import Foundation

enum ListPlaceSortOrder: String, CaseIterable, Hashable {
    case newest
    case name

    var title: String {
        switch self {
        case .newest:
            "최신순"
        case .name:
            "이름순"
        }
    }
}

struct ListPlaceFilterSettings: Equatable {
    var sortOrder: ListPlaceSortOrder = .newest
    var selectedCategory: String?

    var isActive: Bool {
        selectedCategory != nil || sortOrder != .newest
    }
}

enum ListPlaceFilter {
    static func availableCategories(in places: [SavedPlace]) -> [String] {
        let categories = places
            .map(\.shortCategory)
            .filter { !$0.isEmpty }
        return Array(Set(categories)).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    static func apply(_ settings: ListPlaceFilterSettings, to places: [SavedPlace]) -> [SavedPlace] {
        var result = places

        if let category = settings.selectedCategory {
            result = result.filter { $0.shortCategory == category }
        }

        switch settings.sortOrder {
        case .newest:
            result.sort { $0.registeredAt > $1.registeredAt }
        case .name:
            result.sort {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }

        return result
    }
}