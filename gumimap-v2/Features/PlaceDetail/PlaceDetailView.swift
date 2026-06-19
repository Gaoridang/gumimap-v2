import CoreLocation
import SwiftUI

struct PlaceDetailView: View {
    @State private var viewModel: PlaceDetailViewModel
    @State private var isJSONExpanded = false
    @Environment(\.dismiss) private var dismiss

    init(place: Place) {
        _viewModel = State(initialValue: PlaceDetailViewModel(place: place))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                kakaoBaselineSection

                if viewModel.showProgress {
                    progressSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                enrichmentSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .enableInteractivePopGesture()
        .animation(.snappy, value: viewModel.isLoading)
        .animation(.snappy, value: viewModel.progressLog.count)
        .animation(.snappy, value: viewModel.revealStep)
        .onAppear { viewModel.loadIfNeeded() }
        .onDisappear { viewModel.cancelTasks() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    ToolbarIcon(asset: .back, isSelected: true, size: 20)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Text(viewModel.place.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Text(viewModel.headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.snappy, value: viewModel.headerSubtitle)
        }
    }

    // MARK: - Kakao Baseline

    private var kakaoBaselineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailCard(title: "주소", value: viewModel.place.address)

            HStack(spacing: 10) {
                if !viewModel.place.category.isEmpty {
                    detailChip(title: "카테고리", value: viewModel.place.category)
                }

                if let phone = viewModel.place.phone, !phone.isEmpty {
                    detailChip(title: "전화", value: phone)
                }
            }

            if let mapURL = viewModel.place.kakaoMapURL {
                Link(destination: mapURL) {
                    HStack(spacing: 6) {
                        Image(systemName: "map")
                            .font(.subheadline.weight(.medium))
                        Text("카카오맵에서 보기")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.tint)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: - SSE Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.progressLog.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.currentProgress?.message ?? "검색을 시작하고 있어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(Array(viewModel.progressLog.enumerated()), id: \.offset) { index, progress in
                    progressLine(
                        progress,
                        isCurrent: viewModel.isLoading && index == viewModel.progressLog.count - 1
                    )
                }

                if !viewModel.isLoading, viewModel.detail != nil {
                    progressLine(
                        GrokSearchProgress(
                            message: "검색 완료",
                            detail: viewModel.detail?.name
                        ),
                        isCurrent: viewModel.revealStep == 0
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progressLine(_ progress: GrokSearchProgress, isCurrent: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Group {
                if isCurrent {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(progress.message)
                    .font(.subheadline)
                    .foregroundStyle(isCurrent ? .primary : .tertiary)
                    .contentTransition(.opacity)

                if let detail = progress.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(isCurrent ? .secondary : .tertiary)
                        .contentTransition(.opacity)
                }
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8)),
            removal: .opacity
        ))
    }

    // MARK: - Grok Enrichment

    @ViewBuilder
    private var enrichmentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("추가 정보")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            switch viewModel.enrichmentState {
            case .idle, .loading:
                enrichmentSkeleton
            case .loaded:
                if let detail = viewModel.detail {
                    enrichmentResult(detail)
                }
            case .failed(let message):
                enrichmentFailure(message)
            }
        }
    }

    private var enrichmentSkeleton: some View {
        VStack(alignment: .leading, spacing: 14) {
            skeletonChip(title: "영업 상태")
            skeletonCard(title: "영업시간", lines: 2)
        }
    }

    private func enrichmentResult(_ detail: GrokPlaceDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.revealStep >= 1 {
                detailChip(
                    title: "영업 상태",
                    value: detail.isOpenNow ? "영업 중" : "영업 종료",
                    tint: detail.isOpenNow ? .green : .orange
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(resultTransition)
            }

            if viewModel.revealStep >= 2, detail.hasBusinessHours {
                detailCard(title: "영업시간", value: detail.businessHours)
                    .transition(resultTransition)
            }

            if viewModel.revealStep >= 3 {
                jsonDisclosure(detail.formattedJSON)
                    .transition(resultTransition)
            }
        }
    }

    private func enrichmentFailure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                Text("추가 정보를 불러오지 못했어요")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("다시 시도") {
                viewModel.retryEnrichment()
            }
            .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Components

    private func detailCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func detailChip(title: String, value: String, tint: Color = .secondary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func skeletonChip(title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("불러오는 중")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func skeletonCard(title: String, lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(0 ..< lines, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 14)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("Grok 확인 중")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
        }
    }

    private func jsonDisclosure(_ json: String) -> some View {
        DisclosureGroup(isExpanded: $isJSONExpanded) {
            Text(json)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        } label: {
            Text("JSON")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var resultTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 14)).combined(with: .scale(scale: 0.97)),
            removal: .opacity
        )
    }
}

#Preview {
    NavigationStack {
        PlaceDetailView(
            place: Place(
                id: "preview",
                name: "카페 드롭탑 구미인동점",
                address: "경북 구미시 인동가산로 12",
                category: "카페",
                phone: "054-123-4567",
                kakaoMapURL: URL(string: "https://place.map.kakao.com/123"),
                coordinate: .init(latitude: 36.12, longitude: 128.34)
            )
        )
    }
}