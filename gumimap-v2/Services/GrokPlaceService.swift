import CoreLocation
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

    func enrich(
        place: Place,
        onActivity: (@MainActor (GrokEnrichmentPhase) -> Void)? = nil
    ) async throws -> PlaceEnrichment {
        guard !apiKey.isEmpty else {
            throw GrokPlaceError.missingAPIKey
        }

        let nowKST = Self.kstTimestamp()
        let requestBody = GrokResponsesRequest(
            model: model,
            store: false,
            stream: true,
            temperature: 0.2,
            input: [
                .init(
                    role: "system",
                    content: """
                    You enrich Korean local place info for a Gumi (구미), Gyeongsangbuk-do map app.
                    Use web search aggressively to verify facts about the exact place.
                    Prioritize Korean local sources in this order:
                    1) place.map.kakao.com / map.kakao.com
                    2) map.naver.com / m.place.naver.com / naver.me
                    3) Korean blogs/reviews only when map pages are unavailable
                    Open map pages when found. Do not guess hours or features.
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
                .init(type: "web_search"),
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
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let tracker = StreamActivityTracker(placeName: place.name, onActivity: onActivity)

        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GrokPlaceError.invalidResponse
        }

        var errorBody = Data()
        if !(200...299).contains(httpResponse.statusCode) {
            for try await byte in bytes {
                errorBody.append(byte)
            }
            let detail = Self.errorDetail(from: errorBody)
            throw GrokPlaceError.httpStatus(httpResponse.statusCode, detail)
        }

        var outputText = ""
        var eventDataLines: [String] = []

        for try await line in bytes.lines {
            try Task.checkCancellation()

            if line.isEmpty {
                if let event = Self.parseStreamEvent(from: eventDataLines) {
                    try await Self.handleStreamEvent(
                        event,
                        tracker: tracker,
                        outputText: &outputText
                    )
                }
                eventDataLines.removeAll(keepingCapacity: true)
                continue
            }

            if line.hasPrefix("data:") {
                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if payload != "[DONE]" {
                    eventDataLines.append(String(payload))
                }
            }
        }

        if let event = Self.parseStreamEvent(from: eventDataLines) {
            try await Self.handleStreamEvent(
                event,
                tracker: tracker,
                outputText: &outputText
            )
        }

        guard !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GrokPlaceError.emptyContent
        }

        await tracker.markComposing(inProgress: false)

        let json = Self.extractJSON(from: outputText)
        return try JSONDecoder().decode(PlaceEnrichment.self, from: Data(json.utf8))
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 180
        configuration.timeoutIntervalForResource = 240
        return URLSession(configuration: configuration)
    }

    private static func userPrompt(for place: Place, nowKST: String) -> String {
        var lines = [
            "current_datetime_kst: \(nowKST)",
            "place_name: \(place.name)",
            "address: \(place.address)",
            "category: \(place.category)",
            "latitude: \(place.coordinate.latitude)",
            "longitude: \(place.coordinate.longitude)",
        ]

        if let phone = place.phone, !phone.isEmpty {
            lines.append("phone: \(phone)")
        }

        if let kakaoMapURL = place.kakaoMapURL?.absoluteString, !kakaoMapURL.isEmpty {
            lines.append("kakao_map_url: \(kakaoMapURL)")
        }

        lines.append(
            """
            search_instructions:
            - Confirm this exact place is in Gumi, Gyeongsangbuk-do using address and coordinates.
            - If kakao_map_url is present, search and open that Kakao place page first.
            - Run Korean queries like "{place_name} \(place.address) 영업시간" and "site:place.map.kakao.com {place.name}".
            - Prefer verified map-page facts for hours, menu, and highlights.
            - Return enrichment JSON after searching.
            """
        )

        return lines.joined(separator: "\n")
    }

    private static func parseStreamEvent(from dataLines: [String]) -> [String: Any]? {
        guard let jsonLine = dataLines.last,
              let data = jsonLine.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private static func handleStreamEvent(
        _ event: [String: Any],
        tracker: StreamActivityTracker,
        outputText: inout String
    ) async throws {
        guard let type = event["type"] as? String else { return }

        switch type {
        case "response.created":
            await tracker.markPreparingComplete()

        case "response.reasoning_summary_text.delta":
            if let delta = event["delta"] as? String {
                await tracker.appendReasoning(delta)
            }

        case "response.output_item.added":
            if let item = event["item"] as? [String: Any] {
                await tracker.handleOutputItemAdded(item)
            }

        case "response.output_item.done":
            if let item = event["item"] as? [String: Any] {
                await tracker.handleOutputItemDone(item)
            }

        case "response.web_search_call.searching":
            if let itemID = event["item_id"] as? String {
                await tracker.markWebActivitySearching(itemID: itemID)
            }

        case "response.output_text.delta":
            if let delta = event["delta"] as? String {
                outputText += delta
                await tracker.markComposing(inProgress: true)
            }

        case "response.completed":
            if outputText.isEmpty,
               let response = event["response"] as? [String: Any],
               let text = extractOutputText(from: response) {
                outputText = text
            }

        default:
            break
        }
    }

    private static func extractOutputText(from responseObject: [String: Any]) -> String? {
        guard let output = responseObject["output"] as? [[String: Any]] else { return nil }

        for message in output.reversed() where (message["type"] as? String) == "message" {
            guard let content = message["content"] as? [[String: Any]] else { continue }
            for part in content.reversed() where (part["type"] as? String) == "output_text" {
                if let text = part["text"] as? String {
                    return text
                }
            }
        }

        return nil
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

@MainActor
private final class StreamActivityTracker {
    private let placeName: String
    private let onActivity: ((GrokEnrichmentPhase) -> Void)?
    private var reasoningText = ""
    private var webActivityKinds: [String: GrokEnrichmentPhaseKind] = [:]

    init(placeName: String, onActivity: ((GrokEnrichmentPhase) -> Void)?) {
        self.placeName = placeName
        self.onActivity = onActivity
        emit(
            GrokEnrichmentPhase(
                id: "preparing",
                kind: .preparing,
                status: .inProgress,
                detail: nil,
                resultCount: 0,
                sourceHosts: []
            )
        )
    }

    func markPreparingComplete() {
        emit(
            GrokEnrichmentPhase(
                id: "preparing",
                kind: .preparing,
                status: .completed,
                detail: nil,
                resultCount: 0,
                sourceHosts: []
            )
        )
        emit(
            GrokEnrichmentPhase(
                id: "analyzing",
                kind: .analyzing,
                status: .inProgress,
                detail: placeName,
                resultCount: 0,
                sourceHosts: []
            )
        )
    }

    func appendReasoning(_ delta: String) {
        reasoningText += delta
        emit(
            GrokEnrichmentPhase(
                id: "analyzing",
                kind: .analyzing,
                status: .inProgress,
                detail: Self.truncated(reasoningText, limit: 120),
                resultCount: 0,
                sourceHosts: []
            )
        )
    }

    func handleOutputItemAdded(_ item: [String: Any]) {
        let itemType = item["type"] as? String

        if itemType == "reasoning" {
            emit(
                GrokEnrichmentPhase(
                    id: "analyzing",
                    kind: .analyzing,
                    status: .inProgress,
                    detail: placeName,
                    resultCount: 0,
                    sourceHosts: []
                )
            )
            return
        }

        guard itemType == "web_search_call",
              let itemID = item["id"] as? String else {
            return
        }

        let actionType = (item["action"] as? [String: Any])?["type"] as? String ?? "search"
        let kind: GrokEnrichmentPhaseKind = actionType == "open_page" ? .pageReview : .webSearch
        webActivityKinds[itemID] = kind

        let detail: String? = {
            if kind == .pageReview,
               let url = (item["action"] as? [String: Any])?["url"] as? String {
                return Self.displayHost(url)
            }
            let query = ((item["action"] as? [String: Any])?["query"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let query, !query.isEmpty {
                return "\"\(query)\""
            }
            return kind == .webSearch ? "\"\(placeName)\"" : nil
        }()

        emit(webPhase(id: itemID, kind: kind, status: .inProgress, detail: detail))
    }

    func markWebActivitySearching(itemID: String) {
        let kind = webActivityKinds[itemID] ?? .webSearch
        let existingDetail = kind == .webSearch ? "\"\(placeName)\"" : nil
        emit(webPhase(id: itemID, kind: kind, status: .inProgress, detail: existingDetail))
    }

    func handleOutputItemDone(_ item: [String: Any]) {
        let itemType = item["type"] as? String

        if itemType == "reasoning" {
            let summary = (item["summary"] as? [[String: Any]])?.first?["text"] as? String
            let detail = summary.flatMap { Self.truncated($0, limit: 120) } ?? placeName
            emit(
                GrokEnrichmentPhase(
                    id: "analyzing",
                    kind: .analyzing,
                    status: .completed,
                    detail: detail,
                    resultCount: 0,
                    sourceHosts: []
                )
            )
            return
        }

        guard itemType == "web_search_call",
              let action = item["action"] as? [String: Any],
              let itemID = item["id"] as? String else {
            return
        }

        let actionType = action["type"] as? String ?? "search"
        let sourceHosts = Self.sourceHosts(from: action["sources"] as? [[String: Any]] ?? [])

        switch actionType {
        case "open_page":
            webActivityKinds[itemID] = .pageReview
            if let url = action["url"] as? String {
                let host = Self.displayHost(url)
                emit(
                    GrokEnrichmentPhase(
                        id: itemID,
                        kind: .pageReview,
                        status: .completed,
                        detail: host,
                        resultCount: 0,
                        sourceHosts: [host]
                    )
                )
            }

        default:
            webActivityKinds[itemID] = .webSearch
            let query = (action["query"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedQuery = (query?.isEmpty == false) ? query! : placeName
            emit(
                GrokEnrichmentPhase(
                    id: itemID,
                    kind: .webSearch,
                    status: .completed,
                    detail: "\"\(resolvedQuery)\"",
                    resultCount: sourceHosts.count,
                    sourceHosts: Array(sourceHosts.prefix(3))
                )
            )
        }
    }

    func markComposing(inProgress: Bool) {
        emit(
            GrokEnrichmentPhase(
                id: "composing",
                kind: .composing,
                status: inProgress ? .inProgress : .completed,
                detail: inProgress ? "검색한 내용을 바탕으로 장소 소개를 작성하고 있어요" : nil,
                resultCount: 0,
                sourceHosts: []
            )
        )
    }

    private func webPhase(
        id: String,
        kind: GrokEnrichmentPhaseKind,
        status: GrokEnrichmentPhaseStatus,
        detail: String? = nil
    ) -> GrokEnrichmentPhase {
        GrokEnrichmentPhase(
            id: id,
            kind: kind,
            status: status,
            detail: detail,
            resultCount: 0,
            sourceHosts: []
        )
    }

    private func emit(_ phase: GrokEnrichmentPhase) {
        onActivity?(phase)
    }

    private static func truncated(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "…"
    }

    private static func sourceHosts(from sources: [[String: Any]]) -> [String] {
        sources.compactMap { source in
            guard let url = source["url"] as? String else { return nil }
            return displayHost(url)
        }
    }

    private static func displayHost(_ urlString: String) -> String {
        guard let host = URL(string: urlString)?.host?.replacingOccurrences(of: "www.", with: "") else {
            return urlString
        }
        return host
    }
}

private struct GrokResponsesRequest: Encodable {
    let model: String
    let store: Bool
    let stream: Bool
    let temperature: Double
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