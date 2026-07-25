import CoreGraphics
import CoreImage
import Foundation
import ModelIO
import SceneKit

enum FingerprintError: Error, CustomStringConvertible {
    case arguments
    case command(String, Int32, String)
    case framework(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: toolchain-fingerprint --source-authority <sha> --output <json>"
        case let .command(command, status, error):
            return "\(command) failed with status \(status): \(error)"
        case let .framework(name):
            return "framework metadata unavailable: \(name)"
        }
    }
}

func command(_ executable: String, _ arguments: [String]) throws -> String {
    let process = Process()
    let output = Pipe()
    let error = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = error
    try process.run()
    process.waitUntilExit()
    let stdout = String(
        data: output.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""
    let stderr = String(
        data: error.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""
    guard process.terminationStatus == 0 else {
        throw FingerprintError.command(
            ([executable] + arguments).joined(separator: " "),
            process.terminationStatus,
            stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
}

func frameworkRecord(_ name: String) throws -> [String: String] {
    let path = "/System/Library/Frameworks/\(name).framework"
    guard
        let bundle = Bundle(path: path),
        let identifier = bundle.bundleIdentifier,
        let version = bundle.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String
    else {
        throw FingerprintError.framework(name)
    }
    return [
        "bundleIdentifier": identifier,
        "bundleVersion": version,
        "path": path,
    ]
}

@main
enum ToolchainFingerprintMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard
            let authorityIndex = arguments.firstIndex(
                of: "--source-authority"
            ),
            authorityIndex + 1 < arguments.count,
            let outputIndex = arguments.firstIndex(of: "--output"),
            outputIndex + 1 < arguments.count
        else {
            throw FingerprintError.arguments
        }

        let authority = arguments[authorityIndex + 1]
        let outputPath = URL(fileURLWithPath: arguments[outputIndex + 1])
        let frameworkNames = [
            "SceneKit",
            "ModelIO",
            "CoreImage",
            "CoreGraphics",
        ]
        var frameworks: [String: [String: String]] = [:]
        for name in frameworkNames {
            frameworks[name] = try frameworkRecord(name)
        }

        let xcodeLines = try command(
            "/usr/bin/xcodebuild",
            ["-version"]
        ).components(separatedBy: .newlines)
        let object: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "sourceAuthority": authority,
            "host": [
                "productName": try command(
                    "/usr/bin/sw_vers",
                    ["-productName"]
                ),
                "productVersion": try command(
                    "/usr/bin/sw_vers",
                    ["-productVersion"]
                ),
                "buildVersion": try command(
                    "/usr/bin/sw_vers",
                    ["-buildVersion"]
                ),
                "architecture": try command("/usr/bin/uname", ["-m"]),
            ],
            "xcode": [
                "version": xcodeLines.first ?? "",
                "buildVersion": xcodeLines.dropFirst().first ?? "",
            ],
            "swift": [
                "compilerPath": try command(
                    "/usr/bin/xcrun",
                    ["--find", "swiftc"]
                ),
                "version": try command(
                    "/usr/bin/xcrun",
                    ["swiftc", "--version"]
                ),
            ],
            "sdk": [
                "path": try command(
                    "/usr/bin/xcrun",
                    ["--sdk", "macosx", "--show-sdk-path"]
                ),
                "version": try command(
                    "/usr/bin/xcrun",
                    ["--sdk", "macosx", "--show-sdk-version"]
                ),
                "buildVersion": try command(
                    "/usr/bin/xcrun",
                    ["--sdk", "macosx", "--show-sdk-build-version"]
                ),
            ],
            "frameworks": frameworks,
            "availableTypes": [
                "SceneKit": String(describing: SCNScene.self),
                "ModelIO": String(describing: MDLAsset.self),
                "CoreImage": String(describing: CIContext.self),
                "CoreGraphics": String(describing: CGColorSpace.self),
            ],
            "newProductRuntimeDependency": false,
            "packageManifestChanged": false,
            "productionSelected": false,
        ]
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var terminated = data
        terminated.append(0x0a)
        try FileManager.default.createDirectory(
            at: outputPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try terminated.write(to: outputPath, options: .atomic)
    }
}
