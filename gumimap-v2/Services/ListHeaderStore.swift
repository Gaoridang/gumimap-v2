import Foundation
import SwiftUI

@Observable
@MainActor
final class ListHeaderStore {
    private(set) var prompts: [ListSubTab: ListHeaderPrompt] = [:]
    private(set) var shouldAnimatePrompt = false

    func prompt(for subTab: ListSubTab) -> ListHeaderPrompt? {
        prompts[subTab]
    }

    /// Picks a line once per sub-tab. Pass `rotate: true` only when intentionally showing a new line.
    func displayPrompt(for subTab: ListSubTab, rotate: Bool = false) {
        if prompts[subTab] == nil {
            prompts[subTab] = ListHeaderPromptLibrary.nextPrompt(for: subTab, excluding: nil)
            shouldAnimatePrompt = false
            return
        }

        guard rotate else { return }

        let lastText = prompts[subTab]?.fullText
        let next = ListHeaderPromptLibrary.nextPrompt(for: subTab, excluding: lastText)
        shouldAnimatePrompt = lastText != next.fullText
        prompts[subTab] = next
    }
}