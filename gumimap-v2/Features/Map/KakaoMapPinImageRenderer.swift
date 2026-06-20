import SwiftUI
import UIKit

enum KakaoMapPinImageRenderer {
    private static let renderScale: CGFloat = 2
    private static let canvasSize = CGSize(width: 44, height: 50)

    @MainActor
    static func image(listKind: ListSubTab, category: String) -> UIImage {
        let pin = SavedPlaceMapPin(listKind: listKind, category: category)
            .frame(width: canvasSize.width, height: canvasSize.height)

        let renderer = ImageRenderer(content: pin)
        renderer.scale = renderScale
        renderer.isOpaque = false

        guard let rendered = renderer.uiImage else {
            return UIImage()
        }

        return pngImage(from: rendered) ?? rendered
    }

    static func styleID(listKind: ListSubTab, category: String) -> String {
        let symbol = PlaceCategoryIcon.symbol(for: category)
        return "saved-pin-v2-\(listKind.rawValue)-\(symbol)"
    }

    /// KakaoMapsSDK reads PNG bytes internally; round-tripping avoids unsupported bitmap layouts.
    private static func pngImage(from image: UIImage) -> UIImage? {
        guard let data = image.pngData() else { return nil }
        return UIImage(data: data, scale: renderScale)
    }
}