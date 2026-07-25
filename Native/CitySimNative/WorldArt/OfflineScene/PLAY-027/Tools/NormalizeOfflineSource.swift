import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum NormalizeOfflineSourceError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: normalize-offline-source --asset-id <id> --input <png> --output-dir <path> --record <json> --object-width <pixels> --reference-width <source-pixels>"
        case let .invalid(message):
            return message
        }
    }
}

struct RGBAImage {
    let width: Int
    let height: Int
    var pixels: [UInt8]
}

func normalizeArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw NormalizeOfflineSourceError.arguments
    }
    return arguments[index + 1]
}

func normalizeSHA256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map {
        String(format: "%02x", $0)
    }.joined()
}

func decodeRGBA(_ url: URL) throws -> RGBAImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw NormalizeOfflineSourceError.invalid(
            "could not decode \(url.path)"
        )
    }
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    try pixels.withUnsafeMutableBytes { storage in
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
            throw NormalizeOfflineSourceError.invalid(
                "could not allocate RGBA decode context"
            )
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
    }
    return RGBAImage(width: width, height: height, pixels: pixels)
}

func makeCGImage(_ image: RGBAImage) throws -> CGImage {
    var pixels = image.pixels
    return try pixels.withUnsafeMutableBytes { storage in
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
        ),
            let output = context.makeImage()
        else {
            throw NormalizeOfflineSourceError.invalid(
                "could not create RGBA image"
            )
        }
        return output
    }
}

func isOfflineMatte(_ pixels: [UInt8], _ offset: Int) -> Bool {
    let red = Int(pixels[offset])
    let green = Int(pixels[offset + 1])
    let blue = Int(pixels[offset + 2])
    let alpha = Int(pixels[offset + 3])
    return alpha > 0
        && red >= 180
        && blue >= 150
        && green <= 110
        && red + blue >= green * 4
}

func removeOfflineMatte(_ source: RGBAImage) -> RGBAImage {
    var image = source
    let count = image.width * image.height
    var queued = [Bool](repeating: false, count: count)
    var queue: [Int] = []
    queue.reserveCapacity(count / 2)

    func enqueue(_ x: Int, _ y: Int) {
        let index = y * image.width + x
        guard !queued[index] else { return }
        queued[index] = true
        queue.append(index)
    }

    for x in 0..<image.width {
        enqueue(x, 0)
        enqueue(x, image.height - 1)
    }
    for y in 0..<image.height {
        enqueue(0, y)
        enqueue(image.width - 1, y)
    }

    var cursor = 0
    while cursor < queue.count {
        let index = queue[cursor]
        cursor += 1
        let offset = index * 4
        guard isOfflineMatte(image.pixels, offset) else { continue }
        image.pixels[offset] = 0
        image.pixels[offset + 1] = 0
        image.pixels[offset + 2] = 0
        image.pixels[offset + 3] = 0
        let x = index % image.width
        let y = index / image.width
        if x > 0 { enqueue(x - 1, y) }
        if x + 1 < image.width { enqueue(x + 1, y) }
        if y > 0 { enqueue(x, y - 1) }
        if y + 1 < image.height { enqueue(x, y + 1) }
    }

    for offset in stride(from: 0, to: image.pixels.count, by: 4) {
        if image.pixels[offset + 3] == 0 {
            image.pixels[offset] = 0
            image.pixels[offset + 1] = 0
            image.pixels[offset + 2] = 0
            continue
        }
        let red = Int(image.pixels[offset])
        let green = Int(image.pixels[offset + 1])
        let blue = Int(image.pixels[offset + 2])
        if
            Double(red) > Double(green) * 1.35,
            Double(blue) > Double(green) * 1.25
        {
            let spill = min(red, blue) - green
            image.pixels[offset] = UInt8(max(green, red - spill))
            image.pixels[offset + 2] = UInt8(max(green, blue - spill))
        }
    }
    return image
}

func alphaBounds(_ image: RGBAImage) throws -> (Int, Int, Int, Int) {
    var minimumX = image.width
    var minimumY = image.height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<image.height {
        for x in 0..<image.width {
            let alpha = image.pixels[(y * image.width + x) * 4 + 3]
            guard alpha > 0 else { continue }
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    guard maximumX >= minimumX, maximumY >= minimumY else {
        throw NormalizeOfflineSourceError.invalid(
            "normalization rejected: source contains no non-matte pixels"
        )
    }
    return (minimumX, minimumY, maximumX + 1, maximumY + 1)
}

func cropRGBA(
    _ image: RGBAImage,
    bounds: (Int, Int, Int, Int)
) -> RGBAImage {
    let width = bounds.2 - bounds.0
    let height = bounds.3 - bounds.1
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0..<height {
        let sourceOffset = ((bounds.1 + y) * image.width + bounds.0) * 4
        let targetOffset = y * width * 4
        pixels.withUnsafeMutableBytes { target in
            image.pixels.withUnsafeBytes { source in
                target.baseAddress!
                    .advanced(by: targetOffset)
                    .copyMemory(
                        from: source.baseAddress!.advanced(by: sourceOffset),
                        byteCount: width * 4
                    )
            }
        }
    }
    return RGBAImage(width: width, height: height, pixels: pixels)
}

func resizeRGBA(
    _ image: RGBAImage,
    width: Int,
    height: Int
) throws -> RGBAImage {
    let source = try makeCGImage(image)
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    try pixels.withUnsafeMutableBytes { storage in
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
            throw NormalizeOfflineSourceError.invalid(
                "could not allocate resize context"
            )
        }
        context.interpolationQuality = .high
        context.draw(
            source,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
    }
    for offset in stride(from: 0, to: pixels.count, by: 4)
    where pixels[offset + 3] == 0 {
        pixels[offset] = 0
        pixels[offset + 1] = 0
        pixels[offset + 2] = 0
    }
    return RGBAImage(width: width, height: height, pixels: pixels)
}

func registeredOfflineSource(
    _ cleaned: RGBAImage,
    objectWidth: Int,
    referenceWidth: Int
) throws -> (RGBAImage, [String: Any], [Int]) {
    let bounds = try alphaBounds(cleaned)
    let subject = cropRGBA(cleaned, bounds: bounds)
    let uniformScale = Double(objectWidth) / Double(referenceWidth)
    var width = Int((Double(subject.width) * uniformScale).rounded())
    var height = Int(
        (Double(subject.height) * uniformScale).rounded()
    )
    if height > 790 {
        height = 790
        width = Int(
            (Double(subject.width) * Double(height) / Double(subject.height))
                .rounded()
        )
    }
    let resized = try resizeRGBA(subject, width: width, height: height)
    let originX = 768 - width / 2
    let originY = 896 - height
    guard
        originX > 2,
        originY > 2,
        originX + width < 1534,
        originY + height < 1022
    else {
        throw NormalizeOfflineSourceError.invalid(
            "normalization rejected: inadequate transparent padding"
        )
    }
    var canvas = RGBAImage(
        width: 1536,
        height: 1024,
        pixels: [UInt8](repeating: 0, count: 1536 * 1024 * 4)
    )
    for y in 0..<height {
        let sourceOffset = y * width * 4
        let targetOffset = ((originY + y) * canvas.width + originX) * 4
        canvas.pixels.withUnsafeMutableBytes { target in
            resized.pixels.withUnsafeBytes { source in
                target.baseAddress!
                    .advanced(by: targetOffset)
                    .copyMemory(
                        from: source.baseAddress!.advanced(by: sourceOffset),
                        byteCount: width * 4
                    )
            }
        }
    }
    let registration: [String: Any] = [
        "mode": "uniform-object-registration",
        "source_bbox": [bounds.0, bounds.1, bounds.2, bounds.3],
        "target_size": [width, height],
        "target_ground_pivot": [768, 896],
        "target_origin": [originX, originY],
        "uniform_scale": uniformScale,
        "reference_subject_width": referenceWidth,
    ]
    return (canvas, registration, [originX, originY, originX + width, 896])
}

func writeNormalizePNG(_ image: RGBAImage, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw NormalizeOfflineSourceError.invalid(
            "could not create \(url.path)"
        )
    }
    CGImageDestinationAddImage(
        destination,
        try makeCGImage(image),
        [
            kCGImagePropertyPNGDictionary: [
                kCGImagePropertyPNGInterlaceType: 0,
            ],
            kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
            kCGImagePropertyDepth: 8,
        ] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
        throw NormalizeOfflineSourceError.invalid(
            "could not finalize \(url.path)"
        )
    }
}

@main
enum NormalizeOfflineSourceMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let assetID = try normalizeArgument("--asset-id", in: arguments)
        let input = URL(
            fileURLWithPath: try normalizeArgument("--input", in: arguments)
        ).standardizedFileURL
        let outputDirectory = URL(
            fileURLWithPath:
                try normalizeArgument("--output-dir", in: arguments)
        ).standardizedFileURL
        let record = URL(
            fileURLWithPath: try normalizeArgument("--record", in: arguments)
        ).standardizedFileURL
        guard
            let objectWidth = Int(
                try normalizeArgument("--object-width", in: arguments)
            ),
            objectWidth > 0,
            let referenceWidth = Int(
                try normalizeArgument("--reference-width", in: arguments)
            ),
            referenceWidth > 0
        else {
            throw NormalizeOfflineSourceError.arguments
        }
        let decoded = try decodeRGBA(input)
        guard decoded.width == 1536, decoded.height == 1024 else {
            throw NormalizeOfflineSourceError.invalid(
                "source canvas must be 1536 x 1024"
            )
        }
        let cleaned = removeOfflineMatte(decoded)
        let (registered, registration, sourceBounds) =
            try registeredOfflineSource(
                cleaned,
                objectWidth: objectWidth,
                referenceWidth: referenceWidth
            )
        let lods = [
            ("block", 1024, 683),
            ("neighborhood", 512, 342),
            ("city", 256, 171),
        ]
        var outputs: [[String: Any]] = []
        for (lod, width, height) in lods {
            let image = try resizeRGBA(
                registered,
                width: width,
                height: height
            )
            let url = outputDirectory.appendingPathComponent(
                "generated_v4_\(assetID)_\(lod).png"
            )
            try writeNormalizePNG(image, to: url)
            outputs.append([
                "lod": lod,
                "file": url.lastPathComponent,
                "pixels": [width, height],
                "sha256": try normalizeSHA256(url),
            ])
        }
        let payload: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "tool": "PLAY-027 macOS-native offline source normalizer",
            "asset_id": assetID,
            "source_file": input.path,
            "source_sha256": try normalizeSHA256(input),
            "normalization":
                "8-bit sRGB premultiplied RGBA; border-connected #ff00ff removal; edge despill; zero hidden RGB; deterministic Core Graphics high-quality LOD exports",
            "registration": registration,
            "source_bbox": sourceBounds,
            "ground_pivot_source": [768, 896],
            "object_width": objectWidth,
            "reference_subject_width": referenceWidth,
            "outputs": outputs,
            "productionSelected": false,
        ]
        try FileManager.default.createDirectory(
            at: record.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var recordData = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        recordData.append(10)
        try recordData.write(to: record)
    }
}
