import Foundation

struct SaveGameEnvelope: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let fingerprintVersion: Int
    let state: CityGameState
    let digest: String
}

enum SaveGameSource: String, Codable, Equatable, Sendable {
    case primary
    case backup
    case autosave
}

struct SaveGameLoadResult: Equatable, Sendable {
    let state: CityGameState
    let schemaVersion: Int
    let fingerprint: CityStateFingerprint
    let source: SaveGameSource

    var recoveredFromBackup: Bool { source == .backup }
    var isAutosave: Bool { source == .autosave }
}

struct SaveGameWriteResult: Equatable, Sendable {
    let schemaVersion: Int
    let fingerprint: CityStateFingerprint
    let byteCount: Int
}

enum SaveGameError: Error, Equatable {
    case unsupportedSchema(Int)
    case fingerprintVersionMismatch(expected: Int, actual: Int)
    case digestMismatch(expected: String, actual: String)
    case noValidSave(primary: String?, backup: String?)
}

extension SaveGameError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            "Unsupported save schema \(version)."
        case .fingerprintVersionMismatch(let expected, let actual):
            "Save fingerprint version \(actual) does not match expected version \(expected)."
        case .digestMismatch:
            "The save's integrity fingerprint does not match its city state."
        case .noValidSave:
            "No valid primary or backup save was found."
        }
    }
}

struct SaveGameService {
    static let dataRootEnvironmentKey = "CITYSIM_DATA_ROOT"
    static let autosaveSlotCount = 3

    let rootURL: URL
    let fileManager: FileManager
    private let beforePrimaryReplacement: (() throws -> Void)?

    init(
        rootURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        beforePrimaryReplacement: (() throws -> Void)? = nil
    ) {
        self.fileManager = fileManager
        self.beforePrimaryReplacement = beforePrimaryReplacement

        if let rootURL {
            self.rootURL = rootURL.standardizedFileURL
        } else if let override = environment[Self.dataRootEnvironmentKey], !override.isEmpty {
            self.rootURL = URL(fileURLWithPath: override, isDirectory: true).standardizedFileURL
        } else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.rootURL = support.appending(path: "CitySimNative", directoryHint: .isDirectory).standardizedFileURL
        }
    }

    var saveURL: URL { rootURL.appending(path: "quicksave.json") }
    var backupURL: URL { rootURL.appending(path: "quicksave.backup.json") }
    private var candidateURL: URL { rootURL.appending(path: ".quicksave.candidate.json") }
    var autosaveURLs: [URL] {
        (0..<Self.autosaveSlotCount).map {
            rootURL.appending(path: "autosave-\($0).json")
        }
    }

    var hasLoadCandidate: Bool {
        let primaryExists = fileManager.fileExists(atPath: saveURL.path)
        let backupExists = fileManager.fileExists(atPath: backupURL.path)
        return primaryExists || backupExists
    }

    var hasResumeCandidate: Bool {
        hasLoadCandidate || autosaveURLs.contains {
            fileManager.fileExists(atPath: $0.path)
        }
    }

    @discardableResult
    func save(_ state: CityGameState) throws -> SaveGameWriteResult {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let fingerprint = try CityStateFingerprinter.fingerprint(state)
        let envelope = SaveGameEnvelope(
            schemaVersion: SaveGameEnvelope.currentSchemaVersion,
            fingerprintVersion: fingerprint.version,
            state: state,
            digest: fingerprint.digest
        )
        let data = try Self.envelopeEncoder.encode(envelope)

        try? fileManager.removeItem(at: candidateURL)
        defer { try? fileManager.removeItem(at: candidateURL) }
        try data.write(to: candidateURL, options: .atomic)

        let validatedCandidate = try decodeSave(at: candidateURL, source: .primary)
        guard validatedCandidate.state == state, validatedCandidate.fingerprint == fingerprint else {
            throw SaveGameError.digestMismatch(
                expected: fingerprint.digest,
                actual: validatedCandidate.fingerprint.digest
            )
        }

        if fileManager.fileExists(atPath: saveURL.path) {
            do {
                _ = try decodeSave(at: saveURL, source: .primary)
                try Data(contentsOf: saveURL).write(to: backupURL, options: .atomic)
            } catch {
                _ = try? preserveCorruptFile(at: saveURL)
            }
        }

        try beforePrimaryReplacement?()
        if fileManager.fileExists(atPath: saveURL.path) {
            _ = try fileManager.replaceItemAt(saveURL, withItemAt: candidateURL)
        } else {
            try fileManager.moveItem(at: candidateURL, to: saveURL)
        }

        return SaveGameWriteResult(
            schemaVersion: envelope.schemaVersion,
            fingerprint: fingerprint,
            byteCount: data.count
        )
    }

    @discardableResult
    func saveAutosave(_ state: CityGameState) throws -> SaveGameWriteResult {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let fingerprint = try CityStateFingerprinter.fingerprint(state)
        let envelope = SaveGameEnvelope(
            schemaVersion: SaveGameEnvelope.currentSchemaVersion,
            fingerprintVersion: fingerprint.version,
            state: state,
            digest: fingerprint.digest
        )
        let data = try Self.envelopeEncoder.encode(envelope)
        let destinationURL = nextAutosaveURL()
        let candidateURL = rootURL.appending(path: ".\(destinationURL.lastPathComponent).candidate")

        try? fileManager.removeItem(at: candidateURL)
        defer { try? fileManager.removeItem(at: candidateURL) }
        try data.write(to: candidateURL, options: .atomic)

        let validatedCandidate = try decodeSave(at: candidateURL, source: .autosave)
        guard validatedCandidate.state == state,
              validatedCandidate.fingerprint == fingerprint else {
            throw SaveGameError.digestMismatch(
                expected: fingerprint.digest,
                actual: validatedCandidate.fingerprint.digest
            )
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: candidateURL)
        } else {
            try fileManager.moveItem(at: candidateURL, to: destinationURL)
        }

        return SaveGameWriteResult(
            schemaVersion: envelope.schemaVersion,
            fingerprint: fingerprint,
            byteCount: data.count
        )
    }

    func load() throws -> SaveGameLoadResult {
        var primaryFailure: String?
        if fileManager.fileExists(atPath: saveURL.path) {
            do {
                return try decodeSave(at: saveURL, source: .primary)
            } catch {
                primaryFailure = String(describing: error)
                _ = try? preserveCorruptFile(at: saveURL)
            }
        }

        var backupFailure: String?
        if fileManager.fileExists(atPath: backupURL.path) {
            do {
                return try decodeSave(at: backupURL, source: .backup)
            } catch {
                backupFailure = String(describing: error)
                _ = try? preserveCorruptFile(at: backupURL)
            }
        }

        throw SaveGameError.noValidSave(primary: primaryFailure, backup: backupFailure)
    }

    func loadLatestResumeCandidate() throws -> SaveGameLoadResult {
        var candidates: [(result: SaveGameLoadResult, date: Date, priority: Int)] = []

        if hasLoadCandidate, let result = try? load() {
            let url = result.source == .backup ? backupURL : saveURL
            candidates.append((result, modificationDate(for: url), sourcePriority(result.source)))
        }

        for url in autosaveURLs where fileManager.fileExists(atPath: url.path) {
            do {
                let result = try decodeSave(at: url, source: .autosave)
                candidates.append((result, modificationDate(for: url), sourcePriority(.autosave)))
            } catch {
                _ = try? preserveCorruptFile(at: url)
            }
        }

        guard let latest = candidates.max(by: { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.priority < rhs.priority
        }) else {
            throw SaveGameError.noValidSave(primary: nil, backup: nil)
        }
        return latest.result
    }

    private func nextAutosaveURL() -> URL {
        if let empty = autosaveURLs.first(where: {
            !fileManager.fileExists(atPath: $0.path)
        }) {
            return empty
        }
        return autosaveURLs.min {
            let lhsDate = modificationDate(for: $0)
            let rhsDate = modificationDate(for: $1)
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return $0.lastPathComponent < $1.lastPathComponent
        } ?? autosaveURLs[0]
    }

    private func modificationDate(for url: URL) -> Date {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date ?? .distantPast
    }

    private func sourcePriority(_ source: SaveGameSource) -> Int {
        switch source {
        case .primary: 3
        case .backup: 2
        case .autosave: 1
        }
    }

    private func decodeSave(at url: URL, source: SaveGameSource) throws -> SaveGameLoadResult {
        let data = try Data(contentsOf: url)
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let schemaVersion = object?["schemaVersion"] as? Int {
            guard schemaVersion == SaveGameEnvelope.currentSchemaVersion else {
                throw SaveGameError.unsupportedSchema(schemaVersion)
            }

            let envelope = try Self.decoder.decode(SaveGameEnvelope.self, from: data)
            guard envelope.fingerprintVersion == CityStateFingerprint.currentVersion else {
                throw SaveGameError.fingerprintVersionMismatch(
                    expected: CityStateFingerprint.currentVersion,
                    actual: envelope.fingerprintVersion
                )
            }
            let fingerprint = try CityStateFingerprinter.fingerprint(
                envelope.state,
                version: envelope.fingerprintVersion
            )
            guard fingerprint.digest == envelope.digest else {
                throw SaveGameError.digestMismatch(expected: envelope.digest, actual: fingerprint.digest)
            }
            var state = envelope.state
            state.preserveLegacyReplayConsequencesIfKnownFixture()
            return SaveGameLoadResult(
                state: state,
                schemaVersion: envelope.schemaVersion,
                fingerprint: fingerprint,
                source: source
            )
        }

        let state = try Self.decoder.decode(CityGameState.self, from: data)
        return SaveGameLoadResult(
            state: state,
            schemaVersion: 0,
            fingerprint: try CityStateFingerprinter.fingerprint(state),
            source: source
        )
    }

    @discardableResult
    private func preserveCorruptFile(at url: URL) throws -> URL {
        let baseName = url.deletingPathExtension().lastPathComponent
        let preservedURL = rootURL.appending(path: "\(baseName).corrupt-\(UUID().uuidString.lowercased()).json")
        try fileManager.copyItem(at: url, to: preservedURL)
        return preservedURL
    }

    private static let decoder = JSONDecoder()

    private static let envelopeEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
