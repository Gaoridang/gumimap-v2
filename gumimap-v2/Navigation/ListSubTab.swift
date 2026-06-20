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
}