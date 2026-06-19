import SwiftUI

struct SearchTabView: View {
    @Bindable var search: SearchViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool

    private var trimmedQuery: String {
        search.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            resultsContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .enableInteractivePopGesture()
        .onAppear {
            Task { @MainActor in
                isFieldFocused = true
            }
        }
        .onDisappear {
            search.reset()
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                ToolbarIcon(asset: .back, isSelected: true, size: 20)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                ToolbarIcon(asset: .search, isSelected: false, size: 20)

                TextField("장소 검색", text: $search.query)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .focused($isFieldFocused)
                    .submitLabel(.search)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var resultsContent: some View {
        if trimmedQuery.isEmpty {
            Spacer()
        } else if !search.results.isEmpty {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(search.results) { place in
                        resultRow(place)

                        if place.id != search.results.last?.id {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        } else if let errorMessage = search.errorMessage, !search.isLoading {
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 4)
            Spacer()
        } else if !search.isLoading {
            Text("검색 결과가 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 4)
            Spacer()
        } else {
            Spacer()
        }
    }

    private func resultRow(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name)
                .font(.body)
                .foregroundStyle(.primary)

            Text(place.address)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !place.category.isEmpty {
                Text(place.category)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

#Preview {
    @Previewable @State var search = SearchViewModel()

    NavigationStack {
        SearchTabView(search: search)
    }
}