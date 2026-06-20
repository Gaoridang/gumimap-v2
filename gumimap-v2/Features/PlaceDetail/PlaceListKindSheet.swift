import SwiftUI

struct PlaceListKindSheet: View {
    let placeName: String
    let title: String
    let isProcessing: Bool
    let processingMessage: String
    let disabledListKind: ListSubTab?
    let onSelect: (ListSubTab) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(placeName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            VStack(spacing: 12) {
                listKindOption(
                    listKind: .visited,
                    subtitle: "다녀온 장소로 기록해요",
                    icon: "checkmark.circle"
                )

                listKindOption(
                    listKind: .wishlist,
                    subtitle: "나중에 가고 싶은 곳으로 모아둬요",
                    icon: "bookmark"
                )
            }

            if isProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(processingMessage)
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
        .interactiveDismissDisabled(isProcessing)
    }

    private func listKindOption(
        listKind: ListSubTab,
        subtitle: String,
        icon: String
    ) -> some View {
        let isDisabled = isProcessing || disabledListKind == listKind

        return Button {
            onSelect(listKind)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(isDisabled ? .tertiary : .primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(listKind.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isDisabled ? .tertiary : .primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if disabledListKind == listKind {
                    Text("현재")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}