import SwiftUI

struct SavedPlaceMapPin: View {
    let listKind: ListSubTab
    let category: String

    private var categorySymbol: String {
        PlaceCategoryIcon.symbol(for: category)
    }

    private var categoryTint: Color {
        PlaceCategoryIcon.tint(for: category)
    }

    private var listKindColor: Color {
        switch listKind {
        case .visited: .green
        case .wishlist: .blue
        }
    }

    var body: some View {
        ZStack {
            MapPinPointer()
                .fill(categoryTint)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

            MapPinPointer()
                .stroke(listKindColor, lineWidth: 2.5)

            Image(systemName: categorySymbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .offset(y: -2)
        }
        .frame(width: 36, height: 44)
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
        SavedPlaceMapPin(listKind: .visited, category: "쇼핑 > 마트")
    }
    .padding(32)
    .background(Color(.systemGroupedBackground))
}