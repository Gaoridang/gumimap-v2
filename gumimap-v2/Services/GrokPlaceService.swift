import Foundation

enum GrokPlaceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpStatus(Int, String?)
    case emptyContent
    case incompleteResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Grok API 키가 설정되지 않았습니다."
        case .invalidResponse:
            "장소 정보를 불러올 수 없습니다."
        case .httpStatus(let code, let detail):
            if let detail, !detail.isEmpty {
                "장소 정보 요청에 실패했습니다. (HTTP \(code): \(detail))"
            } else {
                "장소 정보 요청에 실패했습니다. (HTTP \(code))"
            }
        case .emptyContent:
            "장소 정보 응답이 비어 있습니다."
        case .incompleteResponse:
            "장소 정보 응답이 완료되지 않았습니다."
        }
    }
}

struct GrokPlaceService: Sendable {
    private let session: URLSession
    private let apiKey: String
    private let model = "grok-4.3"

    init(session: URLSession = GrokPlaceService.makeSession(), apiKey: String = Secrets.xaiAPIKey) {
        self.session = session
        self.apiKey = apiKey
    }

    func enrich(place: Place) async throws -> PlaceEnrichment {
        guard !apiKey.isEmpty else {
            throw GrokPlaceError.missingAPIKey
        }

        let nowKST = Self.kstTimestamp()
        let requestBody = GrokResponsesRequest(
            model: model,
            store: false,
            input: [
                .init(
                    role: "system",
                    content: """
                    You enrich Korean local place info for a Gumi (구미), Gyeongsangbuk-do map app.
                    Use web search to find up-to-date facts about the exact place.
                    Reply only with JSON matching the schema. All user-facing strings must be Korean.
                    If search results are insufficient, keep claims conservative and set hour fields to null.
                    """
                ),
                .init(
                    role: "user",
                    content: Self.userPrompt(for: place, nowKST: nowKST)
                ),
            ],
            tools: [
                .init(
                    type: "web_search",
                    filters: .init(
                        allowedDomains: [
                            "place.map.kakao.com",
                            "map.kakao.com",
                            "map.naver.com",
                            "naver.me",
                            "m.place.naver.com",
                        ]
                    )
                ),
            ],
            text: .init(
                format: .init(
                    type: "json_schema",
                    name: "place_enrichment",
                    schema: .placeEnrichment,
                    strict: true
                )
            )
        )

        var request = URLRequest(url: URL(string: "https://api.x.ai/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GrokPlaceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let detail = Self.errorDetail(from: data)
            throw GrokPlaceError.httpStatus(httpResponse.statusCode, detail)
        }

        let decoded = try JSONDecoder().decode(GrokResponsesResponse.self, from: data)

        if let status = decoded.status, status != "completed" {
            throw GrokPlaceError.incompleteResponse
        }

        guard let content = Self.extractOutputText(from: decoded),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GrokPlaceError.emptyContent
        }

        let json = Self.extractJSON(from: content)
        return try JSONDecoder().decode(PlaceEnrichment.self, from: Data(json.utf8))
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 180
        return URLSession(configuration: configuration)
    }

    private static func userPrompt(for place: Place, nowKST: String) -> String {
        var lines = [
            "current_datetime_kst: \(nowKST)",
            "place_name: \(place.name)",
            "address: \(place.address)",
            "category: \(place.category)",
        ]

        if let phone = place.phone, !phone.isEmpty {
            lines.append("phone: \(phone)")
        }

        if let kakaoMapURL = place.kakaoMapURL?.absoluteString, !kakaoMapURL.isEmpty {
            lines.append("kakao_map_url: \(kakaoMapURL)")
        }

        lines.append("task: Search the web for this exact place in Gumi, Korea and return enrichment JSON.")
        return lines.joined(separator: "\n")
    }

    private static func extractOutputText(from response: GrokResponsesResponse) -> String? {
        response.output
            .reversed()
            .first(where: { $0.type == "message" })?
            .content?
            .reversed()
            .first(where: { $0.type == "output_text" })?
            .text
    }

    private static func extractJSON(from content: String) -> String {
        var trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("```") {
            trimmed = trimmed
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed
    }

    private static func errorDetail(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }

        if let error = object["error"] as? [String: Any] {
            return (error["message"] as? String) ?? (error["code"] as? String)
        }

        return (object["message"] as? String) ?? (object["detail"] as? String)
    }

    private static func kstTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: .now)
    }
}

private struct GrokResponsesRequest: Encodable {
    let model: String
    let store: Bool
    let input: [GrokInputMessage]
    let tools: [GrokWebSearchTool]
    let text: GrokTextConfig
}

private struct GrokInputMessage: Encodable {
    let role: String
    let content: String
}

private struct GrokWebSearchTool: Encodable {
    let type: String
    let filters: GrokWebSearchFilters?

    init(type: String, filters: GrokWebSearchFilters? = nil) {
        self.type = type
        self.filters = filters
    }
}

private struct GrokWebSearchFilters: Encodable {
    let allowedDomains: [String]

    enum CodingKeys: String, CodingKey {
        case allowedDomains = "allowed_domains"
    }
}

private struct GrokTextConfig: Encodable {
    let format: GrokTextFormat
}

private struct GrokTextFormat: Encodable {
    let type: String
    let name: String
    let schema: GrokJSONSchema
    let strict: Bool
}

private struct GrokJSONSchema: Encodable {
    let type: String
    let properties: GrokJSONSchemaProperties
    let required: [String]
    let additionalProperties: Bool
}

private struct GrokJSONSchemaProperties: Encodable {
    let summary: GrokJSONStringProperty
    let highlights: GrokJSONArrayProperty
    let visitTip: GrokJSONStringProperty
    let isClosedToday: GrokJSONBooleanProperty
    let todayOpen: GrokJSONNullableStringProperty
    let todayClose: GrokJSONNullableStringProperty

    enum CodingKeys: String, CodingKey {
        case summary
        case highlights
        case visitTip = "visit_tip"
        case isClosedToday = "is_closed_today"
        case todayOpen = "today_open"
        case todayClose = "today_close"
    }
}

private struct GrokJSONStringProperty: Encodable {
    let type = "string"
    let description: String
}

private struct GrokJSONArrayProperty: Encodable {
    let type = "array"
    let items: GrokJSONStringProperty
    let maxItems = 3
    let description: String
}

private struct GrokJSONBooleanProperty: Encodable {
    let type = "boolean"
    let description: String
}

private struct GrokJSONNullableStringProperty: Encodable {
    let type: [String]
    let description: String
}

private extension GrokJSONSchema {
    static let placeEnrichment = GrokJSONSchema(
        type: "object",
        properties: GrokJSONSchemaProperties(
            summary: .init(description: "1-2 sentence Korean summary of the place"),
            highlights: .init(
                items: .init(description: "Short Korean highlight"),
                description: "Up to 3 short Korean highlights"
            ),
            visitTip: .init(description: "One short Korean visit tip"),
            isClosedToday: .init(description: "True if the place is closed all day today in Korea"),
            todayOpen: .init(
                type: ["string", "null"],
                description: "Today's opening time in 24h HH:mm KST, or null if unknown"
            ),
            todayClose: .init(
                type: ["string", "null"],
                description: "Today's closing time in 24h HH:mm KST, or null if unknown"
            )
        ),
        required: [
            "summary",
            "highlights",
            "visit_tip",
            "is_closed_today",
            "today_open",
            "today_close",
        ],
        additionalProperties: false
    )
}

private struct GrokResponsesResponse: Decodable {
    let status: String?
    let output: [GrokOutputItem]
}

private struct GrokOutputItem: Decodable {
    let type: String
    let content: [GrokOutputContent]?
}

private struct GrokOutputContent: Decodable {
    let type: String
    let text: String?
}