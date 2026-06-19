import SwiftUI

enum SearchMotion {
    // macOS Spotlight: scale + fade with critically damped spring (no overshoot)

    static let searchBarIn = Animation.smooth(duration: 0.32, extraBounce: 0)
    static let searchBarOut = Animation.smooth(duration: 0.26, extraBounce: 0)

    static let resultsIn = Animation.smooth(duration: 0.28, extraBounce: 0)
    static let resultsOut = Animation.smooth(duration: 0.22, extraBounce: 0)

    static let keyboard = Animation.smooth(duration: 0.25, extraBounce: 0)

    /// Spotlight window scales from ~0.94 → 1.0
    static let searchBarScale: CGFloat = 0.94
    static let resultsScale: CGFloat = 0.97

    static let dismissDelay: Duration = .milliseconds(320)
}