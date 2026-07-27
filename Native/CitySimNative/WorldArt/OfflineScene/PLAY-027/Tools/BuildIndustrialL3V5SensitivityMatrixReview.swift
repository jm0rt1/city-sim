import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL3V5SensitivityReviewError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: build-industrial-l3-v5-sensitivity-review \
              --repository-root <path> --matrix-root <path> \
              --output-root <absent-path> --renderer-binary <path> \
              --renderer-source-commit <sha>
            """
        case let .invalid(message):
            return message
        }
    }
}

private struct ImageBuffer {
    let width: Int
    let height: Int
    let rgba: [UInt8]
}

private struct PixelDifference {
    let x: Int
    let y: Int
    let reference: [UInt8]
    let candidate: [UInt8]
}

private struct Bounds {
    var minimumX: Int
    var minimumY: Int
    var maximumX: Int
    var maximumY: Int

    var arrayExclusive: [Int] {
        [minimumX, minimumY, maximumX + 1, maximumY + 1]
    }
}

private struct Vector3 {
    let x: Double
    let y: Double
    let z: Double

    static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static func * (lhs: Vector3, rhs: Double) -> Vector3 {
        Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    func dot(_ other: Vector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    func cross(_ other: Vector3) -> Vector3 {
        Vector3(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }

    func normalized() throws -> Vector3 {
        let length = sqrt(dot(self))
        guard length > 0, length.isFinite else {
            throw IndustrialL3V5SensitivityReviewError.invalid(
                "invalid camera vector"
            )
        }
        return self * (1 / length)
    }
}

private struct ProjectedEnvelope {
    let materialID: String
    let primitiveID: String
    let bounds: [Int]
}

private struct RowContract {
    let id: String
    let direction: String
    let coordinates: [[Int]]
    let authorizedMaterials: Set<String>
}

private let rows = [
    RowContract(
        id: "N1",
        direction: "north",
        coordinates: [[688, 391], [795, 748]],
        authorizedMaterials: [
            "l3c-charcoal-outline-steel",
            "l3c-warm-trim",
        ]
    ),
    RowContract(
        id: "W1",
        direction: "west",
        coordinates: [[847, 391], [786, 524]],
        authorizedMaterials: [
            "l3c-charcoal-outline-steel",
            "l3c-warm-formed-concrete",
        ]
    ),
    RowContract(
        id: "W2",
        direction: "west",
        coordinates: [[847, 391], [786, 524]],
        authorizedMaterials: [
            "l3c-charcoal-outline-steel",
            "l3c-restrained-safety",
        ]
    ),
    RowContract(
        id: "W3",
        direction: "west",
        coordinates: [[847, 391], [786, 524]],
        authorizedMaterials: [
            "l3c-charcoal-outline-steel",
            "l3c-warm-formed-concrete",
            "l3c-restrained-safety",
        ]
    ),
]
private let runs = ["run-a", "run-b", "run-c"]
private let baselineRaw = [
    "north":
        "docs/production/evidence/PLAY-027/industrial-l03/l03/"
        + "cohesion-a0-frontage-raw-v01/diagnostics/raw-repeat/"
        + "north/run-a/raw.png",
    "west":
        "docs/production/evidence/PLAY-027/industrial-l03/l03/"
        + "cohesion-a0-frontage-raw-v01/diagnostics/raw-repeat/"
        + "west/run-a/raw.png",
]
private let baselineProvenance = [
    "north":
        "docs/production/evidence/PLAY-027/industrial-l03/l03/"
        + "cohesion-a0-frontage-raw-v01/diagnostics/raw-repeat/"
        + "north/run-a/provenance.json",
    "west":
        "docs/production/evidence/PLAY-027/industrial-l03/l03/"
        + "cohesion-a0-frontage-raw-v01/diagnostics/raw-repeat/"
        + "west/run-a/provenance.json",
]
private let expectedBaselineHashes = [
    "north":
        "5ca557dae856b492cf80d5074c89d1f9c1563ed9f90f9f8fb13efc498869fced",
    "west":
        "15eb5944d57fbf95beccac61729861a6648c0541df0a0103cafd2e649d4fbb0c",
]
private let sourceWidth = 1536
private let sourceHeight = 1024
private let nativeScale = 0.28125
private let compactScale = 0.125

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3V5SensitivityReviewError.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

private func jsonObject(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL3V5SensitivityReviewError.invalid(
            "JSON object expected: \(url.path)"
        )
    }
    return object
}

private func jsonData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func write(_ data: Data, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL3V5SensitivityReviewError.invalid(
            "refusing to overwrite \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .withoutOverwriting)
}

private func decodedImage(_ url: URL) throws -> ImageBuffer {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw IndustrialL3V5SensitivityReviewError.invalid(
            "could not decode \(url.path)"
        )
    }
    var rgba = [UInt8](
        repeating: 0,
        count: image.width * image.height * 4
    )
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let rendered = rgba.withUnsafeMutableBytes { bytes -> Bool in
        guard
            let context = CGContext(
                data: bytes.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: colorSpace,
                bitmapInfo:
                    CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            )
        else {
            return false
        }
        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(
                x: 0,
                y: 0,
                width: image.width,
                height: image.height
            )
        )
        return true
    }
    guard rendered else {
        throw IndustrialL3V5SensitivityReviewError.invalid(
            "could not canonicalize \(url.path)"
        )
    }
    return ImageBuffer(width: image.width, height: image.height, rgba: rgba)
}

private func pixel(_ image: ImageBuffer, x: Int, y: Int) -> [UInt8] {
    let index = (y * image.width + x) * 4
    return Array(image.rgba[index..<(index + 4)])
}

private func neighborhood(
    _ image: ImageBuffer,
    coordinate: [Int],
    radius: Int
) throws -> [String: Any] {
    guard
        coordinate.count == 2,
        coordinate[0] >= radius,
        coordinate[1] >= radius,
        coordinate[0] + radius < image.width,
        coordinate[1] + radius < image.height
    else {
        throw IndustrialL3V5SensitivityReviewError.invalid(
            "neighborhood coordinate outside image"
        )
    }
    var values: [[[UInt8]]] = []
    for y in (coordinate[1] - radius)...(coordinate[1] + radius) {
        var row: [[UInt8]] = []
        for x in (coordinate[0] - radius)...(coordinate[0] + radius) {
            row.append(pixel(image, x: x, y: y))
        }
        values.append(row)
    }
    return [
        "coordinate": coordinate,
        "radius": radius,
        "dimensions": [radius * 2 + 1, radius * 2 + 1],
        "rgba": values,
        "rgbaSHA256": sha256(Data(values.flatMap { $0 }.flatMap { $0 })),
    ]
}

private func differences(
    reference: ImageBuffer,
    candidate: ImageBuffer
) throws -> [PixelDifference] {
    guard
        reference.width == candidate.width,
        reference.height == candidate.height
    else {
        throw IndustrialL3V5SensitivityReviewError.invalid(
            "image dimensions differ"
        )
    }
    var result: [PixelDifference] = []
    for y in 0..<reference.height {
        for x in 0..<reference.width {
            let index = (y * reference.width + x) * 4
            let referenceRGBA =
                Array(reference.rgba[index..<(index + 4)])
            let candidateRGBA =
                Array(candidate.rgba[index..<(index + 4)])
            if referenceRGBA != candidateRGBA {
                result.append(
                    PixelDifference(
                        x: x,
                        y: y,
                        reference: referenceRGBA,
                        candidate: candidateRGBA
                    )
                )
            }
        }
    }
    return result
}

private func differenceRecord(
    _ differences: [PixelDifference]
) -> [String: Any] {
    var channelCounts = [0, 0, 0, 0]
    var maximumAbsoluteDelta = [0, 0, 0, 0]
    var bounds: Bounds?
    let pixels = differences.map { difference -> [String: Any] in
        for channel in 0..<4 {
            let delta =
                Int(difference.candidate[channel])
                - Int(difference.reference[channel])
            if delta != 0 {
                channelCounts[channel] += 1
                maximumAbsoluteDelta[channel] = max(
                    maximumAbsoluteDelta[channel],
                    abs(delta)
                )
            }
        }
        if var current = bounds {
            current.minimumX = min(current.minimumX, difference.x)
            current.minimumY = min(current.minimumY, difference.y)
            current.maximumX = max(current.maximumX, difference.x)
            current.maximumY = max(current.maximumY, difference.y)
            bounds = current
        } else {
            bounds = Bounds(
                minimumX: difference.x,
                minimumY: difference.y,
                maximumX: difference.x,
                maximumY: difference.y
            )
        }
        return [
            "coordinate": [difference.x, difference.y],
            "referenceRGBA": difference.reference,
            "candidateRGBA": difference.candidate,
            "channelDelta": zip(
                difference.candidate,
                difference.reference
            ).map { Int($0) - Int($1) },
        ]
    }
    return [
        "differingPixelCount": differences.count,
        "differingChannelCountsRGBA": channelCounts,
        "maximumAbsoluteChannelDeltaRGBA": maximumAbsoluteDelta,
        "differenceBoundsExclusive": bounds?.arrayExclusive ?? [],
        "alphaDifferenceCount": channelCounts[3],
        "pixels": pixels,
    ]
}

private func occupancy(_ image: ImageBuffer) -> [String: Any] {
    var count = 0
    var alphaZeroCount = 0
    var alphaNonOpaqueCount = 0
    var hiddenRGBCount = 0
    var bounds: Bounds?
    for y in 0..<image.height {
        for x in 0..<image.width {
            let value = pixel(image, x: x, y: y)
            if value[3] == 0 {
                alphaZeroCount += 1
                if value[0] != 0 || value[1] != 0 || value[2] != 0 {
                    hiddenRGBCount += 1
                }
            }
            if value[3] != 255 { alphaNonOpaqueCount += 1 }
            let chroma =
                value[0] == 255 && value[1] == 0
                && value[2] == 255 && value[3] == 255
            if !chroma {
                count += 1
                if var current = bounds {
                    current.minimumX = min(current.minimumX, x)
                    current.minimumY = min(current.minimumY, y)
                    current.maximumX = max(current.maximumX, x)
                    current.maximumY = max(current.maximumY, y)
                    bounds = current
                } else {
                    bounds = Bounds(
                        minimumX: x,
                        minimumY: y,
                        maximumX: x,
                        maximumY: y
                    )
                }
            }
        }
    }
    let resolved = bounds?.arrayExclusive ?? []
    let padding: [Int] =
        resolved.count == 4
        ? [
            resolved[0],
            resolved[1],
            image.width - resolved[2],
            image.height - resolved[3],
        ] : []
    return [
        "nonChromaPixelCount": count,
        "nonChromaBounds": resolved,
        "paddingLTRB": padding,
        "alphaZeroCount": alphaZeroCount,
        "alphaNonOpaqueCount": alphaNonOpaqueCount,
        "hiddenRGBCount": hiddenRGBCount,
        "allPixelsOpaque": alphaNonOpaqueCount == 0,
        "completeBoundsPassed":
            resolved.count == 4
            && resolved[2] - resolved[0] >= 400
            && resolved[3] - resolved[1] >= 260
            && count >= 50_000,
    ]
}

private func vector(_ value: Any?, label: String) throws -> Vector3 {
    guard
        let values = value as? [NSNumber],
        values.count == 3
    else {
        throw IndustrialL3V5SensitivityReviewError.invalid(
            "\(label) must be a three-number vector"
        )
    }
    return Vector3(
        x: values[0].doubleValue,
        y: values[1].doubleValue,
        z: values[2].doubleValue
    )
}

private func projectedPoint(
    _ point: Vector3,
    descriptor: [String: Any]
) throws -> [Double] {
    guard
        let camera = descriptor["camera"] as? [String: Any],
        let scale = (camera["orthographicScale"] as? NSNumber)?.doubleValue,
        let viewport = camera["renderViewportPixels"] as? [NSNumber],
        viewport.count == 2,
        let offset = camera["postProjectionOffsetPixels"] as? [NSNumber],
        offset.count == 2
    else {
        throw IndustrialL3V5SensitivityReviewError.invalid(
            "camera projection contract missing"
        )
    }
    let position = try vector(
        camera["positionWorld"],
        label: "camera.positionWorld"
    )
    let target = try vector(
        camera["targetWorld"],
        label: "camera.targetWorld"
    )
    let forward = try (target - position).normalized()
    let right = try forward.cross(
        Vector3(x: 0, y: 1, z: 0)
    ).normalized()
    let up = try right.cross(forward).normalized()
    let relative = point - target
    let pixelsPerWorld =
        viewport[1].doubleValue / (2 * scale)
    return [
        viewport[0].doubleValue / 2
            + relative.dot(right) * pixelsPerWorld
            + offset[0].doubleValue,
        viewport[1].doubleValue / 2
            - relative.dot(up) * pixelsPerWorld
            + offset[1].doubleValue,
    ]
}

private func appendEnvelope(
    id: String,
    materialID: String,
    dimensions: Any?,
    position: Any?,
    descriptor: [String: Any],
    allowed: Set<String>,
    to result: inout [ProjectedEnvelope]
) throws {
    guard allowed.contains(materialID) else { return }
    let size = try vector(dimensions, label: "\(id).dimensions")
    let center = try vector(position, label: "\(id).positionWorld")
    let half = size * 0.5
    var points: [[Double]] = []
    for x in [-half.x, half.x] {
        for y in [-half.y, half.y] {
            for z in [-half.z, half.z] {
                points.append(
                    try projectedPoint(
                        center + Vector3(x: x, y: y, z: z),
                        descriptor: descriptor
                    )
                )
            }
        }
    }
    let expansion = 4.0
    result.append(
        ProjectedEnvelope(
            materialID: materialID,
            primitiveID: id,
            bounds: [
                Int(floor(points.map { $0[0] }.min()! - expansion)),
                Int(floor(points.map { $0[1] }.min()! - expansion)),
                Int(ceil(points.map { $0[0] }.max()! + expansion)),
                Int(ceil(points.map { $0[1] }.max()! + expansion)),
            ]
        )
    )
}

private func authorizedEnvelopes(
    descriptor: [String: Any],
    allowed: Set<String>
) throws -> [ProjectedEnvelope] {
    guard let building = descriptor["building"] as? [String: Any] else {
        throw IndustrialL3V5SensitivityReviewError.invalid(
            "building descriptor missing"
        )
    }
    var result: [ProjectedEnvelope] = []
    if let materialID = building["foundationMaterialID"] as? String {
        try appendEnvelope(
            id: "foundation",
            materialID: materialID,
            dimensions: building["foundationDimensions"],
            position: building["foundationPositionWorld"],
            descriptor: descriptor,
            allowed: allowed,
            to: &result
        )
    }
    for key in ["massBlocks", "trimBands"] {
        for object in building[key] as? [[String: Any]] ?? [] {
            guard
                let id = object["id"] as? String,
                let materialID = object["materialID"] as? String
            else {
                throw IndustrialL3V5SensitivityReviewError.invalid(
                    "\(key) identity missing"
                )
            }
            try appendEnvelope(
                id: id,
                materialID: materialID,
                dimensions: object["dimensions"],
                position: object["positionWorld"],
                descriptor: descriptor,
                allowed: allowed,
                to: &result
            )
        }
    }
    for roof in building["roofVolumes"] as? [[String: Any]] ?? [] {
        guard
            let id = roof["id"] as? String,
            let dimensions = roof["dimensions"] as? [NSNumber],
            dimensions.count == 3,
            let position = roof["positionWorld"] as? [NSNumber],
            position.count == 3,
            let materialID = roof["materialID"] as? String,
            let trimID = roof["trimMaterialID"] as? String
        else {
            throw IndustrialL3V5SensitivityReviewError.invalid(
                "roof identity missing"
            )
        }
        let width = dimensions[0].doubleValue
        let height = dimensions[1].doubleValue
        let depth = dimensions[2].doubleValue
        let center = position.map(\.doubleValue)
        let slabHeight = min(1.5, max(0.8, height * 0.22))
        let parapetHeight = max(1.8, height - slabHeight)
        let parapetY =
            center[1] + height / 2 - parapetHeight / 2
        try appendEnvelope(
            id: id + "-slab",
            materialID: materialID,
            dimensions: [width, slabHeight, depth],
            position: [
                center[0],
                center[1] - height / 2 + slabHeight / 2,
                center[2],
            ],
            descriptor: descriptor,
            allowed: allowed,
            to: &result
        )
        for (suffix, size, location) in [
            (
                "north",
                [width, parapetHeight, 1.0],
                [center[0], parapetY, center[2] - depth / 2]
            ),
            (
                "south",
                [width, parapetHeight, 1.0],
                [center[0], parapetY, center[2] + depth / 2]
            ),
            (
                "east",
                [1.0, parapetHeight, depth],
                [center[0] + width / 2, parapetY, center[2]]
            ),
            (
                "west",
                [1.0, parapetHeight, depth],
                [center[0] - width / 2, parapetY, center[2]]
            ),
        ] {
            try appendEnvelope(
                id: id + "-parapet-" + suffix,
                materialID: trimID,
                dimensions: size,
                position: location,
                descriptor: descriptor,
                allowed: allowed,
                to: &result
            )
        }
    }
    for object in descriptor["props"] as? [[String: Any]] ?? [] {
        guard
            let id = object["id"] as? String,
            let materialID = object["materialID"] as? String
        else {
            throw IndustrialL3V5SensitivityReviewError.invalid(
                "prop identity missing"
            )
        }
        try appendEnvelope(
            id: id,
            materialID: materialID,
            dimensions: object["dimensions"],
            position: object["positionWorld"],
            descriptor: descriptor,
            allowed: allowed,
            to: &result
        )
    }
    return result
}

private func ownershipProof(
    differences: [PixelDifference],
    envelopes: [ProjectedEnvelope]
) -> [String: Any] {
    let outside = differences.filter { difference in
        !envelopes.contains { envelope in
            difference.x >= envelope.bounds[0]
                && difference.y >= envelope.bounds[1]
                && difference.x < envelope.bounds[2]
                && difference.y < envelope.bounds[3]
        }
    }
    return [
        "method":
            "exact descriptor camera projection of all primitives using changed materials; source bounds expanded four pixels for antialiasing and Lanczos support",
        "authorizedProjectedEnvelopes": envelopes.map {
            [
                "primitiveID": $0.primitiveID,
                "materialID": $0.materialID,
                "boundsExclusive": $0.bounds,
            ]
        },
        "changedPixelCount": differences.count,
        "outsideAuthorizedProjectedEnvelopeCount": outside.count,
        "outsideCoordinates": outside.map { [$0.x, $0.y] },
        "passed": outside.isEmpty,
    ]
}

private func drawScaled(
    source: ImageBuffer,
    sourceBounds: [Int],
    destination: inout [UInt8],
    destinationWidth: Int,
    originX: Int,
    originY: Int,
    outputWidth: Int,
    outputHeight: Int,
    grayscale: Bool
) {
    let sourceWidth = sourceBounds[2] - sourceBounds[0]
    let sourceHeight = sourceBounds[3] - sourceBounds[1]
    for y in 0..<outputHeight {
        let sourceY =
            sourceBounds[1]
            + min(
                sourceHeight - 1,
                Int(Double(y) * Double(sourceHeight) / Double(outputHeight))
            )
        for x in 0..<outputWidth {
            let sourceX =
                sourceBounds[0]
                + min(
                    sourceWidth - 1,
                    Int(
                        Double(x) * Double(sourceWidth)
                            / Double(outputWidth)
                    )
                )
            let sourceIndex = (sourceY * source.width + sourceX) * 4
            let destinationIndex =
                ((originY + y) * destinationWidth + originX + x) * 4
            if grayscale {
                let red = Double(source.rgba[sourceIndex])
                let green = Double(source.rgba[sourceIndex + 1])
                let blue = Double(source.rgba[sourceIndex + 2])
                let resolvedLuma =
                    0.2126 * red + 0.7152 * green + 0.0722 * blue
                let luma = UInt8(
                    min(255, max(0, Int(resolvedLuma)))
                )
                destination[destinationIndex] = luma
                destination[destinationIndex + 1] = luma
                destination[destinationIndex + 2] = luma
            } else {
                destination[destinationIndex] = source.rgba[sourceIndex]
                destination[destinationIndex + 1] =
                    source.rgba[sourceIndex + 1]
                destination[destinationIndex + 2] =
                    source.rgba[sourceIndex + 2]
            }
            destination[destinationIndex + 3] = 255
        }
    }
}

private func writePNG(
    rgba: [UInt8],
    width: Int,
    height: Int,
    url: URL
) throws {
    var storage = rgba
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard
        let image = storage.withUnsafeMutableBytes({ bytes -> CGImage? in
            guard
                let context = CGContext(
                    data: bytes.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo:
                        CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue
                )
            else {
                return nil
            }
            return context.makeImage()
        })
    else {
        throw IndustrialL3V5SensitivityReviewError.invalid(
            "could not create panel image"
        )
    }
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw IndustrialL3V5SensitivityReviewError.invalid(
            "could not create panel destination"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL3V5SensitivityReviewError.invalid(
            "could not finalize panel"
        )
    }
}

private func buildPanel(
    rows: [(RowContract, ImageBuffer, ImageBuffer, [Int])],
    scale: Double,
    grayscale: Bool,
    cropToOccupied: Bool,
    url: URL
) throws {
    let gap = 16
    let margin = 20
    let maximumSourceWidth = rows.map {
        $0.3[2] - $0.3[0]
    }.max() ?? sourceWidth
    let maximumSourceHeight = rows.map {
        $0.3[3] - $0.3[1]
    }.max() ?? sourceHeight
    let outputImageWidth = max(
        1,
        Int(
            Double(cropToOccupied ? maximumSourceWidth : sourceWidth)
                * scale
        )
    )
    let outputImageHeight = max(
        1,
        Int(
            Double(cropToOccupied ? maximumSourceHeight : sourceHeight)
                * scale
        )
    )
    let width = margin * 2 + outputImageWidth * 2 + gap
    let rowHeight = outputImageHeight + gap
    let height = margin * 2 + rowHeight * rows.count - gap
    var panel = [UInt8](repeating: 28, count: width * height * 4)
    for pixelIndex in stride(from: 3, to: panel.count, by: 4) {
        panel[pixelIndex] = 255
    }
    let rowMarkers: [[UInt8]] = [
        [225, 88, 72, 255],
        [76, 168, 215, 255],
        [103, 194, 114, 255],
        [224, 176, 70, 255],
    ]
    for (index, row) in rows.enumerated() {
        let y = margin + index * rowHeight
        let sourceBounds =
            cropToOccupied
            ? row.3 : [0, 0, row.1.width, row.1.height]
        let actualWidth = max(
            1,
            Int(Double(sourceBounds[2] - sourceBounds[0]) * scale)
        )
        let actualHeight = max(
            1,
            Int(Double(sourceBounds[3] - sourceBounds[1]) * scale)
        )
        drawScaled(
            source: row.1,
            sourceBounds: sourceBounds,
            destination: &panel,
            destinationWidth: width,
            originX: margin,
            originY: y,
            outputWidth: actualWidth,
            outputHeight: actualHeight,
            grayscale: grayscale
        )
        drawScaled(
            source: row.2,
            sourceBounds: sourceBounds,
            destination: &panel,
            destinationWidth: width,
            originX: margin + outputImageWidth + gap,
            originY: y,
            outputWidth: actualWidth,
            outputHeight: actualHeight,
            grayscale: grayscale
        )
        for markerY in y..<(y + min(12, outputImageHeight)) {
            for markerX in 0..<12 {
                let destinationIndex =
                    (markerY * width + markerX) * 4
                for channel in 0..<4 {
                    panel[destinationIndex + channel] =
                        rowMarkers[index][channel]
                }
            }
        }
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try writePNG(rgba: panel, width: width, height: height, url: url)
}

private func registrationRecord(
    provenance: [String: Any],
    baseline: [String: Any]
) -> [String: Any] {
    let keys = [
        "groundPivotSource",
        "frontageEdgeSource",
        "frontageSocketSource",
        "doorBaseSource",
        "contactPolygonWorld",
        "southeastShadowVectorSource",
        "renderedNodeBounds",
    ]
    var values: [String: Any] = [:]
    var passed = true
    for key in keys {
        let candidateValue = provenance[key]
        let baselineValue = baseline[key]
        let equal: Bool
        if let candidateValue, let baselineValue {
            equal = NSDictionary(dictionary: ["value": candidateValue])
                .isEqual(to: ["value": baselineValue])
        } else {
            equal = candidateValue == nil && baselineValue == nil
        }
        values[key] = [
            "candidate": candidateValue ?? NSNull(),
            "baseline": baselineValue ?? NSNull(),
            "equal": equal,
        ]
        passed = passed && equal
    }
    values["passed"] = passed
    return values
}

@main
private enum IndustrialL3V5SensitivityReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            ),
            isDirectory: true
        ).standardizedFileURL
        let matrixRoot = URL(
            fileURLWithPath: try argument("--matrix-root", in: arguments),
            isDirectory: true
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try argument("--output-root", in: arguments),
            isDirectory: true
        ).standardizedFileURL
        let rendererBinary = URL(
            fileURLWithPath: try argument(
                "--renderer-binary",
                in: arguments
            )
        ).standardizedFileURL
        let rendererSourceCommit = try argument(
            "--renderer-source-commit",
            in: arguments
        )
        guard
            matrixRoot.path.hasPrefix(repositoryRoot.path + "/"),
            matrixRoot.path.contains(
                "/docs/production/evidence/PLAY-027/industrial-l03/"
            ),
            (
                matrixRoot.path.contains("/diagnostics/")
                    || matrixRoot.path.hasSuffix("/diagnostics")
            ),
            outputRoot.path.hasPrefix(repositoryRoot.path + "/"),
            outputRoot.path.contains(
                "/docs/production/evidence/PLAY-027/industrial-l03/"
            ),
            !FileManager.default.fileExists(atPath: outputRoot.path),
            rendererSourceCommit
                == "26e3a52168a9b2747cc95f202990b08e5c1ac432"
        else {
            throw IndustrialL3V5SensitivityReviewError.invalid(
                "matrix/review roots or renderer source authority invalid"
            )
        }
        let inputManifestURL =
            matrixRoot.appendingPathComponent("inputs/INPUT-MANIFEST.json")
        let inputManifest = try jsonObject(inputManifestURL)
        guard
            inputManifest["authorityCommit"] as? String
                == "78aba5442c675cc8664deaebffa13422ac2100c1",
            inputManifest["sceneKitProcessCount"] as? Int == 0
        else {
            throw IndustrialL3V5SensitivityReviewError.invalid(
                "input manifest authority drifted"
            )
        }
        var rowRecords: [[String: Any]] = []
        var panelRows:
            [(RowContract, ImageBuffer, ImageBuffer, [Int])] = []
        for row in rows {
            guard
                let baselineRawPath = baselineRaw[row.direction],
                let baselineProvenancePath =
                    baselineProvenance[row.direction],
                let expectedBaselineHash =
                    expectedBaselineHashes[row.direction]
            else {
                throw IndustrialL3V5SensitivityReviewError.invalid(
                    "\(row.id) baseline missing"
                )
            }
            let baselineURL =
                repositoryRoot.appendingPathComponent(baselineRawPath)
            guard try sha256(baselineURL) == expectedBaselineHash else {
                throw IndustrialL3V5SensitivityReviewError.invalid(
                    "\(row.id) source-v05 baseline hash drifted"
                )
            }
            let baselineImage = try decodedImage(baselineURL)
            let baselineRecord = try jsonObject(
                repositoryRoot.appendingPathComponent(
                    baselineProvenancePath
                )
            )
            let descriptorURL =
                matrixRoot.appendingPathComponent(
                    "inputs/\(row.id)/scene.json"
                )
            let descriptor = try jsonObject(descriptorURL)
            let envelopes = try authorizedEnvelopes(
                descriptor: descriptor,
                allowed: row.authorizedMaterials
            )
            var rawFileHashes: [String] = []
            var rawPixelHashes: [String] = []
            var prequantizedFileHashes: [String] = []
            var prequantizedPixelHashes: [String] = []
            var runRecords: [[String: Any]] = []
            var runImages: [ImageBuffer] = []
            var runDiffs: [[PixelDifference]] = []
            for run in runs {
                let runRoot = matrixRoot.appendingPathComponent(
                    "renders/\(row.id)/\(run)"
                )
                let rawURL = runRoot.appendingPathComponent("raw.png")
                let prequantizedURL =
                    runRoot.appendingPathComponent("prequantized.png")
                let provenanceURL =
                    runRoot.appendingPathComponent("provenance.json")
                let capabilityURL =
                    runRoot.appendingPathComponent("capability.json")
                guard
                    FileManager.default.fileExists(atPath: rawURL.path),
                    FileManager.default.fileExists(
                        atPath: prequantizedURL.path
                    ),
                    FileManager.default.fileExists(
                        atPath: provenanceURL.path
                    ),
                    FileManager.default.fileExists(
                        atPath: capabilityURL.path
                    )
                else {
                    throw IndustrialL3V5SensitivityReviewError.invalid(
                        "\(row.id)/\(run) output incomplete"
                    )
                }
                let rawImage = try decodedImage(rawURL)
                let prequantizedImage = try decodedImage(prequantizedURL)
                guard
                    rawImage.width == sourceWidth,
                    rawImage.height == sourceHeight,
                    prequantizedImage.width == sourceWidth,
                    prequantizedImage.height == sourceHeight
                else {
                    throw IndustrialL3V5SensitivityReviewError.invalid(
                        "\(row.id)/\(run) dimensions drifted"
                    )
                }
                let provenance = try jsonObject(provenanceURL)
                let rawHash = try sha256(rawURL)
                let rawPixelHash = sha256(Data(rawImage.rgba))
                let prequantizedHash = try sha256(prequantizedURL)
                let prequantizedPixelHash =
                    sha256(Data(prequantizedImage.rgba))
                let baselineDifferences = try differences(
                    reference: baselineImage,
                    candidate: rawImage
                )
                rawFileHashes.append(rawHash)
                rawPixelHashes.append(rawPixelHash)
                prequantizedFileHashes.append(prequantizedHash)
                prequantizedPixelHashes.append(prequantizedPixelHash)
                runImages.append(rawImage)
                runDiffs.append(baselineDifferences)
                runRecords.append([
                    "run": run,
                    "rawFile": rawURL.path.replacingOccurrences(
                        of: repositoryRoot.path + "/",
                        with: ""
                    ),
                    "rawFileSHA256": rawHash,
                    "rawDecodedRGBASHA256": rawPixelHash,
                    "prequantizedFile": prequantizedURL.path
                        .replacingOccurrences(
                            of: repositoryRoot.path + "/",
                            with: ""
                        ),
                    "prequantizedFileSHA256": prequantizedHash,
                    "prequantizedDecodedRGBASHA256":
                        prequantizedPixelHash,
                    "provenanceFile": provenanceURL.path
                        .replacingOccurrences(
                            of: repositoryRoot.path + "/",
                            with: ""
                        ),
                    "provenanceSHA256": try sha256(provenanceURL),
                    "capabilityFile": capabilityURL.path
                        .replacingOccurrences(
                            of: repositoryRoot.path + "/",
                            with: ""
                        ),
                    "capabilitySHA256": try sha256(capabilityURL),
                    "occupancy": occupancy(rawImage),
                    "registration": registrationRecord(
                        provenance: provenance,
                        baseline: baselineRecord
                    ),
                    "governedNeighborhoods": try row.coordinates.map {
                        coordinate in
                        [
                            "coordinate": coordinate,
                            "prequantized": try neighborhood(
                                prequantizedImage,
                                coordinate: coordinate,
                                radius: 2
                            ),
                            "final": try neighborhood(
                                rawImage,
                                coordinate: coordinate,
                                radius: 2
                            ),
                        ] as [String: Any]
                    },
                    "sourceV05WholeImageDifference":
                        differenceRecord(baselineDifferences),
                    "changedRegionOwnership": ownershipProof(
                        differences: baselineDifferences,
                        envelopes: envelopes
                    ),
                    "rendererSourceCommit":
                        provenance["rendererSourceCommit"] ?? NSNull(),
                    "sceneDescriptorSHA256":
                        provenance["sceneDescriptorSHA256"] ?? NSNull(),
                    "materialLibrarySHA256":
                        provenance["materialLibrarySHA256"] ?? NSNull(),
                    "productionSelected": false,
                ])
            }
            let rawFileIdentity = Set(rawFileHashes).count == 1
            let rawPixelIdentity = Set(rawPixelHashes).count == 1
            let pairwise = [
                ("run-a-to-run-b", 0, 1),
                ("run-a-to-run-c", 0, 2),
                ("run-b-to-run-c", 1, 2),
            ].map { label, left, right -> [String: Any] in
                let delta = try! differences(
                    reference: runImages[left],
                    candidate: runImages[right]
                )
                return [
                    "comparison": label,
                    "fileIdentity":
                        rawFileHashes[left] == rawFileHashes[right],
                    "decodedPixelIdentity":
                        rawPixelHashes[left] == rawPixelHashes[right],
                    "difference": differenceRecord(delta),
                ]
            }
            let baselineBounds =
                occupancy(baselineImage)["nonChromaBounds"] as? [Int]
                ?? [0, 0, sourceWidth, sourceHeight]
            let candidateBounds =
                occupancy(runImages[0])["nonChromaBounds"] as? [Int]
                ?? baselineBounds
            let unionBounds = [
                min(baselineBounds[0], candidateBounds[0]),
                min(baselineBounds[1], candidateBounds[1]),
                max(baselineBounds[2], candidateBounds[2]),
                max(baselineBounds[3], candidateBounds[3]),
            ]
            panelRows.append(
                (row, baselineImage, runImages[0], unionBounds)
            )
            let passed = rawFileIdentity && rawPixelIdentity
            rowRecords.append([
                "row": row.id,
                "direction": row.direction,
                "authorizedChangedMaterials":
                    row.authorizedMaterials.sorted(),
                "runCount": runs.count,
                "rawFileHashes": rawFileHashes,
                "rawDecodedRGBAHashes": rawPixelHashes,
                "prequantizedFileHashes": prequantizedFileHashes,
                "prequantizedDecodedRGBAHashes":
                    prequantizedPixelHashes,
                "rawFileIdentity": rawFileIdentity,
                "rawDecodedPixelIdentity": rawPixelIdentity,
                "prequantizedFileIdentity":
                    Set(prequantizedFileHashes).count == 1,
                "prequantizedDecodedPixelIdentity":
                    Set(prequantizedPixelHashes).count == 1,
                "pairwise": pairwise,
                "runs": runRecords,
                "repeatDisposition":
                    passed ? "REPEAT_PASS" : "REPEAT_FAIL",
                "passed": passed,
            ])
        }
        try buildPanel(
            rows: panelRows,
            scale: 1,
            grayscale: false,
            cropToOccupied: true,
            url: outputRoot.appendingPathComponent(
                "SOURCE-COLOR-COMPARISON.png"
            )
        )
        try buildPanel(
            rows: panelRows,
            scale: nativeScale,
            grayscale: false,
            cropToOccupied: false,
            url: outputRoot.appendingPathComponent(
                "NATIVE-2X-COLOR-COMPARISON.png"
            )
        )
        try buildPanel(
            rows: panelRows,
            scale: compactScale,
            grayscale: false,
            cropToOccupied: false,
            url: outputRoot.appendingPathComponent(
                "COMPACT-COLOR-COMPARISON.png"
            )
        )
        try buildPanel(
            rows: panelRows,
            scale: nativeScale,
            grayscale: true,
            cropToOccupied: false,
            url: outputRoot.appendingPathComponent(
                "NATIVE-2X-GRAYSCALE-COMPARISON.png"
            )
        )
        let allRegistrationPassed = rowRecords.allSatisfy { row in
            guard let runRecords = row["runs"] as? [[String: Any]] else {
                return false
            }
            return runRecords.allSatisfy {
                ($0["registration"] as? [String: Any])?["passed"] as? Bool
                    == true
            }
        }
        let allOwnershipPassed = rowRecords.allSatisfy { row in
            guard let runRecords = row["runs"] as? [[String: Any]] else {
                return false
            }
            return runRecords.allSatisfy {
                ($0["changedRegionOwnership"] as? [String: Any])?[
                    "passed"
                ] as? Bool == true
            }
        }
        let report: [String: Any] = [
            "task": "PLAY-027",
            "authorityCommit":
                "78aba5442c675cc8664deaebffa13422ac2100c1",
            "attributionCheckpoint":
                "a235546ef0a7ddf31cc2e78d16dfba62f08f82fe",
            "rendererSourceCommit": rendererSourceCommit,
            "rendererBinarySHA256": try sha256(rendererBinary),
            "inputManifestFile":
                inputManifestURL.path.replacingOccurrences(
                    of: repositoryRoot.path + "/",
                    with: ""
                ),
            "inputManifestSHA256": try sha256(inputManifestURL),
            "sceneKitProcessCount": 12,
            "rawProcessCount": 12,
            "normalizerProcessCount": 0,
            "rows": rowRecords,
            "registrationSocketFrontageStructuralInvariancePassed":
                allRegistrationPassed,
            "changedRegionOwnershipPassed": allOwnershipPassed,
            "panelContract": [
                "rowOrder": rows.map(\.id),
                "columnOrder":
                    ["exact-source-v05-run-a", "diagnostic-run-a"],
                "rowMarkerColorsRGBA": [
                    [225, 88, 72, 255],
                    [76, 168, 215, 255],
                    [103, 194, 114, 255],
                    [224, 176, 70, 255],
                ],
                "sourcePanel":
                    "SOURCE-COLOR-COMPARISON.png",
                "nativeColorPanel":
                    "NATIVE-2X-COLOR-COMPARISON.png",
                "compactColorPanel":
                    "COMPACT-COLOR-COMPARISON.png",
                "nativeGrayscalePanel":
                    "NATIVE-2X-GRAYSCALE-COMPARISON.png",
            ],
            "matrixDisposition":
                "DIAGNOSTIC_ONLY_NO_SOURCE_SELECTION",
            "sourceAuthority": false,
            "productionSelected": false,
        ]
        let manifestURL =
            outputRoot.appendingPathComponent("MATRIX-MANIFEST.json")
        try write(try jsonData(report), to: manifestURL)
        let panelNames = [
            "SOURCE-COLOR-COMPARISON.png",
            "NATIVE-2X-COLOR-COMPARISON.png",
            "COMPACT-COLOR-COMPARISON.png",
            "NATIVE-2X-GRAYSCALE-COMPARISON.png",
        ]
        let inventory: [String: Any] = [
            "manifestSHA256": try sha256(manifestURL),
            "panels": try panelNames.map { name in
                [
                    "file": name,
                    "sha256": try sha256(
                        outputRoot.appendingPathComponent(name)
                    ),
                    "decodedRGBASHA256": sha256(
                        Data(
                            try decodedImage(
                                outputRoot.appendingPathComponent(name)
                            ).rgba
                        )
                    ),
                ]
            },
        ]
        try write(
            try jsonData(inventory),
            to: outputRoot.appendingPathComponent("REVIEW-INVENTORY.json")
        )
        let dispositions = rowRecords.map {
            "\($0["row"]!)=\($0["repeatDisposition"]!)"
        }.joined(separator: " ")
        print("PASS built diagnostic matrix review \(dispositions)")
    }
}
