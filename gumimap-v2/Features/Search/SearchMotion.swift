import SwiftUI

enum SearchMotion {
    /// Backdrop fade — iOS system-like ease-out
    static let backdrop = Animation.timingCurve(0.33, 0, 0.2, 1, duration: 0.28)

    /// Search bar reveal — quick start, soft landing
    static let searchBar = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.4)

    /// Results panel — gentle ease without bounce
    static let results = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.32)

    /// Keyboard offset
    static let keyboard = Animation.timingCurve(0.33, 0, 0.2, 1, duration: 0.25)

    static let searchBarTravel: CGFloat = 32
    static let resultsTravel: CGFloat = 16
    static let dismissDelay: Duration = .milliseconds(300)
}