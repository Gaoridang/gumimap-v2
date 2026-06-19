import CoreLocation
import SwiftUI

struct PlaceDetailSheet: View {
    let place: Place
    let onDismiss: () -> Void

    @State private var selectedListType: ListSubTab = .wishlist

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                nameSection
                    .padding(.bottom, 4)

                addressSection
                    .padding(.bottom, 8)

                if !place.category.isEmpty {
                    categorySection
                        .padding(.bottom, 20)
                } else {
                    Spacer()
                        .frame(height: 12)
                }

                listTypeSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            PlaceDetailActions(
                kakaoMapURL: place.kakaoMapURL,
                onAdd: onDismiss
            )
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

    private var categorySection: some View {
        Text(place.category)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
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