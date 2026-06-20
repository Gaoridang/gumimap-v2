import Foundation
import Observation

@Observable
final class KakaoMapRuntimeState {
    enum Phase: Equatable {
        case loading
        case ready
        case authFailed(code: Int, message: String)
        case addViewFailed
    }

    var phase: Phase = .loading
}