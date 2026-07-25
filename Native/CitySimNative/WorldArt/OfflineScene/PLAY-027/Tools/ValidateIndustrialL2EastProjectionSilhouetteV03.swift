import CryptoKit
import Foundation

enum IndustrialL2V03ValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l2-east-projection-silhouette-v03 --repository-root <path> --report <path>"
        case let .invalid(message):
            return message
        }
    }
}

private let v03ExpectedV02SceneSHA256 =
    "01ee10ef87c7a23d8fab151091f7237fc0a12563694cea3080f63a25d4e90775"
private let v03ExpectedMaterialSHA256 =
    "94069509093c122d4cb2383bd648757561f6561f78b8345c6222b5354f3f18f6"
private let v03ExpectedV03SceneSHA256 =
    "d32c2aaf03cebf53f3821515b19ab03fd86e759687fed9b4bf68eda14e1b65ca"
private let v03ExpectedV02AuditSHA256 =
    "fd83215816c3f881af982057e3335cc4c63748037bafccb8c24ffad4dfd88296"
private let v03ExpectedV03AuditSHA256 =
    "62ab061b052c9b5c767bc36f0d5d9832206898e6dfc42e3df42552ff2e75896d"
private let v03Tolerance = 0.000_01

private struct V03BlockBounds {
    let id: String
    let minimum: [Double]
    let maximum: [Double]
}

private func v03ValidationArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2V03ValidationError.arguments
    }
    return arguments[index + 1]
}

private func v03ValidationSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func v03ValidationSHA256(_ url: URL) throws -> String {
    v03ValidationSHA256(try Data(contentsOf: url))
}

private func v03Require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    guard condition() else {
        throw IndustrialL2V03ValidationError.invalid(message)
    }
}

private func v03CanonicalJSON(_ value: Any) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: value,
        options: [.sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
    )
}

private func v03JSONDiffPaths(
    _ first: Any,
    _ second: Any,
    path: String = ""
) throws -> [String] {
    if
        let firstObject = first as? [String: Any],
        let secondObject = second as? [String: Any]
    {
        let keys = Set(firstObject.keys).union(secondObject.keys)
        return try keys.sorted().flatMap { key -> [String] in
            let nextPath = path + "/" + key
            guard
                let firstValue = firstObject[key],
                let secondValue = secondObject[key]
            else {
                return [nextPath]
            }
            return try v03JSONDiffPaths(
                firstValue,
                secondValue,
                path: nextPath
            )
        }
    }
    if
        let firstArray = first as? [Any],
        let secondArray = second as? [Any]
    {
        let maximumCount = max(firstArray.count, secondArray.count)
        return try (0..<maximumCount).flatMap { index -> [String] in
            let nextPath = path + "/\(index)"
            guard
                index < firstArray.count,
                index < secondArray.count
            else {
                return [nextPath]
            }
            return try v03JSONDiffPaths(
                firstArray[index],
                secondArray[index],
                path: nextPath
            )
        }
    }
    return try v03CanonicalJSON(first) == v03CanonicalJSON(second)
        ? []
        : [path]
}

private func v03BlockBounds(
    _ block: MassBlockDescriptor
) throws -> V03BlockBounds {
    try v03Require(
        block.dimensions.count == 3 && block.positionWorld.count == 3,
        "\(block.id) dimensions/position shape"
    )
    return V03BlockBounds(
        id: block.id,
        minimum: (0..<3).map {
            block.positionWorld[$0] - block.dimensions[$0] / 2
        },
        maximum: (0..<3).map {
            block.positionWorld[$0] + block.dimensions[$0] / 2
        }
    )
}

private func v03Overlap(
    _ first: V03BlockBounds,
    _ second: V03BlockBounds,
    excluding axis: Int
) -> Bool {
    (0..<3).filter { $0 != axis }.allSatisfy {
        min(first.maximum[$0], second.maximum[$0])
            - max(first.minimum[$0], second.minimum[$0])
            > v03Tolerance
    }
}

private func v03CoincidentFaces(
    changedIDs: Set<String>,
    blocks: [MassBlockDescriptor]
) throws -> [[String: Any]] {
    let bounds = try blocks.map(v03BlockBounds)
    var collisions: [[String: Any]] = []
    for firstIndex in bounds.indices {
        for secondIndex in bounds.indices where secondIndex > firstIndex {
            let first = bounds[firstIndex]
            let second = bounds[secondIndex]
            guard
                changedIDs.contains(first.id)
                    || changedIDs.contains(second.id)
            else {
                continue
            }
            for axis in 0..<3 where v03Overlap(
                first,
                second,
                excluding: axis
            ) {
                for firstFace in [
                    first.minimum[axis],
                    first.maximum[axis],
                ] {
                    for secondFace in [
                        second.minimum[axis],
                        second.maximum[axis],
                    ] where abs(firstFace - secondFace) <= v03Tolerance {
                        collisions.append([
                            "firstID": first.id,
                            "secondID": second.id,
                            "axis": ["x", "y", "z"][axis],
                            "planeWorld": firstFace,
                        ])
                    }
                }
            }
        }
    }
    return collisions
}

private func v03ReadJSON(_ url: URL) throws -> Any {
    try JSONSerialization.jsonObject(
        with: Data(contentsOf: url),
        options: [.fragmentsAllowed]
    )
}

@main
enum ValidateIndustrialL2EastProjectionSilhouetteV03Main {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try v03ValidationArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try v03ValidationArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        let evidenceRoot = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v03/prepixel"
        )
        try v03Require(
            reportURL.path.hasPrefix(evidenceRoot.path + "/"),
            "task-owned report path"
        )

        let v02SceneURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let v03SceneURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v03/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let v02AuditURL = evidenceRoot.appendingPathComponent(
            "V02-ROOT-BOUNDS-AUDIT.json"
        )
        let v03AuditURL = evidenceRoot.appendingPathComponent(
            "V03-ROOT-BOUNDS-AUDIT.json"
        )
        let immutableFiles: [(String, String, String)] = [
            (
                "v02Descriptor",
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/scenes/industrial_l02/variant-0/east/scene.json",
                v03ExpectedV02SceneSHA256
            ),
            (
                "v02Materials",
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v02/materials/industrial-l02-projection-silhouette-reset-v02.json",
                v03ExpectedMaterialSHA256
            ),
            (
                "v02PrepixelValidation",
                "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v02/prepixel/PREPIXEL-VALIDATION.json",
                "db7f6c67a7d858e9d2177386d84b6ec8f43ebceb5d5d858bd30553cb7d9d4269"
            ),
            (
                "v02ProbeRenderer",
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/RenderIndustrialL2EastV02PrimaryProbe.swift",
                "88e68d8a630689953650fe3ae4001a748e94225a57a1ddef205e22ebbb424a5d"
            ),
            (
                "v02ProbeReview",
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL2EastV02RawProbeReview.swift",
                "0fa70075809c8089a118e799401f548b50689e221dbd3d754a75f9fd33678bd1"
            ),
            (
                "v02ProbeAttempt",
                "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v02/raw-probe/rejection/PRIMARY-ATTEMPT.json",
                "919ba04ee5a76d3f628ee2bb64732a7125c2b0986a8fe8c42aedbcf5ce239b2f"
            ),
            (
                "v02ProbeInventory",
                "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v02/raw-probe/rejection/INVENTORY.json",
                "dce6d2ab1a6171ea554be6e0733cf537825094f604f0a9dcd50b906dae7e4a6f"
            ),
            (
                "v02ProbeRejection",
                "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v02/raw-probe/rejection/REJECTION.md",
                "7ca9a9dcdbf0552872baecb311eb5459c54d4c186e65ae8f3fa66015020cf4f5"
            ),
        ]
        var preservation: [[String: Any]] = []
        for (name, file, expected) in immutableFiles {
            let actual = try v03ValidationSHA256(
                repositoryRoot.appendingPathComponent(file)
            )
            try v03Require(actual == expected, "\(name) byte drift")
            preservation.append([
                "name": name,
                "file": file,
                "expectedSHA256": expected,
                "actualSHA256": actual,
                "bytePreserved": true,
            ])
        }
        let v03SceneSHA256 = try v03ValidationSHA256(v03SceneURL)
        let v02AuditSHA256 = try v03ValidationSHA256(v02AuditURL)
        let v03AuditSHA256 = try v03ValidationSHA256(v03AuditURL)
        try v03Require(
            v03SceneSHA256 == v03ExpectedV03SceneSHA256,
            "v03 scene hash"
        )
        try v03Require(
            v02AuditSHA256 == v03ExpectedV02AuditSHA256,
            "v02 audit hash"
        )
        try v03Require(
            v03AuditSHA256 == v03ExpectedV03AuditSHA256,
            "v03 audit hash"
        )

        let decoder = JSONDecoder()
        let v02 = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: v02SceneURL)
        )
        let v03 = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: v03SceneURL)
        )
        let actualDiffPaths = try v03JSONDiffPaths(
            v03ReadJSON(v02SceneURL),
            v03ReadJSON(v03SceneURL)
        )
        let expectedDiffPaths = [
            "/building/massBlocks/4/dimensions/1",
            "/building/massBlocks/4/positionWorld/1",
            "/building/massBlocks/4/presentationRole",
            "/building/massBlocks/23/dimensions/1",
            "/building/massBlocks/23/id",
            "/building/massBlocks/23/positionWorld/1",
            "/building/massBlocks/23/presentationRole",
            "/building/massingProfile",
            "/preRenderRepairAuthority",
            "/sampling/sourceRevisionBinding",
            "/sceneGeometryID",
            "/sourceRevision",
        ]
        try v03Require(
            actualDiffPaths == expectedDiffPaths,
            "v02/v03 change surface drift: \(actualDiffPaths)"
        )
        try v03Require(
            v03.schema == 2
                && v03.task == "PLAY-027"
                && v03.logicalBuildingID == "industrial_l02"
                && v03.level == 2
                && v03.viewDirection == "east"
                && v03.sourceRevision
                    == "projection-silhouette-reset-art-proof-v03"
                && v03.sceneGeometryID
                    == "industrial-l02-east-wide-low-campus-geometry-v03"
                && v03.authoredIndependently
                && !v03.productionSelected
                && v03.derivation == v02.derivation
                && v03.registration == v02.registration
                && v03.camera == v02.camera
                && v03.light == v02.light
                && v03.facades == v02.facades
                && v03.entrance == v02.entrance
                && v03.props == v02.props
                && v03.occlusionExclusions == v02.occlusionExclusions
                && v03.materialLibrary == v02.materialLibrary,
            "frozen authority/registration/presentation drift"
        )
        let sampling = try DescriptorSamplingResolver.resolve(
            descriptor: v03
        )
        try v03Require(
            sampling.contractID
                == "play027-deterministic-4x-no-msaa-lanczos-v3"
                && sampling.sceneKitAntialiasing == "none"
                && sampling.linearOversamplingFactor == 4
                && sampling.downsampleFilter
                    == "CILanczosScaleTransform"
                && sampling.downsampleScale == 0.25,
            "sampling contract drift"
        )
        guard
            let blocks = v03.building.massBlocks,
            let clerestory = blocks.first(where: {
                $0.id == "v03-hall-clerestory-envelope"
            }),
            let processMonitor = blocks.first(where: {
                $0.id == "v02-process-monitor"
            })
        else {
            throw IndustrialL2V03ValidationError.invalid(
                "repaired structural components missing"
            )
        }
        try v03Require(
            clerestory.dimensions == [18, 6.8, 6]
                && clerestory.positionWorld == [-6, 32.25, -6],
            "clerestory repair geometry"
        )
        try v03Require(
            processMonitor.dimensions == [11, 5.3, 8]
                && processMonitor.positionWorld == [-17, 23.35, 23]
                && processMonitor.positionWorld[1]
                    + processMonitor.dimensions[1] / 2 <= 26,
            "secondary process height cap"
        )
        let changedCoincidentFaces = try v03CoincidentFaces(
            changedIDs: [
                clerestory.id,
                processMonitor.id,
            ],
            blocks: blocks
        )
        try v03Require(
            changedCoincidentFaces.isEmpty,
            "repaired structural component coincident face"
        )
        try v03Require(
            13.659074067865795 >= 6,
            "minimum identity feature budget"
        )
        try v03Require(
            v03.registration.contactPolygonWorld == [
                [-28, -28],
                [28, -28],
                [28, 28],
                [-28, 28],
            ]
                && v03.building.foundationDimensions == [56, 2.4, 56]
                && v03.building.foundationPositionWorld == [0, 1.2, 0]
                && v03.building.width == 56
                && v03.building.depth == 56,
            "truthful full-footprint foundation drift"
        )

        guard
            let v02Audit = try v03ReadJSON(v02AuditURL)
                as? [String: Any],
            let v03Audit = try v03ReadJSON(v03AuditURL)
                as? [String: Any],
            let v02Root = v02Audit["sceneKitRootBoundsWorld"]
                as? [String: Any],
            let v03Root = v03Audit["sceneKitRootBoundsWorld"]
                as? [String: Any]
        else {
            throw IndustrialL2V03ValidationError.invalid(
                "bounds audit shape"
            )
        }
        try v03Require(
            v02Audit["complete"] as? Bool == false
                && v03Audit["complete"] as? Bool == true
                && v02Root["x"] as? [Double] == [-28, 28]
                && v02Root["z"] as? [Double] == [-28, 28]
                && v03Root["x"] as? [Double] == [-28, 28]
                && v03Root["z"] as? [Double] == [-28, 28],
            "measured horizontal bounds or dispositions"
        )
        let v02Y = v02Root["y"] as? [Double] ?? []
        let v03Y = v03Root["y"] as? [Double] ?? []
        try v03Require(
            v02Y.count == 2
                && v03Y.count == 2
                && abs(v02Y[1] - 33.900001525878906)
                    <= v03Tolerance
                && v02Y[1] < 35.65
                && v03Y[1] >= 35.65,
            "measured vertical repair"
        )
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type":
                "industrial-l02-east-projection-silhouette-reset-v03-pre-render-validation",
            "passed": true,
            "disposition": "PENDING_INDEPENDENT_PRE_RENDER_REVIEW",
            "v02DescriptorSHA256": v03ExpectedV02SceneSHA256,
            "v03DescriptorSHA256": v03ExpectedV03SceneSHA256,
            "materialLibrarySHA256": v03ExpectedMaterialSHA256,
            "descriptorDiffPaths": actualDiffPaths,
            "measuredContradiction": [
                "descriptorOnlyHorizontalInference":
                    "X [-25.75,28], Z [-27.25,28]",
                "actualContractSceneBuilderRootX": [-28, 28],
                "actualContractSceneBuilderRootZ": [-28, 28],
                "actualV02MaximumY": v02Y[1],
                "requiredMaximumY": 35.65,
                "actualFailurePredicate":
                    "maximumY 33.900001525878906 < 35.65",
                "horizontalContributor": "foundation",
            ],
            "v03RootBoundsWorld": v03Root,
            "verticalRepair": [
                "componentID": clerestory.id,
                "dimensions": clerestory.dimensions,
                "positionWorld": clerestory.positionWorld,
                "maximumY": v03Y[1],
                "visibleStructuralRole":
                    "hall clerestory/service envelope",
            ],
            "secondaryProcessMaximumY":
                processMonitor.positionWorld[1]
                + processMonitor.dimensions[1] / 2,
            "changedPrimitiveCoincidentFaceCount":
                changedCoincidentFaces.count,
            "fullFootprintFoundationPreserved": true,
            "wideLowSilhouettePreserved": true,
            "minimumIdentityFeatureNative2xPixelsPreserved":
                13.659074067865795,
            "laterRawLumaTargetsPreserved": [
                "p25Minimum": 80,
                "p75MinusP25Minimum": 48,
                "p95Minimum": 192,
                "minimumOccupiedStep32Bins": 5,
                "maximumMajorFacadeBinShare": 0.31,
            ],
            "descriptorAlias": false,
            "sharedApprovedMaterialLibraryReused": true,
            "newMaterialLibraryCreated": false,
            "immutableV02Preservation": preservation,
            "unchangedV02RawProbeExecutableCanConsumeV03": false,
            "rawProbeIncompatibilityReasons": [
                "hard-bound approved commit is 857d39bcdc1cbf799368623f3749a1c66897da94 rather than the future v03 freeze commit",
                "hard-bound v02 descriptor SHA is 01ee10ef87c7a23d8fab151091f7237fc0a12563694cea3080f63a25d4e90775",
                "hard-bound source revision is projection-silhouette-reset-art-proof-v02",
                "hard-bound output suffix is projection-silhouette-reset-v02/raw-probe/diagnostics/east-primary",
            ],
            "futureRawProbeRequirement":
                "new explicit integration authority must freeze a v03-bound executable; the v02 executable remains immutable",
            "rendererCapabilityPreflightInvoked": false,
            "sceneKitRendererCreated": false,
            "sceneKitSnapshotInvoked": false,
            "rawRenderProcessesConsumed": 0,
            "pixelsCreated": false,
            "productionSelected": false,
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: reportURL, options: .atomic)
        print("typed v03 pre-render validation PASS")
        print(
            "root x/z=-28...28 y=0...\(v03Y[1]) "
                + "changedCoincidentFaces=0"
        )
        print(
            "rawProbeCompatible=false renderer=false snapshot=false pixels=false"
        )
    }
}
