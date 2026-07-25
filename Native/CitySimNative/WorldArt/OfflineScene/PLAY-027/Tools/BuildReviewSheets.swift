import CoreGraphics
import CoreImage
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ReviewSheetError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-review-sheets --repository-root <path> --north <raw-png> --east <raw-png> --south <raw-png> --west <raw-png> --north-normalized <block-png> --east-normalized <block-png> --south-normalized <block-png> --west-normalized <block-png> --source-sheet <png> --actual-sheet <png> --grayscale-sheet <png> --footprint-sheet <png> --footprint-grayscale-sheet <png> --zoom-sheet <png> --manifest <json>"
        case let .invalid(message):
            return message
        }
    }
}

func sheetArgument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw ReviewSheetError.arguments
    }
    return arguments[index + 1]
}

func sheetSHA256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map {
        String(format: "%02x", $0)
    }.joined()
}

func sheetRelativePath(_ url: URL, repositoryRoot: URL) -> String {
    let prefix = repositoryRoot.path + "/"
    guard url.path.hasPrefix(prefix) else {
        return url.path
    }
    return String(url.path.dropFirst(prefix.count))
}

func loadImage(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw ReviewSheetError.invalid("could not decode \(url.path)")
    }
    return image
}

func writeSheetPNG(_ image: CGImage, to url: URL) throws {
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
        throw ReviewSheetError.invalid("could not create \(url.path)")
    }
    let properties: [CFString: Any] = [
        kCGImagePropertyPNGDictionary: [
            kCGImagePropertyPNGInterlaceType: 0,
        ],
        kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
        kCGImagePropertyDepth: 8,
    ]
    CGImageDestinationAddImage(
        destination,
        image,
        properties as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
        throw ReviewSheetError.invalid("could not finalize \(url.path)")
    }
}

func reviewAlphaImage(_ image: CGImage) throws -> CGImage {
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    return try bytes.withUnsafeMutableBytes { storage in
        guard let context = CGContext(
            data: storage.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw ReviewSheetError.invalid(
                "could not allocate review alpha context"
            )
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
        for pixel in stride(from: 0, to: storage.count, by: 4) {
            let red = Int(storage[pixel])
            let green = Int(storage[pixel + 1])
            let blue = Int(storage[pixel + 2])
            if red == 255 && green == 0 && blue == 255 {
                storage[pixel] = 0
                storage[pixel + 1] = 0
                storage[pixel + 2] = 0
                storage[pixel + 3] = 0
            } else if
                green == 0,
                abs(red - blue) <= 8,
                red >= 96,
                blue >= 96
            {
                let alpha = max(0, 255 - max(red, blue))
                storage[pixel] = 0
                storage[pixel + 1] = 0
                storage[pixel + 2] = 0
                storage[pixel + 3] = UInt8(alpha)
            }
        }
        guard let output = context.makeImage() else {
            throw ReviewSheetError.invalid(
                "could not create review alpha image"
            )
        }
        return output
    }
}

func grayscaleImage(_ image: CGImage) throws -> CGImage {
    let context = CIContext(options: [
        .useSoftwareRenderer: true,
        .cacheIntermediates: false,
        .workingColorSpace: CGColorSpace(
            name: CGColorSpace.extendedSRGB
        )!,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    ])
    guard let filter = CIFilter(name: "CIColorControls") else {
        throw ReviewSheetError.invalid("CIColorControls unavailable")
    }
    filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
    filter.setValue(0, forKey: kCIInputSaturationKey)
    filter.setValue(1, forKey: kCIInputContrastKey)
    filter.setValue(0, forKey: kCIInputBrightnessKey)
    guard
        let output = filter.outputImage,
        let result = context.createCGImage(
            output,
            from: CGRect(
                x: 0,
                y: 0,
                width: image.width,
                height: image.height
            )
        )
    else {
        throw ReviewSheetError.invalid("grayscale conversion failed")
    }
    return result
}

func buildSheet(
    images: [CGImage],
    panelSize: CGSize,
    background: [CGFloat],
    interpolation: CGInterpolationQuality
) throws -> CGImage {
    let width = Int(panelSize.width) * 2
    let height = Int(panelSize.height) * 2
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw ReviewSheetError.invalid("could not allocate review sheet")
    }
    context.setFillColor(
        CGColor(colorSpace: colorSpace, components: background)!
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = interpolation
    let origins = [
        CGPoint(x: 0, y: panelSize.height),
        CGPoint(x: panelSize.width, y: panelSize.height),
        CGPoint(x: 0, y: 0),
        CGPoint(x: panelSize.width, y: 0),
    ]
    for (image, origin) in zip(images, origins) {
        context.draw(
            image,
            in: CGRect(origin: origin, size: panelSize)
        )
    }
    guard let output = context.makeImage() else {
        throw ReviewSheetError.invalid("could not create review sheet")
    }
    return output
}

func cropImages(
    _ images: [CGImage],
    sourceRect: CGRect
) throws -> [CGImage] {
    try images.map { image in
        guard let cropped = image.cropping(to: sourceRect) else {
            throw ReviewSheetError.invalid(
                "could not crop fixed registered review envelope"
            )
        }
        return cropped
    }
}

@main
enum BuildReviewSheetsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try sheetArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let directions = ["north", "east", "south", "west"]
        let inputURLs = try directions.map { direction in
            URL(
                fileURLWithPath: try sheetArgument(
                    "--\(direction)",
                    in: arguments
                )
            ).standardizedFileURL
        }
        let normalizedInputURLs = try directions.map { direction in
            URL(
                fileURLWithPath: try sheetArgument(
                    "--\(direction)-normalized",
                    in: arguments
                )
            ).standardizedFileURL
        }
        let sourceSheetURL = URL(
            fileURLWithPath: try sheetArgument(
                "--source-sheet",
                in: arguments
            )
        ).standardizedFileURL
        let actualSheetURL = URL(
            fileURLWithPath: try sheetArgument(
                "--actual-sheet",
                in: arguments
            )
        ).standardizedFileURL
        let grayscaleSheetURL = URL(
            fileURLWithPath: try sheetArgument(
                "--grayscale-sheet",
                in: arguments
            )
        ).standardizedFileURL
        let footprintSheetURL = URL(
            fileURLWithPath: try sheetArgument(
                "--footprint-sheet",
                in: arguments
            )
        ).standardizedFileURL
        let footprintGrayscaleSheetURL = URL(
            fileURLWithPath: try sheetArgument(
                "--footprint-grayscale-sheet",
                in: arguments
            )
        ).standardizedFileURL
        let zoomSheetURL = URL(
            fileURLWithPath: try sheetArgument(
                "--zoom-sheet",
                in: arguments
            )
        ).standardizedFileURL
        let manifestURL = URL(
            fileURLWithPath: try sheetArgument(
                "--manifest",
                in: arguments
            )
        ).standardizedFileURL

        let rawImages = try inputURLs.map(loadImage)
        guard rawImages.allSatisfy({
            $0.width == 1536 && $0.height == 1024
        }) else {
            throw ReviewSheetError.invalid(
                "all source panels must be 1536 x 1024"
            )
        }
        let reviewImages = try normalizedInputURLs.map(loadImage)
        guard reviewImages.allSatisfy({
            $0.width == 1024 && $0.height == 683
        }) else {
            throw ReviewSheetError.invalid(
                "all normalized review panels must be 1024 x 683 block LOD PNGs"
            )
        }
        let grayscaleImages = try reviewImages.map(grayscaleImage)
        let registeredReviewRect = CGRect(
            x: 341,
            y: 341,
            width: 342,
            height: 256
        )
        let registeredReviewImages = try cropImages(
            reviewImages,
            sourceRect: registeredReviewRect
        )
        let registeredGrayscaleImages = try cropImages(
            grayscaleImages,
            sourceRect: registeredReviewRect
        )
        let sourceSheet = try buildSheet(
            images: rawImages,
            panelSize: CGSize(width: 1536, height: 1024),
            background: [1, 0, 1, 1],
            interpolation: .none
        )
        let actualSheet = try buildSheet(
            images: reviewImages,
            panelSize: CGSize(width: 432, height: 288),
            background: [0.14, 0.15, 0.16, 1],
            interpolation: .high
        )
        let grayscaleSheet = try buildSheet(
            images: grayscaleImages,
            panelSize: CGSize(width: 432, height: 288),
            background: [0.14, 0.14, 0.14, 1],
            interpolation: .high
        )
        let footprintSheet = try buildSheet(
            images: registeredReviewImages,
            panelSize: CGSize(width: 144, height: 108),
            background: [0.14, 0.15, 0.16, 1],
            interpolation: .none
        )
        let zoomSheet = try buildSheet(
            images: registeredReviewImages,
            panelSize: CGSize(width: 512, height: 384),
            background: [0.14, 0.15, 0.16, 1],
            interpolation: .none
        )
        let footprintGrayscaleSheet = try buildSheet(
            images: registeredGrayscaleImages,
            panelSize: CGSize(width: 144, height: 108),
            background: [0.14, 0.14, 0.14, 1],
            interpolation: .none
        )
        try writeSheetPNG(sourceSheet, to: sourceSheetURL)
        try writeSheetPNG(actualSheet, to: actualSheetURL)
        try writeSheetPNG(grayscaleSheet, to: grayscaleSheetURL)
        try writeSheetPNG(footprintSheet, to: footprintSheetURL)
        try writeSheetPNG(
            footprintGrayscaleSheet,
            to: footprintGrayscaleSheetURL
        )
        try writeSheetPNG(zoomSheet, to: zoomSheetURL)

        let inputRecords = try zip(directions, inputURLs).map {
            direction, url in
            [
                "direction": direction,
                "file": sheetRelativePath(
                    url,
                    repositoryRoot: repositoryRoot
                ),
                "sha256": try sheetSHA256(url),
            ]
        }
        let normalizedInputRecords = try zip(
            directions,
            normalizedInputURLs
        ).map { direction, url in
            [
                "direction": direction,
                "file": sheetRelativePath(
                    url,
                    repositoryRoot: repositoryRoot
                ),
                "sha256": try sheetSHA256(url),
                "pixels": [1024, 683],
                "lod": "block",
            ]
        }
        let manifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "calibrationID":
                "residential-l01-variant-0-directional-v03",
            "directionOrder": directions,
            "layout": [
                "columns": 2,
                "rows": 2,
                "rowMajor": directions,
                "labels": false,
            ],
            "inputs": inputRecords,
            "normalizedAlphaInputs": normalizedInputRecords,
            "sourceScale": [
                "file": sheetRelativePath(
                    sourceSheetURL,
                    repositoryRoot: repositoryRoot
                ),
                "sha256": try sheetSHA256(sourceSheetURL),
                "sheetPixels": [3072, 2048],
                "panelPixels": [1536, 1024],
                "presentation": "unaltered raw #ff00ff inspection",
            ],
            "native2xActualScale": [
                "file": sheetRelativePath(
                    actualSheetURL,
                    repositoryRoot: repositoryRoot
                ),
                "sha256": try sheetSHA256(actualSheetURL),
                "sheetPixels": [864, 576],
                "panelPixels": [432, 288],
                "scale": 0.421875,
                "presentation":
                    "existing deterministic normalized-alpha block output on neutral background",
            ],
            "grayscaleRecognition": [
                "file": sheetRelativePath(
                    grayscaleSheetURL,
                    repositoryRoot: repositoryRoot
                ),
                "sha256": try sheetSHA256(grayscaleSheetURL),
                "sheetPixels": [864, 576],
                "conversion":
                    "Core Image CIColorControls saturation=0",
            ],
            "registeredFootprintActualScale": [
                "file": sheetRelativePath(
                    footprintSheetURL,
                    repositoryRoot: repositoryRoot
                ),
                "sha256": try sheetSHA256(footprintSheetURL),
                "normalizedBlockCrop": [341, 341, 342, 256],
                "correspondingRawSourceCrop": [512, 512, 512, 384],
                "sheetPixels": [288, 216],
                "panelPixels": [144, 108],
                "scale": 0.421875,
                "interpolation": "none",
                "presentation":
                    "fixed descriptor-derived normalized-alpha tile and vertical sprite envelope at native-2x scale",
            ],
            "registeredFootprintGrayscale": [
                "file": sheetRelativePath(
                    footprintGrayscaleSheetURL,
                    repositoryRoot: repositoryRoot
                ),
                "sha256": try sheetSHA256(
                    footprintGrayscaleSheetURL
                ),
                "normalizedBlockCrop": [341, 341, 342, 256],
                "correspondingRawSourceCrop": [512, 512, 512, 384],
                "sheetPixels": [288, 216],
                "panelPixels": [144, 108],
                "scale": 0.421875,
                "interpolation": "none",
                "conversion":
                    "Core Image CIColorControls saturation=0",
            ],
            "registeredFootprintZoom": [
                "file": sheetRelativePath(
                    zoomSheetURL,
                    repositoryRoot: repositoryRoot
                ),
                "sha256": try sheetSHA256(zoomSheetURL),
                "normalizedBlockCrop": [341, 341, 342, 256],
                "correspondingRawSourceCrop": [512, 512, 512, 384],
                "sheetPixels": [1024, 768],
                "panelPixels": [512, 384],
                "scale": 1.497076,
                "interpolation": "none",
                "presentation":
                    "fixed descriptor-derived normalized-alpha envelope enlarged with nearest-neighbor review scaling",
            ],
            "previewAlphaIsNormalizedOutput": true,
            "reviewStatus": "pending-independent-source-art-review",
            "productionSelected": false,
        ]
        let manifestData = try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var terminated = manifestData
        terminated.append(0x0a)
        try FileManager.default.createDirectory(
            at: manifestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try terminated.write(to: manifestURL, options: .atomic)
    }
}
