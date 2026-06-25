import CoreGraphics
import SwiftUI
import UIKit

enum MapPinStyle {
    static let borderWidth: CGFloat = 2

    static let fillUIColor = UIColor(red: 0.98, green: 0.89, blue: 0.48, alpha: 1)
    static let borderUIColor = UIColor(red: 0.29, green: 0.52, blue: 0.78, alpha: 1)
    static let fillColor = Color(red: 0.98, green: 0.89, blue: 0.48)
    static let borderColor = Color(red: 0.29, green: 0.52, blue: 0.78)

    private static let visitedFillUIColor = UIColor(red: 0.82, green: 0.94, blue: 0.84, alpha: 1)
    private static let visitedBorderUIColor = UIColor(red: 0.18, green: 0.62, blue: 0.34, alpha: 1)
    private static let visitedFillColor = Color(red: 0.82, green: 0.94, blue: 0.84)
    private static let visitedBorderColor = Color(red: 0.18, green: 0.62, blue: 0.34)

    private static let wishlistFillUIColor = UIColor(red: 0.86, green: 0.92, blue: 0.99, alpha: 1)
    private static let wishlistBorderUIColor = UIColor(red: 0.22, green: 0.48, blue: 0.82, alpha: 1)
    private static let wishlistFillColor = Color(red: 0.86, green: 0.92, blue: 0.99)
    private static let wishlistBorderColor = Color(red: 0.22, green: 0.48, blue: 0.82)

    static func colors(for listKind: ListSubTab) -> (fill: UIColor, border: UIColor) {
        switch listKind {
        case .visited:
            (visitedFillUIColor, visitedBorderUIColor)
        case .wishlist:
            (wishlistFillUIColor, wishlistBorderUIColor)
        }
    }

    static func swiftUIColors(for listKind: ListSubTab) -> (fill: Color, border: Color) {
        switch listKind {
        case .visited:
            (visitedFillColor, visitedBorderColor)
        case .wishlist:
            (wishlistFillColor, wishlistBorderColor)
        }
    }
}

enum MapPinLayout {
    static let contentSize = CGSize(width: 28, height: 32)
    static let canvasPadding = UIEdgeInsets(top: 4, left: 3, bottom: 1, right: 3)
    static let headDiameter: CGFloat = 20
    static let headTopMargin: CGFloat = 6
    static let tailHeight: CGFloat = 5
    static let tailHalfWidth: CGFloat = 4

    static var canvasSize: CGSize {
        CGSize(
            width: contentSize.width + canvasPadding.left + canvasPadding.right,
            height: contentSize.height + canvasPadding.top + canvasPadding.bottom
        )
    }

    static var contentRect: CGRect {
        CGRect(
            x: canvasPadding.left,
            y: canvasPadding.top,
            width: contentSize.width,
            height: contentSize.height
        )
    }

    static func uiBezierPath(in rect: CGRect) -> UIBezierPath {
        let centerX = rect.midX
        let headRadius = headDiameter / 2
        let headCenterY = rect.minY + headTopMargin + headRadius
        let tipY = rect.maxY

        let joinY = headCenterY + sqrt(headRadius * headRadius - tailHalfWidth * tailHalfWidth)
        let leftJoin = CGPoint(x: centerX - tailHalfWidth, y: joinY)
        let tip = CGPoint(x: centerX, y: tipY)

        let leftAngle = CGFloat.pi - acos(tailHalfWidth / headRadius)
        let rightAngle = acos(tailHalfWidth / headRadius)

        let path = UIBezierPath()
        path.move(to: leftJoin)
        // UIKit angles increase clockwise (y-down); `true` arcs over the head, not the short bottom chord.
        path.addArc(
            withCenter: CGPoint(x: centerX, y: headCenterY),
            radius: headRadius,
            startAngle: leftAngle,
            endAngle: rightAngle,
            clockwise: true
        )
        path.addLine(to: tip)
        path.close()
        return path
    }
}