import SwiftData
import SwiftUI

struct ListTabView: View {
    let subTab: ListSubTab

    @Query(sort: \SavedPlace.registeredAt, order: .reverse) private var savedPlaces: [SavedPlace]

    private var places: [SavedPlace] {
        savedPlaces.filter { $0.listKind == subTab.rawValue }
    }

    var body: some View {
        Group {
            if places.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.2), value: subTab)
        .animation(.easeInOut(duration: 0.2), value: places.count)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(subTab.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("아직 저장한 곳이 없어요")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(places, id: \.id) { savedPlace in
                    NavigationLink(value: AppRoute.savedPlaceDetail(id: savedPlace.id)) {
                        listRow(savedPlace)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if savedPlace.id != places.last?.id {
                        Divider()
                            .padding(.leading, 20)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private func listRow(_ savedPlace: SavedPlace) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(savedPlace.name)
                .font(.body)
                .foregroundStyle(.primary)

            Text(savedPlace.address)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !savedPlace.category.isEmpty {
                Text(savedPlace.category)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

#Preview {
    ListTabView(subTab: .visited)
}