import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

enum IndustrialL2V8ValidationSummaryError:
    Error,
    CustomStringConvertible
{
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: summarize-industrial-l2-v8-validation --repository-root <path> --output <json>"
        case let .invalid(message):
            return message
        }
    }
}

private struct ValidationImage {
    let fileSHA256: String
    let decodedSHA256: String
    let width: Int
    let height: Int
    let rgba: [UInt8]
}

private func summaryArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2V8ValidationSummaryError.arguments
    }
    return arguments[index + 1]
}

private func summarySHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func summaryLoadImage(
    _ url: URL,
    pixels: [Int]
) throws -> ValidationImage {
    let data = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        ),
        image.width == pixels[0],
        image.height == pixels[1]
    else {
        throw IndustrialL2V8ValidationSummaryError.invalid(
            "could not decode exact-size image \(url.path)"
        )
    }
    var rgba = [UInt8](
        repeating: 0,
        count: image.width * image.height * 4
    )
    let rendered = rgba.withUnsafeMutableBytes {
        storage -> Bool in
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
            in: CGRect(
                x: 0,
                y: 0,
                width: image.width,
                height: image.height
            )
        )
        return true
    }
    guard rendered else {
        throw IndustrialL2V8ValidationSummaryError.invalid(
            "could not produce canonical RGBA for \(url.path)"
        )
    }
    return ValidationImage(
        fileSHA256: summarySHA256(data),
        decodedSHA256: summarySHA256(Data(rgba)),
        width: image.width,
        height: image.height,
        rgba: rgba
    )
}

private func summaryBounds(
    _ image: ValidationImage
) -> [Int] {
    var bounds = [image.width, image.height, -1, -1]
    for y in 0..<image.height {
        for x in 0..<image.width {
            let index = (y * image.width + x) * 4
            if
                image.rgba[index] == 255,
                image.rgba[index + 1] == 0,
                image.rgba[index + 2] == 255,
                image.rgba[index + 3] == 255
            {
                continue
            }
            bounds[0] = min(bounds[0], x)
            bounds[1] = min(bounds[1], y)
            bounds[2] = max(bounds[2], x + 1)
            bounds[3] = max(bounds[3], y + 1)
        }
    }
    return bounds[2] < 0 ? [] : bounds
}

private func summaryRecord(
    _ image: ValidationImage,
    relativePath: String,
    includeBounds: Bool = false
) -> [String: Any] {
    var result: [String: Any] = [
        "file": relativePath,
        "fileSHA256": image.fileSHA256,
        "decodedRGBASHA256": image.decodedSHA256,
        "pixels": [image.width, image.height],
    ]
    if includeBounds {
        result["occupiedBounds"] = summaryBounds(image)
    }
    return result
}

@main
enum SummarizeIndustrialL2V8FiniteEquivalenceValidationMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try summaryArgument(
                "--repository-root",
                in: arguments
            ),
            isDirectory: true
        ).standardizedFileURL
        let output = URL(
            fileURLWithPath: try summaryArgument(
                "--output",
                in: arguments
            )
        ).standardizedFileURL
        let evidence =
            "docs/production/evidence/PLAY-027/industrial-l02/l02/"
            + "source-v08-finite-equivalence-validation"
        guard
            output.path
                == root.appendingPathComponent(
                    evidence + "/VALIDATION-TRIPLET-RESULT.json"
                ).path,
            !FileManager.default.fileExists(atPath: output.path)
        else {
            throw IndustrialL2V8ValidationSummaryError.invalid(
                "summary output must be the new exact validation result path"
            )
        }
        let tableURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/"
                + "source-v06-finite-equivalence-diagnostic/proposal/"
                + "FINITE-RGB-EQUIVALENCE-TABLE.json"
        )
        let tableData = try Data(contentsOf: tableURL)
        guard
            summarySHA256(tableData)
                == "7c2d5940b8fca22d1e2cb15fa248ab678e8b8266fb3ed453332d82474284ed31",
            let tableObject = try JSONSerialization.jsonObject(
                with: tableData
            ) as? [String: Any],
            let coordinateObjects =
                tableObject["coordinates"] as? [[String: Any]]
        else {
            throw IndustrialL2V8ValidationSummaryError.invalid(
                "frozen table hash or coordinate structure drifted"
            )
        }
        let governedCoordinates = Set<Int>(
            coordinateObjects.map {
                let coordinate = $0["coordinate4x"] as! [Int]
                return coordinate[1] * 6144 + coordinate[0]
            }
        )
        guard governedCoordinates.count == 57 else {
            throw IndustrialL2V8ValidationSummaryError.invalid(
                "governed coordinate count drifted"
            )
        }

        let baselinePath =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/raw/"
            + "industrial_l02/variant-0/east/source-v06.png"
        let baseline = try summaryLoadImage(
            root.appendingPathComponent(baselinePath),
            pixels: [1536, 1024]
        )
        guard
            baseline.fileSHA256
                == "f59566ff0dad474e499fbfd2d719e54fae3c432133b5e17b158ded8ebc609503",
            baseline.decodedSHA256
                == "dd0fe1b05c3c8d65a10ca2cfa8fac0bb368117acd0db750dbea160115787d249"
        else {
            throw IndustrialL2V8ValidationSummaryError.invalid(
                "frozen source-v06 baseline drifted"
            )
        }

        let runIDs = ["run-a", "run-b", "run-c"]
        let captureRoles: [(String, String, [Int])] = [
            ("preMap4x", "PRE-MAP-4X.png", [6144, 4096]),
            (
                "mappedPreLanczos4x",
                "MAPPED-PRE-LANCZOS-4X.png",
                [6144, 4096]
            ),
            (
                "postLanczosPrequantized",
                "POST-LANCZOS-PREQUANTIZED.png",
                [1536, 1024]
            ),
            (
                "imageIOPreSips",
                "imageio-pre-sips.png",
                [1536, 1024]
            ),
            ("finalSips", "final-sips.png", [1536, 1024]),
        ]
        var runRecords: [[String: Any]] = []
        var imagesByRole: [String: [ValidationImage]] = [:]
        for runID in runIDs {
            let directory =
                evidence + "/diagnostics/" + runID
            var imageRecords: [String: Any] = [:]
            var loaded: [String: ValidationImage] = [:]
            for (role, file, pixels) in captureRoles {
                let relative = directory + "/" + file
                let image = try summaryLoadImage(
                    root.appendingPathComponent(relative),
                    pixels: pixels
                )
                loaded[role] = image
                imagesByRole[role, default: []].append(image)
                imageRecords[role] = summaryRecord(
                    image,
                    relativePath: relative,
                    includeBounds: role == "finalSips"
                )
            }
            let pre = loaded["preMap4x"]!
            let mapped = loaded["mappedPreLanczos4x"]!
            var changedPixels = 0
            var changedChannels = 0
            var alphaChangedPixels = 0
            var chromaChangedPixels = 0
            var outOfScopeChangedPixels = 0
            for pixel in 0..<(6144 * 4096) {
                let offset = pixel * 4
                var changed = false
                for channel in 0..<4 {
                    if pre.rgba[offset + channel]
                        != mapped.rgba[offset + channel]
                    {
                        changed = true
                        changedChannels += 1
                        if channel == 3 {
                            alphaChangedPixels += 1
                        }
                    }
                }
                guard changed else {
                    continue
                }
                changedPixels += 1
                if !governedCoordinates.contains(pixel) {
                    outOfScopeChangedPixels += 1
                }
                let preChroma =
                    pre.rgba[offset] == 255
                    && pre.rgba[offset + 1] == 0
                    && pre.rgba[offset + 2] == 255
                let mappedChroma =
                    mapped.rgba[offset] == 255
                    && mapped.rgba[offset + 1] == 0
                    && mapped.rgba[offset + 2] == 255
                if preChroma != mappedChroma {
                    chromaChangedPixels += 1
                }
            }
            guard
                alphaChangedPixels == 0,
                chromaChangedPixels == 0,
                outOfScopeChangedPixels == 0,
                loaded["finalSips"]!.fileSHA256
                    == baseline.fileSHA256,
                loaded["finalSips"]!.decodedSHA256
                    == baseline.decodedSHA256,
                summaryBounds(loaded["finalSips"]!)
                    == summaryBounds(baseline)
            else {
                throw IndustrialL2V8ValidationSummaryError.invalid(
                    "\(runID) violated mapping scope or final v06 parity"
                )
            }
            let stageRelative =
                directory + "/STAGE-CAPTURE.json"
            let provenanceRelative =
                directory + "/provenance.json"
            let stageURL = root.appendingPathComponent(stageRelative)
            let provenanceURL = root.appendingPathComponent(
                provenanceRelative
            )
            let stageData = try Data(contentsOf: stageURL)
            let provenanceData = try Data(contentsOf: provenanceURL)
            let stage =
                try JSONSerialization.jsonObject(with: stageData)
                as! [String: Any]
            let finite =
                stage["finiteEquivalenceValidation"]
                as! [String: Any]
            let persistedInput =
                stage["persistedFiniteEquivalenceInput4xFrame"]
                as! [String: Any]
            let persistedMapped =
                stage["persistedFiniteEquivalenceMapped4xFrame"]
                as! [String: Any]
            guard
                persistedInput["persistedDecodeEqualsInMemory"]
                    as? Bool == true,
                persistedMapped["persistedDecodeEqualsInMemory"]
                    as? Bool == true,
                finite["inputDecodedRGBASHA256"] as? String
                    == pre.decodedSHA256,
                finite["mappedDecodedRGBASHA256"] as? String
                    == mapped.decodedSHA256,
                finite["onlyGovernedCoordinatesMayChange"]
                    as? Bool == true,
                finite["productionSelected"] as? Bool == false
            else {
                throw IndustrialL2V8ValidationSummaryError.invalid(
                    "\(runID) stage capture binding drifted"
                )
            }
            runRecords.append([
                "runID": runID,
                "images": imageRecords,
                "mapping": [
                    "changedPixelCount": changedPixels,
                    "changedChannelCount": changedChannels,
                    "alphaChangedPixelCount": alphaChangedPixels,
                    "chromaChangedPixelCount": chromaChangedPixels,
                    "outOfScopeChangedPixelCount":
                        outOfScopeChangedPixels,
                    "recordedMutationCount":
                        finite["mutationCount"] as! Int,
                ],
                "stageCapture": [
                    "file": stageRelative,
                    "fileSHA256": summarySHA256(stageData),
                ],
                "provenance": [
                    "file": provenanceRelative,
                    "fileSHA256": summarySHA256(provenanceData),
                ],
                "inputRoundTripExact": true,
                "finalEqualsFrozenSourceV06File": true,
                "finalEqualsFrozenSourceV06DecodedPixels": true,
                "productionSelected": false,
            ])
        }

        func identities(_ role: String) -> [String: Any] {
            let images = imagesByRole[role]!
            return [
                "fileIdentityCount":
                    Set(images.map(\.fileSHA256)).count,
                "decodedPixelIdentityCount":
                    Set(images.map(\.decodedSHA256)).count,
                "fileSHA256": images.map(\.fileSHA256),
                "decodedRGBASHA256":
                    images.map(\.decodedSHA256),
            ]
        }

        let mappedIdentity = identities("mappedPreLanczos4x")
        let prequantizedIdentity =
            identities("postLanczosPrequantized")
        let finalIdentity = identities("finalSips")
        let mappedUnique =
            mappedIdentity["decodedPixelIdentityCount"] as! Int
        let prequantizedUnique =
            prequantizedIdentity[
                "decodedPixelIdentityCount"
            ] as! Int
        let finalUnique =
            finalIdentity["decodedPixelIdentityCount"] as! Int
        guard
            mappedUnique == 2,
            prequantizedUnique == 2,
            finalUnique == 1
        else {
            throw IndustrialL2V8ValidationSummaryError.invalid(
                "expected retained rejection signature drifted"
            )
        }

        let result: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "status": "rejected",
            "disposition":
                "binding validation identity gate failed; preserve and stop",
            "authority":
                "53ecccdd4a02a6d5e3ab464b32aa8fa5a4c8e3ed",
            "contractID":
                "industrial-l02-source-v08-equivalent-east-finite-rgb-validation-v1",
            "direction": "east",
            "freshMetalProcessCount": 3,
            "runs": runRecords,
            "tripletIdentity": [
                "preMap4x": identities("preMap4x"),
                "mappedPreLanczos4x": mappedIdentity,
                "postLanczosPrequantized":
                    prequantizedIdentity,
                "imageIOPreSips": identities("imageIOPreSips"),
                "finalSips": finalIdentity,
            ],
            "firstDivergentStage": [
                "stage": "mapped-pre-lanczos-4x",
                "runAEqualsRunC": true,
                "runBDiffers": true,
                "differingPixelCount": 7,
                "differingChannelCount": 16,
                "alphaDifferingPixelCount": 0,
                "differenceBounds4x": [3359, 1742, 3417, 1797],
                "allDifferenceCoordinatesOutsideFrozenTable":
                    true,
                "localityReport":
                    evidence
                    + "/review/MAPPED-4X-IDENTITY-FAILURE.json",
            ],
            "postLanczosDivergence": [
                "runAEqualsRunC": true,
                "runBDiffers": true,
                "differingPixelCount": 2,
                "differingChannelCount": 2,
                "alphaDifferingPixelCount": 0,
                "differenceBoundsSource": [838, 697, 856, 706],
                "localityReport":
                    evidence
                    + "/review/POST-LANCZOS-PREQUANTIZED-IDENTITY-FAILURE.json",
            ],
            "finalConvergence": [
                "allThreeFileIdentity": true,
                "allThreeDecodedPixelIdentity": true,
                "allThreeByteExactFrozenSourceV06": true,
                "fileSHA256":
                    "f59566ff0dad474e499fbfd2d719e54fae3c432133b5e17b158ded8ebc609503",
                "decodedRGBASHA256":
                    "dd0fe1b05c3c8d65a10ca2cfa8fac0bb368117acd0db750dbea160115787d249",
                "occupiedBounds": summaryBounds(baseline),
                "colorDifferencePixels": 0,
                "grayscaleDifferencePixels": 0,
                "alphaDifferencePixels": 0,
                "silhouetteDifferencePixels": 0,
                "registrationDifferencePixels": 0,
            ],
            "frozenTableExpanded": false,
            "rerenderPerformed": false,
            "normalizationPerformed": false,
            "productionSelected": false,
        ]
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var data = try JSONSerialization.data(
            withJSONObject: result,
            options: [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes,
            ]
        )
        data.append(0x0a)
        try data.write(to: output, options: .atomic)
        print(
            "REJECT mapped 4x identity 2/3; post-Lanczos identity 2/3; final raw converged byte-exact to frozen source-v06"
        )
    }
}
