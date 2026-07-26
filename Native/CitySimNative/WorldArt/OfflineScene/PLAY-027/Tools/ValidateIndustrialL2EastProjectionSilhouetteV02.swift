import CryptoKit
import Foundation
import SceneKit

enum ProjectionSilhouetteValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l2-east-projection-silhouette-v02 --repository-root <path> --output <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct Component: Decodable {
    let id: String
    let dimensions: [Double]
    let positionWorld: [Double]
    let materialID: String
    let presentationRole: String?
    let identityBearing: Bool?
}

private struct Building: Decodable {
    let massingProfile: String
    let foundationDimensions: [Double]
    let foundationPositionWorld: [Double]
    let massBlocks: [Component]
}

private struct Camera: Decodable {
    let orthographicScale: Double
    let oversamplingFactor: Int
    let positionWorld: [Double]
    let targetWorld: [Double]
    let postProjectionOffsetPixels: [Double]
    let renderViewportPixels: [Int]
    let sourceGroundCenter: [Double]
    let projection: String
    let yawDegrees: Double
    let elevationDegrees: Double
}

private struct Derivation: Decodable {
    let mirror: Bool
    let rotationDegrees: Double
    let siblingSource: String?
    let sourceKind: String
    let transform: String
}

private struct Registration: Decodable {
    let contactPolygonWorld: [[Double]]
    let doorBaseSource: [[Double]]
    let footprintPolygonSource: [[Double]]
    let frontageEdgeWorld: [[Double]]
    let frontageSocketSource: [Double]
    let groundPivotSource: [Double]
    let orientationTransform: String
    let shadowVectorSource: [Double]
}

private struct Sampling: Decodable {
    let linearOversamplingFactor: Int
    let sceneKitAntialiasing: String
    let sourceRevisionBinding: String
    let purpose: String
}

private struct Descriptor: Decodable {
    let schema: Int
    let task: String
    let sceneGeometryID: String
    let logicalBuildingID: String
    let family: String
    let level: Int
    let variantID: String
    let viewDirection: String
    let sourceRevision: String
    let authoredIndependently: Bool
    let productionSelected: Bool
    let derivation: Derivation
    let registration: Registration
    let camera: Camera
    let sampling: Sampling
    let building: Building
    let props: [Component]
}

private struct Material: Decodable {
    let id: String
    let baseColorRGBA: [Double]
    let targetPostLightStep32Bin: Int
    let valueRole: String
}

private struct BinAllocation: Decodable {
    let step32Bin: Int
    let share: Double
}

private struct DistributionTargets: Decodable {
    let p25Minimum: Int
    let p75MinusP25Minimum: Int
    let p95Minimum: Int
    let minimumOccupiedStep32Bins: Int
    let maximumSingleMajorFacadeBinShare: Double
    let majorFacadeBinAllocation: [BinAllocation]
}

private struct MaterialLibrary: Decodable {
    let schema: Int
    let task: String
    let libraryID: String
    let imageGenMaterialSwatchesUsed: Bool
    let materials: [Material]
    let predeclaredDistributionTargets: DistributionTargets
    let productionSelected: Bool
}

private struct AlphaContract: Decodable {
    let schema: Int
    let task: String
    let authority: String
    let captureBoundary: String
    let alphaTruth: String
    let colorClassification: String
    let postHocMagentaGuess: Bool
    let governedRawMutation: Bool
    let mathematicalGuarantee: String
    let productionSelected: Bool
}

private struct ProjectedBounds {
    let minimumX: Double
    let minimumY: Double
    let maximumX: Double
    let maximumY: Double

    var width: Double { maximumX - minimumX }
    var height: Double { maximumY - minimumY }
}

private let expectedDescriptorSHA256 =
    "01ee10ef87c7a23d8fab151091f7237fc0a12563694cea3080f63a25d4e90775"
private let expectedMaterialSHA256 =
    "94069509093c122d4cb2383bd648757561f6561f78b8345c6222b5354f3f18f6"
private let expectedCalibrationSHA256 =
    "d786987922e81c1d19ec5a88aa91443b60566078d1a1e86325c877f3a1bf5484"
private let immutableV01DescriptorSHA256 =
    "2af1e6488ea5ff8e799bf44482d4061b1efa1a190a360a34a4bdef0dc6d849c2"
private let immutableV01MaterialSHA256 =
    "4ca54f2c10c9cc89d9432d2ac921e8cfb7ac88f14141e5446e9657b6533132d9"
private let immutableV01RawSHA256 =
    "77d47f3feef50c584dfd60177e41ab6793247a6772c536270806a0c3196db5b8"
private let immutableV01MetricsSHA256 =
    "d06995080e99ae587b378eac70926433693b712d6af52f0f8e828667761f941d"
private let native2xScale = 144.0 / 512.0

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count
    else { throw ProjectionSilhouetteValidationError.arguments }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw ProjectionSilhouetteValidationError.invalid(message)
    }
}

private func cameraNode(for camera: Camera) -> SCNNode {
    let node = SCNNode()
    let value = SCNCamera()
    value.usesOrthographicProjection = true
    value.orthographicScale = camera.orthographicScale
    value.projectionDirection = .vertical
    node.camera = value
    node.position = SCNVector3(
        camera.positionWorld[0],
        camera.positionWorld[1],
        camera.positionWorld[2]
    )
    node.look(
        at: SCNVector3(
            camera.targetWorld[0],
            camera.targetWorld[1],
            camera.targetWorld[2]
        ),
        up: SCNVector3(0, 1, 0),
        localFront: SCNVector3(0, 0, -1)
    )
    return node
}

private func projectedBounds(
    components: [Component],
    camera: Camera,
    node: SCNNode
) throws -> ProjectedBounds {
    var xs: [Double] = []
    var ys: [Double] = []
    let pixelsPerWorld =
        Double(camera.renderViewportPixels[1])
        / (2 * camera.orthographicScale)
    for component in components {
        try require(component.dimensions.count == 3, "\(component.id) dimensions")
        try require(component.positionWorld.count == 3, "\(component.id) position")
        for xSign in [-1.0, 1.0] {
            for ySign in [-1.0, 1.0] {
                for zSign in [-1.0, 1.0] {
                    let world = SCNVector3(
                        component.positionWorld[0]
                            + xSign * component.dimensions[0] / 2,
                        component.positionWorld[1]
                            + ySign * component.dimensions[1] / 2,
                        component.positionWorld[2]
                            + zSign * component.dimensions[2] / 2
                    )
                    let local = node.convertPosition(world, from: nil)
                    xs.append(
                        Double(camera.renderViewportPixels[0]) / 2
                            + Double(local.x) * pixelsPerWorld
                            + camera.postProjectionOffsetPixels[0]
                    )
                    ys.append(
                        Double(camera.renderViewportPixels[1]) / 2
                            - Double(local.y) * pixelsPerWorld
                            + camera.postProjectionOffsetPixels[1]
                    )
                }
            }
        }
    }
    return ProjectedBounds(
        minimumX: xs.min()!,
        minimumY: ys.min()!,
        maximumX: xs.max()!,
        maximumY: ys.max()!
    )
}

private func projectedGroundPoint(
    _ world: [Double],
    camera: Camera,
    node: SCNNode
) -> [Double] {
    let local = node.convertPosition(
        SCNVector3(world[0], world[1], world[2]),
        from: nil
    )
    let pixelsPerWorld =
        Double(camera.renderViewportPixels[1])
        / (2 * camera.orthographicScale)
    return [
        Double(camera.renderViewportPixels[0]) / 2
            + Double(local.x) * pixelsPerWorld
            + camera.postProjectionOffsetPixels[0],
        Double(camera.renderViewportPixels[1]) / 2
            - Double(local.y) * pixelsPerWorld
            + camera.postProjectionOffsetPixels[1],
    ]
}

private func overlapsInVolume(_ a: Component, _ b: Component) -> Bool {
    (0..<3).allSatisfy { axis in
        let aMinimum = a.positionWorld[axis] - a.dimensions[axis] / 2
        let aMaximum = a.positionWorld[axis] + a.dimensions[axis] / 2
        let bMinimum = b.positionWorld[axis] - b.dimensions[axis] / 2
        let bMaximum = b.positionWorld[axis] + b.dimensions[axis] / 2
        return min(aMaximum, bMaximum) - max(aMinimum, bMinimum) > 0.001
    }
}

private func writeJSON(_ value: Any, to url: URL) throws {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}

@main
enum ValidateIndustrialL2EastProjectionSilhouetteV02Main {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try argument("--repository-root", in: arguments)
        ).standardizedFileURL
        let outputURL = URL(
            fileURLWithPath: try argument("--output", in: arguments)
        ).standardizedFileURL
        let sceneURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/materials/industrial-l02-projection-silhouette-reset-v02.json"
        )
        let calibrationURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v02/prepixel/projection/PROJECTION-CALIBRATION.json"
        )
        let alphaURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v02/prepixel/PRECHROMA-ALPHA-NEUTRAL-CONTRACT.json"
        )
        let frozenFiles: [(String, URL, String)] = [
            (
                "v01Descriptor",
                root.appendingPathComponent(
                    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-raster-survival-v01/scenes/industrial_l02/variant-0/east/scene.json"
                ),
                immutableV01DescriptorSHA256
            ),
            (
                "v01Materials",
                root.appendingPathComponent(
                    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-raster-survival-v01/materials/industrial-l02-raster-survival-art-proof-v01.json"
                ),
                immutableV01MaterialSHA256
            ),
            (
                "v01Raw",
                root.appendingPathComponent(
                    "docs/production/evidence/PLAY-027/industrial-l02/l02/raster-survival-art-proof-v01/proof/diagnostics/east-primary/raw.png"
                ),
                immutableV01RawSHA256
            ),
            (
                "v01Metrics",
                root.appendingPathComponent(
                    "docs/production/evidence/PLAY-027/industrial-l02/l02/raster-survival-art-proof-v01/proof/review/RASTER-SURVIVAL-METRICS.json"
                ),
                immutableV01MetricsSHA256
            ),
        ]

        let descriptorData = try Data(contentsOf: sceneURL)
        let materialData = try Data(contentsOf: materialURL)
        let alphaData = try Data(contentsOf: alphaURL)
        guard
            let descriptorObject = try JSONSerialization.jsonObject(
                with: descriptorData
            ) as? [String: Any],
            let frozenDescriptorObject = try JSONSerialization.jsonObject(
                with: Data(contentsOf: frozenFiles[0].1)
            ) as? [String: Any]
        else {
            throw ProjectionSilhouetteValidationError.invalid(
                "descriptor objects could not be decoded"
            )
        }
        let decoder = JSONDecoder()
        let descriptor = try decoder.decode(Descriptor.self, from: descriptorData)
        let materialLibrary = try decoder.decode(
            MaterialLibrary.self,
            from: materialData
        )
        let alphaContract = try decoder.decode(
            AlphaContract.self,
            from: alphaData
        )

        try require(
            sha256(descriptorData) == expectedDescriptorSHA256,
            "descriptor hash drift"
        )
        try require(
            sha256(materialData) == expectedMaterialSHA256,
            "material hash drift"
        )
        let calibrationHash = try sha256(calibrationURL)
        try require(
            calibrationHash == expectedCalibrationSHA256,
            "calibration hash drift"
        )
        for (_, url, expected) in frozenFiles {
            let actual = try sha256(url)
            try require(actual == expected, "immutable v01/rejection byte drift")
        }

        try require(descriptor.schema == 2, "descriptor schema")
        try require(descriptor.task == "PLAY-027", "descriptor task")
        try require(descriptor.family == "industrial" && descriptor.level == 2, "family/level")
        try require(descriptor.variantID == "variant-0" && descriptor.viewDirection == "east", "identity/direction")
        try require(descriptor.authoredIndependently, "independent authorship")
        try require(!descriptor.productionSelected, "productionSelected must be false")
        try require(!materialLibrary.productionSelected, "material productionSelected")
        try require(descriptor.derivation.transform == "none", "transform")
        try require(!descriptor.derivation.mirror, "mirror")
        try require(descriptor.derivation.rotationDegrees == 0, "rotation")
        try require(descriptor.derivation.siblingSource == nil, "sibling source")
        try require(descriptor.registration.orientationTransform == "none", "registration transform")
        try require(descriptor.registration.contactPolygonWorld == [[-28, -28], [28, -28], [28, 28], [-28, 28]], "contact polygon")
        try require(descriptor.registration.doorBaseSource == [[934, 813], [858, 851]], "door base")
        try require(descriptor.registration.footprintPolygonSource == [[768, 640], [1024, 768], [768, 896], [512, 768]], "source footprint")
        try require(descriptor.registration.frontageSocketSource == [896, 832], "East socket")
        try require(descriptor.registration.groundPivotSource == [768, 896], "ground pivot")
        try require(descriptor.registration.shadowVectorSource == [2, 1], "shadow vector")
        try require(descriptor.camera.projection == "orthographic-2:1", "projection")
        try require(descriptor.camera.yawDegrees == 45 && descriptor.camera.elevationDegrees == 30, "camera direction")
        try require(abs(descriptor.camera.orthographicScale - 79.1959533691406) < 0.000_000_1, "corrected scale")
        try require(descriptor.camera.oversamplingFactor == 4, "camera oversampling")
        try require(descriptor.sampling.linearOversamplingFactor == 4, "sampling oversampling")
        try require(descriptor.sampling.sceneKitAntialiasing == "none", "MSAA must remain none")
        try require(descriptor.sampling.purpose == "diagnostic-regression", "proof purpose")
        for frozenKey in ["registration", "light", "derivation", "toolchainFingerprint", "styleAnchor"] {
            let current = descriptorObject[frozenKey] as? NSObject
            let frozen = frozenDescriptorObject[frozenKey] as? NSObject
            try require(current == frozen, "\(frozenKey) drift from frozen v01")
        }

        let node = cameraNode(for: descriptor.camera)
        let registrationWorldPoints = [
            [-28.0, 0.0, -28.0],
            [28.0, 0.0, -28.0],
            [28.0, 0.0, 28.0],
            [-28.0, 0.0, 28.0],
        ]
        let expectedRegistrationPoints = [
            [768.0, 640.0],
            [1024.0, 768.0],
            [768.0, 896.0],
            [512.0, 768.0],
        ]
        let actualRegistrationPoints = registrationWorldPoints.map {
            projectedGroundPoint($0, camera: descriptor.camera, node: node)
        }
        let registrationErrors = zip(
            actualRegistrationPoints,
            expectedRegistrationPoints
        ).flatMap { actual, expected in
            zip(actual, expected).map { abs($0 - $1) }
        }
        let maximumRegistrationError = registrationErrors.max()!
        let actualSocket = projectedGroundPoint(
            [28, 0, 0],
            camera: descriptor.camera,
            node: node
        )
        let actualPivot = projectedGroundPoint(
            [28, 0, 28],
            camera: descriptor.camera,
            node: node
        )
        try require(maximumRegistrationError <= 1, "footprint corner registration")
        try require(
            zip(actualSocket, descriptor.registration.frontageSocketSource)
                .allSatisfy { abs($0 - $1) <= 1 },
            "computed East socket registration"
        )
        try require(
            zip(actualPivot, descriptor.registration.groundPivotSource)
                .allSatisfy { abs($0 - $1) <= 1 },
            "computed pivot registration"
        )
        let footprintComponents = [
            Component(
                id: "footprint",
                dimensions: [56, 0.001, 56],
                positionWorld: [0, 0, 0],
                materialID: "",
                presentationRole: nil,
                identityBearing: false
            )
        ]
        let footprintBounds = try projectedBounds(
            components: footprintComponents,
            camera: descriptor.camera,
            node: node
        )
        try require(abs(footprintBounds.width - 512) <= 1, "512 footprint width")
        try require(abs(footprintBounds.height - 256) <= 1, "256 footprint height")

        let components = descriptor.building.massBlocks + descriptor.props
        let buildingBounds = try projectedBounds(
            components: components,
            camera: descriptor.camera,
            node: node
        )
        let buildingNative2xWidth = buildingBounds.width * native2xScale
        try require(buildingBounds.width >= 420, "building source width below 420")
        try require(buildingNative2xWidth >= 118, "building native2x width below 118")
        try require(buildingBounds.width / footprintBounds.width >= 0.82, "footprint width share below 82 percent")

        let componentByID = Dictionary(
            uniqueKeysWithValues: components.map { ($0.id, $0) }
        )
        let coreFormIDs = [
            "v02-main-production-hall",
            "v02-loading-spine",
            "v02-administration-wing",
        ]
        let coreFormBounds = try projectedBounds(
            components: coreFormIDs.map { componentByID[$0]! },
            camera: descriptor.camera,
            node: node
        )
        let coreFormNative2xWidth = coreFormBounds.width * native2xScale
        try require(coreFormBounds.width >= 420, "core hall/admin/loading width below 420")
        try require(coreFormNative2xWidth >= 118, "core hall/admin/loading native2x width below 118")
        try require(coreFormBounds.width / footprintBounds.width >= 0.82, "core hall/admin/loading footprint width share below 82 percent")
        let hall = componentByID["v02-main-production-hall"]!
        let admin = componentByID["v02-administration-wing"]!
        let process = [
            componentByID["v02-process-base"]!,
            componentByID["v02-process-monitor"]!,
            componentByID["v02-process-tank"]!,
        ]
        try require(hall.dimensions.max()! >= 42 && hall.dimensions.max()! <= 48, "hall long dimension")
        try require(admin.dimensions.max()! >= 14 && admin.dimensions.max()! <= 20, "admin long dimension")
        try require(process.allSatisfy { $0.dimensions[1] <= 26 }, "process height")

        let docks = ["a", "b", "c"].map {
            componentByID["v02-dock-throat-\($0)"]!
        }
        let dockDoors = ["a", "b", "c"].map {
            componentByID["v02-dock-door-\($0)"]!
        }
        try require(docks.allSatisfy { $0.dimensions[2] > 10 }, "dock width")
        try require(dockDoors.allSatisfy { $0.dimensions[2] > 10 }, "dock door width")
        let sortedDocks = docks.sorted { $0.positionWorld[2] < $1.positionWorld[2] }
        for index in 1..<sortedDocks.count {
            let separation =
                sortedDocks[index].positionWorld[2]
                - sortedDocks[index].dimensions[2] / 2
                - (
                    sortedDocks[index - 1].positionWorld[2]
                    + sortedDocks[index - 1].dimensions[2] / 2
                )
            try require(separation >= 4, "dock separation below four world units")
        }

        var minimumIdentityPixels = Double.greatestFiniteMagnitude
        var identityBudgets: [[String: Any]] = []
        for component in components where component.identityBearing != false {
            let bounds = try projectedBounds(
                components: [component],
                camera: descriptor.camera,
                node: node
            )
            let survivingPixels = max(bounds.width, bounds.height) * native2xScale
            minimumIdentityPixels = min(minimumIdentityPixels, survivingPixels)
            identityBudgets.append([
                "id": component.id,
                "presentationRole": component.presentationRole ?? "unspecified",
                "sourceWidthPixels": bounds.width,
                "sourceHeightPixels": bounds.height,
                "native2xWidthPixels": bounds.width * native2xScale,
                "native2xHeightPixels": bounds.height * native2xScale,
                "native2xMaximumSpanPixels": survivingPixels,
                "passed": survivingPixels >= 6,
            ])
            try require(survivingPixels >= 6, "\(component.id) below six native2x pixels")
        }

        let extents = components.reduce(
            into: (
                xMin: Double.greatestFiniteMagnitude,
                xMax: -Double.greatestFiniteMagnitude,
                zMin: Double.greatestFiniteMagnitude,
                zMax: -Double.greatestFiniteMagnitude
            )
        ) { result, component in
            result.xMin = min(result.xMin, component.positionWorld[0] - component.dimensions[0] / 2)
            result.xMax = max(result.xMax, component.positionWorld[0] + component.dimensions[0] / 2)
            result.zMin = min(result.zMin, component.positionWorld[2] - component.dimensions[2] / 2)
            result.zMax = max(result.zMax, component.positionWorld[2] + component.dimensions[2] / 2)
        }
        try require(extents.xMin >= -28 && extents.xMax <= 28, "x footprint extent")
        try require(extents.zMin >= -28 && extents.zMax <= 28, "z footprint extent")
        try require(descriptor.building.foundationDimensions == [56, 2.4, 56], "foundation dimensions")

        let majorIDs = [
            "v02-main-production-hall",
            "v02-loading-spine",
            "v02-administration-wing",
            "v02-process-base",
        ]
        var majorOverlaps: [[String]] = []
        for first in 0..<majorIDs.count {
            for second in (first + 1)..<majorIDs.count {
                let a = componentByID[majorIDs[first]]!
                let b = componentByID[majorIDs[second]]!
                if overlapsInVolume(a, b) {
                    majorOverlaps.append([a.id, b.id])
                }
            }
        }
        try require(majorOverlaps.isEmpty, "major forms overlap in volume")

        let targets = materialLibrary.predeclaredDistributionTargets
        try require(targets.p25Minimum == 80, "p25 target")
        try require(targets.p75MinusP25Minimum == 48, "IQR target")
        try require(targets.p95Minimum == 192, "p95 target")
        let bins = Set(materialLibrary.materials.map(\.targetPostLightStep32Bin))
        try require(bins.count >= targets.minimumOccupiedStep32Bins, "material bin count")
        let allocationTotal = targets.majorFacadeBinAllocation.reduce(0) { $0 + $1.share }
        try require(abs(allocationTotal - 1) < 0.000_001, "facade allocation total")
        try require(
            targets.majorFacadeBinAllocation.allSatisfy {
                $0.share <= targets.maximumSingleMajorFacadeBinShare
            },
            "major facade allocation exceeds 35 percent"
        )
        try require(materialLibrary.imageGenMaterialSwatchesUsed == false, "unexpected ImageGen swatch")

        try require(alphaContract.schema == 1 && alphaContract.task == "PLAY-027", "alpha contract identity")
        try require(alphaContract.authority.contains("review-presentation-only"), "alpha authority")
        try require(alphaContract.captureBoundary.contains("before the compositor"), "pre-chroma capture boundary")
        try require(alphaContract.alphaTruth.contains("SceneKit RGBA alpha"), "alpha truth")
        try require(alphaContract.colorClassification == "forbidden", "color guess forbidden")
        try require(!alphaContract.postHocMagentaGuess, "post-hoc magenta guess")
        try require(!alphaContract.governedRawMutation, "governed raw mutation")
        try require(alphaContract.mathematicalGuarantee.contains("no magenta fill"), "zero-magenta guarantee")
        try require(!alphaContract.productionSelected, "alpha productionSelected")

        let immutableRecords = try frozenFiles.map { name, url, expected in
            let actual = try sha256(url)
            return [
                "name": name,
                "file": url.path.replacingOccurrences(
                    of: root.path + "/",
                    with: ""
                ),
                "expectedSHA256": expected,
                "actualSHA256": actual,
                "bytePreserved": actual == expected,
            ] as [String: Any]
        }
        let toolURLs = [
            root.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/CalibrateIndustrialL2ProjectionV02.swift"
            ),
            root.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/FreezeIndustrialL2EastProjectionSilhouetteV02.swift"
            ),
            root.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/ValidateIndustrialL2EastProjectionSilhouetteV02.swift"
            ),
        ]
        let toolingRecords = try toolURLs.map {
            [
                "file": $0.path.replacingOccurrences(
                    of: root.path + "/",
                    with: ""
                ),
                "sha256": try sha256($0),
            ]
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-projection-silhouette-reset-v02-validation",
            "descriptorSHA256": sha256(descriptorData),
            "materialLibrarySHA256": sha256(materialData),
            "calibrationSHA256": try sha256(calibrationURL),
            "sceneGeometryID": descriptor.sceneGeometryID,
            "sourceRevision": descriptor.sourceRevision,
            "projection": [
                "footprintWidthSourcePixels": footprintBounds.width,
                "footprintHeightSourcePixels": footprintBounds.height,
                "maximumCornerRegistrationErrorSourcePixels":
                    maximumRegistrationError,
                "actualFootprintCornersSource": actualRegistrationPoints,
                "expectedFootprintCornersSource": expectedRegistrationPoints,
                "actualFrontageSocketSource": actualSocket,
                "expectedFrontageSocketSource":
                    descriptor.registration.frontageSocketSource,
                "actualGroundPivotSource": actualPivot,
                "expectedGroundPivotSource":
                    descriptor.registration.groundPivotSource,
                "buildingOnlyWidthSourcePixels": buildingBounds.width,
                "buildingOnlyWidthNative2xPixels": buildingNative2xWidth,
                "buildingWidthShareOfFootprint": buildingBounds.width / footprintBounds.width,
                "coreHallAdminLoadingWidthSourcePixels": coreFormBounds.width,
                "coreHallAdminLoadingWidthNative2xPixels": coreFormNative2xWidth,
                "coreHallAdminLoadingWidthShareOfFootprint":
                    coreFormBounds.width / footprintBounds.width,
                "orthographicScale": descriptor.camera.orthographicScale,
            ],
            "geometry": [
                "majorFormOverlapCount": majorOverlaps.count,
                "footprintExtents": [
                    "x": [extents.xMin, extents.xMax],
                    "z": [extents.zMin, extents.zMax],
                ],
                "dockCount": docks.count,
                "minimumIdentityFeatureNative2xPixels": minimumIdentityPixels,
                "identityComponentBudgets": identityBudgets,
            ],
            "materials": [
                "declaredStep32Bins": bins.sorted(),
                "majorFacadeAllocationTotal": allocationTotal,
                "maximumMajorFacadeBinShare":
                    targets.majorFacadeBinAllocation.map(\.share).max()!,
                "p25Minimum": targets.p25Minimum,
                "p75MinusP25Minimum": targets.p75MinusP25Minimum,
                "p95Minimum": targets.p95Minimum,
                "minimumOccupiedStep32Bins":
                    targets.minimumOccupiedStep32Bins,
                "laterPixelTargetsOnly": true,
            ],
            "alphaNeutral": [
                "genuinePreChromaAlpha": true,
                "postHocColorGuess": false,
                "governedRawMutation": false,
                "zeroMagentaByConstruction": true,
            ],
            "tooling": toolingRecords,
            "immutableBytePreservation": immutableRecords,
            "rawRenderProcessesConsumed": 0,
            "productionSelected": false,
            "passed": true,
        ]
        try writeJSON(report, to: outputURL)

        print("projection \(footprintBounds.width)x\(footprintBounds.height)")
        print("building \(buildingBounds.width) source \(buildingNative2xWidth) native2x")
        print("identity minimum \(minimumIdentityPixels) native2x")
        print("validation PASS rawRenderProcessesConsumed=0 productionSelected=false")
    }
}
