import CryptoKit
import Foundation

enum SamplingDescriptorToolError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: create-sampling-regression-descriptors --repository-root <path> --output-root <diagnostics-path> --manifest <json> [--contract-revision v1|v2]"
        case let .invalid(message):
            return message
        }
    }
}

func samplingToolOptionalArgument(
    _ name: String,
    in arguments: [String]
) -> String? {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        return nil
    }
    return arguments[index + 1]
}

func samplingToolArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw SamplingDescriptorToolError.arguments
    }
    return arguments[index + 1]
}

func samplingToolSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func samplingToolRelativePath(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path.hasSuffix("/")
        ? repositoryRoot.path
        : repositoryRoot.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func samplingToolCanonicalData(_ object: Any) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

func samplingToolImmutablePayload(
    _ object: [String: Any]
) throws -> Data {
    var payload = object
    payload.removeValue(forKey: "schema")
    payload.removeValue(forKey: "sampling")
    guard var camera = payload["camera"] as? [String: Any] else {
        throw SamplingDescriptorToolError.invalid("camera missing")
    }
    camera.removeValue(forKey: "oversamplingFactor")
    payload["camera"] = camera
    return try samplingToolCanonicalData(payload)
}

func samplingBlock(
    sourceRevision: String,
    contractRevision: String
) throws -> [String: Any] {
    guard ["v1", "v2"].contains(contractRevision) else {
        throw SamplingDescriptorToolError.invalid(
            "contract revision must be v1 or v2"
        )
    }
    var block: [String: Any] = [
        "contractID":
            "play027-deterministic-4x-no-msaa-lanczos-\(contractRevision)",
        "sourceRevisionBinding": sourceRevision,
        "purpose": "diagnostic-regression",
        "sceneKitAntialiasing": "none",
        "linearOversamplingFactor": 4,
        "downsample": [
            "filter": "CILanczosScaleTransform",
            "scale": 0.25,
            "aspectRatio": 1,
        ],
        "ciContext": [
            "useSoftwareRenderer": true,
            "cacheIntermediates": false,
            "workingColorSpace": "extended-srgb",
            "outputColorSpace": "srgb",
        ],
        "quantizer": [
            "id": "step32-midpoint-offset8-v1",
            "step": 32,
            "midpointOffset": 8,
            "chromaBypassRGBA": [255, 0, 255, 255],
        ],
        "canonicalizer": [
            "id": "imageio-sips-png-v1",
            "encoder": "ImageIO",
            "postEncoder": "/usr/bin/sips",
            "format": "png",
        ],
    ]
    if contractRevision == "v2" {
        block["postQuantizationCanonicalizer"] = [
            "algorithm": "opaque-isolated-one-quantum-majority-3x3",
            "version": 2,
            "quantizationQuantum": 32,
            "neighborhoodSize": 3,
            "majorityThreshold": 7,
            "requiresFullyOpaqueNeighborhood": true,
            "immutableSourceBuffer": true,
            "requiresChromaFreeNeighborhood": true,
            "channels": "rgb-only",
            "preservesAlpha": true,
            "preservesChroma": true,
        ]
    }
    return block
}

@main
enum CreateSamplingRegressionDescriptorsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try samplingToolArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try samplingToolArgument(
                "--output-root",
                in: arguments
            )
        ).standardizedFileURL
        let manifestURL = URL(
            fileURLWithPath: try samplingToolArgument(
                "--manifest",
                in: arguments
            )
        ).standardizedFileURL
        let contractRevision =
            samplingToolOptionalArgument(
                "--contract-revision",
                in: arguments
            ) ?? "v1"
        guard ["v1", "v2"].contains(contractRevision) else {
            throw SamplingDescriptorToolError.invalid(
                "contract revision must be v1 or v2"
            )
        }
        guard
            outputRoot.path.contains("/diagnostics/"),
            manifestURL.path.contains("/diagnostics/")
        else {
            throw SamplingDescriptorToolError.invalid(
                "schema-2 regression copies must remain under diagnostics"
            )
        }

        let sceneRoot = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes"
        )
        let commercialIDs = [
            "commercial_l01",
            "commercial_l02",
            "commercial_l03",
        ]
        let residentialIDs = [
            "residential_l01",
            "residential_l02",
            "residential_l03",
            "residential_l04",
        ]
        var samples: [(String, String)] = []
        for logicalID in commercialIDs {
            for direction in ["north", "east", "south", "west"] {
                samples.append((logicalID, direction))
            }
        }
        for logicalID in residentialIDs {
            samples.append((logicalID, "west"))
        }

        var records: [[String: Any]] = []
        for (logicalID, direction) in samples {
            let acceptedURL = sceneRoot
                .appendingPathComponent(logicalID)
                .appendingPathComponent("variant-0")
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let acceptedData = try Data(contentsOf: acceptedURL)
            guard
                var object = try JSONSerialization.jsonObject(
                    with: acceptedData
                ) as? [String: Any],
                (object["schema"] as? NSNumber)?.intValue == 1,
                object["sampling"] == nil,
                let sourceRevision = object["sourceRevision"] as? String,
                let camera = object["camera"] as? [String: Any],
                (camera["oversamplingFactor"] as? NSNumber)?.intValue == 2,
                (object["productionSelected"] as? Bool) == false
            else {
                throw SamplingDescriptorToolError.invalid(
                    "\(logicalID)/\(direction) is not an accepted schema-1 descriptor"
                )
            }
            let acceptedImmutable = try samplingToolImmutablePayload(object)
            object["schema"] = 2
            var schema2Camera = camera
            schema2Camera["oversamplingFactor"] = 4
            object["camera"] = schema2Camera
            object["sampling"] = try samplingBlock(
                sourceRevision: sourceRevision,
                contractRevision: contractRevision
            )
            let outputImmutable = try samplingToolImmutablePayload(object)
            guard acceptedImmutable == outputImmutable else {
                throw SamplingDescriptorToolError.invalid(
                    "\(logicalID)/\(direction) changed authored payload"
                )
            }
            var outputData = try JSONSerialization.data(
                withJSONObject: object,
                options: [
                    .prettyPrinted,
                    .sortedKeys,
                    .withoutEscapingSlashes,
                ]
            )
            outputData.append(0x0a)
            let outputURL = outputRoot
                .appendingPathComponent(logicalID)
                .appendingPathComponent("variant-0")
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try outputData.write(to: outputURL, options: .atomic)
            records.append([
                "logicalBuildingID": logicalID,
                "direction": direction,
                "sourceRevision": sourceRevision,
                "acceptedDescriptorFile": samplingToolRelativePath(
                    acceptedURL,
                    repositoryRoot: repositoryRoot
                ),
                "acceptedDescriptorSHA256":
                    samplingToolSHA256(acceptedData),
                "diagnosticDescriptorFile": samplingToolRelativePath(
                    outputURL,
                    repositoryRoot: repositoryRoot
                ),
                "diagnosticDescriptorSHA256":
                    samplingToolSHA256(outputData),
                "immutableAuthoredPayloadSHA256":
                    samplingToolSHA256(acceptedImmutable),
                "changedFields": [
                    "schema",
                    "camera.oversamplingFactor",
                    "sampling",
                ],
                "authoredGeometryChanged": false,
                "productionSelected": false,
            ])
        }
        let manifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contractID":
                "play027-deterministic-4x-no-msaa-lanczos-\(contractRevision)",
            "contractRevision": contractRevision,
            "purpose": "diagnostic-regression",
            "samplePolicy": [
                "commercial": "L1-L3 all N/E/S/W",
                "residential":
                    "L1-L4 West; far-frontage orientation matching the isolated L4 seam",
            ],
            "acceptedDescriptorsModified": false,
            "sampleCount": records.count,
            "samples": records,
            "productionSelected": false,
        ]
        var manifestData = try JSONSerialization.data(
            withJSONObject: manifest,
            options: [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes,
            ]
        )
        manifestData.append(0x0a)
        try FileManager.default.createDirectory(
            at: manifestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try manifestData.write(to: manifestURL, options: .atomic)
    }
}
