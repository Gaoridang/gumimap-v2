import SwiftUI

enum PlaceCategoryIcon {
    static func symbol(for category: String) -> String {
        let normalized = category
            .replacingOccurrences(of: " ", with: "")
            .lowercased()

        if normalized.contains("카페") || normalized.contains("커피") || normalized.contains("디저트") {
            return "cup.and.saucer.fill"
        }
        if normalized.contains("술집") || normalized.contains("바") || normalized.contains("주점") {
            return "wineglass.fill"
        }
        if normalized.contains("베이커리") || normalized.contains("빵") {
            return "birthday.cake.fill"
        }
        if normalized.contains("마트") || normalized.contains("편의점") || normalized.contains("쇼핑") {
            return "bag.fill"
        }
        if normalized.contains("병원") || normalized.contains("약국") || normalized.contains("의료") {
            return "cross.case.fill"
        }
        if normalized.contains("공원") || normalized.contains("산") || normalized.contains("자연") {
            return "leaf.fill"
        }
        if normalized.contains("문화") || normalized.contains("전시") || normalized.contains("박물관") {
            return "building.columns.fill"
        }
        if normalized.contains("음식") || normalized.contains("식당") || normalized.contains("한식")
            || normalized.contains("중식") || normalized.contains("일식") || normalized.contains("양식")
            || normalized.contains("분식") || normalized.contains("치킨") || normalized.contains("피자") {
            return "fork.knife"
        }

        return "mappin.and.ellipse"
    }

    static func tint(for category: String) -> Color {
        let normalized = category
            .replacingOccurrences(of: " ", with: "")
            .lowercased()

        if normalized.contains("카페") || normalized.contains("커피") || normalized.contains("디저트") {
            return .brown
        }
        if normalized.contains("술집") || normalized.contains("바") || normalized.contains("주점") {
            return .purple
        }
        if normalized.contains("베이커리") || normalized.contains("빵") {
            return .orange
        }
        if normalized.contains("마트") || normalized.contains("편의점") || normalized.contains("쇼핑") {
            return .blue
        }
        if normalized.contains("병원") || normalized.contains("약국") || normalized.contains("의료") {
            return .red
        }
        if normalized.contains("공원") || normalized.contains("산") || normalized.contains("자연") {
            return .green
        }
        if normalized.contains("문화") || normalized.contains("전시") || normalized.contains("박물관") {
            return .indigo
        }
        if normalized.contains("음식") || normalized.contains("식당") || normalized.contains("한식")
            || normalized.contains("중식") || normalized.contains("일식") || normalized.contains("양식")
            || normalized.contains("분식") || normalized.contains("치킨") || normalized.contains("피자") {
            return .pink
        }

        return .secondary
    }
}