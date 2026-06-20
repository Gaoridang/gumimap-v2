import CoreLocation
import Foundation
import SwiftData

@Model
final class SavedPlace {
    @Attribute(.unique) var id: String
    var kakaoPlaceId: String
    var listKind: String
    var name: String
    var address: String
    var category: String
    var phone: String?
    var kakaoMapURLString: String?
    var latitude: Double
    var longitude: Double
    var enrichmentData: Data?
    var registeredAt: Date
    var updatedAt: Date

    init(
        id: String,
        kakaoPlaceId: String,
        listKind: ListSubTab,
        name: String,
        address: String,
        category: String,
        phone: String?,
        kakaoMapURLString: String?,
        latitude: Double,
        longitude: Double,
        enrichmentData: Data?,
        registeredAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.kakaoPlaceId = kakaoPlaceId
        self.listKind = listKind.rawValue
        self.name = name
        self.address = address
        self.category = category
        self.phone = phone
        self.kakaoMapURLString = kakaoMapURLString
        self.latitude = latitude
        self.longitude = longitude
        self.enrichmentData = enrichmentData
        self.registeredAt = registeredAt
        self.updatedAt = updatedAt
    }

    var listSubTab: ListSubTab? {
        ListSubTab(rawValue: listKind)
    }

    var asPlace: Place {
        Place(
            id: kakaoPlaceId,
            name: name,
            address: address,
            category: category,
            phone: phone,
            kakaoMapURL: kakaoMapURLString.flatMap(URL.init(string:)),
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        )
    }

    var grokDetail: GrokPlaceDetail? {
        guard let enrichmentData else { return nil }
        return try? JSONDecoder().decode(GrokPlaceDetail.self, from: enrichmentData)
    }

    static func makeID(kakaoPlaceId: String, listKind: ListSubTab) -> String {
        "\(kakaoPlaceId)-\(listKind.rawValue)"
    }
}