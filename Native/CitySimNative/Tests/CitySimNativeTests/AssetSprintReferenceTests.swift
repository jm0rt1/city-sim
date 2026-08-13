import AppKit
import CryptoKit
import XCTest
@testable import CitySimNative

final class AssetSprintReferenceTests: XCTestCase {
    func testCanonicalFamilyLocksProjectionPivotScaleAndLight() {
        let family = AssetSprintReferenceFamily.canonical
        XCTAssertEqual(family.projectionID, "citysim-isometric-2to1-southeast-v1")
        XCTAssertEqual(family.projectionRatio, 2, accuracy: 0.0001)
        XCTAssertEqual(family.tileWidth, 88)
        XCTAssertEqual(family.tileHeight, 44)
        XCTAssertEqual(family.elevationStep, 22)
        XCTAssertEqual(family.pivot, CGPoint(x: 0.5, y: 0.18))
        XCTAssertEqual(family.baseInset, 0.08, accuracy: 0.0001)
        XCTAssertEqual(family.keyLight, CGVector(dx: -1, dy: 1))
        XCTAssertEqual(family.shadowOffset, CGVector(dx: 16, dy: -10))
    }

    func testProjectionUsesOneUnmodifiedTwoToOneBasis() {
        let family = AssetSprintReferenceFamily.canonical
        let origin = CGPoint(x: 200, y: 100)
        let xStep = family.project(x: 1, y: 0, origin: origin)
        let yStep = family.project(x: 0, y: 1, origin: origin)
        let raised = family.project(x: 0, y: 0, z: 1, origin: origin)
        XCTAssertEqual(xStep, CGPoint(x: 244, y: 122))
        XCTAssertEqual(yStep, CGPoint(x: 156, y: 122))
        XCTAssertEqual(raised, CGPoint(x: 200, y: 122))
        XCTAssertEqual(abs(xStep.x - origin.x) / abs(xStep.y - origin.y), 2, accuracy: 0.0001)
        XCTAssertEqual(abs(yStep.x - origin.x) / abs(yStep.y - origin.y), 2, accuracy: 0.0001)
    }

    @MainActor
    func testReferenceFamilyProducesDeterministicUsableAssetsAndDenseNeighborhood() throws {
        let renderer = AssetSprintReferenceRenderer()
        let first = try XCTUnwrap(renderer.renderNeighborhood())
        let second = try XCTUnwrap(renderer.renderNeighborhood())
        let firstPNG = try XCTUnwrap(renderer.pngData(for: first))
        let secondPNG = try XCTUnwrap(renderer.pngData(for: second))
        XCTAssertEqual(first.pixelsWide, 1_280)
        XCTAssertEqual(first.pixelsHigh, 800)
        XCTAssertEqual(firstPNG, secondPNG)
        XCTAssertGreaterThan(firstPNG.count, 90_000)
        XCTAssertGreaterThan(opaqueCoverage(in: first), 0.98)
        XCTAssertGreaterThan(distinctColorBuckets(in: first), 35)

        var assetHashes = Set<String>()
        for asset in AssetSprintReferenceAsset.allCases {
            let image = try XCTUnwrap(renderer.renderAsset(asset))
            let png = try XCTUnwrap(renderer.pngData(for: image))
            XCTAssertEqual(image.pixelsWide, 512, asset.rawValue)
            XCTAssertEqual(image.pixelsHigh, 512, asset.rawValue)
            XCTAssertGreaterThan(png.count, 12_000, asset.rawValue)
            XCTAssertGreaterThan(opaqueCoverage(in: image), 0.075, asset.rawValue)
            assetHashes.insert(SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined())
        }
        XCTAssertEqual(assetHashes.count, AssetSprintReferenceAsset.allCases.count)
    }

    @MainActor
    func testPackagedReferenceFilesArePresentAndMatchCanonicalDimensions() throws {
        let directory = try XCTUnwrap(AssetSprintReferenceFamily.resourceDirectoryURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        let renderer = AssetSprintReferenceRenderer()
        let manifestData = try Data(contentsOf: directory.appendingPathComponent("family.json"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        let projection = try XCTUnwrap(json["projection"] as? [String: Any])
        let ground = try XCTUnwrap(json["ground_contract"] as? [String: Any])
        XCTAssertEqual(projection["id"] as? String, AssetSprintReferenceFamily.canonical.projectionID)
        XCTAssertEqual(projection["tile_width"] as? Int, 88)
        XCTAssertEqual(projection["tile_height"] as? Int, 44)
        XCTAssertEqual(projection["renderer_rotation_degrees"] as? Int, 0)
        XCTAssertEqual(projection["renderer_skew"] as? Int, 0)
        XCTAssertEqual(projection["renderer_scale_override"] as? Int, 1)
        XCTAssertEqual(ground["pivot_x"] as? Double, 0.5)
        XCTAssertEqual(ground["pivot_y"] as? Double, 0.18)

        for asset in AssetSprintReferenceAsset.allCases {
            let url = directory.appendingPathComponent(asset.fileName)
            let image = try XCTUnwrap(NSImage(contentsOf: url))
            let bitmap = try XCTUnwrap(image.representations.compactMap { $0 as? NSBitmapImageRep }.first)
            XCTAssertEqual(bitmap.pixelsWide, 512, asset.rawValue)
            XCTAssertEqual(bitmap.pixelsHigh, 512, asset.rawValue)
            let expected = try XCTUnwrap(renderer.pngData(for: XCTUnwrap(renderer.renderAsset(asset))))
            XCTAssertEqual(try Data(contentsOf: url), expected, asset.rawValue)
        }
        let neighborhoodURL = directory.appendingPathComponent("cedar-market-neighborhood-1280x800.png")
        let neighborhood = try XCTUnwrap(NSImage(contentsOf: neighborhoodURL))
        let neighborhoodBitmap = try XCTUnwrap(neighborhood.representations.compactMap { $0 as? NSBitmapImageRep }.first)
        XCTAssertEqual(neighborhoodBitmap.pixelsWide, 1_280)
        XCTAssertEqual(neighborhoodBitmap.pixelsHigh, 800)
        let expectedNeighborhood = try XCTUnwrap(renderer.pngData(for: XCTUnwrap(renderer.renderNeighborhood())))
        XCTAssertEqual(try Data(contentsOf: neighborhoodURL), expectedNeighborhood)
    }

    @MainActor
    func testExportReferenceFamilyWhenRequested() throws {
        guard let outputPath = ProcessInfo.processInfo.environment["CITYSIM_ASSET_SPRINT_OUTPUT"] else { return }
        let output = URL(fileURLWithPath: outputPath, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let renderer = AssetSprintReferenceRenderer()
        let neighborhood = try XCTUnwrap(renderer.renderNeighborhood())
        try XCTUnwrap(renderer.pngData(for: neighborhood)).write(
            to: output.appendingPathComponent("cedar-market-neighborhood-1280x800.png"), options: .atomic
        )
        for asset in AssetSprintReferenceAsset.allCases {
            let image = try XCTUnwrap(renderer.renderAsset(asset))
            try XCTUnwrap(renderer.pngData(for: image)).write(
                to: output.appendingPathComponent(asset.fileName), options: .atomic
            )
        }
    }

    private func opaqueCoverage(in image: NSBitmapImageRep) -> Double {
        var opaque = 0
        var sampled = 0
        for y in stride(from: 0, to: image.pixelsHigh, by: 8) {
            for x in stride(from: 0, to: image.pixelsWide, by: 8) {
                sampled += 1
                if (image.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 { opaque += 1 }
            }
        }
        return Double(opaque) / Double(sampled)
    }

    private func distinctColorBuckets(in image: NSBitmapImageRep) -> Int {
        var buckets = Set<Int>()
        for y in stride(from: 0, to: image.pixelsHigh, by: 12) {
            for x in stride(from: 0, to: image.pixelsWide, by: 12) {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let red = Int(color.redComponent * 7)
                let green = Int(color.greenComponent * 7)
                let blue = Int(color.blueComponent * 7)
                buckets.insert(red * 64 + green * 8 + blue)
            }
        }
        return buckets.count
    }
}
