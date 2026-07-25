import Foundation

enum IndustrialL2V5EastStageCaptureTestError:
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
enum TestIndustrialL2V5EastStageCaptureContractMain {
    static func main() throws {
        let root = URL(
            fileURLWithPath: "/tmp/play027-east-stage-test",
            isDirectory: true
        )
        let scene = root.appendingPathComponent(
            IndustrialL2V5EastStageCaptureContract.scenePath
        )
        let materials = root.appendingPathComponent(
            IndustrialL2V5EastStageCaptureContract.materialPath
        )
        let capture = root.appendingPathComponent(
            IndustrialL2V5EastStageCaptureContract.evidenceRoot
                + "/run-a"
        )
        let output = capture.appendingPathComponent("final-sips.png")
        let record = capture.appendingPathComponent("provenance.json")

        guard
            try IndustrialL2V5EastStageCaptureContract.validate(
                requestedContractID: nil,
                repositoryRoot: root,
                sceneURL: scene,
                materialsURL: materials,
                outputURL: output,
                recordURL: record,
                stageCaptureDirectory: nil,
                stageCoordinate: nil,
                explicitAntialiasing: nil,
                explicitSceneShadows: nil,
                explicitMaterialLighting: nil,
                prequantizedOutputRequested: false,
                logicalBuildingID: "unrelated",
                variantID: "variant-9",
                sourceRevision: "source-v99",
                viewDirection: "west",
                productionSelected: true,
                descriptorSceneKitAntialiasing: "multisampling4X",
                descriptorSceneKitShadows: "current"
            ) == nil
        else {
            throw IndustrialL2V5EastStageCaptureTestError.failed(
                "default renderer path was not a no-op"
            )
        }

        let valid =
            try IndustrialL2V5EastStageCaptureContract.validate(
                requestedContractID:
                    IndustrialL2V5EastStageCaptureContract.contractID,
                repositoryRoot: root,
                sceneURL: scene,
                materialsURL: materials,
                outputURL: output,
                recordURL: record,
                stageCaptureDirectory: capture,
                stageCoordinate: [707, 687],
                explicitAntialiasing: "none",
                explicitSceneShadows: "current",
                explicitMaterialLighting: "current",
                prequantizedOutputRequested: false,
                logicalBuildingID: "industrial_l02",
                variantID: "variant-0",
                sourceRevision: "source-v05",
                viewDirection: "east",
                productionSelected: false,
                descriptorSceneKitAntialiasing: "none",
                descriptorSceneKitShadows: "disabled"
            )
        guard
            valid?.value["targetCoordinate"] as? [Int] == [707, 687],
            valid?.value["sourceAuthority"] as? Bool == false
        else {
            throw IndustrialL2V5EastStageCaptureTestError.failed(
                "valid contract did not retain exact authority"
            )
        }

        let invalidCases: [(
            String,
            URL,
            URL,
            URL?,
            [Int]?,
            String?,
            String?,
            String?
        )] = [
            (
                "outside evidence root",
                root.appendingPathComponent(
                    "tmp/diagnostics/run-a/final-sips.png"
                ),
                root.appendingPathComponent(
                    "tmp/diagnostics/run-a/provenance.json"
                ),
                root.appendingPathComponent("tmp/diagnostics/run-a"),
                [707, 687],
                "none",
                "current",
                "current"
            ),
            (
                "run-d",
                capture.deletingLastPathComponent()
                    .appendingPathComponent("run-d/final-sips.png"),
                capture.deletingLastPathComponent()
                    .appendingPathComponent("run-d/provenance.json"),
                capture.deletingLastPathComponent()
                    .appendingPathComponent("run-d"),
                [707, 687],
                "none",
                "current",
                "current"
            ),
            (
                "wrong final name",
                capture.appendingPathComponent("output.png"),
                record,
                capture,
                [707, 687],
                "none",
                "current",
                "current"
            ),
            (
                "wrong coordinate",
                output,
                record,
                capture,
                [707, 688],
                "none",
                "current",
                "current"
            ),
            (
                "wrong antialiasing",
                output,
                record,
                capture,
                [707, 687],
                "current",
                "current",
                "current"
            ),
            (
                "wrong shadows",
                output,
                record,
                capture,
                [707, 687],
                "none",
                "disabled",
                "current"
            ),
        ]
        for (
            label,
            candidateOutput,
            candidateRecord,
            candidateCapture,
            coordinate,
            antialiasing,
            shadows,
            lighting
        ) in invalidCases {
            do {
                _ = try IndustrialL2V5EastStageCaptureContract.validate(
                    requestedContractID:
                        IndustrialL2V5EastStageCaptureContract.contractID,
                    repositoryRoot: root,
                    sceneURL: scene,
                    materialsURL: materials,
                    outputURL: candidateOutput,
                    recordURL: candidateRecord,
                    stageCaptureDirectory: candidateCapture,
                    stageCoordinate: coordinate,
                    explicitAntialiasing: antialiasing,
                    explicitSceneShadows: shadows,
                    explicitMaterialLighting: lighting,
                    prequantizedOutputRequested: false,
                    logicalBuildingID: "industrial_l02",
                    variantID: "variant-0",
                    sourceRevision: "source-v05",
                    viewDirection: "east",
                    productionSelected: false,
                    descriptorSceneKitAntialiasing: "none",
                    descriptorSceneKitShadows: "disabled"
                )
                throw IndustrialL2V5EastStageCaptureTestError.failed(
                    "\(label) was not rejected"
                )
            } catch is IndustrialL2V5EastStageCaptureContractError {
                continue
            }
        }

        print(
            "PASS additive East 707,687 stage-capture contract; "
                + "default path unchanged and exact three-run authority enforced"
        )
    }
}
