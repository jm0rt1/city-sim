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
        var allStageIdentityPassed = true

        for captureURL in captureURLs {
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
                    return (name, (sha, target, local))
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
                summarizedStages.append([
                    "stage": stageName,
                    "decodedRGBASHA256": stage.0,
                    "targetRGBA": stage.1,
                    "local3x3": stage.2,
                ])
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
            ]
        }
        let earliestDivergentStage = expectedStages.first {
            hashesByStage[$0]!.count > 1
        } ?? "none"
        let finalDistribution =
            hashesByStage["final-sips-decoded"]!
        let status =
            finalDistribution.count >= 2
                && allStageIdentityPassed
                && earliestDivergentStage != "none"
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
            "runs": runRecords,
            "stageDistributions": stageDistributions,
            "earliestDivergentStage": earliestDivergentStage,
            "finalDecodedRGBASHA256Counts": finalDistribution,
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
            "\(status) \(runRecords.count) runs; earliest split: \(earliestDivergentStage)"
        )
    }
}
