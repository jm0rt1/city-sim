import CryptoKit
import Foundation

enum ValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-scenes --repository-root <path> --scenes-root <path> --schema <path> --fingerprint <path> --materials <path> --preview-plan <path> --report <path> [--descriptor-schema 1|2]"
        case let .invalid(message):
            return message
        }
    }
}

func sha256(_ url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw ValidationError.arguments
    }
    return arguments[index + 1]
}

func optionalArgument(
    _ name: String,
    in arguments: [String]
) -> String? {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        return nil
    }
    return arguments[index + 1]
}

func midpoint(_ segment: [[Double]]) -> [Double] {
    [
        (segment[0][0] + segment[1][0]) / 2,
        (segment[0][1] + segment[1][1]) / 2,
    ]
}

func midpoint3(_ segment: [[Double]], y: Double) -> [Double] {
    [
        (segment[0][0] + segment[1][0]) / 2,
        y,
        (segment[0][1] + segment[1][1]) / 2,
    ]
}

func approximatelyEqual(
    _ first: [Double],
    _ second: [Double],
    tolerance: Double = 0.000_001
) -> Bool {
    first.count == second.count && zip(first, second).allSatisfy {
        abs($0 - $1) <= tolerance
    }
}

func relativeURL(_ file: String, repositoryRoot: URL) -> URL {
    repositoryRoot.appendingPathComponent(file)
}

func repositoryRelativePath(_ url: URL, repositoryRoot: URL) -> String {
    let prefix = repositoryRoot.path.hasSuffix("/")
        ? repositoryRoot.path
        : repositoryRoot.path + "/"
    guard url.path.hasPrefix(prefix) else {
        return url.path
    }
    return String(url.path.dropFirst(prefix.count))
}

@main
enum ValidateScenesMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try argument("--repository-root", in: arguments)
        ).standardizedFileURL
        let scenesRoot = URL(
            fileURLWithPath: try argument("--scenes-root", in: arguments)
        ).standardizedFileURL
        let schemaURL = URL(
            fileURLWithPath: try argument("--schema", in: arguments)
        ).standardizedFileURL
        let fingerprintURL = URL(
            fileURLWithPath: try argument("--fingerprint", in: arguments)
        ).standardizedFileURL
        let materialsURL = URL(
            fileURLWithPath: try argument("--materials", in: arguments)
        ).standardizedFileURL
        let previewPlanURL = URL(
            fileURLWithPath: try argument("--preview-plan", in: arguments)
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try argument("--report", in: arguments)
        ).standardizedFileURL
        let logicalBuildingID = optionalArgument(
            "--logical-building-id",
            in: arguments
        ) ?? "residential_l01"
        let family = optionalArgument(
            "--family",
            in: arguments
        ) ?? String(logicalBuildingID.split(separator: "_")[0])
        let level = Int(
            optionalArgument("--level", in: arguments) ?? "1"
        ) ?? 1
        let calibrationID = optionalArgument(
            "--calibration-id",
            in: arguments
        ) ?? "residential-l01-variant-0-directional-v03"
        let expectedDescriptorSchema = Int(
            optionalArgument("--descriptor-schema", in: arguments) ?? "1"
        ) ?? 1
        guard expectedDescriptorSchema == 1 || expectedDescriptorSchema == 2
        else {
            throw ValidationError.invalid(
                "descriptor schema must be 1 or 2"
            )
        }
        let directions = ["north", "east", "south", "west"]
        let expectedEdges: [String: [[Double]]] = [
            "north": [[768, 640], [1024, 768]],
            "east": [[1024, 768], [768, 896]],
            "south": [[768, 896], [512, 768]],
            "west": [[512, 768], [768, 640]],
        ]
        let expectedSockets: [String: [Double]] = [
            "north": [896, 704],
            "east": [896, 832],
            "south": [640, 832],
            "west": [640, 704],
        ]
        let expectedDoorBases: [String: [[Double]]] = [
            "north": [[858, 685], [934, 723]],
            "east": [[934, 813], [858, 851]],
            "south": [[678, 851], [602, 813]],
            "west": [[602, 723], [678, 685]],
        ]

        let decoder = JSONDecoder()
        var failures: [String] = []
        var records: [[String: Any]] = []
        var descriptorHashes = Set<String>()
        var geometryIDs = Set<String>()
        var baselineCamera: CameraDescriptor?
        var baselineLight: LightDescriptor?
        var baselineBuilding: BuildingDescriptor?
        var baselineContact: [[Double]]?

        let fingerprintHash = try sha256(fingerprintURL)
        let materialsHash = try sha256(materialsURL)

        for direction in directions {
            let sceneURL = scenesRoot
                .appendingPathComponent(logicalBuildingID)
                .appendingPathComponent("variant-0")
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let data = try Data(contentsOf: sceneURL)
            let descriptor = try decoder.decode(
                SceneDescriptor.self,
                from: data
            )
            let digest = try sha256(sceneURL)
            var itemFailures: [String] = []

            if descriptor.schema != expectedDescriptorSchema
                || descriptor.task != "PLAY-027"
            {
                itemFailures.append("schema/task mismatch")
            }
            do {
                let sampling = try DescriptorSamplingResolver.resolve(
                    descriptor: descriptor
                )
                if sampling.descriptorSchema != expectedDescriptorSchema {
                    itemFailures.append(
                        "effective sampling schema mismatch"
                    )
                }
                if expectedDescriptorSchema == 2
                    && (
                        sampling.contractID
                            != DescriptorSamplingResolver.schema2ContractV3ID
                        || sampling.purpose != "source-authority"
                    )
                {
                    itemFailures.append(
                        "source-authority schema-2 v3 sampling mismatch"
                    )
                }
            } catch {
                itemFailures.append(
                    "descriptor sampling contract invalid: \(error)"
                )
            }
            if descriptor.logicalBuildingID != logicalBuildingID
                || descriptor.family != family
                || descriptor.level != level
                || descriptor.variantID != "variant-0"
                || !descriptor.sourceRevision.hasPrefix("source-v")
                || descriptor.sourceRevision.count != 10
            {
                itemFailures.append("calibration identity mismatch")
            }
            if descriptor.viewDirection != direction {
                itemFailures.append("path direction does not match descriptor")
            }
            if !descriptor.authoredIndependently
                || descriptor.productionSelected
                || descriptor.derivation.sourceKind
                    != "independent-scene-description"
                || descriptor.derivation.siblingSource != nil
                || descriptor.derivation.mirror
                || descriptor.derivation.rotationDegrees != 0
                || descriptor.derivation.transform != "none"
            {
                itemFailures.append("sibling derivation/transform is not closed")
            }
            let referencedFingerprintHash = try sha256(
                relativeURL(
                    descriptor.toolchainFingerprint.file,
                    repositoryRoot: repositoryRoot
                )
            )
            if descriptor.toolchainFingerprint.sha256 != fingerprintHash
                || referencedFingerprintHash != fingerprintHash {
                itemFailures.append("toolchain fingerprint hash mismatch")
            }
            let referencedMaterialsHash = try sha256(
                relativeURL(
                    descriptor.materialLibrary.file,
                    repositoryRoot: repositoryRoot
                )
            )
            if descriptor.materialLibrary.sha256 != materialsHash
                || referencedMaterialsHash != materialsHash {
                itemFailures.append("material library hash mismatch")
            }
            if try sha256(
                relativeURL(
                    descriptor.styleAnchor.file,
                    repositoryRoot: repositoryRoot
                )
            ) != descriptor.styleAnchor.sha256 {
                itemFailures.append("style anchor hash mismatch")
            }
            if descriptor.registration.tileBasisPoints != [72, 36]
                || descriptor.registration.sceneFootprintUnits != [72, 72]
                || descriptor.registration.footprintPolygonSource
                    != [[768, 640], [1024, 768], [768, 896], [512, 768]]
                || descriptor.registration.groundPivotSource != [768, 896]
                || descriptor.registration.frontageEdgeSource
                    != expectedEdges[direction]
                || descriptor.registration.frontageSocketSource
                    != expectedSockets[direction]
                || descriptor.registration.doorBaseSource
                    != expectedDoorBases[direction]
                || descriptor.registration.orientationTransform != "none"
            {
                itemFailures.append("registration contract mismatch")
            }
            if midpoint(descriptor.registration.frontageEdgeSource)
                != descriptor.registration.frontageSocketSource
                || midpoint(descriptor.registration.doorBaseSource)
                    != descriptor.registration.frontageSocketSource
            {
                itemFailures.append("source socket/door midpoint mismatch")
            }
            if descriptor.camera.projection != "orthographic-2:1"
                || descriptor.camera.yawDegrees != 45
                || descriptor.camera.elevationDegrees != 30
                || descriptor.camera.renderViewportPixels != [1536, 1024]
                || descriptor.camera.oversamplingFactor
                    != (expectedDescriptorSchema == 2 ? 4 : 2)
                || descriptor.camera.sourceGroundCenter != [768, 768]
                || descriptor.camera.postProjectionOffsetPixels != [0, 256]
            {
                itemFailures.append("camera contract mismatch")
            }
            if descriptor.light.shadowVectorSource != [2, 1]
                || descriptor.light.shadowReceiver
                    != "task-owned-transparent-ground-plane"
            {
                itemFailures.append("light/shadow contract mismatch")
            }
            let facadeDirections = Set(
                descriptor.facades.map(\.direction)
            )
            let entranceFacades = descriptor.facades.filter(\.hasEntrance)
            guard
                descriptor.facades.count == 4,
                facadeDirections == Set(directions),
                entranceFacades.count == 1,
                let entranceFacade = entranceFacades.first
            else {
                itemFailures.append("four-facade/one-entrance contract mismatch")
                failures.append(contentsOf: itemFailures.map {
                    "\(direction): \($0)"
                })
                continue
            }
            if entranceFacade.direction != direction
                || entranceFacade.id != descriptor.entrance.facadeID
            {
                itemFailures.append("entrance is not on declared facade")
            }
            let expectedEntranceBase = midpoint3(
                entranceFacade.edgeWorld,
                y: descriptor.building.foundationHeight
            )
            if !approximatelyEqual(
                descriptor.entrance.baseWorld,
                expectedEntranceBase
            ) {
                itemFailures.append("entrance base is not facade midpoint")
            }
            if descriptor.entrance.pavilionWidth
                < descriptor.entrance.width + 4
                || descriptor.entrance.pavilionDepth
                    < descriptor.entrance.depth + 3
                || descriptor.entrance.pavilionHeight
                    < descriptor.entrance.height + 4
                || descriptor.entrance.pavilionRoofHeight <= 0
                || descriptor.entrance.porchWidth
                    < descriptor.entrance.width + 4
                || descriptor.entrance.porchColumnWidth <= 0
                || abs(descriptor.entrance.porchLateralOffset)
                    > descriptor.entrance.porchWidth / 2
            {
                itemFailures.append(
                    "entrance pavilion/porch hierarchy is not readable"
                )
            }
            if direction == "north" || direction == "west" {
                if family == "industrial"
                    && descriptor.sourceRevision == "source-v05"
                {
                    let prefix = "i01-\(direction)-frontage"
                    let masses = descriptor.building.massBlocks ?? []
                    let trims = descriptor.building.trimBands ?? []
                    let gantryPosts = masses.filter {
                        $0.id.hasPrefix(prefix)
                            && $0.id.contains("gantry-post")
                    }
                    let hasApron = masses.contains {
                        $0.id == "\(prefix)-service-apron-v5"
                    }
                    let hasHeader = trims.contains {
                        $0.id == "\(prefix)-gantry-header-v5"
                    }
                    let hasCrown = trims.contains {
                        $0.id == "\(prefix)-hazard-crown-v5"
                    }
                    if gantryPosts.count != 2
                        || !hasApron
                        || !hasHeader
                        || !hasCrown
                    {
                        itemFailures.append(
                            "far industrial frontage lacks authored loading throat infrastructure"
                        )
                    }
                } else if family == "industrial"
                    && logicalBuildingID == "industrial_l02"
                    && descriptor.sourceRevision == "source-v02"
                {
                    let prefix = "i02-\(direction)-frontage"
                    let masses = descriptor.building.massBlocks ?? []
                    let trims = descriptor.building.trimBands ?? []
                    let gantryPosts = masses.filter {
                        $0.id.hasPrefix(prefix)
                            && $0.id.hasSuffix("-post")
                    }
                    let hasApron = masses.contains {
                        $0.id == "i02-\(direction)-service-apron"
                    }
                    let headerCount = trims.filter {
                        $0.id.hasPrefix(prefix)
                            && $0.id.hasSuffix("-header")
                    }.count
                    let crownCount = trims.filter {
                        $0.id.hasPrefix(prefix)
                            && $0.id.hasSuffix("-crown")
                    }.count
                    if gantryPosts.count != 3
                        || !hasApron
                        || headerCount != 2
                        || crownCount != 2
                    {
                        itemFailures.append(
                            "Industrial L2 far frontage lacks explicit three-post logistics gantry and service apron"
                        )
                    }
                } else if descriptor.entrance.canopyDepth < 18
                    || abs(descriptor.entrance.porchLateralOffset) < 10
                {
                    itemFailures.append(
                        "far frontage lacks a grounded visible porch return"
                    )
                }
            }
            if descriptor.occlusionExclusions.isEmpty {
                itemFailures.append("occlusion exclusions are missing")
            }
            if level > 1 || family == "commercial" || family == "industrial" {
                if descriptor.building.massingProfile == nil
                    || descriptor.building.massBlocks?.isEmpty != false
                    || descriptor.building.roofVolumes?.isEmpty != false
                    || descriptor.building.trimBands?.isEmpty != false
                    || descriptor.building.usesLegacyDomesticDetails != false
                {
                    itemFailures.append(
                        "density massing/roof/trim profile is incomplete"
                    )
                }
                if descriptor.building.floors < level + 1 {
                    itemFailures.append(
                        "density level lacks readable vertical progression"
                    )
                }
            }
            if family == "commercial" {
                let commercialStyles = Set([
                    "shopfront",
                    "market-arcade",
                    "office-lobby",
                    "tower-lobby",
                ])
                if !commercialStyles.contains(
                    descriptor.entrance.style ?? ""
                ) {
                    itemFailures.append(
                        "commercial entrance lacks an approved storefront/lobby style"
                    )
                }
                let groundFloorGlazing = descriptor.facades.reduce(0) {
                    count, facade in
                    count
                        + facade.windowBays.filter { $0.floor == 1 }.count
                        + (facade.windowRhythms ?? []).filter {
                            $0.floor == 1
                        }.reduce(0) {
                            $0 + $1.centersWorld.count
                        }
                }
                if groundFloorGlazing < 8 {
                    itemFailures.append(
                        "commercial ground floor lacks storefront glazing rhythm"
                    )
                }
                if !descriptor.props.contains(where: {
                    $0.kind == "rooftop-hvac"
                }) {
                    itemFailures.append(
                        "commercial roof lacks explicit mechanical treatment"
                    )
                }
            }
            if family == "industrial" {
                if descriptor.entrance.style != "loading-bay" {
                    itemFailures.append(
                        "industrial frontage lacks an approved loading-bay style"
                    )
                }
                if descriptor.entrance.width < 20
                    || descriptor.entrance.height < 16
                {
                    itemFailures.append(
                        "industrial loading bay is not legible at game scale"
                    )
                }
                if !descriptor.props.contains(where: {
                    $0.kind == "rooftop-hvac"
                }) {
                    itemFailures.append(
                        "industrial roof lacks explicit mechanical treatment"
                    )
                }
                if !descriptor.props.contains(where: {
                    $0.kind == "exhaust-stack"
                }) {
                    itemFailures.append(
                        "industrial roof lacks explicit exhaust treatment"
                    )
                }
                if !descriptor.props.contains(where: {
                    $0.kind == "service-tank"
                }) {
                    itemFailures.append(
                        "industrial service yard lacks explicit tank logic"
                    )
                }
                let windowCount = descriptor.facades.reduce(0) {
                    count, facade in
                    count
                        + facade.windowBays.count
                        + (facade.windowRhythms ?? []).reduce(0) {
                            $0 + $1.centersWorld.count
                        }
                }
                if windowCount > 16 {
                    itemFailures.append(
                        "industrial facade rhythm aliases residential/commercial glazing density"
                    )
                }
            }

            if let camera = baselineCamera, camera != descriptor.camera {
                itemFailures.append("camera drift across directions")
            } else {
                baselineCamera = descriptor.camera
            }
            if let light = baselineLight, light != descriptor.light {
                itemFailures.append("light drift across directions")
            } else {
                baselineLight = descriptor.light
            }
            if let building = baselineBuilding {
                if family == "industrial" {
                    let stableEnvelope =
                        building.width == descriptor.building.width
                        && building.depth == descriptor.building.depth
                        && building.foundationHeight
                            == descriptor.building.foundationHeight
                        && building.floorHeight
                            == descriptor.building.floorHeight
                        && building.floors == descriptor.building.floors
                        && building.wallHeight
                            == descriptor.building.wallHeight
                        && building.roofHeight
                            == descriptor.building.roofHeight
                        && building.roofOverhang
                            == descriptor.building.roofOverhang
                        && building.wallMaterialID
                            == descriptor.building.wallMaterialID
                        && building.trimMaterialID
                            == descriptor.building.trimMaterialID
                        && building.roofMaterialID
                            == descriptor.building.roofMaterialID
                        && building.foundationMaterialID
                            == descriptor.building.foundationMaterialID
                        && building.massingProfile
                            == descriptor.building.massingProfile
                        && building.usesLegacyDomesticDetails
                            == descriptor.building.usesLegacyDomesticDetails
                    if !stableEnvelope {
                        itemFailures.append(
                            "industrial stable building envelope drift across directions"
                        )
                    }
                } else if building != descriptor.building {
                    itemFailures.append(
                        "building envelope drift across directions"
                    )
                }
            } else {
                baselineBuilding = descriptor.building
            }
            if let contact = baselineContact,
                contact != descriptor.registration.contactPolygonWorld
            {
                itemFailures.append("contact polygon drift across directions")
            } else {
                baselineContact = descriptor.registration.contactPolygonWorld
            }
            if !descriptorHashes.insert(digest).inserted {
                itemFailures.append("descriptor hash aliases another direction")
            }
            if !geometryIDs.insert(descriptor.sceneGeometryID).inserted {
                itemFailures.append("scene geometry ID aliases another direction")
            }

            failures.append(contentsOf: itemFailures.map {
                "\(direction): \($0)"
            })
            records.append([
                "viewDirection": direction,
                "file": repositoryRelativePath(
                    sceneURL,
                    repositoryRoot: repositoryRoot
                ),
                "sha256": digest,
                "sceneGeometryID": descriptor.sceneGeometryID,
                "frontageEdgeSource":
                    descriptor.registration.frontageEdgeSource,
                "frontageSocketSource":
                    descriptor.registration.frontageSocketSource,
                "doorBaseSource": descriptor.registration.doorBaseSource,
                "entranceBaseWorld": descriptor.entrance.baseWorld,
                "facadeIDs": descriptor.facades.map(\.id),
                "windowBayCount": descriptor.facades.reduce(0) {
                    $0
                        + $1.windowBays.count
                        + ($1.windowRhythms ?? []).reduce(0) {
                            $0 + $1.centersWorld.count
                        }
                },
                "propIDs": descriptor.props.map(\.id),
                "failures": itemFailures,
            ])
        }

        let previewPlan = try JSONSerialization.jsonObject(
            with: Data(contentsOf: previewPlanURL)
        ) as? [String: Any]
        if previewPlan?["productionSelected"] as? Bool != false {
            failures.append("preview plan is not explicitly non-shipping")
        }

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "calibrationID":
                calibrationID,
            "logicalBuildingID": logicalBuildingID,
            "family": family,
            "level": level,
            "schemaFile": repositoryRelativePath(
                schemaURL,
                repositoryRoot: repositoryRoot
            ),
            "schemaSHA256": try sha256(schemaURL),
            "toolchainFingerprintFile": repositoryRelativePath(
                fingerprintURL,
                repositoryRoot: repositoryRoot
            ),
            "toolchainFingerprintSHA256": fingerprintHash,
            "materialLibraryFile": repositoryRelativePath(
                materialsURL,
                repositoryRoot: repositoryRoot
            ),
            "materialLibrarySHA256": materialsHash,
            "previewPlanFile": repositoryRelativePath(
                previewPlanURL,
                repositoryRoot: repositoryRoot
            ),
            "previewPlanSHA256": try sha256(previewPlanURL),
            "directions": records,
            "uniqueDescriptorHashes": descriptorHashes.count,
            "uniqueSceneGeometryIDs": geometryIDs.count,
            "failures": failures,
            "passed": failures.isEmpty,
            "productionSelected": false,
        ]
        let reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var terminated = reportData
        terminated.append(0x0a)
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try terminated.write(to: reportURL, options: .atomic)
        if !failures.isEmpty {
            throw ValidationError.invalid(failures.joined(separator: "\n"))
        }
    }
}
