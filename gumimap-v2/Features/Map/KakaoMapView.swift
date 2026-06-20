import CoreLocation
import KakaoMapsSDK
import SwiftUI
import UIKit

struct KakaoMapView: UIViewRepresentable {
    let isActive: Bool
    let places: [SavedPlace]
    let onPinTap: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPinTap: onPinTap)
    }

    func makeUIView(context: Context) -> KMViewContainer {
        let container = KMViewContainer()
        container.sizeToFit()
        context.coordinator.attach(to: container)
        return container
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        context.coordinator.updatePlaces(places)

        if isActive {
            context.coordinator.activateIfNeeded()
        } else {
            context.coordinator.pause()
        }
    }

    final class Coordinator: NSObject, MapControllerDelegate, KakaoMapEventDelegate {
        private enum Constants {
            static let mapViewName = "gumimap-main"
            static let layerID = "saved-places"
            static let defaultLevel: Int = 10
        }

        private let onPinTap: (String) -> Void
        private weak var mapController: KMController?
        private var isMapReady = false
        private var didSetInitialCamera = false
        private var pendingPlaces: [SavedPlace] = []
        private var displayedPlaceIDs: Set<String> = []
        private var registeredStyleIDs: Set<String> = []

        init(onPinTap: @escaping (String) -> Void) {
            self.onPinTap = onPinTap
            super.init()
        }

        func attach(to container: KMViewContainer) {
            guard mapController == nil else { return }

            let controller = KMController(viewContainer: container)
            controller.delegate = self
            mapController = controller
            controller.prepareEngine()
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

        // MARK: - MapControllerDelegate

        func authenticationSucceeded() {
            activateIfNeeded()
        }

        func authenticationFailed(_ errorCode: Int, desc: String) {
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
            mapController?.addView(mapviewInfo)
        }

        func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            guard viewName == Constants.mapViewName else { return }
            kakaoMap?.eventDelegate = self
            setupLabelLayer()
            isMapReady = true
            syncPinsIfReady()
        }

        func addViewFailed(_ viewName: String, viewInfoName: String) {
            print("Kakao Maps addView failed: \(viewName) / \(viewInfoName)")
        }

        func containerDidResized(_ size: CGSize) {
            guard let mapView = kakaoMap else { return }
            mapView.viewRect = CGRect(origin: .zero, size: size)

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
    }
}