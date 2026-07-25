import CryptoKit
import Foundation

enum IndustrialL2V03FreezeError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: freeze-industrial-l2-east-projection-silhouette-v03 --repository-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private let v03ApprovedBaseCommit =
    "a0c04c0b60a66451d743985bbbe901554431eaa2"
private let v03FrozenV02SceneSHA256 =
    "01ee10ef87c7a23d8fab151091f7237fc0a12563694cea3080f63a25d4e90775"
private let v03FrozenMaterialSHA256 =
    "94069509093c122d4cb2383bd648757561f6561f78b8345c6222b5354f3f18f6"

private func v03FreezeArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2V03FreezeError.arguments
    }
    return arguments[index + 1]
}

private func v03FreezeSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func v03FreezeSHA256(_ url: URL) throws -> String {
    v03FreezeSHA256(try Data(contentsOf: url))
}

@main
enum FreezeIndustrialL2EastProjectionSilhouetteV03Main {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try v03FreezeArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let sourceURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/materials/industrial-l02-projection-silhouette-reset-v02.json"
        )
        let outputURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v03/scenes/industrial_l02/variant-0/east/scene.json"
        )
        guard
            try v03FreezeSHA256(sourceURL)
                == v03FrozenV02SceneSHA256,
            try v03FreezeSHA256(materialURL)
                == v03FrozenMaterialSHA256,
            !FileManager.default.fileExists(atPath: outputURL.path)
        else {
            throw IndustrialL2V03FreezeError.invalid(
                "frozen v02 input drift or v03 output already exists"
            )
        }
        guard
            var scene = try JSONSerialization.jsonObject(
                with: Data(contentsOf: sourceURL)
            ) as? [String: Any],
            var building = scene["building"] as? [String: Any],
            var massBlocks = building["massBlocks"]
                as? [[String: Any]],
            var sampling = scene["sampling"] as? [String: Any],
            let clerestoryIndex = massBlocks.firstIndex(where: {
                $0["id"] as? String == "v02-hall-clerestory"
            }),
            let processMonitorIndex = massBlocks.firstIndex(where: {
                $0["id"] as? String == "v02-process-monitor"
            })
        else {
            throw IndustrialL2V03FreezeError.invalid(
                "frozen v02 descriptor shape drift"
            )
        }

        var clerestory = massBlocks[clerestoryIndex]
        guard
            clerestory["dimensions"] as? [Double] == [18, 5, 6],
            clerestory["positionWorld"] as? [Double]
                == [-6, 31.4, -6],
            clerestory["materialID"] as? String
                == "v02-industrial-glazing"
        else {
            throw IndustrialL2V03FreezeError.invalid(
                "frozen v02 clerestory boundary drift"
            )
        }
        clerestory["id"] = "v03-hall-clerestory-envelope"
        clerestory["dimensions"] = [18.0, 6.8, 6.0]
        clerestory["positionWorld"] = [-6.0, 32.25, -6.0]
        clerestory["presentationRole"] =
            "visible structural hall clerestory reaching the governed vertical envelope"
        massBlocks[clerestoryIndex] = clerestory

        var processMonitor = massBlocks[processMonitorIndex]
        guard
            processMonitor["dimensions"] as? [Double] == [11, 6, 8],
            processMonitor["positionWorld"] as? [Double]
                == [-17, 23.7, 23]
        else {
            throw IndustrialL2V03FreezeError.invalid(
                "frozen v02 process-monitor boundary drift"
            )
        }
        processMonitor["dimensions"] = [11.0, 5.3, 8.0]
        processMonitor["positionWorld"] = [-17.0, 23.35, 23.0]
        processMonitor["presentationRole"] =
            "secondary process monitor capped at twenty-six world units"
        massBlocks[processMonitorIndex] = processMonitor

        building["massBlocks"] = massBlocks
        building["massingProfile"] =
            "industrial-l02-east-wide-low-campus-v03-bounds-repair"
        sampling["sourceRevisionBinding"] =
            "projection-silhouette-reset-art-proof-v03"
        scene["building"] = building
        scene["sampling"] = sampling
        scene["sourceRevision"] =
            "projection-silhouette-reset-art-proof-v03"
        scene["sceneGeometryID"] =
            "industrial-l02-east-wide-low-campus-geometry-v03"
        scene["productionSelected"] = false
        scene["preRenderRepairAuthority"] = [
            "approvedBaseCommit": v03ApprovedBaseCommit,
            "purpose":
                "replace the 33.9000015 maximum-Y stop with a visible hall clerestory envelope at the required 35.65 world-unit height",
            "pixelsAuthorized": false,
            "rendererCapabilityPreflightAuthorized": false,
            "sceneKitSnapshotAuthorized": false,
        ]

        var output = try JSONSerialization.data(
            withJSONObject: scene,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        output.append(0x0a)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try output.write(to: outputURL, options: .atomic)
        print("frozen \(outputURL.path)")
        print("sha256 \(v03FreezeSHA256(output))")
        print("productionSelected=false pixels=0")
    }
}
