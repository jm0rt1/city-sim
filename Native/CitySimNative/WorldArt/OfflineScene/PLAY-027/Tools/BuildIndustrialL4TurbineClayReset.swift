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
    let staffBoundsCompact: CGRect
    let peakCount: Int
}

struct DescriptorPrimitive {
    let id: String
    let materialID: String
    let center: V3
    let size: V3
    let shape: String
    let stack: Bool
}

struct CameraContract {
    let position: V3
    let target: V3
    let forward: V3
    let right: V3
    let up: V3
    let pixelsPerWorld: Double
    let viewport: CGSize
    let offset: P2
}

struct DescriptorRenderPlan {
    let direction: String
    let geometryID: String
    let primitives: [DescriptorPrimitive]
    let camera: CameraContract
    let registration: [String: Any]
    let light: [String: Any]
    let frontageWorld: [V3]
    let entranceBaseWorld: V3
    let descriptorGeometrySHA256: String
    let renderGeometrySHA256: String
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
let registeredCameraPosition = V3(
    x: 96,
    y: 101.24557426726288,
    z: 96
)
let registeredCameraTarget = V3(
    x: 0,
    y: 22.861902498201186,
    z: 0
)
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
        "libraryID": "industrial-l04-turbine-source-v08-prepixel",
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
        "sourceRevisionBinding": "source-v08-prepixel",
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
    let authoredBoxes = plan.boxes.filter {
        $0.role != "foundation" && $0.role != "roof-peak"
    }
    let massBlocks: [[String: Any]] = authoredBoxes.map { item in
        let position = worldPoint(item.center, direction: direction)
        return [
            "id": item.id.replacingOccurrences(of: "i04-", with: "i04-v08-"),
            "dimensions": worldDimensions(item.size, direction: direction),
            "positionWorld": [position.x, position.y, position.z],
            "materialID": materialID(for: item.role),
        ]
    } + plan.freightCenters.enumerated().map { index, center in
        let local: V3
        let dimensions: V3
        if direction == "N" {
            local = V3(
                x: [26.0, 19.0, 12.0][index],
                y: 7.75,
                z: center
            )
            dimensions = V3(x: 1, y: 11.5, z: 14.4)
        } else if direction == "W" {
            local = V3(
                x: [-26.0, -19.0, -12.0][index],
                y: 7.75,
                z: center
            )
            dimensions = V3(x: 1, y: 11.5, z: 14.4)
        } else {
            local = V3(x: center, y: 7.75, z: -18)
            dimensions = V3(x: 14.4, y: 11.5, z: 1)
        }
        let position = worldPoint(local, direction: direction)
        return [
            "id": "i04-v08-\(lower)-freight-\(index + 1)-recess",
            "dimensions": worldDimensions(dimensions, direction: direction),
            "positionWorld": [position.x, position.y, position.z],
            "materialID": materialID(for: "freight-recess"),
        ]
    } + [
        {
            let local = V3(x: plan.staffCenter, y: 5, z: -27.7)
            let position = worldPoint(local, direction: direction)
            return [
                "id": "i04-v08-\(lower)-staff-entry",
                "dimensions": worldDimensions(
                V3(x: 5, y: 6, z: 0.6),
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
                "id": item.id.replacingOccurrences(of: "i04-", with: "i04-v08-"),
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
    // One fixed map camera is shared across authored directional geometry.
    // Its exact vertical position and target bind the 56×56 ground diamond to
    // the descriptor's [768,640]…[768,896] registration within one pixel.
    let cameraPosition = [
        registeredCameraPosition.x,
        registeredCameraPosition.y,
        registeredCameraPosition.z,
    ]
    let cameraTarget = [
        registeredCameraTarget.x,
        registeredCameraTarget.y,
        registeredCameraTarget.z,
    ]
    return [
        "schema": 2,
        "task": "PLAY-027",
        "sceneGeometryID": "industrial-l04-turbine-v08-\(lower)-independent",
        "logicalBuildingID": "industrial_l04",
        "family": "industrial",
        "level": 4,
        "variantID": "variant-0",
        "viewDirection": lower,
        "sourceRevision": "source-v08-prepixel",
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
            "yawDegrees": 45,
            "elevationDegrees": 30,
            "orthographicScale": 79.1959533691406,
            "renderViewportPixels": [1536, 1024],
            "oversamplingFactor": 4,
            "positionWorld": cameraPosition,
            "targetWorld": cameraTarget,
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
            "massingProfile": "turbine-works-v08-long-sawtooth-foundry-\(lower)",
            "massBlocks": massBlocks,
            "roofVolumes": roofVolumes,
            "trimBands": [[
                "id": "i04-v08-\(lower)-process-heat-band",
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
            "id": "i04-v08-\(lower)-road-frontage",
            "direction": lower,
            "edgeWorld": facadeEdge(direction),
            "materialID": materialID(for: "control-wing"),
            "hasEntrance": true,
            "windowBays": [],
            "windowRhythms": [],
        ]],
        "entrance": [
            "facadeID": "i04-v08-\(lower)-road-frontage",
            "baseWorld": [entranceWorld.x, entranceWorld.y, entranceWorld.z],
            "width": 5,
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
            "id": "i04-v08-\(lower)-frontage-visibility",
            "purpose": "keep three freight voids and separate staff entrance visible",
            "polygonWorld": frontageVisibilityPolygon(direction),
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
    let freightCenters = [-16.0, 0.0, 16.0]
    if direction == "N" {
        let northFreightCenters = [-12.0, 2.5, 17.0]
        var boxes = [
            box("\(prefix)-foundation", "foundation", 0, 1, 0, 56, 2, 56),
            box(
                "\(prefix)-turbine-hall-rear",
                "main-hall",
                -8.5,
                10,
                13,
                37,
                16,
                26
            ),
            box(
                "\(prefix)-turbine-hall-front-leg",
                "main-hall",
                -21,
                10,
                -12,
                12,
                16,
                24
            ),
            box(
                "\(prefix)-control-wing-west-return",
                "control-wing",
                -23.75,
                6,
                -25.4,
                6.5,
                8,
                4
            ),
            box(
                "\(prefix)-rear-stack",
                "rear-stack",
                -20,
                27,
                17,
                3,
                30,
                3,
                stack: true
            ),
            box(
                "\(prefix)-front-apron",
                "apron",
                18.5,
                0.7,
                3,
                17,
                1.4,
                50
            ),
        ]
        for (index, center) in northFreightCenters.enumerated() {
            boxes.append(
                box(
                    "\(prefix)-freight-canopy-\(index + 1)",
                    "freight-canopy",
                    [23.5, 16.5, 9.5][index],
                    14.5,
                    center,
                    5,
                    3,
                    14.4
                )
            )
        }
        for index in 0..<4 {
            boxes.append(
                box(
                    "\(prefix)-sawtooth-\(index + 1)",
                    "roof-peak",
                    -22 + Double(index) * 9,
                    20,
                    13,
                    8,
                    4,
                    24
                )
            )
        }
        return DirectionPlan(
            direction: direction,
            geometryID: "industrial-l04-turbine-v08-n-courtyard",
            boxes: boxes,
            freightCenters: northFreightCenters,
            staffCenter: -18
        )
    }
    if direction == "W" {
        let westFreightCenters = [-11.0, 3.5, 18.0]
        var boxes = [
            box("\(prefix)-foundation", "foundation", 0, 1, 0, 56, 2, 56),
            box(
                "\(prefix)-turbine-hall",
                "main-hall",
                8.5,
                10,
                1,
                37,
                16,
                50
            ),
            box(
                "\(prefix)-control-wing-south-return",
                "control-wing",
                -13,
                6,
                -25.4,
                4,
                8,
                4
            ),
            box(
                "\(prefix)-assembly-annex",
                "assembly-annex",
                -21,
                7,
                -13,
                12,
                12,
                10
            ),
            box(
                "\(prefix)-rear-stack",
                "rear-stack",
                20,
                27,
                17,
                3,
                30,
                3,
                stack: true
            ),
            box(
                "\(prefix)-front-apron",
                "apron",
                -18.5,
                0.7,
                3,
                17,
                1.4,
                50
            ),
        ]
        for (index, center) in westFreightCenters.enumerated() {
            boxes.append(
                box(
                    "\(prefix)-freight-canopy-\(index + 1)",
                    "freight-canopy",
                    [-23.5, -16.5, -9.5][index],
                    14.5,
                    center,
                    5,
                    3,
                    14.4
                )
            )
        }
        for index in 0..<4 {
            boxes.append(
                box(
                    "\(prefix)-sawtooth-\(index + 1)",
                    "roof-peak",
                    8.5,
                    20,
                    -18 + Double(index) * 12,
                    37,
                    4,
                    10
                )
            )
        }
        return DirectionPlan(
            direction: direction,
            geometryID: "industrial-l04-turbine-v08-w-sidecourt",
            boxes: boxes,
            freightCenters: westFreightCenters,
            staffCenter: -18
        )
    }

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
        box(
            "\(prefix)-assembly-annex",
            "assembly-annex",
            annexX,
            7,
            direction == "N" || direction == "W" ? -1 : 13,
            18,
            12,
            12
        ),
        box("\(prefix)-rear-stack", "rear-stack", stackX, 27, 13, 3, 30, 3, stack: true),
        box("\(prefix)-front-apron", "apron", 0, 0.7, -21, 50, 1.4, 14),
    ]
    for (index, center) in freightCenters.enumerated() {
        boxes.append(
            box(
                "\(prefix)-freight-canopy-\(index + 1)",
                "freight-canopy",
                center,
                14.5,
                direction == "N" || direction == "W" ? 7.5 : -15.5,
                14.4,
                3,
                5
            )
        )
    }
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
        geometryID: "industrial-l04-turbine-v08-\(direction.lowercased())",
        boxes: boxes,
        freightCenters: freightCenters,
        staffCenter: staffX
    )
}

let materialColors: [String: MaterialColor] = [
    "foundation": MaterialColor(
        id: "l4t-charcoal-foundation",
        rgba: [0.22, 0.24, 0.23, 1],
        roughness: 0.96,
        metalness: 0.02,
        pattern: "large-scored-foundation"
    ),
    "main-hall": MaterialColor(
        id: "l4t-weathered-blue-green-steel",
        rgba: [0.27, 0.40, 0.41, 1],
        roughness: 0.84,
        metalness: 0.26,
        pattern: "procedural-vertical-corrugation"
    ),
    "control-wing": MaterialColor(
        id: "l4t-weathered-warm-brick",
        rgba: [0.62, 0.42, 0.29, 1],
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
        rgba: [0.18, 0.23, 0.23, 1],
        roughness: 0.78,
        metalness: 0.38,
        pattern: "painted-structural-steel"
    ),
    "apron": MaterialColor(
        id: "l4t-warm-scored-apron",
        rgba: [0.54, 0.50, 0.42, 1],
        roughness: 0.98,
        metalness: 0,
        pattern: "large-scored-slabs"
    ),
    "roof-peak": MaterialColor(
        id: "l4t-dark-roof-metal",
        rgba: [0.30, 0.37, 0.36, 1],
        roughness: 0.88,
        metalness: 0.24,
        pattern: "weathered-standing-seam"
    ),
    "freight-recess": MaterialColor(
        id: "l4t-deep-freight-recess",
        rgba: [0.18, 0.20, 0.20, 1],
        roughness: 0.97,
        metalness: 0.02,
        pattern: "solid-depth-cavity"
    ),
    "staff-entry": MaterialColor(
        id: "l4t-believable-glazing",
        rgba: [0.38, 0.56, 0.58, 1],
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

func +(lhs: V3, rhs: V3) -> V3 {
    V3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

func -(lhs: V3, rhs: V3) -> V3 {
    V3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

func *(lhs: V3, rhs: Double) -> V3 {
    V3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
}

func dot(_ lhs: V3, _ rhs: V3) -> Double {
    lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
}

func cross(_ lhs: V3, _ rhs: V3) -> V3 {
    V3(
        x: lhs.y * rhs.z - lhs.z * rhs.y,
        y: lhs.z * rhs.x - lhs.x * rhs.z,
        z: lhs.x * rhs.y - lhs.y * rhs.x
    )
}

func normalized(_ value: V3) throws -> V3 {
    let length = sqrt(dot(value, value))
    guard length > 0.000_001 else {
        throw ClayResetError.failed("cannot normalize zero vector")
    }
    return value * (1 / length)
}

func vector(_ value: Any?, label: String) throws -> V3 {
    guard let numbers = value as? [NSNumber], numbers.count == 3 else {
        throw ClayResetError.failed("\(label) must contain three numbers")
    }
    return V3(
        x: numbers[0].doubleValue,
        y: numbers[1].doubleValue,
        z: numbers[2].doubleValue
    )
}

func numberPair(_ value: Any?, label: String) throws -> [Double] {
    guard let numbers = value as? [NSNumber], numbers.count == 2 else {
        throw ClayResetError.failed("\(label) must contain two numbers")
    }
    return numbers.map(\.doubleValue)
}

func cameraContract(_ scene: [String: Any]) throws -> CameraContract {
    guard
        let camera = scene["camera"] as? [String: Any],
        let scale = (camera["orthographicScale"] as? NSNumber)?.doubleValue
    else {
        throw ClayResetError.failed("descriptor camera contract missing")
    }
    let position = try vector(camera["positionWorld"], label: "camera.positionWorld")
    let target = try vector(camera["targetWorld"], label: "camera.targetWorld")
    let viewport = try numberPair(
        camera["renderViewportPixels"],
        label: "camera.renderViewportPixels"
    )
    let offset = try numberPair(
        camera["postProjectionOffsetPixels"],
        label: "camera.postProjectionOffsetPixels"
    )
    let forward = try normalized(target - position)
    let right = try normalized(cross(forward, V3(x: 0, y: 1, z: 0)))
    let up = try normalized(cross(right, forward))
    return CameraContract(
        position: position,
        target: target,
        forward: forward,
        right: right,
        up: up,
        pixelsPerWorld: viewport[1] / (2 * scale),
        viewport: CGSize(width: viewport[0], height: viewport[1]),
        offset: P2(x: offset[0], y: offset[1])
    )
}

func descriptorRenderPlan(
    _ scene: [String: Any],
    geometrySHA256: String
) throws -> DescriptorRenderPlan {
    guard
        let direction = scene["viewDirection"] as? String,
        let geometryID = scene["sceneGeometryID"] as? String,
        let building = scene["building"] as? [String: Any],
        let registration = scene["registration"] as? [String: Any],
        let light = scene["light"] as? [String: Any],
        let facades = scene["facades"] as? [[String: Any]],
        let facade = facades.first,
        let edge = facade["edgeWorld"] as? [[NSNumber]],
        edge.count == 2,
        edge.allSatisfy({ $0.count == 2 }),
        let entrance = scene["entrance"] as? [String: Any]
    else {
        throw ClayResetError.failed("descriptor render contract missing")
    }
    var primitives: [DescriptorPrimitive] = []
    func appendPrimitive(
        id: String,
        materialID: String,
        dimensions: Any?,
        position: Any?,
        shape: String = "box"
    ) throws {
        let size = try vector(dimensions, label: "\(id).dimensions")
        let center = try vector(position, label: "\(id).positionWorld")
        guard size.x > 0, size.y > 0, size.z > 0 else {
            throw ClayResetError.failed("\(id) has invalid dimensions")
        }
        primitives.append(
            DescriptorPrimitive(
                id: id,
                materialID: materialID,
                center: center,
                size: size,
                shape: shape,
                stack: id.contains("rear-stack")
            )
        )
    }
    guard
        let foundationMaterial = building["foundationMaterialID"] as? String
    else {
        throw ClayResetError.failed("foundation material missing")
    }
    try appendPrimitive(
        id: "i04-v08-\(direction)-foundation",
        materialID: foundationMaterial,
        dimensions: building["foundationDimensions"],
        position: building["foundationPositionWorld"]
    )
    for item in building["massBlocks"] as? [[String: Any]] ?? [] {
        guard
            let id = item["id"] as? String,
            let materialID = item["materialID"] as? String
        else {
            throw ClayResetError.failed("mass block identity missing")
        }
        try appendPrimitive(
            id: id,
            materialID: materialID,
            dimensions: item["dimensions"],
            position: item["positionWorld"]
        )
    }
    for item in building["roofVolumes"] as? [[String: Any]] ?? [] {
        guard
            let id = item["id"] as? String,
            let materialID = item["materialID"] as? String
        else {
            throw ClayResetError.failed("roof volume identity missing")
        }
        try appendPrimitive(
            id: id,
            materialID: materialID,
            dimensions: item["dimensions"],
            position: item["positionWorld"],
            shape: item["shape"] as? String ?? "box"
        )
    }
    for item in building["trimBands"] as? [[String: Any]] ?? [] {
        guard
            let id = item["id"] as? String,
            let materialID = item["materialID"] as? String
        else {
            throw ClayResetError.failed("trim band identity missing")
        }
        try appendPrimitive(
            id: id,
            materialID: materialID,
            dimensions: item["dimensions"],
            position: item["positionWorld"]
        )
    }
    let canonical: [[String: Any]] = primitives.map {
        [
            "id": $0.id,
            "materialID": $0.materialID,
            "positionWorld": [$0.center.x, $0.center.y, $0.center.z],
            "dimensions": [$0.size.x, $0.size.y, $0.size.z],
            "shape": $0.shape,
        ]
    }
    return DescriptorRenderPlan(
        direction: direction.uppercased(),
        geometryID: geometryID,
        primitives: primitives,
        camera: try cameraContract(scene),
        registration: registration,
        light: light,
        frontageWorld: edge.map {
            V3(x: $0[0].doubleValue, y: 0, z: $0[1].doubleValue)
        },
        entranceBaseWorld: try vector(
            entrance["baseWorld"],
            label: "entrance.baseWorld"
        ),
        descriptorGeometrySHA256: geometrySHA256,
        renderGeometrySHA256: sha256(try jsonData(canonical))
    )
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

func registeredSourcePoint(_ world: V3) -> [Double] {
    let rootTwo = sqrt(2.0)
    let cameraX = (world.x - world.z) / rootTwo
    let cameraY =
        world.y * cos(.pi / 6)
        - (world.x + world.z) / rootTwo * sin(.pi / 6)
    let cameraPixelsPerWorld =
        Double(sourceSize.height) / (2 * 79.1959533691406)
    return [
        Double(sourceSize.width) * 0.5 + cameraX * cameraPixelsPerWorld,
        768 - cameraY * cameraPixelsPerWorld,
    ]
}

func registration(_ direction: String) -> [String: Any] {
    let edge: [[Double]]
    let socket: [Double]
    switch direction {
    case "N":
        edge = [[768, 640], [1024, 768]]
        socket = [896, 704]
    case "E":
        edge = [[1024, 768], [768, 896]]
        socket = [896, 832]
    case "S":
        edge = [[768, 896], [512, 768]]
        socket = [640, 832]
    default:
        edge = [[512, 768], [768, 640]]
        socket = [640, 704]
    }
    let staffCenter = plan(direction).staffCenter
    let door = [-2.5, 2.5].map {
        registeredSourcePoint(
            worldPoint(
                V3(x: staffCenter + $0, y: 2, z: -28),
                direction: direction
            )
        )
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

func frontageVisibilityPolygon(_ direction: String) -> [[Double]] {
    switch direction {
    case "N": return [[-28, -28], [28, -28], [28, -7], [-28, -7]]
    case "E": return [[28, -28], [28, 28], [7, 28], [7, -28]]
    case "S": return [[28, 28], [-28, 28], [-28, 7], [28, 7]]
    default: return [[-28, 28], [-28, -28], [-7, -28], [-7, 28]]
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

func projected(
    _ point: V3,
    camera: CameraContract,
    size: CGSize
) -> P2 {
    let relative = point - camera.target
    let source = P2(
        x: camera.viewport.width * 0.5
            + dot(relative, camera.right) * camera.pixelsPerWorld
            + camera.offset.x,
        y: camera.viewport.height * 0.5
            - dot(relative, camera.up) * camera.pixelsPerWorld
            + camera.offset.y
    )
    return P2(
        x: source.x * Double(size.width / camera.viewport.width),
        y: source.y * Double(size.height / camera.viewport.height)
    )
}

func primitiveVertices(_ item: DescriptorPrimitive) -> [V3] {
    let half = item.size * 0.5
    return [
        V3(x: item.center.x - half.x, y: item.center.y - half.y, z: item.center.z - half.z),
        V3(x: item.center.x + half.x, y: item.center.y - half.y, z: item.center.z - half.z),
        V3(x: item.center.x + half.x, y: item.center.y + half.y, z: item.center.z - half.z),
        V3(x: item.center.x - half.x, y: item.center.y + half.y, z: item.center.z - half.z),
        V3(x: item.center.x - half.x, y: item.center.y - half.y, z: item.center.z + half.z),
        V3(x: item.center.x + half.x, y: item.center.y - half.y, z: item.center.z + half.z),
        V3(x: item.center.x + half.x, y: item.center.y + half.y, z: item.center.z + half.z),
        V3(x: item.center.x - half.x, y: item.center.y + half.y, z: item.center.z + half.z),
    ]
}

func descriptorPolygons(
    for item: DescriptorPrimitive,
    camera: CameraContract,
    keyOrigin: V3,
    size: CGSize
) throws -> [Polygon] {
    let definitions: [(V3, [V3])]
    if item.shape == "hip" {
        let half = item.size * 0.5
        let y0 = item.center.y - half.y
        let y1 = item.center.y + half.y
        if item.size.x >= item.size.z {
            let left = item.center.x - half.x
            let right = item.center.x + half.x
            definitions = [
                (
                    V3(x: 0, y: 0.7, z: -0.7),
                    [
                        V3(x: left, y: y0, z: item.center.z - half.z),
                        V3(x: right, y: y0, z: item.center.z - half.z),
                        V3(x: right, y: y1, z: item.center.z),
                        V3(x: left, y: y1, z: item.center.z),
                    ]
                ),
                (
                    V3(x: 0, y: 0.7, z: 0.7),
                    [
                        V3(x: right, y: y0, z: item.center.z + half.z),
                        V3(x: left, y: y0, z: item.center.z + half.z),
                        V3(x: left, y: y1, z: item.center.z),
                        V3(x: right, y: y1, z: item.center.z),
                    ]
                ),
                (
                    V3(x: -1, y: 0, z: 0),
                    [
                        V3(x: left, y: y0, z: item.center.z + half.z),
                        V3(x: left, y: y0, z: item.center.z - half.z),
                        V3(x: left, y: y1, z: item.center.z),
                    ]
                ),
                (
                    V3(x: 1, y: 0, z: 0),
                    [
                        V3(x: right, y: y0, z: item.center.z - half.z),
                        V3(x: right, y: y0, z: item.center.z + half.z),
                        V3(x: right, y: y1, z: item.center.z),
                    ]
                ),
            ]
        } else {
            let front = item.center.z - half.z
            let back = item.center.z + half.z
            definitions = [
                (
                    V3(x: -0.7, y: 0.7, z: 0),
                    [
                        V3(x: item.center.x - half.x, y: y0, z: back),
                        V3(x: item.center.x - half.x, y: y0, z: front),
                        V3(x: item.center.x, y: y1, z: front),
                        V3(x: item.center.x, y: y1, z: back),
                    ]
                ),
                (
                    V3(x: 0.7, y: 0.7, z: 0),
                    [
                        V3(x: item.center.x + half.x, y: y0, z: front),
                        V3(x: item.center.x + half.x, y: y0, z: back),
                        V3(x: item.center.x, y: y1, z: back),
                        V3(x: item.center.x, y: y1, z: front),
                    ]
                ),
                (
                    V3(x: 0, y: 0, z: -1),
                    [
                        V3(x: item.center.x - half.x, y: y0, z: front),
                        V3(x: item.center.x + half.x, y: y0, z: front),
                        V3(x: item.center.x, y: y1, z: front),
                    ]
                ),
                (
                    V3(x: 0, y: 0, z: 1),
                    [
                        V3(x: item.center.x + half.x, y: y0, z: back),
                        V3(x: item.center.x - half.x, y: y0, z: back),
                        V3(x: item.center.x, y: y1, z: back),
                    ]
                ),
            ]
        }
    } else {
        let vertices = primitiveVertices(item)
        definitions = [
            (V3(x: -1, y: 0, z: 0), [vertices[0], vertices[4], vertices[7], vertices[3]]),
            (V3(x: 1, y: 0, z: 0), [vertices[1], vertices[2], vertices[6], vertices[5]]),
            (V3(x: 0, y: -1, z: 0), [vertices[0], vertices[1], vertices[5], vertices[4]]),
            (V3(x: 0, y: 1, z: 0), [vertices[3], vertices[7], vertices[6], vertices[2]]),
            (V3(x: 0, y: 0, z: -1), [vertices[0], vertices[3], vertices[2], vertices[1]]),
            (V3(x: 0, y: 0, z: 1), [vertices[4], vertices[5], vertices[6], vertices[7]]),
        ]
    }
    return try definitions.compactMap { normal, world in
        let center = world.reduce(V3(x: 0, y: 0, z: 0), +) * (1 / Double(world.count))
        guard dot(normal, camera.position - center) > 0.000_001 else {
            return nil
        }
        let unitNormal = try normalized(normal)
        let toLight = try normalized(keyOrigin - center)
        let shade = 0.72 + 0.28 * max(0, dot(unitNormal, toLight))
        return Polygon(
            points: world.map { projected($0, camera: camera, size: size) },
            depth: world.map { dot($0 - camera.target, camera.forward) }
                .reduce(0, +) / Double(world.count),
            shade: CGFloat(shade)
        )
    }
}

func projectedBounds(
    _ item: DescriptorPrimitive,
    camera: CameraContract,
    size: CGSize
) -> CGRect {
    let points = primitiveVertices(item).map {
        projected($0, camera: camera, size: size)
    }
    let xs = points.map(\.x)
    let ys = points.map(\.y)
    return CGRect(
        x: xs.min()!,
        y: ys.min()!,
        width: xs.max()! - xs.min()!,
        height: ys.max()! - ys.min()!
    )
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

func imageContext(width: Int, height: Int) throws -> CGContext {
    guard let value = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw ClayResetError.failed("cannot create image compositing context")
    }
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

func render(
    _ plan: DescriptorRenderPlan,
    size: CGSize
) throws -> Raster {
    let width = Int(size.width)
    let height = Int(size.height)
    let ctx = try context(width: width, height: height)
    let keyOrigin = try vector(plan.light["keyOrigin"], label: "light.keyOrigin")
    let all = try plan.primitives.flatMap { item in
        try descriptorPolygons(
            for: item,
            camera: plan.camera,
            keyOrigin: keyOrigin,
            size: size
        ).map { (item, $0) }
    }.sorted { $0.1.depth > $1.1.depth }
    for (item, polygon) in all {
        let base: CGFloat = item.id.contains("control-wing") ? 0.66 : polygon.shade
        ctx.setFillColor(CGColor(gray: base, alpha: 1))
        ctx.addPath(path(polygon.points))
        ctx.fillPath()
        ctx.setStrokeColor(CGColor(gray: 0.14, alpha: 1))
        ctx.setLineWidth(1)
        ctx.addPath(path(polygon.points))
        ctx.strokePath()
    }

    guard let image = ctx.makeImage() else {
        throw ClayResetError.failed("cannot create clay image")
    }
    let stats = try pixelStats(image)
    let hallPrimitives = plan.primitives.filter {
        $0.id.contains("turbine-hall")
    }
    guard
        !hallPrimitives.isEmpty,
        let stack = plan.primitives.first(where: \.stack),
        let staff = plan.primitives.first(where: { $0.id.contains("staff-entry") })
    else {
        throw ClayResetError.failed("\(plan.direction) semantic primitive missing")
    }
    let hallBounds = hallPrimitives
        .map { projectedBounds($0, camera: plan.camera, size: size) }
        .reduce(CGRect.null) { $0.union($1) }
    let stackBounds = projectedBounds(stack, camera: plan.camera, size: size)
    let stackPixels =
        Int(stackBounds.width.rounded(.up)) * Int(stackBounds.height.rounded(.up))
    let freightWidths = plan.primitives
        .filter { $0.id.contains("-freight-") && $0.id.contains("-recess") }
        .sorted { $0.id < $1.id }
        .map {
            projectedBounds($0, camera: plan.camera, size: size).width
                * Double(compactSize.width / size.width)
        }
    let staffBounds = projectedBounds(staff, camera: plan.camera, size: compactSize)
    return Raster(
        image: image,
        silhouetteBounds: stats.0,
        hallBounds: hallBounds,
        stackPixelCount: stackPixels,
        silhouettePixelCount: stats.1,
        freightWidths: freightWidths,
        staffBoundsCompact: staffBounds,
        peakCount: plan.primitives.filter { $0.shape == "hip" }.count
    )
}

func renderColor(
    _ plan: DescriptorRenderPlan,
    size: CGSize
) throws -> CGImage {
    let ctx = try context(width: Int(size.width), height: Int(size.height))
    let keyOrigin = try vector(plan.light["keyOrigin"], label: "light.keyOrigin")
    let materialByID = Dictionary(
        uniqueKeysWithValues: materialColors.values.map { ($0.id, $0) }
    )
    let all = try plan.primitives.flatMap { item in
        try descriptorPolygons(
            for: item,
            camera: plan.camera,
            keyOrigin: keyOrigin,
            size: size
        ).map { (item, $0) }
    }.sorted { $0.1.depth > $1.1.depth }
    for (item, polygon) in all {
        guard let material = materialByID[item.materialID] else {
            throw ClayResetError.failed("unknown render material \(item.materialID)")
        }
        let light = max(0.72, min(1, Double(polygon.shade)))
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
    guard let image = ctx.makeImage() else {
        throw ClayResetError.failed("cannot create color image")
    }
    return image
}

func semanticVisibility(
    _ plan: DescriptorRenderPlan,
    size: CGSize
) throws -> (CGImage, [[String: Any]]) {
    let ctx = try context(width: Int(size.width), height: Int(size.height))
    let keyOrigin = try vector(plan.light["keyOrigin"], label: "light.keyOrigin")
    let targetIDs = plan.primitives
        .filter {
            ($0.id.contains("-freight-") && $0.id.contains("-recess"))
                || $0.id.contains("staff-entry")
        }
        .sorted { $0.id < $1.id }
        .map(\.id)
    guard targetIDs.count == 4 else {
        throw ClayResetError.failed("\(plan.direction) semantic target count")
    }
    let colors: [[UInt8]] = [
        [224, 48, 48, 255],
        [48, 210, 80, 255],
        [48, 100, 230, 255],
        [238, 210, 48, 255],
    ]
    let colorByID = Dictionary(uniqueKeysWithValues: zip(targetIDs, colors))
    let all = try plan.primitives.flatMap { item in
        try descriptorPolygons(
            for: item,
            camera: plan.camera,
            keyOrigin: keyOrigin,
            size: size
        ).map { (item, $0) }
    }.sorted { $0.1.depth > $1.1.depth }
    for (item, polygon) in all {
        let bytes = colorByID[item.id] ?? [20, 20, 20, 255]
        ctx.setFillColor(
            red: CGFloat(bytes[0]) / 255,
            green: CGFloat(bytes[1]) / 255,
            blue: CGFloat(bytes[2]) / 255,
            alpha: 1
        )
        ctx.addPath(path(polygon.points))
        ctx.fillPath()
    }
    guard let image = ctx.makeImage(), let data = ctx.data else {
        throw ClayResetError.failed("cannot create semantic visibility raster")
    }
    let pixels = data.bindMemory(
        to: UInt8.self,
        capacity: Int(size.width * size.height) * 4
    )
    var metrics: [[String: Any]] = []
    for id in targetIDs {
        let color = colorByID[id]!
        var minimumX = Int(size.width)
        var minimumY = Int(size.height)
        var maximumX = -1
        var maximumY = -1
        var count = 0
        for y in 0..<Int(size.height) {
            for x in 0..<Int(size.width) {
                let index = (y * Int(size.width) + x) * 4
                guard
                    pixels[index] == color[0],
                    pixels[index + 1] == color[1],
                    pixels[index + 2] == color[2],
                    pixels[index + 3] == color[3]
                else {
                    continue
                }
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
                count += 1
            }
        }
        let sourceWidth = max(0, maximumX - minimumX + 1)
        let sourceHeight = max(0, maximumY - minimumY + 1)
        let compactWidth =
            Double(sourceWidth) * Double(compactSize.width / size.width)
        let compactHeight =
            Double(sourceHeight) * Double(compactSize.height / size.height)
        let isStaff = id.contains("staff-entry")
        let pass = count > 0
            && compactWidth >= (isStaff ? 2 : 8)
            && compactHeight >= (isStaff ? 4 : 8)
        metrics.append([
            "id": id,
            "visiblePixelCount": count,
            "visibleBoundsSource": [
                minimumX,
                minimumY,
                sourceWidth,
                sourceHeight,
            ],
            "visibleWidthCompact": compactWidth,
            "visibleHeightCompact": compactHeight,
            "pass": pass,
        ])
    }
    return (image, metrics)
}

func grayscale(_ image: CGImage) throws -> CGImage {
    let width = image.width
    let height = image.height
    let ctx = try imageContext(width: width, height: height)
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
    let ctx = try imageContext(width: color.width, height: color.height)
    ctx.draw(color, in: CGRect(x: 0, y: 0, width: color.width, height: color.height))
    ctx.setAlpha(0.34)
    ctx.setBlendMode(.screen)
    ctx.draw(clay, in: CGRect(x: 0, y: 0, width: clay.width, height: clay.height))
    guard let output = ctx.makeImage() else {
        throw ClayResetError.failed("cannot create clay overlay")
    }
    return output
}

func pointPairs(_ value: Any?, label: String) throws -> [[Double]] {
    guard
        let rows = value as? [[NSNumber]],
        rows.allSatisfy({ $0.count == 2 })
    else {
        throw ClayResetError.failed("\(label) must contain coordinate pairs")
    }
    return rows.map { $0.map(\.doubleValue) }
}

func distance(_ lhs: [Double], _ rhs: [Double]) -> Double {
    hypot(lhs[0] - rhs[0], lhs[1] - rhs[1])
}

func segmentDistance(
    point: [Double],
    start: [Double],
    end: [Double]
) -> (distance: Double, parameter: Double) {
    let dx = end[0] - start[0]
    let dy = end[1] - start[1]
    let denominator = dx * dx + dy * dy
    let parameter = denominator == 0
        ? 0
        : ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy)
            / denominator
    let clamped = max(0, min(1, parameter))
    let nearest = [start[0] + clamped * dx, start[1] + clamped * dy]
    return (distance(point, nearest), parameter)
}

func registrationOverlay(
    _ image: CGImage,
    plan: DescriptorRenderPlan
) throws -> (CGImage, [String: Any]) {
    let ctx = try imageContext(width: image.width, height: image.height)
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let edge = try pointPairs(
        plan.registration["frontageEdgeSource"],
        label: "frontageEdgeSource"
    )
    let footprint = try pointPairs(
        plan.registration["footprintPolygonSource"],
        label: "footprintPolygonSource"
    )
    let contactWorld = try pointPairs(
        plan.registration["contactPolygonWorld"],
        label: "contactPolygonWorld"
    ).map { V3(x: $0[0], y: 0, z: $0[1]) }
    let socket = try numberPair(
        plan.registration["frontageSocketSource"],
        label: "frontageSocketSource"
    )
    let pivot = try numberPair(
        plan.registration["groundPivotSource"],
        label: "groundPivotSource"
    )
    let door = try pointPairs(
        plan.registration["doorBaseSource"],
        label: "doorBaseSource"
    )
    let projectedContact = contactWorld.map {
        let point = projected($0, camera: plan.camera, size: sourceSize)
        return [point.x, point.y]
    }
    let projectedFrontage = plan.frontageWorld.map {
        let point = projected($0, camera: plan.camera, size: sourceSize)
        return [point.x, point.y]
    }
    let doorHalf = plan.direction == "N" || plan.direction == "S"
        ? V3(x: 2.5, y: 0, z: 0)
        : V3(x: 0, y: 0, z: 2.5)
    let projectedDoor = [
        plan.entranceBaseWorld - doorHalf,
        plan.entranceBaseWorld + doorHalf,
    ].map {
        let point = projected($0, camera: plan.camera, size: sourceSize)
        return [point.x, point.y]
    }
    let footprintMatchDistances = projectedContact.map { projectedPoint in
        footprint.map { distance(projectedPoint, $0) }.min()!
    }
    let pivotDistance = projectedContact.map { distance($0, pivot) }.min()!
    let frontageEndpointDistances = projectedFrontage.enumerated().map {
        index, point in distance(point, edge[index])
    }
    let socketMidpoint = [
        (edge[0][0] + edge[1][0]) * 0.5,
        (edge[0][1] + edge[1][1]) * 0.5,
    ]
    let socketDistance = distance(socket, socketMidpoint)
    let directDoorDistances = [
        distance(projectedDoor[0], door[0]),
        distance(projectedDoor[1], door[1]),
    ]
    let reversedDoorDistances = [
        distance(projectedDoor[0], door[1]),
        distance(projectedDoor[1], door[0]),
    ]
    let doorProjectionDistances =
        directDoorDistances.max()! <= reversedDoorDistances.max()!
            ? directDoorDistances
            : reversedDoorDistances
    let doorWorldPlaneDistance: Double
    switch plan.direction {
    case "N":
        doorWorldPlaneDistance = abs(plan.entranceBaseWorld.z + 28)
    case "E":
        doorWorldPlaneDistance = abs(plan.entranceBaseWorld.x - 28)
    case "S":
        doorWorldPlaneDistance = abs(plan.entranceBaseWorld.z - 28)
    default:
        doorWorldPlaneDistance = abs(plan.entranceBaseWorld.x + 28)
    }
    let doorParameters = door.map {
        segmentDistance(point: $0, start: edge[0], end: edge[1]).parameter
    }
    let maximumFootprintDistance = footprintMatchDistances.max()!
    let maximumFrontageDistance = frontageEndpointDistances.max()!
    let maximumDoorProjectionDistance = doorProjectionDistances.max()!
    guard maximumFootprintDistance <= 1, pivotDistance <= 1 else {
        throw ClayResetError.failed(
            "\(plan.direction) pivot/contact registration exceeds one pixel"
        )
    }
    guard maximumFrontageDistance <= 1, socketDistance <= 0.000_001 else {
        throw ClayResetError.failed(
            "\(plan.direction) frontage/socket registration mismatch"
        )
    }
    guard
        maximumDoorProjectionDistance <= 1,
        doorWorldPlaneDistance <= 0.000_001,
        doorParameters.allSatisfy({ $0 >= 0 && $0 <= 1 })
    else {
        throw ClayResetError.failed(
            "\(plan.direction) door base is not contained on authored frontage"
        )
    }

    ctx.setStrokeColor(red: 0.16, green: 0.82, blue: 0.94, alpha: 1)
    ctx.setLineWidth(4)
    ctx.addPath(
        path(
            projectedContact.map {
                P2(x: $0[0], y: Double(image.height) - $0[1])
            }
        )
    )
    ctx.strokePath()
    ctx.setStrokeColor(red: 0.95, green: 0.58, blue: 0.08, alpha: 1)
    ctx.setLineWidth(8)
    ctx.move(to: CGPoint(x: edge[0][0], y: Double(image.height) - edge[0][1]))
    ctx.addLine(to: CGPoint(x: edge[1][0], y: Double(image.height) - edge[1][1]))
    ctx.strokePath()
    ctx.setFillColor(red: 0.10, green: 0.85, blue: 0.45, alpha: 1)
    ctx.fillEllipse(
        in: CGRect(
            x: socket[0] - 10,
            y: Double(image.height) - socket[1] - 10,
            width: 20,
            height: 20
        )
    )
    ctx.setFillColor(red: 0.85, green: 0.20, blue: 0.25, alpha: 1)
    ctx.fillEllipse(
        in: CGRect(
            x: pivot[0] - 10,
            y: Double(image.height) - pivot[1] - 10,
            width: 20,
            height: 20
        )
    )
    ctx.setStrokeColor(red: 0.95, green: 0.95, blue: 0.80, alpha: 1)
    ctx.setLineWidth(5)
    ctx.move(to: CGPoint(x: door[0][0], y: Double(image.height) - door[0][1]))
    ctx.addLine(to: CGPoint(x: door[1][0], y: Double(image.height) - door[1][1]))
    ctx.strokePath()

    let keyOrigin = try vector(plan.light["keyOrigin"], label: "light.keyOrigin")
    let keyPoint = projected(keyOrigin, camera: plan.camera, size: sourceSize)
    let keyVector = V3(
        x: keyPoint.x - pivot[0],
        y: keyPoint.y - pivot[1],
        z: 0
    )
    let keyLength = max(1, hypot(keyVector.x, keyVector.y))
    let keyStart = [
        pivot[0] + keyVector.x / keyLength * 80,
        pivot[1] + keyVector.y / keyLength * 80,
    ]
    ctx.setStrokeColor(red: 1, green: 0.88, blue: 0.42, alpha: 1)
    ctx.setLineWidth(4)
    ctx.move(
        to: CGPoint(
            x: keyStart[0],
            y: Double(image.height) - keyStart[1]
        )
    )
    ctx.addLine(
        to: CGPoint(
            x: pivot[0],
            y: Double(image.height) - pivot[1]
        )
    )
    ctx.strokePath()
    let shadow = try numberPair(
        plan.light["shadowVectorSource"],
        label: "light.shadowVectorSource"
    )
    ctx.setStrokeColor(red: 0.46, green: 0.34, blue: 0.70, alpha: 1)
    ctx.setLineWidth(4)
    ctx.move(to: CGPoint(x: pivot[0], y: Double(image.height) - pivot[1]))
    ctx.addLine(
        to: CGPoint(
            x: pivot[0] + shadow[0] * 24,
            y: Double(image.height) - (pivot[1] + shadow[1] * 24)
        )
    )
    ctx.strokePath()
    guard let output = ctx.makeImage() else {
        throw ClayResetError.failed("cannot create registration overlay")
    }
    return (
        output,
        [
            "direction": plan.direction,
            "descriptorGeometrySHA256": plan.descriptorGeometrySHA256,
            "renderGeometrySHA256": plan.renderGeometrySHA256,
            "maximumFootprintProjectionDistancePixels": maximumFootprintDistance,
            "pivotToContactDistancePixels": pivotDistance,
            "maximumFrontageEndpointDistancePixels": maximumFrontageDistance,
            "socketToFrontageMidpointDistancePixels": socketDistance,
            "maximumDoorProjectionDistancePixels": maximumDoorProjectionDistance,
            "doorWorldPlaneDistance": doorWorldPlaneDistance,
            "doorSegmentParameters": doorParameters,
            "northwestKeyOriginWorld": [keyOrigin.x, keyOrigin.y, keyOrigin.z],
            "southeastShadowVectorSource": shadow,
            "pass": true,
        ]
    )
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

func luminanceMetrics(
    _ image: CGImage,
    region: CGRect? = nil
) throws -> [String: Any] {
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
        throw ClayResetError.failed("cannot decode luminance image")
    }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let bounds: CGRect
    if let region {
        bounds = CGRect(
            x: region.minX,
            y: Double(height) - region.maxY,
            width: region.width,
            height: region.height
        )
    } else {
        bounds = CGRect(x: 0, y: 0, width: width, height: height)
    }
    let minimumX = max(0, Int(bounds.minX.rounded(.down)))
    let maximumX = min(width, Int(bounds.maxX.rounded(.up)))
    let minimumY = max(0, Int(bounds.minY.rounded(.down)))
    let maximumY = min(height, Int(bounds.maxY.rounded(.up)))
    var values: [Int] = []
    for y in minimumY..<maximumY {
        for x in minimumX..<maximumX {
            let index = (y * width + x) * 4
            guard bytes[index + 3] > 0 else { continue }
            let red = Double(bytes[index])
            let green = Double(bytes[index + 1])
            let blue = Double(bytes[index + 2])
            let luminance =
                0.2126 * red + 0.7152 * green + 0.0722 * blue
            values.append(Int(luminance.rounded()))
        }
    }
    guard !values.isEmpty else {
        throw ClayResetError.failed("luminance region is empty")
    }
    values.sort()
    let percentile: (Double) -> Int = { fraction in
        values[min(values.count - 1, Int(Double(values.count - 1) * fraction))]
    }
    return [
        "opaquePixelCount": values.count,
        "median": percentile(0.5),
        "p25": percentile(0.25),
        "p75": percentile(0.75),
        "p95": percentile(0.95),
        "shareAtOrBelow32": Double(values.filter { $0 <= 32 }.count)
            / Double(values.count),
    ]
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
    var failures: [String] = []
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let materialURL = sourceRoot.appendingPathComponent(
        "materials/industrial-l04-turbine-v08-prepixel.json"
    )
    try FileManager.default.createDirectory(
        at: materialURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try writeJSON(materialLibraryJSON(), to: materialURL)
    let materialSHA = try sha256(materialURL)
    let materialFile =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
        + "industrial-l04-turbine-v08-prepixel/materials/"
        + "industrial-l04-turbine-v08-prepixel.json"
    let toolchainFile =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/toolchain/"
        + "toolchain-industrial-l03-source-v01.json"
    let toolchainSHA = try sha256(repository.appendingPathComponent(toolchainFile))
    var descriptorRecords: [[String: Any]] = []
    var descriptorHashes = Set<String>()
    var geometryHashes = Set<String>()
    var generatedGeometryIDs = Set<String>()
    var renderPlans: [DescriptorRenderPlan] = []
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
        guard
            let persistedScene = try JSONSerialization.jsonObject(
                with: descriptorData
            ) as? [String: Any]
        else {
            throw ClayResetError.failed("\(plan.direction) persisted descriptor malformed")
        }
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
            "building": persistedScene["building"]!,
            "registration": persistedScene["registration"]!,
            "facades": persistedScene["facades"]!,
            "entrance": persistedScene["entrance"]!,
            "props": persistedScene["props"]!,
            "occlusionExclusions": persistedScene["occlusionExclusions"]!,
        ]
        let geometrySHA = sha256(try jsonData(geometrySubset))
        renderPlans.append(
            try descriptorRenderPlan(
                persistedScene,
                geometrySHA256: geometrySHA
            )
        )
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
    guard renderPlans.count == 4 else {
        throw ClayResetError.failed("descriptor render plan count is not four")
    }

    let rasters = try renderPlans.map { try render($0, size: sourceSize) }
    let colorImages = try renderPlans.map {
        try renderColor($0, size: sourceSize)
    }
    let semanticResults = try renderPlans.map {
        try semanticVisibility($0, size: sourceSize)
    }
    let semanticImages = semanticResults.map(\.0)
    let semanticMetrics = semanticResults.map(\.1)
    let grayscaleImages = try colorImages.map(grayscale)
    let clayOverlayImages = try zip(colorImages, rasters).map {
        try clayOverlay(color: $0.0, clay: $0.1.image)
    }
    let registrationResults = try zip(colorImages, renderPlans).map {
        try registrationOverlay($0.0, plan: $0.1)
    }
    let registrationImages = registrationResults.map(\.0)
    let registrationMetrics = registrationResults.map(\.1)
    let compactColorImages = try colorImages.map {
        try resize($0, to: compactSize)
    }
    let compactGrayscaleImages = try grayscaleImages.map {
        try resize($0, to: compactSize)
    }
    let sourceImages = try colorImages.map {
        try resize($0, to: CGSize(width: 768, height: 512))
    }
    let sourceSheet = try sheet(
        sourceImages,
        cell: CGSize(width: 768, height: 512)
    )

    let reviewRoot = root.appendingPathComponent("review", isDirectory: true)
    try FileManager.default.createDirectory(
        at: reviewRoot,
        withIntermediateDirectories: true
    )
    let sourceURL = reviewRoot.appendingPathComponent("SOURCE-COLOR-NESW.png")
    let compactURL = reviewRoot.appendingPathComponent(
        "EXACT-192X128-COLOR-NESW.png"
    )
    try writePNG(sourceSheet, to: sourceURL)
    try writePNG(
        try sheet(compactColorImages, cell: compactSize),
        to: compactURL
    )
    let blockSize = CGSize(width: 192, height: 128)
    let neighborhoodSize = CGSize(width: 128, height: 85)
    let citySize = CGSize(width: 96, height: 64)
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
            "FRONTAGE-CONTACT-NESW.png",
            try sheet(
                try registrationImages.map {
                    try resize($0, to: CGSize(width: 768, height: 512))
                },
                cell: CGSize(width: 768, height: 512)
            )
        ),
        (
            "FREIGHT-STAFF-VISIBILITY-NESW.png",
            try sheet(
                try semanticImages.map {
                    try resize($0, to: CGSize(width: 768, height: 512))
                },
                cell: CGSize(width: 768, height: 512)
            )
        ),
        (
            "BLOCK-COLOR-NESW.png",
            try sheet(compactColorImages, cell: blockSize)
        ),
        (
            "BLOCK-GRAYSCALE-NESW.png",
            try sheet(compactGrayscaleImages, cell: blockSize)
        ),
        (
            "NEIGHBORHOOD-COLOR-NESW.png",
            try sheet(
                try colorImages.map { try resize($0, to: neighborhoodSize) },
                cell: neighborhoodSize
            )
        ),
        (
            "NEIGHBORHOOD-GRAYSCALE-NESW.png",
            try sheet(
                try grayscaleImages.map {
                    try resize($0, to: neighborhoodSize)
                },
                cell: neighborhoodSize
            )
        ),
        (
            "CITY-COLOR-NESW.png",
            try sheet(
                try colorImages.map { try resize($0, to: citySize) },
                cell: citySize
            )
        ),
        (
            "CITY-GRAYSCALE-NESW.png",
            try sheet(
                try grayscaleImages.map { try resize($0, to: citySize) },
                cell: citySize
            )
        ),
        (
            "EXACT-192X128-GRAYSCALE-NESW.png",
            try sheet(compactGrayscaleImages, cell: compactSize)
        ),
    ]
    for (name, image) in reviewOutputs {
        try writePNG(image, to: reviewRoot.appendingPathComponent(name))
    }

    var directionMetrics: [[String: Any]] = []
    var afterLuminance: [[String: Any]] = []
    for (index, renderPlan) in renderPlans.enumerated() {
        let clayPlan = plans[index]
        let raster = rasters[index]
        let clayHallBoxes = clayPlan.boxes.filter { $0.role == "main-hall" }
        let hallHeight = clayHallBoxes.map(\.size.y).max()!
        let hallMinimumX = clayHallBoxes.map {
            $0.center.x - $0.size.x * 0.5
        }.min()!
        let hallMaximumX = clayHallBoxes.map {
            $0.center.x + $0.size.x * 0.5
        }.max()!
        let hallMinimumZ = clayHallBoxes.map {
            $0.center.z - $0.size.z * 0.5
        }.min()!
        let hallMaximumZ = clayHallBoxes.map {
            $0.center.z + $0.size.z * 0.5
        }.max()!
        let roofHeight = clayPlan.boxes.first { $0.role == "roof-peak" }!.size.y
        let acceptedClayVisibleHeight =
            (hallHeight + roofHeight) * pixelsPerWorld
        let acceptedClayHallRatio =
            (
                hallMaximumX - hallMinimumX
                    + hallMaximumZ - hallMinimumZ
            ) / (hallHeight + roofHeight)
        let nonStackTop = clayPlan.boxes.filter { !$0.stack }
            .map { $0.center.y + $0.size.y * 0.5 }.max()!
        let controlHeight =
            clayPlan.boxes.first { $0.role == "control-wing" }!.size.y
        let stackShare =
            Double(raster.stackPixelCount) / Double(raster.silhouettePixelCount)
        let freightPass = raster.freightWidths.allSatisfy { $0 >= 8 }
        let luma = try luminanceMetrics(compactColorImages[index])
        let median = (luma["median"] as! NSNumber).intValue
        let darkShare = (luma["shareAtOrBelow32"] as! NSNumber).doubleValue
        let staffLuma = try luminanceMetrics(
            compactColorImages[index],
            region: raster.staffBoundsCompact.insetBy(dx: -1, dy: -1)
        )
        let registeredPivot = try numberPair(
            renderPlan.registration["groundPivotSource"],
            label: "groundPivotSource"
        )
        let lastOpaqueSourceY = raster.silhouetteBounds.maxY - 1
        let opaqueContactToPivot =
            abs(lastOpaqueSourceY - registeredPivot[1])
        let directionSemanticMetrics = semanticMetrics[index]
        if acceptedClayHallRatio < 3.4 {
            failures.append("\(renderPlan.direction): accepted clay hall ratio")
        }
        if nonStackTop > 42 {
            failures.append("\(renderPlan.direction): non-stack top \(nonStackTop)")
        }
        if stackShare > 0.08 {
            failures.append("\(renderPlan.direction): stack share \(stackShare)")
        }
        if raster.peakCount < 4 {
            failures.append("\(renderPlan.direction): roof peaks \(raster.peakCount)")
        }
        if controlHeight / hallHeight > 0.55 {
            failures.append(
                "\(renderPlan.direction): control/hall \(controlHeight / hallHeight)"
            )
        }
        if !freightPass {
            failures.append(
                "\(renderPlan.direction): freight width \(raster.freightWidths)"
            )
        }
        if median < 64 {
            failures.append("\(renderPlan.direction): compact median \(median)")
        }
        if darkShare > 0.10 {
            failures.append(
                "\(renderPlan.direction): compact dark share \(darkShare)"
            )
        }
        if raster.staffBoundsCompact.width < 2
            || raster.staffBoundsCompact.height < 4
        {
            failures.append(
                "\(renderPlan.direction): staff entry compact bounds "
                    + "\(raster.staffBoundsCompact)"
            )
        }
        if opaqueContactToPivot > 1 {
            failures.append(
                "\(renderPlan.direction): opaque contact to pivot "
                    + "\(opaqueContactToPivot)"
            )
        }
        if directionSemanticMetrics.contains(where: {
            ($0["pass"] as? Bool) != true
        }) {
            failures.append(
                "\(renderPlan.direction): freight/staff semantic visibility"
            )
        }
        directionMetrics.append([
            "direction": renderPlan.direction,
            "geometryID": renderPlan.geometryID,
            "proofInput": "persisted descriptor geometry and camera",
            "descriptorGeometrySHA256": renderPlan.descriptorGeometrySHA256,
            "renderGeometrySHA256": renderPlan.renderGeometrySHA256,
            "hallProjectedWidthPixels": raster.hallBounds.width,
            "hallVisibleHeightPixels": acceptedClayVisibleHeight,
            "acceptedClayHallWidthToVisibleHeight": acceptedClayHallRatio,
            "descriptorProjectedHallBoundingBoxHeightPixels":
                raster.hallBounds.height,
            "nonStackMaximumWorldY": nonStackTop,
            "stackSilhouetteAreaShareUpperBound": stackShare,
            "roofPeakCount": raster.peakCount,
            "controlWingToHallHeight": controlHeight / hallHeight,
            "freightOpeningCompactWidthsPixels": raster.freightWidths,
            "freightOpeningPass": freightPass,
            "staffEntryBoundsCompact": [
                raster.staffBoundsCompact.minX,
                raster.staffBoundsCompact.minY,
                raster.staffBoundsCompact.width,
                raster.staffBoundsCompact.height,
            ],
            "staffEntryLuminance": staffLuma,
            "freightStaffVisiblePixels": directionSemanticMetrics,
            "lastOpaqueSourceY": lastOpaqueSourceY,
            "opaqueContactToPivotPixels": opaqueContactToPivot,
            "silhouetteBoundsSource": [
                raster.silhouetteBounds.minX,
                raster.silhouetteBounds.minY,
                raster.silhouetteBounds.width,
                raster.silhouetteBounds.height,
            ],
        ])
        afterLuminance.append([
            "direction": renderPlan.direction,
            "exact192x128": luma,
        ])
    }
    let beforeAfterLuminance: [String: Any] = [
        "beforeCandidate": "104027f29fce44fb734c010625a4f8f8fc509c2c",
        "beforeAuthorityMeasurements": [
            ["direction": "N", "median": 34, "shareAtOrBelow32": 0.15],
            ["direction": "E", "median": 51, "shareAtOrBelow32": 0.15],
            ["direction": "S", "median": 51, "shareAtOrBelow32": 0.15],
            ["direction": "W", "median": 51, "shareAtOrBelow32": 0.15],
        ],
        "after": afterLuminance,
        "minimumAfterMedian": 64,
        "maximumAfterShareAtOrBelow32": 0.10,
    ]
    try writeJSON(
        beforeAfterLuminance,
        to: root.appendingPathComponent("LUMINANCE-BEFORE-AFTER.json")
    )
    try writeJSON(
        [
            "taskID": "PLAY-027",
            "artifact": "Turbine v08 descriptor-derived registration",
            "directions": registrationMetrics,
            "sourceAuthority": false,
            "productionSelected": false,
        ],
        to: root.appendingPathComponent("REGISTRATION-ASSERTIONS.json")
    )

    var catalogDescriptorHashes = Set<String>()
    var catalogGeometryIDs = Set<String>()
    let catalogRoots = [
        repository.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof"
        ),
        repository.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l04"
        ),
    ]
    for catalogRoot in catalogRoots {
        if let enumerator = FileManager.default.enumerator(
            at: catalogRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let file as URL in enumerator
            where
                file.lastPathComponent == "scene.json"
                && !file.path.contains("industrial-l04-turbine-v08-prepixel")
            {
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
        "artifact": "Industrial L4 Turbine Works v08 descriptor-bound material and registration pre-pixel",
        "authorityCommit": "3c160e21a917adffd4bf148351a1657184154669",
        "acceptedClayCommit": "90f3c0e8d3c6eab62de2487b84ebf211a2403cd6",
        "rejectedProofCandidate": "104027f29fce44fb734c010625a4f8f8fc509c2c",
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
        "registrationAssertions": registrationMetrics,
        "luminanceBeforeAfter": beforeAfterLuminance,
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
