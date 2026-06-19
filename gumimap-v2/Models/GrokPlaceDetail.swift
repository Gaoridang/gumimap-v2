import Foundation

struct GrokPlaceDetailResponse: Codable, Sendable {
    let places: [GrokPlaceDetail]
}

struct GrokMapListingPatchResponse: Codable, Sendable {
    let places: [GrokMapListingPatch]
}

struct GrokMapListingPatch: Codable, Sendable {
    let features: PlaceFeatures
    let businessHours: String
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

    var missingFieldCount: Int {
        [popularMenu, breakTime, parking, wait, closedDay].filter { !Self.hasContent($0) }.count
    }

    func merging(with other: PlaceFeatures) -> PlaceFeatures {
        PlaceFeatures(
            popularMenu: Self.pick(current: popularMenu, fallback: other.popularMenu),
            breakTime: Self.pick(current: breakTime, fallback: other.breakTime),
            parking: Self.pick(current: parking, fallback: other.parking),
            wait: Self.pick(current: wait, fallback: other.wait),
            closedDay: Self.pick(current: closedDay, fallback: other.closedDay)
        )
    }

    private func displayValue(_ raw: String) -> String {
        Self.hasContent(raw) ? raw : "정보 없음"
    }

    static func hasContent(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "정보 없음"
    }

    static func pick(current: String, fallback: String) -> String {
        hasContent(current) ? current : fallback
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
    let businessHours: String

    var isCurrentlyOpen: Bool? {
        BusinessHoursParser.isOpenNow(
            businessHours: businessHours,
            breakTime: features.breakTime
        )
    }

    var reviewPoints: [String] { reviews.filter { PlaceFeatures.hasContent($0) } }
    var hasReviews: Bool { !reviewPoints.isEmpty }

    var hasAnyInsight: Bool {
        hasReviews || features.hasAnyContent
    }

    var needsMapRetry: Bool {
        features.missingFieldCount >= 2 || !PlaceFeatures.hasContent(businessHours)
    }

    func mergingMapListing(features: PlaceFeatures, businessHours: String) -> GrokPlaceDetail {
        let mergedHours = PlaceFeatures.pick(
            current: self.businessHours,
            fallback: businessHours
        )
        return GrokPlaceDetail(
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            category: category,
            reviews: reviews,
            features: self.features.merging(with: features),
            businessHours: mergedHours
        )
    }
}