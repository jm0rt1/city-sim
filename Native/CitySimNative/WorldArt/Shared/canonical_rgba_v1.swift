import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

enum CanonicalRGBAError: Error {
    case invalid(String)
}

func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func decodedRGBA(_ url: URL) throws -> (width: Int, height: Int, bytes: [UInt8]) {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        )
    else {
        throw CanonicalRGBAError.invalid("cannot decode \(url.path)")
    }
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try bytes.withUnsafeMutableBytes { storage in
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
            throw CanonicalRGBAError.invalid("cannot allocate RGBA context")
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return (image.width, image.height, bytes)
}

func transformedDigest(
    width: Int,
    height: Int,
    bytes: [UInt8],
    coordinates: [(Int, Int)]
) -> String {
    var transformed = Data()
    transformed.reserveCapacity(bytes.count)
    for (x, y) in coordinates {
        let offset = (y * width + x) * 4
        transformed.append(contentsOf: bytes[offset..<(offset + 4)])
    }
    return digest(transformed)
}

func coordinates(
    width: Int,
    height: Int,
    xValues: [Int],
    yValues: [Int],
    xOuter: Bool
) -> [(Int, Int)] {
    var result: [(Int, Int)] = []
    result.reserveCapacity(width * height)
    if xOuter {
        for x in xValues {
            for y in yValues {
                result.append((x, y))
            }
        }
    } else {
        for y in yValues {
            for x in xValues {
                result.append((x, y))
            }
        }
    }
    return result
}

func inspect(_ path: String, includeD4: Bool) throws -> [String: Any] {
    let url = URL(fileURLWithPath: path).standardizedFileURL
    let fileData = try Data(contentsOf: url)
    let raster = try decodedRGBA(url)
    let xs = Array(0..<raster.width)
    let ys = Array(0..<raster.height)
    let reverseX = Array(xs.reversed())
    let reverseY = Array(ys.reversed())
    var occupiedX: [Int] = []
    var occupiedY: [Int] = []
    for y in ys {
        for x in xs {
            if raster.bytes[(y * raster.width + x) * 4 + 3] > 0 {
                occupiedX.append(x)
                occupiedY.append(y)
            }
        }
    }
    let occupiedBounds: Any = occupiedX.isEmpty
        ? NSNull()
        : [
            "minX": occupiedX.min()!,
            "minY": occupiedY.min()!,
            "maxX": occupiedX.max()!,
            "maxY": occupiedY.max()!,
        ]
    let d4: Any = includeD4 ? [
        "identity": digest(Data(raster.bytes)),
        "rotate90": transformedDigest(
            width: raster.width,
            height: raster.height,
            bytes: raster.bytes,
            coordinates: coordinates(
                width: raster.width,
                height: raster.height,
                xValues: xs,
                yValues: reverseY,
                xOuter: true
            )
        ),
        "rotate180": transformedDigest(
            width: raster.width,
            height: raster.height,
            bytes: raster.bytes,
            coordinates: coordinates(
                width: raster.width,
                height: raster.height,
                xValues: reverseX,
                yValues: reverseY,
                xOuter: false
            )
        ),
        "rotate270": transformedDigest(
            width: raster.width,
            height: raster.height,
            bytes: raster.bytes,
            coordinates: coordinates(
                width: raster.width,
                height: raster.height,
                xValues: reverseX,
                yValues: ys,
                xOuter: true
            )
        ),
        "mirrorX": transformedDigest(
            width: raster.width,
            height: raster.height,
            bytes: raster.bytes,
            coordinates: coordinates(
                width: raster.width,
                height: raster.height,
                xValues: reverseX,
                yValues: ys,
                xOuter: false
            )
        ),
        "mirrorY": transformedDigest(
            width: raster.width,
            height: raster.height,
            bytes: raster.bytes,
            coordinates: coordinates(
                width: raster.width,
                height: raster.height,
                xValues: xs,
                yValues: reverseY,
                xOuter: false
            )
        ),
        "mirrorDiagonal": transformedDigest(
            width: raster.width,
            height: raster.height,
            bytes: raster.bytes,
            coordinates: coordinates(
                width: raster.width,
                height: raster.height,
                xValues: xs,
                yValues: ys,
                xOuter: true
            )
        ),
        "mirrorAntiDiagonal": transformedDigest(
            width: raster.width,
            height: raster.height,
            bytes: raster.bytes,
            coordinates: coordinates(
                width: raster.width,
                height: raster.height,
                xValues: reverseX,
                yValues: reverseY,
                xOuter: true
            )
        ),
    ] : NSNull()
    return [
        "path": path,
        "width": raster.width,
        "height": raster.height,
        "fileSha256": digest(fileData),
        "decodedRgbaSha256": digest(Data(raster.bytes)),
        "occupiedBounds": occupiedBounds,
        "d4": d4,
    ]
}

var arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 3, arguments[0] == "--d4-path" else {
    throw CanonicalRGBAError.invalid(
        "usage: canonical-rgba-v1 --d4-path <path> <image> [<image> ...]"
    )
}
let d4Path = URL(fileURLWithPath: arguments[1]).standardizedFileURL.path
arguments.removeFirst(2)
let paths = arguments
guard !paths.isEmpty else {
    throw CanonicalRGBAError.invalid("provide one or more image paths")
}
let records = try paths.map {
    let standardized = URL(fileURLWithPath: $0).standardizedFileURL.path
    return try inspect(standardized, includeD4: standardized == d4Path)
}
let output = try JSONSerialization.data(
    withJSONObject: ["records": records, "schema": "citysim.canonical-rgba.v1"],
    options: [.sortedKeys]
)
FileHandle.standardOutput.write(output)
FileHandle.standardOutput.write(Data([0x0A]))
