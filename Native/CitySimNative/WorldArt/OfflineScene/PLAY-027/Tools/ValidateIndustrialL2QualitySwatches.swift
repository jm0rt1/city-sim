import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

enum SwatchValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l2-quality-swatches --root <directory> --output <json>"
        case let .invalid(message):
            return message
        }
    }
}

struct PixelBuffer {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    func rgb(x: Int, y: Int) -> [UInt8] {
        let offset = (y * width + x) * 4
        return Array(bytes[offset..<(offset + 3)])
    }
}

func argument(_ name: String, in arguments: [String]) throws -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        throw SwatchValidationError.arguments
    }
    return arguments[index + 1]
}

func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func decode(_ url: URL) throws -> PixelBuffer {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw SwatchValidationError.invalid("cannot decode \(url.path)")
    }
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard
        let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else {
        throw SwatchValidationError.invalid("cannot create RGBA context")
    }
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return PixelBuffer(width: width, height: height, bytes: bytes)
}

func edgeMetrics(_ buffer: PixelBuffer, axis: String) -> [String: Any] {
    var deltas: [Int] = []
    let sampleCount = axis == "horizontal" ? buffer.height : buffer.width
    for sample in 0..<sampleCount {
        let first = axis == "horizontal"
            ? buffer.rgb(x: 0, y: sample)
            : buffer.rgb(x: sample, y: 0)
        let last = axis == "horizontal"
            ? buffer.rgb(x: buffer.width - 1, y: sample)
            : buffer.rgb(x: sample, y: buffer.height - 1)
        for channel in 0..<3 {
            deltas.append(abs(Int(first[channel]) - Int(last[channel])))
        }
    }
    let sorted = deltas.sorted()
    let mean = Double(deltas.reduce(0, +)) / Double(max(1, deltas.count))
    let percentileIndex = min(
        sorted.count - 1,
        Int((Double(sorted.count - 1) * 0.95).rounded(.up))
    )
    return [
        "meanAbsoluteChannelDelta": mean,
        "p95AbsoluteChannelDelta": sorted[percentileIndex],
        "maximumAbsoluteChannelDelta": sorted.last ?? 0,
        "sampledChannelValues": deltas.count,
    ]
}

@main
enum ValidateIndustrialL2QualitySwatches {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try argument("--root", in: arguments),
            isDirectory: true
        ).standardizedFileURL
        let output = URL(fileURLWithPath: try argument("--output", in: arguments))
            .standardizedFileURL
        let names = [
            "aged-cast-concrete",
            "blue-gray-painted-steel",
            "dark-roof-membrane",
            "galvanized-corrugated-steel",
        ]
        var entries: [[String: Any]] = []
        for name in names {
            let url = root.appendingPathComponent("\(name).png")
            let data = try Data(contentsOf: url)
            let buffer = try decode(url)
            guard buffer.width == 512, buffer.height == 512 else {
                throw SwatchValidationError.invalid("\(name) is not 512x512")
            }
            let horizontal = edgeMetrics(buffer, axis: "horizontal")
            let vertical = edgeMetrics(buffer, axis: "vertical")
            let horizontalMean = horizontal["meanAbsoluteChannelDelta"] as! Double
            let verticalMean = vertical["meanAbsoluteChannelDelta"] as! Double
            let horizontalP95 = horizontal["p95AbsoluteChannelDelta"] as! Int
            let verticalP95 = vertical["p95AbsoluteChannelDelta"] as! Int
            let seamlessPass =
                horizontalMean <= 18
                && verticalMean <= 18
                && horizontalP95 <= 48
                && verticalP95 <= 48
            entries.append([
                "id": name,
                "file": url.path,
                "sha256": sha256(data),
                "width": buffer.width,
                "height": buffer.height,
                "horizontalWrap": horizontal,
                "verticalWrap": vertical,
                "seamlessBoundary": [
                    "maximumMeanAbsoluteChannelDelta": 18,
                    "maximumP95AbsoluteChannelDelta": 48,
                ],
                "seamlessPass": seamlessPass,
                "disposition": seamlessPass
                    ? "accepted-for-prepixel-material-reference"
                    : "rejected-for-direct-tiling-retained-for-provenance",
            ])
        }
        let object: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "purpose": "non-compositional ImageGen material swatch validation",
            "normalization": [
                "tool": "/usr/bin/sips",
                "operation": "--resampleHeightWidth 512 512",
                "colorSpace": "sRGB decode",
            ],
            "entries": entries,
            "allAccepted": entries.allSatisfy { $0["seamlessPass"] as! Bool },
        ]
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: output, options: .atomic)
    }
}
