import SwiftUI

struct SearchOverlayView: View {
    @Bindable var search: SearchViewModel
    @FocusState private var isFieldFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    private let clusterMaxWidth: CGFloat = 360
    private let resultsMaxHeight: CGFloat = 280

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            searchCluster
                .frame(maxWidth: clusterMaxWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: -keyboardHeight * 0.35)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .animation(.spring(response: 0.38, dampingFraction: 0.78), value: search.results.count)
                .animation(.spring(response: 0.38, dampingFraction: 0.78), value: search.query)
        }
        .onAppear {
            Task { @MainActor in
                isFieldFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
    }

    private var searchCluster: some View {
        VStack(spacing: 10) {
            searchBar
            resultsSection
        }
    }

    private var searchBar: some View {
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
        .floatingCardStyle(shape: Capsule())
    }

    @ViewBuilder
    private var resultsSection: some View {
        let trimmedQuery = search.query.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedQuery.isEmpty {
            VStack(spacing: 0) {
                if search.results.isEmpty {
                    Text("검색 결과가 없습니다")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(search.results) { place in
                                resultRow(place)

                                if place.id != search.results.last?.id {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: resultsMaxHeight)
                }
            }
            .floatingCardStyle(shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .transition(.move(edge: .top).combined(with: .opacity))
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

    private func dismiss() {
        isFieldFocused = false
        search.dismiss()
    }
}

private extension View {
    func floatingCardStyle<S: Shape>(shape: S) -> some View {
        background {
            shape
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
        }
    }
}

#Preview {
    @Previewable @State var search = SearchViewModel()

    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()

        SearchOverlayView(search: search)
            .onAppear { search.present() }
    }
}