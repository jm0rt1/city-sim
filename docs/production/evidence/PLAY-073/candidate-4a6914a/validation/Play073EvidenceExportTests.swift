import AppKit
import SpriteKit
import XCTest
@testable import CitySimNative

final class Play073EvidenceExportTests: XCTestCase {
    private struct Manifest: Decodable {
        let fixtures: [Entry]
    }

    private struct Entry: Decodable {
        let id: String
        let file: String
        let lifecycle: String
        let expectedStateDigest: String
        let focusCoordinate: GridCoordinate
    }

    @MainActor
    func testExportAuthoritativeLifecycleCompositionMatrix() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let fixtureRootPath = environment["CITYSIM_PLAY073_FIXTURE_ROOT"],
              let outputRootPath = environment["CITYSIM_PLAY073_MATRIX_ROOT"],
              let rendererLabel = environment["CITYSIM_PLAY073_RENDERER_LABEL"] else {
            throw XCTSkip("PLAY-073 matrix export paths are not configured")
        }
        let fixtureRoot = URL(fileURLWithPath: fixtureRootPath, isDirectory: true)
        let outputRoot = URL(fileURLWithPath: outputRootPath, isDirectory: true)
        let manifestData = try Data(
            contentsOf: fixtureRoot.appending(path: "visible-city-states-manifest-v2.json")
        )
        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        let retainedLifecycles = Set(["pressured", "recovering", "upgraded", "terminal"])
        let fixtures = manifest.fixtures.filter {
            retainedLifecycles.contains($0.lifecycle)
        }
        XCTAssertEqual(fixtures.count, 8)
        try FileManager.default.createDirectory(
            at: outputRoot,
            withIntermediateDirectories: true
        )

        let routes: [(String, CGSize, CityMapViewportInsets)] = [
            (
                "regular",
                CGSize(width: 1_280, height: 800),
                CityMapViewportInsets(top: 104, leading: 24, bottom: 160, trailing: 24)
            ),
            (
                "compact",
                CGSize(width: 900, height: 600),
                CityMapViewportInsets(top: 138, leading: 19, bottom: 236, trailing: 19)
            ),
        ]
        var csv = [
            "renderer,state,digest,route,lod,camera_scale,"
                + "developed_width_share,developed_height_share,"
                + "public_realm_width_share,public_realm_height_share,"
                + "priority_width_share,priority_height_share,nodes,drawables,actions",
        ]

        for fixture in fixtures {
            let loadRoot = FileManager.default.temporaryDirectory.appending(
                path: "play073-\(rendererLabel)-\(fixture.id)-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
            defer { try? FileManager.default.removeItem(at: loadRoot) }
            try FileManager.default.createDirectory(
                at: loadRoot,
                withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(
                at: fixtureRoot.appending(path: fixture.file),
                to: loadRoot.appending(path: "quicksave.json")
            )
            let state = try SaveGameService(rootURL: loadRoot).load().state
            XCTAssertEqual(
                try CityStateFingerprinter.fingerprint(state).digest,
                fixture.expectedStateDigest
            )

            for (route, size, insets) in routes {
                var renderedFrames: [Data] = []
                for detail in CameraDetailLevel.allCases {
                    let view = SKView(frame: CGRect(origin: .zero, size: size))
                    let scene = CityScene(size: size)
                    scene.reducedMotion = true
                    scene.updateViewportInsets(insets)
                    view.presentScene(scene)
                    scene.render(
                        state: state,
                        overlay: .none,
                        selection: fixture.focusCoordinate,
                        interactionMode: .inspect
                    )
                    scene.configureProofCamera(
                        detail: detail,
                        centeredOn: fixture.focusCoordinate
                    )
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.12))
                    let texture = try XCTUnwrap(view.texture(from: scene))
                    let representation = NSBitmapImageRep(cgImage: texture.cgImage())
                    let png = try XCTUnwrap(
                        representation.representation(using: .png, properties: [:])
                    )
                    renderedFrames.append(png)
                    let file = outputRoot.appending(
                        path: "\(fixture.id)-\(route)-\(detail.assetSuffix).png"
                    )
                    try png.write(to: file, options: .atomic)

                    let developed = scene.occupiedDevelopedViewportOccupancyForTesting()
                    let publicRealm = scene.networkOpportunityViewportOccupancyForTesting()
                    let priority = scene.cameraPriorityViewportOccupancyForTesting()
                    let diagnostics = scene.diagnosticsSnapshot
                    csv.append([
                        rendererLabel,
                        fixture.id,
                        fixture.expectedStateDigest,
                        route,
                        detail.assetSuffix,
                        String(format: "%.9f", scene.cameraScaleForTesting),
                        String(format: "%.6f", developed.width),
                        String(format: "%.6f", developed.height),
                        String(format: "%.6f", publicRealm.width),
                        String(format: "%.6f", publicRealm.height),
                        String(format: "%.6f", priority.width),
                        String(format: "%.6f", priority.height),
                        String(diagnostics.nodeCount),
                        String(diagnostics.drawableNodeCount),
                        String(diagnostics.activeActionCount),
                    ].joined(separator: ","))
                    XCTAssertEqual(diagnostics.activeActionCount, 0)
                }
                XCTAssertEqual(Set(renderedFrames).count, 3)
            }
        }
        try Data((csv.joined(separator: "\n") + "\n").utf8).write(
            to: outputRoot.appending(path: "COMPOSITION.csv"),
            options: .atomic
        )
        XCTAssertEqual(WorldAssetCatalog.shared.residencySnapshot().fallbackCount, 0)
    }
}
