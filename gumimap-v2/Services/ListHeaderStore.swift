import Foundation
import SwiftUI

@Observable
@MainActor
final class ListHeaderStore {
    private(set) var prompts: [ListSubTab: ListHeaderPrompt] = [:]
    private(set) var loadingTabs: Set<ListSubTab> = []
    private(set) var shouldAnimatePrompt = false

    private var loadTasks: [String: Task<Void, Never>] = [:]
    private var lastLoadKey: [ListSubTab: String] = [:]

    private static let fallbackDelay: Duration = .milliseconds(450)

    func prompt(for subTab: ListSubTab) -> ListHeaderPrompt? {
        prompts[subTab]
    }

    func isLoading(_ subTab: ListSubTab) -> Bool {
        loadingTabs.contains(subTab)
    }

    func hasGrokPrompt(for subTab: ListSubTab) -> Bool {
        guard let cached = prompts[subTab] else { return false }
        return cached.fullText != ListHeaderPrompt.fallback(for: subTab).fullText
    }

    func loadIfNeeded(subTab: ListSubTab, placeCount: Int) {
        guard placeCount > 0 else { return }

        let loadKey = "\(subTab.rawValue)-\(placeCount)"
        guard lastLoadKey[subTab] != loadKey else { return }
        lastLoadKey[subTab] = loadKey

        loadTasks[subTab.rawValue]?.cancel()
        loadTasks[subTab.rawValue] = Task {
            defer {
                loadingTabs.remove(subTab)
                loadTasks[subTab.rawValue] = nil
            }

            guard Secrets.isGrokConfigured else {
                if prompts[subTab] == nil {
                    shouldAnimatePrompt = false
                    prompts[subTab] = ListHeaderPrompt.fallback(for: subTab)
                }
                return
            }

            loadingTabs.insert(subTab)

            let fallbackTask = Task {
                try? await Task.sleep(for: Self.fallbackDelay)
                guard !Task.isCancelled, prompts[subTab] == nil else { return }
                shouldAnimatePrompt = false
                prompts[subTab] = ListHeaderPrompt.fallback(for: subTab)
            }

            do {
                let service = try GrokListHeaderService.makeFromSecrets()
                let generated = try await service.generatePrompt(
                    subTab: subTab,
                    placeCount: placeCount
                )
                fallbackTask.cancel()
                guard !Task.isCancelled else { return }

                let existingText = prompts[subTab]?.fullText
                guard existingText != generated.fullText else { return }

                shouldAnimatePrompt = hasGrokPrompt(for: subTab)
                prompts[subTab] = generated
            } catch {
                fallbackTask.cancel()
                if prompts[subTab] == nil {
                    shouldAnimatePrompt = false
                    prompts[subTab] = ListHeaderPrompt.fallback(for: subTab)
                }
            }
        }
    }

    func cancelAll() {
        for task in loadTasks.values {
            task.cancel()
        }
        loadTasks.removeAll()
        loadingTabs.removeAll()
    }
}