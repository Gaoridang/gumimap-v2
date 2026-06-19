import CoreLocation
import SwiftUI

struct PlaceDetailSheet: View {
    let place: Place
    let onDismiss: () -> Void

    @State private var selectedListType: ListSubTab = .wishlist

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
                addButton
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
        HStack(spacing: 8) {
            listTypeButton(.wishlist, title: "가고 싶은 곳")
            listTypeButton(.visited, title: "가본 곳")
        }
    }

    private func listTypeButton(_ listType: ListSubTab, title: String) -> some View {
        let isSelected = selectedListType == listType

        return Button {
            selectedListType = listType
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.black)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.black : Color.black.opacity(0.15),
                        lineWidth: 1.5
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button {
            // TODO: Save place to selected list
            onDismiss()
        } label: {
            Text("추가하기")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    Capsule()
                        .fill(.black)
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemGroupedBackground))
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