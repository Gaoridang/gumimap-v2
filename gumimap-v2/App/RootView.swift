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
                    .zIndex(1)
            }
        }
    }
}

#Preview {
    RootView()
}