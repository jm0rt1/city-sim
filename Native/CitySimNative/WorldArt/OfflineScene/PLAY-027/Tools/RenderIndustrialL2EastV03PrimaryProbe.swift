import AppKit
import CoreGraphics
import CoreImage
import CryptoKit
import Foundation
import SceneKit

enum IndustrialL2EastV03ProbeError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)
    case rendering(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: render-industrial-l2-east-v03-primary-probe --repository-root <path> --output-root <path> --renderer-source-commit <sha>"
        case let .invalid(message), let .rendering(message):
            return message
        }
    }
}

private let v03ProbeApprovedCommit =
    "aaa431e867a635d78f70e422caa756efe71d07e8"
private let v03ProbeDescriptorSHA256 =
    "d32c2aaf03cebf53f3821515b19ab03fd86e759687fed9b4bf68eda14e1b65ca"
private let v03ProbeMaterialSHA256 =
    "94069509093c122d4cb2383bd648757561f6561f78b8345c6222b5354f3f18f6"
private let v03ProbeValidationSHA256 =
    "f73a0a077e058845a03ed8cf273babebbab11fec6bd87dce34444ccd20d42a47"
private let v03ProbeV02RejectionSHA256 =
    "7ca9a9dcdbf0552872baecb311eb5459c54d4c186e65ae8f3fa66015020cf4f5"
private let v03ProbeV02AttemptSHA256 =
    "919ba04ee5a76d3f628ee2bb64732a7125c2b0986a8fe8c42aedbcf5ce239b2f"
private let v03ProbeStyleAnchorFile =
    "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png"
private let v03ProbeStyleAnchorSHA256 =
    "b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425"
private let v03ProbeFamilyAnchorFile =
    "Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/industrial_l01/source-v01.png"
private let v03ProbeFamilyAnchorSHA256 =
    "22dbf75f35d66f86b108c8e5ab9d7b3f753df74489d0b9e9877fc81ba86a2515"
private let v03ProbeOutputSuffix =
    "/docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/raw-probe/diagnostics/east-primary"

private func v03ProbeArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2EastV03ProbeError.arguments
    }
    return arguments[index + 1]
}

private func v03ProbeSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func v03ProbeSHA256(_ url: URL) throws -> String {
    v03ProbeSHA256(try Data(contentsOf: url))
}

private func v03ProbeWriteJSON(
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

private func v03ProbeDecodeMaterials(
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
        try v03ProbeSHA256(
            repositoryRoot.appendingPathComponent(
                v03ProbeStyleAnchorFile
            )
        ) == v03ProbeStyleAnchorSHA256,
        try v03ProbeSHA256(
            repositoryRoot.appendingPathComponent(
                v03ProbeFamilyAnchorFile
            )
        ) == v03ProbeFamilyAnchorSHA256
    else {
        throw IndustrialL2EastV03ProbeError.invalid(
            "material decoder compatibility or anchor hash drift"
        )
    }
    object["styleAnchorFile"] = v03ProbeStyleAnchorFile
    object["styleAnchorSHA256"] = v03ProbeStyleAnchorSHA256
    object["familyAnchorFile"] = v03ProbeFamilyAnchorFile
    object["familyAnchorSHA256"] = v03ProbeFamilyAnchorSHA256
    return try JSONDecoder().decode(
        MaterialLibraryDescriptor.self,
        from: JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    )
}

private func v03ProbeContext(
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
        throw IndustrialL2EastV03ProbeError.rendering(
            "could not allocate alpha proof context"
        )
    }
    return context
}

private func v03ProbeDownsamplePreChroma(
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
        throw IndustrialL2EastV03ProbeError.rendering(
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
        throw IndustrialL2EastV03ProbeError.rendering(
            "pre-chroma software Lanczos downsample failed"
        )
    }
    return image
}

private func v03ProbeDrawAuthoredShadow(
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

private func v03ProbeRegisterAlpha(
    _ source: CGImage,
    descriptor: SceneDescriptor,
    includeAuthoredShadow: Bool
) throws -> CGImage {
    let width = descriptor.camera.renderViewportPixels[0]
    let height = descriptor.camera.renderViewportPixels[1]
    let context = try v03ProbeContext(width: width, height: height)
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    if includeAuthoredShadow {
        v03ProbeDrawAuthoredShadow(
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
        throw IndustrialL2EastV03ProbeError.rendering(
            "could not create registered alpha proof"
        )
    }
    return image
}

private func v03ProbeNeutralComposite(
    _ alphaSource: CGImage
) throws -> CGImage {
    let context = try v03ProbeContext(
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
        throw IndustrialL2EastV03ProbeError.rendering(
            "could not create neutral alpha composite"
        )
    }
    return image
}

private func v03ProbeImageRecord(
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
        "fileSHA256": try v03ProbeSHA256(url),
        "decodedRGBASHA256": v03ProbeSHA256(Data(rgba)),
        "pixels": [image.width, image.height],
    ]
}

@main
enum RenderIndustrialL2EastV03PrimaryProbeMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try v03ProbeArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try v03ProbeArgument(
                "--output-root",
                in: arguments
            )
        ).standardizedFileURL
        let sourceCommit = try v03ProbeArgument(
            "--renderer-source-commit",
            in: arguments
        )
        guard
            sourceCommit == v03ProbeApprovedCommit,
            outputRoot.path == root.path + v03ProbeOutputSuffix,
            outputRoot.path.contains("/raw-probe/diagnostics/"),
            !FileManager.default.fileExists(atPath: outputRoot.path)
        else {
            throw IndustrialL2EastV03ProbeError.invalid(
                "v03 authority, output path, or one-process boundary failed"
            )
        }
        let sceneURL = root.appendingPathComponent(
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
        let v02AttemptURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v02/raw-probe/rejection/PRIMARY-ATTEMPT.json"
        )
        guard
            try v03ProbeSHA256(sceneURL)
                == v03ProbeDescriptorSHA256,
            try v03ProbeSHA256(materialsURL)
                == v03ProbeMaterialSHA256,
            try v03ProbeSHA256(validationURL)
                == v03ProbeValidationSHA256,
            try v03ProbeSHA256(v02RejectionURL)
                == v03ProbeV02RejectionSHA256,
            try v03ProbeSHA256(v02AttemptURL)
                == v03ProbeV02AttemptSHA256
        else {
            throw IndustrialL2EastV03ProbeError.invalid(
                "approved descriptor/material/validation or v02 rejection drift"
            )
        }

        let decoder = JSONDecoder()
        let descriptor = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: sceneURL)
        )
        let materials = try v03ProbeDecodeMaterials(
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
                == "projection-silhouette-reset-art-proof-v03",
            descriptor.sceneGeometryID
                == "industrial-l02-east-wide-low-campus-geometry-v03",
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
            throw IndustrialL2EastV03ProbeError.invalid(
                "v03 frozen source/sampling boundary failed"
            )
        }

        let capability = RendererCapabilityPreflight.capture()
        guard capability.snapshot.available else {
            throw IndustrialL2EastV03ProbeError.rendering(
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
        let governedRaw = try NativeSourceCompositor(
            sampling: sampling
        ).compositeRegisteredSource(
            renderedImage: oversampled,
            descriptor: descriptor
        )
        let preChroma = try v03ProbeDownsamplePreChroma(
            oversampled,
            descriptor: descriptor,
            sampling: sampling
        )
        let buildingAlpha = try v03ProbeRegisterAlpha(
            preChroma,
            descriptor: descriptor,
            includeAuthoredShadow: false
        )
        let registeredAlpha = try v03ProbeRegisterAlpha(
            preChroma,
            descriptor: descriptor,
            includeAuthoredShadow: true
        )
        let neutral = try v03ProbeNeutralComposite(registeredAlpha)

        try FileManager.default.createDirectory(
            at: outputRoot,
            withIntermediateDirectories: true
        )
        let outputs: [(String, CGImage, String)] = [
            (
                "raw.png",
                governedRaw,
                "governed-flat-chroma-raw-existing-compositor-quantizer-canonicalizer"
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
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/RenderIndustrialL2EastV03PrimaryProbe.swift"
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
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/RenderIndustrialL2EastV03PrimaryProbe.swift",
        ]
        let sourceHashes = try sourceFiles.map { file in
            [
                "file": file,
                "sha256": try v03ProbeSHA256(
                    root.appendingPathComponent(file)
                ),
            ]
        }
        let imageRecords = try outputs.map { file, image, role in
            try v03ProbeImageRecord(
                outputRoot.appendingPathComponent(file),
                image: image,
                repositoryRoot: root,
                role: role
            )
        }
        let provenance: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v03-single-primary-raw-probe",
            "disposition": "PENDING_RAW_REVIEW",
            "approvedPrepixelCommit": v03ProbeApprovedCommit,
            "rendererSourceCommit": sourceCommit,
            "sourceKey":
                "industrial_l02/variant-0/east/projection-silhouette-reset-art-proof-v03",
            "freshMetalProcessCount": 1,
            "diagnosticCLIOverrides": "none",
            "rendererCapability": capability.snapshot.record,
            "rendererBinarySHA256": try v03ProbeSHA256(binaryURL),
            "probeToolFile": rendererRelativePath(
                toolURL,
                repositoryRoot: root
            ),
            "probeToolSHA256": try v03ProbeSHA256(toolURL),
            "toolchainFingerprintFile":
                descriptor.toolchainFingerprint.file,
            "toolchainFingerprintDeclaredSHA256":
                descriptor.toolchainFingerprint.sha256,
            "toolchainFingerprintActualSHA256":
                try v03ProbeSHA256(fingerprintURL),
            "rendererSources": sourceHashes,
            "sceneDescriptorFile": rendererRelativePath(
                sceneURL,
                repositoryRoot: root
            ),
            "sceneDescriptorSHA256": try v03ProbeSHA256(sceneURL),
            "materialLibraryFile": rendererRelativePath(
                materialsURL,
                repositoryRoot: root
            ),
            "materialLibrarySHA256": try v03ProbeSHA256(materialsURL),
            "prepixelValidationSHA256":
                try v03ProbeSHA256(validationURL),
            "preservedV02RejectionSHA256":
                try v03ProbeSHA256(v02RejectionURL),
            "preservedV02AttemptSHA256":
                try v03ProbeSHA256(v02AttemptURL),
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
            "governedRawMutationFromFrozenPipeline": false,
            "productionSelected": false,
        ]
        try v03ProbeWriteJSON(
            provenance,
            to: outputRoot.appendingPathComponent("provenance.json")
        )
        print("PLAY-027 Industrial L2 East v03 primary emitted")
        print(
            "raw \(try v03ProbeSHA256(outputRoot.appendingPathComponent("raw.png")))"
        )
        print(
            "pre-chroma \(try v03ProbeSHA256(outputRoot.appendingPathComponent("pre-chroma-downsampled.png")))"
        )
        print("freshMetalProcessCount=1 productionSelected=false")
    }
}
