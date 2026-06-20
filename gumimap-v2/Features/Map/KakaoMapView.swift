import CoreLocation
import KakaoMapsSDK
import SwiftUI
import UIKit

struct KakaoMapView: UIViewRepresentable {
    var isActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
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
    final class Coordinator: NSObject, MapControllerDelegate {
        private enum Constants {
            static let mapViewName = "mapview"
            static let defaultLevel = 10
        }

        private weak var container: KMViewContainer?
        private var controller: KMController?
        private var didSetInitialCamera = false
        private var lastAppliedSize: CGSize = .zero
        private var observersInstalled = false

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
            guard let mapView = kakaoMap,
                  let size = container?.bounds.size,
                  size.width > 0, size.height > 0
            else { return }

            lastAppliedSize = size
            mapView.viewRect = CGRect(origin: .zero, size: size)
            setInitialCameraIfNeeded(on: mapView)
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