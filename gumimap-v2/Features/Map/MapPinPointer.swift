import SwiftUI

/// Round head + pointed tail; tip sits at the bottom center of the rect.
struct MapPinPointer: Shape {
    func path(in rect: CGRect) -> Path {
        let headDiameter = min(rect.width * 0.78, rect.height * 0.58)
        let headRadius = headDiameter / 2
        let centerX = rect.midX
        let headCenterY = headRadius + 1
        let tailHalfWidth = headRadius * 0.4
        let tailTopY = headCenterY + headRadius - 1.5
        let tipY = rect.maxY

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