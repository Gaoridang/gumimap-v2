import Foundation

enum BusinessHoursParser {
    private static let weekdayOrder = ["월", "화", "수", "목", "금", "토", "일"]
    private static let segmentPattern = /^(월|화|수|목|금|토|일)(?:요일)?\s+(.+)$/
    private static let timeRangePattern = /(\d{1,2}):(\d{2})\s*[–-]\s*(\d{1,2}):(\d{2})/

    static var koreaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    static func todayAbbreviation(for date: Date = .now, calendar: Calendar = koreaCalendar) -> String {
        let weekday = calendar.component(.weekday, from: date)
        let days = ["일", "월", "화", "수", "목", "금", "토"]
        return days[weekday - 1]
    }

    static func formatDisplay(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "정보 없음" else { return trimmed }

        let entries = parse(trimmed)
        guard !entries.isEmpty else { return trimmed }

        if entries.allSatisfy({ $0.hours == entries[0].hours }) {
            return "매일  \(formatHours(entries[0].hours))"
        }

        var lines: [String] = []
        var groupStart = 0

        for index in entries.indices {
            let isLast = index == entries.count - 1
            let continuesGroup = !isLast && entries[index].hours == entries[index + 1].hours
            guard isLast || !continuesGroup else { continue }

            let group = Array(entries[groupStart...index])
            let dayLabel = formatDayRange(group.map(\.day))
            lines.append("\(dayLabel)  \(formatHours(group[0].hours))")
            groupStart = index + 1
        }

        return lines.joined(separator: "\n")
    }

    static func isOpenNow(
        businessHours raw: String,
        breakTime: String? = nil,
        at date: Date = .now,
        calendar: Calendar = koreaCalendar
    ) -> Bool? {
        let trimmedHours = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHours.isEmpty, trimmedHours != "정보 없음" else { return nil }

        let entries = parse(trimmedHours)
        guard !entries.isEmpty else { return nil }

        let today = todayAbbreviation(for: date, calendar: calendar)
        guard let todayEntry = entries.first(where: { $0.day == today }) else { return nil }
        if isClosedDay(todayEntry.hours) { return false }

        guard let openFromHours = isTimeWithinHours(todayEntry.hours, at: date, calendar: calendar) else {
            return nil
        }
        guard openFromHours else { return false }

        if let breakTime,
           isInBreakTime(breakTime, at: date, calendar: calendar) {
            return false
        }

        return true
    }

    private static func isClosedDay(_ hours: String) -> Bool {
        let lowered = hours.lowercased()
        return lowered.contains("휴무") || lowered.contains("closed")
    }

    private static func formatDayRange(_ days: [String]) -> String {
        guard let first = days.first else { return "" }
        guard days.count > 1 else { return first }

        let indices = days.compactMap { weekdayOrder.firstIndex(of: $0) }
        let isConsecutive = indices.count == days.count
            && indices == Array(indices[0]...(indices[0] + days.count - 1))

        if isConsecutive, let last = days.last {
            return "\(first)–\(last)"
        }

        return days.joined(separator: ", ")
    }

    private static func formatHours(_ hours: String) -> String {
        if isClosedDay(hours) { return "휴무" }

        return hours.replacing(timeRangePattern) { match in
            let startHour = Int(match.1) ?? 0
            let startMinute = Int(match.2) ?? 0
            let endHour = Int(match.3) ?? 0
            let endMinute = Int(match.4) ?? 0
            return String(
                format: "%02d:%02d – %02d:%02d",
                startHour,
                startMinute,
                endHour,
                endMinute
            )
        }
    }

    private static func parse(_ raw: String) -> [(day: String, hours: String)] {
        let normalized = raw
            .replacingOccurrences(of: "\n", with: ", ")
            .replacingOccurrences(of: "，", with: ",")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return [] }

        return normalized
            .components(separatedBy: ",")
            .compactMap { segment -> (day: String, hours: String)? in
                let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let match = trimmed.firstMatch(of: segmentPattern) else { return nil }
                let day = String(match.1)
                let hours = String(match.2).trimmingCharacters(in: .whitespacesAndNewlines)
                return (day, hours)
            }
            .sorted { lhs, rhs in
                (weekdayOrder.firstIndex(of: lhs.day) ?? 99) < (weekdayOrder.firstIndex(of: rhs.day) ?? 99)
            }
    }

    private static func isInBreakTime(_ breakTime: String, at date: Date, calendar: Calendar) -> Bool {
        let trimmed = breakTime.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != "정보 없음",
              trimmed != "없음" else {
            return false
        }

        for match in trimmed.matches(of: timeRangePattern) {
            guard
                let startHour = Int(match.1),
                let startMinute = Int(match.2),
                let endHour = Int(match.3),
                let endMinute = Int(match.4),
                isTimeWithinRange(
                    hour: calendar.component(.hour, from: date),
                    minute: calendar.component(.minute, from: date),
                    startHour: startHour,
                    startMinute: startMinute,
                    endHour: endHour,
                    endMinute: endMinute
                )
            else { continue }
            return true
        }

        return false
    }

    private static func isTimeWithinHours(_ hours: String, at date: Date, calendar: Calendar) -> Bool? {
        var hasRange = false

        for match in hours.matches(of: timeRangePattern) {
            hasRange = true
            guard
                let openHour = Int(match.1),
                let openMinute = Int(match.2),
                let closeHour = Int(match.3),
                let closeMinute = Int(match.4),
                isTimeWithinRange(
                    hour: calendar.component(.hour, from: date),
                    minute: calendar.component(.minute, from: date),
                    startHour: openHour,
                    startMinute: openMinute,
                    endHour: closeHour,
                    endMinute: closeMinute
                )
            else { continue }
            return true
        }

        return hasRange ? false : nil
    }

    private static func isTimeWithinRange(
        hour: Int,
        minute: Int,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) -> Bool {
        let currentMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        if endMinutes > startMinutes {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }
        return currentMinutes >= startMinutes || currentMinutes < endMinutes
    }
}