import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL2DirectionalFamilyV02PanelError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: build-industrial-l2-directional-family-v02-panels \
              --repository-root <path> [--output-root <path>]
            """
        case let .invalid(message):
            return message
        }
    }
}

private struct FamilyV02PanelVertex {
    let x: Double
    let y: Double
    let depth: Double
}

private struct FamilyV02PanelFace {
    let materialID: String
    let orientation: String
    let vertices: [FamilyV02PanelVertex]

    var depth: Double {
        vertices.map(\.depth).reduce(0, +) / Double(vertices.count)
    }
}

private let familyV02PanelDescriptorHashes = [
    "north":
        "57dd375469958d77186d952d34353335e91bcab9399941d0a61e7550a80f19d5",
    "south":
        "4c9e423236a77f668907d693582efb27122b77f3b2c9cc0fb23767c0c2a9f394",
    "west":
        "9d31e29abcb232f406441b3660b00d0150cf7745dfacd3c22bcbb597c434162e",
]
private let familyV02PanelEastDescriptorSHA256 =
    "482bea0169e9229df437b05ca6f0299046d49bb92e2e9d9ef4f3865df9be5fa0"
private let familyV02PanelMaterialsSHA256 =
    "6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb"
private let familyV02PanelEastNeutralSHA256 =
    "673d0719921ded3420f732cdaf95ef9850d53da3ac8e88d07832e2b9bd87d2da"
private let familyV02PanelSourceWidth = 1536
private let familyV02PanelSourceHeight = 1024
private let familyV02PanelPixelsPerWorld =
    1024.0 / (2.0 * 79.1959533691406)

private func familyV02PanelArgument(
    _ name: String,
    in arguments: [String],
    required: Bool = true
) throws -> String? {
    guard let index = arguments.firstIndex(of: name) else {
        if required {
            throw IndustrialL2DirectionalFamilyV02PanelError.arguments
        }
        return nil
    }
    guard index + 1 < arguments.count else {
        throw IndustrialL2DirectionalFamilyV02PanelError.arguments
    }
    return arguments[index + 1]
}

private func familyV02PanelSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func familyV02PanelSHA256(_ url: URL) throws -> String {
    familyV02PanelSHA256(try Data(contentsOf: url))
}

private func familyV02PanelObject(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "could not decode \(url.path)"
        )
    }
    return object
}

private func familyV02PanelContext(
    width: Int,
    height: Int
) throws -> CGContext {
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
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "could not create bitmap context"
        )
    }
    context.interpolationQuality = .high
    return context
}

private func familyV02PanelWritePNG(
    _ image: CGImage,
    to url: URL
) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "panel output must be absent: \(url.path)"
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
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "could not create PNG destination"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "could not finalize \(url.path)"
        )
    }
}

private func familyV02PanelWriteJSON(
    _ value: Any,
    to url: URL
) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "panel report must be absent: \(url.path)"
        )
    }
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try data.write(to: url, options: .atomic)
}

private func familyV02PanelLoadImage(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "could not load \(url.path)"
        )
    }
    return image
}

private func familyV02PanelProject(
    _ point: [Double]
) -> FamilyV02PanelVertex {
    let rootTwo = sqrt(2.0)
    let cameraX = (point[0] - point[2]) / rootTwo
    let cameraY =
        point[1] * cos(.pi / 6.0)
        - (point[0] + point[2]) / rootTwo * sin(.pi / 6.0)
    let depth =
        (point[0] + point[2]) / rootTwo * cos(.pi / 6.0)
        + point[1] * sin(.pi / 6.0)
    return FamilyV02PanelVertex(
        x: 768.0 + cameraX * familyV02PanelPixelsPerWorld,
        y: 256.0 + cameraY * familyV02PanelPixelsPerWorld,
        depth: depth
    )
}

private func familyV02PanelFaces(
    dimensions: [Double],
    position: [Double],
    materialID: String
) -> [FamilyV02PanelFace] {
    let half = dimensions.map { $0 / 2.0 }
    let minimum = zip(position, half).map(-)
    let maximum = zip(position, half).map(+)
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
    return definitions.map {
        FamilyV02PanelFace(
            materialID: materialID,
            orientation: $0.0,
            vertices: $0.1.map(familyV02PanelProject)
        )
    }
}

private func familyV02PanelColor(
    _ values: [Double],
    factor: Double,
    grayscale: Bool
) -> NSColor {
    var red = min(1, max(0, values[0] * factor))
    var green = min(1, max(0, values[1] * factor))
    var blue = min(1, max(0, values[2] * factor))
    if grayscale {
        let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        red = luma
        green = luma
        blue = luma
    }
    return NSColor(
        calibratedRed: red,
        green: green,
        blue: blue,
        alpha: 1
    )
}

private func familyV02PanelDrawPolygon(
    _ context: CGContext,
    vertices: [FamilyV02PanelVertex],
    fill: NSColor,
    stroke: NSColor,
    lineWidth: CGFloat = 1.3
) {
    guard let first = vertices.first else {
        return
    }
    context.beginPath()
    context.move(to: CGPoint(x: first.x, y: first.y))
    for vertex in vertices.dropFirst() {
        context.addLine(to: CGPoint(x: vertex.x, y: vertex.y))
    }
    context.closePath()
    context.setFillColor(fill.cgColor)
    context.fillPath()
    context.beginPath()
    context.move(to: CGPoint(x: first.x, y: first.y))
    for vertex in vertices.dropFirst() {
        context.addLine(to: CGPoint(x: vertex.x, y: vertex.y))
    }
    context.closePath()
    context.setStrokeColor(stroke.cgColor)
    context.setLineWidth(lineWidth)
    context.strokePath()
}

private func familyV02PanelDrawLabel(
    _ text: String,
    point: CGPoint,
    size: CGFloat,
    color: NSColor,
    context: CGContext
) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(
        cgContext: context,
        flipped: false
    )
    text.draw(
        at: point,
        withAttributes: [
            .font: NSFont.monospacedSystemFont(
                ofSize: size,
                weight: .bold
            ),
            .foregroundColor: color,
        ]
    )
    NSGraphicsContext.restoreGraphicsState()
}

private func familyV02PanelAnalyticImage(
    descriptor: [String: Any],
    materials: [String: [Double]],
    grayscale: Bool
) throws -> CGImage {
    let context = try familyV02PanelContext(
        width: familyV02PanelSourceWidth,
        height: familyV02PanelSourceHeight
    )
    let background = grayscale
        ? NSColor(calibratedWhite: 0.91, alpha: 1)
        : NSColor(
            calibratedRed: 0.91,
            green: 0.91,
            blue: 0.88,
            alpha: 1
        )
    context.setFillColor(background.cgColor)
    context.fill(
        CGRect(
            x: 0,
            y: 0,
            width: familyV02PanelSourceWidth,
            height: familyV02PanelSourceHeight
        )
    )

    let footprint = [
        familyV02PanelProject([-28, 0, -28]),
        familyV02PanelProject([28, 0, -28]),
        familyV02PanelProject([28, 0, 28]),
        familyV02PanelProject([-28, 0, 28]),
    ]
    let shadow = footprint.map {
        FamilyV02PanelVertex(
            x: $0.x + 18,
            y: $0.y + 9,
            depth: $0.depth
        )
    }
    familyV02PanelDrawPolygon(
        context,
        vertices: shadow,
        fill: NSColor(calibratedWhite: 0.04, alpha: 0.44),
        stroke: NSColor(calibratedWhite: 0.04, alpha: 0.60)
    )
    familyV02PanelDrawPolygon(
        context,
        vertices: footprint,
        fill: grayscale
            ? NSColor(calibratedWhite: 0.62, alpha: 1)
            : NSColor(
                calibratedRed: 0.66,
                green: 0.65,
                blue: 0.58,
                alpha: 1
            ),
        stroke: NSColor(calibratedWhite: 0.78, alpha: 1)
    )

    guard
        let building = descriptor["building"] as? [String: Any],
        let foundationDimensions =
            building["foundationDimensions"] as? [Double],
        let foundationPosition =
            building["foundationPositionWorld"] as? [Double],
        let foundationMaterial =
            building["foundationMaterialID"] as? String,
        let blocks = building["massBlocks"] as? [[String: Any]],
        let props = descriptor["props"] as? [[String: Any]],
        let direction = descriptor["viewDirection"] as? String,
        let registration =
            descriptor["registration"] as? [String: Any],
        let edge = registration["frontageEdgeSource"] as? [[Int]],
        let socket = registration["frontageSocketSource"] as? [Int]
    else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "descriptor geometry or registration malformed"
        )
    }
    var components: [[String: Any]] = [
        [
            "dimensions": foundationDimensions,
            "positionWorld": foundationPosition,
            "materialID": foundationMaterial,
        ],
    ]
    components += blocks
    components += props
    var faces: [FamilyV02PanelFace] = []
    for component in components {
        guard
            let dimensions = component["dimensions"] as? [Double],
            let position = component["positionWorld"] as? [Double],
            let materialID = component["materialID"] as? String
        else {
            throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
                "component malformed"
            )
        }
        faces += familyV02PanelFaces(
            dimensions: dimensions,
            position: position,
            materialID: materialID
        )
    }
    for face in faces.sorted(by: { $0.depth < $1.depth }) {
        guard let base = materials[face.materialID] else {
            throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
                "unknown material \(face.materialID)"
            )
        }
        let factor: Double
        switch face.orientation {
        case "+y":
            factor = 1.06
        case "+x":
            factor = 0.90
        default:
            factor = 0.76
        }
        familyV02PanelDrawPolygon(
            context,
            vertices: face.vertices,
            fill: familyV02PanelColor(
                base,
                factor: factor,
                grayscale: grayscale
            ),
            stroke: grayscale
                ? NSColor(calibratedWhite: 0.17, alpha: 0.72)
                : NSColor(
                    calibratedRed: 0.08,
                    green: 0.11,
                    blue: 0.14,
                    alpha: 0.76
                )
        )
    }

    context.beginPath()
    context.move(to: CGPoint(x: edge[0][0], y: edge[0][1]))
    context.addLine(to: CGPoint(x: edge[1][0], y: edge[1][1]))
    context.setStrokeColor(
        (grayscale ? NSColor.white : NSColor.systemCyan).cgColor
    )
    context.setLineWidth(8)
    context.strokePath()
    context.setFillColor(
        (grayscale ? NSColor.black : NSColor.systemOrange).cgColor
    )
    context.fillEllipse(
        in: CGRect(
            x: socket[0] - 12,
            y: socket[1] - 12,
            width: 24,
            height: 24
        )
    )
    familyV02PanelDrawLabel(
        "ANALYTIC \(direction.uppercased()) — PRE-PIXEL / NOT SOURCE AUTHORITY",
        point: CGPoint(x: 34, y: 966),
        size: 23,
        color: grayscale ? .black : .white,
        context: context
    )
    guard let image = context.makeImage() else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "could not create analytic image"
        )
    }
    return image
}

private func familyV02PanelGrayscale(_ image: CGImage) throws -> CGImage {
    let context = try familyV02PanelContext(
        width: image.width,
        height: image.height
    )
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    guard let data = context.data else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "missing grayscale buffer"
        )
    }
    let bytes = data.bindMemory(
        to: UInt8.self,
        capacity: image.width * image.height * 4
    )
    for offset in stride(
        from: 0,
        to: image.width * image.height * 4,
        by: 4
    ) {
        let red = 0.2126 * Double(bytes[offset])
        let green = 0.7152 * Double(bytes[offset + 1])
        let blue = 0.0722 * Double(bytes[offset + 2])
        let rounded = Int((red + green + blue).rounded())
        let luma = UInt8(min(255, rounded))
        bytes[offset] = luma
        bytes[offset + 1] = luma
        bytes[offset + 2] = luma
    }
    guard let result = context.makeImage() else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "could not create grayscale image"
        )
    }
    return result
}

private func familyV02PanelNeutralizeExactChroma(
    _ image: CGImage
) throws -> CGImage {
    let context = try familyV02PanelContext(
        width: image.width,
        height: image.height
    )
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    guard let data = context.data else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "missing neutral buffer"
        )
    }
    let bytes = data.bindMemory(
        to: UInt8.self,
        capacity: image.width * image.height * 4
    )
    for offset in stride(
        from: 0,
        to: image.width * image.height * 4,
        by: 4
    ) where bytes[offset] == 255
        && bytes[offset + 1] == 0
        && bytes[offset + 2] == 255
    {
        bytes[offset] = 232
        bytes[offset + 1] = 232
        bytes[offset + 2] = 226
        bytes[offset + 3] = 255
    }
    guard let result = context.makeImage() else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "could not create neutral image"
        )
    }
    return result
}

private func familyV02PanelGrid(
    images: [CGImage],
    labels: [String],
    columns: Int,
    cell: CGSize,
    title: String
) throws -> CGImage {
    guard images.count == labels.count else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "grid image and label count mismatch"
        )
    }
    let rows = Int(ceil(Double(images.count) / Double(columns)))
    let header = 62
    let labelHeight = 38
    let width = Int(cell.width) * columns
    let height = header + rows * (Int(cell.height) + labelHeight)
    let context = try familyV02PanelContext(width: width, height: height)
    context.setFillColor(NSColor(calibratedWhite: 0.07, alpha: 1).cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    for index in images.indices {
        let column = index % columns
        let row = rows - 1 - index / columns
        let x = column * Int(cell.width)
        let y = row * (Int(cell.height) + labelHeight)
        context.draw(
            images[index],
            in: CGRect(
                x: x,
                y: y,
                width: Int(cell.width),
                height: Int(cell.height)
            )
        )
        familyV02PanelDrawLabel(
            labels[index],
            point: CGPoint(x: x + 10, y: y + Int(cell.height) + 10),
            size: 14,
            color: .white,
            context: context
        )
    }
    familyV02PanelDrawLabel(
        title,
        point: CGPoint(x: 14, y: height - 42),
        size: 21,
        color: .white,
        context: context
    )
    guard let result = context.makeImage() else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "could not create grid"
        )
    }
    return result
}

private func familyV02PanelCrop(
    _ image: CGImage,
    rect: CGRect
) throws -> CGImage {
    guard let result = image.cropping(to: rect) else {
        throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
            "could not crop panel input"
        )
    }
    return result
}

@main
enum BuildIndustrialL2DirectionalFamilyV02PrepixelPanelsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath:
                try familyV02PanelArgument(
                    "--repository-root",
                    in: arguments
                )!
        ).standardizedFileURL
        let defaultOutput = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v02/prepixel/review"
        )
        let outputRoot = URL(
            fileURLWithPath:
                try familyV02PanelArgument(
                    "--output-root",
                    in: arguments,
                    required: false
                ) ?? defaultOutput.path
        ).standardizedFileURL
        guard
            outputRoot.path.contains("directional-family-v02"),
            !FileManager.default.fileExists(atPath: outputRoot.path)
        else {
            throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
                "output must be absent and directional-family-v02 scoped"
            )
        }

        let scenesRoot = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v02/scenes/industrial_l02/variant-0"
        )
        let eastDescriptorURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialsURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/materials/industrial-l02-east-calibration-v05.json"
        )
        let eastNeutralURL = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05/raw-calibration/diagnostics/east-primary/neutral-alpha-composite.png"
        )
        guard
            try familyV02PanelSHA256(eastDescriptorURL)
                == familyV02PanelEastDescriptorSHA256,
            try familyV02PanelSHA256(materialsURL)
                == familyV02PanelMaterialsSHA256,
            try familyV02PanelSHA256(eastNeutralURL)
                == familyV02PanelEastNeutralSHA256
        else {
            throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
                "immutable East panel input drift"
            )
        }

        var descriptors: [String: [String: Any]] = [:]
        for direction in ["north", "south", "west"] {
            let url = scenesRoot.appendingPathComponent(
                "\(direction)/scene.json"
            )
            guard
                try familyV02PanelSHA256(url)
                    == familyV02PanelDescriptorHashes[direction]
            else {
                throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
                    "\(direction) descriptor drift"
                )
            }
            descriptors[direction] = try familyV02PanelObject(url)
        }
        let materialLibrary = try familyV02PanelObject(materialsURL)
        guard
            let rows = materialLibrary["materials"] as? [[String: Any]]
        else {
            throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
                "material library malformed"
            )
        }
        var colors: [String: [Double]] = [:]
        for row in rows {
            guard
                let id = row["id"] as? String,
                let rgba = row["baseColorRGBA"] as? [Double]
            else {
                throw IndustrialL2DirectionalFamilyV02PanelError.invalid(
                    "material row malformed"
                )
            }
            colors[id] = rgba
        }

        let northColor = try familyV02PanelAnalyticImage(
            descriptor: descriptors["north"]!,
            materials: colors,
            grayscale: false
        )
        let northGray = try familyV02PanelAnalyticImage(
            descriptor: descriptors["north"]!,
            materials: colors,
            grayscale: true
        )
        let southColor = try familyV02PanelAnalyticImage(
            descriptor: descriptors["south"]!,
            materials: colors,
            grayscale: false
        )
        let southGray = try familyV02PanelAnalyticImage(
            descriptor: descriptors["south"]!,
            materials: colors,
            grayscale: true
        )
        let westColor = try familyV02PanelAnalyticImage(
            descriptor: descriptors["west"]!,
            materials: colors,
            grayscale: false
        )
        let westGray = try familyV02PanelAnalyticImage(
            descriptor: descriptors["west"]!,
            materials: colors,
            grayscale: true
        )
        let eastColor = try familyV02PanelLoadImage(eastNeutralURL)
        let eastGray = try familyV02PanelGrayscale(eastColor)

        try FileManager.default.createDirectory(
            at: outputRoot,
            withIntermediateDirectories: true
        )
        var outputHashes: [String: String] = [:]
        func write(_ image: CGImage, _ name: String) throws {
            let url = outputRoot.appendingPathComponent(name)
            try familyV02PanelWritePNG(image, to: url)
            outputHashes[name] = try familyV02PanelSHA256(url)
        }

        try write(
            familyV02PanelGrid(
                images: [
                    northColor, eastColor, southColor, westColor,
                    northGray, eastGray, southGray, westGray,
                ],
                labels: [
                    "NORTH ANALYTIC", "EAST GOVERNED V05",
                    "SOUTH ANALYTIC", "WEST ANALYTIC",
                    "NORTH GRAYSCALE", "EAST V05 GRAYSCALE",
                    "SOUTH GRAYSCALE", "WEST GRAYSCALE",
                ],
                columns: 4,
                cell: CGSize(width: 384, height: 256),
                title:
                    "INDUSTRIAL L2 DIRECTION TURNTABLE — PRE-PIXEL / NOT SOURCE AUTHORITY / NOT STAGED APP"
            ),
            "INDUSTRIAL-L02-DIRECTION-TURNTABLE-PREPIXEL.png"
        )
        try write(
            familyV02PanelGrid(
                images: [northColor, westColor, northGray, westGray],
                labels: [
                    "NORTH FAR-EDGE LOADING THROAT",
                    "WEST FAR-EDGE LOADING THROAT",
                    "NORTH GRAYSCALE",
                    "WEST GRAYSCALE",
                ],
                columns: 2,
                cell: CGSize(width: 640, height: 426),
                title:
                    "NORTH / WEST FAR-EDGE FRONTAGE — ANALYTIC PRE-PIXEL"
            ),
            "INDUSTRIAL-L02-FAR-EDGE-FRONTAGE-NORTH-WEST-PREPIXEL.png"
        )

        let footprintRect = CGRect(x: 512, y: 384, width: 512, height: 512)
        var actualScaleInputs: [CGImage] = []
        var actualScaleLabels: [String] = []
        let newByDirection = [
            "north": northColor,
            "east": eastColor,
            "south": southColor,
            "west": westColor,
        ]
        for direction in ["north", "east", "south", "west"] {
            let l1URL = repositoryRoot.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/raw/industrial_l01/variant-0/\(direction)/source-v05.png"
            )
            let l1 = try familyV02PanelNeutralizeExactChroma(
                familyV02PanelLoadImage(l1URL)
            )
            actualScaleInputs.append(
                try familyV02PanelCrop(l1, rect: footprintRect)
            )
            actualScaleLabels.append("L1 \(direction.uppercased())")
            actualScaleInputs.append(
                try familyV02PanelCrop(
                    newByDirection[direction]!,
                    rect: footprintRect
                )
            )
            actualScaleLabels.append(
                direction == "east"
                ? "L2 EAST GOVERNED"
                : "L2 \(direction.uppercased()) ANALYTIC"
            )
        }
        try write(
            familyV02PanelGrid(
                images: actualScaleInputs,
                labels: actualScaleLabels,
                columns: 4,
                cell: CGSize(width: 216, height: 216),
                title:
                    "INDUSTRIAL L1 VS L2 FOOTPRINT — PRE-PIXEL COLOR COMPARISON"
            ),
            "INDUSTRIAL-L01-VS-L02-FOOTPRINT-PREPIXEL-COLOR.png"
        )
        try write(
            familyV02PanelGrid(
                images: try actualScaleInputs.map(
                    familyV02PanelGrayscale
                ),
                labels: actualScaleLabels,
                columns: 4,
                cell: CGSize(width: 216, height: 216),
                title:
                    "INDUSTRIAL L1 VS L2 FOOTPRINT — PRE-PIXEL GRAYSCALE COMPARISON"
            ),
            "INDUSTRIAL-L01-VS-L02-FOOTPRINT-PREPIXEL-GRAYSCALE.png"
        )

        let inventory: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type":
                "industrial-l02-directional-family-v02-prepixel-panel-inventory",
            "panelAuthority":
                "analytic prepixel evidence only; East governed v05 reference is labeled; not source authority or staged app proof",
            "descriptorSHA256": familyV02PanelDescriptorHashes,
            "eastDescriptorSHA256":
                familyV02PanelEastDescriptorSHA256,
            "materialLibrarySHA256":
                familyV02PanelMaterialsSHA256,
            "eastNeutralReferenceSHA256":
                familyV02PanelEastNeutralSHA256,
            "panels": outputHashes,
            "panelCount": outputHashes.count,
            "sourceAuthority": false,
            "productionSelected": false,
        ]
        try familyV02PanelWriteJSON(
            inventory,
            to: outputRoot.appendingPathComponent("PANEL-INVENTORY.json")
        )
        print("PASS panels=\(outputHashes.count)")
    }
}
