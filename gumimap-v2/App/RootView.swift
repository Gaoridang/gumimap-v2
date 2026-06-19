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
                }
            }

            FloatingToolbar(router: router, search: search)
                .padding(.bottom, 12)

            if search.isPresented {
                SearchOverlayView(search: search)
                    .transition(searchOverlayTransition)
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: search.isPresented)
    }

    private var searchOverlayTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }
}

#Preview {
    RootView()
}