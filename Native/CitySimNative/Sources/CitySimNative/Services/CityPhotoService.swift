import Foundation

enum CityPhotoExportError: LocalizedError, Equatable {
    case emptyImage

    var errorDescription: String? {
        switch self {
        case .emptyImage: "The renderer did not produce an image. Keep Photo Mode open and try again."
        }
    }
}

struct CityPhotoExportResult: Equatable, Sendable {
    let url: URL
    let byteCount: Int
}

struct CityPhotoService {
    let photoDirectoryURL: URL
    let fileManager: FileManager

    init(
        photoDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let photoDirectoryURL {
            self.photoDirectoryURL = photoDirectoryURL.standardizedFileURL
        } else {
            let pictures = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appending(
                    path: "Pictures",
                    directoryHint: .isDirectory
                )
            self.photoDirectoryURL = pictures
                .appending(path: "CitySim", directoryHint: .isDirectory)
                .standardizedFileURL
        }
    }

    func export(pngData: Data, cityName: String, day: Int) throws -> CityPhotoExportResult {
        guard !pngData.isEmpty else { throw CityPhotoExportError.emptyImage }
        try fileManager.createDirectory(at: photoDirectoryURL, withIntermediateDirectories: true)
        let baseName = "\(Self.fileSafeName(cityName))-Day-\(max(1, day))"
        let url = availableURL(baseName: baseName)
        try pngData.write(to: url, options: .atomic)
        return CityPhotoExportResult(url: url, byteCount: pngData.count)
    }

    static func fileSafeName(_ value: String) -> String {
        let words = value.unicodeScalars.split { scalar in
            !CharacterSet.alphanumerics.contains(scalar)
        }
        let name = words.map(String.init).filter { !$0.isEmpty }.joined(separator: "-")
        return name.isEmpty ? "City" : String(name.prefix(48))
    }

    private func availableURL(baseName: String) -> URL {
        var suffix = 1
        var candidate = photoDirectoryURL.appending(path: "\(baseName).png")
        while fileManager.fileExists(atPath: candidate.path) {
            suffix += 1
            candidate = photoDirectoryURL.appending(path: "\(baseName)-\(suffix).png")
        }
        return candidate
    }
}
