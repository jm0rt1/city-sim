import AppKit
import CoreGraphics
import CoreImage
import CryptoKit
import Foundation
import ImageIO
import SceneKit
import UniformTypeIdentifiers

private enum SemanticToolError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l4-v17-semantic-visibility-v1 --repository-root <path> --output-directory <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct ScaleMetric {
    let visiblePixels: Int
    let bounds: [Int]
    let width: Int
    let height: Int
    let connectedComponents: Int
}

private struct ComponentEvidence {
    let component: PLAY027SemanticComponent
    let isolatedSourceMask: [UInt8]
    let visibleSourceMask: [UInt8]
    let source: ScaleMetric
    let native2x: ScaleMetric
    let literal192: ScaleMetric
    let isolatedPixels: Int
    let occludedPixels: Int
    let occlusionByOwner: [String: Int]
    let medianLuma: Int?
}

private let descriptorRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v17-north-prepixel/artifact/"
    + "scenes/industrial_l04/variant-0/n/scene.json"
private let materialRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v17-north-prepixel/materials/"
    + "industrial-l04-crucible-gantry-v14-north-prepixel.json"
private let canonicalRelativePath =
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    + "matte-canonicalization-v2-v01/V17-CANONICAL-TRANSPARENT.png"
private let toolRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
    + "BuildIndustrialL4V17SemanticVisibilityV1.swift"
private let semanticSourceRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/"
    + "SemanticVisibilityV1.swift"
private let rendererSourceRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/"
    + "OfflineSceneRenderer.swift"

private let expectedDescriptorSHA =
    "6cb190ea388746c620945ff401a03817df0ff1f92797a18fff8e86b00b0cd94a"
private let expectedMaterialSHA =
    "147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202"
private let expectedCanonicalFileSHA =
    "39bcb896664ef436853790e2acd87bb0d450b8401bb5318708757aef331a2385"

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        index + 1 < CommandLine.arguments.count
    else {
        throw SemanticToolError.arguments
    }
    return CommandLine.arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func digest(_ url: URL) throws -> String {
    digest(try Data(contentsOf: url))
}

private func decodeRGBA(_ url: URL) throws -> (
    width: Int,
    height: Int,
    rgba: [UInt8]
) {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        )
    else {
        throw SemanticToolError.invalid("could not decode \(url.path)")
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
            throw SemanticToolError.invalid("could not create decoder")
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return (image.width, image.height, rgba)
}

private func image(
    rgba: [UInt8],
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
        throw SemanticToolError.invalid("could not create image")
    }
    return image
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
        throw SemanticToolError.invalid("could not create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw SemanticToolError.invalid("could not finalize PNG")
    }
}

private func imageIOCanonicalImage(_ source: CGImage) throws -> CGImage {
    let data = NSMutableData()
    guard
        let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw SemanticToolError.invalid(
            "could not create in-memory semantic PNG"
        )
    }
    CGImageDestinationAddImage(destination, source, nil)
    guard
        CGImageDestinationFinalize(destination),
        let decodedSource = CGImageSourceCreateWithData(
            data as CFData,
            nil
        ),
        let decoded = CGImageSourceCreateImageAtIndex(
            decodedSource,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        )
    else {
        throw SemanticToolError.invalid(
            "could not decode in-memory semantic PNG"
        )
    }
    return decoded
}

private func writeJSON(_ object: Any, to url: URL) throws {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys]
    )
    data.append(0x0A)
    try data.write(to: url, options: .atomic)
}

private func decodedRGBA(_ image: CGImage) throws -> [UInt8] {
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
            throw SemanticToolError.invalid("could not decode image")
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return rgba
}

private func registered(
    _ source: CGImage,
    width: Int,
    height: Int,
    offset: [Double]
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
        throw SemanticToolError.invalid("could not create registration context")
    }
    context.interpolationQuality = .none
    context.draw(
        source,
        in: CGRect(
            x: offset[0],
            y: -offset[1],
            width: Double(width),
            height: Double(height)
        )
    )
    guard let image = context.makeImage() else {
        throw SemanticToolError.invalid("could not create registered image")
    }
    return image
}

private func embedRegistered(
    cropRGBA: [UInt8],
    cropWidth: Int,
    cropHeight: Int,
    sourceWidth: Int,
    sourceHeight: Int,
    cropOriginSourceX: Int,
    cropOriginSourceY: Int,
    postProjectionOffset: [Double]
) -> [UInt8] {
    var output = [UInt8](
        repeating: 0,
        count: sourceWidth * sourceHeight * 4
    )
    let destinationOriginX =
        cropOriginSourceX + Int(postProjectionOffset[0].rounded())
    let destinationOriginY =
        cropOriginSourceY + Int(postProjectionOffset[1].rounded())
    for cropY in 0..<cropHeight {
        let destinationY = destinationOriginY + cropY
        guard destinationY >= 0, destinationY < sourceHeight else { continue }
        for cropX in 0..<cropWidth {
            let destinationX = destinationOriginX + cropX
            guard destinationX >= 0, destinationX < sourceWidth else {
                continue
            }
            let sourceOffset = (cropY * cropWidth + cropX) * 4
            let destinationOffset =
                (destinationY * sourceWidth + destinationX) * 4
            output[destinationOffset] = cropRGBA[sourceOffset]
            output[destinationOffset + 1] = cropRGBA[sourceOffset + 1]
            output[destinationOffset + 2] = cropRGBA[sourceOffset + 2]
            output[destinationOffset + 3] = cropRGBA[sourceOffset + 3]
        }
    }
    return output
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
        throw SemanticToolError.invalid("could not create scale context")
    }
    context.interpolationQuality = .high
    context.draw(
        source,
        in: CGRect(x: 0, y: 0, width: width, height: height)
    )
    guard let image = context.makeImage() else {
        throw SemanticToolError.invalid("could not create scaled image")
    }
    return image
}

private func semanticLanczosDownsample(
    _ source: CGImage,
    sampling: EffectiveSamplingContract,
    outputWidth: Int,
    outputHeight: Int
) throws -> CGImage {
    guard
        sampling.downsampleFilter
            == DiagnosticSamplingPipelineContract.filter,
        sampling.downsampleScale == 0.25,
        sampling.downsampleAspectRatio == 1,
        sampling.ciUseSoftwareRenderer,
        !sampling.ciCacheIntermediates
    else {
        throw SemanticToolError.invalid("semantic Lanczos contract drift")
    }

    func direct(
        _ input: CGImage,
        width: Int,
        height: Int
    ) throws -> CGImage {
        let context = CIContext(options: [
            .useSoftwareRenderer: true,
            .cacheIntermediates: false,
            .workingColorSpace: CGColorSpace(
                name: CGColorSpace.extendedSRGB
            )!,
            .outputColorSpace: CGColorSpace(
                name: CGColorSpace.sRGB
            )!,
        ])
        guard
            let filter = CIFilter(
                name: DiagnosticSamplingPipelineContract.filter
            )
        else {
            throw SemanticToolError.invalid(
                "semantic Lanczos filter unavailable"
            )
        }
        let inputData = Data(try decodedRGBA(input))
        let inputImage = CIImage(
            bitmapData: inputData,
            bytesPerRow: input.width * 4,
            size: CGSize(width: input.width, height: input.height),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        )
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(
            sampling.downsampleScale,
            forKey: kCIInputScaleKey
        )
        filter.setValue(
            sampling.downsampleAspectRatio,
            forKey: kCIInputAspectRatioKey
        )
        guard let output = filter.outputImage else {
            throw SemanticToolError.invalid(
                "semantic Lanczos filter produced no output"
            )
        }
        guard let result = context.createCGImage(
            output,
            from: CGRect(x: 0, y: 0, width: width, height: height)
        ) else {
            throw SemanticToolError.invalid(
                "semantic Lanczos image materialization failed "
                    + "input=\(input.width)x\(input.height) "
                    + "output=\(width)x\(height)"
            )
        }
        return result
    }

    guard
        source.width == outputWidth * 4,
        source.height == outputHeight * 4
    else {
        throw SemanticToolError.invalid(
            "semantic Lanczos input/output dimensions drifted"
        )
    }
    func transparentBlack(_ input: CGImage) throws -> CGImage {
        var rgba = try decodedRGBA(input)
        for offset in stride(from: 0, to: rgba.count, by: 4) {
            if
                rgba[offset] == 0,
                rgba[offset + 1] == 0,
                rgba[offset + 2] == 0
            {
                rgba[offset + 3] = 0
            } else {
                rgba[offset + 3] = 255
            }
        }
        return try image(
            rgba: rgba,
            width: input.width,
            height: input.height
        )
    }

    var sourceRGBA = try decodedRGBA(source)
    for offset in stride(from: 3, to: sourceRGBA.count, by: 4) {
        sourceRGBA[offset] = 255
    }
    let opaqueSource = try image(
        rgba: sourceRGBA,
        width: source.width,
        height: source.height
    )
    if source.width <= 1_024 && source.height <= 1_024 {
        return try transparentBlack(
            direct(
                imageIOCanonicalImage(opaqueSource),
                width: outputWidth,
                height: outputHeight
            )
        )
    }

    // Core Image's software renderer rejects the complete 4,164x2,904
    // semantic crop. Tile at factor-4 boundaries and retain 64 high-resolution
    // pixels of positive Lanczos support around every interior. Only supported
    // cores are stitched; this is the same frozen kernel and color-space
    // contract, with no voting or semantic mutation.
    let core = 768
    let overlap = 64
    var stitched = [UInt8](
        repeating: 0,
        count: outputWidth * outputHeight * 4
    )
    for coreY in stride(from: 0, to: source.height, by: core) {
        let coreEndY = min(source.height, coreY + core)
        let inputY = max(0, coreY - overlap)
        let inputEndY = min(source.height, coreEndY + overlap)
        for coreX in stride(from: 0, to: source.width, by: core) {
            let coreEndX = min(source.width, coreX + core)
            let inputX = max(0, coreX - overlap)
            let inputEndX = min(source.width, coreEndX + overlap)
            let inputWidth = inputEndX - inputX
            let inputHeight = inputEndY - inputY
            guard
                inputX % 4 == 0,
                inputY % 4 == 0,
                inputWidth % 4 == 0,
                inputHeight % 4 == 0
            else {
                throw SemanticToolError.invalid(
                    "semantic Lanczos tiled support contract failed"
                )
            }
            var tileInputRGBA = [UInt8](
                repeating: 0,
                count: inputWidth * inputHeight * 4
            )
            for tileY in 0..<inputHeight {
                let sourceStart =
                    ((inputY + tileY) * source.width + inputX) * 4
                let destinationStart = tileY * inputWidth * 4
                tileInputRGBA[
                    destinationStart..<(destinationStart + inputWidth * 4)
                ] = sourceRGBA[
                    sourceStart..<(sourceStart + inputWidth * 4)
                ]
            }
            let tileInput = try image(
                rgba: tileInputRGBA,
                width: inputWidth,
                height: inputHeight
            )
            let tile = try direct(
                imageIOCanonicalImage(tileInput),
                width: inputWidth / 4,
                height: inputHeight / 4
            )
            let tileRGBA = try decodedRGBA(tile)
            for outputY in (coreY / 4)..<(coreEndY / 4) {
                let tileY = outputY - inputY / 4
                for outputX in (coreX / 4)..<(coreEndX / 4) {
                    let tileX = outputX - inputX / 4
                    let destination =
                        (outputY * outputWidth + outputX) * 4
                    let sourceOffset =
                        (tileY * tile.width + tileX) * 4
                    stitched[destination..<(destination + 4)] =
                        tileRGBA[sourceOffset..<(sourceOffset + 4)]
                }
            }
        }
    }
    return try transparentBlack(
        image(
            rgba: stitched,
            width: outputWidth,
            height: outputHeight
        )
    )
}

private func maskMetric(
    _ rgba: [UInt8],
    width: Int,
    height: Int,
    alphaThreshold: UInt8 = 8
) -> ScaleMetric {
    var count = 0
    var minimumX = width
    var minimumY = height
    var maximumX = -1
    var maximumY = -1
    var active = [Bool](repeating: false, count: width * height)
    for y in 0..<height {
        for x in 0..<width {
            let index = y * width + x
            guard rgba[index * 4 + 3] >= alphaThreshold else { continue }
            active[index] = true
            count += 1
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    var components = 0
    var visited = [Bool](repeating: false, count: active.count)
    for start in 0..<active.count where active[start] && !visited[start] {
        components += 1
        var queue = [start]
        visited[start] = true
        var cursor = 0
        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1
            let x = index % width
            let y = index / width
            for neighbor in [
                x > 0 ? index - 1 : -1,
                x + 1 < width ? index + 1 : -1,
                y > 0 ? index - width : -1,
                y + 1 < height ? index + width : -1,
            ] where neighbor >= 0 && active[neighbor] && !visited[neighbor] {
                visited[neighbor] = true
                queue.append(neighbor)
            }
        }
    }
    let bounds =
        count == 0
        ? []
        : [minimumX, minimumY, maximumX, maximumY]
    return ScaleMetric(
        visiblePixels: count,
        bounds: bounds,
        width: count == 0 ? 0 : maximumX - minimumX + 1,
        height: count == 0 ? 0 : maximumY - minimumY + 1,
        connectedComponents: components
    )
}

private func medianLuma(
    actualRGBA: [UInt8],
    maskRGBA: [UInt8]
) -> Int? {
    var values: [Int] = []
    for index in 0..<(actualRGBA.count / 4)
    where maskRGBA[index * 4 + 3] >= 8 {
        let offset = index * 4
        guard actualRGBA[offset + 3] > 0 else { continue }
        values.append(
            (
                54 * Int(actualRGBA[offset])
                + 183 * Int(actualRGBA[offset + 1])
                + 19 * Int(actualRGBA[offset + 2])
            ) / 256
        )
    }
    guard !values.isEmpty else { return nil }
    values.sort()
    return values[values.count / 2]
}

private func componentRecord(_ evidence: ComponentEvidence) -> [String: Any] {
    func scale(_ metric: ScaleMetric) -> [String: Any] {
        [
            "visiblePixels": metric.visiblePixels,
            "bounds": metric.bounds,
            "width": metric.width,
            "height": metric.height,
            "connectedComponents": metric.connectedComponents,
        ]
    }
    return [
        "component": evidence.component.identifier,
        "isolatedSourceSupportPixels": evidence.isolatedPixels,
        "visibleSourcePixels": evidence.source.visiblePixels,
        "occludedSourcePixels": evidence.occludedPixels,
        "occlusionByVisibleOwner": evidence.occlusionByOwner,
        "source": scale(evidence.source),
        "native2x": scale(evidence.native2x),
        "literal192": scale(evidence.literal192),
        "actualMedianLuma": evidence.medianLuma as Any,
    ]
}

private func composite(
    masks: [[UInt8]],
    components: [PLAY027SemanticComponent],
    width: Int,
    height: Int,
    grayscale: Bool
) -> [UInt8] {
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    for (mask, component) in zip(masks, components) {
        for index in 0..<(width * height)
        where mask[index * 4 + 3] >= 8 {
            let offset = index * 4
            if grayscale {
                rgba[offset] = component.grayscale
                rgba[offset + 1] = component.grayscale
                rgba[offset + 2] = component.grayscale
            } else {
                let color = component.color
                rgba[offset] = color.0
                rgba[offset + 1] = color.1
                rgba[offset + 2] = color.2
            }
            rgba[offset + 3] = 255
        }
    }
    return rgba
}

@main
private enum BuildIndustrialL4V17SemanticVisibilityV1 {
    static func main() throws {
        let repositoryRoot = URL(
            fileURLWithPath: try argument("--repository-root")
        ).standardizedFileURL
        let outputDirectory = URL(
            fileURLWithPath: try argument("--output-directory")
        ).standardizedFileURL
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: outputDirectory.path) else {
            throw SemanticToolError.invalid("output directory must be absent")
        }
        try fileManager.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let descriptorURL = repositoryRoot.appendingPathComponent(
            descriptorRelativePath
        )
        let materialURL = repositoryRoot.appendingPathComponent(
            materialRelativePath
        )
        let canonicalURL = repositoryRoot.appendingPathComponent(
            canonicalRelativePath
        )
        guard
            try digest(descriptorURL) == expectedDescriptorSHA,
            try digest(materialURL) == expectedMaterialSHA,
            try digest(canonicalURL) == expectedCanonicalFileSHA
        else {
            throw SemanticToolError.invalid("exact v17 binding drift")
        }
        let descriptorData = try Data(contentsOf: descriptorURL)
        let materialData = try Data(contentsOf: materialURL)
        let descriptor = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: descriptorData
        )
        let materialDescriptor = try JSONDecoder().decode(
            MaterialLibraryDescriptor.self,
            from: materialData
        )
        guard
            descriptor.logicalBuildingID == "industrial_l04",
            descriptor.variantID == "variant-0",
            descriptor.sourceRevision == "source-v17-prepixel",
            descriptor.viewDirection == "n",
            descriptor.sceneGeometryID
                == "industrial-l04-crucible-gantry-v17-north-monumental-portal"
        else {
            throw SemanticToolError.invalid("v17 descriptor identity drift")
        }
        let sampling = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        guard
            sampling.contractID
                == DescriptorSamplingResolver.schema2ContractV3ID,
            sampling.linearOversamplingFactor == 4,
            sampling.sceneKitAntialiasing == "none",
            sampling.sceneKitShadows == "disabled",
            sampling.sceneKitLightingMode == "authored-constant-v1"
        else {
            throw SemanticToolError.invalid("governed sampling drift")
        }
        let library = NativeMaterialLibrary(
            descriptor: materialDescriptor,
            repositoryRoot: repositoryRoot
        )
        let scene = try ContractSceneBuilder(
            materials: library
        ).buildScene(from: descriptor)
        guard let cameraNode = scene.rootNode.childNode(
            withName: "contract-camera",
            recursively: false
        ) else {
            throw SemanticToolError.invalid("contract camera missing")
        }
        let extraction = try PLAY027SemanticVisibilityV1.extract(scene: scene)
        let sourceWidth = descriptor.camera.renderViewportPixels[0]
        let sourceHeight = descriptor.camera.renderViewportPixels[1]
        let factor = sampling.linearOversamplingFactor
        let highWidth = sourceWidth * factor
        let highHeight = sourceHeight * factor
        let projectedBounds = try PLAY027SemanticVisibilityV1.projectedBounds(
            extraction: extraction,
            cameraNode: cameraNode,
            orthographicScale: descriptor.camera.orthographicScale,
            viewportWidth: highWidth,
            viewportHeight: highHeight
        )
        let cropPadding = 32
        let cropMinimumX =
            max(0, ((projectedBounds[0] - cropPadding) / factor) * factor)
        let cropMinimumY =
            max(0, ((projectedBounds[1] - cropPadding) / factor) * factor)
        let cropMaximumX =
            min(
                highWidth,
                (
                    (projectedBounds[2] + cropPadding + factor - 1)
                        / factor
                ) * factor
            )
        let cropMaximumY =
            min(
                highHeight,
                (
                    (projectedBounds[3] + cropPadding + factor - 1)
                        / factor
                ) * factor
            )
        let cropHighWidth = cropMaximumX - cropMinimumX
        let cropHighHeight = cropMaximumY - cropMinimumY
        let cropSourceWidth = cropHighWidth / factor
        let cropSourceHeight = cropHighHeight / factor
        print(
            "semantic-crop=\(cropMinimumX),\(cropMinimumY),"
                + "\(cropMaximumX),\(cropMaximumY) "
                + "\(cropHighWidth)x\(cropHighHeight)"
        )
        try writeJSON(
            [
                "projectedBounds": projectedBounds,
                "crop": [
                    cropMinimumX,
                    cropMinimumY,
                    cropMaximumX,
                    cropMaximumY,
                ],
                "cropHighSize": [cropHighWidth, cropHighHeight],
                "cropSourceSize": [cropSourceWidth, cropSourceHeight],
            ],
            to: outputDirectory.appendingPathComponent("SEMANTIC-CROP.json")
        )
        let fullHigh = try PLAY027SemanticVisibilityV1.rasterize(
            extraction: extraction,
            cameraNode: cameraNode,
            orthographicScale: descriptor.camera.orthographicScale,
            width: cropHighWidth,
            height: cropHighHeight,
            fullViewportWidth: highWidth,
            fullViewportHeight: highHeight,
            originX: cropMinimumX,
            originY: cropMinimumY
        )
        let fullHighVisiblePixels = fullHigh.owners.filter { $0 != 0 }.count
        guard fullHighVisiblePixels > 0 else {
            throw SemanticToolError.invalid(
                "semantic SceneKit projection produced no visible pixels"
            )
        }
        try writeJSON(
            ["visiblePixels": fullHighVisiblePixels],
            to: outputDirectory.appendingPathComponent(
                "SEMANTIC-HIGH-SUPPORT.json"
            )
        )
        let fullHighImage = try image(
            rgba: PLAY027SemanticVisibilityV1.ownerImage(
                raster: fullHigh
            ),
            width: cropHighWidth,
            height: cropHighHeight
        )
        let fullSourceCrop = try semanticLanczosDownsample(
            fullHighImage,
            sampling: sampling,
            outputWidth: cropSourceWidth,
            outputHeight: cropSourceHeight
        )
        let fullSourceRGBA = embedRegistered(
            cropRGBA: try decodeImage(fullSourceCrop),
            cropWidth: cropSourceWidth,
            cropHeight: cropSourceHeight,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            cropOriginSourceX: cropMinimumX / factor,
            cropOriginSourceY: cropMinimumY / factor,
            postProjectionOffset:
                descriptor.camera.postProjectionOffsetPixels
        )

        let actual = try decodeRGBA(canonicalURL)
        guard
            actual.width == sourceWidth,
            actual.height == sourceHeight
        else {
            throw SemanticToolError.invalid("canonical source dimensions drift")
        }

        var componentEvidence: [ComponentEvidence] = []
        var visibleMasks: [PLAY027SemanticComponent: [UInt8]] = [:]
        var isolatedMasks: [PLAY027SemanticComponent: [UInt8]] = [:]
        for component in PLAY027SemanticComponent.allCases
        where component != .other {
            let isolatedHigh = try PLAY027SemanticVisibilityV1.rasterize(
                extraction: extraction,
                cameraNode: cameraNode,
                orthographicScale: descriptor.camera.orthographicScale,
                width: cropHighWidth,
                height: cropHighHeight,
                fullViewportWidth: highWidth,
                fullViewportHeight: highHeight,
                originX: cropMinimumX,
                originY: cropMinimumY,
                includedComponents: [component]
            )
            let isolatedHighImage = try image(
                rgba: PLAY027SemanticVisibilityV1.binaryMaskImage(
                    raster: isolatedHigh,
                    component: component
                ),
                width: cropHighWidth,
                height: cropHighHeight
            )
            let isolatedSourceCrop = try semanticLanczosDownsample(
                isolatedHighImage,
                sampling: sampling,
                outputWidth: cropSourceWidth,
                outputHeight: cropSourceHeight
            )
            let isolatedRGBA = embedRegistered(
                cropRGBA: try decodeImage(isolatedSourceCrop),
                cropWidth: cropSourceWidth,
                cropHeight: cropSourceHeight,
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                cropOriginSourceX: cropMinimumX / factor,
                cropOriginSourceY: cropMinimumY / factor,
                postProjectionOffset:
                    descriptor.camera.postProjectionOffsetPixels
            )
            isolatedMasks[component] = isolatedRGBA

            var visibleHighRGBA = [UInt8](
                repeating: 0,
                count: cropHighWidth * cropHighHeight * 4
            )
            for index in 0..<fullHigh.owners.count
            where fullHigh.owners[index] == component.rawValue {
                let offset = index * 4
                visibleHighRGBA[offset] = 255
                visibleHighRGBA[offset + 1] = 255
                visibleHighRGBA[offset + 2] = 255
                visibleHighRGBA[offset + 3] = 255
            }
            let visibleSourceCrop = try semanticLanczosDownsample(
                try image(
                    rgba: visibleHighRGBA,
                    width: cropHighWidth,
                    height: cropHighHeight
                ),
                sampling: sampling,
                outputWidth: cropSourceWidth,
                outputHeight: cropSourceHeight
            )
            let visibleRGBA = embedRegistered(
                cropRGBA: try decodeImage(visibleSourceCrop),
                cropWidth: cropSourceWidth,
                cropHeight: cropSourceHeight,
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                cropOriginSourceX: cropMinimumX / factor,
                cropOriginSourceY: cropMinimumY / factor,
                postProjectionOffset:
                    descriptor.camera.postProjectionOffsetPixels
            )
            visibleMasks[component] = visibleRGBA
            let visibleSource = try image(
                rgba: visibleRGBA,
                width: sourceWidth,
                height: sourceHeight
            )
            let nativeRGBA = try decodeImage(
                try scaled(visibleSource, width: 384, height: 256)
            )
            let compactRGBA = try decodeImage(
                try scaled(visibleSource, width: 192, height: 128)
            )
            let isolatedMetric = maskMetric(
                isolatedRGBA,
                width: sourceWidth,
                height: sourceHeight
            )
            let sourceMetric = maskMetric(
                visibleRGBA,
                width: sourceWidth,
                height: sourceHeight
            )
            var occlusionByOwner: [String: Int] = [:]
            for index in 0..<(sourceWidth * sourceHeight)
            where isolatedRGBA[index * 4 + 3] >= 8
                && visibleRGBA[index * 4 + 3] < 8 {
                let owner = fullSourceRGBA[index * 4]
                let nearest = PLAY027SemanticComponent.allCases.min {
                    abs(Int($0.color.0) - Int(owner))
                        < abs(Int($1.color.0) - Int(owner))
                }
                occlusionByOwner[nearest?.identifier ?? "background", default: 0] += 1
            }
            componentEvidence.append(
                ComponentEvidence(
                    component: component,
                    isolatedSourceMask: isolatedRGBA,
                    visibleSourceMask: visibleRGBA,
                    source: sourceMetric,
                    native2x: maskMetric(
                        nativeRGBA,
                        width: 384,
                        height: 256
                    ),
                    literal192: maskMetric(
                        compactRGBA,
                        width: 192,
                        height: 128
                    ),
                    isolatedPixels: isolatedMetric.visiblePixels,
                    occludedPixels:
                        max(
                            0,
                            isolatedMetric.visiblePixels
                                - sourceMetric.visiblePixels
                        ),
                    occlusionByOwner: occlusionByOwner,
                    medianLuma: medianLuma(
                        actualRGBA: actual.rgba,
                        maskRGBA: visibleRGBA
                    )
                )
            )
        }

        let portalComponents: [PLAY027SemanticComponent] = [
            .southJamb, .northJamb, .header, .insetVoid,
        ]
        let occluderComponents: [PLAY027SemanticComponent] = [
            .gantry, .crucibleOccluder,
        ]
        let allComponents = PLAY027SemanticComponent.allCases.filter {
            $0 != .other
        }
        try emitCompositeSet(
            name: "SEMANTIC",
            components: allComponents,
            masks: visibleMasks,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            outputDirectory: outputDirectory
        )
        try emitCompositeSet(
            name: "PORTAL-ONLY",
            components: portalComponents,
            masks: isolatedMasks,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            outputDirectory: outputDirectory
        )
        try emitCompositeSet(
            name: "OCCLUDERS",
            components: occluderComponents,
            masks: isolatedMasks,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            outputDirectory: outputDirectory
        )

        var pairwise: [[String: Any]] = []
        for (leftIndex, left) in allComponents.enumerated() {
            for right in allComponents.dropFirst(leftIndex + 1) {
                let leftMask = isolatedMasks[left]!
                let rightMask = isolatedMasks[right]!
                var overlap = 0
                var adjacency = 0
                for y in 0..<sourceHeight {
                    for x in 0..<sourceWidth {
                        let index = y * sourceWidth + x
                        let leftActive = leftMask[index * 4 + 3] >= 8
                        let rightActive = rightMask[index * 4 + 3] >= 8
                        if leftActive && rightActive { overlap += 1 }
                        guard leftActive else { continue }
                        for neighbor in [
                            x + 1 < sourceWidth ? index + 1 : -1,
                            y + 1 < sourceHeight ? index + sourceWidth : -1,
                        ] where
                            neighbor >= 0
                            && rightMask[neighbor * 4 + 3] >= 8
                        {
                            adjacency += 1
                        }
                    }
                }
                pairwise.append([
                    "left": left.identifier,
                    "right": right.identifier,
                    "isolatedSupportOverlapPixels": overlap,
                    "adjacentEdgeCount": adjacency,
                ])
            }
        }

        let evidenceByComponent = Dictionary(
            uniqueKeysWithValues: componentEvidence.map {
                ($0.component, $0)
            }
        )
        let south = evidenceByComponent[.southJamb]!
        let north = evidenceByComponent[.northJamb]!
        let header = evidenceByComponent[.header]!
        let inset = evidenceByComponent[.insetVoid]!
        let hall = evidenceByComponent[.hall]!
        let gantry = evidenceByComponent[.gantry]!
        let jambMedian = [
            south.medianLuma,
            north.medianLuma,
            header.medianLuma,
        ].compactMap { $0 }.sorted()
        let frameMedian = jambMedian.isEmpty
            ? nil
            : jambMedian[jambMedian.count / 2]
        let frameWallDelta =
            frameMedian.flatMap { frame in
                hall.medianLuma.map { abs(frame - $0) }
            }
        let frameGantryDelta =
            frameMedian.flatMap { frame in
                gantry.medianLuma.map { abs(frame - $0) }
            }
        let literalGate =
            south.literal192.width >= 4
            && south.literal192.height >= 5
            && north.literal192.width >= 4
            && north.literal192.height >= 5
            && header.literal192.width >= 8
            && header.literal192.height >= 3
            && inset.literal192.width >= 5
            && inset.literal192.height >= 5
            && inset.literal192.connectedComponents == 1
            && (frameWallDelta ?? 0) >= 12
            && (frameGantryDelta ?? 0) >= 12
            && inset.source.visiblePixels > 0
        let disposition = literalGate
            ? "PASS_EXACT_V17_SEMANTIC_VISIBILITY"
            : "RETURN_EXACT_V17_PORTAL_VISIBILITY"

        let nodeRecords: [[String: Any]] = extraction.nodes.map {
            [
                "nodeName": $0.nodeName,
                "component": $0.component.identifier,
                "vertexCount": $0.vertexCount,
                "triangleCount": $0.triangleCount,
                "worldTransform": $0.worldTransform,
                "geometrySHA256": $0.geometrySHA256,
            ]
        }
        let nodeManifestData = try JSONSerialization.data(
            withJSONObject: nodeRecords,
            options: [.sortedKeys]
        )
        let report: [String: Any] = [
            "taskID": "PLAY-027",
            "contract": "CONTRACT-019",
            "artifact": "industrial-l04-v17-semantic-visibility-v1",
            "pipeline": PLAY027SemanticVisibilityV1.pipelineName,
            "diagnosticOnly": true,
            "sourceAuthority": false,
            "productionSelected": false,
            "disposition": disposition,
            "processCounts": [
                "metal": 0,
                "sceneKitRenderer": 0,
                "sceneKitNodeConstruction": 1,
                "raw": 0,
                "normalizer": 0,
            ],
            "binding": [
                "descriptor": descriptorRelativePath,
                "descriptorSHA256": expectedDescriptorSHA,
                "materialLibrary": materialRelativePath,
                "materialLibrarySHA256": expectedMaterialSHA,
                "canonicalActualSource": canonicalRelativePath,
                "canonicalActualSourceSHA256": expectedCanonicalFileSHA,
                "sceneGeometryID": descriptor.sceneGeometryID,
                "camera": [
                    "positionWorld": descriptor.camera.positionWorld,
                    "targetWorld": descriptor.camera.targetWorld,
                    "orthographicScale": descriptor.camera.orthographicScale,
                    "renderViewportPixels":
                        descriptor.camera.renderViewportPixels,
                    "postProjectionOffsetPixels":
                        descriptor.camera.postProjectionOffsetPixels,
                ],
                "sampling": [
                    "contractID": sampling.contractID,
                    "linearOversamplingFactor":
                        sampling.linearOversamplingFactor,
                    "filter": sampling.downsampleFilter,
                    "scale": sampling.downsampleScale,
                    "softwareRenderer": sampling.ciUseSoftwareRenderer,
                    "semanticHighResolutionCrop": [
                        cropMinimumX,
                        cropMinimumY,
                        cropMaximumX,
                        cropMaximumY,
                    ],
                ],
            ],
            "descriptorToRenderedNodes": [
                "nodeCount": nodeRecords.count,
                "nodeManifestSHA256": digest(nodeManifestData),
                "nodes": nodeRecords,
            ],
            "components": componentEvidence.map(componentRecord),
            "pairwiseAdjacencyAndOverlap": pairwise,
            "actualGrayscaleSeparation": [
                "portalFrameMedianLuma": frameMedian as Any,
                "hallMedianLuma": hall.medianLuma as Any,
                "gantryMedianLuma": gantry.medianLuma as Any,
                "frameToWallAbsoluteDelta": frameWallDelta as Any,
                "frameToGantryAbsoluteDelta": frameGantryDelta as Any,
            ],
            "gate": [
                "separateJambsAndHeaderAtLiteral192": [
                    "southJamb": [
                        south.literal192.width,
                        south.literal192.height,
                    ],
                    "northJamb": [
                        north.literal192.width,
                        north.literal192.height,
                    ],
                    "header": [
                        header.literal192.width,
                        header.literal192.height,
                    ],
                ],
                "contiguousInsetAtLiteral192": [
                    "width": inset.literal192.width,
                    "height": inset.literal192.height,
                    "connectedComponents":
                        inset.literal192.connectedComponents,
                ],
                "portalCenterVisible": inset.source.visiblePixels > 0,
                "frameToWallDeltaAtLeast12": (frameWallDelta ?? 0) >= 12,
                "frameToGantryDeltaAtLeast12":
                    (frameGantryDelta ?? 0) >= 12,
                "literalActualScalePass": literalGate,
                "independentReviewRequired": true,
            ],
            "tool": [
                "source": toolRelativePath,
                "sourceSHA256": try digest(
                    repositoryRoot.appendingPathComponent(toolRelativePath)
                ),
                "semanticSource": semanticSourceRelativePath,
                "semanticSourceSHA256": try digest(
                    repositoryRoot.appendingPathComponent(
                        semanticSourceRelativePath
                    )
                ),
                "offlineSceneRendererSource": rendererSourceRelativePath,
                "offlineSceneRendererSourceSHA256": try digest(
                    repositoryRoot.appendingPathComponent(
                        rendererSourceRelativePath
                    )
                ),
                "binarySHA256": try digest(
                    URL(fileURLWithPath: CommandLine.arguments[0])
                ),
                "compileCommand":
                    "xcrun swiftc -D PLAY027_SCENE_PREP_DIAGNOSTIC -parse-as-library -warnings-as-errors -module-cache-path <task-local-cache> Sources/*.swift BuildIndustrialL4V17SemanticVisibilityV1.swift -framework AppKit -framework CoreGraphics -framework CoreImage -framework ImageIO -framework ModelIO -framework SceneKit -framework UniformTypeIdentifiers -o build-industrial-l4-v17-semantic-visibility-v1",
            ],
        ]
        try writeJSON(
            report,
            to: outputDirectory.appendingPathComponent(
                "SEMANTIC-VISIBILITY.json"
            )
        )
        print("\(disposition) Industrial L4 v17 semantic visibility")
        print(
            "literal192 south=\(south.literal192.width)x\(south.literal192.height)"
        )
        print(
            "literal192 north=\(north.literal192.width)x\(north.literal192.height)"
        )
        print(
            "literal192 header=\(header.literal192.width)x\(header.literal192.height)"
        )
        print(
            "literal192 inset=\(inset.literal192.width)x\(inset.literal192.height)"
        )
        print(
            "luma frame-wall=\(frameWallDelta ?? -1) frame-gantry=\(frameGantryDelta ?? -1)"
        )
    }

    private static func decodeImage(_ image: CGImage) throws -> [UInt8] {
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
                throw SemanticToolError.invalid("could not decode image")
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
        }
        return rgba
    }

    private static func emitCompositeSet(
        name: String,
        components: [PLAY027SemanticComponent],
        masks: [PLAY027SemanticComponent: [UInt8]],
        sourceWidth: Int,
        sourceHeight: Int,
        outputDirectory: URL
    ) throws {
        let orderedMasks = components.map { masks[$0]! }
        for grayscale in [false, true] {
            let source = try image(
                rgba: composite(
                    masks: orderedMasks,
                    components: components,
                    width: sourceWidth,
                    height: sourceHeight,
                    grayscale: grayscale
                ),
                width: sourceWidth,
                height: sourceHeight
            )
            let suffix = grayscale ? "GRAYSCALE" : "COLOR"
            try writePNG(
                source,
                to: outputDirectory.appendingPathComponent(
                    "\(name)-SOURCE-\(suffix).png"
                )
            )
            try writePNG(
                try scaled(source, width: 384, height: 256),
                to: outputDirectory.appendingPathComponent(
                    "\(name)-NATIVE-2X-\(suffix).png"
                )
            )
            try writePNG(
                try scaled(source, width: 192, height: 128),
                to: outputDirectory.appendingPathComponent(
                    "\(name)-LITERAL-192-\(suffix).png"
                )
            )
        }
    }
}
