import Foundation
import SwiftUI

@Observable
@MainActor
final class ListFilterStore {
    private var settingsBySubTab: [ListSubTab: ListPlaceFilterSettings] = [:]

    func settings(for subTab: ListSubTab) -> ListPlaceFilterSettings {
        settingsBySubTab[subTab] ?? ListPlaceFilterSettings()
    }

    func setSortOrder(_ sortOrder: ListPlaceSortOrder, for subTab: ListSubTab) {
        var settings = settings(for: subTab)
        settings.sortOrder = sortOrder
        settingsBySubTab[subTab] = settings
    }

    func setSelectedCategory(_ category: String?, for subTab: ListSubTab) {
        var settings = settings(for: subTab)
        settings.selectedCategory = category
        settingsBySubTab[subTab] = settings
    }

    func setOpenNowOnly(_ isEnabled: Bool, for subTab: ListSubTab) {
        var settings = settings(for: subTab)
        settings.openNowOnly = isEnabled
        settingsBySubTab[subTab] = settings
    }

    func reset(for subTab: ListSubTab) {
        settingsBySubTab[subTab] = ListPlaceFilterSettings()
    }
}