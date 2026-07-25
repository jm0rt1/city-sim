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
            return "usage: offline-scene-renderer --repository-root <path> --scene <json> --materials <json> --output <png> --record <json> --renderer-source-commit <sha>"
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
                try addWindow(bay, facade: facade.direction, to: scene)
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
        if bay.floor == 1 {
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

        let portalWidth = entrance.width
            + (style == "urban-lobby" ? 8 : 5)
        let portalHeight = entrance.height
            + (style == "courtyard-portal" ? 9 : 6)
        let portalDepth = entrance.depth + 1.2
        let sideWidth = style == "urban-lobby" ? 2.2 : 1.5
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
    func renderSource(
        scene: SCNScene,
        descriptor: SceneDescriptor
    ) throws -> CGImage {
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
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
        let scale = descriptor.camera.oversamplingFactor
        let size = CGSize(
            width: descriptor.camera.renderViewportPixels[0] * scale,
            height: descriptor.camera.renderViewportPixels[1] * scale
        )
        let snapshot = renderer.snapshot(
            atTime: 0,
            with: size,
            antialiasingMode: .multisampling4X
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
    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: true,
        .cacheIntermediates: false,
        .workingColorSpace: CGColorSpace(
            name: CGColorSpace.extendedSRGB
        )!,
        .outputColorSpace: CGColorSpace(
            name: CGColorSpace.sRGB
        )!,
    ])

    func compositeRegisteredSource(
        renderedImage: CGImage,
        descriptor: SceneDescriptor
    ) throws -> CGImage {
        let scale = 1 / CGFloat(descriptor.camera.oversamplingFactor)
        let input = CIImage(cgImage: renderedImage)
        guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
            throw OfflineRendererError.rendering(
                "CILanczosScaleTransform unavailable"
            )
        }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(1, forKey: kCIInputAspectRatioKey)
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
        return try deterministicallyQuantized(composited)
    }

    private func deterministicallyQuantized(
        _ image: CGImage
    ) throws -> CGImage {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
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
            // SceneKit's Metal snapshot can alternate a shaded sample across
            // an exact floor-bucket boundary in otherwise identical process
            // invocations. Round to the nearest 32-value palette entry so the
            // observed 191/192 boundary pair converges to the same value while
            // retaining nine stable levels per channel for the small-scale
            // authored palette.
            let step = 32
            for pixel in stride(from: 0, to: storage.count, by: 4) {
                if
                    storage[pixel] == 255,
                    storage[pixel + 1] == 0,
                    storage[pixel + 2] == 255,
                    storage[pixel + 3] == 255
                {
                    continue
                }
                for channel in 0..<3 {
                    let value = Int(storage[pixel + channel])
                    let quantized = min(
                        255,
                        ((value + step / 2) / step) * step
                    )
                    storage[pixel + channel] = UInt8(quantized)
                }
            }
            guard let output = context.makeImage() else {
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

func writePNG(_ image: CGImage, to url: URL) throws {
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
        let sourceCommit = try rendererArgument(
            "--renderer-source-commit",
            in: arguments
        )
        let decoder = JSONDecoder()
        let descriptor = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: sceneURL)
        )
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
        let materialLibrary = NativeMaterialLibrary(
            descriptor: materialDescriptor
        )
        let scene = try ContractSceneBuilder(
            materials: materialLibrary
        ).buildScene(from: descriptor)
        let oversampled = try NativeSourceRenderer().renderSource(
            scene: scene,
            descriptor: descriptor
        )
        let source = try NativeSourceCompositor().compositeRegisteredSource(
            renderedImage: oversampled,
            descriptor: descriptor
        )
        try writePNG(source, to: outputURL)

        let sourceFiles = [
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/RendererArchitecture.swift",
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
        let record: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "sourceKey":
                "\(descriptor.logicalBuildingID)/\(descriptor.variantID)/\(descriptor.viewDirection)/\(descriptor.sourceRevision)",
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
