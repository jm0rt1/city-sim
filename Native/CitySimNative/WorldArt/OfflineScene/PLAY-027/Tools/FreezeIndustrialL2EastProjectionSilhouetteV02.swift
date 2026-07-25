import CryptoKit
import Foundation

enum ProjectionSilhouetteFreezeError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: freeze-industrial-l2-east-projection-silhouette-v02 --repository-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private let frozenDescriptorSHA256 =
    "2af1e6488ea5ff8e799bf44482d4061b1efa1a190a360a34a4bdef0dc6d849c2"
private let frozenMaterialSHA256 =
    "4ca54f2c10c9cc89d9432d2ac921e8cfb7ac88f14141e5446e9657b6533132d9"
private let frozenMetricsSHA256 =
    "d06995080e99ae587b378eac70926433693b712d6af52f0f8e828667761f941d"
private let correctedOrthographicScale = 79.1959533691406
private let sourcePixelsPerCameraWorld = 1024.0 / (2 * correctedOrthographicScale)
private let native2xScale = 144.0 / 512.0

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count
    else { throw ProjectionSilhouetteFreezeError.arguments }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

private func object(_ url: URL) throws -> [String: Any] {
    guard let value = try JSONSerialization.jsonObject(
        with: Data(contentsOf: url)
    ) as? [String: Any] else {
        throw ProjectionSilhouetteFreezeError.invalid(
            "could not decode \(url.path)"
        )
    }
    return value
}

private func writeJSON(_ value: Any, to url: URL) throws {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}

private func relative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

private func block(
    _ id: String,
    _ dimensions: [Double],
    _ position: [Double],
    _ materialID: String,
    _ role: String,
    identityBearing: Bool = true
) -> [String: Any] {
    [
        "id": id,
        "dimensions": dimensions,
        "positionWorld": position,
        "materialID": materialID,
        "presentationRole": role,
        "identityBearing": identityBearing,
    ]
}

private func prop(
    _ id: String,
    _ kind: String,
    _ dimensions: [Double],
    _ position: [Double],
    _ materialID: String,
    _ role: String,
    identityBearing: Bool = true
) -> [String: Any] {
    [
        "id": id,
        "kind": kind,
        "dimensions": dimensions,
        "positionWorld": position,
        "materialID": materialID,
        "presentationRole": role,
        "identityBearing": identityBearing,
    ]
}

private func material(
    _ id: String,
    _ color: [Double],
    _ targetBin: Int,
    _ role: String,
    _ pattern: String,
    roughness: Double,
    metalness: Double
) -> [String: Any] {
    [
        "id": id,
        "baseColorRGBA": color,
        "targetPostLightStep32Bin": targetBin,
        "valueRole": role,
        "pattern": pattern,
        "physicalScaleWorld": [8.0, 8.0],
        "roughness": roughness,
        "metalness": metalness,
        "textureMapping": [
            "mode": "world-scale-box-face-repeat-v1",
            "wrapS": "repeat",
            "wrapT": "repeat",
            "minificationFilter": "linear",
            "magnificationFilter": "linear",
            "mipFilter": "linear",
        ],
    ]
}

private let massBlocks: [[String: Any]] = [
    block(
        "v02-main-production-hall",
        [44, 24, 41],
        [-3, 14.4, -3.5],
        "v02-formed-concrete",
        "broad forty-eight-unit production hall"
    ),
    block(
        "v02-loading-spine",
        [5, 21, 42],
        [22.5, 12.9, -4],
        "v02-painted-steel",
        "long East road-facing logistics spine"
    ),
    block(
        "v02-administration-wing",
        [16, 17, 8],
        [18, 10.9, 22],
        "v02-warm-concrete",
        "separate eighteen-unit administration wing"
    ),
    block(
        "v02-process-base",
        [15, 18, 10],
        [-17, 11.4, 23],
        "v02-painted-steel",
        "secondary process base"
    ),
    block(
        "v02-process-monitor",
        [11, 6, 8],
        [-17, 23.7, 23],
        "v02-galvanized",
        "secondary process monitor below twenty-six-unit height"
    ),
    block(
        "v02-dock-throat-a",
        [2, 14, 11],
        [25.4, 10.4, -18],
        "v02-deep-recess",
        "deep grounded loading throat A"
    ),
    block(
        "v02-dock-throat-b",
        [2, 14, 11],
        [25.4, 10.4, -3],
        "v02-deep-recess",
        "deep grounded loading throat B"
    ),
    block(
        "v02-dock-throat-c",
        [2, 14, 11],
        [25.4, 10.4, 12],
        "v02-deep-recess",
        "deep grounded loading throat C"
    ),
    block(
        "v02-dock-door-a",
        [1, 12, 10.5],
        [26.6, 10, -18],
        "v02-loading-door",
        "eleven-unit loading door A"
    ),
    block(
        "v02-dock-door-b",
        [1, 12, 10.5],
        [26.6, 10, -3],
        "v02-loading-door",
        "eleven-unit loading door B"
    ),
    block(
        "v02-dock-door-c",
        [1, 12, 10.5],
        [26.6, 10, 12],
        "v02-loading-door",
        "eleven-unit loading door C"
    ),
    block(
        "v02-dock-canopy-a",
        [6, 3, 12],
        [25, 18.9, -18],
        "v02-structural-trim",
        "deep dock canopy A"
    ),
    block(
        "v02-dock-canopy-b",
        [6, 3, 12],
        [25, 18.9, -3],
        "v02-structural-trim",
        "deep dock canopy B"
    ),
    block(
        "v02-dock-canopy-c",
        [6, 3, 12],
        [25, 18.9, 12],
        "v02-structural-trim",
        "deep dock canopy C"
    ),
    block(
        "v02-dock-header",
        [3, 4.5, 42],
        [23.5, 22.75, -4],
        "v02-galvanized",
        "continuous logistics header"
    ),
    block(
        "v02-loading-apron",
        [5.5, 2.2, 48],
        [25.25, 1.1, -1],
        "v02-neutral-apron",
        "grounded East service apron"
    ),
    block(
        "v02-personnel-recess",
        [1, 10, 6],
        [25.6, 8, 22],
        "v02-deep-recess",
        "staff-scale entrance recess"
    ),
    block(
        "v02-personnel-door",
        [0.8, 8, 5.5],
        [26.2, 7, 22],
        "v02-warm-glazing",
        "staff-scale entrance"
    ),
    block(
        "v02-personnel-canopy",
        [4, 2.5, 7],
        [26, 13.5, 22],
        "v02-safety-trim",
        "personnel entrance canopy"
    ),
    block(
        "v02-admin-glazing",
        [1, 6, 13],
        [26.2, 12.5, 17],
        "v02-industrial-glazing",
        "administration glazing band"
    ),
    block(
        "v02-hall-roof",
        [45.5, 2.5, 42.5],
        [-3, 27.65, -3.5],
        "v02-roof-membrane",
        "single broad low production roof"
    ),
    block(
        "v02-admin-roof",
        [17.5, 2.5, 9.5],
        [18, 20.65, 22],
        "v02-roof-membrane",
        "distinct administration roof"
    ),
    block(
        "v02-loading-roof",
        [6.5, 2.5, 43],
        [22.5, 24.65, -4],
        "v02-roof-membrane",
        "low loading-spine roof"
    ),
    block(
        "v02-hall-clerestory",
        [18, 5, 6],
        [-6, 31.4, -6],
        "v02-industrial-glazing",
        "large readable clerestory"
    ),
    block(
        "v02-hvac-bank",
        [12, 5, 8],
        [3, 31.4, 9],
        "v02-galvanized",
        "readable roof service bank"
    ),
    block(
        "v02-hazard-header",
        [2, 5, 42],
        [27, 23, -4],
        "v02-safety-trim",
        "continuous road-facing hazard hierarchy"
    ),
]

private let props: [[String: Any]] = [
    prop(
        "v02-process-tank",
        "explicit-cylinder",
        [10, 22, 10],
        [-17, 13.4, 23],
        "v02-oxide-process",
        "secondary horizontal-scale process vessel"
    ),
    prop(
        "v02-bollard-north",
        "explicit-cylinder",
        [4.5, 5, 4.5],
        [25.5, 3.7, -25],
        "v02-safety-trim",
        "north apron protection"
    ),
    prop(
        "v02-bollard-south",
        "explicit-cylinder",
        [4.5, 5, 4.5],
        [25.5, 3.7, 18.5],
        "v02-safety-trim",
        "south apron protection"
    ),
    prop(
        "v02-personnel-bollard",
        "explicit-cylinder",
        [4.5, 5, 4.5],
        [25.5, 3.7, 25],
        "v02-safety-trim",
        "personnel route protection"
    ),
]

private let materials: [[String: Any]] = [
    material("v02-deep-recess", [0.31, 0.32, 0.34, 1], 80, "recess", "solid-depth-cavity", roughness: 0.96, metalness: 0),
    material("v02-roof-membrane", [0.40, 0.42, 0.44, 1], 96, "roof", "rolled-membrane-seams", roughness: 0.94, metalness: 0),
    material("v02-loading-door", [0.48, 0.51, 0.54, 1], 128, "load-bay", "horizontal-section-joints", roughness: 0.78, metalness: 0.16),
    material("v02-painted-steel", [0.56, 0.62, 0.66, 1], 160, "steel", "procedural-wide-corrugation", roughness: 0.75, metalness: 0.24),
    material("v02-formed-concrete", [0.70, 0.68, 0.62, 1], 176, "concrete", "procedural-large-formed-panels", roughness: 0.95, metalness: 0),
    material("v02-neutral-apron", [0.62, 0.62, 0.58, 1], 160, "apron", "large-scored-slabs", roughness: 0.98, metalness: 0),
    material("v02-warm-concrete", [0.78, 0.72, 0.61, 1], 192, "administration", "procedural-large-formed-panels", roughness: 0.92, metalness: 0),
    material("v02-industrial-glazing", [0.30, 0.52, 0.66, 1], 128, "glazing", "broad-mullion-grid", roughness: 0.40, metalness: 0.08),
    material("v02-galvanized", [0.72, 0.76, 0.77, 1], 192, "service", "procedural-wide-corrugation", roughness: 0.67, metalness: 0.56),
    material("v02-structural-trim", [0.84, 0.83, 0.76, 1], 224, "trim", "painted-steel", roughness: 0.66, metalness: 0.42),
    material("v02-oxide-process", [0.63, 0.39, 0.25, 1], 128, "process", "restrained-oxide", roughness: 0.79, metalness: 0.44),
    material("v02-warm-glazing", [0.92, 0.73, 0.40, 1], 192, "staff-entrance", "muted-warm-glazing", roughness: 0.35, metalness: 0.06),
    material("v02-safety-trim", [0.98, 0.82, 0.25, 1], 224, "safety", "painted-safety-steel", roughness: 0.62, metalness: 0.32),
]

@main
enum FreezeIndustrialL2EastProjectionSilhouetteV02Main {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try argument("--repository-root", in: arguments)
        ).standardizedFileURL
        let frozenRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-raster-survival-v01"
        )
        let frozenSceneURL = frozenRoot.appendingPathComponent(
            "scenes/industrial_l02/variant-0/east/scene.json"
        )
        let frozenMaterialURL = frozenRoot.appendingPathComponent(
            "materials/industrial-l02-raster-survival-art-proof-v01.json"
        )
        let frozenMetricsURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/raster-survival-art-proof-v01/proof/review/RASTER-SURVIVAL-METRICS.json"
        )
        guard
            try sha256(frozenSceneURL) == frozenDescriptorSHA256,
            try sha256(frozenMaterialURL) == frozenMaterialSHA256,
            try sha256(frozenMetricsURL) == frozenMetricsSHA256
        else {
            throw ProjectionSilhouetteFreezeError.invalid(
                "frozen 920af3b/3794912 descriptor, materials, or rejection metrics drift"
            )
        }

        let outputRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02"
        )
        let sceneURL = outputRoot.appendingPathComponent(
            "scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialURL = outputRoot.appendingPathComponent(
            "materials/industrial-l02-projection-silhouette-reset-v02.json"
        )
        let evidenceRoot = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v02/prepixel"
        )

        var scene = try object(frozenSceneURL)
        guard
            var building = scene["building"] as? [String: Any],
            var camera = scene["camera"] as? [String: Any],
            var sampling = scene["sampling"] as? [String: Any],
            var entrance = scene["entrance"] as? [String: Any],
            var facades = scene["facades"] as? [[String: Any]]
        else {
            throw ProjectionSilhouetteFreezeError.invalid(
                "frozen descriptor does not contain the required contracts"
            )
        }

        let materialLibrary: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "libraryID": "industrial-l02-projection-silhouette-reset-v02",
            "source":
                "offline-only numerical role/value reset; no ImageGen and no raster swatch",
            "imageGenMaterialSwatchesUsed": false,
            "colorSpace": "extended-sRGB",
            "materials": materials,
            "predeclaredDistributionTargets": [
                "p25Minimum": 80,
                "p75MinusP25Minimum": 48,
                "p95Minimum": 192,
                "minimumOccupiedStep32Bins": 5,
                "maximumSingleMajorFacadeBinShare": 0.35,
                "majorFacadeBinAllocation": [
                    ["step32Bin": 80, "share": 0.18, "roles": ["recess"]],
                    ["step32Bin": 128, "share": 0.20, "roles": ["load-bay", "glazing", "process"]],
                    ["step32Bin": 160, "share": 0.31, "roles": ["steel", "apron"]],
                    ["step32Bin": 176, "share": 0.22, "roles": ["concrete"]],
                    ["step32Bin": 192, "share": 0.05, "roles": ["administration", "service", "staff-entrance"]],
                    ["step32Bin": 224, "share": 0.04, "roles": ["trim", "safety"]],
                ],
                "authority": "later-pixel-rejection-target-not-a-prepixel-pass-claim",
            ],
            "productionSelected": false,
        ]
        try writeJSON(materialLibrary, to: materialURL)

        camera["orthographicScale"] = correctedOrthographicScale
        sampling["purpose"] = "diagnostic-regression"
        sampling["sourceRevisionBinding"] =
            "projection-silhouette-reset-art-proof-v02"
        sampling["sceneKitAntialiasing"] = "none"
        sampling["sceneKitLightingMode"] = "lambert-scene-lights"
        sampling["sceneKitShadows"] = "current"
        sampling.removeValue(forKey: "preLanczosCanonicalizer")

        building["massingProfile"] =
            "industrial-l02-east-wide-low-campus-v02"
        building["massBlocks"] = massBlocks
        building["wallHeight"] = 32.65
        building["roofHeight"] = 2.5
        building["roofMaterialID"] = "v02-roof-membrane"
        building["wallMaterialID"] = "v02-formed-concrete"
        building["trimMaterialID"] = "v02-structural-trim"
        building["foundationMaterialID"] = "v02-formed-concrete"
        building["foundationDimensions"] = [56.0, 2.4, 56.0]
        building["foundationPositionWorld"] = [0.0, 1.2, 0.0]
        building["chimney"] = [
            "dimensions": [1.0, 1.0, 1.0],
            "positionWorld": [0.0, 1.0, 0.0],
            "materialID": "v02-galvanized",
        ]

        entrance["doorMaterialID"] = "v02-loading-door"
        entrance["surroundMaterialID"] = "v02-structural-trim"
        entrance["pavilionMaterialID"] = "v02-painted-steel"
        entrance["width"] = 43.0
        entrance["height"] = 14.0
        entrance["canopyDepth"] = 9.0
        for index in facades.indices {
            facades[index]["materialID"] =
                facades[index]["direction"] as? String == "east"
                ? "v02-painted-steel"
                : "v02-formed-concrete"
            facades[index]["windowBays"] = []
            facades[index]["windowRhythms"] = []
        }

        scene["sceneGeometryID"] =
            "industrial-l02-east-wide-low-campus-geometry-v02"
        scene["sourceRevision"] = "projection-silhouette-reset-art-proof-v02"
        scene["productionSelected"] = false
        scene["camera"] = camera
        scene["sampling"] = sampling
        scene["building"] = building
        scene["entrance"] = entrance
        scene["facades"] = facades
        scene["props"] = props
        scene["materialLibrary"] = [
            "role":
                "industrial-l02-east-wide-low-campus-offline-only-material-roles",
            "file": relative(materialURL, root: root),
            "sha256": try sha256(materialURL),
        ]
        scene["occlusionExclusions"] = [[
            "id": "east-wide-campus-loading-clearance-v02",
            "purpose":
                "protect three eleven-unit grounded dock throats, canopies, apron, and personnel route at the exact East socket",
            "polygonWorld": [
                [18.0, -28.0],
                [28.0, -28.0],
                [28.0, 28.0],
                [18.0, 28.0],
            ],
        ]]
        try writeJSON(scene, to: sceneURL)

        let alphaContract: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-proof-only-pre-chroma-alpha-v02",
            "authority": "future-review-presentation-only-never-governed-raw",
            "captureBoundary":
                "CIImage returned by SCNRenderer.snapshot after fixed 4x downsample and before the compositor creates or fills the magenta canvas",
            "alphaTruth": "SceneKit RGBA alpha channel from that pre-chroma image",
            "authoredShadow":
                "draw the existing registration.contactPolygonWorld and frozen southeast shadow into a transparent RGBA context, then source-over the pre-chroma SceneKit RGBA",
            "neutralCompositeRGBA": [224, 226, 220, 255],
            "colorClassification": "forbidden",
            "postHocMagentaGuess": false,
            "governedRawMutation": false,
            "mathematicalGuarantee":
                "the proof context is initialized transparent and receives no magenta fill; therefore an output pixel can contain magenta only if the pre-chroma building itself emits magenta, which is a fail-closed material violation",
            "requiredChecks": [
                "zero exact or near-magenta opaque pixels",
                "zero residual magenta-family pixels",
                "alpha bounds preserve the pre-chroma building plus authored shadow union",
                "pivot, socket, contact polygon, and shadow vector remain exact",
            ],
            "productionSelected": false,
        ]
        try writeJSON(
            alphaContract,
            to: evidenceRoot.appendingPathComponent(
                "PRECHROMA-ALPHA-NEUTRAL-CONTRACT.json"
            )
        )

        let presentationContract: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-projection-silhouette-reset-v02",
            "authority": "prepixel-only-no-render-process",
            "immutableEvidence": [
                "prepixelCommit":
                    "920af3b8730a556c564daa56d9a0c9a4d451cf18",
                "rejectionCommit":
                    "3794912daa96e9b6c92d1baa5f56ae7888ab0d1c",
                "frozenDescriptorSHA256": frozenDescriptorSHA256,
                "frozenMaterialSHA256": frozenMaterialSHA256,
                "frozenMetricsSHA256": frozenMetricsSHA256,
            ],
            "descriptorFile": relative(sceneURL, root: root),
            "descriptorSHA256": try sha256(sceneURL),
            "materialLibraryFile": relative(materialURL, root: root),
            "materialLibrarySHA256": try sha256(materialURL),
            "geometryTargets": [
                "footprintUnits": [56, 56],
                "projectedRegistrationDiamondSource": [512, 256],
                "minimumBuildingProjectedWidthSource": 420,
                "minimumBuildingProjectedWidthNative2x": 118,
                "minimumProjectedFootprintWidthShare": 0.82,
                "mainHallLongDimensionWorld": [42, 48],
                "administrationLongDimensionWorld": [14, 20],
                "maximumProcessElementHeightWorld": 26,
                "dockCount": 3,
                "minimumDockWidthWorldExclusive": 10,
                "minimumIdentityFeatureNative2xPixels": 6,
                "forbiddenSilhouette": [
                    "vertical-stack",
                    "stacked-roof-pancakes",
                    "dominant-chimney-tower",
                ],
            ],
            "valueTargets": [
                "p25Minimum": 80,
                "p75MinusP25Minimum": 48,
                "p95Minimum": 192,
                "minimumOccupiedStep32Bins": 5,
                "maximumSingleMajorFacadeBinShare": 0.35,
                "predeclaredMajorFacadeBinAllocation": [
                    ["step32Bin": 80, "share": 0.18],
                    ["step32Bin": 128, "share": 0.20],
                    ["step32Bin": 160, "share": 0.31],
                    ["step32Bin": 176, "share": 0.22],
                    ["step32Bin": 192, "share": 0.05],
                    ["step32Bin": 224, "share": 0.04],
                ],
                "disposition":
                    "binding rejection targets for a later authorized pixel proof",
            ],
            "rawRenderProcessesConsumed": 0,
            "productionSelected": false,
        ]
        try writeJSON(
            presentationContract,
            to: evidenceRoot.appendingPathComponent(
                "PRESENTATION-CONTRACT.json"
            )
        )

        let markdown = """
        # PLAY-027 Industrial L2 East projection and silhouette reset v02

        Status: frozen pre-pixel only. `productionSelected` is false and no Metal render process is authorized or consumed.

        The exact SceneKit calibration corrects the prior factor-of-two error: vertical `orthographicScale` is a half-span, so `79.1959533691406` maps the frozen 56×56 footprint to 512×256. The separately observed 410-pixel plate is compositor-owned: the 56-unit contact polygon is drawn against the 72-unit tile basis (398.2222 pixels), then blur/raster support expands it to 410. It is not a camera utilization measurement.

        The new East scene is a wide, low campus: a 48-unit production hall, 18-unit administration wing, long loading spine, and secondary process/tank group whose vertical element is capped at 26 units. Three 11-unit loading throats and doors have four-unit separations, deep canopies, a grounded apron, and a separate staff entrance. Identity is carried by large volumes and recesses; stacked roofs and a dominant chimney are forbidden.

        The later pixel gate must reject unless building-only projected width is at least 420 source pixels and 118 native-2x pixels, every identity cue survives at six native-2x pixels or larger, and the post-step-32 occupied distribution reaches p25 80, interquartile span 48, p95 192, five occupied bins, with no major facade bin above 35 percent.

        Neutral review must use genuine pre-chroma SceneKit RGBA alpha. A transparent review context receives the frozen authored shadow and then the pre-chroma building. It never introduces magenta and never mutates the governed flat-chroma raw/source contract. Color-family guessing is forbidden.
        """
        try (markdown + "\n").write(
            to: evidenceRoot.appendingPathComponent(
                "PRESENTATION-CONTRACT.md"
            ),
            atomically: true,
            encoding: .utf8
        )

        print("descriptor \(try sha256(sceneURL))")
        print("materials \(try sha256(materialURL))")
        print("orthographicScale \(correctedOrthographicScale)")
        print("rawRenderProcessesConsumed=0 productionSelected=false")
    }
}
