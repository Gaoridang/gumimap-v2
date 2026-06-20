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

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white)
                    .frame(width: 38, height: 38)
                    .shadow(color: .black.opacity(0.16), radius: 5, y: 2)

                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(categoryTint.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 38, height: 38)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(categoryTint.opacity(0.14))
                    .frame(width: 28, height: 28)

                Image(systemName: categorySymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(categoryTint)

                listKindBadge
                    .offset(x: 7, y: -7)
            }

            MapPinPointer()
                .fill(.white)
                .frame(width: 14, height: 8)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                .offset(y: -1)
        }
        .frame(width: 44, height: 50)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var listKindBadge: some View {
        switch listKind {
        case .visited:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.green)
                .background(Circle().fill(.white).padding(-1.5))
        case .wishlist:
            Image(systemName: "bookmark.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
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