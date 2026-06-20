import SwiftData
import SwiftUI

struct MapTabView: View {
    @Query(sort: \SavedPlace.registeredAt, order: .reverse) private var savedPlaces: [SavedPlace]
    @Environment(TabRouter.self) private var router
    @State private var isMapActive = true

    var body: some View {
        Group {
            if Secrets.isKakaoMapConfigured {
                KakaoMapView(isActive: isMapActive, places: savedPlaces) { placeID in
                    router.openSavedPlaceDetail(id: placeID)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { isMapActive = true }
                .onDisappear { isMapActive = false }
            } else {
                missingKeyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var missingKeyState: some View {
        Color(.systemGroupedBackground)
            .overlay {
                VStack(spacing: 8) {
                    Text("카카오맵 키가 필요해요")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("Config/secrets.local.env에 KAKAO_NATIVE_APP_KEY를 추가해 주세요.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
    }
}

#Preview {
    MapTabView()
        .environment(TabRouter())
        .modelContainer(for: SavedPlace.self, inMemory: true)
}