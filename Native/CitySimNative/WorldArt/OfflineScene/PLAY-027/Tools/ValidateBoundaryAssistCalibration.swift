import CryptoKit
import Foundation

enum BoundaryCalibrationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-boundary-assist-calibration --repository-root <path> --run-root <diagnostics-dir> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

func calibrationArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw BoundaryCalibrationError.arguments
    }
    return arguments[index + 1]
}

func calibrationSHA256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map {
        String(format: "%02x", $0)
    }.joined()
}

func calibrationRelativePath(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

@main
enum ValidateBoundaryAssistCalibrationMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try calibrationArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let runRoot = URL(
            fileURLWithPath: try calibrationArgument(
                "--run-root",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try calibrationArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        guard
            runRoot.path.contains("/diagnostics/"),
            reportURL.path.contains("/diagnostics/")
        else {
            throw BoundaryCalibrationError.invalid(
                "calibration and report must remain under diagnostics"
            )
        }
        let runDirectories = try FileManager.default.contentsOfDirectory(
            at: runRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter {
            $0.lastPathComponent.hasPrefix("run-")
        }.sorted { $0.path < $1.path }
        guard runDirectories.count == 12 else {
            throw BoundaryCalibrationError.invalid(
                "exactly 12 fresh-process runs are required"
            )
        }

        var failures: [String] = []
        var records: [[String: Any]] = []
        var fileHashes: [String: Int] = [:]
        var decodedHashes: [String: Int] = [:]
        var boundaryCounts: [Int: Int] = [:]
        var retainedFileCount = 0
        for runDirectory in runDirectories {
            let run = runDirectory.lastPathComponent
            let captureURL = runDirectory.appendingPathComponent(
                "STAGE-CAPTURE.json"
            )
            let sourceURL = runDirectory.appendingPathComponent("source.png")
            let imageIOURL = runDirectory.appendingPathComponent(
                "imageio-pre-sips.png"
            )
            let provenanceURL = runDirectory.appendingPathComponent(
                "provenance.json"
            )
            let files = [
                captureURL,
                sourceURL,
                imageIOURL,
                provenanceURL,
            ]
            guard files.allSatisfy({
                FileManager.default.fileExists(atPath: $0.path)
            }) else {
                failures.append("\(run): retained file missing")
                continue
            }
            retainedFileCount += files.count
            let inventory: [[String: String]] = try files.map {
                [
                    "file": calibrationRelativePath(
                        $0,
                        repositoryRoot: repositoryRoot
                    ),
                    "sha256": try calibrationSHA256($0),
                ]
            }
            guard
                let capture = try JSONSerialization.jsonObject(
                    with: Data(contentsOf: captureURL)
                ) as? [String: Any],
                let stages = capture["stages"] as? [[String: Any]],
                let pre = stages.first(where: {
                    $0["stage"] as? String
                        == "prequantized-in-memory"
                }),
                let post = stages.first(where: {
                    $0["stage"] as? String
                        == "post-majority-in-memory"
                }),
                let final = stages.first(where: {
                    $0["stage"] as? String
                        == "final-sips-decoded"
                }),
                let local = pre["local3x3"] as? [[String: Any]],
                let boundaryPixel = local.first(where: {
                    $0["coordinate"] as? [Int] == [733, 778]
                }),
                let boundaryRGBA = boundaryPixel["rgba"] as? [Int],
                let evaluations =
                    capture["postMajorityTargetEvaluations"]
                    as? [[String: Any]],
                let green = evaluations.first(where: {
                    $0["channel"] as? Int == 1
                }),
                let boundaryGreen = boundaryRGBA[safe: 1],
                [23, 24].contains(boundaryGreen),
                let finalFileSHA = final["fileSHA256"] as? String,
                let finalDecodedSHA =
                    final["decodedRGBASHA256"] as? String,
                let finalTarget = final["targetRGBA"] as? [Int],
                let postTarget = post["targetRGBA"] as? [Int],
                let majorityCount = green["majorityCount"] as? Int,
                let assistEligible =
                    green["boundaryAssistEligible"] as? Bool,
                let standardEligible =
                    green["standardMajorityEligible"] as? Bool,
                let reason = green["eligibilityReason"] as? String,
                let identity = capture["stageIdentity"]
                    as? [String: Any],
                let provenance = try JSONSerialization.jsonObject(
                    with: Data(contentsOf: provenanceURL)
                ) as? [String: Any],
                let sampling =
                    provenance["descriptorSamplingContract"]
                    as? [String: Any],
                sampling["contractID"] as? String
                    == "play027-deterministic-4x-no-msaa-lanczos-v3"
            else {
                failures.append("\(run): capture structure invalid")
                continue
            }
            fileHashes[finalFileSHA, default: 0] += 1
            decodedHashes[finalDecodedSHA, default: 0] += 1
            boundaryCounts[boundaryGreen, default: 0] += 1
            let expectedMajority = boundaryGreen == 23 ? 6 : 7
            let expectedReason =
                boundaryGreen == 23
                ? "boundary-assisted-6-plus-1"
                : "standard-majority-7"
            var runFailures: [String] = []
            if majorityCount != expectedMajority {
                runFailures.append("majority count mismatch")
            }
            if
                boundaryGreen == 23
                    && (!assistEligible || standardEligible)
                || boundaryGreen == 24
                    && (assistEligible || !standardEligible)
            {
                runFailures.append("eligibility path mismatch")
            }
            if reason != expectedReason {
                runFailures.append("eligibility reason mismatch")
            }
            if postTarget != [16, 48, 16, 255]
                || finalTarget != [16, 48, 16, 255]
            {
                runFailures.append("target did not converge")
            }
            if
                identity["postMajorityEqualsImageIODecode"]
                    as? Bool != true
                || identity["imageIODecodeEqualsFinalSipsDecode"]
                    as? Bool != true
            {
                runFailures.append("downstream stage identity failed")
            }
            if boundaryGreen == 23 {
                let assists =
                    sampling[
                        "postQuantizationBoundaryAssistMutations"
                    ] as? [[String: Any]] ?? []
                let targetAssist = assists.first {
                    $0["target"] as? [Int] == [732, 778]
                        && $0["channel"] as? Int == 1
                }
                let vote = targetAssist?["prequantizedVote"]
                    as? [String: Any]
                if
                    vote?["coordinate"] as? [Int] != [733, 778]
                    || vote?["prequantizedValue"] as? Int != 23
                    || vote?["boundaryPair"] as? [Int] != [23, 24]
                    || targetAssist?["effectiveSupportCount"] as? Int != 7
                    || targetAssist?[
                        "competingSupportAfterBoundaryReclassification"
                    ] as? Int != 2
                {
                    runFailures.append(
                        "boundary-assist provenance mismatch"
                    )
                }
            }
            failures.append(contentsOf: runFailures.map {
                "\(run): \($0)"
            })
            records.append([
                "run": run,
                "boundaryPrequantizedGreen": boundaryGreen,
                "majorityCount": majorityCount,
                "eligibilityReason": reason,
                "finalPNGFileSHA256": finalFileSHA,
                "finalDecodedRGBASHA256": finalDecodedSHA,
                "retainedFiles": inventory,
                "status": runFailures.isEmpty ? "pass" : "fail",
            ])
        }
        if fileHashes.count != 1 {
            failures.append("final PNG files are not byte-identical")
        }
        if decodedHashes.count != 1 {
            failures.append("final decoded RGBA is not pixel-identical")
        }
        if boundaryCounts[23, default: 0] == 0
            || boundaryCounts[24, default: 0] == 0
        {
            failures.append("both 23/24 prequantized paths must occur")
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contractID":
                "play027-deterministic-4x-no-msaa-lanczos-v3",
            "runCount": records.count,
            "retainedFileCount": retainedFileCount,
            "boundaryValueCounts": [
                "23": boundaryCounts[23, default: 0],
                "24": boundaryCounts[24, default: 0],
            ],
            "finalPNGFileSHA256Counts": fileHashes,
            "finalDecodedRGBASHA256Counts": decodedHashes,
            "bothBoundaryPathsObserved":
                boundaryCounts[23, default: 0] > 0
                && boundaryCounts[24, default: 0] > 0,
            "byteIdentity": fileHashes.count == 1,
            "pixelIdentity": decodedHashes.count == 1,
            "records": records,
            "failures": failures,
            "status": failures.isEmpty ? "pass" : "fail",
            "productionSelected": false,
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
        try data.write(to: reportURL, options: .atomic)
        guard failures.isEmpty else {
            throw BoundaryCalibrationError.invalid(
                failures.joined(separator: "; ")
            )
        }
        print("PASS 12/12 v3 calibration runs are byte/pixel-identical")
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
