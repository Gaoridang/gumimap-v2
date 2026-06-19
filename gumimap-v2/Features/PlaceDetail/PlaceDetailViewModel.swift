import SwiftUI

enum EnrichmentState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

@Observable
@MainActor
final class PlaceDetailViewModel {
    let place: Place

    private(set) var enrichmentState: EnrichmentState = .idle
    private(set) var progressLog: [GrokSearchProgress] = []
    private(set) var currentProgress: GrokSearchProgress?
    private(set) var detail: GrokPlaceDetail?
    private(set) var revealStep = 0

    private var revealTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    init(place: Place) {
        self.place = place
    }

    var isLoading: Bool {
        enrichmentState == .loading
    }

    var enrichmentError: String? {
        if case let .failed(message) = enrichmentState { return message }
        return nil
    }

    var isOpenNow: Bool? {
        guard case .loaded = enrichmentState, let detail else { return nil }
        return detail.isOpenNow
    }

    var showProgress: Bool {
        isLoading || (revealStep == 0 && !progressLog.isEmpty)
    }

    var showAdditionalInfo: Bool {
        switch enrichmentState {
        case .loaded, .failed:
            true
        case .idle, .loading:
            false
        }
    }

    var headerSubtitle: String {
        switch enrichmentState {
        case .loading:
            return "Grok이 추가 정보를 찾고 있어요."
        case .loaded:
            if let detail {
                return detail.isOpenNow ? "지금 영업 중이에요." : "지금은 영업 시간이 아니에요."
            }
            return "추가 정보를 불러왔어요."
        case .failed:
            return place.address
        case .idle:
            return place.address
        }
    }

    func loadIfNeeded() {
        guard loadTask == nil else { return }
        switch enrichmentState {
        case .loading, .loaded:
            return
        case .idle, .failed:
            break
        }
        loadTask = Task { await load() }
    }

    func retryEnrichment() {
        guard !isLoading else { return }
        loadTask?.cancel()
        loadTask = nil
        cancelReveal()
        enrichmentState = .idle
        detail = nil
        progressLog = []
        currentProgress = nil
        revealStep = 0
        loadTask = Task { await load() }
    }

    func cancelTasks() {
        loadTask?.cancel()
        loadTask = nil
        cancelReveal()
    }

    func register() {
        // TODO: persist place + Grok insights
    }

    private func load() async {
        cancelReveal()
        detail = nil
        progressLog = []
        currentProgress = nil
        revealStep = 0

        withAnimation(.easeInOut(duration: 0.3)) {
            enrichmentState = .loading
        }
        defer {
            loadTask = nil
        }

        do {
            let service = try GrokPlaceSearchService.makeFromSecrets()
            let result = try await service.enrichPlace(
                name: place.name,
                address: place.address,
                onProgress: handleProgress
            )
            guard !Task.isCancelled else { return }
            detail = result
            currentProgress = nil
            withAnimation(.easeInOut(duration: 0.3)) {
                enrichmentState = .loaded
            }
            startReveal()
        } catch is CancellationError {
            if enrichmentState == .loading {
                enrichmentState = .idle
            }
            return
        } catch {
            guard !Task.isCancelled else { return }
            currentProgress = nil
            withAnimation(.easeInOut(duration: 0.3)) {
                enrichmentState = .failed(error.localizedDescription)
            }
        }
    }

    private func handleProgress(_ progress: GrokSearchProgress) {
        Task { @MainActor in
            currentProgress = progress
            guard progressLog.last?.message != progress.message else { return }
            withAnimation(.snappy) {
                progressLog.append(progress)
            }
        }
    }

    private func startReveal() {
        revealTask?.cancel()
        revealTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                revealStep = 1
            }

            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                revealStep = 2
            }
        }
    }

    private func cancelReveal() {
        revealTask?.cancel()
        revealTask = nil
    }
}