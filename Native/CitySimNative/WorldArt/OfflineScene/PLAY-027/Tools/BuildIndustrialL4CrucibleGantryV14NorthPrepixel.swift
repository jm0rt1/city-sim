import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private enum V14Error: Error, CustomStringConvertible {
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
    let target: V3
    let forward: V3
    let right: V3
    let up: V3
    let pixelsPerWorld: Double
    let viewport: CGSize
    let offset: P2
}

private enum PartShape: String {
    case box
    case cylinder
}

private struct Part {
    let id: String
    let role: String
    let materialID: String
    let center: V3
    let size: V3
    let shape: PartShape
    let radialSegments: Int
}

private struct Face {
    let part: Part
    let points: [P2]
    let depth: Double
    let shade: Double
    let normal: V3
}

private let revision = "source-v14-prepixel"
private let geometryID = "industrial-l04-crucible-gantry-v14-north-board-led"
private let libraryID = "industrial-l04-crucible-gantry-v14-north-prepixel"
private let materialFile = "\(libraryID).json"
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
        throw V14Error.failed("zero vector")
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

private func vector(_ value: Any?, _ name: String) throws -> V3 {
    guard let values = value as? [NSNumber], values.count == 3 else {
        throw V14Error.failed("\(name) must have three values")
    }
    return V3(
        x: values[0].doubleValue,
        y: values[1].doubleValue,
        z: values[2].doubleValue
    )
}

private func pair(_ value: Any?, _ name: String) throws -> [Double] {
    guard let values = value as? [NSNumber], values.count == 2 else {
        throw V14Error.failed("\(name) must have two values")
    }
    return values.map(\.doubleValue)
}

private func camera(from scene: [String: Any]) throws -> Camera {
    guard
        let value = scene["camera"] as? [String: Any],
        let scale = (value["orthographicScale"] as? NSNumber)?.doubleValue
    else {
        throw V14Error.failed("camera contract missing")
    }
    let position = try vector(value["positionWorld"], "camera.positionWorld")
    let target = try vector(value["targetWorld"], "camera.targetWorld")
    let viewportValues = try pair(
        value["renderViewportPixels"],
        "camera.renderViewportPixels"
    )
    let offsetValues = try pair(
        value["postProjectionOffsetPixels"],
        "camera.postProjectionOffsetPixels"
    )
    let forward = try normalized(target - position)
    let right = try normalized(cross(forward, V3(x: 0, y: 1, z: 0)))
    let up = try normalized(cross(right, forward))
    return Camera(
        target: target,
        forward: forward,
        right: right,
        up: up,
        pixelsPerWorld: viewportValues[1] / (2 * scale),
        viewport: CGSize(width: viewportValues[0], height: viewportValues[1]),
        offset: P2(x: offsetValues[0], y: offsetValues[1])
    )
}

private func project(_ point: V3, camera: Camera, size: CGSize) -> P2 {
    let relative = point - camera.target
    let x = camera.viewport.width * 0.5
        + dot(relative, camera.right) * camera.pixelsPerWorld
        + camera.offset.x
    let y = camera.viewport.height * 0.5
        - dot(relative, camera.up) * camera.pixelsPerWorld
        + camera.offset.y
    return P2(
        x: x * Double(size.width / camera.viewport.width),
        y: y * Double(size.height / camera.viewport.height)
    )
}

private func part(
    _ id: String,
    _ role: String,
    _ material: String,
    _ center: [Double],
    _ size: [Double],
    shape: PartShape = .box,
    segments: Int = 12
) -> Part {
    Part(
        id: id,
        role: role,
        materialID: material,
        center: V3(x: center[0], y: center[1], z: center[2]),
        size: V3(x: size[0], y: size[1], z: size[2]),
        shape: shape,
        radialSegments: segments
    )
}

// Board-led v14: the hall occupies the west/rear half of the lot while the
// crane and furnace command an open road-connected eastern court.
private func authoredParts() -> [Part] {
    var parts: [Part] = [
        part("v14-foundation", "foundation", "v14-dark-foundation",
             [0, 0.7, 0], [56, 1.4, 56]),
        part("v14-road-court", "court", "v14-scored-concrete",
             [11, 1.5, -12], [34, 1.6, 32]),
        part("v14-foundry-hall", "masonryHall", "v14-warm-masonry",
             [-12, 12, 5], [32, 22, 46]),
        part("v14-hall-roof", "roof", "v14-dark-roof-steel",
             [-12, 24, 5], [34, 3, 48]),
        part("v14-clerestory", "clerestory", "v14-warm-glazing",
             [-12, 27, 7], [26, 3, 32]),
        part("v14-clerestory-cap", "roof", "v14-dark-roof-steel",
             [-12, 29, 7], [28, 1.5, 34]),
        part("v14-control-annex", "staffAnnex", "v14-warm-masonry",
             [20, 6, 17], [14, 10, 18]),
        part("v14-control-roof", "roof", "v14-oxidized-copper",
             [20, 12, 17], [16, 2, 20]),
        part("v14-staff-entry", "staffEntry", "v14-warm-glazing",
             [27.2, 5.7, 12], [1.6, 8, 7]),
        part("v14-staff-surround", "staffSurround", "v14-concrete-trim",
             [26.8, 6, 12], [2.4, 10, 10]),
        part("v14-boiler-block", "boiler", "v14-restrained-green",
             [-22, 8, 21], [9, 14, 11]),
        part("v14-stack", "stack", "v14-warm-masonry",
             [-22, 24, 22], [5.5, 31, 5.5], shape: .cylinder),
        part("v14-stack-rim", "stack", "v14-dark-gantry-steel",
             [-22, 40, 22], [7, 2.2, 7], shape: .cylinder),
    ]

    // A true bridge crane: two deep girders, linked trolley rail, and
    // buttressed towers around a genuinely open court.
    parts += [
        part("v14-gantry-pier-west", "gantryPier", "v14-dark-gantry-steel",
             [-1, 17, -7], [5, 31, 7]),
        part("v14-gantry-pier-east", "gantryPier", "v14-dark-gantry-steel",
             [25, 17, -7], [5, 31, 7]),
        part("v14-gantry-west-foot", "gantryButtress", "v14-dark-gantry-steel",
             [-1, 4, -7], [9, 7, 11]),
        part("v14-gantry-east-foot", "gantryButtress", "v14-dark-gantry-steel",
             [25, 4, -7], [9, 7, 11]),
        part("v14-gantry-girder-front", "gantryBeam", "v14-dark-gantry-steel",
             [12, 32, -11], [34, 6, 4]),
        part("v14-gantry-girder-rear", "gantryBeam", "v14-dark-gantry-steel",
             [12, 32, -3], [34, 6, 4]),
        part("v14-gantry-tie-west", "gantryTie", "v14-structural-mid-steel",
             [-1, 32, -7], [5, 3, 12]),
        part("v14-gantry-tie-center", "gantryTie", "v14-structural-mid-steel",
             [12, 32, -7], [4, 3, 12]),
        part("v14-gantry-tie-east", "gantryTie", "v14-structural-mid-steel",
             [25, 32, -7], [5, 3, 12]),
        part("v14-crane-trolley", "gantryTrolley", "v14-oxidized-copper",
             [12, 28, -7], [7, 5, 8]),
        part("v14-lift-rail", "gantryLift", "v14-process-heat",
             [12, 23, -7], [1.2, 8, 1.2]),
    ]

    // Large stepped octagonal furnace. Concentric cylinders produce a clear
    // base, taper, shoulder, neck, rim and hot mouth in the eventual native
    // SceneKit vocabulary while the analytic proof uses the same volumes.
    parts += [
        part("v14-crucible-base", "crucibleBase", "v14-dark-gantry-steel",
             [12, 4, -7], [16, 3, 16], shape: .cylinder),
        part("v14-crucible-lower", "crucible", "v14-oxidized-copper",
             [12, 8, -7], [13, 7, 13], shape: .cylinder),
        part("v14-crucible-shoulder", "crucible", "v14-oxidized-copper",
             [12, 13, -7], [17, 4, 17], shape: .cylinder),
        part("v14-crucible-upper", "crucible", "v14-oxidized-copper-light",
             [12, 17, -7], [14, 5, 14], shape: .cylinder),
        part("v14-crucible-neck", "crucibleNeck", "v14-dark-gantry-steel",
             [12, 20, -7], [10, 2, 10], shape: .cylinder),
        part("v14-crucible-rim", "crucibleRim", "v14-concrete-trim",
             [12, 21.8, -7], [13, 2.5, 13], shape: .cylinder),
        part("v14-crucible-mouth", "crucibleMouth", "v14-process-heat",
             [12, 23.2, -7], [9, 1.5, 9], shape: .cylinder),
    ]

    // Three grouped, road-connected freight beats. The dark recesses sit
    // within heavy lintel/post frames and connect to individual apron rails.
    let bayCenters = [-20.0, -10.0, 0.0]
    for (index, x) in bayCenters.enumerated() {
        let n = index + 1
        parts += [
            part("v14-freight-\(n)-recess", "freight\(n)",
                 "v14-deep-freight-recess", [x, 6.5, -22.7], [7, 9, 2]),
            part("v14-freight-\(n)-header", "freightHeader",
                 "v14-concrete-trim", [x, 12, -21.5], [9, 3, 4]),
            part("v14-freight-\(n)-left-post", "freightPost",
                 "v14-dark-gantry-steel", [x - 4.5, 7, -21.5], [1.5, 11, 4]),
            part("v14-freight-\(n)-right-post", "freightPost",
                 "v14-dark-gantry-steel", [x + 4.5, 7, -21.5], [1.5, 11, 4]),
            part("v14-freight-\(n)-rail", "serviceRail",
                 "v14-structural-mid-steel", [x, 2.5, -25], [1, 1, 7]),
        ]
    }

    // Large readable functional details, deliberately not micro-greebles.
    parts += [
        part("v14-hall-cornice", "hallTrim", "v14-concrete-trim",
             [-12, 21.5, -18], [32, 2, 2]),
        part("v14-hall-window-band", "hallWindows", "v14-warm-glazing",
             [-12, 16, -18.2], [25, 4, 1.4]),
        part("v14-service-pipe-a", "pipe", "v14-oxidized-copper",
             [-25, 12, 7], [2.4, 18, 2.4], shape: .cylinder),
        part("v14-service-pipe-b", "pipe", "v14-oxidized-copper",
             [-25, 12, 13], [2.4, 18, 2.4], shape: .cylinder),
        part("v14-court-rail-west", "courtRail", "v14-structural-mid-steel",
             [2, 2.5, -23], [1, 2, 10]),
        part("v14-court-rail-east", "courtRail", "v14-structural-mid-steel",
             [24, 2.5, -23], [1, 2, 10]),
    ]
    return parts
}

private let palette: [String: [Double]] = [
    "v14-dark-foundation": [0.17, 0.20, 0.19, 1],
    "v14-scored-concrete": [0.43, 0.42, 0.37, 1],
    "v14-warm-masonry": [0.62, 0.37, 0.23, 1],
    "v14-dark-roof-steel": [0.18, 0.25, 0.24, 1],
    "v14-dark-gantry-steel": [0.075, 0.12, 0.13, 1],
    "v14-structural-mid-steel": [0.24, 0.31, 0.30, 1],
    "v14-oxidized-copper": [0.25, 0.52, 0.48, 1],
    "v14-oxidized-copper-light": [0.39, 0.67, 0.60, 1],
    "v14-concrete-trim": [0.66, 0.61, 0.51, 1],
    "v14-restrained-green": [0.25, 0.38, 0.30, 1],
    "v14-warm-glazing": [0.90, 0.57, 0.24, 1],
    "v14-process-heat": [1.00, 0.32, 0.07, 1],
    "v14-deep-freight-recess": [0.035, 0.05, 0.05, 1],
]

private func boxVertices(_ part: Part) -> [V3] {
    let h = part.size * 0.5
    return [
        V3(x: part.center.x - h.x, y: part.center.y - h.y, z: part.center.z - h.z),
        V3(x: part.center.x + h.x, y: part.center.y - h.y, z: part.center.z - h.z),
        V3(x: part.center.x + h.x, y: part.center.y + h.y, z: part.center.z - h.z),
        V3(x: part.center.x - h.x, y: part.center.y + h.y, z: part.center.z - h.z),
        V3(x: part.center.x - h.x, y: part.center.y - h.y, z: part.center.z + h.z),
        V3(x: part.center.x + h.x, y: part.center.y - h.y, z: part.center.z + h.z),
        V3(x: part.center.x + h.x, y: part.center.y + h.y, z: part.center.z + h.z),
        V3(x: part.center.x - h.x, y: part.center.y + h.y, z: part.center.z + h.z),
    ]
}

private func faces(for part: Part, camera: Camera, size: CGSize) throws -> [Face] {
    var definitions: [(V3, [V3])] = []
    if part.shape == .box {
        let v = boxVertices(part)
        definitions = [
            (V3(x: 0, y: 1, z: 0), [v[3], v[2], v[6], v[7]]),
            (V3(x: 1, y: 0, z: 0), [v[1], v[5], v[6], v[2]]),
            (V3(x: -1, y: 0, z: 0), [v[4], v[0], v[3], v[7]]),
            (V3(x: 0, y: 0, z: 1), [v[5], v[4], v[7], v[6]]),
            (V3(x: 0, y: 0, z: -1), [v[0], v[1], v[2], v[3]]),
        ]
    } else {
        let bottom = part.center.y - part.size.y * 0.5
        let top = part.center.y + part.size.y * 0.5
        let rx = part.size.x * 0.5
        let rz = part.size.z * 0.5
        let ring: (Double) -> [V3] = { y in
            (0..<part.radialSegments).map { index in
                let angle = Double(index) * 2 * .pi
                    / Double(part.radialSegments) + .pi / 8
                return V3(
                    x: part.center.x + cos(angle) * rx,
                    y: y,
                    z: part.center.z + sin(angle) * rz
                )
            }
        }
        let low = ring(bottom)
        let high = ring(top)
        definitions.append((V3(x: 0, y: 1, z: 0), high))
        for index in 0..<part.radialSegments {
            let next = (index + 1) % part.radialSegments
            let normal = try normalized(
                V3(
                    x: (low[index].x + low[next].x) * 0.5 - part.center.x,
                    y: 0,
                    z: (low[index].z + low[next].z) * 0.5 - part.center.z
                )
            )
            definitions.append(
                (normal, [low[index], low[next], high[next], high[index]])
            )
        }
    }
    let light = try normalized(V3(x: -0.5, y: 0.82, z: -0.42))
    return definitions.compactMap { normal, points in
        // Faces directed away from the camera are not raster authority.
        if dot(normal, camera.forward) >= 0.02 { return nil }
        let projected = points.map { project($0, camera: camera, size: size) }
        let depth = points.map { dot($0 - camera.target, camera.forward) }
            .reduce(0, +) / Double(points.count)
        let shade = 0.58 + 0.42 * max(0, dot(normal, light))
        return Face(
            part: part,
            points: projected,
            depth: depth,
            shade: shade,
            normal: normal
        )
    }
}

private func path(_ points: [P2]) -> CGPath {
    let value = CGMutablePath()
    guard let first = points.first else { return value }
    value.move(to: CGPoint(x: first.x, y: first.y))
    for point in points.dropFirst() {
        value.addLine(to: CGPoint(x: point.x, y: point.y))
    }
    value.closeSubpath()
    return value
}

private func context(size: CGSize) throws -> CGContext {
    guard let value = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: Int(size.width) * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V14Error.failed("cannot create context")
    }
    value.translateBy(x: 0, y: size.height)
    value.scaleBy(x: 1, y: -1)
    return value
}

private enum RenderMode {
    case color
    case grayscale
    case semantic
    case heroMask
    case silhouette
}

private func semanticColor(_ role: String) -> [Double] {
    if role.hasPrefix("gantry") { return [0.10, 0.78, 0.95, 1] }
    if role.hasPrefix("crucible") { return [0.96, 0.43, 0.08, 1] }
    if role.hasPrefix("freight1") { return [0.15, 0.92, 0.32, 1] }
    if role.hasPrefix("freight2") { return [0.70, 0.90, 0.12, 1] }
    if role.hasPrefix("freight3") { return [0.20, 0.42, 0.98, 1] }
    if role.hasPrefix("staff") { return [0.92, 0.18, 0.80, 1] }
    if role == "masonryHall" { return [0.58, 0.20, 0.68, 1] }
    return [0.30, 0.32, 0.34, 1]
}

private func drawTexture(
    in context: CGContext,
    face: Face,
    size: CGSize
) {
    guard face.part.role == "masonryHall"
        || face.part.role == "roof"
        || face.part.role == "court"
    else { return }
    context.saveGState()
    context.addPath(path(face.points))
    context.clip()
    let scale = Double(size.width / sourceSize.width)
    context.setStrokeColor(CGColor(gray: 0.08, alpha: 0.35))
    context.setLineWidth(max(0.35, 1.1 * scale))
    let bounds = path(face.points).boundingBox
    if face.part.role == "masonryHall" {
        var y = bounds.minY
        var row = 0
        while y <= bounds.maxY {
            context.move(to: CGPoint(x: bounds.minX, y: y))
            context.addLine(to: CGPoint(x: bounds.maxX, y: y))
            context.strokePath()
            let spacing = max(5, 13 * scale)
            var x = bounds.minX + (row.isMultiple(of: 2) ? 0 : spacing)
            while x <= bounds.maxX {
                context.move(to: CGPoint(x: x, y: y))
                context.addLine(to: CGPoint(x: x, y: y + spacing))
                context.strokePath()
                x += spacing * 2
            }
            y += spacing
            row += 1
        }
    } else {
        let spacing = max(4, 18 * scale)
        var x = bounds.minX
        while x <= bounds.maxX {
            context.move(to: CGPoint(x: x, y: bounds.minY))
            context.addLine(to: CGPoint(x: x, y: bounds.maxY))
            context.strokePath()
            x += spacing
        }
    }
    context.restoreGState()
}

private func render(
    parts: [Part],
    camera: Camera,
    size: CGSize,
    mode: RenderMode
) throws -> CGImage {
    let output = try context(size: size)
    output.setFillColor(CGColor(red: 0.105, green: 0.12, blue: 0.125, alpha: 1))
    output.fill(CGRect(origin: .zero, size: size))
    var allFaces: [Face] = []
    for part in parts {
        if mode == .heroMask {
            guard part.role.hasPrefix("gantry")
                || part.role.hasPrefix("crucible")
            else { continue }
        } else if mode == .silhouette && part.role == "stack" {
            continue
        }
        allFaces += try faces(for: part, camera: camera, size: size)
    }
    allFaces.sort { $0.depth > $1.depth }
    let scale = Double(size.width / sourceSize.width)
    for face in allFaces {
        let rgba: [Double]
        switch mode {
        case .semantic:
            rgba = semanticColor(face.part.role)
        case .heroMask, .silhouette:
            rgba = [1, 1, 1, 1]
        case .color, .grayscale:
            rgba = palette[face.part.materialID] ?? [0.5, 0.5, 0.5, 1]
        }
        let shade = mode == .color || mode == .grayscale ? face.shade : 1
        let r = min(1, rgba[0] * shade)
        let g = min(1, rgba[1] * shade)
        let b = min(1, rgba[2] * shade)
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        output.setFillColor(
            mode == .grayscale
                ? CGColor(gray: luma, alpha: 1)
                : CGColor(red: r, green: g, blue: b, alpha: 1)
        )
        output.addPath(path(face.points))
        output.fillPath()
        if mode == .color || mode == .grayscale {
            drawTexture(in: output, face: face, size: size)
            output.setStrokeColor(CGColor(gray: 0.035, alpha: 0.82))
            output.setLineWidth(max(0.35, 1.5 * scale))
            output.addPath(path(face.points))
            output.strokePath()
        }
    }
    guard let image = output.makeImage() else {
        throw V14Error.failed("cannot make rendered image")
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
        throw V14Error.failed("cannot create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw V14Error.failed("cannot finalize \(url.path)")
    }
}

private func loadImage(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw V14Error.failed("cannot load \(url.path)")
    }
    return image
}

private func tiled(_ images: [CGImage], cell: CGSize) throws -> CGImage {
    let output = try context(
        size: CGSize(width: cell.width * Double(images.count), height: cell.height)
    )
    output.setFillColor(CGColor(gray: 0.08, alpha: 1))
    output.fill(
        CGRect(
            x: 0,
            y: 0,
            width: cell.width * Double(images.count),
            height: cell.height
        )
    )
    for (index, image) in images.enumerated() {
        output.interpolationQuality = .high
        output.draw(
            image,
            in: CGRect(
                x: Double(index) * cell.width,
                y: 0,
                width: cell.width,
                height: cell.height
            )
        )
    }
    guard let result = output.makeImage() else {
        throw V14Error.failed("cannot create comparison")
    }
    return result
}

private func registrationPanel(
    image: CGImage,
    camera: Camera
) throws -> CGImage {
    let output = try context(size: sourceSize)
    output.draw(image, in: CGRect(origin: .zero, size: sourceSize))
    let corners = [
        V3(x: -28, y: 0, z: -28),
        V3(x: 28, y: 0, z: -28),
        V3(x: 28, y: 0, z: 28),
        V3(x: -28, y: 0, z: 28),
    ].map { project($0, camera: camera, size: sourceSize) }
    output.setStrokeColor(CGColor(red: 0.2, green: 0.95, blue: 0.4, alpha: 1))
    output.setLineWidth(3)
    output.addPath(path(corners))
    output.strokePath()
    output.setStrokeColor(CGColor(red: 1, green: 0.78, blue: 0.1, alpha: 1))
    output.setLineWidth(5)
    output.move(to: CGPoint(x: 768, y: 640))
    output.addLine(to: CGPoint(x: 1024, y: 768))
    output.strokePath()
    output.setFillColor(CGColor(red: 1, green: 0.12, blue: 0.12, alpha: 1))
    output.fillEllipse(in: CGRect(x: 888, y: 696, width: 16, height: 16))
    output.setFillColor(CGColor(red: 0.1, green: 0.75, blue: 1, alpha: 1))
    output.fillEllipse(in: CGRect(x: 760, y: 888, width: 16, height: 16))
    guard let result = output.makeImage() else {
        throw V14Error.failed("cannot create registration panel")
    }
    return result
}

private func recursivelyReplace(_ value: Any) -> Any {
    if let string = value as? String {
        return string
            .replacingOccurrences(of: "source-v10-prepixel", with: revision)
            .replacingOccurrences(of: "i04-v10-n-", with: "v14-")
            .replacingOccurrences(
                of: "turbine-works-v10-north-continuous-four-cycle-sawtooth-band",
                with: geometryID
            )
    }
    if let values = value as? [Any] { return values.map(recursivelyReplace) }
    if let values = value as? [String: Any] {
        return values.mapValues(recursivelyReplace)
    }
    return value
}

private func materialLibrary(from template: [String: Any]) -> [String: Any] {
    var library = recursivelyReplace(template) as! [String: Any]
    library["libraryID"] = libraryID
    library["source"] =
        "task-owned board-led Crucible Gantry Works numeric materials; no ImageGen swatch"
    library["imageGenMaterialSwatchesUsed"] = false
    let mapping: [String: Any] = [
        "mode": "world-scale-box-face-repeat-v1",
        "wrapS": "repeat",
        "wrapT": "repeat",
        "minificationFilter": "linear",
        "magnificationFilter": "linear",
        "mipFilter": "linear",
    ]
    library["materials"] = palette.keys.sorted().map { id in
        [
            "id": id,
            "baseColorRGBA": palette[id]!,
            "roughness": id.contains("glazing") ? 0.42 : 0.82,
            "metalness": id.contains("steel") || id.contains("copper") ? 0.38 : 0.04,
            "pattern": id.replacingOccurrences(of: "v14-", with: ""),
            "physicalScaleWorld": [10, 10],
            "textureMapping": mapping,
        ] as [String: Any]
    }
    library["productionSelected"] = false
    return library
}

private func sceneDescriptor(
    from template: [String: Any],
    parts: [Part],
    materialSHA: String
) -> [String: Any] {
    var scene = recursivelyReplace(template) as! [String: Any]
    scene["sceneGeometryID"] = geometryID
    scene["sourceRevision"] = revision
    scene["sourceAuthority"] = false
    scene["productionSelected"] = false
    scene["authoredIndependently"] = true
    scene["derivation"] = [
        "sourceKind": "offline-scene-v14-board-led-functional-translation",
        "siblingSource": NSNull(),
        "mirror": false,
        "rotationDegrees": 0,
        "transform": "none",
    ]
    scene["materialLibrary"] = [
        "role": "industrial-l04-crucible-gantry-v14-north-material-library",
        "file": "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-crucible-gantry-v14-north-prepixel/materials/\(materialFile)",
        "sha256": materialSHA,
    ]
    if var sampling = scene["sampling"] as? [String: Any] {
        sampling["sourceRevisionBinding"] = revision
        scene["sampling"] = sampling
    }
    var building = scene["building"] as! [String: Any]
    building["massingProfile"] = geometryID
    building["usesExplicitComponentGeometry"] = true
    building["massBlocks"] = parts.filter { $0.shape == .box }.map {
        [
            "id": $0.id,
            "dimensions": [$0.size.x, $0.size.y, $0.size.z],
            "positionWorld": [$0.center.x, $0.center.y, $0.center.z],
            "materialID": $0.materialID,
        ]
    }
    building["roofVolumes"] = []
    building["trimBands"] = []
    building["wallMaterialID"] = "v14-warm-masonry"
    building["trimMaterialID"] = "v14-dark-gantry-steel"
    building["roofMaterialID"] = "v14-dark-roof-steel"
    building["foundationMaterialID"] = "v14-dark-foundation"
    building["foundationDimensions"] = [56, 1.4, 56]
    building["foundationPositionWorld"] = [0, 0.7, 0]
    building["chimney"] = [
        "positionWorld": [-22, 24, 22],
        "dimensions": [5.5, 31, 5.5],
        "materialID": "v14-warm-masonry",
    ]
    scene["building"] = building
    scene["props"] = parts.filter { $0.shape == .cylinder }.map {
        [
            "id": $0.id,
            "kind": "explicit-cylinder",
            "positionWorld": [$0.center.x, $0.center.y, $0.center.z],
            "dimensions": [$0.size.x, $0.size.y, $0.size.z],
            "materialID": $0.materialID,
        ]
    }
    scene["facades"] = [
        [
            "id": "v14-north-road-frontage",
            "direction": "north",
            "edgeWorld": [[-28, -28], [28, -28]],
            "materialID": "v14-warm-masonry",
            "hasEntrance": true,
            "windowBays": [],
            "windowRhythms": [],
        ],
    ]
    scene["entrance"] = [
        "facadeID": "v14-north-road-frontage",
        "baseWorld": [27, 12],
        "width": 5,
        "height": 8,
        "depth": 1.6,
        "doorMaterialID": "v14-warm-glazing",
        "surroundMaterialID": "v14-concrete-trim",
        "stepCount": 1,
        "stepRun": 1,
        "canopyDepth": 2,
        "hingeSide": "right",
        "pavilionWidth": 14,
        "pavilionDepth": 18,
        "pavilionHeight": 10,
        "pavilionRoofHeight": 2,
        "pavilionMaterialID": "v14-warm-masonry",
        "porchWidth": 7,
        "porchColumnWidth": 1,
        "porchLateralOffset": 0,
        "style": "human-scale-control-return",
    ]
    return scene
}

private func geometryHash(_ parts: [Part]) throws -> String {
    try sha256(
        stableJSON(
            parts.map {
                [
                    "id": $0.id,
                    "role": $0.role,
                    "materialID": $0.materialID,
                    "positionWorld": [$0.center.x, $0.center.y, $0.center.z],
                    "dimensions": [$0.size.x, $0.size.y, $0.size.z],
                    "shape": $0.shape.rawValue,
                    "radialSegments": $0.radialSegments,
                ] as [String: Any]
            }
        )
    )
}

private func fileInventory(_ root: URL) throws -> [[String: String]] {
    let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey]
    )
    var values: [[String: String]] = []
    while let url = enumerator?.nextObject() as? URL {
        let valuesForURL = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard valuesForURL.isRegularFile == true else { continue }
        values.append([
            "path": url.path.replacingOccurrences(
                of: root.path + "/",
                with: ""
            ),
            "sha256": try sha256(url),
        ])
    }
    return values.sorted { $0["path"]! < $1["path"]! }
}

private func run(
    repositoryRoot: URL,
    artifactRoot: URL,
    evidenceRoot: URL
) throws {
    let templateRoot = repositoryRoot.appendingPathComponent(
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v10-north-prepixel"
    )
    let sceneTemplateURL = templateRoot.appendingPathComponent(
        "scenes/industrial_l04/variant-0/n/scene.json"
    )
    let materialTemplateURL = templateRoot.appendingPathComponent(
        "materials/industrial-l04-turbine-v10-north-prepixel.json"
    )
    let sceneTemplate = try JSONSerialization.jsonObject(
        with: Data(contentsOf: sceneTemplateURL)
    ) as! [String: Any]
    let materialTemplate = try JSONSerialization.jsonObject(
        with: Data(contentsOf: materialTemplateURL)
    ) as! [String: Any]
    let parts = authoredParts()
    let library = materialLibrary(from: materialTemplate)
    let materialData = try stableJSON(library)
    let materialSHA = sha256(materialData)
    let scene = sceneDescriptor(
        from: sceneTemplate,
        parts: parts,
        materialSHA: materialSHA
    )
    let sceneData = try stableJSON(scene)
    let sceneSHA = sha256(sceneData)
    let geometrySHA = try geometryHash(parts)
    let materialURL = artifactRoot.appendingPathComponent(
        "materials/\(materialFile)"
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

    // Decode the persisted artifacts before rendering any proof.
    _ = try JSONDecoder().decode(
        MaterialLibraryDescriptor.self,
        from: Data(contentsOf: materialURL)
    )
    _ = try JSONDecoder().decode(
        SceneDescriptor.self,
        from: Data(contentsOf: sceneURL)
    )
    let persistedScene = try JSONSerialization.jsonObject(
        with: Data(contentsOf: sceneURL)
    ) as! [String: Any]
    let projection = try camera(from: persistedScene)
    let review = evidenceRoot.appendingPathComponent("review")
    try FileManager.default.createDirectory(
        at: review,
        withIntermediateDirectories: true
    )
    let sourceColor = try render(
        parts: parts,
        camera: projection,
        size: sourceSize,
        mode: .color
    )
    let sourceGray = try render(
        parts: parts,
        camera: projection,
        size: sourceSize,
        mode: .grayscale
    )
    let nativeColor = try render(
        parts: parts,
        camera: projection,
        size: nativeSize,
        mode: .color
    )
    let nativeGray = try render(
        parts: parts,
        camera: projection,
        size: nativeSize,
        mode: .grayscale
    )
    let compactColor = try render(
        parts: parts,
        camera: projection,
        size: compactSize,
        mode: .color
    )
    let compactGray = try render(
        parts: parts,
        camera: projection,
        size: compactSize,
        mode: .grayscale
    )
    let semantic = try render(
        parts: parts,
        camera: projection,
        size: compactSize,
        mode: .semantic
    )
    let hero = try render(
        parts: parts,
        camera: projection,
        size: compactSize,
        mode: .heroMask
    )
    let silhouette = try render(
        parts: parts,
        camera: projection,
        size: compactSize,
        mode: .silhouette
    )
    try writePNG(sourceColor, to: review.appendingPathComponent("SOURCE-COLOR.png"))
    try writePNG(sourceGray, to: review.appendingPathComponent("SOURCE-GRAYSCALE.png"))
    try writePNG(nativeColor, to: review.appendingPathComponent("NATIVE-2X-COLOR.png"))
    try writePNG(nativeGray, to: review.appendingPathComponent("NATIVE-2X-GRAYSCALE.png"))
    try writePNG(compactColor, to: review.appendingPathComponent("EXACT-192X128-COLOR.png"))
    try writePNG(compactGray, to: review.appendingPathComponent("EXACT-192X128-GRAYSCALE.png"))
    try writePNG(semantic, to: review.appendingPathComponent("SEMANTIC-SUPPORTING.png"))
    try writePNG(hero, to: review.appendingPathComponent("HERO-SUPPORTING-MASK.png"))
    try writePNG(silhouette, to: review.appendingPathComponent("ALL-BUILDING-SILHOUETTE.png"))
    try writePNG(
        try registrationPanel(image: sourceColor, camera: projection),
        to: review.appendingPathComponent("REGISTRATION-CONTACT.png")
    )

    let v12 = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/crucible-gantry-v12-north-prepixel-rejection/attempts/layout-02/review/EXACT-192X128-COLOR.png"
    )
    let v13 = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/crucible-gantry-v13-north-prepixel-rejection/attempts/layout-02/evidence/review/EXACT-192X128-COLOR.png"
    )
    let acceptedL3 = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-raw-review-v01/diagnostics/raw-repeat/north/run-a/raw.png"
    )
    try writePNG(
        try tiled(
            [try loadImage(v12), try loadImage(v13), compactColor],
            cell: compactSize
        ),
        to: review.appendingPathComponent("UNLABELLED-V12-V13-V14-COLOR.png")
    )
    try writePNG(
        try tiled([try loadImage(acceptedL3), compactColor], cell: compactSize),
        to: review.appendingPathComponent("UNLABELLED-ACCEPTED-L3-V14-COLOR.png")
    )

    let materialIDs = Set(palette.keys)
    let unresolved = parts.map(\.materialID).filter { !materialIDs.contains($0) }
    guard unresolved.isEmpty else {
        throw V14Error.failed("unresolved materials \(unresolved)")
    }
    guard parts.filter({ $0.role.hasPrefix("freight") }).count >= 12 else {
        throw V14Error.failed("three grouped freight beats missing")
    }
    guard parts.contains(where: { $0.role == "staffEntry" }) else {
        throw V14Error.failed("staff entry missing")
    }
    guard parts.filter({ $0.role == "gantryBeam" }).count == 2 else {
        throw V14Error.failed("double-girder crane missing")
    }
    guard parts.filter({ $0.role == "crucible" }).count >= 3 else {
        throw V14Error.failed("shaped crucible hierarchy missing")
    }

    let decisions = """
    # Industrial L4 North v14 board-led design decisions

    Disposition: `PENDING_INDEPENDENT_REVIEW`

    The published board is a non-shipping visual target only. No board pixel,
    perspective, footprint, camera, shadow, or directional composition enters
    the descriptor or panels.

    - The warm masonry turbine hall forms one grounded west/rear anchor rather
      than the v13 compact box.
    - Two deep girders, three transverse ties, a trolley and lift rail make the
      bridge crane a functional lifting assembly over an open court.
    - Seven concentric octagonal volumes form the furnace base, taper,
      shoulder, upper vessel, neck, rim and hot mouth.
    - Three lintel/recess/post freight beats share one road-connected apron.
    - The control annex and staff door remain human-scale and subordinate.
    - The boiler/stack group is offset and dispensable to recognition.
    - Large material groups are authored numerically; ImageGen was not used.

    Human reviewers own premium identity. Semantic and silhouette masks are
    supporting diagnostics only and cannot rescue weak literal color or
    grayscale pixels.

    `sourceAuthority=false`

    `productionSelected=false`
    """
    try decisions.data(using: .utf8)!.write(
        to: evidenceRoot.appendingPathComponent("DESIGN-DECISIONS.md")
    )
    let validation: [String: Any] = [
        "taskID": "PLAY-027",
        "revision": revision,
        "geometryID": geometryID,
        "descriptorSHA256": sceneSHA,
        "materialSHA256": materialSHA,
        "geometrySHA256": geometrySHA,
        "componentCount": parts.count,
        "doubleGirderCount": 2,
        "crucibleTierCount": 7,
        "freightBeatCount": 3,
        "footprintWorld": [[-28, -28], [28, -28], [28, 28], [-28, 28]],
        "groundPivotSource": [768, 896],
        "frontageSocketSource": [896, 704],
        "frontageWorldZ": -28,
        "cameraProjection": "orthographic-2-to-1",
        "sourceAuthority": false,
        "productionSelected": false,
        "rawProcessCount": 0,
        "sceneKitProcessCount": 0,
        "metalProcessCount": 0,
        "normalizerProcessCount": 0,
        "generatedAt": fixedTimestamp,
        "artifactInventory": try fileInventory(artifactRoot),
    ]
    try stableJSON(validation).write(
        to: evidenceRoot.appendingPathComponent("PREPIXEL-VALIDATION.json")
    )
}

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        CommandLine.arguments.indices.contains(index + 1)
    else {
        throw V14Error.failed("missing \(name)")
    }
    return CommandLine.arguments[index + 1]
}

@main
private enum BuildIndustrialL4CrucibleGantryV14NorthPrepixel {
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
            print("PASS v14 board-led pre-pixel model emitted")
        } catch {
            fputs("FAIL \(error)\n", stderr)
            exit(1)
        }
    }
}
