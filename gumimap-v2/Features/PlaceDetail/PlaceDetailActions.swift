import SwiftUI

struct PlaceDetailActions: View {
    let kakaoMapURL: URL?
    let onAdd: () -> Void

    private let buttonCornerRadius: CGFloat = 10
    private let buttonHeight: CGFloat = 48
    private let primaryButtonFill = Color(.label)
    private let primaryButtonForeground = Color(.systemGroupedBackground)
    private let secondaryButtonFill = Color(.secondarySystemGroupedBackground)

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onAdd) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))

                    Text("추가하기")
                        .font(.body.weight(.medium))
                }
                .foregroundStyle(primaryButtonForeground)
                .frame(maxWidth: .infinity)
                .frame(height: buttonHeight)
                .background(buttonBackground(fill: primaryButtonFill))
            }
            .buttonStyle(.plain)

            if let kakaoMapURL {
                Link(destination: kakaoMapURL) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: buttonHeight, height: buttonHeight)
                        .background(buttonBackground(fill: secondaryButtonFill))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemGroupedBackground))
    }

    private func buttonBackground(fill: Color) -> some View {
        RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
            .fill(fill)
            .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 3)
    }
}

#Preview {
    PlaceDetailActions(
        kakaoMapURL: URL(string: "http://place.map.kakao.com/21160803"),
        onAdd: {}
    )
}