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

    static func fallback(for subTab: ListSubTab) -> ListHeaderPrompt {
        switch subTab {
        case .visited:
            ListHeaderPrompt(segments: [
                ListHeaderSegment(text: "지금까지 ", emphasis: false),
                ListHeaderSegment(text: "다녀온 장소", emphasis: true),
                ListHeaderSegment(text: ", 어땠나요?", emphasis: false),
            ])
        case .wishlist:
            ListHeaderPrompt(segments: [
                ListHeaderSegment(text: "다음에 ", emphasis: false),
                ListHeaderSegment(text: "가보고 싶은 곳", emphasis: true),
                ListHeaderSegment(text: "이에요", emphasis: false),
            ])
        }
    }

    static func validated(from response: ListHeaderPromptResponse) -> ListHeaderPrompt? {
        let trimmedSegments = response.segments
            .map { ListHeaderSegment(text: $0.text, emphasis: $0.emphasis) }
            .filter { !$0.text.isEmpty }

        guard !trimmedSegments.isEmpty else { return nil }

        let fullText = trimmedSegments.map(\.text).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !fullText.isEmpty, fullText.count <= 48 else { return nil }
        guard trimmedSegments.contains(where: \.emphasis) else { return nil }

        return ListHeaderPrompt(segments: trimmedSegments)
    }
}

struct ListHeaderPromptResponse: Codable, Sendable {
    let segments: [ListHeaderSegment]
}