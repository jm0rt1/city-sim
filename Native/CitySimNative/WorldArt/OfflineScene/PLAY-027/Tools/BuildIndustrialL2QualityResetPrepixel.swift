import CoreGraphics
import CoreText
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum QualityResetError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l2-quality-reset-prepixel --repository-root <path> --output-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

struct QualityFileReference: Codable {
    let file: String
    let sha256: String
}

struct QualityDerivation: Codable {
    let sourceKind: String
    let siblingSource: String?
    let mirror: Bool
    let rotationDegrees: Double
    let transform: String
}

struct QualityRegistration: Codable {
    let tileBasisPoints: [Double]
    let sceneFootprintUnits: [Double]
    let footprintPolygonSource: [[Double]]
    let groundPivotSource: [Double]
    let contactPolygonWorld: [[Double]]
    let frontageEdgeSource: [[Double]]
    let frontageSocketSource: [Double]
    let frontageEdgeWorld: [[Double]]
    let shadowVectorSource: [Double]
    let shadowOpacity: Double
    let orientationTransform: String
}

struct QualityCamera: Codable {
    let projection: String
    let yawDegrees: Double
    let elevationDegrees: Double
    let orthographicScale: Double
    let renderViewportPixels: [Int]
    let positionWorld: [Double]
    let targetWorld: [Double]
    let sourceGroundCenter: [Double]
    let postProjectionOffsetPixels: [Double]
}

struct QualityLight: Codable {
    let keyOrigin: [Double]
    let keyIntensity: Double
    let keyColorRGBA: [Double]
    let ambientIntensity: Double
    let ambientColorRGBA: [Double]
    let authoredContactShadowDirection: String
}

struct QualityComponent: Codable {
    let id: String
    let category: String
    let primitive: String
    let positionWorld: [Double]
    let dimensions: [Double]
    let materialRole: String
    let frontageDirection: String?
    let nativeScaleCluster: String?
    let purpose: String
}

struct QualityScene: Codable {
    let schema: Int
    let task: String
    let logicalBuildingID: String
    let level: Int
    let variantID: String
    let sourceRevision: String
    let descriptorPurpose: String
    let viewDirection: String
    let sceneGeometryID: String
    let authoredIndependently: Bool
    let productionSelected: Bool
    let derivation: QualityDerivation
    let materialLibrary: QualityFileReference
    let registration: QualityRegistration
    let camera: QualityCamera
    let light: QualityLight
    let components: [QualityComponent]
}

struct QualityMaterial: Codable {
    let id: String
    let baseColorRGBA: [Double]
    let roughness: Double
    let metalness: Double
    let pattern: String
    let physicalScaleWorld: [Double]
    let sourceSwatch: QualityFileReference?
    let sourceSwatchDisposition: String
    let purpose: String
}

struct QualityMaterialLibrary: Codable {
    let schema: Int
    let task: String
    let libraryID: String
    let sourceRevision: String
    let colorSpace: String
    let imageGenMaterialSwatchesUsed: Bool
    let materials: [QualityMaterial]
    let productionSelected: Bool
}

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        throw QualityResetError.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func relative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix) ? String(url.path.dropFirst(prefix.count)) : url.path
}

private func encoded<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(value)
    data.append(0x0a)
    return data
}

private func component(
    _ id: String,
    _ category: String,
    _ primitive: String,
    _ position: [Double],
    _ dimensions: [Double],
    _ material: String,
    frontage: String? = nil,
    cluster: String? = nil,
    purpose: String
) -> QualityComponent {
    QualityComponent(
        id: id,
        category: category,
        primitive: primitive,
        positionWorld: position,
        dimensions: dimensions,
        materialRole: material,
        frontageDirection: frontage,
        nativeScaleCluster: cluster,
        purpose: purpose
    )
}

private func component(
    _ id: String,
    _ category: String,
    _ position: [Double],
    _ dimensions: [Double],
    _ material: String,
    frontage: String? = nil,
    cluster: String? = nil,
    purpose: String
) -> QualityComponent {
    component(
        id,
        category,
        "box",
        position,
        dimensions,
        material,
        frontage: frontage,
        cluster: cluster,
        purpose: purpose
    )
}

private func northComponents() -> [QualityComponent] {
    [
        component("n-foundation", "foundation", [0, 1.5, 1], [54, 3, 52], "cast-concrete-plinth", purpose: "continuous grounded concrete plinth"),
        component("n-hall-west", "production-mass", [-16.5, 19, 3], [21, 35, 36], "galvanized-corrugated-northwest", purpose: "clear-span production hall west bay"),
        component("n-hall-east", "production-mass", [16.5, 19, 3], [21, 35, 36], "blue-gray-painted-steel", purpose: "clear-span production hall east bay"),
        component("n-rear-process", "process-mass", [18, 25, 18], [16, 47, 16], "warm-concrete-northwest", purpose: "stepped tall process volume offset from the loading sightline"),
        component("n-admin-bar", "administration", [17, 11.5, -18], [20, 20, 16], "warm-concrete-side", frontage: "north", purpose: "two-storey road-facing administration bar"),
        component("n-admin-step", "administration", [6, 7, -22], [10, 11, 8], "warm-concrete-northwest", frontage: "north", purpose: "lower staff entrance step"),
        component("n-loading-recess", "loading-recess", [0, 9, -15.8], [25, 15, 1.6], "deep-loading-recess", frontage: "north", purpose: "deep three-position dock throat"),
        component("n-dock-door-a", "loading-door", [-8, 8.5, -16.8], [6, 12, 1], "sectional-loading-door", frontage: "north", purpose: "west loading door"),
        component("n-dock-door-b", "loading-door", [0, 8.5, -16.8], [6, 12, 1], "sectional-loading-door", frontage: "north", purpose: "center loading door"),
        component("n-dock-door-c", "loading-door", [8, 8.5, -16.8], [6, 12, 1], "sectional-loading-door", frontage: "north", purpose: "east loading door"),
        component("n-dock-seal-a", "dock-frame", [-8, 9, -17.5], [8, 15, 0.8], "dock-seal-charcoal", frontage: "north", purpose: "high contrast dock seal"),
        component("n-dock-seal-b", "dock-frame", [0, 9, -17.5], [8, 15, 0.8], "dock-seal-charcoal", frontage: "north", purpose: "high contrast dock seal"),
        component("n-dock-seal-c", "dock-frame", [8, 9, -17.5], [8, 15, 0.8], "dock-seal-charcoal", frontage: "north", purpose: "high contrast dock seal"),
        component("n-canopy", "dock-canopy", [0, 17, -21], [29, 2.2, 10], "galvanized-service-metal", frontage: "north", purpose: "deep dock canopy visible above far edge"),
        component("n-canopy-post-west", "structure", [-13, 8.5, -24.5], [1.4, 17, 1.4], "painted-structural-steel", frontage: "north", purpose: "canopy column"),
        component("n-canopy-post-east", "structure", [13, 8.5, -24.5], [1.4, 17, 1.4], "painted-structural-steel", frontage: "north", purpose: "canopy column"),
        component("n-portal-post-west", "loading-portal", [-8, 29, -18], [2, 30, 2], "painted-structural-steel", frontage: "north", purpose: "grounded loading portal rising through the far-edge silhouette"),
        component("n-portal-post-east", "loading-portal", [8, 29, -18], [2, 30, 2], "painted-structural-steel", frontage: "north", purpose: "grounded loading portal rising through the far-edge silhouette"),
        component("n-portal-header", "loading-portal", [0, 44, -18], [18, 3, 3], "safety-yellow", frontage: "north", purpose: "restrained roof-clearing loading header"),
        component("n-apron", "service-apron", [0, 0.8, -25], [30, 1.2, 6], "service-apron-concrete", frontage: "north", purpose: "socket-aligned loading apron"),
        component("n-apron-joint-a", "surface-detail", [-8, 1.45, -25], [0.6, 0.25, 6], "apron-joint", frontage: "north", cluster: "n-apron-joints", purpose: "readable slab joint"),
        component("n-apron-joint-b", "surface-detail", [8, 1.45, -25], [0.6, 0.25, 6], "apron-joint", frontage: "north", cluster: "n-apron-joints", purpose: "readable slab joint"),
        component("n-hall-roof-west", "roof", [-16.5, 37, 3], [22, 2.2, 37], "dark-roof-membrane", purpose: "membrane roof with coping"),
        component("n-hall-roof-east", "roof", [16.5, 37, 3], [22, 2.2, 37], "dark-roof-membrane", purpose: "membrane roof with coping"),
        component("n-process-roof", "roof", [2, 49, 18], [25, 2.2, 17], "dark-roof-membrane", purpose: "high process roof"),
        component("n-roof-monitor-west", "clerestory", [-16, 41, 4], [14, 7, 6], "blue-gray-painted-steel", purpose: "daylight roof monitor"),
        component("n-roof-monitor-east", "clerestory", [15, 41.5, 2], [12, 8, 6], "galvanized-corrugated-northwest", purpose: "asymmetric daylight roof monitor"),
        component("n-admin-glazing", "window-group", [17, 13, -26.2], [13, 7, 0.8], "industrial-glazing", frontage: "north", purpose: "human-scale administration glazing"),
        component("n-admin-return-glazing", "window-group", [27.2, 13, -18], [0.8, 7, 10], "warm-interior-glazing", purpose: "visible administration return glazing"),
        component("n-staff-door", "person-door", [6, 5, -26.4], [3.5, 7, 0.8], "warm-interior-glazing", frontage: "north", purpose: "staff entrance"),
        component("n-admin-canopy", "person-canopy", [6, 9.5, -25], [8, 1.2, 4], "painted-structural-steel", frontage: "north", purpose: "staff entrance canopy"),
        component("n-hvac-a", "roof-equipment", "cylinder", [-19, 42, 8], [5, 6, 5], "galvanized-service-metal", purpose: "grouped rooftop air handler"),
        component("n-hvac-b", "roof-equipment", [20, 41, 7], [8, 5, 6], "galvanized-service-metal", purpose: "screened rooftop air handler"),
        component("n-exhaust-a", "process-equipment", "cylinder", [-3, 57, 19], [4, 14, 4], "oxide-process-metal", purpose: "process exhaust stack"),
        component("n-exhaust-b", "process-equipment", "cylinder", [5, 55, 19], [3, 11, 3], "galvanized-service-metal", purpose: "secondary process vent"),
        component("n-tank", "process-equipment", "cylinder", [-21, 10, 19], [8, 16, 8], "oxide-process-metal", purpose: "service tank cluster"),
        component("n-pipe-bridge", "service-pipe", [-10, 29, 18], [20, 2, 2], "galvanized-service-metal", cluster: "n-pipe-run", purpose: "visible process pipe bridge"),
        component("n-downpipe", "drainage", "cylinder", [27, 17, 12], [1.2, 29, 1.2], "galvanized-service-metal", cluster: "n-drainage", purpose: "roof drainage downpipe"),
        component("n-gutter", "drainage", [16, 37.5, 22], [22, 1, 1.2], "galvanized-service-metal", cluster: "n-drainage", purpose: "roof edge gutter"),
        component("n-panel-seam-a", "surface-detail", [8, 19, 21.3], [1.2, 30, 0.6], "painted-structural-steel", cluster: "n-panel-rhythm", purpose: "native-scale corrugated facade rhythm"),
        component("n-panel-seam-b", "surface-detail", [16, 19, 21.3], [1.2, 30, 0.6], "painted-structural-steel", cluster: "n-panel-rhythm", purpose: "native-scale corrugated facade rhythm"),
        component("n-panel-seam-c", "surface-detail", [24, 19, 21.3], [1.2, 30, 0.6], "painted-structural-steel", cluster: "n-panel-rhythm", purpose: "native-scale corrugated facade rhythm"),
        component("n-bollard-a", "safety", "cylinder", [-12, 3, -26], [1.2, 5, 1.2], "safety-yellow", frontage: "north", cluster: "n-bollards", purpose: "dock protection"),
        component("n-bollard-b", "safety", "cylinder", [12, 3, -26], [1.2, 5, 1.2], "safety-yellow", frontage: "north", cluster: "n-bollards", purpose: "dock protection"),
        component("n-guardrail", "safety", [0, 19.5, -24.8], [27, 1, 1], "safety-yellow", frontage: "north", cluster: "n-rail", purpose: "canopy edge safety rail"),
    ]
}

private func eastComponents() -> [QualityComponent] {
    [
        component("e-foundation", "foundation", [0, 1.5, 0], [54, 3, 54], "cast-concrete-plinth", purpose: "continuous grounded concrete plinth"),
        component("e-main-hall", "production-mass", [-5, 20, 1], [38, 37, 44], "blue-gray-painted-steel", purpose: "wide clear-span production hall"),
        component("e-north-process", "process-mass", [-17, 27, -16], [18, 51, 18], "galvanized-corrugated-northwest", purpose: "tall corner process bay"),
        component("e-south-fabrication", "production-mass", [-12, 15, 20], [25, 27, 14], "warm-concrete-side", purpose: "lower fabrication wing"),
        component("e-admin-corner", "administration", [17, 12, 18], [18, 21, 18], "warm-concrete-northwest", frontage: "east", purpose: "two-storey corner administration block"),
        component("e-stair-tower", "administration", [20, 18, 7], [10, 33, 8], "blue-gray-painted-steel", frontage: "east", purpose: "glazed stair tower"),
        component("e-loading-recess", "loading-recess", [20.5, 9, -5], [1.8, 15, 31], "deep-loading-recess", frontage: "east", purpose: "deep three-position dock throat"),
        component("e-dock-door-a", "loading-door", [21.7, 8.5, -15], [1, 12, 6], "sectional-loading-door", frontage: "east", purpose: "north loading door"),
        component("e-dock-door-b", "loading-door", [21.7, 8.5, -5], [1, 12, 6], "sectional-loading-door", frontage: "east", purpose: "center loading door"),
        component("e-dock-door-c", "loading-door", [21.7, 8.5, 5], [1, 12, 6], "sectional-loading-door", frontage: "east", purpose: "south loading door"),
        component("e-dock-seal-a", "dock-frame", [22.4, 9, -15], [0.8, 15, 8], "dock-seal-charcoal", frontage: "east", purpose: "high contrast dock seal"),
        component("e-dock-seal-b", "dock-frame", [22.4, 9, -5], [0.8, 15, 8], "dock-seal-charcoal", frontage: "east", purpose: "high contrast dock seal"),
        component("e-dock-seal-c", "dock-frame", [22.4, 9, 5], [0.8, 15, 8], "dock-seal-charcoal", frontage: "east", purpose: "high contrast dock seal"),
        component("e-canopy", "dock-canopy", [25, 17, -5], [6, 2.2, 35], "galvanized-service-metal", frontage: "east", purpose: "deep dock canopy"),
        component("e-canopy-post-north", "structure", [27, 8.5, -21], [1.4, 17, 1.4], "painted-structural-steel", frontage: "east", purpose: "canopy column"),
        component("e-canopy-post-south", "structure", [27, 8.5, 11], [1.4, 17, 1.4], "painted-structural-steel", frontage: "east", purpose: "canopy column"),
        component("e-apron", "service-apron", [25, 0.8, -5], [6, 1.2, 38], "service-apron-concrete", frontage: "east", purpose: "socket-aligned loading apron"),
        component("e-apron-joint-a", "surface-detail", [25, 1.45, -11], [6, 0.25, 0.6], "apron-joint", frontage: "east", cluster: "e-apron-joints", purpose: "readable slab joint"),
        component("e-apron-joint-b", "surface-detail", [25, 1.45, 1], [6, 0.25, 0.6], "apron-joint", frontage: "east", cluster: "e-apron-joints", purpose: "readable slab joint"),
        component("e-main-roof", "roof", [-5, 39, 1], [39, 2.2, 45], "dark-roof-membrane", purpose: "broad membrane production roof"),
        component("e-process-roof", "roof", [-17, 53, -16], [19, 2.2, 19], "dark-roof-membrane", purpose: "high process roof"),
        component("e-fabrication-roof", "roof", [-12, 29.5, 20], [26, 2.2, 15], "dark-roof-membrane", purpose: "lower fabrication roof"),
        component("e-clerestory-a", "clerestory", [-6, 43, -10], [22, 7, 6], "galvanized-corrugated-northwest", purpose: "north daylight monitor"),
        component("e-clerestory-b", "clerestory", [0, 42, 9], [18, 6, 6], "blue-gray-painted-steel", purpose: "offset daylight monitor"),
        component("e-admin-glazing-east", "window-group", [26.3, 13, 18], [0.8, 8, 12], "industrial-glazing", frontage: "east", purpose: "administration glazing"),
        component("e-stair-glazing", "window-group", [25.4, 20, 7], [0.8, 23, 5], "warm-interior-glazing", frontage: "east", purpose: "vertical stair glazing"),
        component("e-person-door", "person-door", [26.5, 5, 22], [0.8, 7, 3.5], "warm-interior-glazing", frontage: "east", purpose: "staff entrance"),
        component("e-person-canopy", "person-canopy", [26, 9.5, 22], [4, 1.2, 8], "painted-structural-steel", frontage: "east", purpose: "staff entrance canopy"),
        component("e-hvac-a", "roof-equipment", [-5, 44, 2], [9, 6, 7], "galvanized-service-metal", purpose: "screened roof air handler"),
        component("e-hvac-b", "roof-equipment", [9, 43, -6], [7, 5, 6], "galvanized-service-metal", purpose: "secondary roof air handler"),
        component("e-exhaust-a", "process-equipment", "cylinder", [-19, 62, -17], [4, 16, 4], "oxide-process-metal", purpose: "process exhaust stack"),
        component("e-exhaust-b", "process-equipment", "cylinder", [-13, 59, -14], [3, 11, 3], "galvanized-service-metal", purpose: "secondary vent"),
        component("e-tank-a", "process-equipment", "cylinder", [-22, 10, 20], [8, 16, 8], "oxide-process-metal", purpose: "fabrication service tank"),
        component("e-tank-b", "process-equipment", "cylinder", [-13, 8, 23], [6, 12, 6], "galvanized-service-metal", purpose: "secondary service tank"),
        component("e-pipe-run", "service-pipe", [-17, 34, 2], [2, 2, 28], "galvanized-service-metal", cluster: "e-pipe-run", purpose: "visible process pipe riser"),
        component("e-downpipe", "drainage", "cylinder", [14, 18, -21], [1.2, 31, 1.2], "galvanized-service-metal", cluster: "e-drainage", purpose: "roof drainage downpipe"),
        component("e-gutter", "drainage", [14, 39.5, 1], [1.2, 1, 43], "galvanized-service-metal", cluster: "e-drainage", purpose: "roof edge gutter"),
        component("e-panel-seam-a", "surface-detail", [14.3, 19, -12], [0.6, 30, 1.2], "painted-structural-steel", cluster: "e-panel-rhythm", purpose: "native-scale painted panel rhythm"),
        component("e-panel-seam-b", "surface-detail", [14.3, 19, 0], [0.6, 30, 1.2], "painted-structural-steel", cluster: "e-panel-rhythm", purpose: "native-scale painted panel rhythm"),
        component("e-panel-seam-c", "surface-detail", [14.3, 19, 12], [0.6, 30, 1.2], "painted-structural-steel", cluster: "e-panel-rhythm", purpose: "native-scale painted panel rhythm"),
        component("e-bollard-a", "safety", "cylinder", [27, 3, -23], [1.2, 5, 1.2], "safety-yellow", frontage: "east", cluster: "e-bollards", purpose: "dock protection"),
        component("e-bollard-b", "safety", "cylinder", [27, 3, 13], [1.2, 5, 1.2], "safety-yellow", frontage: "east", cluster: "e-bollards", purpose: "dock protection"),
        component("e-guardrail", "safety", [27.2, 19.5, -5], [1, 1, 33], "safety-yellow", frontage: "east", cluster: "e-rail", purpose: "canopy edge safety rail"),
    ]
}

private func southComponents() -> [QualityComponent] {
    [
        component("s-foundation", "foundation", [0, 1.5, 0], [54, 3, 54], "cast-concrete-plinth", purpose: "continuous grounded concrete plinth"),
        component("s-main-hall", "production-mass", [2, 19, -5], [42, 35, 38], "galvanized-corrugated-northwest", purpose: "wide clear-span production hall"),
        component("s-process-east", "process-mass", [18, 25, 9], [16, 47, 22], "blue-gray-painted-steel", purpose: "tall southeast process bay"),
        component("s-fabrication-west", "production-mass", [-20, 14, -8], [12, 25, 32], "warm-concrete-side", purpose: "lower fabrication wing"),
        component("s-admin-west", "administration", [-14, 11.5, 19], [24, 20, 16], "warm-concrete-northwest", frontage: "south", purpose: "two-storey road-facing administration bar"),
        component("s-admin-step", "administration", [0, 7, 23], [10, 11, 8], "warm-concrete-side", frontage: "south", purpose: "lower visitor entrance step"),
        component("s-loading-recess", "loading-recess", [10, 9, 17.5], [24, 15, 1.8], "deep-loading-recess", frontage: "south", purpose: "deep three-position dock throat"),
        component("s-dock-door-a", "loading-door", [2, 8.5, 18.7], [6, 12, 1], "sectional-loading-door", frontage: "south", purpose: "west loading door"),
        component("s-dock-door-b", "loading-door", [10, 8.5, 18.7], [6, 12, 1], "sectional-loading-door", frontage: "south", purpose: "center loading door"),
        component("s-dock-door-c", "loading-door", [18, 8.5, 18.7], [6, 12, 1], "sectional-loading-door", frontage: "south", purpose: "east loading door"),
        component("s-dock-seal-a", "dock-frame", [2, 9, 19.4], [8, 15, 0.8], "dock-seal-charcoal", frontage: "south", purpose: "high contrast dock seal"),
        component("s-dock-seal-b", "dock-frame", [10, 9, 19.4], [8, 15, 0.8], "dock-seal-charcoal", frontage: "south", purpose: "high contrast dock seal"),
        component("s-dock-seal-c", "dock-frame", [18, 9, 19.4], [8, 15, 0.8], "dock-seal-charcoal", frontage: "south", purpose: "high contrast dock seal"),
        component("s-canopy", "dock-canopy", [10, 17, 23], [28, 2.2, 9], "galvanized-service-metal", frontage: "south", purpose: "deep dock canopy"),
        component("s-canopy-post-west", "structure", [-3, 8.5, 26.5], [1.4, 17, 1.4], "painted-structural-steel", frontage: "south", purpose: "canopy column"),
        component("s-canopy-post-east", "structure", [23, 8.5, 26.5], [1.4, 17, 1.4], "painted-structural-steel", frontage: "south", purpose: "canopy column"),
        component("s-apron", "service-apron", [10, 0.8, 25], [30, 1.2, 6], "service-apron-concrete", frontage: "south", purpose: "socket-aligned loading apron"),
        component("s-apron-joint-a", "surface-detail", [2, 1.45, 25], [0.6, 0.25, 6], "apron-joint", frontage: "south", cluster: "s-apron-joints", purpose: "readable slab joint"),
        component("s-apron-joint-b", "surface-detail", [18, 1.45, 25], [0.6, 0.25, 6], "apron-joint", frontage: "south", cluster: "s-apron-joints", purpose: "readable slab joint"),
        component("s-main-roof", "roof", [2, 37, -5], [43, 2.2, 39], "dark-roof-membrane", purpose: "broad membrane production roof"),
        component("s-process-roof", "roof", [18, 49, 9], [17, 2.2, 23], "dark-roof-membrane", purpose: "high process roof"),
        component("s-fabrication-roof", "roof", [-20, 27.5, -8], [13, 2.2, 33], "dark-roof-membrane", purpose: "lower fabrication roof"),
        component("s-sawlight-a", "clerestory", [-8, 41, -8], [14, 7, 7], "blue-gray-painted-steel", purpose: "western roof monitor"),
        component("s-sawlight-b", "clerestory", [8, 42, -8], [14, 9, 7], "galvanized-corrugated-northwest", purpose: "taller eastern roof monitor"),
        component("s-admin-glazing", "window-group", [-14, 13, 27.3], [15, 7, 0.8], "industrial-glazing", frontage: "south", purpose: "administration glazing"),
        component("s-person-door", "person-door", [0, 5, 27.5], [3.5, 7, 0.8], "warm-interior-glazing", frontage: "south", purpose: "visitor entrance"),
        component("s-person-canopy", "person-canopy", [0, 9.5, 26], [8, 1.2, 4], "painted-structural-steel", frontage: "south", purpose: "visitor entrance canopy"),
        component("s-hvac-a", "roof-equipment", [-5, 43, -1], [9, 6, 7], "galvanized-service-metal", purpose: "screened roof air handler"),
        component("s-hvac-b", "roof-equipment", [9, 42, -14], [7, 5, 6], "galvanized-service-metal", purpose: "secondary roof air handler"),
        component("s-exhaust-a", "process-equipment", "cylinder", [17, 58, 8], [4, 15, 4], "oxide-process-metal", purpose: "process exhaust stack"),
        component("s-exhaust-b", "process-equipment", "cylinder", [22, 55, 12], [3, 11, 3], "galvanized-service-metal", purpose: "secondary process vent"),
        component("s-tank-a", "process-equipment", "cylinder", [-22, 10, 14], [8, 16, 8], "oxide-process-metal", purpose: "service tank"),
        component("s-pipe-bridge", "service-pipe", [13, 31, 4], [2, 2, 24], "galvanized-service-metal", cluster: "s-pipe-run", purpose: "visible process pipe run"),
        component("s-downpipe", "drainage", "cylinder", [-19, 17, -24], [1.2, 29, 1.2], "galvanized-service-metal", cluster: "s-drainage", purpose: "roof drainage downpipe"),
        component("s-gutter", "drainage", [2, 37.5, -24], [41, 1, 1.2], "galvanized-service-metal", cluster: "s-drainage", purpose: "roof edge gutter"),
        component("s-panel-seam-a", "surface-detail", [-10, 19, 14.3], [1.2, 30, 0.6], "painted-structural-steel", cluster: "s-panel-rhythm", purpose: "native-scale corrugated facade rhythm"),
        component("s-panel-seam-b", "surface-detail", [2, 19, 14.3], [1.2, 30, 0.6], "painted-structural-steel", cluster: "s-panel-rhythm", purpose: "native-scale corrugated facade rhythm"),
        component("s-panel-seam-c", "surface-detail", [14, 19, 14.3], [1.2, 30, 0.6], "painted-structural-steel", cluster: "s-panel-rhythm", purpose: "native-scale corrugated facade rhythm"),
        component("s-bollard-a", "safety", "cylinder", [-4, 3, 26], [1.2, 5, 1.2], "safety-yellow", frontage: "south", cluster: "s-bollards", purpose: "dock protection"),
        component("s-bollard-b", "safety", "cylinder", [24, 3, 26], [1.2, 5, 1.2], "safety-yellow", frontage: "south", cluster: "s-bollards", purpose: "dock protection"),
        component("s-guardrail", "safety", [10, 19.5, 26.8], [27, 1, 1], "safety-yellow", frontage: "south", cluster: "s-rail", purpose: "canopy edge safety rail"),
    ]
}

private func westComponents() -> [QualityComponent] {
    [
        component("w-foundation", "foundation", [0, 1.5, 0], [54, 3, 54], "cast-concrete-plinth", purpose: "continuous grounded concrete plinth"),
        component("w-hall-north", "production-mass", [-3, 20, -16], [38, 37, 21], "galvanized-corrugated-northwest", purpose: "north clear-span production bay"),
        component("w-hall-south", "production-mass", [-3, 20, 16], [38, 37, 21], "blue-gray-painted-steel", purpose: "south clear-span production bay"),
        component("w-rear-process", "process-mass", [15, 26, -17], [20, 49, 18], "warm-concrete-side", purpose: "tall eastern process block offset from the loading sightline"),
        component("w-admin-south", "administration", [-18, 11.5, 17], [18, 20, 20], "warm-concrete-northwest", frontage: "west", purpose: "two-storey road-facing administration block"),
        component("w-admin-step", "administration", [-23, 7, 5], [8, 11, 10], "warm-concrete-side", frontage: "west", purpose: "lower staff entrance step"),
        component("w-loading-recess", "loading-recess", [-15.8, 9, -4], [1.6, 15, 25], "deep-loading-recess", frontage: "west", purpose: "deep three-position dock throat"),
        component("w-dock-door-a", "loading-door", [-16.8, 8.5, -12], [1, 12, 6], "sectional-loading-door", frontage: "west", purpose: "north loading door"),
        component("w-dock-door-b", "loading-door", [-16.8, 8.5, -4], [1, 12, 6], "sectional-loading-door", frontage: "west", purpose: "center loading door"),
        component("w-dock-door-c", "loading-door", [-16.8, 8.5, 4], [1, 12, 6], "sectional-loading-door", frontage: "west", purpose: "south loading door"),
        component("w-dock-seal-a", "dock-frame", [-17.5, 9, -12], [0.8, 15, 8], "dock-seal-charcoal", frontage: "west", purpose: "high contrast dock seal"),
        component("w-dock-seal-b", "dock-frame", [-17.5, 9, -4], [0.8, 15, 8], "dock-seal-charcoal", frontage: "west", purpose: "high contrast dock seal"),
        component("w-dock-seal-c", "dock-frame", [-17.5, 9, 4], [0.8, 15, 8], "dock-seal-charcoal", frontage: "west", purpose: "high contrast dock seal"),
        component("w-canopy", "dock-canopy", [-21, 17, -4], [10, 2.2, 29], "galvanized-service-metal", frontage: "west", purpose: "deep dock canopy visible above far edge"),
        component("w-canopy-post-north", "structure", [-24.5, 8.5, -17], [1.4, 17, 1.4], "painted-structural-steel", frontage: "west", purpose: "canopy column"),
        component("w-canopy-post-south", "structure", [-24.5, 8.5, 9], [1.4, 17, 1.4], "painted-structural-steel", frontage: "west", purpose: "canopy column"),
        component("w-portal-post-north", "loading-portal", [-18, 29, -8], [2, 30, 2], "painted-structural-steel", frontage: "west", purpose: "grounded loading portal rising through the far-edge silhouette"),
        component("w-portal-post-south", "loading-portal", [-18, 29, 8], [2, 30, 2], "painted-structural-steel", frontage: "west", purpose: "grounded loading portal rising through the far-edge silhouette"),
        component("w-portal-header", "loading-portal", [-18, 44, 0], [3, 3, 18], "safety-yellow", frontage: "west", purpose: "restrained roof-clearing loading header"),
        component("w-apron", "service-apron", [-25, 0.8, -4], [6, 1.2, 30], "service-apron-concrete", frontage: "west", purpose: "socket-aligned loading apron"),
        component("w-apron-joint-a", "surface-detail", [-25, 1.45, -12], [6, 0.25, 0.6], "apron-joint", frontage: "west", cluster: "w-apron-joints", purpose: "readable slab joint"),
        component("w-apron-joint-b", "surface-detail", [-25, 1.45, 4], [6, 0.25, 0.6], "apron-joint", frontage: "west", cluster: "w-apron-joints", purpose: "readable slab joint"),
        component("w-hall-roof-north", "roof", [-3, 39, -16], [39, 2.2, 22], "dark-roof-membrane", purpose: "north membrane roof"),
        component("w-hall-roof-south", "roof", [-3, 39, 16], [39, 2.2, 22], "dark-roof-membrane", purpose: "south membrane roof"),
        component("w-process-roof", "roof", [15, 51, -2], [21, 2.2, 25], "dark-roof-membrane", purpose: "high process roof"),
        component("w-roof-monitor-north", "clerestory", [-5, 43, -16], [18, 7, 7], "blue-gray-painted-steel", purpose: "north daylight monitor"),
        component("w-roof-monitor-south", "clerestory", [2, 42, 16], [14, 6, 7], "galvanized-corrugated-northwest", purpose: "offset south daylight monitor"),
        component("w-admin-glazing", "window-group", [-27.3, 13, 17], [0.8, 7, 13], "industrial-glazing", frontage: "west", purpose: "administration glazing"),
        component("w-admin-return-glazing", "window-group", [-18, 13, 27.2], [10, 7, 0.8], "warm-interior-glazing", purpose: "visible administration return glazing"),
        component("w-person-door", "person-door", [-27.5, 5, 5], [0.8, 7, 3.5], "warm-interior-glazing", frontage: "west", purpose: "staff entrance"),
        component("w-person-canopy", "person-canopy", [-26, 9.5, 5], [4, 1.2, 8], "painted-structural-steel", frontage: "west", purpose: "staff entrance canopy"),
        component("w-hvac-a", "roof-equipment", [-8, 44, -11], [9, 6, 7], "galvanized-service-metal", purpose: "screened roof air handler"),
        component("w-hvac-b", "roof-equipment", [-1, 43, 17], [7, 5, 6], "galvanized-service-metal", purpose: "secondary roof air handler"),
        component("w-exhaust-a", "process-equipment", "cylinder", [17, 60, -4], [4, 16, 4], "oxide-process-metal", purpose: "process exhaust stack"),
        component("w-exhaust-b", "process-equipment", "cylinder", [10, 57, 2], [3, 11, 3], "galvanized-service-metal", purpose: "secondary process vent"),
        component("w-tank-a", "process-equipment", "cylinder", [20, 10, 17], [8, 16, 8], "oxide-process-metal", purpose: "service tank"),
        component("w-tank-b", "process-equipment", "cylinder", [12, 8, 22], [6, 12, 6], "galvanized-service-metal", purpose: "secondary tank"),
        component("w-pipe-bridge", "service-pipe", [-5, 31, -2], [24, 2, 2], "galvanized-service-metal", cluster: "w-pipe-run", purpose: "visible cross-building pipe bridge"),
        component("w-downpipe", "drainage", "cylinder", [16, 18, 27], [1.2, 31, 1.2], "galvanized-service-metal", cluster: "w-drainage", purpose: "roof drainage downpipe"),
        component("w-gutter", "drainage", [-3, 39.5, 27], [37, 1, 1.2], "galvanized-service-metal", cluster: "w-drainage", purpose: "roof edge gutter"),
        component("w-panel-seam-a", "surface-detail", [16.3, 19, 8], [0.6, 30, 1.2], "painted-structural-steel", cluster: "w-panel-rhythm", purpose: "native-scale painted panel rhythm"),
        component("w-panel-seam-b", "surface-detail", [16.3, 19, 16], [0.6, 30, 1.2], "painted-structural-steel", cluster: "w-panel-rhythm", purpose: "native-scale painted panel rhythm"),
        component("w-panel-seam-c", "surface-detail", [16.3, 19, 24], [0.6, 30, 1.2], "painted-structural-steel", cluster: "w-panel-rhythm", purpose: "native-scale painted panel rhythm"),
        component("w-bollard-a", "safety", "cylinder", [-26, 3, -18], [1.2, 5, 1.2], "safety-yellow", frontage: "west", cluster: "w-bollards", purpose: "dock protection"),
        component("w-bollard-b", "safety", "cylinder", [-26, 3, 10], [1.2, 5, 1.2], "safety-yellow", frontage: "west", cluster: "w-bollards", purpose: "dock protection"),
        component("w-guardrail", "safety", [-24.8, 19.5, -4], [1, 1, 27], "safety-yellow", frontage: "west", cluster: "w-rail", purpose: "canopy edge safety rail"),
    ]
}

private func registration(_ direction: String) -> QualityRegistration {
    let edgeSource: [String: [[Double]]] = [
        "north": [[768, 640], [1024, 768]],
        "east": [[1024, 768], [768, 896]],
        "south": [[768, 896], [512, 768]],
        "west": [[512, 768], [768, 640]],
    ]
    let socketSource: [String: [Double]] = [
        "north": [896, 704],
        "east": [896, 832],
        "south": [640, 832],
        "west": [640, 704],
    ]
    let edgeWorld: [String: [[Double]]] = [
        "north": [[-28, -28], [28, -28]],
        "east": [[28, -28], [28, 28]],
        "south": [[28, 28], [-28, 28]],
        "west": [[-28, 28], [-28, -28]],
    ]
    return QualityRegistration(
        tileBasisPoints: [72, 36],
        sceneFootprintUnits: [72, 72],
        footprintPolygonSource: [[768, 640], [1024, 768], [768, 896], [512, 768]],
        groundPivotSource: [768, 896],
        contactPolygonWorld: [[-28, -28], [28, -28], [28, 28], [-28, 28]],
        frontageEdgeSource: edgeSource[direction]!,
        frontageSocketSource: socketSource[direction]!,
        frontageEdgeWorld: edgeWorld[direction]!,
        shadowVectorSource: [2, 1],
        shadowOpacity: 0.34,
        orientationTransform: "none"
    )
}

private let camera = QualityCamera(
    projection: "orthographic-2:1",
    yawDegrees: 45,
    elevationDegrees: 30,
    orthographicScale: 203.64675298172568,
    renderViewportPixels: [1536, 1024],
    positionWorld: [180, 146.9693845669907, 180],
    targetWorld: [0, 0, 0],
    sourceGroundCenter: [768, 768],
    postProjectionOffsetPixels: [0, 256]
)

private let light = QualityLight(
    keyOrigin: [-120, 180, -120],
    keyIntensity: 1000,
    keyColorRGBA: [1, 0.86, 0.68, 1],
    ambientIntensity: 0.5,
    ambientColorRGBA: [0.5, 0.46, 0.38, 1],
    authoredContactShadowDirection: "southeast"
)

private func materialLibrary(
    repositoryRoot: URL,
    evidenceRoot: URL
) throws -> QualityMaterialLibrary {
    let normalized = evidenceRoot.appendingPathComponent("material-swatches/normalized")
    func swatch(_ name: String) throws -> QualityFileReference {
        let url = normalized.appendingPathComponent("\(name).png")
        let data = try Data(contentsOf: url)
        return QualityFileReference(file: relative(url, root: repositoryRoot), sha256: sha256(data))
    }
    return QualityMaterialLibrary(
        schema: 1,
        task: "PLAY-027",
        libraryID: "industrial-l02-quality-reset-prepixel-v01-materials",
        sourceRevision: "quality-reset-prepixel-v01",
        colorSpace: "sRGB",
        imageGenMaterialSwatchesUsed: true,
        materials: [
            QualityMaterial(id: "deep-loading-recess", baseColorRGBA: [0.055, 0.065, 0.07, 1], roughness: 0.9, metalness: 0, pattern: "solid-depth-cavity", physicalScaleWorld: [8, 8], sourceSwatch: nil, sourceSwatchDisposition: "not-applicable", purpose: "deep dock and window cavity"),
            QualityMaterial(id: "dock-seal-charcoal", baseColorRGBA: [0.08, 0.09, 0.095, 1], roughness: 0.95, metalness: 0, pattern: "compressible-seal", physicalScaleWorld: [4, 4], sourceSwatch: nil, sourceSwatchDisposition: "not-applicable", purpose: "dock seal silhouette"),
            QualityMaterial(id: "dark-roof-membrane", baseColorRGBA: [0.14, 0.15, 0.16, 1], roughness: 0.92, metalness: 0, pattern: "rolled-membrane-seams", physicalScaleWorld: [8, 8], sourceSwatch: try swatch("dark-roof-membrane"), sourceSwatchDisposition: "accepted-for-prepixel-material-reference", purpose: "flat roof membrane"),
            QualityMaterial(id: "sectional-loading-door", baseColorRGBA: [0.19, 0.22, 0.23, 1], roughness: 0.7, metalness: 0.25, pattern: "horizontal-section-joints", physicalScaleWorld: [6, 12], sourceSwatch: nil, sourceSwatchDisposition: "not-applicable", purpose: "loading door"),
            QualityMaterial(id: "apron-joint", baseColorRGBA: [0.20, 0.21, 0.20, 1], roughness: 1, metalness: 0, pattern: "joint-line", physicalScaleWorld: [0.6, 6], sourceSwatch: nil, sourceSwatchDisposition: "not-applicable", purpose: "service apron joint"),
            QualityMaterial(id: "cast-concrete-plinth", baseColorRGBA: [0.27, 0.28, 0.27, 1], roughness: 0.96, metalness: 0, pattern: "procedural-formed-concrete", physicalScaleWorld: [4, 4], sourceSwatch: try swatch("aged-cast-concrete"), sourceSwatchDisposition: "rejected-for-direct-tiling-reference-only", purpose: "foundation and dock plinth"),
            QualityMaterial(id: "oxide-process-metal", baseColorRGBA: [0.39, 0.22, 0.14, 1], roughness: 0.78, metalness: 0.55, pattern: "restrained-oxide", physicalScaleWorld: [4, 4], sourceSwatch: nil, sourceSwatchDisposition: "not-applicable", purpose: "process equipment accent"),
            QualityMaterial(id: "blue-gray-painted-steel", baseColorRGBA: [0.30, 0.40, 0.44, 1], roughness: 0.72, metalness: 0.32, pattern: "vertical-painted-panel", physicalScaleWorld: [4, 4], sourceSwatch: try swatch("blue-gray-painted-steel"), sourceSwatchDisposition: "accepted-for-prepixel-material-reference", purpose: "painted production cladding"),
            QualityMaterial(id: "warm-concrete-side", baseColorRGBA: [0.43, 0.42, 0.38, 1], roughness: 0.93, metalness: 0, pattern: "procedural-formed-concrete", physicalScaleWorld: [4, 4], sourceSwatch: try swatch("aged-cast-concrete"), sourceSwatchDisposition: "rejected-for-direct-tiling-reference-only", purpose: "administration side plane"),
            QualityMaterial(id: "industrial-glazing", baseColorRGBA: [0.18, 0.34, 0.38, 1], roughness: 0.34, metalness: 0.12, pattern: "muted-mullion-grid", physicalScaleWorld: [8, 4], sourceSwatch: nil, sourceSwatchDisposition: "not-applicable", purpose: "cool administration glazing"),
            QualityMaterial(id: "service-apron-concrete", baseColorRGBA: [0.44, 0.44, 0.41, 1], roughness: 0.98, metalness: 0, pattern: "large-scored-slabs", physicalScaleWorld: [8, 8], sourceSwatch: try swatch("aged-cast-concrete"), sourceSwatchDisposition: "rejected-for-direct-tiling-reference-only", purpose: "loading apron"),
            QualityMaterial(id: "galvanized-corrugated-northwest", baseColorRGBA: [0.55, 0.59, 0.58, 1], roughness: 0.68, metalness: 0.65, pattern: "procedural-vertical-corrugation", physicalScaleWorld: [4, 4], sourceSwatch: try swatch("galvanized-corrugated-steel"), sourceSwatchDisposition: "rejected-for-direct-tiling-reference-only", purpose: "northwest-lit production cladding"),
            QualityMaterial(id: "painted-structural-steel", baseColorRGBA: [0.31, 0.36, 0.37, 1], roughness: 0.66, metalness: 0.58, pattern: "painted-steel", physicalScaleWorld: [4, 4], sourceSwatch: try swatch("blue-gray-painted-steel"), sourceSwatchDisposition: "accepted-for-prepixel-material-reference", purpose: "canopies, columns, and rails"),
            QualityMaterial(id: "warm-concrete-northwest", baseColorRGBA: [0.62, 0.59, 0.51, 1], roughness: 0.92, metalness: 0, pattern: "procedural-formed-concrete", physicalScaleWorld: [4, 4], sourceSwatch: try swatch("aged-cast-concrete"), sourceSwatchDisposition: "rejected-for-direct-tiling-reference-only", purpose: "northwest-lit administration and process concrete"),
            QualityMaterial(id: "galvanized-service-metal", baseColorRGBA: [0.65, 0.68, 0.66, 1], roughness: 0.62, metalness: 0.72, pattern: "fine-galvanized", physicalScaleWorld: [4, 4], sourceSwatch: try swatch("galvanized-corrugated-steel"), sourceSwatchDisposition: "rejected-for-direct-tiling-reference-only", purpose: "HVAC, pipes, gutters, and canopies"),
            QualityMaterial(id: "safety-yellow", baseColorRGBA: [0.88, 0.61, 0.12, 1], roughness: 0.61, metalness: 0.25, pattern: "solid-safety-paint", physicalScaleWorld: [2, 2], sourceSwatch: nil, sourceSwatchDisposition: "not-applicable", purpose: "restrained safety hierarchy"),
            QualityMaterial(id: "warm-interior-glazing", baseColorRGBA: [0.78, 0.59, 0.28, 1], roughness: 0.32, metalness: 0.08, pattern: "muted-warm-glazing", physicalScaleWorld: [4, 4], sourceSwatch: nil, sourceSwatchDisposition: "not-applicable", purpose: "human-scale entrance cue"),
        ],
        productionSelected: false
    )
}

private func scene(
    direction: String,
    components: [QualityComponent],
    materials: QualityFileReference
) -> QualityScene {
    QualityScene(
        schema: 1,
        task: "PLAY-027",
        logicalBuildingID: "industrial_l02",
        level: 2,
        variantID: "variant-0",
        sourceRevision: "quality-reset-prepixel-v01",
        descriptorPurpose: "non-authority-prepixel-quality-reset-design",
        viewDirection: direction,
        sceneGeometryID: "industrial-l02-quality-reset-\(direction)-geometry-v01",
        authoredIndependently: true,
        productionSelected: false,
        derivation: QualityDerivation(
            sourceKind: "independent-scene-description",
            siblingSource: nil,
            mirror: false,
            rotationDegrees: 0,
            transform: "none"
        ),
        materialLibrary: materials,
        registration: registration(direction),
        camera: camera,
        light: light,
        components: components
    )
}

private func color(_ rgba: [Double], multiplier: Double = 1) -> CGColor {
    CGColor(
        red: min(1, rgba[0] * multiplier),
        green: min(1, rgba[1] * multiplier),
        blue: min(1, rgba[2] * multiplier),
        alpha: rgba[3]
    )
}

private func grayscale(_ rgba: [Double]) -> [Double] {
    let y = rgba[0] * 0.2126 + rgba[1] * 0.7152 + rgba[2] * 0.0722
    return [y, y, y, rgba[3]]
}

private func drawText(
    _ text: String,
    at point: CGPoint,
    size: CGFloat,
    color: CGColor,
    context: CGContext
) {
    let font = CTFontCreateWithName("SFProDisplay-Bold" as CFString, size, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
    ]
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: attributes)
    )
    context.textPosition = point
    CTLineDraw(line, context)
}

private func projected(
    _ point: [Double],
    origin: CGPoint,
    scale: Double
) -> CGPoint {
    CGPoint(
        x: origin.x + (point[0] - point[2]) * scale,
        y: origin.y - (point[0] + point[2]) * scale * 0.5 + point[1] * scale
    )
}

private func path(_ points: [CGPoint]) -> CGPath {
    let mutable = CGMutablePath()
    mutable.move(to: points[0])
    for point in points.dropFirst() {
        mutable.addLine(to: point)
    }
    mutable.closeSubpath()
    return mutable
}

private func drawBox(
    _ item: QualityComponent,
    origin: CGPoint,
    scale: Double,
    roleColors: [String: [Double]],
    mode: String,
    grayscaleMode: Bool,
    context: CGContext
) {
    let x0 = item.positionWorld[0] - item.dimensions[0] / 2
    let x1 = item.positionWorld[0] + item.dimensions[0] / 2
    let y0 = item.positionWorld[1] - item.dimensions[1] / 2
    let y1 = item.positionWorld[1] + item.dimensions[1] / 2
    let z0 = item.positionWorld[2] - item.dimensions[2] / 2
    let z1 = item.positionWorld[2] + item.dimensions[2] / 2
    let top = [
        projected([x0, y1, z0], origin: origin, scale: scale),
        projected([x1, y1, z0], origin: origin, scale: scale),
        projected([x1, y1, z1], origin: origin, scale: scale),
        projected([x0, y1, z1], origin: origin, scale: scale),
    ]
    let xFace = [
        projected([x1, y0, z0], origin: origin, scale: scale),
        projected([x1, y1, z0], origin: origin, scale: scale),
        projected([x1, y1, z1], origin: origin, scale: scale),
        projected([x1, y0, z1], origin: origin, scale: scale),
    ]
    let zFace = [
        projected([x0, y0, z1], origin: origin, scale: scale),
        projected([x0, y1, z1], origin: origin, scale: scale),
        projected([x1, y1, z1], origin: origin, scale: scale),
        projected([x1, y0, z1], origin: origin, scale: scale),
    ]
    let base = grayscaleMode
        ? grayscale(roleColors[item.materialRole] ?? [0.5, 0.5, 0.5, 1])
        : (roleColors[item.materialRole] ?? [0.5, 0.5, 0.5, 1])
    let clayBase = [0.55, 0.56, 0.55, 1.0]
    let use = mode == "clay" ? clayBase : base
    let stroke = mode == "wireframe"
        ? CGColor(red: 0.40, green: 0.92, blue: 0.94, alpha: 0.92)
        : CGColor(red: 0.04, green: 0.05, blue: 0.055, alpha: 0.52)
    for (face, multiplier) in [(top, 1.18), (xFace, 0.92), (zFace, 0.74)] {
        context.addPath(path(face))
        if mode != "wireframe" {
            context.setFillColor(color(use, multiplier: multiplier))
            context.fillPath()
            context.addPath(path(face))
        }
        context.setStrokeColor(stroke)
        context.setLineWidth(mode == "wireframe" ? max(0.8, scale * 0.17) : max(0.45, scale * 0.08))
        context.strokePath()
    }
    if item.primitive == "cylinder" {
        let center = projected(
            [item.positionWorld[0], y1, item.positionWorld[2]],
            origin: origin,
            scale: scale
        )
        let radius = max(1, item.dimensions[0] * scale * 0.72)
        let ellipse = CGRect(
            x: center.x - radius,
            y: center.y - radius * 0.42,
            width: radius * 2,
            height: radius * 0.84
        )
        context.setFillColor(mode == "wireframe" ? CGColor.clear : color(use, multiplier: 1.25))
        context.fillEllipse(in: ellipse)
        context.setStrokeColor(stroke)
        context.strokeEllipse(in: ellipse)
    }
}

private func drawScene(
    _ scene: QualityScene,
    materials: [String: [Double]],
    origin: CGPoint,
    scale: Double,
    mode: String,
    grayscaleMode: Bool,
    context: CGContext
) {
    let shadow = [[-20.0, 0.0, -10.0], [28, 0, 10], [40, 0, 30], [-8, 0, 12]]
        .map { projected($0, origin: origin, scale: scale) }
    context.setFillColor(CGColor(red: 0.035, green: 0.045, blue: 0.05, alpha: 0.48))
    context.addPath(path(shadow))
    context.fillPath()
    let footprint = [[-28.0, 0.0, -28.0], [28, 0, -28], [28, 0, 28], [-28, 0, 28]]
        .map { projected($0, origin: origin, scale: scale) }
    context.setFillColor(CGColor(red: 0.20, green: 0.22, blue: 0.22, alpha: 1))
    context.addPath(path(footprint))
    context.fillPath()
    context.addPath(path(footprint))
    context.setStrokeColor(CGColor(red: 0.48, green: 0.53, blue: 0.53, alpha: 0.8))
    context.setLineWidth(max(1, scale * 0.25))
    context.strokePath()
    let edge = scene.registration.frontageEdgeWorld.map {
        projected([$0[0], 0.8, $0[1]], origin: origin, scale: scale)
    }
    context.setStrokeColor(CGColor(red: 1, green: 0.65, blue: 0.12, alpha: 1))
    context.setLineWidth(max(2, scale * 0.7))
    context.move(to: edge[0])
    context.addLine(to: edge[1])
    context.strokePath()
    let sorted = scene.components.sorted {
        let lhs = $0.positionWorld[0] + $0.positionWorld[2] + $0.positionWorld[1] * 0.015
        let rhs = $1.positionWorld[0] + $1.positionWorld[2] + $1.positionWorld[1] * 0.015
        return lhs < rhs
    }
    for item in sorted {
        drawBox(
            item,
            origin: origin,
            scale: scale,
            roleColors: materials,
            mode: mode,
            grayscaleMode: grayscaleMode,
            context: context
        )
    }
}

private func pngContext(width: Int, height: Int) throws -> (CGContext, UnsafeMutableRawPointer) {
    let pointer = UnsafeMutableRawPointer.allocate(
        byteCount: width * height * 4,
        alignment: MemoryLayout<UInt8>.alignment
    )
    pointer.initializeMemory(as: UInt8.self, repeating: 0, count: width * height * 4)
    guard
        let context = CGContext(
            data: pointer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else {
        pointer.deallocate()
        throw QualityResetError.invalid("could not create RGBA canvas")
    }
    return (context, pointer)
}

private func writePNG(_ context: CGContext, pointer: UnsafeMutableRawPointer, to url: URL) throws {
    defer { pointer.deallocate() }
    guard let image = context.makeImage() else {
        throw QualityResetError.invalid("could not create image")
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw QualityResetError.invalid("could not create PNG destination")
    }
    CGImageDestinationAddImage(
        destination,
        image,
        [kCGImagePropertyPNGInterlaceType: 0] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
        throw QualityResetError.invalid("could not finalize PNG")
    }
}

private func renderSourceSheet(
    scenes: [QualityScene],
    materials: [String: [Double]],
    mode: String,
    grayscaleMode: Bool,
    output: URL
) throws {
    let width = 3072
    let height = 2048
    let (context, pointer) = try pngContext(width: width, height: height)
    context.setFillColor(CGColor(red: 0.055, green: 0.065, blue: 0.075, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let origins = [
        CGPoint(x: 768, y: 1152),
        CGPoint(x: 2304, y: 1152),
        CGPoint(x: 768, y: 128),
        CGPoint(x: 2304, y: 128),
    ]
    for (index, scene) in scenes.enumerated() {
        let cellX = index % 2 * 1536
        let cellY = index < 2 ? 1024 : 0
        context.setStrokeColor(CGColor(red: 0.85, green: 0.22, blue: 0.18, alpha: 1))
        context.setLineWidth(8)
        context.stroke(CGRect(x: cellX + 4, y: cellY + 4, width: 1528, height: 1016))
        drawScene(
            scene,
            materials: materials,
            origin: origins[index],
            scale: 512.0 / 112.0,
            mode: mode,
            grayscaleMode: grayscaleMode,
            context: context
        )
        drawText(
            "NON-AUTHORITY PRE-PIXEL \(mode.uppercased()) — \(scene.viewDirection.uppercased())",
            at: CGPoint(x: cellX + 42, y: cellY + 960),
            size: 30,
            color: CGColor(red: 1, green: 0.82, blue: 0.72, alpha: 1),
            context: context
        )
    }
    try writePNG(context, pointer: pointer, to: output)
}

private func renderNativeSheet(
    scenes: [QualityScene],
    materials: [String: [Double]],
    grayscaleMode: Bool,
    output: URL
) throws {
    let width = 1120
    let height = 340
    let (context, pointer) = try pngContext(width: width, height: height)
    context.setFillColor(CGColor(red: 0.055, green: 0.065, blue: 0.075, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    drawText(
        "NON-AUTHORITY NATIVE-2X MOCKUP — 144 x 72 FOOTPRINT",
        at: CGPoint(x: 28, y: 300),
        size: 24,
        color: CGColor(red: 1, green: 0.82, blue: 0.72, alpha: 1),
        context: context
    )
    for (index, scene) in scenes.enumerated() {
        let origin = CGPoint(x: 140 + index * 280, y: 70)
        drawScene(
            scene,
            materials: materials,
            origin: origin,
            scale: 144.0 / 112.0,
            mode: "material-look",
            grayscaleMode: grayscaleMode,
            context: context
        )
        drawText(
            scene.viewDirection.uppercased(),
            at: CGPoint(x: index * 280 + 104, y: 28),
            size: 18,
            color: CGColor(red: 0.8, green: 0.84, blue: 0.85, alpha: 1),
            context: context
        )
    }
    try writePNG(context, pointer: pointer, to: output)
}

private func loadImage(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw QualityResetError.invalid("cannot decode swatch \(url.path)")
    }
    return image
}

private func renderSwatchSheet(
    evidenceRoot: URL,
    output: URL
) throws {
    let width = 1200
    let height = 760
    let (context, pointer) = try pngContext(width: width, height: height)
    context.setFillColor(CGColor(red: 0.055, green: 0.065, blue: 0.075, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    drawText(
        "PLAY-027 MATERIAL SWATCHES — NON-COMPOSITIONAL PRE-PIXEL REFERENCES",
        at: CGPoint(x: 34, y: 710),
        size: 25,
        color: CGColor(red: 0.94, green: 0.92, blue: 0.86, alpha: 1),
        context: context
    )
    let items: [(String, String, String, Bool)] = [
        ("galvanized-corrugated-steel", "GALVANIZED CORRUGATED", "RETAINED — TILE REJECT", false),
        ("aged-cast-concrete", "AGED CONCRETE", "RETAINED — TILE REJECT", false),
        ("dark-roof-membrane", "DARK ROOF MEMBRANE", "ACCEPTED REFERENCE", true),
        ("blue-gray-painted-steel", "BLUE-GRAY PAINTED STEEL", "ACCEPTED REFERENCE", true),
    ]
    for (index, item) in items.enumerated() {
        let column = index % 2
        let row = index / 2
        let x = 40 + column * 580
        let y = 390 - row * 320
        let imageURL = evidenceRoot
            .appendingPathComponent("material-swatches/normalized/\(item.0).png")
        let image = try loadImage(imageURL)
        let rect = CGRect(x: x, y: y, width: 260, height: 260)
        context.draw(image, in: rect)
        context.setStrokeColor(
            item.3
                ? CGColor(red: 0.28, green: 0.86, blue: 0.52, alpha: 1)
                : CGColor(red: 0.95, green: 0.40, blue: 0.24, alpha: 1)
        )
        context.setLineWidth(6)
        context.stroke(rect)
        drawText(
            item.1,
            at: CGPoint(x: x + 280, y: y + 140),
            size: 14,
            color: CGColor(red: 0.86, green: 0.88, blue: 0.88, alpha: 1),
            context: context
        )
        drawText(
            item.2,
            at: CGPoint(x: x + 280, y: y + 112),
            size: 13,
            color: item.3
                ? CGColor(red: 0.28, green: 0.86, blue: 0.52, alpha: 1)
                : CGColor(red: 0.95, green: 0.40, blue: 0.24, alpha: 1),
            context: context
        )
    }
    try writePNG(context, pointer: pointer, to: output)
}

private func transformSignatures(_ scene: QualityScene) -> Set<String> {
    let transforms: [(Double, Double, Double, Double)] = [
        (1, 0, 0, 1), (0, 1, -1, 0), (-1, 0, 0, -1), (0, -1, 1, 0),
        (-1, 0, 0, 1), (1, 0, 0, -1), (0, 1, 1, 0), (0, -1, -1, 0),
    ]
    return Set(transforms.map { transform in
        scene.components.map { item in
            let x = item.positionWorld[0]
            let z = item.positionWorld[2]
            let tx = transform.0 * x + transform.1 * z
            let tz = transform.2 * x + transform.3 * z
            let swapsAxes = transform.1 != 0 || transform.2 != 0
            let dx = swapsAxes ? item.dimensions[2] : item.dimensions[0]
            let dz = swapsAxes ? item.dimensions[0] : item.dimensions[2]
            return [
                item.category,
                item.primitive,
                String(format: "%.2f", tx),
                String(format: "%.2f", item.positionWorld[1]),
                String(format: "%.2f", tz),
                String(format: "%.2f", dx),
                String(format: "%.2f", item.dimensions[1]),
                String(format: "%.2f", dz),
            ].joined(separator: ":")
        }.sorted().joined(separator: "|")
    })
}

@main
enum BuildIndustrialL2QualityResetPrepixel {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try argument("--repository-root", in: arguments),
            isDirectory: true
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try argument("--output-root", in: arguments),
            isDirectory: true
        ).standardizedFileURL
        try FileManager.default.createDirectory(
            at: outputRoot,
            withIntermediateDirectories: true
        )

        let library = try materialLibrary(
            repositoryRoot: repositoryRoot,
            evidenceRoot: outputRoot
        )
        let materialsURL = outputRoot.appendingPathComponent(
            "materials/industrial-l02-quality-reset-v01-materials.json"
        )
        try FileManager.default.createDirectory(
            at: materialsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let libraryData = try encoded(library)
        try libraryData.write(to: materialsURL, options: .atomic)
        let materialReference = QualityFileReference(
            file: relative(materialsURL, root: repositoryRoot),
            sha256: sha256(libraryData)
        )

        let scenes = [
            scene(direction: "north", components: northComponents(), materials: materialReference),
            scene(direction: "east", components: eastComponents(), materials: materialReference),
            scene(direction: "south", components: southComponents(), materials: materialReference),
            scene(direction: "west", components: westComponents(), materials: materialReference),
        ]
        var descriptorRecords: [[String: Any]] = []
        var descriptorHashes = Set<String>()
        var geometryIDs = Set<String>()
        let materialRoles = Dictionary(
            uniqueKeysWithValues: library.materials.map { ($0.id, $0.baseColorRGBA) }
        )
        for design in scenes {
            let sceneURL = outputRoot.appendingPathComponent(
                "descriptors/\(design.viewDirection)/scene-design.json"
            )
            try FileManager.default.createDirectory(
                at: sceneURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoded(design)
            try data.write(to: sceneURL, options: .atomic)
            let descriptorHash = sha256(data)
            descriptorHashes.insert(descriptorHash)
            geometryIDs.insert(design.sceneGeometryID)
            let geometryData = try encoded(design.components)
            let frontageDoors = design.components.filter {
                $0.category == "loading-door"
                    && $0.frontageDirection == design.viewDirection
            }
            descriptorRecords.append([
                "direction": design.viewDirection,
                "file": relative(sceneURL, root: repositoryRoot),
                "descriptorSHA256": descriptorHash,
                "sceneGeometryID": design.sceneGeometryID,
                "geometrySHA256": sha256(geometryData),
                "componentCount": design.components.count,
                "loadingDoorCount": frontageDoors.count,
                "uniqueComponentIDs": Set(design.components.map(\.id)).count
                    == design.components.count,
                "productionSelected": design.productionSelected,
            ])
        }

        var noSiblingTransform = true
        var pairRecords: [[String: Any]] = []
        for lhsIndex in scenes.indices {
            for rhsIndex in scenes.indices where rhsIndex > lhsIndex {
                let overlap = transformSignatures(scenes[lhsIndex])
                    .intersection(transformSignatures(scenes[rhsIndex]))
                let passed = overlap.isEmpty
                noSiblingTransform = noSiblingTransform && passed
                pairRecords.append([
                    "lhs": scenes[lhsIndex].viewDirection,
                    "rhs": scenes[rhsIndex].viewDirection,
                    "transformEquivalent": !passed,
                    "passed": passed,
                ])
            }
        }

        let reviewRoot = outputRoot.appendingPathComponent("review")
        try renderSourceSheet(
            scenes: scenes,
            materials: materialRoles,
            mode: "clay",
            grayscaleMode: false,
            output: reviewRoot.appendingPathComponent("SOURCE-SCALE-CLAY-NON-AUTHORITY.png")
        )
        try renderSourceSheet(
            scenes: scenes,
            materials: materialRoles,
            mode: "wireframe",
            grayscaleMode: false,
            output: reviewRoot.appendingPathComponent("SOURCE-SCALE-WIREFRAME-NON-AUTHORITY.png")
        )
        try renderSourceSheet(
            scenes: scenes,
            materials: materialRoles,
            mode: "material-look",
            grayscaleMode: false,
            output: reviewRoot.appendingPathComponent("SOURCE-SCALE-MATERIAL-LOOK-NON-AUTHORITY.png")
        )
        try renderNativeSheet(
            scenes: scenes,
            materials: materialRoles,
            grayscaleMode: false,
            output: reviewRoot.appendingPathComponent("NATIVE-2X-COLOR-MOCKUP-NON-AUTHORITY.png")
        )
        try renderNativeSheet(
            scenes: scenes,
            materials: materialRoles,
            grayscaleMode: true,
            output: reviewRoot.appendingPathComponent("NATIVE-2X-GRAYSCALE-MOCKUP-NON-AUTHORITY.png")
        )
        try renderSwatchSheet(
            evidenceRoot: outputRoot,
            output: reviewRoot.appendingPathComponent("MATERIAL-SWATCH-SHEET.png")
        )

        var panelRecords: [[String: Any]] = []
        for name in [
            "SOURCE-SCALE-CLAY-NON-AUTHORITY.png",
            "SOURCE-SCALE-WIREFRAME-NON-AUTHORITY.png",
            "SOURCE-SCALE-MATERIAL-LOOK-NON-AUTHORITY.png",
            "NATIVE-2X-COLOR-MOCKUP-NON-AUTHORITY.png",
            "NATIVE-2X-GRAYSCALE-MOCKUP-NON-AUTHORITY.png",
            "MATERIAL-SWATCH-SHEET.png",
        ] {
            let url = reviewRoot.appendingPathComponent(name)
            let data = try Data(contentsOf: url)
            panelRecords.append([
                "file": relative(url, root: repositoryRoot),
                "sha256": sha256(data),
                "authority": "non-authority-prepixel-diagnostic",
            ])
        }

        let values = library.materials.map {
            $0.baseColorRGBA[0] * 0.2126
                + $0.baseColorRGBA[1] * 0.7152
                + $0.baseColorRGBA[2] * 0.0722
        }
        let validation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l02",
            "sourceRevision": "quality-reset-prepixel-v01",
            "status": "PREPIXEL-REVIEW-CANDIDATE",
            "governedSourcePixelsCreated": false,
            "normalizationPerformed": false,
            "productionSelected": false,
            "descriptorCount": scenes.count,
            "uniqueDescriptorHashes": descriptorHashes.count,
            "uniqueGeometryIDs": geometryIDs.count,
            "descriptorRecords": descriptorRecords,
            "registration": [
                "sourceCanvas": [1536, 1024],
                "footprintPolygonSource": [[768, 640], [1024, 768], [768, 896], [512, 768]],
                "groundPivotSource": [768, 896],
                "tileBasisPoints": [72, 36],
                "cameraProjection": "orthographic-2:1",
                "cameraYawDegrees": 45,
                "cameraElevationDegrees": 30,
                "northwestLightOrigin": [-120, 180, -120],
                "authoredContactShadow": "southeast",
                "orientationTransform": "none",
                "passed": scenes.allSatisfy {
                    $0.registration.groundPivotSource == [768, 896]
                        && $0.registration.footprintPolygonSource
                            == [[768, 640], [1024, 768], [768, 896], [512, 768]]
                        && $0.camera.projection == "orthographic-2:1"
                        && $0.registration.orientationTransform == "none"
                },
            ],
            "frontage": [
                "expectedSockets": [
                    "north": [896, 704],
                    "east": [896, 832],
                    "south": [640, 832],
                    "west": [640, 704],
                ],
                "threeLoadingDoorsPerDirection": descriptorRecords.allSatisfy {
                    $0["loadingDoorCount"] as! Int == 3
                },
                "socketAlignedApronAndCanopyPerDirection": scenes.allSatisfy { design in
                    design.components.contains {
                        $0.category == "service-apron"
                            && $0.frontageDirection == design.viewDirection
                    } && design.components.contains {
                        $0.category == "dock-canopy"
                            && $0.frontageDirection == design.viewDirection
                    }
                },
            ],
            "independentAuthorship": [
                "authoredIndependently": scenes.allSatisfy(\.authoredIndependently),
                "derivationTransforms": scenes.map {
                    [
                        "direction": $0.viewDirection,
                        "mirror": $0.derivation.mirror,
                        "rotationDegrees": $0.derivation.rotationDegrees,
                        "transform": $0.derivation.transform,
                        "siblingSource": $0.derivation.siblingSource as Any,
                    ]
                },
                "pairwiseTransformTests": pairRecords,
                "noSiblingTransformEquivalentGeometry": noSiblingTransform,
            ],
            "materials": [
                "libraryFile": materialReference.file,
                "librarySHA256": materialReference.sha256,
                "roleCount": library.materials.count,
                "minimumRelativeLuminance": values.min()!,
                "maximumRelativeLuminance": values.max()!,
                "relativeLuminanceSpan": values.max()! - values.min()!,
                "acceptedDirectImageGenTileReferences": 2,
                "rejectedImageGenAttemptsRetained": 2,
            ],
            "nativeScale": [
                "native2xFootprintPixels": [144, 72],
                "sourceToNative2xScale": 0.28125,
                "minimumStandaloneDetailWorldUnits": 2,
                "subTwoUnitDetailsRequireNamedCluster": true,
                "mockupsAreAuthority": false,
            ],
            "panels": panelRecords,
            "passed": descriptorHashes.count == 4
                && geometryIDs.count == 4
                && noSiblingTransform
                && descriptorRecords.allSatisfy { $0["loadingDoorCount"] as! Int == 3 }
                && library.productionSelected == false,
        ]
        var validationData = try JSONSerialization.data(
            withJSONObject: validation,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        validationData.append(0x0a)
        try validationData.write(
            to: outputRoot.appendingPathComponent("PREPIXEL-VALIDATION.json"),
            options: .atomic
        )
    }
}
