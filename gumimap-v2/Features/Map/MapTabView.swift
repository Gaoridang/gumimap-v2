import SwiftData
import SwiftUI

private struct SelectedMapPlace: Identifiable {
    let id: String
}

struct MapTabView: View {
    @Query(sort: \SavedPlace.registeredAt, order: .reverse) private var savedPlaces: [SavedPlace]
    @Environment(TabRouter.self) private var router
    @State private var isMapActive = false
    @State private var selectedPlace: SelectedMapPlace?
    @State private var focusPlaceId: String?
    @State private var animatedFocus = false

    var body: some View {
        Group {
            if Secrets.isKakaoMapConfigured {
                KakaoMapView(
                    isActive: isMapActive,
                    places: savedPlaces,
                    focusPlaceId: focusPlaceId,
                    animatedFocus: animatedFocus,
                    onPinTap: { placeID in
                        selectedPlace = SelectedMapPlace(id: placeID)
                    },
                    onFocusCompleted: { placeId in
                        guard animatedFocus else { return }
                        presentSheet(for: placeId)
                    }
                )
                .ignoresSafeArea()
                .onAppear { isMapActive = true }
                .onDisappear { isMapActive = false }
                .onChange(of: router.pendingMapFocusPlaceId) { _, placeId in
                    guard let placeId else { return }
                    animatedFocus = true
                    focusPlaceId = placeId
                    router.pendingMapFocusPlaceId = nil

                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(380))
                        guard animatedFocus, focusPlaceId == placeId else { return }
                        presentSheet(for: placeId)
                    }
                }
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

    private func presentSheet(for placeId: String) {
        animatedFocus = false

        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            selectedPlace = SelectedMapPlace(id: placeId)
        }

        Task {
            try? await Task.sleep(for: .milliseconds(400))
            focusPlaceId = nil
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