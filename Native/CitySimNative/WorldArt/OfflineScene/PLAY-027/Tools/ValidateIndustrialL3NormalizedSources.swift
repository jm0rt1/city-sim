import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

enum IndustrialL3NormalizedValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l3-normalized-sources --asset-id <id> --run-a <directory> --run-b <directory> --output <json>"
        case let .invalid(message):
            return message
        }
    }
}

struct IndustrialL3NormalizedRaster {
    let fileSHA256: String
    let decodedRGBASHA256: String
    let width: Int
    let height: Int
    let alphaBounds: [Int]
    let visiblePixelCount: Int
    let hiddenRGBPixelCount: Int
    let exactChromaPixelCount: Int
    let visibleMagentaSpillPixelCount: Int
}

func l3NormalizedArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3NormalizedValidationError.arguments
    }
    return arguments[index + 1]
}

func l3NormalizedDigest(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func l3NormalizedInspect(_ url: URL) throws -> IndustrialL3NormalizedRaster {
    let fileData = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    else {
        throw IndustrialL3NormalizedValidationError.invalid(
            "ImageIO decode failed: \(url.path)"
        )
    }
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try rgba.withUnsafeMutableBytes { storage in
        guard let context = CGContext(
            data: storage.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw IndustrialL3NormalizedValidationError.invalid(
                "RGBA context allocation failed: \(url.path)"
            )
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }

    var minimumX = image.width
    var minimumY = image.height
    var maximumX = -1
    var maximumY = -1
    var visiblePixelCount = 0
    var hiddenRGBPixelCount = 0
    var exactChromaPixelCount = 0
    var visibleMagentaSpillPixelCount = 0
    for y in 0..<image.height {
        for x in 0..<image.width {
            let offset = (y * image.width + x) * 4
            let red = Int(rgba[offset])
            let green = Int(rgba[offset + 1])
            let blue = Int(rgba[offset + 2])
            let alpha = Int(rgba[offset + 3])
            if alpha == 0 {
                if red != 0 || green != 0 || blue != 0 {
                    hiddenRGBPixelCount += 1
                }
                continue
            }
            visiblePixelCount += 1
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
            if red == 255 && green == 0 && blue == 255 {
                exactChromaPixelCount += 1
            }
            if
                red >= 180,
                blue >= 150,
                green <= 110,
                red + blue >= green * 4
            {
                visibleMagentaSpillPixelCount += 1
            }
        }
    }
    guard maximumX >= minimumX, maximumY >= minimumY else {
        throw IndustrialL3NormalizedValidationError.invalid(
            "normalized image contains no visible pixels: \(url.path)"
        )
    }
    return IndustrialL3NormalizedRaster(
        fileSHA256: l3NormalizedDigest(fileData),
        decodedRGBASHA256: l3NormalizedDigest(Data(rgba)),
        width: image.width,
        height: image.height,
        alphaBounds: [minimumX, minimumY, maximumX + 1, maximumY + 1],
        visiblePixelCount: visiblePixelCount,
        hiddenRGBPixelCount: hiddenRGBPixelCount,
        exactChromaPixelCount: exactChromaPixelCount,
        visibleMagentaSpillPixelCount: visibleMagentaSpillPixelCount
    )
}

@main
enum ValidateIndustrialL3NormalizedSourcesMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let assetID = try l3NormalizedArgument("--asset-id", in: arguments)
        let runA = URL(
            fileURLWithPath: try l3NormalizedArgument("--run-a", in: arguments)
        ).standardizedFileURL
        let runB = URL(
            fileURLWithPath: try l3NormalizedArgument("--run-b", in: arguments)
        ).standardizedFileURL
        let output = URL(
            fileURLWithPath: try l3NormalizedArgument("--output", in: arguments)
        ).standardizedFileURL
        let lods = [
            ("block", [1024, 683]),
            ("neighborhood", [512, 342]),
            ("city", [256, 171]),
        ]
        var records: [[String: Any]] = []
        var uniqueFiles = Set<String>()
        var uniquePixels = Set<String>()
        var allPassed = true
        for (lod, expectedPixels) in lods {
            let filename = "generated_v4_\(assetID)_\(lod).png"
            let rasterA = try l3NormalizedInspect(
                runA.appendingPathComponent(filename)
            )
            let rasterB = try l3NormalizedInspect(
                runB.appendingPathComponent(filename)
            )
            let repeatIdentity =
                rasterA.fileSHA256 == rasterB.fileSHA256
                && rasterA.decodedRGBASHA256 == rasterB.decodedRGBASHA256
            let paddingPassed =
                rasterA.alphaBounds[0] > 2
                && rasterA.alphaBounds[1] > 2
                && rasterA.alphaBounds[2] < rasterA.width - 2
                && rasterA.alphaBounds[3] < rasterA.height - 2
            let dimensionsPassed =
                rasterA.width == expectedPixels[0]
                && rasterA.height == expectedPixels[1]
            let cleanlinessPassed =
                rasterA.hiddenRGBPixelCount == 0
                && rasterA.exactChromaPixelCount == 0
                && rasterA.visibleMagentaSpillPixelCount == 0
            let passed =
                repeatIdentity
                && dimensionsPassed
                && paddingPassed
                && cleanlinessPassed
                && rasterA.alphaBounds == rasterB.alphaBounds
                && rasterA.visiblePixelCount == rasterB.visiblePixelCount
            allPassed = allPassed && passed
            uniqueFiles.insert(rasterA.fileSHA256)
            uniquePixels.insert(rasterA.decodedRGBASHA256)
            records.append([
                "lod": lod,
                "pixels": [rasterA.width, rasterA.height],
                "fileSHA256": rasterA.fileSHA256,
                "decodedRGBASHA256": rasterA.decodedRGBASHA256,
                "alphaBounds": rasterA.alphaBounds,
                "visiblePixelCount": rasterA.visiblePixelCount,
                "hiddenRGBPixelCount": rasterA.hiddenRGBPixelCount,
                "exactChromaPixelCount": rasterA.exactChromaPixelCount,
                "visibleMagentaSpillPixelCount":
                    rasterA.visibleMagentaSpillPixelCount,
                "repeatFileIdentity": rasterA.fileSHA256 == rasterB.fileSHA256,
                "repeatDecodedPixelIdentity":
                    rasterA.decodedRGBASHA256 == rasterB.decodedRGBASHA256,
                "dimensionsPassed": dimensionsPassed,
                "paddingPassed": paddingPassed,
                "cleanlinessPassed": cleanlinessPassed,
                "validationPassed": passed,
            ])
        }
        let uniquenessPassed =
            uniqueFiles.count == lods.count
            && uniquePixels.count == lods.count
        allPassed = allPassed && uniquenessPassed
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "family": "industrial_l03",
            "assetID": assetID,
            "productionSelected": false,
            "sourceAuthority": false,
            "lods": records,
            "repeatIdentityPassed": records.allSatisfy {
                $0["validationPassed"] as? Bool == true
            },
            "uniqueLODFileIdentityCount": uniqueFiles.count,
            "uniqueLODDecodedPixelIdentityCount": uniquePixels.count,
            "uniqueLODIdentityPassed": uniquenessPassed,
            "validationPassed": allPassed,
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: output, options: .atomic)
        if !allPassed {
            throw IndustrialL3NormalizedValidationError.invalid(
                "Industrial L3 normalized source validation failed"
            )
        }
    }
}
