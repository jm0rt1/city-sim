import AppKit
import CoreGraphics
import CoreText
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum RasterSurvivalReviewError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l2-east-raster-survival-review --repository-root <path> --raw <path> --provenance <path> --output-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct RGBAImage {
    let width: Int
    let height: Int
    var bytes: [UInt8]
}

private struct PixelBounds {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int
    var count: Int

    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }

    var dictionary: [String: Any] {
        [
            "minX": minX,
            "minY": minY,
            "maxX": maxX,
            "maxY": maxY,
            "width": width,
            "height": height,
            "area": count,
        ]
    }
}

private let expectedRawSHA256 =
    "77d47f3feef50c584dfd60177e41ab6793247a6772c536270806a0c3196db5b8"
private let expectedSceneSHA256 =
    "2af1e6488ea5ff8e799bf44482d4061b1efa1a190a360a34a4bdef0dc6d849c2"
private let expectedMaterialSHA256 =
    "4ca54f2c10c9cc89d9432d2ac921e8cfb7ac88f14141e5446e9657b6533132d9"
private let expectedL1RawSHA256 =
    "f20d78d6b4b43c7111250f231351166397e3444e3f7a7243f282dacd94592e4f"

private func reviewArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw RasterSurvivalReviewError.arguments
    }
    return arguments[index + 1]
}

private func reviewSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func reviewSHA256(_ url: URL) throws -> String {
    reviewSHA256(try Data(contentsOf: url))
}

private func relative(
    _ url: URL,
    root: URL
) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

private func decode(_ url: URL) throws -> RGBAImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw RasterSurvivalReviewError.invalid(
            "could not decode \(url.path)"
        )
    }
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    try bytes.withUnsafeMutableBytes { storage in
        guard let context = CGContext(
            data: storage.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw RasterSurvivalReviewError.invalid(
                "could not allocate RGBA decoder"
            )
        }
        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
    }
    return RGBAImage(width: width, height: height, bytes: bytes)
}

private func cgImage(_ image: RGBAImage) throws -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    var mutable = image.bytes
    return try mutable.withUnsafeMutableBytes { storage in
        guard
            let context = CGContext(
                data: storage.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: colorSpace,
                bitmapInfo:
                    CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            let output = context.makeImage()
        else {
            throw RasterSurvivalReviewError.invalid(
                "could not construct RGBA image"
            )
        }
        return output
    }
}

private func writePNG(
    _ image: CGImage,
    to url: URL
) throws {
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
        throw RasterSurvivalReviewError.invalid(
            "could not create PNG destination"
        )
    }
    CGImageDestinationAddImage(
        destination,
        image,
        [
            kCGImagePropertyPNGDictionary:
                [kCGImagePropertyPNGInterlaceType: 0],
        ] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
        throw RasterSurvivalReviewError.invalid(
            "could not finalize PNG"
        )
    }
}

private func writeJSON(
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

private func exactChroma(
    _ r: UInt8,
    _ g: UInt8,
    _ b: UInt8,
    _ a: UInt8
) -> Bool {
    r == 255 && g == 0 && b == 255 && a == 255
}

private func frozenShadowFamily(
    _ r: UInt8,
    _ g: UInt8,
    _ b: UInt8,
    _ a: UInt8
) -> Bool {
    a == 255
        && Int(g) <= 8
        && abs(Int(r) - Int(b)) <= 2
        && Int(r) >= 16
}

private func quantizedMagentaFamily(
    _ r: UInt8,
    _ g: UInt8,
    _ b: UInt8,
    _ a: UInt8
) -> Bool {
    a == 255
        && Int(g) <= 24
        && abs(Int(r) - Int(b)) <= 2
        && Int(r) >= 16
        && Int(r) - Int(g) >= 64
}

private func borderFloodMask(
    _ image: RGBAImage
) -> [Bool] {
    let pixelCount = image.width * image.height
    var visited = [Bool](repeating: false, count: pixelCount)
    var queue = [Int]()
    queue.reserveCapacity(pixelCount / 4)

    func eligible(_ pixel: Int) -> Bool {
        let offset = pixel * 4
        let r = image.bytes[offset]
        let g = image.bytes[offset + 1]
        let b = image.bytes[offset + 2]
        let a = image.bytes[offset + 3]
        return exactChroma(r, g, b, a)
            || frozenShadowFamily(r, g, b, a)
    }

    func seed(_ pixel: Int) {
        guard !visited[pixel], eligible(pixel) else { return }
        visited[pixel] = true
        queue.append(pixel)
    }

    for x in 0..<image.width {
        seed(x)
        seed((image.height - 1) * image.width + x)
    }
    for y in 0..<image.height {
        seed(y * image.width)
        seed(y * image.width + image.width - 1)
    }
    var cursor = 0
    while cursor < queue.count {
        let pixel = queue[cursor]
        cursor += 1
        let x = pixel % image.width
        let y = pixel / image.width
        if x > 0 { seed(pixel - 1) }
        if x + 1 < image.width { seed(pixel + 1) }
        if y > 0 { seed(pixel - image.width) }
        if y + 1 < image.height { seed(pixel + image.width) }
    }
    return visited
}

private func alphaExtract(
    _ source: RGBAImage
) -> (
    image: RGBAImage,
    floodCount: Int,
    exactChromaCount: Int,
    reconstructedShadowCount: Int
) {
    let flood = borderFloodMask(source)
    var output = source
    var exactCount = 0
    var shadowCount = 0
    for pixel in 0..<(source.width * source.height) where flood[pixel] {
        let offset = pixel * 4
        let r = source.bytes[offset]
        let g = source.bytes[offset + 1]
        let b = source.bytes[offset + 2]
        let a = source.bytes[offset + 3]
        if exactChroma(r, g, b, a) {
            output.bytes[offset] = 0
            output.bytes[offset + 1] = 0
            output.bytes[offset + 2] = 0
            output.bytes[offset + 3] = 0
            exactCount += 1
        } else {
            output.bytes[offset] = 0
            output.bytes[offset + 1] = 0
            output.bytes[offset + 2] = 0
            output.bytes[offset + 3] = 255 &- r
            shadowCount += 1
        }
    }
    return (
        output,
        flood.filter { $0 }.count,
        exactCount,
        shadowCount
    )
}

private func bounds(
    _ image: RGBAImage,
    where include: (UInt8, UInt8, UInt8, UInt8) -> Bool
) -> PixelBounds? {
    var result: PixelBounds?
    for y in 0..<image.height {
        for x in 0..<image.width {
            let offset = (y * image.width + x) * 4
            guard include(
                image.bytes[offset],
                image.bytes[offset + 1],
                image.bytes[offset + 2],
                image.bytes[offset + 3]
            ) else {
                continue
            }
            if result == nil {
                result = PixelBounds(
                    minX: x,
                    minY: y,
                    maxX: x,
                    maxY: y,
                    count: 1
                )
            } else {
                result!.minX = min(result!.minX, x)
                result!.minY = min(result!.minY, y)
                result!.maxX = max(result!.maxX, x)
                result!.maxY = max(result!.maxY, y)
                result!.count += 1
            }
        }
    }
    return result
}

private func quantile(
    _ values: [Int],
    _ fraction: Double
) -> Int {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let index = min(
        sorted.count - 1,
        Int(Double(sorted.count - 1) * fraction)
    )
    return sorted[index]
}

private func materialLumaMetrics(
    _ image: RGBAImage
) -> [String: Any] {
    var lumas = [Int]()
    var bins = [Int: Int]()
    var residualPlate = 0
    for pixel in 0..<(image.width * image.height) {
        let offset = pixel * 4
        let r = image.bytes[offset]
        let g = image.bytes[offset + 1]
        let b = image.bytes[offset + 2]
        let a = image.bytes[offset + 3]
        if quantizedMagentaFamily(r, g, b, a) {
            residualPlate += 1
            continue
        }
        guard a > 0 else { continue }
        let redLuma = 0.2126 * Double(r)
        let greenLuma = 0.7152 * Double(g)
        let blueLuma = 0.0722 * Double(b)
        let luma = Int(redLuma + greenLuma + blueLuma)
        lumas.append(luma)
        let bin = (luma / 16) * 16
        bins[bin, default: 0] += 1
    }
    return [
        "sampleCount": lumas.count,
        "p05": quantile(lumas, 0.05),
        "p25": quantile(lumas, 0.25),
        "p50": quantile(lumas, 0.50),
        "p75": quantile(lumas, 0.75),
        "p95": quantile(lumas, 0.95),
        "p95MinusP05": quantile(lumas, 0.95) - quantile(lumas, 0.05),
        "p75MinusP25": quantile(lumas, 0.75) - quantile(lumas, 0.25),
        "occupiedLumaBins":
            bins.keys.sorted().map {
                ["lowerBound": $0, "count": bins[$0]!]
            },
        "residualQuantizedMagentaPlatePixels": residualPlate,
    ]
}

private func alphaMetrics(
    _ image: RGBAImage
) -> [String: Any] {
    var minimum = 255
    var maximum = 0
    var nonOpaque = 0
    var transparent = 0
    var hiddenRGB = 0
    for pixel in 0..<(image.width * image.height) {
        let offset = pixel * 4
        let alpha = Int(image.bytes[offset + 3])
        minimum = min(minimum, alpha)
        maximum = max(maximum, alpha)
        if alpha != 255 { nonOpaque += 1 }
        if alpha == 0 {
            transparent += 1
            if
                image.bytes[offset] != 0
                    || image.bytes[offset + 1] != 0
                    || image.bytes[offset + 2] != 0
            {
                hiddenRGB += 1
            }
        }
    }
    return [
        "minimum": minimum,
        "maximum": maximum,
        "nonOpaquePixels": nonOpaque,
        "transparentPixels": transparent,
        "hiddenRGBPixels": hiddenRGB,
    ]
}

private func neutralComposite(
    _ image: RGBAImage,
    grayscale: Bool
) -> RGBAImage {
    var output = image
    for pixel in 0..<(image.width * image.height) {
        let offset = pixel * 4
        let alpha = Double(image.bytes[offset + 3]) / 255
        let background = [224.0, 226.0, 220.0]
        var channels = [Double](repeating: 0, count: 3)
        for channel in 0..<3 {
            channels[channel] =
                Double(image.bytes[offset + channel]) * alpha
                + background[channel] * (1 - alpha)
        }
        if grayscale {
            let luma =
                0.2126 * channels[0]
                + 0.7152 * channels[1]
                + 0.0722 * channels[2]
            channels = [luma, luma, luma]
        }
        output.bytes[offset] = UInt8(clamping: Int(channels[0].rounded()))
        output.bytes[offset + 1] = UInt8(clamping: Int(channels[1].rounded()))
        output.bytes[offset + 2] = UInt8(clamping: Int(channels[2].rounded()))
        output.bytes[offset + 3] = 255
    }
    return output
}

private func drawLabel(
    _ text: String,
    in context: CGContext,
    rect: CGRect,
    size: CGFloat = 22
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(
            ofSize: size,
            weight: .semibold
        ),
        .foregroundColor: NSColor(
            calibratedRed: 0.10,
            green: 0.12,
            blue: 0.14,
            alpha: 1
        ),
    ]
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: attributes)
    )
    context.textPosition = CGPoint(x: rect.minX, y: rect.minY)
    CTLineDraw(line, context)
}

private func panel(
    items: [(label: String, image: CGImage)],
    itemSize: CGSize,
    output: URL,
    title: String
) throws {
    let margin: CGFloat = 28
    let titleHeight: CGFloat = 52
    let labelHeight: CGFloat = 36
    let gap: CGFloat = 24
    let contentWidth =
        margin * 2
        + CGFloat(items.count) * itemSize.width
        + CGFloat(max(0, items.count - 1)) * gap
    let width = max(contentWidth, 920)
    let height = margin * 2 + titleHeight + labelHeight + itemSize.height
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: Int(width),
        height: Int(height),
        bitsPerComponent: 8,
        bytesPerRow: Int(width) * 4,
        space: colorSpace,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw RasterSurvivalReviewError.invalid(
            "could not allocate review panel"
        )
    }
    context.setFillColor(
        NSColor(
            calibratedRed: 0.88,
            green: 0.89,
            blue: 0.86,
            alpha: 1
        ).cgColor
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    drawLabel(
        title,
        in: context,
        rect: CGRect(
            x: margin,
            y: height - margin - 30,
            width: width - margin * 2,
            height: 30
        ),
        size: 24
    )
    let itemsWidth =
        CGFloat(items.count) * itemSize.width
        + CGFloat(max(0, items.count - 1)) * gap
    let itemsStart = (width - itemsWidth) / 2
    for (index, item) in items.enumerated() {
        let x = itemsStart + CGFloat(index) * (itemSize.width + gap)
        let y = margin
        context.interpolationQuality = .high
        context.draw(
            item.image,
            in: CGRect(
                x: x,
                y: y,
                width: itemSize.width,
                height: itemSize.height
            )
        )
        drawLabel(
            item.label,
            in: context,
            rect: CGRect(
                x: x,
                y: y + itemSize.height + 8,
                width: itemSize.width,
                height: labelHeight
            ),
            size: 17
        )
    }
    guard let image = context.makeImage() else {
        throw RasterSurvivalReviewError.invalid(
            "could not finalize review panel"
        )
    }
    try writePNG(image, to: output)
}

private func cropped(
    _ image: CGImage,
    bounds: PixelBounds,
    padding: Int
) throws -> CGImage {
    let x = max(0, bounds.minX - padding)
    let y = max(0, bounds.minY - padding)
    let maxX = min(image.width - 1, bounds.maxX + padding)
    let maxY = min(image.height - 1, bounds.maxY + padding)
    guard
        let crop = image.cropping(
            to: CGRect(
                x: x,
                y: y,
                width: maxX - x + 1,
                height: maxY - y + 1
            )
        )
    else {
        throw RasterSurvivalReviewError.invalid("could not crop review image")
    }
    return crop
}

@main
enum BuildIndustrialL2EastRasterSurvivalReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try reviewArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let rawURL = URL(
            fileURLWithPath: try reviewArgument(
                "--raw",
                in: arguments
            )
        ).standardizedFileURL
        let provenanceURL = URL(
            fileURLWithPath: try reviewArgument(
                "--provenance",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try reviewArgument(
                "--output-root",
                in: arguments
            )
        ).standardizedFileURL
        let l1URL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/raw/industrial_l01/variant-0/east/source-v05.png"
        )
        guard
            try reviewSHA256(rawURL) == expectedRawSHA256,
            try reviewSHA256(l1URL) == expectedL1RawSHA256
        else {
            throw RasterSurvivalReviewError.invalid(
                "proof or accepted L1 raw hash drift"
            )
        }
        guard
            let provenance = try JSONSerialization.jsonObject(
                with: Data(contentsOf: provenanceURL)
            ) as? [String: Any],
            provenance["sceneDescriptorSHA256"] as? String
                == expectedSceneSHA256,
            provenance["materialLibrarySHA256"] as? String
                == expectedMaterialSHA256,
            provenance["rawSourceSHA256"] as? String
                == expectedRawSHA256
        else {
            throw RasterSurvivalReviewError.invalid(
                "proof provenance binding failed"
            )
        }

        let proof = try decode(rawURL)
        let l1 = try decode(l1URL)
        guard
            proof.width == 1536,
            proof.height == 1024,
            l1.width == proof.width,
            l1.height == proof.height
        else {
            throw RasterSurvivalReviewError.invalid(
                "source dimensions drift"
            )
        }
        let extracted = alphaExtract(proof)
        let l1Extracted = alphaExtract(l1)
        let proofNeutralColor = neutralComposite(
            extracted.image,
            grayscale: false
        )
        let proofNeutralGray = neutralComposite(
            extracted.image,
            grayscale: true
        )
        let l1NeutralColor = neutralComposite(
            l1Extracted.image,
            grayscale: false
        )
        let l1NeutralGray = neutralComposite(
            l1Extracted.image,
            grayscale: true
        )

        let alphaURL = outputRoot.appendingPathComponent(
            "ALPHA-MASKED-SOURCE.png"
        )
        let neutralColorURL = outputRoot.appendingPathComponent(
            "SOURCE-SCALE-NEUTRAL-COLOR.png"
        )
        let neutralGrayURL = outputRoot.appendingPathComponent(
            "SOURCE-SCALE-NEUTRAL-GRAYSCALE.png"
        )
        try writePNG(try cgImage(extracted.image), to: alphaURL)
        try writePNG(try cgImage(proofNeutralColor), to: neutralColorURL)
        try writePNG(try cgImage(proofNeutralGray), to: neutralGrayURL)

        guard
            let buildingBounds = bounds(
                proof,
                where: { r, g, b, a in
                    a > 0
                        && !exactChroma(r, g, b, a)
                        && !quantizedMagentaFamily(r, g, b, a)
                }
            ),
            let maskedBounds = bounds(
                extracted.image,
                where: { _, _, _, a in a > 0 }
            ),
            let l1BuildingBounds = bounds(
                l1,
                where: { r, g, b, a in
                    a > 0
                        && !exactChroma(r, g, b, a)
                        && !quantizedMagentaFamily(r, g, b, a)
                }
            )
        else {
            throw RasterSurvivalReviewError.invalid(
                "could not resolve proof/L1 occupied bounds"
            )
        }
        let proofColorCG = try cgImage(proofNeutralColor)
        let proofGrayCG = try cgImage(proofNeutralGray)
        let l1ColorCG = try cgImage(l1NeutralColor)
        let l1GrayCG = try cgImage(l1NeutralGray)
        let proofCropColor = try cropped(
            proofColorCG,
            bounds: buildingBounds,
            padding: 28
        )
        let proofCropGray = try cropped(
            proofGrayCG,
            bounds: buildingBounds,
            padding: 28
        )
        let l1CropColor = try cropped(
            l1ColorCG,
            bounds: l1BuildingBounds,
            padding: 28
        )
        let l1CropGray = try cropped(
            l1GrayCG,
            bounds: l1BuildingBounds,
            padding: 28
        )

        let nativeWidth: CGFloat = 144
        let proofNativeHeight =
            nativeWidth * CGFloat(proofCropColor.height)
            / CGFloat(proofCropColor.width)
        let l1NativeHeight =
            nativeWidth * CGFloat(l1CropColor.height)
            / CGFloat(l1CropColor.width)
        let nativeHeight = max(proofNativeHeight, l1NativeHeight)
        try panel(
            items: [("Industrial L2 proof", proofCropColor)],
            itemSize: CGSize(width: nativeWidth, height: nativeHeight),
            output: outputRoot.appendingPathComponent(
                "NATIVE-2X-COLOR.png"
            ),
            title: "East proof — literal native-2x color"
        )
        try panel(
            items: [("Industrial L2 proof", proofCropGray)],
            itemSize: CGSize(width: nativeWidth, height: nativeHeight),
            output: outputRoot.appendingPathComponent(
                "NATIVE-2X-GRAYSCALE.png"
            ),
            title: "East proof — literal native-2x grayscale"
        )
        try panel(
            items: [
                ("L1 accepted", l1CropColor),
                ("L2 proof", proofCropColor),
            ],
            itemSize: CGSize(width: 320, height: 360),
            output: outputRoot.appendingPathComponent(
                "L1-VS-L2-SOURCE-COLOR.png"
            ),
            title: "Industrial L1 vs L2 proof — source-scale color"
        )
        try panel(
            items: [
                ("L1 accepted", l1CropGray),
                ("L2 proof", proofCropGray),
            ],
            itemSize: CGSize(width: 320, height: 360),
            output: outputRoot.appendingPathComponent(
                "L1-VS-L2-SOURCE-GRAYSCALE.png"
            ),
            title: "Industrial L1 vs L2 proof — source-scale grayscale"
        )
        try panel(
            items: [
                ("L1 accepted", l1CropColor),
                ("L2 proof", proofCropColor),
            ],
            itemSize: CGSize(width: 144, height: nativeHeight),
            output: outputRoot.appendingPathComponent(
                "L1-VS-L2-NATIVE-2X-COLOR.png"
            ),
            title: "Literal native-2x comparison"
        )
        try panel(
            items: [
                ("L1 accepted", l1CropGray),
                ("L2 proof", proofCropGray),
            ],
            itemSize: CGSize(width: 144, height: nativeHeight),
            output: outputRoot.appendingPathComponent(
                "L1-VS-L2-NATIVE-2X-GRAYSCALE.png"
            ),
            title: "Literal native-2x grayscale comparison"
        )
        try panel(
            items: [
                ("L2 footprint crop color", proofCropColor),
                ("L2 footprint crop grayscale", proofCropGray),
            ],
            itemSize: CGSize(width: 512, height: 512),
            output: outputRoot.appendingPathComponent(
                "FOOTPRINT-CROP-COLOR-GRAYSCALE.png"
            ),
            title: "Alpha-respecting neutral footprint review"
        )
        try panel(
            items: [("East frontage/detail survival", proofCropColor)],
            itemSize: CGSize(width: 768, height: 768),
            output: outputRoot.appendingPathComponent("ZOOM.png"),
            title: "Zoom is diagnostic only — native-2x remains binding"
        )

        let lumaMetrics = materialLumaMetrics(extracted.image)
        let rawAlphaMetrics = alphaMetrics(proof)
        let extractedAlphaMetrics = alphaMetrics(extracted.image)
        let residualPlatePixels =
            lumaMetrics["residualQuantizedMagentaPlatePixels"] as? Int
            ?? 0
        let sourceDiamondUtilization =
            Double(maskedBounds.width) / 512.0
        let technicalPass =
            sourceDiamondUtilization > 0.801
            && buildingBounds.minX >= 0
            && buildingBounds.maxX < proof.width
            && buildingBounds.minY >= 0
            && buildingBounds.maxY < proof.height
        let visualPresentationPass = residualPlatePixels == 0
        let disposition =
            technicalPass && visualPresentationPass
            ? "REVIEW-CANDIDATE-NOT-ACCEPTED"
            : "VISUAL-REJECTION"
        let metrics: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-raster-survival-proof",
            "authority": "single-process-non-source-authority",
            "rawFile": relative(rawURL, root: root),
            "rawSHA256": try reviewSHA256(rawURL),
            "provenanceFile": relative(provenanceURL, root: root),
            "provenanceSHA256": try reviewSHA256(provenanceURL),
            "acceptedIndustrialL1RawFile": relative(l1URL, root: root),
            "acceptedIndustrialL1RawSHA256": try reviewSHA256(l1URL),
            "frozenMask": [
                "classification":
                    "border-connected exact chroma or g<=8, abs(r-b)<=2, r>=16",
                "floodPixels": extracted.floodCount,
                "exactChromaPixelsMadeTransparent":
                    extracted.exactChromaCount,
                "shadowPixelsReconstructed":
                    extracted.reconstructedShadowCount,
                "residualQuantizedMagentaPlatePixels":
                    residualPlatePixels,
            ],
            "alpha": [
                "literalRaw": rawAlphaMetrics,
                "reviewExtraction": extractedAlphaMetrics,
                "exactChromaRGBA": [255, 0, 255, 255],
            ],
            "bounds": [
                "buildingExcludingQuantizedMagentaFamily":
                    buildingBounds.dictionary,
                "alphaMaskedOccupied": maskedBounds.dictionary,
                "acceptedIndustrialL1Building":
                    l1BuildingBounds.dictionary,
            ],
            "utilization": [
                "rejectedObserved": 0.801,
                "registeredDiamondExpected": 1.0,
                "alphaMaskedOccupiedWidthOver512":
                    sourceDiamondUtilization,
                "passedAboveRejected": sourceDiamondUtilization > 0.801,
            ],
            "registration": [
                "pivotSource": [768, 896],
                "eastSocketSource": [896, 832],
                "doorBaseSource": [[934, 813], [858, 851]],
                "shadowVectorSource": [2, 1],
                "renderedNodeBoundsComplete":
                    (provenance["renderedNodeBounds"]
                        as? [String: Any])?[
                            "completeBuildingVolumePassed"
                        ] as? Bool
                        ?? false,
            ],
            "componentSurvivalBudget": [
                "dockDoorWidthWorld": 7,
                "dockDoorWidthNative2xPixels": 10.1,
                "dockCanopyDepthWorld": 8,
                "dockCanopyDepthNative2xPixels": 11.5,
                "dockThroatDepthWorld": 4,
                "dockThroatDepthNative2xPixels": 5.8,
                "personnelDoorWidthWorld": 4,
                "personnelDoorWidthNative2xPixels": 5.8,
                "bollardDiameterWorld": 3,
                "bollardDiameterNative2xPixels": 4.3,
                "allIdentityBearingFeaturesAtLeastFourPixels": true,
            ],
            "observedLiteralVisualSurvival": [
                "majorFormsReadAsDistinctCapabilityHierarchy": false,
                "threeDocksUnmistakableWithoutZoom": false,
                "personnelRouteUnmistakableWithoutZoom": false,
                "materialHierarchySurvivesNative2x": false,
                "footprintFieldSubordinateToBuilding": false,
                "basis":
                    "independent live pixel review plus bound source/native-2x color and grayscale panels",
            ],
            "luma": lumaMetrics,
            "provenanceCorrectionRequired":
                provenance["rendererSourceCommit"] as? String
                    != "920af3b8730a556c564daa56d9a0c9a4d451cf18",
            "technicalChecksPassed": technicalPass,
            "neutralPresentationPassed": visualPresentationPass,
            "disposition": disposition,
            "productionSelected": false,
        ]
        try writeJSON(
            metrics,
            to: outputRoot.appendingPathComponent(
                "RASTER-SURVIVAL-METRICS.json"
            )
        )

        let reviewManifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-raster-survival-review-manifest",
            "disposition": disposition,
            "panels": try FileManager.default.contentsOfDirectory(
                at: outputRoot,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map {
                [
                    "file": relative($0, root: root),
                    "sha256": try reviewSHA256($0),
                ]
            },
            "metricsFile": relative(
                outputRoot.appendingPathComponent(
                    "RASTER-SURVIVAL-METRICS.json"
                ),
                root: root
            ),
            "productionSelected": false,
        ]
        try writeJSON(
            reviewManifest,
            to: outputRoot.appendingPathComponent(
                "REVIEW-MANIFEST.json"
            )
        )
        print("raw \(expectedRawSHA256)")
        print("utilization \(sourceDiamondUtilization)")
        print("residualPlatePixels \(residualPlatePixels)")
        print("disposition \(disposition)")
        print("productionSelected=false")
    }
}
