import Foundation

enum Secrets {
    static var kakaoRestAPIKey: String { GeneratedSecrets.kakaoRestAPIKey }
    static var xaiAPIKey: String { GeneratedSecrets.xaiAPIKey }

    static var isKakaoConfigured: Bool {
        !kakaoRestAPIKey.isEmpty
    }

    static var isGrokConfigured: Bool {
        !xaiAPIKey.isEmpty
    }
}