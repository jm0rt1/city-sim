import CryptoKit
import Foundation

enum IndustrialL2EastV04ValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l2-east-v04-prepixel-reset --repository-root <path> --output <path>"
        case let .invalid(message):
            return message
        }
    }
}

private let expectedFiles: [String: String] = [
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v04/materials/industrial-l02-projection-silhouette-reset-v04.json":
        "31f500488b7d143e88015bf71b53db4d1a4b19076563dc3d774d61f00c8b83a3",
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v04/scenes/industrial_l02/variant-0/east/scene.json":
        "fdb92d39acb8847178a95d1e0f6315332a93eda01df71388e54582fe1e6f12bf",
    "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/diagnosis/CAUSAL-DIAGNOSIS.md":
        "c7a10f38f19744b5fbf043e4b2720183f53b99722f2a92ef660ad3da59886cc8",
    "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/diagnosis/MATERIAL-SEGMENTATION.json":
        "2c07696e2d6fc14e554ee1715a84bc741f70fcb1d110d927c5892ce67dfde48a",
    "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/prepixel/INVENTORY.json":
        "799bcd3cadbb97622bbb36da6d5306ea5e24fa403b2cf3ec28f3aea2d92d742f",
    "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/prepixel/PREDICTED-VALUE-LEDGER.json":
        "60da32f89de16cd4706675dac83dc6dbd0395305acbb5a9cd1ee0f2ef67cb77e",
    "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/prepixel/PREPIXEL-VALIDATION.json":
        "bd53c10abbe0393555333b5498db25f6973a775248a981bf523d408ad2bbb17a",
    "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/prepixel/V04-ALPHA-COMPOSITOR-CONTRACT.json":
        "351aed1910d7b680991815a479897fb4849060dd19798d662fe8c03f494f64e9",
    "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/prepixel/V04-MATERIAL-LIGHT-CONTRACT.json":
        "96d51f18e8a7eef98eba3bdd1d3af74c0be90e648257602fa844cf43f090ba15",
]

private let preservedFiles: [String: String] = [
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v03/scenes/industrial_l02/variant-0/east/scene.json":
        "d32c2aaf03cebf53f3821515b19ab03fd86e759687fed9b4bf68eda14e1b65ca",
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/materials/industrial-l02-projection-silhouette-reset-v02.json":
        "94069509093c122d4cb2383bd648757561f6561f78b8345c6222b5354f3f18f6",
    "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/diagnostics/east-primary/raw.png":
        "24e57812ef0d0d024aef8b4d45a2bda9f98c902874b534aed9ff6040707867ba",
    "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/diagnostics/east-primary/pre-chroma-registered-building.png":
        "b571b6bbabf5c1d1c2a60167af076d05ece13d379d323368c6150f79e2e119c6",
    "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/diagnostics/east-primary/pre-chroma-registered-alpha.png":
        "f6cdf5833011cf2842e2f4245216d8224de760c63ede8ec4473b259667afeafc",
    "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/diagnostics/east-primary/neutral-alpha-composite.png":
        "89fcc84601214345e35c2ac07cd0fc4475aa99b038e03553ca515bfcfbc7506c",
    "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/review/RAW-PROBE-METRICS.json":
        "cd55e28517b2e2ca5896d433f5a0646840786b8684a45c2f3ef0bd931f69c1c9",
    "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/rejection/REJECTION.md":
        "3ccefb83cded63bf0958c4b28eabf00af8ccf4551dd4191d3675c4641110a877",
]

private func argument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2EastV04ValidationError.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

private func loadJSON(_ url: URL) throws -> [String: Any] {
    guard
        let value = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL2EastV04ValidationError.invalid(
            "could not decode \(url.path)"
        )
    }
    return value
}

private func writeJSON(
    _ value: Any,
    to url: URL
) throws {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}

private func canonicalGeometry(
    _ descriptor: [String: Any]
) throws -> String {
    guard
        let building = descriptor["building"],
        let camera = descriptor["camera"],
        let registration = descriptor["registration"],
        let entrance = descriptor["entrance"],
        let facades = descriptor["facades"],
        let props = descriptor["props"],
        let occlusion = descriptor["occlusionExclusions"]
    else {
        throw IndustrialL2EastV04ValidationError.invalid(
            "geometry contract fields missing"
        )
    }
    func strippingMaterials(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            var stripped: [String: Any] = [:]
            for (key, child) in dictionary
            where !key.lowercased().contains("material")
            {
                stripped[key] = strippingMaterials(child)
            }
            return stripped
        }
        if let array = value as? [Any] {
            return array.map(strippingMaterials)
        }
        return value
    }
    let data = try JSONSerialization.data(
        withJSONObject: [
            "building": strippingMaterials(building),
            "camera": camera,
            "registration": registration,
            "entrance": entrance,
            "facades": strippingMaterials(facades),
            "props": strippingMaterials(props),
            "occlusionExclusions": occlusion,
        ],
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
    return sha256(data)
}

@main
enum ValidateIndustrialL2EastV04PrepixelResetMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let output = URL(
            fileURLWithPath: try argument(
                "--output",
                in: arguments
            )
        ).standardizedFileURL
        let repositoryOutputPrefix =
            root.path
            + "/docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/"
        guard
            output.path.hasPrefix(repositoryOutputPrefix)
                || output.path.hasPrefix("/private/tmp/")
        else {
            throw IndustrialL2EastV04ValidationError.invalid(
                "validator output is outside task evidence or /private/tmp"
            )
        }

        var exactHashes: [[String: Any]] = []
        for (file, expected) in expectedFiles.sorted(
            by: { $0.key < $1.key }
        ) {
            let actual = try sha256(root.appendingPathComponent(file))
            guard actual == expected else {
                throw IndustrialL2EastV04ValidationError.invalid(
                    "v04 artifact hash drift: \(file)"
                )
            }
            exactHashes.append([
                "file": file,
                "sha256": actual,
                "passed": true,
            ])
        }
        var preservation: [[String: Any]] = []
        for (file, expected) in preservedFiles.sorted(
            by: { $0.key < $1.key }
        ) {
            let actual = try sha256(root.appendingPathComponent(file))
            guard actual == expected else {
                throw IndustrialL2EastV04ValidationError.invalid(
                    "preserved v02/v03 artifact hash drift: \(file)"
                )
            }
            preservation.append([
                "file": file,
                "sha256": actual,
                "passed": true,
            ])
        }

        let descriptor = try loadJSON(
            root.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v04/scenes/industrial_l02/variant-0/east/scene.json"
            )
        )
        _ = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: Data(
                contentsOf: root.appendingPathComponent(
                    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v04/scenes/industrial_l02/variant-0/east/scene.json"
                )
            )
        )
        let oldDescriptor = try loadJSON(
            root.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v03/scenes/industrial_l02/variant-0/east/scene.json"
            )
        )
        let materials = try loadJSON(
            root.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v04/materials/industrial-l02-projection-silhouette-reset-v04.json"
            )
        )
        _ = try JSONDecoder().decode(
            MaterialLibraryDescriptor.self,
            from: Data(
                contentsOf: root.appendingPathComponent(
                    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v04/materials/industrial-l02-projection-silhouette-reset-v04.json"
                )
            )
        )
        let segmentation = try loadJSON(
            root.appendingPathComponent(
                "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/diagnosis/MATERIAL-SEGMENTATION.json"
            )
        )
        let ledger = try loadJSON(
            root.appendingPathComponent(
                "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/prepixel/PREDICTED-VALUE-LEDGER.json"
            )
        )
        let alphaContract = try loadJSON(
            root.appendingPathComponent(
                "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/prepixel/V04-ALPHA-COMPOSITOR-CONTRACT.json"
            )
        )
        let committedValidation = try loadJSON(
            root.appendingPathComponent(
                "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/prepixel/PREPIXEL-VALIDATION.json"
            )
        )

        let oldGeometry = try canonicalGeometry(oldDescriptor)
        let newGeometry = try canonicalGeometry(descriptor)
        guard
            oldGeometry
                == "478254a6228ae5bcc4d81ae87ec1f43bfc433b606f95b87a440ca3d41cdf34a3",
            newGeometry == oldGeometry,
            descriptor["sourceRevision"] as? String
                == "projection-silhouette-reset-art-proof-v04",
            descriptor["sceneGeometryID"] as? String
                == "industrial-l02-east-wide-low-campus-geometry-v03",
            descriptor["productionSelected"] as? Bool == false,
            let materialReference =
                descriptor["materialLibrary"] as? [String: Any],
            materialReference["sha256"] as? String
                == "31f500488b7d143e88015bf71b53db4d1a4b19076563dc3d774d61f00c8b83a3",
            let light = descriptor["light"] as? [String: Any],
            light["ambientIntensity"] as? Double == 0.72,
            light["keyIntensity"] as? Int == 1050
        else {
            throw IndustrialL2EastV04ValidationError.invalid(
                "descriptor geometry/material/light contract failed"
            )
        }

        let supportedPatterns = Set([
            "procedural-formed-concrete",
            "procedural-vertical-corrugation",
            "horizontal-section-joints",
            "large-scored-slabs",
            "muted-mullion-grid",
            "muted-warm-glazing",
            "fine-galvanized",
            "painted-steel",
            "rolled-membrane-seams",
            "restrained-oxide",
            "solid-depth-cavity",
            "solid-safety-paint",
        ])
        guard let materialValues =
            materials["materials"] as? [[String: Any]]
        else {
            throw IndustrialL2EastV04ValidationError.invalid(
                "v04 materials are malformed"
            )
        }
        let allMaterialPatternsSupported =
            materialValues.allSatisfy {
                guard let pattern = $0["pattern"] as? String else {
                    return false
                }
                return supportedPatterns.contains(pattern)
            }
        guard
            materialValues.count == 13,
            allMaterialPatternsSupported,
            materials["imageGenMaterialSwatchesUsed"] as? Bool == false,
            materials["productionSelected"] as? Bool == false
        else {
            throw IndustrialL2EastV04ValidationError.invalid(
                "v04 material pattern/value contract failed"
            )
        }

        guard
            let coverage =
                segmentation["coverage"] as? [String: Any],
            let attributedAlphaRatio =
                coverage["attributedAlphaRatio"] as? Double,
            let attributedOpaqueRatio =
                coverage["attributedOpaqueRatio"] as? Double,
            attributedAlphaRatio > 0.99,
            attributedOpaqueRatio > 0.998,
            let patternDispatch =
                segmentation["patternDispatch"] as? [String: Any],
            let unsupported =
                patternDispatch["unsupportedReferencedPatterns"]
                as? [String],
            unsupported.count == 6,
            let chroma =
                segmentation["chromaEdge"] as? [String: Any],
            chroma["nearMagentaOpaqueRawPixels"] as? Int == 8460,
            chroma["nearMagentaAtPartialPreChromaAlpha"] as? Int
                == 8460,
            chroma["nearMagentaAtOpaquePreChromaAlpha"] as? Int == 0,
            chroma["nearMagentaAtZeroPreChromaAlpha"] as? Int == 0,
            chroma["neutralCompositeMagentaFamilyPixels"] as? Int == 0
        else {
            throw IndustrialL2EastV04ValidationError.invalid(
                "retained-pixel diagnosis contract failed"
            )
        }

        guard
            let global = ledger["global"] as? [String: Any],
            global["passed"] as? Bool == true,
            global["predictedP25"] as? Int == 112,
            global["predictedP75MinusP25"] as? Int == 96,
            global["predictedP95"] as? Int == 240,
            let bins =
                global["predictedOccupiedStep32Bins"] as? [Int],
            bins.count == 7,
            let maximumShare =
                global["predictedMaximumBinShare"] as? Double,
            maximumShare < 0.35,
            global["identityBearingMinimumPredictedBin"] as? Int
                == 80,
            alphaContract["productionSelected"] as? Bool == false,
            committedValidation["passed"] as? Bool == true,
            committedValidation["metalProcessesConsumed"] as? Int == 0,
            committedValidation["sceneKitSnapshotsCreated"] as? Int
                == 0,
            committedValidation["newPixelFilesCreated"] as? Int == 0
        else {
            throw IndustrialL2EastV04ValidationError.invalid(
                "prediction/alpha/prepixel validation contract failed"
            )
        }

        let outputTree = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04"
        )
        guard let enumerator = FileManager.default.enumerator(
            at: outputTree,
            includingPropertiesForKeys: nil
        ) else {
            throw IndustrialL2EastV04ValidationError.invalid(
                "could not enumerate v04 evidence"
            )
        }
        var forbiddenPixelFiles: [String] = []
        for case let url as URL in enumerator {
            if ["png", "jpg", "jpeg", "tiff"].contains(
                url.pathExtension.lowercased()
            ) {
                forbiddenPixelFiles.append(url.path)
            }
        }
        guard forbiddenPixelFiles.isEmpty else {
            throw IndustrialL2EastV04ValidationError.invalid(
                "v04 pre-pixel tree contains pixel files"
            )
        }

        let validatorSource = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/ValidateIndustrialL2EastV04PrepixelReset.swift"
        )
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v04-prepixel-validator-replay",
            "passed": true,
            "authorityCommit":
                "af6b35bee6732d8ad9b16e7353083258c48e5607",
            "exactV04Hashes": exactHashes,
            "preservedV02V03Hashes": preservation,
            "geometry": [
                "v03CanonicalSHA256": oldGeometry,
                "v04CanonicalSHA256": newGeometry,
                "unchanged": true,
            ],
            "segmentation": [
                "attributedAlphaRatio": attributedAlphaRatio,
                "attributedOpaqueRatio": attributedOpaqueRatio,
                "unsupportedV03PatternCount": unsupported.count,
                "nearMagentaPartialAlphaPixels": 8460,
                "neutralMagentaFamilyPixels": 0,
            ],
            "prediction": [
                "p25": 112,
                "p75MinusP25": 96,
                "p95": 240,
                "occupiedStep32BinCount": bins.count,
                "maximumBinShare": maximumShare,
                "identityBearingMinimumBin": 80,
            ],
            "pixelFilesCreated": 0,
            "metalProcessesConsumed": 0,
            "sceneKitSnapshotsCreated": 0,
            "productionSelected": false,
            "validatorSourceSHA256": try sha256(validatorSource),
        ]
        try writeJSON(report, to: output)
        print("PLAY-027 Industrial L2 East v04 validator PASS")
        print("geometry \(newGeometry)")
        print(
            "prediction p25=112 iqr=96 p95=240 bins=\(bins.count) maxShare=\(maximumShare)"
        )
        print("Metal=0 snapshots=0 pixels=0 productionSelected=false")
    }
}
