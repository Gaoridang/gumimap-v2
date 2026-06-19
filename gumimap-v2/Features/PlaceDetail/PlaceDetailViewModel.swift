import SwiftUI

@Observable
@MainActor
final class PlaceDetailViewModel {
    private(set) var enrichment: PlaceEnrichment?
    private(set) var isLoadingEnrichment = false
    private(set) var enrichmentErrorMessage: String?
    private(set) var enrichmentSearchSteps: [GrokSearchStep] = []
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
        enrichmentSearchSteps = []
        enrichmentSearchStartedAt = .now

        loadTask = Task {
            isLoadingEnrichment = true
            defer {
                isLoadingEnrichment = false
                enrichmentSearchSteps = []
                enrichmentSearchStartedAt = nil
            }

            do {
                let result = try await grokService.enrich(place: place) { [weak self] step in
                    self?.handleSearchStep(step)
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
        enrichmentSearchSteps = []
        enrichmentSearchStartedAt = nil
        isLoadingEnrichment = false
    }

    private func handleSearchStep(_ step: GrokSearchStep) {
        if let index = enrichmentSearchSteps.firstIndex(where: { $0.id == step.id }) {
            enrichmentSearchSteps[index] = step
        } else {
            enrichmentSearchSteps.append(step)
        }
    }
}