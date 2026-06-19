import CoreLocation
import Foundation

struct Place: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let category: String
    let phone: String?
    let kakaoMapURL: URL?
    let coordinate: CLLocationCoordinate2D

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.id == rhs.id
    }

    var phoneURL: URL? {
        guard let phone, !phone.isEmpty else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:\(digits)")
    }
}