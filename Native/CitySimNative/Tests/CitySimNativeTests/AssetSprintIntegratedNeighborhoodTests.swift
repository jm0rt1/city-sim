import AppKit
import CryptoKit
import XCTest
@testable import CitySimNative

final class AssetSprintIntegratedNeighborhoodTests: XCTestCase {
    @MainActor
    func testIntegrationUsesOneCanonicalProjectionAndExactGridContract() {
        XCTAssertEqual(AssetSprintReferenceFamily.canonical.projectionRatio, 2, accuracy: 0.0001)
        XCTAssertEqual(AssetSprintReferenceFamily.canonical.pivot, CGPoint(x: 0.5, y: 0.18))
        XCTAssertEqual(AssetSprintIntegratedNeighborhoodRenderer.worldWidth, 14)
        XCTAssertEqual(AssetSprintIntegratedNeighborhoodRenderer.worldDepth, 10)
        XCTAssertEqual(AssetSprintIntegratedNeighborhoodRenderer.roadWidth, 0.74)
        XCTAssertEqual(AssetSprintIntegratedNeighborhoodRenderer.roadX, [4.02, 8.82])
        XCTAssertEqual(AssetSprintIntegratedNeighborhoodRenderer.roadY, [3.20, 6.35])
        XCTAssertGreaterThanOrEqual(AssetSprintIntegratedNeighborhoodRenderer.placements.count, 10)
    }

    @MainActor
    func testIntegrationCoversEveryOriginalNeighborhoodRoleWithoutRasterCollage() {
        XCTAssertEqual(
            Set(AssetSprintIntegratedNeighborhoodRenderer.placements.map(\.role)),
            Set(AssetSprintIntegratedNeighborhoodRenderer.BuildingRole.allCases)
        )
        XCTAssertTrue(
            AssetSprintIntegratedNeighborhoodRenderer.placements.allSatisfy {
                $0.width > 0 && $0.depth > 0 && $0.height > 0
            }
        )
        for placement in AssetSprintIntegratedNeighborhoodRenderer.placements {
            let bounds = CGRect(
                x: placement.x,
                y: placement.y,
                width: placement.width,
                height: placement.depth
            )
            XCTAssertGreaterThanOrEqual(bounds.minX, 0, placement.role.rawValue)
            XCTAssertGreaterThanOrEqual(bounds.minY, 0, placement.role.rawValue)
            XCTAssertLessThanOrEqual(
                bounds.maxX,
                AssetSprintIntegratedNeighborhoodRenderer.worldWidth,
                placement.role.rawValue
            )
            XCTAssertLessThanOrEqual(
                bounds.maxY,
                AssetSprintIntegratedNeighborhoodRenderer.worldDepth,
                placement.role.rawValue
            )
            for roadX in AssetSprintIntegratedNeighborhoodRenderer.roadX {
                XCTAssertFalse(
                    bounds.minX < roadX + AssetSprintIntegratedNeighborhoodRenderer.roadWidth
                        && bounds.maxX > roadX,
                    "\(placement.role.rawValue) crosses the canonical x-axis road band"
                )
            }
            for roadY in AssetSprintIntegratedNeighborhoodRenderer.roadY {
                XCTAssertFalse(
                    bounds.minY < roadY + AssetSprintIntegratedNeighborhoodRenderer.roadWidth
                        && bounds.maxY > roadY,
                    "\(placement.role.rawValue) crosses the canonical y-axis road band"
                )
            }
        }
    }

    @MainActor
    func testEveryRoleUsesAProjectedDetailProfileWithFamilyDifferentiation() {
        let styles = AssetSprintIntegratedNeighborhoodRenderer.BuildingRole.allCases.map {
            AssetSprintIntegratedNeighborhoodRenderer.style(for: $0)
        }
        XCTAssertTrue(styles.allSatisfy { style in
            style.stories > 0 && style.frontBays > 0 && style.sideBays > 0
        })
        XCTAssertEqual(Set(styles.map(\.roof)), [.gable, .flatParapet, .industrialMonitor])
        XCTAssertEqual(
            Set(styles.map(\.facade)),
            [.clapboard, .masonry, .civicStone, .storefront, .industrial]
        )
        XCTAssertEqual(styles.map(\.stories).max(), 3)
        XCTAssertGreaterThanOrEqual(Set(styles).count, 8)
    }

    @MainActor
    func testComposedNeighborhoodRendersDeterministicallyAtAcceptanceSizes() throws {
        let renderer = AssetSprintIntegratedNeighborhoodRenderer()
        for size in [CGSize(width: 1_280, height: 800), CGSize(width: 900, height: 600)] {
            let first = try XCTUnwrap(renderer.render(size: size))
            let second = try XCTUnwrap(renderer.render(size: size))
            let firstData = try XCTUnwrap(renderer.pngData(for: first))
            let secondData = try XCTUnwrap(renderer.pngData(for: second))
            XCTAssertEqual(first.pixelsWide, Int(size.width))
            XCTAssertEqual(first.pixelsHigh, Int(size.height))
            XCTAssertEqual(firstData, secondData)
            XCTAssertGreaterThan(firstData.count, size.width > 1_000 ? 250_000 : 150_000)
            XCTAssertGreaterThan(colorBuckets(in: first), 60)
        }
    }

    @MainActor
    func testExportsComposedNeighborhoodWhenRequested() throws {
        guard let directory = ProcessInfo.processInfo.environment["CITYSIM_ASSET_SPRINT_INTEGRATED_OUTPUT"] else {
            return
        }
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let renderer = AssetSprintIntegratedNeighborhoodRenderer()
        for size in [CGSize(width: 1_280, height: 800), CGSize(width: 900, height: 600)] {
            let image = try XCTUnwrap(renderer.render(size: size))
            let data = try XCTUnwrap(renderer.pngData(for: image))
            try data.write(
                to: output.appendingPathComponent(
                    "cedar-market-integrated-\(Int(size.width))x\(Int(size.height)).png"
                ),
                options: .atomic
            )
        }
    }

    private func colorBuckets(in image: NSBitmapImageRep) -> Int {
        var buckets = Set<Int>()
        for y in stride(from: 0, to: image.pixelsHigh, by: 10) {
            for x in stride(from: 0, to: image.pixelsWide, by: 10) {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let red = Int(color.redComponent * 9)
                let green = Int(color.greenComponent * 9)
                let blue = Int(color.blueComponent * 9)
                buckets.insert(red * 100 + green * 10 + blue)
            }
        }
        return buckets.count
    }
}
