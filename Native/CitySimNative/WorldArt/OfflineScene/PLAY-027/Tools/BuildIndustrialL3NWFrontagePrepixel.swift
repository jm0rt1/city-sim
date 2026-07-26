import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL3NWFrontagePrepixelError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: build-industrial-l3-nw-frontage-prepixel \
              --repository-root <path> --output-root <path>
            """
        case let .invalid(message):
            return message
        }
    }
}

private struct PreviewBox {
    let id: String
    let dimensions: [Double]
    let position: [Double]
    let materialID: String
}

private struct PreviewVertex {
    let x: Double
    let y: Double
    let depth: Double
}

private struct PreviewFace {
    let id: String
    let materialID: String
    let orientation: String
    let vertices: [PreviewVertex]
}

private struct PreviewRaster {
    let width: Int
    let height: Int
    let pixels: [UInt8]
    let image: CGImage
}

private let repositoryAuthority =
    "db03ab1459ebbc612438859a6602ef9bcc2bef86"
private let returnedCheckpoint =
    "e5613a3faa34b35c15385e465e4e47f17cf88b5e"
private let oldSceneRoot =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-siblings-v01/scenes/"
    + "industrial_l03/variant-0"
private let eastScene =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-east-v01/scenes/"
    + "industrial_l03/variant-0/east/scene.json"
private let southScene =
    oldSceneRoot + "/south/scene.json"
private let outputSceneRoot =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-frontage-v01/scenes/"
    + "industrial_l03/variant-0"
private let evidenceRoot =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "cohesion-a0-frontage-prepixel-v01"
private let materialFile =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-east-v01/materials/"
    + "industrial-l03-cohesion-east-v01.json"
private let expectedHashes = [
    "north":
        "1afaefb06e8e6a91f3e3e6215e9721f1ce8de224cc790e1599c33f956afa12be",
    "east":
        "1e5c69a03a6298f64f4d4d13bb0f523690729b82d5565343f40aaa8278aa3b6d",
    "south":
        "31c7eef5e3f461b97b116288274baa8bc5980ef711d45401645e2925ac326a48",
    "west":
        "9107f7b1055b9b4e523071614687ccf6a9fef728a7318339b1951dfe1a775e1c",
    "materials":
        "f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65",
]
private let sourceWidth = 1536
private let sourceHeight = 1024
private let compactWidth = 512
private let compactHeight = 342
private let orthographicScale = 79.1959533691406
private let pixelsPerWorld =
    Double(sourceHeight) / (2.0 * orthographicScale)

private func requiredArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3NWFrontagePrepixelError.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ target: URL) throws -> String {
    sha256(try Data(contentsOf: target))
}

private func jsonObject(_ target: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: target)
        ) as? [String: Any]
    else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "JSON object expected: \(target.path)"
        )
    }
    return object
}

private func jsonData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func writeJSON(_ object: Any, to target: URL) throws {
    guard !FileManager.default.fileExists(atPath: target.path) else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "output must be absent: \(target.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try jsonData(object).write(to: target, options: .atomic)
}

private func writeText(_ value: String, to target: URL) throws {
    guard !FileManager.default.fileExists(atPath: target.path) else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "output must be absent: \(target.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data((value + "\n").utf8).write(to: target, options: .atomic)
}

private func writePNG(_ image: CGImage, to target: URL) throws {
    guard !FileManager.default.fileExists(atPath: target.path) else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "output must be absent: \(target.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard
        let destination = CGImageDestinationCreateWithURL(
            target as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "could not allocate PNG destination"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "could not finalize PNG: \(target.path)"
        )
    }
}

private func replaceMassBlock(
    _ blocks: inout [[String: Any]],
    id: String,
    expectedDimensions: [Double],
    expectedPosition: [Double],
    dimensions: [Double],
    position: [Double]
) throws {
    guard
        let index = blocks.firstIndex(where: { $0["id"] as? String == id }),
        blocks[index]["dimensions"] as? [Double] == expectedDimensions,
        blocks[index]["positionWorld"] as? [Double] == expectedPosition
    else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "frozen mass block drift: \(id)"
        )
    }
    blocks[index]["dimensions"] = dimensions
    blocks[index]["positionWorld"] = position
}

private func revisedDescriptor(
    _ base: [String: Any],
    direction: String
) throws -> ([String: Any], [[String: Any]]) {
    guard
        direction == "north" || direction == "west",
        base["sourceRevision"] as? String == "source-v04",
        var building = base["building"] as? [String: Any],
        var blocks = building["massBlocks"] as? [[String: Any]],
        var sampling = base["sampling"] as? [String: Any],
        var exclusions = base["occlusionExclusions"] as? [[String: Any]],
        exclusions.count == 1
    else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "\(direction) frozen descriptor shape mismatch"
        )
    }
    var output = base
    var ledger: [[String: Any]] = []
    if direction == "north" {
        try replaceMassBlock(
            &blocks,
            id: "n-throat-bridge",
            expectedDimensions: [44, 5, 8],
            expectedPosition: [0, 5.5, -10.5],
            dimensions: [44, 0.45, 8],
            position: [0, 2.675, -10.5]
        )
        for dockX in [-16.5, -5.5, 5.5, 16.5] {
            let dockNumber = Int((dockX + 27.5) / 11)
            try replaceMassBlock(
                &blocks,
                id: "n-dock-\(dockNumber)-canopy",
                expectedDimensions: [9, 3.5, 6],
                expectedPosition: [dockX, 18, -11.5],
                dimensions: [9, 3.5, 6],
                position: [dockX, 18, -16.5]
            )
        }
        try replaceMassBlock(
            &blocks,
            id: "n-quality-wing",
            expectedDimensions: [8, 20, 14],
            expectedPosition: [24, 13.1, -7],
            dimensions: [7.5, 20, 14],
            position: [23.75, 13.1, -7]
        )
        try replaceMassBlock(
            &blocks,
            id: "n-quality-glazing",
            expectedDimensions: [6.5, 7, 1],
            expectedPosition: [24.5, 16.1, -14.2],
            dimensions: [0.4, 7, 6.5],
            position: [27.8, 16.1, -3.5]
        )
        try replaceMassBlock(
            &blocks,
            id: "n-staff-door",
            expectedDimensions: [5.5, 9, 1],
            expectedPosition: [24.5, 8, -14.4],
            dimensions: [0.4, 9, 5.5],
            position: [27.8, 8, -10.25]
        )
        try replaceMassBlock(
            &blocks,
            id: "n-staff-canopy",
            expectedDimensions: [6.8, 3.5, 6],
            expectedPosition: [24.5, 14.7, -11.5],
            dimensions: [0.6, 3.5, 6.8],
            position: [27.7, 14.7, -10.25]
        )
        output["sceneGeometryID"] =
            "industrial-l03-north-v05-open-loading-court"
        building["massingProfile"] =
            "industrial-l03-north-v05-frontage-first-open-loading-court"
        exclusions[0]["purpose"] =
            "keep at least two complete loading faces and the return-side staff entrance visible at compact neighborhood scale"
        ledger = [
            [
                "id": "n-throat-bridge",
                "reason":
                    "lower continuous foreground threshold below loading-door base without expanding footprint",
                "fromDimensions": [44, 5, 8],
                "toDimensions": [44, 0.45, 8],
                "fromPosition": [0, 5.5, -10.5],
                "toPosition": [0, 2.675, -10.5],
            ],
            [
                "ids": [
                    "n-dock-1-canopy",
                    "n-dock-2-canopy",
                    "n-dock-3-canopy",
                    "n-dock-4-canopy",
                ],
                "reason":
                    "move the retained warm-trim canopies behind the dark loading faces in the far-edge sightline so they frame rather than occlude the doors",
                "positionDeltaWorld": [0, 0, -5],
            ],
            [
                "id": "n-quality-wing",
                "reason":
                    "recess visible-side wall by 0.5 world unit for non-coincident return-side entrance treatment",
                "fromDimensions": [8, 20, 14],
                "toDimensions": [7.5, 20, 14],
                "fromPosition": [24, 13.1, -7],
                "toPosition": [23.75, 13.1, -7],
            ],
            [
                "ids":
                    ["n-quality-glazing", "n-staff-door", "n-staff-canopy"],
                "reason":
                    "move staff identity from camera-hidden far face to separately authored visible return face inside the same governed footprint",
            ],
        ]
    } else {
        try replaceMassBlock(
            &blocks,
            id: "w-throat-bridge",
            expectedDimensions: [8, 5, 44],
            expectedPosition: [-10.5, 5.5, 0],
            dimensions: [8, 0.45, 44],
            position: [-10.5, 2.675, 0]
        )
        for dockZ in [-16.5, -5.5, 5.5, 16.5] {
            let dockNumber = Int((dockZ + 27.5) / 11)
            try replaceMassBlock(
                &blocks,
                id: "w-dock-\(dockNumber)-canopy",
                expectedDimensions: [6, 3.5, 9],
                expectedPosition: [-11.5, 18, dockZ],
                dimensions: [6, 3.5, 9],
                position: [-16.5, 18, dockZ]
            )
        }
        try replaceMassBlock(
            &blocks,
            id: "w-quality-wing",
            expectedDimensions: [14, 20, 8],
            expectedPosition: [-7, 13.1, 24],
            dimensions: [14, 20, 7.5],
            position: [-7, 13.1, 23.75]
        )
        try replaceMassBlock(
            &blocks,
            id: "w-quality-glazing",
            expectedDimensions: [1, 7, 6.5],
            expectedPosition: [-14.2, 16.1, 24.5],
            dimensions: [6.5, 7, 0.4],
            position: [-3.5, 16.1, 27.8]
        )
        try replaceMassBlock(
            &blocks,
            id: "w-staff-door",
            expectedDimensions: [1, 9, 5.5],
            expectedPosition: [-14.4, 8, 24.5],
            dimensions: [5.5, 9, 0.4],
            position: [-10.25, 8, 27.8]
        )
        try replaceMassBlock(
            &blocks,
            id: "w-staff-canopy",
            expectedDimensions: [6, 3.5, 6.8],
            expectedPosition: [-11.5, 14.7, 24.5],
            dimensions: [6.8, 3.5, 0.6],
            position: [-10.25, 14.7, 27.7]
        )
        output["sceneGeometryID"] =
            "industrial-l03-west-v05-open-loading-court"
        building["massingProfile"] =
            "industrial-l03-west-v05-frontage-first-open-loading-court"
        exclusions[0]["purpose"] =
            "keep at least two complete loading faces and the return-side staff entrance visible at compact neighborhood scale"
        ledger = [
            [
                "id": "w-throat-bridge",
                "reason":
                    "lower continuous foreground threshold below loading-door base without expanding footprint",
                "fromDimensions": [8, 5, 44],
                "toDimensions": [8, 0.45, 44],
                "fromPosition": [-10.5, 5.5, 0],
                "toPosition": [-10.5, 2.675, 0],
            ],
            [
                "ids": [
                    "w-dock-1-canopy",
                    "w-dock-2-canopy",
                    "w-dock-3-canopy",
                    "w-dock-4-canopy",
                ],
                "reason":
                    "move the retained warm-trim canopies behind the dark loading faces in the far-edge sightline so they frame rather than occlude the doors",
                "positionDeltaWorld": [-5, 0, 0],
            ],
            [
                "id": "w-quality-wing",
                "reason":
                    "recess visible-side wall by 0.5 world unit for non-coincident return-side entrance treatment",
                "fromDimensions": [14, 20, 8],
                "toDimensions": [14, 20, 7.5],
                "fromPosition": [-7, 13.1, 24],
                "toPosition": [-7, 13.1, 23.75],
            ],
            [
                "ids":
                    ["w-quality-glazing", "w-staff-door", "w-staff-canopy"],
                "reason":
                    "move staff identity from camera-hidden far face to separately authored visible return face inside the same governed footprint",
            ],
        ]
    }
    building["massBlocks"] = blocks
    output["building"] = building
    output["occlusionExclusions"] = exclusions
    output["sourceRevision"] = "source-v05"
    sampling["sourceRevisionBinding"] = "source-v05"
    output["sampling"] = sampling
    return (output, ledger)
}

private func numberArray(_ value: Any?, label: String) throws -> [Double] {
    guard let values = value as? [NSNumber] else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "\(label) numeric array missing"
        )
    }
    return values.map(\.doubleValue)
}

private func boxes(_ descriptor: [String: Any]) throws -> [PreviewBox] {
    guard let building = descriptor["building"] as? [String: Any] else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "building object missing"
        )
    }
    var result: [PreviewBox] = []
    if
        let dimensions = building["foundationDimensions"] as? [Double],
        let position = building["foundationPositionWorld"] as? [Double],
        let material = building["foundationMaterialID"] as? String
    {
        result.append(
            PreviewBox(
                id: "foundation",
                dimensions: dimensions,
                position: position,
                materialID: material
            )
        )
    }
    for key in ["massBlocks", "roofVolumes", "trimBands"] {
        for object in building[key] as? [[String: Any]] ?? [] {
            guard
                let id = object["id"] as? String,
                let dimensions = object["dimensions"] as? [Double],
                let position = object["positionWorld"] as? [Double],
                let material = object["materialID"] as? String
            else {
                throw IndustrialL3NWFrontagePrepixelError.invalid(
                    "\(key) preview primitive malformed"
                )
            }
            result.append(
                PreviewBox(
                    id: id,
                    dimensions: dimensions,
                    position: position,
                    materialID: material
                )
            )
        }
    }
    for object in descriptor["props"] as? [[String: Any]] ?? [] {
        guard
            let id = object["id"] as? String,
            let dimensions = object["dimensions"] as? [Double],
            let position = object["positionWorld"] as? [Double],
            let material = object["materialID"] as? String
        else {
            throw IndustrialL3NWFrontagePrepixelError.invalid(
                "prop preview primitive malformed"
            )
        }
        result.append(
            PreviewBox(
                id: id,
                dimensions: dimensions,
                position: position,
                materialID: material
            )
        )
    }
    return result
}

private func sourceVertex(_ point: [Double]) -> PreviewVertex {
    let rootTwo = sqrt(2.0)
    let cameraX = (point[0] - point[2]) / rootTwo
    let cameraY =
        point[1] * cos(.pi / 6)
        - (point[0] + point[2]) / rootTwo * sin(.pi / 6)
    let depth =
        (point[0] + point[2]) / rootTwo * cos(.pi / 6)
        + point[1] * sin(.pi / 6)
    return PreviewVertex(
        x: 768 + cameraX * pixelsPerWorld,
        y: 768 - cameraY * pixelsPerWorld,
        depth: depth
    )
}

private func faces(_ box: PreviewBox) -> [PreviewFace] {
    let half = box.dimensions.map { $0 / 2 }
    let minimum = zip(box.position, half).map(-)
    let maximum = zip(box.position, half).map(+)
    let definitions: [(String, [[Double]])] = [
        (
            "+x",
            [
                [maximum[0], minimum[1], minimum[2]],
                [maximum[0], maximum[1], minimum[2]],
                [maximum[0], maximum[1], maximum[2]],
                [maximum[0], minimum[1], maximum[2]],
            ]
        ),
        (
            "+z",
            [
                [maximum[0], minimum[1], maximum[2]],
                [maximum[0], maximum[1], maximum[2]],
                [minimum[0], maximum[1], maximum[2]],
                [minimum[0], minimum[1], maximum[2]],
            ]
        ),
        (
            "+y",
            [
                [minimum[0], maximum[1], minimum[2]],
                [minimum[0], maximum[1], maximum[2]],
                [maximum[0], maximum[1], maximum[2]],
                [maximum[0], maximum[1], minimum[2]],
            ]
        ),
    ]
    return definitions.map { orientation, points in
        PreviewFace(
            id: box.id,
            materialID: box.materialID,
            orientation: orientation,
            vertices: points.map(sourceVertex)
        )
    }
}

private func transformed(
    _ vertex: PreviewVertex,
    width: Int,
    height: Int,
    normalization: [String: Any]?
) throws -> PreviewVertex {
    guard let normalization else { return vertex }
    guard
        let registration = normalization["registration"] as? [String: Any],
        let scale =
            (registration["uniform_scale"] as? NSNumber)?.doubleValue
    else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "normalization registration missing"
        )
    }
    let sourceBounds = try numberArray(
        registration["source_bbox"],
        label: "source bounds"
    )
    let targetOrigin = try numberArray(
        registration["target_origin"],
        label: "target origin"
    )
    return PreviewVertex(
        x:
            (targetOrigin[0] + (vertex.x - sourceBounds[0]) * scale)
            * Double(width) / 1536,
        y:
            (targetOrigin[1] + (vertex.y - sourceBounds[1]) * scale)
            * Double(height) / 1024,
        depth: vertex.depth
    )
}

private func rasterize(
    _ triangle: [PreviewVertex],
    color: [UInt8],
    width: Int,
    height: Int,
    pixels: inout [UInt8],
    depth: inout [Double]
) {
    let a = triangle[0]
    let b = triangle[1]
    let c = triangle[2]
    let denominator =
        (b.y - c.y) * (a.x - c.x)
        + (c.x - b.x) * (a.y - c.y)
    guard abs(denominator) > 0.000_001 else { return }
    let minimumX = max(0, Int(floor(min(a.x, min(b.x, c.x)))))
    let maximumX = min(width - 1, Int(ceil(max(a.x, max(b.x, c.x)))))
    let minimumY = max(0, Int(floor(min(a.y, min(b.y, c.y)))))
    let maximumY = min(height - 1, Int(ceil(max(a.y, max(b.y, c.y)))))
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
            let value =
                weightA * a.depth + weightB * b.depth + weightC * c.depth
            let pixel = y * width + x
            guard value > depth[pixel] else { continue }
            depth[pixel] = value
            let offset = pixel * 4
            pixels[offset] = color[0]
            pixels[offset + 1] = color[1]
            pixels[offset + 2] = color[2]
            pixels[offset + 3] = color[3]
        }
    }
}

private enum PreviewMode {
    case color
    case clay
    case grayscale
    case silhouette
    case semantic([String: [UInt8]])
}

private func render(
    descriptor: [String: Any],
    colors: [String: [Double]],
    width: Int,
    height: Int,
    normalization: [String: Any]?,
    mode: PreviewMode
) throws -> PreviewRaster {
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    var depth = [Double](
        repeating: -Double.greatestFiniteMagnitude,
        count: width * height
    )
    for box in try boxes(descriptor) {
        for face in faces(box) {
            let faceColor: [UInt8]
            switch mode {
            case .silhouette:
                faceColor = [236, 236, 236, 255]
            case let .semantic(semantic):
                faceColor = semantic[face.id] ?? [48, 50, 52, 255]
            case .clay:
                let factor =
                    face.orientation == "+y"
                    ? 1.08 : (face.orientation == "+x" ? 0.88 : 0.72)
                faceColor = [
                    UInt8(178 * factor),
                    UInt8(166 * factor),
                    UInt8(146 * factor),
                    255,
                ]
            case .color, .grayscale:
                guard var rgba = colors[face.materialID] else {
                    throw IndustrialL3NWFrontagePrepixelError.invalid(
                        "preview material missing: \(face.materialID)"
                    )
                }
                let factor =
                    face.orientation == "+y"
                    ? 1.08 : (face.orientation == "+x" ? 0.88 : 0.72)
                for index in 0..<3 {
                    rgba[index] = min(1, rgba[index] * factor)
                }
                if case .grayscale = mode {
                    let luma =
                        rgba[0] * 0.2126 + rgba[1] * 0.7152
                        + rgba[2] * 0.0722
                    rgba = [luma, luma, luma, 1]
                }
                faceColor = rgba.map {
                    UInt8(max(0, min(255, Int(($0 * 255).rounded()))))
                }
            }
            let vertices = try face.vertices.map {
                try transformed(
                    $0,
                    width: width,
                    height: height,
                    normalization: normalization
                )
            }
            rasterize(
                [vertices[0], vertices[1], vertices[2]],
                color: faceColor,
                width: width,
                height: height,
                pixels: &pixels,
                depth: &depth
            )
            rasterize(
                [vertices[0], vertices[2], vertices[3]],
                color: faceColor,
                width: width,
                height: height,
                pixels: &pixels,
                depth: &depth
            )
        }
    }
    guard
        let provider = CGDataProvider(data: Data(pixels) as CFData),
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
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
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "preview image creation failed"
        )
    }
    return PreviewRaster(
        width: width,
        height: height,
        pixels: pixels,
        image: image
    )
}

private func panel(
    _ images: [CGImage],
    columns: Int,
    panelWidth: Int,
    panelHeight: Int
) throws -> CGImage {
    let rows = Int(ceil(Double(images.count) / Double(columns)))
    guard let context = CGContext(
        data: nil,
        width: panelWidth * columns,
        height: panelHeight * rows,
        bitsPerComponent: 8,
        bytesPerRow: panelWidth * columns * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "panel context allocation failed"
        )
    }
    context.setFillColor(
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [0.10, 0.11, 0.12, 1]
        )!
    )
    context.fill(
        CGRect(
            x: 0,
            y: 0,
            width: panelWidth * columns,
            height: panelHeight * rows
        )
    )
    context.interpolationQuality = .none
    for (index, image) in images.enumerated() {
        let column = index % columns
        let row = rows - 1 - index / columns
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
    guard let output = context.makeImage() else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "panel image creation failed"
        )
    }
    return output
}

private func drawLine(
    pixels: inout [UInt8],
    width: Int,
    height: Int,
    start: [Double],
    end: [Double],
    color: [UInt8],
    radius: Int
) {
    let deltaX = end[0] - start[0]
    let deltaY = end[1] - start[1]
    let steps = max(1, Int(ceil(max(abs(deltaX), abs(deltaY)) * 2)))
    for step in 0...steps {
        let progress = Double(step) / Double(steps)
        let centerX = Int((start[0] + deltaX * progress).rounded())
        let centerY = Int((start[1] + deltaY * progress).rounded())
        for y in (centerY - radius)...(centerY + radius) {
            for x in (centerX - radius)...(centerX + radius)
            where x >= 0 && x < width && y >= 0 && y < height {
                let offset = (y * width + x) * 4
                pixels[offset] = color[0]
                pixels[offset + 1] = color[1]
                pixels[offset + 2] = color[2]
                pixels[offset + 3] = 255
            }
        }
    }
}

private func imageFromPixels(
    _ pixels: [UInt8],
    width: Int,
    height: Int
) throws -> CGImage {
    guard
        let provider = CGDataProvider(data: Data(pixels) as CFData),
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
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
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "pixel image creation failed"
        )
    }
    return image
}

private func projectedRegistrationPoint(
    _ point: [Double],
    normalization: [String: Any]
) throws -> [Double] {
    guard
        let registration = normalization["registration"] as? [String: Any],
        let scale =
            (registration["uniform_scale"] as? NSNumber)?.doubleValue
    else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "normalizer registration missing"
        )
    }
    let sourceBounds = try numberArray(
        registration["source_bbox"],
        label: "source bounds"
    )
    let targetOrigin = try numberArray(
        registration["target_origin"],
        label: "target origin"
    )
    return [
        (targetOrigin[0] + (point[0] - sourceBounds[0]) * scale)
            * Double(compactWidth) / 1536,
        (targetOrigin[1] + (point[1] - sourceBounds[1]) * scale)
            * Double(compactHeight) / 1024,
    ]
}

private func overlay(
    raster: PreviewRaster,
    descriptor: [String: Any],
    normalization: [String: Any]
) throws -> (CGImage, [String: Any]) {
    guard let registration = descriptor["registration"] as? [String: Any] else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "descriptor registration missing"
        )
    }
    let edge =
        try (registration["frontageEdgeSource"] as? [[NSNumber]] ?? [])
            .map { $0.map(\.doubleValue) }
            .map {
                try projectedRegistrationPoint(
                    $0,
                    normalization: normalization
                )
            }
    let door =
        try (registration["doorBaseSource"] as? [[NSNumber]] ?? [])
            .map { $0.map(\.doubleValue) }
            .map {
                try projectedRegistrationPoint(
                    $0,
                    normalization: normalization
                )
            }
    let socket = try projectedRegistrationPoint(
        try numberArray(
            registration["frontageSocketSource"],
            label: "frontage socket"
        ),
        normalization: normalization
    )
    guard edge.count == 2, door.count == 2 else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "registration overlay dimensions invalid"
        )
    }
    var pixels = raster.pixels
    drawLine(
        pixels: &pixels,
        width: raster.width,
        height: raster.height,
        start: edge[0],
        end: edge[1],
        color: [0, 220, 255, 255],
        radius: 1
    )
    drawLine(
        pixels: &pixels,
        width: raster.width,
        height: raster.height,
        start: door[0],
        end: door[1],
        color: [255, 255, 255, 255],
        radius: 1
    )
    drawLine(
        pixels: &pixels,
        width: raster.width,
        height: raster.height,
        start: [socket[0] - 4, socket[1]],
        end: [socket[0] + 4, socket[1]],
        color: [255, 220, 0, 255],
        radius: 1
    )
    drawLine(
        pixels: &pixels,
        width: raster.width,
        height: raster.height,
        start: [socket[0], socket[1] - 4],
        end: [socket[0], socket[1] + 4],
        color: [255, 220, 0, 255],
        radius: 1
    )
    let midpoint = [
        (door[0][0] + door[1][0]) / 2,
        (door[0][1] + door[1][1]) / 2,
    ]
    let frontageWidth = hypot(
        door[1][0] - door[0][0],
        door[1][1] - door[0][1]
    )
    let socketDistance = hypot(
        midpoint[0] - socket[0],
        midpoint[1] - socket[1]
    )
    return (
        try imageFromPixels(
            pixels,
            width: raster.width,
            height: raster.height
        ),
        [
            "frontageWidthPixels": frontageWidth,
            "socketDistancePixels": socketDistance,
            "frontageWidthAtLeastEightPixels": frontageWidth >= 8,
            "socketBelowTwoPixels": socketDistance < 2,
            "frontageEdgeNeighborhood": edge,
            "doorBaseNeighborhood": door,
            "socketNeighborhood": socket,
            "legend":
                "cyan=authoritative road edge; white=door/loading-base segment; yellow=socket",
        ]
    )
}

private func maskRecord(
    raster: PreviewRaster,
    color: [UInt8]
) -> [String: Any] {
    var minimumX = raster.width
    var minimumY = raster.height
    var maximumX = -1
    var maximumY = -1
    var count = 0
    for y in 0..<raster.height {
        for x in 0..<raster.width {
            let offset = (y * raster.width + x) * 4
            if
                raster.pixels[offset] == color[0],
                raster.pixels[offset + 1] == color[1],
                raster.pixels[offset + 2] == color[2],
                raster.pixels[offset + 3] == 255
            {
                count += 1
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
            }
        }
    }
    let bounds =
        maximumX >= minimumX
        ? [minimumX, minimumY, maximumX + 1, maximumY + 1]
        : [0, 0, 0, 0]
    let width = bounds[2] - bounds[0]
    let height = bounds[3] - bounds[1]
    let fill =
        width > 0 && height > 0
        ? Double(count) / Double(width * height)
        : 0
    return [
        "visiblePixelCount": count,
        "bounds": bounds,
        "widthPixels": width,
        "heightPixels": height,
        "boundingFillRatio": fill,
        "completeRectangleGate":
            width >= 6 && height >= 8 && fill >= 0.55,
    ]
}

private func materialColors(
    _ materialObject: [String: Any]
) throws -> [String: [Double]] {
    guard let materials = materialObject["materials"] as? [[String: Any]] else {
        throw IndustrialL3NWFrontagePrepixelError.invalid(
            "material list missing"
        )
    }
    return try Dictionary(
        uniqueKeysWithValues: materials.map { material in
            guard
                let id = material["id"] as? String,
                let color = material["baseColorRGBA"] as? [Double]
            else {
                throw IndustrialL3NWFrontagePrepixelError.invalid(
                    "material color malformed"
                )
            }
            return (id, color)
        }
    )
}

private func bounds(_ values: [PreviewBox]) -> [[Double]] {
    let minimums = values.map {
        zip($0.position, $0.dimensions.map { $0 / 2 }).map(-)
    }
    let maximums = values.map {
        zip($0.position, $0.dimensions.map { $0 / 2 }).map(+)
    }
    return [
        [
            minimums.map { $0[0] }.min()!,
            minimums.map { $0[1] }.min()!,
            minimums.map { $0[2] }.min()!,
        ],
        [
            maximums.map { $0[0] }.max()!,
            maximums.map { $0[1] }.max()!,
            maximums.map { $0[2] }.max()!,
        ],
    ]
}

private func materialReferences(in value: Any) -> Set<String> {
    if let dictionary = value as? [String: Any] {
        var values = Set<String>()
        for (key, child) in dictionary {
            if
                (key == "materialID" || key.hasSuffix("MaterialID")),
                let materialID = child as? String
            {
                values.insert(materialID)
            }
            values.formUnion(materialReferences(in: child))
        }
        return values
    }
    if let array = value as? [Any] {
        return array.reduce(into: Set<String>()) {
            $0.formUnion(materialReferences(in: $1))
        }
    }
    return []
}

@main
enum BuildIndustrialL3NWFrontagePrepixel {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try requiredArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try requiredArgument(
                "--output-root",
                in: arguments
            )
        ).standardizedFileURL
        let evidence = outputRoot.appendingPathComponent(evidenceRoot)
        guard !FileManager.default.fileExists(atPath: evidence.path) else {
            throw IndustrialL3NWFrontagePrepixelError.invalid(
                "evidence output must be absent"
            )
        }
        let materialURL = repositoryRoot.appendingPathComponent(materialFile)
        guard
            try sha256(materialURL) == expectedHashes["materials"]
        else {
            throw IndustrialL3NWFrontagePrepixelError.invalid(
                "material library hash drift"
            )
        }
        let materialObject = try jsonObject(materialURL)
        let colors = try materialColors(materialObject)
        let materialIDs = Set(colors.keys)
        let inputFiles = [
            "north": "\(oldSceneRoot)/north/scene.json",
            "east": eastScene,
            "south": southScene,
            "west": "\(oldSceneRoot)/west/scene.json",
        ]
        var inputObjects: [String: [String: Any]] = [:]
        for direction in ["north", "east", "south", "west"] {
            let sceneURL =
                repositoryRoot.appendingPathComponent(inputFiles[direction]!)
            guard try sha256(sceneURL) == expectedHashes[direction] else {
                throw IndustrialL3NWFrontagePrepixelError.invalid(
                    "\(direction) descriptor hash drift"
                )
            }
            inputObjects[direction] = try jsonObject(sceneURL)
        }
        var candidateObjects = inputObjects
        var changeLedgers: [String: [[String: Any]]] = [:]
        for direction in ["north", "west"] {
            let revision = try revisedDescriptor(
                inputObjects[direction]!,
                direction: direction
            )
            candidateObjects[direction] = revision.0
            changeLedgers[direction] = revision.1
        }

        var descriptorRecords: [[String: Any]] = []
        var descriptorHashes = Set<String>()
        var geometryIDs = Set<String>()
        for direction in ["north", "west"] {
            let descriptor = candidateObjects[direction]!
            let data = try jsonData(descriptor)
            let decoded = try JSONDecoder().decode(
                SceneDescriptor.self,
                from: data
            )
            let frozenDescriptor = try JSONDecoder().decode(
                SceneDescriptor.self,
                from: jsonData(inputObjects[direction]!)
            )
            guard
                decoded.sourceRevision == "source-v05",
                decoded.logicalBuildingID == "industrial_l03",
                decoded.variantID == "variant-0",
                decoded.viewDirection == direction,
                decoded.authoredIndependently,
                !decoded.productionSelected,
                decoded.registration.orientationTransform == "none",
                decoded.registration == frozenDescriptor.registration,
                decoded.camera == frozenDescriptor.camera,
                decoded.light == frozenDescriptor.light
            else {
                throw IndustrialL3NWFrontagePrepixelError.invalid(
                    "\(direction) frozen contract drift"
                )
            }
            let references = materialReferences(in: descriptor)
            guard references.isSubset(of: materialIDs) else {
                throw IndustrialL3NWFrontagePrepixelError.invalid(
                    "\(direction) unresolved material reference"
                )
            }
            let outputRelative =
                "\(outputSceneRoot)/\(direction)/scene.json"
            let outputURL = outputRoot.appendingPathComponent(outputRelative)
            try writeJSON(descriptor, to: outputURL)
            let rootBounds = bounds(try boxes(descriptor))
            guard
                abs(rootBounds[0][0] + 28) <= 0.000_001,
                abs(rootBounds[0][2] + 28) <= 0.000_001,
                abs(rootBounds[1][0] - 28) <= 0.000_001,
                abs(rootBounds[1][2] - 28) <= 0.000_001,
                rootBounds[1][1] >= 50
            else {
                throw IndustrialL3NWFrontagePrepixelError.invalid(
                    "\(direction) footprint or height envelope drift"
                )
            }
            let descriptorHash = try sha256(outputURL)
            descriptorHashes.insert(descriptorHash)
            geometryIDs.insert(decoded.sceneGeometryID)
            descriptorRecords.append([
                "direction": direction,
                "inputDescriptor": inputFiles[direction]!,
                "inputDescriptorSHA256": expectedHashes[direction]!,
                "candidateDescriptor": outputRelative,
                "candidateDescriptorSHA256": descriptorHash,
                "sceneGeometryID": decoded.sceneGeometryID,
                "rootBoundsWorld": rootBounds,
                "registrationPreserved": true,
                "cameraPreserved": true,
                "lightShadowPreserved": true,
                "materialLibraryPreserved": true,
                "productionDecode": "pass",
                "productionSelected": false,
                "changeLedger": changeLedgers[direction]!,
            ])
        }
        guard descriptorHashes.count == 2, geometryIDs.count == 2 else {
            throw IndustrialL3NWFrontagePrepixelError.invalid(
                "North/West descriptor or geometry alias"
            )
        }
        guard
            try sha256(repositoryRoot.appendingPathComponent(eastScene))
                == expectedHashes["east"],
            try sha256(repositoryRoot.appendingPathComponent(southScene))
                == expectedHashes["south"]
        else {
            throw IndustrialL3NWFrontagePrepixelError.invalid(
                "East or South descriptor mutation"
            )
        }

        let normalizationRoot =
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-family-v01/chroma-repair-v01/normalized/"
            + "run-a"
        var sourceColor: [CGImage] = []
        var clayAndGray: [CGImage] = []
        var compactColor: [CGImage] = []
        var overlays: [CGImage] = []
        var semanticImages: [CGImage] = []
        var silhouetteImages: [CGImage] = []
        var visibilityRecords: [[String: Any]] = []
        var overlayRecords: [[String: Any]] = []
        let semanticPalette: [[UInt8]] = [
            [225, 45, 45, 255],
            [45, 205, 80, 255],
            [45, 115, 235, 255],
            [175, 65, 225, 255],
            [255, 210, 35, 255],
        ]
        for direction in ["north", "east", "south", "west"] {
            let descriptor = candidateObjects[direction]!
            let normalization = try jsonObject(
                repositoryRoot.appendingPathComponent(
                    "\(normalizationRoot)/\(direction)/provenance.json"
                )
            )
            if direction == "north" || direction == "west" {
                sourceColor.append(
                    try render(
                        descriptor: descriptor,
                        colors: colors,
                        width: sourceWidth,
                        height: sourceHeight,
                        normalization: nil,
                        mode: .color
                    ).image
                )
                clayAndGray.append(
                    try render(
                        descriptor: descriptor,
                        colors: colors,
                        width: sourceWidth,
                        height: sourceHeight,
                        normalization: nil,
                        mode: .clay
                    ).image
                )
                clayAndGray.append(
                    try render(
                        descriptor: descriptor,
                        colors: colors,
                        width: sourceWidth,
                        height: sourceHeight,
                        normalization: nil,
                        mode: .grayscale
                    ).image
                )
            }
            let compact = try render(
                descriptor: descriptor,
                colors: colors,
                width: compactWidth,
                height: compactHeight,
                normalization: normalization,
                mode: .color
            )
            if direction == "north" || direction == "west" {
                compactColor.append(compact.image)
                let overlayResult = try overlay(
                    raster: compact,
                    descriptor: descriptor,
                    normalization: normalization
                )
                overlays.append(overlayResult.0)
                var overlayRecord = overlayResult.1
                overlayRecord["direction"] = direction
                overlayRecords.append(overlayRecord)

                let prefix = direction == "north" ? "n" : "w"
                let targetIDs = [
                    "\(prefix)-dock-1-door",
                    "\(prefix)-dock-2-door",
                    "\(prefix)-dock-3-door",
                    "\(prefix)-dock-4-door",
                    "\(prefix)-staff-door",
                ]
                let semantic = Dictionary(
                    uniqueKeysWithValues: zip(targetIDs, semanticPalette)
                )
                let semanticRaster = try render(
                    descriptor: descriptor,
                    colors: colors,
                    width: compactWidth,
                    height: compactHeight,
                    normalization: normalization,
                    mode: .semantic(semantic)
                )
                semanticImages.append(semanticRaster.image)
                var targets: [[String: Any]] = []
                var completeDockCount = 0
                var staffPassed = false
                for (index, id) in targetIDs.enumerated() {
                    var record = maskRecord(
                        raster: semanticRaster,
                        color: semanticPalette[index]
                    )
                    record["id"] = id
                    record["semanticColorRGBA"] = semanticPalette[index]
                    if id.contains("-dock-") {
                        if record["completeRectangleGate"] as? Bool == true {
                            completeDockCount += 1
                        }
                    } else {
                        staffPassed =
                            (record["widthPixels"] as? Int ?? 0) >= 6
                            && (record["heightPixels"] as? Int ?? 0) >= 8
                    }
                    targets.append(record)
                }
                let visibilityRecord: [String: Any] = [
                    "direction": direction,
                    "completeLoadingBayRectangleCount": completeDockCount,
                    "minimumCompleteLoadingBayCount": 2,
                    "staffEntranceSeparatelyReadable": staffPassed,
                    "targets": targets,
                    "passed":
                        completeDockCount >= 2
                        && staffPassed
                        && overlayResult.1[
                            "frontageWidthAtLeastEightPixels"
                        ] as? Bool == true
                        && overlayResult.1[
                            "socketBelowTwoPixels"
                        ] as? Bool == true,
                ]
                guard
                    completeDockCount >= 2,
                    staffPassed,
                    overlayResult.1["frontageWidthAtLeastEightPixels"]
                        as? Bool == true,
                    overlayResult.1["socketBelowTwoPixels"] as? Bool == true
                else {
                    let details = String(
                        data: try jsonData(visibilityRecord),
                        encoding: .utf8
                    ) ?? "unavailable"
                    throw IndustrialL3NWFrontagePrepixelError.invalid(
                        "\(direction) semantic frontage gate failed: \(details)"
                    )
                }
                visibilityRecords.append(visibilityRecord)
            }
            silhouetteImages.append(
                try render(
                    descriptor: descriptor,
                    colors: colors,
                    width: compactWidth,
                    height: compactHeight,
                    normalization: normalization,
                    mode: .silhouette
                ).image
            )
        }

        let reviewRoot = evidence.appendingPathComponent("review")
        let panelSpecs: [(String, CGImage, String)] = [
            (
                "DESCRIPTOR-SOURCE-NW-COLOR.png",
                try panel(
                    sourceColor,
                    columns: 2,
                    panelWidth: sourceWidth,
                    panelHeight: sourceHeight
                ),
                "North/West descriptor-only analytic color; not source pixels"
            ),
            (
                "DESCRIPTOR-SOURCE-NW-CLAY-GRAYSCALE.png",
                try panel(
                    clayAndGray,
                    columns: 2,
                    panelWidth: 768,
                    panelHeight: 512
                ),
                "rows North clay/grayscale then West clay/grayscale; descriptor-only"
            ),
            (
                "COMPACT-PROJECTED-FRONTAGE-NW.png",
                try panel(
                    compactColor,
                    columns: 2,
                    panelWidth: compactWidth,
                    panelHeight: compactHeight
                ),
                "literal descriptor projection through retained normalization registration"
            ),
            (
                "COMPACT-ROAD-SOCKET-OVERLAY-NW.png",
                try panel(
                    overlays,
                    columns: 2,
                    panelWidth: compactWidth,
                    panelHeight: compactHeight
                ),
                "cyan road edge, white door/loading-base segment, yellow socket"
            ),
            (
                "COMPACT-SEMANTIC-VISIBILITY-NW.png",
                try panel(
                    semanticImages,
                    columns: 2,
                    panelWidth: compactWidth,
                    panelHeight: compactHeight
                ),
                "red/green/blue/purple loading doors; yellow staff entrance; gray occluders"
            ),
            (
                "SILHOUETTE-NESW-COMPARISON.png",
                try panel(
                    silhouetteImages,
                    columns: 2,
                    panelWidth: compactWidth,
                    panelHeight: compactHeight
                ),
                "N/E/S/W row-major; revised N/W beside immutable E/S"
            ),
        ]
        var panelRecords: [[String: Any]] = []
        for (filename, image, purpose) in panelSpecs {
            let target = reviewRoot.appendingPathComponent(filename)
            try writePNG(image, to: target)
            panelRecords.append([
                "file":
                    "\(evidenceRoot)/review/\(filename)",
                "sha256": try sha256(target),
                "pixels": [image.width, image.height],
                "purpose": purpose,
                "authority":
                    "descriptor-only analytic pre-pixel visualization; not source pixels or acceptance",
            ])
        }
        let builderRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
            + "BuildIndustrialL3NWFrontagePrepixel.swift"
        let validation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "program": "Wave-011-A0",
            "batch": "industrial-l03-north-west-frontage-prepixel-v01",
            "publishedAuthority": repositoryAuthority,
            "returnedCheckpoint": returnedCheckpoint,
            "sourceRevision": "source-v05",
            "authorizedDirections": ["north", "west"],
            "immutableDirections": [
                [
                    "direction": "east",
                    "descriptor": eastScene,
                    "sha256": expectedHashes["east"]!,
                    "bytePreserved": true,
                ],
                [
                    "direction": "south",
                    "descriptor": southScene,
                    "sha256": expectedHashes["south"]!,
                    "bytePreserved": true,
                ],
            ],
            "materialLibrary": materialFile,
            "materialLibrarySHA256": expectedHashes["materials"]!,
            "materialLibraryBytePreserved": true,
            "descriptors": descriptorRecords,
            "uniqueCandidateDescriptorHashes": descriptorHashes.count,
            "uniqueCandidateGeometryIDs": geometryIDs.count,
            "semanticVisibility": visibilityRecords,
            "roadSocketOverlays": overlayRecords,
            "frontageMinimumPixels": 8,
            "socketDistanceMustBeBelowPixels": 2,
            "footprintPivotSocketDoorBaseLightShadowHeightPreserved": true,
            "plantIdentityPreserved": true,
            "orientationTransform": "none",
            "mirrorRotationRecolorAliasFallback": false,
            "sceneKitProcesses": 0,
            "metalProcesses": 0,
            "rawRenderProcesses": 0,
            "normalizerProcesses": 0,
            "imageGenCalls": 0,
            "sourceAuthority": false,
            "familyAuthority": false,
            "productionSelected": false,
            "reviewPanels": panelRecords,
            "builderSource": builderRelative,
            "builderSourceSHA256": try sha256(
                repositoryRoot.appendingPathComponent(builderRelative)
            ),
            "structuralBoundaryReport":
                "\(evidenceRoot)/STRUCTURAL-BOUNDARIES.json",
            "nextGate":
                "independent pre-pixel review; no raw render authority in this checkpoint",
        ]
        try writeJSON(
            validation,
            to: evidence.appendingPathComponent("PREPIXEL-VALIDATION.json")
        )
        let reviewRequest = """
        # Industrial L3 North/West frontage pre-pixel review

        **Disposition:** `PENDING_INDEPENDENT_PREPIXEL_REVIEW`.

        This descriptor-only checkpoint revises North and West only. It lowers
        the foreground throat threshold below the loading-door base and moves
        each staff entrance to a visible, direction-authored return face.
        East, South, the accepted warm/dark material library, footprint,
        pivot, road socket, door-base midpoint, camera, light, shadow, height
        envelope, and plant/process identity remain frozen.

        The exact-camera semantic gate requires at least two complete loading
        rectangles and one separately readable staff entrance per revised
        direction. The road/socket overlay also requires frontage width of at
        least eight compact pixels and socket error below two pixels.

        All panels are analytic descriptor visualizations, not source pixels
        or art acceptance. No SceneKit, Metal, raw render, normalization,
        renderer, shipping, package, or production-selection process ran.
        """
        try writeText(
            reviewRequest,
            to: evidence.appendingPathComponent(
                "INDEPENDENT-REVIEW-REQUEST.md"
            )
        )
        print(
            "industrial-l03-nw-frontage-prepixel-pass "
                + evidence.path
        )
    }
}
