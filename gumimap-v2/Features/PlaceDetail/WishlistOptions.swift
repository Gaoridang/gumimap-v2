import Foundation

enum WishlistPriority: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "낮음"
        case .medium: "보통"
        case .high: "높음"
        }
    }
}

enum WishlistTag: String, CaseIterable, Identifiable {
    case date
    case solo
    case friends
    case family
    case cafe
    case food
    case walk
    case photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .date: "데이트"
        case .solo: "혼밥"
        case .friends: "친구"
        case .family: "가족"
        case .cafe: "카페"
        case .food: "맛집"
        case .walk: "산책"
        case .photo: "사진"
        }
    }
}