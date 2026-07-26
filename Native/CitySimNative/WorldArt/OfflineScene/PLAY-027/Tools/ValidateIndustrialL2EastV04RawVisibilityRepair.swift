import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

enum IndustrialL2V04VisibilityRepairError: Error {
    case invalid(String)
}

struct VisibilityRepairRaster {
    let width: Int
    let height: Int
    let rgba: [UInt8]
}

struct VisibilityRepairBounds {
    var minimumX = Int.max
    var minimumY = Int.max
    var maximumX = Int.min
    var maximumY = Int.min
    var count = 0

    mutating func include(x: Int, y: Int) {
        minimumX = min(minimumX, x)
        minimumY = min(minimumY, y)
        maximumX = max(maximumX, x)
        maximumY = max(maximumY, y)
        count += 1
    }

    var record: [String: Any] {
        [
            "minimum": [minimumX, minimumY],
            "maximum": [maximumX, maximumY],
            "width": maximumX - minimumX + 1,
            "height": maximumY - minimumY + 1,
            "pixelCount": count,
        ]
    }
}

func visibilityRepairSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func visibilityRepairArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2V04VisibilityRepairError.invalid(
            "missing \(name)"
        )
    }
    return arguments[index + 1]
}

func loadVisibilityRepairRaster(
    _ url: URL
) throws -> VisibilityRepairRaster {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw IndustrialL2V04VisibilityRepairError.invalid(
            "could not decode \(url.path)"
        )
    }
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let rendered = rgba.withUnsafeMutableBytes { storage -> Bool in
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
        throw IndustrialL2V04VisibilityRepairError.invalid(
            "could not canonicalize \(url.path)"
        )
    }
    return VisibilityRepairRaster(
        width: image.width,
        height: image.height,
        rgba: rgba
    )
}

@main
enum ValidateIndustrialL2EastV04RawVisibilityRepairMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let rawURL = URL(
            fileURLWithPath:
                try visibilityRepairArgument("--raw", in: arguments)
        )
        let alphaURL = URL(
            fileURLWithPath:
                try visibilityRepairArgument("--alpha", in: arguments)
        )
        let oldMetricsURL = URL(
            fileURLWithPath:
                try visibilityRepairArgument("--old-metrics", in: arguments)
        )
        let rejectionURL = URL(
            fileURLWithPath:
                try visibilityRepairArgument("--rejection", in: arguments)
        )
        let outputURL = URL(
            fileURLWithPath:
                try visibilityRepairArgument("--output", in: arguments)
        )
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw IndustrialL2V04VisibilityRepairError.invalid(
                "output must be absent"
            )
        }

        let rawData = try Data(contentsOf: rawURL)
        let alphaData = try Data(contentsOf: alphaURL)
        let metricsData = try Data(contentsOf: oldMetricsURL)
        let rejectionData = try Data(contentsOf: rejectionURL)
        let raw = try loadVisibilityRepairRaster(rawURL)
        let alpha = try loadVisibilityRepairRaster(alphaURL)
        guard
            raw.width == 1536,
            raw.height == 1024,
            alpha.width == raw.width,
            alpha.height == raw.height,
            visibilityRepairSHA256(rawData)
                == "41ba5f09159534438e1a89fc25cf28ccb99ea48bc09d9c3bba80f03f14403072",
            visibilityRepairSHA256(alphaData)
                == "94a4323fe8a6a5da7009a7c0c12b52c4350fe19a3cd5b23d00fd51992a2b35bf",
            visibilityRepairSHA256(metricsData)
                == "83b0b403efcac6b9d8794a036dd69da470acd3d399b5a3a3a7a76bab47fb27b3",
            visibilityRepairSHA256(rejectionData)
                == "791a6effab74ca6ff7abedd250908ccf752c22db521b315c3e20100e01b325d3"
        else {
            throw IndustrialL2V04VisibilityRepairError.invalid(
                "retained v04 evidence drift"
            )
        }

        var rawNonChromaBounds = VisibilityRepairBounds()
        var alphaGreaterThanZeroBounds = VisibilityRepairBounds()
        var alphaGreaterThanEightBounds = VisibilityRepairBounds()
        var lowAlphaEdgeBounds = VisibilityRepairBounds()
        var supportMismatchCount = 0
        for y in 0..<raw.height {
            for x in 0..<raw.width {
                let offset = (y * raw.width + x) * 4
                let exactChroma =
                    raw.rgba[offset] == 255
                    && raw.rgba[offset + 1] == 0
                    && raw.rgba[offset + 2] == 255
                    && raw.rgba[offset + 3] == 255
                let rawVisible = !exactChroma
                let alphaValue = alpha.rgba[offset + 3]
                let alphaVisible = alphaValue > 0
                if rawVisible {
                    rawNonChromaBounds.include(x: x, y: y)
                }
                if alphaVisible {
                    alphaGreaterThanZeroBounds.include(x: x, y: y)
                }
                if alphaValue > 8 {
                    alphaGreaterThanEightBounds.include(x: x, y: y)
                }
                if alphaValue >= 1 && alphaValue <= 8 {
                    lowAlphaEdgeBounds.include(x: x, y: y)
                }
                if rawVisible != alphaVisible {
                    supportMismatchCount += 1
                }
            }
        }

        let countDelta =
            rawNonChromaBounds.count - alphaGreaterThanEightBounds.count
        let passed =
            rawNonChromaBounds.count == 146_141
            && alphaGreaterThanZeroBounds.count == 146_141
            && alphaGreaterThanEightBounds.count == 141_318
            && lowAlphaEdgeBounds.count == 4_823
            && countDelta == lowAlphaEdgeBounds.count
            && supportMismatchCount == 0
            && rawNonChromaBounds.minimumX
                == alphaGreaterThanZeroBounds.minimumX
            && rawNonChromaBounds.minimumY
                == alphaGreaterThanZeroBounds.minimumY
            && rawNonChromaBounds.maximumX
                == alphaGreaterThanZeroBounds.maximumX
            && rawNonChromaBounds.maximumY
                == alphaGreaterThanZeroBounds.maximumY

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v04-raw-visibility-validator-repair",
            "passed": passed,
            "comparisonContract":
                "raw non-chroma support equals genuine pre-chroma alpha greater than zero support",
            "rawFileSHA256": visibilityRepairSHA256(rawData),
            "alphaFileSHA256": visibilityRepairSHA256(alphaData),
            "preservedOldMetricsSHA256":
                visibilityRepairSHA256(metricsData),
            "preservedRejectionSHA256":
                visibilityRepairSHA256(rejectionData),
            "rawNonChromaSupport": rawNonChromaBounds.record,
            "alphaGreaterThanZeroSupport":
                alphaGreaterThanZeroBounds.record,
            "alphaGreaterThanEightLegacySupport":
                alphaGreaterThanEightBounds.record,
            "alphaOneThroughEightEdgeSupport":
                lowAlphaEdgeBounds.record,
            "legacyCountShortfall": countDelta,
            "supportMismatchPixelCount": supportMismatchCount,
            "causalConclusion":
                "4,823 alpha 1-8 edge pixels were excluded by the prior alpha>8 support predicate and exactly explain the retained bounds/count mismatch",
            "priorRejectionPreserved": true,
            "automaticReclassification": false,
            "sceneKitMetalProcessCount": 0,
            "productionSelected": false,
        ]
        var outputData = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        outputData.append(0x0a)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try outputData.write(to: outputURL, options: .atomic)
        guard passed else {
            throw IndustrialL2V04VisibilityRepairError.invalid(
                "visibility repair proof failed"
            )
        }
        print("PASS raw=146141 alpha>0=146141 edge=4823 mismatch=0")
    }
}
