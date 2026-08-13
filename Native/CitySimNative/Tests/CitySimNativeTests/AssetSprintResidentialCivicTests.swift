import AppKit
import CryptoKit
import XCTest
@testable import CitySimNative

final class AssetSprintResidentialCivicTests: XCTestCase {
    func testCatalogKeepsCanonicalProjectionPivotAndNaturalScale() throws {
        let family = AssetSprintResidentialCivicCatalog.family
        XCTAssertEqual(family, AssetSprintReferenceFamily.canonical)
        XCTAssertEqual(family.projectionID, "citysim-isometric-2to1-southeast-v1")
        XCTAssertEqual(family.projectionRatio, 2, accuracy: 0.0001)
        XCTAssertEqual(family.tileWidth, 88)
        XCTAssertEqual(family.tileHeight, 44)
        XCTAssertEqual(family.elevationStep, 22)
        XCTAssertEqual(family.pivot, CGPoint(x: 0.5, y: 0.18))
        XCTAssertEqual(family.keyLight, CGVector(dx: -1, dy: 1))
        XCTAssertEqual(family.shadowOffset, CGVector(dx: 16, dy: -10))

        let directory = try XCTUnwrap(AssetSprintResidentialCivicCatalog.resourceDirectoryURL)
        let data = try Data(contentsOf: directory.appendingPathComponent("family.json"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let projection = try XCTUnwrap(json["projection"] as? [String: Any])
        let ground = try XCTUnwrap(json["ground_contract"] as? [String: Any])
        XCTAssertEqual(projection["id"] as? String, family.projectionID)
        XCTAssertEqual(projection["renderer_rotation_degrees"] as? Int, 0)
        XCTAssertEqual(projection["renderer_skew"] as? Int, 0)
        XCTAssertEqual(projection["renderer_scale_override"] as? Int, 1)
        XCTAssertEqual(ground["pivot_x"] as? Double, 0.5)
        XCTAssertEqual(ground["pivot_y"] as? Double, 0.18)
        XCTAssertEqual(ground["key_light"] as? String, "northwest")
        XCTAssertEqual(ground["shadow_direction"] as? String, "southeast")
    }

    func testPackagedAssetsHaveExpectedIdentityAlphaAndGroundContact() throws {
        let expectedHashes: [AssetSprintResidentialCivicAsset: String] = [
            .craftsman: "01c014eceec2c8fc9bf8a9f6360e7b7335e8c0837147c349ab4a8dcb18ea8e42",
            .rowhouses: "06f5673c616fb5e61c7d927959554c672023c73426a588a20f4b9753bdee3267",
            .courtyardApartments: "19e14f73631b1fc2e52f9e2e6bcb3b914d09ce18a023e17a8c62e763e8be5205",
            .neighborhoodLibrary: "8c751d6694061adca5f88737f55262d3136fa8420e2cde86121d375cfb957f3b",
            .cityHall: "088d6a0e934c48a36794bdec68781a92b105f30fccec56bd3e49d10d98fe1072"
        ]

        for asset in AssetSprintResidentialCivicAsset.allCases {
            let url = try XCTUnwrap(AssetSprintResidentialCivicCatalog.resourceURL(for: asset))
            let data = try Data(contentsOf: url)
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(digest, expectedHashes[asset], asset.rawValue)

            let image = try XCTUnwrap(NSImage(contentsOf: url))
            let bitmap = try XCTUnwrap(image.representations.compactMap { $0 as? NSBitmapImageRep }.first)
            XCTAssertEqual(bitmap.pixelsWide, asset.expectedPixels.width, asset.rawValue)
            XCTAssertEqual(bitmap.pixelsHigh, asset.expectedPixels.height, asset.rawValue)
            XCTAssertLessThan(alpha(atX: 0, y: 0, in: bitmap), 0.01, asset.rawValue)
            XCTAssertLessThan(alpha(atX: bitmap.pixelsWide - 1, y: 0, in: bitmap), 0.01, asset.rawValue)
            XCTAssertLessThan(alpha(atX: 0, y: bitmap.pixelsHigh - 1, in: bitmap), 0.01, asset.rawValue)
            XCTAssertLessThan(alpha(atX: bitmap.pixelsWide - 1, y: bitmap.pixelsHigh - 1, in: bitmap), 0.01, asset.rawValue)
            XCTAssertGreaterThan(opaqueCoverage(in: bitmap), 0.12, asset.rawValue)
            XCTAssertLessThan(opaqueCoverage(in: bitmap), 0.72, asset.rawValue)
            XCTAssertGreaterThan(groundContactCoverage(in: bitmap), 0.025, asset.rawValue)
            XCTAssertLessThan(magentaArtifactCoverage(in: bitmap), 0.012, asset.rawValue)
        }
    }

    @MainActor
    func testRepresentativeBlockRendersDeterministicallyAtBothRequiredSizes() throws {
        let renderer = AssetSprintResidentialCivicRenderer()
        for size in [CGSize(width: 1_280, height: 800), CGSize(width: 900, height: 600)] {
            let first = try XCTUnwrap(renderer.renderBlock(size: size))
            let second = try XCTUnwrap(renderer.renderBlock(size: size))
            let firstPNG = try XCTUnwrap(renderer.pngData(for: first))
            let secondPNG = try XCTUnwrap(renderer.pngData(for: second))
            XCTAssertEqual(first.pixelsWide, Int(size.width))
            XCTAssertEqual(first.pixelsHigh, Int(size.height))
            XCTAssertEqual(firstPNG, secondPNG)
            XCTAssertGreaterThan(firstPNG.count, 180_000)
            XCTAssertGreaterThan(distinctColorBuckets(in: first), 140)
            XCTAssertLessThan(magentaArtifactCoverage(in: first), 0.002)
        }
    }

    @MainActor
    func testPackagedRepresentativeBlocksMatchSourceRenderer() throws {
        let directory = try XCTUnwrap(AssetSprintResidentialCivicCatalog.resourceDirectoryURL)
        let renderer = AssetSprintResidentialCivicRenderer()
        for size in [CGSize(width: 1_280, height: 800), CGSize(width: 900, height: 600)] {
            let fileName = "cedar-residential-civic-block-\(Int(size.width))x\(Int(size.height)).png"
            let packaged = try Data(contentsOf: directory.appendingPathComponent(fileName))
            let rendered = try XCTUnwrap(renderer.pngData(for: XCTUnwrap(renderer.renderBlock(size: size))))
            XCTAssertEqual(packaged, rendered, fileName)
        }
    }

    @MainActor
    func testExportRepresentativeBlocksWhenRequested() throws {
        guard let outputPath = ProcessInfo.processInfo.environment["CITYSIM_ASSET_SPRINT_RESIDENTIAL_CIVIC_OUTPUT"] else { return }
        let output = URL(fileURLWithPath: outputPath, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let renderer = AssetSprintResidentialCivicRenderer()
        for size in [CGSize(width: 1_280, height: 800), CGSize(width: 900, height: 600)] {
            let image = try XCTUnwrap(renderer.renderBlock(size: size))
            let data = try XCTUnwrap(renderer.pngData(for: image))
            try data.write(
                to: output.appendingPathComponent("cedar-residential-civic-block-\(Int(size.width))x\(Int(size.height)).png"),
                options: .atomic
            )
        }
    }

    private func alpha(atX x: Int, y: Int, in image: NSBitmapImageRep) -> CGFloat {
        image.colorAt(x: x, y: y)?.alphaComponent ?? 0
    }

    private func opaqueCoverage(in image: NSBitmapImageRep) -> Double {
        var opaque = 0
        var sampled = 0
        for y in stride(from: 0, to: image.pixelsHigh, by: 3) {
            for x in stride(from: 0, to: image.pixelsWide, by: 3) {
                sampled += 1
                if alpha(atX: x, y: y, in: image) > 0.1 { opaque += 1 }
            }
        }
        return Double(opaque) / Double(sampled)
    }

    private func groundContactCoverage(in image: NSBitmapImageRep) -> Double {
        let pivotY = Int(CGFloat(image.pixelsHigh) * AssetSprintResidentialCivicCatalog.family.pivot.y)
        let minimumX = Int(CGFloat(image.pixelsWide) * 0.18)
        let maximumX = Int(CGFloat(image.pixelsWide) * 0.82)
        var opaque = 0
        var sampled = 0
        for y in max(0, pivotY - 8)...min(image.pixelsHigh - 1, pivotY + 8) {
            for x in stride(from: minimumX, through: maximumX, by: 2) {
                sampled += 1
                if alpha(atX: x, y: y, in: image) > 0.2 { opaque += 1 }
            }
        }
        return Double(opaque) / Double(sampled)
    }

    private func magentaArtifactCoverage(in image: NSBitmapImageRep) -> Double {
        var magenta = 0
        var opaque = 0
        for y in stride(from: 0, to: image.pixelsHigh, by: 3) {
            for x in stride(from: 0, to: image.pixelsWide, by: 3) {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.1 else { continue }
                opaque += 1
                if color.redComponent > 0.72,
                   color.blueComponent > 0.58,
                   color.greenComponent < 0.34 {
                    magenta += 1
                }
            }
        }
        return opaque == 0 ? 0 : Double(magenta) / Double(opaque)
    }

    private func distinctColorBuckets(in image: NSBitmapImageRep) -> Int {
        var buckets = Set<Int>()
        for y in stride(from: 0, to: image.pixelsHigh, by: 10) {
            for x in stride(from: 0, to: image.pixelsWide, by: 10) {
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
