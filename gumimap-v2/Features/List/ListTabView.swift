import SwiftData
import SwiftUI

struct ListTabView: View {
    let subTab: ListSubTab

    @Environment(\.placeStore) private var placeStore
    @Query(sort: \SavedPlace.registeredAt, order: .reverse) private var savedPlaces: [SavedPlace]
    @State private var placeToMoveID: String?
    @State private var isMoving = false

    private var places: [SavedPlace] {
        savedPlaces.filter { $0.listKind == subTab.rawValue }
    }

    private var placeToMove: SavedPlace? {
        guard let placeToMoveID else { return nil }
        return places.first { $0.id == placeToMoveID }
    }

    var body: some View {
        Group {
            if places.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.2), value: subTab)
        .animation(.easeInOut(duration: 0.2), value: places.count)
        .sheet(isPresented: Binding(
            get: { placeToMoveID != nil },
            set: { if !$0 { placeToMoveID = nil } }
        )) {
            if let savedPlace = placeToMove {
                PlaceListKindSheet(
                    placeName: savedPlace.name,
                    title: "어디로 옮길까요?",
                    isProcessing: isMoving,
                    processingMessage: "옮기고 있어요",
                    disabledListKind: savedPlace.listSubTab
                ) { listKind in
                    Task {
                        await move(savedPlace, to: listKind)
                    }
                }
            }
        }
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

    private var listContent: some View {
        List {
            ForEach(places, id: \.id) { savedPlace in
                NavigationLink(value: AppRoute.savedPlaceDetail(id: savedPlace.id)) {
                    listRow(savedPlace)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        placeToMoveID = savedPlace.id
                    } label: {
                        Label("옮기기", systemImage: "arrow.left.arrow.right")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        delete(savedPlace)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color(.systemGroupedBackground))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.top, 8)
        .padding(.bottom, 120)
    }

    private func listRow(_ savedPlace: SavedPlace) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(savedPlace.name)
                .font(.body)
                .foregroundStyle(.primary)

            Text(savedPlace.address)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !savedPlace.category.isEmpty {
                Text(savedPlace.category)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func delete(_ savedPlace: SavedPlace) {
        guard let placeStore else { return }
        try? placeStore.delete(savedPlaceId: savedPlace.id)
    }

    private func move(_ savedPlace: SavedPlace, to listKind: ListSubTab) async {
        guard let placeStore else { return }
        guard savedPlace.listSubTab != listKind else { return }

        isMoving = true
        defer {
            isMoving = false
            placeToMoveID = nil
        }

        try? placeStore.moveListKind(savedPlaceId: savedPlace.id, to: listKind)
    }
}

#Preview {
    ListTabView(subTab: .visited)
}