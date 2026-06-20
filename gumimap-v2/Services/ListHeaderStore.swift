import Foundation
import SwiftUI

@Observable
@MainActor
final class ListHeaderStore {
    private(set) var prompts: [ListSubTab: ListHeaderPrompt] = [:]
    private(set) var shouldAnimatePrompt = false

    func prompt(for subTab: ListSubTab) -> ListHeaderPrompt {
        prompts[subTab] ?? ListHeaderPromptLibrary.nextPrompt(for: subTab, excluding: nil)
    }

    func refreshPrompt(for subTab: ListSubTab) {
        let lastText = prompts[subTab]?.fullText
        let next = ListHeaderPromptLibrary.nextPrompt(for: subTab, excluding: lastText)
        shouldAnimatePrompt = lastText != nil && lastText != next.fullText
        prompts[subTab] = next
    }
}