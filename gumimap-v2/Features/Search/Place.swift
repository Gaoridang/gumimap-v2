import CoreLocation
import Foundation

struct Place: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let category: String
    let coordinate: CLLocationCoordinate2D

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.id == rhs.id
    }
}