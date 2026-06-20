import Foundation
import Observation

struct KakaoMapDebugSnapshot: Equatable {
    var updatedAt: Date = .now
    var phaseLabel: String = "loading"
    var lastEvent: String = "init"
    var bundleID: String = Bundle.main.bundleIdentifier ?? "unknown"
    var nativeKeyMasked: String = KakaoMapDebugSnapshot.maskKey(Secrets.kakaoNativeAppKey)
    var sdkPhase: String = "—"
    var isMapTabActive: Bool = false
    var isEnginePrepared: Bool = false
    var isEngineActive: Bool = false
    var isMapReady: Bool = false
    var didAuthenticate: Bool = false
    var hasMapView: Bool = false
    var viewRectApplied: Bool = false
    var cameraSet: Bool = false
    var containerSize: String = "0×0"
    var pendingSize: String = "0×0"
    var appliedViewRectSize: String = "0×0"
    var addViewSize: String = "—"
    var pinCount: Int = 0
    var engineStateMessage: String = "—"
    var authError: String?

    static func maskKey(_ key: String) -> String {
        guard key.count > 12 else { return key.isEmpty ? "(empty)" : "(set)" }
        let prefix = key.prefix(8)
        let suffix = key.suffix(4)
        return "\(prefix)…\(suffix)"
    }

    static func format(_ size: CGSize) -> String {
        "\(Int(size.width))×\(Int(size.height))"
    }
}

@Observable
final class KakaoMapRuntimeState {
    enum Phase: Equatable {
        case loading
        case ready
        case authFailed(code: Int, message: String)
        case addViewFailed
    }

    var phase: Phase = .loading
    var debug = KakaoMapDebugSnapshot()

    @MainActor
    func apply(_ mutation: (inout KakaoMapDebugSnapshot) -> Void) {
        mutation(&debug)
        debug.updatedAt = .now
    }

    @MainActor
    func record(event: String) {
        debug.lastEvent = event
        debug.updatedAt = .now
    }
}