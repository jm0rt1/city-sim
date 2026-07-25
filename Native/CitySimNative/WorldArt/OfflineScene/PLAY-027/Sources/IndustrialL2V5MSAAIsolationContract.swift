import Foundation

enum IndustrialL2V5MSAAIsolationContractError:
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

struct IndustrialL2V5MSAAIsolationRecord {
    let value: [String: Any]
}

enum IndustrialL2V5MSAAIsolationContract {
    static let contractID =
        "industrial-l02-source-v05-msaa-none-current-shadows-v1"
    static let evidenceRoot =
        "docs/production/evidence/PLAY-027/industrial-l02/l02/"
        + "source-v05-diagnostics/msaa-none-current-shadows"
    static let materialPath =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/materials/"
        + "industrial-l02-v0-source-v05-materials.json"

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
        explicitAntialiasing: String?,
        explicitSceneShadows: String?,
        explicitMaterialLighting: String?,
        logicalBuildingID: String,
        variantID: String,
        sourceRevision: String,
        viewDirection: String,
        productionSelected: Bool,
        descriptorSceneKitAntialiasing: String,
        descriptorSceneKitShadows: String
    ) throws -> IndustrialL2V5MSAAIsolationRecord? {
        guard let requestedContractID else {
            return nil
        }
        guard requestedContractID == contractID else {
            throw IndustrialL2V5MSAAIsolationContractError.invalid(
                "unknown diagnostic isolation contract"
            )
        }
        guard
            logicalBuildingID == "industrial_l02",
            variantID == "variant-0",
            sourceRevision == "source-v05",
            ["north", "east", "south", "west"].contains(viewDirection),
            productionSelected == false
        else {
            throw IndustrialL2V5MSAAIsolationContractError.invalid(
                "diagnostic isolation contract requires frozen Industrial L2 source-v05"
            )
        }
        guard
            explicitAntialiasing == "none",
            explicitSceneShadows == "current",
            explicitMaterialLighting == "current"
        else {
            throw IndustrialL2V5MSAAIsolationContractError.invalid(
                "diagnostic isolation contract requires explicit none/current/current options"
            )
        }

        let expectedScene =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/"
            + "industrial_l02/variant-0/\(viewDirection)/scene.json"
        guard
            relativePath(sceneURL, repositoryRoot: repositoryRoot)
                == expectedScene,
            relativePath(materialsURL, repositoryRoot: repositoryRoot)
                == materialPath
        else {
            throw IndustrialL2V5MSAAIsolationContractError.invalid(
                "diagnostic isolation contract input path mismatch"
            )
        }

        let expectedOutputParent = evidenceRoot + "/raw"
        guard
            let outputRelative = relativePath(
                outputURL,
                repositoryRoot: repositoryRoot
            ),
            let recordRelative = relativePath(
                recordURL,
                repositoryRoot: repositoryRoot
            ),
            (outputRelative as NSString).deletingLastPathComponent
                == expectedOutputParent,
            (recordRelative as NSString).deletingLastPathComponent
                == expectedOutputParent,
            outputURL.pathExtension == "png",
            recordURL.pathExtension == "json"
        else {
            throw IndustrialL2V5MSAAIsolationContractError.invalid(
                "diagnostic isolation output must remain under the exact PLAY-027 evidence root"
            )
        }

        let outputStem = outputURL.deletingPathExtension()
            .lastPathComponent
        let recordStem = recordURL.deletingPathExtension()
            .lastPathComponent
        let allowedStems = ["a", "b", "c"].map {
            "\(viewDirection)-run-\($0)"
        }
        guard
            outputStem == recordStem,
            allowedStems.contains(outputStem),
            !FileManager.default.fileExists(atPath: outputURL.path),
            !FileManager.default.fileExists(atPath: recordURL.path)
        else {
            throw IndustrialL2V5MSAAIsolationContractError.invalid(
                "diagnostic isolation requires a new direction run-a, run-b, or run-c pair"
            )
        }

        let antialiasingChanged =
            descriptorSceneKitAntialiasing != "none"
        // `current` preserves the descriptor-resolved shadow behavior.
        let shadowsChanged = false
        return IndustrialL2V5MSAAIsolationRecord(value: [
            "contractID": contractID,
            "sourceAuthority": false,
            "descriptorChanged": false,
            "materialsChanged": false,
            "geometryChanged": false,
            "requestedSceneKitAntialiasing": "none",
            "requestedSceneShadows": "current",
            "requestedMaterialLighting": "current",
            "descriptorSceneKitAntialiasing":
                descriptorSceneKitAntialiasing,
            "descriptorSceneKitShadows": descriptorSceneKitShadows,
            "effectiveSceneKitAntialiasingChanged":
                antialiasingChanged,
            "effectiveSceneKitShadowsChanged": shadowsChanged,
            "causalInterpretation":
                antialiasingChanged
                ? "true antialiasing counterfactual"
                : "explicit diagnostic-path reproduction; descriptor already resolves no MSAA",
            "productionSelected": false,
        ])
    }
}
