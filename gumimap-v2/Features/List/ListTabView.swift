import SwiftUI

struct ListTabView: View {
    let subTab: ListSubTab

    private var title: String {
        switch subTab {
        case .visited:
            "가본 곳"
        case .wishlist:
            "가고 싶은 곳"
        }
    }

    var body: some View {
        Color(.systemGroupedBackground)
            .overlay {
                Text(title)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.2), value: subTab)
            }
            .ignoresSafeArea()
    }
}

#Preview {
    ListTabView(subTab: .visited)
}