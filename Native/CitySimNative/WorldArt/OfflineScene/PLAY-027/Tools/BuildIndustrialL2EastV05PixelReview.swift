import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL2EastV05PixelReviewError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

private struct V05ReviewRaster {
    let url: URL
    let width: Int
    let height: Int
    let rgba: [UInt8]
    let fileSHA256: String
    let decodedRGBASHA256: String
}

private func reviewArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2EastV05PixelReviewError.invalid(
            "missing \(name)"
        )
    }
    return arguments[index + 1]
}

private func reviewSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func reviewSHA256(_ url: URL) throws -> String {
    reviewSHA256(try Data(contentsOf: url))
}

private func loadReviewRaster(_ url: URL) throws -> V05ReviewRaster {
    let fileData = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw IndustrialL2EastV05PixelReviewError.invalid(
            "could not decode \(url.path)"
        )
    }
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let rendered = rgba.withUnsafeMutableBytes { storage -> Bool in
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
        throw IndustrialL2EastV05PixelReviewError.invalid(
            "could not canonicalize \(url.path)"
        )
    }
    return V05ReviewRaster(
        url: url,
        width: image.width,
        height: image.height,
        rgba: rgba,
        fileSHA256: reviewSHA256(fileData),
        decodedRGBASHA256: reviewSHA256(Data(rgba))
    )
}

private func reviewImage(
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
        throw IndustrialL2EastV05PixelReviewError.invalid(
            "could not create review image"
        )
    }
    return image
}

private func grayscaleReviewRGBA(_ rgba: [UInt8]) -> [UInt8] {
    var output = rgba
    for offset in stride(from: 0, to: output.count, by: 4) {
        let red = 54 * Int(output[offset])
        let green = 183 * Int(output[offset + 1])
        let blue = 19 * Int(output[offset + 2])
        let weighted = (red + green + blue + 128) >> 8
        let luma = UInt8(min(255, weighted))
        output[offset] = luma
        output[offset + 1] = luma
        output[offset + 2] = luma
    }
    return output
}

private func neutralizedBorderMatteRGBA(
    _ rgba: [UInt8],
    width: Int,
    height: Int
) -> [UInt8] {
    var output = rgba
    var queued = [Bool](repeating: false, count: width * height)
    var queue: [Int] = []
    queue.reserveCapacity(width * height / 2)

    func enqueue(_ x: Int, _ y: Int) {
        let index = y * width + x
        guard !queued[index] else { return }
        queued[index] = true
        queue.append(index)
    }
    func isMatte(_ offset: Int) -> Bool {
        let red = Int(output[offset])
        let green = Int(output[offset + 1])
        let blue = Int(output[offset + 2])
        return output[offset + 3] > 0
            && red >= 180
            && blue >= 150
            && green <= 110
            && red + blue >= green * 4
    }

    for x in 0..<width {
        enqueue(x, 0)
        enqueue(x, height - 1)
    }
    for y in 0..<height {
        enqueue(0, y)
        enqueue(width - 1, y)
    }
    var cursor = 0
    while cursor < queue.count {
        let index = queue[cursor]
        cursor += 1
        let offset = index * 4
        guard isMatte(offset) else { continue }
        output[offset] = 230
        output[offset + 1] = 230
        output[offset + 2] = 222
        output[offset + 3] = 255
        let x = index % width
        let y = index / width
        if x > 0 { enqueue(x - 1, y) }
        if x + 1 < width { enqueue(x + 1, y) }
        if y > 0 { enqueue(x, y - 1) }
        if y + 1 < height { enqueue(x, y + 1) }
    }
    for offset in stride(from: 0, to: output.count, by: 4) {
        let red = Int(output[offset])
        let green = Int(output[offset + 1])
        let blue = Int(output[offset + 2])
        if
            red != 230 || green != 230 || blue != 222,
            Double(red) > Double(green) * 1.35,
            Double(blue) > Double(green) * 1.25
        {
            let spill = min(red, blue) - green
            output[offset] = UInt8(max(green, red - spill))
            output[offset + 2] = UInt8(max(green, blue - spill))
        }
    }
    return output
}

private func occupiedBounds(
    width: Int,
    height: Int,
    includes: (Int, Int) -> Bool
) -> [Int] {
    var minimumX = width
    var minimumY = height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<height {
        for x in 0..<width where includes(x, y) {
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    guard maximumX >= 0 else {
        return []
    }
    return [minimumX, minimumY, maximumX + 1, maximumY + 1]
}

private func rawSupportInspection(
    raw: V05ReviewRaster,
    registeredAlpha: V05ReviewRaster
) throws -> [String: Any] {
    guard
        raw.width == registeredAlpha.width,
        raw.height == registeredAlpha.height
    else {
        throw IndustrialL2EastV05PixelReviewError.invalid(
            "raw and registered alpha dimensions differ"
        )
    }
    var rawNonChromaCount = 0
    var alphaPositiveCount = 0
    var alphaOneThroughEightCount = 0
    var hiddenNonMagentaCount = 0
    var nearMagentaForegroundCount = 0
    for offset in stride(from: 0, to: raw.rgba.count, by: 4) {
        let red = Int(raw.rgba[offset])
        let green = Int(raw.rgba[offset + 1])
        let blue = Int(raw.rgba[offset + 2])
        let rawAlpha = Int(raw.rgba[offset + 3])
        let exactChroma = red == 255 && green == 0 && blue == 255
        if !exactChroma {
            rawNonChromaCount += 1
            if rawAlpha == 0 {
                hiddenNonMagentaCount += 1
            }
            if
                rawAlpha > 0,
                red >= 180,
                blue >= 150,
                green <= 110,
                red + blue >= green * 4
            {
                nearMagentaForegroundCount += 1
            }
        }
        let alpha = Int(registeredAlpha.rgba[offset + 3])
        if alpha > 0 {
            alphaPositiveCount += 1
        }
        if (1...8).contains(alpha) {
            alphaOneThroughEightCount += 1
        }
    }
    let rawBounds = occupiedBounds(
        width: raw.width,
        height: raw.height
    ) { x, y in
        let offset = (y * raw.width + x) * 4
        return !(
            raw.rgba[offset] == 255
            && raw.rgba[offset + 1] == 0
            && raw.rgba[offset + 2] == 255
        )
    }
    let alphaBounds = occupiedBounds(
        width: registeredAlpha.width,
        height: registeredAlpha.height
    ) { x, y in
        registeredAlpha.rgba[
            (y * registeredAlpha.width + x) * 4 + 3
        ] > 0
    }
    let supportMatches =
        rawNonChromaCount == alphaPositiveCount
        && rawBounds == alphaBounds
    return [
        "rawFileSHA256": raw.fileSHA256,
        "rawDecodedRGBASHA256": raw.decodedRGBASHA256,
        "registeredAlphaFileSHA256": registeredAlpha.fileSHA256,
        "registeredAlphaDecodedRGBASHA256":
            registeredAlpha.decodedRGBASHA256,
        "rawNonChromaPixelCount": rawNonChromaCount,
        "alphaPositivePixelCount": alphaPositiveCount,
        "alphaOneThroughEightPixelCount": alphaOneThroughEightCount,
        "rawNonChromaBounds": rawBounds,
        "alphaPositiveBounds": alphaBounds,
        "hiddenNonMagentaPixelCount": hiddenNonMagentaCount,
        "nearMagentaForegroundPixelCount": nearMagentaForegroundCount,
        "rawSupportMatchesGenuineAlphaPositiveSupport": supportMatches,
        "technicalPassed":
            supportMatches
            && hiddenNonMagentaCount == 0
            && nearMagentaForegroundCount == 0,
    ]
}

private func normalizedInspection(
    _ raster: V05ReviewRaster
) -> [String: Any] {
    var alphaMinimum = 255
    var alphaMaximum = 0
    var transparentCount = 0
    var visibleCount = 0
    var hiddenRGBCount = 0
    var exactChromaCount = 0
    var visibleMagentaSpillCount = 0
    var lumas: [Int] = []
    for offset in stride(from: 0, to: raster.rgba.count, by: 4) {
        let red = Int(raster.rgba[offset])
        let green = Int(raster.rgba[offset + 1])
        let blue = Int(raster.rgba[offset + 2])
        let alpha = Int(raster.rgba[offset + 3])
        alphaMinimum = min(alphaMinimum, alpha)
        alphaMaximum = max(alphaMaximum, alpha)
        if alpha == 0 {
            transparentCount += 1
            if red != 0 || green != 0 || blue != 0 {
                hiddenRGBCount += 1
            }
            continue
        }
        visibleCount += 1
        if red == 255 && green == 0 && blue == 255 {
            exactChromaCount += 1
        }
        if
            alpha >= 8,
            red >= 96,
            blue >= 96,
            red > green * 3 / 2,
            blue > green * 3 / 2
        {
            visibleMagentaSpillCount += 1
        }
        lumas.append((54 * red + 183 * green + 19 * blue + 128) >> 8)
    }
    lumas.sort()
    func percentile(_ fraction: Double) -> Int {
        guard !lumas.isEmpty else { return 0 }
        let index = Int(
            (Double(lumas.count - 1) * fraction).rounded()
        )
        return lumas[index]
    }
    let bounds = occupiedBounds(
        width: raster.width,
        height: raster.height
    ) { x, y in
        raster.rgba[(y * raster.width + x) * 4 + 3] > 0
    }
    let padding =
        bounds.count == 4
        ? [
            bounds[0],
            bounds[1],
            raster.width - bounds[2],
            raster.height - bounds[3],
        ] : []
    let passed =
        alphaMinimum == 0
        && alphaMaximum == 255
        && transparentCount > 0
        && visibleCount > 0
        && hiddenRGBCount == 0
        && exactChromaCount == 0
        && visibleMagentaSpillCount == 0
        && padding.count == 4
        && padding.allSatisfy { $0 > 2 }
    return [
        "pixels": [raster.width, raster.height],
        "fileSHA256": raster.fileSHA256,
        "decodedRGBASHA256": raster.decodedRGBASHA256,
        "alphaRange": [alphaMinimum, alphaMaximum],
        "alphaBounds": bounds,
        "paddingPixels": padding,
        "transparentPixelCount": transparentCount,
        "visiblePixelCount": visibleCount,
        "hiddenRGBPixelCount": hiddenRGBCount,
        "exactChromaPixelCount": exactChromaCount,
        "visibleMagentaSpillPixelCount": visibleMagentaSpillCount,
        "lumaP25": percentile(0.25),
        "lumaP50": percentile(0.50),
        "lumaP75": percentile(0.75),
        "lumaP95": percentile(0.95),
        "technicalPassed": passed,
    ]
}

private func rasterDifference(
    _ first: V05ReviewRaster,
    _ second: V05ReviewRaster
) throws -> [String: Any] {
    guard
        first.width == second.width,
        first.height == second.height
    else {
        throw IndustrialL2EastV05PixelReviewError.invalid(
            "repeat dimensions differ"
        )
    }
    var differingPixels = 0
    var differingChannels = 0
    var maximumChannelDelta = 0
    for offset in stride(from: 0, to: first.rgba.count, by: 4) {
        var changed = false
        for channel in 0..<4 {
            let delta = abs(
                Int(first.rgba[offset + channel])
                    - Int(second.rgba[offset + channel])
            )
            if delta > 0 {
                changed = true
                differingChannels += 1
                maximumChannelDelta = max(maximumChannelDelta, delta)
            }
        }
        if changed {
            differingPixels += 1
        }
    }
    return [
        "differingPixelCount": differingPixels,
        "differingChannelCount": differingChannels,
        "maximumChannelDelta": maximumChannelDelta,
    ]
}

private func writeReviewPNG(_ image: CGImage, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2EastV05PixelReviewError.invalid(
            "output must be absent: \(url.path)"
        )
    }
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
        throw IndustrialL2EastV05PixelReviewError.invalid(
            "could not create \(url.path)"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL2EastV05PixelReviewError.invalid(
            "could not finalize \(url.path)"
        )
    }
}

private func buildReviewPanel(
    images: [CGImage],
    labels: [String],
    sourceRects: [CGRect],
    destinationSize: CGSize,
    outputURL: URL
) throws {
    guard
        images.count == labels.count,
        images.count == sourceRects.count
    else {
        throw IndustrialL2EastV05PixelReviewError.invalid(
            "panel inputs differ"
        )
    }
    let cellWidth = Int(destinationSize.width)
    let cellHeight = Int(destinationSize.height)
    let headerHeight = 52
    guard let context = CGContext(
        data: nil,
        width: cellWidth * images.count,
        height: cellHeight + headerHeight,
        bitsPerComponent: 8,
        bytesPerRow: cellWidth * images.count * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw IndustrialL2EastV05PixelReviewError.invalid(
            "could not create panel context"
        )
    }
    context.setFillColor(NSColor(calibratedWhite: 0.09, alpha: 1).cgColor)
    context.fill(
        CGRect(
            x: 0,
            y: 0,
            width: cellWidth * images.count,
            height: cellHeight + headerHeight
        )
    )
    context.interpolationQuality = .high
    for index in images.indices {
        guard let cropped = images[index].cropping(
            to: sourceRects[index]
        ) else {
            throw IndustrialL2EastV05PixelReviewError.invalid(
                "panel crop failed"
            )
        }
        context.draw(
            cropped,
            in: CGRect(
                x: index * cellWidth,
                y: 0,
                width: cellWidth,
                height: cellHeight
            )
        )
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(
        cgContext: context,
        flipped: false
    )
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .bold),
        .foregroundColor: NSColor.white,
    ]
    for index in labels.indices {
        labels[index].draw(
            at: CGPoint(
                x: index * cellWidth + 10,
                y: cellHeight + 14
            ),
            withAttributes: attributes
        )
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let output = context.makeImage() else {
        throw IndustrialL2EastV05PixelReviewError.invalid(
            "could not create panel image"
        )
    }
    try writeReviewPNG(output, to: outputURL)
}

private func reviewJSONObject(_ url: URL) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(
        with: Data(contentsOf: url)
    ) as? [String: Any] else {
        throw IndustrialL2EastV05PixelReviewError.invalid(
            "invalid JSON \(url.path)"
        )
    }
    return object
}

private func relativeReviewPath(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path + "/"
    guard url.path.hasPrefix(prefix) else {
        return url.path
    }
    return String(url.path.dropFirst(prefix.count))
}

@main
enum BuildIndustrialL2EastV05PixelReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath:
                try reviewArgument("--repository-root", in: arguments)
        ).standardizedFileURL
        let outputDirectory = URL(
            fileURLWithPath:
                try reviewArgument("--output-directory", in: arguments)
        ).standardizedFileURL
        guard !FileManager.default.fileExists(
            atPath: outputDirectory.path
        ) else {
            throw IndustrialL2EastV05PixelReviewError.invalid(
                "output directory must be absent"
            )
        }

        let evidenceRoot = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05"
        )
        let rawRoot = evidenceRoot.appendingPathComponent(
            "raw-calibration/diagnostics/east-primary"
        )
        let runARoot = evidenceRoot.appendingPathComponent(
            "normalized-calibration/run-a"
        )
        let runBRoot = evidenceRoot.appendingPathComponent(
            "normalized-calibration/run-b"
        )
        let acceptedL1RawURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/raw/industrial_l01/variant-0/east/source-v05.png"
        )
        let retainedV04NeutralURL = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/raw-probe/diagnostics/east-primary/neutral-alpha-composite.png"
        )
        let v05NeutralURL = rawRoot.appendingPathComponent(
            "neutral-alpha-composite.png"
        )
        let rawURL = rawRoot.appendingPathComponent("raw.png")
        let registeredAlphaURL = rawRoot.appendingPathComponent(
            "pre-chroma-registered-alpha.png"
        )
        let rawProvenanceURL = rawRoot.appendingPathComponent(
            "provenance.json"
        )
        let runAProvenanceURL = runARoot.appendingPathComponent(
            "provenance.json"
        )
        let runBProvenanceURL = runBRoot.appendingPathComponent(
            "provenance.json"
        )

        let raw = try loadReviewRaster(rawURL)
        let registeredAlpha = try loadReviewRaster(registeredAlphaURL)
        let rawSupport = try rawSupportInspection(
            raw: raw,
            registeredAlpha: registeredAlpha
        )
        let rawProvenance = try reviewJSONObject(rawProvenanceURL)
        let runAProvenance = try reviewJSONObject(runAProvenanceURL)
        let runBProvenance = try reviewJSONObject(runBProvenanceURL)

        let l1Raw = try loadReviewRaster(acceptedL1RawURL)
        let v04Neutral = try loadReviewRaster(retainedV04NeutralURL)
        let v05Neutral = try loadReviewRaster(v05NeutralURL)
        let rawColorImages = [
            try reviewImage(
                rgba: neutralizedBorderMatteRGBA(
                    l1Raw.rgba,
                    width: l1Raw.width,
                    height: l1Raw.height
                ),
                width: l1Raw.width,
                height: l1Raw.height
            ),
            try reviewImage(
                rgba: v04Neutral.rgba,
                width: v04Neutral.width,
                height: v04Neutral.height
            ),
            try reviewImage(
                rgba: v05Neutral.rgba,
                width: v05Neutral.width,
                height: v05Neutral.height
            ),
        ]
        let rawGrayImages = [
            try reviewImage(
                rgba: grayscaleReviewRGBA(
                    neutralizedBorderMatteRGBA(
                        l1Raw.rgba,
                        width: l1Raw.width,
                        height: l1Raw.height
                    )
                ),
                width: l1Raw.width,
                height: l1Raw.height
            ),
            try reviewImage(
                rgba: grayscaleReviewRGBA(v04Neutral.rgba),
                width: v04Neutral.width,
                height: v04Neutral.height
            ),
            try reviewImage(
                rgba: grayscaleReviewRGBA(v05Neutral.rgba),
                width: v05Neutral.width,
                height: v05Neutral.height
            ),
        ]
        let comparisonLabels = [
            "ACCEPTED INDUSTRIAL L1",
            "RETAINED V04",
            "V05 REAL EAST PRIMARY",
        ]
        let compactComparisonLabels = [
            "L1 ACCEPTED",
            "V04 RETAINED",
            "V05 REAL",
        ]
        let fullRects = Array(
            repeating: CGRect(x: 0, y: 0, width: 1536, height: 1024),
            count: 3
        )
        let footprintRects = Array(
            repeating: CGRect(x: 512, y: 416, width: 512, height: 512),
            count: 3
        )
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let sourceColorURL = outputDirectory.appendingPathComponent(
            "SOURCE-SCALE-L1-V04-V05-COLOR.png"
        )
        let sourceGrayURL = outputDirectory.appendingPathComponent(
            "SOURCE-SCALE-L1-V04-V05-GRAYSCALE.png"
        )
        let footprintColorURL = outputDirectory.appendingPathComponent(
            "FOOTPRINT-NATIVE-2X-L1-V04-V05-COLOR.png"
        )
        let footprintGrayURL = outputDirectory.appendingPathComponent(
            "FOOTPRINT-NATIVE-2X-L1-V04-V05-GRAYSCALE.png"
        )
        let zoomColorURL = outputDirectory.appendingPathComponent(
            "FOOTPRINT-ZOOM-L1-V04-V05-COLOR.png"
        )
        let zoomGrayURL = outputDirectory.appendingPathComponent(
            "FOOTPRINT-ZOOM-L1-V04-V05-GRAYSCALE.png"
        )
        try buildReviewPanel(
            images: rawColorImages,
            labels: comparisonLabels,
            sourceRects: fullRects,
            destinationSize: CGSize(width: 432, height: 288),
            outputURL: sourceColorURL
        )
        try buildReviewPanel(
            images: rawGrayImages,
            labels: comparisonLabels,
            sourceRects: fullRects,
            destinationSize: CGSize(width: 432, height: 288),
            outputURL: sourceGrayURL
        )
        try buildReviewPanel(
            images: rawColorImages,
            labels: compactComparisonLabels,
            sourceRects: footprintRects,
            destinationSize: CGSize(width: 144, height: 144),
            outputURL: footprintColorURL
        )
        try buildReviewPanel(
            images: rawGrayImages,
            labels: compactComparisonLabels,
            sourceRects: footprintRects,
            destinationSize: CGSize(width: 144, height: 144),
            outputURL: footprintGrayURL
        )
        try buildReviewPanel(
            images: rawColorImages,
            labels: compactComparisonLabels,
            sourceRects: footprintRects,
            destinationSize: CGSize(width: 288, height: 288),
            outputURL: zoomColorURL
        )
        try buildReviewPanel(
            images: rawGrayImages,
            labels: compactComparisonLabels,
            sourceRects: footprintRects,
            destinationSize: CGSize(width: 288, height: 288),
            outputURL: zoomGrayURL
        )

        let v05FileNames = [
            "block":
                "generated_v4_industrial_l02_east_calibration_v05_block.png",
            "neighborhood":
                "generated_v4_industrial_l02_east_calibration_v05_neighborhood.png",
            "city":
                "generated_v4_industrial_l02_east_calibration_v05_city.png",
        ]
        let l1FileNames = [
            "block": "generated_v4_industrial_l01_block.png",
            "neighborhood": "generated_v4_industrial_l01_neighborhood.png",
            "city": "generated_v4_industrial_l01_city.png",
        ]
        let acceptedL1NormalizedRoot = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/normalized/industrial_l01/variant-0/east/source-v05"
        )
        var lodReports: [[String: Any]] = []
        var panelRecords: [[String: Any]] = []
        var uniqueFiles: [String] = []
        var uniquePixels: [String] = []
        var allNormalizedTechnicalPassed = true
        for lod in ["block", "neighborhood", "city"] {
            guard
                let v05FileName = v05FileNames[lod],
                let l1FileName = l1FileNames[lod]
            else {
                throw IndustrialL2EastV05PixelReviewError.invalid(
                    "missing LOD filename"
                )
            }
            let runA = try loadReviewRaster(
                runARoot.appendingPathComponent(v05FileName)
            )
            let runB = try loadReviewRaster(
                runBRoot.appendingPathComponent(v05FileName)
            )
            let acceptedL1 = try loadReviewRaster(
                acceptedL1NormalizedRoot.appendingPathComponent(l1FileName)
            )
            let runAInspection = normalizedInspection(runA)
            let runBInspection = normalizedInspection(runB)
            let difference = try rasterDifference(runA, runB)
            let exactIdentity =
                runA.fileSHA256 == runB.fileSHA256
                && runA.decodedRGBASHA256 == runB.decodedRGBASHA256
            let technicalPassed =
                exactIdentity
                && runAInspection["technicalPassed"] as? Bool == true
                && runBInspection["technicalPassed"] as? Bool == true
            allNormalizedTechnicalPassed =
                allNormalizedTechnicalPassed && technicalPassed
            uniqueFiles.append(runA.fileSHA256)
            uniquePixels.append(runA.decodedRGBASHA256)

            let v05Color = try reviewImage(
                rgba: runA.rgba,
                width: runA.width,
                height: runA.height
            )
            let v05Gray = try reviewImage(
                rgba: grayscaleReviewRGBA(runA.rgba),
                width: runA.width,
                height: runA.height
            )
            let l1Color = try reviewImage(
                rgba: acceptedL1.rgba,
                width: acceptedL1.width,
                height: acceptedL1.height
            )
            let l1Gray = try reviewImage(
                rgba: grayscaleReviewRGBA(acceptedL1.rgba),
                width: acceptedL1.width,
                height: acceptedL1.height
            )
            let actualURL = outputDirectory.appendingPathComponent(
                "\(lod.uppercased())-ACTUAL-L1-V05-COLOR-GRAYSCALE.png"
            )
            let normalizedRects = Array(
                repeating: CGRect(
                    x: 0,
                    y: 0,
                    width: runA.width,
                    height: runA.height
                ),
                count: 4
            )
            try buildReviewPanel(
                images: [l1Color, v05Color, l1Gray, v05Gray],
                labels: [
                    "ACCEPTED L1 COLOR",
                    "V05 COLOR",
                    "ACCEPTED L1 GRAY",
                    "V05 GRAY",
                ],
                sourceRects: normalizedRects,
                destinationSize: CGSize(
                    width: runA.width,
                    height: runA.height
                ),
                outputURL: actualURL
            )
            let crop = CGRect(
                x: max(
                    0,
                    min(
                        (runAInspection["alphaBounds"] as? [Int])?[0] ?? 0,
                        (normalizedInspection(acceptedL1)["alphaBounds"]
                            as? [Int])?[0] ?? 0
                    ) - 8
                ),
                y: max(
                    0,
                    min(
                        (runAInspection["alphaBounds"] as? [Int])?[1] ?? 0,
                        (normalizedInspection(acceptedL1)["alphaBounds"]
                            as? [Int])?[1] ?? 0
                    ) - 8
                ),
                width: runA.width,
                height: runA.height
            )
            let safeCrop = crop.intersection(
                CGRect(x: 0, y: 0, width: runA.width, height: runA.height)
            )
            let zoomURL = outputDirectory.appendingPathComponent(
                "\(lod.uppercased())-ZOOM-L1-V05-COLOR-GRAYSCALE.png"
            )
            try buildReviewPanel(
                images: [l1Color, v05Color, l1Gray, v05Gray],
                labels: [
                    "ACCEPTED L1 COLOR",
                    "V05 COLOR",
                    "ACCEPTED L1 GRAY",
                    "V05 GRAY",
                ],
                sourceRects: Array(repeating: safeCrop, count: 4),
                destinationSize: CGSize(
                    width: max(1, Int(safeCrop.width) * 2),
                    height: max(1, Int(safeCrop.height) * 2)
                ),
                outputURL: zoomURL
            )
            for panel in [actualURL, zoomURL] {
                panelRecords.append([
                    "lod": lod,
                    "file": panel.lastPathComponent,
                    "sha256": try reviewSHA256(panel),
                ])
            }
            lodReports.append([
                "lod": lod,
                "runA": runAInspection,
                "runB": runBInspection,
                "exactFileAndDecodedPixelIdentity": exactIdentity,
                "repeatDifference": difference,
                "technicalPassed": technicalPassed,
                "acceptedL1": normalizedInspection(acceptedL1),
            ])
        }

        let uniqueLODFileIdentities =
            Set(uniqueFiles).count == uniqueFiles.count
        let uniqueLODDecodedPixelIdentities =
            Set(uniquePixels).count == uniquePixels.count
        let repeatProvenanceIdentity =
            try reviewSHA256(runAProvenanceURL)
                == reviewSHA256(runBProvenanceURL)
        let runARegistration =
            runAProvenance["registration"] as? [String: Any]
        let runBRegistration =
            runBProvenance["registration"] as? [String: Any]
        let registrationPassed =
            NSDictionary(dictionary: runARegistration ?? [:]).isEqual(
                to: runBRegistration ?? [:]
            )
            && runARegistration?["target_ground_pivot"] as? [Int]
                == [768, 896]
            && runARegistration?["source_bbox"] as? [Int]
                == [509, 488, 1029, 906]
            && runARegistration?["target_size"] as? [Int]
                == [416, 335]
            && runARegistration?["target_origin"] as? [Int]
                == [560, 561]
            && runAProvenance["object_width"] as? Int == 410
            && runAProvenance["reference_subject_width"] as? Int == 512
            && runAProvenance["productionSelected"] as? Bool == false
            && runBProvenance["productionSelected"] as? Bool == false
        let rawRegistration =
            rawProvenance["registration"] as? [String: Any]
        let rawRegistrationPassed =
            rawRegistration?["groundPivotSource"] as? [Int] == [768, 896]
            && rawRegistration?["frontageSocketSource"] as? [Int]
                == [896, 832]
            && rawRegistration?["doorBaseSource"] as? [[Int]]
                == [[934, 813], [858, 851]]
            && rawRegistration?["southeastShadowVectorSource"] as? [Int]
                == [2, 1]
            && rawProvenance["productionSelected"] as? Bool == false
        let rawTechnicalPassed =
            rawSupport["technicalPassed"] as? Bool == true
            && rawRegistrationPassed
        let technicalPassed =
            rawTechnicalPassed
            && allNormalizedTechnicalPassed
            && repeatProvenanceIdentity
            && registrationPassed
            && uniqueLODFileIdentities
            && uniqueLODDecodedPixelIdentities

        let fixedPanels = [
            sourceColorURL,
            sourceGrayURL,
            footprintColorURL,
            footprintGrayURL,
            zoomColorURL,
            zoomGrayURL,
        ]
        for panel in fixedPanels {
            panelRecords.append([
                "lod": "source-and-native2x",
                "file": panel.lastPathComponent,
                "sha256": try reviewSHA256(panel),
            ])
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v05-normalized-calibration-review",
            "finalDisposition":
                technicalPassed
                ? "PENDING_INDEPENDENT_VISUAL_REVIEW" : "REJECT",
            "technicalPassed": technicalPassed,
            "sourceAuthority": false,
            "productionSelected": false,
            "sceneKitMetalProcessCount": 0,
            "retainedFreshMetalProcessCount": 1,
            "normalizerProcessCount": 2,
            "normalizerSourceSHA256":
                try reviewArgument(
                    "--normalizer-source-sha256",
                    in: arguments
                ),
            "normalizerBinarySHA256":
                try reviewArgument(
                    "--normalizer-binary-sha256",
                    in: arguments
                ),
            "reviewToolSourceSHA256":
                try reviewSHA256(
                    repositoryRoot.appendingPathComponent(
                        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL2EastV05PixelReview.swift"
                    )
                ),
            "immutableRawInputSHA256": raw.fileSHA256,
            "raw": rawSupport,
            "rawRegistrationPassed": rawRegistrationPassed,
            "normalizationParameters": [
                "objectWidth": 410,
                "referenceWidth": 512,
                "referenceBasis":
                    "frozen 512-source-pixel registration diamond",
            ],
            "repeatProvenanceByteIdentical": repeatProvenanceIdentity,
            "normalizedRegistrationPassed": registrationPassed,
            "uniqueLODFileIdentities": uniqueLODFileIdentities,
            "uniqueLODDecodedPixelIdentities":
                uniqueLODDecodedPixelIdentities,
            "lods": lodReports,
            "panels": panelRecords,
            "panelAuthority":
                "bound actual-pixel review evidence; not source or production acceptance",
            "visualReviewChecklist": [
                "three dock bays and canopies remain separately readable at native-2x",
                "staff entrance does not alias a fourth dock",
                "safety orange remains subordinate",
                "far-side mass does not occlude East frontage",
                "v05 remains superior to accepted Industrial L1 and retained v04 in color and grayscale",
                "no edge loss, halos, stair steps, footprint loss, or material identity drift",
            ],
        ]
        var reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        reportData.append(0x0a)
        try reportData.write(
            to: outputDirectory.appendingPathComponent("REVIEW.json"),
            options: .atomic
        )
        print(
            technicalPassed
                ? "PENDING_INDEPENDENT_VISUAL_REVIEW" : "REJECT"
        )
    }
}
