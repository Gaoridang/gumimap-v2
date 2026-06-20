import Foundation

enum AppRoute: Hashable {
    case search
    case placeDetail(Place)
    case savedPlaceDetail(id: String)
}