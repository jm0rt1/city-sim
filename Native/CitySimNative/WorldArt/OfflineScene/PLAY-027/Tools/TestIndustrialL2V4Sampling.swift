import Foundation

enum IndustrialL2V4SamplingTestError: Error, CustomStringConvertible {
    case arguments
    case failed(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: test-industrial-l2-v4-sampling --scene <industrial-l02-source-v03-scene.json>"
        case let .failed(message):
            return message
        }
    }
}

func samplingTestArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2V4SamplingTestError.arguments
    }
    return arguments[index + 1]
}

func samplingTestDescriptor(
    from original: [String: Any],
    sourceRevision: String,
    logicalBuildingID: String = "industrial_l02",
    sceneKitShadows: String?
) throws -> SceneDescriptor {
    var object = original
    object["logicalBuildingID"] = logicalBuildingID
    object["sourceRevision"] = sourceRevision
    guard var sampling = object["sampling"] as? [String: Any] else {
        throw IndustrialL2V4SamplingTestError.failed("sampling missing")
    }
    sampling["sourceRevisionBinding"] = sourceRevision
    if let sceneKitShadows {
        sampling["sceneKitShadows"] = sceneKitShadows
    } else {
        sampling.removeValue(forKey: "sceneKitShadows")
    }
    object["sampling"] = sampling
    let data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
    return try JSONDecoder().decode(SceneDescriptor.self, from: data)
}

func samplingTestRequiresFailure(
    _ descriptor: SceneDescriptor,
    label: String
) throws {
    do {
        _ = try DescriptorSamplingResolver.resolve(descriptor: descriptor)
        throw IndustrialL2V4SamplingTestError.failed(
            "\(label) unexpectedly resolved"
        )
    } catch is SamplingContractError {
        return
    }
}

@main
enum TestIndustrialL2V4SamplingMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let sceneURL = URL(
            fileURLWithPath: try samplingTestArgument(
                "--scene",
                in: arguments
            )
        )
        guard
            let object = try JSONSerialization.jsonObject(
                with: Data(contentsOf: sceneURL)
            ) as? [String: Any]
        else {
            throw IndustrialL2V4SamplingTestError.failed(
                "scene is not a JSON object"
            )
        }

        let legacyV03 = try samplingTestDescriptor(
            from: object,
            sourceRevision: "source-v03",
            sceneKitShadows: nil
        )
        let legacyContract = try DescriptorSamplingResolver.resolve(
            descriptor: legacyV03
        )
        guard legacyContract.sceneKitShadows == "current" else {
            throw IndustrialL2V4SamplingTestError.failed(
                "source-v03 default shadow behavior changed"
            )
        }

        try samplingTestRequiresFailure(
            samplingTestDescriptor(
                from: object,
                sourceRevision: "source-v03",
                sceneKitShadows: "disabled"
            ),
            label: "source-v03 disabled shadows"
        )
        try samplingTestRequiresFailure(
            samplingTestDescriptor(
                from: object,
                sourceRevision: "source-v04",
                sceneKitShadows: nil
            ),
            label: "source-v04 without disabled shadows"
        )
        try samplingTestRequiresFailure(
            samplingTestDescriptor(
                from: object,
                sourceRevision: "source-v04",
                logicalBuildingID: "commercial_l02",
                sceneKitShadows: "disabled"
            ),
            label: "cross-family disabled shadows"
        )

        let sourceV04 = try samplingTestDescriptor(
            from: object,
            sourceRevision: "source-v04",
            sceneKitShadows: "disabled"
        )
        let sourceV04Contract = try DescriptorSamplingResolver.resolve(
            descriptor: sourceV04
        )
        guard
            sourceV04Contract.sceneKitShadows == "disabled",
            sourceV04Contract.sceneKitAntialiasing == "none",
            sourceV04Contract.linearOversamplingFactor == 4,
            sourceV04Contract.downsampleFilter
                == "CILanczosScaleTransform",
            sourceV04Contract.downsampleScale == 0.25,
            sourceV04Contract.quantizerStep == 32,
            sourceV04Contract.postQuantizationCanonicalizer?.version == 3
        else {
            throw IndustrialL2V4SamplingTestError.failed(
                "source-v04 did not preserve the schema-2 v3 sampling contract"
            )
        }

        print(
            "PASS Industrial L2 source-v04 alone binds disabled SceneKit shadows; accepted/default descriptors retain current shadows"
        )
    }
}
