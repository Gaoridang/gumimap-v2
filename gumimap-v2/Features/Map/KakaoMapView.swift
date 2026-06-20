import KakaoMapsSDK
import SwiftUI
import UIKit

struct KakaoMapView: UIViewRepresentable {
    let isActive: Bool
    let availableSize: CGSize
    let places: [SavedPlace]
    let runtimeState: KakaoMapRuntimeState
    let onPinTap: (String) -> Void

    func makeCoordinator() -> KakaoMapCoordinator {
        KakaoMapCoordinator(runtimeState: runtimeState, onPinTap: onPinTap)
    }

    func makeUIView(context: Context) -> KMViewContainer {
        let container = KMViewContainer(frame: CGRect(origin: .zero, size: availableSize))
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.clipsToBounds = true
        container.backgroundColor = UIColor.secondarySystemBackground
        context.coordinator.attach(to: container)
        return container
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        let layoutSize = resolvedLayoutSize(for: uiView)
        uiView.layoutIfNeeded()
        context.coordinator.handleContainerResize(layoutSize)
        context.coordinator.updatePlaces(places)

        if isActive {
            context.coordinator.activateIfNeeded()
        } else {
            context.coordinator.pause()
        }

        context.coordinator.refreshDebug(isMapTabActive: isActive)
    }

    private func resolvedLayoutSize(for uiView: KMViewContainer) -> CGSize {
        let boundsSize = uiView.bounds.size
        if boundsSize.width > 0, boundsSize.height > 0 {
            return boundsSize
        }
        if availableSize.width > 0, availableSize.height > 0 {
            return availableSize
        }
        return boundsSize
    }

    static func dismantleUIView(_ uiView: KMViewContainer, coordinator: KakaoMapCoordinator) {
        coordinator.tearDown()
    }
}