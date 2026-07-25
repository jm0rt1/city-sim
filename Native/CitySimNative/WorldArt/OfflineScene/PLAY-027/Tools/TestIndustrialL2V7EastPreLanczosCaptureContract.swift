import Foundation

enum IndustrialL2V7EastPreLanczosCaptureTestError:
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
enum TestIndustrialL2V7EastPreLanczosCaptureContractMain {
    static func main() throws {
        let decoder = JSONDecoder()
        let sourceRoot = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let root = URL(
            fileURLWithPath:
                "/tmp/play027-source-v07-east-capture-test-"
                + String(ProcessInfo.processInfo.processIdentifier),
            isDirectory: true
        )
        let sceneURL = root.appendingPathComponent(
            IndustrialL2V7EastPreLanczosCaptureContract.scenePath
        )
        let materialsURL = root.appendingPathComponent(
            IndustrialL2V7EastPreLanczosCaptureContract.materialPath
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
                IndustrialL2V7EastPreLanczosCaptureContract.scenePath
            ),
            to: sceneURL
        )
        try FileManager.default.copyItem(
            at: sourceRoot.appendingPathComponent(
                IndustrialL2V7EastPreLanczosCaptureContract.materialPath
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
            IndustrialL2V7EastPreLanczosCaptureContract.evidenceRoot
                + "/run-a"
        )
        let output = capture.appendingPathComponent("final-sips.png")
        let record = capture.appendingPathComponent("provenance.json")

        let valid =
            try IndustrialL2V7EastPreLanczosCaptureContract.validate(
                requestedContractID:
                    IndustrialL2V7EastPreLanczosCaptureContract.contractID,
                repositoryRoot: root,
                sceneURL: sceneURL,
                sceneFileSHA256:
                    IndustrialL2V7EastPreLanczosCaptureContract
                    .sceneSHA256,
                materialsURL: materialsURL,
                materialFileSHA256:
                    IndustrialL2V7EastPreLanczosCaptureContract
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
            valid?.value["sourceAuthority"] as? Bool == false,
            sampling.preLanczosCanonicalizer?.version == 1
        else {
            throw IndustrialL2V7EastPreLanczosCaptureTestError.failed(
                "valid source-v07 capture contract drifted"
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
            String,
            SceneDescriptor,
            String,
            [Int]
        )] = [
            (
                "revision",
                try modifiedDescriptor(
                    key: "sourceRevision",
                    value: "source-v06"
                ),
                IndustrialL2V7EastPreLanczosCaptureContract.sceneSHA256,
                [707, 687]
            ),
            (
                "direction",
                try modifiedDescriptor(
                    key: "viewDirection",
                    value: "west"
                ),
                IndustrialL2V7EastPreLanczosCaptureContract.sceneSHA256,
                [707, 687]
            ),
            (
                "descriptor hash",
                descriptor,
                String(repeating: "0", count: 64),
                [707, 687]
            ),
            (
                "coordinate",
                descriptor,
                IndustrialL2V7EastPreLanczosCaptureContract.sceneSHA256,
                [707, 688]
            ),
        ]
        for (label, candidate, candidateSHA, coordinate) in invalidCases {
            do {
                _ =
                    try IndustrialL2V7EastPreLanczosCaptureContract
                        .validate(
                            requestedContractID:
                                IndustrialL2V7EastPreLanczosCaptureContract
                                .contractID,
                            repositoryRoot: root,
                            sceneURL: sceneURL,
                            sceneFileSHA256: candidateSHA,
                            materialsURL: materialsURL,
                            materialFileSHA256:
                                IndustrialL2V7EastPreLanczosCaptureContract
                                .materialSHA256,
                            outputURL: output,
                            recordURL: record,
                            stageCaptureDirectory: capture,
                            stageCoordinate: coordinate,
                            explicitAntialiasing: "none",
                            explicitSceneShadows: "current",
                            explicitMaterialLighting: "current",
                            prequantizedOutputRequested: false,
                            descriptor: candidate,
                            sampling: sampling
                        )
                throw IndustrialL2V7EastPreLanczosCaptureTestError
                    .failed("\(label) was not rejected")
            } catch is
                IndustrialL2V7EastPreLanczosCaptureContractError
            {
                continue
            }
        }

        guard
            try IndustrialL2V7EastPreLanczosCaptureContract.validate(
                requestedContractID: nil,
                repositoryRoot: root,
                sceneURL: sceneURL,
                sceneFileSHA256:
                    IndustrialL2V7EastPreLanczosCaptureContract
                    .sceneSHA256,
                materialsURL: materialsURL,
                materialFileSHA256:
                    IndustrialL2V7EastPreLanczosCaptureContract
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
            throw IndustrialL2V7EastPreLanczosCaptureTestError.failed(
                "default renderer path was not a no-op"
            )
        }

        print(
            "PASS source-v07 East pre-Lanczos capture contract; "
                + "exact source hash admitted and revision/direction/coordinate drift rejected"
        )
    }
}
