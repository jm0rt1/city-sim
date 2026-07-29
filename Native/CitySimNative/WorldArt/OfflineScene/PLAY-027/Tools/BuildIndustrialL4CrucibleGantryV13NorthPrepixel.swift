import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private enum V13Error: Error, CustomStringConvertible {
    case failed(String)
    var description: String {
        switch self { case .failed(let message): return message }
    }
}

private struct V3 {
    let x: Double
    let y: Double
    let z: Double
}

private struct P2 {
    let x: Double
    let y: Double
}

private struct Camera {
    let position: V3
    let target: V3
    let forward: V3
    let right: V3
    let up: V3
    let pixelsPerWorld: Double
    let viewport: CGSize
    let offset: P2
}

private struct Primitive {
    let id: String
    let materialID: String
    let center: V3
    let size: V3
    let shape: String
}

private struct Face {
    let primitiveID: String
    let materialID: String
    let role: String
    let points: [P2]
    let depth: Double
    let shade: Double
}

private let revision = "source-v13-prepixel"
private let geometryID =
    "industrial-l04-crucible-gantry-v13-n-cross-court-layout-02"
private let materialName =
    "industrial-l04-crucible-gantry-v13-north-prepixel.json"
private let sourceSize = CGSize(width: 1536, height: 1024)
private let nativeSize = CGSize(width: 384, height: 256)
private let compactSize = CGSize(width: 192, height: 128)
private let fixedTimestamp = "2026-07-27T00:00:00Z"

private func +(lhs: V3, rhs: V3) -> V3 {
    V3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

private func -(lhs: V3, rhs: V3) -> V3 {
    V3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

private func *(lhs: V3, rhs: Double) -> V3 {
    V3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
}

private func dot(_ lhs: V3, _ rhs: V3) -> Double {
    lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
}

private func cross(_ lhs: V3, _ rhs: V3) -> V3 {
    V3(
        x: lhs.y * rhs.z - lhs.z * rhs.y,
        y: lhs.z * rhs.x - lhs.x * rhs.z,
        z: lhs.x * rhs.y - lhs.y * rhs.x
    )
}

private func normalized(_ value: V3) throws -> V3 {
    let length = sqrt(dot(value, value))
    guard length > 0.000_001 else {
        throw V13Error.failed("cannot normalize zero vector")
    }
    return value * (1 / length)
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

private func stableJSON(_ value: Any) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    ) + Data([0x0A])
}

private func vector(_ value: Any?, _ label: String) throws -> V3 {
    guard let numbers = value as? [NSNumber], numbers.count == 3 else {
        throw V13Error.failed("\(label) must contain three numbers")
    }
    return V3(
        x: numbers[0].doubleValue,
        y: numbers[1].doubleValue,
        z: numbers[2].doubleValue
    )
}

private func pair(_ value: Any?, _ label: String) throws -> [Double] {
    guard let numbers = value as? [NSNumber], numbers.count == 2 else {
        throw V13Error.failed("\(label) must contain two numbers")
    }
    return numbers.map(\.doubleValue)
}

private func camera(_ scene: [String: Any]) throws -> Camera {
    guard
        let value = scene["camera"] as? [String: Any],
        let scale = (value["orthographicScale"] as? NSNumber)?.doubleValue
    else {
        throw V13Error.failed("camera contract missing")
    }
    let position = try vector(value["positionWorld"], "camera.positionWorld")
    let target = try vector(value["targetWorld"], "camera.targetWorld")
    let viewport = try pair(value["renderViewportPixels"], "camera.viewport")
    let offset = try pair(value["postProjectionOffsetPixels"], "camera.offset")
    let forward = try normalized(target - position)
    let right = try normalized(cross(forward, V3(x: 0, y: 1, z: 0)))
    let up = try normalized(cross(right, forward))
    return Camera(
        position: position,
        target: target,
        forward: forward,
        right: right,
        up: up,
        pixelsPerWorld: viewport[1] / (2 * scale),
        viewport: CGSize(width: viewport[0], height: viewport[1]),
        offset: P2(x: offset[0], y: offset[1])
    )
}

private func project(_ point: V3, camera: Camera, size: CGSize) -> P2 {
    let relative = point - camera.target
    let sourceX = camera.viewport.width * 0.5
        + dot(relative, camera.right) * camera.pixelsPerWorld
        + camera.offset.x
    let sourceY = camera.viewport.height * 0.5
        - dot(relative, camera.up) * camera.pixelsPerWorld
        + camera.offset.y
    return P2(
        x: sourceX * Double(size.width / camera.viewport.width),
        y: sourceY * Double(size.height / camera.viewport.height)
    )
}

private func vertices(_ item: Primitive) -> [V3] {
    let h = item.size * 0.5
    return [
        V3(x: item.center.x - h.x, y: item.center.y - h.y, z: item.center.z - h.z),
        V3(x: item.center.x + h.x, y: item.center.y - h.y, z: item.center.z - h.z),
        V3(x: item.center.x + h.x, y: item.center.y + h.y, z: item.center.z - h.z),
        V3(x: item.center.x - h.x, y: item.center.y + h.y, z: item.center.z - h.z),
        V3(x: item.center.x - h.x, y: item.center.y - h.y, z: item.center.z + h.z),
        V3(x: item.center.x + h.x, y: item.center.y - h.y, z: item.center.z + h.z),
        V3(x: item.center.x + h.x, y: item.center.y + h.y, z: item.center.z + h.z),
        V3(x: item.center.x - h.x, y: item.center.y + h.y, z: item.center.z + h.z),
    ]
}

private func faces(
    _ item: Primitive,
    camera: Camera,
    size: CGSize
) throws -> [Face] {
    let definitions: [(String, V3, [V3])]
    if item.shape == "tapered-octagonal-vessel" {
        let radiusX = item.size.x * 0.5
        let radiusZ = item.size.z * 0.5
        let bottom = item.center.y - item.size.y * 0.5
        let shoulder = bottom + item.size.y * 0.32
        let top = item.center.y + item.size.y * 0.5
        func ring(y: Double, scale: Double) -> [V3] {
            (0..<8).map { index in
                let angle = Double(index) * .pi / 4 + .pi / 8
                return V3(
                    x: item.center.x + cos(angle) * radiusX * scale,
                    y: y,
                    z: item.center.z + sin(angle) * radiusZ * scale
                )
            }
        }
        let bottomRing = ring(y: bottom, scale: 0.58)
        let shoulderRing = ring(y: shoulder, scale: 1)
        let mouthRing = ring(y: top, scale: 0.72)
        var vesselFaces: [(String, V3, [V3])] = []
        for index in 0..<8 {
            let next = (index + 1) % 8
            let lowerA = bottomRing[index]
            let lowerB = bottomRing[next]
            let shoulderA = shoulderRing[index]
            let shoulderB = shoulderRing[next]
            let mouthA = mouthRing[index]
            let mouthB = mouthRing[next]
            let normal = try normalized(
                V3(
                    x: (shoulderA.x + shoulderB.x) * 0.5 - item.center.x,
                    y: 0,
                    z: (shoulderA.z + shoulderB.z) * 0.5 - item.center.z
                )
            )
            vesselFaces.append(
                (
                    "lower-taper-plane-\(index + 1)",
                    normal,
                    [lowerA, lowerB, shoulderB, shoulderA]
                )
            )
            vesselFaces.append(
                (
                    "upper-shoulder-plane-\(index + 1)",
                    normal,
                    [shoulderA, shoulderB, mouthB, mouthA]
                )
            )
        }
        vesselFaces.append(
            ("mouth", V3(x: 0, y: 1, z: 0), mouthRing)
        )
        definitions = vesselFaces
    } else if item.shape == "octagonal-prism" {
        let radiusX = item.size.x * 0.5
        let radiusZ = item.size.z * 0.5
        let bottom = item.center.y - item.size.y * 0.5
        let top = item.center.y + item.size.y * 0.5
        let ring = (0..<8).map { index -> V3 in
            let angle = Double(index) * .pi / 4 + .pi / 8
            return V3(
                x: item.center.x + cos(angle) * radiusX,
                y: bottom,
                z: item.center.z + sin(angle) * radiusZ
            )
        }
        var octagonalFaces: [(String, V3, [V3])] = []
        for index in 0..<8 {
            let next = (index + 1) % 8
            let a = ring[index]
            let b = ring[next]
            let topA = V3(x: a.x, y: top, z: a.z)
            let topB = V3(x: b.x, y: top, z: b.z)
            let normal = try normalized(
                V3(
                    x: (a.x + b.x) * 0.5 - item.center.x,
                    y: 0,
                    z: (a.z + b.z) * 0.5 - item.center.z
                )
            )
            octagonalFaces.append(
                ("machinery-plane-\(index + 1)", normal, [a, b, topB, topA])
            )
        }
        octagonalFaces.append(
            (
                "top",
                V3(x: 0, y: 1, z: 0),
                ring.map { V3(x: $0.x, y: top, z: $0.z) }
            )
        )
        definitions = octagonalFaces
    } else if item.shape == "sawtooth-band" {
        let h = item.size * 0.5
        let x0 = item.center.x - h.x
        let y0 = item.center.y - h.y
        let y1 = item.center.y + h.y
        let front = item.center.z - h.z
        let back = item.center.z + h.z
        let bay = item.size.x / 4
        var profile: [(x: Double, y: Double)] = [(x0, y0)]
        for index in 0..<4 {
            profile.append((x0 + (Double(index) + 0.5) * bay, y1))
            profile.append((x0 + Double(index + 1) * bay, y0))
        }
        var bandFaces: [(String, V3, [V3])] = []
        for index in 0..<(profile.count - 1) {
            let a = profile[index]
            let b = profile[index + 1]
            let slope = V3(x: b.x - a.x, y: b.y - a.y, z: 0)
            let depth = V3(x: 0, y: 0, z: back - front)
            let normal = try normalized(cross(depth, slope))
            let role = normal.x < 0
                ? "northwest-plane-\(index / 2 + 1)"
                : "southeast-plane-\(index / 2 + 1)"
            bandFaces.append((role, normal, [
                V3(x: a.x, y: a.y, z: front),
                V3(x: b.x, y: b.y, z: front),
                V3(x: b.x, y: b.y, z: back),
                V3(x: a.x, y: a.y, z: back),
            ]))
        }
        definitions = bandFaces
    } else if item.shape == "hip" {
        let h = item.size * 0.5
        let y0 = item.center.y - h.y
        let y1 = item.center.y + h.y
        let left = item.center.x - h.x
        let right = item.center.x + h.x
        let front = item.center.z - h.z
        let back = item.center.z + h.z
        let apex = V3(x: item.center.x, y: y1, z: item.center.z)
        definitions = [
            ("west-plane", V3(x: -0.74, y: 0.67, z: 0), [
                V3(x: left, y: y0, z: back),
                V3(x: left, y: y0, z: front),
                apex,
            ]),
            ("northwest-plane", V3(x: 0.74, y: 0.67, z: 0), [
                V3(x: right, y: y0, z: front),
                V3(x: right, y: y0, z: back),
                apex,
            ]),
            ("north-plane", V3(x: 0, y: 0.67, z: -0.74), [
                V3(x: left, y: y0, z: front),
                V3(x: right, y: y0, z: front),
                apex,
            ]),
            ("southeast-plane", V3(x: 0, y: 0.67, z: 0.74), [
                V3(x: right, y: y0, z: back),
                V3(x: left, y: y0, z: back),
                apex,
            ]),
        ]
    } else {
        let v = vertices(item)
        definitions = [
            ("west", V3(x: -1, y: 0, z: 0), [v[0], v[4], v[7], v[3]]),
            ("east", V3(x: 1, y: 0, z: 0), [v[1], v[2], v[6], v[5]]),
            ("bottom", V3(x: 0, y: -1, z: 0), [v[0], v[1], v[5], v[4]]),
            ("top", V3(x: 0, y: 1, z: 0), [v[3], v[7], v[6], v[2]]),
            ("north", V3(x: 0, y: 0, z: -1), [v[0], v[3], v[2], v[1]]),
            ("south", V3(x: 0, y: 0, z: 1), [v[4], v[5], v[6], v[7]]),
        ]
    }
    return definitions.compactMap { role, normal, world in
        let center = world.reduce(V3(x: 0, y: 0, z: 0), +)
            * (1 / Double(world.count))
        guard dot(normal, camera.position - center) > 0.000_001 else {
            return nil
        }
        let shade: Double
        if role.hasPrefix("northwest-plane") {
            shade = 1.04
        } else if role.hasPrefix("southeast-plane") {
            shade = 0.72
        } else if role.contains("plane") {
            shade = 0.84
        } else {
            shade = role == "top" ? 0.96 : (role == "east" ? 0.82 : 0.74)
        }
        return Face(
            primitiveID: item.id,
            materialID: item.materialID,
            role: role,
            points: world.map { project($0, camera: camera, size: size) },
            depth: world.map { dot($0 - camera.target, camera.forward) }
                .reduce(0, +) / Double(world.count),
            shade: shade
        )
    }
}

private func primitives(_ scene: [String: Any]) throws -> [Primitive] {
    guard let building = scene["building"] as? [String: Any] else {
        throw V13Error.failed("building missing")
    }
    var result: [Primitive] = []
    func append(
        _ id: String,
        _ material: String,
        _ dimensions: Any?,
        _ position: Any?,
        _ shape: String = "box"
    ) throws {
        let size = try vector(dimensions, "\(id).dimensions")
        guard size.x > 0, size.y > 0, size.z > 0 else {
            throw V13Error.failed("\(id) dimensions invalid")
        }
        result.append(
            Primitive(
                id: id,
                materialID: material,
                center: try vector(position, "\(id).position"),
                size: size,
                shape: shape
            )
        )
    }
    try append(
        "i04-v13-n-foundation",
        building["foundationMaterialID"] as! String,
        building["foundationDimensions"],
        building["foundationPositionWorld"]
    )
    for item in building["massBlocks"] as? [[String: Any]] ?? [] {
        try append(
            item["id"] as! String,
            item["materialID"] as! String,
            item["dimensions"],
            item["positionWorld"],
            item["shape"] as? String ?? "box"
        )
    }
    for item in building["roofVolumes"] as? [[String: Any]] ?? [] {
        try append(
            item["id"] as! String,
            item["materialID"] as! String,
            item["dimensions"],
            item["positionWorld"],
            item["shape"] as? String ?? "box"
        )
    }
    for item in building["trimBands"] as? [[String: Any]] ?? [] {
        try append(
            item["id"] as! String,
            item["materialID"] as! String,
            item["dimensions"],
            item["positionWorld"]
        )
    }
    return result
}

private func colors(_ library: [String: Any]) throws -> [String: [Double]] {
    guard let materials = library["materials"] as? [[String: Any]] else {
        throw V13Error.failed("materials missing")
    }
    return try Dictionary(uniqueKeysWithValues: materials.map {
        guard
            let id = $0["id"] as? String,
            let rgba = $0["baseColorRGBA"] as? [NSNumber],
            rgba.count == 4
        else {
            throw V13Error.failed("material color invalid")
        }
        return (id, rgba.map(\.doubleValue))
    })
}

private func lumaByte(_ rgba: [Double], shade: Double) -> Int {
    let red = min(1, rgba[0] * shade)
    let green = min(1, rgba[1] * shade)
    let blue = min(1, rgba[2] * shade)
    return Int(
        (255 * (0.2126 * red + 0.7152 * green + 0.0722 * blue)).rounded()
    )
}

private func drawingContext(
    width: Int,
    height: Int,
    flipped: Bool
) throws -> CGContext {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V13Error.failed("cannot allocate bitmap")
    }
    if flipped {
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
    }
    context.setShouldAntialias(false)
    context.setFillColor(CGColor(red: 0.12, green: 0.13, blue: 0.14, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context
}

private func path(_ points: [P2]) -> CGPath {
    let value = CGMutablePath()
    value.move(to: CGPoint(x: points[0].x, y: points[0].y))
    for point in points.dropFirst() {
        value.addLine(to: CGPoint(x: point.x, y: point.y))
    }
    value.closeSubpath()
    return value
}

private enum RenderMode {
    case color
    case grayscale
    case clay
    case semantic
    case valueSemantic
    case heroMask
    case buildingTopMask
}

private func render(
    scene: [String: Any],
    library: [String: Any],
    size: CGSize,
    mode: RenderMode
) throws -> CGImage {
    let cameraValue = try camera(scene)
    let materialColors = try colors(library)
    let items = try primitives(scene)
    var collected: [(Primitive, Face)] = []
    for item in items {
        if mode == .heroMask {
            let isHero = item.id.contains("gantry-")
                || item.id.contains("crucible")
            if !isHero { continue }
        } else if mode == .buildingTopMask {
            let excluded = item.id.contains("boiler-stack")
                || item.id.contains("foundation")
                || item.id.contains("apron")
            if excluded { continue }
        }
        collected += try faces(item, camera: cameraValue, size: size)
            .map { (item, $0) }
    }
    collected.sort { $0.1.depth > $1.1.depth }
    let context = try drawingContext(
        width: Int(size.width),
        height: Int(size.height),
        flipped: true
    )
    if mode == .heroMask || mode == .buildingTopMask {
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
    }
    for (item, face) in collected {
        let rgba: [Double]
        switch mode {
        case .heroMask, .buildingTopMask:
            rgba = [1, 1, 1, 1]
        case .clay:
            rgba = [0.54, 0.49, 0.42, 1]
        case .semantic:
            if item.id.contains("gantry-bridge-beam") {
                rgba = [0.94, 0.79, 0.16, 1]
            } else if item.id.contains("gantry-pier-west") {
                rgba = [0.91, 0.21, 0.21, 1]
            } else if item.id.contains("gantry-pier-east") {
                rgba = [0.19, 0.71, 0.92, 1]
            } else if item.id.contains("crucible-mouth") {
                rgba = [0.98, 0.18, 0.06, 1]
            } else if item.id.contains("crucible") {
                rgba = [0.90, 0.44, 0.12, 1]
            } else if item.id.contains("staff-entry") {
                rgba = [0.92, 0.18, 0.82, 1]
            } else if item.id.contains("freight-beat-1") {
                rgba = [0.10, 0.86, 0.90, 1]
            } else if item.id.contains("freight-beat-2") {
                rgba = [0.15, 0.90, 0.44, 1]
            } else if item.id.contains("freight-beat-3") {
                rgba = [0.16, 0.44, 0.94, 1]
            } else if item.id.contains("foundry-hall") {
                rgba = [0.48, 0.18, 0.64, 1]
            } else if item.id.contains("control-annex") {
                rgba = [0.33, 0.70, 0.36, 1]
            } else {
                rgba = [0.30, 0.30, 0.32, 1]
            }
        case .valueSemantic:
            if item.id.contains("low-foundry-roof") {
                rgba = [0.95, 0.10, 0.10, 1]
            } else if item.id.contains("foundry-hall") {
                rgba = [0.10, 0.92, 0.10, 1]
            } else if item.id.contains("gantry-") {
                rgba = [0.10, 0.20, 0.95, 1]
            } else if item.id.contains("crucible") {
                rgba = [0.95, 0.85, 0.10, 1]
            } else if item.id.contains("freight-beat")
                && item.id.contains("recess")
            {
                rgba = [0.90, 0.10, 0.85, 1]
            } else if item.id.contains("freight-beat") {
                rgba = [0.10, 0.90, 0.90, 1]
            } else {
                rgba = [0.30, 0.30, 0.32, 1]
            }
        case .color, .grayscale:
            rgba = materialColors[face.materialID] ?? [0.5, 0.5, 0.5, 1]
        }
        let shade =
            mode == .semantic || mode == .valueSemantic
                || mode == .heroMask || mode == .buildingTopMask
            ? 1
            : face.shade
        let red = min(1, rgba[0] * shade)
        let green = min(1, rgba[1] * shade)
        let blue = min(1, rgba[2] * shade)
        let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        context.setFillColor(
            mode == .grayscale
                ? CGColor(gray: luma, alpha: 1)
                : CGColor(red: red, green: green, blue: blue, alpha: 1)
        )
        context.addPath(path(face.points))
        context.fillPath()
    }
    guard let image = context.makeImage() else {
        throw V13Error.failed("cannot create image")
    }
    return image
}

private func writePNG(_ image: CGImage, _ url: URL) throws {
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
        throw V13Error.failed("cannot create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw V13Error.failed("cannot finalize PNG")
    }
}

private func decoded(_ image: CGImage) throws -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    guard let context = CGContext(
        data: &bytes,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V13Error.failed("cannot decode image")
    }
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    return bytes
}

private func connectedComponents(
    bytes: [UInt8],
    width: Int,
    height: Int
) -> (count: Int, pixels: Int) {
    var active = [Bool](repeating: false, count: width * height)
    for y in 0..<height {
        for x in 0..<width {
            let pixel = y * width + x
            let index = pixel * 4
            active[pixel] = bytes[index] > 220
                && bytes[index + 1] > 220
                && bytes[index + 2] > 220
        }
    }
    var visited = [Bool](repeating: false, count: active.count)
    var componentCount = 0
    var activeCount = 0
    for start in active.indices where active[start] {
        activeCount += 1
        if visited[start] { continue }
        componentCount += 1
        var queue = [start]
        visited[start] = true
        var cursor = 0
        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            let x = current % width
            let y = current / width
            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let nx = x + dx
                let ny = y + dy
                guard nx >= 0, nx < width, ny >= 0, ny < height else {
                    continue
                }
                let next = ny * width + nx
                if active[next] && !visited[next] {
                    visited[next] = true
                    queue.append(next)
                }
            }
        }
    }
    return (componentCount, activeCount)
}

private func silhouetteIoU(
    candidateMask: [UInt8],
    acceptedImage: [UInt8]
) -> Double {
    precondition(candidateMask.count == acceptedImage.count)
    var intersection = 0
    var union = 0
    for index in stride(from: 0, to: candidateMask.count, by: 4) {
        let candidate = candidateMask[index] > 220
            && candidateMask[index + 1] > 220
            && candidateMask[index + 2] > 220
        let redDelta = abs(Int(acceptedImage[index]) - 31)
        let greenDelta = abs(Int(acceptedImage[index + 1]) - 33)
        let blueDelta = abs(Int(acceptedImage[index + 2]) - 36)
        let accepted = max(redDelta, greenDelta, blueDelta) > 10
        if candidate || accepted { union += 1 }
        if candidate && accepted { intersection += 1 }
    }
    return union == 0 ? 0 : Double(intersection) / Double(union)
}

private func bounds(
    bytes: [UInt8],
    width: Int,
    height: Int,
    predicate: (UInt8, UInt8, UInt8) -> Bool
) -> CGRect {
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    for y in 0..<height {
        for x in 0..<width {
            let index = (y * width + x) * 4
            if predicate(bytes[index], bytes[index + 1], bytes[index + 2]) {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }
    return maxX >= minX
        ? CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        : .null
}

private func matchingPixelCount(
    bytes: [UInt8],
    predicate: (UInt8, UInt8, UInt8) -> Bool
) -> Int {
    stride(from: 0, to: bytes.count, by: 4).reduce(into: 0) {
        if predicate(bytes[$1], bytes[$1 + 1], bytes[$1 + 2]) {
            $0 += 1
        }
    }
}

private func medianLuma(
    colorBytes: [UInt8],
    semanticBytes: [UInt8],
    predicate: (UInt8, UInt8, UInt8) -> Bool
) -> Int? {
    precondition(colorBytes.count == semanticBytes.count)
    var values: [Int] = []
    for index in stride(from: 0, to: colorBytes.count, by: 4) {
        guard predicate(
            semanticBytes[index],
            semanticBytes[index + 1],
            semanticBytes[index + 2]
        ) else {
            continue
        }
        let red = 0.2126 * Double(colorBytes[index])
        let green = 0.7152 * Double(colorBytes[index + 1])
        let blue = 0.0722 * Double(colorBytes[index + 2])
        values.append(Int((red + green + blue).rounded()))
    }
    guard !values.isEmpty else { return nil }
    values.sort()
    return values[values.count / 2]
}

private func topBoundary(
    bytes: [UInt8],
    width: Int,
    height: Int
) -> [Int?] {
    (0..<width).map { x in
        for y in 0..<height {
            let index = (y * width + x) * 4
            if bytes[index] > 220
                && bytes[index + 1] > 220
                && bytes[index + 2] > 220
            {
                return y
            }
        }
        return nil
    }
}

private func sampledTop(
    _ profile: [Int?],
    around x: Double,
    radius: Int
) -> Int? {
    let center = Int(x.rounded())
    let lower = max(0, center - radius)
    let upper = min(profile.count - 1, center + radius)
    return (lower...upper).compactMap { profile[$0] }.min()
}

private func topProfileOverlay(
    _ mask: CGImage,
    peaks: [P2],
    valleys: [P2]
) throws -> CGImage {
    let context = try drawingContext(
        width: mask.width,
        height: mask.height,
        flipped: false
    )
    context.draw(
        mask,
        in: CGRect(x: 0, y: 0, width: mask.width, height: mask.height)
    )
    context.saveGState()
    context.translateBy(x: 0, y: CGFloat(mask.height))
    context.scaleBy(x: 1, y: -1)
    for point in peaks {
        context.setFillColor(CGColor(red: 0.10, green: 0.95, blue: 0.35, alpha: 1))
        context.fillEllipse(
            in: CGRect(x: point.x - 2, y: point.y - 2, width: 5, height: 5)
        )
    }
    for point in valleys {
        context.setFillColor(CGColor(red: 0.20, green: 0.55, blue: 1, alpha: 1))
        context.fillEllipse(
            in: CGRect(x: point.x - 2, y: point.y - 2, width: 5, height: 5)
        )
    }
    context.restoreGState()
    guard let output = context.makeImage() else {
        throw V13Error.failed("cannot make all-building top-profile overlay")
    }
    return output
}

private func neutralizedRaw(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw V13Error.failed("cannot decode retained v08 raw")
    }
    var bytes = try decoded(image)
    for index in stride(from: 0, to: bytes.count, by: 4) {
        if bytes[index] == 255 && bytes[index + 1] == 0 && bytes[index + 2] == 255 {
            bytes[index] = 31
            bytes[index + 1] = 33
            bytes[index + 2] = 36
        }
    }
    guard let context = CGContext(
        data: &bytes,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let output = context.makeImage() else {
        throw V13Error.failed("cannot neutralize retained v08 raw")
    }
    return output
}

private func loadImage(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw V13Error.failed("cannot decode comparison image \(url.path)")
    }
    return image
}

private func scaled(_ image: CGImage, to size: CGSize) throws -> CGImage {
    let context = try drawingContext(
        width: Int(size.width),
        height: Int(size.height),
        flipped: false
    )
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(origin: .zero, size: size))
    guard let output = context.makeImage() else {
        throw V13Error.failed("cannot scale comparison")
    }
    return output
}

private func threeWay(
    _ a: CGImage,
    _ b: CGImage,
    _ c: CGImage,
    size: CGSize
) throws -> CGImage {
    let context = try drawingContext(
        width: Int(size.width * 3),
        height: Int(size.height),
        flipped: false
    )
    context.interpolationQuality = .none
    for (index, image) in [a, b, c].enumerated() {
        context.draw(
            image,
            in: CGRect(
                x: CGFloat(index) * size.width,
                y: 0,
                width: size.width,
                height: size.height
            )
        )
    }
    context.setStrokeColor(CGColor(gray: 0.9, alpha: 1))
    context.setLineWidth(2)
    for index in [1, 2] {
        context.move(to: CGPoint(x: CGFloat(index) * size.width, y: 0))
        context.addLine(
            to: CGPoint(x: CGFloat(index) * size.width, y: size.height)
        )
    }
    context.strokePath()
    guard let output = context.makeImage() else {
        throw V13Error.failed("cannot make three-way comparison")
    }
    return output
}

private func fourWay(
    _ a: CGImage,
    _ b: CGImage,
    _ c: CGImage,
    _ d: CGImage,
    size: CGSize
) throws -> CGImage {
    let context = try drawingContext(
        width: Int(size.width * 4),
        height: Int(size.height),
        flipped: false
    )
    context.interpolationQuality = .none
    for (index, image) in [a, b, c, d].enumerated() {
        context.draw(
            image,
            in: CGRect(
                x: CGFloat(index) * size.width,
                y: 0,
                width: size.width,
                height: size.height
            )
        )
    }
    context.setStrokeColor(CGColor(gray: 0.9, alpha: 1))
    context.setLineWidth(2)
    for index in [1, 2, 3] {
        context.move(to: CGPoint(x: CGFloat(index) * size.width, y: 0))
        context.addLine(
            to: CGPoint(x: CGFloat(index) * size.width, y: size.height)
        )
    }
    context.strokePath()
    guard let output = context.makeImage() else {
        throw V13Error.failed("cannot make four-way comparison")
    }
    return output
}

private func fiveWay(
    _ images: [CGImage],
    size: CGSize
) throws -> CGImage {
    guard images.count == 5 else {
        throw V13Error.failed("five-way comparison requires five images")
    }
    let context = try drawingContext(
        width: Int(size.width * 5),
        height: Int(size.height),
        flipped: false
    )
    context.interpolationQuality = .none
    for (index, image) in images.enumerated() {
        context.draw(
            image,
            in: CGRect(
                x: CGFloat(index) * size.width,
                y: 0,
                width: size.width,
                height: size.height
            )
        )
    }
    context.setStrokeColor(CGColor(gray: 0.9, alpha: 1))
    context.setLineWidth(2)
    for index in 1..<5 {
        context.move(to: CGPoint(x: CGFloat(index) * size.width, y: 0))
        context.addLine(
            to: CGPoint(x: CGFloat(index) * size.width, y: size.height)
        )
    }
    context.strokePath()
    guard let output = context.makeImage() else {
        throw V13Error.failed("cannot make five-way comparison")
    }
    return output
}

private func twoWay(
    _ a: CGImage,
    _ b: CGImage,
    size: CGSize
) throws -> CGImage {
    let context = try drawingContext(
        width: Int(size.width * 2),
        height: Int(size.height),
        flipped: false
    )
    context.interpolationQuality = .none
    context.draw(a, in: CGRect(origin: .zero, size: size))
    context.draw(
        b,
        in: CGRect(x: size.width, y: 0, width: size.width, height: size.height)
    )
    context.setStrokeColor(CGColor(gray: 0.9, alpha: 1))
    context.setLineWidth(2)
    context.move(to: CGPoint(x: size.width, y: 0))
    context.addLine(to: CGPoint(x: size.width, y: size.height))
    context.strokePath()
    guard let output = context.makeImage() else {
        throw V13Error.failed("cannot make two-way comparison")
    }
    return output
}

private func registrationOverlay(
    _ image: CGImage,
    scene: [String: Any]
) throws -> CGImage {
    guard
        let registration = scene["registration"] as? [String: Any],
        let footprint = registration["footprintPolygonSource"] as? [[NSNumber]],
        let frontage = registration["frontageEdgeSource"] as? [[NSNumber]],
        let pivot = registration["groundPivotSource"] as? [NSNumber],
        let socket = registration["frontageSocketSource"] as? [NSNumber],
        let door = registration["doorBaseSource"] as? [[NSNumber]],
        let light = scene["light"] as? [String: Any],
        let shadow = light["shadowVectorSource"] as? [NSNumber]
    else {
        throw V13Error.failed("registration overlay contract missing")
    }
    let context = try drawingContext(
        width: image.width,
        height: image.height,
        flipped: false
    )
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    context.saveGState()
    context.translateBy(x: 0, y: CGFloat(image.height))
    context.scaleBy(x: 1, y: -1)
    func stroke(_ points: [[NSNumber]], _ color: CGColor, close: Bool = false) {
        guard let first = points.first else { return }
        context.setStrokeColor(color)
        context.setLineWidth(4)
        context.move(to: CGPoint(x: first[0].doubleValue, y: first[1].doubleValue))
        for point in points.dropFirst() {
            context.addLine(
                to: CGPoint(x: point[0].doubleValue, y: point[1].doubleValue)
            )
        }
        if close { context.closePath() }
        context.strokePath()
    }
    stroke(footprint, CGColor(red: 0.95, green: 0.78, blue: 0.16, alpha: 1), close: true)
    stroke(frontage, CGColor(red: 0.10, green: 0.88, blue: 0.92, alpha: 1))
    stroke(door, CGColor(red: 0.20, green: 0.92, blue: 0.36, alpha: 1))
    func marker(_ point: [NSNumber], _ color: CGColor) {
        context.setFillColor(color)
        context.fillEllipse(
            in: CGRect(
                x: point[0].doubleValue - 7,
                y: point[1].doubleValue - 7,
                width: 14,
                height: 14
            )
        )
    }
    marker(pivot, CGColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 1))
    marker(socket, CGColor(red: 0.22, green: 0.48, blue: 1, alpha: 1))
    context.setStrokeColor(CGColor(red: 0.95, green: 0.48, blue: 0.12, alpha: 1))
    context.setLineWidth(4)
    context.move(to: CGPoint(x: pivot[0].doubleValue, y: pivot[1].doubleValue))
    context.addLine(
        to: CGPoint(
            x: pivot[0].doubleValue + shadow[0].doubleValue * 32,
            y: pivot[1].doubleValue + shadow[1].doubleValue * 32
        )
    )
    context.strokePath()
    context.restoreGState()
    guard let output = context.makeImage() else {
        throw V13Error.failed("cannot make registration proof")
    }
    return output
}

private func replaceV10(_ value: Any) -> Any {
    if let string = value as? String {
        return string
            .replacingOccurrences(of: "source-v10-prepixel", with: revision)
            .replacingOccurrences(of: "i04-v10-n-", with: "i04-v13-n-")
            .replacingOccurrences(
                of: "turbine-works-v10-north-continuous-four-cycle-sawtooth-band",
                with: "crucible-gantry-works-v13-north"
            )
    }
    if let array = value as? [Any] { return array.map(replaceV10) }
    if let dictionary = value as? [String: Any] {
        return dictionary.mapValues(replaceV10)
    }
    return value
}

private func mutateLibrary(_ v10: [String: Any]) throws -> [String: Any] {
    guard var library = replaceV10(v10) as? [String: Any] else {
        throw V13Error.failed("cannot clone v10 material library")
    }
    library["libraryID"] = "industrial-l04-crucible-gantry-v13-north-prepixel"
    library["source"] =
        "task-owned Crucible Gantry Works palette; no ImageGen or raster swatch"
    guard var materials = library["materials"] as? [[String: Any]] else {
        throw V13Error.failed("v10 material inventory missing")
    }
    let mapping: [[String: Any]] = [
        [
            "id": "l4g-v13-warm-masonry",
            "baseColorRGBA": [0.72, 0.54, 0.38, 1],
            "roughness": 0.94,
            "metalness": 0,
            "pattern": "weathered-heavy-foundry-masonry",
            "physicalScaleWorld": [12, 12],
        ],
        [
            "id": "l4g-v13-dark-gantry-steel",
            "baseColorRGBA": [0.12, 0.17, 0.18, 1],
            "roughness": 0.78,
            "metalness": 0.42,
            "pattern": "heavy-riveted-blue-green-steel",
            "physicalScaleWorld": [10, 10],
        ],
        [
            "id": "l4g-v13-oxidized-copper-machinery",
            "baseColorRGBA": [0.48, 0.33, 0.18, 1],
            "roughness": 0.82,
            "metalness": 0.46,
            "pattern": "mid-value-oxidized-copper-machinery",
            "physicalScaleWorld": [10, 10],
        ],
        [
            "id": "l4g-v13-dark-roof-steel",
            "baseColorRGBA": [0.20, 0.29, 0.29, 1],
            "roughness": 0.88,
            "metalness": 0.28,
            "pattern": "weathered-low-foundry-roof",
            "physicalScaleWorld": [12, 12],
        ],
        [
            "id": "l4g-v13-freight-header-steel",
            "baseColorRGBA": [0.38, 0.43, 0.36, 1],
            "roughness": 0.84,
            "metalness": 0.30,
            "pattern": "weathered-loading-header-steel",
            "physicalScaleWorld": [10, 10],
        ],
        [
            "id": "l4g-v13-restrained-green",
            "baseColorRGBA": [0.29, 0.40, 0.33, 1],
            "roughness": 0.86,
            "metalness": 0.22,
            "pattern": "restrained-green-boiler-steel",
            "physicalScaleWorld": [10, 10],
        ],
        [
            "id": "l4g-v13-staff-glazing",
            "baseColorRGBA": [0.52, 0.68, 0.66, 1],
            "roughness": 0.44,
            "metalness": 0.06,
            "pattern": "warm-lit-control-glazing",
            "physicalScaleWorld": [8, 8],
        ],
    ]
    let mappingDefaults = [
        "textureMapping": [
            "mode": "world-scale-box-face-repeat-v1",
            "wrapS": "repeat",
            "wrapT": "repeat",
            "minificationFilter": "linear",
            "magnificationFilter": "linear",
            "mipFilter": "linear",
        ],
    ]
    materials += mapping.map { item in
        item.merging(mappingDefaults) { current, _ in current }
    }
    library["materials"] = materials
    return library
}

private func mutateScene(
    _ v10: [String: Any],
    materialSHA: String
) throws -> [String: Any] {
    guard var scene = replaceV10(v10) as? [String: Any] else {
        throw V13Error.failed("cannot clone v10 scene")
    }
    scene["sourceRevision"] = revision
    scene["sceneGeometryID"] = geometryID
    scene["sourceAuthority"] = false
    scene["productionSelected"] = false
    scene["derivation"] = [
        "sourceKind": "offline-scene-v13-crucible-gantry-architectural-reset",
        "siblingSource": NSNull(),
        "mirror": false,
        "rotationDegrees": 0,
        "transform": "none",
    ]
    scene["materialLibrary"] = [
        "role": "industrial-l04-crucible-gantry-v13-north-material-library",
        "file": "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-crucible-gantry-v13-north-prepixel/materials/\(materialName)",
        "sha256": materialSHA,
    ]
    if var sampling = scene["sampling"] as? [String: Any] {
        sampling["sourceRevisionBinding"] = revision
        scene["sampling"] = sampling
    }
    guard var building = scene["building"] as? [String: Any] else {
        throw V13Error.failed("building missing")
    }
    building["massBlocks"] = [
        [
            "id": "i04-v13-n-foundry-hall-west",
            "dimensions": [34, 16, 34],
            "positionWorld": [-11, 10, 11],
            "materialID": "l4g-v13-warm-masonry",
        ],
        [
            "id": "i04-v13-n-control-annex",
            "dimensions": [16, 10, 12],
            "positionWorld": [20, 7, 18],
            "materialID": "l4g-v13-warm-masonry",
        ],
        [
            "id": "i04-v13-n-staff-entry",
            "dimensions": [2, 12, 8],
            "positionWorld": [27, 8, 18],
            "materialID": "l4g-v13-staff-glazing",
        ],
        [
            "id": "i04-v13-n-open-service-court-apron",
            "dimensions": [56, 1.4, 22],
            "positionWorld": [0, 0.7, -17],
            "materialID": "l4t-warm-scored-apron",
        ],
        [
            "id": "i04-v13-n-freight-beat-1-recess",
            "dimensions": [8, 8, 2],
            "positionWorld": [-8, 6, -20],
            "materialID": "l4t-deep-freight-recess",
        ],
        [
            "id": "i04-v13-n-freight-beat-1-header",
            "dimensions": [8, 4, 4],
            "positionWorld": [-8, 12, -18],
            "materialID": "l4g-v13-freight-header-steel",
        ],
        [
            "id": "i04-v13-n-freight-beat-1-post-west",
            "dimensions": [2, 10, 4],
            "positionWorld": [-13, 7, -18],
            "materialID": "l4g-v13-freight-header-steel",
        ],
        [
            "id": "i04-v13-n-freight-beat-1-post-east",
            "dimensions": [2, 10, 4],
            "positionWorld": [-3, 7, -18],
            "materialID": "l4g-v13-freight-header-steel",
        ],
        [
            "id": "i04-v13-n-freight-beat-2-recess",
            "dimensions": [8, 8, 2],
            "positionWorld": [8, 6, -20],
            "materialID": "l4t-deep-freight-recess",
        ],
        [
            "id": "i04-v13-n-freight-beat-2-header",
            "dimensions": [8, 4, 4],
            "positionWorld": [8, 12, -18],
            "materialID": "l4g-v13-freight-header-steel",
        ],
        [
            "id": "i04-v13-n-freight-beat-2-post-west",
            "dimensions": [2, 10, 4],
            "positionWorld": [3, 7, -18],
            "materialID": "l4g-v13-freight-header-steel",
        ],
        [
            "id": "i04-v13-n-freight-beat-2-post-east",
            "dimensions": [2, 10, 4],
            "positionWorld": [13, 7, -18],
            "materialID": "l4g-v13-freight-header-steel",
        ],
        [
            "id": "i04-v13-n-freight-beat-3-recess",
            "dimensions": [8, 8, 2],
            "positionWorld": [24, 6, -20],
            "materialID": "l4t-deep-freight-recess",
        ],
        [
            "id": "i04-v13-n-freight-beat-3-header",
            "dimensions": [8, 4, 4],
            "positionWorld": [24, 12, -18],
            "materialID": "l4g-v13-freight-header-steel",
        ],
        [
            "id": "i04-v13-n-freight-beat-3-post-west",
            "dimensions": [2, 10, 4],
            "positionWorld": [19, 7, -18],
            "materialID": "l4g-v13-freight-header-steel",
        ],
        [
            "id": "i04-v13-n-freight-beat-3-post-east",
            "dimensions": [2, 10, 4],
            "positionWorld": [27, 7, -18],
            "materialID": "l4g-v13-freight-header-steel",
        ],
        [
            "id": "i04-v13-n-gantry-pier-west",
            "dimensions": [6, 30, 8],
            "positionWorld": [-24, 16, -6],
            "materialID": "l4g-v13-dark-gantry-steel",
        ],
        [
            "id": "i04-v13-n-gantry-pier-east",
            "dimensions": [6, 30, 8],
            "positionWorld": [24, 16, -6],
            "materialID": "l4g-v13-dark-gantry-steel",
        ],
        [
            "id": "i04-v13-n-gantry-bridge-beam",
            "dimensions": [56, 7, 10],
            "positionWorld": [0, 32.5, -6],
            "materialID": "l4g-v13-dark-gantry-steel",
        ],
        [
            "id": "i04-v13-n-crucible",
            "shape": "tapered-octagonal-vessel",
            "dimensions": [16, 20, 14],
            "positionWorld": [0, 12, -6],
            "materialID": "l4g-v13-oxidized-copper-machinery",
        ],
        [
            "id": "i04-v13-n-crucible-mouth",
            "shape": "octagonal-prism",
            "dimensions": [10, 3, 8],
            "positionWorld": [0, 23.5, -6],
            "materialID": "l4t-orange-process-heat",
        ],
        [
            "id": "i04-v13-n-boiler-block",
            "dimensions": [8, 15, 8],
            "positionWorld": [-20, 9.5, 20],
            "materialID": "l4g-v13-restrained-green",
        ],
        [
            "id": "i04-v13-n-boiler-stack",
            "dimensions": [3, 22, 3],
            "positionWorld": [-21, 20, 21],
            "materialID": "l4t-oxidized-machinery",
        ],
    ]
    building["roofHeight"] = 3
    building["roofMaterialID"] = "l4g-v13-dark-roof-steel"
    building["massingProfile"] =
        "crucible-gantry-works-v13-north-transverse-lifting-court"
    building["roofVolumes"] = [
        [
            "id": "i04-v13-n-low-foundry-roof",
            "shape": "box",
            "dimensions": [34, 3, 34],
            "positionWorld": [-11, 19.5, 11],
            "materialID": "l4g-v13-dark-roof-steel",
            "trimMaterialID": "l4g-v13-dark-gantry-steel",
        ],
        [
            "id": "i04-v13-n-control-annex-roof",
            "shape": "box",
            "dimensions": [16, 2, 12],
            "positionWorld": [20, 13, 18],
            "materialID": "l4g-v13-dark-roof-steel",
            "trimMaterialID": "l4g-v13-dark-gantry-steel",
        ],
    ]
    building["trimBands"] = []
    building["wallMaterialID"] = "l4g-v13-warm-masonry"
    building["trimMaterialID"] = "l4g-v13-dark-gantry-steel"
    scene["building"] = building
    return scene
}

private func geometryHash(_ scene: [String: Any]) throws -> String {
    let canonical = try primitives(scene).map {
        [
            "id": $0.id,
            "materialID": $0.materialID,
            "positionWorld": [$0.center.x, $0.center.y, $0.center.z],
            "dimensions": [$0.size.x, $0.size.y, $0.size.z],
            "shape": $0.shape,
        ] as [String: Any]
    }
    return sha256(try stableJSON(canonical))
}

private func run(
    repositoryRoot: URL,
    artifactRoot: URL,
    evidenceRoot: URL
) throws {
    let v10Root = repositoryRoot.appendingPathComponent(
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v10-north-prepixel"
    )
    let v10SceneURL = v10Root.appendingPathComponent(
        "scenes/industrial_l04/variant-0/n/scene.json"
    )
    let v10MaterialURL = v10Root.appendingPathComponent(
        "materials/industrial-l04-turbine-v10-north-prepixel.json"
    )
    let v08RawURL = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/turbine-v08-north-raw-v02/diagnostics/raw-repeat/north/run-a/raw.png"
    )
    let v09ReviewRoot = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/turbine-works-v09-north-prepixel/review"
    )
    let v10ReviewRoot = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/turbine-works-v10-north-prepixel/review"
    )
    let v11ReviewRoot = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/turbine-works-v11-north-prepixel-rejection/attempts/layout-02/evidence/review"
    )
    let v12ReviewRoot = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/crucible-gantry-v12-north-prepixel-rejection/attempts/layout-02/review"
    )
    let v12SceneURL = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/crucible-gantry-v12-north-prepixel-rejection/attempts/layout-02/artifact/scenes/industrial_l04/variant-0/n/scene.json"
    )
    let acceptedL3RawURL = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-raw-review-v01/diagnostics/raw-repeat/north/run-a/raw.png"
    )
    let v10Scene = try JSONSerialization.jsonObject(
        with: Data(contentsOf: v10SceneURL)
    ) as! [String: Any]
    let v10Library = try JSONSerialization.jsonObject(
        with: Data(contentsOf: v10MaterialURL)
    ) as! [String: Any]
    let v12Scene = try JSONSerialization.jsonObject(
        with: Data(contentsOf: v12SceneURL)
    ) as! [String: Any]
    let v12GeometrySHA = try geometryHash(v12Scene)
    let library = try mutateLibrary(v10Library)
    let materialData = try stableJSON(library)
    let materialSHA = sha256(materialData)
    let scene = try mutateScene(v10Scene, materialSHA: materialSHA)
    let sceneData = try stableJSON(scene)
    let descriptorSHA = sha256(sceneData)
    let geometrySHA = try geometryHash(scene)
    let materialURL = artifactRoot.appendingPathComponent(
        "materials/\(materialName)"
    )
    let sceneURL = artifactRoot.appendingPathComponent(
        "scenes/industrial_l04/variant-0/n/scene.json"
    )
    try FileManager.default.createDirectory(
        at: materialURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: sceneURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try materialData.write(to: materialURL)
    try sceneData.write(to: sceneURL)
    let persistedSceneData = try Data(contentsOf: sceneURL)
    let persistedMaterialData = try Data(contentsOf: materialURL)
    _ = try JSONDecoder().decode(SceneDescriptor.self, from: persistedSceneData)
    _ = try JSONDecoder().decode(
        MaterialLibraryDescriptor.self,
        from: persistedMaterialData
    )
    let persistedScene = try JSONSerialization.jsonObject(
        with: persistedSceneData
    ) as! [String: Any]
    let persistedLibrary = try JSONSerialization.jsonObject(
        with: persistedMaterialData
    ) as! [String: Any]
    guard
        sha256(try stableJSON(persistedScene)) == descriptorSHA,
        sha256(try stableJSON(persistedLibrary)) == materialSHA,
        let building = persistedScene["building"] as? [String: Any],
        (building["width"] as? NSNumber)?.doubleValue == 56,
        (building["depth"] as? NSNumber)?.doubleValue == 56,
        let registration = persistedScene["registration"] as? [String: Any],
        try pair(registration["groundPivotSource"], "pivot") == [768, 896],
        try pair(registration["frontageSocketSource"], "socket") == [896, 704]
    else {
        throw V13Error.failed("persisted descriptor/material binding failed")
    }

    let review = evidenceRoot.appendingPathComponent("review")
    let sourceColor = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: sourceSize,
        mode: .color
    )
    let sourceGray = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: sourceSize,
        mode: .grayscale
    )
    let nativeColor = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: nativeSize,
        mode: .color
    )
    let nativeGray = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: nativeSize,
        mode: .grayscale
    )
    let compactColor = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: compactSize,
        mode: .color
    )
    let compactGray = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: compactSize,
        mode: .grayscale
    )
    let semantic = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: compactSize,
        mode: .semantic
    )
    let valueSemantic = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: compactSize,
        mode: .valueSemantic
    )
    let heroMask = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: compactSize,
        mode: .heroMask
    )
    let buildingTopMask = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: compactSize,
        mode: .buildingTopMask
    )
    let clay = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: sourceSize,
        mode: .clay
    )
    let registrationProof = try registrationOverlay(
        sourceColor,
        scene: persistedScene
    )
    let v08Raw = try neutralizedRaw(v08RawURL)
    let v09Source = try loadImage(v09ReviewRoot.appendingPathComponent("SOURCE-COLOR.png"))
    let v09SourceGray = try loadImage(v09ReviewRoot.appendingPathComponent("SOURCE-GRAYSCALE.png"))
    let v09Native = try loadImage(v09ReviewRoot.appendingPathComponent("NATIVE-2X-COLOR.png"))
    let v09NativeGray = try loadImage(v09ReviewRoot.appendingPathComponent("NATIVE-2X-GRAYSCALE.png"))
    let v09Compact = try loadImage(v09ReviewRoot.appendingPathComponent("EXACT-192X128-COLOR.png"))
    let v09CompactGray = try loadImage(v09ReviewRoot.appendingPathComponent("EXACT-192X128-GRAYSCALE.png"))
    let v10Source = try loadImage(v10ReviewRoot.appendingPathComponent("SOURCE-COLOR.png"))
    let v10SourceGray = try loadImage(v10ReviewRoot.appendingPathComponent("SOURCE-GRAYSCALE.png"))
    let v10Native = try loadImage(v10ReviewRoot.appendingPathComponent("NATIVE-2X-COLOR.png"))
    let v10NativeGray = try loadImage(v10ReviewRoot.appendingPathComponent("NATIVE-2X-GRAYSCALE.png"))
    let v10Compact = try loadImage(v10ReviewRoot.appendingPathComponent("EXACT-192X128-COLOR.png"))
    let v10CompactGray = try loadImage(v10ReviewRoot.appendingPathComponent("EXACT-192X128-GRAYSCALE.png"))
    let v11Source = try loadImage(v11ReviewRoot.appendingPathComponent("SOURCE-COLOR.png"))
    let v11SourceGray = try loadImage(v11ReviewRoot.appendingPathComponent("SOURCE-GRAYSCALE.png"))
    let v11Native = try loadImage(v11ReviewRoot.appendingPathComponent("NATIVE-2X-COLOR.png"))
    let v11NativeGray = try loadImage(v11ReviewRoot.appendingPathComponent("NATIVE-2X-GRAYSCALE.png"))
    let v11Compact = try loadImage(v11ReviewRoot.appendingPathComponent("EXACT-192X128-COLOR.png"))
    let v11CompactGray = try loadImage(v11ReviewRoot.appendingPathComponent("EXACT-192X128-GRAYSCALE.png"))
    let v12Source = try loadImage(v12ReviewRoot.appendingPathComponent("SOURCE-COLOR.png"))
    let v12SourceGray = try loadImage(v12ReviewRoot.appendingPathComponent("SOURCE-GRAYSCALE.png"))
    let v12Native = try loadImage(v12ReviewRoot.appendingPathComponent("NATIVE-2X-COLOR.png"))
    let v12NativeGray = try loadImage(v12ReviewRoot.appendingPathComponent("NATIVE-2X-GRAYSCALE.png"))
    let v12Compact = try loadImage(v12ReviewRoot.appendingPathComponent("EXACT-192X128-COLOR.png"))
    let v12CompactGray = try loadImage(v12ReviewRoot.appendingPathComponent("EXACT-192X128-GRAYSCALE.png"))
    let acceptedL3 = try neutralizedRaw(acceptedL3RawURL)
    let acceptedL3Gray = try renderComparisonGray(acceptedL3)
    let acceptedL3Native = try scaled(acceptedL3, to: nativeSize)
    let acceptedL3NativeGray = try renderComparisonGray(acceptedL3Native)
    let acceptedL3Compact = try scaled(acceptedL3, to: compactSize)
    let acceptedL3CompactGray = try renderComparisonGray(acceptedL3Compact)
    let v08Native = try scaled(v08Raw, to: nativeSize)
    let v08Compact = try scaled(v08Raw, to: compactSize)
    let v08Gray = try renderComparisonGray(v08Raw)
    let v08NativeGray = try renderComparisonGray(v08Native)
    let v08CompactGray = try renderComparisonGray(v08Compact)
    let files: [(String, CGImage)] = [
        ("SOURCE-COLOR.png", sourceColor),
        ("SOURCE-GRAYSCALE.png", sourceGray),
        ("NATIVE-2X-COLOR.png", nativeColor),
        ("NATIVE-2X-GRAYSCALE.png", nativeGray),
        ("EXACT-192X128-COLOR.png", compactColor),
        ("EXACT-192X128-GRAYSCALE.png", compactGray),
        ("HERO-ASSEMBLY-MASK-192X128.png", heroMask),
        ("ALL-BUILDING-TOP-SILHOUETTE-192X128.png", buildingTopMask),
        ("SEMANTIC-192X128.png", semantic),
        ("VALUE-ROLE-SEMANTIC-192X128.png", valueSemantic),
        ("CLAY-SILHOUETTE.png", clay),
        ("FRONTAGE-REGISTRATION.png", registrationProof),
        ("V08-V09-V10-V11-V13-SOURCE-COLOR.png", try fiveWay([v08Raw, v09Source, v10Source, v11Source, sourceColor], size: sourceSize)),
        ("V08-V09-V10-V11-V13-SOURCE-GRAYSCALE.png", try fiveWay([v08Gray, v09SourceGray, v10SourceGray, v11SourceGray, sourceGray], size: sourceSize)),
        ("V08-V09-V10-V11-V13-NATIVE-2X-COLOR.png", try fiveWay([v08Native, v09Native, v10Native, v11Native, nativeColor], size: nativeSize)),
        ("V08-V09-V10-V11-V13-NATIVE-2X-GRAYSCALE.png", try fiveWay([v08NativeGray, v09NativeGray, v10NativeGray, v11NativeGray, nativeGray], size: nativeSize)),
        ("V08-V09-V10-V11-V13-192X128-COLOR.png", try fiveWay([v08Compact, v09Compact, v10Compact, v11Compact, compactColor], size: compactSize)),
        ("V08-V09-V10-V11-V13-192X128-GRAYSCALE.png", try fiveWay([v08CompactGray, v09CompactGray, v10CompactGray, v11CompactGray, compactGray], size: compactSize)),
        ("ACCEPTED-L3-VS-V13-SOURCE-COLOR.png", try twoWay(acceptedL3, sourceColor, size: sourceSize)),
        ("ACCEPTED-L3-VS-V13-SOURCE-GRAYSCALE.png", try twoWay(acceptedL3Gray, sourceGray, size: sourceSize)),
        ("ACCEPTED-L3-VS-V13-NATIVE-2X-COLOR.png", try twoWay(acceptedL3Native, nativeColor, size: nativeSize)),
        ("ACCEPTED-L3-VS-V13-NATIVE-2X-GRAYSCALE.png", try twoWay(acceptedL3NativeGray, nativeGray, size: nativeSize)),
        ("ACCEPTED-L3-VS-V13-192X128-COLOR.png", try twoWay(acceptedL3Compact, compactColor, size: compactSize)),
        ("ACCEPTED-L3-VS-V13-192X128-GRAYSCALE.png", try twoWay(acceptedL3CompactGray, compactGray, size: compactSize)),
        ("V12-V13-SOURCE-COLOR.png", try twoWay(v12Source, sourceColor, size: sourceSize)),
        ("V12-V13-SOURCE-GRAYSCALE.png", try twoWay(v12SourceGray, sourceGray, size: sourceSize)),
        ("V12-V13-NATIVE-2X-COLOR.png", try twoWay(v12Native, nativeColor, size: nativeSize)),
        ("V12-V13-NATIVE-2X-GRAYSCALE.png", try twoWay(v12NativeGray, nativeGray, size: nativeSize)),
        ("V12-V13-192X128-COLOR.png", try twoWay(v12Compact, compactColor, size: compactSize)),
        ("V12-V13-192X128-GRAYSCALE.png", try twoWay(v12CompactGray, compactGray, size: compactSize)),
    ]
    for (name, image) in files {
        try writePNG(image, review.appendingPathComponent(name))
    }

    let maskBytes = try decoded(heroMask)
    let components = connectedComponents(
        bytes: maskBytes,
        width: Int(compactSize.width),
        height: Int(compactSize.height)
    )
    let buildingTopMaskBytes = try decoded(buildingTopMask)
    let buildingTopComponents = connectedComponents(
        bytes: buildingTopMaskBytes,
        width: Int(compactSize.width),
        height: Int(compactSize.height)
    )
    let semanticBytes = try decoded(semantic)
    let valueSemanticBytes = try decoded(valueSemantic)
    let compactColorBytes = try decoded(compactColor)
    let staffBounds = bounds(
        bytes: semanticBytes,
        width: 192,
        height: 128
    ) { $0 > 220 && $1 < 120 && $2 > 190 }
    let freight1Bounds = bounds(
        bytes: semanticBytes,
        width: 192,
        height: 128
    ) { $0 < 40 && $1 > 200 && $2 > 210 }
    let freight2Bounds = bounds(
        bytes: semanticBytes,
        width: 192,
        height: 128
    ) { $0 < 80 && $1 > 190 && $2 < 160 }
    let freight3Bounds = bounds(
        bytes: semanticBytes,
        width: 192,
        height: 128
    ) { $0 < 80 && $1 < 160 && $2 > 190 }
    let gantryBeamBounds = bounds(
        bytes: semanticBytes,
        width: 192,
        height: 128
    ) { $0 > 200 && $1 > 150 && $2 < 100 }
    let gantryWestPierBounds = bounds(
        bytes: semanticBytes,
        width: 192,
        height: 128
    ) { $0 > 200 && $1 < 100 && $2 < 100 }
    let gantryEastPierBounds = bounds(
        bytes: semanticBytes,
        width: 192,
        height: 128
    ) { $0 < 100 && $1 > 150 && $2 > 200 }
    let crucibleBounds = bounds(
        bytes: semanticBytes,
        width: 192,
        height: 128
    ) { $0 > 180 && $1 > 70 && $1 < 170 && $2 < 100 }
    let crucibleMouthBounds = bounds(
        bytes: semanticBytes,
        width: 192,
        height: 128
    ) { $0 > 230 && $1 < 80 && $2 < 50 }
    let gantryBounds = gantryBeamBounds
        .union(gantryWestPierBounds)
        .union(gantryEastPierBounds)
    let namedSemanticBounds = [
        ("staff", staffBounds),
        ("freight1", freight1Bounds),
        ("freight2", freight2Bounds),
        ("freight3", freight3Bounds),
        ("gantryBeam", gantryBeamBounds),
        ("gantryWestPier", gantryWestPierBounds),
        ("gantryEastPier", gantryEastPierBounds),
        ("crucible", crucibleBounds),
        ("crucibleMouth", crucibleMouthBounds),
    ]
    let missingSemanticBounds = namedSemanticBounds
        .filter { $0.1.isNull }
        .map(\.0)
    guard missingSemanticBounds.isEmpty else {
        throw V13Error.failed(
            "v13 player-visible semantic regions missing: \(missingSemanticBounds)"
        )
    }
    let freightPixelCounts = [
        matchingPixelCount(bytes: semanticBytes) {
            $0 < 40 && $1 > 200 && $2 > 210
        },
        matchingPixelCount(bytes: semanticBytes) {
            $0 < 80 && $1 > 190 && $2 < 160
        },
        matchingPixelCount(bytes: semanticBytes) {
            $0 < 80 && $1 < 160 && $2 > 190
        },
    ]
    let orderedFreightBounds = [
        freight1Bounds, freight2Bounds, freight3Bounds,
    ].sorted { $0.minX < $1.minX }
    let freightSeparatorPixels = zip(
        orderedFreightBounds,
        orderedFreightBounds.dropFirst()
    ).map { left, right in
        right.minX - left.maxX - 1
    }
    let cameraValue = try camera(persistedScene)
    let allItems = try primitives(persistedScene)
    guard
        let gantryBeam = allItems.first(where: {
            $0.id.contains("gantry-bridge-beam")
        }),
        let foundryRoof = allItems.first(where: {
            $0.id.contains("low-foundry-roof")
        }),
        let foundryHall = allItems.first(where: {
            $0.id.contains("foundry-hall")
        }),
        let crucible = allItems.first(where: {
            $0.id.hasSuffix("-crucible")
        }),
        let crucibleMouth = allItems.first(where: {
            $0.id.contains("crucible-mouth")
        }),
        let freightHeader = allItems.first(where: {
            $0.id.contains("freight-beat-1-header")
        }),
        let freightRecess = allItems.first(where: {
            $0.id.contains("freight-beat-1-recess")
        }),
        let courtApron = allItems.first(where: {
            $0.id.contains("open-service-court-apron")
        })
    else {
        throw V13Error.failed("v13 hero geometry missing")
    }
    let bridgeAlongX = gantryBeam.size.x > gantryBeam.size.z
    let gantryPiers = allItems.filter {
        $0.id.contains("gantry-pier")
    }.sorted {
        bridgeAlongX
            ? $0.center.x < $1.center.x
            : $0.center.z < $1.center.z
    }
    guard gantryPiers.count == 2 else {
        throw V13Error.failed("gantry must contain two piers")
    }
    let firstInner = bridgeAlongX
        ? gantryPiers[0].center.x + gantryPiers[0].size.x / 2
        : gantryPiers[0].center.z + gantryPiers[0].size.z / 2
    let secondInner = bridgeAlongX
        ? gantryPiers[1].center.x - gantryPiers[1].size.x / 2
        : gantryPiers[1].center.z - gantryPiers[1].size.z / 2
    let beamBottomY = gantryBeam.center.y - gantryBeam.size.y / 2
    let beamTopY = gantryBeam.center.y + gantryBeam.size.y / 2
    let apertureWidth = abs(
        project(
            V3(
                x: bridgeAlongX ? firstInner : gantryBeam.center.x,
                y: 12,
                z: bridgeAlongX ? gantryBeam.center.z : firstInner
            ),
            camera: cameraValue,
            size: compactSize
        ).x - project(
            V3(
                x: bridgeAlongX ? secondInner : gantryBeam.center.x,
                y: 12,
                z: bridgeAlongX ? gantryBeam.center.z : secondInner
            ),
            camera: cameraValue,
            size: compactSize
        ).x
    )
    let apertureHeight = abs(
        project(
            V3(x: gantryBeam.center.x, y: 2, z: gantryBeam.center.z),
            camera: cameraValue,
            size: compactSize
        ).y - project(
            V3(
                x: gantryBeam.center.x,
                y: beamBottomY,
                z: gantryBeam.center.z
            ),
            camera: cameraValue,
            size: compactSize
        ).y
    )
    let beamThickness = abs(
        project(
            V3(
                x: gantryBeam.center.x,
                y: beamBottomY,
                z: gantryBeam.center.z
            ),
            camera: cameraValue,
            size: compactSize
        ).y - project(
            V3(
                x: gantryBeam.center.x,
                y: beamTopY,
                z: gantryBeam.center.z
            ),
            camera: cameraValue,
            size: compactSize
        ).y
    )
    let pierThickness = abs(
        project(
            V3(
                x: bridgeAlongX
                    ? gantryPiers[0].center.x - gantryPiers[0].size.x / 2
                    : gantryPiers[0].center.x,
                y: gantryPiers[0].center.y,
                z: bridgeAlongX
                    ? gantryPiers[0].center.z
                    : gantryPiers[0].center.z - gantryPiers[0].size.z / 2
            ),
            camera: cameraValue,
            size: compactSize
        ).x - project(
            V3(
                x: bridgeAlongX
                    ? gantryPiers[0].center.x + gantryPiers[0].size.x / 2
                    : gantryPiers[0].center.x,
                y: gantryPiers[0].center.y,
                z: bridgeAlongX
                    ? gantryPiers[0].center.z
                    : gantryPiers[0].center.z + gantryPiers[0].size.z / 2
            ),
            camera: cameraValue,
            size: compactSize
        ).x
    )
    let heroRise = project(
        V3(
            x: gantryBeam.center.x,
            y: foundryRoof.center.y + foundryRoof.size.y / 2,
            z: gantryBeam.center.z
        ),
        camera: cameraValue,
        size: compactSize
    ).y - project(
        V3(x: gantryBeam.center.x, y: beamTopY, z: gantryBeam.center.z),
        camera: cameraValue,
        size: compactSize
    ).y
    let heroSpan = abs(
        project(
            V3(
                x: bridgeAlongX
                    ? gantryBeam.center.x - gantryBeam.size.x / 2
                    : gantryBeam.center.x,
                y: beamTopY,
                z: bridgeAlongX
                    ? gantryBeam.center.z
                    : gantryBeam.center.z - gantryBeam.size.z / 2
            ),
            camera: cameraValue,
            size: compactSize
        ).x - project(
            V3(
                x: bridgeAlongX
                    ? gantryBeam.center.x + gantryBeam.size.x / 2
                    : gantryBeam.center.x,
                y: beamTopY,
                z: bridgeAlongX
                    ? gantryBeam.center.z
                    : gantryBeam.center.z + gantryBeam.size.z / 2
            ),
            camera: cameraValue,
            size: compactSize
        ).x
    )
    let materialColors = try colors(persistedLibrary)
    guard let roofRGBA = materialColors[foundryRoof.materialID] else {
        throw V13Error.failed("v13 material luma inputs missing")
    }
    guard
        let roofMedianLuma = medianLuma(
            colorBytes: compactColorBytes,
            semanticBytes: valueSemanticBytes,
            predicate: { $0 > 200 && $1 < 80 && $2 < 80 }
        ),
        let hallMedianLuma = medianLuma(
            colorBytes: compactColorBytes,
            semanticBytes: valueSemanticBytes,
            predicate: { $0 < 80 && $1 > 200 && $2 < 80 }
        ),
        let gantryMedianLuma = medianLuma(
            colorBytes: compactColorBytes,
            semanticBytes: valueSemanticBytes,
            predicate: { $0 < 80 && $1 < 100 && $2 > 200 }
        ),
        let crucibleMedianLuma = medianLuma(
            colorBytes: compactColorBytes,
            semanticBytes: valueSemanticBytes,
            predicate: { $0 > 200 && $1 > 180 && $2 < 80 }
        ),
        let freightRecessMedianLuma = medianLuma(
            colorBytes: compactColorBytes,
            semanticBytes: valueSemanticBytes,
            predicate: { $0 > 200 && $1 < 80 && $2 > 180 }
        ),
        let freightHeaderMedianLuma = medianLuma(
            colorBytes: compactColorBytes,
            semanticBytes: valueSemanticBytes,
            predicate: { $0 < 80 && $1 > 200 && $2 > 200 }
        )
    else {
        throw V13Error.failed("v13 literal-192 value roles missing")
    }
    let roofHallLumaSeparation = abs(roofMedianLuma - hallMedianLuma)
    let gantryHallLumaSeparation = abs(gantryMedianLuma - hallMedianLuma)
    let crucibleGantryLumaSeparation = abs(
        crucibleMedianLuma - gantryMedianLuma
    )
    let freightLumaSeparation = abs(
        freightRecessMedianLuma - freightHeaderMedianLuma
    )
    let nwPlaneLuma = lumaByte(roofRGBA, shade: 0.96)
    let sePlaneLuma = lumaByte(roofRGBA, shade: 0.74)
    let grayscaleGroups = [
        "darkSteel": gantryMedianLuma,
        "machinery": crucibleMedianLuma,
        "warmMasonry": hallMedianLuma,
    ]
    let crucibleToNorthPierGap = max(
        0,
        max(crucibleBounds.minX, gantryWestPierBounds.minX)
            - min(crucibleBounds.maxX, gantryWestPierBounds.maxX) - 1
    )
    let crucibleToSouthPierGap = max(
        0,
        max(crucibleBounds.minX, gantryEastPierBounds.minX)
            - min(crucibleBounds.maxX, gantryEastPierBounds.maxX) - 1
    )
    let crucibleSupportGap = min(
        crucibleToNorthPierGap,
        crucibleToSouthPierGap
    )
    let courtReachesNorthSocket =
        abs(courtApron.center.z - courtApron.size.z / 2 + 28) < 0.000_001
        && courtApron.center.x - courtApron.size.x / 2 <= 0
        && courtApron.center.x + courtApron.size.x / 2 >= 0
    let stack = allItems.first {
        $0.id.contains("boiler-stack")
    }
    guard let stack, stack.size.x * stack.size.z <= 9 else {
        throw V13Error.failed("stack is not subordinate")
    }
    let l3SilhouetteIoU = silhouetteIoU(
        candidateMask: buildingTopMaskBytes,
        acceptedImage: try decoded(acceptedL3Compact)
    )
    let heroAreaShare = buildingTopComponents.pixels == 0
        ? 0
        : Double(components.pixels) / Double(buildingTopComponents.pixels)
    let gates: [String: Bool] = [
        "oneConnectedHeroAssemblyComponent": components.count == 1,
        "allBuildingSilhouetteConnected": buildingTopComponents.count == 1,
        "gantryClearOpeningAtLeast5": apertureHeight >= 5,
        "gantryBeamSpanAtLeast16": gantryBeamBounds.width >= 16,
        "gantryBeamThicknessAtLeast3":
            beamThickness >= 3 && gantryBeamBounds.height >= 3,
        "gantryWestUprightAtLeast9":
            gantryWestPierBounds.height >= 9,
        "gantryEastUprightAtLeast9":
            gantryEastPierBounds.height >= 9,
        "gantryPierThicknessOver2": pierThickness > 2,
        "heroRiseAtLeast3": heroRise >= 3,
        "heroSpanAtLeast16": heroSpan >= 16,
        "heroAssemblyDominatesOutline": heroAreaShare >= 0.24,
        "gantryVisibleAtCompact":
            gantryBounds.width >= 16 && gantryBounds.height >= 12,
        "crucibleVisibleAtCompact":
            crucibleBounds.width >= 7 && crucibleBounds.height >= 8,
        "crucibleHasTaperedVesselShape":
            crucible.shape == "tapered-octagonal-vessel",
        "crucibleMouthOver3":
            crucibleMouth.shape == "octagonal-prism"
            && crucibleMouthBounds.width > 3,
        "crucibleSeparatedFromSupportsOver2": crucibleSupportGap > 2,
        "roofHallLiteral192LumaAtLeast24":
            roofHallLumaSeparation >= 24,
        "gantryHallLiteral192LumaAtLeast22":
            gantryHallLumaSeparation >= 22,
        "crucibleGantryLiteral192LumaAtLeast28":
            crucibleGantryLumaSeparation >= 28,
        "freightRecessHeaderLiteral192LumaAtLeast18":
            freightLumaSeparation >= 18
            && freightHeader.materialID != freightRecess.materialID,
        "northwestSoutheastPlaneSeparationAtLeast12":
            nwPlaneLuma - sePlaneLuma >= 12,
        "threeCoherentGrayscaleGroups":
            (grayscaleGroups["darkSteel"] ?? 255) + 15
                <= (grayscaleGroups["machinery"] ?? 0)
            && (grayscaleGroups["machinery"] ?? 255) + 15
                <= (grayscaleGroups["warmMasonry"] ?? 0),
        "staffSideReturnOver4x5":
            staffBounds.width > 4 && staffBounds.height > 5,
        "freightBeat1AtLeast4x3":
            freight1Bounds.width >= 4 && freight1Bounds.height >= 3
            && freightPixelCounts[0] >= 12,
        "freightBeat2AtLeast4x3":
            freight2Bounds.width >= 4 && freight2Bounds.height >= 3
            && freightPixelCounts[1] >= 12,
        "freightBeat3AtLeast4x3":
            freight3Bounds.width >= 4 && freight3Bounds.height >= 3
            && freightPixelCounts[2] >= 12,
        "freightSeparatorsOver2":
            freightSeparatorPixels.count == 2
            && freightSeparatorPixels.allSatisfy { $0 > 2 },
        "courtReachesExactNorthSocket": courtReachesNorthSocket,
        "broadLowFoundryHallPreserved":
            foundryHall.size.x == 34 && foundryHall.size.z == 34
            && foundryHall.size.y == 16,
        "negativeSilhouetteAliasAgainstAcceptedL3": l3SilhouetteIoU < 0.72,
        "noV12GeometryAlias": geometrySHA != v12GeometrySHA,
        "noSawtoothAdmission":
            allItems.allSatisfy { $0.shape != "sawtooth-band" },
        "footprint56x56": true,
        "pivotAndSocketExact": true,
        "sourceAuthorityFalse": true,
        "productionSelectedFalse": true,
    ]
    let allGatesPassed = gates.values.allSatisfy { $0 }
    let metrics: [String: Any] = [
        "schema": 1,
        "task": "PLAY-027",
        "revision": revision,
        "layoutAttempt": 2,
        "generatedAt": fixedTimestamp,
        "disposition": allGatesPassed
            ? "PENDING_INDEPENDENT_PREPIXEL_REVIEW"
            : "REJECTED_PREPIXEL_GATE",
        "sourceAuthority": false,
        "productionSelected": false,
        "descriptorSHA256": descriptorSHA,
        "materialLibrarySHA256": materialSHA,
        "canonicalGeometrySHA256": geometrySHA,
        "v12CanonicalGeometrySHA256": v12GeometrySHA,
        "cameraSHA256": sha256(try stableJSON(persistedScene["camera"]!)),
        "registrationSHA256": sha256(try stableJSON(persistedScene["registration"]!)),
        "v08RawSHA256": try sha256(v08RawURL),
        "v10DescriptorSHA256": try sha256(v10SceneURL),
        "v10MaterialSHA256": try sha256(v10MaterialURL),
        "heroAssemblyComponentCount192": components.count,
        "heroAssemblyPixelCount192": components.pixels,
        "heroAssemblyAreaShareOfStackExcludedBuilding192": heroAreaShare,
        "allBuildingTopComponentCount192": buildingTopComponents.count,
        "allBuildingTopPixelCount192": buildingTopComponents.pixels,
        "gantryAperturePixels192": [apertureWidth, apertureHeight],
        "gantryBeamThicknessPixels192": beamThickness,
        "gantryPierThicknessPixels192": pierThickness,
        "heroRiseAboveHallPixels192": heroRise,
        "heroSpanPixels192": heroSpan,
        "gantrySemanticBounds192": [
            Int(gantryBounds.minX), Int(gantryBounds.minY),
            Int(gantryBounds.width), Int(gantryBounds.height),
        ],
        "gantryBeamBounds192": [
            Int(gantryBeamBounds.minX), Int(gantryBeamBounds.minY),
            Int(gantryBeamBounds.width), Int(gantryBeamBounds.height),
        ],
        "gantryUprightBounds192": [
            [
                Int(gantryWestPierBounds.minX),
                Int(gantryWestPierBounds.minY),
                Int(gantryWestPierBounds.width),
                Int(gantryWestPierBounds.height),
            ],
            [
                Int(gantryEastPierBounds.minX),
                Int(gantryEastPierBounds.minY),
                Int(gantryEastPierBounds.width),
                Int(gantryEastPierBounds.height),
            ],
        ],
        "crucibleSemanticBounds192": [
            Int(crucibleBounds.minX), Int(crucibleBounds.minY),
            Int(crucibleBounds.width), Int(crucibleBounds.height),
        ],
        "crucibleMouthBounds192": [
            Int(crucibleMouthBounds.minX), Int(crucibleMouthBounds.minY),
            Int(crucibleMouthBounds.width), Int(crucibleMouthBounds.height),
        ],
        "crucibleSupportSeparationPixels192": crucibleSupportGap,
        "roofHallMedianLuma192": [roofMedianLuma, hallMedianLuma],
        "roofHallAbsoluteMedianLumaSeparation192":
            roofHallLumaSeparation,
        "gantryHallMedianLuma192": [gantryMedianLuma, hallMedianLuma],
        "gantryHallAbsoluteMedianLumaSeparation192":
            gantryHallLumaSeparation,
        "crucibleGantryMedianLuma192": [
            crucibleMedianLuma, gantryMedianLuma,
        ],
        "crucibleGantryAbsoluteMedianLumaSeparation192":
            crucibleGantryLumaSeparation,
        "freightRecessHeaderMedianLuma192": [
            freightRecessMedianLuma, freightHeaderMedianLuma,
        ],
        "freightRecessHeaderAbsoluteMedianLumaSeparation192":
            freightLumaSeparation,
        "northwestPlaneMedianLuma192": nwPlaneLuma,
        "southeastPlaneMedianLuma192": sePlaneLuma,
        "northwestSoutheastPlaneSeparation192":
            nwPlaneLuma - sePlaneLuma,
        "grayscaleGroups192": grayscaleGroups,
        "staffEntranceBounds192": [
            Int(staffBounds.minX), Int(staffBounds.minY),
            Int(staffBounds.width), Int(staffBounds.height),
        ],
        "freightBounds192": [
            [
                Int(freight1Bounds.minX), Int(freight1Bounds.minY),
                Int(freight1Bounds.width), Int(freight1Bounds.height),
            ],
            [
                Int(freight2Bounds.minX), Int(freight2Bounds.minY),
                Int(freight2Bounds.width), Int(freight2Bounds.height),
            ],
            [
                Int(freight3Bounds.minX), Int(freight3Bounds.minY),
                Int(freight3Bounds.width), Int(freight3Bounds.height),
            ],
        ],
        "freightVisiblePixelCounts192": freightPixelCounts,
        "freightSeparatorPixels192": freightSeparatorPixels,
        "courtNorthEdgeWorldZ":
            courtApron.center.z - courtApron.size.z / 2,
        "courtReachesNorthSocket": courtReachesNorthSocket,
        "acceptedL3StackExcludedSilhouetteIoU192": l3SilhouetteIoU,
        "fixedRegistration": [
            "footprintWorld": [56, 56],
            "pivotSource": [768, 896],
            "socketSource": [896, 704],
        ],
        "gates": gates,
        "rawSourceProcesses": 0,
        "sceneKitProcesses": 0,
        "metalProcesses": 0,
        "normalizerProcesses": 0,
    ]
    try FileManager.default.createDirectory(
        at: evidenceRoot,
        withIntermediateDirectories: true
    )
    try stableJSON(metrics).write(
        to: evidenceRoot.appendingPathComponent("PREPIXEL-VALIDATION.json")
    )
    guard allGatesPassed else {
        throw V13Error.failed(
            "v13 gates failed: \(gates.filter { !$0.value }.keys.sorted())"
        )
    }
    let hashes = try Dictionary(uniqueKeysWithValues: files.map {
        ($0.0, try sha256(review.appendingPathComponent($0.0)))
    })
    let manifest: [String: Any] = [
        "schema": 1,
        "task": "PLAY-027",
        "revision": revision,
        "generatedAt": fixedTimestamp,
        "disposition": "PENDING_INDEPENDENT_PREPIXEL_REVIEW",
        "sourceAuthority": false,
        "productionSelected": false,
        "descriptorSHA256": descriptorSHA,
        "materialLibrarySHA256": materialSHA,
        "canonicalGeometrySHA256": geometrySHA,
        "reviewSHA256": hashes,
        "rawSourceProcesses": 0,
        "normalizerProcesses": 0,
    ]
    try stableJSON(manifest).write(
        to: evidenceRoot.appendingPathComponent("MANIFEST.json")
    )
    let request = """
    # PLAY-027 Industrial L4 North v13 pre-pixel review

    Disposition: `PENDING_INDEPENDENT_PREPIXEL_REVIEW`.

    This immutable North-only architectural reset retires the sawtooth grammar.
    One dark bridge gantry spans the road-facing service court, framing a
    mid-value octagonal crucible against the broad low warm-masonry hall.
    Three separated header/recess/post beats establish the grouped freight
    rhythm without claiming visibility of physically hidden far-side door
    leaves. A separate lit staff/control return remains subordinate. The
    boiler/stack block is not required for recognition. Footprint, pivot,
    socket, contact, light, shadow, envelopes, and atlas budget remain bound.

    All panels are descriptor-camera analytical proof, not raw source pixels.
    `sourceAuthority=false`; `productionSelected=false`.
    """
    try Data(request.utf8).write(
        to: evidenceRoot.appendingPathComponent("REVIEW-REQUEST.md")
    )
    print(
        "PASS \(revision) components=\(components.count)"
            + " aperture=\(apertureWidth)x\(apertureHeight)"
            + " heroRise=\(heroRise) freight="
            + "\(freight1Bounds.width)/\(freight2Bounds.width)/"
            + "\(freight3Bounds.width)"
    )
}

private func renderComparisonGray(_ image: CGImage) throws -> CGImage {
    let bytes = try decoded(image)
    var output = bytes
    for index in stride(from: 0, to: output.count, by: 4) {
        let red = 0.2126 * Double(output[index])
        let green = 0.7152 * Double(output[index + 1])
        let blue = 0.0722 * Double(output[index + 2])
        let value = UInt8(min(255, Int(red + green + blue)))
        output[index] = value
        output[index + 1] = value
        output[index + 2] = value
    }
    guard let context = CGContext(
        data: &output,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let result = context.makeImage() else {
        throw V13Error.failed("cannot make grayscale comparison")
    }
    return result
}

private extension Double {
    func distance(to other: Double) -> Double {
        abs(self - other)
    }
}

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        CommandLine.arguments.indices.contains(index + 1)
    else {
        throw V13Error.failed("missing \(name)")
    }
    return CommandLine.arguments[index + 1]
}

@main
private enum BuildIndustrialL4CrucibleGantryV13NorthPrepixel {
    static func main() {
        do {
            try run(
                repositoryRoot: URL(
                    fileURLWithPath: try argument("--repository-root")
                ),
                artifactRoot: URL(
                    fileURLWithPath: try argument("--artifact-root")
                ),
                evidenceRoot: URL(
                    fileURLWithPath: try argument("--evidence-root")
                )
            )
        } catch {
            fputs("FAIL \(error)\n", stderr)
            exit(1)
        }
    }
}
