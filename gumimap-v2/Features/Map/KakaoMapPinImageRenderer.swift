import UIKit

enum KakaoMapPinImageRenderer {
    private static let renderScale: CGFloat = 2
    private static let canvasSize = CGSize(width: 36, height: 44)
    private static let headRadiusRatio: CGFloat = 0.42
    private static let strokeWidth: CGFloat = 2.5

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
            let pinPath = teardropPath(in: CGRect(origin: .zero, size: canvasSize))

            cgContext.setShadow(
                offset: CGSize(width: 0, height: 2),
                blur: 4,
                color: UIColor.black.withAlphaComponent(0.2).cgColor
            )
            tint.setFill()
            pinPath.fill()

            cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            ringColor.setStroke()
            pinPath.lineWidth = strokeWidth
            pinPath.stroke()

            let headRadius = canvasSize.width * headRadiusRatio
            let headCenter = CGPoint(x: canvasSize.width / 2, y: headRadius + 2)
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            if let symbol = UIImage(systemName: symbolName, withConfiguration: symbolConfig)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let symbolOrigin = CGPoint(
                    x: headCenter.x - symbol.size.width / 2,
                    y: headCenter.y - symbol.size.height / 2 - 1
                )
                symbol.draw(at: symbolOrigin)
            }
        }

        return pngImage(from: rendered) ?? rendered
    }

    static func styleID(listKind: ListSubTab, category: String) -> String {
        let symbol = PlaceCategoryIcon.symbol(for: category)
        return "saved-pin-v4-teardrop-\(listKind.rawValue)-\(symbol)"
    }

    private static func teardropPath(in rect: CGRect) -> UIBezierPath {
        let radius = rect.width * headRadiusRatio
        let centerX = rect.midX
        let centerY = radius + 2
        let tip = CGPoint(x: centerX, y: rect.maxY - 0.5)

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