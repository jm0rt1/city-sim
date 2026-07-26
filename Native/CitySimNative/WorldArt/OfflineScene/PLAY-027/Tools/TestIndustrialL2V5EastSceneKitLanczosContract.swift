import Foundation

enum IndustrialL2V5EastSceneKitLanczosTestError:
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
enum TestIndustrialL2V5EastSceneKitLanczosContractMain {
    static func main() throws {
        let geometry =
            try IndustrialL2V5EastSceneKitLanczosContract.supportGeometry(
                outputTargetCoordinate: [707, 687],
                viewportPixels: [1536, 1024],
                postProjectionOffsetPixels: [0, 256],
                linearOversamplingFactor: 4
            )
        guard
            geometry.downsampledInputCoordinate == [707, 431],
            geometry.highResolutionCenterTwice == [5659, 3451],
            geometry.highResolutionWindowBoundsExclusive
                == [2813, 1709, 2846, 1742],
            geometry.highResolutionWindowPixels == [33, 33],
            geometry.capturedRadiusInputPixels == 16
        else {
            throw IndustrialL2V5EastSceneKitLanczosTestError.failed(
                "frozen 4x support geometry mismatch"
            )
        }

        do {
            _ =
                try IndustrialL2V5EastSceneKitLanczosContract
                    .supportGeometry(
                        outputTargetCoordinate: [707, 688],
                        viewportPixels: [1536, 1024],
                        postProjectionOffsetPixels: [0, 256],
                        linearOversamplingFactor: 4
                    )
            throw IndustrialL2V5EastSceneKitLanczosTestError.failed(
                "wrong coordinate was not rejected"
            )
        } catch is IndustrialL2V5EastSceneKitLanczosContractError {
            // Expected.
        }

        let decoder = JSONDecoder()
        let sourceRepositoryRoot = URL(
            fileURLWithPath:
                FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let repositoryRoot = URL(
            fileURLWithPath:
                "/tmp/play027-east-scene-kit-lanczos-test-"
                + String(ProcessInfo.processInfo.processIdentifier),
            isDirectory: true
        )
        let sceneURL = repositoryRoot.appendingPathComponent(
            IndustrialL2V5EastSceneKitLanczosContract.scenePath
        )
        let materialsURL = repositoryRoot.appendingPathComponent(
            IndustrialL2V5EastSceneKitLanczosContract.materialPath
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
            at: sourceRepositoryRoot.appendingPathComponent(
                IndustrialL2V5EastSceneKitLanczosContract.scenePath
            ),
            to: sceneURL
        )
        try FileManager.default.copyItem(
            at: sourceRepositoryRoot.appendingPathComponent(
                IndustrialL2V5EastSceneKitLanczosContract.materialPath
            ),
            to: materialsURL
        )
        let descriptor = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: sceneURL)
        )
        let sampling = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        let capture = repositoryRoot.appendingPathComponent(
            IndustrialL2V5EastSceneKitLanczosContract.evidenceRoot
                + "/run-a"
        )
        let output = capture.appendingPathComponent("final-sips.png")
        let record = capture.appendingPathComponent("provenance.json")

        guard
            try IndustrialL2V5EastSceneKitLanczosContract.validate(
                requestedContractID: nil,
                repositoryRoot: repositoryRoot,
                sceneURL: sceneURL,
                sceneFileSHA256:
                    IndustrialL2V5EastSceneKitLanczosContract
                    .sceneSHA256,
                materialsURL: materialsURL,
                materialFileSHA256:
                    IndustrialL2V5EastSceneKitLanczosContract
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
            throw IndustrialL2V5EastSceneKitLanczosTestError.failed(
                "default renderer path was not a no-op"
            )
        }

        let valid =
            try IndustrialL2V5EastSceneKitLanczosContract.validate(
                requestedContractID:
                    IndustrialL2V5EastSceneKitLanczosContract.contractID,
                repositoryRoot: repositoryRoot,
                sceneURL: sceneURL,
                sceneFileSHA256:
                    IndustrialL2V5EastSceneKitLanczosContract
                    .sceneSHA256,
                materialsURL: materialsURL,
                materialFileSHA256:
                    IndustrialL2V5EastSceneKitLanczosContract
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
            valid?.supportGeometry == geometry,
            valid?.value["sourceAuthority"] as? Bool == false
        else {
            throw IndustrialL2V5EastSceneKitLanczosTestError.failed(
                "valid contract did not retain exact authority"
            )
        }

        let invalidCaptures = [
            repositoryRoot.appendingPathComponent(
                "docs/production/evidence/PLAY-027/other/"
                    + "diagnostics/run-a"
            ),
            capture.deletingLastPathComponent()
                .appendingPathComponent("run-d"),
        ]
        for invalidCapture in invalidCaptures {
            do {
                _ =
                    try IndustrialL2V5EastSceneKitLanczosContract
                        .validate(
                            requestedContractID:
                                IndustrialL2V5EastSceneKitLanczosContract
                                .contractID,
                            repositoryRoot: repositoryRoot,
                            sceneURL: sceneURL,
                            sceneFileSHA256:
                                IndustrialL2V5EastSceneKitLanczosContract
                                .sceneSHA256,
                            materialsURL: materialsURL,
                            materialFileSHA256:
                                IndustrialL2V5EastSceneKitLanczosContract
                                .materialSHA256,
                            outputURL: invalidCapture
                                .appendingPathComponent(
                                    "final-sips.png"
                                ),
                            recordURL: invalidCapture
                                .appendingPathComponent(
                                    "provenance.json"
                                ),
                            stageCaptureDirectory: invalidCapture,
                            stageCoordinate: [707, 687],
                            explicitAntialiasing: "none",
                            explicitSceneShadows: "current",
                            explicitMaterialLighting: "current",
                            prequantizedOutputRequested: false,
                            descriptor: descriptor,
                            sampling: sampling
                        )
                throw IndustrialL2V5EastSceneKitLanczosTestError
                    .failed("invalid capture root was not rejected")
            } catch is
                IndustrialL2V5EastSceneKitLanczosContractError
            {
                continue
            }
        }

        let invalidConfigurations: [(
            [Int],
            String,
            String,
            String,
            Bool,
            String,
            String
        )] = [
            (
                [707, 688],
                "none",
                "current",
                "current",
                false,
                IndustrialL2V5EastSceneKitLanczosContract.sceneSHA256,
                IndustrialL2V5EastSceneKitLanczosContract.materialSHA256
            ),
            (
                [707, 687],
                "current",
                "current",
                "current",
                false,
                IndustrialL2V5EastSceneKitLanczosContract.sceneSHA256,
                IndustrialL2V5EastSceneKitLanczosContract.materialSHA256
            ),
            (
                [707, 687],
                "none",
                "disabled",
                "current",
                false,
                IndustrialL2V5EastSceneKitLanczosContract.sceneSHA256,
                IndustrialL2V5EastSceneKitLanczosContract.materialSHA256
            ),
            (
                [707, 687],
                "none",
                "current",
                "constant-unlit",
                false,
                IndustrialL2V5EastSceneKitLanczosContract.sceneSHA256,
                IndustrialL2V5EastSceneKitLanczosContract.materialSHA256
            ),
            (
                [707, 687],
                "none",
                "current",
                "current",
                true,
                IndustrialL2V5EastSceneKitLanczosContract.sceneSHA256,
                IndustrialL2V5EastSceneKitLanczosContract.materialSHA256
            ),
            (
                [707, 687],
                "none",
                "current",
                "current",
                false,
                String(repeating: "0", count: 64),
                IndustrialL2V5EastSceneKitLanczosContract.materialSHA256
            ),
            (
                [707, 687],
                "none",
                "current",
                "current",
                false,
                IndustrialL2V5EastSceneKitLanczosContract.sceneSHA256,
                String(repeating: "0", count: 64)
            ),
        ]
        for configuration in invalidConfigurations {
            do {
                _ =
                    try IndustrialL2V5EastSceneKitLanczosContract
                        .validate(
                            requestedContractID:
                                IndustrialL2V5EastSceneKitLanczosContract
                                .contractID,
                            repositoryRoot: repositoryRoot,
                            sceneURL: sceneURL,
                            sceneFileSHA256: configuration.5,
                            materialsURL: materialsURL,
                            materialFileSHA256: configuration.6,
                            outputURL: output,
                            recordURL: record,
                            stageCaptureDirectory: capture,
                            stageCoordinate: configuration.0,
                            explicitAntialiasing: configuration.1,
                            explicitSceneShadows: configuration.2,
                            explicitMaterialLighting: configuration.3,
                            prequantizedOutputRequested:
                                configuration.4,
                            descriptor: descriptor,
                            sampling: sampling
                        )
                throw IndustrialL2V5EastSceneKitLanczosTestError
                    .failed("contract drift was not rejected")
            } catch is
                IndustrialL2V5EastSceneKitLanczosContractError
            {
                continue
            }
        }

        print(
            "PASS additive East SceneKit/Lanczos contract; "
                + "exact 4x support geometry and three-run task path enforced"
        )
    }
}
