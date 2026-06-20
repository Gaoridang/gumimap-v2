import SwiftUI

/// Round head + short pointed tail; tip sits at the bottom center of the rect.
struct MapPinPointer: Shape {
    var tailHeightRatio: CGFloat = 0.2

    func path(in rect: CGRect) -> Path {
        let headDiameter = rect.width * 0.72
        let headRadius = headDiameter / 2
        let centerX = rect.midX
        let headCenterY = headRadius
        let tailHalfWidth = headRadius * 0.38
        let tailTopY = headCenterY + headRadius - 1
        let tipY = min(rect.maxY, tailTopY + rect.height * tailHeightRatio)

        var path = Path()
        path.addEllipse(in: CGRect(
            x: centerX - headRadius,
            y: headCenterY - headRadius,
            width: headDiameter,
            height: headDiameter
        ))
        path.move(to: CGPoint(x: centerX - tailHalfWidth, y: tailTopY))
        path.addLine(to: CGPoint(x: centerX + tailHalfWidth, y: tailTopY))
        path.addLine(to: CGPoint(x: centerX, y: tipY))
        path.closeSubpath()
        return path
    }
}