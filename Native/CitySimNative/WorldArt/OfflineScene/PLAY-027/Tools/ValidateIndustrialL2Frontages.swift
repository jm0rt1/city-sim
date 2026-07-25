import CryptoKit
import Foundation

enum IndustrialL2FrontageError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l2-frontages --repository-root <path> --scenes-root <path> --report <path>"
        case let .invalid(message):
            return message
        }
    }
}

func industrialL2RequiredArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2FrontageError.arguments
    }
    return arguments[index + 1]
}

func industrialL2Digest(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func industrialL2RepositoryPath(
    _ url: URL,
    root: URL
) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func industrialL2ApproximatelyEqual(
    _ first: [Double],
    _ second: [Double],
    tolerance: Double = 0.000_001
) -> Bool {
    first.count == second.count
        && zip(first, second).allSatisfy {
            abs($0 - $1) <= tolerance
        }
}

func industrialL2MaximumTop(_ descriptor: SceneDescriptor) -> Double {
    var tops: [Double] = []
    for block in descriptor.building.massBlocks ?? [] {
        tops.append(block.positionWorld[1] + block.dimensions[1] / 2)
    }
    for roof in descriptor.building.roofVolumes ?? [] {
        tops.append(roof.positionWorld[1] + roof.dimensions[1] / 2)
    }
    for trim in descriptor.building.trimBands ?? [] {
        tops.append(trim.positionWorld[1] + trim.dimensions[1] / 2)
    }
    tops.append(
        descriptor.building.chimney.positionWorld[1]
            + descriptor.building.chimney.dimensions[1] / 2
    )
    for prop in descriptor.props {
        tops.append(prop.positionWorld[1] + prop.dimensions[1] / 2)
    }
    return tops.max() ?? 0
}

@main
enum ValidateIndustrialL2FrontagesMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try industrialL2RequiredArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let scenesRoot = URL(
            fileURLWithPath: try industrialL2RequiredArgument(
                "--scenes-root",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try industrialL2RequiredArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        let directions = ["north", "east", "south", "west"]
        let expectedEntranceBases: [String: [Double]] = [
            "north": [0, 2, -28],
            "east": [28, 2, 0],
            "south": [0, 2, 28],
            "west": [-28, 2, 0],
        ]
        let expectedSockets: [String: [Double]] = [
            "north": [896, 704],
            "east": [896, 832],
            "south": [640, 832],
            "west": [640, 704],
        ]
        let expectedApronCenters: [String: [Double]] = [
            "north": [0, 2.75, -23],
            "east": [23, 2.75, 0],
            "south": [0, 2.75, 23],
            "west": [-23, 2.75, 0],
        ]
        let decoder = JSONDecoder()
        var failures: [String] = []
        var records: [[String: Any]] = []
        var descriptorHashes = Set<String>()
        var geometryIDs = Set<String>()

        for direction in directions {
            let sceneURL = scenesRoot
                .appendingPathComponent("industrial_l02")
                .appendingPathComponent("variant-0")
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let data = try Data(contentsOf: sceneURL)
            let descriptor = try decoder.decode(
                SceneDescriptor.self,
                from: data
            )
            var itemFailures: [String] = []
            let digest = industrialL2Digest(data)
            let prefix = "i02-\(direction)"
            let masses = descriptor.building.massBlocks ?? []
            let trims = descriptor.building.trimBands ?? []
            let roofs = descriptor.building.roofVolumes ?? []

            if descriptor.schema != 2
                || descriptor.task != "PLAY-027"
                || descriptor.logicalBuildingID != "industrial_l02"
                || descriptor.family != "industrial"
                || descriptor.level != 2
                || descriptor.variantID != "variant-0"
                || !["source-v04", "source-v05"].contains(
                    descriptor.sourceRevision
                )
                || descriptor.viewDirection != direction
            {
                itemFailures.append("identity mismatch")
            }
            if !descriptor.authoredIndependently
                || descriptor.productionSelected
                || descriptor.derivation.sourceKind
                    != "independent-scene-description"
                || descriptor.derivation.siblingSource != nil
                || descriptor.derivation.rotationDegrees != 0
                || descriptor.derivation.mirror
                || descriptor.derivation.transform != "none"
            {
                itemFailures.append(
                    "direction is transformed, aliased, or production-selected"
                )
            }
            do {
                let sampling = try DescriptorSamplingResolver.resolve(
                    descriptor: descriptor
                )
                if sampling.contractID
                    != DescriptorSamplingResolver.schema2ContractV3ID
                    || sampling.purpose != "source-authority"
                    || sampling.sceneKitShadows != "disabled"
                    || descriptor.sampling?.sourceRevisionBinding
                        != descriptor.sourceRevision
                    || (
                        descriptor.sourceRevision == "source-v05"
                        && sampling.sceneKitLightingMode
                            != "authored-constant-v1"
                    )
                    || (
                        descriptor.sourceRevision == "source-v04"
                        && sampling.sceneKitLightingMode
                            != "lambert-scene-lights"
                    )
                {
                    itemFailures.append(
                        "schema-2 v3 source sampling binding mismatch"
                    )
                }
            } catch {
                itemFailures.append("sampling invalid: \(error)")
            }
            if descriptor.sceneGeometryID
                != "industrial-l02-v0-\(direction)-integrated-logistics-geometry-v3"
            {
                itemFailures.append("geometry ID mismatch")
            }
            if descriptor.building.width != 60
                || descriptor.building.depth != 60
                || descriptor.building.foundationHeight != 2
                || descriptor.building.floorHeight != 14
                || descriptor.building.floors != 3
                || descriptor.building.wallHeight != 42
                || descriptor.building.roofHeight != 10
                || descriptor.building.massingProfile
                    != "dual-bay-logistics-foundry-v1"
                || descriptor.building.usesLegacyDomesticDetails != false
            {
                itemFailures.append("frozen L2 envelope mismatch")
            }
            if !industrialL2ApproximatelyEqual(
                descriptor.entrance.baseWorld,
                expectedEntranceBases[direction]!
            )
                || descriptor.entrance.facadeID != "\(direction)-facade"
                || descriptor.entrance.style != "loading-bay"
                || descriptor.entrance.width != 22
                || descriptor.entrance.height != 20
                || descriptor.entrance.canopyDepth != 20
                || descriptor.entrance.porchWidth != 48
                || descriptor.entrance.porchLateralOffset != 0
            {
                itemFailures.append("loading entrance hierarchy mismatch")
            }
            if !industrialL2ApproximatelyEqual(
                descriptor.registration.frontageSocketSource,
                expectedSockets[direction]!
            )
                || descriptor.registration.groundPivotSource != [768, 896]
                || descriptor.registration.contactPolygonWorld
                    != [[-28, -28], [28, -28], [28, 28], [-28, 28]]
            {
                itemFailures.append("registration mismatch")
            }

            let gantryPosts = masses.filter {
                $0.id.hasPrefix("\(prefix)-frontage-")
                    && $0.id.hasSuffix("-post")
            }
            if gantryPosts.count != 3
                || !gantryPosts.allSatisfy({
                    industrialL2ApproximatelyEqual(
                        $0.dimensions,
                        [3, 60, 3]
                    )
                })
            {
                itemFailures.append("three-post gantry envelope mismatch")
            }
            guard let serviceApron = masses.first(where: {
                $0.id == "\(prefix)-service-apron"
            }) else {
                itemFailures.append("service apron missing")
                failures.append(contentsOf: itemFailures.map {
                    "\(direction): \($0)"
                })
                continue
            }
            let expectedApronDimensions =
                direction == "north" || direction == "south"
                ? [50.0, 0.8, 20.0]
                : [20.0, 0.8, 50.0]
            if !industrialL2ApproximatelyEqual(
                serviceApron.dimensions,
                expectedApronDimensions
            )
                || !industrialL2ApproximatelyEqual(
                    serviceApron.positionWorld,
                    expectedApronCenters[direction]!
                )
            {
                itemFailures.append("service apron geometry mismatch")
            }
            let headerCount = trims.filter {
                $0.id.hasPrefix("\(prefix)-frontage-")
                    && $0.id.hasSuffix("-header")
            }.count
            let crownCount = trims.filter {
                $0.id.hasPrefix("\(prefix)-frontage-")
                    && $0.id.hasSuffix("-crown")
            }.count
            let laneCount = trims.filter {
                $0.id.hasPrefix("\(prefix)-apron-")
                    && $0.id.hasSuffix("-lane")
            }.count
            if headerCount != 2 || crownCount != 2 || laneCount != 2 {
                itemFailures.append(
                    "dual loading headers, crowns, or apron lanes missing"
                )
            }
            if masses.count != 9
                || roofs.count != 6
                || trims.count != 10
            {
                itemFailures.append("authored primitive inventory mismatch")
            }
            let requiredMassSuffixes = [
                "high-assembly-hall",
                "fabrication-annex",
                "process-tower",
                "dual-dock-house",
                "secondary-loading-door",
            ]
            if !requiredMassSuffixes.allSatisfy({ suffix in
                masses.contains { $0.id == "\(prefix)-\(suffix)" }
            }) {
                itemFailures.append("L2 operational massing inventory missing")
            }
            let propKinds = Set(descriptor.props.map(\.kind))
            if propKinds != Set([
                "rooftop-hvac",
                "exhaust-stack",
                "service-tank",
            ]) {
                itemFailures.append("industrial roof/service props mismatch")
            }
            let windowCount = descriptor.facades.reduce(0) {
                $0 + $1.windowBays.count
                    + ($1.windowRhythms ?? []).reduce(0) {
                        $0 + $1.centersWorld.count
                    }
            }
            if windowCount != 11 {
                itemFailures.append("industrial clerestory rhythm mismatch")
            }
            if industrialL2MaximumTop(descriptor) < 64 {
                itemFailures.append("L2 vertical silhouette is too weak")
            }
            if !descriptorHashes.insert(digest).inserted {
                itemFailures.append("descriptor aliases a sibling")
            }
            if !geometryIDs.insert(descriptor.sceneGeometryID).inserted {
                itemFailures.append("geometry ID aliases a sibling")
            }

            failures.append(contentsOf: itemFailures.map {
                "\(direction): \($0)"
            })
            records.append([
                "viewDirection": direction,
                "sceneFile": industrialL2RepositoryPath(
                    sceneURL,
                    root: repositoryRoot
                ),
                "descriptorSHA256": digest,
                "sceneGeometryID": descriptor.sceneGeometryID,
                "massBlockCount": masses.count,
                "roofVolumeCount": roofs.count,
                "trimBandCount": trims.count,
                "windowCount": windowCount,
                "maximumStructuralTopWorld": industrialL2MaximumTop(
                    descriptor
                ),
                "frontageSocketSource":
                    descriptor.registration.frontageSocketSource,
                "entranceBaseWorld": descriptor.entrance.baseWorld,
                "gantryPostCount": gantryPosts.count,
                "frontageHeaderCount": headerCount,
                "frontageCrownCount": crownCount,
                "serviceApronDimensions": serviceApron.dimensions,
                "serviceApronPositionWorld": serviceApron.positionWorld,
                "failures": itemFailures,
                "passed": itemFailures.isEmpty,
            ])
        }

        let l1SceneURL = scenesRoot
            .appendingPathComponent("industrial_l01")
            .appendingPathComponent("variant-0")
            .appendingPathComponent("north")
            .appendingPathComponent("scene.json")
        let l2SceneURL = scenesRoot
            .appendingPathComponent("industrial_l02")
            .appendingPathComponent("variant-0")
            .appendingPathComponent("north")
            .appendingPathComponent("scene.json")
        let l1 = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: l1SceneURL)
        )
        let l2 = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: l2SceneURL)
        )
        let progressionPassed =
            l1.building.massingProfile != l2.building.massingProfile
            && l2.building.floors > l1.building.floors
            && l2.building.wallHeight > l1.building.wallHeight
            && (l2.building.massBlocks?.count ?? 0)
                > (l1.building.massBlocks?.count ?? 0)
            && industrialL2MaximumTop(l2)
                > industrialL2MaximumTop(l1) + 4
        if !progressionPassed {
            failures.append(
                "Industrial L2 does not materially progress beyond accepted L1"
            )
        }

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l02",
            "sourceRevision": "source-v05",
            "purpose":
                "freeze Industrial L2 source-v05 loading-logistics frontage, descriptor-bound disabled SceneKit shadows and authored constant lighting, independent direction authorship, and non-aliasing progression beyond accepted Industrial L1",
            "directions": records,
            "uniqueDescriptorHashCount": descriptorHashes.count,
            "uniqueSceneGeometryIDCount": geometryIDs.count,
            "l1ToL2Progression": [
                "l1MassingProfile": l1.building.massingProfile ?? "",
                "l2MassingProfile": l2.building.massingProfile ?? "",
                "l1Floors": l1.building.floors,
                "l2Floors": l2.building.floors,
                "l1WallHeight": l1.building.wallHeight,
                "l2WallHeight": l2.building.wallHeight,
                "l1MaximumStructuralTopWorld":
                    industrialL2MaximumTop(l1),
                "l2MaximumStructuralTopWorld":
                    industrialL2MaximumTop(l2),
                "passed": progressionPassed,
            ],
            "failures": failures,
            "passed": failures.isEmpty,
            "productionSelected": false,
        ]
        var reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        reportData.append(0x0a)
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try reportData.write(to: reportURL, options: .atomic)
        if !failures.isEmpty {
            throw IndustrialL2FrontageError.invalid(
                "Industrial L2 frontage validation failed: "
                    + failures.joined(separator: "; ")
            )
        }
    }
}
