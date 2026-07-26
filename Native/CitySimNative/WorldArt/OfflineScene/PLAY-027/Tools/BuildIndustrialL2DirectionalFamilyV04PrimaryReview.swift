import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL2DirectionalPrimaryReviewError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

private struct ReviewRaster {
    let id: String
    let url: URL
    let width: Int
    let height: Int
    let rgba: [UInt8]
    let fileSHA256: String
    let decodedRGBASHA256: String
    let bounds: [Int]
    let nonChromaPixelCount: Int
    let alphaRange: [Int]
    let flatChromaCorners: Bool
}

private struct DirectionInput {
    let id: String
    let rawPath: String
    let provenancePath: String
    let expectedPivot: [Int]
    let expectedSocket: [Int]
    let expectedDoorBases: [[Int]]
    let requiresFullyOpaqueRaw: Bool
}

private func requiredArgument(
    _ name: String,
    arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2DirectionalPrimaryReviewError.invalid(
            "missing \(name)"
        )
    }
    return arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func relativePath(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    guard url.path.hasPrefix(prefix) else {
        return url.path
    }
    return String(url.path.dropFirst(prefix.count))
}

private func loadJSONObject(_ url: URL) throws -> [String: Any] {
    guard let value = try JSONSerialization.jsonObject(
        with: Data(contentsOf: url)
    ) as? [String: Any] else {
        throw IndustrialL2DirectionalPrimaryReviewError.invalid(
            "invalid JSON: \(url.path)"
        )
    }
    return value
}

private func integerArray(_ value: Any?) -> [Int]? {
    guard let numbers = value as? [NSNumber] else {
        return nil
    }
    return numbers.map(\.intValue)
}

private func integerArrays(_ value: Any?) -> [[Int]]? {
    guard let arrays = value as? [[NSNumber]] else {
        return nil
    }
    return arrays.map { $0.map(\.intValue) }
}

private func loadRaster(id: String, url: URL) throws -> ReviewRaster {
    let fileData = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    else {
        throw IndustrialL2DirectionalPrimaryReviewError.invalid(
            "could not decode \(url.path)"
        )
    }
    var bytes = [UInt8](
        repeating: 0,
        count: image.width * image.height * 4
    )
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
            in: CGRect(
                x: 0,
                y: 0,
                width: image.width,
                height: image.height
            )
        )
        return true
    }
    guard rendered else {
        throw IndustrialL2DirectionalPrimaryReviewError.invalid(
            "could not canonicalize \(url.path)"
        )
    }

    var minimumX = image.width
    var minimumY = image.height
    var maximumX = -1
    var maximumY = -1
    var nonChromaPixelCount = 0
    var alphaMinimum = 255
    var alphaMaximum = 0
    for y in 0..<image.height {
        for x in 0..<image.width {
            let offset = (y * image.width + x) * 4
            let alpha = Int(bytes[offset + 3])
            alphaMinimum = min(alphaMinimum, alpha)
            alphaMaximum = max(alphaMaximum, alpha)
            let isChroma =
                bytes[offset] == 255
                && bytes[offset + 1] == 0
                && bytes[offset + 2] == 255
            if !isChroma {
                nonChromaPixelCount += 1
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
            }
        }
    }
    let bounds = maximumX >= 0
        ? [minimumX, minimumY, maximumX + 1, maximumY + 1]
        : []
    func cornerIsChroma(_ x: Int, _ y: Int) -> Bool {
        let offset = (y * image.width + x) * 4
        return bytes[offset] == 255
            && bytes[offset + 1] == 0
            && bytes[offset + 2] == 255
            && bytes[offset + 3] == 255
    }
    let cornersPassed =
        cornerIsChroma(0, 0)
        && cornerIsChroma(image.width - 1, 0)
        && cornerIsChroma(0, image.height - 1)
        && cornerIsChroma(image.width - 1, image.height - 1)
    return ReviewRaster(
        id: id,
        url: url,
        width: image.width,
        height: image.height,
        rgba: bytes,
        fileSHA256: digest(fileData),
        decodedRGBASHA256: digest(Data(bytes)),
        bounds: bounds,
        nonChromaPixelCount: nonChromaPixelCount,
        alphaRange: [alphaMinimum, alphaMaximum],
        flatChromaCorners: cornersPassed
    )
}

private func neutralReviewRGBA(
    _ raster: ReviewRaster,
    replaceAllExactChroma: Bool
) -> [UInt8] {
    var output = raster.rgba
    var visited = [Bool](
        repeating: false,
        count: raster.width * raster.height
    )
    var queue: [Int] = []
    queue.reserveCapacity(raster.width * raster.height / 2)

    func enqueue(_ x: Int, _ y: Int) {
        let index = y * raster.width + x
        guard !visited[index] else {
            return
        }
        visited[index] = true
        queue.append(index)
    }
    func isBackgroundFamily(_ offset: Int) -> Bool {
        let red = Int(output[offset])
        let green = Int(output[offset + 1])
        let blue = Int(output[offset + 2])
        return output[offset + 3] > 0
            && red >= 150
            && blue >= 130
            && green <= 130
            && red + blue >= green * 4
    }
    for x in 0..<raster.width {
        enqueue(x, 0)
        enqueue(x, raster.height - 1)
    }
    for y in 0..<raster.height {
        enqueue(0, y)
        enqueue(raster.width - 1, y)
    }
    var cursor = 0
    while cursor < queue.count {
        let index = queue[cursor]
        cursor += 1
        let offset = index * 4
        guard isBackgroundFamily(offset) else {
            continue
        }
        output[offset] = 226
        output[offset + 1] = 228
        output[offset + 2] = 224
        output[offset + 3] = 255
        let x = index % raster.width
        let y = index / raster.width
        if x > 0 { enqueue(x - 1, y) }
        if x + 1 < raster.width { enqueue(x + 1, y) }
        if y > 0 { enqueue(x, y - 1) }
        if y + 1 < raster.height { enqueue(x, y + 1) }
    }
    if replaceAllExactChroma {
        for offset in stride(from: 0, to: output.count, by: 4) {
            if
                output[offset] == 255,
                output[offset + 1] == 0,
                output[offset + 2] == 255
            {
                output[offset] = 226
                output[offset + 1] = 228
                output[offset + 2] = 224
                output[offset + 3] = 255
            }
        }
    }
    return output
}

private func grayscale(_ rgba: [UInt8]) -> [UInt8] {
    var output = rgba
    for offset in stride(from: 0, to: output.count, by: 4) {
        let redTerm = 54 * Int(output[offset])
        let greenTerm = 183 * Int(output[offset + 1])
        let blueTerm = 19 * Int(output[offset + 2])
        let weighted = (redTerm + greenTerm + blueTerm + 128) >> 8
        let luma = UInt8(min(255, weighted))
        output[offset] = luma
        output[offset + 1] = luma
        output[offset + 2] = luma
    }
    return output
}

private func image(
    rgba: [UInt8],
    width: Int,
    height: Int
) throws -> CGImage {
    guard
        let provider = CGDataProvider(data: Data(rgba) as CFData),
        let value = CGImage(
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
        throw IndustrialL2DirectionalPrimaryReviewError.invalid(
            "could not create review image"
        )
    }
    return value
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2DirectionalPrimaryReviewError.invalid(
            "output must be absent: \(url.path)"
        )
    }
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw IndustrialL2DirectionalPrimaryReviewError.invalid(
            "could not create \(url.path)"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL2DirectionalPrimaryReviewError.invalid(
            "could not finalize \(url.path)"
        )
    }
}

private func writePanel(
    images: [CGImage],
    labels: [String],
    sourceRect: CGRect,
    cellSize: CGSize,
    interpolation: CGInterpolationQuality,
    outputURL: URL
) throws {
    let headerHeight = 44
    let width = Int(cellSize.width) * images.count
    let height = Int(cellSize.height) + headerHeight
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
        throw IndustrialL2DirectionalPrimaryReviewError.invalid(
            "could not create review panel"
        )
    }
    context.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 1).cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = interpolation
    for index in images.indices {
        guard let cropped = images[index].cropping(to: sourceRect) else {
            throw IndustrialL2DirectionalPrimaryReviewError.invalid(
                "could not crop review image"
            )
        }
        context.draw(
            cropped,
            in: CGRect(
                x: index * Int(cellSize.width),
                y: 0,
                width: Int(cellSize.width),
                height: Int(cellSize.height)
            )
        )
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(
        cgContext: context,
        flipped: false
    )
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
        .foregroundColor: NSColor.white,
    ]
    for index in labels.indices {
        labels[index].draw(
            at: CGPoint(
                x: index * Int(cellSize.width) + 8,
                y: Int(cellSize.height) + 13
            ),
            withAttributes: attributes
        )
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let panel = context.makeImage() else {
        throw IndustrialL2DirectionalPrimaryReviewError.invalid(
            "could not capture review panel"
        )
    }
    try writePNG(panel, to: outputURL)
}

@main
enum BuildIndustrialL2DirectionalFamilyV04PrimaryReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try requiredArgument(
                "--repository-root",
                arguments: arguments
            )
        ).standardizedFileURL
        let outputDirectory = URL(
            fileURLWithPath: try requiredArgument(
                "--output-directory",
                arguments: arguments
            )
        ).standardizedFileURL
        guard !FileManager.default.fileExists(
            atPath: outputDirectory.path
        ) else {
            throw IndustrialL2DirectionalPrimaryReviewError.invalid(
                "output directory must be absent"
            )
        }
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let candidateFamily: String
        if let familyIndex = arguments.firstIndex(of: "--candidate-family") {
            guard familyIndex + 1 < arguments.count else {
                throw IndustrialL2DirectionalPrimaryReviewError.invalid(
                    "missing --candidate-family value"
                )
            }
            candidateFamily = arguments[familyIndex + 1]
        } else {
            candidateFamily = "v04"
        }
        guard
            candidateFamily == "v04"
                || candidateFamily == "v05"
                || candidateFamily == "v07"
        else {
            throw IndustrialL2DirectionalPrimaryReviewError.invalid(
                "candidate family must be v04, v05, or v07"
            )
        }
        let candidateEvidenceFamily =
            "directional-family-\(candidateFamily)"
        let northAttempt =
            candidateFamily == "v04"
            ? "north-primary-v02"
            : "north-primary-v01"
        let westAttempt = "west-primary-v01"
        let includeSouth = arguments.contains("--include-south")
        guard !includeSouth || candidateFamily == "v07" else {
            throw IndustrialL2DirectionalPrimaryReviewError.invalid(
                "--include-south is authorized only for candidate family v07"
            )
        }

        var directions = [
            DirectionInput(
                id: "north-\(candidateFamily)-primary",
                rawPath:
                    "docs/production/evidence/PLAY-027/industrial-l02/l02/\(candidateEvidenceFamily)/primary-calibration/diagnostics/\(northAttempt)/raw.png",
                provenancePath:
                    "docs/production/evidence/PLAY-027/industrial-l02/l02/\(candidateEvidenceFamily)/primary-calibration/diagnostics/\(northAttempt)/provenance.json",
                expectedPivot: [768, 896],
                expectedSocket: [896, 704],
                expectedDoorBases: [[858, 685], [934, 723]],
                requiresFullyOpaqueRaw: true
            ),
            DirectionInput(
                id: "east-v05-immutable-anchor",
                rawPath:
                    "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05/raw-calibration/diagnostics/east-primary/raw.png",
                provenancePath:
                    "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05/raw-calibration/diagnostics/east-primary/provenance.json",
                expectedPivot: [768, 896],
                expectedSocket: [896, 832],
                expectedDoorBases: [[934, 813], [858, 851]],
                requiresFullyOpaqueRaw: false
            ),
        ]
        if includeSouth {
            directions.append(
                DirectionInput(
                    id: "south-v07-primary",
                    rawPath:
                        "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v07/primary-calibration/diagnostics/south-primary-v01/raw.png",
                    provenancePath:
                        "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v07/primary-calibration/diagnostics/south-primary-v01/provenance.json",
                    expectedPivot: [768, 896],
                    expectedSocket: [640, 832],
                    expectedDoorBases: [[678, 851], [602, 813]],
                    requiresFullyOpaqueRaw: true
                )
            )
        }
        directions.append(
            DirectionInput(
                id: "west-\(candidateFamily)-primary",
                rawPath:
                    "docs/production/evidence/PLAY-027/industrial-l02/l02/\(candidateEvidenceFamily)/primary-calibration/diagnostics/\(westAttempt)/raw.png",
                provenancePath:
                    "docs/production/evidence/PLAY-027/industrial-l02/l02/\(candidateEvidenceFamily)/primary-calibration/diagnostics/\(westAttempt)/provenance.json",
                expectedPivot: [768, 896],
                expectedSocket: [640, 704],
                expectedDoorBases: [[602, 723], [678, 685]],
                requiresFullyOpaqueRaw: true
            )
        )
        var rasters: [ReviewRaster] = []
        var records: [[String: Any]] = []
        var allTechnicalPassed = true
        for direction in directions {
            let rawURL = root.appendingPathComponent(direction.rawPath)
            let provenanceURL = root.appendingPathComponent(
                direction.provenancePath
            )
            let raster = try loadRaster(id: direction.id, url: rawURL)
            rasters.append(raster)
            let provenance = try loadJSONObject(provenanceURL)
            let registration =
                provenance["registration"] as? [String: Any]
                ?? provenance
            let pivot = integerArray(registration["groundPivotSource"])
            let socket = integerArray(
                registration["frontageSocketSource"]
            )
            let doorBases = integerArrays(registration["doorBaseSource"])
            let occupiedWidth =
                raster.bounds.count == 4
                ? raster.bounds[2] - raster.bounds[0] : 0
            let occupiedHeight =
                raster.bounds.count == 4
                ? raster.bounds[3] - raster.bounds[1] : 0
            let registrationPassed =
                pivot == direction.expectedPivot
                && socket == direction.expectedSocket
                && doorBases == direction.expectedDoorBases
            let sourcePassed =
                raster.width == 1536
                && raster.height == 1024
                && (
                    direction.requiresFullyOpaqueRaw
                        ? raster.alphaRange == [255, 255]
                        : raster.alphaRange[0] > 0
                            && raster.alphaRange[1] == 255
                )
                && raster.flatChromaCorners
                && raster.nonChromaPixelCount >= 50_000
                && occupiedWidth >= 400
                && occupiedHeight >= 260
                && registrationPassed
                && provenance["productionSelected"] as? Bool == false
            allTechnicalPassed = allTechnicalPassed && sourcePassed
            records.append([
                "id": direction.id,
                "rawFile": relativePath(rawURL, root: root),
                "rawFileSHA256": raster.fileSHA256,
                "decodedRGBASHA256": raster.decodedRGBASHA256,
                "pixels": [raster.width, raster.height],
                "alphaRange": raster.alphaRange,
                "alphaContract":
                    direction.requiresFullyOpaqueRaw
                    ? "flat-chroma raw is fully opaque"
                    : "immutable East v05 alpha-correct raw retains positive edge alpha",
                "flatOpaqueChromaCorners": raster.flatChromaCorners,
                "nonChromaPixelCount": raster.nonChromaPixelCount,
                "nonChromaBounds": raster.bounds,
                "nonChromaBoundsPixels": [
                    occupiedWidth,
                    occupiedHeight,
                ],
                "provenanceFile": relativePath(
                    provenanceURL,
                    root: root
                ),
                "provenanceFileSHA256":
                    digest(try Data(contentsOf: provenanceURL)),
                "groundPivotSource": pivot as Any,
                "frontageSocketSource": socket as Any,
                "doorBaseSource": doorBases as Any,
                "registrationPassed": registrationPassed,
                "sourceChecksPassed": sourcePassed,
            ])
        }

        let uniqueFiles = Set(rasters.map(\.fileSHA256)).count
        let uniquePixels = Set(rasters.map(\.decodedRGBASHA256)).count
        let uniquenessPassed =
            uniqueFiles == rasters.count
            && uniquePixels == rasters.count
        allTechnicalPassed = allTechnicalPassed && uniquenessPassed

        let neutralImages = try rasters.map {
            try image(
                rgba: neutralReviewRGBA(
                    $0,
                    replaceAllExactChroma: candidateFamily != "v04"
                ),
                width: $0.width,
                height: $0.height
            )
        }
        let grayscaleImages = try rasters.map {
            try image(
                rgba: grayscale(
                    neutralReviewRGBA(
                        $0,
                        replaceAllExactChroma: candidateFamily != "v04"
                    )
                ),
                width: $0.width,
                height: $0.height
            )
        }
        var labels = [
            "NORTH \(candidateFamily.uppercased()) PRIMARY",
            "EAST V05 IMMUTABLE",
        ]
        if includeSouth {
            labels.append("SOUTH V07 PRIMARY")
        }
        labels.append("WEST \(candidateFamily.uppercased()) PRIMARY")
        let sourceRect = CGRect(x: 481, y: 433, width: 576, height: 501)
        let footprintRect = CGRect(x: 480, y: 584, width: 576, height: 350)
        let directionSuffix = includeSouth ? "N-E-S-W" : "N-E-W"
        let panelSpecifications: [
            (String, [CGImage], CGRect, CGSize, CGInterpolationQuality)
        ] = [
            (
                "SOURCE-SCALE-COLOR-\(directionSuffix).png",
                neutralImages,
                sourceRect,
                CGSize(width: 576, height: 501),
                .none
            ),
            (
                "SOURCE-SCALE-GRAYSCALE-\(directionSuffix).png",
                grayscaleImages,
                sourceRect,
                CGSize(width: 576, height: 501),
                .none
            ),
            (
                "NATIVE-2X-COLOR-\(directionSuffix).png",
                neutralImages,
                sourceRect,
                CGSize(width: 162, height: 141),
                .high
            ),
            (
                "NATIVE-2X-GRAYSCALE-\(directionSuffix).png",
                grayscaleImages,
                sourceRect,
                CGSize(width: 162, height: 141),
                .high
            ),
            (
                "FOOTPRINT-NATIVE-2X-COLOR-\(directionSuffix).png",
                neutralImages,
                footprintRect,
                CGSize(width: 162, height: 98),
                .high
            ),
            (
                "FOOTPRINT-NATIVE-2X-GRAYSCALE-\(directionSuffix).png",
                grayscaleImages,
                footprintRect,
                CGSize(width: 162, height: 98),
                .high
            ),
        ]
        var panelRecords: [[String: Any]] = []
        for specification in panelSpecifications {
            let outputURL = outputDirectory.appendingPathComponent(
                specification.0
            )
            try writePanel(
                images: specification.1,
                labels: labels,
                sourceRect: specification.2,
                cellSize: specification.3,
                interpolation: specification.4,
                outputURL: outputURL
            )
            panelRecords.append([
                "file": relativePath(outputURL, root: root),
                "fileSHA256": digest(try Data(contentsOf: outputURL)),
                "panelAuthority":
                    "actual retained source pixels; review-only border-connected chroma matte replacement; no source mutation",
            ])
        }

        let executableURL = URL(
            fileURLWithPath: CommandLine.arguments[0]
        ).standardizedFileURL
        let rendererSourceCommit =
            candidateFamily == "v07"
            ? "4ae0f3cb38867260685a5eecfed881bda71bde24"
            : "ba0c233722535db06d5a0000438740b720a4222e"
        let rendererBinarySHA256 =
            candidateFamily == "v07"
            ? "2283632f7445b467632fae414e23e6ebd31b7a89fa2dbacbd934051eb3aa301f"
            : "f36e9c0c693b3738c9ac4e9fb91866271dbb4eda0589fb62fab4b247bc2052ea"
        let rawTechnicalReport: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "candidateFamily": candidateFamily,
            "sources": records,
            "sourceCount": records.count,
            "uniqueRawFileHashCount": uniqueFiles,
            "uniqueDecodedPixelHashCount": uniquePixels,
            "rawUniquenessPassed": uniquenessPassed,
            "technicalPassed": allTechnicalPassed,
            "sourceAuthority": false,
            "productionSelected": false,
        ]
        let rawTechnicalData = try JSONSerialization.data(
            withJSONObject: rawTechnicalReport,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var terminatedRawTechnical = rawTechnicalData
        terminatedRawTechnical.append(0x0a)
        try terminatedRawTechnical.write(
            to: outputDirectory.appendingPathComponent(
                "RAW-TECHNICAL-UNIQUENESS.json"
            ),
            options: .atomic
        )
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "checkpoint":
                includeSouth
                ? "Industrial L2 V07 N/E/S/W raw family review"
                : "Industrial L2 \(candidateFamily.uppercased()) N/E/W raw review",
            "candidateFamily": candidateFamily,
            "rendererSourceCommit": rendererSourceCommit,
            "rendererBinarySHA256": rendererBinarySHA256,
            "reviewToolFile":
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL2DirectionalFamilyV04PrimaryReview.swift",
            "reviewToolBinarySHA256":
                digest(try Data(contentsOf: executableURL)),
            "metalProcesses": [
                "northCandidatePrimary": 1,
                "eastV05AnchorInherited": 1,
                "westCandidatePrimary": 1,
                "south": includeSouth ? 1 : 0,
                "repeatProcesses": 0,
            ],
            "normalizerProcessCount": 0,
            "sourceAuthority": false,
            "productionSelected": false,
            "rawSourceCount": records.count,
            "uniqueRawFileHashCount": uniqueFiles,
            "uniqueDecodedPixelHashCount": uniquePixels,
            "rawUniquenessPassed": uniquenessPassed,
            "sources": records,
            "reviewPresentation": [
                "sourceScaleCrop": [481, 433, 576, 501],
                "native2xScale": 0.28125,
                "footprintCrop": [480, 584, 576, 350],
                "backgroundTreatment":
                    candidateFamily != "v04"
                    ? "review-only global exact-chroma replacement plus border-connected chroma-family replacement with neutral RGB 226/228/224"
                    : "review-only border-connected flat-chroma family replacement with neutral RGB 226/228/224",
                "rawFilesRemainImmutable": true,
                "panels": panelRecords,
            ],
            "southDescriptorLineage":
                includeSouth
                ? [
                    "familyDisposition":
                        "V07 South inherits the independently authored V04 South descriptor unchanged because the governed V07 semantic repair has southMutationCount 0",
                    "descriptorFile":
                        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v04/scenes/industrial_l02/variant-0/south/scene.json",
                    "sourceRevision": "source-v07",
                ]
                : [:],
            "familyCohesionReview":
                includeSouth
                ? [
                    "eastHeavierOutlineMismatchDisclosed": true,
                    "observation":
                        "Immutable East V05 retains visibly heavier dark exterior outlines and contact shadow than North/South/West; final family cohesion disposition remains with independent review",
                    "noEastMutation": true,
                ]
                : [:],
            "technicalPassed": allTechnicalPassed,
            "visualDisposition": "PENDING_INDEPENDENT_REVIEW",
            "nextAuthorityRequired":
                includeSouth
                ? "Repeats, normalization, source authority, production selection, and renderer ingestion remain blocked"
                : "South primary, repeats, and normalization remain blocked",
        ]
        let reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var terminated = reportData
        terminated.append(0x0a)
        try terminated.write(
            to: outputDirectory.appendingPathComponent("REVIEW.json"),
            options: .atomic
        )
        guard allTechnicalPassed else {
            throw IndustrialL2DirectionalPrimaryReviewError.invalid(
                "raw review technical gate failed"
            )
        }
    }
}
