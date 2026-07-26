import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum FiniteEquivalenceReviewError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l2-finite-equivalence-review --repository-root <path> --baseline <png> --candidate <png> --output-directory <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct ReviewSource {
    let url: URL
    let image: CGImage
    let rgba: [UInt8]
}

private func reviewArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        throw FiniteEquivalenceReviewError.arguments
    }
    return arguments[index + 1]
}

private func reviewURL(_ value: String, root: URL) -> URL {
    let candidate = URL(fileURLWithPath: value)
    return (
        candidate.path.hasPrefix("/")
            ? candidate
            : root.appendingPathComponent(value)
    ).standardizedFileURL
}

private func reviewRelative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

private func reviewSHA256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map {
        String(format: "%02x", $0)
    }.joined()
}

private func reviewLoad(_ url: URL) throws -> ReviewSource {
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
        throw FiniteEquivalenceReviewError.invalid(
            "could not decode 1536x1024 review source"
        )
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
            throw FiniteEquivalenceReviewError.invalid(
                "could not allocate review decoder"
            )
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return ReviewSource(url: url, image: image, rgba: rgba)
}

private func reviewImage(
    width: Int,
    height: Int,
    rgba: [UInt8]
) throws -> CGImage {
    guard
        let provider = CGDataProvider(data: Data(rgba) as CFData),
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
        throw FiniteEquivalenceReviewError.invalid(
            "could not create review image"
        )
    }
    return image
}

private func reviewMasked(_ source: ReviewSource) throws -> CGImage {
    var rgba = source.rgba
    for index in stride(from: 0, to: rgba.count, by: 4) {
        if rgba[index] == 255, rgba[index + 1] == 0, rgba[index + 2] == 255 {
            rgba[index] = 0
            rgba[index + 1] = 0
            rgba[index + 2] = 0
            rgba[index + 3] = 0
        }
    }
    return try reviewImage(
        width: source.image.width,
        height: source.image.height,
        rgba: rgba
    )
}

private func reviewGrayscale(_ image: CGImage) throws -> CGImage {
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
            throw FiniteEquivalenceReviewError.invalid(
                "could not allocate grayscale context"
            )
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
        for index in stride(from: 0, to: storage.count, by: 4) {
            let red = Int(storage[index])
            let green = Int(storage[index + 1])
            let blue = Int(storage[index + 2])
            let weighted = 54 * red + 183 * green + 19 * blue + 128
            let value = UInt8(min(255, weighted >> 8))
            storage[index] = value
            storage[index + 1] = value
            storage[index + 2] = value
        }
    }
    return try reviewImage(
        width: image.width,
        height: image.height,
        rgba: rgba
    )
}

private func reviewCrop(_ image: CGImage) throws -> CGImage {
    guard let cropped = image.cropping(
        to: CGRect(x: 512, y: 270, width: 513, height: 695)
    ) else {
        throw FiniteEquivalenceReviewError.invalid(
            "could not crop registered review envelope"
        )
    }
    return cropped
}

private func reviewSheet(
    images: [CGImage],
    panel: CGSize,
    gutter: Int = 12
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
        throw FiniteEquivalenceReviewError.invalid(
            "could not allocate review sheet"
        )
    }
    context.setFillColor(
        CGColor(
            colorSpace: colorSpace,
            components: [0.11, 0.12, 0.13, 1]
        )!
    )
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
    guard let result = context.makeImage() else {
        throw FiniteEquivalenceReviewError.invalid(
            "could not create review sheet"
        )
    }
    return result
}

private func reviewWrite(_ image: CGImage, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw FiniteEquivalenceReviewError.invalid(
            "review output already exists"
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
        throw FiniteEquivalenceReviewError.invalid(
            "could not create review destination"
        )
    }
    CGImageDestinationAddImage(destination, image, [
        kCGImagePropertyPNGInterlaceType: 0,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw FiniteEquivalenceReviewError.invalid(
            "could not finalize review PNG"
        )
    }
}

private func occupiedBounds(
    _ rgba: [UInt8],
    width: Int,
    height: Int
) -> [Int] {
    var bounds = [width, height, -1, -1]
    for y in 0..<height {
        for x in 0..<width {
            let index = (y * width + x) * 4
            if
                rgba[index] == 255,
                rgba[index + 1] == 0,
                rgba[index + 2] == 255,
                rgba[index + 3] == 255
            {
                continue
            }
            bounds[0] = min(bounds[0], x)
            bounds[1] = min(bounds[1], y)
            bounds[2] = max(bounds[2], x + 1)
            bounds[3] = max(bounds[3], y + 1)
        }
    }
    return bounds[2] < 0 ? [] : bounds
}

@main
enum BuildIndustrialL2FiniteEquivalenceReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try reviewArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let baseline = try reviewLoad(
            reviewURL(
                try reviewArgument("--baseline", in: arguments),
                root: root
            )
        )
        let candidate = try reviewLoad(
            reviewURL(
                try reviewArgument("--candidate", in: arguments),
                root: root
            )
        )
        let outputDirectory = reviewURL(
            try reviewArgument("--output-directory", in: arguments),
            root: root
        )
        guard
            outputDirectory.path.hasSuffix(
                "/source-v06-finite-equivalence-diagnostic/proposal/review"
            ),
            !FileManager.default.fileExists(atPath: outputDirectory.path)
        else {
            throw FiniteEquivalenceReviewError.invalid(
                "review output must use one new exact proposal/review directory"
            )
        }

        var changedPixels = 0
        var changedChannels = [0, 0, 0, 0]
        var absoluteDelta = [0, 0, 0, 0]
        var maximumDelta = [0, 0, 0, 0]
        var differenceBounds = [1536, 1024, -1, -1]
        var differenceRGBA = [UInt8](
            repeating: 0,
            count: baseline.rgba.count
        )
        for y in 0..<1024 {
            for x in 0..<1536 {
                let index = (y * 1536 + x) * 4
                var changed = false
                for channel in 0..<4 {
                    let delta = abs(
                        Int(candidate.rgba[index + channel])
                            - Int(baseline.rgba[index + channel])
                    )
                    if delta > 0 {
                        changed = true
                        changedChannels[channel] += 1
                        absoluteDelta[channel] += delta
                        maximumDelta[channel] =
                            max(maximumDelta[channel], delta)
                    }
                    if channel < 3 {
                        differenceRGBA[index + channel] =
                            UInt8(min(255, delta * 8))
                    }
                }
                if changed {
                    changedPixels += 1
                    differenceBounds[0] = min(differenceBounds[0], x)
                    differenceBounds[1] = min(differenceBounds[1], y)
                    differenceBounds[2] = max(differenceBounds[2], x + 1)
                    differenceBounds[3] = max(differenceBounds[3], y + 1)
                    differenceRGBA[index + 3] = 255
                }
            }
        }
        let baselineCrop = try reviewCrop(try reviewMasked(baseline))
        let candidateCrop = try reviewCrop(try reviewMasked(candidate))
        let differenceCrop = try reviewCrop(
            try reviewImage(
                width: 1536,
                height: 1024,
                rgba: differenceRGBA
            )
        )
        let nativePanel = CGSize(width: 144, height: 195)
        let colorURL = outputDirectory.appendingPathComponent(
            "NATIVE-2X-COLOR-FROZEN-V06-VS-PROPOSAL.png"
        )
        let grayscaleURL = outputDirectory.appendingPathComponent(
            "NATIVE-2X-GRAYSCALE-FROZEN-V06-VS-PROPOSAL.png"
        )
        let differenceURL = outputDirectory.appendingPathComponent(
            "NATIVE-2X-DIFFERENCE-X8.png"
        )
        let sourceScaleURL = outputDirectory.appendingPathComponent(
            "SOURCE-SCALE-FROZEN-V06-VS-PROPOSAL-DIFFERENCE-X8.png"
        )
        try reviewWrite(
            try reviewSheet(
                images: [baselineCrop, candidateCrop],
                panel: nativePanel
            ),
            to: colorURL
        )
        try reviewWrite(
            try reviewSheet(
                images: [
                    try reviewGrayscale(baselineCrop),
                    try reviewGrayscale(candidateCrop),
                ],
                panel: nativePanel
            ),
            to: grayscaleURL
        )
        try reviewWrite(
            try reviewSheet(
                images: [differenceCrop],
                panel: nativePanel,
                gutter: 0
            ),
            to: differenceURL
        )
        try reviewWrite(
            try reviewSheet(
                images: [
                    baselineCrop,
                    candidateCrop,
                    differenceCrop,
                ],
                panel: CGSize(width: 513, height: 695)
            ),
            to: sourceScaleURL
        )
        let files = [
            ("native2xColor", colorURL),
            ("native2xGrayscale", grayscaleURL),
            ("native2xDifferenceAmplified8x", differenceURL),
            ("sourceScaleComparison", sourceScaleURL),
        ]
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "comparison":
                "frozen-source-v06-vs-finite-equivalence-proposal",
            "panelOrder": [
                "frozen source-v06",
                "finite equivalence proposal",
                "amplified absolute RGB difference where present",
            ],
            "baseline": [
                "file": reviewRelative(baseline.url, root: root),
                "fileSHA256": try reviewSHA256(baseline.url),
                "occupiedBounds": occupiedBounds(
                    baseline.rgba,
                    width: 1536,
                    height: 1024
                ),
            ],
            "candidate": [
                "file": reviewRelative(candidate.url, root: root),
                "fileSHA256": try reviewSHA256(candidate.url),
                "occupiedBounds": occupiedBounds(
                    candidate.rgba,
                    width: 1536,
                    height: 1024
                ),
            ],
            "changedPixelCount": changedPixels,
            "changedPixelRatio":
                Double(changedPixels) / Double(1536 * 1024),
            "changedChannelCounts": [
                "red": changedChannels[0],
                "green": changedChannels[1],
                "blue": changedChannels[2],
                "alpha": changedChannels[3],
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
            "differenceBoundsSource":
                differenceBounds[2] < 0 ? [] : differenceBounds,
            "registeredCrop": [512, 270, 513, 695],
            "native2xPanelPixelsPerImage": [144, 195],
            "native2xScale": 0.28125,
            "differenceRendering":
                "absolute decoded RGB delta multiplied by 8 and clamped",
            "files": try files.map { role, url in
                [
                    "role": role,
                    "file": reviewRelative(url, root: root),
                    "sha256": try reviewSHA256(url),
                ]
            },
            "normalizationPerformed": false,
            "productionSelected": false,
        ]
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        try data.write(
            to: outputDirectory.appendingPathComponent(
                "VISUAL-COMPARISON-METRICS.json"
            ),
            options: .atomic
        )
    }
}
