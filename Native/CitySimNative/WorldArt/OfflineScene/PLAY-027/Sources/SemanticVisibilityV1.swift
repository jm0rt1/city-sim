import CoreGraphics
import CoreImage
import CryptoKit
import Foundation
import SceneKit
import simd

enum PLAY027SemanticVisibilityV1Error: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return "semantic-visibility-v1 rejected: \(message)"
        }
    }
}

enum PLAY027SemanticComponent: UInt8, CaseIterable {
    case southJamb = 1
    case northJamb = 2
    case header = 3
    case insetVoid = 4
    case hall = 5
    case gantry = 6
    case crucibleOccluder = 7
    case other = 8

    var identifier: String {
        switch self {
        case .southJamb: return "portal-jamb-south"
        case .northJamb: return "portal-jamb-north"
        case .header: return "portal-header"
        case .insetVoid: return "portal-inset-void"
        case .hall: return "hall"
        case .gantry: return "gantry"
        case .crucibleOccluder: return "crucible-occluder"
        case .other: return "other"
        }
    }

    var color: (UInt8, UInt8, UInt8) {
        switch self {
        case .southJamb: return (24, 194, 242)
        case .northJamb: return (242, 216, 24)
        case .header: return (242, 30, 24)
        case .insetVoid: return (30, 230, 70)
        case .hall: return (170, 104, 58)
        case .gantry: return (72, 100, 120)
        case .crucibleOccluder: return (208, 112, 28)
        case .other: return (92, 96, 100)
        }
    }

    var grayscale: UInt8 {
        switch self {
        case .southJamb: return 220
        case .northJamb: return 190
        case .header: return 235
        case .insetVoid: return 45
        case .hall: return 145
        case .gantry: return 85
        case .crucibleOccluder: return 175
        case .other: return 110
        }
    }

    static func classify(nodeName: String) -> PLAY027SemanticComponent {
        if nodeName == "v17-monumental-portal-jamb-south" {
            return .southJamb
        }
        if nodeName == "v17-monumental-portal-jamb-north" {
            return .northJamb
        }
        if
            nodeName == "v17-monumental-portal-lintel"
                || nodeName == "v17-monumental-portal-header-wall"
        {
            return .header
        }
        if nodeName == "v17-monumental-portal-inset-back-plane" {
            return .insetVoid
        }
        if
            nodeName.contains("hall")
                || nodeName.contains("side-return")
                || nodeName.contains("portal-wall")
        {
            return .hall
        }
        if
            nodeName.contains("gantry")
                || nodeName.contains("crane")
                || nodeName.contains("lift-rail")
        {
            return .gantry
        }
        if nodeName.contains("crucible") {
            return .crucibleOccluder
        }
        return .other
    }
}

struct PLAY027SemanticTriangle {
    let component: PLAY027SemanticComponent
    let nodeName: String
    let points: [SIMD3<Float>]
}

struct PLAY027SemanticRaster {
    let width: Int
    let height: Int
    let owners: [UInt8]
}

struct PLAY027SemanticNodeRecord {
    let nodeName: String
    let component: PLAY027SemanticComponent
    let vertexCount: Int
    let triangleCount: Int
    let worldTransform: [Float]
    let geometrySHA256: String
}

struct PLAY027SemanticSceneExtraction {
    let triangles: [PLAY027SemanticTriangle]
    let nodes: [PLAY027SemanticNodeRecord]
}

enum PLAY027SemanticVisibilityV1 {
    static let pipelineName = "semantic-visibility-v1"

    static func extract(
        scene: SCNScene
    ) throws -> PLAY027SemanticSceneExtraction {
        var triangles: [PLAY027SemanticTriangle] = []
        var records: [PLAY027SemanticNodeRecord] = []
        scene.rootNode.enumerateChildNodes { node, _ in
            guard
                let name = node.name,
                name != "contract-camera",
                node.light == nil,
                let geometry = node.geometry,
                let vertexSource = geometry.sources(
                    for: .vertex
                ).first
            else {
                return
            }
            do {
                let localVertices = try vertices(from: vertexSource)
                let worldVertices = localVertices.map {
                    let transformed =
                        node.simdWorldTransform
                        * SIMD4<Float>($0.x, $0.y, $0.z, 1)
                    return SIMD3<Float>(
                        transformed.x,
                        transformed.y,
                        transformed.z
                    )
                }
                var nodeTriangles: [[SIMD3<Float>]] = []
                for element in geometry.elements {
                    for indices in try triangleIndices(from: element) {
                        guard
                            indices[0] < worldVertices.count,
                            indices[1] < worldVertices.count,
                            indices[2] < worldVertices.count
                        else {
                            throw PLAY027SemanticVisibilityV1Error.invalid(
                                "geometry index outside vertex buffer for \(name)"
                            )
                        }
                        nodeTriangles.append([
                            worldVertices[indices[0]],
                            worldVertices[indices[1]],
                            worldVertices[indices[2]],
                        ])
                    }
                }
                let component = PLAY027SemanticComponent.classify(
                    nodeName: name
                )
                triangles.append(
                    contentsOf: nodeTriangles.map {
                        PLAY027SemanticTriangle(
                            component: component,
                            nodeName: name,
                            points: $0
                        )
                    }
                )
                var geometryData = Data()
                for vertex in worldVertices {
                    for value in [vertex.x, vertex.y, vertex.z] {
                        var bits = value.bitPattern.littleEndian
                        withUnsafeBytes(of: &bits) {
                            geometryData.append(contentsOf: $0)
                        }
                    }
                }
                for triangle in nodeTriangles {
                    for vertex in triangle {
                        for value in [vertex.x, vertex.y, vertex.z] {
                            var bits = value.bitPattern.littleEndian
                            withUnsafeBytes(of: &bits) {
                                geometryData.append(contentsOf: $0)
                            }
                        }
                    }
                }
                let transform = node.simdWorldTransform
                let transformValues = (0..<4).flatMap { column in
                    [
                        transform[column].x,
                        transform[column].y,
                        transform[column].z,
                        transform[column].w,
                    ]
                }
                records.append(
                    PLAY027SemanticNodeRecord(
                        nodeName: name,
                        component: component,
                        vertexCount: worldVertices.count,
                        triangleCount: nodeTriangles.count,
                        worldTransform: transformValues,
                        geometrySHA256: digest(geometryData)
                    )
                )
            } catch {
                preconditionFailure("\(error)")
            }
        }
        guard !triangles.isEmpty else {
            throw PLAY027SemanticVisibilityV1Error.invalid(
                "SceneKit node construction produced no triangles"
            )
        }
        return PLAY027SemanticSceneExtraction(
            triangles: triangles,
            nodes: records.sorted {
                $0.nodeName < $1.nodeName
            }
        )
    }

    static func rasterize(
        extraction: PLAY027SemanticSceneExtraction,
        cameraNode: SCNNode,
        orthographicScale: Double,
        width: Int,
        height: Int,
        fullViewportWidth: Int? = nil,
        fullViewportHeight: Int? = nil,
        originX: Int = 0,
        originY: Int = 0,
        includedComponents: Set<PLAY027SemanticComponent>? = nil
    ) throws -> PLAY027SemanticRaster {
        guard
            width > 0,
            height > 0,
            orthographicScale > 0
        else {
            throw PLAY027SemanticVisibilityV1Error.invalid(
                "invalid semantic viewport"
            )
        }
        let pixelCount = width * height
        var owners = [UInt8](repeating: 0, count: pixelCount)
        var depths = [Float](repeating: .greatestFiniteMagnitude, count: pixelCount)
        let inverseCamera = cameraNode.simdWorldTransform.inverse
        let projectionWidth = fullViewportWidth ?? width
        let projectionHeight = fullViewportHeight ?? height
        let aspect = Float(projectionWidth) / Float(projectionHeight)
        let verticalScale = Float(orthographicScale)
        let horizontalScale = verticalScale * aspect

        for triangle in extraction.triangles {
            if let includedComponents, !includedComponents.contains(triangle.component) {
                continue
            }
            let projected = triangle.points.map { world -> SIMD3<Float> in
                let camera =
                    inverseCamera
                    * SIMD4<Float>(world.x, world.y, world.z, 1)
                return SIMD3<Float>(
                    (camera.x / horizontalScale + 0.5)
                        * Float(projectionWidth) - Float(originX),
                    (0.5 - camera.y / verticalScale)
                        * Float(projectionHeight) - Float(originY),
                    -camera.z
                )
            }
            rasterizeTriangle(
                projected,
                owner: triangle.component.rawValue,
                width: width,
                height: height,
                owners: &owners,
                depths: &depths
            )
        }
        return PLAY027SemanticRaster(
            width: width,
            height: height,
            owners: owners
        )
    }

    static func projectedBounds(
        extraction: PLAY027SemanticSceneExtraction,
        cameraNode: SCNNode,
        orthographicScale: Double,
        viewportWidth: Int,
        viewportHeight: Int
    ) throws -> [Int] {
        guard
            viewportWidth > 0,
            viewportHeight > 0,
            orthographicScale > 0
        else {
            throw PLAY027SemanticVisibilityV1Error.invalid(
                "invalid semantic projection bounds viewport"
            )
        }
        let inverseCamera = cameraNode.simdWorldTransform.inverse
        let aspect = Float(viewportWidth) / Float(viewportHeight)
        let verticalScale = Float(orthographicScale)
        let horizontalScale = verticalScale * aspect
        var minimumX = Float.greatestFiniteMagnitude
        var minimumY = Float.greatestFiniteMagnitude
        var maximumX = -Float.greatestFiniteMagnitude
        var maximumY = -Float.greatestFiniteMagnitude
        for triangle in extraction.triangles {
            for world in triangle.points {
                let camera =
                    inverseCamera
                    * SIMD4<Float>(world.x, world.y, world.z, 1)
                let x =
                    (camera.x / horizontalScale + 0.5)
                    * Float(viewportWidth)
                let y =
                    (0.5 - camera.y / verticalScale)
                    * Float(viewportHeight)
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
            }
        }
        guard minimumX.isFinite else {
            throw PLAY027SemanticVisibilityV1Error.invalid(
                "semantic projection produced no finite bounds"
            )
        }
        return [
            Int(floor(minimumX)),
            Int(floor(minimumY)),
            Int(ceil(maximumX)),
            Int(ceil(maximumY)),
        ]
    }

    static func ownerImage(
        raster: PLAY027SemanticRaster,
        component: PLAY027SemanticComponent? = nil,
        grayscale: Bool = false
    ) -> [UInt8] {
        var rgba = [UInt8](repeating: 0, count: raster.width * raster.height * 4)
        for index in 0..<raster.owners.count {
            guard
                raster.owners[index] != 0,
                let owner = PLAY027SemanticComponent(
                    rawValue: raster.owners[index]
                ),
                component == nil || owner == component
            else {
                continue
            }
            let offset = index * 4
            if grayscale {
                rgba[offset] = owner.grayscale
                rgba[offset + 1] = owner.grayscale
                rgba[offset + 2] = owner.grayscale
            } else {
                let color = owner.color
                rgba[offset] = color.0
                rgba[offset + 1] = color.1
                rgba[offset + 2] = color.2
            }
            rgba[offset + 3] = 255
        }
        return rgba
    }

    static func binaryMaskImage(
        raster: PLAY027SemanticRaster,
        component: PLAY027SemanticComponent
    ) -> [UInt8] {
        var rgba = [UInt8](repeating: 0, count: raster.width * raster.height * 4)
        for index in 0..<raster.owners.count
        where raster.owners[index] == component.rawValue {
            let offset = index * 4
            rgba[offset] = 255
            rgba[offset + 1] = 255
            rgba[offset + 2] = 255
            rgba[offset + 3] = 255
        }
        return rgba
    }

    private static func vertices(
        from source: SCNGeometrySource
    ) throws -> [SIMD3<Float>] {
        guard
            source.componentsPerVector >= 3,
            source.bytesPerComponent == 4
        else {
            throw PLAY027SemanticVisibilityV1Error.invalid(
                "unsupported SceneKit vertex source layout"
            )
        }
        return try source.data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                throw PLAY027SemanticVisibilityV1Error.invalid(
                    "empty SceneKit vertex source"
                )
            }
            return (0..<source.vectorCount).map { index in
                let base =
                    source.dataOffset
                    + index * source.dataStride
                func value(_ component: Int) -> Float {
                    baseAddress.loadUnaligned(
                        fromByteOffset:
                            base + component * source.bytesPerComponent,
                        as: Float.self
                    )
                }
                return SIMD3<Float>(value(0), value(1), value(2))
            }
        }
    }

    private static func triangleIndices(
        from element: SCNGeometryElement
    ) throws -> [[Int]] {
        let indexCount: Int
        switch element.primitiveType {
        case .triangles:
            indexCount = element.primitiveCount * 3
        case .triangleStrip:
            indexCount = element.primitiveCount + 2
        default:
            throw PLAY027SemanticVisibilityV1Error.invalid(
                "unsupported SceneKit primitive type \(element.primitiveType.rawValue)"
            )
        }
        let indices: [Int] = try element.data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                throw PLAY027SemanticVisibilityV1Error.invalid(
                    "empty SceneKit index buffer"
                )
            }
            return try (0..<indexCount).map { index in
                let offset = index * element.bytesPerIndex
                switch element.bytesPerIndex {
                case 1:
                    return Int(
                        baseAddress.loadUnaligned(
                            fromByteOffset: offset,
                            as: UInt8.self
                        )
                    )
                case 2:
                    return Int(
                        UInt16(littleEndian:
                            baseAddress.loadUnaligned(
                                fromByteOffset: offset,
                                as: UInt16.self
                            )
                        )
                    )
                case 4:
                    return Int(
                        UInt32(littleEndian:
                            baseAddress.loadUnaligned(
                                fromByteOffset: offset,
                                as: UInt32.self
                            )
                        )
                    )
                default:
                    throw PLAY027SemanticVisibilityV1Error.invalid(
                        "unsupported SceneKit index width"
                    )
                }
            }
        }
        switch element.primitiveType {
        case .triangles:
            return stride(from: 0, to: indices.count, by: 3).map {
                [indices[$0], indices[$0 + 1], indices[$0 + 2]]
            }
        case .triangleStrip:
            return (0..<element.primitiveCount).map { index in
                if index.isMultiple(of: 2) {
                    return [
                        indices[index],
                        indices[index + 1],
                        indices[index + 2],
                    ]
                }
                return [
                    indices[index + 1],
                    indices[index],
                    indices[index + 2],
                ]
            }
        default:
            return []
        }
    }

    private static func rasterizeTriangle(
        _ points: [SIMD3<Float>],
        owner: UInt8,
        width: Int,
        height: Int,
        owners: inout [UInt8],
        depths: inout [Float]
    ) {
        guard points.count == 3 else { return }
        let minimumX = max(
            0,
            Int(floor(min(points[0].x, points[1].x, points[2].x)))
        )
        let maximumX = min(
            width - 1,
            Int(ceil(max(points[0].x, points[1].x, points[2].x)))
        )
        let minimumY = max(
            0,
            Int(floor(min(points[0].y, points[1].y, points[2].y)))
        )
        let maximumY = min(
            height - 1,
            Int(ceil(max(points[0].y, points[1].y, points[2].y)))
        )
        guard minimumX <= maximumX, minimumY <= maximumY else { return }
        let area = edge(points[0], points[1], points[2].x, points[2].y)
        guard abs(area) > 0.000_001 else { return }
        for y in minimumY...maximumY {
            for x in minimumX...maximumX {
                let sampleX = Float(x) + 0.5
                let sampleY = Float(y) + 0.5
                let w0 = edge(points[1], points[2], sampleX, sampleY) / area
                let w1 = edge(points[2], points[0], sampleX, sampleY) / area
                let w2 = edge(points[0], points[1], sampleX, sampleY) / area
                guard
                    w0 >= -0.000_01,
                    w1 >= -0.000_01,
                    w2 >= -0.000_01
                else {
                    continue
                }
                let depth =
                    w0 * points[0].z
                    + w1 * points[1].z
                    + w2 * points[2].z
                let index = y * width + x
                if
                    depth < depths[index] - 0.000_1
                    || (
                        abs(depth - depths[index]) <= 0.000_1
                            && owner < owners[index]
                    )
                {
                    depths[index] = depth
                    owners[index] = owner
                }
            }
        }
    }

    private static func edge(
        _ a: SIMD3<Float>,
        _ b: SIMD3<Float>,
        _ x: Float,
        _ y: Float
    ) -> Float {
        (x - a.x) * (b.y - a.y) - (y - a.y) * (b.x - a.x)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map {
            String(format: "%02x", $0)
        }.joined()
    }
}
