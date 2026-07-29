import CryptoKit
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
            packetPath: input.packetURL.path,
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

    private func read(_ url: URL, expectedSha256: String) throws -> Data {
        let root = claimedRoot.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path == root || path.hasPrefix(root + "/") else {
            throw L4V2HarnessError.outsideClaimedRoot(path)
        }
        guard FileManager.default.fileExists(atPath: path) else {
            throw L4V2HarnessError.missingFile(url.lastPathComponent)
        }
        let data = try Data(contentsOf: url)
        guard Self.sha256(data) == expectedSha256 else {
            throw L4V2HarnessError.hashMismatch
        }
        return data
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

final class IndustrialL4V2SourceAdmissionHarnessTests: XCTestCase {
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
            packetPath: packetURL.path,
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
