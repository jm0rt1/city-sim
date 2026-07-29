import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import Metal
import SceneKit
import UniformTypeIdentifiers

enum IndustrialL2V06SemanticError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

private struct SemanticTarget {
    let id: String
    let rgba: [UInt8]
}

private struct PixelBounds {
    var minimumX: Int
    var minimumY: Int
    var maximumX: Int
    var maximumY: Int

    var width: Int { maximumX - minimumX + 1 }
    var height: Int { maximumY - minimumY + 1 }
}

private struct SemanticComponent {
    let pixels: [Int]
    let bounds: PixelBounds
}

private struct SemanticProfile {
    let revision: String
    let artDirectory: String
    let reportType: String
    let descriptorHashes: [String: String]
}

private let semanticV06DescriptorHashes = [
    "north":
        "6a51cf80436a5e0626ce869e9178c80844e979758419b8c509da0a651af4b390",
    "west":
        "2ef1b01ddb5eee3eda3f0e859d7e9bec5572dddce53a6f6502c202504b345fd5",
]
private let semanticV07DescriptorHashes = [
    "north":
        "361a2ce80066d4493c2d746f42808f516ec0e5d9abe177791d1f75e4205e2357",
    "west":
        "7fe7f851a036461820b4a98bb29da6e57176c9794b991bee6be80a153fa74244",
]
private let semanticMaterialsSHA256 =
    "6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb"
private let semanticNativeWidth = 432
private let semanticNativeHeight = 288

private func semanticSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func semanticSHA256(_ url: URL) throws -> String {
    semanticSHA256(try Data(contentsOf: url))
}

private func semanticArgument(
    _ name: String,
    arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2V06SemanticError.invalid(
            "missing \(name)"
        )
    }
    return arguments[index + 1]
}

private func semanticProfile(
    arguments: [String]
) throws -> SemanticProfile {
    guard
        let revisionIndex = arguments.firstIndex(
            of: "--descriptor-revision"
        )
    else {
        return SemanticProfile(
            revision: "v06",
            artDirectory:
                "industrial-l02-directional-family-v06",
            reportType:
                "industrial-l02-directional-family-v06-semantic-visibility-gate",
            descriptorHashes: semanticV06DescriptorHashes
        )
    }
    guard
        revisionIndex + 1 < arguments.count,
        arguments[revisionIndex + 1] == "v07"
    else {
        throw IndustrialL2V06SemanticError.invalid(
            "unsupported semantic descriptor revision"
        )
    }
    return SemanticProfile(
        revision: "v07",
        artDirectory:
            "industrial-l02-directional-family-v07",
        reportType:
            "industrial-l02-directional-family-v07-semantic-visibility-gate",
        descriptorHashes: semanticV07DescriptorHashes
    )
}

private func semanticRGBA(_ image: CGImage) throws -> [UInt8] {
    var bytes = [UInt8](
        repeating: 0,
        count: image.width * image.height * 4
    )
    let rendered = bytes.withUnsafeMutableBytes { storage -> Bool in
        guard let context = CGContext(
            data: storage.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
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
        throw IndustrialL2V06SemanticError.invalid(
            "could not canonicalize semantic render"
        )
    }
    return bytes
}

private func semanticWritePNG(_ image: CGImage, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2V06SemanticError.invalid(
            "output must be absent: \(url.path)"
        )
    }
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw IndustrialL2V06SemanticError.invalid(
            "could not create PNG destination"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL2V06SemanticError.invalid(
            "could not finalize semantic PNG"
        )
    }
}

private func semanticMaterial(_ rgba: [UInt8]) -> SCNMaterial {
    let material = SCNMaterial()
    material.lightingModel = .constant
    material.diffuse.contents = NSColor(
        srgbRed: CGFloat(rgba[0]) / 255,
        green: CGFloat(rgba[1]) / 255,
        blue: CGFloat(rgba[2]) / 255,
        alpha: 1
    )
    material.isDoubleSided = false
    material.writesToDepthBuffer = true
    material.readsFromDepthBuffer = true
    return material
}

private func semanticTargets(_ direction: String) -> [SemanticTarget] {
    let prefix = direction == "north" ? "n" : "w"
    return [
        SemanticTarget(
            id: "\(prefix)-dock-door-a",
            rgba: [248, 56, 56, 255]
        ),
        SemanticTarget(
            id: "\(prefix)-dock-door-b",
            rgba: [56, 232, 72, 255]
        ),
        SemanticTarget(
            id: "\(prefix)-dock-door-c",
            rgba: [64, 96, 248, 255]
        ),
        SemanticTarget(
            id: "\(prefix)-staff-door",
            rgba: [248, 232, 56, 255]
        ),
    ]
}

private func semanticColorScene(
    _ scene: SCNScene,
    targets: [SemanticTarget]
) throws {
    let targetMap = Dictionary(
        uniqueKeysWithValues: targets.map { ($0.id, $0.rgba) }
    )
    let occluder = semanticMaterial([52, 54, 60, 255])
    var found: Set<String> = []
    scene.rootNode.enumerateChildNodes { node, _ in
        if node.light != nil {
            node.removeFromParentNode()
            return
        }
        guard let geometry = node.geometry else {
            return
        }
        if
            let name = node.name,
            let targetColor = targetMap[name]
        {
            geometry.materials = geometry.materials.map { _ in
                semanticMaterial(targetColor)
            }
            found.insert(name)
        } else {
            geometry.materials = geometry.materials.map { _ in
                occluder.copy() as! SCNMaterial
            }
        }
        node.castsShadow = false
    }
    let expected = Set(targets.map(\.id))
    guard found == expected else {
        throw IndustrialL2V06SemanticError.invalid(
            "semantic target nodes missing: \(expected.subtracting(found))"
        )
    }
    scene.background.contents = NSColor.clear
}

private func semanticLabel(
    red: Int,
    green: Int,
    blue: Int,
    alpha: Int,
    targets: [SemanticTarget]
) -> Int? {
    guard alpha > 0 else {
        return nil
    }
    var bestIndex: Int?
    var bestDistance = Int.max
    for (index, target) in targets.enumerated() {
        let dr = red - Int(target.rgba[0])
        let dg = green - Int(target.rgba[1])
        let db = blue - Int(target.rgba[2])
        let distance = dr * dr + dg * dg + db * db
        if distance < bestDistance {
            bestDistance = distance
            bestIndex = index
        }
    }
    return bestDistance <= 48 * 48 ? bestIndex : nil
}

private func semanticNativeLabels(
    sourceRGBA: [UInt8],
    sourceWidth: Int,
    sourceHeight: Int,
    targets: [SemanticTarget]
) -> ([Int], [UInt8]) {
    var labels = [Int](
        repeating: -1,
        count: semanticNativeWidth * semanticNativeHeight
    )
    var maskRGBA = [UInt8](
        repeating: 0,
        count: semanticNativeWidth * semanticNativeHeight * 4
    )
    for y in 0..<semanticNativeHeight {
        let sourceY = min(
            sourceHeight - 1,
            ((y * 32) + 16) / 9
        )
        for x in 0..<semanticNativeWidth {
            let sourceX = min(
                sourceWidth - 1,
                ((x * 32) + 16) / 9
            )
            let sourceOffset =
                (sourceY * sourceWidth + sourceX) * 4
            let alpha = Int(sourceRGBA[sourceOffset + 3])
            let label = semanticLabel(
                red: Int(sourceRGBA[sourceOffset]),
                green: Int(sourceRGBA[sourceOffset + 1]),
                blue: Int(sourceRGBA[sourceOffset + 2]),
                alpha: alpha,
                targets: targets
            )
            let nativeIndex = y * semanticNativeWidth + x
            let outputOffset = nativeIndex * 4
            if let label {
                labels[nativeIndex] = label
                maskRGBA[outputOffset] = targets[label].rgba[0]
                maskRGBA[outputOffset + 1] = targets[label].rgba[1]
                maskRGBA[outputOffset + 2] = targets[label].rgba[2]
                maskRGBA[outputOffset + 3] = 255
            } else if alpha > 0 {
                maskRGBA[outputOffset] = 70
                maskRGBA[outputOffset + 1] = 72
                maskRGBA[outputOffset + 2] = 78
                maskRGBA[outputOffset + 3] = 255
            } else {
                maskRGBA[outputOffset] = 230
                maskRGBA[outputOffset + 1] = 231
                maskRGBA[outputOffset + 2] = 227
                maskRGBA[outputOffset + 3] = 255
            }
        }
    }
    return (labels, maskRGBA)
}

private func semanticLargestComponent(
    label: Int,
    labels: [Int]
) -> SemanticComponent? {
    var visited = [Bool](repeating: false, count: labels.count)
    var largest: SemanticComponent?
    for start in labels.indices where labels[start] == label && !visited[start] {
        var queue = [start]
        visited[start] = true
        var cursor = 0
        var pixels: [Int] = []
        var bounds = PixelBounds(
            minimumX: semanticNativeWidth,
            minimumY: semanticNativeHeight,
            maximumX: -1,
            maximumY: -1
        )
        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1
            pixels.append(index)
            let x = index % semanticNativeWidth
            let y = index / semanticNativeWidth
            bounds.minimumX = min(bounds.minimumX, x)
            bounds.minimumY = min(bounds.minimumY, y)
            bounds.maximumX = max(bounds.maximumX, x)
            bounds.maximumY = max(bounds.maximumY, y)
            for neighbor in [
                x > 0 ? index - 1 : -1,
                x + 1 < semanticNativeWidth ? index + 1 : -1,
                y > 0 ? index - semanticNativeWidth : -1,
                y + 1 < semanticNativeHeight
                    ? index + semanticNativeWidth : -1,
            ] where neighbor >= 0
                && labels[neighbor] == label
                && !visited[neighbor]
            {
                visited[neighbor] = true
                queue.append(neighbor)
            }
        }
        let component = SemanticComponent(
            pixels: pixels,
            bounds: bounds
        )
        if largest == nil || pixels.count > largest!.pixels.count {
            largest = component
        }
    }
    return largest
}

private func semanticBoundsGap(
    _ first: PixelBounds,
    _ second: PixelBounds
) -> Int {
    let horizontal = max(
        0,
        max(
            second.minimumX - first.maximumX - 1,
            first.minimumX - second.maximumX - 1
        )
    )
    let vertical = max(
        0,
        max(
            second.minimumY - first.maximumY - 1,
            first.minimumY - second.maximumY - 1
        )
    )
    return max(horizontal, vertical)
}

private func semanticImage(
    rgba: [UInt8],
    width: Int,
    height: Int
) throws -> CGImage {
    guard
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
        throw IndustrialL2V06SemanticError.invalid(
            "could not create semantic image"
        )
    }
    return image
}

private func semanticLabeledMask(
    image: CGImage,
    direction: String
) throws -> CGImage {
    let headerHeight = 42
    guard let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height + headerHeight,
        bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw IndustrialL2V06SemanticError.invalid(
            "could not allocate labeled mask"
        )
    }
    context.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 1).cgColor)
    context.fill(
        CGRect(
            x: 0,
            y: 0,
            width: image.width,
            height: image.height + headerHeight
        )
    )
    context.interpolationQuality = .none
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(
        cgContext: context,
        flipped: false
    )
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold),
        .foregroundColor: NSColor.white,
    ]
    let legend =
        "\(direction.uppercased())  RED=dock A  GREEN=dock B  BLUE=dock C  YELLOW=staff"
    legend.draw(
        at: CGPoint(x: 8, y: image.height + 13),
        withAttributes: attributes
    )
    NSGraphicsContext.restoreGraphicsState()
    guard let result = context.makeImage() else {
        throw IndustrialL2V06SemanticError.invalid(
            "could not capture labeled mask"
        )
    }
    return result
}

@main
enum ValidateIndustrialL2DirectionalFamilyV06SemanticVisibilityMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let profile = try semanticProfile(arguments: arguments)
        let root = URL(
            fileURLWithPath: try semanticArgument(
                "--repository-root",
                arguments: arguments
            )
        ).standardizedFileURL
        let outputDirectory = URL(
            fileURLWithPath: try semanticArgument(
                "--output-directory",
                arguments: arguments
            )
        ).standardizedFileURL
        guard
            outputDirectory.path.contains(
                "/docs/production/evidence/PLAY-027/"
            ),
            outputDirectory.path.contains("/diagnostics/"),
            !FileManager.default.fileExists(
                atPath: outputDirectory.path
            )
        else {
            throw IndustrialL2V06SemanticError.invalid(
                "semantic output must be an absent PLAY-027 diagnostics path"
            )
        }
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let materialsURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/materials/industrial-l02-east-calibration-v05.json"
        )
        guard
            try semanticSHA256(materialsURL)
                == semanticMaterialsSHA256
        else {
            throw IndustrialL2V06SemanticError.invalid(
                "material library drift"
            )
        }
        let decoder = JSONDecoder()
        let materialsDescriptor = try decoder.decode(
            MaterialLibraryDescriptor.self,
            from: Data(contentsOf: materialsURL)
        )
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw IndustrialL2V06SemanticError.invalid(
                "renderer-backend-unavailable"
            )
        }
        var directionRecords: [[String: Any]] = []
        var allPassed = true
        for direction in ["north", "west"] {
            let descriptorURL = root.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/\(profile.artDirectory)/scenes/industrial_l02/variant-0/\(direction)/scene.json"
            )
            guard
                try semanticSHA256(descriptorURL)
                    == profile.descriptorHashes[direction]
            else {
                throw IndustrialL2V06SemanticError.invalid(
                    "\(direction) descriptor drift"
                )
            }
            let descriptor = try decoder.decode(
                SceneDescriptor.self,
                from: Data(contentsOf: descriptorURL)
            )
            let library = NativeMaterialLibrary(
                descriptor: materialsDescriptor,
                repositoryRoot: root
            )
            let scene = try ContractSceneBuilder(
                materials: library
            ).buildScene(from: descriptor)
            let targets = semanticTargets(direction)
            try semanticColorScene(scene, targets: targets)
            let renderer = SCNRenderer(device: device, options: nil)
            let rendered = try NativeSourceRenderer(
                renderer: renderer,
                antialiasingMode: .none,
                linearOversamplingFactor: 1
            ).renderSource(scene: scene, descriptor: descriptor)
            let sourceURL = outputDirectory.appendingPathComponent(
                "\(direction)-semantic-source.png"
            )
            try semanticWritePNG(rendered, to: sourceURL)
            let sourceRGBA = try semanticRGBA(rendered)
            let (labels, maskRGBA) = semanticNativeLabels(
                sourceRGBA: sourceRGBA,
                sourceWidth: rendered.width,
                sourceHeight: rendered.height,
                targets: targets
            )
            let maskImage = try semanticImage(
                rgba: maskRGBA,
                width: semanticNativeWidth,
                height: semanticNativeHeight
            )
            let labeled = try semanticLabeledMask(
                image: maskImage,
                direction: direction
            )
            let maskURL = outputDirectory.appendingPathComponent(
                "\(direction)-semantic-mask-native2x-labeled.png"
            )
            try semanticWritePNG(labeled, to: maskURL)

            var targetRecords: [[String: Any]] = []
            var components: [SemanticComponent] = []
            var targetsPassed = true
            for (index, target) in targets.enumerated() {
                guard let component = semanticLargestComponent(
                    label: index,
                    labels: labels
                ) else {
                    targetRecords.append([
                        "id": target.id,
                        "visible": false,
                        "passed": false,
                    ])
                    targetsPassed = false
                    continue
                }
                components.append(component)
                let passed =
                    component.bounds.width >= 6
                    && component.bounds.height >= 8
                targetsPassed = targetsPassed && passed
                targetRecords.append([
                    "id": target.id,
                    "semanticRGBA": target.rgba,
                    "largestContiguousVisiblePixelCount":
                        component.pixels.count,
                    "native2xBounds": [
                        component.bounds.minimumX,
                        component.bounds.minimumY,
                        component.bounds.maximumX + 1,
                        component.bounds.maximumY + 1,
                    ],
                    "native2xBoundsPixels": [
                        component.bounds.width,
                        component.bounds.height,
                    ],
                    "minimumBoundsPixels": [6, 8],
                    "passed": passed,
                ])
            }
            var separations: [[String: Any]] = []
            var separationPassed = components.count == 4
            if components.count == 4 {
                for first in 0..<3 {
                    for second in (first + 1)..<3 {
                        let gap = semanticBoundsGap(
                            components[first].bounds,
                            components[second].bounds
                        )
                        let passed = gap >= 2
                        separationPassed =
                            separationPassed && passed
                        separations.append([
                            "first": targets[first].id,
                            "second": targets[second].id,
                            "boundsGapPixels": gap,
                            "minimumPixels": 2,
                            "passed": passed,
                        ])
                    }
                }
            }
            let directionPassed =
                targetsPassed && separationPassed
            allPassed = allPassed && directionPassed
            directionRecords.append([
                "direction": direction,
                "descriptorSHA256":
                    profile.descriptorHashes[direction]!,
                "sourceSemanticPNG":
                    sourceURL.path.replacingOccurrences(
                        of: root.path + "/",
                        with: ""
                    ),
                "sourceSemanticPNGFileSHA256":
                    try semanticSHA256(sourceURL),
                "sourceSemanticDecodedRGBASHA256":
                    semanticSHA256(Data(sourceRGBA)),
                "native2xMask":
                    maskURL.path.replacingOccurrences(
                        of: root.path + "/",
                        with: ""
                    ),
                "native2xMaskSHA256":
                    try semanticSHA256(maskURL),
                "targets": targetRecords,
                "dockSiblingSeparations": separations,
                "targetVisibilityPassed": targetsPassed,
                "dockSiblingSeparationPassed": separationPassed,
                "passed": directionPassed,
            ])
        }
        let executableURL = URL(
            fileURLWithPath: CommandLine.arguments[0]
        ).standardizedFileURL
        var report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": profile.reportType,
            "classification":
                "diagnostic-only pre-pixel semantic visibility; no source authority",
            "renderer":
                "production ContractSceneBuilder plus production orthographic camera; diagnostic constant colors; SceneKit MSAA none",
            "native2xMapping":
                "deterministic center sample at rational scale 9/32 from 1536x1024 to 432x288",
            "toolFile":
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/ValidateIndustrialL2DirectionalFamilyV06SemanticVisibility.swift",
            "toolBinarySHA256":
                try semanticSHA256(executableURL),
            "materialLibrarySHA256":
                semanticMaterialsSHA256,
            "directions": directionRecords,
            "metalDiagnosticProcessCount": 1,
            "sourceRawProcessCount": 0,
            "normalizerProcessCount": 0,
            "southProcessCount": 0,
            "sourceAuthority": false,
            "productionSelected": false,
            "passed": allPassed,
        ]
        if profile.revision != "v06" {
            report["descriptorRevision"] = profile.revision
        }
        let reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var terminated = reportData
        terminated.append(0x0a)
        try terminated.write(
            to: outputDirectory.appendingPathComponent("SEMANTIC-VISIBILITY.json"),
            options: .atomic
        )
        if !allPassed {
            throw IndustrialL2V06SemanticError.invalid(
                "semantic visibility gate failed"
            )
        }
    }
}
