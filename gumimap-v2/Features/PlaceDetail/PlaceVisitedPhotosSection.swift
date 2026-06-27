import PhotosUI
import SwiftData
import SwiftUI

struct PlaceVisitedPhotosSection: View {
    let savedPlaceId: String
    let photoStore: PlacePhotoStore

    @Query private var photos: [PlacePhoto]
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var importErrorMessage: String?

    private var remainingSlots: Int {
        max(0, PlacePhotoFileIO.maxPhotosPerPlace - photos.count)
    }

    private var canAddPhotos: Bool {
        remainingSlots > 0 && !isImporting
    }

    init(savedPlaceId: String, photoStore: PlacePhotoStore) {
        self.savedPlaceId = savedPlaceId
        self.photoStore = photoStore
        _photos = Query(
            filter: #Predicate<PlacePhoto> { $0.savedPlaceId == savedPlaceId },
            sort: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.createdAt)
            ]
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(alignment: .leading, spacing: 10) {
                photoStrip

                if photos.isEmpty {
                    Text("다녀온 순간을 사진으로 남겨 보세요")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if isImporting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("사진을 저장하고 있어요")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await importPickerItems(newItems)
            }
        }
        .alert("사진 불러오기", isPresented: importErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("내 사진")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            Spacer()

            Text("\(photos.count)/\(PlacePhotoFileIO.maxPhotosPerPlace)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    photoThumbnail(photo, index: index + 1)
                }

                if canAddPhotos {
                    addPhotoTile
                } else if photos.count >= PlacePhotoFileIO.maxPhotosPerPlace {
                    maxCountTile
                }
            }
        }
        .scrollDisabled(photos.count < 3 && canAddPhotos)
    }

    private func photoThumbnail(_ photo: PlacePhoto, index: Int) -> some View {
        Group {
            if let image = PlacePhotoFileIO.loadImage(
                savedPlaceId: savedPlaceId,
                fileName: photo.fileName
            ) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.tertiarySystemFill)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .accessibilityLabel("사진, \(index)번째")
        .accessibilityValue("총 \(photos.count)장 중 \(index)번째")
    }

    private var addPhotoTile: some View {
        PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: remainingSlots,
            matching: .images,
            photoLibrary: .shared()
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 80, height: 80)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    }

                Image(systemName: "plus")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .disabled(isImporting)
        .accessibilityLabel("사진 추가")
        .accessibilityHint("탭하면 앨범에서 사진을 선택해요")
        .accessibilityAddTraits(.isButton)
    }

    private var maxCountTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 80, height: 80)
                .opacity(0.45)

            Image(systemName: "checkmark")
                .font(.title3.weight(.medium))
                .foregroundStyle(.tertiary)
        }
        .accessibilityLabel("사진 추가 불가")
        .accessibilityValue("최대 \(PlacePhotoFileIO.maxPhotosPerPlace)장")
        .accessibilityHint("더 이상 추가할 수 없어요")
    }

    private var importErrorPresented: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )
    }

    @MainActor
    private func importPickerItems(_ items: [PhotosPickerItem]) async {
        guard !isImporting else { return }

        isImporting = true
        importErrorMessage = nil
        defer {
            isImporting = false
            pickerItems = []
        }

        let cappedItems = Array(items.prefix(remainingSlots))
        var imageDataItems: [Data] = []
        var loadFailures = 0

        for item in cappedItems {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      !data.isEmpty else {
                    loadFailures += 1
                    continue
                }
                imageDataItems.append(data)
            } catch {
                loadFailures += 1
            }
        }

        guard !imageDataItems.isEmpty else {
            if loadFailures > 0 {
                importErrorMessage = "사진을 불러오지 못했어요."
            }
            return
        }

        do {
            let result = try photoStore.importPhotos(
                savedPlaceId: savedPlaceId,
                imageDataItems: imageDataItems
            )
            let totalFailures = loadFailures + result.failedCount
            if totalFailures > 0 {
                if result.importedCount > 0 {
                    importErrorMessage = "\(result.importedCount)장을 저장했어요. \(totalFailures)장은 불러오지 못했어요."
                } else {
                    importErrorMessage = "사진을 저장하지 못했어요."
                }
            }
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}