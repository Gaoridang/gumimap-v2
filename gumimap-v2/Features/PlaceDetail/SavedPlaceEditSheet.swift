import SwiftUI

struct SavedPlaceEditDraft: Equatable {
    var name: String
    var address: String
    var category: String
    var phone: String
    var businessHours: String
    var breakTime: String
    var closedDay: String
    var parking: String
    var atmosphere: String
    var features: String
    var reviewsText: String

    init(place: Place, detail: GrokPlaceDetail?) {
        name = place.name
        address = place.address
        category = place.category
        phone = place.phone ?? ""
        businessHours = detail?.editableValue(for: .businessHours) ?? ""
        breakTime = detail?.editableValue(for: .breakTime) ?? ""
        closedDay = detail?.editableValue(for: .closedDay) ?? ""
        parking = detail?.editableValue(for: .parking) ?? ""
        atmosphere = detail?.editableValue(for: .atmosphere) ?? ""
        features = detail?.editableValue(for: .features) ?? ""
        reviewsText = detail?.reviewPoints.joined(separator: "\n") ?? ""
    }

    var canSave: Bool {
        !trimmed(name).isEmpty
            && !trimmed(address).isEmpty
            && !trimmed(category).isEmpty
    }

    func hasChanges(comparedTo other: SavedPlaceEditDraft) -> Bool {
        self != other
    }

    func makeGrokDetail(
        latitude: Double,
        longitude: Double,
        existingSearchQuery: String?
    ) -> GrokPlaceDetail? {
        let fields = GrokVisibleField.allCases.compactMap { field -> GrokInsightField? in
            let value = trimmed(fieldValue(for: field))
            guard !value.isEmpty else { return nil }
            return GrokInsightField(label: field.title, value: value)
        }

        let reviews = reviewsText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !fields.isEmpty || !reviews.isEmpty else { return nil }

        return GrokPlaceDetail(
            name: trimmed(name),
            address: trimmed(address),
            latitude: latitude,
            longitude: longitude,
            category: trimmed(category),
            searchQuery: existingSearchQuery ?? "",
            fields: fields,
            reviews: reviews
        )
    }

    private func fieldValue(for field: GrokVisibleField) -> String {
        switch field {
        case .businessHours: businessHours
        case .breakTime: breakTime
        case .closedDay: closedDay
        case .parking: parking
        case .atmosphere: atmosphere
        case .features: features
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SavedPlaceEditSheet: View {
    let isProcessing: Bool
    let onSave: (SavedPlaceEditDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: SavedPlaceEditDraft
    private let initialDraft: SavedPlaceEditDraft

    init(
        place: Place,
        detail: GrokPlaceDetail?,
        isProcessing: Bool,
        onSave: @escaping (SavedPlaceEditDraft) -> Void
    ) {
        let initial = SavedPlaceEditDraft(place: place, detail: detail)
        self.isProcessing = isProcessing
        self.onSave = onSave
        self.initialDraft = initial
        _draft = State(initialValue: initial)
    }

    private var canSubmit: Bool {
        draft.canSave && draft.hasChanges(comparedTo: initialDraft) && !isProcessing
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    sectionHeader("기본 정보", subtitle: "이름, 주소 등 잘못된 내용을 고쳐요")

                    VStack(spacing: 12) {
                        editField(title: "이름", text: $draft.name, required: true)
                        editField(title: "주소", text: $draft.address, required: true, axis: .vertical)
                        editField(title: "카테고리", text: $draft.category, required: true)
                        editField(title: "전화번호", text: $draft.phone, placeholder: "선택")
                    }

                    sectionHeader("추가 정보", subtitle: "영업시간, 분위기 등 직접 입력하거나 수정해요")

                    VStack(spacing: 12) {
                        editField(title: "영업시간", text: $draft.businessHours, axis: .vertical)
                        editField(title: "브레이크타임", text: $draft.breakTime, axis: .vertical)
                        editField(title: "휴무일", text: $draft.closedDay, axis: .vertical)
                        editField(title: "주차", text: $draft.parking, axis: .vertical)
                        editField(title: "분위기", text: $draft.atmosphere, axis: .vertical)
                        editField(title: "특징", text: $draft.features, axis: .vertical)
                        editField(
                            title: "리뷰",
                            text: $draft.reviewsText,
                            placeholder: "한 줄에 하나씩 입력",
                            axis: .vertical,
                            minLines: 3
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("정보 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(draft)
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSubmit)
                }
            }
            .interactiveDismissDisabled(isProcessing)
            .overlay {
                if isProcessing {
                    ProgressView("저장하고 있어요")
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func editField(
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        required: Bool = false,
        axis: Axis = .horizontal,
        minLines: Int = 1
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)

                if required {
                    Text("*")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            TextField(placeholder.isEmpty ? title : placeholder, text: text, axis: axis)
                .font(.body)
                .lineLimit(minLines ... (axis == .vertical ? 8 : 1))
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}