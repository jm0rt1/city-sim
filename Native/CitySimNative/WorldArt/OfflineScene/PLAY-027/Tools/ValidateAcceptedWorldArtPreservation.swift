import Foundation

enum AcceptedWorldArtPreservationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-accepted-world-art-preservation --repository-root <path> --baseline <commit> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

func preservationArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw AcceptedWorldArtPreservationError.arguments
    }
    return arguments[index + 1]
}

func preservationGit(
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
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return (
        process.terminationStatus,
        String(decoding: data, as: UTF8.self)
    )
}

func isAcceptedWorldArtSource(_ path: String) -> Bool {
    guard path.hasPrefix(
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    ) else {
        return false
    }
    let normalized = path.lowercased()
    return
        normalized.contains("residential_l0")
        || normalized.contains("commercial_l0")
        || normalized.contains("residential-l0")
        || normalized.contains("commercial-l0")
        || normalized.contains("industrial_l01")
        || normalized.contains("industrial-l01")
}

@main
enum ValidateAcceptedWorldArtPreservationMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try preservationArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let baseline = try preservationArgument(
            "--baseline",
            in: arguments
        )
        let reportURL = URL(
            fileURLWithPath: try preservationArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        let sourceRoot =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027"

        let baselineCheck = try preservationGit(
            root: root,
            arguments: ["cat-file", "-e", "\(baseline)^{commit}"]
        )
        guard baselineCheck.status == 0 else {
            throw AcceptedWorldArtPreservationError.invalid(
                "baseline commit is unavailable: \(baselineCheck.output)"
            )
        }
        let changed = try preservationGit(
            root: root,
            arguments: [
                "diff",
                "--name-only",
                baseline,
                "--",
                sourceRoot,
            ]
        )
        guard changed.status == 0 else {
            throw AcceptedWorldArtPreservationError.invalid(
                "git diff failed: \(changed.output)"
            )
        }
        let status = try preservationGit(
            root: root,
            arguments: [
                "status",
                "--porcelain=v1",
                "--untracked-files=all",
                "--",
                sourceRoot,
            ]
        )
        guard status.status == 0 else {
            throw AcceptedWorldArtPreservationError.invalid(
                "git status failed: \(status.output)"
            )
        }
        let changedAcceptedPaths = changed.output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter(isAcceptedWorldArtSource)
        let untrackedAcceptedPaths = status.output
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> String? in
                let text = String(line)
                guard text.count > 3 else {
                    return nil
                }
                return String(text.dropFirst(3))
            }
            .filter(isAcceptedWorldArtSource)
        let failures =
            changedAcceptedPaths.map {
                "accepted tracked source changed: \($0)"
            }
            + untrackedAcceptedPaths.map {
                "accepted untracked source present: \($0)"
            }
        let head = try preservationGit(
            root: root,
            arguments: ["rev-parse", "HEAD"]
        )
        guard head.status == 0 else {
            throw AcceptedWorldArtPreservationError.invalid(
                "could not resolve HEAD: \(head.output)"
            )
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "baseline": baseline,
            "checkedAtHead": head.output.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            "scope":
                "all task-owned OfflineScene PLAY-027 paths whose names bind accepted Residential L1-L4, Commercial L1-L4, or Industrial L1 sources, descriptors, materials, raw, normalized, or provenance",
            "trackedAcceptedChangedPaths": changedAcceptedPaths,
            "untrackedAcceptedPaths": untrackedAcceptedPaths,
            "acceptedSourceMutationCount": failures.count,
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
            throw AcceptedWorldArtPreservationError.invalid(
                failures.joined(separator: "\n")
            )
        }
    }
}
