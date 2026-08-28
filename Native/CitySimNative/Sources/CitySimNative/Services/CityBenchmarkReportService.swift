import Foundation

struct CityBenchmarkReport: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let reportVersion: Int
    let generatedAt: Date
    let qualification: String
    let result: CityBenchmarkResult
}

struct CityBenchmarkReportService {
    let reportDirectoryURL: URL
    let fileManager: FileManager

    init(
        reportDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let reportDirectoryURL {
            self.reportDirectoryURL = reportDirectoryURL.standardizedFileURL
        } else {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appending(
                    path: "Documents",
                    directoryHint: .isDirectory
                )
            self.reportDirectoryURL = documents
                .appending(path: "CitySim", directoryHint: .isDirectory)
                .appending(path: "Benchmarks", directoryHint: .isDirectory)
                .standardizedFileURL
        }
    }

    func export(
        result: CityBenchmarkResult,
        generatedAt: Date = Date()
    ) throws -> URL {
        try fileManager.createDirectory(at: reportDirectoryURL, withIntermediateDirectories: true)
        let report = CityBenchmarkReport(
            reportVersion: CityBenchmarkReport.currentVersion,
            generatedAt: generatedAt,
            qualification: CityBenchmarkDefinition.verticalSlice.qualification,
            result: result
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        let destination = availableURL()
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private func availableURL() -> URL {
        var suffix = 1
        var candidate = reportDirectoryURL.appending(path: "native-dense-3x-v3.json")
        while fileManager.fileExists(atPath: candidate.path) {
            suffix += 1
            candidate = reportDirectoryURL.appending(path: "native-dense-3x-v3-\(suffix).json")
        }
        return candidate
    }
}
