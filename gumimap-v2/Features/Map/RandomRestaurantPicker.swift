import Foundation

@Observable
@MainActor
final class RandomRestaurantPicker {
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service: KakaoLocalService

    private let searchKeywords = [
        "구미 맛집",
        "구미 식당",
        "구미 한식",
        "구미 중식",
        "구미 일식",
        "구미 양식",
        "구미 분식",
        "구미 국밥",
        "구미 고기",
        "구미 치킨",
    ]

    init(service: KakaoLocalService = KakaoLocalService()) {
        self.service = service
    }

    func pickRandomRestaurant() async -> Place? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard Secrets.isKakaoConfigured else {
            errorMessage = "Kakao REST API 키가 설정되지 않았습니다."
            return nil
        }

        let keywords = searchKeywords.shuffled()
        var collected: [Place] = []

        for keyword in keywords.prefix(4) {
            do {
                let places = try await service.search(keyword: keyword, size: 15)
                collected.append(contentsOf: places.filter(Self.isRestaurant))
            } catch {
                errorMessage = error.localizedDescription
                return nil
            }

            if let pick = collected.randomElement() {
                return pick
            }
        }

        errorMessage = "구미에서 식당을 찾지 못했어요. 잠시 후 다시 시도해 주세요."
        return nil
    }

    private static func isRestaurant(_ place: Place) -> Bool {
        let normalized = place.category
            .replacingOccurrences(of: " ", with: "")
            .lowercased()

        if normalized.contains("음식") || normalized.contains("식당") {
            return true
        }

        return PlaceCategoryIcon.symbol(for: place.category) == "fork.knife"
    }
}