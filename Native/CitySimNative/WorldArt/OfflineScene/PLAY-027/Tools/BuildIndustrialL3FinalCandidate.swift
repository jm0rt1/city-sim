import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL3FinalError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l3-final-candidate --repository-root <path> --output <directory>"
        case let .invalid(message):
            return message
        }
    }
}

struct IndustrialL3FinalRaster {
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

struct IndustrialL3FinalMaster {
    let direction: String
    let path: String
    let provenancePath: String
    let descriptorPath: String
    let authorityCommit: String
    let expectedFileSHA256: String
    let expectedDecodedRGBASHA256: String
    let expectedDescriptorSHA256: String
}

func l3FinalArgument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3FinalError.arguments
    }
    return arguments[index + 1]
}

func l3FinalSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func l3FinalURL(_ path: String, root: URL) -> URL {
    root.appendingPathComponent(path).standardizedFileURL
}

func l3FinalRelative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    guard url.path.hasPrefix(prefix) else {
        return url.path
    }
    return String(url.path.dropFirst(prefix.count))
}

func l3FinalJSON(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL3FinalError.invalid(
            "JSON object expected: \(url.path)"
        )
    }
    return object
}

func l3FinalWriteJSON(_ object: Any, to url: URL) throws {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}

func l3FinalInspect(_ url: URL) throws -> IndustrialL3FinalRaster {
    let fileData = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        )
    else {
        throw IndustrialL3FinalError.invalid(
            "ImageIO decode failed: \(url.path)"
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
            throw IndustrialL3FinalError.invalid(
                "RGBA context allocation failed: \(url.path)"
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
    var visiblePixelCount = 0
    var hiddenRGBPixelCount = 0
    var exactChromaPixelCount = 0
    var visibleMagentaSpillPixelCount = 0
    for y in 0..<image.height {
        for x in 0..<image.width {
            let offset = (y * image.width + x) * 4
            let red = Int(rgba[offset])
            let green = Int(rgba[offset + 1])
            let blue = Int(rgba[offset + 2])
            let alpha = Int(rgba[offset + 3])
            if alpha == 0 {
                if red != 0 || green != 0 || blue != 0 {
                    hiddenRGBPixelCount += 1
                }
                continue
            }
            visiblePixelCount += 1
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
            if red == 255 && green == 0 && blue == 255 {
                exactChromaPixelCount += 1
            }
            if
                red >= 180,
                blue >= 150,
                green <= 110,
                red + blue >= green * 4
            {
                visibleMagentaSpillPixelCount += 1
            }
        }
    }
    let bounds =
        maximumX >= minimumX && maximumY >= minimumY
        ? [minimumX, minimumY, maximumX + 1, maximumY + 1]
        : [0, 0, 0, 0]
    return IndustrialL3FinalRaster(
        image: image,
        rgba: Data(rgba),
        fileSHA256: l3FinalSHA256(fileData),
        decodedRGBASHA256: l3FinalSHA256(Data(rgba)),
        alphaBounds: bounds,
        visiblePixelCount: visiblePixelCount,
        hiddenRGBPixelCount: hiddenRGBPixelCount,
        exactChromaPixelCount: exactChromaPixelCount,
        visibleMagentaSpillPixelCount: visibleMagentaSpillPixelCount
    )
}

func l3FinalGrayscale(_ image: CGImage) throws -> CGImage {
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    return try bytes.withUnsafeMutableBytes { storage in
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
            throw IndustrialL3FinalError.invalid(
                "grayscale context allocation failed"
            )
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
        for offset in stride(from: 0, to: storage.count, by: 4) {
            let red = Int(storage[offset])
            let green = Int(storage[offset + 1])
            let blue = Int(storage[offset + 2])
            let luma = UInt8(
                min(255, (54 * red + 183 * green + 19 * blue + 128) >> 8)
            )
            storage[offset] = luma
            storage[offset + 1] = luma
            storage[offset + 2] = luma
        }
        guard let output = context.makeImage() else {
            throw IndustrialL3FinalError.invalid(
                "grayscale output creation failed"
            )
        }
        return output
    }
}

func l3FinalRawReviewAlpha(_ image: CGImage) throws -> CGImage {
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    return try bytes.withUnsafeMutableBytes { storage in
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
            throw IndustrialL3FinalError.invalid(
                "raw review alpha context allocation failed"
            )
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
        for offset in stride(from: 0, to: storage.count, by: 4) {
            let red = Int(storage[offset])
            let green = Int(storage[offset + 1])
            let blue = Int(storage[offset + 2])
            if red == 255 && green == 0 && blue == 255 {
                storage[offset] = 0
                storage[offset + 1] = 0
                storage[offset + 2] = 0
                storage[offset + 3] = 0
            } else if
                green == 0,
                abs(red - blue) <= 8,
                red >= 96,
                blue >= 96
            {
                let alpha = max(0, 255 - max(red, blue))
                storage[offset] = 0
                storage[offset + 1] = 0
                storage[offset + 2] = 0
                storage[offset + 3] = UInt8(alpha)
            }
        }
        guard let output = context.makeImage() else {
            throw IndustrialL3FinalError.invalid(
                "raw review alpha image creation failed"
            )
        }
        return output
    }
}

func l3FinalCanvas(
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
        throw IndustrialL3FinalError.invalid("panel context allocation failed")
    }
    context.setFillColor(
        CGColor(colorSpace: colorSpace, components: background)!
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = interpolation
    for (index, image) in images.enumerated() {
        let column = index % columns
        let row = index / columns
        let origin = CGPoint(
            x: CGFloat(column) * panelSize.width,
            y: CGFloat(rows - row - 1) * panelSize.height
        )
        context.draw(image, in: CGRect(origin: origin, size: panelSize))
    }
    guard let output = context.makeImage() else {
        throw IndustrialL3FinalError.invalid("panel image creation failed")
    }
    return output
}

func l3FinalCrops(
    _ images: [CGImage],
    rect: CGRect
) throws -> [CGImage] {
    try images.map { image in
        guard let cropped = image.cropping(to: rect) else {
            throw IndustrialL3FinalError.invalid(
                "registered crop exceeds input image"
            )
        }
        return cropped
    }
}

func l3FinalZoomCrops(
    _ rasters: [IndustrialL3FinalRaster]
) throws -> [CGImage] {
    try rasters.map { raster in
        let bounds = raster.alphaBounds
        let padding = 8
        let x = max(0, bounds[0] - padding)
        let y = max(0, bounds[1] - padding)
        let maximumX = min(raster.image.width, bounds[2] + padding)
        let maximumY = min(raster.image.height, bounds[3] + padding)
        let rect = CGRect(
            x: x,
            y: y,
            width: maximumX - x,
            height: maximumY - y
        )
        guard let cropped = raster.image.cropping(to: rect) else {
            throw IndustrialL3FinalError.invalid(
                "occupied zoom crop failed"
            )
        }
        return cropped
    }
}

func l3FinalWritePNG(_ image: CGImage, to url: URL) throws {
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
        throw IndustrialL3FinalError.invalid(
            "PNG destination creation failed: \(url.path)"
        )
    }
    CGImageDestinationAddImage(
        destination,
        image,
        [
            kCGImagePropertyPNGDictionary: [
                kCGImagePropertyPNGInterlaceType: 0,
            ],
            kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
            kCGImagePropertyDepth: 8,
        ] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL3FinalError.invalid(
            "PNG finalization failed: \(url.path)"
        )
    }
}

func l3FinalCollectCatalogHashes(
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
                for hash in hashes.values.compactMap({ $0 as? String }) {
                    normalized.insert(hash)
                }
            }
            l3FinalCollectCatalogHashes(
                child,
                raw: &raw,
                normalized: &normalized
            )
        }
    } else if let array = value as? [Any] {
        for child in array {
            l3FinalCollectCatalogHashes(
                child,
                raw: &raw,
                normalized: &normalized
            )
        }
    }
}

func l3FinalRegistration(
    _ provenance: [String: Any]
) throws -> [String: Any] {
    let names = [
        "groundPivotSource",
        "frontageSocketSource",
        "frontageEdgeSource",
        "doorBaseSource",
        "southeastShadowVectorSource",
    ]
    var result: [String: Any] = [:]
    for name in names {
        guard let value = provenance[name] else {
            throw IndustrialL3FinalError.invalid(
                "missing provenance registration field \(name)"
            )
        }
        result[name] = value
    }
    return result
}

#if !PLAY027_L3_SOURCE_V06_FAMILY_REVIEW
@main
enum BuildIndustrialL3FinalCandidateMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try l3FinalArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let output = URL(
            fileURLWithPath: try l3FinalArgument(
                "--output",
                in: arguments
            )
        ).standardizedFileURL
        let base =
            "docs/production/evidence/PLAY-027/industrial-l03/l03/source-completion-v02"
        let finalizerSourcePath =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL3FinalCandidate.swift"
        let normalizerSourcePath =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/NormalizeOfflineSource.swift"
        let finalizerSourceSHA256 = l3FinalSHA256(
            try Data(
                contentsOf: l3FinalURL(finalizerSourcePath, root: root)
            )
        )
        let normalizerSourceSHA256 = l3FinalSHA256(
            try Data(
                contentsOf: l3FinalURL(normalizerSourcePath, root: root)
            )
        )
        let finalizerBinarySHA256 = l3FinalSHA256(
            try Data(
                contentsOf: URL(
                    fileURLWithPath: CommandLine.arguments[0]
                ).standardizedFileURL
            )
        )
        let descriptorBase =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-directional-family-v02/scenes/industrial_l03/variant-0"
        let masters = [
            IndustrialL3FinalMaster(
                direction: "north",
                path:
                    "docs/production/evidence/PLAY-027/industrial-l03/l03/raw-gate-v02/diagnostics/raw-repeat/north/run-a/raw.png",
                provenancePath:
                    "docs/production/evidence/PLAY-027/industrial-l03/l03/raw-gate-v02/diagnostics/raw-repeat/north/run-a/provenance.json",
                descriptorPath: "\(descriptorBase)/north/scene.json",
                authorityCommit: "4e6e7b50dc0e8e483e375883399c3159e972c729",
                expectedFileSHA256:
                    "05d97a621d466b8943d3fcd30ee934e91b9733cc7715d832534771eaeb2b6888",
                expectedDecodedRGBASHA256:
                    "5d1858ff3676156b7b2084f492e3a227a70b65177d1f4bf436885d8e4237eb9f",
                expectedDescriptorSHA256:
                    "78803712a2b4118abef6ff90119444b1c4093f5cb442348f3cdb9b3e4bf1fe51"
            ),
            IndustrialL3FinalMaster(
                direction: "east",
                path:
                    "\(base)/diagnostics/raw-repeat/east/run-a/raw.png",
                provenancePath:
                    "\(base)/diagnostics/raw-repeat/east/run-a/provenance.json",
                descriptorPath: "\(descriptorBase)/east/scene.json",
                authorityCommit: "8a1126a1f18984be6994c8e177ba4289063cbeef",
                expectedFileSHA256:
                    "5dd2999ad2916a8ccddcf91954e54d1dfcf1139f78977d05d738c3dbfff4b9af",
                expectedDecodedRGBASHA256:
                    "29b0f59bad27c4c8e9918e5544ab712d4e35d5acb056a31be2f2e0d71081f4d6",
                expectedDescriptorSHA256:
                    "dbe0dd260d28d848864d4194826f5147ec91314cf75b95bff9349bbfe466342c"
            ),
            IndustrialL3FinalMaster(
                direction: "south",
                path:
                    "\(base)/diagnostics/raw-repeat/south/run-a/raw.png",
                provenancePath:
                    "\(base)/diagnostics/raw-repeat/south/run-a/provenance.json",
                descriptorPath: "\(descriptorBase)/south/scene.json",
                authorityCommit: "0d5919941359bf0458d5325f666d2c27996fa812",
                expectedFileSHA256:
                    "171bcba90f5a06353778bc6d420723b714ad0a6313dd4d858128ae0efad5775c",
                expectedDecodedRGBASHA256:
                    "4a5d3f5473528015ce604ade12e18fb6bbc53df4d3607f277b67d86d40386e06",
                expectedDescriptorSHA256:
                    "1e548d4694bea47b36e9aca1a97e901917ea92742fd6366f53a4e92bfcba1b2b"
            ),
            IndustrialL3FinalMaster(
                direction: "west",
                path:
                    "\(base)/diagnostics/raw-repeat/west/run-a/raw.png",
                provenancePath:
                    "\(base)/diagnostics/raw-repeat/west/run-a/provenance.json",
                descriptorPath: "\(descriptorBase)/west/scene.json",
                authorityCommit: "6302ec9409e0111493a840c1a008bf6da2195da7",
                expectedFileSHA256:
                    "6d99f9436c11294f97359b3ed35203658ea178caa092f0ffea7d63982baa2151",
                expectedDecodedRGBASHA256:
                    "b47b211174e77d53ffad023af06734c1467403cd612af46c4e49dcef0e2921df",
                expectedDescriptorSHA256:
                    "bc0812eb16008bb0a544873fb3d24c4b01c470c405b4f6051a36a400c68856ce"
            ),
        ]
        let materialPath =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-directional-family-v02/materials/industrial-l03-v02.json"
        let materialSHA256 = l3FinalSHA256(
            try Data(contentsOf: l3FinalURL(materialPath, root: root))
        )
        guard
            materialSHA256
                == "3a9b0d97e74c3aba1772fa0dac66151955db98b34d25212eee7e15472ce2715e"
        else {
            throw IndustrialL3FinalError.invalid(
                "material library hash drift"
            )
        }

        var rawRecords: [[String: Any]] = []
        var rawRasters: [IndustrialL3FinalRaster] = []
        var rawFileHashes = Set<String>()
        var rawPixelHashes = Set<String>()
        for master in masters {
            let rawURL = l3FinalURL(master.path, root: root)
            let raster = try l3FinalInspect(rawURL)
            let descriptorSHA256 = l3FinalSHA256(
                try Data(
                    contentsOf: l3FinalURL(
                        master.descriptorPath,
                        root: root
                    )
                )
            )
            guard
                raster.fileSHA256 == master.expectedFileSHA256,
                raster.decodedRGBASHA256
                    == master.expectedDecodedRGBASHA256,
                descriptorSHA256 == master.expectedDescriptorSHA256,
                raster.image.width == 1536,
                raster.image.height == 1024
            else {
                throw IndustrialL3FinalError.invalid(
                    "\(master.direction) immutable-master identity drift"
                )
            }
            let provenance = try l3FinalJSON(
                l3FinalURL(master.provenancePath, root: root)
            )
            rawFileHashes.insert(raster.fileSHA256)
            rawPixelHashes.insert(raster.decodedRGBASHA256)
            rawRasters.append(raster)
            rawRecords.append([
                "direction": master.direction,
                "authorityCommit": master.authorityCommit,
                "file": master.path,
                "provenance": master.provenancePath,
                "descriptor": master.descriptorPath,
                "descriptorSHA256": descriptorSHA256,
                "materialLibrarySHA256": materialSHA256,
                "fileSHA256": raster.fileSHA256,
                "decodedRGBASHA256": raster.decodedRGBASHA256,
                "pixels": [raster.image.width, raster.image.height],
                "registration": try l3FinalRegistration(provenance),
                "orientationTransform": "none",
                "selection": "CONTRACT-018 immutable run-A master",
            ])
        }
        guard rawFileHashes.count == 4, rawPixelHashes.count == 4 else {
            throw IndustrialL3FinalError.invalid(
                "four-direction raw uniqueness failed"
            )
        }

        let lods = [
            ("block", [1024, 683]),
            ("neighborhood", [512, 342]),
            ("city", [256, 171]),
        ]
        var normalizedRecords: [[String: Any]] = []
        var normalizedFileHashes = Set<String>()
        var normalizedPixelHashes = Set<String>()
        var blockRasters: [IndustrialL3FinalRaster] = []
        for master in masters {
            for (lod, dimensions) in lods {
                let filename =
                    "generated_v4_industrial_l03_\(master.direction)_source_v02_\(lod).png"
                let pathA = "\(base)/normalized/run-a/\(master.direction)/\(filename)"
                let pathB = "\(base)/normalized/run-b/\(master.direction)/\(filename)"
                let rasterA = try l3FinalInspect(
                    l3FinalURL(pathA, root: root)
                )
                let rasterB = try l3FinalInspect(
                    l3FinalURL(pathB, root: root)
                )
                let repeatIdentity =
                    rasterA.fileSHA256 == rasterB.fileSHA256
                    && rasterA.decodedRGBASHA256
                        == rasterB.decodedRGBASHA256
                let dimensionsPassed =
                    rasterA.image.width == dimensions[0]
                    && rasterA.image.height == dimensions[1]
                let paddingPassed =
                    rasterA.alphaBounds[0] > 2
                    && rasterA.alphaBounds[1] > 2
                    && rasterA.alphaBounds[2] < rasterA.image.width - 2
                    && rasterA.alphaBounds[3] < rasterA.image.height - 2
                let cleanlinessPassed =
                    rasterA.hiddenRGBPixelCount == 0
                    && rasterA.exactChromaPixelCount == 0
                    && rasterA.visibleMagentaSpillPixelCount == 0
                guard
                    repeatIdentity,
                    dimensionsPassed,
                    paddingPassed,
                    cleanlinessPassed,
                    rasterA.alphaBounds == rasterB.alphaBounds,
                    rasterA.visiblePixelCount == rasterB.visiblePixelCount
                else {
                    throw IndustrialL3FinalError.invalid(
                        "\(master.direction) \(lod) normalized validation failed"
                    )
                }
                normalizedFileHashes.insert(rasterA.fileSHA256)
                normalizedPixelHashes.insert(
                    rasterA.decodedRGBASHA256
                )
                if lod == "block" {
                    blockRasters.append(rasterA)
                }
                normalizedRecords.append([
                    "direction": master.direction,
                    "lod": lod,
                    "runA": pathA,
                    "runB": pathB,
                    "fileSHA256": rasterA.fileSHA256,
                    "decodedRGBASHA256": rasterA.decodedRGBASHA256,
                    "pixels": [rasterA.image.width, rasterA.image.height],
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
            normalizedFileHashes.count == 12,
            normalizedPixelHashes.count == 12
        else {
            throw IndustrialL3FinalError.invalid(
                "12-output normalized uniqueness failed"
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
            let url = l3FinalURL(path, root: root)
            let data = try Data(contentsOf: url)
            let object = try JSONSerialization.jsonObject(with: data)
            l3FinalCollectCatalogHashes(
                object,
                raw: &acceptedRawHashes,
                normalized: &acceptedNormalizedHashes
            )
            catalogRecords.append([
                "file": path,
                "sha256": l3FinalSHA256(data),
            ])
        }
        let rawIntersection = rawFileHashes.intersection(acceptedRawHashes)
        let normalizedIntersection =
            normalizedFileHashes.intersection(acceptedNormalizedHashes)
        guard rawIntersection.isEmpty, normalizedIntersection.isEmpty else {
            throw IndustrialL3FinalError.invalid(
                "accepted-catalog alias intersection is non-empty"
            )
        }

        let reviewDirectory = output.appendingPathComponent("review")
        let rawImages = rawRasters.map(\.image)
        let blockImages = blockRasters.map(\.image)
        let grayscaleImages = try blockImages.map(l3FinalGrayscale)
        let sourceGrayscaleImages = try rawImages.map {
            try l3FinalGrayscale(l3FinalRawReviewAlpha($0))
        }
        let footprintRect = CGRect(x: 341, y: 341, width: 342, height: 256)
        let footprintImages = try l3FinalCrops(
            blockImages,
            rect: footprintRect
        )
        let footprintGrayscaleImages = try l3FinalCrops(
            grayscaleImages,
            rect: footprintRect
        )
        let zoomImages = try l3FinalZoomCrops(blockRasters)
        let zoomGrayscaleImages = try zoomImages.map(l3FinalGrayscale)
        let reviewSpecifications: [
            (String, CGImage, String)
        ] = [
            (
                "SOURCE-SCALE-NESW-COLOR.png",
                try l3FinalCanvas(
                    images: rawImages,
                    columns: 2,
                    panelSize: CGSize(width: 1536, height: 1024),
                    background: [1, 0, 1, 1],
                    interpolation: .none
                ),
                "N/E/S/W row-major; exact flat-chroma immutable masters"
            ),
            (
                "SOURCE-SCALE-NESW-GRAYSCALE.png",
                try l3FinalCanvas(
                    images: sourceGrayscaleImages,
                    columns: 2,
                    panelSize: CGSize(width: 1536, height: 1024),
                    background: [0.14, 0.14, 0.14, 1],
                    interpolation: .none
                ),
                "N/E/S/W row-major; review-only deterministic chroma matte and Rec.709 integer grayscale"
            ),
            (
                "NATIVE-2X-NESW-COLOR.png",
                try l3FinalCanvas(
                    images: blockImages,
                    columns: 2,
                    panelSize: CGSize(width: 432, height: 288),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .high
                ),
                "N/E/S/W row-major; normalized alpha at native-2x review scale"
            ),
            (
                "NATIVE-2X-NESW-GRAYSCALE.png",
                try l3FinalCanvas(
                    images: grayscaleImages,
                    columns: 2,
                    panelSize: CGSize(width: 432, height: 288),
                    background: [0.14, 0.14, 0.14, 1],
                    interpolation: .high
                ),
                "N/E/S/W row-major; Rec.709 integer grayscale"
            ),
            (
                "FOOTPRINT-NATIVE-2X-COLOR.png",
                try l3FinalCanvas(
                    images: footprintImages,
                    columns: 2,
                    panelSize: CGSize(width: 144, height: 108),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .none
                ),
                "fixed registered block crop 341,341,342,256; N/E/S/W"
            ),
            (
                "FOOTPRINT-NATIVE-2X-GRAYSCALE.png",
                try l3FinalCanvas(
                    images: footprintGrayscaleImages,
                    columns: 2,
                    panelSize: CGSize(width: 144, height: 108),
                    background: [0.14, 0.14, 0.14, 1],
                    interpolation: .none
                ),
                "fixed registered block crop; Rec.709 integer grayscale"
            ),
            (
                "ZOOM-NESW-COLOR.png",
                try l3FinalCanvas(
                    images: zoomImages,
                    columns: 2,
                    panelSize: CGSize(width: 512, height: 384),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .none
                ),
                "per-direction occupied-alpha crop plus 8px padding; N/E/S/W"
            ),
            (
                "ZOOM-NESW-GRAYSCALE.png",
                try l3FinalCanvas(
                    images: zoomGrayscaleImages,
                    columns: 2,
                    panelSize: CGSize(width: 512, height: 384),
                    background: [0.14, 0.14, 0.14, 1],
                    interpolation: .none
                ),
                "per-direction occupied-alpha crop plus 8px padding; Rec.709 integer grayscale"
            ),
        ]
        var reviewRecords: [[String: Any]] = []
        for (filename, image, presentation) in reviewSpecifications {
            let url = reviewDirectory.appendingPathComponent(filename)
            try l3FinalWritePNG(image, to: url)
            reviewRecords.append([
                "file": l3FinalRelative(url, root: root),
                "sha256": l3FinalSHA256(try Data(contentsOf: url)),
                "pixels": [image.width, image.height],
                "presentation": presentation,
            ])
        }

        let industrialL1Path =
            "docs/production/evidence/PLAY-027/industrial-l01/l01/source-v05-candidate/normalized-repeat/east/generated_v4_industrial_l01_block.png"
        let industrialL2Path =
            "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v07/source-completion/normalized/run-a/east/generated_v4_industrial_l02_east_source_v05_block.png"
        let residentialL3Path =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/normalized/residential_l03/variant-0/east/source-v01/generated_v4_residential_l03_block.png"
        let commercialL3Path =
            "docs/production/evidence/PLAY-027/commercial-l01-l04/l03/source-v01-review-candidate/normalized-repeat/east/generated_v4_commercial_l03_block.png"
        let industrialL3East = blockRasters[1].image
        let levelImages = try [
            l3FinalInspect(l3FinalURL(industrialL1Path, root: root)).image,
            l3FinalInspect(l3FinalURL(industrialL2Path, root: root)).image,
            industrialL3East,
        ]
        let levelComparison = try l3FinalCanvas(
            images: levelImages + levelImages.map(l3FinalGrayscale),
            columns: 3,
            panelSize: CGSize(width: 320, height: 213),
            background: [0.14, 0.15, 0.16, 1],
            interpolation: .high
        )
        let levelURL = reviewDirectory.appendingPathComponent(
            "INDUSTRIAL-L1-L2-L3-COLOR-GRAYSCALE.png"
        )
        try l3FinalWritePNG(levelComparison, to: levelURL)
        reviewRecords.append([
            "file": l3FinalRelative(levelURL, root: root),
            "sha256": l3FinalSHA256(try Data(contentsOf: levelURL)),
            "pixels": [levelComparison.width, levelComparison.height],
            "presentation":
                "columns Industrial L1/L2/L3 East; top color, bottom grayscale",
            "inputs": [industrialL1Path, industrialL2Path, rawRecords[1]["file"]!],
        ])

        let familyImages = try [
            l3FinalInspect(l3FinalURL(residentialL3Path, root: root)).image,
            l3FinalInspect(l3FinalURL(commercialL3Path, root: root)).image,
            industrialL3East,
        ]
        let familyComparison = try l3FinalCanvas(
            images: familyImages + familyImages.map(l3FinalGrayscale),
            columns: 3,
            panelSize: CGSize(width: 320, height: 213),
            background: [0.14, 0.15, 0.16, 1],
            interpolation: .high
        )
        let familyURL = reviewDirectory.appendingPathComponent(
            "CROSS-FAMILY-L3-COLOR-GRAYSCALE.png"
        )
        try l3FinalWritePNG(familyComparison, to: familyURL)
        reviewRecords.append([
            "file": l3FinalRelative(familyURL, root: root),
            "sha256": l3FinalSHA256(try Data(contentsOf: familyURL)),
            "pixels": [familyComparison.width, familyComparison.height],
            "presentation":
                "columns Residential/Commercial/Industrial L3 East; top color, bottom grayscale",
            "inputs": [residentialL3Path, commercialL3Path, rawRecords[1]["file"]!],
        ])

        let reviewManifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contract": "CONTRACT-018",
            "family": "industrial_l03",
            "directionOrder": ["north", "east", "south", "west"],
            "panelAuthority": "exact immutable raw and normalized source pixels",
            "panels": reviewRecords,
            "panelReplay": "generated twice by the committed finalizer; compare file hashes",
            "reviewStatus": "pending-independent-source-art-review",
            "sourceAuthority": false,
            "productionSelected": false,
        ]
        try l3FinalWriteJSON(
            reviewManifest,
            to: reviewDirectory.appendingPathComponent(
                "REVIEW-MANIFEST.json"
            )
        )

        let ledger: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contract": "CONTRACT-018",
            "family": "industrial_l03",
            "variant": 0,
            "materialLibrary": materialPath,
            "materialLibrarySHA256": materialSHA256,
            "masters": rawRecords,
            "selectionRule":
                "Only the exact published run-A file per direction is an immutable master; divergent siblings remain rejection evidence.",
            "sourceAuthority": false,
            "productionSelected": false,
        ]
        try l3FinalWriteJSON(
            ledger,
            to: output.appendingPathComponent(
                "IMMUTABLE-MASTER-LEDGER.json"
            )
        )

        let validation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "family": "industrial_l03",
            "rawUniqueFileIdentities": rawFileHashes.count,
            "rawUniqueDecodedPixelIdentities": rawPixelHashes.count,
            "normalizedOutputs": normalizedRecords.count,
            "normalizedRepeatFileIdentityPassed":
                normalizedRecords.allSatisfy {
                    $0["repeatFileIdentity"] as? Bool == true
                },
            "normalizedRepeatDecodedPixelIdentityPassed":
                normalizedRecords.allSatisfy {
                    $0["repeatDecodedPixelIdentity"] as? Bool == true
                },
            "normalizedUniqueFileIdentities": normalizedFileHashes.count,
            "normalizedUniqueDecodedPixelIdentities":
                normalizedPixelHashes.count,
            "normalizedAlphaChromaSpillPaddingPassed":
                normalizedRecords.allSatisfy {
                    $0["hiddenRGBPixelCount"] as? Int == 0
                        && $0["exactChromaPixelCount"] as? Int == 0
                        && $0["visibleMagentaSpillPixelCount"] as? Int == 0
                        && $0["paddingPassed"] as? Bool == true
                },
            "registrationPassed":
                normalizedRecords.allSatisfy {
                    $0["registrationPassed"] as? Bool == true
                },
            "acceptedCatalogs": catalogRecords,
            "acceptedCatalogRawPopulation": acceptedRawHashes.count,
            "acceptedCatalogNormalizedPopulation":
                acceptedNormalizedHashes.count,
            "acceptedCatalogRawIntersection":
                Array(rawIntersection).sorted(),
            "acceptedCatalogNormalizedIntersection":
                Array(normalizedIntersection).sorted(),
            "acceptedCatalogNonIntersectionPassed":
                rawIntersection.isEmpty && normalizedIntersection.isEmpty,
            "reviewPanelCount": reviewRecords.count,
            "validationPassed": true,
            "sourceAuthority": false,
            "productionSelected": false,
        ]
        try l3FinalWriteJSON(
            validation,
            to: output.appendingPathComponent("VALIDATION.json")
        )

        let manifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contract": "CONTRACT-018",
            "family": "industrial_l03",
            "variant": 0,
            "sourceRevision": "source-v02",
            "branchBase":
                "9290d7f53e7ea75d5011c19c48388084e2cbe6af",
            "toolchain": [
                "rendererSourceCommit":
                    "4096741c7fe64404408e8ea39df116c32f5f2623",
                "finalizerSource": finalizerSourcePath,
                "finalizerSourceSHA256": finalizerSourceSHA256,
                "finalizerBinarySHA256": finalizerBinarySHA256,
                "normalizerSource": normalizerSourcePath,
                "normalizerSourceSHA256": normalizerSourceSHA256,
                "normalizationObjectWidth": 410,
                "normalizationReferenceWidth": 512,
            ],
            "status": [
                "sourceAuthority": false,
                "sourceAuthorityProposal": "pending-independent-review",
                "productionSelected": false,
                "rendererOrShippingMutation": false,
            ],
            "immutableMasterLedger":
                l3FinalRelative(
                    output.appendingPathComponent(
                        "IMMUTABLE-MASTER-LEDGER.json"
                    ),
                    root: root
                ),
            "rawMasters": rawRecords,
            "normalizedOutputs": normalizedRecords,
            "validation":
                l3FinalRelative(
                    output.appendingPathComponent("VALIDATION.json"),
                    root: root
                ),
            "reviewManifest":
                l3FinalRelative(
                    reviewDirectory.appendingPathComponent(
                        "REVIEW-MANIFEST.json"
                    ),
                    root: root
                ),
            "rejectedSourceV03": [
                "docs/production/evidence/PLAY-027/industrial-l03/l03/source-v03-prepixel",
                "docs/production/evidence/PLAY-027/industrial-l03/l03/raw-gate-v03/rejection",
            ],
            "disposition": "pending-independent-source-art-review",
        ]
        try l3FinalWriteJSON(
            manifest,
            to: output.appendingPathComponent("FAMILY-MANIFEST.json")
        )
    }
}
#endif
