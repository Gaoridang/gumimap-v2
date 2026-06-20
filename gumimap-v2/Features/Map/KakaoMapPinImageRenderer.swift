import UIKit

enum KakaoMapPinImageRenderer {
    private static let renderScale: CGFloat = 2
    private static let canvasSize = CGSize(width: 28, height: 26)
    private static let headDiameter: CGFloat = 20
    private static let tailHeight: CGFloat = 5
    private static let tailHalfWidth: CGFloat = 4

    static func image(listKind: ListSubTab, category: String) -> UIImage {
        let fillColor = listKindColor(for: listKind)

        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = false
        format.preferredRange = .standard

        let rendered = UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            let cgContext = context.cgContext
            let pinPath = pinPath(in: CGRect(origin: .zero, size: canvasSize))

            cgContext.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 2,
                color: UIColor.black.withAlphaComponent(0.16).cgColor
            )
            fillColor.setFill()
            pinPath.fill()
        }

        return pngImage(from: rendered) ?? rendered
    }

    static func styleID(listKind: ListSubTab, category: String) -> String {
        "saved-pin-v7-short-\(listKind.rawValue)"
    }

    private static func pinPath(in rect: CGRect) -> UIBezierPath {
        let centerX = rect.midX
        let headRadius = headDiameter / 2
        let headCenterY = headRadius
        let headRect = CGRect(
            x: centerX - headRadius,
            y: headCenterY - headRadius,
            width: headDiameter,
            height: headDiameter
        )
        let tailTopY = headRect.maxY - 1
        let tipY = tailTopY + tailHeight

        let path = UIBezierPath(ovalIn: headRect)
        let tail = UIBezierPath()
        tail.move(to: CGPoint(x: centerX - tailHalfWidth, y: tailTopY))
        tail.addLine(to: CGPoint(x: centerX + tailHalfWidth, y: tailTopY))
        tail.addLine(to: CGPoint(x: centerX, y: tipY))
        tail.close()
        path.append(tail)
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