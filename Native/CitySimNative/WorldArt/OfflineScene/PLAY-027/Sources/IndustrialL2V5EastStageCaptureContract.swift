import Foundation

enum IndustrialL2V5EastStageCaptureContractError:
    Error,
    CustomStringConvertible
{
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

struct IndustrialL2V5EastStageCaptureRecord {
    let value: [String: Any]
}

enum IndustrialL2V5EastStageCaptureContract {
    static let contractID =
        "industrial-l02-source-v05-east-stage-707x687-v1"
    static let evidenceRoot =
        "docs/production/evidence/PLAY-027/industrial-l02/l02/"
        + "source-v05-stage-capture/diagnostics/east-707x687"
    static let scenePath =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/"
        + "industrial_l02/variant-0/east/scene.json"
    static let materialPath =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/materials/"
        + "industrial-l02-v0-source-v05-materials.json"
    static let targetCoordinate = [707, 687]

    private static func relativePath(
        _ url: URL,
        repositoryRoot: URL
    ) -> String? {
        let root = repositoryRoot.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(root) else {
            return nil
        }
        return String(path.dropFirst(root.count))
    }

    static func validate(
        requestedContractID: String?,
        repositoryRoot: URL,
        sceneURL: URL,
        materialsURL: URL,
        outputURL: URL,
        recordURL: URL,
        stageCaptureDirectory: URL?,
        stageCoordinate: [Int]?,
        explicitAntialiasing: String?,
        explicitSceneShadows: String?,
        explicitMaterialLighting: String?,
        prequantizedOutputRequested: Bool,
        logicalBuildingID: String,
        variantID: String,
        sourceRevision: String,
        viewDirection: String,
        productionSelected: Bool,
        descriptorSceneKitAntialiasing: String,
        descriptorSceneKitShadows: String
    ) throws -> IndustrialL2V5EastStageCaptureRecord? {
        guard let requestedContractID else {
            return nil
        }
        guard requestedContractID == contractID else {
            throw IndustrialL2V5EastStageCaptureContractError.invalid(
                "unknown East stage-capture contract"
            )
        }
        guard
            logicalBuildingID == "industrial_l02",
            variantID == "variant-0",
            sourceRevision == "source-v05",
            viewDirection == "east",
            productionSelected == false
        else {
            throw IndustrialL2V5EastStageCaptureContractError.invalid(
                "stage capture requires frozen Industrial L2 source-v05 East"
            )
        }
        guard
            explicitAntialiasing == "none",
            explicitSceneShadows == "current",
            explicitMaterialLighting == "current",
            prequantizedOutputRequested == false,
            stageCoordinate == targetCoordinate,
            let stageCaptureDirectory
        else {
            throw IndustrialL2V5EastStageCaptureContractError.invalid(
                "stage capture requires explicit none/current/current and coordinate 707,687"
            )
        }
        guard
            relativePath(sceneURL, repositoryRoot: repositoryRoot)
                == scenePath,
            relativePath(materialsURL, repositoryRoot: repositoryRoot)
                == materialPath
        else {
            throw IndustrialL2V5EastStageCaptureContractError.invalid(
                "stage-capture input path mismatch"
            )
        }

        guard
            let captureRelative = relativePath(
                stageCaptureDirectory,
                repositoryRoot: repositoryRoot
            ),
            let outputRelative = relativePath(
                outputURL,
                repositoryRoot: repositoryRoot
            ),
            let recordRelative = relativePath(
                recordURL,
                repositoryRoot: repositoryRoot
            ),
            ["run-a", "run-b", "run-c"].contains(
                stageCaptureDirectory.lastPathComponent
            ),
            (captureRelative as NSString).deletingLastPathComponent
                == evidenceRoot,
            outputRelative == captureRelative + "/final-sips.png",
            recordRelative == captureRelative + "/provenance.json",
            !FileManager.default.fileExists(
                atPath: stageCaptureDirectory.path
            )
        else {
            throw IndustrialL2V5EastStageCaptureContractError.invalid(
                "stage capture requires a new exact PLAY-027 run-a, run-b, or run-c directory"
            )
        }

        return IndustrialL2V5EastStageCaptureRecord(value: [
            "contractID": contractID,
            "purpose":
                "East 707,687 five-stage causal isolation only",
            "sourceAuthority": false,
            "descriptorChanged": false,
            "materialsChanged": false,
            "geometryChanged": false,
            "cameraChanged": false,
            "registrationChanged": false,
            "lightingChanged": false,
            "shadowsChanged": false,
            "samplerChanged": false,
            "compositorChanged": false,
            "targetCoordinate": targetCoordinate,
            "requestedSceneKitAntialiasing": "none",
            "requestedSceneShadows": "current",
            "requestedMaterialLighting": "current",
            "descriptorSceneKitAntialiasing":
                descriptorSceneKitAntialiasing,
            "descriptorSceneKitShadows": descriptorSceneKitShadows,
            "effectiveSceneKitAntialiasingChanged": false,
            "effectiveSceneKitShadowsChanged": false,
            "productionSelected": false,
        ])
    }
}
