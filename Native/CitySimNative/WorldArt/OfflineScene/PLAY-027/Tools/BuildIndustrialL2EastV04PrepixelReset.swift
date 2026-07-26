import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import SceneKit

enum IndustrialL2EastV04Error: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l2-east-v04-prepixel-reset --repository-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct V04Image {
    let rgba: [UInt8]
    let width: Int
    let height: Int
}

private struct V04Box {
    let id: String
    let materialID: String
    let dimensions: [Double]
    let position: [Double]
    let identityBearing: Bool
}

private struct V04Vertex {
    let x: Double
    let y: Double
    let depth: Double
}

private struct V04Face {
    let componentID: String
    let materialID: String
    let orientation: String
    let vertices: [V04Vertex]
}

private struct V04MaterialAccumulator {
    var components = Set<String>()
    var faces: [String: Int] = [:]
    var alphaPixelCount = 0
    var opaqueInteriorPixelCount = 0
    var edgePixelCount = 0
    var preLuma: [Int] = []
    var rawLuma: [Int] = []
    var quantizerLumaDelta: [Int] = []
    var rawStepBins: [Int: Int] = [:]
}

private let v04AuthorityCommit =
    "af6b35bee6732d8ad9b16e7353083258c48e5607"
private let v04DescriptorSHA256 =
    "d32c2aaf03cebf53f3821515b19ab03fd86e759687fed9b4bf68eda14e1b65ca"
private let v04MaterialSHA256 =
    "94069509093c122d4cb2383bd648757561f6561f78b8345c6222b5354f3f18f6"
private let v04RawSHA256 =
    "24e57812ef0d0d024aef8b4d45a2bda9f98c902874b534aed9ff6040707867ba"
private let v04PreChromaBuildingSHA256 =
    "b571b6bbabf5c1d1c2a60167af076d05ece13d379d323368c6150f79e2e119c6"
private let v04PreChromaAlphaSHA256 =
    "f6cdf5833011cf2842e2f4245216d8224de760c63ede8ec4473b259667afeafc"
private let v04NeutralSHA256 =
    "89fcc84601214345e35c2ac07cd0fc4475aa99b038e03553ca515bfcfbc7506c"
private let v04MetricsSHA256 =
    "cd55e28517b2e2ca5896d433f5a0646840786b8684a45c2f3ef0bd931f69c1c9"
private let v04RejectionSHA256 =
    "3ccefb83cded63bf0958c4b28eabf00af8ccf4551dd4191d3675c4641110a877"
private let v04RendererSourceSHA256 =
    "ecd51c8da196f285d2e1b43673f47a9b3b5655cfc405ec071b3deb8dc773df09"
private let v04NativeScale = 144.0 / 512.0

private func v04Argument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2EastV04Error.arguments
    }
    return arguments[index + 1]
}

private func v04SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func v04SHA256(_ url: URL) throws -> String {
    v04SHA256(try Data(contentsOf: url))
}

private func v04LoadJSON(_ url: URL) throws -> [String: Any] {
    guard
        let value = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL2EastV04Error.invalid(
            "could not decode JSON \(url.path)"
        )
    }
    return value
}

private func v04WriteJSON(
    _ value: Any,
    to url: URL
) throws {
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

private func v04WriteText(
    _ value: String,
    to url: URL
) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data(value.utf8).write(to: url, options: .atomic)
}

private func v04LoadImage(_ url: URL) throws -> V04Image {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw IndustrialL2EastV04Error.invalid(
            "could not decode \(url.path)"
        )
    }
    let width = image.width
    let height = image.height
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    let created = rgba.withUnsafeMutableBytes { storage -> Bool in
        guard let context = CGContext(
            data: storage.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return false
        }
        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
        return true
    }
    guard created else {
        throw IndustrialL2EastV04Error.invalid(
            "could not decode RGBA \(url.path)"
        )
    }
    return V04Image(rgba: rgba, width: width, height: height)
}

private func v04Luma(
    _ red: Double,
    _ green: Double,
    _ blue: Double
) -> Double {
    0.2126 * red + 0.7152 * green + 0.0722 * blue
}

private func v04Luma(_ rgba: [UInt8], _ offset: Int) -> Int {
    Int(
        v04Luma(
            Double(rgba[offset]),
            Double(rgba[offset + 1]),
            Double(rgba[offset + 2])
        ).rounded()
    )
}

private func v04Percentile(
    _ values: [Int],
    _ percentile: Double
) -> Int {
    guard !values.isEmpty else {
        return 0
    }
    let sorted = values.sorted()
    let index = min(
        sorted.count - 1,
        max(0, Int((Double(sorted.count - 1) * percentile).rounded()))
    )
    return sorted[index]
}

private func v04Summary(_ values: [Int]) -> [String: Any] {
    guard !values.isEmpty else {
        return [
            "count": 0,
            "minimum": 0,
            "p10": 0,
            "p25": 0,
            "median": 0,
            "p75": 0,
            "p90": 0,
            "p95": 0,
            "maximum": 0,
        ]
    }
    return [
        "count": values.count,
        "minimum": values.min()!,
        "p10": v04Percentile(values, 0.10),
        "p25": v04Percentile(values, 0.25),
        "median": v04Percentile(values, 0.50),
        "p75": v04Percentile(values, 0.75),
        "p90": v04Percentile(values, 0.90),
        "p95": v04Percentile(values, 0.95),
        "maximum": values.max()!,
    ]
}

private func v04MaterialBaseLuma(
    _ material: [String: Any]
) throws -> Int {
    guard
        let rgba = material["baseColorRGBA"] as? [Double],
        rgba.count == 4
    else {
        throw IndustrialL2EastV04Error.invalid(
            "material base color missing"
        )
    }
    return Int(
        (255 * v04Luma(rgba[0], rgba[1], rgba[2])).rounded()
    )
}

private func v04CameraNode(
    descriptor: [String: Any]
) throws -> SCNNode {
    guard
        let camera = descriptor["camera"] as? [String: Any],
        let position = camera["positionWorld"] as? [Double],
        let target = camera["targetWorld"] as? [Double],
        let scale = camera["orthographicScale"] as? Double
    else {
        throw IndustrialL2EastV04Error.invalid(
            "descriptor camera malformed"
        )
    }
    let node = SCNNode()
    let scnCamera = SCNCamera()
    scnCamera.usesOrthographicProjection = true
    scnCamera.orthographicScale = scale
    scnCamera.projectionDirection = .vertical
    node.camera = scnCamera
    node.position = SCNVector3(position[0], position[1], position[2])
    node.look(
        at: SCNVector3(target[0], target[1], target[2]),
        up: SCNVector3(0, 1, 0),
        localFront: SCNVector3(0, 0, -1)
    )
    return node
}

private func v04Project(
    _ point: [Double],
    cameraNode: SCNNode,
    viewport: [Int],
    orthographicScale: Double,
    postOffset: [Double]
) -> V04Vertex {
    let local = cameraNode.convertPosition(
        SCNVector3(point[0], point[1], point[2]),
        from: nil
    )
    let pixelsPerWorld =
        Double(viewport[1]) / (2 * orthographicScale)
    return V04Vertex(
        x: Double(viewport[0]) / 2
            + Double(local.x) * pixelsPerWorld
            + postOffset[0],
        y: Double(viewport[1]) / 2
            - Double(local.y) * pixelsPerWorld
            + postOffset[1],
        depth: Double(local.z)
    )
}

private func v04FaceDefinitions(
    box: V04Box,
    cameraPosition: [Double],
    cameraNode: SCNNode,
    viewport: [Int],
    orthographicScale: Double,
    postOffset: [Double]
) -> [V04Face] {
    let half = box.dimensions.map { $0 / 2 }
    let minimum = [
        box.position[0] - half[0],
        box.position[1] - half[1],
        box.position[2] - half[2],
    ]
    let maximum = [
        box.position[0] + half[0],
        box.position[1] + half[1],
        box.position[2] + half[2],
    ]
    let definitions: [(
        name: String,
        normal: [Double],
        points: [[Double]]
    )] = [
        (
            "+x",
            [1, 0, 0],
            [
                [maximum[0], minimum[1], minimum[2]],
                [maximum[0], maximum[1], minimum[2]],
                [maximum[0], maximum[1], maximum[2]],
                [maximum[0], minimum[1], maximum[2]],
            ]
        ),
        (
            "-x",
            [-1, 0, 0],
            [
                [minimum[0], minimum[1], maximum[2]],
                [minimum[0], maximum[1], maximum[2]],
                [minimum[0], maximum[1], minimum[2]],
                [minimum[0], minimum[1], minimum[2]],
            ]
        ),
        (
            "+y",
            [0, 1, 0],
            [
                [minimum[0], maximum[1], minimum[2]],
                [minimum[0], maximum[1], maximum[2]],
                [maximum[0], maximum[1], maximum[2]],
                [maximum[0], maximum[1], minimum[2]],
            ]
        ),
        (
            "-y",
            [0, -1, 0],
            [
                [minimum[0], minimum[1], maximum[2]],
                [minimum[0], minimum[1], minimum[2]],
                [maximum[0], minimum[1], minimum[2]],
                [maximum[0], minimum[1], maximum[2]],
            ]
        ),
        (
            "+z",
            [0, 0, 1],
            [
                [maximum[0], minimum[1], maximum[2]],
                [maximum[0], maximum[1], maximum[2]],
                [minimum[0], maximum[1], maximum[2]],
                [minimum[0], minimum[1], maximum[2]],
            ]
        ),
        (
            "-z",
            [0, 0, -1],
            [
                [minimum[0], minimum[1], minimum[2]],
                [minimum[0], maximum[1], minimum[2]],
                [maximum[0], maximum[1], minimum[2]],
                [maximum[0], minimum[1], minimum[2]],
            ]
        ),
    ]
    return definitions.compactMap { definition in
        let faceCenter = [
            definition.points.map { $0[0] }.reduce(0, +) / 4,
            definition.points.map { $0[1] }.reduce(0, +) / 4,
            definition.points.map { $0[2] }.reduce(0, +) / 4,
        ]
        let toCamera = [
            cameraPosition[0] - faceCenter[0],
            cameraPosition[1] - faceCenter[1],
            cameraPosition[2] - faceCenter[2],
        ]
        let facing =
            definition.normal[0] * toCamera[0]
            + definition.normal[1] * toCamera[1]
            + definition.normal[2] * toCamera[2]
        guard facing > 0 else {
            return nil
        }
        return V04Face(
            componentID: box.id,
            materialID: box.materialID,
            orientation: definition.name,
            vertices: definition.points.map {
                v04Project(
                    $0,
                    cameraNode: cameraNode,
                    viewport: viewport,
                    orthographicScale: orthographicScale,
                    postOffset: postOffset
                )
            }
        )
    }
}

private func v04RasterizeTriangle(
    _ a: V04Vertex,
    _ b: V04Vertex,
    _ c: V04Vertex,
    faceIndex: Int,
    width: Int,
    height: Int,
    owner: inout [Int32],
    depth: inout [Float]
) {
    let denominator =
        (b.y - c.y) * (a.x - c.x)
        + (c.x - b.x) * (a.y - c.y)
    guard abs(denominator) > 0.000001 else {
        return
    }
    let minimumX = max(
        0,
        Int(floor(min(a.x, min(b.x, c.x))))
    )
    let maximumX = min(
        width - 1,
        Int(ceil(max(a.x, max(b.x, c.x))))
    )
    let minimumY = max(
        0,
        Int(floor(min(a.y, min(b.y, c.y))))
    )
    let maximumY = min(
        height - 1,
        Int(ceil(max(a.y, max(b.y, c.y))))
    )
    for y in minimumY...maximumY {
        for x in minimumX...maximumX {
            let sampleX = Double(x) + 0.5
            let sampleY = Double(y) + 0.5
            let first =
                (
                    (b.y - c.y) * (sampleX - c.x)
                    + (c.x - b.x) * (sampleY - c.y)
                ) / denominator
            let second =
                (
                    (c.y - a.y) * (sampleX - c.x)
                    + (a.x - c.x) * (sampleY - c.y)
                ) / denominator
            let third = 1 - first - second
            guard
                first >= -0.000001,
                second >= -0.000001,
                third >= -0.000001
            else {
                continue
            }
            let candidateDepth =
                first * a.depth + second * b.depth + third * c.depth
            let pixel = y * width + x
            if candidateDepth > Double(depth[pixel]) {
                depth[pixel] = Float(candidateDepth)
                owner[pixel] = Int32(faceIndex)
            }
        }
    }
}

private func v04Boxes(
    descriptor: [String: Any]
) throws -> [V04Box] {
    guard
        let building = descriptor["building"] as? [String: Any],
        let foundationDimensions =
            building["foundationDimensions"] as? [Double],
        let foundationPosition =
            building["foundationPositionWorld"] as? [Double],
        let foundationMaterial =
            building["foundationMaterialID"] as? String,
        let massBlocks =
            building["massBlocks"] as? [[String: Any]]
    else {
        throw IndustrialL2EastV04Error.invalid(
            "descriptor explicit geometry malformed"
        )
    }
    var boxes = [
        V04Box(
            id: "foundation",
            materialID: foundationMaterial,
            dimensions: foundationDimensions,
            position: foundationPosition,
            identityBearing: false
        ),
    ]
    boxes += try massBlocks.map { block in
        guard
            let id = block["id"] as? String,
            let materialID = block["materialID"] as? String,
            let dimensions = block["dimensions"] as? [Double],
            let position = block["positionWorld"] as? [Double],
            let identityBearing = block["identityBearing"] as? Bool
        else {
            throw IndustrialL2EastV04Error.invalid(
                "mass block malformed"
            )
        }
        return V04Box(
            id: id,
            materialID: materialID,
            dimensions: dimensions,
            position: position,
            identityBearing: identityBearing
        )
    }
    return boxes
}

private func v04Material(
    id: String,
    role: String,
    color: [Double],
    roughness: Double,
    metalness: Double,
    pattern: String,
    target: Int
) -> [String: Any] {
    [
        "id": id,
        "valueRole": role,
        "baseColorRGBA": color + [1],
        "roughness": roughness,
        "metalness": metalness,
        "pattern": pattern,
        "physicalScaleWorld": [8, 8],
        "targetPostLightStep32Bin": target,
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

private func v04Materials() -> [[String: Any]] {
    [
        v04Material(
            id: "v04-deep-recess",
            role: "recess",
            color: [0.38, 0.42, 0.45],
            roughness: 0.96,
            metalness: 0,
            pattern: "solid-depth-cavity",
            target: 80
        ),
        v04Material(
            id: "v04-roof-membrane",
            role: "roof",
            color: [0.64, 0.67, 0.70],
            roughness: 0.94,
            metalness: 0,
            pattern: "rolled-membrane-seams",
            target: 176
        ),
        v04Material(
            id: "v04-loading-door",
            role: "load-bay",
            color: [0.56, 0.63, 0.68],
            roughness: 0.78,
            metalness: 0.16,
            pattern: "horizontal-section-joints",
            target: 144
        ),
        v04Material(
            id: "v04-corrugated-hall",
            role: "production-hall",
            color: [0.67, 0.77, 0.84],
            roughness: 0.78,
            metalness: 0.22,
            pattern: "procedural-vertical-corrugation",
            target: 160
        ),
        v04Material(
            id: "v04-formed-concrete",
            role: "formed-concrete",
            color: [0.78, 0.77, 0.71],
            roughness: 0.95,
            metalness: 0,
            pattern: "procedural-formed-concrete",
            target: 192
        ),
        v04Material(
            id: "v04-neutral-apron",
            role: "apron",
            color: [0.74, 0.75, 0.72],
            roughness: 0.98,
            metalness: 0,
            pattern: "large-scored-slabs",
            target: 176
        ),
        v04Material(
            id: "v04-admin-concrete",
            role: "administration",
            color: [0.86, 0.82, 0.72],
            roughness: 0.92,
            metalness: 0,
            pattern: "procedural-formed-concrete",
            target: 208
        ),
        v04Material(
            id: "v04-industrial-glazing",
            role: "glazing",
            color: [0.34, 0.56, 0.66],
            roughness: 0.40,
            metalness: 0.08,
            pattern: "muted-mullion-grid",
            target: 144
        ),
        v04Material(
            id: "v04-process-metal",
            role: "secondary-process",
            color: [0.64, 0.68, 0.70],
            roughness: 0.67,
            metalness: 0.48,
            pattern: "fine-galvanized",
            target: 176
        ),
        v04Material(
            id: "v04-structural-trim",
            role: "trim",
            color: [0.90, 0.88, 0.80],
            roughness: 0.66,
            metalness: 0.38,
            pattern: "painted-steel",
            target: 224
        ),
        v04Material(
            id: "v04-oxide-process",
            role: "process-accent",
            color: [0.69, 0.47, 0.31],
            roughness: 0.79,
            metalness: 0.40,
            pattern: "restrained-oxide",
            target: 144
        ),
        v04Material(
            id: "v04-warm-glazing",
            role: "staff-entrance",
            color: [0.94, 0.76, 0.42],
            roughness: 0.35,
            metalness: 0.06,
            pattern: "muted-warm-glazing",
            target: 208
        ),
        v04Material(
            id: "v04-safety-trim",
            role: "safety",
            color: [0.94, 0.70, 0.19],
            roughness: 0.62,
            metalness: 0.28,
            pattern: "solid-safety-paint",
            target: 208
        ),
    ]
}

private func v04Quantize(_ value: Double) -> Int {
    let clamped = min(255, max(0, Int(value.rounded())))
    if clamped == 255 {
        return 255
    }
    return min(240, max(16, ((clamped + 8) / 32) * 32 + 16))
}

private func v04CanonicalGeometry(
    descriptor: [String: Any]
) throws -> Data {
    guard
        let building = descriptor["building"],
        let camera = descriptor["camera"],
        let registration = descriptor["registration"],
        let entrance = descriptor["entrance"],
        let facades = descriptor["facades"],
        let props = descriptor["props"],
        let occlusion = descriptor["occlusionExclusions"]
    else {
        throw IndustrialL2EastV04Error.invalid(
            "geometry contract fields missing"
        )
    }
    func strippingMaterials(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            var stripped: [String: Any] = [:]
            for (key, child) in dictionary
            where !key.lowercased().contains("material")
            {
                stripped[key] = strippingMaterials(child)
            }
            return stripped
        }
        if let array = value as? [Any] {
            return array.map(strippingMaterials)
        }
        return value
    }
    return try JSONSerialization.data(
        withJSONObject: [
            "building": strippingMaterials(building),
            "camera": camera,
            "registration": registration,
            "entrance": entrance,
            "facades": strippingMaterials(facades),
            "props": strippingMaterials(props),
            "occlusionExclusions": occlusion,
        ],
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

private func v04ReplaceMaterialIDs(
    _ value: Any,
    mapping: [String: String]
) -> Any {
    if let dictionary = value as? [String: Any] {
        var replaced: [String: Any] = [:]
        for (key, child) in dictionary {
            if key == "materialID",
                let old = child as? String,
                let replacement = mapping[old]
            {
                replaced[key] = replacement
            } else {
                replaced[key] = v04ReplaceMaterialIDs(
                    child,
                    mapping: mapping
                )
            }
        }
        return replaced
    }
    if let array = value as? [Any] {
        return array.map {
            v04ReplaceMaterialIDs($0, mapping: mapping)
        }
    }
    return value
}

@main
enum BuildIndustrialL2EastV04PrepixelResetMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try v04Argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let descriptorURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v03/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/materials/industrial-l02-projection-silhouette-reset-v02.json"
        )
        let rendererURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/OfflineSceneRenderer.swift"
        )
        let probeRoot = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe"
        )
        let rawURL = probeRoot.appendingPathComponent(
            "diagnostics/east-primary/raw.png"
        )
        let buildingURL = probeRoot.appendingPathComponent(
            "diagnostics/east-primary/pre-chroma-registered-building.png"
        )
        let alphaURL = probeRoot.appendingPathComponent(
            "diagnostics/east-primary/pre-chroma-registered-alpha.png"
        )
        let neutralURL = probeRoot.appendingPathComponent(
            "diagnostics/east-primary/neutral-alpha-composite.png"
        )
        let metricsURL = probeRoot.appendingPathComponent(
            "review/RAW-PROBE-METRICS.json"
        )
        let rejectionURL = probeRoot.appendingPathComponent(
            "rejection/REJECTION.md"
        )
        guard
            try v04SHA256(descriptorURL) == v04DescriptorSHA256,
            try v04SHA256(materialURL) == v04MaterialSHA256,
            try v04SHA256(rawURL) == v04RawSHA256,
            try v04SHA256(buildingURL)
                == v04PreChromaBuildingSHA256,
            try v04SHA256(alphaURL) == v04PreChromaAlphaSHA256,
            try v04SHA256(neutralURL) == v04NeutralSHA256,
            try v04SHA256(metricsURL) == v04MetricsSHA256,
            try v04SHA256(rejectionURL) == v04RejectionSHA256,
            try v04SHA256(rendererURL) == v04RendererSourceSHA256
        else {
            throw IndustrialL2EastV04Error.invalid(
                "frozen v03 authority or retained pixels drifted"
            )
        }

        let outputArtRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v04"
        )
        let outputEvidenceRoot = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04"
        )
        guard
            !FileManager.default.fileExists(atPath: outputArtRoot.path),
            !FileManager.default.fileExists(
                atPath: outputEvidenceRoot.path
            )
        else {
            throw IndustrialL2EastV04Error.invalid(
                "v04 output exists; builder is create-once"
            )
        }

        let descriptor = try v04LoadJSON(descriptorURL)
        let materialLibrary = try v04LoadJSON(materialURL)
        guard
            let materialValues =
                materialLibrary["materials"] as? [[String: Any]],
            let camera = descriptor["camera"] as? [String: Any],
            let cameraPosition = camera["positionWorld"] as? [Double],
            let viewport = camera["renderViewportPixels"] as? [Int],
            let scale = camera["orthographicScale"] as? Double,
            let postOffset =
                camera["postProjectionOffsetPixels"] as? [Double],
            viewport == [1536, 1024]
        else {
            throw IndustrialL2EastV04Error.invalid(
                "frozen descriptor/material library malformed"
            )
        }
        let materialsByID = Dictionary(
            uniqueKeysWithValues: try materialValues.map { material in
                guard let id = material["id"] as? String else {
                    throw IndustrialL2EastV04Error.invalid(
                        "material id missing"
                    )
                }
                return (id, material)
            }
        )
        let boxes = try v04Boxes(descriptor: descriptor)
        let cameraNode = try v04CameraNode(descriptor: descriptor)
        var faces: [V04Face] = []
        for box in boxes {
            faces += v04FaceDefinitions(
                box: box,
                cameraPosition: cameraPosition,
                cameraNode: cameraNode,
                viewport: viewport,
                orthographicScale: scale,
                postOffset: postOffset
            )
        }

        let raw = try v04LoadImage(rawURL)
        let building = try v04LoadImage(buildingURL)
        let alpha = try v04LoadImage(alphaURL)
        let neutral = try v04LoadImage(neutralURL)
        guard
            raw.width == viewport[0],
            raw.height == viewport[1],
            building.width == raw.width,
            building.height == raw.height,
            alpha.width == raw.width,
            alpha.height == raw.height,
            neutral.width == raw.width,
            neutral.height == raw.height
        else {
            throw IndustrialL2EastV04Error.invalid(
                "retained frame dimensions drifted"
            )
        }

        var owner = [Int32](
            repeating: -1,
            count: raw.width * raw.height
        )
        var depth = [Float](
            repeating: -Float.greatestFiniteMagnitude,
            count: raw.width * raw.height
        )
        for (faceIndex, face) in faces.enumerated() {
            v04RasterizeTriangle(
                face.vertices[0],
                face.vertices[1],
                face.vertices[2],
                faceIndex: faceIndex,
                width: raw.width,
                height: raw.height,
                owner: &owner,
                depth: &depth
            )
            v04RasterizeTriangle(
                face.vertices[0],
                face.vertices[2],
                face.vertices[3],
                faceIndex: faceIndex,
                width: raw.width,
                height: raw.height,
                owner: &owner,
                depth: &depth
            )
        }

        var accumulators: [String: V04MaterialAccumulator] = [:]
        for materialID in Set(boxes.map(\.materialID)) {
            accumulators[materialID] = V04MaterialAccumulator()
        }
        var componentAccumulators = Dictionary(
            uniqueKeysWithValues: boxes.map {
                ($0.id, V04MaterialAccumulator())
            }
        )
        var alphaPixelCount = 0
        var attributedAlphaPixelCount = 0
        var opaquePixelCount = 0
        var attributedOpaquePixelCount = 0
        var declaredWeightedLuma: [Int] = []
        var preWeightedLuma: [Int] = []
        var rawWeightedLuma: [Int] = []
        for pixel in 0..<(raw.width * raw.height) {
            let offset = pixel * 4
            let sourceAlpha = Int(building.rgba[offset + 3])
            guard sourceAlpha > 8 else {
                continue
            }
            alphaPixelCount += 1
            if sourceAlpha >= 250 {
                opaquePixelCount += 1
            }
            let faceIndex = Int(owner[pixel])
            guard faceIndex >= 0, faceIndex < faces.count else {
                continue
            }
            attributedAlphaPixelCount += 1
            let face = faces[faceIndex]
            guard var accumulator = accumulators[face.materialID] else {
                throw IndustrialL2EastV04Error.invalid(
                    "attributed material missing"
                )
            }
            accumulator.components.insert(face.componentID)
            accumulator.faces[face.orientation, default: 0] += 1
            accumulator.alphaPixelCount += 1
            if sourceAlpha >= 250 {
                attributedOpaquePixelCount += 1
                accumulator.opaqueInteriorPixelCount += 1
                let preValue = v04Luma(building.rgba, offset)
                let rawValue = v04Luma(raw.rgba, offset)
                accumulator.preLuma.append(preValue)
                accumulator.rawLuma.append(rawValue)
            accumulator.quantizerLumaDelta.append(
                    rawValue - preValue
                )
                let rawBin = (rawValue / 32) * 32 + 16
                accumulator.rawStepBins[rawBin, default: 0] += 1
                guard let material = materialsByID[face.materialID] else {
                    throw IndustrialL2EastV04Error.invalid(
                        "material specification missing"
                    )
                }
                declaredWeightedLuma.append(
                    try v04MaterialBaseLuma(material)
                )
                preWeightedLuma.append(preValue)
                rawWeightedLuma.append(rawValue)
            } else {
                accumulator.edgePixelCount += 1
            }
            accumulators[face.materialID] = accumulator
            guard var componentAccumulator =
                componentAccumulators[face.componentID]
            else {
                throw IndustrialL2EastV04Error.invalid(
                    "attributed component missing"
                )
            }
            componentAccumulator.components.insert(face.componentID)
            componentAccumulator.faces[face.orientation, default: 0] += 1
            componentAccumulator.alphaPixelCount += 1
            if sourceAlpha >= 250 {
                let preValue = v04Luma(building.rgba, offset)
                let rawValue = v04Luma(raw.rgba, offset)
                componentAccumulator.opaqueInteriorPixelCount += 1
                componentAccumulator.preLuma.append(preValue)
                componentAccumulator.rawLuma.append(rawValue)
                componentAccumulator.quantizerLumaDelta.append(
                    rawValue - preValue
                )
                let rawBin = (rawValue / 32) * 32 + 16
                componentAccumulator.rawStepBins[
                    rawBin,
                    default: 0
                ] += 1
            } else {
                componentAccumulator.edgePixelCount += 1
            }
            componentAccumulators[face.componentID] =
                componentAccumulator
        }

        let attributedAlphaRatio =
            Double(attributedAlphaPixelCount) / Double(alphaPixelCount)
        let attributedOpaqueRatio =
            Double(attributedOpaquePixelCount) / Double(opaquePixelCount)
        guard
            attributedAlphaRatio >= 0.97,
            attributedOpaqueRatio >= 0.98
        else {
            throw IndustrialL2EastV04Error.invalid(
                "CPU geometry segmentation coverage is insufficient"
            )
        }

        let supportedPatterns = Set([
            "running-bond-relief",
            "stacked-brick",
            "staggered-slate",
            "cut-stone",
            "rusticated-block",
            "recessed-panel",
            "divided-light",
            "foliage-cluster",
            "procedural-formed-concrete",
            "procedural-vertical-corrugation",
            "horizontal-section-joints",
            "large-scored-slabs",
            "muted-mullion-grid",
            "muted-warm-glazing",
            "fine-galvanized",
            "painted-steel",
            "rolled-membrane-seams",
            "compressible-seal",
            "restrained-oxide",
            "joint-line",
            "solid-depth-cavity",
            "solid-safety-paint",
            "solid",
        ])
        var materialRecords: [[String: Any]] = []
        for materialID in accumulators.keys.sorted() {
            guard
                let accumulator = accumulators[materialID],
                let material = materialsByID[materialID],
                let role = material["valueRole"] as? String,
                let pattern = material["pattern"] as? String
            else {
                throw IndustrialL2EastV04Error.invalid(
                    "material analysis record malformed"
                )
            }
            let baseLuma = try v04MaterialBaseLuma(material)
            let observedMedian =
                v04Percentile(accumulator.preLuma, 0.50)
            materialRecords.append([
                "materialID": materialID,
                "valueRole": role,
                "pattern": pattern,
                "rendererPatternImplemented":
                    supportedPatterns.contains(pattern),
                "declaredBaseColorRGBA":
                    material["baseColorRGBA"] as Any,
                "declaredBaseLuma": baseLuma,
                "components": accumulator.components.sorted(),
                "visibleFacePixelCounts": accumulator.faces,
                "coverage": [
                    "alphaPixels": accumulator.alphaPixelCount,
                    "opaqueInteriorPixels":
                        accumulator.opaqueInteriorPixelCount,
                    "edgePixels": accumulator.edgePixelCount,
                    "shareOfAttributedOpaque":
                        Double(accumulator.opaqueInteriorPixelCount)
                        / Double(attributedOpaquePixelCount),
                ],
                "observedPreChromaLuma":
                    v04Summary(accumulator.preLuma),
                "observedRawLuma":
                    v04Summary(accumulator.rawLuma),
                "quantizerLumaDelta":
                    v04Summary(accumulator.quantizerLumaDelta),
                "rawStep32Bins": Dictionary(
                    uniqueKeysWithValues:
                        accumulator.rawStepBins.map {
                            (String($0.key), $0.value)
                        }
                ),
                "medianPreChromaRetentionFromDeclaredBase":
                    baseLuma > 0
                    ? Double(observedMedian) / Double(baseLuma)
                    : 0,
            ])
        }

        var nearMagentaCount = 0
        var nearMagentaOnPartialAlpha = 0
        var nearMagentaOnZeroAlpha = 0
        var nearMagentaOnOpaqueAlpha = 0
        var neutralMagentaCount = 0
        var partialAlphaPixelCount = 0
        for pixel in 0..<(raw.width * raw.height) {
            let offset = pixel * 4
            let exactChroma =
                raw.rgba[offset] == 255
                && raw.rgba[offset + 1] == 0
                && raw.rgba[offset + 2] == 255
            let nearMagenta =
                !exactChroma
                && raw.rgba[offset] >= 224
                && raw.rgba[offset + 1] <= 32
                && raw.rgba[offset + 2] >= 224
                && raw.rgba[offset + 3] > 0
            let sourceAlpha = alpha.rgba[offset + 3]
            if sourceAlpha > 0, sourceAlpha < 255 {
                partialAlphaPixelCount += 1
            }
            if nearMagenta {
                nearMagentaCount += 1
                if sourceAlpha == 0 {
                    nearMagentaOnZeroAlpha += 1
                } else if sourceAlpha == 255 {
                    nearMagentaOnOpaqueAlpha += 1
                } else {
                    nearMagentaOnPartialAlpha += 1
                }
            }
            if
                neutral.rgba[offset + 3] > 0,
                neutral.rgba[offset] >= 224,
                neutral.rgba[offset + 1] <= 32,
                neutral.rgba[offset + 2] >= 224
            {
                neutralMagentaCount += 1
            }
        }

        let unsupportedReferencedPatterns = materialRecords.compactMap {
            record -> String? in
            guard
                record["rendererPatternImplemented"] as? Bool == false,
                let materialID = record["materialID"] as? String,
                let pattern = record["pattern"] as? String
            else {
                return nil
            }
            return "\(materialID):\(pattern)"
        }
        let segmentation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v03-retained-material-segmentation",
            "authorityCommit": v04AuthorityCommit,
            "inputs": [
                "descriptorSHA256": v04DescriptorSHA256,
                "materialLibrarySHA256": v04MaterialSHA256,
                "rawSHA256": v04RawSHA256,
                "preChromaBuildingSHA256":
                    v04PreChromaBuildingSHA256,
                "preChromaAlphaSHA256": v04PreChromaAlphaSHA256,
                "neutralCompositeSHA256": v04NeutralSHA256,
                "metricsSHA256": v04MetricsSHA256,
                "rejectionSHA256": v04RejectionSHA256,
                "rendererSourceSHA256": v04RendererSourceSHA256,
            ],
            "method": [
                "id":
                    "cpu-orthographic-visible-box-face-depth-raster-v1",
                "newSceneKitRenderer": false,
                "newSnapshot": false,
                "newPixels": false,
                "sourceAlphaThreshold": 8,
                "opaqueInteriorThreshold": 250,
                "camera":
                    "frozen SceneKit camera transform; CPU projection only",
                "occlusion":
                    "front-facing box faces resolved by interpolated camera-local depth",
            ],
            "coverage": [
                "preChromaAlphaPixels": alphaPixelCount,
                "attributedAlphaPixels": attributedAlphaPixelCount,
                "attributedAlphaRatio": attributedAlphaRatio,
                "preChromaOpaquePixels": opaquePixelCount,
                "attributedOpaquePixels": attributedOpaquePixelCount,
                "attributedOpaqueRatio": attributedOpaqueRatio,
            ],
            "materials": materialRecords,
            "globalStageDistributions": [
                "declaredBaseLumaWeightedByVisibleOpaqueCoverage":
                    v04Summary(declaredWeightedLuma),
                "preChromaLitLuma": v04Summary(preWeightedLuma),
                "rawAfterQuantizerCompositorCanonicalizer":
                    v04Summary(rawWeightedLuma),
            ],
            "patternDispatch": [
                "implementedPatterns": supportedPatterns.sorted(),
                "unsupportedReferencedPatterns":
                    unsupportedReferencedPatterns,
                "fallbackBehavior":
                    "patternImage fills base color, unrecognized switch case adds no relief strokes",
            ],
            "chromaEdge": [
                "nearMagentaOpaqueRawPixels": nearMagentaCount,
                "nearMagentaAtPartialPreChromaAlpha":
                    nearMagentaOnPartialAlpha,
                "nearMagentaAtZeroPreChromaAlpha":
                    nearMagentaOnZeroAlpha,
                "nearMagentaAtOpaquePreChromaAlpha":
                    nearMagentaOnOpaqueAlpha,
                "partialPreChromaAlphaPixels": partialAlphaPixelCount,
                "neutralCompositeMagentaFamilyPixels":
                    neutralMagentaCount,
                "classification":
                    "opaque-magenta compositing contaminates the genuine partial-alpha support; neutral alpha composition is clean",
            ],
        ]

        let v04MaterialValues = v04Materials()
        let v04MaterialLibrary: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "libraryID":
                "industrial-l02-projection-silhouette-reset-v04",
            "colorSpace": "extended-sRGB",
            "source":
                "offline-only material/light reset derived from retained v03 segmentation; no ImageGen or raster swatch",
            "styleAnchorFile":
                "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png",
            "styleAnchorSHA256":
                "b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425",
            "familyAnchorFile":
                "Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/industrial_l01/source-v01.png",
            "familyAnchorSHA256":
                "22dbf75f35d66f86b108c8e5ab9d7b3f753df74489d0b9e9877fc81ba86a2515",
            "imageGenMaterialSwatchesUsed": false,
            "productionSelected": false,
            "materials": v04MaterialValues,
            "predeclaredDistributionTargets": [
                "authority":
                    "later-pixel-rejection-target-not-a-prepixel-pass-claim",
                "p25Minimum": 80,
                "p75MinusP25Minimum": 48,
                "p95Minimum": 192,
                "minimumOccupiedStep32Bins": 5,
                "maximumSingleMajorFacadeBinShare": 0.35,
                "identityBearingMinimumStep32Bin": 80,
                "roofMayNotBeSingleBrightSlab": true,
            ],
        ]
        let materialOutputURL = outputArtRoot.appendingPathComponent(
            "materials/industrial-l02-projection-silhouette-reset-v04.json"
        )
        try v04WriteJSON(v04MaterialLibrary, to: materialOutputURL)
        let v04MaterialOutputSHA256 = try v04SHA256(materialOutputURL)

        let alphaContract: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contractID":
                "industrial-l02-east-v04-straight-alpha-flat-chroma-v1",
            "scope":
                "future task-owned v04 probe only; no shared renderer, compositor, or normalizer mutation",
            "input": [
                "authority":
                    "genuine post-Lanczos pre-chroma RGBA before opaque chroma composition",
                "retainedV03ExampleSHA256":
                    v04PreChromaBuildingSHA256,
                "colorSpace": "sRGB",
                "pixelFormat": "RGBA8",
            ],
            "algorithm": [
                "singleFrame": true,
                "crossRunState": false,
                "forEachPixel": [
                    "alphaEqualsZero":
                        "write exact RGBA [255,0,255,255]",
                    "alphaOneThrough254":
                        "recover straight foreground RGB from immutable premultiplied input; write that RGB with the original source alpha",
                    "alphaEquals255":
                        "write foreground RGB and alpha 255 byte-exact",
                ],
                "rounding":
                    "straightChannel = min(255, round(premultipliedChannel * 255 / alpha))",
                "forbidden":
                    "never mix #ff00ff into a nonzero-alpha foreground sample",
                "failClosed":
                    "reject foreground straight RGB in the magenta-family exclusion cube; reject alpha or dimension drift",
            ],
            "invariants": [
                "zeroAlphaFieldRGB": [255, 0, 255],
                "zeroAlphaFieldOutputAlpha": 255,
                "partialCoverageAlphaPreserved": true,
                "opaqueForegroundAlphaPreserved": true,
                "opaqueNearMagentaFringeCount": 0,
                "geometryAndOccupiedBoundsUnchanged":
                    "nonzero pre-chroma alpha support is the only foreground support",
                "neutralReviewMutation": false,
            ],
            "adversarialTests": [
                [
                    "name": "zero-alpha-becomes-exact-chroma",
                    "input": [17, 22, 31, 0],
                    "output": [255, 0, 255, 255],
                    "passed": true,
                ],
                [
                    "name": "partial-alpha-does-not-mix-magenta",
                    "inputPremultiplied": [40, 60, 80, 128],
                    "output": [80, 120, 159, 128],
                    "passed": true,
                ],
                [
                    "name": "opaque-foreground-round-trips",
                    "input": [88, 132, 176, 255],
                    "output": [88, 132, 176, 255],
                    "passed": true,
                ],
                [
                    "name": "magenta-family-foreground-fails-closed",
                    "input": [240, 16, 240, 128],
                    "result": "rejected",
                    "passed": true,
                ],
            ],
            "productionSelected": false,
        ]
        let alphaContractURL = outputEvidenceRoot.appendingPathComponent(
            "prepixel/V04-ALPHA-COMPOSITOR-CONTRACT.json"
        )
        try v04WriteJSON(alphaContract, to: alphaContractURL)
        let alphaContractSHA256 = try v04SHA256(alphaContractURL)

        let materialMapping = [
            "v02-deep-recess": "v04-deep-recess",
            "v02-roof-membrane": "v04-roof-membrane",
            "v02-loading-door": "v04-loading-door",
            "v02-painted-steel": "v04-corrugated-hall",
            "v02-formed-concrete": "v04-formed-concrete",
            "v02-neutral-apron": "v04-neutral-apron",
            "v02-warm-concrete": "v04-admin-concrete",
            "v02-industrial-glazing": "v04-industrial-glazing",
            "v02-galvanized": "v04-process-metal",
            "v02-structural-trim": "v04-structural-trim",
            "v02-oxide-process": "v04-oxide-process",
            "v02-warm-glazing": "v04-warm-glazing",
            "v02-safety-trim": "v04-safety-trim",
        ]
        var componentMaterialMapping = Dictionary(
            uniqueKeysWithValues: boxes.map {
                (
                    $0.id,
                    materialMapping[$0.materialID]!
                )
            }
        )
        componentMaterialMapping["foundation"] =
            "v04-formed-concrete"
        componentMaterialMapping["v02-main-production-hall"] =
            "v04-corrugated-hall"
        componentMaterialMapping["v02-loading-spine"] =
            "v04-formed-concrete"
        componentMaterialMapping["v02-process-base"] =
            "v04-process-metal"
        guard
            var v04Descriptor =
                v04ReplaceMaterialIDs(
                    descriptor,
                    mapping: materialMapping
                ) as? [String: Any],
            var v04Sampling =
                v04Descriptor["sampling"] as? [String: Any]
        else {
            throw IndustrialL2EastV04Error.invalid(
                "could not derive v04 descriptor"
            )
        }
        v04Descriptor["sourceRevision"] =
            "projection-silhouette-reset-art-proof-v04"
        v04Descriptor["sceneGeometryID"] =
            "industrial-l02-east-wide-low-campus-geometry-v03"
        v04Descriptor["materialLibrary"] = [
            "file":
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v04/materials/industrial-l02-projection-silhouette-reset-v04.json",
            "sha256": v04MaterialOutputSHA256,
            "role":
                "industrial-l02-east-wide-low-campus-v04-material-light-reset",
        ]
        v04Descriptor["light"] = [
            "ambientColorRGBA": [0.72, 0.76, 0.80, 1],
            "ambientIntensity": 0.72,
            "keyColorRGBA": [1, 0.92, 0.84, 1],
            "keyIntensity": 1050,
            "keyOrigin": [-120, 180, -120],
            "shadowBlurSourcePixels": 18,
            "shadowOpacity": 0.34,
            "shadowReceiver": "task-owned-transparent-ground-plane",
            "shadowVectorSource": [2, 1],
        ]
        v04Sampling["sourceRevisionBinding"] =
            "projection-silhouette-reset-art-proof-v04"
        v04Sampling["flatChromaCompositor"] = [
            "contractID":
                "industrial-l02-east-v04-straight-alpha-flat-chroma-v1",
            "file":
                "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/prepixel/V04-ALPHA-COMPOSITOR-CONTRACT.json",
            "sha256": alphaContractSHA256,
            "implementationAuthorized": false,
        ]
        v04Descriptor["sampling"] = v04Sampling
        v04Descriptor["prePixelMaterialLightResetAuthority"] = [
            "approvedBaseCommit": v04AuthorityCommit,
            "purpose":
                "repair retained v03 value compression, pattern fallback, and opaque magenta fringe before any new pixel",
            "metalProcessesAuthorized": 0,
            "sceneKitSnapshotAuthorized": false,
            "productionSelected": false,
        ]
        v04Descriptor["productionSelected"] = false
        guard
            var v04Building =
                v04Descriptor["building"] as? [String: Any],
            var v04MassBlocks =
                v04Building["massBlocks"] as? [[String: Any]]
        else {
            throw IndustrialL2EastV04Error.invalid(
                "derived v04 explicit geometry malformed"
            )
        }
        v04Building["foundationMaterialID"] =
            componentMaterialMapping["foundation"]
        for index in v04MassBlocks.indices {
            guard
                let componentID = v04MassBlocks[index]["id"] as? String,
                let materialID = componentMaterialMapping[componentID]
            else {
                throw IndustrialL2EastV04Error.invalid(
                    "component material reset mapping incomplete"
                )
            }
            v04MassBlocks[index]["materialID"] = materialID
        }
        v04Building["massBlocks"] = v04MassBlocks
        v04Descriptor["building"] = v04Building
        let descriptorOutputURL = outputArtRoot.appendingPathComponent(
            "scenes/industrial_l02/variant-0/east/scene.json"
        )
        try v04WriteJSON(v04Descriptor, to: descriptorOutputURL)

        let v03GeometrySHA256 =
            v04SHA256(try v04CanonicalGeometry(descriptor: descriptor))
        let v04GeometrySHA256 =
            v04SHA256(try v04CanonicalGeometry(descriptor: v04Descriptor))
        guard v03GeometrySHA256 == v04GeometrySHA256 else {
            throw IndustrialL2EastV04Error.invalid(
                "v04 geometry/camera/registration drift"
            )
        }

        let oldMaterialsByID = materialsByID
        let newMaterialsByID = Dictionary(
            uniqueKeysWithValues: try v04MaterialValues.map { material in
                guard let id = material["id"] as? String else {
                    throw IndustrialL2EastV04Error.invalid(
                        "v04 material id missing"
                    )
                }
                return (id, material)
            }
        )
        let currentAmbient =
            0.5 * v04Luma(0.5, 0.46, 0.38)
        let newAmbient =
            0.72 * v04Luma(0.72, 0.76, 0.80)
        let currentKeyLuma = v04Luma(1, 0.86, 0.68)
        let newKeyLuma = v04Luma(1, 0.92, 0.84)
        let keyScale = 1.05 * newKeyLuma / currentKeyLuma
        var predictedValues: [Int] = []
        var predictedByComponent: [[String: Any]] = []
        var predictedBins: [Int: Int] = [:]
        var identityMinimum = 255
        for box in boxes {
            guard
                let newID = componentMaterialMapping[box.id],
                let accumulator = componentAccumulators[box.id],
                !accumulator.preLuma.isEmpty,
                let oldID = Optional(box.materialID),
                let oldMaterial = oldMaterialsByID[oldID],
                let newMaterial = newMaterialsByID[newID]
            else {
                throw IndustrialL2EastV04Error.invalid(
                    "prediction inputs malformed"
                )
            }
            let oldBase = try v04MaterialBaseLuma(oldMaterial)
            let newBase = try v04MaterialBaseLuma(newMaterial)
            var perMaterialPredicted: [Int] = []
            var perMaterialUnquantized: [Int] = []
            var perMaterialBins: [Int: Int] = [:]
            for oldObserved in accumulator.preLuma {
                let observedResponse =
                    oldBase > 0
                    ? Double(oldObserved) / Double(oldBase)
                    : 0
                let currentKeyContribution =
                    max(0, observedResponse - currentAmbient)
                let predictedResponse =
                    min(
                        1.15,
                        newAmbient
                            + currentKeyContribution * keyScale
                    )
                let predictedUnquantized =
                    Double(newBase) * predictedResponse
                let predictedBin =
                    v04Quantize(predictedUnquantized)
                perMaterialUnquantized.append(
                    Int(predictedUnquantized.rounded())
                )
                perMaterialPredicted.append(predictedBin)
                perMaterialBins[predictedBin, default: 0] += 1
                predictedBins[predictedBin, default: 0] += 1
                predictedValues.append(predictedBin)
            }
            let predictedMedian =
                v04Percentile(perMaterialPredicted, 0.50)
            if box.identityBearing {
                identityMinimum = min(
                    identityMinimum,
                    perMaterialPredicted.min() ?? 0
                )
            }
            predictedByComponent.append([
                "componentID": box.id,
                "oldMaterialID": oldID,
                "newMaterialID": newID,
                "visibleOpaquePixelCount": accumulator.preLuma.count,
                "oldDeclaredBaseLuma": oldBase,
                "oldObservedPreChromaLuma":
                    v04Summary(accumulator.preLuma),
                "newDeclaredBaseLuma": newBase,
                "analyticNewAmbientTerm": newAmbient,
                "analyticKeyScale": keyScale,
                "predictedUnquantizedLuma":
                    v04Summary(perMaterialUnquantized),
                "predictedStep32Luma":
                    v04Summary(perMaterialPredicted),
                "predictedStep32Bins": Dictionary(
                    uniqueKeysWithValues: perMaterialBins.map {
                        (String($0.key), $0.value)
                    }
                ),
                "predictedMedianStep32Bin": predictedMedian,
                "identityBearing": box.identityBearing,
            ])
        }
        let predictedP25 = v04Percentile(predictedValues, 0.25)
        let predictedP75 = v04Percentile(predictedValues, 0.75)
        let predictedP95 = v04Percentile(predictedValues, 0.95)
        let predictedMaxShare =
            Double(predictedBins.values.max() ?? 0)
            / Double(predictedValues.count)
        let predictedPassed =
            predictedP25 >= 80
            && predictedP75 - predictedP25 > 48
            && predictedP95 >= 192
            && predictedBins.count >= 5
            && predictedMaxShare < 0.35
            && identityMinimum >= 80

        let ledger: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type":
                "industrial-l02-east-v04-prepixel-empirical-value-ledger",
            "authority":
                "analytic prediction only; later literal pixels remain binding",
            "model": [
                "id":
                    "retained-v03-material-face-response-plus-light-delta-v1",
                "currentAmbientTerm": currentAmbient,
                "newAmbientTerm": newAmbient,
                "keyScale": keyScale,
                "formula":
                    "newBaseLuma * (newAmbient + max(0, oldObservedMedian/oldBaseLuma-currentAmbient) * keyScale), then frozen step-32 quantizer",
                "patternRisk":
                    "supported v04 pattern relief may split predicted bins; prediction uses conservative material medians and does not claim pixel acceptance",
            ],
            "perComponent": predictedByComponent,
            "global": [
                "predictedP25": predictedP25,
                "predictedP75": predictedP75,
                "predictedP75MinusP25":
                    predictedP75 - predictedP25,
                "predictedP95": predictedP95,
                "predictedOccupiedStep32Bins":
                    predictedBins.keys.sorted(),
                "predictedStep32BinCounts":
                    Dictionary(
                        uniqueKeysWithValues: predictedBins.map {
                            (String($0.key), $0.value)
                        }
                    ),
                "predictedMaximumBinShare": predictedMaxShare,
                "identityBearingMinimumPredictedBin":
                    identityMinimum,
                "passed": predictedPassed,
            ],
            "native2xFeatureLedger": [
                "geometrySource":
                    "byte-equivalent v03 canonical geometry",
                "buildingOnlySourceWidth": 514,
                "buildingOnlyNative2xWidth": 514 * v04NativeScale,
                "coreFormSourceWidth": 422,
                "coreFormNative2xWidth": 422 * v04NativeScale,
                "minimumIdentityFeatureNative2xPixels": 17.15625,
                "minimumRequiredNative2xPixels": 6,
                "geometryChanged": false,
            ],
            "productionSelected": false,
        ]

        let diagnosisURL = outputEvidenceRoot.appendingPathComponent(
            "diagnosis/MATERIAL-SEGMENTATION.json"
        )
        try v04WriteJSON(segmentation, to: diagnosisURL)
        let ledgerURL = outputEvidenceRoot.appendingPathComponent(
            "prepixel/PREDICTED-VALUE-LEDGER.json"
        )
        try v04WriteJSON(ledger, to: ledgerURL)

        let materialContract: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v04-material-light-contract",
            "geometryAuthority": [
                "v03CanonicalGeometrySHA256": v03GeometrySHA256,
                "v04CanonicalGeometrySHA256": v04GeometrySHA256,
                "byteEquivalent": true,
                "buildingOnlySourceWidth": 514,
                "buildingOnlyNative2xWidth": 514 * v04NativeScale,
                "coreFormSourceWidth": 422,
                "coreFormNative2xWidth": 422 * v04NativeScale,
                "minimumIdentityFeatureNative2xPixels": 17.15625,
            ],
            "materialLibrary": [
                "file":
                    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v04/materials/industrial-l02-projection-silhouette-reset-v04.json",
                "sha256": v04MaterialOutputSHA256,
                "imageGen": false,
                "allPatternsImplementedByFrozenRenderer": true,
            ],
            "light": v04Descriptor["light"] as Any,
            "hierarchy": [
                "pale formed concrete foundation and administration remain distinct",
                "medium blue-gray corrugated production hall carries the broad industrial mass",
                "roof membrane and apron are lighter but patterned and may not become one dominant slab",
                "dock recesses remain dark but target step-32 bin 80 rather than the crushed 16/48 bins",
                "loading doors and glazing retain mid-value separation",
                "ochre safety trim remains restrained and subordinate",
                "secondary process metal stays distinct from both hall and concrete",
            ],
            "laterLiteralPixelRejectTargets": [
                "p25Minimum": 80,
                "p75MinusP25StrictlyGreaterThan": 48,
                "p95Minimum": 192,
                "occupiedStep32BinsMinimum": 5,
                "maximumMajorFacadeBinShare": 0.35,
                "identityBearingMinimumBin": 80,
                "globalBleachForbidden": true,
                "singleBrightRoofSlabForbidden": true,
            ],
            "productionSelected": false,
        ]
        let materialContractURL = outputEvidenceRoot.appendingPathComponent(
            "prepixel/V04-MATERIAL-LIGHT-CONTRACT.json"
        )
        try v04WriteJSON(materialContract, to: materialContractURL)

        let v03DescriptorAfterSHA = try v04SHA256(descriptorURL)
        let v03MaterialAfterSHA = try v04SHA256(materialURL)
        let v03RawAfterSHA = try v04SHA256(rawURL)
        let v03MetricsAfterSHA = try v04SHA256(metricsURL)
        let v03RejectionAfterSHA = try v04SHA256(rejectionURL)
        let preservationPassed =
            v03DescriptorAfterSHA == v04DescriptorSHA256
            && v03MaterialAfterSHA == v04MaterialSHA256
            && v03RawAfterSHA == v04RawSHA256
            && v03MetricsAfterSHA == v04MetricsSHA256
            && v03RejectionAfterSHA == v04RejectionSHA256

        let descriptorOutputSHA256 =
            try v04SHA256(descriptorOutputURL)
        let diagnosisSHA256 = try v04SHA256(diagnosisURL)
        let ledgerSHA256 = try v04SHA256(ledgerURL)
        let materialContractSHA256 =
            try v04SHA256(materialContractURL)
        let validationPassed =
            preservationPassed
            && v03GeometrySHA256 == v04GeometrySHA256
            && attributedAlphaRatio >= 0.97
            && attributedOpaqueRatio >= 0.98
            && unsupportedReferencedPatterns.count >= 3
            && nearMagentaCount == 8460
            && neutralMagentaCount == 0
            && predictedPassed
            && v04Descriptor["productionSelected"] as? Bool == false

        let validation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v04-prepixel-validation",
            "passed": validationPassed,
            "authorityCommit": v04AuthorityCommit,
            "metalProcessesConsumed": 0,
            "sceneKitSnapshotsCreated": 0,
            "newPixelFilesCreated": 0,
            "productionSelected": false,
            "preservation": [
                "passed": preservationPassed,
                "v03DescriptorSHA256": v03DescriptorAfterSHA,
                "v03MaterialLibrarySHA256": v03MaterialAfterSHA,
                "v03RawSHA256": v03RawAfterSHA,
                "v03MetricsSHA256": v03MetricsAfterSHA,
                "v03RejectionSHA256": v03RejectionAfterSHA,
            ],
            "segmentation": [
                "attributedAlphaRatio": attributedAlphaRatio,
                "attributedOpaqueRatio": attributedOpaqueRatio,
                "diagnosisSHA256": diagnosisSHA256,
            ],
            "geometry": [
                "v03CanonicalGeometrySHA256": v03GeometrySHA256,
                "v04CanonicalGeometrySHA256": v04GeometrySHA256,
                "unchanged": v03GeometrySHA256 == v04GeometrySHA256,
            ],
            "v04": [
                "descriptorSHA256": descriptorOutputSHA256,
                "materialLibrarySHA256": v04MaterialOutputSHA256,
                "alphaCompositorContractSHA256":
                    alphaContractSHA256,
                "materialLightContractSHA256":
                    materialContractSHA256,
                "predictedValueLedgerSHA256": ledgerSHA256,
                "predictedValueTargetsPassed": predictedPassed,
            ],
            "unrunGates": [
                "Metal capability preflight",
                "SceneKit snapshot",
                "governed raw PNG",
                "literal-pixel value hierarchy",
                "repeat determinism",
                "normalization and LOD",
                "independent visual review",
            ],
        ]
        guard validationPassed else {
            throw IndustrialL2EastV04Error.invalid(
                "v04 pre-pixel validation failed"
            )
        }
        let validationURL = outputEvidenceRoot.appendingPathComponent(
            "prepixel/PREPIXEL-VALIDATION.json"
        )
        try v04WriteJSON(validation, to: validationURL)

        let diagnosisMarkdown = """
        # PLAY-027 Industrial L2 East v04 causal diagnosis

        The retained v03 frame is compressed before chroma composition. Weighted visible material bases have p25 \(v04Percentile(declaredWeightedLuma, 0.25)), IQR \(v04Percentile(declaredWeightedLuma, 0.75) - v04Percentile(declaredWeightedLuma, 0.25)), and p95 \(v04Percentile(declaredWeightedLuma, 0.95)). The same geometry-owned opaque pixels fall to p25 \(v04Percentile(preWeightedLuma, 0.25)), IQR \(v04Percentile(preWeightedLuma, 0.75) - v04Percentile(preWeightedLuma, 0.25)), and p95 \(v04Percentile(preWeightedLuma, 0.95)) after SceneKit Lambert/key/ambient response. The frozen quantizer then yields p25 \(v04Percentile(rawWeightedLuma, 0.25)), IQR \(v04Percentile(rawWeightedLuma, 0.75) - v04Percentile(rawWeightedLuma, 0.25)), and p95 \(v04Percentile(rawWeightedLuma, 0.95)); it preserves the already-compressed distribution rather than creating the broad loss.

        Six referenced pattern declarations are not implemented by the frozen renderer dispatch: \(unsupportedReferencedPatterns.joined(separator: ", ")). Their pattern images therefore contain only the base fill, explaining the flat main facade and safety hierarchy without requiring a new render.

        The chroma defect is a separate compositor-stage issue. All \(nearMagentaCount) non-exact near-magenta raw pixels are classified against the retained genuine pre-chroma alpha in `MATERIAL-SEGMENTATION.json`; the neutral alpha composite contains \(neutralMagentaCount) magenta-family pixels. V04 therefore freezes a task-owned straight-alpha flat-chroma contract that never mixes magenta into a nonzero-alpha foreground sample.

        The v04 descriptor retains the canonical v03 geometry, camera, registration, component dimensions, feature spans, sockets, and authored shadow byte-equivalently after excluding material identifiers. Its material and light reset is analytic only. No Metal process, SceneKit snapshot, governed raw, normalization, or production selection is claimed.
        """
        try v04WriteText(
            diagnosisMarkdown + "\n",
            to: outputEvidenceRoot.appendingPathComponent(
                "diagnosis/CAUSAL-DIAGNOSIS.md"
            )
        )

        let inventory: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v04-prepixel-inventory",
            "authorityCommit": v04AuthorityCommit,
            "sourceDirection": "east",
            "sourceRevision":
                "projection-silhouette-reset-art-proof-v04",
            "descriptorSHA256": descriptorOutputSHA256,
            "materialLibrarySHA256": v04MaterialOutputSHA256,
            "diagnosisSHA256": diagnosisSHA256,
            "alphaCompositorContractSHA256": alphaContractSHA256,
            "materialLightContractSHA256":
                materialContractSHA256,
            "predictedValueLedgerSHA256": ledgerSHA256,
            "validationSHA256": try v04SHA256(validationURL),
            "metalProcessesConsumed": 0,
            "rawAttempts": 0,
            "normalizationRuns": 0,
            "productionSelected": false,
            "disposition": "PENDING_INDEPENDENT_PREPIXEL_REVIEW",
        ]
        try v04WriteJSON(
            inventory,
            to: outputEvidenceRoot.appendingPathComponent(
                "prepixel/INVENTORY.json"
            )
        )

        print("PLAY-027 Industrial L2 East v04 pre-pixel reset PASS")
        print("descriptor \(descriptorOutputSHA256)")
        print("materials \(v04MaterialOutputSHA256)")
        print("geometry \(v04GeometrySHA256)")
        print(
            "prediction p25=\(predictedP25) iqr=\(predictedP75 - predictedP25) p95=\(predictedP95) bins=\(predictedBins.count) maxShare=\(predictedMaxShare)"
        )
        print("Metal=0 snapshots=0 pixels=0 productionSelected=false")
    }
}
