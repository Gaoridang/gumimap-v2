import SwiftUI

struct SavedPlaceMapPin: View {
    let listKind: ListSubTab
    let category: String

    private var pinColor: Color {
        switch listKind {
        case .visited: .green
        case .wishlist: .blue
        }
    }

    var body: some View {
        MapPinPointer()
            .fill(pinColor)
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            .frame(width: 28, height: 26)
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