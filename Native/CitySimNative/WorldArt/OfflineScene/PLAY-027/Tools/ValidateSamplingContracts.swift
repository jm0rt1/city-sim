import CryptoKit
import Foundation

enum SamplingValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-sampling-contracts --repository-root <path> --manifest <json> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

func samplingValidationArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw SamplingValidationError.arguments
    }
    return arguments[index + 1]
}

func samplingValidationSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func samplingValidationImmutablePayload(
    _ object: [String: Any]
) throws -> Data {
    var payload = object
    payload.removeValue(forKey: "schema")
    payload.removeValue(forKey: "sampling")
    guard var camera = payload["camera"] as? [String: Any] else {
        throw SamplingValidationError.invalid("camera missing")
    }
    camera.removeValue(forKey: "oversamplingFactor")
    payload["camera"] = camera
    return try JSONSerialization.data(
        withJSONObject: payload,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

func samplingValidationNumber(
    _ value: Any?
) -> Double? {
    (value as? NSNumber)?.doubleValue
}

@main
enum ValidateSamplingContractsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try samplingValidationArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let manifestURL = URL(
            fileURLWithPath: try samplingValidationArgument(
                "--manifest",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try samplingValidationArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        guard
            let manifest = try JSONSerialization.jsonObject(
                with: Data(contentsOf: manifestURL)
            ) as? [String: Any],
            let samples = manifest["samples"] as? [[String: Any]],
            let contractID = manifest["contractID"] as? String,
            [
                "play027-deterministic-4x-no-msaa-lanczos-v1",
                "play027-deterministic-4x-no-msaa-lanczos-v2",
                "play027-deterministic-4x-no-msaa-lanczos-v3",
            ].contains(contractID)
        else {
            throw SamplingValidationError.invalid("invalid manifest")
        }
        let expectsPostQuantizationRepair =
            contractID.hasSuffix("-v2")
            || contractID.hasSuffix("-v3")
        let expectsBoundaryAssist = contractID.hasSuffix("-v3")
        var failures: [String] = []
        var records: [[String: Any]] = []
        for sample in samples {
            guard
                let logicalID = sample["logicalBuildingID"] as? String,
                let direction = sample["direction"] as? String,
                let acceptedFile =
                    sample["acceptedDescriptorFile"] as? String,
                let diagnosticFile =
                    sample["diagnosticDescriptorFile"] as? String
            else {
                failures.append("manifest sample identity missing")
                continue
            }
            let key = "\(logicalID)/\(direction)"
            let acceptedURL = repositoryRoot.appendingPathComponent(
                acceptedFile
            )
            let diagnosticURL = repositoryRoot.appendingPathComponent(
                diagnosticFile
            )
            let acceptedData = try Data(contentsOf: acceptedURL)
            let diagnosticData = try Data(contentsOf: diagnosticURL)
            guard
                let accepted = try JSONSerialization.jsonObject(
                    with: acceptedData
                ) as? [String: Any],
                let diagnostic = try JSONSerialization.jsonObject(
                    with: diagnosticData
                ) as? [String: Any],
                let acceptedCamera =
                    accepted["camera"] as? [String: Any],
                let diagnosticCamera =
                    diagnostic["camera"] as? [String: Any],
                let sampling =
                    diagnostic["sampling"] as? [String: Any],
                let downsample =
                    sampling["downsample"] as? [String: Any],
                let ciContext =
                    sampling["ciContext"] as? [String: Any],
                let quantizer =
                    sampling["quantizer"] as? [String: Any],
                let canonicalizer =
                    sampling["canonicalizer"] as? [String: Any],
                let sourceRevision =
                    diagnostic["sourceRevision"] as? String
            else {
                failures.append("\(key): descriptor structure missing")
                continue
            }
            var itemFailures: [String] = []
            if samplingValidationNumber(accepted["schema"]) != 1
                || accepted["sampling"] != nil
                || samplingValidationNumber(
                    acceptedCamera["oversamplingFactor"]
                ) != 2
            {
                itemFailures.append("legacy schema-1 path changed")
            }
            if samplingValidationNumber(diagnostic["schema"]) != 2
                || samplingValidationNumber(
                    diagnosticCamera["oversamplingFactor"]
                ) != 4
                || sampling["contractID"] as? String != contractID
                || sampling["sourceRevisionBinding"] as? String
                    != sourceRevision
                || sampling["purpose"] as? String
                    != "diagnostic-regression"
                || sampling["sceneKitAntialiasing"] as? String != "none"
                || samplingValidationNumber(
                    sampling["linearOversamplingFactor"]
                ) != 4
                || downsample["filter"] as? String
                    != "CILanczosScaleTransform"
                || samplingValidationNumber(downsample["scale"]) != 0.25
                || samplingValidationNumber(
                    downsample["aspectRatio"]
                ) != 1
                || ciContext["useSoftwareRenderer"] as? Bool != true
                || ciContext["cacheIntermediates"] as? Bool != false
                || ciContext["workingColorSpace"] as? String
                    != "extended-srgb"
                || ciContext["outputColorSpace"] as? String != "srgb"
                || quantizer["id"] as? String
                    != "step32-midpoint-offset8-v1"
                || samplingValidationNumber(quantizer["step"]) != 32
                || samplingValidationNumber(
                    quantizer["midpointOffset"]
                ) != 8
                || (quantizer["chromaBypassRGBA"] as? [Int])
                    != [255, 0, 255, 255]
                || canonicalizer["id"] as? String
                    != "imageio-sips-png-v1"
                || canonicalizer["encoder"] as? String != "ImageIO"
                || canonicalizer["postEncoder"] as? String
                    != "/usr/bin/sips"
                || canonicalizer["format"] as? String != "png"
            {
                itemFailures.append("schema-2 sampling contract mismatch")
            }
            let repair = sampling[
                "postQuantizationCanonicalizer"
            ] as? [String: Any]
            if expectsPostQuantizationRepair {
                if repair?["algorithm"] as? String
                    != "opaque-isolated-one-quantum-majority-3x3"
                    || samplingValidationNumber(repair?["version"])
                        != (expectsBoundaryAssist ? 3 : 2)
                    || samplingValidationNumber(
                        repair?["quantizationQuantum"]
                    ) != 32
                    || samplingValidationNumber(
                        repair?["neighborhoodSize"]
                    ) != 3
                    || samplingValidationNumber(
                        repair?["majorityThreshold"]
                    ) != 7
                    || repair?["requiresFullyOpaqueNeighborhood"] as? Bool
                        != true
                    || repair?["immutableSourceBuffer"] as? Bool != true
                    || repair?["requiresChromaFreeNeighborhood"] as? Bool
                        != true
                    || repair?["channels"] as? String != "rgb-only"
                    || repair?["preservesAlpha"] as? Bool != true
                    || repair?["preservesChroma"] as? Bool != true
                {
                    itemFailures.append(
                        "schema-2 post-quantization canonicalizer mismatch"
                    )
                }
                let assist =
                    repair?["boundaryAssist"] as? [String: Any]
                if expectsBoundaryAssist {
                    if assist?["algorithm"] as? String
                        != "immutable-prequantized-one-value-boundary-6-plus-1"
                        || samplingValidationNumber(assist?["version"]) != 1
                        || samplingValidationNumber(
                            assist?["baseQuantizedMajorityCount"]
                        ) != 6
                        || samplingValidationNumber(
                            assist?["requiredBoundaryVoteCount"]
                        ) != 1
                        || samplingValidationNumber(
                            assist?["effectiveSupportCount"]
                        ) != 7
                        || samplingValidationNumber(
                            assist?[
                                "maximumCompetingSupportAfterBoundaryReclassification"
                            ]
                        ) != 2
                        || samplingValidationNumber(
                            assist?["quantizerStep"]
                        ) != 32
                        || samplingValidationNumber(
                            assist?["quantizerMidpointOffset"]
                        ) != 8
                        || samplingValidationNumber(
                            assist?["boundaryBandWidthValues"]
                        ) != 1
                        || assist?["requiresSameChannelEvidence"] as? Bool
                            != true
                        || assist?["immutablePrequantizedBuffer"] as? Bool
                            != true
                        || assist?["recordsBoundaryVoteReason"] as? Bool
                            != true
                    {
                        itemFailures.append(
                            "schema-2 v3 boundary-assist contract mismatch"
                        )
                    }
                } else if assist != nil {
                    itemFailures.append(
                        "schema-2 v2 must omit boundary assist"
                    )
                }
            } else if repair != nil {
                itemFailures.append(
                    "schema-2 contract v1 must omit post-quantization canonicalizer"
                )
            }
            let acceptedImmutable =
                try samplingValidationImmutablePayload(accepted)
            let diagnosticImmutable =
                try samplingValidationImmutablePayload(diagnostic)
            if acceptedImmutable != diagnosticImmutable {
                itemFailures.append("authored payload changed")
            }
            if (diagnostic["productionSelected"] as? Bool) != false {
                itemFailures.append("productionSelected is not false")
            }
            failures.append(contentsOf: itemFailures.map {
                "\(key): \($0)"
            })
            records.append([
                "key": key,
                "acceptedDescriptorSHA256":
                    samplingValidationSHA256(acceptedData),
                "diagnosticDescriptorSHA256":
                    samplingValidationSHA256(diagnosticData),
                "immutableAuthoredPayloadSHA256":
                    samplingValidationSHA256(acceptedImmutable),
                "status": itemFailures.isEmpty ? "pass" : "fail",
            ])
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contractID":
                contractID,
            "legacySchema1Contract":
                "factor-2 + SceneKit multisampling4X",
            "schema2Contract":
                "factor-4 + SceneKit none + software CI Lanczos 0.25",
            "sampleCount": records.count,
            "failures": failures,
            "records": records,
            "status": failures.isEmpty ? "pass" : "fail",
            "productionSelected": false,
        ]
        var reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes,
            ]
        )
        reportData.append(0x0a)
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try reportData.write(to: reportURL, options: .atomic)
        if !failures.isEmpty {
            throw SamplingValidationError.invalid(
                failures.joined(separator: "\n")
            )
        }
    }
}
