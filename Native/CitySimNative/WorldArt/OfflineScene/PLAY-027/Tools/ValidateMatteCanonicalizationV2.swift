import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private enum ValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-matte-canonicalization-v2 --repository-root <path> --output-directory <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct Raster {
    let width: Int
    let height: Int
    let rgba: [UInt8]
    let fileSHA256: String
    let decodedRGBASHA256: String
}

private struct Bounds: Equatable {
    let minimumX: Int
    let minimumY: Int
    let maximumX: Int
    let maximumY: Int

    var array: [Int] {
        [minimumX, minimumY, maximumX, maximumY]
    }
}

private let rawRelativePath =
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    + "crucible-gantry-v17-north-raw-probe/diagnostics/north/run-a/raw.png"
private let descriptorRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v17-north-prepixel/artifact/"
    + "scenes/industrial_l04/variant-0/n/scene.json"
private let materialRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v17-north-prepixel/materials/"
    + "industrial-l04-crucible-gantry-v14-north-prepixel.json"
private let shippingManifestRelativePath =
    "Native/CitySimNative/Sources/CitySimNative/Resources/"
    + "WorldAssets.atlas/generated-v4-manifest.json"
private let l3ManifestRelativePath =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "source-v06-complete-family-v01/FAMILY-MANIFEST.json"
private let implementationRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/"
    + "MatteCanonicalizationV2.swift"
private let validatorRelativePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
    + "ValidateMatteCanonicalizationV2.swift"

private let expectedRawFileSHA =
    "9aea278d4fe7640a4dd126c4393fd284f2849f80168b5e62d6e8dbe2cf75c5d7"
private let expectedCoordinateSHA =
    "824601712493f3e8b402b69055267a10bfdd8d80254e4d04b8c91f58d6df4109"
private let expectedCleanedDecodedSHA =
    "d5ef428818b2ea5ba5e44c3d46f30c06b69589964ed37f53843a6976128c87ad"

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        index + 1 < CommandLine.arguments.count
    else {
        throw ValidationError.arguments
    }
    return CommandLine.arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func digest(_ url: URL) throws -> String {
    digest(try Data(contentsOf: url))
}

private func decode(_ url: URL) throws -> Raster {
    let fileData = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        )
    else {
        throw ValidationError.invalid("could not decode \(url.path)")
    }
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try rgba.withUnsafeMutableBytes { storage in
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
            throw ValidationError.invalid("could not allocate RGBA decoder")
        }
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
    return Raster(
        width: image.width,
        height: image.height,
        rgba: rgba,
        fileSHA256: digest(fileData),
        decodedRGBASHA256: digest(Data(rgba))
    )
}

private func jsonObject(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw ValidationError.invalid("expected JSON object at \(url.path)")
    }
    return object
}

private func writeJSON(_ object: Any, to url: URL) throws {
    let data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys]
    )
    var terminated = data
    terminated.append(0x0A)
    try terminated.write(to: url, options: .atomic)
}

private func writePNG(
    rgba: [UInt8],
    width: Int,
    height: Int,
    to url: URL
) throws {
    var storage = rgba
    let image = try storage.withUnsafeMutableBytes { bytes -> CGImage in
        guard
            let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo:
                    CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            let image = context.makeImage()
        else {
            throw ValidationError.invalid("could not create canonical image")
        }
        return image
    }
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw ValidationError.invalid("could not create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw ValidationError.invalid("could not finalize PNG")
    }
}

private func isExactOrNearChroma(_ rgba: [UInt8], offset: Int) -> Bool {
    guard rgba[offset + 3] > 0 else { return false }
    let exact =
        rgba[offset] == 255
        && rgba[offset + 1] == 0
        && rgba[offset + 2] == 255
    let near =
        rgba[offset] >= 240
        && rgba[offset + 1] <= 16
        && rgba[offset + 2] >= 240
    return exact || near
}

private func nearChromaCoordinates(
    _ raster: Raster
) -> [(x: Int, y: Int)] {
    var result: [(x: Int, y: Int)] = []
    for y in 0..<raster.height {
        for x in 0..<raster.width {
            let offset = (y * raster.width + x) * 4
            let exact =
                raster.rgba[offset] == 255
                && raster.rgba[offset + 1] == 0
                && raster.rgba[offset + 2] == 255
                && raster.rgba[offset + 3] > 0
            let near =
                !exact
                && raster.rgba[offset] >= 240
                && raster.rgba[offset + 1] <= 16
                && raster.rgba[offset + 2] >= 240
                && raster.rgba[offset + 3] > 0
            if near {
                result.append((x, y))
            }
        }
    }
    return result
}

private func coordinateSHA(_ coordinates: [(x: Int, y: Int)]) -> String {
    let body = coordinates.map { "\($0.x),\($0.y)" }.joined(separator: "\n")
        + "\n"
    return digest(Data(body.utf8))
}

private func alphaBounds(
    rgba: [UInt8],
    width: Int,
    height: Int
) -> Bounds? {
    var minimumX = width
    var minimumY = height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<height {
        for x in 0..<width {
            guard rgba[(y * width + x) * 4 + 3] > 0 else { continue }
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    guard maximumX >= 0 else { return nil }
    return Bounds(
        minimumX: minimumX,
        minimumY: minimumY,
        maximumX: maximumX,
        maximumY: maximumY
    )
}

private func request(
    changing keyPath: WritableKeyPath<PLAY027MatteCanonicalizationV2Request, String>,
    to value: String,
    descriptorData: Data,
    materialLibraryData: Data
) -> PLAY027MatteCanonicalizationV2Request {
    var candidate = validRequest(
        descriptorData: descriptorData,
        materialLibraryData: materialLibraryData
    )
    candidate[keyPath: keyPath] = value
    return candidate
}

private func validRequest(
    descriptorData: Data,
    materialLibraryData: Data,
    width: Int = PLAY027MatteCanonicalizationV2.width,
    height: Int = PLAY027MatteCanonicalizationV2.height
) -> PLAY027MatteCanonicalizationV2Request {
    PLAY027MatteCanonicalizationV2Request(
        pipelineName: PLAY027MatteCanonicalizationV2.pipelineName,
        descriptorData: descriptorData,
        materialLibraryData: materialLibraryData,
        descriptorSHA256: PLAY027MatteCanonicalizationV2.descriptorSHA256,
        materialLibrarySHA256:
            PLAY027MatteCanonicalizationV2.materialLibrarySHA256,
        width: width,
        height: height
    )
}

private func requireRejected(
    name: String,
    request: PLAY027MatteCanonicalizationV2Request,
    rgba: [UInt8]
) throws -> [String: Any] {
    do {
        _ = try PLAY027MatteCanonicalizationV2.canonicalize(
            rgba: rgba,
            request: request
        )
        throw ValidationError.invalid("negative case admitted: \(name)")
    } catch let error as PLAY027MatteCanonicalizationV2Error {
        return [
            "name": name,
            "admissionInvoked": true,
            "rejected": true,
            "reason": error.description,
        ]
    }
}

private func repositoryRelativeRawPath(_ manifestPath: String) -> String {
    if manifestPath.hasPrefix("CitySimNative/") {
        return "Native/" + manifestPath
    }
    return manifestPath
}

private func acceptedMasterInventory(
    repositoryRoot: URL,
    descriptorData: Data,
    materialLibraryData: Data
) throws -> [[String: Any]] {
    let shipping = try jsonObject(
        repositoryRoot.appendingPathComponent(shippingManifestRelativePath)
    )
    guard let assets = shipping["assets"] as? [[String: Any]] else {
        throw ValidationError.invalid("shipping manifest assets missing")
    }
    let acceptedPattern = try NSRegularExpression(
        pattern:
            "^(residential|commercial)_l0[1-4]_v0_(north|east|south|west)$"
            + "|^industrial_l0[12]_v0_(north|east|south|west)$"
    )
    var inventory: [[String: Any]] = []
    for asset in assets {
        guard
            let logicalID = asset["logical_id"] as? String,
            acceptedPattern.firstMatch(
                in: logicalID,
                range: NSRange(logicalID.startIndex..., in: logicalID)
            ) != nil,
            let manifestFile = asset["raw_source_file"] as? String,
            let expectedSHA = asset["source_sha256"] as? String
        else {
            continue
        }
        let file = repositoryRelativeRawPath(manifestFile)
        let fileURL = repositoryRoot.appendingPathComponent(file)
        let actualSHA = try digest(fileURL)
        guard actualSHA == expectedSHA else {
            throw ValidationError.invalid(
                "accepted master hash drift: \(logicalID)"
            )
        }
        let acceptedRaster = try decode(fileURL)
        let rejection = try requireRejected(
            name: logicalID,
            request: validRequest(
                descriptorData: descriptorData,
                materialLibraryData: materialLibraryData,
                width: acceptedRaster.width,
                height: acceptedRaster.height
            ),
            rgba: acceptedRaster.rgba
        )
        inventory.append([
            "logicalID": logicalID,
            "file": file,
            "sha256Before": actualSHA,
            "sha256After": actualSHA,
            "byteIdentical": true,
            "decodedRGBASHA256": acceptedRaster.decodedRGBASHA256,
            "matteV2Admission": rejection,
        ])
    }
    guard inventory.count == 40 else {
        throw ValidationError.invalid(
            "expected 40 accepted shipping R/C/I1-I2 masters, got \(inventory.count)"
        )
    }

    let l3 = try jsonObject(
        repositoryRoot.appendingPathComponent(l3ManifestRelativePath)
    )
    guard let rawMasters = l3["rawMasters"] as? [[String: Any]] else {
        throw ValidationError.invalid("accepted Industrial L3 masters missing")
    }
    for master in rawMasters {
        guard
            let direction = master["direction"] as? String,
            let file = master["file"] as? String,
            let expectedSHA = master["fileSHA256"] as? String
        else {
            throw ValidationError.invalid("Industrial L3 master malformed")
        }
        let fileURL = repositoryRoot.appendingPathComponent(file)
        let actualSHA = try digest(fileURL)
        guard actualSHA == expectedSHA else {
            throw ValidationError.invalid(
                "accepted Industrial L3 \(direction) hash drift"
            )
        }
        let acceptedRaster = try decode(fileURL)
        let rejection = try requireRejected(
            name: "industrial_l03_v0_\(direction)",
            request: validRequest(
                descriptorData: descriptorData,
                materialLibraryData: materialLibraryData,
                width: acceptedRaster.width,
                height: acceptedRaster.height
            ),
            rgba: acceptedRaster.rgba
        )
        inventory.append([
            "logicalID": "industrial_l03_v0_\(direction)",
            "file": file,
            "sha256Before": actualSHA,
            "sha256After": actualSHA,
            "byteIdentical": true,
            "decodedRGBASHA256": acceptedRaster.decodedRGBASHA256,
            "matteV2Admission": rejection,
        ])
    }
    guard inventory.count == 44 else {
        throw ValidationError.invalid(
            "expected 44 accepted R/C/Industrial L1-L3 masters"
        )
    }
    return inventory.sorted {
        ($0["logicalID"] as? String ?? "") < ($1["logicalID"] as? String ?? "")
    }
}

@main
private enum ValidateMatteCanonicalizationV2 {
    static func main() throws {
        let repositoryRoot = URL(
            fileURLWithPath: try argument("--repository-root")
        ).standardizedFileURL
        let outputDirectory = URL(
            fileURLWithPath: try argument("--output-directory")
        ).standardizedFileURL
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: outputDirectory.path) else {
            throw ValidationError.invalid("output directory must be absent")
        }
        try fileManager.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let rawURL = repositoryRoot.appendingPathComponent(rawRelativePath)
        let descriptorURL = repositoryRoot.appendingPathComponent(
            descriptorRelativePath
        )
        let materialURL = repositoryRoot.appendingPathComponent(
            materialRelativePath
        )
        let descriptorData = try Data(contentsOf: descriptorURL)
        let materialData = try Data(contentsOf: materialURL)
        let raster = try decode(rawURL)
        guard
            raster.fileSHA256 == expectedRawFileSHA,
            digest(descriptorData)
                == PLAY027MatteCanonicalizationV2.descriptorSHA256,
            digest(materialData)
                == PLAY027MatteCanonicalizationV2.materialLibrarySHA256
        else {
            throw ValidationError.invalid("immutable v17 input binding drift")
        }

        let nearCoordinates = nearChromaCoordinates(raster)
        guard
            nearCoordinates.count == 1_807,
            coordinateSHA(nearCoordinates) == expectedCoordinateSHA
        else {
            throw ValidationError.invalid("v17 near-chroma mask drift")
        }

        let result = try PLAY027MatteCanonicalizationV2.canonicalize(
            rgba: raster.rgba,
            request: validRequest(
                descriptorData: descriptorData,
                materialLibraryData: materialData
            )
        )
        guard
            result.binding.decodedRGBASHA256
                == raster.decodedRGBASHA256,
            result.binding.descriptorSHA256 == digest(descriptorData),
            result.binding.materialLibrarySHA256 == digest(materialData),
            !result.binding.authoredPaletteAllowsMagenta,
            digest(Data(result.rgba)) == expectedCleanedDecodedSHA
        else {
            throw ValidationError.invalid("canonical decoded output drift")
        }

        var retainedSupport = raster.rgba
        for index in 0..<result.borderConnectedMatteMask.count
        where result.borderConnectedMatteMask[index] {
            let offset = index * 4
            retainedSupport[offset] = 0
            retainedSupport[offset + 1] = 0
            retainedSupport[offset + 2] = 0
            retainedSupport[offset + 3] = 0
        }
        let retainedBounds = alphaBounds(
            rgba: retainedSupport,
            width: raster.width,
            height: raster.height
        )
        let outputBounds = alphaBounds(
            rgba: result.rgba,
            width: raster.width,
            height: raster.height
        )
        guard
            retainedBounds == outputBounds,
            outputBounds?.array == [512, 525, 1_023, 895]
        else {
            throw ValidationError.invalid("occupied bounds changed")
        }

        var chromaAtNonzeroAlpha = 0
        var hiddenRGB = 0
        var changesOutsidePredicate = 0
        for index in 0..<(raster.width * raster.height) {
            let offset = index * 4
            if isExactOrNearChroma(result.rgba, offset: offset) {
                chromaAtNonzeroAlpha += 1
            }
            if
                result.rgba[offset + 3] == 0,
                result.rgba[offset] != 0
                    || result.rgba[offset + 1] != 0
                    || result.rgba[offset + 2] != 0
            {
                hiddenRGB += 1
            }
            if
                result.changedMask[index],
                !result.borderConnectedMatteMask[index],
                !result.retainedDespillMask[index]
            {
                changesOutsidePredicate += 1
            }
        }
        guard
            chromaAtNonzeroAlpha == 0,
            hiddenRGB == 0,
            changesOutsidePredicate == 0
        else {
            throw ValidationError.invalid("canonical output contract failed")
        }

        let canonicalURL = outputDirectory.appendingPathComponent(
            "V17-CANONICAL-TRANSPARENT.png"
        )
        try writePNG(
            rgba: result.rgba,
            width: raster.width,
            height: raster.height,
            to: canonicalURL
        )

        let negativeCases: [(String, PLAY027MatteCanonicalizationV2Request)] = [
            (
                "pipeline",
                request(
                    changing: \.pipelineName,
                    to: "matte-v1",
                    descriptorData: descriptorData,
                    materialLibraryData: materialData
                )
            ),
            (
                "descriptorSHA256",
                request(
                    changing: \.descriptorSHA256,
                    to: String(repeating: "0", count: 64),
                    descriptorData: descriptorData,
                    materialLibraryData: materialData
                )
            ),
            (
                "materialLibrarySHA256",
                request(
                    changing: \.materialLibrarySHA256,
                    to: String(repeating: "1", count: 64),
                    descriptorData: descriptorData,
                    materialLibraryData: materialData
                )
            ),
        ]
        var negativeResults: [[String: Any]] = []
        for item in negativeCases {
            negativeResults.append(
                try requireRejected(
                    name: item.0,
                    request: item.1,
                    rgba: raster.rgba
                )
            )
        }
        let wrongDimensions = PLAY027MatteCanonicalizationV2Request(
            pipelineName: PLAY027MatteCanonicalizationV2.pipelineName,
            descriptorData: descriptorData,
            materialLibraryData: materialData,
            descriptorSHA256:
                PLAY027MatteCanonicalizationV2.descriptorSHA256,
            materialLibrarySHA256:
                PLAY027MatteCanonicalizationV2.materialLibrarySHA256,
            width: 1_535,
            height: PLAY027MatteCanonicalizationV2.height
        )
        negativeResults.append(
            try requireRejected(
                name: "dimensions",
                request: wrongDimensions,
                rgba: raster.rgba
            )
        )
        var staleRGBA = raster.rgba
        staleRGBA[0] ^= 1
        negativeResults.append(
            try requireRejected(
                name: "mutatedRGBAWithStaleMetadata",
                request: validRequest(
                    descriptorData: descriptorData,
                    materialLibraryData: materialData
                ),
                rgba: staleRGBA
            )
        )
        var staleDescriptorData = descriptorData
        staleDescriptorData.append(0x20)
        negativeResults.append(
            try requireRejected(
                name: "mutatedDescriptorBytesWithStaleMetadata",
                request: validRequest(
                    descriptorData: staleDescriptorData,
                    materialLibraryData: materialData
                ),
                rgba: raster.rgba
            )
        )
        var staleMaterialData = materialData
        staleMaterialData.append(0x20)
        negativeResults.append(
            try requireRejected(
                name: "mutatedMaterialBytesWithStaleMetadata",
                request: validRequest(
                    descriptorData: descriptorData,
                    materialLibraryData: staleMaterialData
                ),
                rgba: raster.rgba
            )
        )
        negativeResults.append(
            try requireRejected(
                name: "rgbaByteCount",
                request: validRequest(
                    descriptorData: descriptorData,
                    materialLibraryData: materialData
                ),
                rgba: Array(raster.rgba.dropLast(4))
            )
        )

        let acceptedInventory = try acceptedMasterInventory(
            repositoryRoot: repositoryRoot,
            descriptorData: descriptorData,
            materialLibraryData: materialData
        )
        try writeJSON(
            [
                "taskID": "PLAY-027",
                "contract": "CONTRACT-019",
                "pipeline": PLAY027MatteCanonicalizationV2.pipelineName,
                "acceptedMasterCount": acceptedInventory.count,
                "allByteIdentical": true,
                "allAdmissionPathsInvoked": true,
                "allRejectedByVersionGate": true,
                "masters": acceptedInventory,
            ],
            to: outputDirectory.appendingPathComponent(
                "ACCEPTED-MASTER-REGRESSION.json"
            )
        )

        let descriptor = try jsonObject(descriptorURL)
        let registration = descriptor["registration"] as? [String: Any] ?? [:]
        let changedCount = result.changedMask.filter { $0 }.count
        let matteCount = result.borderConnectedMatteMask.filter { $0 }.count
        let despillCount = result.retainedDespillMask.filter { $0 }.count
        let report: [String: Any] = [
            "taskID": "PLAY-027",
            "contract": "CONTRACT-019",
            "artifact": "matte-canonicalization-v2-regression-v01",
            "pipeline": PLAY027MatteCanonicalizationV2.pipelineName,
            "diagnosticOnly": true,
            "sourceAuthority": false,
            "productionSelected": false,
            "disposition": "PASS_MATTE_CANONICALIZATION_V2",
            "processCounts": [
                "metal": 0,
                "sceneKit": 0,
                "raw": 0,
                "normalizer": 0,
            ],
            "input": [
                "file": rawRelativePath,
                "fileSHA256": raster.fileSHA256,
                "decodedRGBASHA256": raster.decodedRGBASHA256,
                "nearChromaCount": nearCoordinates.count,
                "nearChromaCoordinateSHA256": coordinateSHA(nearCoordinates),
            ],
            "binding": [
                "descriptor": descriptorRelativePath,
                "descriptorSHA256":
                    PLAY027MatteCanonicalizationV2.descriptorSHA256,
                "materialLibrary": materialRelativePath,
                "materialLibrarySHA256":
                    result.binding.materialLibrarySHA256,
                "authoredPaletteAllowsMagenta":
                    result.binding.authoredPaletteAllowsMagenta,
                "bindingDerivedFromActualBytes": true,
            ],
            "output": [
                "file": "V17-CANONICAL-TRANSPARENT.png",
                "fileSHA256": try digest(canonicalURL),
                "decodedRGBASHA256": digest(Data(result.rgba)),
                "borderConnectedMattePixelCount": matteCount,
                "retainedDespillPixelCount": despillCount,
                "changedPixelCount": changedCount,
                "changedOutsidePredicatePixelCount": changesOutsidePredicate,
                "exactOrNearChromaAtNonzeroAlpha": chromaAtNonzeroAlpha,
                "hiddenRGBAtAlphaZero": hiddenRGB,
                "occupiedBounds": outputBounds?.array ?? [],
                "retainedSupportBounds": retainedBounds?.array ?? [],
                "boundsPreserved": retainedBounds == outputBounds,
            ],
            "registration": [
                "groundPivotSource": registration["groundPivotSource"] ?? [],
                "frontageSocketSource":
                    registration["frontageSocketSource"] ?? [],
                "frontageEdgeSource":
                    registration["frontageEdgeSource"] ?? [],
                "contactPolygonWorld":
                    registration["contactPolygonWorld"] ?? [],
                "unchanged": true,
            ],
            "negativeCases": negativeResults,
            "acceptedMasterRegression": [
                "count": acceptedInventory.count,
                "allByteIdentical": true,
                "allAdmissionPathsInvoked": true,
                "allRejectedByVersionGate": true,
                "file": "ACCEPTED-MASTER-REGRESSION.json",
            ],
            "tool": [
                "implementation": implementationRelativePath,
                "implementationSHA256": try digest(
                    repositoryRoot.appendingPathComponent(
                        implementationRelativePath
                    )
                ),
                "validator": validatorRelativePath,
                "validatorSHA256": try digest(
                    repositoryRoot.appendingPathComponent(
                        validatorRelativePath
                    )
                ),
                "binarySHA256": try digest(
                    URL(fileURLWithPath: CommandLine.arguments[0])
                ),
                "compileCommand":
                    "xcrun swiftc -parse-as-library -warnings-as-errors -module-cache-path <task-local-cache> MatteCanonicalizationV2.swift ValidateMatteCanonicalizationV2.swift -framework CoreGraphics -framework ImageIO -framework UniformTypeIdentifiers -o validate-matte-canonicalization-v2",
            ],
        ]
        try writeJSON(
            report,
            to: outputDirectory.appendingPathComponent(
                "MATTE-V2-VALIDATION.json"
            )
        )
        print("PASS matte-canonicalization-v2")
        print("near-chroma-count=\(nearCoordinates.count)")
        print("coordinate-sha256=\(coordinateSHA(nearCoordinates))")
        print("canonical-decoded-sha256=\(digest(Data(result.rgba)))")
        print("accepted-master-count=\(acceptedInventory.count)")
    }
}
