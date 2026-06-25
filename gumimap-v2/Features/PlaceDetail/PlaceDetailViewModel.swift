import CoreLocation
import SwiftUI

enum EnrichmentState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

enum PlaceDetailMode: Equatable {
    case discovery(Place)
    case saved(id: String)
}

enum RegistrationState: Equatable {
    case idle
    case saving
    case failed(String)
}

@Observable
@MainActor
final class PlaceDetailViewModel {
    let mode: PlaceDetailMode

    private(set) var place: Place
    private(set) var enrichmentState: EnrichmentState = .idle
    private(set) var progressLog: [GrokSearchProgress] = []
    private(set) var currentProgress: GrokSearchProgress?
    private(set) var detail: GrokPlaceDetail?
    private(set) var revealStep = 0
    private(set) var registrationState: RegistrationState = .idle
    private(set) var savedListKind: ListSubTab?
    private(set) var existingSavedListKind: ListSubTab?
    private(set) var requestedAdditionalInfo = false

    private var revealTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    var isDiscoveryMode: Bool {
        if case .discovery = mode { return true }
        return false
    }

    init(place: Place) {
        mode = .discovery(place)
        self.place = place
    }

    init(savedPlaceId: String, store: PlaceStore) {
        mode = .saved(id: savedPlaceId)
        if let saved = store.savedPlace(id: savedPlaceId) {
            savedListKind = saved.listSubTab
            place = saved.asPlace
            detail = saved.grokDetail
            if saved.grokDetail != nil {
                enrichmentState = .loaded
                revealStep = 2
            } else {
                enrichmentState = .idle
                revealStep = 0
            }
        } else {
            place = Place(
                id: savedPlaceId,
                name: "저장된 장소",
                address: "",
                category: "",
                phone: nil,
                kakaoMapURL: nil,
                coordinate: .init(latitude: 0, longitude: 0)
            )
            enrichmentState = .failed("저장된 장소를 찾을 수 없어요.")
            revealStep = 2
        }
    }

    var isLoading: Bool {
        enrichmentState == .loading
    }

    var isSavingRegistration: Bool {
        registrationState == .saving
    }

    var isAlreadySaved: Bool {
        existingSavedListKind != nil
    }

    var canRegister: Bool {
        isDiscoveryMode && !isSavingRegistration && !isAlreadySaved
    }

    var savedPlaceId: String? {
        if case let .saved(id) = mode { return id }
        return nil
    }

    var enrichmentError: String? {
        if case let .failed(message) = enrichmentState { return message }
        return nil
    }

    var isOpenNow: Bool? {
        guard case .loaded = enrichmentState, let detail else { return nil }
        return detail.isCurrentlyOpen
    }

    var showProgress: Bool {
        if isDiscoveryMode {
            return requestedAdditionalInfo && (isLoading || (revealStep == 0 && !progressLog.isEmpty))
        }
        return false
    }

    var showAdditionalInfo: Bool {
        if isDiscoveryMode {
            guard requestedAdditionalInfo else { return false }
        }
        switch enrichmentState {
        case .loaded, .failed:
            return true
        case .idle, .loading:
            return false
        }
    }

    var showAdditionalInfoButton: Bool {
        if isDiscoveryMode {
            return !requestedAdditionalInfo
        }
        guard enrichmentState == .idle else { return false }
        return true
    }

    func refreshSavedStatus(store: PlaceStore) {
        guard isDiscoveryMode else { return }
        existingSavedListKind = store.savedListKind(forKakaoPlaceId: place.id)
    }

    func requestAdditionalInfo(
        enrichmentService: PlaceEnrichmentService,
        store: PlaceStore
    ) {
        if isDiscoveryMode {
            guard !requestedAdditionalInfo else { return }
            requestedAdditionalInfo = true
            startEnrichmentLoad()
            return
        }

        guard let savedPlaceId else { return }
        guard enrichmentState == .idle else { return }
        guard !enrichmentService.isRunning(for: savedPlaceId) else { return }

        enrichmentService.schedule(
            savedPlaceId: savedPlaceId,
            place: place,
            store: store
        )
    }

    func retryEnrichment() {
        guard isDiscoveryMode else { return }
        guard requestedAdditionalInfo else { return }
        guard !isLoading else { return }
        loadTask?.cancel()
        loadTask = nil
        cancelReveal()
        enrichmentState = .idle
        detail = nil
        progressLog = []
        currentProgress = nil
        revealStep = 0
        startEnrichmentLoad()
    }

    private func startEnrichmentLoad() {
        guard isDiscoveryMode else { return }
        guard loadTask == nil else { return }
        switch enrichmentState {
        case .loading, .loaded:
            return
        case .idle, .failed:
            break
        }
        loadTask = Task { await load() }
    }

    func cancelTasks() {
        loadTask?.cancel()
        loadTask = nil
        cancelReveal()
    }

    func register(
        listKind: ListSubTab,
        store: PlaceStore
    ) async -> String? {
        guard isDiscoveryMode else { return nil }
        guard canRegister else { return nil }

        registrationState = .saving

        do {
            let savedPlaceId = try store.register(
                place: place,
                detail: detail,
                listKind: listKind
            )

            registrationState = .idle
            return savedPlaceId
        } catch {
            registrationState = .failed(error.localizedDescription)
            return nil
        }
    }

    func refreshFromStore(store: PlaceStore) {
        guard let savedPlaceId else { return }
        guard let saved = store.savedPlace(id: savedPlaceId) else { return }

        place = saved.asPlace

        if let grokDetail = saved.grokDetail {
            detail = grokDetail
            enrichmentState = .loaded
            revealStep = 2
        } else {
            detail = nil
            enrichmentState = .idle
            revealStep = 0
        }
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
                place,
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
        currentProgress = progress
        guard progressLog.last?.message != progress.message else { return }
        withAnimation(.snappy) {
            progressLog.append(progress)
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