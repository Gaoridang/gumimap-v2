import Foundation

struct GrokPlaceDetailResponse: Codable, Sendable {
    let places: [GrokPlaceDetail]
}

struct GrokPlaceDetail: Codable, Sendable, Equatable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let category: String
    let reviews: [String]
    let features: [String]
    let waitInfo: [String]

    private func hasContent(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "정보 없음"
    }

    var reviewPoints: [String] { reviews.filter { hasContent($0) } }
    var featurePoints: [String] { features.filter { hasContent($0) } }
    var waitPoints: [String] { waitInfo.filter { hasContent($0) } }

    var hasReviews: Bool { !reviewPoints.isEmpty }
    var hasFeatures: Bool { !featurePoints.isEmpty }
    var hasWaitInfo: Bool { !waitPoints.isEmpty }

    var hasAnyInsight: Bool {
        hasReviews || hasFeatures || hasWaitInfo
    }
}