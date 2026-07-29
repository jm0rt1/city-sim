import CryptoKit
import Darwin
import Foundation
import XCTest

private enum L4V2Direction: String, Codable, CaseIterable, Hashable {
    case north
    case east
    case south
    case west
}

private struct L4V2Artifact: Codable, Equatable {
    let path: String
    let sha256: String
}

private struct L4V2WorkerState: Codable, Equatable {
    let stage: String
    let candidateReadyForIndependentReview: Bool
    let sourceReady: Bool
    let integrationAdmitted: Bool
    let rendererQuarantined: Bool
    let productionSelected: Bool
}

private struct L4V2SourceStage: Codable, Equatable {
    let schema: L4V2Artifact
    let semanticValidator: L4V2Artifact
    let canonicalDecoder: L4V2Artifact
    let nonAliasLoader: L4V2Artifact
}

private struct L4V2Source: Codable, Equatable {
    let contentCommit: String
    let sourceKey: String
    let decodedRgbaSha256: String
    let fallbackSourceKey: String?
}

private struct L4V2LOD: Codable, Equatable {
    let detail: String
    let normalizedRgbaSha256: String
    let atlasSlot: String
    let canvasPixels: [Int]
}

private struct L4V2Registration: Codable, Equatable {
    let footprintTiles: [Int]
    let canvasPixels: [Int]
    let groundPivotSource: [Int]
    let frontageSocketSource: [Int]
    let frontageEdge: String
    let occupiedBounds: [Int]
}

private struct L4V2FixturePreparation: Codable, Equatable {
    let fixtureCoordinate: [Int]
    let soleRoadCoordinate: [Int]
    let expectedFrontage: String
    let cityCameraScale: Double
    let neighborhoodCameraScale: Double
    let blockCameraScale: Double
}

private struct L4V2DirectionPacket: Codable, Equatable {
    let schemaVersion: Int
    let family: String
    let level: Int
    let variant: Int
    let direction: L4V2Direction
    let logicalID: String
    let sourceStage: L4V2SourceStage
    let workerState: L4V2WorkerState
    let source: L4V2Source
    let lods: [L4V2LOD]
    let registration: L4V2Registration
    let d4Fingerprints: [String: String]
    let fixturePreparation: L4V2FixturePreparation
    let productionSelected: Bool
}

private struct L4V2SourceAdmission: Codable, Equatable {
    let schemaVersion: Int
    let disposition: String
    let integrationCommit: String
    let direction: L4V2Direction
    let logicalID: String
    let workerPacket: L4V2Artifact
    let contentCommit: String
    let decodedRgbaSha256: String
    let semanticValidator: L4V2Artifact
    let semanticValidationResult: String
    let independentTechnicalDisposition: String
    let literalScaleDisposition: String
    let rendererQuarantined: Bool
    let productionSelected: Bool
}

private struct L4V2RendererQuarantineReceipt: Codable, Equatable {
    let schemaVersion: Int
    let disposition: String
    let direction: L4V2Direction
    let logicalID: String
    let workerPacketSha256: String
    let sourceAdmissionSha256: String
    let rendererQuarantined: Bool
    let readyForAtomicAssembly: Bool
    let productionSelected: Bool
    let runtimeMappingMutated: Bool
    let shippingResourcesMutated: Bool
}

private struct L4V2AdmittedPacket: Equatable {
    let packet: L4V2DirectionPacket
    let packetSha256: String
    let admission: L4V2SourceAdmission
    let admissionSha256: String
    let receipt: L4V2RendererQuarantineReceipt
}

private enum L4V2Status: String, Equatable {
    case inactive
    case quarantinedIncomplete = "quarantined_incomplete"
    case readyForAtomicAssembly = "ready_for_atomic_assembly"
}

private struct L4V2BatchResult: Equatable {
    let status: L4V2Status
    let directions: [L4V2Direction]
    let lodIdentityCount: Int
    let d4IdentityCount: Int
    let fixtureCount: Int
    let runtimeActivated: Bool
}

private enum L4V2HarnessError: Error, Equatable {
    case missingFile(String)
    case outsideClaimedRoot(String)
    case invalidPathType(String)
    case hashMismatch
    case schemaDrift
    case invalidField(String)
    case sourceStageDrift
    case workerSelfAdmission
    case missingAdmission
    case admissionDrift(String)
    case fallbackReference
    case registrationDrift
    case alias(String)
    case transformedSibling
    case incompleteDirections
}

private struct L4V2FileInput {
    let packetURL: URL
    let packetSha256: String
    let admissionURL: URL?
    let admissionSha256: String?
}

private struct L4V2SourceAdmissionHarness {
    static let sourceStage = L4V2SourceStage(
        schema: L4V2Artifact(
            path:
                "docs/production/evidence/INTEGRATION/industrial-l04-source-stage-handoff-schema-v2.json",
            sha256:
                "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7"
        ),
        semanticValidator: L4V2Artifact(
            path:
                "Native/CitySimNative/WorldArt/Shared/validate_source_stage_handoff_v2.py",
            sha256:
                "7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340"
        ),
        canonicalDecoder: L4V2Artifact(
            path:
                "Native/CitySimNative/WorldArt/Shared/canonical_rgba_v1.swift",
            sha256:
                "2be2b57d0c9bb73e8a4438c69aa4230eba08c4b87937fae4d4e048244b9beaab"
        ),
        nonAliasLoader: L4V2Artifact(
            path:
                "Native/CitySimNative/WorldArt/Shared/accepted_master_non_alias_v1.py",
            sha256:
                "2c44bc3a4ffe3fdfc68a477b70f3af9478122e9b796543f32a154859ac300a39"
        )
    )

    let claimedRoot: URL

    private var canonicalClaimedRoot: URL {
        claimedRoot.standardizedFileURL.resolvingSymlinksInPath()
    }

    func inspect(_ input: L4V2FileInput) throws -> L4V2AdmittedPacket {
        let packetData = try read(
            input.packetURL,
            expectedSha256: input.packetSha256
        )
        try Self.validatePacketShape(packetData)
        let packet = try JSONDecoder().decode(
            L4V2DirectionPacket.self,
            from: packetData
        )
        try Self.validate(packet)

        guard let admissionURL = input.admissionURL,
              let admissionSha256 = input.admissionSha256
        else {
            throw L4V2HarnessError.missingAdmission
        }
        let admissionData = try read(
            admissionURL,
            expectedSha256: admissionSha256
        )
        try Self.validateAdmissionShape(admissionData)
        let admission = try JSONDecoder().decode(
            L4V2SourceAdmission.self,
            from: admissionData
        )
        try Self.validateAdmission(
            admission,
            packet: packet,
            packetPath: try relativePath(input.packetURL),
            packetSha256: input.packetSha256
        )
        return L4V2AdmittedPacket(
            packet: packet,
            packetSha256: input.packetSha256,
            admission: admission,
            admissionSha256: admissionSha256,
            receipt: L4V2RendererQuarantineReceipt(
                schemaVersion: 1,
                disposition: "renderer_quarantined_nonshipping",
                direction: packet.direction,
                logicalID: packet.logicalID,
                workerPacketSha256: input.packetSha256,
                sourceAdmissionSha256: admissionSha256,
                rendererQuarantined: true,
                readyForAtomicAssembly: false,
                productionSelected: false,
                runtimeMappingMutated: false,
                shippingResourcesMutated: false
            )
        )
    }

    static func join(_ admitted: [L4V2AdmittedPacket]) throws -> L4V2BatchResult {
        let packets = admitted.map(\.packet)
        let directions = packets.map(\.direction)
        guard Set(directions).count == directions.count else {
            throw L4V2HarnessError.alias("direction")
        }
        try unique(packets.map(\.logicalID), "logicalID")
        try unique(packets.map(\.source.sourceKey), "sourceKey")
        try unique(packets.map(\.source.decodedRgbaSha256), "decodedRgba")
        try unique(
            packets.flatMap { $0.lods.map(\.normalizedRgbaSha256) },
            "lod"
        )
        for packet in packets {
            let transformed = Set(
                packet.d4Fingerprints
                    .filter { $0.key != "identity" }
                    .map { $0.value }
            )
            for sibling in packets where sibling.direction != packet.direction {
                if transformed.contains(sibling.source.decodedRgbaSha256) {
                    throw L4V2HarnessError.transformedSibling
                }
            }
        }
        try unique(
            packets.flatMap { Array($0.d4Fingerprints.values) },
            "d4"
        )

        let ordered = L4V2Direction.allCases.filter(directions.contains)
        let status: L4V2Status
        switch ordered.count {
        case 0:
            status = .inactive
        case 4:
            status = .readyForAtomicAssembly
        default:
            status = .quarantinedIncomplete
        }
        return L4V2BatchResult(
            status: status,
            directions: ordered,
            lodIdentityCount: packets.flatMap(\.lods).count,
            d4IdentityCount:
                packets.flatMap { Array($0.d4Fingerprints.values) }.count,
            fixtureCount: packets.count,
            runtimeActivated: false
        )
    }

    static func requireReady(
        _ admitted: [L4V2AdmittedPacket]
    ) throws -> L4V2BatchResult {
        let result = try join(admitted)
        guard result.status == .readyForAtomicAssembly else {
            throw L4V2HarnessError.incompleteDirections
        }
        return result
    }

    func writeReceipt(
        _ receipt: L4V2RendererQuarantineReceipt,
        to outputURL: URL
    ) throws -> (url: URL, data: Data) {
        let canonicalOutput = try validatedPath(
            outputURL,
            use: .outputFile
        )
        let evidenceRoot = canonicalURLForContainment(
            canonicalClaimedRoot.appending(
                path: "docs/production/evidence/PLAY-073"
            )
        )
        guard canonicalOutput.path.hasPrefix(evidenceRoot.path + "/") else {
            throw L4V2HarnessError.outsideClaimedRoot(
                canonicalOutput.path
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let receiptData = try encoder.encode(receipt)
        try FileManager.default.createDirectory(
            at: canonicalOutput.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: canonicalOutput.path) {
            guard try Data(contentsOf: canonicalOutput) == receiptData else {
                throw L4V2HarnessError.hashMismatch
            }
        } else {
            try receiptData.write(to: canonicalOutput)
        }
        return (canonicalOutput, receiptData)
    }

    private func read(_ url: URL, expectedSha256: String) throws -> Data {
        let canonicalURL = try validatedPath(url, use: .inputFile)
        let data = try Data(contentsOf: canonicalURL)
        guard Self.sha256(data) == expectedSha256 else {
            throw L4V2HarnessError.hashMismatch
        }
        return data
    }

    private func relativePath(_ url: URL) throws -> String {
        let root = canonicalClaimedRoot.path
        let path = try validatedPath(url, use: .inputFile).path
        guard path.hasPrefix(root + "/") else {
            throw L4V2HarnessError.outsideClaimedRoot(path)
        }
        return String(path.dropFirst(root.count + 1))
    }

    private enum PathUse: Equatable {
        case inputFile
        case outputFile
    }

    private func validatedPath(
        _ url: URL,
        use: PathUse
    ) throws -> URL {
        let root = canonicalClaimedRoot
        let lexicalURL = url.standardizedFileURL
        guard lexicalURL.path.hasPrefix(root.path + "/") else {
            throw L4V2HarnessError.outsideClaimedRoot(lexicalURL.path)
        }

        let relativePath = lexicalURL.path.dropFirst(root.path.count + 1)
        let components = relativePath.split(separator: "/")
        guard !components.isEmpty else {
            throw L4V2HarnessError.invalidPathType(lexicalURL.path)
        }

        var componentURL = root
        var missingComponentSeen = false
        for (index, component) in components.enumerated() {
            componentURL.append(path: String(component))
            guard !missingComponentSeen else {
                continue
            }

            var metadata = stat()
            let result = componentURL.path.withCString {
                lstat($0, &metadata)
            }
            if result == 0 {
                let fileType = metadata.st_mode & S_IFMT
                guard fileType != S_IFLNK else {
                    throw L4V2HarnessError.outsideClaimedRoot(
                        componentURL.path
                    )
                }
                let isFinal = index == components.count - 1
                if isFinal {
                    guard fileType == S_IFREG else {
                        throw L4V2HarnessError.invalidPathType(
                            componentURL.path
                        )
                    }
                } else {
                    guard fileType == S_IFDIR else {
                        throw L4V2HarnessError.invalidPathType(
                            componentURL.path
                        )
                    }
                }
            } else if errno == ENOENT {
                guard use == .outputFile else {
                    throw L4V2HarnessError.missingFile(
                        componentURL.lastPathComponent
                    )
                }
                missingComponentSeen = true
            } else {
                throw L4V2HarnessError.invalidPathType(componentURL.path)
            }
        }

        let canonicalURL = canonicalURLForContainment(lexicalURL)
        guard canonicalURL.path.hasPrefix(root.path + "/") else {
            throw L4V2HarnessError.outsideClaimedRoot(canonicalURL.path)
        }
        return canonicalURL
    }

    private func canonicalURLForContainment(_ url: URL) -> URL {
        var existingAncestor = url.standardizedFileURL
        var unresolvedComponents: [String] = []
        while !FileManager.default.fileExists(
            atPath: existingAncestor.path
        ) {
            let parent = existingAncestor.deletingLastPathComponent()
            guard parent.path != existingAncestor.path else {
                break
            }
            unresolvedComponents.insert(
                existingAncestor.lastPathComponent,
                at: 0
            )
            existingAncestor = parent
        }
        var canonicalURL = existingAncestor.resolvingSymlinksInPath()
        for component in unresolvedComponents {
            canonicalURL.append(path: component)
        }
        return canonicalURL.standardizedFileURL
    }

    private static func validate(_ packet: L4V2DirectionPacket) throws {
        guard packet.schemaVersion == 2,
              packet.family == "industrial",
              packet.level == 4,
              packet.variant == 0,
              packet.logicalID ==
                "industrial_l04_v0_\(packet.direction.rawValue)"
        else {
            throw L4V2HarnessError.invalidField("identity")
        }
        guard packet.sourceStage == sourceStage else {
            throw L4V2HarnessError.sourceStageDrift
        }
        guard packet.workerState.stage == "source_candidate",
              packet.workerState.candidateReadyForIndependentReview
        else {
            throw L4V2HarnessError.invalidField("workerState")
        }
        guard !packet.workerState.sourceReady,
              !packet.workerState.integrationAdmitted,
              !packet.workerState.rendererQuarantined,
              !packet.workerState.productionSelected,
              !packet.productionSelected
        else {
            throw L4V2HarnessError.workerSelfAdmission
        }
        guard packet.source.fallbackSourceKey == nil else {
            throw L4V2HarnessError.fallbackReference
        }
        try validateHash(packet.source.decodedRgbaSha256)
        try validateCommit(packet.source.contentCommit)

        let expectedLOD: [String: [Int]] = [
            "city": [256, 171],
            "neighborhood": [512, 342],
            "block": [1024, 683],
        ]
        guard packet.lods.count == 3,
              Set(packet.lods.map(\.detail)) == Set(expectedLOD.keys),
              Set(packet.lods.map(\.normalizedRgbaSha256)).count == 3,
              Set(packet.lods.map(\.atlasSlot)).count == 3
        else {
            throw L4V2HarnessError.invalidField("lods")
        }
        for lod in packet.lods {
            guard lod.canvasPixels == expectedLOD[lod.detail],
                  lod.atlasSlot ==
                    "\(packet.logicalID)/\(lod.detail)"
            else {
                throw L4V2HarnessError.invalidField("lod")
            }
            try validateHash(lod.normalizedRgbaSha256)
        }

        let sockets: [L4V2Direction: [Int]] = [
            .north: [896, 704],
            .east: [896, 832],
            .south: [640, 832],
            .west: [640, 704],
        ]
        guard packet.registration.footprintTiles == [1, 1],
              packet.registration.canvasPixels == [1536, 1024],
              packet.registration.groundPivotSource == [768, 896],
              packet.registration.frontageSocketSource ==
                sockets[packet.direction],
              packet.registration.frontageEdge == packet.direction.rawValue,
              packet.registration.occupiedBounds.count == 4,
              packet.registration.occupiedBounds[0] >= 0,
              packet.registration.occupiedBounds[1] >= 0,
              packet.registration.occupiedBounds[2] <= 1536,
              packet.registration.occupiedBounds[3] <= 1024
        else {
            throw L4V2HarnessError.registrationDrift
        }
        guard packet.d4Fingerprints.count == 8,
              packet.d4Fingerprints["identity"] ==
                packet.source.decodedRgbaSha256,
              Set(packet.d4Fingerprints.values).count == 8
        else {
            throw L4V2HarnessError.invalidField("d4Fingerprints")
        }
        for hash in packet.d4Fingerprints.values {
            try validateHash(hash)
        }
        guard packet.fixturePreparation.expectedFrontage ==
                packet.direction.rawValue,
              packet.fixturePreparation.fixtureCoordinate.count == 2,
              packet.fixturePreparation.soleRoadCoordinate.count == 2,
              packet.fixturePreparation.cityCameraScale > 0,
              packet.fixturePreparation.neighborhoodCameraScale > 0,
              packet.fixturePreparation.blockCameraScale > 0
        else {
            throw L4V2HarnessError.invalidField("fixturePreparation")
        }
    }

    private static func validateAdmission(
        _ admission: L4V2SourceAdmission,
        packet: L4V2DirectionPacket,
        packetPath: String,
        packetSha256: String
    ) throws {
        guard admission.schemaVersion == 1,
              admission.disposition == "integration_source_admitted"
        else {
            throw L4V2HarnessError.admissionDrift("disposition")
        }
        guard admission.direction == packet.direction,
              admission.logicalID == packet.logicalID,
              admission.workerPacket ==
                L4V2Artifact(path: packetPath, sha256: packetSha256),
              admission.contentCommit == packet.source.contentCommit,
              admission.decodedRgbaSha256 ==
                packet.source.decodedRgbaSha256,
              admission.semanticValidator ==
                packet.sourceStage.semanticValidator
        else {
            throw L4V2HarnessError.admissionDrift("candidateBinding")
        }
        guard admission.semanticValidationResult == "PASS",
              admission.independentTechnicalDisposition == "ACCEPT",
              admission.literalScaleDisposition == "ACCEPT"
        else {
            throw L4V2HarnessError.admissionDrift("independentDisposition")
        }
        guard !admission.rendererQuarantined,
              !admission.productionSelected
        else {
            throw L4V2HarnessError.admissionDrift("authorityBoundary")
        }
        try validateCommit(admission.integrationCommit)
    }

    private static func validatePacketShape(_ data: Data) throws {
        let root = try object(data)
        try exactKeys(
            root,
            [
                "schemaVersion", "family", "level", "variant", "direction",
                "logicalID", "sourceStage", "workerState", "source", "lods",
                "registration", "d4Fingerprints", "fixturePreparation",
                "productionSelected",
            ]
        )
        try exactKeys(
            child(root, "sourceStage"),
            [
                "schema", "semanticValidator", "canonicalDecoder",
                "nonAliasLoader",
            ]
        )
        for key in [
            "schema", "semanticValidator", "canonicalDecoder", "nonAliasLoader",
        ] {
            try exactKeys(child(child(root, "sourceStage"), key), ["path", "sha256"])
        }
        try exactKeys(
            child(root, "workerState"),
            [
                "stage", "candidateReadyForIndependentReview", "sourceReady",
                "integrationAdmitted", "rendererQuarantined",
                "productionSelected",
            ]
        )
        try allowedKeys(
            child(root, "source"),
            [
                "contentCommit", "sourceKey", "decodedRgbaSha256",
                "fallbackSourceKey",
            ],
            required: [
                "contentCommit", "sourceKey", "decodedRgbaSha256",
            ]
        )
        try exactKeys(
            child(root, "registration"),
            [
                "footprintTiles", "canvasPixels", "groundPivotSource",
                "frontageSocketSource", "frontageEdge", "occupiedBounds",
            ]
        )
        try exactKeys(
            child(root, "fixturePreparation"),
            [
                "fixtureCoordinate", "soleRoadCoordinate", "expectedFrontage",
                "cityCameraScale", "neighborhoodCameraScale",
                "blockCameraScale",
            ]
        )
        guard let lods = root["lods"] as? [[String: Any]], lods.count == 3 else {
            throw L4V2HarnessError.schemaDrift
        }
        for lod in lods {
            try exactKeys(
                lod,
                ["detail", "normalizedRgbaSha256", "atlasSlot", "canvasPixels"]
            )
        }
        let d4 = try child(root, "d4Fingerprints")
        try exactKeys(
            d4,
            [
                "identity", "rotate90", "rotate180", "rotate270", "mirrorX",
                "mirrorY", "mirrorDiagonal", "mirrorAntiDiagonal",
            ]
        )
    }

    private static func validateAdmissionShape(_ data: Data) throws {
        let root = try object(data)
        try exactKeys(
            root,
            [
                "schemaVersion", "disposition", "integrationCommit",
                "direction", "logicalID", "workerPacket", "contentCommit",
                "decodedRgbaSha256", "semanticValidator",
                "semanticValidationResult", "independentTechnicalDisposition",
                "literalScaleDisposition", "rendererQuarantined",
                "productionSelected",
            ]
        )
        try exactKeys(child(root, "workerPacket"), ["path", "sha256"])
        try exactKeys(child(root, "semanticValidator"), ["path", "sha256"])
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        else {
            throw L4V2HarnessError.schemaDrift
        }
        return object
    }

    private static func child(
        _ object: [String: Any],
        _ key: String
    ) throws -> [String: Any] {
        guard let child = object[key] as? [String: Any] else {
            throw L4V2HarnessError.schemaDrift
        }
        return child
    }

    private static func exactKeys(
        _ object: [String: Any],
        _ expected: Set<String>
    ) throws {
        guard Set(object.keys) == expected else {
            throw L4V2HarnessError.schemaDrift
        }
    }

    private static func allowedKeys(
        _ object: [String: Any],
        _ allowed: Set<String>,
        required: Set<String>
    ) throws {
        let keys = Set(object.keys)
        guard keys.isSubset(of: allowed), required.isSubset(of: keys) else {
            throw L4V2HarnessError.schemaDrift
        }
    }

    private static func unique(_ values: [String], _ field: String) throws {
        guard Set(values).count == values.count else {
            throw L4V2HarnessError.alias(field)
        }
    }

    private static func validateHash(_ value: String) throws {
        guard value.count == 64, value.allSatisfy(\.isLowercaseHexDigit) else {
            throw L4V2HarnessError.invalidField("sha256")
        }
    }

    private static func validateCommit(_ value: String) throws {
        guard value.count == 40, value.allSatisfy(\.isLowercaseHexDigit) else {
            throw L4V2HarnessError.invalidField("commit")
        }
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct L4V2AcceptedBaseline: Codable, Equatable {
    let commit: String
    let catalog: L4V2Artifact
    let industrialL3Manifest: L4V2Artifact
}

private struct L4V2AssemblyLocators: Codable, Equatable {
    let raw: L4V2Artifact
    let provenance: L4V2Artifact
    let normalization: L4V2Artifact
    let descriptor: L4V2Artifact
    let contact: L4V2Artifact
    let review: L4V2Artifact

    var ordered: [L4V2Artifact] {
        [raw, provenance, normalization, descriptor, contact, review]
    }
}

private struct L4V2AssemblyDirectionInput: Codable, Equatable {
    let direction: L4V2Direction
    let packet: L4V2Artifact
    let sourceAdmission: L4V2Artifact
    let quarantineReceipt: L4V2Artifact
    let locators: L4V2AssemblyLocators
}

private struct L4V2AssemblyInputManifest: Codable, Equatable {
    let schemaVersion: Int
    let disposition: String
    let acceptedL3Baseline: L4V2AcceptedBaseline
    let directions: [L4V2AssemblyDirectionInput]
    let runtimeActivated: Bool
    let shippingResourcesMutated: Bool
    let productionSelected: Bool
}

private struct L4V2AtomicDirectionLedger: Codable, Equatable {
    let direction: L4V2Direction
    let logicalID: String
    let packetSha256: String
    let sourceAdmissionSha256: String
    let quarantineReceiptSha256: String
    let decodedRgbaSha256: String
    let lodRgbaSha256: [String]
    let d4Fingerprints: [String: String]
    let locators: L4V2AssemblyLocators
}

private struct L4V2AtomicAdmissionLedger: Codable, Equatable {
    let schemaVersion: Int
    let disposition: String
    let assemblyInputManifestSha256: String
    let acceptedL3Baseline: L4V2AcceptedBaseline
    let directions: [L4V2AtomicDirectionLedger]
    let lodIdentityCount: Int
    let d4IdentityCount: Int
    let runtimeActivated: Bool
    let shippingResourcesMutated: Bool
    let productionSelected: Bool
}

private struct L4V2AtomicAssemblyHarness {
    let claimedRoot: URL

    private var canonicalClaimedRoot: URL {
        canonicalURLForContainment(claimedRoot)
    }

    func assemble(
        manifestURL: URL,
        manifestSha256: String
    ) throws -> L4V2AtomicAdmissionLedger {
        let manifestData = try read(
            manifestURL,
            expectedSha256: manifestSha256
        )
        try Self.validateManifestShape(manifestData)
        let manifest = try JSONDecoder().decode(
            L4V2AssemblyInputManifest.self,
            from: manifestData
        )
        guard manifest.schemaVersion == 1,
              manifest.disposition ==
                "integration_assembly_input_admitted",
              !manifest.runtimeActivated,
              !manifest.shippingResourcesMutated,
              !manifest.productionSelected
        else {
            throw L4V2HarnessError.invalidField("assemblyManifest")
        }
        try validateCommit(manifest.acceptedL3Baseline.commit)
        _ = try read(manifest.acceptedL3Baseline.catalog)
        _ = try read(manifest.acceptedL3Baseline.industrialL3Manifest)

        guard manifest.directions.count == 4,
              Set(manifest.directions.map(\.direction)) ==
                Set(L4V2Direction.allCases)
        else {
            throw L4V2HarnessError.incompleteDirections
        }

        let directionHarness = L4V2SourceAdmissionHarness(
            claimedRoot: canonicalClaimedRoot
        )
        var admitted: [L4V2AdmittedPacket] = []
        var ledgerDirections: [L4V2AtomicDirectionLedger] = []
        var locatorPaths: [String] = []
        var locatorHashes: [String] = []

        for direction in L4V2Direction.allCases {
            let input = try XCTUnwrap(
                manifest.directions.first { $0.direction == direction }
            )
            let admittedPacket = try directionHarness.inspect(
                L4V2FileInput(
                    packetURL: try url(for: input.packet.path),
                    packetSha256: input.packet.sha256,
                    admissionURL: try url(for: input.sourceAdmission.path),
                    admissionSha256: input.sourceAdmission.sha256
                )
            )
            let receiptData = try read(input.quarantineReceipt)
            try Self.validateReceiptShape(receiptData)
            let receipt = try JSONDecoder().decode(
                L4V2RendererQuarantineReceipt.self,
                from: receiptData
            )
            guard receipt == admittedPacket.receipt else {
                throw L4V2HarnessError.invalidField("quarantineReceipt")
            }
            for locator in input.locators.ordered {
                _ = try read(locator)
                locatorPaths.append(locator.path)
                locatorHashes.append(locator.sha256)
            }
            admitted.append(admittedPacket)
            ledgerDirections.append(
                L4V2AtomicDirectionLedger(
                    direction: direction,
                    logicalID: admittedPacket.packet.logicalID,
                    packetSha256: admittedPacket.packetSha256,
                    sourceAdmissionSha256:
                        admittedPacket.admissionSha256,
                    quarantineReceiptSha256:
                        input.quarantineReceipt.sha256,
                    decodedRgbaSha256:
                        admittedPacket.packet.source.decodedRgbaSha256,
                    lodRgbaSha256: admittedPacket.packet.lods
                        .sorted { $0.detail < $1.detail }
                        .map(\.normalizedRgbaSha256),
                    d4Fingerprints:
                        admittedPacket.packet.d4Fingerprints,
                    locators: input.locators
                )
            )
        }
        guard Set(locatorPaths).count == locatorPaths.count else {
            throw L4V2HarnessError.alias("locatorPath")
        }
        guard Set(locatorHashes).count == locatorHashes.count else {
            throw L4V2HarnessError.alias("locatorSha256")
        }

        let ready = try L4V2SourceAdmissionHarness.requireReady(admitted)
        return L4V2AtomicAdmissionLedger(
            schemaVersion: 1,
            disposition: "ready_for_atomic_assembly_nonshipping",
            assemblyInputManifestSha256: manifestSha256,
            acceptedL3Baseline: manifest.acceptedL3Baseline,
            directions: ledgerDirections,
            lodIdentityCount: ready.lodIdentityCount,
            d4IdentityCount: ready.d4IdentityCount,
            runtimeActivated: false,
            shippingResourcesMutated: false,
            productionSelected: false
        )
    }

    private func read(_ artifact: L4V2Artifact) throws -> Data {
        try read(
            try url(for: artifact.path),
            expectedSha256: artifact.sha256
        )
    }

    private func read(
        _ url: URL,
        expectedSha256: String
    ) throws -> Data {
        let canonicalURL = try containedURL(url)
        let path = canonicalURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            throw L4V2HarnessError.missingFile(
                canonicalURL.lastPathComponent
            )
        }
        let data = try Data(contentsOf: canonicalURL)
        guard L4V2SourceAdmissionHarness.sha256(data) ==
                expectedSha256
        else {
            throw L4V2HarnessError.hashMismatch
        }
        return data
    }

    private func url(for path: String) throws -> URL {
        guard !path.hasPrefix("/"),
              !path.split(separator: "/").contains("..")
        else {
            throw L4V2HarnessError.outsideClaimedRoot(path)
        }
        return try containedURL(
            canonicalClaimedRoot.appending(path: path)
        )
    }

    func canonicalEvidenceOutputURL(_ outputURL: URL) throws -> URL {
        try rejectSymlinkComponents(in: outputURL)
        let evidenceRoot = try containedURL(
            canonicalClaimedRoot.appending(
                path: "docs/production/evidence/PLAY-073"
            )
        )
        let canonicalOutput = try containedURL(outputURL)
        guard canonicalOutput.path.hasPrefix(evidenceRoot.path + "/") else {
            throw L4V2HarnessError.outsideClaimedRoot(
                canonicalOutput.path
            )
        }
        return canonicalOutput
    }

    private func rejectSymlinkComponents(in outputURL: URL) throws {
        let root = canonicalClaimedRoot
        let output = outputURL.standardizedFileURL
        guard output.path.hasPrefix(root.path + "/") else {
            throw L4V2HarnessError.outsideClaimedRoot(output.path)
        }
        let relativePath = output.path.dropFirst(root.path.count + 1)
        var componentURL = root
        for component in relativePath.split(separator: "/") {
            componentURL.append(path: String(component))
            var metadata = stat()
            let result = componentURL.path.withCString {
                lstat($0, &metadata)
            }
            if result == 0 {
                guard (metadata.st_mode & S_IFMT) != S_IFLNK else {
                    throw L4V2HarnessError.outsideClaimedRoot(
                        componentURL.path
                    )
                }
            } else if errno != ENOENT {
                throw L4V2HarnessError.outsideClaimedRoot(
                    componentURL.path
                )
            }
        }
    }

    private func containedURL(_ url: URL) throws -> URL {
        let root = canonicalClaimedRoot
        let canonicalURL = canonicalURLForContainment(url)
        let path = canonicalURL.path
        guard path.hasPrefix(root.path + "/") else {
            throw L4V2HarnessError.outsideClaimedRoot(path)
        }
        return canonicalURL
    }

    private func canonicalURLForContainment(_ url: URL) -> URL {
        var existingAncestor = url.standardizedFileURL
        var unresolvedComponents: [String] = []
        while !FileManager.default.fileExists(
            atPath: existingAncestor.path
        ) {
            let parent = existingAncestor.deletingLastPathComponent()
            guard parent.path != existingAncestor.path else {
                break
            }
            unresolvedComponents.insert(
                existingAncestor.lastPathComponent,
                at: 0
            )
            existingAncestor = parent
        }
        var canonicalURL = existingAncestor.resolvingSymlinksInPath()
        for component in unresolvedComponents {
            canonicalURL.append(path: component)
        }
        return canonicalURL.standardizedFileURL
    }

    private func validateCommit(_ value: String) throws {
        guard value.count == 40,
              value.allSatisfy(\.isLowercaseHexDigit)
        else {
            throw L4V2HarnessError.invalidField("baselineCommit")
        }
    }

    private static func validateManifestShape(_ data: Data) throws {
        let root = try object(data)
        try exactKeys(
            root,
            [
                "schemaVersion", "disposition", "acceptedL3Baseline",
                "directions", "runtimeActivated",
                "shippingResourcesMutated", "productionSelected",
            ]
        )
        let baseline = try child(root, "acceptedL3Baseline")
        try exactKeys(
            baseline,
            ["commit", "catalog", "industrialL3Manifest"]
        )
        try artifactShape(try child(baseline, "catalog"))
        try artifactShape(try child(baseline, "industrialL3Manifest"))
        guard let directions = root["directions"] as? [[String: Any]],
              directions.count == 4
        else {
            throw L4V2HarnessError.schemaDrift
        }
        for direction in directions {
            try exactKeys(
                direction,
                [
                    "direction", "packet", "sourceAdmission",
                    "quarantineReceipt", "locators",
                ]
            )
            try artifactShape(try child(direction, "packet"))
            try artifactShape(try child(direction, "sourceAdmission"))
            try artifactShape(try child(direction, "quarantineReceipt"))
            let locators = try child(direction, "locators")
            try exactKeys(
                locators,
                [
                    "raw", "provenance", "normalization", "descriptor",
                    "contact", "review",
                ]
            )
            for key in [
                "raw", "provenance", "normalization", "descriptor",
                "contact", "review",
            ] {
                try artifactShape(try child(locators, key))
            }
        }
    }

    private static func validateReceiptShape(_ data: Data) throws {
        try exactKeys(
            try object(data),
            [
                "schemaVersion", "disposition", "direction", "logicalID",
                "workerPacketSha256", "sourceAdmissionSha256",
                "rendererQuarantined", "readyForAtomicAssembly",
                "productionSelected", "runtimeMappingMutated",
                "shippingResourcesMutated",
            ]
        )
    }

    private static func artifactShape(
        _ object: [String: Any]
    ) throws {
        try exactKeys(object, ["path", "sha256"])
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        else {
            throw L4V2HarnessError.schemaDrift
        }
        return object
    }

    private static func child(
        _ object: [String: Any],
        _ key: String
    ) throws -> [String: Any] {
        guard let child = object[key] as? [String: Any] else {
            throw L4V2HarnessError.schemaDrift
        }
        return child
    }

    private static func exactKeys(
        _ object: [String: Any],
        _ expected: Set<String>
    ) throws {
        guard Set(object.keys) == expected else {
            throw L4V2HarnessError.schemaDrift
        }
    }
}

final class IndustrialL4V2SourceAdmissionHarnessTests: XCTestCase {
    func testCallerSuppliedAtomicAssemblyManifest() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let manifestPath =
                environment["CITYSIM_L4_ASSEMBLY_MANIFEST_PATH"]
        else {
            throw XCTSkip("No caller-supplied Industrial L4 assembly manifest")
        }
        let root = URL(
            fileURLWithPath: try requiredEnvironment(
                "CITYSIM_L4_CLAIMED_ROOT",
                environment: environment
            )
        ).standardizedFileURL.resolvingSymlinksInPath()
        let harness = L4V2AtomicAssemblyHarness(
            claimedRoot: root
        )
        let outputURL = try harness.canonicalEvidenceOutputURL(
            resolve(
                try requiredEnvironment(
                    "CITYSIM_L4_ATOMIC_LEDGER_OUTPUT",
                    environment: environment
                ),
                beneath: root
            )
        )
        let ledger = try harness.assemble(
            manifestURL: resolve(manifestPath, beneath: root),
            manifestSha256: try requiredEnvironment(
                "CITYSIM_L4_ASSEMBLY_MANIFEST_SHA256",
                environment: environment
            )
        )
        let data = try sortedData(ledger)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: outputURL.path) {
            XCTAssertEqual(try Data(contentsOf: outputURL), data)
        } else {
            try data.write(to: outputURL)
        }
        print(
            "PLAY073_L4_ATOMIC_LEDGER \(outputURL.path) "
                + L4V2SourceAdmissionHarness.sha256(data)
        )
    }

    func testSyntheticFileBackedAtomicAssemblyIsDeterministic() throws {
        try withRoot { root in
            let input = try makeAssemblyInput(root: root)
            let harness = L4V2AtomicAssemblyHarness(claimedRoot: root)
            let first = try harness.assemble(
                manifestURL: input.url,
                manifestSha256: input.sha256
            )
            let second = try harness.assemble(
                manifestURL: input.url,
                manifestSha256: input.sha256
            )
            XCTAssertEqual(first, second)
            XCTAssertEqual(first.lodIdentityCount, 12)
            XCTAssertEqual(first.d4IdentityCount, 32)
            XCTAssertEqual(
                first.directions.map(\.direction),
                L4V2Direction.allCases
            )
            XCTAssertFalse(first.runtimeActivated)
            XCTAssertFalse(first.shippingResourcesMutated)
            XCTAssertFalse(first.productionSelected)
            XCTAssertEqual(try sortedData(first), try sortedData(second))
        }
    }

    func testAtomicAssemblyRejectsMissingExtraAndLocatorDrift() throws {
        try withRoot { root in
            let valid = try makeAssemblyInput(root: root)
            let harness = L4V2AtomicAssemblyHarness(claimedRoot: root)
            let validData = try Data(contentsOf: valid.url)

            var missing = try jsonObject(validData)
            var directions = try XCTUnwrap(
                missing["directions"] as? [[String: Any]]
            )
            directions.removeLast()
            missing["directions"] = directions
            let missingHash = try write(missing, to: valid.url)
            XCTAssertThrowsError(
                try harness.assemble(
                    manifestURL: valid.url,
                    manifestSha256: missingHash
                )
            ) {
                XCTAssertEqual($0 as? L4V2HarnessError, .schemaDrift)
            }

            let restored = try makeAssemblyInput(root: root)
            var extra = try jsonObject(try Data(contentsOf: restored.url))
            directions = try XCTUnwrap(
                extra["directions"] as? [[String: Any]]
            )
            directions.append(try XCTUnwrap(directions.first))
            extra["directions"] = directions
            let extraHash = try write(extra, to: restored.url)
            XCTAssertThrowsError(
                try harness.assemble(
                    manifestURL: restored.url,
                    manifestSha256: extraHash
                )
            ) {
                XCTAssertEqual($0 as? L4V2HarnessError, .schemaDrift)
            }

            let locatorInput = try makeAssemblyInput(root: root)
            var drift = try jsonObject(
                try Data(contentsOf: locatorInput.url)
            )
            directions = try XCTUnwrap(
                drift["directions"] as? [[String: Any]]
            )
            var north = directions[0]
            var locators = try XCTUnwrap(
                north["locators"] as? [String: Any]
            )
            var raw = try XCTUnwrap(locators["raw"] as? [String: Any])
            raw["sha256"] = hash("wrong-locator")
            locators["raw"] = raw
            north["locators"] = locators
            directions[0] = north
            drift["directions"] = directions
            let driftHash = try write(drift, to: locatorInput.url)
            XCTAssertThrowsError(
                try harness.assemble(
                    manifestURL: locatorInput.url,
                    manifestSha256: driftHash
                )
            ) {
                XCTAssertEqual($0 as? L4V2HarnessError, .hashMismatch)
            }
        }
    }

    func testAtomicAssemblyRejectsInputLocatorSymlinkEscape() throws {
        try withRoot { root in
            let externalRoot = FileManager.default.temporaryDirectory
                .appending(
                    path: "play073-l4-v2-external-\(UUID().uuidString)"
                )
            try FileManager.default.createDirectory(
                at: externalRoot,
                withIntermediateDirectories: true
            )
            defer { try? FileManager.default.removeItem(at: externalRoot) }

            let input = try makeAssemblyInput(root: root)
            let escapedData = Data("escaped-raw-locator".utf8)
            let escapedURL = externalRoot.appending(path: "raw.png")
            let escapedHash = try writeBytes(
                escapedData,
                to: escapedURL
            )
            let symlinkURL = root.appending(
                path: "locators/n/escaped-raw.png"
            )
            try FileManager.default.createDirectory(
                at: symlinkURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.createSymbolicLink(
                at: symlinkURL,
                withDestinationURL: escapedURL
            )

            var manifest = try jsonObject(
                try Data(contentsOf: input.url)
            )
            var directions = try XCTUnwrap(
                manifest["directions"] as? [[String: Any]]
            )
            var north = directions[0]
            var locators = try XCTUnwrap(
                north["locators"] as? [String: Any]
            )
            locators["raw"] = [
                "path": try relativePath(symlinkURL, root: root),
                "sha256": escapedHash,
            ]
            north["locators"] = locators
            directions[0] = north
            manifest["directions"] = directions
            let manifestHash = try write(manifest, to: input.url)

            XCTAssertThrowsError(
                try L4V2AtomicAssemblyHarness(
                    claimedRoot: root
                ).assemble(
                    manifestURL: input.url,
                    manifestSha256: manifestHash
                )
            ) {
                XCTAssertEqual(
                    $0 as? L4V2HarnessError,
                    .outsideClaimedRoot(
                        escapedURL.resolvingSymlinksInPath().path
                    )
                )
            }
        }
    }

    func testAtomicAssemblyRejectsLedgerOutputSymlinkEscape() throws {
        try withRoot { root in
            let externalRoot = FileManager.default.temporaryDirectory
                .appending(
                    path: "play073-l4-v2-ledger-\(UUID().uuidString)"
                )
            try FileManager.default.createDirectory(
                at: externalRoot,
                withIntermediateDirectories: true
            )
            defer { try? FileManager.default.removeItem(at: externalRoot) }

            let evidenceRoot = root.appending(
                path: "docs/production/evidence/PLAY-073"
            )
            try FileManager.default.createDirectory(
                at: evidenceRoot,
                withIntermediateDirectories: true
            )
            let symlinkURL = evidenceRoot.appending(path: "escaped")
            try FileManager.default.createSymbolicLink(
                at: symlinkURL,
                withDestinationURL: externalRoot
            )
            let outputURL = symlinkURL.appending(path: "ledger.json")

            XCTAssertThrowsError(
                try L4V2AtomicAssemblyHarness(
                    claimedRoot: root
                ).canonicalEvidenceOutputURL(outputURL)
            ) {
                XCTAssertEqual(
                    $0 as? L4V2HarnessError,
                    .outsideClaimedRoot(
                        symlinkURL.path
                    )
                )
            }
        }
    }

    func testAtomicAssemblyRejectsDanglingFinalLedgerSymlink() throws {
        try withRoot { root in
            let externalRoot = FileManager.default.temporaryDirectory
                .appending(
                    path:
                        "play073-l4-v2-dangling-ledger-\(UUID().uuidString)"
                )
            try FileManager.default.createDirectory(
                at: externalRoot,
                withIntermediateDirectories: true
            )
            defer { try? FileManager.default.removeItem(at: externalRoot) }

            let evidenceRoot = root.appending(
                path: "docs/production/evidence/PLAY-073"
            )
            try FileManager.default.createDirectory(
                at: evidenceRoot,
                withIntermediateDirectories: true
            )
            let externalTarget = externalRoot.appending(
                path: "absent-ledger.json"
            )
            let outputURL = evidenceRoot.appending(
                path: "atomic-ledger.json"
            )
            try FileManager.default.createSymbolicLink(
                at: outputURL,
                withDestinationURL: externalTarget
            )
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: externalTarget.path
                )
            )

            XCTAssertThrowsError(
                try {
                    let validatedOutput =
                        try L4V2AtomicAssemblyHarness(
                            claimedRoot: root
                        ).canonicalEvidenceOutputURL(outputURL)
                    try Data("must-not-escape".utf8).write(
                        to: validatedOutput
                    )
                }()
            ) {
                XCTAssertEqual(
                    $0 as? L4V2HarnessError,
                    .outsideClaimedRoot(outputURL.path)
                )
            }
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: externalTarget.path
                )
            )
        }
    }

    func testCallerSuppliedDirectionPacketAndAdmissionReceipt() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let packetPath = environment["CITYSIM_L4_PACKET_PATH"] else {
            throw XCTSkip("No caller-supplied Industrial L4 packet")
        }
        let claimedRoot = URL(
            fileURLWithPath: try requiredEnvironment(
                "CITYSIM_L4_CLAIMED_ROOT",
                environment: environment
            )
        ).standardizedFileURL.resolvingSymlinksInPath()
        let packetURL = resolve(packetPath, beneath: claimedRoot)
        let admissionURL = resolve(
            try requiredEnvironment(
                "CITYSIM_L4_ADMISSION_PATH",
                environment: environment
            ),
            beneath: claimedRoot
        )
        let outputURL = resolve(
            try requiredEnvironment(
                "CITYSIM_L4_RECEIPT_OUTPUT",
                environment: environment
            ),
            beneath: claimedRoot
        )
        let expectedDirection = try XCTUnwrap(
            L4V2Direction(
                rawValue: try requiredEnvironment(
                    "CITYSIM_L4_DIRECTION",
                    environment: environment
                )
            )
        )
        let admitted = try L4V2SourceAdmissionHarness(
            claimedRoot: claimedRoot
        ).inspect(
            L4V2FileInput(
                packetURL: packetURL,
                packetSha256: try requiredEnvironment(
                    "CITYSIM_L4_PACKET_SHA256",
                    environment: environment
                ),
                admissionURL: admissionURL,
                admissionSha256: try requiredEnvironment(
                    "CITYSIM_L4_ADMISSION_SHA256",
                    environment: environment
                )
            )
        )
        XCTAssertEqual(admitted.packet.direction, expectedDirection)
        XCTAssertEqual(admitted.admission.direction, expectedDirection)
        XCTAssertTrue(admitted.receipt.rendererQuarantined)
        XCTAssertFalse(admitted.receipt.readyForAtomicAssembly)
        XCTAssertFalse(admitted.receipt.productionSelected)
        XCTAssertFalse(admitted.receipt.runtimeMappingMutated)
        XCTAssertFalse(admitted.receipt.shippingResourcesMutated)

        let written = try L4V2SourceAdmissionHarness(
            claimedRoot: claimedRoot
        ).writeReceipt(admitted.receipt, to: outputURL)
        print(
            "PLAY073_L4_QUARANTINE_RECEIPT "
                + "\(written.url.path) "
                + L4V2SourceAdmissionHarness.sha256(written.data)
        )
    }

    func testAllDirectionsUseCanonicalRegularFilesAndDeterministicReceipts() throws {
        try withRoot { root in
            let harness = L4V2SourceAdmissionHarness(claimedRoot: root)
            for direction in L4V2Direction.allCases {
                let packet = makePacket(direction)
                let packetURL = root.appending(
                    path: "worker/\(direction.rawValue).json"
                )
                let packetHash = try write(packet, to: packetURL)
                let input = try writeAdmission(
                    packet: packet,
                    packetURL: packetURL,
                    packetHash: packetHash,
                    root: root
                )

                let first = try harness.inspect(input)
                let second = try harness.inspect(input)
                XCTAssertEqual(first, second)

                let outputURL = root.appending(
                    path:
                        "docs/production/evidence/PLAY-073/"
                        + "\(direction.rawValue)-receipt.json"
                )
                let firstWrite = try harness.writeReceipt(
                    first.receipt,
                    to: outputURL
                )
                let secondWrite = try harness.writeReceipt(
                    second.receipt,
                    to: outputURL
                )
                XCTAssertEqual(firstWrite.url, secondWrite.url)
                XCTAssertEqual(firstWrite.data, secondWrite.data)
                XCTAssertEqual(
                    try Data(contentsOf: firstWrite.url),
                    firstWrite.data
                )
                XCTAssertTrue(first.receipt.rendererQuarantined)
                XCTAssertFalse(first.receipt.readyForAtomicAssembly)
                XCTAssertFalse(first.receipt.productionSelected)
                XCTAssertFalse(first.receipt.runtimeMappingMutated)
                XCTAssertFalse(first.receipt.shippingResourcesMutated)
            }
        }
    }

    func testAllDirectionsRejectInputSymlinksAndNonRegularFiles() throws {
        try withRoot { root in
            let harness = L4V2SourceAdmissionHarness(claimedRoot: root)
            for direction in L4V2Direction.allCases {
                let packet = makePacket(direction)
                let packetURL = root.appending(
                    path: "worker/\(direction.rawValue).json"
                )
                let packetHash = try write(packet, to: packetURL)
                let input = try writeAdmission(
                    packet: packet,
                    packetURL: packetURL,
                    packetHash: packetHash,
                    root: root
                )
                let admissionURL = try XCTUnwrap(input.admissionURL)
                let admissionHash = try XCTUnwrap(input.admissionSha256)

                let packetSymlink = root.appending(
                    path: "worker/\(direction.rawValue)-link.json"
                )
                try FileManager.default.createSymbolicLink(
                    at: packetSymlink,
                    withDestinationURL: packetURL
                )
                XCTAssertThrowsError(
                    try harness.inspect(
                        L4V2FileInput(
                            packetURL: packetSymlink,
                            packetSha256: packetHash,
                            admissionURL: admissionURL,
                            admissionSha256: admissionHash
                        )
                    )
                ) {
                    XCTAssertEqual(
                        $0 as? L4V2HarnessError,
                        .outsideClaimedRoot(packetSymlink.path)
                    )
                }

                let admissionSymlink = root.appending(
                    path:
                        "integration/\(direction.rawValue)-admission-link.json"
                )
                try FileManager.default.createSymbolicLink(
                    at: admissionSymlink,
                    withDestinationURL: admissionURL
                )
                XCTAssertThrowsError(
                    try harness.inspect(
                        L4V2FileInput(
                            packetURL: packetURL,
                            packetSha256: packetHash,
                            admissionURL: admissionSymlink,
                            admissionSha256: admissionHash
                        )
                    )
                ) {
                    XCTAssertEqual(
                        $0 as? L4V2HarnessError,
                        .outsideClaimedRoot(admissionSymlink.path)
                    )
                }

                let packetDirectory = root.appending(
                    path: "worker/\(direction.rawValue)-directory"
                )
                try FileManager.default.createDirectory(
                    at: packetDirectory,
                    withIntermediateDirectories: true
                )
                XCTAssertThrowsError(
                    try harness.inspect(
                        L4V2FileInput(
                            packetURL: packetDirectory,
                            packetSha256: packetHash,
                            admissionURL: admissionURL,
                            admissionSha256: admissionHash
                        )
                    )
                ) {
                    XCTAssertEqual(
                        $0 as? L4V2HarnessError,
                        .invalidPathType(packetDirectory.path)
                    )
                }
            }
        }
    }

    func testAllDirectionsRejectReceiptSymlinksAndDirectoryTargets() throws {
        try withRoot { root in
            let harness = L4V2SourceAdmissionHarness(claimedRoot: root)
            let externalRoot = FileManager.default.temporaryDirectory
                .appending(
                    path: "play073-l4-v2-direction-\(UUID().uuidString)"
                )
            try FileManager.default.createDirectory(
                at: externalRoot,
                withIntermediateDirectories: true
            )
            defer { try? FileManager.default.removeItem(at: externalRoot) }

            let evidenceRoot = root.appending(
                path: "docs/production/evidence/PLAY-073"
            )
            try FileManager.default.createDirectory(
                at: evidenceRoot,
                withIntermediateDirectories: true
            )

            for direction in L4V2Direction.allCases {
                let packet = makePacket(direction)
                let packetURL = root.appending(
                    path: "worker/\(direction.rawValue).json"
                )
                let packetHash = try write(packet, to: packetURL)
                let input = try writeAdmission(
                    packet: packet,
                    packetURL: packetURL,
                    packetHash: packetHash,
                    root: root
                )
                let admitted = try harness.inspect(input)

                let intermediateSymlink = evidenceRoot.appending(
                    path: "\(direction.rawValue)-escaped"
                )
                try FileManager.default.createSymbolicLink(
                    at: intermediateSymlink,
                    withDestinationURL: externalRoot
                )
                XCTAssertThrowsError(
                    try harness.writeReceipt(
                        admitted.receipt,
                        to: intermediateSymlink.appending(
                            path: "receipt.json"
                        )
                    )
                ) {
                    XCTAssertEqual(
                        $0 as? L4V2HarnessError,
                        .outsideClaimedRoot(intermediateSymlink.path)
                    )
                }

                let externalTarget = externalRoot.appending(
                    path: "\(direction.rawValue)-absent.json"
                )
                let danglingOutput = evidenceRoot.appending(
                    path: "\(direction.rawValue)-dangling.json"
                )
                try FileManager.default.createSymbolicLink(
                    at: danglingOutput,
                    withDestinationURL: externalTarget
                )
                XCTAssertFalse(
                    FileManager.default.fileExists(
                        atPath: externalTarget.path
                    )
                )
                XCTAssertThrowsError(
                    try harness.writeReceipt(
                        admitted.receipt,
                        to: danglingOutput
                    )
                ) {
                    XCTAssertEqual(
                        $0 as? L4V2HarnessError,
                        .outsideClaimedRoot(danglingOutput.path)
                    )
                }
                XCTAssertFalse(
                    FileManager.default.fileExists(
                        atPath: externalTarget.path
                    )
                )

                let directoryOutput = evidenceRoot.appending(
                    path: "\(direction.rawValue)-directory"
                )
                try FileManager.default.createDirectory(
                    at: directoryOutput,
                    withIntermediateDirectories: true
                )
                XCTAssertThrowsError(
                    try harness.writeReceipt(
                        admitted.receipt,
                        to: directoryOutput
                    )
                ) {
                    XCTAssertEqual(
                        $0 as? L4V2HarnessError,
                        .invalidPathType(directoryOutput.path)
                    )
                }

                let lexicalEscape = root.appending(
                    path:
                        "docs/production/evidence/PLAY-073/../../../../"
                        + "\(direction.rawValue)-escaped.json"
                )
                XCTAssertThrowsError(
                    try harness.writeReceipt(
                        admitted.receipt,
                        to: lexicalEscape
                    )
                ) {
                    XCTAssertEqual(
                        $0 as? L4V2HarnessError,
                        .outsideClaimedRoot(
                            lexicalEscape.standardizedFileURL.path
                        )
                    )
                }
            }
        }
    }

    func testWorkerCandidateRequiresSeparateIntegrationAdmission() throws {
        try withRoot { root in
            let packet = makePacket(.north)
            let packetURL = root.appending(path: "worker/north.json")
            let packetHash = try write(packet, to: packetURL)
            let harness = L4V2SourceAdmissionHarness(claimedRoot: root)

            XCTAssertThrowsError(
                try harness.inspect(
                    L4V2FileInput(
                        packetURL: packetURL,
                        packetSha256: packetHash,
                        admissionURL: nil,
                        admissionSha256: nil
                    )
                )
            ) {
                XCTAssertEqual($0 as? L4V2HarnessError, .missingAdmission)
            }

            let admitted = try writeAdmission(
                packet: packet,
                packetURL: packetURL,
                packetHash: packetHash,
                root: root
            )
            let first = try harness.inspect(admitted)
            let second = try harness.inspect(admitted)
            XCTAssertEqual(first, second)
            XCTAssertTrue(first.receipt.rendererQuarantined)
            XCTAssertFalse(first.receipt.readyForAtomicAssembly)
            XCTAssertFalse(first.receipt.productionSelected)
            XCTAssertFalse(first.receipt.runtimeMappingMutated)
            XCTAssertFalse(first.receipt.shippingResourcesMutated)
        }
    }

    func testDirectionLocalAdmissionRejectsWorkerSelfAdmissionAndShapeDrift() throws {
        try withRoot { root in
            let harness = L4V2SourceAdmissionHarness(claimedRoot: root)
            let workerAdmitted = replacing(
                makePacket(.east),
                workerState: L4V2WorkerState(
                    stage: "source_candidate",
                    candidateReadyForIndependentReview: true,
                    sourceReady: false,
                    integrationAdmitted: true,
                    rendererQuarantined: false,
                    productionSelected: false
                )
            )
            try assertPacketRejected(
                workerAdmitted,
                root: root,
                harness: harness,
                expected: .workerSelfAdmission
            )

            let packet = makePacket(.south)
            let packetURL = root.appending(path: "worker/south.json")
            let packetHash = try write(packet, to: packetURL)
            let validInput = try writeAdmission(
                packet: packet,
                packetURL: packetURL,
                packetHash: packetHash,
                root: root
            )
            var missing = try jsonObject(
                Data(contentsOf: try XCTUnwrap(validInput.admissionURL))
            )
            missing.removeValue(forKey: "literalScaleDisposition")
            let missingHash = try write(
                missing,
                to: try XCTUnwrap(validInput.admissionURL)
            )
            XCTAssertThrowsError(
                try harness.inspect(
                    L4V2FileInput(
                        packetURL: packetURL,
                        packetSha256: packetHash,
                        admissionURL: validInput.admissionURL,
                        admissionSha256: missingHash
                    )
                )
            ) {
                XCTAssertEqual($0 as? L4V2HarnessError, .schemaDrift)
            }

            let unknownInput = try writeAdmission(
                packet: packet,
                packetURL: packetURL,
                packetHash: packetHash,
                root: root
            )
            var unknown = try jsonObject(
                Data(contentsOf: try XCTUnwrap(unknownInput.admissionURL))
            )
            var validator = try XCTUnwrap(
                unknown["semanticValidator"] as? [String: Any]
            )
            validator["workerApproved"] = true
            unknown["semanticValidator"] = validator
            let unknownHash = try write(
                unknown,
                to: try XCTUnwrap(unknownInput.admissionURL)
            )
            XCTAssertThrowsError(
                try harness.inspect(
                    L4V2FileInput(
                        packetURL: packetURL,
                        packetSha256: packetHash,
                        admissionURL: unknownInput.admissionURL,
                        admissionSha256: unknownHash
                    )
                )
            ) {
                XCTAssertEqual($0 as? L4V2HarnessError, .schemaDrift)
            }
        }
    }

    func testPacketRejectsFallbackRegistrationAliasAndRuntimeTransform() throws {
        let north = makeAdmitted(.north)
        var fallback = makePacket(.east)
        fallback = replacing(
            fallback,
            source: L4V2Source(
                contentCommit: fallback.source.contentCommit,
                sourceKey: fallback.source.sourceKey,
                decodedRgbaSha256: fallback.source.decodedRgbaSha256,
                fallbackSourceKey: "industrial_l03_v0_east"
            )
        )
        XCTAssertThrowsError(try validatePacket(fallback)) {
            XCTAssertEqual($0 as? L4V2HarnessError, .fallbackReference)
        }

        var badSocket = makePacket(.west)
        badSocket = replacing(
            badSocket,
            registration: L4V2Registration(
                footprintTiles: badSocket.registration.footprintTiles,
                canvasPixels: badSocket.registration.canvasPixels,
                groundPivotSource: badSocket.registration.groundPivotSource,
                frontageSocketSource: [896, 704],
                frontageEdge: badSocket.registration.frontageEdge,
                occupiedBounds: badSocket.registration.occupiedBounds
            )
        )
        XCTAssertThrowsError(try validatePacket(badSocket)) {
            XCTAssertEqual($0 as? L4V2HarnessError, .registrationDrift)
        }

        var aliasedEast = makeAdmitted(.east)
        aliasedEast = replacing(
            aliasedEast,
            sourceHash: north.packet.source.decodedRgbaSha256
        )
        XCTAssertThrowsError(
            try L4V2SourceAdmissionHarness.join([north, aliasedEast])
        ) {
            XCTAssertEqual(
                $0 as? L4V2HarnessError,
                .alias("decodedRgba")
            )
        }

        let northRotate90 = try XCTUnwrap(
            north.packet.d4Fingerprints["rotate90"]
        )
        let transformedEast = replacing(
            makeAdmitted(.east),
            sourceHash: northRotate90
        )
        XCTAssertThrowsError(
            try L4V2SourceAdmissionHarness.join([north, transformedEast])
        ) {
            XCTAssertEqual($0 as? L4V2HarnessError, .transformedSibling)
        }
    }

    func testFourDirectionJoinPreparesTwelveLODAndThirtyTwoD4Identities() throws {
        var admitted: [L4V2AdmittedPacket] = []
        XCTAssertEqual(
            try L4V2SourceAdmissionHarness.join(admitted).status,
            .inactive
        )
        for direction in L4V2Direction.allCases {
            admitted.append(makeAdmitted(direction))
            let partial = try L4V2SourceAdmissionHarness.join(admitted)
            if admitted.count < 4 {
                XCTAssertEqual(partial.status, .quarantinedIncomplete)
                XCTAssertThrowsError(
                    try L4V2SourceAdmissionHarness.requireReady(admitted)
                ) {
                    XCTAssertEqual(
                        $0 as? L4V2HarnessError,
                        .incompleteDirections
                    )
                }
            }
        }

        let ready = try L4V2SourceAdmissionHarness.requireReady(admitted)
        XCTAssertEqual(ready.status, .readyForAtomicAssembly)
        XCTAssertEqual(ready.directions, L4V2Direction.allCases)
        XCTAssertEqual(ready.lodIdentityCount, 12)
        XCTAssertEqual(ready.d4IdentityCount, 32)
        XCTAssertEqual(ready.fixtureCount, 4)
        XCTAssertFalse(ready.runtimeActivated)
        XCTAssertTrue(admitted.allSatisfy { !$0.packet.productionSelected })
        XCTAssertTrue(
            admitted.allSatisfy {
                !$0.receipt.runtimeMappingMutated
                    && !$0.receipt.shippingResourcesMutated
            }
        )
    }

    private func validatePacket(_ packet: L4V2DirectionPacket) throws {
        try withRoot { root in
            let packetURL = root.appending(path: "worker/\(packet.direction.rawValue).json")
            let packetHash = try write(packet, to: packetURL)
            let input = try writeAdmission(
                packet: packet,
                packetURL: packetURL,
                packetHash: packetHash,
                root: root
            )
            _ = try L4V2SourceAdmissionHarness(claimedRoot: root).inspect(input)
        }
    }

    private func assertPacketRejected(
        _ packet: L4V2DirectionPacket,
        root: URL,
        harness: L4V2SourceAdmissionHarness,
        expected: L4V2HarnessError
    ) throws {
        let packetURL = root.appending(
            path: "worker/\(packet.direction.rawValue)-rejected.json"
        )
        let packetHash = try write(packet, to: packetURL)
        let input = try writeAdmission(
            packet: packet,
            packetURL: packetURL,
            packetHash: packetHash,
            root: root
        )
        XCTAssertThrowsError(try harness.inspect(input)) {
            XCTAssertEqual($0 as? L4V2HarnessError, expected)
        }
    }

    private func makePacket(
        _ direction: L4V2Direction
    ) -> L4V2DirectionPacket {
        let prefix = "synthetic-\(direction.rawValue)"
        let decoded = hash(prefix + "-decoded")
        let socket: [L4V2Direction: [Int]] = [
            .north: [896, 704],
            .east: [896, 832],
            .south: [640, 832],
            .west: [640, 704],
        ]
        let fixture: [L4V2Direction: ([Int], [Int])] = [
            .north: ([4, 4], [4, 3]),
            .east: ([8, 4], [9, 4]),
            .south: ([8, 8], [8, 9]),
            .west: ([4, 8], [3, 8]),
        ]
        return L4V2DirectionPacket(
            schemaVersion: 2,
            family: "industrial",
            level: 4,
            variant: 0,
            direction: direction,
            logicalID: "industrial_l04_v0_\(direction.rawValue)",
            sourceStage: L4V2SourceAdmissionHarness.sourceStage,
            workerState: L4V2WorkerState(
                stage: "source_candidate",
                candidateReadyForIndependentReview: true,
                sourceReady: false,
                integrationAdmitted: false,
                rendererQuarantined: false,
                productionSelected: false
            ),
            source: L4V2Source(
                contentCommit: commit(prefix),
                sourceKey: "world-art/industrial-l04/\(direction.rawValue)",
                decodedRgbaSha256: decoded,
                fallbackSourceKey: nil
            ),
            lods: ["city", "neighborhood", "block"].map { detail in
                let sizes = [
                    "city": [256, 171],
                    "neighborhood": [512, 342],
                    "block": [1024, 683],
                ]
                return L4V2LOD(
                    detail: detail,
                    normalizedRgbaSha256: hash("\(prefix)-lod-\(detail)"),
                    atlasSlot:
                        "industrial_l04_v0_\(direction.rawValue)/\(detail)",
                    canvasPixels: sizes[detail]!
                )
            },
            registration: L4V2Registration(
                footprintTiles: [1, 1],
                canvasPixels: [1536, 1024],
                groundPivotSource: [768, 896],
                frontageSocketSource: socket[direction]!,
                frontageEdge: direction.rawValue,
                occupiedBounds: [430, 350, 1110, 930]
            ),
            d4Fingerprints: [
                "identity": decoded,
                "rotate90": hash(prefix + "-rotate90"),
                "rotate180": hash(prefix + "-rotate180"),
                "rotate270": hash(prefix + "-rotate270"),
                "mirrorX": hash(prefix + "-mirrorX"),
                "mirrorY": hash(prefix + "-mirrorY"),
                "mirrorDiagonal": hash(prefix + "-mirrorDiagonal"),
                "mirrorAntiDiagonal": hash(prefix + "-mirrorAntiDiagonal"),
            ],
            fixturePreparation: L4V2FixturePreparation(
                fixtureCoordinate: fixture[direction]!.0,
                soleRoadCoordinate: fixture[direction]!.1,
                expectedFrontage: direction.rawValue,
                cityCameraScale: 0.85,
                neighborhoodCameraScale: 0.65,
                blockCameraScale: 0.50
            ),
            productionSelected: false
        )
    }

    private func makeAdmitted(
        _ direction: L4V2Direction
    ) -> L4V2AdmittedPacket {
        let packet = makePacket(direction)
        let packetHash = hash("packet-\(direction.rawValue)")
        return L4V2AdmittedPacket(
            packet: packet,
            packetSha256: packetHash,
            admission: makeAdmission(
                packet: packet,
                packetPath: "/candidate/\(direction.rawValue).json",
                packetHash: packetHash
            ),
            admissionSha256: hash("admission-\(direction.rawValue)"),
            receipt: L4V2RendererQuarantineReceipt(
                schemaVersion: 1,
                disposition: "renderer_quarantined_nonshipping",
                direction: direction,
                logicalID: packet.logicalID,
                workerPacketSha256: packetHash,
                sourceAdmissionSha256: hash("admission-\(direction.rawValue)"),
                rendererQuarantined: true,
                readyForAtomicAssembly: false,
                productionSelected: false,
                runtimeMappingMutated: false,
                shippingResourcesMutated: false
            )
        )
    }

    private func replacing(
        _ packet: L4V2DirectionPacket,
        workerState: L4V2WorkerState? = nil,
        source: L4V2Source? = nil,
        registration: L4V2Registration? = nil
    ) -> L4V2DirectionPacket {
        L4V2DirectionPacket(
            schemaVersion: packet.schemaVersion,
            family: packet.family,
            level: packet.level,
            variant: packet.variant,
            direction: packet.direction,
            logicalID: packet.logicalID,
            sourceStage: packet.sourceStage,
            workerState: workerState ?? packet.workerState,
            source: source ?? packet.source,
            lods: packet.lods,
            registration: registration ?? packet.registration,
            d4Fingerprints: packet.d4Fingerprints,
            fixturePreparation: packet.fixturePreparation,
            productionSelected: packet.productionSelected
        )
    }

    private func replacing(
        _ admitted: L4V2AdmittedPacket,
        sourceHash: String
    ) -> L4V2AdmittedPacket {
        let packet = admitted.packet
        let replacement = L4V2DirectionPacket(
            schemaVersion: packet.schemaVersion,
            family: packet.family,
            level: packet.level,
            variant: packet.variant,
            direction: packet.direction,
            logicalID: packet.logicalID,
            sourceStage: packet.sourceStage,
            workerState: packet.workerState,
            source: L4V2Source(
                contentCommit: packet.source.contentCommit,
                sourceKey: packet.source.sourceKey,
                decodedRgbaSha256: sourceHash,
                fallbackSourceKey: nil
            ),
            lods: packet.lods,
            registration: packet.registration,
            d4Fingerprints: packet.d4Fingerprints.merging(
                ["identity": sourceHash]
            ) { _, new in new },
            fixturePreparation: packet.fixturePreparation,
            productionSelected: packet.productionSelected
        )
        return L4V2AdmittedPacket(
            packet: replacement,
            packetSha256: admitted.packetSha256,
            admission: admitted.admission,
            admissionSha256: admitted.admissionSha256,
            receipt: admitted.receipt
        )
    }

    private func writeAdmission(
        packet: L4V2DirectionPacket,
        packetURL: URL,
        packetHash: String,
        root: URL
    ) throws -> L4V2FileInput {
        let admission = makeAdmission(
            packet: packet,
            packetPath: try relativePath(packetURL, root: root),
            packetHash: packetHash
        )
        let admissionURL = root.appending(
            path: "integration/\(packet.direction.rawValue)-admission.json"
        )
        let admissionHash = try write(admission, to: admissionURL)
        return L4V2FileInput(
            packetURL: packetURL,
            packetSha256: packetHash,
            admissionURL: admissionURL,
            admissionSha256: admissionHash
        )
    }

    private func makeAdmission(
        packet: L4V2DirectionPacket,
        packetPath: String,
        packetHash: String
    ) -> L4V2SourceAdmission {
        L4V2SourceAdmission(
            schemaVersion: 1,
            disposition: "integration_source_admitted",
            integrationCommit: commit(
                "integration-\(packet.direction.rawValue)"
            ),
            direction: packet.direction,
            logicalID: packet.logicalID,
            workerPacket: L4V2Artifact(
                path: packetPath,
                sha256: packetHash
            ),
            contentCommit: packet.source.contentCommit,
            decodedRgbaSha256: packet.source.decodedRgbaSha256,
            semanticValidator: packet.sourceStage.semanticValidator,
            semanticValidationResult: "PASS",
            independentTechnicalDisposition: "ACCEPT",
            literalScaleDisposition: "ACCEPT",
            rendererQuarantined: false,
            productionSelected: false
        )
    }

    private func withRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "play073-l4-v2-\(UUID().uuidString)"
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func makeAssemblyInput(
        root: URL
    ) throws -> (url: URL, sha256: String) {
        let baselineCatalog = try writeBytes(
            Data("synthetic-accepted-l3-catalog".utf8),
            to: root.appending(path: "baseline/catalog.json")
        )
        let baselineManifest = try writeBytes(
            Data("synthetic-accepted-l3-manifest".utf8),
            to: root.appending(path: "baseline/industrial-l3.json")
        )
        let directionHarness = L4V2SourceAdmissionHarness(
            claimedRoot: root
        )
        var directions: [L4V2AssemblyDirectionInput] = []

        for direction in L4V2Direction.allCases {
            let packet = makePacket(direction)
            let packetURL = root.appending(
                path: "worker/\(direction.rawValue).json"
            )
            let packetHash = try write(packet, to: packetURL)
            let input = try writeAdmission(
                packet: packet,
                packetURL: packetURL,
                packetHash: packetHash,
                root: root
            )
            let admitted = try directionHarness.inspect(input)
            let admissionURL = try XCTUnwrap(input.admissionURL)
            let admissionHash = try XCTUnwrap(input.admissionSha256)
            let receiptURL = root.appending(
                path: "renderer/\(direction.rawValue)-receipt.json"
            )
            let receiptHash = try write(
                admitted.receipt,
                to: receiptURL
            )

            func locator(_ role: String) throws -> L4V2Artifact {
                let url = root.appending(
                    path:
                        "locators/\(direction.rawValue)/\(role).synthetic"
                )
                let sha = try writeBytes(
                    Data(
                        "synthetic-\(direction.rawValue)-\(role)".utf8
                    ),
                    to: url
                )
                return L4V2Artifact(
                    path: try relativePath(url, root: root),
                    sha256: sha
                )
            }

            directions.append(
                L4V2AssemblyDirectionInput(
                    direction: direction,
                    packet: L4V2Artifact(
                        path: try relativePath(packetURL, root: root),
                        sha256: packetHash
                    ),
                    sourceAdmission: L4V2Artifact(
                        path: try relativePath(admissionURL, root: root),
                        sha256: admissionHash
                    ),
                    quarantineReceipt: L4V2Artifact(
                        path: try relativePath(receiptURL, root: root),
                        sha256: receiptHash
                    ),
                    locators: L4V2AssemblyLocators(
                        raw: try locator("raw"),
                        provenance: try locator("provenance"),
                        normalization: try locator("normalization"),
                        descriptor: try locator("descriptor"),
                        contact: try locator("contact"),
                        review: try locator("review")
                    )
                )
            )
        }

        let manifest = L4V2AssemblyInputManifest(
            schemaVersion: 1,
            disposition: "integration_assembly_input_admitted",
            acceptedL3Baseline: L4V2AcceptedBaseline(
                commit: commit("accepted-l3-baseline"),
                catalog: L4V2Artifact(
                    path: "baseline/catalog.json",
                    sha256: baselineCatalog
                ),
                industrialL3Manifest: L4V2Artifact(
                    path: "baseline/industrial-l3.json",
                    sha256: baselineManifest
                )
            ),
            directions: directions,
            runtimeActivated: false,
            shippingResourcesMutated: false,
            productionSelected: false
        )
        let url = root.appending(path: "integration/assembly-input.json")
        return (url, try write(manifest, to: url))
    }

    private func sortedData<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    @discardableResult
    private func writeBytes(_ data: Data, to url: URL) throws -> String {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
        return L4V2SourceAdmissionHarness.sha256(data)
    }

    private func requiredEnvironment(
        _ key: String,
        environment: [String: String]
    ) throws -> String {
        guard let value = environment[key], !value.isEmpty else {
            throw L4V2HarnessError.invalidField(key)
        }
        return value
    }

    private func resolve(_ path: String, beneath root: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }
        return root.appending(path: path).standardizedFileURL
    }

    private func relativePath(_ url: URL, root: URL) throws -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else {
            throw L4V2HarnessError.outsideClaimedRoot(path)
        }
        return String(path.dropFirst(rootPath.count + 1))
    }

    @discardableResult
    private func write<T: Encodable>(_ value: T, to url: URL) throws -> String {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url)
        return L4V2SourceAdmissionHarness.sha256(data)
    }

    @discardableResult
    private func write(
        _ object: [String: Any],
        to url: URL
    ) throws -> String {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        try data.write(to: url)
        return L4V2SourceAdmissionHarness.sha256(data)
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    private func hash(_ seed: String) -> String {
        L4V2SourceAdmissionHarness.sha256(Data(seed.utf8))
    }

    private func commit(_ seed: String) -> String {
        String(hash(seed).prefix(40))
    }
}

extension Character {
    fileprivate var isLowercaseHexDigit: Bool {
        ("0"..."9").contains(self) || ("a"..."f").contains(self)
    }
}
