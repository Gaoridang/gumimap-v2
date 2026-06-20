import Foundation
import KakaoMapsSDK

enum KakaoMapSDKBootstrap {
    private static var didRegister = false

    static func registerIfNeeded() {
        guard !didRegister else { return }
        guard Secrets.isKakaoMapConfigured else { return }

        SDKInitializer.InitSDK(appKey: Secrets.kakaoNativeAppKey)
        didRegister = true
    }
}