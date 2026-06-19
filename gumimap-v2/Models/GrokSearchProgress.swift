import Foundation

struct GrokSearchProgress: Sendable, Equatable {
    let message: String
    let detail: String?

    init(message: String, detail: String? = nil) {
        self.message = message
        self.detail = detail
    }
}