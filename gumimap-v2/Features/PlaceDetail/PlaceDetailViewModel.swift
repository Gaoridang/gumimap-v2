import SwiftUI

@Observable
@MainActor
final class PlaceDetailViewModel {
    private(set) var enrichment: PlaceEnrichment?
    private(set) var isLoadingEnrichment = false
    private(set) var enrichmentErrorMessage: String?
    private(set) var enrichmentActivities: [GrokEnrichmentActivity] = []

    private let grokService: GrokPlaceService
    private var loadTask: Task<Void, Never>?
    private var loadedPlaceID: String?

    init(grokService: GrokPlaceService = GrokPlaceService()) {
        self.grokService = grokService
    }

    func loadEnrichment(for place: Place) {
        guard loadedPlaceID != place.id else { return }

        loadTask?.cancel()
        loadedPlaceID = place.id
        enrichment = nil
        enrichmentErrorMessage = nil
        enrichmentActivities = []

        loadTask = Task {
            isLoadingEnrichment = true
            defer { isLoadingEnrichment = false }

            do {
                let result = try await grokService.enrich(place: place) { [weak self] activity in
                    self?.handleActivity(activity)
                }
                guard !Task.isCancelled, loadedPlaceID == place.id else { return }
                enrichment = result
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, loadedPlaceID == place.id else { return }
                enrichmentErrorMessage = error.localizedDescription
            }
        }
    }

    func reset() {
        loadTask?.cancel()
        loadedPlaceID = nil
        enrichment = nil
        enrichmentErrorMessage = nil
        enrichmentActivities = []
        isLoadingEnrichment = false
    }

    private func handleActivity(_ activity: GrokEnrichmentActivity) {
        if let index = enrichmentActivities.firstIndex(where: { $0.id == activity.id }) {
            enrichmentActivities[index] = activity
        } else {
            enrichmentActivities.append(activity)
        }
    }
}