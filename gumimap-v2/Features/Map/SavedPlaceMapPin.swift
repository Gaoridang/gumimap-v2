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
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(categoryTint.opacity(0.15))
                    .frame(width: 30, height: 30)

                Circle()
                    .strokeBorder(listKindColor, lineWidth: 2)
                    .frame(width: 30, height: 30)

                Image(systemName: categorySymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(categoryTint)
            }
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)

            MapPinPointer()
                .fill(categoryTint.opacity(0.15))
                .frame(width: 10, height: 5)
                .offset(y: -1)
        }
        .frame(width: 36, height: 40)
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