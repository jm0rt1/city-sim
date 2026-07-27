import Foundation

enum IndustrialL3V5NWCanonicalizerTraceContractError:
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

struct IndustrialL3V5NWCanonicalizerTraceRecord {
    let direction: String
    let processID: String
    let coordinates: [[Int]]
    let value: [String: Any]
}

enum IndustrialL3V5NWCanonicalizerTraceContract {
    static let contractID =
        "play027-industrial-l03-source-v05-nw-canonicalizer-trace-v1"
    static let evidenceRoot =
        "docs/production/evidence/PLAY-027/industrial-l03/l03/"
        + "cohesion-a0-frontage-trace-v01/diagnostics"
    static let materialPath =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
        + "art-proof/industrial-l03-cohesion-east-v01/materials/"
        + "industrial-l03-cohesion-east-v01.json"
    static let materialSHA256 =
        "f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65"
    static let directionRecords: [
        String: (
            scenePath: String,
            sceneSHA256: String,
            geometryID: String,
            coordinates: [[Int]]
        )
    ] = [
        "north": (
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
                + "art-proof/industrial-l03-cohesion-frontage-v01/scenes/"
                + "industrial_l03/variant-0/north/scene.json",
            "a147ad0a7023374b982a6677325da2912f45796616b03579e1a72eb7da4a6b61",
            "industrial-l03-north-v05-open-loading-court",
            [[688, 391], [795, 748]]
        ),
        "west": (
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
                + "art-proof/industrial-l03-cohesion-frontage-v01/scenes/"
                + "industrial_l03/variant-0/west/scene.json",
            "56e9aef896ef5eef435f76ff466f837ac022ff18edbc4e6bd3fa24cb583d78dc",
            "industrial-l03-west-v05-open-loading-court",
            [[847, 391]]
        ),
    ]

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
        sceneSHA256: String,
        materialsURL: URL,
        materialSHA256: String,
        outputURL: URL,
        recordURL: URL,
        traceDirectory: URL?,
        descriptor: SceneDescriptor,
        sampling: EffectiveSamplingContract,
        explicitAntialiasing: String?,
        explicitSceneShadows: String?,
        explicitMaterialLighting: String?,
        diagnosticSamplingPipelineID: String?,
        diagnosticContractID: String?,
        diagnosticStageContractID: String?,
        diagnosticStageCaptureDirectory: URL?,
        diagnosticStageCoordinate: [Int]?,
        diagnosticPrequantizedOutput: URL?
    ) throws -> IndustrialL3V5NWCanonicalizerTraceRecord? {
        guard let requestedContractID else {
            guard traceDirectory == nil else {
                throw IndustrialL3V5NWCanonicalizerTraceContractError
                    .invalid("trace directory requires the exact trace contract")
            }
            return nil
        }
        guard requestedContractID == contractID, let traceDirectory else {
            throw IndustrialL3V5NWCanonicalizerTraceContractError.invalid(
                "unknown or incomplete Industrial L3 source-v05 trace contract"
            )
        }
        guard
            descriptor.logicalBuildingID == "industrial_l03",
            descriptor.variantID == "variant-0",
            descriptor.sourceRevision == "source-v05",
            descriptor.productionSelected == false,
            let direction = directionRecords[descriptor.viewDirection],
            descriptor.sceneGeometryID == direction.geometryID
        else {
            throw IndustrialL3V5NWCanonicalizerTraceContractError.invalid(
                "trace requires exact Industrial L3 source-v05 North/West identity"
            )
        }
        guard
            relativePath(sceneURL, repositoryRoot: repositoryRoot)
                == direction.scenePath,
            sceneSHA256 == direction.sceneSHA256,
            relativePath(materialsURL, repositoryRoot: repositoryRoot)
                == materialPath,
            materialSHA256 == self.materialSHA256
        else {
            throw IndustrialL3V5NWCanonicalizerTraceContractError.invalid(
                "trace descriptor or material binding drift"
            )
        }
        guard
            sampling.contractID
                == DescriptorSamplingResolver.schema2ContractV3ID,
            sampling.purpose == "source-authority",
            sampling.sceneKitAntialiasing == "none",
            sampling.sceneKitShadows == "disabled",
            sampling.sceneKitLightingMode == "authored-constant-v1",
            sampling.linearOversamplingFactor == 4,
            sampling.downsampleFilter == "CILanczosScaleTransform",
            sampling.downsampleScale == 0.25,
            sampling.preLanczosCanonicalizer == nil,
            sampling.postQuantizationCanonicalizer?.version == 3
        else {
            throw IndustrialL3V5NWCanonicalizerTraceContractError.invalid(
                "trace sampling contract drift"
            )
        }
        guard
            explicitAntialiasing == nil,
            explicitSceneShadows == nil,
            explicitMaterialLighting == nil,
            diagnosticSamplingPipelineID == nil,
            diagnosticContractID == nil,
            diagnosticStageContractID == nil,
            diagnosticStageCaptureDirectory == nil,
            diagnosticStageCoordinate == nil,
            diagnosticPrequantizedOutput == nil
        else {
            throw IndustrialL3V5NWCanonicalizerTraceContractError.invalid(
                "trace forbids every sampling, lighting, shadow, and stage override"
            )
        }
        guard
            let traceRelative = relativePath(
                traceDirectory,
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
                traceDirectory.lastPathComponent
            ),
            (traceRelative as NSString).deletingLastPathComponent
                == evidenceRoot + "/" + descriptor.viewDirection,
            outputRelative == traceRelative + "/raw.png",
            recordRelative == traceRelative + "/provenance.json",
            !FileManager.default.fileExists(atPath: traceDirectory.path)
        else {
            throw IndustrialL3V5NWCanonicalizerTraceContractError.invalid(
                "trace requires one new exact PLAY-027 diagnostics run directory"
            )
        }
        let processID =
            descriptor.viewDirection + "/" + traceDirectory.lastPathComponent
        return IndustrialL3V5NWCanonicalizerTraceRecord(
            direction: descriptor.viewDirection,
            processID: processID,
            coordinates: direction.coordinates,
            value: [
                "contractID": contractID,
                "purpose":
                    "Industrial L3 source-v05 canonicalizer trace only",
                "processID": processID,
                "direction": descriptor.viewDirection,
                "coordinates": direction.coordinates,
                "sceneDescriptorSHA256": direction.sceneSHA256,
                "sceneGeometryID": direction.geometryID,
                "materialLibrarySHA256": self.materialSHA256,
                "samplingContractID": sampling.contractID,
                "sceneKitAntialiasing": sampling.sceneKitAntialiasing,
                "sceneKitShadows": sampling.sceneKitShadows,
                "sceneKitLightingMode": sampling.sceneKitLightingMode,
                "descriptorChanged": false,
                "materialsChanged": false,
                "geometryChanged": false,
                "samplingChanged": false,
                "canonicalizerChanged": false,
                "defaultRenderingChanged": false,
                "sourceAuthority": false,
                "productionSelected": false,
            ]
        )
    }
}

func industrialL3V5TraceWindowRecord(
    stage: String,
    rgba: [UInt8],
    width: Int,
    height: Int,
    target: [Int],
    radius: Int
) throws -> [String: Any] {
    guard
        width > 0,
        height > 0,
        rgba.count == width * height * 4,
        target.count == 2,
        radius >= 0,
        target[0] - radius >= 0,
        target[1] - radius >= 0,
        target[0] + radius < width,
        target[1] + radius < height
    else {
        throw IndustrialL3V5NWCanonicalizerTraceContractError.invalid(
            "trace window is outside the immutable RGBA buffer"
        )
    }
    var samples: [[String: Any]] = []
    for y in (target[1] - radius)...(target[1] + radius) {
        for x in (target[0] - radius)...(target[0] + radius) {
            let offset = (y * width + x) * 4
            samples.append([
                "coordinate": [x, y],
                "offsetFromTarget": [x - target[0], y - target[1]],
                "rgba": Array(rgba[offset..<(offset + 4)]).map(Int.init),
            ])
        }
    }
    return [
        "stage": stage,
        "immutableInput": true,
        "coordinateSystem": "top-left decoded RGBA source pixel",
        "targetCoordinate": target,
        "windowSize": [radius * 2 + 1, radius * 2 + 1],
        "samplesRowMajor": samples,
    ]
}

func industrialL3V5TraceEvaluationRecord(
    _ evaluation: PixelCanonicalizationEvaluation,
    postMajorityRGBA: [UInt8],
    width: Int
) -> [String: Any] {
    let outputOffset = (evaluation.y * width + evaluation.x) * 4
    let selectedOutput = Int(
        postMajorityRGBA[outputOffset + evaluation.channel]
    )
    let nonMajorityBoundaryVotes = evaluation.boundaryVotes.filter {
        guard let majority = evaluation.majorityValue else {
            return false
        }
        return $0.quantizedValue != majority
    }.count
    return [
        "coordinate": [evaluation.x, evaluation.y],
        "channel": evaluation.channel,
        "centerValue": evaluation.centerValue,
        "majorityValue":
            evaluation.majorityValue.map { $0 as Any } ?? NSNull(),
        "majorityVotes": evaluation.majorityCount,
        "boundaryVotes": evaluation.boundaryVotes.map {
            [
                "coordinate": [$0.x, $0.y],
                "channel": $0.channel,
                "prequantizedValue": $0.prequantizedValue,
                "quantizedValue": $0.quantizedValue,
                "boundaryPair": $0.boundaryPair,
            ] as [String: Any]
        },
        "effectiveSupport":
            evaluation.majorityCount + nonMajorityBoundaryVotes,
        "competingSupportAfterBoundaryReclassification":
            evaluation.competingSupportAfterBoundaryReclassification
            .map { $0 as Any } ?? NSNull(),
        "fullyOpaqueNeighborhood":
            evaluation.fullyOpaqueNeighborhood,
        "chromaFreeNeighborhood":
            evaluation.chromaFreeNeighborhood,
        "exactQuantumDifference":
            evaluation.exactQuantumDifference,
        "standardMajorityEligible":
            evaluation.standardMajorityEligible,
        "boundaryAssistEligible":
            evaluation.boundaryAssistEligible,
        "eligible": evaluation.eligible,
        "mutated": evaluation.mutated,
        "selectedOutput": selectedOutput,
        "canonicalizerReason": evaluation.eligibilityReason,
    ]
}
