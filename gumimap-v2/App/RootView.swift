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
                    ListTabView()
                }
            }

            FloatingToolbar(router: router)
                .padding(.bottom, 24)
        }
    }
}

#Preview {
    RootView()
}