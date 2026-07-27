import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL3V5LanczosOwnershipError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: analyze-industrial-l3-v5-lanczos-ownership \
              --repository-root <path> --output-root <path>
            """
        case let .invalid(message):
            return message
        }
    }
}

private struct Vector3 {
    let x: Double
    let y: Double
    let z: Double

    static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static func * (lhs: Vector3, rhs: Double) -> Vector3 {
        Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    func dot(_ other: Vector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    func cross(_ other: Vector3) -> Vector3 {
        Vector3(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }

    func normalized() throws -> Vector3 {
        let length = sqrt(dot(self))
        guard length.isFinite, length > 0 else {
            throw IndustrialL3V5LanczosOwnershipError.invalid(
                "zero or non-finite vector"
            )
        }
        return self * (1.0 / length)
    }

    var array: [Double] { [x, y, z] }
}

private enum PrimitiveShape {
    case box
    case cylinder
}

private struct Primitive {
    let id: String
    let role: String
    let materialID: String
    let shape: PrimitiveShape
    let dimensions: Vector3
    let position: Vector3
}

private struct Ray {
    let origin: Vector3
    let direction: Vector3
}

private struct Hit {
    let distance: Double
    let primitive: Primitive
    let face: String
}

private struct CameraContract {
    let position: Vector3
    let target: Vector3
    let forward: Vector3
    let right: Vector3
    let up: Vector3
    let orthographicScale: Double
    let viewport: [Int]
    let postOffset: [Double]
    let oversamplingFactor: Int
}

private struct GovernedCoordinate {
    let direction: String
    let coordinate: [Int]
    let label: String
    let expectedRole: String
    let expectedMaterialID: String
}

private struct WeightedSample {
    let x: Int
    let y: Int
    let weight: Double
    let hit: Hit?
}

private let northScene =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-frontage-v01/scenes/"
    + "industrial_l03/variant-0/north/scene.json"
private let westScene =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-frontage-v01/scenes/"
    + "industrial_l03/variant-0/west/scene.json"
private let materialsFile =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-east-v01/materials/"
    + "industrial-l03-cohesion-east-v01.json"
private let authorityFile =
    "docs/production/evidence/PLAY-027/"
    + "INDUSTRIAL-L03-SOURCE-V06-MATERIAL-REPAIR-AUTHORITY-722c8c5.md"

private let expectedFileHashes = [
    northScene:
        "a147ad0a7023374b982a6677325da2912f45796616b03579e1a72eb7da4a6b61",
    westScene:
        "56e9aef896ef5eef435f76ff466f837ac022ff18edbc4e6bd3fa24cb583d78dc",
    materialsFile:
        "f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65",
]

private let governedCoordinates = [
    GovernedCoordinate(
        direction: "north",
        coordinate: [688, 391],
        label: "North high-bay parapet trim",
        expectedRole: "flat-parapet-trim",
        expectedMaterialID: "l3c-charcoal-outline-steel"
    ),
    GovernedCoordinate(
        direction: "west",
        coordinate: [847, 391],
        label: "West high-bay parapet trim",
        expectedRole: "flat-parapet-trim",
        expectedMaterialID: "l3c-charcoal-outline-steel"
    ),
    GovernedCoordinate(
        direction: "north",
        coordinate: [795, 748],
        label: "North annex parapet edge",
        expectedRole: "flat-parapet-trim",
        expectedMaterialID: "l3c-warm-trim"
    ),
    GovernedCoordinate(
        direction: "west",
        coordinate: [786, 524],
        label: "West loading-spine edge",
        expectedRole: "mass-block",
        expectedMaterialID: "l3c-warm-formed-concrete"
    ),
]

private let minimumExpectedOwnership = 0.80
private let lanczosRadius = 3.0
private let downsampleScale = 0.25

private func requiredArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3V5LanczosOwnershipError.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

private func jsonObject(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "JSON object expected: \(url.path)"
        )
    }
    return object
}

private func writeJSON(_ object: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "refusing to overwrite \(url.path)"
        )
    }
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .withoutOverwriting)
}

private func vector(
    _ value: Any?,
    count: Int = 3,
    label: String
) throws -> Vector3 {
    guard
        let values = value as? [NSNumber],
        values.count == count
    else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "\(label) must contain \(count) numbers"
        )
    }
    return Vector3(
        x: values[0].doubleValue,
        y: values[1].doubleValue,
        z: values[2].doubleValue
    )
}

private func numberArray(
    _ value: Any?,
    count: Int,
    label: String
) throws -> [Double] {
    guard
        let values = value as? [NSNumber],
        values.count == count
    else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "\(label) must contain \(count) numbers"
        )
    }
    return values.map(\.doubleValue)
}

private func primitive(
    id: String,
    role: String,
    materialID: String,
    shape: PrimitiveShape,
    dimensions: Any?,
    position: Any?
) throws -> Primitive {
    let dimensions = try vector(
        dimensions,
        label: "\(id).dimensions"
    )
    guard
        dimensions.x > 0,
        dimensions.y > 0,
        dimensions.z > 0
    else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "\(id) dimensions must be positive"
        )
    }
    return Primitive(
        id: id,
        role: role,
        materialID: materialID,
        shape: shape,
        dimensions: dimensions,
        position: try vector(position, label: "\(id).positionWorld")
    )
}

private func appendBoxes(
    _ objects: [[String: Any]],
    role: String,
    to primitives: inout [Primitive]
) throws {
    for object in objects {
        guard
            let id = object["id"] as? String,
            let materialID = object["materialID"] as? String
        else {
            throw IndustrialL3V5LanczosOwnershipError.invalid(
                "\(role) primitive identity missing"
            )
        }
        primitives.append(
            try primitive(
                id: id,
                role: role,
                materialID: materialID,
                shape: .box,
                dimensions: object["dimensions"],
                position: object["positionWorld"]
            )
        )
    }
}

private func appendFlatParapet(
    _ roof: [String: Any],
    to primitives: inout [Primitive]
) throws {
    guard
        let id = roof["id"] as? String,
        roof["shape"] as? String == "flat-parapet",
        let materialID = roof["materialID"] as? String,
        let trimMaterialID = roof["trimMaterialID"] as? String
    else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "only frozen flat-parapet roof volumes are supported"
        )
    }
    let dimensions = try vector(
        roof["dimensions"],
        label: "\(id).dimensions"
    )
    let position = try vector(
        roof["positionWorld"],
        label: "\(id).positionWorld"
    )
    let slabHeight = min(1.5, max(0.8, dimensions.y * 0.22))
    let parapetHeight = max(1.8, dimensions.y - slabHeight)
    let parapetY =
        position.y + dimensions.y / 2 - parapetHeight / 2
    primitives.append(
        Primitive(
            id: id + "-slab",
            role: "flat-parapet-slab",
            materialID: materialID,
            shape: .box,
            dimensions: Vector3(
                x: dimensions.x,
                y: slabHeight,
                z: dimensions.z
            ),
            position: Vector3(
                x: position.x,
                y: position.y - dimensions.y / 2 + slabHeight / 2,
                z: position.z
            )
        )
    )
    let definitions: [(String, Vector3, Vector3)] = [
        (
            "north",
            Vector3(x: dimensions.x, y: parapetHeight, z: 1),
            Vector3(
                x: position.x,
                y: parapetY,
                z: position.z - dimensions.z / 2
            )
        ),
        (
            "south",
            Vector3(x: dimensions.x, y: parapetHeight, z: 1),
            Vector3(
                x: position.x,
                y: parapetY,
                z: position.z + dimensions.z / 2
            )
        ),
        (
            "east",
            Vector3(x: 1, y: parapetHeight, z: dimensions.z),
            Vector3(
                x: position.x + dimensions.x / 2,
                y: parapetY,
                z: position.z
            )
        ),
        (
            "west",
            Vector3(x: 1, y: parapetHeight, z: dimensions.z),
            Vector3(
                x: position.x - dimensions.x / 2,
                y: parapetY,
                z: position.z
            )
        ),
    ]
    for (suffix, parapetDimensions, parapetPosition) in definitions {
        primitives.append(
            Primitive(
                id: id + "-parapet-" + suffix,
                role: "flat-parapet-trim",
                materialID: trimMaterialID,
                shape: .box,
                dimensions: parapetDimensions,
                position: parapetPosition
            )
        )
    }
}

private func primitives(
    from descriptor: [String: Any]
) throws -> [Primitive] {
    guard
        let building = descriptor["building"] as? [String: Any],
        let foundationMaterialID =
            building["foundationMaterialID"] as? String
    else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "building/foundation contract missing"
        )
    }
    var result = [
        try primitive(
            id: "foundation",
            role: "foundation",
            materialID: foundationMaterialID,
            shape: .box,
            dimensions: building["foundationDimensions"],
            position: building["foundationPositionWorld"]
        )
    ]
    try appendBoxes(
        building["massBlocks"] as? [[String: Any]] ?? [],
        role: "mass-block",
        to: &result
    )
    for roof in building["roofVolumes"] as? [[String: Any]] ?? [] {
        try appendFlatParapet(roof, to: &result)
    }
    try appendBoxes(
        building["trimBands"] as? [[String: Any]] ?? [],
        role: "trim-band",
        to: &result
    )
    for object in descriptor["props"] as? [[String: Any]] ?? [] {
        guard
            let id = object["id"] as? String,
            let kind = object["kind"] as? String,
            let materialID = object["materialID"] as? String
        else {
            throw IndustrialL3V5LanczosOwnershipError.invalid(
                "prop identity missing"
            )
        }
        let shape: PrimitiveShape
        switch kind {
        case "explicit-box":
            shape = .box
        case "explicit-cylinder":
            shape = .cylinder
        default:
            throw IndustrialL3V5LanczosOwnershipError.invalid(
                "unsupported explicit prop kind \(kind)"
            )
        }
        result.append(
            try primitive(
                id: id,
                role: kind,
                materialID: materialID,
                shape: shape,
                dimensions: object["dimensions"],
                position: object["positionWorld"]
            )
        )
    }
    let duplicateIDs = Dictionary(grouping: result, by: \.id)
        .filter { $0.value.count > 1 }
        .keys
        .sorted()
    guard duplicateIDs.isEmpty else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "duplicate explicit primitive IDs: \(duplicateIDs)"
        )
    }
    return result
}

private func camera(
    from descriptor: [String: Any]
) throws -> CameraContract {
    guard
        let object = descriptor["camera"] as? [String: Any],
        let scale = (object["orthographicScale"] as? NSNumber)?.doubleValue,
        let oversampling =
            (object["oversamplingFactor"] as? NSNumber)?.intValue
    else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "camera contract missing"
        )
    }
    let position = try vector(
        object["positionWorld"],
        label: "camera.positionWorld"
    )
    let target = try vector(
        object["targetWorld"],
        label: "camera.targetWorld"
    )
    let forward = try (target - position).normalized()
    let right = try forward.cross(
        Vector3(x: 0, y: 1, z: 0)
    ).normalized()
    let up = try right.cross(forward).normalized()
    let viewport = try numberArray(
        object["renderViewportPixels"],
        count: 2,
        label: "camera.renderViewportPixels"
    ).map { Int($0) }
    let offset = try numberArray(
        object["postProjectionOffsetPixels"],
        count: 2,
        label: "camera.postProjectionOffsetPixels"
    )
    guard
        viewport == [1536, 1024],
        offset == [0, 128],
        oversampling == 4,
        scale == 79.1959533691406
    else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "frozen camera/sampling registration drifted"
        )
    }
    return CameraContract(
        position: position,
        target: target,
        forward: forward,
        right: right,
        up: up,
        orthographicScale: scale,
        viewport: viewport,
        postOffset: offset,
        oversamplingFactor: oversampling
    )
}

private func intersectBox(
    ray: Ray,
    primitive: Primitive
) -> Hit? {
    let half = primitive.dimensions * 0.5
    let minimum = primitive.position - half
    let maximum = primitive.position + half
    let origin = [ray.origin.x, ray.origin.y, ray.origin.z]
    let direction = [ray.direction.x, ray.direction.y, ray.direction.z]
    let lower = [minimum.x, minimum.y, minimum.z]
    let upper = [maximum.x, maximum.y, maximum.z]
    let negativeFaces = ["-x", "-y", "-z"]
    let positiveFaces = ["+x", "+y", "+z"]
    var near = -Double.infinity
    var far = Double.infinity
    var nearFace = ""
    for axis in 0..<3 {
        if abs(direction[axis]) < 1e-12 {
            guard origin[axis] >= lower[axis], origin[axis] <= upper[axis]
            else {
                return nil
            }
            continue
        }
        var first = (lower[axis] - origin[axis]) / direction[axis]
        var second = (upper[axis] - origin[axis]) / direction[axis]
        var firstFace = negativeFaces[axis]
        if first > second {
            swap(&first, &second)
            firstFace = positiveFaces[axis]
        }
        if first > near {
            near = first
            nearFace = firstFace
        }
        far = min(far, second)
        if near > far {
            return nil
        }
    }
    guard far >= 0 else { return nil }
    let distance = near >= 0 ? near : far
    return Hit(
        distance: distance,
        primitive: primitive,
        face: near >= 0 ? nearFace : "inside"
    )
}

private func intersectCylinder(
    ray: Ray,
    primitive: Primitive
) -> Hit? {
    let radius = primitive.dimensions.x / 2
    let yMinimum = primitive.position.y - primitive.dimensions.y / 2
    let yMaximum = primitive.position.y + primitive.dimensions.y / 2
    let ox = ray.origin.x - primitive.position.x
    let oz = ray.origin.z - primitive.position.z
    let dx = ray.direction.x
    let dz = ray.direction.z
    var candidates: [(Double, String)] = []
    let a = dx * dx + dz * dz
    let b = 2 * (ox * dx + oz * dz)
    let c = ox * ox + oz * oz - radius * radius
    if a > 1e-12 {
        let discriminant = b * b - 4 * a * c
        if discriminant >= 0 {
            let root = sqrt(discriminant)
            for distance in [
                (-b - root) / (2 * a),
                (-b + root) / (2 * a),
            ] where distance >= 0 {
                let y = ray.origin.y + distance * ray.direction.y
                if y >= yMinimum, y <= yMaximum {
                    candidates.append((distance, "side"))
                }
            }
        }
    }
    if abs(ray.direction.y) > 1e-12 {
        for (y, face) in [(yMinimum, "-y"), (yMaximum, "+y")] {
            let distance = (y - ray.origin.y) / ray.direction.y
            guard distance >= 0 else { continue }
            let x = ox + distance * dx
            let z = oz + distance * dz
            if x * x + z * z <= radius * radius {
                candidates.append((distance, face))
            }
        }
    }
    guard let nearest = candidates.min(by: { $0.0 < $1.0 }) else {
        return nil
    }
    return Hit(
        distance: nearest.0,
        primitive: primitive,
        face: nearest.1
    )
}

private func hit(
    ray: Ray,
    primitives: [Primitive]
) -> Hit? {
    primitives.compactMap { primitive -> Hit? in
        switch primitive.shape {
        case .box:
            return intersectBox(ray: ray, primitive: primitive)
        case .cylinder:
            return intersectCylinder(ray: ray, primitive: primitive)
        }
    }.min(by: { $0.distance < $1.distance })
}

private func ray(
    highResolutionX: Int,
    highResolutionY: Int,
    camera: CameraContract
) -> Ray {
    let width =
        Double(camera.viewport[0] * camera.oversamplingFactor)
    let height =
        Double(camera.viewport[1] * camera.oversamplingFactor)
    let pixelsPerWorld =
        height / (2 * camera.orthographicScale)
    let cameraX =
        (Double(highResolutionX) + 0.5 - width / 2)
        / pixelsPerWorld
    let cameraY =
        (height / 2 - (Double(highResolutionY) + 0.5))
        / pixelsPerWorld
    return Ray(
        origin:
            camera.position
            + camera.right * cameraX
            + camera.up * cameraY,
        direction: camera.forward
    )
}

private func sinc(_ value: Double) -> Double {
    if abs(value) < 1e-12 { return 1 }
    return sin(.pi * value) / (.pi * value)
}

private func lanczosWeight(distanceHighResolutionPixels: Double) -> Double {
    let value = distanceHighResolutionPixels * downsampleScale
    guard abs(value) < lanczosRadius else { return 0 }
    return sinc(value) * sinc(value / lanczosRadius)
}

private func samples(
    target: [Int],
    camera: CameraContract,
    primitives: [Primitive]
) -> [WeightedSample] {
    let inputX = Double(target[0]) - camera.postOffset[0]
    let inputY = Double(target[1]) - camera.postOffset[1]
    let factor = Double(camera.oversamplingFactor)
    let centerX = (inputX + 0.5) * factor - 0.5
    let centerY = (inputY + 0.5) * factor - 0.5
    let radius = Int(ceil(lanczosRadius / downsampleScale))
    var result: [WeightedSample] = []
    for y in
        (Int(floor(centerY)) - radius)...(Int(ceil(centerY)) + radius)
    {
        let wy = lanczosWeight(
            distanceHighResolutionPixels: Double(y) - centerY
        )
        if abs(wy) < 1e-15 { continue }
        let minimumX = Int(floor(centerX)) - radius
        let maximumX = Int(ceil(centerX)) + radius
        for x in minimumX...maximumX {
            let wx = lanczosWeight(
                distanceHighResolutionPixels: Double(x) - centerX
            )
            let weight = wx * wy
            guard weight > 1e-15 else { continue }
            result.append(
                WeightedSample(
                    x: x,
                    y: y,
                    weight: weight,
                    hit: hit(
                        ray: ray(
                            highResolutionX: x,
                            highResolutionY: y,
                            camera: camera
                        ),
                        primitives: primitives
                    )
                )
            )
        }
    }
    return result
}

private func ownershipRecord(
    governed: GovernedCoordinate,
    descriptorSHA256: String,
    camera: CameraContract,
    primitives: [Primitive]
) throws -> ([String: Any], [WeightedSample]) {
    let weightedSamples = samples(
        target: governed.coordinate,
        camera: camera,
        primitives: primitives
    )
    let totalPositiveWeight = weightedSamples.reduce(0) { $0 + $1.weight }
    let attributed = weightedSamples.filter { $0.hit != nil }
    let attributedWeight = attributed.reduce(0) { $0 + $1.weight }
    var byMaterial: [String: Double] = [:]
    var byPrimitive: [String: Double] = [:]
    var byRole: [String: Double] = [:]
    for sample in attributed {
        guard let hit = sample.hit else { continue }
        byMaterial[hit.primitive.materialID, default: 0] += sample.weight
        byPrimitive[hit.primitive.id, default: 0] += sample.weight
        byRole[hit.primitive.role, default: 0] += sample.weight
    }
    let expectedMaterialWeight =
        byMaterial[governed.expectedMaterialID, default: 0]
    let expectedRoleMaterialWeight = attributed.reduce(0) {
        partial, sample in
        guard
            let hit = sample.hit,
            hit.primitive.materialID == governed.expectedMaterialID,
            hit.primitive.role == governed.expectedRole
        else {
            return partial
        }
        return partial + sample.weight
    }
    let ownershipAmongAttributed =
        attributedWeight > 0
        ? expectedRoleMaterialWeight / attributedWeight : 0
    let ownershipOfFullPositiveSupport =
        totalPositiveWeight > 0
        ? expectedRoleMaterialWeight / totalPositiveWeight : 0
    let primaryMaterial = byMaterial.max(by: { $0.value < $1.value })?.key
    let primaryRole = byRole.max(by: { $0.value < $1.value })?.key
    let passed =
        ownershipAmongAttributed >= minimumExpectedOwnership
        && primaryMaterial == governed.expectedMaterialID
        && primaryRole == governed.expectedRole
    let sortedMaterials = byMaterial.sorted { $0.value > $1.value }.map {
        [
            "materialID": $0.key,
            "positiveWeight": $0.value,
            "attributedOwnership":
                attributedWeight > 0 ? $0.value / attributedWeight : 0,
        ] as [String: Any]
    }
    let sortedPrimitives = byPrimitive.sorted {
        $0.value > $1.value
    }.map {
        [
            "primitiveID": $0.key,
            "positiveWeight": $0.value,
            "attributedOwnership":
                attributedWeight > 0 ? $0.value / attributedWeight : 0,
        ] as [String: Any]
    }
    let inputCoordinate = [
        Double(governed.coordinate[0]) - camera.postOffset[0],
        Double(governed.coordinate[1]) - camera.postOffset[1],
    ]
    let center = inputCoordinate.map {
        ($0 + 0.5) * Double(camera.oversamplingFactor) - 0.5
    }
    return (
        [
            "direction": governed.direction,
            "sourceCoordinate": governed.coordinate,
            "downsampleInputCoordinate": inputCoordinate,
            "highResolutionCenter": center,
            "label": governed.label,
            "descriptorSHA256": descriptorSHA256,
            "expectedRole": governed.expectedRole,
            "expectedMaterialID": governed.expectedMaterialID,
            "positiveSupportSampleCount": weightedSamples.count,
            "positiveSupportHitSampleCount": attributed.count,
            "positiveSupportMissSampleCount":
                weightedSamples.count - attributed.count,
            "totalPositiveWeight": totalPositiveWeight,
            "attributedPositiveWeight": attributedWeight,
            "unattributedPositiveWeight":
                totalPositiveWeight - attributedWeight,
            "expectedMaterialPositiveWeight": expectedMaterialWeight,
            "expectedRoleMaterialPositiveWeight":
                expectedRoleMaterialWeight,
            "expectedOwnershipAmongAttributedPositiveSupport":
                ownershipAmongAttributed,
            "expectedOwnershipOfFullPositiveSupport":
                ownershipOfFullPositiveSupport,
            "minimumExpectedOwnershipAmongAttributedPositiveSupport":
                minimumExpectedOwnership,
            "primaryMaterialID": primaryMaterial ?? "none",
            "primaryRole": primaryRole ?? "none",
            "materialOwnership": sortedMaterials,
            "primitiveOwnership": sortedPrimitives,
            "passed": passed,
        ],
        weightedSamples
    )
}

private func writePanel(
    rows: [(GovernedCoordinate, [WeightedSample], Bool)],
    to url: URL
) throws {
    let width = 1120
    let rowHeight = 250
    let height = rowHeight * rows.count
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "could not allocate attribution panel"
        )
    }
    context.setFillColor(
        CGColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1)
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let gridCell = 8
    for (index, row) in rows.enumerated() {
        let originY = height - (index + 1) * rowHeight
        let samples = row.1
        guard
            let minimumX = samples.map(\.x).min(),
            let minimumY = samples.map(\.y).min()
        else {
            continue
        }
        for sample in samples {
            let color: CGColor
            if let hit = sample.hit {
                if
                    hit.primitive.materialID
                        == row.0.expectedMaterialID,
                    hit.primitive.role == row.0.expectedRole
                {
                    color = CGColor(
                        red: 0.88,
                        green: 0.64,
                        blue: 0.20,
                        alpha: 1
                    )
                } else {
                    color = CGColor(
                        red: 0.30,
                        green: 0.52,
                        blue: 0.67,
                        alpha: 1
                    )
                }
            } else {
                color = CGColor(
                    red: 0.76,
                    green: 0.16,
                    blue: 0.68,
                    alpha: 1
                )
            }
            context.setFillColor(color)
            context.fill(
                CGRect(
                    x: 26 + (sample.x - minimumX) * gridCell,
                    y:
                        originY + 24
                        + (sample.y - minimumY) * gridCell,
                    width: gridCell - 1,
                    height: gridCell - 1
                )
            )
        }
        context.setStrokeColor(
            row.2
                ? CGColor(red: 0.33, green: 0.86, blue: 0.48, alpha: 1)
                : CGColor(red: 0.94, green: 0.28, blue: 0.26, alpha: 1)
        )
        context.setLineWidth(5)
        context.stroke(
            CGRect(
                x: 14,
                y: originY + 12,
                width: 230,
                height: 226
            )
        )
        let swatches: [(CGColor, CGFloat)] = [
            (
                CGColor(red: 0.88, green: 0.64, blue: 0.20, alpha: 1),
                300
            ),
            (
                CGColor(red: 0.30, green: 0.52, blue: 0.67, alpha: 1),
                500
            ),
            (
                CGColor(red: 0.76, green: 0.16, blue: 0.68, alpha: 1),
                700
            ),
        ]
        for (color, x) in swatches {
            context.setFillColor(color)
            context.fill(
                CGRect(
                    x: x,
                    y: CGFloat(originY + 82),
                    width: 150,
                    height: 80
                )
            )
        }
        context.setStrokeColor(
            CGColor(red: 0.78, green: 0.80, blue: 0.82, alpha: 1)
        )
        context.setLineWidth(2)
        context.stroke(
            CGRect(
                x: 280,
                y: originY + 62,
                width: 590,
                height: 120
            )
        )
        context.setFillColor(
            row.2
                ? CGColor(red: 0.33, green: 0.86, blue: 0.48, alpha: 1)
                : CGColor(red: 0.94, green: 0.28, blue: 0.26, alpha: 1)
        )
        context.fill(
            CGRect(
                x: 920,
                y: originY + 62,
                width: 150,
                height: 120
            )
        )
    }
    guard let image = context.makeImage() else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "could not make attribution panel"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "could not create attribution panel destination"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "could not finalize attribution panel"
        )
    }
}

private func run() throws {
    let arguments = CommandLine.arguments
    let repositoryRoot = URL(
        fileURLWithPath: try requiredArgument(
            "--repository-root",
            in: arguments
        ),
        isDirectory: true
    ).standardizedFileURL
    let outputRoot = URL(
        fileURLWithPath: try requiredArgument(
            "--output-root",
            in: arguments
        ),
        isDirectory: true
    ).standardizedFileURL
    let rootPrefix = repositoryRoot.path + "/"
    guard outputRoot.path.hasPrefix(rootPrefix) else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "output root must be task-owned inside the repository"
        )
    }
    guard
        outputRoot.path.contains(
            "/docs/production/evidence/PLAY-027/industrial-l03/"
        ),
        !FileManager.default.fileExists(atPath: outputRoot.path)
    else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "output root must be one absent PLAY-027 Industrial L3 evidence path"
        )
    }
    let authorityURL = repositoryRoot.appendingPathComponent(authorityFile)
    guard FileManager.default.fileExists(atPath: authorityURL.path) else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "published source-v06 material-repair authority missing"
        )
    }
    var descriptors: [String: [String: Any]] = [:]
    var descriptorHashes: [String: String] = [:]
    for (direction, path) in [
        ("north", northScene),
        ("west", westScene),
    ] {
        let url = repositoryRoot.appendingPathComponent(path)
        let hash = try sha256(url)
        guard hash == expectedFileHashes[path] else {
            throw IndustrialL3V5LanczosOwnershipError.invalid(
                "\(direction) source-v05 descriptor hash drifted: \(hash)"
            )
        }
        descriptors[direction] = try jsonObject(url)
        descriptorHashes[direction] = hash
    }
    let materialURL = repositoryRoot.appendingPathComponent(materialsFile)
    let materialHash = try sha256(materialURL)
    guard materialHash == expectedFileHashes[materialsFile] else {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "source-v05 material hash drifted: \(materialHash)"
        )
    }
    let materialObject = try jsonObject(materialURL)
    let materialIDs = Set(
        (materialObject["materials"] as? [[String: Any]] ?? [])
            .compactMap { $0["id"] as? String }
    )
    var records: [[String: Any]] = []
    var panelRows: [(GovernedCoordinate, [WeightedSample], Bool)] = []
    for governed in governedCoordinates {
        guard
            materialIDs.contains(governed.expectedMaterialID),
            let descriptor = descriptors[governed.direction],
            let descriptorHash = descriptorHashes[governed.direction]
        else {
            throw IndustrialL3V5LanczosOwnershipError.invalid(
                "\(governed.label) expected material or descriptor missing"
            )
        }
        let primitiveList = try primitives(from: descriptor)
        let cameraContract = try camera(from: descriptor)
        let (record, coordinateSamples) = try ownershipRecord(
            governed: governed,
            descriptorSHA256: descriptorHash,
            camera: cameraContract,
            primitives: primitiveList
        )
        let passed = record["passed"] as? Bool == true
        records.append(record)
        panelRows.append((governed, coordinateSamples, passed))
    }
    let allPassed = records.allSatisfy {
        $0["passed"] as? Bool == true
    }
    let report: [String: Any] = [
        "task": "PLAY-027",
        "purpose":
            "no-SceneKit analytical full-positive-Lanczos-support ownership",
        "authorityCommit":
            "5fd2d6861305fef23d32af4afbac7228f60d925f",
        "traceCheckpoint":
            "722c8c5456f58716827adee598c48361d0ee0295",
        "authorityFile": authorityFile,
        "sceneKitProcessCount": 0,
        "rawProcessCount": 0,
        "normalizerProcessCount": 0,
        "projection": [
            "camera":
                "descriptor position/target look-at, vertical orthographic",
            "orthographicPixelsPerWorld":
                "(viewportHeight*4)/(2*orthographicScale)",
            "registration":
                "output coordinate minus postProjectionOffsetPixels",
            "inversePixelCenter":
                "(downsamplePixel+0.5)*4-0.5",
            "rayModel":
                "orthographic ray, nearest finite explicit primitive",
        ],
        "primitiveModel": [
            "foundation": "axis-aligned box",
            "massBlocks": "axis-aligned boxes",
            "roofVolumes":
                "ContractSceneBuilder flat-parapet slab plus four trim boxes",
            "trimBands": "axis-aligned boxes",
            "explicitBoxProps": "axis-aligned boxes",
            "explicitCylinderProps": "finite vertical cylinders",
        ],
        "kernel": [
            "name": "analytical separable Lanczos-3",
            "downsampleScale": downsampleScale,
            "radiusDownsampleInputPixels": lanczosRadius,
            "positiveSupportRule":
                "retain every 2D product weight greater than 1e-15",
            "ownershipDenominator":
                "positive weight attributed to explicit geometry",
            "fullPositiveSupportAccounting":
                "unattributed/background weight retained separately",
        ],
        "minimumExpectedOwnership": minimumExpectedOwnership,
        "descriptorFiles": [
            "north": [
                "path": northScene,
                "sha256": descriptorHashes["north"]!,
            ],
            "west": [
                "path": westScene,
                "sha256": descriptorHashes["west"]!,
            ],
        ],
        "materialLibrary": [
            "path": materialsFile,
            "sha256": materialHash,
        ],
        "coordinates": records,
        "passed": allPassed,
        "disposition":
            allPassed
            ? "PASS_SOURCE_V06_MATERIAL_REPAIR_ATTRIBUTION_GATE"
            : "STOP_ATTRIBUTION_GATE_FAILED",
    ]
    try writeJSON(
        report,
        to: outputRoot.appendingPathComponent(
            "LANCZOS-OWNERSHIP.json"
        )
    )
    try writePanel(
        rows: panelRows,
        to: outputRoot.appendingPathComponent(
            "LANCZOS-OWNERSHIP.png"
        )
    )
    if !allPassed {
        throw IndustrialL3V5LanczosOwnershipError.invalid(
            "one or more governed coordinates missed the 80% ownership gate"
        )
    }
    print(
        "PASS source-v06 material ownership attribution: "
            + records.map {
                let value =
                    $0[
                        "expectedOwnershipAmongAttributedPositiveSupport"
                    ] as? Double ?? 0
                return String(format: "%.6f", value)
            }.joined(separator: ",")
    )
}

@main
private enum IndustrialL3V5LanczosOwnershipMain {
    static func main() {
        do {
            try run()
        } catch {
            fputs("ERROR: \(error)\n", stderr)
            exit(1)
        }
    }
}
