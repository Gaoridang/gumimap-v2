import SwiftUI

struct SavedPlaceCardContent: Equatable {
    let name: String
    let address: String
    let category: String
    let insightLine: String?
    let isOpenNow: Bool
}

struct SavedPlaceCard: View {
    let content: SavedPlaceCardContent

    private var shortCategory: String {
        let parts = content.category
            .split(separator: ">")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.last ?? content.category
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            categoryIcon

            VStack(alignment: .leading, spacing: 6) {
                nameRow

                if !shortCategory.isEmpty {
                    Text(shortCategory)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(content.address)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                if let insightLine = content.insightLine {
                    Text(insightLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var nameRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(content.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if content.isOpenNow {
                openBadge
            }
        }
    }

    private var categoryIcon: some View {
        let tint = PlaceCategoryIcon.tint(for: content.category)

        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(tint.opacity(0.12))
                .frame(width: 44, height: 44)

            Image(systemName: PlaceCategoryIcon.symbol(for: content.category))
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
        }
        .accessibilityHidden(true)
    }

    private var openBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            Text("영업중")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.12), in: Capsule())
    }
}

extension SavedPlace {
    var cardContent: SavedPlaceCardContent {
        SavedPlaceCardContent(
            name: name,
            address: address,
            category: category,
            insightLine: cardInsightLine,
            isOpenNow: grokDetail?.isCurrentlyOpen == true
        )
    }

    private var cardInsightLine: String? {
        guard let detail = grokDetail else { return nil }

        let rows = detail.visibleFieldRows
        let atmosphere = rows.first { $0.label == "분위기" && !$0.isMissing }?.value
        let features = rows.first { $0.label == "특징" && !$0.isMissing }?.value
        return atmosphere ?? features
    }
}

#Preview {
    ScrollView {
        LazyVStack(spacing: 10) {
            SavedPlaceCard(
                content: SavedPlaceCardContent(
                    name: "와일드차일드",
                    address: "경북 구미시 인동가산로35길 14",
                    category: "음식점 > 카페",
                    insightLine: "조용하고 넓은 공간, 디저트가 인기",
                    isOpenNow: true
                )
            )
            SavedPlaceCard(
                content: SavedPlaceCardContent(
                    name: "구미중앙시장",
                    address: "경북 구미시 원평동 123-4",
                    category: "쇼핑 > 시장",
                    insightLine: nil,
                    isOpenNow: false
                )
            )
        }
        .padding(20)
        .background(Color(.systemGroupedBackground))
    }
}