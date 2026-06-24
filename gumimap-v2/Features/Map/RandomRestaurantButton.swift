import SwiftUI

struct RandomRestaurantButton: View {
    @Environment(TabRouter.self) private var router
    @State private var picker = RandomRestaurantPicker()
    @State private var showsError = false

    var body: some View {
        Button {
            Task { await pickRestaurant() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: picker.isLoading ? "hourglass" : "dice.fill")
                    .font(.body.weight(.semibold))
                    .symbolEffect(.bounce, value: picker.isLoading)

                Text(picker.isLoading ? "고르는 중..." : "오늘 뭐 먹지?")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(MapPinStyle.borderColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(MapPinStyle.fillColor)
                    .shadow(color: MapPinStyle.borderColor.opacity(0.18), radius: 8, y: 3)
            }
            .overlay {
                Capsule()
                    .strokeBorder(MapPinStyle.borderColor.opacity(0.55), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(picker.isLoading)
        .accessibilityLabel("랜덤 식당 선택")
        .alert("식당을 고르지 못했어요", isPresented: $showsError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(picker.errorMessage ?? "잠시 후 다시 시도해 주세요.")
        }
    }

    private func pickRestaurant() async {
        guard let place = await picker.pickRandomRestaurant() else {
            showsError = picker.errorMessage != nil
            return
        }

        router.openPlaceDetail(place)
    }
}