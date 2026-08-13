import AppKit
import CryptoKit
import XCTest
@testable import CitySimNative

final class AssetSprintIntegratedNeighborhoodTests: XCTestCase {
    @MainActor
    func testIntegrationUsesOneCanonicalProjectionPivotAndFootprintScale() {
        XCTAssertEqual(AssetSprintReferenceFamily.canonical.projectionRatio, 2, accuracy: 0.0001)
        XCTAssertEqual(AssetSprintReferenceFamily.canonical.pivot, CGPoint(x: 0.5, y: 0.18))
        XCTAssertEqual(AssetSprintIntegratedNeighborhoodRenderer.pixelsPerFootprintEdge, 42)
        XCTAssertGreaterThanOrEqual(AssetSprintIntegratedNeighborhoodRenderer.placements.count, 10)
    }

    @MainActor
    func testIntegrationConsumesEveryAcceptedProductionFamily() {
        let familyNames = Set(AssetSprintIntegratedNeighborhoodRenderer.placements.map { placement in
            switch placement.asset {
            case .residentialCivic: "residential-civic"
            case .commercialIndustrial: "commercial-industrial"
            case .terrain: "terrain-roads-vegetation"
            }
        })
        XCTAssertEqual(familyNames, [
            "residential-civic", "commercial-industrial", "terrain-roads-vegetation"
        ])
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
            XCTAssertGreaterThan(firstData.count, size.width > 1_000 ? 500_000 : 250_000)
            XCTAssertGreaterThan(colorBuckets(in: first), 90)
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
