import SwiftUI

enum ToolbarIconAsset: String {
    case pin = "toolbar-pin"
    case list = "toolbar-list"
    case search = "toolbar-search"
}

struct ToolbarIcon: View {
    let asset: ToolbarIconAsset
    var isSelected: Bool = true

    var body: some View {
        Image(asset.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .foregroundStyle(.black)
            .opacity(isSelected ? 1 : 0.4)
    }
}

#Preview {
    HStack(spacing: 20) {
        ToolbarIcon(asset: .pin)
        ToolbarIcon(asset: .list, isSelected: false)
        ToolbarIcon(asset: .search)
    }
    .padding()
}