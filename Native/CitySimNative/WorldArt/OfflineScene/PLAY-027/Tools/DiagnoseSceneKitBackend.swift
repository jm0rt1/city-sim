import Darwin
import Foundation
import Metal
import SceneKit

enum SceneKitBackendDiagnosticError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: diagnose-scenekit-backend --report <json> --diagnostic-ack PLAY-027-SCENEKIT-BACKEND-V1"
        case let .invalid(message):
            return message
        }
    }
}

func sceneKitBackendArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw SceneKitBackendDiagnosticError.arguments
    }
    return arguments[index + 1]
}

func sceneKitBackendPrepareRecord(
    label: String,
    object: Any,
    renderer: SCNRenderer,
    useNoncancelingBlock: Bool
) -> [String: Any] {
    var abortBlockInvocationCount = 0
    let passed: Bool
    if useNoncancelingBlock {
        passed = renderer.prepare(object) {
            abortBlockInvocationCount += 1
            return false
        }
    } else {
        passed = renderer.prepare(
            object,
            shouldAbortBlock: nil
        )
    }
    return [
        "label": label,
        "objectType": String(describing: type(of: object)),
        "noncancelingBlockProvided": useNoncancelingBlock,
        "abortBlockInvocationCount": abortBlockInvocationCount,
        "abortBlockEverReturnedTrue": false,
        "passed": passed,
    ]
}

@main
enum DiagnoseSceneKitBackendMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let reportURL = URL(
            fileURLWithPath: try sceneKitBackendArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        let acknowledgement = try sceneKitBackendArgument(
            "--diagnostic-ack",
            in: arguments
        )
        guard
            acknowledgement == "PLAY-027-SCENEKIT-BACKEND-V1",
            reportURL.path.contains(
                "/docs/production/evidence/PLAY-027/industrial-l02/l02/source-v03-candidate/diagnostics/"
            ),
            reportURL.pathExtension == "json",
            !FileManager.default.fileExists(atPath: reportURL.path)
        else {
            throw SceneKitBackendDiagnosticError.invalid(
                "diagnostic acknowledgement/path/no-overwrite guard failed"
            )
        }

        let defaultDevice = MTLCreateSystemDefaultDevice()
        let allDevices = MTLCopyAllDevices()
        let renderer = SCNRenderer(device: nil, options: nil)
        let explicitRenderer = SCNRenderer(
            device: defaultDevice,
            options: nil
        )
        let emptySceneNilBlock = sceneKitBackendPrepareRecord(
            label: "empty-scene-nil-abort-block",
            object: SCNScene(),
            renderer: renderer,
            useNoncancelingBlock: false
        )
        let emptySceneNoncancelingBlock = sceneKitBackendPrepareRecord(
            label: "empty-scene-never-cancel-block",
            object: SCNScene(),
            renderer: renderer,
            useNoncancelingBlock: true
        )
        let emptyNode = sceneKitBackendPrepareRecord(
            label: "empty-node-nil-abort-block",
            object: SCNNode(),
            renderer: renderer,
            useNoncancelingBlock: false
        )
        let emptyMaterial = sceneKitBackendPrepareRecord(
            label: "empty-material-nil-abort-block",
            object: SCNMaterial(),
            renderer: renderer,
            useNoncancelingBlock: false
        )
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "purpose":
                "diagnostic-only SceneKit and Metal backend availability without candidate render",
            "diagnosticContract": "PLAY-027-SCENEKIT-BACKEND-V1",
            "sourceAuthority": false,
            "productionSelected": false,
            "candidateDescriptorRead": false,
            "candidateOutputWritten": false,
            "metal": [
                "systemDefaultDeviceAvailable": defaultDevice != nil,
                "systemDefaultDeviceName":
                    defaultDevice?.name ?? "none",
                "allDeviceCount": allDevices.count,
                "allDeviceNames": allDevices.map(\.name),
            ],
            "sceneKit": [
                "implicitRendererDeviceAvailable":
                    renderer.device != nil,
                "implicitRendererDeviceName":
                    renderer.device?.name ?? "none",
                "explicitRendererDeviceAvailable":
                    explicitRenderer.device != nil,
                "explicitRendererDeviceName":
                    explicitRenderer.device?.name ?? "none",
                "renderingAPIRawValue": renderer.renderingAPI.rawValue,
                "prepareControls": [
                    emptySceneNilBlock,
                    emptySceneNoncancelingBlock,
                    emptyNode,
                    emptyMaterial,
                ],
            ],
            "causalBoundary": [
                "gpuBackendAvailable": defaultDevice != nil,
                "prepareFalseWithoutCandidateContent":
                    !((emptySceneNilBlock["passed"] as? Bool) ?? true),
                "prepareFalseWithoutCancellation":
                    !((emptySceneNoncancelingBlock["passed"] as? Bool)
                        ?? true)
                    && !((emptySceneNoncancelingBlock[
                        "abortBlockEverReturnedTrue"
                    ] as? Bool) ?? true),
            ],
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
    }
}
