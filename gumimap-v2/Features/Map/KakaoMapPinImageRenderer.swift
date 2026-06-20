import UIKit

enum KakaoMapPinImageRenderer {
    private static let renderScale: CGFloat = 2
    private static let canvasSize = CGSize(width: 32, height: 40)
    private static let headRadiusRatio: CGFloat = 0.44

    static func image(listKind: ListSubTab, category: String) -> UIImage {
        let fillColor = listKindColor(for: listKind)

        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = false
        format.preferredRange = .standard

        let rendered = UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            let cgContext = context.cgContext
            let pinPath = teardropPath(in: CGRect(origin: .zero, size: canvasSize))

            cgContext.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 2,
                color: UIColor.black.withAlphaComponent(0.18).cgColor
            )
            fillColor.setFill()
            pinPath.fill()
        }

        return pngImage(from: rendered) ?? rendered
    }

    static func styleID(listKind: ListSubTab, category: String) -> String {
        "saved-pin-v5-solid-\(listKind.rawValue)"
    }

    private static func teardropPath(in rect: CGRect) -> UIBezierPath {
        let radius = rect.width * headRadiusRatio
        let centerX = rect.midX
        let centerY = radius + 2
        let tip = CGPoint(x: centerX, y: rect.maxY)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: centerX - radius, y: centerY))
        path.addArc(
            withCenter: CGPoint(x: centerX, y: centerY),
            radius: radius,
            startAngle: .pi,
            endAngle: 0,
            clockwise: false
        )
        path.addLine(to: tip)
        path.close()
        return path
    }

    private static func listKindColor(for listKind: ListSubTab) -> UIColor {
        switch listKind {
        case .visited: .systemGreen
        case .wishlist: .systemBlue
        }
    }

    /// KakaoMapsSDK reads PNG bytes internally; round-tripping avoids unsupported bitmap layouts.
    private static func pngImage(from image: UIImage) -> UIImage? {
        guard let data = image.pngData() else { return nil }
        return UIImage(data: data, scale: renderScale)
    }
}