import CoreLocation
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class PlaceStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    func register(
        place: Place,
        detail: GrokPlaceDetail?,
        listKind: ListSubTab
    ) throws -> String {
        let id = SavedPlace.makeID(kakaoPlaceId: place.id, listKind: listKind)
        let enrichmentData = try detail.map { try JSONEncoder().encode($0) }
        let now = Date()

        if let existing = savedPlace(id: id) {
            existing.name = place.name
            existing.address = place.address
            existing.category = place.category
            existing.phone = place.phone
            existing.kakaoMapURLString = place.kakaoMapURL?.absoluteString
            existing.latitude = place.coordinate.latitude
            existing.longitude = place.coordinate.longitude
            if let enrichmentData {
                existing.enrichmentData = enrichmentData
            }
            existing.updatedAt = now
        } else {
            let saved = SavedPlace(
                id: id,
                kakaoPlaceId: place.id,
                listKind: listKind,
                name: place.name,
                address: place.address,
                category: place.category,
                phone: place.phone,
                kakaoMapURLString: place.kakaoMapURL?.absoluteString,
                latitude: place.coordinate.latitude,
                longitude: place.coordinate.longitude,
                enrichmentData: enrichmentData,
                registeredAt: now,
                updatedAt: now
            )
            modelContext.insert(saved)
        }

        try modelContext.save()
        return id
    }

    func updateEnrichment(savedPlaceId: String, detail: GrokPlaceDetail) throws {
        guard let saved = savedPlace(id: savedPlaceId) else { return }

        saved.enrichmentData = try JSONEncoder().encode(detail)
        saved.updatedAt = Date()
        try modelContext.save()

        NotificationCenter.default.post(
            name: .savedPlaceEnrichmentUpdated,
            object: savedPlaceId
        )
    }

    func savedPlace(id: String) -> SavedPlace? {
        var descriptor = FetchDescriptor<SavedPlace>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}

private struct PlaceStoreKey: EnvironmentKey {
    static let defaultValue: PlaceStore? = nil
}

extension EnvironmentValues {
    var placeStore: PlaceStore? {
        get { self[PlaceStoreKey.self] }
        set { self[PlaceStoreKey.self] = newValue }
    }
}