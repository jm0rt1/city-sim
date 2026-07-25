import AppKit
import CryptoKit
import Foundation
import SceneKit

enum IndustrialL2BoundsAuditError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: audit-industrial-l2-pre-render-bounds --repository-root <path> --scene <path> --materials <path> --report <path>"
        case let .invalid(message):
            return message
        }
    }
}

private let boundsAuditFamilyAnchorFile =
    "Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/industrial_l01/source-v01.png"
private let boundsAuditFamilyAnchorSHA256 =
    "22dbf75f35d66f86b108c8e5ab9d7b3f753df74489d0b9e9877fc81ba86a2515"
private let boundsAuditTolerance = 0.000_01

private struct BoundsAuditExtent {
    var minX = Double.greatestFiniteMagnitude
    var minY = Double.greatestFiniteMagnitude
    var minZ = Double.greatestFiniteMagnitude
    var maxX = -Double.greatestFiniteMagnitude
    var maxY = -Double.greatestFiniteMagnitude
    var maxZ = -Double.greatestFiniteMagnitude

    mutating func include(_ point: SCNVector3) {
        minX = min(minX, Double(point.x))
        minY = min(minY, Double(point.y))
        minZ = min(minZ, Double(point.z))
        maxX = max(maxX, Double(point.x))
        maxY = max(maxY, Double(point.y))
        maxZ = max(maxZ, Double(point.z))
    }

    mutating func include(_ other: BoundsAuditExtent) {
        minX = min(minX, other.minX)
        minY = min(minY, other.minY)
        minZ = min(minZ, other.minZ)
        maxX = max(maxX, other.maxX)
        maxY = max(maxY, other.maxY)
        maxZ = max(maxZ, other.maxZ)
    }

    var record: [String: Any] {
        [
            "x": [minX, maxX],
            "y": [minY, maxY],
            "z": [minZ, maxZ],
        ]
    }
}

private struct BoundsAuditNode {
    let name: String
    let extent: BoundsAuditExtent
    let materialIDs: [String]
    let primitiveCount: Int

    var record: [String: Any] {
        [
            "name": name,
            "boundsWorld": extent.record,
            "materialIDs": materialIDs,
            "primitiveCount": primitiveCount,
        ]
    }
}

private func boundsAuditArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2BoundsAuditError.arguments
    }
    return arguments[index + 1]
}

private func boundsAuditSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func boundsAuditSHA256(_ url: URL) throws -> String {
    boundsAuditSHA256(try Data(contentsOf: url))
}

private func boundsAuditRepositoryPath(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path + "/"
    guard url.path.hasPrefix(prefix) else {
        return url.path
    }
    return String(url.path.dropFirst(prefix.count))
}

private func boundsAuditDecodeMaterials(
    data: Data,
    descriptor: SceneDescriptor,
    repositoryRoot: URL
) throws -> MaterialLibraryDescriptor {
    guard
        var object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    else {
        throw IndustrialL2BoundsAuditError.invalid(
            "material library must be a JSON object"
        )
    }
    if object["styleAnchorFile"] == nil {
        object["styleAnchorFile"] = descriptor.styleAnchor.file
        object["styleAnchorSHA256"] = descriptor.styleAnchor.sha256
        object["familyAnchorFile"] = boundsAuditFamilyAnchorFile
        object["familyAnchorSHA256"] = boundsAuditFamilyAnchorSHA256
    }
    guard
        object["styleAnchorFile"] as? String
            == descriptor.styleAnchor.file,
        object["styleAnchorSHA256"] as? String
            == descriptor.styleAnchor.sha256,
        object["familyAnchorFile"] as? String
            == boundsAuditFamilyAnchorFile,
        object["familyAnchorSHA256"] as? String
            == boundsAuditFamilyAnchorSHA256,
        try boundsAuditSHA256(
            repositoryRoot.appendingPathComponent(
                descriptor.styleAnchor.file
            )
        ) == descriptor.styleAnchor.sha256,
        try boundsAuditSHA256(
            repositoryRoot.appendingPathComponent(
                boundsAuditFamilyAnchorFile
            )
        ) == boundsAuditFamilyAnchorSHA256
    else {
        throw IndustrialL2BoundsAuditError.invalid(
            "material decoder anchor compatibility drift"
        )
    }
    return try JSONDecoder().decode(
        MaterialLibraryDescriptor.self,
        from: JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    )
}

private func boundsAuditNodeExtent(
    _ node: SCNNode,
    root: SCNNode
) -> BoundsAuditExtent? {
    guard node.geometry != nil else {
        return nil
    }
    let bounds = node.boundingBox
    let minimum = bounds.min
    let maximum = bounds.max
    guard
        maximum.x > minimum.x,
        maximum.y > minimum.y,
        maximum.z > minimum.z
    else {
        return nil
    }
    var extent = BoundsAuditExtent()
    for x in [minimum.x, maximum.x] {
        for y in [minimum.y, maximum.y] {
            for z in [minimum.z, maximum.z] {
                extent.include(
                    node.convertPosition(
                        SCNVector3(x, y, z),
                        to: root
                    )
                )
            }
        }
    }
    return extent
}

private func boundsAuditContributors(
    _ nodes: [BoundsAuditNode],
    union: BoundsAuditExtent
) -> [String: Any] {
    func names(
        _ value: (BoundsAuditExtent) -> Double,
        target: Double
    ) -> [String] {
        nodes.filter {
            abs(value($0.extent) - target) <= boundsAuditTolerance
        }.map(\.name).sorted()
    }
    return [
        "minX": names({ $0.minX }, target: union.minX),
        "maxX": names({ $0.maxX }, target: union.maxX),
        "minY": names({ $0.minY }, target: union.minY),
        "maxY": names({ $0.maxY }, target: union.maxY),
        "minZ": names({ $0.minZ }, target: union.minZ),
        "maxZ": names({ $0.maxZ }, target: union.maxZ),
    ]
}

private func boundsAuditRootExtent(_ root: SCNNode) throws
    -> BoundsAuditExtent
{
    let bounds = root.boundingBox
    let minimum = bounds.min
    let maximum = bounds.max
    guard
        maximum.x > minimum.x,
        maximum.y > minimum.y,
        maximum.z > minimum.z
    else {
        throw IndustrialL2BoundsAuditError.invalid(
            "SceneKit root bounds unavailable"
        )
    }
    var extent = BoundsAuditExtent()
    extent.include(minimum)
    extent.include(maximum)
    return extent
}

@main
enum AuditIndustrialL2PreRenderBoundsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try boundsAuditArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let sceneURL = URL(
            fileURLWithPath: try boundsAuditArgument(
                "--scene",
                in: arguments
            )
        ).standardizedFileURL
        let materialsURL = URL(
            fileURLWithPath: try boundsAuditArgument(
                "--materials",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try boundsAuditArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        let allowedReportPrefix = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/"
        ).path
        guard
            sceneURL.path.hasPrefix(repositoryRoot.path + "/"),
            materialsURL.path.hasPrefix(repositoryRoot.path + "/"),
            reportURL.path.hasPrefix(allowedReportPrefix),
            reportURL.path.contains("/prepixel/"),
            reportURL.path.hasSuffix(".json")
        else {
            throw IndustrialL2BoundsAuditError.invalid(
                "task-owned input/output boundary failed"
            )
        }

        let decoder = JSONDecoder()
        let descriptor = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: sceneURL)
        )
        let materialsData = try Data(contentsOf: materialsURL)
        let materials = try boundsAuditDecodeMaterials(
            data: materialsData,
            descriptor: descriptor,
            repositoryRoot: repositoryRoot
        )
        guard
            descriptor.task == "PLAY-027",
            descriptor.logicalBuildingID == "industrial_l02",
            descriptor.level == 2,
            descriptor.variantID == "variant-0",
            descriptor.viewDirection == "east",
            descriptor.productionSelected == false,
            materials.productionSelected == false,
            descriptor.materialLibrary.sha256
                == boundsAuditSHA256(materialsData)
        else {
            throw IndustrialL2BoundsAuditError.invalid(
                "Industrial L2 East pre-render authority failed"
            )
        }

        let scene = try ContractSceneBuilder(
            materials: NativeMaterialLibrary(
                descriptor: materials,
                repositoryRoot: repositoryRoot
            )
        ).buildScene(from: descriptor)
        var nodes: [BoundsAuditNode] = []
        scene.rootNode.enumerateChildNodes { node, _ in
            guard
                let geometry = node.geometry,
                let extent = boundsAuditNodeExtent(
                    node,
                    root: scene.rootNode
                )
            else {
                return
            }
            nodes.append(
                BoundsAuditNode(
                    name: node.name ?? "<unnamed>",
                    extent: extent,
                    materialIDs: geometry.materials.compactMap(\.name)
                        .sorted(),
                    primitiveCount: geometry.elements.reduce(0) {
                        $0 + $1.primitiveCount
                    }
                )
            )
        }
        nodes.sort { $0.name < $1.name }
        guard !nodes.isEmpty else {
            throw IndustrialL2BoundsAuditError.invalid(
                "scene contains no geometry nodes"
            )
        }
        var manualUnion = BoundsAuditExtent()
        for node in nodes {
            manualUnion.include(node.extent)
        }
        let rootExtent = try boundsAuditRootExtent(scene.rootNode)
        let halfWidth = descriptor.building.width / 2
        let halfDepth = descriptor.building.depth / 2
        let requiredHeight =
            descriptor.building.foundationHeight
            + descriptor.building.wallHeight
        let complete =
            rootExtent.minX <= -halfWidth
            && rootExtent.maxX >= halfWidth
            && rootExtent.minZ <= -halfDepth
            && rootExtent.maxZ >= halfDepth
            && rootExtent.minY <= 0
            && rootExtent.maxY >= requiredHeight
        let rootMatchesManual =
            abs(rootExtent.minX - manualUnion.minX)
                <= boundsAuditTolerance
            && abs(rootExtent.maxX - manualUnion.maxX)
                <= boundsAuditTolerance
            && abs(rootExtent.minY - manualUnion.minY)
                <= boundsAuditTolerance
            && abs(rootExtent.maxY - manualUnion.maxY)
                <= boundsAuditTolerance
            && abs(rootExtent.minZ - manualUnion.minZ)
                <= boundsAuditTolerance
            && abs(rootExtent.maxZ - manualUnion.maxZ)
                <= boundsAuditTolerance
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-pre-render-bounds-audit",
            "sceneFile": boundsAuditRepositoryPath(
                sceneURL,
                repositoryRoot: repositoryRoot
            ),
            "sceneSHA256": try boundsAuditSHA256(sceneURL),
            "materialLibraryFile": boundsAuditRepositoryPath(
                materialsURL,
                repositoryRoot: repositoryRoot
            ),
            "materialLibrarySHA256": boundsAuditSHA256(materialsData),
            "sourceRevision": descriptor.sourceRevision,
            "sceneGeometryID": descriptor.sceneGeometryID,
            "requiredBoundsWorld": [
                "x": [-halfWidth, halfWidth],
                "z": [-halfDepth, halfDepth],
                "minimumY": 0,
                "minimumMaximumY": requiredHeight,
            ],
            "sceneKitRootBoundsWorld": rootExtent.record,
            "manualGeometryUnionBoundsWorld": manualUnion.record,
            "rootMatchesManualGeometryUnion": rootMatchesManual,
            "faceContributors":
                boundsAuditContributors(nodes, union: manualUnion),
            "geometryNodeCount": nodes.count,
            "geometryNodes": nodes.map(\.record),
            "complete": complete,
            "rendererCapabilityPreflightInvoked": false,
            "sceneKitRendererCreated": false,
            "sceneKitSnapshotInvoked": false,
            "pixelsCreated": false,
            "productionSelected": false,
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: reportURL, options: .atomic)
        print(
            "pre-render bounds \(complete ? "PASS" : "FAIL") "
                + "root=\(rootExtent.record)"
        )
        print(
            "nodes=\(nodes.count) renderer=false snapshot=false pixels=false"
        )
    }
}
