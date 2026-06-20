import CoreLocation
import KakaoMapsSDK
import UIKit

final class KakaoMapCoordinator: NSObject, MapControllerDelegate, KakaoMapEventDelegate {
    private enum Constants {
        static let mapViewName = "mapview"
        static let layerID = "saved-places"
        static let defaultLevel: Int = 10
    }

    private let runtimeState: KakaoMapRuntimeState
    private let onPinTap: (String) -> Void
    private weak var viewContainer: KMViewContainer?
    private weak var mapController: KMController?
    private var isMapReady = false
    private var didAuthenticate = false
    private var didCallAddViews = false
    private var didSetInitialCamera = false
    private var lastAppliedSize: CGSize = .zero
    private var pendingContainerSize: CGSize = .zero
    private var pendingPlaces: [SavedPlace] = []
    private var displayedPlaceIDs: Set<String> = []
    private var registeredStyleIDs: Set<String> = []
    private var observersInstalled = false

    init(runtimeState: KakaoMapRuntimeState, onPinTap: @escaping (String) -> Void) {
        self.runtimeState = runtimeState
        self.onPinTap = onPinTap
        super.init()
    }

    func attach(to container: KMViewContainer) {
        guard mapController == nil else { return }

        setPhase(.loading)
        viewContainer = container

        let controller = KMController(viewContainer: container)
        controller.delegate = self
        mapController = controller
        installAppLifecycleObserversIfNeeded()

        let prepared = controller.prepareEngine()
        refreshDebug(event: "prepareEngine(\(prepared))")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.activateIfNeeded()
        }
    }

    func tearDown() {
        removeAppLifecycleObservers()
        mapController?.pauseEngine()
        refreshDebug(event: "tearDown")
    }

    func activateIfNeeded() {
        guard let controller = mapController else { return }
        guard controller.isEnginePrepared else {
            refreshDebug(event: "activateSkipped(notPrepared)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.activateIfNeeded()
            }
            return
        }
        guard controller.isEngineActive == false else { return }

        controller.activateEngine()
        refreshDebug(event: "activateEngine")
    }

    func pause() {
        mapController?.pauseEngine()
        refreshDebug(event: "pauseEngine")
    }

    func updatePlaces(_ places: [SavedPlace]) {
        pendingPlaces = places
        syncPinsIfReady()
    }

    func handleContainerResize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        pendingContainerSize = size
        applyLayoutIfPossible()
        refreshDebug(event: "containerResize \(KakaoMapDebugSnapshot.format(size))")
    }

    // MARK: - MapControllerDelegate

    @objc func addViews() {
        didCallAddViews = true
        refreshDebug(event: "delegate.addViews")

        let center = SearchRegion.gumiCenter
        let defaultPosition = MapPoint(longitude: center.longitude, latitude: center.latitude)
        let mapviewInfo = MapviewInfo(
            viewName: Constants.mapViewName,
            viewInfoName: "map",
            defaultPosition: defaultPosition,
            defaultLevel: Constants.defaultLevel
        )

        mapController?.addView(mapviewInfo)
        refreshDebug(event: "addView called")
    }

    @objc func addViewSucceeded(_ viewName: String, viewInfoName: String) {
        guard viewName == Constants.mapViewName else { return }

        kakaoMap?.eventDelegate = self
        setupLabelLayer()
        isMapReady = true
        setPhase(.ready)

        applyLayoutIfPossible(force: true)
        syncPinsIfReady()
        refreshDebug(event: "addViewSucceeded(\(viewInfoName))")
    }

    @objc func addViewFailed(_ viewName: String, viewInfoName: String) {
        setPhase(.addViewFailed)
        refreshDebug(event: "addViewFailed(\(viewName))")
        print("Kakao Maps addView failed: \(viewName) / \(viewInfoName)")
    }

    @objc func containerDidResized(_ size: CGSize) {
        handleContainerResize(size)
        refreshDebug(event: "delegate.containerDidResized")
    }

    @objc func authenticationSucceeded() {
        didAuthenticate = true
        activateIfNeeded()
        refreshDebug(event: "authenticationSucceeded")
    }

    @objc func authenticationFailed(_ errorCode: Int, desc: String) {
        setPhase(.authFailed(code: errorCode, message: desc))
        refreshDebug(event: "authenticationFailed(\(errorCode))")
        print("Kakao Maps authentication failed (\(errorCode)): \(desc)")
    }

    // MARK: - KakaoMapEventDelegate

    @objc func poiDidTapped(
        kakaoMap: KakaoMap,
        layerID: String,
        poiID: String,
        position: MapPoint
    ) {
        guard layerID == Constants.layerID else { return }
        onPinTap(poiID)
    }

    // MARK: - Private

    private func applyLayoutIfPossible(force: Bool = false) {
        let size = pendingContainerSize
        guard size.width > 0, size.height > 0 else { return }
        guard let mapView = kakaoMap else { return }
        guard force || size != lastAppliedSize else { return }

        lastAppliedSize = size
        mapView.viewRect = CGRect(origin: .zero, size: size)
        setInitialCameraIfNeeded(on: mapView)
        refreshDebug(event: "applyViewRect \(KakaoMapDebugSnapshot.format(size))")
    }

    private func setupLabelLayer() {
        guard let mapView = kakaoMap else { return }
        let manager = mapView.getLabelManager()
        guard manager.getLabelLayer(layerID: Constants.layerID) == nil else { return }

        let layerOption = LabelLayerOptions(
            layerID: Constants.layerID,
            competitionType: .none,
            competitionUnit: .symbolFirst,
            orderType: .rank,
            zOrder: 1000
        )
        _ = manager.addLabelLayer(option: layerOption)
    }

    private var kakaoMap: KakaoMap? {
        mapController?.getView(Constants.mapViewName) as? KakaoMap
    }

    private func setInitialCameraIfNeeded(on mapView: KakaoMap) {
        guard !didSetInitialCamera else { return }

        let center = SearchRegion.gumiCenter
        let target = MapPoint(longitude: center.longitude, latitude: center.latitude)
        let cameraUpdate = CameraUpdate.make(
            target: target,
            zoomLevel: Constants.defaultLevel,
            mapView: mapView
        )
        mapView.moveCamera(cameraUpdate)
        didSetInitialCamera = true
        refreshDebug(event: "moveCamera(level:\(Constants.defaultLevel))")
    }

    private func syncPinsIfReady() {
        guard isMapReady, let mapView = kakaoMap else { return }
        let manager = mapView.getLabelManager()
        guard let layer = manager.getLabelLayer(layerID: Constants.layerID) else { return }

        let nextPlaces = pendingPlaces.filter { $0.listSubTab != nil }
        let nextIDs = Set(nextPlaces.map(\.id))

        for removedID in displayedPlaceIDs.subtracting(nextIDs) {
            layer.removePoi(poiID: removedID)
        }

        for place in nextPlaces {
            guard let listKind = place.listSubTab else { continue }
            guard !displayedPlaceIDs.contains(place.id) else { continue }

            let styleID = KakaoMapPinImageRenderer.styleID(listKind: listKind, category: place.category)
            ensureStyleRegistered(styleID: styleID, listKind: listKind, category: place.category, manager: manager)

            let coordinate = place.asPlace.coordinate
            let position = MapPoint(longitude: coordinate.longitude, latitude: coordinate.latitude)
            let options = PoiOptions(styleID: styleID, poiID: place.id)
            options.rank = 0
            options.clickable = true

            guard let poi = layer.addPoi(option: options, at: position) else { continue }
            poi.show()
        }

        displayedPlaceIDs = nextIDs
        refreshDebug(event: "syncPins(\(nextIDs.count))")
    }

    private func ensureStyleRegistered(
        styleID: String,
        listKind: ListSubTab,
        category: String,
        manager: LabelManager
    ) {
        guard !registeredStyleIDs.contains(styleID) else { return }

        let image = KakaoMapPinImageRenderer.image(listKind: listKind, category: category)
        let iconStyle = PoiIconStyle(symbol: image, anchorPoint: CGPoint(x: 0.5, y: 1.0))
        let perLevelStyle = PerLevelPoiStyle(iconStyle: iconStyle, level: 0)
        let poiStyle = PoiStyle(styleID: styleID, styles: [perLevelStyle])
        manager.addPoiStyle(poiStyle)
        registeredStyleIDs.insert(styleID)
    }

    private func setPhase(_ phase: KakaoMapRuntimeState.Phase) {
        Task { @MainActor in
            runtimeState.phase = phase
            refreshDebugOnMain()
        }
    }

    func refreshDebug(event: String? = nil, isMapTabActive: Bool? = nil) {
        Task { @MainActor in
            refreshDebugOnMain(event: event, isMapTabActive: isMapTabActive)
        }
    }

    @MainActor
    private func refreshDebugOnMain(event: String? = nil, isMapTabActive: Bool? = nil) {
        if let event {
            runtimeState.record(event: event)
        }

        runtimeState.apply { snapshot in
            snapshot.phaseLabel = Self.livePhaseLabel(
                phase: runtimeState.phase,
                enginePrepared: mapController?.isEnginePrepared ?? false,
                engineActive: mapController?.isEngineActive ?? false,
                didCallAddViews: didCallAddViews,
                isMapReady: isMapReady,
                didAuthenticate: didAuthenticate
            )
            if let isMapTabActive {
                snapshot.isMapTabActive = isMapTabActive
            }
            snapshot.sdkPhase = String(describing: SDKInitializer.GetPhase())
            snapshot.isEnginePrepared = mapController?.isEnginePrepared ?? false
            snapshot.isEngineActive = mapController?.isEngineActive ?? false
            snapshot.isMapReady = isMapReady
            snapshot.didAuthenticate = didAuthenticate
            snapshot.hasMapView = kakaoMap != nil
            snapshot.viewRectApplied = lastAppliedSize.width > 0 && lastAppliedSize.height > 0
            snapshot.cameraSet = didSetInitialCamera
            snapshot.containerSize = KakaoMapDebugSnapshot.format(viewContainer?.bounds.size ?? .zero)
            snapshot.pendingSize = KakaoMapDebugSnapshot.format(pendingContainerSize)
            snapshot.appliedViewRectSize = KakaoMapDebugSnapshot.format(lastAppliedSize)
            snapshot.pinCount = displayedPlaceIDs.count
            snapshot.engineStateMessage = mapController?.getStateDescMessage() ?? "(no controller)"
            if case let .authFailed(code, message) = runtimeState.phase {
                snapshot.authError = "[\(code)] \(message)"
            } else {
                snapshot.authError = nil
            }
        }
    }

    private static func livePhaseLabel(
        phase: KakaoMapRuntimeState.Phase,
        enginePrepared: Bool,
        engineActive: Bool,
        didCallAddViews: Bool,
        isMapReady: Bool,
        didAuthenticate: Bool
    ) -> String {
        switch phase {
        case .ready:
            return "ready"
        case .authFailed:
            return "authFailed"
        case .addViewFailed:
            return "addViewFailed"
        case .loading:
            if isMapReady { return "ready" }
            if didCallAddViews { return "addingView" }
            if engineActive { return "engineActive" }
            if enginePrepared { return "enginePrepared" }
            if didAuthenticate { return "authenticated" }
            return "loading"
        }
    }

    // MARK: - App lifecycle

    private func installAppLifecycleObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    private func removeAppLifecycleObservers() {
        guard observersInstalled else { return }
        observersInstalled = false
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleWillResignActive() {
        mapController?.pauseEngine()
        refreshDebug(event: "app.willResignActive")
    }

    @objc private func handleDidBecomeActive() {
        activateIfNeeded()
        refreshDebug(event: "app.didBecomeActive")
    }
}