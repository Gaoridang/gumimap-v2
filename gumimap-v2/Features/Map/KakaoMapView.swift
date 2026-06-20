import CoreLocation
import KakaoMapsSDK
import SwiftUI
import UIKit

struct KakaoMapView: UIViewRepresentable {
    var isActive: Bool
    let places: [SavedPlace]
    var focusPlaceId: String?
    var animatedFocus = false
    let onPinTap: (String) -> Void
    var onFocusCompleted: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onPinTap: onPinTap, onFocusCompleted: onFocusCompleted)
    }

    func makeUIView(context: Context) -> KMViewContainer {
        let container = KMViewContainer()
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.clipsToBounds = true
        context.coordinator.start(in: container)
        return container
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        let size = uiView.bounds.size
        if size.width > 0, size.height > 0 {
            context.coordinator.handleResize(size)
        }

        context.coordinator.updatePlaces(places)
        context.coordinator.onFocusCompleted = onFocusCompleted
        context.coordinator.applyFocus(
            placeId: focusPlaceId,
            in: places,
            animated: animatedFocus
        )

        if isActive {
            context.coordinator.activate()
        } else {
            context.coordinator.pause()
        }
    }

    static func dismantleUIView(_ uiView: KMViewContainer, coordinator: Coordinator) {
        coordinator.tearDown()
    }
}

// MARK: - Coordinator

extension KakaoMapView {
    final class Coordinator: NSObject, MapControllerDelegate, KakaoMapEventDelegate {
        private enum Constants {
            static let mapViewName = "mapview"
            static let layerID = "saved-places"
            static let defaultLevel = 12
            static let focusLevel = 17
            static let focusAnimationMillis: UInt = 700
        }

        private let onPinTap: (String) -> Void
        var onFocusCompleted: ((String) -> Void)?
        private weak var container: KMViewContainer?
        private var controller: KMController?
        private var isMapReady = false
        private var didSetInitialCamera = false
        private var lastAppliedSize: CGSize = .zero
        private var pendingPlaces: [SavedPlace] = []
        private var pendingFocusPlaceId: String?
        private var pendingFocusAnimated = false
        private var appliedFocusPlaceId: String?
        private var displayedPlaceIDs: Set<String> = []
        private var registeredStyleIDs: Set<String> = []
        private var observersInstalled = false

        init(
            onPinTap: @escaping (String) -> Void,
            onFocusCompleted: ((String) -> Void)?
        ) {
            self.onPinTap = onPinTap
            self.onFocusCompleted = onFocusCompleted
            super.init()
        }

        func start(in container: KMViewContainer) {
            guard controller == nil else { return }

            self.container = container
            let controller = KMController(viewContainer: container)
            controller.delegate = self
            self.controller = controller
            installAppLifecycleObserversIfNeeded()
            controller.prepareEngine()

            DispatchQueue.main.async { [weak self] in
                self?.activate()
            }
        }

        func activate() {
            guard let controller, controller.isEnginePrepared else { return }
            guard !controller.isEngineActive else { return }
            controller.activateEngine()
        }

        func pause() {
            controller?.pauseEngine()
        }

        func tearDown() {
            removeAppLifecycleObservers()
            controller?.pauseEngine()
        }

        func updatePlaces(_ places: [SavedPlace]) {
            pendingPlaces = places
            syncPinsIfReady()
        }

        func applyFocus(placeId: String?, in places: [SavedPlace], animated: Bool) {
            guard let placeId else {
                appliedFocusPlaceId = nil
                pendingFocusPlaceId = nil
                pendingFocusAnimated = false
                return
            }
            guard placeId != appliedFocusPlaceId else { return }

            guard isMapReady, let mapView = kakaoMap else {
                pendingFocusPlaceId = placeId
                pendingFocusAnimated = animated
                return
            }

            guard focusCamera(
                on: placeId,
                in: places,
                mapView: mapView,
                animated: animated
            ) else {
                pendingFocusPlaceId = placeId
                pendingFocusAnimated = animated
                return
            }

            pendingFocusPlaceId = nil
            pendingFocusAnimated = false
            appliedFocusPlaceId = placeId
        }

        func handleResize(_ size: CGSize) {
            guard size.width > 0, size.height > 0 else { return }
            guard let mapView = kakaoMap else { return }
            guard size != lastAppliedSize else { return }

            lastAppliedSize = size
            mapView.viewRect = CGRect(origin: .zero, size: size)
            setInitialCameraIfNeeded(on: mapView)
        }

        // MARK: MapControllerDelegate

        func addViews() {
            let center = SearchRegion.gumiCenter
            let defaultPosition = MapPoint(
                longitude: center.longitude,
                latitude: center.latitude
            )
            let mapviewInfo = MapviewInfo(
                viewName: Constants.mapViewName,
                viewInfoName: "map",
                defaultPosition: defaultPosition,
                defaultLevel: Constants.defaultLevel
            )
            controller?.addView(mapviewInfo)
        }

        func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            guard viewName == Constants.mapViewName else { return }

            kakaoMap?.eventDelegate = self
            setupLabelLayer()
            isMapReady = true

            if let mapView = kakaoMap,
               let size = container?.bounds.size,
               size.width > 0, size.height > 0 {
                lastAppliedSize = size
                mapView.viewRect = CGRect(origin: .zero, size: size)
                setInitialCameraIfNeeded(on: mapView)
            }

            syncPinsIfReady()
            applyPendingFocusIfNeeded()
        }

        func addViewFailed(_ viewName: String, viewInfoName: String) {
            print("Kakao Maps addView failed: \(viewName) / \(viewInfoName)")
        }

        func containerDidResized(_ size: CGSize) {
            handleResize(size)
        }

        func authenticationFailed(_ errorCode: Int, desc: String) {
            print("Kakao Maps authentication failed (\(errorCode)): \(desc)")
        }

        // MARK: KakaoMapEventDelegate

        func poiDidTapped(
            kakaoMap: KakaoMap,
            layerID: String,
            poiID: String,
            position: MapPoint
        ) {
            guard layerID == Constants.layerID else { return }
            onPinTap(poiID)
        }

        // MARK: Private

        private var kakaoMap: KakaoMap? {
            controller?.getView(Constants.mapViewName) as? KakaoMap
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

                let styleID = KakaoMapPinImageRenderer.styleID(
                    listKind: listKind,
                    category: place.category
                )
                ensureStyleRegistered(
                    styleID: styleID,
                    listKind: listKind,
                    category: place.category,
                    manager: manager
                )

                let coordinate = place.asPlace.coordinate
                let position = MapPoint(
                    longitude: coordinate.longitude,
                    latitude: coordinate.latitude
                )
                let options = PoiOptions(styleID: styleID, poiID: place.id)
                options.rank = 0
                options.clickable = true

                guard let poi = layer.addPoi(option: options, at: position) else { continue }
                poi.show()
            }

            displayedPlaceIDs = nextIDs
            applyPendingFocusIfNeeded()
        }

        private func applyPendingFocusIfNeeded() {
            guard let pendingFocusPlaceId else { return }
            applyFocus(
                placeId: pendingFocusPlaceId,
                in: pendingPlaces,
                animated: pendingFocusAnimated
            )
        }

        @discardableResult
        private func focusCamera(
            on placeId: String,
            in places: [SavedPlace],
            mapView: KakaoMap,
            animated: Bool
        ) -> Bool {
            guard let place = places.first(where: { $0.id == placeId }) else { return false }

            let coordinate = place.asPlace.coordinate
            let target = MapPoint(
                longitude: coordinate.longitude,
                latitude: coordinate.latitude
            )
            let cameraUpdate = CameraUpdate.make(
                target: target,
                zoomLevel: Constants.focusLevel,
                mapView: mapView
            )

            if animated {
                let options = CameraAnimationOptions(
                    autoElevation: true,
                    consecutive: false,
                    durationInMillis: Constants.focusAnimationMillis
                )
                mapView.animateCamera(cameraUpdate: cameraUpdate, options: options) { [weak self] in
                    self?.onFocusCompleted?(placeId)
                }
            } else {
                mapView.moveCamera(cameraUpdate)
            }

            return true
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

        // MARK: App lifecycle

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
            controller?.pauseEngine()
        }

        @objc private func handleDidBecomeActive() {
            activate()
        }
    }
}