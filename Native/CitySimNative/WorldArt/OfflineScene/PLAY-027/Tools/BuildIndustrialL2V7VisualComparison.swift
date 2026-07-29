import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum V7ComparisonError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l2-v7-visual-comparison --repository-root <path> --baseline <png> --candidate <png> --output-directory <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct ReviewImage {
    let url: URL
    let image: CGImage
    let rgba: [UInt8]
}

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        throw V7ComparisonError.arguments
    }
    return arguments[index + 1]
}

private func resolvedURL(_ value: String, root: URL) -> URL {
    let candidate = URL(fileURLWithPath: value)
    return (
        candidate.path.hasPrefix("/")
            ? candidate
            : root.appendingPathComponent(value)
    ).standardizedFileURL
}

private func relativePath(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

private func sha256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map {
        String(format: "%02x", $0)
    }.joined()
}

private func load(_ url: URL) throws -> ReviewImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        ),
        image.width == 1536,
        image.height == 1024
    else {
        throw V7ComparisonError.invalid("could not decode 1536x1024 PNG \(url.path)")
    }
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    try rgba.withUnsafeMutableBytes { storage in
        guard let context = CGContext(
            data: storage.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: colorSpace,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw V7ComparisonError.invalid("could not allocate RGBA decoder")
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return ReviewImage(url: url, image: image, rgba: rgba)
}

private func makeImage(width: Int, height: Int, rgba: [UInt8]) throws -> CGImage {
    var bytes = rgba
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    return try bytes.withUnsafeMutableBytes { storage in
        guard
            let context = CGContext(
                data: storage.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo:
                    CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            let image = context.makeImage()
        else {
            throw V7ComparisonError.invalid("could not create RGBA image")
        }
        return image
    }
}

private func chromaMasked(_ source: ReviewImage) throws -> CGImage {
    var bytes = source.rgba
    for index in stride(from: 0, to: bytes.count, by: 4) {
        if bytes[index] == 255, bytes[index + 1] == 0, bytes[index + 2] == 255 {
            bytes[index] = 0
            bytes[index + 1] = 0
            bytes[index + 2] = 0
            bytes[index + 3] = 0
        }
    }
    return try makeImage(width: source.image.width, height: source.image.height, rgba: bytes)
}

private func grayscale(_ image: CGImage) throws -> CGImage {
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    try rgba.withUnsafeMutableBytes { storage in
        guard let context = CGContext(
            data: storage.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: colorSpace,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw V7ComparisonError.invalid("could not allocate grayscale context")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        for index in stride(from: 0, to: storage.count, by: 4) {
            let red = Int(storage[index])
            let green = Int(storage[index + 1])
            let blue = Int(storage[index + 2])
            let weighted = 54 * red + 183 * green + 19 * blue + 128
            let luma = UInt8(min(255, weighted >> 8))
            storage[index] = luma
            storage[index + 1] = luma
            storage[index + 2] = luma
        }
    }
    return try makeImage(width: image.width, height: image.height, rgba: rgba)
}

private func cropped(_ image: CGImage, rect: CGRect) throws -> CGImage {
    guard let result = image.cropping(to: rect) else {
        throw V7ComparisonError.invalid("could not crop registered envelope")
    }
    return result
}

private func sheet(
    images: [CGImage],
    panel: CGSize,
    gutter: Int = 12,
    background: [CGFloat] = [0.11, 0.12, 0.13, 1]
) throws -> CGImage {
    let width = Int(panel.width) * images.count + gutter * (images.count - 1)
    let height = Int(panel.height)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw V7ComparisonError.invalid("could not allocate comparison sheet")
    }
    context.setFillColor(CGColor(colorSpace: colorSpace, components: background)!)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .none
    for (index, image) in images.enumerated() {
        context.draw(
            image,
            in: CGRect(
                x: index * (Int(panel.width) + gutter),
                y: 0,
                width: Int(panel.width),
                height: Int(panel.height)
            )
        )
    }
    guard let output = context.makeImage() else {
        throw V7ComparisonError.invalid("could not create comparison sheet")
    }
    return output
}

private func writePNG(_ image: CGImage, to url: URL) throws {
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
        throw V7ComparisonError.invalid("could not create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, [
        kCGImagePropertyPNGInterlaceType: 0,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw V7ComparisonError.invalid("could not finalize PNG")
    }
}

private func occupiedBounds(_ rgba: [UInt8], width: Int, height: Int) -> [Int] {
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    for y in 0..<height {
        for x in 0..<width {
            let index = (y * width + x) * 4
            if rgba[index] == 255, rgba[index + 1] == 0, rgba[index + 2] == 255 {
                continue
            }
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
    return maxX < 0 ? [] : [minX, minY, maxX + 1, maxY + 1]
}

@main
enum BuildIndustrialL2V7VisualComparison {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try argument("--repository-root", in: arguments)
        ).standardizedFileURL
        let baseline = try load(
            resolvedURL(try argument("--baseline", in: arguments), root: root)
        )
        let candidate = try load(
            resolvedURL(try argument("--candidate", in: arguments), root: root)
        )
        let outputDirectory = resolvedURL(
            try argument("--output-directory", in: arguments),
            root: root
        )
        let registeredCrop = CGRect(x: 512, y: 270, width: 513, height: 695)
        let nativePanel = CGSize(width: 144, height: 195)
        let baselineMasked = try chromaMasked(baseline)
        let candidateMasked = try chromaMasked(candidate)
        let baselineCrop = try cropped(baselineMasked, rect: registeredCrop)
        let candidateCrop = try cropped(candidateMasked, rect: registeredCrop)

        var differentPixels = 0
        var differentChannels = [0, 0, 0, 0]
        var absoluteDelta = [0, 0, 0, 0]
        var maximumDelta = [0, 0, 0, 0]
        var differenceMinX = baseline.image.width
        var differenceMinY = baseline.image.height
        var differenceMaxX = -1
        var differenceMaxY = -1
        var differenceRGBA = [UInt8](
            repeating: 0,
            count: baseline.image.width * baseline.image.height * 4
        )
        for y in 0..<baseline.image.height {
            for x in 0..<baseline.image.width {
                let index = (y * baseline.image.width + x) * 4
                var changed = false
                for channel in 0..<4 {
                    let delta = abs(
                        Int(candidate.rgba[index + channel])
                            - Int(baseline.rgba[index + channel])
                    )
                    if delta > 0 {
                        changed = true
                        differentChannels[channel] += 1
                        absoluteDelta[channel] += delta
                        maximumDelta[channel] = max(maximumDelta[channel], delta)
                    }
                    if channel < 3 {
                        differenceRGBA[index + channel] = UInt8(min(255, delta * 4))
                    }
                }
                if changed {
                    differentPixels += 1
                    differenceMinX = min(differenceMinX, x)
                    differenceMinY = min(differenceMinY, y)
                    differenceMaxX = max(differenceMaxX, x)
                    differenceMaxY = max(differenceMaxY, y)
                    differenceRGBA[index + 3] = 255
                }
            }
        }
        let differenceImage = try makeImage(
            width: baseline.image.width,
            height: baseline.image.height,
            rgba: differenceRGBA
        )
        let differenceCrop = try cropped(differenceImage, rect: registeredCrop)

        let colorURL = outputDirectory.appendingPathComponent(
            "NATIVE-2X-COLOR-V06-VS-V07.png"
        )
        let grayscaleURL = outputDirectory.appendingPathComponent(
            "NATIVE-2X-GRAYSCALE-V06-VS-V07.png"
        )
        let differenceURL = outputDirectory.appendingPathComponent(
            "NATIVE-2X-DIFFERENCE-X4.png"
        )
        let sourceDifferenceURL = outputDirectory.appendingPathComponent(
            "SOURCE-SCALE-CROP-V06-VS-V07-DIFFERENCE-X4.png"
        )
        try writePNG(
            try sheet(images: [baselineCrop, candidateCrop], panel: nativePanel),
            to: colorURL
        )
        try writePNG(
            try sheet(
                images: [
                    try grayscale(baselineCrop),
                    try grayscale(candidateCrop),
                ],
                panel: nativePanel
            ),
            to: grayscaleURL
        )
        try writePNG(
            try sheet(images: [differenceCrop], panel: nativePanel, gutter: 0),
            to: differenceURL
        )
        try writePNG(
            try sheet(
                images: [baselineCrop, candidateCrop, differenceCrop],
                panel: CGSize(width: 513, height: 695)
            ),
            to: sourceDifferenceURL
        )

        let files = [
            ("native2xColor", colorURL),
            ("native2xGrayscale", grayscaleURL),
            ("native2xDifferenceAmplified4x", differenceURL),
            ("sourceScaleRegisteredCropComparison", sourceDifferenceURL),
        ]
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "comparison": "frozen-source-v06-vs-source-v07-pre-lanczos-canonicalized",
            "baseline": [
                "file": relativePath(baseline.url, root: root),
                "fileSHA256": try sha256(baseline.url),
                "occupiedBounds": occupiedBounds(
                    baseline.rgba,
                    width: baseline.image.width,
                    height: baseline.image.height
                ),
            ],
            "candidate": [
                "file": relativePath(candidate.url, root: root),
                "fileSHA256": try sha256(candidate.url),
                "occupiedBounds": occupiedBounds(
                    candidate.rgba,
                    width: candidate.image.width,
                    height: candidate.image.height
                ),
            ],
            "registeredCrop": [512, 270, 513, 695],
            "native2xPanelPixelsPerImage": [144, 195],
            "native2xScale": 0.28125,
            "changedPixelCount": differentPixels,
            "changedPixelRatio": Double(differentPixels)
                / Double(baseline.image.width * baseline.image.height),
            "changedChannelCounts": [
                "red": differentChannels[0],
                "green": differentChannels[1],
                "blue": differentChannels[2],
                "alpha": differentChannels[3],
            ],
            "absoluteChannelDeltaSums": [
                "red": absoluteDelta[0],
                "green": absoluteDelta[1],
                "blue": absoluteDelta[2],
                "alpha": absoluteDelta[3],
            ],
            "maximumChannelDelta": [
                "red": maximumDelta[0],
                "green": maximumDelta[1],
                "blue": maximumDelta[2],
                "alpha": maximumDelta[3],
            ],
            "differenceBoundsSource": (
                differenceMaxX < 0
                    ? []
                    : [
                        differenceMinX,
                        differenceMinY,
                        differenceMaxX + 1,
                        differenceMaxY + 1,
                    ]
            ),
            "differenceRendering": "absolute decoded RGB delta multiplied by 4 and clamped; alpha 255 only where any channel differs",
            "files": try files.map { role, url in
                [
                    "role": role,
                    "file": relativePath(url, root: root),
                    "sha256": try sha256(url),
                ]
            },
            "normalizationPerformed": false,
            "productionSelected": false,
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        try data.write(
            to: outputDirectory.appendingPathComponent(
                "V06-VS-V07-VISUAL-METRICS.json"
            ),
            options: .atomic
        )
    }
}
