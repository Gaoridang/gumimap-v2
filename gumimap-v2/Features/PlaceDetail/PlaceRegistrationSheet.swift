import SwiftUI

struct PlaceRegistrationSheet: View {
    let placeName: String
    let isSaving: Bool
    let onSelect: (ListSubTab) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("어디에 저장할까요?")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(placeName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            VStack(spacing: 12) {
                registrationOption(
                    title: ListSubTab.visited.title,
                    subtitle: "다녀온 장소로 기록해요",
                    icon: "checkmark.circle"
                ) {
                    onSelect(.visited)
                }

                registrationOption(
                    title: ListSubTab.wishlist.title,
                    subtitle: "나중에 가고 싶은 곳으로 모아둬요",
                    icon: "bookmark"
                ) {
                    onSelect(.wishlist)
                }
            }

            if isSaving {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("저장하고 있어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving)
    }

    private func registrationOption(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }
}