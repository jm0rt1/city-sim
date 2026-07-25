import Foundation

enum IndustrialL2V5LightingTestError: Error, CustomStringConvertible {
    case arguments
    case failed(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: test-industrial-l2-v5-lighting --source-v04-scene <json> --legacy-scene <json> --schema <scene-v2.schema.json>"
        case let .failed(message):
            return message
        }
    }
}

func lightingTestArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2V5LightingTestError.arguments
    }
    return arguments[index + 1]
}

func lightingTestJSONObject(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL2V5LightingTestError.failed(
            "\(url.path) is not a JSON object"
        )
    }
    return object
}

func lightingTestDescriptor(
    from original: [String: Any],
    logicalBuildingID: String,
    sourceRevision: String,
    viewDirection: String? = nil,
    purpose: String = "source-authority",
    sceneKitShadows: String?,
    sceneKitLightingMode: String?
) throws -> SceneDescriptor {
    var object = original
    object["logicalBuildingID"] = logicalBuildingID
    object["sourceRevision"] = sourceRevision
    if let viewDirection {
        object["viewDirection"] = viewDirection
    }
    guard var sampling = object["sampling"] as? [String: Any] else {
        throw IndustrialL2V5LightingTestError.failed("sampling missing")
    }
    sampling["sourceRevisionBinding"] = sourceRevision
    sampling["purpose"] = purpose
    if let sceneKitShadows {
        sampling["sceneKitShadows"] = sceneKitShadows
    } else {
        sampling.removeValue(forKey: "sceneKitShadows")
    }
    if let sceneKitLightingMode {
        sampling["sceneKitLightingMode"] = sceneKitLightingMode
    } else {
        sampling.removeValue(forKey: "sceneKitLightingMode")
    }
    object["sampling"] = sampling
    let data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
    return try JSONDecoder().decode(SceneDescriptor.self, from: data)
}

func lightingTestRequiresFailure(
    _ descriptor: SceneDescriptor,
    label: String
) throws {
    do {
        _ = try DescriptorSamplingResolver.resolve(descriptor: descriptor)
        throw IndustrialL2V5LightingTestError.failed(
            "\(label) unexpectedly resolved"
        )
    } catch is SamplingContractError {
        return
    }
}

func lightingTestSchema(_ object: [String: Any]) throws {
    guard
        let definitions = object["$defs"] as? [String: Any],
        let sampling = definitions["sampling"] as? [String: Any],
        let properties = sampling["properties"] as? [String: Any],
        let lighting = properties["sceneKitLightingMode"]
            as? [String: Any],
        let values = lighting["enum"] as? [String],
        Set(values)
            == Set([
                "lambert-scene-lights",
                "authored-constant-v1",
            ]),
        let conditions = object["allOf"] as? [[String: Any]],
        conditions.count == 1,
        let condition = conditions.first,
        let ifObject = condition["if"] as? [String: Any],
        let alternatives = ifObject["anyOf"] as? [[String: Any]],
        alternatives.count == 2,
        let sourceV05Properties = alternatives[0]["properties"]
            as? [String: Any],
        let sourceV05LogicalID = sourceV05Properties["logicalBuildingID"]
            as? [String: Any],
        sourceV05LogicalID["const"] as? String == "industrial_l02",
        let sourceV05Revision = sourceV05Properties["sourceRevision"]
            as? [String: Any],
        sourceV05Revision["const"] as? String == "source-v05",
        let sourceV06Properties = alternatives[1]["properties"]
            as? [String: Any],
        let sourceV06LogicalID = sourceV06Properties["logicalBuildingID"]
            as? [String: Any],
        sourceV06LogicalID["const"] as? String == "industrial_l02",
        let sourceV06Revision = sourceV06Properties["sourceRevision"]
            as? [String: Any],
        sourceV06Revision["const"] as? String == "source-v06",
        let sourceV06Direction = sourceV06Properties["viewDirection"]
            as? [String: Any],
        sourceV06Direction["const"] as? String == "east",
        let thenObject = condition["then"] as? [String: Any],
        let thenProperties = thenObject["properties"]
            as? [String: Any],
        let thenSampling = thenProperties["sampling"] as? [String: Any],
        let required = thenSampling["required"] as? [String],
        Set(required)
            == Set([
                "purpose",
                "sceneKitLightingMode",
                "sceneKitShadows",
            ])
    else {
        throw IndustrialL2V5LightingTestError.failed(
            "scene-v2 schema does not bind the additive source-v05 and source-v06 East lighting rules"
        )
    }
}

@main
enum TestIndustrialL2V5LightingMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let sourceV04Object = try lightingTestJSONObject(
            URL(
                fileURLWithPath: try lightingTestArgument(
                    "--source-v04-scene",
                    in: arguments
                )
            )
        )
        let legacyDescriptor = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: Data(
                contentsOf: URL(
                    fileURLWithPath: try lightingTestArgument(
                        "--legacy-scene",
                        in: arguments
                    )
                )
            )
        )
        try lightingTestSchema(
            lightingTestJSONObject(
                URL(
                    fileURLWithPath: try lightingTestArgument(
                        "--schema",
                        in: arguments
                    )
                )
            )
        )

        let legacy = try DescriptorSamplingResolver.resolve(
            descriptor: legacyDescriptor
        )
        guard
            legacy.sceneKitLightingMode == "lambert-scene-lights",
            legacy.sceneKitShadows == "current",
            legacy.sceneKitAntialiasing == "multisampling4X"
        else {
            throw IndustrialL2V5LightingTestError.failed(
                "legacy schema-1 reproduction defaults changed"
            )
        }

        let sourceV04 = try lightingTestDescriptor(
            from: sourceV04Object,
            logicalBuildingID: "industrial_l02",
            sourceRevision: "source-v04",
            sceneKitShadows: "disabled",
            sceneKitLightingMode: nil
        )
        let sourceV04Resolved = try DescriptorSamplingResolver.resolve(
            descriptor: sourceV04
        )
        guard
            sourceV04Resolved.sceneKitLightingMode
                == "lambert-scene-lights",
            sourceV04Resolved.sceneKitShadows == "disabled"
        else {
            throw IndustrialL2V5LightingTestError.failed(
                "source-v04 reproduction defaults changed"
            )
        }

        let sourceV05 = try lightingTestDescriptor(
            from: sourceV04Object,
            logicalBuildingID: "industrial_l02",
            sourceRevision: "source-v05",
            sceneKitShadows: "disabled",
            sceneKitLightingMode: "authored-constant-v1"
        )
        let sourceV05Resolved = try DescriptorSamplingResolver.resolve(
            descriptor: sourceV05
        )
        guard
            sourceV05Resolved.sceneKitLightingMode
                == "authored-constant-v1",
            sourceV05Resolved.sceneKitShadows == "disabled",
            sourceV05Resolved.sceneKitAntialiasing == "none",
            sourceV05Resolved.linearOversamplingFactor == 4,
            sourceV05Resolved.downsampleScale == 0.25,
            sourceV05Resolved.ciUseSoftwareRenderer,
            sourceV05Resolved.quantizerStep == 32,
            sourceV05Resolved.postQuantizationCanonicalizer?.version == 3
        else {
            throw IndustrialL2V5LightingTestError.failed(
                "source-v05 authored-constant sampling did not resolve"
            )
        }

        let sourceV06East = try lightingTestDescriptor(
            from: sourceV04Object,
            logicalBuildingID: "industrial_l02",
            sourceRevision: "source-v06",
            viewDirection: "east",
            sceneKitShadows: "disabled",
            sceneKitLightingMode: "authored-constant-v1"
        )
        let sourceV06EastResolved = try DescriptorSamplingResolver.resolve(
            descriptor: sourceV06East
        )
        guard
            sourceV06EastResolved.sceneKitLightingMode
                == "authored-constant-v1",
            sourceV06EastResolved.sceneKitShadows == "disabled",
            sourceV06EastResolved.sceneKitAntialiasing == "none",
            sourceV06EastResolved.linearOversamplingFactor == 4,
            sourceV06EastResolved.downsampleScale == 0.25,
            sourceV06EastResolved.ciUseSoftwareRenderer,
            sourceV06EastResolved.quantizerStep == 32,
            sourceV06EastResolved
                .postQuantizationCanonicalizer?.version == 3
        else {
            throw IndustrialL2V5LightingTestError.failed(
                "source-v06 East authored-constant sampling did not resolve"
            )
        }

        try lightingTestRequiresFailure(
            lightingTestDescriptor(
                from: sourceV04Object,
                logicalBuildingID: "industrial_l02",
                sourceRevision: "source-v05",
                sceneKitShadows: "disabled",
                sceneKitLightingMode: nil
            ),
            label: "source-v05 missing lighting mode"
        )
        try lightingTestRequiresFailure(
            lightingTestDescriptor(
                from: sourceV04Object,
                logicalBuildingID: "industrial_l02",
                sourceRevision: "source-v05",
                sceneKitShadows: "disabled",
                sceneKitLightingMode: "lambert-scene-lights"
            ),
            label: "source-v05 Lambert mode"
        )
        try lightingTestRequiresFailure(
            lightingTestDescriptor(
                from: sourceV04Object,
                logicalBuildingID: "industrial_l02",
                sourceRevision: "source-v05",
                sceneKitShadows: "current",
                sceneKitLightingMode: "authored-constant-v1"
            ),
            label: "source-v05 current shadows"
        )
        try lightingTestRequiresFailure(
            lightingTestDescriptor(
                from: sourceV04Object,
                logicalBuildingID: "industrial_l02",
                sourceRevision: "source-v04",
                sceneKitShadows: "disabled",
                sceneKitLightingMode: "authored-constant-v1"
            ),
            label: "source-v04 authored constant"
        )
        try lightingTestRequiresFailure(
            lightingTestDescriptor(
                from: sourceV04Object,
                logicalBuildingID: "commercial_l02",
                sourceRevision: "source-v05",
                sceneKitShadows: "disabled",
                sceneKitLightingMode: "authored-constant-v1"
            ),
            label: "cross-family source-v05 authored constant"
        )
        try lightingTestRequiresFailure(
            lightingTestDescriptor(
                from: sourceV04Object,
                logicalBuildingID: "industrial_l02",
                sourceRevision: "source-v06",
                viewDirection: "north",
                sceneKitShadows: "disabled",
                sceneKitLightingMode: "authored-constant-v1"
            ),
            label: "non-East source-v06 authored constant"
        )
        try lightingTestRequiresFailure(
            lightingTestDescriptor(
                from: sourceV04Object,
                logicalBuildingID: "industrial_l02",
                sourceRevision: "source-v06",
                viewDirection: "east",
                sceneKitShadows: "current",
                sceneKitLightingMode: "authored-constant-v1"
            ),
            label: "source-v06 East current shadows"
        )
        try lightingTestRequiresFailure(
            lightingTestDescriptor(
                from: sourceV04Object,
                logicalBuildingID: "industrial_l02",
                sourceRevision: "source-v05",
                purpose: "diagnostic-regression",
                sceneKitShadows: "disabled",
                sceneKitLightingMode: "authored-constant-v1"
            ),
            label: "diagnostic source-v05 authored constant authority"
        )

        print(
            "PASS schema-1 and source-v04 retain Lambert defaults; only Industrial L2 source-v05 and source-v06 East source-authority resolve authored-constant-v1"
        )
    }
}
