import SwiftUI

enum SearchMotion {
    // MARK: - Insertion (ease-out)

    /// Backdrop fade in — iOS standard ease-in-out
    static let backdropIn = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.32)

    /// Search bar slide up — decelerate into place, 50ms after backdrop
    static let searchBarIn = Animation.timingCurve(0, 0, 0.58, 1, duration: 0.35).delay(0.05)

    /// Results panel reveal
    static let resultsIn = Animation.timingCurve(0, 0, 0.58, 1, duration: 0.28)

    // MARK: - Removal (ease-in)

    static let backdropOut = Animation.timingCurve(0.42, 0, 0.58, 1, duration: 0.28)

    static let searchBarOut = Animation.timingCurve(0.42, 0, 1, 1, duration: 0.32)

    static let resultsOut = Animation.timingCurve(0.42, 0, 1, 1, duration: 0.24)

    /// Keyboard offset — symmetric, matches UIKeyboard
    static let keyboard = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.25)

    static let searchBarTravel: CGFloat = 24
    static let resultsTravel: CGFloat = 12

    /// Must exceed longest removal animation (searchBarOut 320ms) + frame buffer
    static let dismissDelay: Duration = .milliseconds(360)
}