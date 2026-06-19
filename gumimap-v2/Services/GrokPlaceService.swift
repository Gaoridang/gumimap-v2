import Foundation

enum GrokPlaceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpStatus(Int)
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Grok API 키가 설정되지 않았습니다."
        case .invalidResponse:
            "장소 정보를 불러올 수 없습니다."
        case .httpStatus(let code):
            "장소 정보 요청에 실패했습니다. (HTTP \(code))"
        case .emptyContent:
            "장소 정보 응답이 비어 있습니다."
        }
    }
}

struct GrokPlaceService: Sendable {
    private let session: URLSession
    private let apiKey: String
    private let model = "grok-4-1-fast-non-reasoning"

    init(session: URLSession = .shared, apiKey: String = Secrets.xaiAPIKey) {
        self.session = session
        self.apiKey = apiKey
    }

    func enrich(place: Place) async throws -> PlaceEnrichment {
        guard !apiKey.isEmpty else {
            throw GrokPlaceError.missingAPIKey
        }

        let nowKST = Self.kstTimestamp()

        let requestBody = GrokChatRequest(
            model: model,
            temperature: 0.3,
            responseFormat: .jsonObject,
            messages: [
                .init(
                    role: "system",
                    content: """
                    You enrich Korean local place info for a Gumi city map app.
                    Reply only valid JSON with keys:
                    summary (string, 1-2 sentences Korean),
                    highlights (array of up to 3 short Korean strings),
                    visit_tip (string, one short Korean sentence),
                    is_closed_today (boolean, true if closed all day today),
                    today_open (string or null, 24h HH:mm for today's opening in Korea),
                    today_close (string or null, 24h HH:mm for today's closing in Korea; use next-day close for overnight hours).
                    Use the provided KST datetime to pick today's hours. If unsure, set hours fields to null.
                    """
                ),
                .init(
                    role: "user",
                    content: """
                    current_datetime_kst: \(nowKST)
                    place_name: \(place.name)
                    address: \(place.address)
                    category: \(place.category)
                    """
                ),
            ]
        )

        var request = URLRequest(url: URL(string: "https://api.x.ai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GrokPlaceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GrokPlaceError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(GrokChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GrokPlaceError.emptyContent
        }

        return try JSONDecoder().decode(PlaceEnrichment.self, from: Data(content.utf8))
    }

    private static func kstTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: .now)
    }
}

private struct GrokChatRequest: Encodable {
    let model: String
    let temperature: Double
    let responseFormat: ResponseFormat
    let messages: [GrokMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case temperature
        case responseFormat = "response_format"
        case messages
    }

    struct ResponseFormat: Encodable {
        let type: String

        static let jsonObject = ResponseFormat(type: "json_object")
    }
}

private struct GrokMessage: Encodable {
    let role: String
    let content: String
}

private struct GrokChatResponse: Decodable {
    let choices: [GrokChoice]
}

private struct GrokChoice: Decodable {
    let message: GrokResponseMessage
}

private struct GrokResponseMessage: Decodable {
    let content: String?
}