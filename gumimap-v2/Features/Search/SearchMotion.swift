import SwiftUI

enum SearchMotion {
    /// Matches FloatingToolbar spring
    static let searchBarIn = Animation.spring(response: 0.38, dampingFraction: 0.78)

    static let searchBarOut = Animation.spring(response: 0.34, dampingFraction: 0.86)

    static let resultsIn = Animation.spring(response: 0.34, dampingFraction: 0.82)

    static let resultsOut = Animation.spring(response: 0.3, dampingFraction: 0.88)

    static let keyboard = Animation.spring(response: 0.35, dampingFraction: 0.86)

    static let searchBarTravel: CGFloat = 24
    static let resultsTravel: CGFloat = 12

    /// Buffer beyond spring settle for searchBarOut
    static let dismissDelay: Duration = .milliseconds(420)
}