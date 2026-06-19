import CoreLocation
import Foundation

enum GrokPlaceSearchError: LocalizedError {
    case missingAPIKey
    case emptyQuery
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "xAI API 키가 설정되지 않았습니다. Config/secrets.local.env를 확인해 주세요."
        case .emptyQuery:
            "검색할 장소 이름을 입력해 주세요."
        case .invalidResponse:
            "Grok API 응답을 해석할 수 없습니다."
        case let .apiError(statusCode, message):
            "Grok API 오류 (\(statusCode)): \(message)"
        case .decodingFailed:
            "장소 정보 JSON 파싱에 실패했습니다."
        }
    }
}

struct GrokPlaceSearchService: Sendable {
    private static let searchSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 180
        configuration.timeoutIntervalForResource = 300
        return URLSession(configuration: configuration)
    }()

    private static let mapSearchDomains = [
        "map.naver.com",
        "pcmap.place.naver.com",
        "place.map.kakao.com"
    ]

    private static let reviewSearchDomains = [
        "blog.naver.com",
        "www.diningcode.com"
    ]

    private let apiKey: String
    private let session: URLSession
    private let endpoint = URL(string: "https://api.x.ai/v1/responses")!

    init(apiKey: String, session: URLSession = searchSession) {
        self.apiKey = apiKey
        self.session = session
    }

    static func makeFromSecrets() throws -> GrokPlaceSearchService {
        guard Secrets.isGrokConfigured else {
            throw GrokPlaceSearchError.missingAPIKey
        }
        return GrokPlaceSearchService(apiKey: Secrets.xaiAPIKey)
    }

    func enrichPlace(
        _ place: Place,
        onProgress: (@Sendable (GrokSearchProgress) -> Void)? = nil
    ) async throws -> GrokPlaceDetail {
        let trimmed = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GrokPlaceSearchError.emptyQuery }

        onProgress?(GrokSearchProgress(
            message: "Grok에 검색 요청을 보냈어요",
            detail: trimmed
        ))

        async let mapListing = fetchMapListing(place: place, onProgress: onProgress)
        async let reviews = fetchCommunityReviews(place: place, onProgress: onProgress)

        let listing = try? await mapListing
        let reviewPoints = (try? await reviews) ?? []

        guard listing != nil || !reviewPoints.isEmpty else {
            throw GrokPlaceSearchError.invalidResponse
        }

        return GrokPlaceDetail.from(
            place: place,
            mapListing: listing,
            reviews: reviewPoints
        )
    }

    // MARK: - Focused searches

    private func fetchMapListing(
        place: Place,
        onProgress: (@Sendable (GrokSearchProgress) -> Void)?
    ) async throws -> GrokMapListing? {
        onProgress?(GrokSearchProgress(
            message: "네이버·카카오 지도에서 영업정보 확인 중",
            detail: place.name
        ))

        let response: GrokMapListingResponse = try await executeSearch(
            query: place.name,
            systemPrompt: Self.mapListingSystemPrompt,
            userPrompt: buildMapUserPrompt(place: place),
            onProgress: onProgress,
            responseSchema: mapListingJSONSchema,
            schemaName: "gumi_map_listing",
            allowedDomains: Self.mapSearchDomains,
            reasoningEffort: "medium",
            searchProgressMessage: "지도 페이지에서 영업정보 수집 중"
        )

        return response.listing
    }

    private func fetchCommunityReviews(
        place: Place,
        onProgress: (@Sendable (GrokSearchProgress) -> Void)?
    ) async throws -> [String] {
        onProgress?(GrokSearchProgress(
            message: "블로그·다이닝코드에서 리뷰 수집 중",
            detail: place.name
        ))

        let response: GrokReviewsResponse = try await executeSearch(
            query: place.name,
            systemPrompt: Self.reviewsSystemPrompt,
            userPrompt: buildReviewsUserPrompt(place: place),
            onProgress: onProgress,
            responseSchema: reviewsJSONSchema,
            schemaName: "gumi_place_reviews",
            allowedDomains: Self.reviewSearchDomains,
            reasoningEffort: "low",
            searchProgressMessage: "커뮤니티 후기 검색 중"
        )

        return response.reviews.filter { PlaceFeatures.hasContent($0) }
    }

    private func buildMapUserPrompt(place: Place) -> String {
        var lines = [
            "Extract structured info for this exact store in Gumi (구미), Gyeongsangbuk-do.",
            "Place name: \(place.name)",
            "Address: \(place.address)",
            "Coordinates: \(place.coordinate.latitude), \(place.coordinate.longitude)"
        ]

        if !place.category.isEmpty {
            lines.append("Category: \(place.category)")
        }
        if let phone = place.phone, !phone.isEmpty {
            lines.append("Phone: \(phone)")
        }
        if let kakaoMapURL = place.kakaoMapURL {
            lines.append("PRIMARY SOURCE — open this Kakao Map listing first: \(kakaoMapURL.absoluteString)")
        } else {
            lines.append("Search \"\(place.name) 구미\" on map.naver.com or place.map.kakao.com and open the exact detail page.")
        }

        lines.append("""
        
        Read every tab on the map page: 홈, 정보, 메뉴, 영업정보, 편의시설.
        Copy breakTime, parking, businessHours verbatim from the map listing only.
        """)

        return lines.joined(separator: "\n")
    }

    private func buildReviewsUserPrompt(place: Place) -> String {
        """
        Find community reviews for this exact store in Gumi:
        Name: \(place.name)
        Address: \(place.address)

        Search blog.naver.com and www.diningcode.com for "\(place.name) 구미 후기".
        Read 2-3 recent posts. Return only review bullet points — no hours, parking, or menu facts.
        """
    }

    // MARK: - API execution

    private func executeSearch<Response: Decodable>(
        query: String,
        systemPrompt: String,
        userPrompt: String,
        onProgress: (@Sendable (GrokSearchProgress) -> Void)?,
        responseSchema: JSONSchema,
        schemaName: String,
        allowedDomains: [String]?,
        reasoningEffort: String,
        searchProgressMessage: String
    ) async throws -> Response {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            makeRequestBody(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                responseSchema: responseSchema,
                schemaName: schemaName,
                allowedDomains: allowedDomains,
                reasoningEffort: reasoningEffort
            )
        )

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GrokPlaceSearchError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let message = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw GrokPlaceSearchError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        let completedResponse = try await parseStream(
            bytes: bytes,
            query: query,
            onProgress: onProgress,
            searchProgressMessage: searchProgressMessage
        )
        return try decodeResponse(from: completedResponse)
    }

    private func parseStream(
        bytes: URLSession.AsyncBytes,
        query: String,
        onProgress: (@Sendable (GrokSearchProgress) -> Void)?,
        searchProgressMessage: String
    ) async throws -> Data {
        var completedJSON: Data?
        var hasWebSearchStarted = false
        var hasWebSearchFinished = false
        var hasReportedOrganizing = false

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }

            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }

            guard let eventData = payload.data(using: .utf8),
                  let event = try? JSONDecoder().decode(StreamEvent.self, from: eventData) else {
                continue
            }

            switch event.type {
            case "response.created", "response.in_progress":
                onProgress?(GrokSearchProgress(message: "Grok이 검색을 준비하고 있어요"))

            case "response.output_item.added":
                if event.item?.type == "web_search_call", !hasWebSearchStarted {
                    hasWebSearchStarted = true
                    onProgress?(GrokSearchProgress(
                        message: searchProgressMessage,
                        detail: "'\(query)'"
                    ))
                }

            case "response.output_item.done":
                if event.item?.type == "web_search_call", !hasWebSearchFinished {
                    hasWebSearchFinished = true
                    onProgress?(GrokSearchProgress(
                        message: "웹 검색 완료",
                        detail: "검색 결과를 분석하고 있어요"
                    ))
                }

            case "response.content_part.added":
                if !hasReportedOrganizing {
                    hasReportedOrganizing = true
                    onProgress?(GrokSearchProgress(message: "장소 정보를 정리하고 있어요"))
                }

            case "response.completed":
                onProgress?(GrokSearchProgress(message: "검색 완료", detail: "결과를 확인해 주세요"))
                if let json = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any],
                   let responseObject = json["response"],
                   let responseData = try? JSONSerialization.data(withJSONObject: responseObject) {
                    completedJSON = responseData
                }

            default:
                break
            }
        }

        guard let completedJSON else {
            throw GrokPlaceSearchError.invalidResponse
        }
        return completedJSON
    }

    private func makeRequestBody(
        systemPrompt: String,
        userPrompt: String,
        responseSchema: JSONSchema,
        schemaName: String,
        allowedDomains: [String]?,
        reasoningEffort: String
    ) -> ResponsesAPIRequest {
        ResponsesAPIRequest(
            model: "grok-4.3",
            store: false,
            stream: true,
            maxOutputTokens: 4096,
            reasoning: ReasoningConfig(effort: reasoningEffort),
            input: [
                InputMessage(role: "system", content: systemPrompt),
                InputMessage(role: "user", content: userPrompt)
            ],
            tools: [
                WebSearchTool(type: "web_search", allowedDomains: allowedDomains)
            ],
            text: TextConfig(
                format: TextFormat(
                    type: "json_schema",
                    name: schemaName,
                    schema: responseSchema,
                    strict: true
                )
            )
        )
    }

    private func decodeResponse<Response: Decodable>(from data: Data) throws -> Response {
        let response = try JSONDecoder().decode(ResponsesAPIResponse.self, from: data)

        if let error = response.error {
            throw GrokPlaceSearchError.apiError(
                statusCode: 0,
                message: "\(error.code): \(error.message)"
            )
        }

        guard let jsonText = response.outputText,
              let contentData = jsonText.data(using: .utf8) else {
            throw GrokPlaceSearchError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(Response.self, from: contentData)
        } catch let error as GrokPlaceSearchError {
            throw error
        } catch {
            throw GrokPlaceSearchError.decodingFailed
        }
    }

    // MARK: - JSON schemas

    private var stringItemSchema: JSONSchema {
        JSONSchema(
            type: "string",
            properties: [:],
            required: [],
            additionalProperties: false
        )
    }

    private var placeFeaturesSchema: JSONSchema {
        JSONSchema(
            type: "object",
            properties: [
                "popularMenu": JSONSchemaProperty(
                    type: "string",
                    description: "Verbatim copy of 대표메뉴/시그니처 from map page menu or summary tab"
                ),
                "breakTime": JSONSchemaProperty(
                    type: "string",
                    description: "Verbatim copy of 브레이크타임/라스트오더 time range from map 영업정보; use 없음 only if map explicitly says none"
                ),
                "parking": JSONSchemaProperty(
                    type: "string",
                    description: "Verbatim copy of 주차/주차가능/주차안내 from map 편의시설; never contradict the map page"
                ),
                "wait": JSONSchemaProperty(
                    type: "string",
                    description: "Waiting/혼잡/예약 from map page only, or 정보 없음"
                ),
                "closedDay": JSONSchemaProperty(
                    type: "string",
                    description: "Verbatim copy of 정기 휴무일 from map hours or 휴무일 field"
                )
            ],
            required: ["popularMenu", "breakTime", "parking", "wait", "closedDay"],
            additionalProperties: false
        )
    }

    private var mapListingJSONSchema: JSONSchema {
        JSONSchema(
            type: "object",
            properties: [
                "listing": JSONSchemaProperty(
                    type: "object",
                    nestedSchema: JSONSchema(
                        type: "object",
                        properties: [
                            "features": JSONSchemaProperty(
                                type: "object",
                                nestedSchema: placeFeaturesSchema
                            ),
                            "businessHours": JSONSchemaProperty(
                                type: "string",
                                description: "All 7 weekdays verbatim from map 영업시간, e.g. 월 11:00-22:00, 화 휴무, ..."
                            )
                        ],
                        required: ["features", "businessHours"],
                        additionalProperties: false
                    )
                )
            ],
            required: ["listing"],
            additionalProperties: false
        )
    }

    private var reviewsJSONSchema: JSONSchema {
        JSONSchema(
            type: "object",
            properties: [
                "reviews": JSONSchemaProperty(
                    type: "array",
                    description: "2-4 specific Korean insights from real blog/diningcode posts; empty if none found",
                    items: stringItemSchema,
                    minItems: 0,
                    maxItems: 4
                )
            ],
            required: ["reviews"],
            additionalProperties: false
        )
    }

    private static let mapListingSystemPrompt = """
    You extract structured facts from ONE Naver Place or Kakao Map listing in Gumi, South Korea.

    SOURCE OF TRUTH: only map.naver.com, pcmap.place.naver.com, or place.map.kakao.com detail pages.
    NEVER use blogs, reviews, or inference for any field.

    Rules:
    1. Open the provided Kakao Map URL first when given; otherwise find the exact store on Naver/Kakao map.
    2. Read ALL tabs: 홈, 정보, 메뉴, 영업정보, 편의시설.
    3. COPY text verbatim from the map page — do not paraphrase, guess, or invert facts.
       • If the page says 주차가능 or 주차 있음 → never write 불가능 or 불가.
       • breakTime: copy the exact time range shown (e.g. "15:00-17:00").
       • parking: copy exactly as shown (e.g. "주차 가능 (매장 앞)", "건물 지하 주차장").
    4. Use "정보 없음" ONLY when the map page truly does not show that field after checking all tabs.
    5. Use "없음" for breakTime ONLY when the map page explicitly states no break time.

    Return listing.features (5 fields) and listing.businessHours (all 7 weekdays).
    Format hours: "월 HH:MM-HH:MM, 화 ..., 수 ..., 목 ..., 금 ..., 토 ..., 일 ...", use "휴무" for closed days.
    Max 2 web_search calls.
    """

    private static let reviewsSystemPrompt = """
    You collect community review insights for ONE restaurant or cafe in Gumi, South Korea.

    Search ONLY blog.naver.com and www.diningcode.com for recent posts about this exact store.
    Do NOT extract business hours, parking, break time, or menu facts — reviews only.

    Return 2-4 bullet points (Korean, max ~50 chars each):
    • Each must mention a concrete detail: menu name, taste, price, seating, wait, service, vibe
    • Never use vague lines like "맛있어요" or "분위기 좋아요" alone
    • Return [] if no trustworthy posts exist — do NOT invent reviews

    Max 2 web_search calls.
    """
}

// MARK: - Request DTOs

private struct ResponsesAPIRequest: Encodable {
    let model: String
    let store: Bool
    let stream: Bool
    let maxOutputTokens: Int
    let reasoning: ReasoningConfig
    let input: [InputMessage]
    let tools: [WebSearchTool]
    let text: TextConfig

    enum CodingKeys: String, CodingKey {
        case model
        case store
        case stream
        case maxOutputTokens = "max_output_tokens"
        case reasoning
        case input
        case tools
        case text
    }
}

private struct ReasoningConfig: Encodable {
    let effort: String
}

private struct InputMessage: Encodable {
    let role: String
    let content: String
}

private struct WebSearchTool: Encodable {
    let type: String
    let filters: WebSearchFilters?

    init(type: String, allowedDomains: [String]?) {
        self.type = type
        self.filters = allowedDomains.map { WebSearchFilters(allowedDomains: $0) }
    }
}

private struct WebSearchFilters: Encodable {
    let allowedDomains: [String]

    enum CodingKeys: String, CodingKey {
        case allowedDomains = "allowed_domains"
    }
}

private struct TextConfig: Encodable {
    let format: TextFormat
}

private struct TextFormat: Encodable {
    let type: String
    let name: String
    let schema: JSONSchema
    let strict: Bool
}

private struct JSONSchema: Encodable {
    let type: String
    let properties: [String: JSONSchemaProperty]
    let required: [String]
    let additionalProperties: Bool
}

private struct JSONSchemaProperty: Encodable {
    let type: String
    let description: String?
    let enumValues: [String]?
    let items: JSONSchema?
    let nestedSchema: JSONSchema?
    let minItems: Int?
    let maxItems: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
        case items
        case properties
        case required
        case additionalProperties
        case minItems
        case maxItems
    }

    init(
        type: String,
        description: String? = nil,
        enumValues: [String]? = nil,
        items: JSONSchema? = nil,
        nestedSchema: JSONSchema? = nil,
        minItems: Int? = nil,
        maxItems: Int? = nil
    ) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
        self.items = items
        self.nestedSchema = nestedSchema
        self.minItems = minItems
        self.maxItems = maxItems
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(enumValues, forKey: .enumValues)
        try container.encodeIfPresent(items, forKey: .items)
        try container.encodeIfPresent(minItems, forKey: .minItems)
        try container.encodeIfPresent(maxItems, forKey: .maxItems)

        if let nestedSchema {
            try container.encode(nestedSchema.properties, forKey: .properties)
            try container.encode(nestedSchema.required, forKey: .required)
            try container.encode(nestedSchema.additionalProperties, forKey: .additionalProperties)
        }
    }
}

// MARK: - Response DTOs

private struct StreamEvent: Decodable {
    let type: String
    let item: StreamOutputItem?
}

private struct StreamOutputItem: Decodable {
    let type: String?
}

private struct ResponsesAPIResponse: Codable {
    let output: [OutputItem]?
    let error: APIErrorBody?

    struct APIErrorBody: Codable {
        let code: String
        let message: String
    }

    var outputText: String? {
        guard let output else { return nil }

        for item in output where item.type == "message" {
            if let text = item.content?
                .first(where: { $0.type == "output_text" })?
                .text {
                return text
            }
        }
        return nil
    }
}

private struct OutputItem: Codable {
    let type: String
    let content: [OutputContent]?
}

private struct OutputContent: Codable {
    let type: String
    let text: String?
}