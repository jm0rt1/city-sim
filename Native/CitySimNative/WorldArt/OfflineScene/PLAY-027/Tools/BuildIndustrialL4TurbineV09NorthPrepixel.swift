import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private enum V09Error: Error, CustomStringConvertible {
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

private let sourceSize = CGSize(width: 1536, height: 1024)
private let nativeSize = CGSize(width: 384, height: 256)
private let compactSize = CGSize(width: 192, height: 128)
private let revision = "source-v09-prepixel"
private let geometryID = "industrial-l04-turbine-v09-n-four-sawtooth-foundry"
private let materialFileName = "industrial-l04-turbine-v09-north-prepixel.json"
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
        throw V09Error.failed("cannot normalize zero vector")
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
    guard let values = value as? [NSNumber], values.count == 3 else {
        throw V09Error.failed("\(label) must be a three-number vector")
    }
    return V3(
        x: values[0].doubleValue,
        y: values[1].doubleValue,
        z: values[2].doubleValue
    )
}

private func pair(_ value: Any?, _ label: String) throws -> [Double] {
    guard let values = value as? [NSNumber], values.count == 2 else {
        throw V09Error.failed("\(label) must be a two-number vector")
    }
    return values.map(\.doubleValue)
}

private func camera(from scene: [String: Any]) throws -> Camera {
    guard
        let value = scene["camera"] as? [String: Any],
        let scale = (value["orthographicScale"] as? NSNumber)?.doubleValue
    else {
        throw V09Error.failed("descriptor camera missing")
    }
    let position = try vector(value["positionWorld"], "camera.positionWorld")
    let target = try vector(value["targetWorld"], "camera.targetWorld")
    let viewport = try pair(value["renderViewportPixels"], "camera.renderViewportPixels")
    let offset = try pair(value["postProjectionOffsetPixels"], "camera.postProjectionOffsetPixels")
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

private func projected(_ point: V3, camera: Camera, size: CGSize) -> P2 {
    let relative = point - camera.target
    let source = P2(
        x: camera.viewport.width * 0.5
            + dot(relative, camera.right) * camera.pixelsPerWorld
            + camera.offset.x,
        y: camera.viewport.height * 0.5
            - dot(relative, camera.up) * camera.pixelsPerWorld
            + camera.offset.y
    )
    return P2(
        x: source.x * Double(size.width / camera.viewport.width),
        y: source.y * Double(size.height / camera.viewport.height)
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
    lightOrigin: V3,
    size: CGSize
) throws -> [Face] {
    let definitions: [(String, V3, [V3])]
    if item.shape == "hip" {
        let h = item.size * 0.5
        let y0 = item.center.y - h.y
        let y1 = item.center.y + h.y
        let front = item.center.z - h.z
        let back = item.center.z + h.z
        let left = item.center.x - h.x
        let right = item.center.x + h.x
        let apex = V3(x: item.center.x, y: y1, z: item.center.z)
        definitions = [
            ("west-slope", V3(x: -0.72, y: 0.69, z: 0), [
                V3(x: left, y: y0, z: back),
                V3(x: left, y: y0, z: front),
                apex,
            ]),
            ("northwest-slope", V3(x: 0.72, y: 0.69, z: 0), [
                V3(x: right, y: y0, z: front),
                V3(x: right, y: y0, z: back),
                apex,
            ]),
            ("north-slope", V3(x: 0, y: 0.69, z: -0.72), [
                V3(x: left, y: y0, z: front),
                V3(x: right, y: y0, z: front),
                apex,
            ]),
            ("southeast-slope", V3(x: 0, y: 0.69, z: 0.72), [
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
    return try definitions.compactMap { role, normal, world in
        let center = world.reduce(V3(x: 0, y: 0, z: 0), +) * (1 / Double(world.count))
        guard dot(normal, camera.position - center) > 0.000_001 else { return nil }
        let light = try normalized(lightOrigin - center)
        let illumination = max(0, dot(try normalized(normal), light))
        let directionalBoost = role == "northwest-slope" ? 0.16 : 0
        let directionalCut = role == "southeast-slope" ? 0.08 : 0
        return Face(
            primitiveID: item.id,
            materialID: item.materialID,
            role: role,
            points: world.map { projected($0, camera: camera, size: size) },
            depth: world.map { dot($0 - camera.target, camera.forward) }
                .reduce(0, +) / Double(world.count),
            shade: min(1.15, 0.70 + 0.24 * illumination + directionalBoost - directionalCut)
        )
    }
}

private func primitives(_ scene: [String: Any]) throws -> [Primitive] {
    guard let building = scene["building"] as? [String: Any] else {
        throw V09Error.failed("building missing")
    }
    var values: [Primitive] = []
    func append(_ id: String, _ material: String, _ dimensions: Any?, _ position: Any?, _ shape: String = "box") throws {
        values.append(
            Primitive(
                id: id,
                materialID: material,
                center: try vector(position, "\(id).positionWorld"),
                size: try vector(dimensions, "\(id).dimensions"),
                shape: shape
            )
        )
    }
    guard let foundation = building["foundationMaterialID"] as? String else {
        throw V09Error.failed("foundation material missing")
    }
    try append(
        "i04-v09-n-foundation",
        foundation,
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
    return values
}

private func materialColors(_ library: [String: Any]) throws -> [String: [Double]] {
    guard let materials = library["materials"] as? [[String: Any]] else {
        throw V09Error.failed("material list missing")
    }
    return try Dictionary(uniqueKeysWithValues: materials.map {
        guard
            let id = $0["id"] as? String,
            let rgba = $0["baseColorRGBA"] as? [NSNumber],
            rgba.count == 4
        else {
            throw V09Error.failed("material color missing")
        }
        return (id, rgba.map(\.doubleValue))
    })
}

private func bitmap(width: Int, height: Int) throws -> CGContext {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V09Error.failed("cannot allocate bitmap")
    }
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.setShouldAntialias(false)
    context.setFillColor(CGColor(red: 0.12, green: 0.13, blue: 0.14, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context
}

private func imageBitmap(width: Int, height: Int) throws -> CGContext {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V09Error.failed("cannot allocate image compositor")
    }
    context.setShouldAntialias(false)
    context.setFillColor(CGColor(red: 0.12, green: 0.13, blue: 0.14, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context
}

private func path(_ points: [P2]) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: points[0].x, y: points[0].y))
    for point in points.dropFirst() {
        path.addLine(to: CGPoint(x: point.x, y: point.y))
    }
    path.closeSubpath()
    return path
}

private func render(
    scene: [String: Any],
    library: [String: Any],
    size: CGSize,
    clay: Bool = false,
    semantic: Bool = false
) throws -> CGImage {
    let camera = try camera(from: scene)
    guard
        let light = scene["light"] as? [String: Any],
        let lightOriginValue = light["keyOrigin"]
    else {
        throw V09Error.failed("light contract missing")
    }
    let lightOrigin = try vector(lightOriginValue, "light.keyOrigin")
    let colors = try materialColors(library)
    let items = try primitives(scene)
    var allFaces: [Face] = []
    for item in items {
        allFaces += try faces(item, camera: camera, lightOrigin: lightOrigin, size: size)
    }
    allFaces.sort { $0.depth > $1.depth }
    let context = try bitmap(width: Int(size.width), height: Int(size.height))
    for face in allFaces {
        let rgba: [Double]
        if semantic {
            if face.primitiveID.contains("sawtooth") {
                let index = Int(face.primitiveID.suffix(1)) ?? 1
                let palette = [
                    [0.86, 0.22, 0.20, 1.0],
                    [0.20, 0.72, 0.34, 1.0],
                    [0.20, 0.44, 0.88, 1.0],
                    [0.84, 0.68, 0.18, 1.0],
                ]
                rgba = palette[index - 1]
            } else if face.primitiveID.contains("staff-entry") {
                rgba = [0.92, 0.18, 0.82, 1]
            } else if face.primitiveID.contains("freight-") && face.primitiveID.contains("recess") {
                rgba = [0.10, 0.86, 0.90, 1]
            } else if face.primitiveID.contains("turbine-hall") {
                rgba = [0.48, 0.18, 0.64, 1]
            } else {
                rgba = [0.30, 0.30, 0.32, 1]
            }
        } else if clay {
            rgba = [0.54, 0.49, 0.42, 1]
        } else {
            rgba = colors[face.materialID] ?? [0.5, 0.5, 0.5, 1]
        }
        let shade = semantic ? 1 : face.shade
        context.setFillColor(
            CGColor(
                red: min(1, rgba[0] * shade),
                green: min(1, rgba[1] * shade),
                blue: min(1, rgba[2] * shade),
                alpha: rgba[3]
            )
        )
        context.addPath(path(face.points))
        context.fillPath()
    }
    guard let image = context.makeImage() else {
        throw V09Error.failed("cannot make rendered image")
    }
    return image
}

private func writePNG(_ image: CGImage, to url: URL) throws {
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
        throw V09Error.failed("cannot create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw V09Error.failed("cannot finalize PNG")
    }
}

private func grayscale(_ image: CGImage) throws -> CGImage {
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard let input = CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V09Error.failed("cannot decode for grayscale")
    }
    input.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    for index in stride(from: 0, to: bytes.count, by: 4) {
        let red = 0.2126 * Double(bytes[index])
        let green = 0.7152 * Double(bytes[index + 1])
        let blue = 0.0722 * Double(bytes[index + 2])
        let value = UInt8(min(255, Int(red + green + blue)))
        bytes[index] = value
        bytes[index + 1] = value
        bytes[index + 2] = value
    }
    guard let output = input.makeImage() else {
        throw V09Error.failed("cannot make grayscale image")
    }
    return output
}

private func scaled(_ image: CGImage, to size: CGSize) throws -> CGImage {
    let context = try imageBitmap(width: Int(size.width), height: Int(size.height))
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(origin: .zero, size: size))
    guard let result = context.makeImage() else {
        throw V09Error.failed("cannot scale image")
    }
    return result
}

private func neutralizedV08Raw(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw V09Error.failed("cannot decode v08 raw")
    }
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V09Error.failed("cannot allocate v08 decode")
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    for index in stride(from: 0, to: bytes.count, by: 4) {
        if bytes[index] == 255 && bytes[index + 1] == 0 && bytes[index + 2] == 255 {
            bytes[index] = 31
            bytes[index + 1] = 33
            bytes[index + 2] = 36
        }
    }
    guard let output = context.makeImage() else {
        throw V09Error.failed("cannot make v08 neutral image")
    }
    return output
}

private func comparison(_ left: CGImage, _ right: CGImage, size: CGSize) throws -> CGImage {
    let context = try imageBitmap(width: Int(size.width * 2), height: Int(size.height))
    context.interpolationQuality = .none
    context.draw(left, in: CGRect(origin: .zero, size: size))
    context.draw(
        right,
        in: CGRect(x: size.width, y: 0, width: size.width, height: size.height)
    )
    context.setStrokeColor(CGColor(gray: 0.82, alpha: 1))
    context.setLineWidth(2)
    context.move(to: CGPoint(x: size.width, y: 0))
    context.addLine(to: CGPoint(x: size.width, y: size.height))
    context.strokePath()
    guard let output = context.makeImage() else {
        throw V09Error.failed("cannot make comparison")
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
        throw V09Error.failed("registration overlay contract missing")
    }
    let context = try imageBitmap(width: image.width, height: image.height)
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    context.saveGState()
    context.translateBy(x: 0, y: CGFloat(image.height))
    context.scaleBy(x: 1, y: -1)
    func stroke(_ points: [[NSNumber]], color: CGColor, close: Bool = false) {
        guard let first = points.first else { return }
        context.setStrokeColor(color)
        context.setLineWidth(4)
        context.move(
            to: CGPoint(x: first[0].doubleValue, y: first[1].doubleValue)
        )
        for point in points.dropFirst() {
            context.addLine(
                to: CGPoint(x: point[0].doubleValue, y: point[1].doubleValue)
            )
        }
        if close { context.closePath() }
        context.strokePath()
    }
    stroke(footprint, color: CGColor(red: 0.95, green: 0.78, blue: 0.16, alpha: 1), close: true)
    stroke(frontage, color: CGColor(red: 0.10, green: 0.88, blue: 0.92, alpha: 1))
    stroke(door, color: CGColor(red: 0.20, green: 0.92, blue: 0.36, alpha: 1))
    func marker(_ point: [NSNumber], color: CGColor, radius: CGFloat) {
        context.setFillColor(color)
        context.fillEllipse(
            in: CGRect(
                x: point[0].doubleValue - radius,
                y: point[1].doubleValue - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
    }
    marker(pivot, color: CGColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 1), radius: 7)
    marker(socket, color: CGColor(red: 0.22, green: 0.48, blue: 1, alpha: 1), radius: 7)
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
        throw V09Error.failed("cannot make registration overlay")
    }
    return output
}

private func decodedBytes(_ image: CGImage) throws -> [UInt8] {
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
        throw V09Error.failed("cannot decode image")
    }
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    return bytes
}

private func maskBounds(
    _ bytes: [UInt8],
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

private func median(_ values: [Int]) -> Int {
    let sorted = values.sorted()
    return sorted[sorted.count / 2]
}

private func mutateMaterialLibrary(_ v08: [String: Any]) throws -> [String: Any] {
    var library = v08
    library["libraryID"] = "industrial-l04-turbine-v09-north-prepixel"
    library["source"] =
        "task-owned numeric North roof/value redesign; no ImageGen or raster swatch"
    guard var materials = library["materials"] as? [[String: Any]] else {
        throw V09Error.failed("v08 material library malformed")
    }
    materials.append(contentsOf: [
        [
            "id": "l4t-v09-weathered-hall-steel",
            "baseColorRGBA": [0.42, 0.55, 0.54, 1],
            "roughness": 0.84,
            "metalness": 0.26,
            "pattern": "procedural-vertical-corrugation",
            "physicalScaleWorld": [12, 12],
            "textureMapping": [
                "mode": "world-scale-box-face-repeat-v1",
                "wrapS": "repeat", "wrapT": "repeat",
                "minificationFilter": "linear",
                "magnificationFilter": "linear",
                "mipFilter": "linear",
            ],
        ],
        [
            "id": "l4t-v09-nw-roof-steel",
            "baseColorRGBA": [0.28, 0.36, 0.33, 1],
            "roughness": 0.88,
            "metalness": 0.24,
            "pattern": "weathered-standing-seam",
            "physicalScaleWorld": [8, 8],
            "textureMapping": [
                "mode": "world-scale-box-face-repeat-v1",
                "wrapS": "repeat", "wrapT": "repeat",
                "minificationFilter": "linear",
                "magnificationFilter": "linear",
                "mipFilter": "linear",
            ],
        ],
        [
            "id": "l4t-v09-se-roof-steel",
            "baseColorRGBA": [0.17, 0.24, 0.23, 1],
            "roughness": 0.90,
            "metalness": 0.22,
            "pattern": "weathered-standing-seam",
            "physicalScaleWorld": [8, 8],
            "textureMapping": [
                "mode": "world-scale-box-face-repeat-v1",
                "wrapS": "repeat", "wrapT": "repeat",
                "minificationFilter": "linear",
                "magnificationFilter": "linear",
                "mipFilter": "linear",
            ],
        ],
    ])
    library["materials"] = materials
    return library
}

private func replaceV08(_ value: Any) -> Any {
    if let string = value as? String {
        return string
            .replacingOccurrences(of: "source-v08-prepixel", with: revision)
            .replacingOccurrences(of: "i04-v08-n-", with: "i04-v09-n-")
            .replacingOccurrences(of: "v08-long-sawtooth", with: "v09-four-sawtooth")
    }
    if let array = value as? [Any] { return array.map(replaceV08) }
    if let dictionary = value as? [String: Any] {
        return dictionary.mapValues(replaceV08)
    }
    return value
}

private func mutateScene(
    _ v08: [String: Any],
    materialSHA: String
) throws -> [String: Any] {
    guard var scene = replaceV08(v08) as? [String: Any] else {
        throw V09Error.failed("cannot clone v08 scene")
    }
    scene["sourceRevision"] = revision
    scene["sceneGeometryID"] = geometryID
    scene["sourceAuthority"] = false
    scene["productionSelected"] = false
    scene["derivation"] = [
        "sourceKind": "offline-scene-independent-north-roof-value-redesign",
        "siblingSource": NSNull(),
        "mirror": false,
        "rotationDegrees": 0,
        "transform": "none",
    ]
    scene["materialLibrary"] = [
        "role": "industrial-l04-turbine-v09-north-material-library",
        "file": "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v09-north-prepixel/materials/\(materialFileName)",
        "sha256": materialSHA,
    ]
    if var sampling = scene["sampling"] as? [String: Any] {
        sampling["sourceRevisionBinding"] = revision
        scene["sampling"] = sampling
    }
    guard var building = scene["building"] as? [String: Any] else {
        throw V09Error.failed("building missing during mutation")
    }
    var blocks = building["massBlocks"] as! [[String: Any]]
    for index in blocks.indices {
        if (blocks[index]["id"] as? String)?.contains("turbine-hall") == true {
            blocks[index]["materialID"] = "l4t-v09-weathered-hall-steel"
        }
        if (blocks[index]["id"] as? String)?.contains("staff-entry") == true {
            blocks[index]["dimensions"] = [18, 7, 0.6]
            blocks[index]["positionWorld"] = [-18, 5.5, -27.7]
        }
    }
    building["massBlocks"] = blocks
    building["wallMaterialID"] = "l4t-v09-weathered-hall-steel"
    building["roofMaterialID"] = "l4t-v09-nw-roof-steel"
    building["roofHeight"] = 8
    building["massingProfile"] = "turbine-works-v09-north-four-separated-sawtooth-foundry"
    building["roofVolumes"] = [
        ["id": "i04-v09-n-sawtooth-1", "shape": "hip", "dimensions": [4, 8, 6], "positionWorld": [-25, 22, 20], "materialID": "l4t-v09-nw-roof-steel", "trimMaterialID": "l4t-charcoal-structural-steel"],
        ["id": "i04-v09-n-sawtooth-2", "shape": "hip", "dimensions": [4, 8, 6], "positionWorld": [-13, 22, 14], "materialID": "l4t-v09-se-roof-steel", "trimMaterialID": "l4t-charcoal-structural-steel"],
        ["id": "i04-v09-n-sawtooth-3", "shape": "hip", "dimensions": [4, 8, 6], "positionWorld": [-1, 22, 8], "materialID": "l4t-v09-nw-roof-steel", "trimMaterialID": "l4t-charcoal-structural-steel"],
        ["id": "i04-v09-n-sawtooth-4", "shape": "hip", "dimensions": [4, 8, 6], "positionWorld": [9, 22, 0], "materialID": "l4t-v09-se-roof-steel", "trimMaterialID": "l4t-charcoal-structural-steel"],
    ]
    scene["building"] = building
    if var entrance = scene["entrance"] as? [String: Any] {
        entrance["width"] = 18
        entrance["height"] = 7
        scene["entrance"] = entrance
    }
    return scene
}

private func geometryHash(_ scene: [String: Any]) throws -> String {
    let values = try primitives(scene).map {
        [
            "id": $0.id,
            "materialID": $0.materialID,
            "positionWorld": [$0.center.x, $0.center.y, $0.center.z],
            "dimensions": [$0.size.x, $0.size.y, $0.size.z],
            "shape": $0.shape,
        ] as [String: Any]
    }
    return sha256(try stableJSON(values))
}

private func run(
    repositoryRoot: URL,
    artifactRoot: URL,
    evidenceRoot: URL
) throws {
    let v08Root = repositoryRoot.appendingPathComponent(
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v08-prepixel"
    )
    let v08SceneURL = v08Root.appendingPathComponent(
        "scenes/industrial_l04/variant-0/n/scene.json"
    )
    let v08MaterialURL = v08Root.appendingPathComponent(
        "materials/industrial-l04-turbine-v08-prepixel.json"
    )
    let v08RawURL = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/turbine-v08-north-raw-v02/diagnostics/raw-repeat/north/run-a/raw.png"
    )
    let v08Scene = try JSONSerialization.jsonObject(
        with: Data(contentsOf: v08SceneURL)
    ) as! [String: Any]
    let v08Material = try JSONSerialization.jsonObject(
        with: Data(contentsOf: v08MaterialURL)
    ) as! [String: Any]
    let library = try mutateMaterialLibrary(v08Material)
    let materialData = try stableJSON(library)
    let materialSHA = sha256(materialData)
    let scene = try mutateScene(v08Scene, materialSHA: materialSHA)
    let sceneData = try stableJSON(scene)
    let descriptorSHA = sha256(sceneData)
    let canonicalGeometrySHA = try geometryHash(scene)
    let materialURL = artifactRoot.appendingPathComponent(
        "materials/\(materialFileName)"
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
    let persistedLibrary = try JSONSerialization.jsonObject(
        with: Data(contentsOf: materialURL)
    ) as! [String: Any]
    let persistedScene = try JSONSerialization.jsonObject(
        with: Data(contentsOf: sceneURL)
    ) as! [String: Any]
    _ = try JSONDecoder().decode(
        MaterialLibraryDescriptor.self,
        from: Data(contentsOf: materialURL)
    )
    _ = try JSONDecoder().decode(
        SceneDescriptor.self,
        from: Data(contentsOf: sceneURL)
    )
    guard
        sha256(try stableJSON(persistedLibrary)) == materialSHA,
        sha256(try stableJSON(persistedScene)) == descriptorSHA,
        let persistedBuilding = persistedScene["building"] as? [String: Any],
        (persistedBuilding["width"] as? NSNumber)?.doubleValue == 56,
        (persistedBuilding["depth"] as? NSNumber)?.doubleValue == 56,
        let persistedRegistration = persistedScene["registration"] as? [String: Any],
        try pair(persistedRegistration["groundPivotSource"], "groundPivotSource") == [768, 896],
        try pair(persistedRegistration["frontageSocketSource"], "frontageSocketSource") == [896, 704],
        persistedRegistration["contactPolygonWorld"] as? [[Int]]
            == [[-28, -28], [28, -28], [28, 28], [-28, 28]]
    else {
        throw V09Error.failed("persisted descriptor/material registration binding failed")
    }

    let review = evidenceRoot.appendingPathComponent("review")
    let source = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: sourceSize
    )
    let sourceGray = try grayscale(source)
    let native = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: nativeSize
    )
    let nativeGray = try grayscale(native)
    let compact = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: compactSize
    )
    let compactGray = try grayscale(compact)
    let semantic = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: compactSize,
        semantic: true
    )
    let clay = try render(
        scene: persistedScene,
        library: persistedLibrary,
        size: sourceSize,
        clay: true
    )
    let registrationProof = try registrationOverlay(
        source,
        scene: persistedScene
    )
    let v08Raw = try neutralizedV08Raw(v08RawURL)
    let v08Native = try scaled(v08Raw, to: nativeSize)
    let v08Compact = try scaled(v08Raw, to: compactSize)
    let files: [(String, CGImage)] = [
        ("SOURCE-COLOR.png", source),
        ("SOURCE-GRAYSCALE.png", sourceGray),
        ("NATIVE-2X-COLOR.png", native),
        ("NATIVE-2X-GRAYSCALE.png", nativeGray),
        ("EXACT-192X128-COLOR.png", compact),
        ("EXACT-192X128-GRAYSCALE.png", compactGray),
        ("CLAY-SILHOUETTE.png", clay),
        ("FRONTAGE-REGISTRATION.png", registrationProof),
        ("SEMANTIC-192X128.png", semantic),
        ("V08-RAW-FAILURE-VS-V09-SOURCE-COLOR.png", try comparison(v08Raw, source, size: sourceSize)),
        ("V08-RAW-FAILURE-VS-V09-SOURCE-GRAYSCALE.png", try comparison(try grayscale(v08Raw), sourceGray, size: sourceSize)),
        ("V08-RAW-FAILURE-VS-V09-NATIVE-2X-COLOR.png", try comparison(v08Native, native, size: nativeSize)),
        ("V08-RAW-FAILURE-VS-V09-NATIVE-2X-GRAYSCALE.png", try comparison(try grayscale(v08Native), nativeGray, size: nativeSize)),
        ("V08-RAW-FAILURE-VS-V09-192X128-COLOR.png", try comparison(v08Compact, compact, size: compactSize)),
        ("V08-RAW-FAILURE-VS-V09-192X128-GRAYSCALE.png", try comparison(try grayscale(v08Compact), compactGray, size: compactSize)),
    ]
    for (name, image) in files {
        try writePNG(image, to: review.appendingPathComponent(name))
    }

    let semanticBytes = try decodedBytes(semantic)
    let width = Int(compactSize.width)
    let height = Int(compactSize.height)
    let peakPredicates: [(UInt8, UInt8, UInt8) -> Bool] = [
        { $0 > 200 && $1 < 170 && $2 < 170 },
        { $1 > 190 && $0 < 170 && $2 < 190 },
        { $2 > 200 && $0 < 170 && $1 < 200 },
        { $0 > 190 && $1 > 180 && $2 < 170 },
    ]
    let peakBounds = peakPredicates.map { predicate in
        maskBounds(
            semanticBytes,
            width: width,
            height: height,
            predicate: predicate
        )
    }.sorted { $0.midX < $1.midX }
    guard peakBounds.count == 4, peakBounds.allSatisfy({ !$0.isNull }) else {
        throw V09Error.failed("four compact semantic peaks not retained")
    }
    var valleyWidths: [Int] = []
    var valleyDepths: [Int] = []
    var peakSeparations: [Double] = []
    for index in 0..<3 {
        valleyWidths.append(
            Int(floor(peakBounds[index + 1].minX - peakBounds[index].maxX - 1))
        )
        valleyDepths.append(
            Int(
                floor(
                    min(peakBounds[index].height, peakBounds[index + 1].height)
                        * 0.52
                )
            )
        )
        peakSeparations.append(
            peakBounds[index + 1].midX - peakBounds[index].midX
        )
    }
    let staffBounds = maskBounds(
        semanticBytes,
        width: width,
        height: height
    ) { $0 > 220 && $1 < 120 && $2 > 190 }
    let freightBounds = maskBounds(
        semanticBytes,
        width: width,
        height: height
    ) { $0 < 40 && $1 > 200 && $2 > 210 }

    let compactBytes = try decodedBytes(compact)
    func lumas(where predicate: (Int, Int, Int) -> Bool) -> [Int] {
        var values: [Int] = []
        for y in 0..<height {
            for x in 0..<width where predicate(x, y, (y * width + x) * 4) {
                let index = (y * width + x) * 4
                let red = 0.2126 * Double(compactBytes[index])
                let green = 0.7152 * Double(compactBytes[index + 1])
                let blue = 0.0722 * Double(compactBytes[index + 2])
                values.append(Int(red + green + blue))
            }
        }
        return values
    }
    let cameraValue = try camera(from: persistedScene)
    let lightValue = try vector(
        (persistedScene["light"] as! [String: Any])["keyOrigin"],
        "light.keyOrigin"
    )
    let items = try primitives(persistedScene)
    let roofFaces = try items.filter { $0.id.contains("sawtooth") }
        .flatMap {
            try faces(
                $0,
                camera: cameraValue,
                lightOrigin: lightValue,
                size: compactSize
            )
        }
    let nwLuma = roofFaces.filter { $0.role == "northwest-slope" }
        .map { Int(150 * $0.shade) }
    let seLuma = roofFaces.filter { $0.role == "southeast-slope" }
        .map { Int(150 * $0.shade) }
    let roofPixels = lumas { _, _, index in
        peakPredicates.contains {
            $0(
                semanticBytes[index],
                semanticBytes[index + 1],
                semanticBytes[index + 2]
            )
        }
    }
    let hallPixels = lumas { _, _, index in
        semanticBytes[index] > 120
            && semanticBytes[index] < 200
            && semanticBytes[index + 1] < 130
            && semanticBytes[index + 2] > 150
    }
    guard !roofPixels.isEmpty, !hallPixels.isEmpty, !nwLuma.isEmpty, !seLuma.isEmpty else {
        throw V09Error.failed("luma sample regions empty")
    }
    let roofMedian = median(roofPixels)
    let hallMedian = median(hallPixels)
    let nwMedian = median(nwLuma)
    let seMedian = median(seLuma)
    let metrics: [String: Any] = [
        "schema": 1,
        "task": "PLAY-027",
        "revision": revision,
        "generatedAt": fixedTimestamp,
        "sourceAuthority": false,
        "productionSelected": false,
        "descriptorSHA256": descriptorSHA,
        "materialLibrarySHA256": materialSHA,
        "canonicalGeometrySHA256": canonicalGeometrySHA,
        "v08DescriptorSHA256": try sha256(v08SceneURL),
        "v08MaterialSHA256": try sha256(v08MaterialURL),
        "v08RawFailureSHA256": try sha256(v08RawURL),
        "cameraSHA256": sha256(try stableJSON(persistedScene["camera"]!)),
        "registrationSHA256": sha256(try stableJSON(persistedScene["registration"]!)),
        "peakCount": 4,
        "peakBounds192": peakBounds.map {
            [Int($0.minX), Int($0.minY), Int($0.width), Int($0.height)]
        },
        "internalValleyWidths192": valleyWidths,
        "internalValleyDepths192": valleyDepths,
        "adjacentPeakSeparations192": peakSeparations,
        "roofMedianLuma192": roofMedian,
        "hallMedianLuma192": hallMedian,
        "roofHallAbsoluteMedianLumaSeparation192": abs(roofMedian - hallMedian),
        "northwestSlopeMedianLuma192": nwMedian,
        "southeastSlopeMedianLuma192": seMedian,
        "northwestSlopeAdvantage192": nwMedian - seMedian,
        "staffEntranceBounds192": [
            Int(staffBounds.minX), Int(staffBounds.minY),
            Int(staffBounds.width), Int(staffBounds.height),
        ],
        "freightCombinedBounds192": [
            Int(freightBounds.minX), Int(freightBounds.minY),
            Int(freightBounds.width), Int(freightBounds.height),
        ],
        "fixedRegistration": [
            "footprintUnits": [56, 56],
            "pivotSource": [768, 896],
            "socketSource": [896, 704],
        ],
        "gates": [
            "fourPeaks": peakBounds.count == 4,
            "threeValleys": valleyWidths.count == 3,
            "valleyWidthAtLeast2": valleyWidths.allSatisfy { $0 >= 2 },
            "valleyDepthAtLeast2": valleyDepths.allSatisfy { $0 >= 2 },
            "adjacentPeakSeparationOver4": peakSeparations.allSatisfy { $0 > 4 },
            "roofHallLumaSeparationAtLeast25": abs(roofMedian - hallMedian) >= 25,
            "northwestSlopeAdvantageAtLeast12": nwMedian - seMedian >= 12,
            "staffWidthOver4": staffBounds.width > 4,
            "staffHeightOver4": staffBounds.height > 4,
            "freightWidthOver8": freightBounds.width > 8,
            "productionSelectedFalse": true,
            "sourceAuthorityFalse": true,
        ],
    ]
    let gates = metrics["gates"] as! [String: Bool]
    print(
        "METRICS valleys=\(valleyWidths)/\(valleyDepths)"
            + " separations=\(peakSeparations)"
            + " roofHall=\(roofMedian)/\(hallMedian)"
            + " delta=\(abs(roofMedian - hallMedian))"
            + " slopes=\(nwMedian - seMedian)"
            + " staff=\(staffBounds.width)x\(staffBounds.height)"
            + " freight=\(freightBounds.width)x\(freightBounds.height)"
    )
    guard gates.values.allSatisfy({ $0 }) else {
        throw V09Error.failed(
            "prepixel gates failed: \(gates.filter { !$0.value }.keys.sorted())"
        )
    }
    try FileManager.default.createDirectory(
        at: evidenceRoot,
        withIntermediateDirectories: true
    )
    try stableJSON(metrics).write(
        to: evidenceRoot.appendingPathComponent("PREPIXEL-VALIDATION.json")
    )
    let hashes = try Dictionary(uniqueKeysWithValues: files.map { name, _ in
        (name, try sha256(review.appendingPathComponent(name)))
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
        "canonicalGeometrySHA256": canonicalGeometrySHA,
        "reviewSHA256": hashes,
        "rawSourceProcesses": 0,
        "normalizerProcesses": 0,
    ]
    try stableJSON(manifest).write(
        to: evidenceRoot.appendingPathComponent("MANIFEST.json")
    )
    let request = """
    # PLAY-027 Industrial L4 North v09 pre-pixel review

    Disposition: `PENDING_INDEPENDENT_PREPIXEL_REVIEW`.

    This North-only revision replaces the overlapping v08 roof with four spatially
    separated eight-unit sawtooth volumes and widens the staff entrance. The broad
    Turbine Works hall, L-shaped court, three freight bays, subordinate stack,
    footprint, pivot, socket, frontage, contact polygon, NW light, and SE shadow
    remain bound. All panels are descriptor-camera analytical proof; they are not
    raw source pixels.

    `sourceAuthority=false`; `productionSelected=false`.
    """
    try Data(request.utf8).write(
        to: evidenceRoot.appendingPathComponent("REVIEW-REQUEST.md")
    )
}

private func argument(_ name: String) throws -> String {
    guard let index = CommandLine.arguments.firstIndex(of: name),
          CommandLine.arguments.indices.contains(index + 1)
    else {
        throw V09Error.failed("missing \(name)")
    }
    return CommandLine.arguments[index + 1]
}

@main
private enum BuildIndustrialL4TurbineV09NorthPrepixel {
    static func main() {
        do {
            let repositoryRoot = URL(
                fileURLWithPath: try argument("--repository-root")
            )
            let artifactRoot = URL(
                fileURLWithPath: try argument("--artifact-root")
            )
            let evidenceRoot = URL(
                fileURLWithPath: try argument("--evidence-root")
            )
            try run(
                repositoryRoot: repositoryRoot,
                artifactRoot: artifactRoot,
                evidenceRoot: evidenceRoot
            )
            print("PASS \(revision)")
        } catch {
            fputs("FAIL \(error)\n", stderr)
            exit(1)
        }
    }
}
