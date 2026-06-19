import Foundation
import SwiftUI

@Observable
final class TabRouter {
    var selectedTab: AppTab = .map
    var listSubTab: ListSubTab = .visited

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

    func selectListSubTab(_ subTab: ListSubTab) {
        withAnimation(.easeInOut(duration: 0.2)) {
            listSubTab = subTab
        }
    }
}