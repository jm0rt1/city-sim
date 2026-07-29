import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum RetainedPixelComparisonError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: compare-retained-raw-pixels --repository-root <path> --primary <png> --repeat-b <png> --repeat-c <png> --report <json> --sheet <png> [--diagnostic-id <id>]"
        case let .invalid(message):
            return message
        }
    }
}

func comparisonOptionalArgument(
    _ name: String,
    in arguments: [String]
) -> String? {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        return nil
    }
    return arguments[index + 1]
}

struct RetainedPNG {
    let url: URL
    let fileSHA256: String
    let width: Int
    let height: Int
    let rgba: [UInt8]

    func pixel(x: Int, y: Int) -> [UInt8] {
        let index = (y * width + x) * 4
        return Array(rgba[index..<(index + 4)])
    }
}

struct PixelDifference {
    let x: Int
    let y: Int
    let primary: [UInt8]
    let repeatB: [UInt8]
    let repeatC: [UInt8]

    var differingChannels: [String] {
        let names = ["red", "green", "blue", "alpha"]
        return names.indices.compactMap { index in
            primary[index] == repeatB[index] ? nil : names[index]
        }
    }

    var record: [String: Any] {
        [
            "sourceCoordinate": [x, y],
            "primaryRGBA": primary,
            "repeatBRGBA": repeatB,
            "repeatCRGBA": repeatC,
            "differingChannels": differingChannels,
        ]
    }
}

func comparisonArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw RetainedPixelComparisonError.arguments
    }
    return arguments[index + 1]
}

func comparisonURL(
    _ value: String,
    repositoryRoot: URL
) -> URL {
    let candidate = URL(fileURLWithPath: value)
    return (
        candidate.path.hasPrefix("/")
            ? candidate
            : repositoryRoot.appendingPathComponent(value)
    ).standardizedFileURL
}

func comparisonRelativePath(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path + "/"
    guard url.path.hasPrefix(prefix) else {
        return url.path
    }
    return String(url.path.dropFirst(prefix.count))
}

func comparisonSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func decodeRetainedPNG(_ url: URL) throws -> RetainedPNG {
    let fileData = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary),
        image.bitsPerComponent == 8,
        image.bitsPerPixel == 32,
        image.bytesPerRow >= image.width * 4,
        image.alphaInfo == .last || image.alphaInfo == .premultipliedLast,
        let providerData = image.dataProvider?.data
    else {
        throw RetainedPixelComparisonError.invalid(
            "standard ImageIO RGBA decode failed for \(url.path)"
        )
    }
    let storage = providerData as Data
    guard storage.count >= image.bytesPerRow * image.height else {
        throw RetainedPixelComparisonError.invalid(
            "decoded RGBA storage is incomplete for \(url.path)"
        )
    }
    var rgba = [UInt8](
        repeating: 0,
        count: image.width * image.height * 4
    )
    for y in 0..<image.height {
        let sourceStart = y * image.bytesPerRow
        let destinationStart = y * image.width * 4
        rgba.withUnsafeMutableBytes { destination in
            storage.withUnsafeBytes { sourceBytes in
                guard
                    let destinationBase = destination.baseAddress,
                    let sourceBase = sourceBytes.baseAddress
                else {
                    return
                }
                destinationBase
                    .advanced(by: destinationStart)
                    .copyMemory(
                        from: sourceBase.advanced(by: sourceStart),
                        byteCount: image.width * 4
                    )
            }
        }
    }
    return RetainedPNG(
        url: url,
        fileSHA256: comparisonSHA256(fileData),
        width: image.width,
        height: image.height,
        rgba: rgba
    )
}

func differenceCount(
    _ first: RetainedPNG,
    _ second: RetainedPNG
) throws -> (pixels: Int, channels: Int, alphaPixels: Int) {
    guard first.width == second.width, first.height == second.height else {
        throw RetainedPixelComparisonError.invalid(
            "retained PNG dimensions differ"
        )
    }
    var pixels = 0
    var channels = 0
    var alphaPixels = 0
    for index in stride(from: 0, to: first.rgba.count, by: 4) {
        var pixelChanged = false
        for channel in 0..<4
        where first.rgba[index + channel] != second.rgba[index + channel] {
            channels += 1
            pixelChanged = true
            if channel == 3 {
                alphaPixels += 1
            }
        }
        if pixelChanged {
            pixels += 1
        }
    }
    return (pixels, channels, alphaPixels)
}

func makeLocalitySheet(
    primary: RetainedPNG,
    repeatB: RetainedPNG,
    differences: [PixelDifference],
    outputURL: URL
) throws {
    guard
        let minimumX = differences.map(\.x).min(),
        let maximumX = differences.map(\.x).max(),
        let minimumY = differences.map(\.y).min(),
        let maximumY = differences.map(\.y).max()
    else {
        throw RetainedPixelComparisonError.invalid(
            "locality sheet requires at least one differing pixel"
        )
    }
    let padding = 10
    let cropX = max(0, minimumX - padding)
    let cropY = max(0, minimumY - padding)
    let cropMaxX = min(primary.width, maximumX + padding + 1)
    let cropMaxY = min(primary.height, maximumY + padding + 1)
    let cropWidth = cropMaxX - cropX
    let cropHeight = cropMaxY - cropY
    let zoom = 12
    let panelWidth = cropWidth * zoom
    let panelHeight = cropHeight * zoom
    let gap = 12
    let outputWidth = panelWidth * 3 + gap * 2
    let outputHeight = panelHeight
    var output = [UInt8](
        repeating: 0,
        count: outputWidth * outputHeight * 4
    )
    for pixel in stride(from: 0, to: output.count, by: 4) {
        output[pixel] = 24
        output[pixel + 1] = 28
        output[pixel + 2] = 34
        output[pixel + 3] = 255
    }
    let changedCoordinates = Set(
        differences.map { "\($0.x),\($0.y)" }
    )

    func writePanel(
        originX: Int,
        source: RetainedPNG?,
        differenceMask: Bool
    ) {
        for cropRow in 0..<cropHeight {
            for cropColumn in 0..<cropWidth {
                let sourceX = cropX + cropColumn
                let sourceY = cropY + cropRow
                let sourcePixel = source?.pixel(x: sourceX, y: sourceY)
                let changed = changedCoordinates.contains(
                    "\(sourceX),\(sourceY)"
                )
                let color: [UInt8]
                if differenceMask {
                    color = changed
                        ? [255, 128, 32, 255]
                        : [36, 42, 50, 255]
                } else {
                    color = sourcePixel ?? [0, 0, 0, 255]
                }
                for zoomY in 0..<zoom {
                    for zoomX in 0..<zoom {
                        let outputX = originX + cropColumn * zoom + zoomX
                        let outputY = cropRow * zoom + zoomY
                        let destination =
                            (outputY * outputWidth + outputX) * 4
                        output[destination] = color[0]
                        output[destination + 1] = color[1]
                        output[destination + 2] = color[2]
                        output[destination + 3] = color[3]
                    }
                }
            }
        }
    }

    writePanel(originX: 0, source: primary, differenceMask: false)
    writePanel(
        originX: panelWidth + gap,
        source: repeatB,
        differenceMask: false
    )
    writePanel(
        originX: (panelWidth + gap) * 2,
        source: nil,
        differenceMask: true
    )

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let data = Data(output)
    guard
        let provider = CGDataProvider(data: data as CFData),
        let image = CGImage(
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: outputWidth * 4,
            space: colorSpace,
            bitmapInfo:
                CGBitmapInfo.byteOrder32Big.union(
                    CGBitmapInfo(
                        rawValue:
                            CGImageAlphaInfo.premultipliedLast.rawValue
                    )
                ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ),
        let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw RetainedPixelComparisonError.invalid(
            "could not create locality sheet"
        )
    }
    CGImageDestinationAddImage(destination, image, [
        kCGImageDestinationLossyCompressionQuality: 1.0,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw RetainedPixelComparisonError.invalid(
            "could not write locality sheet"
        )
    }
}

@main
enum CompareRetainedRawPixelsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try comparisonArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let primary = try decodeRetainedPNG(
            comparisonURL(
                try comparisonArgument("--primary", in: arguments),
                repositoryRoot: repositoryRoot
            )
        )
        let repeatB = try decodeRetainedPNG(
            comparisonURL(
                try comparisonArgument("--repeat-b", in: arguments),
                repositoryRoot: repositoryRoot
            )
        )
        let repeatC = try decodeRetainedPNG(
            comparisonURL(
                try comparisonArgument("--repeat-c", in: arguments),
                repositoryRoot: repositoryRoot
            )
        )
        guard
            primary.width == repeatB.width,
            primary.height == repeatB.height,
            primary.width == repeatC.width,
            primary.height == repeatC.height
        else {
            throw RetainedPixelComparisonError.invalid(
                "retained PNG dimensions differ"
            )
        }
        var differences: [PixelDifference] = []
        for y in 0..<primary.height {
            for x in 0..<primary.width {
                let primaryPixel = primary.pixel(x: x, y: y)
                let repeatBPixel = repeatB.pixel(x: x, y: y)
                if primaryPixel != repeatBPixel {
                    differences.append(
                        PixelDifference(
                            x: x,
                            y: y,
                            primary: primaryPixel,
                            repeatB: repeatBPixel,
                            repeatC: repeatC.pixel(x: x, y: y)
                        )
                    )
                }
            }
        }
        guard !differences.isEmpty else {
            throw RetainedPixelComparisonError.invalid(
                "primary and repeat B contain no differing pixels"
            )
        }
        let primaryVsB = try differenceCount(primary, repeatB)
        let primaryVsC = try differenceCount(primary, repeatC)
        let bVsC = try differenceCount(repeatB, repeatC)
        let bounds = [
            differences.map(\.x).min()!,
            differences.map(\.y).min()!,
            differences.map(\.x).max()! + 1,
            differences.map(\.y).max()! + 1,
        ]
        let reportURL = comparisonURL(
            try comparisonArgument("--report", in: arguments),
            repositoryRoot: repositoryRoot
        )
        let sheetURL = comparisonURL(
            try comparisonArgument("--sheet", in: arguments),
            repositoryRoot: repositoryRoot
        )
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: sheetURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try makeLocalitySheet(
            primary: primary,
            repeatB: repeatB,
            differences: differences,
            outputURL: sheetURL
        )
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "diagnostic":
                comparisonOptionalArgument(
                    "--diagnostic-id",
                    in: arguments
                )
                ?? "commercial-l04-source-v02-west-pixel-locality",
            "coordinateOrigin": "top-left exact decoded RGBA row",
            "primary": [
                "file": comparisonRelativePath(
                    primary.url,
                    repositoryRoot: repositoryRoot
                ),
                "fileSHA256": primary.fileSHA256,
                "decodedRGBASHA256":
                    comparisonSHA256(Data(primary.rgba)),
            ],
            "repeatB": [
                "file": comparisonRelativePath(
                    repeatB.url,
                    repositoryRoot: repositoryRoot
                ),
                "fileSHA256": repeatB.fileSHA256,
                "decodedRGBASHA256":
                    comparisonSHA256(Data(repeatB.rgba)),
            ],
            "repeatC": [
                "file": comparisonRelativePath(
                    repeatC.url,
                    repositoryRoot: repositoryRoot
                ),
                "fileSHA256": repeatC.fileSHA256,
                "decodedRGBASHA256":
                    comparisonSHA256(Data(repeatC.rgba)),
            ],
            "sourcePixels": [primary.width, primary.height],
            "differenceBoundsSource": bounds,
            "primaryVsRepeatB": [
                "differingPixelCount": primaryVsB.pixels,
                "differingChannelCount": primaryVsB.channels,
                "alphaDifferingPixelCount": primaryVsB.alphaPixels,
            ],
            "primaryVsRepeatC": [
                "differingPixelCount": primaryVsC.pixels,
                "differingChannelCount": primaryVsC.channels,
                "alphaDifferingPixelCount": primaryVsC.alphaPixels,
            ],
            "repeatBVsRepeatC": [
                "differingPixelCount": bVsC.pixels,
                "differingChannelCount": bVsC.channels,
                "alphaDifferingPixelCount": bVsC.alphaPixels,
            ],
            "differingPixels": differences.map(\.record),
            "contactZoom": [
                "file": comparisonRelativePath(
                    sheetURL,
                    repositoryRoot: repositoryRoot
                ),
                "panelOrder": [
                    "primary exact crop",
                    "repeat B exact crop",
                    "difference mask",
                ],
                "nearestNeighborScale": 12,
                "cropPaddingSourcePixels": 10,
            ],
            "productionSelected": false,
        ]
        let reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var terminated = reportData
        terminated.append(0x0a)
        try terminated.write(to: reportURL, options: .atomic)
    }
}
