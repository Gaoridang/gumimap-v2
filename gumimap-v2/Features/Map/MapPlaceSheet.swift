import SwiftUI

struct MapPlaceSheet: View {
    let savedPlace: SavedPlace

    @Environment(\.dismiss) private var dismiss
    @Environment(\.placeStore) private var placeStore
    @Environment(TabRouter.self) private var router
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isManagingSavedPlace = false

    private var shortCategory: String {
        let parts = savedPlace.category
            .split(separator: ">")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.last.map { String($0) } ?? savedPlace.category
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    infoSection

                    if let detail = savedPlace.grokDetail, detail.hasAnyInsight {
                        enrichmentSection(detail)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(savedPlace.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    savedPlaceMenu
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showEditSheet) {
            PlaceListKindSheet(
                placeName: savedPlace.name,
                title: "어디로 옮길까요?",
                isProcessing: isManagingSavedPlace,
                processingMessage: "옮기고 있어요",
                disabledListKind: savedPlace.listSubTab
            ) { listKind in
                Task {
                    await handleMove(listKind: listKind)
                }
            }
        }
        .confirmationDialog(
            "이 장소를 삭제할까요?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                Task {
                    await handleDelete()
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제하면 이 리스트에서 장소가 사라져요.")
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            categoryIcon

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if let listKind = savedPlace.listSubTab {
                        Text(listKind.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(listKind == .visited ? .green : .blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                (listKind == .visited ? Color.green : Color.blue).opacity(0.12),
                                in: Capsule()
                            )
                    }

                    if savedPlace.grokDetail?.isCurrentlyOpen == true {
                        openBadge
                    }
                }

                if !shortCategory.isEmpty {
                    Text(shortCategory)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(savedPlace.address)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var categoryIcon: some View {
        let tint = PlaceCategoryIcon.tint(for: savedPlace.category)

        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.12))
                .frame(width: 44, height: 44)

            Image(systemName: PlaceCategoryIcon.symbol(for: savedPlace.category))
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
        }
        .accessibilityHidden(true)
    }

    private var openBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            Text("영업중")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.12), in: Capsule())
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let phone = savedPlace.phone, !phone.isEmpty {
                infoRow(title: "전화", value: phone)
            }

            if let mapURL = savedPlace.asPlace.kakaoMapURL {
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

    @ViewBuilder
    private func enrichmentSection(_ detail: GrokPlaceDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("추가 정보")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            fieldsCard(detail.visibleFieldRows)

            if detail.hasReviews {
                bulletCard(
                    title: "리뷰",
                    icon: "text.quote",
                    points: detail.reviewPoints
                )
            }
        }
    }

    private var savedPlaceMenu: some View {
        Menu {
            Button {
                showEditSheet = true
            } label: {
                Label("리스트 변경", systemImage: "arrow.left.arrow.right")
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.medium))
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func fieldsCard(_ rows: [GrokVisibleFieldRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                featureRow(label: row.label, value: row.value)

                if index < rows.count - 1 {
                    Divider()
                        .padding(.leading, 96)
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

    private func handleMove(listKind: ListSubTab) async {
        guard let placeStore else { return }
        guard savedPlace.listSubTab != listKind else { return }

        isManagingSavedPlace = true
        defer {
            isManagingSavedPlace = false
            showEditSheet = false
        }

        do {
            _ = try placeStore.moveListKind(savedPlaceId: savedPlace.id, to: listKind)
            router.selectListSubTab(listKind)
        } catch {
            return
        }
    }

    private func handleDelete() async {
        guard let placeStore else { return }

        isManagingSavedPlace = true
        defer { isManagingSavedPlace = false }

        do {
            try placeStore.delete(savedPlaceId: savedPlace.id)
            dismiss()
        } catch {
            return
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            MapPlaceSheet(
                savedPlace: SavedPlace(
                    id: "preview-visited",
                    kakaoPlaceId: "123",
                    listKind: .visited,
                    name: "카페 드롭탑 구미인동점",
                    address: "경북 구미시 인동가산로 12",
                    category: "음식점 > 카페",
                    phone: "054-123-4567",
                    kakaoMapURLString: "https://place.map.kakao.com/123",
                    latitude: 36.12,
                    longitude: 128.34,
                    enrichmentData: nil,
                    registeredAt: .now,
                    updatedAt: .now
                )
            )
            .environment(TabRouter())
        }
}