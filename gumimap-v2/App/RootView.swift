import SwiftUI

struct RootView: View {
    @State private var router = TabRouter()
    @State private var search = SearchViewModel()

    private var toolbarAnimation: Animation {
        .spring(response: 0.38, dampingFraction: 0.78)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                mainContent

                if router.isSearchMode {
                    SearchTabView(router: router, search: search)
                        .transition(searchTransition)
                }
            }
            .animation(toolbarAnimation, value: router.isSearchMode)

            if !router.isSearchMode {
                FloatingToolbar(router: router)
                    .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch router.isSearchMode ? router.returnTab : router.selectedTab {
        case .map:
            MapTabView()
        case .list:
            ListTabView(subTab: router.listSubTab)
        case .search:
            EmptyView()
        }
    }

    private var searchTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .trailing)
        )
    }
}

#Preview {
    RootView()
}