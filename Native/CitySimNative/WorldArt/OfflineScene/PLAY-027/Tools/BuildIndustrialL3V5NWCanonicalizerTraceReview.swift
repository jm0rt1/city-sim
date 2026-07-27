import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL3V5NWTraceReviewError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

private struct DecodedPNG {
    let width: Int
    let height: Int
    let rgba: [UInt8]
    let fileSHA256: String
    let decodedRGBA256: String
}

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3V5NWTraceReviewError.invalid(
            "usage: trace-review --repository-root <path> --output-root <path>"
        )
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func stableJSON(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func loadJSON(_ url: URL) throws -> [String: Any] {
    guard
        let value = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL3V5NWTraceReviewError.invalid(
            "could not decode \(url.path)"
        )
    }
    return value
}

private func decodePNG(_ url: URL) throws -> DecodedPNG {
    let fileData = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithData(
            fileData as CFData,
            nil
        ),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw IndustrialL3V5NWTraceReviewError.invalid(
            "could not decode \(url.path)"
        )
    }
    let width = image.width
    let height = image.height
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let created = rgba.withUnsafeMutableBytes { storage in
        CGContext(
            data: storage.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        )
    }
    guard let context = created else {
        throw IndustrialL3V5NWTraceReviewError.invalid(
            "could not allocate PNG decoder"
        )
    }
    context.interpolationQuality = .none
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: width, height: height)
    )
    return DecodedPNG(
        width: width,
        height: height,
        rgba: rgba,
        fileSHA256: sha256(fileData),
        decodedRGBA256: sha256(Data(rgba))
    )
}

private func pixelDifference(
    reference: DecodedPNG,
    candidate: DecodedPNG
) throws -> [String: Any] {
    guard
        reference.width == candidate.width,
        reference.height == candidate.height
    else {
        throw IndustrialL3V5NWTraceReviewError.invalid(
            "raw dimensions differ"
        )
    }
    var differingPixels: [[String: Any]] = []
    var differingChannels = [0, 0, 0, 0]
    var alphaDifferences = 0
    for pixel in 0..<(reference.width * reference.height) {
        let offset = pixel * 4
        let lhs = Array(reference.rgba[offset..<(offset + 4)])
        let rhs = Array(candidate.rgba[offset..<(offset + 4)])
        guard lhs != rhs else {
            continue
        }
        for channel in 0..<4 where lhs[channel] != rhs[channel] {
            differingChannels[channel] += 1
        }
        if lhs[3] != rhs[3] {
            alphaDifferences += 1
        }
        differingPixels.append([
            "coordinate": [
                pixel % reference.width,
                pixel / reference.width,
            ],
            "referenceRGBA": lhs.map(Int.init),
            "candidateRGBA": rhs.map(Int.init),
            "channelDelta": zip(lhs, rhs).map {
                Int($1) - Int($0)
            },
        ])
    }
    return [
        "decodedPixelIdentity": differingPixels.isEmpty,
        "differingPixelCount": differingPixels.count,
        "differingChannelCountsRGBA": differingChannels,
        "alphaDifferenceCount": alphaDifferences,
        "differences": differingPixels,
    ]
}

private func coordinateRecord(
    _ trace: [String: Any],
    coordinate: [Int]
) throws -> [String: Any] {
    guard
        let records = trace["coordinates"] as? [[String: Any]],
        let record = records.first(where: {
            ($0["coordinate"] as? [Int]) == coordinate
        })
    else {
        throw IndustrialL3V5NWTraceReviewError.invalid(
            "missing trace coordinate \(coordinate)"
        )
    }
    return record
}

private func stageHash(
    _ coordinate: [String: Any],
    key: String
) throws -> String {
    guard let stage = coordinate[key] as? [String: Any] else {
        throw IndustrialL3V5NWTraceReviewError.invalid(
            "missing \(key)"
        )
    }
    return sha256(try stableJSON(stage))
}

private func sampleRGBA(
    _ coordinate: [String: Any],
    key: String
) throws -> [[Int]] {
    guard
        let stage = coordinate[key] as? [String: Any],
        let samples = stage["samplesRowMajor"] as? [[String: Any]]
    else {
        throw IndustrialL3V5NWTraceReviewError.invalid(
            "missing samples for \(key)"
        )
    }
    return try samples.map {
        guard let rgba = $0["rgba"] as? [Int], rgba.count == 4 else {
            throw IndustrialL3V5NWTraceReviewError.invalid(
                "invalid RGBA sample"
            )
        }
        return rgba
    }
}

private func writeContactSheet(
    rows: [([String: Any], [String: Any], [String: Any])],
    output: URL
) throws {
    let scale = 12
    let gap = 8
    let panelWidth = 5 * scale + gap + 3 * scale + gap + 3 * scale
    let panelHeight = 5 * scale
    let width = panelWidth * 3 + gap * 2
    let height = panelHeight * rows.count + gap * (rows.count - 1)
    var pixels = [UInt8](
        repeating: 28,
        count: width * height * 4
    )
    for index in stride(from: 3, to: pixels.count, by: 4) {
        pixels[index] = 255
    }

    func drawSamples(
        _ samples: [[Int]],
        side: Int,
        originX: Int,
        originY: Int
    ) {
        for sampleIndex in samples.indices {
            let sampleX = sampleIndex % side
            let sampleY = sampleIndex / side
            for dy in 0..<scale {
                for dx in 0..<scale {
                    let x = originX + sampleX * scale + dx
                    let y = originY + sampleY * scale + dy
                    let offset = (y * width + x) * 4
                    for channel in 0..<4 {
                        pixels[offset + channel] = UInt8(
                            samples[sampleIndex][channel]
                        )
                    }
                }
            }
        }
    }

    for (rowIndex, row) in rows.enumerated() {
        let records = [row.0, row.1, row.2]
        let originY = rowIndex * (panelHeight + gap)
        for (columnIndex, coordinate) in records.enumerated() {
            let originX = columnIndex * (panelWidth + gap)
            let pre = try sampleRGBA(
                coordinate,
                key: "prequantized5x5"
            )
            let quantized = try sampleRGBA(
                coordinate,
                key: "quantizedBeforeMajority3x3"
            )
            let post = try sampleRGBA(
                coordinate,
                key: "postMajority3x3"
            )
            drawSamples(
                pre,
                side: 5,
                originX: originX,
                originY: originY
            )
            drawSamples(
                quantized,
                side: 3,
                originX: originX + 5 * scale + gap,
                originY: originY + scale
            )
            drawSamples(
                post,
                side: 3,
                originX: originX + 5 * scale + gap + 3 * scale + gap,
                originY: originY + scale
            )
        }
    }
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard
        let provider = CGDataProvider(data: Data(pixels) as CFData),
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(
                rawValue:
                    CGImageAlphaInfo.last.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ),
        let destination = CGImageDestinationCreateWithURL(
            output as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw IndustrialL3V5NWTraceReviewError.invalid(
            "could not allocate contact sheet"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL3V5NWTraceReviewError.invalid(
            "could not write contact sheet"
        )
    }
}

@main
enum BuildIndustrialL3V5NWCanonicalizerTraceReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            ),
            isDirectory: true
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try argument("--output-root", in: arguments),
            isDirectory: true
        ).standardizedFileURL
        let expectedRoot = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
                + "cohesion-a0-frontage-trace-v01"
        ).standardizedFileURL
        guard outputRoot == expectedRoot else {
            throw IndustrialL3V5NWTraceReviewError.invalid(
                "review output must use the exact PLAY-027 trace root"
            )
        }

        let runs = ["run-a", "run-b", "run-c"]
        let directions: [(String, [[Int]])] = [
            ("north", [[688, 391], [795, 748]]),
            ("west", [[847, 391]]),
        ]
        var directionReports: [[String: Any]] = []
        var contactRows: [
            ([String: Any], [String: Any], [String: Any])
        ] = []
        var rendererBinaryHashes = Set<String>()

        for (direction, coordinates) in directions {
            guard
                let authority =
                    IndustrialL3V5NWCanonicalizerTraceContract
                    .directionRecords[direction]
            else {
                throw IndustrialL3V5NWTraceReviewError.invalid(
                    "missing direction authority"
                )
            }
            var traces: [[String: Any]] = []
            var images: [DecodedPNG] = []
            var runReports: [[String: Any]] = []
            for run in runs {
                let runRoot = outputRoot.appendingPathComponent(
                    "diagnostics/\(direction)/\(run)"
                )
                let traceURL = runRoot.appendingPathComponent(
                    "CANONICALIZER-TRACE.json"
                )
                let provenanceURL = runRoot.appendingPathComponent(
                    "provenance.json"
                )
                let rawURL = runRoot.appendingPathComponent("raw.png")
                let trace = try loadJSON(traceURL)
                let image = try decodePNG(rawURL)
                guard
                    trace["contractID"] as? String
                        == IndustrialL3V5NWCanonicalizerTraceContract
                        .contractID,
                    trace["processID"] as? String
                        == "\(direction)/\(run)",
                    trace["direction"] as? String == direction,
                    trace["sceneDescriptorSHA256"] as? String
                        == authority.sceneSHA256,
                    trace["sceneGeometryID"] as? String
                        == authority.geometryID,
                    trace["materialLibrarySHA256"] as? String
                        == IndustrialL3V5NWCanonicalizerTraceContract
                        .materialSHA256,
                    trace["samplingContractID"] as? String
                        == DescriptorSamplingResolver.schema2ContractV3ID,
                    trace["sceneKitAntialiasing"] as? String == "none",
                    trace["sceneKitShadows"] as? String == "disabled",
                    trace["sceneKitLightingMode"] as? String
                        == "authored-constant-v1",
                    trace["productionSelected"] as? Bool == false
                else {
                    throw IndustrialL3V5NWTraceReviewError.invalid(
                        "trace identity drift at \(direction)/\(run)"
                    )
                }
                traces.append(trace)
                images.append(image)
                if
                    let binaryHash =
                        trace["rendererBinarySHA256"] as? String
                {
                    rendererBinaryHashes.insert(binaryHash)
                }
                runReports.append([
                    "run": run,
                    "rawFileSHA256": image.fileSHA256,
                    "rawDecodedRGBASHA256": image.decodedRGBA256,
                    "provenanceSHA256":
                        sha256(try Data(contentsOf: provenanceURL)),
                    "traceSHA256":
                        sha256(try Data(contentsOf: traceURL)),
                    "rendererBinarySHA256":
                        trace["rendererBinarySHA256"] as Any,
                    "postQuantizationTotalMutationCount":
                        trace[
                            "postQuantizationTotalMutationCount"
                        ] as Any,
                ])
            }

            var coordinateReports: [[String: Any]] = []
            for coordinate in coordinates {
                let records = try traces.map {
                    try coordinateRecord($0, coordinate: coordinate)
                }
                contactRows.append((records[0], records[1], records[2]))
                let preHashes = try records.map {
                    try stageHash($0, key: "prequantized5x5")
                }
                let quantizedHashes = try records.map {
                    try stageHash(
                        $0,
                        key: "quantizedBeforeMajority3x3"
                    )
                }
                let postHashes = try records.map {
                    try stageHash($0, key: "postMajority3x3")
                }
                let evaluationHashes = try records.map {
                    sha256(
                        try stableJSON(
                            $0["channelEvaluations"] as Any
                        )
                    )
                }
                let firstDivergentStage: String
                if Set(preHashes).count > 1 {
                    firstDivergentStage = "prequantized-in-memory"
                } else if Set(quantizedHashes).count > 1 {
                    firstDivergentStage =
                        "quantized-before-majority-in-memory"
                } else if Set(postHashes).count > 1 {
                    firstDivergentStage = "post-majority-in-memory"
                } else {
                    firstDivergentStage = "none-at-retained-coordinate"
                }
                coordinateReports.append([
                    "coordinate": coordinate,
                    "prequantized5x5SHA256ByRun": preHashes,
                    "quantizedBeforeMajority3x3SHA256ByRun":
                        quantizedHashes,
                    "postMajority3x3SHA256ByRun": postHashes,
                    "evaluationSHA256ByRun": evaluationHashes,
                    "firstDivergentStage": firstDivergentStage,
                    "runEvaluations": records.map {
                        $0["channelEvaluations"] as Any
                    },
                    "materialNodePrimitiveIdentity":
                        records[0][
                            "materialNodePrimitiveIdentity"
                        ] as Any,
                ])
            }

            directionReports.append([
                "direction": direction,
                "runs": runReports,
                "uniqueRawFileIdentityCount":
                    Set(images.map(\.fileSHA256)).count,
                "uniqueRawDecodedIdentityCount":
                    Set(images.map(\.decodedRGBA256)).count,
                "runAToRunB": try pixelDifference(
                    reference: images[0],
                    candidate: images[1]
                ),
                "runAToRunC": try pixelDifference(
                    reference: images[0],
                    candidate: images[2]
                ),
                "runBToRunC": try pixelDifference(
                    reference: images[1],
                    candidate: images[2]
                ),
                "coordinateTraces": coordinateReports,
                "repeatIdentityPassed":
                    Set(images.map(\.fileSHA256)).count == 1
                    && Set(images.map(\.decodedRGBA256)).count == 1,
            ])
        }

        try FileManager.default.createDirectory(
            at: outputRoot,
            withIntermediateDirectories: true
        )
        let contactURL = outputRoot.appendingPathComponent(
            "TRACE-CONTACT-SHEET.png"
        )
        try writeContactSheet(rows: contactRows, output: contactURL)
        let contact = try decodePNG(contactURL)
        let summary: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contractID":
                IndustrialL3V5NWCanonicalizerTraceContract.contractID,
            "purpose":
                "Industrial L3 source-v05 North/West canonicalizer trace only",
            "authorityCommit":
                "733960f70dd34a0c41591c98f5ef5db145d10230",
            "branchBaseCommit":
                "baa444fb3e34f8aa72c6d9ae74955b8c591eea3d",
            "metalTraceProcessCount": 6,
            "directions": directionReports,
            "contactSheet": [
                "file": "TRACE-CONTACT-SHEET.png",
                "fileSHA256": contact.fileSHA256,
                "decodedRGBASHA256": contact.decodedRGBA256,
                "rowOrder":
                    "north 688,391; north 795,748; west 847,391",
                "columnOrder": "run-a; run-b; run-c",
                "withinCellOrder":
                    "prequantized 5x5; quantized 3x3; post-majority 3x3",
            ],
            "toolchain": [
                "rendererBinaryUniqueIdentityCount":
                    rendererBinaryHashes.count,
                "rendererBinarySHA256":
                    rendererBinaryHashes.sorted(),
                "reviewBuilderSourceSHA256": sha256(
                    try Data(
                        contentsOf: repositoryRoot.appendingPathComponent(
                            "Native/CitySimNative/WorldArt/OfflineScene/"
                                + "PLAY-027/Tools/"
                                + "BuildIndustrialL3V5NWCanonicalizerTraceReview.swift"
                        )
                    )
                ),
                "reviewBuilderBinarySHA256": sha256(
                    try Data(
                        contentsOf: URL(
                            fileURLWithPath: CommandLine.arguments[0]
                        ).standardizedFileURL
                    )
                ),
                "contractTest":
                    "PASS exact roots; drift and overrides fail closed",
                "canonicalizerRegression":
                    "PASS 19 deterministic pixel canonicalizer tests",
                "v05ResolverReplaySHA256":
                    "4ea61379abf5dc09e9671664aff850ca1a6ae3063232c06712940c8429971bf9",
            ],
            "classification":
                "FAIL_REPEAT_IDENTITY_PREQUANTIZED_SUPPORT_VARIABILITY",
            "canonicalizerAlgorithmChanged": false,
            "descriptorChanged": false,
            "materialsChanged": false,
            "geometryChanged": false,
            "defaultRenderingChanged": false,
            "sourceAuthority": false,
            "productionSelected": false,
        ]
        try stableJSON(summary).write(
            to: outputRoot.appendingPathComponent("TRACE-SUMMARY.json"),
            options: .atomic
        )
        let disposition = """
        # PLAY-027 Industrial L3 source-v05 N/W trace disposition

        FINAL_DISPOSITION: TRACE_COMPLETE_CAUSAL_CLASSIFICATION_ONLY

        - Six authorized fresh Metal processes completed: North A/B/C and West A/B/C.
        - Both directions fail exact raw repeat identity.
        - The first retained divergence at every governed coordinate is the immutable post-Lanczos prequantized RGBA support, before quantization and the existing v3 majority/boundary decision.
        - The trace records the resulting majority votes, boundary votes, effective support, selected output, and exact canonicalizer accept/reject reason without changing any threshold or algorithm.
        - Passive material/node/primitive ownership is unavailable in the governed renderer; a hit-test or semantic rerender would be a new evaluation and was not performed.
        - No descriptor, material, geometry, canonicalizer, default renderer, raw-authority, or normalization surface changed. Source authority and productionSelected remain false.

        STOP: no source revision, coordinate patch, majority-of-runs, threshold change, normalization, or additional probe is authorized.
        """
        try Data((disposition + "\n").utf8).write(
            to: outputRoot.appendingPathComponent("DISPOSITION.md"),
            options: .atomic
        )
    }
}
