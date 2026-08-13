import AppKit
import CryptoKit
import XCTest
@testable import CitySimNative

final class AssetSprintCommercialIndustrialTests: XCTestCase {
    func testFamilyInheritsCanonicalProjectionPivotLightingAndShadow() {
        let family = AssetSprintCommercialIndustrialFamily.canonical
        let reference = AssetSprintReferenceFamily.canonical
        XCTAssertEqual(family.projectionID, reference.projectionID)
        XCTAssertEqual(family.tileWidth, 88)
        XCTAssertEqual(family.tileHeight, 44)
        XCTAssertEqual(family.tileWidth / family.tileHeight, 2, accuracy: 0.0001)
        XCTAssertEqual(family.elevationStep, 22)
        XCTAssertEqual(family.pivot, CGPoint(x: 0.5, y: 0.18))
        XCTAssertEqual(family.keyLight, CGVector(dx: -1, dy: 1))
        XCTAssertEqual(family.shadowOffset, CGVector(dx: 16, dy: -10))
    }

    @MainActor
    func testPackagedAssetsAreGroundedAlphaSpritesWithStableIdentity() throws {
        let directory = try XCTUnwrap(AssetSprintCommercialIndustrialFamily.resourceDirectoryURL)
        let manifestData = try Data(contentsOf: directory.appendingPathComponent("family.json"))
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        let projection = try XCTUnwrap(manifest["projection"] as? [String: Any])
        let ground = try XCTUnwrap(manifest["ground_contract"] as? [String: Any])
        let entries = try XCTUnwrap(manifest["assets"] as? [[String: Any]])

        XCTAssertEqual(projection["id"] as? String, AssetSprintReferenceFamily.canonical.projectionID)
        XCTAssertEqual(projection["tile_width"] as? Int, 88)
        XCTAssertEqual(projection["tile_height"] as? Int, 44)
        XCTAssertEqual(projection["elevation_step"] as? Int, 22)
        XCTAssertEqual(ground["pivot_x"] as? Double, 0.5)
        XCTAssertEqual(ground["pivot_y"] as? Double, 0.18)
        XCTAssertEqual(ground["key_light"] as? String, "northwest")
        XCTAssertEqual(ground["shadow_direction"] as? String, "southeast")
        XCTAssertEqual(entries.count, 6)

        var identities = Set<String>()
        for asset in AssetSprintCommercialIndustrialAsset.allCases {
            let entry = try XCTUnwrap(entries.first { $0["id"] as? String == asset.rawValue })
            XCTAssertEqual(entry["renderer_rotation_degrees"] as? Int, 0, asset.rawValue)
            XCTAssertEqual(entry["renderer_skew"] as? Int, 0, asset.rawValue)
            XCTAssertEqual(entry["renderer_scale_override"] as? Int, 1, asset.rawValue)
            XCTAssertEqual(entry["category"] as? String, asset.category, asset.rawValue)

            let file = directory.appendingPathComponent(asset.fileName)
            let data = try Data(contentsOf: file)
            let image = try XCTUnwrap(NSImage(data: data))
            let bitmap = try XCTUnwrap(image.representations.compactMap { $0 as? NSBitmapImageRep }.first)
            XCTAssertEqual(bitmap.pixelsWide, Int(asset.pixelSize.width), asset.rawValue)
            XCTAssertEqual(bitmap.pixelsHigh, Int(asset.pixelSize.height), asset.rawValue)
            XCTAssertTrue(bitmap.hasAlpha, asset.rawValue)
            XCTAssertLessThan(alpha(bitmap, x: 0, y: 0), 0.01, asset.rawValue)
            XCTAssertLessThan(alpha(bitmap, x: bitmap.pixelsWide - 1, y: bitmap.pixelsHigh - 1), 0.01, asset.rawValue)
            XCTAssertGreaterThan(opaqueCoverage(bitmap), 0.16, asset.rawValue)
            XCTAssertTrue(hasGroundContactNearCanonicalPivot(bitmap), asset.rawValue)

            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(entry["packaged_sha256"] as? String, digest, asset.rawValue)
            identities.insert(digest)
        }
        XCTAssertEqual(identities.count, AssetSprintCommercialIndustrialAsset.allCases.count)
    }

    @MainActor
    func testRepresentativeBlockIsDeterministicAtBothRequiredSizes() throws {
        let renderer = AssetSprintCommercialIndustrialRenderer()
        XCTAssertEqual(Set(AssetSprintCommercialIndustrialRenderer.canonicalPlacements.map(\.asset)), Set(AssetSprintCommercialIndustrialAsset.allCases))

        for size in [CGSize(width: 1_280, height: 800), CGSize(width: 900, height: 600)] {
            let first = try XCTUnwrap(renderer.renderRepresentativeBlock(size: size))
            let second = try XCTUnwrap(renderer.renderRepresentativeBlock(size: size))
            let firstData = try XCTUnwrap(renderer.pngData(for: first))
            let secondData = try XCTUnwrap(renderer.pngData(for: second))
            XCTAssertEqual(firstData, secondData)
            XCTAssertEqual(first.pixelsWide, Int(size.width))
            XCTAssertEqual(first.pixelsHigh, Int(size.height))
            XCTAssertGreaterThan(firstData.count, 250_000)
            XCTAssertGreaterThan(distinctColorBuckets(first), 85)

            let name = "cedar-market-commercial-industrial-block-\(Int(size.width))x\(Int(size.height)).png"
            let packaged = try Data(contentsOf: try XCTUnwrap(AssetSprintCommercialIndustrialFamily.resourceDirectoryURL).appendingPathComponent(name))
            XCTAssertEqual(packaged, firstData)
        }
    }

    @MainActor
    func testExportRepresentativeBlockWhenRequested() throws {
        guard let outputPath = ProcessInfo.processInfo.environment["CITYSIM_ASSET_SPRINT_COMMERCIAL_INDUSTRIAL_OUTPUT"] else { return }
        let output = URL(fileURLWithPath: outputPath, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let renderer = AssetSprintCommercialIndustrialRenderer()
        for size in [CGSize(width: 1_280, height: 800), CGSize(width: 900, height: 600)] {
            let image = try XCTUnwrap(renderer.renderRepresentativeBlock(size: size))
            let data = try XCTUnwrap(renderer.pngData(for: image))
            try data.write(
                to: output.appendingPathComponent("cedar-market-commercial-industrial-block-\(Int(size.width))x\(Int(size.height)).png"),
                options: .atomic
            )
        }
    }

    private func alpha(_ image: NSBitmapImageRep, x: Int, y: Int) -> CGFloat {
        image.colorAt(x: x, y: y)?.alphaComponent ?? 0
    }

    private func opaqueCoverage(_ image: NSBitmapImageRep) -> Double {
        var opaque = 0
        var sampled = 0
        for y in stride(from: 0, to: image.pixelsHigh, by: 8) {
            for x in stride(from: 0, to: image.pixelsWide, by: 8) {
                sampled += 1
                if alpha(image, x: x, y: y) > 0.1 { opaque += 1 }
            }
        }
        return Double(opaque) / Double(sampled)
    }

    private func hasGroundContactNearCanonicalPivot(_ image: NSBitmapImageRep) -> Bool {
        let pivotX = Int(CGFloat(image.pixelsWide) * AssetSprintReferenceFamily.canonical.pivot.x)
        // NSBitmapImageRep samples PNG rows from the top; the runtime pivot is
        // expressed from the bottom in SpriteKit/AppKit scene coordinates.
        let pivotY = image.pixelsHigh - 1 - Int(CGFloat(image.pixelsHigh) * AssetSprintReferenceFamily.canonical.pivot.y)
        for y in max(0, pivotY - 5)...min(image.pixelsHigh - 1, pivotY + 5) {
            for x in max(0, pivotX - 28)...min(image.pixelsWide - 1, pivotX + 28) {
                if alpha(image, x: x, y: y) > 0.35 { return true }
            }
        }
        return false
    }

    private func distinctColorBuckets(_ image: NSBitmapImageRep) -> Int {
        var buckets = Set<Int>()
        for y in stride(from: 0, to: image.pixelsHigh, by: 12) {
            for x in stride(from: 0, to: image.pixelsWide, by: 12) {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let red = Int(color.redComponent * 15)
                let green = Int(color.greenComponent * 15)
                let blue = Int(color.blueComponent * 15)
                buckets.insert(red * 256 + green * 16 + blue)
            }
        }
        return buckets.count
    }
}
