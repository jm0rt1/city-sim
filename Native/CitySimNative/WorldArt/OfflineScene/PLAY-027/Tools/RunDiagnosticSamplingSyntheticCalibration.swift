import CoreGraphics
import CoreImage
import CryptoKit
import Foundation

enum SyntheticCalibrationError: Error {
    case failed(String)
}

func calibrationSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func calibrationImage(
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
        throw SyntheticCalibrationError.failed(
            "could not create calibration image"
        )
    }
    return image
}

func syntheticCalibrationRGBA(width: Int, height: Int) -> [UInt8] {
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    func set(
        _ x: Int,
        _ y: Int,
        _ red: Int,
        _ green: Int,
        _ blue: Int,
        _ alpha: Int = 255
    ) {
        guard x >= 0, x < width, y >= 0, y < height else {
            return
        }
        let index = (y * width + x) * 4
        rgba[index] = UInt8(red * alpha / 255)
        rgba[index + 1] = UInt8(green * alpha / 255)
        rgba[index + 2] = UInt8(blue * alpha / 255)
        rgba[index + 3] = UInt8(alpha)
    }

    for y in 0..<height {
        for x in 0..<width {
            if x < 96 && y < 96 {
                set(x, y, 255, 0, 255)
            }
        }
    }
    let grayValues = [16, 48, 80, 112, 144, 176, 208, 240]
    for (patch, value) in grayValues.enumerated() {
        let startX = 128 + patch * 96
        for y in 48..<176 {
            for x in startX..<(startX + 72) {
                set(x, y, value, value, value)
            }
        }
    }
    set(300, 250, 255, 255, 255)
    for y in 220..<540 {
        set(380, y, 240, 176, 48)
        set(420, y, 48, 144, 208)
        set(421, y, 48, 144, 208)
    }
    for x in 500..<900 {
        let y = 220 + (x - 500) / 2
        set(x, y, 240, 240, 240)
        set(x, y + 1, 112, 144, 176)
    }
    let alphaValues = [0, 1, 8, 9, 64, 128, 254, 255]
    for (column, alpha) in alphaValues.enumerated() {
        let startX = 96 + column * 96
        for y in 576..<704 {
            for x in startX..<(startX + 64) {
                set(x, y, 208, 112, 48, alpha)
            }
        }
    }
    let centerX = 760
    let centerY = 430
    for delta in -180...180 {
        let half = 180 - abs(delta)
        set(centerX + delta, centerY - half / 2, 176, 208, 240)
        set(centerX + delta, centerY + half / 2, 176, 208, 240)
    }
    for offset in -16...16 {
        set(centerX + 180 + offset, centerY, 255, 176, 16)
        set(centerX + 180, centerY + offset, 255, 176, 16)
    }
    return rgba
}

func quantizedCalibrationRGBA(
    _ image: CGImage,
    sampling: EffectiveSamplingContract
) throws -> [UInt8] {
    var rgba = try rendererCanonicalRGBA(image: image)
    for pixel in stride(from: 0, to: rgba.count, by: 4) {
        if
            rgba[pixel] == UInt8(sampling.chromaBypassRGBA[0]),
            rgba[pixel + 1] == UInt8(sampling.chromaBypassRGBA[1]),
            rgba[pixel + 2] == UInt8(sampling.chromaBypassRGBA[2]),
            rgba[pixel + 3] == UInt8(sampling.chromaBypassRGBA[3])
        {
            continue
        }
        for channel in 0..<3 {
            let value = Int(rgba[pixel + channel])
            rgba[pixel + channel] = UInt8(
                min(
                    255,
                    ((value + sampling.quantizerMidpointOffset)
                        / sampling.quantizerStep)
                        * sampling.quantizerStep
                        + sampling.quantizerStep / 2
                )
            )
        }
    }
    return rgba
}

func referenceLegacyDownsample(
    _ image: CGImage,
    width: Int,
    height: Int
) throws -> CGImage {
    let context = CIContext(options: [
        .useSoftwareRenderer: true,
        .cacheIntermediates: false,
        .workingColorSpace: CGColorSpace(
            name: CGColorSpace.extendedSRGB
        )!,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    ])
    guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
        throw SyntheticCalibrationError.failed("legacy filter unavailable")
    }
    filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
    filter.setValue(0.5, forKey: kCIInputScaleKey)
    filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
    guard
        let output = filter.outputImage,
        let result = context.createCGImage(
            output,
            from: CGRect(x: 0, y: 0, width: width, height: height)
        )
    else {
        throw SyntheticCalibrationError.failed(
            "legacy reference downsample failed"
        )
    }
    return result
}

@main
enum RunDiagnosticSamplingSyntheticCalibrationMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try rendererArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputDirectory = URL(
            fileURLWithPath: try rendererArgument(
                "--output-directory",
                in: arguments
            )
        ).standardizedFileURL
        let finalURL = outputDirectory.appendingPathComponent("FINAL.png")
        let reportURL = outputDirectory.appendingPathComponent("REPORT.json")
        let descriptorData = try JSONSerialization.data(
            withJSONObject: [
                "schema": 1,
                "type": "synthetic-sampling-calibration",
                "inputPixels": [1024, 768],
                "outputPixels": [256, 192],
                "patterns": [
                    "impulse",
                    "one-pixel-line",
                    "two-pixel-sub-feature-line",
                    "diagonal-edge",
                    "alpha-0-1-8-9-64-128-254-255",
                    "exact-chroma-boundary",
                    "grayscale-value-patches",
                    "footprint-diamond-and-socket-marker",
                ],
            ],
            options: [.sortedKeys]
        )
        let descriptorSHA = calibrationSHA256(descriptorData)
        let resolution = try DiagnosticSamplingPipelineContract.resolve(
            requestedContractID:
                DiagnosticSamplingPipelineContract.contractID,
            repositoryRoot: root,
            outputURL: finalURL,
            recordURL: reportURL,
            descriptorSHA256: descriptorSHA,
            rendererSourceCommit: "67646d5",
            productionSelected: false,
            explicitAntialiasing: nil,
            explicitSceneShadows: nil,
            explicitMaterialLighting: nil,
            diagnosticContractID: nil,
            diagnosticStageContractID: nil,
            descriptorSampling:
                DescriptorSamplingResolver.legacySchema1
        )
        guard let resolution else {
            throw SyntheticCalibrationError.failed(
                "diagnostic sampling resolution missing"
            )
        }
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let width = 1024
        let height = 768
        let inputRGBA = syntheticCalibrationRGBA(
            width: width,
            height: height
        )
        let input = try calibrationImage(
            rgba: inputRGBA,
            width: width,
            height: height
        )
        let inputURL = outputDirectory.appendingPathComponent("INPUT-4X.png")
        _ = try writePNG(input, to: inputURL)
        let downsampled = try FrozenSoftwareLanczos.downsample(
            input,
            sampling: resolution.effectiveSampling,
            outputWidth: 256,
            outputHeight: 192
        )
        let lanczosURL = outputDirectory.appendingPathComponent("LANCZOS.png")
        _ = try writePNG(downsampled, to: lanczosURL)
        let quantizedRGBA = try quantizedCalibrationRGBA(
            downsampled,
            sampling: resolution.effectiveSampling
        )
        let finalImage = try calibrationImage(
            rgba: quantizedRGBA,
            width: 256,
            height: 192
        )
        _ = try writePNG(finalImage, to: finalURL)

        let legacyInputRGBA = syntheticCalibrationRGBA(
            width: 512,
            height: 384
        )
        let legacyInput = try calibrationImage(
            rgba: legacyInputRGBA,
            width: 512,
            height: 384
        )
        let helperLegacy = try FrozenSoftwareLanczos.downsample(
            legacyInput,
            sampling: DescriptorSamplingResolver.legacySchema1,
            outputWidth: 256,
            outputHeight: 192
        )
        let referenceLegacy = try referenceLegacyDownsample(
            legacyInput,
            width: 256,
            height: 192
        )
        let helperLegacyRGBA = try rendererCanonicalRGBA(
            image: helperLegacy
        )
        let referenceLegacyRGBA = try rendererCanonicalRGBA(
            image: referenceLegacy
        )
        guard helperLegacyRGBA == referenceLegacyRGBA else {
            throw SyntheticCalibrationError.failed(
                "default legacy Lanczos fixture replay changed"
            )
        }

        let toolURL = URL(
            fileURLWithPath: CommandLine.arguments[0]
        ).standardizedFileURL
        let sourcePaths = [
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/DiagnosticSamplingPipeline.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/OfflineSceneRenderer.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/RendererArchitecture.swift",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/RunDiagnosticSamplingSyntheticCalibration.swift",
        ]
        let sourceHashes = try sourcePaths.map { path in
            [
                "file": path,
                "sha256": try rendererSHA256(
                    root.appendingPathComponent(path)
                ),
            ]
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "diagnostic-sampling-synthetic-calibration",
            "pipeline": resolution.provenance,
            "syntheticDescriptorSHA256": descriptorSHA,
            "inputFileSHA256": try rendererSHA256(inputURL),
            "inputDecodedRGBASHA256":
                calibrationSHA256(Data(inputRGBA)),
            "lanczosFileSHA256": try rendererSHA256(lanczosURL),
            "lanczosDecodedRGBASHA256":
                calibrationSHA256(
                    Data(try rendererCanonicalRGBA(image: downsampled))
                ),
            "finalFileSHA256": try rendererSHA256(finalURL),
            "finalDecodedRGBASHA256":
                calibrationSHA256(Data(quantizedRGBA)),
            "defaultRegression": [
                "contractID":
                    DescriptorSamplingResolver.legacySchema1.contractID,
                "reference": "pre-change inline software Core Image Lanczos",
                "helperDecodedRGBASHA256":
                    calibrationSHA256(Data(helperLegacyRGBA)),
                "referenceDecodedRGBASHA256":
                    calibrationSHA256(Data(referenceLegacyRGBA)),
                "pixelByteIdentical": true,
                "defaultOptionResolution": "nil-no-op",
            ],
            "alphaRampValues": [0, 1, 8, 9, 64, 128, 254, 255],
            "patternCount": 8,
            "crossRunState": "none",
            "sceneKitOrMetalInvoked": false,
            "productionSelected": false,
            "binarySHA256": try rendererSHA256(toolURL),
            "sourceHashes": sourceHashes,
            "hostToolchain": [
                "operatingSystem":
                    ProcessInfo.processInfo.operatingSystemVersionString,
                "coreImageContext": "software",
                "workingColorSpace": "extended-srgb",
                "outputColorSpace": "srgb",
                "cacheIntermediates": false,
            ],
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        try data.write(to: reportURL, options: .atomic)
        print(
            "PASS \(try rendererSHA256(finalURL)) "
                + "\(try rendererSHA256(reportURL))"
        )
    }
}
