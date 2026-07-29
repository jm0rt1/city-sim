import CryptoKit
import Darwin
import Foundation
import XCTest

private enum L4AdapterDirection: String, Codable, CaseIterable {
    case east
    case south
    case west
}

private struct L4AdapterArtifact: Codable, Equatable {
    let path: String
    let sha256: String
}

private struct L4AdapterContract: Codable, Equatable {
    let path: String
    let revision: Int
    let sha256: String
}

private struct L4AdapterBridge: Codable, Equatable {
    let documentPath: String
    let commit: String
    let documentSha256: String
    let canonicalMappingSha256: String
    let coordinateSystem: String
}

private struct L4AdapterAppearance: Codable, Equatable {
    let documentPath: String
    let commit: String
    let documentSha256: String
    let northProcessASourceSha256: String
    let northProcessADecodedRgbaSha256: String
}

private struct L4AdapterLocatorEntry: Codable, Equatable {
    let taskId: String
    let direction: L4AdapterDirection
    let branch: String
    let evidenceRoot: String
    let packetPath: String
    let status: String
    let writer: String
    let creationPolicy: String
}

private struct L4AdapterLocatorGrants: Codable, Equatable {
    let sourceAdmission: Bool
    let rendererQuarantine: Bool
    let rendererActivation: Bool
    let productionSelection: Bool
    let shipping: Bool
}

private struct L4AdapterSourceStageSchema: Codable, Equatable {
    let path: String
    let version: Int
    let sha256: String
}

private struct L4AdapterLocatorAuthority: Codable, Equatable {
    let schemaVersion: Int
    let documentType: String
    let family: String
    let level: Int
    let variant: Int
    let governingContract: L4AdapterContract
    let sourceStageSchema: L4AdapterSourceStageSchema
    let directions: [L4AdapterLocatorEntry]
    let grants: L4AdapterLocatorGrants
}

private struct L4AdapterIdentity: Codable, Equatable {
    let taskId: String
    let direction: L4AdapterDirection
    let branch: String
    let logicalID: String
    let sourceKey: String
    let sourceRoot: String
    let evidenceRoot: String
}

private struct L4AdapterAuthorities: Codable, Equatable {
    let contract021: L4AdapterContract
    let directionBridge: L4AdapterBridge
    let appearanceLock: L4AdapterAppearance
    let semanticValidator: L4AdapterArtifact
    let canonicalDecoder: L4AdapterArtifact
    let nonAliasLoader: L4AdapterArtifact
}

private struct L4AdapterInputs: Codable, Equatable {
    let runnerContract: L4AdapterArtifact
}

private struct L4AdapterSource: Codable, Equatable {
    let decodedRgbaSha256: String
    let authoredGeometrySha256: String
    let componentManifestSha256: String
    let fallbackSourceKey: String?
}

private struct L4AdapterLOD: Codable, Equatable {
    let path: String
    let sha256: String
    let decodedRgbaSha256: String
    let canvasPixels: [Int]
}

private struct L4AdapterBounds: Codable, Equatable {
    let minX: Int
    let minY: Int
    let maxX: Int
    let maxY: Int
}

private struct L4AdapterAlpha: Codable, Equatable {
    let nonzeroPixelCount: Int
    let hiddenRgbPixelCount: Int
    let nearChromaPixelCount: Int
}

private struct L4AdapterRegistration: Codable, Equatable {
    let footprintTiles: [Int]
    let canvasPixels: [Int]
    let groundPivotSource: [Int]
    let frontageSocketSource: [Int]
    let frontageEdge: L4AdapterDirection
    let supportedOrientation: String
    let occupiedBounds: L4AdapterBounds
    let groundContactPolygonWorld: [[Double]]
    let contactDeclaration: String
    let shadowDirection: String
    let alpha: L4AdapterAlpha
}

private struct L4AdapterValidation: Codable, Equatable {
    let receipt: L4AdapterArtifact
    let result: String
    let allGatesPassed: Bool
}

private struct L4AdapterCompletion: Codable, Equatable {
    let contentCommit: String
    let source: L4AdapterSource
    let selectedSource: L4AdapterArtifact
    let lods: [String: L4AdapterLOD]
    let registration: L4AdapterRegistration
    let transformFingerprints: [String: String]
    let validation: L4AdapterValidation
    let reviewManifest: L4AdapterArtifact
}

private struct L4AdapterSourceStage: Codable, Equatable {
    let schemaVersion: Int
    let stage: String
    let identity: L4AdapterIdentity
    let authorities: L4AdapterAuthorities
    let inputs: L4AdapterInputs
    let completion: L4AdapterCompletion
    let candidateReadyForIndependentReview: Bool
    let sourceReady: Bool
    let integrationAdmitted: Bool
    let rendererQuarantined: Bool
    let productionSelected: Bool
}

private struct L4AdapterWorkerState: Codable, Equatable {
    let stage: String
    let candidateReadyForIndependentReview: Bool
    let sourceReady: Bool
    let integrationAdmitted: Bool
    let rendererQuarantined: Bool
}

private struct L4AdapterPacketSource: Codable, Equatable {
    let candidateCommit: String
    let sourceKey: String
    let decodedRgbaSha256: String
    let authoredGeometrySha256: String
    let componentManifestSha256: String
    let fallbackSourceKey: String?
}

private struct L4AdapterPacketLOD: Codable, Equatable {
    let detail: String
    let normalizedRgbaSha256: String
    let canvasPixels: [Int]
}

private struct L4AdapterProvenance: Codable, Equatable {
    let sourceManifest: L4AdapterArtifact
    let toolchain: L4AdapterArtifact
    let normalizationReceipt: L4AdapterArtifact
}

private struct L4AdapterSourceStageBinding: Codable, Equatable {
    let schema: L4AdapterArtifact
    let semanticValidator: L4AdapterArtifact
    let canonicalDecoder: L4AdapterArtifact
    let nonAliasLoader: L4AdapterArtifact
}

private struct L4AdapterRendererPacket: Codable, Equatable {
    let schemaVersion: Int
    let family: String
    let level: Int
    let variant: Int
    let direction: L4AdapterDirection
    let logicalID: String
    let governingContract: L4AdapterContract
    let directionBridge: L4AdapterBridge
    let appearanceLock: L4AdapterAppearance
    let sourceStage: L4AdapterSourceStageBinding
    let workerState: L4AdapterWorkerState
    let source: L4AdapterPacketSource
    let lods: [L4AdapterPacketLOD]
    let provenance: L4AdapterProvenance
    let registration: L4AdapterRegistration
    let transformFingerprints: [String: String]
    let productionSelected: Bool
}

private struct L4AdapterBatchState: Equatable {
    let packets: [L4AdapterDirection: Data]
    let failures: [L4AdapterDirection: L4AdapterPrototypeError]
    let pendingDirections: [String]
    let status: String
    let runtimeActivated: Bool
    let shippingResourcesMutated: Bool
    let productionSelected: Bool
}

private struct L4AdapterSyntheticAdmission: Codable, Equatable {
    let schemaVersion: Int
    let disposition: String
    let integrationCommit: String
    let direction: L4AdapterDirection
    let logicalID: String
    let workerPacket: L4AdapterArtifact
    let contentCommit: String
    let decodedRgbaSha256: String
    let semanticValidator: L4AdapterArtifact
    let semanticValidationResult: String
    let independentTechnicalDisposition: String
    let literalScaleDisposition: String
    let rendererQuarantined: Bool
    let productionSelected: Bool
}

private enum L4AdapterSyntheticQuarantineStatus: String, Codable, Equatable {
    case inactive
    case quarantinedIncomplete = "quarantined_incomplete"
    case readyForAtomicAssembly = "ready_for_atomic_assembly"
}

private struct L4AdapterSyntheticQuarantineReceipt: Codable, Equatable {
    let schemaVersion: Int
    let packetSha256: String
    let sourceAdmissionSha256: String
    let logicalID: String
    let direction: L4AdapterDirection
    let decodedRgbaSha256: String
    let validationResult: String
    let quarantineStatus: L4AdapterSyntheticQuarantineStatus
    let rendererQuarantined: Bool
    let productionSelected: Bool
    let runtimeMappingMutated: Bool
    let shippingResourcesMutated: Bool
}

private struct L4AdapterSyntheticAdmittedPacket: Equatable {
    let packet: L4AdapterRendererPacket
    let packetSha256: String
    let admission: L4AdapterSyntheticAdmission
    let admissionSha256: String
}

private struct L4AdapterSyntheticQuarantineResult: Equatable {
    let status: L4AdapterSyntheticQuarantineStatus
    let acceptedDirections: [L4AdapterDirection]
    let missingDirections: [String]
}

private struct L4AdapterSyntheticFileInput {
    let packetURL: URL
    let packetSha256: String
    let admissionURL: URL
    let admissionSha256: String
}

private struct L4AdapterSyntheticFileOutput: Equatable {
    let admittedPacket: L4AdapterSyntheticAdmittedPacket
    let receipt: L4AdapterSyntheticQuarantineReceipt
    let receiptData: Data
}

private enum L4AdapterSyntheticQuarantineError: Error, Equatable {
    case unsafePath(String)
    case hashMismatch(String)
    case schemaDrift
    case packetDrift(String)
    case admissionDrift(String)
    case alias(String)
    case transformedSibling
    case incompleteDirections([String])
}

private struct L4AdapterSyntheticQuarantineHarness {
    let root: URL

    func inspect(
        _ input: L4AdapterSyntheticFileInput,
        existingPackets: [L4AdapterSyntheticAdmittedPacket] = []
    ) throws -> L4AdapterSyntheticFileOutput {
        let packetData = try read(
            input.packetURL,
            expectedSha256: input.packetSha256
        )
        try Self.validatePacketShape(packetData)
        let packet = try JSONDecoder().decode(
            L4AdapterRendererPacket.self,
            from: packetData
        )
        try Self.validatePacket(packet)

        let admissionData = try read(
            input.admissionURL,
            expectedSha256: input.admissionSha256
        )
        try Self.validateAdmissionShape(admissionData)
        let admission = try JSONDecoder().decode(
            L4AdapterSyntheticAdmission.self,
            from: admissionData
        )
        try Self.validateAdmission(
            admission,
            packet: packet,
            packetPath: try relativePath(input.packetURL),
            packetSha256: input.packetSha256
        )

        let admitted = L4AdapterSyntheticAdmittedPacket(
            packet: packet,
            packetSha256: input.packetSha256,
            admission: admission,
            admissionSha256: input.admissionSha256
        )
        let result = try Self.validateBatch(existingPackets + [admitted])
        let receipt = L4AdapterSyntheticQuarantineReceipt(
            schemaVersion: 1,
            packetSha256: input.packetSha256,
            sourceAdmissionSha256: input.admissionSha256,
            logicalID: packet.logicalID,
            direction: packet.direction,
            decodedRgbaSha256: packet.source.decodedRgbaSha256,
            validationResult: "accepted_direction_quarantine",
            quarantineStatus: result.status,
            rendererQuarantined: true,
            productionSelected: false,
            runtimeMappingMutated: false,
            shippingResourcesMutated: false
        )
        return L4AdapterSyntheticFileOutput(
            admittedPacket: admitted,
            receipt: receipt,
            receiptData: try L4AdapterPrototype.sortedData(receipt)
        )
    }

    static func validateBatch(
        _ admitted: [L4AdapterSyntheticAdmittedPacket]
    ) throws -> L4AdapterSyntheticQuarantineResult {
        let packets = admitted.map(\.packet)
        try unique(packets.map { $0.direction.rawValue }, field: "direction")
        try unique(packets.map(\.logicalID), field: "logicalID")
        try unique(packets.map(\.source.sourceKey), field: "sourceKey")
        try unique(
            packets.map(\.source.decodedRgbaSha256),
            field: "decodedRgbaSha256"
        )
        try unique(
            packets.map(\.source.authoredGeometrySha256),
            field: "authoredGeometrySha256"
        )
        try unique(
            packets.map(\.source.componentManifestSha256),
            field: "componentManifestSha256"
        )
        try unique(
            packets.flatMap { $0.lods.map(\.normalizedRgbaSha256) },
            field: "lods"
        )
        for packet in packets {
            let transformed = Set(
                packet.transformFingerprints
                    .filter { $0.key != "identity" }
                    .map(\.value)
            )
            for sibling in packets where sibling.direction != packet.direction {
                guard !transformed.contains(
                    sibling.source.decodedRgbaSha256
                ) else {
                    throw L4AdapterSyntheticQuarantineError.transformedSibling
                }
            }
        }

        let accepted = L4AdapterDirection.allCases.filter {
            packets.map(\.direction).contains($0)
        }
        let missing = ["north", "east", "south", "west"].filter {
            !accepted.map(\.rawValue).contains($0)
        }
        let status: L4AdapterSyntheticQuarantineStatus
        switch packets.count {
        case 0:
            status = .inactive
        case 4 where missing.isEmpty:
            status = .readyForAtomicAssembly
        default:
            status = .quarantinedIncomplete
        }
        return L4AdapterSyntheticQuarantineResult(
            status: status,
            acceptedDirections: accepted,
            missingDirections: missing
        )
    }

    static func requireReadyForAtomicAssembly(
        _ admitted: [L4AdapterSyntheticAdmittedPacket]
    ) throws -> L4AdapterSyntheticQuarantineResult {
        let result = try validateBatch(admitted)
        guard result.status == .readyForAtomicAssembly else {
            throw L4AdapterSyntheticQuarantineError.incompleteDirections(
                result.missingDirections
            )
        }
        return result
    }

    private static func validatePacket(
        _ packet: L4AdapterRendererPacket
    ) throws {
        guard packet.schemaVersion == 2,
              packet.family == "industrial",
              packet.level == 4,
              packet.variant == 0,
              packet.logicalID ==
                "industrial_l04_v0_\(packet.direction.rawValue)",
              packet.governingContract == L4AdapterPrototype.contract,
              packet.directionBridge == L4AdapterPrototype.directionBridge,
              packet.sourceStage == L4AdapterPrototype.sourceStage,
              packet.workerState.stage == "source_candidate",
              packet.workerState.candidateReadyForIndependentReview,
              !packet.workerState.sourceReady,
              !packet.workerState.integrationAdmitted,
              !packet.workerState.rendererQuarantined,
              packet.source.fallbackSourceKey == nil,
              !packet.productionSelected
        else {
            throw L4AdapterSyntheticQuarantineError.packetDrift("authority")
        }

        let lods = Dictionary(grouping: packet.lods, by: \.detail)
        guard packet.lods.count == 3,
              Set(lods.keys) == Set(L4AdapterPrototype.lodOrder),
              lods.values.allSatisfy({ $0.count == 1 }),
              packet.lods.allSatisfy({
                  $0.canvasPixels ==
                    L4AdapterPrototype.lodSizes[$0.detail]
              }),
              Set(packet.lods.map(\.normalizedRgbaSha256)).count == 3
        else {
            throw L4AdapterSyntheticQuarantineError.packetDrift("lods")
        }
        guard packet.transformFingerprints["identity"] ==
                packet.source.decodedRgbaSha256,
              Set(packet.transformFingerprints.keys) ==
                L4AdapterPrototype.transformKeys,
              Set(packet.transformFingerprints.values).count ==
                L4AdapterPrototype.transformKeys.count
        else {
            throw L4AdapterSyntheticQuarantineError.packetDrift("transforms")
        }
    }

    private static func validateAdmission(
        _ admission: L4AdapterSyntheticAdmission,
        packet: L4AdapterRendererPacket,
        packetPath: String,
        packetSha256: String
    ) throws {
        guard admission.schemaVersion == 1,
              admission.disposition == "integration_source_admitted",
              admission.direction == packet.direction,
              admission.logicalID == packet.logicalID,
              admission.workerPacket ==
                L4AdapterArtifact(path: packetPath, sha256: packetSha256),
              admission.contentCommit == packet.source.candidateCommit,
              admission.decodedRgbaSha256 ==
                packet.source.decodedRgbaSha256,
              admission.semanticValidator ==
                packet.sourceStage.semanticValidator
        else {
            throw L4AdapterSyntheticQuarantineError.admissionDrift(
                "candidateBinding"
            )
        }
        guard admission.semanticValidationResult == "PASS",
              admission.independentTechnicalDisposition == "ACCEPT",
              admission.literalScaleDisposition == "ACCEPT",
              !admission.rendererQuarantined,
              !admission.productionSelected,
              isCommit(admission.integrationCommit)
        else {
            throw L4AdapterSyntheticQuarantineError.admissionDrift(
                "authorityBoundary"
            )
        }
    }

    private func read(
        _ url: URL,
        expectedSha256: String
    ) throws -> Data {
        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let canonicalURL = url.standardizedFileURL.resolvingSymlinksInPath()
        guard canonicalURL.path.hasPrefix(canonicalRoot.path + "/"),
              canonicalURL.pathExtension == "json"
        else {
            throw L4AdapterSyntheticQuarantineError.unsafePath(
                canonicalURL.path
            )
        }
        let data = try Data(contentsOf: canonicalURL)
        guard L4AdapterPrototype.sha256(data) == expectedSha256 else {
            throw L4AdapterSyntheticQuarantineError.hashMismatch(
                canonicalURL.lastPathComponent
            )
        }
        return data
    }

    private func relativePath(_ url: URL) throws -> String {
        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let canonicalURL = url.standardizedFileURL.resolvingSymlinksInPath()
        guard canonicalURL.path.hasPrefix(canonicalRoot.path + "/") else {
            throw L4AdapterSyntheticQuarantineError.unsafePath(
                canonicalURL.path
            )
        }
        return String(
            canonicalURL.path.dropFirst(canonicalRoot.path.count + 1)
        )
    }

    private static func validatePacketShape(_ data: Data) throws {
        let root = try object(data)
        try exactKeys(
            root,
            [
                "schemaVersion", "family", "level", "variant", "direction",
                "logicalID", "governingContract", "directionBridge",
                "appearanceLock", "sourceStage", "workerState", "source",
                "lods", "provenance", "registration",
                "transformFingerprints", "productionSelected",
            ]
        )
        try exactKeys(
            try child(root, "workerState"),
            [
                "stage", "candidateReadyForIndependentReview", "sourceReady",
                "integrationAdmitted", "rendererQuarantined",
            ]
        )
        try allowedKeys(
            try child(root, "source"),
            [
                "candidateCommit", "sourceKey", "decodedRgbaSha256",
                "authoredGeometrySha256", "componentManifestSha256",
                "fallbackSourceKey",
            ],
            required: [
                "candidateCommit", "sourceKey", "decodedRgbaSha256",
                "authoredGeometrySha256", "componentManifestSha256",
            ]
        )
        guard let lods = root["lods"] as? [[String: Any]],
              lods.count == 3
        else {
            throw L4AdapterSyntheticQuarantineError.schemaDrift
        }
        for lod in lods {
            try exactKeys(
                lod,
                ["detail", "normalizedRgbaSha256", "canvasPixels"]
            )
        }
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
        try exactKeys(
            try child(root, "workerPacket"),
            ["path", "sha256"]
        )
        try exactKeys(
            try child(root, "semanticValidator"),
            ["path", "sha256"]
        )
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else {
            throw L4AdapterSyntheticQuarantineError.schemaDrift
        }
        return object
    }

    private static func child(
        _ object: [String: Any],
        _ key: String
    ) throws -> [String: Any] {
        guard let child = object[key] as? [String: Any] else {
            throw L4AdapterSyntheticQuarantineError.schemaDrift
        }
        return child
    }

    private static func exactKeys(
        _ object: [String: Any],
        _ expected: Set<String>
    ) throws {
        guard Set(object.keys) == expected else {
            throw L4AdapterSyntheticQuarantineError.schemaDrift
        }
    }

    private static func allowedKeys(
        _ object: [String: Any],
        _ allowed: Set<String>,
        required: Set<String>
    ) throws {
        let keys = Set(object.keys)
        guard keys.isSubset(of: allowed),
              required.isSubset(of: keys)
        else {
            throw L4AdapterSyntheticQuarantineError.schemaDrift
        }
    }

    private static func unique(
        _ values: [String],
        field: String
    ) throws {
        guard Set(values).count == values.count else {
            throw L4AdapterSyntheticQuarantineError.alias(field)
        }
    }

    private static func isCommit(_ value: String) -> Bool {
        value.count == 40
            && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}

private enum L4AdapterPrototypeError: Error, Equatable {
    case authorityHash
    case authorityDrift(String)
    case sourceHash(L4AdapterDirection)
    case unsafePath(String)
    case symlink(String)
    case sourceDrift(L4AdapterDirection, String)
    case alias(L4AdapterDirection)
    case transform(L4AdapterDirection)
    case northPending
}

private struct L4AdapterPrototype {
    static let authorityPath =
        "docs/production/evidence/INTEGRATION/industrial-l04-source-candidate-packet-locators-v1.json"
    static let authoritySHA =
        "a2c8daf558274bed9088b6c9ab616044e919af5b19101a01c2fe3a1b89122e65"
    static let contract = L4AdapterContract(
        path:
            "docs/production/decisions/CONTRACT-021-parallel-directional-art-cells.md",
        revision: 2,
        sha256:
            "f80844c928d904498510b8b151381f40315e072d52d81695aafcd6b91081ae4c"
    )
    static let sourceStage = L4AdapterSourceStageBinding(
        schema: L4AdapterArtifact(
            path:
                "docs/production/evidence/INTEGRATION/industrial-l04-source-stage-handoff-schema-v2.json",
            sha256:
                "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7"
        ),
        semanticValidator: L4AdapterArtifact(
            path:
                "Native/CitySimNative/WorldArt/Shared/validate_source_stage_handoff_v2.py",
            sha256:
                "7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340"
        ),
        canonicalDecoder: L4AdapterArtifact(
            path:
                "Native/CitySimNative/WorldArt/Shared/canonical_rgba_v1.swift",
            sha256:
                "2be2b57d0c9bb73e8a4438c69aa4230eba08c4b87937fae4d4e048244b9beaab"
        ),
        nonAliasLoader: L4AdapterArtifact(
            path:
                "Native/CitySimNative/WorldArt/Shared/accepted_master_non_alias_v1.py",
            sha256:
                "2c44bc3a4ffe3fdfc68a477b70f3af9478122e9b796543f32a154859ac300a39"
        )
    )
    static let directionBridge = L4AdapterBridge(
        documentPath:
            "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-DIRECTIONAL-BRIDGE-V06-ACCEPTANCE.md",
        commit: "3e01ca6738d7574718f9aeff4b66771eee109feb",
        documentSha256:
            "9765d88191d8a555de41dcccfb83b3da16d8f1423d534d66312ffa98a4615208",
        canonicalMappingSha256:
            "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7",
        coordinateSystem: "citysim_source_pixels_v1"
    )
    static let sockets: [L4AdapterDirection: [Int]] = [
        .east: [896, 832],
        .south: [640, 832],
        .west: [640, 704],
    ]
    static let lodOrder = ["city", "neighborhood", "block"]
    static let lodSizes = [
        "city": [256, 171],
        "neighborhood": [512, 342],
        "block": [1024, 683],
    ]
    static let transformKeys: Set<String> = [
        "identity", "rotate90", "rotate180", "rotate270",
        "mirrorX", "mirrorY", "mirrorDiagonal", "mirrorAntiDiagonal",
    ]

    let root: URL
    let authority: L4AdapterLocatorAuthority

    init(root: URL, authorityData: Data) throws {
        guard Self.sha256(authorityData) == Self.authoritySHA else {
            throw L4AdapterPrototypeError.authorityHash
        }
        let decoded = try JSONDecoder().decode(
            L4AdapterLocatorAuthority.self,
            from: authorityData
        )
        guard decoded.schemaVersion == 1,
              decoded.documentType ==
                "CITYSIM_INDUSTRIAL_L04_SOURCE_CANDIDATE_PACKET_LOCATORS",
              decoded.family == "industrial",
              decoded.level == 4,
              decoded.variant == 0,
              decoded.governingContract == Self.contract,
              decoded.sourceStageSchema.path == Self.sourceStage.schema.path,
              decoded.sourceStageSchema.version == 2,
              decoded.sourceStageSchema.sha256 ==
                Self.sourceStage.schema.sha256,
              decoded.directions.map(\.direction) ==
                L4AdapterDirection.allCases,
              !decoded.grants.sourceAdmission,
              !decoded.grants.rendererQuarantine,
              !decoded.grants.rendererActivation,
              !decoded.grants.productionSelection,
              !decoded.grants.shipping
        else {
            throw L4AdapterPrototypeError.authorityDrift("topLevel")
        }
        self.root = root
        authority = decoded
    }

    func adapt(
        _ direction: L4AdapterDirection,
        expectedSourceSHA: String,
        siblingPackets: [L4AdapterRendererPacket] = []
    ) throws -> (packet: L4AdapterRendererPacket, data: Data) {
        guard let locator = authority.directions.first(where: {
            $0.direction == direction
        }) else {
            throw L4AdapterPrototypeError.authorityDrift(direction.rawValue)
        }
        let sourceData = try safeRead(locator.packetPath)
        guard Self.sha256(sourceData) == expectedSourceSHA else {
            throw L4AdapterPrototypeError.sourceHash(direction)
        }
        let source = try JSONDecoder().decode(
            L4AdapterSourceStage.self,
            from: sourceData
        )
        try validate(source, locator: locator)

        let packet = L4AdapterRendererPacket(
            schemaVersion: 2,
            family: "industrial",
            level: 4,
            variant: 0,
            direction: direction,
            logicalID: source.identity.logicalID,
            governingContract: source.authorities.contract021,
            directionBridge: source.authorities.directionBridge,
            appearanceLock: source.authorities.appearanceLock,
            sourceStage: Self.sourceStage,
            workerState: L4AdapterWorkerState(
                stage: source.stage,
                candidateReadyForIndependentReview:
                    source.candidateReadyForIndependentReview,
                sourceReady: source.sourceReady,
                integrationAdmitted: source.integrationAdmitted,
                rendererQuarantined: source.rendererQuarantined
            ),
            source: L4AdapterPacketSource(
                candidateCommit: source.completion.contentCommit,
                sourceKey: source.identity.sourceKey,
                decodedRgbaSha256:
                    source.completion.source.decodedRgbaSha256,
                authoredGeometrySha256:
                    source.completion.source.authoredGeometrySha256,
                componentManifestSha256:
                    source.completion.source.componentManifestSha256,
                fallbackSourceKey:
                    source.completion.source.fallbackSourceKey
            ),
            lods: Self.lodOrder.map { detail in
                let lod = source.completion.lods[detail]!
                return L4AdapterPacketLOD(
                    detail: detail,
                    normalizedRgbaSha256: lod.decodedRgbaSha256,
                    canvasPixels: lod.canvasPixels
                )
            },
            provenance: L4AdapterProvenance(
                sourceManifest: L4AdapterArtifact(
                    path: locator.packetPath,
                    sha256: expectedSourceSHA
                ),
                toolchain: source.inputs.runnerContract,
                normalizationReceipt: source.completion.validation.receipt
            ),
            registration: source.completion.registration,
            transformFingerprints: source.completion.transformFingerprints,
            productionSelected: false
        )
        try validateNoAlias(packet, siblings: siblingPackets)
        return (packet, try Self.sortedData(packet))
    }

    func adaptIndependently(
        hashes: [L4AdapterDirection: String]
    ) -> L4AdapterBatchState {
        var packets: [L4AdapterDirection: Data] = [:]
        var decoded: [L4AdapterRendererPacket] = []
        var failures: [L4AdapterDirection: L4AdapterPrototypeError] = [:]
        for direction in L4AdapterDirection.allCases {
            do {
                let result = try adapt(
                    direction,
                    expectedSourceSHA: hashes[direction] ?? "",
                    siblingPackets: decoded
                )
                decoded.append(result.packet)
                packets[direction] = result.data
            } catch let error as L4AdapterPrototypeError {
                failures[direction] = error
            } catch {
                failures[direction] = .sourceDrift(direction, "decode")
            }
        }
        return L4AdapterBatchState(
            packets: packets,
            failures: failures,
            pendingDirections: ["north"],
            status: packets.count == 3 && failures.isEmpty
                ? "quarantined_incomplete_north_pending"
                : "source_candidate_incomplete",
            runtimeActivated: false,
            shippingResourcesMutated: false,
            productionSelected: false
        )
    }

    private func validate(
        _ source: L4AdapterSourceStage,
        locator: L4AdapterLocatorEntry
    ) throws {
        let direction = locator.direction
        guard source.schemaVersion == 2,
              source.stage == "source_candidate",
              source.identity.taskId == locator.taskId,
              source.identity.direction == direction,
              source.identity.branch == locator.branch,
              source.identity.logicalID ==
                "industrial_l04_v0_\(direction.rawValue)",
              source.identity.sourceKey.hasPrefix(
                "industrial_l04/variant-0/\(direction.rawValue)/source-v"
              ),
              source.identity.evidenceRoot.hasPrefix(locator.evidenceRoot),
              source.authorities.contract021 == Self.contract,
              source.authorities.directionBridge == Self.directionBridge,
              source.authorities.semanticValidator ==
                Self.sourceStage.semanticValidator,
              source.authorities.canonicalDecoder ==
                Self.sourceStage.canonicalDecoder,
              source.authorities.nonAliasLoader ==
                Self.sourceStage.nonAliasLoader,
              source.candidateReadyForIndependentReview,
              !source.sourceReady,
              !source.integrationAdmitted,
              !source.rendererQuarantined,
              !source.productionSelected,
              source.completion.source.fallbackSourceKey == nil,
              source.completion.validation.result == "PASS",
              source.completion.validation.allGatesPassed,
              source.completion.registration.frontageEdge == direction,
              source.completion.registration.supportedOrientation ==
                "\(direction.rawValue)-facing-authored",
              source.completion.registration.frontageSocketSource ==
                Self.sockets[direction],
              source.completion.registration.footprintTiles == [1, 1],
              source.completion.registration.canvasPixels == [1536, 1024],
              source.completion.registration.groundPivotSource == [768, 896],
              source.completion.registration.contactDeclaration ==
                "registered_ground_pivot",
              source.completion.registration.shadowDirection == "southeast",
              source.completion.registration.alpha.nonzeroPixelCount > 0,
              source.completion.registration.alpha.hiddenRgbPixelCount == 0,
              source.completion.registration.alpha.nearChromaPixelCount == 0
        else {
            throw L4AdapterPrototypeError.sourceDrift(direction, "semantic")
        }
        guard Set(source.completion.lods.keys) == Set(Self.lodOrder),
              Self.lodOrder.allSatisfy({
                  source.completion.lods[$0]?.canvasPixels ==
                    Self.lodSizes[$0]
              }),
              Set(source.completion.lods.values.map(\.decodedRgbaSha256))
                .count == 3
        else {
            throw L4AdapterPrototypeError.sourceDrift(direction, "lods")
        }
        guard Set(source.completion.transformFingerprints.keys) ==
                Self.transformKeys,
              Set(source.completion.transformFingerprints.values).count == 8
        else {
            throw L4AdapterPrototypeError.transform(direction)
        }
        for path in [
            source.identity.sourceRoot,
            source.identity.evidenceRoot,
            source.inputs.runnerContract.path,
            source.completion.selectedSource.path,
            source.completion.validation.receipt.path,
            source.completion.reviewManifest.path,
        ] + source.completion.lods.values.map(\.path) {
            try Self.validateRelativePath(path)
        }
    }

    private func validateNoAlias(
        _ packet: L4AdapterRendererPacket,
        siblings: [L4AdapterRendererPacket]
    ) throws {
        let direction = packet.direction
        let packetHashes =
            Set(packet.lods.map(\.normalizedRgbaSha256))
            .union(packet.transformFingerprints.values)
            .union([packet.source.decodedRgbaSha256])
        for sibling in siblings {
            let siblingHashes =
                Set(sibling.lods.map(\.normalizedRgbaSha256))
                .union(sibling.transformFingerprints.values)
                .union([sibling.source.decodedRgbaSha256])
            if !packetHashes.isDisjoint(with: siblingHashes) {
                throw L4AdapterPrototypeError.alias(direction)
            }
        }
    }

    private func safeRead(_ path: String) throws -> Data {
        try Self.validateRelativePath(path)
        let canonicalRoot =
            root.standardizedFileURL.resolvingSymlinksInPath()
        let components = path.split(separator: "/").map(String.init)
        var current = canonicalRoot
        for (index, component) in components.enumerated() {
            current.appendPathComponent(component)
            var info = stat()
            guard lstat(current.path, &info) == 0 else {
                throw L4AdapterPrototypeError.unsafePath(path)
            }
            let kind = info.st_mode & S_IFMT
            guard kind != S_IFLNK else {
                throw L4AdapterPrototypeError.symlink(
                    components.prefix(index + 1).joined(separator: "/")
                )
            }
            guard index == components.count - 1
                    ? kind == S_IFREG
                    : kind == S_IFDIR
            else {
                throw L4AdapterPrototypeError.unsafePath(path)
            }
        }
        let canonicalFile = current.resolvingSymlinksInPath()
        guard canonicalFile.path.hasPrefix(canonicalRoot.path + "/") else {
            throw L4AdapterPrototypeError.unsafePath(path)
        }
        return try Data(contentsOf: canonicalFile)
    }

    private static func validateRelativePath(_ path: String) throws {
        let components = path.split(separator: "/").map(String.init)
        guard !path.hasPrefix("/"),
              !path.contains("//"),
              !components.contains("."),
              !components.contains(".."),
              path.hasPrefix("Native/CitySimNative/WorldArt/")
                || path.hasPrefix("docs/production/evidence/")
        else {
            throw L4AdapterPrototypeError.unsafePath(path)
        }
    }

    static func sortedData<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

final class IndustrialL4SourceStageAdapterPrototypeTests: XCTestCase {
    func testReservedEastSouthWestMapDeterministicallyWithNorthPending()
        throws
    {
        try withSyntheticInputs { root, authorityData, hashes in
            let adapter = try L4AdapterPrototype(
                root: root,
                authorityData: authorityData
            )
            let first = adapter.adaptIndependently(hashes: hashes)
            let second = adapter.adaptIndependently(hashes: hashes)
            XCTAssertEqual(first, second)
            XCTAssertEqual(
                Set(first.packets.keys),
                Set(L4AdapterDirection.allCases)
            )
            XCTAssertTrue(first.failures.isEmpty)
            XCTAssertEqual(first.pendingDirections, ["north"])
            XCTAssertEqual(
                first.status,
                "quarantined_incomplete_north_pending"
            )
            XCTAssertFalse(first.runtimeActivated)
            XCTAssertFalse(first.shippingResourcesMutated)
            XCTAssertFalse(first.productionSelected)

            var allLODHashes: Set<String> = []
            var allTransformHashes: Set<String> = []
            for direction in L4AdapterDirection.allCases {
                let packet = try JSONDecoder().decode(
                    L4AdapterRendererPacket.self,
                    from: try XCTUnwrap(first.packets[direction])
                )
                XCTAssertEqual(packet.direction, direction)
                XCTAssertEqual(packet.lods.map(\.detail), [
                    "city", "neighborhood", "block",
                ])
                XCTAssertEqual(
                    packet.registration.frontageSocketSource,
                    L4AdapterPrototype.sockets[direction]
                )
                XCTAssertNil(packet.source.fallbackSourceKey)
                XCTAssertFalse(packet.workerState.integrationAdmitted)
                XCTAssertFalse(packet.workerState.rendererQuarantined)
                XCTAssertFalse(packet.productionSelected)
                allLODHashes.formUnion(
                    packet.lods.map(\.normalizedRgbaSha256)
                )
                allTransformHashes.formUnion(
                    packet.transformFingerprints.values
                )
            }
            XCTAssertEqual(allLODHashes.count, 9)
            XCTAssertEqual(allTransformHashes.count, 24)
        }
    }

    func testAuthorityHashPathContainmentAndSymlinkFailClosed() throws {
        try withSyntheticInputs { root, authorityData, hashes in
            XCTAssertThrowsError(
                try L4AdapterPrototype(
                    root: root,
                    authorityData: Data(authorityData.dropLast())
                )
            ) {
                XCTAssertEqual(
                    $0 as? L4AdapterPrototypeError,
                    .authorityHash
                )
            }
            let adapter = try L4AdapterPrototype(
                root: root,
                authorityData: authorityData
            )
            XCTAssertThrowsError(
                try adapter.adapt(
                    .east,
                    expectedSourceSHA: String(repeating: "0", count: 64)
                )
            ) {
                XCTAssertEqual(
                    $0 as? L4AdapterPrototypeError,
                    .sourceHash(.east)
                )
            }

            let eastPath = try XCTUnwrap(
                adapter.authority.directions.first(where: {
                    $0.direction == .east
                })?.packetPath
            )
            let eastURL = root.appendingPathComponent(eastPath)
            let original = try Data(contentsOf: eastURL)
            try FileManager.default.removeItem(at: eastURL)
            let external = root.deletingLastPathComponent()
                .appendingPathComponent(UUID().uuidString + ".json")
            try original.write(to: external)
            try FileManager.default.createSymbolicLink(
                at: eastURL,
                withDestinationURL: external
            )
            XCTAssertThrowsError(
                try adapter.adapt(
                    .east,
                    expectedSourceSHA: try XCTUnwrap(hashes[.east])
                )
            ) {
                guard case .some(.symlink) =
                    $0 as? L4AdapterPrototypeError
                else {
                    return XCTFail("Expected symlink rejection, got \($0)")
                }
            }
            try? FileManager.default.removeItem(at: external)
        }
    }

    func testDirectionFailurePreservesPassingSiblingPackets() throws {
        try withSyntheticInputs { root, authorityData, hashes in
            let adapter = try L4AdapterPrototype(
                root: root,
                authorityData: authorityData
            )
            let baseline = adapter.adaptIndependently(hashes: hashes)
            var changedHashes = hashes
            changedHashes[.south] = String(repeating: "f", count: 64)
            let changed = adapter.adaptIndependently(hashes: changedHashes)
            XCTAssertEqual(changed.failures, [.south: .sourceHash(.south)])
            XCTAssertEqual(
                changed.packets[.east],
                baseline.packets[.east]
            )
            XCTAssertEqual(
                changed.packets[.west],
                baseline.packets[.west]
            )
            XCTAssertNil(changed.packets[.south])
            XCTAssertEqual(changed.pendingDirections, ["north"])
            XCTAssertFalse(changed.runtimeActivated)
            XCTAssertFalse(changed.shippingResourcesMutated)
            XCTAssertFalse(changed.productionSelected)
        }
    }

    func testFallbackTransformAndSiblingAliasNeverActivate() throws {
        try withSyntheticInputs { root, authorityData, hashes in
            let adapter = try L4AdapterPrototype(
                root: root,
                authorityData: authorityData
            )
            try mutateSyntheticSource(
                root: root,
                adapter: adapter,
                direction: .east
            ) { source in
                source["fallbackSourceKey"] = "legacy/fallback"
            }
            let fallbackHash = try hashAtReservedPath(
                root: root,
                adapter: adapter,
                direction: .east
            )
            XCTAssertThrowsError(
                try adapter.adapt(.east, expectedSourceSHA: fallbackHash)
            ) {
                XCTAssertEqual(
                    $0 as? L4AdapterPrototypeError,
                    .sourceDrift(.east, "semantic")
                )
            }

            try restoreSyntheticSource(
                root: root,
                adapter: adapter,
                direction: .east
            )
            try mutateSyntheticTransforms(
                root: root,
                adapter: adapter,
                direction: .south
            ) { transforms in
                transforms["mirrorX"] = transforms["identity"]
            }
            let transformHash = try hashAtReservedPath(
                root: root,
                adapter: adapter,
                direction: .south
            )
            XCTAssertThrowsError(
                try adapter.adapt(.south, expectedSourceSHA: transformHash)
            ) {
                XCTAssertEqual(
                    $0 as? L4AdapterPrototypeError,
                    .transform(.south)
                )
            }

            try restoreSyntheticSource(
                root: root,
                adapter: adapter,
                direction: .south
            )
            let east = try adapter.adapt(
                .east,
                expectedSourceSHA: try hashAtReservedPath(
                    root: root,
                    adapter: adapter,
                    direction: .east
                )
            ).packet
            try mutateSyntheticSource(
                root: root,
                adapter: adapter,
                direction: .west
            ) { source in
                source["decodedRgbaSha256"] =
                    east.source.decodedRgbaSha256
            }
            let aliasHash = try hashAtReservedPath(
                root: root,
                adapter: adapter,
                direction: .west
            )
            XCTAssertThrowsError(
                try adapter.adapt(
                    .west,
                    expectedSourceSHA: aliasHash,
                    siblingPackets: [east]
                )
            ) {
                XCTAssertEqual(
                    $0 as? L4AdapterPrototypeError,
                    .alias(.west)
                )
            }
            XCTAssertFalse(east.workerState.integrationAdmitted)
            XCTAssertFalse(east.workerState.rendererQuarantined)
            XCTAssertFalse(east.productionSelected)
        }
    }

    func testSyntheticIntegrationReceiptsQuarantineEastSouthWestWithNorthPending()
        throws
    {
        try withSyntheticInputs { root, authorityData, hashes in
            let adapter = try L4AdapterPrototype(
                root: root,
                authorityData: authorityData
            )
            let adapted = adapter.adaptIndependently(hashes: hashes)
            XCTAssertTrue(adapted.failures.isEmpty)

            var admitted: [L4AdapterSyntheticAdmittedPacket] = []
            for direction in L4AdapterDirection.allCases {
                let pair = try makeQuarantineInput(
                    root: root,
                    direction: direction,
                    packetData: try XCTUnwrap(adapted.packets[direction])
                )
                let first = try pair.harness.inspect(
                    pair.input,
                    existingPackets: admitted
                )
                let second = try pair.harness.inspect(
                    pair.input,
                    existingPackets: admitted
                )
                XCTAssertEqual(first, second)
                XCTAssertEqual(first.receiptData, second.receiptData)
                XCTAssertEqual(
                    first.receipt.direction.rawValue,
                    direction.rawValue
                )
                XCTAssertEqual(
                    first.receipt.quarantineStatus,
                    .quarantinedIncomplete
                )
                XCTAssertTrue(first.receipt.rendererQuarantined)
                XCTAssertFalse(first.receipt.productionSelected)
                XCTAssertFalse(first.receipt.runtimeMappingMutated)
                XCTAssertFalse(first.receipt.shippingResourcesMutated)
                admitted.append(first.admittedPacket)
            }

            let result =
                try L4AdapterSyntheticQuarantineHarness.validateBatch(admitted)
            XCTAssertEqual(result.status, .quarantinedIncomplete)
            XCTAssertEqual(
                result.acceptedDirections,
                [.east, .south, .west]
            )
            XCTAssertEqual(result.missingDirections, ["north"])
            XCTAssertThrowsError(
                try L4AdapterSyntheticQuarantineHarness
                    .requireReadyForAtomicAssembly(admitted)
            ) {
                XCTAssertEqual(
                    $0 as? L4AdapterSyntheticQuarantineError,
                    .incompleteDirections(["north"])
                )
            }
        }
    }

    func testSouthAdmissionDriftRejectsWithoutChangingEastWestQuarantine()
        throws
    {
        try withSyntheticInputs { root, authorityData, hashes in
            let adapter = try L4AdapterPrototype(
                root: root,
                authorityData: authorityData
            )
            let adapted = adapter.adaptIndependently(hashes: hashes)
            XCTAssertTrue(adapted.failures.isEmpty)

            var siblings: [L4AdapterSyntheticAdmittedPacket] = []
            var siblingReceipts: [Data] = []
            for direction in [L4AdapterDirection.east, .west] {
                let pair = try makeQuarantineInput(
                    root: root,
                    direction: direction,
                    packetData: try XCTUnwrap(adapted.packets[direction])
                )
                let output = try pair.harness.inspect(
                    pair.input,
                    existingPackets: siblings
                )
                siblings.append(output.admittedPacket)
                siblingReceipts.append(output.receiptData)
            }
            let siblingsBefore = siblings
            let receiptsBefore = siblingReceipts
            let resultBefore =
                try L4AdapterSyntheticQuarantineHarness.validateBatch(siblings)

            let rejected = try makeQuarantineInput(
                root: root,
                direction: .south,
                packetData: try XCTUnwrap(adapted.packets[.south]),
                admittedDecodedRgbaSha256: String(repeating: "0", count: 64)
            )
            XCTAssertThrowsError(
                try rejected.harness.inspect(
                    rejected.input,
                    existingPackets: siblings
                )
            ) {
                XCTAssertEqual(
                    $0 as? L4AdapterSyntheticQuarantineError,
                    .admissionDrift("candidateBinding")
                )
            }
            XCTAssertEqual(siblings, siblingsBefore)
            XCTAssertEqual(siblingReceipts, receiptsBefore)
            XCTAssertEqual(
                try L4AdapterSyntheticQuarantineHarness.validateBatch(
                    siblings
                ),
                resultBefore
            )

            let corrected = try makeQuarantineInput(
                root: root,
                direction: .south,
                packetData: try XCTUnwrap(adapted.packets[.south])
            )
            let acceptedSouth = try corrected.harness.inspect(
                corrected.input,
                existingPackets: siblings
            )
            siblings.append(acceptedSouth.admittedPacket)
            let final =
                try L4AdapterSyntheticQuarantineHarness.validateBatch(siblings)
            XCTAssertEqual(final.status, .quarantinedIncomplete)
            XCTAssertEqual(final.missingDirections, ["north"])
            XCTAssertTrue(acceptedSouth.receipt.rendererQuarantined)
            XCTAssertFalse(acceptedSouth.receipt.productionSelected)
            XCTAssertFalse(acceptedSouth.receipt.runtimeMappingMutated)
            XCTAssertFalse(acceptedSouth.receipt.shippingResourcesMutated)
        }
    }

    private func makeQuarantineInput(
        root: URL,
        direction: L4AdapterDirection,
        packetData: Data,
        admittedDecodedRgbaSha256: String? = nil
    ) throws -> (
        harness: L4AdapterSyntheticQuarantineHarness,
        input: L4AdapterSyntheticFileInput
    ) {
        let packet = try JSONDecoder().decode(
            L4AdapterRendererPacket.self,
            from: packetData
        )
        XCTAssertEqual(packet.direction.rawValue, direction.rawValue)

        let packetPath =
            "renderer-candidate/\(direction.rawValue)-direction-packet-v2.json"
        let packetURL = root.appending(path: packetPath)
        try writeData(packetData, to: packetURL)
        let packetSha256 = L4AdapterPrototype.sha256(packetData)

        let admission = L4AdapterSyntheticAdmission(
            schemaVersion: 1,
            disposition: "integration_source_admitted",
            integrationCommit: String(
                L4AdapterPrototype.sha256(
                    Data(
                        "integration-source-admission-\(direction.rawValue)"
                            .utf8
                    )
                ).prefix(40)
            ),
            direction: packet.direction,
            logicalID: packet.logicalID,
            workerPacket: L4AdapterArtifact(
                path: packetPath,
                sha256: packetSha256
            ),
            contentCommit: packet.source.candidateCommit,
            decodedRgbaSha256:
                admittedDecodedRgbaSha256
                ?? packet.source.decodedRgbaSha256,
            semanticValidator: packet.sourceStage.semanticValidator,
            semanticValidationResult: "PASS",
            independentTechnicalDisposition: "ACCEPT",
            literalScaleDisposition: "ACCEPT",
            rendererQuarantined: false,
            productionSelected: false
        )
        let admissionData = try L4AdapterPrototype.sortedData(admission)
        let admissionURL = root.appending(
            path:
                "integration-admission/"
                + "\(direction.rawValue)-source-admission-v1.json"
        )
        try writeData(admissionData, to: admissionURL)

        return (
            L4AdapterSyntheticQuarantineHarness(root: root),
            L4AdapterSyntheticFileInput(
                packetURL: packetURL,
                packetSha256: packetSha256,
                admissionURL: admissionURL,
                admissionSha256:
                    L4AdapterPrototype.sha256(admissionData)
            )
        )
    }

    private func writeData(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    private func withSyntheticInputs(
        _ body: (
            URL,
            Data,
            [L4AdapterDirection: String]
        ) throws -> Void
    ) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "play073-l4-source-stage-adapter-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        let repo = try repositoryRoot()
        let authorityData = try Data(
            contentsOf: repo.appendingPathComponent(
                L4AdapterPrototype.authorityPath
            )
        )
        let adapter = try L4AdapterPrototype(
            root: root,
            authorityData: authorityData
        )
        var hashes: [L4AdapterDirection: String] = [:]
        for direction in L4AdapterDirection.allCases {
            try restoreSyntheticSource(
                root: root,
                adapter: adapter,
                direction: direction
            )
            hashes[direction] = try hashAtReservedPath(
                root: root,
                adapter: adapter,
                direction: direction
            )
        }
        try body(root, authorityData, hashes)
    }

    private func restoreSyntheticSource(
        root: URL,
        adapter: L4AdapterPrototype,
        direction: L4AdapterDirection
    ) throws {
        let locator = try XCTUnwrap(
            adapter.authority.directions.first(where: {
                $0.direction == direction
            })
        )
        let data = try L4AdapterPrototype.sortedData(
            syntheticSource(direction: direction, locator: locator)
        )
        let target = root.appendingPathComponent(locator.packetPath)
        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: target, options: .atomic)
    }

    private func syntheticSource(
        direction: L4AdapterDirection,
        locator: L4AdapterLocatorEntry
    ) -> L4AdapterSourceStage {
        let seed = direction.rawValue
        let hash: (String) -> String = {
            L4AdapterPrototype.sha256(Data("\(seed)-\($0)".utf8))
        }
        let lods = Dictionary(
            uniqueKeysWithValues: L4AdapterPrototype.lodOrder.map { detail in
                (
                    detail,
                    L4AdapterLOD(
                        path:
                            "\(locator.evidenceRoot)/normalized/\(detail).png",
                        sha256: hash("\(detail)-file"),
                        decodedRgbaSha256: hash("\(detail)-rgba"),
                        canvasPixels:
                            L4AdapterPrototype.lodSizes[detail]!
                    )
                )
            }
        )
        var transformFingerprints = Dictionary(
            uniqueKeysWithValues:
                L4AdapterPrototype.transformKeys.sorted().map {
                    ($0, hash("transform-\($0)"))
                }
        )
        transformFingerprints["identity"] = hash("source-rgba")
        return L4AdapterSourceStage(
            schemaVersion: 2,
            stage: "source_candidate",
            identity: L4AdapterIdentity(
                taskId: locator.taskId,
                direction: direction,
                branch: locator.branch,
                logicalID: "industrial_l04_v0_\(direction.rawValue)",
                sourceKey:
                    "industrial_l04/variant-0/\(direction.rawValue)/source-v99",
                sourceRoot:
                    "Native/CitySimNative/WorldArt/Blender/\(locator.taskId)/synthetic",
                evidenceRoot: locator.evidenceRoot
            ),
            authorities: L4AdapterAuthorities(
                contract021: L4AdapterPrototype.contract,
                directionBridge: L4AdapterPrototype.directionBridge,
                appearanceLock: L4AdapterAppearance(
                    documentPath:
                        "docs/production/evidence/INTEGRATION/synthetic-appearance-lock.json",
                    commit: commonHash("appearance-commit")
                        .prefix(40).description,
                    documentSha256: commonHash("appearance-document"),
                    northProcessASourceSha256: commonHash("north-source"),
                    northProcessADecodedRgbaSha256:
                        commonHash("north-rgba")
                ),
                semanticValidator:
                    L4AdapterPrototype.sourceStage.semanticValidator,
                canonicalDecoder:
                    L4AdapterPrototype.sourceStage.canonicalDecoder,
                nonAliasLoader:
                    L4AdapterPrototype.sourceStage.nonAliasLoader
            ),
            inputs: L4AdapterInputs(
                runnerContract: L4AdapterArtifact(
                    path:
                        "\(locator.evidenceRoot)/synthetic-runner-contract.json",
                    sha256: hash("runner")
                )
            ),
            completion: L4AdapterCompletion(
                contentCommit: hash("content").prefix(40).description,
                source: L4AdapterSource(
                    decodedRgbaSha256: hash("source-rgba"),
                    authoredGeometrySha256: hash("geometry"),
                    componentManifestSha256: hash("components"),
                    fallbackSourceKey: nil
                ),
                selectedSource: L4AdapterArtifact(
                    path: "\(locator.evidenceRoot)/raw/source.png",
                    sha256: hash("raw-file")
                ),
                lods: lods,
                registration: L4AdapterRegistration(
                    footprintTiles: [1, 1],
                    canvasPixels: [1536, 1024],
                    groundPivotSource: [768, 896],
                    frontageSocketSource:
                        L4AdapterPrototype.sockets[direction]!,
                    frontageEdge: direction,
                    supportedOrientation:
                        "\(direction.rawValue)-facing-authored",
                    occupiedBounds: L4AdapterBounds(
                        minX: 384,
                        minY: 256,
                        maxX: 1152,
                        maxY: 896
                    ),
                    groundContactPolygonWorld: [
                        [0, 13.5], [27, 0], [0, -13.5], [-27, 0],
                    ],
                    contactDeclaration: "registered_ground_pivot",
                    shadowDirection: "southeast",
                    alpha: L4AdapterAlpha(
                        nonzeroPixelCount: 100_000,
                        hiddenRgbPixelCount: 0,
                        nearChromaPixelCount: 0
                    )
                ),
                transformFingerprints: transformFingerprints,
                validation: L4AdapterValidation(
                    receipt:
                        L4AdapterArtifact(
                            path:
                                "\(locator.evidenceRoot)/NORMALIZATION-VALIDATION.json",
                            sha256: hash("normalization")
                        ),
                    result: "PASS",
                    allGatesPassed: true
                ),
                reviewManifest: L4AdapterArtifact(
                    path: "\(locator.evidenceRoot)/REVIEW-MANIFEST.json",
                    sha256: hash("review")
                )
            ),
            candidateReadyForIndependentReview: true,
            sourceReady: false,
            integrationAdmitted: false,
            rendererQuarantined: false,
            productionSelected: false
        )
    }

    private func mutateSyntheticSource(
        root: URL,
        adapter: L4AdapterPrototype,
        direction: L4AdapterDirection,
        mutation: (inout [String: Any]) -> Void
    ) throws {
        try mutateReservedJSON(
            root: root,
            adapter: adapter,
            direction: direction
        ) { document in
            var completion =
                document["completion"] as? [String: Any] ?? [:]
            var source = completion["source"] as? [String: Any] ?? [:]
            mutation(&source)
            completion["source"] = source
            document["completion"] = completion
        }
    }

    private func mutateSyntheticTransforms(
        root: URL,
        adapter: L4AdapterPrototype,
        direction: L4AdapterDirection,
        mutation: (inout [String: String]) -> Void
    ) throws {
        try mutateReservedJSON(
            root: root,
            adapter: adapter,
            direction: direction
        ) { document in
            var completion =
                document["completion"] as? [String: Any] ?? [:]
            var transforms =
                completion["transformFingerprints"] as? [String: String] ?? [:]
            mutation(&transforms)
            completion["transformFingerprints"] = transforms
            document["completion"] = completion
        }
    }

    private func mutateReservedJSON(
        root: URL,
        adapter: L4AdapterPrototype,
        direction: L4AdapterDirection,
        mutation: (inout [String: Any]) -> Void
    ) throws {
        let path = try XCTUnwrap(
            adapter.authority.directions.first(where: {
                $0.direction == direction
            })?.packetPath
        )
        let url = root.appendingPathComponent(path)
        var document = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(contentsOf: url)
            ) as? [String: Any]
        )
        mutation(&document)
        let data = try JSONSerialization.data(
            withJSONObject: document,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: url, options: .atomic)
    }

    private func hashAtReservedPath(
        root: URL,
        adapter: L4AdapterPrototype,
        direction: L4AdapterDirection
    ) throws -> String {
        let path = try XCTUnwrap(
            adapter.authority.directions.first(where: {
                $0.direction == direction
            })?.packetPath
        )
        return L4AdapterPrototype.sha256(
            try Data(contentsOf: root.appendingPathComponent(path))
        )
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
        throw L4AdapterPrototypeError.unsafePath("repositoryRoot")
    }

    private func commonHash(_ value: String) -> String {
        L4AdapterPrototype.sha256(Data("shared-\(value)".utf8))
    }
}
