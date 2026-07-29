import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ReviewFailure: Error {
    case invalid(String)
}

struct Raster {
    let width: Int
    let height: Int
    let rgba: [UInt8]
}

func argument(_ name: String) throws -> String {
    let arguments = CommandLine.arguments
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw ReviewFailure.invalid("missing \(name)")
    }
    return arguments[index + 1]
}

func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func sha256(_ url: URL) throws -> String {
    try sha256(Data(contentsOf: url))
}

func decode(_ url: URL) throws -> Raster {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw ReviewFailure.invalid("could not decode \(url.path)")
    }
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let rendered = bytes.withUnsafeMutableBytes { storage -> Bool in
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
            return false
        }
        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
        return true
    }
    guard rendered else {
        throw ReviewFailure.invalid("could not canonicalize \(url.path)")
    }
    return Raster(width: image.width, height: image.height, rgba: bytes)
}

func image(_ raster: Raster) throws -> CGImage {
    guard
        let provider = CGDataProvider(data: Data(raster.rgba) as CFData),
        let value = CGImage(
            width: raster.width,
            height: raster.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: raster.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(
                rawValue:
                    CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    else {
        throw ReviewFailure.invalid("could not construct image")
    }
    return value
}

func writePNG(_ raster: Raster, _ url: URL) throws {
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw ReviewFailure.invalid("could not create \(url.path)")
    }
    CGImageDestinationAddImage(destination, try image(raster), nil)
    guard CGImageDestinationFinalize(destination) else {
        throw ReviewFailure.invalid("could not write \(url.path)")
    }
}

func composite(_ input: Raster) -> Raster {
    let background = [48, 52, 50]
    var output = [UInt8](repeating: 0, count: input.rgba.count)
    for offset in stride(from: 0, to: input.rgba.count, by: 4) {
        let isFlatChroma =
            input.rgba[offset] >= 180
            && input.rgba[offset + 1] <= 110
            && input.rgba[offset + 2] >= 150
            && Int(input.rgba[offset]) + Int(input.rgba[offset + 2])
                >= Int(input.rgba[offset + 1]) * 4
        let alpha = isFlatChroma ? 0 : Int(input.rgba[offset + 3])
        let inverse = 255 - alpha
        for channel in 0..<3 {
            let source = isFlatChroma ? 0 : Int(input.rgba[offset + channel])
            output[offset + channel] = UInt8(
                min(
                    255,
                    source + background[channel] * inverse / 255
                )
            )
        }
        output[offset + 3] = 255
    }
    return Raster(width: input.width, height: input.height, rgba: output)
}

func grayscale(_ input: Raster) -> Raster {
    var bytes = input.rgba
    for offset in stride(from: 0, to: bytes.count, by: 4) {
        let weighted =
            54 * Int(bytes[offset])
            + 183 * Int(bytes[offset + 1])
            + 19 * Int(bytes[offset + 2])
        let value = UInt8(min(255, weighted / 256))
        bytes[offset] = value
        bytes[offset + 1] = value
        bytes[offset + 2] = value
    }
    return Raster(width: input.width, height: input.height, rgba: bytes)
}

func resized(_ input: Raster, width: Int, height: Int) throws -> Raster {
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let source = try image(input)
    let rendered = bytes.withUnsafeMutableBytes { storage -> Bool in
        guard let context = CGContext(
            data: storage.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return false
        }
        context.interpolationQuality = .high
        context.draw(
            source,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
        return true
    }
    guard rendered else {
        throw ReviewFailure.invalid("resize failed")
    }
    return Raster(width: width, height: height, rgba: bytes)
}

func silhouette(_ input: Raster) -> Raster {
    var bytes = [UInt8](repeating: 0, count: input.rgba.count)
    for offset in stride(from: 0, to: bytes.count, by: 4) {
        let occupied = input.rgba[offset + 3] > 0
        let value: UInt8 = occupied ? 235 : 24
        bytes[offset] = value
        bytes[offset + 1] = value
        bytes[offset + 2] = value
        bytes[offset + 3] = 255
    }
    return Raster(width: input.width, height: input.height, rgba: bytes)
}

func registrationOverlay(_ input: Raster) -> Raster {
    var bytes = input.rgba
    let footprint = [(96, 80), (128, 96), (96, 112), (64, 96)]
    let edges = Array(zip(footprint, footprint.dropFirst() + [footprint[0]]))
    func set(_ x: Int, _ y: Int, _ color: [UInt8]) {
        guard x >= 0, x < input.width, y >= 0, y < input.height else { return }
        let offset = (y * input.width + x) * 4
        bytes.replaceSubrange(offset..<(offset + 4), with: color)
    }
    for (start, end) in edges {
        let count = max(abs(end.0 - start.0), abs(end.1 - start.1))
        for step in 0...count {
            set(
                start.0 + (end.0 - start.0) * step / count,
                start.1 + (end.1 - start.1) * step / count,
                [80, 236, 140, 255]
            )
        }
    }
    for (point, color) in [
        ((96, 112), [UInt8(255), 222, 70, 255]),
        ((112, 88), [UInt8(70), 220, 255, 255]),
    ] {
        for y in (point.1 - 2)...(point.1 + 2) {
            for x in (point.0 - 2)...(point.0 + 2) {
                set(x, y, color)
            }
        }
    }
    return Raster(width: input.width, height: input.height, rgba: bytes)
}

func sheet(_ rasters: [Raster]) throws -> Raster {
    guard
        let first = rasters.first,
        rasters.allSatisfy({ $0.width == first.width && $0.height == first.height })
    else {
        throw ReviewFailure.invalid("sheet cell mismatch")
    }
    let width = first.width * rasters.count
    var bytes = [UInt8](repeating: 0, count: width * first.height * 4)
    for (index, raster) in rasters.enumerated() {
        for y in 0..<first.height {
            let source = y * first.width * 4
            let target = (y * width + index * first.width) * 4
            bytes[target..<(target + first.width * 4)] =
                raster.rgba[source..<(source + first.width * 4)]
        }
    }
    return Raster(width: width, height: first.height, rgba: bytes)
}

func metrics(_ raster: Raster) -> [String: Any] {
    var minimumX = raster.width
    var minimumY = raster.height
    var maximumX = -1
    var maximumY = -1
    var visible = 0
    var hiddenRGB = 0
    var exactChroma = 0
    var nearChroma = 0
    var lumas: [Int] = []
    for y in 0..<raster.height {
        for x in 0..<raster.width {
            let offset = (y * raster.width + x) * 4
            let red = Int(raster.rgba[offset])
            let green = Int(raster.rgba[offset + 1])
            let blue = Int(raster.rgba[offset + 2])
            let alpha = Int(raster.rgba[offset + 3])
            if alpha == 0 {
                if red != 0 || green != 0 || blue != 0 { hiddenRGB += 1 }
                continue
            }
            visible += 1
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
            if red >= 250 && green <= 4 && blue >= 250 { exactChroma += 1 }
            if
                red >= 180 && blue >= 150 && green <= 110
                    && red + blue >= green * 4
            {
                nearChroma += 1
            }
            lumas.append((54 * red + 183 * green + 19 * blue) / 256)
        }
    }
    lumas.sort()
    let median = lumas.isEmpty ? 0 : lumas[lumas.count / 2]
    let p95 = lumas.isEmpty ? 0 : lumas[min(lumas.count - 1, lumas.count * 95 / 100)]
    let bounds = visible == 0
        ? [0, 0, 0, 0]
        : [minimumX, minimumY, maximumX + 1, maximumY + 1]
    let horizontalPadding = min(
        minimumX,
        raster.width - maximumX - 1
    )
    let verticalPadding = min(
        minimumY,
        raster.height - maximumY - 1
    )
    let padding = visible == 0 ? 0 : min(horizontalPadding, verticalPadding)
    return [
        "pixels": [raster.width, raster.height],
        "decodedRGBASHA256": sha256(Data(raster.rgba)),
        "alphaBounds": bounds,
        "visiblePixelCount": visible,
        "minimumPaddingPixels": padding,
        "hiddenRGBPixelCount": hiddenRGB,
        "exactChromaAtNonzeroAlpha": exactChroma,
        "nearChromaAtNonzeroAlpha": nearChroma,
        "medianVisibleLuma": median,
        "p95VisibleLuma": p95,
    ]
}

@main
enum BuildNorthV07ProcessAReview {
    static func main() throws {
        let root = URL(fileURLWithPath: try argument("--repository-root"))
            .standardizedFileURL
        let rawURL = URL(fileURLWithPath: try argument("--raw"))
            .standardizedFileURL
        let normalized = URL(fileURLWithPath: try argument("--normalized"))
            .standardizedFileURL
        let output = URL(fileURLWithPath: try argument("--output"))
            .standardizedFileURL
        try FileManager.default.createDirectory(
            at: output,
            withIntermediateDirectories: true
        )
        let raw = try decode(rawURL)
        let blockURL = normalized.appendingPathComponent(
            "generated_v4_industrial_l04_north_v07_block.png"
        )
        let neighborhoodURL = normalized.appendingPathComponent(
            "generated_v4_industrial_l04_north_v07_neighborhood.png"
        )
        let cityURL = normalized.appendingPathComponent(
            "generated_v4_industrial_l04_north_v07_city.png"
        )
        let block = try decode(blockURL)
        let neighborhood = try decode(neighborhoodURL)
        let city = try decode(cityURL)
        let sourceColor = composite(raw)
        let sourceGray = grayscale(sourceColor)
        let nativeColor = try resized(sourceColor, width: 384, height: 256)
        let nativeGray = grayscale(nativeColor)
        let compactColor = try resized(sourceColor, width: 192, height: 128)
        let compactGray = grayscale(compactColor)
        let compactRaw = try resized(raw, width: 192, height: 128)
        let acceptedL3 = try decode(
            root.appendingPathComponent(
                "docs/production/evidence/PLAY-027/industrial-l03/l03/"
                    + "source-v06-raw-review-v01/diagnostics/raw-repeat/"
                    + "north/run-a/raw.png"
            )
        )
        let l3Compact = try resized(
            composite(acceptedL3),
            width: 192,
            height: 128
        )
        let lodCells = try [
            resized(composite(block), width: 192, height: 128),
            resized(composite(neighborhood), width: 192, height: 128),
            resized(composite(city), width: 192, height: 128),
        ]
        let outputs: [(String, Raster)] = [
            ("SOURCE-COLOR.png", sourceColor),
            ("SOURCE-GRAYSCALE.png", sourceGray),
            ("NATIVE-2X-COLOR.png", nativeColor),
            ("NATIVE-2X-GRAYSCALE.png", nativeGray),
            ("EXACT-192X128-COLOR.png", compactColor),
            ("EXACT-192X128-GRAYSCALE.png", compactGray),
            ("ALPHA-SILHOUETTE.png", silhouette(compactRaw)),
            ("REGISTRATION-CONTACT.png", registrationOverlay(compactColor)),
            ("LOD-COLOR.png", try sheet(lodCells)),
            ("LOD-GRAYSCALE.png", try sheet(lodCells.map(grayscale))),
            (
                "ACCEPTED-L3-VS-V07-COLOR.png",
                try sheet([l3Compact, compactColor])
            ),
            (
                "ACCEPTED-L3-VS-V07-GRAYSCALE.png",
                try sheet([grayscale(l3Compact), compactGray])
            ),
        ]
        var hashes: [String: String] = [:]
        for (name, raster) in outputs {
            let url = output.appendingPathComponent(name)
            try writePNG(raster, url)
            hashes[name] = try sha256(url)
        }
        let rawMetrics = metrics(raw)
        let normalizedMetrics: [String: Any] = [
            "block": metrics(block),
            "neighborhood": metrics(neighborhood),
            "city": metrics(city),
        ]
        let rawPassed =
            (rawMetrics["pixels"] as? [Int]) == [1536, 1024]
            && (rawMetrics["hiddenRGBPixelCount"] as? Int) == 0
            && (rawMetrics["exactChromaAtNonzeroAlpha"] as? Int) == 0
            && (rawMetrics["nearChromaAtNonzeroAlpha"] as? Int) == 0
            && (rawMetrics["minimumPaddingPixels"] as? Int ?? 0) >= 4
        let normalizedPassed = normalizedMetrics.values.allSatisfy { value in
            guard let record = value as? [String: Any] else { return false }
            return (record["hiddenRGBPixelCount"] as? Int) == 0
                && (record["exactChromaAtNonzeroAlpha"] as? Int) == 0
                && (record["nearChromaAtNonzeroAlpha"] as? Int) == 0
                && (record["minimumPaddingPixels"] as? Int ?? 0) >= 2
        }
        let manifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "processID": "A",
            "rawFile": rawURL.path,
            "rawFileSHA256": try sha256(rawURL),
            "raw": rawMetrics,
            "normalized": normalizedMetrics,
            "panels": hashes,
            "rawTechnicalPassed": rawPassed,
            "normalizedTechnicalPassed": normalizedPassed,
            "registrationProof": [
                "groundPivotSource": [768, 896],
                "frontageSocketSource": [896, 704],
                "orientationTransform": "none",
            ],
            "sourceAuthority": false,
            "productionSelected": false,
            "disposition": rawPassed && normalizedPassed
                ? "PENDING_INDEPENDENT_APPEARANCE_REVIEW"
                : "REJECTED_TECHNICAL_GATE",
        ]
        let data = try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try (data + Data([0x0A])).write(
            to: output.appendingPathComponent("REVIEW-MANIFEST.json")
        )
        guard rawPassed && normalizedPassed else {
            throw ReviewFailure.invalid("technical review gate failed")
        }
    }
}
