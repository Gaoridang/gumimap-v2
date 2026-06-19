import Foundation

struct GrokPlaceDetailResponse: Codable, Sendable {
    let places: [GrokPlaceDetail]
}

struct PlaceFeatures: Codable, Sendable, Equatable {
    let popularMenu: String
    let breakTime: String
    let parking: String
    let wait: String
    let closedDay: String

    var rows: [(label: String, value: String)] {
        [
            ("인기 메뉴", displayValue(popularMenu)),
            ("브레이크 타임", displayValue(breakTime)),
            ("주차", displayValue(parking)),
            ("대기", displayValue(wait)),
            ("휴무", displayValue(closedDay))
        ]
    }

    var hasAnyContent: Bool {
        [popularMenu, breakTime, parking, wait, closedDay].contains { Self.hasContent($0) }
    }

    private func displayValue(_ raw: String) -> String {
        Self.hasContent(raw) ? raw : "정보 없음"
    }

    private static func hasContent(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "정보 없음"
    }
}

struct GrokPlaceDetail: Codable, Sendable, Equatable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let category: String
    let reviews: [String]
    let features: PlaceFeatures
    let isOpenNow: Bool

    private static func hasContent(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "정보 없음"
    }

    var reviewPoints: [String] { reviews.filter { Self.hasContent($0) } }
    var hasReviews: Bool { !reviewPoints.isEmpty }

    var hasAnyInsight: Bool {
        hasReviews || features.hasAnyContent
    }
}