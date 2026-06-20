import Foundation

enum ListHeaderPromptLibrary {
    static let visited: [ListHeaderPrompt] = [
        make(
            ("지금까지 ", false), ("다녀온 장소", true), (", 어땠나요?", false)
        ),
        make(
            ("다녀온 곳", true), (", ", false), ("기억에 남는 순간", true), ("이 있나요?", false)
        ),
        make(
            ("한번쯤 ", false), ("다시 가고 싶은 곳", true), ("이 있나요?", false)
        ),
        make(
            ("그때 ", false), ("분위기", true), (", 아직도 생각나요?", false)
        ),
        make(
            ("가본 곳", true), (" 중에 ", false), ("마음에 든 곳", true), ("이 있나요?", false)
        ),
        make(
            ("오늘도 ", false), ("좋았던 장소", true), ("가 떠오르나요?", false)
        ),
        make(
            ("다녀온 장소", true), (", ", false), ("어떤 기억", true), ("이 남았나요?", false)
        ),
        make(
            ("혼자 갔던 곳", true), (", ", false), ("누군가랑 가고 싶은 곳", true), ("도 있나요?", false)
        ),
    ]

    static let wishlist: [ListHeaderPrompt] = [
        make(
            ("다음에 ", false), ("가보고 싶은 곳", true), ("이에요", false)
        ),
        make(
            ("언젠가 ", false), ("꼭 가보고 싶은 곳", true), ("들이에요", false)
        ),
        make(
            ("다음 주말", true), (", ", false), ("어디로 갈까요", true), ("?", false)
        ),
        make(
            ("가보고 싶은 곳", true), (", ", false), ("뭐부터 갈까요", true), ("?", false)
        ),
        make(
            ("기대되는 장소", true), ("가 ", false), ("모여 있어요", false)
        ),
        make(
            ("아직 안 가본 곳", true), (", ", false), ("설레지 않나요", true), ("?", false)
        ),
        make(
            ("곧 ", false), ("가볼 예정인 곳", true), ("들이에요", false)
        ),
        make(
            ("버킷리스트", true), ("에 ", false), ("올려둔 곳", true), ("들이에요", false)
        ),
    ]

    static func nextPrompt(for subTab: ListSubTab, excluding lastText: String?) -> ListHeaderPrompt {
        let pool = subTab == .visited ? visited : wishlist
        let candidates = pool.filter { $0.fullText != lastText }

        if let pick = candidates.randomElement() {
            return pick
        }

        return pool.randomElement() ?? pool[0]
    }

    private static func make(_ parts: (String, Bool)...) -> ListHeaderPrompt {
        ListHeaderPrompt(segments: parts.map { ListHeaderSegment(text: $0.0, emphasis: $0.1) })
    }
}