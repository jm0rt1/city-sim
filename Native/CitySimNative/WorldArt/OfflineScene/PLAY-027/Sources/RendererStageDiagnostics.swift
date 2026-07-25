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
