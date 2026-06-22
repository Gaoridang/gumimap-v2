import UIKit

enum KakaoMapPinImageRenderer {
    private static let renderScale: CGFloat = 3

    static func image(listKind: ListSubTab, category: String) -> UIImage {
        let colors = MapPinStyle.colors(for: listKind)

        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = false
        format.preferredRange = .standard

        let rendered = UIGraphicsImageRenderer(size: MapPinLayout.canvasSize, format: format).image { _ in
            let pinPath = MapPinLayout.uiBezierPath(in: MapPinLayout.contentRect)
            colors.fill.setFill()
            pinPath.fill()
            colors.border.setStroke()
            pinPath.lineWidth = MapPinStyle.borderWidth
            pinPath.lineJoinStyle = .round
            pinPath.stroke()
        }

        return pngImage(from: rendered) ?? rendered
    }

    static func styleID(listKind: ListSubTab, category: String) -> String {
        "saved-pin-v10-yellow-\(listKind.rawValue)"
    }

    /// KakaoMapsSDK reads PNG bytes internally; round-tripping avoids unsupported bitmap layouts.
    private static func pngImage(from image: UIImage) -> UIImage? {
        guard let data = image.pngData() else { return nil }
        return UIImage(data: data, scale: renderScale)
    }
}