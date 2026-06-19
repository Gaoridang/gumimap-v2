import SwiftUI

@Observable
@MainActor
final class PlaceDetailViewModel {
    private(set) var enrichment: PlaceEnrichment?
    private(set) var isLoadingEnrichment = false
    private(set) var enrichmentErrorMessage: String?
    private(set) var enrichmentPhases: [GrokEnrichmentPhase] = []
    private(set) var enrichmentSearchStartedAt: Date?

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
        enrichmentPhases = []
        enrichmentSearchStartedAt = .now
        isLoadingEnrichment = true

        loadTask = Task {
            defer {
                isLoadingEnrichment = false
                enrichmentPhases = []
                enrichmentSearchStartedAt = nil
            }

            do {
                let result = try await grokService.enrich(place: place) { [weak self] phase in
                    self?.handlePhase(phase)
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
        enrichmentPhases = []
        enrichmentSearchStartedAt = nil
        isLoadingEnrichment = false
    }

    private func handlePhase(_ phase: GrokEnrichmentPhase) {
        if let index = enrichmentPhases.firstIndex(where: { $0.id == phase.id }) {
            enrichmentPhases[index] = phase
        } else {
            enrichmentPhases.append(phase)
        }
    }
}