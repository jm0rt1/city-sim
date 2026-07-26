import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL3NWV05RawReviewError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l3-nw-v05-raw-review --repository-root <path> --output-directory <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct Raster {
    let id: String
    let url: URL
    let image: CGImage
    let rgba: [UInt8]
    let fileSHA256: String
    let decodedRGBASHA256: String
    let nonChromaBounds: CGRect
}

private let rawRoot =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "cohesion-a0-frontage-raw-v01/diagnostics/raw-repeat"
private let v04Root =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "cohesion-a0-family-v01/raw"

private func argument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3NWV05RawReviewError.arguments
    }
    return arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func relative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

private func decode(
    id: String,
    url: URL
) throws -> Raster {
    let fileData = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        ),
        image.width == 1536,
        image.height == 1024
    else {
        throw IndustrialL3NWV05RawReviewError.invalid(
            "expected 1536x1024 PNG: \(url.path)"
        )
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
            throw IndustrialL3NWV05RawReviewError.invalid(
                "could not allocate RGBA decoder"
            )
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    var minimumX = image.width
    var minimumY = image.height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<image.height {
        for x in 0..<image.width {
            let offset = (y * image.width + x) * 4
            if
                bytes[offset] == 255,
                bytes[offset + 1] == 0,
                bytes[offset + 2] == 255
            {
                continue
            }
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    guard maximumX >= minimumX, maximumY >= minimumY else {
        throw IndustrialL3NWV05RawReviewError.invalid(
            "raw contains no non-chroma pixels: \(url.path)"
        )
    }
    return Raster(
        id: id,
        url: url,
        image: image,
        rgba: bytes,
        fileSHA256: digest(fileData),
        decodedRGBASHA256: digest(Data(bytes)),
        nonChromaBounds: CGRect(
            x: minimumX,
            y: minimumY,
            width: maximumX - minimumX + 1,
            height: maximumY - minimumY + 1
        )
    )
}

private func image(
    bytes: [UInt8],
    width: Int,
    height: Int
) throws -> CGImage {
    let data = Data(bytes)
    guard
        let provider = CGDataProvider(data: data as CFData),
        let output = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo:
                CGBitmapInfo.byteOrder32Big.union(
                    CGBitmapInfo(
                        rawValue:
                            CGImageAlphaInfo.premultipliedLast.rawValue
                    )
                ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    else {
        throw IndustrialL3NWV05RawReviewError.invalid(
            "could not create RGBA image"
        )
    }
    return output
}

private func matte(_ raster: Raster) throws -> CGImage {
    var bytes = raster.rgba
    for offset in stride(from: 0, to: bytes.count, by: 4) {
        let red = Int(bytes[offset])
        let green = Int(bytes[offset + 1])
        let blue = Int(bytes[offset + 2])
        if red == 255 && green == 0 && blue == 255 {
            bytes[offset] = 0
            bytes[offset + 1] = 0
            bytes[offset + 2] = 0
            bytes[offset + 3] = 0
        } else if
            green == 0,
            abs(red - blue) <= 8,
            red >= 96,
            blue >= 96
        {
            bytes[offset] = 0
            bytes[offset + 1] = 0
            bytes[offset + 2] = 0
            bytes[offset + 3] = UInt8(max(0, 255 - max(red, blue)))
        }
    }
    return try image(
        bytes: bytes,
        width: raster.image.width,
        height: raster.image.height
    )
}

private func grayscale(_ source: CGImage) throws -> CGImage {
    var bytes = [UInt8](
        repeating: 0,
        count: source.width * source.height * 4
    )
    try bytes.withUnsafeMutableBytes { storage in
        guard let context = CGContext(
            data: storage.baseAddress,
            width: source.width,
            height: source.height,
            bitsPerComponent: 8,
            bytesPerRow: source.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw IndustrialL3NWV05RawReviewError.invalid(
                "could not allocate grayscale context"
            )
        }
        context.draw(
            source,
            in: CGRect(
                x: 0,
                y: 0,
                width: source.width,
                height: source.height
            )
        )
        for offset in stride(from: 0, to: storage.count, by: 4) {
            let luma = min(
                255,
                (
                    54 * Int(storage[offset])
                    + 183 * Int(storage[offset + 1])
                    + 19 * Int(storage[offset + 2])
                    + 128
                ) >> 8
            )
            storage[offset] = UInt8(luma)
            storage[offset + 1] = UInt8(luma)
            storage[offset + 2] = UInt8(luma)
        }
    }
    return try image(
        bytes: bytes,
        width: source.width,
        height: source.height
    )
}

private func crop(
    _ source: CGImage,
    bounds: CGRect,
    padding: CGFloat = 12
) throws -> CGImage {
    let padded = CGRect(
        x: max(0, bounds.minX - padding),
        y: max(0, bounds.minY - padding),
        width: min(
            CGFloat(source.width),
            bounds.maxX + padding
        ) - max(0, bounds.minX - padding),
        height: min(
            CGFloat(source.height),
            bounds.maxY + padding
        ) - max(0, bounds.minY - padding)
    ).integral
    guard let output = source.cropping(to: padded) else {
        throw IndustrialL3NWV05RawReviewError.invalid(
            "could not crop occupied source bounds"
        )
    }
    return output
}

private func sheet(
    images: [CGImage],
    columns: Int,
    panel: CGSize,
    gutter: Int = 12
) throws -> CGImage {
    let rows = Int(ceil(Double(images.count) / Double(columns)))
    let width = Int(panel.width) * columns + gutter * (columns - 1)
    let height = Int(panel.height) * rows + gutter * (rows - 1)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo:
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw IndustrialL3NWV05RawReviewError.invalid(
            "could not allocate review sheet"
        )
    }
    context.setFillColor(
        CGColor(
            colorSpace: colorSpace,
            components: [0.12, 0.13, 0.14, 1]
        )!
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .none
    for (index, source) in images.enumerated() {
        let column = index % columns
        let row = index / columns
        context.draw(
            source,
            in: CGRect(
                x: column * (Int(panel.width) + gutter),
                y: height
                    - (row + 1) * Int(panel.height)
                    - row * gutter,
                width: Int(panel.width),
                height: Int(panel.height)
            )
        )
    }
    guard let output = context.makeImage() else {
        throw IndustrialL3NWV05RawReviewError.invalid(
            "could not create review sheet"
        )
    }
    return output
}

private func write(_ source: CGImage, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL3NWV05RawReviewError.invalid(
            "output must be absent: \(url.path)"
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
        throw IndustrialL3NWV05RawReviewError.invalid(
            "could not create PNG destination"
        )
    }
    CGImageDestinationAddImage(
        destination,
        source,
        [kCGImagePropertyPNGInterlaceType: 0] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL3NWV05RawReviewError.invalid(
            "could not finalize PNG"
        )
    }
}

private func json(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL3NWV05RawReviewError.invalid(
            "expected JSON object: \(url.path)"
        )
    }
    return object
}

private func reportFile(
    role: String,
    url: URL,
    root: URL
) throws -> [String: Any] {
    [
        "role": role,
        "file": relative(url, root: root),
        "sha256": digest(try Data(contentsOf: url)),
    ]
}

@main
enum BuildIndustrialL3NWV05RawReviewMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let output = URL(
            fileURLWithPath: try argument(
                "--output-directory",
                in: arguments
            )
        ).standardizedFileURL
        let north = try decode(
            id: "north-source-v05-run-a",
            url: root.appendingPathComponent(
                rawRoot + "/north/run-a/raw.png"
            )
        )
        let west = try decode(
            id: "west-source-v05-run-a",
            url: root.appendingPathComponent(
                rawRoot + "/west/run-a/raw.png"
            )
        )
        let northV04 = try decode(
            id: "north-source-v04",
            url: root.appendingPathComponent(
                v04Root + "/north-primary-v02/raw.png"
            )
        )
        let westV04 = try decode(
            id: "west-source-v04",
            url: root.appendingPathComponent(
                v04Root + "/west-primary/raw.png"
            )
        )
        let current = [north, west]
        let masked = try current.map(matte)
        let maskedV04 = try [northV04, westV04].map(matte)
        let occupied = try zip(masked, current).map {
            try crop($0.0, bounds: $0.1.nonChromaBounds)
        }
        let files: [(String, URL, CGImage)] = [
            (
                "sourceScaleColor",
                output.appendingPathComponent("SOURCE-SCALE-NW-COLOR.png"),
                try sheet(
                    images: current.map(\.image),
                    columns: 2,
                    panel: CGSize(width: 1536, height: 1024),
                    gutter: 0
                )
            ),
            (
                "sourceScaleGrayscale",
                output.appendingPathComponent(
                    "SOURCE-SCALE-NW-GRAYSCALE.png"
                ),
                try sheet(
                    images: try masked.map(grayscale),
                    columns: 2,
                    panel: CGSize(width: 1536, height: 1024),
                    gutter: 0
                )
            ),
            (
                "native2xColor",
                output.appendingPathComponent("NATIVE-2X-NW-COLOR.png"),
                try sheet(
                    images: masked,
                    columns: 2,
                    panel: CGSize(width: 432, height: 288)
                )
            ),
            (
                "native2xGrayscale",
                output.appendingPathComponent(
                    "NATIVE-2X-NW-GRAYSCALE.png"
                ),
                try sheet(
                    images: try masked.map(grayscale),
                    columns: 2,
                    panel: CGSize(width: 432, height: 288)
                )
            ),
            (
                "occupiedCropColor",
                output.appendingPathComponent("OCCUPIED-CROP-NW-COLOR.png"),
                try sheet(
                    images: occupied,
                    columns: 2,
                    panel: CGSize(width: 542, height: 533)
                )
            ),
            (
                "occupiedCropGrayscale",
                output.appendingPathComponent(
                    "OCCUPIED-CROP-NW-GRAYSCALE.png"
                ),
                try sheet(
                    images: try occupied.map(grayscale),
                    columns: 2,
                    panel: CGSize(width: 542, height: 533)
                )
            ),
            (
                "v04V05Native2xColor",
                output.appendingPathComponent(
                    "V04-V05-NATIVE-2X-COLOR.png"
                ),
                try sheet(
                    images: [
                        maskedV04[0], masked[0],
                        maskedV04[1], masked[1],
                    ],
                    columns: 2,
                    panel: CGSize(width: 432, height: 288)
                )
            ),
            (
                "v04V05Native2xGrayscale",
                output.appendingPathComponent(
                    "V04-V05-NATIVE-2X-GRAYSCALE.png"
                ),
                try sheet(
                    images: try [
                        maskedV04[0], masked[0],
                        maskedV04[1], masked[1],
                    ].map(grayscale),
                    columns: 2,
                    panel: CGSize(width: 432, height: 288)
                )
            ),
        ]
        for file in files {
            try write(file.2, to: file.1)
        }
        let northIdentityURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
                + "cohesion-a0-frontage-raw-v01/validation/"
                + "NORTH-RAW-IDENTITY.json"
        )
        let westIdentityURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
                + "cohesion-a0-frontage-raw-v01/validation/"
                + "WEST-RAW-IDENTITY.json"
        )
        let northIdentity = try json(northIdentityURL)
        let westIdentity = try json(westIdentityURL)
        guard
            northIdentity["validationPassed"] as? Bool == false,
            westIdentity["validationPassed"] as? Bool == false
        else {
            throw IndustrialL3NWV05RawReviewError.invalid(
                "expected retained repeat-gate failures"
            )
        }
        let provenanceFiles = [
            "north/run-a", "north/run-b", "north/run-c",
            "west/run-a", "west/run-b", "west/run-c",
        ].map {
            root.appendingPathComponent(
                rawRoot + "/\($0)/provenance.json"
            )
        }
        let provenance = try provenanceFiles.map(json)
        let expectedPivot = [768, 896]
        guard provenance.allSatisfy({
            $0["rendererSourceCommit"] as? String
                == "f7e67031f5fcd222e2755a75270685c54b4bd038"
                && $0["groundPivotSource"] as? [Int] == expectedPivot
                && $0["sourceRevision"] as? String == "source-v05"
                && $0["productionSelected"] as? Bool == false
        }) else {
            throw IndustrialL3NWV05RawReviewError.invalid(
                "provenance registration or authority drift"
            )
        }
        let reportURL = output.appendingPathComponent(
            "RAW-REVIEW-MANIFEST.json"
        )
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l03",
            "sourceRevision": "source-v05",
            "directions": ["north", "west"],
            "processCount": 6,
            "sceneKitProcessCount": 6,
            "normalizerProcessCount": 0,
            "rendererSourceCommit":
                "f7e67031f5fcd222e2755a75270685c54b4bd038",
            "rendererBinarySHA256":
                "e75dd4a3176318e91aeb95a4197846e321f32c2f582204ea13e839d75d3cdbf9",
            "descriptorSHA256": [
                "north":
                    "a147ad0a7023374b982a6677325da2912f45796616b03579e1a72eb7da4a6b61",
                "west":
                    "56e9aef896ef5eef435f76ff466f837ac022ff18edbc4e6bd3fa24cb583d78dc",
            ],
            "materialLibrarySHA256":
                "f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65",
            "primaryRaw": current.map {
                [
                    "direction": $0.id,
                    "file": relative($0.url, root: root),
                    "fileSHA256": $0.fileSHA256,
                    "decodedRGBASHA256": $0.decodedRGBASHA256,
                    "nonChromaBounds": [
                        Int($0.nonChromaBounds.minX),
                        Int($0.nonChromaBounds.minY),
                        Int($0.nonChromaBounds.maxX),
                        Int($0.nonChromaBounds.maxY),
                    ],
                ]
            },
            "northRepeatIdentityPassed": false,
            "westRepeatIdentityPassed": false,
            "rawCompletenessPassed": true,
            "primaryDirectionUniquenessPassed": true,
            "registrationProvenancePassed": true,
            "reviewPanelOrder":
                "North then West; v04/v05 comparisons use rows North/West and columns v04/v05",
            "reviewFiles": try files.map {
                try reportFile(role: $0.0, url: $0.1, root: root)
            },
            "identityReports": try [
                reportFile(
                    role: "northRepeatIdentity",
                    url: northIdentityURL,
                    root: root
                ),
                reportFile(
                    role: "westRepeatIdentity",
                    url: westIdentityURL,
                    root: root
                ),
            ],
            "finalDisposition": "REJECTED_REPEAT_IDENTITY",
            "sourceAuthority": false,
            "productionSelected": false,
            "normalizationPerformed": false,
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        guard !FileManager.default.fileExists(atPath: reportURL.path) else {
            throw IndustrialL3NWV05RawReviewError.invalid(
                "manifest output must be absent"
            )
        }
        try data.write(to: reportURL, options: .atomic)
    }
}
