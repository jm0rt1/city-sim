import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

enum CalibrationValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-blender-calibration-raw --repository-root <path> --output <json> --expect <unique|identical> --source <id=png> [--source <id=png> ...]"
        case let .invalid(message):
            return message
        }
    }
}

struct CanonicalImage {
    let width: Int
    let height: Int
    let rgba: Data
}

func required(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw CalibrationValidationError.arguments
    }
    return arguments[index + 1]
}

func repeated(_ name: String, in arguments: [String]) throws -> [String] {
    var values: [String] = []
    for (index, value) in arguments.enumerated()
    where value == name && index + 1 < arguments.count {
        values.append(arguments[index + 1])
    }
    guard !values.isEmpty else {
        throw CalibrationValidationError.arguments
    }
    return values
}

func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func canonicalImage(_ url: URL) throws -> CanonicalImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw CalibrationValidationError.invalid(
            "could not decode \(url.path)"
        )
    }
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let created = bytes.withUnsafeMutableBytes { storage -> Bool in
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
            return false
        }
        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
        return true
    }
    guard created else {
        throw CalibrationValidationError.invalid(
            "could not canonicalize \(url.path)"
        )
    }
    return CanonicalImage(
        width: image.width,
        height: image.height,
        rgba: Data(bytes)
    )
}

func relative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func inspect(_ image: CanonicalImage) -> [String: Any] {
    let bytes = [UInt8](image.rgba)
    var alphaMinimum = 255
    var alphaMaximum = 0
    var transparent = 0
    var visible = 0
    var hiddenRGB = 0
    var exactChroma = 0
    var nearChroma = 0
    var minimumX = image.width
    var minimumY = image.height
    var maximumX = -1
    var maximumY = -1

    for y in 0..<image.height {
        for x in 0..<image.width {
            let offset = (y * image.width + x) * 4
            let red = Int(bytes[offset])
            let green = Int(bytes[offset + 1])
            let blue = Int(bytes[offset + 2])
            let alpha = Int(bytes[offset + 3])
            alphaMinimum = min(alphaMinimum, alpha)
            alphaMaximum = max(alphaMaximum, alpha)
            if alpha == 0 {
                transparent += 1
                if red != 0 || green != 0 || blue != 0 {
                    hiddenRGB += 1
                }
                continue
            }
            visible += 1
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
            if red == 255 && green == 0 && blue == 255 {
                exactChroma += 1
            }
            if
                red >= 96,
                blue >= 96,
                red > green * 3 / 2,
                blue > green * 3 / 2
            {
                nearChroma += 1
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
            image.width - maximumX - 1,
            image.height - maximumY - 1,
        ]
        : []
    let passed =
        image.width == 1536
        && image.height == 1024
        && alphaMinimum == 0
        && alphaMaximum == 255
        && transparent > 0
        && visible > 0
        && hiddenRGB == 0
        && exactChroma == 0
        && nearChroma == 0
        && padding.count == 4
        && padding.allSatisfy { $0 > 2 }
    return [
        "dimensions": [image.width, image.height],
        "alphaRange": [alphaMinimum, alphaMaximum],
        "alphaBounds": bounds,
        "paddingPixels": padding,
        "transparentPixelCount": transparent,
        "nonTransparentPixelCount": visible,
        "hiddenRGBAtAlphaZeroPixelCount": hiddenRGB,
        "exactChromaAtNonzeroAlphaPixelCount": exactChroma,
        "nearChromaAtNonzeroAlphaPixelCount": nearChroma,
        "registrationPaddingPassed": padding.count == 4
            && padding.allSatisfy { $0 > 2 },
        "alphaChromaHiddenRGBPassed":
            alphaMinimum == 0
            && alphaMaximum == 255
            && hiddenRGB == 0
            && exactChroma == 0
            && nearChroma == 0,
        "sourceChecksPassed": passed,
    ]
}

@main
enum ValidateBlenderCalibrationRaw {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try required(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let output = URL(
            fileURLWithPath: try required("--output", in: arguments)
        ).standardizedFileURL
        let expectation = try required("--expect", in: arguments)
        guard expectation == "unique" || expectation == "identical" else {
            throw CalibrationValidationError.arguments
        }
        let sources = try repeated("--source", in: arguments)
        var records: [[String: Any]] = []
        var fileHashes: [String] = []
        var pixelHashes: [String] = []
        var allSourcesPassed = true
        for source in sources {
            let pieces = source.split(
                separator: "=",
                maxSplits: 1
            ).map(String.init)
            guard pieces.count == 2 else {
                throw CalibrationValidationError.arguments
            }
            let candidate = URL(fileURLWithPath: pieces[1])
            let url = (candidate.path.hasPrefix("/")
                ? candidate
                : root.appendingPathComponent(pieces[1])).standardizedFileURL
            let fileData = try Data(contentsOf: url)
            let image = try canonicalImage(url)
            let metrics = inspect(image)
            let fileHash = digest(fileData)
            let pixelHash = digest(image.rgba)
            fileHashes.append(fileHash)
            pixelHashes.append(pixelHash)
            allSourcesPassed =
                allSourcesPassed
                && (metrics["sourceChecksPassed"] as? Bool == true)
            records.append([
                "id": pieces[0],
                "file": relative(url, root: root),
                "fileSHA256": fileHash,
                "decodedPremultipliedRGBASHA256": pixelHash,
                "metrics": metrics,
            ])
        }
        let fileIdentity = Set(fileHashes).count == 1
        let pixelIdentity = Set(pixelHashes).count == 1
        // CONTRACT-020 R2 binds canonical decoded RGBA identity. PNG container
        // identity is retained as evidence but is not an acceptance condition.
        let identityPassed = expectation == "identical"
            ? pixelIdentity
            : Set(pixelHashes).count == pixelHashes.count
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contract": "CONTRACT-020",
            "tool": "task-owned Blender transparent-raw validator",
            "expectation": expectation,
            "sourceCount": records.count,
            "sources": records,
            "fileIdentity": fileIdentity,
            "fileIdentityRequired": false,
            "decodedRGBAIdentity": pixelIdentity,
            "identityExpectationPassed": identityPassed,
            "validationPassed": allSourcesPassed && identityPassed,
            "sourceAuthority": false,
            "productionSelected": false,
        ]
        let data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) + Data([0x0a])
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: output, options: .atomic)
        guard allSourcesPassed && identityPassed else {
            throw CalibrationValidationError.invalid(
                "Blender calibration raw validation failed"
            )
        }
    }
}
