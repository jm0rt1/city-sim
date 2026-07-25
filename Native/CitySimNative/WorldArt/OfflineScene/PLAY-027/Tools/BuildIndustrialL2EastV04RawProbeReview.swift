import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import SceneKit
import UniformTypeIdentifiers

enum IndustrialL2EastV04ReviewError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l2-east-v04-raw-probe-review --repository-root <path> --probe-root <path> --output-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct V04ReviewImage {
    let image: CGImage
    let rgba: [UInt8]
    let width: Int
    let height: Int
}

private struct V04PixelBounds {
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

private let v04ReviewCommit =
    "f35bddcdab0b0ac6c4ed0fd6635c840ae7c4cc5b"
private let v04ReviewDescriptorSHA256 =
    "fdb92d39acb8847178a95d1e0f6315332a93eda01df71388e54582fe1e6f12bf"
private let v04ReviewMaterialSHA256 =
    "31f500488b7d143e88015bf71b53db4d1a4b19076563dc3d774d61f00c8b83a3"
private let v04ReviewGeometrySHA256 =
    "478254a6228ae5bcc4d81ae87ec1f43bfc433b606f95b87a440ca3d41cdf34a3"
private let v04ReviewAlphaContractSHA256 =
    "351aed1910d7b680991815a479897fb4849060dd19798d662fe8c03f494f64e9"
private let v04ReviewValidationReplaySHA256 =
    "09c659428e3cb5a24b2cb3f83d996f3509d77897f0dc51f15b06af0eda7c608a"
private let v04ReviewV03RawSHA256 =
    "24e57812ef0d0d024aef8b4d45a2bda9f98c902874b534aed9ff6040707867ba"
private let v04ReviewV03RejectionSHA256 =
    "3ccefb83cded63bf0958c4b28eabf00af8ccf4551dd4191d3675c4641110a877"
private let v04ReviewV03MetricsSHA256 =
    "cd55e28517b2e2ca5896d433f5a0646840786b8684a45c2f3ef0bd931f69c1c9"
private let v04ReviewProbeSuffix =
    "/docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/raw-probe/diagnostics/east-primary"
private let v04ReviewOutputSuffix =
    "/docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/raw-probe/review"
private let v04Native2xScale = 144.0 / 512.0

private func v04ReviewArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2EastV04ReviewError.arguments
    }
    return arguments[index + 1]
}

private func v04ReviewSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func v04ReviewSHA256(_ url: URL) throws -> String {
    v04ReviewSHA256(try Data(contentsOf: url))
}

private func v04ReviewLoadImage(
    _ url: URL
) throws -> V04ReviewImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw IndustrialL2EastV04ReviewError.invalid(
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
        throw IndustrialL2EastV04ReviewError.invalid(
            "could not decode canonical RGBA \(url.path)"
        )
    }
    return V04ReviewImage(
        image: image,
        rgba: rgba,
        width: width,
        height: height
    )
}

private func v04ReviewBounds(
    width: Int,
    height: Int,
    predicate: (Int) -> Bool
) -> V04PixelBounds {
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
    return V04PixelBounds(
        minimumX: minX,
        minimumY: minY,
        maximumX: maxX,
        maximumY: maxY,
        count: count
    )
}

private func v04ReviewPercentile(
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

private func v04ReviewLuma(
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

private func v04ReviewRGBAContext(
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
        throw IndustrialL2EastV04ReviewError.invalid(
            "could not allocate review context"
        )
    }
    return context
}

private func v04ReviewResize(
    _ image: CGImage,
    width: Int,
    height: Int
) throws -> CGImage {
    let context = try v04ReviewRGBAContext(
        width: width,
        height: height
    )
    context.interpolationQuality = .high
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: width, height: height)
    )
    guard let output = context.makeImage() else {
        throw IndustrialL2EastV04ReviewError.invalid(
            "could not create resized image"
        )
    }
    return output
}

private func v04ReviewGrayscale(
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
        throw IndustrialL2EastV04ReviewError.invalid(
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
        throw IndustrialL2EastV04ReviewError.invalid(
            "could not create grayscale image"
        )
    }
    return output
}

private func v04ReviewCrop(
    _ image: CGImage,
    x: Int,
    y: Int,
    width: Int,
    height: Int
) throws -> CGImage {
    guard let output = image.cropping(
        to: CGRect(x: x, y: y, width: width, height: height)
    ) else {
        throw IndustrialL2EastV04ReviewError.invalid(
            "could not crop review image"
        )
    }
    return output
}

private func v04ReviewContactSheet(
    images: [CGImage],
    columns: Int
) throws -> CGImage {
    guard let first = images.first else {
        throw IndustrialL2EastV04ReviewError.invalid(
            "empty contact sheet"
        )
    }
    let gap = 16
    let rows = Int(ceil(Double(images.count) / Double(columns)))
    let width = columns * first.width + (columns + 1) * gap
    let height = rows * first.height + (rows + 1) * gap
    let context = try v04ReviewRGBAContext(
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
        throw IndustrialL2EastV04ReviewError.invalid(
            "could not create contact sheet"
        )
    }
    return output
}

private func v04ReviewWritePNG(
    _ image: CGImage,
    to url: URL
) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw IndustrialL2EastV04ReviewError.invalid(
            "could not create PNG destination"
        )
    }
    CGImageDestinationAddImage(
        destination,
        image,
        [kCGImagePropertyHasAlpha: true] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL2EastV04ReviewError.invalid(
            "could not finalize \(url.path)"
        )
    }
}

private func v04ReviewWriteJSON(
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

private func v04ReviewProjectedBounds(
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

private func v04ReviewUnion(_ rects: [CGRect]) -> CGRect {
    rects.dropFirst().reduce(rects[0]) { $0.union($1) }
}

@main
enum BuildIndustrialL2EastV04RawProbeReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try v04ReviewArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let probeRoot = URL(
            fileURLWithPath: try v04ReviewArgument(
                "--probe-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try v04ReviewArgument(
                "--output-root",
                in: arguments
            )
        ).standardizedFileURL
        guard
            probeRoot.path == root.path + v04ReviewProbeSuffix,
            outputRoot.path == root.path + v04ReviewOutputSuffix,
            !FileManager.default.fileExists(atPath: outputRoot.path)
        else {
            throw IndustrialL2EastV04ReviewError.invalid(
                "v04 review input/output or one-run boundary failed"
            )
        }
        let descriptorURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v04/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialsURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v04/materials/industrial-l02-projection-silhouette-reset-v04.json"
        )
        let alphaContractURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/prepixel/V04-ALPHA-COMPOSITOR-CONTRACT.json"
        )
        let validationReplayURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/prepixel/VALIDATOR-REPLAY.json"
        )
        let v03RawURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/diagnostics/east-primary/raw.png"
        )
        let v03RejectionURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/rejection/REJECTION.md"
        )
        let v03MetricsURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/review/RAW-PROBE-METRICS.json"
        )
        guard
            try v04ReviewSHA256(descriptorURL)
                == v04ReviewDescriptorSHA256,
            try v04ReviewSHA256(materialsURL)
                == v04ReviewMaterialSHA256,
            try v04ReviewSHA256(alphaContractURL)
                == v04ReviewAlphaContractSHA256,
            try v04ReviewSHA256(validationReplayURL)
                == v04ReviewValidationReplaySHA256,
            try v04ReviewSHA256(v03RawURL)
                == v04ReviewV03RawSHA256,
            try v04ReviewSHA256(v03RejectionURL)
                == v04ReviewV03RejectionSHA256,
            try v04ReviewSHA256(v03MetricsURL)
                == v04ReviewV03MetricsSHA256
        else {
            throw IndustrialL2EastV04ReviewError.invalid(
                "v04 authority or preserved v03 rejection drift"
            )
        }
        guard
            let replay = try JSONSerialization.jsonObject(
                with: Data(contentsOf: validationReplayURL)
            ) as? [String: Any],
            let geometry = replay["geometry"] as? [String: Any],
            geometry["v04CanonicalSHA256"] as? String
                == v04ReviewGeometrySHA256,
            replay["passed"] as? Bool == true,
            replay["productionSelected"] as? Bool == false
        else {
            throw IndustrialL2EastV04ReviewError.invalid(
                "v04 geometry or validator replay drift"
            )
        }
        let descriptor = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: Data(contentsOf: descriptorURL)
        )
        guard
            descriptor.sourceRevision
                == "projection-silhouette-reset-art-proof-v04",
            descriptor.sceneGeometryID
                == "industrial-l02-east-wide-low-campus-geometry-v03",
            !descriptor.productionSelected
        else {
            throw IndustrialL2EastV04ReviewError.invalid(
                "v04 descriptor identity drift"
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
        let raw = try v04ReviewLoadImage(rawURL)
        let building = try v04ReviewLoadImage(buildingURL)
        let alpha = try v04ReviewLoadImage(alphaURL)
        let neutral = try v04ReviewLoadImage(neutralURL)
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
            throw IndustrialL2EastV04ReviewError.invalid(
                "probe image dimensions drift"
            )
        }
        guard
            let provenance = try JSONSerialization.jsonObject(
                with: Data(contentsOf: provenanceURL)
            ) as? [String: Any],
            provenance["approvedPrepixelCommit"] as? String
                == v04ReviewCommit,
            provenance["freshMetalProcessCount"] as? Int == 1,
            provenance["sceneDescriptorSHA256"] as? String
                == v04ReviewDescriptorSHA256,
            provenance["materialLibrarySHA256"] as? String
                == v04ReviewMaterialSHA256,
            provenance["canonicalGeometrySHA256"] as? String
                == v04ReviewGeometrySHA256,
            provenance["alphaCompositorContractSHA256"] as? String
                == v04ReviewAlphaContractSHA256,
            provenance["validatorReplaySHA256"] as? String
                == v04ReviewValidationReplaySHA256,
            provenance["productionSelected"] as? Bool == false
        else {
            throw IndustrialL2EastV04ReviewError.invalid(
                "probe provenance authority drift"
            )
        }

        let exactChroma: (Int) -> Bool = {
            raw.rgba[$0] == 255
                && raw.rgba[$0 + 1] == 0
                && raw.rgba[$0 + 2] == 255
                && raw.rgba[$0 + 3] == 255
        }
        let rawRGBBounds = v04ReviewBounds(
            width: raw.width,
            height: raw.height
        ) { !exactChroma($0) }
        let buildingBounds = v04ReviewBounds(
            width: building.width,
            height: building.height
        ) { building.rgba[$0 + 3] > 8 }
        let alphaBounds = v04ReviewBounds(
            width: alpha.width,
            height: alpha.height
        ) { alpha.rgba[$0 + 3] > 8 }

        var hiddenRGB = 0
        var exactChromaCount = 0
        var nearMagentaOpaque = 0
        var proofMagenta = 0
        var alphaContractMismatch = 0
        var rawForegroundPixelCount = 0
        var luma: [Int] = []
        var bins: [Int: Int] = [:]
        for offset in stride(from: 0, to: raw.rgba.count, by: 4) {
            if exactChroma(offset) {
                exactChromaCount += 1
            } else if
                raw.rgba[offset] >= 224,
                raw.rgba[offset + 1] <= 32,
                raw.rgba[offset + 2] >= 224,
                raw.rgba[offset + 3] == 255
            {
                nearMagentaOpaque += 1
            }
            if alpha.rgba[offset + 3] == 0 {
                if !exactChroma(offset) {
                    alphaContractMismatch += 1
                }
            } else {
                rawForegroundPixelCount += 1
                if raw.rgba[offset + 3] != alpha.rgba[offset + 3] {
                    alphaContractMismatch += 1
                }
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
            if
                building.rgba[offset + 3] > 128,
                raw.rgba[offset + 3] == 255
            {
                let value = v04ReviewLuma(
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
            throw IndustrialL2EastV04ReviewError.invalid(
                "building alpha selected no governed pixels"
            )
        }
        let p25 = v04ReviewPercentile(luma, 0.25)
        let p75 = v04ReviewPercentile(luma, 0.75)
        let p95 = v04ReviewPercentile(luma, 0.95)
        let maximumBinShare =
            Double(bins.values.max() ?? 0) / Double(luma.count)

        guard let blocks = descriptor.building.massBlocks else {
            throw IndustrialL2EastV04ReviewError.invalid(
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
                throw IndustrialL2EastV04ReviewError.invalid(
                    "missing feature \(id)"
                )
            }
            let projected = v04ReviewProjectedBounds(
                component,
                descriptor: descriptor
            )
            let x0 = max(0, Int(floor(projected.minX)))
            let y0 = max(0, Int(floor(projected.minY)))
            let x1 = min(raw.width - 1, Int(ceil(projected.maxX)))
            let y1 = min(raw.height - 1, Int(ceil(projected.maxY)))
            let occupied = v04ReviewBounds(
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
            let widthNative = Double(occupied.width) * v04Native2xScale
            let heightNative =
                Double(occupied.height) * v04Native2xScale
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
        let coreRect = v04ReviewUnion(
            try coreIDs.map { id in
                guard let block = blockByID[id] else {
                    throw IndustrialL2EastV04ReviewError.invalid(
                        "missing core component \(id)"
                    )
                }
                return v04ReviewProjectedBounds(
                    block,
                    descriptor: descriptor
                )
            }
        )
        let coreX0 = max(0, Int(floor(coreRect.minX)))
        let coreY0 = max(0, Int(floor(coreRect.minY)))
        let coreX1 = min(raw.width - 1, Int(ceil(coreRect.maxX)))
        let coreY1 = min(raw.height - 1, Int(ceil(coreRect.maxY)))
        let coreBounds = v04ReviewBounds(
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

        let identityComponents: [(String, String)] = [
            ("v02-main-production-hall", "production-hall"),
            ("v02-loading-spine", "formed-concrete"),
            ("v02-administration-wing", "administration"),
            ("v02-process-base", "secondary-process"),
            ("v02-dock-throat-a", "recess"),
            ("v02-dock-throat-b", "recess"),
            ("v02-dock-throat-c", "recess"),
            ("v02-dock-door-a", "load-bay"),
            ("v02-dock-door-b", "load-bay"),
            ("v02-dock-door-c", "load-bay"),
            ("v02-loading-apron", "apron"),
            ("v02-admin-glazing", "glazing"),
            ("v02-hazard-header", "safety"),
        ]
        var identityValueRecords: [[String: Any]] = []
        var identityMinimumBin = 256
        var maximumMajorFacadeBinShare = 0.0
        for (id, role) in identityComponents {
            guard let component = blockByID[id] else {
                throw IndustrialL2EastV04ReviewError.invalid(
                    "missing identity component \(id)"
                )
            }
            let projected = v04ReviewProjectedBounds(
                component,
                descriptor: descriptor
            )
            let x0 = max(0, Int(ceil(projected.minX + 2)))
            let y0 = max(0, Int(ceil(projected.minY + 2)))
            let x1 = min(
                raw.width - 1,
                Int(floor(projected.maxX - 2))
            )
            let y1 = min(
                raw.height - 1,
                Int(floor(projected.maxY - 2))
            )
            var componentLuma: [Int] = []
            var componentBins: [Int: Int] = [:]
            if x0 <= x1, y0 <= y1 {
                for y in y0...y1 {
                    for x in x0...x1 {
                        let offset = (y * raw.width + x) * 4
                        guard
                            building.rgba[offset + 3] == 255,
                            raw.rgba[offset + 3] == 255,
                            !exactChroma(offset)
                        else {
                            continue
                        }
                        let value = v04ReviewLuma(
                            red: raw.rgba[offset],
                            green: raw.rgba[offset + 1],
                            blue: raw.rgba[offset + 2]
                        )
                        componentLuma.append(value)
                        componentBins[
                            min(240, (value / 32) * 32 + 16),
                            default: 0
                        ] += 1
                    }
                }
            }
            guard !componentLuma.isEmpty else {
                throw IndustrialL2EastV04ReviewError.invalid(
                    "identity component \(id) selected no opaque pixels"
                )
            }
            let componentP25 =
                v04ReviewPercentile(componentLuma, 0.25)
            let componentMinimumBin =
                min(240, (componentP25 / 32) * 32 + 16)
            let componentMaximumShare =
                Double(componentBins.values.max() ?? 0)
                / Double(componentLuma.count)
            identityMinimumBin = min(
                identityMinimumBin,
                componentMinimumBin
            )
            identityValueRecords.append([
                "id": id,
                "role": role,
                "opaqueInteriorPixelCount": componentLuma.count,
                "p25": componentP25,
                "p25Step32Bin": componentMinimumBin,
                "occupiedStep32Bins":
                    componentBins.keys.sorted(),
                "maximumBinShare": componentMaximumShare,
            ])
        }
        maximumMajorFacadeBinShare = maximumBinShare

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
            && rawRGBBounds.minimumX == alphaBounds.minimumX
            && rawRGBBounds.minimumY == alphaBounds.minimumY
            && rawRGBBounds.maximumX == alphaBounds.maximumX
            && rawRGBBounds.maximumY == alphaBounds.maximumY
            && buildingBounds.width == 514
            && Double(buildingBounds.width) * v04Native2xScale
                == 144.5625
            && coreBounds.width == 422
            && Double(coreBounds.width) * v04Native2xScale
                == 118.6875
            && hiddenRGB == 0
            && proofMagenta == 0
            && nearMagentaOpaque == 0
            && alphaContractMismatch == 0
            && p25 >= 80
            && p75 - p25 > 48
            && p95 >= 192
            && bins.count > 5
            && maximumMajorFacadeBinShare < 0.35
            && identityMinimumBin >= 80
            && minimumFeature >= 17.15625
            && registrationPassed

        try FileManager.default.createDirectory(
            at: outputRoot,
            withIntermediateDirectories: true
        )
        let nativeWidth = Int(
            (Double(neutral.width) * v04Native2xScale).rounded()
        )
        let nativeHeight = Int(
            (Double(neutral.height) * v04Native2xScale).rounded()
        )
        let nativeColor = try v04ReviewResize(
            neutral.image,
            width: nativeWidth,
            height: nativeHeight
        )
        let nativeGray = try v04ReviewGrayscale(nativeColor)
        let sourceGray = try v04ReviewGrayscale(neutral.image)
        let sourceSheet = try v04ReviewContactSheet(
            images: [neutral.image, sourceGray],
            columns: 2
        )
        let rawAndNeutral = try v04ReviewContactSheet(
            images: [raw.image, neutral.image],
            columns: 2
        )
        let footprintCrop = try v04ReviewCrop(
            neutral.image,
            x: 384,
            y: 320,
            width: 768,
            height: 640
        )
        let footprintNative = try v04ReviewResize(
            footprintCrop,
            width: 216,
            height: 180
        )
        let footprintGray = try v04ReviewGrayscale(footprintNative)
        let zoomX = max(0, buildingBounds.minimumX - 24)
        let zoomY = max(0, buildingBounds.minimumY - 24)
        let zoomCrop = try v04ReviewCrop(
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
        let zoomColor = try v04ReviewResize(
            zoomCrop,
            width: zoomCrop.width * 2,
            height: zoomCrop.height * 2
        )
        let zoomGray = try v04ReviewGrayscale(zoomColor)
        let zoomSheet = try v04ReviewContactSheet(
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
            try v04ReviewWritePNG(
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
                "fileSHA256": try v04ReviewSHA256(url),
                "pixels": [image.width, image.height],
            ] as [String: Any]
        }
        let metrics: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v04-single-primary-raw-review",
            "disposition":
                technicalPassed
                ? "PENDING_INDEPENDENT_REVIEW"
                : "REJECTED_RAW_TECHNICAL_GATE",
            "sourceAuthorityAccepted": false,
            "probe": [
                "approvedCommit": v04ReviewCommit,
                "rawFileSHA256": try v04ReviewSHA256(rawURL),
                "rawDecodedRGBASHA256":
                    v04ReviewSHA256(Data(raw.rgba)),
                "provenanceFileSHA256":
                    try v04ReviewSHA256(provenanceURL),
                "descriptorSHA256":
                    try v04ReviewSHA256(descriptorURL),
                "materialLibrarySHA256":
                    try v04ReviewSHA256(materialsURL),
                "canonicalGeometrySHA256":
                    v04ReviewGeometrySHA256,
                "alphaCompositorContractSHA256":
                    try v04ReviewSHA256(alphaContractURL),
                "validatorReplaySHA256":
                    try v04ReviewSHA256(validationReplayURL),
                "preservedV03RawSHA256":
                    try v04ReviewSHA256(v03RawURL),
                "preservedV03RejectionSHA256":
                    try v04ReviewSHA256(v03RejectionURL),
                "preservedV03MetricsSHA256":
                    try v04ReviewSHA256(v03MetricsURL),
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
                "rawForegroundPixelCount":
                    rawForegroundPixelCount,
                "nearMagentaOpaquePixelCount": nearMagentaOpaque,
                "proofMagentaFamilyPixelCount": proofMagenta,
                "alphaContractMismatchPixelCount":
                    alphaContractMismatch,
                "alphaVisibleBoundsEqualRGBBounds":
                    rawRGBBounds.minimumX == alphaBounds.minimumX
                    && rawRGBBounds.minimumY == alphaBounds.minimumY
                    && rawRGBBounds.maximumX == alphaBounds.maximumX
                    && rawRGBBounds.maximumY == alphaBounds.maximumY,
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
                    Double(buildingBounds.width) * v04Native2xScale,
                "coreFormBounds": coreBounds.record,
                "coreFormSourceWidth": coreBounds.width,
                "coreFormNative2xWidth":
                    Double(coreBounds.width) * v04Native2xScale,
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
                "maximumMajorFacadeBinShare":
                    maximumMajorFacadeBinShare,
                "maximumMajorFacadeBinShareDefinition":
                    "maximum occupied step-32 luma-bin share over opaque building material pixels",
                "identityBearingMinimumBin":
                    identityMinimumBin,
                "identityComponentValues":
                    identityValueRecords,
                "targets": [
                    "p25Minimum": 80,
                    "p75MinusP25StrictlyGreaterThan": 48,
                    "p95Minimum": 192,
                    "occupiedStep32BinsStrictlyGreaterThan": 5,
                    "maximumMajorFacadeBinShareStrictlyLessThan":
                        0.35,
                    "identityBearingMinimumBin": 80,
                ],
            ],
            "panels": panelRecords,
            "technicalPassed": technicalPassed,
            "visualDisposition": "PENDING_INDEPENDENT_REVIEW",
            "freshMetalProcessCount": 1,
            "normalizationRunCount": 0,
            "productionSelected": false,
        ]
        try v04ReviewWriteJSON(
            metrics,
            to: outputRoot.appendingPathComponent(
                "RAW-PROBE-METRICS.json"
            )
        )
        try v04ReviewWriteJSON(
            [
                "schema": 1,
                "task": "PLAY-027",
                "attempt": "industrial-l02-east-v04-primary",
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
