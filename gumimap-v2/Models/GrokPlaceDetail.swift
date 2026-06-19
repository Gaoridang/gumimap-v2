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
    let businessHours: String
    let isOpenNow: Bool

    var hasBusinessHours: Bool {
        !businessHours.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var formattedJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}