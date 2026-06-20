import CoreLocation
import SwiftUI

struct PlaceDetailView: View {
    @State private var viewModel: PlaceDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.placeStore) private var placeStore
    @Environment(\.placeEnrichmentService) private var enrichmentService
    @Environment(TabRouter.self) private var router
    @State private var showRegistrationSheet = false

    init(place: Place) {
        _viewModel = State(initialValue: PlaceDetailViewModel(place: place))
    }

    init(savedPlaceId: String, store: PlaceStore) {
        _viewModel = State(initialValue: PlaceDetailViewModel(savedPlaceId: savedPlaceId, store: store))
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

                if viewModel.showAdditionalInfo {
                    additionalInfoSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, viewModel.isDiscoveryMode ? 24 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .enableInteractivePopGesture()
        .safeAreaInset(edge: .bottom) {
            if viewModel.isDiscoveryMode {
                registerButton
            }
        }
        .animation(.snappy, value: viewModel.isLoading)
        .animation(.snappy, value: viewModel.progressLog.count)
        .animation(.snappy, value: viewModel.revealStep)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: viewModel.showAdditionalInfo)
        .onAppear { viewModel.loadIfNeeded() }
        .onDisappear { viewModel.cancelTasks() }
        .onChange(of: viewModel.canRegister) { _, canRegister in
            if !canRegister {
                showRegistrationSheet = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .savedPlaceEnrichmentUpdated)) { notification in
            guard let updatedId = notification.object as? String,
                  updatedId == viewModel.savedPlaceId,
                  let placeStore else { return }
            viewModel.refreshFromStore(store: placeStore)
        }
        .sheet(isPresented: $showRegistrationSheet) {
            PlaceRegistrationSheet(
                placeName: viewModel.place.name,
                isSaving: viewModel.isSavingRegistration
            ) { listKind in
                Task {
                    await handleRegistration(listKind: listKind)
                }
            }
        }
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
                    Text(viewModel.currentProgress?.message ?? "추가 정보를 불러오고 있어요")
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
                        GrokSearchProgress(message: "추가 정보를 불러왔어요"),
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

    // MARK: - Additional Info

    @ViewBuilder
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("추가 정보")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            switch viewModel.enrichmentState {
            case .loaded:
                if let detail = viewModel.detail {
                    insightResult(detail)
                }
            case .failed(let message):
                additionalInfoFailure(message)
            case .idle, .loading:
                EmptyView()
            }
        }
    }

    private func insightResult(_ detail: GrokPlaceDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !detail.hasAnyInsight {
                Text("추가로 찾은 정보가 없어요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    .transition(resultTransition)
            }

            if viewModel.revealStep >= 1 {
                fieldsCard(detail.visibleFieldRows)
                    .transition(resultTransition)
            }

            if viewModel.revealStep >= 2, detail.hasReviews {
                bulletCard(
                    title: "리뷰",
                    icon: "text.quote",
                    points: detail.reviewPoints
                )
                .transition(resultTransition)
            }
        }
    }

    private func additionalInfoFailure(_ message: String) -> some View {
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

            if viewModel.isDiscoveryMode {
                Button("다시 시도") {
                    viewModel.retryEnrichment()
                }
                .font(.subheadline.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Register

    private var registerButton: some View {
        HStack(spacing: 10) {
            Button {
                guard viewModel.canRegister else { return }
                showRegistrationSheet = true
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color(.systemBackground))
                    } else {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                    Text(viewModel.isLoading ? "추가 정보 확인 중" : "등록하기")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.canRegister ? Color.primary : Color.primary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canRegister)

            if let isOpen = viewModel.isOpenNow, isOpen {
                openStatusBadge
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: viewModel.isOpenNow)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background {
            Color(.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.06), radius: 8, y: -4)
        }
    }

    private var openStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            Text("영업중")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private func handleRegistration(listKind: ListSubTab) async {
        guard let placeStore, let enrichmentService else { return }
        guard let savedPlaceId = await viewModel.register(
            listKind: listKind,
            store: placeStore,
            enrichmentService: enrichmentService
        ) else {
            return
        }

        showRegistrationSheet = false
        router.completeRegistration(savedPlaceId: savedPlaceId, listKind: listKind)
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

    private func detailChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func fieldsCard(_ rows: [GrokVisibleFieldRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    featureRow(label: row.label, value: row.value)

                    if index < rows.count - 1 {
                        Divider()
                            .padding(.leading, 96)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func featureRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(value == "정보 없음" ? .tertiary : .primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }

    private func bulletCard(title: String, icon: String, points: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 1)

                        Text(point)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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