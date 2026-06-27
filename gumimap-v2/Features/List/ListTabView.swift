import SwiftData
import SwiftUI

struct ListTabView: View {
    let subTab: ListSubTab

    @Query(sort: \SavedPlace.registeredAt, order: .reverse) private var savedPlaces: [SavedPlace]
    @Environment(ListHeaderStore.self) private var listHeaderStore
    @Environment(ListFilterStore.self) private var listFilterStore
    @Environment(TabRouter.self) private var router

    private var allPlaces: [SavedPlace] {
        savedPlaces.filter { $0.listKind == subTab.rawValue }
    }

    private var filterSettings: ListPlaceFilterSettings {
        listFilterStore.settings(for: subTab)
    }

    private var availableCategories: [String] {
        ListPlaceFilter.availableCategories(in: allPlaces)
    }

    private var places: [SavedPlace] {
        ListPlaceFilter.apply(filterSettings, to: allPlaces)
    }

    var body: some View {
        Group {
            if allPlaces.isEmpty {
                emptyState
            } else if places.isEmpty {
                filteredListContent
            } else {
                listContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.2), value: subTab)
        .animation(.easeInOut(duration: 0.2), value: places.count)
        .animation(.easeInOut(duration: 0.2), value: filterSettings)
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

    private var filteredListContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                listHeader
                filterBar
                filteredEmptyState
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 12) {
            Text("조건에 맞는 곳이 없어요")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("필터를 바꾸거나 초기화해 보세요")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Button("필터 초기화") {
                listFilterStore.reset(for: subTab)
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                listHeader
                filterBar

                LazyVStack(spacing: 10) {
                    ForEach(places, id: \.id) { savedPlace in
                        listPlaceRow(savedPlace)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private func listPlaceRow(_ savedPlace: SavedPlace) -> some View {
        Button {
            router.openSavedPlaceDetail(id: savedPlace.id)
        } label: {
            SavedPlaceCard(content: savedPlace.cardContent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            ListPlaceMapButton(listKind: subTab) {
                router.openSavedPlaceOnMap(id: savedPlace.id)
            }
            .padding(.trailing, 12)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var listHeader: some View {
        if let prompt = listHeaderStore.prompt(for: subTab) {
            StyledListHeader(prompt: prompt)
                .contentTransition(.opacity)
                .animation(
                    listHeaderStore.shouldAnimatePrompt ? .easeInOut(duration: 0.35) : nil,
                    value: prompt.fullText
                )
                .accessibilityLabel(prompt.fullText)
        }
    }

    private var filterBar: some View {
        ListFilterBar(
            subTab: subTab,
            categories: availableCategories,
            settings: filterSettings,
            onSortOrderChange: { order in
                listFilterStore.setSortOrder(order, for: subTab)
            },
            onCategoryChange: { category in
                listFilterStore.setSelectedCategory(category, for: subTab)
            }
        )
    }
}

#Preview {
    ListTabView(subTab: .visited)
        .environment(ListHeaderStore())
        .environment(ListFilterStore())
        .environment(TabRouter())
}