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
            "추가 정보를 불러올 수 없어요. 잠시 후 다시 시도해 주세요."
        case .emptyQuery:
            "장소 정보를 확인할 수 없어요."
        case .invalidResponse:
            "추가 정보를 불러오지 못했어요."
        case .apiError:
            "일시적인 오류가 발생했어요. 다시 시도해 주세요."
        case .decodingFailed:
            "추가 정보를 불러오지 못했어요."
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
        _ place: Place,
        onProgress: (@Sendable (GrokSearchProgress) -> Void)? = nil
    ) async throws -> GrokPlaceDetail {
        let trimmed = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GrokPlaceSearchError.emptyQuery }

        let searchQuery = "\(trimmed) 구미"

        onProgress?(GrokSearchProgress(
            message: "추가 정보를 불러오고 있어요",
            detail: trimmed
        ))

        let response: GrokPlaceSearchResponse = try await executeSearch(
            query: searchQuery,
            systemPrompt: Self.searchSystemPrompt,
            userPrompt: buildSearchUserPrompt(place: place, searchQuery: searchQuery),
            onProgress: onProgress,
            responseSchema: placeSearchJSONSchema,
            schemaName: "gumi_place_search",
            allowedDomains: nil,
            reasoningEffort: "medium",
            searchProgressMessage: "영업시간과 리뷰를 살펴보고 있어요"
        )

        return GrokPlaceDetail.from(
            place: place,
            response: response,
            searchQuery: searchQuery
        )
    }

    private func buildSearchUserPrompt(place: Place, searchQuery: String) -> String {
        var lines = [
            "Search the web for: \"\(searchQuery)\"",
            "Place name: \(place.name)",
            "Address: \(place.address)"
        ]

        if !place.category.isEmpty {
            lines.append("Category: \(place.category)")
        }
        if let phone = place.phone, !phone.isEmpty {
            lines.append("Phone: \(phone)")
        }
        if let kakaoMapURL = place.kakaoMapURL {
            lines.append("Kakao Map: \(kakaoMapURL.absoluteString)")
        }

        lines.append("""
        
        Find useful facts about this exact store in Gumi from web search results.
        Return label/value fields in Korean and 2-4 review bullet points when available.
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
                onProgress?(GrokSearchProgress(message: "잠시만 기다려 주세요"))

            case "response.output_item.added":
                if event.item?.type == "web_search_call", !hasWebSearchStarted {
                    hasWebSearchStarted = true
                    onProgress?(GrokSearchProgress(message: searchProgressMessage))
                }

            case "response.output_item.done":
                if event.item?.type == "web_search_call", !hasWebSearchFinished {
                    hasWebSearchFinished = true
                    onProgress?(GrokSearchProgress(message: "찾은 내용을 정리하고 있어요"))
                }

            case "response.content_part.added":
                if !hasReportedOrganizing {
                    hasReportedOrganizing = true
                    onProgress?(GrokSearchProgress(message: "장소 정보를 정리하고 있어요"))
                }

            case "response.completed":
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

    // MARK: - JSON schema

    private var stringItemSchema: JSONSchema {
        JSONSchema(
            type: "string",
            properties: [:],
            required: [],
            additionalProperties: false
        )
    }

    private var insightFieldSchema: JSONSchema {
        JSONSchema(
            type: "object",
            properties: [
                "label": JSONSchemaProperty(
                    type: "string",
                    description: "Korean field label. Prefer: 영업시간, 브레이크타임, 휴무일, 주차, 분위기, 특징. Extra labels allowed."
                ),
                "value": JSONSchemaProperty(
                    type: "string",
                    description: "Value found from web search for this store in Gumi"
                )
            ],
            required: ["label", "value"],
            additionalProperties: false
        )
    }

    private var placeSearchJSONSchema: JSONSchema {
        JSONSchema(
            type: "object",
            properties: [
                "fields": JSONSchemaProperty(
                    type: "array",
                    description: "Useful place facts as label/value pairs in Korean",
                    items: insightFieldSchema,
                    minItems: 0,
                    maxItems: 12
                ),
                "reviews": JSONSchemaProperty(
                    type: "array",
                    description: "2-4 short Korean review insights from blogs or community posts",
                    items: stringItemSchema,
                    minItems: 0,
                    maxItems: 4
                )
            ],
            required: ["fields", "reviews"],
            additionalProperties: false
        )
    }

    private static let searchSystemPrompt = """
    You search the web for information about ONE place in Gumi (구미), South Korea.

    Use the exact search query provided by the user, such as \"후우미라멘 구미\".
    Collect useful facts from map listings, blogs, reviews, and community posts.

    Return JSON only:
    • fields: array of { label, value } in Korean
    • reviews: 2-4 short Korean bullet points with concrete details

    Always try to include these field labels when available:
    영업시간, 브레이크타임, 휴무일, 주차, 분위기, 특징
    You may add extra fields (e.g. 인기 메뉴, 대기) for data collection.

    Prefer facts that clearly refer to the exact store in Gumi.
    Do not invent information. Omit uncertain items instead of guessing.
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