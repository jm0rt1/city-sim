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
            return "usage: build-industrial-l4-v16-north-raw-probe-review --repository-root <path> --output-directory <path> --renderer-binary <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct Raster {
    let image: CGImage
    let rgba: [UInt8]
    let fileSHA256: String
    let decodedRGBASHA256: String
}

private struct Bounds {
    let minimumX: Int
    let minimumY: Int
    let maximumX: Int
    let maximumY: Int

    var array: [Int] {
        [minimumX, minimumY, maximumX, maximumY]
    }
}

private let rawRelativePath =
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    + "crucible-gantry-v16-north-raw-probe/diagnostics/north/run-a/raw.png"
private let provenanceRelativePath =
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    + "crucible-gantry-v16-north-raw-probe/diagnostics/north/run-a/provenance.json"
private let capabilityRelativePath =
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    + "crucible-gantry-v16-north-raw-probe/diagnostics/north/run-a/capability.json"
private let descriptorRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v16-north-prepixel/attempts/refinement-02/"
    + "artifact/scenes/industrial_l04/variant-0/n/scene.json"
private let materialRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v16-north-prepixel/materials/"
    + "industrial-l04-crucible-gantry-v14-north-prepixel.json"
private let l3RelativePath =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "source-v06-raw-review-v01/diagnostics/raw-repeat/north/run-a/raw.png"
private let v14ColorRelativePath =
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    + "crucible-gantry-v14-north-prepixel/attempts/refinement-03/evidence/"
    + "review/SOURCE-COLOR.png"

private let expectedDescriptorSHA =
    "bb4d38f44223083fe88b24f482b62a3061b0322e83e50836d8fb7b2d97b3c411"
private let expectedMaterialSHA =
    "147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202"
private let expectedBuilderSHA =
    "15d88031e4b845060d2f66cef93f96a7d9b204fd2ecd9873f885924e8099c97d"
private let expectedResolverReportSHA =
    "ccfb0bd122e0d487a6478e9275d9a974c15a504f0562edc55f3a251eb1d88c48"

private func argument(_ name: String) throws -> String {
    let arguments = CommandLine.arguments
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw ReviewError.arguments
    }
    return arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func digest(_ url: URL) throws -> String {
    digest(try Data(contentsOf: url))
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
            throw ReviewError.invalid("could not allocate RGBA decoder")
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
        decodedRGBASHA256: digest(Data(rgba))
    )
}

private func image(
    rgba: [UInt8],
    width: Int,
    height: Int
) throws -> CGImage {
    guard
        let provider = CGDataProvider(data: Data(rgba) as CFData),
        let result = CGImage(
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
        throw ReviewError.invalid("could not create RGBA image")
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

private func scaled(
    _ source: CGImage,
    width: Int,
    height: Int
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
        throw ReviewError.invalid("could not allocate scaling context")
    }
    context.interpolationQuality = .high
    context.setFillColor(CGColor(gray: 0.12, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(
        source,
        in: CGRect(x: 0, y: 0, width: width, height: height)
    )
    guard let result = context.makeImage() else {
        throw ReviewError.invalid("could not create scaled image")
    }
    return result
}

private func occupiedCrop(
    _ source: CGImage,
    bounds: Bounds,
    width: Int,
    height: Int
) throws -> CGImage {
    let padding = 24
    let cropX = max(0, bounds.minimumX - padding)
    let cropY = max(0, bounds.minimumY - padding)
    let cropMaximumX = min(source.width - 1, bounds.maximumX + padding)
    let cropMaximumY = min(source.height - 1, bounds.maximumY + padding)
    let rect = CGRect(
        x: cropX,
        y: cropY,
        width: cropMaximumX - cropX + 1,
        height: cropMaximumY - cropY + 1
    )
    guard let crop = source.cropping(to: rect) else {
        throw ReviewError.invalid("could not crop occupied source")
    }
    return try scaled(crop, width: width, height: height)
}

private func isChroma(_ rgba: [UInt8], _ offset: Int) -> Bool {
    rgba[offset] == 255
        && rgba[offset + 1] == 0
        && rgba[offset + 2] == 255
}

private func preparedRGBA(
    _ source: [UInt8],
    grayscale: Bool
) -> [UInt8] {
    var result = source
    for offset in stride(from: 0, to: result.count, by: 4) {
        if isChroma(source, offset) {
            result[offset] = 0
            result[offset + 1] = 0
            result[offset + 2] = 0
            result[offset + 3] = 0
        } else {
            result[offset + 3] = source[offset + 3]
            if grayscale {
                let luma =
                    0.2126 * Double(source[offset])
                    + 0.7152 * Double(source[offset + 1])
                    + 0.0722 * Double(source[offset + 2])
                let value = UInt8(max(0, min(255, Int(luma.rounded()))))
                result[offset] = value
                result[offset + 1] = value
                result[offset + 2] = value
            }
        }
    }
    return result
}

private func occupancyRGBA(_ source: [UInt8]) -> [UInt8] {
    var result = [UInt8](repeating: 0, count: source.count)
    for offset in stride(from: 0, to: source.count, by: 4) {
        let occupied = !isChroma(source, offset)
        let value: UInt8 = occupied ? 255 : 0
        result[offset] = value
        result[offset + 1] = value
        result[offset + 2] = value
        result[offset + 3] = 255
    }
    return result
}

private func visibleBounds(
    _ rgba: [UInt8],
    width: Int,
    height: Int
) -> Bounds? {
    var minimumX = width
    var minimumY = height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            guard !isChroma(rgba, offset) else { continue }
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    guard maximumX >= minimumX, maximumY >= minimumY else {
        return nil
    }
    return Bounds(
        minimumX: minimumX,
        minimumY: minimumY,
        maximumX: maximumX,
        maximumY: maximumY
    )
}

private func sideBySide(
    left: CGImage,
    right: CGImage,
    width: Int,
    height: Int
) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: width * 2,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 2 * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw ReviewError.invalid("could not allocate comparison context")
    }
    context.setFillColor(CGColor(gray: 0.12, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width * 2, height: height))
    context.interpolationQuality = .high
    context.draw(left, in: CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(right, in: CGRect(x: width, y: 0, width: width, height: height))
    guard let result = context.makeImage() else {
        throw ReviewError.invalid("could not create comparison image")
    }
    return result
}

private func overlay(
    base: CGImage,
    descriptor: [String: Any]
) throws -> CGImage {
    let width = 192
    let height = 128
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
        throw ReviewError.invalid("could not allocate registration context")
    }
    context.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard
        let registration = descriptor["registration"] as? [String: Any],
        let footprint = registration["footprintPolygonSource"] as? [[NSNumber]],
        let frontage = registration["frontageEdgeSource"] as? [[NSNumber]],
        let socket = registration["frontageSocketSource"] as? [NSNumber],
        let pivot = registration["groundPivotSource"] as? [NSNumber]
    else {
        throw ReviewError.invalid("descriptor registration is incomplete")
    }
    func point(_ values: [NSNumber]) -> CGPoint {
        CGPoint(
            x: values[0].doubleValue / 8,
            y: Double(height) - values[1].doubleValue / 8
        )
    }
    context.setLineWidth(1)
    context.setStrokeColor(CGColor(red: 0.1, green: 0.9, blue: 0.9, alpha: 1))
    context.beginPath()
    context.move(to: point(footprint[0]))
    for values in footprint.dropFirst() {
        context.addLine(to: point(values))
    }
    context.closePath()
    context.strokePath()
    context.setStrokeColor(CGColor(red: 1, green: 0.75, blue: 0, alpha: 1))
    context.setLineWidth(2)
    context.move(to: point(frontage[0]))
    context.addLine(to: point(frontage[1]))
    context.strokePath()
    let socketPoint = point(socket)
    context.setFillColor(CGColor(red: 1, green: 0.1, blue: 0.1, alpha: 1))
    context.fillEllipse(
        in: CGRect(
            x: socketPoint.x - 2,
            y: socketPoint.y - 2,
            width: 4,
            height: 4
        )
    )
    let pivotPoint = point(pivot)
    context.setFillColor(CGColor(red: 0.2, green: 1, blue: 0.2, alpha: 1))
    context.fillEllipse(
        in: CGRect(
            x: pivotPoint.x - 2,
            y: pivotPoint.y - 2,
            width: 4,
            height: 4
        )
    )
    guard let result = context.makeImage() else {
        throw ReviewError.invalid("could not create registration overlay")
    }
    return result
}

private func jsonObject(_ url: URL) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(
        with: Data(contentsOf: url)
    ) as? [String: Any] else {
        throw ReviewError.invalid("expected JSON object at \(url.path)")
    }
    return object
}

@main
private enum BuildIndustrialL4V16NorthRawProbeReview {
    static func main() throws {
        let repositoryRoot = URL(
            fileURLWithPath: try argument("--repository-root")
        ).standardizedFileURL
        let outputDirectory = URL(
            fileURLWithPath: try argument("--output-directory")
        ).standardizedFileURL
        let rendererBinary = URL(
            fileURLWithPath: try argument("--renderer-binary")
        ).standardizedFileURL
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        func repositoryURL(_ relativePath: String) -> URL {
            repositoryRoot.appendingPathComponent(relativePath)
        }

        let rawURL = repositoryURL(rawRelativePath)
        let provenanceURL = repositoryURL(provenanceRelativePath)
        let capabilityURL = repositoryURL(capabilityRelativePath)
        let descriptorURL = repositoryURL(descriptorRelativePath)
        let materialURL = repositoryURL(materialRelativePath)
        let builderURL = repositoryURL(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
                + "BuildIndustrialL4CrucibleGantryV16NorthPrepixel.swift"
        )
        let resolverReportURL = repositoryURL(
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
                + "crucible-gantry-v16-north-resolver/RESOLVER-VALIDATION.json"
        )
        let raw = try decode(rawURL)
        guard raw.image.width == 1536, raw.image.height == 1024 else {
            throw ReviewError.invalid("raw dimensions are not 1536x1024")
        }
        guard try digest(descriptorURL) == expectedDescriptorSHA else {
            throw ReviewError.invalid("descriptor SHA drift")
        }
        guard try digest(materialURL) == expectedMaterialSHA else {
            throw ReviewError.invalid("material SHA drift")
        }
        guard try digest(builderURL) == expectedBuilderSHA else {
            throw ReviewError.invalid("builder SHA drift")
        }
        guard try digest(resolverReportURL) == expectedResolverReportSHA else {
            throw ReviewError.invalid("resolver report SHA drift")
        }
        let provenance = try jsonObject(provenanceURL)
        guard provenance["rawSourceSHA256"] as? String == raw.fileSHA256 else {
            throw ReviewError.invalid("raw SHA does not match provenance")
        }
        guard
            provenance["sceneDescriptorSHA256"] as? String
                == expectedDescriptorSHA,
            provenance["materialLibrarySHA256"] as? String
                == expectedMaterialSHA
        else {
            throw ReviewError.invalid("provenance input binding drift")
        }
        let descriptor = try jsonObject(descriptorURL)
        guard
            descriptor["sceneGeometryID"] as? String
                == "industrial-l04-crucible-gantry-v16-north-l-side-return"
        else {
            throw ReviewError.invalid("geometry binding drift")
        }

        var alphaZero = 0
        var alphaPartial = 0
        var alphaOpaque = 0
        var hiddenRGB = 0
        var exactChroma = 0
        var nonExactNearChroma = 0
        var occupied = 0
        for offset in stride(from: 0, to: raw.rgba.count, by: 4) {
            let alpha = raw.rgba[offset + 3]
            if alpha == 0 {
                alphaZero += 1
                if raw.rgba[offset] != 0
                    || raw.rgba[offset + 1] != 0
                    || raw.rgba[offset + 2] != 0
                {
                    hiddenRGB += 1
                }
            } else if alpha == 255 {
                alphaOpaque += 1
            } else {
                alphaPartial += 1
            }
            if isChroma(raw.rgba, offset) {
                exactChroma += 1
            } else {
                occupied += 1
                if raw.rgba[offset] >= 240
                    && raw.rgba[offset + 1] <= 16
                    && raw.rgba[offset + 2] >= 240
                {
                    nonExactNearChroma += 1
                }
            }
        }
        guard let bounds = visibleBounds(
            raw.rgba,
            width: raw.image.width,
            height: raw.image.height
        ) else {
            throw ReviewError.invalid("raw has no non-chroma support")
        }

        let colorRGBA = preparedRGBA(raw.rgba, grayscale: false)
        let grayRGBA = preparedRGBA(raw.rgba, grayscale: true)
        let sourceColor = try image(
            rgba: colorRGBA,
            width: 1536,
            height: 1024
        )
        let sourceGray = try image(
            rgba: grayRGBA,
            width: 1536,
            height: 1024
        )
        let occupancy = try image(
            rgba: occupancyRGBA(raw.rgba),
            width: 1536,
            height: 1024
        )
        let nativeColor = try scaled(sourceColor, width: 384, height: 256)
        let nativeGray = try scaled(sourceGray, width: 384, height: 256)
        let compactColor = try scaled(sourceColor, width: 192, height: 128)
        let compactGray = try scaled(sourceGray, width: 192, height: 128)
        let occupiedColor = try occupiedCrop(
            sourceColor,
            bounds: bounds,
            width: 768,
            height: 512
        )
        let occupiedGray = try occupiedCrop(
            sourceGray,
            bounds: bounds,
            width: 768,
            height: 512
        )
        let registration = try overlay(
            base: compactColor,
            descriptor: descriptor
        )

        let outputs: [(String, CGImage)] = [
            ("SOURCE-COLOR.png", sourceColor),
            ("SOURCE-GRAYSCALE.png", sourceGray),
            ("ALPHA-OCCUPANCY.png", occupancy),
            ("NATIVE-2X-COLOR.png", nativeColor),
            ("NATIVE-2X-GRAYSCALE.png", nativeGray),
            ("EXACT-192X128-COLOR.png", compactColor),
            ("EXACT-192X128-GRAYSCALE.png", compactGray),
            ("OCCUPIED-CROP-COLOR.png", occupiedColor),
            ("OCCUPIED-CROP-GRAYSCALE.png", occupiedGray),
            ("FRONTAGE-REGISTRATION-CONTACT.png", registration),
        ]
        for (name, output) in outputs {
            try writePNG(
                output,
                to: outputDirectory.appendingPathComponent(name)
            )
        }

        let l3 = try decode(repositoryURL(l3RelativePath))
        let l3Color = try scaled(
            try image(
                rgba: preparedRGBA(l3.rgba, grayscale: false),
                width: l3.image.width,
                height: l3.image.height
            ),
            width: 192,
            height: 128
        )
        let l3Gray = try scaled(
            try image(
                rgba: preparedRGBA(l3.rgba, grayscale: true),
                width: l3.image.width,
                height: l3.image.height
            ),
            width: 192,
            height: 128
        )
        let v14 = try decode(repositoryURL(v14ColorRelativePath))
        let v14Color = try scaled(v14.image, width: 192, height: 128)
        let v14Gray = try scaled(
            try image(
                rgba: preparedRGBA(v14.rgba, grayscale: true),
                width: v14.image.width,
                height: v14.image.height
            ),
            width: 192,
            height: 128
        )
        try writePNG(
            try sideBySide(
                left: l3Color,
                right: compactColor,
                width: 192,
                height: 128
            ),
            to: outputDirectory.appendingPathComponent(
                "ACCEPTED-L3-VS-V16-COLOR.png"
            )
        )
        try writePNG(
            try sideBySide(
                left: l3Gray,
                right: compactGray,
                width: 192,
                height: 128
            ),
            to: outputDirectory.appendingPathComponent(
                "ACCEPTED-L3-VS-V16-GRAYSCALE.png"
            )
        )
        try writePNG(
            try sideBySide(
                left: v14Color,
                right: compactColor,
                width: 192,
                height: 128
            ),
            to: outputDirectory.appendingPathComponent(
                "V14-PREPIXEL-VS-V16-RAW-COLOR.png"
            )
        )
        try writePNG(
            try sideBySide(
                left: v14Gray,
                right: compactGray,
                width: 192,
                height: 128
            ),
            to: outputDirectory.appendingPathComponent(
                "V14-PREPIXEL-VS-V16-RAW-GRAYSCALE.png"
            )
        )

        let capability = try jsonObject(capabilityURL)
        let capabilityRecord =
            capability["capability"] as? [String: Any] ?? [:]
        let rawOccupancy =
            provenance["rawOccupancy"] as? [String: Any] ?? [:]
        let report: [String: Any] = [
            "taskID": "PLAY-027",
            "artifact": "industrial-l04-crucible-gantry-v16-north-raw-probe",
            "disposition": "PENDING_INDEPENDENT_RENDERER_AND_QA_REVIEW",
            "authorizedRawProcessCount": 1,
            "consumedRawProcessCount": 1,
            "repeatProcessesRun": 0,
            "normalizerProcessCount": 0,
            "sourceAuthority": false,
            "productionSelected": false,
            "rendererSourceCommit":
                "3201664511ae3329fe58bb97438e230a471b8fa4",
            "rendererBinarySHA256": try digest(rendererBinary),
            "builderSHA256": expectedBuilderSHA,
            "descriptorSHA256": expectedDescriptorSHA,
            "materialSHA256": expectedMaterialSHA,
            "resolverValidationSHA256": expectedResolverReportSHA,
            "resolverPositiveCount": 1,
            "resolverFailClosedNegativeCount": 20,
            "geometryID":
                "industrial-l04-crucible-gantry-v16-north-l-side-return",
            "raw": [
                "file": rawRelativePath,
                "fileSHA256": raw.fileSHA256,
                "decodedRGBASHA256": raw.decodedRGBASHA256,
                "pixels": [raw.image.width, raw.image.height],
                "visibleBounds": bounds.array,
                "occupiedPixelCount": occupied,
                "provenanceOccupancy": rawOccupancy,
            ],
            "alphaChroma": [
                "alphaZeroPixelCount": alphaZero,
                "alphaPartialPixelCount": alphaPartial,
                "alphaOpaquePixelCount": alphaOpaque,
                "hiddenRGBAtAlphaZeroPixelCount": hiddenRGB,
                "exactChromaPixelCount": exactChroma,
                "nonExactNearChromaOccupiedPixelCount": nonExactNearChroma,
                "flatChromaRawContractPassed":
                    exactChroma + occupied == raw.image.width * raw.image.height,
            ],
            "registration": [
                "groundPivotSource": [768, 896],
                "frontageSocketSource": [896, 704],
                "frontageEdgeSource": [[768, 640], [1024, 768]],
                "doorBaseSource": [
                    [868.5714363480198, 690.28570827653016],
                    [923.4285834469398, 717.71428182599004],
                ],
                "northThroatCompactWidthAnalytic": 7.666519372805656,
                "northThroatMinimumCompactWidth": 7,
                "northThroatAnalyticGatePassed": true,
                "southeastShadowVectorSource": [2, 1],
                "orientationTransform": "none",
            ],
            "sampling": [
                "contractID": "play027-deterministic-4x-no-msaa-lanczos-v3",
                "sceneKitAntialiasing": "none",
                "sceneKitLightingMode": "authored-constant-v1",
                "sceneKitShadows": "disabled",
                "orientationTransform": "none",
            ],
            "backend": capabilityRecord,
            "visualReviewRequired": [
                "monumental gate has visible jamb, header, and inset depth",
                "warm hall, double-girder gantry, hot crucible, and stack survive",
                "northwest value direction and southeast contact shadow cohere",
                "road socket visibly connects to the North throat",
            ],
            "visualReviewDisposition": "PENDING_INDEPENDENT_REVIEW",
        ]
        let reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var terminated = reportData
        terminated.append(0x0a)
        try terminated.write(
            to: outputDirectory.appendingPathComponent("RAW-PROBE-REVIEW.json"),
            options: .atomic
        )

        var inventory: [[String: Any]] = []
        for file in try fileManager.contentsOfDirectory(
            at: outputDirectory,
            includingPropertiesForKeys: nil
        ).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard file.pathExtension == "png" || file.pathExtension == "json" else {
                continue
            }
            guard file.lastPathComponent != "PACKET-MANIFEST.json" else {
                continue
            }
            inventory.append([
                "file": file.lastPathComponent,
                "sha256": try digest(file),
            ])
        }
        let manifest: [String: Any] = [
            "taskID": "PLAY-027",
            "artifact": "industrial-l04-crucible-gantry-v16-north-raw-probe",
            "files": inventory,
            "sourceAuthority": false,
            "productionSelected": false,
        ]
        let manifestData = try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var manifestTerminated = manifestData
        manifestTerminated.append(0x0a)
        try manifestTerminated.write(
            to: outputDirectory.appendingPathComponent("PACKET-MANIFEST.json"),
            options: .atomic
        )
        print("PASS Industrial L4 v16 North A-only raw review packet")
        print("raw-file-sha256=\(raw.fileSHA256)")
        print("raw-decoded-rgba-sha256=\(raw.decodedRGBASHA256)")
    }
}
