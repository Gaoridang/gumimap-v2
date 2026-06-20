import SwiftUI

/// Classic map-pin teardrop; tip sits at the bottom center of the rect.
struct MapPinPointer: Shape {
    var headRadiusRatio: CGFloat = 0.42

    func path(in rect: CGRect) -> Path {
        let radius = rect.width * headRadiusRatio
        let centerX = rect.midX
        let centerY = radius + 2
        let tip = CGPoint(x: centerX, y: rect.maxY)

        var path = Path()
        path.move(to: CGPoint(x: centerX - radius, y: centerY))
        path.addArc(
            center: CGPoint(x: centerX, y: centerY),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: tip)
        path.closeSubpath()
        return path
    }
}