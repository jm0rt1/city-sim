import CryptoKit
import Foundation

enum StageCaptureSummaryError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: summarize-renderer-stage-captures --repository-root <path> --capture-root <diagnostics-dir> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

func stageSummaryArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw StageCaptureSummaryError.arguments
    }
    return arguments[index + 1]
}

func stageSummaryRelativePath(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path + "/"
    guard url.path.hasPrefix(prefix) else {
        return url.path
    }
    return String(url.path.dropFirst(prefix.count))
}

func stageSummarySHA256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map {
        String(format: "%02x", $0)
    }.joined()
}

func stageSummarySHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

@main
enum SummarizeRendererStageCapturesMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try stageSummaryArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let captureRoot = URL(
            fileURLWithPath: try stageSummaryArgument(
                "--capture-root",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try stageSummaryArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        guard
            captureRoot.path.contains("/diagnostics/"),
            reportURL.path.contains("/diagnostics/")
        else {
            throw StageCaptureSummaryError.invalid(
                "capture input and report must remain under diagnostics"
            )
        }
        let manager = FileManager.default
        guard
            let enumerator = manager.enumerator(
                at: captureRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            throw StageCaptureSummaryError.invalid(
                "could not enumerate capture root"
            )
        }
        let captureURLs = enumerator.compactMap { item -> URL? in
            guard let url = item as? URL else {
                return nil
            }
            return url.lastPathComponent == "STAGE-CAPTURE.json"
                ? url
                : nil
        }.sorted { $0.path < $1.path }
        guard !captureURLs.isEmpty else {
            throw StageCaptureSummaryError.invalid(
                "no STAGE-CAPTURE.json records found"
            )
        }

        let expectedStages = [
            "prequantized-in-memory",
            "quantized-before-majority-in-memory",
            "post-majority-in-memory",
            "imageio-pre-sips-decoded",
            "final-sips-decoded",
        ]
        var runRecords: [[String: Any]] = []
        var hashesByStage = Dictionary(
            uniqueKeysWithValues: expectedStages.map {
                ($0, [String: Int]())
            }
        )
        var targetsByStage = Dictionary(
            uniqueKeysWithValues: expectedStages.map {
                ($0, [String: Int]())
            }
        )
        var local3x3ByStage = Dictionary(
            uniqueKeysWithValues: expectedStages.map {
                ($0, [String: Int]())
            }
        )
        var finalFileHashes: [String: Int] = [:]
        var allStageIdentityPassed = true
        var retainedFileCount = 0

        for captureURL in captureURLs {
            let runDirectory = captureURL.deletingLastPathComponent()
            let expectedRetainedFiles = [
                captureURL,
                runDirectory.appendingPathComponent("final-sips.png"),
                runDirectory.appendingPathComponent("imageio-pre-sips.png"),
                runDirectory.appendingPathComponent("provenance.json"),
            ]
            guard expectedRetainedFiles.allSatisfy({
                manager.fileExists(atPath: $0.path)
            }) else {
                throw StageCaptureSummaryError.invalid(
                    "run is missing one of four retained files: \(runDirectory.path)"
                )
            }
            let retainedFiles: [[String: String]] =
                try expectedRetainedFiles.map { fileURL in
                    [
                        "file": stageSummaryRelativePath(
                            fileURL,
                            repositoryRoot: repositoryRoot
                        ),
                        "sha256": try stageSummarySHA256(fileURL),
                    ]
                }
            retainedFileCount += retainedFiles.count
            guard
                let capture = try JSONSerialization.jsonObject(
                    with: Data(contentsOf: captureURL)
                ) as? [String: Any],
                let stages = capture["stages"] as? [[String: Any]],
                let targetCoordinate =
                    capture["targetCoordinate"] as? [Int],
                targetCoordinate == [732, 778],
                let evaluations =
                    capture["postMajorityTargetEvaluations"]
                    as? [[String: Any]],
                evaluations.count == 3,
                let identity =
                    capture["stageIdentity"] as? [String: Any],
                let postToImageIO =
                    identity["postMajorityEqualsImageIODecode"]
                    as? Bool,
                let imageIOToSips =
                    identity["imageIODecodeEqualsFinalSipsDecode"]
                    as? Bool
            else {
                throw StageCaptureSummaryError.invalid(
                    "invalid capture record: \(captureURL.path)"
                )
            }
            let recordsByName = Dictionary(
                uniqueKeysWithValues: try stages.map { stage in
                    guard
                        let name = stage["stage"] as? String,
                        let sha = stage["decodedRGBASHA256"] as? String,
                        let target = stage["targetRGBA"] as? [Int],
                        let local = stage["local3x3"] as? [[String: Any]],
                        local.count == 9
                    else {
                        throw StageCaptureSummaryError.invalid(
                            "incomplete stage record: \(captureURL.path)"
                        )
                    }
                    return (
                        name,
                        (
                            sha,
                            target,
                            local,
                            stage["fileSHA256"] as? String
                        )
                    )
                }
            )
            guard Set(recordsByName.keys) == Set(expectedStages) else {
                throw StageCaptureSummaryError.invalid(
                    "capture does not contain the exact five stages"
                )
            }
            var summarizedStages: [[String: Any]] = []
            for stageName in expectedStages {
                let stage = recordsByName[stageName]!
                hashesByStage[stageName]![stage.0, default: 0] += 1
                let targetKey = stage.1.map(String.init).joined(separator: ",")
                targetsByStage[stageName]![targetKey, default: 0] += 1
                let localData = try JSONSerialization.data(
                    withJSONObject: stage.2,
                    options: [.sortedKeys, .withoutEscapingSlashes]
                )
                let localSHA = stageSummarySHA256(localData)
                local3x3ByStage[stageName]![localSHA, default: 0] += 1
                var summarizedStage: [String: Any] = [
                    "stage": stageName,
                    "decodedRGBASHA256": stage.0,
                    "targetRGBA": stage.1,
                    "local3x3": stage.2,
                    "local3x3SHA256": localSHA,
                ]
                if let fileSHA = stage.3 {
                    summarizedStage["fileSHA256"] = fileSHA
                    if stageName == "final-sips-decoded" {
                        finalFileHashes[fileSHA, default: 0] += 1
                    }
                }
                summarizedStages.append(summarizedStage)
            }
            allStageIdentityPassed =
                allStageIdentityPassed && postToImageIO && imageIOToSips
            runRecords.append([
                "run": captureURL.deletingLastPathComponent()
                    .lastPathComponent,
                "captureFile": stageSummaryRelativePath(
                    captureURL,
                    repositoryRoot: repositoryRoot
                ),
                "captureFileSHA256":
                    try stageSummarySHA256(captureURL),
                "retainedFiles": retainedFiles,
                "stages": summarizedStages,
                "postMajorityTargetEvaluations": evaluations,
                "postMajorityTargetEligible":
                    capture["postMajorityTargetEligible"] as? Bool
                    ?? false,
                "postMajorityTargetMutated":
                    capture["postMajorityTargetMutated"] as? Bool
                    ?? false,
                "postMajorityTotalMutationCount":
                    capture["postMajorityTotalMutationCount"] as? Int
                    ?? -1,
                "stageIdentity": identity,
            ])
        }

        let stageDistributions: [[String: Any]] = expectedStages.map {
            stageName in
            [
                "stage": stageName,
                "distinctDecodedRGBASHA256Count":
                    hashesByStage[stageName]!.count,
                "decodedRGBASHA256Counts":
                    hashesByStage[stageName]!,
                "targetRGBACounts":
                    targetsByStage[stageName]!,
                "distinctLocal3x3Count":
                    local3x3ByStage[stageName]!.count,
                "local3x3SHA256Counts":
                    local3x3ByStage[stageName]!,
            ]
        }
        let earliestFullFrameDivergentStage = expectedStages.first {
            hashesByStage[$0]!.count > 1
        } ?? "none"
        let earliestLocal3x3DivergentStage = expectedStages.first {
            local3x3ByStage[$0]!.count > 1
        } ?? "none"
        let exactStageThatReintroducesTarget = expectedStages.first {
            targetsByStage[$0]!.count > 1
        } ?? "none"
        let finalDistribution =
            hashesByStage["final-sips-decoded"]!
        let status =
            finalFileHashes.count >= 2
                && allStageIdentityPassed
                && exactStageThatReintroducesTarget
                    == "post-majority-in-memory"
            ? "stage-boundary-isolated"
            : "incomplete"
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "purpose":
                "residual-stage-isolation-no-authority",
            "targetCoordinate": [732, 778],
            "coordinateSystem":
                "top-left decoded RGBA source pixel",
            "runCount": runRecords.count,
            "retainedRunFileCount": retainedFileCount,
            "runs": runRecords,
            "stageDistributions": stageDistributions,
            "earliestFullFrameDivergentStage":
                earliestFullFrameDivergentStage,
            "earliestLocal3x3DivergentStage":
                earliestLocal3x3DivergentStage,
            "exactStageThatReintroducesTarget":
                exactStageThatReintroducesTarget,
            "finalDecodedRGBASHA256Counts": finalDistribution,
            "finalPNGFileSHA256Counts": finalFileHashes,
            "allPostMajorityImageIOSipsDecodedPixelsIdentical":
                allStageIdentityPassed,
            "thresholdsBroadened": false,
            "additionalRepairAdded": false,
            "productionSelected": false,
            "status": status,
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes,
            ]
        )
        data.append(0x0a)
        try manager.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: reportURL, options: .atomic)
        print(
            "\(status) \(runRecords.count) runs; target split: \(exactStageThatReintroducesTarget)"
        )
    }
}
