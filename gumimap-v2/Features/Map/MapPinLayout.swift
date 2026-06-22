import CoreGraphics
import SwiftUI
import UIKit

enum MapPinStyle {
    static let borderWidth: CGFloat = 2

    static let fillUIColor = UIColor(red: 0.98, green: 0.89, blue: 0.48, alpha: 1)
    static let borderUIColor = UIColor(red: 0.29, green: 0.52, blue: 0.78, alpha: 1)
    static let fillColor = Color(red: 0.98, green: 0.89, blue: 0.48)
    static let borderColor = Color(red: 0.29, green: 0.52, blue: 0.78)

    static func colors(for listKind: ListSubTab) -> (fill: UIColor, border: UIColor) {
        _ = listKind
        return (fillUIColor, borderUIColor)
    }

    static func swiftUIColors(for listKind: ListSubTab) -> (fill: Color, border: Color) {
        _ = listKind
        return (fillColor, borderColor)
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
        path.addArc(
            withCenter: CGPoint(x: centerX, y: headCenterY),
            radius: headRadius,
            startAngle: leftAngle,
            endAngle: rightAngle,
            clockwise: false
        )
        path.addLine(to: tip)
        path.close()
        return path
    }
}