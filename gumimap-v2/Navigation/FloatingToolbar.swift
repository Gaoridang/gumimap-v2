import SwiftUI

struct FloatingToolbar: View {
    @Bindable var router: TabRouter

    private let iconSize: CGFloat = 24
    private let tapTargetSize: CGFloat = 40
    private let backCircleSize: CGFloat = 36
    private let dividerHeight: CGFloat = 20
    private let itemSpacing: CGFloat = 12
    private let tabGroupSpacing: CGFloat = 8

    var body: some View {
        HStack(spacing: itemSpacing) {
            tabGroup
            toolbarDivider
            searchButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background {
            Capsule()
                .fill(.white)
                .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
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
                    .frame(width: backCircleSize, height: backCircleSize)

                ToolbarIcon(asset: .back, isSelected: true, size: 20)
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
            .frame(width: 1, height: dividerHeight)
    }

    private var searchButton: some View {
        Button {
            router.openSearch()
        } label: {
            ToolbarIcon(asset: .search, isSelected: false, size: iconSize)
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
            ToolbarIcon(asset: asset, isSelected: isSelected, size: iconSize)
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
    func toolbarTapTarget(size: CGFloat = 40) -> some View {
        frame(width: size, height: size)
            .contentShape(Rectangle())
    }
}

#Preview {
    @Previewable @State var router = TabRouter()

    FloatingToolbar(router: router)
        .padding()
        .background(Color.gray.opacity(0.2))
}