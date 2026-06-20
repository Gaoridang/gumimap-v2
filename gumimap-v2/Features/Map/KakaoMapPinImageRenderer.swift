import UIKit

enum KakaoMapPinImageRenderer {
    private static let renderScale: CGFloat = 2
    private static let canvasSize = CGSize(width: 36, height: 40)
    private static let circleSize: CGFloat = 30
    private static let ringWidth: CGFloat = 2
    private static let pointerWidth: CGFloat = 10
    private static let pointerHeight: CGFloat = 5

    static func image(listKind: ListSubTab, category: String) -> UIImage {
        let symbolName = PlaceCategoryIcon.symbol(for: category)
        let tint = PlaceCategoryIcon.uiTint(for: category)
        let ringColor = listKindColor(for: listKind)

        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = false
        format.preferredRange = .standard

        let rendered = UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            let cgContext = context.cgContext
            let circleRect = CGRect(
                x: (canvasSize.width - circleSize) / 2,
                y: 0,
                width: circleSize,
                height: circleSize
            )

            cgContext.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 3,
                color: UIColor.black.withAlphaComponent(0.12).cgColor
            )

            let fillPath = UIBezierPath(ovalIn: circleRect)
            tint.withAlphaComponent(0.15).setFill()
            fillPath.fill()

            cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            ringColor.setStroke()
            let ringPath = UIBezierPath(ovalIn: circleRect.insetBy(dx: ringWidth / 2, dy: ringWidth / 2))
            ringPath.lineWidth = ringWidth
            ringPath.stroke()

            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            if let symbol = UIImage(systemName: symbolName, withConfiguration: symbolConfig)?
                .withTintColor(tint, renderingMode: .alwaysOriginal) {
                let symbolOrigin = CGPoint(
                    x: circleRect.midX - symbol.size.width / 2,
                    y: circleRect.midY - symbol.size.height / 2
                )
                symbol.draw(at: symbolOrigin)
            }

            let pointerTopY = circleRect.maxY - 1
            let pointerRect = CGRect(
                x: circleRect.midX - pointerWidth / 2,
                y: pointerTopY,
                width: pointerWidth,
                height: pointerHeight
            )
            let pointerPath = UIBezierPath()
            pointerPath.move(to: CGPoint(x: pointerRect.minX, y: pointerRect.minY))
            pointerPath.addLine(to: CGPoint(x: pointerRect.maxX, y: pointerRect.minY))
            pointerPath.addLine(to: CGPoint(x: pointerRect.midX, y: pointerRect.maxY))
            pointerPath.close()
            tint.withAlphaComponent(0.15).setFill()
            pointerPath.fill()
        }

        return pngImage(from: rendered) ?? rendered
    }

    static func styleID(listKind: ListSubTab, category: String) -> String {
        let symbol = PlaceCategoryIcon.symbol(for: category)
        return "saved-pin-v3-\(listKind.rawValue)-\(symbol)"
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