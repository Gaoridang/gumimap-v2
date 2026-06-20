import CoreLocation
import Foundation

struct GrokMapResolveResponse: Codable, Sendable {
    let sourceURL: String
    let pageName: String
    let pageAddress: String
    let confidence: String
}

struct GrokMapListingExtractionResponse: Codable, Sendable {
    let sourceURL: String
    let listing: GrokMapListing
}

struct GrokMapListingResponse: Codable, Sendable {
    let listing: GrokMapListing
}

struct GrokMapListing: Codable, Sendable {
    let features: PlaceFeatures
    let businessHours: String
}

struct GrokReviewsResponse: Codable, Sendable {
    let reviews: [String]
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

    static func from(
        place: Place,
        mapListing: GrokMapListing?,
        reviews: [String]
    ) -> GrokPlaceDetail {
        let features = mapListing?.features ?? PlaceFeatures.empty
        let hours = mapListing?.businessHours ?? ""

        return GrokPlaceDetail(
            name: place.name,
            address: place.address,
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            category: place.category,
            reviews: reviews,
            features: features,
            businessHours: hours
        )
    }
}

extension PlaceFeatures {
    static let empty = PlaceFeatures(
        popularMenu: "정보 없음",
        breakTime: "정보 없음",
        parking: "정보 없음",
        wait: "정보 없음",
        closedDay: "정보 없음"
    )
}