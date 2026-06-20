import Foundation
import SwiftUI

@Observable
final class TabRouter {
    var selectedTab: AppTab = .map
    var listSubTab: ListSubTab = .visited
    var path: [AppRoute] = []
    var pendingMapFocusPlaceId: String?

    var isListMode: Bool { selectedTab == .list }

    private var toolbarAnimation: Animation {
        .spring(response: 0.38, dampingFraction: 0.78)
    }

    func selectMap() {
        withAnimation(toolbarAnimation) {
            selectedTab = .map
        }
    }

    func openList() {
        withAnimation(toolbarAnimation) {
            selectedTab = .list
        }
    }

    func openSearch() {
        path.append(.search)
    }

    func openSavedPlaceDetail(id: String) {
        path.append(.savedPlaceDetail(id: id))
    }

    func openSavedPlaceOnMap(id: String) {
        withAnimation(toolbarAnimation) {
            path = []
            selectedTab = .map
            pendingMapFocusPlaceId = id
        }
    }

    func selectListSubTab(_ subTab: ListSubTab) {
        withAnimation(.easeInOut(duration: 0.2)) {
            listSubTab = subTab
        }
    }

    func completeRegistration(savedPlaceId: String, listKind: ListSubTab) {
        withAnimation(toolbarAnimation) {
            path = []
            listSubTab = listKind
            selectedTab = .list
            path.append(.savedPlaceDetail(id: savedPlaceId))
        }
    }

    func replaceSavedPlaceDetail(savedPlaceId: String, listKind: ListSubTab) {
        withAnimation(toolbarAnimation) {
            if !path.isEmpty {
                path.removeLast()
            }
            listSubTab = listKind
            selectedTab = .list
            path.append(.savedPlaceDetail(id: savedPlaceId))
        }
    }
}