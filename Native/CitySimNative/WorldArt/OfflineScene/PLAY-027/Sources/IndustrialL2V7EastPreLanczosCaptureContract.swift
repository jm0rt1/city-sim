import Foundation

enum IndustrialL2V7EastPreLanczosCaptureContractError:
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

enum IndustrialL2V7EastPreLanczosCaptureContract {
    static let contractID =
        "industrial-l02-source-v07-east-pre-lanczos-707x687-v1"
    static let evidenceRoot =
        "docs/production/evidence/PLAY-027/industrial-l02/l02/"
        + "source-v07-east-pre-lanczos-proof/diagnostics/"
        + "east-707x687"
    static let scenePath =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/"
        + "industrial_l02/variant-0/east/scene.json"
    static let materialPath =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/materials/"
        + "industrial-l02-v0-source-v05-materials.json"
    static let sceneSHA256 =
        "69c2d2b37e65c91fb19e6c1f3b913e4f00a22558694fdd87b97a9942c6ed6a90"
    static let materialSHA256 =
        "4f4e34aa87891d70c442e596315bcbd474f059638c0af69abe6ecaac17af0815"
    static let targetCoordinate = [707, 687]

    private static func relativePath(
        _ url: URL,
        repositoryRoot: URL
    ) -> String? {
        let prefix = repositoryRoot.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(prefix) else {
            return nil
        }
        return String(path.dropFirst(prefix.count))
    }

    static func validate(
        requestedContractID: String?,
        repositoryRoot: URL,
        sceneURL: URL,
        sceneFileSHA256: String,
        materialsURL: URL,
        materialFileSHA256: String,
        outputURL: URL,
        recordURL: URL,
        stageCaptureDirectory: URL?,
        stageCoordinate: [Int]?,
        explicitAntialiasing: String?,
        explicitSceneShadows: String?,
        explicitMaterialLighting: String?,
        prequantizedOutputRequested: Bool,
        descriptor: SceneDescriptor,
        sampling: EffectiveSamplingContract
    ) throws -> IndustrialL2V5EastSceneKitLanczosRecord? {
        guard let requestedContractID else {
            return nil
        }
        guard requestedContractID == contractID else {
            throw IndustrialL2V7EastPreLanczosCaptureContractError.invalid(
                "unknown Industrial L2 source-v07 pre-Lanczos capture contract"
            )
        }
        guard
            descriptor.logicalBuildingID == "industrial_l02",
            descriptor.variantID == "variant-0",
            descriptor.sourceRevision == "source-v07",
            descriptor.viewDirection == "east",
            descriptor.productionSelected == false,
            descriptor.camera.renderViewportPixels == [1536, 1024],
            descriptor.camera.oversamplingFactor == 4,
            descriptor.camera.postProjectionOffsetPixels == [0, 256],
            sampling.preLanczosCanonicalizer != nil
        else {
            throw IndustrialL2V7EastPreLanczosCaptureContractError.invalid(
                "capture requires frozen Industrial L2 source-v07 East"
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
            throw IndustrialL2V7EastPreLanczosCaptureContractError.invalid(
                "capture requires explicit none/current/current and coordinate 707,687"
            )
        }
        guard
            sampling.contractID
                == DescriptorSamplingResolver.schema2ContractV3ID,
            sampling.descriptorSchema == 2,
            sampling.purpose == "source-authority",
            sampling.sceneKitAntialiasing == "none",
            sampling.sceneKitShadows == "disabled",
            sampling.sceneKitLightingMode == "authored-constant-v1",
            sampling.linearOversamplingFactor == 4,
            sampling.downsampleFilter == "CILanczosScaleTransform",
            sampling.downsampleScale == 0.25,
            sampling.downsampleAspectRatio == 1,
            sampling.ciUseSoftwareRenderer,
            sampling.ciCacheIntermediates == false,
            sampling.ciWorkingColorSpace == "extended-srgb",
            sampling.ciOutputColorSpace == "srgb",
            sampling.quantizerID == "step32-midpoint-offset8-v1",
            sampling.postQuantizationCanonicalizer?.version == 3
        else {
            throw IndustrialL2V7EastPreLanczosCaptureContractError.invalid(
                "source-v07 East sampling contract drifted"
            )
        }
        guard
            relativePath(sceneURL, repositoryRoot: repositoryRoot)
                == scenePath,
            sceneFileSHA256 == sceneSHA256,
            relativePath(materialsURL, repositoryRoot: repositoryRoot)
                == materialPath,
            materialFileSHA256 == materialSHA256
        else {
            throw IndustrialL2V7EastPreLanczosCaptureContractError.invalid(
                "source-v07 East input path or hash mismatch"
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
            throw IndustrialL2V7EastPreLanczosCaptureContractError.invalid(
                "capture requires one new exact source-v07 run-a, run-b, or run-c directory"
            )
        }

        let geometry =
            try IndustrialL2V5EastSceneKitLanczosContract
                .supportGeometry(
                    outputTargetCoordinate: targetCoordinate,
                    viewportPixels:
                        descriptor.camera.renderViewportPixels,
                    postProjectionOffsetPixels:
                        descriptor.camera.postProjectionOffsetPixels,
                    linearOversamplingFactor:
                        sampling.linearOversamplingFactor
                )
        return IndustrialL2V5EastSceneKitLanczosRecord(
            value: [
                "contractID": contractID,
                "purpose":
                    "Industrial L2 source-v07 East pre-Lanczos deterministic proof",
                "sourceAuthority": false,
                "descriptorChanged": false,
                "materialsChanged": false,
                "geometryChanged": false,
                "cameraChanged": false,
                "registrationChanged": false,
                "lightingChanged": false,
                "shadowsChanged": false,
                "samplerChanged": true,
                "samplerChange":
                    "descriptor-bound pre-Lanczos full-frame canonicalizer only",
                "quantizerChanged": false,
                "canonicalizerChanged": false,
                "compositorChanged": false,
                "targetCoordinate": targetCoordinate,
                "sceneDescriptorSHA256": sceneSHA256,
                "materialLibrarySHA256": materialSHA256,
                "preLanczosCanonicalizer":
                    sampling.preLanczosCanonicalizer.map {
                        [
                            "algorithm": $0.algorithm,
                            "version": $0.version,
                            "quantizationStep":
                                $0.quantizationStep,
                            "midpointOffset": $0.midpointOffset,
                            "partialAlphaPolicy":
                                $0.partialAlphaPolicy,
                            "preservesAlpha": $0.preservesAlpha,
                            "preservesChroma": $0.preservesChroma,
                            "crossRunState": $0.crossRunState,
                        ] as [String: Any]
                    } ?? [:],
                "highResolutionWindowBoundsExclusive":
                    geometry.highResolutionWindowBoundsExclusive,
                "highResolutionWindowPixels":
                    geometry.highResolutionWindowPixels,
                "productionSelected": false,
            ],
            supportGeometry: geometry
        )
    }
}
