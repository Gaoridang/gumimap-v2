import Foundation
import SwiftUI

@Observable
final class TabRouter {
    var selectedTab: AppTab = .map
    var listSubTab: ListSubTab = .visited
    private(set) var returnTab: AppTab = .map

    var isListMode: Bool { selectedTab == .list }
    var isSearchMode: Bool { selectedTab == .search }

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
        if selectedTab != .search {
            returnTab = selectedTab
        }
        withAnimation(toolbarAnimation) {
            selectedTab = .search
        }
    }

    func closeSearch() {
        withAnimation(toolbarAnimation) {
            selectedTab = returnTab
        }
    }

    func selectListSubTab(_ subTab: ListSubTab) {
        withAnimation(.easeInOut(duration: 0.2)) {
            listSubTab = subTab
        }
    }
}