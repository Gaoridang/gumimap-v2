import Foundation

struct ListHeaderSegment: Codable, Sendable, Equatable {
    let text: String
    let emphasis: Bool
}

struct ListHeaderPrompt: Equatable, Sendable {
    let segments: [ListHeaderSegment]

    var fullText: String {
        segments.map(\.text).joined()
    }
}