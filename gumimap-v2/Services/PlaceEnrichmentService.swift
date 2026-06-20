import Foundation
import SwiftUI

extension Notification.Name {
    static let savedPlaceEnrichmentUpdated = Notification.Name("savedPlaceEnrichmentUpdated")
    static let savedPlaceInfoUpdated = Notification.Name("savedPlaceInfoUpdated")
}

@MainActor
final class PlaceEnrichmentService {
    private var pendingSavedPlaceIds: [String: Set<String>] = [:]
    private var tasks: [String: Task<Void, Never>] = [:]

    func schedule(savedPlaceId: String, place: Place, store: PlaceStore) {
        let placeId = place.id
        pendingSavedPlaceIds[placeId, default: []].insert(savedPlaceId)

        guard tasks[placeId] == nil else { return }

        tasks[placeId] = Task {
            defer {
                tasks[placeId] = nil
                pendingSavedPlaceIds[placeId] = nil
            }

            do {
                let service = try GrokPlaceSearchService.makeFromSecrets()
                let detail = try await service.enrichPlace(place) { _ in }
                let savedIds = pendingSavedPlaceIds[placeId] ?? [savedPlaceId]

                for id in savedIds {
                    try store.updateEnrichment(savedPlaceId: id, detail: detail)
                }
            } catch {
                return
            }
        }
    }
}

private struct PlaceEnrichmentServiceKey: EnvironmentKey {
    static let defaultValue: PlaceEnrichmentService? = nil
}

extension EnvironmentValues {
    var placeEnrichmentService: PlaceEnrichmentService? {
        get { self[PlaceEnrichmentServiceKey.self] }
        set { self[PlaceEnrichmentServiceKey.self] = newValue }
    }
}