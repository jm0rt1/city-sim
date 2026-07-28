import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

private enum AnalysisError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: analyze-industrial-l4-r4-edge-locality --repository-root <path> --output <json>"
        case let .invalid(message):
            return message
        }
    }
}

private struct Vector3 {
    let x: Double
    let y: Double
    let z: Double

    static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func * (lhs: Vector3, rhs: Double) -> Vector3 {
        Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    func dot(_ rhs: Vector3) -> Double {
        x * rhs.x + y * rhs.y + z * rhs.z
    }

    func cross(_ rhs: Vector3) -> Vector3 {
        Vector3(
            x: y * rhs.z - z * rhs.y,
            y: z * rhs.x - x * rhs.z,
            z: x * rhs.y - y * rhs.x
        )
    }

    func normalized() throws -> Vector3 {
        let length = sqrt(dot(self))
        guard length > 1e-12 else {
            throw AnalysisError.invalid("zero-length camera vector")
        }
        return self * (1 / length)
    }

    var array: [Double] { [x, y, z] }
}

private struct AABB {
    let minimum: Vector3
    let maximum: Vector3

    static func union(_ values: [AABB]) throws -> AABB {
        guard let first = values.first else {
            throw AnalysisError.invalid("cannot union empty AABB set")
        }
        return values.dropFirst().reduce(first) { result, value in
            AABB(
                minimum: Vector3(
                    x: min(result.minimum.x, value.minimum.x),
                    y: min(result.minimum.y, value.minimum.y),
                    z: min(result.minimum.z, value.minimum.z)
                ),
                maximum: Vector3(
                    x: max(result.maximum.x, value.maximum.x),
                    y: max(result.maximum.y, value.maximum.y),
                    z: max(result.maximum.z, value.maximum.z)
                )
            )
        }
    }

    var corners: [Vector3] {
        [minimum.x, maximum.x].flatMap { x in
            [minimum.y, maximum.y].flatMap { y in
                [minimum.z, maximum.z].map { z in
                    Vector3(x: x, y: y, z: z)
                }
            }
        }
    }

    var json: [String: Any] {
        ["minimum": minimum.array, "maximum": maximum.array]
    }
}

private struct Camera {
    let position: Vector3
    let right: Vector3
    let up: Vector3
    let orthographicScale: Double
    let viewport: [Int]
    let offset: [Double]

    func project(_ point: Vector3) -> [Double] {
        let relative = point - position
        let pixelsPerWorld =
            Double(viewport[1]) / (2 * orthographicScale)
        return [
            Double(viewport[0]) * 0.5
                + relative.dot(right) * pixelsPerWorld
                + offset[0],
            Double(viewport[1]) * 0.5
                - relative.dot(up) * pixelsPerWorld
                + offset[1],
        ]
    }
}

private struct Raster {
    let width: Int
    let height: Int
    let rgba: [UInt8]
    let fileSHA256: String
    let decodedSHA256: String
}

private struct Group {
    let name: String
    let rgba: [Int]
}

private let groups = [
    Group(name: "portal-jamb-south", rgba: [16, 16, 240]),
    Group(name: "portal-jamb-north", rgba: [240, 208, 16]),
    Group(name: "portal-header", rgba: [240, 16, 16]),
    Group(name: "portal-inset-void", rgba: [16, 240, 48]),
    Group(name: "hall", rgba: [144, 80, 48]),
    Group(name: "gantry", rgba: [48, 80, 112]),
    Group(name: "crucible-occluder", rgba: [208, 112, 16]),
    Group(name: "other", rgba: [80, 80, 80]),
]

private let descriptorPath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v18-north-prepixel/artifact/scenes/"
    + "industrial_l04/variant-0/n/scene.json"
private let evidencePath =
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    + "duplicate-foundation-repair-r3-v01/diagnostics"
private let expectedDescriptorSHA =
    "3696b813e6c3e0f46251e689582163bdbdcc5d84a3a9c1125bfbefba37da2630"
private let expectedManifestSHA =
    "611d60db7d39c9c0de73d1042f658c08e18c2d26bf4be9b7af3c6f577593a94f"
private let expectedRunAPNG =
    "39c5a71a3a185a125b3404a72a36deae5274833a3e6b81f01a063fb7f9db1ade"
private let expectedRunBPNG =
    "d9932be72d4538da41eb096c426e416e34f5eb4a40baf29dfcf32ec1bce0595e"
private let expectedRunAProvenance =
    "24955e0380234de124cd6ef9d4a9890fbabc8c9d44e05e95883d4f41d339b487"
private let expectedRunBProvenance =
    "7a1c7e715c08328ccf5d346917abb93c1f04c87a6702b287520598afeebe3f24"

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        index + 1 < CommandLine.arguments.count
    else {
        throw AnalysisError.arguments
    }
    return CommandLine.arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func decode(_ url: URL) throws -> Raster {
    let data = try Data(contentsOf: url)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        )
    else {
        throw AnalysisError.invalid("could not decode \(url.path)")
    }
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try rgba.withUnsafeMutableBytes { bytes in
        guard let context = CGContext(
            data: bytes.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw AnalysisError.invalid("could not allocate decoder")
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
        fileSHA256: digest(data),
        decodedSHA256: digest(Data(rgba))
    )
}

private func groupIndex(_ raster: Raster, x: Int, y: Int) -> Int? {
    guard
        x >= 0, x < raster.width,
        y >= 0, y < raster.height
    else {
        return nil
    }
    let offset = (y * raster.width + x) * 4
    guard raster.rgba[offset + 3] > 0 else { return nil }
    let red = Int(raster.rgba[offset])
    let green = Int(raster.rgba[offset + 1])
    let blue = Int(raster.rgba[offset + 2])
    let chromaDistance =
        (red - 255) * (red - 255)
        + green * green
        + (blue - 255) * (blue - 255)
    var bestIndex = 0
    var bestDistance = Int.max
    for (index, group) in groups.enumerated() {
        let redDelta = red - group.rgba[0]
        let greenDelta = green - group.rgba[1]
        let blueDelta = blue - group.rgba[2]
        let distance =
            redDelta * redDelta
            + greenDelta * greenDelta
            + blueDelta * blueDelta
        if distance < bestDistance {
            bestIndex = index
            bestDistance = distance
        }
    }
    return bestDistance < chromaDistance ? bestIndex : nil
}

private func rgba(_ raster: Raster, x: Int, y: Int) -> [Int] {
    let offset = (y * raster.width + x) * 4
    return (0..<4).map { Int(raster.rgba[offset + $0]) }
}

private func isBoundary(
    _ raster: Raster,
    x: Int,
    y: Int,
    group: Int
) -> Bool {
    for deltaY in -1...1 {
        for deltaX in -1...1 where deltaX != 0 || deltaY != 0 {
            if groupIndex(raster, x: x + deltaX, y: y + deltaY) != group {
                return true
            }
        }
    }
    return false
}

private func boundaryDistance(
    _ raster: Raster,
    x: Int,
    y: Int,
    group: Int
) -> Int {
    if isBoundary(raster, x: x, y: y, group: group) { return 0 }
    let maximum = max(raster.width, raster.height)
    for radius in 1...maximum {
        for deltaY in -radius...radius {
            for deltaX in -radius...radius
            where abs(deltaX) == radius || abs(deltaY) == radius {
                let testX = x + deltaX
                let testY = y + deltaY
                if groupIndex(raster, x: testX, y: testY) == group,
                   isBoundary(
                       raster,
                       x: testX,
                       y: testY,
                       group: group
                   ) {
                    return radius
                }
            }
        }
    }
    return maximum
}

private func stableInterior3x3(
    _ raster: Raster,
    x: Int,
    y: Int,
    group: Int
) -> Bool {
    (-1...1).allSatisfy { deltaY in
        (-1...1).allSatisfy { deltaX in
            groupIndex(
                raster,
                x: x + deltaX,
                y: y + deltaY
            ) == group
        }
    }
}

private func thickness(
    _ raster: Raster,
    x: Int,
    y: Int,
    group: Int
) -> [String: Int] {
    var left = x
    while left > 0,
          groupIndex(raster, x: left - 1, y: y) == group {
        left -= 1
    }
    var right = x
    while right + 1 < raster.width,
          groupIndex(raster, x: right + 1, y: y) == group {
        right += 1
    }
    var top = y
    while top > 0,
          groupIndex(raster, x: x, y: top - 1) == group {
        top -= 1
    }
    var bottom = y
    while bottom + 1 < raster.height,
          groupIndex(raster, x: x, y: bottom + 1) == group {
        bottom += 1
    }
    return [
        "horizontal": right - left + 1,
        "vertical": bottom - top + 1,
        "minimumAxis": min(right - left + 1, bottom - top + 1),
    ]
}

private func vector(_ value: Any?, label: String) throws -> Vector3 {
    guard
        let numbers = value as? [NSNumber],
        numbers.count == 3
    else {
        throw AnalysisError.invalid("\(label) invalid")
    }
    return Vector3(
        x: numbers[0].doubleValue,
        y: numbers[1].doubleValue,
        z: numbers[2].doubleValue
    )
}

private func aabb(_ object: [String: Any]) throws -> AABB {
    let position = try vector(
        object["positionWorld"],
        label: "positionWorld"
    )
    let dimensions = try vector(
        object["dimensions"],
        label: "dimensions"
    )
    let half = dimensions * 0.5
    return AABB(minimum: position - half, maximum: position + half)
}

private func projectedBounds(
    _ bounds: AABB,
    camera: Camera
) -> [String: Any] {
    let points = bounds.corners.map(camera.project)
    return [
        "minimumX": points.map { $0[0] }.min() as Any,
        "minimumY": points.map { $0[1] }.min() as Any,
        "maximumX": points.map { $0[0] }.max() as Any,
        "maximumY": points.map { $0[1] }.max() as Any,
        "conservativeAABBProjection": true,
    ]
}

private func pairMetrics(
    _ lhsName: String,
    _ lhs: AABB,
    _ rhsName: String,
    _ rhs: AABB
) -> [String: Any] {
    func axis(
        _ lhsMinimum: Double,
        _ lhsMaximum: Double,
        _ rhsMinimum: Double,
        _ rhsMaximum: Double
    ) -> (gap: Double, overlap: Double) {
        let gap = max(
            0,
            max(rhsMinimum - lhsMaximum, lhsMinimum - rhsMaximum)
        )
        let overlap = max(
            0,
            min(lhsMaximum, rhsMaximum)
                - max(lhsMinimum, rhsMinimum)
        )
        return (gap, overlap)
    }
    let x = axis(
        lhs.minimum.x, lhs.maximum.x,
        rhs.minimum.x, rhs.maximum.x
    )
    let y = axis(
        lhs.minimum.y, lhs.maximum.y,
        rhs.minimum.y, rhs.maximum.y
    )
    let z = axis(
        lhs.minimum.z, lhs.maximum.z,
        rhs.minimum.z, rhs.maximum.z
    )
    return [
        "components": [lhsName, rhsName],
        "axisGapWorld": [x.gap, y.gap, z.gap],
        "axisOverlapWorld": [x.overlap, y.overlap, z.overlap],
        "euclideanGapWorld": sqrt(
            x.gap * x.gap + y.gap * y.gap + z.gap * z.gap
        ),
        "volumeOverlap": x.overlap > 0 && y.overlap > 0 && z.overlap > 0,
    ]
}

private func mutationRecords(
    _ provenance: [String: Any]
) throws -> [[String: Any]] {
    guard
        let sampling = provenance["descriptorSamplingContract"]
            as? [String: Any],
        let mutations = sampling[
            "postQuantizationBoundaryAssistMutations"
        ] as? [[String: Any]]
    else {
        throw AnalysisError.invalid("post-quantization mutations missing")
    }
    return mutations
}

private func mutationMap(
    _ records: [[String: Any]]
) throws -> [String: [[String: Any]]] {
    var result: [String: [[String: Any]]] = [:]
    for record in records {
        guard
            let target = record["target"] as? [NSNumber],
            target.count == 2
        else {
            throw AnalysisError.invalid("mutation target invalid")
        }
        let key = "\(target[0].intValue),\(target[1].intValue)"
        result[key, default: []].append(record)
    }
    return result
}

private func manifestSHA(_ provenance: [String: Any]) throws -> String {
    guard
        let semantic =
            provenance["diagnosticSemanticVisibility"] as? [String: Any],
        let value = semantic["nodeManifestSHA256"] as? String
    else {
        throw AnalysisError.invalid("semantic manifest missing")
    }
    return value
}

@main
private enum AnalyzeR4 {
    static func main() throws {
        let root = URL(
            fileURLWithPath: try argument("--repository-root")
        ).standardizedFileURL
        let outputURL = URL(
            fileURLWithPath: try argument("--output")
        ).standardizedFileURL
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw AnalysisError.invalid("output path must be absent")
        }
        let descriptorURL = root.appendingPathComponent(descriptorPath)
        let descriptorData = try Data(contentsOf: descriptorURL)
        guard digest(descriptorData) == expectedDescriptorSHA else {
            throw AnalysisError.invalid("descriptor hash drift")
        }
        guard
            let descriptor = try JSONSerialization.jsonObject(
                with: descriptorData
            ) as? [String: Any],
            let building = descriptor["building"] as? [String: Any],
            let massBlocks = building["massBlocks"] as? [[String: Any]],
            let props = descriptor["props"] as? [[String: Any]],
            let cameraObject = descriptor["camera"] as? [String: Any]
        else {
            throw AnalysisError.invalid("descriptor structure invalid")
        }
        let runAURL = root.appendingPathComponent(
            evidencePath + "/run-a/semantic.png"
        )
        let runBURL = root.appendingPathComponent(
            evidencePath + "/run-b/semantic.png"
        )
        let provenanceAURL = root.appendingPathComponent(
            evidencePath + "/run-a/provenance.json"
        )
        let provenanceBURL = root.appendingPathComponent(
            evidencePath + "/run-b/provenance.json"
        )
        let provenanceAData = try Data(contentsOf: provenanceAURL)
        let provenanceBData = try Data(contentsOf: provenanceBURL)
        let runA = try decode(runAURL)
        let runB = try decode(runBURL)
        guard
            runA.fileSHA256 == expectedRunAPNG,
            runB.fileSHA256 == expectedRunBPNG,
            digest(provenanceAData) == expectedRunAProvenance,
            digest(provenanceBData) == expectedRunBProvenance,
            runA.width == runB.width,
            runA.height == runB.height
        else {
            throw AnalysisError.invalid("immutable R3 input drift")
        }
        guard
            let provenanceA = try JSONSerialization.jsonObject(
                with: provenanceAData
            ) as? [String: Any],
            let provenanceB = try JSONSerialization.jsonObject(
                with: provenanceBData
            ) as? [String: Any],
            try manifestSHA(provenanceA) == expectedManifestSHA,
            try manifestSHA(provenanceB) == expectedManifestSHA
        else {
            throw AnalysisError.invalid("manifest binding drift")
        }

        let mutationsA = try mutationRecords(provenanceA)
        let mutationsB = try mutationRecords(provenanceB)
        let mutationMapA = try mutationMap(mutationsA)
        let mutationMapB = try mutationMap(mutationsB)
        let mutationBytesA = try JSONSerialization.data(
            withJSONObject: mutationsA,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        let mutationBytesB = try JSONSerialization.data(
            withJSONObject: mutationsB,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )

        var differences: [[String: Any]] = []
        var transitionCounts: [String: Int] = [:]
        var anyStableInterior = false
        var anyBeyondBothBoundaries = false
        var allDifferencesPostQuantizationExplained = true
        var allHeaderCrucibleEdgeLocal = true
        var headerCrucibleCount = 0
        var postQuantizationIntersectionCount = 0

        for y in 0..<runA.height {
            for x in 0..<runA.width {
                let rgbaA = rgba(runA, x: x, y: y)
                let rgbaB = rgba(runB, x: x, y: y)
                guard rgbaA != rgbaB else { continue }
                guard
                    let groupA = groupIndex(runA, x: x, y: y),
                    let groupB = groupIndex(runB, x: x, y: y)
                else {
                    throw AnalysisError.invalid(
                        "difference lacks governed semantic class at \(x),\(y)"
                    )
                }
                let nameA = groups[groupA].name
                let nameB = groups[groupB].name
                let transition = "\(nameA)->\(nameB)"
                transitionCounts[transition, default: 0] += 1
                let distanceA = boundaryDistance(
                    runA,
                    x: x,
                    y: y,
                    group: groupA
                )
                let distanceB = boundaryDistance(
                    runB,
                    x: x,
                    y: y,
                    group: groupB
                )
                let interiorA = stableInterior3x3(
                    runA,
                    x: x,
                    y: y,
                    group: groupA
                )
                let interiorB = stableInterior3x3(
                    runB,
                    x: x,
                    y: y,
                    group: groupB
                )
                anyStableInterior = anyStableInterior || interiorA || interiorB
                anyBeyondBothBoundaries =
                    anyBeyondBothBoundaries
                    || (distanceA > 2 && distanceB > 2)
                let key = "\(x),\(y)"
                let recordsA = mutationMapA[key] ?? []
                let recordsB = mutationMapB[key] ?? []
                if !recordsA.isEmpty || !recordsB.isEmpty {
                    postQuantizationIntersectionCount += 1
                }
                let mutationDifference =
                    try JSONSerialization.data(
                        withJSONObject: recordsA,
                        options: [.sortedKeys, .withoutEscapingSlashes]
                    )
                    != JSONSerialization.data(
                        withJSONObject: recordsB,
                        options: [.sortedKeys, .withoutEscapingSlashes]
                    )
                let explainedByPostQuantization =
                    mutationDifference
                    && (!recordsA.isEmpty || !recordsB.isEmpty)
                allDifferencesPostQuantizationExplained =
                    allDifferencesPostQuantizationExplained
                    && explainedByPostQuantization
                let isHeaderCrucible =
                    Set([nameA, nameB])
                    == Set(["portal-header", "crucible-occluder"])
                if isHeaderCrucible {
                    headerCrucibleCount += 1
                    allHeaderCrucibleEdgeLocal =
                        allHeaderCrucibleEdgeLocal
                        && distanceA <= 2
                        && distanceB <= 2
                        && !interiorA
                        && !interiorB
                        && !explainedByPostQuantization
                }
                differences.append(
                    [
                        "coordinate": [x, y],
                        "runA": [
                            "rgba": rgbaA,
                            "semantic": nameA,
                            "boundaryDistanceChebyshev": distanceA,
                            "stableInterior3x3": interiorA,
                            "componentThickness": thickness(
                                runA,
                                x: x,
                                y: y,
                                group: groupA
                            ),
                            "postQuantizationMutations": recordsA,
                        ],
                        "runB": [
                            "rgba": rgbaB,
                            "semantic": nameB,
                            "boundaryDistanceChebyshev": distanceB,
                            "stableInterior3x3": interiorB,
                            "componentThickness": thickness(
                                runB,
                                x: x,
                                y: y,
                                group: groupB
                            ),
                            "postQuantizationMutations": recordsB,
                        ],
                        "transition": transition,
                        "postQuantizationExplained":
                            explainedByPostQuantization,
                    ]
                )
            }
        }
        guard differences.count == 143, headerCrucibleCount == 85 else {
            throw AnalysisError.invalid(
                "expected 143 differences and 85 header/crucible transitions"
            )
        }

        let position = try vector(
            cameraObject["positionWorld"],
            label: "camera.positionWorld"
        )
        let target = try vector(
            cameraObject["targetWorld"],
            label: "camera.targetWorld"
        )
        let forward = try (target - position).normalized()
        let right = try forward.cross(
            Vector3(x: 0, y: 1, z: 0)
        ).normalized()
        let up = try right.cross(forward).normalized()
        guard
            let scale =
                (cameraObject["orthographicScale"] as? NSNumber)?.doubleValue,
            let viewportValues =
                cameraObject["renderViewportPixels"] as? [NSNumber],
            let offsetValues =
                cameraObject["postProjectionOffsetPixels"] as? [NSNumber],
            viewportValues.count == 2,
            offsetValues.count == 2
        else {
            throw AnalysisError.invalid("camera contract invalid")
        }
        let camera = Camera(
            position: position,
            right: right,
            up: up,
            orthographicScale: scale,
            viewport: viewportValues.map(\.intValue),
            offset: offsetValues.map(\.doubleValue)
        )
        let objects = Dictionary(
            uniqueKeysWithValues: (massBlocks + props).compactMap {
                object -> (String, [String: Any])? in
                guard let id = object["id"] as? String else { return nil }
                return (id, object)
            }
        )
        func requiredBounds(_ id: String) throws -> AABB {
            guard let object = objects[id] else {
                throw AnalysisError.invalid("primitive missing: \(id)")
            }
            return try aabb(object)
        }
        let componentBounds: [String: AABB] = [
            "portal-header-wall": try requiredBounds(
                "v17-monumental-portal-header-wall"
            ),
            "portal-lintel": try requiredBounds(
                "v17-monumental-portal-lintel"
            ),
            "portal-jamb-south": try requiredBounds(
                "v17-monumental-portal-jamb-south"
            ),
            "portal-jamb-north": try requiredBounds(
                "v17-monumental-portal-jamb-north"
            ),
            "gantry": try AABB.union(
                objects.keys.filter {
                    $0.contains("gantry")
                        || $0.contains("crane")
                        || $0.contains("lift-rail")
                }.sorted().map { try requiredBounds($0) }
            ),
            "crucible": try AABB.union(
                objects.keys.filter {
                    $0.contains("crucible")
                }.sorted().map { try requiredBounds($0) }
            ),
        ]
        var projected: [String: Any] = [:]
        for name in componentBounds.keys.sorted() {
            let bounds = componentBounds[name]!
            projected[name] = [
                "worldAABB": bounds.json,
                "projectedSourceBounds": projectedBounds(
                    bounds,
                    camera: camera
                ),
            ]
        }
        let pairs = [
            ("portal-header-wall", "crucible"),
            ("portal-lintel", "crucible"),
            ("portal-header-wall", "gantry"),
            ("portal-lintel", "gantry"),
            ("portal-jamb-south", "crucible"),
            ("portal-jamb-north", "crucible"),
        ]
        let pairReports = pairs.map {
            pairMetrics(
                $0.0,
                componentBounds[$0.0]!,
                $0.1,
                componentBounds[$0.1]!
            )
        }

        let disposition: String
        if anyStableInterior || anyBeyondBothBoundaries {
            disposition = "PREPARATION_STATE_SPLIT"
        } else if allDifferencesPostQuantizationExplained {
            disposition = "POSTQUANTIZATION_SPLIT"
        } else if
            headerCrucibleCount == 85
                && allHeaderCrucibleEdgeLocal
                && mutationBytesA == mutationBytesB
        {
            disposition = "RASTER_RESOLVE_EDGE"
        } else {
            disposition = "MIXED_OR_UNCLASSIFIED"
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contract": "CONTRACT-019-R4",
            "disposition": disposition,
            "diagnosticOnly": true,
            "sourceAuthority": false,
            "productionSelected": false,
            "inputBinding": [
                "descriptor": descriptorPath,
                "descriptorSHA256": expectedDescriptorSHA,
                "manifestSHA256": expectedManifestSHA,
                "runAPNGSHA256": runA.fileSHA256,
                "runADecodedRGBASHA256": runA.decodedSHA256,
                "runAProvenanceSHA256": digest(provenanceAData),
                "runBPNGSHA256": runB.fileSHA256,
                "runBDecodedRGBASHA256": runB.decodedSHA256,
                "runBProvenanceSHA256": digest(provenanceBData),
            ],
            "processCounts": [
                "analyzerReplay": 1,
                "sceneKit": 0,
                "metal": 0,
                "authoritativeRaw": 0,
                "normalizer": 0,
                "siblings": 0,
                "modeling": 0,
            ],
            "summary": [
                "differingCoordinateCount": differences.count,
                "headerCrucibleTransitionCount": headerCrucibleCount,
                "transitionCounts": transitionCounts.keys.sorted().map {
                    [
                        "transition": $0,
                        "pixelCount": transitionCounts[$0] ?? 0,
                    ]
                },
                "anyStableInterior3x3": anyStableInterior,
                "anyMoreThanTwoPixelsFromBothBoundaries":
                    anyBeyondBothBoundaries,
                "allHeaderCrucibleEdgeLocal":
                    allHeaderCrucibleEdgeLocal,
                "postQuantizationMutationSetsIdentical":
                    mutationBytesA == mutationBytesB,
                "postQuantizationMutationSetSHA256": digest(mutationBytesA),
                "postQuantizationMutationCountA": mutationsA.count,
                "postQuantizationMutationCountB": mutationsB.count,
                "differingCoordinatesIntersectingMutationTargets":
                    postQuantizationIntersectionCount,
                "allDifferencesPostQuantizationExplained":
                    allDifferencesPostQuantizationExplained,
            ],
            "coordinateEvidence": differences,
            "analyticGeometry": [
                "camera": [
                    "projection": "orthographic-2-to-1",
                    "positionWorld": position.array,
                    "targetWorld": target.array,
                    "orthographicScale": scale,
                    "viewport": camera.viewport,
                    "postProjectionOffsetPixels": camera.offset,
                ],
                "components": projected,
                "pairwiseGapOverlap": pairReports,
            ],
            "stopBoundary":
                "Portal remains rejected. No modeling or further renderer process is authorized.",
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: outputURL, options: .atomic)
        print(disposition)
        print("coordinate-count=\(differences.count)")
    }
}
