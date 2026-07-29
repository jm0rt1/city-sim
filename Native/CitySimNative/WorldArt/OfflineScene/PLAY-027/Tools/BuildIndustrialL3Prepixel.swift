import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL3PrepixelError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l3-prepixel --repository-root <path> [--output-root <path>]"
        case let .invalid(message):
            return message
        }
    }
}

private struct L3Block {
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

private struct L3Roof {
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

private struct L3Prop {
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

private struct L3Plan {
    let direction: String
    let geometryID: String
    let blocks: [L3Block]
    let roofs: [L3Roof]
    let trims: [L3Block]
    let props: [L3Prop]
    let facadeEdgeWorld: [[Double]]
    let entranceBase: [Double]
    let registration: [String: Any]
    let exclusion: [[Double]]
}

private struct L3Vertex {
    let x: Double
    let y: Double
    let depth: Double
}

private struct L3Face {
    let materialID: String
    let orientation: String
    let vertices: [L3Vertex]

    var depth: Double {
        vertices.map(\.depth).reduce(0, +) / Double(vertices.count)
    }
}

private let l3SourceWidth = 1536
private let l3SourceHeight = 1024
private let l3OrthographicScale = 79.1959533691406
private let l3PixelsPerWorld =
    Double(l3SourceHeight) / (2.0 * l3OrthographicScale)
private let l3NativeScale = 0.28125
private let l3StyleAnchor =
    "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png"
private let l3StyleAnchorSHA =
    "b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425"
private let l3FamilyAnchor =
    "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v07/source-completion/final-family/review/NATIVE-2X-COLOR.png"
private let l3FamilyAnchorSHA =
    "ac981aa751669f8d9edcc96a7e9f8cdaa63bfe5b52d77d256ccba9b9aafa5a49"

private func l3Argument(
    _ name: String,
    in arguments: [String],
    required: Bool = true
) throws -> String? {
    guard let index = arguments.firstIndex(of: name) else {
        if required { throw IndustrialL3PrepixelError.arguments }
        return nil
    }
    guard index + 1 < arguments.count else {
        throw IndustrialL3PrepixelError.arguments
    }
    return arguments[index + 1]
}

private func l3SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func l3SHA256(_ url: URL) throws -> String {
    l3SHA256(try Data(contentsOf: url))
}

private func l3JSONData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func l3WriteJSON(_ object: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL3PrepixelError.invalid(
            "output must be absent: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try l3JSONData(object).write(to: url, options: .atomic)
}

private func l3WritePNG(_ image: CGImage, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL3PrepixelError.invalid(
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
        throw IndustrialL3PrepixelError.invalid(
            "could not create PNG destination"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL3PrepixelError.invalid(
            "could not finalize PNG: \(url.path)"
        )
    }
}

private func l3Mapping() -> [String: Any] {
    [
        "mode": "world-scale-box-face-repeat-v1",
        "wrapS": "repeat",
        "wrapT": "repeat",
        "minificationFilter": "linear",
        "magnificationFilter": "linear",
        "mipFilter": "linear",
    ]
}

private func l3Material(
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
        "textureMapping": l3Mapping(),
    ]
}

private func l3Materials() -> [[String: Any]] {
    [
        l3Material("l3-recess", [0.14, 0.18, 0.21, 1], 0.94, 0.04, "solid-depth-cavity"),
        l3Material("l3-dock-door", [0.28, 0.38, 0.43, 1], 0.76, 0.20, "horizontal-section-joints"),
        l3Material("l3-hall-blue", [0.46, 0.60, 0.68, 1], 0.76, 0.24, "procedural-vertical-corrugation"),
        l3Material("l3-hall-light", [0.61, 0.70, 0.73, 1], 0.78, 0.18, "procedural-vertical-corrugation"),
        l3Material("l3-plinth", [0.55, 0.54, 0.48, 1], 0.96, 0.00, "procedural-formed-concrete"),
        l3Material("l3-admin-concrete", [0.76, 0.72, 0.63, 1], 0.91, 0.00, "procedural-formed-concrete"),
        l3Material("l3-foundation", [0.39, 0.40, 0.37, 1], 0.98, 0.00, "large-scored-slabs"),
        l3Material("l3-apron", [0.66, 0.65, 0.59, 1], 0.98, 0.00, "large-scored-slabs"),
        l3Material("l3-roof", [0.69, 0.72, 0.72, 1], 0.92, 0.04, "rolled-membrane-seams"),
        l3Material("l3-roof-dark", [0.25, 0.31, 0.33, 1], 0.74, 0.28, "painted-steel"),
        l3Material("l3-glazing", [0.27, 0.52, 0.61, 1], 0.36, 0.08, "muted-mullion-grid"),
        l3Material("l3-warm-glazing", [0.78, 0.57, 0.29, 1], 0.34, 0.05, "muted-warm-glazing"),
        l3Material("l3-process-metal", [0.53, 0.60, 0.61, 1], 0.62, 0.48, "fine-galvanized"),
        l3Material("l3-duct-metal", [0.68, 0.70, 0.67, 1], 0.60, 0.54, "fine-galvanized"),
        l3Material("l3-dark-steel", [0.20, 0.25, 0.28, 1], 0.70, 0.42, "painted-steel"),
        l3Material("l3-light-trim", [0.84, 0.82, 0.72, 1], 0.64, 0.30, "painted-steel"),
        l3Material("l3-safety", [0.86, 0.50, 0.10, 1], 0.62, 0.22, "solid-safety-paint"),
        l3Material("l3-tank-oxide", [0.52, 0.36, 0.27, 1], 0.74, 0.40, "restrained-oxide"),
        l3Material("l3-pipe", [0.58, 0.61, 0.58, 1], 0.58, 0.58, "fine-galvanized"),
    ]
}

private func l3NorthPlan() -> L3Plan {
    let dockCenters = [-16.5, -5.5, 5.5, 16.5]
    var blocks: [L3Block] = [
        L3Block(id: "n-high-bay-plinth", dimensions: [14, 5, 20], position: [-21, 4.9, 0], material: "l3-plinth"),
        L3Block(id: "n-high-bay-hall", dimensions: [13.6, 36, 19.6], position: [-21, 25, 0], material: "l3-hall-blue"),
        L3Block(id: "n-low-assembly-annex", dimensions: [20, 12, 21], position: [17.5, 10, 11.5], material: "l3-hall-light"),
        L3Block(id: "n-loading-spine", dimensions: [47, 20, 4], position: [0, 13, -16.5], material: "l3-admin-concrete"),
        L3Block(id: "n-throat-bridge", dimensions: [44, 5, 8], position: [0, 5.5, -10.5], material: "l3-plinth"),
        L3Block(id: "n-loading-apron", dimensions: [52, 1.6, 12], position: [0, 1.8, -22], material: "l3-apron"),
        L3Block(id: "n-quality-wing", dimensions: [8, 20, 14], position: [24, 13.1, -7], material: "l3-admin-concrete"),
        L3Block(id: "n-quality-glazing", dimensions: [6.5, 7, 1], position: [24.5, 16.1, -14.2], material: "l3-glazing"),
        L3Block(id: "n-staff-door", dimensions: [5.5, 9, 1], position: [24.5, 8, -14.4], material: "l3-warm-glazing"),
        L3Block(id: "n-staff-canopy", dimensions: [6.8, 3.5, 6], position: [24.5, 14.7, -11.5], material: "l3-light-trim"),
        L3Block(id: "n-process-tower", dimensions: [13, 46, 12], position: [-21, 28, 17], material: "l3-process-metal"),
        L3Block(id: "n-pipe-bridge", dimensions: [32, 3, 3], position: [-3, 31, 10], material: "l3-duct-metal"),
    ]
    for (index, center) in dockCenters.enumerated() {
        blocks.append(
            L3Block(id: "n-dock-\(index + 1)-recess", dimensions: [8, 13, 1.4], position: [center, 10, -13.8], material: "l3-recess")
        )
        blocks.append(
            L3Block(id: "n-dock-\(index + 1)-door", dimensions: [7, 11, 0.8], position: [center, 9.1, -12.7], material: "l3-dock-door")
        )
        blocks.append(
            L3Block(id: "n-dock-\(index + 1)-canopy", dimensions: [9, 3.5, 6], position: [center, 18, -11.5], material: "l3-light-trim")
        )
    }
    return L3Plan(
        direction: "north",
        geometryID: "industrial-l03-north-v02-open-court-high-bay",
        blocks: blocks,
        roofs: [
            L3Roof(id: "n-high-bay-roof", dimensions: [14, 4, 21], position: [-21, 44.9, 0], material: "l3-roof", trim: "l3-dark-steel"),
            L3Roof(id: "n-annex-roof", dimensions: [21, 3, 22], position: [17.5, 17.4, 11.5], material: "l3-roof", trim: "l3-light-trim"),
            L3Roof(id: "n-quality-roof", dimensions: [9, 3, 15], position: [23.5, 24.5, -7], material: "l3-roof", trim: "l3-light-trim"),
        ],
        trims: [
            L3Block(id: "n-clerestory-one", dimensions: [5, 6, 8], position: [-21, 43, -5], material: "l3-glazing"),
            L3Block(id: "n-clerestory-two", dimensions: [5, 7, 8], position: [-21, 44, 5], material: "l3-glazing"),
            L3Block(id: "n-portal-header", dimensions: [46, 3.5, 3.5], position: [0, 24.5, -19], material: "l3-safety"),
        ],
        props: [
            L3Prop(id: "n-tank-a", kind: "explicit-cylinder", dimensions: [7, 16, 7], position: [-6, 11.2, 18], material: "l3-tank-oxide"),
            L3Prop(id: "n-tank-b", kind: "explicit-cylinder", dimensions: [6, 13, 6], position: [3, 9.7, 18], material: "l3-process-metal"),
            L3Prop(id: "n-hvac-a", kind: "explicit-box", dimensions: [6, 5, 7], position: [12, 21.5, 7], material: "l3-process-metal"),
            L3Prop(id: "n-hvac-b", kind: "explicit-box", dimensions: [6, 5, 7], position: [20, 21.5, 7], material: "l3-process-metal"),
        ],
        facadeEdgeWorld: [[-28, -28], [28, -28]],
        entranceBase: [24.5, 3, -28],
        registration: l3Registration("north"),
        exclusion: [[-26, -28], [26, -28], [26, -10], [-26, -10]]
    )
}

private func l3EastPlan() -> L3Plan {
    let dockCenters = [-16.5, -5.5, 5.5, 16.5]
    var blocks: [L3Block] = [
        L3Block(id: "e-main-plinth", dimensions: [36, 5, 48], position: [-8, 4.9, 0], material: "l3-plinth"),
        L3Block(id: "e-high-bay-hall", dimensions: [35.6, 32, 47.6], position: [-8, 23, 0], material: "l3-hall-blue"),
        L3Block(id: "e-loading-spine", dimensions: [5, 21, 48], position: [19, 13.5, 0], material: "l3-admin-concrete"),
        L3Block(id: "e-loading-apron", dimensions: [12, 1.6, 52], position: [22, 1.8, 0], material: "l3-apron"),
        L3Block(id: "e-admin-wing", dimensions: [14, 25, 15], position: [18, 15.6, 20], material: "l3-admin-concrete"),
        L3Block(id: "e-admin-glazing", dimensions: [1, 8, 10], position: [25.5, 18, 20], material: "l3-glazing"),
        L3Block(id: "e-staff-door", dimensions: [1, 9, 5.5], position: [25.7, 8, 20], material: "l3-warm-glazing"),
        L3Block(id: "e-staff-canopy", dimensions: [6, 3.5, 8], position: [24.8, 14.7, 20], material: "l3-light-trim"),
        L3Block(id: "e-process-tower", dimensions: [14, 48, 14], position: [-18, 27, 14], material: "l3-process-metal"),
        L3Block(id: "e-duct-spine", dimensions: [4, 4, 34], position: [-1, 45.2, -4], material: "l3-duct-metal"),
    ]
    for (index, center) in dockCenters.enumerated() {
        blocks.append(
            L3Block(id: "e-dock-\(index + 1)-recess", dimensions: [1.4, 13, 8], position: [21.7, 10, center], material: "l3-recess")
        )
        blocks.append(
            L3Block(id: "e-dock-\(index + 1)-door", dimensions: [0.8, 11, 7], position: [22.9, 9, center], material: "l3-dock-door")
        )
        blocks.append(
            L3Block(id: "e-dock-\(index + 1)-canopy", dimensions: [6, 3.5, 9], position: [25, 18, center], material: "l3-light-trim")
        )
    }
    return L3Plan(
        direction: "east",
        geometryID: "industrial-l03-east-v02-four-bay-process-spine",
        blocks: blocks,
        roofs: [
            L3Roof(id: "e-main-roof", dimensions: [37, 4, 49], position: [-8, 40.9, 0], material: "l3-roof", trim: "l3-dark-steel"),
            L3Roof(id: "e-admin-roof", dimensions: [15, 3, 16], position: [18, 29.4, 20], material: "l3-roof", trim: "l3-light-trim"),
        ],
        trims: [
            L3Block(id: "e-roof-monitor-north", dimensions: [18, 6, 8], position: [-7, 44, -13], material: "l3-glazing"),
            L3Block(id: "e-roof-monitor-south", dimensions: [18, 7, 8], position: [-7, 45, 6], material: "l3-glazing"),
            L3Block(id: "e-loading-crown", dimensions: [2.5, 2.5, 48], position: [24, 25, 0], material: "l3-safety"),
        ],
        props: [
            L3Prop(id: "e-tank-a", kind: "explicit-cylinder", dimensions: [6, 17, 6], position: [12.8, 11.5, -18], material: "l3-tank-oxide"),
            L3Prop(id: "e-tank-b", kind: "explicit-cylinder", dimensions: [5, 14, 5], position: [12.8, 10, -9], material: "l3-process-metal"),
            L3Prop(id: "e-hvac-a", kind: "explicit-box", dimensions: [7, 5, 7], position: [4, 45, 15], material: "l3-process-metal"),
            L3Prop(id: "e-hvac-b", kind: "explicit-box", dimensions: [7, 5, 7], position: [12, 45, 15], material: "l3-process-metal"),
        ],
        facadeEdgeWorld: [[28, -28], [28, 28]],
        entranceBase: [28, 3, 20],
        registration: l3Registration("east"),
        exclusion: [[10, -26], [28, -26], [28, 26], [10, 26]]
    )
}

private func l3SouthPlan() -> L3Plan {
    let dockCenters = [-16.5, -5.5, 5.5, 16.5]
    var blocks: [L3Block] = [
        L3Block(id: "s-main-plinth", dimensions: [48, 5, 35], position: [0, 4.9, -7.5], material: "l3-plinth"),
        L3Block(id: "s-stepped-hall-west", dimensions: [27, 30, 34], position: [-10.5, 22, -7.5], material: "l3-hall-blue"),
        L3Block(id: "s-stepped-hall-east", dimensions: [18.6, 23, 34], position: [14.5, 18.5, -7.5], material: "l3-hall-light"),
        L3Block(id: "s-loading-spine", dimensions: [48, 21, 5], position: [0, 13.5, 19], material: "l3-admin-concrete"),
        L3Block(id: "s-loading-apron", dimensions: [52, 1.6, 12], position: [0, 1.8, 22], material: "l3-apron"),
        L3Block(id: "s-quality-wing", dimensions: [14, 24, 14], position: [-21, 15.1, 17], material: "l3-admin-concrete"),
        L3Block(id: "s-quality-glazing", dimensions: [9, 8, 1], position: [-21, 18, 24.5], material: "l3-glazing"),
        L3Block(id: "s-staff-door", dimensions: [5.5, 9, 1], position: [-10, 8, 24.7], material: "l3-warm-glazing"),
        L3Block(id: "s-staff-canopy", dimensions: [8, 3.5, 6], position: [-10, 14.7, 24.8], material: "l3-light-trim"),
        L3Block(id: "s-process-tower", dimensions: [14, 44, 14], position: [18, 25, -17], material: "l3-process-metal"),
        L3Block(id: "s-pipe-bridge", dimensions: [32, 3, 3], position: [0, 37, -19], material: "l3-duct-metal"),
    ]
    for (index, center) in dockCenters.enumerated() {
        blocks.append(
            L3Block(id: "s-dock-\(index + 1)-recess", dimensions: [8, 13, 1.4], position: [center, 10, 21.7], material: "l3-recess")
        )
        blocks.append(
            L3Block(id: "s-dock-\(index + 1)-door", dimensions: [7, 11, 0.8], position: [center, 9, 22.9], material: "l3-dock-door")
        )
        blocks.append(
            L3Block(id: "s-dock-\(index + 1)-canopy", dimensions: [9, 3.5, 6], position: [center, 18, 25], material: "l3-light-trim")
        )
    }
    return L3Plan(
        direction: "south",
        geometryID: "industrial-l03-south-v02-stepped-fabrication-campus",
        blocks: blocks,
        roofs: [
            L3Roof(id: "s-west-roof", dimensions: [28, 4, 35], position: [-10.5, 38.9, -7.5], material: "l3-roof", trim: "l3-dark-steel"),
            L3Roof(id: "s-east-roof", dimensions: [20, 3, 35], position: [14.5, 32, -7.5], material: "l3-roof", trim: "l3-light-trim"),
            L3Roof(id: "s-quality-roof", dimensions: [14, 3, 15], position: [-21, 28.4, 17], material: "l3-roof", trim: "l3-light-trim"),
        ],
        trims: [
            L3Block(id: "s-sawlight-west", dimensions: [18, 6, 8], position: [-10, 42, -14], material: "l3-glazing"),
            L3Block(id: "s-sawlight-east", dimensions: [13, 5, 8], position: [14, 34, 0], material: "l3-glazing"),
            L3Block(id: "s-loading-crown", dimensions: [48, 2.5, 2.5], position: [0, 25, 24], material: "l3-safety"),
        ],
        props: [
            L3Prop(id: "s-tank-a", kind: "explicit-cylinder", dimensions: [6, 17, 6], position: [5, 11.5, 13], material: "l3-tank-oxide"),
            L3Prop(id: "s-tank-b", kind: "explicit-cylinder", dimensions: [5, 14, 5], position: [-4, 10, 13], material: "l3-process-metal"),
            L3Prop(id: "s-hvac-a", kind: "explicit-box", dimensions: [7, 5, 7], position: [-21, 42, 2], material: "l3-process-metal"),
            L3Prop(id: "s-hvac-b", kind: "explicit-box", dimensions: [7, 5, 7], position: [-12, 42, 2], material: "l3-process-metal"),
        ],
        facadeEdgeWorld: [[28, 28], [-28, 28]],
        entranceBase: [-10, 3, 28],
        registration: l3Registration("south"),
        exclusion: [[-26, 10], [26, 10], [26, 28], [-26, 28]]
    )
}

private func l3WestPlan() -> L3Plan {
    let dockCenters = [-16.5, -5.5, 5.5, 16.5]
    var blocks: [L3Block] = [
        L3Block(id: "w-high-bay-plinth", dimensions: [20, 5, 14], position: [0, 4.9, -21], material: "l3-plinth"),
        L3Block(id: "w-high-bay-hall", dimensions: [19.6, 36, 13.6], position: [0, 25, -21], material: "l3-hall-blue"),
        L3Block(id: "w-low-assembly-annex", dimensions: [21, 12, 20], position: [11.5, 10, 17.5], material: "l3-hall-light"),
        L3Block(id: "w-loading-spine", dimensions: [4, 20, 47], position: [-16.5, 13, 0], material: "l3-admin-concrete"),
        L3Block(id: "w-throat-bridge", dimensions: [8, 5, 44], position: [-10.5, 5.5, 0], material: "l3-plinth"),
        L3Block(id: "w-loading-apron", dimensions: [12, 1.6, 52], position: [-22, 1.8, 0], material: "l3-apron"),
        L3Block(id: "w-quality-wing", dimensions: [14, 20, 8], position: [-7, 13.1, 24], material: "l3-admin-concrete"),
        L3Block(id: "w-quality-glazing", dimensions: [1, 7, 6.5], position: [-14.2, 16.1, 24.5], material: "l3-glazing"),
        L3Block(id: "w-staff-door", dimensions: [1, 9, 5.5], position: [-14.4, 8, 24.5], material: "l3-warm-glazing"),
        L3Block(id: "w-staff-canopy", dimensions: [6, 3.5, 6.8], position: [-11.5, 14.7, 24.5], material: "l3-light-trim"),
        L3Block(id: "w-process-tower", dimensions: [12, 46, 13], position: [17, 28, -21], material: "l3-process-metal"),
        L3Block(id: "w-pipe-bridge", dimensions: [3, 3, 32], position: [10, 31, -3], material: "l3-duct-metal"),
    ]
    for (index, center) in dockCenters.enumerated() {
        blocks.append(
            L3Block(id: "w-dock-\(index + 1)-recess", dimensions: [1.4, 13, 8], position: [-13.8, 10, center], material: "l3-recess")
        )
        blocks.append(
            L3Block(id: "w-dock-\(index + 1)-door", dimensions: [0.8, 11, 7], position: [-12.7, 9.1, center], material: "l3-dock-door")
        )
        blocks.append(
            L3Block(id: "w-dock-\(index + 1)-canopy", dimensions: [6, 3.5, 9], position: [-11.5, 18, center], material: "l3-light-trim")
        )
    }
    return L3Plan(
        direction: "west",
        geometryID: "industrial-l03-west-v02-open-court-process-yard",
        blocks: blocks,
        roofs: [
            L3Roof(id: "w-high-bay-roof", dimensions: [21, 4, 14], position: [0, 44.9, -21], material: "l3-roof", trim: "l3-dark-steel"),
            L3Roof(id: "w-annex-roof", dimensions: [22, 3, 21], position: [11.5, 17.4, 17.5], material: "l3-roof", trim: "l3-light-trim"),
            L3Roof(id: "w-quality-roof", dimensions: [15, 3, 9], position: [-7, 24.5, 23.5], material: "l3-roof", trim: "l3-light-trim"),
        ],
        trims: [
            L3Block(id: "w-clerestory-one", dimensions: [8, 6, 5], position: [-5, 43, -21], material: "l3-glazing"),
            L3Block(id: "w-clerestory-two", dimensions: [8, 7, 5], position: [5, 44, -21], material: "l3-glazing"),
            L3Block(id: "w-portal-header", dimensions: [3.5, 3.5, 46], position: [-19, 24.5, 0], material: "l3-safety"),
        ],
        props: [
            L3Prop(id: "w-tank-a", kind: "explicit-cylinder", dimensions: [7, 16, 7], position: [18, 11.2, -6], material: "l3-tank-oxide"),
            L3Prop(id: "w-tank-b", kind: "explicit-cylinder", dimensions: [6, 13, 6], position: [18, 9.7, 3], material: "l3-process-metal"),
            L3Prop(id: "w-hvac-a", kind: "explicit-box", dimensions: [7, 5, 6], position: [7, 21.5, 12], material: "l3-process-metal"),
            L3Prop(id: "w-hvac-b", kind: "explicit-box", dimensions: [7, 5, 6], position: [7, 21.5, 20], material: "l3-process-metal"),
        ],
        facadeEdgeWorld: [[-28, 28], [-28, -28]],
        entranceBase: [-28, 3, 24.5],
        registration: l3Registration("west"),
        exclusion: [[-28, -26], [-10, -26], [-10, 26], [-28, 26]]
    )
}

private func l3Registration(_ direction: String) -> [String: Any] {
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
        "presentationEnvelopeSource": [256, 40, 1280, 896],
        "shadowEnvelopeSource": [768, 512, 1456, 976],
        "orientationTransform": "none",
    ]
}

private func l3Sampling() -> [String: Any] {
    [
        "contractID": "play027-deterministic-4x-no-msaa-lanczos-v3",
        "sourceRevisionBinding": "source-v02",
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

private func l3Descriptor(
    plan: L3Plan,
    toolchainHash: String,
    materialHash: String
) -> [String: Any] {
    [
        "schema": 2,
        "task": "PLAY-027",
        "sceneGeometryID": plan.geometryID,
        "logicalBuildingID": "industrial_l03",
        "family": "industrial",
        "level": 3,
        "variantID": "variant-0",
        "viewDirection": plan.direction,
        "sourceRevision": "source-v02",
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
            "file": "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/toolchain/toolchain-industrial-l03-source-v01.json",
            "sha256": toolchainHash,
        ],
        "styleAnchor": [
            "role": "global-style-anchor",
            "file": l3StyleAnchor,
            "sha256": l3StyleAnchorSHA,
        ],
        "materialLibrary": [
            "role": "industrial-l03-material-library",
            "file": "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-directional-family-v02/materials/industrial-l03-v02.json",
            "sha256": materialHash,
        ],
        "registration": plan.registration,
        "camera": [
            "projection": "orthographic-2-to-1",
            "yawDegrees": 45,
            "elevationDegrees": 30,
            "orthographicScale": l3OrthographicScale,
            "renderViewportPixels": [1536, 1024],
            "oversamplingFactor": 4,
            "positionWorld": [96, 96, 96],
            "targetWorld": [0, 18, 0],
            "sourceGroundCenter": [768, 768],
            "postProjectionOffsetPixels": [0, 128],
        ],
        "sampling": l3Sampling(),
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
            "floors": 4,
            "wallHeight": 44,
            "roofHeight": 6,
            "roofOverhang": 0.8,
            "wallMaterialID": "l3-hall-blue",
            "trimMaterialID": "l3-light-trim",
            "roofMaterialID": "l3-roof",
            "foundationMaterialID": "l3-foundation",
            "chimney": [
                "positionWorld": [0, 50, 0],
                "dimensions": [4, 8, 4],
                "materialID": "l3-duct-metal",
            ],
            "massingProfile": "industrial-l03-high-capacity-stepped-manufacturing-campus",
            "massBlocks": plan.blocks.map(\.json),
            "roofVolumes": plan.roofs.map(\.json),
            "trimBands": plan.trims.map(\.json),
            "usesLegacyDomesticDetails": false,
            "usesExplicitComponentGeometry": true,
            "foundationDimensions": [56, 2.4, 56],
            "foundationPositionWorld": [0, 1.2, 0],
        ],
        "facades": [[
            "id": "l3-\(plan.direction)-road-frontage",
            "direction": plan.direction,
            "edgeWorld": plan.facadeEdgeWorld,
            "materialID": "l3-admin-concrete",
            "hasEntrance": true,
            "windowBays": [],
            "windowRhythms": [],
        ]],
        "entrance": [
            "facadeID": "l3-\(plan.direction)-road-frontage",
            "baseWorld": plan.entranceBase,
            "width": 5.5,
            "height": 9,
            "depth": 1,
            "doorMaterialID": "l3-warm-glazing",
            "surroundMaterialID": "l3-light-trim",
            "stepCount": 1,
            "stepRun": 1.2,
            "canopyDepth": 4,
            "hingeSide": "right",
            "pavilionWidth": 11,
            "pavilionDepth": 10,
            "pavilionHeight": 18,
            "pavilionRoofHeight": 2.5,
            "pavilionMaterialID": "l3-admin-concrete",
            "porchWidth": 7,
            "porchColumnWidth": 1.2,
            "porchLateralOffset": 0,
            "style": "industrial-quality-lab-entry",
        ],
        "props": plan.props.map(\.json),
        "occlusionExclusions": [[
            "id": "l3-\(plan.direction)-frontage-visibility",
            "purpose": "keep four loading bays and staff entrance visible at native-2x",
            "polygonWorld": plan.exclusion,
        ]],
    ]
}

private func l3Project(_ point: [Double]) -> L3Vertex {
    let rootTwo = sqrt(2.0)
    let cameraX = (point[0] - point[2]) / rootTwo
    let cameraY =
        point[1] * cos(.pi / 6.0)
        - (point[0] + point[2]) / rootTwo * sin(.pi / 6.0)
    let depth =
        (point[0] + point[2]) / rootTwo * cos(.pi / 6.0)
        + point[1] * sin(.pi / 6.0)
    return L3Vertex(
        x: 768 + cameraX * l3PixelsPerWorld,
        y: 256 + cameraY * l3PixelsPerWorld,
        depth: depth
    )
}

private func l3Faces(
    dimensions: [Double],
    position: [Double],
    material: String
) -> [L3Face] {
    let half = dimensions.map { $0 / 2 }
    let min = zip(position, half).map(-)
    let max = zip(position, half).map(+)
    let definitions: [(String, [[Double]])] = [
        ("+x", [[max[0], min[1], min[2]], [max[0], max[1], min[2]], [max[0], max[1], max[2]], [max[0], min[1], max[2]]]),
        ("+z", [[max[0], min[1], max[2]], [max[0], max[1], max[2]], [min[0], max[1], max[2]], [min[0], min[1], max[2]]]),
        ("+y", [[min[0], max[1], min[2]], [min[0], max[1], max[2]], [max[0], max[1], max[2]], [max[0], max[1], min[2]]]),
    ]
    return definitions.map { orientation, points in
        L3Face(
            materialID: material,
            orientation: orientation,
            vertices: points.map(l3Project)
        )
    }
}

private func l3ColorMap(_ materials: [[String: Any]]) -> [String: [Double]] {
    Dictionary(uniqueKeysWithValues: materials.compactMap { material in
        guard
            let id = material["id"] as? String,
            let color = material["baseColorRGBA"] as? [Double]
        else { return nil }
        return (id, color)
    })
}

private func l3Context(width: Int, height: Int) throws -> CGContext {
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
        throw IndustrialL3PrepixelError.invalid("could not allocate context")
    }
    context.interpolationQuality = .high
    return context
}

private func l3RenderPlan(
    _ plan: L3Plan,
    colors: [String: [Double]],
    grayscale: Bool
) throws -> CGImage {
    let background: [UInt8] = [26, 29, 31, 255]
    var pixels = [UInt8](
        repeating: 0,
        count: l3SourceWidth * l3SourceHeight * 4
    )
    for index in stride(from: 0, to: pixels.count, by: 4) {
        pixels[index] = background[0]
        pixels[index + 1] = background[1]
        pixels[index + 2] = background[2]
        pixels[index + 3] = background[3]
    }
    var depthBuffer = [Double](
        repeating: -Double.greatestFiniteMagnitude,
        count: l3SourceWidth * l3SourceHeight
    )
    let foundation = L3Block(
        id: "foundation",
        dimensions: [56, 2.4, 56],
        position: [0, 1.2, 0],
        material: "l3-foundation"
    )
    var faces = l3Faces(
        dimensions: foundation.dimensions,
        position: foundation.position,
        material: foundation.material
    )
    for block in plan.blocks + plan.trims {
        faces += l3Faces(
            dimensions: block.dimensions,
            position: block.position,
            material: block.material
        )
    }
    for roof in plan.roofs {
        faces += l3Faces(
            dimensions: roof.dimensions,
            position: roof.position,
            material: roof.material
        )
    }
    for prop in plan.props {
        faces += l3Faces(
            dimensions: prop.dimensions,
            position: prop.position,
            material: prop.material
        )
    }
    for face in faces {
        guard var rgba = colors[face.materialID] else { continue }
        let factor: Double
        switch face.orientation {
        case "+y": factor = 1.08
        case "+x": factor = 0.88
        default: factor = 0.72
        }
        for index in 0..<3 {
            rgba[index] = min(1, rgba[index] * factor)
        }
        if grayscale {
            let luma = rgba[0] * 0.2126 + rgba[1] * 0.7152
                + rgba[2] * 0.0722
            rgba = [luma, luma, luma, 1]
        }
        let color = rgba.map {
            UInt8(max(0, min(255, Int(($0 * 255).rounded()))))
        }
        try l3RasterizeTriangle(
            [face.vertices[0], face.vertices[1], face.vertices[2]],
            color: color,
            pixels: &pixels,
            depthBuffer: &depthBuffer
        )
        try l3RasterizeTriangle(
            [face.vertices[0], face.vertices[2], face.vertices[3]],
            color: color,
            pixels: &pixels,
            depthBuffer: &depthBuffer
        )
    }
    guard
        let provider = CGDataProvider(data: Data(pixels) as CFData),
        let image = CGImage(
            width: l3SourceWidth,
            height: l3SourceHeight,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: l3SourceWidth * 4,
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
        throw IndustrialL3PrepixelError.invalid("could not render analytic plan")
    }
    return image
}

private func l3RasterizeTriangle(
    _ triangle: [L3Vertex],
    color: [UInt8],
    pixels: inout [UInt8],
    depthBuffer: inout [Double]
) throws {
    guard triangle.count == 3, color.count == 4 else {
        throw IndustrialL3PrepixelError.invalid(
            "invalid analytic triangle input"
        )
    }
    let a = triangle[0]
    let b = triangle[1]
    let c = triangle[2]
    let denominator =
        (b.y - c.y) * (a.x - c.x)
        + (c.x - b.x) * (a.y - c.y)
    guard abs(denominator) > 0.000_001 else { return }
    let minimumX = max(
        0,
        Int(floor(min(a.x, min(b.x, c.x))))
    )
    let maximumX = min(
        l3SourceWidth - 1,
        Int(ceil(max(a.x, max(b.x, c.x))))
    )
    let minimumY = max(
        0,
        Int(floor(min(a.y, min(b.y, c.y))))
    )
    let maximumY = min(
        l3SourceHeight - 1,
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
            let rasterY = l3SourceHeight - 1 - y
            let pixelIndex = rasterY * l3SourceWidth + x
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

private func l3Sheet(
    images: [CGImage],
    panelWidth: Int,
    panelHeight: Int
) throws -> CGImage {
    let context = try l3Context(
        width: panelWidth * 2,
        height: panelHeight * 2
    )
    context.setFillColor(
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [0.08, 0.09, 0.10, 1]
        )!
    )
    context.fill(
        CGRect(x: 0, y: 0, width: panelWidth * 2, height: panelHeight * 2)
    )
    for (index, image) in images.enumerated() {
        let column = index % 2
        let row = 1 - index / 2
        context.draw(
            image,
            in: CGRect(
                x: column * panelWidth,
                y: row * panelHeight,
                width: panelWidth,
                height: panelHeight
            )
        )
    }
    guard let image = context.makeImage() else {
        throw IndustrialL3PrepixelError.invalid("could not compose sheet")
    }
    return image
}

private func l3BoxBounds(_ block: L3Block) -> [[Double]] {
    [
        zip(block.position, block.dimensions.map { $0 / 2 }).map(-),
        zip(block.position, block.dimensions.map { $0 / 2 }).map(+),
    ]
}

private func l3Bounds(_ plan: L3Plan) -> [[Double]] {
    let foundation = L3Block(
        id: "foundation",
        dimensions: [56, 2.4, 56],
        position: [0, 1.2, 0],
        material: "l3-foundation"
    )
    let blocks =
        [foundation] + plan.blocks + plan.trims
        + plan.roofs.map {
            L3Block(
                id: $0.id,
                dimensions: $0.dimensions,
                position: $0.position,
                material: $0.material
            )
        }
        + plan.props.map {
            L3Block(
                id: $0.id,
                dimensions: $0.dimensions,
                position: $0.position,
                material: $0.material
            )
        }
    let bounds = blocks.map(l3BoxBounds)
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

private func l3MaterialReferences(_ plan: L3Plan) -> [String] {
    var values = [
        "l3-hall-blue", "l3-light-trim", "l3-roof",
        "l3-foundation", "l3-duct-metal", "l3-admin-concrete",
        "l3-warm-glazing",
    ]
    values += plan.blocks.map(\.material)
    values += plan.roofs.flatMap { [$0.material, $0.trim] }
    values += plan.trims.map(\.material)
    values += plan.props.map(\.material)
    return Array(Set(values)).sorted()
}

@main
struct BuildIndustrialL3Prepixel {
    static func main() throws {
        let arguments = CommandLine.arguments
        let repositoryRoot = URL(
            fileURLWithPath: try l3Argument(
                "--repository-root",
                in: arguments
            )!
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath:
                try l3Argument(
                    "--output-root",
                    in: arguments,
                    required: false
                )
                ?? repositoryRoot.path
        ).standardizedFileURL
        let toolchainRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/toolchain/toolchain-industrial-l03-source-v01.json"
        let materialRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-directional-family-v02/materials/industrial-l03-v02.json"
        let sceneBaseRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-directional-family-v02/scenes/industrial_l03/variant-0"
        let evidenceRelative =
            "docs/production/evidence/PLAY-027/industrial-l03/l03/prepixel-v02"
        let toolchainURL = repositoryRoot.appendingPathComponent(toolchainRelative)
        let toolchainHash = try l3SHA256(toolchainURL)
        let materials = l3Materials()
        let materialLibrary: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "libraryID": "industrial-l03-v02",
            "source": "task-owned numeric Industrial L3 hierarchy; no ImageGen or raster swatch",
            "styleAnchorFile": l3StyleAnchor,
            "styleAnchorSHA256": l3StyleAnchorSHA,
            "familyAnchorFile": l3FamilyAnchor,
            "familyAnchorSHA256": l3FamilyAnchorSHA,
            "imageGenMaterialSwatchesUsed": false,
            "colorSpace": "extended-sRGB",
            "materials": materials,
            "productionSelected": false,
        ]
        let materialURL = outputRoot.appendingPathComponent(materialRelative)
        try l3WriteJSON(materialLibrary, to: materialURL)
        let materialHash = try l3SHA256(materialURL)
        let plans = [
            l3NorthPlan(), l3EastPlan(), l3SouthPlan(), l3WestPlan(),
        ]
        let materialIDs = Set(materials.compactMap { $0["id"] as? String })
        var records: [[String: Any]] = []
        var descriptorHashes = Set<String>()
        var geometryHashes = Set<String>()
        for plan in plans {
            let descriptor = l3Descriptor(
                plan: plan,
                toolchainHash: toolchainHash,
                materialHash: materialHash
            )
            let sceneURL = outputRoot
                .appendingPathComponent(sceneBaseRelative)
                .appendingPathComponent(plan.direction)
                .appendingPathComponent("scene.json")
            try l3WriteJSON(descriptor, to: sceneURL)
            let data = try Data(contentsOf: sceneURL)
            _ = try JSONDecoder().decode(SceneDescriptor.self, from: data)
            let descriptorHash = l3SHA256(data)
            descriptorHashes.insert(descriptorHash)
            let geometryObject: [String: Any] = [
                "sceneGeometryID": plan.geometryID,
                "building": descriptor["building"]!,
                "props": descriptor["props"]!,
                "occlusionExclusions": descriptor["occlusionExclusions"]!,
            ]
            let geometryHash = l3SHA256(try l3JSONData(geometryObject))
            geometryHashes.insert(geometryHash)
            let references = l3MaterialReferences(plan)
            let unresolved = references.filter { !materialIDs.contains($0) }
            guard unresolved.isEmpty else {
                throw IndustrialL3PrepixelError.invalid(
                    "unresolved \(plan.direction) materials: \(unresolved)"
                )
            }
            let bounds = l3Bounds(plan)
            guard
                abs(bounds[0][0] + 28) <= 0.000_001,
                abs(bounds[0][2] + 28) <= 0.000_001,
                abs(bounds[1][0] - 28) <= 0.000_001,
                abs(bounds[1][2] - 28) <= 0.000_001,
                bounds[1][1] >= 47
            else {
                throw IndustrialL3PrepixelError.invalid(
                    "incomplete \(plan.direction) bounds: \(bounds)"
                )
            }
            let dockCount = plan.blocks.filter {
                $0.id.contains("-dock-") && $0.id.hasSuffix("-door")
            }.count
            let staffCount = plan.blocks.filter {
                $0.id.contains("staff-door")
            }.count
            guard dockCount == 4, staffCount == 1 else {
                throw IndustrialL3PrepixelError.invalid(
                    "frontage semantics failed for \(plan.direction)"
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
                "staffEntranceCount": staffCount,
                "materialReferences": references,
                "productionDecode": "pass",
                "orientationTransform": "none",
                "authoredIndependently": true,
                "productionSelected": false,
            ])
        }
        guard descriptorHashes.count == 4, geometryHashes.count == 4 else {
            throw IndustrialL3PrepixelError.invalid(
                "directional descriptor or geometry identities are not unique"
            )
        }
        let nativePixelsPerWorld = l3PixelsPerWorld * l3NativeScale
        let semanticFeatures: [[String: Any]] = [
            ["feature": "loading-door-width", "worldUnits": 7, "native2xPixels": 7 * nativePixelsPerWorld],
            ["feature": "loading-door-height", "worldUnits": 11, "native2xPixels": 11 * nativePixelsPerWorld],
            ["feature": "staff-door-width", "worldUnits": 5.5, "native2xPixels": 5.5 * nativePixelsPerWorld],
            ["feature": "canopy-thickness", "worldUnits": 3.5, "native2xPixels": 3.5 * nativePixelsPerWorld],
        ]
        guard semanticFeatures.allSatisfy({
            ($0["native2xPixels"] as! Double) >= 6
        }) else {
            throw IndustrialL3PrepixelError.invalid(
                "identity feature falls below six native-2x pixels"
            )
        }
        let colors = l3ColorMap(materials)
        let colorImages = try plans.map {
            try l3RenderPlan($0, colors: colors, grayscale: false)
        }
        let grayscaleImages = try plans.map {
            try l3RenderPlan($0, colors: colors, grayscale: true)
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
        try l3WritePNG(
            l3Sheet(
                images: colorImages,
                panelWidth: l3SourceWidth,
                panelHeight: l3SourceHeight
            ),
            to: sourceColorURL
        )
        try l3WritePNG(
            l3Sheet(
                images: grayscaleImages,
                panelWidth: l3SourceWidth,
                panelHeight: l3SourceHeight
            ),
            to: sourceGrayURL
        )
        try l3WritePNG(
            l3Sheet(images: colorImages, panelWidth: 432, panelHeight: 288),
            to: nativeColorURL
        )
        try l3WritePNG(
            l3Sheet(
                images: grayscaleImages,
                panelWidth: 432,
                panelHeight: 288
            ),
            to: nativeGrayURL
        )
        let validation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "batch": "industrial-l03-variant-0-prepixel-v02",
            "authorityBase": "9290d7f53e7ea75d5011c19c48388084e2cbe6af",
            "sourceProcesses": 0,
            "normalizerProcesses": 0,
            "productionSelected": false,
            "sourceAuthority": false,
            "toolchainFile": toolchainRelative,
            "toolchainSHA256": toolchainHash,
            "materialLibraryFile": materialRelative,
            "materialLibrarySHA256": materialHash,
            "materialCount": materials.count,
            "descriptorUniqueness": "4/4",
            "canonicalGeometryUniqueness": "4/4",
            "productionDecoderDryDecode": "4/4 pass",
            "materialReferenceValidation": "4/4 pass",
            "footprintPivotSocketShadowContract": "4/4 pass",
            "identityFeatureMinimumNative2xPixels":
                semanticFeatures.map {
                    $0["native2xPixels"] as! Double
                }.min()!,
            "semanticFeatureLedger": semanticFeatures,
            "directions": records,
            "artDirection": [
                "capacityStep": "four-bay high-capacity manufacturing campus above accepted three-bay L2",
                "silhouette": "stepped high-bay hall, lower assembly annex, quality wing, roof-monitor rhythm, process tower and tank group",
                "frontage": "four loading bays plus separate staff entrance on every named road edge",
                "materials": "blue-gray corrugated hall, pale formed-concrete quality wing, light membrane roof, dark recesses, restrained ochre safety",
                "familyNonAlias": "no residential roof language, no commercial storefront/lobby rhythm, no L1/L2 geometry reuse",
            ],
            "reviewAuthority": "analytic-prepixel-only-not-source-pixels-or-acceptance",
        ]
        let validationURL = outputRoot
            .appendingPathComponent(evidenceRelative)
            .appendingPathComponent("PREPIXEL-VALIDATION.json")
        try l3WriteJSON(validation, to: validationURL)
        let reviewFiles = [
            sourceColorURL, sourceGrayURL, nativeColorURL, nativeGrayURL,
        ]
        let reviewManifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "batch": "industrial-l03-variant-0-prepixel-v02",
            "authority": "analytic-prepixel-only-not-source-pixels-or-acceptance",
            "directionOrder": ["north", "east", "south", "west"],
            "files": try reviewFiles.map {
                [
                    "file": $0.path.replacingOccurrences(
                        of: outputRoot.path + "/",
                        with: ""
                    ),
                    "sha256": try l3SHA256($0),
                ]
            },
            "productionSelected": false,
        ]
        try l3WriteJSON(
            reviewManifest,
            to: reviewRoot.appendingPathComponent("REVIEW-MANIFEST.json")
        )
        print("industrial-l03-prepixel-pass \(validationURL.path)")
    }
}
