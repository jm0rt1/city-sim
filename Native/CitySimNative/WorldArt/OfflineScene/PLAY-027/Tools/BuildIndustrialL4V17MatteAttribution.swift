import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private enum MatteDiagnosticError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l4-v17-matte-attribution --repository-root <path> --output-directory <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct Raster {
    let width: Int
    let height: Int
    let rgba: [UInt8]
    let fileSHA256: String
    let decodedRGBASHA256: String
}

private struct Coordinate: Hashable {
    let x: Int
    let y: Int
}

private struct Bounds: Equatable {
    let minimumX: Int
    let minimumY: Int
    let maximumX: Int
    let maximumY: Int

    var array: [Int] {
        [minimumX, minimumY, maximumX, maximumY]
    }
}

private struct Attribution {
    let silhouette: Bool
    let shadow: Bool

    var label: String {
        if silhouette && shadow { return "overlap" }
        if silhouette { return "silhouette-edge" }
        if shadow { return "contact-shadow-edge" }
        return "unowned"
    }
}

private let v17RawRelativePath =
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    + "crucible-gantry-v17-north-raw-probe/diagnostics/north/run-a/raw.png"
private let v16RawRelativePath =
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    + "crucible-gantry-v16-north-raw-probe/diagnostics/north/run-a/raw.png"
private let descriptorRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v17-north-prepixel/artifact/"
    + "scenes/industrial_l04/variant-0/n/scene.json"
private let materialRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v17-north-prepixel/materials/"
    + "industrial-l04-crucible-gantry-v14-north-prepixel.json"
private let toolRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
    + "BuildIndustrialL4V17MatteAttribution.swift"

private let expectedV17FileSHA =
    "9aea278d4fe7640a4dd126c4393fd284f2849f80168b5e62d6e8dbe2cf75c5d7"
private let expectedV17DecodedSHA =
    "0d9ca24f63de0f17c72cd36c38b742bd6fe6aca8aaee60c987a541af952e620f"
private let expectedV16FileSHA =
    "25635578bc30e6a9de895161a6f33855866d456aa8a73eb307aff86793b55b03"
private let expectedV16DecodedSHA =
    "a20e26cf02afc4ba7a316251077fd844f5e2c7243d077259a1833d4fcf92499b"
private let expectedDescriptorSHA =
    "6cb190ea388746c620945ff401a03817df0ff1f92797a18fff8e86b00b0cd94a"
private let expectedMaterialSHA =
    "147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202"
private let expectedCoordinateSHA =
    "824601712493f3e8b402b69055267a10bfdd8d80254e4d04b8c91f58d6df4109"

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        index + 1 < CommandLine.arguments.count
    else {
        throw MatteDiagnosticError.arguments
    }
    return CommandLine.arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func digest(_ url: URL) throws -> String {
    digest(try Data(contentsOf: url))
}

private func decode(_ url: URL) throws -> Raster {
    let fileData = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        )
    else {
        throw MatteDiagnosticError.invalid("could not decode \(url.path)")
    }
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try rgba.withUnsafeMutableBytes { storage in
        guard let context = CGContext(
            data: storage.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw MatteDiagnosticError.invalid("could not allocate RGBA decoder")
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return Raster(
        width: image.width,
        height: image.height,
        rgba: rgba,
        fileSHA256: digest(fileData),
        decodedRGBASHA256: digest(Data(rgba))
    )
}

private func jsonObject(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw MatteDiagnosticError.invalid("expected JSON object at \(url.path)")
    }
    return object
}

private func isExactChroma(_ rgba: [UInt8], _ offset: Int) -> Bool {
    rgba[offset] == 255
        && rgba[offset + 1] == 0
        && rgba[offset + 2] == 255
        && rgba[offset + 3] > 0
}

private func isNearChroma(_ rgba: [UInt8], _ offset: Int) -> Bool {
    guard !isExactChroma(rgba, offset), rgba[offset + 3] > 0 else {
        return false
    }
    return rgba[offset] >= 240
        && rgba[offset + 1] <= 16
        && rgba[offset + 2] >= 240
}

// This is byte-for-byte the established NormalizeOfflineSource matte predicate.
private func isOfflineMatte(_ rgba: [UInt8], _ offset: Int) -> Bool {
    let red = Int(rgba[offset])
    let green = Int(rgba[offset + 1])
    let blue = Int(rgba[offset + 2])
    let alpha = Int(rgba[offset + 3])
    return alpha > 0
        && red >= 180
        && blue >= 150
        && green <= 110
        && red + blue >= green * 4
}

private func nearCoordinates(_ raster: Raster) -> [Coordinate] {
    var result: [Coordinate] = []
    for y in 0..<raster.height {
        for x in 0..<raster.width {
            let offset = (y * raster.width + x) * 4
            if isNearChroma(raster.rgba, offset) {
                result.append(Coordinate(x: x, y: y))
            }
        }
    }
    return result
}

private func coordinateHash(
    _ coordinates: [Coordinate]
) throws -> (name: String, sha256: String) {
    let rowMajor = coordinates.sorted {
        $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
    }
    let xMajor = coordinates.sorted {
        $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x
    }
    var candidates: [(String, Data)] = []
    func addText(_ name: String, _ values: [Coordinate], _ format: (Coordinate) -> String) {
        let lines = values.map(format)
        candidates.append(("\(name)-newline", Data(lines.joined(separator: "\n").utf8)))
        candidates.append(("\(name)-newline-terminated", Data((lines.joined(separator: "\n") + "\n").utf8)))
        candidates.append(("\(name)-semicolon", Data(lines.joined(separator: ";").utf8)))
    }
    for (name, values) in [("row-major", rowMajor), ("x-major", xMajor)] {
        addText(name + "-csv", values) { "\($0.x),\($0.y)" }
        addText(name + "-colon", values) { "\($0.x):\($0.y)" }
        addText(name + "-space", values) { "\($0.x) \($0.y)" }
        addText(name + "-brackets", values) { "[\($0.x),\($0.y)]" }
        let arrays = values.map { [$0.x, $0.y] }
        candidates.append((
            name + "-json-compact",
            try JSONSerialization.data(withJSONObject: arrays)
        ))
        candidates.append((
            name + "-json-pretty",
            try JSONSerialization.data(withJSONObject: arrays, options: [.prettyPrinted])
        ))
        let objects = values.map { ["x": $0.x, "y": $0.y] }
        candidates.append((
            name + "-objects-json",
            try JSONSerialization.data(withJSONObject: objects, options: [.sortedKeys])
        ))
        for byteOrder in ["little", "big"] {
            for bitWidth in [32, 64] {
                var data = Data()
                for value in values {
                    for integer in [value.x, value.y] {
                        if bitWidth == 32 {
                            var encoded = byteOrder == "little"
                                ? UInt32(integer).littleEndian
                                : UInt32(integer).bigEndian
                            withUnsafeBytes(of: &encoded) { data.append(contentsOf: $0) }
                        } else {
                            var encoded = byteOrder == "little"
                                ? UInt64(integer).littleEndian
                                : UInt64(integer).bigEndian
                            withUnsafeBytes(of: &encoded) { data.append(contentsOf: $0) }
                        }
                    }
                }
                candidates.append(("\(name)-binary-\(bitWidth)-\(byteOrder)", data))
            }
        }
    }
    guard let match = candidates.first(where: { digest($0.1) == expectedCoordinateSHA }) else {
        let observed = candidates.map { "\($0.0)=\(digest($0.1))" }.joined(separator: ",")
        throw MatteDiagnosticError.invalid(
            "coordinate serialization did not reproduce authority SHA; candidates=\(observed)"
        )
    }
    return (match.0, digest(match.1))
}

private func pointInPolygon(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
    var inside = false
    var previous = polygon.count - 1
    for current in 0..<polygon.count {
        let a = polygon[current]
        let b = polygon[previous]
        let crosses = (a.y > point.y) != (b.y > point.y)
        if crosses {
            let intersectionX =
                (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x
            if point.x < intersectionX {
                inside.toggle()
            }
        }
        previous = current
    }
    return inside
}

private func distanceToSegment(
    point: CGPoint,
    start: CGPoint,
    end: CGPoint
) -> CGFloat {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let lengthSquared = dx * dx + dy * dy
    guard lengthSquared > 0 else {
        return hypot(point.x - start.x, point.y - start.y)
    }
    let projection = max(
        0,
        min(
            1,
            ((point.x - start.x) * dx + (point.y - start.y) * dy)
                / lengthSquared
        )
    )
    let closest = CGPoint(
        x: start.x + projection * dx,
        y: start.y + projection * dy
    )
    return hypot(point.x - closest.x, point.y - closest.y)
}

private func withinShadowSupport(
    _ coordinate: Coordinate,
    polygon: [CGPoint]
) -> Bool {
    let point = CGPoint(
        x: CGFloat(coordinate.x) + 0.5,
        y: CGFloat(coordinate.y) + 0.5
    )
    if pointInPolygon(point, polygon: polygon) {
        return true
    }
    for index in 0..<polygon.count {
        let next = (index + 1) % polygon.count
        if distanceToSegment(
            point: point,
            start: polygon[index],
            end: polygon[next]
        ) <= 1.5 {
            return true
        }
    }
    return false
}

private func isShadowOnlyFamily(_ rgba: [UInt8], _ offset: Int) -> Bool {
    let red = Int(rgba[offset])
    let green = Int(rgba[offset + 1])
    let blue = Int(rgba[offset + 2])
    return rgba[offset + 3] > 0
        && red >= 64
        && blue >= 64
        && green <= 32
        && abs(red - blue) <= 16
}

private func nearGeometrySupport(
    _ coordinate: Coordinate,
    raster: Raster
) -> Bool {
    for radius in 1...3 {
        for y in max(0, coordinate.y - radius)...min(raster.height - 1, coordinate.y + radius) {
            for x in max(0, coordinate.x - radius)...min(raster.width - 1, coordinate.x + radius) {
                guard max(abs(x - coordinate.x), abs(y - coordinate.y)) == radius else {
                    continue
                }
                let offset = (y * raster.width + x) * 4
                if !isOfflineMatte(raster.rgba, offset)
                    && !isShadowOnlyFamily(raster.rgba, offset)
                {
                    return true
                }
            }
        }
    }
    return false
}

private func borderConnectedMatteMask(
    _ raster: Raster
) -> [Bool] {
    let count = raster.width * raster.height
    var visited = [Bool](repeating: false, count: count)
    var matte = [Bool](repeating: false, count: count)
    var queue: [Int] = []
    queue.reserveCapacity(count / 2)
    func enqueue(_ x: Int, _ y: Int) {
        let index = y * raster.width + x
        guard !visited[index] else { return }
        visited[index] = true
        queue.append(index)
    }
    for x in 0..<raster.width {
        enqueue(x, 0)
        enqueue(x, raster.height - 1)
    }
    for y in 0..<raster.height {
        enqueue(0, y)
        enqueue(raster.width - 1, y)
    }
    var cursor = 0
    while cursor < queue.count {
        let index = queue[cursor]
        cursor += 1
        let offset = index * 4
        guard isOfflineMatte(raster.rgba, offset) else { continue }
        matte[index] = true
        let x = index % raster.width
        let y = index / raster.width
        if x > 0 { enqueue(x - 1, y) }
        if x + 1 < raster.width { enqueue(x + 1, y) }
        if y > 0 { enqueue(x, y - 1) }
        if y + 1 < raster.height { enqueue(x, y + 1) }
    }
    return matte
}

// This retains the exact established removeOfflineMatte order and arithmetic.
private func diagnosticMatteRemoval(
    _ raster: Raster,
    matteMask: [Bool]
) -> (
    rgba: [UInt8],
    changed: [Bool],
    retainedDespillMask: [Bool],
    retainedDespillCount: Int
) {
    var output = raster.rgba
    var changed = [Bool](repeating: false, count: raster.width * raster.height)
    var retainedDespillMask = [Bool](
        repeating: false,
        count: raster.width * raster.height
    )
    for index in 0..<matteMask.count where matteMask[index] {
        let offset = index * 4
        output[offset] = 0
        output[offset + 1] = 0
        output[offset + 2] = 0
        output[offset + 3] = 0
        changed[index] = true
    }
    var retainedDespillCount = 0
    for index in 0..<(raster.width * raster.height) {
        let offset = index * 4
        if output[offset + 3] == 0 {
            output[offset] = 0
            output[offset + 1] = 0
            output[offset + 2] = 0
            continue
        }
        let red = Int(output[offset])
        let green = Int(output[offset + 1])
        let blue = Int(output[offset + 2])
        if
            Double(red) > Double(green) * 1.35,
            Double(blue) > Double(green) * 1.25
        {
            let spill = min(red, blue) - green
            let newRed = UInt8(max(green, red - spill))
            let newBlue = UInt8(max(green, blue - spill))
            if newRed != output[offset] || newBlue != output[offset + 2] {
                output[offset] = newRed
                output[offset + 2] = newBlue
                changed[index] = true
                retainedDespillMask[index] = true
                retainedDespillCount += 1
            }
        }
    }
    return (output, changed, retainedDespillMask, retainedDespillCount)
}

private func touchesMask(
    index: Int,
    mask: [Bool],
    width: Int,
    height: Int,
    radius: Int
) -> Bool {
    let centerX = index % width
    let centerY = index / width
    for y in max(0, centerY - radius)...min(height - 1, centerY + radius) {
        for x in max(0, centerX - radius)...min(width - 1, centerX + radius) {
            if mask[y * width + x] {
                return true
            }
        }
    }
    return false
}

private func alphaBounds(
    _ rgba: [UInt8],
    width: Int,
    height: Int
) -> Bounds? {
    var minimumX = width
    var minimumY = height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<height {
        for x in 0..<width {
            let alpha = rgba[(y * width + x) * 4 + 3]
            guard alpha > 0 else { continue }
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    guard maximumX >= minimumX else { return nil }
    return Bounds(
        minimumX: minimumX,
        minimumY: minimumY,
        maximumX: maximumX,
        maximumY: maximumY
    )
}

private func image(
    rgba: [UInt8],
    width: Int,
    height: Int
) throws -> CGImage {
    guard
        let provider = CGDataProvider(data: Data(rgba) as CFData),
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo:
                CGBitmapInfo.byteOrder32Big.union(
                    CGBitmapInfo(
                        rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                    )
                ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    else {
        throw MatteDiagnosticError.invalid("could not create RGBA image")
    }
    return image
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw MatteDiagnosticError.invalid("could not create \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw MatteDiagnosticError.invalid("could not finalize \(url.path)")
    }
}

private func neutralComposite(
    rgba: [UInt8],
    width: Int,
    height: Int,
    grayscale: Bool,
    removeExactOnly: Bool
) throws -> CGImage {
    var prepared = rgba
    for offset in stride(from: 0, to: prepared.count, by: 4) {
        if removeExactOnly && isExactChroma(prepared, offset) {
            prepared[offset] = 0
            prepared[offset + 1] = 0
            prepared[offset + 2] = 0
            prepared[offset + 3] = 0
        }
        if grayscale && prepared[offset + 3] > 0 {
            let luma =
                (54 * Int(prepared[offset])
                    + 183 * Int(prepared[offset + 1])
                    + 19 * Int(prepared[offset + 2])
                    + 128) >> 8
            prepared[offset] = UInt8(luma)
            prepared[offset + 1] = UInt8(luma)
            prepared[offset + 2] = UInt8(luma)
        }
        if prepared[offset + 3] == 0 {
            prepared[offset] = 0
            prepared[offset + 1] = 0
            prepared[offset + 2] = 0
        }
    }
    let source = try image(rgba: prepared, width: width, height: height)
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw MatteDiagnosticError.invalid("could not allocate neutral compositor")
    }
    context.setFillColor(CGColor(red: 0.12, green: 0.13, blue: 0.13, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let output = context.makeImage() else {
        throw MatteDiagnosticError.invalid("could not create neutral composite")
    }
    return output
}

private func scaled(
    _ source: CGImage,
    width: Int,
    height: Int
) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw MatteDiagnosticError.invalid("could not allocate scaler")
    }
    context.interpolationQuality = .high
    context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let result = context.makeImage() else {
        throw MatteDiagnosticError.invalid("could not create scaled image")
    }
    return result
}

private func sideBySide(
    _ left: CGImage,
    _ right: CGImage,
    width: Int,
    height: Int
) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: width * 2,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 2 * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw MatteDiagnosticError.invalid("could not allocate comparison")
    }
    context.draw(left, in: CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(right, in: CGRect(x: width, y: 0, width: width, height: height))
    guard let output = context.makeImage() else {
        throw MatteDiagnosticError.invalid("could not create comparison")
    }
    return output
}

private func writeJSON(_ object: Any, to url: URL) throws {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try data.write(to: url, options: .atomic)
}

@main
private enum BuildIndustrialL4V17MatteAttribution {
    static func main() throws {
        let repositoryRoot = URL(
            fileURLWithPath: try argument("--repository-root")
        ).standardizedFileURL
        let outputDirectory = URL(
            fileURLWithPath: try argument("--output-directory")
        ).standardizedFileURL
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        func repositoryURL(_ relativePath: String) -> URL {
            repositoryRoot.appendingPathComponent(relativePath)
        }

        let v17 = try decode(repositoryURL(v17RawRelativePath))
        let v16 = try decode(repositoryURL(v16RawRelativePath))
        guard
            v17.fileSHA256 == expectedV17FileSHA,
            v17.decodedRGBASHA256 == expectedV17DecodedSHA,
            v16.fileSHA256 == expectedV16FileSHA,
            v16.decodedRGBASHA256 == expectedV16DecodedSHA,
            v17.width == 1536,
            v17.height == 1024,
            v16.width == v17.width,
            v16.height == v17.height
        else {
            throw MatteDiagnosticError.invalid("immutable raw binding drift")
        }
        let descriptorURL = repositoryURL(descriptorRelativePath)
        let materialURL = repositoryURL(materialRelativePath)
        guard
            try digest(descriptorURL) == expectedDescriptorSHA,
            try digest(materialURL) == expectedMaterialSHA
        else {
            throw MatteDiagnosticError.invalid("descriptor or material binding drift")
        }
        let descriptor = try jsonObject(descriptorURL)
        guard
            descriptor["sceneGeometryID"] as? String
                == "industrial-l04-crucible-gantry-v17-north-monumental-portal",
            let registration = descriptor["registration"] as? [String: Any],
            let contactValues = registration["contactPolygonWorld"] as? [[NSNumber]],
            let light = descriptor["light"] as? [String: Any],
            let shadowVector = light["shadowVectorSource"] as? [NSNumber],
            let shadowBlur = light["shadowBlurSourcePixels"] as? NSNumber,
            shadowBlur.doubleValue == 0
        else {
            throw MatteDiagnosticError.invalid("frozen contact/shadow binding drift")
        }

        let v17Coordinates = nearCoordinates(v17)
        let v16Coordinates = nearCoordinates(v16)
        guard
            v17Coordinates.count == 1_807,
            v17Coordinates == v16Coordinates
        else {
            throw MatteDiagnosticError.invalid("near-chroma coordinate set drift")
        }
        let coordinateHashResult = try coordinateHash(v17Coordinates)
        guard coordinateHashResult.sha256 == expectedCoordinateSHA else {
            throw MatteDiagnosticError.invalid("near-chroma coordinate SHA drift")
        }

        var histogram: [String: Int] = [:]
        for coordinate in v17Coordinates {
            let offset = (coordinate.y * v17.width + coordinate.x) * 4
            let key =
                "\(v17.rgba[offset]),\(v17.rgba[offset + 1]),"
                + "\(v17.rgba[offset + 2]),\(v17.rgba[offset + 3])"
            histogram[key, default: 0] += 1
        }
        let expectedHistogram = [
            "255,16,255,255": 1_202,
            "240,16,240,255": 529,
            "255,16,240,255": 70,
            "240,16,255,255": 6,
        ]
        guard histogram == expectedHistogram else {
            throw MatteDiagnosticError.invalid("near-chroma histogram drift")
        }

        let shadowOffset = CGPoint(
            x: shadowVector[0].doubleValue * 28,
            y: shadowVector[1].doubleValue * 28
        )
        let shadowPolygon = contactValues.map {
            CGPoint(
                x: 768 + ($0[0].doubleValue - $0[1].doubleValue) * 256 / 72
                    + shadowOffset.x,
                y: 768 + ($0[0].doubleValue + $0[1].doubleValue) * 128 / 72
                    + shadowOffset.y
            )
        }
        var attributions: [Coordinate: Attribution] = [:]
        var attributionCounts = [
            "silhouette-edge": 0,
            "contact-shadow-edge": 0,
            "overlap": 0,
            "unowned": 0,
        ]
        for coordinate in v17Coordinates {
            let attribution = Attribution(
                silhouette: nearGeometrySupport(coordinate, raster: v17),
                shadow: withinShadowSupport(coordinate, polygon: shadowPolygon)
            )
            attributions[coordinate] = attribution
            attributionCounts[attribution.label, default: 0] += 1
        }
        guard attributionCounts["unowned"] == 0 else {
            throw MatteDiagnosticError.invalid(
                "attribution incomplete: \(attributionCounts)"
            )
        }

        let matteMask = borderConnectedMatteMask(v17)
        let cleaned = diagnosticMatteRemoval(v17, matteMask: matteMask)
        var retainedSupportRGBA = v17.rgba
        for index in 0..<matteMask.count where matteMask[index] {
            let offset = index * 4
            retainedSupportRGBA[offset] = 0
            retainedSupportRGBA[offset + 1] = 0
            retainedSupportRGBA[offset + 2] = 0
            retainedSupportRGBA[offset + 3] = 0
        }
        let changedOutsideClassifiedSpill = cleaned.changed.enumerated().filter {
            $0.element
                && !matteMask[$0.offset]
                && !cleaned.retainedDespillMask[$0.offset]
        }.count
        let retainedDespillOutsideMatteSupport =
            cleaned.retainedDespillMask.enumerated().filter {
                $0.element
                    && !touchesMask(
                        index: $0.offset,
                        mask: matteMask,
                        width: v17.width,
                        height: v17.height,
                        radius: 3
                    )
            }.count
        let retainedDespillOutsideSamples =
            cleaned.retainedDespillMask.enumerated().compactMap {
                item -> String? in
                guard
                    item.element,
                    !touchesMask(
                        index: item.offset,
                        mask: matteMask,
                        width: v17.width,
                        height: v17.height,
                        radius: 3
                    )
                else {
                    return nil
                }
                let offset = item.offset * 4
                return
                    "\(item.offset % v17.width),\(item.offset / v17.width):"
                    + "\(v17.rgba[offset]),\(v17.rgba[offset + 1]),"
                    + "\(v17.rgba[offset + 2]),\(v17.rgba[offset + 3])"
            }
        guard
            changedOutsideClassifiedSpill == 0
        else {
            throw MatteDiagnosticError.invalid(
                "diagnostic cleanup changed pixels outside classified matte/spill support: outsideClassified=\(changedOutsideClassifiedSpill), despillOutsideMatteSupport=\(retainedDespillOutsideMatteSupport), retainedDespill=\(cleaned.retainedDespillCount), samples=\(retainedDespillOutsideSamples)"
            )
        }
        let changedOutsideMatte = cleaned.changed.enumerated().filter {
            $0.element && !matteMask[$0.offset]
        }.count
        let contaminationSet = Set(v17Coordinates)
        let contaminationOutsideBorderMatte = v17Coordinates.filter {
            !matteMask[$0.y * v17.width + $0.x]
        }.count
        let uncoveredContamination = v17Coordinates.filter {
            let index = $0.y * v17.width + $0.x
            return !matteMask[index] && !cleaned.retainedDespillMask[index]
        }.count
        guard uncoveredContamination == 0 else {
            throw MatteDiagnosticError.invalid(
                "border-connected matte did not cover every contaminated coordinate: uncovered=\(uncoveredContamination)"
            )
        }
        var outputExactOrNearAtNonzeroAlpha = 0
        var outputHiddenRGB = 0
        for index in 0..<(v17.width * v17.height) {
            let offset = index * 4
            if cleaned.rgba[offset + 3] > 0
                && (
                    isExactChroma(cleaned.rgba, offset)
                        || isNearChroma(cleaned.rgba, offset)
                )
            {
                outputExactOrNearAtNonzeroAlpha += 1
            }
            if cleaned.rgba[offset + 3] == 0
                && (
                    cleaned.rgba[offset] != 0
                        || cleaned.rgba[offset + 1] != 0
                        || cleaned.rgba[offset + 2] != 0
                )
            {
                outputHiddenRGB += 1
            }
        }
        guard
            outputExactOrNearAtNonzeroAlpha == 0,
            outputHiddenRGB == 0
        else {
            throw MatteDiagnosticError.invalid(
                "diagnostic cleanup retained chroma or hidden RGB"
            )
        }
        guard let cleanedBounds = alphaBounds(
            cleaned.rgba,
            width: v17.width,
            height: v17.height
        ) else {
            throw MatteDiagnosticError.invalid("diagnostic cleanup removed all support")
        }
        guard
            let retainedSupportBounds = alphaBounds(
                retainedSupportRGBA,
                width: v17.width,
                height: v17.height
            ),
            retainedSupportBounds == cleanedBounds
        else {
            throw MatteDiagnosticError.invalid(
                "diagnostic cleanup changed retained candidate bounds"
            )
        }

        var maskRGBA = [UInt8](
            repeating: 0,
            count: v17.width * v17.height * 4
        )
        for coordinate in v17Coordinates {
            let offset = (coordinate.y * v17.width + coordinate.x) * 4
            switch attributions[coordinate]!.label {
            case "silhouette-edge":
                maskRGBA[offset] = 30
                maskRGBA[offset + 1] = 220
                maskRGBA[offset + 2] = 240
            case "contact-shadow-edge":
                maskRGBA[offset] = 255
                maskRGBA[offset + 1] = 145
                maskRGBA[offset + 2] = 25
            case "overlap":
                maskRGBA[offset] = 255
                maskRGBA[offset + 1] = 255
                maskRGBA[offset + 2] = 255
            default:
                break
            }
            maskRGBA[offset + 3] = 255
        }
        var shadowSupportRGBA = [UInt8](
            repeating: 0,
            count: v17.width * v17.height * 4
        )
        for y in 0..<v17.height {
            for x in 0..<v17.width {
                let coordinate = Coordinate(x: x, y: y)
                guard withinShadowSupport(
                    coordinate,
                    polygon: shadowPolygon
                ) else {
                    continue
                }
                let offset = (y * v17.width + x) * 4
                shadowSupportRGBA[offset] = 255
                shadowSupportRGBA[offset + 1] = 145
                shadowSupportRGBA[offset + 2] = 25
                shadowSupportRGBA[offset + 3] = 180
            }
        }

        let rawColor = try neutralComposite(
            rgba: v17.rgba,
            width: v17.width,
            height: v17.height,
            grayscale: false,
            removeExactOnly: true
        )
        let rawGray = try neutralComposite(
            rgba: v17.rgba,
            width: v17.width,
            height: v17.height,
            grayscale: true,
            removeExactOnly: true
        )
        let cleanColor = try neutralComposite(
            rgba: cleaned.rgba,
            width: v17.width,
            height: v17.height,
            grayscale: false,
            removeExactOnly: false
        )
        let cleanGray = try neutralComposite(
            rgba: cleaned.rgba,
            width: v17.width,
            height: v17.height,
            grayscale: true,
            removeExactOnly: false
        )
        let mask = try image(
            rgba: maskRGBA,
            width: v17.width,
            height: v17.height
        )
        let shadowSupport = try image(
            rgba: shadowSupportRGBA,
            width: v17.width,
            height: v17.height
        )
        let diagnosticCopyURL = outputDirectory.appendingPathComponent(
            "DIAGNOSTIC-MATTE-REMOVED.png"
        )
        try writePNG(
            try image(
                rgba: cleaned.rgba,
                width: v17.width,
                height: v17.height
            ),
            to: diagnosticCopyURL
        )
        let panels: [(String, CGImage)] = [
            (
                "NATIVE-2X-COLOR-BEFORE-AFTER.png",
                try sideBySide(
                    try scaled(rawColor, width: 384, height: 256),
                    try scaled(cleanColor, width: 384, height: 256),
                    width: 384,
                    height: 256
                )
            ),
            (
                "NATIVE-2X-GRAYSCALE-BEFORE-AFTER.png",
                try sideBySide(
                    try scaled(rawGray, width: 384, height: 256),
                    try scaled(cleanGray, width: 384, height: 256),
                    width: 384,
                    height: 256
                )
            ),
            (
                "LITERAL-192-COLOR-BEFORE-AFTER.png",
                try sideBySide(
                    try scaled(rawColor, width: 192, height: 128),
                    try scaled(cleanColor, width: 192, height: 128),
                    width: 192,
                    height: 128
                )
            ),
            (
                "LITERAL-192-GRAYSCALE-BEFORE-AFTER.png",
                try sideBySide(
                    try scaled(rawGray, width: 192, height: 128),
                    try scaled(cleanGray, width: 192, height: 128),
                    width: 192,
                    height: 128
                )
            ),
            (
                "ATTRIBUTION-MASK-NATIVE-2X.png",
                try scaled(mask, width: 384, height: 256)
            ),
            (
                "ATTRIBUTION-MASK-LITERAL-192.png",
                try scaled(mask, width: 192, height: 128)
            ),
            (
                "CONTACT-SHADOW-SUPPORT-LITERAL-192.png",
                try scaled(shadowSupport, width: 192, height: 128)
            ),
        ]
        for (name, panel) in panels {
            try writePNG(panel, to: outputDirectory.appendingPathComponent(name))
        }

        let mattePixelCount = matteMask.filter { $0 }.count
        let changedPixelCount = cleaned.changed.filter { $0 }.count
        let borderConnectedExactChromaCount =
            matteMask.enumerated().filter {
                $0.element && isExactChroma(v17.rgba, $0.offset * 4)
            }.count
        let borderConnectedNearChromaCount =
            matteMask.enumerated().filter {
                $0.element && isNearChroma(v17.rgba, $0.offset * 4)
            }.count
        let borderConnectedOtherMatteCount =
            mattePixelCount
            - borderConnectedExactChromaCount
            - borderConnectedNearChromaCount
        let report: [String: Any] = [
            "taskID": "PLAY-027",
            "artifact": "industrial-l04-v17-matte-attribution-v01",
            "diagnosticOnly": true,
            "sourceAuthority": false,
            "productionSelected": false,
            "disposition": "PASS_DIAGNOSTIC_MATTE_ATTRIBUTION",
            "processCounts": [
                "metal": 0,
                "sceneKit": 0,
                "raw": 0,
                "authorityNormalizer": 0,
            ],
            "inputs": [
                "v17Raw": [
                    "file": v17RawRelativePath,
                    "fileSHA256": v17.fileSHA256,
                    "decodedRGBASHA256": v17.decodedRGBASHA256,
                ],
                "v16Raw": [
                    "file": v16RawRelativePath,
                    "fileSHA256": v16.fileSHA256,
                    "decodedRGBASHA256": v16.decodedRGBASHA256,
                ],
                "descriptor": [
                    "file": descriptorRelativePath,
                    "sha256": expectedDescriptorSHA,
                ],
                "material": [
                    "file": materialRelativePath,
                    "sha256": expectedMaterialSHA,
                ],
            ],
            "nearChroma": [
                "count": v17Coordinates.count,
                "v16V17CoordinateSetsEqual": true,
                "coordinateSHA256": coordinateHashResult.sha256,
                "coordinateSerialization": coordinateHashResult.name,
                "histogram": histogram,
            ],
            "contactProjection": [
                "formula":
                    "x=768+(worldX-worldZ)*256/72; y=768+(worldX+worldZ)*128/72; shadowOffset=shadowVectorSource*28",
                "contactPolygonWorld": contactValues.map {
                    [$0[0].doubleValue, $0[1].doubleValue]
                },
                "shadowVectorSource": shadowVector.map(\.doubleValue),
                "shadowOffsetSource": [shadowOffset.x, shadowOffset.y],
                "shadowBlurSourcePixels": shadowBlur.doubleValue,
                "projectedShadowPolygonSource": shadowPolygon.map {
                    [$0.x, $0.y]
                },
            ],
            "attribution": [
                "counts": attributionCounts,
                "complete": attributionCounts["unowned"] == 0,
                "silhouetteSupportRule":
                    "within Chebyshev radius 3 of a retained non-matte non-shadow-family pixel",
                "shadowSupportRule":
                    "inside frozen projected contact polygon or within 1.5 source pixels of its zero-blur boundary",
            ],
            "diagnosticCleanup": [
                "algorithm":
                    "existing NormalizeOfflineSource border-connected isOfflineMatte flood then retained-pixel despill and zero hidden RGB",
                "borderConnectedMattePixelCount": mattePixelCount,
                "borderConnectedExactChromaPixelCount":
                    borderConnectedExactChromaCount,
                "borderConnectedNearChromaPixelCount":
                    borderConnectedNearChromaCount,
                "borderConnectedOtherMattePixelCount":
                    borderConnectedOtherMatteCount,
                "classifiedContaminationPixelCount": contaminationSet.count,
                "contaminationOutsideBorderMattePixelCount":
                    contaminationOutsideBorderMatte,
                "contaminationOutsideClassifiedMatteSpillSet":
                    uncoveredContamination,
                "changedPixelCount": changedPixelCount,
                "changedOutsideBorderConnectedMattePixelCount":
                    changedOutsideMatte,
                "changedOutsideClassifiedMatteSpillSet":
                    changedOutsideClassifiedSpill,
                "retainedCandidateDespillPixelCount": cleaned.retainedDespillCount,
                "retainedDespillOutsideMatteSupportPixelCount":
                    retainedDespillOutsideMatteSupport,
                "retainedDespillOutsideMatteSupportSamples":
                    retainedDespillOutsideSamples,
                "outputExactOrNearChromaAtNonzeroAlpha":
                    outputExactOrNearAtNonzeroAlpha,
                "outputHiddenRGBAtAlphaZero": outputHiddenRGB,
                "outputAlphaBounds": cleanedBounds.array,
                "retainedCandidateBoundsBeforeCleanup":
                    retainedSupportBounds.array,
                "retainedCandidateBoundsPreserved":
                    retainedSupportBounds == cleanedBounds,
                "outputCanvasPixels": [v17.width, v17.height],
                "diagnosticCopyFile": "DIAGNOSTIC-MATTE-REMOVED.png",
                "diagnosticCopyFileSHA256": try digest(diagnosticCopyURL),
                "diagnosticCopyDecodedRGBASHA256":
                    digest(Data(cleaned.rgba)),
            ],
            "immutability": [
                "rawFilesChanged": false,
                "descriptorChanged": false,
                "cameraChanged": false,
                "pivotChanged": false,
                "socketChanged": false,
                "contactPolygonChanged": false,
                "sourceBoundsChanged": false,
            ],
            "tool": [
                "file": toolRelativePath,
                "sourceSHA256": try digest(repositoryURL(toolRelativePath)),
                "compiledBinarySHA256": try digest(
                    URL(fileURLWithPath: CommandLine.arguments[0])
                ),
                "compileCommand":
                    "xcrun swiftc -parse-as-library -warnings-as-errors -module-cache-path <task-local-cache> BuildIndustrialL4V17MatteAttribution.swift -framework CoreGraphics -framework ImageIO -framework UniformTypeIdentifiers -o build-industrial-l4-v17-matte-attribution",
                "toolchain":
                    "swift-driver 1.148.6; Apple Swift 6.3.3; arm64-apple-macosx26.0; macOS 26.4.1 (25E253)",
            ],
        ]
        let reportURL = outputDirectory.appendingPathComponent(
            "MATTE-ATTRIBUTION.json"
        )
        try writeJSON(report, to: reportURL)

        var inventory: [[String: Any]] = []
        for file in try fileManager.contentsOfDirectory(
            at: outputDirectory,
            includingPropertiesForKeys: nil
        ).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard file.lastPathComponent != "IMMUTABLE-MANIFEST.json" else {
                continue
            }
            inventory.append([
                "file": file.lastPathComponent,
                "sha256": try digest(file),
            ])
        }
        let manifest: [String: Any] = [
            "taskID": "PLAY-027",
            "artifact": "industrial-l04-v17-matte-attribution-v01",
            "diagnosticOnly": true,
            "sourceAuthority": false,
            "productionSelected": false,
            "inputs": [
                [
                    "file": v17RawRelativePath,
                    "sha256": v17.fileSHA256,
                ],
                [
                    "file": v16RawRelativePath,
                    "sha256": v16.fileSHA256,
                ],
                [
                    "file": descriptorRelativePath,
                    "sha256": expectedDescriptorSHA,
                ],
                [
                    "file": materialRelativePath,
                    "sha256": expectedMaterialSHA,
                ],
            ],
            "outputs": inventory,
        ]
        try writeJSON(
            manifest,
            to: outputDirectory.appendingPathComponent(
                "IMMUTABLE-MANIFEST.json"
            )
        )
        print("PASS Industrial L4 v17 matte attribution")
        print("near-chroma-count=\(v17Coordinates.count)")
        print("coordinate-sha256=\(coordinateHashResult.sha256)")
        print("attribution=\(attributionCounts)")
        print("diagnostic-copy-sha256=\(try digest(diagnosticCopyURL))")
    }
}
