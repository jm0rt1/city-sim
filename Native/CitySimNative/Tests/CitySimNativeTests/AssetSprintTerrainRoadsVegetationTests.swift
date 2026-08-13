import AppKit
import CryptoKit
import XCTest
@testable import CitySimNative

final class AssetSprintTerrainRoadsVegetationTests: XCTestCase {
    func testFamilyUsesUnmodifiedCedarMarketProjectionAndGroundContract() throws {
        let family = AssetSprintTerrainRoadsVegetationFamily.canonical
        let reference = AssetSprintReferenceFamily.canonical
        XCTAssertEqual(family.reference, reference)
        XCTAssertEqual(family.reference.projectionID, "citysim-isometric-2to1-southeast-v1")
        XCTAssertEqual(family.reference.projectionRatio, 2, accuracy: 0.0001)
        XCTAssertEqual(family.reference.tileWidth, 88)
        XCTAssertEqual(family.reference.tileHeight, 44)
        XCTAssertEqual(family.reference.elevationStep, 22)
        XCTAssertEqual(family.reference.pivot, CGPoint(x: 0.5, y: 0.18))
        XCTAssertEqual(family.reference.keyLight, CGVector(dx: -1, dy: 1))
        XCTAssertEqual(family.reference.shadowOffset, CGVector(dx: 16, dy: -10))

        let directory = try XCTUnwrap(AssetSprintTerrainRoadsVegetationFamily.resourceDirectoryURL)
        let data = try Data(contentsOf: directory.appendingPathComponent("family.json"))
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let projection = try XCTUnwrap(manifest["projection"] as? [String: Any])
        let ground = try XCTUnwrap(manifest["ground_contract"] as? [String: Any])
        let runtime = try XCTUnwrap(manifest["runtime_transforms"] as? [String: Any])
        XCTAssertEqual(projection["id"] as? String, reference.projectionID)
        XCTAssertEqual(projection["tile_width"] as? Int, 88)
        XCTAssertEqual(projection["tile_height"] as? Int, 44)
        XCTAssertEqual(projection["elevation_step"] as? Int, 22)
        XCTAssertEqual(ground["pivot_x"] as? Double, 0.5)
        XCTAssertEqual(ground["pivot_y"] as? Double, 0.18)
        XCTAssertEqual(ground["key_light"] as? String, "northwest")
        XCTAssertEqual(ground["shadow_direction"] as? String, "southeast")
        XCTAssertEqual(runtime["rotation_degrees"] as? Int, 0)
        XCTAssertEqual(runtime["skew"] as? Int, 0)
        XCTAssertEqual(runtime["per_asset_scale_override"] as? Bool, false)
    }

    @MainActor
    func testEveryUsableAssetIsCanonicalSizedDistinctAndGrounded() throws {
        let renderer = AssetSprintTerrainRoadsVegetationRenderer()
        var hashes = Set<String>()
        for asset in AssetSprintTerrainAsset.allCases {
            let image = try XCTUnwrap(renderer.renderAsset(asset), asset.rawValue)
            let data = try XCTUnwrap(renderer.pngData(for: image), asset.rawValue)
            XCTAssertEqual(image.pixelsWide, 512, asset.rawValue)
            XCTAssertEqual(image.pixelsHigh, 512, asset.rawValue)
            XCTAssertGreaterThan(data.count, 9_000, asset.rawValue)
            let coverage = alphaCoverage(in: image)
            XCTAssertGreaterThan(coverage, 0.07, asset.rawValue)
            XCTAssertLessThan(coverage, 0.82, asset.rawValue)
            XCTAssertTrue(hasGroundContact(in: image), asset.rawValue)
            hashes.insert(hash(data))
        }
        XCTAssertEqual(hashes.count, AssetSprintTerrainAsset.allCases.count)
    }

    @MainActor
    func testPackagedAssetsMatchDeterministicSourceRenderer() throws {
        let directory = try XCTUnwrap(AssetSprintTerrainRoadsVegetationFamily.resourceDirectoryURL)
        let renderer = AssetSprintTerrainRoadsVegetationRenderer()
        for asset in AssetSprintTerrainAsset.allCases where asset != .parkTreatment {
            let url = directory.appendingPathComponent(asset.fileName)
            let packaged = try Data(contentsOf: url)
            let expected = try XCTUnwrap(renderer.pngData(for: XCTUnwrap(renderer.renderAsset(asset))))
            XCTAssertEqual(packaged, expected, asset.rawValue)
        }

        let manifestData = try Data(contentsOf: directory.appendingPathComponent("family.json"))
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        let identities = try XCTUnwrap(manifest["packaged_sha256"] as? [String: String])
        let parkData = try Data(contentsOf: directory.appendingPathComponent(AssetSprintTerrainAsset.parkTreatment.fileName))
        XCTAssertEqual(hash(parkData), identities[AssetSprintTerrainAsset.parkTreatment.fileName])
    }

    @MainActor
    func testParkMatteHasTransparentCornersAndNoOpaqueChromaFringe() throws {
        let directory = try XCTUnwrap(AssetSprintTerrainRoadsVegetationFamily.resourceDirectoryURL)
        let image = try bitmap(at: directory.appendingPathComponent(AssetSprintTerrainAsset.parkTreatment.fileName))
        for point in [(0, 0), (511, 0), (0, 511), (511, 511)] {
            XCTAssertLessThan(image.colorAt(x: point.0, y: point.1)?.alphaComponent ?? 1, 0.01)
        }
        var opaqueChroma = 0
        var opaque = 0
        for y in stride(from: 0, to: image.pixelsHigh, by: 4) {
            for x in stride(from: 0, to: image.pixelsWide, by: 4) {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.alphaComponent > 0.5 else { continue }
                opaque += 1
                if color.redComponent > 0.75, color.blueComponent > 0.65, color.greenComponent < 0.25 { opaqueChroma += 1 }
            }
        }
        XCTAssertGreaterThan(opaque, 1_200)
        XCTAssertLessThan(Double(opaqueChroma) / Double(opaque), 0.002)
    }

    @MainActor
    func testRepresentativeBlockIsDeterministicAtBothAcceptanceSizes() throws {
        let renderer = AssetSprintTerrainRoadsVegetationRenderer()
        for size in [CGSize(width: 1_280, height: 800), CGSize(width: 900, height: 600)] {
            let first = try XCTUnwrap(renderer.renderRepresentativeBlock(size: size))
            let second = try XCTUnwrap(renderer.renderRepresentativeBlock(size: size))
            let firstData = try XCTUnwrap(renderer.pngData(for: first))
            XCTAssertEqual(firstData, renderer.pngData(for: second))
            XCTAssertEqual(first.pixelsWide, Int(size.width))
            XCTAssertEqual(first.pixelsHigh, Int(size.height))
            XCTAssertGreaterThan(firstData.count, 550_000)
            XCTAssertGreaterThan(colorBuckets(in: first), 140)
        }
    }

    @MainActor
    func testPackagedRepresentativeRendersMatchSourceRenderer() throws {
        let directory = try XCTUnwrap(AssetSprintTerrainRoadsVegetationFamily.resourceDirectoryURL)
        let renderer = AssetSprintTerrainRoadsVegetationRenderer()
        for (name, size) in [
            ("cedar-market-terrain-block-1280x800.png", CGSize(width: 1_280, height: 800)),
            ("cedar-market-terrain-block-900x600.png", CGSize(width: 900, height: 600))
        ] {
            let expected = try XCTUnwrap(renderer.pngData(for: XCTUnwrap(renderer.renderRepresentativeBlock(size: size))))
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(name)), expected, name)
        }
    }

    @MainActor
    func testExportTerrainFamilyWhenRequested() throws {
        guard let outputPath = ProcessInfo.processInfo.environment["CITYSIM_ASSET_SPRINT_TERRAIN_OUTPUT"] else { return }
        let output = URL(fileURLWithPath: outputPath, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let renderer = AssetSprintTerrainRoadsVegetationRenderer()
        for asset in AssetSprintTerrainAsset.allCases where asset != .parkTreatment {
            let data = try XCTUnwrap(renderer.pngData(for: XCTUnwrap(renderer.renderAsset(asset))))
            try data.write(to: output.appendingPathComponent(asset.fileName), options: .atomic)
        }
        for (name, size) in [
            ("cedar-market-terrain-block-1280x800.png", CGSize(width: 1_280, height: 800)),
            ("cedar-market-terrain-block-900x600.png", CGSize(width: 900, height: 600))
        ] {
            let data = try XCTUnwrap(renderer.pngData(for: XCTUnwrap(renderer.renderRepresentativeBlock(size: size))))
            try data.write(to: output.appendingPathComponent(name), options: .atomic)
        }
    }

    private func bitmap(at url: URL) throws -> NSBitmapImageRep {
        let image = try XCTUnwrap(NSImage(contentsOf: url))
        return try XCTUnwrap(image.representations.compactMap { $0 as? NSBitmapImageRep }.first)
    }

    private func alphaCoverage(in image: NSBitmapImageRep) -> Double {
        var visible = 0
        var sampled = 0
        for y in stride(from: 0, to: image.pixelsHigh, by: 5) {
            for x in stride(from: 0, to: image.pixelsWide, by: 5) {
                sampled += 1
                if (image.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 { visible += 1 }
            }
        }
        return Double(visible) / Double(sampled)
    }

    private func hasGroundContact(in image: NSBitmapImageRep) -> Bool {
        let lowerBand = Int(Double(image.pixelsHigh) * 0.18)...Int(Double(image.pixelsHigh) * 0.50)
        var visible = 0
        for y in stride(from: lowerBand.lowerBound, through: lowerBand.upperBound, by: 4) {
            for x in stride(from: 40, to: image.pixelsWide - 40, by: 4) {
                if (image.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.25 { visible += 1 }
            }
        }
        return visible > 300
    }

    private func colorBuckets(in image: NSBitmapImageRep) -> Int {
        var buckets = Set<Int>()
        for y in stride(from: 0, to: image.pixelsHigh, by: 11) {
            for x in stride(from: 0, to: image.pixelsWide, by: 11) {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let r = Int(color.redComponent * 15)
                let g = Int(color.greenComponent * 15)
                let b = Int(color.blueComponent * 15)
                buckets.insert(r * 256 + g * 16 + b)
            }
        }
        return buckets.count
    }

    private func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
