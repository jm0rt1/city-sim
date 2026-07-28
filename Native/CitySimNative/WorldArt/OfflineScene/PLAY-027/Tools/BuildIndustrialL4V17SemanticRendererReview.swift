import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private enum ReviewError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l4-v17-semantic-review --repository-root <path> --output-directory <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct Raster {
    let image: CGImage
    let rgba: [UInt8]
    let fileSHA256: String
    let decodedSHA256: String
}

private struct PixelBounds {
    var minimumX = Int.max
    var minimumY = Int.max
    var maximumX = Int.min
    var maximumY = Int.min

    mutating func include(x: Int, y: Int) {
        minimumX = min(minimumX, x)
        minimumY = min(minimumY, y)
        maximumX = max(maximumX, x)
        maximumY = max(maximumY, y)
    }

    var json: Any {
        minimumX == Int.max
            ? NSNull()
            : [minimumX, minimumY, maximumX, maximumY]
    }
}

private struct SemanticGroup {
    let name: String
    let rgba: [UInt8]
}

private let groups = [
    SemanticGroup(name: "portal-jamb-south", rgba: [16, 16, 240, 255]),
    SemanticGroup(name: "portal-jamb-north", rgba: [240, 208, 16, 255]),
    SemanticGroup(name: "portal-header", rgba: [240, 16, 16, 255]),
    SemanticGroup(name: "portal-inset-void", rgba: [16, 240, 48, 255]),
    SemanticGroup(name: "hall", rgba: [144, 80, 48, 255]),
    SemanticGroup(name: "gantry", rgba: [48, 80, 112, 255]),
    SemanticGroup(name: "crucible-occluder", rgba: [208, 112, 16, 255]),
    SemanticGroup(name: "other", rgba: [80, 80, 80, 255]),
]

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        index + 1 < CommandLine.arguments.count
    else {
        throw ReviewError.arguments
    }
    return CommandLine.arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func decode(_ url: URL) throws -> Raster {
    let data = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        )
    else {
        throw ReviewError.invalid("could not decode \(url.path)")
    }
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try rgba.withUnsafeMutableBytes { bytes in
        guard let context = CGContext(
            data: bytes.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw ReviewError.invalid("could not allocate decoder")
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return Raster(
        image: image,
        rgba: rgba,
        fileSHA256: digest(data),
        decodedSHA256: digest(Data(rgba))
    )
}

private func image(rgba: [UInt8], width: Int, height: Int) throws -> CGImage {
    guard
        let provider = CGDataProvider(data: Data(rgba) as CFData),
        let result = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Big.union(
                CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    else {
        throw ReviewError.invalid("could not create image")
    }
    return result
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
        throw ReviewError.invalid("could not create \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw ReviewError.invalid("could not finalize \(url.path)")
    }
}

private func scale(
    _ source: CGImage,
    width: Int,
    height: Int,
    interpolation: CGInterpolationQuality
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
        throw ReviewError.invalid("could not allocate scaler")
    }
    context.interpolationQuality = interpolation
    context.setFillColor(CGColor(gray: 0.12, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let result = context.makeImage() else {
        throw ReviewError.invalid("could not create scaled image")
    }
    return result
}

private func grayscale(_ source: CGImage) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: source.width,
        height: source.height,
        bitsPerComponent: 8,
        bytesPerRow: source.width,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else {
        throw ReviewError.invalid("could not allocate grayscale context")
    }
    context.draw(
        source,
        in: CGRect(x: 0, y: 0, width: source.width, height: source.height)
    )
    guard let result = context.makeImage() else {
        throw ReviewError.invalid("could not create grayscale image")
    }
    return result
}

private func tile(_ images: [CGImage], columns: Int) throws -> CGImage {
    guard let first = images.first else {
        throw ReviewError.invalid("cannot tile empty image set")
    }
    let rows = (images.count + columns - 1) / columns
    guard let context = CGContext(
        data: nil,
        width: first.width * columns,
        height: first.height * rows,
        bitsPerComponent: 8,
        bytesPerRow: first.width * columns * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw ReviewError.invalid("could not allocate contact sheet")
    }
    context.setFillColor(CGColor(gray: 0.08, alpha: 1))
    context.fill(
        CGRect(
            x: 0,
            y: 0,
            width: first.width * columns,
            height: first.height * rows
        )
    )
    for (index, item) in images.enumerated() {
        let column = index % columns
        let row = rows - 1 - index / columns
        context.draw(
            item,
            in: CGRect(
                x: column * first.width,
                y: row * first.height,
                width: first.width,
                height: first.height
            )
        )
    }
    guard let result = context.makeImage() else {
        throw ReviewError.invalid("could not create contact sheet")
    }
    return result
}

private func exactGroup(_ rgba: [UInt8], offset: Int) -> Int? {
    guard rgba[offset + 3] > 0 else {
        return nil
    }
    let red = Int(rgba[offset])
    let green = Int(rgba[offset + 1])
    let blue = Int(rgba[offset + 2])
    let chromaDistance =
        (red - 255) * (red - 255)
        + green * green
        + (blue - 255) * (blue - 255)
    var bestIndex = 0
    var bestDistance = Int.max
    for (index, group) in groups.enumerated() {
        let redDelta = red - Int(group.rgba[0])
        let greenDelta = green - Int(group.rgba[1])
        let blueDelta = blue - Int(group.rgba[2])
        let distance =
            redDelta * redDelta
            + greenDelta * greenDelta
            + blueDelta * blueDelta
        if distance < bestDistance {
            bestDistance = distance
            bestIndex = index
        }
    }
    return bestDistance < chromaDistance ? bestIndex : nil
}

private func maskRGBA(
    raster: Raster,
    acceptedGroups: Set<Int>,
    muted: Bool = false
) -> [UInt8] {
    var output = [UInt8](repeating: 0, count: raster.rgba.count)
    for pixel in 0..<(raster.image.width * raster.image.height) {
        let offset = pixel * 4
        if let group = exactGroup(raster.rgba, offset: offset),
           acceptedGroups.contains(group) {
            output[offset] = muted ? 176 : groups[group].rgba[0]
            output[offset + 1] = muted ? 176 : groups[group].rgba[1]
            output[offset + 2] = muted ? 176 : groups[group].rgba[2]
            output[offset + 3] = 255
        }
    }
    return output
}

private func groupMetrics(_ raster: Raster, index: Int) -> [String: Any] {
    var count = 0
    var bounds = PixelBounds()
    var locations = Set<Int>()
    for y in 0..<raster.image.height {
        for x in 0..<raster.image.width {
            let pixel = y * raster.image.width + x
            if exactGroup(raster.rgba, offset: pixel * 4) == index {
                count += 1
                bounds.include(x: x, y: y)
                locations.insert(pixel)
            }
        }
    }
    var components = 0
    var remaining = locations
    while let seed = remaining.first {
        components += 1
        remaining.remove(seed)
        var queue = [seed]
        var cursor = 0
        while cursor < queue.count {
            let pixel = queue[cursor]
            cursor += 1
            let x = pixel % raster.image.width
            let y = pixel / raster.image.width
            let neighbors = [
                (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1),
            ]
            for (nextX, nextY) in neighbors
            where nextX >= 0 && nextX < raster.image.width
                && nextY >= 0 && nextY < raster.image.height {
                let next = nextY * raster.image.width + nextX
                if remaining.remove(next) != nil {
                    queue.append(next)
                }
            }
        }
    }
    return [
        "visiblePixelCount": count,
        "bounds": bounds.json,
        "connectedComponentCount": components,
        "fullyOccluded": count == 0,
    ]
}

private func adjacency(_ raster: Raster) -> [[String: Any]] {
    var counts: [String: Int] = [:]
    for y in 0..<raster.image.height {
        for x in 0..<raster.image.width {
            let pixel = y * raster.image.width + x
            guard let lhs = exactGroup(raster.rgba, offset: pixel * 4) else {
                continue
            }
            for (nextX, nextY) in [(x + 1, y), (x, y + 1)]
            where nextX < raster.image.width && nextY < raster.image.height {
                let next = nextY * raster.image.width + nextX
                guard
                    let rhs = exactGroup(raster.rgba, offset: next * 4),
                    lhs != rhs
                else {
                    continue
                }
                let names = [groups[lhs].name, groups[rhs].name].sorted()
                counts["\(names[0])|\(names[1])", default: 0] += 1
            }
        }
    }
    return counts.keys.sorted().map { key in
        let names = key.split(separator: "|").map(String.init)
        return [
            "groups": names,
            "sharedFourNeighborEdges": counts[key] ?? 0,
        ]
    }
}

private func medianLuma(
    actual: Raster,
    semantic: Raster,
    groupIndex: Int
) -> Int? {
    guard
        actual.image.width == semantic.image.width,
        actual.image.height == semantic.image.height
    else {
        return nil
    }
    var values: [Int] = []
    for pixel in 0..<(semantic.image.width * semantic.image.height) {
        let offset = pixel * 4
        guard exactGroup(semantic.rgba, offset: offset) == groupIndex else {
            continue
        }
        let red = Int(actual.rgba[offset])
        let green = Int(actual.rgba[offset + 1])
        let blue = Int(actual.rgba[offset + 2])
        values.append((54 * red + 183 * green + 19 * blue + 128) / 256)
    }
    guard !values.isEmpty else {
        return nil
    }
    values.sort()
    return values[values.count / 2]
}

private func provenanceManifestSHA(_ url: URL) throws -> String {
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    guard
        let root = object as? [String: Any],
        let semantic = root["diagnosticSemanticVisibility"] as? [String: Any],
        let value = semantic["nodeManifestSHA256"] as? String
    else {
        throw ReviewError.invalid("missing semantic node manifest in \(url.path)")
    }
    return value
}

@main
private enum BuildReview {
    static func main() throws {
        let repositoryRoot = URL(fileURLWithPath: try argument("--repository-root"))
        let outputDirectory = URL(fileURLWithPath: try argument("--output-directory"))
        guard !FileManager.default.fileExists(atPath: outputDirectory.path) else {
            throw ReviewError.invalid("output directory must be absent")
        }
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let evidence = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
                + "semantic-visibility-renderer-v1/diagnostics"
        )
        let runAURL = evidence.appendingPathComponent("run-a/semantic.png")
        let runBURL = evidence.appendingPathComponent("run-b/semantic.png")
        let provenanceA = evidence.appendingPathComponent("run-a/provenance.json")
        let provenanceB = evidence.appendingPathComponent("run-b/provenance.json")
        let actualURL = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
                + "matte-canonicalization-v2-r2-v02/V17-CANONICAL-TRANSPARENT.png"
        )
        let v16URL = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
                + "crucible-gantry-v16-north-raw-probe/diagnostics/north/run-a/raw.png"
        )
        let runA = try decode(runAURL)
        let runB = try decode(runBURL)
        let actual = try decode(actualURL)
        let v16 = try decode(v16URL)
        guard
            runA.image.width == runB.image.width,
            runA.image.height == runB.image.height
        else {
            throw ReviewError.invalid("run dimensions differ")
        }

        var differingPixels = 0
        var differingChannels = 0
        var maximumChannelDelta = 0
        var diffBounds = PixelBounds()
        var firstDifference: [String: Any]?
        var semanticTransitions: [String: Int] = [:]
        for y in 0..<runA.image.height {
            for x in 0..<runA.image.width {
                let offset = (y * runA.image.width + x) * 4
                var pixelDiffers = false
                for channel in 0..<4 {
                    let lhs = Int(runA.rgba[offset + channel])
                    let rhs = Int(runB.rgba[offset + channel])
                    if lhs != rhs {
                        differingChannels += 1
                        pixelDiffers = true
                        maximumChannelDelta = max(maximumChannelDelta, abs(lhs - rhs))
                    }
                }
                if pixelDiffers {
                    differingPixels += 1
                    diffBounds.include(x: x, y: y)
                    let groupA = exactGroup(runA.rgba, offset: offset)
                        .map { groups[$0].name } ?? "chroma"
                    let groupB = exactGroup(runB.rgba, offset: offset)
                        .map { groups[$0].name } ?? "chroma"
                    semanticTransitions["\(groupA)->\(groupB)", default: 0] += 1
                    if firstDifference == nil {
                        firstDifference = [
                            "coordinate": [x, y],
                            "runA": Array(runA.rgba[offset..<(offset + 4)]),
                            "runB": Array(runB.rgba[offset..<(offset + 4)]),
                        ]
                    }
                }
            }
        }

        var componentMetrics: [String: Any] = [:]
        var componentMetricsRunB: [String: Any] = [:]
        var lumaMetrics: [String: Any] = [:]
        for (index, group) in groups.enumerated() {
            componentMetrics[group.name] = groupMetrics(runA, index: index)
            componentMetricsRunB[group.name] = groupMetrics(runB, index: index)
            lumaMetrics[group.name] =
                medianLuma(actual: actual, semantic: runA, groupIndex: index)
                ?? NSNull()
        }

        let portalIndices = Set(0...3)
        let occluderIndices = Set(4..<groups.count)
        let portalRGBA = maskRGBA(raster: runA, acceptedGroups: portalIndices)
        let occluderRGBA = maskRGBA(
            raster: runA,
            acceptedGroups: occluderIndices,
            muted: true
        )
        let portalImage = try image(
            rgba: portalRGBA,
            width: runA.image.width,
            height: runA.image.height
        )
        let occluderImage = try image(
            rgba: occluderRGBA,
            width: runA.image.width,
            height: runA.image.height
        )
        try writePNG(portalImage, to: outputDirectory.appendingPathComponent("PORTAL-ONLY-SOURCE.png"))
        try writePNG(occluderImage, to: outputDirectory.appendingPathComponent("OCCLUDERS-SOURCE.png"))

        let scales = [
            ("SOURCE", 1536, 1024),
            ("NATIVE-2X", 384, 256),
            ("LITERAL-192", 192, 128),
        ]
        var componentMetricsByScale: [String: Any] = [:]
        for (name, width, height) in scales {
            let color = try scale(runA.image, width: width, height: height, interpolation: .none)
            let colorURL = outputDirectory.appendingPathComponent(
                "\(name)-SEMANTIC-COLOR.png"
            )
            try writePNG(
                color,
                to: colorURL
            )
            try writePNG(
                try grayscale(color),
                to: outputDirectory.appendingPathComponent("\(name)-SEMANTIC-GRAYSCALE.png")
            )
            let scaledRaster = try decode(colorURL)
            var scaledMetrics: [String: Any] = [:]
            for (index, group) in groups.enumerated() {
                scaledMetrics[group.name] = groupMetrics(
                    scaledRaster,
                    index: index
                )
            }
            componentMetricsByScale[name] = scaledMetrics
        }
        try writePNG(
            try scale(portalImage, width: 192, height: 128, interpolation: .none),
            to: outputDirectory.appendingPathComponent("PORTAL-ONLY-LITERAL-192.png")
        )
        try writePNG(
            try scale(occluderImage, width: 192, height: 128, interpolation: .none),
            to: outputDirectory.appendingPathComponent("OCCLUDERS-LITERAL-192.png")
        )

        let v16Compact = try scale(v16.image, width: 192, height: 128, interpolation: .high)
        let v17Compact = try scale(actual.image, width: 192, height: 128, interpolation: .high)
        try writePNG(
            try tile([v16Compact, v17Compact], columns: 2),
            to: outputDirectory.appendingPathComponent("V16-V17-LITERAL-192-COLOR.png")
        )
        try writePNG(
            try tile(
                [try grayscale(v16Compact), try grayscale(v17Compact)],
                columns: 2
            ),
            to: outputDirectory.appendingPathComponent("V16-V17-LITERAL-192-GRAYSCALE.png")
        )

        let manifestA = try provenanceManifestSHA(provenanceA)
        let manifestB = try provenanceManifestSHA(provenanceB)
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "disposition": "RETURN_SEMANTIC_REPEAT_GATE",
            "diagnosticOnly": true,
            "sourceAuthority": false,
            "productionSelected": false,
            "sceneKitMetalProcessCount": 2,
            "authoritativeRawProcessCount": 0,
            "normalizerProcessCount": 0,
            "runs": [
                "runA": [
                    "fileSHA256": runA.fileSHA256,
                    "decodedRGBASHA256": runA.decodedSHA256,
                    "nodeManifestSHA256": manifestA,
                ],
                "runB": [
                    "fileSHA256": runB.fileSHA256,
                    "decodedRGBASHA256": runB.decodedSHA256,
                    "nodeManifestSHA256": manifestB,
                ],
            ],
            "repeatIdentity": [
                "fileIdentity": runA.fileSHA256 == runB.fileSHA256,
                "decodedRGBAIdentity": runA.decodedSHA256 == runB.decodedSHA256,
                "nodeManifestIdentity": manifestA == manifestB,
                "differingPixelCount": differingPixels,
                "differingChannelCount": differingChannels,
                "maximumChannelDelta": maximumChannelDelta,
                "differenceBounds": diffBounds.json,
                "firstDifference": firstDifference ?? NSNull(),
                "semanticTransitions": semanticTransitions.keys.sorted().map {
                    [
                        "transition": $0,
                        "pixelCount": semanticTransitions[$0] ?? 0,
                    ]
                },
            ],
            "componentVisibilityRunA": componentMetrics,
            "componentVisibilityRunB": componentMetricsRunB,
            "componentVisibilityByScaleRunA": componentMetricsByScale,
            "componentMedianLumaAgainstCanonicalV17": lumaMetrics,
            "componentEncoding": [
                "visibleOverlapPixelCount": 0,
                "basis":
                    "nearest governed semantic ID after the unchanged quantizer; chroma wins ties and is excluded",
                "adjacency": adjacency(runA),
                "occlusionBasis":
                    "a semantic node is fully occluded only when its governed group has zero exact-ID output pixels",
            ],
            "stopReason":
                "A/B semantic rasters are not byte or decoded-pixel identical; modeling is not authorized.",
        ]
        let reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try reportData.write(
            to: outputDirectory.appendingPathComponent("REVIEW.json"),
            options: .atomic
        )
        print("RETURN semantic repeat identity: \(differingPixels) pixels differ")
    }
}
