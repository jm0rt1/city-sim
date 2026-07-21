import Foundation

struct GeneratedWorldAssetManifest: Decodable, Sendable {
    struct LOD: Decodable, Sendable {
        let file: String
        let pixels: [Int]
        let sha256: String
    }

    struct Asset: Decodable, Sendable {
        let logicalID: String
        let family: String
        let footprint: [Int]
        let anchor: [Double]
        let groundPivot: [Double]
        let worldSize: [Double]
        let lods: [String: LOD]

        enum CodingKeys: String, CodingKey {
            case logicalID = "logical_id"
            case family, footprint, anchor
            case groundPivot = "ground_pivot"
            case worldSize = "world_size"
            case lods
        }
    }

    let schema: Int
    let packID: String
    let productionSelection: Bool
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case schema
        case packID = "pack_id"
        case productionSelection = "production_selection"
        case assets
    }
}
