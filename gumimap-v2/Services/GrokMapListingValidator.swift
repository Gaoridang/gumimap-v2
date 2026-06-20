import Foundation

enum GrokMapListingValidator {
    static func kakaoPlaceID(from url: URL?) -> String? {
        guard let url else { return nil }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.isEmpty, path.allSatisfy(\.isNumber) else { return nil }
        return path
    }

    static func validateResolution(_ resolved: GrokMapResolveResponse, for place: Place) -> Bool {
        guard resolved.confidence == "high" else { return false }
        guard URL(string: resolved.sourceURL) != nil else { return false }
        return placesMatch(
            pageName: resolved.pageName,
            pageAddress: resolved.pageAddress,
            place: place
        )
    }

    static func validateExtraction(
        _ response: GrokMapListingExtractionResponse,
        expectedSourceURL: String,
        place: Place
    ) -> Bool {
        guard urlsMatch(response.sourceURL, expected: expectedSourceURL, place: place) else {
            return false
        }

        let listing = response.listing
        return listing.features.hasAnyContent || PlaceFeatures.hasContent(listing.businessHours)
    }

    static func placesMatch(pageName: String, pageAddress: String, place: Place) -> Bool {
        let expectedNameTokens = significantTokens(from: place.name)
        let pageNameTokens = significantTokens(from: pageName)
        guard !expectedNameTokens.isEmpty, !pageNameTokens.isEmpty else { return false }

        let sharedNameTokens = expectedNameTokens.filter { pageNameTokens.contains($0) }
        let nameMatches = sharedNameTokens.count >= max(1, expectedNameTokens.count / 2)

        let addressTokens = addressKeywords(from: place.address)
        let addressMatches = addressTokens.contains { keyword in
            pageAddress.localizedCaseInsensitiveContains(keyword)
        }

        return nameMatches && addressMatches
    }

    private static func urlsMatch(_ actual: String, expected: String, place: Place) -> Bool {
        let normalizedActual = actual.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = expected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedActual.isEmpty, !normalizedExpected.isEmpty else { return false }

        if let expectedID = kakaoPlaceID(from: URL(string: normalizedExpected)) {
            return normalizedActual.contains(expectedID)
        }

        return normalizedActual == normalizedExpected
            || normalizedActual.localizedCaseInsensitiveContains(normalizedExpected)
            || normalizedExpected.localizedCaseInsensitiveContains(normalizedActual)
    }

    private static func significantTokens(from text: String) -> Set<String> {
        Set(
            text
                .replacingOccurrences(of: #"[^\p{L}\p{N}]"#, with: " ", options: .regularExpression)
                .split(separator: " ")
                .map { $0.lowercased() }
                .filter { $0.count >= 2 && !ignoredNameTokens.contains($0) }
        )
    }

    private static func addressKeywords(from address: String) -> [String] {
        address
            .replacingOccurrences(of: #"[^\p{L}\p{N}]"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                token.count >= 2
                    && !ignoredAddressTokens.contains(token)
                    && (token.hasSuffix("로") || token.hasSuffix("길") || token.hasSuffix("동") || token.contains("구미"))
            }
    }

    private static let ignoredNameTokens: Set<String> = [
        "구미", "경북", "점", "지점", "본점", "카페", "식당", "맛집"
    ]

    private static let ignoredAddressTokens: Set<String> = [
        "경상북도", "경북", "구미시", "대한민국"
    ]
}