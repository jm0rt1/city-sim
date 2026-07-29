import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL2EastV05PanelError: Error {
    case invalid(String)
}

private struct V05PanelImage {
    let image: CGImage
    let width: Int
    let height: Int
}

private struct V05PanelVertex {
    let x: Double
    let y: Double
    let depth: Double
}

private struct V05PanelFace {
    let id: String
    let materialID: String
    let orientation: String
    let vertices: [V05PanelVertex]

    var depth: Double {
        vertices.map(\.depth).reduce(0, +) / Double(vertices.count)
    }
}

private let v05PanelDescriptorSHA256 =
    "482bea0169e9229df437b05ca6f0299046d49bb92e2e9d9ef4f3865df9be5fa0"
private let v05PanelMaterialsSHA256 =
    "6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb"
private let v05PanelAcceptedL1SHA256 =
    "f20d78d6b4b43c7111250f231351166397e3444e3f7a7243f282dacd94592e4f"
private let v05PanelRetainedV04NeutralSHA256 =
    "0b9983c5e2604185dea6a15c59913f3288cacb53a6b0b49bb3d1810c2dd1237e"
private let v05PanelSourceSize = CGSize(width: 1536, height: 1024)
private let v05PanelPixelsPerWorld = 1024.0 / (2.0 * 79.1959533691406)

private func v05PanelArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2EastV05PanelError.invalid("missing \(name)")
    }
    return arguments[index + 1]
}

private func v05PanelSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func v05PanelSHA256(_ url: URL) throws -> String {
    v05PanelSHA256(try Data(contentsOf: url))
}

private func v05PanelObject(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL2EastV05PanelError.invalid(
            "could not decode \(url.path)"
        )
    }
    return object
}

private func v05PanelLoadImage(_ url: URL) throws -> V05PanelImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw IndustrialL2EastV05PanelError.invalid(
            "could not load \(url.path)"
        )
    }
    return V05PanelImage(
        image: image,
        width: image.width,
        height: image.height
    )
}

private func v05PanelWritePNG(
    _ image: CGImage,
    to url: URL
) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2EastV05PanelError.invalid(
            "panel output must be absent: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw IndustrialL2EastV05PanelError.invalid(
            "could not create PNG destination"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL2EastV05PanelError.invalid(
            "could not finalize \(url.path)"
        )
    }
}

private func v05PanelContext(
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
        throw IndustrialL2EastV05PanelError.invalid(
            "could not create context"
        )
    }
    context.interpolationQuality = .high
    return context
}

private func v05PanelProject(_ point: [Double]) -> V05PanelVertex {
    let rootTwo = sqrt(2.0)
    let cameraX = (point[0] - point[2]) / rootTwo
    let cameraY =
        point[1] * cos(.pi / 6.0)
        - (point[0] + point[2]) / rootTwo * sin(.pi / 6.0)
    let depth =
        (point[0] + point[2]) / rootTwo * cos(.pi / 6.0)
        + point[1] * sin(.pi / 6.0)
    return V05PanelVertex(
        x: 768.0 + cameraX * v05PanelPixelsPerWorld,
        y: 256.0 + cameraY * v05PanelPixelsPerWorld,
        depth: depth
    )
}

private func v05PanelFaces(
    id: String,
    dimensions: [Double],
    position: [Double],
    materialID: String
) -> [V05PanelFace] {
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
        V05PanelFace(
            id: id,
            materialID: materialID,
            orientation: $0.0,
            vertices: $0.1.map(v05PanelProject)
        )
    }
}

private func v05PanelColor(
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

private func v05PanelDrawPolygon(
    _ context: CGContext,
    vertices: [V05PanelVertex],
    fill: NSColor,
    stroke: NSColor
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
    context.setLineWidth(1.3)
    context.strokePath()
}

private func v05PanelSourceMockup(
    descriptor: [String: Any],
    materials: [String: [Double]],
    grayscale: Bool
) throws -> CGImage {
    let width = Int(v05PanelSourceSize.width)
    let height = Int(v05PanelSourceSize.height)
    let context = try v05PanelContext(width: width, height: height)
    let background = grayscale
        ? NSColor(calibratedWhite: 0.89, alpha: 1)
        : NSColor(calibratedRed: 0.90, green: 0.90, blue: 0.87, alpha: 1)
    context.setFillColor(background.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let footprint = [
        v05PanelProject([-28, 0, -28]),
        v05PanelProject([28, 0, -28]),
        v05PanelProject([28, 0, 28]),
        v05PanelProject([-28, 0, 28]),
    ]
    let shadowVertices = footprint.map {
        V05PanelVertex(x: $0.x + 18, y: $0.y + 9, depth: $0.depth)
    }
    v05PanelDrawPolygon(
        context,
        vertices: shadowVertices,
        fill: NSColor(calibratedWhite: 0.04, alpha: 0.50),
        stroke: NSColor(calibratedWhite: 0.04, alpha: 0.65)
    )
    v05PanelDrawPolygon(
        context,
        vertices: footprint,
        fill: grayscale
            ? NSColor(calibratedWhite: 0.58, alpha: 1)
            : NSColor(calibratedRed: 0.46, green: 0.47, blue: 0.43, alpha: 1),
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
        let props = descriptor["props"] as? [[String: Any]]
    else {
        throw IndustrialL2EastV05PanelError.invalid(
            "descriptor geometry malformed"
        )
    }
    var components: [[String: Any]] = [
        [
            "id": "foundation",
            "dimensions": foundationDimensions,
            "positionWorld": foundationPosition,
            "materialID": foundationMaterial,
        ],
    ]
    components += blocks
    components += props
    var faces: [V05PanelFace] = []
    for component in components {
        guard
            let id = component["id"] as? String,
            let dimensions = component["dimensions"] as? [Double],
            let position = component["positionWorld"] as? [Double],
            let materialID = component["materialID"] as? String
        else {
            throw IndustrialL2EastV05PanelError.invalid(
                "component malformed"
            )
        }
        faces += v05PanelFaces(
            id: id,
            dimensions: dimensions,
            position: position,
            materialID: materialID
        )
    }
    for face in faces.sorted(by: { $0.depth < $1.depth }) {
        guard let base = materials[face.materialID] else {
            throw IndustrialL2EastV05PanelError.invalid(
                "unknown material \(face.materialID)"
            )
        }
        let factor: Double
        switch face.orientation {
        case "+y":
            factor = 1.08
        case "+x":
            factor = 0.88
        default:
            factor = 0.72
        }
        v05PanelDrawPolygon(
            context,
            vertices: face.vertices,
            fill: v05PanelColor(base, factor: factor, grayscale: grayscale),
            stroke: grayscale
                ? NSColor(calibratedWhite: 0.18, alpha: 0.78)
                : NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.16, alpha: 0.78)
        )
    }

    let title =
        "NON-AUTHORITY PRE-PIXEL MOCKUP — INDUSTRIAL L2 EAST V05"
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 25, weight: .bold),
        .foregroundColor: NSColor.white,
        .backgroundColor: NSColor(calibratedWhite: 0.05, alpha: 0.85),
    ]
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(
        cgContext: context,
        flipped: false
    )
    title.draw(
        at: CGPoint(x: 40, y: 968),
        withAttributes: attributes
    )
    NSGraphicsContext.restoreGraphicsState()
    guard let image = context.makeImage() else {
        throw IndustrialL2EastV05PanelError.invalid(
            "could not create mockup image"
        )
    }
    return image
}

private func v05PanelGrayscale(_ image: CGImage) throws -> CGImage {
    let context = try v05PanelContext(
        width: image.width,
        height: image.height
    )
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    guard let input = context.data else {
        throw IndustrialL2EastV05PanelError.invalid("missing pixel data")
    }
    let bytes = input.bindMemory(
        to: UInt8.self,
        capacity: image.width * image.height * 4
    )
    for offset in stride(
        from: 0,
        to: image.width * image.height * 4,
        by: 4
    ) {
        let red = Double(bytes[offset])
        let green = Double(bytes[offset + 1])
        let blue = Double(bytes[offset + 2])
        let weighted = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        let luma = UInt8(min(255, Int(weighted.rounded())))
        bytes[offset] = luma
        bytes[offset + 1] = luma
        bytes[offset + 2] = luma
    }
    guard let output = context.makeImage() else {
        throw IndustrialL2EastV05PanelError.invalid(
            "could not create grayscale"
        )
    }
    return output
}

private func v05PanelNeutralizeExactChroma(
    _ image: CGImage
) throws -> CGImage {
    let context = try v05PanelContext(
        width: image.width,
        height: image.height
    )
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    guard let input = context.data else {
        throw IndustrialL2EastV05PanelError.invalid("missing pixel data")
    }
    let bytes = input.bindMemory(
        to: UInt8.self,
        capacity: image.width * image.height * 4
    )
    for offset in stride(
        from: 0,
        to: image.width * image.height * 4,
        by: 4
    ) {
        if bytes[offset] == 255
            && bytes[offset + 1] == 0
            && bytes[offset + 2] == 255
        {
            bytes[offset] = 230
            bytes[offset + 1] = 230
            bytes[offset + 2] = 222
            bytes[offset + 3] = 255
        }
    }
    guard let output = context.makeImage() else {
        throw IndustrialL2EastV05PanelError.invalid(
            "could not create neutral chroma review"
        )
    }
    return output
}

private func v05PanelComparison(
    images: [CGImage],
    labels: [String],
    sourceRects: [CGRect],
    destinationSize: CGSize,
    headerHeight: Int
) throws -> CGImage {
    let cellWidth = Int(destinationSize.width)
    let cellHeight = Int(destinationSize.height)
    let context = try v05PanelContext(
        width: cellWidth * images.count,
        height: cellHeight + headerHeight
    )
    context.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 1).cgColor)
    context.fill(
        CGRect(
            x: 0,
            y: 0,
            width: cellWidth * images.count,
            height: cellHeight + headerHeight
        )
    )
    for index in images.indices {
        guard let cropped = images[index].cropping(to: sourceRects[index]) else {
            throw IndustrialL2EastV05PanelError.invalid("crop failed")
        }
        context.draw(
            cropped,
            in: CGRect(
                x: index * cellWidth,
                y: 0,
                width: cellWidth,
                height: cellHeight
            )
        )
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(
        cgContext: context,
        flipped: false
    )
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .bold),
        .foregroundColor: NSColor.white,
    ]
    for index in labels.indices {
        labels[index].draw(
            at: CGPoint(
                x: index * cellWidth + 12,
                y: cellHeight + 14
            ),
            withAttributes: attributes
        )
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let output = context.makeImage() else {
        throw IndustrialL2EastV05PanelError.invalid(
            "could not create comparison"
        )
    }
    return output
}

private func v05PanelMaterialSheet(
    materials: [[String: Any]]
) throws -> CGImage {
    let width = 960
    let rowHeight = 54
    let height = 58 + rowHeight * materials.count
    let context = try v05PanelContext(width: width, height: height)
    context.setFillColor(NSColor(calibratedWhite: 0.10, alpha: 1).cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(
        cgContext: context,
        flipped: false
    )
    for (index, material) in materials.enumerated() {
        guard
            let id = material["id"] as? String,
            let role = material["valueRole"] as? String,
            let color = material["baseColorRGBA"] as? [Double],
            let target = material["targetPostLightStep32Bin"] as? Int
        else {
            throw IndustrialL2EastV05PanelError.invalid(
                "material row malformed"
            )
        }
        let y = height - 58 - rowHeight * (index + 1)
        context.setFillColor(
            NSColor(
                calibratedRed: color[0],
                green: color[1],
                blue: color[2],
                alpha: 1
            ).cgColor
        )
        context.fill(CGRect(x: 22, y: y + 8, width: 180, height: 38))
        let text = "\(id)  •  \(role)  •  target step \(target)"
        text.draw(
            at: CGPoint(x: 220, y: y + 18),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(
                    ofSize: 15,
                    weight: .medium
                ),
                .foregroundColor: NSColor.white,
            ]
        )
    }
    "NON-AUTHORITY PRE-PIXEL MATERIAL / VALUE LADDER".draw(
        at: CGPoint(x: 22, y: height - 38),
        withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
    )
    NSGraphicsContext.restoreGraphicsState()
    guard let output = context.makeImage() else {
        throw IndustrialL2EastV05PanelError.invalid(
            "could not create material sheet"
        )
    }
    return output
}

@main
enum BuildIndustrialL2EastV05PrepixelPanelsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath:
                try v05PanelArgument("--repository-root", in: arguments)
        ).standardizedFileURL
        let descriptorURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialsURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/materials/industrial-l02-east-calibration-v05.json"
        )
        let acceptedL1URL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/raw/industrial_l01/variant-0/east/source-v05.png"
        )
        let retainedV04URL = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/raw-probe/diagnostics/east-primary/neutral-alpha-composite.png"
        )
        guard
            try v05PanelSHA256(descriptorURL)
                == v05PanelDescriptorSHA256,
            try v05PanelSHA256(materialsURL)
                == v05PanelMaterialsSHA256,
            try v05PanelSHA256(acceptedL1URL)
                == v05PanelAcceptedL1SHA256,
            try v05PanelSHA256(retainedV04URL)
                == v05PanelRetainedV04NeutralSHA256
        else {
            throw IndustrialL2EastV05PanelError.invalid(
                "frozen panel input drift"
            )
        }
        let descriptor = try v05PanelObject(descriptorURL)
        let materialLibrary = try v05PanelObject(materialsURL)
        guard
            let materialRows =
                materialLibrary["materials"] as? [[String: Any]]
        else {
            throw IndustrialL2EastV05PanelError.invalid(
                "material library malformed"
            )
        }
        var colors: [String: [Double]] = [:]
        for material in materialRows {
            guard
                let id = material["id"] as? String,
                let rgba = material["baseColorRGBA"] as? [Double]
            else {
                throw IndustrialL2EastV05PanelError.invalid(
                    "material malformed"
                )
            }
            colors[id] = rgba
        }
        let acceptedL1Raw = try v05PanelLoadImage(acceptedL1URL).image
        let acceptedL1 = try v05PanelNeutralizeExactChroma(acceptedL1Raw)
        let retainedV04 = try v05PanelLoadImage(retainedV04URL).image
        let newColor = try v05PanelSourceMockup(
            descriptor: descriptor,
            materials: colors,
            grayscale: false
        )
        let newGrayscale = try v05PanelSourceMockup(
            descriptor: descriptor,
            materials: colors,
            grayscale: true
        )
        let acceptedL1Grayscale = try v05PanelGrayscale(acceptedL1)
        let retainedV04Grayscale = try v05PanelGrayscale(retainedV04)
        let outputRoot = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05/prepixel/review"
        )
        try v05PanelWritePNG(
            newColor,
            to: outputRoot.appendingPathComponent(
                "PREPIXEL-SOURCE-SCALE-COLOR-NONAUTHORITY.png"
            )
        )
        try v05PanelWritePNG(
            newGrayscale,
            to: outputRoot.appendingPathComponent(
                "PREPIXEL-SOURCE-SCALE-GRAYSCALE-NONAUTHORITY.png"
            )
        )
        let fullRects = [
            CGRect(x: 0, y: 0, width: 1536, height: 1024),
            CGRect(x: 0, y: 0, width: 1536, height: 1024),
            CGRect(x: 0, y: 0, width: 1536, height: 1024),
        ]
        let labels = [
            "ACCEPTED INDUSTRIAL L1 EAST",
            "RETAINED V04 EAST",
            "NEW V05 PREPIXEL MOCKUP",
        ]
        try v05PanelWritePNG(
            v05PanelComparison(
                images: [acceptedL1, retainedV04, newColor],
                labels: labels,
                sourceRects: fullRects,
                destinationSize: CGSize(width: 432, height: 288),
                headerHeight: 52
            ),
            to: outputRoot.appendingPathComponent(
                "PREPIXEL-NATIVE-2X-COLOR-COMPARISON.png"
            )
        )
        try v05PanelWritePNG(
            v05PanelComparison(
                images: [
                    acceptedL1Grayscale,
                    retainedV04Grayscale,
                    newGrayscale,
                ],
                labels: labels,
                sourceRects: fullRects,
                destinationSize: CGSize(width: 432, height: 288),
                headerHeight: 52
            ),
            to: outputRoot.appendingPathComponent(
                "PREPIXEL-NATIVE-2X-GRAYSCALE-COMPARISON.png"
            )
        )
        let footprintRects = [
            CGRect(x: 512, y: 416, width: 512, height: 512),
            CGRect(x: 512, y: 416, width: 512, height: 512),
            CGRect(x: 512, y: 416, width: 512, height: 512),
        ]
        try v05PanelWritePNG(
            v05PanelComparison(
                images: [acceptedL1, retainedV04, newColor],
                labels: ["L1", "V04", "V05 ANALYTIC"],
                sourceRects: footprintRects,
                destinationSize: CGSize(width: 144, height: 144),
                headerHeight: 52
            ),
            to: outputRoot.appendingPathComponent(
                "PREPIXEL-FOOTPRINT-ACTUAL-SCALE-COLOR-COMPARISON.png"
            )
        )
        try v05PanelWritePNG(
            v05PanelComparison(
                images: [
                    acceptedL1Grayscale,
                    retainedV04Grayscale,
                    newGrayscale,
                ],
                labels: ["L1", "V04", "V05 ANALYTIC"],
                sourceRects: footprintRects,
                destinationSize: CGSize(width: 144, height: 144),
                headerHeight: 52
            ),
            to: outputRoot.appendingPathComponent(
                "PREPIXEL-FOOTPRINT-ACTUAL-SCALE-GRAYSCALE-COMPARISON.png"
            )
        )
        try v05PanelWritePNG(
            v05PanelMaterialSheet(materials: materialRows),
            to: outputRoot.appendingPathComponent(
                "PREPIXEL-MATERIAL-VALUE-LADDER.png"
            )
        )
        print("PASS generated seven non-authority prepixel panels")
    }
}
