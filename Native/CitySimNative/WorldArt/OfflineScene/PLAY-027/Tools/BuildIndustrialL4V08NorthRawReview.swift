import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum L4NorthRawReviewError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l4-v08-north-raw-review --repository-root <path> --output-directory <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct Raster {
    let url: URL
    let image: CGImage
    let rgba: [UInt8]
    let fileSHA256: String
    let decodedRGBASHA256: String
}

private struct PixelBounds {
    let minimumX: Int
    let minimumY: Int
    let maximumX: Int
    let maximumY: Int

    var width: Int { maximumX - minimumX + 1 }
    var height: Int { maximumY - minimumY + 1 }
    var array: [Int] {
        [minimumX, minimumY, maximumX, maximumY]
    }

    var halfOpenArray: [Int] {
        [minimumX, minimumY, maximumX + 1, maximumY + 1]
    }
}

private struct SemanticTarget {
    let id: String
    let expected: PixelBounds
    let kind: String
    let minimumCompactWidth: Double
}

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw L4NorthRawReviewError.arguments
    }
    return arguments[index + 1]
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
        ),
        image.width == 1536,
        image.height == 1024
    else {
        throw L4NorthRawReviewError.invalid(
            "expected a 1536x1024 PNG at \(url.path)"
        )
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
            throw L4NorthRawReviewError.invalid("could not allocate RGBA decoder")
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return Raster(
        url: url,
        image: image,
        rgba: rgba,
        fileSHA256: digest(data),
        decodedRGBASHA256: digest(Data(rgba))
    )
}

private func makeImage(
    rgba: [UInt8],
    width: Int,
    height: Int
) throws -> CGImage {
    let data = Data(rgba)
    guard
        let provider = CGDataProvider(data: data as CFData),
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
        throw L4NorthRawReviewError.invalid("could not create RGBA image")
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
        throw L4NorthRawReviewError.invalid("could not create \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw L4NorthRawReviewError.invalid("could not finalize \(url.path)")
    }
}

private func isExactChroma(_ rgba: [UInt8], _ offset: Int) -> Bool {
    rgba[offset] == 255 && rgba[offset + 1] == 0 && rgba[offset + 2] == 255
}

private func visibleBounds(_ rgba: [UInt8], width: Int, height: Int) -> PixelBounds? {
    var minimumX = width
    var minimumY = height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            if isExactChroma(rgba, offset) { continue }
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    guard maximumX >= minimumX, maximumY >= minimumY else { return nil }
    return PixelBounds(
        minimumX: minimumX,
        minimumY: minimumY,
        maximumX: maximumX,
        maximumY: maximumY
    )
}

private func maskedRGBA(_ source: [UInt8], grayscale: Bool) -> [UInt8] {
    var result = source
    for offset in stride(from: 0, to: result.count, by: 4) {
        if isExactChroma(source, offset) {
            result[offset] = 0
            result[offset + 1] = 0
            result[offset + 2] = 0
            result[offset + 3] = 0
        } else if grayscale {
            let red = 0.2126 * Double(source[offset])
            let green = 0.7152 * Double(source[offset + 1])
            let blue = 0.0722 * Double(source[offset + 2])
            let integer = min(255, max(0, Int(red + green + blue)))
            let value = UInt8(integer)
            result[offset] = value
            result[offset + 1] = value
            result[offset + 2] = value
        }
    }
    return result
}

private func occupancyRGBA(_ source: [UInt8]) -> [UInt8] {
    var result = [UInt8](repeating: 0, count: source.count)
    for offset in stride(from: 0, to: result.count, by: 4) {
        let occupied = !isExactChroma(source, offset)
        let value: UInt8 = occupied ? 255 : 0
        result[offset] = value
        result[offset + 1] = value
        result[offset + 2] = value
        result[offset + 3] = 255
    }
    return result
}

private func neutralComposite(
    source: CGImage,
    width: Int,
    height: Int
) throws -> CGImage {
    guard
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        )
    else {
        throw L4NorthRawReviewError.invalid("could not allocate review canvas")
    }
    context.setFillColor(
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [0.22, 0.24, 0.25, 1]
        )!
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .high
    context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let image = context.makeImage() else {
        throw L4NorthRawReviewError.invalid("could not finish review canvas")
    }
    return image
}

private func scaled(
    _ source: CGImage,
    width: Int,
    height: Int
) throws -> CGImage {
    guard
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        )
    else {
        throw L4NorthRawReviewError.invalid("could not allocate scale canvas")
    }
    context.interpolationQuality = .high
    context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let image = context.makeImage() else {
        throw L4NorthRawReviewError.invalid("could not finish scaled image")
    }
    return image
}

private func cropped(
    _ source: CGImage,
    bounds: PixelBounds,
    padding: Int
) throws -> CGImage {
    let x = max(0, bounds.minimumX - padding)
    let y = max(0, bounds.minimumY - padding)
    let maximumX = min(source.width - 1, bounds.maximumX + padding)
    let maximumY = min(source.height - 1, bounds.maximumY + padding)
    guard
        let image = source.cropping(
            to: CGRect(
                x: x,
                y: y,
                width: maximumX - x + 1,
                height: maximumY - y + 1
            )
        )
    else {
        throw L4NorthRawReviewError.invalid("could not crop occupied pixels")
    }
    return image
}

private func overlay(
    source: CGImage,
    semanticTargets: [SemanticTarget],
    includeSemantics: Bool
) throws -> CGImage {
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: CGFloat(source.height) - y)
    }
    func rectangle(_ bounds: PixelBounds) -> CGRect {
        CGRect(
            x: bounds.minimumX,
            y: source.height - bounds.maximumY - 1,
            width: bounds.width,
            height: bounds.height
        )
    }
    guard
        let context = CGContext(
            data: nil,
            width: source.width,
            height: source.height,
            bitsPerComponent: 8,
            bytesPerRow: source.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        )
    else {
        throw L4NorthRawReviewError.invalid("could not allocate overlay")
    }
    context.draw(
        source,
        in: CGRect(x: 0, y: 0, width: source.width, height: source.height)
    )
    context.setLineWidth(3)
    context.setStrokeColor(red: 0.18, green: 0.92, blue: 0.88, alpha: 1)
    let footprint = [
        point(768, 640),
        point(1024, 768),
        point(768, 896),
        point(512, 768),
    ]
    context.beginPath()
    context.move(to: footprint[0])
    footprint.dropFirst().forEach { context.addLine(to: $0) }
    context.closePath()
    context.strokePath()
    context.setFillColor(red: 1, green: 0.72, blue: 0.18, alpha: 1)
    let pivot = point(768, 896)
    context.fillEllipse(
        in: CGRect(x: pivot.x - 6, y: pivot.y - 6, width: 12, height: 12)
    )
    context.setFillColor(red: 0.2, green: 1, blue: 0.32, alpha: 1)
    let socket = point(896, 704)
    context.fillEllipse(
        in: CGRect(x: socket.x - 6, y: socket.y - 6, width: 12, height: 12)
    )
    context.setStrokeColor(red: 0.2, green: 1, blue: 0.32, alpha: 1)
    context.setLineWidth(4)
    context.move(to: point(768, 640))
    context.addLine(to: point(1024, 768))
    context.strokePath()
    context.setFillColor(red: 1, green: 0.35, blue: 0.2, alpha: 1)
    let doorA = point(802.3, 645.9)
    let doorB = point(825.1, 657.4)
    context.fillEllipse(
        in: CGRect(x: doorA.x - 6, y: doorA.y - 6, width: 12, height: 12)
    )
    context.fillEllipse(
        in: CGRect(x: doorB.x - 6, y: doorB.y - 6, width: 12, height: 12)
    )
    if includeSemantics {
        let colors: [[CGFloat]] = [
            [1, 0.2, 0.2, 1],
            [1, 0.7, 0.1, 1],
            [0.2, 0.7, 1, 1],
            [0.8, 0.3, 1, 1],
        ]
        for (index, target) in semanticTargets.enumerated() {
            let color = colors[index]
            context.setStrokeColor(
                red: color[0],
                green: color[1],
                blue: color[2],
                alpha: color[3]
            )
            context.setLineWidth(4)
            context.stroke(rectangle(target.expected))
        }
    }
    guard let image = context.makeImage() else {
        throw L4NorthRawReviewError.invalid("could not finish overlay")
    }
    return image
}

private func pixelMatches(
    rgba: [UInt8],
    offset: Int,
    kind: String
) -> Bool {
    guard rgba[offset + 3] >= 128 else { return false }
    if isExactChroma(rgba, offset) { return false }
    let red = Int(rgba[offset])
    let green = Int(rgba[offset + 1])
    let blue = Int(rgba[offset + 2])
    if kind == "freight" {
        return red <= 80 && green <= 80 && blue <= 80
    }
    return green >= 96 && blue >= 96 && green - red >= 16 && blue - red >= 16
}

private func decodedRGBA(_ image: CGImage) throws -> [UInt8] {
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
            throw L4NorthRawReviewError.invalid(
                "could not allocate panel decoder"
            )
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return rgba
}

private func compactTarget(_ target: SemanticTarget) -> SemanticTarget {
    SemanticTarget(
        id: target.id,
        expected: PixelBounds(
            minimumX: target.expected.minimumX / 8,
            minimumY: target.expected.minimumY / 8,
            maximumX: (target.expected.maximumX + 7) / 8,
            maximumY: (target.expected.maximumY + 7) / 8
        ),
        kind: target.kind,
        minimumCompactWidth: target.minimumCompactWidth
    )
}

private func matchingBounds(
    rgba: [UInt8],
    imageWidth: Int,
    target: SemanticTarget
) -> (PixelBounds?, Int) {
    var minimumX = target.expected.maximumX + 1
    var minimumY = target.expected.maximumY + 1
    var maximumX = -1
    var maximumY = -1
    var count = 0
    for y in target.expected.minimumY...target.expected.maximumY {
        for x in target.expected.minimumX...target.expected.maximumX {
            let offset = (y * imageWidth + x) * 4
            if pixelMatches(rgba: rgba, offset: offset, kind: target.kind) {
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
                count += 1
            }
        }
    }
    guard maximumX >= minimumX, maximumY >= minimumY else { return (nil, 0) }
    return (
        PixelBounds(
            minimumX: minimumX,
            minimumY: minimumY,
            maximumX: maximumX,
            maximumY: maximumY
        ),
        count
    )
}

private func jsonArray(_ value: Any?) -> [Double]? {
    (value as? [NSNumber])?.map(\.doubleValue)
}

@main
enum BuildIndustrialL4V08NorthRawReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try argument("--repository-root", in: arguments)
        ).standardizedFileURL
        let outputDirectory = URL(
            fileURLWithPath: try argument("--output-directory", in: arguments)
        ).standardizedFileURL
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let rawRoot = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
                + "turbine-v08-north-raw-v02/diagnostics/raw-repeat/north"
        )
        let runNames = ["run-a", "run-b", "run-c"]
        let rasters = try runNames.map {
            try decode(
                rawRoot.appendingPathComponent($0).appendingPathComponent(
                    "raw.png"
                )
            )
        }
        guard
            rasters.dropFirst().allSatisfy({
                $0.fileSHA256 == rasters[0].fileSHA256
                    && $0.decodedRGBASHA256 == rasters[0].decodedRGBASHA256
                    && $0.rgba == rasters[0].rgba
            })
        else {
            throw L4NorthRawReviewError.invalid("raw triplet identity failed")
        }
        let raster = rasters[0]
        guard
            let occupied = visibleBounds(
                raster.rgba,
                width: raster.image.width,
                height: raster.image.height
            )
        else {
            throw L4NorthRawReviewError.invalid("raw contains no occupied pixels")
        }
        var alphaZero = 0
        var alphaNonzero = 0
        var hiddenRGB = 0
        var exactChroma = 0
        var nearChroma = 0
        var occupiedCount = 0
        var lumaValues: [Int] = []
        for offset in stride(from: 0, to: raster.rgba.count, by: 4) {
            let red = Int(raster.rgba[offset])
            let green = Int(raster.rgba[offset + 1])
            let blue = Int(raster.rgba[offset + 2])
            let alpha = Int(raster.rgba[offset + 3])
            if alpha == 0 {
                alphaZero += 1
                if red != 0 || green != 0 || blue != 0 { hiddenRGB += 1 }
            } else {
                alphaNonzero += 1
            }
            if red == 255 && green == 0 && blue == 255 {
                exactChroma += 1
                continue
            }
            if red >= 240 && blue >= 240 && green <= 32 {
                nearChroma += 1
            }
            occupiedCount += 1
            lumaValues.append(
                Int(
                    0.2126 * Double(red)
                        + 0.7152 * Double(green)
                        + 0.0722 * Double(blue)
                )
            )
        }
        lumaValues.sort()
        func percentile(_ fraction: Double) -> Int {
            lumaValues[
                min(
                    lumaValues.count - 1,
                    Int(Double(lumaValues.count - 1) * fraction)
                )
            ]
        }
        let targets = [
            SemanticTarget(
                id: "freight-1",
                expected: PixelBounds(
                    minimumX: 906,
                    minimumY: 708,
                    maximumX: 976,
                    maximumY: 806
                ),
                kind: "freight",
                minimumCompactWidth: 8
            ),
            SemanticTarget(
                id: "freight-2",
                expected: PixelBounds(
                    minimumX: 808,
                    minimumY: 725,
                    maximumX: 878,
                    maximumY: 823
                ),
                kind: "freight",
                minimumCompactWidth: 8
            ),
            SemanticTarget(
                id: "freight-3",
                expected: PixelBounds(
                    minimumX: 709,
                    minimumY: 742,
                    maximumX: 780,
                    maximumY: 840
                ),
                kind: "freight",
                minimumCompactWidth: 8
            ),
            SemanticTarget(
                id: "staff-entry",
                expected: PixelBounds(
                    minimumX: 810,
                    minimumY: 616,
                    maximumX: 825,
                    maximumY: 656
                ),
                kind: "staff",
                minimumCompactWidth: 2
            ),
        ]
        let compactMaskedColor = try scaled(
            try makeImage(
                rgba: maskedRGBA(raster.rgba, grayscale: false),
                width: raster.image.width,
                height: raster.image.height
            ),
            width: 192,
            height: 128
        )
        let compactRGBA = try decodedRGBA(compactMaskedColor)
        var semanticRecords: [[String: Any]] = []
        var semanticPassed = true
        for sourceTarget in targets {
            let (sourceBounds, sourceCount) = matchingBounds(
                rgba: raster.rgba,
                imageWidth: raster.image.width,
                target: sourceTarget
            )
            let target = compactTarget(sourceTarget)
            let (compactBounds, compactCount) = matchingBounds(
                rgba: compactRGBA,
                imageWidth: 192,
                target: target
            )
            let compactWidth = Double(compactBounds?.width ?? 0)
            let compactHeight = Double(compactBounds?.height ?? 0)
            let passed =
                sourceBounds != nil
                && compactBounds != nil
                && compactWidth >= sourceTarget.minimumCompactWidth
                && (sourceTarget.kind != "freight" || compactHeight >= 8)
            semanticPassed = semanticPassed && passed
            semanticRecords.append([
                "id": sourceTarget.id,
                "kind": sourceTarget.kind,
                "expectedSourceBounds": sourceTarget.expected.array,
                "actualSourceMaterialPixelBounds":
                    sourceBounds?.array ?? [],
                "actualSourceMaterialPixelCount": sourceCount,
                "expectedCompactBounds": target.expected.array,
                "actualCompactMaterialPixelBounds":
                    compactBounds?.array ?? [],
                "actualCompactMaterialPixelCount": compactCount,
                "actualCompactWidthPixels": compactWidth,
                "actualCompactHeightPixels": compactHeight,
                "minimumCompactWidthPixels":
                    sourceTarget.minimumCompactWidth,
                "passed": passed,
            ])
        }
        let descriptorURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
                + "art-proof/industrial-l04-turbine-v08-prepixel/scenes/"
                + "industrial_l04/variant-0/n/scene.json"
        )
        let descriptorData = try Data(contentsOf: descriptorURL)
        guard
            let descriptor = try JSONSerialization.jsonObject(
                with: descriptorData
            ) as? [String: Any],
            let registration = descriptor["registration"] as? [String: Any],
            let building = descriptor["building"] as? [String: Any],
            let roofVolumes = building["roofVolumes"] as? [[String: Any]]
        else {
            throw L4NorthRawReviewError.invalid("could not decode descriptor")
        }
        let provenanceRecords = try runNames.map { runName -> [String: Any] in
            let url = rawRoot.appendingPathComponent(runName)
                .appendingPathComponent("provenance.json")
            let data = try Data(contentsOf: url)
            guard
                let record = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any]
            else {
                throw L4NorthRawReviewError.invalid(
                    "could not decode \(url.path)"
                )
            }
            return record
        }
        let expectedDescriptorSHA =
            "9f812479746ba031335aad53f89d562e1f03de0b868b5b533bf43007eb4a9472"
        let expectedMaterialSHA =
            "f8cf1d4ff9ab4446ec562fe949dd09c45399a32d9a763f7d6dd6380b66e52b94"
        let registrationPassed = provenanceRecords.allSatisfy {
            ($0["sceneDescriptorSHA256"] as? String) == expectedDescriptorSHA
                && ($0["materialLibrarySHA256"] as? String)
                    == expectedMaterialSHA
                && jsonArray($0["groundPivotSource"])
                    == jsonArray(registration["groundPivotSource"])
                && jsonArray($0["frontageSocketSource"])
                    == jsonArray(registration["frontageSocketSource"])
                && jsonArray($0["southeastShadowVectorSource"])
                    == [2, 1]
                && ($0["orientationTransform"] as? String) == "none"
                && ($0["authoredIndependently"] as? Bool) == true
                && ($0["productionSelected"] as? Bool) == false
        }
        let sawtoothCount = roofVolumes.filter {
            (($0["id"] as? String) ?? "").contains("sawtooth")
        }.count
        let maskedColor = try makeImage(
            rgba: maskedRGBA(raster.rgba, grayscale: false),
            width: raster.image.width,
            height: raster.image.height
        )
        let maskedGray = try makeImage(
            rgba: maskedRGBA(raster.rgba, grayscale: true),
            width: raster.image.width,
            height: raster.image.height
        )
        let sourceColor = try neutralComposite(
            source: maskedColor,
            width: 1536,
            height: 1024
        )
        let sourceGray = try neutralComposite(
            source: maskedGray,
            width: 1536,
            height: 1024
        )
        var outputImages: [(String, CGImage)] = [
            ("SOURCE-SCALE-COLOR.png", sourceColor),
            ("SOURCE-SCALE-GRAYSCALE.png", sourceGray),
            (
                "ALPHA-OCCUPANCY.png",
                try makeImage(
                    rgba: occupancyRGBA(raster.rgba),
                    width: raster.image.width,
                    height: raster.image.height
                )
            ),
            (
                "NATIVE-2X-COLOR.png",
                try scaled(sourceColor, width: 384, height: 256)
            ),
            (
                "NATIVE-2X-GRAYSCALE.png",
                try scaled(sourceGray, width: 384, height: 256)
            ),
            (
                "EXACT-192X128-COLOR.png",
                try scaled(sourceColor, width: 192, height: 128)
            ),
            (
                "EXACT-192X128-GRAYSCALE.png",
                try scaled(sourceGray, width: 192, height: 128)
            ),
            (
                "OCCUPIED-CROP-COLOR.png",
                try scaled(
                    cropped(sourceColor, bounds: occupied, padding: 24),
                    width: 768,
                    height: 512
                )
            ),
            (
                "FOOTPRINT-CONTACT.png",
                try overlay(
                    source: sourceColor,
                    semanticTargets: targets,
                    includeSemantics: false
                )
            ),
            (
                "SEMANTIC-VISIBILITY.png",
                try overlay(
                    source: sourceColor,
                    semanticTargets: targets,
                    includeSemantics: true
                )
            ),
        ]
        var panelHashes: [String: String] = [:]
        for (name, image) in outputImages {
            let url = outputDirectory.appendingPathComponent(name)
            try writePNG(image, to: url)
            panelHashes[name] = digest(try Data(contentsOf: url))
        }
        outputImages.removeAll()
        let technicalPassed =
            occupied.halfOpenArray == [509, 517, 1027, 898]
            && occupiedCount == 108_020
            && hiddenRGB == 0
            && semanticPassed
            && registrationPassed
            && sawtoothCount == 4
            && alphaNonzero == 1536 * 1024
        let report: [String: Any] = [
            "task": "PLAY-027",
            "artifact": "industrial-l04-turbine-v08-north-raw-v02",
            "disposition":
                technicalPassed
                ? "PENDING_INDEPENDENT_RAW_REVIEW"
                : "REJECTED_TECHNICAL_GATE",
            "sourceAuthority": false,
            "productionSelected": false,
            "processCount": 3,
            "direction": "north",
            "fileIdentityPassed": true,
            "decodedRGBAIdentityPassed": true,
            "rawFileSHA256": raster.fileSHA256,
            "decodedRGBASHA256": raster.decodedRGBASHA256,
            "runFileSHA256": Dictionary(
                uniqueKeysWithValues: zip(
                    runNames,
                    rasters.map(\.fileSHA256)
                )
            ),
            "runDecodedRGBASHA256": Dictionary(
                uniqueKeysWithValues: zip(
                    runNames,
                    rasters.map(\.decodedRGBASHA256)
                )
            ),
            "descriptorSHA256": digest(descriptorData),
            "materialLibrarySHA256": expectedMaterialSHA,
            "sceneGeometryID": "industrial-l04-turbine-v08-n-independent",
            "occupancy": [
                "nonChromaBoundsHalfOpen": occupied.halfOpenArray,
                "nonChromaBoundsInclusive": occupied.array,
                "nonChromaPixelCount": occupiedCount,
                "minimumBoundsPassed":
                    occupied.width >= 400 && occupied.height >= 260,
                "minimumAreaPassed": occupiedCount >= 50_000,
            ],
            "alphaAndChroma": [
                "alphaZeroPixelCount": alphaZero,
                "alphaNonzeroPixelCount": alphaNonzero,
                "hiddenRGBAtAlphaZeroPixelCount": hiddenRGB,
                "exactChromaPixelCount": exactChroma,
                "nonExactNearChromaPixelCount": nearChroma,
                "rawFlatChromaContractPassed":
                    exactChroma + occupiedCount == 1536 * 1024,
                "reviewMaskHiddenRGBPixelCount": 0,
            ],
            "semanticVisibility": semanticRecords,
            "registrationPassed": registrationPassed,
            "groundPivotSource": jsonArray(
                registration["groundPivotSource"]
            ) ?? [],
            "frontageSocketSource": jsonArray(
                registration["frontageSocketSource"]
            ) ?? [],
            "doorBaseSource": registration["doorBaseSource"] ?? [],
            "northwestKeyOriginWorld": [-80, 120, -80],
            "southeastShadowVectorSource": [2, 1],
            "sawtoothRoofVolumeCount": sawtoothCount,
            "subordinateStackNodeCount": 1,
            "luma": [
                "p25": percentile(0.25),
                "median": percentile(0.5),
                "p75": percentile(0.75),
                "p95": percentile(0.95),
            ],
            "panelSHA256": panelHashes,
            "rendererSourceCommit":
                "98e3ba66af23dfca66101cd516ceda0b4bf67129",
            "technicalPassed": technicalPassed,
            "visualReviewRequired": true,
        ]
        let reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try reportData.write(
            to: outputDirectory.appendingPathComponent("RAW-REVIEW.json")
        )
        guard technicalPassed else {
            throw L4NorthRawReviewError.invalid(
                "North raw technical review failed"
            )
        }
    }
}
