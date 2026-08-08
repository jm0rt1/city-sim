import CoreGraphics
import CoreImage
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct LODReceipt: Codable {
    let name: String
    let canvas: [Int]
    let filter: String
    let rounding: String
    let path: String
    let sha256: String
    let pivot: [Int]
    let socket: [Int]
}

struct SouthReceipt: Codable {
    let schema: String
    let task: String
    let logicalId: String
    let level: Int
    let variant: Int
    let direction: String
    let sourceCanvas: [Int]
    let rawPath: String
    let rawSha256: String
    let rawBytesPreserved: Bool
    let normalizedPath: String
    let normalizedSha256: String
    let groundPivotSource: [Int]
    let frontageSocketSource: [Int]
    let footprintPolygonSource: [[Int]]
    let profilePath: String
    let profileSha256: String
    let normalization: String
    let chromaThreshold: Int
    let borderConnectedChromaPixelsRemoved: Int
    let lods: [LODReceipt]
    let visualAcceptance: String
    let integrationAdmitted: Bool
    let productionSelected: Bool
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".", isDirectory: true)
let rawRoot = root.appendingPathComponent("raw", isDirectory: true)
let normalizedRoot = root.appendingPathComponent("normalized/south", isDirectory: true)
let receiptsRoot = root.appendingPathComponent("receipts/south", isDirectory: true)
let fileManager = FileManager.default
try fileManager.createDirectory(at: normalizedRoot, withIntermediateDirectories: true)
try fileManager.createDirectory(at: receiptsRoot, withIntermediateDirectories: true)

let expected = (1...4).flatMap { level in (0...2).map { variant in
    ("industrial_l\(String(format: "%02d", level))_v\(String(format: "%02d", variant))", level, variant)
} }
let sourceSize = CGSize(width: 1536, height: 1024)
let sourceWidth = 1536
let sourceHeight = 1024
let groundPivot = [768, 896]
let southSocket = [640, 832]
let footprint = [[768, 640], [1024, 768], [768, 896], [512, 768]]
let profilePath = "docs/production/decisions/CONTRACT-026-registration-profiles-v1.json"
let profileSHA = "6663482339e953bdcbcb86bcfc876676989fbcb7f74a91f3f1b480d124fe3bd8"
let chromaThreshold = 160
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CIContext(options: [:])

func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func distanceToMagenta(_ pixels: [UInt8], _ index: Int) -> Int {
    abs(Int(pixels[index]) - 255) + Int(pixels[index + 1]) + abs(Int(pixels[index + 2]) - 255)
}

func renderRGBA(_ image: CIImage, width: Int, height: Int) -> [UInt8] {
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { buffer in
        context.render(image, toBitmap: buffer.baseAddress!, rowBytes: width * 4, bounds: CGRect(x: 0, y: 0, width: width, height: height), format: .RGBA8, colorSpace: colorSpace)
    }
    return pixels
}

func renderCGImage(_ image: CGImage, width: Int, height: Int) -> [UInt8] {
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let bitmap = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo) else {
        return pixels
    }
    bitmap.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixels
}

func removeBorderChroma(_ pixels: inout [UInt8], width: Int, height: Int) -> Int {
    var visited = [Bool](repeating: false, count: width * height)
    var queue = [Int]()
    func seed(_ x: Int, _ y: Int) {
        let pixelIndex = y * width + x
        if !visited[pixelIndex] { visited[pixelIndex] = true; queue.append(pixelIndex) }
    }
    for x in 0..<width { seed(x, 0); seed(x, height - 1) }
    for y in 0..<height { seed(0, y); seed(width - 1, y) }
    var head = 0
    var removed = 0
    while head < queue.count {
        let pixelIndex = queue[head]; head += 1
        let byteIndex = pixelIndex * 4
        guard distanceToMagenta(pixels, byteIndex) <= chromaThreshold else { continue }
        if pixels[byteIndex + 3] != 0 {
            pixels[byteIndex] = 0; pixels[byteIndex + 1] = 0; pixels[byteIndex + 2] = 0; pixels[byteIndex + 3] = 0
            removed += 1
        }
        let x = pixelIndex % width; let y = pixelIndex / width
        if x > 0 { seed(x - 1, y) }; if x + 1 < width { seed(x + 1, y) }
        if y > 0 { seed(x, y - 1) }; if y + 1 < height { seed(x, y + 1) }
    }
    return removed
}

func imageFromRGBA(_ pixels: [UInt8], width: Int, height: Int) -> CIImage {
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    return CIImage(cgImage: image)
}

func writePNGRGBA(_ pixels: [UInt8], to url: URL, width: Int, height: Int) throws {
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
    guard let cgImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { throw NSError(domain: "PLAY099", code: 1) }
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw NSError(domain: "PLAY099", code: 2) }
    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "PLAY099", code: 3) }
}

func evenRound(_ numerator: Int, _ denominator: Int) -> Int {
    let quotient = numerator / denominator; let remainder = numerator % denominator
    if remainder * 2 < denominator { return quotient }
    if remainder * 2 > denominator { return quotient + 1 }
    return quotient.isMultiple(of: 2) ? quotient : quotient + 1
}

func mapped(_ point: [Int], _ canvas: [Int]) -> [Int] {
    [evenRound(point[0] * canvas[0], sourceWidth), evenRound(point[1] * canvas[1], sourceHeight)]
}

func lodReceipt(_ name: String, _ canvas: [Int], _ source: CIImage, _ identityRoot: URL) throws -> LODReceipt {
    // Core Image's Lanczos output extent includes its terminal sample. Use
    // target-minus-one source samples so the whole-canvas extent is exact,
    // without cropping or resizing-to-bounds after the filter.
    let scale = CGFloat(canvas[0] - 1) / CGFloat(sourceWidth)
    let aspect = (CGFloat(canvas[1] - 1) / CGFloat(sourceHeight)) / scale
    let filter = CIFilter(name: "CILanczosScaleTransform")!
    filter.setValue(source, forKey: kCIInputImageKey)
    filter.setValue(scale, forKey: kCIInputScaleKey)
    filter.setValue(aspect, forKey: kCIInputAspectRatioKey)
    guard let output = filter.outputImage else { throw NSError(domain: "PLAY099", code: 4) }
    let path = identityRoot.appendingPathComponent("\(name).png")
    try writePNGRGBA(renderRGBA(output, width: canvas[0], height: canvas[1]), to: path, width: canvas[0], height: canvas[1])
    let bytes = try Data(contentsOf: path)
    return LODReceipt(name: name, canvas: canvas, filter: "CILanczosScaleTransform", rounding: "round-half-even source-coordinate receipts", path: path.path.replacingOccurrences(of: root.path + "/", with: ""), sha256: sha256(bytes), pivot: mapped(groundPivot, canvas), socket: mapped(southSocket, canvas))
}

var allReceipts = [SouthReceipt]()
for (logicalId, level, variant) in expected {
    let raw = rawRoot.appendingPathComponent("\(logicalId)-source-v01.png")
    let rawData = try Data(contentsOf: raw)
    let rawHash = sha256(rawData)
    guard let source = CGImageSourceCreateWithData(rawData as CFData, nil),
          let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw NSError(domain: "PLAY099", code: 5) }
    let input = CIImage(cgImage: decoded)
    guard Int(input.extent.width) == sourceWidth && Int(input.extent.height) == sourceHeight else { throw NSError(domain: "PLAY099", code: 6) }
    var pixels = renderCGImage(decoded, width: sourceWidth, height: sourceHeight)
    let removed = removeBorderChroma(&pixels, width: sourceWidth, height: sourceHeight)
    let normalized = imageFromRGBA(pixels, width: sourceWidth, height: sourceHeight)
    let identityRoot = normalizedRoot.appendingPathComponent(logicalId, isDirectory: true)
    try fileManager.createDirectory(at: identityRoot, withIntermediateDirectories: true)
    let normalizedPath = identityRoot.appendingPathComponent("source-rgba.png")
    try writePNGRGBA(pixels, to: normalizedPath, width: sourceWidth, height: sourceHeight)
    guard let lodSource = CIImage(contentsOf: normalizedPath, options: [.applyOrientationProperty: false]) else { throw NSError(domain: "PLAY099", code: 7) }
    let lods = try [
        lodReceipt("block", [1024, 683], lodSource, identityRoot),
        lodReceipt("neighborhood", [512, 342], lodSource, identityRoot),
        lodReceipt("city", [256, 171], lodSource, identityRoot)
    ]
    let normalizedHash = sha256(try Data(contentsOf: normalizedPath))
    let receipt = SouthReceipt(schema: "PLAY-099-south-admission-v3-receipt", task: "PLAY-099", logicalId: logicalId, level: level, variant: variant, direction: "south", sourceCanvas: [sourceWidth, sourceHeight], rawPath: raw.path.replacingOccurrences(of: root.path + "/", with: ""), rawSha256: rawHash, rawBytesPreserved: sha256(try Data(contentsOf: raw)) == rawHash, normalizedPath: normalizedPath.path.replacingOccurrences(of: root.path + "/", with: ""), normalizedSha256: normalizedHash, groundPivotSource: groundPivot, frontageSocketSource: southSocket, footprintPolygonSource: footprint, profilePath: profilePath, profileSha256: profileSHA, normalization: "full-canvas RGBA; border-connected chroma removal; no crop/trim; CILanczosScaleTransform whole-canvas LODs", chromaThreshold: chromaThreshold, borderConnectedChromaPixelsRemoved: removed, lods: lods, visualAcceptance: "not performed; frontier-owned", integrationAdmitted: false, productionSelected: false)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(receipt).write(to: receiptsRoot.appendingPathComponent("\(logicalId).json"))
    allReceipts.append(receipt)
}

let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(allReceipts).write(to: receiptsRoot.appendingPathComponent("all-south-receipts.json"))
print("PASS: normalized \(allReceipts.count) South identities with 3 whole-canvas LODs each")
