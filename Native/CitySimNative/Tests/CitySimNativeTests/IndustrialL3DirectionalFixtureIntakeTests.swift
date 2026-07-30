import CryptoKit
import Foundation
import XCTest
@testable import CitySimNative

@MainActor
final class IndustrialL3DirectionalFixtureIntakeTests: XCTestCase {
    private struct Placement {
        let coordinate: GridCoordinate
        let road: GridCoordinate
        let direction: String
        let mask: RoadConnectionMask
        let logicalID: String
    }

    private let fixtureSHA256 =
        "b8875422a277b59f6797aef03ca93175a502df5963a5c972684ca47be40e7aa5"
    private let stateDigest =
        "dbe6860011f43063a39e228531db4b49303d64a918e7884301b3de80360dd97f"
    private let placements = [
        Placement(
            coordinate: GridCoordinate(x: 10, y: 10),
            road: GridCoordinate(x: 10, y: 9),
            direction: "north",
            mask: .north,
            logicalID: "industrial_l03_v0_north"
        ),
        Placement(
            coordinate: GridCoordinate(x: 3, y: 9),
            road: GridCoordinate(x: 4, y: 9),
            direction: "east",
            mask: .east,
            logicalID: "industrial_l03_v0_east"
        ),
        Placement(
            coordinate: GridCoordinate(x: 4, y: 8),
            road: GridCoordinate(x: 4, y: 9),
            direction: "south",
            mask: .south,
            logicalID: "industrial_l03_v0_south"
        ),
        Placement(
            coordinate: GridCoordinate(x: 17, y: 11),
            road: GridCoordinate(x: 16, y: 11),
            direction: "west",
            mask: .west,
            logicalID: "industrial_l03_v0_west"
        ),
    ]
    private let sourceHashes = [
        "north": "91b3fb983e294eeff288b13f6d89a19366393cfaf084b52527633e88ed0507ea",
        "east": "5ba539536c4363d71ddae79a128f42bfd8e22cce248f4aa0c852dd22a24fb84e",
        "south": "5267ef34929114af987ec586cb4802fa5316f4383ecac4ae6807a7be099baed5",
        "west": "ceaa2948be0f37cbd8f6288c9c125f15502a864ce683bc3eaa1cd0d7563477d4",
    ]
    private let normalizedHashes = [
        "north": [
            "block": "87123d62629b1ddd39a893f8043e0e45c3f533f3148e9bec40a11b18e1d13500",
            "neighborhood": "4da44d259ea8e9a93a9a197f6500dabd11d0f325c4ab2c0cf6294b023860b4f1",
            "city": "4854da095d10d0f2f77b3eb8ec9a468b18666081ff415d2c50b0e08f7e6ce500",
        ],
        "east": [
            "block": "5e02d83a0b4f929584ab0a240ac9661f055ea1e1e371810d39077ad6d169e6ba",
            "neighborhood": "36598c75d1d94bf0599062e20ad2e343ca1d076de96dfae8464a898fab9ee342",
            "city": "136d1a9a2e514cbcd1306d4f589f523bf75913ef7f998efdacea6fd0025e052e",
        ],
        "south": [
            "block": "c0b47330aa41d7c04c19230635611eb70da534a1b5c7b0ea0fba46b4c8faba2c",
            "neighborhood": "05207da9254d605fe80b5c0084e13fcf1c7c3a3a42104cb2f30b58cedc87e5c1",
            "city": "05064fe4930a458f2149d196841d8405e73ebd6d6ac041bdb53df8429ac0f21e",
        ],
        "west": [
            "block": "265bd5ccd6c9f8e72e59c2323622eba58fad9665bba250c18d8d1415e9c7cbc8",
            "neighborhood": "5df4d99d472b3938975530fda174b5cecf11d7cc0f926bfe15f1cade15d666c5",
            "city": "ba021d4fef6bd08238e8b2b430ae712701e0874c97d3fb58f04f9a19b6963d7a",
        ],
    ]

    func testPublishedDirectionalFixtureLoadsThroughSaveServiceAndResolvesExactR2Payloads() throws {
        let fixture = repositoryRoot
            .appending(path: "docs/production/evidence/PLAY-075")
            .appending(path: "industrial-l4-family-preregistration-v1")
            .appending(path: "fixtures")
            .appending(path: "industrial-l03-directional-mature-city-v1.json")
        let fixtureData = try Data(contentsOf: fixture)
        XCTAssertEqual(sha256(fixtureData), fixtureSHA256)

        let root = FileManager.default.temporaryDirectory.appending(
            path: "play073-published-l3-fixture-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        try fixtureData.write(
            to: root.appending(path: "quicksave.json"),
            options: .atomic
        )
        let loaded = try SaveGameService(rootURL: root).load()
        XCTAssertEqual(loaded.schemaVersion, 1)
        XCTAssertEqual(loaded.fingerprint.version, 1)
        XCTAssertEqual(loaded.fingerprint.digest, stateDigest)
        XCTAssertEqual(loaded.state.status, .playing)

        let catalog = WorldAssetCatalog()
        var logicalIDs: Set<String> = []
        var sourceKeys: Set<String> = []
        var resolvedSourceHashes: Set<String> = []
        var resolvedNormalizedHashes: Set<String> = []

        for placement in placements {
            let tile = try XCTUnwrap(loaded.state.tile(at: placement.coordinate))
            XCTAssertEqual(tile.kind, .industrial)
            XCTAssertEqual(tile.level, 3)
            XCTAssertEqual(tile.constructionProgress, 1)
            XCTAssertEqual(tile.condition, 1)
            XCTAssertEqual(tile.occupancy, 89)
            XCTAssertEqual(loaded.state.tile(at: placement.road)?.kind, .road)

            let roads = RoadConnectionMask.resolving(
                at: placement.coordinate,
                in: loaded.state
            )
            XCTAssertEqual(roads, placement.mask)
            XCTAssertEqual(roads.connectionCount, 1)
            let identity = try XCTUnwrap(
                IndustrialGeneratedAssetIdentity(level: tile.level, adjacentRoads: roads)
            )
            XCTAssertEqual(identity.direction, placement.direction)
            XCTAssertEqual(identity.logicalID, placement.logicalID)

            let asset = try XCTUnwrap(
                catalog.generatedAsset(logicalID: placement.logicalID)
            )
            XCTAssertEqual(asset.family, "industrial")
            XCTAssertEqual(asset.level, 3)
            XCTAssertEqual(asset.variant, 0)
            XCTAssertEqual(asset.frontageEdge, placement.direction)
            XCTAssertEqual(asset.viewDirection, placement.direction)
            XCTAssertEqual(
                asset.supportedOrientation,
                "\(placement.direction)-facing-authored"
            )
            XCTAssertEqual(asset.sourceSHA256, sourceHashes[placement.direction])
            logicalIDs.insert(asset.logicalID)
            sourceKeys.insert(try XCTUnwrap(asset.sourceKey))
            resolvedSourceHashes.insert(try XCTUnwrap(asset.sourceSHA256))

            for detail in CameraDetailLevel.allCases {
                let lod = try XCTUnwrap(asset.lods[detail.assetSuffix])
                XCTAssertEqual(
                    lod.normalizedSHA256,
                    normalizedHashes[placement.direction]?[detail.assetSuffix]
                )
                resolvedNormalizedHashes.insert(
                    try XCTUnwrap(lod.normalizedSHA256)
                )
                XCTAssertNotNil(
                    catalog.generatedIndustrialPresentation(
                        level: 3,
                        adjacentRoads: roads,
                        detail: detail
                    )
                )
            }
        }

        XCTAssertEqual(logicalIDs.count, 4)
        XCTAssertEqual(sourceKeys.count, 4)
        XCTAssertEqual(resolvedSourceHashes.count, 4)
        XCTAssertEqual(resolvedNormalizedHashes.count, 12)

        let fallbackBefore = WorldAssetCatalog.shared
            .residencySnapshot()
            .fallbackCount
        for size in [
            CGSize(width: 1_278, height: 768),
            CGSize(width: 900, height: 600),
        ] {
            let scene = CityScene(size: size)
            scene.reducedMotion = true
            scene.render(
                state: loaded.state,
                overlay: .none,
                selection: nil,
                interactionMode: .inspect
            )
            for detail in CameraDetailLevel.allCases {
                scene.configureProofCamera(detail: detail)
                for placement in placements {
                    let generatedNames = scene
                        .tileVisibleDescendantNamesForTesting(
                            at: placement.coordinate
                        )
                        .filter {
                            $0.hasPrefix(
                                "lot.generated-v4.industrial_l03_v0_"
                            )
                        }
                    XCTAssertEqual(
                        generatedNames,
                        ["lot.generated-v4.\(placement.logicalID).\(detail.assetSuffix)"],
                        "\(Int(size.width))x\(Int(size.height)) " +
                            "\(placement.direction) \(detail.assetSuffix)"
                    )
                }
            }
        }
        XCTAssertEqual(
            WorldAssetCatalog.shared.residencySnapshot().fallbackCount,
            fallbackBefore
        )
    }

    private var repositoryRoot: URL {
        var root = URL(filePath: #filePath)
        for _ in 0..<5 {
            root.deleteLastPathComponent()
        }
        return root
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
