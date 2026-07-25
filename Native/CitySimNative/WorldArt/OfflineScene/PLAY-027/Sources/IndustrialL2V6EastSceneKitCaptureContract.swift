import Foundation

enum IndustrialL2V6EastSceneKitCaptureContractError:
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

enum IndustrialL2V6EastSceneKitCaptureContract {
    static let contractID =
        "industrial-l02-source-v06-east-scene-kit-vs-lanczos-707x687-v1"
    static let evidenceRoot =
        "docs/production/evidence/PLAY-027/industrial-l02/l02/"
        + "source-v06-east-proof-rerun/diagnostics/"
        + "east-707x687-scene-kit-vs-lanczos"
    static let scenePath =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/"
        + "industrial_l02/variant-0/east/scene.json"
    static let materialPath =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/materials/"
        + "industrial-l02-v0-source-v05-materials.json"
    static let sceneSHA256 =
        "70b36a0e76581524e64d40f19e364659eed6a53d7f7ab8d8924c51ba5d0951dd"
    static let materialSHA256 =
        "4f4e34aa87891d70c442e596315bcbd474f059638c0af69abe6ecaac17af0815"
    static let targetCoordinate = [707, 687]
    static let expectedViewportPixels = [1536, 1024]
    static let expectedPostProjectionOffsetPixels = [0.0, 256.0]
    static let expectedLinearOversamplingFactor = 4

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
            throw IndustrialL2V6EastSceneKitCaptureContractError.invalid(
                "unknown Industrial L2 source-v06 East capture contract"
            )
        }
        guard
            descriptor.logicalBuildingID == "industrial_l02",
            descriptor.variantID == "variant-0",
            descriptor.sourceRevision == "source-v06",
            descriptor.viewDirection == "east",
            descriptor.productionSelected == false,
            descriptor.camera.renderViewportPixels
                == expectedViewportPixels,
            descriptor.camera.oversamplingFactor
                == expectedLinearOversamplingFactor,
            descriptor.camera.postProjectionOffsetPixels
                == expectedPostProjectionOffsetPixels
        else {
            throw IndustrialL2V6EastSceneKitCaptureContractError.invalid(
                "capture requires frozen Industrial L2 source-v06 East"
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
            throw IndustrialL2V6EastSceneKitCaptureContractError.invalid(
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
            sampling.quantizerStep == 32,
            sampling.quantizerMidpointOffset == 8,
            sampling.chromaBypassRGBA == [255, 0, 255, 255],
            sampling.canonicalizerID == "imageio-sips-png-v1",
            sampling.canonicalizerEncoder == "ImageIO",
            sampling.canonicalizerPostEncoder == "/usr/bin/sips",
            sampling.canonicalizerFormat == "png",
            sampling.postQuantizationCanonicalizer?.version == 3
        else {
            throw IndustrialL2V6EastSceneKitCaptureContractError.invalid(
                "source-v06 East capture sampling contract drifted"
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
            throw IndustrialL2V6EastSceneKitCaptureContractError.invalid(
                "source-v06 East capture input path or hash mismatch"
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
            throw IndustrialL2V6EastSceneKitCaptureContractError.invalid(
                "capture requires a new exact source-v06 PLAY-027 run-a, run-b, or run-c directory"
            )
        }

        let geometry: OversampledSupportGeometry
        do {
            geometry =
                try IndustrialL2V5EastSceneKitLanczosContract
                    .supportGeometry(
                        outputTargetCoordinate: targetCoordinate,
                        viewportPixels:
                            descriptor.camera.renderViewportPixels,
                        postProjectionOffsetPixels:
                            descriptor.camera
                            .postProjectionOffsetPixels,
                        linearOversamplingFactor:
                            sampling.linearOversamplingFactor
                    )
        } catch {
            throw IndustrialL2V6EastSceneKitCaptureContractError.invalid(
                "source-v06 East 4x support geometry drifted"
            )
        }
        return IndustrialL2V5EastSceneKitLanczosRecord(
            value: [
                "contractID": contractID,
                "purpose":
                    "Industrial L2 source-v06 East proof rerun at 707,687",
                "sourceAuthority": false,
                "descriptorChanged": false,
                "materialsChanged": false,
                "geometryChanged": false,
                "cameraChanged": false,
                "registrationChanged": false,
                "lightingChanged": false,
                "shadowsChanged": false,
                "samplerChanged": false,
                "quantizerChanged": false,
                "canonicalizerChanged": false,
                "compositorChanged": false,
                "targetCoordinate": targetCoordinate,
                "sceneDescriptorSHA256": sceneSHA256,
                "materialLibrarySHA256": materialSHA256,
                "requestedSceneKitAntialiasing": "none",
                "requestedSceneShadows": "current",
                "requestedMaterialLighting": "current",
                "descriptorSceneKitAntialiasing":
                    sampling.sceneKitAntialiasing,
                "descriptorSceneKitShadows":
                    sampling.sceneKitShadows,
                "descriptorSceneKitLightingMode":
                    sampling.sceneKitLightingMode,
                "linearOversamplingFactor":
                    sampling.linearOversamplingFactor,
                "downsampleFilter": sampling.downsampleFilter,
                "downsampleScale": sampling.downsampleScale,
                "downsampleAspectRatio":
                    sampling.downsampleAspectRatio,
                "ciUseSoftwareRenderer":
                    sampling.ciUseSoftwareRenderer,
                "ciWorkingColorSpace":
                    sampling.ciWorkingColorSpace,
                "ciOutputColorSpace":
                    sampling.ciOutputColorSpace,
                "quantizerID": sampling.quantizerID,
                "canonicalizerID": sampling.canonicalizerID,
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
