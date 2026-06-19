import SwiftUI

@Observable
final class SearchViewModel {
    var query = "" {
        didSet { updateResults() }
    }
    private(set) var results: [MockPlace] = []

    private let allPlaces = MockPlace.samples

    func reset() {
        query = ""
        results = []
    }

    func select(_ place: MockPlace) {
        // TODO: Navigate map camera / save to list
        print("Selected place: \(place.name)")
    }

    private func updateResults() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }

        results = allPlaces.filter { place in
            place.name.localizedCaseInsensitiveContains(trimmed)
                || place.address.localizedCaseInsensitiveContains(trimmed)
                || place.category.localizedCaseInsensitiveContains(trimmed)
        }
    }
}