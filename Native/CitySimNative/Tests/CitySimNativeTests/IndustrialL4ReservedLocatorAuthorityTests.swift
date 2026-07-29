import CryptoKit
import Darwin
import Foundation
import XCTest

private enum L4ReservedDirection: String, Codable, CaseIterable {
    case east
    case south
    case west
}

private struct L4ReservedArtifact: Codable, Equatable {
    let path: String
    let sha256: String
}

private struct L4ReservedContract: Codable, Equatable {
    let path: String
    let revision: Int
    let sha256: String
}

private struct L4ReservedSourceStageSchema: Codable, Equatable {
    let path: String
    let version: Int
    let sha256: String
}

private struct L4ReservedDirectionEntry: Codable, Equatable {
    let taskId: String
    let direction: L4ReservedDirection
    let branch: String
    let evidenceRoot: String
    let packetPath: String
    let status: String
    let writer: String
    let creationPolicy: String
}

private struct L4ReservedGrants: Codable, Equatable {
    let sourceAdmission: Bool
    let rendererQuarantine: Bool
    let rendererActivation: Bool
    let productionSelection: Bool
    let shipping: Bool
}

private struct L4ReservedLocatorAuthority: Codable, Equatable {
    let schemaVersion: Int
    let documentType: String
    let family: String
    let level: Int
    let variant: Int
    let governingContract: L4ReservedContract
    let sourceStageSchema: L4ReservedSourceStageSchema
    let directions: [L4ReservedDirectionEntry]
    let grants: L4ReservedGrants
}

private struct L4ReservedLocatorReceipt: Codable, Equatable {
    let schemaVersion: Int
    let disposition: String
    let locatorAuthority: L4ReservedArtifact
    let locatorSchema: L4ReservedArtifact
    let direction: L4ReservedDirection
    let taskId: String
    let branch: String
    let evidenceRoot: String
    let reservedPacketPath: String
    let creationPolicy: String
    let sourcePacketPresent: Bool
    let sourceAdmissionGranted: Bool
    let rendererQuarantined: Bool
    let runtimeActivated: Bool
    let shippingResourcesMutated: Bool
    let productionSelected: Bool
}

private enum L4ReservedLocatorError: Error, Equatable {
    case hashMismatch(String)
    case schemaDrift(String)
    case authorityDrift(String)
    case duplicateDirection(String)
    case siblingAlias(String)
    case unsafePath(String)
    case symlinkComponent(String)
    case preexistingPacket(String)
}

private struct L4ReservedLocatorHarness {
    static let authority = L4ReservedArtifact(
        path:
            "docs/production/evidence/INTEGRATION/industrial-l04-source-candidate-packet-locators-v1.json",
        sha256:
            "a2c8daf558274bed9088b6c9ab616044e919af5b19101a01c2fe3a1b89122e65"
    )
    static let schema = L4ReservedArtifact(
        path:
            "docs/production/evidence/INTEGRATION/industrial-l04-source-candidate-packet-locators-v1.schema.json",
        sha256:
            "cb9716330593224bc5cbdae46052cff17cbb84a270ca9976c5452b8075308cbe"
    )

    static let expectedEntries: [L4ReservedDirection: L4ReservedDirectionEntry] = [
        .east: L4ReservedDirectionEntry(
            taskId: "PLAY-079",
            direction: .east,
            branch: "codex/citysim-world-art-east",
            evidenceRoot:
                "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01",
            packetPath:
                "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/SOURCE-STAGE-HANDOFF.json",
            status: "reserved",
            writer: "direction_cell",
            creationPolicy: "exclusive_no_overwrite_nofollow"
        ),
        .south: L4ReservedDirectionEntry(
            taskId: "PLAY-080",
            direction: .south,
            branch: "codex/citysim-world-art-south",
            evidenceRoot:
                "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01",
            packetPath:
                "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/SOURCE-STAGE-HANDOFF-V2.json",
            status: "reserved",
            writer: "direction_cell",
            creationPolicy: "exclusive_no_overwrite_nofollow"
        ),
        .west: L4ReservedDirectionEntry(
            taskId: "PLAY-081",
            direction: .west,
            branch: "codex/citysim-world-art-west",
            evidenceRoot:
                "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01",
            packetPath:
                "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01/SOURCE-STAGE-HANDOFF-V2.json",
            status: "reserved",
            writer: "direction_cell",
            creationPolicy: "exclusive_no_overwrite_nofollow"
        ),
    ]

    let claimedRoot: URL

    func load(
        authorityData: Data,
        schemaData: Data,
        expectedAuthorityHash: String = Self.authority.sha256,
        expectedSchemaHash: String = Self.schema.sha256
    ) throws -> L4ReservedLocatorAuthority {
        guard Self.sha256(authorityData) == expectedAuthorityHash else {
            throw L4ReservedLocatorError.hashMismatch("authority")
        }
        guard Self.sha256(schemaData) == expectedSchemaHash else {
            throw L4ReservedLocatorError.hashMismatch("schema")
        }
        try Self.validateSchemaShape(schemaData)
        try Self.validateAuthorityShape(authorityData)

        let authority: L4ReservedLocatorAuthority
        do {
            authority = try JSONDecoder().decode(
                L4ReservedLocatorAuthority.self,
                from: authorityData
            )
        } catch {
            throw L4ReservedLocatorError.schemaDrift("decode")
        }
        try Self.validateAuthoritySemantics(authority)
        return authority
    }

    func reserve(
        _ direction: L4ReservedDirection,
        from authority: L4ReservedLocatorAuthority,
        existing: [L4ReservedDirection: L4ReservedLocatorReceipt]
    ) throws -> [L4ReservedDirection: L4ReservedLocatorReceipt] {
        guard existing[direction] == nil else {
            throw L4ReservedLocatorError.duplicateDirection(direction.rawValue)
        }
        guard let entry = authority.directions.first(where: {
            $0.direction == direction
        }) else {
            throw L4ReservedLocatorError.authorityDrift(direction.rawValue)
        }
        try validateReservedPath(entry)

        var updated = existing
        updated[direction] = L4ReservedLocatorReceipt(
            schemaVersion: 1,
            disposition: "renderer_reserved_locator_nonshipping",
            locatorAuthority: Self.authority,
            locatorSchema: Self.schema,
            direction: direction,
            taskId: entry.taskId,
            branch: entry.branch,
            evidenceRoot: entry.evidenceRoot,
            reservedPacketPath: entry.packetPath,
            creationPolicy: entry.creationPolicy,
            sourcePacketPresent: false,
            sourceAdmissionGranted: false,
            rendererQuarantined: false,
            runtimeActivated: false,
            shippingResourcesMutated: false,
            productionSelected: false
        )
        return updated
    }

    static func receiptData(
        _ receipt: L4ReservedLocatorReceipt
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(receipt)
    }

    private func validateReservedPath(
        _ entry: L4ReservedDirectionEntry
    ) throws {
        guard entry.packetPath.hasPrefix(entry.evidenceRoot + "/") else {
            throw L4ReservedLocatorError.unsafePath(entry.packetPath)
        }
        let components = entry.packetPath.split(separator: "/").map(String.init)
        guard !entry.packetPath.hasPrefix("/"),
              !entry.packetPath.contains("//"),
              !components.contains(".."),
              !components.contains(".")
        else {
            throw L4ReservedLocatorError.unsafePath(entry.packetPath)
        }

        let root = claimedRoot.standardizedFileURL.resolvingSymlinksInPath()
        var current = root
        for (index, component) in components.enumerated() {
            current.appendPathComponent(component, isDirectory: false)
            var info = stat()
            if lstat(current.path, &info) == 0 {
                let kind = info.st_mode & S_IFMT
                if kind == S_IFLNK {
                    throw L4ReservedLocatorError.symlinkComponent(
                        components.prefix(index + 1).joined(separator: "/")
                    )
                }
                if index == components.count - 1 {
                    throw L4ReservedLocatorError.preexistingPacket(
                        entry.packetPath
                    )
                }
                guard kind == S_IFDIR else {
                    throw L4ReservedLocatorError.unsafePath(
                        components.prefix(index + 1).joined(separator: "/")
                    )
                }
            } else if errno != ENOENT {
                throw L4ReservedLocatorError.unsafePath(
                    components.prefix(index + 1).joined(separator: "/")
                )
            }
        }
    }

    private static func validateAuthoritySemantics(
        _ authority: L4ReservedLocatorAuthority
    ) throws {
        guard authority.schemaVersion == 1,
              authority.documentType ==
                "CITYSIM_INDUSTRIAL_L04_SOURCE_CANDIDATE_PACKET_LOCATORS",
              authority.family == "industrial",
              authority.level == 4,
              authority.variant == 0,
              authority.governingContract.path ==
                IndustrialL4DirectionPacketValidator.contract.path,
              authority.governingContract.revision ==
                IndustrialL4DirectionPacketValidator.contract.revision,
              authority.governingContract.sha256 ==
                IndustrialL4DirectionPacketValidator.contract.sha256,
              authority.sourceStageSchema.path ==
                IndustrialL4DirectionPacketValidator.sourceStage.schema.path,
              authority.sourceStageSchema.version == 2,
              authority.sourceStageSchema.sha256 ==
                IndustrialL4DirectionPacketValidator.sourceStage.schema.sha256,
              !authority.grants.sourceAdmission,
              !authority.grants.rendererQuarantine,
              !authority.grants.rendererActivation,
              !authority.grants.productionSelection,
              !authority.grants.shipping
        else {
            throw L4ReservedLocatorError.authorityDrift("topLevel")
        }
        guard authority.directions.map(\.direction) ==
                [.east, .south, .west]
        else {
            throw L4ReservedLocatorError.authorityDrift("directionOrder")
        }
        for entry in authority.directions {
            guard entry == expectedEntries[entry.direction] else {
                throw L4ReservedLocatorError.authorityDrift(
                    entry.direction.rawValue
                )
            }
        }
        guard Set(authority.directions.map(\.packetPath)).count == 3,
              Set(authority.directions.map(\.evidenceRoot)).count == 3
        else {
            throw L4ReservedLocatorError.siblingAlias("path")
        }
    }

    private static func validateSchemaShape(_ data: Data) throws {
        let root = try dictionary(data, field: "schema")
        try requireKeys(
            root,
            [
                "$schema", "$id", "title", "type", "additionalProperties",
                "required", "properties", "$defs",
            ],
            field: "schema"
        )
        guard root["additionalProperties"] as? Bool == false,
              let required = root["required"] as? [String],
              Set(required) == Set([
                  "schemaVersion", "documentType", "family", "level",
                  "variant", "governingContract", "sourceStageSchema",
                  "directions", "grants",
              ]),
              let definitions = root["$defs"] as? [String: Any],
              let directionBase =
                definitions["directionBase"] as? [String: Any],
              directionBase["additionalProperties"] as? Bool == false
        else {
            throw L4ReservedLocatorError.schemaDrift("schemaSemantics")
        }
    }

    private static func validateAuthorityShape(_ data: Data) throws {
        let root = try dictionary(data, field: "authority")
        try requireKeys(
            root,
            [
                "schemaVersion", "documentType", "family", "level", "variant",
                "governingContract", "sourceStageSchema", "directions", "grants",
            ],
            field: "authority"
        )
        guard let contract = root["governingContract"] as? [String: Any],
              let stageSchema = root["sourceStageSchema"] as? [String: Any],
              let directions = root["directions"] as? [[String: Any]],
              let grants = root["grants"] as? [String: Any]
        else {
            throw L4ReservedLocatorError.schemaDrift("nested")
        }
        try requireKeys(
            contract,
            ["path", "revision", "sha256"],
            field: "governingContract"
        )
        try requireKeys(
            stageSchema,
            ["path", "version", "sha256"],
            field: "sourceStageSchema"
        )
        guard directions.count == 3 else {
            throw L4ReservedLocatorError.schemaDrift("directions")
        }
        for direction in directions {
            try requireKeys(
                direction,
                [
                    "taskId", "direction", "branch", "evidenceRoot",
                    "packetPath", "status", "writer", "creationPolicy",
                ],
                field: "direction"
            )
        }
        try requireKeys(
            grants,
            [
                "sourceAdmission", "rendererQuarantine", "rendererActivation",
                "productionSelection", "shipping",
            ],
            field: "grants"
        )
    }

    private static func dictionary(
        _ data: Data,
        field: String
    ) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else {
            throw L4ReservedLocatorError.schemaDrift(field)
        }
        return value
    }

    private static func requireKeys(
        _ dictionary: [String: Any],
        _ expected: Set<String>,
        field: String
    ) throws {
        guard Set(dictionary.keys) == expected else {
            throw L4ReservedLocatorError.schemaDrift(field)
        }
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

final class IndustrialL4ReservedLocatorAuthorityTests: XCTestCase {
    func testPublishedSchemaAndAuthorityMapExactReservedPathsDeterministically()
        throws
    {
        let repo = try repositoryRoot()
        let harness = L4ReservedLocatorHarness(claimedRoot: repo)
        let authority = try harness.load(
            authorityData: try Data(contentsOf: repo.appendingPathComponent(
                L4ReservedLocatorHarness.authority.path
            )),
            schemaData: try Data(contentsOf: repo.appendingPathComponent(
                L4ReservedLocatorHarness.schema.path
            ))
        )
        var receipts: [L4ReservedDirection: L4ReservedLocatorReceipt] = [:]
        for direction in L4ReservedDirection.allCases {
            receipts = try harness.reserve(
                direction,
                from: authority,
                existing: receipts
            )
        }
        XCTAssertEqual(Set(receipts.keys), Set(L4ReservedDirection.allCases))
        for direction in L4ReservedDirection.allCases {
            let receipt = try XCTUnwrap(receipts[direction])
            XCTAssertEqual(
                receipt.reservedPacketPath,
                L4ReservedLocatorHarness.expectedEntries[direction]?.packetPath
            )
            XCTAssertFalse(receipt.sourcePacketPresent)
            XCTAssertFalse(receipt.sourceAdmissionGranted)
            XCTAssertFalse(receipt.rendererQuarantined)
            XCTAssertFalse(receipt.runtimeActivated)
            XCTAssertFalse(receipt.shippingResourcesMutated)
            XCTAssertFalse(receipt.productionSelected)
            XCTAssertEqual(
                try L4ReservedLocatorHarness.receiptData(receipt),
                try L4ReservedLocatorHarness.receiptData(receipt)
            )
        }
    }

    func testWrongAuthorityHashAndUnknownFieldsFailClosed() throws {
        try withSyntheticRoot { root in
            let (authorityData, schemaData) = try publishedBytes()
            let harness = L4ReservedLocatorHarness(claimedRoot: root)
            XCTAssertThrowsError(
                try harness.load(
                    authorityData: authorityData,
                    schemaData: schemaData,
                    expectedAuthorityHash: String(repeating: "0", count: 64)
                )
            ) {
                XCTAssertEqual(
                    $0 as? L4ReservedLocatorError,
                    .hashMismatch("authority")
                )
            }

            let unknown = try mutatingAuthority(authorityData) { root in
                root["unexpected"] = true
            }
            XCTAssertThrowsError(
                try harness.load(
                    authorityData: unknown,
                    schemaData: schemaData,
                    expectedAuthorityHash:
                        L4ReservedLocatorHarness.sha256(unknown)
                )
            ) {
                XCTAssertEqual(
                    $0 as? L4ReservedLocatorError,
                    .schemaDrift("authority")
                )
            }

            let wrongAuthority = try mutatingAuthority(authorityData) { root in
                var contract =
                    root["governingContract"] as? [String: Any] ?? [:]
                contract["sha256"] = String(repeating: "0", count: 64)
                root["governingContract"] = contract
            }
            XCTAssertThrowsError(
                try harness.load(
                    authorityData: wrongAuthority,
                    schemaData: schemaData,
                    expectedAuthorityHash:
                        L4ReservedLocatorHarness.sha256(wrongAuthority)
                )
            ) {
                XCTAssertEqual(
                    $0 as? L4ReservedLocatorError,
                    .authorityDrift("topLevel")
                )
            }

            let unknownNested = try mutatingDirection(
                authorityData,
                index: 0
            ) {
                $0["unexpected"] = true
            }
            XCTAssertThrowsError(
                try harness.load(
                    authorityData: unknownNested,
                    schemaData: schemaData,
                    expectedAuthorityHash:
                        L4ReservedLocatorHarness.sha256(unknownNested)
                )
            ) {
                XCTAssertEqual(
                    $0 as? L4ReservedLocatorError,
                    .schemaDrift("direction")
                )
            }
        }
    }

    func testPathDirectionAndSiblingAliasRejectWithoutChangingPassingSiblings()
        throws
    {
        try withSyntheticRoot { root in
            let (authorityData, schemaData) = try publishedBytes()
            let harness = L4ReservedLocatorHarness(claimedRoot: root)
            let authority = try harness.load(
                authorityData: authorityData,
                schemaData: schemaData
            )
            let accepted = try harness.reserve(
                .east,
                from: authority,
                existing: [:]
            )

            let mutations: [(Data) throws -> Data] = [
                { data in
                    try self.mutatingDirection(data, index: 1) {
                        $0["packetPath"] =
                            "docs/production/evidence/PLAY-080/wrong.json"
                    }
                },
                { data in
                    try self.mutatingDirection(data, index: 1) {
                        $0["direction"] = "west"
                    }
                },
                { data in
                    try self.mutatingDirection(data, index: 1) { direction in
                        direction["packetPath"] =
                            L4ReservedLocatorHarness.expectedEntries[.east]?
                            .packetPath
                        direction["evidenceRoot"] =
                            L4ReservedLocatorHarness.expectedEntries[.east]?
                            .evidenceRoot
                    }
                },
            ]
            for mutation in mutations {
                let changed = try mutation(authorityData)
                XCTAssertThrowsError(
                    try harness.load(
                        authorityData: changed,
                        schemaData: schemaData,
                        expectedAuthorityHash:
                            L4ReservedLocatorHarness.sha256(changed)
                    )
                )
                XCTAssertEqual(Set(accepted.keys), [.east])
                XCTAssertEqual(
                    accepted[.east]?.reservedPacketPath,
                    L4ReservedLocatorHarness.expectedEntries[.east]?.packetPath
                )
            }
        }
    }

    func testSymlinkAndPreexistingPacketRejectPerDirectionWithoutSiblingLoss()
        throws
    {
        let (authorityData, schemaData) = try publishedBytes()
        for direction in L4ReservedDirection.allCases {
            try withSyntheticRoot { root in
                let harness = L4ReservedLocatorHarness(claimedRoot: root)
                let authority = try harness.load(
                    authorityData: authorityData,
                    schemaData: schemaData
                )
                var accepted: [L4ReservedDirection: L4ReservedLocatorReceipt] =
                    [:]
                for sibling in L4ReservedDirection.allCases
                    where sibling != direction
                {
                    accepted = try harness.reserve(
                        sibling,
                        from: authority,
                        existing: accepted
                    )
                }
                let snapshot = accepted
                let packetPath = try XCTUnwrap(
                    L4ReservedLocatorHarness.expectedEntries[direction]?.packetPath
                )
                let packetURL = root.appendingPathComponent(packetPath)
                try FileManager.default.createDirectory(
                    at: packetURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let external = root.deletingLastPathComponent()
                    .appendingPathComponent(UUID().uuidString + ".json")
                try FileManager.default.createSymbolicLink(
                    at: packetURL,
                    withDestinationURL: external
                )
                XCTAssertThrowsError(
                    try harness.reserve(
                        direction,
                        from: authority,
                        existing: accepted
                    )
                ) {
                    guard case .some(.symlinkComponent) =
                        $0 as? L4ReservedLocatorError
                    else {
                        return XCTFail("Expected symlink rejection, got \($0)")
                    }
                }
                XCTAssertEqual(accepted, snapshot)
            }

            try withSyntheticRoot { root in
                let harness = L4ReservedLocatorHarness(claimedRoot: root)
                let authority = try harness.load(
                    authorityData: authorityData,
                    schemaData: schemaData
                )
                var accepted: [L4ReservedDirection: L4ReservedLocatorReceipt] =
                    [:]
                for sibling in L4ReservedDirection.allCases
                    where sibling != direction
                {
                    accepted = try harness.reserve(
                        sibling,
                        from: authority,
                        existing: accepted
                    )
                }
                let snapshot = accepted
                let packetPath = try XCTUnwrap(
                    L4ReservedLocatorHarness.expectedEntries[direction]?.packetPath
                )
                let packetURL = root.appendingPathComponent(packetPath)
                try FileManager.default.createDirectory(
                    at: packetURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                XCTAssertTrue(
                    FileManager.default.createFile(
                        atPath: packetURL.path,
                        contents: Data("synthetic".utf8)
                    )
                )
                XCTAssertThrowsError(
                    try harness.reserve(
                        direction,
                        from: authority,
                        existing: accepted
                    )
                ) {
                    XCTAssertEqual(
                        $0 as? L4ReservedLocatorError,
                        .preexistingPacket(packetPath)
                    )
                }
                XCTAssertEqual(accepted, snapshot)
            }
        }
    }

    private func repositoryRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            candidate.deleteLastPathComponent()
            if FileManager.default.fileExists(
                atPath: candidate.appendingPathComponent(".git").path
            ) {
                return candidate
            }
        }
        throw L4ReservedLocatorError.unsafePath("repositoryRoot")
    }

    private func publishedBytes() throws -> (Data, Data) {
        let repo = try repositoryRoot()
        return (
            try Data(contentsOf: repo.appendingPathComponent(
                L4ReservedLocatorHarness.authority.path
            )),
            try Data(contentsOf: repo.appendingPathComponent(
                L4ReservedLocatorHarness.schema.path
            ))
        )
    }

    private func withSyntheticRoot(
        _ body: (URL) throws -> Void
    ) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "play073-l4-reserved-locators-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        try body(root)
    }

    private func mutatingAuthority(
        _ data: Data,
        mutation: (inout [String: Any]) -> Void
    ) throws -> Data {
        var root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        mutation(&root)
        return try JSONSerialization.data(
            withJSONObject: root,
            options: [.sortedKeys]
        )
    }

    private func mutatingDirection(
        _ data: Data,
        index: Int,
        mutation: (inout [String: Any]) -> Void
    ) throws -> Data {
        try mutatingAuthority(data) { root in
            var directions = root["directions"] as? [[String: Any]] ?? []
            var direction = directions[index]
            mutation(&direction)
            directions[index] = direction
            root["directions"] = directions
        }
    }
}
