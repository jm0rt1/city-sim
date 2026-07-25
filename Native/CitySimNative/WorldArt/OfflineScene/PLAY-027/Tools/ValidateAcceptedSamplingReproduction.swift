import CryptoKit
import Foundation

enum AcceptedSamplingReproductionError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-accepted-sampling-reproduction --repository-root <path> --baseline <commit> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

private func reproductionArgument(_ name: String, in arguments: [String]) throws -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        throw AcceptedSamplingReproductionError.arguments
    }
    return arguments[index + 1]
}

private func reproductionSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func reproductionGit(
    root: URL,
    arguments: [String]
) throws -> (status: Int32, data: Data, error: String) {
    let process = Process()
    let output = Pipe()
    let error = Pipe()
    process.currentDirectoryURL = root
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = error
    try process.run()
    process.waitUntilExit()
    return (
        process.terminationStatus,
        output.fileHandleForReading.readDataToEndOfFile(),
        String(
            decoding: error.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
    )
}

private func reproductionJSON(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func acceptedScenePath(_ relative: String) -> Bool {
    let acceptedRoots = [
        "residential_l01",
        "residential_l02",
        "residential_l03",
        "residential_l04",
        "commercial_l01",
        "commercial_l02",
        "commercial_l03",
        "commercial_l04",
        "industrial_l01",
    ]
    return acceptedRoots.contains { relative.contains("/scenes/\($0)/") }
}

@main
enum ValidateAcceptedSamplingReproductionMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try reproductionArgument("--repository-root", in: arguments)
        ).standardizedFileURL
        let baseline = try reproductionArgument("--baseline", in: arguments)
        let reportURL = URL(
            fileURLWithPath: try reproductionArgument("--report", in: arguments)
        ).standardizedFileURL
        let sceneRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes"
        )
        let prefix = root.path + "/"

        let baselineCheck = try reproductionGit(
            root: root,
            arguments: ["cat-file", "-e", "\(baseline)^{commit}"]
        )
        guard baselineCheck.status == 0 else {
            throw AcceptedSamplingReproductionError.invalid(
                "baseline unavailable: \(baselineCheck.error)"
            )
        }

        guard let enumerator = FileManager.default.enumerator(
            at: sceneRoot,
            includingPropertiesForKeys: nil
        ) else {
            throw AcceptedSamplingReproductionError.invalid("could not enumerate scenes")
        }
        let sceneURLs = enumerator.compactMap { value -> URL? in
            guard let url = value as? URL, url.lastPathComponent == "scene.json" else {
                return nil
            }
            let relative = String(url.path.dropFirst(prefix.count))
            return acceptedScenePath(relative) ? url : nil
        }.sorted { $0.path < $1.path }
        guard sceneURLs.count == 36 else {
            throw AcceptedSamplingReproductionError.invalid(
                "expected 36 accepted scene descriptors, found \(sceneURLs.count)"
            )
        }

        var records: [[String: Any]] = []
        var failures: [String] = []
        for url in sceneURLs {
            let relative = String(url.path.dropFirst(prefix.count))
            let currentData = try Data(contentsOf: url)
            let historical = try reproductionGit(
                root: root,
                arguments: ["show", "\(baseline):\(relative)"]
            )
            guard historical.status == 0 else {
                throw AcceptedSamplingReproductionError.invalid(
                    "could not read baseline blob \(relative): \(historical.error)"
                )
            }
            let bytesIdentical = currentData == historical.data
            let descriptor = try JSONDecoder().decode(SceneDescriptor.self, from: currentData)
            let resolved = try DescriptorSamplingResolver.resolve(descriptor: descriptor)
            let legacyLightingDefaulted =
                descriptor.sampling?.sceneKitLightingMode == nil
                && resolved.sceneKitLightingMode == "lambert-scene-lights"
            let unchangedLegacyContract =
                resolved.sceneKitLightingMode == "lambert-scene-lights"
            if !bytesIdentical {
                failures.append("accepted descriptor bytes changed: \(relative)")
            }
            if !unchangedLegacyContract {
                failures.append("accepted lighting contract changed: \(relative)")
            }
            let descriptorLighting: Any =
                descriptor.sampling?.sceneKitLightingMode as Any? ?? NSNull()
            records.append([
                "file": relative,
                "logicalBuildingID": descriptor.logicalBuildingID,
                "direction": descriptor.viewDirection,
                "sourceRevision": descriptor.sourceRevision,
                "baselineSHA256": reproductionSHA256(historical.data),
                "currentSHA256": reproductionSHA256(currentData),
                "bytesIdentical": bytesIdentical,
                "descriptorSceneKitLightingMode": descriptorLighting,
                "resolvedSceneKitLightingMode": resolved.sceneKitLightingMode,
                "resolvedSceneMaterialLightingModel": "lambert",
                "resolvedSceneLightsEnabled": true,
                "legacyLightingDefaultApplied": legacyLightingDefaulted,
            ])
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "baseline": baseline,
            "scope":
                "accepted Residential L1-L4, Commercial L1-L4, and Industrial L1 canonical scene descriptors",
            "descriptorCount": records.count,
            "byteIdenticalDescriptorCount":
                records.filter { $0["bytesIdentical"] as? Bool == true }.count,
            "lambertSceneLightsDescriptorCount":
                records.filter {
                    $0["resolvedSceneKitLightingMode"] as? String
                        == "lambert-scene-lights"
                }.count,
            "acceptedDescriptors": records,
            "failures": failures,
            "acceptedSourceMutationCount": failures.count,
            "productionSelected": false,
            "passed": failures.isEmpty,
        ]
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try reproductionJSON(report).write(to: reportURL, options: .atomic)
        if !failures.isEmpty {
            throw AcceptedSamplingReproductionError.invalid(
                failures.joined(separator: "\n")
            )
        }
    }
}
