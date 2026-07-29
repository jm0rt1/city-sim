import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL2V5RawReviewError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l2-v5-raw-review --repository-root <path> --output-directory <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct RawReviewImage {
    let id: String
    let url: URL
    let image: CGImage
    let rgba: [UInt8]
}

private func rawReviewArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        throw IndustrialL2V5RawReviewError.arguments
    }
    return arguments[index + 1]
}

private func rawReviewOptionalArgument(
    _ name: String,
    in arguments: [String]
) -> String? {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        return nil
    }
    return arguments[index + 1]
}

private func rawReviewSHA256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map {
        String(format: "%02x", $0)
    }.joined()
}

private func rawReviewRelative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

private func rawReviewLoad(id: String, url: URL) throws -> RawReviewImage {
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
        throw IndustrialL2V5RawReviewError.invalid(
            "could not decode 1536x1024 raw \(url.path)"
        )
    }
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    try rgba.withUnsafeMutableBytes { storage in
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
            throw IndustrialL2V5RawReviewError.invalid(
                "could not allocate raw review decoder"
            )
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return RawReviewImage(id: id, url: url, image: image, rgba: rgba)
}

private func rawReviewMasked(_ source: RawReviewImage) throws -> CGImage {
    var bytes = source.rgba
    for pixel in stride(from: 0, to: bytes.count, by: 4) {
        if
            bytes[pixel] == 255,
            bytes[pixel + 1] == 0,
            bytes[pixel + 2] == 255
        {
            bytes[pixel] = 0
            bytes[pixel + 1] = 0
            bytes[pixel + 2] = 0
            bytes[pixel + 3] = 0
        } else if
            bytes[pixel + 1] == 0,
            abs(Int(bytes[pixel]) - Int(bytes[pixel + 2])) <= 8,
            bytes[pixel] >= 96,
            bytes[pixel + 2] >= 96
        {
            let alpha = max(
                0,
                255 - max(Int(bytes[pixel]), Int(bytes[pixel + 2]))
            )
            bytes[pixel] = 0
            bytes[pixel + 1] = 0
            bytes[pixel + 2] = 0
            bytes[pixel + 3] = UInt8(alpha)
        }
    }
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    return try bytes.withUnsafeMutableBytes { storage in
        guard
            let context = CGContext(
                data: storage.baseAddress,
                width: source.image.width,
                height: source.image.height,
                bitsPerComponent: 8,
                bytesPerRow: source.image.width * 4,
                space: colorSpace,
                bitmapInfo:
                    CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            let image = context.makeImage()
        else {
            throw IndustrialL2V5RawReviewError.invalid(
                "could not create exact-chroma-masked review image"
            )
        }
        return image
    }
}

private func rawReviewGrayscale(_ image: CGImage) throws -> CGImage {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    return try bytes.withUnsafeMutableBytes { storage in
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
            throw IndustrialL2V5RawReviewError.invalid(
                "could not allocate grayscale review image"
            )
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
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
        guard let result = context.makeImage() else {
            throw IndustrialL2V5RawReviewError.invalid(
                "could not create grayscale review output"
            )
        }
        return result
    }
}

private func rawReviewSheet(
    images: [CGImage],
    columns: Int,
    panel: CGSize,
    gutter: Int = 12,
    interpolation: CGInterpolationQuality = .none
) throws -> CGImage {
    let rows = Int(ceil(Double(images.count) / Double(columns)))
    let width = Int(panel.width) * columns + gutter * (columns - 1)
    let height = Int(panel.height) * rows + gutter * (rows - 1)
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
        throw IndustrialL2V5RawReviewError.invalid(
            "could not allocate raw review sheet"
        )
    }
    context.setFillColor(
        CGColor(
            colorSpace: colorSpace,
            components: [0.11, 0.12, 0.13, 1]
        )!
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = interpolation
    for (index, image) in images.enumerated() {
        let column = index % columns
        let row = index / columns
        let x = column * (Int(panel.width) + gutter)
        let y = height - (row + 1) * Int(panel.height) - row * gutter
        context.draw(
            image,
            in: CGRect(x: x, y: y, width: Int(panel.width), height: Int(panel.height))
        )
    }
    guard let output = context.makeImage() else {
        throw IndustrialL2V5RawReviewError.invalid(
            "could not create raw review sheet"
        )
    }
    return output
}

private func rawReviewWrite(_ image: CGImage, to url: URL) throws {
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
        throw IndustrialL2V5RawReviewError.invalid(
            "could not create review PNG destination"
        )
    }
    CGImageDestinationAddImage(destination, image, [
        kCGImagePropertyPNGInterlaceType: 0,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL2V5RawReviewError.invalid(
            "could not finalize review PNG"
        )
    }
}

private func rawReviewCrop(
    _ image: CGImage,
    rect: CGRect
) throws -> CGImage {
    guard let cropped = image.cropping(to: rect) else {
        throw IndustrialL2V5RawReviewError.invalid(
            "could not crop registered raw envelope"
        )
    }
    return cropped
}

private func rawReviewValueRecord(
    _ source: RawReviewImage,
    root: URL
) -> [String: Any] {
    var histogram = [Int](repeating: 0, count: 256)
    var count = 0
    for pixel in stride(from: 0, to: source.rgba.count, by: 4) {
        let red = Int(source.rgba[pixel])
        let green = Int(source.rgba[pixel + 1])
        let blue = Int(source.rgba[pixel + 2])
        if red == 255 && green == 0 && blue == 255 {
            continue
        }
        let luma = min(255, (54 * red + 183 * green + 19 * blue + 128) >> 8)
        histogram[luma] += 1
        count += 1
    }
    func quantile(_ fraction: Double) -> Int {
        let target = Int(floor(Double(max(0, count - 1)) * fraction))
        var accumulated = 0
        for (value, population) in histogram.enumerated() {
            accumulated += population
            if accumulated > target { return value }
        }
        return 255
    }
    let p05 = quantile(0.05)
    let p25 = quantile(0.25)
    let p50 = quantile(0.50)
    let p75 = quantile(0.75)
    let p95 = quantile(0.95)
    return [
        "id": source.id,
        "file": rawReviewRelative(source.url, root: root),
        "nonChromaPixelCount": count,
        "lumaQuantiles": [
            "p05": p05,
            "p25": p25,
            "p50": p50,
            "p75": p75,
            "p95": p95,
        ],
        "p95MinusP05": p95 - p05,
        "p75MinusP25": p75 - p25,
    ]
}

private func rawReviewJSON(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

@main
enum BuildIndustrialL2V5RawReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try rawReviewArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputDirectory = URL(
            fileURLWithPath: try rawReviewArgument(
                "--output-directory",
                in: arguments
            )
        ).standardizedFileURL
        let candidateStem =
            rawReviewOptionalArgument(
                "--candidate-stem",
                in: arguments
            ) ?? "source-v05"
        let candidateRevision =
            rawReviewOptionalArgument(
                "--candidate-revision",
                in: arguments
            ) ?? "source-v05"
        let offlineRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027"
        )
        let directions = ["north", "east", "south", "west"]
        let candidates = try directions.map { direction in
            try rawReviewLoad(
                id: "industrial-l02-\(candidateRevision)-\(direction)",
                url: offlineRoot.appendingPathComponent(
                    "raw/industrial_l02/variant-0/\(direction)/\(candidateStem).png"
                )
            )
        }
        let acceptedL1 = try directions.map { direction in
            try rawReviewLoad(
                id: "accepted-industrial-l01-source-v05-\(direction)",
                url: offlineRoot.appendingPathComponent(
                    "raw/industrial_l01/variant-0/\(direction)/source-v05.png"
                )
            )
        }
        let rejectedCurrentEast = try rawReviewLoad(
            id: "rejected-industrial-l02-source-v04-east",
            url: offlineRoot.appendingPathComponent(
                "raw/industrial_l02/variant-0/east/source-v04.png"
            )
        )
        let rejectedFlatEast = try rawReviewLoad(
            id: "rejected-industrial-l02-source-v04-east-constant-unlit-diagnostic",
            url: root.appendingPathComponent(
                "docs/production/evidence/PLAY-027/industrial-l02/l02/source-v04-candidate/diagnostics/constant-unlit/east-run-a.png"
            )
        )
        let candidateMasked = try candidates.map(rawReviewMasked)
        let acceptedMasked = try acceptedL1.map(rawReviewMasked)
        let registeredCrop = CGRect(x: 512, y: 270, width: 513, height: 695)
        let candidateCrops = try candidateMasked.map {
            try rawReviewCrop($0, rect: registeredCrop)
        }
        let acceptedCrops = try acceptedMasked.map {
            try rawReviewCrop($0, rect: registeredCrop)
        }
        let nativePanel = CGSize(width: 144, height: 195)

        let sourceScaleURL = outputDirectory.appendingPathComponent(
            "SOURCE-SCALE-NESW.png"
        )
        let nativeColorURL = outputDirectory.appendingPathComponent(
            "NATIVE-2X-COLOR-NESW.png"
        )
        let nativeGrayscaleURL = outputDirectory.appendingPathComponent(
            "NATIVE-2X-GRAYSCALE-NESW.png"
        )
        let familyColorURL = outputDirectory.appendingPathComponent(
            "INDUSTRIAL-L1-VS-L2-NATIVE-2X-COLOR.png"
        )
        let familyGrayscaleURL = outputDirectory.appendingPathComponent(
            "INDUSTRIAL-L1-VS-L2-NATIVE-2X-GRAYSCALE.png"
        )
        let lightingColorURL = outputDirectory.appendingPathComponent(
            "EAST-V05-VS-V04-VS-FLATTENED-COLOR.png"
        )
        let lightingGrayscaleURL = outputDirectory.appendingPathComponent(
            "EAST-V05-VS-V04-VS-FLATTENED-GRAYSCALE.png"
        )
        let northTripletArguments = [
            rawReviewOptionalArgument(
                "--north-primary",
                in: arguments
            ),
            rawReviewOptionalArgument(
                "--north-repeat-b",
                in: arguments
            ),
            rawReviewOptionalArgument(
                "--north-repeat-c",
                in: arguments
            ),
        ]
        let northTriplet: [RawReviewImage]? =
            northTripletArguments.allSatisfy { $0 != nil }
            ? try zip(
                ["north-primary", "north-repeat-b", "north-repeat-c"],
                northTripletArguments.compactMap { $0 }
            ).map { id, path in
                try rawReviewLoad(
                    id: id,
                    url: URL(fileURLWithPath: path).standardizedFileURL
                )
            }
            : nil
        let northTripletColorURL = outputDirectory.appendingPathComponent(
            "NORTH-A-B-C-NATIVE-2X-COLOR.png"
        )
        let northTripletGrayscaleURL =
            outputDirectory.appendingPathComponent(
                "NORTH-A-B-C-NATIVE-2X-GRAYSCALE.png"
            )
        try rawReviewWrite(
            try rawReviewSheet(
                images: candidates.map(\.image),
                columns: 2,
                panel: CGSize(width: 1536, height: 1024),
                gutter: 0
            ),
            to: sourceScaleURL
        )
        try rawReviewWrite(
            try rawReviewSheet(
                images: candidateCrops,
                columns: 2,
                panel: nativePanel
            ),
            to: nativeColorURL
        )
        try rawReviewWrite(
            try rawReviewSheet(
                images: try candidateCrops.map(rawReviewGrayscale),
                columns: 2,
                panel: nativePanel
            ),
            to: nativeGrayscaleURL
        )
        var familyColor: [CGImage] = []
        for index in directions.indices {
            familyColor.append(acceptedCrops[index])
            familyColor.append(candidateCrops[index])
        }
        try rawReviewWrite(
            try rawReviewSheet(
                images: familyColor,
                columns: 2,
                panel: nativePanel
            ),
            to: familyColorURL
        )
        try rawReviewWrite(
            try rawReviewSheet(
                images: try familyColor.map(rawReviewGrayscale),
                columns: 2,
                panel: nativePanel
            ),
            to: familyGrayscaleURL
        )
        let lightingSources = [
            candidates[1],
            rejectedCurrentEast,
            rejectedFlatEast,
        ]
        let lightingCrops = try lightingSources.map {
            try rawReviewCrop(
                try rawReviewMasked($0),
                rect: registeredCrop
            )
        }
        try rawReviewWrite(
            try rawReviewSheet(
                images: lightingCrops,
                columns: 3,
                panel: CGSize(width: 288, height: 390)
            ),
            to: lightingColorURL
        )
        try rawReviewWrite(
            try rawReviewSheet(
                images: try lightingCrops.map(rawReviewGrayscale),
                columns: 3,
                panel: CGSize(width: 288, height: 390)
            ),
            to: lightingGrayscaleURL
        )
        if let northTriplet {
            let northTripletCrops = try northTriplet.map {
                try rawReviewCrop(
                    try rawReviewMasked($0),
                    rect: registeredCrop
                )
            }
            try rawReviewWrite(
                try rawReviewSheet(
                    images: northTripletCrops,
                    columns: 3,
                    panel: nativePanel
                ),
                to: northTripletColorURL
            )
            try rawReviewWrite(
                try rawReviewSheet(
                    images: try northTripletCrops.map(rawReviewGrayscale),
                    columns: 3,
                    panel: nativePanel
                ),
                to: northTripletGrayscaleURL
            )
        }

        var files = [
            ("sourceScale", sourceScaleURL),
            ("native2xColor", nativeColorURL),
            ("native2xGrayscale", nativeGrayscaleURL),
            ("industrialL1VsL2Color", familyColorURL),
            ("industrialL1VsL2Grayscale", familyGrayscaleURL),
            ("eastLightingComparisonColor", lightingColorURL),
            ("eastLightingComparisonGrayscale", lightingGrayscaleURL),
        ]
        if northTriplet != nil {
            files.append(
                ("northABCNative2xColor", northTripletColorURL)
            )
            files.append(
                ("northABCNative2xGrayscale", northTripletGrayscaleURL)
            )
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l02",
            "sourceRevision": candidateRevision,
            "purpose":
                "review-only raw-gate panels after deterministic identity failure; no normalization",
            "directionOrder": directions,
            "sourceScaleLayout": [
                "order": directions,
                "presentation": "exact retained raw PNG on exact #ff00ff field",
            ],
            "native2xLayout": [
                "order": directions,
                "registeredRawCrop": [512, 270, 513, 695],
                "panelPixels": [144, 195],
                "scale": 0.28125,
                "presentation":
                    "task-owned review-only exact-chroma mask plus frozen magenta-edge alpha preview on neutral field; no normalized output created",
            ],
            "familyComparisonLayout": [
                "columns": [
                    "accepted Industrial L1 source-v05",
                    "rejected Industrial L2 \(candidateRevision) raw attempt",
                ],
                "rows": directions,
            ],
            "lightingComparisonLayout": [
                "columns": [
                    "Industrial L2 \(candidateRevision) East",
                    "rejected Industrial L2 source-v04 East current lighting",
                    "rejected Industrial L2 source-v04 East flattened constant-unlit diagnostic",
                ],
            ],
            "northABCLayout": northTriplet == nil
                ? NSNull()
                : [
                    "columns": [
                        "North primary",
                        "North repeat B",
                        "North repeat C",
                    ],
                    "registeredRawCrop": [512, 270, 513, 695],
                    "panelPixels": [144, 195],
                    "presentation":
                        "exact retained PNG decoded through ImageIO, exact chroma masked transparent, alpha retained, native-2x scale on neutral field",
                ],
            "valueEvidence": (
                candidates
                + [rejectedCurrentEast, rejectedFlatEast]
            ).map {
                rawReviewValueRecord($0, root: root)
            },
            "files": try files.map { role, url in
                [
                    "role": role,
                    "file": rawReviewRelative(url, root: root),
                    "sha256": try rawReviewSHA256(url),
                ]
            },
            "rawGateIdentityPassed": false,
            "normalizationPerformed": false,
            "productionSelected": false,
            "reviewStatus": "rejected-technical-gate-pending-integration-disposition",
        ]
        try rawReviewJSON(report).write(
            to: outputDirectory.appendingPathComponent(
                "RAW-REVIEW-MANIFEST.json"
            ),
            options: .atomic
        )
    }
}
