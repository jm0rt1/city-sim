import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ReviewError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-blender-calibration-review --repository-root <path> --output-directory <path>"
        case let .invalid(message):
            return message
        }
    }
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
        throw ReviewError.arguments
    }
    return arguments[index + 1]
}

func decode(_ url: URL) throws -> Raster {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw ReviewError.invalid("could not decode \(url.path)")
    }
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let created = bytes.withUnsafeMutableBytes { storage -> Bool in
        guard let context = CGContext(
            data: storage.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: colorSpace,
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
    guard created else {
        throw ReviewError.invalid("could not canonicalize \(url.path)")
    }
    return Raster(width: image.width, height: image.height, rgba: bytes)
}

func neutralComposite(_ input: Raster) -> Raster {
    var output = [UInt8](repeating: 0, count: input.rgba.count)
    let neutral = [UInt8(52), UInt8(56), UInt8(54)]
    for offset in stride(from: 0, to: input.rgba.count, by: 4) {
        var red = input.rgba[offset]
        var green = input.rgba[offset + 1]
        var blue = input.rgba[offset + 2]
        var alpha = input.rgba[offset + 3]
        // Retained flat-chroma references can decode one code value below
        // literal magenta through ColorSync. This affects review copies only.
        if red >= 250 && green <= 4 && blue >= 250 {
            alpha = 0
            red = 0
            green = 0
            blue = 0
        }
        let inverse = 255 - Int(alpha)
        output[offset] = UInt8(
            min(255, Int(red) + Int(neutral[0]) * inverse / 255)
        )
        output[offset + 1] = UInt8(
            min(255, Int(green) + Int(neutral[1]) * inverse / 255)
        )
        output[offset + 2] = UInt8(
            min(255, Int(blue) + Int(neutral[2]) * inverse / 255)
        )
        output[offset + 3] = 255
    }
    return Raster(width: input.width, height: input.height, rgba: output)
}

func grayscale(_ input: Raster) -> Raster {
    var output = input.rgba
    for offset in stride(from: 0, to: output.count, by: 4) {
        let red = 54 * Int(output[offset])
        let green = 183 * Int(output[offset + 1])
        let blue = 19 * Int(output[offset + 2])
        let luma = UInt8(min(255, (red + green + blue) / 256))
        output[offset] = luma
        output[offset + 1] = luma
        output[offset + 2] = luma
    }
    return Raster(width: input.width, height: input.height, rgba: output)
}

func cgImage(_ raster: Raster) throws -> CGImage {
    let data = Data(raster.rgba) as CFData
    guard
        let provider = CGDataProvider(data: data),
        let image = CGImage(
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
        throw ReviewError.invalid("could not create CGImage")
    }
    return image
}

func resized(_ input: Raster, width: Int, height: Int) throws -> Raster {
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let source = try cgImage(input)
    let created = bytes.withUnsafeMutableBytes { storage -> Bool in
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
    guard created else {
        throw ReviewError.invalid("could not resize raster")
    }
    return Raster(width: width, height: height, rgba: bytes)
}

func sheet(_ rasters: [Raster]) throws -> Raster {
    guard
        let first = rasters.first,
        rasters.allSatisfy({
            $0.width == first.width && $0.height == first.height
        })
    else {
        throw ReviewError.invalid("sheet cell dimensions differ")
    }
    let width = first.width * rasters.count
    var bytes = [UInt8](repeating: 0, count: width * first.height * 4)
    for (cell, raster) in rasters.enumerated() {
        for y in 0..<first.height {
            let sourceStart = y * first.width * 4
            let destinationStart = (y * width + cell * first.width) * 4
            bytes[destinationStart..<(destinationStart + first.width * 4)] =
                raster.rgba[sourceStart..<(sourceStart + first.width * 4)]
        }
    }
    return Raster(width: width, height: first.height, rgba: bytes)
}

func registrationOverlay(_ input: Raster) -> Raster {
    var output = input.rgba
    let points = [
        (96, 80), (128, 96), (96, 112), (64, 96),
        (96, 112), (112, 88),
    ]
    for (index, point) in points.enumerated() {
        let color: [UInt8] = index == 4
            ? [255, 224, 64, 255]
            : index == 5
                ? [64, 224, 255, 255]
                : [96, 255, 128, 255]
        for y in max(0, point.1 - 1)...min(input.height - 1, point.1 + 1) {
            for x in max(0, point.0 - 1)...min(input.width - 1, point.0 + 1) {
                let offset = (y * input.width + x) * 4
                output[offset..<(offset + 4)] = color[0..<4]
            }
        }
    }
    return Raster(width: input.width, height: input.height, rgba: output)
}

func occupancy(_ input: Raster) -> Raster {
    var output = [UInt8](repeating: 0, count: input.rgba.count)
    for offset in stride(from: 0, to: input.rgba.count, by: 4) {
        let alpha = input.rgba[offset + 3]
        let value = alpha == 0 ? UInt8(0) : UInt8(255)
        output[offset] = value
        output[offset + 1] = value
        output[offset + 2] = value
        output[offset + 3] = 255
    }
    return Raster(width: input.width, height: input.height, rgba: output)
}

func writePNG(_ raster: Raster, to url: URL) throws {
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
    CGImageDestinationAddImage(destination, try cgImage(raster), nil)
    guard CGImageDestinationFinalize(destination) else {
        throw ReviewError.invalid("could not write \(url.path)")
    }
}

@main
enum BuildBlenderCalibrationReview {
    static func main() throws {
        let root = URL(
            fileURLWithPath: try argument("--repository-root")
        ).standardizedFileURL
        let output = URL(
            fileURLWithPath: try argument("--output-directory")
        ).standardizedFileURL
        try FileManager.default.createDirectory(
            at: output,
            withIntermediateDirectories: true
        )
        let base =
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
        let candidate = try decode(
            root.appendingPathComponent(
                base
                    + "blender-v18-north-calibration-v03/"
                    + "diagnostics/run-a/raw.png"
            )
        )
        let semantic = try neutralComposite(
            decode(
                root.appendingPathComponent(
                    base
                        + "blender-v18-north-calibration-v03/"
                        + "diagnostics/run-a/semantic.png"
                )
            )
        )
        let sceneKitSemantic = try neutralComposite(
            decode(
                root.appendingPathComponent(
                    base
                        + "duplicate-foundation-repair-r3-v01/"
                        + "diagnostics/run-a/semantic.png"
                )
            )
        )
        let acceptedL3 = try neutralComposite(
            decode(
                root.appendingPathComponent(
                    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
                        + "source-v06-raw-review-v01/diagnostics/"
                        + "raw-repeat/north/run-a/raw.png"
                )
            )
        )
        let color = neutralComposite(candidate)
        let gray = grayscale(color)
        let native = try resized(color, width: 384, height: 256)
        let nativeGray = grayscale(native)
        let compact = try resized(color, width: 192, height: 128)
        let compactGray = grayscale(compact)
        try writePNG(color, to: output.appendingPathComponent("SOURCE-COLOR.png"))
        try writePNG(
            gray,
            to: output.appendingPathComponent("SOURCE-GRAYSCALE.png")
        )
        try writePNG(
            native,
            to: output.appendingPathComponent("NATIVE-2X-COLOR.png")
        )
        try writePNG(
            nativeGray,
            to: output.appendingPathComponent("NATIVE-2X-GRAYSCALE.png")
        )
        try writePNG(
            compact,
            to: output.appendingPathComponent("EXACT-192X128-COLOR.png")
        )
        try writePNG(
            compactGray,
            to: output.appendingPathComponent("EXACT-192X128-GRAYSCALE.png")
        )
        try writePNG(
            registrationOverlay(compact),
            to: output.appendingPathComponent("REGISTRATION-CONTACT.png")
        )
        try writePNG(
            occupancy(candidate),
            to: output.appendingPathComponent("ALPHA-OCCUPANCY.png")
        )
        let semanticCells = try [sceneKitSemantic, semantic].map {
            try resized($0, width: 384, height: 256)
        }
        try writePNG(
            try sheet(semanticCells),
            to: output.appendingPathComponent(
                "V18-SCENEKIT-VS-BLENDER-SEMANTIC.png"
            )
        )
        let l3Compact = try resized(acceptedL3, width: 192, height: 128)
        try writePNG(
            try sheet([l3Compact, compact]),
            to: output.appendingPathComponent(
                "ACCEPTED-L3-VS-BLENDER-COLOR.png"
            )
        )
        try writePNG(
            try sheet([grayscale(l3Compact), compactGray]),
            to: output.appendingPathComponent(
                "ACCEPTED-L3-VS-BLENDER-GRAYSCALE.png"
            )
        )
    }
}
