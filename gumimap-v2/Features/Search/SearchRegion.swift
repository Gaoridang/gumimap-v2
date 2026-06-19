import CoreLocation
import Foundation

enum SearchRegion {
    /// 구미시 중심 좌표 (시청 인근)
    static let gumiCenter = CLLocationCoordinate2D(latitude: 36.1195, longitude: 128.3445)

    /// 구미시 전역을 커버하는 반경 (미터, Kakao API 최대 20,000)
    static let gumiRadiusMeters = 20_000

    static func isInGumi(address: String) -> Bool {
        address.contains("구미")
    }
}