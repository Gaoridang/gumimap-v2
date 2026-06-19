import SwiftUI

struct MapTabView: View {
    var body: some View {
        Color(.systemGroupedBackground)
            .overlay {
                Text("지도")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .ignoresSafeArea()
    }
}

#Preview {
    MapTabView()
}