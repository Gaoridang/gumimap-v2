import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var router = TabRouter()
    @State private var search = SearchViewModel()
    @State private var placeStore: PlaceStore?
    @State private var enrichmentService = PlaceEnrichmentService()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            ZStack(alignment: .bottom) {
                switch router.selectedTab {
                case .map:
                    MapTabView()
                case .list:
                    ListTabView(subTab: router.listSubTab)
                }

                FloatingToolbar(router: router)
                    .padding(.bottom, 12)
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
        .environment(\.placeStore, placeStore)
        .environment(\.placeEnrichmentService, enrichmentService)
        .onAppear {
            if placeStore == nil {
                placeStore = PlaceStore(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: SavedPlace.self, inMemory: true)
}