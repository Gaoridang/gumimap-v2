import CoreLocation
import SwiftUI

struct PlaceDetailView: View {
    @State private var viewModel: PlaceDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(place: Place) {
        _viewModel = State(initialValue: PlaceDetailViewModel(place: place))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                if viewModel.showProgress {
                    progressSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let errorMessage = viewModel.errorMessage {
                    errorSection(errorMessage)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                if let detail = viewModel.detail, viewModel.revealStep >= 1 {
                    resultSection(detail)
                }
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

    // MARK: - Progress

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

    // MARK: - Error

    private func errorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("오류", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Result

    private func resultSection(_ detail: GrokPlaceDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.revealStep >= 1 {
                detailCard(title: "이름", value: detail.name)
            }
            if viewModel.revealStep >= 2 {
                detailCard(title: "주소", value: detail.address)
            }
            if viewModel.revealStep >= 3 {
                HStack(spacing: 10) {
                    detailChip(title: "카테고리", value: detail.category)
                    detailChip(
                        title: "영업 상태",
                        value: detail.isOpenNow ? "영업 중" : "영업 종료",
                        tint: detail.isOpenNow ? .green : .orange
                    )
                }
            }
            if viewModel.revealStep >= 4, detail.hasBusinessHours {
                detailCard(title: "영업시간", value: detail.businessHours)
            }
            if viewModel.revealStep >= 5 {
                jsonCard(detail.formattedJSON)
            }
        }
    }

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
        .transition(resultTransition)
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
        .transition(resultTransition)
    }

    private func jsonCard(_ json: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("JSON")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            Text(json)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .transition(resultTransition)
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
                phone: nil,
                kakaoMapURL: nil,
                coordinate: .init(latitude: 36.12, longitude: 128.34)
            )
        )
    }
}