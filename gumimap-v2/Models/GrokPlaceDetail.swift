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
    let reviewSummary: String
    let features: String
    let waitInfo: String

    private func hasContent(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "정보 없음"
    }

    var hasReviewSummary: Bool { hasContent(reviewSummary) }
    var hasFeatures: Bool { hasContent(features) }
    var hasWaitInfo: Bool { hasContent(waitInfo) }

    var hasAnyInsight: Bool {
        hasReviewSummary || hasFeatures || hasWaitInfo
    }
}