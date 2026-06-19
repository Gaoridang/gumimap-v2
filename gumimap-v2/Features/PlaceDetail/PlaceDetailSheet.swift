import CoreLocation
import SwiftUI

struct PlaceDetailSheet: View {
    let place: Place
    let onDismiss: () -> Void

    @State private var selectedListType: ListSubTab = .wishlist
    @State private var memo = ""
    @State private var selectedTags: Set<WishlistTag> = []
    @State private var priority: WishlistPriority = .medium

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    nameSection
                        .padding(.bottom, 4)

                    addressSection
                        .padding(.bottom, 20)

                    mapPlaceholder
                        .padding(.bottom, 24)

                    listTypeSection

                    if selectedListType == .wishlist {
                        wishlistOptionsSection
                            .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", action: onDismiss)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
        }
    }

    private var nameSection: some View {
        Text(place.name)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addressSection: some View {
        Text(place.address)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mapPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.tertiarySystemFill))
            .frame(height: 180)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "map")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("지도 미리보기")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.5f, %.5f", place.coordinate.latitude, place.coordinate.longitude))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
    }

    private var listTypeSection: some View {
        HStack(spacing: 20) {
            listTypeButton(.wishlist, title: "가고싶음")
            listTypeButton(.visited, title: "갔다옴")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    private func listTypeButton(_ listType: ListSubTab, title: String) -> some View {
        let isSelected = selectedListType == listType

        return Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedListType = listType
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(isSelected ? .black : .black.opacity(0.35))
                    .contentTransition(.identity)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .animation(nil, value: selectedListType)
        }
        .buttonStyle(.plain)
    }

    private var wishlistOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("메모 (선택)", text: $memo, axis: .vertical)
                .lineLimit(1...3)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(optionFieldBackground)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(WishlistTag.allCases) { tag in
                    tagChip(tag)
                }
            }

            HStack(spacing: 8) {
                ForEach(WishlistPriority.allCases) { level in
                    priorityButton(level)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    private var optionFieldBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(.tertiarySystemGroupedBackground))
    }

    private func tagChip(_ tag: WishlistTag) -> some View {
        let isSelected = selectedTags.contains(tag)

        return Button {
            if isSelected {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        } label: {
            Text(tag.title)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color(.tertiarySystemGroupedBackground) : Color.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color.primary.opacity(0.25) : Color.primary.opacity(0.12),
                                    lineWidth: 1
                                )
                        }
                }
        }
        .buttonStyle(.plain)
    }

    private func priorityButton(_ level: WishlistPriority) -> some View {
        let isSelected = priority == level

        return Button {
            priority = level
        } label: {
            Text(level.title)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color(.tertiarySystemGroupedBackground) : Color.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color.primary.opacity(0.25) : Color.primary.opacity(0.12),
                                    lineWidth: 1
                                )
                        }
                }
        }
        .buttonStyle(.plain)
    }

    private let bottomButtonCornerRadius: CGFloat = 10
    private let bottomButtonHeight: CGFloat = 48
    private let primaryButtonFill = Color(.label)
    private let primaryButtonForeground = Color(.systemGroupedBackground)
    private let secondaryButtonFill = Color(.secondarySystemGroupedBackground)

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            Button {
                // TODO: Save place to selected list
                onDismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))

                    Text("추가하기")
                        .font(.body.weight(.medium))
                }
                .foregroundStyle(primaryButtonForeground)
                .frame(maxWidth: .infinity)
                .frame(height: bottomButtonHeight)
                .background(bottomButtonBackground(fill: primaryButtonFill))
            }
            .buttonStyle(.plain)

            if let kakaoMapURL = place.kakaoMapURL {
                Link(destination: kakaoMapURL) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: bottomButtonHeight, height: bottomButtonHeight)
                        .background(bottomButtonBackground(fill: secondaryButtonFill))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemGroupedBackground))
    }

    private func bottomButtonBackground(fill: Color) -> some View {
        RoundedRectangle(cornerRadius: bottomButtonCornerRadius, style: .continuous)
            .fill(fill)
            .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 3)
    }
}

#Preview {
    PlaceDetailSheet(
        place: Place(
            id: "21160803",
            name: "스타벅스 구미시청DT점",
            address: "경북 구미시 송정동 33-11",
            category: "카페",
            phone: "054-123-4567",
            kakaoMapURL: URL(string: "http://place.map.kakao.com/21160803"),
            coordinate: .init(latitude: 36.1195, longitude: 128.3445)
        ),
        onDismiss: {}
    )
}