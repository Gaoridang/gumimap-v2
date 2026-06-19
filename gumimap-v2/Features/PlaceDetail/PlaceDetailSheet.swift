import CoreLocation
import SwiftUI

struct PlaceDetailSheet: View {
    let place: Place
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    mapPlaceholder
                    infoSection
                    actionSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(place.name)
                            .font(.headline)
                            .lineLimit(1)

                        if !place.category.isEmpty {
                            Text(place.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", action: onDismiss)
                }
            }
        }
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
            .padding(.top, 8)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(title: "주소", value: place.address)

            if let phone = place.phone {
                detailRow(title: "전화번호", value: phone)
            } else {
                detailRow(title: "전화번호", value: "정보 없음", valueColor: .secondary)
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            if let phoneURL = place.phoneURL {
                Link(destination: phoneURL) {
                    actionLabel(title: "전화 걸기", systemImage: "phone.fill")
                }
            }

            if let kakaoMapURL = place.kakaoMapURL {
                Link(destination: kakaoMapURL) {
                    actionLabel(title: "카카오맵에서 보기", systemImage: "map.fill")
                }
            }
        }
    }

    private func detailRow(title: String, value: String, valueColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body)
                .foregroundStyle(valueColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionLabel(title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.medium))
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    PlaceDetailSheet(
        place: Place(
            id: "21160803",
            name: "강남역 2호선",
            address: "서울 강남구 강남대로 지하 396",
            category: "지하철역",
            phone: "02-6110-2221",
            kakaoMapURL: URL(string: "http://place.map.kakao.com/21160803"),
            coordinate: .init(latitude: 37.498086, longitude: 127.028001)
        ),
        onDismiss: {}
    )
}