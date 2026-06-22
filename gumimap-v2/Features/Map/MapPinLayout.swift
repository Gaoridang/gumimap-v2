import CoreGraphics
import UIKit

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
        let headRect = CGRect(
            x: centerX - headRadius,
            y: headCenterY - headRadius,
            width: headDiameter,
            height: headDiameter
        )
        let tailTopY = headRect.maxY - 1
        let tipY = rect.maxY

        let path = UIBezierPath(ovalIn: headRect)
        let tail = UIBezierPath()
        tail.move(to: CGPoint(x: centerX - tailHalfWidth, y: tailTopY))
        tail.addLine(to: CGPoint(x: centerX + tailHalfWidth, y: tailTopY))
        tail.addLine(to: CGPoint(x: centerX, y: tipY))
        tail.close()
        path.append(tail)
        return path
    }
}