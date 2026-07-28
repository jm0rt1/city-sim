import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum V15SupportError: Error, CustomStringConvertible {
    case failed(String)
    var description: String {
        switch self { case .failed(let message): return message }
    }
}

struct V15V3: Codable, Equatable {
    let x: Double
    let y: Double
    let z: Double
}

struct V15P2: Codable, Equatable {
    let x: Double
    let y: Double
}

struct V15Camera {
    let position: V15V3
    let target: V15V3
    let forward: V15V3
    let right: V15V3
    let up: V15V3
    let pixelsPerWorld: Double
    let viewport: CGSize
    let offset: V15P2
}

struct V15Mass: Codable, Equatable {
    let id: String
    let role: String
    let materialID: String
    let center: V15V3
    let size: V15V3
    let shape: String
    let radialSegments: Int

    init(
        id: String,
        role: String,
        materialID: String,
        center: V15V3,
        size: V15V3,
        shape: String = "box",
        radialSegments: Int = 12
    ) {
        self.id = id
        self.role = role
        self.materialID = materialID
        self.center = center
        self.size = size
        self.shape = shape
        self.radialSegments = radialSegments
    }
}

struct V15AABB: Codable, Equatable {
    let minimum: V15V3
    let maximum: V15V3

    init(center: V15V3, size: V15V3) {
        minimum = V15V3(
            x: center.x - size.x * 0.5,
            y: center.y - size.y * 0.5,
            z: center.z - size.z * 0.5
        )
        maximum = V15V3(
            x: center.x + size.x * 0.5,
            y: center.y + size.y * 0.5,
            z: center.z + size.z * 0.5
        )
    }
}

struct V15RecessedOpening {
    let id: String
    let centerX: Double
    let baseY: Double
    let width: Double
    let height: Double
    let wallZ: Double
    let wallDepth: Double
    let frameWidth: Double
    let frameTop: Double
    let sillHeight: Double
    let backset: Double
    let wallMaterialID: String
    let frameMaterialID: String
    let backMaterialID: String
    let role: String

    var aperture: V15AABB {
        V15AABB(
            center: V15V3(
                x: centerX,
                y: baseY + height * 0.5,
                z: wallZ
            ),
            size: V15V3(x: width, y: height, z: wallDepth)
        )
    }

    var insetBackPlane: V15Mass {
        V15Mass(
            id: "\(id)-inset-back-plane",
            role: "\(role)Back",
            materialID: backMaterialID,
            center: V15V3(
                x: centerX,
                y: baseY + height * 0.5,
                z: wallZ - wallDepth * 0.5 - backset
            ),
            size: V15V3(x: width, y: height, z: 0.8)
        )
    }

    func loweredPositiveMasses(sectionWidth: Double) throws -> [V15Mass] {
        guard
            width > 0,
            height > 0,
            wallDepth > 0,
            frameWidth > 0,
            frameTop > 0,
            sillHeight >= 0,
            backset > 0,
            sectionWidth > width + frameWidth * 2
        else {
            throw V15SupportError.failed("\(id) dimensions invalid")
        }
        let sectionHeight = sillHeight + height + frameTop
        let sideWidth = (sectionWidth - width) * 0.5
        let sideOffset = width * 0.5 + sideWidth * 0.5
        var values = [
            V15Mass(
                id: "\(id)-wall-left",
                role: "\(role)Wall",
                materialID: wallMaterialID,
                center: V15V3(
                    x: centerX - sideOffset,
                    y: sectionHeight * 0.5,
                    z: wallZ
                ),
                size: V15V3(
                    x: sideWidth,
                    y: sectionHeight,
                    z: wallDepth
                )
            ),
            V15Mass(
                id: "\(id)-wall-right",
                role: "\(role)Wall",
                materialID: wallMaterialID,
                center: V15V3(
                    x: centerX + sideOffset,
                    y: sectionHeight * 0.5,
                    z: wallZ
                ),
                size: V15V3(
                    x: sideWidth,
                    y: sectionHeight,
                    z: wallDepth
                )
            ),
            V15Mass(
                id: "\(id)-wall-header",
                role: "\(role)Header",
                materialID: wallMaterialID,
                center: V15V3(
                    x: centerX,
                    y: baseY + height + frameTop * 0.5,
                    z: wallZ
                ),
                size: V15V3(
                    x: width,
                    y: frameTop,
                    z: wallDepth
                )
            ),
        ]
        if sillHeight > 0 {
            values.append(
                V15Mass(
                    id: "\(id)-wall-sill",
                    role: "\(role)Sill",
                    materialID: wallMaterialID,
                    center: V15V3(
                        x: centerX,
                        y: sillHeight * 0.5,
                        z: wallZ
                    ),
                    size: V15V3(
                        x: width,
                        y: sillHeight,
                        z: wallDepth
                    )
                )
            )
        }
        let frontZ = wallZ + wallDepth * 0.5 + 0.45
        values += [
            V15Mass(
                id: "\(id)-jamb-left",
                role: "\(role)Jamb",
                materialID: frameMaterialID,
                center: V15V3(
                    x: centerX - width * 0.5 - frameWidth * 0.5,
                    y: baseY + height * 0.5,
                    z: frontZ
                ),
                size: V15V3(
                    x: frameWidth,
                    y: height + frameTop,
                    z: 0.9
                )
            ),
            V15Mass(
                id: "\(id)-jamb-right",
                role: "\(role)Jamb",
                materialID: frameMaterialID,
                center: V15V3(
                    x: centerX + width * 0.5 + frameWidth * 0.5,
                    y: baseY + height * 0.5,
                    z: frontZ
                ),
                size: V15V3(
                    x: frameWidth,
                    y: height + frameTop,
                    z: 0.9
                )
            ),
            V15Mass(
                id: "\(id)-lintel",
                role: "\(role)Lintel",
                materialID: frameMaterialID,
                center: V15V3(
                    x: centerX,
                    y: baseY + height + frameTop * 0.5,
                    z: frontZ
                ),
                size: V15V3(
                    x: width + frameWidth * 2,
                    y: frameTop,
                    z: 0.9
                )
            ),
            insetBackPlane,
        ]
        return values
    }
}

private struct V15Face {
    let mass: V15Mass
    let points: [V15P2]
    let depth: Double
    let shade: Double
}

func v15Add(_ lhs: V15V3, _ rhs: V15V3) -> V15V3 {
    V15V3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

func v15Subtract(_ lhs: V15V3, _ rhs: V15V3) -> V15V3 {
    V15V3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

func v15Scale(_ value: V15V3, _ scale: Double) -> V15V3 {
    V15V3(x: value.x * scale, y: value.y * scale, z: value.z * scale)
}

func v15Dot(_ lhs: V15V3, _ rhs: V15V3) -> Double {
    lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
}

func v15Cross(_ lhs: V15V3, _ rhs: V15V3) -> V15V3 {
    V15V3(
        x: lhs.y * rhs.z - lhs.z * rhs.y,
        y: lhs.z * rhs.x - lhs.x * rhs.z,
        z: lhs.x * rhs.y - lhs.y * rhs.x
    )
}

func v15Normalized(_ value: V15V3) throws -> V15V3 {
    let length = sqrt(v15Dot(value, value))
    guard length > 0.000_001 else {
        throw V15SupportError.failed("cannot normalize zero vector")
    }
    return v15Scale(value, 1 / length)
}

func v15StableJSON(_ value: Any) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    ) + Data([0x0A])
}

func v15SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func v15SHA256(_ url: URL) throws -> String {
    v15SHA256(try Data(contentsOf: url))
}

private func v15Vector(_ value: Any?, _ label: String) throws -> V15V3 {
    guard let numbers = value as? [NSNumber], numbers.count == 3 else {
        throw V15SupportError.failed("\(label) invalid")
    }
    return V15V3(
        x: numbers[0].doubleValue,
        y: numbers[1].doubleValue,
        z: numbers[2].doubleValue
    )
}

private func v15Pair(_ value: Any?, _ label: String) throws -> [Double] {
    guard let numbers = value as? [NSNumber], numbers.count == 2 else {
        throw V15SupportError.failed("\(label) invalid")
    }
    return numbers.map(\.doubleValue)
}

func v15Camera(from scene: [String: Any]) throws -> V15Camera {
    guard
        let value = scene["camera"] as? [String: Any],
        let scale = (value["orthographicScale"] as? NSNumber)?.doubleValue
    else {
        throw V15SupportError.failed("camera missing")
    }
    let position = try v15Vector(value["positionWorld"], "position")
    let target = try v15Vector(value["targetWorld"], "target")
    let viewport = try v15Pair(value["renderViewportPixels"], "viewport")
    let offset = try v15Pair(value["postProjectionOffsetPixels"], "offset")
    let forward = try v15Normalized(v15Subtract(target, position))
    let right = try v15Normalized(
        v15Cross(forward, V15V3(x: 0, y: 1, z: 0))
    )
    let up = try v15Normalized(v15Cross(right, forward))
    return V15Camera(
        position: position,
        target: target,
        forward: forward,
        right: right,
        up: up,
        pixelsPerWorld: viewport[1] / (2 * scale),
        viewport: CGSize(width: viewport[0], height: viewport[1]),
        offset: V15P2(x: offset[0], y: offset[1])
    )
}

func v15Project(
    _ point: V15V3,
    camera: V15Camera,
    size: CGSize
) -> V15P2 {
    let relative = v15Subtract(point, camera.target)
    let x = camera.viewport.width * 0.5
        + v15Dot(relative, camera.right) * camera.pixelsPerWorld
        + camera.offset.x
    let y = camera.viewport.height * 0.5
        - v15Dot(relative, camera.up) * camera.pixelsPerWorld
        + camera.offset.y
    return V15P2(
        x: x * Double(size.width / camera.viewport.width),
        y: y * Double(size.height / camera.viewport.height)
    )
}

func v15Overlaps(_ lhs: V15AABB, _ rhs: V15AABB) -> Bool {
    lhs.minimum.x < rhs.maximum.x && lhs.maximum.x > rhs.minimum.x
        && lhs.minimum.y < rhs.maximum.y && lhs.maximum.y > rhs.minimum.y
        && lhs.minimum.z < rhs.maximum.z && lhs.maximum.z > rhs.minimum.z
}

func v15RayHitDistance(
    origin: V15V3,
    direction: V15V3,
    box: V15AABB
) -> Double? {
    var near = -Double.infinity
    var far = Double.infinity
    for (o, d, minimum, maximum) in [
        (origin.x, direction.x, box.minimum.x, box.maximum.x),
        (origin.y, direction.y, box.minimum.y, box.maximum.y),
        (origin.z, direction.z, box.minimum.z, box.maximum.z),
    ] {
        if abs(d) < 0.000_001 {
            if o < minimum || o > maximum { return nil }
            continue
        }
        let first = (minimum - o) / d
        let second = (maximum - o) / d
        near = max(near, min(first, second))
        far = min(far, max(first, second))
        if near > far { return nil }
    }
    return far >= max(0, near) ? max(0, near) : nil
}

private func v15BoxVertices(_ mass: V15Mass) -> [V15V3] {
    let h = v15Scale(mass.size, 0.5)
    return [
        V15V3(x: mass.center.x - h.x, y: mass.center.y - h.y, z: mass.center.z - h.z),
        V15V3(x: mass.center.x + h.x, y: mass.center.y - h.y, z: mass.center.z - h.z),
        V15V3(x: mass.center.x + h.x, y: mass.center.y + h.y, z: mass.center.z - h.z),
        V15V3(x: mass.center.x - h.x, y: mass.center.y + h.y, z: mass.center.z - h.z),
        V15V3(x: mass.center.x - h.x, y: mass.center.y - h.y, z: mass.center.z + h.z),
        V15V3(x: mass.center.x + h.x, y: mass.center.y - h.y, z: mass.center.z + h.z),
        V15V3(x: mass.center.x + h.x, y: mass.center.y + h.y, z: mass.center.z + h.z),
        V15V3(x: mass.center.x - h.x, y: mass.center.y + h.y, z: mass.center.z + h.z),
    ]
}

private func v15Faces(
    _ mass: V15Mass,
    camera: V15Camera,
    size: CGSize
) throws -> [V15Face] {
    var definitions: [(V15V3, [V15V3])] = []
    if mass.shape == "cylinder" {
        let lowY = mass.center.y - mass.size.y * 0.5
        let highY = mass.center.y + mass.size.y * 0.5
        let ring: (Double) -> [V15V3] = { y in
            (0..<mass.radialSegments).map { index in
                let angle = Double(index) * 2 * .pi
                    / Double(mass.radialSegments) + .pi / 8
                return V15V3(
                    x: mass.center.x + cos(angle) * mass.size.x * 0.5,
                    y: y,
                    z: mass.center.z + sin(angle) * mass.size.z * 0.5
                )
            }
        }
        let low = ring(lowY)
        let high = ring(highY)
        definitions.append((V15V3(x: 0, y: 1, z: 0), high))
        for index in 0..<mass.radialSegments {
            let next = (index + 1) % mass.radialSegments
            let normal = try v15Normalized(
                V15V3(
                    x: (low[index].x + low[next].x) * 0.5 - mass.center.x,
                    y: 0,
                    z: (low[index].z + low[next].z) * 0.5 - mass.center.z
                )
            )
            definitions.append(
                (normal, [low[index], low[next], high[next], high[index]])
            )
        }
    } else {
        let v = v15BoxVertices(mass)
        definitions = [
            (V15V3(x: 0, y: 1, z: 0), [v[3], v[2], v[6], v[7]]),
            (V15V3(x: 1, y: 0, z: 0), [v[1], v[5], v[6], v[2]]),
            (V15V3(x: -1, y: 0, z: 0), [v[4], v[0], v[3], v[7]]),
            (V15V3(x: 0, y: 0, z: 1), [v[5], v[4], v[7], v[6]]),
            (V15V3(x: 0, y: 0, z: -1), [v[0], v[1], v[2], v[3]]),
        ]
    }
    let light = try v15Normalized(V15V3(x: -0.5, y: 0.82, z: -0.42))
    return definitions.compactMap { normal, vertices in
        if v15Dot(normal, camera.forward) >= 0.02 { return nil }
        let points = vertices.map { v15Project($0, camera: camera, size: size) }
        let depth = vertices.map {
            v15Dot(v15Subtract($0, camera.target), camera.forward)
        }.reduce(0, +) / Double(vertices.count)
        return V15Face(
            mass: mass,
            points: points,
            depth: depth,
            shade: 0.58 + 0.42 * max(0, v15Dot(normal, light))
        )
    }
}

private func v15Path(_ points: [V15P2]) -> CGPath {
    let path = CGMutablePath()
    guard let first = points.first else { return path }
    path.move(to: CGPoint(x: first.x, y: first.y))
    for point in points.dropFirst() {
        path.addLine(to: CGPoint(x: point.x, y: point.y))
    }
    path.closeSubpath()
    return path
}

private func v15Context(_ size: CGSize) throws -> CGContext {
    guard let value = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: Int(size.width) * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V15SupportError.failed("cannot create context")
    }
    value.translateBy(x: 0, y: size.height)
    value.scaleBy(x: 1, y: -1)
    return value
}

func v15Render(
    masses: [V15Mass],
    camera: V15Camera,
    palette: [String: [Double]],
    size: CGSize,
    grayscale: Bool
) throws -> CGImage {
    let context = try v15Context(size)
    context.setFillColor(CGColor(red: 0.105, green: 0.12, blue: 0.125, alpha: 1))
    context.fill(CGRect(origin: .zero, size: size))
    var faces: [V15Face] = []
    for mass in masses {
        faces += try v15Faces(mass, camera: camera, size: size)
    }
    faces.sort { $0.depth > $1.depth }
    for face in faces {
        let color = palette[face.mass.materialID] ?? [0.5, 0.5, 0.5, 1]
        let red = min(1, color[0] * face.shade)
        let green = min(1, color[1] * face.shade)
        let blue = min(1, color[2] * face.shade)
        let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        context.setFillColor(
            grayscale
                ? CGColor(gray: luma, alpha: 1)
                : CGColor(red: red, green: green, blue: blue, alpha: 1)
        )
        context.addPath(v15Path(face.points))
        context.fillPath()
        context.setStrokeColor(CGColor(gray: 0.025, alpha: 0.9))
        context.setLineWidth(max(0.45, Double(size.width) / 1000))
        context.addPath(v15Path(face.points))
        context.strokePath()
    }
    guard let image = context.makeImage() else {
        throw V15SupportError.failed("cannot make image")
    }
    return image
}

func v15WritePNG(_ image: CGImage, to url: URL) throws {
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
        throw V15SupportError.failed("cannot create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw V15SupportError.failed("cannot finalize PNG")
    }
}
