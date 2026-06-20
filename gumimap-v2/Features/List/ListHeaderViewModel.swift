import Foundation

@Observable
@MainActor
final class ListHeaderViewModel {
    private(set) var prompt: ListHeaderPrompt = ListHeaderPrompt.fallback(for: .visited)
    private(set) var isLoading = false

    private var loadTask: Task<Void, Never>?
    private var requestToken = 0

    func load(subTab: ListSubTab, placeCount: Int) {
        loadTask?.cancel()
        requestToken += 1
        let token = requestToken

        prompt = ListHeaderPrompt.fallback(for: subTab)
        guard placeCount > 0, Secrets.isGrokConfigured else {
            isLoading = false
            return
        }

        isLoading = true
        loadTask = Task {
            defer {
                if token == requestToken {
                    isLoading = false
                }
            }

            do {
                let service = try GrokListHeaderService.makeFromSecrets()
                let generated = try await service.generatePrompt(
                    subTab: subTab,
                    placeCount: placeCount
                )
                guard !Task.isCancelled, token == requestToken else { return }
                prompt = generated
            } catch {
                guard token == requestToken else { return }
                prompt = ListHeaderPrompt.fallback(for: subTab)
            }
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
}