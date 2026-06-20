import CoreLocation
import Foundation

struct GrokInsightField: Codable, Sendable, Equatable, Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

struct GrokPlaceSearchResponse: Codable, Sendable {
    let fields: [GrokInsightField]
    let reviews: [String]
}

struct GrokVisibleFieldRow: Identifiable, Equatable {
    let label: String
    let value: String

    var id: String { label }

    var isMissing: Bool { value == "정보 없음" }
}

enum GrokVisibleField: CaseIterable {
    case businessHours
    case breakTime
    case closedDay
    case parking
    case atmosphere
    case features

    var title: String {
        switch self {
        case .businessHours: "영업시간"
        case .breakTime: "브레이크타임"
        case .closedDay: "휴무일"
        case .parking: "주차"
        case .atmosphere: "분위기"
        case .features: "특징"
        }
    }

    var matchKeywords: [String] {
        switch self {
        case .businessHours:
            ["영업시간", "영업 시간", "운영시간", "운영 시간"]
        case .breakTime:
            ["브레이크타임", "브레이크 타임", "브레이크"]
        case .closedDay:
            ["휴무일", "정기휴무", "정기 휴무", "휴무"]
        case .parking:
            ["주차"]
        case .atmosphere:
            ["분위기"]
        case .features:
            ["특징"]
        }
    }
}

struct GrokPlaceDetail: Codable, Sendable, Equatable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let category: String
    let searchQuery: String
    let fields: [GrokInsightField]
    let reviews: [String]

    var reviewPoints: [String] {
        reviews
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var hasReviews: Bool { !reviewPoints.isEmpty }

    var visibleFieldRows: [GrokVisibleFieldRow] {
        GrokVisibleField.allCases.map { field in
            let raw = value(for: field)
            let value = Self.hasContent(raw) ? raw : "정보 없음"
            return GrokVisibleFieldRow(label: field.title, value: value)
        }
    }

    var hasVisibleFieldContent: Bool {
        visibleFieldRows.contains { !$0.isMissing }
    }

    var hasAnyInsight: Bool {
        hasVisibleFieldContent || hasReviews
    }

    var isCurrentlyOpen: Bool? {
        BusinessHoursParser.isOpenNow(
            businessHours: value(for: .businessHours),
            breakTime: value(for: .breakTime)
        )
    }

    static func from(place: Place, response: GrokPlaceSearchResponse, searchQuery: String) -> GrokPlaceDetail {
        GrokPlaceDetail(
            name: place.name,
            address: place.address,
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            category: place.category,
            searchQuery: searchQuery,
            fields: response.fields,
            reviews: response.reviews
        )
    }

    func editableValue(for field: GrokVisibleField) -> String {
        value(for: field)
    }

    private func value(for field: GrokVisibleField) -> String {
        for insight in fields {
            let normalizedLabel = normalize(insight.label)
            if field.matchKeywords.contains(where: { normalize($0) == normalizedLabel || normalizedLabel.contains(normalize($0)) }) {
                return insight.value
            }
        }
        return ""
    }

    private func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }

    private static func hasContent(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "정보 없음"
    }
}