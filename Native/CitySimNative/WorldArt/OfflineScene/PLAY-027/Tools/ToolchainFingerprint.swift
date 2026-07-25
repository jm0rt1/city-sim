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
            return "usage: toolchain-fingerprint --source-authority <sha> --output <json> [--sampling-contract v2|v3] [--scene-shadows current|disabled]"
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
        let samplingContract: String? = {
            guard
                let index = arguments.firstIndex(of: "--sampling-contract"),
                index + 1 < arguments.count
            else {
                return nil
            }
            return arguments[index + 1]
        }()
        let sceneShadows: String = {
            guard
                let index = arguments.firstIndex(of: "--scene-shadows"),
                index + 1 < arguments.count
            else {
                return "current"
            }
            return arguments[index + 1]
        }()
        guard
            samplingContract == nil
                || ["v2", "v3"].contains(samplingContract!),
            ["current", "disabled"].contains(sceneShadows),
            samplingContract != nil || sceneShadows == "current"
        else {
            throw FingerprintError.arguments
        }
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
        var object: [String: Any] = [
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
        if let samplingContract {
            var repair: [String: Any] = [
                "algorithm":
                    "opaque-isolated-one-quantum-majority-3x3",
                "version": samplingContract == "v3" ? 3 : 2,
                "quantizationQuantum": 32,
                "neighborhoodSize": 3,
                "majorityThreshold": 7,
                "requiresFullyOpaqueNeighborhood": true,
                "immutableSourceBuffer": true,
                "requiresChromaFreeNeighborhood": true,
                "channels": "rgb-only",
                "preservesAlpha": true,
                "preservesChroma": true,
            ]
            if samplingContract == "v3" {
                repair["boundaryAssist"] = [
                    "algorithm":
                        "immutable-prequantized-one-value-boundary-6-plus-1",
                    "version": 1,
                    "baseQuantizedMajorityCount": 6,
                    "requiredBoundaryVoteCount": 1,
                    "effectiveSupportCount": 7,
                    "maximumCompetingSupportAfterBoundaryReclassification":
                        2,
                    "quantizerStep": 32,
                    "quantizerMidpointOffset": 8,
                    "boundaryBandWidthValues": 1,
                    "requiresSameChannelEvidence": true,
                    "immutablePrequantizedBuffer": true,
                    "recordsBoundaryVoteReason": true,
                ]
            }
            object["descriptorSamplingContract"] = [
                "contractID":
                    "play027-deterministic-4x-no-msaa-lanczos-\(samplingContract)",
                "sceneKitAntialiasing": "none",
                "sceneKitShadows": sceneShadows,
                "linearOversamplingFactor": 4,
                "downsample": [
                    "filter": "CILanczosScaleTransform",
                    "scale": 0.25,
                    "aspectRatio": 1,
                ],
                "ciContext": [
                    "useSoftwareRenderer": true,
                    "cacheIntermediates": false,
                    "workingColorSpace": "extended-srgb",
                    "outputColorSpace": "srgb",
                ],
                "quantizer": [
                    "id": "step32-midpoint-offset8-v1",
                    "quantizationQuantum": 32,
                    "midpointOffset": 8,
                ],
                "postQuantizationCanonicalizer": repair,
                "canonicalizer": [
                    "id": "imageio-sips-png-v1",
                    "encoder": "ImageIO",
                    "postEncoder": "/usr/bin/sips",
                    "format": "png",
                ],
            ]
        }
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
