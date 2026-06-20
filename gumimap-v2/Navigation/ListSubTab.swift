import Foundation

enum ListSubTab: String, Hashable, CaseIterable {
    case visited
    case wishlist

    var title: String {
        switch self {
        case .visited:
            "가본 곳"
        case .wishlist:
            "가고 싶은 곳"
        }
    }

    var listHeaderPrompt: String {
        switch self {
        case .visited:
            "지금까지 다녀온 장소, 어땠나요?"
        case .wishlist:
            "다음에 가보고 싶은 곳이에요"
        }
    }
}