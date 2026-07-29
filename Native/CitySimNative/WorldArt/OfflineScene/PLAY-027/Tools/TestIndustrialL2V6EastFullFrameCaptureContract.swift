import Foundation

enum IndustrialL2V6EastFullFrameCaptureTestError:
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
enum TestIndustrialL2V6EastFullFrameCaptureContractMain {
    static func main() throws {
        let decoder = JSONDecoder()
        let sourceRoot = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let root = URL(
            fileURLWithPath:
                "/tmp/play027-v06-full-frame-contract-test-"
                + String(ProcessInfo.processInfo.processIdentifier),
            isDirectory: true
        )
        let sceneURL = URL(
            fileURLWithPath:
                IndustrialL2V6EastFullFrameCaptureContract
                .diagnosticScenePath
        )
        let materialsURL = root.appendingPathComponent(
            IndustrialL2V6EastFullFrameCaptureContract.materialPath
        )
        try FileManager.default.createDirectory(
            at: materialsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(
            at: sourceRoot.appendingPathComponent(
                IndustrialL2V6EastFullFrameCaptureContract.materialPath
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
            IndustrialL2V6EastFullFrameCaptureContract.evidenceRoot
                + "/run-a"
        )
        let output = capture.appendingPathComponent("final-sips.png")
        let record = capture.appendingPathComponent("provenance.json")

        guard
            try IndustrialL2V6EastFullFrameCaptureContract.validate(
                requestedContractID: nil,
                repositoryRoot: root,
                sceneURL: sceneURL,
                sceneFileSHA256:
                    IndustrialL2V6EastFullFrameCaptureContract
                    .sceneSHA256,
                materialsURL: materialsURL,
                materialFileSHA256:
                    IndustrialL2V6EastFullFrameCaptureContract
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
            throw IndustrialL2V6EastFullFrameCaptureTestError.failed(
                "default renderer path was not a no-op"
            )
        }

        let valid =
            try IndustrialL2V6EastFullFrameCaptureContract.validate(
                requestedContractID:
                    IndustrialL2V6EastFullFrameCaptureContract.contractID,
                repositoryRoot: root,
                sceneURL: sceneURL,
                sceneFileSHA256:
                    IndustrialL2V6EastFullFrameCaptureContract
                    .sceneSHA256,
                materialsURL: materialsURL,
                materialFileSHA256:
                    IndustrialL2V6EastFullFrameCaptureContract
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
            valid?.value["persistCompletePreCanonical4xRGBA"]
                as? Bool == true,
            valid?.value["preLanczosCanonicalizer"]
                as? String == "none",
            sampling.preLanczosCanonicalizer == nil
        else {
            throw IndustrialL2V6EastFullFrameCaptureTestError.failed(
                "valid source-v06 full-frame contract drifted"
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

        let invalidCases: [(
            label: String,
            candidateDescriptor: SceneDescriptor,
            candidateSHA: String,
            candidateSceneURL: URL,
            coordinate: [Int],
            capture: URL
        )] = [
            (
                "revision",
                try modifiedDescriptor(
                    key: "sourceRevision",
                    value: "source-v07"
                ),
                IndustrialL2V6EastFullFrameCaptureContract.sceneSHA256,
                sceneURL,
                [707, 687],
                capture
            ),
            (
                "direction",
                try modifiedDescriptor(
                    key: "viewDirection",
                    value: "west"
                ),
                IndustrialL2V6EastFullFrameCaptureContract.sceneSHA256,
                sceneURL,
                [707, 687],
                capture
            ),
            (
                "descriptor hash",
                descriptor,
                String(repeating: "0", count: 64),
                sceneURL,
                [707, 687],
                capture
            ),
            (
                "descriptor path",
                descriptor,
                IndustrialL2V6EastFullFrameCaptureContract.sceneSHA256,
                root.appendingPathComponent("scene.json"),
                [707, 687],
                capture
            ),
            (
                "coordinate",
                descriptor,
                IndustrialL2V6EastFullFrameCaptureContract.sceneSHA256,
                sceneURL,
                [708, 687],
                capture
            ),
            (
                "evidence root",
                descriptor,
                IndustrialL2V6EastFullFrameCaptureContract.sceneSHA256,
                sceneURL,
                [707, 687],
                root.appendingPathComponent(
                    "docs/production/evidence/PLAY-027/other/"
                        + "diagnostics/run-a"
                )
            ),
        ]
        for candidate in invalidCases {
            do {
                _ =
                    try IndustrialL2V6EastFullFrameCaptureContract
                        .validate(
                            requestedContractID:
                                IndustrialL2V6EastFullFrameCaptureContract
                                .contractID,
                            repositoryRoot: root,
                            sceneURL: candidate.candidateSceneURL,
                            sceneFileSHA256: candidate.candidateSHA,
                            materialsURL: materialsURL,
                            materialFileSHA256:
                                IndustrialL2V6EastFullFrameCaptureContract
                                .materialSHA256,
                            outputURL: candidate.capture
                                .appendingPathComponent(
                                    "final-sips.png"
                                ),
                            recordURL: candidate.capture
                                .appendingPathComponent(
                                    "provenance.json"
                                ),
                            stageCaptureDirectory: candidate.capture,
                            stageCoordinate: candidate.coordinate,
                            explicitAntialiasing: "none",
                            explicitSceneShadows: "current",
                            explicitMaterialLighting: "current",
                            prequantizedOutputRequested: false,
                            descriptor: candidate.candidateDescriptor,
                            sampling: sampling
                        )
                throw IndustrialL2V6EastFullFrameCaptureTestError
                    .failed("\(candidate.label) was not rejected")
            } catch is
                IndustrialL2V6EastFullFrameCaptureContractError
            {
                continue
            }
        }

        print(
            "PASS source-v06 complete pre-canonical 4x capture contract; "
                + "exact Git-object input admitted and revision/direction/hash/path/coordinate/root drift rejected"
        )
    }
}
