import AppKit
import CoreGraphics
import CoreImage
import CoreText
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL4PrepixelError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l4-prepixel --repository-root <path> --regular-staged-frame <path> --compact-staged-frame <path> [--output-root <path>]"
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
    "f45b16cacfe1e518ef16752cd87ea9156afcc5c0"
private let l4ContinuityBase =
    "5e019c3e7b7992cabeae179641a0f6748a971666"
private let l4StyleAnchor =
    "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png"
private let l4StyleAnchorSHA =
    "b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425"
private let l4FamilyAnchor =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/source-completion-v02/final-family/review/NATIVE-2X-NESW-COLOR.png"
private let l4FamilyAnchorSHA =
    "8512e10c09bdccead3ca59c516c214a7bb0695656d2c8f1990d4862606b2d17f"

private func l4Argument(
    _ name: String,
    in arguments: [String],
    required: Bool = true
) throws -> String? {
    guard let index = arguments.firstIndex(of: name) else {
        if required { throw IndustrialL4PrepixelError.arguments }
        return nil
    }
    guard index + 1 < arguments.count else {
        throw IndustrialL4PrepixelError.arguments
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
        throw IndustrialL4PrepixelError.invalid(
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
        throw IndustrialL4PrepixelError.invalid(
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
        throw IndustrialL4PrepixelError.invalid("could not create PNG")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL4PrepixelError.invalid(
            "could not finalize PNG: \(url.path)"
        )
    }
}

private func l4WriteText(_ text: String, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL4PrepixelError.invalid(
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
        l4Material("l4-recess", [0.06, 0.08, 0.09, 1], 0.94, 0.04, "solid-depth-cavity"),
        l4Material("l4-dock-door", [0.23, 0.34, 0.38, 1], 0.78, 0.22, "horizontal-section-joints"),
        l4Material("l4-weathered-blue-steel", [0.36, 0.50, 0.56, 1], 0.79, 0.26, "broad-vertical-corrugation"),
        l4Material("l4-blue-steel-light", [0.51, 0.62, 0.64, 1], 0.80, 0.20, "broad-vertical-corrugation"),
        l4Material("l4-warm-concrete", [0.72, 0.62, 0.50, 1], 0.92, 0.00, "large-formed-concrete-panels"),
        l4Material("l4-concrete-shadow", [0.45, 0.40, 0.34, 1], 0.95, 0.00, "large-formed-concrete-panels"),
        l4Material("l4-foundation", [0.31, 0.33, 0.31, 1], 0.98, 0.00, "large-scored-slabs"),
        l4Material("l4-apron", [0.61, 0.59, 0.52, 1], 0.98, 0.00, "large-scored-slabs"),
        l4Material("l4-roof-membrane", [0.67, 0.69, 0.65, 1], 0.92, 0.04, "rolled-membrane-seams"),
        l4Material("l4-charcoal-steel", [0.17, 0.22, 0.24, 1], 0.72, 0.42, "painted-steel"),
        l4Material("l4-control-glazing", [0.18, 0.42, 0.48, 1], 0.34, 0.10, "wide-control-room-mullions"),
        l4Material("l4-warm-glazing", [0.73, 0.51, 0.27, 1], 0.34, 0.06, "muted-warm-glazing"),
        l4Material("l4-process-metal", [0.51, 0.58, 0.57, 1], 0.63, 0.50, "fine-galvanized"),
        l4Material("l4-duct-metal", [0.63, 0.66, 0.61, 1], 0.60, 0.56, "fine-galvanized"),
        l4Material("l4-light-trim", [0.82, 0.75, 0.60, 1], 0.66, 0.26, "painted-steel"),
        l4Material("l4-safety-ochre", [0.82, 0.46, 0.10, 1], 0.64, 0.20, "restrained-safety-paint"),
        l4Material("l4-oxide", [0.59, 0.33, 0.20, 1], 0.76, 0.38, "restrained-oxide"),
        l4Material("l4-pipe", [0.55, 0.59, 0.55, 1], 0.58, 0.60, "fine-galvanized"),
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
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-recess", dimensions: [6.8, 14, 1.6], position: [center, 10.5, edge], material: "l4-recess"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-door", dimensions: [5.8, 12, 0.9], position: [center, 9.5, edge + (edge < 0 ? 1.2 : -1.2)], material: "l4-dock-door"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-canopy", dimensions: [7.8, 3.2, 6], position: [center, 19, edge + (edge < 0 ? -2.4 : 2.4)], material: "l4-light-trim"))
        } else {
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-recess", dimensions: [1.6, 14, 6.8], position: [edge, 10.5, center], material: "l4-recess"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-door", dimensions: [0.9, 12, 5.8], position: [edge + (edge < 0 ? 1.2 : -1.2), 9.5, center], material: "l4-dock-door"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-canopy", dimensions: [6, 3.2, 7.8], position: [edge + (edge < 0 ? -2.4 : 2.4), 19, center], material: "l4-light-trim"))
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
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-recess", dimensions: [5.8, 14, 1.6], position: [center, 10.5, edge], material: "l4-recess"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-door", dimensions: [5, 12, 0.9], position: [center, 9.5, edge + 1.2], material: "l4-dock-door"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-canopy", dimensions: [6, 3.5, 6], position: [center, 19, edge - 2.4], material: "l4-light-trim"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-portal-shadow", dimensions: [5, 7, 1], position: [center, 24.5, edge + 1.6], material: "l4-recess"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-portal-cap", dimensions: [5.8, 2.5, 3], position: [center, 29, edge + 0.8], material: "l4-light-trim"))
        } else {
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-recess", dimensions: [1.6, 14, 5.8], position: [edge, 10.5, center], material: "l4-recess"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-door", dimensions: [0.9, 12, 5], position: [edge + 1.2, 9.5, center], material: "l4-dock-door"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-canopy", dimensions: [6, 3.5, 6], position: [edge - 2.4, 19, center], material: "l4-light-trim"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-portal-shadow", dimensions: [1, 7, 5], position: [edge + 1.6, 24.5, center], material: "l4-recess"))
            result.append(L4Block(id: "\(prefix)-dock-\(index + 1)-portal-cap", dimensions: [3, 2.5, 5.8], position: [edge + 0.8, 29, center], material: "l4-light-trim"))
        }
    }
    return result
}

private func l4NorthPlan() -> L4Plan {
    let centers = [-12.4, -6.2, 0.0, 6.2, 12.4]
    var blocks: [L4Block] = [
        L4Block(id: "n-high-bay-west", dimensions: [8, 48, 28], position: [-24, 28, 14], material: "l4-weathered-blue-steel"),
        L4Block(id: "n-assembly-east", dimensions: [8, 31, 26], position: [24, 19.5, 15], material: "l4-blue-steel-light"),
        L4Block(id: "n-loading-spine", dimensions: [34, 24, 4], position: [0, 15, 12], material: "l4-warm-concrete"),
        L4Block(id: "n-open-loading-court", dimensions: [36, 3, 41.25], position: [0, 3.9, -6.875], material: "l4-concrete-shadow"),
        L4Block(id: "n-service-apron", dimensions: [38, 1.8, 13], position: [0, 2.1, -21.5], material: "l4-apron"),
        L4Block(id: "n-control-wing", dimensions: [8, 28, 12], position: [20, 17.5, 6], material: "l4-warm-concrete"),
        L4Block(id: "n-control-glazing", dimensions: [7, 8, 1.2], position: [20, 20, 12.6], material: "l4-control-glazing"),
        L4Block(id: "n-staff-door", dimensions: [5.5, 10, 1], position: [20, 8.5, 12.8], material: "l4-warm-glazing"),
        L4Block(id: "n-staff-canopy", dimensions: [7, 3.5, 6], position: [19.8, 15.5, 15.5], material: "l4-light-trim"),
        L4Block(id: "n-process-podium", dimensions: [7, 8, 10], position: [-24, 60, 20], material: "l4-oxide"),
        L4Block(id: "n-process-crown", dimensions: [6, 8, 8], position: [-24, 68.2, 20], material: "l4-process-metal"),
        L4Block(id: "n-pipe-gallery", dimensions: [33, 4, 4], position: [0, 58, 20], material: "l4-duct-metal"),
    ]
    blocks += l4FarEdgeDockBlocks(
        prefix: "n",
        centers: centers,
        axis: "x",
        edge: 14.2
    )
    return L4Plan(
        direction: "north",
        geometryID: "industrial-l04-north-v01-centered-loading-court-campus",
        blocks: blocks,
        roofs: [
            L4Roof(id: "n-high-bay-roof", dimensions: [8, 4, 28], position: [-24, 54, 14], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
            L4Roof(id: "n-assembly-roof", dimensions: [8, 3.5, 26], position: [24, 36.8, 15], material: "l4-roof-membrane", trim: "l4-light-trim"),
            L4Roof(id: "n-control-roof", dimensions: [8, 3, 12], position: [20, 33, 6], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
        ],
        trims: [
            L4Block(id: "n-clerestory-west", dimensions: [5, 7, 13], position: [-24, 59.5, 13], material: "l4-control-glazing"),
            L4Block(id: "n-clerestory-east", dimensions: [5, 6, 12], position: [24, 42, 14], material: "l4-control-glazing"),
            L4Block(id: "n-portal-beam", dimensions: [34, 3.5, 3], position: [0, 26.5, 16.4], material: "l4-safety-ochre"),
        ],
        props: [
            L4Prop(id: "n-stack-a", kind: "explicit-cylinder", dimensions: [5, 20, 5], position: [-24.3, 66, 8], material: "l4-charcoal-steel"),
            L4Prop(id: "n-stack-b", kind: "explicit-cylinder", dimensions: [5, 17, 5], position: [24, 63.5, 10], material: "l4-oxide"),
            L4Prop(id: "n-tank-a", kind: "explicit-cylinder", dimensions: [8, 16, 8], position: [8, 11, 21], material: "l4-process-metal"),
            L4Prop(id: "n-tank-b", kind: "explicit-cylinder", dimensions: [7, 13, 7], position: [-3, 9.5, 21], material: "l4-oxide"),
            L4Prop(id: "n-hvac-a", kind: "explicit-box", dimensions: [6, 5, 7], position: [22, 42, 10], material: "l4-process-metal"),
            L4Prop(id: "n-hvac-b", kind: "explicit-box", dimensions: [6, 5, 7], position: [22, 42, 19], material: "l4-process-metal"),
        ],
        facadeEdgeWorld: [[-28, -28], [28, -28]],
        entranceBase: [20, 3, -28],
        exclusion: [[-19, -28], [28, -28], [28, 8], [-19, 8]]
    )
}

private func l4EastPlan() -> L4Plan {
    let centers = [-17.0, -8.5, 0.0, 8.5, 17.0]
    var blocks: [L4Block] = [
        L4Block(id: "e-high-bay-hall", dimensions: [36, 48, 48], position: [-9, 28, 0], material: "l4-weathered-blue-steel"),
        L4Block(id: "e-stepped-assembly", dimensions: [13, 31, 31], position: [10.5, 19.5, -7], material: "l4-blue-steel-light"),
        L4Block(id: "e-loading-spine", dimensions: [4, 24, 49], position: [17, 15, 1.5], material: "l4-warm-concrete"),
        L4Block(id: "e-service-apron", dimensions: [13, 1.8, 54], position: [21.5, 2.1, 0], material: "l4-apron"),
        L4Block(id: "e-control-wing", dimensions: [16, 28, 13], position: [6, 17.5, 20.5], material: "l4-warm-concrete"),
        L4Block(id: "e-control-glazing", dimensions: [1.2, 8, 10], position: [14.6, 20, 20.5], material: "l4-control-glazing"),
        L4Block(id: "e-staff-door", dimensions: [1, 10, 5.5], position: [14.8, 8.5, 20.5], material: "l4-warm-glazing"),
        L4Block(id: "e-staff-canopy", dimensions: [6, 3.2, 8], position: [17.5, 15.5, 20.5], material: "l4-light-trim"),
        L4Block(id: "e-process-podium", dimensions: [14, 10, 14], position: [-18, 61, -9], material: "l4-oxide"),
        L4Block(id: "e-process-crown", dimensions: [10, 8, 10], position: [-18, 70.2, -9], material: "l4-process-metal"),
        L4Block(id: "e-pipe-gallery", dimensions: [4, 4, 31], position: [-12.8, 59, 1], material: "l4-duct-metal"),
    ]
    blocks += l4DockBlocks(
        prefix: "e",
        centers: centers,
        axis: "z",
        edge: 18.5
    )
    return L4Plan(
        direction: "east",
        geometryID: "industrial-l04-east-v01-five-bay-control-process-campus",
        blocks: blocks,
        roofs: [
            L4Roof(id: "e-high-bay-roof", dimensions: [37, 4, 49], position: [-9, 54, 0], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
            L4Roof(id: "e-assembly-roof", dimensions: [14, 3.5, 32], position: [10.5, 36.8, -7], material: "l4-roof-membrane", trim: "l4-light-trim"),
            L4Roof(id: "e-control-roof", dimensions: [17, 3, 14], position: [6, 33, 20.5], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
        ],
        trims: [
            L4Block(id: "e-clerestory-north", dimensions: [18, 7, 8], position: [-9, 59.5, -12], material: "l4-control-glazing"),
            L4Block(id: "e-clerestory-south", dimensions: [15, 6, 9], position: [-9, 59, 10], material: "l4-control-glazing"),
            L4Block(id: "e-portal-beam", dimensions: [3, 3.5, 47], position: [21, 26.5, 1], material: "l4-safety-ochre"),
        ],
        props: [
            L4Prop(id: "e-stack-a", kind: "explicit-cylinder", dimensions: [5, 20, 5], position: [-14, 60, -14], material: "l4-charcoal-steel"),
            L4Prop(id: "e-stack-b", kind: "explicit-cylinder", dimensions: [5, 17, 5], position: [-14, 58.5, -4], material: "l4-oxide"),
            L4Prop(id: "e-tank-a", kind: "explicit-cylinder", dimensions: [8, 16, 8], position: [-18, 11, 7], material: "l4-process-metal"),
            L4Prop(id: "e-tank-b", kind: "explicit-cylinder", dimensions: [7, 13, 7], position: [-18, 9.5, 17], material: "l4-oxide"),
            L4Prop(id: "e-hvac-a", kind: "explicit-box", dimensions: [8, 5, 7], position: [3, 60, -16], material: "l4-process-metal"),
            L4Prop(id: "e-hvac-b", kind: "explicit-box", dimensions: [8, 5, 7], position: [3, 60, -7], material: "l4-process-metal"),
        ],
        facadeEdgeWorld: [[28, -28], [28, 28]],
        entranceBase: [28, 3, 20.5],
        exclusion: [[8, -27], [28, -27], [28, 27], [8, 27]]
    )
}

private func l4SouthPlan() -> L4Plan {
    let centers = [-17.0, -8.5, 0.0, 8.5, 17.0]
    var blocks: [L4Block] = [
        L4Block(id: "s-high-bay-west", dimensions: [31, 46, 38], position: [-10.5, 27, -8], material: "l4-weathered-blue-steel"),
        L4Block(id: "s-assembly-east", dimensions: [18, 34, 38], position: [15, 21, -8], material: "l4-blue-steel-light"),
        L4Block(id: "s-loading-spine", dimensions: [49, 24, 4], position: [1.5, 15, 17], material: "l4-warm-concrete"),
        L4Block(id: "s-service-apron", dimensions: [54, 1.8, 13], position: [0, 2.1, 21.5], material: "l4-apron"),
        L4Block(id: "s-control-wing", dimensions: [13, 28, 16], position: [-20.5, 17.5, 6], material: "l4-warm-concrete"),
        L4Block(id: "s-control-glazing", dimensions: [10, 8, 1.2], position: [-20.5, 20, 14.6], material: "l4-control-glazing"),
        L4Block(id: "s-staff-door", dimensions: [5.5, 10, 1], position: [-20.5, 8.5, 14.8], material: "l4-warm-glazing"),
        L4Block(id: "s-staff-canopy", dimensions: [8, 3.2, 6], position: [-20.5, 15.5, 17.5], material: "l4-light-trim"),
        L4Block(id: "s-process-podium", dimensions: [14, 10, 14], position: [-5, 59, -18], material: "l4-oxide"),
        L4Block(id: "s-process-crown", dimensions: [10, 8, 10], position: [-5, 68.2, -18], material: "l4-process-metal"),
        L4Block(id: "s-pipe-gallery", dimensions: [31, 4, 4], position: [-1, 57, -12.8], material: "l4-duct-metal"),
    ]
    blocks += l4DockBlocks(
        prefix: "s",
        centers: centers,
        axis: "x",
        edge: 18.5
    )
    return L4Plan(
        direction: "south",
        geometryID: "industrial-l04-south-v01-stepped-fabrication-tank-campus",
        blocks: blocks,
        roofs: [
            L4Roof(id: "s-high-bay-roof", dimensions: [32, 4, 39], position: [-10.5, 52, -8], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
            L4Roof(id: "s-assembly-roof", dimensions: [19, 3.5, 39], position: [15, 39.8, -8], material: "l4-roof-membrane", trim: "l4-light-trim"),
            L4Roof(id: "s-control-roof", dimensions: [14, 3, 17], position: [-20.5, 33, 6], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
        ],
        trims: [
            L4Block(id: "s-sawlight-west", dimensions: [17, 7, 9], position: [-11, 58, -14], material: "l4-control-glazing"),
            L4Block(id: "s-sawlight-east", dimensions: [11, 6, 9], position: [15, 45, -2], material: "l4-control-glazing"),
            L4Block(id: "s-portal-beam", dimensions: [47, 3.5, 3], position: [1, 26.5, 21], material: "l4-safety-ochre"),
        ],
        props: [
            L4Prop(id: "s-stack-a", kind: "explicit-cylinder", dimensions: [5, 20, 5], position: [14, 58, -14], material: "l4-charcoal-steel"),
            L4Prop(id: "s-stack-b", kind: "explicit-cylinder", dimensions: [5, 17, 5], position: [4, 56.5, -14], material: "l4-oxide"),
            L4Prop(id: "s-tank-a", kind: "explicit-cylinder", dimensions: [8, 16, 8], position: [-3, 11, -20], material: "l4-process-metal"),
            L4Prop(id: "s-tank-b", kind: "explicit-cylinder", dimensions: [7, 13, 7], position: [-13, 9.5, -20], material: "l4-oxide"),
            L4Prop(id: "s-hvac-a", kind: "explicit-box", dimensions: [7, 5, 8], position: [-1, 58, -3], material: "l4-process-metal"),
            L4Prop(id: "s-hvac-b", kind: "explicit-box", dimensions: [7, 5, 8], position: [8, 58, -3], material: "l4-process-metal"),
        ],
        facadeEdgeWorld: [[28, 28], [-28, 28]],
        entranceBase: [-20.5, 3, 28],
        exclusion: [[27, 8], [27, 28], [-27, 28], [-27, 8]]
    )
}

private func l4WestPlan() -> L4Plan {
    let centers = [-12.4, -6.2, 0.0, 6.2, 12.4]
    var blocks: [L4Block] = [
        L4Block(id: "w-high-bay-north", dimensions: [28, 48, 8], position: [14, 28, -24], material: "l4-weathered-blue-steel"),
        L4Block(id: "w-assembly-south", dimensions: [26, 31, 8], position: [15, 19.5, 24], material: "l4-blue-steel-light"),
        L4Block(id: "w-loading-spine", dimensions: [4, 24, 34], position: [12, 15, 0], material: "l4-warm-concrete"),
        L4Block(id: "w-open-loading-court", dimensions: [41.25, 3, 36], position: [-6.875, 3.9, 0], material: "l4-concrete-shadow"),
        L4Block(id: "w-service-apron", dimensions: [13, 1.8, 38], position: [-21.5, 2.1, 0], material: "l4-apron"),
        L4Block(id: "w-control-wing", dimensions: [12, 28, 8], position: [6, 17.5, 20], material: "l4-warm-concrete"),
        L4Block(id: "w-control-glazing", dimensions: [1.2, 8, 7], position: [12.6, 20, 20], material: "l4-control-glazing"),
        L4Block(id: "w-staff-door", dimensions: [1, 10, 5.5], position: [12.8, 8.5, 20], material: "l4-warm-glazing"),
        L4Block(id: "w-staff-canopy", dimensions: [6, 3.5, 7], position: [15.5, 15.5, 19.8], material: "l4-light-trim"),
        L4Block(id: "w-process-podium", dimensions: [10, 8, 7], position: [20, 60, -24], material: "l4-oxide"),
        L4Block(id: "w-process-crown", dimensions: [8, 8, 6], position: [20, 68.2, -24], material: "l4-process-metal"),
        L4Block(id: "w-pipe-gallery", dimensions: [4, 4, 33], position: [20, 58, 0], material: "l4-duct-metal"),
    ]
    blocks += l4FarEdgeDockBlocks(
        prefix: "w",
        centers: centers,
        axis: "z",
        edge: 14.2
    )
    return L4Plan(
        direction: "west",
        geometryID: "industrial-l04-west-v01-centered-loading-court-campus",
        blocks: blocks,
        roofs: [
            L4Roof(id: "w-high-bay-roof", dimensions: [28, 4, 8], position: [14, 54, -24], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
            L4Roof(id: "w-assembly-roof", dimensions: [26, 3.5, 8], position: [15, 36.8, 24], material: "l4-roof-membrane", trim: "l4-light-trim"),
            L4Roof(id: "w-control-roof", dimensions: [12, 3, 8], position: [6, 33, 20], material: "l4-roof-membrane", trim: "l4-charcoal-steel"),
        ],
        trims: [
            L4Block(id: "w-clerestory-north", dimensions: [13, 7, 5], position: [13, 59.5, -24], material: "l4-control-glazing"),
            L4Block(id: "w-clerestory-south", dimensions: [12, 6, 5], position: [14, 42, 24], material: "l4-control-glazing"),
            L4Block(id: "w-portal-beam", dimensions: [3, 3.5, 34], position: [16.4, 26.5, 0], material: "l4-safety-ochre"),
        ],
        props: [
            L4Prop(id: "w-stack-a", kind: "explicit-cylinder", dimensions: [5, 20, 5], position: [8, 66, -24.3], material: "l4-charcoal-steel"),
            L4Prop(id: "w-stack-b", kind: "explicit-cylinder", dimensions: [5, 17, 5], position: [10, 63.5, 24], material: "l4-oxide"),
            L4Prop(id: "w-tank-a", kind: "explicit-cylinder", dimensions: [8, 16, 8], position: [21, 11, 8], material: "l4-process-metal"),
            L4Prop(id: "w-tank-b", kind: "explicit-cylinder", dimensions: [7, 13, 7], position: [21, 9.5, -3], material: "l4-oxide"),
            L4Prop(id: "w-hvac-a", kind: "explicit-box", dimensions: [7, 5, 6], position: [10, 42, 22], material: "l4-process-metal"),
            L4Prop(id: "w-hvac-b", kind: "explicit-box", dimensions: [7, 5, 6], position: [19, 42, 22], material: "l4-process-metal"),
        ],
        facadeEdgeWorld: [[-28, 28], [-28, -28]],
        entranceBase: [-28, 3, 20],
        exclusion: [[-28, 28], [-28, -19], [8, -19], [8, 28]]
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
        "sourceRevisionBinding": "source-v01",
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
        "sourceRevision": "source-v01",
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
            "file": "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/toolchain/toolchain-industrial-l04-source-v01.json",
            "sha256": toolchainHash,
        ],
        "styleAnchor": [
            "role": "global-style-anchor",
            "file": l4StyleAnchor,
            "sha256": l4StyleAnchorSHA,
        ],
        "materialLibrary": [
            "role": "industrial-l04-material-library",
            "file": "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-directional-family-v01/materials/industrial-l04-v01.json",
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
            "massingProfile": "industrial-l04-advanced-manufacturing-process-campus",
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
            "purpose": "keep five loading bays and control entrance visible at native-2x",
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
        throw IndustrialL4PrepixelError.invalid("could not allocate context")
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
        throw IndustrialL4PrepixelError.invalid("invalid triangle input")
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
        throw IndustrialL4PrepixelError.invalid(
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
        throw IndustrialL4PrepixelError.invalid("could not compose sheet")
    }
    return image
}

private func l4LoadImage(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw IndustrialL4PrepixelError.invalid(
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
        throw IndustrialL4PrepixelError.invalid(
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
        throw IndustrialL4PrepixelError.invalid(
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
        throw IndustrialL4PrepixelError.invalid(
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
        throw IndustrialL4PrepixelError.invalid("could not resize image")
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
        throw IndustrialL4PrepixelError.invalid(
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
        throw IndustrialL4PrepixelError.invalid(
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
        throw IndustrialL4PrepixelError.invalid(
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
        throw IndustrialL4PrepixelError.invalid(
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
        throw IndustrialL4PrepixelError.invalid(
            "could not compose material ladder"
        )
    }
    return image
}

@main
struct BuildIndustrialL4Prepixel {
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
            throw IndustrialL4PrepixelError.invalid(
                "R2 staged-frame hash drift"
            )
        }

        let toolchainRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/toolchain/toolchain-industrial-l04-source-v01.json"
        let materialRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-directional-family-v01/materials/industrial-l04-v01.json"
        let sceneBaseRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-directional-family-v01/scenes/industrial_l04/variant-0"
        let evidenceRelative =
            "docs/production/evidence/PLAY-027/industrial-l04/l04/prepixel-v01"
        let toolchainURL = repositoryRoot.appendingPathComponent(
            toolchainRelative
        )
        let toolchainHash = try l4SHA256(toolchainURL)
        let materials = l4Materials()
        let materialLibrary: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "libraryID": "industrial-l04-v01",
            "source": "task-owned numeric Industrial L4 hierarchy; no ImageGen or raster swatch",
            "styleAnchorFile": l4StyleAnchor,
            "styleAnchorSHA256": l4StyleAnchorSHA,
            "familyAnchorFile": l4FamilyAnchor,
            "familyAnchorSHA256": l4FamilyAnchorSHA,
            "imageGenMaterialSwatchesUsed": false,
            "colorSpace": "extended-sRGB",
            "artDirection": [
                "weathered blue steel rather than sterile white",
                "warm formed-concrete control volume",
                "dark readable loading recesses",
                "oxidized process metal and restrained ochre",
                "light membrane roof broken by plant and clerestories",
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
                throw IndustrialL4PrepixelError.invalid(
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
                throw IndustrialL4PrepixelError.invalid(
                    "incomplete \(plan.direction) bounds: \(bounds)"
                )
            }
            let dockCount = plan.blocks.filter {
                $0.id.contains("-dock-") && $0.id.hasSuffix("-door")
            }.count
            let staffCount = plan.blocks.filter {
                $0.id.contains("staff-door")
            }.count
            guard dockCount == 5, staffCount == 1 else {
                throw IndustrialL4PrepixelError.invalid(
                    "frontage semantics failed for \(plan.direction)"
                )
            }
            let conflicts = l4VisiblePlaneConflicts(plan)
            guard conflicts.isEmpty else {
                throw IndustrialL4PrepixelError.invalid(
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
            throw IndustrialL4PrepixelError.invalid(
                "directional descriptor or geometry identities are not unique"
            )
        }

        let nativePixelsPerWorld = l4PixelsPerWorld * l4NativeScale
        let semanticFeatures: [[String: Any]] = [
            ["feature": "loading-door-width", "worldUnits": 5.8, "native2xPixels": 5.8 * nativePixelsPerWorld],
            ["feature": "loading-door-height", "worldUnits": 12, "native2xPixels": 12 * nativePixelsPerWorld],
            ["feature": "control-door-width", "worldUnits": 5.5, "native2xPixels": 5.5 * nativePixelsPerWorld],
            ["feature": "stack-diameter", "worldUnits": 5, "native2xPixels": 5 * nativePixelsPerWorld],
            ["feature": "tank-diameter", "worldUnits": 7, "native2xPixels": 7 * nativePixelsPerWorld],
        ]
        let minimumIdentityPixels = semanticFeatures.map {
            $0["native2xPixels"] as! Double
        }.min()!
        guard minimumIdentityPixels >= 6 else {
            throw IndustrialL4PrepixelError.invalid(
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
            throw IndustrialL4PrepixelError.invalid(
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
            l4MaterialLadder(materials),
            to: materialLadderURL
        )

        let acceptedReferences: [(String, String)] = [
            ("industrial-l01-east-block", "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/normalized/industrial_l01/variant-0/east/source-v05/generated_v4_industrial_l01_block.png"),
            ("industrial-l02-east-block", "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v07/source-completion/normalized/run-a/east/generated_v4_industrial_l02_east_source_v05_block.png"),
            ("industrial-l02-east-city", "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v07/source-completion/normalized/run-a/east/generated_v4_industrial_l02_east_source_v05_city.png"),
            ("industrial-l03-east-block", "docs/production/evidence/PLAY-027/industrial-l03/l03/source-completion-v02/normalized/run-a/east/generated_v4_industrial_l03_east_source_v02_block.png"),
            ("industrial-l03-east-city", "docs/production/evidence/PLAY-027/industrial-l03/l03/source-completion-v02/normalized/run-a/east/generated_v4_industrial_l03_east_source_v02_city.png"),
            ("industrial-l03-east-raw", "docs/production/evidence/PLAY-027/industrial-l03/l03/source-completion-v02/diagnostics/raw-repeat/east/run-a/raw.png"),
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
                title: "Level 4 family separation: accepted R/C + analytic Industrial",
                images: crossFamilyImages,
                labels: ["Residential L4", "Commercial L4", "Industrial L4 analytic"],
                cellWidth: 520,
                cellHeight: 430
            ),
            to: crossFamilyColorURL
        )
        try l4WritePNG(
            l4ComparisonStrip(
                title: "Level 4 grayscale family separation",
                images: try crossFamilyImages.map(l4Grayscale),
                labels: ["Residential L4", "Commercial L4", "Industrial L4 analytic"],
                cellWidth: 520,
                cellHeight: 430
            ),
            to: crossFamilyGrayURL
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
            throw IndustrialL4PrepixelError.invalid(
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
            throw IndustrialL4PrepixelError.invalid(
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
            throw IndustrialL4PrepixelError.invalid(
                "gameplay-scale frontage target failed"
            )
        }

        let validation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "batch": "industrial-l04-variant-0-prepixel-v01",
            "publishedAuthority": l4AuthorityBase,
            "acceptedIndustrialL3Continuity": l4ContinuityBase,
            "mergeBoundary": "62115e0f0034fabd9f5120191678bac9c5f5d615",
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
                "capacityStep": "five-bay advanced manufacturing campus above accepted four-bay L3",
                "silhouette": "broad high-bay and assembly steps, control wing, process crown, twin stacks, roof plant and tank group",
                "frontage": "five loading bays plus a separate control/staff entrance on every named road edge",
                "materials": "weathered blue steel, warm concrete, oxide process metal, charcoal depth, light membrane roof and restrained ochre",
                "familyNonAlias": "no residential tower/roof grammar, no commercial floorplate/storefront rhythm, no L1-L3 geometry reuse",
                "r2Response": "adds warm and dark midtone structure to the pale L3 while preserving the shared northwest-value hierarchy",
            ],
            "reviewAuthority":
                "analytic-prepixel-only-not-source-pixels-or-acceptance",
        ]
        let evidenceRoot = outputRoot.appendingPathComponent(
            evidenceRelative
        )
        let validationURL = evidenceRoot.appendingPathComponent(
            "PREPIXEL-VALIDATION.json"
        )
        try l4WriteJSON(validation, to: validationURL)

        let architecture = """
        # Industrial L4 pre-pixel architecture v01

        Authority: `\(l4AuthorityBase)` merged over source continuity `\(l4ContinuityBase)`.

        Disposition: `PENDING_INDEPENDENT_PREPIXEL_REVIEW`

        This source-only family completes the R/C/I level spine with an
        advanced-manufacturing hero campus: a broad high-bay production hall,
        lower stepped assembly volume, warm control/quality wing, five loading
        bays, separate staff entrance, roof plant, pipe gallery, tanks, and twin
        stacks. North and West use independently authored open loading throats;
        no sibling mirror, rotation, recolor, source alias, or camera trick is
        present.

        The palette intentionally answers the pale, clinical R2 L3 read with
        weathered blue steel, warm formed concrete, deep dock recesses,
        restrained oxide and ochre, charcoal structure, and a broken light roof
        membrane. Identity is carried by large volumes and facade rhythm rather
        than source-only greebles.

        Frozen contracts:

        - exact 56 x 56 footprint, `[768,896]` pivot, named sockets and road edges;
        - fixed 2:1 camera and source registration;
        - northwest value language plus authored southeast contact shadow;
        - five readable dock bays and one control entrance in every direction;
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
        five-bay facade, control entrance, high-bay step, process crown, tanks,
        stacks, roof plant, and contact shadow are all directly judgeable.

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
            sourceColorURL, sourceGrayURL, nativeColorURL, nativeGrayURL,
            clayURL, materialLadderURL, progressionColorURL,
            progressionGrayURL, crossFamilyColorURL, crossFamilyGrayURL,
            stagedComparisonURL, cityColorURL, cityGrayURL,
        ]
        let reviewManifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "batch": "industrial-l04-variant-0-prepixel-v01",
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
        2. Are the control wing, five loading bays, high-bay/assembly step, process
           crown, tanks/stacks, roof plant, and ground contact readable at native-2x?
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
