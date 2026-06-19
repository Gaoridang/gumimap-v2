import CoreLocation
import SwiftUI

@Observable
@MainActor
final class SearchViewModel {
    var query = "" {
        didSet { scheduleSearch() }
    }

    private(set) var results: [Place] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service: KakaoLocalService
    private var searchTask: Task<Void, Never>?
    private var requestID = 0

    init(service: KakaoLocalService = KakaoLocalService()) {
        self.service = service
    }

    func reset() {
        searchTask?.cancel()
        query = ""
        results = []
        isLoading = false
        errorMessage = nil
    }

    func select(_ place: Place) {
        // TODO: Navigate map camera / save to list
        print("Selected place: \(place.name) (\(place.coordinate.latitude), \(place.coordinate.longitude))")
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isLoading = false
            errorMessage = nil
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await performSearch(for: trimmed)
        }
    }

    private func performSearch(for keyword: String) async {
        requestID += 1
        let currentRequestID = requestID

        isLoading = true
        errorMessage = nil

        do {
            let places = try await service.search(keyword: keyword)
            guard currentRequestID == requestID else { return }
            results = places
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            guard currentRequestID == requestID else { return }
            results = []
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}