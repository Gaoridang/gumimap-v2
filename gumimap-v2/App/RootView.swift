import SwiftUI

struct RootView: View {
    @State private var router = TabRouter()

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

            FloatingToolbar(router: router)
                .padding(.bottom, 12)
        }
    }
}

#Preview {
    RootView()
}