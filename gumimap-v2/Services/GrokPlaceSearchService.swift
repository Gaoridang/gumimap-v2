import CoreLocation
import Foundation

enum GrokPlaceSearchError: LocalizedError {
    case missingAPIKey
    case emptyQuery
    case invalidResponse
    case placeMismatch
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
        case .placeMismatch:
            "지도에서 정확한 장소 페이지를 찾지 못했어요."
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

    private static let kakaoMapDomain = ["place.map.kakao.com"]

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

        async let reviews = fetchCommunityReviews(place: place, onProgress: onProgress)

        let listing = try? await fetchMapListing(place: place, onProgress: onProgress)
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
        let sourceURL = try await resolveListingURL(for: place, onProgress: onProgress)

        onProgress?(GrokSearchProgress(
            message: "지도 페이지에서 영업정보 추출 중",
            detail: place.name
        ))

        for attempt in 1 ... 2 {
            let response: GrokMapListingExtractionResponse = try await executeSearch(
                query: sourceURL,
                systemPrompt: attempt == 1 ? Self.mapExtractSystemPrompt : Self.mapExtractRetrySystemPrompt,
                userPrompt: buildMapExtractUserPrompt(place: place, sourceURL: sourceURL),
                onProgress: onProgress,
                responseSchema: mapListingExtractionJSONSchema,
                schemaName: "gumi_map_listing_extract",
                allowedDomains: listingDomains(for: sourceURL),
                reasoningEffort: "high",
                searchProgressMessage: "지도 페이지 탭별 정보 수집 중"
            )

            if GrokMapListingValidator.validateExtraction(
                response,
                expectedSourceURL: sourceURL,
                place: place
            ) {
                return response.listing
            }
        }

        throw GrokPlaceSearchError.placeMismatch
    }

    private func resolveListingURL(
        for place: Place,
        onProgress: (@Sendable (GrokSearchProgress) -> Void)?
    ) async throws -> String {
        if let kakaoMapURL = place.kakaoMapURL?.absoluteString, !kakaoMapURL.isEmpty {
            onProgress?(GrokSearchProgress(
                message: "카카오맵 페이지 확인 중",
                detail: place.name
            ))
            return kakaoMapURL
        }

        onProgress?(GrokSearchProgress(
            message: "네이버·카카오 지도에서 정확한 페이지 찾는 중",
            detail: place.name
        ))

        let response: GrokMapResolveResponse = try await executeSearch(
            query: "\(place.name) \(place.address)",
            systemPrompt: Self.mapResolveSystemPrompt,
            userPrompt: buildMapResolveUserPrompt(place: place),
            onProgress: onProgress,
            responseSchema: mapResolveJSONSchema,
            schemaName: "gumi_map_resolve",
            allowedDomains: Self.mapSearchDomains,
            reasoningEffort: "medium",
            searchProgressMessage: "지도에서 장소 페이지 검색 중"
        )

        guard GrokMapListingValidator.validateResolution(response, for: place) else {
            throw GrokPlaceSearchError.placeMismatch
        }

        return response.sourceURL
    }

    private func listingDomains(for sourceURL: String) -> [String] {
        guard let host = URL(string: sourceURL)?.host?.lowercased() else {
            return Self.mapSearchDomains
        }

        if host.contains("kakao.com") {
            return Self.kakaoMapDomain
        }
        if host.contains("naver.com") {
            return ["map.naver.com", "pcmap.place.naver.com"]
        }

        return Self.mapSearchDomains
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

    private func buildMapResolveUserPrompt(place: Place) -> String {
        var lines = [
            "Find the exact map listing page for this store in Gumi (구미), Gyeongsangbuk-do.",
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

        lines.append("""
        
        Search map.naver.com and place.map.kakao.com using name + address.
        Open candidate pages and verify BOTH name and street/road address match.
        Return confidence \"high\" only when the page clearly matches this exact store.
        Do NOT extract hours, menu, parking, or reviews — only resolve the listing URL.
        """)

        return lines.joined(separator: "\n")
    }

    private func buildMapExtractUserPrompt(place: Place, sourceURL: String) -> String {
        var lines = [
            "Extract structured info from ONE map listing page only.",
            "Open ONLY this exact URL — do NOT search by store name:",
            sourceURL,
            "",
            "Expected store:",
            "Name: \(place.name)",
            "Address: \(place.address)"
        ]

        if let phone = place.phone, !phone.isEmpty {
            lines.append("Phone: \(phone)")
        }

        lines.append("""
        
        If the page is NOT this exact store, return sourceURL as given and set every feature field to \"정보 없음\" with businessHours \"\".
        Otherwise read every tab: 홈, 정보, 메뉴, 영업정보, 편의시설.
        Copy breakTime, parking, and businessHours verbatim from the map listing only.
        """)

        return lines.joined(separator: "\n")
    }

    private func buildReviewsUserPrompt(place: Place) -> String {
        """
        Find community reviews for this exact store in Gumi:
        Name: \(place.name)
        Address: \(place.address)

        Search blog.naver.com and www.diningcode.com for "\(place.name) \(place.address) 후기".
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

    private var mapListingBodySchema: JSONSchema {
        JSONSchema(
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
    }

    private var mapResolveJSONSchema: JSONSchema {
        JSONSchema(
            type: "object",
            properties: [
                "sourceURL": JSONSchemaProperty(
                    type: "string",
                    description: "Exact Naver Place or Kakao Map detail page URL"
                ),
                "pageName": JSONSchemaProperty(
                    type: "string",
                    description: "Store name shown on the resolved map page"
                ),
                "pageAddress": JSONSchemaProperty(
                    type: "string",
                    description: "Address shown on the resolved map page"
                ),
                "confidence": JSONSchemaProperty(
                    type: "string",
                    description: "high only when name and address both match the expected store",
                    enumValues: ["high", "medium", "low"]
                )
            ],
            required: ["sourceURL", "pageName", "pageAddress", "confidence"],
            additionalProperties: false
        )
    }

    private var mapListingExtractionJSONSchema: JSONSchema {
        JSONSchema(
            type: "object",
            properties: [
                "sourceURL": JSONSchemaProperty(
                    type: "string",
                    description: "The exact map listing URL that was opened"
                ),
                "listing": JSONSchemaProperty(
                    type: "object",
                    nestedSchema: mapListingBodySchema
                )
            ],
            required: ["sourceURL", "listing"],
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

    private static let mapResolveSystemPrompt = """
    You resolve the exact map listing URL for ONE store in Gumi, South Korea.

    Search only map.naver.com, pcmap.place.naver.com, or place.map.kakao.com.
    NEVER extract hours, menu, parking, or reviews in this step.

    Rules:
    1. Search using store name AND address together — never name alone.
    2. Open candidate detail pages and verify the page name and street/road address match.
    3. Return confidence \"high\" only when both name and address clearly match.
    4. Return confidence \"low\" for ambiguous chains, homonyms, or partial address matches.
    5. sourceURL must be the final detail page URL, not a search results page.

    Max 2 web_search calls.
    """

    private static let mapExtractSystemPrompt = """
    You extract structured facts from ONE already-resolved map listing URL in Gumi, South Korea.

    SOURCE OF TRUTH: only the exact URL provided in the user message.
    NEVER search by store name. NEVER use blogs, reviews, or inference.

    Rules:
    1. Open ONLY the provided URL. Do not run additional name-based searches.
    2. If the page is not the expected store, return empty/정보 없음 values — do not guess.
    3. Read ALL tabs: 홈, 정보, 메뉴, 영업정보, 편의시설.
    4. COPY text verbatim — do not paraphrase, guess, or invert facts.
       • If the page says 주차가능 or 주차 있음 → never write 불가능 or 불가.
       • breakTime: copy the exact time range shown (e.g. "15:00-17:00").
       • parking: copy exactly as shown.
    5. Use "정보 없음" ONLY when the map page truly does not show that field after checking all tabs.

    Return sourceURL and listing.features + listing.businessHours.
    Format hours: "월 HH:MM-HH:MM, 화 ..., 수 ..., 목 ..., 금 ..., 토 ..., 일 ...", use "휴무" for closed days.
    Max 1 web_search call — open the provided URL only.
    """

    private static let mapExtractRetrySystemPrompt = """
    You extract structured facts from ONE map listing URL in Gumi, South Korea.

    The previous extraction failed validation. Be stricter:
    1. Open ONLY the provided URL — no name-based search.
    2. If the page does not clearly match the expected store name and address, return all feature fields as \"정보 없음\" and businessHours as \"\".
    3. Otherwise copy map page text verbatim from 홈, 정보, 메뉴, 영업정보, 편의시설 tabs.
    4. Never invent or invert parking, break time, or hours.

    Return sourceURL and listing.features + listing.businessHours.
    Max 1 web_search call.
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