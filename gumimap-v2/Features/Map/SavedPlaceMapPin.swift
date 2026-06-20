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
        ZStack(alignment: .topTrailing) {
            Image(systemName: categorySymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(categoryTint.gradient, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2.5)
                }
                .shadow(color: .black.opacity(0.22), radius: 4, y: 2)

            listKindBadge
                .offset(x: 5, y: -5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var listKindBadge: some View {
        switch listKind {
        case .visited:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.green)
                .background(Circle().fill(.white).padding(-1))
        case .wishlist:
            Image(systemName: "bookmark.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 4))
        }
    }

    private var accessibilityLabel: String {
        "\(listKind.title), \(category)"
    }
}

#Preview {
    HStack(spacing: 24) {
        SavedPlaceMapPin(listKind: .visited, category: "음식점 > 카페")
        SavedPlaceMapPin(listKind: .wishlist, category: "음식점 > 한식")
    }
    .padding()
}