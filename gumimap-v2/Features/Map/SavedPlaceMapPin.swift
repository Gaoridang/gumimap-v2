import SwiftUI

struct SavedPlaceMapPin: View {
    let listKind: ListSubTab
    let category: String

    private var colors: (fill: Color, border: Color) {
        MapPinStyle.swiftUIColors(for: listKind)
    }

    var body: some View {
        MapPinPointer()
            .fill(colors.fill)
            .overlay {
                MapPinPointer()
                    .stroke(colors.border, style: StrokeStyle(
                        lineWidth: MapPinStyle.borderWidth,
                        lineCap: .round,
                        lineJoin: .round
                    ))
            }
            .frame(width: MapPinLayout.contentSize.width, height: MapPinLayout.contentSize.height)
            .padding(EdgeInsets(
                top: MapPinLayout.canvasPadding.top,
                leading: MapPinLayout.canvasPadding.left,
                bottom: MapPinLayout.canvasPadding.bottom,
                trailing: MapPinLayout.canvasPadding.right
            ))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        "\(listKind.title), \(category)"
    }
}

#Preview {
    HStack(spacing: 28) {
        SavedPlaceMapPin(listKind: .visited, category: "음식점 > 카페")
        SavedPlaceMapPin(listKind: .wishlist, category: "음식점 > 한식")
    }
    .padding(32)
    .background(Color(.systemGroupedBackground))
}