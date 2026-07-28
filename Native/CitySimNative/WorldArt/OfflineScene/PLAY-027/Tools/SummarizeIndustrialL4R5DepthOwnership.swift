import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

private enum R5SummaryError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: summarize-industrial-l4-r5-depth-ownership --repository-root <path> --output <json>"
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

    var value: Any {
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
private let expectedSource = [
    "portal-header": 1_275,
    "portal-jamb-north": 1_562,
    "portal-inset-void": 3_388,
    "portal-jamb-south": 155,
]
private let expectedCompact = [
    "portal-header": 19,
    "portal-jamb-north": 21,
    "portal-inset-void": 57,
    "portal-jamb-south": 3,
]
private let canonicalDecodedSHA =
    "dab941daf6be1539218ee030cd8ddd32474b1296eaef0268d84c54301fe37925"
private let expectedManifestSHA =
    "611d60db7d39c9c0de73d1042f658c08e18c2d26bf4be9b7af3c6f577593a94f"
private let support = [711, 612, 840, 702]
private let targetNames = Set([
    "v17-monumental-portal-header-wall",
    "v17-monumental-portal-lintel",
])

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        index + 1 < CommandLine.arguments.count
    else {
        throw R5SummaryError.arguments
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
        throw R5SummaryError.invalid("could not decode \(url.path)")
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
            throw R5SummaryError.invalid("could not allocate decoder")
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

private func groupIndex(_ raster: Raster, offset: Int) -> Int? {
    guard raster.rgba[offset + 3] > 0 else { return nil }
    let red = Int(raster.rgba[offset])
    let green = Int(raster.rgba[offset + 1])
    let blue = Int(raster.rgba[offset + 2])
    let chromaDistance =
        (red - 255) * (red - 255)
        + green * green
        + (blue - 255) * (blue - 255)
    var bestIndex = 0
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
            bestIndex = index
            bestDistance = distance
        }
    }
    return bestDistance < chromaDistance ? bestIndex : nil
}

private func metrics(
    _ raster: Raster,
    stride: Int
) -> [String: [String: Any]] {
    var counts = [Int](repeating: 0, count: groups.count)
    var bounds = [Bounds](repeating: Bounds(), count: groups.count)
    for y in 0..<(raster.height / stride) {
        for x in 0..<(raster.width / stride) {
            let sourceX = x * stride + stride / 2
            let sourceY = y * stride + stride / 2
            let offset = (sourceY * raster.width + sourceX) * 4
            guard let index = groupIndex(raster, offset: offset) else {
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
                    "bounds": bounds[index].value,
                ]
            )
        }
    )
}

private func provenanceRecord(_ url: URL) throws -> [String: Any] {
    guard
        let root = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any],
        let semantic =
            root["diagnosticSemanticVisibility"] as? [String: Any],
        let contract = semantic["contract"] as? [String: Any],
        let manifest = semantic["nodeManifestSHA256"] as? String,
        let actual =
            semantic["r5ActualDepthOwnership"] as? [String: Any],
        let semanticBias =
            semantic["r5SemanticDepthOwnership"] as? [String: Any]
    else {
        throw R5SummaryError.invalid("R5 provenance record missing")
    }
    func names(_ record: [String: Any]) -> Set<String> {
        let nodes = record["nodes"] as? [[String: Any]] ?? []
        return Set(nodes.compactMap { $0["nodeName"] as? String })
    }
    return [
        "fileSHA256": digest(try Data(contentsOf: url)),
        "contractID": contract["contractID"] as? String ?? "",
        "nodeManifestSHA256": manifest,
        "nodeCount": semantic["nodeCount"] as? Int ?? -1,
        "actualTargetNodeNames": names(actual).sorted(),
        "semanticTargetNodeNames": names(semanticBias).sorted(),
        "actualScopeExact": names(actual) == targetNames,
        "semanticScopeExact": names(semanticBias) == targetNames,
        "actualBias": actual["worldDepthBias"] as? NSNumber ?? -1,
        "semanticBias": semanticBias["worldDepthBias"] as? NSNumber ?? -1,
    ]
}

private func matches(
    _ metrics: [String: [String: Any]],
    expected: [String: Int]
) -> Bool {
    expected.allSatisfy { key, value in
        metrics[key]?["visiblePixelCount"] as? Int == value
    }
}

private func comparison(
    _ lhs: Raster,
    _ rhs: Raster
) throws -> [String: Any] {
    guard lhs.width == rhs.width, lhs.height == rhs.height else {
        throw R5SummaryError.invalid("comparison dimensions differ")
    }
    var pixelCount = 0
    var channelCount = 0
    var outsideSupport = 0
    var bounds = Bounds()
    for y in 0..<lhs.height {
        for x in 0..<lhs.width {
            let offset = (y * lhs.width + x) * 4
            var differs = false
            for channel in 0..<4 where
                lhs.rgba[offset + channel] != rhs.rgba[offset + channel]
            {
                differs = true
                channelCount += 1
            }
            guard differs else { continue }
            pixelCount += 1
            bounds.include(x: x, y: y)
            if
                x < support[0] || y < support[1]
                    || x > support[2] || y > support[3]
            {
                outsideSupport += 1
            }
        }
    }
    return [
        "differingPixelCount": pixelCount,
        "differingChannelCount": channelCount,
        "differenceBounds": bounds.value,
        "differingPixelsOutsideTargetSupport": outsideSupport,
    ]
}

@main
private enum SummarizeR5DepthOwnership {
    static func main() throws {
        let root = URL(
            fileURLWithPath: try argument("--repository-root")
        ).standardizedFileURL
        let outputURL = URL(
            fileURLWithPath: try argument("--output")
        ).standardizedFileURL
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw R5SummaryError.invalid("output path must be absent")
        }
        let evidence = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
                + "portal-joint-depth-ownership-r5-v01/diagnostics"
        )
        let r3AURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
                + "duplicate-foundation-repair-r3-v01/diagnostics/"
                + "run-a/semantic.png"
        )
        let runA = try decode(
            evidence.appendingPathComponent("run-a/semantic.png")
        )
        let runB = try decode(
            evidence.appendingPathComponent("run-b/semantic.png")
        )
        let canonical = try decode(r3AURL)
        let provenanceA = try provenanceRecord(
            evidence.appendingPathComponent("run-a/provenance.json")
        )
        let provenanceB = try provenanceRecord(
            evidence.appendingPathComponent("run-b/provenance.json")
        )
        let sourceA = metrics(runA, stride: 1)
        let sourceB = metrics(runB, stride: 1)
        let compactA = metrics(runA, stride: 8)
        let compactB = metrics(runB, stride: 8)
        let repeatComparison = try comparison(runA, runB)
        let canonicalComparisonA = try comparison(runA, canonical)
        let canonicalComparisonB = try comparison(runB, canonical)
        let provenancePassed =
            provenanceA["nodeManifestSHA256"] as? String
                == expectedManifestSHA
            && provenanceB["nodeManifestSHA256"] as? String
                == expectedManifestSHA
            && provenanceA["nodeCount"] as? Int == 51
            && provenanceB["nodeCount"] as? Int == 51
            && provenanceA["actualScopeExact"] as? Bool == true
            && provenanceB["actualScopeExact"] as? Bool == true
            && provenanceA["semanticScopeExact"] as? Bool == true
            && provenanceB["semanticScopeExact"] as? Bool == true
        let portalCountsPassed =
            matches(sourceA, expected: expectedSource)
            && matches(sourceB, expected: expectedSource)
            && matches(compactA, expected: expectedCompact)
            && matches(compactB, expected: expectedCompact)
        let passed =
            runA.fileSHA256 == runB.fileSHA256
            && runA.decodedSHA256 == runB.decodedSHA256
            && runA.decodedSHA256 == canonicalDecodedSHA
            && runB.decodedSHA256 == canonicalDecodedSHA
            && (repeatComparison["differingPixelCount"] as? Int) == 0
            && (canonicalComparisonA["differingPixelCount"] as? Int) == 0
            && (canonicalComparisonB["differingPixelCount"] as? Int) == 0
            && provenancePassed
            && portalCountsPassed
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contract": "CONTRACT-019-R5",
            "disposition":
                passed ? "PASS_DEPTH_OWNERSHIP" : "HARD_PIPELINE_LIMIT",
            "diagnosticOnly": true,
            "sourceAuthority": false,
            "productionSelected": false,
            "rendererBinarySHA256":
                "3e6537e85e194069232b91ed0c1b617fb17692b76ea3c8a28242fb4bd3755659",
            "canonicalR3A": [
                "fileSHA256": canonical.fileSHA256,
                "decodedRGBASHA256": canonical.decodedSHA256,
                "requiredDecodedRGBASHA256": canonicalDecodedSHA,
            ],
            "runs": [
                "runA": [
                    "fileSHA256": runA.fileSHA256,
                    "decodedRGBASHA256": runA.decodedSHA256,
                    "provenance": provenanceA,
                ],
                "runB": [
                    "fileSHA256": runB.fileSHA256,
                    "decodedRGBASHA256": runB.decodedSHA256,
                    "provenance": provenanceB,
                ],
            ],
            "gates": [
                "fileIdentity": runA.fileSHA256 == runB.fileSHA256,
                "decodedRGBAIdentity":
                    runA.decodedSHA256 == runB.decodedSHA256,
                "canonicalDecodedRGBA":
                    runA.decodedSHA256 == canonicalDecodedSHA
                    && runB.decodedSHA256 == canonicalDecodedSHA,
                "nodeManifestAndApplicationScope": provenancePassed,
                "portalCounts": portalCountsPassed,
                "changedPixelSupport":
                    (canonicalComparisonA[
                        "differingPixelsOutsideTargetSupport"
                    ] as? Int) == 0
                    && (canonicalComparisonB[
                        "differingPixelsOutsideTargetSupport"
                    ] as? Int) == 0,
            ],
            "repeatComparison": repeatComparison,
            "canonicalComparison": [
                "runA": canonicalComparisonA,
                "runB": canonicalComparisonB,
                "targetSupportBoundsInclusive": support,
            ],
            "portalCounts": [
                "expectedSource": expectedSource,
                "expectedLiteral192": expectedCompact,
                "runASource": sourceA,
                "runBSource": sourceB,
                "runALiteral192": compactA,
                "runBLiteral192": compactB,
            ],
            "processCounts": [
                "sceneKitMetalSemantic": 2,
                "authoritativeRaw": 0,
                "normalizer": 0,
                "siblings": 0,
                "modeling": 0,
            ],
            "stopBoundary":
                passed
                ? "Determinism proof passed; portal modeling remains blocked."
                : "Depth bias is removed from the candidate; all further "
                    + "SceneKit tuning and portal modeling are blocked.",
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        try data.write(to: outputURL, options: .atomic)
        print(
            passed
                ? "PASS depth ownership"
                : "HARD_PIPELINE_LIMIT"
        )
    }
}
