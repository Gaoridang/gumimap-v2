import Foundation

enum GrokListHeaderError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey, .invalidResponse, .decodingFailed:
            "목록 문구를 불러오지 못했어요."
        case .apiError:
            "목록 문구를 불러오지 못했어요."
        }
    }
}

struct GrokListHeaderService: Sendable {
    private let apiKey: String
    private let session: URLSession
    private let endpoint = URL(string: "https://api.x.ai/v1/responses")!

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    static func makeFromSecrets() throws -> GrokListHeaderService {
        guard Secrets.isGrokConfigured else {
            throw GrokListHeaderError.missingAPIKey
        }
        return GrokListHeaderService(apiKey: Secrets.xaiAPIKey)
    }

    func generatePrompt(subTab: ListSubTab, placeCount: Int) async throws -> ListHeaderPrompt {
        let variationID = UUID().uuidString.prefix(8)
        let listContext = subTab == .visited ? "가본 곳 (visited)" : "가고 싶은 곳 (wishlist)"

        let response: ListHeaderPromptResponse = try await execute(
            systemPrompt: Self.systemPrompt,
            userPrompt: """
            List: \(listContext)
            Saved place count: \(placeCount)
            Variation id: \(variationID)

            Write a fresh one-line Korean header. Wording must differ from previous variations.
            """
        )

        guard let prompt = ListHeaderPrompt.validated(from: response) else {
            throw GrokListHeaderError.decodingFailed
        }

        return prompt
    }

    private func execute(systemPrompt: String, userPrompt: String) async throws -> ListHeaderPromptResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try makeRequestBody(systemPrompt: systemPrompt, userPrompt: userPrompt)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GrokListHeaderError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GrokListHeaderError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        let apiResponse = try JSONDecoder().decode(ListHeaderResponsesAPIResponse.self, from: data)

        if let error = apiResponse.error {
            throw GrokListHeaderError.apiError(
                statusCode: 0,
                message: "\(error.code): \(error.message)"
            )
        }

        guard let jsonText = apiResponse.outputText,
              let contentData = jsonText.data(using: .utf8) else {
            throw GrokListHeaderError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(ListHeaderPromptResponse.self, from: contentData)
        } catch {
            throw GrokListHeaderError.decodingFailed
        }
    }

    private func makeRequestBody(systemPrompt: String, userPrompt: String) throws -> Data {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "segments": [
                    "type": "array",
                    "description": "Ordered text fragments that concatenate into one Korean sentence",
                    "items": [
                        "type": "object",
                        "properties": [
                            "text": [
                                "type": "string",
                                "description": "Substring including spaces and punctuation",
                            ],
                            "emphasis": [
                                "type": "boolean",
                                "description": "true for meaningful words; false for particles and fillers",
                            ],
                        ],
                        "required": ["text", "emphasis"],
                        "additionalProperties": false,
                    ],
                    "minItems": 2,
                    "maxItems": 8,
                ],
            ],
            "required": ["segments"],
            "additionalProperties": false,
        ]

        let body: [String: Any] = [
            "model": "grok-4.3",
            "store": false,
            "stream": false,
            "max_output_tokens": 256,
            "reasoning": ["effort": "none"],
            "input": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt],
            ],
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "list_header_prompt",
                    "schema": schema,
                    "strict": true,
                ],
            ],
        ]

        return try JSONSerialization.data(withJSONObject: body)
    }

    private static let systemPrompt = """
    You write one short Korean header line for a saved-places list in a local map app in Gumi.

    Return JSON only:
    • segments: ordered array of { text, emphasis }

    Concatenated segments must form one natural sentence (max ~30 Korean characters).
    emphasis=true for content words the user should notice (nouns, verbs, key adjectives).
    emphasis=false for particles, endings, connectors, commas, and light fillers
    (e.g. 지금까지, 은/는/이/가, 에요, 할까요, ?, ,).

    Tone:
    • visited list — warm reflection on places already gone
    • wishlist — gentle anticipation about places to visit soon

    Rules:
    • Vary wording every request; avoid repeating common templates
    • No emoji, no quotation marks, no place names
    • At least one emphasis=true segment
    """
}

// MARK: - Response DTOs

private struct ListHeaderResponsesAPIResponse: Decodable {
    let output: [ListHeaderOutputItem]?
    let error: ListHeaderAPIErrorBody?

    struct ListHeaderAPIErrorBody: Decodable {
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

private struct ListHeaderOutputItem: Decodable {
    let type: String
    let content: [ListHeaderOutputContent]?
}

private struct ListHeaderOutputContent: Decodable {
    let type: String
    let text: String?
}