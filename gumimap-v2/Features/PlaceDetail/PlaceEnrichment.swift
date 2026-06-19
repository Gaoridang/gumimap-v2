import Foundation

struct PlaceEnrichment: Decodable, Equatable {
    let summary: String
    let highlights: [String]
    let visitTip: String

    enum CodingKeys: String, CodingKey {
        case summary
        case highlights
        case visitTip = "visit_tip"
    }
}