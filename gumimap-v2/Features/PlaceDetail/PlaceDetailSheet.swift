import CoreLocation
import SwiftUI

struct PlaceDetailSheet: View {
    let place: Place
    let onDismiss: () -> Void

    @State private var viewModel = PlaceDetailViewModel()
    @State private var selectedListType: ListSubTab = .wishlist

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    nameSection
                        .padding(.bottom, 4)

                    addressSection
                        .padding(.bottom, 4)

                    openStatusSection
                        .padding(.bottom, 20)

                    mapPlaceholder
                        .padding(.bottom, 24)

                    listTypeSection

                    if viewModel.isLoadingEnrichment || !viewModel.enrichmentActivities.isEmpty {
                        enrichmentActivitySection
                            .padding(.top, 16)
                    }

                    enrichmentSection
                        .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", action: onDismiss)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
            .onAppear {
                viewModel.loadEnrichment(for: place)
            }
            .onDisappear {
                viewModel.reset()
            }
        }
    }

    private var nameSection: some View {
        Text(place.name)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addressSection: some View {
        Text(place.address)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var openStatusSection: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(openStatusDotColor)
                .frame(width: 6, height: 6)

            Text(openStatusLabel)
                .font(.subheadline)
                .foregroundStyle(openStatusLabelColor)

            if let detail = openStatusDetail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        .redacted(reason: viewModel.isLoadingEnrichment ? .placeholder : [])
        .animation(nil, value: viewModel.isLoadingEnrichment)
        .animation(nil, value: viewModel.enrichment?.isClosedToday)
    }

    private var openStatusDotColor: Color {
        if viewModel.isLoadingEnrichment {
            return Color.primary.opacity(0.15)
        }
        guard let status = viewModel.enrichment?.openStatus() else {
            return Color.primary.opacity(0.15)
        }
        return status.isPositive ? Color.green : Color.primary.opacity(0.25)
    }

    private var openStatusLabel: String {
        if viewModel.isLoadingEnrichment {
            return "영업시간 확인 중"
        }
        return viewModel.enrichment?.openStatus().label ?? "영업시간 정보 없음"
    }

    private var openStatusLabelColor: Color {
        if viewModel.isLoadingEnrichment {
            return .secondary
        }
        guard let status = viewModel.enrichment?.openStatus() else {
            return .secondary
        }
        return status.isPositive ? .primary : .secondary
    }

    private var openStatusDetail: String? {
        guard !viewModel.isLoadingEnrichment else { return nil }
        return viewModel.enrichment?.openStatus().detail
    }

    private var mapPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.tertiarySystemFill))
            .frame(height: 180)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "map")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("지도 미리보기")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.5f, %.5f", place.coordinate.latitude, place.coordinate.longitude))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
    }

    private var listTypeSection: some View {
        HStack(spacing: 20) {
            listTypeButton(.wishlist, title: "가고싶음")
            listTypeButton(.visited, title: "갔다옴")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    private var enrichmentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Grok 작업")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.enrichmentActivities) { activity in
                    enrichmentActivityRow(activity)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(enrichmentBackground)
        .animation(nil, value: viewModel.enrichmentActivities.count)
    }

    private func enrichmentActivityRow(_ activity: GrokEnrichmentActivity) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: activity.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(activity.isInProgress ? .primary : .secondary)
                .frame(width: 18, alignment: .center)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(activity.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if activity.isInProgress {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let detail = activity.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !activity.sources.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(activity.sources, id: \.self) { source in
                            Text(source)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color(.tertiarySystemFill))
                                )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var enrichmentSection: some View {
        if let errorMessage = viewModel.enrichmentErrorMessage, !viewModel.isLoadingEnrichment {
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(enrichmentBackground)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(enrichmentSummaryText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(enrichmentHighlightLines, id: \.self) { highlight in
                        Text(highlight)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(minHeight: enrichmentHighlightsMinHeight, alignment: .top)

                Text(enrichmentVisitTipText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(enrichmentBackground)
            .redacted(reason: viewModel.isLoadingEnrichment ? .placeholder : [])
            .animation(nil, value: viewModel.isLoadingEnrichment)
            .animation(nil, value: viewModel.enrichment?.summary)
        }
    }

    private var enrichmentSummaryText: String {
        if viewModel.isLoadingEnrichment {
            return "가나다라마바사아자차카타파하가나다라마바사아자차카타파하"
        }
        return viewModel.enrichment?.summary ?? ""
    }

    private var enrichmentHighlightLines: [String] {
        if viewModel.isLoadingEnrichment {
            return [
                "• 가나다라마바사아자차카타파하",
                "• 가나다라마바사아자차카타파하",
            ]
        }
        return viewModel.enrichment?.highlights.map { "• \($0)" } ?? []
    }

    private var enrichmentHighlightsMinHeight: CGFloat {
        let lineHeight: CGFloat = 20
        let lineCount = max(viewModel.isLoadingEnrichment ? 2 : enrichmentHighlightLines.count, 1)
        let spacing: CGFloat = 6
        return lineHeight * CGFloat(lineCount) + spacing * CGFloat(max(lineCount - 1, 0))
    }

    private var enrichmentVisitTipText: String {
        if viewModel.isLoadingEnrichment {
            return "가나다라마바사아자차카타파하가나다라마바사"
        }
        return viewModel.enrichment?.visitTip ?? ""
    }

    private var enrichmentBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    private func listTypeButton(_ listType: ListSubTab, title: String) -> some View {
        let isSelected = selectedListType == listType

        return Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedListType = listType
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.35))
                    .contentTransition(.identity)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .animation(nil, value: selectedListType)
        }
        .buttonStyle(.plain)
    }

    private let bottomButtonCornerRadius: CGFloat = 10
    private let bottomButtonHeight: CGFloat = 48
    private let primaryButtonFill = Color(.label)
    private let primaryButtonForeground = Color(.systemGroupedBackground)
    private let secondaryButtonFill = Color(.secondarySystemGroupedBackground)

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            Button {
                // TODO: Save place to selected list
                onDismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))

                    Text("추가하기")
                        .font(.body.weight(.medium))
                }
                .foregroundStyle(primaryButtonForeground)
                .frame(maxWidth: .infinity)
                .frame(height: bottomButtonHeight)
                .background(bottomButtonBackground(fill: primaryButtonFill))
            }
            .buttonStyle(.plain)

            if let kakaoMapURL = place.kakaoMapURL {
                Link(destination: kakaoMapURL) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: bottomButtonHeight, height: bottomButtonHeight)
                        .background(bottomButtonBackground(fill: secondaryButtonFill))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemGroupedBackground))
    }

    private func bottomButtonBackground(fill: Color) -> some View {
        RoundedRectangle(cornerRadius: bottomButtonCornerRadius, style: .continuous)
            .fill(fill)
            .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 3)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    PlaceDetailSheet(
        place: Place(
            id: "21160803",
            name: "스타벅스 구미시청DT점",
            address: "경북 구미시 송정동 33-11",
            category: "카페",
            phone: "054-123-4567",
            kakaoMapURL: URL(string: "http://place.map.kakao.com/21160803"),
            coordinate: .init(latitude: 36.1195, longitude: 128.3445)
        ),
        onDismiss: {}
    )
}