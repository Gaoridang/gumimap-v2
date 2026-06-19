import SwiftUI

struct FloatingToolbar: View {
    @Bindable var router: TabRouter

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                tabButton(asset: .pin, tab: .map)
                tabButton(asset: .list, tab: .list)
            }

            toolbarDivider

            Button {
                // Search placeholder
            } label: {
                ToolbarIcon(asset: .search, isSelected: false)
            }
            .buttonStyle(.plain)
            .toolbarTapTarget()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
        }
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.15))
            .frame(width: 1, height: 16)
    }

    private func tabButton(asset: ToolbarIconAsset, tab: AppTab) -> some View {
        Button {
            router.selectedTab = tab
        } label: {
            ToolbarIcon(asset: asset, isSelected: router.selectedTab == tab)
        }
        .buttonStyle(.plain)
        .toolbarTapTarget()
    }
}

private extension View {
    func toolbarTapTarget() -> some View {
        frame(width: 32, height: 32)
            .contentShape(Rectangle())
    }
}

#Preview {
    FloatingToolbar(router: TabRouter())
        .padding()
        .background(Color.gray.opacity(0.2))
}