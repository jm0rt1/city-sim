import Foundation

struct SaveGameEnvelope: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let fingerprintVersion: Int
    let state: CityGameState
    let digest: String
    let branchName: String?

    init(
        schemaVersion: Int,
        fingerprintVersion: Int,
        state: CityGameState,
        digest: String,
        branchName: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.fingerprintVersion = fingerprintVersion
        self.state = state
        self.digest = digest
        self.branchName = branchName
    }
}

enum SaveGameSource: String, Codable, Equatable, Sendable {
    case primary
    case backup
    case autosave
    case branch
}

struct SaveGameLoadResult: Equatable, Sendable {
    let state: CityGameState
    let schemaVersion: Int
    let fingerprint: CityStateFingerprint
    let source: SaveGameSource
    let branchName: String?

    init(
        state: CityGameState,
        schemaVersion: Int,
        fingerprint: CityStateFingerprint,
        source: SaveGameSource,
        branchName: String? = nil
    ) {
        self.state = state
        self.schemaVersion = schemaVersion
        self.fingerprint = fingerprint
        self.source = source
        self.branchName = branchName
    }

    var recoveredFromBackup: Bool { source == .backup }
    var isAutosave: Bool { source == .autosave }
    var isNamedBranch: Bool { source == .branch }
}

struct SaveGameWriteResult: Equatable, Sendable {
    let schemaVersion: Int
    let fingerprint: CityStateFingerprint
    let byteCount: Int
}

enum SaveGameCheckpointIntegrity: Equatable, Sendable {
    case verified
    case invalid
}

struct SaveGameCheckpointCatalogEntry: Identifiable, Equatable, Sendable {
    let id: String
    let source: SaveGameSource
    let fileName: String
    let modifiedAt: Date
    let integrity: SaveGameCheckpointIntegrity
    let loadResult: SaveGameLoadResult?
    let branchName: String?

    var isLoadable: Bool {
        integrity == .verified && loadResult != nil
    }
}

enum SaveGameError: Error, Equatable {
    case unsupportedSchema(Int)
    case fingerprintVersionMismatch(expected: Int, actual: Int)
    case digestMismatch(expected: String, actual: String)
    case noValidSave(primary: String?, backup: String?)
    case invalidBranchName
    case duplicateBranchName(String)
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
        case .invalidBranchName:
            "Enter a branch name between 1 and 40 characters."
        case .duplicateBranchName(let name):
            "A timeline branch named \(name) already exists."
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
    var branchDirectoryURL: URL {
        rootURL.appending(path: "branches", directoryHint: .isDirectory)
    }
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
        } || !branchURLs.isEmpty
    }

    var branchURLs: [URL] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: branchDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return urls.filter { $0.pathExtension.lowercased() == "json" }
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

    @discardableResult
    func saveNamedBranch(_ state: CityGameState, name: String) throws -> SaveGameWriteResult {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty, cleanedName.count <= 40 else {
            throw SaveGameError.invalidBranchName
        }
        let existingNames = checkpointCatalog().compactMap(\.branchName)
        guard !existingNames.contains(where: {
            $0.compare(cleanedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else {
            throw SaveGameError.duplicateBranchName(cleanedName)
        }

        try fileManager.createDirectory(at: branchDirectoryURL, withIntermediateDirectories: true)
        let fingerprint = try CityStateFingerprinter.fingerprint(state)
        let envelope = SaveGameEnvelope(
            schemaVersion: SaveGameEnvelope.currentSchemaVersion,
            fingerprintVersion: fingerprint.version,
            state: state,
            digest: fingerprint.digest,
            branchName: cleanedName
        )
        let data = try Self.envelopeEncoder.encode(envelope)
        let identifier = UUID().uuidString.lowercased()
        let destinationURL = branchDirectoryURL.appending(path: "branch-\(identifier).json")
        let candidateURL = branchDirectoryURL.appending(path: ".branch-\(identifier).candidate")
        defer { try? fileManager.removeItem(at: candidateURL) }
        try data.write(to: candidateURL, options: .atomic)

        let validated = try decodeSave(at: candidateURL, source: .branch)
        guard validated.state == state,
              validated.fingerprint == fingerprint,
              validated.branchName == cleanedName else {
            throw SaveGameError.digestMismatch(
                expected: fingerprint.digest,
                actual: validated.fingerprint.digest
            )
        }
        try fileManager.moveItem(at: candidateURL, to: destinationURL)
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

        for url in branchURLs {
            if let result = try? decodeSave(at: url, source: .branch) {
                candidates.append((result, modificationDate(for: url), sourcePriority(.branch)))
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

    func checkpointCatalog() -> [SaveGameCheckpointCatalogEntry] {
        let locations = [
            (saveURL, SaveGameSource.primary),
            (backupURL, SaveGameSource.backup),
        ] + autosaveURLs.map { ($0, SaveGameSource.autosave) }
            + branchURLs.map { ($0, SaveGameSource.branch) }

        return locations.compactMap { url, source in
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            let result = try? decodeSave(at: url, source: source)
            return SaveGameCheckpointCatalogEntry(
                id: "\(source.rawValue):\(url.lastPathComponent)",
                source: source,
                fileName: url.lastPathComponent,
                modifiedAt: modificationDate(for: url),
                integrity: result == nil ? .invalid : .verified,
                loadResult: result,
                branchName: result?.branchName
            )
        }.sorted { lhs, rhs in
            if lhs.modifiedAt != rhs.modifiedAt { return lhs.modifiedAt > rhs.modifiedAt }
            let lhsPriority = sourcePriority(lhs.source)
            let rhsPriority = sourcePriority(rhs.source)
            if lhsPriority != rhsPriority { return lhsPriority > rhsPriority }
            return lhs.fileName < rhs.fileName
        }
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
        case .primary: 4
        case .backup: 3
        case .autosave: 1
        case .branch: 2
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
                source: source,
                branchName: envelope.branchName
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
