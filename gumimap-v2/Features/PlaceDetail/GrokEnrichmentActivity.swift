import Foundation

struct GrokEnrichmentActivity: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String?
    let sources: [String]
    let isInProgress: Bool
    let symbolName: String

    init(
        id: String,
        title: String,
        detail: String? = nil,
        sources: [String] = [],
        isInProgress: Bool = false,
        symbolName: String = "circle"
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.sources = sources
        self.isInProgress = isInProgress
        self.symbolName = symbolName
    }
}