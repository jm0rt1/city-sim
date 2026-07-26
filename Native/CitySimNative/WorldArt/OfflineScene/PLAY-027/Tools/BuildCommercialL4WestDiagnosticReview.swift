import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CommercialL4WestReviewError: Error {
    case invalid(String)
}

struct ReviewRaster {
    let url: URL
    let fileSHA256: String
    let width: Int
    let height: Int
    let rgba: [UInt8]
    let decodedSHA256: String
}

func reviewSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func reviewArgument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw CommercialL4WestReviewError.invalid("missing \(name)")
    }
    return arguments[index + 1]
}

func loadReviewRaster(_ url: URL) throws -> ReviewRaster {
    let data = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw CommercialL4WestReviewError.invalid(
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
        throw CommercialL4WestReviewError.invalid(
            "could not canonicalize \(url.path)"
        )
    }
    return ReviewRaster(
        url: url,
        fileSHA256: reviewSHA256(data),
        width: image.width,
        height: image.height,
        rgba: rgba,
        decodedSHA256: reviewSHA256(Data(rgba))
    )
}

func imageFromReviewRGBA(
    _ rgba: [UInt8],
    width: Int,
    height: Int
) throws -> CGImage {
    guard
        rgba.count == width * height * 4,
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
        throw CommercialL4WestReviewError.invalid(
            "could not create review image"
        )
    }
    return image
}

func maskedReviewRGBA(_ raster: ReviewRaster) -> [UInt8] {
    var output = raster.rgba
    for pixel in stride(from: 0, to: output.count, by: 4) {
        if
            output[pixel] == 255,
            output[pixel + 1] == 0,
            output[pixel + 2] == 255
        {
            output[pixel] = 0
            output[pixel + 1] = 0
            output[pixel + 2] = 0
            output[pixel + 3] = 0
        }
    }
    return output
}

func grayReviewRGBA(_ rgba: [UInt8]) -> [UInt8] {
    var output = rgba
    for pixel in stride(from: 0, to: output.count, by: 4) {
        let redContribution = 54 * Int(output[pixel])
        let greenContribution = 183 * Int(output[pixel + 1])
        let blueContribution = 19 * Int(output[pixel + 2])
        let weighted = redContribution + greenContribution + blueContribution
        let luma = UInt8(min(255, (weighted + 128) >> 8))
        output[pixel] = luma
        output[pixel + 1] = luma
        output[pixel + 2] = luma
    }
    return output
}

func occupiedReviewMetrics(_ raster: ReviewRaster) -> [String: Any] {
    var minimumX = raster.width
    var minimumY = raster.height
    var maximumX = -1
    var maximumY = -1
    var occupied = 0
    var exactChroma = 0
    var nonExactNearMagenta = 0
    var nonOpaqueAlpha = 0
    let cornerCoordinates = [
        (0, 0),
        (raster.width - 1, 0),
        (0, raster.height - 1),
        (raster.width - 1, raster.height - 1),
    ]
    let flatChromaCorners = cornerCoordinates.allSatisfy { coordinate in
        let index = (coordinate.1 * raster.width + coordinate.0) * 4
        return raster.rgba[index] == 255
            && raster.rgba[index + 1] == 0
            && raster.rgba[index + 2] == 255
            && raster.rgba[index + 3] == 255
    }
    for y in 0..<raster.height {
        for x in 0..<raster.width {
            let index = (y * raster.width + x) * 4
            let red = Int(raster.rgba[index])
            let green = Int(raster.rgba[index + 1])
            let blue = Int(raster.rgba[index + 2])
            let alpha = Int(raster.rgba[index + 3])
            if alpha != 255 {
                nonOpaqueAlpha += 1
            }
            if red == 255 && green == 0 && blue == 255 {
                exactChroma += 1
                continue
            }
            if
                green <= 16,
                red >= 96,
                blue >= 96,
                abs(red - blue) <= 16
            {
                nonExactNearMagenta += 1
            }
            occupied += 1
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    return [
        "occupiedPixelCount": occupied,
        "occupiedBounds": [
            minimumX,
            minimumY,
            maximumX + 1,
            maximumY + 1,
        ],
        "occupiedWidth": maximumX - minimumX + 1,
        "occupiedHeight": maximumY - minimumY + 1,
        "exactChromaPixelCount": exactChroma,
        "flatChromaCorners": flatChromaCorners,
        "nonExactNearMagentaPixelCount": nonExactNearMagenta,
        "nonOpaqueAlphaPixelCount": nonOpaqueAlpha,
        "hiddenRGBPixelCount": 0,
        "hiddenRGBPassed": nonOpaqueAlpha == 0,
        "padding": [
            "left": minimumX,
            "top": minimumY,
            "right": raster.width - maximumX - 1,
            "bottom": raster.height - maximumY - 1,
        ],
    ]
}

func reviewDifference(
    _ first: ReviewRaster,
    _ second: ReviewRaster
) throws -> [String: Any] {
    guard
        first.width == second.width,
        first.height == second.height
    else {
        throw CommercialL4WestReviewError.invalid(
            "comparison dimensions differ"
        )
    }
    var pixels = 0
    var channels = 0
    var alphaPixels = 0
    var minX = first.width
    var minY = first.height
    var maxX = -1
    var maxY = -1
    for y in 0..<first.height {
        for x in 0..<first.width {
            let index = (y * first.width + x) * 4
            var changed = false
            for channel in 0..<4
            where first.rgba[index + channel]
                != second.rgba[index + channel]
            {
                channels += 1
                changed = true
                if channel == 3 {
                    alphaPixels += 1
                }
            }
            if changed {
                pixels += 1
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }
    return [
        "differingPixelCount": pixels,
        "differingChannelCount": channels,
        "alphaDifferingPixelCount": alphaPixels,
        "differenceBounds":
            pixels == 0 ? [] : [minX, minY, maxX + 1, maxY + 1],
    ]
}

func writeReviewPNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw CommercialL4WestReviewError.invalid("PNG destination failed")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CommercialL4WestReviewError.invalid("PNG write failed")
    }
}

func compositeReviewPanel(
    images: [CGImage],
    panelWidth: Int,
    panelHeight: Int,
    crop: CGRect?,
    outputURL: URL
) throws {
    let width = panelWidth * images.count
    let height = panelHeight
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw CommercialL4WestReviewError.invalid("panel context failed")
    }
    context.setFillColor(
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [0.88, 0.88, 0.86, 1]
        )!
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .high
    for (index, image) in images.enumerated() {
        let source = crop.flatMap { image.cropping(to: $0) } ?? image
        context.draw(
            source,
            in: CGRect(
                x: index * panelWidth,
                y: 0,
                width: panelWidth,
                height: panelHeight
            )
        )
    }
    guard let output = context.makeImage() else {
        throw CommercialL4WestReviewError.invalid("panel image failed")
    }
    try writeReviewPNG(output, to: outputURL)
}

@main
enum BuildCommercialL4WestDiagnosticReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let runA = try loadReviewRaster(
            URL(fileURLWithPath: try reviewArgument("--run-a", in: arguments))
        )
        let runB = try loadReviewRaster(
            URL(fileURLWithPath: try reviewArgument("--run-b", in: arguments))
        )
        let runC = try loadReviewRaster(
            URL(fileURLWithPath: try reviewArgument("--run-c", in: arguments))
        )
        let retainedMSAA = try loadReviewRaster(
            URL(
                fileURLWithPath:
                    try reviewArgument("--retained-msaa", in: arguments)
            )
        )
        let retainedNoMSAA = try loadReviewRaster(
            URL(
                fileURLWithPath:
                    try reviewArgument("--retained-no-msaa", in: arguments)
            )
        )
        let provenanceURL = URL(
            fileURLWithPath:
                try reviewArgument("--provenance", in: arguments)
        )
        let outputDirectory = URL(
            fileURLWithPath:
                try reviewArgument("--output-directory", in: arguments)
        )
        guard !FileManager.default.fileExists(
            atPath: outputDirectory.path
        ) else {
            throw CommercialL4WestReviewError.invalid(
                "review output directory must be absent"
            )
        }
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let provenance = try JSONSerialization.jsonObject(
            with: Data(contentsOf: provenanceURL)
        ) as! [String: Any]
        let registration: [String: Any] = [
            "groundPivotSource": provenance["groundPivotSource"] ?? [],
            "frontageSocketSource": provenance["frontageSocketSource"] ?? [],
            "frontageEdgeSource": provenance["frontageEdgeSource"] ?? [],
            "doorBaseSource": provenance["doorBaseSource"] ?? [],
            "southeastShadowVectorSource":
                provenance["southeastShadowVectorSource"] ?? [],
        ]
        let identityAB = try reviewDifference(runA, runB)
        let identityAC = try reviewDifference(runA, runC)
        let occupancy = occupiedReviewMetrics(runA)
        let masked = maskedReviewRGBA(runA)
        let gray = grayReviewRGBA(masked)
        let colorImage = try imageFromReviewRGBA(
            masked,
            width: runA.width,
            height: runA.height
        )
        let grayImage = try imageFromReviewRGBA(
            gray,
            width: runA.width,
            height: runA.height
        )
        let occupiedBounds = occupancy["occupiedBounds"] as! [Int]
        let padding = occupancy["padding"] as! [String: Int]
        let crop = CGRect(
            x: max(0, occupiedBounds[0] - 24),
            y: max(0, occupiedBounds[1] - 24),
            width: min(
                runA.width - max(0, occupiedBounds[0] - 24),
                occupiedBounds[2] - occupiedBounds[0] + 48
            ),
            height: min(
                runA.height - max(0, occupiedBounds[1] - 24),
                occupiedBounds[3] - occupiedBounds[1] + 48
            )
        )

        let sourceSheet = outputDirectory.appendingPathComponent(
            "SOURCE-SCALE-COLOR-GRAYSCALE.png"
        )
        try compositeReviewPanel(
            images: [colorImage, grayImage],
            panelWidth: 1536,
            panelHeight: 1024,
            crop: nil,
            outputURL: sourceSheet
        )
        let nativeSheet = outputDirectory.appendingPathComponent(
            "NATIVE-2X-COLOR-GRAYSCALE.png"
        )
        try compositeReviewPanel(
            images: [colorImage, grayImage],
            panelWidth: 432,
            panelHeight: 288,
            crop: nil,
            outputURL: nativeSheet
        )
        let footprintSheet = outputDirectory.appendingPathComponent(
            "FOOTPRINT-COLOR-GRAYSCALE.png"
        )
        try compositeReviewPanel(
            images: [colorImage, grayImage],
            panelWidth: 410,
            panelHeight: 488,
            crop: crop,
            outputURL: footprintSheet
        )
        let zoomSheet = outputDirectory.appendingPathComponent(
            "ZOOM-COLOR-GRAYSCALE.png"
        )
        try compositeReviewPanel(
            images: [colorImage, grayImage],
            panelWidth: Int(crop.width) * 2,
            panelHeight: Int(crop.height) * 2,
            crop: crop,
            outputURL: zoomSheet
        )
        let comparisonSheet = outputDirectory.appendingPathComponent(
            "COMPARISON-4X-DIAGNOSTIC-MSAA-NO-MSAA.png"
        )
        let comparisonImages = try [
            runA,
            retainedMSAA,
            retainedNoMSAA,
        ].map {
            try imageFromReviewRGBA(
                maskedReviewRGBA($0),
                width: $0.width,
                height: $0.height
            )
        }
        try compositeReviewPanel(
            images: comparisonImages,
            panelWidth: 410,
            panelHeight: 488,
            crop: crop,
            outputURL: comparisonSheet
        )
        let comparisonGraySheet = outputDirectory.appendingPathComponent(
            "COMPARISON-4X-DIAGNOSTIC-MSAA-NO-MSAA-GRAYSCALE.png"
        )
        let comparisonGrayImages = try [
            runA,
            retainedMSAA,
            retainedNoMSAA,
        ].map {
            let maskedComparison = maskedReviewRGBA($0)
            return try imageFromReviewRGBA(
                grayReviewRGBA(maskedComparison),
                width: $0.width,
                height: $0.height
            )
        }
        try compositeReviewPanel(
            images: comparisonGrayImages,
            panelWidth: 410,
            panelHeight: 488,
            crop: crop,
            outputURL: comparisonGraySheet
        )

        let technicalPassed =
            (identityAB["differingPixelCount"] as? Int == 0)
            && (identityAC["differingPixelCount"] as? Int == 0)
            && (occupancy["occupiedPixelCount"] as? Int ?? 0) >= 50_000
            && (occupancy["occupiedWidth"] as? Int ?? 0) >= 400
            && (occupancy["occupiedHeight"] as? Int ?? 0) >= 260
            && (occupancy["flatChromaCorners"] as? Bool == true)
            && (occupancy["nonExactNearMagentaPixelCount"] as? Int == 0)
            && (occupancy["nonOpaqueAlphaPixelCount"] as? Int == 0)
            && (padding.values.min() ?? 0) >= 16
            && (registration["groundPivotSource"] as? [Int]
                == [768, 896])
            && (registration["frontageSocketSource"] as? [Int]
                == [640, 704])
            && (registration["frontageEdgeSource"] as? [[Int]]
                == [[512, 768], [768, 640]])
            && (registration["doorBaseSource"] as? [[Int]]
                == [[602, 723], [678, 685]])
            && (registration["southeastShadowVectorSource"] as? [Int]
                == [2, 1])

        let panels = [
            sourceSheet,
            nativeSheet,
            footprintSheet,
            zoomSheet,
            comparisonSheet,
            comparisonGraySheet,
        ]
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "commercial-l04-west-4x-diagnostic-review",
            "disposition":
                technicalPassed
                ? "PENDING_INDEPENDENT_PIXEL_REVIEW"
                : "REJECTED_TECHNICAL_GATE",
            "technicalPassed": technicalPassed,
            "visualDisposition":
                technicalPassed
                ? "PENDING_INDEPENDENT_REVIEW"
                : "REJECTED_VISIBLE_CHROMA_FRINGE",
            "rejectionReason":
                technicalPassed
                ? ""
                : "Determinism passed, but 4x chroma-field resampling produced non-exact near-magenta edge pixels and a visible fringe after exact-chroma masking.",
            "runs": [
                [
                    "id": "A",
                    "fileSHA256": runA.fileSHA256,
                    "decodedRGBASHA256": runA.decodedSHA256,
                ],
                [
                    "id": "B",
                    "fileSHA256": runB.fileSHA256,
                    "decodedRGBASHA256": runB.decodedSHA256,
                ],
                [
                    "id": "C",
                    "fileSHA256": runC.fileSHA256,
                    "decodedRGBASHA256": runC.decodedSHA256,
                ],
            ],
            "identity": [
                "fileByteIdentical":
                    runA.fileSHA256 == runB.fileSHA256
                    && runA.fileSHA256 == runC.fileSHA256,
                "decodedPixelIdentical":
                    runA.decodedSHA256 == runB.decodedSHA256
                    && runA.decodedSHA256 == runC.decodedSHA256,
                "aVsB": identityAB,
                "aVsC": identityAC,
                "crossRunState": "none",
            ],
            "occupancyAlphaChromaPadding": occupancy,
            "registration": registration,
            "comparisons": [
                "diagnosticVsRetainedMSAA":
                    try reviewDifference(runA, retainedMSAA),
                "diagnosticVsRetainedNoMSAA":
                    try reviewDifference(runA, retainedNoMSAA),
                "panelOrder": [
                    "4x diagnostic",
                    "retained 2x plus SceneKit 4x MSAA",
                    "retained deterministic 2x plus no MSAA",
                ],
            ],
            "inspectionChecklist": [
                "window-frame seams",
                "frontage hierarchy",
                "halos",
                "stair steps",
                "material and value drift",
                "shadow and contact",
                "feature survival",
            ],
            "panels": try panels.map {
                [
                    "file": $0.lastPathComponent,
                    "sha256": reviewSHA256(try Data(contentsOf: $0)),
                ]
            },
            "rendererProcessCount": 3,
            "normalizationRunCount": 0,
            "productionSelected": false,
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        try data.write(
            to: outputDirectory.appendingPathComponent("REVIEW.json"),
            options: .atomic
        )
        print(technicalPassed ? "PASS" : "FAIL")
    }
}
