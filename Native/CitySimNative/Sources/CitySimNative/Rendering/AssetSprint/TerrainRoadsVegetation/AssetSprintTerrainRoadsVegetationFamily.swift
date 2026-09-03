import AppKit
import Foundation

/// Production terrain family locked to the Cedar Market canonical projection.
/// Runtime consumers use packaged pixels at authored size; there are no
/// per-asset rotation, skew, or scale corrections.
struct AssetSprintTerrainRoadsVegetationFamily: Equatable, Sendable {
    static let canonical = AssetSprintTerrainRoadsVegetationFamily(
        familyID: "cedar-market-terrain-roads-vegetation-v1",
        reference: .canonical,
        assetCanvas: CGSize(width: 512, height: 512)
    )

    let familyID: String
    let reference: AssetSprintReferenceFamily
    let assetCanvas: CGSize

    static var resourceDirectoryURL: URL? {
        CityResourceBundle.shared.resourceURL?
            .appendingPathComponent("WorldAssets.atlas", isDirectory: true)
            .appendingPathComponent("AssetSprintTerrainRoadsVegetation", isDirectory: true)
    }
}

enum AssetSprintTerrainAsset: String, CaseIterable, Sendable {
    case grass = "ground-grass"
    case lawn = "ground-lawn"
    case plaza = "ground-plaza"
    case industrialYard = "ground-industrial-yard"
    case roadStraight = "road-straight"
    case roadCorner = "road-corner"
    case roadIntersection = "road-intersection"
    case vegetationCluster = "vegetation-cluster"
    case streetDressingCluster = "street-dressing-cluster"
    case parkTreatment = "park-treatment"

    var fileName: String { "terrain-\(rawValue).png" }
}
