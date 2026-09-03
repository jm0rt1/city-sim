import AppKit
import Foundation

/// Canonical geometry for the Asset Sprint. Production families must preserve
/// this projection and ground contract rather than correcting individual art
/// with renderer rotation, skew, or scale overrides.
struct AssetSprintReferenceFamily: Equatable, Sendable {
    static let canonical = AssetSprintReferenceFamily(
        projectionID: "citysim-isometric-2to1-southeast-v1",
        tileWidth: 88,
        tileHeight: 44,
        elevationStep: 22,
        pivot: CGPoint(x: 0.5, y: 0.18),
        baseInset: 0.08,
        keyLight: CGVector(dx: -1, dy: 1),
        shadowOffset: CGVector(dx: 16, dy: -10)
    )

    let projectionID: String
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    let elevationStep: CGFloat
    let pivot: CGPoint
    let baseInset: CGFloat
    let keyLight: CGVector
    let shadowOffset: CGVector

    var projectionRatio: CGFloat { tileWidth / tileHeight }

    static var resourceDirectoryURL: URL? {
        CityResourceBundle.shared.resourceURL?
            .appendingPathComponent("WorldAssets.atlas", isDirectory: true)
            .appendingPathComponent("AssetSprintReference", isDirectory: true)
    }

    func project(x: CGFloat, y: CGFloat, z: CGFloat = 0, origin: CGPoint) -> CGPoint {
        CGPoint(
            x: origin.x + (x - y) * tileWidth / 2,
            y: origin.y + (x + y) * tileHeight / 2 + z * elevationStep
        )
    }
}

enum AssetSprintReferenceAsset: String, CaseIterable, Sendable {
    case residential
    case commercial
    case civic
    case utility
    case terrainRoads = "terrain-roads"

    var fileName: String { "cedar-market-\(rawValue).png" }
}
