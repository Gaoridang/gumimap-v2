import CoreLocation
import Foundation

enum KakaoLocalError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Kakao REST API 키가 설정되지 않았습니다."
        case .invalidResponse:
            "검색 응답을 처리할 수 없습니다."
        case .httpStatus(let code):
            "검색 요청에 실패했습니다. (HTTP \(code))"
        }
    }
}

struct KakaoLocalService: Sendable {
    private let session: URLSession
    private let apiKey: String

    init(session: URLSession = .shared, apiKey: String = Secrets.kakaoRestAPIKey) {
        self.session = session
        self.apiKey = apiKey
    }

    func search(keyword: String, page: Int = 1, size: Int = 15) async throws -> [Place] {
        guard !apiKey.isEmpty else {
            throw KakaoLocalError.missingAPIKey
        }

        var components = URLComponents(string: "https://dapi.kakao.com/v2/local/search/keyword.json")
        components?.queryItems = [
            URLQueryItem(name: "query", value: keyword),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size)),
        ]

        guard let url = components?.url else {
            throw KakaoLocalError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KakaoLocalError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw KakaoLocalError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(KakaoKeywordSearchResponse.self, from: data)
        return decoded.documents.map(\.place)
    }
}

private struct KakaoKeywordSearchResponse: Decodable {
    let documents: [KakaoPlaceDocument]
}

private struct KakaoPlaceDocument: Decodable {
    let id: String
    let placeName: String
    let addressName: String
    let roadAddressName: String
    let categoryGroupName: String
    let x: String
    let y: String

    enum CodingKeys: String, CodingKey {
        case id
        case placeName = "place_name"
        case addressName = "address_name"
        case roadAddressName = "road_address_name"
        case categoryGroupName = "category_group_name"
        case x, y
    }

    var place: Place {
        let address = roadAddressName.isEmpty ? addressName : roadAddressName
        let longitude = Double(x) ?? 0
        let latitude = Double(y) ?? 0

        return Place(
            id: id,
            name: placeName,
            address: address,
            category: categoryGroupName,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        )
    }
}