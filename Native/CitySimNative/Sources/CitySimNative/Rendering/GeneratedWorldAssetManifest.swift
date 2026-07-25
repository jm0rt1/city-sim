import Foundation

struct GeneratedWorldAssetManifest: Decodable, Sendable {
    struct LOD: Decodable, Sendable {
        let file: String
        let page: String
        let pageFile: String
        let pixels: [Int]
        let sourcePixels: [Int]
        let sha256: String
        let trimRectPixels: [Int]
        let sourceTrimRectPixels: [Int]
        let textureRectPixels: [Int]
        let packedRectPixels: [Int]
        let anchor: [Double]
        let worldSize: [Double]
        let paddingPixels: Int
        let extrusionPixels: Int
        let decodedByteEstimate: Int
        let normalizedFile: String?
        let normalizedSHA256: String?

        enum CodingKeys: String, CodingKey {
            case file, page, pixels, sha256, anchor
            case pageFile = "page_file"
            case sourcePixels = "source_pixels"
            case trimRectPixels = "trim_rect_pixels"
            case sourceTrimRectPixels = "source_trim_rect_pixels"
            case textureRectPixels = "texture_rect_pixels"
            case packedRectPixels = "packed_rect_pixels"
            case worldSize = "world_size"
            case paddingPixels = "padding_pixels"
            case extrusionPixels = "extrusion_pixels"
            case decodedByteEstimate = "decoded_byte_estimate"
            case normalizedFile = "normalized_file"
            case normalizedSHA256 = "normalized_sha256"
        }
    }

    struct Asset: Decodable, Sendable {
        let logicalID: String
        let sourceKey: String?
        let sourceRevision: String?
        let viewDirection: String?
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
        let sourceSHA256: String?
        let provenanceFile: String?
        let provenanceSHA256: String?
        let normalizationRecordFile: String?
        let normalizationRecordSHA256: String?
        let sceneDescriptorFile: String?
        let sceneDescriptorSHA256: String?

        enum CodingKeys: String, CodingKey {
            case logicalID = "logical_id"
            case sourceKey = "source_key"
            case sourceRevision = "source_revision"
            case viewDirection = "view_direction"
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
            case sourceSHA256 = "source_sha256"
            case provenanceFile = "provenance_file"
            case provenanceSHA256 = "provenance_sha256"
            case normalizationRecordFile = "normalization_record_file"
            case normalizationRecordSHA256 = "normalization_record_sha256"
            case sceneDescriptorFile = "scene_descriptor_file"
            case sceneDescriptorSHA256 = "scene_descriptor_sha256"
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

    struct Page: Decodable, Sendable {
        let id: String
        let lod: String
        let file: String
        let sha256: String
        let pixels: [Int]
        let decodedByteEstimate: Int
        let entryCount: Int
        let paddingPixels: Int
        let extrusionPixels: Int
        let rotation: Bool

        enum CodingKeys: String, CodingKey {
            case id, lod, file, sha256, pixels, rotation
            case decodedByteEstimate = "decoded_byte_estimate"
            case entryCount = "entry_count"
            case paddingPixels = "padding_pixels"
            case extrusionPixels = "extrusion_pixels"
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
            let textures: [String: Texture]

            struct Texture: Decodable, Sendable {
                let page: String
                let pageFile: String
                let textureRectPixels: [Int]
                let packedRectPixels: [Int]
                let payloadSHA256: String
                let paddingPixels: Int
                let extrusionPixels: Int

                enum CodingKeys: String, CodingKey {
                    case page
                    case pageFile = "page_file"
                    case textureRectPixels = "texture_rect_pixels"
                    case packedRectPixels = "packed_rect_pixels"
                    case payloadSHA256 = "payload_sha256"
                    case paddingPixels = "padding_pixels"
                    case extrusionPixels = "extrusion_pixels"
                }
            }

            enum CodingKeys: String, CodingKey {
                case pixels, textures
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
    let pages: [Page]
    let inventory: [InventoryItem]
    let compiledNetwork: CompiledNetwork

    enum CodingKeys: String, CodingKey {
        case schema
        case packID = "pack_id"
        case productionSelection = "production_selection"
        case assets, pages, inventory
        case compiledNetwork = "compiled_network"
    }
}
