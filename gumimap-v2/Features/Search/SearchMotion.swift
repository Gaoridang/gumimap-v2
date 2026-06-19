import SwiftUI

enum SearchMotion {
    // MARK: - Insertion (ease-out)

    static let searchBarIn = Animation.timingCurve(0, 0, 0.58, 1, duration: 0.35)

    static let resultsIn = Animation.timingCurve(0, 0, 0.58, 1, duration: 0.28)

    // MARK: - Removal (ease-in)

    static let searchBarOut = Animation.timingCurve(0.42, 0, 1, 1, duration: 0.32)

    static let resultsOut = Animation.timingCurve(0.42, 0, 1, 1, duration: 0.24)

    static let keyboard = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.25)

    static let searchBarTravel: CGFloat = 24
    static let resultsTravel: CGFloat = 12

    static let dismissDelay: Duration = .milliseconds(360)
}