import CryptoKit
import Foundation

enum AdvanceCommercialL4V3Error: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: advance-commercial-l4-v3-descriptors --repository-root <path> --manifest <json>"
        case let .invalid(message):
            return message
        }
    }
}

func advanceArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw AdvanceCommercialL4V3Error.arguments
    }
    return arguments[index + 1]
}

func advanceSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func advanceRelativePath(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func authoredPayload(_ object: [String: Any]) throws -> Data {
    var payload = object
    payload.removeValue(forKey: "schema")
    payload.removeValue(forKey: "sourceRevision")
    payload.removeValue(forKey: "sceneGeometryID")
    payload.removeValue(forKey: "sampling")
    payload.removeValue(forKey: "toolchainFingerprint")
    guard var camera = payload["camera"] as? [String: Any] else {
        throw AdvanceCommercialL4V3Error.invalid("camera missing")
    }
    camera.removeValue(forKey: "oversamplingFactor")
    payload["camera"] = camera
    return try JSONSerialization.data(
        withJSONObject: payload,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

func commercialL4V3Sampling() -> [String: Any] {
    [
        "contractID": "play027-deterministic-4x-no-msaa-lanczos-v3",
        "sourceRevisionBinding": "source-v03",
        "purpose": "source-authority",
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
        "postQuantizationCanonicalizer": [
            "algorithm": "opaque-isolated-one-quantum-majority-3x3",
            "version": 3,
            "quantizationQuantum": 32,
            "neighborhoodSize": 3,
            "majorityThreshold": 7,
            "requiresFullyOpaqueNeighborhood": true,
            "immutableSourceBuffer": true,
            "requiresChromaFreeNeighborhood": true,
            "channels": "rgb-only",
            "preservesAlpha": true,
            "preservesChroma": true,
            "boundaryAssist": [
                "algorithm":
                    "immutable-prequantized-one-value-boundary-6-plus-1",
                "version": 1,
                "baseQuantizedMajorityCount": 6,
                "requiredBoundaryVoteCount": 1,
                "effectiveSupportCount": 7,
                "maximumCompetingSupportAfterBoundaryReclassification": 2,
                "quantizerStep": 32,
                "quantizerMidpointOffset": 8,
                "boundaryBandWidthValues": 1,
                "requiresSameChannelEvidence": true,
                "immutablePrequantizedBuffer": true,
                "recordsBoundaryVoteReason": true,
            ],
        ],
    ]
}

@main
enum AdvanceCommercialL4V3DescriptorsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try advanceArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let manifestURL = URL(
            fileURLWithPath: try advanceArgument(
                "--manifest",
                in: arguments
            )
        ).standardizedFileURL
        guard
            manifestURL.path.contains(
                "/docs/production/evidence/PLAY-027/"
            )
        else {
            throw AdvanceCommercialL4V3Error.invalid(
                "manifest must remain under PLAY-027 evidence"
            )
        }

        let sceneRoot = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/commercial_l04/variant-0"
        )
        let archiveRoot = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/commercial-l01-l04/l04/source-v02-rejected/descriptors"
        )
        let v3FingerprintURL = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/commercial-l01-l04/l04/diagnostics/schema2-sampling-regression-v03/TOOLCHAIN-FINGERPRINT.json"
        )
        let v3FingerprintData = try Data(contentsOf: v3FingerprintURL)
        let directions = ["north", "east", "south", "west"]
        var samples: [[String: Any]] = []
        var descriptorHashes = Set<String>()
        var geometryIDs = Set<String>()

        for direction in directions {
            let sceneURL = sceneRoot
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let archiveURL = archiveRoot
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let originalData: Data
            if FileManager.default.fileExists(atPath: archiveURL.path) {
                originalData = try Data(contentsOf: archiveURL)
            } else {
                originalData = try Data(contentsOf: sceneURL)
            }
            guard
                var object = try JSONSerialization.jsonObject(
                    with: originalData
                ) as? [String: Any],
                (object["schema"] as? NSNumber)?.intValue == 1,
                object["sourceRevision"] as? String == "source-v02",
                object["logicalBuildingID"] as? String == "commercial_l04",
                object["viewDirection"] as? String == direction,
                object["authoredIndependently"] as? Bool == true,
                object["productionSelected"] as? Bool == false,
                object["sampling"] == nil,
                let derivation = object["derivation"] as? [String: Any],
                derivation["siblingSource"] is NSNull,
                derivation["mirror"] as? Bool == false,
                (derivation["rotationDegrees"] as? NSNumber)?.doubleValue
                    == 0,
                derivation["transform"] as? String == "none",
                let originalGeometryID =
                    object["sceneGeometryID"] as? String,
                originalGeometryID.hasSuffix("geometry-v2"),
                var camera = object["camera"] as? [String: Any],
                (camera["oversamplingFactor"] as? NSNumber)?.intValue == 2
            else {
                throw AdvanceCommercialL4V3Error.invalid(
                    "\(direction) is not the frozen source-v02 descriptor"
                )
            }
            if !FileManager.default.fileExists(atPath: archiveURL.path) {
                try FileManager.default.createDirectory(
                    at: archiveURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try originalData.write(to: archiveURL, options: .atomic)
            }

            let originalPayload = try authoredPayload(object)
            object["schema"] = 2
            object["sourceRevision"] = "source-v03"
            object["sceneGeometryID"] =
                String(originalGeometryID.dropLast("geometry-v2".count))
                + "geometry-v3"
            camera["oversamplingFactor"] = 4
            object["camera"] = camera
            object["sampling"] = commercialL4V3Sampling()
            object["toolchainFingerprint"] = [
                "role": "frozen-schema-2-v3-offline-host-and-frameworks",
                "file": advanceRelativePath(
                    v3FingerprintURL,
                    repositoryRoot: repositoryRoot
                ),
                "sha256": advanceSHA256(v3FingerprintData),
            ]
            let candidatePayload = try authoredPayload(object)
            guard originalPayload == candidatePayload else {
                throw AdvanceCommercialL4V3Error.invalid(
                    "\(direction) authored payload changed"
                )
            }

            var candidateData = try JSONSerialization.data(
                withJSONObject: object,
                options: [
                    .prettyPrinted,
                    .sortedKeys,
                    .withoutEscapingSlashes,
                ]
            )
            candidateData.append(0x0a)
            try candidateData.write(to: sceneURL, options: .atomic)

            let descriptorHash = advanceSHA256(candidateData)
            let geometryID = object["sceneGeometryID"] as! String
            guard
                descriptorHashes.insert(descriptorHash).inserted,
                geometryIDs.insert(geometryID).inserted
            else {
                throw AdvanceCommercialL4V3Error.invalid(
                    "\(direction) aliases a sibling descriptor"
                )
            }
            samples.append([
                "logicalBuildingID": "commercial_l04",
                "direction": direction,
                "sourceRevision": "source-v03",
                "archivedSourceV02File": advanceRelativePath(
                    archiveURL,
                    repositoryRoot: repositoryRoot
                ),
                "archivedSourceV02SHA256": advanceSHA256(originalData),
                "sourceV03DescriptorFile": advanceRelativePath(
                    sceneURL,
                    repositoryRoot: repositoryRoot
                ),
                "sourceV03DescriptorSHA256": descriptorHash,
                "sceneGeometryID": geometryID,
                "immutableAuthoredPayloadSHA256":
                    advanceSHA256(originalPayload),
                "authoredPayloadChanged": false,
                "orientationTransform": "none",
                "productionSelected": false,
            ])
        }

        let manifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "commercial_l04",
            "sourceRevision": "source-v03",
            "contractID": "play027-deterministic-4x-no-msaa-lanczos-v3",
            "samplingPurpose": "source-authority",
            "descriptorCount": samples.count,
            "uniqueDescriptorHashCount": descriptorHashes.count,
            "uniqueSceneGeometryIDCount": geometryIDs.count,
            "authoredGeometryChangedFromSourceV02": false,
            "samples": samples,
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
