import Foundation

struct PlaceEnrichment: Decodable, Equatable {
    let summary: String
    let highlights: [String]
    let visitTip: String
    let isClosedToday: Bool
    let todayOpen: String?
    let todayClose: String?

    enum CodingKeys: String, CodingKey {
        case summary
        case highlights
        case visitTip = "visit_tip"
        case isClosedToday = "is_closed_today"
        case todayOpen = "today_open"
        case todayClose = "today_close"
    }

    init(
        summary: String,
        highlights: [String],
        visitTip: String,
        isClosedToday: Bool = false,
        todayOpen: String? = nil,
        todayClose: String? = nil
    ) {
        self.summary = summary
        self.highlights = highlights
        self.visitTip = visitTip
        self.isClosedToday = isClosedToday
        self.todayOpen = todayOpen
        self.todayClose = todayClose
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        highlights = try container.decode([String].self, forKey: .highlights)
        visitTip = try container.decode(String.self, forKey: .visitTip)
        isClosedToday = try container.decodeIfPresent(Bool.self, forKey: .isClosedToday) ?? false
        todayOpen = try container.decodeIfPresent(String.self, forKey: .todayOpen)
        todayClose = try container.decodeIfPresent(String.self, forKey: .todayClose)
    }

    func openStatus(at date: Date = .now, timeZone: TimeZone = .koreaStandard) -> PlaceOpenStatus {
        if isClosedToday {
            return .closedToday
        }

        guard let openMinutes = Self.minutes(from: todayOpen),
              let closeMinutes = Self.minutes(from: todayClose) else {
            return .unknown
        }

        let calendar = Calendar.gregorianKST
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else {
            return .unknown
        }

        let nowMinutes = hour * 60 + minute
        let isOpen: Bool

        if closeMinutes > openMinutes {
            isOpen = nowMinutes >= openMinutes && nowMinutes < closeMinutes
        } else {
            isOpen = nowMinutes >= openMinutes || nowMinutes < closeMinutes
        }

        let hoursText = "\(todayOpen ?? "")~\(todayClose ?? "")"
        return isOpen ? .open(hoursText: hoursText) : .closed(hoursText: hoursText)
    }

    private static func minutes(from time: String?) -> Int? {
        guard let time, !time.isEmpty else { return nil }

        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        return hour * 60 + minute
    }
}

enum PlaceOpenStatus: Equatable {
    case open(hoursText: String)
    case closed(hoursText: String)
    case closedToday
    case unknown

    var label: String {
        switch self {
        case .open: "영업중"
        case .closed: "영업 종료"
        case .closedToday: "휴무"
        case .unknown: "영업시간 정보 없음"
        }
    }

    var detail: String? {
        switch self {
        case .open(let hoursText), .closed(let hoursText):
            hoursText
        case .closedToday, .unknown:
            nil
        }
    }

    var isPositive: Bool {
        if case .open = self { return true }
        return false
    }
}

private extension TimeZone {
    static let koreaStandard = TimeZone(identifier: "Asia/Seoul")!
}

private extension Calendar {
    static var gregorianKST: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .koreaStandard
        return calendar
    }
}