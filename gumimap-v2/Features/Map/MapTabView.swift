import SwiftData
import SwiftUI

struct MapTabView: View {
    @Query(sort: \SavedPlace.registeredAt, order: .reverse) private var savedPlaces: [SavedPlace]
    @Environment(TabRouter.self) private var router
    @State private var isMapActive = true
    @State private var mapRuntimeState = KakaoMapRuntimeState()

    var body: some View {
        Group {
            if Secrets.isKakaoMapConfigured {
                ZStack {
                    KakaoMapView(
                        isActive: isMapActive,
                        places: savedPlaces,
                        runtimeState: mapRuntimeState
                    ) { placeID in
                        router.openSavedPlaceDetail(id: placeID)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { isMapActive = true }
                    .onDisappear { isMapActive = false }

                    mapStatusOverlay
                }
            } else {
                missingKeyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var mapStatusOverlay: some View {
        switch mapRuntimeState.phase {
        case .loading:
            EmptyView()
        case .ready:
            EmptyView()
        case let .authFailed(code, message):
            mapErrorCard(
                title: "카카오맵 인증 실패 (\(code))",
                message: authFailureMessage(code: code, detail: message)
            )
        case .addViewFailed:
            mapErrorCard(
                title: "지도를 불러오지 못했어요",
                message: "네트워크 연결을 확인한 뒤 앱을 다시 실행해 주세요."
            )
        }
    }

    private func authFailureMessage(code: Int, detail: String) -> String {
        switch code {
        case 401:
            """
            네이티브 앱 키 또는 번들 ID가 맞지 않습니다.

            카카오 개발자 콘솔 > 앱 > 플랫폼 > iOS에
            com.ijaejun.gumimap-v2 가 등록돼 있는지 확인해 주세요.
            """
        case 403:
            "카카오맵 SDK 사용 권한이 없습니다. 개발자 콘솔에서 지도 API를 활성화했는지 확인해 주세요."
        case 429:
            "카카오맵 API 사용량을 초과했습니다."
        case 499:
            "네트워크 오류입니다. 연결 후 다시 시도해 주세요."
        default:
            detail.isEmpty ? "알 수 없는 인증 오류가 발생했습니다." : detail
        }
    }

    private func mapErrorCard(title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 28)
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