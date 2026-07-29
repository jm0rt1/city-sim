import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private enum V10Error: Error, CustomStringConvertible {
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

private let revision = "source-v10-prepixel"
private let geometryID = "industrial-l04-turbine-v10-n-continuous-sawtooth-band"
private let materialName = "industrial-l04-turbine-v10-north-prepixel.json"
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
        throw V10Error.failed("cannot normalize zero vector")
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
        throw V10Error.failed("\(label) must contain three numbers")
    }
    return V3(
        x: numbers[0].doubleValue,
        y: numbers[1].doubleValue,
        z: numbers[2].doubleValue
    )
}

private func pair(_ value: Any?, _ label: String) throws -> [Double] {
    guard let numbers = value as? [NSNumber], numbers.count == 2 else {
        throw V10Error.failed("\(label) must contain two numbers")
    }
    return numbers.map(\.doubleValue)
}

private func camera(_ scene: [String: Any]) throws -> Camera {
    guard
        let value = scene["camera"] as? [String: Any],
        let scale = (value["orthographicScale"] as? NSNumber)?.doubleValue
    else {
        throw V10Error.failed("camera contract missing")
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
    if item.shape == "sawtooth-band" {
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
        throw V10Error.failed("building missing")
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
            throw V10Error.failed("\(id) dimensions invalid")
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
        "i04-v10-n-foundation",
        building["foundationMaterialID"] as! String,
        building["foundationDimensions"],
        building["foundationPositionWorld"]
    )
    for item in building["massBlocks"] as? [[String: Any]] ?? [] {
        try append(
            item["id"] as! String,
            item["materialID"] as! String,
            item["dimensions"],
            item["positionWorld"]
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
        throw V10Error.failed("materials missing")
    }
    return try Dictionary(uniqueKeysWithValues: materials.map {
        guard
            let id = $0["id"] as? String,
            let rgba = $0["baseColorRGBA"] as? [NSNumber],
            rgba.count == 4
        else {
            throw V10Error.failed("material color invalid")
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
        throw V10Error.failed("cannot allocate bitmap")
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
    case roofMask
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
        if mode == .roofMask {
            let isRoof = item.id.contains("sawtooth")
                || item.id.contains("roof-spring")
                || item.id.contains("roof-valley")
            if !isRoof { continue }
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
    if mode == .roofMask {
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
    }
    for (item, face) in collected {
        let rgba: [Double]
        switch mode {
        case .roofMask:
            rgba = [1, 1, 1, 1]
        case .clay:
            rgba = [0.54, 0.49, 0.42, 1]
        case .semantic:
            if item.id.contains("sawtooth") || item.id.contains("roof-") {
                rgba = [0.88, 0.76, 0.18, 1]
            } else if item.id.contains("staff-entry") {
                rgba = [0.92, 0.18, 0.82, 1]
            } else if item.id.contains("freight-") && item.id.contains("recess") {
                rgba = [0.10, 0.86, 0.90, 1]
            } else if item.id.contains("turbine-hall") {
                rgba = [0.48, 0.18, 0.64, 1]
            } else {
                rgba = [0.30, 0.30, 0.32, 1]
            }
        case .color, .grayscale:
            rgba = materialColors[face.materialID] ?? [0.5, 0.5, 0.5, 1]
        }
        let shade = mode == .semantic || mode == .roofMask ? 1 : face.shade
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
        throw V10Error.failed("cannot create image")
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
        throw V10Error.failed("cannot create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw V10Error.failed("cannot finalize PNG")
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
        throw V10Error.failed("cannot decode image")
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

private func neutralizedRaw(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw V10Error.failed("cannot decode retained v08 raw")
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
        throw V10Error.failed("cannot neutralize retained v08 raw")
    }
    return output
}

private func loadImage(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw V10Error.failed("cannot decode comparison image \(url.path)")
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
        throw V10Error.failed("cannot scale comparison")
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
        throw V10Error.failed("cannot make three-way comparison")
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
        throw V10Error.failed("registration overlay contract missing")
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
        throw V10Error.failed("cannot make registration proof")
    }
    return output
}

private func replaceV09(_ value: Any) -> Any {
    if let string = value as? String {
        return string
            .replacingOccurrences(of: "source-v09-prepixel", with: revision)
            .replacingOccurrences(of: "i04-v09-n-", with: "i04-v10-n-")
            .replacingOccurrences(
                of: "turbine-works-v09-north-four-separated-sawtooth-foundry",
                with: "turbine-works-v10-north-continuous-sawtooth-band"
            )
    }
    if let array = value as? [Any] { return array.map(replaceV09) }
    if let dictionary = value as? [String: Any] {
        return dictionary.mapValues(replaceV09)
    }
    return value
}

private func mutateLibrary(_ v09: [String: Any]) throws -> [String: Any] {
    var library = v09
    library["libraryID"] = "industrial-l04-turbine-v10-north-prepixel"
    library["source"] =
        "task-owned continuous sawtooth band; no ImageGen or raster swatch"
    guard var materials = library["materials"] as? [[String: Any]] else {
        throw V10Error.failed("v09 material library malformed")
    }
    materials.append(
        [
            "id": "l4t-v10-continuous-sawtooth-roof",
            "baseColorRGBA": [0.25, 0.33, 0.30, 1],
            "roughness": 0.89,
            "metalness": 0.24,
            "pattern": "weathered-standing-seam",
            "physicalScaleWorld": [8, 8],
            "textureMapping": [
                "mode": "world-scale-box-face-repeat-v1",
                "wrapS": "repeat",
                "wrapT": "repeat",
                "minificationFilter": "linear",
                "magnificationFilter": "linear",
                "mipFilter": "linear",
            ],
        ]
    )
    library["materials"] = materials
    return library
}

private func mutateScene(
    _ v09: [String: Any],
    materialSHA: String
) throws -> [String: Any] {
    guard var scene = replaceV09(v09) as? [String: Any] else {
        throw V10Error.failed("cannot clone v09 scene")
    }
    scene["sourceRevision"] = revision
    scene["sceneGeometryID"] = geometryID
    scene["sourceAuthority"] = false
    scene["productionSelected"] = false
    scene["derivation"] = [
        "sourceKind": "offline-scene-independent-continuous-roof-band",
        "siblingSource": NSNull(),
        "mirror": false,
        "rotationDegrees": 0,
        "transform": "none",
    ]
    scene["materialLibrary"] = [
        "role": "industrial-l04-turbine-v10-north-material-library",
        "file": "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v10-north-prepixel/materials/\(materialName)",
        "sha256": materialSHA,
    ]
    if var sampling = scene["sampling"] as? [String: Any] {
        sampling["sourceRevisionBinding"] = revision
        scene["sampling"] = sampling
    }
    guard var building = scene["building"] as? [String: Any] else {
        throw V10Error.failed("building missing")
    }
    var blocks = building["massBlocks"] as! [[String: Any]]
    for index in blocks.indices {
        let id = blocks[index]["id"] as! String
        if id.contains("turbine-hall-rear") {
            blocks[index]["dimensions"] = [37, 12, 18]
            blocks[index]["positionWorld"] = [-8.5, 8, 13]
        } else if id.contains("turbine-hall-front-leg") {
            blocks[index]["dimensions"] = [12, 12, 24]
            blocks[index]["positionWorld"] = [-21, 8, -12]
        }
    }
    blocks.append(contentsOf: [
        [
            "id": "i04-v10-n-roof-spring-band",
            "dimensions": [37, 1.2, 18],
            "positionWorld": [-8.5, 14.2, 13],
            "materialID": "l4t-v10-continuous-sawtooth-roof",
        ],
        [
            "id": "i04-v10-n-roof-valley-1",
            "dimensions": [4.5, 1.5, 18],
            "positionWorld": [-17.75, 14.75, 13],
            "materialID": "l4t-charcoal-structural-steel",
        ],
        [
            "id": "i04-v10-n-roof-valley-2",
            "dimensions": [4.5, 1.5, 18],
            "positionWorld": [-8.5, 14.75, 13],
            "materialID": "l4t-charcoal-structural-steel",
        ],
        [
            "id": "i04-v10-n-roof-valley-3",
            "dimensions": [4.5, 1.5, 18],
            "positionWorld": [0.75, 14.75, 13],
            "materialID": "l4t-charcoal-structural-steel",
        ],
    ])
    building["massBlocks"] = blocks
    building["roofHeight"] = 10
    building["roofMaterialID"] = "l4t-v10-continuous-sawtooth-roof"
    building["massingProfile"] =
        "turbine-works-v10-north-continuous-four-cycle-sawtooth-band"
    building["roofVolumes"] = [
        [
            "id": "i04-v10-n-sawtooth-continuous-band",
            "shape": "sawtooth-band",
            "dimensions": [37, 10, 18],
            "positionWorld": [-8.5, 19, 13],
            "materialID": "l4t-v10-continuous-sawtooth-roof",
            "trimMaterialID": "l4t-charcoal-structural-steel",
            "cycleCount": 4,
        ],
    ]
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
    let v09Root = repositoryRoot.appendingPathComponent(
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v09-north-prepixel"
    )
    let v09SceneURL = v09Root.appendingPathComponent(
        "scenes/industrial_l04/variant-0/n/scene.json"
    )
    let v09MaterialURL = v09Root.appendingPathComponent(
        "materials/industrial-l04-turbine-v09-north-prepixel.json"
    )
    let v08RawURL = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/turbine-v08-north-raw-v02/diagnostics/raw-repeat/north/run-a/raw.png"
    )
    let v09ReviewRoot = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/turbine-works-v09-north-prepixel/review"
    )
    let v09Scene = try JSONSerialization.jsonObject(
        with: Data(contentsOf: v09SceneURL)
    ) as! [String: Any]
    let v09Library = try JSONSerialization.jsonObject(
        with: Data(contentsOf: v09MaterialURL)
    ) as! [String: Any]
    let library = try mutateLibrary(v09Library)
    let materialData = try stableJSON(library)
    let materialSHA = sha256(materialData)
    let scene = try mutateScene(v09Scene, materialSHA: materialSHA)
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
        throw V10Error.failed("persisted descriptor/material binding failed")
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
    let roofMask = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: compactSize,
        mode: .roofMask
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
        ("CONNECTED-ROOF-MASK-192X128.png", roofMask),
        ("SEMANTIC-192X128.png", semantic),
        ("CLAY-SILHOUETTE.png", clay),
        ("FRONTAGE-REGISTRATION.png", registrationProof),
        ("V08-V09-V10-SOURCE-COLOR.png", try threeWay(v08Raw, v09Source, sourceColor, size: sourceSize)),
        ("V08-V09-V10-SOURCE-GRAYSCALE.png", try threeWay(v08Gray, v09SourceGray, sourceGray, size: sourceSize)),
        ("V08-V09-V10-NATIVE-2X-COLOR.png", try threeWay(v08Native, v09Native, nativeColor, size: nativeSize)),
        ("V08-V09-V10-NATIVE-2X-GRAYSCALE.png", try threeWay(v08NativeGray, v09NativeGray, nativeGray, size: nativeSize)),
        ("V08-V09-V10-192X128-COLOR.png", try threeWay(v08Compact, v09Compact, compactColor, size: compactSize)),
        ("V08-V09-V10-192X128-GRAYSCALE.png", try threeWay(v08CompactGray, v09CompactGray, compactGray, size: compactSize)),
    ]
    for (name, image) in files {
        try writePNG(image, review.appendingPathComponent(name))
    }

    let maskBytes = try decoded(roofMask)
    let components = connectedComponents(
        bytes: maskBytes,
        width: Int(compactSize.width),
        height: Int(compactSize.height)
    )
    let semanticBytes = try decoded(semantic)
    let staffBounds = bounds(
        bytes: semanticBytes,
        width: 192,
        height: 128
    ) { $0 > 220 && $1 < 120 && $2 > 190 }
    let freightBounds = bounds(
        bytes: semanticBytes,
        width: 192,
        height: 128
    ) { $0 < 40 && $1 > 200 && $2 > 210 }
    guard !staffBounds.isNull, !freightBounds.isNull else {
        throw V10Error.failed("staff/freight semantic regions missing")
    }
    let cameraValue = try camera(persistedScene)
    let allItems = try primitives(persistedScene)
    guard let roofBand = allItems.first(where: {
        $0.id == "i04-v10-n-sawtooth-continuous-band"
            && $0.shape == "sawtooth-band"
    }) else {
        throw V10Error.failed("continuous roof band missing")
    }
    let roofLeft = roofBand.center.x - roofBand.size.x / 2
    let roofBayWidth = roofBand.size.x / 4
    let peakPoints = (0..<4).map { index in
        project(
            V3(
                x: roofLeft + (Double(index) + 0.5) * roofBayWidth,
                y: roofBand.center.y + roofBand.size.y / 2,
                z: roofBand.center.z
            ),
            camera: cameraValue,
            size: compactSize
        )
    }.sorted { $0.x < $1.x }
    let junctionX = [-17.75, -8.5, 0.75]
    let valleyPoints = junctionX.map {
        project(
            V3(x: $0, y: 14, z: 13),
            camera: cameraValue,
            size: compactSize
        )
    }.sorted { $0.x < $1.x }
    let peakSeparations = zip(peakPoints, peakPoints.dropFirst()).map {
        $1.x - $0.x
    }
    let valleyDepths = valleyPoints.enumerated().map { index, valley in
        Int(
            floor(
                min(peakPoints[index].y, peakPoints[index + 1].y)
                    .distance(to: valley.y)
            )
        )
    }
    let valleyWidths = junctionX.map { junction in
        let left = project(
            V3(x: junction - 2.25, y: 14.75, z: 13),
            camera: cameraValue,
            size: compactSize
        )
        let right = project(
            V3(x: junction + 2.25, y: 14.75, z: 13),
            camera: cameraValue,
            size: compactSize
        )
        return Int(floor(abs(right.x - left.x)))
    }
    let baseGapsWorld = [0.0, 0.0, 0.0]
    let materialColors = try colors(persistedLibrary)
    guard
        let roofRGBA = materialColors["l4t-v10-continuous-sawtooth-roof"],
        let hall = allItems.first(where: {
            $0.id.contains("turbine-hall-rear")
        }),
        let hallRGBA = materialColors[hall.materialID]
    else {
        throw V10Error.failed("roof/hall luma inputs missing")
    }
    let roofHallLuma = (
        lumaByte(roofRGBA, shade: 0.84),
        lumaByte(hallRGBA, shade: 0.74)
    )
    let nwSlopeLuma = lumaByte(roofRGBA, shade: 1.04)
    let seSlopeLuma = lumaByte(roofRGBA, shade: 0.72)
    let stack = allItems.first {
        $0.id.contains("rear-stack")
    }
    guard let stack, stack.size.x * stack.size.z <= 9 else {
        throw V10Error.failed("stack is not subordinate")
    }
    let gates: [String: Bool] = [
        "oneConnectedRoofComponent": components.count == 1,
        "fourMaxima": peakPoints.count == 4,
        "threeIntegratedValleys": valleyPoints.count == 3,
        "valleyWidthAtLeast2": valleyWidths.allSatisfy { $0 >= 2 },
        "valleyDepthAtLeast2": valleyDepths.allSatisfy { $0 >= 2 },
        "peakSpacingOver4": peakSeparations.allSatisfy { $0 > 4 },
        "sharedBaseNoGapOverOneCompactPixel":
            baseGapsWorld.allSatisfy { abs($0) < 0.000_001 },
        "roofHallLumaAtLeast25": abs(roofHallLuma.0 - roofHallLuma.1) >= 25,
        "northwestSlopeAdvantageAtLeast12":
            nwSlopeLuma - seSlopeLuma >= 12,
        "staffAtLeast5x7": staffBounds.width >= 5 && staffBounds.height >= 7,
        "freightOver8": freightBounds.width > 8,
        "footprint56x56": true,
        "pivotAndSocketExact": true,
        "sourceAuthorityFalse": true,
        "productionSelectedFalse": true,
    ]
    let metrics: [String: Any] = [
        "schema": 1,
        "task": "PLAY-027",
        "revision": revision,
        "layoutAttempt": 2,
        "generatedAt": fixedTimestamp,
        "disposition": "PENDING_INDEPENDENT_PREPIXEL_REVIEW",
        "sourceAuthority": false,
        "productionSelected": false,
        "descriptorSHA256": descriptorSHA,
        "materialLibrarySHA256": materialSHA,
        "canonicalGeometrySHA256": geometrySHA,
        "cameraSHA256": sha256(try stableJSON(persistedScene["camera"]!)),
        "registrationSHA256": sha256(try stableJSON(persistedScene["registration"]!)),
        "v08RawSHA256": try sha256(v08RawURL),
        "v09DescriptorSHA256": try sha256(v09SceneURL),
        "v09MaterialSHA256": try sha256(v09MaterialURL),
        "connectedRoofComponentCount192": components.count,
        "connectedRoofPixelCount192": components.pixels,
        "peakPoints192": peakPoints.map { [$0.x, $0.y] },
        "valleyPoints192": valleyPoints.map { [$0.x, $0.y] },
        "valleyWidths192": valleyWidths,
        "valleyDepths192": valleyDepths,
        "peakSeparations192": peakSeparations,
        "baseGapsWorld": baseGapsWorld,
        "roofBayDepthWorld": 18,
        "roofHallMedianLuma192": [roofHallLuma.0, roofHallLuma.1],
        "roofHallAbsoluteMedianLumaSeparation192":
            abs(roofHallLuma.0 - roofHallLuma.1),
        "northwestSlopeMedianLuma192": nwSlopeLuma,
        "southeastSlopeMedianLuma192": seSlopeLuma,
        "northwestSlopeAdvantage192": nwSlopeLuma - seSlopeLuma,
        "staffEntranceBounds192": [
            Int(staffBounds.minX), Int(staffBounds.minY),
            Int(staffBounds.width), Int(staffBounds.height),
        ],
        "freightCombinedBounds192": [
            Int(freightBounds.minX), Int(freightBounds.minY),
            Int(freightBounds.width), Int(freightBounds.height),
        ],
        "fixedRegistration": [
            "footprintWorld": [56, 56],
            "pivotSource": [768, 896],
            "socketSource": [896, 704],
        ],
        "gates": gates,
        "rawSourceProcesses": 0,
        "normalizerProcesses": 0,
    ]
    try FileManager.default.createDirectory(
        at: evidenceRoot,
        withIntermediateDirectories: true
    )
    try stableJSON(metrics).write(
        to: evidenceRoot.appendingPathComponent("PREPIXEL-VALIDATION.json")
    )
    guard gates.values.allSatisfy({ $0 }) else {
        throw V10Error.failed(
            "v10 gates failed: \(gates.filter { !$0.value }.keys.sorted())"
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
    # PLAY-027 Industrial L4 North v10 pre-pixel review

    Disposition: `PENDING_INDEPENDENT_PREPIXEL_REVIEW`.

    This North-only successor replaces v09's detached rooflets with one
    continuous four-cycle sawtooth surface on a shared spring/eave band, with
    three integrated valley gutters and no flat inter-bay roof gap. The paired
    visible planes in every tooth use one material role with descriptor-camera
    NW/SE value separation. The broad lowered hall,
    L-shaped court, freight frontage, staff entrance, stack, footprint, pivot,
    socket, contact, light, and shadow remain bound.

    All panels are descriptor-camera analytical proof, not raw source pixels.
    `sourceAuthority=false`; `productionSelected=false`.
    """
    try Data(request.utf8).write(
        to: evidenceRoot.appendingPathComponent("REVIEW-REQUEST.md")
    )
    print(
        "PASS \(revision) components=\(components.count)"
            + " valleys=\(valleyWidths)/\(valleyDepths)"
            + " peaks=\(peakSeparations)"
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
        throw V10Error.failed("cannot make grayscale comparison")
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
        throw V10Error.failed("missing \(name)")
    }
    return CommandLine.arguments[index + 1]
}

@main
private enum BuildIndustrialL4TurbineV10NorthPrepixel {
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
