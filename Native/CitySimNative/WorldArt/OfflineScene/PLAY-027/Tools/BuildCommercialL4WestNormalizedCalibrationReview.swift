import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CommercialL4NormalizedReviewError: Error {
    case invalid(String)
}

struct CalibrationRaster {
    let url: URL
    let width: Int
    let height: Int
    let rgba: [UInt8]
    let fileSHA256: String
    let pixelSHA256: String
}

struct LODInputs {
    let name: String
    let diagnosticA: CalibrationRaster
    let diagnosticB: CalibrationRaster
    let accepted: CalibrationRaster
}

func calibrationSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func calibrationArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw CommercialL4NormalizedReviewError.invalid("missing \(name)")
    }
    return arguments[index + 1]
}

func loadCalibrationRaster(_ url: URL) throws -> CalibrationRaster {
    let fileData = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw CommercialL4NormalizedReviewError.invalid(
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
        throw CommercialL4NormalizedReviewError.invalid(
            "could not canonicalize \(url.path)"
        )
    }
    return CalibrationRaster(
        url: url,
        width: image.width,
        height: image.height,
        rgba: rgba,
        fileSHA256: calibrationSHA256(fileData),
        pixelSHA256: calibrationSHA256(Data(rgba))
    )
}

func calibrationImage(
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
        throw CommercialL4NormalizedReviewError.invalid(
            "could not create calibration image"
        )
    }
    return image
}

func grayscaleCalibrationRGBA(_ rgba: [UInt8]) -> [UInt8] {
    var output = rgba
    for offset in stride(from: 0, to: output.count, by: 4) {
        let red = 54 * Int(output[offset])
        let green = 183 * Int(output[offset + 1])
        let blue = 19 * Int(output[offset + 2])
        let luma = UInt8(min(255, (red + green + blue + 128) >> 8))
        output[offset] = luma
        output[offset + 1] = luma
        output[offset + 2] = luma
    }
    return output
}

func calibrationBounds(
    _ raster: CalibrationRaster
) -> [Int] {
    var minimumX = raster.width
    var minimumY = raster.height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<raster.height {
        for x in 0..<raster.width {
            let offset = (y * raster.width + x) * 4
            guard raster.rgba[offset + 3] > 0 else { continue }
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    guard maximumX >= 0 else { return [] }
    return [minimumX, minimumY, maximumX + 1, maximumY + 1]
}

func calibrationInspection(
    _ raster: CalibrationRaster
) -> [String: Any] {
    let bounds = calibrationBounds(raster)
    var alphaMinimum = 255
    var alphaMaximum = 0
    var transparent = 0
    var visible = 0
    var hiddenRGB = 0
    var opaqueChroma = 0
    var visibleMagenta = 0
    var lumas: [Int] = []
    for offset in stride(from: 0, to: raster.rgba.count, by: 4) {
        let red = Int(raster.rgba[offset])
        let green = Int(raster.rgba[offset + 1])
        let blue = Int(raster.rgba[offset + 2])
        let alpha = Int(raster.rgba[offset + 3])
        alphaMinimum = min(alphaMinimum, alpha)
        alphaMaximum = max(alphaMaximum, alpha)
        if alpha == 0 {
            transparent += 1
            if red != 0 || green != 0 || blue != 0 {
                hiddenRGB += 1
            }
        } else {
            visible += 1
            if red == 255 && green == 0 && blue == 255 {
                opaqueChroma += 1
            }
            if
                alpha >= 8,
                red >= 96,
                blue >= 96,
                red > green * 3 / 2,
                blue > green * 3 / 2
            {
                visibleMagenta += 1
            }
            lumas.append((54 * red + 183 * green + 19 * blue + 128) >> 8)
        }
    }
    lumas.sort()
    func percentile(_ fraction: Double) -> Int {
        guard !lumas.isEmpty else { return 0 }
        let index = Int(
            (Double(lumas.count - 1) * fraction).rounded()
        )
        return lumas[index]
    }
    let padding: [Int]
    if bounds.count == 4 {
        padding = [
            bounds[0],
            bounds[1],
            raster.width - bounds[2],
            raster.height - bounds[3],
        ]
    } else {
        padding = []
    }
    return [
        "pixels": [raster.width, raster.height],
        "fileSHA256": raster.fileSHA256,
        "decodedRGBASHA256": raster.pixelSHA256,
        "alphaRange": [alphaMinimum, alphaMaximum],
        "alphaBounds": bounds,
        "paddingPixels": padding,
        "paddingPassed":
            padding.count == 4 && padding.allSatisfy { $0 > 2 },
        "transparentPixelCount": transparent,
        "visiblePixelCount": visible,
        "hiddenRGBPixelCount": hiddenRGB,
        "opaqueChromaPixelCount": opaqueChroma,
        "visibleMagentaSpillPixelCount": visibleMagenta,
        "lumaP25": percentile(0.25),
        "lumaP50": percentile(0.50),
        "lumaP75": percentile(0.75),
        "technicalSurfacePassed":
            alphaMinimum == 0
            && alphaMaximum == 255
            && transparent > 0
            && visible > 0
            && hiddenRGB == 0
            && opaqueChroma == 0
            && visibleMagenta == 0
            && padding.count == 4
            && padding.allSatisfy { $0 > 2 },
    ]
}

func calibrationDifference(
    _ first: CalibrationRaster,
    _ second: CalibrationRaster
) throws -> [String: Any] {
    guard
        first.width == second.width,
        first.height == second.height
    else {
        throw CommercialL4NormalizedReviewError.invalid(
            "comparison dimensions differ"
        )
    }
    var differingPixels = 0
    var differingChannels = 0
    var alphaDifferingPixels = 0
    var visibilityCategoryFlips = 0
    var maximumChannelDelta = 0
    var absoluteLumaDelta = 0
    var minimumX = first.width
    var minimumY = first.height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<first.height {
        for x in 0..<first.width {
            let offset = (y * first.width + x) * 4
            var changed = false
            for channel in 0..<4 {
                let delta = abs(
                    Int(first.rgba[offset + channel])
                        - Int(second.rgba[offset + channel])
                )
                if delta > 0 {
                    differingChannels += 1
                    changed = true
                    maximumChannelDelta = max(maximumChannelDelta, delta)
                    if channel == 3 {
                        alphaDifferingPixels += 1
                    }
                }
            }
            let firstVisible = first.rgba[offset + 3] > 0
            let secondVisible = second.rgba[offset + 3] > 0
            if firstVisible != secondVisible {
                visibilityCategoryFlips += 1
            }
            if firstVisible || secondVisible {
                let firstLuma =
                    (
                        54 * Int(first.rgba[offset])
                        + 183 * Int(first.rgba[offset + 1])
                        + 19 * Int(first.rgba[offset + 2])
                        + 128
                    ) >> 8
                let secondLuma =
                    (
                        54 * Int(second.rgba[offset])
                        + 183 * Int(second.rgba[offset + 1])
                        + 19 * Int(second.rgba[offset + 2])
                        + 128
                    ) >> 8
                absoluteLumaDelta += abs(firstLuma - secondLuma)
            }
            if changed {
                differingPixels += 1
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
            }
        }
    }
    return [
        "differingPixelCount": differingPixels,
        "differingChannelCount": differingChannels,
        "alphaDifferingPixelCount": alphaDifferingPixels,
        "visibilityCategoryFlipCount": visibilityCategoryFlips,
        "maximumChannelDelta": maximumChannelDelta,
        "absoluteLumaDeltaSum": absoluteLumaDelta,
        "differenceBounds":
            differingPixels == 0
            ? [] : [minimumX, minimumY, maximumX + 1, maximumY + 1],
    ]
}

func unionCalibrationCrop(
    _ first: CalibrationRaster,
    _ second: CalibrationRaster,
    padding: Int
) throws -> CGRect {
    let firstBounds = calibrationBounds(first)
    let secondBounds = calibrationBounds(second)
    guard firstBounds.count == 4, secondBounds.count == 4 else {
        throw CommercialL4NormalizedReviewError.invalid(
            "empty alpha bounds"
        )
    }
    let minimumX = max(0, min(firstBounds[0], secondBounds[0]) - padding)
    let minimumY = max(0, min(firstBounds[1], secondBounds[1]) - padding)
    let maximumX = min(
        first.width,
        max(firstBounds[2], secondBounds[2]) + padding
    )
    let maximumY = min(
        first.height,
        max(firstBounds[3], secondBounds[3]) + padding
    )
    return CGRect(
        x: minimumX,
        y: minimumY,
        width: maximumX - minimumX,
        height: maximumY - minimumY
    )
}

func writeCalibrationPNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw CommercialL4NormalizedReviewError.invalid(
            "could not create PNG destination"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CommercialL4NormalizedReviewError.invalid(
            "could not finalize PNG"
        )
    }
}

func buildCalibrationPanel(
    images: [CGImage],
    crop: CGRect?,
    scale: Int,
    outputURL: URL
) throws {
    guard images.count == 4 else {
        throw CommercialL4NormalizedReviewError.invalid(
            "panel requires four images"
        )
    }
    let sourceWidth = Int(crop?.width ?? CGFloat(images[0].width))
    let sourceHeight = Int(crop?.height ?? CGFloat(images[0].height))
    let cellWidth = sourceWidth * scale
    let cellHeight = sourceHeight * scale
    guard let context = CGContext(
        data: nil,
        width: cellWidth * 2,
        height: cellHeight * 2,
        bitsPerComponent: 8,
        bytesPerRow: cellWidth * 2 * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw CommercialL4NormalizedReviewError.invalid(
            "could not allocate panel context"
        )
    }
    context.setFillColor(
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [0.88, 0.88, 0.86, 1]
        )!
    )
    context.fill(
        CGRect(
            x: 0,
            y: 0,
            width: cellWidth * 2,
            height: cellHeight * 2
        )
    )
    context.interpolationQuality = scale == 1 ? .none : .high
    for (index, image) in images.enumerated() {
        let source = crop.flatMap { image.cropping(to: $0) } ?? image
        let column = index % 2
        let row = index / 2
        context.draw(
            source,
            in: CGRect(
                x: column * cellWidth,
                y: (1 - row) * cellHeight,
                width: cellWidth,
                height: cellHeight
            )
        )
    }
    guard let output = context.makeImage() else {
        throw CommercialL4NormalizedReviewError.invalid(
            "could not create panel image"
        )
    }
    try writeCalibrationPNG(output, to: outputURL)
}

func calibrationJSONObject(_ url: URL) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(
        with: Data(contentsOf: url)
    ) as? [String: Any] else {
        throw CommercialL4NormalizedReviewError.invalid(
            "invalid JSON \(url.path)"
        )
    }
    return object
}

@main
enum BuildCommercialL4WestNormalizedCalibrationReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let diagnosticRoot = URL(
            fileURLWithPath:
                try calibrationArgument("--diagnostic-root", in: arguments)
        )
        let repeatRoot = URL(
            fileURLWithPath:
                try calibrationArgument("--repeat-root", in: arguments)
        )
        let acceptedRoot = URL(
            fileURLWithPath:
                try calibrationArgument("--accepted-root", in: arguments)
        )
        let diagnosticProvenanceURL = URL(
            fileURLWithPath:
                try calibrationArgument(
                    "--diagnostic-provenance",
                    in: arguments
                )
        )
        let acceptedProvenanceURL = URL(
            fileURLWithPath:
                try calibrationArgument(
                    "--accepted-provenance",
                    in: arguments
                )
        )
        let outputDirectory = URL(
            fileURLWithPath:
                try calibrationArgument("--output-directory", in: arguments)
        )
        guard !FileManager.default.fileExists(
            atPath: outputDirectory.path
        ) else {
            throw CommercialL4NormalizedReviewError.invalid(
                "output directory must be absent"
            )
        }
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let diagnosticProvenance = try calibrationJSONObject(
            diagnosticProvenanceURL
        )
        let acceptedProvenance = try calibrationJSONObject(
            acceptedProvenanceURL
        )
        let fileNames = [
            "block": "generated_v4_commercial_l04_block.png",
            "neighborhood":
                "generated_v4_commercial_l04_neighborhood.png",
            "city": "generated_v4_commercial_l04_city.png",
        ]
        var lodInputs: [LODInputs] = []
        for name in ["block", "neighborhood", "city"] {
            guard let fileName = fileNames[name] else {
                throw CommercialL4NormalizedReviewError.invalid(
                    "missing LOD filename"
                )
            }
            lodInputs.append(
                LODInputs(
                    name: name,
                    diagnosticA: try loadCalibrationRaster(
                        diagnosticRoot.appendingPathComponent(fileName)
                    ),
                    diagnosticB: try loadCalibrationRaster(
                        repeatRoot.appendingPathComponent(fileName)
                    ),
                    accepted: try loadCalibrationRaster(
                        acceptedRoot.appendingPathComponent(fileName)
                    )
                )
            )
        }

        var lodReports: [[String: Any]] = []
        var panelRecords: [[String: Any]] = []
        var allTechnicalPassed = true
        for lod in lodInputs {
            guard
                lod.diagnosticA.width == lod.diagnosticB.width,
                lod.diagnosticA.height == lod.diagnosticB.height,
                lod.diagnosticA.width == lod.accepted.width,
                lod.diagnosticA.height == lod.accepted.height
            else {
                throw CommercialL4NormalizedReviewError.invalid(
                    "\(lod.name) dimensions differ"
                )
            }
            let diagnosticInspection = calibrationInspection(lod.diagnosticA)
            let acceptedInspection = calibrationInspection(lod.accepted)
            let repeatDifference = try calibrationDifference(
                lod.diagnosticA,
                lod.diagnosticB
            )
            let acceptedDifference = try calibrationDifference(
                lod.diagnosticA,
                lod.accepted
            )
            let exactRepeat =
                lod.diagnosticA.fileSHA256 == lod.diagnosticB.fileSHA256
                && lod.diagnosticA.pixelSHA256
                    == lod.diagnosticB.pixelSHA256
            let registrationPreserved =
                diagnosticInspection["alphaBounds"] as? [Int]
                    == acceptedInspection["alphaBounds"] as? [Int]
                && diagnosticInspection["visiblePixelCount"] as? Int
                    == acceptedInspection["visiblePixelCount"] as? Int
                && acceptedDifference["alphaDifferingPixelCount"] as? Int == 0
                && acceptedDifference["visibilityCategoryFlipCount"] as? Int
                    == 0
            let lodTechnicalPassed =
                exactRepeat
                && (diagnosticInspection["technicalSurfacePassed"] as? Bool
                    == true)
                && registrationPreserved
            allTechnicalPassed = allTechnicalPassed && lodTechnicalPassed

            let diagnosticColor = try calibrationImage(
                rgba: lod.diagnosticA.rgba,
                width: lod.diagnosticA.width,
                height: lod.diagnosticA.height
            )
            let acceptedColor = try calibrationImage(
                rgba: lod.accepted.rgba,
                width: lod.accepted.width,
                height: lod.accepted.height
            )
            let diagnosticGray = try calibrationImage(
                rgba: grayscaleCalibrationRGBA(lod.diagnosticA.rgba),
                width: lod.diagnosticA.width,
                height: lod.diagnosticA.height
            )
            let acceptedGray = try calibrationImage(
                rgba: grayscaleCalibrationRGBA(lod.accepted.rgba),
                width: lod.accepted.width,
                height: lod.accepted.height
            )
            let images = [
                diagnosticColor,
                acceptedColor,
                diagnosticGray,
                acceptedGray,
            ]
            let crop = try unionCalibrationCrop(
                lod.diagnosticA,
                lod.accepted,
                padding: 8
            )
            let fullURL = outputDirectory.appendingPathComponent(
                "\(lod.name.uppercased())-ACTUAL-COLOR-GRAYSCALE.png"
            )
            try buildCalibrationPanel(
                images: images,
                crop: nil,
                scale: 1,
                outputURL: fullURL
            )
            let footprintURL = outputDirectory.appendingPathComponent(
                "\(lod.name.uppercased())-REGISTERED-FOOTPRINT-COLOR-GRAYSCALE.png"
            )
            try buildCalibrationPanel(
                images: images,
                crop: crop,
                scale: 1,
                outputURL: footprintURL
            )
            let zoomURL = outputDirectory.appendingPathComponent(
                "\(lod.name.uppercased())-ZOOM-COLOR-GRAYSCALE.png"
            )
            try buildCalibrationPanel(
                images: images,
                crop: crop,
                scale: 2,
                outputURL: zoomURL
            )
            for panel in [fullURL, footprintURL, zoomURL] {
                panelRecords.append([
                    "lod": lod.name,
                    "file": panel.lastPathComponent,
                    "sha256":
                        calibrationSHA256(try Data(contentsOf: panel)),
                    "panelOrder": [
                        "diagnostic color",
                        "accepted source-v03 color",
                        "diagnostic grayscale",
                        "accepted source-v03 grayscale",
                    ],
                ])
            }
            lodReports.append([
                "lod": lod.name,
                "exactRepeatIdentity": exactRepeat,
                "registrationPreserved": registrationPreserved,
                "technicalPassed": lodTechnicalPassed,
                "diagnostic": diagnosticInspection,
                "acceptedSourceV03": acceptedInspection,
                "repeatDifference": repeatDifference,
                "acceptedComparison": acceptedDifference,
            ])
        }

        let diagnosticRegistration =
            diagnosticProvenance["registration"] as? [String: Any]
        let acceptedRegistration =
            acceptedProvenance["registration"] as? [String: Any]
        let provenanceRegistrationPassed =
            diagnosticRegistration?["target_ground_pivot"] as? [Int]
                == [768, 896]
            && diagnosticRegistration?["target_origin"] as? [Int]
                == [559, 200]
            && diagnosticRegistration?["target_size"] as? [Int]
                == [419, 696]
            && diagnosticRegistration?["source_bbox"] as? [Int]
                == [630, 421, 869, 818]
            && NSDictionary(dictionary: diagnosticRegistration ?? [:])
                .isEqual(to: acceptedRegistration ?? [:])
            && diagnosticProvenance["productionSelected"] as? Bool == false
            && acceptedProvenance["productionSelected"] as? Bool == false
        allTechnicalPassed =
            allTechnicalPassed && provenanceRegistrationPassed

        let uniqueFiles = Set(
            lodInputs.map { $0.diagnosticA.fileSHA256 }
        ).count == lodInputs.count
        let uniquePixels = Set(
            lodInputs.map { $0.diagnosticA.pixelSHA256 }
        ).count == lodInputs.count
        allTechnicalPassed =
            allTechnicalPassed && uniqueFiles && uniquePixels

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "commercial-l04-west-normalized-diagnostic-calibration",
            "finalDisposition":
                allTechnicalPassed
                ? "PENDING_INDEPENDENT_VISUAL_REVIEW"
                : "REJECT",
            "technicalPassed": allTechnicalPassed,
            "sourceAuthority": false,
            "productionSelected": false,
            "sceneKitMetalProcessCount": 0,
            "normalizerProcessCount": 2,
            "normalizerSourceSHA256":
                try calibrationArgument(
                    "--normalizer-source-sha256",
                    in: arguments
                ),
            "normalizerBinarySHA256":
                try calibrationArgument(
                    "--normalizer-binary-sha256",
                    in: arguments
                ),
            "validatorBinarySHA256":
                try calibrationArgument(
                    "--validator-binary-sha256",
                    in: arguments
                ),
            "immutableRawInputSHA256":
                diagnosticProvenance["source_sha256"] ?? "",
            "normalizationParameters": [
                "objectWidth": diagnosticProvenance["object_width"] ?? 0,
                "referenceWidth":
                    diagnosticProvenance["reference_subject_width"] ?? 0,
            ],
            "repeatProvenanceByteIdentical":
                calibrationSHA256(try Data(contentsOf: diagnosticProvenanceURL))
                == calibrationSHA256(
                    try Data(
                        contentsOf:
                            repeatRoot.appendingPathComponent(
                                "provenance.json"
                            )
                    )
                ),
            "provenanceRegistrationPassed":
                provenanceRegistrationPassed,
            "diagnosticRegistration": diagnosticRegistration ?? [:],
            "acceptedRegistration": acceptedRegistration ?? [:],
            "uniqueLODFileIdentities": uniqueFiles,
            "uniqueLODDecodedPixelIdentities": uniquePixels,
            "lods": lodReports,
            "panels": panelRecords,
            "visualReviewChecklist": [
                "edge loss",
                "halos",
                "stair steps",
                "value and material drift",
                "footprint and shadow loss",
                "frontage and window-frame feature survival",
            ],
            "visualDisposition": "PENDING_INDEPENDENT_REVIEW",
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
            allTechnicalPassed
                ? "PENDING_INDEPENDENT_VISUAL_REVIEW" : "REJECT"
        )
    }
}
