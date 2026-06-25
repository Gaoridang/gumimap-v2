import CoreLocation
import KakaoMapsSDK
import SwiftUI
import UIKit

struct PlaceDetailMapPreview: View {
    let coordinate: CLLocationCoordinate2D
    let listKind: ListSubTab
    let category: String
    let isActive: Bool
    var onTap: (() -> Void)?

    private static let height: CGFloat = 180

    var body: some View {
        Group {
            if Self.isValidCoordinate(coordinate), Secrets.isKakaoMapConfigured {
                previewContent
            }
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        let map = PlaceDetailKakaoMapPreview(
            coordinate: coordinate,
            listKind: listKind,
            category: category,
            isActive: isActive
        )
        .frame(height: Self.height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("장소 위치 미리보기")
        .accessibilityHint(onTap == nil ? "" : "탭하면 지도에서 열어요")

        if let onTap {
            Button(action: onTap) {
                map
            }
            .buttonStyle(.plain)
        } else {
            map
        }
    }

    static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard abs(coordinate.latitude) <= 90, abs(coordinate.longitude) <= 180 else {
            return false
        }
        return coordinate.latitude != 0 || coordinate.longitude != 0
    }
}

// MARK: - Kakao map embed

private struct PlaceDetailKakaoMapPreview: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let listKind: ListSubTab
    let category: String
    let isActive: Bool

    private static let mapViewName = "detail-preview-map"
    private static let layerID = "detail-preview-pin"
    private static let poiID = "detail-preview-poi"
    private static let zoomLevel = 16

    func makeCoordinator() -> Coordinator {
        Coordinator(
            coordinate: coordinate,
            listKind: listKind,
            category: category
        )
    }

    func makeUIView(context: Context) -> KMViewContainer {
        let container = KMViewContainer()
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.clipsToBounds = true
        container.isUserInteractionEnabled = false
        context.coordinator.start(in: container)
        return container
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        let size = uiView.bounds.size
        if size.width > 0, size.height > 0 {
            context.coordinator.handleResize(size)
        }

        context.coordinator.updatePlace(
            coordinate: coordinate,
            listKind: listKind,
            category: category
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

private extension PlaceDetailKakaoMapPreview {
    final class Coordinator: NSObject, MapControllerDelegate {
        private var coordinate: CLLocationCoordinate2D
        private var listKind: ListSubTab
        private var category: String

        private weak var container: KMViewContainer?
        private var controller: KMController?
        private var isMapReady = false
        private var lastAppliedSize: CGSize = .zero
        private var pendingCoordinate: CLLocationCoordinate2D?
        private var pendingListKind: ListSubTab?
        private var pendingCategory: String?
        private var registeredStyleID: String?

        init(coordinate: CLLocationCoordinate2D, listKind: ListSubTab, category: String) {
            self.coordinate = coordinate
            self.listKind = listKind
            self.category = category
            super.init()
        }

        func start(in container: KMViewContainer) {
            guard controller == nil else { return }

            self.container = container
            let controller = KMController(viewContainer: container)
            controller.delegate = self
            self.controller = controller
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
            controller?.pauseEngine()
        }

        func updatePlace(
            coordinate: CLLocationCoordinate2D,
            listKind: ListSubTab,
            category: String
        ) {
            let styleChanged = self.listKind != listKind || self.category != category
            let coordinateChanged = self.coordinate.latitude != coordinate.latitude
                || self.coordinate.longitude != coordinate.longitude

            guard styleChanged || coordinateChanged else { return }

            self.coordinate = coordinate
            self.listKind = listKind
            self.category = category
            pendingCoordinate = coordinate
            pendingListKind = listKind
            pendingCategory = category
            registeredStyleID = nil
            syncMapIfReady()
        }

        func handleResize(_ size: CGSize) {
            guard size.width > 0, size.height > 0 else { return }
            guard let mapView = kakaoMap else { return }
            guard size != lastAppliedSize else { return }

            lastAppliedSize = size
            mapView.viewRect = CGRect(origin: .zero, size: size)
            syncMapIfReady()
        }

        // MARK: MapControllerDelegate

        func addViews() {
            let target = MapPoint(
                longitude: coordinate.longitude,
                latitude: coordinate.latitude
            )
            let mapviewInfo = MapviewInfo(
                viewName: PlaceDetailKakaoMapPreview.mapViewName,
                viewInfoName: "map",
                defaultPosition: target,
                defaultLevel: PlaceDetailKakaoMapPreview.zoomLevel
            )
            controller?.addView(mapviewInfo)
        }

        func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            guard viewName == PlaceDetailKakaoMapPreview.mapViewName else { return }

            isMapReady = true

            if let mapView = kakaoMap,
               let size = container?.bounds.size,
               size.width > 0, size.height > 0 {
                lastAppliedSize = size
                mapView.viewRect = CGRect(origin: .zero, size: size)
            }

            syncMapIfReady()
        }

        func addViewFailed(_ viewName: String, viewInfoName: String) {
            print("Place detail map preview failed: \(viewName) / \(viewInfoName)")
        }

        func containerDidResized(_ size: CGSize) {
            handleResize(size)
        }

        func authenticationFailed(_ errorCode: Int, desc: String) {
            print("Place detail map preview auth failed (\(errorCode)): \(desc)")
        }

        // MARK: Private

        private var kakaoMap: KakaoMap? {
            controller?.getView(PlaceDetailKakaoMapPreview.mapViewName) as? KakaoMap
        }

        private func syncMapIfReady() {
            guard isMapReady, let mapView = kakaoMap else { return }

            let activeCoordinate = pendingCoordinate ?? coordinate
            let activeListKind = pendingListKind ?? listKind
            let activeCategory = pendingCategory ?? category

            moveCamera(to: activeCoordinate, on: mapView)
            syncPin(
                coordinate: activeCoordinate,
                listKind: activeListKind,
                category: activeCategory,
                on: mapView
            )

            pendingCoordinate = nil
            pendingListKind = nil
            pendingCategory = nil
        }

        private func moveCamera(to coordinate: CLLocationCoordinate2D, on mapView: KakaoMap) {
            let target = MapPoint(
                longitude: coordinate.longitude,
                latitude: coordinate.latitude
            )
            let cameraUpdate = CameraUpdate.make(
                target: target,
                zoomLevel: PlaceDetailKakaoMapPreview.zoomLevel,
                mapView: mapView
            )
            mapView.moveCamera(cameraUpdate)
        }

        private func syncPin(
            coordinate: CLLocationCoordinate2D,
            listKind: ListSubTab,
            category: String,
            on mapView: KakaoMap
        ) {
            let manager = mapView.getLabelManager()
            let layerID = PlaceDetailKakaoMapPreview.layerID
            let poiID = PlaceDetailKakaoMapPreview.poiID

            if manager.getLabelLayer(layerID: layerID) == nil {
                let layerOption = LabelLayerOptions(
                    layerID: layerID,
                    competitionType: .none,
                    competitionUnit: .symbolFirst,
                    orderType: .rank,
                    zOrder: 1000
                )
                _ = manager.addLabelLayer(option: layerOption)
            }

            guard let layer = manager.getLabelLayer(layerID: layerID) else { return }

            layer.removePoi(poiID: poiID)

            let styleID = KakaoMapPinImageRenderer.styleID(
                listKind: listKind,
                category: category
            )

            if registeredStyleID != styleID {
                let image = KakaoMapPinImageRenderer.image(
                    listKind: listKind,
                    category: category
                )
                let iconStyle = PoiIconStyle(
                    symbol: image,
                    anchorPoint: CGPoint(x: 0.5, y: 1.0)
                )
                let perLevelStyle = PerLevelPoiStyle(iconStyle: iconStyle, level: 0)
                let poiStyle = PoiStyle(styleID: styleID, styles: [perLevelStyle])
                manager.addPoiStyle(poiStyle)
                registeredStyleID = styleID
            }

            let position = MapPoint(
                longitude: coordinate.longitude,
                latitude: coordinate.latitude
            )
            let options = PoiOptions(styleID: styleID, poiID: poiID)
            options.rank = 0
            options.clickable = false

            guard let poi = layer.addPoi(option: options, at: position) else { return }
            poi.show()
        }
    }
}