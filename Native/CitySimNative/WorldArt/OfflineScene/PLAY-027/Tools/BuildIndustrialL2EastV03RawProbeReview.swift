import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import SceneKit
import UniformTypeIdentifiers

enum IndustrialL2EastV03ReviewError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l2-east-v03-raw-probe-review --repository-root <path> --probe-root <path> --output-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct V03ReviewImage {
    let image: CGImage
    let rgba: [UInt8]
    let width: Int
    let height: Int
}

private struct V03PixelBounds {
    let minimumX: Int
    let minimumY: Int
    let maximumX: Int
    let maximumY: Int
    let count: Int

    var width: Int {
        maximumX >= minimumX ? maximumX - minimumX + 1 : 0
    }
    var height: Int {
        maximumY >= minimumY ? maximumY - minimumY + 1 : 0
    }
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

private let v03ReviewCommit =
    "aaa431e867a635d78f70e422caa756efe71d07e8"
private let v03ReviewDescriptorSHA256 =
    "d32c2aaf03cebf53f3821515b19ab03fd86e759687fed9b4bf68eda14e1b65ca"
private let v03ReviewMaterialSHA256 =
    "94069509093c122d4cb2383bd648757561f6561f78b8345c6222b5354f3f18f6"
private let v03ReviewValidationSHA256 =
    "f73a0a077e058845a03ed8cf273babebbab11fec6bd87dce34444ccd20d42a47"
private let v03ReviewV02RejectionSHA256 =
    "7ca9a9dcdbf0552872baecb311eb5459c54d4c186e65ae8f3fa66015020cf4f5"
private let v03ReviewProbeSuffix =
    "/docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/diagnostics/east-primary"
private let v03ReviewOutputSuffix =
    "/docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/review"
private let v03Native2xScale = 144.0 / 512.0

private func v03ReviewArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2EastV03ReviewError.arguments
    }
    return arguments[index + 1]
}

private func v03ReviewSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func v03ReviewSHA256(_ url: URL) throws -> String {
    v03ReviewSHA256(try Data(contentsOf: url))
}

private func v03ReviewLoadImage(
    _ url: URL
) throws -> V03ReviewImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw IndustrialL2EastV03ReviewError.invalid(
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
        throw IndustrialL2EastV03ReviewError.invalid(
            "could not decode canonical RGBA \(url.path)"
        )
    }
    return V03ReviewImage(
        image: image,
        rgba: rgba,
        width: width,
        height: height
    )
}

private func v03ReviewBounds(
    width: Int,
    height: Int,
    predicate: (Int) -> Bool
) -> V03PixelBounds {
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    var count = 0
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            if predicate(offset) {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
                count += 1
            }
        }
    }
    return V03PixelBounds(
        minimumX: minX,
        minimumY: minY,
        maximumX: maxX,
        maximumY: maxY,
        count: count
    )
}

private func v03ReviewPercentile(
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

private func v03ReviewLuma(
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

private func v03ReviewRGBAContext(
    width: Int,
    height: Int
) throws -> CGContext {
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
        throw IndustrialL2EastV03ReviewError.invalid(
            "could not allocate review context"
        )
    }
    return context
}

private func v03ReviewResize(
    _ image: CGImage,
    width: Int,
    height: Int
) throws -> CGImage {
    let context = try v03ReviewRGBAContext(
        width: width,
        height: height
    )
    context.interpolationQuality = .high
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: width, height: height)
    )
    guard let output = context.makeImage() else {
        throw IndustrialL2EastV03ReviewError.invalid(
            "could not create resized image"
        )
    }
    return output
}

private func v03ReviewGrayscale(
    _ image: CGImage
) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else {
        throw IndustrialL2EastV03ReviewError.invalid(
            "could not allocate grayscale context"
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
    guard let output = context.makeImage() else {
        throw IndustrialL2EastV03ReviewError.invalid(
            "could not create grayscale image"
        )
    }
    return output
}

private func v03ReviewCrop(
    _ image: CGImage,
    x: Int,
    y: Int,
    width: Int,
    height: Int
) throws -> CGImage {
    guard let output = image.cropping(
        to: CGRect(x: x, y: y, width: width, height: height)
    ) else {
        throw IndustrialL2EastV03ReviewError.invalid(
            "could not crop review image"
        )
    }
    return output
}

private func v03ReviewContactSheet(
    images: [CGImage],
    columns: Int
) throws -> CGImage {
    guard let first = images.first else {
        throw IndustrialL2EastV03ReviewError.invalid(
            "empty contact sheet"
        )
    }
    let gap = 16
    let rows = Int(ceil(Double(images.count) / Double(columns)))
    let width = columns * first.width + (columns + 1) * gap
    let height = rows * first.height + (rows + 1) * gap
    let context = try v03ReviewRGBAContext(
        width: width,
        height: height
    )
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    for (index, image) in images.enumerated() {
        let column = index % columns
        let row = index / columns
        context.draw(
            image,
            in: CGRect(
                x: gap + column * (first.width + gap),
                y: height - gap - (row + 1) * first.height
                    - row * gap,
                width: first.width,
                height: first.height
            )
        )
    }
    guard let output = context.makeImage() else {
        throw IndustrialL2EastV03ReviewError.invalid(
            "could not create contact sheet"
        )
    }
    return output
}

private func v03ReviewWritePNG(
    _ image: CGImage,
    to url: URL
) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw IndustrialL2EastV03ReviewError.invalid(
            "could not create PNG destination"
        )
    }
    CGImageDestinationAddImage(
        destination,
        image,
        [kCGImagePropertyHasAlpha: true] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL2EastV03ReviewError.invalid(
            "could not finalize \(url.path)"
        )
    }
}

private func v03ReviewWriteJSON(
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

private func v03ReviewProjectedBounds(
    _ component: MassBlockDescriptor,
    descriptor: SceneDescriptor
) -> CGRect {
    let cameraNode = SCNNode()
    let camera = SCNCamera()
    camera.usesOrthographicProjection = true
    camera.orthographicScale = descriptor.camera.orthographicScale
    camera.projectionDirection = .vertical
    cameraNode.camera = camera
    cameraNode.position = SCNVector3(
        descriptor.camera.positionWorld[0],
        descriptor.camera.positionWorld[1],
        descriptor.camera.positionWorld[2]
    )
    cameraNode.look(
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
                let local = cameraNode.convertPosition(
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

private func v03ReviewUnion(_ rects: [CGRect]) -> CGRect {
    rects.dropFirst().reduce(rects[0]) { $0.union($1) }
}

@main
enum BuildIndustrialL2EastV03RawProbeReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try v03ReviewArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let probeRoot = URL(
            fileURLWithPath: try v03ReviewArgument(
                "--probe-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try v03ReviewArgument(
                "--output-root",
                in: arguments
            )
        ).standardizedFileURL
        guard
            probeRoot.path == root.path + v03ReviewProbeSuffix,
            outputRoot.path == root.path + v03ReviewOutputSuffix,
            !FileManager.default.fileExists(atPath: outputRoot.path)
        else {
            throw IndustrialL2EastV03ReviewError.invalid(
                "v03 review input/output or one-run boundary failed"
            )
        }
        let descriptorURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v03/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialsURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/materials/industrial-l02-projection-silhouette-reset-v02.json"
        )
        let validationURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/prepixel/PREPIXEL-VALIDATION.json"
        )
        let v02RejectionURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v02/raw-probe/rejection/REJECTION.md"
        )
        guard
            try v03ReviewSHA256(descriptorURL)
                == v03ReviewDescriptorSHA256,
            try v03ReviewSHA256(materialsURL)
                == v03ReviewMaterialSHA256,
            try v03ReviewSHA256(validationURL)
                == v03ReviewValidationSHA256,
            try v03ReviewSHA256(v02RejectionURL)
                == v03ReviewV02RejectionSHA256
        else {
            throw IndustrialL2EastV03ReviewError.invalid(
                "v03 authority or preserved v02 rejection drift"
            )
        }
        let descriptor = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: Data(contentsOf: descriptorURL)
        )
        guard
            descriptor.sourceRevision
                == "projection-silhouette-reset-art-proof-v03",
            descriptor.sceneGeometryID
                == "industrial-l02-east-wide-low-campus-geometry-v03",
            !descriptor.productionSelected
        else {
            throw IndustrialL2EastV03ReviewError.invalid(
                "v03 descriptor identity drift"
            )
        }

        let rawURL = probeRoot.appendingPathComponent("raw.png")
        let buildingURL = probeRoot.appendingPathComponent(
            "pre-chroma-registered-building.png"
        )
        let alphaURL = probeRoot.appendingPathComponent(
            "pre-chroma-registered-alpha.png"
        )
        let neutralURL = probeRoot.appendingPathComponent(
            "neutral-alpha-composite.png"
        )
        let provenanceURL = probeRoot.appendingPathComponent(
            "provenance.json"
        )
        let raw = try v03ReviewLoadImage(rawURL)
        let building = try v03ReviewLoadImage(buildingURL)
        let alpha = try v03ReviewLoadImage(alphaURL)
        let neutral = try v03ReviewLoadImage(neutralURL)
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
            throw IndustrialL2EastV03ReviewError.invalid(
                "probe image dimensions drift"
            )
        }
        guard
            let provenance = try JSONSerialization.jsonObject(
                with: Data(contentsOf: provenanceURL)
            ) as? [String: Any],
            provenance["approvedPrepixelCommit"] as? String
                == v03ReviewCommit,
            provenance["freshMetalProcessCount"] as? Int == 1,
            provenance["sceneDescriptorSHA256"] as? String
                == v03ReviewDescriptorSHA256,
            provenance["materialLibrarySHA256"] as? String
                == v03ReviewMaterialSHA256,
            provenance["productionSelected"] as? Bool == false
        else {
            throw IndustrialL2EastV03ReviewError.invalid(
                "probe provenance authority drift"
            )
        }

        let exactChroma: (Int) -> Bool = {
            raw.rgba[$0] == 255
                && raw.rgba[$0 + 1] == 0
                && raw.rgba[$0 + 2] == 255
        }
        let rawRGBBounds = v03ReviewBounds(
            width: raw.width,
            height: raw.height
        ) { !exactChroma($0) }
        let buildingBounds = v03ReviewBounds(
            width: building.width,
            height: building.height
        ) { building.rgba[$0 + 3] > 8 }
        let alphaBounds = v03ReviewBounds(
            width: alpha.width,
            height: alpha.height
        ) { alpha.rgba[$0 + 3] > 8 }

        var hiddenRGB = 0
        var exactChromaCount = 0
        var nearMagentaOpaque = 0
        var proofMagenta = 0
        var luma: [Int] = []
        var bins: [Int: Int] = [:]
        for offset in stride(from: 0, to: raw.rgba.count, by: 4) {
            if exactChroma(offset) {
                exactChromaCount += 1
            } else if
                raw.rgba[offset] >= 224,
                raw.rgba[offset + 1] <= 32,
                raw.rgba[offset + 2] >= 224,
                raw.rgba[offset + 3] > 0
            {
                nearMagentaOpaque += 1
            }
            if
                building.rgba[offset + 3] == 0,
                building.rgba[offset] != 0
                    || building.rgba[offset + 1] != 0
                    || building.rgba[offset + 2] != 0
            {
                hiddenRGB += 1
            }
            if
                alpha.rgba[offset + 3] > 0,
                alpha.rgba[offset] >= 224,
                alpha.rgba[offset + 1] <= 32,
                alpha.rgba[offset + 2] >= 224
            {
                proofMagenta += 1
            }
            if building.rgba[offset + 3] > 128 {
                let value = v03ReviewLuma(
                    red: raw.rgba[offset],
                    green: raw.rgba[offset + 1],
                    blue: raw.rgba[offset + 2]
                )
                luma.append(value)
                bins[min(240, (value / 32) * 32 + 16), default: 0]
                    += 1
            }
        }
        guard !luma.isEmpty else {
            throw IndustrialL2EastV03ReviewError.invalid(
                "building alpha selected no governed pixels"
            )
        }
        let p25 = v03ReviewPercentile(luma, 0.25)
        let p75 = v03ReviewPercentile(luma, 0.75)
        let p95 = v03ReviewPercentile(luma, 0.95)
        let maximumBinShare =
            Double(bins.values.max() ?? 0) / Double(luma.count)

        guard let blocks = descriptor.building.massBlocks else {
            throw IndustrialL2EastV03ReviewError.invalid(
                "explicit component geometry missing"
            )
        }
        let blockByID = Dictionary(
            uniqueKeysWithValues: blocks.map { ($0.id, $0) }
        )
        let featureIDs = [
            "v02-dock-door-a",
            "v02-dock-door-b",
            "v02-dock-door-c",
            "v02-dock-canopy-a",
            "v02-dock-canopy-b",
            "v02-dock-canopy-c",
            "v02-personnel-door",
        ]
        var featureRecords: [[String: Any]] = []
        var minimumFeature = Double.greatestFiniteMagnitude
        for id in featureIDs {
            guard let component = blockByID[id] else {
                throw IndustrialL2EastV03ReviewError.invalid(
                    "missing feature \(id)"
                )
            }
            let projected = v03ReviewProjectedBounds(
                component,
                descriptor: descriptor
            )
            let x0 = max(0, Int(floor(projected.minX)))
            let y0 = max(0, Int(floor(projected.minY)))
            let x1 = min(raw.width - 1, Int(ceil(projected.maxX)))
            let y1 = min(raw.height - 1, Int(ceil(projected.maxY)))
            let occupied = v03ReviewBounds(
                width: raw.width,
                height: raw.height
            ) { offset in
                let pixel = offset / 4
                let x = pixel % raw.width
                let y = pixel / raw.width
                return x >= x0 && x <= x1
                    && y >= y0 && y <= y1
                    && building.rgba[offset + 3] > 8
            }
            let widthNative = Double(occupied.width) * v03Native2xScale
            let heightNative =
                Double(occupied.height) * v03Native2xScale
            let maximumSpan = max(widthNative, heightNative)
            minimumFeature = min(minimumFeature, maximumSpan)
            featureRecords.append([
                "id": id,
                "projectedSourceBounds": [
                    projected.minX,
                    projected.minY,
                    projected.maxX,
                    projected.maxY,
                ],
                "alphaOccupiedBounds": occupied.record,
                "measuredNative2xWidthPixels": widthNative,
                "measuredNative2xHeightPixels": heightNative,
                "measuredNative2xMaximumSpanPixels": maximumSpan,
                "passedSixPixelMinimum": maximumSpan >= 6,
            ])
        }
        let coreIDs = [
            "v02-main-production-hall",
            "v02-loading-spine",
            "v02-administration-wing",
        ]
        let coreRect = v03ReviewUnion(
            try coreIDs.map { id in
                guard let block = blockByID[id] else {
                    throw IndustrialL2EastV03ReviewError.invalid(
                        "missing core component \(id)"
                    )
                }
                return v03ReviewProjectedBounds(
                    block,
                    descriptor: descriptor
                )
            }
        )
        let coreX0 = max(0, Int(floor(coreRect.minX)))
        let coreY0 = max(0, Int(floor(coreRect.minY)))
        let coreX1 = min(raw.width - 1, Int(ceil(coreRect.maxX)))
        let coreY1 = min(raw.height - 1, Int(ceil(coreRect.maxY)))
        let coreBounds = v03ReviewBounds(
            width: raw.width,
            height: raw.height
        ) { offset in
            let pixel = offset / 4
            let x = pixel % raw.width
            let y = pixel / raw.width
            return x >= coreX0 && x <= coreX1
                && y >= coreY0 && y <= coreY1
                && building.rgba[offset + 3] > 8
        }

        let registrationPassed =
            descriptor.registration.footprintPolygonSource
                == [[768, 640], [1024, 768], [768, 896], [512, 768]]
            && descriptor.registration.groundPivotSource == [768, 896]
            && descriptor.registration.frontageSocketSource == [896, 832]
            && descriptor.registration.doorBaseSource
                == [[934, 813], [858, 851]]
            && descriptor.registration.contactPolygonWorld
                == [[-28, -28], [28, -28], [28, 28], [-28, 28]]
            && descriptor.light.shadowVectorSource == [2, 1]
        let technicalPassed =
            rawRGBBounds.width > 0
            && buildingBounds.width >= 420
            && Double(buildingBounds.width) * v03Native2xScale >= 118
            && coreBounds.width >= 420
            && hiddenRGB == 0
            && proofMagenta == 0
            && nearMagentaOpaque == 0
            && p25 >= 80
            && p75 - p25 >= 48
            && p95 >= 192
            && bins.count >= 5
            && maximumBinShare <= 0.35
            && minimumFeature >= 6
            && registrationPassed

        try FileManager.default.createDirectory(
            at: outputRoot,
            withIntermediateDirectories: true
        )
        let nativeWidth = Int(
            (Double(neutral.width) * v03Native2xScale).rounded()
        )
        let nativeHeight = Int(
            (Double(neutral.height) * v03Native2xScale).rounded()
        )
        let nativeColor = try v03ReviewResize(
            neutral.image,
            width: nativeWidth,
            height: nativeHeight
        )
        let nativeGray = try v03ReviewGrayscale(nativeColor)
        let sourceGray = try v03ReviewGrayscale(neutral.image)
        let sourceSheet = try v03ReviewContactSheet(
            images: [neutral.image, sourceGray],
            columns: 2
        )
        let rawAndNeutral = try v03ReviewContactSheet(
            images: [raw.image, neutral.image],
            columns: 2
        )
        let footprintCrop = try v03ReviewCrop(
            neutral.image,
            x: 384,
            y: 320,
            width: 768,
            height: 640
        )
        let footprintNative = try v03ReviewResize(
            footprintCrop,
            width: 216,
            height: 180
        )
        let footprintGray = try v03ReviewGrayscale(footprintNative)
        let zoomX = max(0, buildingBounds.minimumX - 24)
        let zoomY = max(0, buildingBounds.minimumY - 24)
        let zoomCrop = try v03ReviewCrop(
            neutral.image,
            x: zoomX,
            y: zoomY,
            width: min(
                neutral.width - zoomX,
                buildingBounds.width + 48
            ),
            height: min(
                neutral.height - zoomY,
                buildingBounds.height + 48
            )
        )
        let zoomColor = try v03ReviewResize(
            zoomCrop,
            width: zoomCrop.width * 2,
            height: zoomCrop.height * 2
        )
        let zoomGray = try v03ReviewGrayscale(zoomColor)
        let zoomSheet = try v03ReviewContactSheet(
            images: [zoomColor, zoomGray],
            columns: 2
        )
        let panels: [(String, CGImage)] = [
            ("SOURCE-SCALE-RAW-AND-NEUTRAL.png", rawAndNeutral),
            ("SOURCE-SCALE-COLOR-AND-GRAYSCALE.png", sourceSheet),
            ("NEUTRAL-NATIVE-2X-COLOR.png", nativeColor),
            ("NEUTRAL-NATIVE-2X-GRAYSCALE.png", nativeGray),
            ("FOOTPRINT-NATIVE-2X-COLOR.png", footprintNative),
            ("FOOTPRINT-NATIVE-2X-GRAYSCALE.png", footprintGray),
            ("ZOOM-COLOR-AND-GRAYSCALE.png", zoomSheet),
        ]
        for (name, image) in panels {
            try v03ReviewWritePNG(
                image,
                to: outputRoot.appendingPathComponent(name)
            )
        }
        let panelRecords = try panels.map { name, image in
            let url = outputRoot.appendingPathComponent(name)
            return [
                "file": String(
                    url.path.dropFirst(root.path.count + 1)
                ),
                "fileSHA256": try v03ReviewSHA256(url),
                "pixels": [image.width, image.height],
            ] as [String: Any]
        }
        let metrics: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v03-single-primary-raw-review",
            "disposition":
                technicalPassed
                ? "PENDING_INDEPENDENT_REVIEW"
                : "REJECTED_RAW_TECHNICAL_GATE",
            "sourceAuthorityAccepted": false,
            "probe": [
                "approvedCommit": v03ReviewCommit,
                "rawFileSHA256": try v03ReviewSHA256(rawURL),
                "rawDecodedRGBASHA256":
                    v03ReviewSHA256(Data(raw.rgba)),
                "provenanceFileSHA256":
                    try v03ReviewSHA256(provenanceURL),
                "descriptorSHA256":
                    try v03ReviewSHA256(descriptorURL),
                "materialLibrarySHA256":
                    try v03ReviewSHA256(materialsURL),
                "prepixelValidationSHA256":
                    try v03ReviewSHA256(validationURL),
                "preservedV02RejectionSHA256":
                    try v03ReviewSHA256(v02RejectionURL),
            ],
            "alphaAndChroma": [
                "rawRGBOccupiedBounds": rawRGBBounds.record,
                "preChromaBuildingAlphaBounds": buildingBounds.record,
                "preChromaBuildingAndShadowAlphaBounds":
                    alphaBounds.record,
                "alphaVisibleToRGBWidthRatio":
                    Double(alphaBounds.width)
                    / Double(rawRGBBounds.width),
                "hiddenRGBPixelCount": hiddenRGB,
                "hiddenRGBRatio":
                    Double(hiddenRGB)
                    / Double(building.width * building.height),
                "exactChromaPixelCount": exactChromaCount,
                "nearMagentaOpaquePixelCount": nearMagentaOpaque,
                "proofMagentaFamilyPixelCount": proofMagenta,
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
                "passed": registrationPassed,
            ],
            "spans": [
                "buildingOnlyBounds": buildingBounds.record,
                "buildingOnlySourceWidth": buildingBounds.width,
                "buildingOnlyNative2xWidth":
                    Double(buildingBounds.width) * v03Native2xScale,
                "coreFormBounds": coreBounds.record,
                "coreFormSourceWidth": coreBounds.width,
                "coreFormNative2xWidth":
                    Double(coreBounds.width) * v03Native2xScale,
            ],
            "features": [
                "measuredMinimumNative2xPixels": minimumFeature,
                "records": featureRecords,
            ],
            "luma": [
                "buildingOpaquePixelCount": luma.count,
                "p25": p25,
                "p75": p75,
                "p75MinusP25": p75 - p25,
                "p95": p95,
                "occupiedStep32Bins": bins.keys.sorted(),
                "step32BinCounts": Dictionary(
                    uniqueKeysWithValues: bins.map {
                        (String($0.key), $0.value)
                    }
                ),
                "maximumMajorFacadeBinShareProxy":
                    maximumBinShare,
                "proxyDefinition":
                    "maximum occupied step-32 luma-bin share over building-alpha pixels",
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
        try v03ReviewWriteJSON(
            metrics,
            to: outputRoot.appendingPathComponent(
                "RAW-PROBE-METRICS.json"
            )
        )
        try v03ReviewWriteJSON(
            [
                "schema": 1,
                "task": "PLAY-027",
                "attempt": "industrial-l02-east-v03-primary",
                "rawAttemptCount": 1,
                "repeatAttempts": 0,
                "otherDirections": 0,
                "normalizationRuns": 0,
                "disposition":
                    technicalPassed
                    ? "PENDING_INDEPENDENT_REVIEW"
                    : "REJECTED_RAW_TECHNICAL_GATE",
                "productionSelected": false,
            ] as [String: Any],
            to: outputRoot.appendingPathComponent("INVENTORY.json")
        )
        print(
            "raw review \(technicalPassed ? "PASS" : "FAIL") "
                + "p25=\(p25) iqr=\(p75 - p25) p95=\(p95) "
                + "bins=\(bins.count) maxShare=\(maximumBinShare)"
        )
        print(
            "building=\(buildingBounds.width) "
                + "core=\(coreBounds.width) "
                + "featureMin=\(minimumFeature)"
        )
        print(
            technicalPassed
            ? "PENDING_INDEPENDENT_REVIEW"
            : "REJECTED_RAW_TECHNICAL_GATE"
        )
    }
}
