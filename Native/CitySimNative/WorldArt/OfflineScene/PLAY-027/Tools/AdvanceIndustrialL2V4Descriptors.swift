import CryptoKit
import Foundation

enum AdvanceIndustrialL2V4Error: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: advance-industrial-l2-v4-descriptors --repository-root <path> --fingerprint <json> --evidence-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

func industrialL2V4Argument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw AdvanceIndustrialL2V4Error.arguments
    }
    return arguments[index + 1]
}

func industrialL2V4SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func industrialL2V4Relative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func industrialL2V4JSONData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

func industrialL2V4ImmutablePayload(
    _ object: [String: Any]
) throws -> Data {
    var payload = object
    payload.removeValue(forKey: "sourceRevision")
    payload.removeValue(forKey: "sampling")
    payload.removeValue(forKey: "toolchainFingerprint")
    return try JSONSerialization.data(
        withJSONObject: payload,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

@main
enum AdvanceIndustrialL2V4DescriptorsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try industrialL2V4Argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let fingerprintURL = URL(
            fileURLWithPath: try industrialL2V4Argument(
                "--fingerprint",
                in: arguments
            )
        ).standardizedFileURL
        let evidenceRoot = URL(
            fileURLWithPath: try industrialL2V4Argument(
                "--evidence-root",
                in: arguments
            )
        ).standardizedFileURL
        let directions = ["north", "east", "south", "west"]
        let expectedV03Hashes = [
            "north":
                "aee5c7ef5de5b62fb357335c09d9a020ed97582882bfd1bf7ac7bc21f6d3a5b6",
            "east":
                "24ccd400535090532be046fe9868c069f3fc1b94aa999fc4c6569b74c24c03e1",
            "south":
                "ce4c8067135a1f57ee50dbfed9aa3b83b7fab6aa847aa7bd8c79cb783bb72d1c",
            "west":
                "8ce989ea6c4b85fbdf04ba002236179c45b71b0fbe2cc2d5a39a2abf28b29a1e",
        ]
        let sceneRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/industrial_l02/variant-0"
        )
        let materialURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/materials/industrial-l01-l04-v0-materials.json"
        )
        let materialData = try Data(contentsOf: materialURL)
        let materialSHA = industrialL2V4SHA256(materialData)
        guard
            materialSHA
                == "166a19d5569a927d6ccdbaf1b29131835238bb3622e66d3b376d9eb33008f1ef"
        else {
            throw AdvanceIndustrialL2V4Error.invalid(
                "industrial material anchor changed"
            )
        }
        let fingerprintData = try Data(contentsOf: fingerprintURL)
        guard
            let fingerprint = try JSONSerialization.jsonObject(
                with: fingerprintData
            ) as? [String: Any],
            let sampling =
                fingerprint["descriptorSamplingContract"]
                    as? [String: Any],
            sampling["contractID"] as? String
                == "play027-deterministic-4x-no-msaa-lanczos-v3",
            sampling["sceneKitAntialiasing"] as? String == "none",
            sampling["sceneKitShadows"] as? String == "disabled",
            (sampling["linearOversamplingFactor"] as? NSNumber)?.intValue
                == 4,
            let fingerprintAuthority =
                fingerprint["sourceAuthority"] as? String
        else {
            throw AdvanceIndustrialL2V4Error.invalid(
                "fingerprint does not bind schema-2 v3 shadows-disabled sampling"
            )
        }
        let fingerprintSHA = industrialL2V4SHA256(fingerprintData)
        let archiveRoot = evidenceRoot.appendingPathComponent(
            "source-v03-descriptors"
        )
        guard
            !FileManager.default.fileExists(atPath: evidenceRoot.path)
        else {
            throw AdvanceIndustrialL2V4Error.invalid(
                "source-v04 evidence root already exists"
            )
        }
        try FileManager.default.createDirectory(
            at: archiveRoot,
            withIntermediateDirectories: true
        )

        var records: [[String: Any]] = []
        var v04DescriptorHashes = Set<String>()
        var immutablePayloadHashes = Set<String>()
        for direction in directions {
            let sceneURL = sceneRoot
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let originalData = try Data(contentsOf: sceneURL)
            let originalSHA = industrialL2V4SHA256(originalData)
            guard originalSHA == expectedV03Hashes[direction] else {
                throw AdvanceIndustrialL2V4Error.invalid(
                    "\(direction) source-v03 descriptor hash changed"
                )
            }
            guard
                var object = try JSONSerialization.jsonObject(
                    with: originalData
                ) as? [String: Any],
                object["schema"] as? Int == 2,
                object["logicalBuildingID"] as? String == "industrial_l02",
                object["sourceRevision"] as? String == "source-v03",
                object["viewDirection"] as? String == direction,
                object["productionSelected"] as? Bool == false,
                var descriptorSampling =
                    object["sampling"] as? [String: Any],
                descriptorSampling["sourceRevisionBinding"] as? String
                    == "source-v03",
                descriptorSampling["sceneKitShadows"] == nil
            else {
                throw AdvanceIndustrialL2V4Error.invalid(
                    "\(direction) is not the frozen source-v03 authority"
                )
            }
            let immutableBefore = try industrialL2V4ImmutablePayload(
                object
            )
            let archiveURL = archiveRoot.appendingPathComponent(
                "\(direction)-source-v03.json"
            )
            try originalData.write(to: archiveURL, options: .atomic)

            object["sourceRevision"] = "source-v04"
            descriptorSampling["sourceRevisionBinding"] = "source-v04"
            descriptorSampling["sceneKitShadows"] = "disabled"
            object["sampling"] = descriptorSampling
            object["toolchainFingerprint"] = [
                "role":
                    "frozen-schema-2-v3-shadows-disabled-offline-host-and-frameworks",
                "file": industrialL2V4Relative(
                    fingerprintURL,
                    root: root
                ),
                "sha256": fingerprintSHA,
            ]
            let immutableAfter = try industrialL2V4ImmutablePayload(object)
            guard immutableBefore == immutableAfter else {
                throw AdvanceIndustrialL2V4Error.invalid(
                    "\(direction) authored payload changed"
                )
            }
            let v04Data = try industrialL2V4JSONData(object)
            let descriptor = try JSONDecoder().decode(
                SceneDescriptor.self,
                from: v04Data
            )
            let resolved = try DescriptorSamplingResolver.resolve(
                descriptor: descriptor
            )
            guard
                resolved.sceneKitShadows == "disabled",
                resolved.sceneKitAntialiasing == "none",
                resolved.linearOversamplingFactor == 4,
                resolved.downsampleScale == 0.25,
                resolved.postQuantizationCanonicalizer?.version == 3
            else {
                throw AdvanceIndustrialL2V4Error.invalid(
                    "\(direction) source-v04 sampling did not resolve"
                )
            }
            try v04Data.write(to: sceneURL, options: .atomic)
            let v04SHA = industrialL2V4SHA256(v04Data)
            guard v04DescriptorHashes.insert(v04SHA).inserted else {
                throw AdvanceIndustrialL2V4Error.invalid(
                    "\(direction) descriptor aliases a sibling"
                )
            }
            let immutableSHA = industrialL2V4SHA256(immutableAfter)
            immutablePayloadHashes.insert(immutableSHA)
            records.append([
                "direction": direction,
                "sourceV03DescriptorFile": industrialL2V4Relative(
                    archiveURL,
                    root: root
                ),
                "sourceV03DescriptorSHA256": originalSHA,
                "sourceV04DescriptorFile": industrialL2V4Relative(
                    sceneURL,
                    root: root
                ),
                "sourceV04DescriptorSHA256": v04SHA,
                "immutableAuthoredPayloadSHA256": immutableSHA,
                "sceneGeometryID": descriptor.sceneGeometryID,
                "sceneKitAntialiasing": resolved.sceneKitAntialiasing,
                "sceneKitShadows": resolved.sceneKitShadows,
                "linearOversamplingFactor":
                    resolved.linearOversamplingFactor,
                "downsampleFilter": resolved.downsampleFilter,
                "downsampleScale": resolved.downsampleScale,
                "quantizerID": resolved.quantizerID,
                "postQuantizationCanonicalizerVersion":
                    resolved.postQuantizationCanonicalizer?.version ?? 0,
                "authoredPayloadChanged": false,
                "productionSelected": false,
            ])
        }
        guard
            records.count == 4,
            v04DescriptorHashes.count == 4,
            immutablePayloadHashes.count == 4
        else {
            throw AdvanceIndustrialL2V4Error.invalid(
                "source-v04 direction identity gate failed"
            )
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l02",
            "variantID": "variant-0",
            "sourceRevision": "source-v04",
            "sourceAuthority": fingerprintAuthority,
            "contract":
                "play027-deterministic-4x-no-msaa-lanczos-v3",
            "sceneKitShadows": "disabled",
            "fingerprintFile": industrialL2V4Relative(
                fingerprintURL,
                root: root
            ),
            "fingerprintSHA256": fingerprintSHA,
            "materialLibraryFile": industrialL2V4Relative(
                materialURL,
                root: root
            ),
            "materialLibrarySHA256": materialSHA,
            "directions": records,
            "descriptorCount": records.count,
            "uniqueDescriptorHashCount": v04DescriptorHashes.count,
            "uniqueImmutableAuthoredPayloadHashCount":
                immutablePayloadHashes.count,
            "geometryChanged": false,
            "materialsChanged": false,
            "cameraChanged": false,
            "registrationChanged": false,
            "samplingChanges": [
                "sourceRevision: source-v03 -> source-v04",
                "sourceRevisionBinding: source-v03 -> source-v04",
                "sceneKitShadows: implicit current -> disabled",
                "toolchain fingerprint: v3 current shadows -> v3 disabled shadows",
            ],
            "rawPixelsCreated": false,
            "normalizationPerformed": false,
            "productionSelected": false,
            "passed": true,
        ]
        let reportURL = evidenceRoot.appendingPathComponent(
            "SOURCE-V04-DESCRIPTOR-FREEZE.json"
        )
        try industrialL2V4JSONData(report).write(
            to: reportURL,
            options: .atomic
        )
    }
}
