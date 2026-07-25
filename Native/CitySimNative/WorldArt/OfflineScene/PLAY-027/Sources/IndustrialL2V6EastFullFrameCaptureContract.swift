import Foundation

enum IndustrialL2V6EastFullFrameCaptureContractError:
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

enum IndustrialL2V6EastFullFrameCaptureContract {
    static let contractID =
        "industrial-l02-source-v06-east-full-precanonical-rgba-v1"
    static let evidenceRoot =
        "docs/production/evidence/PLAY-027/industrial-l02/l02/"
        + "source-v06-finite-equivalence-diagnostic/diagnostics/"
        + "precanonical-4x"
    static let diagnosticScenePath =
        "/tmp/"
        + "play027-industrial-l02-source-v06-equivalence-input/"
        + "scene.json"
    static let materialPath =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/materials/"
        + "industrial-l02-v0-source-v05-materials.json"
    static let sourceDescriptorCommit =
        "6d3dffd60925ad1aa1a4babcf6c959b44d324714"
    static let sourceDescriptorGitObject =
        "ac523576aac0fee3b2f0b2a4f64f6b2b892415b9"
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
            throw IndustrialL2V6EastFullFrameCaptureContractError.invalid(
                "unknown Industrial L2 source-v06 full-frame capture contract"
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
            throw IndustrialL2V6EastFullFrameCaptureContractError.invalid(
                "full-frame capture requires frozen Industrial L2 source-v06 East"
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
            throw IndustrialL2V6EastFullFrameCaptureContractError.invalid(
                "full-frame capture requires explicit none/current/current and coordinate 707,687"
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
            sampling.postQuantizationCanonicalizer?.version == 3,
            sampling.preLanczosCanonicalizer == nil
        else {
            throw IndustrialL2V6EastFullFrameCaptureContractError.invalid(
                "source-v06 sampling or no-canonicalization contract drifted"
            )
        }
        guard
            sceneURL.standardizedFileURL.path == diagnosticScenePath,
            sceneFileSHA256 == sceneSHA256,
            relativePath(materialsURL, repositoryRoot: repositoryRoot)
                == materialPath,
            materialFileSHA256 == materialSHA256
        else {
            throw IndustrialL2V6EastFullFrameCaptureContractError.invalid(
                "source-v06 Git-object input path or hash mismatch"
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
            throw IndustrialL2V6EastFullFrameCaptureContractError.invalid(
                "full-frame capture requires one new exact run-a, run-b, or run-c diagnostics directory"
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
            throw IndustrialL2V6EastFullFrameCaptureContractError.invalid(
                "source-v06 4x support geometry drifted"
            )
        }
        return IndustrialL2V5EastSceneKitLanczosRecord(
            value: [
                "contractID": contractID,
                "purpose":
                    "retain complete source-v06 East pre-canonical 4x RGBA frames for finite equivalence diagnosis",
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
                "sourceDescriptorCommit": sourceDescriptorCommit,
                "sourceDescriptorGitObject": sourceDescriptorGitObject,
                "sceneDescriptorSHA256": sceneSHA256,
                "materialLibrarySHA256": materialSHA256,
                "persistCompletePreCanonical4xRGBA": true,
                "preLanczosCanonicalizer": "none",
                "requestedSceneKitAntialiasing": "none",
                "requestedSceneShadows": "current",
                "requestedMaterialLighting": "current",
                "linearOversamplingFactor":
                    sampling.linearOversamplingFactor,
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
