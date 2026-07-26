import AppKit
import CoreGraphics
import CoreImage
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum FiniteRGBEquivalenceError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: derive-industrial-l2-v6-finite-rgb-equivalence --repository-root <path> --descriptor <json> --output-directory <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct CapturedFrame {
    let id: String
    let url: URL
    let fileSHA256: String
    let width: Int
    let height: Int
    let rgba: [UInt8]
}

private struct RGBClass {
    let members: [UInt32]
    let representative: UInt32
    let unstableObservationCounts: [UInt32: Int]
}

private struct UnstableCoordinate {
    let pixelIndex: Int
    let x: Int
    let y: Int
    let observedKeys: [UInt32]
}

private struct UnionFind {
    var parent: [UInt32: UInt32] = [:]

    mutating func add(_ value: UInt32) {
        if parent[value] == nil {
            parent[value] = value
        }
    }

    mutating func root(_ value: UInt32) -> UInt32 {
        add(value)
        let direct = parent[value]!
        if direct == value {
            return value
        }
        let resolved = root(direct)
        parent[value] = resolved
        return resolved
    }

    mutating func union(_ first: UInt32, _ second: UInt32) {
        let firstRoot = root(first)
        let secondRoot = root(second)
        if firstRoot == secondRoot {
            return
        }
        if firstRoot < secondRoot {
            parent[secondRoot] = firstRoot
        } else {
            parent[firstRoot] = secondRoot
        }
    }
}

private let expectedCaptureFiles: [(String, String, String)] = [
    (
        "run-a",
        "docs/production/evidence/PLAY-027/industrial-l02/l02/source-v06-finite-equivalence-diagnostic/diagnostics/precanonical-4x/run-a/PRE-CANONICAL-4X.png",
        "5e45e2a76337b737ae8d1e30596bf1e9661d36b2ceaa215053dc958bdb536d09"
    ),
    (
        "run-b",
        "docs/production/evidence/PLAY-027/industrial-l02/l02/source-v06-finite-equivalence-diagnostic/diagnostics/precanonical-4x/run-b/PRE-CANONICAL-4X.png",
        "4f759d95b5afcf27d867b6308134e7d71e456b942bc7b20ad99e2ecd11692f32"
    ),
    (
        "run-c",
        "docs/production/evidence/PLAY-027/industrial-l02/l02/source-v06-finite-equivalence-diagnostic/diagnostics/precanonical-4x/run-c/PRE-CANONICAL-4X.png",
        "ec9683349c39974bbe3de97daffba6885b3bac8826c7fd40aec56d3f63e1450f"
    ),
]

private let expectedDecodedHashes = [
    "cae05a4646d87b605fcb03d1a3bffe82cb364a9f7027c4a784d7d96831115666",
    "7fed5d8b3b4c0dca20cd18726ca10223617182471e3dc646567032f575fb625a",
    "6909f0626e9409359af16d75ec66d26ccea531150b7b370ef8e2bc73820088da",
]

private let expectedDescriptorSHA256 =
    "70b36a0e76581524e64d40f19e364659eed6a53d7f7ab8d8924c51ba5d0951dd"
private let expectedFrozenV06FileSHA256 =
    "f59566ff0dad474e499fbfd2d719e54fae3c432133b5e17b158ded8ebc609503"
private let expectedFrozenV06DecodedSHA256 =
    "dd0fe1b05c3c8d65a10ca2cfa8fac0bb368117acd0db750dbea160115787d249"

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        throw FiniteRGBEquivalenceError.arguments
    }
    return arguments[index + 1]
}

private func resolvedURL(_ value: String, root: URL) -> URL {
    let candidate = URL(fileURLWithPath: value)
    return (
        candidate.path.hasPrefix("/")
            ? candidate
            : root.appendingPathComponent(value)
    ).standardizedFileURL
}

private func relativePath(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func sha256(_ url: URL) throws -> String {
    try sha256(Data(contentsOf: url))
}

private func rgbKey(_ rgba: [UInt8], _ index: Int) -> UInt32 {
    UInt32(rgba[index]) << 16
        | UInt32(rgba[index + 1]) << 8
        | UInt32(rgba[index + 2])
}

private func rgbArray(_ key: UInt32) -> [Int] {
    [
        Int((key >> 16) & 0xff),
        Int((key >> 8) & 0xff),
        Int(key & 0xff),
    ]
}

private func isExactChroma(_ key: UInt32) -> Bool {
    key == 0xff00ff
}

private func decodeRGBA(
    _ url: URL
) throws -> (image: CGImage, rgba: [UInt8]) {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        )
    else {
        throw FiniteRGBEquivalenceError.invalid(
            "ImageIO could not decode \(url.path)"
        )
    }
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    try rgba.withUnsafeMutableBytes { storage in
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
            throw FiniteRGBEquivalenceError.invalid(
                "could not allocate canonical RGBA decoder"
            )
        }
        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return (image, rgba)
}

private func image(
    rgba: [UInt8],
    width: Int,
    height: Int
) throws -> CGImage {
    guard
        let provider = CGDataProvider(data: Data(rgba) as CFData),
        let result = CGImage(
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
        throw FiniteRGBEquivalenceError.invalid(
            "could not create RGBA image"
        )
    }
    return result
}

private func writeImageIOPNG(_ image: CGImage, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw FiniteRGBEquivalenceError.invalid(
            "proposal output already exists: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw FiniteRGBEquivalenceError.invalid(
            "could not create proposal PNG destination"
        )
    }
    CGImageDestinationAddImage(destination, image, [
        kCGImagePropertyPNGInterlaceType: 0,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw FiniteRGBEquivalenceError.invalid(
            "could not finalize proposal PNG"
        )
    }
}

private func writeSipsPNG(_ image: CGImage, to url: URL) throws {
    let intermediate = url.deletingLastPathComponent()
        .appendingPathComponent("." + url.lastPathComponent + ".imageio.png")
    try writeImageIOPNG(image, to: intermediate)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = [
        "-s", "format", "png",
        intermediate.path,
        "--out", url.path,
    ]
    let errorPipe = Pipe()
    process.standardOutput = Pipe()
    process.standardError = errorPipe
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        let error = String(
            data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? "unknown sips error"
        throw FiniteRGBEquivalenceError.invalid(
            "sips failed: \(error)"
        )
    }
    try FileManager.default.removeItem(at: intermediate)
}

private func drawShadow(
    descriptor: SceneDescriptor,
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

private func composite(
    frame: CGImage,
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
    let input = CIImage(cgImage: frame)
    guard let filter = CIFilter(name: sampling.downsampleFilter) else {
        throw FiniteRGBEquivalenceError.invalid(
            "CILanczosScaleTransform unavailable"
        )
    }
    filter.setValue(input, forKey: kCIInputImageKey)
    filter.setValue(
        CGFloat(sampling.downsampleScale),
        forKey: kCIInputScaleKey
    )
    filter.setValue(
        sampling.downsampleAspectRatio,
        forKey: kCIInputAspectRatioKey
    )
    guard
        let downsampled = filter.outputImage,
        let source = ciContext.createCGImage(
            downsampled,
            from: CGRect(x: 0, y: 0, width: 1536, height: 1024)
        )
    else {
        throw FiniteRGBEquivalenceError.invalid(
            "software Lanczos could not create proposal source"
        )
    }
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: 1536,
        height: 1024,
        bitsPerComponent: 8,
        bytesPerRow: 1536 * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw FiniteRGBEquivalenceError.invalid(
            "could not allocate proposal compositor"
        )
    }
    context.setFillColor(
        NSColor(
            colorSpace: .sRGB,
            components: [1, 0, 1, 1],
            count: 4
        ).cgColor
    )
    context.fill(CGRect(x: 0, y: 0, width: 1536, height: 1024))
    drawShadow(
        descriptor: descriptor,
        in: context,
        canvasHeight: 1024
    )
    context.interpolationQuality = .high
    context.draw(
        source,
        in: CGRect(
            x: descriptor.camera.postProjectionOffsetPixels[0],
            y: -descriptor.camera.postProjectionOffsetPixels[1],
            width: 1536,
            height: 1024
        )
    )
    guard let composited = context.makeImage() else {
        throw FiniteRGBEquivalenceError.invalid(
            "could not create registered proposal source"
        )
    }

    let decoded = try canonicalRGBA(composited)
    let immutablePrequantized = decoded
    var quantized = decoded
    for index in stride(from: 0, to: quantized.count, by: 4) {
        if
            quantized[index] == sampling.chromaBypassRGBA[0],
            quantized[index + 1] == sampling.chromaBypassRGBA[1],
            quantized[index + 2] == sampling.chromaBypassRGBA[2],
            quantized[index + 3] == sampling.chromaBypassRGBA[3]
        {
            continue
        }
        for channel in 0..<3 {
            let value = Int(quantized[index + channel])
            let output = min(
                255,
                (
                    (value + sampling.quantizerMidpointOffset)
                        / sampling.quantizerStep
                ) * sampling.quantizerStep
                    + sampling.quantizerStep / 2
            )
            quantized[index + channel] = UInt8(output)
        }
    }
    if let repair = sampling.postQuantizationCanonicalizer {
        quantized = try canonicalizeIsolatedQuantizedRGBOutliers(
            sourceRGBA: quantized,
            prequantizedRGBA: immutablePrequantized,
            width: 1536,
            height: 1024,
            contract: repair
        ).rgba
    }
    return try image(rgba: quantized, width: 1536, height: 1024)
}

private func canonicalRGBA(_ image: CGImage) throws -> [UInt8] {
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    try rgba.withUnsafeMutableBytes { storage in
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
            throw FiniteRGBEquivalenceError.invalid(
                "could not allocate proposal RGBA decoder"
            )
        }
        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return rgba
}

private func outputJSONObject(_ value: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw FiniteRGBEquivalenceError.invalid(
            "proposal JSON already exists: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try data.write(to: url, options: .atomic)
}

@main
enum DeriveIndustrialL2V6FiniteRGBEquivalenceMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let descriptorURL = resolvedURL(
            try argument("--descriptor", in: arguments),
            root: root
        )
        let outputDirectory = resolvedURL(
            try argument("--output-directory", in: arguments),
            root: root
        )
        let expectedOutputSuffix =
            "/docs/production/evidence/PLAY-027/industrial-l02/l02/"
            + "source-v06-finite-equivalence-diagnostic/proposal"
        guard
            outputDirectory.path.hasSuffix(expectedOutputSuffix),
            !FileManager.default.fileExists(
                atPath: outputDirectory.path
            ),
            try sha256(descriptorURL) == expectedDescriptorSHA256
        else {
            throw FiniteRGBEquivalenceError.invalid(
                "proposal output or frozen descriptor hash drifted"
            )
        }
        let descriptor = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: Data(contentsOf: descriptorURL)
        )
        let sampling = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        guard
            descriptor.logicalBuildingID == "industrial_l02",
            descriptor.variantID == "variant-0",
            descriptor.viewDirection == "east",
            descriptor.sourceRevision == "source-v06",
            descriptor.productionSelected == false,
            sampling.preLanczosCanonicalizer == nil,
            sampling.contractID
                == DescriptorSamplingResolver.schema2ContractV3ID,
            sampling.linearOversamplingFactor == 4,
            sampling.sceneKitAntialiasing == "none",
            sampling.sceneKitShadows == "disabled",
            sampling.sceneKitLightingMode == "authored-constant-v1"
        else {
            throw FiniteRGBEquivalenceError.invalid(
                "frozen source-v06 descriptor sampling drifted"
            )
        }

        var frames: [CapturedFrame] = []
        for (index, expected) in expectedCaptureFiles.enumerated() {
            let url = root.appendingPathComponent(expected.1)
            let fileHash = try sha256(url)
            guard fileHash == expected.2 else {
                throw FiniteRGBEquivalenceError.invalid(
                    "\(expected.0) file hash drifted"
                )
            }
            let decoded = try decodeRGBA(url)
            let decodedHash = sha256(Data(decoded.rgba))
            guard
                decoded.image.width == 6144,
                decoded.image.height == 4096,
                decodedHash == expectedDecodedHashes[index]
            else {
                throw FiniteRGBEquivalenceError.invalid(
                    "\(expected.0) decoded frame drifted"
                )
            }
            frames.append(
                CapturedFrame(
                    id: expected.0,
                    url: url,
                    fileSHA256: fileHash,
                    width: decoded.image.width,
                    height: decoded.image.height,
                    rgba: decoded.rgba
                )
            )
        }

        var unionFind = UnionFind()
        var unstableObservationCounts: [UInt32: Int] = [:]
        var unstableCoordinates: [UnstableCoordinate] = []
        var unstableCoordinateCount = 0
        var unstableAlphaCoordinateCount = 0
        var unstableChromaCoordinateCount = 0
        var unstableBounds = [6144, 4096, -1, -1]
        let pixelCount = 6144 * 4096
        for pixel in 0..<pixelCount {
            let index = pixel * 4
            let first = Array(frames[0].rgba[index..<(index + 4)])
            let second = Array(frames[1].rgba[index..<(index + 4)])
            let third = Array(frames[2].rgba[index..<(index + 4)])
            if first == second, first == third {
                continue
            }
            unstableCoordinateCount += 1
            let x = pixel % 6144
            let y = pixel / 6144
            unstableBounds[0] = min(unstableBounds[0], x)
            unstableBounds[1] = min(unstableBounds[1], y)
            unstableBounds[2] = max(unstableBounds[2], x + 1)
            unstableBounds[3] = max(unstableBounds[3], y + 1)
            let alphas = [first[3], second[3], third[3]]
            if alphas.contains(where: { $0 != 255 }) {
                unstableAlphaCoordinateCount += 1
                continue
            }
            let keys = [
                rgbKey(frames[0].rgba, index),
                rgbKey(frames[1].rgba, index),
                rgbKey(frames[2].rgba, index),
            ]
            if keys.contains(where: isExactChroma) {
                unstableChromaCoordinateCount += 1
                continue
            }
            let unique = Array(Set(keys)).sorted()
            guard unique.count > 1 else {
                throw FiniteRGBEquivalenceError.invalid(
                    "unstable opaque coordinate contains no RGB divergence"
                )
            }
            for key in unique {
                unionFind.add(key)
            }
            for key in unique.dropFirst() {
                unionFind.union(unique[0], key)
            }
            for key in keys {
                unstableObservationCounts[key, default: 0] += 1
            }
            unstableCoordinates.append(
                UnstableCoordinate(
                    pixelIndex: pixel,
                    x: x,
                    y: y,
                    observedKeys: unique
                )
            )
        }
        guard
            unstableCoordinateCount > 0,
            unstableAlphaCoordinateCount == 0,
            unstableChromaCoordinateCount == 0
        else {
            throw FiniteRGBEquivalenceError.invalid(
                "finite RGB proposal requires every unstable coordinate to be fully opaque and non-chroma"
            )
        }

        var grouped: [UInt32: [UInt32]] = [:]
        for value in unionFind.parent.keys.sorted() {
            let rootValue = unionFind.root(value)
            grouped[rootValue, default: []].append(value)
        }
        var classes: [RGBClass] = []
        for members in grouped.values {
            let sortedMembers = members.sorted()
            let ranked = sortedMembers.sorted {
                let lhs = unstableObservationCounts[$0, default: 0]
                let rhs = unstableObservationCounts[$1, default: 0]
                if lhs == rhs {
                    return $0 < $1
                }
                return lhs > rhs
            }
            guard let representative = ranked.first else {
                throw FiniteRGBEquivalenceError.invalid(
                    "empty equivalence class"
                )
            }
            let topCount =
                unstableObservationCounts[representative, default: 0]
            let tiedTopCount = ranked.filter {
                unstableObservationCounts[$0, default: 0] == topCount
            }.count
            guard tiedTopCount == 1 else {
                throw FiniteRGBEquivalenceError.invalid(
                    "ambiguous equivalence class has no unique observed majority"
                )
            }
            classes.append(
                RGBClass(
                    members: sortedMembers,
                    representative: representative,
                    unstableObservationCounts:
                        Dictionary(uniqueKeysWithValues: sortedMembers.map {
                            (
                                $0,
                                unstableObservationCounts[$0, default: 0]
                            )
                        })
                )
            )
        }
        classes.sort { $0.representative < $1.representative }

        var mapping: [UInt32: UInt32] = [:]
        var classIDByTuple: [UInt32: String] = [:]
        for (classIndex, rgbClass) in classes.enumerated() {
            let classID =
                "class-\(String(format: "%04d", classIndex + 1))"
            for member in rgbClass.members {
                if let existing = mapping[member],
                    existing != rgbClass.representative
                {
                    throw FiniteRGBEquivalenceError.invalid(
                        "one tuple belongs to multiple ambiguous classes"
                    )
                }
                mapping[member] = rgbClass.representative
                classIDByTuple[member] = classID
            }
        }
        guard
            !mapping.isEmpty,
            !mapping.keys.contains(where: isExactChroma),
            !mapping.values.contains(where: isExactChroma)
        else {
            throw FiniteRGBEquivalenceError.invalid(
                "finite mapping is empty or contains exact chroma"
            )
        }

        let frozenV06URL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
                + "raw/industrial_l02/variant-0/east/source-v06.png"
        )
        guard
            try sha256(frozenV06URL)
                == expectedFrozenV06FileSHA256
        else {
            throw FiniteRGBEquivalenceError.invalid(
                "frozen source-v06 comparison surface drifted"
            )
        }

        var runRecords: [[String: Any]] = []
        var mappedFinalDecodedHashes: [String] = []
        var mappedFinalFileHashes: [String] = []
        var mapped4xDecodedHashes: [String] = []
        for frame in frames {
            let replayImage = try composite(
                frame: try image(
                    rgba: frame.rgba,
                    width: frame.width,
                    height: frame.height
                ),
                descriptor: descriptor,
                sampling: sampling
            )
            let replayHash = sha256(
                Data(try canonicalRGBA(replayImage))
            )
            guard replayHash == expectedFrozenV06DecodedSHA256 else {
                throw FiniteRGBEquivalenceError.invalid(
                    "standalone unchanged replay does not reproduce frozen source-v06"
                )
            }

            var mapped = frame.rgba
            var changedPixels = 0
            var changedChannels = 0
            let mappedTupleOccurrenceCount =
                unstableCoordinates.count
            for coordinate in unstableCoordinates {
                let index = coordinate.pixelIndex * 4
                let key = rgbKey(mapped, index)
                guard
                    let representative = mapping[key],
                    let classID = classIDByTuple[key],
                    coordinate.observedKeys.contains(key),
                    coordinate.observedKeys.allSatisfy({
                        classIDByTuple[$0] == classID
                    })
                else {
                    throw FiniteRGBEquivalenceError.invalid(
                        "unknown or ambiguous tuple at frozen unstable coordinate \(coordinate.x),\(coordinate.y)"
                    )
                }
                guard
                    mapped[index + 3] == 255,
                    !isExactChroma(key)
                else {
                    throw FiniteRGBEquivalenceError.invalid(
                        "mapping encountered non-opaque or chroma tuple"
                    )
                }
                if representative == key {
                    continue
                }
                let output = rgbArray(representative).map(UInt8.init)
                var pixelChanged = false
                for channel in 0..<3 {
                    if mapped[index + channel] != output[channel] {
                        mapped[index + channel] = output[channel]
                        changedChannels += 1
                        pixelChanged = true
                    }
                }
                if pixelChanged {
                    changedPixels += 1
                }
            }
            let mappedImage = try image(
                rgba: mapped,
                width: frame.width,
                height: frame.height
            )
            let runDirectory = outputDirectory
                .appendingPathComponent("application")
                .appendingPathComponent(frame.id)
            let mapped4xURL = runDirectory
                .appendingPathComponent("MAPPED-PRE-LANCZOS-4X.png")
            try writeImageIOPNG(mappedImage, to: mapped4xURL)
            let persistedMapped = try decodeRGBA(mapped4xURL)
            guard persistedMapped.rgba == mapped else {
                throw FiniteRGBEquivalenceError.invalid(
                    "\(frame.id) mapped 4x persisted decode mismatch"
                )
            }
            let mapped4xDecodedHash = sha256(Data(mapped))
            mapped4xDecodedHashes.append(mapped4xDecodedHash)

            let candidateImage = try composite(
                frame: mappedImage,
                descriptor: descriptor,
                sampling: sampling
            )
            let finalURL = runDirectory
                .appendingPathComponent("final-sips.png")
            try writeSipsPNG(candidateImage, to: finalURL)
            let finalDecoded = try decodeRGBA(finalURL)
            let finalDecodedHash = sha256(Data(finalDecoded.rgba))
            let finalFileHash = try sha256(finalURL)
            mappedFinalDecodedHashes.append(finalDecodedHash)
            mappedFinalFileHashes.append(finalFileHash)
            runRecords.append([
                "id": frame.id,
                "inputFile": relativePath(frame.url, root: root),
                "inputFileSHA256": frame.fileSHA256,
                "inputDecodedRGBASHA256":
                    sha256(Data(frame.rgba)),
                "unchangedReplayDecodedRGBASHA256": replayHash,
                "unchangedReplayEqualsFrozenV06": true,
                "mappedTupleOccurrenceCount":
                    mappedTupleOccurrenceCount,
                "changedPixelCount": changedPixels,
                "changedChannelCount": changedChannels,
                "alphaChanged": false,
                "chromaChanged": false,
                "mapped4xFile":
                    relativePath(mapped4xURL, root: root),
                "mapped4xFileSHA256": try sha256(mapped4xURL),
                "mapped4xDecodedRGBASHA256":
                    mapped4xDecodedHash,
                "finalFile": relativePath(finalURL, root: root),
                "finalFileSHA256": finalFileHash,
                "finalDecodedRGBASHA256": finalDecodedHash,
                "productionSelected": false,
            ])
        }

        let classRecords = classes.enumerated().map {
            index,
            rgbClass -> [String: Any] in
            [
                "id": "class-\(String(format: "%04d", index + 1))",
                "representativeRGB":
                    rgbArray(rgbClass.representative),
                "members": rgbClass.members.map {
                    [
                        "rgb": rgbArray($0),
                        "unstableObservationCount":
                            rgbClass
                            .unstableObservationCounts[$0, default: 0],
                    ] as [String: Any]
                },
                "representativeRule":
                    "unique highest observation count across exact unstable coordinates; ties reject",
            ]
        }
        let coordinateRecords = unstableCoordinates.map {
            coordinate -> [String: Any] in
            let first = coordinate.observedKeys[0]
            return [
                "coordinate4x": [coordinate.x, coordinate.y],
                "classID": classIDByTuple[first]!,
                "allowedRGB": coordinate.observedKeys.map(rgbArray),
                "representativeRGB":
                    rgbArray(mapping[first]!),
                "unknownTuplePolicy": "reject",
            ]
        }
        let table: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contractID":
                "industrial-l02-source-v06-east-finite-rgb-equivalence-proposal-v1",
            "derivation": [
                "inputCount": 3,
                "pixelAlignment": "exact 6144x4096 top-left RGBA",
                "unstableCoordinateCount":
                    unstableCoordinateCount,
                "unstableBounds4x": unstableBounds,
                "unstableAlphaCoordinateCount":
                    unstableAlphaCoordinateCount,
                "unstableChromaCoordinateCount":
                    unstableChromaCoordinateCount,
                "derivationUsesCrossRunEvidence": true,
            ],
            "application": [
                "singleFramePureTransform": true,
                "crossRunState": "none",
                "channels": "rgb-only",
                "requiresAlpha": 255,
                "exactChromaPolicy": "bypass-byte-exact",
                "unknownTuplePolicy":
                    "reject at a frozen unstable coordinate; outside the coordinate table leave byte-exact",
                "ambiguousClassPolicy": "reject",
                "inputHashDriftPolicy": "reject",
                "coordinateScope":
                    "exact finite list of proven unstable 4x coordinates",
                "alphaWrites": false,
                "geometryWrites": false,
                "registrationWrites": false,
            ],
            "classCount": classes.count,
            "tupleCount": mapping.count,
            "classes": classRecords,
            "coordinates": coordinateRecords,
            "productionSelected": false,
        ]
        let tableURL = outputDirectory.appendingPathComponent(
            "FINITE-RGB-EQUIVALENCE-TABLE.json"
        )
        try outputJSONObject(table, to: tableURL)

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "status": "proposal-only-not-authorized-for-validation-or-production",
            "descriptorSHA256": expectedDescriptorSHA256,
            "frozenV06FileSHA256":
                expectedFrozenV06FileSHA256,
            "frozenV06DecodedRGBASHA256":
                expectedFrozenV06DecodedSHA256,
            "tableFile": relativePath(tableURL, root: root),
            "tableFileSHA256": try sha256(tableURL),
            "classCount": classes.count,
            "tupleCount": mapping.count,
            "unstableCoordinateCount":
                unstableCoordinateCount,
            "unstableBounds4x": unstableBounds,
            "allUnstableCoordinatesOpaque": true,
            "allUnstableCoordinatesNonChroma": true,
            "unchangedReplayCount": runRecords.count,
            "unchangedReplayAllEqualFrozenV06": true,
            "applicationRuns": runRecords,
            "mapped4xUniqueDecodedIdentityCount":
                Set(mapped4xDecodedHashes).count,
            "mappedFinalUniqueDecodedIdentityCount":
                Set(mappedFinalDecodedHashes).count,
            "mappedFinalUniqueFileIdentityCount":
                Set(mappedFinalFileHashes).count,
            "normalizationPerformed": false,
            "productionSelected": false,
        ]
        try outputJSONObject(
            report,
            to: outputDirectory.appendingPathComponent(
                "DERIVATION-AND-APPLICATION.json"
            )
        )
        print(
            "PASS finite equivalence proposal derived: "
                + "unstableCoordinates=\(unstableCoordinateCount) "
                + "classes=\(classes.count) tuples=\(mapping.count) "
                + "mapped4xUnique=\(Set(mapped4xDecodedHashes).count) "
                + "mappedFinalUnique=\(Set(mappedFinalDecodedHashes).count)"
        )
    }
}
