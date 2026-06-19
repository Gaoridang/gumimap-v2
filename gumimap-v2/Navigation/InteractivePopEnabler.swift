import SwiftUI
import UIKit

/// Re-enables edge swipe-back when the navigation bar or back button is hidden.
struct InteractivePopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        PopEnablerViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        (uiViewController as? PopEnablerViewController)?.enablePopGesture()
    }

    private final class PopEnablerViewController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enablePopGesture()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            enablePopGesture()
        }

        func enablePopGesture() {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

extension View {
    func enableInteractivePopGesture() -> some View {
        background(InteractivePopEnabler())
    }
}