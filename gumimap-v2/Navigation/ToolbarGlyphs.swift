import SwiftUI

enum ToolbarGlyph {
    case pin
    case list
    case search
}

struct ToolbarGlyphView: View {
    let glyph: ToolbarGlyph
    var isSelected: Bool = true

    private let size: CGFloat = 20
    private let strokeWidth: CGFloat = 1.75

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
    }

    var body: some View {
        Group {
            switch glyph {
            case .pin:
                PinGlyph().stroke(.black, style: strokeStyle)
            case .list:
                ListGlyph().stroke(.black, style: strokeStyle)
            case .search:
                SearchGlyph().stroke(.black, style: strokeStyle)
            }
        }
        .opacity(isSelected ? 1 : 0.4)
        .frame(width: size, height: size)
    }
}

private struct PinGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 20
        let ox = rect.midX - 10 * scale
        let oy = rect.midY - 10 * scale

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * scale, y: oy + y * scale)
        }

        var path = Path()
        path.addArc(center: p(10, 7), radius: 4 * scale, startAngle: .degrees(200), endAngle: .degrees(-20), clockwise: false)
        path.addQuadCurve(to: p(10, 18), control: p(14, 12))
        path.addQuadCurve(to: p(6, 11), control: p(6, 12))
        path.closeSubpath()
        return path
    }
}

private struct ListGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 20
        let ox = rect.midX - 10 * scale
        let oy = rect.midY - 10 * scale

        func line(y: CGFloat) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: ox + 4 * scale, y: oy + y * scale))
            path.addLine(to: CGPoint(x: ox + 16 * scale, y: oy + y * scale))
            return path
        }

        var path = Path()
        path.addPath(line(y: 6))
        path.addPath(line(y: 10))
        path.addPath(line(y: 14))
        return path
    }
}

private struct SearchGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 20
        let ox = rect.midX - 10 * scale
        let oy = rect.midY - 10 * scale

        var path = Path()
        path.addEllipse(in: CGRect(
            x: ox + 3.5 * scale,
            y: oy + 3.5 * scale,
            width: 9 * scale,
            height: 9 * scale
        ))
        path.move(to: CGPoint(x: ox + 12 * scale, y: oy + 12 * scale))
        path.addLine(to: CGPoint(x: ox + 16.5 * scale, y: oy + 16.5 * scale))
        return path
    }
}

#Preview {
    HStack(spacing: 20) {
        ToolbarGlyphView(glyph: .pin)
        ToolbarGlyphView(glyph: .list, isSelected: false)
        ToolbarGlyphView(glyph: .search)
    }
    .padding()
}