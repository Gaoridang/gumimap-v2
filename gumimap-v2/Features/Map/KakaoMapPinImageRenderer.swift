import UIKit

enum KakaoMapPinImageRenderer {
    private static let renderScale: CGFloat = 2
    private static let canvasSize = CGSize(width: 44, height: 50)
    private static let bubbleSize: CGFloat = 38
    private static let bubbleCornerRadius: CGFloat = 11
    private static let innerCornerRadius: CGFloat = 8
    private static let innerSize: CGFloat = 28
    private static let pointerWidth: CGFloat = 14
    private static let pointerHeight: CGFloat = 8

    static func image(listKind: ListSubTab, category: String) -> UIImage {
        let symbolName = PlaceCategoryIcon.symbol(for: category)
        let tint = PlaceCategoryIcon.uiTint(for: category)

        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = false
        format.preferredRange = .standard

        let rendered = UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            let cgContext = context.cgContext
            let bubbleRect = CGRect(
                x: (canvasSize.width - bubbleSize) / 2,
                y: 0,
                width: bubbleSize,
                height: bubbleSize
            )

            cgContext.setShadow(
                offset: CGSize(width: 0, height: 2),
                blur: 5,
                color: UIColor.black.withAlphaComponent(0.16).cgColor
            )
            let bubblePath = UIBezierPath(
                roundedRect: bubbleRect,
                cornerRadius: bubbleCornerRadius
            )
            UIColor.white.setFill()
            bubblePath.fill()
            cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            tint.withAlphaComponent(0.4).setStroke()
            bubblePath.lineWidth = 1.5
            bubblePath.stroke()

            let innerRect = CGRect(
                x: bubbleRect.midX - innerSize / 2,
                y: bubbleRect.midY - innerSize / 2,
                width: innerSize,
                height: innerSize
            )
            let innerPath = UIBezierPath(
                roundedRect: innerRect,
                cornerRadius: innerCornerRadius
            )
            tint.withAlphaComponent(0.14).setFill()
            innerPath.fill()

            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            if let symbol = UIImage(systemName: symbolName, withConfiguration: symbolConfig)?
                .withTintColor(tint, renderingMode: .alwaysOriginal) {
                let symbolOrigin = CGPoint(
                    x: bubbleRect.midX - symbol.size.width / 2,
                    y: bubbleRect.midY - symbol.size.height / 2
                )
                symbol.draw(at: symbolOrigin)
            }

            drawListKindBadge(listKind, bubbleRect: bubbleRect)

            let pointerTopY = bubbleRect.maxY - 1
            let pointerRect = CGRect(
                x: bubbleRect.midX - pointerWidth / 2,
                y: pointerTopY,
                width: pointerWidth,
                height: pointerHeight
            )
            cgContext.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 2,
                color: UIColor.black.withAlphaComponent(0.1).cgColor
            )
            let pointerPath = UIBezierPath()
            pointerPath.move(to: CGPoint(x: pointerRect.minX, y: pointerRect.minY))
            pointerPath.addLine(to: CGPoint(x: pointerRect.maxX, y: pointerRect.minY))
            pointerPath.addLine(to: CGPoint(x: pointerRect.midX, y: pointerRect.maxY))
            pointerPath.close()
            UIColor.white.setFill()
            pointerPath.fill()
            cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        }

        return pngImage(from: rendered) ?? rendered
    }

    static func styleID(listKind: ListSubTab, category: String) -> String {
        let symbol = PlaceCategoryIcon.symbol(for: category)
        return "saved-pin-v2-\(listKind.rawValue)-\(symbol)"
    }

    private static func drawListKindBadge(_ listKind: ListSubTab, bubbleRect: CGRect) {
        switch listKind {
        case .visited:
            let badgeConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            guard let badge = UIImage(systemName: "checkmark.circle.fill", withConfiguration: badgeConfig)?
                .withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
            else { return }

            let origin = CGPoint(x: bubbleRect.maxX - 10, y: bubbleRect.minY - 7)
            UIColor.white.setFill()
            UIBezierPath(
                ovalIn: CGRect(origin: origin, size: badge.size).insetBy(dx: -1.5, dy: -1.5)
            ).fill()
            badge.draw(at: origin)

        case .wishlist:
            let badgeRect = CGRect(
                x: bubbleRect.maxX - 8,
                y: bubbleRect.minY - 4,
                width: 17,
                height: 17
            )
            let path = UIBezierPath(roundedRect: badgeRect, cornerRadius: 4)
            UIColor.systemBlue.setFill()
            path.fill()

            let badgeConfig = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            if let badge = UIImage(systemName: "bookmark.fill", withConfiguration: badgeConfig)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let origin = CGPoint(
                    x: badgeRect.midX - badge.size.width / 2,
                    y: badgeRect.midY - badge.size.height / 2
                )
                badge.draw(at: origin)
            }
        }
    }

    /// KakaoMapsSDK reads PNG bytes internally; round-tripping avoids unsupported bitmap layouts.
    private static func pngImage(from image: UIImage) -> UIImage? {
        guard let data = image.pngData() else { return nil }
        return UIImage(data: data, scale: renderScale)
    }
}