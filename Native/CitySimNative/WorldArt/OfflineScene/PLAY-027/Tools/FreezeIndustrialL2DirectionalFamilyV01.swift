import CryptoKit
import Foundation

enum IndustrialL2DirectionalFamilyV01Error: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: freeze-industrial-l2-directional-family-v01 \
              --repository-root <path> \
              [--art-output-root <path>] \
              [--evidence-output-root <path>]
            """
        case let .invalid(message):
            return message
        }
    }
}

private let familyV01AuthorityCommit =
    "4918b32f44f4d767203a02421f364e234eeebf10"
private let familyV01EastAnchorCommit =
    "023407791bbebe81f882dd8c7a4b348b79c22e67"
private let familyV01EastDescriptorSHA256 =
    "482bea0169e9229df437b05ca6f0299046d49bb92e2e9d9ef4f3865df9be5fa0"
private let familyV01EastMaterialsSHA256 =
    "6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb"
private let familyV01EastRawSHA256 =
    "a32725fd0ea0436c1f8a13d319c3c66408a7cdf44ff8f2cdb72665839dd685a8"
private let familyV01EastGeometrySHA256 =
    "6c727c4b7053d69578e97c2f73cf3054cd2dda106bf06625e0dac12a356798fb"
private let familyV01OrthographicScale = 79.1959533691406
private let familyV01SourcePixelsPerWorld =
    1024.0 / (2.0 * familyV01OrthographicScale)
private let familyV01Native2xScale = 144.0 / 512.0

private func familyV01Argument(
    _ name: String,
    in arguments: [String],
    required: Bool = true
) throws -> String? {
    guard let index = arguments.firstIndex(of: name) else {
        if required {
            throw IndustrialL2DirectionalFamilyV01Error.arguments
        }
        return nil
    }
    guard index + 1 < arguments.count else {
        throw IndustrialL2DirectionalFamilyV01Error.arguments
    }
    return arguments[index + 1]
}

private func familyV01SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func familyV01SHA256(_ url: URL) throws -> String {
    familyV01SHA256(try Data(contentsOf: url))
}

private func familyV01LoadObject(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL2DirectionalFamilyV01Error.invalid(
            "could not decode \(url.path)"
        )
    }
    return object
}

private func familyV01WriteJSON(
    _ value: Any,
    to url: URL
) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2DirectionalFamilyV01Error.invalid(
            "output must be absent: \(url.path)"
        )
    }
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

private func familyV01WriteText(
    _ value: String,
    to url: URL
) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2DirectionalFamilyV01Error.invalid(
            "output must be absent: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try (value + "\n").write(
        to: url,
        atomically: true,
        encoding: .utf8
    )
}

private func familyV01Block(
    _ id: String,
    _ dimensions: [Double],
    _ position: [Double],
    _ material: String,
    _ role: String,
    identityBearing: Bool = true
) -> [String: Any] {
    [
        "id": id,
        "dimensions": dimensions,
        "positionWorld": position,
        "materialID": material,
        "presentationRole": role,
        "identityBearing": identityBearing,
    ]
}

private func familyV01Prop(
    _ id: String,
    kind: String,
    dimensions: [Double],
    position: [Double],
    material: String,
    role: String,
    identityBearing: Bool = true
) -> [String: Any] {
    [
        "id": id,
        "kind": kind,
        "dimensions": dimensions,
        "positionWorld": position,
        "materialID": material,
        "presentationRole": role,
        "identityBearing": identityBearing,
    ]
}

private func familyV01NorthBlocks() -> [[String: Any]] {
    [
        familyV01Block(
            "n-production-plinth-west", [23, 5, 42], [-15, 4.9, 2],
            "v05-hall-plinth", "grounded western production plinth"
        ),
        familyV01Block(
            "n-production-plinth-east", [23, 5, 36], [15, 5.2, 5],
            "v05-hall-plinth", "stepped eastern production plinth"
        ),
        familyV01Block(
            "n-production-hall-west", [22.6, 18, 41.6], [-15, 16.3, 2],
            "v05-hall-metal", "broad western clear-span hall"
        ),
        familyV01Block(
            "n-production-hall-east", [22.4, 20, 35.6], [15, 17.2, 5],
            "v05-hall-metal", "asymmetric eastern production hall"
        ),
        familyV01Block(
            "n-loading-throat", [21, 15, 2.4], [0, 10, -20.8],
            "v05-recess", "deep North loading throat"
        ),
        familyV01Block(
            "n-dock-door-a", [8.5, 11, 0.8], [-10, 9, -22.4],
            "v05-dock-door", "North loading door A"
        ),
        familyV01Block(
            "n-dock-door-b", [8.5, 11, 0.8], [0, 9, -22.4],
            "v05-dock-door", "North loading door B"
        ),
        familyV01Block(
            "n-dock-door-c", [8.5, 11, 0.8], [10, 9, -22.4],
            "v05-dock-door", "North loading door C"
        ),
        familyV01Block(
            "n-dock-canopy-a", [10, 3, 8], [-10, 17.7, -23.2],
            "v05-light-trim", "North dock canopy A"
        ),
        familyV01Block(
            "n-dock-canopy-b", [10, 3.4, 9], [0, 18.1, -23.8],
            "v05-light-trim", "North dock canopy B"
        ),
        familyV01Block(
            "n-dock-canopy-c", [10, 3, 8], [10, 17.7, -23.2],
            "v05-light-trim", "North dock canopy C"
        ),
        familyV01Block(
            "n-loading-apron", [38, 2.2, 8], [0, 1.1, -24],
            "v05-apron", "socket-aligned North service apron"
        ),
        familyV01Block(
            "n-portal-post-west", [3.5, 29, 3.5], [-15, 20, -20],
            "v05-dark-steel", "grounded far-edge loading portal west"
        ),
        familyV01Block(
            "n-portal-post-east", [3.5, 31, 3.5], [15, 21, -20],
            "v05-dark-steel", "grounded far-edge loading portal east"
        ),
        familyV01Block(
            "n-portal-header", [34, 4, 4], [0, 36.5, -20],
            "v05-safety", "roof-clearing North logistics header"
        ),
        familyV01Block(
            "n-admin-quality-wing", [18, 16, 14], [19, 10.6, -18],
            "v05-admin-concrete", "road-facing administration quality wing"
        ),
        familyV01Block(
            "n-admin-glazing", [12, 6.5, 1.1], [19, 12.2, -25.55],
            "v05-glazing", "North administration glazing band"
        ),
        familyV01Block(
            "n-staff-door", [5.5, 8.5, 0.8], [21, 7.35, -27.4],
            "v05-warm-glazing", "North staff entrance"
        ),
        familyV01Block(
            "n-staff-canopy", [9, 2.5, 6], [21, 13.6, -25],
            "v05-safety", "separate North staff canopy"
        ),
        familyV01Block(
            "n-roof-west", [24, 2.4, 43], [-15, 26.4, 2],
            "v05-roof", "western membrane roof"
        ),
        familyV01Block(
            "n-roof-east", [24, 3.2, 37], [15, 27.4, 5],
            "v05-roof", "raised eastern membrane roof"
        ),
        familyV01Block(
            "n-clerestory-west", [15, 6, 9], [-15, 32.6, 0],
            "v05-glazing", "western daylight monitor"
        ),
        familyV01Block(
            "n-clerestory-east", [13, 7, 9], [15, 34.0, 8],
            "v05-glazing", "asymmetric eastern daylight monitor"
        ),
        familyV01Block(
            "n-process-platform", [18, 3.5, 11], [-18, 29, 18],
            "v05-dark-steel", "secondary process platform"
        ),
        familyV01Block(
            "n-main-duct", [4, 4, 28], [-8, 30.5, 8],
            "v05-duct-metal", "readable North roof duct"
        ),
    ]
}

private func familyV01NorthProps() -> [[String: Any]] {
    [
        familyV01Prop(
            "n-process-vessel", kind: "explicit-cylinder",
            dimensions: [9, 16, 9], position: [-21, 11, 22],
            material: "v05-process-metal", role: "secondary North process vessel"
        ),
        familyV01Prop(
            "n-hvac-bank-a", kind: "explicit-box",
            dimensions: [7, 5, 7], position: [-12, 32.5, 17],
            material: "v05-process-metal", role: "North roof plant A"
        ),
        familyV01Prop(
            "n-hvac-bank-b", kind: "explicit-box",
            dimensions: [7, 5, 7], position: [-21, 32.5, 17],
            material: "v05-process-metal", role: "North roof plant B"
        ),
        familyV01Prop(
            "n-stack", kind: "explicit-cylinder",
            dimensions: [4, 9, 4], position: [-17, 34, 18],
            material: "v05-duct-metal", role: "subordinate North stack"
        ),
        familyV01Prop(
            "n-bollard-west", kind: "explicit-cylinder",
            dimensions: [3.5, 5, 3.5], position: [-18, 3.7, -26],
            material: "v05-safety", role: "North dock protection west"
        ),
        familyV01Prop(
            "n-bollard-east", kind: "explicit-cylinder",
            dimensions: [3.5, 5, 3.5], position: [17, 3.7, -26],
            material: "v05-safety", role: "North dock protection east"
        ),
    ]
}

private func familyV01SouthBlocks() -> [[String: Any]] {
    [
        familyV01Block(
            "s-production-plinth", [42, 5, 43], [0, 4.9, -3],
            "v05-hall-plinth", "continuous South production plinth"
        ),
        familyV01Block(
            "s-production-hall", [41.6, 18, 42.6], [0, 16.3, -3],
            "v05-hall-metal", "wide low South production hall"
        ),
        familyV01Block(
            "s-fabrication-step", [16, 14, 18], [18, 11.5, -18],
            "v05-admin-concrete", "lower southeast fabrication step"
        ),
        familyV01Block(
            "s-loading-spine", [34, 17, 8.5], [7, 11.5, 20.5],
            "v05-hall-plinth", "South logistics frontage spine"
        ),
        familyV01Block(
            "s-loading-throat-a", [8.5, 14, 2.4], [-3, 10, 25.8],
            "v05-recess", "South loading recess A"
        ),
        familyV01Block(
            "s-loading-throat-b", [8.5, 14, 2.4], [7, 10, 25.8],
            "v05-recess", "South loading recess B"
        ),
        familyV01Block(
            "s-loading-throat-c", [8.5, 14, 2.4], [17, 10, 25.8],
            "v05-recess", "South loading recess C"
        ),
        familyV01Block(
            "s-dock-door-a", [8.5, 11, 0.8], [-3, 9, 27.3],
            "v05-dock-door", "South loading door A"
        ),
        familyV01Block(
            "s-dock-door-b", [8.5, 11, 0.8], [7, 9, 27.3],
            "v05-dock-door", "South loading door B"
        ),
        familyV01Block(
            "s-dock-door-c", [8.5, 11, 0.8], [17, 9, 27.3],
            "v05-dock-door", "South loading door C"
        ),
        familyV01Block(
            "s-dock-canopy-a", [10, 3, 7], [-3, 17.7, 24.5],
            "v05-light-trim", "South dock canopy A"
        ),
        familyV01Block(
            "s-dock-canopy-b", [10, 3.6, 8], [7, 18.0, 24],
            "v05-light-trim", "South dock canopy B"
        ),
        familyV01Block(
            "s-dock-canopy-c", [10, 3, 7], [17, 17.7, 24.5],
            "v05-light-trim", "South dock canopy C"
        ),
        familyV01Block(
            "s-loading-apron", [38, 2.2, 6], [7, 1.1, 25],
            "v05-apron", "socket-aligned South service apron"
        ),
        familyV01Block(
            "s-admin-quality-wing", [18, 16, 18], [-19, 10.6, 18],
            "v05-admin-concrete", "separate South administration wing"
        ),
        familyV01Block(
            "s-admin-glazing", [11, 6.5, 1.1], [-19, 12.2, 27.55],
            "v05-glazing", "South administration glazing band"
        ),
        familyV01Block(
            "s-staff-door", [5.5, 8.5, 0.8], [-9, 7.35, 27.4],
            "v05-warm-glazing", "South personnel entrance"
        ),
        familyV01Block(
            "s-staff-canopy", [9, 2.5, 6], [-9, 13.6, 25],
            "v05-safety", "distinct South personnel canopy"
        ),
        familyV01Block(
            "s-roof-west", [21, 2.4, 44], [-11, 26.4, -3],
            "v05-roof", "South western membrane roof"
        ),
        familyV01Block(
            "s-roof-east", [21, 3.2, 44], [11, 27.0, -3],
            "v05-roof", "South raised eastern roof"
        ),
        familyV01Block(
            "s-sawlight-west", [15, 6, 8], [-11, 32.5, -8],
            "v05-glazing", "South western sawlight"
        ),
        familyV01Block(
            "s-sawlight-east", [15, 7, 8], [11, 34.0, 2],
            "v05-glazing", "South eastern sawlight"
        ),
        familyV01Block(
            "s-process-platform", [17, 3.5, 12], [19, 29, -18],
            "v05-dark-steel", "secondary South process platform"
        ),
        familyV01Block(
            "s-main-duct", [28, 4, 4], [3, 30.5, -13],
            "v05-duct-metal", "readable South roof duct"
        ),
    ]
}

private func familyV01SouthProps() -> [[String: Any]] {
    [
        familyV01Prop(
            "s-process-vessel", kind: "explicit-cylinder",
            dimensions: [9, 16, 9], position: [22, 11, -21],
            material: "v05-process-metal", role: "secondary South process vessel"
        ),
        familyV01Prop(
            "s-hvac-bank-a", kind: "explicit-box",
            dimensions: [7, 5, 7], position: [12, 32.5, -16],
            material: "v05-process-metal", role: "South roof plant A"
        ),
        familyV01Prop(
            "s-hvac-bank-b", kind: "explicit-box",
            dimensions: [7, 5, 7], position: [21, 32.5, -16],
            material: "v05-process-metal", role: "South roof plant B"
        ),
        familyV01Prop(
            "s-stack", kind: "explicit-cylinder",
            dimensions: [4, 8, 4], position: [18, 34, -17],
            material: "v05-duct-metal", role: "subordinate South stack"
        ),
        familyV01Prop(
            "s-bollard-west", kind: "explicit-cylinder",
            dimensions: [3.5, 5, 3.5], position: [-10, 3.7, 27],
            material: "v05-safety", role: "South staff route protection"
        ),
        familyV01Prop(
            "s-bollard-east", kind: "explicit-cylinder",
            dimensions: [3.5, 5, 3.5], position: [23, 3.7, 27],
            material: "v05-safety", role: "South dock protection"
        ),
    ]
}

private func familyV01WestBlocks() -> [[String: Any]] {
    [
        familyV01Block(
            "w-production-plinth-north", [40, 5, 23], [2, 4.9, -15],
            "v05-hall-plinth", "grounded northern production plinth"
        ),
        familyV01Block(
            "w-production-plinth-south", [36, 5, 23], [5, 5.1, 15],
            "v05-hall-plinth", "stepped southern production plinth"
        ),
        familyV01Block(
            "w-production-hall-north", [39.6, 18, 22.6], [2, 16.3, -15],
            "v05-hall-metal", "broad northern clear-span hall"
        ),
        familyV01Block(
            "w-production-hall-south", [35.6, 20, 22.4], [5, 17.2, 15],
            "v05-hall-metal", "asymmetric southern production hall"
        ),
        familyV01Block(
            "w-loading-throat", [2.4, 15, 21], [-20.8, 10, 0],
            "v05-recess", "deep West loading throat"
        ),
        familyV01Block(
            "w-dock-door-a", [0.8, 11, 8.5], [-22.4, 9, -10],
            "v05-dock-door", "West loading door A"
        ),
        familyV01Block(
            "w-dock-door-b", [0.8, 11, 8.5], [-22.4, 9, 0],
            "v05-dock-door", "West loading door B"
        ),
        familyV01Block(
            "w-dock-door-c", [0.8, 11, 8.5], [-22.4, 9, 10],
            "v05-dock-door", "West loading door C"
        ),
        familyV01Block(
            "w-dock-canopy-a", [8, 3, 10], [-23.2, 17.7, -10],
            "v05-light-trim", "West dock canopy A"
        ),
        familyV01Block(
            "w-dock-canopy-b", [9, 3.4, 10], [-23.8, 18.1, 0],
            "v05-light-trim", "West dock canopy B"
        ),
        familyV01Block(
            "w-dock-canopy-c", [8, 3, 10], [-23.2, 17.7, 10],
            "v05-light-trim", "West dock canopy C"
        ),
        familyV01Block(
            "w-loading-apron", [8, 2.2, 38], [-24, 1.1, 0],
            "v05-apron", "socket-aligned West service apron"
        ),
        familyV01Block(
            "w-portal-post-north", [3.5, 29, 3.5], [-20, 20, -15],
            "v05-dark-steel", "grounded far-edge loading portal north"
        ),
        familyV01Block(
            "w-portal-post-south", [3.5, 31, 3.5], [-20, 21, 15],
            "v05-dark-steel", "grounded far-edge loading portal south"
        ),
        familyV01Block(
            "w-portal-header", [4, 4, 34], [-20, 36.5, 0],
            "v05-safety", "roof-clearing West logistics header"
        ),
        familyV01Block(
            "w-admin-quality-wing", [14, 16, 18], [-18, 10.6, 19],
            "v05-admin-concrete", "road-facing West administration wing"
        ),
        familyV01Block(
            "w-admin-glazing", [1.1, 6.5, 12], [-25.55, 12.2, 19],
            "v05-glazing", "West administration glazing band"
        ),
        familyV01Block(
            "w-staff-door", [0.8, 8.5, 5.5], [-27.4, 7.35, 21],
            "v05-warm-glazing", "West staff entrance"
        ),
        familyV01Block(
            "w-staff-canopy", [6, 2.5, 9], [-25, 13.6, 21],
            "v05-safety", "separate West staff canopy"
        ),
        familyV01Block(
            "w-roof-north", [41, 2.4, 24], [2, 26.4, -15],
            "v05-roof", "northern membrane roof"
        ),
        familyV01Block(
            "w-roof-south", [37, 3.2, 24], [5, 27.4, 15],
            "v05-roof", "raised southern membrane roof"
        ),
        familyV01Block(
            "w-clerestory-north", [9, 6, 15], [0, 32.6, -15],
            "v05-glazing", "northern daylight monitor"
        ),
        familyV01Block(
            "w-clerestory-south", [9, 7, 13], [8, 34.0, 15],
            "v05-glazing", "asymmetric southern daylight monitor"
        ),
        familyV01Block(
            "w-process-platform", [11, 3.5, 18], [18, 29, -18],
            "v05-dark-steel", "secondary West process platform"
        ),
        familyV01Block(
            "w-main-duct", [28, 4, 4], [8, 30.5, -8],
            "v05-duct-metal", "readable West roof duct"
        ),
    ]
}

private func familyV01WestProps() -> [[String: Any]] {
    [
        familyV01Prop(
            "w-process-vessel", kind: "explicit-cylinder",
            dimensions: [9, 16, 9], position: [22, 11, -21],
            material: "v05-process-metal", role: "secondary West process vessel"
        ),
        familyV01Prop(
            "w-hvac-bank-a", kind: "explicit-box",
            dimensions: [7, 5, 7], position: [17, 32.5, -12],
            material: "v05-process-metal", role: "West roof plant A"
        ),
        familyV01Prop(
            "w-hvac-bank-b", kind: "explicit-box",
            dimensions: [7, 5, 7], position: [17, 32.5, -21],
            material: "v05-process-metal", role: "West roof plant B"
        ),
        familyV01Prop(
            "w-stack", kind: "explicit-cylinder",
            dimensions: [4, 9, 4], position: [18, 34, -17],
            material: "v05-duct-metal", role: "subordinate West stack"
        ),
        familyV01Prop(
            "w-bollard-north", kind: "explicit-cylinder",
            dimensions: [3.5, 5, 3.5], position: [-26, 3.7, -18],
            material: "v05-safety", role: "West dock protection north"
        ),
        familyV01Prop(
            "w-bollard-south", kind: "explicit-cylinder",
            dimensions: [3.5, 5, 3.5], position: [-26, 3.7, 17],
            material: "v05-safety", role: "West dock protection south"
        ),
    ]
}

private func familyV01Registration(
    _ direction: String,
    base: [String: Any]
) throws -> [String: Any] {
    let edgeWorld: [String: [[Double]]] = [
        "north": [[-28, -28], [28, -28]],
        "south": [[28, 28], [-28, 28]],
        "west": [[-28, 28], [-28, -28]],
    ]
    let edgeSource: [String: [[Int]]] = [
        "north": [[768, 640], [1024, 768]],
        "south": [[768, 896], [512, 768]],
        "west": [[512, 768], [768, 640]],
    ]
    let socketSource: [String: [Int]] = [
        "north": [896, 704],
        "south": [640, 832],
        "west": [640, 704],
    ]
    let doorBaseSource: [String: [[Int]]] = [
        "north": [[858, 685], [934, 723]],
        "south": [[678, 851], [602, 813]],
        "west": [[602, 723], [678, 685]],
    ]
    guard
        let world = edgeWorld[direction],
        let source = edgeSource[direction],
        let socket = socketSource[direction],
        let doorBase = doorBaseSource[direction]
    else {
        throw IndustrialL2DirectionalFamilyV01Error.invalid(
            "unsupported direction \(direction)"
        )
    }
    var result = base
    result["frontageEdgeWorld"] = world
    result["frontageEdgeSource"] = source
    result["frontageSocketSource"] = socket
    result["doorBaseSource"] = doorBase
    result["orientationTransform"] = "none"
    return result
}

private func familyV01Facades(_ direction: String) -> [[String: Any]] {
    let edges: [(String, [[Double]])] = [
        ("north", [[-28, -28], [28, -28]]),
        ("east", [[28, -28], [28, 28]]),
        ("south", [[28, 28], [-28, 28]]),
        ("west", [[-28, 28], [-28, -28]]),
    ]
    return edges.map { item in
        [
            "id": "\(item.0)-facade",
            "direction": item.0,
            "edgeWorld": item.1,
            "hasEntrance": item.0 == direction,
            "materialID":
                item.0 == direction
                ? "v05-hall-plinth"
                : "v05-hall-metal",
            "windowBays": [],
            "windowRhythms": [],
        ]
    }
}

private func familyV01Entrance(_ direction: String) -> [String: Any] {
    let baseWorld: [String: [Double]] = [
        "north": [20, 3, -28],
        "south": [-9, 3, 28],
        "west": [-28, 3, 21],
    ]
    return [
        "baseWorld": baseWorld[direction]!,
        "width": 7.0,
        "height": 10.0,
        "depth": 2.4,
        "facadeID": "\(direction)-facade",
        "doorMaterialID": "v05-warm-glazing",
        "surroundMaterialID": "v05-safety",
        "style": "staff-entrance-plus-three-dock-frontage",
        "frontageLoadingDoorCount": 3,
    ]
}

private func familyV01Occlusion(_ direction: String) -> [[String: Any]] {
    let polygons: [String: [[Double]]] = [
        "north": [[-28, -28], [28, -28], [28, -18], [-28, -18]],
        "south": [[28, 18], [-28, 18], [-28, 28], [28, 28]],
        "west": [[-28, 28], [-28, -28], [-18, -28], [-18, 28]],
    ]
    return [
        [
            "id": "\(direction)-industrial-l02-v01-loading-clearance",
            "polygonWorld": polygons[direction]!,
            "purpose":
                "preserve exact socket, three-bay apron, staff route, and authored loading infrastructure",
        ],
    ]
}

private func familyV01Descriptor(
    direction: String,
    blocks: [[String: Any]],
    props: [[String: Any]],
    eastAnchor: [String: Any],
    materialsPath: String
) throws -> [String: Any] {
    guard
        let camera = eastAnchor["camera"] as? [String: Any],
        let light = eastAnchor["light"] as? [String: Any],
        let styleAnchor = eastAnchor["styleAnchor"] as? [String: Any],
        let toolchain = eastAnchor["toolchainFingerprint"] as? [String: Any],
        let baseRegistration =
            eastAnchor["registration"] as? [String: Any],
        var sampling = eastAnchor["sampling"] as? [String: Any],
        var building = eastAnchor["building"] as? [String: Any]
    else {
        throw IndustrialL2DirectionalFamilyV01Error.invalid(
            "immutable East descriptor is malformed"
        )
    }
    let revision = "source-v06"
    sampling["sourceRevisionBinding"] = revision
    sampling["purpose"] = "source-authority"
    building["massBlocks"] = blocks
    building["massingProfile"] =
        "industrial-l02-\(direction)-wide-low-capable-campus-v01"
    building["foundationDimensions"] = [56.0, 2.4, 56.0]
    building["foundationPositionWorld"] = [0.0, 1.2, 0.0]
    building["foundationMaterialID"] = "v05-foundation"
    building["wallHeight"] = 33.0
    building["wallMaterialID"] = "v05-hall-metal"
    building["roofMaterialID"] = "v05-roof"
    building["trimMaterialID"] = "v05-light-trim"
    building["chimney"] = [
        "dimensions": [4.0, 8.0, 4.0],
        "positionWorld":
            direction == "north"
            ? [-17.0, 34.0, 18.0]
            : [18.0, 34.0, -17.0],
        "materialID": "v05-duct-metal",
    ]

    return [
        "schema": 2,
        "task": "PLAY-027",
        "logicalBuildingID": "industrial_l02",
        "family": "industrial",
        "level": 2,
        "variantID": "variant-0",
        "sourceRevision": revision,
        "viewDirection": direction,
        "sceneGeometryID":
            "industrial-l02-\(direction)-wide-low-capable-campus-geometry-v01",
        "authoredIndependently": true,
        "productionSelected": false,
        "derivation": [
            "sourceKind": "independent-scene-description",
            "siblingSource": NSNull(),
            "mirror": false,
            "rotationDegrees": 0,
            "transform": "none",
        ],
        "eastReviewAnchor": [
            "commit": familyV01EastAnchorCommit,
            "descriptorSHA256": familyV01EastDescriptorSHA256,
            "materialLibrarySHA256": familyV01EastMaterialsSHA256,
            "rawSHA256": familyV01EastRawSHA256,
            "sourceAuthority": false,
            "productionSelected": false,
        ],
        "materialLibrary": [
            "file": materialsPath,
            "sha256": familyV01EastMaterialsSHA256,
            "role": "immutable-industrial-l02-east-v05-family-material-anchor",
        ],
        "building": building,
        "props": props,
        "camera": camera,
        "light": light,
        "styleAnchor": styleAnchor,
        "toolchainFingerprint": toolchain,
        "sampling": sampling,
        "registration":
            try familyV01Registration(
                direction,
                base: baseRegistration
            ),
        "entrance": familyV01Entrance(direction),
        "facades": familyV01Facades(direction),
        "occlusionExclusions": familyV01Occlusion(direction),
        "prePixelFamilyAuthority": [
            "approvedContinuationCommit": familyV01AuthorityCommit,
            "scope": "Industrial L2 North South West source-v06 only",
            "sourceAuthorityPixels": false,
            "primaryMetalProcessesConsumed": 0,
            "normalizerProcessesConsumed": 0,
            "productionSelected": false,
        ],
    ]
}

private func familyV01CanonicalGeometry(
    _ descriptor: [String: Any]
) throws -> Data {
    func stripMaterials(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, child) in dictionary
            where !key.lowercased().contains("material") {
                result[key] = stripMaterials(child)
            }
            return result
        }
        if let array = value as? [Any] {
            return array.map(stripMaterials)
        }
        return value
    }
    let keys = [
        "building",
        "camera",
        "registration",
        "entrance",
        "facades",
        "props",
        "occlusionExclusions",
    ]
    var contract: [String: Any] = [:]
    for key in keys {
        guard let value = descriptor[key] else {
            throw IndustrialL2DirectionalFamilyV01Error.invalid(
                "descriptor missing \(key)"
            )
        }
        contract[key] = stripMaterials(value)
    }
    return try JSONSerialization.data(
        withJSONObject: contract,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

private func familyV01PixelInventory(
    repositoryRoot: URL
) throws -> (count: Int, hashes: Set<String>, digest: String) {
    let roots = [
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/raw",
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/normalized",
        "docs/production/evidence/PLAY-027/residential-l02-l04",
        "docs/production/evidence/PLAY-027/commercial-l01-l04",
        "docs/production/evidence/PLAY-027/industrial-l01",
    ]
    var rows: [String] = []
    for path in roots {
        let root = repositoryRoot.appendingPathComponent(path)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        ) else {
            continue
        }
        for case let url as URL in enumerator
        where url.pathExtension.lowercased() == "png" {
            let relative = url.path.replacingOccurrences(
                of: repositoryRoot.path + "/",
                with: ""
            )
            rows.append("\(relative) \(try familyV01SHA256(url))")
        }
    }
    rows.sort()
    let hashes = Set(rows.compactMap { $0.split(separator: " ").last.map(String.init) })
    return (
        rows.count,
        hashes,
        familyV01SHA256(Data(rows.joined(separator: "\n").utf8))
    )
}

@main
enum FreezeIndustrialL2DirectionalFamilyV01Main {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath:
                try familyV01Argument(
                    "--repository-root",
                    in: arguments
                )!
        ).standardizedFileURL
        let canonicalArtPath =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v01"
        let canonicalEvidencePath =
            "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v01"
        let artOutputRoot = URL(
            fileURLWithPath:
                try familyV01Argument(
                    "--art-output-root",
                    in: arguments,
                    required: false
                ) ?? repositoryRoot.appendingPathComponent(
                    canonicalArtPath
                ).path
        ).standardizedFileURL
        let evidenceOutputRoot = URL(
            fileURLWithPath:
                try familyV01Argument(
                    "--evidence-output-root",
                    in: arguments,
                    required: false
                ) ?? repositoryRoot.appendingPathComponent(
                    canonicalEvidencePath
                ).path
        ).standardizedFileURL
        guard
            artOutputRoot.path.contains(
                "industrial-l02-directional-family-v01"
            ),
            evidenceOutputRoot.path.contains(
                "industrial-l02/l02/directional-family-v01"
            ),
            !FileManager.default.fileExists(atPath: artOutputRoot.path),
            !FileManager.default.fileExists(atPath: evidenceOutputRoot.path)
        else {
            throw IndustrialL2DirectionalFamilyV01Error.invalid(
                "outputs must be absent and task-owned"
            )
        }

        let eastDescriptorURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialsURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/materials/industrial-l02-east-calibration-v05.json"
        )
        let eastRawURL = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05/raw-calibration/diagnostics/east-primary/raw.png"
        )
        guard
            try familyV01SHA256(eastDescriptorURL)
                == familyV01EastDescriptorSHA256,
            try familyV01SHA256(materialsURL)
                == familyV01EastMaterialsSHA256,
            try familyV01SHA256(eastRawURL)
                == familyV01EastRawSHA256
        else {
            throw IndustrialL2DirectionalFamilyV01Error.invalid(
                "immutable East v05 anchor drift"
            )
        }
        let eastAnchor = try familyV01LoadObject(eastDescriptorURL)
        let materialsPath =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/materials/industrial-l02-east-calibration-v05.json"
        let definitions: [
            (
                direction: String,
                blocks: [[String: Any]],
                props: [[String: Any]]
            )
        ] = [
            ("north", familyV01NorthBlocks(), familyV01NorthProps()),
            ("south", familyV01SouthBlocks(), familyV01SouthProps()),
            ("west", familyV01WestBlocks(), familyV01WestProps()),
        ]

        var directionRows: [[String: Any]] = []
        var descriptorHashes = Set<String>()
        var geometryHashes = Set<String>()
        var candidateHashes = Set<String>()
        var allPassed = true
        for definition in definitions {
            let descriptor = try familyV01Descriptor(
                direction: definition.direction,
                blocks: definition.blocks,
                props: definition.props,
                eastAnchor: eastAnchor,
                materialsPath: materialsPath
            )
            let descriptorURL = artOutputRoot.appendingPathComponent(
                "scenes/industrial_l02/variant-0/\(definition.direction)/scene.json"
            )
            try familyV01WriteJSON(descriptor, to: descriptorURL)
            let descriptorHash = try familyV01SHA256(descriptorURL)
            let geometryHash = familyV01SHA256(
                try familyV01CanonicalGeometry(descriptor)
            )
            descriptorHashes.insert(descriptorHash)
            geometryHashes.insert(geometryHash)
            candidateHashes.insert(descriptorHash)
            candidateHashes.insert(geometryHash)

            let components = definition.blocks + definition.props
            let ids = components.compactMap { $0["id"] as? String }
            let materialIDs = Set(
                components.compactMap { $0["materialID"] as? String }
            )
            let dockDoors = ids.filter {
                $0.hasPrefix("\(definition.direction.first!)-dock-door-")
            }.count
            let dockCanopies = ids.filter {
                $0.hasPrefix("\(definition.direction.first!)-dock-canopy-")
            }.count
            let minimumWorld = components.compactMap { component -> Double? in
                guard
                    component["identityBearing"] as? Bool == true,
                    let dimensions = component["dimensions"] as? [Double],
                    let id = component["id"] as? String
                else {
                    return nil
                }
                if id.contains("door")
                    || id.contains("glazing")
                    || id.contains("recess")
                {
                    return min(dimensions[1], dimensions[2])
                }
                return min(dimensions[0], dimensions[2])
            }.min() ?? 0
            let minimumNative =
                minimumWorld
                * familyV01SourcePixelsPerWorld
                * familyV01Native2xScale
            let uniqueIDs = Set(ids).count == ids.count
            let passed =
                uniqueIDs
                && dockDoors == 3
                && dockCanopies == 3
                && minimumNative >= 6
                && materialIDs.allSatisfy { $0.hasPrefix("v05-") }
                && descriptorHash != familyV01EastDescriptorSHA256
                && geometryHash != familyV01EastGeometrySHA256
            allPassed = allPassed && passed
            directionRows.append(
                [
                    "direction": definition.direction,
                    "sourceRevision": "source-v06",
                    "descriptorSHA256": descriptorHash,
                    "canonicalGeometrySHA256": geometryHash,
                    "sceneGeometryID":
                        "industrial-l02-\(definition.direction)-wide-low-capable-campus-geometry-v01",
                    "componentCount": components.count,
                    "uniqueComponentIDs": uniqueIDs,
                    "materialRoleCount": materialIDs.count,
                    "dockDoorCount": dockDoors,
                    "dockCanopyCount": dockCanopies,
                    "minimumIdentityWorld": minimumWorld,
                    "minimumIdentityNative2xPixels": minimumNative,
                    "orientationTransform": "none",
                    "authoredIndependently": true,
                    "sourceAuthorityPixels": false,
                    "productionSelected": false,
                    "passed": passed,
                ]
            )
        }

        let pixelInventory = try familyV01PixelInventory(
            repositoryRoot: repositoryRoot
        )
        let aliasIntersection = candidateHashes.intersection(
            pixelInventory.hashes
        ).sorted()
        allPassed =
            allPassed
            && descriptorHashes.count == 3
            && geometryHashes.count == 3
            && aliasIntersection.isEmpty

        let contract: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-directional-family-v01-prepixel-contract",
            "approvedContinuationCommit": familyV01AuthorityCommit,
            "scope": ["north", "south", "west"],
            "immutableEastReviewAnchor": [
                "commit": familyV01EastAnchorCommit,
                "descriptorSHA256": familyV01EastDescriptorSHA256,
                "canonicalGeometrySHA256": familyV01EastGeometrySHA256,
                "materialLibrarySHA256": familyV01EastMaterialsSHA256,
                "rawSHA256": familyV01EastRawSHA256,
                "sourceAuthority": false,
                "productionSelected": false,
            ],
            "sharedArtDirection": [
                "family": "credible medium logistics and manufacturing campus",
                "massing":
                    "wide low production hall with separate administration quality wing and subordinate process plant",
                "frontage":
                    "three grounded loading docks plus a staff entrance on the named road edge",
                "materials":
                    "pale formed concrete, blue-gray corrugated hall, light membrane roof and apron, readable recess-door-glazing hierarchy, restrained ochre safety",
                "projection": "orthographic-2:1",
                "northwestLight": true,
                "southeastAuthoredContactShadow": true,
                "minimumIdentityNative2xPixels": 6,
            ],
            "sampling": [
                "contract": "schema-2-v3",
                "sceneKitAntialiasing": "none",
                "linearOversamplingFactor": 4,
                "softwareLanczosScale": 0.25,
                "finiteEquivalenceTable": false,
                "preLanczosGlobalRepair": false,
            ],
            "primaryGate": [
                "order": ["north", "west", "south"],
                "freshMetalProcessesPerDirection": 1,
                "stopOnFirstFailure": true,
                "repeatAndNormalizationBlockedUntilFourPrimaryReview": true,
            ],
            "repeatGate": [
                "freshMetalProcessesPerDirection": 3,
                "normalizerProcessesPerDirection": 2,
                "lods": ["block", "neighborhood", "city"],
                "exactFileAndDecodedPixelIdentity": true,
            ],
            "productionSelected": false,
        ]
        try familyV01WriteJSON(
            contract,
            to: evidenceOutputRoot.appendingPathComponent(
                "prepixel/PREPIXEL-CONTRACT.json"
            )
        )
        let validation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type":
                "industrial-l02-directional-family-v01-prepixel-validation",
            "passed": allPassed,
            "directions": directionRows,
            "uniqueDescriptorHashCount": descriptorHashes.count,
            "uniqueGeometryHashCount": geometryHashes.count,
            "acceptedAndRetainedPixelInventoryCount": pixelInventory.count,
            "acceptedAndRetainedPixelInventoryDigestSHA256":
                pixelInventory.digest,
            "candidateDescriptorGeometryToPixelHashIntersection":
                aliasIntersection,
            "eastDescriptorBytePreserved":
                try familyV01SHA256(eastDescriptorURL)
                == familyV01EastDescriptorSHA256,
            "eastMaterialLibraryBytePreserved":
                try familyV01SHA256(materialsURL)
                == familyV01EastMaterialsSHA256,
            "eastRawBytePreserved":
                try familyV01SHA256(eastRawURL)
                == familyV01EastRawSHA256,
            "sourceAuthorityRawPixelCount": 0,
            "normalizerProcessCount": 0,
            "productionSelected": false,
        ]
        try familyV01WriteJSON(
            validation,
            to: evidenceOutputRoot.appendingPathComponent(
                "prepixel/PREPIXEL-VALIDATION.json"
            )
        )
        let directionHashRows = directionRows.map {
            "- \($0["direction"] as! String): descriptor `\($0["descriptorSHA256"] as! String)`, geometry `\($0["canonicalGeometrySHA256"] as! String)`"
        }.joined(separator: "\n")
        try familyV01WriteText(
            """
            # PLAY-027 Industrial L2 directional family v01 art direction

            Status: `PREPIXEL_REVIEW_CANDIDATE`

            East v05 remains the immutable governed review anchor. North, South,
            and West are three separately authored source-v06 descriptors. No
            sibling mirror, rotation, transform, raster alias, recolor-only
            substitution, governed raw, normalization, or production selection
            is present.

            ## Direction identities

            - North: split production halls create a real far-edge loading throat;
              three dock canopies and a grounded portal header clear the roofline,
              with the administration wing on the road-facing northeast corner.
            - South: a broad single hall uses an asymmetric sawlight rhythm,
              separate southwest administration wing, and three near-edge docks.
            - West: split north/south halls create the second physical far-edge
              loading throat; its apron, portal posts, and roof-clearing header
              terminate at the exact West socket.

            ## Shared value and scale rules

            The immutable East v05 material library supplies every material role.
            Identity must survive at six or more native-2x pixels. Dark recesses
            are bounded by readable loading doors and high-value canopies; safety
            ochre remains subordinate. The family retains the 56×56 footprint,
            fixed pivot, four sockets, 2:1 camera, northwest light, and southeast
            authored contact shadow.

            ## Frozen identities

            \(directionHashRows)

            All descriptors retain `sourceAuthority=false` by absence of governed
            pixels and `productionSelected=false`. Analytic panels are explicitly
            non-authority.
            """,
            to: evidenceOutputRoot.appendingPathComponent(
                "prepixel/ART-DIRECTION.md"
            )
        )
        try familyV01WriteText(
            """
            # PLAY-027 Industrial L2 directional family v01 review request

            Disposition: `PENDING_INDEPENDENT_PREPIXEL_REVIEW`.

            Review the labeled analytic four-view and North/West far-edge panels.
            The East column is the immutable governed v05 reference; North, South,
            and West are non-authority descriptor visualizations.

            Reject before pixels if any new direction reads as a rotated sibling,
            loses three separate docks, hides its staff entrance, becomes a dark
            box, depends on subpixel detail, aliases Industrial L1, breaks the
            family material/value hierarchy, or misregisters pivot/socket/shadow.

            If the pre-pixel gate passes, authorize exactly one fresh primary for
            North and West first, then South. B/C repeats and two-run
            normalization remain blocked until the four-primary family sheet is
            independently reviewed.
            """,
            to: evidenceOutputRoot.appendingPathComponent(
                "prepixel/PREPIXEL-REVIEW-REQUEST.md"
            )
        )
        guard allPassed else {
            throw IndustrialL2DirectionalFamilyV01Error.invalid(
                "prepixel family validation failed"
            )
        }
        print(
            "PASS descriptors=\(descriptorHashes.count) geometries=\(geometryHashes.count) aliasIntersection=\(aliasIntersection.count)"
        )
    }
}
