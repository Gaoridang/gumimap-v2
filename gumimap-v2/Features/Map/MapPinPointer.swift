import SwiftUI

/// Round head + short pointed tail; tip sits at the bottom center of the rect.
struct MapPinPointer: Shape {
    func path(in rect: CGRect) -> Path {
        Path(MapPinLayout.uiBezierPath(in: rect).cgPath)
    }
}