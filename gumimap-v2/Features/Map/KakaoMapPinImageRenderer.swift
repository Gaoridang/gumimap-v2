import SwiftUI
import UIKit

enum KakaoMapPinImageRenderer {
    @MainActor
    static func image(listKind: ListSubTab, category: String) -> UIImage {
        let content = SavedPlaceMapPin(listKind: listKind, category: category)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3

        if let uiImage = renderer.uiImage {
            return uiImage
        }

        return UIImage(systemName: "mappin.circle.fill") ?? UIImage()
    }

    static func styleID(listKind: ListSubTab, category: String) -> String {
        let symbol = PlaceCategoryIcon.symbol(for: category)
        return "saved-pin-\(listKind.rawValue)-\(symbol)"
    }
}