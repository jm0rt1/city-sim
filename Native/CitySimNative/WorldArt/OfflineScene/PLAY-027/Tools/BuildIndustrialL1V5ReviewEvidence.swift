import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialReviewEvidenceError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l1-v5-review-evidence --repository-root <path> --output-directory <path>"
        case let .invalid(message):
            return message
        }
    }
}

func industrialReviewArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialReviewEvidenceError.arguments
    }
    return arguments[index + 1]
}

func industrialReviewImage(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        )
    else {
        throw IndustrialReviewEvidenceError.invalid(
            "could not decode \(url.path)"
        )
    }
    return image
}

func industrialReviewRGBA(_ image: CGImage) throws -> [UInt8] {
    var bytes = [UInt8](
        repeating: 0,
        count: image.width * image.height * 4
    )
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    try bytes.withUnsafeMutableBytes { storage in
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
            throw IndustrialReviewEvidenceError.invalid(
                "could not allocate RGBA decoder"
            )
        }
        context.draw(
            image,
            in: CGRect(
                x: 0,
                y: 0,
                width: image.width,
                height: image.height
            )
        )
    }
    return bytes
}

func industrialReviewSHA256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map {
        String(format: "%02x", $0)
    }.joined()
}

func industrialReviewRelative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func industrialReviewWrite(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw IndustrialReviewEvidenceError.invalid(
            "could not create \(url.path)"
        )
    }
    CGImageDestinationAddImage(destination, image, [
        kCGImagePropertyPNGInterlaceType: 0,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialReviewEvidenceError.invalid(
            "could not finalize \(url.path)"
        )
    }
}

func industrialReviewGrayscale(_ image: CGImage) throws -> CGImage {
    let width = image.width
    let height = image.height
    var bytes = try industrialReviewRGBA(image)
    return try bytes.withUnsafeMutableBytes { storage in
        for pixel in stride(from: 0, to: storage.count, by: 4) {
            let red = Int(storage[pixel])
            let green = Int(storage[pixel + 1])
            let blue = Int(storage[pixel + 2])
            let weighted = 54 * red + 183 * green + 19 * blue + 128
            let luma = UInt8(min(255, weighted >> 8))
            storage[pixel] = luma
            storage[pixel + 1] = luma
            storage[pixel + 2] = luma
        }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard
            let context = CGContext(
                data: storage.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo:
                    CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            let output = context.makeImage()
        else {
            throw IndustrialReviewEvidenceError.invalid(
                "could not create grayscale image"
            )
        }
        return output
    }
}

func industrialReviewBounds(
    _ image: CGImage,
    bytes: [UInt8]
) throws -> CGRect {
    var minimumX = image.width
    var minimumY = image.height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<image.height {
        for x in 0..<image.width {
            let alpha = Int(bytes[(y * image.width + x) * 4 + 3])
            if alpha > 0 {
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
            }
        }
    }
    guard maximumX >= minimumX, maximumY >= minimumY else {
        throw IndustrialReviewEvidenceError.invalid(
            "normalized source has no visible pixels"
        )
    }
    return CGRect(
        x: minimumX,
        y: minimumY,
        width: maximumX - minimumX + 1,
        height: maximumY - minimumY + 1
    )
}

func industrialReviewQuantile(
    histogram: [Int],
    total: Int,
    fraction: Double
) -> Int {
    let target = Int(
        floor(Double(max(0, total - 1)) * fraction)
    )
    var accumulated = 0
    for (value, count) in histogram.enumerated() {
        accumulated += count
        if accumulated > target {
            return value
        }
    }
    return 255
}

func industrialReviewValueRecord(
    image: CGImage,
    bytes: [UInt8]
) -> [String: Any] {
    var histogram = [Int](repeating: 0, count: 256)
    var opaqueCount = 0
    for pixel in stride(from: 0, to: bytes.count, by: 4) {
        guard bytes[pixel + 3] == 255 else {
            continue
        }
        let luma = min(
            255,
            (
                54 * Int(bytes[pixel])
                    + 183 * Int(bytes[pixel + 1])
                    + 19 * Int(bytes[pixel + 2])
                    + 128
            ) >> 8
        )
        histogram[luma] += 1
        opaqueCount += 1
    }
    let p05 = industrialReviewQuantile(
        histogram: histogram,
        total: opaqueCount,
        fraction: 0.05
    )
    let p25 = industrialReviewQuantile(
        histogram: histogram,
        total: opaqueCount,
        fraction: 0.25
    )
    let p50 = industrialReviewQuantile(
        histogram: histogram,
        total: opaqueCount,
        fraction: 0.50
    )
    let p75 = industrialReviewQuantile(
        histogram: histogram,
        total: opaqueCount,
        fraction: 0.75
    )
    let p95 = industrialReviewQuantile(
        histogram: histogram,
        total: opaqueCount,
        fraction: 0.95
    )
    let minimumBandPopulation = max(2, opaqueCount / 500)
    let significantBands = stride(from: 0, to: 256, by: 16).filter {
        histogram[$0..<min($0 + 16, 256)].reduce(0, +)
            >= minimumBandPopulation
    }.count
    let separationPassed =
        opaqueCount > 0
        && p50 < 128
        && p95 >= 96
        && p95 - p05 >= 80
        && significantBands >= 8
    return [
        "pixels": [image.width, image.height],
        "fullyOpaquePixelCount": opaqueCount,
        "lumaQuantiles": [
            "p05": p05,
            "p25": p25,
            "p50": p50,
            "p75": p75,
            "p95": p95,
        ],
        "p95MinusP05": p95 - p05,
        "p75MinusP25": p75 - p25,
        "significant16StepLumaBands": significantBands,
        "intentionallyDarkPalette": p50 < 128,
        "valueSeparationPassed": separationPassed,
    ]
}

func industrialReviewSheet(
    images: [CGImage],
    crop: CGRect
) throws -> CGImage {
    let width = Int(crop.width) * 2
    let height = Int(crop.height) * 2
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw IndustrialReviewEvidenceError.invalid(
            "could not allocate LOD review sheet"
        )
    }
    context.setFillColor(
        CGColor(
            colorSpace: colorSpace,
            components: [0.14, 0.14, 0.14, 1]
        )!
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .none
    let origins = [
        CGPoint(x: 0, y: crop.height),
        CGPoint(x: crop.width, y: crop.height),
        CGPoint(x: 0, y: 0),
        CGPoint(x: crop.width, y: 0),
    ]
    for (image, origin) in zip(images, origins) {
        guard let cropped = image.cropping(to: crop) else {
            throw IndustrialReviewEvidenceError.invalid(
                "could not crop LOD review image"
            )
        }
        context.draw(
            cropped,
            in: CGRect(
                origin: origin,
                size: CGSize(width: crop.width, height: crop.height)
            )
        )
    }
    guard let output = context.makeImage() else {
        throw IndustrialReviewEvidenceError.invalid(
            "could not create LOD review sheet"
        )
    }
    return output
}

func industrialReviewFamilySheet(
    images: [CGImage]
) throws -> CGImage {
    let gutter = 16
    let width = images.map(\.width).reduce(0, +)
        + gutter * (images.count - 1)
    let height = images.map(\.height).max() ?? 0
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw IndustrialReviewEvidenceError.invalid(
            "could not allocate family comparison sheet"
        )
    }
    context.setFillColor(
        CGColor(
            colorSpace: colorSpace,
            components: [0.08, 0.09, 0.10, 1]
        )!
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .none
    var x = 0
    for image in images {
        context.draw(
            image,
            in: CGRect(
                x: x,
                y: height - image.height,
                width: image.width,
                height: image.height
            )
        )
        x += image.width + gutter
    }
    guard let output = context.makeImage() else {
        throw IndustrialReviewEvidenceError.invalid(
            "could not create family comparison"
        )
    }
    return output
}

@main
enum BuildIndustrialL1V5ReviewEvidenceMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try industrialReviewArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputDirectory = URL(
            fileURLWithPath: try industrialReviewArgument(
                "--output-directory",
                in: arguments
            )
        ).standardizedFileURL
        let toolRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027"
        )
        let directions = ["north", "east", "south", "west"]
        let lods = ["block", "neighborhood", "city"]
        var valueRecords: [[String: Any]] = []
        var grayscaleSheetRecords: [[String: Any]] = []
        var allValueChecksPassed = true

        for lod in lods {
            var images: [CGImage] = []
            var grayscaleImages: [CGImage] = []
            var unionBounds = CGRect.null
            for direction in directions {
                let url = toolRoot
                    .appendingPathComponent(
                        "normalized/industrial_l01/variant-0"
                    )
                    .appendingPathComponent(direction)
                    .appendingPathComponent("source-v05")
                    .appendingPathComponent(
                        "generated_v4_industrial_l01_\(lod).png"
                    )
                let image = try industrialReviewImage(url)
                let bytes = try industrialReviewRGBA(image)
                let bounds = try industrialReviewBounds(
                    image,
                    bytes: bytes
                )
                unionBounds = unionBounds.union(bounds)
                let values = industrialReviewValueRecord(
                    image: image,
                    bytes: bytes
                )
                if values["valueSeparationPassed"] as? Bool != true {
                    allValueChecksPassed = false
                }
                valueRecords.append([
                    "direction": direction,
                    "lod": lod,
                    "file": industrialReviewRelative(url, root: root),
                    "sha256": try industrialReviewSHA256(url),
                    "values": values,
                ])
                images.append(image)
                grayscaleImages.append(
                    try industrialReviewGrayscale(image)
                )
            }
            let imageSize = CGSize(
                width: images[0].width,
                height: images[0].height
            )
            let crop = unionBounds.insetBy(dx: -8, dy: -8).intersection(
                CGRect(origin: .zero, size: imageSize)
            ).integral
            let sheet = try industrialReviewSheet(
                images: grayscaleImages,
                crop: crop
            )
            let sheetURL = outputDirectory.appendingPathComponent(
                "GRAYSCALE-\(lod.uppercased())-ORIGINAL-PIXELS.png"
            )
            try industrialReviewWrite(sheet, to: sheetURL)
            grayscaleSheetRecords.append([
                "lod": lod,
                "file": industrialReviewRelative(sheetURL, root: root),
                "sha256": try industrialReviewSHA256(sheetURL),
                "commonCrop": [
                    Int(crop.origin.x),
                    Int(crop.origin.y),
                    Int(crop.width),
                    Int(crop.height),
                ],
                "sheetPixels": [sheet.width, sheet.height],
                "layout":
                    "N/E/S/W row-major; common occupied union plus eight source pixels; no interpolation",
            ])
        }

        let acceptedReviewRoot = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/commercial-l01-l04/l04/diagnostics/schema2-sampling-regression-v03/full-regression/review"
        )
        let industrialReviewRoot = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l01/l01/source-v05-candidate/review"
        )
        let familyOrder = [
            "accepted-residential-l01",
            "accepted-commercial-l01",
            "industrial-l01-source-v05-candidate",
        ]
        let colorURLs = [
            acceptedReviewRoot.appendingPathComponent(
                "residential_l01/FOOTPRINT-NATIVE-2X-COLOR.png"
            ),
            acceptedReviewRoot.appendingPathComponent(
                "commercial_l01/FOOTPRINT-NATIVE-2X-COLOR.png"
            ),
            industrialReviewRoot.appendingPathComponent(
                "FOOTPRINT-NATIVE-2X-COLOR.png"
            ),
        ]
        let grayscaleURLs = [
            acceptedReviewRoot.appendingPathComponent(
                "residential_l01/FOOTPRINT-NATIVE-2X-GRAYSCALE.png"
            ),
            acceptedReviewRoot.appendingPathComponent(
                "commercial_l01/FOOTPRINT-NATIVE-2X-GRAYSCALE.png"
            ),
            industrialReviewRoot.appendingPathComponent(
                "FOOTPRINT-NATIVE-2X-GRAYSCALE.png"
            ),
        ]
        let comparisonColorURL = outputDirectory.appendingPathComponent(
            "CROSS-FAMILY-NATIVE-2X-COLOR.png"
        )
        let comparisonGrayscaleURL = outputDirectory.appendingPathComponent(
            "CROSS-FAMILY-NATIVE-2X-GRAYSCALE.png"
        )
        try industrialReviewWrite(
            try industrialReviewFamilySheet(
                images: try colorURLs.map(industrialReviewImage)
            ),
            to: comparisonColorURL
        )
        try industrialReviewWrite(
            try industrialReviewFamilySheet(
                images: try grayscaleURLs.map(industrialReviewImage)
            ),
            to: comparisonGrayscaleURL
        )

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l01",
            "sourceRevision": "source-v05",
            "purpose":
                "prove dark-palette grayscale separation at every normalized LOD and expose cross-family silhouette comparison",
            "directionOrder": directions,
            "lodOrder": lods,
            "valueMethod": [
                "pixels": "fully opaque normalized-alpha pixels only",
                "luma":
                    "deterministic Rec.709 integer weights 54/183/19",
                "darkPalette": "median luma below 128",
                "valueSeparation":
                    "p95 >= 96, p95-p05 >= 80, and at least eight materially populated 16-step luma bands; interquartile range remains disclosed but is not a gate because the authored dark wall mass intentionally dominates",
            ],
            "valueRecords": valueRecords,
            "allValueChecksPassed": allValueChecksPassed,
            "grayscaleOriginalPixelSheets": grayscaleSheetRecords,
            "crossFamilyComparison": [
                "order": familyOrder,
                "basis":
                    "literal normalized-alpha footprint native-2x sheets from the accepted schema-2 v3 regression and the Industrial L1 candidate",
                "color": [
                    "file": industrialReviewRelative(
                        comparisonColorURL,
                        root: root
                    ),
                    "sha256": try industrialReviewSHA256(
                        comparisonColorURL
                    ),
                ],
                "grayscale": [
                    "file": industrialReviewRelative(
                        comparisonGrayscaleURL,
                        root: root
                    ),
                    "sha256": try industrialReviewSHA256(
                        comparisonGrayscaleURL
                    ),
                ],
            ],
            "productionSelected": false,
            "passed": allValueChecksPassed,
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        try data.write(
            to: outputDirectory.appendingPathComponent(
                "VALUE-AND-CROSS-FAMILY.json"
            ),
            options: .atomic
        )
        if !allValueChecksPassed {
            throw IndustrialReviewEvidenceError.invalid(
                "one or more normalized LODs failed grayscale value separation"
            )
        }
    }
}
