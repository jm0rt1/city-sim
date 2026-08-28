import SpriteKit
import XCTest
@testable import CitySimNative

final class FullGameFourViewArtIntegrationTests: XCTestCase {
    @MainActor
    func testEveryPlayableCityModeUsesApprovedArtWithoutLegacyFallback() throws {
        let states: [(String, CityGameState)] = [
            ("guided", CityGameState.newCity(seed: 42)),
            ("scenario", CityAuthoredScenarioCatalog.harborRecovery.makeState()),
            ("dense", CityBenchmarkDefinition.verticalSlice.makeState()),
        ]
        let worldCatalog = FourViewWorldAssetCatalog()
        let groundCatalog = FourViewGroundEcologyCatalog()

        for (mode, state) in states {
            let scene = CityScene(size: CGSize(width: 1_280, height: 800))
            scene.reducedMotion = true
            scene.render(
                state: state,
                overlay: .none,
                selection: nil,
                interactionMode: .inspect
            )

            let sceneNames = descendantNames(in: scene)
            XCTAssertFalse(
                sceneNames.contains { $0.contains("four-view.missing") },
                "\(mode) must not contain an unresolved approved-art source"
            )
            XCTAssertFalse(
                sceneNames.contains { $0.hasPrefix("road.socket-seam-blend.") },
                "\(mode) must not decorate approved roads with legacy seam patches"
            )
            XCTAssertFalse(
                sceneNames.contains { $0.hasPrefix("road.fabric.") },
                "\(mode) must not place procedural road fabric under approved roads"
            )

            for tile in state.tiles where tile.kind != .empty {
                let tileRoot = try XCTUnwrap(
                    scene.childNode(withName: "//tile:\(tile.coordinate.x):\(tile.coordinate.y)"),
                    "\(mode) \(tile.coordinate.id)"
                )
                let names = descendantNames(in: tileRoot)
                if tile.kind == .road {
                    let mask = RoadConnectionMask.resolving(at: tile.coordinate, in: state)
                    XCTAssertTrue(
                        names.contains(String(
                            format: "road.four-view.mask-%02d.camNE",
                            mask.rawValue
                        )),
                        "\(mode) road \(tile.coordinate.id)"
                    )
                    continue
                }

                guard tile.constructionProgress >= 1 else { continue }
                let variant = tile.kind == .residential
                    ? ResidentialGeneratedAssetIdentity.liveVisualVariant(at: tile.coordinate)
                    : WorldVisualSeed.variant(
                        count: 3,
                        for: tile.coordinate,
                        kind: tile.kind
                    )
                let roads = RoadConnectionMask.resolving(at: tile.coordinate, in: state)
                let productionLevelOneIdentity: String? = if tile.level == 1 {
                    switch tile.kind {
                    case .commercial:
                        CommercialGeneratedAssetIdentity(
                            level: 1,
                            adjacentRoads: roads
                        )?.logicalID
                    case .industrial:
                        IndustrialGeneratedAssetIdentity(
                            level: 1,
                            adjacentRoads: roads
                        )?.logicalID
                    default:
                        nil
                    }
                } else {
                    nil
                }
                if let identity = productionLevelOneIdentity {
                    XCTAssertTrue(
                        names.contains("lot.generated-v4.\(identity).neighborhood")
                            || names.contains("lot.generated-v4.\(identity).block")
                            || names.contains("lot.generated-v4.\(identity).city"),
                        "\(mode) lot \(tile.coordinate.id) must use its admitted level-one family"
                    )
                    XCTAssertFalse(
                        names.contains { $0.hasPrefix("lot.four-view.") },
                        "\(mode) production level-one art must not use compatibility sources"
                    )
                } else {
                    let assetID = try XCTUnwrap(
                        worldCatalog.assetID(for: tile, variant: variant),
                        "\(mode) lot \(tile.coordinate.id)"
                    )
                    let descriptor = try XCTUnwrap(
                        worldCatalog.manifest?.assets.first { $0.assetID == assetID },
                        "\(mode) approved descriptor \(assetID)"
                    )
                    let authoredCameras = descriptor.views.compactMap {
                        FourViewWorldAssetCatalog.Camera(rawValue: $0.camera)
                    }
                    XCTAssertTrue(
                        authoredCameras.contains { camera in
                            names.contains("lot.four-view.\(assetID).\(camera.rawValue)")
                        },
                        "\(mode) lot \(tile.coordinate.id) must use an authored \(assetID) view"
                    )
                }

                let groundAssetID = try XCTUnwrap(
                    groundCatalog.groundAssetID(for: tile),
                    "\(mode) ground \(tile.coordinate.id)"
                )
                XCTAssertTrue(
                    names.contains("ground-ecology.four-view.\(groundAssetID).camNE"),
                    "\(mode) ground \(tile.coordinate.id) must use \(groundAssetID)"
                )
                XCTAssertFalse(
                    names.contains { $0.hasPrefix("terrain.lot-surface.") },
                    "\(mode) lot \(tile.coordinate.id) must not use procedural ground"
                )
            }
        }
    }

    @MainActor
    func testDenseCityLotsWithoutAdjacentRoadsStillReceiveApprovedBuildings() throws {
        let state = CityBenchmarkDefinition.verticalSlice.makeState()
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )

        let catalog = FourViewWorldAssetCatalog()
        let isolatedLots = state.tiles.filter { tile in
            tile.kind != .empty
                && tile.kind != .road
                && RoadConnectionMask.resolving(at: tile.coordinate, in: state).isEmpty
        }
        XCTAssertGreaterThan(isolatedLots.count, 0)

        for tile in isolatedLots {
            let variant = tile.kind == .residential
                ? ResidentialGeneratedAssetIdentity.liveVisualVariant(at: tile.coordinate)
                : WorldVisualSeed.variant(count: 3, for: tile.coordinate, kind: tile.kind)
            let assetID = try XCTUnwrap(catalog.assetID(for: tile, variant: variant))
            let tileRoot = try XCTUnwrap(
                scene.childNode(withName: "//tile:\(tile.coordinate.x):\(tile.coordinate.y)")
            )
            XCTAssertTrue(
                descendantNames(in: tileRoot).contains("lot.four-view.\(assetID).camNE"),
                tile.coordinate.id
            )
        }
    }

    @MainActor
    private func descendantNames(in node: SKNode) -> [String] {
        (node.name.map { [$0] } ?? []) + node.children.flatMap(descendantNames)
    }
}
