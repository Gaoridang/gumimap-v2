import SwiftUI

struct RootView: View {
    @State private var router = TabRouter()
    @State private var search = SearchViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch router.selectedTab {
                case .map:
                    MapTabView()
                case .list:
                    ListTabView(subTab: router.listSubTab)
                case .search:
                    SearchTabView(router: router, search: search)
                }
            }

            if !router.isSearchMode {
                FloatingToolbar(router: router)
                    .padding(.bottom, 12)
            }
        }
    }
}

#Preview {
    RootView()
}