import SwiftData
import SwiftUI

struct ListTabView: View {
    let subTab: ListSubTab

    @Query(sort: \SavedPlace.registeredAt, order: .reverse) private var savedPlaces: [SavedPlace]
    @Environment(ListHeaderStore.self) private var listHeaderStore

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
        .onAppear {
            listHeaderStore.refreshPrompt(for: subTab)
        }
        .onChange(of: subTab) { _, tab in
            listHeaderStore.refreshPrompt(for: tab)
        }
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
            LazyVStack(alignment: .leading, spacing: 16) {
                listHeader

                LazyVStack(spacing: 10) {
                    ForEach(places, id: \.id) { savedPlace in
                        NavigationLink(value: AppRoute.savedPlaceDetail(id: savedPlace.id)) {
                            SavedPlaceCard(content: savedPlace.cardContent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private var listHeader: some View {
        let prompt = listHeaderStore.prompt(for: subTab)

        return StyledListHeader(prompt: prompt)
            .contentTransition(.opacity)
            .animation(
                listHeaderStore.shouldAnimatePrompt ? .easeInOut(duration: 0.35) : nil,
                value: prompt.fullText
            )
            .accessibilityLabel(prompt.fullText)
    }
}

#Preview {
    ListTabView(subTab: .visited)
        .environment(ListHeaderStore())
}