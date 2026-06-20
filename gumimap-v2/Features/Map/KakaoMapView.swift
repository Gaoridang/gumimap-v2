import CoreLocation
import KakaoMapsSDK
import SwiftUI
import UIKit

struct KakaoMapView: UIViewRepresentable {
    let isActive: Bool
    let places: [SavedPlace]
    let runtimeState: KakaoMapRuntimeState
    let onPinTap: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(runtimeState: runtimeState, onPinTap: onPinTap)
    }

    func makeUIView(context: Context) -> KMViewContainer {
        let container = KMViewContainer()
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.backgroundColor = .systemBackground
        context.coordinator.attach(to: container)
        return container
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        uiView.layoutIfNeeded()
        context.coordinator.handleContainerResize(uiView.bounds.size)
        context.coordinator.updatePlaces(places)

        if isActive {
            context.coordinator.activateIfNeeded()
        } else {
            context.coordinator.pause()
        }
    }

    static func dismantleUIView(_ uiView: KMViewContainer, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    final class Coordinator: NSObject, MapControllerDelegate, KakaoMapEventDelegate {
        private enum Constants {
            static let mapViewName = "gumimap-main"
            static let layerID = "saved-places"
            static let defaultLevel: Int = 10
        }

        private let runtimeState: KakaoMapRuntimeState
        private let onPinTap: (String) -> Void
        private weak var viewContainer: KMViewContainer?
        private weak var mapController: KMController?
        private var isMapReady = false
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

            runtimeState.phase = .loading
            viewContainer = container
            let controller = KMController(viewContainer: container)
            controller.delegate = self
            mapController = controller
            installAppLifecycleObserversIfNeeded()
            controller.prepareEngine()
        }

        func tearDown() {
            removeAppLifecycleObservers()
            mapController?.pauseEngine()
        }

        func activateIfNeeded() {
            guard mapController?.isEngineActive == false else { return }
            mapController?.activateEngine()
        }

        func pause() {
            mapController?.pauseEngine()
        }

        func updatePlaces(_ places: [SavedPlace]) {
            pendingPlaces = places
            syncPinsIfReady()
        }

        func handleContainerResize(_ size: CGSize) {
            guard size.width > 0, size.height > 0 else { return }

            pendingContainerSize = size
            applyLayoutIfPossible()
        }

        private func applyLayoutIfPossible(force: Bool = false) {
            let size = pendingContainerSize
            guard size.width > 0, size.height > 0 else { return }
            guard let mapView = kakaoMap else { return }
            guard force || size != lastAppliedSize else { return }

            lastAppliedSize = size
            mapView.viewRect = CGRect(origin: .zero, size: size)
            setInitialCameraIfNeeded(on: mapView)
        }

        // MARK: - MapControllerDelegate

        func authenticationSucceeded() {
            activateIfNeeded()
        }

        func authenticationFailed(_ errorCode: Int, desc: String) {
            runtimeState.phase = .authFailed(code: errorCode, message: desc)
            print("Kakao Maps authentication failed (\(errorCode)): \(desc)")
        }

        func addViews() {
            let center = SearchRegion.gumiCenter
            let defaultPosition = MapPoint(longitude: center.longitude, latitude: center.latitude)
            let mapviewInfo = MapviewInfo(
                viewName: Constants.mapViewName,
                viewInfoName: "map",
                defaultPosition: defaultPosition,
                defaultLevel: Constants.defaultLevel
            )

            let viewSize = resolvedContainerSize()
            if viewSize.width > 0, viewSize.height > 0 {
                pendingContainerSize = viewSize
                mapController?.addView(mapviewInfo, viewSize: viewSize)
            } else {
                mapController?.addView(mapviewInfo)
            }
        }

        func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            guard viewName == Constants.mapViewName else { return }

            kakaoMap?.eventDelegate = self
            setupLabelLayer()
            isMapReady = true
            runtimeState.phase = .ready

            applyLayoutIfPossible(force: true)
            syncPinsIfReady()
        }

        func addViewFailed(_ viewName: String, viewInfoName: String) {
            runtimeState.phase = .addViewFailed
            print("Kakao Maps addView failed: \(viewName) / \(viewInfoName)")
        }

        func containerDidResized(_ size: CGSize) {
            handleContainerResize(size)
        }

        // MARK: - Pins

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

        private func resolvedContainerSize() -> CGSize {
            if pendingContainerSize.width > 0, pendingContainerSize.height > 0 {
                return pendingContainerSize
            }

            if let container = viewContainer {
                let size = container.bounds.size
                if size.width > 0, size.height > 0 {
                    return size
                }
            }

            if let screen = viewContainer?.window?.windowScene?.screen {
                return screen.bounds.size
            }

            return CGSize(width: 393, height: 852)
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

        func poiDidTapped(
            kakaoMap: KakaoMap,
            layerID: String,
            poiID: String,
            position: MapPoint
        ) {
            guard layerID == Constants.layerID else { return }
            onPinTap(poiID)
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
        }

        @objc private func handleDidBecomeActive() {
            activateIfNeeded()
        }
    }
}