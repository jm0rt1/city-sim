import CryptoKit
import Foundation
import SceneKit

enum PLAY027PortalJointDepthOwnershipR5Error:
    Error, CustomStringConvertible
{
    case rejected(String)

    var description: String {
        switch self {
        case let .rejected(message):
            return "portal-joint-depth-ownership-r5 rejected: \(message)"
        }
    }
}

struct PLAY027PortalJointDepthOwnershipR5Application {
    let record: [String: Any]
}

enum PLAY027PortalJointDepthOwnershipR5 {
    static let worldDepthBias = 0.0625
    static let targetNodeNames = [
        "v17-monumental-portal-header-wall",
        "v17-monumental-portal-lintel",
    ]
    static let uniformName = "play027R5CameraDepthBiasLocal"
    static let shader = """
        #pragma arguments
        float3 play027R5CameraDepthBiasLocal;
        #pragma body
        _geometry.position.xyz += play027R5CameraDepthBiasLocal;
        """

    static var shaderSHA256: String {
        digest(Data(shader.utf8))
    }

    static func applyActualMaterials(
        to scene: SCNScene
    ) throws -> PLAY027PortalJointDepthOwnershipR5Application {
        let worldBias = try cameraWorldBias(in: scene)
        var records: [[String: Any]] = []
        for name in targetNodeNames {
            let node = try exactNode(named: name, in: scene)
            guard
                let geometry = node.geometry,
                !geometry.materials.isEmpty
            else {
                throw PLAY027PortalJointDepthOwnershipR5Error.rejected(
                    "target geometry or actual materials missing: \(name)"
                )
            }
            let beforeTransform = transformBits(node.simdWorldTransform)
            let beforeBounds = boundsRecord(node)
            let localBias = node.convertVector(worldBias, from: nil)
            let copiedMaterials = try geometry.materials.map { material in
                guard let copy = material.copy() as? SCNMaterial else {
                    throw PLAY027PortalJointDepthOwnershipR5Error.rejected(
                        "actual material copy failed: \(name)"
                    )
                }
                try apply(
                    to: copy,
                    localBias: localBias,
                    nodeName: name,
                    materialKind: "actual"
                )
                return copy
            }
            geometry.materials = copiedMaterials
            guard
                transformBits(node.simdWorldTransform) == beforeTransform,
                NSDictionary(dictionary: boundsRecord(node)).isEqual(
                    to: beforeBounds
                )
            else {
                throw PLAY027PortalJointDepthOwnershipR5Error.rejected(
                    "target transform or bounds changed: \(name)"
                )
            }
            records.append(
                applicationRecord(
                    node: node,
                    localBias: localBias,
                    materialKind: "actual"
                )
            )
        }
        try rejectUnexpectedApplications(in: scene)
        return PLAY027PortalJointDepthOwnershipR5Application(
            record: rootRecord(
                worldBias: worldBias,
                materialKind: "actual",
                nodes: records
            )
        )
    }

    static func applySemanticMaterial(
        _ material: SCNMaterial,
        to node: SCNNode,
        in scene: SCNScene
    ) throws -> [String: Any]? {
        guard let name = node.name else { return nil }
        guard targetNodeNames.contains(name) else {
            guard material.shaderModifiers?[.geometry] == nil else {
                throw PLAY027PortalJointDepthOwnershipR5Error.rejected(
                    "non-target semantic material already has geometry shader"
                )
            }
            return nil
        }
        let worldBias = try cameraWorldBias(in: scene)
        let localBias = node.convertVector(worldBias, from: nil)
        try apply(
            to: material,
            localBias: localBias,
            nodeName: name,
            materialKind: "semantic"
        )
        return applicationRecord(
            node: node,
            localBias: localBias,
            materialKind: "semantic"
        )
    }

    static func semanticRecord(
        _ nodeRecords: [[String: Any]],
        in scene: SCNScene
    ) throws -> [String: Any] {
        guard
            nodeRecords.count == targetNodeNames.count,
            Set(nodeRecords.compactMap { $0["nodeName"] as? String })
                == Set(targetNodeNames)
        else {
            throw PLAY027PortalJointDepthOwnershipR5Error.rejected(
                "semantic application scope"
            )
        }
        try rejectUnexpectedApplications(in: scene)
        return rootRecord(
            worldBias: try cameraWorldBias(in: scene),
            materialKind: "semantic",
            nodes: nodeRecords.sorted {
                ($0["nodeName"] as? String ?? "")
                    < ($1["nodeName"] as? String ?? "")
            }
        )
    }

    private static func apply(
        to material: SCNMaterial,
        localBias: SCNVector3,
        nodeName: String,
        materialKind: String
    ) throws {
        guard material.shaderModifiers?[.geometry] == nil else {
            throw PLAY027PortalJointDepthOwnershipR5Error.rejected(
                "\(materialKind) target already has geometry shader: \(nodeName)"
            )
        }
        material.shaderModifiers = [.geometry: shader]
        material.setValue(
            NSValue(scnVector3: localBias),
            forKey: uniformName
        )
        guard material.shaderModifiers?[.geometry] == shader else {
            throw PLAY027PortalJointDepthOwnershipR5Error.rejected(
                "\(materialKind) shader application failed: \(nodeName)"
            )
        }
    }

    private static func exactNode(
        named name: String,
        in scene: SCNScene
    ) throws -> SCNNode {
        var matches: [SCNNode] = []
        scene.rootNode.enumerateChildNodes { node, _ in
            if node.name == name {
                matches.append(node)
            }
        }
        guard matches.count == 1, let node = matches.first else {
            throw PLAY027PortalJointDepthOwnershipR5Error.rejected(
                "expected one target node: \(name)"
            )
        }
        return node
    }

    private static func cameraWorldBias(
        in scene: SCNScene
    ) throws -> SCNVector3 {
        guard
            let camera = scene.rootNode.childNode(
                withName: "contract-camera",
                recursively: false
            )
        else {
            throw PLAY027PortalJointDepthOwnershipR5Error.rejected(
                "contract camera missing"
            )
        }
        let column = camera.simdWorldTransform.columns.2
        let length = sqrt(
            Double(column.x * column.x)
                + Double(column.y * column.y)
                + Double(column.z * column.z)
        )
        guard length > 0 else {
            throw PLAY027PortalJointDepthOwnershipR5Error.rejected(
                "camera depth axis invalid"
            )
        }
        let scale = Float(worldDepthBias / length)
        return SCNVector3(
            column.x * scale,
            column.y * scale,
            column.z * scale
        )
    }

    private static func rejectUnexpectedApplications(
        in scene: SCNScene
    ) throws {
        var unexpected: [String] = []
        scene.rootNode.enumerateChildNodes { node, _ in
            guard
                let geometry = node.geometry,
                !targetNodeNames.contains(node.name ?? "")
            else {
                return
            }
            if geometry.materials.contains(where: {
                $0.shaderModifiers?[.geometry] == shader
            }) {
                unexpected.append(node.name ?? "<unnamed>")
            }
        }
        guard unexpected.isEmpty else {
            throw PLAY027PortalJointDepthOwnershipR5Error.rejected(
                "unexpected shader application: \(unexpected.sorted())"
            )
        }
    }

    private static func applicationRecord(
        node: SCNNode,
        localBias: SCNVector3,
        materialKind: String
    ) -> [String: Any] {
        [
            "nodeName": node.name ?? "",
            "materialKind": materialKind,
            "materialSlotCount": node.geometry?.materials.count ?? 0,
            "localBiasVector": [
                Double(localBias.x),
                Double(localBias.y),
                Double(localBias.z),
            ],
            "localBiasMagnitude": sqrt(
                Double(localBias.x * localBias.x)
                    + Double(localBias.y * localBias.y)
                    + Double(localBias.z * localBias.z)
            ),
            "worldTransformBits": transformBits(node.simdWorldTransform),
            "bounds": boundsRecord(node),
            "shaderSHA256": shaderSHA256,
        ]
    }

    private static func rootRecord(
        worldBias: SCNVector3,
        materialKind: String,
        nodes: [[String: Any]]
    ) -> [String: Any] {
        [
            "contractID":
                "play027-industrial-l04-v18-portal-joint-depth-r5-v1",
            "materialKind": materialKind,
            "worldDepthBias": worldDepthBias,
            "worldBiasVector": [
                Double(worldBias.x),
                Double(worldBias.y),
                Double(worldBias.z),
            ],
            "shaderEntryPoint": "geometry",
            "shaderSHA256": shaderSHA256,
            "uniformName": uniformName,
            "targetNodeNames": targetNodeNames,
            "nodes": nodes,
            "descriptorMutationCount": 0,
            "worldTransformMutationCount": 0,
            "boundsMutationCount": 0,
            "hitGeometryMutationCount": 0,
        ]
    }

    private static func transformBits(
        _ transform: simd_float4x4
    ) -> [String] {
        (0..<4).flatMap { column in
            [
                String(transform[column].x.bitPattern),
                String(transform[column].y.bitPattern),
                String(transform[column].z.bitPattern),
                String(transform[column].w.bitPattern),
            ]
        }
    }

    private static func boundsRecord(_ node: SCNNode) -> [String: Any] {
        guard let bounds = node.geometry?.boundingBox else {
            return ["available": false]
        }
        return [
            "available": true,
            "minimum": [
                Double(bounds.min.x),
                Double(bounds.min.y),
                Double(bounds.min.z),
            ],
            "maximum": [
                Double(bounds.max.x),
                Double(bounds.max.y),
                Double(bounds.max.z),
            ],
        ]
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
