import Foundation

enum IndustrialL2V5MSAAIsolationTestError:
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
enum TestIndustrialL2V5MSAAIsolationContractMain {
    static func main() throws {
        let root = URL(
            fileURLWithPath: "/tmp/play027-msaa-isolation-test",
            isDirectory: true
        )
        let scene = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/"
                + "industrial_l02/variant-0/north/scene.json"
        )
        let materials = root.appendingPathComponent(
            IndustrialL2V5MSAAIsolationContract.materialPath
        )
        let outputRoot = root.appendingPathComponent(
            IndustrialL2V5MSAAIsolationContract.evidenceRoot + "/raw"
        )
        let output = outputRoot.appendingPathComponent("north-run-a.png")
        let record = outputRoot.appendingPathComponent("north-run-a.json")

        guard
            try IndustrialL2V5MSAAIsolationContract.validate(
                requestedContractID: nil,
                repositoryRoot: root,
                sceneURL: scene,
                materialsURL: materials,
                outputURL: output,
                recordURL: record,
                explicitAntialiasing: nil,
                explicitSceneShadows: nil,
                explicitMaterialLighting: nil,
                logicalBuildingID: "unrelated",
                variantID: "variant-9",
                sourceRevision: "source-v99",
                viewDirection: "north",
                productionSelected: true,
                descriptorSceneKitAntialiasing: "multisampling4X",
                descriptorSceneKitShadows: "current"
            ) == nil
        else {
            throw IndustrialL2V5MSAAIsolationTestError.failed(
                "default renderer path was not a no-op"
            )
        }

        let valid = try IndustrialL2V5MSAAIsolationContract.validate(
            requestedContractID:
                IndustrialL2V5MSAAIsolationContract.contractID,
            repositoryRoot: root,
            sceneURL: scene,
            materialsURL: materials,
            outputURL: output,
            recordURL: record,
            explicitAntialiasing: "none",
            explicitSceneShadows: "current",
            explicitMaterialLighting: "current",
            logicalBuildingID: "industrial_l02",
            variantID: "variant-0",
            sourceRevision: "source-v05",
            viewDirection: "north",
            productionSelected: false,
            descriptorSceneKitAntialiasing: "none",
            descriptorSceneKitShadows: "disabled"
        )
        guard
            valid?.value["effectiveSceneKitAntialiasingChanged"]
                as? Bool == false,
            valid?.value["effectiveSceneKitShadowsChanged"]
                as? Bool == false
        else {
            throw IndustrialL2V5MSAAIsolationTestError.failed(
                "existing no-MSAA/disabled-shadow descriptor was misclassified"
            )
        }

        let invalidCases: [(
            String,
            URL,
            URL,
            String?,
            String?,
            String?
        )] = [
            (
                "outside evidence root",
                root.appendingPathComponent("tmp/north-run-a.png"),
                root.appendingPathComponent("tmp/north-run-a.json"),
                "none",
                "current",
                "current"
            ),
            (
                "wrong output name",
                outputRoot.appendingPathComponent("north-run-d.png"),
                outputRoot.appendingPathComponent("north-run-d.json"),
                "none",
                "current",
                "current"
            ),
            (
                "missing antialiasing",
                output,
                record,
                nil,
                "current",
                "current"
            ),
            (
                "wrong shadows",
                output,
                record,
                "none",
                "disabled",
                "current"
            ),
            (
                "wrong material lighting",
                output,
                record,
                "none",
                "current",
                "constant-unlit"
            ),
        ]
        for (
            label,
            candidateOutput,
            candidateRecord,
            antialiasing,
            shadows,
            lighting
        ) in invalidCases {
            do {
                _ = try IndustrialL2V5MSAAIsolationContract.validate(
                    requestedContractID:
                        IndustrialL2V5MSAAIsolationContract.contractID,
                    repositoryRoot: root,
                    sceneURL: scene,
                    materialsURL: materials,
                    outputURL: candidateOutput,
                    recordURL: candidateRecord,
                    explicitAntialiasing: antialiasing,
                    explicitSceneShadows: shadows,
                    explicitMaterialLighting: lighting,
                    logicalBuildingID: "industrial_l02",
                    variantID: "variant-0",
                    sourceRevision: "source-v05",
                    viewDirection: "north",
                    productionSelected: false,
                    descriptorSceneKitAntialiasing: "none",
                    descriptorSceneKitShadows: "disabled"
                )
                throw IndustrialL2V5MSAAIsolationTestError.failed(
                    "\(label) was not rejected"
                )
            } catch is IndustrialL2V5MSAAIsolationContractError {
                continue
            }
        }

        print(
            "PASS additive Industrial L2 source-v05 diagnostic contract; "
                + "default path unchanged and exact PLAY-027 path/options enforced"
        )
    }
}
