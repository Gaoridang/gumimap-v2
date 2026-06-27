import Foundation
import SwiftData

@Model
final class PlacePhoto {
    @Attribute(.unique) var id: String
    var savedPlaceId: String
    var fileName: String
    var createdAt: Date
    var sortOrder: Int

    init(
        id: String,
        savedPlaceId: String,
        fileName: String,
        createdAt: Date,
        sortOrder: Int
    ) {
        self.id = id
        self.savedPlaceId = savedPlaceId
        self.fileName = fileName
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}