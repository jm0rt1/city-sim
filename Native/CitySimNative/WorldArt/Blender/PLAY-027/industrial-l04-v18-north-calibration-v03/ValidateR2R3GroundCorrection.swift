import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

enum GroundCorrectionError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-r2-r3-ground-correction --r2 <png> --r3 <png> --output <json>"
        case let .invalid(message):
            return message
        }
    }
}

struct Raster {
    let width: Int
    let height: Int
    let rgba: [UInt8]
}

func argument(_ name: String) throws -> String {
    let values = Array(CommandLine.arguments.dropFirst())
    guard let index = values.firstIndex(of: name), index + 1 < values.count else {
        throw GroundCorrectionError.arguments
    }
    return values[index + 1]
}

func decode(_ path: String) throws -> Raster {
    let url = URL(fileURLWithPath: path)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw GroundCorrectionError.invalid("could not decode \(path)")
    }
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let rendered = bytes.withUnsafeMutableBytes { storage -> Bool in
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
            return false
        }
        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
        return true
    }
    guard rendered else {
        throw GroundCorrectionError.invalid("could not canonicalize \(path)")
    }
    return Raster(width: image.width, height: image.height, rgba: bytes)
}

func digest(_ bytes: [UInt8]) -> String {
    SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
}

func bounds(_ raster: Raster) -> [Int] {
    var minimumX = raster.width
    var minimumY = raster.height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<raster.height {
        for x in 0..<raster.width {
            let alpha = raster.rgba[(y * raster.width + x) * 4 + 3]
            guard alpha > 0 else { continue }
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    return maximumX >= 0
        ? [minimumX, minimumY, maximumX + 1, maximumY + 1]
        : []
}

@main
enum ValidateR2R3GroundCorrection {
    static func main() throws {
        let r2Path = try argument("--r2")
        let r3Path = try argument("--r3")
        let outputPath = try argument("--output")
        let r2 = try decode(r2Path)
        let r3 = try decode(r3Path)
        guard r2.width == r3.width, r2.height == r3.height else {
            throw GroundCorrectionError.invalid("dimension mismatch")
        }
        let correctionY = -64
        var differingPixels = 0
        var differingChannels = 0
        for y in 0..<r3.height {
            let r2Y = y - correctionY
            for x in 0..<r3.width {
                let r3Offset = (y * r3.width + x) * 4
                var pixelDiffers = false
                for channel in 0..<4 {
                    let expected: UInt8
                    if r2Y >= 0, r2Y < r2.height {
                        expected = r2.rgba[(r2Y * r2.width + x) * 4 + channel]
                    } else {
                        expected = 0
                    }
                    if r3.rgba[r3Offset + channel] != expected {
                        differingChannels += 1
                        pixelDiffers = true
                    }
                }
                if pixelDiffers {
                    differingPixels += 1
                }
            }
        }
        let r2Bounds = bounds(r2)
        let r3Bounds = bounds(r3)
        let expectedR3Bounds = [
            r2Bounds[0],
            r2Bounds[1] + correctionY,
            r2Bounds[2],
            r2Bounds[3] + correctionY,
        ]
        let boundsError = zip(r3Bounds, expectedR3Bounds).map {
            abs($0.0 - $0.1)
        }
        let passed =
            r3Bounds[1] - r2Bounds[1] == correctionY
            && boundsError.allSatisfy { $0 <= 1 }
        guard passed else {
            throw GroundCorrectionError.invalid(
                "R2-to-R3 correction drift: pixels=\(differingPixels) channels=\(differingChannels) r2=\(r2Bounds) r3=\(r3Bounds)"
            )
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contract": "CONTRACT-020-R3",
            "validationPassed": true,
            "r2File": r2Path,
            "r3File": r3Path,
            "r2DecodedPremultipliedRGBASHA256": digest(r2.rgba),
            "r3DecodedPremultipliedRGBASHA256": digest(r3.rgba),
            "r2OccupiedBounds": r2Bounds,
            "r3OccupiedBounds": r3Bounds,
            "expectedR3OccupiedBounds": expectedR3Bounds,
            "occupiedBoundsAbsoluteError": boundsError,
            "groundCorrectionSourcePixels": [0, correctionY],
            "nonTranslationDifferingPixelCount": differingPixels,
            "nonTranslationDifferingChannelCount": differingChannels,
            "pixelPayloadOtherwiseIdentical": differingChannels == 0,
            "subpixelResamplingDifferenceRetained": differingChannels > 0,
            "otherRenderedInputDriftCheckedBy": [
                "prepixel/VALIDATION.json",
                "prepixel/R2-R3-CONTRACT-DIFF.json",
            ],
            "sourceAuthority": false,
            "productionSelected": false,
        ]
        let data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys]
        )
        let output = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: output)
        try Data([0x0A]).append(to: output)
    }
}

private extension Data {
    func append(to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: self)
    }
}
