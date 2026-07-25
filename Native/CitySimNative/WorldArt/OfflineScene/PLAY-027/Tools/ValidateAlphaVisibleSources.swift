import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum AlphaVisibleValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-alpha-visible-sources --repository-root <path> --output <json> --sheet <png> --source <id=png> [--source <id=png> ...] --reference <id=png> [--reference <id=png> ...]"
        case let .invalid(message):
            return message
        }
    }
}

struct AlphaVisibleInspection {
    let id: String
    let url: URL
    let fileSHA256: String
    let image: CGImage
    let rgba: Data
    let rgbOccupiedPixelCount: Int
    let alphaVisibleOccupiedPixelCount: Int
    let hiddenNonMagentaPixelCount: Int
    let rgbBounds: [Int]
    let alphaVisibleBounds: [Int]
    let flatOpaqueChromaCorners: Bool
}

func requiredArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw AlphaVisibleValidationError.arguments
    }
    return arguments[index + 1]
}

func repeatedArgument(
    _ name: String,
    in arguments: [String]
) throws -> [String] {
    var values: [String] = []
    for (index, argument) in arguments.enumerated()
    where argument == name && index + 1 < arguments.count {
        values.append(arguments[index + 1])
    }
    guard !values.isEmpty else {
        throw AlphaVisibleValidationError.arguments
    }
    return values
}

func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func relativePath(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path + "/"
    guard url.path.hasPrefix(prefix) else {
        return url.path
    }
    return String(url.path.dropFirst(prefix.count))
}

func resolvedSource(
    _ value: String,
    repositoryRoot: URL
) throws -> (String, URL) {
    let parts = value.split(
        separator: "=",
        maxSplits: 1
    ).map(String.init)
    guard parts.count == 2 else {
        throw AlphaVisibleValidationError.arguments
    }
    let candidate = URL(fileURLWithPath: parts[1])
    let url = candidate.path.hasPrefix("/")
        ? candidate
        : repositoryRoot.appendingPathComponent(parts[1])
    return (parts[0], url.standardizedFileURL)
}

func occupiedBounds(
    width: Int,
    height: Int,
    includes: (Int, Int) -> Bool
) -> [Int] {
    var minimumX = width
    var minimumY = height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<height {
        for x in 0..<width where includes(x, y) {
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    guard maximumX >= 0 else {
        return []
    }
    return [minimumX, minimumY, maximumX + 1, maximumY + 1]
}

func inspectExactRetainedPNG(
    id: String,
    url: URL
) throws -> AlphaVisibleInspection {
    let fileData = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary),
        image.bitsPerComponent == 8,
        image.bitsPerPixel == 32,
        image.bytesPerRow >= image.width * 4,
        image.alphaInfo == .last || image.alphaInfo == .premultipliedLast,
        let providerData = image.dataProvider?.data
    else {
        throw AlphaVisibleValidationError.invalid(
            "standard ImageIO RGBA decode failed for \(url.path)"
        )
    }
    let rgba = providerData as Data
    guard rgba.count >= image.bytesPerRow * image.height else {
        throw AlphaVisibleValidationError.invalid(
            "decoded RGBA storage is incomplete for \(url.path)"
        )
    }

    func pixel(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let index = y * image.bytesPerRow + x * 4
        return (
            rgba[index],
            rgba[index + 1],
            rgba[index + 2],
            rgba[index + 3]
        )
    }
    func isChroma(_ value: (UInt8, UInt8, UInt8, UInt8)) -> Bool {
        value.0 == 255 && value.1 == 0 && value.2 == 255
    }

    var rgbOccupiedPixelCount = 0
    var alphaVisibleOccupiedPixelCount = 0
    var hiddenNonMagentaPixelCount = 0
    for y in 0..<image.height {
        for x in 0..<image.width {
            let value = pixel(x, y)
            if !isChroma(value) {
                rgbOccupiedPixelCount += 1
                if value.3 > 0 {
                    alphaVisibleOccupiedPixelCount += 1
                } else {
                    hiddenNonMagentaPixelCount += 1
                }
            }
        }
    }
    let rgbBounds = occupiedBounds(
        width: image.width,
        height: image.height
    ) { x, y in
        !isChroma(pixel(x, y))
    }
    let alphaVisibleBounds = occupiedBounds(
        width: image.width,
        height: image.height
    ) { x, y in
        let value = pixel(x, y)
        return value.3 > 0 && !isChroma(value)
    }
    let corners = [
        pixel(0, 0),
        pixel(image.width - 1, 0),
        pixel(0, image.height - 1),
        pixel(image.width - 1, image.height - 1),
    ]
    let flatOpaqueChromaCorners = corners.allSatisfy {
        isChroma($0) && $0.3 == 255
    }
    return AlphaVisibleInspection(
        id: id,
        url: url,
        fileSHA256: digest(fileData),
        image: image,
        rgba: rgba,
        rgbOccupiedPixelCount: rgbOccupiedPixelCount,
        alphaVisibleOccupiedPixelCount: alphaVisibleOccupiedPixelCount,
        hiddenNonMagentaPixelCount: hiddenNonMagentaPixelCount,
        rgbBounds: rgbBounds,
        alphaVisibleBounds: alphaVisibleBounds,
        flatOpaqueChromaCorners: flatOpaqueChromaCorners
    )
}

func dimension(_ bounds: [Int], axis: Int) -> Int {
    guard bounds.count == 4 else {
        return 0
    }
    return bounds[axis + 2] - bounds[axis]
}

func maskedImage(
    _ inspection: AlphaVisibleInspection
) throws -> CGImage {
    var bytes = [UInt8](inspection.rgba)
    let width = inspection.image.width
    let height = inspection.image.height
    let bytesPerRow = inspection.image.bytesPerRow
    for y in 0..<height {
        for x in 0..<width {
            let index = y * bytesPerRow + x * 4
            let chroma =
                bytes[index] == 255
                && bytes[index + 1] == 0
                && bytes[index + 2] == 255
            if chroma {
                bytes[index] = 0
                bytes[index + 1] = 0
                bytes[index + 2] = 0
                bytes[index + 3] = 0
            }
        }
    }
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    return try bytes.withUnsafeMutableBytes { storage in
        guard
            let context = CGContext(
                data: storage.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo:
                    CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            let image = context.makeImage()
        else {
            throw AlphaVisibleValidationError.invalid(
                "could not create chroma-masked image"
            )
        }
        return image
    }
}

func writeOccupiedContactSheet(
    inspections: [AlphaVisibleInspection],
    to url: URL
) throws -> [[String: Any]] {
    let panelWidth = 460
    let panelHeight = 320
    let gap = 20
    let margin = 24
    let sheetWidth = margin * 2 + panelWidth * 2 + gap
    let sheetHeight = margin * 2 + panelHeight * 2 + gap
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: sheetWidth,
        height: sheetHeight,
        bitsPerComponent: 8,
        bytesPerRow: sheetWidth * 4,
        space: colorSpace,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw AlphaVisibleValidationError.invalid(
            "could not allocate occupied-pixel contact sheet"
        )
    }
    context.setFillColor(
        CGColor(
            colorSpace: colorSpace,
            components: [0.18, 0.19, 0.21, 1]
        )!
    )
    context.fill(
        CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight)
    )
    context.interpolationQuality = .none

    var panels: [[String: Any]] = []
    for (index, inspection) in inspections.enumerated() {
        let bounds = inspection.alphaVisibleBounds
        guard bounds.count == 4 else {
            throw AlphaVisibleValidationError.invalid(
                "empty alpha-visible bounds for \(inspection.id)"
            )
        }
        let padding = 8
        let cropX = max(0, bounds[0] - padding)
        let cropY = max(0, bounds[1] - padding)
        let cropMaxX = min(inspection.image.width, bounds[2] + padding)
        let cropMaxY = min(inspection.image.height, bounds[3] + padding)
        let cropRect = CGRect(
            x: cropX,
            y: cropY,
            width: cropMaxX - cropX,
            height: cropMaxY - cropY
        )
        guard
            let cropped = try maskedImage(inspection).cropping(to: cropRect)
        else {
            throw AlphaVisibleValidationError.invalid(
                "could not crop \(inspection.id)"
            )
        }
        let column = index % 2
        let row = index / 2
        let panelX = margin + column * (panelWidth + gap)
        let panelY =
            sheetHeight - margin - (row + 1) * panelHeight - row * gap
        context.setFillColor(
            CGColor(
                colorSpace: colorSpace,
                components: [0.28, 0.30, 0.33, 1]
            )!
        )
        context.fill(
            CGRect(
                x: panelX,
                y: panelY,
                width: panelWidth,
                height: panelHeight
            )
        )
        let drawX = panelX + (panelWidth - cropped.width) / 2
        let drawY = panelY + (panelHeight - cropped.height) / 2
        context.draw(
            cropped,
            in: CGRect(
                x: drawX,
                y: drawY,
                width: cropped.width,
                height: cropped.height
            )
        )
        panels.append([
            "id": inspection.id,
            "row": row,
            "column": column,
            "sourceAlphaVisibleBounds": bounds,
            "sourceCrop": [
                cropX,
                cropY,
                cropMaxX,
                cropMaxY,
            ],
            "sheetPanel": [panelX, panelY, panelWidth, panelHeight],
        ])
    }
    guard let image = context.makeImage() else {
        throw AlphaVisibleValidationError.invalid(
            "could not create occupied-pixel contact sheet image"
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
        throw AlphaVisibleValidationError.invalid(
            "could not create occupied-pixel sheet destination"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw AlphaVisibleValidationError.invalid(
            "could not finalize occupied-pixel contact sheet"
        )
    }
    return panels
}

@main
enum ValidateAlphaVisibleSourcesMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try requiredArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputURL = URL(
            fileURLWithPath: try requiredArgument("--output", in: arguments)
        ).standardizedFileURL
        let sheetURL = URL(
            fileURLWithPath: try requiredArgument("--sheet", in: arguments)
        ).standardizedFileURL
        let candidates = try repeatedArgument(
            "--source",
            in: arguments
        ).map {
            try resolvedSource($0, repositoryRoot: repositoryRoot)
        }.map {
            try inspectExactRetainedPNG(id: $0.0, url: $0.1)
        }
        let references = try repeatedArgument(
            "--reference",
            in: arguments
        ).map {
            try resolvedSource($0, repositoryRoot: repositoryRoot)
        }.map {
            try inspectExactRetainedPNG(id: $0.0, url: $0.1)
        }

        let referenceMinimumCount =
            references.map(\.alphaVisibleOccupiedPixelCount).min() ?? 0
        let referenceMinimumWidth =
            references.map {
                dimension($0.alphaVisibleBounds, axis: 0)
            }.min() ?? 0
        let referenceMinimumHeight =
            references.map {
                dimension($0.alphaVisibleBounds, axis: 1)
            }.min() ?? 0
        guard
            referenceMinimumCount > 0,
            referenceMinimumWidth > 0,
            referenceMinimumHeight > 0
        else {
            throw AlphaVisibleValidationError.invalid(
                "reference occupancy is empty"
            )
        }

        var candidateRecords: [[String: Any]] = []
        var allPassed = true
        for candidate in candidates {
            let alphaVisibilityRatio =
                Double(candidate.alphaVisibleOccupiedPixelCount)
                / Double(max(1, candidate.rgbOccupiedPixelCount))
            let referenceCountRatio =
                Double(candidate.alphaVisibleOccupiedPixelCount)
                / Double(referenceMinimumCount)
            let referenceWidthRatio =
                Double(dimension(candidate.alphaVisibleBounds, axis: 0))
                / Double(referenceMinimumWidth)
            let referenceHeightRatio =
                Double(dimension(candidate.alphaVisibleBounds, axis: 1))
                / Double(referenceMinimumHeight)
            let boundsMatch =
                candidate.rgbBounds == candidate.alphaVisibleBounds
            let passed =
                candidate.flatOpaqueChromaCorners
                && candidate.hiddenNonMagentaPixelCount == 0
                && alphaVisibilityRatio >= 0.999
                && boundsMatch
                && referenceCountRatio >= 0.90
                && referenceWidthRatio >= 0.95
                && referenceHeightRatio >= 0.95
            allPassed = allPassed && passed
            candidateRecords.append([
                "id": candidate.id,
                "file": relativePath(
                    candidate.url,
                    repositoryRoot: repositoryRoot
                ),
                "fileSHA256": candidate.fileSHA256,
                "decodedAlphaInfo": candidate.image.alphaInfo.rawValue,
                "decodedBitsPerPixel": candidate.image.bitsPerPixel,
                "rgbOccupiedPixelCount":
                    candidate.rgbOccupiedPixelCount,
                "alphaVisibleOccupiedPixelCount":
                    candidate.alphaVisibleOccupiedPixelCount,
                "hiddenNonMagentaPixelCount":
                    candidate.hiddenNonMagentaPixelCount,
                "rgbOccupiedBounds": candidate.rgbBounds,
                "alphaVisibleOccupiedBounds":
                    candidate.alphaVisibleBounds,
                "alphaVisibilityRatio": alphaVisibilityRatio,
                "referenceMinimumCountRatio": referenceCountRatio,
                "referenceMinimumWidthRatio": referenceWidthRatio,
                "referenceMinimumHeightRatio": referenceHeightRatio,
                "rgbAndAlphaVisibleBoundsMatch": boundsMatch,
                "flatOpaqueChromaCorners":
                    candidate.flatOpaqueChromaCorners,
                "validationPassed": passed,
            ])
        }

        let panels = try writeOccupiedContactSheet(
            inspections: candidates,
            to: sheetURL
        )
        let referenceRecords = references.map {
            [
                "id": $0.id,
                "file": relativePath(
                    $0.url,
                    repositoryRoot: repositoryRoot
                ),
                "fileSHA256": $0.fileSHA256,
                "alphaVisibleOccupiedPixelCount":
                    $0.alphaVisibleOccupiedPixelCount,
                "alphaVisibleOccupiedBounds": $0.alphaVisibleBounds,
            ] as [String: Any]
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "tool":
                "exact retained-byte ImageIO RGBA visibility validator",
            "decodePath":
                "CGImageSource immediate standard RGBA decode plus provider bytes",
            "candidateThresholds": [
                "minimumAlphaVisibilityRatio": 0.999,
                "maximumHiddenNonMagentaPixelCount": 0,
                "rgbAndAlphaVisibleBoundsMustMatch": true,
                "minimumReferenceCountRatio": 0.90,
                "minimumReferenceWidthRatio": 0.95,
                "minimumReferenceHeightRatio": 0.95,
            ],
            "derivedReferenceFloor": [
                "alphaVisibleOccupiedPixelCount":
                    referenceMinimumCount,
                "occupiedBoundsPixels": [
                    referenceMinimumWidth,
                    referenceMinimumHeight,
                ],
            ],
            "references": referenceRecords,
            "sources": candidateRecords,
            "contactSheet": [
                "file": relativePath(
                    sheetURL,
                    repositoryRoot: repositoryRoot
                ),
                "directionOrder": candidates.map(\.id),
                "presentation":
                    "exact decoded RGBA, flat chroma masked transparent, occupied crop on neutral field",
                "panels": panels,
            ],
            "validationPassed": allPassed,
        ]
        let data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var terminated = data
        terminated.append(0x0a)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try terminated.write(to: outputURL, options: .atomic)
        if !allPassed {
            throw AlphaVisibleValidationError.invalid(
                "alpha-visible retained-byte validation failed"
            )
        }
    }
}
