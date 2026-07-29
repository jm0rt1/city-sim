import CryptoKit
import Foundation

enum IndustrialL3V3AdvanceError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: advance-industrial-l3-v3-descriptors --repository-root <path> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

private let l3V2DescriptorHashes = [
    "north":
        "78803712a2b4118abef6ff90119444b1c4093f5cb442348f3cdb9b3e4bf1fe51",
    "east":
        "dbe0dd260d28d848864d4194826f5147ec91314cf75b95bff9349bbfe466342c",
    "south":
        "1e548d4694bea47b36e9aca1a97e901917ea92742fd6366f53a4e92bfcba1b2b",
    "west":
        "bc0812eb16008bb0a544873fb3d24c4b01c470c405b4f6051a36a400c68856ce",
]

private func advanceArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3V3AdvanceError.arguments
    }
    return arguments[index + 1]
}

private func advanceSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func advanceObject(_ data: Data) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    else {
        throw IndustrialL3V3AdvanceError.invalid(
            "input is not a JSON object"
        )
    }
    return object
}

private func advanceJSON(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func canonicalV2Payload(
    _ object: [String: Any],
    removingV3Changes: Bool
) throws -> Data {
    var payload = object
    guard var sampling = payload["sampling"] as? [String: Any] else {
        throw IndustrialL3V3AdvanceError.invalid("sampling block missing")
    }
    if removingV3Changes {
        payload["sourceRevision"] = "source-v02"
        sampling["sourceRevisionBinding"] = "source-v02"
        sampling.removeValue(forKey: "preLanczosCanonicalizer")
        payload["sampling"] = sampling
    }
    return try JSONSerialization.data(
        withJSONObject: payload,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

@main
enum AdvanceIndustrialL3V3DescriptorsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try advanceArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try advanceArgument("--report", in: arguments)
        ).standardizedFileURL
        let base =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
        let v2Root =
            base
            + "industrial-l03-directional-family-v02/scenes/"
            + "industrial_l03/variant-0"
        let v3Root =
            base
            + "industrial-l03-directional-family-v03/scenes/"
            + "industrial_l03/variant-0"
        let l2ReferenceRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/"
            + "industrial_l02/variant-0/east/scene.json"
        let l2ReferenceData = try Data(
            contentsOf: root.appendingPathComponent(l2ReferenceRelative)
        )
        guard
            advanceSHA256(l2ReferenceData)
                == "69c2d2b37e65c91fb19e6c1f3b913e4f00a22558694fdd87b97a9942c6ed6a90",
            let l2Sampling =
                try advanceObject(l2ReferenceData)["sampling"]
                as? [String: Any],
            let preLanczos =
                l2Sampling["preLanczosCanonicalizer"] as? [String: Any],
            preLanczos["algorithm"] as? String
                == "rgb-step32-midpoint8-preserve-alpha-chroma-v1",
            (preLanczos["version"] as? NSNumber)?.intValue == 1
        else {
            throw IndustrialL3V3AdvanceError.invalid(
                "accepted Industrial L2 source-v07 East reference drift"
            )
        }

        var records: [[String: Any]] = []
        for direction in ["north", "east", "south", "west"] {
            guard let expectedHash = l3V2DescriptorHashes[direction] else {
                throw IndustrialL3V3AdvanceError.invalid(
                    "missing v02 hash for \(direction)"
                )
            }
            let inputRelative = "\(v2Root)/\(direction)/scene.json"
            let outputRelative = "\(v3Root)/\(direction)/scene.json"
            let inputData = try Data(
                contentsOf: root.appendingPathComponent(inputRelative)
            )
            guard advanceSHA256(inputData) == expectedHash else {
                throw IndustrialL3V3AdvanceError.invalid(
                    "\(direction) v02 descriptor hash drift"
                )
            }
            let original = try advanceObject(inputData)
            guard
                original["logicalBuildingID"] as? String
                    == "industrial_l03",
                original["variantID"] as? String == "variant-0",
                original["sourceRevision"] as? String == "source-v02",
                original["viewDirection"] as? String == direction,
                var sampling = original["sampling"] as? [String: Any],
                sampling["sourceRevisionBinding"] as? String
                    == "source-v02",
                sampling["contractID"] as? String
                    == "play027-deterministic-4x-no-msaa-lanczos-v3",
                sampling["purpose"] as? String == "source-authority",
                sampling["preLanczosCanonicalizer"] == nil
            else {
                throw IndustrialL3V3AdvanceError.invalid(
                    "\(direction) v02 identity mismatch"
                )
            }
            var advanced = original
            advanced["sourceRevision"] = "source-v03"
            sampling["sourceRevisionBinding"] = "source-v03"
            sampling["preLanczosCanonicalizer"] = preLanczos
            advanced["sampling"] = sampling

            guard
                try canonicalV2Payload(
                    original,
                    removingV3Changes: false
                )
                == canonicalV2Payload(
                    advanced,
                    removingV3Changes: true
                )
            else {
                throw IndustrialL3V3AdvanceError.invalid(
                    "\(direction) changed outside the authorized sampling fields"
                )
            }
            let outputData = try advanceJSON(advanced)
            let outputURL = root.appendingPathComponent(outputRelative)
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try outputData.write(to: outputURL, options: .atomic)
            _ = try JSONDecoder().decode(
                SceneDescriptor.self,
                from: outputData
            )
            records.append([
                "direction": direction,
                "v02File": inputRelative,
                "v02SHA256": expectedHash,
                "v03File": outputRelative,
                "v03SHA256": advanceSHA256(outputData),
                "canonicalV02ValueIdentityAfterRemovingV3Changes": true,
            ])
        }

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "sourceRevision": "source-v03",
            "referencePreLanczosDescriptorFile": l2ReferenceRelative,
            "referencePreLanczosDescriptorSHA256":
                advanceSHA256(l2ReferenceData),
            "allowedChanges": [
                "sourceRevision source-v02 to source-v03",
                "sampling.sourceRevisionBinding source-v02 to source-v03",
                "sampling.preLanczosCanonicalizer exact accepted L2 v07 block",
            ],
            "descriptors": records,
            "materialMutationCount": 0,
            "geometryMutationCount": 0,
            "productionSelected": false,
            "sourceAuthority": false,
            "passed": records.count == 4,
        ]
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try advanceJSON(report).write(to: reportURL, options: .atomic)
    }
}
