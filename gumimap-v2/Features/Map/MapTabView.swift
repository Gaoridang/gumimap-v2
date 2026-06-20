import SwiftData
import SwiftUI

private struct SelectedMapPlace: Identifiable {
    let id: String
}

struct MapTabView: View {
    @Query(sort: \SavedPlace.registeredAt, order: .reverse) private var savedPlaces: [SavedPlace]
    @State private var isMapActive = false
    @State private var selectedPlace: SelectedMapPlace?

    var body: some View {
        Group {
            if Secrets.isKakaoMapConfigured {
                KakaoMapView(isActive: isMapActive, places: savedPlaces) { placeID in
                    selectedPlace = SelectedMapPlace(id: placeID)
                }
                .ignoresSafeArea()
                .onAppear { isMapActive = true }
                .onDisappear { isMapActive = false }
            } else {
                missingKeyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedPlace) { selection in
            if let savedPlace = savedPlaces.first(where: { $0.id == selection.id }) {
                MapPlaceSheet(savedPlace: savedPlace)
            }
        }
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