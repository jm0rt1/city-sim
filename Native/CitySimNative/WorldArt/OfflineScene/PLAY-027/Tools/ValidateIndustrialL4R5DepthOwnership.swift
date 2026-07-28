import AppKit
import CryptoKit
import Foundation
import SceneKit

private enum R5ValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l4-r5-depth-ownership --repository-root <path> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

private let descriptorPath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v18-north-prepixel/artifact/scenes/"
    + "industrial_l04/variant-0/n/scene.json"
private let materialPath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v17-north-prepixel/materials/"
    + "industrial-l04-crucible-gantry-v14-north-prepixel.json"
private let r4Path =
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    + "edge-locality-attribution-r4-v01/EDGE-LOCALITY.json"
private let expectedDescriptorSHA =
    "3696b813e6c3e0f46251e689582163bdbdcc5d84a3a9c1125bfbefba37da2630"
private let expectedMaterialSHA =
    "147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202"
private let expectedR4SHA =
    "30504318c3e4949c5320bcf2017ffb2e087cbdb697aaf2c0765436d9e1a14d8f"
private let expectedManifestSHA =
    "611d60db7d39c9c0de73d1042f658c08e18c2d26bf4be9b7af3c6f577593a94f"

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        index + 1 < CommandLine.arguments.count
    else {
        throw R5ValidationError.arguments
    }
    return CommandLine.arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func contractRecord(
    root: URL,
    descriptorURL: URL,
    materialURL: URL,
    descriptor: SceneDescriptor,
    sampling: EffectiveSamplingContract
) throws -> PLAY027SemanticRendererV1Record {
    let run = root.appendingPathComponent(
        PLAY027SemanticRendererV1.r5EvidenceRoot + "/run-a"
    )
    guard
        let result = try PLAY027SemanticRendererV1.validate(
            requestedContractID: PLAY027SemanticRendererV1.r5ContractID,
            repositoryRoot: root,
            sceneURL: descriptorURL,
            sceneSHA256: expectedDescriptorSHA,
            materialsURL: materialURL,
            materialSHA256: expectedMaterialSHA,
            outputURL: run.appendingPathComponent("semantic.png"),
            recordURL: run.appendingPathComponent("provenance.json"),
            descriptor: descriptor,
            sampling: sampling,
            diagnosticSamplingPipelineID: nil,
            diagnosticContractID: nil,
            diagnosticStageContractID: nil,
            diagnosticL3V5TraceContractID: nil,
            diagnosticStageCaptureDirectory: nil,
            diagnosticStageCoordinate: nil,
            diagnosticPrequantizedOutput: nil,
            diagnosticAntialiasing: nil,
            diagnosticSceneShadows: nil,
            diagnosticMaterialLighting: nil
        )
    else {
        throw R5ValidationError.invalid("R5 contract did not resolve")
    }
    return result
}

private func transformedNodeRecord(_ node: SCNNode) -> [String: Any] {
    let transform = node.simdWorldTransform
    let transformBits = (0..<4).flatMap { column in
        [
            String(transform[column].x.bitPattern),
            String(transform[column].y.bitPattern),
            String(transform[column].z.bitPattern),
            String(transform[column].w.bitPattern),
        ]
    }
    let bounds: Any
    if let value = node.geometry?.boundingBox {
        bounds = [
            "minimum": [
                Double(value.min.x),
                Double(value.min.y),
                Double(value.min.z),
            ],
            "maximum": [
                Double(value.max.x),
                Double(value.max.y),
                Double(value.max.z),
            ],
        ]
    } else {
        bounds = NSNull()
    }
    return [
        "nodeName": node.name ?? "",
        "worldTransformBits": transformBits,
        "bounds": bounds,
        "geometryIdentity":
            node.geometry.map { String(ObjectIdentifier($0).hashValue) }
            ?? "none",
    ]
}

private func projectedSupport(
    _ r4: [String: Any]
) throws -> [String: Any] {
    guard
        let analytic = r4["analyticGeometry"] as? [String: Any],
        let components = analytic["components"] as? [String: Any],
        let header = components["portal-header-wall"] as? [String: Any],
        let lintel = components["portal-lintel"] as? [String: Any],
        let headerBounds =
            header["projectedSourceBounds"] as? [String: Any],
        let lintelBounds =
            lintel["projectedSourceBounds"] as? [String: Any],
        let headerMinX = headerBounds["minimumX"] as? NSNumber,
        let headerMinY = headerBounds["minimumY"] as? NSNumber,
        let headerMaxX = headerBounds["maximumX"] as? NSNumber,
        let headerMaxY = headerBounds["maximumY"] as? NSNumber,
        let lintelMinX = lintelBounds["minimumX"] as? NSNumber,
        let lintelMinY = lintelBounds["minimumY"] as? NSNumber,
        let lintelMaxX = lintelBounds["maximumX"] as? NSNumber,
        let lintelMaxY = lintelBounds["maximumY"] as? NSNumber
    else {
        throw R5ValidationError.invalid("R4 projected support missing")
    }
    let minimumX = min(headerMinX.doubleValue, lintelMinX.doubleValue)
    let minimumY = min(headerMinY.doubleValue, lintelMinY.doubleValue)
    let maximumX = max(headerMaxX.doubleValue, lintelMaxX.doubleValue)
    let maximumY = max(headerMaxY.doubleValue, lintelMaxY.doubleValue)
    return [
        "headerWallConservativeBounds": headerBounds,
        "lintelConservativeBounds": lintelBounds,
        "lanczosSupportPixels": 2,
        "integerAdmissionBoundsInclusive": [
            Int(floor(minimumX)) - 2,
            Int(floor(minimumY)) - 2,
            Int(ceil(maximumX)) + 2,
            Int(ceil(maximumY)) + 2,
        ],
        "comparisonAuthority":
            "canonical R3-A decoded RGBA; any R5 change outside this "
            + "admission region fails closed",
    ]
}

@main
private enum ValidateR5DepthOwnership {
    static func main() throws {
        let root = URL(
            fileURLWithPath: try argument("--repository-root")
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try argument("--report")
        ).standardizedFileURL
        guard !FileManager.default.fileExists(atPath: reportURL.path) else {
            throw R5ValidationError.invalid("report path must be absent")
        }
        let descriptorURL = root.appendingPathComponent(descriptorPath)
        let materialURL = root.appendingPathComponent(materialPath)
        let r4URL = root.appendingPathComponent(r4Path)
        let descriptorData = try Data(contentsOf: descriptorURL)
        let materialData = try Data(contentsOf: materialURL)
        let r4Data = try Data(contentsOf: r4URL)
        guard
            digest(descriptorData) == expectedDescriptorSHA,
            digest(materialData) == expectedMaterialSHA,
            digest(r4Data) == expectedR4SHA
        else {
            throw R5ValidationError.invalid("immutable input hash drift")
        }
        let decoder = JSONDecoder()
        let descriptor = try decoder.decode(
            SceneDescriptor.self,
            from: descriptorData
        )
        let materials = try decoder.decode(
            MaterialLibraryDescriptor.self,
            from: materialData
        )
        let sampling = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        let contract = try contractRecord(
            root: root,
            descriptorURL: descriptorURL,
            materialURL: materialURL,
            descriptor: descriptor,
            sampling: sampling
        )
        guard contract.appliesR5PortalJointDepthOwnership else {
            throw R5ValidationError.invalid("R5 depth rule not admitted")
        }
        let scene = try ContractSceneBuilder(
            materials: NativeMaterialLibrary(
                descriptor: materials,
                repositoryRoot: root
            )
        ).buildScene(from: descriptor)
        var geometryNodes: [SCNNode] = []
        scene.rootNode.enumerateChildNodes { node, _ in
            if node.geometry != nil {
                geometryNodes.append(node)
            }
        }
        geometryNodes.sort { ($0.name ?? "") < ($1.name ?? "") }
        guard geometryNodes.count == 51 else {
            throw R5ValidationError.invalid("expected 51 geometry nodes")
        }
        let before = Dictionary(
            uniqueKeysWithValues: geometryNodes.map {
                ($0.name ?? "", transformedNodeRecord($0))
            }
        )
        let actual =
            try PLAY027PortalJointDepthOwnershipR5.applyActualMaterials(
                to: scene
            )
        let afterActual = Dictionary(
            uniqueKeysWithValues: geometryNodes.map {
                ($0.name ?? "", transformedNodeRecord($0))
            }
        )
        guard
            NSDictionary(dictionary: before).isEqual(to: afterActual)
        else {
            throw R5ValidationError.invalid(
                "actual shader application changed geometry facts"
            )
        }
        let semantic = try PLAY027SemanticRendererV1.apply(
            to: scene,
            appliesR5PortalJointDepthOwnership: true
        )
        let afterSemantic = Dictionary(
            uniqueKeysWithValues: geometryNodes.map {
                ($0.name ?? "", transformedNodeRecord($0))
            }
        )
        guard
            semantic.nodeRecords.count == 51,
            semantic.nodeManifestSHA256 == expectedManifestSHA,
            NSDictionary(dictionary: before).isEqual(to: afterSemantic),
            semantic.r5SemanticDepthOwnership != nil
        else {
            throw R5ValidationError.invalid(
                "semantic scope, manifest, or geometry drift"
            )
        }
        guard
            let r4 = try JSONSerialization.jsonObject(with: r4Data)
                as? [String: Any]
        else {
            throw R5ValidationError.invalid("R4 evidence malformed")
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contract": "CONTRACT-019-R5",
            "disposition": "PASS_EXACT_TWO_NODE_SHADER_PREFLIGHT",
            "diagnosticOnly": true,
            "sourceAuthority": false,
            "productionSelected": false,
            "bindings": [
                "descriptorFile": descriptorPath,
                "descriptorSHA256": expectedDescriptorSHA,
                "materialLibraryFile": materialPath,
                "materialLibrarySHA256": expectedMaterialSHA,
                "r4EvidenceFile": r4Path,
                "r4EvidenceSHA256": expectedR4SHA,
                "nodeManifestSHA256": semantic.nodeManifestSHA256,
            ],
            "depthOwnership": [
                "biasWorldDepth": 0.0625,
                "targetNodeNames":
                    PLAY027PortalJointDepthOwnershipR5.targetNodeNames,
                "shaderSHA256":
                    PLAY027PortalJointDepthOwnershipR5.shaderSHA256,
                "actualMaterialApplication": actual.record,
                "semanticMaterialApplication":
                    semantic.r5SemanticDepthOwnership
                    ?? (NSNull() as Any),
            ],
            "preservation": [
                "descriptorBytesChanged": false,
                "materialLibraryBytesChanged": false,
                "geometryNodeCount": geometryNodes.count,
                "worldTransformsChanged": false,
                "boundsChanged": false,
                "hitGeometryChanged": false,
                "screenPositionContractChanged": false,
                "cameraChanged": false,
                "registrationChanged": false,
                "samplingChanged": false,
            ],
            "changedPixelSupport": try projectedSupport(r4),
            "processCounts": [
                "sceneConstructionOnly": 1,
                "sceneKitMetalSnapshot": 0,
                "authoritativeRaw": 0,
                "normalizer": 0,
                "siblings": 0,
                "modeling": 0,
            ],
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: reportURL, options: .atomic)
        print("PASS exact two-node shader preflight")
    }
}
