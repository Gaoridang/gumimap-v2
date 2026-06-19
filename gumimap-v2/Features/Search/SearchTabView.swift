import SwiftUI

struct SearchTabView: View {
    @Bindable var router: TabRouter
    @Bindable var search: SearchViewModel
    @FocusState private var isFieldFocused: Bool

    private var trimmedQuery: String {
        search.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Color(.systemGroupedBackground)
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    searchHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    resultsContent
                }
            }
            .ignoresSafeArea(edges: .bottom)
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
            Button(action: router.closeSearch) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 36, height: 36)

                    ToolbarIcon(asset: .back, isSelected: true, size: 17)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                ToolbarIcon(asset: .search, isSelected: false, size: 20)

                TextField("장소 검색", text: $search.query)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.black)
                    .focused($isFieldFocused)
                    .submitLabel(.search)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                Capsule()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
            }
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        if trimmedQuery.isEmpty {
            Spacer()
        } else if search.results.isEmpty {
            Text("검색 결과가 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 4)
            Spacer()
        } else {
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
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
                    .padding(.horizontal, 16)
            }
        }
    }

    private func resultRow(_ place: MockPlace) -> some View {
        Button {
            search.select(place)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.body)
                    .foregroundStyle(.black)

                Text(place.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var router = TabRouter()
    @Previewable @State var search = SearchViewModel()

    SearchTabView(router: router, search: search)
        .onAppear { router.openSearch() }
}