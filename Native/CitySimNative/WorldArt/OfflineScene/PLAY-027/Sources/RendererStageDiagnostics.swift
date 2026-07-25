import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

enum RendererStageDiagnosticsError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

struct RendererPNGWriteDiagnostics {
    let imageIOPreSips: [String: Any]
    let finalSips: [String: Any]
}

func rendererStageSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func rendererPackedRGBA(
    image: CGImage
) throws -> [UInt8] {
    guard
        image.bitsPerComponent == 8,
        image.bitsPerPixel == 32,
        image.bytesPerRow >= image.width * 4,
        image.alphaInfo == .last
            || image.alphaInfo == .premultipliedLast,
        let providerData = image.dataProvider?.data
    else {
        throw RendererStageDiagnosticsError.invalid(
            "stage image is not standard 8-bit RGBA"
        )
    }
    let storage = providerData as Data
    guard storage.count >= image.bytesPerRow * image.height else {
        throw RendererStageDiagnosticsError.invalid(
            "stage RGBA provider storage is incomplete"
        )
    }
    var rgba = [UInt8](
        repeating: 0,
        count: image.width * image.height * 4
    )
    rgba.withUnsafeMutableBytes { destination in
        storage.withUnsafeBytes { source in
            guard
                let destinationBase = destination.baseAddress,
                let sourceBase = source.baseAddress
            else {
                return
            }
            for row in 0..<image.height {
                destinationBase
                    .advanced(by: row * image.width * 4)
                    .copyMemory(
                        from: sourceBase.advanced(
                            by: row * image.bytesPerRow
                        ),
                        byteCount: image.width * 4
                    )
            }
        }
    }
    return rgba
}

func rendererCanonicalRGBA(
    image: CGImage
) throws -> [UInt8] {
    var rgba = [UInt8](
        repeating: 0,
        count: image.width * image.height * 4
    )
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let rendered = rgba.withUnsafeMutableBytes { storage -> Bool in
        guard let context = CGContext(
            data: storage.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: colorSpace,
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
        throw RendererStageDiagnosticsError.invalid(
            "could not decode stage image as canonical sRGB RGBA8"
        )
    }
    return rgba
}

func rendererDecodePNG(
    _ url: URL
) throws -> (width: Int, height: Int, rgba: [UInt8]) {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    else {
        throw RendererStageDiagnosticsError.invalid(
            "ImageIO could not decode \(url.path)"
        )
    }
    return (
        width: image.width,
        height: image.height,
        rgba: try rendererPackedRGBA(image: image)
    )
}

func rendererLocal3x3(
    rgba: [UInt8],
    width: Int,
    height: Int,
    target: [Int]
) throws -> [[String: Any]] {
    guard
        target.count == 2,
        target[0] > 0,
        target[1] > 0,
        target[0] < width - 1,
        target[1] < height - 1,
        rgba.count == width * height * 4
    else {
        throw RendererStageDiagnosticsError.invalid(
            "stage target must have a complete 3x3 RGBA neighborhood"
        )
    }
    var records: [[String: Any]] = []
    for offsetY in -1...1 {
        for offsetX in -1...1 {
            let x = target[0] + offsetX
            let y = target[1] + offsetY
            let index = (y * width + x) * 4
            records.append([
                "offset": [offsetX, offsetY],
                "coordinate": [x, y],
                "rgba": Array(rgba[index..<(index + 4)]),
            ])
        }
    }
    return records
}

func rendererRGBAStageRecord(
    stage: String,
    rgba: [UInt8],
    width: Int,
    height: Int,
    target: [Int]
) throws -> [String: Any] {
    let targetIndex = (target[1] * width + target[0]) * 4
    guard
        target.count == 2,
        targetIndex >= 0,
        targetIndex + 4 <= rgba.count
    else {
        throw RendererStageDiagnosticsError.invalid(
            "stage target is outside RGBA buffer"
        )
    }
    return [
        "stage": stage,
        "sourcePixels": [width, height],
        "decodedRGBASHA256":
            rendererStageSHA256(Data(rgba)),
        "targetRGBA":
            Array(rgba[targetIndex..<(targetIndex + 4)]),
        "local3x3": try rendererLocal3x3(
            rgba: rgba,
            width: width,
            height: height,
            target: target
        ),
    ]
}

func rendererOversampledSupportWindowRecord(
    image: CGImage,
    geometry: OversampledSupportGeometry
) throws -> [String: Any] {
    let rgba = try rendererCanonicalRGBA(image: image)
    let bounds = geometry.highResolutionWindowBoundsExclusive
    guard
        bounds.count == 4,
        bounds[0] >= 0,
        bounds[1] >= 0,
        bounds[2] <= image.width,
        bounds[3] <= image.height,
        bounds[0] < bounds[2],
        bounds[1] < bounds[3],
        image.width
            == 1536 * geometry.linearOversamplingFactor,
        image.height
            == 1024 * geometry.linearOversamplingFactor
    else {
        throw RendererStageDiagnosticsError.invalid(
            "oversampled support geometry does not match the 4x frame"
        )
    }
    var windowRGBA: [UInt8] = []
    windowRGBA.reserveCapacity(
        geometry.highResolutionWindowPixels[0]
            * geometry.highResolutionWindowPixels[1] * 4
    )
    for y in bounds[1]..<bounds[3] {
        let start = (y * image.width + bounds[0]) * 4
        let end = (y * image.width + bounds[2]) * 4
        windowRGBA.append(contentsOf: rgba[start..<end])
    }
    let expectedByteCount =
        geometry.highResolutionWindowPixels[0]
        * geometry.highResolutionWindowPixels[1] * 4
    guard windowRGBA.count == expectedByteCount else {
        throw RendererStageDiagnosticsError.invalid(
            "oversampled support window byte count mismatch"
        )
    }
    return [
        "stage": "scenekit-4x-in-memory",
        "coordinateSystem":
            "top-left immutable decoded RGBA",
        "sourceCGImageColorSpace":
            image.colorSpace?.name.map { $0 as String }
            ?? "not-declared",
        "decodedColorSpace": "sRGB",
        "decodedPixelFormat":
            "rgba8-premultiplied-last-byte-order-32-big",
        "decodeInterpolation": "none",
        "fullFramePixels": [image.width, image.height],
        "fullFrameDecodedRGBASHA256":
            rendererStageSHA256(Data(rgba)),
        "outputTargetCoordinate":
            geometry.outputTargetCoordinate,
        "downsampledInputCoordinate":
            geometry.downsampledInputCoordinate,
        "inversePixelCenterMapping":
            "(outputPixel + 0.5) * 4 - 0.5",
        "highResolutionCenterTwice":
            geometry.highResolutionCenterTwice,
        "highResolutionCenterDenominator": 2,
        "supportWindowBoundsExclusive":
            geometry.highResolutionWindowBoundsExclusive,
        "supportWindowPixels":
            geometry.highResolutionWindowPixels,
        "supportWindowCapturedRadiusInputPixels":
            geometry.capturedRadiusInputPixels,
        "supportWindowBorderPolicy":
            "reject-if-window-crosses-4x-frame",
        "supportWindowPurpose":
            "conservative CILanczosScaleTransform input support capture",
        "supportWindowPixelLayout": "row-major-rgba8",
        "supportWindowByteCount": windowRGBA.count,
        "supportWindowRGBASHA256":
            rendererStageSHA256(Data(windowRGBA)),
        "supportWindowRGBA": windowRGBA,
    ]
}

func rendererFullFrameRecord(
    image: CGImage,
    stage: String
) throws -> [String: Any] {
    let rgba = try rendererCanonicalRGBA(image: image)
    return [
        "stage": stage,
        "pixels": [image.width, image.height],
        "decodedColorSpace": "sRGB",
        "decodedPixelFormat":
            "rgba8-premultiplied-last-byte-order-32-big",
        "decodedRGBAByteCount": rgba.count,
        "decodedRGBASHA256":
            rendererStageSHA256(Data(rgba)),
    ]
}

func canonicalizePreLanczosFrameImage(
    _ image: CGImage,
    contract: SamplingPreLanczosCanonicalizerDescriptor
) throws -> (
    image: CGImage,
    result: PreLanczosFrameCanonicalizationResult
) {
    let rgba = try rendererCanonicalRGBA(image: image)
    let result = try canonicalizePreLanczosFrameRGBA(
        sourceRGBA: rgba,
        width: image.width,
        height: image.height,
        contract: contract
    )
    guard
        let provider = CGDataProvider(
            data: Data(result.rgba) as CFData
        ),
        let output = CGImage(
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: image.width * 4,
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
        throw PreLanczosFrameCanonicalizerError.invalid(
            "could not create canonicalized pre-Lanczos image"
        )
    }
    return (output, result)
}

func rendererPNGStageRecord(
    stage: String,
    url: URL,
    repositoryRoot: URL,
    target: [Int]
) throws -> [String: Any] {
    let decoded = try rendererDecodePNG(url)
    var record = try rendererRGBAStageRecord(
        stage: stage,
        rgba: decoded.rgba,
        width: decoded.width,
        height: decoded.height,
        target: target
    )
    record["file"] = rendererRelativePath(
        url,
        repositoryRoot: repositoryRoot
    )
    record["fileSHA256"] = try rendererSHA256(url)
    return record
}
