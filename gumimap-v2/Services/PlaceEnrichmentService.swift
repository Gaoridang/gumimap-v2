import Foundation
import SwiftUI

extension Notification.Name {
    static let savedPlaceEnrichmentUpdated = Notification.Name("savedPlaceEnrichmentUpdated")
    static let savedPlaceInfoUpdated = Notification.Name("savedPlaceInfoUpdated")
}

@Observable
@MainActor
final class PlaceEnrichmentService {
    private var pendingSavedPlaceIds: [String: Set<String>] = [:]
    private var tasks: [String: Task<Void, Never>] = [:]
    private(set) var progressBySavedPlaceId: [String: [GrokSearchProgress]] = [:]
    private(set) var runningSavedPlaceIds: Set<String> = []

    func schedule(savedPlaceId: String, place: Place, store: PlaceStore) {
        let placeId = place.id
        pendingSavedPlaceIds[placeId, default: []].insert(savedPlaceId)
        markRunning(savedPlaceId)

        guard tasks[placeId] == nil else { return }

        tasks[placeId] = Task {
            defer {
                tasks[placeId] = nil
                let savedIds = pendingSavedPlaceIds[placeId] ?? []
                pendingSavedPlaceIds[placeId] = nil
                clearProgress(for: savedIds)
            }

            do {
                let service = try GrokPlaceSearchService.makeFromSecrets()
                let detail = try await service.enrichPlace(place) { [weak self] progress in
                    Task { @MainActor in
                        self?.handleProgress(progress, placeId: placeId)
                    }
                }
                let savedIds = pendingSavedPlaceIds[placeId] ?? [savedPlaceId]

                for id in savedIds {
                    try store.updateEnrichment(savedPlaceId: id, detail: detail)
                }
            } catch {
                return
            }
        }
    }

    func progressLog(for savedPlaceId: String) -> [GrokSearchProgress] {
        progressBySavedPlaceId[savedPlaceId] ?? []
    }

    func isRunning(for savedPlaceId: String) -> Bool {
        runningSavedPlaceIds.contains(savedPlaceId)
    }

    private func markRunning(_ savedPlaceId: String) {
        runningSavedPlaceIds.insert(savedPlaceId)
        if progressBySavedPlaceId[savedPlaceId] == nil {
            progressBySavedPlaceId[savedPlaceId] = []
        }
    }

    private func handleProgress(_ progress: GrokSearchProgress, placeId: String) {
        let savedIds = pendingSavedPlaceIds[placeId] ?? []
        for id in savedIds {
            var log = progressBySavedPlaceId[id] ?? []
            guard log.last?.message != progress.message else { continue }
            log.append(progress)
            progressBySavedPlaceId[id] = log
        }
    }

    private func clearProgress(for savedPlaceIds: Set<String>) {
        for id in savedPlaceIds {
            runningSavedPlaceIds.remove(id)
            progressBySavedPlaceId[id] = nil
        }
    }
}

