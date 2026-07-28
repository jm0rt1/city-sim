import AppKit
import CryptoKit
import Foundation
import SceneKit

enum PLAY027SemanticRendererV1Error: Error, CustomStringConvertible {
    case rejected(String)

    var description: String {
        switch self {
        case let .rejected(message):
            return "semantic-visibility-renderer-v1 rejected: \(message)"
        }
    }
}

struct PLAY027SemanticRendererV1Record {
    let value: [String: Any]
    let appliesR5PortalJointDepthOwnership: Bool
}

struct PLAY027SemanticRendererV1Application {
    let nodeRecords: [[String: Any]]
    let nodeManifestSHA256: String
    let r5SemanticDepthOwnership: [String: Any]?
}

enum PLAY027SemanticRendererV1 {
    static let contractID =
        "play027-industrial-l04-v17-semantic-visibility-renderer-v1"
    static let r3ContractID =
        "play027-industrial-l04-v18-semantic-visibility-renderer-r3-v1"
    static let r5ContractID =
        "play027-industrial-l04-v18-semantic-visibility-renderer-r5-v1"
    static let descriptorSHA256 =
        "6cb190ea388746c620945ff401a03817df0ff1f92797a18fff8e86b00b0cd94a"
    static let r3DescriptorSHA256 =
        "3696b813e6c3e0f46251e689582163bdbdcc5d84a3a9c1125bfbefba37da2630"
    static let materialSHA256 =
        "147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202"
    static let evidenceRoot =
        "docs/production/evidence/PLAY-027/industrial-l04/l04/"
        + "semantic-visibility-renderer-v1/diagnostics"
    static let r3EvidenceRoot =
        "docs/production/evidence/PLAY-027/industrial-l04/l04/"
        + "duplicate-foundation-repair-r3-v01/diagnostics"
    static let r5EvidenceRoot =
        "docs/production/evidence/PLAY-027/industrial-l04/l04/"
        + "portal-joint-depth-ownership-r5-v01/diagnostics"

    static let semanticColors: [String: [Int]] = [
        "portal-jamb-south": [16, 16, 240, 255],
        "portal-jamb-north": [240, 208, 16, 255],
        "portal-header": [240, 16, 16, 255],
        "portal-inset-void": [16, 240, 48, 255],
        "hall": [144, 80, 48, 255],
        "gantry": [48, 80, 112, 255],
        "crucible-occluder": [208, 112, 16, 255],
        "other": [80, 80, 80, 255],
    ]

    static func validate(
        requestedContractID: String?,
        repositoryRoot: URL,
        sceneURL: URL,
        sceneSHA256: String,
        materialsURL: URL,
        materialSHA256: String,
        outputURL: URL,
        recordURL: URL,
        descriptor: SceneDescriptor,
        sampling: EffectiveSamplingContract,
        diagnosticSamplingPipelineID: String?,
        diagnosticContractID: String?,
        diagnosticStageContractID: String?,
        diagnosticL3V5TraceContractID: String?,
        diagnosticStageCaptureDirectory: URL?,
        diagnosticStageCoordinate: [Int]?,
        diagnosticPrequantizedOutput: URL?,
        diagnosticAntialiasing: String?,
        diagnosticSceneShadows: String?,
        diagnosticMaterialLighting: String?
    ) throws -> PLAY027SemanticRendererV1Record? {
        guard let requestedContractID else { return nil }
        guard
            [contractID, r3ContractID, r5ContractID].contains(
                requestedContractID
            )
        else {
            throw PLAY027SemanticRendererV1Error.rejected("contract ID")
        }
        let isR3OrR5 =
            requestedContractID == r3ContractID
            || requestedContractID == r5ContractID
        let isR5 = requestedContractID == r5ContractID
        let expectedDescriptorSHA = isR3OrR5
            ? r3DescriptorSHA256 : descriptorSHA256
        let expectedRevision = isR3OrR5
            ? "source-v18-prepixel" : "source-v17-prepixel"
        let expectedGeometryID = isR3OrR5
            ? "industrial-l04-crucible-gantry-v18-north-single-foundation"
            : "industrial-l04-crucible-gantry-v17-north-monumental-portal"
        let expectedEvidenceRoot =
            isR5 ? r5EvidenceRoot
            : (isR3OrR5 ? r3EvidenceRoot : evidenceRoot)
        guard
            sceneSHA256 == expectedDescriptorSHA,
            materialSHA256 == self.materialSHA256,
            descriptor.logicalBuildingID == "industrial_l04",
            descriptor.variantID == "variant-0",
            descriptor.sourceRevision == expectedRevision,
            descriptor.viewDirection == "n",
            descriptor.sceneGeometryID == expectedGeometryID,
            descriptor.productionSelected == false,
            descriptor.derivation.siblingSource == nil,
            descriptor.derivation.mirror == false,
            descriptor.derivation.rotationDegrees == 0,
            descriptor.derivation.transform == "none"
        else {
            throw PLAY027SemanticRendererV1Error.rejected(
                "descriptor identity or derivation"
            )
        }
        guard
            sampling.contractID
                == DescriptorSamplingResolver.schema2ContractV3ID,
            sampling.purpose == "source-authority",
            sampling.linearOversamplingFactor == 4,
            sampling.sceneKitAntialiasing == "none",
            sampling.sceneKitShadows == "disabled",
            sampling.sceneKitLightingMode == "authored-constant-v1",
            sampling.downsampleFilter == "CILanczosScaleTransform",
            sampling.downsampleScale == 0.25,
            sampling.downsampleAspectRatio == 1,
            sampling.ciUseSoftwareRenderer,
            !sampling.ciCacheIntermediates
        else {
            throw PLAY027SemanticRendererV1Error.rejected(
                "sampling contract"
            )
        }
        guard
            diagnosticSamplingPipelineID == nil,
            diagnosticContractID == nil,
            diagnosticStageContractID == nil,
            diagnosticL3V5TraceContractID == nil,
            diagnosticStageCaptureDirectory == nil,
            diagnosticStageCoordinate == nil,
            diagnosticPrequantizedOutput == nil,
            diagnosticAntialiasing == nil,
            diagnosticSceneShadows == nil,
            diagnosticMaterialLighting == nil
        else {
            throw PLAY027SemanticRendererV1Error.rejected(
                "competing diagnostic option"
            )
        }

        let rootPrefix = repositoryRoot.standardizedFileURL.path + "/"
        let expectedPrefix =
            rootPrefix + expectedEvidenceRoot + "/"
        let outputPath = outputURL.standardizedFileURL.path
        let recordPath = recordURL.standardizedFileURL.path
        let outputParent = outputURL.deletingLastPathComponent()
            .standardizedFileURL.path
        let recordParent = recordURL.deletingLastPathComponent()
            .standardizedFileURL.path
        guard
            outputPath.hasPrefix(expectedPrefix),
            recordPath.hasPrefix(expectedPrefix),
            outputParent == recordParent,
            ["run-a", "run-b"].contains(
                outputURL.deletingLastPathComponent().lastPathComponent
            ),
            outputURL.lastPathComponent == "semantic.png",
            recordURL.lastPathComponent == "provenance.json",
            !FileManager.default.fileExists(atPath: outputParent),
            !FileManager.default.fileExists(atPath: outputPath),
            !FileManager.default.fileExists(atPath: recordPath)
        else {
            throw PLAY027SemanticRendererV1Error.rejected(
                "new diagnostics output path"
            )
        }
        return PLAY027SemanticRendererV1Record(
            value: [
                "contractID": requestedContractID,
                "diagnosticOnly": true,
                "sourceAuthority": false,
                "productionSelected": false,
                "descriptorFile": rendererRelativePath(
                    sceneURL,
                    repositoryRoot: repositoryRoot
                ),
                "descriptorSHA256": sceneSHA256,
                "materialLibraryFile": rendererRelativePath(
                    materialsURL,
                    repositoryRoot: repositoryRoot
                ),
                "materialLibrarySHA256": materialSHA256,
                "sceneGeometryID": descriptor.sceneGeometryID,
                "semanticColorsRGBA8": semanticColors,
                "sceneConstruction": "ContractSceneBuilder",
                "renderer": "NativeSourceRenderer",
                "snapshotScale": 4,
                "downsample": "governed-software-CILanczos-0.25",
                "registration": descriptor.camera.postProjectionOffsetPixels,
                "rawProcessCount": 0,
                "normalizerProcessCount": 0,
                "r5PortalJointDepthOwnership": isR5,
            ],
            appliesR5PortalJointDepthOwnership: isR5
        )
    }

    static func apply(
        to scene: SCNScene,
        appliesR5PortalJointDepthOwnership: Bool
    ) throws -> PLAY027SemanticRendererV1Application {
        var records: [[String: Any]] = []
        var r5Records: [[String: Any]] = []
        var applicationError: Error?
        scene.rootNode.enumerateChildNodes { node, _ in
            guard applicationError == nil else { return }
            guard
                let name = node.name,
                let geometry = node.geometry
            else {
                return
            }
            let group = semanticGroup(nodeName: name)
            let rgba = semanticColors[group]!
            let material = SCNMaterial()
            material.name = "semantic-v1-\(group)"
            material.lightingModel = .constant
            material.diffuse.contents = NSColor(
                calibratedRed: CGFloat(rgba[0]) / 255,
                green: CGFloat(rgba[1]) / 255,
                blue: CGFloat(rgba[2]) / 255,
                alpha: 1
            )
            material.emission.contents = NSColor.black
            material.isDoubleSided = false
            if appliesR5PortalJointDepthOwnership {
                do {
                    if let record =
                        try PLAY027PortalJointDepthOwnershipR5
                        .applySemanticMaterial(
                            material,
                            to: node,
                            in: scene
                        )
                    {
                        r5Records.append(record)
                    }
                } catch {
                    applicationError = error
                    return
                }
            }
            geometry.materials = Array(
                repeating: material,
                count: max(1, geometry.materials.count)
            )
            records.append(
                [
                    "nodeName": name,
                    "semanticGroup": group,
                    "semanticRGBA8": rgba,
                    "nodeSHA256": nodeSHA256(node, group: group),
                    "geometryElementCount": geometry.elements.count,
                    "geometrySourceCount": geometry.sources.count,
                    "materialSlotCount": geometry.materials.count,
                ]
            )
        }
        if let applicationError {
            throw applicationError
        }
        records.sort {
            ($0["nodeName"] as? String ?? "")
                < ($1["nodeName"] as? String ?? "")
        }
        let data = try JSONSerialization.data(
            withJSONObject: records,
            options: [.sortedKeys]
        )
        guard
            records.contains(where: {
                $0["semanticGroup"] as? String == "portal-jamb-south"
            }),
            records.contains(where: {
                $0["semanticGroup"] as? String == "portal-jamb-north"
            }),
            records.contains(where: {
                $0["semanticGroup"] as? String == "portal-header"
            }),
            records.contains(where: {
                $0["semanticGroup"] as? String == "portal-inset-void"
            }),
            records.contains(where: {
                $0["semanticGroup"] as? String == "hall"
            }),
            records.contains(where: {
                $0["semanticGroup"] as? String == "gantry"
            }),
            records.contains(where: {
                $0["semanticGroup"] as? String == "crucible-occluder"
            })
        else {
            throw PLAY027SemanticRendererV1Error.rejected(
                "required named node group"
            )
        }
        let r5Record = try appliesR5PortalJointDepthOwnership
            ? PLAY027PortalJointDepthOwnershipR5.semanticRecord(
                r5Records,
                in: scene
            )
            : nil
        return PLAY027SemanticRendererV1Application(
            nodeRecords: records,
            nodeManifestSHA256: digest(data),
            r5SemanticDepthOwnership: r5Record
        )
    }

    private static func semanticGroup(nodeName: String) -> String {
        switch nodeName {
        case "v17-monumental-portal-jamb-south":
            return "portal-jamb-south"
        case "v17-monumental-portal-jamb-north":
            return "portal-jamb-north"
        case "v17-monumental-portal-lintel",
            "v17-monumental-portal-header-wall":
            return "portal-header"
        case "v17-monumental-portal-inset-back-plane":
            return "portal-inset-void"
        default:
            if
                nodeName.contains("gantry")
                    || nodeName.contains("crane")
                    || nodeName.contains("lift-rail")
            {
                return "gantry"
            }
            if nodeName.contains("crucible") {
                return "crucible-occluder"
            }
            if
                nodeName == "foundation"
                    || nodeName.contains("hall")
                    || nodeName.contains("side-return")
                    || nodeName.contains("portal-wall")
            {
                return "hall"
            }
            return "other"
        }
    }

    private static func nodeSHA256(
        _ node: SCNNode,
        group: String
    ) -> String {
        var values = [node.name ?? "", group]
        let transform = node.simdWorldTransform
        for column in 0..<4 {
            values.append(String(transform[column].x.bitPattern))
            values.append(String(transform[column].y.bitPattern))
            values.append(String(transform[column].z.bitPattern))
            values.append(String(transform[column].w.bitPattern))
        }
        if let bounds = node.geometry?.boundingBox {
            for value in [
                bounds.min.x,
                bounds.min.y,
                bounds.min.z,
                bounds.max.x,
                bounds.max.y,
                bounds.max.z,
            ] {
                values.append(String(value.bitPattern))
            }
        }
        for element in node.geometry?.elements ?? [] {
            values.append(String(element.primitiveCount))
            values.append(String(element.bytesPerIndex))
            values.append(String(element.primitiveType.rawValue))
        }
        return digest(Data(values.joined(separator: "|").utf8))
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
