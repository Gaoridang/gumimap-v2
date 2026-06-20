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

    var hasAnyInsight: Bool {
        !displayFields.isEmpty || hasReviews
    }

    var displayFields: [GrokInsightField] {
        fields.filter { field in
            let value = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !value.isEmpty && value != "정보 없음"
        }
    }

    var jsonPayload: GrokPlaceSearchResponse {
        GrokPlaceSearchResponse(fields: fields, reviews: reviews)
    }

    var prettyJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(jsonPayload),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    var isCurrentlyOpen: Bool? {
        BusinessHoursParser.isOpenNow(
            businessHours: fieldValue(matching: ["영업시간", "영업 시간", "운영시간"]),
            breakTime: fieldValue(matching: ["브레이크", "브레이크타임", "브레이크 타임"])
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

    private func fieldValue(matching keywords: [String]) -> String {
        for field in fields {
            let normalizedLabel = field.label
                .replacingOccurrences(of: " ", with: "")
                .lowercased()

            if keywords.contains(where: { normalizedLabel.contains($0.replacingOccurrences(of: " ", with: "").lowercased()) }) {
                return field.value
            }
        }
        return ""
    }
}