import CryptoKit
import Foundation

enum IndustrialL1V5CandidateError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l1-v5-candidate --repository-root <path> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

func candidateArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL1V5CandidateError.arguments
    }
    return arguments[index + 1]
}

func candidateSHA256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map {
        String(format: "%02x", $0)
    }.joined()
}

func candidateRelative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func candidateArray(_ value: Any?) -> [Int]? {
    (value as? [NSNumber])?.map(\.intValue)
}

func candidateDictionary(_ url: URL) throws -> [String: Any] {
    guard
        let value = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL1V5CandidateError.invalid(
            "invalid JSON \(url.path)"
        )
    }
    return value
}

@main
enum ValidateIndustrialL1V5CandidateMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try candidateArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try candidateArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        let toolRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027"
        )
        let evidenceRoot = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l01/l01/source-v05-candidate"
        )
        let directions = ["north", "east", "south", "west"]
        let expectedSockets: [String: [Double]] = [
            "north": [896, 704],
            "east": [896, 832],
            "south": [640, 832],
            "west": [640, 704],
        ]
        let expectedEntranceBases: [String: [Double]] = [
            "north": [0, 2, -28],
            "east": [28, 2, 0],
            "south": [0, 2, 28],
            "west": [-28, 2, 0],
        ]
        let lods = ["block", "neighborhood", "city"]
        let decoder = JSONDecoder()
        var records: [[String: Any]] = []
        var failures: [String] = []
        var primaryHashes = Set<String>()

        for direction in directions {
            let sceneURL = toolRoot
                .appendingPathComponent("scenes/industrial_l01/variant-0")
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let rawURL = toolRoot
                .appendingPathComponent("raw/industrial_l01/variant-0")
                .appendingPathComponent(direction)
                .appendingPathComponent("source-v05.png")
            let primaryRecordURL = toolRoot
                .appendingPathComponent(
                    "provenance/industrial_l01/variant-0"
                )
                .appendingPathComponent(direction)
                .appendingPathComponent(
                    "normalization-source-v05-native-tool.json"
                )
            let repeatRecordURL = evidenceRoot
                .appendingPathComponent("normalized-repeat")
                .appendingPathComponent(direction)
                .appendingPathComponent("normalization-repeat.json")
            let descriptor = try decoder.decode(
                SceneDescriptor.self,
                from: Data(contentsOf: sceneURL)
            )
            let primaryRecord = try candidateDictionary(primaryRecordURL)
            let repeatRecord = try candidateDictionary(repeatRecordURL)
            var itemFailures: [String] = []

            if descriptor.sourceRevision != "source-v05"
                || descriptor.productionSelected
                || descriptor.registration.groundPivotSource != [768, 896]
                || descriptor.registration.frontageSocketSource
                    != expectedSockets[direction]!
                || descriptor.entrance.baseWorld
                    != expectedEntranceBases[direction]!
                || descriptor.light.shadowVectorSource != [2, 1]
                || descriptor.light.shadowReceiver
                    != "task-owned-transparent-ground-plane"
                || descriptor.registration.orientationTransform != "none"
            {
                itemFailures.append(
                    "descriptor pivot/socket/frontage/shadow contract drift"
                )
            }
            let rawHash = try candidateSHA256(rawURL)
            for (label, record) in [
                ("primary", primaryRecord),
                ("repeat", repeatRecord),
            ] {
                if record["productionSelected"] as? Bool != false
                    || record["asset_id"] as? String != "industrial_l01"
                    || record["source_sha256"] as? String != rawHash
                    || candidateArray(record["ground_pivot_source"])
                        != [768, 896]
                    || (record["object_width"] as? NSNumber)?.intValue
                        != 410
                    || (
                        record["reference_subject_width"] as? NSNumber
                    )?.intValue != 234
                {
                    itemFailures.append(
                        "\(label) normalization authority drift"
                    )
                }
                guard
                    let registration =
                        record["registration"] as? [String: Any],
                    candidateArray(
                        registration["target_ground_pivot"]
                    ) == [768, 896],
                    let origin = candidateArray(
                        registration["target_origin"]
                    ),
                    let size = candidateArray(registration["target_size"]),
                    origin.count == 2,
                    size.count == 2,
                    origin[1] + size[1] == 896
                else {
                    itemFailures.append(
                        "\(label) normalized pivot registration mismatch"
                    )
                    continue
                }
            }

            var outputRecords: [[String: Any]] = []
            for lod in lods {
                let filename = "generated_v4_industrial_l01_\(lod).png"
                let primaryURL = toolRoot
                    .appendingPathComponent(
                        "normalized/industrial_l01/variant-0"
                    )
                    .appendingPathComponent(direction)
                    .appendingPathComponent("source-v05")
                    .appendingPathComponent(filename)
                let repeatURL = evidenceRoot
                    .appendingPathComponent("normalized-repeat")
                    .appendingPathComponent(direction)
                    .appendingPathComponent(filename)
                let primaryHash = try candidateSHA256(primaryURL)
                let repeatHash = try candidateSHA256(repeatURL)
                if primaryHash != repeatHash {
                    itemFailures.append(
                        "\(lod) normalized file repeat mismatch"
                    )
                }
                primaryHashes.insert(primaryHash)
                outputRecords.append([
                    "lod": lod,
                    "primaryFile": candidateRelative(
                        primaryURL,
                        root: root
                    ),
                    "repeatFile": candidateRelative(
                        repeatURL,
                        root: root
                    ),
                    "primarySHA256": primaryHash,
                    "repeatSHA256": repeatHash,
                    "fileIdentity": primaryHash == repeatHash,
                ])
            }
            failures.append(
                contentsOf: itemFailures.map { "\(direction): \($0)" }
            )
            records.append([
                "direction": direction,
                "sceneFile": candidateRelative(sceneURL, root: root),
                "rawFile": candidateRelative(rawURL, root: root),
                "rawSHA256": rawHash,
                "groundPivotSource":
                    descriptor.registration.groundPivotSource,
                "frontageSocketSource":
                    descriptor.registration.frontageSocketSource,
                "entranceBaseWorld": descriptor.entrance.baseWorld,
                "shadowVectorSource":
                    descriptor.light.shadowVectorSource,
                "normalizationOutputs": outputRecords,
                "failures": itemFailures,
                "passed": itemFailures.isEmpty,
            ])
        }
        if primaryHashes.count != 12 {
            failures.append(
                "normalized primary file hashes are not 12/12 unique"
            )
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l01",
            "sourceRevision": "source-v05",
            "purpose":
                "bind source-v05 socket, pivot, shadow, normalization registration, two-run file identity, and 12-output uniqueness",
            "directions": records,
            "uniqueNormalizedPrimaryFileHashCount": primaryHashes.count,
            "expectedUniqueNormalizedPrimaryFileHashCount": 12,
            "failures": failures,
            "passed": failures.isEmpty,
            "productionSelected": false,
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: reportURL, options: .atomic)
        if !failures.isEmpty {
            throw IndustrialL1V5CandidateError.invalid(
                failures.joined(separator: "\n")
            )
        }
    }
}
