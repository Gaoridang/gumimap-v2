import SwiftUI

struct FloatingToolbar: View {
    @Bindable var router: TabRouter

    private let itemSpacing: CGFloat = 10
    private let tabGroupSpacing: CGFloat = 6

    var body: some View {
        HStack(spacing: itemSpacing) {
            tabGroup
            toolbarDivider
            searchButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: router.isListMode)
        .animation(.easeInOut(duration: 0.2), value: router.listSubTab)
    }

    @ViewBuilder
    private var tabGroup: some View {
        HStack(spacing: tabGroupSpacing) {
            leadingSlot

            if router.isListMode {
                listSubTabButton(asset: .visited, subTab: .visited)
                    .transition(listSubTabTransition)
                listSubTabButton(asset: .wishlist, subTab: .wishlist)
                    .transition(listSubTabTransition)
            } else {
                listEntryButton
                    .transition(listEntryTransition)
            }
        }
    }

    private var leadingSlot: some View {
        ZStack {
            if router.isListMode {
                backButton
                    .transition(leadingIconTransition)
            } else {
                iconButton(asset: .pin, isSelected: router.selectedTab == .map, action: router.selectMap)
                    .transition(leadingIconTransition)
            }
        }
        .toolbarTapTarget()
    }

    private var backButton: some View {
        Button(action: router.selectMap) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 28, height: 28)

                ToolbarIcon(asset: .back, isSelected: true, size: 17)
            }
        }
        .buttonStyle(.plain)
    }

    private var listEntryButton: some View {
        iconButton(asset: .list, isSelected: false, action: router.openList)
            .toolbarTapTarget()
    }

    private func listSubTabButton(asset: ToolbarIconAsset, subTab: ListSubTab) -> some View {
        iconButton(
            asset: asset,
            isSelected: router.listSubTab == subTab,
            action: { router.selectListSubTab(subTab) }
        )
        .toolbarTapTarget()
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.15))
            .frame(width: 1, height: 16)
    }

    private var searchButton: some View {
        Button {
            router.openSearch()
        } label: {
            ToolbarIcon(asset: .search, isSelected: false)
        }
        .buttonStyle(.plain)
        .toolbarTapTarget()
    }

    private func iconButton(
        asset: ToolbarIconAsset,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ToolbarIcon(asset: asset, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var leadingIconTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.75).combined(with: .opacity),
            removal: .scale(scale: 0.75).combined(with: .opacity)
        )
    }

    private var listEntryTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var listSubTabTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }
}

private extension View {
    func toolbarTapTarget() -> some View {
        frame(width: 32, height: 32)
            .contentShape(Rectangle())
    }
}

#Preview {
    @Previewable @State var router = TabRouter()

    FloatingToolbar(router: router)
        .padding()
        .background(Color.gray.opacity(0.2))
}