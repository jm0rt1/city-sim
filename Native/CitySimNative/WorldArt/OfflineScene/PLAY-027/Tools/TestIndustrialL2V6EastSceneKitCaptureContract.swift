import Foundation

enum IndustrialL2V6EastSceneKitCaptureTestError:
    Error,
    CustomStringConvertible
{
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message):
            return message
        }
    }
}

@main
enum TestIndustrialL2V6EastSceneKitCaptureContractMain {
    static func main() throws {
        let decoder = JSONDecoder()
        let sourceRoot = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let root = URL(
            fileURLWithPath:
                "/tmp/play027-source-v06-east-capture-test-"
                + String(ProcessInfo.processInfo.processIdentifier),
            isDirectory: true
        )
        let sceneURL = root.appendingPathComponent(
            IndustrialL2V6EastSceneKitCaptureContract.scenePath
        )
        let materialsURL = root.appendingPathComponent(
            IndustrialL2V6EastSceneKitCaptureContract.materialPath
        )
        try FileManager.default.createDirectory(
            at: sceneURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: materialsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(
            at: sourceRoot.appendingPathComponent(
                IndustrialL2V6EastSceneKitCaptureContract.scenePath
            ),
            to: sceneURL
        )
        try FileManager.default.copyItem(
            at: sourceRoot.appendingPathComponent(
                IndustrialL2V6EastSceneKitCaptureContract.materialPath
            ),
            to: materialsURL
        )
        let descriptorData = try Data(contentsOf: sceneURL)
        let descriptor = try decoder.decode(
            SceneDescriptor.self,
            from: descriptorData
        )
        let sampling = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        let capture = root.appendingPathComponent(
            IndustrialL2V6EastSceneKitCaptureContract.evidenceRoot
                + "/run-a"
        )
        let output = capture.appendingPathComponent("final-sips.png")
        let record = capture.appendingPathComponent("provenance.json")

        guard
            try IndustrialL2V6EastSceneKitCaptureContract.validate(
                requestedContractID: nil,
                repositoryRoot: root,
                sceneURL: sceneURL,
                sceneFileSHA256:
                    IndustrialL2V6EastSceneKitCaptureContract
                    .sceneSHA256,
                materialsURL: materialsURL,
                materialFileSHA256:
                    IndustrialL2V6EastSceneKitCaptureContract
                    .materialSHA256,
                outputURL: output,
                recordURL: record,
                stageCaptureDirectory: nil,
                stageCoordinate: nil,
                explicitAntialiasing: nil,
                explicitSceneShadows: nil,
                explicitMaterialLighting: nil,
                prequantizedOutputRequested: false,
                descriptor: descriptor,
                sampling: sampling
            ) == nil
        else {
            throw IndustrialL2V6EastSceneKitCaptureTestError.failed(
                "default renderer path was not a no-op"
            )
        }

        let valid =
            try IndustrialL2V6EastSceneKitCaptureContract.validate(
                requestedContractID:
                    IndustrialL2V6EastSceneKitCaptureContract.contractID,
                repositoryRoot: root,
                sceneURL: sceneURL,
                sceneFileSHA256:
                    IndustrialL2V6EastSceneKitCaptureContract
                    .sceneSHA256,
                materialsURL: materialsURL,
                materialFileSHA256:
                    IndustrialL2V6EastSceneKitCaptureContract
                    .materialSHA256,
                outputURL: output,
                recordURL: record,
                stageCaptureDirectory: capture,
                stageCoordinate: [707, 687],
                explicitAntialiasing: "none",
                explicitSceneShadows: "current",
                explicitMaterialLighting: "current",
                prequantizedOutputRequested: false,
                descriptor: descriptor,
                sampling: sampling
            )
        guard
            valid?.supportGeometry
                .highResolutionWindowPixels == [33, 33],
            valid?.value["sceneDescriptorSHA256"] as? String
                == IndustrialL2V6EastSceneKitCaptureContract
                .sceneSHA256,
            valid?.value["sourceAuthority"] as? Bool == false
        else {
            throw IndustrialL2V6EastSceneKitCaptureTestError.failed(
                "valid source-v06 capture contract drifted"
            )
        }

        func modifiedDescriptor(
            key: String,
            value: Any
        ) throws -> SceneDescriptor {
            var object =
                try JSONSerialization.jsonObject(
                    with: descriptorData
                ) as! [String: Any]
            object[key] = value
            let data = try JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys]
            )
            return try decoder.decode(SceneDescriptor.self, from: data)
        }

        let wrongRevision = try modifiedDescriptor(
            key: "sourceRevision",
            value: "source-v05"
        )
        let wrongDirection = try modifiedDescriptor(
            key: "viewDirection",
            value: "west"
        )
        let invalidCases: [(
            String,
            SceneDescriptor,
            String,
            [Int],
            URL
        )] = [
            (
                "revision",
                wrongRevision,
                IndustrialL2V6EastSceneKitCaptureContract.sceneSHA256,
                [707, 687],
                capture
            ),
            (
                "direction",
                wrongDirection,
                IndustrialL2V6EastSceneKitCaptureContract.sceneSHA256,
                [707, 687],
                capture
            ),
            (
                "descriptor hash",
                descriptor,
                String(repeating: "0", count: 64),
                [707, 687],
                capture
            ),
            (
                "coordinate",
                descriptor,
                IndustrialL2V6EastSceneKitCaptureContract.sceneSHA256,
                [707, 688],
                capture
            ),
            (
                "evidence root",
                descriptor,
                IndustrialL2V6EastSceneKitCaptureContract.sceneSHA256,
                [707, 687],
                root.appendingPathComponent(
                    "docs/production/evidence/PLAY-027/other/"
                        + "diagnostics/run-a"
                )
            ),
        ]
        for (
            label,
            candidateDescriptor,
            candidateSHA,
            coordinate,
            candidateCapture
        ) in invalidCases {
            do {
                _ =
                    try IndustrialL2V6EastSceneKitCaptureContract
                        .validate(
                            requestedContractID:
                                IndustrialL2V6EastSceneKitCaptureContract
                                .contractID,
                            repositoryRoot: root,
                            sceneURL: sceneURL,
                            sceneFileSHA256: candidateSHA,
                            materialsURL: materialsURL,
                            materialFileSHA256:
                                IndustrialL2V6EastSceneKitCaptureContract
                                .materialSHA256,
                            outputURL: candidateCapture
                                .appendingPathComponent(
                                    "final-sips.png"
                                ),
                            recordURL: candidateCapture
                                .appendingPathComponent(
                                    "provenance.json"
                                ),
                            stageCaptureDirectory: candidateCapture,
                            stageCoordinate: coordinate,
                            explicitAntialiasing: "none",
                            explicitSceneShadows: "current",
                            explicitMaterialLighting: "current",
                            prequantizedOutputRequested: false,
                            descriptor: candidateDescriptor,
                            sampling: sampling
                        )
                throw IndustrialL2V6EastSceneKitCaptureTestError
                    .failed("\(label) was not rejected")
            } catch is
                IndustrialL2V6EastSceneKitCaptureContractError
            {
                continue
            }
        }

        print(
            "PASS source-v06 East capture extension; "
                + "v06 SHA admitted and revision/direction/coordinate drift rejected"
        )
    }
}
