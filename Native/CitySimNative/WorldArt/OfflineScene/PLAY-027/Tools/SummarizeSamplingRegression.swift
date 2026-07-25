import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

enum SamplingRegressionSummaryError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: summarize-sampling-regression --repository-root <path> --regression-root <path> --manifest <json> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

func summaryArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw SamplingRegressionSummaryError.arguments
    }
    return arguments[index + 1]
}

func summarySHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func summaryRelativePath(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func decodedPixelSHA256(_ url: URL) throws -> String {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary),
        image.bitsPerComponent == 8,
        image.bitsPerPixel == 32,
        image.bytesPerRow >= image.width * 4,
        let providerData = image.dataProvider?.data
    else {
        throw SamplingRegressionSummaryError.invalid(
            "standard ImageIO RGBA decode failed for \(url.path)"
        )
    }
    let sourceBytes = providerData as Data
    var packed = Data(count: image.width * image.height * 4)
    packed.withUnsafeMutableBytes { destination in
        sourceBytes.withUnsafeBytes { sourceStorage in
            guard
                let destinationBase = destination.baseAddress,
                let sourceBase = sourceStorage.baseAddress
            else {
                return
            }
            for row in 0..<image.height {
                destinationBase
                    .advanced(by: row * image.width * 4)
                    .copyMemory(
                        from: sourceBase.advanced(
                            by: row * image.bytesPerRow
                        ),
                        byteCount: image.width * 4
                    )
            }
        }
    }
    return summarySHA256(packed)
}

func summaryRecord(
    _ url: URL,
    repositoryRoot: URL
) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    return [
        "file": summaryRelativePath(
            url,
            repositoryRoot: repositoryRoot
        ),
        "fileSHA256": summarySHA256(data),
        "decodedPixelSHA256": try decodedPixelSHA256(url),
    ]
}

@main
enum SummarizeSamplingRegressionMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try summaryArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let regressionRoot = URL(
            fileURLWithPath: try summaryArgument(
                "--regression-root",
                in: arguments
            )
        ).standardizedFileURL
        let manifestURL = URL(
            fileURLWithPath: try summaryArgument(
                "--manifest",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try summaryArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        guard
            regressionRoot.path.contains("/diagnostics/"),
            reportURL.path.contains("/diagnostics/"),
            let manifest = try JSONSerialization.jsonObject(
                with: Data(contentsOf: manifestURL)
            ) as? [String: Any],
            let samples = manifest["samples"] as? [[String: Any]]
        else {
            throw SamplingRegressionSummaryError.invalid(
                "invalid diagnostic regression inputs"
            )
        }

        var failures: [String] = []
        var sampleReports: [[String: Any]] = []
        var primaryHashes = Set<String>()
        for sample in samples {
            guard
                let logicalID = sample["logicalBuildingID"] as? String,
                let direction = sample["direction"] as? String
            else {
                failures.append("descriptor manifest sample identity missing")
                continue
            }
            let key = "\(logicalID)/\(direction)"
            let rawRoot = regressionRoot
                .appendingPathComponent("raw")
                .appendingPathComponent(logicalID)
                .appendingPathComponent(direction)
            var runReports: [[String: Any]] = []
            var runFileHashes: [String] = []
            var runPixelHashes: [String] = []
            var itemFailures: [String] = []
            for runID in ["a", "b", "c"] {
                let pngURL = rawRoot.appendingPathComponent(
                    "run-\(runID).png"
                )
                let recordURL = rawRoot.appendingPathComponent(
                    "run-\(runID).json"
                )
                guard
                    FileManager.default.fileExists(
                        atPath: pngURL.path
                    ),
                    FileManager.default.fileExists(
                        atPath: recordURL.path
                    )
                else {
                    itemFailures.append("run-\(runID) missing")
                    continue
                }
                var run = try summaryRecord(
                    pngURL,
                    repositoryRoot: repositoryRoot
                )
                guard
                    let provenance = try JSONSerialization.jsonObject(
                        with: Data(contentsOf: recordURL)
                    ) as? [String: Any],
                    let sampling = provenance[
                        "descriptorSamplingContract"
                    ] as? [String: Any],
                    let diagnostic = provenance[
                        "diagnosticConfiguration"
                    ] as? [String: Any]
                else {
                    itemFailures.append("run-\(runID) provenance invalid")
                    continue
                }
                if sampling["contractID"] as? String
                    != "play027-deterministic-4x-no-msaa-lanczos-v1"
                    || sampling["descriptorSchema"] as? Int != 2
                    || sampling["sceneKitAntialiasing"] as? String
                        != "none"
                    || sampling["effectiveSceneKitAntialiasing"]
                        as? String != "none"
                    || sampling["linearOversamplingFactor"] as? Int != 4
                    || sampling["downsampleScale"] as? Double != 0.25
                    || diagnostic["antialiasingOverride"] as? String
                        != "none"
                    || diagnostic["sceneShadows"] as? String != "current"
                {
                    itemFailures.append(
                        "run-\(runID) is not descriptor-bound schema 2"
                    )
                }
                run["run"] = runID
                run["recordFile"] = summaryRelativePath(
                    recordURL,
                    repositoryRoot: repositoryRoot
                )
                runReports.append(run)
                runFileHashes.append(run["fileSHA256"] as! String)
                runPixelHashes.append(
                    run["decodedPixelSHA256"] as! String
                )
            }
            let repeatIdentityPassed =
                runFileHashes.count == 3
                && Set(runFileHashes).count == 1
                && Set(runPixelHashes).count == 1
            if runFileHashes.count == 3 && !repeatIdentityPassed {
                itemFailures.append("three-process raw identity failed")
            }
            if let first = runFileHashes.first {
                primaryHashes.insert(first)
            }
            failures.append(contentsOf: itemFailures.map {
                "\(key): \($0)"
            })
            sampleReports.append([
                "key": key,
                "runs": runReports,
                "repeatIdentityPassed": repeatIdentityPassed,
                "failures": itemFailures,
            ])
        }

        let completedPrimaryCount = sampleReports.filter {
            (($0["runs"] as? [[String: Any]])?.count ?? 0) > 0
        }.count
        let primaryUniquenessPassed =
            primaryHashes.count == completedPrimaryCount
        if !primaryUniquenessPassed {
            failures.append("completed primary raw identities are not unique")
        }

        let legacyRevisions: [String: String] = [
            "commercial_l01": "source-v04",
            "commercial_l02": "source-v01",
            "commercial_l03": "source-v01",
        ]
        var legacyReports: [[String: Any]] = []
        for logicalID in [
            "commercial_l01",
            "commercial_l02",
            "commercial_l03",
        ] {
            for direction in ["north", "east", "south", "west"] {
                let revision = legacyRevisions[logicalID]!
                let reproducedURL = regressionRoot
                    .appendingPathComponent("legacy-schema1")
                    .appendingPathComponent(logicalID)
                    .appendingPathComponent(direction)
                    .appendingPathComponent("source.png")
                let acceptedURL = repositoryRoot
                    .appendingPathComponent(
                        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/raw"
                    )
                    .appendingPathComponent(logicalID)
                    .appendingPathComponent("variant-0")
                    .appendingPathComponent(direction)
                    .appendingPathComponent("\(revision).png")
                guard
                    FileManager.default.fileExists(
                        atPath: reproducedURL.path
                    )
                else {
                    failures.append(
                        "legacy \(logicalID)/\(direction): reproduction missing"
                    )
                    continue
                }
                let reproduced = try summaryRecord(
                    reproducedURL,
                    repositoryRoot: repositoryRoot
                )
                let accepted = try summaryRecord(
                    acceptedURL,
                    repositoryRoot: repositoryRoot
                )
                let passed =
                    reproduced["fileSHA256"] as? String
                        == accepted["fileSHA256"] as? String
                    && reproduced["decodedPixelSHA256"] as? String
                        == accepted["decodedPixelSHA256"] as? String
                if !passed {
                    failures.append(
                        "legacy \(logicalID)/\(direction): byte reproduction failed"
                    )
                }
                legacyReports.append([
                    "key": "\(logicalID)/\(direction)",
                    "accepted": accepted,
                    "reproduced": reproduced,
                    "byteAndPixelIdentityPassed": passed,
                ])
            }
        }

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contractID":
                "play027-deterministic-4x-no-msaa-lanczos-v1",
            "expectedSchema2Samples": samples.count,
            "completedSchema2Primaries": completedPrimaryCount,
            "uniqueCompletedPrimaryHashes": primaryHashes.count,
            "primaryUniquenessPassed": primaryUniquenessPassed,
            "legacySchema1Reproduction": legacyReports,
            "schema2Samples": sampleReports,
            "failures": failures,
            "status": failures.isEmpty ? "pass" : "fail",
            "normalizationAuthorizedByRawGate": failures.isEmpty,
            "productionSelected": false,
        ]
        var reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes,
            ]
        )
        reportData.append(0x0a)
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try reportData.write(to: reportURL, options: .atomic)
        if !failures.isEmpty {
            throw SamplingRegressionSummaryError.invalid(
                failures.joined(separator: "\n")
            )
        }
    }
}
