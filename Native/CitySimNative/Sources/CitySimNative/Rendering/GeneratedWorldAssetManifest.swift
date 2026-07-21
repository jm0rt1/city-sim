import Foundation

struct GeneratedWorldAssetManifest: Decodable, Sendable {
    struct LOD: Decodable, Sendable {
        let file: String
        let pixels: [Int]
        let sha256: String
        let trimRectPixels: [Int]
        let anchor: [Double]
        let worldSize: [Double]
        let decodedByteEstimate: Int

        enum CodingKeys: String, CodingKey {
            case file, pixels, sha256, anchor
            case trimRectPixels = "trim_rect_pixels"
            case worldSize = "world_size"
            case decodedByteEstimate = "decoded_byte_estimate"
        }
    }

    struct Asset: Decodable, Sendable {
        let logicalID: String
        let family: String
        let variant: Int
        let level: Int
        let state: String
        let authoringTemplate: String
        let sourceCanvasPixels: [Int]
        let sourceFootprintTiles: [Int]
        let footprintTiles: [Int]
        let supportedOrientation: String
        let placementOffsetWorld: [Double]
        let groundPivotSource: [Double]
        let groundContactPolygonWorld: [[Double]]
        let opaqueBoundsWorld: [Double]
        let shadowBoundsWorld: [Double]
        let allowedOverhangWorld: [Double]
        let frontageEdge: String
        let entranceSocketWorld: [Double]
        let roadSetbackPoints: Double
        let propExclusionRectsWorld: [[Double]]
        let depthRoles: [String: Double]
        let residencyID: String
        let decodedByteEstimate: Int
        let lods: [String: LOD]

        enum CodingKeys: String, CodingKey {
            case logicalID = "logical_id"
            case family, variant, level, state, lods
            case authoringTemplate = "authoring_template"
            case sourceCanvasPixels = "source_canvas_pixels"
            case sourceFootprintTiles = "source_footprint_tiles"
            case footprintTiles = "footprint_tiles"
            case supportedOrientation = "supported_orientation"
            case placementOffsetWorld = "placement_offset_world"
            case groundPivotSource = "ground_pivot_source"
            case groundContactPolygonWorld = "ground_contact_polygon_world"
            case opaqueBoundsWorld = "opaque_bounds_world"
            case shadowBoundsWorld = "shadow_bounds_world"
            case allowedOverhangWorld = "allowed_overhang_world"
            case frontageEdge = "frontage_edge"
            case entranceSocketWorld = "entrance_socket_world"
            case roadSetbackPoints = "road_setback_points"
            case propExclusionRectsWorld = "prop_exclusion_rects_world"
            case depthRoles = "depth_roles"
            case residencyID = "residency_id"
            case decodedByteEstimate = "decoded_byte_estimate"
        }
    }

    struct InventoryItem: Decodable, Sendable {
        let file: String
        let sha256: String
        let pixels: [Int]
        let decodedByteEstimate: Int

        enum CodingKeys: String, CodingKey {
            case file, sha256, pixels
            case decodedByteEstimate = "decoded_byte_estimate"
        }
    }

    struct CompiledNetwork: Decodable, Sendable {
        let sourceLogicalID: String
        let connectionMasks: Int
        let topologyAuthority: String
        let lods: [String: NetworkLOD]

        struct NetworkLOD: Decodable, Sendable {
            let pixels: [Int]
            let worldSize: [Double]
            let decodedBytesPerTexture: Int

            enum CodingKeys: String, CodingKey {
                case pixels
                case worldSize = "world_size"
                case decodedBytesPerTexture = "decoded_bytes_per_texture"
            }
        }

        enum CodingKeys: String, CodingKey {
            case sourceLogicalID = "source_logical_id"
            case connectionMasks = "connection_masks"
            case topologyAuthority = "topology_authority"
            case lods
        }
    }

    let schema: Int
    let packID: String
    let productionSelection: Bool
    let assets: [Asset]
    let inventory: [InventoryItem]
    let compiledNetwork: CompiledNetwork

    enum CodingKeys: String, CodingKey {
        case schema
        case packID = "pack_id"
        case productionSelection = "production_selection"
        case assets, inventory
        case compiledNetwork = "compiled_network"
    }
}
