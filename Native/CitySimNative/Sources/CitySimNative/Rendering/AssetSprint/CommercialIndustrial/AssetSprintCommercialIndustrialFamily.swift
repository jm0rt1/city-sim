import AppKit
import Foundation

struct AssetSprintCommercialIndustrialFamily: Equatable, Sendable {
    static let canonical = AssetSprintCommercialIndustrialFamily(reference: .canonical)

    let reference: AssetSprintReferenceFamily

    var projectionID: String { reference.projectionID }
    var tileWidth: CGFloat { reference.tileWidth }
    var tileHeight: CGFloat { reference.tileHeight }
    var elevationStep: CGFloat { reference.elevationStep }
    var pivot: CGPoint { reference.pivot }
    var keyLight: CGVector { reference.keyLight }
    var shadowOffset: CGVector { reference.shadowOffset }

    static var resourceDirectoryURL: URL? {
        CityResourceBundle.shared.resourceURL?
            .appendingPathComponent("WorldAssets.atlas", isDirectory: true)
            .appendingPathComponent("AssetSprintCommercialIndustrial", isDirectory: true)
    }
}

enum AssetSprintCommercialIndustrialAsset: String, CaseIterable, Sendable {
    case cornerShop = "cedar-corner-shop"
    case cafe = "cedar-cafe"
    case mixedUse = "cedar-mixed-use"
    case workshop = "cedar-workshop"
    case factory = "cedar-factory"
    case utilityIndustry = "cedar-utility-industry"

    var fileName: String { "\(rawValue).png" }

    var category: String {
        switch self {
        case .cornerShop, .cafe, .mixedUse: "commercial"
        case .workshop, .factory, .utilityIndustry: "industrial"
        }
    }

    var footprint: CGSize {
        switch self {
        case .cornerShop, .cafe, .mixedUse: CGSize(width: 2, height: 2)
        case .workshop, .utilityIndustry: CGSize(width: 2, height: 3)
        case .factory: CGSize(width: 3, height: 3)
        }
    }

    var pixelSize: CGSize {
        switch self {
        case .cornerShop, .cafe: CGSize(width: 512, height: 512)
        case .mixedUse: CGSize(width: 512, height: 576)
        case .workshop, .utilityIndustry: CGSize(width: 640, height: 576)
        case .factory: CGSize(width: 768, height: 640)
        }
    }
}
