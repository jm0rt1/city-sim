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
}

struct SaveGameLoadResult: Equatable, Sendable {
    let state: CityGameState
    let schemaVersion: Int
    let fingerprint: CityStateFingerprint
    let source: SaveGameSource

    var recoveredFromBackup: Bool { source == .backup }
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
            return SaveGameLoadResult(
                state: envelope.state,
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
