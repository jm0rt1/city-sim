import AppKit
import CoreGraphics
import CoreImage
import CoreText
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL4TurbinePrepixelError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l4-turbine-prepixel --repository-root <path> --regular-staged-frame <path> --compact-staged-frame <path> [--output-root <path>]"
        case let .invalid(message):
            return message
        }
    }
}

private struct L4Block {
    let id: String
    let dimensions: [Double]
    let position: [Double]
    let material: String

    var json: [String: Any] {
        [
            "id": id,
            "dimensions": dimensions,
            "positionWorld": position,
            "materialID": material,
        ]
    }
}

private struct L4Roof {
    let id: String
    let dimensions: [Double]
    let position: [Double]
    let material: String
    let trim: String

    var json: [String: Any] {
        [
            "id": id,
            "shape": "flat-parapet",
            "dimensions": dimensions,
            "positionWorld": position,
            "materialID": material,
            "trimMaterialID": trim,
        ]
    }
}

private struct L4Prop {
    let id: String
    let kind: String
    let dimensions: [Double]
    let position: [Double]
    let material: String

    var json: [String: Any] {
        [
            "id": id,
            "kind": kind,
            "dimensions": dimensions,
            "positionWorld": position,
            "materialID": material,
        ]
    }
}

private struct L4Plan {
    let direction: String
    let geometryID: String
    let blocks: [L4Block]
    let roofs: [L4Roof]
    let trims: [L4Block]
    let props: [L4Prop]
    let facadeEdgeWorld: [[Double]]
    let entranceBase: [Double]
    let exclusion: [[Double]]
}

private struct L4Vertex {
    let x: Double
    let y: Double
    let depth: Double
}

private struct L4Face {
    let materialID: String
    let orientation: String
    let vertices: [L4Vertex]

    var depth: Double {
        vertices.map(\.depth).reduce(0, +) / Double(vertices.count)
    }
}

private let l4SourceWidth = 1536
private let l4SourceHeight = 1024
private let l4OrthographicScale = 79.1959533691406
private let l4PixelsPerWorld =
    Double(l4SourceHeight) / (2.0 * l4OrthographicScale)
private let l4NativeScale = 0.28125
private let l4AuthorityBase =
    "b264e3e81c870c6e52961add93ae9b50edcf1f80"
private let l4ContinuityBase =
    "5b1378a2c81d7d55a39b19366b5206c28f70d9f7"
private let l4StyleAnchor =
    "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png"
private let l4StyleAnchorSHA =
    "b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425"
private let l4FamilyAnchor =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-complete-family-v01/review/NEUTRAL-GROUND-NATIVE-2X-NESW-COLOR.png"
private let l4FamilyAnchorSHA =
    "14ba96ea73f80de3d68e30388c9b56d6326698fa4a625822aa34e65a34de8fa7"

private func l4Argument(
    _ name: String,
    in arguments: [String],
    required: Bool = true
) throws -> String? {
    guard let index = arguments.firstIndex(of: name) else {
        if required { throw IndustrialL4TurbinePrepixelError.arguments }
        return nil
    }
    guard index + 1 < arguments.count else {
        throw IndustrialL4TurbinePrepixelError.arguments
    }
    return arguments[index + 1]
}

private func l4SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func l4SHA256(_ url: URL) throws -> String {
    l4SHA256(try Data(contentsOf: url))
}

private func l4JSONData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func l4WriteJSON(_ object: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "output must be absent: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try l4JSONData(object).write(to: url, options: .atomic)
}

private func l4WritePNG(_ image: CGImage, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "output must be absent: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw IndustrialL4TurbinePrepixelError.invalid("could not create PNG")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "could not finalize PNG: \(url.path)"
        )
    }
}

private func l4WriteText(_ text: String, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "output must be absent: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try (text + "\n").data(using: .utf8)!.write(
        to: url,
        options: .atomic
    )
}

private func l4Mapping() -> [String: Any] {
    [
        "mode": "world-scale-box-face-repeat-v1",
        "wrapS": "repeat",
        "wrapT": "repeat",
        "minificationFilter": "linear",
        "magnificationFilter": "linear",
        "mipFilter": "linear",
    ]
}

private func l4Material(
    _ id: String,
    _ rgba: [Double],
    _ roughness: Double,
    _ metalness: Double,
    _ pattern: String,
    scale: [Double] = [8, 8]
) -> [String: Any] {
    [
        "id": id,
        "baseColorRGBA": rgba,
        "roughness": roughness,
        "metalness": metalness,
        "pattern": pattern,
        "physicalScaleWorld": scale,
        "textureMapping": l4Mapping(),
    ]
}

private func l4Materials() -> [[String: Any]] {
    [
        l4Material("l4-recess", [0.055, 0.060, 0.058, 1], 0.95, 0.04, "deep-service-cavity"),
        l4Material("l4-dock-door", [0.16, 0.20, 0.19, 1], 0.82, 0.30, "heavy-vertical-fold-door"),
        l4Material("l4-weathered-blue-steel", [0.25, 0.34, 0.35, 1], 0.84, 0.31, "weathered-wide-corrugation"),
        l4Material("l4-blue-steel-light", [0.38, 0.45, 0.43, 1], 0.86, 0.23, "aged-assembly-steel-panels"),
        l4Material("l4-warm-concrete", [0.61, 0.48, 0.34, 1], 0.94, 0.00, "weathered-board-formed-concrete"),
        l4Material("l4-concrete-shadow", [0.31, 0.25, 0.20, 1], 0.97, 0.00, "oil-darkened-service-concrete"),
        l4Material("l4-foundation", [0.25, 0.25, 0.22, 1], 0.99, 0.00, "heavy-scored-foundation"),
        l4Material("l4-apron", [0.49, 0.43, 0.34, 1], 0.99, 0.00, "worn-heavy-load-apron"),
        l4Material("l4-roof-membrane", [0.41, 0.40, 0.34, 1], 0.95, 0.04, "weathered-dark-roof-seams"),
        l4Material("l4-charcoal-steel", [0.12, 0.15, 0.15, 1], 0.76, 0.48, "charcoal-heavy-structural-steel"),
        l4Material("l4-control-glazing", [0.16, 0.29, 0.28, 1], 0.40, 0.12, "deep-green-control-glazing"),
        l4Material("l4-warm-glazing", [0.96, 0.78, 0.42, 1], 0.39, 0.08, "warm-staff-entry-glazing"),
        l4Material("l4-process-metal", [0.45, 0.42, 0.35, 1], 0.70, 0.55, "aged-process-alloy"),
        l4Material("l4-duct-metal", [0.55, 0.49, 0.37, 1], 0.67, 0.60, "heat-stained-duct-metal"),
        l4Material("l4-light-trim", [0.82, 0.70, 0.50, 1], 0.72, 0.29, "weathered-copper-bronze-trim"),
        l4Material("l4-safety-ochre", [0.74, 0.39, 0.08, 1], 0.70, 0.20, "restrained-ochre-safety-paint"),
        l4Material("l4-oxide", [0.51, 0.25, 0.13, 1], 0.82, 0.41, "layered-oxide-weathering"),
        l4Material("l4-pipe", [0.42, 0.39, 0.31, 1], 0.65, 0.64, "aged-pipework"),
    ]
}

private func l4DockBlocks(
    prefix: String,
    centers: [Double],
    axis: String,
    edge: Double
) -> [L4Block] {
    var result: [L4Block] = []
    for (index, center) in centers.enumerated() {
        if axis == "x" {
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-recess", dimensions: [11, 15, 1.8], position: [center, 10.8, edge], material: "l4-recess"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-door", dimensions: [9.5, 13, 1], position: [center, 10, edge + (edge < 0 ? 1.4 : -1.4)], material: "l4-dock-door"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-canopy", dimensions: [12, 3.5, 7], position: [center, 19.5, edge + (edge < 0 ? -2.8 : 2.8)], material: "l4-charcoal-steel"))
        } else {
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-recess", dimensions: [1.8, 15, 11], position: [edge, 10.8, center], material: "l4-recess"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-door", dimensions: [1, 13, 9.5], position: [edge + (edge < 0 ? 1.4 : -1.4), 10, center], material: "l4-dock-door"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-canopy", dimensions: [7, 3.5, 12], position: [edge + (edge < 0 ? -2.8 : 2.8), 19.5, center], material: "l4-charcoal-steel"))
        }
    }
    return result
}

private func l4FarEdgeDockBlocks(
    prefix: String,
    centers: [Double],
    axis: String,
    edge: Double
) -> [L4Block] {
    var result: [L4Block] = []
    for (index, center) in centers.enumerated() {
        if axis == "x" {
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-recess", dimensions: [11, 15, 1.8], position: [center, 10.8, edge], material: "l4-recess"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-door", dimensions: [9.5, 13, 1], position: [center, 10, edge + 1.4], material: "l4-dock-door"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-canopy", dimensions: [12, 3.5, 7], position: [center, 19.5, edge - 2.8], material: "l4-charcoal-steel"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-portal-shadow", dimensions: [9.5, 7, 1], position: [center, 25.5, edge + 1.8], material: "l4-recess"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-portal-cap", dimensions: [11, 3, 3], position: [center, 30.5, edge + 0.8], material: "l4-light-trim"))
        } else {
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-recess", dimensions: [1.8, 15, 11], position: [edge, 10.8, center], material: "l4-recess"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-door", dimensions: [1, 13, 9.5], position: [edge + 1.4, 10, center], material: "l4-dock-door"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-canopy", dimensions: [7, 3.5, 12], position: [edge - 2.8, 19.5, center], material: "l4-charcoal-steel"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-portal-shadow", dimensions: [1, 7, 9.5], position: [edge + 1.8, 25.5, center], material: "l4-recess"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-portal-cap", dimensions: [3, 3, 11], position: [edge + 0.8, 30.5, center], material: "l4-light-trim"))
        }
    }
    return result
}

private func l4NorthPlan() -> L4Plan {
    let centers = [-13.0, 0.0, 13.0]
    var blocks: [L4Block] = [
        L4Block(id: "n-high-bay-forge-hall", dimensions: [38, 44, 22], position: [-3, 25, 15], material: "l4-weathered-blue-steel"),
        L4Block(id: "n-lower-assembly-wing", dimensions: [18, 25, 30], position: [18.5, 15.5, 10.5], material: "l4-blue-steel-light"),
        L4Block(id: "n-heavy-loading-wall", dimensions: [40, 22, 4], position: [-1.2, 14, 8], material: "l4-warm-concrete"),
        L4Block(id: "n-open-freight-throat", dimensions: [42, 2.6, 34], position: [-1, 3.7, -9], material: "l4-concrete-shadow"),
        L4Block(id: "n-service-apron", dimensions: [44, 1.8, 12], position: [-1, 2.1, -22], material: "l4-apron"),
        L4Block(id: "n-control-laboratory-wing", dimensions: [14, 20, 14], position: [20, 13, 0], material: "l4-warm-concrete"),
        L4Block(id: "n-control-glazing", dimensions: [11, 7, 1.2], position: [20, 17, 7.6], material: "l4-control-glazing"),
        L4Block(id: "n-staff-door", dimensions: [6.5, 10, 1], position: [20, 8.5, 7.8], material: "l4-warm-glazing"),
        L4Block(id: "n-staff-canopy", dimensions: [9, 3.5, 6], position: [20, 15.5, 10.5], material: "l4-light-trim"),
        L4Block(id: "n-overhead-gantry", dimensions: [40, 5, 5], position: [-1, 42, 7], material: "l4-charcoal-steel"),
        L4Block(id: "n-pipe-bridge", dimensions: [30, 4, 4], position: [-4, 51, 15], material: "l4-duct-metal"),
        L4Block(id: "n-process-headhouse", dimensions: [12, 13, 11], position: [-14, 56.5, 14], material: "l4-oxide"),
    ]
    blocks += l4FarEdgeDockBlocks(
        prefix: "n",
        centers: centers,
        axis: "x",
        edge: 8.2
    )
    return L4Plan(
        direction: "north",
        geometryID: "industrial-l04-north-v02-heavy-fabrication-freight-throat",
        blocks: blocks,
        roofs: [
            L4Roof(id: "n-high-bay-monitor-roof", dimensions: [39, 4, 23], position: [-3, 49, 15], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
            L4Roof(id: "n-assembly-roof", dimensions: [19, 3.5, 31], position: [18.5, 29.8, 10.3], material: "l4-roof-membrane", trim: "l4-light-trim"),
            L4Roof(id: "n-control-roof", dimensions: [15, 3, 15], position: [19.8, 24.5, 0], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
        ],
        trims: [
            L4Block(id: "n-monitor-clerestory", dimensions: [24, 8, 8], position: [-4, 55, 15], material: "l4-control-glazing"),
            L4Block(id: "n-gantry-oxide-cap", dimensions: [38, 2.5, 5.5], position: [-1, 46, 7], material: "l4-oxide"),
            L4Block(id: "n-service-header", dimensions: [40, 3, 3], position: [-1, 31, 10], material: "l4-safety-ochre"),
        ],
        props: [
            L4Prop(id: "n-stack-a", kind: "explicit-cylinder", dimensions: [5.5, 25, 5.5], position: [-20, 62.5, 18], material: "l4-charcoal-steel"),
            L4Prop(id: "n-stack-b", kind: "explicit-cylinder", dimensions: [5, 21, 5], position: [-11, 60.5, 19], material: "l4-oxide"),
            L4Prop(id: "n-silo-a", kind: "explicit-cylinder", dimensions: [9, 18, 9], position: [8, 12, 20], material: "l4-process-metal"),
            L4Prop(id: "n-silo-b", kind: "explicit-cylinder", dimensions: [8, 15, 8], position: [18, 10.5, 21.3], material: "l4-oxide"),
            L4Prop(id: "n-roof-plant-a", kind: "explicit-box", dimensions: [9, 6, 8], position: [5, 55, 10], material: "l4-process-metal"),
            L4Prop(id: "n-roof-plant-b", kind: "explicit-box", dimensions: [8, 5, 8], position: [14.3, 34, 6], material: "l4-duct-metal"),
        ],
        facadeEdgeWorld: [[-28, -28], [28, -28]],
        entranceBase: [20, 3, -28],
        exclusion: [[-24, -28], [28, -28], [28, 10], [-24, 10]]
    )
}

private func l4EastPlan() -> L4Plan {
    let centers = [-14.0, 0.0, 14.0]
    var blocks: [L4Block] = [
        L4Block(id: "e-high-bay-forge-hall", dimensions: [38, 44, 46], position: [-7, 25, -2], material: "l4-weathered-blue-steel"),
        L4Block(id: "e-lower-assembly-wing", dimensions: [15, 25, 34], position: [19.5, 15.5, -5], material: "l4-blue-steel-light"),
        L4Block(id: "e-heavy-loading-wall", dimensions: [4, 22, 46], position: [18, 14, 0], material: "l4-warm-concrete"),
        L4Block(id: "e-service-apron", dimensions: [16, 1.8, 54], position: [20, 2.1, 0], material: "l4-apron"),
        L4Block(id: "e-control-laboratory-wing", dimensions: [18, 20, 14], position: [9, 13, 20], material: "l4-warm-concrete"),
        L4Block(id: "e-control-glazing", dimensions: [1.2, 7, 9], position: [18.6, 17, 22], material: "l4-control-glazing"),
        L4Block(id: "e-staff-door", dimensions: [1, 10, 6.5], position: [18.8, 8.5, 22], material: "l4-warm-glazing"),
        L4Block(id: "e-staff-canopy", dimensions: [7, 3.5, 8], position: [21.5, 15.5, 22], material: "l4-light-trim"),
        L4Block(id: "e-overhead-gantry", dimensions: [5, 5, 46], position: [8, 42, 0], material: "l4-charcoal-steel"),
        L4Block(id: "e-pipe-bridge", dimensions: [4, 4, 31], position: [-3, 51, -1], material: "l4-duct-metal"),
        L4Block(id: "e-process-headhouse", dimensions: [12, 13, 11], position: [-16, 56.5, -12], material: "l4-oxide"),
    ]
    blocks += l4DockBlocks(
        prefix: "e",
        centers: centers,
        axis: "z",
        edge: 20.2
    )
    return L4Plan(
        direction: "east",
        geometryID: "industrial-l04-east-v02-heavy-fabrication-gantry-campus",
        blocks: blocks,
        roofs: [
            L4Roof(id: "e-high-bay-monitor-roof", dimensions: [39, 4, 47], position: [-7, 49, -2], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
            L4Roof(id: "e-assembly-roof", dimensions: [16, 3.5, 35], position: [19.5, 29.8, -5], material: "l4-roof-membrane", trim: "l4-light-trim"),
            L4Roof(id: "e-control-roof", dimensions: [19, 3, 15], position: [9, 24.5, 20], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
        ],
        trims: [
            L4Block(id: "e-monitor-clerestory", dimensions: [24, 8, 9], position: [-8, 55, -4], material: "l4-control-glazing"),
            L4Block(id: "e-gantry-oxide-cap", dimensions: [5.5, 2.5, 44], position: [8, 46, 0], material: "l4-oxide"),
            L4Block(id: "e-service-header", dimensions: [3, 3, 44], position: [21, 31, 0], material: "l4-safety-ochre"),
        ],
        props: [
            L4Prop(id: "e-stack-a", kind: "explicit-cylinder", dimensions: [5.5, 25, 5.5], position: [-18, 62.5, -15], material: "l4-charcoal-steel"),
            L4Prop(id: "e-stack-b", kind: "explicit-cylinder", dimensions: [5, 21, 5], position: [-18, 60.5, -6], material: "l4-oxide"),
            L4Prop(id: "e-silo-a", kind: "explicit-cylinder", dimensions: [9, 18, 9], position: [-18, 12, 8], material: "l4-process-metal"),
            L4Prop(id: "e-silo-b", kind: "explicit-cylinder", dimensions: [8, 15, 8], position: [-17, 10.5, 19], material: "l4-oxide"),
            L4Prop(id: "e-roof-plant-a", kind: "explicit-box", dimensions: [9, 6, 8], position: [0, 55, -14], material: "l4-process-metal"),
            L4Prop(id: "e-roof-plant-b", kind: "explicit-box", dimensions: [8, 5, 8], position: [0.3, 55, -3], material: "l4-duct-metal"),
        ],
        facadeEdgeWorld: [[28, -28], [28, 28]],
        entranceBase: [28, 3, 22],
        exclusion: [[7, -27], [28, -27], [28, 27], [7, 27]]
    )
}

private func l4SouthPlan() -> L4Plan {
    let centers = [-14.0, 0.0, 14.0]
    var blocks: [L4Block] = [
        L4Block(id: "s-high-bay-forge-hall", dimensions: [42, 44, 38], position: [-3, 25, -7], material: "l4-weathered-blue-steel"),
        L4Block(id: "s-lower-assembly-wing", dimensions: [34, 25, 15], position: [4, 15.5, 19.5], material: "l4-blue-steel-light"),
        L4Block(id: "s-heavy-loading-wall", dimensions: [46, 22, 4], position: [0, 14, 18], material: "l4-warm-concrete"),
        L4Block(id: "s-service-apron", dimensions: [54, 1.8, 16], position: [0, 2.1, 20], material: "l4-apron"),
        L4Block(id: "s-control-laboratory-wing", dimensions: [18, 20, 14], position: [-18, 13, 9], material: "l4-warm-concrete"),
        L4Block(id: "s-control-glazing", dimensions: [8, 7, 1.2], position: [-23, 17, 18.6], material: "l4-control-glazing"),
        L4Block(id: "s-staff-door", dimensions: [6.5, 10, 1], position: [-23, 8.5, 18.8], material: "l4-warm-glazing"),
        L4Block(id: "s-staff-canopy", dimensions: [8, 3.5, 7], position: [-22.8, 15.5, 21.5], material: "l4-light-trim"),
        L4Block(id: "s-overhead-gantry", dimensions: [46, 5, 5], position: [0, 42, 8], material: "l4-charcoal-steel"),
        L4Block(id: "s-pipe-bridge", dimensions: [31, 4, 4], position: [-2, 51, -3], material: "l4-duct-metal"),
        L4Block(id: "s-process-headhouse", dimensions: [12, 13, 11], position: [13, 56.5, -16], material: "l4-oxide"),
    ]
    blocks += l4DockBlocks(
        prefix: "s",
        centers: centers,
        axis: "x",
        edge: 20.2
    )
    return L4Plan(
        direction: "south",
        geometryID: "industrial-l04-south-v02-heavy-fabrication-assembly-yard",
        blocks: blocks,
        roofs: [
            L4Roof(id: "s-high-bay-monitor-roof", dimensions: [43, 4, 39], position: [-3, 49, -7], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
            L4Roof(id: "s-assembly-roof", dimensions: [35, 3.5, 16], position: [4, 29.8, 19.5], material: "l4-roof-membrane", trim: "l4-light-trim"),
            L4Roof(id: "s-control-roof", dimensions: [19, 3, 15], position: [-18, 24.5, 9], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
        ],
        trims: [
            L4Block(id: "s-monitor-clerestory", dimensions: [25, 8, 9], position: [-4, 55, -8], material: "l4-control-glazing"),
            L4Block(id: "s-gantry-oxide-cap", dimensions: [44, 2.5, 5.5], position: [0, 46, 8], material: "l4-oxide"),
            L4Block(id: "s-service-header", dimensions: [44, 3, 3], position: [0, 31, 21], material: "l4-safety-ochre"),
        ],
        props: [
            L4Prop(id: "s-stack-a", kind: "explicit-cylinder", dimensions: [5.5, 25, 5.5], position: [18, 62.5, -15], material: "l4-charcoal-steel"),
            L4Prop(id: "s-stack-b", kind: "explicit-cylinder", dimensions: [5, 21, 5], position: [9, 60.5, -16], material: "l4-oxide"),
            L4Prop(id: "s-silo-a", kind: "explicit-cylinder", dimensions: [9, 18, 9], position: [-10, 12, -18], material: "l4-process-metal"),
            L4Prop(id: "s-silo-b", kind: "explicit-cylinder", dimensions: [8, 15, 8], position: [-20, 10.5, -16], material: "l4-oxide"),
            L4Prop(id: "s-roof-plant-a", kind: "explicit-box", dimensions: [9, 6, 8], position: [0, 55, -15], material: "l4-process-metal"),
            L4Prop(id: "s-roof-plant-b", kind: "explicit-box", dimensions: [8, 5, 8], position: [10, 55, -5], material: "l4-duct-metal"),
        ],
        facadeEdgeWorld: [[28, 28], [-28, 28]],
        entranceBase: [-23, 3, 28],
        exclusion: [[27, 7], [27, 28], [-27, 28], [-27, 7]]
    )
}

private func l4WestPlan() -> L4Plan {
    let centers = [-13.0, 0.0, 13.0]
    var blocks: [L4Block] = [
        L4Block(id: "w-high-bay-forge-hall", dimensions: [22, 44, 38], position: [15, 25, 3], material: "l4-weathered-blue-steel"),
        L4Block(id: "w-lower-assembly-wing", dimensions: [30, 25, 18], position: [10.5, 15.5, -19], material: "l4-blue-steel-light"),
        L4Block(id: "w-heavy-loading-wall", dimensions: [4, 22, 40], position: [8, 14, 1], material: "l4-warm-concrete"),
        L4Block(id: "w-open-freight-throat", dimensions: [34, 2.6, 42], position: [-9, 3.7, 0.5], material: "l4-concrete-shadow"),
        L4Block(id: "w-service-apron", dimensions: [12, 1.8, 44], position: [-22, 2.1, 1], material: "l4-apron"),
        L4Block(id: "w-control-laboratory-wing", dimensions: [14, 20, 14], position: [0, 13, -20], material: "l4-warm-concrete"),
        L4Block(id: "w-control-glazing", dimensions: [1.2, 7, 11], position: [7.6, 17, -20], material: "l4-control-glazing"),
        L4Block(id: "w-staff-door", dimensions: [1, 10, 6.5], position: [7.8, 8.5, -20], material: "l4-warm-glazing"),
        L4Block(id: "w-staff-canopy", dimensions: [6, 3.5, 9], position: [10.5, 15.5, -20], material: "l4-light-trim"),
        L4Block(id: "w-overhead-gantry", dimensions: [5, 5, 40], position: [7, 42, 1], material: "l4-charcoal-steel"),
        L4Block(id: "w-pipe-bridge", dimensions: [4, 4, 30], position: [15, 51, 4], material: "l4-duct-metal"),
        L4Block(id: "w-process-headhouse", dimensions: [11, 13, 12], position: [13.5, 56.5, 14], material: "l4-oxide"),
    ]
    blocks += l4FarEdgeDockBlocks(
        prefix: "w",
        centers: centers,
        axis: "z",
        edge: 8.2
    )
    return L4Plan(
        direction: "west",
        geometryID: "industrial-l04-west-v02-heavy-fabrication-freight-throat",
        blocks: blocks,
        roofs: [
            L4Roof(id: "w-high-bay-monitor-roof", dimensions: [23, 4, 39], position: [15, 49, 3], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
            L4Roof(id: "w-assembly-roof", dimensions: [31, 3.5, 18], position: [11, 29.8, -19], material: "l4-roof-membrane", trim: "l4-light-trim"),
            L4Roof(id: "w-control-roof", dimensions: [15, 3, 15], position: [0, 24.5, -20], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
        ],
        trims: [
            L4Block(id: "w-monitor-clerestory", dimensions: [9, 8, 24], position: [15, 55, 4], material: "l4-control-glazing"),
            L4Block(id: "w-gantry-oxide-cap", dimensions: [5.5, 2.5, 38], position: [7, 46, 1], material: "l4-oxide"),
            L4Block(id: "w-service-header", dimensions: [3, 3, 40], position: [10, 31, 1], material: "l4-safety-ochre"),
        ],
        props: [
            L4Prop(id: "w-stack-a", kind: "explicit-cylinder", dimensions: [5.5, 25, 5.5], position: [18, 62.5, 18], material: "l4-charcoal-steel"),
            L4Prop(id: "w-stack-b", kind: "explicit-cylinder", dimensions: [5, 21, 5], position: [19, 60.5, 9], material: "l4-oxide"),
            L4Prop(id: "w-silo-a", kind: "explicit-cylinder", dimensions: [9, 18, 9], position: [20, 12, -8], material: "l4-process-metal"),
            L4Prop(id: "w-silo-b", kind: "explicit-cylinder", dimensions: [8, 15, 8], position: [21, 10.5, -18], material: "l4-oxide"),
            L4Prop(id: "w-roof-plant-a", kind: "explicit-box", dimensions: [8, 6, 9], position: [10, 55, 0], material: "l4-process-metal"),
            L4Prop(id: "w-roof-plant-b", kind: "explicit-box", dimensions: [8, 5, 8], position: [10, 34, -12], material: "l4-duct-metal"),
        ],
        facadeEdgeWorld: [[-28, 28], [-28, -28]],
        entranceBase: [-28, 3, -20],
        exclusion: [[-28, 28], [-28, -24], [10, -24], [10, 28]]
    )
}

private func l4FoundryConceptPlan() -> L4Plan {
    L4Plan(
        direction: "concept-foundry",
        geometryID: "industrial-l04-concept-a-broad-turbine-foundry",
        blocks: [
            L4Block(id: "a-turbine-hall", dimensions: [46, 39, 42], position: [-4, 22.5, -2], material: "l4-weathered-blue-steel"),
            L4Block(id: "a-casting-wing", dimensions: [18, 24, 34], position: [19, 15, 2], material: "l4-warm-concrete"),
            L4Block(id: "a-furnace-house", dimensions: [15, 47, 18], position: [-17, 26.5, 14], material: "l4-oxide"),
            L4Block(id: "a-service-recess", dimensions: [4, 20, 40], position: [19, 13, -4], material: "l4-recess"),
            L4Block(id: "a-monitor-one", dimensions: [22, 8, 7], position: [-10, 46, -11], material: "l4-control-glazing"),
            L4Block(id: "a-monitor-two", dimensions: [22, 8, 7], position: [-10, 46, 0], material: "l4-control-glazing"),
            L4Block(id: "a-monitor-three", dimensions: [22, 8, 7], position: [-10, 46, 11], material: "l4-control-glazing"),
        ],
        roofs: [
            L4Roof(id: "a-hall-roof", dimensions: [47, 4, 43], position: [-4, 44, -2], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
        ],
        trims: [
            L4Block(id: "a-casting-header", dimensions: [3, 4, 34], position: [21, 28, 2], material: "l4-safety-ochre"),
        ],
        props: [
            L4Prop(id: "a-furnace-stack", kind: "explicit-cylinder", dimensions: [7, 30, 7], position: [-18, 65, 13], material: "l4-charcoal-steel"),
            L4Prop(id: "a-quench-tank", kind: "explicit-cylinder", dimensions: [10, 18, 10], position: [8, 12, 18], material: "l4-process-metal"),
        ],
        facadeEdgeWorld: [[28, -28], [28, 28]],
        entranceBase: [28, 3, 20],
        exclusion: [[8, -27], [28, -27], [28, 27], [8, 27]]
    )
}

private func l4PrecisionConceptPlan() -> L4Plan {
    L4Plan(
        direction: "concept-precision",
        geometryID: "industrial-l04-concept-b-asymmetric-precision-campus",
        blocks: [
            L4Block(id: "b-clean-assembly-hall", dimensions: [40, 35, 45], position: [-6, 20.5, -2], material: "l4-blue-steel-light"),
            L4Block(id: "b-metrology-wing", dimensions: [17, 24, 38], position: [19.5, 15, 0], material: "l4-warm-concrete"),
            L4Block(id: "b-elevated-control", dimensions: [18, 16, 18], position: [7, 38, 15], material: "l4-control-glazing"),
            L4Block(id: "b-process-spine", dimensions: [7, 11, 43], position: [-1, 45, -1], material: "l4-duct-metal"),
            L4Block(id: "b-entry-court", dimensions: [14, 10, 16], position: [16, 8, 18], material: "l4-warm-glazing"),
        ],
        roofs: [
            L4Roof(id: "b-assembly-roof", dimensions: [41, 4, 46], position: [-6, 40, -2], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
            L4Roof(id: "b-control-roof", dimensions: [19, 3, 19], position: [7, 47.5, 15], material: "l4-roof-membrane", trim: "l4-light-trim"),
        ],
        trims: [
            L4Block(id: "b-control-bridge", dimensions: [25, 5, 6], position: [6, 33, 9], material: "l4-light-trim"),
        ],
        props: [
            L4Prop(id: "b-vacuum-stack", kind: "explicit-cylinder", dimensions: [5, 20, 5], position: [-18, 54, -15], material: "l4-charcoal-steel"),
            L4Prop(id: "b-roof-plant", kind: "explicit-box", dimensions: [11, 8, 10], position: [-9, 48, 9], material: "l4-process-metal"),
        ],
        facadeEdgeWorld: [[28, -28], [28, 28]],
        entranceBase: [28, 3, 20],
        exclusion: [[8, -27], [28, -27], [28, 27], [8, 27]]
    )
}

private func l4Registration(_ direction: String) -> [String: Any] {
    let edge: [[Double]]
    let socket: [Double]
    let doors: [[Double]]
    switch direction {
    case "north":
        edge = [[768, 640], [1024, 768]]
        socket = [896, 704]
        doors = [[858, 685], [934, 723]]
    case "east":
        edge = [[1024, 768], [768, 896]]
        socket = [896, 832]
        doors = [[934, 813], [858, 851]]
    case "south":
        edge = [[768, 896], [512, 768]]
        socket = [640, 832]
        doors = [[678, 851], [602, 813]]
    default:
        edge = [[512, 768], [768, 640]]
        socket = [640, 704]
        doors = [[602, 723], [678, 685]]
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
        "doorBaseSource": doors,
        "presentationEnvelopeSource": [256, 20, 1280, 896],
        "shadowEnvelopeSource": [768, 512, 1456, 976],
        "orientationTransform": "none",
    ]
}

private func l4Sampling() -> [String: Any] {
    [
        "contractID": "play027-deterministic-4x-no-msaa-lanczos-v3",
        "sourceRevisionBinding": "source-v03",
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

private func l4Descriptor(
    plan: L4Plan,
    toolchainHash: String,
    materialHash: String
) -> [String: Any] {
    [
        "schema": 2,
        "task": "PLAY-027",
        "sceneGeometryID": plan.geometryID,
        "logicalBuildingID": "industrial_l04",
        "family": "industrial",
        "level": 4,
        "variantID": "variant-0",
        "viewDirection": plan.direction,
        "sourceRevision": "source-v03",
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
            "file": "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/toolchain/toolchain-industrial-l04-source-v03.json",
            "sha256": toolchainHash,
        ],
        "styleAnchor": [
            "role": "global-style-anchor",
            "file": l4StyleAnchor,
            "sha256": l4StyleAnchorSHA,
        ],
        "materialLibrary": [
            "role": "industrial-l04-material-library",
            "file": "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v03/materials/industrial-l04-turbine-v03.json",
            "sha256": materialHash,
        ],
        "registration": l4Registration(plan.direction),
        "camera": [
            "projection": "orthographic-2-to-1",
            "yawDegrees": 45,
            "elevationDegrees": 30,
            "orthographicScale": l4OrthographicScale,
            "renderViewportPixels": [1536, 1024],
            "oversamplingFactor": 4,
            "positionWorld": [96, 96, 96],
            "targetWorld": [0, 20, 0],
            "sourceGroundCenter": [768, 768],
            "postProjectionOffsetPixels": [0, 128],
        ],
        "sampling": l4Sampling(),
        "light": [
            "keyOrigin": [-80, 120, -80],
            "keyIntensity": 0,
            "keyColorRGBA": [1.0, 0.94, 0.84, 1.0],
            "ambientIntensity": 0,
            "ambientColorRGBA": [0.36, 0.43, 0.50, 1.0],
            "shadowVectorSource": [2, 1],
            "shadowOpacity": 0.34,
            "shadowBlurSourcePixels": 0,
            "shadowReceiver": "authored-contact-polygon",
        ],
        "building": [
            "width": 56,
            "depth": 56,
            "foundationHeight": 3,
            "floorHeight": 12,
            "floors": 5,
            "wallHeight": 52,
            "roofHeight": 6,
            "roofOverhang": 0.8,
            "wallMaterialID": "l4-weathered-blue-steel",
            "trimMaterialID": "l4-light-trim",
            "roofMaterialID": "l4-roof-membrane",
            "foundationMaterialID": "l4-foundation",
            "chimney": [
                "positionWorld": [0, 58, 0],
                "dimensions": [5, 18, 5],
                "materialID": "l4-charcoal-steel",
            ],
            "massingProfile": "industrial-l04-heavy-fabrication-gantry-campus",
            "massBlocks": plan.blocks.map(\.json),
            "roofVolumes": plan.roofs.map(\.json),
            "trimBands": plan.trims.map(\.json),
            "usesLegacyDomesticDetails": false,
            "usesExplicitComponentGeometry": true,
            "foundationDimensions": [56, 2.4, 56],
            "foundationPositionWorld": [0, 1.2, 0],
        ],
        "facades": [[
            "id": "l4-\(plan.direction)-road-frontage",
            "direction": plan.direction,
            "edgeWorld": plan.facadeEdgeWorld,
            "materialID": "l4-warm-concrete",
            "hasEntrance": true,
            "windowBays": [],
            "windowRhythms": [],
        ]],
        "entrance": [
            "facadeID": "l4-\(plan.direction)-road-frontage",
            "baseWorld": plan.entranceBase,
            "width": 5.5,
            "height": 10,
            "depth": 1,
            "doorMaterialID": "l4-warm-glazing",
            "surroundMaterialID": "l4-light-trim",
            "stepCount": 1,
            "stepRun": 1.2,
            "canopyDepth": 4,
            "hingeSide": "right",
            "pavilionWidth": 13,
            "pavilionDepth": 12,
            "pavilionHeight": 24,
            "pavilionRoofHeight": 3,
            "pavilionMaterialID": "l4-warm-concrete",
            "porchWidth": 8,
            "porchColumnWidth": 1.2,
            "porchLateralOffset": 0,
            "style": "industrial-control-quality-entry",
        ],
        "props": plan.props.map(\.json),
        "occlusionExclusions": [[
            "id": "l4-\(plan.direction)-frontage-visibility",
            "purpose": "keep three heavy freight bays and separate staff entrance visible at native-2x",
            "polygonWorld": plan.exclusion,
        ]],
    ]
}

private func l4Project(_ point: [Double]) -> L4Vertex {
    let rootTwo = sqrt(2.0)
    let cameraX = (point[0] - point[2]) / rootTwo
    let cameraY =
        point[1] * cos(.pi / 6.0)
        - (point[0] + point[2]) / rootTwo * sin(.pi / 6.0)
    let depth =
        (point[0] + point[2]) / rootTwo * cos(.pi / 6.0)
        + point[1] * sin(.pi / 6.0)
    return L4Vertex(
        x: 768 + cameraX * l4PixelsPerWorld,
        y: 256 + cameraY * l4PixelsPerWorld,
        depth: depth
    )
}

private func l4Faces(
    dimensions: [Double],
    position: [Double],
    material: String
) -> [L4Face] {
    let half = dimensions.map { $0 / 2 }
    let minimum = zip(position, half).map(-)
    let maximum = zip(position, half).map(+)
    let definitions: [(String, [[Double]])] = [
        ("+x", [[maximum[0], minimum[1], minimum[2]], [maximum[0], maximum[1], minimum[2]], [maximum[0], maximum[1], maximum[2]], [maximum[0], minimum[1], maximum[2]]]),
        ("+z", [[maximum[0], minimum[1], maximum[2]], [maximum[0], maximum[1], maximum[2]], [minimum[0], maximum[1], maximum[2]], [minimum[0], minimum[1], maximum[2]]]),
        ("+y", [[minimum[0], maximum[1], minimum[2]], [minimum[0], maximum[1], maximum[2]], [maximum[0], maximum[1], maximum[2]], [maximum[0], maximum[1], minimum[2]]]),
    ]
    return definitions.map { orientation, points in
        L4Face(
            materialID: material,
            orientation: orientation,
            vertices: points.map(l4Project)
        )
    }
}

private func l4ColorMap(_ materials: [[String: Any]]) -> [String: [Double]] {
    Dictionary(uniqueKeysWithValues: materials.compactMap { material in
        guard
            let id = material["id"] as? String,
            let color = material["baseColorRGBA"] as? [Double]
        else { return nil }
        return (id, color)
    })
}

private func l4Context(width: Int, height: Int) throws -> CGContext {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw IndustrialL4TurbinePrepixelError.invalid("could not allocate context")
    }
    context.interpolationQuality = .high
    return context
}

private func l4RasterizeTriangle(
    _ triangle: [L4Vertex],
    color: [UInt8],
    pixels: inout [UInt8],
    depthBuffer: inout [Double]
) throws {
    guard triangle.count == 3, color.count == 4 else {
        throw IndustrialL4TurbinePrepixelError.invalid("invalid triangle input")
    }
    let a = triangle[0]
    let b = triangle[1]
    let c = triangle[2]
    let denominator =
        (b.y - c.y) * (a.x - c.x)
        + (c.x - b.x) * (a.y - c.y)
    guard abs(denominator) > 0.000_001 else { return }
    let minimumX = max(0, Int(floor(min(a.x, min(b.x, c.x)))))
    let maximumX = min(
        l4SourceWidth - 1,
        Int(ceil(max(a.x, max(b.x, c.x))))
    )
    let minimumY = max(0, Int(floor(min(a.y, min(b.y, c.y)))))
    let maximumY = min(
        l4SourceHeight - 1,
        Int(ceil(max(a.y, max(b.y, c.y))))
    )
    guard minimumX <= maximumX, minimumY <= maximumY else { return }
    for y in minimumY...maximumY {
        for x in minimumX...maximumX {
            let sampleX = Double(x) + 0.5
            let sampleY = Double(y) + 0.5
            let weightA =
                ((b.y - c.y) * (sampleX - c.x)
                    + (c.x - b.x) * (sampleY - c.y))
                / denominator
            let weightB =
                ((c.y - a.y) * (sampleX - c.x)
                    + (a.x - c.x) * (sampleY - c.y))
                / denominator
            let weightC = 1 - weightA - weightB
            guard
                weightA >= -0.000_001,
                weightB >= -0.000_001,
                weightC >= -0.000_001
            else { continue }
            let depth =
                weightA * a.depth + weightB * b.depth + weightC * c.depth
            let rasterY = l4SourceHeight - 1 - y
            let pixelIndex = rasterY * l4SourceWidth + x
            guard depth > depthBuffer[pixelIndex] else { continue }
            depthBuffer[pixelIndex] = depth
            let byteIndex = pixelIndex * 4
            pixels[byteIndex] = color[0]
            pixels[byteIndex + 1] = color[1]
            pixels[byteIndex + 2] = color[2]
            pixels[byteIndex + 3] = color[3]
        }
    }
}

private enum L4RenderMode {
    case color
    case grayscale
    case clay
}

private func l4RenderPlan(
    _ plan: L4Plan,
    colors: [String: [Double]],
    mode: L4RenderMode
) throws -> CGImage {
    let background: [UInt8] = [25, 29, 31, 255]
    var pixels = [UInt8](
        repeating: 0,
        count: l4SourceWidth * l4SourceHeight * 4
    )
    for index in stride(from: 0, to: pixels.count, by: 4) {
        pixels[index] = background[0]
        pixels[index + 1] = background[1]
        pixels[index + 2] = background[2]
        pixels[index + 3] = background[3]
    }
    var depthBuffer = [Double](
        repeating: -Double.greatestFiniteMagnitude,
        count: l4SourceWidth * l4SourceHeight
    )
    let foundation = L4Block(
        id: "foundation",
        dimensions: [56, 2.4, 56],
        position: [0, 1.2, 0],
        material: "l4-foundation"
    )
    var faces = l4Faces(
        dimensions: foundation.dimensions,
        position: foundation.position,
        material: foundation.material
    )
    for block in plan.blocks + plan.trims {
        faces += l4Faces(
            dimensions: block.dimensions,
            position: block.position,
            material: block.material
        )
    }
    for roof in plan.roofs {
        faces += l4Faces(
            dimensions: roof.dimensions,
            position: roof.position,
            material: roof.material
        )
    }
    for prop in plan.props {
        faces += l4Faces(
            dimensions: prop.dimensions,
            position: prop.position,
            material: prop.material
        )
    }
    for face in faces {
        var rgba = colors[face.materialID] ?? [0.5, 0.5, 0.5, 1]
        if mode == .clay {
            rgba = [0.58, 0.54, 0.48, 1]
        }
        let factor: Double
        switch face.orientation {
        case "+y": factor = 1.10
        case "+x": factor = 0.88
        default: factor = 0.70
        }
        for index in 0..<3 {
            rgba[index] = min(1, rgba[index] * factor)
        }
        if mode == .grayscale {
            let luma = rgba[0] * 0.2126 + rgba[1] * 0.7152
                + rgba[2] * 0.0722
            rgba = [luma, luma, luma, 1]
        }
        let color = rgba.map {
            UInt8(max(0, min(255, Int(($0 * 255).rounded()))))
        }
        try l4RasterizeTriangle(
            [face.vertices[0], face.vertices[1], face.vertices[2]],
            color: color,
            pixels: &pixels,
            depthBuffer: &depthBuffer
        )
        try l4RasterizeTriangle(
            [face.vertices[0], face.vertices[2], face.vertices[3]],
            color: color,
            pixels: &pixels,
            depthBuffer: &depthBuffer
        )
    }
    guard
        let provider = CGDataProvider(data: Data(pixels) as CFData),
        let image = CGImage(
            width: l4SourceWidth,
            height: l4SourceHeight,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: l4SourceWidth * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(
                rawValue:
                    CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "could not render analytic plan"
        )
    }
    return image
}

private func l4DrawText(
    _ text: String,
    in context: CGContext,
    at point: CGPoint,
    size: CGFloat,
    color: CGColor
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: .semibold),
        .foregroundColor: NSColor(cgColor: color) ?? .white,
    ]
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: attributes)
    )
    context.textPosition = point
    CTLineDraw(line, context)
}

private func l4DrawAspect(
    _ image: CGImage,
    in context: CGContext,
    rect: CGRect,
    inset: CGFloat = 0
) {
    let available = rect.insetBy(dx: inset, dy: inset)
    let scale = min(
        available.width / CGFloat(image.width),
        available.height / CGFloat(image.height)
    )
    let width = CGFloat(image.width) * scale
    let height = CGFloat(image.height) * scale
    context.draw(
        image,
        in: CGRect(
            x: available.midX - width / 2,
            y: available.midY - height / 2,
            width: width,
            height: height
        )
    )
}

private func l4Sheet(
    title: String,
    images: [CGImage],
    labels: [String],
    panelWidth: Int,
    panelHeight: Int
) throws -> CGImage {
    let titleHeight = 70
    let context = try l4Context(
        width: panelWidth * 2,
        height: panelHeight * 2 + titleHeight
    )
    let background = CGColor(
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        components: [0.075, 0.086, 0.092, 1]
    )!
    context.setFillColor(background)
    context.fill(
        CGRect(
            x: 0,
            y: 0,
            width: panelWidth * 2,
            height: panelHeight * 2 + titleHeight
        )
    )
    l4DrawText(
        title,
        in: context,
        at: CGPoint(x: 24, y: panelHeight * 2 + 22),
        size: 30,
        color: CGColor(gray: 0.96, alpha: 1)
    )
    for (index, image) in images.enumerated() {
        let column = index % 2
        let row = 1 - index / 2
        let panel = CGRect(
            x: column * panelWidth,
            y: row * panelHeight,
            width: panelWidth,
            height: panelHeight
        )
        l4DrawAspect(image, in: context, rect: panel)
        l4DrawText(
            labels[index],
            in: context,
            at: CGPoint(x: panel.minX + 20, y: panel.minY + 18),
            size: 22,
            color: CGColor(gray: 0.94, alpha: 1)
        )
    }
    guard let image = context.makeImage() else {
        throw IndustrialL4TurbinePrepixelError.invalid("could not compose sheet")
    }
    return image
}

private func l4LoadImage(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "could not load image: \(url.path)"
        )
    }
    return image
}

private func l4Grayscale(_ image: CGImage) throws -> CGImage {
    let context = try l4Context(width: image.width, height: image.height)
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "could not access grayscale image buffer"
        )
    }
    for index in 0..<(image.width * image.height) {
        let byte = index * 4
        let red = Double(data[byte]) * 0.2126
        let green = Double(data[byte + 1]) * 0.7152
        let blue = Double(data[byte + 2]) * 0.0722
        let lumaValue = min(255, Int(red + green + blue))
        let luma = UInt8(lumaValue)
        data[byte] = luma
        data[byte + 1] = luma
        data[byte + 2] = luma
    }
    guard let grayscale = context.makeImage() else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "could not create grayscale image"
        )
    }
    return grayscale
}

private func l4ComparisonStrip(
    title: String,
    images: [CGImage],
    labels: [String],
    cellWidth: Int,
    cellHeight: Int
) throws -> CGImage {
    let titleHeight = 78
    let context = try l4Context(
        width: cellWidth * images.count,
        height: cellHeight + titleHeight
    )
    context.setFillColor(
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [0.075, 0.086, 0.092, 1]
        )!
    )
    context.fill(
        CGRect(
            x: 0,
            y: 0,
            width: cellWidth * images.count,
            height: cellHeight + titleHeight
        )
    )
    l4DrawText(
        title,
        in: context,
        at: CGPoint(x: 24, y: cellHeight + 26),
        size: 30,
        color: CGColor(gray: 0.96, alpha: 1)
    )
    for (index, image) in images.enumerated() {
        let rect = CGRect(
            x: index * cellWidth,
            y: 0,
            width: cellWidth,
            height: cellHeight
        )
        l4DrawAspect(image, in: context, rect: rect, inset: 24)
        l4DrawText(
            labels[index],
            in: context,
            at: CGPoint(x: rect.minX + 20, y: 20),
            size: 21,
            color: CGColor(gray: 0.94, alpha: 1)
        )
    }
    guard let image = context.makeImage() else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "could not compose comparison"
        )
    }
    return image
}

private func l4Resize(
    _ image: CGImage,
    width: Int,
    height: Int
) throws -> CGImage {
    let context = try l4Context(width: width, height: height)
    context.interpolationQuality = .high
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: width, height: height)
    )
    guard let resized = context.makeImage() else {
        throw IndustrialL4TurbinePrepixelError.invalid("could not resize image")
    }
    return resized
}

private func l4ExactSizeStrip(
    title: String,
    images: [CGImage],
    labels: [String]
) throws -> CGImage {
    let cellWidth = 360
    let cellHeight = 250
    let titleHeight = 78
    let context = try l4Context(
        width: cellWidth * images.count,
        height: cellHeight + titleHeight
    )
    context.setFillColor(
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [0.075, 0.086, 0.092, 1]
        )!
    )
    context.fill(
        CGRect(
            x: 0,
            y: 0,
            width: cellWidth * images.count,
            height: cellHeight + titleHeight
        )
    )
    l4DrawText(
        title,
        in: context,
        at: CGPoint(x: 24, y: cellHeight + 26),
        size: 30,
        color: CGColor(gray: 0.96, alpha: 1)
    )
    for (index, image) in images.enumerated() {
        let originX = index * cellWidth
        let drawX = originX + (cellWidth - image.width) / 2
        let drawY = 46 + (cellHeight - 46 - image.height) / 2
        context.draw(
            image,
            in: CGRect(
                x: drawX,
                y: drawY,
                width: image.width,
                height: image.height
            )
        )
        l4DrawText(
            labels[index],
            in: context,
            at: CGPoint(x: originX + 20, y: 18),
            size: 21,
            color: CGColor(gray: 0.94, alpha: 1)
        )
    }
    guard let output = context.makeImage() else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "could not compose exact-size strip"
        )
    }
    return output
}

private func l4StagedComparison(
    regular: CGImage,
    compact: CGImage,
    l4Color: CGImage,
    l4Gray: CGImage
) throws -> CGImage {
    let context = try l4Context(width: 1800, height: 1120)
    context.setFillColor(
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [0.06, 0.075, 0.08, 1]
        )!
    )
    context.fill(CGRect(x: 0, y: 0, width: 1800, height: 1120))
    l4DrawText(
        "R2 staged value system + Industrial L4 analytic target",
        in: context,
        at: CGPoint(x: 28, y: 1068),
        size: 34,
        color: CGColor(gray: 0.96, alpha: 1)
    )
    l4DrawAspect(
        regular,
        in: context,
        rect: CGRect(x: 20, y: 530, width: 880, height: 500),
        inset: 10
    )
    l4DrawAspect(
        compact,
        in: context,
        rect: CGRect(x: 900, y: 530, width: 880, height: 500),
        inset: 10
    )
    l4DrawAspect(
        l4Color,
        in: context,
        rect: CGRect(x: 300, y: 50, width: 600, height: 440),
        inset: 10
    )
    l4DrawAspect(
        l4Gray,
        in: context,
        rect: CGRect(x: 900, y: 50, width: 600, height: 440),
        inset: 10
    )
    l4DrawText(
        "exact R2 regular frame",
        in: context,
        at: CGPoint(x: 40, y: 545),
        size: 22,
        color: CGColor(gray: 0.96, alpha: 1)
    )
    l4DrawText(
        "exact R2 compact frame",
        in: context,
        at: CGPoint(x: 920, y: 545),
        size: 22,
        color: CGColor(gray: 0.96, alpha: 1)
    )
    l4DrawText(
        "analytic East L4 color - non-authority",
        in: context,
        at: CGPoint(x: 340, y: 60),
        size: 22,
        color: CGColor(gray: 0.96, alpha: 1)
    )
    l4DrawText(
        "analytic East L4 grayscale - non-authority",
        in: context,
        at: CGPoint(x: 930, y: 60),
        size: 22,
        color: CGColor(gray: 0.96, alpha: 1)
    )
    guard let image = context.makeImage() else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "could not compose staged comparison"
        )
    }
    return image
}

private func l4BoxBounds(_ block: L4Block) -> [[Double]] {
    [
        zip(block.position, block.dimensions.map { $0 / 2 }).map(-),
        zip(block.position, block.dimensions.map { $0 / 2 }).map(+),
    ]
}

private func l4AllBlocks(_ plan: L4Plan) -> [L4Block] {
    [
        L4Block(
            id: "foundation",
            dimensions: [56, 2.4, 56],
            position: [0, 1.2, 0],
            material: "l4-foundation"
        ),
    ] + plan.blocks + plan.trims
        + plan.roofs.map {
            L4Block(
                id: $0.id,
                dimensions: $0.dimensions,
                position: $0.position,
                material: $0.material
            )
        }
        + plan.props.map {
            L4Block(
                id: $0.id,
                dimensions: $0.dimensions,
                position: $0.position,
                material: $0.material
            )
        }
}

private func l4Bounds(_ plan: L4Plan) -> [[Double]] {
    let bounds = l4AllBlocks(plan).map(l4BoxBounds)
    return [
        [
            bounds.map { $0[0][0] }.min()!,
            bounds.map { $0[0][1] }.min()!,
            bounds.map { $0[0][2] }.min()!,
        ],
        [
            bounds.map { $0[1][0] }.max()!,
            bounds.map { $0[1][1] }.max()!,
            bounds.map { $0[1][2] }.max()!,
        ],
    ]
}

private func l4Overlaps(
    _ aMin: Double,
    _ aMax: Double,
    _ bMin: Double,
    _ bMax: Double
) -> Bool {
    min(aMax, bMax) - max(aMin, bMin) > 0.000_001
}

private func l4VisiblePlaneConflicts(_ plan: L4Plan) -> [[String: Any]] {
    let blocks = l4AllBlocks(plan).filter { $0.id != "foundation" }
    var conflicts: [[String: Any]] = []
    for firstIndex in blocks.indices {
        for secondIndex in blocks.indices where secondIndex > firstIndex {
            let first = blocks[firstIndex]
            let second = blocks[secondIndex]
            let a = l4BoxBounds(first)
            let b = l4BoxBounds(second)
            let samePositiveX = abs(a[1][0] - b[1][0]) <= 0.000_001
                && l4Overlaps(a[0][1], a[1][1], b[0][1], b[1][1])
                && l4Overlaps(a[0][2], a[1][2], b[0][2], b[1][2])
            let samePositiveZ = abs(a[1][2] - b[1][2]) <= 0.000_001
                && l4Overlaps(a[0][0], a[1][0], b[0][0], b[1][0])
                && l4Overlaps(a[0][1], a[1][1], b[0][1], b[1][1])
            if (samePositiveX || samePositiveZ)
                && first.material != second.material
            {
                conflicts.append([
                    "first": first.id,
                    "second": second.id,
                    "plane": samePositiveX ? "+x" : "+z",
                ])
            }
        }
    }
    return conflicts
}

private func l4MaterialReferences(_ plan: L4Plan) -> [String] {
    var values = [
        "l4-weathered-blue-steel", "l4-light-trim",
        "l4-roof-membrane", "l4-foundation", "l4-charcoal-steel",
        "l4-warm-concrete", "l4-warm-glazing",
    ]
    values += plan.blocks.map(\.material)
    values += plan.roofs.flatMap { [$0.material, $0.trim] }
    values += plan.trims.map(\.material)
    values += plan.props.map(\.material)
    return Array(Set(values)).sorted()
}

private func l4QuantizedLuma(_ color: [Double]) -> Int {
    let luma = (
        color[0] * 0.2126 + color[1] * 0.7152 + color[2] * 0.0722
    ) * 255
    let stepped = Int(((luma - 8) / 32).rounded()) * 32 + 8
    return max(8, min(248, stepped))
}

private func l4RGBA(_ image: CGImage) throws -> [UInt8] {
    let context = try l4Context(width: image.width, height: image.height)
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    guard let data = context.data else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "could not access image pixels"
        )
    }
    return Array(
        UnsafeBufferPointer(
            start: data.assumingMemoryBound(to: UInt8.self),
            count: image.width * image.height * 4
        )
    )
}

private func l4AnalyticMetrics(
    _ image: CGImage,
    safetyColor: [Double]
) throws -> [String: Any] {
    let pixels = try l4RGBA(image)
    let background: [UInt8] = [25, 29, 31]
    let factors = [1.10, 0.88, 0.70]
    let safetyColors = Set(factors.map { factor in
        safetyColor.prefix(3).map {
            UInt8(max(0, min(255, Int(($0 * factor * 255).rounded()))))
        }
    }.map { $0.map(String.init).joined(separator: ",") })
    var occupied = 0
    var safety = 0
    for index in stride(from: 0, to: pixels.count, by: 4) {
        let rgb = [pixels[index], pixels[index + 1], pixels[index + 2]]
        if rgb != background {
            occupied += 1
            let key = rgb.map(String.init).joined(separator: ",")
            if safetyColors.contains(key) {
                safety += 1
            }
        }
    }
    return [
        "occupiedAnalyticPixels": occupied,
        "safetyAccentPixels": safety,
        "safetyAccentShare": occupied == 0
            ? 0
            : Double(safety) / Double(occupied),
    ]
}

private func l4SilhouetteMetrics(
    acceptedL3: CGImage,
    analyticL4: CGImage
) throws -> [String: Any] {
    guard
        acceptedL3.width == analyticL4.width,
        acceptedL3.height == analyticL4.height
    else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "silhouette comparison dimensions differ"
        )
    }
    let accepted = try l4RGBA(acceptedL3)
    let candidate = try l4RGBA(analyticL4)
    let count = acceptedL3.width * acceptedL3.height
    var acceptedMask = [Bool](repeating: false, count: count)
    var candidateMask = [Bool](repeating: false, count: count)
    for index in 0..<count {
        let byte = index * 4
        acceptedMask[index] = !(
            accepted[byte] == 255
                && accepted[byte + 1] == 0
                && accepted[byte + 2] == 255
        )
        candidateMask[index] = !(
            candidate[byte] == 25
                && candidate[byte + 1] == 29
                && candidate[byte + 2] == 31
        )
    }
    var intersection = 0
    var union = 0
    var acceptedBoundary = Set<Int>()
    var candidateBoundary = Set<Int>()
    let width = acceptedL3.width
    let height = acceptedL3.height
    for y in 1..<(height - 1) {
        for x in 1..<(width - 1) {
            let index = y * width + x
            if acceptedMask[index] || candidateMask[index] { union += 1 }
            if acceptedMask[index] && candidateMask[index] {
                intersection += 1
            }
            let neighbors = [
                index - 1, index + 1, index - width, index + width,
            ]
            if acceptedMask[index]
                && neighbors.contains(where: { !acceptedMask[$0] })
            {
                acceptedBoundary.insert(index)
            }
            if candidateMask[index]
                && neighbors.contains(where: { !candidateMask[$0] })
            {
                candidateBoundary.insert(index)
            }
        }
    }
    let boundaryUnion = acceptedBoundary.union(candidateBoundary)
    let boundaryDifference = acceptedBoundary.symmetricDifference(
        candidateBoundary
    )
    return [
        "acceptedL3OccupiedPixels": acceptedMask.filter { $0 }.count,
        "analyticL4OccupiedPixels": candidateMask.filter { $0 }.count,
        "silhouetteMaskIntersectionOverUnion": union == 0
            ? 0
            : Double(intersection) / Double(union),
        "silhouetteBoundaryChangeShare": boundaryUnion.isEmpty
            ? 0
            : Double(boundaryDifference.count)
                / Double(boundaryUnion.count),
    ]
}

private func l4MaterialLadder(
    _ materials: [[String: Any]]
) throws -> CGImage {
    let width = 1600
    let rowHeight = 54
    let titleHeight = 80
    let context = try l4Context(
        width: width,
        height: titleHeight + rowHeight * materials.count
    )
    context.setFillColor(
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [0.06, 0.075, 0.08, 1]
        )!
    )
    context.fill(
        CGRect(
            x: 0,
            y: 0,
            width: width,
            height: titleHeight + rowHeight * materials.count
        )
    )
    l4DrawText(
        "Industrial L4 material and post-step-32 value ladder",
        in: context,
        at: CGPoint(x: 24, y: rowHeight * materials.count + 28),
        size: 31,
        color: CGColor(gray: 0.96, alpha: 1)
    )
    for (index, material) in materials.enumerated() {
        guard
            let id = material["id"] as? String,
            let rgba = material["baseColorRGBA"] as? [Double]
        else { continue }
        let y = rowHeight * (materials.count - index - 1)
        let color = CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: rgba.map { CGFloat($0) }
        )!
        context.setFillColor(color)
        context.fill(CGRect(x: 24, y: y + 7, width: 360, height: 40))
        let luma = l4QuantizedLuma(rgba)
        context.setFillColor(CGColor(gray: CGFloat(luma) / 255, alpha: 1))
        context.fill(CGRect(x: 405, y: y + 7, width: 220, height: 40))
        l4DrawText(
            "\(id)  |  quantized luma \(luma)",
            in: context,
            at: CGPoint(x: 650, y: y + 15),
            size: 20,
            color: CGColor(gray: 0.94, alpha: 1)
        )
    }
    guard let image = context.makeImage() else {
        throw IndustrialL4TurbinePrepixelError.invalid(
            "could not compose material ladder"
        )
    }
    return image
}

@main
struct BuildIndustrialL4TurbinePrepixel {
    static func main() throws {
        let arguments = CommandLine.arguments
        let repositoryRoot = URL(
            fileURLWithPath: try l4Argument(
                "--repository-root",
                in: arguments
            )!
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath:
                try l4Argument(
                    "--output-root",
                    in: arguments,
                    required: false
                )
                ?? repositoryRoot.path
        ).standardizedFileURL
        let regularStagedURL = URL(
            fileURLWithPath: try l4Argument(
                "--regular-staged-frame",
                in: arguments
            )!
        ).standardizedFileURL
        let compactStagedURL = URL(
            fileURLWithPath: try l4Argument(
                "--compact-staged-frame",
                in: arguments
            )!
        ).standardizedFileURL
        let regularStagedHash = try l4SHA256(regularStagedURL)
        let compactStagedHash = try l4SHA256(compactStagedURL)
        guard regularStagedHash
            == "d45dfaa8fe8e4c985c86a32814de5c4339ad1de7256de12f00dd0e103b28e977",
            compactStagedHash
                == "b2be098b11f1fe74a46938efa559e5b68dacc7758f0fdc6bf4a40611885978f4"
        else {
            throw IndustrialL4TurbinePrepixelError.invalid(
                "R2 staged-frame hash drift"
            )
        }

        let toolchainRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/toolchain/toolchain-industrial-l04-source-v03.json"
        let materialRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v03/materials/industrial-l04-turbine-v03.json"
        let sceneBaseRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v03/scenes/industrial_l04/variant-0"
        let evidenceRelative =
            "docs/production/evidence/PLAY-027/industrial-l04/l04/turbine-works-v03-prepixel"
        let toolchainURL = repositoryRoot.appendingPathComponent(
            toolchainRelative
        )
        let toolchainHash = try l4SHA256(toolchainURL)
        let materials = l4Materials()
        let materialLibrary: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "libraryID": "industrial-l04-turbine-v03",
            "source": "task-owned numeric Industrial L4 hero hierarchy; no ImageGen or raster swatch",
            "styleAnchorFile": l4StyleAnchor,
            "styleAnchorSHA256": l4StyleAnchorSHA,
            "familyAnchorFile": l4FamilyAnchor,
            "familyAnchorSHA256": l4FamilyAnchorSHA,
            "imageGenMaterialSwatchesUsed": false,
            "colorSpace": "extended-sRGB",
            "artDirection": [
                "warm weathered masonry and dark blue-green heavy steel",
                "broad high-bay hall and lower control-assembly volume",
                "three deep freight openings instead of storefront rhythm",
                "oxidized plant metal, copper-bronze trim, and restrained ochre",
                "gantry, pipe bridge, silos, roof plant, and paired-stack skyline",
            ],
            "materials": materials,
            "productionSelected": false,
        ]
        let materialURL = outputRoot.appendingPathComponent(materialRelative)
        try l4WriteJSON(materialLibrary, to: materialURL)
        let materialHash = try l4SHA256(materialURL)
        let plans = [
            l4NorthPlan(), l4EastPlan(), l4SouthPlan(), l4WestPlan(),
        ]
        let materialIDs = Set(materials.compactMap {
            $0["id"] as? String
        })
        var records: [[String: Any]] = []
        var descriptorHashes = Set<String>()
        var geometryHashes = Set<String>()
        for plan in plans {
            let descriptor = l4Descriptor(
                plan: plan,
                toolchainHash: toolchainHash,
                materialHash: materialHash
            )
            let sceneURL = outputRoot
                .appendingPathComponent(sceneBaseRelative)
                .appendingPathComponent(plan.direction)
                .appendingPathComponent("scene.json")
            try l4WriteJSON(descriptor, to: sceneURL)
            let descriptorData = try Data(contentsOf: sceneURL)
            _ = try JSONDecoder().decode(
                SceneDescriptor.self,
                from: descriptorData
            )
            let descriptorHash = l4SHA256(descriptorData)
            descriptorHashes.insert(descriptorHash)
            let geometryObject: [String: Any] = [
                "sceneGeometryID": plan.geometryID,
                "building": descriptor["building"]!,
                "facades": descriptor["facades"]!,
                "entrance": descriptor["entrance"]!,
                "props": descriptor["props"]!,
                "occlusionExclusions": descriptor["occlusionExclusions"]!,
            ]
            let geometryHash = l4SHA256(
                try l4JSONData(geometryObject)
            )
            geometryHashes.insert(geometryHash)
            let references = l4MaterialReferences(plan)
            let unresolved = references.filter {
                !materialIDs.contains($0)
            }
            guard unresolved.isEmpty else {
                throw IndustrialL4TurbinePrepixelError.invalid(
                    "unresolved \(plan.direction) materials: \(unresolved)"
                )
            }
            let bounds = l4Bounds(plan)
            guard
                abs(bounds[0][0] + 28) <= 0.000_001,
                abs(bounds[0][2] + 28) <= 0.000_001,
                abs(bounds[1][0] - 28) <= 0.000_001,
                abs(bounds[1][2] - 28) <= 0.000_001,
                bounds[1][1] >= 68
            else {
                throw IndustrialL4TurbinePrepixelError.invalid(
                    "incomplete \(plan.direction) bounds: \(bounds)"
                )
            }
            let dockCount = plan.blocks.filter {
                $0.id.contains("-dock-") && $0.id.hasSuffix("-door")
            }.count
            let staffCount = plan.blocks.filter {
                $0.id.contains("staff-door")
            }.count
            guard dockCount == 3, staffCount == 1 else {
                throw IndustrialL4TurbinePrepixelError.invalid(
                    "frontage semantics failed for \(plan.direction)"
                )
            }
            let conflicts = l4VisiblePlaneConflicts(plan)
            guard conflicts.isEmpty else {
                throw IndustrialL4TurbinePrepixelError.invalid(
                    "visible plane conflict \(plan.direction): \(conflicts)"
                )
            }
            records.append([
                "direction": plan.direction,
                "sceneGeometryID": plan.geometryID,
                "descriptor": sceneURL.path.replacingOccurrences(
                    of: outputRoot.path + "/",
                    with: ""
                ),
                "descriptorSHA256": descriptorHash,
                "canonicalGeometrySHA256": geometryHash,
                "rootBoundsWorld": bounds,
                "massBlockCount": plan.blocks.count,
                "roofVolumeCount": plan.roofs.count,
                "trimBandCount": plan.trims.count,
                "propCount": plan.props.count,
                "loadingDoorCount": dockCount,
                "controlEntranceCount": staffCount,
                "cameraVisibleCoincidentMaterialOwnerPlanes": 0,
                "materialReferences": references,
                "productionDecode": "pass",
                "orientationTransform": "none",
                "authoredIndependently": true,
                "productionSelected": false,
            ])
        }
        guard descriptorHashes.count == 4, geometryHashes.count == 4 else {
            throw IndustrialL4TurbinePrepixelError.invalid(
                "directional descriptor or geometry identities are not unique"
            )
        }

        let nativePixelsPerWorld = l4PixelsPerWorld * l4NativeScale
        let semanticFeatures: [[String: Any]] = [
            ["feature": "loading-door-width", "worldUnits": 9.5, "native2xPixels": 9.5 * nativePixelsPerWorld],
            ["feature": "loading-door-height", "worldUnits": 13, "native2xPixels": 13 * nativePixelsPerWorld],
            ["feature": "control-door-width", "worldUnits": 6.5, "native2xPixels": 6.5 * nativePixelsPerWorld],
            ["feature": "stack-diameter", "worldUnits": 5, "native2xPixels": 5 * nativePixelsPerWorld],
            ["feature": "tank-diameter", "worldUnits": 7, "native2xPixels": 7 * nativePixelsPerWorld],
        ]
        let minimumIdentityPixels = semanticFeatures.map {
            $0["native2xPixels"] as! Double
        }.min()!
        guard minimumIdentityPixels >= 6 else {
            throw IndustrialL4TurbinePrepixelError.invalid(
                "identity feature falls below six native-2x pixels"
            )
        }

        let materialValueRecords = materials.map { material -> [String: Any] in
            let id = material["id"] as! String
            let color = material["baseColorRGBA"] as! [Double]
            return [
                "materialID": id,
                "baseColorRGBA": color,
                "predictedStep32Luma": l4QuantizedLuma(color),
            ]
        }
        let materialBins = Set(materialValueRecords.map {
            $0["predictedStep32Luma"] as! Int
        })
        guard materialBins.count >= 7 else {
            throw IndustrialL4TurbinePrepixelError.invalid(
                "insufficient material value separation"
            )
        }

        let colors = l4ColorMap(materials)
        let colorImages = try plans.map {
            try l4RenderPlan($0, colors: colors, mode: .color)
        }
        let grayscaleImages = try plans.map {
            try l4RenderPlan($0, colors: colors, mode: .grayscale)
        }
        let clayImages = try plans.map {
            try l4RenderPlan($0, colors: colors, mode: .clay)
        }
        let reviewRoot = outputRoot
            .appendingPathComponent(evidenceRelative)
            .appendingPathComponent("review")
        let conceptPlans = [
            l4FoundryConceptPlan(),
            l4PrecisionConceptPlan(),
            l4EastPlan(),
        ]
        let conceptLabels = [
            "A TURBINE / FOUNDRY",
            "B PRECISION CAMPUS",
            "C HEAVY FABRICATION — SELECTED",
        ]
        let conceptColorURL = reviewRoot.appendingPathComponent(
            "THREE-CONCEPT-SOURCE-COLOR.png"
        )
        let conceptGrayURL = reviewRoot.appendingPathComponent(
            "THREE-CONCEPT-COMPACT-GRAYSCALE.png"
        )
        let conceptClayURL = reviewRoot.appendingPathComponent(
            "THREE-CONCEPT-SILHOUETTE-CLAY.png"
        )
        let conceptColorImages = try conceptPlans.map {
            try l4RenderPlan($0, colors: colors, mode: .color)
        }
        let conceptGrayImages = try conceptPlans.map {
            try l4RenderPlan($0, colors: colors, mode: .grayscale)
        }
        let conceptClayImages = try conceptPlans.map {
            try l4RenderPlan($0, colors: colors, mode: .clay)
        }
        try l4WritePNG(
            l4Sheet(
                title: "Industrial L4 hero concept comparison — analytic non-authority",
                images: conceptColorImages,
                labels: conceptLabels,
                panelWidth: 640,
                panelHeight: 426
            ),
            to: conceptColorURL
        )
        try l4WritePNG(
            l4Sheet(
                title: "Industrial L4 concepts at compact grayscale scale — analytic",
                images: conceptGrayImages,
                labels: conceptLabels,
                panelWidth: 320,
                panelHeight: 213
            ),
            to: conceptGrayURL
        )
        try l4WritePNG(
            l4Sheet(
                title: "Industrial L4 concept silhouette / clay comparison — analytic",
                images: conceptClayImages,
                labels: conceptLabels,
                panelWidth: 432,
                panelHeight: 288
            ),
            to: conceptClayURL
        )
        let sourceColorURL = reviewRoot.appendingPathComponent(
            "ANALYTIC-SOURCE-SCALE-COLOR.png"
        )
        let sourceGrayURL = reviewRoot.appendingPathComponent(
            "ANALYTIC-SOURCE-SCALE-GRAYSCALE.png"
        )
        let nativeColorURL = reviewRoot.appendingPathComponent(
            "ANALYTIC-NATIVE-2X-COLOR.png"
        )
        let nativeGrayURL = reviewRoot.appendingPathComponent(
            "ANALYTIC-NATIVE-2X-GRAYSCALE.png"
        )
        let clayURL = reviewRoot.appendingPathComponent(
            "ANALYTIC-CLAY-MASSING.png"
        )
        let neighborhoodColorURL = reviewRoot.appendingPathComponent(
            "ANALYTIC-NEIGHBORHOOD-COLOR.png"
        )
        let neighborhoodGrayURL = reviewRoot.appendingPathComponent(
            "ANALYTIC-NEIGHBORHOOD-GRAYSCALE.png"
        )
        let compactColorURL = reviewRoot.appendingPathComponent(
            "ANALYTIC-COMPACT-COLOR.png"
        )
        let compactGrayURL = reviewRoot.appendingPathComponent(
            "ANALYTIC-COMPACT-GRAYSCALE.png"
        )
        let materialLadderURL = reviewRoot.appendingPathComponent(
            "MATERIAL-VALUE-LADDER.png"
        )
        let labels = ["NORTH", "EAST", "SOUTH", "WEST"]
        try l4WritePNG(
            l4Sheet(
                title: "Industrial L4 analytic source-scale color - non-authority",
                images: colorImages,
                labels: labels,
                panelWidth: 768,
                panelHeight: 512
            ),
            to: sourceColorURL
        )
        try l4WritePNG(
            l4Sheet(
                title: "Industrial L4 analytic source-scale grayscale - non-authority",
                images: grayscaleImages,
                labels: labels,
                panelWidth: 768,
                panelHeight: 512
            ),
            to: sourceGrayURL
        )
        try l4WritePNG(
            l4Sheet(
                title: "Industrial L4 analytic native-2x color - non-authority",
                images: colorImages,
                labels: labels,
                panelWidth: 432,
                panelHeight: 288
            ),
            to: nativeColorURL
        )
        try l4WritePNG(
            l4Sheet(
                title: "Industrial L4 analytic native-2x grayscale - non-authority",
                images: grayscaleImages,
                labels: labels,
                panelWidth: 432,
                panelHeight: 288
            ),
            to: nativeGrayURL
        )
        try l4WritePNG(
            l4Sheet(
                title: "Industrial L4 analytic clay massing - non-authority",
                images: clayImages,
                labels: labels,
                panelWidth: 432,
                panelHeight: 288
            ),
            to: clayURL
        )
        try l4WritePNG(
            l4Sheet(
                title: "Industrial L4 analytic neighborhood-scale color - non-authority",
                images: colorImages,
                labels: labels,
                panelWidth: 300,
                panelHeight: 200
            ),
            to: neighborhoodColorURL
        )
        try l4WritePNG(
            l4Sheet(
                title: "Industrial L4 analytic neighborhood-scale grayscale - non-authority",
                images: grayscaleImages,
                labels: labels,
                panelWidth: 300,
                panelHeight: 200
            ),
            to: neighborhoodGrayURL
        )
        try l4WritePNG(
            l4Sheet(
                title: "Industrial L4 analytic compact gameplay color - non-authority",
                images: colorImages,
                labels: labels,
                panelWidth: 210,
                panelHeight: 140
            ),
            to: compactColorURL
        )
        try l4WritePNG(
            l4Sheet(
                title: "Industrial L4 analytic compact gameplay grayscale - non-authority",
                images: grayscaleImages,
                labels: labels,
                panelWidth: 210,
                panelHeight: 140
            ),
            to: compactGrayURL
        )
        try l4WritePNG(
            l4MaterialLadder(materials),
            to: materialLadderURL
        )

        let acceptedReferences: [(String, String)] = [
            ("industrial-l01-east-block", "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/normalized/industrial_l01/variant-0/east/source-v05/generated_v4_industrial_l01_block.png"),
            ("industrial-l02-east-block", "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v07/source-completion/normalized/run-a/east/generated_v4_industrial_l02_east_source_v05_block.png"),
            ("industrial-l02-east-city", "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v07/source-completion/normalized/run-a/east/generated_v4_industrial_l02_east_source_v05_city.png"),
            ("industrial-l03-east-block", "docs/production/evidence/PLAY-027/industrial-l03/l03/cohesion-a0-family-v01/chroma-repair-v01/normalized/run-a/east/generated_v4_industrial_l03_east_source_v04_block.png"),
            ("industrial-l03-east-city", "docs/production/evidence/PLAY-027/industrial-l03/l03/cohesion-a0-family-v01/chroma-repair-v01/normalized/run-a/east/generated_v4_industrial_l03_east_source_v04_city.png"),
            ("industrial-l03-east-raw", "docs/production/evidence/PLAY-027/industrial-l03/l03/cohesion-a0-east-v01/raw/east-primary/raw.png"),
            ("residential-l04-east-block", "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/normalized/residential_l04/variant-0/east/source-v01/generated_v4_residential_l04_block.png"),
            ("commercial-l04-east-block", "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/normalized/commercial_l04/variant-0/east/source-v03/generated_v4_commercial_l04_block.png"),
        ]
        var acceptedImages: [String: CGImage] = [:]
        var acceptedReferenceRecords: [[String: Any]] = []
        for (id, path) in acceptedReferences {
            let url = repositoryRoot.appendingPathComponent(path)
            acceptedImages[id] = try l4LoadImage(url)
            acceptedReferenceRecords.append([
                "id": id,
                "file": path,
                "sha256": try l4SHA256(url),
            ])
        }
        let progressionColorURL = reviewRoot.appendingPathComponent(
            "INDUSTRIAL-L1-L4-PROGRESSION-COLOR.png"
        )
        let progressionGrayURL = reviewRoot.appendingPathComponent(
            "INDUSTRIAL-L1-L4-PROGRESSION-GRAYSCALE.png"
        )
        let progressionImages = [
            acceptedImages["industrial-l01-east-block"]!,
            acceptedImages["industrial-l02-east-block"]!,
            acceptedImages["industrial-l03-east-block"]!,
            colorImages[1],
        ]
        try l4WritePNG(
            l4ComparisonStrip(
                title: "Industrial capability progression: accepted L1-L3 + analytic L4",
                images: progressionImages,
                labels: ["L1 accepted", "L2 accepted", "L3 accepted", "L4 analytic"],
                cellWidth: 430,
                cellHeight: 360
            ),
            to: progressionColorURL
        )
        try l4WritePNG(
            l4ComparisonStrip(
                title: "Industrial grayscale progression: accepted L1-L3 + analytic L4",
                images: try progressionImages.map(l4Grayscale),
                labels: ["L1 accepted", "L2 accepted", "L3 accepted", "L4 analytic"],
                cellWidth: 430,
                cellHeight: 360
            ),
            to: progressionGrayURL
        )
        let crossFamilyColorURL = reviewRoot.appendingPathComponent(
            "CROSS-FAMILY-L4-COLOR.png"
        )
        let crossFamilyGrayURL = reviewRoot.appendingPathComponent(
            "CROSS-FAMILY-L4-GRAYSCALE.png"
        )
        let crossFamilyImages = [
            acceptedImages["residential-l04-east-block"]!,
            acceptedImages["commercial-l04-east-block"]!,
            colorImages[1],
        ]
        try l4WritePNG(
            l4ComparisonStrip(
                title: "Unlabeled Level 4 family recognition — analytic non-authority",
                images: crossFamilyImages,
                labels: ["", "", ""],
                cellWidth: 520,
                cellHeight: 430
            ),
            to: crossFamilyColorURL
        )
        try l4WritePNG(
            l4ComparisonStrip(
                title: "Unlabeled Level 4 grayscale family recognition",
                images: try crossFamilyImages.map(l4Grayscale),
                labels: ["", "", ""],
                cellWidth: 520,
                cellHeight: 430
            ),
            to: crossFamilyGrayURL
        )
        let rejectedV01URL = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l04/l04/prepixel-v01/review/ANALYTIC-NATIVE-2X-COLOR.png"
        )
        let v01V02ColorURL = reviewRoot.appendingPathComponent(
            "REJECTED-V01-VS-HERO-V02-COLOR.png"
        )
        let v01V02GrayURL = reviewRoot.appendingPathComponent(
            "REJECTED-V01-VS-HERO-V02-GRAYSCALE.png"
        )
        let v01ComparisonImages = [
            try l4LoadImage(rejectedV01URL),
            colorImages[1],
        ]
        try l4WritePNG(
            l4ComparisonStrip(
                title: "Rejected sterile v01 versus broad grounded hero v02",
                images: v01ComparisonImages,
                labels: ["v01 rejected", "v02 analytic hero"],
                cellWidth: 640,
                cellHeight: 430
            ),
            to: v01V02ColorURL
        )
        try l4WritePNG(
            l4ComparisonStrip(
                title: "Rejected v01 versus hero v02 grayscale",
                images: try v01ComparisonImages.map(l4Grayscale),
                labels: ["v01 rejected", "v02 analytic hero"],
                cellWidth: 640,
                cellHeight: 430
            ),
            to: v01V02GrayURL
        )
        let stagedComparisonURL = reviewRoot.appendingPathComponent(
            "R2-STAGED-VALUE-SYSTEM-COMPARISON.png"
        )
        try l4WritePNG(
            l4StagedComparison(
                regular: try l4LoadImage(regularStagedURL),
                compact: try l4LoadImage(compactStagedURL),
                l4Color: colorImages[1],
                l4Gray: grayscaleImages[1]
            ),
            to: stagedComparisonURL
        )
        let cityColorURL = reviewRoot.appendingPathComponent(
            "GAMEPLAY-CITY-SIZE-L2-L4-COLOR.png"
        )
        let cityGrayURL = reviewRoot.appendingPathComponent(
            "GAMEPLAY-CITY-SIZE-L2-L4-GRAYSCALE.png"
        )
        let cityImages = [
            acceptedImages["industrial-l02-east-city"]!,
            acceptedImages["industrial-l03-east-city"]!,
            try l4Resize(colorImages[1], width: 256, height: 171),
        ]
        try l4WritePNG(
            l4ExactSizeStrip(
                title: "Literal 256x171 city canvases: accepted L2/L3 + analytic L4",
                images: cityImages,
                labels: ["L2 accepted", "L3 accepted", "L4 analytic"]
            ),
            to: cityColorURL
        )
        try l4WritePNG(
            l4ExactSizeStrip(
                title: "Literal city-size grayscale: accepted L2/L3 + analytic L4",
                images: try cityImages.map(l4Grayscale),
                labels: ["L2 accepted", "L3 accepted", "L4 analytic"]
            ),
            to: cityGrayURL
        )

        let safetyColor = materials.first {
            $0["id"] as? String == "l4-safety-ochre"
        }!["baseColorRGBA"] as! [Double]
        let analyticMetrics = try colorImages.map {
            try l4AnalyticMetrics($0, safetyColor: safetyColor)
        }
        let maximumAccentShare = analyticMetrics.map {
            $0["safetyAccentShare"] as! Double
        }.max()!
        guard maximumAccentShare < 0.10 else {
            throw IndustrialL4TurbinePrepixelError.invalid(
                "safety accent exceeds gameplay-scale target"
            )
        }
        let silhouetteMetrics = try l4SilhouetteMetrics(
            acceptedL3: acceptedImages["industrial-l03-east-raw"]!,
            analyticL4: colorImages[1]
        )
        guard
            (silhouetteMetrics["silhouetteBoundaryChangeShare"] as! Double)
                >= 0.20,
            (silhouetteMetrics["silhouetteMaskIntersectionOverUnion"] as! Double)
                < 0.80
        else {
            throw IndustrialL4TurbinePrepixelError.invalid(
                "L3-to-L4 silhouette change target failed"
            )
        }
        let frontageWidthNative2x = 30.6 * nativePixelsPerWorld
        let facadeContrast = abs(
            l4QuantizedLuma(
                materials.first {
                    $0["id"] as? String == "l4-warm-concrete"
                }!["baseColorRGBA"] as! [Double]
            )
                - l4QuantizedLuma(
                    materials.first {
                        $0["id"] as? String == "l4-dock-door"
                    }!["baseColorRGBA"] as! [Double]
                )
        )
        guard frontageWidthNative2x >= 8, facadeContrast >= 15 else {
            throw IndustrialL4TurbinePrepixelError.invalid(
                "gameplay-scale frontage target failed"
            )
        }

        let validation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "batch": "industrial-l04-hero-variant-0-prepixel-v02",
            "publishedAuthority": l4AuthorityBase,
            "acceptedIndustrialL3Continuity": l4ContinuityBase,
            "mergeBoundary": "b264e3e81c870c6e52961add93ae9b50edcf1f80",
            "sourceProcesses": 0,
            "normalizerProcesses": 0,
            "imageGenCalls": 0,
            "productionSelected": false,
            "sourceAuthority": false,
            "toolchainFile": toolchainRelative,
            "toolchainSHA256": toolchainHash,
            "materialLibraryFile": materialRelative,
            "materialLibrarySHA256": materialHash,
            "materialCount": materials.count,
            "predictedStep32LumaBins": materialBins.sorted(),
            "predictedStep32LumaBinCount": materialBins.count,
            "materialValueLedger": materialValueRecords,
            "descriptorUniqueness": "4/4",
            "canonicalGeometryUniqueness": "4/4",
            "productionDecoderDryDecode": "4/4 pass",
            "materialReferenceValidation": "4/4 pass",
            "footprintPivotSocketShadowContract": "4/4 pass",
            "cameraVisibleCoincidentMaterialOwnerPlanes": "0/4",
            "identityFeatureMinimumNative2xPixels":
                minimumIdentityPixels,
            "semanticFeatureLedger": semanticFeatures,
            "gameplayScaleMeasurableCloseoutTargets": [
                "analyticDirectionMetrics": analyticMetrics,
                "maximumSafetyAccentShare": maximumAccentShare,
                "maximumSafetyAccentShareLimit": 0.10,
                "frontageSpanNative2xPixels": frontageWidthNative2x,
                "frontageMinimumPixels": 8,
                "dockToFacadeStep32LumaContrast": facadeContrast,
                "frontageMinimumGrayscaleContrast": 15,
                "industrialL3ToL4Silhouette": silhouetteMetrics,
                "minimumBoundaryChangeShare": 0.20,
                "maximumSilhouetteMaskOverlap": 0.80,
                "outlineAndContactShadow": "frozen shared northwest-light and southeast authored-contact language; exact pixel proof deferred to first raw gate",
                "cityFrameOccupancy": "integration-owned composed-frame metric; exact R2 frames bound read-only and no L4 staged claim made",
            ],
            "directions": records,
            "acceptedReferenceInputs": acceptedReferenceRecords,
            "r2StagedFrames": [
                [
                    "role": "regular-current-staged-value-system",
                    "externalFile": regularStagedURL.path,
                    "sha256": regularStagedHash,
                ],
                [
                    "role": "compact-current-staged-value-system",
                    "externalFile": compactStagedURL.path,
                    "sha256": compactStagedHash,
                ],
            ],
            "artDirection": [
                "capacityStep": "heavy-fabrication hero campus above accepted four-bay L3",
                "silhouette": "broad high-bay hall, lower assembly-control wing, asymmetric gantry, pipe bridge, paired stacks, roof plant and silos",
                "frontage": "three oversized freight openings plus a separate control/staff entrance on every named road edge",
                "materials": "warm weathered concrete, dark blue-green steel, oxide process metal, copper-bronze trim, charcoal depth and restrained ochre",
                "familyNonAlias": "no residential tower/roof grammar, no commercial floorplate/storefront rhythm, no L1-L3 geometry reuse",
                "l3Cohesion": "extends accepted warm/dark L3 treatment with heavier aging, deeper recesses, and materially broader operations silhouette",
            ],
            "reviewAuthority":
                "analytic-prepixel-only-not-source-pixels-or-acceptance",
        ]
        let evidenceRoot = outputRoot.appendingPathComponent(
            evidenceRelative
        )
        let conceptComparison = """
        # Industrial L4 hero concept comparison

        Authority: `\(l4AuthorityBase)`

        All three concepts are analytic pre-pixel studies. They are not source
        pixels, source authority, production selection, or shipping art.

        ## A — Broad turbine / foundry works

        - Silhouette: widest single hall, repeated monitor roof, furnace house,
          tall stack, and quench tank.
        - Materials: weathered heavy steel, warm casting wing, oxide furnace.
        - Readability: unmistakably industrial at compact scale, but the repeated
          monitor rhythm risks flattening into a generic sawtooth factory and
          leaves the road-facing logistics hierarchy comparatively weak.

        ## B — Asymmetric precision-manufacturing campus

        - Silhouette: lower clean assembly hall, elevated glazed control volume,
          process spine, and compact roof plant.
        - Materials: warmer concrete and aged steel with deeper glazing.
        - Readability: the staff/control story is strongest, but the elevated
          control volume risks office or research-campus ambiguity and lacks the
          heavy city-scale freight identity required for Industrial L4.

        ## C — Heavy fabrication works — selected

        - Silhouette: broad high-bay forge hall, lower assembly/control wing,
          asymmetric overhead gantry, pipe bridge, paired stacks, silos, and
          roof plant.
        - Materials: dark weathered blue-green steel, warm board-formed concrete,
          charcoal structure, aged process alloy, layered oxide, copper-bronze
          trim, and restrained ochre.
        - Readability: three oversized freight openings and a separate staff
          entrance survive without storefront rhythm; the gantry and paired
          stack silhouette reads as major productive capacity at city scale.

        C is selected because it combines A's heavy-operation credibility with
        B's separate human-scale control identity, while remaining broad,
        grounded, asymmetric, and non-commercial. Its N/E/S/W descriptors are
        authored independently; no sibling mirror, rotation, transform, recolor,
        source alias, or fallback is used.

        `sourceAuthority: false`

        `productionSelected: false`
        """
        try l4WriteText(
            conceptComparison,
            to: evidenceRoot.appendingPathComponent(
                "THREE-CONCEPT-COMPARISON.md"
            )
        )
        let validationURL = evidenceRoot.appendingPathComponent(
            "PREPIXEL-VALIDATION.json"
        )
        try l4WriteJSON(validation, to: validationURL)

        let architecture = """
        # Industrial L4 hero pre-pixel architecture v02

        Authority: `\(l4AuthorityBase)` merged over source continuity `\(l4ContinuityBase)`.

        Disposition: `PENDING_INDEPENDENT_PREPIXEL_REVIEW`

        This source-only family completes the R/C/I level spine with an
        advanced-manufacturing hero campus: a broad high-bay fabrication hall,
        lower assembly/control volume, warm staff wing, three oversized freight
        bays, separate staff entrance, overhead gantry, pipe bridge, silos,
        roof plant, and paired stacks. North and West use independently authored
        open freight throats;
        no sibling mirror, rotation, recolor, source alias, or camera trick is
        present.

        The palette answers rejected v01's pale clinical read with dark
        blue-green weathered steel, warm board-formed concrete, deep freight
        recesses, oxidized plant metal, copper-bronze trim, charcoal structure,
        and a weathered dark roof membrane. Identity is carried by large
        operational volumes rather than source-only greebles.

        Frozen contracts:

        - exact 56 x 56 footprint, `[768,896]` pivot, named sockets and road edges;
        - fixed 2:1 camera and source registration;
        - northwest value language plus authored southeast contact shadow;
        - three readable heavy freight bays and one control entrance in every direction;
        - minimum identity feature \(String(format: "%.3f", minimumIdentityPixels)) native-2x pixels;
        - \(materialBins.count) predicted post-step-32 value bins;
        - zero camera-visible coincident material-owner planes in analytic validation;
        - schema-2 v3 no-MSAA, fixed 4x, software-Lanczos sampling contract;
        - zero SceneKit, Metal, raw-source, or normalization processes.

        All review panels are analytic and explicitly non-authority. The exact R2
        regular/compact frames are read-only comparison inputs, not claimed staged
        Industrial L4 proof.

        `sourceAuthority: false`

        `productionSelected: false`
        """
        try l4WriteText(
            architecture,
            to: evidenceRoot.appendingPathComponent("ARCHITECTURE.md")
        )
        let rawGatePlan = """
        # Industrial L4 first-direction raw gate

        After independent approval of this pre-pixel checkpoint, freeze the
        descriptor/material/toolchain hashes in PREPIXEL-VALIDATION.json and run
        exactly one fresh East source-authority process. East is first because its
        three heavy freight openings, staff entrance, high-bay step, gantry,
        pipe bridge, silos, stacks, roof plant, and contact shadow are judgeable.

        Stop after that one process. Require complete RGBA/occupancy, chroma and
        hidden-RGB safety, exact pivot/socket/frontage/contact registration, source
        and native-2x color/grayscale/footprint/zoom panels, and visible superiority
        to Industrial L3 without sterile white, subpixel noise, mixed fidelity, or
        floating ground contact. N/S/W, repeats, normalization, source authority,
        renderer ingestion, and production selection remain blocked pending a
        separate integration disposition.
        """
        try l4WriteText(
            rawGatePlan,
            to: evidenceRoot.appendingPathComponent(
                "FIRST-DIRECTION-RAW-GATE-PLAN.md"
            )
        )
        let reviewFiles = [
            conceptColorURL, conceptGrayURL, conceptClayURL,
            sourceColorURL, sourceGrayURL, nativeColorURL, nativeGrayURL,
            neighborhoodColorURL, neighborhoodGrayURL,
            compactColorURL, compactGrayURL,
            clayURL, materialLadderURL, progressionColorURL,
            progressionGrayURL, crossFamilyColorURL, crossFamilyGrayURL,
            v01V02ColorURL, v01V02GrayURL, stagedComparisonURL,
            cityColorURL, cityGrayURL,
        ]
        let reviewManifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "batch": "industrial-l04-hero-variant-0-prepixel-v02",
            "authority":
                "analytic-prepixel-only-not-source-pixels-or-acceptance",
            "directionOrder": ["north", "east", "south", "west"],
            "files": try reviewFiles.map {
                [
                    "file": $0.path.replacingOccurrences(
                        of: outputRoot.path + "/",
                        with: ""
                    ),
                    "sha256": try l4SHA256($0),
                ]
            },
            "productionSelected": false,
        ]
        try l4WriteJSON(
            reviewManifest,
            to: reviewRoot.appendingPathComponent("REVIEW-MANIFEST.json")
        )
        let reviewRequest = """
        # Industrial L4 pre-pixel independent review request

        Please inspect the exact descriptor/material identities and the analytic
        source/native color, grayscale, clay, value-ladder, L1-L4 progression,
        R/C/I L4 separation, and current R2 staged-system comparison panels.

        Binding review questions:

        1. Does every view read as a separately authored advanced industrial campus?
        2. Are the control wing, three heavy freight bays, high-bay/assembly step,
           gantry, pipe bridge, silos/stacks, roof plant, and ground contact
           readable at native-2x?
        3. Is the palette richer and less sterile than L3 while remaining in the
           same CitySim value/outline/light family?
        4. Is capability clearly above L3 and non-aliased from Residential or
           Commercial L4?
        5. Is East strong enough for the separately governed one-process raw gate?

        This request proposes only the pre-pixel boundary. It is not source,
        renderer, shipping, or production-selection acceptance.
        """
        try l4WriteText(
            reviewRequest,
            to: evidenceRoot.appendingPathComponent(
                "INDEPENDENT-REVIEW-REQUEST.md"
            )
        )
        print("industrial-l04-prepixel-pass \(validationURL.path)")
    }
}
