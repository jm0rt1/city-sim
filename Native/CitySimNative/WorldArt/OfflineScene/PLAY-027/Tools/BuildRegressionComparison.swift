import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum RegressionComparisonError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-regression-comparison --repository-root <path> --comparison-id <id> --baseline <png> --candidate <png> --output <png> --record <json>"
        case let .invalid(message):
            return message
        }
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
        throw RegressionComparisonError.arguments
    }
    return arguments[index + 1]
}

func comparisonImage(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        )
    else {
        throw RegressionComparisonError.invalid(
            "could not decode \(url.path)"
        )
    }
    return image
}

func comparisonSHA256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map {
        String(format: "%02x", $0)
    }.joined()
}

func comparisonRelativePath(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func writeComparisonPNG(
    baseline: CGImage,
    candidate: CGImage,
    to outputURL: URL
) throws {
    let gutter = 16
    let width = baseline.width + gutter + candidate.width
    let height = max(baseline.height, candidate.height)
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
        throw RegressionComparisonError.invalid(
            "could not create comparison canvas"
        )
    }
    context.setFillColor(
        CGColor(
            colorSpace: colorSpace,
            components: [0.08, 0.09, 0.10, 1.0]
        )!
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .none
    context.draw(
        baseline,
        in: CGRect(
            x: 0,
            y: height - baseline.height,
            width: baseline.width,
            height: baseline.height
        )
    )
    context.draw(
        candidate,
        in: CGRect(
            x: baseline.width + gutter,
            y: height - candidate.height,
            width: candidate.width,
            height: candidate.height
        )
    )
    guard
        let output = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw RegressionComparisonError.invalid(
            "could not create comparison output"
        )
    }
    CGImageDestinationAddImage(destination, output, [
        kCGImagePropertyPNGInterlaceType: 0,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw RegressionComparisonError.invalid(
            "could not finalize comparison output"
        )
    }
}

@main
enum BuildRegressionComparisonMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try comparisonArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let comparisonID = try comparisonArgument(
            "--comparison-id",
            in: arguments
        )
        let baselineURL = URL(
            fileURLWithPath: try comparisonArgument(
                "--baseline",
                in: arguments
            )
        ).standardizedFileURL
        let candidateURL = URL(
            fileURLWithPath: try comparisonArgument(
                "--candidate",
                in: arguments
            )
        ).standardizedFileURL
        let outputURL = URL(
            fileURLWithPath: try comparisonArgument(
                "--output",
                in: arguments
            )
        ).standardizedFileURL
        let recordURL = URL(
            fileURLWithPath: try comparisonArgument(
                "--record",
                in: arguments
            )
        ).standardizedFileURL
        guard
            outputURL.path.contains("/diagnostics/"),
            recordURL.path.contains("/diagnostics/")
        else {
            throw RegressionComparisonError.invalid(
                "comparison outputs must remain under diagnostics"
            )
        }

        let baseline = try comparisonImage(baselineURL)
        let candidate = try comparisonImage(candidateURL)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writeComparisonPNG(
            baseline: baseline,
            candidate: candidate,
            to: outputURL
        )

        let record: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "comparisonID": comparisonID,
            "layout": [
                "order": ["accepted-schema-1", "candidate-schema-2-v3"],
                "orientation": "left-to-right",
                "gutterPixels": 16,
                "interpolation": "none",
            ],
            "baseline": [
                "file": comparisonRelativePath(
                    baselineURL,
                    repositoryRoot: repositoryRoot
                ),
                "sha256": try comparisonSHA256(baselineURL),
                "pixels": [baseline.width, baseline.height],
            ],
            "candidate": [
                "file": comparisonRelativePath(
                    candidateURL,
                    repositoryRoot: repositoryRoot
                ),
                "sha256": try comparisonSHA256(candidateURL),
                "pixels": [candidate.width, candidate.height],
            ],
            "comparison": [
                "file": comparisonRelativePath(
                    outputURL,
                    repositoryRoot: repositoryRoot
                ),
                "sha256": try comparisonSHA256(outputURL),
                "pixels": [
                    baseline.width + 16 + candidate.width,
                    max(baseline.height, candidate.height),
                ],
            ],
            "productionSelected": false,
        ]
        var data = try JSONSerialization.data(
            withJSONObject: record,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        try data.write(to: recordURL, options: .atomic)
    }
}
