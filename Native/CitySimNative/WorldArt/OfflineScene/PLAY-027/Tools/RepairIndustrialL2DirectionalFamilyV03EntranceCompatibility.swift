import CryptoKit
import Foundation

enum IndustrialL2DirectionalFamilyV03RepairError:
    Error,
    CustomStringConvertible
{
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: repair-industrial-l2-directional-family-v03 \
              --repository-root <path> \
              [--art-output-root <path>] \
              [--evidence-output-root <path>]
            """
        case let .invalid(message):
            return message
        }
    }
}

private let familyV03InputHashes = [
    "north":
        "57dd375469958d77186d952d34353335e91bcab9399941d0a61e7550a80f19d5",
    "south":
        "4c9e423236a77f668907d693582efb27122b77f3b2c9cc0fb23767c0c2a9f394",
    "west":
        "9d31e29abcb232f406441b3660b00d0150cf7745dfacd3c22bcbb597c434162e",
]

private let familyV03GeometryHashes = [
    "north":
        "c9ecd93a68e230315fe7a9213b3a4a277c0c6c235c62898282c11d3ce7e70f57",
    "south":
        "f036a561f796e49f62188573dc919c6dc25141aa3fe67a4c7f84df6a49017c18",
    "west":
        "a929f9bc244f153d7fbb52b6cb69c1860c32976c3d86d897b814fb3b3ff84e96",
]

private let familyV03EastDescriptorSHA256 =
    "482bea0169e9229df437b05ca6f0299046d49bb92e2e9d9ef4f3865df9be5fa0"
private let familyV03EastMaterialsSHA256 =
    "6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb"
private let familyV03EastRawSHA256 =
    "a32725fd0ea0436c1f8a13d319c3c66408a7cdf44ff8f2cdb72665839dd685a8"
private let familyV03V02PanelBuilderSHA256 =
    "07625630e25dc33e4546aae5ffec4180a70198cab3fd882a8c66aec5ab883823"

private func familyV03Argument(
    _ name: String,
    in arguments: [String],
    required: Bool = true
) throws -> String? {
    guard let index = arguments.firstIndex(of: name) else {
        if required {
            throw IndustrialL2DirectionalFamilyV03RepairError.arguments
        }
        return nil
    }
    guard index + 1 < arguments.count else {
        throw IndustrialL2DirectionalFamilyV03RepairError.arguments
    }
    return arguments[index + 1]
}

private func familyV03SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func familyV03SHA256(_ url: URL) throws -> String {
    familyV03SHA256(try Data(contentsOf: url))
}

private func familyV03CanonicalData(_ value: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func familyV03Object(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL2DirectionalFamilyV03RepairError.invalid(
            "could not decode \(url.path)"
        )
    }
    return object
}

private func familyV03WriteJSON(_ value: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2DirectionalFamilyV03RepairError.invalid(
            "output must be absent: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try familyV03CanonicalData(value).write(to: url, options: .atomic)
}

private func familyV03Equal(_ first: Any?, _ second: Any?) -> Bool {
    guard let first, let second else {
        return first == nil && second == nil
    }
    return (first as AnyObject).isEqual(second)
}

@main
enum RepairIndustrialL2DirectionalFamilyV03EntranceCompatibilityMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath:
                try familyV03Argument(
                    "--repository-root",
                    in: arguments
                )!
        ).standardizedFileURL
        let artRoot = URL(
            fileURLWithPath:
                try familyV03Argument(
                    "--art-output-root",
                    in: arguments,
                    required: false
                ) ?? root.appendingPathComponent(
                    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v03"
                ).path
        ).standardizedFileURL
        let evidenceRoot = URL(
            fileURLWithPath:
                try familyV03Argument(
                    "--evidence-output-root",
                    in: arguments,
                    required: false
                ) ?? root.appendingPathComponent(
                    "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v03"
                ).path
        ).standardizedFileURL
        guard
            artRoot.path.contains(
                "industrial-l02-directional-family-v03"
            ),
            evidenceRoot.path.contains(
                "industrial-l02/l02/directional-family-v03"
            ),
            !FileManager.default.fileExists(atPath: artRoot.path),
            !FileManager.default.fileExists(atPath: evidenceRoot.path)
        else {
            throw IndustrialL2DirectionalFamilyV03RepairError.invalid(
                "outputs must be absent and task-owned"
            )
        }

        let v02Root = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v02/scenes/industrial_l02/variant-0"
        )
        let eastDescriptorURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialsURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/materials/industrial-l02-east-calibration-v05.json"
        )
        let eastRawURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05/raw-calibration/diagnostics/east-primary/raw.png"
        )
        let panelBuilderURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL2DirectionalFamilyV02PrepixelPanels.swift"
        )
        guard
            try familyV03SHA256(eastDescriptorURL)
                == familyV03EastDescriptorSHA256,
            try familyV03SHA256(materialsURL)
                == familyV03EastMaterialsSHA256,
            try familyV03SHA256(eastRawURL)
                == familyV03EastRawSHA256,
            try familyV03SHA256(panelBuilderURL)
                == familyV03V02PanelBuilderSHA256
        else {
            throw IndustrialL2DirectionalFamilyV03RepairError.invalid(
                "immutable East or panel-builder input drift"
            )
        }

        let exactUnchangedKeys = [
            "schemaVersion",
            "logicalBuildingID",
            "variantID",
            "viewDirection",
            "sourceRevision",
            "sceneGeometryID",
            "productionSelected",
            "materialLibrary",
            "building",
            "facades",
            "props",
            "occlusionExclusions",
            "registration",
            "camera",
            "light",
            "derivation",
            "sampling",
            "toolchainFingerprint",
        ]
        var rows: [[String: Any]] = []
        for direction in ["north", "south", "west"] {
            let inputURL = v02Root.appendingPathComponent(
                "\(direction)/scene.json"
            )
            guard
                try familyV03SHA256(inputURL)
                    == familyV03InputHashes[direction],
                var input = try? familyV03Object(inputURL),
                var entrance = input["entrance"] as? [String: Any],
                entrance["stepCount"] == nil
            else {
                throw IndustrialL2DirectionalFamilyV03RepairError.invalid(
                    "\(direction) V02 input or missing-key premise drift"
                )
            }
            let original = input
            entrance["stepCount"] = 1
            input["entrance"] = entrance
            let outputURL = artRoot.appendingPathComponent(
                "scenes/industrial_l02/variant-0/\(direction)/scene.json"
            )
            try familyV03WriteJSON(input, to: outputURL)
            let retained = try familyV03Object(outputURL)
            let unchangedValuesExact =
                exactUnchangedKeys.allSatisfy { key in
                    familyV03Equal(original[key], retained[key])
                }
            guard
                let retainedEntrance =
                    retained["entrance"] as? [String: Any],
                retainedEntrance["stepCount"] as? Int == 1,
                unchangedValuesExact
            else {
                throw IndustrialL2DirectionalFamilyV03RepairError.invalid(
                    "\(direction) compatibility repair changed another contract value"
                )
            }
            var stripped = retained
            var strippedEntrance =
                stripped["entrance"] as! [String: Any]
            strippedEntrance.removeValue(forKey: "stepCount")
            stripped["entrance"] = strippedEntrance
            guard
                try familyV03CanonicalData(stripped)
                    == familyV03CanonicalData(original)
            else {
                throw IndustrialL2DirectionalFamilyV03RepairError.invalid(
                    "\(direction) descriptor differs beyond entrance.stepCount"
                )
            }
            rows.append([
                "direction": direction,
                "oldDescriptorSHA256":
                    familyV03InputHashes[direction]!,
                "newDescriptorSHA256":
                    try familyV03SHA256(outputURL),
                "oldCanonicalGeometrySHA256":
                    familyV03GeometryHashes[direction]!,
                "newCanonicalGeometrySHA256":
                    familyV03GeometryHashes[direction]!,
                "onlySemanticMutation": "entrance.stepCount",
                "oldValue": NSNull(),
                "newValue": 1,
                "allOtherDescriptorValuesExact": true,
                "productionSelected": false,
            ])
        }

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type":
                "industrial-l02-directional-family-v03-entrance-compatibility-repair",
            "inputCheckpoint":
                "ce2235083732a33f5bae7cb99a6270b25b2ff12b",
            "rejectionCheckpoint":
                "0d79e57f184698b3e1e0b940e686cfd879f707ba",
            "mutationContract":
                "add entrance.stepCount=1 only; preserve every other descriptor value",
            "directions": rows,
            "eastDescriptorBytePreserved": true,
            "eastMaterialLibraryBytePreserved": true,
            "eastRawBytePreserved": true,
            "panelBuilderSHA256":
                familyV03V02PanelBuilderSHA256,
            "panelBuilderReadsEntrance": false,
            "sceneKitProcessCount": 0,
            "metalSnapshotCount": 0,
            "rawPixelCount": 0,
            "normalizerProcessCount": 0,
            "sourceAuthority": false,
            "productionSelected": false,
            "passed": true,
        ]
        try familyV03WriteJSON(
            report,
            to: evidenceRoot.appendingPathComponent(
                "prepixel/DESCRIPTOR-COMPATIBILITY-REPAIR.json"
            )
        )
        print("PASS compatibility-only descriptors=\(rows.count)")
    }
}
