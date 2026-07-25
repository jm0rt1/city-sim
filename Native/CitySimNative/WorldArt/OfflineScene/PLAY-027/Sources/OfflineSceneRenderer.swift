import AppKit
import CoreGraphics
import CoreImage
import CryptoKit
import Foundation
import ImageIO
import ModelIO
import SceneKit
import SceneKit.ModelIO
import UniformTypeIdentifiers

enum OfflineRendererError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)
    case rendering(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: offline-scene-renderer --repository-root <path> --scene <json> --materials <json> --output <png> --record <json> --renderer-source-commit <sha> [--backend-capability-record <json>] [--diagnostic-contract <id>] [--diagnostic-stage-contract <id>] [--diagnostic-antialiasing current|none] [--diagnostic-scene-shadows current|disabled] [--diagnostic-material-lighting current|constant-unlit] [--diagnostic-prequantized-output <png>] [--diagnostic-stage-capture-dir <dir> --diagnostic-stage-coordinate <x,y>]"
        case let .invalid(message):
            return message
        case let .rendering(message):
            return message
        }
    }
}

func rendererArgument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw OfflineRendererError.arguments
    }
    return arguments[index + 1]
}

func rendererOptionalArgument(
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

enum DiagnosticAntialiasing: String {
    case current
    case none

    var sceneKitMode: SCNAntialiasingMode {
        switch self {
        case .current:
            return .multisampling4X
        case .none:
            return .none
        }
    }
}

enum DiagnosticSceneShadows: String {
    case current
    case disabled
}

enum DiagnosticMaterialLighting: String {
    case current
    case constantUnlit = "constant-unlit"
}

struct RendererDiagnosticConfiguration {
    let antialiasingOverride: DiagnosticAntialiasing?
    let sceneShadows: DiagnosticSceneShadows
    let materialLighting: DiagnosticMaterialLighting

    var hasOverride: Bool {
        antialiasingOverride != nil
            || sceneShadows != .current
            || materialLighting != .current
    }
}

struct DiagnosticMaterialLightingApplication {
    let uniqueMaterialCount: Int
    let sceneLightCount: Int
}

func applyDiagnosticMaterialLighting(
    _ mode: DiagnosticMaterialLighting,
    to scene: SCNScene
) -> DiagnosticMaterialLightingApplication {
    guard mode == .constantUnlit else {
        return DiagnosticMaterialLightingApplication(
            uniqueMaterialCount: 0,
            sceneLightCount: 0
        )
    }
    var materialIdentities = Set<ObjectIdentifier>()
    var sceneLightCount = 0
    scene.rootNode.enumerateChildNodes { node, _ in
        if let light = node.light {
            light.intensity = 0
            light.castsShadow = false
            sceneLightCount += 1
        }
        for material in node.geometry?.materials ?? [] {
            material.lightingModel = .constant
            materialIdentities.insert(ObjectIdentifier(material))
        }
    }
    return DiagnosticMaterialLightingApplication(
        uniqueMaterialCount: materialIdentities.count,
        sceneLightCount: sceneLightCount
    )
}

func rendererSHA256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map {
        String(format: "%02x", $0)
    }.joined()
}

func rendererRelativePath(_ url: URL, repositoryRoot: URL) -> String {
    let prefix = repositoryRoot.path.hasSuffix("/")
        ? repositoryRoot.path
        : repositoryRoot.path + "/"
    guard url.path.hasPrefix(prefix) else {
        return url.path
    }
    return String(url.path.dropFirst(prefix.count))
}

func rendererBoundaryAssistMutationRecord(
    _ mutation: PixelCanonicalizationMutation
) -> [String: Any]? {
    guard let assist = mutation.boundaryAssist else {
        return nil
    }
    let vote: [String: Any] = [
        "coordinate": [assist.vote.x, assist.vote.y],
        "channel": assist.vote.channel,
        "prequantizedValue": assist.vote.prequantizedValue,
        "quantizedValue": assist.vote.quantizedValue,
        "boundaryPair": assist.vote.boundaryPair,
    ]
    return [
        "target": [mutation.x, mutation.y],
        "channel": mutation.channel,
        "originalValue": mutation.originalValue,
        "majorityValue": mutation.majorityValue,
        "prequantizedVote": vote,
        "effectiveSupportCount": assist.effectiveSupportCount,
        "competingSupportAfterBoundaryReclassification":
            assist.competingSupportAfterBoundaryReclassification,
        "reason": assist.reason,
    ]
}

func rendererPostQuantizationContractRecord(
    _ contract: SamplingPostQuantizationCanonicalizerDescriptor?
) -> [String: Any] {
    guard let contract else {
        return ["algorithm": "none"]
    }
    let boundaryAssist: [String: Any]
    if let assist = contract.boundaryAssist {
        boundaryAssist = [
            "algorithm": assist.algorithm,
            "version": assist.version,
            "baseQuantizedMajorityCount":
                assist.baseQuantizedMajorityCount,
            "requiredBoundaryVoteCount":
                assist.requiredBoundaryVoteCount,
            "effectiveSupportCount": assist.effectiveSupportCount,
            "maximumCompetingSupportAfterBoundaryReclassification":
                assist
                .maximumCompetingSupportAfterBoundaryReclassification,
            "quantizerStep": assist.quantizerStep,
            "quantizerMidpointOffset":
                assist.quantizerMidpointOffset,
            "boundaryBandWidthValues":
                assist.boundaryBandWidthValues,
            "requiresSameChannelEvidence":
                assist.requiresSameChannelEvidence,
            "immutablePrequantizedBuffer":
                assist.immutablePrequantizedBuffer,
            "recordsBoundaryVoteReason":
                assist.recordsBoundaryVoteReason,
        ]
    } else {
        boundaryAssist = ["algorithm": "none"]
    }
    return [
        "algorithm": contract.algorithm,
        "version": contract.version,
        "quantizationQuantum": contract.quantizationQuantum,
        "neighborhoodSize": contract.neighborhoodSize,
        "majorityThreshold": contract.majorityThreshold,
        "requiresFullyOpaqueNeighborhood":
            contract.requiresFullyOpaqueNeighborhood,
        "immutableSourceBuffer": contract.immutableSourceBuffer,
        "requiresChromaFreeNeighborhood":
            contract.requiresChromaFreeNeighborhood,
        "channels": contract.channels,
        "preservesAlpha": contract.preservesAlpha,
        "preservesChroma": contract.preservesChroma,
        "boundaryAssist": boundaryAssist,
    ]
}

func color(_ components: [Double]) throws -> NSColor {
    guard components.count == 4 else {
        throw OfflineRendererError.invalid("material color must contain RGBA")
    }
    return NSColor(
        colorSpace: .extendedSRGB,
        components: components.map { CGFloat($0) },
        count: 4
    )
}

final class NativeMaterialLibrary {
    private let specifications: [String: MaterialDescriptor]
    private var sceneKitMaterials: [String: SCNMaterial] = [:]

    init(descriptor: MaterialLibraryDescriptor) {
        specifications = Dictionary(
            uniqueKeysWithValues: descriptor.materials.map { ($0.id, $0) }
        )
    }

    func material(_ id: String) throws -> SCNMaterial {
        if let existing = sceneKitMaterials[id] {
            return existing
        }
        guard let specification = specifications[id] else {
            throw OfflineRendererError.invalid("unknown material: \(id)")
        }
        let material = SCNMaterial()
        material.name = id
        // The offline source contract needs stable directional illumination,
        // not runtime PBR. Lambert retains the authored northwest key and
        // ambient hierarchy without SceneKit's stochastic PBR shading drift.
        material.lightingModel = .lambert
        material.diffuse.contents = specification.pattern == "solid"
            ? try color(specification.baseColorRGBA)
            : try patternImage(specification)
        material.roughness.contents = NSNumber(
            value: specification.roughness
        )
        material.metalness.contents = NSNumber(
            value: specification.metalness
        )
        if let emission = specification.emissionRGBA {
            material.emission.contents = try color(emission)
            material.emission.intensity = 0.42
        }
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.diffuse.mipFilter = .linear
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(4, 4, 1)
        material.isDoubleSided = false
        sceneKitMaterials[id] = material
        return material
    }

    private func patternImage(
        _ specification: MaterialDescriptor
    ) throws -> CGImage {
        let size = 256
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw OfflineRendererError.rendering(
                "could not allocate material context"
            )
        }
        context.setFillColor(try color(specification.baseColorRGBA).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))

        let lineColor = try color(
            specification.baseColorRGBA.enumerated().map { index, value in
                index == 3 ? value : max(0, value * 0.72)
            }
        )
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(2)

        switch specification.pattern {
        case "running-bond-relief", "stacked-brick":
            let course = 32
            for y in stride(from: 0, through: size, by: course) {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: size, y: y))
                let offset = (y / course).isMultiple(of: 2) ? 0 : 32
                for x in stride(from: offset, through: size, by: 64) {
                    context.move(to: CGPoint(x: x, y: y))
                    context.addLine(to: CGPoint(x: x, y: y + course))
                }
            }
        case "staggered-slate":
            for y in stride(from: 0, through: size, by: 28) {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: size, y: y))
                let offset = (y / 28).isMultiple(of: 2) ? 0 : 24
                for x in stride(from: offset, through: size, by: 48) {
                    context.move(to: CGPoint(x: x, y: y))
                    context.addLine(to: CGPoint(x: x, y: y + 28))
                }
            }
        case "cut-stone", "rusticated-block":
            for y in stride(from: 0, through: size, by: 48) {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: size, y: y))
                let offset = (y / 48).isMultiple(of: 2) ? 0 : 40
                for x in stride(from: offset, through: size, by: 80) {
                    context.move(to: CGPoint(x: x, y: y))
                    context.addLine(to: CGPoint(x: x, y: y + 48))
                }
            }
        case "recessed-panel":
            context.stroke(CGRect(x: 24, y: 24, width: 208, height: 208))
            context.stroke(CGRect(x: 48, y: 48, width: 160, height: 64))
            context.stroke(CGRect(x: 48, y: 144, width: 160, height: 64))
        case "divided-light":
            context.setStrokeColor(
                NSColor(
                    colorSpace: .extendedSRGB,
                    components: [0.12, 0.08, 0.04, 1],
                    count: 4
                ).cgColor
            )
            context.setLineWidth(10)
            context.stroke(CGRect(x: 8, y: 8, width: 240, height: 240))
            context.move(to: CGPoint(x: 128, y: 8))
            context.addLine(to: CGPoint(x: 128, y: 248))
            context.move(to: CGPoint(x: 8, y: 128))
            context.addLine(to: CGPoint(x: 248, y: 128))
        case "foliage-cluster":
            for index in 0..<18 {
                let x = CGFloat((index * 47) % 220 + 18)
                let y = CGFloat((index * 83) % 220 + 18)
                let radius = CGFloat(9 + (index % 4) * 3)
                context.setFillColor(
                    NSColor(
                        colorSpace: .extendedSRGB,
                        components: [
                            0.05 + CGFloat(index % 3) * 0.018,
                            0.17 + CGFloat(index % 4) * 0.025,
                            0.055,
                            1,
                        ],
                        count: 4
                    ).cgColor
                )
                context.fillEllipse(
                    in: CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                )
            }
        default:
            break
        }
        context.strokePath()
        guard let image = context.makeImage() else {
            throw OfflineRendererError.rendering(
                "could not create material image"
            )
        }
        return image
    }
}

final class ContractSceneBuilder: OfflineSceneBuilding {
    private let materials: NativeMaterialLibrary

    init(materials: NativeMaterialLibrary) {
        self.materials = materials
    }

    func buildScene(from descriptor: SceneDescriptor) throws -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.clear

        let foundation = try boxNode(
            name: "foundation",
            dimensions: [
                descriptor.building.width,
                descriptor.building.foundationHeight,
                descriptor.building.depth,
            ],
            position: [
                0,
                descriptor.building.foundationHeight / 2,
                0,
            ],
            materialID: descriptor.building.foundationMaterialID
        )
        scene.rootNode.addChildNode(foundation)

        if let massBlocks = descriptor.building.massBlocks,
            !massBlocks.isEmpty
        {
            for block in massBlocks {
                scene.rootNode.addChildNode(
                    try boxNode(
                        name: block.id,
                        dimensions: block.dimensions,
                        position: block.positionWorld,
                        materialID: block.materialID
                    )
                )
            }
            for band in descriptor.building.trimBands ?? [] {
                scene.rootNode.addChildNode(
                    try boxNode(
                        name: band.id,
                        dimensions: band.dimensions,
                        position: band.positionWorld,
                        materialID: band.materialID
                    )
                )
            }
            for roof in descriptor.building.roofVolumes ?? [] {
                try addRoofVolume(roof, to: scene)
            }
        } else {
            let walls = try boxNode(
                name: "wall-mass",
                dimensions: [
                    descriptor.building.width,
                    descriptor.building.wallHeight,
                    descriptor.building.depth,
                ],
                position: [
                    0,
                    descriptor.building.foundationHeight
                        + descriptor.building.wallHeight / 2,
                    0,
                ],
                materialID: descriptor.building.wallMaterialID
            )
            scene.rootNode.addChildNode(walls)

            try addCornices(descriptor, to: scene)
            try addCornerQuoins(descriptor, to: scene)
            try addRoof(descriptor, to: scene)
            try addDormer(descriptor, to: scene)
        }
        try addChimney(descriptor, to: scene)

        for facade in descriptor.facades {
            for bay in facade.windowBays {
                try addWindow(
                    bay,
                    facade: facade.direction,
                    family: descriptor.family,
                    to: scene
                )
            }
            for rhythm in facade.windowRhythms ?? [] {
                for (index, center) in rhythm.centersWorld.enumerated() {
                    try addWindow(
                        WindowBayDescriptor(
                            id: rhythm.id + "-\(index)",
                            centerWorld: center,
                            width: rhythm.width,
                            height: rhythm.height,
                            sillHeight: rhythm.sillHeight,
                            floor: rhythm.floor,
                            materialID: rhythm.materialID
                        ),
                        facade: facade.direction,
                        family: descriptor.family,
                        to: scene
                    )
                }
            }
        }
        try addEntrance(descriptor, to: scene)
        for prop in descriptor.props {
            try addProp(prop, to: scene)
        }
        try addLights(descriptor, to: scene)
        addCamera(descriptor, to: scene)
        return scene
    }

    private func addRoofVolume(
        _ roof: RoofVolumeDescriptor,
        to scene: SCNScene
    ) throws {
        guard roof.dimensions.count == 3, roof.positionWorld.count == 3 else {
            throw OfflineRendererError.invalid(
                "roof volume requires three dimensions and position values"
            )
        }
        switch roof.shape {
        case "hip":
            let geometry = SCNPyramid(
                width: roof.dimensions[0],
                height: roof.dimensions[1],
                length: roof.dimensions[2]
            )
            geometry.firstMaterial = try materials.material(roof.materialID)
            let node = SCNNode(geometry: geometry)
            node.name = roof.id
            node.position = SCNVector3(
                roof.positionWorld[0],
                roof.positionWorld[1],
                roof.positionWorld[2]
            )
            node.castsShadow = true
            scene.rootNode.addChildNode(node)
        case "flat-parapet":
            let slabHeight = min(1.5, max(0.8, roof.dimensions[1] * 0.22))
            scene.rootNode.addChildNode(
                try boxNode(
                    name: roof.id + "-slab",
                    dimensions: [
                        roof.dimensions[0],
                        slabHeight,
                        roof.dimensions[2],
                    ],
                    position: [
                        roof.positionWorld[0],
                        roof.positionWorld[1]
                            - roof.dimensions[1] / 2 + slabHeight / 2,
                        roof.positionWorld[2],
                    ],
                    materialID: roof.materialID
                )
            )
            let parapetHeight = max(1.8, roof.dimensions[1] - slabHeight)
            let parapetY =
                roof.positionWorld[1]
                + roof.dimensions[1] / 2
                - parapetHeight / 2
            let halfWidth = roof.dimensions[0] / 2
            let halfDepth = roof.dimensions[2] / 2
            for (suffix, dimensions, position) in [
                (
                    "north",
                    [roof.dimensions[0], parapetHeight, 1.0],
                    [
                        roof.positionWorld[0],
                        parapetY,
                        roof.positionWorld[2] - halfDepth,
                    ]
                ),
                (
                    "south",
                    [roof.dimensions[0], parapetHeight, 1.0],
                    [
                        roof.positionWorld[0],
                        parapetY,
                        roof.positionWorld[2] + halfDepth,
                    ]
                ),
                (
                    "east",
                    [1.0, parapetHeight, roof.dimensions[2]],
                    [
                        roof.positionWorld[0] + halfWidth,
                        parapetY,
                        roof.positionWorld[2],
                    ]
                ),
                (
                    "west",
                    [1.0, parapetHeight, roof.dimensions[2]],
                    [
                        roof.positionWorld[0] - halfWidth,
                        parapetY,
                        roof.positionWorld[2],
                    ]
                ),
            ] {
                scene.rootNode.addChildNode(
                    try boxNode(
                        name: roof.id + "-parapet-" + suffix,
                        dimensions: dimensions,
                        position: position,
                        materialID: roof.trimMaterialID
                    )
                )
            }
        default:
            throw OfflineRendererError.invalid(
                "unsupported roof volume shape: \(roof.shape)"
            )
        }
    }

    private func boxNode(
        name: String,
        dimensions: [Double],
        position: [Double],
        materialID: String
    ) throws -> SCNNode {
        let mesh = MDLMesh(
            boxWithExtent: SIMD3<Float>(
                Float(dimensions[0]),
                Float(dimensions[1]),
                Float(dimensions[2])
            ),
            segments: SIMD3<UInt32>(1, 1, 1),
            inwardNormals: false,
            geometryType: .triangles,
            allocator: nil
        )
        let geometry = SCNGeometry(mdlMesh: mesh)
        geometry.firstMaterial = try materials.material(materialID)
        let node = SCNNode(geometry: geometry)
        node.name = name
        node.position = SCNVector3(
            position[0],
            position[1],
            position[2]
        )
        node.castsShadow = true
        return node
    }

    private func addCornices(
        _ descriptor: SceneDescriptor,
        to scene: SCNScene
    ) throws {
        let width = descriptor.building.width + 1.2
        let depth = descriptor.building.depth + 1.2
        let levels = [
            descriptor.building.foundationHeight + 0.45,
            descriptor.building.foundationHeight
                + descriptor.building.floorHeight + 0.5,
            descriptor.building.foundationHeight
                + descriptor.building.wallHeight - 0.7,
        ]
        for (index, y) in levels.enumerated() {
            scene.rootNode.addChildNode(
                try boxNode(
                    name: "cornice-\(index)-north-south",
                    dimensions: [width, 0.8, depth],
                    position: [0, y, 0],
                    materialID: descriptor.building.trimMaterialID
                )
            )
        }
    }

    private func addCornerQuoins(
        _ descriptor: SceneDescriptor,
        to scene: SCNScene
    ) throws {
        let halfWidth = descriptor.building.width / 2 + 0.35
        let halfDepth = descriptor.building.depth / 2 + 0.35
        let y = descriptor.building.foundationHeight
            + descriptor.building.wallHeight / 2
        for x in [-halfWidth, halfWidth] {
            for z in [-halfDepth, halfDepth] {
                scene.rootNode.addChildNode(
                    try boxNode(
                        name: "corner-quoin-\(x)-\(z)",
                        dimensions: [
                            1.15,
                            descriptor.building.wallHeight,
                            1.15,
                        ],
                        position: [x, y, z],
                        materialID: descriptor.building.trimMaterialID
                    )
                )
            }
        }
    }

    private func addRoof(
        _ descriptor: SceneDescriptor,
        to scene: SCNScene
    ) throws {
        let baseY = descriptor.building.foundationHeight
            + descriptor.building.wallHeight
        let roof = SCNPyramid(
            width: descriptor.building.width
                + descriptor.building.roofOverhang * 2,
            height: descriptor.building.roofHeight,
            length: descriptor.building.depth
                + descriptor.building.roofOverhang * 2
        )
        roof.firstMaterial = try materials.material(
            descriptor.building.roofMaterialID
        )
        let roofNode = SCNNode(geometry: roof)
        roofNode.name = "domestic-hip-roof"
        roofNode.position = SCNVector3(
            0,
            baseY + descriptor.building.roofHeight / 2,
            0
        )
        roofNode.castsShadow = true
        scene.rootNode.addChildNode(roofNode)

        let halfWidth = descriptor.building.width / 2
            + descriptor.building.roofOverhang
        let halfDepth = descriptor.building.depth / 2
            + descriptor.building.roofOverhang
        let fasciaY = baseY + 0.3
        scene.rootNode.addChildNode(
            try boxNode(
                name: "roof-fascia-north",
                dimensions: [halfWidth * 2, 0.9, 0.8],
                position: [0, fasciaY, -halfDepth],
                materialID: descriptor.building.trimMaterialID
            )
        )
        scene.rootNode.addChildNode(
            try boxNode(
                name: "roof-fascia-south",
                dimensions: [halfWidth * 2, 0.9, 0.8],
                position: [0, fasciaY, halfDepth],
                materialID: descriptor.building.trimMaterialID
            )
        )
        scene.rootNode.addChildNode(
            try boxNode(
                name: "roof-fascia-east",
                dimensions: [0.8, 0.9, halfDepth * 2],
                position: [halfWidth, fasciaY, 0],
                materialID: descriptor.building.trimMaterialID
            )
        )
        scene.rootNode.addChildNode(
            try boxNode(
                name: "roof-fascia-west",
                dimensions: [0.8, 0.9, halfDepth * 2],
                position: [-halfWidth, fasciaY, 0],
                materialID: descriptor.building.trimMaterialID
            )
        )
    }

    private func addDormer(
        _ descriptor: SceneDescriptor,
        to scene: SCNScene
    ) throws {
        let wallTop = descriptor.building.foundationHeight
            + descriptor.building.wallHeight
        scene.rootNode.addChildNode(
            try boxNode(
                name: "north-dormer-mass",
                dimensions: [10, 8, 5],
                position: [0, wallTop + 6.2, -21.5],
                materialID: descriptor.building.trimMaterialID
            )
        )
        scene.rootNode.addChildNode(
            try boxNode(
                name: "north-dormer-window",
                dimensions: [4.4, 5.2, 0.5],
                position: [0, wallTop + 6.1, -24.2],
                materialID: "window-warm"
            )
        )
        let dormerRoof = SCNPyramid(
            width: 12,
            height: 4,
            length: 7
        )
        dormerRoof.firstMaterial = try materials.material(
            descriptor.building.roofMaterialID
        )
        let roofNode = SCNNode(geometry: dormerRoof)
        roofNode.name = "north-dormer-roof"
        roofNode.position = SCNVector3(0, wallTop + 11.5, -21.5)
        scene.rootNode.addChildNode(roofNode)
    }

    private func addChimney(
        _ descriptor: SceneDescriptor,
        to scene: SCNScene
    ) throws {
        let chimney = descriptor.building.chimney
        scene.rootNode.addChildNode(
            try boxNode(
                name: "chimney",
                dimensions: chimney.dimensions,
                position: chimney.positionWorld,
                materialID: chimney.materialID
            )
        )
        scene.rootNode.addChildNode(
            try boxNode(
                name: "chimney-cap",
                dimensions: [
                    chimney.dimensions[0] + 1.2,
                    1,
                    chimney.dimensions[2] + 1.2,
                ],
                position: [
                    chimney.positionWorld[0],
                    chimney.positionWorld[1]
                        + chimney.dimensions[1] / 2 + 0.35,
                    chimney.positionWorld[2],
                ],
                materialID: descriptor.building.trimMaterialID
            )
        )
    }

    private func addWindow(
        _ bay: WindowBayDescriptor,
        facade: String,
        family: String,
        to scene: SCNScene
    ) throws {
        let isHorizontal = facade == "north" || facade == "south"
        let glassDimensions = isHorizontal
            ? [bay.width, bay.height, 0.55]
            : [0.55, bay.height, bay.width]
        scene.rootNode.addChildNode(
            try boxNode(
                name: bay.id + "-glass",
                dimensions: glassDimensions,
                position: bay.centerWorld,
                materialID: bay.materialID
            )
        )
        let trim = 0.7
        let depth = 0.85
        let x = bay.centerWorld[0]
        let y = bay.centerWorld[1]
        let z = bay.centerWorld[2]
        if isHorizontal {
            for xOffset in [
                -(bay.width + trim) / 2,
                (bay.width + trim) / 2,
            ] {
                scene.rootNode.addChildNode(
                    try boxNode(
                        name: bay.id + "-side-\(xOffset)",
                        dimensions: [trim, bay.height + 1.4, depth],
                        position: [x + xOffset, y, z],
                        materialID: "limestone-warm"
                    )
                )
            }
            for yOffset in [
                -(bay.height + trim) / 2,
                (bay.height + trim) / 2,
            ] {
                scene.rootNode.addChildNode(
                    try boxNode(
                        name: bay.id + "-rail-\(yOffset)",
                        dimensions: [bay.width + 2.1, trim, depth],
                        position: [x, y + yOffset, z],
                        materialID: "limestone-warm"
                    )
                )
            }
            scene.rootNode.addChildNode(
                try boxNode(
                    name: bay.id + "-mullion",
                    dimensions: [0.35, bay.height, depth + 0.1],
                    position: [x, y, z],
                    materialID: "slate-charcoal"
                )
            )
        } else {
            for zOffset in [
                -(bay.width + trim) / 2,
                (bay.width + trim) / 2,
            ] {
                scene.rootNode.addChildNode(
                    try boxNode(
                        name: bay.id + "-side-\(zOffset)",
                        dimensions: [depth, bay.height + 1.4, trim],
                        position: [x, y, z + zOffset],
                        materialID: "limestone-warm"
                    )
                )
            }
            for yOffset in [
                -(bay.height + trim) / 2,
                (bay.height + trim) / 2,
            ] {
                scene.rootNode.addChildNode(
                    try boxNode(
                        name: bay.id + "-rail-\(yOffset)",
                        dimensions: [depth, trim, bay.width + 2.1],
                        position: [x, y + yOffset, z],
                        materialID: "limestone-warm"
                    )
                )
            }
            scene.rootNode.addChildNode(
                try boxNode(
                    name: bay.id + "-mullion",
                    dimensions: [depth + 0.1, bay.height, 0.35],
                    position: [x, y, z],
                    materialID: "slate-charcoal"
                )
            )
        }
        if bay.floor == 1 && family == "residential" {
            let outward: [Double]
            switch facade {
            case "north": outward = [0, 0, -1]
            case "east": outward = [1, 0, 0]
            case "south": outward = [0, 0, 1]
            case "west": outward = [-1, 0, 0]
            default:
                throw OfflineRendererError.invalid(
                    "invalid window facade"
                )
            }
            let flowerBoxCenter = [
                x + outward[0] * 0.8,
                y - bay.height / 2 - 1.0,
                z + outward[2] * 0.8,
            ]
            let flowerBoxDimensions = isHorizontal
                ? [bay.width + 2.4, 1.5, 1.8]
                : [1.8, 1.5, bay.width + 2.4]
            scene.rootNode.addChildNode(
                try boxNode(
                    name: bay.id + "-flower-box",
                    dimensions: flowerBoxDimensions,
                    position: flowerBoxCenter,
                    materialID: "limestone-warm"
                )
            )
            let flowersCenter = [
                flowerBoxCenter[0] + outward[0] * 0.1,
                flowerBoxCenter[1] + 1.0,
                flowerBoxCenter[2] + outward[2] * 0.1,
            ]
            let flowersDimensions = isHorizontal
                ? [bay.width + 1.2, 1.0, 1.2]
                : [1.2, 1.0, bay.width + 1.2]
            scene.rootNode.addChildNode(
                try boxNode(
                    name: bay.id + "-flowers",
                    dimensions: flowersDimensions,
                    position: flowersCenter,
                    materialID: "planting-evergreen"
                )
            )
        }
    }

    private func addEntrance(
        _ descriptor: SceneDescriptor,
        to scene: SCNScene
    ) throws {
        let entrance = descriptor.entrance
        guard
            let facade = descriptor.facades.first(
                where: { $0.id == entrance.facadeID }
            )
        else {
            throw OfflineRendererError.invalid("entrance facade is missing")
        }
        if entrance.style == "loading-bay" {
            try addIndustrialLoadingBay(
                descriptor,
                facade: facade,
                to: scene
            )
            return
        }
        if let style = entrance.style, style != "domestic-porch" {
            try addDensityEntrance(
                descriptor,
                facade: facade,
                style: style,
                to: scene
            )
            return
        }
        let outward: [Double]
        switch facade.direction {
        case "north": outward = [0, 0, -1]
        case "east": outward = [1, 0, 0]
        case "south": outward = [0, 0, 1]
        case "west": outward = [-1, 0, 0]
        default:
            throw OfflineRendererError.invalid("invalid facade direction")
        }
        let base = entrance.baseWorld
        let horizontal = facade.direction == "north"
            || facade.direction == "south"
        let tangent = horizontal
            ? [1.0, 0.0, 0.0]
            : [0.0, 0.0, 1.0]
        let pavilionCenter = [
            base[0]
                - outward[0] * (entrance.pavilionDepth / 2 - 0.2),
            entrance.pavilionHeight / 2,
            base[2]
                - outward[2] * (entrance.pavilionDepth / 2 - 0.2),
        ]
        let pavilionDimensions = horizontal
            ? [
                entrance.pavilionWidth,
                entrance.pavilionHeight,
                entrance.pavilionDepth,
            ]
            : [
                entrance.pavilionDepth,
                entrance.pavilionHeight,
                entrance.pavilionWidth,
            ]
        scene.rootNode.addChildNode(
            try boxNode(
                name: facade.direction + "-entry-pavilion",
                dimensions: pavilionDimensions,
                position: pavilionCenter,
                materialID: entrance.pavilionMaterialID
            )
        )
        let pavilionRoof = SCNPyramid(
            width: horizontal
                ? entrance.pavilionWidth + 3
                : entrance.pavilionDepth + 3,
            height: entrance.pavilionRoofHeight,
            length: horizontal
                ? entrance.pavilionDepth + 3
                : entrance.pavilionWidth + 3
        )
        pavilionRoof.firstMaterial = try materials.material(
            descriptor.building.roofMaterialID
        )
        let pavilionRoofNode = SCNNode(geometry: pavilionRoof)
        pavilionRoofNode.name = facade.direction + "-entry-pavilion-roof"
        pavilionRoofNode.position = SCNVector3(
            pavilionCenter[0],
            entrance.pavilionHeight
                + entrance.pavilionRoofHeight / 2,
            pavilionCenter[2]
        )
        pavilionRoofNode.castsShadow = true
        scene.rootNode.addChildNode(pavilionRoofNode)

        let lanternY = entrance.pavilionHeight - 7
        let lanternWidth = min(6.5, entrance.pavilionWidth * 0.46)
        let lanternHeight = 7.5
        let lanternDepth = 0.7
        for (suffix, dimensions, position) in [
            (
                "north",
                [lanternWidth, lanternHeight, lanternDepth],
                [
                    pavilionCenter[0],
                    lanternY,
                    pavilionCenter[2]
                        - pavilionDimensions[2] / 2 - 0.15,
                ]
            ),
            (
                "south",
                [lanternWidth, lanternHeight, lanternDepth],
                [
                    pavilionCenter[0],
                    lanternY,
                    pavilionCenter[2]
                        + pavilionDimensions[2] / 2 + 0.15,
                ]
            ),
            (
                "east",
                [lanternDepth, lanternHeight, lanternWidth],
                [
                    pavilionCenter[0]
                        + pavilionDimensions[0] / 2 + 0.15,
                    lanternY,
                    pavilionCenter[2],
                ]
            ),
            (
                "west",
                [lanternDepth, lanternHeight, lanternWidth],
                [
                    pavilionCenter[0]
                        - pavilionDimensions[0] / 2 - 0.15,
                    lanternY,
                    pavilionCenter[2],
                ]
            ),
        ] {
            scene.rootNode.addChildNode(
                try boxNode(
                    name:
                        facade.direction
                        + "-entry-lantern-\(suffix)",
                    dimensions: dimensions,
                    position: position,
                    materialID: "window-warm"
                )
            )
        }

        let center = [
            base[0] + outward[0] * entrance.depth / 2,
            base[1] + entrance.height / 2,
            base[2] + outward[2] * entrance.depth / 2,
        ]
        let doorDimensions = horizontal
            ? [entrance.width, entrance.height, entrance.depth]
            : [entrance.depth, entrance.height, entrance.width]
        scene.rootNode.addChildNode(
            try boxNode(
                name: facade.direction + "-primary-door",
                dimensions: doorDimensions,
                position: center,
                materialID: entrance.doorMaterialID
            )
        )

        let trim = 1.15
        let surroundDepth = entrance.depth + 0.5
        if horizontal {
            for offset in [
                -(entrance.width + trim) / 2,
                (entrance.width + trim) / 2,
            ] {
                scene.rootNode.addChildNode(
                    try boxNode(
                        name: facade.direction + "-door-side-\(offset)",
                        dimensions: [
                            trim,
                            entrance.height + 2.3,
                            surroundDepth,
                        ],
                        position: [
                            center[0] + offset,
                            center[1],
                            center[2],
                        ],
                        materialID: entrance.surroundMaterialID
                    )
                )
            }
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-door-lintel",
                    dimensions: [
                        entrance.width + 3.4,
                        trim,
                        surroundDepth,
                    ],
                    position: [
                        center[0],
                        base[1] + entrance.height + trim / 2,
                        center[2],
                    ],
                    materialID: entrance.surroundMaterialID
                )
            )
        } else {
            for offset in [
                -(entrance.width + trim) / 2,
                (entrance.width + trim) / 2,
            ] {
                scene.rootNode.addChildNode(
                    try boxNode(
                        name: facade.direction + "-door-side-\(offset)",
                        dimensions: [
                            surroundDepth,
                            entrance.height + 2.3,
                            trim,
                        ],
                        position: [
                            center[0],
                            center[1],
                            center[2] + offset,
                        ],
                        materialID: entrance.surroundMaterialID
                    )
                )
            }
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-door-lintel",
                    dimensions: [
                        surroundDepth,
                        trim,
                        entrance.width + 3.4,
                    ],
                    position: [
                        center[0],
                        base[1] + entrance.height + trim / 2,
                        center[2],
                    ],
                    materialID: entrance.surroundMaterialID
                )
            )
        }

        let stepHeight = descriptor.building.foundationHeight
            / Double(entrance.stepCount)
        for level in 0..<entrance.stepCount {
            let remaining = entrance.stepCount - level
            let run = Double(remaining) * entrance.stepRun
            let stepCenter = [
                base[0] + outward[0] * run / 2,
                stepHeight / 2 + Double(level) * stepHeight,
                base[2] + outward[2] * run / 2,
            ]
            let stepWidth = entrance.width
                + 2.4 + Double(remaining) * 0.6
            let dimensions = horizontal
                ? [stepWidth, stepHeight, run]
                : [run, stepHeight, stepWidth]
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-step-\(level)",
                    dimensions: dimensions,
                    position: stepCenter,
                    materialID: entrance.surroundMaterialID
                )
            )
        }

        let canopyCenter = [
            base[0] + outward[0] * entrance.canopyDepth / 2
                + tangent[0] * entrance.porchLateralOffset,
            base[1] + entrance.height + 2.0,
            base[2] + outward[2] * entrance.canopyDepth / 2
                + tangent[2] * entrance.porchLateralOffset,
        ]
        let porchDeckCenter = [
            base[0] + outward[0] * entrance.canopyDepth / 2
                + tangent[0] * entrance.porchLateralOffset,
            descriptor.building.foundationHeight - 0.35,
            base[2] + outward[2] * entrance.canopyDepth / 2
                + tangent[2] * entrance.porchLateralOffset,
        ]
        let porchDeckDimensions = horizontal
            ? [
                entrance.porchWidth,
                0.7,
                entrance.canopyDepth,
            ]
            : [
                entrance.canopyDepth,
                0.7,
                entrance.porchWidth,
            ]
        scene.rootNode.addChildNode(
            try boxNode(
                name: facade.direction + "-porch-deck",
                dimensions: porchDeckDimensions,
                position: porchDeckCenter,
                materialID: entrance.surroundMaterialID
            )
        )
        let porchRoof = SCNPyramid(
            width: horizontal
                ? entrance.porchWidth
                : entrance.canopyDepth,
            height: 5.2,
            length: horizontal
                ? entrance.canopyDepth
                : entrance.porchWidth
        )
        porchRoof.firstMaterial = try materials.material(
            descriptor.building.roofMaterialID
        )
        let porchRoofNode = SCNNode(geometry: porchRoof)
        porchRoofNode.name = facade.direction + "-porch-roof"
        porchRoofNode.position = SCNVector3(
            canopyCenter[0],
            canopyCenter[1] + 2.6,
            canopyCenter[2]
        )
        porchRoofNode.castsShadow = true
        scene.rootNode.addChildNode(porchRoofNode)

        for side in [-1.0, 1.0] {
            let tangentOffset =
                side
                * (entrance.porchWidth / 2
                    - entrance.porchColumnWidth)
            scene.rootNode.addChildNode(
                try boxNode(
                    name:
                        facade.direction
                        + "-porch-column-\(side)",
                    dimensions: [
                        entrance.porchColumnWidth,
                        entrance.height + 3.5,
                        entrance.porchColumnWidth,
                    ],
                    position: [
                        base[0]
                            + outward[0]
                                * (entrance.canopyDepth - 1.0)
                            + tangent[0]
                                * entrance.porchLateralOffset
                            + tangent[0] * tangentOffset,
                        descriptor.building.foundationHeight
                            + (entrance.height + 3.5) / 2,
                        base[2]
                            + outward[2]
                                * (entrance.canopyDepth - 1.0)
                            + tangent[2]
                                * entrance.porchLateralOffset
                            + tangent[2] * tangentOffset,
                    ],
                    materialID: entrance.surroundMaterialID
                )
            )
        }
        let railHeight = descriptor.building.foundationHeight + 3.4
        let railThickness = max(0.8, entrance.porchColumnWidth * 0.55)
        for side in [-1.0, 1.0] {
            let tangentOffset =
                side
                * (entrance.porchWidth / 2
                    - entrance.porchColumnWidth / 2)
            let railDimensions = horizontal
                ? [
                    railThickness,
                    2.1,
                    max(4, entrance.canopyDepth - 4),
                ]
                : [
                    max(4, entrance.canopyDepth - 4),
                    2.1,
                    railThickness,
                ]
            scene.rootNode.addChildNode(
                try boxNode(
                    name:
                        facade.direction
                        + "-porch-side-rail-\(side)",
                    dimensions: railDimensions,
                    position: [
                        base[0]
                            + outward[0]
                                * (entrance.canopyDepth / 2 + 1)
                            + tangent[0]
                                * entrance.porchLateralOffset
                            + tangent[0] * tangentOffset,
                        railHeight,
                        base[2]
                            + outward[2]
                                * (entrance.canopyDepth / 2 + 1)
                            + tangent[2]
                                * entrance.porchLateralOffset
                            + tangent[2] * tangentOffset,
                    ],
                    materialID: entrance.surroundMaterialID
                )
            )
        }
        if abs(entrance.porchLateralOffset) > 0 {
            let returnSign =
                entrance.porchLateralOffset > 0 ? 1.0 : -1.0
            let returnNormal = [
                tangent[0] * returnSign,
                0.0,
                tangent[2] * returnSign,
            ]
            let returnCenter = [
                porchDeckCenter[0]
                    + returnNormal[0] * entrance.porchWidth / 2,
                descriptor.building.foundationHeight,
                porchDeckCenter[2]
                    + returnNormal[2] * entrance.porchWidth / 2,
            ]
            let postHeight = entrance.height + 1
            for depthFraction in [0.22, 0.78] {
                let depthOffset =
                    (depthFraction - 0.5) * entrance.canopyDepth
                scene.rootNode.addChildNode(
                    try boxNode(
                        name:
                            facade.direction
                            + "-porch-return-post-\(depthFraction)",
                        dimensions: [
                            entrance.porchColumnWidth,
                            postHeight,
                            entrance.porchColumnWidth,
                        ],
                        position: [
                            returnCenter[0] + outward[0] * depthOffset,
                            descriptor.building.foundationHeight
                                + postHeight / 2,
                            returnCenter[2] + outward[2] * depthOffset,
                        ],
                        materialID: entrance.surroundMaterialID
                    )
                )
            }
            let lintelDimensions = horizontal
                ? [
                    entrance.porchColumnWidth,
                    2.2,
                    entrance.canopyDepth * 0.58,
                ]
                : [
                    entrance.canopyDepth * 0.58,
                    2.2,
                    entrance.porchColumnWidth,
                ]
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-porch-return-lintel",
                    dimensions: lintelDimensions,
                    position: [
                        returnCenter[0],
                        descriptor.building.foundationHeight
                            + postHeight - 0.4,
                        returnCenter[2],
                    ],
                    materialID: entrance.surroundMaterialID
                )
            )
            let lanternDimensions = horizontal
                ? [0.9, 4.6, 4.2]
                : [4.2, 4.6, 0.9]
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-porch-return-lantern",
                    dimensions: lanternDimensions,
                    position: [
                        returnCenter[0] + returnNormal[0] * 0.5,
                        descriptor.building.foundationHeight + 10,
                        returnCenter[2] + returnNormal[2] * 0.5,
                    ],
                    materialID: "window-warm"
                )
            )
        }
    }

    private func addIndustrialLoadingBay(
        _ descriptor: SceneDescriptor,
        facade: FacadeDescriptor,
        to scene: SCNScene
    ) throws {
        guard descriptor.family == "industrial" else {
            throw OfflineRendererError.invalid(
                "loading-bay entrance is industrial-only"
            )
        }
        let entrance = descriptor.entrance
        let outward: [Double]
        switch facade.direction {
        case "north": outward = [0, 0, -1]
        case "east": outward = [1, 0, 0]
        case "south": outward = [0, 0, 1]
        case "west": outward = [-1, 0, 0]
        default:
            throw OfflineRendererError.invalid("invalid facade direction")
        }
        let horizontal = facade.direction == "north"
            || facade.direction == "south"
        let tangent = horizontal
            ? [1.0, 0.0, 0.0]
            : [0.0, 0.0, 1.0]
        let base = entrance.baseWorld
        let doorCenter = [
            base[0] + outward[0] * entrance.depth / 2,
            base[1] + entrance.height / 2,
            base[2] + outward[2] * entrance.depth / 2,
        ]
        scene.rootNode.addChildNode(
            try boxNode(
                name: facade.direction + "-loading-bay-door",
                dimensions: horizontal
                    ? [entrance.width, entrance.height, entrance.depth]
                    : [entrance.depth, entrance.height, entrance.width],
                position: doorCenter,
                materialID: entrance.doorMaterialID
            )
        )
        let jambWidth = 1.8
        let surroundDepth = entrance.depth + 1.4
        for side in [-1.0, 1.0] {
            let offset = side * (entrance.width / 2 + jambWidth / 2)
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-loading-bay-jamb-\(side)",
                    dimensions: horizontal
                        ? [jambWidth, entrance.height + 3, surroundDepth]
                        : [surroundDepth, entrance.height + 3, jambWidth],
                    position: [
                        doorCenter[0] + tangent[0] * offset,
                        doorCenter[1] + 0.8,
                        doorCenter[2] + tangent[2] * offset,
                    ],
                    materialID: entrance.surroundMaterialID
                )
            )
        }
        scene.rootNode.addChildNode(
            try boxNode(
                name: facade.direction + "-loading-bay-header",
                dimensions: horizontal
                    ? [entrance.width + 5.4, 2.4, surroundDepth]
                    : [surroundDepth, 2.4, entrance.width + 5.4],
                position: [
                    doorCenter[0],
                    base[1] + entrance.height + 1.2,
                    doorCenter[2],
                ],
                materialID: entrance.surroundMaterialID
            )
        )
        for index in 1...5 {
            let offsetY =
                base[1] + Double(index) * entrance.height / 6
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-loading-bay-slat-\(index)",
                    dimensions: horizontal
                        ? [entrance.width - 1.2, 0.55, entrance.depth + 0.5]
                        : [entrance.depth + 0.5, 0.55, entrance.width - 1.2],
                    position: [
                        doorCenter[0],
                        offsetY,
                        doorCenter[2],
                    ],
                    materialID: entrance.pavilionMaterialID
                )
            )
        }
        let dockDepth = max(6, entrance.stepRun * 4)
        scene.rootNode.addChildNode(
            try boxNode(
                name: facade.direction + "-loading-dock",
                dimensions: horizontal
                    ? [entrance.width + 8, 2.2, dockDepth]
                    : [dockDepth, 2.2, entrance.width + 8],
                position: [
                    base[0] + outward[0] * dockDepth / 2,
                    1.1,
                    base[2] + outward[2] * dockDepth / 2,
                ],
                materialID: descriptor.building.foundationMaterialID
            )
        )
        let canopyCenter = [
            base[0] + outward[0] * entrance.canopyDepth / 2
                + tangent[0] * entrance.porchLateralOffset,
            base[1] + entrance.height + 4.5,
            base[2] + outward[2] * entrance.canopyDepth / 2
                + tangent[2] * entrance.porchLateralOffset,
        ]
        scene.rootNode.addChildNode(
            try boxNode(
                name: facade.direction + "-loading-canopy",
                dimensions: horizontal
                    ? [entrance.porchWidth, 1.6, entrance.canopyDepth]
                    : [entrance.canopyDepth, 1.6, entrance.porchWidth],
                position: canopyCenter,
                materialID: descriptor.building.roofMaterialID
            )
        )
        for side in [-1.0, 1.0] {
            let tangentOffset =
                side * (entrance.porchWidth / 2 - 1.3)
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-loading-bollard-\(side)",
                    dimensions: [1.6, 6.5, 1.6],
                    position: [
                        base[0]
                            + outward[0] * (dockDepth - 1)
                            + tangent[0]
                                * (entrance.porchLateralOffset
                                    + tangentOffset),
                        3.25,
                        base[2]
                            + outward[2] * (dockDepth - 1)
                            + tangent[2]
                                * (entrance.porchLateralOffset
                                    + tangentOffset),
                    ],
                    materialID: "hazard-yellow"
                )
            )
        }
        // source-v01/v02 retained this renderer-created corner return for
        // exact rejection reproduction. Source-v03 replaces it with explicit
        // direction-specific dock-house massing in the scene descriptor.
        if
            descriptor.sourceRevision != "source-v03",
            descriptor.sourceRevision != "source-v04",
            descriptor.sourceRevision != "source-v05",
            abs(entrance.porchLateralOffset) >= 10
        {
            let returnNormal: [Double]
            let returnCenter: [Double]
            switch facade.direction {
            case "north":
                returnNormal = [1, 0, 0]
                returnCenter = [
                    descriptor.building.width / 2 + 2,
                    base[1] + entrance.height * 0.44,
                    -descriptor.building.depth / 2 + 10,
                ]
            case "west":
                returnNormal = [0, 0, 1]
                returnCenter = [
                    -descriptor.building.width / 2 + 10,
                    base[1] + entrance.height * 0.44,
                    descriptor.building.depth / 2 + 2,
                ]
            default:
                let returnSign =
                    entrance.porchLateralOffset > 0 ? 1.0 : -1.0
                returnNormal = [
                    tangent[0] * returnSign,
                    0.0,
                    tangent[2] * returnSign,
                ]
                returnCenter = [
                    canopyCenter[0]
                        + returnNormal[0] * entrance.porchWidth / 2,
                    base[1] + entrance.height * 0.44,
                    canopyCenter[2]
                        + returnNormal[2] * entrance.porchWidth / 2,
                ]
            }
            let returnWidth = min(20, entrance.width * 0.88)
            let returnHeight = entrance.height * 0.82
            let returnFacesXAxis = abs(returnNormal[0]) > 0
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-loading-return-door",
                    dimensions: returnFacesXAxis
                        ? [1.0, returnHeight, returnWidth]
                        : [returnWidth, returnHeight, 1.0],
                    position: [
                        returnCenter[0] + returnNormal[0] * 0.6,
                        returnCenter[1],
                        returnCenter[2] + returnNormal[2] * 0.6,
                    ],
                    materialID: entrance.doorMaterialID
                )
            )
            let returnTangent = returnFacesXAxis
                ? [0.0, 0.0, 1.0]
                : [1.0, 0.0, 0.0]
            for side in [-1.0, 1.0] {
                let offset = side * (returnWidth / 2 + 1.1)
                scene.rootNode.addChildNode(
                    try boxNode(
                        name:
                            facade.direction
                            + "-loading-return-jamb-\(side)",
                        dimensions: returnFacesXAxis
                            ? [2.0, returnHeight + 3, 2.2]
                            : [2.2, returnHeight + 3, 2.0],
                        position: [
                            returnCenter[0]
                                + returnTangent[0] * offset,
                            returnCenter[1] + 0.6,
                            returnCenter[2]
                                + returnTangent[2] * offset,
                        ],
                        materialID: entrance.surroundMaterialID
                    )
                )
            }
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-loading-return-lintel",
                    dimensions: returnFacesXAxis
                        ? [2.0, 2.0, returnWidth + 5]
                        : [returnWidth + 5, 2.0, 2.0],
                    position: [
                        returnCenter[0],
                        returnCenter[1] + returnHeight / 2 + 1,
                        returnCenter[2],
                    ],
                    materialID: entrance.surroundMaterialID
                )
            )
            let returnDockDepth = 8.0
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-loading-return-dock",
                    dimensions: returnFacesXAxis
                        ? [returnDockDepth, 2.2, returnWidth + 8]
                        : [returnWidth + 8, 2.2, returnDockDepth],
                    position: [
                        returnCenter[0]
                            + returnNormal[0] * returnDockDepth / 2,
                        1.1,
                        returnCenter[2]
                            + returnNormal[2] * returnDockDepth / 2,
                    ],
                    materialID: descriptor.building.foundationMaterialID
                )
            )
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-loading-return-canopy",
                    dimensions: returnFacesXAxis
                        ? [8, 1.6, returnWidth + 10]
                        : [returnWidth + 10, 1.6, 8],
                    position: [
                        returnCenter[0] + returnNormal[0] * 3.5,
                        returnCenter[1] + returnHeight / 2 + 4.0,
                        returnCenter[2] + returnNormal[2] * 3.5,
                    ],
                    materialID: descriptor.building.roofMaterialID
                )
            )
            for index in 1...4 {
                scene.rootNode.addChildNode(
                    try boxNode(
                        name:
                            facade.direction
                            + "-loading-return-slat-\(index)",
                        dimensions: returnFacesXAxis
                            ? [1.3, 0.5, returnWidth - 1.0]
                            : [returnWidth - 1.0, 0.5, 1.3],
                        position: [
                            returnCenter[0] + returnNormal[0] * 0.7,
                            returnCenter[1] - returnHeight / 2
                                + Double(index) * returnHeight / 5,
                            returnCenter[2] + returnNormal[2] * 0.7,
                        ],
                        materialID: entrance.pavilionMaterialID
                    )
                )
            }
        }
    }

    private func addDensityEntrance(
        _ descriptor: SceneDescriptor,
        facade: FacadeDescriptor,
        style: String,
        to scene: SCNScene
    ) throws {
        guard [
            "walkup-stoop",
            "courtyard-portal",
            "urban-lobby",
            "shopfront",
            "market-arcade",
            "office-lobby",
            "tower-lobby",
        ].contains(style) else {
            throw OfflineRendererError.invalid(
                "unsupported density entrance style: \(style)"
            )
        }
        let entrance = descriptor.entrance
        let outward: [Double]
        switch facade.direction {
        case "north": outward = [0, 0, -1]
        case "east": outward = [1, 0, 0]
        case "south": outward = [0, 0, 1]
        case "west": outward = [-1, 0, 0]
        default:
            throw OfflineRendererError.invalid("invalid facade direction")
        }
        let horizontal = facade.direction == "north"
            || facade.direction == "south"
        let tangent = horizontal
            ? [1.0, 0.0, 0.0]
            : [0.0, 0.0, 1.0]
        let base = entrance.baseWorld
        let doorCenter = [
            base[0] + outward[0] * entrance.depth / 2,
            base[1] + entrance.height / 2,
            base[2] + outward[2] * entrance.depth / 2,
        ]
        let doorDimensions = horizontal
            ? [entrance.width, entrance.height, entrance.depth]
            : [entrance.depth, entrance.height, entrance.width]
        scene.rootNode.addChildNode(
            try boxNode(
                name: facade.direction + "-" + style + "-door",
                dimensions: doorDimensions,
                position: doorCenter,
                materialID: entrance.doorMaterialID
            )
        )

        let isCommercial = descriptor.family == "commercial"
        let isLargeLobby = [
            "urban-lobby",
            "office-lobby",
            "tower-lobby",
        ].contains(style)
        let portalWidth = entrance.width
            + (isLargeLobby ? 8 : 5)
        let portalHeight = entrance.height
            + (style == "courtyard-portal" || style == "market-arcade" ? 9 : 6)
        let portalDepth = entrance.depth + 1.2
        let sideWidth = isLargeLobby ? 2.2 : 1.5
        for side in [-1.0, 1.0] {
            let offset = side * (portalWidth / 2 - sideWidth / 2)
            let dimensions = horizontal
                ? [sideWidth, portalHeight, portalDepth]
                : [portalDepth, portalHeight, sideWidth]
            let position = [
                doorCenter[0] + tangent[0] * offset,
                base[1] + portalHeight / 2,
                doorCenter[2] + tangent[2] * offset,
            ]
            scene.rootNode.addChildNode(
                try boxNode(
                    name:
                        facade.direction
                        + "-\(style)-portal-side-\(side)",
                    dimensions: dimensions,
                    position: position,
                    materialID: entrance.surroundMaterialID
                )
            )
        }
        let lintelDimensions = horizontal
            ? [portalWidth, 2.2, portalDepth]
            : [portalDepth, 2.2, portalWidth]
        scene.rootNode.addChildNode(
            try boxNode(
                name: facade.direction + "-" + style + "-lintel",
                dimensions: lintelDimensions,
                position: [
                    doorCenter[0],
                    base[1] + portalHeight - 1.1,
                    doorCenter[2],
                ],
                materialID: entrance.surroundMaterialID
            )
        )
        if isCommercial {
            let facadeSpan = horizontal
                ? descriptor.building.width
                : descriptor.building.depth
            let storefrontWidth = max(
                7,
                (facadeSpan - portalWidth - 10) / 2
            )
            let storefrontHeight = min(
                15,
                descriptor.building.floorHeight - 2
            )
            for side in [-1.0, 1.0] {
                let offset = side
                    * (portalWidth / 2 + storefrontWidth / 2 + 2)
                let storefrontCenter = [
                    base[0] + outward[0] * 0.8 + tangent[0] * offset,
                    descriptor.building.foundationHeight
                        + storefrontHeight / 2,
                    base[2] + outward[2] * 0.8 + tangent[2] * offset,
                ]
                scene.rootNode.addChildNode(
                    try boxNode(
                        name:
                            facade.direction
                            + "-\(style)-storefront-\(side)",
                        dimensions: horizontal
                            ? [storefrontWidth, storefrontHeight, 0.8]
                            : [0.8, storefrontHeight, storefrontWidth],
                        position: storefrontCenter,
                        materialID: "window-warm"
                    )
                )
                let mullionOffset = storefrontWidth * 0.22
                for mullionSide in [-1.0, 1.0] {
                    scene.rootNode.addChildNode(
                        try boxNode(
                            name:
                                facade.direction
                                + "-\(style)-storefront-mullion-\(side)-\(mullionSide)",
                            dimensions: horizontal
                                ? [0.7, storefrontHeight + 1.5, 1.0]
                                : [1.0, storefrontHeight + 1.5, 0.7],
                            position: [
                                storefrontCenter[0]
                                    + tangent[0]
                                        * mullionOffset * mullionSide,
                                storefrontCenter[1],
                                storefrontCenter[2]
                                    + tangent[2]
                                        * mullionOffset * mullionSide,
                            ],
                            materialID: entrance.surroundMaterialID
                        )
                    )
                }
            }
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-\(style)-storefront-cornice",
                    dimensions: horizontal
                        ? [facadeSpan - 4, 2.1, 2.2]
                        : [2.2, 2.1, facadeSpan - 4],
                    position: [
                        base[0] + outward[0] * 1.1,
                        descriptor.building.foundationHeight
                            + storefrontHeight + 1.2,
                        base[2] + outward[2] * 1.1,
                    ],
                    materialID: entrance.pavilionMaterialID
                )
            )
        }
        let transomDimensions = horizontal
            ? [entrance.width * 0.82, 3.2, entrance.depth + 1.4]
            : [entrance.depth + 1.4, 3.2, entrance.width * 0.82]
        scene.rootNode.addChildNode(
            try boxNode(
                name: facade.direction + "-" + style + "-transom",
                dimensions: transomDimensions,
                position: [
                    doorCenter[0],
                    base[1] + entrance.height + 2.2,
                    doorCenter[2],
                ],
                materialID: "window-warm"
            )
        )

        let stepHeight = descriptor.building.foundationHeight
            / Double(entrance.stepCount)
        for level in 0..<entrance.stepCount {
            let remaining = entrance.stepCount - level
            let run = Double(remaining) * entrance.stepRun
            let stepCenter = [
                base[0] + outward[0] * run / 2,
                stepHeight / 2 + Double(level) * stepHeight,
                base[2] + outward[2] * run / 2,
            ]
            let stepWidth = entrance.width
                + 3.5 + Double(remaining) * 0.8
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-" + style + "-step-\(level)",
                    dimensions: horizontal
                        ? [stepWidth, stepHeight, run]
                        : [run, stepHeight, stepWidth],
                    position: stepCenter,
                    materialID: entrance.surroundMaterialID
                )
            )
        }

        let canopyCenter = [
            base[0] + outward[0] * entrance.canopyDepth / 2
                + tangent[0] * entrance.porchLateralOffset,
            base[1] + entrance.height + 5.2,
            base[2] + outward[2] * entrance.canopyDepth / 2
                + tangent[2] * entrance.porchLateralOffset,
        ]
        let canopyDimensions = horizontal
            ? [entrance.porchWidth, 1.5, entrance.canopyDepth]
            : [entrance.canopyDepth, 1.5, entrance.porchWidth]
        scene.rootNode.addChildNode(
            try boxNode(
                name: facade.direction + "-" + style + "-canopy",
                dimensions: canopyDimensions,
                position: canopyCenter,
                materialID: descriptor.building.roofMaterialID
            )
        )

        for side in [-1.0, 1.0] {
            let tangentOffset =
                side
                * (entrance.porchWidth / 2
                    - entrance.porchColumnWidth)
            scene.rootNode.addChildNode(
                try boxNode(
                    name:
                        facade.direction
                        + "-\(style)-canopy-column-\(side)",
                    dimensions: [
                        entrance.porchColumnWidth,
                        entrance.height + 4.8,
                        entrance.porchColumnWidth,
                    ],
                    position: [
                        base[0]
                            + outward[0] * (entrance.canopyDepth - 0.8)
                            + tangent[0]
                                * (entrance.porchLateralOffset
                                    + tangentOffset),
                        descriptor.building.foundationHeight
                            + (entrance.height + 4.8) / 2,
                        base[2]
                            + outward[2] * (entrance.canopyDepth - 0.8)
                            + tangent[2]
                                * (entrance.porchLateralOffset
                                    + tangentOffset),
                    ],
                    materialID: entrance.surroundMaterialID
                )
            )
        }

        if abs(entrance.porchLateralOffset) > 0 {
            let returnSign =
                entrance.porchLateralOffset > 0 ? 1.0 : -1.0
            let returnNormal = [
                tangent[0] * returnSign,
                0.0,
                tangent[2] * returnSign,
            ]
            let returnCenter = [
                canopyCenter[0]
                    + returnNormal[0] * entrance.porchWidth / 2,
                descriptor.building.foundationHeight + 7,
                canopyCenter[2]
                    + returnNormal[2] * entrance.porchWidth / 2,
            ]
            scene.rootNode.addChildNode(
                try boxNode(
                    name: facade.direction + "-" + style + "-return-frame",
                    dimensions: horizontal
                        ? [
                            entrance.porchColumnWidth,
                            entrance.height + 6,
                            entrance.canopyDepth * 0.62,
                        ]
                        : [
                            entrance.canopyDepth * 0.62,
                            entrance.height + 6,
                            entrance.porchColumnWidth,
                        ],
                    position: returnCenter,
                    materialID: entrance.surroundMaterialID
                )
            )
            let lanternDimensions = horizontal
                ? [0.9, 5.4, 5.0]
                : [5.0, 5.4, 0.9]
            scene.rootNode.addChildNode(
                try boxNode(
                    name:
                        facade.direction
                        + "-" + style + "-return-lantern",
                    dimensions: lanternDimensions,
                    position: [
                        returnCenter[0] + returnNormal[0] * 0.6,
                        descriptor.building.foundationHeight + 10,
                        returnCenter[2] + returnNormal[2] * 0.6,
                    ],
                    materialID: "window-warm"
                )
            )

            // A hidden road-facing plane cannot rely on a canopy return alone
            // at game scale. The independently authored lateral offset elects
            // a grounded secondary door plane on the visible corner return.
            // North returns face east; west returns face south. No sibling
            // scene or raster transform participates in this geometry.
            let returnDoorWidth = min(8.0, entrance.width * 0.72)
            let returnDoorHeight = min(11.5, entrance.height * 0.82)
            let returnDoorDepth = 1.0
            let returnDoorCenter = [
                returnCenter[0] + returnNormal[0] * 0.7,
                descriptor.building.foundationHeight
                    + returnDoorHeight / 2,
                returnCenter[2] + returnNormal[2] * 0.7,
            ]
            let returnDoorDimensions = horizontal
                ? [returnDoorDepth, returnDoorHeight, returnDoorWidth]
                : [returnDoorWidth, returnDoorHeight, returnDoorDepth]
            scene.rootNode.addChildNode(
                try boxNode(
                    name:
                        facade.direction
                        + "-" + style + "-return-door",
                    dimensions: returnDoorDimensions,
                    position: returnDoorCenter,
                    materialID: entrance.doorMaterialID
                )
            )
            let returnTangent = outward
            let returnSideWidth = 1.35
            for side in [-1.0, 1.0] {
                let offset =
                    side
                    * (returnDoorWidth / 2 + returnSideWidth / 2)
                scene.rootNode.addChildNode(
                    try boxNode(
                        name:
                            facade.direction
                            + "-" + style
                            + "-return-door-side-\(side)",
                        dimensions: horizontal
                            ? [
                                returnDoorDepth + 0.5,
                                returnDoorHeight + 2.5,
                                returnSideWidth,
                            ]
                            : [
                                returnSideWidth,
                                returnDoorHeight + 2.5,
                                returnDoorDepth + 0.5,
                            ],
                        position: [
                            returnDoorCenter[0]
                                + returnTangent[0] * offset,
                            returnDoorCenter[1] + 0.8,
                            returnDoorCenter[2]
                                + returnTangent[2] * offset,
                        ],
                        materialID: entrance.surroundMaterialID
                    )
                )
            }
            scene.rootNode.addChildNode(
                try boxNode(
                    name:
                        facade.direction
                        + "-" + style + "-return-door-lintel",
                    dimensions: horizontal
                        ? [
                            returnDoorDepth + 0.5,
                            1.5,
                            returnDoorWidth + 4.0,
                        ]
                        : [
                            returnDoorWidth + 4.0,
                            1.5,
                            returnDoorDepth + 0.5,
                        ],
                    position: [
                        returnDoorCenter[0],
                        descriptor.building.foundationHeight
                            + returnDoorHeight + 1.2,
                        returnDoorCenter[2],
                    ],
                    materialID: entrance.surroundMaterialID
                )
            )
            scene.rootNode.addChildNode(
                try boxNode(
                    name:
                        facade.direction
                        + "-" + style + "-return-stoop",
                    dimensions: horizontal
                        ? [4.5, 0.8, returnDoorWidth + 5.0]
                        : [returnDoorWidth + 5.0, 0.8, 4.5],
                    position: [
                        returnDoorCenter[0] + returnNormal[0] * 2.0,
                        descriptor.building.foundationHeight - 0.4,
                        returnDoorCenter[2] + returnNormal[2] * 2.0,
                    ],
                    materialID: entrance.surroundMaterialID
                )
            )
        }
    }

    private func addProp(
        _ prop: PropDescriptor,
        to scene: SCNScene
    ) throws {
        let material = try materials.material(prop.materialID)
        switch prop.kind {
        case "shrub-cluster":
            let offsets: [(Double, Double, Double)] = [
                (-0.24, 0.0, -0.16),
                (0.2, 0.1, -0.1),
                (-0.05, 0.18, 0.2),
                (0.28, -0.05, 0.22),
            ]
            for (index, offset) in offsets.enumerated() {
                let sphere = SCNSphere(
                    radius: CGFloat(
                        min(prop.dimensions[0], prop.dimensions[2])
                            * (0.24 + Double(index % 2) * 0.04)
                    )
                )
                sphere.segmentCount = 16
                sphere.firstMaterial = material
                let node = SCNNode(geometry: sphere)
                node.name = prop.id + "-\(index)"
                node.position = SCNVector3(
                    prop.positionWorld[0]
                        + offset.0 * prop.dimensions[0],
                    prop.positionWorld[1]
                        + offset.1 * prop.dimensions[1],
                    prop.positionWorld[2]
                        + offset.2 * prop.dimensions[2]
                )
                scene.rootNode.addChildNode(node)
            }
        case "flower-bed":
            for index in 0..<7 {
                let sphere = SCNSphere(radius: 0.7)
                sphere.segmentCount = 12
                sphere.firstMaterial = material
                let node = SCNNode(geometry: sphere)
                node.name = prop.id + "-\(index)"
                let t = Double(index) / 6
                node.position = SCNVector3(
                    prop.positionWorld[0]
                        + (t - 0.5) * prop.dimensions[0],
                    prop.positionWorld[1] + Double(index % 2) * 0.35,
                    prop.positionWorld[2]
                        + (Double((index * 3) % 5) / 4 - 0.5)
                            * prop.dimensions[2]
                )
                scene.rootNode.addChildNode(node)
            }
        case "domestic-bay-window":
            let dimensions = prop.dimensions
            guard dimensions.count == 3 else {
                throw OfflineRendererError.invalid(
                    "domestic bay dimensions must contain width, height, depth"
                )
            }
            scene.rootNode.addChildNode(
                try boxNode(
                    name: prop.id + "-masonry",
                    dimensions: dimensions,
                    position: prop.positionWorld,
                    materialID: prop.materialID
                )
            )
            let facesXAxis =
                abs(prop.positionWorld[0]) > abs(prop.positionWorld[2])
            let sign = facesXAxis
                ? (prop.positionWorld[0] >= 0 ? 1.0 : -1.0)
                : (prop.positionWorld[2] >= 0 ? 1.0 : -1.0)
            let windowDimensions = facesXAxis
                ? [0.8, dimensions[1] * 0.58, dimensions[2] * 0.64]
                : [dimensions[0] * 0.64, dimensions[1] * 0.58, 0.8]
            let windowPosition = [
                prop.positionWorld[0]
                    + (facesXAxis ? sign * dimensions[0] / 2 : 0),
                prop.positionWorld[1] + 1,
                prop.positionWorld[2]
                    + (facesXAxis ? 0 : sign * dimensions[2] / 2),
            ]
            scene.rootNode.addChildNode(
                try boxNode(
                    name: prop.id + "-window",
                    dimensions: windowDimensions,
                    position: windowPosition,
                    materialID: "window-warm"
                )
            )
            let bayRoof = SCNPyramid(
                width: dimensions[0] + 2,
                height: 4,
                length: dimensions[2] + 2
            )
            bayRoof.firstMaterial = try materials.material(
                "slate-charcoal"
            )
            let bayRoofNode = SCNNode(geometry: bayRoof)
            bayRoofNode.name = prop.id + "-roof"
            bayRoofNode.position = SCNVector3(
                prop.positionWorld[0],
                prop.positionWorld[1] + dimensions[1] / 2 + 2,
                prop.positionWorld[2]
            )
            bayRoofNode.castsShadow = true
            scene.rootNode.addChildNode(bayRoofNode)
        case "balcony-stack":
            guard prop.dimensions.count == 3 else {
                throw OfflineRendererError.invalid(
                    "balcony stack dimensions must contain width, height, depth"
                )
            }
            let facesXAxis =
                abs(prop.positionWorld[0]) > abs(prop.positionWorld[2])
            let levelCount = max(2, Int((prop.dimensions[1] / 11).rounded()))
            let levelSpacing = prop.dimensions[1] / Double(levelCount)
            for level in 0..<levelCount {
                let y =
                    prop.positionWorld[1]
                    - prop.dimensions[1] / 2
                    + Double(level) * levelSpacing
                    + 1
                let slabDimensions = facesXAxis
                    ? [prop.dimensions[2], 0.8, prop.dimensions[0]]
                    : [prop.dimensions[0], 0.8, prop.dimensions[2]]
                scene.rootNode.addChildNode(
                    try boxNode(
                        name: prop.id + "-slab-\(level)",
                        dimensions: slabDimensions,
                        position: [
                            prop.positionWorld[0],
                            y,
                            prop.positionWorld[2],
                        ],
                        materialID: prop.materialID
                    )
                )
                let railDimensions = facesXAxis
                    ? [0.8, 3.4, prop.dimensions[0]]
                    : [prop.dimensions[0], 3.4, 0.8]
                scene.rootNode.addChildNode(
                    try boxNode(
                        name: prop.id + "-rail-\(level)",
                        dimensions: railDimensions,
                        position: [
                            prop.positionWorld[0],
                            y + 2.0,
                            prop.positionWorld[2],
                        ],
                        materialID: "limestone-warm"
                    )
                )
            }
        case "roof-pavilion":
            guard prop.dimensions.count == 3 else {
                throw OfflineRendererError.invalid(
                    "roof pavilion dimensions must contain width, height, depth"
                )
            }
            scene.rootNode.addChildNode(
                try boxNode(
                    name: prop.id + "-mass",
                    dimensions: prop.dimensions,
                    position: prop.positionWorld,
                    materialID: prop.materialID
                )
            )
            let pavilionRoof = SCNPyramid(
                width: prop.dimensions[0] + 2,
                height: 4,
                length: prop.dimensions[2] + 2
            )
            pavilionRoof.firstMaterial = try materials.material(
                "roof-copper"
            )
            let pavilionRoofNode = SCNNode(geometry: pavilionRoof)
            pavilionRoofNode.name = prop.id + "-roof"
            pavilionRoofNode.position = SCNVector3(
                prop.positionWorld[0],
                prop.positionWorld[1] + prop.dimensions[1] / 2 + 2,
                prop.positionWorld[2]
            )
            pavilionRoofNode.castsShadow = true
            scene.rootNode.addChildNode(pavilionRoofNode)
        case "rooftop-hvac":
            guard prop.dimensions.count == 3 else {
                throw OfflineRendererError.invalid(
                    "rooftop HVAC dimensions must contain width, height, depth"
                )
            }
            scene.rootNode.addChildNode(
                try boxNode(
                    name: prop.id + "-cabinet",
                    dimensions: prop.dimensions,
                    position: prop.positionWorld,
                    materialID: prop.materialID
                )
            )
            scene.rootNode.addChildNode(
                try boxNode(
                    name: prop.id + "-cap",
                    dimensions: [
                        prop.dimensions[0] + 1.8,
                        0.9,
                        prop.dimensions[2] + 1.8,
                    ],
                    position: [
                        prop.positionWorld[0],
                        prop.positionWorld[1]
                            + prop.dimensions[1] / 2 + 0.35,
                        prop.positionWorld[2],
                    ],
                    materialID: "slate-charcoal"
                )
            )
            for offset in [-0.25, 0.0, 0.25] {
                scene.rootNode.addChildNode(
                    try boxNode(
                        name: prop.id + "-louver-\(offset)",
                        dimensions: [
                            prop.dimensions[0] * 0.68,
                            0.55,
                            0.7,
                        ],
                        position: [
                            prop.positionWorld[0],
                            prop.positionWorld[1]
                                + offset * prop.dimensions[1],
                            prop.positionWorld[2]
                                + prop.dimensions[2] / 2 + 0.2,
                        ],
                        materialID: "slate-charcoal"
                    )
                )
            }
        case "exhaust-stack":
            guard prop.dimensions.count == 3 else {
                throw OfflineRendererError.invalid(
                    "exhaust stack dimensions must contain diameter, height, diameter"
                )
            }
            let diameter = min(prop.dimensions[0], prop.dimensions[2])
            let stack = SCNCylinder(
                radius: CGFloat(diameter / 2),
                height: CGFloat(prop.dimensions[1])
            )
            stack.radialSegmentCount = 24
            stack.firstMaterial = material
            let stackNode = SCNNode(geometry: stack)
            stackNode.name = prop.id + "-stack"
            stackNode.position = SCNVector3(
                prop.positionWorld[0],
                prop.positionWorld[1],
                prop.positionWorld[2]
            )
            stackNode.castsShadow = true
            scene.rootNode.addChildNode(stackNode)
            let cap = SCNCylinder(
                radius: CGFloat(diameter * 0.66),
                height: 1.1
            )
            cap.radialSegmentCount = 24
            cap.firstMaterial = try materials.material("slate-charcoal")
            let capNode = SCNNode(geometry: cap)
            capNode.name = prop.id + "-cap"
            capNode.position = SCNVector3(
                prop.positionWorld[0],
                prop.positionWorld[1] + prop.dimensions[1] / 2 + 0.55,
                prop.positionWorld[2]
            )
            capNode.castsShadow = true
            scene.rootNode.addChildNode(capNode)
        case "service-tank":
            guard prop.dimensions.count == 3 else {
                throw OfflineRendererError.invalid(
                    "service tank dimensions must contain diameter, height, diameter"
                )
            }
            let diameter = min(prop.dimensions[0], prop.dimensions[2])
            let tank = SCNCylinder(
                radius: CGFloat(diameter / 2),
                height: CGFloat(prop.dimensions[1])
            )
            tank.radialSegmentCount = 24
            tank.firstMaterial = material
            let tankNode = SCNNode(geometry: tank)
            tankNode.name = prop.id + "-tank"
            tankNode.position = SCNVector3(
                prop.positionWorld[0],
                prop.positionWorld[1],
                prop.positionWorld[2]
            )
            tankNode.castsShadow = true
            scene.rootNode.addChildNode(tankNode)
        default:
            throw OfflineRendererError.invalid(
                "unsupported prop kind: \(prop.kind)"
            )
        }
    }

    private func addLights(
        _ descriptor: SceneDescriptor,
        to scene: SCNScene
    ) throws {
        let key = SCNLight()
        key.type = .directional
        key.intensity = descriptor.light.keyIntensity
        key.color = try color(descriptor.light.keyColorRGBA)
        key.castsShadow = true
        key.shadowMode = .deferred
        key.shadowSampleCount = 16
        key.shadowRadius = 3
        key.shadowMapSize = CGSize(width: 2048, height: 2048)
        let keyNode = SCNNode()
        keyNode.name = "northwest-key"
        keyNode.light = key
        keyNode.position = SCNVector3(
            descriptor.light.keyOrigin[0],
            descriptor.light.keyOrigin[1],
            descriptor.light.keyOrigin[2]
        )
        keyNode.look(
            at: SCNVector3Zero,
            up: SCNVector3(0, 1, 0),
            localFront: SCNVector3(0, 0, -1)
        )
        scene.rootNode.addChildNode(keyNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = descriptor.light.ambientIntensity * 1000
        ambient.color = try color(descriptor.light.ambientColorRGBA)
        let ambientNode = SCNNode()
        ambientNode.name = "ambient-fill"
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
    }

    private func addCamera(
        _ descriptor: SceneDescriptor,
        to scene: SCNScene
    ) {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = descriptor.camera.orthographicScale
        camera.zNear = 0.1
        camera.zFar = 1000
        camera.wantsHDR = false
        camera.wantsExposureAdaptation = false
        camera.projectionDirection = .vertical
        let node = SCNNode()
        node.name = "contract-camera"
        node.camera = camera
        node.position = SCNVector3(
            descriptor.camera.positionWorld[0],
            descriptor.camera.positionWorld[1],
            descriptor.camera.positionWorld[2]
        )
        node.look(
            at: SCNVector3(
                descriptor.camera.targetWorld[0],
                descriptor.camera.targetWorld[1],
                descriptor.camera.targetWorld[2]
            ),
            up: SCNVector3(0, 1, 0),
            localFront: SCNVector3(0, 0, -1)
        )
        scene.rootNode.addChildNode(node)
    }
}

final class NativeSourceRenderer: OfflineSourceRendering {
    private let renderer: SCNRenderer
    private let antialiasingMode: SCNAntialiasingMode
    private let linearOversamplingFactor: Int

    init(
        renderer: SCNRenderer,
        antialiasingMode: SCNAntialiasingMode,
        linearOversamplingFactor: Int
    ) {
        self.renderer = renderer
        self.antialiasingMode = antialiasingMode
        self.linearOversamplingFactor = linearOversamplingFactor
    }

    func renderSource(
        scene: SCNScene,
        descriptor: SceneDescriptor
    ) throws -> CGImage {
        // SceneKit can otherwise expose a process-dependent first snapshot:
        // descriptor nodes exist, but their presentation tree or prepared
        // material state is incomplete. Flush authored transactions and hold
        // the offline scene at one fixed time before synchronous preparation.
        SCNTransaction.flush()
        scene.isPaused = true
        renderer.scene = scene
        renderer.sceneTime = 0
        guard let camera = scene.rootNode.childNode(
            withName: "contract-camera",
            recursively: false
        ) else {
            throw OfflineRendererError.rendering("contract camera missing")
        }
        renderer.pointOfView = camera
        renderer.isJitteringEnabled = false
        renderer.autoenablesDefaultLighting = false
        guard renderer.prepare(
            scene,
            shouldAbortBlock: nil
        ) else {
            throw OfflineRendererError.rendering(
                "SceneKit could not prepare the complete scene graph"
            )
        }
        let scale = linearOversamplingFactor
        let size = CGSize(
            width: descriptor.camera.renderViewportPixels[0] * scale,
            height: descriptor.camera.renderViewportPixels[1] * scale
        )
        // The first two snapshots are explicit native-pipeline warmups. They
        // force camera/frustum state, the complete node presentation tree,
        // and prepared materials through the same fixed frame without making
        // either warmup a source-art authority.
        _ = renderer.snapshot(
            atTime: 0,
            with: size,
            antialiasingMode: antialiasingMode
        )
        _ = renderer.snapshot(
            atTime: 0,
            with: size,
            antialiasingMode: antialiasingMode
        )
        let snapshot = renderer.snapshot(
            atTime: 0,
            with: size,
            antialiasingMode: antialiasingMode
        )
        if let cgImage = snapshot.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) {
            return cgImage
        }
        if
            let tiffData = snapshot.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let cgImage = bitmap.cgImage
        {
            return cgImage
        }
        throw OfflineRendererError.rendering(
            "SceneKit snapshot could not be decoded as a CGImage"
        )
    }
}

final class NativeSourceCompositor: OfflineSourceCompositing {
    private let sampling: EffectiveSamplingContract
    private let stageTraceCoordinate: [Int]?
    private let ciContext: CIContext
    private(set) var prequantizedImage: CGImage?
    private(set) var prequantizedRGBA: [UInt8]?
    private(set) var quantizedBeforeMajorityRGBA: [UInt8]?
    private(set) var postMajorityRGBA: [UInt8]?
    private(set) var postQuantizationMutations:
        [PixelCanonicalizationMutation] = []
    private(set) var postQuantizationEvaluations:
        [PixelCanonicalizationEvaluation] = []

    init(
        sampling: EffectiveSamplingContract,
        stageTraceCoordinate: [Int]? = nil
    ) {
        self.sampling = sampling
        self.stageTraceCoordinate = stageTraceCoordinate
        ciContext = CIContext(options: [
            .useSoftwareRenderer: sampling.ciUseSoftwareRenderer,
            .cacheIntermediates: sampling.ciCacheIntermediates,
            .workingColorSpace: CGColorSpace(
                name: CGColorSpace.extendedSRGB
            )!,
            .outputColorSpace: CGColorSpace(
                name: CGColorSpace.sRGB
            )!,
        ])
    }

    func compositeRegisteredSource(
        renderedImage: CGImage,
        descriptor: SceneDescriptor
    ) throws -> CGImage {
        let scale = CGFloat(sampling.downsampleScale)
        let input = CIImage(cgImage: renderedImage)
        guard let filter = CIFilter(name: sampling.downsampleFilter) else {
            throw OfflineRendererError.rendering(
                "CILanczosScaleTransform unavailable"
            )
        }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(
            sampling.downsampleAspectRatio,
            forKey: kCIInputAspectRatioKey
        )
        guard let downsampled = filter.outputImage else {
            throw OfflineRendererError.rendering("downsample failed")
        }
        let width = descriptor.camera.renderViewportPixels[0]
        let height = descriptor.camera.renderViewportPixels[1]
        guard let source = ciContext.createCGImage(
            downsampled,
            from: CGRect(x: 0, y: 0, width: width, height: height)
        ) else {
            throw OfflineRendererError.rendering(
                "Core Image could not create downsampled source"
            )
        }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw OfflineRendererError.rendering(
                "could not allocate source compositor"
            )
        }
        context.setFillColor(
            NSColor(
                colorSpace: .sRGB,
                components: [1, 0, 1, 1],
                count: 4
            ).cgColor
        )
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        drawShadow(descriptor, in: context, canvasHeight: CGFloat(height))

        let verticalOffset = descriptor.camera.postProjectionOffsetPixels[1]
        context.interpolationQuality = .high
        context.draw(
            source,
            in: CGRect(
                x: descriptor.camera.postProjectionOffsetPixels[0],
                y: -verticalOffset,
                width: Double(width),
                height: Double(height)
            )
        )
        guard let composited = context.makeImage() else {
            throw OfflineRendererError.rendering(
                "could not create registered source"
            )
        }
        prequantizedImage = composited
        return try deterministicallyQuantized(composited)
    }

    private func deterministicallyQuantized(
        _ image: CGImage
    ) throws -> CGImage {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        try bytes.withUnsafeMutableBytes { storage in
            guard let context = CGContext(
                data: storage.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo:
                    CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                throw OfflineRendererError.rendering(
                    "could not allocate deterministic quantizer"
                )
            }
            context.interpolationQuality = .none
            context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: width, height: height)
            )
        }
        let immutablePrequantizedBytes = bytes
        if stageTraceCoordinate != nil {
            prequantizedRGBA = immutablePrequantizedBytes
        }
        bytes.withUnsafeMutableBytes { storage in
            // SceneKit's Metal snapshot can alternate a shaded sample across
            // an exact floor-bucket boundary in otherwise identical process
            // invocations. Shift the existing midpoint palette boundary by
            // eight values so the observed 191/192 pair converges while the
            // established 16,48,...,240 palette remains intact for the
            // deterministic normalizer's edge-despill behavior.
            let step = sampling.quantizerStep
            let midpointOffset = sampling.quantizerMidpointOffset
            for pixel in stride(from: 0, to: storage.count, by: 4) {
                if
                    storage[pixel] == sampling.chromaBypassRGBA[0],
                    storage[pixel + 1] == sampling.chromaBypassRGBA[1],
                    storage[pixel + 2] == sampling.chromaBypassRGBA[2],
                    storage[pixel + 3] == sampling.chromaBypassRGBA[3]
                {
                    continue
                }
                for channel in 0..<3 {
                    let value = Int(storage[pixel + channel])
                    let quantized = min(
                        255,
                        ((value + midpointOffset) / step) * step + step / 2
                    )
                    storage[pixel + channel] = UInt8(quantized)
                }
            }
        }
        if stageTraceCoordinate != nil {
            quantizedBeforeMajorityRGBA = bytes
        }
        if let repair = sampling.postQuantizationCanonicalizer {
            let result = try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: bytes,
                prequantizedRGBA: immutablePrequantizedBytes,
                width: width,
                height: height,
                contract: repair,
                traceCoordinates: stageTraceCoordinate.map { [$0] } ?? []
            )
            bytes = result.rgba
            postQuantizationMutations = result.mutations
            postQuantizationEvaluations = result.evaluations
        }
        if stageTraceCoordinate != nil {
            postMajorityRGBA = bytes
        }
        return try bytes.withUnsafeMutableBytes { storage in
            guard let context = CGContext(
                data: storage.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo:
                    CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ), let output = context.makeImage()
            else {
                throw OfflineRendererError.rendering(
                    "could not create deterministic source"
                )
            }
            return output
        }
    }

    private func drawShadow(
        _ descriptor: SceneDescriptor,
        in context: CGContext,
        canvasHeight: CGFloat
    ) {
        context.saveGState()
        context.translateBy(x: 0, y: canvasHeight)
        context.scaleBy(x: 1, y: -1)
        let path = CGMutablePath()
        let projected = descriptor.registration.contactPolygonWorld.map {
            worldPoint in
            CGPoint(
                x: 768 + (worldPoint[0] - worldPoint[1]) * 256 / 72,
                y: 768 + (worldPoint[0] + worldPoint[1]) * 128 / 72
            )
        }
        let shadowScale = 28.0
        let offset = CGPoint(
            x: descriptor.light.shadowVectorSource[0] * shadowScale,
            y: descriptor.light.shadowVectorSource[1] * shadowScale
        )
        path.move(
            to: CGPoint(
                x: projected[0].x + offset.x,
                y: projected[0].y + offset.y
            )
        )
        for point in projected.dropFirst() {
            path.addLine(
                to: CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            )
        }
        path.closeSubpath()
        context.setShadow(
            offset: .zero,
            blur: descriptor.light.shadowBlurSourcePixels,
            color: NSColor.black.withAlphaComponent(
                descriptor.light.shadowOpacity
            ).cgColor
        )
        context.setFillColor(
            NSColor.black.withAlphaComponent(0.12).cgColor
        )
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }
}

func validatedRenderedNodeBounds(
    _ scene: SCNScene,
    descriptor: SceneDescriptor
) throws -> [String: Any] {
    let bounds = scene.rootNode.boundingBox
    let minimum = bounds.min
    let maximum = bounds.max
    guard
        maximum.x > minimum.x,
        maximum.y > minimum.y,
        maximum.z > minimum.z
    else {
        throw OfflineRendererError.rendering(
            "complete rendered-node bounds unavailable"
        )
    }
    let halfWidth = descriptor.building.width / 2
    let halfDepth = descriptor.building.depth / 2
    let minimumRequiredHeight =
        descriptor.building.foundationHeight
        + descriptor.building.wallHeight
    let complete =
        Double(minimum.x) <= -halfWidth
        && Double(maximum.x) >= halfWidth
        && Double(minimum.z) <= -halfDepth
        && Double(maximum.z) >= halfDepth
        && Double(minimum.y) <= 0
        && Double(maximum.y) >= minimumRequiredHeight
    guard complete else {
        throw OfflineRendererError.rendering(
            "rendered-node bounds do not contain the complete building volume"
        )
    }
    return [
        "minimumWorld": [
            Double(minimum.x),
            Double(minimum.y),
            Double(minimum.z),
        ],
        "maximumWorld": [
            Double(maximum.x),
            Double(maximum.y),
            Double(maximum.z),
        ],
        "requiredFootprintHalfExtents": [halfWidth, halfDepth],
        "minimumRequiredHeight": minimumRequiredHeight,
        "completeBuildingVolumePassed": true,
    ]
}

func validatedRawOccupancy(
    _ image: CGImage
) throws -> [String: Any] {
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let created = bytes.withUnsafeMutableBytes { storage -> Bool in
        guard let context = CGContext(
            data: storage.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return false
        }
        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
        return true
    }
    guard created else {
        throw OfflineRendererError.rendering(
            "could not inspect raw occupied area"
        )
    }

    var occupiedPixelCount = 0
    var minimumX = width
    var minimumY = height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<height {
        for x in 0..<width {
            let index = (y * width + x) * 4
            let chroma =
                bytes[index] == 255
                && bytes[index + 1] == 0
                && bytes[index + 2] == 255
                && bytes[index + 3] == 255
            if !chroma {
                occupiedPixelCount += 1
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
            }
        }
    }
    let occupiedWidth = maximumX >= 0 ? maximumX - minimumX + 1 : 0
    let occupiedHeight = maximumY >= 0 ? maximumY - minimumY + 1 : 0
    let passed =
        occupiedPixelCount >= 50_000
        && occupiedWidth >= 400
        && occupiedHeight >= 260
    guard passed else {
        throw OfflineRendererError.rendering(
            "raw occupied area cannot contain a complete building, footprint, and shadow: pixels=\(occupiedPixelCount), bounds=\(occupiedWidth)x\(occupiedHeight), required=50000/400x260"
        )
    }
    return [
        "nonChromaPixelCount": occupiedPixelCount,
        "nonChromaBounds": [
            minimumX,
            minimumY,
            maximumX + 1,
            maximumY + 1,
        ],
        "minimumNonChromaPixelCount": 50_000,
        "minimumBoundsPixels": [400, 260],
        "completeOccupiedAreaPassed": true,
    ]
}

func writeImageIOPNG(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw OfflineRendererError.rendering(
            "could not create PNG destination"
        )
    }
    let properties: [CFString: Any] = [
        kCGImagePropertyPNGDictionary: [
            kCGImagePropertyPNGInterlaceType: 0,
        ],
        kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
        kCGImagePropertyDepth: 8,
    ]
    CGImageDestinationAddImage(
        destination,
        image,
        properties as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
        throw OfflineRendererError.rendering("PNG finalization failed")
    }
}

func writePNG(
    _ image: CGImage,
    to url: URL,
    diagnosticIntermediateURL: URL? = nil,
    diagnosticRepositoryRoot: URL? = nil,
    diagnosticTarget: [Int]? = nil
) throws -> RendererPNGWriteDiagnostics? {
    let intermediateURL =
        diagnosticIntermediateURL
        ?? url.deletingLastPathComponent()
            .appendingPathComponent(
                "." + url.lastPathComponent + ".imageio-intermediate.png"
            )
    if
        diagnosticIntermediateURL != nil,
        FileManager.default.fileExists(atPath: intermediateURL.path)
    {
        throw OfflineRendererError.invalid(
            "diagnostic ImageIO intermediate already exists: \(intermediateURL.path)"
        )
    }
    if FileManager.default.fileExists(atPath: intermediateURL.path) {
        try FileManager.default.removeItem(at: intermediateURL)
    }
    let removeIntermediateAfterWrite = diagnosticIntermediateURL == nil
    defer {
        if removeIntermediateAfterWrite {
            try? FileManager.default.removeItem(at: intermediateURL)
        }
    }
    try writeImageIOPNG(image, to: intermediateURL)

    // `/usr/bin/sips` is a macOS-native ImageIO front end. Re-encoding the
    // already canonical pixels through it removes the direction-dependent PNG
    // presentation seen in the review decoder while preserving exact pixels.
    // The fixed host/toolchain makes this final byte encoding deterministic.
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = [
        "-s",
        "format",
        "png",
        intermediateURL.path,
        "--out",
        url.path,
    ]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw OfflineRendererError.rendering(
            "native PNG canonicalization failed"
        )
    }
    guard
        let diagnosticRepositoryRoot,
        let diagnosticTarget
    else {
        return nil
    }
    return RendererPNGWriteDiagnostics(
        imageIOPreSips: try rendererPNGStageRecord(
            stage: "imageio-pre-sips-decoded",
            url: intermediateURL,
            repositoryRoot: diagnosticRepositoryRoot,
            target: diagnosticTarget
        ),
        finalSips: try rendererPNGStageRecord(
            stage: "final-sips-decoded",
            url: url,
            repositoryRoot: diagnosticRepositoryRoot,
            target: diagnosticTarget
        )
    )
}

#if !PLAY027_SCENE_PREP_DIAGNOSTIC
@main
enum OfflineSceneRendererMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try rendererArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let sceneURL = URL(
            fileURLWithPath: try rendererArgument("--scene", in: arguments)
        ).standardizedFileURL
        let materialsURL = URL(
            fileURLWithPath: try rendererArgument(
                "--materials",
                in: arguments
            )
        ).standardizedFileURL
        let outputURL = URL(
            fileURLWithPath: try rendererArgument("--output", in: arguments)
        ).standardizedFileURL
        let recordURL = URL(
            fileURLWithPath: try rendererArgument("--record", in: arguments)
        ).standardizedFileURL
        let backendCapabilityRecordURL = rendererOptionalArgument(
            "--backend-capability-record",
            in: arguments
        ).map {
            URL(fileURLWithPath: $0).standardizedFileURL
        }
        let sourceCommit = try rendererArgument(
            "--renderer-source-commit",
            in: arguments
        )
        let diagnosticPrequantizedOutput = rendererOptionalArgument(
            "--diagnostic-prequantized-output",
            in: arguments
        ).map {
            URL(fileURLWithPath: $0).standardizedFileURL
        }
        let diagnosticStageCaptureDirectory = rendererOptionalArgument(
            "--diagnostic-stage-capture-dir",
            in: arguments
        ).map {
            URL(fileURLWithPath: $0).standardizedFileURL
        }
        let diagnosticStageCoordinateRaw = rendererOptionalArgument(
            "--diagnostic-stage-coordinate",
            in: arguments
        )
        let diagnosticStageCoordinate: [Int]? = {
            guard let diagnosticStageCoordinateRaw else {
                return nil
            }
            let components = diagnosticStageCoordinateRaw.split(
                separator: ",",
                omittingEmptySubsequences: false
            )
            guard
                components.count == 2,
                let x = Int(components[0]),
                let y = Int(components[1])
            else {
                return nil
            }
            return [x, y]
        }()
        let diagnosticAntialiasingRaw = rendererOptionalArgument(
            "--diagnostic-antialiasing",
            in: arguments
        )
        let diagnosticSceneShadowsRaw = rendererOptionalArgument(
            "--diagnostic-scene-shadows",
            in: arguments
        )
        let diagnosticMaterialLightingRaw = rendererOptionalArgument(
            "--diagnostic-material-lighting",
            in: arguments
        )
        let diagnosticContractID = rendererOptionalArgument(
            "--diagnostic-contract",
            in: arguments
        )
        let diagnosticStageContractID = rendererOptionalArgument(
            "--diagnostic-stage-contract",
            in: arguments
        )
        if let diagnosticStageContractID {
            guard [
                IndustrialL2V5EastStageCaptureContract.contractID,
                IndustrialL2V5EastSceneKitLanczosContract.contractID,
            ].contains(diagnosticStageContractID) else {
                throw OfflineRendererError.invalid(
                    "unknown diagnostic stage contract"
                )
            }
        }
        guard
            diagnosticAntialiasingRaw == nil
                || DiagnosticAntialiasing(
                    rawValue: diagnosticAntialiasingRaw!
                ) != nil,
            let diagnosticSceneShadows = DiagnosticSceneShadows(
                rawValue: diagnosticSceneShadowsRaw ?? "current"
            ),
            let diagnosticMaterialLighting = DiagnosticMaterialLighting(
                rawValue: diagnosticMaterialLightingRaw ?? "current"
            )
        else {
            throw OfflineRendererError.arguments
        }
        let diagnosticConfiguration = RendererDiagnosticConfiguration(
            antialiasingOverride: diagnosticAntialiasingRaw.flatMap(
                DiagnosticAntialiasing.init(rawValue:)
            ),
            sceneShadows: diagnosticSceneShadows,
            materialLighting: diagnosticMaterialLighting
        )
        if let backendCapabilityRecordURL {
            guard
                backendCapabilityRecordURL.path.contains("/diagnostics/"),
                backendCapabilityRecordURL.pathExtension == "json",
                !FileManager.default.fileExists(
                    atPath: backendCapabilityRecordURL.path
                )
            else {
                throw OfflineRendererError.invalid(
                    "backend capability record must be a new JSON under a diagnostics path"
                )
            }
        }
        if diagnosticConfiguration.hasOverride {
            guard
                outputURL.path.contains("/diagnostics/"),
                recordURL.path.contains("/diagnostics/")
            else {
                throw OfflineRendererError.invalid(
                    "non-baseline diagnostic output must remain under a diagnostics path"
                )
            }
        }
        if let diagnosticPrequantizedOutput {
            guard diagnosticPrequantizedOutput.path.contains("/diagnostics/")
            else {
                throw OfflineRendererError.invalid(
                    "prequantized diagnostic output must remain under a diagnostics path"
                )
            }
        }
        guard
            (diagnosticStageCaptureDirectory == nil)
                == (diagnosticStageCoordinate == nil)
        else {
            throw OfflineRendererError.invalid(
                "stage capture directory and coordinate must be supplied together"
            )
        }
        if let diagnosticStageCaptureDirectory {
            let capturePrefix =
                diagnosticStageCaptureDirectory.path.hasSuffix("/")
                ? diagnosticStageCaptureDirectory.path
                : diagnosticStageCaptureDirectory.path + "/"
            guard
                diagnosticStageCaptureDirectory.path.contains(
                    "/diagnostics/"
                ),
                outputURL.path.hasPrefix(capturePrefix),
                recordURL.path.hasPrefix(capturePrefix),
                !FileManager.default.fileExists(
                    atPath: diagnosticStageCaptureDirectory.path
                )
            else {
                throw OfflineRendererError.invalid(
                    "stage capture output and record must use one new diagnostics directory"
                )
            }
        }
        let decoder = JSONDecoder()
        let descriptor = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: sceneURL)
        )
        let descriptorSampling = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        let diagnosticMSAAIsolationRecord =
            try IndustrialL2V5MSAAIsolationContract.validate(
                requestedContractID: diagnosticContractID,
                repositoryRoot: repositoryRoot,
                sceneURL: sceneURL,
                materialsURL: materialsURL,
                outputURL: outputURL,
                recordURL: recordURL,
                explicitAntialiasing: diagnosticAntialiasingRaw,
                explicitSceneShadows: diagnosticSceneShadowsRaw,
                explicitMaterialLighting: diagnosticMaterialLightingRaw,
                logicalBuildingID: descriptor.logicalBuildingID,
                variantID: descriptor.variantID,
                sourceRevision: descriptor.sourceRevision,
                viewDirection: descriptor.viewDirection,
                productionSelected: descriptor.productionSelected,
                descriptorSceneKitAntialiasing:
                    descriptorSampling.sceneKitAntialiasing,
                descriptorSceneKitShadows:
                    descriptorSampling.sceneKitShadows
            )
        let diagnosticStageIsolationRecord =
            try IndustrialL2V5EastStageCaptureContract.validate(
                requestedContractID:
                    diagnosticStageContractID
                        == IndustrialL2V5EastStageCaptureContract
                        .contractID
                    ? diagnosticStageContractID
                    : nil,
                repositoryRoot: repositoryRoot,
                sceneURL: sceneURL,
                materialsURL: materialsURL,
                outputURL: outputURL,
                recordURL: recordURL,
                stageCaptureDirectory:
                    diagnosticStageCaptureDirectory,
                stageCoordinate: diagnosticStageCoordinate,
                explicitAntialiasing: diagnosticAntialiasingRaw,
                explicitSceneShadows: diagnosticSceneShadowsRaw,
                explicitMaterialLighting:
                    diagnosticMaterialLightingRaw,
                prequantizedOutputRequested:
                    diagnosticPrequantizedOutput != nil,
                logicalBuildingID: descriptor.logicalBuildingID,
                variantID: descriptor.variantID,
                sourceRevision: descriptor.sourceRevision,
                viewDirection: descriptor.viewDirection,
                productionSelected: descriptor.productionSelected,
                descriptorSceneKitAntialiasing:
                    descriptorSampling.sceneKitAntialiasing,
                descriptorSceneKitShadows:
                    descriptorSampling.sceneKitShadows
            )
        let diagnosticSceneKitLanczosRecord =
            try IndustrialL2V5EastSceneKitLanczosContract.validate(
                requestedContractID:
                    diagnosticStageContractID
                        == IndustrialL2V5EastSceneKitLanczosContract
                        .contractID
                    ? diagnosticStageContractID
                    : nil,
                repositoryRoot: repositoryRoot,
                sceneURL: sceneURL,
                sceneFileSHA256: try rendererSHA256(sceneURL),
                materialsURL: materialsURL,
                materialFileSHA256:
                    try rendererSHA256(materialsURL),
                outputURL: outputURL,
                recordURL: recordURL,
                stageCaptureDirectory:
                    diagnosticStageCaptureDirectory,
                stageCoordinate: diagnosticStageCoordinate,
                explicitAntialiasing: diagnosticAntialiasingRaw,
                explicitSceneShadows: diagnosticSceneShadowsRaw,
                explicitMaterialLighting:
                    diagnosticMaterialLightingRaw,
                prequantizedOutputRequested:
                    diagnosticPrequantizedOutput != nil,
                descriptor: descriptor,
                sampling: descriptorSampling
            )
        guard
            [
                diagnosticMSAAIsolationRecord != nil,
                diagnosticStageIsolationRecord != nil,
                diagnosticSceneKitLanczosRecord != nil,
            ].filter({ $0 }).count <= 1
        else {
            throw OfflineRendererError.invalid(
                "only one diagnostic isolation contract may be active"
            )
        }
        let diagnosticIsolationRecord =
            diagnosticMSAAIsolationRecord?.value
            ?? diagnosticStageIsolationRecord?.value
            ?? diagnosticSceneKitLanczosRecord?.value
        if descriptorSampling.purpose == "diagnostic-regression" {
            guard
                outputURL.path.contains("/diagnostics/"),
                recordURL.path.contains("/diagnostics/")
            else {
                throw OfflineRendererError.invalid(
                    "schema-2 diagnostic regression output must remain under a diagnostics path"
                )
            }
        }
        let materialDescriptor = try decoder.decode(
            MaterialLibraryDescriptor.self,
            from: Data(contentsOf: materialsURL)
        )
        guard
            descriptor.productionSelected == false,
            materialDescriptor.productionSelected == false,
            descriptor.derivation.siblingSource == nil,
            descriptor.derivation.mirror == false,
            descriptor.derivation.rotationDegrees == 0,
            descriptor.derivation.transform == "none"
        else {
            throw OfflineRendererError.invalid(
                "non-shipping/no-sibling contract failed"
            )
        }
        let capabilityContext = RendererCapabilityPreflight.capture()
        let resolvedCapabilityRecordURL: URL? = {
            if let backendCapabilityRecordURL {
                return backendCapabilityRecordURL
            }
            guard !capabilityContext.snapshot.available else {
                return nil
            }
            return recordURL.deletingPathExtension().appendingPathExtension(
                "backend-unavailable.json"
            )
        }()
        if let resolvedCapabilityRecordURL {
            guard !FileManager.default.fileExists(
                atPath: resolvedCapabilityRecordURL.path
            ) else {
                throw OfflineRendererError.invalid(
                    "backend capability record already exists"
                )
            }
            let fingerprintURL = repositoryRoot.appendingPathComponent(
                descriptor.toolchainFingerprint.file
            )
            try rendererWriteCapabilityRecord(
                [
                    "schema": 1,
                    "task": "PLAY-027",
                    "type": capabilityContext.snapshot.result,
                    "capability": capabilityContext.snapshot.record,
                    "rendererSourceCommit": sourceCommit,
                    "sceneDescriptorFile": rendererRelativePath(
                        sceneURL,
                        repositoryRoot: repositoryRoot
                    ),
                    "sceneDescriptorSHA256":
                        try rendererSHA256(sceneURL),
                    "materialLibraryFile": rendererRelativePath(
                        materialsURL,
                        repositoryRoot: repositoryRoot
                    ),
                    "materialLibrarySHA256":
                        try rendererSHA256(materialsURL),
                    "toolchainFingerprintFile":
                        descriptor.toolchainFingerprint.file,
                    "toolchainFingerprintDeclaredSHA256":
                        descriptor.toolchainFingerprint.sha256,
                    "toolchainFingerprintActualSHA256":
                        try rendererSHA256(fingerprintURL),
                    "requestedRawSourceFile": rendererRelativePath(
                        outputURL,
                        repositoryRoot: repositoryRoot
                    ),
                    "requestedProvenanceFile": rendererRelativePath(
                        recordURL,
                        repositoryRoot: repositoryRoot
                    ),
                    "candidateOutputWritten": false,
                    "candidateFailureClassified": false,
                    "sceneConstructionStarted": false,
                    "scenePreparationStarted": false,
                    "productionSelected": false,
                ],
                to: resolvedCapabilityRecordURL
            )
        }
        guard capabilityContext.snapshot.available else {
            let recordPath = resolvedCapabilityRecordURL?.path
                ?? "capability-record-unavailable"
            print("renderer-backend-unavailable \(recordPath)")
            return
        }
        let materialLibrary = NativeMaterialLibrary(
            descriptor: materialDescriptor
        )
        let scene = try ContractSceneBuilder(
            materials: materialLibrary
        ).buildScene(from: descriptor)
        let effectiveSceneKitLightingMode =
            diagnosticConfiguration.materialLighting == .constantUnlit
            ? "authored-constant-v1"
            : descriptorSampling.sceneKitLightingMode
        let sceneKitLightingApplication =
            applyDiagnosticMaterialLighting(
                effectiveSceneKitLightingMode == "authored-constant-v1"
                    ? .constantUnlit
                    : .current,
                to: scene
            )
        if descriptorSampling.sceneKitShadows == "disabled"
            || diagnosticConfiguration.sceneShadows == .disabled
        {
            scene.rootNode.enumerateChildNodes { node, _ in
                node.light?.castsShadow = false
            }
        }
        let renderedNodeBounds = try validatedRenderedNodeBounds(
            scene,
            descriptor: descriptor
        )
        let effectiveAntialiasing =
            diagnosticConfiguration.antialiasingOverride?.sceneKitMode
            ?? (
                descriptorSampling.sceneKitAntialiasing == "none"
                    ? SCNAntialiasingMode.none
                    : SCNAntialiasingMode.multisampling4X
            )
        let oversampled = try NativeSourceRenderer(
            renderer: capabilityContext.renderer,
            antialiasingMode: effectiveAntialiasing,
            linearOversamplingFactor:
                descriptorSampling.linearOversamplingFactor
        ).renderSource(scene: scene, descriptor: descriptor)
        let oversampledSupportWindow =
            try diagnosticSceneKitLanczosRecord.map {
                try rendererOversampledSupportWindowRecord(
                    image: oversampled,
                    geometry: $0.supportGeometry
                )
            }
        let compositor = NativeSourceCompositor(
            sampling: descriptorSampling,
            stageTraceCoordinate: diagnosticStageCoordinate
        )
        let source = try compositor.compositeRegisteredSource(
            renderedImage: oversampled,
            descriptor: descriptor
        )
        let rawOccupancy = try validatedRawOccupancy(source)
        var pngWriteDiagnostics: RendererPNGWriteDiagnostics?
        if
            let diagnosticStageCaptureDirectory,
            let diagnosticStageCoordinate
        {
            try FileManager.default.createDirectory(
                at: diagnosticStageCaptureDirectory,
                withIntermediateDirectories: true
            )
            pngWriteDiagnostics = try writePNG(
                source,
                to: outputURL,
                diagnosticIntermediateURL:
                    diagnosticStageCaptureDirectory.appendingPathComponent(
                        "imageio-pre-sips.png"
                    ),
                diagnosticRepositoryRoot: repositoryRoot,
                diagnosticTarget: diagnosticStageCoordinate
            )
        } else {
            _ = try writePNG(source, to: outputURL)
        }
        if
            let diagnosticPrequantizedOutput,
            let prequantizedImage = compositor.prequantizedImage
        {
            _ = try writePNG(
                prequantizedImage,
                to: diagnosticPrequantizedOutput
            )
        }

        if
            let diagnosticStageCaptureDirectory,
            let diagnosticStageCoordinate,
            let prequantizedRGBA = compositor.prequantizedRGBA,
            let quantizedBeforeMajorityRGBA =
                compositor.quantizedBeforeMajorityRGBA,
            let postMajorityRGBA = compositor.postMajorityRGBA,
            let pngWriteDiagnostics
        {
            let width = descriptor.camera.renderViewportPixels[0]
            let height = descriptor.camera.renderViewportPixels[1]
            let prequantized = try rendererRGBAStageRecord(
                stage: "prequantized-in-memory",
                rgba: prequantizedRGBA,
                width: width,
                height: height,
                target: diagnosticStageCoordinate
            )
            let quantizedBeforeMajority = try rendererRGBAStageRecord(
                stage: "quantized-before-majority-in-memory",
                rgba: quantizedBeforeMajorityRGBA,
                width: width,
                height: height,
                target: diagnosticStageCoordinate
            )
            let postMajority = try rendererRGBAStageRecord(
                stage: "post-majority-in-memory",
                rgba: postMajorityRGBA,
                width: width,
                height: height,
                target: diagnosticStageCoordinate
            )
            let evaluations = compositor.postQuantizationEvaluations.map {
                [
                    "x": $0.x,
                    "y": $0.y,
                    "channel": $0.channel,
                    "centerValue": $0.centerValue,
                    "majorityValue":
                        $0.majorityValue.map { $0 as Any } ?? NSNull(),
                    "majorityCount": $0.majorityCount,
                    "fullyOpaqueNeighborhood":
                        $0.fullyOpaqueNeighborhood,
                    "chromaFreeNeighborhood":
                        $0.chromaFreeNeighborhood,
                    "exactQuantumDifference":
                        $0.exactQuantumDifference,
                    "eligible": $0.eligible,
                    "mutated": $0.mutated,
                    "standardMajorityEligible":
                        $0.standardMajorityEligible,
                    "boundaryAssistEligible":
                        $0.boundaryAssistEligible,
                    "boundaryVotes": $0.boundaryVotes.map {
                        [
                            "coordinate": [$0.x, $0.y],
                            "channel": $0.channel,
                            "prequantizedValue":
                                $0.prequantizedValue,
                            "quantizedValue":
                                $0.quantizedValue,
                            "boundaryPair": $0.boundaryPair,
                        ] as [String: Any]
                    },
                    "competingSupportAfterBoundaryReclassification":
                        $0
                        .competingSupportAfterBoundaryReclassification
                        .map { $0 as Any } ?? NSNull(),
                    "eligibilityReason": $0.eligibilityReason,
                ] as [String: Any]
            }
            let postSHA =
                postMajority["decodedRGBASHA256"] as? String
            let imageIOSHA =
                pngWriteDiagnostics.imageIOPreSips[
                    "decodedRGBASHA256"
                ] as? String
            let finalSHA =
                pngWriteDiagnostics.finalSips[
                    "decodedRGBASHA256"
                ] as? String
            var capture: [String: Any] = [
                "schema": 1,
                "task": "PLAY-027",
                "purpose":
                    "residual-stage-isolation-no-authority",
                "coordinateSystem":
                    "top-left decoded RGBA source pixel",
                "targetCoordinate": diagnosticStageCoordinate,
                "sourceKey":
                    "\(descriptor.logicalBuildingID)/\(descriptor.variantID)/\(descriptor.viewDirection)/\(descriptor.sourceRevision)",
                "stages": [
                    prequantized,
                    quantizedBeforeMajority,
                    postMajority,
                    pngWriteDiagnostics.imageIOPreSips,
                    pngWriteDiagnostics.finalSips,
                ],
                "postMajorityTargetEvaluations": evaluations,
                "postMajorityTargetEligible":
                    evaluations.contains { $0["eligible"] as? Bool == true },
                "postMajorityTargetMutated":
                    evaluations.contains { $0["mutated"] as? Bool == true },
                "postMajorityTotalMutationCount":
                    compositor.postQuantizationMutations.count,
                "postMajorityMutationCountsByChannel": [
                    "red":
                        compositor.postQuantizationMutations.filter {
                            $0.channel == 0
                        }.count,
                    "green":
                        compositor.postQuantizationMutations.filter {
                            $0.channel == 1
                        }.count,
                    "blue":
                        compositor.postQuantizationMutations.filter {
                            $0.channel == 2
                        }.count,
                ],
                "stageIdentity": [
                    "postMajorityEqualsImageIODecode":
                        postSHA != nil && postSHA == imageIOSHA,
                    "imageIODecodeEqualsFinalSipsDecode":
                        imageIOSHA != nil && imageIOSHA == finalSHA,
                ],
                "descriptorSamplingContractID":
                    descriptorSampling.contractID,
                "repairThresholdsChanged": false,
                "productionSelected": false,
            ]
            if let oversampledSupportWindow {
                capture["oversampledSupportWindow"] =
                    oversampledSupportWindow
            }
            var captureData = try JSONSerialization.data(
                withJSONObject: capture,
                options: [
                    .prettyPrinted,
                    .sortedKeys,
                    .withoutEscapingSlashes,
                ]
            )
            captureData.append(0x0a)
            try captureData.write(
                to: diagnosticStageCaptureDirectory.appendingPathComponent(
                    "STAGE-CAPTURE.json"
                ),
                options: .atomic
            )
        }

        let sourceFiles = [
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/RendererArchitecture.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/DeterministicPixelCanonicalizer.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/RendererStageDiagnostics.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/RendererCapabilityPreflight.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/IndustrialL2V5MSAAIsolationContract.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/IndustrialL2V5EastStageCaptureContract.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/IndustrialL2V5EastSceneKitLanczosContract.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/OfflineSceneRenderer.swift",
        ]
        var sourceHashes: [[String: String]] = []
        for file in sourceFiles {
            let url = repositoryRoot.appendingPathComponent(file)
            sourceHashes.append([
                "file": file,
                "sha256": try rendererSHA256(url),
            ])
        }
        let sourceKey =
            "\(descriptor.logicalBuildingID)/\(descriptor.variantID)/\(descriptor.viewDirection)/\(descriptor.sourceRevision)"
        let boundaryAssistMutations =
            compositor.postQuantizationMutations.compactMap {
                rendererBoundaryAssistMutationRecord($0)
            }
        let postQuantizationContract =
            rendererPostQuantizationContractRecord(
                descriptorSampling.postQuantizationCanonicalizer
            )
        let record: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "sourceKey": sourceKey,
            "logicalBuildingID": descriptor.logicalBuildingID,
            "family": descriptor.family,
            "level": descriptor.level,
            "variantID": descriptor.variantID,
            "viewDirection": descriptor.viewDirection,
            "sourceRevision": descriptor.sourceRevision,
            "tool": "PLAY-027 macOS-native offline source renderer",
            "frameworks": [
                "SceneKit",
                "ModelIO",
                "CoreImage",
                "CoreGraphics",
            ],
            "rendererSourceCommit": sourceCommit,
            "rendererCapability": capabilityContext.snapshot.record,
            "diagnosticConfiguration": [
                "antialiasingOverride":
                    diagnosticConfiguration.antialiasingOverride?.rawValue
                    ?? "none",
                "sceneShadows":
                    diagnosticConfiguration.sceneShadows.rawValue,
                "materialLighting":
                    diagnosticConfiguration.materialLighting.rawValue,
                "materialLightingApplication": [
                    "uniqueMaterialCount":
                        sceneKitLightingApplication
                        .uniqueMaterialCount,
                    "sceneLightCount":
                        sceneKitLightingApplication.sceneLightCount,
                    "sceneLightsDisabled":
                        effectiveSceneKitLightingMode
                        == "authored-constant-v1",
                    "materialColorsChanged": false,
                    "descriptorChanged": false,
                ],
                "descriptorGeometryChanged": false,
                "sourceAuthority": false,
                "prequantizedOutput":
                    diagnosticPrequantizedOutput.map {
                        rendererRelativePath(
                            $0,
                            repositoryRoot: repositoryRoot
                        )
                    } ?? "not-requested",
                "stageCapture":
                    diagnosticStageCaptureDirectory.map {
                        rendererRelativePath(
                            $0,
                            repositoryRoot: repositoryRoot
                        )
                    } ?? "not-requested",
            ],
            "diagnosticIsolationContract":
                diagnosticIsolationRecord ?? [
                    "contractID": "none",
                    "sourceAuthority": false,
                    "productionSelected": false,
                ],
            "descriptorSamplingContract": [
                "contractID": descriptorSampling.contractID,
                "descriptorSchema": descriptorSampling.descriptorSchema,
                "purpose": descriptorSampling.purpose,
                "sceneKitAntialiasing":
                    descriptorSampling.sceneKitAntialiasing,
                "effectiveSceneKitAntialiasing":
                    diagnosticConfiguration.antialiasingOverride?.rawValue
                    ?? descriptorSampling.sceneKitAntialiasing,
                "sceneKitShadows":
                    descriptorSampling.sceneKitShadows,
                "effectiveSceneKitShadows":
                    diagnosticConfiguration.sceneShadows == .disabled
                    ? "disabled"
                    : descriptorSampling.sceneKitShadows,
                "sceneKitLightingMode":
                    descriptorSampling.sceneKitLightingMode,
                "effectiveSceneKitLightingMode":
                    effectiveSceneKitLightingMode,
                "sceneKitMaterialLightingModel":
                    effectiveSceneKitLightingMode
                        == "authored-constant-v1"
                    ? "constant"
                    : "lambert",
                "sceneLights":
                    effectiveSceneKitLightingMode
                        == "authored-constant-v1"
                    ? "disabled-zero-intensity-no-shadow"
                    : "descriptor-authored",
                "linearOversamplingFactor":
                    descriptorSampling.linearOversamplingFactor,
                "downsampleFilter":
                    descriptorSampling.downsampleFilter,
                "downsampleScale":
                    descriptorSampling.downsampleScale,
                "downsampleAspectRatio":
                    descriptorSampling.downsampleAspectRatio,
                "ciUseSoftwareRenderer":
                    descriptorSampling.ciUseSoftwareRenderer,
                "ciCacheIntermediates":
                    descriptorSampling.ciCacheIntermediates,
                "ciWorkingColorSpace":
                    descriptorSampling.ciWorkingColorSpace,
                "ciOutputColorSpace":
                    descriptorSampling.ciOutputColorSpace,
                "quantizerID": descriptorSampling.quantizerID,
                "quantizerStep": descriptorSampling.quantizerStep,
                "quantizerMidpointOffset":
                    descriptorSampling.quantizerMidpointOffset,
                "canonicalizerID":
                    descriptorSampling.canonicalizerID,
                "canonicalizerEncoder":
                    descriptorSampling.canonicalizerEncoder,
                "canonicalizerPostEncoder":
                    descriptorSampling.canonicalizerPostEncoder,
                "canonicalizerFormat":
                    descriptorSampling.canonicalizerFormat,
                "postQuantizationCanonicalizer":
                    postQuantizationContract,
                "postQuantizationMutationCount":
                    compositor.postQuantizationMutations.count,
                "postQuantizationMutationCountsByChannel": [
                    "red":
                        compositor.postQuantizationMutations.filter {
                            $0.channel == 0
                        }.count,
                    "green":
                        compositor.postQuantizationMutations.filter {
                            $0.channel == 1
                        }.count,
                    "blue":
                        compositor.postQuantizationMutations.filter {
                            $0.channel == 2
                        }.count,
                ],
                "postQuantizationBoundaryAssistMutationCount":
                    boundaryAssistMutations.count,
                "postQuantizationBoundaryAssistMutations":
                    boundaryAssistMutations,
            ],
            "rendererSources": sourceHashes,
            "sceneDescriptorFile": rendererRelativePath(
                sceneURL,
                repositoryRoot: repositoryRoot
            ),
            "sceneDescriptorSHA256": try rendererSHA256(sceneURL),
            "materialLibraryFile": rendererRelativePath(
                materialsURL,
                repositoryRoot: repositoryRoot
            ),
            "materialLibrarySHA256": try rendererSHA256(materialsURL),
            "rawSourceFile": rendererRelativePath(
                outputURL,
                repositoryRoot: repositoryRoot
            ),
            "rawSourceSHA256": try rendererSHA256(outputURL),
            "renderedNodeBounds": renderedNodeBounds,
            "rawOccupancy": rawOccupancy,
            "nativePNGCanonicalizer": [
                "path": "/usr/bin/sips",
                "role": "deterministic review-decoder-safe final PNG encoding",
            ],
            "rawSourcePixels":
                descriptor.camera.renderViewportPixels,
            "oversamplingFactor":
                descriptor.camera.oversamplingFactor,
            "cameraProjection": descriptor.camera.projection,
            "groundPivotSource":
                descriptor.registration.groundPivotSource,
            "frontageEdgeSource":
                descriptor.registration.frontageEdgeSource,
            "frontageSocketSource":
                descriptor.registration.frontageSocketSource,
            "doorBaseSource":
                descriptor.registration.doorBaseSource,
            "contactPolygonWorld":
                descriptor.registration.contactPolygonWorld,
            "northwestKeyOriginWorld": descriptor.light.keyOrigin,
            "southeastShadowVectorSource":
                descriptor.light.shadowVectorSource,
            "chromaKeyRGBA": [255, 0, 255, 255],
            "orientationTransform": "none",
            "authoredIndependently":
                descriptor.authoredIndependently,
            "generatedPixelsAreGeometryAuthority": false,
            "productionSelected": false,
        ]
        let data = try JSONSerialization.data(
            withJSONObject: record,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var terminated = data
        terminated.append(0x0a)
        try FileManager.default.createDirectory(
            at: recordURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try terminated.write(to: recordURL, options: .atomic)
    }
}
#endif
