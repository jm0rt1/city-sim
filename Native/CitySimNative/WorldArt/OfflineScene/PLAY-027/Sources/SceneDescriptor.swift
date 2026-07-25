import Foundation

struct FileReference: Codable, Equatable {
    let role: String
    let file: String
    let sha256: String
}

struct DerivationRecord: Codable, Equatable {
    let sourceKind: String
    let siblingSource: String?
    let mirror: Bool
    let rotationDegrees: Double
    let transform: String
}

struct RegistrationDescriptor: Codable, Equatable {
    let tileBasisPoints: [Double]
    let sceneFootprintUnits: [Double]
    let footprintPolygonSource: [[Double]]
    let groundPivotSource: [Double]
    let contactPolygonWorld: [[Double]]
    let frontageEdgeSource: [[Double]]
    let frontageSocketSource: [Double]
    let doorBaseSource: [[Double]]
    let presentationEnvelopeSource: [Double]
    let shadowEnvelopeSource: [Double]
    let orientationTransform: String
}

struct CameraDescriptor: Codable, Equatable {
    let projection: String
    let yawDegrees: Double
    let elevationDegrees: Double
    let orthographicScale: Double
    let renderViewportPixels: [Int]
    let oversamplingFactor: Int
    let positionWorld: [Double]
    let targetWorld: [Double]
    let sourceGroundCenter: [Double]
    let postProjectionOffsetPixels: [Double]
}

struct SamplingDownsampleDescriptor: Codable, Equatable {
    let filter: String
    let scale: Double
    let aspectRatio: Double
}

struct SamplingCIContextDescriptor: Codable, Equatable {
    let useSoftwareRenderer: Bool
    let cacheIntermediates: Bool
    let workingColorSpace: String
    let outputColorSpace: String
}

struct SamplingQuantizerDescriptor: Codable, Equatable {
    let id: String
    let step: Int
    let midpointOffset: Int
    let chromaBypassRGBA: [Int]
}

struct SamplingCanonicalizerDescriptor: Codable, Equatable {
    let id: String
    let encoder: String
    let postEncoder: String
    let format: String
}

struct SamplingBoundaryAssistDescriptor: Codable, Equatable {
    let algorithm: String
    let version: Int
    let baseQuantizedMajorityCount: Int
    let requiredBoundaryVoteCount: Int
    let effectiveSupportCount: Int
    let maximumCompetingSupportAfterBoundaryReclassification: Int
    let quantizerStep: Int
    let quantizerMidpointOffset: Int
    let boundaryBandWidthValues: Int
    let requiresSameChannelEvidence: Bool
    let immutablePrequantizedBuffer: Bool
    let recordsBoundaryVoteReason: Bool
}

struct SamplingPostQuantizationCanonicalizerDescriptor:
    Codable, Equatable
{
    let algorithm: String
    let version: Int
    let quantizationQuantum: Int
    let neighborhoodSize: Int
    let majorityThreshold: Int
    let requiresFullyOpaqueNeighborhood: Bool
    let immutableSourceBuffer: Bool
    let requiresChromaFreeNeighborhood: Bool
    let channels: String
    let preservesAlpha: Bool
    let preservesChroma: Bool
    let boundaryAssist: SamplingBoundaryAssistDescriptor?
}

struct SamplingDescriptor: Codable, Equatable {
    let contractID: String
    let sourceRevisionBinding: String
    let purpose: String
    let sceneKitAntialiasing: String
    let sceneKitShadows: String?
    let sceneKitLightingMode: String?
    let linearOversamplingFactor: Int
    let downsample: SamplingDownsampleDescriptor
    let ciContext: SamplingCIContextDescriptor
    let quantizer: SamplingQuantizerDescriptor
    let canonicalizer: SamplingCanonicalizerDescriptor
    let postQuantizationCanonicalizer:
        SamplingPostQuantizationCanonicalizerDescriptor?
}

struct LightDescriptor: Codable, Equatable {
    let keyOrigin: [Double]
    let keyIntensity: Double
    let keyColorRGBA: [Double]
    let ambientIntensity: Double
    let ambientColorRGBA: [Double]
    let shadowVectorSource: [Double]
    let shadowOpacity: Double
    let shadowBlurSourcePixels: Double
    let shadowReceiver: String
}

struct ChimneyDescriptor: Codable, Equatable {
    let positionWorld: [Double]
    let dimensions: [Double]
    let materialID: String
}

struct MassBlockDescriptor: Codable, Equatable {
    let id: String
    let dimensions: [Double]
    let positionWorld: [Double]
    let materialID: String
}

struct RoofVolumeDescriptor: Codable, Equatable {
    let id: String
    let shape: String
    let dimensions: [Double]
    let positionWorld: [Double]
    let materialID: String
    let trimMaterialID: String
}

struct TrimBandDescriptor: Codable, Equatable {
    let id: String
    let dimensions: [Double]
    let positionWorld: [Double]
    let materialID: String
}

struct BuildingDescriptor: Codable, Equatable {
    let width: Double
    let depth: Double
    let foundationHeight: Double
    let floorHeight: Double
    let floors: Int
    let wallHeight: Double
    let roofHeight: Double
    let roofOverhang: Double
    let wallMaterialID: String
    let trimMaterialID: String
    let roofMaterialID: String
    let foundationMaterialID: String
    let chimney: ChimneyDescriptor
    let massingProfile: String?
    let massBlocks: [MassBlockDescriptor]?
    let roofVolumes: [RoofVolumeDescriptor]?
    let trimBands: [TrimBandDescriptor]?
    let usesLegacyDomesticDetails: Bool?
}

struct WindowBayDescriptor: Codable, Equatable {
    let id: String
    let centerWorld: [Double]
    let width: Double
    let height: Double
    let sillHeight: Double
    let floor: Int
    let materialID: String
}

struct WindowRhythmDescriptor: Codable, Equatable {
    let id: String
    let centersWorld: [[Double]]
    let width: Double
    let height: Double
    let sillHeight: Double
    let floor: Int
    let materialID: String
}

struct FacadeDescriptor: Codable, Equatable {
    let id: String
    let direction: String
    let edgeWorld: [[Double]]
    let materialID: String
    let hasEntrance: Bool
    let windowBays: [WindowBayDescriptor]
    let windowRhythms: [WindowRhythmDescriptor]?
}

struct EntranceDescriptor: Codable, Equatable {
    let facadeID: String
    let baseWorld: [Double]
    let width: Double
    let height: Double
    let depth: Double
    let doorMaterialID: String
    let surroundMaterialID: String
    let stepCount: Int
    let stepRun: Double
    let canopyDepth: Double
    let hingeSide: String
    let pavilionWidth: Double
    let pavilionDepth: Double
    let pavilionHeight: Double
    let pavilionRoofHeight: Double
    let pavilionMaterialID: String
    let porchWidth: Double
    let porchColumnWidth: Double
    let porchLateralOffset: Double
    let style: String?
}

struct PropDescriptor: Codable, Equatable {
    let id: String
    let kind: String
    let positionWorld: [Double]
    let dimensions: [Double]
    let materialID: String
}

struct OcclusionExclusionDescriptor: Codable, Equatable {
    let id: String
    let purpose: String
    let polygonWorld: [[Double]]
}

struct SceneDescriptor: Codable, Equatable {
    let schema: Int
    let task: String
    let sceneGeometryID: String
    let logicalBuildingID: String
    let family: String
    let level: Int
    let variantID: String
    let viewDirection: String
    let sourceRevision: String
    let authoredIndependently: Bool
    let productionSelected: Bool
    let derivation: DerivationRecord
    let toolchainFingerprint: FileReference
    let styleAnchor: FileReference
    let materialLibrary: FileReference
    let registration: RegistrationDescriptor
    let camera: CameraDescriptor
    let sampling: SamplingDescriptor?
    let light: LightDescriptor
    let building: BuildingDescriptor
    let facades: [FacadeDescriptor]
    let entrance: EntranceDescriptor
    let props: [PropDescriptor]
    let occlusionExclusions: [OcclusionExclusionDescriptor]
}

struct MaterialLibraryDescriptor: Codable {
    let schema: Int
    let task: String
    let libraryID: String
    let source: String
    let styleAnchorFile: String
    let styleAnchorSHA256: String
    let familyAnchorFile: String
    let familyAnchorSHA256: String
    let imageGenMaterialSwatchesUsed: Bool
    let colorSpace: String
    let materials: [MaterialDescriptor]
    let productionSelected: Bool
}

struct MaterialDescriptor: Codable {
    let id: String
    let baseColorRGBA: [Double]
    let roughness: Double
    let metalness: Double
    let emissionRGBA: [Double]?
    let pattern: String
    let physicalScaleWorld: [Double]
}
