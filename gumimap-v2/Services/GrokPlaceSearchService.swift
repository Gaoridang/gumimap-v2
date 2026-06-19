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

    private static let allowedSearchDomains = [
        "map.naver.com",
        "pcmap.place.naver.com",
        "place.map.kakao.com",
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
        name: String,
        address: String? = nil,
        category: String? = nil,
        phone: String? = nil,
        kakaoMapURL: URL? = nil,
        onProgress: (@Sendable (GrokSearchProgress) -> Void)? = nil
    ) async throws -> GrokPlaceDetail {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GrokPlaceSearchError.emptyQuery }

        onProgress?(GrokSearchProgress(
            message: "Grok에 검색 요청을 보냈어요",
            detail: trimmed
        ))

        let userPrompt = buildUserPrompt(
            name: trimmed,
            address: address,
            category: category,
            phone: phone,
            kakaoMapURL: kakaoMapURL
        )

        let response: GrokPlaceDetailResponse = try await executeSearch(
            query: trimmed,
            systemPrompt: Self.placeDetailSystemPrompt,
            userPrompt: userPrompt,
            onProgress: onProgress,
            responseSchema: placeDetailJSONSchema,
            schemaName: "gumi_place_detail",
            allowedDomains: Self.allowedSearchDomains
        )

        guard var place = response.places.first else {
            throw GrokPlaceSearchError.invalidResponse
        }

        if place.needsMapRetry {
            onProgress?(GrokSearchProgress(
                message: "지도에서 상세 정보 확인 중",
                detail: trimmed
            ))

            if let patch = try? await fetchMapListingPatch(
                name: trimmed,
                address: address,
                kakaoMapURL: kakaoMapURL,
                onProgress: onProgress
            ) {
                place = place.mergingMapListing(
                    features: patch.features,
                    businessHours: patch.businessHours
                )
            }
        }

        return place
    }

    private func buildUserPrompt(
        name: String,
        address: String?,
        category: String?,
        phone: String?,
        kakaoMapURL: URL?
    ) -> String {
        var lines = [
            "Find this exact place in Gumi (구미), Gyeongsangbuk-do, South Korea.",
            "Place name: \(name)"
        ]

        if let address, !address.isEmpty {
            lines.append("Address: \(address)")
        }
        if let category, !category.isEmpty {
            lines.append("Category: \(category)")
        }
        if let phone, !phone.isEmpty {
            lines.append("Phone: \(phone)")
        }
        if let kakaoMapURL {
            lines.append("Kakao Map URL (open and read this listing first): \(kakaoMapURL.absoluteString)")
        }

        lines.append("""
        
        REQUIRED search order:
        1. Open the Naver Place or Kakao Map detail page for this exact store (use the Kakao URL if provided, otherwise search "\(name) 구미" on map.naver.com or place.map.kakao.com).
        2. From that map listing page, copy businessHours and every field in features (popularMenu, breakTime, parking, wait, closedDay). These are often under 영업정보, 정보, 편의시설, 주차, 브레이크타임, 휴무일, 대표메뉴.
        3. Only then search blogs for reviews.
        
        Use "정보 없음" ONLY if the map listing page truly does not show that field.
        For breakTime: use "없음" only when the map page explicitly says no break time.
        """)

        return lines.joined(separator: "\n")
    }

    private func fetchMapListingPatch(
        name: String,
        address: String?,
        kakaoMapURL: URL?,
        onProgress: (@Sendable (GrokSearchProgress) -> Void)?
    ) async throws -> GrokMapListingPatch? {
        var userPrompt = """
        Re-read the Naver Place or Kakao Map detail page for: \(name)
        """
        if let address, !address.isEmpty {
            userPrompt += "\nAddress: \(address)"
        }
        if let kakaoMapURL {
            userPrompt += "\nKakao Map URL: \(kakaoMapURL.absoluteString)"
        }
        userPrompt += """

        Extract businessHours and all features fields from the map page only.
        Do NOT use blogs. Fill every visible field from the listing.
        """

        let response: GrokMapListingPatchResponse = try await executeSearch(
            query: name,
            systemPrompt: Self.mapListingSystemPrompt,
            userPrompt: userPrompt,
            onProgress: onProgress,
            responseSchema: mapListingJSONSchema,
            schemaName: "gumi_map_listing",
            allowedDomains: Self.mapSearchDomains
        )

        return response.places.first
    }

    // MARK: - API execution

    private func executeSearch<Response: Decodable>(
        query: String,
        systemPrompt: String,
        userPrompt: String,
        onProgress: (@Sendable (GrokSearchProgress) -> Void)?,
        responseSchema: JSONSchema,
        schemaName: String,
        allowedDomains: [String]
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
                allowedDomains: allowedDomains
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
            onProgress: onProgress
        )
        return try decodeResponse(from: completedResponse)
    }

    private func parseStream(
        bytes: URLSession.AsyncBytes,
        query: String,
        onProgress: (@Sendable (GrokSearchProgress) -> Void)?
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
                        message: "지도·커뮤니티에서 검색 중",
                        detail: "'\(query)' 관련 정보 수집"
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
        allowedDomains: [String]
    ) -> ResponsesAPIRequest {
        ResponsesAPIRequest(
            model: "grok-4.3",
            store: false,
            stream: true,
            maxOutputTokens: 4096,
            reasoning: ReasoningConfig(effort: "medium"),
            input: [
                InputMessage(role: "system", content: systemPrompt),
                InputMessage(role: "user", content: userPrompt)
            ],
            tools: [
                WebSearchTool(
                    type: "web_search",
                    filters: WebSearchFilters(allowedDomains: allowedDomains)
                )
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

    private var placeDetailJSONSchema: JSONSchema {
        JSONSchema(
            type: "object",
            properties: [
                "places": JSONSchemaProperty(
                    type: "array",
                    items: placeItemJSONSchema,
                    minItems: 1,
                    maxItems: 1
                )
            ],
            required: ["places"],
            additionalProperties: false
        )
    }

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
                    description: "Copy 대표메뉴/시그니처 from Naver/Kakao map menu or summary tab"
                ),
                "breakTime": JSONSchemaProperty(
                    type: "string",
                    description: "Copy 브레이크타임/라스트오더/휴게시간 from map 영업정보; use 없음 only if page says none"
                ),
                "parking": JSONSchemaProperty(
                    type: "string",
                    description: "Copy 주차/주차가능/주차안내 from map 편의시설 or 정보 tab"
                ),
                "wait": JSONSchemaProperty(
                    type: "string",
                    description: "Copy waiting/혼잡/예약 info from map or use 정보 없음"
                ),
                "closedDay": JSONSchemaProperty(
                    type: "string",
                    description: "Copy 정기 휴무일 from map hours or 휴무일 field"
                )
            ],
            required: ["popularMenu", "breakTime", "parking", "wait", "closedDay"],
            additionalProperties: false
        )
    }

    private var placeItemJSONSchema: JSONSchema {
        JSONSchema(
            type: "object",
            properties: [
                "name": JSONSchemaProperty(type: "string"),
                "address": JSONSchemaProperty(type: "string"),
                "latitude": JSONSchemaProperty(type: "number"),
                "longitude": JSONSchemaProperty(type: "number"),
                "category": JSONSchemaProperty(type: "string"),
                "reviews": JSONSchemaProperty(
                    type: "array",
                    description: "2-4 short Korean bullet points about community reviews",
                    items: stringItemSchema,
                    minItems: 1,
                    maxItems: 4
                ),
                "features": JSONSchemaProperty(
                    type: "object",
                    description: "Structured place traits with exactly 5 fields",
                    nestedSchema: placeFeaturesSchema
                ),
                "businessHours": JSONSchemaProperty(
                    type: "string",
                    description: "All 7 weekdays from official listing, e.g. 월 11:00-22:00, 화 휴무, ..."
                )
            ],
            required: [
                "name", "address", "latitude", "longitude", "category",
                "reviews", "features", "businessHours"
            ],
            additionalProperties: false
        )
    }

    private var mapListingPlaceSchema: JSONSchema {
        JSONSchema(
            type: "object",
            properties: [
                "features": JSONSchemaProperty(
                    type: "object",
                    nestedSchema: placeFeaturesSchema
                ),
                "businessHours": JSONSchemaProperty(
                    type: "string",
                    description: "All 7 weekdays copied from map listing"
                )
            ],
            required: ["features", "businessHours"],
            additionalProperties: false
        )
    }

    private var mapListingJSONSchema: JSONSchema {
        JSONSchema(
            type: "object",
            properties: [
                "places": JSONSchemaProperty(
                    type: "array",
                    items: mapListingPlaceSchema,
                    minItems: 1,
                    maxItems: 1
                )
            ],
            required: ["places"],
            additionalProperties: false
        )
    }

    private static let placeDetailSystemPrompt = """
    You research ONE real restaurant or cafe in Gumi (구미), Gyeongsangbuk-do, South Korea.

    CRITICAL: Most structured data lives on the Naver Place or Kakao Map detail page — NOT blogs.
    Always open the map listing page first and read ALL tabs/sections before using "정보 없음".

    Search order (max 4 web_search calls):
    1. map.naver.com, pcmap.place.naver.com, or place.map.kakao.com — open the exact place detail page
    2. On that page copy: businessHours, popularMenu, breakTime, parking, wait, closedDay
       Look for labels: 영업시간, 브레이크타임, 라스트오더, 휴게시간, 주차, 주차가능, 휴무일, 대표메뉴, 시그니처, 정보, 편의시설
    3. blog.naver.com or www.diningcode.com — reviews ONLY (after map page is read)

    Return exactly 1 place with:
    - name, address, latitude/longitude, category: from map listing
    - businessHours: all 7 weekdays, format "월 HH:MM-HH:MM, 화 ..., 수 ..., 목 ..., 금 ..., 토 ..., 일 ..."
    - features: copy from map page when visible:
      • popularMenu — 대표/시그니처 메뉴
      • breakTime — 브레이크타임/라스트오더 (use "없음" only if map explicitly says none)
      • parking — 주차 정보
      • wait — 대기·혼잡·예약 (often not on map → "정보 없음" OK)
      • closedDay — 정기 휴무일
    - reviews: 2-4 community bullet points (Korean, max ~40 chars each)

    Use "정보 없음" ONLY after checking the map listing page. Never guess.
    """

    private static let mapListingSystemPrompt = """
    Re-read the Naver Place or Kakao Map detail page for ONE place in Gumi, South Korea.
    Search ONLY map.naver.com, pcmap.place.naver.com, or place.map.kakao.com.

    Copy every visible field from the listing page:
    - businessHours (영업시간 — all 7 weekdays)
    - features.popularMenu (대표메뉴/메뉴 탭)
    - features.breakTime (브레이크타임/라스트오더/휴게시간 — very common on map pages)
    - features.parking (주차/주차가능)
    - features.closedDay (휴무일)
    - features.wait (if shown)

    Do NOT use blogs. Do NOT return reviews.
    Use "정보 없음" only when the map page truly lacks that field. Use "없음" for breakTime when map says no break.
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
    let filters: WebSearchFilters
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