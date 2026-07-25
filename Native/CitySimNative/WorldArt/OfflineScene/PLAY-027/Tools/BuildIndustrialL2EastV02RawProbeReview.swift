import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import SceneKit
import UniformTypeIdentifiers

enum IndustrialL2EastV02ReviewError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l2-east-v02-raw-probe-review --repository-root <path> --probe-root <path> --output-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct ReviewImage {
    let image: CGImage
    let rgba: [UInt8]
    let width: Int
    let height: Int
}

private struct PixelBounds {
    let minimumX: Int
    let minimumY: Int
    let maximumX: Int
    let maximumY: Int
    let count: Int

    var width: Int { maximumX >= minimumX ? maximumX - minimumX + 1 : 0 }
    var height: Int { maximumY >= minimumY ? maximumY - minimumY + 1 : 0 }

    var record: [String: Any] {
        [
            "minimum": [minimumX, minimumY],
            "maximum": [maximumX, maximumY],
            "width": width,
            "height": height,
            "pixelCount": count,
        ]
    }
}

private let expectedDescriptorSHA256 =
    "01ee10ef87c7a23d8fab151091f7237fc0a12563694cea3080f63a25d4e90775"
private let expectedMaterialSHA256 =
    "94069509093c122d4cb2383bd648757561f6561f78b8345c6222b5354f3f18f6"
private let expectedValidationSHA256 =
    "db7f6c67a7d858e9d2177386d84b6ec8f43ebceb5d5d858bd30553cb7d9d4269"
private let native2xScale = 144.0 / 512.0

private func reviewArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2EastV02ReviewError.arguments
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

private func reviewLoadImage(_ url: URL) throws -> ReviewImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw IndustrialL2EastV02ReviewError.invalid(
            "could not decode \(url.path)"
        )
    }
    let width = image.width
    let height = image.height
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    let created = rgba.withUnsafeMutableBytes { storage -> Bool in
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
            return false
        }
        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
        return true
    }
    guard created else {
        throw IndustrialL2EastV02ReviewError.invalid(
            "could not decode RGBA \(url.path)"
        )
    }
    return ReviewImage(
        image: image,
        rgba: rgba,
        width: width,
        height: height
    )
}

private func reviewBounds(
    width: Int,
    height: Int,
    predicate: (Int) -> Bool
) -> PixelBounds {
    var minimumX = width
    var minimumY = height
    var maximumX = -1
    var maximumY = -1
    var count = 0
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            if predicate(offset) {
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
                count += 1
            }
        }
    }
    return PixelBounds(
        minimumX: minimumX,
        minimumY: minimumY,
        maximumX: maximumX,
        maximumY: maximumY,
        count: count
    )
}

private func reviewPercentile(
    _ values: [Int],
    _ percentile: Double
) -> Int {
    let sorted = values.sorted()
    let index = min(
        sorted.count - 1,
        max(0, Int((Double(sorted.count - 1) * percentile).rounded()))
    )
    return sorted[index]
}

private func reviewLuma(
    red: UInt8,
    green: UInt8,
    blue: UInt8
) -> Int {
    let redContribution = 0.2126 * Double(red)
    let greenContribution = 0.7152 * Double(green)
    let blueContribution = 0.0722 * Double(blue)
    return Int(
        (redContribution + greenContribution + blueContribution).rounded()
    )
}

private func reviewResize(
    _ image: CGImage,
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
        throw IndustrialL2EastV02ReviewError.invalid(
            "could not allocate resize context"
        )
    }
    context.interpolationQuality = .high
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: width, height: height)
    )
    guard let output = context.makeImage() else {
        throw IndustrialL2EastV02ReviewError.invalid(
            "could not create resized image"
        )
    }
    return output
}

private func reviewGrayscale(_ image: CGImage) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else {
        throw IndustrialL2EastV02ReviewError.invalid(
            "could not allocate grayscale context"
        )
    }
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    guard let output = context.makeImage() else {
        throw IndustrialL2EastV02ReviewError.invalid(
            "could not create grayscale image"
        )
    }
    return output
}

private func reviewCrop(
    _ image: CGImage,
    x: Int,
    y: Int,
    width: Int,
    height: Int
) throws -> CGImage {
    guard let output = image.cropping(
        to: CGRect(x: x, y: y, width: width, height: height)
    ) else {
        throw IndustrialL2EastV02ReviewError.invalid(
            "could not crop review image"
        )
    }
    return output
}

private func reviewContactSheet(
    images: [CGImage],
    columns: Int,
    background: NSColor = .white
) throws -> CGImage {
    guard let first = images.first else {
        throw IndustrialL2EastV02ReviewError.invalid("empty contact sheet")
    }
    let rows = Int(ceil(Double(images.count) / Double(columns)))
    let gap = 16
    let width = columns * first.width + (columns + 1) * gap
    let height = rows * first.height + (rows + 1) * gap
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
        throw IndustrialL2EastV02ReviewError.invalid(
            "could not allocate contact sheet"
        )
    }
    context.setFillColor(background.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    for (index, image) in images.enumerated() {
        let column = index % columns
        let row = index / columns
        context.draw(
            image,
            in: CGRect(
                x: gap + column * (first.width + gap),
                y: height - gap - (row + 1) * first.height - row * gap,
                width: first.width,
                height: first.height
            )
        )
    }
    guard let output = context.makeImage() else {
        throw IndustrialL2EastV02ReviewError.invalid(
            "could not create contact sheet"
        )
    }
    return output
}

private func reviewWritePNG(
    _ image: CGImage,
    to url: URL
) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw IndustrialL2EastV02ReviewError.invalid(
            "could not create PNG destination"
        )
    }
    CGImageDestinationAddImage(
        destination,
        image,
        [kCGImagePropertyHasAlpha: true] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL2EastV02ReviewError.invalid(
            "could not finalize \(url.path)"
        )
    }
}

private func reviewWriteJSON(
    _ value: Any,
    to url: URL
) throws {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try data.write(to: url, options: .atomic)
}

private func reviewProjectedBounds(
    _ component: MassBlockDescriptor,
    descriptor: SceneDescriptor
) -> CGRect {
    let node = SCNNode()
    let camera = SCNCamera()
    camera.usesOrthographicProjection = true
    camera.orthographicScale = descriptor.camera.orthographicScale
    camera.projectionDirection = .vertical
    node.camera = camera
    node.position = SCNVector3(
        descriptor.camera.positionWorld[0],
        descriptor.camera.positionWorld[1],
        descriptor.camera.positionWorld[2]
    )
    node.look(
        at: SCNVector3(
            descriptor.camera.targetWorld[0],
            descriptor.camera.targetWorld[1],
            descriptor.camera.targetWorld[2]
        ),
        up: SCNVector3(0, 1, 0),
        localFront: SCNVector3(0, 0, -1)
    )
    let pixelsPerWorld =
        Double(descriptor.camera.renderViewportPixels[1])
        / (2 * descriptor.camera.orthographicScale)
    var xs: [Double] = []
    var ys: [Double] = []
    for xSign in [-1.0, 1.0] {
        for ySign in [-1.0, 1.0] {
            for zSign in [-1.0, 1.0] {
                let local = node.convertPosition(
                    SCNVector3(
                        component.positionWorld[0]
                            + xSign * component.dimensions[0] / 2,
                        component.positionWorld[1]
                            + ySign * component.dimensions[1] / 2,
                        component.positionWorld[2]
                            + zSign * component.dimensions[2] / 2
                    ),
                    from: nil
                )
                xs.append(
                    Double(descriptor.camera.renderViewportPixels[0]) / 2
                        + Double(local.x) * pixelsPerWorld
                        + descriptor.camera.postProjectionOffsetPixels[0]
                )
                ys.append(
                    Double(descriptor.camera.renderViewportPixels[1]) / 2
                        - Double(local.y) * pixelsPerWorld
                        + descriptor.camera.postProjectionOffsetPixels[1]
                )
            }
        }
    }
    return CGRect(
        x: xs.min()!,
        y: ys.min()!,
        width: xs.max()! - xs.min()!,
        height: ys.max()! - ys.min()!
    )
}

@main
enum BuildIndustrialL2EastV02RawProbeReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try reviewArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let probeRoot = URL(
            fileURLWithPath: try reviewArgument(
                "--probe-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try reviewArgument(
                "--output-root",
                in: arguments
            )
        ).standardizedFileURL
        guard
            probeRoot.path.hasPrefix(root.path + "/"),
            probeRoot.path.contains("/raw-probe/diagnostics/east-primary"),
            outputRoot.path.hasPrefix(root.path + "/"),
            outputRoot.path.contains("/raw-probe/review"),
            !FileManager.default.fileExists(atPath: outputRoot.path)
        else {
            throw IndustrialL2EastV02ReviewError.invalid(
                "review input/output boundary failed"
            )
        }

        let descriptorURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialsURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/materials/industrial-l02-projection-silhouette-reset-v02.json"
        )
        let prepixelURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v02/prepixel/PREPIXEL-VALIDATION.json"
        )
        guard
            try reviewSHA256(descriptorURL) == expectedDescriptorSHA256,
            try reviewSHA256(materialsURL) == expectedMaterialSHA256,
            try reviewSHA256(prepixelURL) == expectedValidationSHA256
        else {
            throw IndustrialL2EastV02ReviewError.invalid(
                "approved pre-pixel authority drift"
            )
        }
        let decoder = JSONDecoder()
        let descriptor = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: descriptorURL)
        )
        let rawURL = probeRoot.appendingPathComponent("raw.png")
        let provenanceURL = probeRoot.appendingPathComponent(
            "provenance.json"
        )
        let buildingURL = probeRoot.appendingPathComponent(
            "pre-chroma-registered-building.png"
        )
        let alphaURL = probeRoot.appendingPathComponent(
            "pre-chroma-registered-alpha.png"
        )
        let neutralURL = probeRoot.appendingPathComponent(
            "neutral-alpha-composite.png"
        )
        let raw = try reviewLoadImage(rawURL)
        let building = try reviewLoadImage(buildingURL)
        let alpha = try reviewLoadImage(alphaURL)
        let neutral = try reviewLoadImage(neutralURL)
        guard
            raw.width == 1536,
            raw.height == 1024,
            building.width == raw.width,
            building.height == raw.height,
            alpha.width == raw.width,
            alpha.height == raw.height,
            neutral.width == raw.width,
            neutral.height == raw.height
        else {
            throw IndustrialL2EastV02ReviewError.invalid(
                "probe image dimensions drifted"
            )
        }

        let exactChroma: (Int) -> Bool = {
            raw.rgba[$0] == 255
                && raw.rgba[$0 + 1] == 0
                && raw.rgba[$0 + 2] == 255
        }
        let nonMagentaRGB: (Int) -> Bool = {
            !exactChroma($0)
        }
        let rawRGBBounds = reviewBounds(
            width: raw.width,
            height: raw.height,
            predicate: nonMagentaRGB
        )
        let buildingAlphaBounds = reviewBounds(
            width: building.width,
            height: building.height
        ) { building.rgba[$0 + 3] > 8 }
        let alphaVisibleBounds = reviewBounds(
            width: alpha.width,
            height: alpha.height
        ) { alpha.rgba[$0 + 3] > 8 }

        var hiddenRGBPixelCount = 0
        var exactChromaPixelCount = 0
        var nearMagentaOpaquePixelCount = 0
        var proofMagentaFamilyPixelCount = 0
        var buildingLuma: [Int] = []
        var binCounts: [Int: Int] = [:]
        for offset in stride(from: 0, to: raw.rgba.count, by: 4) {
            if exactChroma(offset) {
                exactChromaPixelCount += 1
            } else if
                raw.rgba[offset] >= 224,
                raw.rgba[offset + 1] <= 32,
                raw.rgba[offset + 2] >= 224,
                raw.rgba[offset + 3] > 0
            {
                nearMagentaOpaquePixelCount += 1
            }
            if
                building.rgba[offset + 3] == 0,
                building.rgba[offset] != 0
                    || building.rgba[offset + 1] != 0
                    || building.rgba[offset + 2] != 0
            {
                hiddenRGBPixelCount += 1
            }
            if
                alpha.rgba[offset + 3] > 0,
                alpha.rgba[offset] >= 224,
                alpha.rgba[offset + 1] <= 32,
                alpha.rgba[offset + 2] >= 224
            {
                proofMagentaFamilyPixelCount += 1
            }
            if building.rgba[offset + 3] > 128 {
                let value = reviewLuma(
                    red: raw.rgba[offset],
                    green: raw.rgba[offset + 1],
                    blue: raw.rgba[offset + 2]
                )
                buildingLuma.append(value)
                let bin = min(240, (value / 32) * 32 + 16)
                binCounts[bin, default: 0] += 1
            }
        }
        guard !buildingLuma.isEmpty else {
            throw IndustrialL2EastV02ReviewError.invalid(
                "building alpha selected no governed raw pixels"
            )
        }
        let p25 = reviewPercentile(buildingLuma, 0.25)
        let p75 = reviewPercentile(buildingLuma, 0.75)
        let p95 = reviewPercentile(buildingLuma, 0.95)
        let maximumBinCount = binCounts.values.max() ?? 0
        let maximumBinShare =
            Double(maximumBinCount) / Double(buildingLuma.count)

        let massByID = Dictionary(
            uniqueKeysWithValues:
                (descriptor.building.massBlocks ?? []).map {
                    ($0.id, $0)
                }
        )
        let measuredFeatureIDs = [
            "v02-dock-door-a",
            "v02-dock-door-b",
            "v02-dock-door-c",
            "v02-dock-canopy-a",
            "v02-dock-canopy-b",
            "v02-dock-canopy-c",
            "v02-personnel-door",
        ]
        var featureRecords: [[String: Any]] = []
        var minimumFeatureNative2x = Double.greatestFiniteMagnitude
        for id in measuredFeatureIDs {
            guard let component = massByID[id] else {
                throw IndustrialL2EastV02ReviewError.invalid(
                    "missing measured feature \(id)"
                )
            }
            let projected = reviewProjectedBounds(
                component,
                descriptor: descriptor
            )
            let x0 = max(0, Int(floor(projected.minX)))
            let y0 = max(0, Int(floor(projected.minY)))
            let x1 = min(raw.width - 1, Int(ceil(projected.maxX)))
            let y1 = min(raw.height - 1, Int(ceil(projected.maxY)))
            let occupied = reviewBounds(
                width: raw.width,
                height: raw.height
            ) { offset in
                let pixel = offset / 4
                let x = pixel % raw.width
                let y = pixel / raw.width
                return x >= x0 && x <= x1 && y >= y0 && y <= y1
                    && building.rgba[offset + 3] > 8
            }
            let nativeWidth = Double(occupied.width) * native2xScale
            let nativeHeight = Double(occupied.height) * native2xScale
            let surviving = max(nativeWidth, nativeHeight)
            minimumFeatureNative2x = min(
                minimumFeatureNative2x,
                surviving
            )
            featureRecords.append([
                "id": id,
                "projectedSourceBounds": [
                    projected.minX,
                    projected.minY,
                    projected.maxX,
                    projected.maxY,
                ],
                "rawAlphaOccupiedBoundsWithinProjectedROI":
                    occupied.record,
                "measuredNative2xWidthPixels": nativeWidth,
                "measuredNative2xHeightPixels": nativeHeight,
                "measuredNative2xMaximumSpanPixels": surviving,
                "passedSixPixelMinimum": surviving >= 6,
            ])
        }

        let technicalPassed =
            rawRGBBounds.width > 0
            && buildingAlphaBounds.width >= 420
            && Double(buildingAlphaBounds.width) * native2xScale >= 118
            && hiddenRGBPixelCount == 0
            && proofMagentaFamilyPixelCount == 0
            && nearMagentaOpaquePixelCount == 0
            && p25 >= 80
            && p75 - p25 >= 48
            && p95 >= 192
            && binCounts.count >= 5
            && maximumBinShare <= 0.35
            && minimumFeatureNative2x >= 6
            && descriptor.registration.footprintPolygonSource
                == [[768, 640], [1024, 768], [768, 896], [512, 768]]
            && descriptor.registration.frontageSocketSource == [896, 832]
            && descriptor.registration.groundPivotSource == [768, 896]
            && descriptor.registration.doorBaseSource
                == [[934, 813], [858, 851]]
            && descriptor.light.shadowVectorSource == [2, 1]

        try FileManager.default.createDirectory(
            at: outputRoot,
            withIntermediateDirectories: true
        )
        let nativeWidth = Int(
            (Double(neutral.width) * native2xScale).rounded()
        )
        let nativeHeight = Int(
            (Double(neutral.height) * native2xScale).rounded()
        )
        let nativeColor = try reviewResize(
            neutral.image,
            width: nativeWidth,
            height: nativeHeight
        )
        let nativeGray = try reviewGrayscale(nativeColor)
        let footprintCrop = try reviewCrop(
            neutral.image,
            x: 384,
            y: 320,
            width: 768,
            height: 640
        )
        let footprintNative = try reviewResize(
            footprintCrop,
            width: 216,
            height: 180
        )
        let footprintGray = try reviewGrayscale(footprintNative)
        let sourceNeutral = neutral.image
        let sourceRaw = raw.image
        let sourceSheet = try reviewContactSheet(
            images: [sourceRaw, sourceNeutral],
            columns: 2
        )
        let zoomX = max(0, buildingAlphaBounds.minimumX - 24)
        let zoomY = max(0, buildingAlphaBounds.minimumY - 24)
        let zoomWidth = min(
            neutral.width - zoomX,
            buildingAlphaBounds.width + 48
        )
        let zoomHeight = min(
            neutral.height - zoomY,
            buildingAlphaBounds.height + 48
        )
        let zoomCrop = try reviewCrop(
            neutral.image,
            x: zoomX,
            y: zoomY,
            width: zoomWidth,
            height: zoomHeight
        )
        let zoomColor = try reviewResize(
            zoomCrop,
            width: zoomCrop.width * 2,
            height: zoomCrop.height * 2
        )
        let zoomGray = try reviewGrayscale(zoomColor)
        let zoomSheet = try reviewContactSheet(
            images: [zoomColor, zoomGray],
            columns: 2
        )

        let panelImages: [(String, CGImage)] = [
            ("SOURCE-SCALE-RAW-AND-NEUTRAL.png", sourceSheet),
            ("NEUTRAL-NATIVE-2X-COLOR.png", nativeColor),
            ("NEUTRAL-NATIVE-2X-GRAYSCALE.png", nativeGray),
            ("FOOTPRINT-NATIVE-2X-COLOR.png", footprintNative),
            ("FOOTPRINT-NATIVE-2X-GRAYSCALE.png", footprintGray),
            ("ZOOM-COLOR-AND-GRAYSCALE.png", zoomSheet),
        ]
        for (name, image) in panelImages {
            try reviewWritePNG(
                image,
                to: outputRoot.appendingPathComponent(name)
            )
        }

        guard
            let prepixel = try JSONSerialization.jsonObject(
                with: Data(contentsOf: prepixelURL)
            ) as? [String: Any],
            let projection = prepixel["projection"] as? [String: Any]
        else {
            throw IndustrialL2EastV02ReviewError.invalid(
                "pre-pixel projection evidence malformed"
            )
        }
        let panelRecords = try panelImages.map { name, image in
            let url = outputRoot.appendingPathComponent(name)
            return [
                "file": url.path.replacingOccurrences(
                    of: root.path + "/",
                    with: ""
                ),
                "fileSHA256": try reviewSHA256(url),
                "pixels": [image.width, image.height],
            ] as [String: Any]
        }
        let metrics: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v02-single-primary-raw-review",
            "disposition":
                technicalPassed
                ? "PENDING_INDEPENDENT_REVIEW"
                : "REJECTED_RAW_TECHNICAL_GATE",
            "sourceAuthorityAccepted": false,
            "probe": [
                "rawFileSHA256": try reviewSHA256(rawURL),
                "rawDecodedRGBASHA256":
                    reviewSHA256(Data(raw.rgba)),
                "provenanceFileSHA256":
                    try reviewSHA256(provenanceURL),
                "descriptorSHA256": try reviewSHA256(descriptorURL),
                "materialLibrarySHA256":
                    try reviewSHA256(materialsURL),
            ],
            "alphaAndChroma": [
                "rawRGBOccupiedBounds": rawRGBBounds.record,
                "preChromaBuildingAlphaBounds":
                    buildingAlphaBounds.record,
                "preChromaBuildingAndShadowAlphaBounds":
                    alphaVisibleBounds.record,
                "alphaVisibleToRGBWidthRatio":
                    Double(alphaVisibleBounds.width)
                    / Double(rawRGBBounds.width),
                "hiddenRGBPixelCount": hiddenRGBPixelCount,
                "hiddenRGBRatio":
                    Double(hiddenRGBPixelCount)
                    / Double(building.width * building.height),
                "exactChromaPixelCount": exactChromaPixelCount,
                "nearMagentaOpaquePixelCount":
                    nearMagentaOpaquePixelCount,
                "proofMagentaFamilyPixelCount":
                    proofMagentaFamilyPixelCount,
            ],
            "registration": [
                "footprintPolygonSource":
                    descriptor.registration.footprintPolygonSource,
                "groundPivotSource":
                    descriptor.registration.groundPivotSource,
                "frontageSocketSource":
                    descriptor.registration.frontageSocketSource,
                "doorBaseSource":
                    descriptor.registration.doorBaseSource,
                "contactPolygonWorld":
                    descriptor.registration.contactPolygonWorld,
                "southeastShadowVectorSource":
                    descriptor.light.shadowVectorSource,
                "passed": true,
            ],
            "spans": [
                "measuredBuildingOnlySourceWidth":
                    buildingAlphaBounds.width,
                "measuredBuildingOnlyNative2xWidth":
                    Double(buildingAlphaBounds.width) * native2xScale,
                "predictedCoreFormSourceWidth":
                    projection[
                        "coreHallAdminLoadingWidthSourcePixels"
                    ] ?? NSNull(),
                "predictedCoreFormNative2xWidth":
                    projection[
                        "coreHallAdminLoadingWidthNative2xPixels"
                    ] ?? NSNull(),
            ],
            "features": [
                "measuredMinimumNative2xPixels":
                    minimumFeatureNative2x,
                "records": featureRecords,
            ],
            "luma": [
                "buildingOpaquePixelCount": buildingLuma.count,
                "p25": p25,
                "p75": p75,
                "p75MinusP25": p75 - p25,
                "p95": p95,
                "occupiedStep32Bins": binCounts.keys.sorted(),
                "step32BinCounts": Dictionary(
                    uniqueKeysWithValues: binCounts.map {
                        (String($0.key), $0.value)
                    }
                ),
                "maximumMajorFacadeBinShare": maximumBinShare,
                "targets": [
                    "p25Minimum": 80,
                    "p75MinusP25Minimum": 48,
                    "p95Minimum": 192,
                    "minimumOccupiedStep32Bins": 5,
                    "maximumMajorFacadeBinShare": 0.35,
                ],
            ],
            "panels": panelRecords,
            "technicalPassed": technicalPassed,
            "visualDisposition": "PENDING_INDEPENDENT_REVIEW",
            "freshMetalProcessCount": 1,
            "normalizationRunCount": 0,
            "productionSelected": false,
        ]
        try reviewWriteJSON(
            metrics,
            to: outputRoot.appendingPathComponent(
                "RAW-PROBE-METRICS.json"
            )
        )
        let inventory: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "attempt": "industrial-l02-east-v02-primary",
            "rawAttemptCount": 1,
            "repeatAttempts": 0,
            "otherDirections": 0,
            "normalizationRuns": 0,
            "disposition":
                technicalPassed
                ? "PENDING_INDEPENDENT_REVIEW"
                : "REJECTED_RAW_TECHNICAL_GATE",
            "productionSelected": false,
        ]
        try reviewWriteJSON(
            inventory,
            to: outputRoot.appendingPathComponent("INVENTORY.json")
        )
        print(
            "raw review \(technicalPassed ? "PASS" : "FAIL") "
                + "p25=\(p25) iqr=\(p75 - p25) p95=\(p95) "
                + "bins=\(binCounts.count) maxShare=\(maximumBinShare)"
        )
        print(
            "building \(buildingAlphaBounds.width) source "
                + "\(Double(buildingAlphaBounds.width) * native2xScale) native2x "
                + "featureMin=\(minimumFeatureNative2x)"
        )
        print(
            technicalPassed
            ? "PENDING_INDEPENDENT_REVIEW"
            : "REJECTED_RAW_TECHNICAL_GATE"
        )
    }
}
