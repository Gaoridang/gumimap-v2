import ImageIO
import UIKit

enum PlacePhotoFileIO {
    static let maxPhotosPerPlace = 5
    static let maxPixelDimension = 1024
    static let jpegQuality: CGFloat = 0.78
    private static let subdirectoryName = "PlacePhotos"

    static func directoryURL(savedPlaceId: String) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent(subdirectoryName, isDirectory: true)
        let placeDirectory = root.appendingPathComponent(savedPlaceId, isDirectory: true)
        try FileManager.default.createDirectory(at: placeDirectory, withIntermediateDirectories: true)
        return placeDirectory
    }

    static func fileURL(savedPlaceId: String, fileName: String) throws -> URL {
        try directoryURL(savedPlaceId: savedPlaceId).appendingPathComponent(fileName)
    }

    @discardableResult
    static func writeJPEG(
        from imageData: Data,
        savedPlaceId: String,
        fileName: String
    ) throws -> URL {
        guard let jpegData = makeJPEGData(from: imageData) else {
            throw PlacePhotoError.encodingFailed
        }

        let destination = try fileURL(savedPlaceId: savedPlaceId, fileName: fileName)
        do {
            try jpegData.write(to: destination, options: .atomic)
            return destination
        } catch {
            throw PlacePhotoError.fileIOFailed(underlying: error)
        }
    }

    static func deleteFile(savedPlaceId: String, fileName: String) throws {
        let url = try fileURL(savedPlaceId: savedPlaceId, fileName: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    static func deleteAllFiles(savedPlaceId: String) throws {
        let directory = try directoryURL(savedPlaceId: savedPlaceId)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    static func loadImage(savedPlaceId: String, fileName: String) -> UIImage? {
        guard let url = try? fileURL(savedPlaceId: savedPlaceId, fileName: fileName),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

    private static func makeJPEGData(from imageData: Data) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage).jpegData(compressionQuality: jpegQuality)
    }
}

enum PlacePhotoError: LocalizedError {
    case savedPlaceNotFound
    case limitReached(max: Int)
    case encodingFailed
    case fileIOFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .savedPlaceNotFound:
            "저장된 장소를 찾을 수 없어요."
        case let .limitReached(max):
            "사진은 최대 \(max)장까지 추가할 수 있어요."
        case .encodingFailed:
            "사진을 저장하지 못했어요."
        case .fileIOFailed:
            "사진 파일을 저장하지 못했어요."
        }
    }
}