import AppKit
import CoreGraphics
import CoreImage
import CryptoKit
import Foundation
import SceneKit

enum IndustrialL2EastV02ProbeError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)
    case rendering(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: render-industrial-l2-east-v02-primary-probe --repository-root <path> --output-root <path> --renderer-source-commit <sha>"
        case let .invalid(message), let .rendering(message):
            return message
        }
    }
}

private let approvedCommit =
    "857d39bcdc1cbf799368623f3749a1c66897da94"
private let approvedDescriptorSHA256 =
    "01ee10ef87c7a23d8fab151091f7237fc0a12563694cea3080f63a25d4e90775"
private let approvedMaterialSHA256 =
    "94069509093c122d4cb2383bd648757561f6561f78b8345c6222b5354f3f18f6"
private let approvedValidationSHA256 =
    "db7f6c67a7d858e9d2177386d84b6ec8f43ebceb5d5d858bd30553cb7d9d4269"
private let approvedStyleAnchorFile =
    "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png"
private let approvedStyleAnchorSHA256 =
    "b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425"
private let approvedFamilyAnchorFile =
    "Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/industrial_l01/source-v01.png"
private let approvedFamilyAnchorSHA256 =
    "22dbf75f35d66f86b108c8e5ab9d7b3f753df74489d0b9e9877fc81ba86a2515"
private let expectedOutputSuffix =
    "/docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v02/raw-probe/diagnostics/east-primary"

private func probeArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2EastV02ProbeError.arguments
    }
    return arguments[index + 1]
}

private func probeSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func probeSHA256(_ url: URL) throws -> String {
    probeSHA256(try Data(contentsOf: url))
}

private func probeWriteJSON(
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

private func probeDecodeFrozenMaterialLibrary(
    from data: Data,
    repositoryRoot: URL
) throws -> MaterialLibraryDescriptor {
    guard
        var object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any],
        object["styleAnchorFile"] == nil,
        object["styleAnchorSHA256"] == nil,
        object["familyAnchorFile"] == nil,
        object["familyAnchorSHA256"] == nil,
        try probeSHA256(
            repositoryRoot.appendingPathComponent(
                approvedStyleAnchorFile
            )
        ) == approvedStyleAnchorSHA256,
        try probeSHA256(
            repositoryRoot.appendingPathComponent(
                approvedFamilyAnchorFile
            )
        ) == approvedFamilyAnchorSHA256
    else {
        throw IndustrialL2EastV02ProbeError.invalid(
            "frozen material library compatibility or anchor hash drift"
        )
    }
    object["styleAnchorFile"] = approvedStyleAnchorFile
    object["styleAnchorSHA256"] = approvedStyleAnchorSHA256
    object["familyAnchorFile"] = approvedFamilyAnchorFile
    object["familyAnchorSHA256"] = approvedFamilyAnchorSHA256
    return try JSONDecoder().decode(
        MaterialLibraryDescriptor.self,
        from: JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    )
}

private func probeDownsampledPreChroma(
    _ oversampled: CGImage,
    descriptor: SceneDescriptor,
    sampling: EffectiveSamplingContract
) throws -> CGImage {
    let ciContext = CIContext(options: [
        .useSoftwareRenderer: sampling.ciUseSoftwareRenderer,
        .cacheIntermediates: sampling.ciCacheIntermediates,
        .workingColorSpace: CGColorSpace(
            name: CGColorSpace.extendedSRGB
        )!,
        .outputColorSpace: CGColorSpace(
            name: CGColorSpace.sRGB
        )!,
    ])
    guard let filter = CIFilter(name: sampling.downsampleFilter) else {
        throw IndustrialL2EastV02ProbeError.rendering(
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
    guard let downsampled = filter.outputImage else {
        throw IndustrialL2EastV02ProbeError.rendering(
            "pre-chroma downsample failed"
        )
    }
    let width = descriptor.camera.renderViewportPixels[0]
    let height = descriptor.camera.renderViewportPixels[1]
    guard let image = ciContext.createCGImage(
        downsampled,
        from: CGRect(x: 0, y: 0, width: width, height: height)
    ) else {
        throw IndustrialL2EastV02ProbeError.rendering(
            "pre-chroma downsample could not create image"
        )
    }
    return image
}

private func probeContext(
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
        throw IndustrialL2EastV02ProbeError.rendering(
            "could not allocate proof-only alpha context"
        )
    }
    return context
}

private func probeDrawAuthoredShadow(
    _ descriptor: SceneDescriptor,
    in context: CGContext,
    canvasHeight: CGFloat
) {
    context.saveGState()
    context.translateBy(x: 0, y: canvasHeight)
    context.scaleBy(x: 1, y: -1)
    let path = CGMutablePath()
    let projected = descriptor.registration.contactPolygonWorld.map {
        worldPoint in
        CGPoint(
            x: 768 + (worldPoint[0] - worldPoint[1]) * 256 / 72,
            y: 768 + (worldPoint[0] + worldPoint[1]) * 128 / 72
        )
    }
    let shadowScale = 28.0
    let offset = CGPoint(
        x: descriptor.light.shadowVectorSource[0] * shadowScale,
        y: descriptor.light.shadowVectorSource[1] * shadowScale
    )
    path.move(
        to: CGPoint(
            x: projected[0].x + offset.x,
            y: projected[0].y + offset.y
        )
    )
    for point in projected.dropFirst() {
        path.addLine(
            to: CGPoint(x: point.x + offset.x, y: point.y + offset.y)
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

private func probeRegisteredPreChroma(
    source: CGImage,
    descriptor: SceneDescriptor,
    includeAuthoredShadow: Bool
) throws -> CGImage {
    let width = descriptor.camera.renderViewportPixels[0]
    let height = descriptor.camera.renderViewportPixels[1]
    let context = try probeContext(width: width, height: height)
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    if includeAuthoredShadow {
        probeDrawAuthoredShadow(
            descriptor,
            in: context,
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
        throw IndustrialL2EastV02ProbeError.rendering(
            "could not create registered pre-chroma proof"
        )
    }
    return image
}

private func probeNeutralComposite(
    _ source: CGImage
) throws -> CGImage {
    let context = try probeContext(
        width: source.width,
        height: source.height
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
        CGRect(x: 0, y: 0, width: source.width, height: source.height)
    )
    context.draw(
        source,
        in: CGRect(x: 0, y: 0, width: source.width, height: source.height)
    )
    guard let image = context.makeImage() else {
        throw IndustrialL2EastV02ProbeError.rendering(
            "could not create neutral proof composite"
        )
    }
    return image
}

private func probeImageRecord(
    _ url: URL,
    image: CGImage,
    repositoryRoot: URL,
    role: String
) throws -> [String: Any] {
    let rgba = try rendererCanonicalRGBA(image: image)
    return [
        "role": role,
        "file": rendererRelativePath(
            url,
            repositoryRoot: repositoryRoot
        ),
        "fileSHA256": try probeSHA256(url),
        "decodedRGBASHA256": probeSHA256(Data(rgba)),
        "pixels": [image.width, image.height],
    ]
}

@main
enum RenderIndustrialL2EastV02PrimaryProbeMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try probeArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try probeArgument(
                "--output-root",
                in: arguments
            )
        ).standardizedFileURL
        let sourceCommit = try probeArgument(
            "--renderer-source-commit",
            in: arguments
        )
        guard
            sourceCommit == approvedCommit,
            outputRoot.path == root.path + expectedOutputSuffix,
            outputRoot.path.contains("/diagnostics/"),
            !FileManager.default.fileExists(atPath: outputRoot.path)
        else {
            throw IndustrialL2EastV02ProbeError.invalid(
                "probe authority, output path, or one-attempt boundary failed"
            )
        }

        let sceneURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialsURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/materials/industrial-l02-projection-silhouette-reset-v02.json"
        )
        let validationURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v02/prepixel/PREPIXEL-VALIDATION.json"
        )
        guard
            try probeSHA256(sceneURL) == approvedDescriptorSHA256,
            try probeSHA256(materialsURL) == approvedMaterialSHA256,
            try probeSHA256(validationURL) == approvedValidationSHA256
        else {
            throw IndustrialL2EastV02ProbeError.invalid(
                "approved pre-pixel descriptor/material/validation hash drift"
            )
        }

        let decoder = JSONDecoder()
        let descriptor = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: sceneURL)
        )
        let materials = try probeDecodeFrozenMaterialLibrary(
            from: Data(contentsOf: materialsURL),
            repositoryRoot: root
        )
        let sampling = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        guard
            descriptor.logicalBuildingID == "industrial_l02",
            descriptor.variantID == "variant-0",
            descriptor.viewDirection == "east",
            descriptor.sourceRevision
                == "projection-silhouette-reset-art-proof-v02",
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
            sampling.sceneKitShadows == "current"
        else {
            throw IndustrialL2EastV02ProbeError.invalid(
                "frozen descriptor sampling/source boundary failed"
            )
        }

        let capability = RendererCapabilityPreflight.capture()
        guard capability.snapshot.available else {
            throw IndustrialL2EastV02ProbeError.rendering(
                "renderer-backend-unavailable: \(capability.snapshot.record)"
            )
        }
        let materialLibrary = NativeMaterialLibrary(
            descriptor: materials,
            repositoryRoot: root
        )
        let scene = try ContractSceneBuilder(
            materials: materialLibrary
        ).buildScene(from: descriptor)
        let renderedNodeBounds = try validatedRenderedNodeBounds(
            scene,
            descriptor: descriptor
        )
        let oversampled = try NativeSourceRenderer(
            renderer: capability.renderer,
            antialiasingMode: .none,
            linearOversamplingFactor: sampling.linearOversamplingFactor
        ).renderSource(scene: scene, descriptor: descriptor)

        let compositor = NativeSourceCompositor(sampling: sampling)
        let governedRaw = try compositor.compositeRegisteredSource(
            renderedImage: oversampled,
            descriptor: descriptor
        )
        let preChroma = try probeDownsampledPreChroma(
            oversampled,
            descriptor: descriptor,
            sampling: sampling
        )
        let registeredBuilding = try probeRegisteredPreChroma(
            source: preChroma,
            descriptor: descriptor,
            includeAuthoredShadow: false
        )
        let registeredAlpha = try probeRegisteredPreChroma(
            source: preChroma,
            descriptor: descriptor,
            includeAuthoredShadow: true
        )
        let neutral = try probeNeutralComposite(registeredAlpha)

        try FileManager.default.createDirectory(
            at: outputRoot,
            withIntermediateDirectories: true
        )
        let rawURL = outputRoot.appendingPathComponent("raw.png")
        let preChromaURL = outputRoot.appendingPathComponent(
            "pre-chroma-downsampled.png"
        )
        let registeredBuildingURL = outputRoot.appendingPathComponent(
            "pre-chroma-registered-building.png"
        )
        let registeredAlphaURL = outputRoot.appendingPathComponent(
            "pre-chroma-registered-alpha.png"
        )
        let neutralURL = outputRoot.appendingPathComponent(
            "neutral-alpha-composite.png"
        )
        _ = try writePNG(governedRaw, to: rawURL)
        _ = try writePNG(preChroma, to: preChromaURL)
        _ = try writePNG(registeredBuilding, to: registeredBuildingURL)
        _ = try writePNG(registeredAlpha, to: registeredAlphaURL)
        _ = try writePNG(neutral, to: neutralURL)

        let binaryURL = URL(
            fileURLWithPath: CommandLine.arguments[0]
        ).standardizedFileURL
        let toolURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/RenderIndustrialL2EastV02PrimaryProbe.swift"
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
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/IndustrialL2V5MSAAIsolationContract.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/IndustrialL2V5EastStageCaptureContract.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/IndustrialL2V5EastSceneKitLanczosContract.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/IndustrialL2V6EastSceneKitCaptureContract.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/IndustrialL2V7EastPreLanczosCaptureContract.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/IndustrialL2V6EastFullFrameCaptureContract.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/IndustrialL2V8EastFiniteEquivalenceContract.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/PreLanczosFrameCanonicalizer.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/OfflineSceneRenderer.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/RenderIndustrialL2EastV02PrimaryProbe.swift",
        ]
        let sourceHashes = try sourceFiles.map { file in
            [
                "file": file,
                "sha256": try probeSHA256(
                    root.appendingPathComponent(file)
                ),
            ]
        }
        let rawOccupancy = try validatedRawOccupancy(governedRaw)
        let record: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v02-single-primary-raw-probe",
            "disposition": "PENDING_INDEPENDENT_REVIEW",
            "approvedPrepixelCommit": approvedCommit,
            "rendererSourceCommit": sourceCommit,
            "sourceKey":
                "industrial_l02/variant-0/east/projection-silhouette-reset-art-proof-v02",
            "freshMetalProcessCount": 1,
            "diagnosticCLIOverrides": "none",
            "rendererCapability": capability.snapshot.record,
            "rendererBinarySHA256": try probeSHA256(binaryURL),
            "probeToolFile": rendererRelativePath(
                toolURL,
                repositoryRoot: root
            ),
            "probeToolSHA256": try probeSHA256(toolURL),
            "toolchainFingerprintFile":
                descriptor.toolchainFingerprint.file,
            "toolchainFingerprintDeclaredSHA256":
                descriptor.toolchainFingerprint.sha256,
            "toolchainFingerprintActualSHA256":
                try probeSHA256(fingerprintURL),
            "rendererSources": sourceHashes,
            "sceneDescriptorFile": rendererRelativePath(
                sceneURL,
                repositoryRoot: root
            ),
            "sceneDescriptorSHA256": try probeSHA256(sceneURL),
            "materialLibraryFile": rendererRelativePath(
                materialsURL,
                repositoryRoot: root
            ),
            "materialLibrarySHA256": try probeSHA256(materialsURL),
            "materialDecoderCompatibility": [
                "frozenMaterialLibraryBytesChanged": false,
                "renderedMaterialDefinitionsChanged": false,
                "reason":
                    "approved v02 material JSON predates four required decoder-only anchor metadata fields",
                "injectedMetadataOnly": [
                    "styleAnchorFile": approvedStyleAnchorFile,
                    "styleAnchorSHA256":
                        approvedStyleAnchorSHA256,
                    "familyAnchorFile": approvedFamilyAnchorFile,
                    "familyAnchorSHA256":
                        approvedFamilyAnchorSHA256,
                ],
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
                "downsampleAspectRatio":
                    sampling.downsampleAspectRatio,
                "quantizerID": sampling.quantizerID,
                "canonicalizerID": sampling.canonicalizerID,
            ],
            "renderedNodeBounds": renderedNodeBounds,
            "rawOccupancy": rawOccupancy,
            "outputs": [
                try probeImageRecord(
                    rawURL,
                    image: governedRaw,
                    repositoryRoot: root,
                    role:
                        "governed-flat-chroma-raw-existing-compositor-quantizer-canonicalizer"
                ),
                try probeImageRecord(
                    preChromaURL,
                    image: preChroma,
                    repositoryRoot: root,
                    role:
                        "genuine-post-lanczos-pre-chroma-unregistered-alpha-intermediate"
                ),
                try probeImageRecord(
                    registeredBuildingURL,
                    image: registeredBuilding,
                    repositoryRoot: root,
                    role:
                        "proof-only-registered-building-alpha-without-authored-shadow"
                ),
                try probeImageRecord(
                    registeredAlphaURL,
                    image: registeredAlpha,
                    repositoryRoot: root,
                    role:
                        "proof-only-registered-pre-chroma-alpha-plus-authored-shadow"
                ),
                try probeImageRecord(
                    neutralURL,
                    image: neutral,
                    repositoryRoot: root,
                    role:
                        "proof-only-neutral-alpha-respecting-composite"
                ),
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
            ],
            "governedRawMutationFromFrozenPipeline": false,
            "productionSelected": false,
        ]
        try probeWriteJSON(
            record,
            to: outputRoot.appendingPathComponent("provenance.json")
        )
        print("PLAY-027 Industrial L2 East v02 primary emitted")
        print("raw \(try probeSHA256(rawURL))")
        print("pre-chroma \(try probeSHA256(preChromaURL))")
        print("freshMetalProcessCount=1 productionSelected=false")
    }
}
