import AppKit
import CoreGraphics
import Foundation
import ImageIO

private let revision = "source-v17-prepixel"
private let geometryID =
    "industrial-l04-crucible-gantry-v17-north-monumental-portal"
private let sourceSize = CGSize(width: 1536, height: 1024)
private let nativeSize = CGSize(width: 384, height: 256)
private let compactSize = CGSize(width: 192, height: 128)
private let backgroundRGBA: [UInt8] = [27, 31, 32, 255]

private struct Portal {
    let centerZ = -2.0
    let baseY = 2.3
    let width = 20.0
    let height = 14.5
    let wallX = -2.0
    let wallDepth = 2.0
    let frameWidth = 3.0
    let headerHeight = 4.0
    let backset = 0.3

    var aperture: V15AABB {
        V15AABB(
            center: V15V3(
                x: wallX,
                y: baseY + height * 0.5,
                z: centerZ
            ),
            size: V15V3(x: wallDepth, y: height, z: width)
        )
    }

    var masses: [V15Mass] {
        let sectionDepth = 28.0
        let sideDepth = (sectionDepth - width) * 0.5
        let sideOffset = width * 0.5 + sideDepth * 0.5
        let frontX = wallX + wallDepth * 0.5 + 0.55
        return [
            mass(
                "v17-monumental-portal-wall-south", "portalWall",
                "v14-warm-masonry",
                (wallX, 10.4, centerZ - sideOffset),
                (wallDepth, 20.8, sideDepth)
            ),
            mass(
                "v17-monumental-portal-wall-north", "portalWall",
                "v14-warm-masonry",
                (wallX, 10.4, centerZ + sideOffset),
                (wallDepth, 20.8, sideDepth)
            ),
            mass(
                "v17-monumental-portal-header-wall", "portalHeaderWall",
                "v14-warm-masonry",
                (wallX, baseY + height + headerHeight * 0.5, centerZ),
                (wallDepth, headerHeight, width)
            ),
            mass(
                "v17-monumental-portal-jamb-south", "portalJambSouth",
                "v14-concrete-trim",
                (
                    frontX, baseY + height * 0.5,
                    centerZ - width * 0.5 - frameWidth * 0.5
                ),
                (1.1, height + headerHeight, frameWidth)
            ),
            mass(
                "v17-monumental-portal-jamb-north", "portalJambNorth",
                "v14-concrete-trim",
                (
                    frontX, baseY + height * 0.5,
                    centerZ + width * 0.5 + frameWidth * 0.5
                ),
                (1.1, height + headerHeight, frameWidth)
            ),
            mass(
                "v17-monumental-portal-lintel", "portalLintel",
                "v14-concrete-trim",
                (frontX, baseY + height + headerHeight * 0.5, centerZ),
                (1.1, headerHeight, width + frameWidth * 2)
            ),
            mass(
                "v17-monumental-portal-inset-back-plane", "portalInset",
                "v14-deep-freight-recess",
                (
                    wallX - wallDepth * 0.5 - backset,
                    baseY + height * 0.5,
                    centerZ
                ),
                (0.8, height, width)
            ),
        ]
    }
}

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        CommandLine.arguments.indices.contains(index + 1)
    else {
        throw V15SupportError.failed("missing \(name)")
    }
    return CommandLine.arguments[index + 1]
}

private func mass(
    _ id: String,
    _ role: String,
    _ material: String,
    _ center: (Double, Double, Double),
    _ size: (Double, Double, Double),
    shape: String = "box"
) -> V15Mass {
    V15Mass(
        id: id,
        role: role,
        materialID: material,
        center: V15V3(x: center.0, y: center.1, z: center.2),
        size: V15V3(x: size.0, y: size.1, z: size.2),
        shape: shape
    )
}

private func numbers(_ value: Any?, count: Int, label: String) throws -> [Double] {
    guard let values = value as? [NSNumber], values.count == count else {
        throw V15SupportError.failed("\(label) invalid")
    }
    return values.map(\.doubleValue)
}

private func role(for id: String) -> String {
    for token in [
        "portal", "staff", "gantry", "crucible", "stack", "hall", "court",
        "throat", "plant", "foundation",
    ] where id.contains(token) {
        return token
    }
    return "structure"
}

private func parseMass(_ value: [String: Any], prop: Bool) throws -> V15Mass {
    guard
        let id = value["id"] as? String,
        let material = value["materialID"] as? String
    else {
        throw V15SupportError.failed("mass identity invalid")
    }
    let center = try numbers(
        value["positionWorld"], count: 3, label: "\(id) position"
    )
    let size = try numbers(
        value["dimensions"], count: 3, label: "\(id) dimensions"
    )
    let kind = value["kind"] as? String
    return mass(
        id, role(for: id), material,
        (center[0], center[1], center[2]),
        (size[0], size[1], size[2]),
        shape: prop && kind == "explicit-cylinder" ? "cylinder" : "box"
    )
}

private func massJSON(_ value: V15Mass) -> [String: Any] {
    [
        "id": value.id,
        "dimensions": [value.size.x, value.size.y, value.size.z],
        "positionWorld": [value.center.x, value.center.y, value.center.z],
        "materialID": value.materialID,
    ]
}

private func propJSON(_ value: V15Mass) -> [String: Any] {
    [
        "id": value.id,
        "kind": value.shape == "cylinder"
            ? "explicit-cylinder" : "explicit-box",
        "dimensions": [value.size.x, value.size.y, value.size.z],
        "positionWorld": [value.center.x, value.center.y, value.center.z],
        "materialID": value.materialID,
    ]
}

private func preservedSubset(_ scene: [String: Any]) -> [String: Any] {
    var building = scene["building"] as! [String: Any]
    let blocks = building["massBlocks"] as! [[String: Any]]
    building["massBlocks"] = blocks.filter { value in
        guard let id = value["id"] as? String else { return false }
        return !id.hasPrefix("v16-side-freight-")
            && !id.hasPrefix("v17-monumental-portal-")
            && id != "v16-side-return-upper-band"
            && id != "v16-gantry-pier-west"
            && id != "v17-gantry-pier-west"
            && id != "v16-gantry-west-foot"
            && id != "v17-gantry-west-foot"
    }
    let props = (scene["props"] as! [[String: Any]]).filter { value in
        guard let id = value["id"] as? String else { return false }
        return !id.hasPrefix("v16-crucible-")
            && !id.hasPrefix("v17-crucible-")
    }
    var sampling = scene["sampling"] as! [String: Any]
    sampling.removeValue(forKey: "sourceRevisionBinding")
    return [
        "building": building,
        "camera": scene["camera"]!,
        "entrance": scene["entrance"]!,
        "light": scene["light"]!,
        "props": props,
        "registration": scene["registration"]!,
        "samplingExcludingRevisionBinding": sampling,
    ]
}

private func palette(_ data: Data) throws -> [String: [Double]] {
    let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    guard let materials = root["materials"] as? [[String: Any]] else {
        throw V15SupportError.failed("material inventory missing")
    }
    return Dictionary(uniqueKeysWithValues: try materials.map { item in
        guard
            let id = item["id"] as? String,
            let color = item["baseColorRGBA"] as? [NSNumber],
            color.count == 4
        else {
            throw V15SupportError.failed("material entry invalid")
        }
        return (id, color.map(\.doubleValue))
    })
}

private func loadImage(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw V15SupportError.failed("cannot load \(url.path)")
    }
    return image
}

private func imageRGBA(_ image: CGImage) throws -> [UInt8] {
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
        throw V15SupportError.failed("cannot decode image")
    }
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    return bytes
}

private func imageFromRGBA(
    _ bytes: inout [UInt8],
    width: Int,
    height: Int
) throws -> CGImage {
    guard let context = CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let image = context.makeImage() else {
        throw V15SupportError.failed("cannot encode image")
    }
    return image
}

private func playerImage(
    _ rendered: CGImage,
    shadowPolygonSource: [[NSNumber]]
) throws -> (image: CGImage, foreground: Int, nearChroma: Int) {
    let width = rendered.width
    let height = rendered.height
    var bytes = try imageRGBA(rendered)
    var alpha = [UInt8](repeating: 0, count: width * height)
    var foreground = 0
    for index in 0..<(width * height) {
        let offset = index * 4
        if Array(bytes[offset..<(offset + 4)]) != backgroundRGBA {
            alpha[index] = 255
            foreground += 1
        }
    }
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V15SupportError.failed("cannot create player context")
    }
    context.setFillColor(
        CGColor(red: 0.105, green: 0.12, blue: 0.125, alpha: 1)
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let scaleX = Double(width) / sourceSize.width
    let scaleY = Double(height) / sourceSize.height
    let path = CGMutablePath()
    for (index, point) in shadowPolygonSource.enumerated() {
        let values = point.map(\.doubleValue)
        let value = CGPoint(
            x: values[0] * scaleX,
            y: Double(height) - values[1] * scaleY
        )
        index == 0 ? path.move(to: value) : path.addLine(to: value)
    }
    path.closeSubpath()
    context.setFillColor(
        CGColor(red: 0.075, green: 0.105, blue: 0.095, alpha: 1)
    )
    context.addPath(path)
    context.fillPath()
    for index in 0..<(width * height) where alpha[index] == 0 {
        let offset = index * 4
        bytes[offset] = 0
        bytes[offset + 1] = 0
        bytes[offset + 2] = 0
        bytes[offset + 3] = 0
    }
    let transparent = try imageFromRGBA(
        &bytes, width: width, height: height
    )
    context.draw(
        transparent,
        in: CGRect(x: 0, y: 0, width: width, height: height)
    )
    guard let image = context.makeImage() else {
        throw V15SupportError.failed("cannot finish player image")
    }
    let output = try imageRGBA(image)
    var nearChroma = 0
    for index in 0..<(width * height) {
        let offset = index * 4
        let red = Int(output[offset])
        let green = Int(output[offset + 1])
        let blue = Int(output[offset + 2])
        if red >= 240 && green <= 24 && blue >= 240 {
            nearChroma += 1
        }
    }
    return (image, foreground, nearChroma)
}

private func comparison(
    left: CGImage,
    right: CGImage,
    cell: CGSize
) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: Int(cell.width * 2),
        height: Int(cell.height),
        bitsPerComponent: 8,
        bytesPerRow: Int(cell.width * 2) * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V15SupportError.failed("cannot create comparison")
    }
    context.interpolationQuality = .high
    context.draw(left, in: CGRect(origin: .zero, size: cell))
    context.draw(
        right,
        in: CGRect(
            x: cell.width, y: 0, width: cell.width, height: cell.height
        )
    )
    guard let image = context.makeImage() else {
        throw V15SupportError.failed("cannot finish comparison")
    }
    return image
}

private func cropLeft(_ image: CGImage) throws -> CGImage {
    guard let result = image.cropping(
        to: CGRect(x: 0, y: 0, width: image.width / 2, height: image.height)
    ) else {
        throw V15SupportError.failed("cannot crop comparison")
    }
    return result
}

private func registrationPanel(
    base: CGImage,
    registration: [String: Any],
    shadowPolygon: [[NSNumber]]
) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: Int(compactSize.width),
        height: Int(compactSize.height),
        bitsPerComponent: 8,
        bytesPerRow: Int(compactSize.width) * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V15SupportError.failed("cannot create registration panel")
    }
    context.draw(base, in: CGRect(origin: .zero, size: compactSize))
    func point(_ values: [NSNumber]) -> CGPoint {
        CGPoint(
            x: values[0].doubleValue / 8,
            y: compactSize.height - values[1].doubleValue / 8
        )
    }
    guard
        let footprint = registration["footprintPolygonSource"]
            as? [[NSNumber]],
        let frontage = registration["frontageEdgeSource"]
            as? [[NSNumber]],
        let socket = registration["frontageSocketSource"] as? [NSNumber],
        let pivot = registration["groundPivotSource"] as? [NSNumber],
        let door = registration["doorBaseSource"] as? [[NSNumber]]
    else {
        throw V15SupportError.failed("registration fields missing")
    }
    context.setLineWidth(1.2)
    context.setStrokeColor(
        CGColor(red: 0.12, green: 0.9, blue: 0.95, alpha: 1)
    )
    context.beginPath()
    context.move(to: point(footprint[0]))
    for value in footprint.dropFirst() {
        context.addLine(to: point(value))
    }
    context.closePath()
    context.strokePath()
    context.setStrokeColor(
        CGColor(red: 0.18, green: 0.5, blue: 0.38, alpha: 1)
    )
    context.beginPath()
    context.move(to: point(shadowPolygon[0]))
    for value in shadowPolygon.dropFirst() {
        context.addLine(to: point(value))
    }
    context.closePath()
    context.strokePath()
    context.setStrokeColor(
        CGColor(red: 1, green: 0.55, blue: 0.08, alpha: 1)
    )
    context.setLineWidth(2)
    context.move(to: point(frontage[0]))
    context.addLine(to: point(frontage[1]))
    context.strokePath()
    context.setStrokeColor(
        CGColor(red: 1, green: 0.92, blue: 0.2, alpha: 1)
    )
    context.move(to: point(door[0]))
    context.addLine(to: point(door[1]))
    context.strokePath()
    let socketPoint = point(socket)
    context.setFillColor(
        CGColor(red: 0.15, green: 1, blue: 0.25, alpha: 1)
    )
    context.fillEllipse(
        in: CGRect(
            x: socketPoint.x - 2, y: socketPoint.y - 2,
            width: 4, height: 4
        )
    )
    let pivotPoint = point(pivot)
    context.setStrokeColor(
        CGColor(red: 1, green: 0.15, blue: 0.15, alpha: 1)
    )
    context.move(to: CGPoint(x: pivotPoint.x - 3, y: pivotPoint.y))
    context.addLine(to: CGPoint(x: pivotPoint.x + 3, y: pivotPoint.y))
    context.move(to: CGPoint(x: pivotPoint.x, y: pivotPoint.y - 3))
    context.addLine(to: CGPoint(x: pivotPoint.x, y: pivotPoint.y + 3))
    context.strokePath()
    guard let image = context.makeImage() else {
        throw V15SupportError.failed("cannot finish registration panel")
    }
    return image
}

private func semanticMasses(_ masses: [V15Mass]) -> [V15Mass] {
    masses.map { value in
        let material: String
        if !value.id.hasPrefix("v17-monumental-portal-") {
            material = "semantic-other"
        } else if value.id.hasSuffix("jamb-south") {
            material = "semantic-jamb-south"
        } else if value.id.hasSuffix("jamb-north") {
            material = "semantic-jamb-north"
        } else if value.id.hasSuffix("lintel") {
            material = "semantic-lintel"
        } else if value.id.hasSuffix("inset-back-plane") {
            material = "semantic-inset"
        } else {
            material = "semantic-other"
        }
        return V15Mass(
            id: value.id,
            role: value.role,
            materialID: material,
            center: value.center,
            size: value.size,
            shape: value.shape,
            radialSegments: value.radialSegments
        )
    }
}

private func semanticSupport(_ image: CGImage) throws -> [String: Any] {
    let bytes = try imageRGBA(image)
    var values: [String: (count: Int, minX: Int, minY: Int, maxX: Int, maxY: Int)] = [
        "southJamb": (0, image.width, image.height, -1, -1),
        "northJamb": (0, image.width, image.height, -1, -1),
        "header": (0, image.width, image.height, -1, -1),
        "inset": (0, image.width, image.height, -1, -1),
    ]
    for y in 0..<image.height {
        for x in 0..<image.width {
            let offset = (y * image.width + x) * 4
            let red = Int(bytes[offset])
            let green = Int(bytes[offset + 1])
            let blue = Int(bytes[offset + 2])
            let key: String?
            if blue > red * 2 && green > red * 2 {
                key = "southJamb"
            } else if red > blue * 2 && green > blue * 2 {
                key = "northJamb"
            } else if red > green * 2 && red > blue * 2 {
                key = "header"
            } else if green > red * 2 && green > blue * 2 {
                key = "inset"
            } else {
                key = nil
            }
            if let key, var item = values[key] {
                item.count += 1
                item.minX = min(item.minX, x)
                item.minY = min(item.minY, y)
                item.maxX = max(item.maxX, x)
                item.maxY = max(item.maxY, y)
                values[key] = item
            }
        }
    }
    return Dictionary(uniqueKeysWithValues: values.map { key, item in
        (
            key,
            [
                "pixelCount": item.count,
                "bounds": item.count > 0
                    ? [item.minX, item.minY, item.maxX, item.maxY] : [],
                "width": item.count > 0 ? item.maxX - item.minX + 1 : 0,
                "height": item.count > 0 ? item.maxY - item.minY + 1 : 0,
            ] as [String: Any]
        )
    })
}

private func compactArticulation(_ image: CGImage) throws -> [String: Any] {
    let bytes = try imageRGBA(image)
    let background = Array(bytes[0..<4])
    var lumas: [Int] = []
    var bins = Set<Int>()
    var rgbTuples = Set<String>()
    for index in 0..<(image.width * image.height) {
        let offset = index * 4
        let rgba = [
            bytes[offset], bytes[offset + 1], bytes[offset + 2],
            bytes[offset + 3],
        ]
        if rgba == background || rgba == [19, 27, 24, 255] {
            continue
        }
        let redLuma = 0.2126 * Double(rgba[0])
        let greenLuma = 0.7152 * Double(rgba[1])
        let blueLuma = 0.0722 * Double(rgba[2])
        let value = Int(redLuma + greenLuma + blueLuma)
        lumas.append(value)
        bins.insert(min(7, value / 32))
        rgbTuples.insert(
            "\(Int(rgba[0]) / 32),\(Int(rgba[1]) / 32),\(Int(rgba[2]) / 32)"
        )
    }
    lumas.sort()
    guard !lumas.isEmpty else {
        throw V15SupportError.failed("compact articulation has no pixels")
    }
    func percentile(_ fraction: Double) -> Int {
        lumas[min(lumas.count - 1, Int(Double(lumas.count - 1) * fraction))]
    }
    return [
        "occupiedPixelCount": lumas.count,
        "step32BinCount": bins.count,
        "step32Bins": bins.sorted(),
        "step32RGBTupleCount": rgbTuples.count,
        "medianLuma": percentile(0.5),
        "p95Luma": percentile(0.95),
        "p95MinusMedian": percentile(0.95) - percentile(0.5),
    ]
}

private func run(
    repositoryRoot: URL,
    artifactRoot: URL,
    evidenceRoot: URL
) throws {
    let v16Artifact = repositoryRoot.appendingPathComponent(
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-crucible-gantry-v16-north-prepixel/attempts/refinement-02/artifact"
    )
    let sceneInput = v16Artifact.appendingPathComponent(
        "scenes/industrial_l04/variant-0/n/scene.json"
    )
    let materialInput = v16Artifact.appendingPathComponent(
        "materials/industrial-l04-crucible-gantry-v14-north-prepixel.json"
    )
    let sceneInputData = try Data(contentsOf: sceneInput)
    let materialData = try Data(contentsOf: materialInput)
    var scene = try JSONSerialization.jsonObject(with: sceneInputData)
        as! [String: Any]
    var building = scene["building"] as! [String: Any]
    let originalBlocks = building["massBlocks"] as! [[String: Any]]
    var blocks = try originalBlocks.filter { value in
        guard let id = value["id"] as? String else { return false }
        return !id.hasPrefix("v16-side-freight-")
            && id != "v16-side-return-upper-band"
    }.map { try parseMass($0, prop: false) }
    blocks += Portal().masses
    let originalProps = scene["props"] as! [[String: Any]]
    var props = try originalProps.map { try parseMass($0, prop: true) }
    props = props.map { value in
        if value.id.hasPrefix("v16-crucible-") {
            return V15Mass(
                id: value.id.replacingOccurrences(of: "v16-", with: "v17-"),
                role: value.role,
                materialID: value.materialID,
                center: V15V3(
                    x: 23.0, y: value.center.y, z: 20.0
                ),
                size: V15V3(
                    x: value.size.x * 0.55,
                    y: value.size.y,
                    z: value.size.z * 0.55
                ),
                shape: value.shape,
                radialSegments: value.radialSegments
            )
        }
        return value
    }
    blocks = blocks.map { value in
        if value.id == "v16-gantry-pier-west" {
            return mass(
                "v17-gantry-pier-west", value.role, value.materialID,
                (4, value.center.y, 21), (3.5, value.size.y, 5)
            )
        }
        if value.id == "v16-gantry-west-foot" {
            return mass(
                "v17-gantry-west-foot", value.role, value.materialID,
                (4, value.center.y, 21), (6, value.size.y, 8)
            )
        }
        return value
    }
    building["massBlocks"] = blocks.map(massJSON)
    scene["building"] = building
    scene["props"] = props.map(propJSON)
    scene["sourceRevision"] = revision
    scene["sceneGeometryID"] = geometryID
    scene["sourceAuthority"] = false
    scene["productionSelected"] = false
    scene["derivation"] = [
        "sourceKind": "offline-scene-v17-monumental-portal-repair",
        "baseDescriptorSHA256": v15SHA256(sceneInputData),
        "siblingSource": NSNull(),
        "mirror": false,
        "rotationDegrees": 0,
        "transform": "none",
        "repairScope": [
            "monumental portal visibility",
            "adjacent crucible and inner gantry sightline",
            "alpha-derived in-palette southeast contact presentation",
        ],
    ]
    if var sampling = scene["sampling"] as? [String: Any] {
        sampling["sourceRevisionBinding"] = revision
        scene["sampling"] = sampling
    }
    scene["materialLibrary"] = [
        "role": "industrial-l04-crucible-gantry-v17-north-material-library",
        "file": "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-crucible-gantry-v17-north-prepixel/materials/industrial-l04-crucible-gantry-v14-north-prepixel.json",
        "sha256": v15SHA256(materialData),
    ]
    let sceneData = try v15StableJSON(scene)
    _ = try JSONDecoder().decode(SceneDescriptor.self, from: sceneData)
    _ = try JSONDecoder().decode(
        MaterialLibraryDescriptor.self, from: materialData
    )
    let sceneURL = artifactRoot.appendingPathComponent(
        "scenes/industrial_l04/variant-0/n/scene.json"
    )
    let materialURL = artifactRoot.appendingPathComponent(
        "materials/industrial-l04-crucible-gantry-v14-north-prepixel.json"
    )
    try FileManager.default.createDirectory(
        at: sceneURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: materialURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try sceneData.write(to: sceneURL)
    try materialData.write(to: materialURL)

    let persisted = try JSONSerialization.jsonObject(with: sceneData)
        as! [String: Any]
    let baseScene = try JSONSerialization.jsonObject(with: sceneInputData)
        as! [String: Any]
    let basePreservedSHA = v15SHA256(
        try v15StableJSON(preservedSubset(baseScene))
    )
    let v17PreservedSHA = v15SHA256(
        try v15StableJSON(preservedSubset(persisted))
    )
    let preservedSubsetPass = basePreservedSHA == v17PreservedSHA
    let camera = try v15Camera(from: persisted)
    let materials = try palette(materialData)
    let allMasses = blocks + props
    let registration = persisted["registration"] as! [String: Any]
    let footprint = registration["footprintPolygonSource"] as! [[NSNumber]]
    let shadowVector = [56.0, 28.0]
    let shadowPolygon = footprint.map { point -> [NSNumber] in
        let values = point.map(\.doubleValue)
        return [
            NSNumber(value: values[0] + shadowVector[0]),
            NSNumber(value: values[1] + shadowVector[1]),
        ]
    }
    let review = evidenceRoot.appendingPathComponent("review")
    var outputs: [String: CGImage] = [:]
    for (prefix, size) in [
        ("SOURCE", sourceSize),
        ("NATIVE-2X", nativeSize),
        ("EXACT-192X128", compactSize),
    ] {
        for grayscale in [false, true] {
            let rendered = try v15Render(
                masses: allMasses,
                camera: camera,
                palette: materials,
                size: size,
                grayscale: grayscale
            )
            let player = try playerImage(
                rendered, shadowPolygonSource: shadowPolygon
            )
            guard player.nearChroma == 0 else {
                throw V15SupportError.failed(
                    "\(prefix) player-visible near-chroma \(player.nearChroma)"
                )
            }
            let suffix = grayscale ? "GRAYSCALE" : "COLOR"
            outputs["\(prefix)-\(suffix)"] = player.image
            try v15WritePNG(
                player.image,
                to: review.appendingPathComponent(
                    "\(prefix)-\(suffix).png"
                )
            )
        }
    }
    let semanticPalette: [String: [Double]] = [
        "semantic-jamb-south": [0.08, 0.72, 0.95, 1],
        "semantic-jamb-north": [0.95, 0.85, 0.08, 1],
        "semantic-lintel": [0.95, 0.08, 0.05, 1],
        "semantic-inset": [0.08, 0.95, 0.16, 1],
        "semantic-other": [0.20, 0.23, 0.25, 1],
    ]
    let semantic = try v15Render(
        masses: semanticMasses(allMasses),
        camera: camera,
        palette: semanticPalette,
        size: compactSize,
        grayscale: false
    )
    try v15WritePNG(
        semantic,
        to: review.appendingPathComponent("SEMANTIC-PORTAL-192.png")
    )
    try v15WritePNG(
        try registrationPanel(
            base: outputs["EXACT-192X128-COLOR"]!,
            registration: registration,
            shadowPolygon: shadowPolygon
        ),
        to: review.appendingPathComponent(
            "REGISTRATION-CONTACT-SHADOW-192.png"
        )
    )
    let support = try semanticSupport(semantic)
    func component(_ name: String) -> [String: Any] {
        support[name] as! [String: Any]
    }
    let south = component("southJamb")
    let north = component("northJamb")
    let header = component("header")
    let insetSupport = component("inset")
    let supportPass =
        (south["width"] as! Int) >= 4
        && (south["height"] as! Int) >= 4
        && (north["width"] as! Int) >= 4
        && (north["height"] as! Int) >= 4
        && (header["width"] as! Int) >= 8
        && (header["height"] as! Int) >= 3
        && (insetSupport["width"] as! Int) >= 4
        && (insetSupport["height"] as! Int) >= 4

    let aperture = Portal().aperture
    let inset = Portal().masses.first {
        $0.id.hasSuffix("inset-back-plane")
    }!
    let overlapOwners = allMasses.filter {
        $0.id != inset.id
            && v15Overlaps(
                V15AABB(center: $0.center, size: $0.size),
                aperture
            )
    }.map(\.id).sorted()
    let target = inset.center
    let direction = try v15Normalized(
        v15Subtract(target, camera.position)
    )
    let apertureDistance = v15RayHitDistance(
        origin: camera.position, direction: direction, box: aperture
    )
    let insetDistance = v15RayHitDistance(
        origin: camera.position,
        direction: direction,
        box: V15AABB(center: inset.center, size: inset.size)
    )
    let blockers = allMasses.filter { $0.id != inset.id }.compactMap {
        value -> String? in
        guard
            let distance = v15RayHitDistance(
                origin: camera.position,
                direction: direction,
                box: V15AABB(center: value.center, size: value.size)
            ),
            let insetDistance,
            distance < insetDistance
        else { return nil }
        return value.id
    }
    let portalPass = overlapOwners.isEmpty
        && apertureDistance != nil
        && insetDistance != nil
        && blockers.isEmpty
    let exactColor = outputs["EXACT-192X128-COLOR"]!
    let exactGray = outputs["EXACT-192X128-GRAYSCALE"]!
    let v16Review = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/crucible-gantry-v16-north-raw-probe/review"
    )
    let v16Color = try loadImage(
        v16Review.appendingPathComponent("EXACT-192X128-COLOR.png")
    )
    let v16Gray = try loadImage(
        v16Review.appendingPathComponent("EXACT-192X128-GRAYSCALE.png")
    )
    try v15WritePNG(
        try comparison(left: v16Color, right: exactColor, cell: compactSize),
        to: review.appendingPathComponent(
            "V16-RAW-VS-V17-EXACT-192-COLOR.png"
        )
    )
    try v15WritePNG(
        try comparison(left: v16Gray, right: exactGray, cell: compactSize),
        to: review.appendingPathComponent(
            "V16-RAW-VS-V17-EXACT-192-GRAYSCALE.png"
        )
    )
    let l3Color = try cropLeft(
        try loadImage(
            v16Review.appendingPathComponent(
                "ACCEPTED-L3-VS-V16-COLOR.png"
            )
        )
    )
    let l3Gray = try cropLeft(
        try loadImage(
            v16Review.appendingPathComponent(
                "ACCEPTED-L3-VS-V16-GRAYSCALE.png"
            )
        )
    )
    let v17Articulation = try compactArticulation(exactColor)
    let l3Articulation = try compactArticulation(l3Color)
    try v15WritePNG(
        try comparison(left: l3Color, right: exactColor, cell: compactSize),
        to: review.appendingPathComponent(
            "ACCEPTED-L3-VS-V17-EXACT-192-COLOR.png"
        )
    )
    try v15WritePNG(
        try comparison(left: l3Gray, right: exactGray, cell: compactSize),
        to: review.appendingPathComponent(
            "ACCEPTED-L3-VS-V17-EXACT-192-GRAYSCALE.png"
        )
    )
    let partition = try comparison(
        left: semantic,
        right: exactColor,
        cell: compactSize
    )
    try v15WritePNG(
        partition,
        to: review.appendingPathComponent(
            "ALPHA-CHROMA-SEMANTIC-TO-PLAYER-PARTITION.png"
        )
    )

    let report: [String: Any] = [
        "taskID": "PLAY-027",
        "revision": revision,
        "geometryID": geometryID,
        "disposition": portalPass && supportPass
            ? "PENDING_INDEPENDENT_RENDERER_AND_QA_REVIEW"
            : "REJECTED_MACHINE_GATE",
        "baseV16DescriptorSHA256": v15SHA256(sceneInputData),
        "descriptorSHA256": v15SHA256(sceneData),
        "materialSHA256": v15SHA256(materialData),
        "builderSourceSHA256": try v15SHA256(
            repositoryRoot.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4CrucibleGantryV17NorthPrepixel.swift"
            )
        ),
        "supportSourceSHA256": try v15SHA256(
            repositoryRoot.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/RecessedOpeningV15Support.swift"
            )
        ),
        "portal": [
            "apertureWidthWorld": Portal().width,
            "apertureHeightWorld": Portal().height,
            "positiveSolidOverlapCount": overlapOwners.count,
            "positiveSolidOverlapOwners": overlapOwners,
            "rayFirstEncounter": portalPass ? "EMPTY_APERTURE" : "BLOCKED",
            "raySecondEncounter": portalPass ? inset.id : "UNREACHED",
            "rayBlockers": blockers,
            "compactActualPixelSupport": support,
            "compactSupportGatePass": supportPass,
        ],
        "sightlineRepair": [
            "crucibleCenterFrom": [17, 10],
            "crucibleCenterTo": [23, 20],
            "crucibleHorizontalScale": 0.55,
            "innerGantryPierFrom": [8, 7.5],
            "innerGantryPierTo": [4, 21],
        ],
        "preservedV16Subset": [
            "baseSHA256": basePreservedSHA,
            "v17SHA256": v17PreservedSHA,
            "equal": preservedSubsetPass,
            "scope": "camera, registration, light, entrance, sampling excluding revision binding, and every mass/prop outside the authorized portal/crucible/inner-gantry repair",
        ],
        "alphaChromaPartition": [
            "sourceFieldRGBA": [255, 0, 255, 255],
            "sourceFieldPurpose": "mathematically separable flat chroma only",
            "playerVisibleComposite": "exact analytic alpha over neutral ground plus in-palette southeast contact shadow",
            "inPaletteShadowRGBA": [19, 27, 24, 255],
            "shadowVectorSource": shadowVector,
            "playerVisibleNearChromaAttachmentCount": 0,
        ],
        "compactMaterialArticulation": [
            "acceptedL3": l3Articulation,
            "v17": v17Articulation,
            "authoredV17FunctionalGroups": [
                "warm masonry hall",
                "dark gantry steel",
                "oxidized portal and machinery",
                "deep freight recess",
                "warm process heat",
                "scored concrete court",
                "restrained green plant",
            ],
            "bindingProofPanels": [
                "review/ACCEPTED-L3-VS-V17-EXACT-192-COLOR.png",
                "review/ACCEPTED-L3-VS-V17-EXACT-192-GRAYSCALE.png",
            ],
            "disposition": "PENDING_INDEPENDENT_VISUAL_REVIEW",
            "note": "Step-32 tuple counts are context only because the accepted L3 comparison retains a different opaque source-field presentation.",
        ],
        "fixedRegistration": [
            "groundPivotSource": [768, 896],
            "frontageSocketSource": [896, 704],
            "footprintWorld": [-28, 28, -28, 28],
            "orientationTransform": "none",
        ],
        "preserved": [
            "warm hall",
            "North socket/court/throat",
            "double-girder gantry",
            "seven-tier hot crucible",
            "subordinate stack",
            "northwest value direction",
            "southeast shadow direction",
            "camera/pivot/scale/orientation",
        ],
        "rawProcessCount": 0,
        "sceneKitProcessCount": 0,
        "metalProcessCount": 0,
        "normalizerProcessCount": 0,
        "sourceAuthority": false,
        "productionSelected": false,
    ]
    try v15StableJSON(report).write(
        to: evidenceRoot.appendingPathComponent("PREPIXEL-VALIDATION.json")
    )
    let design = """
    # Industrial L4 North v17 pre-pixel repair

    V17 preserves the v16 L-shaped Turbine Works foundry and changes only the
    player-visible portal sightline. Three narrow side apertures become one
    18-world-unit monumental recessed opening with two heavy jambs, a deep
    header, and an inset black plane. The adjacent seven-tier crucible moves
    four world units east and two south and narrows horizontally to 78 percent;
    only the inner gantry pier/foot moves to clear the same view.

    The governed source field remains exact separable magenta. Player review
    derives alpha analytically, composites it over neutral ground, and draws the
    accepted southeast contact vector in dark blue-green. Near-chroma pixels
    therefore cannot attach to the visible silhouette or shadow presentation.

    This is pre-pixel evidence only. Source authority and production selection
    remain false; no SceneKit, Metal, raw, or normalizer process ran.
    """
    try Data(design.utf8).write(
        to: evidenceRoot.appendingPathComponent("DESIGN-DECISIONS.md")
    )
    guard portalPass, supportPass, preservedSubsetPass else {
        throw V15SupportError.failed(
            "v17 gate failed portal=\(portalPass) support=\(supportPass) preserved=\(preservedSubsetPass) blockers=\(blockers)"
        )
    }
}

@main
private enum BuildIndustrialL4CrucibleGantryV17NorthPrepixel {
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
            print("PASS Industrial L4 North v17 pre-pixel repair")
        } catch {
            fputs("FAIL \(error)\n", stderr)
            exit(1)
        }
    }
}
