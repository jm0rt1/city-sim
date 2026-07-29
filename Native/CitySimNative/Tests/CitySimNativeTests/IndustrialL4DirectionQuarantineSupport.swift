import CryptoKit
import Foundation

enum IndustrialL4PacketDirection: String, Codable, CaseIterable, Hashable {
    case north
    case east
    case south
    case west
}

struct IndustrialL4DirectionPacket: Codable, Equatable {
    let schemaVersion: Int
    let family: String
    let level: Int
    let variant: Int
    let direction: IndustrialL4PacketDirection
    let logicalID: String
    let governingContract: IndustrialL4ContractBinding
    let appearanceLock: IndustrialL4AppearanceLock
    let source: IndustrialL4SourceBinding
    let lods: [IndustrialL4LODIdentity]
    let provenance: IndustrialL4Provenance
    let registration: IndustrialL4Registration
    let transformFingerprints: IndustrialL4TransformFingerprints
    let sourceReady: Bool
    let productionSelected: Bool
    let quarantineDisposition: String
}

struct IndustrialL4ContractBinding: Codable, Equatable {
    let path: String
    let revision: Int
    let sha256: String
}

struct IndustrialL4AppearanceLock: Codable, Equatable {
    let documentPath: String
    let commit: String
    let documentSha256: String
    let northProcessASourceSha256: String
    let northProcessADecodedRgbaSha256: String
}

struct IndustrialL4SourceBinding: Codable, Equatable {
    let candidateCommit: String
    let sourceKey: String
    let decodedRgbaSha256: String
    let authoredGeometrySha256: String
    let componentManifestSha256: String
    let fallbackSourceKey: String?
}

struct IndustrialL4LODIdentity: Codable, Equatable {
    let detail: String
    let normalizedRgbaSha256: String
    let canvasPixels: [Int]
}

struct IndustrialL4ArtifactBinding: Codable, Equatable {
    let path: String
    let sha256: String
}

struct IndustrialL4Provenance: Codable, Equatable {
    let sourceManifest: IndustrialL4ArtifactBinding
    let toolchain: IndustrialL4ArtifactBinding
    let normalizationReceipt: IndustrialL4ArtifactBinding
}

struct IndustrialL4Registration: Codable, Equatable {
    let footprintTiles: [Int]
    let canvasPixels: [Int]
    let groundPivotSource: [Int]
    let entranceSocketWorld: [Double]
    let frontageEdge: String
    let supportedOrientation: String
    let occupiedBounds: IndustrialL4PixelBounds
    let groundContactPolygonWorld: [[Double]]
    let contactDeclaration: String
    let shadowDirection: String
    let alpha: IndustrialL4AlphaEvidence
}

struct IndustrialL4PixelBounds: Codable, Equatable {
    let minX: Int
    let minY: Int
    let maxX: Int
    let maxY: Int
}

struct IndustrialL4AlphaEvidence: Codable, Equatable {
    let nonzeroPixelCount: Int
    let hiddenRgbPixelCount: Int
    let nearChromaPixelCount: Int
}

struct IndustrialL4TransformFingerprints: Codable, Equatable {
    let identity: String
    let rotate90: String
    let rotate180: String
    let rotate270: String
    let mirrorX: String
    let mirrorY: String
    let mirrorDiagonal: String
    let mirrorAntiDiagonal: String

    var all: [String] {
        [
            identity,
            rotate90,
            rotate180,
            rotate270,
            mirrorX,
            mirrorY,
            mirrorDiagonal,
            mirrorAntiDiagonal,
        ]
    }

    var transformed: Set<String> {
        Set(all.dropFirst())
    }
}

enum IndustrialL4DirectionPacketValidationError: Error, Equatable {
    case invalidField(String)
    case contractDrift
    case appearanceLockDrift
    case incompleteProvenance(String)
    case registrationDrift(String)
    case invalidLODSet
    case duplicateLODHash
    case invalidTransformFingerprints
    case fallbackReference
    case sourceNotReady
    case productionSelected
    case invalidDisposition
}

struct IndustrialL4DirectionPacketValidator {
    static let contract = IndustrialL4ContractBinding(
        path: "docs/production/decisions/CONTRACT-021-parallel-directional-art-cells.md",
        revision: 2,
        sha256: "f80844c928d904498510b8b151381f40315e072d52d81695aafcd6b91081ae4c"
    )

    let appearanceLock: IndustrialL4AppearanceLock

    func validate(_ packet: IndustrialL4DirectionPacket) throws {
        guard packet.schemaVersion == 1 else {
            throw IndustrialL4DirectionPacketValidationError.invalidField("schemaVersion")
        }
        guard packet.family == "industrial", packet.level == 4, packet.variant == 0 else {
            throw IndustrialL4DirectionPacketValidationError.invalidField("familyIdentity")
        }
        guard packet.logicalID == "industrial_l04_v0_\(packet.direction.rawValue)" else {
            throw IndustrialL4DirectionPacketValidationError.invalidField("logicalID")
        }
        guard packet.governingContract == Self.contract else {
            throw IndustrialL4DirectionPacketValidationError.contractDrift
        }
        guard packet.appearanceLock == appearanceLock else {
            throw IndustrialL4DirectionPacketValidationError.appearanceLockDrift
        }

        try validateCommit(packet.source.candidateCommit, field: "source.candidateCommit")
        try validateSHA(packet.source.decodedRgbaSha256, field: "source.decodedRgbaSha256")
        try validateSHA(
            packet.source.authoredGeometrySha256,
            field: "source.authoredGeometrySha256"
        )
        try validateSHA(
            packet.source.componentManifestSha256,
            field: "source.componentManifestSha256"
        )
        guard !packet.source.sourceKey.isEmpty else {
            throw IndustrialL4DirectionPacketValidationError.invalidField("source.sourceKey")
        }
        guard packet.source.fallbackSourceKey == nil else {
            throw IndustrialL4DirectionPacketValidationError.fallbackReference
        }

        let lodGroups = Dictionary(grouping: packet.lods, by: \.detail)
        let expectedSizes = [
            "city": [256, 171],
            "neighborhood": [512, 342],
            "block": [1024, 683],
        ]
        guard packet.lods.count == 3,
              Set(lodGroups.keys) == Set(expectedSizes.keys),
              lodGroups.values.allSatisfy({ $0.count == 1 })
        else {
            throw IndustrialL4DirectionPacketValidationError.invalidLODSet
        }
        for (detail, expectedSize) in expectedSizes {
            guard let lod = lodGroups[detail]?.first, lod.canvasPixels == expectedSize else {
                throw IndustrialL4DirectionPacketValidationError.invalidLODSet
            }
            try validateSHA(
                lod.normalizedRgbaSha256,
                field: "lods.\(detail).normalizedRgbaSha256"
            )
        }
        guard Set(packet.lods.map(\.normalizedRgbaSha256)).count == 3 else {
            throw IndustrialL4DirectionPacketValidationError.duplicateLODHash
        }

        try validateArtifact(packet.provenance.sourceManifest, field: "sourceManifest")
        try validateArtifact(packet.provenance.toolchain, field: "toolchain")
        try validateArtifact(
            packet.provenance.normalizationReceipt,
            field: "normalizationReceipt"
        )
        try validateRegistration(packet)

        guard packet.transformFingerprints.identity == packet.source.decodedRgbaSha256,
              packet.transformFingerprints.all.count == 8,
              Set(packet.transformFingerprints.all).count == 8
        else {
            throw IndustrialL4DirectionPacketValidationError.invalidTransformFingerprints
        }
        for hash in packet.transformFingerprints.all {
            try validateSHA(hash, field: "transformFingerprints")
        }

        guard packet.sourceReady else {
            throw IndustrialL4DirectionPacketValidationError.sourceNotReady
        }
        guard !packet.productionSelected else {
            throw IndustrialL4DirectionPacketValidationError.productionSelected
        }
        guard packet.quarantineDisposition == "accepted_direction_quarantine" else {
            throw IndustrialL4DirectionPacketValidationError.invalidDisposition
        }
    }

    private func validateRegistration(_ packet: IndustrialL4DirectionPacket) throws {
        let registration = packet.registration
        let expectedSockets: [IndustrialL4PacketDirection: [Double]] = [
            .north: [18, 9],
            .east: [18, -9],
            .south: [-18, -9],
            .west: [-18, 9],
        ]
        guard registration.footprintTiles == [1, 1],
              registration.canvasPixels == [1536, 1024],
              registration.groundPivotSource == [768, 896],
              registration.entranceSocketWorld == expectedSockets[packet.direction],
              registration.frontageEdge == packet.direction.rawValue,
              registration.supportedOrientation ==
                "\(packet.direction.rawValue)-facing-authored",
              registration.groundContactPolygonWorld ==
                [[0, 13.5], [27, 0], [0, -13.5], [-27, 0]],
              registration.contactDeclaration == "registered_ground_pivot",
              registration.shadowDirection == "southeast"
        else {
            throw IndustrialL4DirectionPacketValidationError.registrationDrift(
                packet.direction.rawValue
            )
        }

        let bounds = registration.occupiedBounds
        guard bounds.minX >= 0,
              bounds.minY >= 0,
              bounds.maxX > bounds.minX,
              bounds.maxY > bounds.minY,
              bounds.maxX <= registration.canvasPixels[0],
              bounds.maxY <= registration.canvasPixels[1],
              registration.alpha.nonzeroPixelCount > 0,
              registration.alpha.hiddenRgbPixelCount == 0,
              registration.alpha.nearChromaPixelCount == 0
        else {
            throw IndustrialL4DirectionPacketValidationError.registrationDrift(
                packet.direction.rawValue
            )
        }
    }

    private func validateArtifact(
        _ artifact: IndustrialL4ArtifactBinding,
        field: String
    ) throws {
        guard !artifact.path.isEmpty else {
            throw IndustrialL4DirectionPacketValidationError.incompleteProvenance(field)
        }
        do {
            try validateSHA(artifact.sha256, field: field)
        } catch {
            throw IndustrialL4DirectionPacketValidationError.incompleteProvenance(field)
        }
    }

    private func validateSHA(_ value: String, field: String) throws {
        guard value.count == 64, value.allSatisfy(\.isLowercaseHexDigit) else {
            throw IndustrialL4DirectionPacketValidationError.invalidField(field)
        }
    }

    private func validateCommit(_ value: String, field: String) throws {
        guard value.count == 40, value.allSatisfy(\.isLowercaseHexDigit) else {
            throw IndustrialL4DirectionPacketValidationError.invalidField(field)
        }
    }
}

enum IndustrialL4DirectionPacketFactory {
    static let appearanceLock = IndustrialL4AppearanceLock(
        documentPath: "docs/production/evidence/INTEGRATION/future-industrial-l04-lock.md",
        commit: commit("appearance-lock"),
        documentSha256: sha("appearance-lock-document"),
        northProcessASourceSha256: sha("appearance-lock-north-source"),
        northProcessADecodedRgbaSha256: sha("appearance-lock-north-rgba")
    )

    static func packet(
        _ direction: IndustrialL4PacketDirection
    ) -> IndustrialL4DirectionPacket {
        let root = "synthetic-\(direction.rawValue)"
        let decoded = sha("\(root)-decoded-rgba")
        let sockets: [IndustrialL4PacketDirection: [Double]] = [
            .north: [18, 9],
            .east: [18, -9],
            .south: [-18, -9],
            .west: [-18, 9],
        ]
        return IndustrialL4DirectionPacket(
            schemaVersion: 1,
            family: "industrial",
            level: 4,
            variant: 0,
            direction: direction,
            logicalID: "industrial_l04_v0_\(direction.rawValue)",
            governingContract: IndustrialL4DirectionPacketValidator.contract,
            appearanceLock: appearanceLock,
            source: IndustrialL4SourceBinding(
                candidateCommit: commit("\(root)-commit"),
                sourceKey: "world-art/industrial-l04/\(direction.rawValue)/source",
                decodedRgbaSha256: decoded,
                authoredGeometrySha256: sha("\(root)-geometry"),
                componentManifestSha256: sha("\(root)-components"),
                fallbackSourceKey: nil
            ),
            lods: [
                IndustrialL4LODIdentity(
                    detail: "city",
                    normalizedRgbaSha256: sha("\(root)-lod-city"),
                    canvasPixels: [256, 171]
                ),
                IndustrialL4LODIdentity(
                    detail: "neighborhood",
                    normalizedRgbaSha256: sha("\(root)-lod-neighborhood"),
                    canvasPixels: [512, 342]
                ),
                IndustrialL4LODIdentity(
                    detail: "block",
                    normalizedRgbaSha256: sha("\(root)-lod-block"),
                    canvasPixels: [1024, 683]
                ),
            ],
            provenance: IndustrialL4Provenance(
                sourceManifest: IndustrialL4ArtifactBinding(
                    path: "evidence/\(direction.rawValue)/SOURCE-MANIFEST.json",
                    sha256: sha("\(root)-source-manifest")
                ),
                toolchain: IndustrialL4ArtifactBinding(
                    path: "evidence/\(direction.rawValue)/TOOLCHAIN.json",
                    sha256: sha("\(root)-toolchain")
                ),
                normalizationReceipt: IndustrialL4ArtifactBinding(
                    path: "evidence/\(direction.rawValue)/NORMALIZATION.json",
                    sha256: sha("\(root)-normalization")
                )
            ),
            registration: IndustrialL4Registration(
                footprintTiles: [1, 1],
                canvasPixels: [1536, 1024],
                groundPivotSource: [768, 896],
                entranceSocketWorld: sockets[direction]!,
                frontageEdge: direction.rawValue,
                supportedOrientation: "\(direction.rawValue)-facing-authored",
                occupiedBounds: IndustrialL4PixelBounds(
                    minX: 512,
                    minY: 480,
                    maxX: 1024,
                    maxY: 896
                ),
                groundContactPolygonWorld: [
                    [0, 13.5],
                    [27, 0],
                    [0, -13.5],
                    [-27, 0],
                ],
                contactDeclaration: "registered_ground_pivot",
                shadowDirection: "southeast",
                alpha: IndustrialL4AlphaEvidence(
                    nonzeroPixelCount: 100_000 + direction.ordinal,
                    hiddenRgbPixelCount: 0,
                    nearChromaPixelCount: 0
                )
            ),
            transformFingerprints: IndustrialL4TransformFingerprints(
                identity: decoded,
                rotate90: sha("\(root)-rotate90"),
                rotate180: sha("\(root)-rotate180"),
                rotate270: sha("\(root)-rotate270"),
                mirrorX: sha("\(root)-mirror-x"),
                mirrorY: sha("\(root)-mirror-y"),
                mirrorDiagonal: sha("\(root)-mirror-diagonal"),
                mirrorAntiDiagonal: sha("\(root)-mirror-antidiagonal")
            ),
            sourceReady: true,
            productionSelected: false,
            quarantineDisposition: "accepted_direction_quarantine"
        )
    }

    static func sha(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func commit(_ value: String) -> String {
        String(sha(value).prefix(40))
    }
}

private extension IndustrialL4PacketDirection {
    var ordinal: Int {
        switch self {
        case .north: 1
        case .east: 2
        case .south: 3
        case .west: 4
        }
    }
}

private extension Character {
    var isLowercaseHexDigit: Bool {
        isNumber || ("a"..."f").contains(String(self))
    }
}
