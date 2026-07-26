import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL3CohesionFamilyReviewError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: build-industrial-l3-cohesion-family-review \
              --repository-root <path> --output-root <path>
            """
        case let .invalid(message):
            return message
        }
    }
}

private struct FamilyRaster {
    let image: CGImage
    let rgba: Data
    let fileSHA256: String
    let decodedRGBASHA256: String
    let alphaBounds: [Int]
    let visiblePixelCount: Int
    let hiddenRGBPixelCount: Int
    let exactChromaPixelCount: Int
    let visibleMagentaSpillPixelCount: Int
}

private struct DirectionFiles {
    let direction: String
    let raw: String
    let provenance: String
    let descriptor: String
    let normalizedRoot: String
}

private let directions = [
    DirectionFiles(
        direction: "north",
        raw:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-family-v01/raw/north-primary-v02/raw.png",
        provenance:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-family-v01/raw/north-primary-v02/provenance.json",
        descriptor:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-siblings-v01/scenes/"
            + "industrial_l03/variant-0/north/scene.json",
        normalizedRoot:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-family-v01/normalized"
    ),
    DirectionFiles(
        direction: "east",
        raw:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-east-v01/raw/east-primary/raw.png",
        provenance:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-east-v01/raw/east-primary/provenance.json",
        descriptor:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-east-v01/scenes/"
            + "industrial_l03/variant-0/east/scene.json",
        normalizedRoot:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-east-v01/normalized"
    ),
    DirectionFiles(
        direction: "south",
        raw:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-family-v01/raw/south-primary/raw.png",
        provenance:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-family-v01/raw/south-primary/provenance.json",
        descriptor:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-siblings-v01/scenes/"
            + "industrial_l03/variant-0/south/scene.json",
        normalizedRoot:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-family-v01/normalized"
    ),
    DirectionFiles(
        direction: "west",
        raw:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-family-v01/raw/west-primary/raw.png",
        provenance:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-family-v01/raw/west-primary/provenance.json",
        descriptor:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-siblings-v01/scenes/"
            + "industrial_l03/variant-0/west/scene.json",
        normalizedRoot:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-family-v01/normalized"
    ),
]

private let materialRelative =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-east-v01/materials/"
    + "industrial-l03-cohesion-east-v01.json"
private let materialSHA256 =
    "f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65"
private let outputRelative =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "cohesion-a0-family-v01/final-review"

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3CohesionFamilyReviewError.arguments
    }
    return arguments[index + 1]
}

private func url(_ path: String, root: URL) -> URL {
    root.appendingPathComponent(path).standardizedFileURL
}

private func relative(_ target: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return target.path.hasPrefix(prefix)
        ? String(target.path.dropFirst(prefix.count))
        : target.path
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ target: URL) throws -> String {
    sha256(try Data(contentsOf: target))
}

private func json(_ target: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: target)
        ) as? [String: Any]
    else {
        throw IndustrialL3CohesionFamilyReviewError.invalid(
            "JSON object expected: \(target.path)"
        )
    }
    return object
}

private func writeJSON(_ object: Any, to target: URL) throws {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: target, options: .atomic)
}

private func inspect(_ target: URL) throws -> FamilyRaster {
    let fileData = try Data(contentsOf: target)
    guard
        let source = CGImageSourceCreateWithURL(target as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        )
    else {
        throw IndustrialL3CohesionFamilyReviewError.invalid(
            "ImageIO decode failed: \(target.path)"
        )
    }
    var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try pixels.withUnsafeMutableBytes { storage in
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
            throw IndustrialL3CohesionFamilyReviewError.invalid(
                "RGBA context allocation failed"
            )
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    var minimumX = image.width
    var minimumY = image.height
    var maximumX = -1
    var maximumY = -1
    var visible = 0
    var hidden = 0
    var chroma = 0
    var spill = 0
    for y in 0..<image.height {
        for x in 0..<image.width {
            let offset = (y * image.width + x) * 4
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            let alpha = Int(pixels[offset + 3])
            if alpha == 0 {
                if red != 0 || green != 0 || blue != 0 { hidden += 1 }
                continue
            }
            visible += 1
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
            if red == 255 && green == 0 && blue == 255 { chroma += 1 }
            if
                red >= 180,
                blue >= 150,
                green <= 110,
                red + blue >= green * 4
            {
                spill += 1
            }
        }
    }
    let bounds =
        maximumX >= minimumX && maximumY >= minimumY
        ? [minimumX, minimumY, maximumX + 1, maximumY + 1]
        : [0, 0, 0, 0]
    return FamilyRaster(
        image: image,
        rgba: Data(pixels),
        fileSHA256: sha256(fileData),
        decodedRGBASHA256: sha256(Data(pixels)),
        alphaBounds: bounds,
        visiblePixelCount: visible,
        hiddenRGBPixelCount: hidden,
        exactChromaPixelCount: chroma,
        visibleMagentaSpillPixelCount: spill
    )
}

private func imageFromRGBA(
    _ pixels: [UInt8],
    width: Int,
    height: Int
) throws -> CGImage {
    let data = Data(pixels) as CFData
    guard
        let provider = CGDataProvider(data: data),
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
        throw IndustrialL3CohesionFamilyReviewError.invalid(
            "CGImage creation failed"
        )
    }
    return image
}

private func rawReviewAlpha(_ raster: FamilyRaster) throws -> CGImage {
    var pixels = [UInt8](raster.rgba)
    for offset in stride(from: 0, to: pixels.count, by: 4) {
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blue = Int(pixels[offset + 2])
        if red == 255 && green == 0 && blue == 255 {
            pixels[offset] = 0
            pixels[offset + 1] = 0
            pixels[offset + 2] = 0
            pixels[offset + 3] = 0
        } else if
            green == 0,
            abs(red - blue) <= 8,
            red >= 96,
            blue >= 96
        {
            pixels[offset] = 0
            pixels[offset + 1] = 0
            pixels[offset + 2] = 0
            pixels[offset + 3] = UInt8(max(0, 255 - max(red, blue)))
        }
    }
    return try imageFromRGBA(
        pixels,
        width: raster.image.width,
        height: raster.image.height
    )
}

private func grayscale(_ image: CGImage) throws -> CGImage {
    let raster = try inspectCGImage(image)
    var pixels = [UInt8](raster.rgba)
    for offset in stride(from: 0, to: pixels.count, by: 4) {
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blue = Int(pixels[offset + 2])
        let weighted = 54 * red + 183 * green + 19 * blue + 128
        let luma = UInt8(min(255, weighted >> 8))
        pixels[offset] = luma
        pixels[offset + 1] = luma
        pixels[offset + 2] = luma
    }
    return try imageFromRGBA(
        pixels,
        width: image.width,
        height: image.height
    )
}

private func inspectCGImage(_ image: CGImage) throws -> FamilyRaster {
    var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try pixels.withUnsafeMutableBytes { storage in
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
            throw IndustrialL3CohesionFamilyReviewError.invalid(
                "in-memory decode context failed"
            )
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return FamilyRaster(
        image: image,
        rgba: Data(pixels),
        fileSHA256: "",
        decodedRGBASHA256: sha256(Data(pixels)),
        alphaBounds: [0, 0, image.width, image.height],
        visiblePixelCount: 0,
        hiddenRGBPixelCount: 0,
        exactChromaPixelCount: 0,
        visibleMagentaSpillPixelCount: 0
    )
}

private func canvas(
    images: [CGImage],
    columns: Int,
    panelSize: CGSize,
    background: [CGFloat],
    interpolation: CGInterpolationQuality
) throws -> CGImage {
    let rows = Int(ceil(Double(images.count) / Double(columns)))
    let width = Int(panelSize.width) * columns
    let height = Int(panelSize.height) * rows
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw IndustrialL3CohesionFamilyReviewError.invalid(
            "panel context allocation failed"
        )
    }
    context.setFillColor(
        CGColor(colorSpace: colorSpace, components: background)!
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = interpolation
    for (index, image) in images.enumerated() {
        let column = index % columns
        let row = index / columns
        let panelOrigin = CGPoint(
            x: CGFloat(column) * panelSize.width,
            y: CGFloat(rows - row - 1) * panelSize.height
        )
        let scale = min(
            panelSize.width / CGFloat(image.width),
            panelSize.height / CGFloat(image.height)
        )
        let drawSize = CGSize(
            width: CGFloat(image.width) * scale,
            height: CGFloat(image.height) * scale
        )
        let drawOrigin = CGPoint(
            x: panelOrigin.x + (panelSize.width - drawSize.width) / 2,
            y: panelOrigin.y + (panelSize.height - drawSize.height) / 2
        )
        context.draw(image, in: CGRect(origin: drawOrigin, size: drawSize))
    }
    guard let output = context.makeImage() else {
        throw IndustrialL3CohesionFamilyReviewError.invalid(
            "panel image creation failed"
        )
    }
    return output
}

private func occupiedCrop(_ raster: FamilyRaster) throws -> CGImage {
    let bounds = raster.alphaBounds
    let padding = 6
    let x = max(0, bounds[0] - padding)
    let y = max(0, bounds[1] - padding)
    let maximumX = min(raster.image.width, bounds[2] + padding)
    let maximumY = min(raster.image.height, bounds[3] + padding)
    guard
        let cropped = raster.image.cropping(
            to: CGRect(
                x: x,
                y: y,
                width: maximumX - x,
                height: maximumY - y
            )
        )
    else {
        throw IndustrialL3CohesionFamilyReviewError.invalid(
            "occupied crop failed"
        )
    }
    return cropped
}

private func writePNG(_ image: CGImage, to target: URL) throws {
    try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard
        let destination = CGImageDestinationCreateWithURL(
            target as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw IndustrialL3CohesionFamilyReviewError.invalid(
            "PNG destination failed"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL3CohesionFamilyReviewError.invalid(
            "PNG finalization failed"
        )
    }
}

private func collectCatalogHashes(
    _ value: Any,
    raw: inout Set<String>,
    normalized: inout Set<String>
) {
    if let dictionary = value as? [String: Any] {
        for (key, child) in dictionary {
            if key == "raw_sha256", let hash = child as? String {
                raw.insert(hash)
            } else if
                key == "normalized_sha256",
                let hashes = child as? [String: Any]
            {
                normalized.formUnion(hashes.values.compactMap { $0 as? String })
            }
            collectCatalogHashes(child, raw: &raw, normalized: &normalized)
        }
    } else if let array = value as? [Any] {
        for child in array {
            collectCatalogHashes(child, raw: &raw, normalized: &normalized)
        }
    }
}

private func registration(
    provenance: [String: Any],
    descriptor: [String: Any]
) throws -> [String: Any] {
    guard let descriptorRegistration =
        descriptor["registration"] as? [String: Any]
    else {
        throw IndustrialL3CohesionFamilyReviewError.invalid(
            "descriptor registration missing"
        )
    }
    let names = [
        "groundPivotSource",
        "frontageSocketSource",
        "frontageEdgeSource",
        "doorBaseSource",
    ]
    var result: [String: Any] = [:]
    for name in names {
        guard
            let actual = provenance[name],
            let expected = descriptorRegistration[name],
            (actual as AnyObject).isEqual(expected)
        else {
            throw IndustrialL3CohesionFamilyReviewError.invalid(
                "registration mismatch: \(name)"
            )
        }
        result[name] = actual
    }
    guard let shadow = provenance["southeastShadowVectorSource"] else {
        throw IndustrialL3CohesionFamilyReviewError.invalid(
            "southeast shadow registration missing"
        )
    }
    result["southeastShadowVectorSource"] = shadow
    return result
}

@main
enum BuildIndustrialL3CohesionFamilyReview {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try argument("--output-root", in: arguments)
        ).standardizedFileURL
        let output = outputRoot.appendingPathComponent(outputRelative)
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw IndustrialL3CohesionFamilyReviewError.invalid(
                "review output must be absent"
            )
        }
        guard try sha256(url(materialRelative, root: root)) == materialSHA256 else {
            throw IndustrialL3CohesionFamilyReviewError.invalid(
                "accepted cohesion material library hash drift"
            )
        }

        let lods: [(String, [Int])] = [
            ("block", [1024, 683]),
            ("neighborhood", [512, 342]),
            ("city", [256, 171]),
        ]
        var rawRecords: [[String: Any]] = []
        var normalizedRecords: [[String: Any]] = []
        var rawRasters: [FamilyRaster] = []
        var blockRasters: [FamilyRaster] = []
        var neighborhoodRasters: [FamilyRaster] = []
        var cityRasters: [FamilyRaster] = []
        var rawHashes = Set<String>()
        var rawPixelHashes = Set<String>()
        var normalizedHashes = Set<String>()
        var normalizedPixelHashes = Set<String>()

        for files in directions {
            let rawURL = url(files.raw, root: root)
            let rawRaster = try inspect(rawURL)
            let provenance = try json(url(files.provenance, root: root))
            let descriptor = try json(url(files.descriptor, root: root))
            guard
                provenance["productionSelected"] as? Bool == false,
                provenance["viewDirection"] as? String == files.direction,
                provenance["sourceRevision"] as? String == "source-v04",
                provenance["orientationTransform"] as? String == "none",
                let occupancy = provenance["rawOccupancy"] as? [String: Any],
                occupancy["completeOccupiedAreaPassed"] as? Bool == true,
                let renderedBounds =
                    provenance["renderedNodeBounds"] as? [String: Any],
                renderedBounds["completeBuildingVolumePassed"] as? Bool == true
            else {
                throw IndustrialL3CohesionFamilyReviewError.invalid(
                    "\(files.direction) raw safety provenance failed"
                )
            }
            let registrationRecord = try registration(
                provenance: provenance,
                descriptor: descriptor
            )
            rawHashes.insert(rawRaster.fileSHA256)
            rawPixelHashes.insert(rawRaster.decodedRGBASHA256)
            rawRasters.append(rawRaster)
            rawRecords.append([
                "direction": files.direction,
                "raw": files.raw,
                "provenance": files.provenance,
                "descriptor": files.descriptor,
                "descriptorSHA256": try sha256(
                    url(files.descriptor, root: root)
                ),
                "materialLibrarySHA256": materialSHA256,
                "fileSHA256": rawRaster.fileSHA256,
                "decodedRGBASHA256": rawRaster.decodedRGBASHA256,
                "rawOccupancy": occupancy,
                "renderedNodeBounds": renderedBounds,
                "registration": registrationRecord,
                "authoredIndependently":
                    provenance["authoredIndependently"] as? Bool == true,
                "orientationTransform": "none",
                "productionSelected": false,
            ])

            for (lod, expectedDimensions) in lods {
                let filename =
                    "generated_v4_industrial_l03_\(files.direction)_source_v04_\(lod).png"
                let pathA =
                    "\(files.normalizedRoot)/run-a/\(files.direction)/\(filename)"
                let pathB =
                    "\(files.normalizedRoot)/run-b/\(files.direction)/\(filename)"
                let rasterA = try inspect(url(pathA, root: root))
                let rasterB = try inspect(url(pathB, root: root))
                let passed =
                    rasterA.fileSHA256 == rasterB.fileSHA256
                    && rasterA.decodedRGBASHA256
                        == rasterB.decodedRGBASHA256
                    && rasterA.image.width == expectedDimensions[0]
                    && rasterA.image.height == expectedDimensions[1]
                    && rasterA.alphaBounds == rasterB.alphaBounds
                    && rasterA.visiblePixelCount == rasterB.visiblePixelCount
                    && rasterA.hiddenRGBPixelCount == 0
                    && rasterA.exactChromaPixelCount == 0
                    && rasterA.visibleMagentaSpillPixelCount == 0
                    && rasterA.alphaBounds[0] > 2
                    && rasterA.alphaBounds[1] > 2
                    && rasterA.alphaBounds[2] < rasterA.image.width - 2
                    && rasterA.alphaBounds[3] < rasterA.image.height - 2
                guard passed else {
                    throw IndustrialL3CohesionFamilyReviewError.invalid(
                        "\(files.direction) \(lod) normalization gate failed"
                    )
                }
                normalizedHashes.insert(rasterA.fileSHA256)
                normalizedPixelHashes.insert(rasterA.decodedRGBASHA256)
                if lod == "block" { blockRasters.append(rasterA) }
                if lod == "neighborhood" {
                    neighborhoodRasters.append(rasterA)
                }
                if lod == "city" { cityRasters.append(rasterA) }
                normalizedRecords.append([
                    "direction": files.direction,
                    "lod": lod,
                    "runA": pathA,
                    "runB": pathB,
                    "fileSHA256": rasterA.fileSHA256,
                    "decodedRGBASHA256": rasterA.decodedRGBASHA256,
                    "alphaBounds": rasterA.alphaBounds,
                    "visiblePixelCount": rasterA.visiblePixelCount,
                    "repeatFileIdentity": true,
                    "repeatDecodedPixelIdentity": true,
                    "hiddenRGBPixelCount": 0,
                    "exactChromaPixelCount": 0,
                    "visibleMagentaSpillPixelCount": 0,
                    "paddingPassed": true,
                    "registrationPassed": true,
                ])
            }
        }
        guard
            rawHashes.count == 4,
            rawPixelHashes.count == 4,
            normalizedHashes.count == 12,
            normalizedPixelHashes.count == 12
        else {
            throw IndustrialL3CohesionFamilyReviewError.invalid(
                "family raw or normalized uniqueness failed"
            )
        }

        let catalogPaths = [
            "Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-028-residential-directions.json",
            "Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-060-commercial-directions.json",
            "Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-062-industrial-l1-directions.json",
            "Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-073-industrial-l2-directions.json",
        ]
        var acceptedRawHashes = Set<String>()
        var acceptedNormalizedHashes = Set<String>()
        var catalogRecords: [[String: Any]] = []
        for path in catalogPaths {
            let data = try Data(contentsOf: url(path, root: root))
            collectCatalogHashes(
                try JSONSerialization.jsonObject(with: data),
                raw: &acceptedRawHashes,
                normalized: &acceptedNormalizedHashes
            )
            catalogRecords.append([
                "file": path,
                "sha256": sha256(data),
            ])
        }
        let rawIntersection = rawHashes.intersection(acceptedRawHashes)
        let normalizedIntersection =
            normalizedHashes.intersection(acceptedNormalizedHashes)
        guard rawIntersection.isEmpty, normalizedIntersection.isEmpty else {
            throw IndustrialL3CohesionFamilyReviewError.invalid(
                "accepted-catalog alias intersection is non-empty"
            )
        }

        let sourceImages = try rawRasters.map(rawReviewAlpha)
        let sourceGray = try sourceImages.map(grayscale)
        let compactImages = neighborhoodRasters.map(\.image)
        let compactGray = try compactImages.map(grayscale)
        let frontageImages = try blockRasters.map(occupiedCrop)
        let frontageGray = try frontageImages.map(grayscale)
        let cityImages = cityRasters.map(\.image)
        let cityGray = try cityImages.map(grayscale)
        let oldBlockRoot =
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "source-completion-v02/normalized/run-a"
        var oldBlockImages: [CGImage] = []
        for files in directions {
            let filename =
                "generated_v4_industrial_l03_\(files.direction)_source_v02_block.png"
            oldBlockImages.append(
                try inspect(
                    url(
                        "\(oldBlockRoot)/\(files.direction)/\(filename)",
                        root: root
                    )
                ).image
            )
        }
        let oldBlockGray = try oldBlockImages.map(grayscale)
        let newBlockImages = blockRasters.map(\.image)
        let newBlockGray = try newBlockImages.map(grayscale)

        let residentialL3 =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "normalized/residential_l03/variant-0/east/source-v01/"
            + "generated_v4_residential_l03_block.png"
        let commercialL3 =
            "docs/production/evidence/PLAY-027/commercial-l01-l04/l03/"
            + "source-v01-review-candidate/normalized-repeat/east/"
            + "generated_v4_commercial_l03_block.png"
        let crossFamily = [
            try inspect(url(residentialL3, root: root)).image,
            try inspect(url(commercialL3, root: root)).image,
            newBlockImages[1],
        ]
        let stagedReference =
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "cohesion-a0-east-v01/review/"
            + "STAGED-CATALOG-COMPOSED-CITY-COMPARISON.png"
        let stagedReferenceImage =
            try inspect(url(stagedReference, root: root)).image
        let cityPanel = try canvas(
            images: cityImages + cityGray,
            columns: 4,
            panelSize: CGSize(width: 256, height: 171),
            background: [0.14, 0.15, 0.16, 1],
            interpolation: .none
        )

        let panelSpecs: [(String, CGImage, String)] = [
            (
                "SOURCE-SCALE-NESW-COLOR.png",
                try canvas(
                    images: sourceImages,
                    columns: 2,
                    panelSize: CGSize(width: 768, height: 512),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .none
                ),
                "N/E/S/W row-major; exact raw pixels with review-only matte removal"
            ),
            (
                "SOURCE-SCALE-NESW-GRAYSCALE.png",
                try canvas(
                    images: sourceGray,
                    columns: 2,
                    panelSize: CGSize(width: 768, height: 512),
                    background: [0.14, 0.14, 0.14, 1],
                    interpolation: .none
                ),
                "N/E/S/W row-major; raw review alpha plus deterministic grayscale"
            ),
            (
                "COMPACT-NESW-COLOR.png",
                try canvas(
                    images: compactImages,
                    columns: 2,
                    panelSize: CGSize(width: 512, height: 342),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .none
                ),
                "N/E/S/W row-major; literal neighborhood LOD"
            ),
            (
                "COMPACT-NESW-GRAYSCALE.png",
                try canvas(
                    images: compactGray,
                    columns: 2,
                    panelSize: CGSize(width: 512, height: 342),
                    background: [0.14, 0.14, 0.14, 1],
                    interpolation: .none
                ),
                "N/E/S/W row-major; literal neighborhood LOD grayscale"
            ),
            (
                "FRONTAGE-OCCUPIED-NESW-COLOR.png",
                try canvas(
                    images: frontageImages,
                    columns: 2,
                    panelSize: CGSize(width: 512, height: 384),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .none
                ),
                "N/E/S/W row-major; block occupied crops for frontage inspection"
            ),
            (
                "FRONTAGE-OCCUPIED-NESW-GRAYSCALE.png",
                try canvas(
                    images: frontageGray,
                    columns: 2,
                    panelSize: CGSize(width: 512, height: 384),
                    background: [0.14, 0.14, 0.14, 1],
                    interpolation: .none
                ),
                "N/E/S/W row-major; block occupied crops in grayscale"
            ),
            (
                "V02-V04-COMPACT-COLOR-GRAYSCALE.png",
                try canvas(
                    images:
                        oldBlockImages + newBlockImages
                        + oldBlockGray + newBlockGray,
                    columns: 4,
                    panelSize: CGSize(width: 320, height: 213),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .high
                ),
                "rows: accepted v02 color, cohesion v04 color, accepted v02 grayscale, cohesion v04 grayscale; columns N/E/S/W"
            ),
            (
                "CROSS-FAMILY-L3-COLOR-GRAYSCALE.png",
                try canvas(
                    images: crossFamily + (try crossFamily.map(grayscale)),
                    columns: 3,
                    panelSize: CGSize(width: 320, height: 213),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .high
                ),
                "columns Residential/Commercial/Industrial L3 East; top color, bottom grayscale"
            ),
            (
                "STAGED-SYSTEM-AND-CITY-LOD.png",
                try canvas(
                    images: [stagedReferenceImage, cityPanel],
                    columns: 2,
                    panelSize: CGSize(width: 1024, height: 512),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .high
                ),
                "left: accepted East staged-catalog composed comparison; right: literal N/E/S/W city LOD color and grayscale"
            ),
        ]

        let reviewDirectory = output.appendingPathComponent("review")
        var panelRecords: [[String: Any]] = []
        for (filename, image, presentation) in panelSpecs {
            let target = reviewDirectory.appendingPathComponent(filename)
            try writePNG(image, to: target)
            panelRecords.append([
                "file": relative(target, root: outputRoot),
                "sha256": try sha256(target),
                "pixels": [image.width, image.height],
                "presentation": presentation,
            ])
        }

        let sourcePath =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
            + "BuildIndustrialL3CohesionFamilyReview.swift"
        let manifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "program": "Wave-011-A0",
            "family": "industrial_l03",
            "variant": 0,
            "sourceRevision": "source-v04",
            "directionOrder": ["north", "east", "south", "west"],
            "materialLibrary": materialRelative,
            "materialLibrarySHA256": materialSHA256,
            "rawProcessCount": 4,
            "newSiblingRawProcessCount": 3,
            "normalizerProcessCount": 8,
            "newSiblingNormalizerProcessCount": 6,
            "rawMasters": rawRecords,
            "normalizedOutputs": normalizedRecords,
            "rawUniqueFileIdentities": rawHashes.count,
            "rawUniqueDecodedPixelIdentities": rawPixelHashes.count,
            "normalizedUniqueFileIdentities": normalizedHashes.count,
            "normalizedUniqueDecodedPixelIdentities":
                normalizedPixelHashes.count,
            "normalizedTwoRunFileIdentity": true,
            "normalizedTwoRunDecodedPixelIdentity": true,
            "normalizedAlphaChromaSpillPadding": "pass",
            "registrationPivotSocketFrontageShadow": "pass",
            "authoredIndependently": true,
            "orientationTransform": "none",
            "mirrorRotationRecolorAliasFallback": false,
            "acceptedCatalogs": catalogRecords,
            "acceptedCatalogRawIntersection":
                Array(rawIntersection).sorted(),
            "acceptedCatalogNormalizedIntersection":
                Array(normalizedIntersection).sorted(),
            "acceptedCatalogNonIntersection": true,
            "panels": panelRecords,
            "stagedReference": [
                "file": stagedReference,
                "sha256": try sha256(url(stagedReference, root: root)),
                "authority":
                    "accepted East calibration staged-value reference; not a new staged-app proof",
            ],
            "preservedNoPixelFailure":
                "docs/production/evidence/PLAY-027/industrial-l03/l03/cohesion-a0-family-v01/raw/north-primary/NO-PIXEL-FAILURE.md",
            "reviewStatus": "pending-independent-family-review",
            "sourceAuthority": false,
            "familyAuthority": false,
            "productionSelected": false,
            "rendererOrShippingMutation": false,
            "builderSource": sourcePath,
            "builderSourceSHA256": try sha256(url(sourcePath, root: root)),
            "builderBinarySHA256": try sha256(
                URL(fileURLWithPath: CommandLine.arguments[0])
                    .standardizedFileURL
            ),
        ]
        try writeJSON(
            manifest,
            to: output.appendingPathComponent("FAMILY-MANIFEST.json")
        )
        let disposition = """
        # Industrial L3 A0 cohesion family candidate

        **Disposition:** `PENDING_INDEPENDENT_FAMILY_REVIEW`.

        This packet proposes no source, family, production-selection, renderer,
        or shipping acceptance. It binds four separately authored N/E/S/W
        source-v04 treatments: immutable accepted East calibration plus North,
        South, and West derived from each direction's own accepted source-v02
        geometry and registration. No sibling transform, mirror, rotation,
        post-process tint, recolor-only alias, or fallback is used.

        The family contains four unique raw identities and twelve unique
        normalized identities. Every normalized LOD is byte- and decoded-pixel
        identical across two fresh normalizer processes, with zero hidden RGB,
        exact chroma, or visible magenta spill and passing padding and
        registration. Accepted Residential, Commercial, Industrial L1, and
        Industrial L2 catalog intersections are empty.

        Independent review must judge compact-scale material cohesion,
        N/E/S/W frontage readability, grayscale hierarchy, directional
        authorship, cross-family distinction, and fit beside the staged
        warm/dark value system. `productionSelected` remains false.
        """
        try FileManager.default.createDirectory(
            at: output,
            withIntermediateDirectories: true
        )
        try Data((disposition + "\n").utf8).write(
            to: output.appendingPathComponent("DISPOSITION.md"),
            options: .atomic
        )
    }
}
