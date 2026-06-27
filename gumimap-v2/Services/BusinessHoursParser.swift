import Foundation

enum BusinessHoursParser {
    private static let weekdayOrder = ["월", "화", "수", "목", "금", "토", "일"]
    private static let weekdaySet = Set(weekdayOrder)
    private static let timeRangePattern = /(\d{1,2}):(\d{2})\s*[~–\-]\s*(\d{1,2}):(\d{2})/
    private static let segmentDelimiterPattern =
        /,(?=\s*(?:매일|평일|주말)\s+\d|(?:월|화|수|목|금|토|일)(?:요일)?\s*(?:[~–\-]|\d))/

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

        let segments = splitSegments(normalized)
        var entries: [(day: String, hours: String)] = []

        for segment in segments {
            entries.append(contentsOf: parseSegment(segment))
        }

        return entries.sorted { lhs, rhs in
            (weekdayOrder.firstIndex(of: lhs.day) ?? 99) < (weekdayOrder.firstIndex(of: rhs.day) ?? 99)
        }
    }

    private static func splitSegments(_ raw: String) -> [String] {
        raw
            .split(separator: segmentDelimiterPattern, omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func parseSegment(_ segment: String) -> [(day: String, hours: String)] {
        let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let match = trimmed.firstMatch(of: timeRangePattern) else { return [] }

        let hours = String(trimmed[match.range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let dayPart = String(trimmed[..<match.range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let days = extractDays(from: dayPart.isEmpty ? "매일" : dayPart)
        guard !days.isEmpty else { return [] }
        return days.map { ($0, hours) }
    }

    private static func extractDays(from dayPart: String) -> [String] {
        let normalized = dayPart
            .replacingOccurrences(of: "요일", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return [] }

        if normalized.contains("매일") {
            return weekdayOrder
        }

        if normalized.contains("평일") {
            return ["월", "화", "수", "목", "금"]
        }

        if normalized.contains("주말") {
            return ["토", "일"]
        }

        if let rangeMatch = normalized.firstMatch(of: /^(월|화|수|목|금|토|일)[~–\-](월|화|수|목|금|토|일)$/) {
            return expandDayRange(
                start: String(rangeMatch.1),
                end: String(rangeMatch.2)
            )
        }

        var days: [String] = []
        var index = normalized.startIndex

        while index < normalized.endIndex {
            let character = String(normalized[index])
            if weekdaySet.contains(character), !days.contains(character) {
                days.append(character)
            }
            index = normalized.index(after: index)
        }

        return days.sorted {
            (weekdayOrder.firstIndex(of: $0) ?? 99) < (weekdayOrder.firstIndex(of: $1) ?? 99)
        }
    }

    private static func expandDayRange(start: String, end: String) -> [String] {
        guard
            let startIndex = weekdayOrder.firstIndex(of: start),
            let endIndex = weekdayOrder.firstIndex(of: end)
        else {
            return []
        }

        if startIndex <= endIndex {
            return Array(weekdayOrder[startIndex...endIndex])
        }

        return Array(weekdayOrder[startIndex...]) + Array(weekdayOrder[0...endIndex])
    }
}