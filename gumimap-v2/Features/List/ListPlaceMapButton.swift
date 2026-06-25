import SwiftUI

struct ListPlaceMapButton: View {
    let listKind: ListSubTab
    let action: () -> Void

    private var tint: Color {
        MapPinStyle.swiftUIColors(for: listKind).border
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(ToolbarIconAsset.pin.rawValue)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(tint)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("지도에서 보기")
    }
}

#Preview {
    ListPlaceMapButton(listKind: .wishlist) {}
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding()
        .background(Color(.systemGroupedBackground))
}