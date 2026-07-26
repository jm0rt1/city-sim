import AppKit
import CoreGraphics
import CoreImage
import CryptoKit
import Foundation
import ImageIO
import SceneKit
import UniformTypeIdentifiers

enum IndustrialL2EastV04ProbeError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)
    case rendering(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: render-industrial-l2-east-v05-calibration --repository-root <path> --output-root <path> --renderer-source-commit <sha>"
        case let .invalid(message), let .rendering(message):
            return message
        }
    }
}

private let v04ProbeApprovedCommit =
    "08e9f3ab669caf41af24f910e3d673d96cbb2cd9"
private let v04ProbeDescriptorSHA256 =
    "9f9e0a61a2fd0a1fbe18304a1b32a803447b7aa4f03d22d27f349cd2b7088ad6"
private let v04ProbeMaterialSHA256 =
    "6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb"
private let v04ProbeGeometrySHA256 =
    "6c727c4b7053d69578e97c2f73cf3054cd2dda106bf06625e0dac12a356798fb"
private let v04ProbeAlphaContractSHA256 =
    "351aed1910d7b680991815a479897fb4849060dd19798d662fe8c03f494f64e9"
private let v04ProbeValidationReplaySHA256 =
    "07c2b605520898abd547e53fae2582d75e04957e56ab699484c372ec512d6072"
private let v04ProbeV03RawSHA256 =
    "24e57812ef0d0d024aef8b4d45a2bda9f98c902874b534aed9ff6040707867ba"
private let v04ProbeV03ProvenanceSHA256 =
    "a8feb0b164d7d67c047de32e8291e4c4d16c220a8f72b6f46ef931b22a7b4db7"
private let v04ProbeV03HandoffSHA256 =
    "d1bf816ec8267b68d780fc4ab7b02d123a011d19fe3727994236c20ace9b9015"
private let v04ProbeV03RejectionSHA256 =
    "3ccefb83cded63bf0958c4b28eabf00af8ccf4551dd4191d3675c4641110a877"
private let v04ProbeV03MetricsSHA256 =
    "cd55e28517b2e2ca5896d433f5a0646840786b8684a45c2f3ef0bd931f69c1c9"
private let v04ProbeRejectedToolFreezeSHA256 =
    "749e4ffdf68aec197fcb7a99993014cc00f0af55895ee58d620669b71f128e3a"
private let v04ProbeRejectedInventorySHA256 =
    "ede91428c6f2e88253b7165dbe9db16314da9190afdfe5a3594ce3934f9f7ec8"
private let v04ProbeRejectedFailureSHA256 =
    "16ded1f76af96415d57033f7bb1dcfd97d991c9d47216e5cc70271c381959154"
private let v04ProbeRejectedTextSHA256 =
    "791a6effab74ca6ff7abedd250908ccf752c22db521b315c3e20100e01b325d3"
private let v04ProbeOutputSuffix =
    "/docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05/raw-calibration/diagnostics/east-primary"
private let v04ProbeRelationEvidenceSuffix =
    "/docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/alpha-relation-repair/prepixel/ALPHA-RELATION-SYNTHETIC-PROOF.json"
private let v04ProbeRelationReplayPath =
    "/private/tmp/play027-industrial-l2-east-v04-alpha-relation-replay.json"

private func v04ProbeArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2EastV04ProbeError.arguments
    }
    return arguments[index + 1]
}

private func v04ProbeSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func v04ProbeSHA256(_ url: URL) throws -> String {
    v04ProbeSHA256(try Data(contentsOf: url))
}

private func v04ProbeWriteJSON(
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

private func v04ProbeDecodeMaterials(
    from data: Data,
    repositoryRoot: URL
) throws -> MaterialLibraryDescriptor {
    let descriptor = try JSONDecoder().decode(
        MaterialLibraryDescriptor.self,
        from: data
    )
    guard
        try v04ProbeSHA256(
            repositoryRoot.appendingPathComponent(
                descriptor.styleAnchorFile
            )
        ) == descriptor.styleAnchorSHA256,
        try v04ProbeSHA256(
            repositoryRoot.appendingPathComponent(
                descriptor.familyAnchorFile
            )
        ) == descriptor.familyAnchorSHA256
    else {
        throw IndustrialL2EastV04ProbeError.invalid(
            "v04 material anchor hash drift"
        )
    }
    return descriptor
}

private func v04ProbeContext(
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
        throw IndustrialL2EastV04ProbeError.rendering(
            "could not allocate alpha proof context"
        )
    }
    return context
}

private func v04ProbeDownsamplePreChroma(
    _ oversampled: CGImage,
    descriptor: SceneDescriptor,
    sampling: EffectiveSamplingContract
) throws -> CGImage {
    let context = CIContext(options: [
        .useSoftwareRenderer: sampling.ciUseSoftwareRenderer,
        .cacheIntermediates: sampling.ciCacheIntermediates,
        .workingColorSpace: CGColorSpace(
            name: CGColorSpace.extendedSRGB
        )!,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    ])
    guard let filter = CIFilter(name: sampling.downsampleFilter) else {
        throw IndustrialL2EastV04ProbeError.rendering(
            "CILanczosScaleTransform unavailable"
        )
    }
    filter.setValue(CIImage(cgImage: oversampled), forKey: kCIInputImageKey)
    filter.setValue(
        CGFloat(sampling.downsampleScale),
        forKey: kCIInputScaleKey
    )
    filter.setValue(
        sampling.downsampleAspectRatio,
        forKey: kCIInputAspectRatioKey
    )
    guard
        let output = filter.outputImage,
        let image = context.createCGImage(
            output,
            from: CGRect(
                x: 0,
                y: 0,
                width: descriptor.camera.renderViewportPixels[0],
                height: descriptor.camera.renderViewportPixels[1]
            )
        )
    else {
        throw IndustrialL2EastV04ProbeError.rendering(
            "pre-chroma software Lanczos downsample failed"
        )
    }
    return image
}

private func v04ProbeDrawAuthoredShadow(
    descriptor: SceneDescriptor,
    context: CGContext,
    canvasHeight: CGFloat
) {
    context.saveGState()
    context.translateBy(x: 0, y: canvasHeight)
    context.scaleBy(x: 1, y: -1)
    let projected = descriptor.registration.contactPolygonWorld.map {
        point in
        CGPoint(
            x: 768 + (point[0] - point[1]) * 256 / 72,
            y: 768 + (point[0] + point[1]) * 128 / 72
        )
    }
    let shadowScale = 28.0
    let offset = CGPoint(
        x: descriptor.light.shadowVectorSource[0] * shadowScale,
        y: descriptor.light.shadowVectorSource[1] * shadowScale
    )
    let path = CGMutablePath()
    path.move(
        to: CGPoint(
            x: projected[0].x + offset.x,
            y: projected[0].y + offset.y
        )
    )
    for point in projected.dropFirst() {
        path.addLine(
            to: CGPoint(
                x: point.x + offset.x,
                y: point.y + offset.y
            )
        )
    }
    path.closeSubpath()
    context.setShadow(
        offset: .zero,
        blur: descriptor.light.shadowBlurSourcePixels,
        color: NSColor.black.withAlphaComponent(
            descriptor.light.shadowOpacity
        ).cgColor
    )
    context.setFillColor(
        NSColor.black.withAlphaComponent(0.12).cgColor
    )
    context.addPath(path)
    context.fillPath()
    context.restoreGState()
}

private func v04ProbeRegisterAlpha(
    _ source: CGImage,
    descriptor: SceneDescriptor,
    includeAuthoredShadow: Bool
) throws -> CGImage {
    let width = descriptor.camera.renderViewportPixels[0]
    let height = descriptor.camera.renderViewportPixels[1]
    let context = try v04ProbeContext(width: width, height: height)
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    if includeAuthoredShadow {
        v04ProbeDrawAuthoredShadow(
            descriptor: descriptor,
            context: context,
            canvasHeight: CGFloat(height)
        )
    }
    context.interpolationQuality = .high
    context.draw(
        source,
        in: CGRect(
            x: descriptor.camera.postProjectionOffsetPixels[0],
            y: -descriptor.camera.postProjectionOffsetPixels[1],
            width: Double(width),
            height: Double(height)
        )
    )
    guard let image = context.makeImage() else {
        throw IndustrialL2EastV04ProbeError.rendering(
            "could not create registered alpha proof"
        )
    }
    return image
}

private func v04ProbeNeutralComposite(
    _ alphaSource: CGImage
) throws -> CGImage {
    let context = try v04ProbeContext(
        width: alphaSource.width,
        height: alphaSource.height
    )
    context.setFillColor(
        NSColor(
            colorSpace: .sRGB,
            components: [
                CGFloat(224) / 255,
                CGFloat(226) / 255,
                CGFloat(220) / 255,
                1,
            ],
            count: 4
        ).cgColor
    )
    context.fill(
        CGRect(
            x: 0,
            y: 0,
            width: alphaSource.width,
            height: alphaSource.height
        )
    )
    context.draw(
        alphaSource,
        in: CGRect(
            x: 0,
            y: 0,
            width: alphaSource.width,
            height: alphaSource.height
        )
    )
    guard let image = context.makeImage() else {
        throw IndustrialL2EastV04ProbeError.rendering(
            "could not create neutral alpha composite"
        )
    }
    return image
}

private struct V04StraightAlphaResult {
    let image: CGImage
    let inputAlphaSHA256: String
    let outputAlphaSHA256: String
    let foregroundInputAlphaSHA256: String
    let foregroundOutputAlphaSHA256: String
    let foregroundPixelCount: Int
    let partialAlphaPixelCount: Int
    let exactChromaPixelCount: Int
    let zeroToChromaPixelCount: Int
    let alphaRelationViolationCount: Int
    let opaqueNearMagentaForegroundPixelCount: Int
    let postQuantizationMutationCount: Int
}

private struct V04AlphaRelationReport {
    let inputAlphaSHA256: String
    let outputAlphaSHA256: String
    let foregroundInputAlphaSHA256: String
    let foregroundOutputAlphaSHA256: String
    let inputPixelCount: Int
    let foregroundPixelCount: Int
    let zeroToChromaPixelCount: Int
    let relationViolationCount: Int

    var record: [String: Any] {
        [
            "inputAlphaSHA256": inputAlphaSHA256,
            "outputAlphaSHA256": outputAlphaSHA256,
            "foregroundInputAlphaSHA256":
                foregroundInputAlphaSHA256,
            "foregroundOutputAlphaSHA256":
                foregroundOutputAlphaSHA256,
            "inputPixelCount": inputPixelCount,
            "foregroundPixelCount": foregroundPixelCount,
            "zeroToChromaPixelCount": zeroToChromaPixelCount,
            "relationViolationCount": relationViolationCount,
        ]
    }
}

private func v04ProbeAlphaRelationReport(
    inputRGBA: [UInt8],
    outputRGBA: [UInt8]
) throws -> V04AlphaRelationReport {
    guard
        inputRGBA.count == outputRGBA.count,
        inputRGBA.count.isMultiple(of: 4)
    else {
        throw IndustrialL2EastV04ProbeError.invalid(
            "v04 alpha relation dimensions mismatch"
        )
    }
    var inputAlpha: [UInt8] = []
    var outputAlpha: [UInt8] = []
    var foregroundInputAlpha: [UInt8] = []
    var foregroundOutputAlpha: [UInt8] = []
    inputAlpha.reserveCapacity(inputRGBA.count / 4)
    outputAlpha.reserveCapacity(outputRGBA.count / 4)
    foregroundInputAlpha.reserveCapacity(inputRGBA.count / 4)
    foregroundOutputAlpha.reserveCapacity(outputRGBA.count / 4)
    var zeroToChroma = 0
    var violations = 0
    for pixel in stride(from: 0, to: inputRGBA.count, by: 4) {
        let input = Array(inputRGBA[pixel..<(pixel + 4)])
        let output = Array(outputRGBA[pixel..<(pixel + 4)])
        inputAlpha.append(input[3])
        outputAlpha.append(output[3])
        if input[3] == 0 {
            if output == [255, 0, 255, 255] {
                zeroToChroma += 1
            } else {
                violations += 1
            }
        } else {
            foregroundInputAlpha.append(input[3])
            foregroundOutputAlpha.append(output[3])
            if output[3] != input[3] {
                violations += 1
            }
        }
    }
    return V04AlphaRelationReport(
        inputAlphaSHA256: v04ProbeSHA256(Data(inputAlpha)),
        outputAlphaSHA256: v04ProbeSHA256(Data(outputAlpha)),
        foregroundInputAlphaSHA256:
            v04ProbeSHA256(Data(foregroundInputAlpha)),
        foregroundOutputAlphaSHA256:
            v04ProbeSHA256(Data(foregroundOutputAlpha)),
        inputPixelCount: inputAlpha.count,
        foregroundPixelCount: foregroundInputAlpha.count,
        zeroToChromaPixelCount: zeroToChroma,
        relationViolationCount: violations
    )
}

@discardableResult
private func v04ProbeRequireAlphaRelation(
    inputRGBA: [UInt8],
    outputRGBA: [UInt8]
) throws -> V04AlphaRelationReport {
    let report = try v04ProbeAlphaRelationReport(
        inputRGBA: inputRGBA,
        outputRGBA: outputRGBA
    )
    guard report.relationViolationCount == 0 else {
        throw IndustrialL2EastV04ProbeError.invalid(
            "v04 alpha relation failed closed with "
                + "\(report.relationViolationCount) violation(s)"
        )
    }
    return report
}

private func v04ProbeSyntheticAlphaRelationProof() throws -> [String: Any] {
    let alphaCases = [0, 1, 64, 128, 254, 255]
    let input = alphaCases.flatMap { alpha -> [UInt8] in
        if alpha == 0 {
            return [17, 22, 31, 0]
        }
        let value = UInt8(min(alpha, 192))
        return [value / 2, value / 3, value / 4, UInt8(alpha)]
    }
    let validOutput = alphaCases.flatMap { alpha -> [UInt8] in
        if alpha == 0 {
            return [255, 0, 255, 255]
        }
        return [80, 112, 144, UInt8(alpha)]
    }
    let validReport = try v04ProbeRequireAlphaRelation(
        inputRGBA: input,
        outputRGBA: validOutput
    )
    let invalidCases: [(String, [UInt8], [UInt8])] = [
        (
            "zero-alpha-rgb-not-exact-chroma",
            [17, 22, 31, 0],
            [254, 0, 255, 255]
        ),
        (
            "zero-alpha-output-not-opaque",
            [17, 22, 31, 0],
            [255, 0, 255, 0]
        ),
        (
            "foreground-alpha-changed",
            [40, 60, 80, 128],
            [80, 120, 160, 127]
        ),
        (
            "post-quantizer-alpha-mutation",
            [80, 96, 112, 254],
            [80, 112, 144, 255]
        ),
    ]
    let invalidRecords = try invalidCases.map {
        name,
        invalidInput,
        invalidOutput -> [String: Any] in
        let report = try v04ProbeAlphaRelationReport(
            inputRGBA: invalidInput,
            outputRGBA: invalidOutput
        )
        var rejected = false
        do {
            _ = try v04ProbeRequireAlphaRelation(
                inputRGBA: invalidInput,
                outputRGBA: invalidOutput
            )
        } catch {
            rejected = true
        }
        guard
            rejected,
            report.relationViolationCount > 0
        else {
            throw IndustrialL2EastV04ProbeError.invalid(
                "synthetic invalid alpha relation did not fail closed"
            )
        }
        return [
            "name": name,
            "inputRGBA": invalidInput,
            "outputRGBA": invalidOutput,
            "rejected": rejected,
            "report": report.record,
        ]
    }
    return [
        "schema": 1,
        "task": "PLAY-027",
        "type":
            "industrial-l02-east-v04-alpha-relation-synthetic-proof",
        "authorityCommit":
            "8fac58b22c7785eb277c80a7c96d133e1eaa5865",
        "contractID":
            "industrial-l02-east-v04-straight-alpha-flat-chroma-v1",
        "relation": [
            "inputAlphaEqualsZero":
                "output RGBA must equal [255,0,255,255]",
            "inputAlphaGreaterThanZero":
                "output alpha must equal input alpha",
            "foregroundAlphaMutationAllowed": false,
        ],
        "valid": [
            "inputAlphaCases": alphaCases,
            "inputRGBA": input,
            "outputRGBA": validOutput,
            "report": validReport.record,
            "passed": true,
        ],
        "invalid": invalidRecords,
        "preservedRejectedPacket": [
            "toolFreezeSHA256":
                v04ProbeRejectedToolFreezeSHA256,
            "inventorySHA256":
                v04ProbeRejectedInventorySHA256,
            "primaryFailureSHA256":
                v04ProbeRejectedFailureSHA256,
            "rejectionTextSHA256":
                v04ProbeRejectedTextSHA256,
        ],
        "passed": true,
        "capabilityPreflightInvoked": false,
        "sceneKitSnapshotInvoked": false,
        "pixelFilesCreated": 0,
        "productionSelected": false,
    ]
}

private func v04ProbePremultipliedRGBA(
    _ image: CGImage
) throws -> [UInt8] {
    try rendererCanonicalRGBA(image: image)
}

private func v04ProbeStraightAlphaImage(
    rgba: [UInt8],
    width: Int,
    height: Int
) throws -> CGImage {
    let data = Data(rgba)
    guard
        let provider = CGDataProvider(data: data as CFData),
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(
                rawValue:
                    CGImageAlphaInfo.last.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    else {
        throw IndustrialL2EastV04ProbeError.rendering(
            "could not create straight-alpha v04 flat-chroma image"
        )
    }
    return image
}

private func v04ProbeQuantizedStraightAlphaFlatChroma(
    _ preChroma: CGImage,
    sampling: EffectiveSamplingContract
) throws -> V04StraightAlphaResult {
    let premultiplied = try v04ProbePremultipliedRGBA(preChroma)
    var straight = [UInt8](repeating: 0, count: premultiplied.count)
    var foreground = 0
    var partial = 0
    var exactChroma = 0
    var opaqueNearMagenta = 0
    for pixel in stride(from: 0, to: premultiplied.count, by: 4) {
        let alpha = premultiplied[pixel + 3]
        if alpha == 0 {
            straight[pixel] = 255
            straight[pixel + 1] = 0
            straight[pixel + 2] = 255
            straight[pixel + 3] = 255
            exactChroma += 1
            continue
        }
        foreground += 1
        if alpha < 255 {
            partial += 1
        }
        for channel in 0..<3 {
            let value = Int(premultiplied[pixel + channel])
            let recovered = min(
                255,
                Int(
                    (
                        Double(value) * 255.0 / Double(alpha)
                    ).rounded()
                )
            )
            straight[pixel + channel] = UInt8(recovered)
        }
        straight[pixel + 3] = alpha
        if
            straight[pixel] >= 224,
            straight[pixel + 1] <= 32,
            straight[pixel + 2] >= 224
        {
            opaqueNearMagenta += 1
        }
    }
    guard opaqueNearMagenta == 0 else {
        throw IndustrialL2EastV04ProbeError.invalid(
            "v04 compositor rejected magenta-family foreground"
        )
    }

    let immutablePrequantized = straight
    for pixel in stride(from: 0, to: straight.count, by: 4) {
        if
            straight[pixel] == sampling.chromaBypassRGBA[0],
            straight[pixel + 1] == sampling.chromaBypassRGBA[1],
            straight[pixel + 2] == sampling.chromaBypassRGBA[2],
            straight[pixel + 3] == sampling.chromaBypassRGBA[3]
        {
            continue
        }
        for channel in 0..<3 {
            let value = Int(straight[pixel + channel])
            let quantized = min(
                255,
                (
                    (value + sampling.quantizerMidpointOffset)
                    / sampling.quantizerStep
                ) * sampling.quantizerStep
                    + sampling.quantizerStep / 2
            )
            straight[pixel + channel] = UInt8(quantized)
        }
    }

    var mutationCount = 0
    if let repair = sampling.postQuantizationCanonicalizer {
        let result = try canonicalizeIsolatedQuantizedRGBOutliers(
            sourceRGBA: straight,
            prequantizedRGBA: immutablePrequantized,
            width: preChroma.width,
            height: preChroma.height,
            contract: repair
        )
        straight = result.rgba
        mutationCount = result.mutations.count
    }
    let alphaRelation = try v04ProbeRequireAlphaRelation(
        inputRGBA: premultiplied,
        outputRGBA: straight
    )
    return V04StraightAlphaResult(
        image: try v04ProbeStraightAlphaImage(
            rgba: straight,
            width: preChroma.width,
            height: preChroma.height
        ),
        inputAlphaSHA256: alphaRelation.inputAlphaSHA256,
        outputAlphaSHA256: alphaRelation.outputAlphaSHA256,
        foregroundInputAlphaSHA256:
            alphaRelation.foregroundInputAlphaSHA256,
        foregroundOutputAlphaSHA256:
            alphaRelation.foregroundOutputAlphaSHA256,
        foregroundPixelCount: foreground,
        partialAlphaPixelCount: partial,
        exactChromaPixelCount: exactChroma,
        zeroToChromaPixelCount:
            alphaRelation.zeroToChromaPixelCount,
        alphaRelationViolationCount:
            alphaRelation.relationViolationCount,
        opaqueNearMagentaForegroundPixelCount: opaqueNearMagenta,
        postQuantizationMutationCount: mutationCount
    )
}

private func v04ProbeImageRecord(
    _ url: URL,
    image: CGImage,
    repositoryRoot: URL,
    role: String
) throws -> [String: Any] {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let retained = CGImageSourceCreateImageAtIndex(source, 0, nil),
        retained.width == image.width,
        retained.height == image.height
    else {
        throw IndustrialL2EastV04ProbeError.invalid(
            "retained v04 PNG decode or dimensions failed"
        )
    }
    let rgba = try rendererCanonicalRGBA(image: retained)
    return [
        "role": role,
        "file": rendererRelativePath(
            url,
            repositoryRoot: repositoryRoot
        ),
        "fileSHA256": try v04ProbeSHA256(url),
        "decodedRGBASHA256": v04ProbeSHA256(Data(rgba)),
        "pixels": [retained.width, retained.height],
    ]
}

@main
enum RenderIndustrialL2EastV04PrimaryProbeMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.contains("--alpha-relation-proof-output") {
            throw IndustrialL2EastV04ProbeError.invalid(
                "v05 calibration tool forbids alpha-relation proof mode"
            )
        }
        let root = URL(
            fileURLWithPath: try v04ProbeArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try v04ProbeArgument(
                "--output-root",
                in: arguments
            )
        ).standardizedFileURL
        let sourceCommit = try v04ProbeArgument(
            "--renderer-source-commit",
            in: arguments
        )
        guard
            sourceCommit == v04ProbeApprovedCommit,
            outputRoot.path == root.path + v04ProbeOutputSuffix,
            outputRoot.path.contains("/raw-calibration/diagnostics/"),
            !FileManager.default.fileExists(atPath: outputRoot.path)
        else {
            throw IndustrialL2EastV04ProbeError.invalid(
                "v05 authority, output path, or one-process boundary failed"
            )
        }
        let sceneURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialsURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/materials/industrial-l02-east-calibration-v05.json"
        )
        let alphaContractURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/prepixel/V04-ALPHA-COMPOSITOR-CONTRACT.json"
        )
        let validationReplayURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05/prepixel/PREPIXEL-VALIDATION.json"
        )
        let v03RawURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/diagnostics/east-primary/raw.png"
        )
        let v03ProvenanceURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/diagnostics/east-primary/provenance.json"
        )
        let v03HandoffURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/rejection/HANDOFF.json"
        )
        let v03RejectionURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/rejection/REJECTION.md"
        )
        let v03MetricsURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/review/RAW-PROBE-METRICS.json"
        )
        guard
            try v04ProbeSHA256(sceneURL)
                == v04ProbeDescriptorSHA256,
            try v04ProbeSHA256(materialsURL)
                == v04ProbeMaterialSHA256,
            try v04ProbeSHA256(alphaContractURL)
                == v04ProbeAlphaContractSHA256,
            try v04ProbeSHA256(validationReplayURL)
                == v04ProbeValidationReplaySHA256,
            try v04ProbeSHA256(v03RawURL)
                == v04ProbeV03RawSHA256,
            try v04ProbeSHA256(v03ProvenanceURL)
                == v04ProbeV03ProvenanceSHA256,
            try v04ProbeSHA256(v03HandoffURL)
                == v04ProbeV03HandoffSHA256,
            try v04ProbeSHA256(v03RejectionURL)
                == v04ProbeV03RejectionSHA256,
            try v04ProbeSHA256(v03MetricsURL)
                == v04ProbeV03MetricsSHA256
        else {
            throw IndustrialL2EastV04ProbeError.invalid(
                "v04 approved inputs or preserved v03 rejection drift"
            )
        }
        guard
            let descriptorObject = try JSONSerialization.jsonObject(
                with: Data(contentsOf: sceneURL)
            ) as? [String: Any],
            let samplingObject =
                descriptorObject["sampling"] as? [String: Any],
            let flatChroma =
                samplingObject["flatChromaCompositor"]
                as? [String: Any],
            flatChroma["contractID"] as? String
                == "industrial-l02-east-v04-straight-alpha-flat-chroma-v1",
            flatChroma["sha256"] as? String
                == v04ProbeAlphaContractSHA256,
            flatChroma["implementationAuthorized"] as? Bool == false,
            let replay = try JSONSerialization.jsonObject(
                with: Data(contentsOf: validationReplayURL)
            ) as? [String: Any],
            replay["canonicalGeometrySHA256"] as? String
                == v04ProbeGeometrySHA256,
            replay["passed"] as? Bool == true,
            replay["productionSelected"] as? Bool == false
        else {
            throw IndustrialL2EastV04ProbeError.invalid(
                "v04 alpha/geometry/validator binding drift"
            )
        }

        let decoder = JSONDecoder()
        let descriptor = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: sceneURL)
        )
        let materials = try v04ProbeDecodeMaterials(
            from: Data(contentsOf: materialsURL),
            repositoryRoot: root
        )
        let sampling = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        let supportedV04Patterns: Set<String> = [
            "solid-depth-cavity",
            "horizontal-section-joints",
            "procedural-vertical-corrugation",
            "procedural-formed-concrete",
            "rolled-membrane-seams",
            "large-scored-slabs",
            "muted-mullion-grid",
            "muted-warm-glazing",
            "fine-galvanized",
            "painted-steel",
            "solid-safety-paint",
        ]
        guard
            descriptor.logicalBuildingID == "industrial_l02",
            descriptor.variantID == "variant-0",
            descriptor.viewDirection == "east",
            descriptor.sourceRevision
                == "east-quality-calibration-art-proof-v05",
            descriptor.sceneGeometryID
                == "industrial-l02-east-wide-low-capable-campus-geometry-v05",
            descriptor.productionSelected == false,
            materials.productionSelected == false,
            descriptor.derivation.transform == "none",
            descriptor.derivation.mirror == false,
            descriptor.derivation.rotationDegrees == 0,
            descriptor.derivation.siblingSource == nil,
            sampling.contractID
                == "play027-deterministic-4x-no-msaa-lanczos-v3",
            sampling.sceneKitAntialiasing == "none",
            sampling.linearOversamplingFactor == 4,
            sampling.downsampleFilter == "CILanczosScaleTransform",
            sampling.downsampleScale == 0.25,
            sampling.sceneKitLightingMode == "lambert-scene-lights",
            sampling.sceneKitShadows == "current",
            Set(materials.materials.map(\.pattern))
                .isSubset(of: supportedV04Patterns)
        else {
            throw IndustrialL2EastV04ProbeError.invalid(
                "v04 frozen source/sampling boundary failed"
            )
        }

        let capability = RendererCapabilityPreflight.capture()
        guard capability.snapshot.available else {
            throw IndustrialL2EastV04ProbeError.rendering(
                "renderer-backend-unavailable: \(capability.snapshot.record)"
            )
        }
        let scene = try ContractSceneBuilder(
            materials: NativeMaterialLibrary(
                descriptor: materials,
                repositoryRoot: root
            )
        ).buildScene(from: descriptor)
        let nodeBounds = try validatedRenderedNodeBounds(
            scene,
            descriptor: descriptor
        )
        let oversampled = try NativeSourceRenderer(
            renderer: capability.renderer,
            antialiasingMode: .none,
            linearOversamplingFactor: sampling.linearOversamplingFactor
        ).renderSource(scene: scene, descriptor: descriptor)
        let preChroma = try v04ProbeDownsamplePreChroma(
            oversampled,
            descriptor: descriptor,
            sampling: sampling
        )
        let buildingAlpha = try v04ProbeRegisterAlpha(
            preChroma,
            descriptor: descriptor,
            includeAuthoredShadow: false
        )
        let registeredAlpha = try v04ProbeRegisterAlpha(
            preChroma,
            descriptor: descriptor,
            includeAuthoredShadow: true
        )
        let governed = try v04ProbeQuantizedStraightAlphaFlatChroma(
            registeredAlpha,
            sampling: sampling
        )
        let governedRaw = governed.image
        let neutral = try v04ProbeNeutralComposite(registeredAlpha)

        try FileManager.default.createDirectory(
            at: outputRoot,
            withIntermediateDirectories: true
        )
        let outputs: [(String, CGImage, String)] = [
            (
                "raw.png",
                governedRaw,
                "governed-v05-straight-alpha-flat-chroma-quantized-canonicalized-raw"
            ),
            (
                "pre-chroma-downsampled.png",
                preChroma,
                "genuine-post-lanczos-pre-chroma-unregistered-alpha"
            ),
            (
                "pre-chroma-registered-building.png",
                buildingAlpha,
                "proof-only-registered-building-alpha-without-authored-shadow"
            ),
            (
                "pre-chroma-registered-alpha.png",
                registeredAlpha,
                "proof-only-registered-building-alpha-plus-authored-shadow"
            ),
            (
                "neutral-alpha-composite.png",
                neutral,
                "proof-only-neutral-alpha-respecting-composite"
            ),
        ]
        for (file, image, _) in outputs {
            _ = try writePNG(
                image,
                to: outputRoot.appendingPathComponent(file)
            )
        }

        let binaryURL = URL(
            fileURLWithPath: CommandLine.arguments[0]
        ).standardizedFileURL
        let toolURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/RenderIndustrialL2EastV05Calibration.swift"
        )
        let fingerprintURL = root.appendingPathComponent(
            descriptor.toolchainFingerprint.file
        )
        let sourceFiles = [
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/RendererArchitecture.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/DeterministicPixelCanonicalizer.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/RendererStageDiagnostics.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/RendererCapabilityPreflight.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/OfflineSceneRenderer.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/RenderIndustrialL2EastV05Calibration.swift",
        ]
        let sourceHashes = try sourceFiles.map { file in
            [
                "file": file,
                "sha256": try v04ProbeSHA256(
                    root.appendingPathComponent(file)
                ),
            ]
        }
        let imageRecords = try outputs.map { file, image, role in
            try v04ProbeImageRecord(
                outputRoot.appendingPathComponent(file),
                image: image,
                repositoryRoot: root,
                role: role
            )
        }
        let provenance: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v05-single-primary-calibration",
            "disposition": "PENDING_RAW_REVIEW",
            "approvedPrepixelCommit": v04ProbeApprovedCommit,
            "rendererSourceCommit": sourceCommit,
            "sourceKey":
                "industrial_l02/variant-0/east/east-quality-calibration-art-proof-v05",
            "freshMetalProcessCount": 1,
            "diagnosticCLIOverrides": "none",
            "rendererCapability": capability.snapshot.record,
            "rendererBinarySHA256": try v04ProbeSHA256(binaryURL),
            "probeToolFile": rendererRelativePath(
                toolURL,
                repositoryRoot: root
            ),
            "probeToolSHA256": try v04ProbeSHA256(toolURL),
            "toolchainFingerprintFile":
                descriptor.toolchainFingerprint.file,
            "toolchainFingerprintDeclaredSHA256":
                descriptor.toolchainFingerprint.sha256,
            "toolchainFingerprintActualSHA256":
                try v04ProbeSHA256(fingerprintURL),
            "rendererSources": sourceHashes,
            "sceneDescriptorFile": rendererRelativePath(
                sceneURL,
                repositoryRoot: root
            ),
            "sceneDescriptorSHA256": try v04ProbeSHA256(sceneURL),
            "materialLibraryFile": rendererRelativePath(
                materialsURL,
                repositoryRoot: root
            ),
            "materialLibrarySHA256": try v04ProbeSHA256(materialsURL),
            "canonicalGeometrySHA256": v04ProbeGeometrySHA256,
            "alphaCompositorContractSHA256":
                try v04ProbeSHA256(alphaContractURL),
            "validatorReplaySHA256":
                try v04ProbeSHA256(validationReplayURL),
            "preservedV03": [
                "rawSHA256": try v04ProbeSHA256(v03RawURL),
                "provenanceSHA256":
                    try v04ProbeSHA256(v03ProvenanceURL),
                "handoffSHA256": try v04ProbeSHA256(v03HandoffURL),
                "rejectionSHA256":
                    try v04ProbeSHA256(v03RejectionURL),
                "metricsSHA256": try v04ProbeSHA256(v03MetricsURL),
            ],
            "sampling": [
                "contractID": sampling.contractID,
                "sceneKitAntialiasing": sampling.sceneKitAntialiasing,
                "sceneKitShadows": sampling.sceneKitShadows,
                "sceneKitLightingMode": sampling.sceneKitLightingMode,
                "linearOversamplingFactor":
                    sampling.linearOversamplingFactor,
                "downsampleFilter": sampling.downsampleFilter,
                "downsampleScale": sampling.downsampleScale,
                "quantizerID": sampling.quantizerID,
                "canonicalizerID": sampling.canonicalizerID,
            ],
            "taskOwnedFlatChromaCompositor": [
                "contractID":
                    "industrial-l02-east-v04-straight-alpha-flat-chroma-v1",
                "scope": "v05-east-calibration-only",
                "inputAlphaSHA256": governed.inputAlphaSHA256,
                "outputAlphaSHA256": governed.outputAlphaSHA256,
                "foregroundInputAlphaSHA256":
                    governed.foregroundInputAlphaSHA256,
                "foregroundOutputAlphaSHA256":
                    governed.foregroundOutputAlphaSHA256,
                "foregroundPixelCount":
                    governed.foregroundPixelCount,
                "partialAlphaPixelCount":
                    governed.partialAlphaPixelCount,
                "exactChromaPixelCount":
                    governed.exactChromaPixelCount,
                "zeroToChromaPixelCount":
                    governed.zeroToChromaPixelCount,
                "alphaRelationViolationCount":
                    governed.alphaRelationViolationCount,
                "opaqueNearMagentaForegroundPixelCount":
                    governed.opaqueNearMagentaForegroundPixelCount,
                "postQuantizationMutationCount":
                    governed.postQuantizationMutationCount,
                "crossRunState": false,
            ],
            "renderedNodeBounds": nodeBounds,
            "rawOccupancy": try validatedRawOccupancy(governedRaw),
            "outputs": imageRecords,
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
            ],
            "sharedRendererOrCompositorMutation": false,
            "productionSelected": false,
        ]
        try v04ProbeWriteJSON(
            provenance,
            to: outputRoot.appendingPathComponent("provenance.json")
        )
        print("PLAY-027 Industrial L2 East v05 calibration emitted")
        print(
            "raw \(try v04ProbeSHA256(outputRoot.appendingPathComponent("raw.png")))"
        )
        print(
            "pre-chroma \(try v04ProbeSHA256(outputRoot.appendingPathComponent("pre-chroma-downsampled.png")))"
        )
        print("freshMetalProcessCount=1 productionSelected=false")
    }
}
