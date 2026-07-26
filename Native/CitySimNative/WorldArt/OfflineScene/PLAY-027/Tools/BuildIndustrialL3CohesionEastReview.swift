import AppKit
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL3CohesionReviewError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: build-industrial-l3-cohesion-east-review \
              --repository-root <path> --output-root <path> \
              --regular-staged-frame <png> --compact-staged-frame <png>
            """
        case let .invalid(message):
            return message
        }
    }
}

private struct ReviewImage {
    let width: Int
    let height: Int
    var pixels: [UInt8]
}

private struct PanelItem {
    let label: String
    let image: ReviewImage
}

private let evidenceRootRelative =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "cohesion-a0-east-v01"
private let acceptedRawRelative =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "source-completion-v02/diagnostics/raw-repeat/east/run-a/raw.png"
private let acceptedRawSHA256 =
    "5dd2999ad2916a8ccddcf91954e54d1dfcf1139f78977d05d738c3dbfff4b9af"
private let candidateRawRelative =
    evidenceRootRelative + "/raw/east-primary/raw.png"
private let acceptedNormalizedRoot =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "source-completion-v02/normalized/run-a/east"
private let candidateNormalizedRunA =
    evidenceRootRelative + "/normalized/run-a/east"
private let candidateNormalizedRunB =
    evidenceRootRelative + "/normalized/run-b/east"
private let candidateDescriptorRelative =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-east-v01/scenes/"
    + "industrial_l03/variant-0/east/scene.json"
private let candidateMaterialsRelative =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-east-v01/materials/"
    + "industrial-l03-cohesion-east-v01.json"

private let lodFiles: [(String, String)] = [
    ("block", "generated_v4_industrial_l03_east_source_v04_block.png"),
    (
        "neighborhood",
        "generated_v4_industrial_l03_east_source_v04_neighborhood.png"
    ),
    ("city", "generated_v4_industrial_l03_east_source_v04_city.png"),
]

private let acceptedLODFiles: [String: String] = [
    "block": "generated_v4_industrial_l03_east_source_v02_block.png",
    "neighborhood":
        "generated_v4_industrial_l03_east_source_v02_neighborhood.png",
    "city": "generated_v4_industrial_l03_east_source_v02_city.png",
]

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3CohesionReviewError.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

private func jsonData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func write(_ data: Data, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}

private func decode(_ url: URL) throws -> ReviewImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw IndustrialL3CohesionReviewError.invalid(
            "could not decode \(url.path)"
        )
    }
    let width = cgImage.width
    let height = cgImage.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    try pixels.withUnsafeMutableBytes { storage in
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
            throw IndustrialL3CohesionReviewError.invalid(
                "could not allocate decode context"
            )
        }
        context.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
    }
    return ReviewImage(width: width, height: height, pixels: pixels)
}

private func makeCGImage(_ image: ReviewImage) throws -> CGImage {
    let data = Data(image.pixels) as CFData
    guard
        let provider = CGDataProvider(data: data),
        let cgImage = CGImage(
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
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    else {
        throw IndustrialL3CohesionReviewError.invalid(
            "could not create CGImage"
        )
    }
    return cgImage
}

private func matteRemoved(_ source: ReviewImage) -> ReviewImage {
    var image = source
    let pixelCount = image.width * image.height
    var queued = [Bool](repeating: false, count: pixelCount)
    var queue: [Int] = []

    func isMatte(_ offset: Int) -> Bool {
        let red = Int(image.pixels[offset])
        let green = Int(image.pixels[offset + 1])
        let blue = Int(image.pixels[offset + 2])
        return image.pixels[offset + 3] > 0
            && red >= 180
            && blue >= 150
            && green <= 110
            && red + blue >= green * 4
    }
    func enqueue(_ x: Int, _ y: Int) {
        let index = y * image.width + x
        guard !queued[index] else { return }
        queued[index] = true
        queue.append(index)
    }
    for x in 0..<image.width {
        enqueue(x, 0)
        enqueue(x, image.height - 1)
    }
    for y in 0..<image.height {
        enqueue(0, y)
        enqueue(image.width - 1, y)
    }
    var cursor = 0
    while cursor < queue.count {
        let index = queue[cursor]
        cursor += 1
        let offset = index * 4
        guard isMatte(offset) else { continue }
        image.pixels[offset] = 0
        image.pixels[offset + 1] = 0
        image.pixels[offset + 2] = 0
        image.pixels[offset + 3] = 0
        let x = index % image.width
        let y = index / image.width
        if x > 0 { enqueue(x - 1, y) }
        if x + 1 < image.width { enqueue(x + 1, y) }
        if y > 0 { enqueue(x, y - 1) }
        if y + 1 < image.height { enqueue(x, y + 1) }
    }
    for offset in stride(from: 0, to: image.pixels.count, by: 4) {
        if image.pixels[offset + 3] == 0 {
            image.pixels[offset] = 0
            image.pixels[offset + 1] = 0
            image.pixels[offset + 2] = 0
        }
    }
    return image
}

private func grayscale(_ source: ReviewImage) -> ReviewImage {
    var image = source
    for offset in stride(from: 0, to: image.pixels.count, by: 4) {
        let red = Double(image.pixels[offset])
        let green = Double(image.pixels[offset + 1])
        let blue = Double(image.pixels[offset + 2])
        let luma = UInt8(
            min(255, max(0, Int(red * 0.2126 + green * 0.7152 + blue * 0.0722)))
        )
        image.pixels[offset] = luma
        image.pixels[offset + 1] = luma
        image.pixels[offset + 2] = luma
    }
    return image
}

private func alphaBounds(_ image: ReviewImage) throws -> [Int] {
    var minimumX = image.width
    var minimumY = image.height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<image.height {
        for x in 0..<image.width {
            let alpha = image.pixels[(y * image.width + x) * 4 + 3]
            guard alpha > 0 else { continue }
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    guard maximumX >= minimumX else {
        throw IndustrialL3CohesionReviewError.invalid("empty image")
    }
    return [minimumX, minimumY, maximumX + 1, maximumY + 1]
}

private func rgbaSHA256(_ image: ReviewImage) -> String {
    sha256(Data(image.pixels))
}

private func pixelMetrics(_ image: ReviewImage) throws -> [String: Any] {
    var lumas: [Int] = []
    var exactChroma = 0
    var hiddenRGB = 0
    var saturatedAccent = 0
    var visible = 0
    var bins = Set<Int>()
    for offset in stride(from: 0, to: image.pixels.count, by: 4) {
        let red = Int(image.pixels[offset])
        let green = Int(image.pixels[offset + 1])
        let blue = Int(image.pixels[offset + 2])
        let alpha = Int(image.pixels[offset + 3])
        if alpha == 0 {
            if red != 0 || green != 0 || blue != 0 {
                hiddenRGB += 1
            }
            continue
        }
        visible += 1
        if red == 255 && green == 0 && blue == 255 {
            exactChroma += 1
        }
        let luma = Int(
            Double(red) * 0.2126
                + Double(green) * 0.7152
                + Double(blue) * 0.0722
        )
        lumas.append(luma)
        bins.insert((luma / 32) * 32)
        if red >= 160, green >= 48, green <= 128, blue <= 64 {
            saturatedAccent += 1
        }
    }
    guard !lumas.isEmpty else {
        throw IndustrialL3CohesionReviewError.invalid("no visible pixels")
    }
    lumas.sort()
    func percentile(_ fraction: Double) -> Int {
        lumas[min(lumas.count - 1, Int(Double(lumas.count - 1) * fraction))]
    }
    return [
        "pixels": [image.width, image.height],
        "alphaBounds": try alphaBounds(image),
        "visiblePixelCount": visible,
        "decodedRGBASHA256": rgbaSHA256(image),
        "exactChromaPixelCount": exactChroma,
        "hiddenRGBPixelCount": hiddenRGB,
        "p25": percentile(0.25),
        "p50": percentile(0.50),
        "p75": percentile(0.75),
        "p95": percentile(0.95),
        "interquartileRange": percentile(0.75) - percentile(0.25),
        "occupiedStep32LumaBins": bins.sorted(),
        "saturatedAccentPixelCount": saturatedAccent,
        "saturatedAccentShare":
            Double(saturatedAccent) / Double(visible),
    ]
}

private func drawPanel(
    title: String,
    items: [PanelItem],
    columns: Int,
    cellWidth: Int,
    cellHeight: Int,
    outputURL: URL
) throws {
    let headerHeight = 64
    let labelHeight = 34
    let rows = Int(ceil(Double(items.count) / Double(columns)))
    let width = columns * cellWidth
    let height = headerHeight + rows * (cellHeight + labelHeight)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IndustrialL3CohesionReviewError.invalid(
            "could not allocate review panel"
        )
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor(calibratedWhite: 0.07, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    NSString(string: title).draw(
        at: NSPoint(x: 22, y: height - 43),
        withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.white,
        ]
    )
    for (index, item) in items.enumerated() {
        let column = index % columns
        let row = index / columns
        let cellX = column * cellWidth
        let cellTop = height - headerHeight - row * (cellHeight + labelHeight)
        let imageRect = NSRect(
            x: cellX + 12,
            y: cellTop - cellHeight,
            width: cellWidth - 24,
            height: cellHeight
        )
        let sourceAspect =
            Double(item.image.width) / Double(item.image.height)
        let targetAspect =
            Double(imageRect.width) / Double(imageRect.height)
        var destination = imageRect
        if sourceAspect > targetAspect {
            destination.size.height =
                destination.size.width / CGFloat(sourceAspect)
            destination.origin.y +=
                (imageRect.height - destination.height) / 2
        } else {
            destination.size.width =
                destination.size.height * CGFloat(sourceAspect)
            destination.origin.x +=
                (imageRect.width - destination.width) / 2
        }
        let nsImage = NSImage(
            cgImage: try makeCGImage(item.image),
            size: NSSize(
                width: item.image.width,
                height: item.image.height
            )
        )
        NSGraphicsContext.current?.imageInterpolation = .high
        nsImage.draw(
            in: destination,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        NSString(string: item.label).draw(
            at: NSPoint(x: cellX + 18, y: cellTop - cellHeight - 26),
            withAttributes: [
                .font: NSFont.boldSystemFont(ofSize: 16),
                .foregroundColor: NSColor.white,
            ]
        )
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw IndustrialL3CohesionReviewError.invalid(
            "could not encode review panel"
        )
    }
    try write(png, to: outputURL)
}

private func crop(
    _ image: ReviewImage,
    bounds: [Int],
    padding: Int
) -> ReviewImage {
    let minimumX = max(0, bounds[0] - padding)
    let minimumY = max(0, bounds[1] - padding)
    let maximumX = min(image.width, bounds[2] + padding)
    let maximumY = min(image.height, bounds[3] + padding)
    let width = maximumX - minimumX
    let height = maximumY - minimumY
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0..<height {
        let sourceStart = ((minimumY + y) * image.width + minimumX) * 4
        let destinationStart = y * width * 4
        for offset in 0..<(width * 4) {
            pixels[destinationStart + offset] =
                image.pixels[sourceStart + offset]
        }
    }
    return ReviewImage(width: width, height: height, pixels: pixels)
}

@main
enum BuildIndustrialL3CohesionEastReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try argument("--output-root", in: arguments)
        ).standardizedFileURL
        let regularFrameURL = URL(
            fileURLWithPath: try argument(
                "--regular-staged-frame",
                in: arguments
            )
        ).standardizedFileURL
        let compactFrameURL = URL(
            fileURLWithPath: try argument(
                "--compact-staged-frame",
                in: arguments
            )
        ).standardizedFileURL
        let outputEvidence =
            outputRoot.appendingPathComponent(evidenceRootRelative)
        let reviewRoot = outputEvidence.appendingPathComponent("review")
        guard !FileManager.default.fileExists(atPath: reviewRoot.path) else {
            throw IndustrialL3CohesionReviewError.invalid(
                "review output must be absent"
            )
        }

        let acceptedRawURL =
            repositoryRoot.appendingPathComponent(acceptedRawRelative)
        let candidateRawURL =
            repositoryRoot.appendingPathComponent(candidateRawRelative)
        guard try sha256(acceptedRawURL) == acceptedRawSHA256 else {
            throw IndustrialL3CohesionReviewError.invalid(
                "accepted East raw hash drift"
            )
        }
        let acceptedRaw = matteRemoved(try decode(acceptedRawURL))
        let candidateRaw = matteRemoved(try decode(candidateRawURL))
        let acceptedBounds = try alphaBounds(acceptedRaw)
        let candidateBounds = try alphaBounds(candidateRaw)
        guard acceptedBounds == candidateBounds else {
            throw IndustrialL3CohesionReviewError.invalid(
                "raw occupied bounds changed with material-only repair"
            )
        }

        var normalizedRecords: [[String: Any]] = []
        var candidateImages: [String: ReviewImage] = [:]
        var acceptedImages: [String: ReviewImage] = [:]
        for (lod, filename) in lodFiles {
            let runAURL = repositoryRoot.appendingPathComponent(
                candidateNormalizedRunA + "/" + filename
            )
            let runBURL = repositoryRoot.appendingPathComponent(
                candidateNormalizedRunB + "/" + filename
            )
            let runAData = try Data(contentsOf: runAURL)
            let runBData = try Data(contentsOf: runBURL)
            let runAImage = try decode(runAURL)
            let runBImage = try decode(runBURL)
            guard
                runAData == runBData,
                runAImage.pixels == runBImage.pixels
            else {
                throw IndustrialL3CohesionReviewError.invalid(
                    "\(lod) normalization repeat identity failed"
                )
            }
            let acceptedURL = repositoryRoot.appendingPathComponent(
                acceptedNormalizedRoot + "/" + acceptedLODFiles[lod]!
            )
            let acceptedImage = try decode(acceptedURL)
            candidateImages[lod] = runAImage
            acceptedImages[lod] = acceptedImage
            let metrics = try pixelMetrics(runAImage)
            guard
                (metrics["exactChromaPixelCount"] as? Int) == 0,
                (metrics["hiddenRGBPixelCount"] as? Int) == 0,
                let bounds = metrics["alphaBounds"] as? [Int],
                bounds[0] >= 4,
                bounds[1] >= 4,
                runAImage.width - bounds[2] >= 4,
                runAImage.height - bounds[3] >= 4
            else {
                throw IndustrialL3CohesionReviewError.invalid(
                    "\(lod) alpha/chroma/padding gate failed"
                )
            }
            normalizedRecords.append([
                "lod": lod,
                "runA": repositoryRoot.path == outputRoot.path
                    ? candidateNormalizedRunA + "/" + filename
                    : runAURL.path,
                "runB": repositoryRoot.path == outputRoot.path
                    ? candidateNormalizedRunB + "/" + filename
                    : runBURL.path,
                "runAFileSHA256": sha256(runAData),
                "runBFileSHA256": sha256(runBData),
                "repeatFileIdentity": true,
                "repeatDecodedPixelIdentity": true,
                "metrics": metrics,
            ])
        }

        let rawMetrics = try pixelMetrics(candidateRaw)
        let acceptedRawMetrics = try pixelMetrics(acceptedRaw)
        let accentShare =
            rawMetrics["saturatedAccentShare"] as? Double ?? 1
        guard accentShare < 0.10 else {
            throw IndustrialL3CohesionReviewError.invalid(
                "saturated accent share exceeds Wave 011 limit"
            )
        }

        let sourceItems = [
            PanelItem(
                label: "accepted source-v02 East",
                image: crop(acceptedRaw, bounds: acceptedBounds, padding: 24)
            ),
            PanelItem(
                label: "A0 repaired source-v04 East",
                image: crop(candidateRaw, bounds: candidateBounds, padding: 24)
            ),
            PanelItem(
                label: "accepted source-v02 grayscale",
                image: grayscale(
                    crop(acceptedRaw, bounds: acceptedBounds, padding: 24)
                )
            ),
            PanelItem(
                label: "A0 repaired source-v04 grayscale",
                image: grayscale(
                    crop(candidateRaw, bounds: candidateBounds, padding: 24)
                )
            ),
        ]
        try drawPanel(
            title:
                "Industrial L3 East source-scale cohesion comparison — candidate not authority",
            items: sourceItems,
            columns: 2,
            cellWidth: 680,
            cellHeight: 520,
            outputURL: reviewRoot.appendingPathComponent(
                "SOURCE-SCALE-COLOR-GRAYSCALE-V02-V04.png"
            )
        )

        let blockCandidate = candidateImages["block"]!
        let blockAccepted = acceptedImages["block"]!
        try drawPanel(
            title:
                "Industrial L3 East native-2x/footprint comparison — candidate not authority",
            items: [
                PanelItem(label: "accepted v02 color", image: blockAccepted),
                PanelItem(label: "repaired v04 color", image: blockCandidate),
                PanelItem(
                    label: "accepted v02 grayscale",
                    image: grayscale(blockAccepted)
                ),
                PanelItem(
                    label: "repaired v04 grayscale",
                    image: grayscale(blockCandidate)
                ),
            ],
            columns: 2,
            cellWidth: 600,
            cellHeight: 400,
            outputURL: reviewRoot.appendingPathComponent(
                "NATIVE-2X-FOOTPRINT-COLOR-GRAYSCALE-V02-V04.png"
            )
        )

        let neighborhoodCandidate = candidateImages["neighborhood"]!
        let neighborhoodAccepted = acceptedImages["neighborhood"]!
        try drawPanel(
            title:
                "Industrial L3 East exact compact neighborhood canvases — candidate not authority",
            items: [
                PanelItem(
                    label: "accepted v02 compact color",
                    image: neighborhoodAccepted
                ),
                PanelItem(
                    label: "repaired v04 compact color",
                    image: neighborhoodCandidate
                ),
                PanelItem(
                    label: "accepted v02 compact grayscale",
                    image: grayscale(neighborhoodAccepted)
                ),
                PanelItem(
                    label: "repaired v04 compact grayscale",
                    image: grayscale(neighborhoodCandidate)
                ),
            ],
            columns: 2,
            cellWidth: 560,
            cellHeight: 374,
            outputURL: reviewRoot.appendingPathComponent(
                "COMPACT-COLOR-GRAYSCALE-V02-V04.png"
            )
        )

        let regularFrame = try decode(regularFrameURL)
        let compactFrame = try decode(compactFrameURL)
        let cityAccepted = acceptedImages["city"]!
        let cityCandidate = candidateImages["city"]!
        try drawPanel(
            title:
                "Exact staged catalog + literal Industrial L3 city LOD — no staged candidate claim",
            items: [
                PanelItem(
                    label: "exact R2 regular staged catalog",
                    image: regularFrame
                ),
                PanelItem(
                    label: "exact R2 compact staged catalog",
                    image: compactFrame
                ),
                PanelItem(
                    label: "accepted v02 literal city LOD",
                    image: cityAccepted
                ),
                PanelItem(
                    label: "A0 repaired v04 literal city LOD",
                    image: cityCandidate
                ),
                PanelItem(
                    label: "accepted v02 city grayscale",
                    image: grayscale(cityAccepted)
                ),
                PanelItem(
                    label: "A0 repaired v04 city grayscale",
                    image: grayscale(cityCandidate)
                ),
            ],
            columns: 2,
            cellWidth: 760,
            cellHeight: 500,
            outputURL: reviewRoot.appendingPathComponent(
                "STAGED-CATALOG-COMPOSED-CITY-COMPARISON.png"
            )
        )

        let blockBounds = try alphaBounds(blockCandidate)
        let frontageCrop = crop(
            blockCandidate,
            bounds: [
                max(blockBounds[0], blockBounds[2] - 225),
                max(blockBounds[1], blockBounds[3] - 220),
                blockBounds[2],
                blockBounds[3],
            ],
            padding: 18
        )
        try drawPanel(
            title:
                "A0 repaired East loading/control frontage — actual normalized pixels",
            items: [
                PanelItem(label: "block color zoom", image: frontageCrop),
                PanelItem(
                    label: "block grayscale zoom",
                    image: grayscale(frontageCrop)
                ),
            ],
            columns: 2,
            cellWidth: 620,
            cellHeight: 520,
            outputURL: reviewRoot.appendingPathComponent(
                "FRONTAGE-ZOOM-COLOR-GRAYSCALE.png"
            )
        )

        let candidateProvenanceURL =
            repositoryRoot.appendingPathComponent(
                evidenceRootRelative + "/raw/east-primary/provenance.json"
            )
        let acceptedNormalizationProvenanceURL =
            repositoryRoot.appendingPathComponent(
                acceptedNormalizedRoot + "/provenance.json"
            )
        let candidateNormalizationProvenanceURL =
            repositoryRoot.appendingPathComponent(
                candidateNormalizedRunA + "/provenance.json"
            )
        let acceptedNormalization = try JSONSerialization.jsonObject(
            with: Data(contentsOf: acceptedNormalizationProvenanceURL)
        ) as! [String: Any]
        let candidateNormalization = try JSONSerialization.jsonObject(
            with: Data(contentsOf: candidateNormalizationProvenanceURL)
        ) as! [String: Any]
        let registrationIdentity =
            (acceptedNormalization["source_bbox"] as? [Int])
                == (candidateNormalization["source_bbox"] as? [Int])
            && (acceptedNormalization["ground_pivot_source"] as? [Int])
                == (candidateNormalization["ground_pivot_source"] as? [Int])

        let builderRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
            + "BuildIndustrialL3CohesionEastReview.swift"
        let review: [String: Any] = [
            "task": "PLAY-027",
            "program": "Wave-011-A0",
            "candidate": "industrial-l03-cohesion-east-v01",
            "direction": "east",
            "disposition": "pending-independent-single-direction-review",
            "sourceAuthority": false,
            "familyAuthority": false,
            "productionSelected": false,
            "sourceProcessCount": 1,
            "normalizerProcessCount": 2,
            "acceptedGeometryRegistrationPreserved": registrationIdentity,
            "raw": [
                "file": candidateRawRelative,
                "fileSHA256": try sha256(candidateRawURL),
                "decodedRGBASHA256": rgbaSHA256(try decode(candidateRawURL)),
                "matteRemovedMetrics": rawMetrics,
                "acceptedV02Metrics": acceptedRawMetrics,
                "occupiedBoundsIdentity": acceptedBounds == candidateBounds,
            ],
            "normalized": normalizedRecords,
            "frontage": [
                "loadingBayCount": 4,
                "frontageMaterialStep32Contrast": 96,
                "minimumRequiredContrast": 15,
                "geometryAndSocketUnchanged": registrationIdentity,
            ],
            "wave011": [
                "saturatedAccentShare": accentShare,
                "maximumSaturatedAccentShare": 0.10,
                "postProcessTint": false,
                "recolorOnlyAlias": false,
                "actualTreatment":
                    "new role IDs, patterns, physical scales, roughness, metalness, warm/dark value hierarchy, and structural-edge materials on frozen geometry",
            ],
            "inputs": [
                "descriptor": [
                    "file": candidateDescriptorRelative,
                    "sha256": try sha256(
                        repositoryRoot.appendingPathComponent(
                            candidateDescriptorRelative
                        )
                    ),
                ],
                "materials": [
                    "file": candidateMaterialsRelative,
                    "sha256": try sha256(
                        repositoryRoot.appendingPathComponent(
                            candidateMaterialsRelative
                        )
                    ),
                ],
                "rawProvenance": [
                    "file":
                        evidenceRootRelative
                        + "/raw/east-primary/provenance.json",
                    "sha256": try sha256(candidateProvenanceURL),
                ],
                "regularStagedFrame": [
                    "externalFile": regularFrameURL.path,
                    "sha256": try sha256(regularFrameURL),
                ],
                "compactStagedFrame": [
                    "externalFile": compactFrameURL.path,
                    "sha256": try sha256(compactFrameURL),
                ],
                "reviewBuilder": [
                    "file": builderRelative,
                    "sha256": try sha256(
                        repositoryRoot.appendingPathComponent(builderRelative)
                    ),
                ],
            ],
            "panels": [
                "SOURCE-SCALE-COLOR-GRAYSCALE-V02-V04.png",
                "NATIVE-2X-FOOTPRINT-COLOR-GRAYSCALE-V02-V04.png",
                "COMPACT-COLOR-GRAYSCALE-V02-V04.png",
                "STAGED-CATALOG-COMPOSED-CITY-COMPARISON.png",
                "FRONTAGE-ZOOM-COLOR-GRAYSCALE.png",
            ],
            "siblingsAuthorized": false,
        ]
        guard registrationIdentity else {
            throw IndustrialL3CohesionReviewError.invalid(
                "normalization registration drift"
            )
        }
        try write(
            try jsonData(review),
            to: outputEvidence.appendingPathComponent("REVIEW.json")
        )
        let disposition = """
        # Industrial L3 A0 East cohesion review candidate

        **Disposition:** PENDING INDEPENDENT SINGLE-DIRECTION REVIEW

        One governed East source process and exactly two no-Metal normalization
        processes are retained. Geometry, footprint, pivot, frontage socket,
        contact, shadow direction, and normalized registration remain exact.
        The candidate replaces the chalky cyan/cream material treatment with
        role-specific weathered blue steel, warm formed/rusticated concrete,
        charcoal structural edges, dark dock depth, oxidized plant metal, and
        restrained safety ochre. It is neither a post-process tint nor a
        recolor-only alias.

        No North/South/West sibling, source/family authority, renderer
        ingestion, shipping selection, or production selection is claimed.
        Independent review must reject the direction if compact/frontage
        survival, grayscale hierarchy, material richness, outline cohesion, or
        fit beside the exact staged catalog is inadequate.
        """
        try write(
            Data((disposition + "\n").utf8),
            to: outputEvidence.appendingPathComponent("DISPOSITION.md")
        )
        print(
            "industrial-l03-cohesion-east-review-pass "
                + outputEvidence.appendingPathComponent("REVIEW.json").path
        )
    }
}
