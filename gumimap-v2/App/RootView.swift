import SwiftUI

struct RootView: View {
    @State private var router = TabRouter()
    @State private var search = SearchViewModel()

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
                    SearchTabView(search: search, router: router)
                }
            }
            .fullScreenCover(item: $router.presentedPlace) { place in
                PlaceDetailSheet(place: place) {
                    router.dismissPlaceDetail()
                }
            }
        }
    }
}

#Preview {
    RootView()
}