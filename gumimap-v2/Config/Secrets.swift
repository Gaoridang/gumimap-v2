import Foundation

enum Secrets {
    static var kakaoRestAPIKey: String { GeneratedSecrets.kakaoRestAPIKey }

    static var isKakaoConfigured: Bool {
        !kakaoRestAPIKey.isEmpty
    }
}