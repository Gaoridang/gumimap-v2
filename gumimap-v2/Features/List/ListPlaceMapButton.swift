import SwiftUI

struct ListPlaceMapButton: View {
    let action: () -> Void

    private let tint = MapPinStyle.borderColor

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
    ListPlaceMapButton {}
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding()
        .background(Color(.systemGroupedBackground))
}