import CryptoKit
import Foundation
import XCTest
@testable import CitySimNative

@MainActor
final class IndustrialL4DirectionQuarantineMatrixTests: XCTestCase {
    func testZeroThroughFourMutationMatrixPreservesSiblingsAndRuntimeInactivity() throws {
        let validator = makeValidator()
        var quarantine = IndustrialL4DirectionQuarantine()
        var preserved: [IndustrialL4PacketDirection: IndustrialL4DirectionPacket] = [:]
        let catalogBefore = WorldAssetCatalog()

        let zero = try quarantine.result(validator: validator)
        XCTAssertEqual(zero.status, .inactive)
        XCTAssertEqual(zero.acceptedDirections, [])
        XCTAssertEqual(zero.missingDirections, IndustrialL4PacketDirection.allCases)
        XCTAssertThrowsError(
            try validator.requireReadyForAtomicAssembly([])
        ) {
            XCTAssertEqual(
                $0 as? IndustrialL4DirectionPacketValidationError,
                .missingDirections(["north", "east", "south", "west"])
            )
        }

        for (index, direction) in IndustrialL4PacketDirection.allCases.enumerated() {
            let packet = IndustrialL4DirectionPacketFactory.packet(direction)
            quarantine = try quarantine.admitting(packet, validator: validator)
            preserved[direction] = packet
            let result = try quarantine.result(validator: validator)

            XCTAssertEqual(
                result.status,
                index == 3 ? .readyForAtomicAssembly : .quarantinedIncomplete
            )
            XCTAssertEqual(
                result.acceptedDirections,
                Array(IndustrialL4PacketDirection.allCases.prefix(index + 1))
            )
            XCTAssertEqual(
                result.missingDirections,
                Array(IndustrialL4PacketDirection.allCases.dropFirst(index + 1))
            )
            for (acceptedDirection, acceptedPacket) in preserved {
                XCTAssertEqual(quarantine.packets[acceptedDirection], acceptedPacket)
                XCTAssertFalse(acceptedPacket.productionSelected)
            }

            if index < 3 {
                XCTAssertThrowsError(
                    try validator.requireReadyForAtomicAssembly(
                        Array(quarantine.packets.values)
                    )
                ) {
                    XCTAssertEqual(
                        $0 as? IndustrialL4DirectionPacketValidationError,
                        .missingDirections(result.missingDirections.map(\.rawValue))
                    )
                }
            } else {
                XCTAssertEqual(
                    try validator.requireReadyForAtomicAssembly(
                        Array(quarantine.packets.values)
                    ),
                    result
                )
            }

            assertRuntimeRemainsInactive()
        }

        let catalogAfter = WorldAssetCatalog()
        XCTAssertEqual(
            catalogBefore.generatedManifest?.assets.map(\.logicalID),
            catalogAfter.generatedManifest?.assets.map(\.logicalID)
        )
        XCTAssertEqual(
            catalogBefore.generatedManifest?.assets
                .filter { $0.family == "industrial" }
                .compactMap(\.level)
                .max(),
            3
        )
    }

    func testMutationMatrixReplaysByteIdentically() throws {
        let first = try replayLedger()
        let second = try replayLedger()
        XCTAssertEqual(first, second)
        XCTAssertEqual(sha256(first), sha256(second))
    }

    func testBatchRejectsDirectionSourceLODAndTransformedSiblingAliases() throws {
        let validator = makeValidator()
        let north = IndustrialL4DirectionPacketFactory.packet(.north)
        let east = IndustrialL4DirectionPacketFactory.packet(.east)

        XCTAssertThrowsError(try validator.validateBatch([north, north])) {
            XCTAssertEqual(
                $0 as? IndustrialL4DirectionPacketValidationError,
                .duplicateDirection("north")
            )
        }

        let sourceAlias = IndustrialL4DirectionPacketFactory.replacing(
            east,
            source: IndustrialL4SourceBinding(
                candidateCommit: east.source.candidateCommit,
                sourceKey: east.source.sourceKey,
                decodedRgbaSha256: north.source.decodedRgbaSha256,
                authoredGeometrySha256: east.source.authoredGeometrySha256,
                componentManifestSha256: east.source.componentManifestSha256,
                fallbackSourceKey: nil
            ),
            transformFingerprints: IndustrialL4TransformFingerprints(
                identity: north.source.decodedRgbaSha256,
                rotate90: east.transformFingerprints.rotate90,
                rotate180: east.transformFingerprints.rotate180,
                rotate270: east.transformFingerprints.rotate270,
                mirrorX: east.transformFingerprints.mirrorX,
                mirrorY: east.transformFingerprints.mirrorY,
                mirrorDiagonal: east.transformFingerprints.mirrorDiagonal,
                mirrorAntiDiagonal: east.transformFingerprints.mirrorAntiDiagonal
            )
        )
        XCTAssertThrowsError(try validator.validateBatch([north, sourceAlias])) {
            XCTAssertEqual(
                $0 as? IndustrialL4DirectionPacketValidationError,
                .sourceAlias("decodedRgbaSha256")
            )
        }

        var aliasedLODs = east.lods
        aliasedLODs[0] = IndustrialL4LODIdentity(
            detail: aliasedLODs[0].detail,
            normalizedRgbaSha256: north.lods[0].normalizedRgbaSha256,
            canvasPixels: aliasedLODs[0].canvasPixels
        )
        let lodAlias = IndustrialL4DirectionPacketFactory.replacing(
            east,
            lods: aliasedLODs
        )
        XCTAssertThrowsError(try validator.validateBatch([north, lodAlias])) {
            XCTAssertEqual(
                $0 as? IndustrialL4DirectionPacketValidationError,
                .lodAlias
            )
        }

        let transformed = IndustrialL4DirectionPacketFactory.replacing(
            east,
            source: IndustrialL4SourceBinding(
                candidateCommit: east.source.candidateCommit,
                sourceKey: east.source.sourceKey,
                decodedRgbaSha256: north.transformFingerprints.rotate90,
                authoredGeometrySha256: east.source.authoredGeometrySha256,
                componentManifestSha256: east.source.componentManifestSha256,
                fallbackSourceKey: nil
            ),
            transformFingerprints: IndustrialL4TransformFingerprints(
                identity: north.transformFingerprints.rotate90,
                rotate90: east.transformFingerprints.rotate90,
                rotate180: east.transformFingerprints.rotate180,
                rotate270: east.transformFingerprints.rotate270,
                mirrorX: east.transformFingerprints.mirrorX,
                mirrorY: east.transformFingerprints.mirrorY,
                mirrorDiagonal: east.transformFingerprints.mirrorDiagonal,
                mirrorAntiDiagonal: east.transformFingerprints.mirrorAntiDiagonal
            )
        )
        XCTAssertThrowsError(try validator.validateBatch([north, transformed])) {
            XCTAssertEqual(
                $0 as? IndustrialL4DirectionPacketValidationError,
                .transformedSibling("north", "east")
            )
        }
    }

    func testPacketRejectsDriftFallbackAndProductionSelection() throws {
        let validator = makeValidator()
        let north = IndustrialL4DirectionPacketFactory.packet(.north)

        let wrongContract = IndustrialL4DirectionPacketFactory.replacing(
            north,
            governingContract: IndustrialL4ContractBinding(
                path: north.governingContract.path,
                revision: 3,
                sha256: north.governingContract.sha256
            )
        )
        assertRejected(wrongContract, as: .contractDrift, validator: validator)

        let wrongLock = IndustrialL4DirectionPacketFactory.replacing(
            north,
            appearanceLock: IndustrialL4AppearanceLock(
                documentPath: north.appearanceLock.documentPath,
                commit: IndustrialL4DirectionPacketFactory.commit("wrong-lock"),
                documentSha256: north.appearanceLock.documentSha256,
                northProcessASourceSha256:
                    north.appearanceLock.northProcessASourceSha256,
                northProcessADecodedRgbaSha256:
                    north.appearanceLock.northProcessADecodedRgbaSha256
            )
        )
        assertRejected(wrongLock, as: .appearanceLockDrift, validator: validator)

        let incompleteProvenance = IndustrialL4DirectionPacketFactory.replacing(
            north,
            provenance: IndustrialL4Provenance(
                sourceManifest: IndustrialL4ArtifactBinding(
                    path: "",
                    sha256: north.provenance.sourceManifest.sha256
                ),
                toolchain: north.provenance.toolchain,
                normalizationReceipt: north.provenance.normalizationReceipt
            )
        )
        assertRejected(
            incompleteProvenance,
            as: .incompleteProvenance("sourceManifest"),
            validator: validator
        )

        let registrationDrift = IndustrialL4DirectionPacketFactory.replacing(
            north,
            registration: IndustrialL4Registration(
                footprintTiles: north.registration.footprintTiles,
                canvasPixels: north.registration.canvasPixels,
                groundPivotSource: north.registration.groundPivotSource,
                entranceSocketWorld: north.registration.entranceSocketWorld,
                frontageEdge: "south",
                supportedOrientation: north.registration.supportedOrientation,
                occupiedBounds: north.registration.occupiedBounds,
                groundContactPolygonWorld:
                    north.registration.groundContactPolygonWorld,
                contactDeclaration: north.registration.contactDeclaration,
                shadowDirection: north.registration.shadowDirection,
                alpha: north.registration.alpha
            )
        )
        assertRejected(
            registrationDrift,
            as: .registrationDrift("north"),
            validator: validator
        )

        let fallback = IndustrialL4DirectionPacketFactory.replacing(
            north,
            source: IndustrialL4SourceBinding(
                candidateCommit: north.source.candidateCommit,
                sourceKey: north.source.sourceKey,
                decodedRgbaSha256: north.source.decodedRgbaSha256,
                authoredGeometrySha256: north.source.authoredGeometrySha256,
                componentManifestSha256: north.source.componentManifestSha256,
                fallbackSourceKey: "industrial_l03_v0_north"
            )
        )
        assertRejected(fallback, as: .fallbackReference, validator: validator)

        assertRejected(
            IndustrialL4DirectionPacketFactory.replacing(
                north,
                sourceReady: false
            ),
            as: .sourceNotReady,
            validator: validator
        )
        assertRejected(
            IndustrialL4DirectionPacketFactory.replacing(
                north,
                productionSelected: true
            ),
            as: .productionSelected,
            validator: validator
        )
    }

    private func makeValidator() -> IndustrialL4DirectionPacketValidator {
        IndustrialL4DirectionPacketValidator(
            appearanceLock: IndustrialL4DirectionPacketFactory.appearanceLock
        )
    }

    private func assertRejected(
        _ packet: IndustrialL4DirectionPacket,
        as expected: IndustrialL4DirectionPacketValidationError,
        validator: IndustrialL4DirectionPacketValidator,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try validator.validate(packet),
            file: file,
            line: line
        ) {
            XCTAssertEqual(
                $0 as? IndustrialL4DirectionPacketValidationError,
                expected,
                file: file,
                line: line
            )
        }
    }

    private func assertRuntimeRemainsInactive(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let catalog = WorldAssetCatalog()
        for direction in IndustrialL4PacketDirection.allCases {
            XCTAssertNil(
                catalog.generatedAsset(
                    logicalID: "industrial_l04_v0_\(direction.rawValue)"
                ),
                file: file,
                line: line
            )
        }
        for edge in RoadConnectionMask.cardinalEdges {
            XCTAssertNil(
                IndustrialGeneratedAssetIdentity(level: 4, adjacentRoads: edge),
                file: file,
                line: line
            )
        }
    }

    private func replayLedger() throws -> Data {
        let validator = makeValidator()
        var quarantine = IndustrialL4DirectionQuarantine()
        var results: [IndustrialL4QuarantineResult] = [
            try quarantine.result(validator: validator)
        ]
        for direction in IndustrialL4PacketDirection.allCases {
            quarantine = try quarantine.admitting(
                IndustrialL4DirectionPacketFactory.packet(direction),
                validator: validator
            )
            results.append(try quarantine.result(validator: validator))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(results)
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
