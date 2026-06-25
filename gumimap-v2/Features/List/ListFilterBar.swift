import SwiftUI

struct ListFilterBar: View {
    let subTab: ListSubTab
    let categories: [String]
    let settings: ListPlaceFilterSettings
    let onSortOrderChange: (ListPlaceSortOrder) -> Void
    let onCategoryChange: (String?) -> Void
    let onOpenNowChange: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            controlsRow

            if categories.count > 1 {
                categoryChips
            }
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 8) {
            sortMenu

            openNowToggle

            Spacer(minLength: 0)
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(ListPlaceSortOrder.allCases, id: \.self) { order in
                Button {
                    onSortOrderChange(order)
                } label: {
                    if settings.sortOrder == order {
                        Label(order.title, systemImage: "checkmark")
                    } else {
                        Text(order.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(settings.sortOrder.title)
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        }
    }

    private var openNowToggle: some View {
        Button {
            onOpenNowChange(!settings.openNowOnly)
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(settings.openNowOnly ? Color.green : Color.secondary.opacity(0.35))
                    .frame(width: 6, height: 6)
                Text("영업중")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(settings.openNowOnly ? .green : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(
                        settings.openNowOnly
                            ? Color.green.opacity(0.12)
                            : Color(.secondarySystemGroupedBackground)
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("영업중만 보기")
        .accessibilityValue(settings.openNowOnly ? "켜짐" : "꺼짐")
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "전체", category: nil, isSelected: settings.selectedCategory == nil)

                ForEach(categories, id: \.self) { category in
                    categoryChip(
                        title: category,
                        category: category,
                        isSelected: settings.selectedCategory == category
                    )
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func categoryChip(title: String, category: String?, isSelected: Bool) -> some View {
        Button {
            onCategoryChange(category)
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ListFilterBar(
        subTab: .wishlist,
        categories: ["카페", "한식", "분식"],
        settings: ListPlaceFilterSettings(sortOrder: .newest, selectedCategory: "카페", openNowOnly: true),
        onSortOrderChange: { _ in },
        onCategoryChange: { _ in },
        onOpenNowChange: { _ in }
    )
    .padding(20)
    .background(Color(.systemGroupedBackground))
}