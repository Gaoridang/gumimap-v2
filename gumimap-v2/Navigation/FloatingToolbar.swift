import SwiftUI

struct FloatingToolbar: View {
    @Bindable var router: TabRouter

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 16) {
                tabButton(systemName: "mappin", tab: .map)
                tabButton(systemName: "list.bullet", tab: .list)
            }

            toolbarDivider

            Button {
                // Search placeholder
            } label: {
                Image(systemName: "magnifyingglass")
                    .toolbarIconStyle(isSelected: false)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background {
            Capsule()
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.15))
            .frame(width: 1, height: 20)
    }

    private func tabButton(systemName: String, tab: AppTab) -> some View {
        Button {
            router.selectedTab = tab
        } label: {
            Image(systemName: systemName)
                .toolbarIconStyle(isSelected: router.selectedTab == tab)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
    }
}

private extension Image {
    func toolbarIconStyle(isSelected: Bool) -> some View {
        self
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.black)
            .opacity(isSelected ? 1 : 0.4)
    }
}

#Preview {
    FloatingToolbar(router: TabRouter())
        .padding()
        .background(Color.gray.opacity(0.2))
}