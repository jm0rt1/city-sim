import CryptoKit
import Foundation

enum IndustrialL2V4PreservationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l2-v4-rejection-preservation --repository-root <path> --baseline <commit> --rejection-commit <commit> --archive-root <path> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

private func v4Argument(_ name: String, in arguments: [String]) throws -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        throw IndustrialL2V4PreservationError.arguments
    }
    return arguments[index + 1]
}

private func v4SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func v4Git(
    root: URL,
    arguments: [String]
) throws -> (status: Int32, output: String) {
    let process = Process()
    let pipe = Pipe()
    process.currentDirectoryURL = root
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    process.waitUntilExit()
    return (
        process.terminationStatus,
        String(
            decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
    )
}

private func v4JSON(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

@main
enum ValidateIndustrialL2V4RejectionPreservationMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try v4Argument("--repository-root", in: arguments)
        ).standardizedFileURL
        let baseline = try v4Argument("--baseline", in: arguments)
        let rejectionCommit = try v4Argument("--rejection-commit", in: arguments)
        let archiveRoot = URL(
            fileURLWithPath: try v4Argument("--archive-root", in: arguments)
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try v4Argument("--report", in: arguments)
        ).standardizedFileURL
        let rejectedEvidencePath =
            "docs/production/evidence/PLAY-027/industrial-l02/l02/source-v04-candidate"
        let dispositionPath =
            "\(rejectedEvidencePath)/RAW-GATE-DISPOSITION.json"
        let expectedDescriptorHashes = [
            "north": "62bda4794068215ea91419368f10a314a28bfac3808c4f8c68d4fd05aed030c3",
            "east": "08f17a9478d417f5f30d14ec231af02fb4c74a36108ab49ce5dd33940db0b6af",
            "south": "420b658a771ed93d6505afddfbb71a330b020df4271bdba943e2adb504533dd0",
            "west": "444bb2cb1fab124dafb36286beb84f183c00669a6e31dd3eb0178ef068b07e7c",
        ]

        let ancestry = try v4Git(
            root: root,
            arguments: ["merge-base", "--is-ancestor", rejectionCommit, "HEAD"]
        )
        guard ancestry.status == 0 else {
            throw IndustrialL2V4PreservationError.invalid(
                "source-v04 rejection commit is not an ancestor"
            )
        }
        let diff = try v4Git(
            root: root,
            arguments: ["diff", "--name-only", baseline, "--", rejectedEvidencePath]
        )
        let status = try v4Git(
            root: root,
            arguments: [
                "status",
                "--porcelain=v1",
                "--untracked-files=all",
                "--",
                rejectedEvidencePath,
            ]
        )
        guard
            diff.status == 0,
            diff.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            status.status == 0,
            status.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw IndustrialL2V4PreservationError.invalid(
                "source-v04 rejection evidence changed"
            )
        }
        let baselineTree = try v4Git(
            root: root,
            arguments: ["rev-parse", "\(baseline):\(rejectedEvidencePath)"]
        )
        let headTree = try v4Git(
            root: root,
            arguments: ["rev-parse", "HEAD:\(rejectedEvidencePath)"]
        )
        let baselineTreeID = baselineTree.output.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let headTreeID = headTree.output.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard
            baselineTree.status == 0,
            headTree.status == 0,
            baselineTreeID == headTreeID
        else {
            throw IndustrialL2V4PreservationError.invalid(
                "source-v04 rejection evidence tree identity changed"
            )
        }

        let dispositionURL = root.appendingPathComponent(dispositionPath)
        let dispositionData = try Data(contentsOf: dispositionURL)
        guard
            let disposition = try JSONSerialization.jsonObject(
                with: dispositionData
            ) as? [String: Any],
            disposition["sourceRevision"] as? String == "source-v04",
            disposition["status"] as? String == "FAIL-repeat-identity",
            disposition["sourceV04Accepted"] as? Bool == false,
            disposition["normalizationPerformed"] as? Bool == false,
            disposition["productionSelected"] as? Bool == false
        else {
            throw IndustrialL2V4PreservationError.invalid(
                "source-v04 rejection disposition no longer rejects the source"
            )
        }

        var archiveRecords: [[String: Any]] = []
        for direction in ["north", "east", "south", "west"] {
            let url = archiveRoot.appendingPathComponent(
                "\(direction)-source-v04.json"
            )
            let data = try Data(contentsOf: url)
            let hash = v4SHA256(data)
            guard hash == expectedDescriptorHashes[direction] else {
                throw IndustrialL2V4PreservationError.invalid(
                    "\(direction) archived source-v04 descriptor changed"
                )
            }
            archiveRecords.append([
                "direction": direction,
                "file": url.path.replacingOccurrences(
                    of: root.path + "/",
                    with: ""
                ),
                "sha256": hash,
                "matchesRejectedSourceV04Authority": true,
            ])
        }

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l02",
            "rejectedSourceRevision": "source-v04",
            "baseline": baseline,
            "rejectionCommit": rejectionCommit,
            "rejectionCommitIsAncestor": true,
            "rejectedEvidencePath": rejectedEvidencePath,
            "baselineRejectedEvidenceTreeID": baselineTreeID,
            "currentRejectedEvidenceTreeID": headTreeID,
            "rejectedEvidenceTreeByteIdentical": true,
            "rejectionDispositionFile": dispositionPath,
            "rejectionDispositionSHA256": v4SHA256(dispositionData),
            "rejectionStatus": "FAIL-repeat-identity",
            "sourceV04Accepted": false,
            "normalizationPerformed": false,
            "archivedDescriptors": archiveRecords,
            "archivedDescriptorCount": archiveRecords.count,
            "productionSelected": false,
            "passed": true,
        ]
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try v4JSON(report).write(to: reportURL, options: .atomic)
    }
}
