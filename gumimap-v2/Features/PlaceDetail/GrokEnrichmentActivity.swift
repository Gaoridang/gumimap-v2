import Foundation

struct GrokSearchStep: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case webSearch
        case openPage
    }

    let id: String
    let kind: Kind
    let query: String?
    let pageHost: String?
    let resultCount: Int
    let sourceHosts: [String]
    let isInProgress: Bool

    var title: String {
        switch kind {
        case .webSearch:
            isInProgress ? "Searching web" : "Searched web"
        case .openPage:
            isInProgress ? "Opening page" : "Opened page"
        }
    }

    var subtitle: String? {
        switch kind {
        case .webSearch:
            guard let query, !query.isEmpty else { return nil }
            return "\"\(query)\""
        case .openPage:
            return pageHost
        }
    }

    var resultLabel: String? {
        guard kind == .webSearch, resultCount > 0 else { return nil }
        return resultCount == 1 ? "1 result" : "\(resultCount) results"
    }
}