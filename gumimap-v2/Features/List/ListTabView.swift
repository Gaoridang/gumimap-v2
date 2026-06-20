import SwiftData
import SwiftUI

struct ListTabView: View {
    let subTab: ListSubTab

    @Query(sort: \SavedPlace.registeredAt, order: .reverse) private var savedPlaces: [SavedPlace]
    @State private var headerViewModel = ListHeaderViewModel()
    @State private var appearCount = 0

    private var places: [SavedPlace] {
        savedPlaces.filter { $0.listKind == subTab.rawValue }
    }

    private var headerLoadKey: String {
        "\(subTab.rawValue)-\(places.count)-\(appearCount)"
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
            appearCount += 1
        }
        .task(id: headerLoadKey) {
            headerViewModel.load(subTab: subTab, placeCount: places.count)
        }
        .onDisappear {
            headerViewModel.cancel()
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
        StyledListHeader(prompt: headerViewModel.prompt)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: headerViewModel.prompt)
            .accessibilityLabel(headerViewModel.prompt.fullText)
    }
}

#Preview {
    ListTabView(subTab: .visited)
}