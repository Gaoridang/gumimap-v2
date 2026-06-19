import Foundation

struct MockPlace: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let category: String

    static let samples: [MockPlace] = [
        MockPlace(id: "1", name: "을지로3가", address: "서울 중구 을지로3가", category: "역"),
        MockPlace(id: "2", name: "성수동 카페거리", address: "서울 성동구 성수동2가", category: "거리"),
        MockPlace(id: "3", name: "한강공원 여의도", address: "서울 영등포구 여의도동", category: "공원"),
        MockPlace(id: "4", name: "경복궁", address: "서울 종로구 사직로 161", category: "관광"),
        MockPlace(id: "5", name: "홍대입구", address: "서울 마포구 양화로", category: "역"),
        MockPlace(id: "6", name: "이태원", address: "서울 용산구 이태원로", category: "거리"),
        MockPlace(id: "7", name: "남산타워", address: "서울 용산구 남산공원길 105", category: "관광"),
        MockPlace(id: "8", name: "강남역", address: "서울 강남구 강남대로", category: "역"),
        MockPlace(id: "9", name: "북촌 한옥마을", address: "서울 종로구 계동길", category: "마을"),
        MockPlace(id: "10", name: "광장시장", address: "서울 종로구 창경궁로 88", category: "시장"),
    ]
}