import SwiftUI

struct ListTabView: View {
    var body: some View {
        Color(.systemGroupedBackground)
            .overlay {
                Text("목록")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .ignoresSafeArea()
    }
}

#Preview {
    ListTabView()
}