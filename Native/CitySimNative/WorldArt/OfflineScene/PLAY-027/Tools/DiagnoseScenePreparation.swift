import CryptoKit
import Darwin
import Foundation
import SceneKit

enum ScenePreparationDiagnosticError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: diagnose-scene-preparation --repository-root <path> --scene <json> --materials <json> --report <json> --diagnostic-ack PLAY-027-SCENE-PREP-V1 [--include-groups <csv>] [--include-root-names <csv>]"
        case let .invalid(message):
            return message
        }
    }
}

struct DiagnosticSelection {
    let groups: Set<String>?
    let rootNames: Set<String>?

    func includes(name: String, group: String) -> Bool {
        if let rootNames {
            return rootNames.contains(name)
        }
        if let groups {
            return groups.contains(group)
        }
        return true
    }
}

func sceneDiagnosticArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw ScenePreparationDiagnosticError.arguments
    }
    return arguments[index + 1]
}

func sceneDiagnosticOptionalArgument(
    _ name: String,
    in arguments: [String]
) -> String? {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        return nil
    }
    return arguments[index + 1]
}

func sceneDiagnosticCSV(_ value: String?) -> Set<String>? {
    value.map {
        Set(
            $0.split(separator: ",")
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }
}

func sceneDiagnosticSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func sceneDiagnosticRelativePath(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func sceneDiagnosticFinite(_ value: Float) -> Bool {
    value.isFinite
}

func sceneDiagnosticVector(_ vector: SCNVector3) -> [Double] {
    [Double(vector.x), Double(vector.y), Double(vector.z)]
}

func sceneDiagnosticMatrix(_ matrix: SCNMatrix4) -> [Double] {
    [
        Double(matrix.m11), Double(matrix.m12),
        Double(matrix.m13), Double(matrix.m14),
        Double(matrix.m21), Double(matrix.m22),
        Double(matrix.m23), Double(matrix.m24),
        Double(matrix.m31), Double(matrix.m32),
        Double(matrix.m33), Double(matrix.m34),
        Double(matrix.m41), Double(matrix.m42),
        Double(matrix.m43), Double(matrix.m44),
    ]
}

func sceneDiagnosticGroup(
    name: String,
    node: SCNNode
) -> String {
    let lower = name.lowercased()
    if node.camera != nil || node.light != nil {
        return "shadow-light-camera"
    }
    if lower == "foundation" || lower.contains("ground-plate")
        || lower.contains("shadow-receiver")
    {
        return "foundation-plate"
    }
    if lower.contains("window") || lower.contains("clerestory")
        || lower.contains("-glass") || lower.contains("-mullion")
    {
        return "windows"
    }
    if lower.contains("frontage") || lower.contains("gantry")
        || lower.contains("apron") || lower.contains("loading")
        || lower.contains("entrance") || lower.contains("pavilion")
        || lower.contains("porch") || lower.contains("door")
        || lower.contains("canopy") || lower.contains("stoop")
        || lower.contains("service-tank")
    {
        return "frontage-gantry-props"
    }
    if lower.contains("roof") || lower.contains("sawtooth")
        || lower.contains("process-tower") || lower.contains("chimney")
        || lower.contains("crane") || lower.contains("hvac")
        || lower.contains("exhaust")
    {
        return "roof-process"
    }
    return "structural-mass"
}

func sceneDiagnosticContentsRecord(_ contents: Any?) -> [String: Any] {
    guard let contents else {
        return ["kind": "none", "resourcePath": NSNull()]
    }
    if let url = contents as? URL {
        return [
            "kind": "url",
            "resourcePath": url.path,
        ]
    }
    if let path = contents as? String {
        return [
            "kind": "string",
            "resourcePath": path,
        ]
    }
    return [
        "kind": String(describing: type(of: contents)),
        "resourcePath": NSNull(),
    ]
}

func sceneDiagnosticMaterialRecord(
    _ material: SCNMaterial,
    index: Int
) -> [String: Any] {
    [
        "index": index,
        "name": material.name ?? "",
        "lightingModel": material.lightingModel.rawValue,
        "doubleSided": material.isDoubleSided,
        "diffuse": sceneDiagnosticContentsRecord(
            material.diffuse.contents
        ),
        "roughness": sceneDiagnosticContentsRecord(
            material.roughness.contents
        ),
        "metalness": sceneDiagnosticContentsRecord(
            material.metalness.contents
        ),
        "emission": sceneDiagnosticContentsRecord(
            material.emission.contents
        ),
    ]
}

func sceneDiagnosticGeometryRecord(
    _ geometry: SCNGeometry
) -> [String: Any] {
    let sources = geometry.sources.map { source in
        [
            "semantic": source.semantic.rawValue,
            "vectorCount": source.vectorCount,
            "componentsPerVector": source.componentsPerVector,
            "bytesPerComponent": source.bytesPerComponent,
            "dataOffset": source.dataOffset,
            "dataStride": source.dataStride,
        ] as [String: Any]
    }
    let elements = geometry.elements.enumerated().map { index, element in
        [
            "index": index,
            "primitiveType": element.primitiveType.rawValue,
            "primitiveCount": element.primitiveCount,
            "bytesPerIndex": element.bytesPerIndex,
            "dataByteCount": element.data.count,
        ] as [String: Any]
    }
    return [
        "class": String(describing: type(of: geometry)),
        "name": geometry.name ?? "",
        "sourceCount": sources.count,
        "elementCount": elements.count,
        "vertexCount":
            geometry.sources(for: .vertex).first?.vectorCount ?? 0,
        "sources": sources,
        "elements": elements,
        "materialCount": geometry.materials.count,
        "materials": geometry.materials.enumerated().map {
            sceneDiagnosticMaterialRecord($0.element, index: $0.offset)
        },
    ]
}

func sceneDiagnosticNodeRecord(
    _ node: SCNNode,
    path: String,
    index: Int
) -> ([String: Any], [String]) {
    let name = node.name ?? ""
    let bounds = node.boundingBox
    let transform = sceneDiagnosticMatrix(node.transform)
    let worldTransform = sceneDiagnosticMatrix(node.worldTransform)
    let boundValues = sceneDiagnosticVector(bounds.min)
        + sceneDiagnosticVector(bounds.max)
    var failures: [String] = []
    if name.isEmpty {
        failures.append("missing node identity")
    }
    if !(transform + worldTransform + boundValues).allSatisfy({
        $0.isFinite
    }) {
        failures.append("non-finite transform or bounds")
    }
    if let geometry = node.geometry {
        if geometry.sources(for: .vertex).first?.vectorCount ?? 0 <= 0 {
            failures.append("geometry has no vertices")
        }
        if geometry.elements.isEmpty {
            failures.append("geometry has no index elements")
        }
        if geometry.materials.isEmpty {
            failures.append("geometry has no material")
        }
    }
    let group = sceneDiagnosticGroup(name: name, node: node)
    let record: [String: Any] = [
        "index": index,
        "name": name,
        "path": path,
        "group": group,
        "position": sceneDiagnosticVector(node.position),
        "scale": sceneDiagnosticVector(node.scale),
        "transform": transform,
        "worldTransform": worldTransform,
        "bounds": [
            "minimum": sceneDiagnosticVector(bounds.min),
            "maximum": sceneDiagnosticVector(bounds.max),
        ],
        "castsShadow": node.castsShadow,
        "hasCamera": node.camera != nil,
        "hasLight": node.light != nil,
        "geometry":
            node.geometry.map(sceneDiagnosticGeometryRecord) ?? NSNull(),
        "failures": failures,
        "passed": failures.isEmpty,
    ]
    return (record, failures)
}

func sceneDiagnosticInventory(
    _ scene: SCNScene
) -> [String: Any] {
    var records: [[String: Any]] = []
    var failures: [String] = []
    var names: [String] = []
    var primitiveCount = 0
    var materialCount = 0
    var geometrySourceCount = 0
    var geometryElementCount = 0
    var textureResourcePaths: [String] = []

    func visit(_ node: SCNNode, parentPath: String) {
        let name = node.name ?? ""
        let path = parentPath + "/" + (name.isEmpty ? "<unnamed>" : name)
        let (record, nodeFailures) = sceneDiagnosticNodeRecord(
            node,
            path: path,
            index: records.count
        )
        records.append(record)
        failures.append(contentsOf: nodeFailures.map {
            "\(path): \($0)"
        })
        names.append(name)
        if let geometry = node.geometry {
            primitiveCount += geometry.elements.reduce(0) {
                $0 + $1.primitiveCount
            }
            materialCount += geometry.materials.count
            geometrySourceCount += geometry.sources.count
            geometryElementCount += geometry.elements.count
            for material in geometry.materials {
                for property in [
                    material.diffuse,
                    material.roughness,
                    material.metalness,
                    material.emission,
                ] {
                    if let url = property.contents as? URL {
                        textureResourcePaths.append(url.path)
                    } else if let path = property.contents as? String {
                        textureResourcePaths.append(path)
                    }
                }
            }
        }
        for child in node.childNodes {
            visit(child, parentPath: path)
        }
    }

    for child in scene.rootNode.childNodes {
        visit(child, parentPath: "root")
    }
    let duplicateNames = Dictionary(grouping: names, by: { $0 })
        .filter { !$0.key.isEmpty && $0.value.count > 1 }
        .map {
            [
                "name": $0.key,
                "count": $0.value.count,
            ] as [String: Any]
        }
        .sorted {
            ($0["name"] as? String ?? "")
                < ($1["name"] as? String ?? "")
        }
    if !duplicateNames.isEmpty {
        failures.append(
            "\(duplicateNames.count) duplicate node identities"
        )
    }
    let groupCounts = Dictionary(
        grouping: records,
        by: { $0["group"] as? String ?? "unknown" }
    ).mapValues(\.count)
    return [
        "nodeCount": records.count,
        "rootNodeCount": scene.rootNode.childNodes.count,
        "primitiveCount": primitiveCount,
        "materialReferenceCount": materialCount,
        "geometrySourceCount": geometrySourceCount,
        "geometryElementCount": geometryElementCount,
        "groupCounts": groupCounts,
        "textureResourcePaths": Array(Set(textureResourcePaths)).sorted(),
        "duplicateIdentities": duplicateNames,
        "invalidIdentityCount": names.filter(\.isEmpty).count,
        "nodes": records,
        "failures": failures,
        "passed": failures.isEmpty,
    ]
}

func sceneDiagnosticClone(
    _ source: SCNScene,
    selection: DiagnosticSelection
) -> (SCNScene, [[String: String]]) {
    let result = SCNScene()
    result.background.contents = source.background.contents
    var included: [[String: String]] = []
    for node in source.rootNode.childNodes {
        let name = node.name ?? ""
        let group = sceneDiagnosticGroup(name: name, node: node)
        guard selection.includes(name: name, group: group) else {
            continue
        }
        result.rootNode.addChildNode(node.clone())
        included.append([
            "name": name,
            "group": group,
        ])
    }
    return (result, included)
}

func sceneDiagnosticPrepare(_ scene: SCNScene) -> Bool {
    let renderer = SCNRenderer(device: nil, options: nil)
    SCNTransaction.flush()
    scene.isPaused = true
    renderer.scene = scene
    renderer.sceneTime = 0
    if let camera = scene.rootNode.childNode(
        withName: "contract-camera",
        recursively: false
    ) {
        renderer.pointOfView = camera
    }
    renderer.isJitteringEnabled = false
    renderer.autoenablesDefaultLighting = false
    return renderer.prepare(scene, shouldAbortBlock: nil)
}

@main
enum DiagnoseScenePreparationMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try sceneDiagnosticArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let sceneURL = URL(
            fileURLWithPath: try sceneDiagnosticArgument(
                "--scene",
                in: arguments
            )
        ).standardizedFileURL
        let materialsURL = URL(
            fileURLWithPath: try sceneDiagnosticArgument(
                "--materials",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try sceneDiagnosticArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        let acknowledgement = try sceneDiagnosticArgument(
            "--diagnostic-ack",
            in: arguments
        )
        guard
            acknowledgement == "PLAY-027-SCENE-PREP-V1",
            reportURL.path.contains(
                "/docs/production/evidence/PLAY-027/industrial-l02/l02/source-v03-candidate/diagnostics/"
            ),
            reportURL.pathExtension == "json",
            !FileManager.default.fileExists(atPath: reportURL.path)
        else {
            throw ScenePreparationDiagnosticError.invalid(
                "diagnostic acknowledgement/path/no-overwrite guard failed"
            )
        }
        let sceneData = try Data(contentsOf: sceneURL)
        let materialsData = try Data(contentsOf: materialsURL)
        let sceneHash = sceneDiagnosticSHA256(sceneData)
        let materialsHash = sceneDiagnosticSHA256(materialsData)
        let allowedSceneHashes: [String: String] = [
            "north":
                "aee5c7ef5de5b62fb357335c09d9a020ed97582882bfd1bf7ac7bc21f6d3a5b6",
            "east":
                "24ccd400535090532be046fe9868c069f3fc1b94aa999fc4c6569b74c24c03e1",
            "south":
                "ce4c8067135a1f57ee50dbfed9aa3b83b7fab6aa847aa7bd8c79cb783bb72d1c",
            "west":
                "8ce989ea6c4b85fbdf04ba002236179c45b71b0fbe2cc2d5a39a2abf28b29a1e",
        ]
        let decoder = JSONDecoder()
        let descriptor = try decoder.decode(
            SceneDescriptor.self,
            from: sceneData
        )
        let materialDescriptor = try decoder.decode(
            MaterialLibraryDescriptor.self,
            from: materialsData
        )
        guard
            descriptor.logicalBuildingID == "industrial_l02",
            descriptor.variantID == "variant-0",
            descriptor.sourceRevision == "source-v03",
            descriptor.productionSelected == false,
            descriptor.authoredIndependently,
            descriptor.derivation.siblingSource == nil,
            descriptor.derivation.mirror == false,
            descriptor.derivation.rotationDegrees == 0,
            descriptor.derivation.transform == "none",
            allowedSceneHashes[descriptor.viewDirection] == sceneHash,
            materialsHash
                == "166a19d5569a927d6ccdbaf1b29131835238bb3622e66d3b376d9eb33008f1ef",
            materialDescriptor.productionSelected == false
        else {
            throw ScenePreparationDiagnosticError.invalid(
                "frozen descriptor/material identity guard failed"
            )
        }
        let sampling = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        guard
            sampling.contractID
                == DescriptorSamplingResolver.schema2ContractV3ID,
            sampling.purpose == "source-authority"
        else {
            throw ScenePreparationDiagnosticError.invalid(
                "schema-2 v3 descriptor binding guard failed"
            )
        }

        let sourceScene = try ContractSceneBuilder(
            materials: NativeMaterialLibrary(
                descriptor: materialDescriptor
            )
        ).buildScene(from: descriptor)
        let selection = DiagnosticSelection(
            groups: sceneDiagnosticCSV(
                sceneDiagnosticOptionalArgument(
                    "--include-groups",
                    in: arguments
                )
            ),
            rootNames: sceneDiagnosticCSV(
                sceneDiagnosticOptionalArgument(
                    "--include-root-names",
                    in: arguments
                )
            )
        )
        let sourceInventory = sceneDiagnosticInventory(sourceScene)
        let (diagnosticScene, includedNodes) = sceneDiagnosticClone(
            sourceScene,
            selection: selection
        )
        let selectedInventory = sceneDiagnosticInventory(diagnosticScene)
        let prepared = sceneDiagnosticPrepare(diagnosticScene)
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "purpose":
                "diagnostic-only cloned-scene inventory and SceneKit prepare isolation",
            "diagnosticContract": "PLAY-027-SCENE-PREP-V1",
            "sourceAuthority": false,
            "productionSelected": false,
            "descriptorGeometryChanged": false,
            "candidateOutputWritten": false,
            "logicalBuildingID": descriptor.logicalBuildingID,
            "viewDirection": descriptor.viewDirection,
            "sourceRevision": descriptor.sourceRevision,
            "sceneFile": sceneDiagnosticRelativePath(
                sceneURL,
                repositoryRoot: repositoryRoot
            ),
            "sceneSHA256": sceneHash,
            "materialsFile": sceneDiagnosticRelativePath(
                materialsURL,
                repositoryRoot: repositoryRoot
            ),
            "materialsSHA256": materialsHash,
            "rendererSourceAuthority":
                "e2690f524dbf468255605cfe77a236404a015fa9",
            "selection": [
                "groups":
                    selection.groups.map { Array($0).sorted() }
                    ?? ["all"],
                "rootNames":
                    selection.rootNames.map { Array($0).sorted() }
                    ?? ["all"],
                "includedRootNodes": includedNodes,
            ],
            "sourceInventory": sourceInventory,
            "selectedInventory": selectedInventory,
            "prepare": [
                "api":
                    "SCNRenderer.prepare(scene, shouldAbortBlock:nil)",
                "passed": prepared,
                "exitCode": prepared ? 0 : 2,
                "pngWritten": false,
                "provenanceWritten": false,
            ],
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
        exit(prepared ? 0 : 2)
    }
}
