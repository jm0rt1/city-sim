import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

private enum SummaryError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: summarize-industrial-l4-v18-foundation-repair --repository-root <path> --output <json>"
        case let .invalid(message):
            return message
        }
    }
}

private struct Raster {
    let width: Int
    let height: Int
    let rgba: [UInt8]
    let fileSHA256: String
    let decodedSHA256: String
}

private struct Bounds {
    var minimumX = Int.max
    var minimumY = Int.max
    var maximumX = Int.min
    var maximumY = Int.min

    mutating func include(x: Int, y: Int) {
        minimumX = min(minimumX, x)
        minimumY = min(minimumY, y)
        maximumX = max(maximumX, x)
        maximumY = max(maximumY, y)
    }

    var json: Any {
        minimumX == Int.max
            ? NSNull()
            : [minimumX, minimumY, maximumX, maximumY]
    }
}

private struct Group {
    let name: String
    let rgba: [Int]
}

private let groups = [
    Group(name: "portal-jamb-south", rgba: [16, 16, 240]),
    Group(name: "portal-jamb-north", rgba: [240, 208, 16]),
    Group(name: "portal-header", rgba: [240, 16, 16]),
    Group(name: "portal-inset-void", rgba: [16, 240, 48]),
    Group(name: "hall", rgba: [144, 80, 48]),
    Group(name: "gantry", rgba: [48, 80, 112]),
    Group(name: "crucible-occluder", rgba: [208, 112, 16]),
    Group(name: "other", rgba: [80, 80, 80]),
]

private let expectedPortalSource = [
    "portal-jamb-south": 155,
    "portal-jamb-north": 1_562,
    "portal-header": 1_275,
    "portal-inset-void": 3_388,
]
private let expectedPortalCompact = [
    "portal-jamb-south": 3,
    "portal-jamb-north": 21,
    "portal-header": 19,
    "portal-inset-void": 57,
]

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        index + 1 < CommandLine.arguments.count
    else {
        throw SummaryError.arguments
    }
    return CommandLine.arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func decode(_ url: URL) throws -> Raster {
    let data = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        )
    else {
        throw SummaryError.invalid("could not decode \(url.path)")
    }
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try rgba.withUnsafeMutableBytes { bytes in
        guard let context = CGContext(
            data: bytes.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw SummaryError.invalid("could not allocate decoder")
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return Raster(
        width: image.width,
        height: image.height,
        rgba: rgba,
        fileSHA256: digest(data),
        decodedSHA256: digest(Data(rgba))
    )
}

private func groupIndex(_ rgba: [UInt8], offset: Int) -> Int? {
    guard rgba[offset + 3] > 0 else { return nil }
    let red = Int(rgba[offset])
    let green = Int(rgba[offset + 1])
    let blue = Int(rgba[offset + 2])
    let chromaDistance =
        (red - 255) * (red - 255)
        + green * green
        + (blue - 255) * (blue - 255)
    var best = 0
    var bestDistance = Int.max
    for (index, group) in groups.enumerated() {
        let redDelta = red - group.rgba[0]
        let greenDelta = green - group.rgba[1]
        let blueDelta = blue - group.rgba[2]
        let distance =
            redDelta * redDelta
            + greenDelta * greenDelta
            + blueDelta * blueDelta
        if distance < bestDistance {
            best = index
            bestDistance = distance
        }
    }
    return bestDistance < chromaDistance ? best : nil
}

private func metrics(
    _ raster: Raster,
    samplingStride: Int
) -> [String: [String: Any]] {
    var counts = [Int](repeating: 0, count: groups.count)
    var bounds = [Bounds](repeating: Bounds(), count: groups.count)
    let outputWidth = raster.width / samplingStride
    let outputHeight = raster.height / samplingStride
    for y in 0..<outputHeight {
        for x in 0..<outputWidth {
            let sourceX = min(
                raster.width - 1,
                x * samplingStride + samplingStride / 2
            )
            let sourceY = min(
                raster.height - 1,
                y * samplingStride + samplingStride / 2
            )
            let offset = (sourceY * raster.width + sourceX) * 4
            guard let index = groupIndex(raster.rgba, offset: offset) else {
                continue
            }
            counts[index] += 1
            bounds[index].include(x: x, y: y)
        }
    }
    return Dictionary(
        uniqueKeysWithValues: groups.indices.map { index in
            (
                groups[index].name,
                [
                    "visiblePixelCount": counts[index],
                    "bounds": bounds[index].json,
                ]
            )
        }
    )
}

private func manifestSHA(_ url: URL) throws -> String {
    guard
        let root = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any],
        let semantic =
            root["diagnosticSemanticVisibility"] as? [String: Any],
        let value = semantic["nodeManifestSHA256"] as? String
    else {
        throw SummaryError.invalid("provenance manifest missing")
    }
    return value
}

private func portalMatches(
    _ metrics: [String: [String: Any]],
    expected: [String: Int]
) -> Bool {
    expected.allSatisfy { name, count in
        metrics[name]?["visiblePixelCount"] as? Int == count
    }
}

@main
private enum SummarizeRepair {
    static func main() throws {
        let root = URL(
            fileURLWithPath: try argument("--repository-root")
        ).standardizedFileURL
        let outputURL = URL(
            fileURLWithPath: try argument("--output")
        ).standardizedFileURL
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw SummaryError.invalid("output path must be absent")
        }
        let evidence = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
                + "duplicate-foundation-repair-r3-v01/diagnostics"
        )
        let runAURL = evidence.appendingPathComponent("run-a/semantic.png")
        let runBURL = evidence.appendingPathComponent("run-b/semantic.png")
        let provenanceA = evidence.appendingPathComponent(
            "run-a/provenance.json"
        )
        let provenanceB = evidence.appendingPathComponent(
            "run-b/provenance.json"
        )
        let runA = try decode(runAURL)
        let runB = try decode(runBURL)
        guard runA.width == runB.width, runA.height == runB.height else {
            throw SummaryError.invalid("dimensions differ")
        }
        var differingPixels = 0
        var differingChannels = 0
        var maximumDelta = 0
        var differenceBounds = Bounds()
        var firstDifference: [String: Any]?
        var transitions: [String: Int] = [:]
        for y in 0..<runA.height {
            for x in 0..<runA.width {
                let offset = (y * runA.width + x) * 4
                var differs = false
                for channel in 0..<4 {
                    let lhs = Int(runA.rgba[offset + channel])
                    let rhs = Int(runB.rgba[offset + channel])
                    if lhs != rhs {
                        differs = true
                        differingChannels += 1
                        maximumDelta = max(maximumDelta, abs(lhs - rhs))
                    }
                }
                guard differs else { continue }
                differingPixels += 1
                differenceBounds.include(x: x, y: y)
                let lhs = groupIndex(runA.rgba, offset: offset)
                    .map { groups[$0].name } ?? "chroma"
                let rhs = groupIndex(runB.rgba, offset: offset)
                    .map { groups[$0].name } ?? "chroma"
                transitions["\(lhs)->\(rhs)", default: 0] += 1
                if firstDifference == nil {
                    firstDifference = [
                        "coordinate": [x, y],
                        "runA": Array(runA.rgba[offset..<(offset + 4)]),
                        "runB": Array(runB.rgba[offset..<(offset + 4)]),
                    ]
                }
            }
        }
        let sourceA = metrics(runA, samplingStride: 1)
        let sourceB = metrics(runB, samplingStride: 1)
        let compactA = metrics(runA, samplingStride: 8)
        let compactB = metrics(runB, samplingStride: 8)
        let manifestA = try manifestSHA(provenanceA)
        let manifestB = try manifestSHA(provenanceB)
        let portalUnchanged =
            portalMatches(sourceA, expected: expectedPortalSource)
            && portalMatches(sourceB, expected: expectedPortalSource)
            && portalMatches(compactA, expected: expectedPortalCompact)
            && portalMatches(compactB, expected: expectedPortalCompact)
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contract": "CONTRACT-019-R3",
            "disposition": differingPixels == 0
                ? "PASS_REPEAT_IDENTITY"
                : "RETURN_REMAINING_REPEAT_SPLIT",
            "diagnosticOnly": true,
            "sourceAuthority": false,
            "productionSelected": false,
            "processCounts": [
                "sceneKitMetalSemantic": 2,
                "authoritativeRaw": 0,
                "normalizer": 0,
                "siblings": 0,
            ],
            "runs": [
                "runA": [
                    "fileSHA256": runA.fileSHA256,
                    "decodedRGBASHA256": runA.decodedSHA256,
                    "nodeManifestSHA256": manifestA,
                ],
                "runB": [
                    "fileSHA256": runB.fileSHA256,
                    "decodedRGBASHA256": runB.decodedSHA256,
                    "nodeManifestSHA256": manifestB,
                ],
            ],
            "repeatIdentity": [
                "fileIdentity": runA.fileSHA256 == runB.fileSHA256,
                "decodedRGBAIdentity":
                    runA.decodedSHA256 == runB.decodedSHA256,
                "manifestIdentity": manifestA == manifestB,
                "differingPixelCount": differingPixels,
                "differingChannelCount": differingChannels,
                "maximumChannelDelta": maximumDelta,
                "differenceBounds": differenceBounds.json,
                "firstDifference": firstDifference ?? NSNull(),
                "semanticTransitions": transitions.keys.sorted().map {
                    [
                        "transition": $0,
                        "pixelCount": transitions[$0] ?? 0,
                    ]
                },
            ],
            "portalCounts": [
                "expectedSource": expectedPortalSource,
                "expectedLiteral192": expectedPortalCompact,
                "runASource": sourceA,
                "runBSource": sourceB,
                "runALiteral192": compactA,
                "runBLiteral192": compactB,
                "unchangedFromV17Return": portalUnchanged,
            ],
            "stopReason": differingPixels == 0
                ? "Repeat identity passed; portal modeling remains blocked pending independent review."
                : "A/B split remains after duplicate-foundation removal; no further process or modeling is authorized.",
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        try data.write(to: outputURL, options: .atomic)
        print(
            differingPixels == 0
                ? "PASS semantic repeat identity"
                : "RETURN semantic split: \(differingPixels) pixels"
        )
        print("portal-counts-unchanged=\(portalUnchanged)")
    }
}
