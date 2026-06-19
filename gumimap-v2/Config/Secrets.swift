import Foundation

enum Secrets {
    static var kakaoRestAPIKey: String { GeneratedSecrets.kakaoRestAPIKey }

    static var isConfigured: Bool {
        !kakaoRestAPIKey.isEmpty
    }
}