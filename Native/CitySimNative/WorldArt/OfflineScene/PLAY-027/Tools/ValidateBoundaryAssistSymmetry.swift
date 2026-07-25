import Foundation

enum BoundarySymmetryError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-boundary-assist-symmetry --capture-root <diagnostics-dir> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

func symmetryArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw BoundarySymmetryError.arguments
    }
    return arguments[index + 1]
}

func symmetryStage(
    _ name: String,
    in capture: [String: Any]
) throws -> [String: Any] {
    guard
        let stages = capture["stages"] as? [[String: Any]],
        let stage = stages.first(where: {
            $0["stage"] as? String == name
        })
    else {
        throw BoundarySymmetryError.invalid("missing stage \(name)")
    }
    return stage
}

func symmetryGreenValues(
    _ stage: [String: Any]
) throws -> [String: Int] {
    guard let local = stage["local3x3"] as? [[String: Any]] else {
        throw BoundarySymmetryError.invalid("missing local 3x3")
    }
    return try Dictionary(
        uniqueKeysWithValues: local.map { pixel in
            guard
                let coordinate = pixel["coordinate"] as? [Int],
                coordinate.count == 2,
                let rgba = pixel["rgba"] as? [Int],
                rgba.count == 4
            else {
                throw BoundarySymmetryError.invalid(
                    "invalid local 3x3 pixel"
                )
            }
            return ("\(coordinate[0]),\(coordinate[1])", rgba[1])
        }
    )
}

@main
enum ValidateBoundaryAssistSymmetryMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let captureRoot = URL(
            fileURLWithPath: try symmetryArgument(
                "--capture-root",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try symmetryArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        guard
            captureRoot.path.contains("/diagnostics/"),
            reportURL.path.contains("/diagnostics/")
        else {
            throw BoundarySymmetryError.invalid(
                "input and output must remain under diagnostics"
            )
        }
        guard
            let enumerator = FileManager.default.enumerator(
                at: captureRoot,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else {
            throw BoundarySymmetryError.invalid(
                "could not enumerate captures"
            )
        }
        let captures = enumerator.compactMap { item -> URL? in
            guard let url = item as? URL else {
                return nil
            }
            return url.lastPathComponent == "STAGE-CAPTURE.json"
                ? url
                : nil
        }.sorted { $0.path < $1.path }
        guard captures.count == 12 else {
            throw BoundarySymmetryError.invalid(
                "expected the preserved 12-run stage packet"
            )
        }

        let boundaryCoordinate = "733,778"
        let targetCoordinate = [732, 778]
        let expectedFileHashes = [
            23:
                "52011ce067bad07dcca911dbf40cef6b2f9c8c843c8f136859027e21d8f02830",
            24:
                "23f9a952eaa5650babeb2efea11b4f66215dc31162bc305a45ec719da392b2e7",
        ]
        var failures: [String] = []
        var records: [[String: Any]] = []
        var boundaryValueCounts: [Int: Int] = [:]
        var referenceOtherGreens: [String: Int]?

        for captureURL in captures {
            let run = captureURL.deletingLastPathComponent()
                .lastPathComponent
            guard
                let capture = try JSONSerialization.jsonObject(
                    with: Data(contentsOf: captureURL)
                ) as? [String: Any],
                capture["targetCoordinate"] as? [Int]
                    == targetCoordinate
            else {
                failures.append("\(run): invalid capture")
                continue
            }
            let pre = try symmetryStage(
                "prequantized-in-memory",
                in: capture
            )
            let quantized = try symmetryStage(
                "quantized-before-majority-in-memory",
                in: capture
            )
            let post = try symmetryStage(
                "post-majority-in-memory",
                in: capture
            )
            let final = try symmetryStage(
                "final-sips-decoded",
                in: capture
            )
            let preGreens = try symmetryGreenValues(pre)
            let quantizedGreens = try symmetryGreenValues(quantized)
            guard
                let boundaryValue = preGreens[boundaryCoordinate],
                [23, 24].contains(boundaryValue),
                let preTarget = pre["targetRGBA"] as? [Int],
                let quantizedTarget =
                    quantized["targetRGBA"] as? [Int],
                let postTarget = post["targetRGBA"] as? [Int],
                let finalHash = final["fileSHA256"] as? String,
                let evaluations =
                    capture["postMajorityTargetEvaluations"]
                    as? [[String: Any]],
                let greenEvaluation = evaluations.first(where: {
                    ($0["channel"] as? Int) == 1
                }),
                let majorityCount =
                    greenEvaluation["majorityCount"] as? Int,
                let identity = capture["stageIdentity"]
                    as? [String: Any]
            else {
                failures.append("\(run): required evidence missing")
                continue
            }
            boundaryValueCounts[boundaryValue, default: 0] += 1
            let expectedMajority = boundaryValue == 23 ? 6 : 7
            let expectedPostTarget =
                boundaryValue == 23
                ? [16, 16, 16, 255]
                : [16, 48, 16, 255]
            var otherGreens = preGreens
            otherGreens.removeValue(forKey: boundaryCoordinate)
            if let referenceOtherGreens {
                if otherGreens != referenceOtherGreens {
                    failures.append(
                        "\(run): same-channel prequantized neighborhood differs beyond the boundary vote"
                    )
                }
            } else {
                referenceOtherGreens = otherGreens
            }
            let quantized48Count =
                quantizedGreens.values.filter { $0 == 48 }.count
            var runFailures: [String] = []
            if preTarget != [4, 22, 2, 255] {
                runFailures.append("prequantized target changed")
            }
            if quantizedTarget != [16, 16, 16, 255] {
                runFailures.append("quantized target changed")
            }
            if quantized48Count != expectedMajority
                || majorityCount != expectedMajority
            {
                runFailures.append("6/7 support mismatch")
            }
            if postTarget != expectedPostTarget {
                runFailures.append("post-majority target mismatch")
            }
            if finalHash != expectedFileHashes[boundaryValue] {
                runFailures.append("final identity mismatch")
            }
            if
                identity["postMajorityEqualsImageIODecode"]
                    as? Bool != true
                || identity["imageIODecodeEqualsFinalSipsDecode"]
                    as? Bool != true
            {
                runFailures.append("downstream stage identity failed")
            }
            failures.append(contentsOf: runFailures.map {
                "\(run): \($0)"
            })
            records.append([
                "run": run,
                "boundaryCoordinate": [733, 778],
                "boundaryPrequantizedGreen": boundaryValue,
                "quantizedMajority48Count": quantized48Count,
                "targetPrequantizedRGBA": preTarget,
                "targetQuantizedRGBA": quantizedTarget,
                "targetPostMajorityRGBA": postTarget,
                "finalPNGFileSHA256": finalHash,
                "status": runFailures.isEmpty ? "pass" : "fail",
            ])
        }
        if boundaryValueCounts[23, default: 0] == 0
            || boundaryValueCounts[24, default: 0] == 0
        {
            failures.append("both retained 23/24 identities are required")
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "purpose": "schema-2-v3-preimplementation-symmetry-gate",
            "runCount": records.count,
            "targetCoordinate": targetCoordinate,
            "boundaryCoordinate": [733, 778],
            "boundaryPair": [23, 24],
            "boundaryValueCounts": [
                "23": boundaryValueCounts[23, default: 0],
                "24": boundaryValueCounts[24, default: 0],
            ],
            "sameChannelOnly": true,
            "bothIdentitiesDescribedSymmetrically":
                failures.isEmpty,
            "failures": failures,
            "records": records,
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
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: reportURL, options: .atomic)
        guard failures.isEmpty else {
            throw BoundarySymmetryError.invalid(
                failures.joined(separator: "; ")
            )
        }
        print("PASS 12/12 retained 23/24 symmetry records")
    }
}
