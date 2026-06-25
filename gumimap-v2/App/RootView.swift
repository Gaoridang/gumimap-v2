import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var router = TabRouter()
    @State private var search = SearchViewModel()
    @State private var placeStore: PlaceStore?
    @State private var enrichmentService = PlaceEnrichmentService()
    @State private var listHeaderStore = ListHeaderStore()
    @State private var listFilterStore = ListFilterStore()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            Group {
                switch router.selectedTab {
                case .map:
                    MapTabView()
                case .list:
                    ListTabView(subTab: router.listSubTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FloatingToolbar(router: router)
                    .padding(.bottom, 12)
                    .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .search:
                    SearchTabView(search: search)
                case let .placeDetail(place):
                    PlaceDetailView(place: place)
                case let .savedPlaceDetail(id):
                    if let placeStore {
                        PlaceDetailView(savedPlaceId: id, store: placeStore)
                    }
                }
            }
        }
        .environment(router)
        .environment(listHeaderStore)
        .environment(listFilterStore)
        .environment(\.placeStore, placeStore)
        .environment(enrichmentService)
        .onAppear {
            if placeStore == nil {
                placeStore = PlaceStore(modelContext: modelContext)
            }
        }
        .onChange(of: router.selectedTab) { oldTab, newTab in
            guard newTab == .list else { return }
            let enteringFromMap = oldTab != .list
            listHeaderStore.displayPrompt(for: router.listSubTab, rotate: enteringFromMap)
        }
        .onChange(of: router.listSubTab) { _, subTab in
            guard router.selectedTab == .list else { return }
            listHeaderStore.displayPrompt(for: subTab)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: SavedPlace.self, inMemory: true)
}