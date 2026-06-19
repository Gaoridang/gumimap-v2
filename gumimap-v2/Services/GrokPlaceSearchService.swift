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
            schemaName: "gumi_place_detail"
        )

        guard let place = response.places.first else {
            throw GrokPlaceSearchError.invalidResponse
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
        
        Search this exact store in Gumi. Use the Kakao URL when provided.
        For reviews, search blog.naver.com and www.diningcode.com for "\(name) 구미 후기".
        """)

        return lines.joined(separator: "\n")
    }

    // MARK: - API execution

    private func executeSearch<Response: Decodable>(
        query: String,
        systemPrompt: String,
        userPrompt: String,
        onProgress: (@Sendable (GrokSearchProgress) -> Void)?,
        responseSchema: JSONSchema,
        schemaName: String
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
                schemaName: schemaName
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
        schemaName: String
    ) -> ResponsesAPIRequest {
        ResponsesAPIRequest(
            model: "grok-4.3",
            store: false,
            stream: true,
            maxOutputTokens: 4096,
            reasoning: ReasoningConfig(effort: "low"),
            input: [
                InputMessage(role: "system", content: systemPrompt),
                InputMessage(role: "user", content: userPrompt)
            ],
            tools: [
                WebSearchTool(type: "web_search")
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
                    description: "인기 메뉴·시그니처 메뉴 (Korean, concise)"
                ),
                "breakTime": JSONSchemaProperty(
                    type: "string",
                    description: "브레이크 타임 시간대 (e.g. 15:00-17:00) or 정보 없음"
                ),
                "parking": JSONSchemaProperty(
                    type: "string",
                    description: "주차 가능 여부·위치·요금 (Korean)"
                ),
                "wait": JSONSchemaProperty(
                    type: "string",
                    description: "평균 대기·혼잡 시간대·예약 필요 여부 (Korean)"
                ),
                "closedDay": JSONSchemaProperty(
                    type: "string",
                    description: "정기 휴무일 (e.g. 매주 월요일) or 정보 없음"
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
                    description: "2-4 specific Korean insights from real blog/diningcode posts; empty if none found",
                    items: stringItemSchema,
                    minItems: 0,
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

    private static let placeDetailSystemPrompt = """
    You research ONE real restaurant or cafe in Gumi (구미), Gyeongsangbuk-do, South Korea.
    Focus on visitor-facing insights from community sources and official map listings.

    Use at most 3 web_search calls:
    1. map.naver.com, pcmap.place.naver.com, or place.map.kakao.com for "{name} 구미" — verify name, address, coordinates, hours, features
    2. blog.naver.com or www.diningcode.com for "{name} 구미 후기" — read 2-3 recent posts for reviews
    3. If traits still missing: search menu, parking, break time, or holiday info from blogs or map tabs

    Return exactly 1 place with:
    - name, address, latitude/longitude, category: from official map listing
    - reviews: 2-4 bullet points from real community posts (Korean, max ~50 chars each)
      • Each must mention a concrete detail: menu name, taste, price, seating, wait, service, vibe
      • Never use vague lines like "맛있어요" or "분위기 좋아요" alone
      • Return [] if no trustworthy community posts exist — do NOT invent reviews
    - features: object with exactly these 5 fields (use "정보 없음" when unknown):
      • popularMenu — 인기 메뉴 / 시그니처 메뉴
      • breakTime — 브레이크 타임 (e.g. "15:00-17:00" or "없음")
      • parking — 주차 정보
      • wait — 대기·혼잡·예약 정보
      • closedDay — 정기 휴무일
    - businessHours: all 7 weekdays from Naver/Kakao listing, format "월 HH:MM-HH:MM, 화 ..., 수 ..., 목 ..., 금 ..., 토 ..., 일 ...", use "휴무" for closed days

    Each reviews item must be a single scannable line — no paragraphs, no numbering prefix.
    Do NOT invent reviews. Prefer recent blog and dining community sources.
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