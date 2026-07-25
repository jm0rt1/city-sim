import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

enum RenderedSourceValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-rendered-sources --repository-root <path> --output <json> --expect <identical|unique> [--kind <raw|normalized>] --source <id=png> [--source <id=png> ...]"
        case let .invalid(message):
            return message
        }
    }
}

struct CanonicalPixels {
    let width: Int
    let height: Int
    let data: Data
}

func argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw RenderedSourceValidationError.arguments
    }
    return arguments[index + 1]
}

func repeatedArguments(
    _ name: String,
    in arguments: [String]
) throws -> [String] {
    var values: [String] = []
    for (index, argument) in arguments.enumerated()
    where argument == name && index + 1 < arguments.count {
        values.append(arguments[index + 1])
    }
    guard !values.isEmpty else {
        throw RenderedSourceValidationError.arguments
    }
    return values
}

func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func relativePath(_ url: URL, repositoryRoot: URL) -> String {
    let prefix = repositoryRoot.path + "/"
    guard url.path.hasPrefix(prefix) else {
        return url.path
    }
    return String(url.path.dropFirst(prefix.count))
}

func loadCanonicalPixels(from url: URL) throws -> CanonicalPixels {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw RenderedSourceValidationError.invalid(
            "could not decode \(url.path)"
        )
    }
    let width = image.width
    let height = image.height
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let created = bytes.withUnsafeMutableBytes { storage -> Bool in
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
            return false
        }
        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
        return true
    }
    guard created else {
        throw RenderedSourceValidationError.invalid(
            "could not canonicalize \(url.path)"
        )
    }
    return CanonicalPixels(width: width, height: height, data: Data(bytes))
}

func inspect(_ pixels: CanonicalPixels) -> [String: Any] {
    let bytes = [UInt8](pixels.data)
    var alphaMinimum = 255
    var alphaMaximum = 0
    var chromaPixelCount = 0
    var minimumX = pixels.width
    var minimumY = pixels.height
    var maximumX = -1
    var maximumY = -1

    for y in 0..<pixels.height {
        for x in 0..<pixels.width {
            let index = (y * pixels.width + x) * 4
            let red = Int(bytes[index])
            let green = Int(bytes[index + 1])
            let blue = Int(bytes[index + 2])
            let alpha = Int(bytes[index + 3])
            alphaMinimum = min(alphaMinimum, alpha)
            alphaMaximum = max(alphaMaximum, alpha)
            if red == 255 && green == 0 && blue == 255 && alpha == 255 {
                chromaPixelCount += 1
            } else {
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
            }
        }
    }

    let corners = [
        0,
        (pixels.width - 1) * 4,
        ((pixels.height - 1) * pixels.width) * 4,
        (pixels.width * pixels.height - 1) * 4,
    ].map { index in
        Array(bytes[index..<(index + 4)]) == [255, 0, 255, 255]
    }
    let bounds: [Int]
    let padding: [Int]
    if maximumX >= 0 {
        bounds = [minimumX, minimumY, maximumX + 1, maximumY + 1]
        padding = [
            minimumX,
            minimumY,
            pixels.width - maximumX - 1,
            pixels.height - maximumY - 1,
        ]
    } else {
        bounds = []
        padding = []
    }
    return [
        "alphaRange": [alphaMinimum, alphaMaximum],
        "allRawPixelsOpaque": alphaMinimum == 255 && alphaMaximum == 255,
        "exactChromaPixelCount": chromaPixelCount,
        "flatChromaCorners": corners.allSatisfy { $0 },
        "nonChromaBounds": bounds,
        "paddingPixels": padding,
    ]
}

func inspectNormalized(_ pixels: CanonicalPixels) -> [String: Any] {
    let bytes = [UInt8](pixels.data)
    var alphaMinimum = 255
    var alphaMaximum = 0
    var transparentPixelCount = 0
    var opaquePixelCount = 0
    var opaqueChromaPixelCount = 0
    var minimumX = pixels.width
    var minimumY = pixels.height
    var maximumX = -1
    var maximumY = -1

    for y in 0..<pixels.height {
        for x in 0..<pixels.width {
            let index = (y * pixels.width + x) * 4
            let red = Int(bytes[index])
            let green = Int(bytes[index + 1])
            let blue = Int(bytes[index + 2])
            let alpha = Int(bytes[index + 3])
            alphaMinimum = min(alphaMinimum, alpha)
            alphaMaximum = max(alphaMaximum, alpha)
            if alpha == 0 {
                transparentPixelCount += 1
            } else {
                opaquePixelCount += 1
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
                if red == 255 && green == 0 && blue == 255 {
                    opaqueChromaPixelCount += 1
                }
            }
        }
    }
    let bounds = maximumX >= 0
        ? [minimumX, minimumY, maximumX + 1, maximumY + 1]
        : []
    let padding = maximumX >= 0
        ? [
            minimumX,
            minimumY,
            pixels.width - maximumX - 1,
            pixels.height - maximumY - 1,
        ]
        : []
    let paddingPassed =
        padding.count == 4 && padding.allSatisfy { $0 > 2 }
    return [
        "alphaRange": [alphaMinimum, alphaMaximum],
        "alphaBounds": bounds,
        "paddingPixels": padding,
        "paddingPassed": paddingPassed,
        "transparentPixelCount": transparentPixelCount,
        "nonTransparentPixelCount": opaquePixelCount,
        "opaqueChromaPixelCount": opaqueChromaPixelCount,
        "alphaAndChromaPassed":
            alphaMinimum == 0
            && alphaMaximum == 255
            && transparentPixelCount > 0
            && opaquePixelCount > 0
            && opaqueChromaPixelCount == 0,
    ]
}

@main
enum ValidateRenderedSourcesMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputURL = URL(
            fileURLWithPath: try argument("--output", in: arguments)
        ).standardizedFileURL
        let expectation = try argument("--expect", in: arguments)
        guard expectation == "identical" || expectation == "unique" else {
            throw RenderedSourceValidationError.arguments
        }
        let kind: String
        if let kindIndex = arguments.firstIndex(of: "--kind") {
            guard kindIndex + 1 < arguments.count else {
                throw RenderedSourceValidationError.arguments
            }
            kind = arguments[kindIndex + 1]
        } else {
            kind = "raw"
        }
        guard kind == "raw" || kind == "normalized" else {
            throw RenderedSourceValidationError.arguments
        }
        let sourceArguments = try repeatedArguments(
            "--source",
            in: arguments
        )
        var records: [[String: Any]] = []
        var pixelHashes: [String] = []
        var basicChecksPassed = true

        for sourceArgument in sourceArguments {
            let parts = sourceArgument.split(
                separator: "=",
                maxSplits: 1
            ).map(String.init)
            guard parts.count == 2 else {
                throw RenderedSourceValidationError.arguments
            }
            let id = parts[0]
            let candidateURL = URL(fileURLWithPath: parts[1])
            let sourceURL = candidateURL.path.hasPrefix("/")
                ? candidateURL
                : repositoryRoot.appendingPathComponent(parts[1])
            let fileData = try Data(contentsOf: sourceURL)
            let pixels = try loadCanonicalPixels(from: sourceURL)
            let inspection = kind == "raw"
                ? inspect(pixels)
                : inspectNormalized(pixels)
            let dimensionsPassed = kind == "raw"
                ? pixels.width == 1536 && pixels.height == 1024
                : [
                    [1024, 683],
                    [512, 342],
                    [256, 171],
                ].contains([pixels.width, pixels.height])
            let sourcePassed: Bool
            if kind == "raw" {
                sourcePassed =
                    dimensionsPassed
                    && (inspection["flatChromaCorners"] as? Bool == true)
                    && (inspection["allRawPixelsOpaque"] as? Bool == true)
            } else {
                sourcePassed =
                    dimensionsPassed
                    && (inspection["alphaAndChromaPassed"] as? Bool == true)
                    && (inspection["paddingPassed"] as? Bool == true)
            }
            basicChecksPassed = basicChecksPassed && sourcePassed
            let pixelHash = sha256(pixels.data)
            pixelHashes.append(pixelHash)
            records.append([
                "id": id,
                "file": relativePath(
                    sourceURL,
                    repositoryRoot: repositoryRoot
                ),
                "fileSHA256": sha256(fileData),
                "pixelSHA256": pixelHash,
                "pixels": [pixels.width, pixels.height],
                "inspection": inspection,
                "sourceChecksPassed": sourcePassed,
            ])
        }

        let uniquePixelHashCount = Set(pixelHashes).count
        let expectationPassed = expectation == "identical"
            ? uniquePixelHashCount == 1
            : uniquePixelHashCount == pixelHashes.count
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "tool": "macOS-native canonical RGBA source validator",
            "sourceKind": kind,
            "canonicalPixelFormat": "8-bit sRGB premultiplied RGBA",
            "pixelExpectation": expectation,
            "pixelExpectationPassed": expectationPassed,
            "uniquePixelHashCount": uniquePixelHashCount,
            "sourceCount": records.count,
            "sources": records,
            "validationPassed": basicChecksPassed && expectationPassed,
        ]
        let data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var terminated = data
        terminated.append(0x0a)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try terminated.write(to: outputURL, options: .atomic)
        if !basicChecksPassed || !expectationPassed {
            throw RenderedSourceValidationError.invalid(
                "rendered source validation failed"
            )
        }
    }
}
