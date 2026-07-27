import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ClayResetError: Error, CustomStringConvertible {
    case usage
    case failed(String)

    var description: String {
        switch self {
        case .usage:
            return "usage: BuildIndustrialL4TurbineClayReset --output-root <absent-path>"
        case let .failed(message):
            return message
        }
    }
}

struct V3 {
    let x: Double
    let y: Double
    let z: Double
}

struct Box {
    let id: String
    let role: String
    let center: V3
    let size: V3
    let stack: Bool
}

struct DirectionPlan {
    let direction: String
    let geometryID: String
    let boxes: [Box]
    let freightCenters: [Double]
    let staffCenter: Double
}

struct P2 {
    let x: Double
    let y: Double
}

struct Polygon {
    let points: [P2]
    let depth: Double
    let shade: CGFloat
}

struct Raster {
    let image: CGImage
    let silhouetteBounds: CGRect
    let hallBounds: CGRect
    let stackPixelCount: Int
    let silhouettePixelCount: Int
    let freightWidths: [Double]
    let peakCount: Int
}

let sourceSize = CGSize(width: 1536, height: 1024)
let compactSize = CGSize(width: 192, height: 128)
let pixelsPerWorld = 6.47
let sourceAuthority = false
let productionSelected = false

func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

func jsonData(_ value: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw ClayResetError.failed("output exists: \(url.path)")
    }
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw ClayResetError.failed("cannot create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw ClayResetError.failed("cannot finalize PNG: \(url.path)")
    }
}

func writeJSON(_ value: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw ClayResetError.failed("output exists: \(url.path)")
    }
    try jsonData(value).write(to: url, options: .atomic)
}

func box(
    _ id: String,
    _ role: String,
    _ x: Double,
    _ y: Double,
    _ z: Double,
    _ width: Double,
    _ height: Double,
    _ depth: Double,
    stack: Bool = false
) -> Box {
    Box(
        id: id,
        role: role,
        center: V3(x: x, y: y, z: z),
        size: V3(x: width, y: height, z: depth),
        stack: stack
    )
}

func plan(_ direction: String) -> DirectionPlan {
    let prefix = "i04-\(direction.lowercased())"
    let hall = box("\(prefix)-turbine-hall", "main-hall", 0, 10, 2, 54, 16, 18)
    let controlX: Double
    let annexX: Double
    let stackX: Double
    let staffX: Double
    switch direction {
    case "N":
        controlX = 18
        annexX = -17
        stackX = -19
        staffX = 19
    case "E":
        controlX = 17
        annexX = -18
        stackX = 19
        staffX = 18
    case "S":
        controlX = -18
        annexX = 17
        stackX = 20
        staffX = -19
    default:
        controlX = -17
        annexX = 18
        stackX = -20
        staffX = -18
    }
    var boxes = [
        box("\(prefix)-foundation", "foundation", 0, 1, 0, 56, 2, 56),
        hall,
        box("\(prefix)-control-wing", "control-wing", controlX, 6, -11, 18, 10, 12),
        box("\(prefix)-assembly-annex", "assembly-annex", annexX, 7, 13, 18, 12, 12),
        box("\(prefix)-rear-stack", "rear-stack", stackX, 27, 13, 3, 30, 3, stack: true),
        box("\(prefix)-freight-canopy", "freight-canopy", 0, 14.5, -10.5, 42, 3, 5),
        box("\(prefix)-front-apron", "apron", 0, 0.7, -21, 50, 1.4, 14),
    ]
    for index in 0..<4 {
        let x = -20.25 + Double(index) * 13.5
        boxes.append(
            box(
                "\(prefix)-sawtooth-\(index + 1)",
                "roof-peak",
                x,
                20,
                2,
                11,
                4,
                17
            )
        )
    }
    return DirectionPlan(
        direction: direction,
        geometryID: "industrial-l04-turbine-v05-\(direction.lowercased())",
        boxes: boxes,
        freightCenters: [-14, 0, 14],
        staffCenter: staffX
    )
}

func projected(_ point: V3, in size: CGSize) -> P2 {
    P2(
        x: Double(size.width) * 0.5 + (point.x - point.z) * pixelsPerWorld,
        y: Double(size.height) * 0.69
            - (point.x + point.z) * pixelsPerWorld * 0.36
            - point.y * pixelsPerWorld
    )
}

func vertices(of box: Box) -> [V3] {
    let hx = box.size.x * 0.5
    let hy = box.size.y * 0.5
    let hz = box.size.z * 0.5
    return [
        V3(x: box.center.x - hx, y: box.center.y - hy, z: box.center.z - hz),
        V3(x: box.center.x + hx, y: box.center.y - hy, z: box.center.z - hz),
        V3(x: box.center.x + hx, y: box.center.y + hy, z: box.center.z - hz),
        V3(x: box.center.x - hx, y: box.center.y + hy, z: box.center.z - hz),
        V3(x: box.center.x - hx, y: box.center.y - hy, z: box.center.z + hz),
        V3(x: box.center.x + hx, y: box.center.y - hy, z: box.center.z + hz),
        V3(x: box.center.x + hx, y: box.center.y + hy, z: box.center.z + hz),
        V3(x: box.center.x - hx, y: box.center.y + hy, z: box.center.z + hz),
    ]
}

func polygons(for box: Box, size: CGSize) -> [Polygon] {
    if box.role == "roof-peak" {
        let hx = box.size.x * 0.5
        let hy = box.size.y * 0.5
        let hz = box.size.z * 0.5
        let y0 = box.center.y - hy
        let y1 = box.center.y + hy
        let front = box.center.z - hz
        let back = box.center.z + hz
        let worldFaces: [([V3], CGFloat)] = [
            ([
                V3(x: box.center.x - hx, y: y0, z: front),
                V3(x: box.center.x, y: y1, z: front),
                V3(x: box.center.x + hx, y: y0, z: front),
            ], 0.62),
            ([
                V3(x: box.center.x, y: y1, z: front),
                V3(x: box.center.x, y: y1, z: back),
                V3(x: box.center.x + hx, y: y0, z: back),
                V3(x: box.center.x + hx, y: y0, z: front),
            ], 0.76),
            ([
                V3(x: box.center.x - hx, y: y0, z: front),
                V3(x: box.center.x - hx, y: y0, z: back),
                V3(x: box.center.x, y: y1, z: back),
                V3(x: box.center.x, y: y1, z: front),
            ], 0.70),
        ]
        return worldFaces.map { world, shade in
            Polygon(
                points: world.map { projected($0, in: size) },
                depth: world.map { $0.x + $0.z }.reduce(0, +) / Double(world.count),
                shade: shade
            )
        }
    }
    let v = vertices(of: box)
    let faces: [([Int], CGFloat)] = [
        ([4, 5, 6, 7], 0.54),
        ([1, 5, 6, 2], 0.66),
        ([3, 2, 6, 7], 0.78),
    ]
    return faces.map { indices, shade in
        let world = indices.map { v[$0] }
        return Polygon(
            points: world.map { projected($0, in: size) },
            depth: world.map { $0.x + $0.z }.reduce(0, +) / 4,
            shade: shade
        )
    }
}

func context(width: Int, height: Int) throws -> CGContext {
    guard let value = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw ClayResetError.failed("cannot create bitmap context")
    }
    value.translateBy(x: 0, y: CGFloat(height))
    value.scaleBy(x: 1, y: -1)
    value.setShouldAntialias(false)
    return value
}

func path(_ points: [P2]) -> CGPath {
    let value = CGMutablePath()
    value.move(to: CGPoint(x: points[0].x, y: points[0].y))
    for point in points.dropFirst() {
        value.addLine(to: CGPoint(x: point.x, y: point.y))
    }
    value.closeSubpath()
    return value
}

func pixelStats(_ image: CGImage) throws -> (CGRect, Int) {
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard let ctx = CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw ClayResetError.failed("cannot decode image")
    }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    var count = 0
    for y in 0..<height {
        for x in 0..<width where bytes[(y * width + x) * 4 + 3] > 0 {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
            count += 1
        }
    }
    guard count > 0 else { throw ClayResetError.failed("empty clay raster") }
    return (
        CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1),
        count
    )
}

func render(_ plan: DirectionPlan, size: CGSize) throws -> Raster {
    let width = Int(size.width)
    let height = Int(size.height)
    let ctx = try context(width: width, height: height)
    let all = plan.boxes.flatMap { item in
        polygons(for: item, size: size).map { (item, $0) }
    }.sorted { $0.1.depth > $1.1.depth }
    for (item, polygon) in all {
        let base: CGFloat = item.role == "control-wing" ? 0.63 : polygon.shade
        ctx.setFillColor(CGColor(gray: base, alpha: 1))
        ctx.addPath(path(polygon.points))
        ctx.fillPath()
        ctx.setStrokeColor(CGColor(gray: 0.14, alpha: 1))
        ctx.setLineWidth(1)
        ctx.addPath(path(polygon.points))
        ctx.strokePath()
    }

    var freightWidths: [Double] = []
    for center in plan.freightCenters {
        let bottomLeft = projected(V3(x: center - 5.8, y: 2, z: -9.1), in: size)
        let bottomRight = projected(V3(x: center + 5.8, y: 2, z: -9.1), in: size)
        let topRight = projected(V3(x: center + 5.8, y: 13.5, z: -9.1), in: size)
        let topLeft = projected(V3(x: center - 5.8, y: 13.5, z: -9.1), in: size)
        let points = [bottomLeft, bottomRight, topRight, topLeft]
        ctx.setFillColor(CGColor(gray: 0.08, alpha: 1))
        ctx.addPath(path(points))
        ctx.fillPath()
        freightWidths.append(abs(bottomRight.x - bottomLeft.x) * Double(compactSize.width / sourceSize.width))
    }
    let staffLeft = projected(V3(x: plan.staffCenter - 2, y: 2, z: -17.1), in: size)
    let staffRight = projected(V3(x: plan.staffCenter + 2, y: 2, z: -17.1), in: size)
    let staffTopRight = projected(V3(x: plan.staffCenter + 2, y: 10, z: -17.1), in: size)
    let staffTopLeft = projected(V3(x: plan.staffCenter - 2, y: 10, z: -17.1), in: size)
    ctx.setFillColor(CGColor(gray: 0.24, alpha: 1))
    ctx.addPath(path([staffLeft, staffRight, staffTopRight, staffTopLeft]))
    ctx.fillPath()

    guard let image = ctx.makeImage() else {
        throw ClayResetError.failed("cannot create clay image")
    }
    let stats = try pixelStats(image)
    let hallPoints = vertices(of: plan.boxes.first { $0.role == "main-hall" }!)
        .map { projected($0, in: size) }
    let hallMinX = hallPoints.map(\.x).min()!
    let hallMaxX = hallPoints.map(\.x).max()!
    let hallMinY = hallPoints.map(\.y).min()!
    let hallMaxY = hallPoints.map(\.y).max()!
    let hallBounds = CGRect(
        x: hallMinX,
        y: hallMinY,
        width: hallMaxX - hallMinX,
        height: hallMaxY - hallMinY
    )
    let stack = plan.boxes.first { $0.stack }!
    let stackPoints = vertices(of: stack).map { projected($0, in: size) }
    let sx0 = Int(stackPoints.map(\.x).min()!.rounded(.down))
    let sx1 = Int(stackPoints.map(\.x).max()!.rounded(.up))
    let sy0 = Int(stackPoints.map(\.y).min()!.rounded(.down))
    let sy1 = Int(stackPoints.map(\.y).max()!.rounded(.up))
    let stackPixels = max(0, sx1 - sx0) * max(0, sy1 - sy0)
    return Raster(
        image: image,
        silhouetteBounds: stats.0,
        hallBounds: hallBounds,
        stackPixelCount: stackPixels,
        silhouettePixelCount: stats.1,
        freightWidths: freightWidths,
        peakCount: plan.boxes.filter { $0.role == "roof-peak" }.count
    )
}

func resize(_ image: CGImage, to size: CGSize) throws -> CGImage {
    let ctx = try context(width: Int(size.width), height: Int(size.height))
    ctx.interpolationQuality = .none
    ctx.draw(image, in: CGRect(origin: .zero, size: size))
    guard let output = ctx.makeImage() else {
        throw ClayResetError.failed("cannot resize image")
    }
    return output
}

func sheet(_ images: [CGImage], cell: CGSize) throws -> CGImage {
    let ctx = try context(width: Int(cell.width * 2), height: Int(cell.height * 2))
    for (index, image) in images.enumerated() {
        let x = CGFloat(index % 2) * cell.width
        let y = CGFloat(index / 2) * cell.height
        ctx.draw(image, in: CGRect(x: x, y: y, width: cell.width, height: cell.height))
    }
    guard let output = ctx.makeImage() else {
        throw ClayResetError.failed("cannot create sheet")
    }
    return output
}

func run() throws {
    let arguments = CommandLine.arguments
    guard let index = arguments.firstIndex(of: "--output-root"), index + 1 < arguments.count else {
        throw ClayResetError.usage
    }
    let root = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    guard root.path.hasPrefix("/tmp/") || root.path.contains("/docs/production/evidence/PLAY-027/") else {
        throw ClayResetError.failed("output root must be task-owned")
    }
    guard !FileManager.default.fileExists(atPath: root.path) else {
        throw ClayResetError.failed("output root must be absent")
    }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let plans = ["N", "E", "S", "W"].map(plan)
    let rasters = try plans.map { try render($0, size: sourceSize) }
    let sourceImages = try rasters.map { try resize($0.image, to: CGSize(width: 768, height: 512)) }
    let compactImages = try rasters.map { try resize($0.image, to: compactSize) }
    let sourceSheet = try sheet(sourceImages, cell: CGSize(width: 768, height: 512))
    let compactSheet = try sheet(compactImages, cell: compactSize)

    let sourceURL = root.appendingPathComponent("TURBINE-V04-CLAY-NESW-EQUAL-SCALE.png")
    let compactURL = root.appendingPathComponent("TURBINE-V04-CLAY-NESW-192x128.png")
    try writePNG(sourceSheet, to: sourceURL)
    try writePNG(compactSheet, to: compactURL)

    var directionMetrics: [[String: Any]] = []
    var failures: [String] = []
    for (index, plan) in plans.enumerated() {
        let raster = rasters[index]
        let hallHeight = plan.boxes.first { $0.role == "main-hall" }!.size.y
        let roofHeight = plan.boxes.first { $0.role == "roof-peak" }!.size.y
        let hallVisibleHeight = (hallHeight + roofHeight) * pixelsPerWorld
        let hallRatio = Double(raster.hallBounds.width) / hallVisibleHeight
        let nonStackTop = plan.boxes.filter { !$0.stack }
            .map { $0.center.y + $0.size.y * 0.5 }.max()!
        let controlHeight = plan.boxes.first { $0.role == "control-wing" }!.size.y
        let stackShare = Double(raster.stackPixelCount) / Double(raster.silhouettePixelCount)
        let freightPass = raster.freightWidths.allSatisfy { $0 >= 8 }
        if hallRatio < 2.4 { failures.append("\(plan.direction): hall ratio \(hallRatio)") }
        if nonStackTop > 42 { failures.append("\(plan.direction): non-stack top \(nonStackTop)") }
        if stackShare > 0.08 { failures.append("\(plan.direction): stack share \(stackShare)") }
        if raster.peakCount < 4 { failures.append("\(plan.direction): roof peaks \(raster.peakCount)") }
        if controlHeight / hallHeight > 0.55 {
            failures.append("\(plan.direction): control/hall \(controlHeight / hallHeight)")
        }
        if !freightPass { failures.append("\(plan.direction): freight width \(raster.freightWidths)") }
        directionMetrics.append([
            "direction": plan.direction,
            "geometryID": plan.geometryID,
            "hallProjectedWidthPixels": raster.hallBounds.width,
            "hallVisibleHeightPixels": hallVisibleHeight,
            "hallIsometricBoundingBoxHeightPixels": raster.hallBounds.height,
            "hallWidthToVisibleHeight": hallRatio,
            "nonStackMaximumWorldY": nonStackTop,
            "stackSilhouetteAreaShareUpperBound": stackShare,
            "roofPeakCount": raster.peakCount,
            "controlWingToHallHeight": controlHeight / hallHeight,
            "freightOpeningCompactWidthsPixels": raster.freightWidths,
            "freightOpeningPass": freightPass,
            "silhouetteBoundsSource": [
                raster.silhouetteBounds.minX,
                raster.silhouetteBounds.minY,
                raster.silhouetteBounds.width,
                raster.silhouetteBounds.height,
            ],
        ])
    }

    let report: [String: Any] = [
        "taskID": "PLAY-027",
        "artifact": "Industrial L4 Turbine Works v05 clay-only repair",
        "authority": "play027-turbine-v05-one-surgical-replay",
        "sourceAuthority": sourceAuthority,
        "productionSelected": productionSelected,
        "sceneKitProcesses": 0,
        "metalProcesses": 0,
        "imageGenCalls": 0,
        "normalizerProcesses": 0,
        "containsDescriptors": false,
        "containsMaterials": false,
        "containsPropsOrDetails": false,
        "directions": directionMetrics,
        "hardGateFailures": failures,
        "technicalDisposition": failures.isEmpty ? "PASS_PENDING_VISUAL_REVIEW" : "REJECTED",
        "outputs": [
            sourceURL.lastPathComponent: try sha256(sourceURL),
            compactURL.lastPathComponent: try sha256(compactURL),
        ],
    ]
    try writeJSON(report, to: root.appendingPathComponent("CLAY-METRICS.json"))
    guard failures.isEmpty else {
        throw ClayResetError.failed(failures.joined(separator: "; "))
    }
}

@main
enum Main {
    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }
}
