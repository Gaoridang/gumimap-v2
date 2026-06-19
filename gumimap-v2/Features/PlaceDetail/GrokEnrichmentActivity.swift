import Foundation

enum GrokEnrichmentPhaseKind: Equatable, Sendable {
    case preparing
    case analyzing
    case webSearch
    case pageReview
    case composing
}

enum GrokEnrichmentPhaseStatus: Equatable, Sendable {
    case inProgress
    case completed
}

struct GrokEnrichmentPhase: Identifiable, Equatable, Sendable {
    let id: String
    let kind: GrokEnrichmentPhaseKind
    let status: GrokEnrichmentPhaseStatus
    let detail: String?
    let resultCount: Int
    let sourceHosts: [String]

    var title: String {
        switch (kind, status) {
        case (.preparing, .inProgress): "검색 준비 중"
        case (.preparing, .completed): "검색 준비 완료"
        case (.analyzing, .inProgress): "질문 분석 중"
        case (.analyzing, .completed): "질문 분석 완료"
        case (.webSearch, .inProgress): "웹 검색 중"
        case (.webSearch, .completed): "웹 검색 완료"
        case (.pageReview, .inProgress): "장소 정보 확인 중"
        case (.pageReview, .completed): "장소 정보 확인 완료"
        case (.composing, .inProgress): "장소 정보 정리 중"
        case (.composing, .completed): "장소 정보 정리 완료"
        }
    }

    var resultLabel: String? {
        guard kind == .webSearch, resultCount > 0 else { return nil }
        return "\(resultCount)개 결과"
    }

    var symbolName: String {
        switch kind {
        case .preparing: "arrow.triangle.2.circlepath"
        case .analyzing: "brain.head.profile"
        case .webSearch: "magnifyingglass"
        case .pageReview: "doc.text.magnifyingglass"
        case .composing: "text.alignleft"
        }
    }
}