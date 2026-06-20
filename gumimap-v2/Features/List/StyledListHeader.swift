import SwiftUI

struct StyledListHeader: View {
    let prompt: ListHeaderPrompt

    var body: some View {
        prompt.segments.reduce(Text("")) { result, segment in
            result + styledSegment(segment)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    private func styledSegment(_ segment: ListHeaderSegment) -> Text {
        Text(segment.text)
            .font(.title2)
            .fontWeight(segment.emphasis ? .semibold : .regular)
            .foregroundStyle(segment.emphasis ? .primary : .secondary)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        StyledListHeader(prompt: ListHeaderPromptLibrary.visited[0])
        StyledListHeader(prompt: ListHeaderPromptLibrary.wishlist[0])
    }
    .padding(20)
    .background(Color(.systemGroupedBackground))
}