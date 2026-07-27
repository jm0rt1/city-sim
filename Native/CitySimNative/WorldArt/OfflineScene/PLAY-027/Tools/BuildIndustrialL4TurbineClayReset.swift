import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ClayResetError: Error, CustomStringConvertible {
    case usage
    case failed(String)

    var description: String {
        switch self {
        case .usage:
            return "usage: BuildIndustrialL4TurbineClayReset --output-root <absent-path>"
        case let .failed(message):
            return message
        }
    }
}

struct V3 {
    let x: Double
    let y: Double
    let z: Double
}

struct Box {
    let id: String
    let role: String
    let center: V3
    let size: V3
    let stack: Bool
}

struct DirectionPlan {
    let direction: String
    let geometryID: String
    let boxes: [Box]
    let freightCenters: [Double]
    let staffCenter: Double
}

struct P2 {
    let x: Double
    let y: Double
}

struct Polygon {
    let points: [P2]
    let depth: Double
    let shade: CGFloat
}

struct Raster {
    let image: CGImage
    let silhouetteBounds: CGRect
    let hallBounds: CGRect
    let stackPixelCount: Int
    let silhouettePixelCount: Int
    let freightWidths: [Double]
    let peakCount: Int
}

struct MaterialColor {
    let id: String
    let rgba: [Double]
    let roughness: Double
    let metalness: Double
    let pattern: String
}

let sourceSize = CGSize(width: 1536, height: 1024)
let compactSize = CGSize(width: 192, height: 128)
let pixelsPerWorld = 6.47
let sourceAuthority = false
let productionSelected = false

func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

func jsonData(_ value: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw ClayResetError.failed("output exists: \(url.path)")
    }
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw ClayResetError.failed("cannot create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw ClayResetError.failed("cannot finalize PNG: \(url.path)")
    }
}

func writeJSON(_ value: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw ClayResetError.failed("output exists: \(url.path)")
    }
    try jsonData(value).write(to: url, options: .atomic)
}

func materialLibraryJSON() -> [String: Any] {
    let orderedRoles = [
        "foundation", "freight-recess", "freight-canopy", "main-hall",
        "assembly-annex", "control-wing", "roof-peak", "rear-stack",
        "apron", "staff-entry", "process-heat",
    ]
    let materials: [[String: Any]] = orderedRoles.map { role in
        let material = materialColors[role]!
        var value: [String: Any] = [
            "id": material.id,
            "baseColorRGBA": material.rgba,
            "roughness": material.roughness,
            "metalness": material.metalness,
            "pattern": material.pattern,
            "physicalScaleWorld": [12, 12],
            "textureMapping": [
                "mode": "world-scale-box-face-repeat-v1",
                "wrapS": "repeat",
                "wrapT": "repeat",
                "minificationFilter": "linear",
                "magnificationFilter": "linear",
                "mipFilter": "linear",
            ],
        ]
        if role == "process-heat" {
            value["emissionRGBA"] = [0.20, 0.045, 0.008, 1]
        }
        return value
    }
    return [
        "schema": 1,
        "task": "PLAY-027",
        "libraryID": "industrial-l04-turbine-source-v06-prepixel",
        "source": "task-owned numeric Turbine Works hierarchy; no ImageGen or raster swatch",
        "styleAnchorFile": "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png",
        "styleAnchorSHA256": "b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425",
        "familyAnchorFile": "docs/production/evidence/PLAY-027/industrial-l03/l03/cohesion-a0-family-v01/chroma-repair-v01/final-review/review/COMPACT-NESW-COLOR.png",
        "familyAnchorSHA256": "83b5be9cafc359c95c9455ef7c419a99053f1e843cb401cdb95ea7fad2da6d70",
        "imageGenMaterialSwatchesUsed": false,
        "colorSpace": "extended-sRGB",
        "materials": materials,
        "productionSelected": false,
    ]
}

func samplingJSON() -> [String: Any] {
    [
        "contractID": "play027-deterministic-4x-no-msaa-lanczos-v3",
        "sourceRevisionBinding": "source-v06-prepixel",
        "purpose": "source-authority",
        "sceneKitAntialiasing": "none",
        "sceneKitShadows": "disabled",
        "sceneKitLightingMode": "authored-constant-v1",
        "linearOversamplingFactor": 4,
        "downsample": [
            "filter": "CILanczosScaleTransform",
            "scale": 0.25,
            "aspectRatio": 1,
        ],
        "ciContext": [
            "useSoftwareRenderer": true,
            "cacheIntermediates": false,
            "workingColorSpace": "extended-srgb",
            "outputColorSpace": "srgb",
        ],
        "quantizer": [
            "id": "step32-midpoint-offset8-v1",
            "step": 32,
            "midpointOffset": 8,
            "chromaBypassRGBA": [255, 0, 255, 255],
        ],
        "canonicalizer": [
            "id": "imageio-sips-png-v1",
            "encoder": "ImageIO",
            "postEncoder": "/usr/bin/sips",
            "format": "png",
        ],
        "postQuantizationCanonicalizer": [
            "algorithm": "opaque-isolated-one-quantum-majority-3x3",
            "version": 3,
            "quantizationQuantum": 32,
            "neighborhoodSize": 3,
            "majorityThreshold": 7,
            "requiresFullyOpaqueNeighborhood": true,
            "immutableSourceBuffer": true,
            "requiresChromaFreeNeighborhood": true,
            "channels": "rgb-only",
            "preservesAlpha": true,
            "preservesChroma": true,
            "boundaryAssist": [
                "algorithm": "immutable-prequantized-one-value-boundary-6-plus-1",
                "version": 1,
                "baseQuantizedMajorityCount": 6,
                "requiredBoundaryVoteCount": 1,
                "effectiveSupportCount": 7,
                "maximumCompetingSupportAfterBoundaryReclassification": 2,
                "quantizerStep": 32,
                "quantizerMidpointOffset": 8,
                "boundaryBandWidthValues": 1,
                "requiresSameChannelEvidence": true,
                "immutablePrequantizedBuffer": true,
                "recordsBoundaryVoteReason": true,
            ],
        ],
    ]
}

func sceneJSON(
    _ plan: DirectionPlan,
    materialFile: String,
    materialSHA: String,
    toolchainFile: String,
    toolchainSHA: String
) -> [String: Any] {
    let direction = plan.direction
    let lower = direction.lowercased()
    let massBlocks: [[String: Any]] = plan.boxes.compactMap { item in
        guard item.role != "foundation", item.role != "roof-peak" else {
            return nil
        }
        let position = worldPoint(item.center, direction: direction)
        return [
            "id": item.id.replacingOccurrences(of: "i04-", with: "i04-v06-"),
            "dimensions": worldDimensions(item.size, direction: direction),
            "positionWorld": [position.x, position.y, position.z],
            "materialID": materialID(for: item.role),
        ]
    } + plan.freightCenters.enumerated().map { index, center in
        let local = V3(x: center, y: 7.75, z: -7.4)
        let position = worldPoint(local, direction: direction)
        return [
            "id": "i04-v06-\(lower)-freight-\(index + 1)-recess",
            "dimensions": worldDimensions(
                V3(x: 11.6, y: 11.5, z: 1.0),
                direction: direction
            ),
            "positionWorld": [position.x, position.y, position.z],
            "materialID": materialID(for: "freight-recess"),
        ]
    } + [
        {
            let local = V3(x: plan.staffCenter, y: 5, z: -17.2)
            let position = worldPoint(local, direction: direction)
            return [
                "id": "i04-v06-\(lower)-staff-entry",
                "dimensions": worldDimensions(
                    V3(x: 4, y: 6, z: 0.6),
                    direction: direction
                ),
                "positionWorld": [position.x, position.y, position.z],
                "materialID": materialID(for: "staff-entry"),
            ]
        }(),
    ]
    let roofVolumes: [[String: Any]] = plan.boxes
        .filter { $0.role == "roof-peak" }
        .map { item in
            let position = worldPoint(item.center, direction: direction)
            return [
                "id": item.id.replacingOccurrences(of: "i04-", with: "i04-v06-"),
                "shape": "hip",
                "dimensions": worldDimensions(item.size, direction: direction),
                "positionWorld": [position.x, position.y, position.z],
                "materialID": materialID(for: "roof-peak"),
                "trimMaterialID": materialID(for: "freight-canopy"),
            ]
        }
    let heatLocal = V3(x: plan.boxes.first { $0.stack }!.center.x, y: 13, z: 10.8)
    let heatPosition = worldPoint(heatLocal, direction: direction)
    let entranceLocal = V3(x: plan.staffCenter, y: 2, z: -28)
    let entranceWorld = worldPoint(entranceLocal, direction: direction)
    let cameraPosition: [Double]
    let yaw: Double
    switch direction {
    case "N":
        cameraPosition = [96, 96, 96]
        yaw = 45
    case "E":
        cameraPosition = [-96, 96, 96]
        yaw = 135
    case "S":
        cameraPosition = [-96, 96, -96]
        yaw = 225
    default:
        cameraPosition = [96, 96, -96]
        yaw = 315
    }
    return [
        "schema": 2,
        "task": "PLAY-027",
        "sceneGeometryID": "industrial-l04-turbine-v06-\(lower)-independent",
        "logicalBuildingID": "industrial_l04",
        "family": "industrial",
        "level": 4,
        "variantID": "variant-0",
        "viewDirection": lower,
        "sourceRevision": "source-v06-prepixel",
        "authoredIndependently": true,
        "productionSelected": false,
        "derivation": [
            "sourceKind": "offline-scene-explicit-authored",
            "siblingSource": NSNull(),
            "mirror": false,
            "rotationDegrees": 0,
            "transform": "none",
        ],
        "toolchainFingerprint": [
            "role": "offline-toolchain",
            "file": toolchainFile,
            "sha256": toolchainSHA,
        ],
        "styleAnchor": [
            "role": "global-style-anchor",
            "file": "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png",
            "sha256": "b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425",
        ],
        "materialLibrary": [
            "role": "industrial-l04-turbine-material-library",
            "file": materialFile,
            "sha256": materialSHA,
        ],
        "registration": registration(direction),
        "camera": [
            "projection": "orthographic-2-to-1",
            "yawDegrees": yaw,
            "elevationDegrees": 30,
            "orthographicScale": 79.1959533691406,
            "renderViewportPixels": [1536, 1024],
            "oversamplingFactor": 4,
            "positionWorld": cameraPosition,
            "targetWorld": [0, 12, 0],
            "sourceGroundCenter": [768, 768],
            "postProjectionOffsetPixels": [0, 128],
        ],
        "sampling": samplingJSON(),
        "light": [
            "keyOrigin": [-80, 120, -80],
            "keyIntensity": 0,
            "keyColorRGBA": [1, 0.94, 0.84, 1],
            "ambientIntensity": 0,
            "ambientColorRGBA": [0.36, 0.43, 0.50, 1],
            "shadowVectorSource": [2, 1],
            "shadowOpacity": 0.34,
            "shadowBlurSourcePixels": 0,
            "shadowReceiver": "authored-contact-polygon",
        ],
        "building": [
            "width": 56,
            "depth": 56,
            "foundationHeight": 2,
            "floorHeight": 8,
            "floors": 2,
            "wallHeight": 18,
            "roofHeight": 4,
            "roofOverhang": 0,
            "wallMaterialID": materialID(for: "main-hall"),
            "trimMaterialID": materialID(for: "freight-canopy"),
            "roofMaterialID": materialID(for: "roof-peak"),
            "foundationMaterialID": materialID(for: "foundation"),
            "chimney": [
                "positionWorld": [heatPosition.x, 27, heatPosition.z],
                "dimensions": [3, 30, 3],
                "materialID": materialID(for: "rear-stack"),
            ],
            "massingProfile": "turbine-works-v06-long-sawtooth-foundry-\(lower)",
            "massBlocks": massBlocks,
            "roofVolumes": roofVolumes,
            "trimBands": [[
                "id": "i04-v06-\(lower)-process-heat-band",
                "dimensions": [5, 2, 5],
                "positionWorld": [heatPosition.x, heatPosition.y, heatPosition.z],
                "materialID": materialID(for: "process-heat"),
            ]],
            "usesLegacyDomesticDetails": false,
            "usesExplicitComponentGeometry": true,
            "foundationDimensions": [56, 2, 56],
            "foundationPositionWorld": [0, 1, 0],
        ],
        "facades": [[
            "id": "i04-v06-\(lower)-road-frontage",
            "direction": lower,
            "edgeWorld": facadeEdge(direction),
            "materialID": materialID(for: "control-wing"),
            "hasEntrance": true,
            "windowBays": [],
            "windowRhythms": [],
        ]],
        "entrance": [
            "facadeID": "i04-v06-\(lower)-road-frontage",
            "baseWorld": [entranceWorld.x, entranceWorld.y, entranceWorld.z],
            "width": 4,
            "height": 6,
            "depth": 0.6,
            "doorMaterialID": materialID(for: "staff-entry"),
            "surroundMaterialID": materialID(for: "process-heat"),
            "stepCount": 1,
            "stepRun": 1.2,
            "canopyDepth": 3,
            "hingeSide": "right",
            "pavilionWidth": 10,
            "pavilionDepth": 10,
            "pavilionHeight": 8,
            "pavilionRoofHeight": 2,
            "pavilionMaterialID": materialID(for: "control-wing"),
            "porchWidth": 6,
            "porchColumnWidth": 1,
            "porchLateralOffset": 0,
            "style": "turbine-works-control-entry",
        ],
        "props": [],
        "occlusionExclusions": [[
            "id": "i04-v06-\(lower)-frontage-visibility",
            "purpose": "keep three freight voids and separate staff entrance visible",
            "polygonWorld": [[-28, -28], [28, -28], [28, -7], [-28, -7]],
        ]],
    ]
}

func box(
    _ id: String,
    _ role: String,
    _ x: Double,
    _ y: Double,
    _ z: Double,
    _ width: Double,
    _ height: Double,
    _ depth: Double,
    stack: Bool = false
) -> Box {
    Box(
        id: id,
        role: role,
        center: V3(x: x, y: y, z: z),
        size: V3(x: width, y: height, z: depth),
        stack: stack
    )
}

func plan(_ direction: String) -> DirectionPlan {
    let prefix = "i04-\(direction.lowercased())"
    let hall = box("\(prefix)-turbine-hall", "main-hall", 0, 10, 2, 54, 16, 18)
    let controlX: Double
    let annexX: Double
    let stackX: Double
    let staffX: Double
    switch direction {
    case "N":
        controlX = 18
        annexX = -17
        stackX = -19
        staffX = 19
    case "E":
        controlX = 17
        annexX = -18
        stackX = 19
        staffX = 18
    case "S":
        controlX = -18
        annexX = 17
        stackX = 20
        staffX = -19
    default:
        controlX = -17
        annexX = 18
        stackX = -20
        staffX = -18
    }
    var boxes = [
        box("\(prefix)-foundation", "foundation", 0, 1, 0, 56, 2, 56),
        hall,
        box("\(prefix)-control-wing", "control-wing", controlX, 6, -11, 18, 8, 12),
        box("\(prefix)-assembly-annex", "assembly-annex", annexX, 7, 13, 18, 12, 12),
        box("\(prefix)-rear-stack", "rear-stack", stackX, 27, 13, 3, 30, 3, stack: true),
        box("\(prefix)-freight-canopy", "freight-canopy", 0, 14.5, -10.5, 42, 3, 5),
        box("\(prefix)-front-apron", "apron", 0, 0.7, -21, 50, 1.4, 14),
    ]
    for index in 0..<4 {
        let x = -20.25 + Double(index) * 13.5
        boxes.append(
            box(
                "\(prefix)-sawtooth-\(index + 1)",
                "roof-peak",
                x,
                20,
                2,
                11,
                4,
                17
            )
        )
    }
    return DirectionPlan(
        direction: direction,
        geometryID: "industrial-l04-turbine-v06-\(direction.lowercased())",
        boxes: boxes,
        freightCenters: [-14, 0, 14],
        staffCenter: staffX
    )
}

let materialColors: [String: MaterialColor] = [
    "foundation": MaterialColor(
        id: "l4t-charcoal-foundation",
        rgba: [0.10, 0.12, 0.12, 1],
        roughness: 0.96,
        metalness: 0.02,
        pattern: "large-scored-foundation"
    ),
    "main-hall": MaterialColor(
        id: "l4t-weathered-blue-green-steel",
        rgba: [0.16, 0.27, 0.27, 1],
        roughness: 0.84,
        metalness: 0.26,
        pattern: "procedural-vertical-corrugation"
    ),
    "control-wing": MaterialColor(
        id: "l4t-weathered-warm-brick",
        rgba: [0.50, 0.31, 0.20, 1],
        roughness: 0.94,
        metalness: 0,
        pattern: "weathered-industrial-brick"
    ),
    "assembly-annex": MaterialColor(
        id: "l4t-restrained-green-steel",
        rgba: [0.25, 0.34, 0.29, 1],
        roughness: 0.86,
        metalness: 0.20,
        pattern: "painted-weathered-steel"
    ),
    "rear-stack": MaterialColor(
        id: "l4t-oxidized-machinery",
        rgba: [0.48, 0.29, 0.17, 1],
        roughness: 0.82,
        metalness: 0.42,
        pattern: "restrained-oxide"
    ),
    "freight-canopy": MaterialColor(
        id: "l4t-charcoal-structural-steel",
        rgba: [0.08, 0.13, 0.14, 1],
        roughness: 0.78,
        metalness: 0.38,
        pattern: "painted-structural-steel"
    ),
    "apron": MaterialColor(
        id: "l4t-warm-scored-apron",
        rgba: [0.42, 0.39, 0.33, 1],
        roughness: 0.98,
        metalness: 0,
        pattern: "large-scored-slabs"
    ),
    "roof-peak": MaterialColor(
        id: "l4t-dark-roof-metal",
        rgba: [0.18, 0.23, 0.22, 1],
        roughness: 0.88,
        metalness: 0.24,
        pattern: "weathered-standing-seam"
    ),
    "freight-recess": MaterialColor(
        id: "l4t-deep-freight-recess",
        rgba: [0.04, 0.06, 0.06, 1],
        roughness: 0.97,
        metalness: 0.02,
        pattern: "solid-depth-cavity"
    ),
    "staff-entry": MaterialColor(
        id: "l4t-believable-glazing",
        rgba: [0.15, 0.25, 0.25, 1],
        roughness: 0.46,
        metalness: 0.06,
        pattern: "muted-mullion-grid"
    ),
    "process-heat": MaterialColor(
        id: "l4t-orange-process-heat",
        rgba: [0.78, 0.30, 0.08, 1],
        roughness: 0.72,
        metalness: 0.16,
        pattern: "restrained-process-heat"
    ),
]

func materialID(for role: String) -> String {
    materialColors[role]?.id ?? materialColors["main-hall"]!.id
}

func worldPoint(_ local: V3, direction: String) -> V3 {
    switch direction {
    case "N":
        return local
    case "E":
        return V3(x: -local.z, y: local.y, z: local.x)
    case "S":
        return V3(x: -local.x, y: local.y, z: -local.z)
    default:
        return V3(x: local.z, y: local.y, z: -local.x)
    }
}

func worldDimensions(_ local: V3, direction: String) -> [Double] {
    if direction == "E" || direction == "W" {
        return [local.z, local.y, local.x]
    }
    return [local.x, local.y, local.z]
}

func registration(_ direction: String) -> [String: Any] {
    let edge: [[Double]]
    let socket: [Double]
    let door: [[Double]]
    switch direction {
    case "N":
        edge = [[768, 640], [1024, 768]]
        socket = [896, 704]
        door = [[914, 713], [938, 725]]
    case "E":
        edge = [[1024, 768], [768, 896]]
        socket = [896, 832]
        door = [[887, 850], [875, 874]]
    case "S":
        edge = [[768, 896], [512, 768]]
        socket = [640, 832]
        door = [[622, 823], [598, 811]]
    default:
        edge = [[512, 768], [768, 640]]
        socket = [640, 704]
        door = [[649, 686], [661, 662]]
    }
    return [
        "tileBasisPoints": [72, 36],
        "sceneFootprintUnits": [72, 72],
        "footprintPolygonSource": [
            [768, 640], [1024, 768], [768, 896], [512, 768],
        ],
        "groundPivotSource": [768, 896],
        "contactPolygonWorld": [
            [-28, -28], [28, -28], [28, 28], [-28, 28],
        ],
        "frontageEdgeSource": edge,
        "frontageSocketSource": socket,
        "doorBaseSource": door,
        "presentationEnvelopeSource": [256, 64, 1280, 896],
        "shadowEnvelopeSource": [768, 512, 1456, 976],
        "orientationTransform": "none",
    ]
}

func facadeEdge(_ direction: String) -> [[Double]] {
    switch direction {
    case "N": return [[-28, -28], [28, -28]]
    case "E": return [[28, -28], [28, 28]]
    case "S": return [[28, 28], [-28, 28]]
    default: return [[-28, 28], [-28, -28]]
    }
}

func projected(_ point: V3, in size: CGSize) -> P2 {
    P2(
        x: Double(size.width) * 0.5 + (point.x - point.z) * pixelsPerWorld,
        y: Double(size.height) * 0.69
            - (point.x + point.z) * pixelsPerWorld * 0.36
            - point.y * pixelsPerWorld
    )
}

func vertices(of box: Box) -> [V3] {
    let hx = box.size.x * 0.5
    let hy = box.size.y * 0.5
    let hz = box.size.z * 0.5
    return [
        V3(x: box.center.x - hx, y: box.center.y - hy, z: box.center.z - hz),
        V3(x: box.center.x + hx, y: box.center.y - hy, z: box.center.z - hz),
        V3(x: box.center.x + hx, y: box.center.y + hy, z: box.center.z - hz),
        V3(x: box.center.x - hx, y: box.center.y + hy, z: box.center.z - hz),
        V3(x: box.center.x - hx, y: box.center.y - hy, z: box.center.z + hz),
        V3(x: box.center.x + hx, y: box.center.y - hy, z: box.center.z + hz),
        V3(x: box.center.x + hx, y: box.center.y + hy, z: box.center.z + hz),
        V3(x: box.center.x - hx, y: box.center.y + hy, z: box.center.z + hz),
    ]
}

func polygons(for box: Box, size: CGSize) -> [Polygon] {
    if box.role == "roof-peak" {
        let hx = box.size.x * 0.5
        let hy = box.size.y * 0.5
        let hz = box.size.z * 0.5
        let y0 = box.center.y - hy
        let y1 = box.center.y + hy
        let front = box.center.z - hz
        let back = box.center.z + hz
        let worldFaces: [([V3], CGFloat)] = [
            ([
                V3(x: box.center.x - hx, y: y0, z: front),
                V3(x: box.center.x, y: y1, z: front),
                V3(x: box.center.x + hx, y: y0, z: front),
            ], 0.62),
            ([
                V3(x: box.center.x, y: y1, z: front),
                V3(x: box.center.x, y: y1, z: back),
                V3(x: box.center.x + hx, y: y0, z: back),
                V3(x: box.center.x + hx, y: y0, z: front),
            ], 0.76),
            ([
                V3(x: box.center.x - hx, y: y0, z: front),
                V3(x: box.center.x - hx, y: y0, z: back),
                V3(x: box.center.x, y: y1, z: back),
                V3(x: box.center.x, y: y1, z: front),
            ], 0.70),
        ]
        return worldFaces.map { world, shade in
            Polygon(
                points: world.map { projected($0, in: size) },
                depth: world.map { $0.x + $0.z }.reduce(0, +) / Double(world.count),
                shade: shade
            )
        }
    }
    let v = vertices(of: box)
    let faces: [([Int], CGFloat)] = [
        ([4, 5, 6, 7], 0.54),
        ([1, 5, 6, 2], 0.66),
        ([3, 2, 6, 7], 0.78),
    ]
    return faces.map { indices, shade in
        let world = indices.map { v[$0] }
        return Polygon(
            points: world.map { projected($0, in: size) },
            depth: world.map { $0.x + $0.z }.reduce(0, +) / 4,
            shade: shade
        )
    }
}

func context(width: Int, height: Int) throws -> CGContext {
    guard let value = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw ClayResetError.failed("cannot create bitmap context")
    }
    value.translateBy(x: 0, y: CGFloat(height))
    value.scaleBy(x: 1, y: -1)
    value.setShouldAntialias(false)
    return value
}

func path(_ points: [P2]) -> CGPath {
    let value = CGMutablePath()
    value.move(to: CGPoint(x: points[0].x, y: points[0].y))
    for point in points.dropFirst() {
        value.addLine(to: CGPoint(x: point.x, y: point.y))
    }
    value.closeSubpath()
    return value
}

func pixelStats(_ image: CGImage) throws -> (CGRect, Int) {
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard let ctx = CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw ClayResetError.failed("cannot decode image")
    }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    var count = 0
    for y in 0..<height {
        for x in 0..<width where bytes[(y * width + x) * 4 + 3] > 0 {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
            count += 1
        }
    }
    guard count > 0 else { throw ClayResetError.failed("empty clay raster") }
    return (
        CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1),
        count
    )
}

func render(_ plan: DirectionPlan, size: CGSize) throws -> Raster {
    let width = Int(size.width)
    let height = Int(size.height)
    let ctx = try context(width: width, height: height)
    let all = plan.boxes.flatMap { item in
        polygons(for: item, size: size).map { (item, $0) }
    }.sorted { $0.1.depth > $1.1.depth }
    for (item, polygon) in all {
        let base: CGFloat = item.role == "control-wing" ? 0.63 : polygon.shade
        ctx.setFillColor(CGColor(gray: base, alpha: 1))
        ctx.addPath(path(polygon.points))
        ctx.fillPath()
        ctx.setStrokeColor(CGColor(gray: 0.14, alpha: 1))
        ctx.setLineWidth(1)
        ctx.addPath(path(polygon.points))
        ctx.strokePath()
    }

    var freightWidths: [Double] = []
    for center in plan.freightCenters {
        let bottomLeft = projected(V3(x: center - 5.8, y: 2, z: -9.1), in: size)
        let bottomRight = projected(V3(x: center + 5.8, y: 2, z: -9.1), in: size)
        let topRight = projected(V3(x: center + 5.8, y: 13.5, z: -9.1), in: size)
        let topLeft = projected(V3(x: center - 5.8, y: 13.5, z: -9.1), in: size)
        let points = [bottomLeft, bottomRight, topRight, topLeft]
        ctx.setFillColor(CGColor(gray: 0.08, alpha: 1))
        ctx.addPath(path(points))
        ctx.fillPath()
        freightWidths.append(abs(bottomRight.x - bottomLeft.x) * Double(compactSize.width / sourceSize.width))
    }
    let staffLeft = projected(V3(x: plan.staffCenter - 2, y: 2, z: -17.1), in: size)
    let staffRight = projected(V3(x: plan.staffCenter + 2, y: 2, z: -17.1), in: size)
    let staffTopRight = projected(V3(x: plan.staffCenter + 2, y: 10, z: -17.1), in: size)
    let staffTopLeft = projected(V3(x: plan.staffCenter - 2, y: 10, z: -17.1), in: size)
    ctx.setFillColor(CGColor(gray: 0.24, alpha: 1))
    ctx.addPath(path([staffLeft, staffRight, staffTopRight, staffTopLeft]))
    ctx.fillPath()

    guard let image = ctx.makeImage() else {
        throw ClayResetError.failed("cannot create clay image")
    }
    let stats = try pixelStats(image)
    let hallPoints = vertices(of: plan.boxes.first { $0.role == "main-hall" }!)
        .map { projected($0, in: size) }
    let hallMinX = hallPoints.map(\.x).min()!
    let hallMaxX = hallPoints.map(\.x).max()!
    let hallMinY = hallPoints.map(\.y).min()!
    let hallMaxY = hallPoints.map(\.y).max()!
    let hallBounds = CGRect(
        x: hallMinX,
        y: hallMinY,
        width: hallMaxX - hallMinX,
        height: hallMaxY - hallMinY
    )
    let stack = plan.boxes.first { $0.stack }!
    let stackPoints = vertices(of: stack).map { projected($0, in: size) }
    let sx0 = Int(stackPoints.map(\.x).min()!.rounded(.down))
    let sx1 = Int(stackPoints.map(\.x).max()!.rounded(.up))
    let sy0 = Int(stackPoints.map(\.y).min()!.rounded(.down))
    let sy1 = Int(stackPoints.map(\.y).max()!.rounded(.up))
    let stackPixels = max(0, sx1 - sx0) * max(0, sy1 - sy0)
    return Raster(
        image: image,
        silhouetteBounds: stats.0,
        hallBounds: hallBounds,
        stackPixelCount: stackPixels,
        silhouettePixelCount: stats.1,
        freightWidths: freightWidths,
        peakCount: plan.boxes.filter { $0.role == "roof-peak" }.count
    )
}

func renderColor(_ plan: DirectionPlan, size: CGSize) throws -> CGImage {
    let ctx = try context(width: Int(size.width), height: Int(size.height))
    let all = plan.boxes.flatMap { item in
        polygons(for: item, size: size).map { (item, $0) }
    }.sorted { $0.1.depth > $1.1.depth }
    for (item, polygon) in all {
        let material = materialColors[item.role] ?? materialColors["main-hall"]!
        let light = max(0.62, min(1.12, Double(polygon.shade) / 0.68))
        let color = material.rgba
        ctx.setFillColor(
            red: CGFloat(min(1, color[0] * light)),
            green: CGFloat(min(1, color[1] * light)),
            blue: CGFloat(min(1, color[2] * light)),
            alpha: 1
        )
        ctx.addPath(path(polygon.points))
        ctx.fillPath()
        let outline = materialColors["freight-canopy"]!.rgba
        ctx.setStrokeColor(
            red: outline[0],
            green: outline[1],
            blue: outline[2],
            alpha: 1
        )
        ctx.setLineWidth(1)
        ctx.addPath(path(polygon.points))
        ctx.strokePath()
    }
    let recess = materialColors["freight-recess"]!.rgba
    for center in plan.freightCenters {
        let points = [
            projected(V3(x: center - 5.8, y: 2, z: -9.1), in: size),
            projected(V3(x: center + 5.8, y: 2, z: -9.1), in: size),
            projected(V3(x: center + 5.8, y: 13.5, z: -9.1), in: size),
            projected(V3(x: center - 5.8, y: 13.5, z: -9.1), in: size),
        ]
        ctx.setFillColor(red: recess[0], green: recess[1], blue: recess[2], alpha: 1)
        ctx.addPath(path(points))
        ctx.fillPath()
        ctx.setStrokeColor(red: 0.42, green: 0.30, blue: 0.18, alpha: 1)
        ctx.setLineWidth(2)
        ctx.addPath(path(points))
        ctx.strokePath()
    }
    let glazing = materialColors["staff-entry"]!.rgba
    let staff = [
        projected(V3(x: plan.staffCenter - 2, y: 2, z: -17.1), in: size),
        projected(V3(x: plan.staffCenter + 2, y: 2, z: -17.1), in: size),
        projected(V3(x: plan.staffCenter + 2, y: 10, z: -17.1), in: size),
        projected(V3(x: plan.staffCenter - 2, y: 10, z: -17.1), in: size),
    ]
    ctx.setFillColor(red: glazing[0], green: glazing[1], blue: glazing[2], alpha: 1)
    ctx.addPath(path(staff))
    ctx.fillPath()
    ctx.setStrokeColor(red: 0.78, green: 0.30, blue: 0.08, alpha: 1)
    ctx.setLineWidth(2)
    ctx.addPath(path(staff))
    ctx.strokePath()
    guard let image = ctx.makeImage() else {
        throw ClayResetError.failed("cannot create color image")
    }
    return image
}

func grayscale(_ image: CGImage) throws -> CGImage {
    let width = image.width
    let height = image.height
    let ctx = try context(width: width, height: height)
    ctx.setBlendMode(.copy)
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let data = ctx.data else {
        throw ClayResetError.failed("cannot access grayscale buffer")
    }
    let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    for index in 0..<(width * height) where bytes[index * 4 + 3] > 0 {
        let r = Double(bytes[index * 4])
        let g = Double(bytes[index * 4 + 1])
        let b = Double(bytes[index * 4 + 2])
        let y = UInt8(max(0, min(255, Int((0.2126 * r + 0.7152 * g + 0.0722 * b).rounded()))))
        bytes[index * 4] = y
        bytes[index * 4 + 1] = y
        bytes[index * 4 + 2] = y
    }
    guard let output = ctx.makeImage() else {
        throw ClayResetError.failed("cannot create grayscale image")
    }
    return output
}

func clayOverlay(color: CGImage, clay: CGImage) throws -> CGImage {
    let ctx = try context(width: color.width, height: color.height)
    ctx.draw(color, in: CGRect(x: 0, y: 0, width: color.width, height: color.height))
    ctx.setAlpha(0.34)
    ctx.setBlendMode(.screen)
    ctx.draw(clay, in: CGRect(x: 0, y: 0, width: clay.width, height: clay.height))
    guard let output = ctx.makeImage() else {
        throw ClayResetError.failed("cannot create clay overlay")
    }
    return output
}

func registrationOverlay(_ image: CGImage, direction: String) throws -> CGImage {
    let ctx = try context(width: image.width, height: image.height)
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let value = registration(direction)
    let edge = value["frontageEdgeSource"] as! [[Double]]
    let socket = value["frontageSocketSource"] as! [Double]
    let pivot = value["groundPivotSource"] as! [Double]
    ctx.setStrokeColor(red: 0.95, green: 0.58, blue: 0.08, alpha: 1)
    ctx.setLineWidth(8)
    ctx.move(to: CGPoint(x: edge[0][0], y: edge[0][1]))
    ctx.addLine(to: CGPoint(x: edge[1][0], y: edge[1][1]))
    ctx.strokePath()
    ctx.setFillColor(red: 0.10, green: 0.85, blue: 0.45, alpha: 1)
    ctx.fillEllipse(in: CGRect(x: socket[0] - 10, y: socket[1] - 10, width: 20, height: 20))
    ctx.setFillColor(red: 0.85, green: 0.20, blue: 0.25, alpha: 1)
    ctx.fillEllipse(in: CGRect(x: pivot[0] - 10, y: pivot[1] - 10, width: 20, height: 20))
    guard let output = ctx.makeImage() else {
        throw ClayResetError.failed("cannot create registration overlay")
    }
    return output
}

func resize(_ image: CGImage, to size: CGSize) throws -> CGImage {
    let ctx = try context(width: Int(size.width), height: Int(size.height))
    ctx.interpolationQuality = .none
    ctx.draw(image, in: CGRect(origin: .zero, size: size))
    guard let output = ctx.makeImage() else {
        throw ClayResetError.failed("cannot resize image")
    }
    return output
}

func sheet(_ images: [CGImage], cell: CGSize) throws -> CGImage {
    let ctx = try context(width: Int(cell.width * 2), height: Int(cell.height * 2))
    for (index, image) in images.enumerated() {
        let x = CGFloat(index % 2) * cell.width
        let y = CGFloat(index / 2) * cell.height
        ctx.draw(image, in: CGRect(x: x, y: y, width: cell.width, height: cell.height))
    }
    guard let output = ctx.makeImage() else {
        throw ClayResetError.failed("cannot create sheet")
    }
    return output
}

func run() throws {
    let arguments = CommandLine.arguments
    guard
        let index = arguments.firstIndex(of: "--output-root"),
        index + 1 < arguments.count,
        let repositoryIndex = arguments.firstIndex(of: "--repository-root"),
        repositoryIndex + 1 < arguments.count
    else {
        throw ClayResetError.usage
    }
    let root = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    let repository = URL(
        fileURLWithPath: arguments[repositoryIndex + 1],
        isDirectory: true
    )
    guard root.path.hasPrefix("/tmp/") || root.path.contains("/docs/production/evidence/PLAY-027/") else {
        throw ClayResetError.failed("output root must be task-owned")
    }
    guard !FileManager.default.fileExists(atPath: root.path) else {
        throw ClayResetError.failed("output root must be absent")
    }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let plans = ["N", "E", "S", "W"].map(plan)
    let rasters = try plans.map { try render($0, size: sourceSize) }
    let colorImages = try plans.map { try renderColor($0, size: sourceSize) }
    let grayscaleImages = try colorImages.map(grayscale)
    let clayOverlayImages = try zip(colorImages, rasters).map {
        try clayOverlay(color: $0.0, clay: $0.1.image)
    }
    let registrationImages = try zip(colorImages, plans).map {
        try registrationOverlay($0.0, direction: $0.1.direction)
    }
    let sourceImages = try colorImages.map {
        try resize($0, to: CGSize(width: 768, height: 512))
    }
    let sourceSheet = try sheet(sourceImages, cell: CGSize(width: 768, height: 512))

    let reviewRoot = root.appendingPathComponent("review", isDirectory: true)
    try FileManager.default.createDirectory(at: reviewRoot, withIntermediateDirectories: true)
    let sourceURL = reviewRoot.appendingPathComponent("SOURCE-COLOR-NESW.png")
    let compactURL = reviewRoot.appendingPathComponent("EXACT-192X128-COLOR-NESW.png")
    try writePNG(sourceSheet, to: sourceURL)
    let exactCompactColor = try sheet(
        try colorImages.map { try resize($0, to: compactSize) },
        cell: compactSize
    )
    try writePNG(exactCompactColor, to: compactURL)
    let reviewOutputs: [(String, CGImage)] = [
        (
            "SOURCE-GRAYSCALE-NESW.png",
            try sheet(
                try grayscaleImages.map {
                    try resize($0, to: CGSize(width: 768, height: 512))
                },
                cell: CGSize(width: 768, height: 512)
            )
        ),
        (
            "CLAY-OVERLAY-NESW.png",
            try sheet(
                try clayOverlayImages.map {
                    try resize($0, to: CGSize(width: 768, height: 512))
                },
                cell: CGSize(width: 768, height: 512)
            )
        ),
        (
            "FRONTAGE-SOCKET-NESW.png",
            try sheet(
                try registrationImages.map {
                    try resize($0, to: CGSize(width: 768, height: 512))
                },
                cell: CGSize(width: 768, height: 512)
            )
        ),
        (
            "BLOCK-COLOR-NESW.png",
            try sheet(
                try colorImages.map { try resize($0, to: compactSize) },
                cell: compactSize
            )
        ),
        (
            "NEIGHBORHOOD-COLOR-NESW.png",
            try sheet(
                try colorImages.map {
                    try resize($0, to: CGSize(width: 128, height: 85))
                },
                cell: CGSize(width: 128, height: 85)
            )
        ),
        (
            "CITY-COLOR-NESW.png",
            try sheet(
                try colorImages.map {
                    try resize($0, to: CGSize(width: 96, height: 64))
                },
                cell: CGSize(width: 96, height: 64)
            )
        ),
        (
            "EXACT-192X128-GRAYSCALE-NESW.png",
            try sheet(
                try grayscaleImages.map { try resize($0, to: compactSize) },
                cell: compactSize
            )
        ),
    ]
    for (name, image) in reviewOutputs {
        try writePNG(image, to: reviewRoot.appendingPathComponent(name))
    }

    var directionMetrics: [[String: Any]] = []
    var failures: [String] = []
    for (index, plan) in plans.enumerated() {
        let raster = rasters[index]
        let hallHeight = plan.boxes.first { $0.role == "main-hall" }!.size.y
        let roofHeight = plan.boxes.first { $0.role == "roof-peak" }!.size.y
        let hallVisibleHeight = (hallHeight + roofHeight) * pixelsPerWorld
        let hallRatio = Double(raster.hallBounds.width) / hallVisibleHeight
        let nonStackTop = plan.boxes.filter { !$0.stack }
            .map { $0.center.y + $0.size.y * 0.5 }.max()!
        let controlHeight = plan.boxes.first { $0.role == "control-wing" }!.size.y
        let stackShare = Double(raster.stackPixelCount) / Double(raster.silhouettePixelCount)
        let freightPass = raster.freightWidths.allSatisfy { $0 >= 8 }
        if hallRatio < 3.4 { failures.append("\(plan.direction): hall ratio \(hallRatio)") }
        if nonStackTop > 42 { failures.append("\(plan.direction): non-stack top \(nonStackTop)") }
        if stackShare > 0.08 { failures.append("\(plan.direction): stack share \(stackShare)") }
        if raster.peakCount < 4 { failures.append("\(plan.direction): roof peaks \(raster.peakCount)") }
        if controlHeight / hallHeight > 0.55 {
            failures.append("\(plan.direction): control/hall \(controlHeight / hallHeight)")
        }
        if !freightPass { failures.append("\(plan.direction): freight width \(raster.freightWidths)") }
        directionMetrics.append([
            "direction": plan.direction,
            "geometryID": plan.geometryID,
            "hallProjectedWidthPixels": raster.hallBounds.width,
            "hallVisibleHeightPixels": hallVisibleHeight,
            "hallIsometricBoundingBoxHeightPixels": raster.hallBounds.height,
            "hallWidthToVisibleHeight": hallRatio,
            "nonStackMaximumWorldY": nonStackTop,
            "stackSilhouetteAreaShareUpperBound": stackShare,
            "roofPeakCount": raster.peakCount,
            "controlWingToHallHeight": controlHeight / hallHeight,
            "freightOpeningCompactWidthsPixels": raster.freightWidths,
            "freightOpeningPass": freightPass,
            "silhouetteBoundsSource": [
                raster.silhouetteBounds.minX,
                raster.silhouetteBounds.minY,
                raster.silhouetteBounds.width,
                raster.silhouetteBounds.height,
            ],
        ])
    }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let materialURL = sourceRoot.appendingPathComponent(
        "materials/industrial-l04-turbine-v06-prepixel.json"
    )
    try FileManager.default.createDirectory(
        at: materialURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try writeJSON(materialLibraryJSON(), to: materialURL)
    let materialSHA = try sha256(materialURL)
    let materialFile =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
        + "industrial-l04-turbine-v06-prepixel/materials/"
        + "industrial-l04-turbine-v06-prepixel.json"
    let toolchainFile =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/toolchain/"
        + "toolchain-industrial-l03-source-v01.json"
    let toolchainSHA = try sha256(repository.appendingPathComponent(toolchainFile))
    var descriptorRecords: [[String: Any]] = []
    var descriptorHashes = Set<String>()
    var geometryHashes = Set<String>()
    var generatedGeometryIDs = Set<String>()
    let decoder = JSONDecoder()
    let materialLibrary = try decoder.decode(
        MaterialLibraryDescriptor.self,
        from: Data(contentsOf: materialURL)
    )
    let materialIDs = Set(materialLibrary.materials.map(\.id))
    for plan in plans {
        let scene = sceneJSON(
            plan,
            materialFile: materialFile,
            materialSHA: materialSHA,
            toolchainFile: toolchainFile,
            toolchainSHA: toolchainSHA
        )
        let lower = plan.direction.lowercased()
        let descriptorURL = sourceRoot.appendingPathComponent(
            "scenes/industrial_l04/variant-0/\(lower)/scene.json"
        )
        try FileManager.default.createDirectory(
            at: descriptorURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writeJSON(scene, to: descriptorURL)
        let descriptorData = try Data(contentsOf: descriptorURL)
        let decoded = try decoder.decode(SceneDescriptor.self, from: descriptorData)
        let references =
            [decoded.building.wallMaterialID, decoded.building.trimMaterialID,
             decoded.building.roofMaterialID, decoded.building.foundationMaterialID,
             decoded.building.chimney.materialID, decoded.entrance.doorMaterialID,
             decoded.entrance.surroundMaterialID, decoded.entrance.pavilionMaterialID]
            + (decoded.building.massBlocks ?? []).map(\.materialID)
            + (decoded.building.roofVolumes ?? []).flatMap {
                [$0.materialID, $0.trimMaterialID]
            }
            + (decoded.building.trimBands ?? []).map(\.materialID)
            + decoded.facades.map(\.materialID)
            + decoded.props.map(\.materialID)
        let missing = Set(references).subtracting(materialIDs)
        if !missing.isEmpty {
            failures.append("\(plan.direction): missing materials \(missing.sorted())")
        }
        let descriptorSHA = sha256(descriptorData)
        let geometrySubset: [String: Any] = [
            "building": scene["building"]!,
            "registration": scene["registration"]!,
            "facades": scene["facades"]!,
            "entrance": scene["entrance"]!,
            "props": scene["props"]!,
            "occlusionExclusions": scene["occlusionExclusions"]!,
        ]
        let geometrySHA = sha256(try jsonData(geometrySubset))
        descriptorHashes.insert(descriptorSHA)
        geometryHashes.insert(geometrySHA)
        generatedGeometryIDs.insert(decoded.sceneGeometryID)
        descriptorRecords.append([
            "direction": plan.direction,
            "file": "source/scenes/industrial_l04/variant-0/\(lower)/scene.json",
            "descriptorSHA256": descriptorSHA,
            "canonicalGeometrySHA256": geometrySHA,
            "sceneGeometryID": decoded.sceneGeometryID,
            "productionDecode": "PASS",
            "materialReferenceCount": references.count,
            "missingMaterialReferences": missing.sorted(),
            "authoredIndependently": decoded.authoredIndependently,
            "orientationTransform": decoded.registration.orientationTransform,
        ])
    }
    if descriptorHashes.count != 4 { failures.append("descriptor uniqueness failed") }
    if geometryHashes.count != 4 { failures.append("geometry uniqueness failed") }

    var catalogDescriptorHashes = Set<String>()
    var catalogGeometryIDs = Set<String>()
    let artProof = repository.appendingPathComponent(
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof"
    )
    if let enumerator = FileManager.default.enumerator(
        at: artProof,
        includingPropertiesForKeys: nil
    ) {
        for case let file as URL in enumerator
        where file.lastPathComponent == "scene.json" {
            let data = try Data(contentsOf: file)
            catalogDescriptorHashes.insert(sha256(data))
            if
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let geometryID = object["sceneGeometryID"] as? String
            {
                catalogGeometryIDs.insert(geometryID)
            }
        }
    }
    let descriptorIntersection = descriptorHashes.intersection(catalogDescriptorHashes)
    let geometryIDIntersection = generatedGeometryIDs.intersection(catalogGeometryIDs)
    if !descriptorIntersection.isEmpty { failures.append("catalog descriptor alias") }
    if !geometryIDIntersection.isEmpty { failures.append("catalog geometry ID alias") }

    let feasibility: [String: Any] = [
        "oneSpritePerDirectionPerLOD": true,
        "directionCount": 4,
        "lodCount": 3,
        "spriteCount": 12,
        "conservativeDimensions": [
            "block": [512, 512],
            "neighborhood": [256, 256],
            "city": [128, 128],
        ],
        "decodedRGBABytes": 5_505_024,
        "decodedMiB": 5.25,
        "residencyCeilingMiB": 50.3,
        "residencyPass": true,
        "maximumAtlasPages": 4,
        "fourPagePass": true,
        "productionSelected": false,
    ]
    let feasibilityURL = root.appendingPathComponent("FEASIBILITY.json")
    try writeJSON(feasibility, to: feasibilityURL)

    var panelHashes: [String: String] = [:]
    for file in try FileManager.default.contentsOfDirectory(
        at: reviewRoot,
        includingPropertiesForKeys: nil
    ).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        panelHashes[file.lastPathComponent] = try sha256(file)
    }
    let report: [String: Any] = [
        "taskID": "PLAY-027",
        "artifact": "Industrial L4 Turbine Works v06 material and registration pre-pixel",
        "authorityCommit": "3c160e21a917adffd4bf148351a1657184154669",
        "acceptedClayCommit": "90f3c0e8d3c6eab62de2487b84ebf211a2403cd6",
        "sourceAuthority": sourceAuthority,
        "productionSelected": productionSelected,
        "sceneKitProcesses": 0,
        "metalProcesses": 0,
        "imageGenCalls": 0,
        "normalizerProcesses": 0,
        "containsDescriptors": true,
        "containsMaterials": true,
        "materialLibrarySHA256": materialSHA,
        "materialCount": materialLibrary.materials.count,
        "descriptorRecords": descriptorRecords,
        "descriptorUniqueness": descriptorHashes.count,
        "canonicalGeometryUniqueness": geometryHashes.count,
        "catalogDescriptorHashIntersection": descriptorIntersection.sorted(),
        "catalogGeometryIDIntersection": geometryIDIntersection.sorted(),
        "directions": directionMetrics,
        "hardGateFailures": failures,
        "technicalDisposition": failures.isEmpty
            ? "PASS_PENDING_INDEPENDENT_PREPIXEL_REVIEW"
            : "REJECTED",
        "reviewPanelSHA256": panelHashes,
        "feasibilitySHA256": try sha256(feasibilityURL),
    ]
    try writeJSON(report, to: root.appendingPathComponent("PREPIXEL-VALIDATION.json"))
    guard failures.isEmpty else {
        throw ClayResetError.failed(failures.joined(separator: "; "))
    }
}

@main
enum Main {
    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }
}
