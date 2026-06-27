import Foundation
import SwiftData

struct PlacePhotoImportResult: Sendable {
    let importedCount: Int
    let failedCount: Int
}

@MainActor
final class PlacePhotoStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func photos(for savedPlaceId: String) -> [PlacePhoto] {
        var descriptor = FetchDescriptor<PlacePhoto>(
            predicate: #Predicate { $0.savedPlaceId == savedPlaceId },
            sortBy: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.createdAt)
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func remainingSlots(for savedPlaceId: String) -> Int {
        max(0, PlacePhotoFileIO.maxPhotosPerPlace - photos(for: savedPlaceId).count)
    }

    @discardableResult
    func importPhotos(
        savedPlaceId: String,
        imageDataItems: [Data]
    ) throws -> PlacePhotoImportResult {
        var importedCount = 0
        var failedCount = 0
        let now = Date()

        for imageData in imageDataItems {
            let remaining = remainingSlots(for: savedPlaceId)
            guard remaining > 0 else { break }

            let photoId = UUID().uuidString
            let fileName = "\(photoId).jpg"
            let sortOrder = photos(for: savedPlaceId).count

            do {
                try PlacePhotoFileIO.writeJPEG(
                    from: imageData,
                    savedPlaceId: savedPlaceId,
                    fileName: fileName
                )

                let photo = PlacePhoto(
                    id: photoId,
                    savedPlaceId: savedPlaceId,
                    fileName: fileName,
                    createdAt: now,
                    sortOrder: sortOrder
                )
                modelContext.insert(photo)
                try modelContext.save()
                importedCount += 1
            } catch {
                try? PlacePhotoFileIO.deleteFile(savedPlaceId: savedPlaceId, fileName: fileName)
                failedCount += 1
            }
        }

        return PlacePhotoImportResult(importedCount: importedCount, failedCount: failedCount)
    }

    func deletePhoto(id: String) throws {
        guard let photo = photo(id: id) else { return }

        try? PlacePhotoFileIO.deleteFile(savedPlaceId: photo.savedPlaceId, fileName: photo.fileName)
        modelContext.delete(photo)
        try modelContext.save()
    }

    func deleteAllPhotos(savedPlaceId: String) throws {
        let existing = photos(for: savedPlaceId)
        for photo in existing {
            modelContext.delete(photo)
        }
        if !existing.isEmpty {
            try modelContext.save()
        }
        try PlacePhotoFileIO.deleteAllFiles(savedPlaceId: savedPlaceId)
    }

    private func photo(id: String) -> PlacePhoto? {
        var descriptor = FetchDescriptor<PlacePhoto>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}