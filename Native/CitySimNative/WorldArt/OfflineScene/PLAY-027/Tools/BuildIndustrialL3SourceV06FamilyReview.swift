import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private struct L3V06Direction {
    let direction: String
    let revision: String
    let raw: String
    let provenance: String
    let descriptor: String
    let descriptorSHA256: String
    let material: String
    let materialSHA256: String
    let normalizedRoot: String
    let expectedRawFileSHA256: String
    let expectedRawDecodedRGBASHA256: String
}

private let l3V06Directions = [
    L3V06Direction(
        direction: "north",
        revision: "source-v06",
        raw: "docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-raw-review-v01/diagnostics/raw-repeat/north/run-a/raw.png",
        provenance: "docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-raw-review-v01/diagnostics/raw-repeat/north/run-a/provenance.json",
        descriptor: "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-source-v06-v01/scenes/industrial_l03/variant-0/north/scene.json",
        descriptorSHA256: "adc73af1704c067d75f62b818d9a6ee7da6c7ff87637356552ef72393f8c77a9",
        material: "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-source-v06-v01/materials/industrial-l03-source-v06-north.json",
        materialSHA256: "2a9c9fa964f6135207b7ab4bbdea37f343ebd7ac0e14cc0356ece643616d3fc8",
        normalizedRoot: "docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-complete-family-v01/normalized",
        expectedRawFileSHA256: "91b3fb983e294eeff288b13f6d89a19366393cfaf084b52527633e88ed0507ea",
        expectedRawDecodedRGBASHA256: "ca087fb06b5bcc67ea101f661ac07a5a1b263d5b3b32db4d1c6d8aa7d18764af"
    ),
    L3V06Direction(
        direction: "east",
        revision: "source-v04",
        raw: "docs/production/evidence/PLAY-027/industrial-l03/l03/cohesion-a0-east-v01/raw/east-primary/raw.png",
        provenance: "docs/production/evidence/PLAY-027/industrial-l03/l03/cohesion-a0-east-v01/raw/east-primary/provenance.json",
        descriptor: "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-east-v01/scenes/industrial_l03/variant-0/east/scene.json",
        descriptorSHA256: "1e5c69a03a6298f64f4d4d13bb0f523690729b82d5565343f40aaa8278aa3b6d",
        material: "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-east-v01/materials/industrial-l03-cohesion-east-v01.json",
        materialSHA256: "f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65",
        normalizedRoot: "docs/production/evidence/PLAY-027/industrial-l03/l03/cohesion-a0-family-v01/chroma-repair-v01/normalized",
        expectedRawFileSHA256: "5ba539536c4363d71ddae79a128f42bfd8e22cce248f4aa0c852dd22a24fb84e",
        expectedRawDecodedRGBASHA256: "4d3b980ef0c641cc7010172c4d6ffd22d59b023195eaef50dbcf8c67b66ec222"
    ),
    L3V06Direction(
        direction: "south",
        revision: "source-v04",
        raw: "docs/production/evidence/PLAY-027/industrial-l03/l03/cohesion-a0-family-v01/raw/south-primary/raw.png",
        provenance: "docs/production/evidence/PLAY-027/industrial-l03/l03/cohesion-a0-family-v01/raw/south-primary/provenance.json",
        descriptor: "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-siblings-v01/scenes/industrial_l03/variant-0/south/scene.json",
        descriptorSHA256: "31c7eef5e3f461b97b116288274baa8bc5980ef711d45401645e2925ac326a48",
        material: "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-east-v01/materials/industrial-l03-cohesion-east-v01.json",
        materialSHA256: "f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65",
        normalizedRoot: "docs/production/evidence/PLAY-027/industrial-l03/l03/cohesion-a0-family-v01/chroma-repair-v01/normalized",
        expectedRawFileSHA256: "5267ef34929114af987ec586cb4802fa5316f4383ecac4ae6807a7be099baed5",
        expectedRawDecodedRGBASHA256: "85308c293986c7f46c90404e2a2b478487fdac4b892223aff2b01625831da7dd"
    ),
    L3V06Direction(
        direction: "west",
        revision: "source-v06",
        raw: "docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-raw-review-v01/diagnostics/raw-repeat/west/run-a/raw.png",
        provenance: "docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-raw-review-v01/diagnostics/raw-repeat/west/run-a/provenance.json",
        descriptor: "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-source-v06-v01/scenes/industrial_l03/variant-0/west/scene.json",
        descriptorSHA256: "d4affd0773c557056cf15b56db66dfb76736658a995df68cdd86a48b84178f4f",
        material: "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-source-v06-v01/materials/industrial-l03-source-v06-west.json",
        materialSHA256: "928c5dc9963b3a67e5e4cd9e48033ec11efbc8d8aa9f32eb45f0730b8e2e3faf",
        normalizedRoot: "docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-complete-family-v01/normalized",
        expectedRawFileSHA256: "ceaa2948be0f37cbd8f6288c9c125f15502a864ce683bc3eaa1cd0d7563477d4",
        expectedRawDecodedRGBASHA256: "f66b4fe3cde165e0c3852ce5aa0863ec7380824f46e81708804428b6717be310"
    ),
]

private func l3V06Array(_ value: Any?, _ label: String) throws -> [Double] {
    guard let values = value as? [NSNumber] else {
        throw IndustrialL3FinalError.invalid("\(label) missing")
    }
    return values.map(\.doubleValue)
}

private func l3V06Matrix(_ value: Any?, _ label: String) throws -> [[Double]] {
    guard let values = value as? [[NSNumber]] else {
        throw IndustrialL3FinalError.invalid("\(label) missing")
    }
    return values.map { $0.map(\.doubleValue) }
}

private func l3V06Image(
    pixels: [UInt8],
    width: Int,
    height: Int
) throws -> CGImage {
    guard
        let provider = CGDataProvider(data: Data(pixels) as CFData),
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
        throw IndustrialL3FinalError.invalid("RGBA image creation failed")
    }
    return image
}

private func l3V06DrawLine(
    pixels: inout [UInt8],
    width: Int,
    height: Int,
    start: [Double],
    end: [Double],
    color: [UInt8],
    radius: Int
) {
    let dx = end[0] - start[0]
    let dy = end[1] - start[1]
    let steps = max(1, Int(ceil(max(abs(dx), abs(dy)) * 2)))
    for step in 0...steps {
        let t = Double(step) / Double(steps)
        let cx = Int((start[0] + dx * t).rounded())
        let cy = Int((start[1] + dy * t).rounded())
        for y in (cy - radius)...(cy + radius) {
            for x in (cx - radius)...(cx + radius)
            where x >= 0 && x < width && y >= 0 && y < height {
                let offset = (y * width + x) * 4
                pixels[offset] = color[0]
                pixels[offset + 1] = color[1]
                pixels[offset + 2] = color[2]
                pixels[offset + 3] = 255
            }
        }
    }
}

private func l3V06Overlay(
    raster: IndustrialL3FinalRaster,
    descriptor: [String: Any],
    normalization: [String: Any]
) throws -> (CGImage, [String: Any]) {
    guard
        let descriptorRegistration = descriptor["registration"]
            as? [String: Any],
        let normalizedRegistration = normalization["registration"]
            as? [String: Any],
        let scale = (normalizedRegistration["uniform_scale"] as? NSNumber)?
            .doubleValue
    else {
        throw IndustrialL3FinalError.invalid("registration overlay missing")
    }
    let sourceBounds = try l3V06Array(
        normalizedRegistration["source_bbox"],
        "source_bbox"
    )
    let targetOrigin = try l3V06Array(
        normalizedRegistration["target_origin"],
        "target_origin"
    )
    let edge = try l3V06Matrix(
        descriptorRegistration["frontageEdgeSource"],
        "frontageEdgeSource"
    )
    let door = try l3V06Matrix(
        descriptorRegistration["doorBaseSource"],
        "doorBaseSource"
    )
    let socket = try l3V06Array(
        descriptorRegistration["frontageSocketSource"],
        "frontageSocketSource"
    )
    func project(_ point: [Double]) -> [Double] {
        let x = targetOrigin[0] + (point[0] - sourceBounds[0]) * scale
        let y = targetOrigin[1] + (point[1] - sourceBounds[1]) * scale
        return [
            x * Double(raster.image.width) / 1536,
            y * Double(raster.image.height) / 1024,
        ]
    }
    let projectedEdge = edge.map(project)
    let projectedDoor = door.map(project)
    let projectedSocket = project(socket)
    var pixels = [UInt8](raster.rgba)
    l3V06DrawLine(
        pixels: &pixels,
        width: raster.image.width,
        height: raster.image.height,
        start: projectedEdge[0],
        end: projectedEdge[1],
        color: [0, 220, 255, 255],
        radius: 1
    )
    l3V06DrawLine(
        pixels: &pixels,
        width: raster.image.width,
        height: raster.image.height,
        start: projectedDoor[0],
        end: projectedDoor[1],
        color: [255, 255, 255, 255],
        radius: 1
    )
    l3V06DrawLine(
        pixels: &pixels,
        width: raster.image.width,
        height: raster.image.height,
        start: [projectedSocket[0] - 4, projectedSocket[1]],
        end: [projectedSocket[0] + 4, projectedSocket[1]],
        color: [255, 220, 0, 255],
        radius: 1
    )
    l3V06DrawLine(
        pixels: &pixels,
        width: raster.image.width,
        height: raster.image.height,
        start: [projectedSocket[0], projectedSocket[1] - 4],
        end: [projectedSocket[0], projectedSocket[1] + 4],
        color: [255, 220, 0, 255],
        radius: 1
    )
    let doorWidth = hypot(
        projectedDoor[1][0] - projectedDoor[0][0],
        projectedDoor[1][1] - projectedDoor[0][1]
    )
    let midpoint = [
        (projectedDoor[0][0] + projectedDoor[1][0]) / 2,
        (projectedDoor[0][1] + projectedDoor[1][1]) / 2,
    ]
    let socketDistance = hypot(
        midpoint[0] - projectedSocket[0],
        midpoint[1] - projectedSocket[1]
    )
    return (
        try l3V06Image(
            pixels: pixels,
            width: raster.image.width,
            height: raster.image.height
        ),
        [
            "doorBaseWidthPixels": doorWidth,
            "doorBaseMidpointToSocketPixels": socketDistance,
            "frontageWidthAtLeastEightPixels": doorWidth >= 8,
            "socketRegistrationWithinTwoPixels": socketDistance <= 2,
            "frontageEdgeColor": "cyan",
            "doorBaseColor": "white",
            "socketColor": "yellow-cross",
        ]
    )
}

private func l3V06Luma(_ raster: IndustrialL3FinalRaster) -> [String: Any] {
    let bytes = [UInt8](raster.rgba)
    var lumas: [Int] = []
    var saturated = 0
    for offset in stride(from: 0, to: bytes.count, by: 4) {
        let alpha = Int(bytes[offset + 3])
        guard alpha > 0 else { continue }
        let red = min(255, (Int(bytes[offset]) * 255 + alpha / 2) / alpha)
        let green = min(
            255,
            (Int(bytes[offset + 1]) * 255 + alpha / 2) / alpha
        )
        let blue = min(
            255,
            (Int(bytes[offset + 2]) * 255 + alpha / 2) / alpha
        )
        lumas.append((54 * red + 183 * green + 19 * blue + 128) >> 8)
        if max(red, green, blue) >= 160,
            max(red, green, blue) - min(red, green, blue) >= 96
        {
            saturated += 1
        }
    }
    lumas.sort()
    let median = lumas.isEmpty ? 0 : lumas[lumas.count / 2]
    let p95Index = lumas.isEmpty
        ? 0
        : min(lumas.count - 1, Int(Double(lumas.count - 1) * 0.95))
    return [
        "medianLuma": median,
        "p95Luma": lumas.isEmpty ? 0 : lumas[p95Index],
        "saturatedAccentPixelCount": saturated,
        "saturatedAccentShare":
            lumas.isEmpty ? 0 : Double(saturated) / Double(lumas.count),
    ]
}

@main
enum BuildIndustrialL3SourceV06FamilyReview {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try l3FinalArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let familyRoot = URL(
            fileURLWithPath: try l3FinalArgument(
                "--family-root",
                in: arguments
            )
        ).standardizedFileURL
        let review = familyRoot.appendingPathComponent("review")
        let manifestURL = familyRoot.appendingPathComponent(
            "FAMILY-MANIFEST.json"
        )
        guard
            !FileManager.default.fileExists(atPath: review.path),
            !FileManager.default.fileExists(atPath: manifestURL.path)
        else {
            throw IndustrialL3FinalError.invalid(
                "family review outputs must be absent"
            )
        }

        let lods = [
            ("block", [1024, 683]),
            ("neighborhood", [512, 342]),
            ("city", [256, 171]),
        ]
        var rawRecords: [[String: Any]] = []
        var normalizedRecords: [[String: Any]] = []
        var rawRasters: [IndustrialL3FinalRaster] = []
        var blockRasters: [IndustrialL3FinalRaster] = []
        var neighborhoodRasters: [IndustrialL3FinalRaster] = []
        var cityRasters: [IndustrialL3FinalRaster] = []
        var overlays: [CGImage] = []
        var overlayRecords: [[String: Any]] = []
        var rawHashes = Set<String>()
        var rawPixelHashes = Set<String>()
        var normalizedHashes = Set<String>()
        var normalizedPixelHashes = Set<String>()

        for direction in l3V06Directions {
            let raw = try l3FinalInspect(
                l3FinalURL(direction.raw, root: root)
            )
            guard
                raw.fileSHA256 == direction.expectedRawFileSHA256,
                raw.decodedRGBASHA256
                    == direction.expectedRawDecodedRGBASHA256,
                l3FinalSHA256(
                    try Data(
                        contentsOf: l3FinalURL(
                            direction.descriptor,
                            root: root
                        )
                    )
                ) == direction.descriptorSHA256,
                l3FinalSHA256(
                    try Data(
                        contentsOf: l3FinalURL(
                            direction.material,
                            root: root
                        )
                    )
                ) == direction.materialSHA256,
                raw.image.width == 1536,
                raw.image.height == 1024
            else {
                throw IndustrialL3FinalError.invalid(
                    "\(direction.direction) frozen input hash drift"
                )
            }
            let rawProvenance = try l3FinalJSON(
                l3FinalURL(direction.provenance, root: root)
            )
            rawRasters.append(raw)
            rawHashes.insert(raw.fileSHA256)
            rawPixelHashes.insert(raw.decodedRGBASHA256)
            rawRecords.append([
                "direction": direction.direction,
                "revision": direction.revision,
                "file": direction.raw,
                "provenance": direction.provenance,
                "descriptor": direction.descriptor,
                "descriptorSHA256": direction.descriptorSHA256,
                "materialLibrary": direction.material,
                "materialLibrarySHA256": direction.materialSHA256,
                "fileSHA256": raw.fileSHA256,
                "decodedRGBASHA256": raw.decodedRGBASHA256,
                "registration": try l3FinalRegistration(rawProvenance),
                "orientationTransform": "none",
                "productionSelected": false,
            ])

            let provenanceAPath =
                "\(direction.normalizedRoot)/run-a/\(direction.direction)/provenance.json"
            let provenanceBPath =
                "\(direction.normalizedRoot)/run-b/\(direction.direction)/provenance.json"
            let provenanceA = try l3FinalJSON(
                l3FinalURL(provenanceAPath, root: root)
            )
            let provenanceB = try l3FinalJSON(
                l3FinalURL(provenanceBPath, root: root)
            )
            guard
                provenanceA["source_sha256"] as? String
                    == direction.expectedRawFileSHA256,
                provenanceB["source_sha256"] as? String
                    == direction.expectedRawFileSHA256,
                provenanceA["object_width"] as? Int == 410,
                provenanceB["object_width"] as? Int == 410,
                provenanceA["strict_chroma_contract"] as? String
                    == "play027-zero-nonzero-alpha-chroma-premultiplied-v1",
                provenanceB["strict_chroma_contract"] as? String
                    == "play027-zero-nonzero-alpha-chroma-premultiplied-v1",
                provenanceA["productionSelected"] as? Bool == false,
                provenanceB["productionSelected"] as? Bool == false
            else {
                throw IndustrialL3FinalError.invalid(
                    "\(direction.direction) normalization provenance drift"
                )
            }
            let descriptor = try l3FinalJSON(
                l3FinalURL(direction.descriptor, root: root)
            )
            var compactRaster: IndustrialL3FinalRaster?
            for (lod, dimensions) in lods {
                let filenameRevision = direction.revision.replacingOccurrences(
                    of: "-",
                    with: "_"
                )
                let filename =
                    "generated_v4_industrial_l03_\(direction.direction)_"
                    + "\(filenameRevision)_\(lod).png"
                let pathA =
                    "\(direction.normalizedRoot)/run-a/"
                    + "\(direction.direction)/\(filename)"
                let pathB =
                    "\(direction.normalizedRoot)/run-b/"
                    + "\(direction.direction)/\(filename)"
                let rasterA = try l3FinalInspect(
                    l3FinalURL(pathA, root: root)
                )
                let rasterB = try l3FinalInspect(
                    l3FinalURL(pathB, root: root)
                )
                let pivotY = Int(
                    floor(
                        896 * Double(rasterA.image.height) / 1024
                    )
                )
                let passed =
                    rasterA.fileSHA256 == rasterB.fileSHA256
                    && rasterA.decodedRGBASHA256
                        == rasterB.decodedRGBASHA256
                    && rasterA.image.width == dimensions[0]
                    && rasterA.image.height == dimensions[1]
                    && rasterA.alphaBounds == rasterB.alphaBounds
                    && rasterA.visiblePixelCount == rasterB.visiblePixelCount
                    && rasterA.hiddenRGBPixelCount == 0
                    && rasterA.exactChromaPixelCount == 0
                    && rasterA.visibleMagentaSpillPixelCount == 0
                    && rasterA.alphaBounds[0] > 2
                    && rasterA.alphaBounds[1] > 2
                    && rasterA.alphaBounds[2] < rasterA.image.width - 2
                    && rasterA.alphaBounds[3] < rasterA.image.height - 2
                    && rasterA.alphaBounds[3] >= pivotY
                guard passed else {
                    throw IndustrialL3FinalError.invalid(
                        "\(direction.direction) \(lod) normalized gate failed"
                    )
                }
                normalizedHashes.insert(rasterA.fileSHA256)
                normalizedPixelHashes.insert(rasterA.decodedRGBASHA256)
                if lod == "block" { blockRasters.append(rasterA) }
                if lod == "neighborhood" {
                    neighborhoodRasters.append(rasterA)
                    compactRaster = rasterA
                }
                if lod == "city" { cityRasters.append(rasterA) }
                normalizedRecords.append([
                    "direction": direction.direction,
                    "revision": direction.revision,
                    "lod": lod,
                    "runA": pathA,
                    "runB": pathB,
                    "fileSHA256": rasterA.fileSHA256,
                    "decodedRGBASHA256": rasterA.decodedRGBASHA256,
                    "pixels": [rasterA.image.width, rasterA.image.height],
                    "alphaBounds": rasterA.alphaBounds,
                    "visiblePixelCount": rasterA.visiblePixelCount,
                    "repeatFileIdentity": true,
                    "repeatDecodedPixelIdentity": true,
                    "hiddenRGBPixelCount": 0,
                    "exactChromaPixelCount": 0,
                    "visibleMagentaSpillPixelCount": 0,
                    "paddingPassed": true,
                    "registrationPassed": true,
                    "contactShadowSupportReachedGroundPivot": true,
                    "valueMetrics": l3V06Luma(rasterA),
                ])
            }
            guard let compactRaster else {
                throw IndustrialL3FinalError.invalid(
                    "\(direction.direction) compact raster missing"
                )
            }
            let overlay = try l3V06Overlay(
                raster: compactRaster,
                descriptor: descriptor,
                normalization: provenanceA
            )
            guard
                overlay.1["frontageWidthAtLeastEightPixels"] as? Bool == true,
                overlay.1["socketRegistrationWithinTwoPixels"] as? Bool
                    == true
            else {
                throw IndustrialL3FinalError.invalid(
                    "\(direction.direction) frontage/socket gate failed"
                )
            }
            overlays.append(overlay.0)
            var overlayRecord = overlay.1
            overlayRecord["direction"] = direction.direction
            overlayRecords.append(overlayRecord)
        }

        guard
            rawHashes.count == 4,
            rawPixelHashes.count == 4,
            normalizedHashes.count == 12,
            normalizedPixelHashes.count == 12
        else {
            throw IndustrialL3FinalError.invalid(
                "family uniqueness gate failed"
            )
        }

        let catalogPaths = [
            "Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-028-residential-directions.json",
            "Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-060-commercial-directions.json",
            "Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-062-industrial-l1-directions.json",
            "Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-073-industrial-l2-directions.json",
        ]
        var acceptedRaw = Set<String>()
        var acceptedNormalized = Set<String>()
        var catalogRecords: [[String: Any]] = []
        for path in catalogPaths {
            let data = try Data(contentsOf: l3FinalURL(path, root: root))
            l3FinalCollectCatalogHashes(
                try JSONSerialization.jsonObject(with: data),
                raw: &acceptedRaw,
                normalized: &acceptedNormalized
            )
            catalogRecords.append([
                "file": path,
                "sha256": l3FinalSHA256(data),
            ])
        }
        let rawIntersection = rawHashes.intersection(acceptedRaw)
        let normalizedIntersection =
            normalizedHashes.intersection(acceptedNormalized)
        guard rawIntersection.isEmpty, normalizedIntersection.isEmpty else {
            throw IndustrialL3FinalError.invalid(
                "accepted-catalog alias intersection failed"
            )
        }

        let rawReview = try rawRasters.map {
            try l3FinalRawReviewAlpha($0.image)
        }
        let rawGray = try rawReview.map(l3FinalGrayscale)
        let blocks = blockRasters.map(\.image)
        let blockGray = try blocks.map(l3FinalGrayscale)
        let neighborhoods = neighborhoodRasters.map(\.image)
        let neighborhoodGray = try neighborhoods.map(l3FinalGrayscale)
        let cities = cityRasters.map(\.image)
        let cityGray = try cities.map(l3FinalGrayscale)
        let footprintRect = CGRect(x: 341, y: 341, width: 342, height: 256)
        let footprints = try l3FinalCrops(blocks, rect: footprintRect)
        let footprintGray = try footprints.map(l3FinalGrayscale)
        let zooms = try l3FinalZoomCrops(blockRasters)
        let zoomGray = try zooms.map(l3FinalGrayscale)

        let r2Root =
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "source-completion-v02/normalized/run-a"
        var r2Blocks: [CGImage] = []
        for direction in ["north", "east", "south", "west"] {
            let path =
                "\(r2Root)/\(direction)/"
                + "generated_v4_industrial_l03_\(direction)_source_v02_block.png"
            r2Blocks.append(
                try l3FinalInspect(l3FinalURL(path, root: root)).image
            )
        }
        let r2Gray = try r2Blocks.map(l3FinalGrayscale)

        let panels: [(String, CGImage, String)] = [
            (
                "SOURCE-SCALE-NESW-COLOR.png",
                try l3FinalCanvas(
                    images: rawReview,
                    columns: 2,
                    panelSize: CGSize(width: 768, height: 512),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .none
                ),
                "N/E/S/W exact frozen raws; review-only matte on neutral ground"
            ),
            (
                "SOURCE-SCALE-NESW-GRAYSCALE.png",
                try l3FinalCanvas(
                    images: rawGray,
                    columns: 2,
                    panelSize: CGSize(width: 768, height: 512),
                    background: [0.14, 0.14, 0.14, 1],
                    interpolation: .none
                ),
                "N/E/S/W exact frozen raws in deterministic grayscale"
            ),
            (
                "NEUTRAL-GROUND-NATIVE-2X-NESW-COLOR.png",
                try l3FinalCanvas(
                    images: blocks,
                    columns: 2,
                    panelSize: CGSize(width: 432, height: 288),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .high
                ),
                "N/E/S/W block LOD at native-2x review size on neutral ground"
            ),
            (
                "NEUTRAL-GROUND-NATIVE-2X-NESW-GRAYSCALE.png",
                try l3FinalCanvas(
                    images: blockGray,
                    columns: 2,
                    panelSize: CGSize(width: 432, height: 288),
                    background: [0.14, 0.14, 0.14, 1],
                    interpolation: .high
                ),
                "N/E/S/W block LOD at native-2x review size in grayscale"
            ),
            (
                "FOOTPRINT-NATIVE-2X-COLOR.png",
                try l3FinalCanvas(
                    images: footprints,
                    columns: 2,
                    panelSize: CGSize(width: 144, height: 108),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .none
                ),
                "fixed registered footprint crop N/E/S/W"
            ),
            (
                "FOOTPRINT-NATIVE-2X-GRAYSCALE.png",
                try l3FinalCanvas(
                    images: footprintGray,
                    columns: 2,
                    panelSize: CGSize(width: 144, height: 108),
                    background: [0.14, 0.14, 0.14, 1],
                    interpolation: .none
                ),
                "fixed registered footprint crop N/E/S/W grayscale"
            ),
            (
                "ZOOM-NESW-COLOR.png",
                try l3FinalCanvas(
                    images: zooms,
                    columns: 2,
                    panelSize: CGSize(width: 512, height: 384),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .none
                ),
                "occupied-alpha zoom N/E/S/W"
            ),
            (
                "ZOOM-NESW-GRAYSCALE.png",
                try l3FinalCanvas(
                    images: zoomGray,
                    columns: 2,
                    panelSize: CGSize(width: 512, height: 384),
                    background: [0.14, 0.14, 0.14, 1],
                    interpolation: .none
                ),
                "occupied-alpha zoom N/E/S/W grayscale"
            ),
            (
                "BLOCK-ACTUAL-COLOR-GRAYSCALE.png",
                try l3FinalCanvas(
                    images: blocks + blockGray,
                    columns: 4,
                    panelSize: CGSize(width: 256, height: 171),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .none
                ),
                "top N/E/S/W block color; bottom grayscale"
            ),
            (
                "NEIGHBORHOOD-ACTUAL-COLOR-GRAYSCALE.png",
                try l3FinalCanvas(
                    images: neighborhoods + neighborhoodGray,
                    columns: 4,
                    panelSize: CGSize(width: 256, height: 171),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .none
                ),
                "top N/E/S/W neighborhood color; bottom grayscale"
            ),
            (
                "CITY-ACTUAL-COLOR-GRAYSCALE.png",
                try l3FinalCanvas(
                    images: cities + cityGray,
                    columns: 4,
                    panelSize: CGSize(width: 256, height: 171),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .none
                ),
                "top N/E/S/W city color; bottom grayscale"
            ),
            (
                "ROAD-SOCKET-NEIGHBORHOOD-NESW.png",
                try l3FinalCanvas(
                    images: overlays,
                    columns: 2,
                    panelSize: CGSize(width: 512, height: 342),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .none
                ),
                "cyan road edge, white door base, yellow authoritative socket"
            ),
            (
                "REJECTED-R2-VS-CANDIDATE-BLOCK-COLOR-GRAYSCALE.png",
                try l3FinalCanvas(
                    images:
                        r2Blocks + blocks + r2Gray + blockGray,
                    columns: 4,
                    panelSize: CGSize(width: 256, height: 171),
                    background: [0.14, 0.15, 0.16, 1],
                    interpolation: .high
                ),
                "rows rejected R2 color, cohesion candidate color, rejected R2 grayscale, cohesion candidate grayscale"
            ),
        ]

        var panelRecords: [[String: Any]] = []
        for (filename, image, presentation) in panels {
            let target = review.appendingPathComponent(filename)
            try l3FinalWritePNG(image, to: target)
            panelRecords.append([
                "file": l3FinalRelative(target, root: root),
                "sha256": l3FinalSHA256(
                    try Data(contentsOf: target)
                ),
                "pixels": [image.width, image.height],
                "presentation": presentation,
            ])
        }

        let normalizer =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
            + "NormalizeOfflineSource.swift"
        let strictHelper =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
            + "StrictNonzeroAlphaChromaCanonicalizer.swift"
        let builder =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
            + "BuildIndustrialL3SourceV06FamilyReview.swift"
        let validation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "family": "industrial_l03",
            "directionOrder": ["north", "east", "south", "west"],
            "rawUniqueFileIdentities": rawHashes.count,
            "rawUniqueDecodedPixelIdentities": rawPixelHashes.count,
            "normalizedOutputCount": normalizedRecords.count,
            "normalizedUniqueFileIdentities": normalizedHashes.count,
            "normalizedUniqueDecodedPixelIdentities":
                normalizedPixelHashes.count,
            "twoRunByteAndDecodedPixelIdentity": true,
            "zeroHiddenRGBExactChromaNearChroma": true,
            "paddingRegistrationContactShadowPassed": true,
            "compactFrontageAndSocketPassed": true,
            "rawAcceptedCatalogIntersection":
                Array(rawIntersection).sorted(),
            "normalizedAcceptedCatalogIntersection":
                Array(normalizedIntersection).sorted(),
            "acceptedCatalogNonIntersectionPassed":
                rawIntersection.isEmpty && normalizedIntersection.isEmpty,
            "sourceAuthority": false,
            "productionSelected": false,
            "validationPassed": true,
        ]
        try l3FinalWriteJSON(
            validation,
            to: familyRoot.appendingPathComponent("VALIDATION.json")
        )
        let manifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contract": "CONTRACT-018",
            "family": "industrial_l03",
            "variant": 0,
            "directionScopedRevisions": [
                "north": "source-v06",
                "east": "source-v04",
                "south": "source-v04",
                "west": "source-v06",
            ],
            "normalizationAuthority":
                "docs/production/evidence/PLAY-027/INDUSTRIAL-L03-SOURCE-V06-NORMALIZATION-AUTHORITY-575ed9e.md",
            "normalizerProcessesConsumed": 4,
            "newNormalizationDirections": ["north", "west"],
            "retainedNormalizationDirections": ["east", "south"],
            "normalizationObjectWidth": 410,
            "normalizationReferenceWidth": 512,
            "strictChromaContract":
                "play027-zero-nonzero-alpha-chroma-premultiplied-v1",
            "rawMasters": rawRecords,
            "normalizedOutputs": normalizedRecords,
            "roadSocketOverlay": overlayRecords,
            "panels": panelRecords,
            "acceptedCatalogs": catalogRecords,
            "tooling": [
                "normalizer": normalizer,
                "normalizerSHA256": l3FinalSHA256(
                    try Data(
                        contentsOf: l3FinalURL(normalizer, root: root)
                    )
                ),
                "strictCanonicalizer": strictHelper,
                "strictCanonicalizerSHA256": l3FinalSHA256(
                    try Data(
                        contentsOf: l3FinalURL(strictHelper, root: root)
                    )
                ),
                "builder": builder,
                "builderSHA256": l3FinalSHA256(
                    try Data(
                        contentsOf: l3FinalURL(builder, root: root)
                    )
                ),
                "builderBinarySHA256": l3FinalSHA256(
                    try Data(
                        contentsOf: URL(
                            fileURLWithPath: CommandLine.arguments[0]
                        ).standardizedFileURL
                    )
                ),
            ],
            "rejectedSourceV03":
                "docs/production/evidence/PLAY-027/industrial-l03/l03/raw-gate-v03/rejection",
            "rejectedR2":
                "docs/production/evidence/PLAY-027/industrial-l03/l03/source-completion-v02",
            "reviewStatus": "pending-independent-family-review",
            "sourceAuthorityProposal": "pending-independent-review",
            "sourceAuthority": false,
            "familyAuthority": false,
            "productionSelected": false,
            "rendererOrShippingMutation": false,
        ]
        try l3FinalWriteJSON(manifest, to: manifestURL)
        let disposition = """
        # Industrial L3 source-v06 complete-family review candidate

        **Disposition:** `PENDING_INDEPENDENT_FAMILY_REVIEW`.

        North and West use exact source-v06 run-A raw masters and two new,
        independent strict-chroma normalizer processes per direction. East and
        South bind the retained, accepted source-v04 run-A/run-B bytes without
        rerendering or renormalizing them. The resulting family has four unique
        raw identities and twelve unique normalized identities; all twelve LOD
        pairs are byte- and decoded-pixel-identical with zero hidden RGB,
        exact/near chroma spill, padding, registration, and contact-shadow
        failures.

        The neutral-ground, road/socket, every-LOD, grayscale, footprint, zoom,
        and rejected-R2 comparisons are exact-pixel review evidence. This
        packet proposes source authority for independent disposition only.
        `productionSelected` remains false; no renderer or shipping surface
        changed.
        """
        try Data((disposition + "\n").utf8).write(
            to: familyRoot.appendingPathComponent("DISPOSITION.md"),
            options: .atomic
        )
    }
}
