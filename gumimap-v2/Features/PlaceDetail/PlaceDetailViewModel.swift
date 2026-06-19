import SwiftUI

@Observable
@MainActor
final class PlaceDetailViewModel {
    let place: Place

    private(set) var isLoading = false
    private(set) var progressLog: [GrokSearchProgress] = []
    private(set) var currentProgress: GrokSearchProgress?
    private(set) var detail: GrokPlaceDetail?
    private(set) var errorMessage: String?
    private(set) var revealStep = 0

    private var revealTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    init(place: Place) {
        self.place = place
    }

    var showProgress: Bool {
        isLoading || (revealStep == 0 && !progressLog.isEmpty)
    }

    var headerSubtitle: String {
        if isLoading {
            return "Grok이 장소 정보를 찾고 있어요."
        }
        if revealStep >= 1, detail != nil {
            return "상세 정보를 불러왔어요."
        }
        if errorMessage != nil {
            return "정보를 불러오지 못했어요."
        }
        return place.address
    }

    func loadIfNeeded() {
        guard loadTask == nil, detail == nil, errorMessage == nil else { return }
        loadTask = Task { await load() }
    }

    func cancelTasks() {
        loadTask?.cancel()
        loadTask = nil
        cancelReveal()
    }

    private func load() async {
        cancelReveal()
        errorMessage = nil
        detail = nil
        progressLog = []
        currentProgress = nil
        revealStep = 0

        withAnimation(.easeInOut(duration: 0.3)) {
            isLoading = true
        }
        defer {
            withAnimation(.easeInOut(duration: 0.3)) {
                isLoading = false
            }
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
            startReveal()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            currentProgress = nil
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

            for step in 2 ... 5 {
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    revealStep = step
                }
            }
        }
    }

    private func cancelReveal() {
        revealTask?.cancel()
        revealTask = nil
    }
}