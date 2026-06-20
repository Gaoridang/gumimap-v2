import SwiftData
import SwiftUI

struct ListTabView: View {
    let subTab: ListSubTab

    @Query(sort: \SavedPlace.registeredAt, order: .reverse) private var savedPlaces: [SavedPlace]
    @State private var cardStyle: SavedPlaceCardStyle = .text

    private var places: [SavedPlace] {
        savedPlaces.filter { $0.listKind == subTab.rawValue }
    }

    var body: some View {
        Group {
            if places.isEmpty {
                demoComparison
            } else {
                savedListContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.2), value: subTab)
        .animation(.easeInOut(duration: 0.2), value: places.count)
        .animation(.easeInOut(duration: 0.2), value: cardStyle)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(subTab.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("아직 저장한 곳이 없어요")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    private var demoComparison: some View {
        ScrollView {
            VStack(spacing: 20) {
                emptyState
                    .padding(.top, 24)

                demoBanner

                demoSection(title: "A · 텍스트 카드", style: .text)
                demoSection(title: "B · 아이콘 카드", style: .icon)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private var savedListContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                stylePicker

                LazyVStack(spacing: 10) {
                    ForEach(places, id: \.id) { savedPlace in
                        NavigationLink(value: AppRoute.savedPlaceDetail(id: savedPlace.id)) {
                            SavedPlaceCard(content: savedPlace.cardContent, style: cardStyle)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private var demoBanner: some View {
        Text("저장한 장소가 없어서 샘플 카드로 비교해요")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var stylePicker: some View {
        Picker("카드 스타일", selection: $cardStyle) {
            ForEach(SavedPlaceCardStyle.allCases) { style in
                Text(style.title).tag(style)
            }
        }
        .pickerStyle(.segmented)
    }

    private func demoSection(title: String, style: SavedPlaceCardStyle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            ForEach(Array(SavedPlaceCardContent.demoSamples.enumerated()), id: \.offset) { _, sample in
                SavedPlaceCard(content: sample, style: style)
            }
        }
    }
}

#Preview("Empty · Demo") {
    ListTabView(subTab: .visited)
}