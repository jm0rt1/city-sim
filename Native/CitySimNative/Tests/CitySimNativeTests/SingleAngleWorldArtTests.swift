import CryptoKit
import Foundation
import XCTest

final class SingleAngleWorldArtTests: XCTestCase {
    private enum Detail: String, CaseIterable {
        case city
        case neighborhood
        case block
    }

    private struct LogicalIdentity: Hashable {
        let family: String
        let level: Int?
        let variant: Int

        var value: String {
            if let level {
                return "\(family)_l\(String(format: "%02d", level))_v\(variant)"
            }
            return "civic_\(family)_v\(variant)"
        }
    }

    private struct Registration: Equatable {
        let canvasPixels: [Int]
        let groundPivotSource: [Int]
        let orientationTransform: String
    }

    private struct LOD: Equatable {
        let detail: Detail
        let normalizedSHA256: String
        let resourcePath: String
        let resourceBytes: Data
    }

    private struct QuarantinedAsset: Equatable {
        let identity: LogicalIdentity
        let rawSHA256: String
        var lods: [LOD]
        let registration: Registration
        var fallbackSourceKey: String?
        var orientationTransform: String
        var productionSelected: Bool
    }

    private struct Lot: Equatable {
        let x: Int
        let y: Int
        let family: String
        let level: Int
    }

    private enum ValidationError: Error, Equatable {
        case wrongInventoryCount(Int)
        case duplicateLogicalIdentity(String)
        case missingLogicalIdentity(String)
        case wrongLODCount(String, Int)
        case duplicateNormalizedPayload(String)
        case rawAlias(String)
        case resourceDigestMismatch(String)
        case invalidRegistration(String)
        case transformed(String)
        case fallback(String)
        case productionSelected(String)
        case forbiddenPath(String)
    }

    private let expectedAuthorityCommit =
        "004bd2dbcb88e57330425a833505d81ce00e9f90"
    private let expectedBaseCommit =
        "690c46bc9019b641c023f264c46bf8aadb506619"
    private let expectedRouteID = "single-angle-v1:play-101"
    private let expectedRouteSHA256 =
        "00669192181f4695deca0f86950fed0be27cf6aee14c6d9cc611a2efd77bdd70"

    func testExact43LogicalIdentitiesAnd129NormalizedLODs() throws {
        let graph = makeGraph()

        XCTAssertEqual(graph.count, 43)
        XCTAssertEqual(graph.flatMap(\.lods).count, 129)
        XCTAssertNoThrow(try validate(graph))

        let familyCounts = Dictionary(grouping: graph, by: { $0.identity.family })
            .mapValues { $0.count }
        XCTAssertEqual(familyCounts["residential"], 12)
        XCTAssertEqual(familyCounts["commercial"], 12)
        XCTAssertEqual(familyCounts["industrial"], 12)
        XCTAssertEqual(familyCounts["park"], 1)
        XCTAssertEqual(familyCounts["power_plant"], 1)
        XCTAssertEqual(familyCounts["water_tower"], 1)
        XCTAssertEqual(familyCounts["fire_station"], 1)
        XCTAssertEqual(familyCounts["police_station"], 1)
        XCTAssertEqual(familyCounts["school"], 1)
        XCTAssertEqual(familyCounts["city_hall"], 1)

        let logicalIDs = Set(graph.map(\.identity.value))
        XCTAssertEqual(logicalIDs.count, 43)
        XCTAssertEqual(
            Set(graph.flatMap { $0.lods.map(\.normalizedSHA256) }).count,
            129
        )
    }

    func testDirectionFreeIdentityRegistrationAndQuarantineInvariants() throws {
        let graph = makeGraph()
        let directionTokens = ["north", "east", "south", "west"]

        for asset in graph {
            XCTAssertFalse(
                directionTokens.contains { asset.identity.value.contains($0) },
                asset.identity.value
            )
            XCTAssertEqual(asset.registration.canvasPixels, [1536, 1024])
            XCTAssertEqual(asset.registration.groundPivotSource, [768, 896])
            XCTAssertEqual(asset.registration.orientationTransform, "none")
            XCTAssertEqual(asset.orientationTransform, "none")
            XCTAssertNil(asset.fallbackSourceKey)
            XCTAssertFalse(asset.productionSelected)
            XCTAssertTrue(
                asset.lods.allSatisfy {
                    $0.resourcePath.hasPrefix("docs/production/evidence/PLAY-101/")
                }
            )
        }

        XCTAssertNoThrow(try validate(graph))
    }

    func testDeterministicAdjacentVariantSelectionUsesAllVariantsBeforeRepeat() {
        let lots = (0..<9).map { index in
            Lot(
                x: index % 3,
                y: index / 3,
                family: "residential",
                level: 1
            )
        }

        let first = selectVariants(lots, seed: 101)
        let replay = selectVariants(lots.shuffled(), seed: 101)

        XCTAssertEqual(first, replay)
        XCTAssertEqual(first.count, 9)
        XCTAssertEqual(Set(first[0..<3]), [0, 1, 2])
        XCTAssertEqual(Set(first[3..<6]), [0, 1, 2])
        XCTAssertEqual(Set(first[6..<9]), [0, 1, 2])
    }

    func testAtomicActivationRejectsPartialAliasFallbackAndTransform() throws {
        let graph = makeGraph()

        XCTAssertThrowsError(try activate(Array(graph.dropLast()))) {
            XCTAssertEqual($0 as? ValidationError, .wrongInventoryCount(42))
        }

        var duplicate = graph
        duplicate[1] = replacing(duplicate[1], identity: duplicate[0].identity)
        XCTAssertThrowsError(try activate(duplicate)) {
            XCTAssertEqual(
                $0 as? ValidationError,
                .duplicateLogicalIdentity(duplicate[0].identity.value)
            )
        }

        var fallback = graph
        fallback[0].fallbackSourceKey = "residential_l01_v1"
        XCTAssertThrowsError(try activate(fallback)) {
            XCTAssertEqual(
                $0 as? ValidationError,
                .fallback(fallback[0].identity.value)
            )
        }

        var transformed = graph
        transformed[0].orientationTransform = "mirrorX"
        XCTAssertThrowsError(try activate(transformed)) {
            XCTAssertEqual(
                $0 as? ValidationError,
                .transformed(transformed[0].identity.value)
            )
        }

        var selected = graph
        selected[0].productionSelected = true
        XCTAssertThrowsError(try activate(selected)) {
            XCTAssertEqual(
                $0 as? ValidationError,
                .productionSelected(selected[0].identity.value)
            )
        }
    }

    func testQuarantineResourceIntegrityRejectsDecodedPayloadDrift() throws {
        let graph = makeGraph()
        XCTAssertNoThrow(try activate(graph))

        var drifted = graph
        var driftedLODs = drifted[0].lods
        driftedLODs[0] = LOD(
            detail: driftedLODs[0].detail,
            normalizedSHA256: driftedLODs[0].normalizedSHA256,
            resourcePath: driftedLODs[0].resourcePath,
            resourceBytes: Data("drifted-payload".utf8)
        )
        drifted[0].lods = driftedLODs
        XCTAssertThrowsError(try activate(drifted)) {
            XCTAssertEqual(
                $0 as? ValidationError,
                .resourceDigestMismatch(
                    "\(drifted[0].identity.value).\(drifted[0].lods[0].detail.rawValue)"
                )
            )
        }
    }

    func testCompactReceiptBindsRouteCandidateAndQuarantineOnlyDisposition() throws {
        let receiptURL = repositoryRoot
            .appending(path: "docs/production/evidence/PLAY-101")
            .appending(path: "renderer-intake-receipt-v1.json")
        let data = try Data(contentsOf: receiptURL)
        XCTAssertLessThan(data.count, 4096)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data))
        let receipt = try XCTUnwrap(object as? [String: Any])
        XCTAssertEqual(receipt["schema"] as? Int, 1)
        XCTAssertEqual(receipt["task"] as? String, "PLAY-101")
        XCTAssertEqual(receipt["routeId"] as? String, expectedRouteID)
        XCTAssertEqual(receipt["routeSha256"] as? String, expectedRouteSHA256)
        XCTAssertEqual(receipt["authorityCommit"] as? String, expectedAuthorityCommit)
        XCTAssertEqual(receipt["baseCommit"] as? String, expectedBaseCommit)
        XCTAssertEqual(receipt["workerHead"] as? String, expectedAuthorityCommit)

        let inventory = try XCTUnwrap(receipt["inventory"] as? [String: Any])
        XCTAssertEqual(inventory["logicalBuildingImages"] as? Int, 43)
        XCTAssertEqual(inventory["normalizedLODPayloads"] as? Int, 129)

        let quarantine = try XCTUnwrap(receipt["quarantine"] as? [String: Any])
        XCTAssertEqual(quarantine["productionSelected"] as? Bool, false)
        XCTAssertNil(quarantine["fallbackSourceKey"] as? String)
        XCTAssertEqual(quarantine["orientationTransform"] as? String, "none")
        XCTAssertEqual(
            quarantine["activation"] as? String,
            "integration-only-after-exact-43-129"
        )
    }

    private func makeGraph() -> [QuarantinedAsset] {
        var identities: [LogicalIdentity] = []
        for family in ["residential", "commercial", "industrial"] {
            for level in 1...4 {
                for variant in 0...2 {
                    identities.append(
                        LogicalIdentity(family: family, level: level, variant: variant)
                    )
                }
            }
        }
        for family in [
            "park",
            "power_plant",
            "water_tower",
            "fire_station",
            "police_station",
            "school",
            "city_hall",
        ] {
            identities.append(LogicalIdentity(family: family, level: nil, variant: 0))
        }

        return identities.map { identity in
            let rawSHA256 = sha256("raw:\(identity.value)")
            let lods = Detail.allCases.map { detail in
                let payload = Data("normalized:\(identity.value):\(detail.rawValue)".utf8)
                return LOD(
                    detail: detail,
                    normalizedSHA256: sha256(payload),
                    resourcePath: "docs/production/evidence/PLAY-101/quarantine/\(identity.value)/\(detail.rawValue).rgba8",
                    resourceBytes: payload
                )
            }
            return QuarantinedAsset(
                identity: identity,
                rawSHA256: rawSHA256,
                lods: lods,
                registration: Registration(
                    canvasPixels: [1536, 1024],
                    groundPivotSource: [768, 896],
                    orientationTransform: "none"
                ),
                fallbackSourceKey: nil,
                orientationTransform: "none",
                productionSelected: false
            )
        }
    }

    private func validate(_ graph: [QuarantinedAsset]) throws {
        guard graph.count == 43 else {
            throw ValidationError.wrongInventoryCount(graph.count)
        }

        var identities = Set<LogicalIdentity>()
        var rawDigests = Set<String>()
        var normalizedDigests = Set<String>()
        for asset in graph {
            guard identities.insert(asset.identity).inserted else {
                throw ValidationError.duplicateLogicalIdentity(asset.identity.value)
            }
            guard rawDigests.insert(asset.rawSHA256).inserted else {
                throw ValidationError.rawAlias(asset.identity.value)
            }
            guard asset.lods.count == Detail.allCases.count else {
                throw ValidationError.wrongLODCount(asset.identity.value, asset.lods.count)
            }
            guard asset.registration == Registration(
                canvasPixels: [1536, 1024],
                groundPivotSource: [768, 896],
                orientationTransform: "none"
            ) else {
                throw ValidationError.invalidRegistration(asset.identity.value)
            }
            if asset.orientationTransform != "none" {
                throw ValidationError.transformed(asset.identity.value)
            }
            if asset.fallbackSourceKey != nil {
                throw ValidationError.fallback(asset.identity.value)
            }
            if asset.productionSelected {
                throw ValidationError.productionSelected(asset.identity.value)
            }
            for lod in asset.lods {
                guard normalizedDigests.insert(lod.normalizedSHA256).inserted else {
                    throw ValidationError.duplicateNormalizedPayload(
                        "\(asset.identity.value).\(lod.detail.rawValue)"
                    )
                }
                guard sha256(lod.resourceBytes) == lod.normalizedSHA256 else {
                    throw ValidationError.resourceDigestMismatch(
                        "\(asset.identity.value).\(lod.detail.rawValue)"
                    )
                }
                guard lod.resourcePath.hasPrefix(
                    "docs/production/evidence/PLAY-101/"
                ) else {
                    throw ValidationError.forbiddenPath(lod.resourcePath)
                }
            }
        }

        guard identities.count == 43 else {
            throw ValidationError.wrongInventoryCount(identities.count)
        }
        guard normalizedDigests.count == 129 else {
            throw ValidationError.duplicateNormalizedPayload("inventory")
        }
    }

    private func activate(_ graph: [QuarantinedAsset]) throws -> [QuarantinedAsset] {
        try validate(graph)
        return graph.sorted { $0.identity.value < $1.identity.value }
    }

    private func replacing(
        _ asset: QuarantinedAsset,
        identity: LogicalIdentity
    ) -> QuarantinedAsset {
        QuarantinedAsset(
            identity: identity,
            rawSHA256: asset.rawSHA256,
            lods: asset.lods,
            registration: asset.registration,
            fallbackSourceKey: asset.fallbackSourceKey,
            orientationTransform: asset.orientationTransform,
            productionSelected: asset.productionSelected
        )
    }

    private func selectVariants(_ lots: [Lot], seed: Int) -> [Int] {
        var usedByFamilyAndLevel: [String: Set<Int>] = [:]
        let orderedLots = lots.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        return orderedLots.map { lot in
            let key = "\(lot.family):\(lot.level)"
            var used = usedByFamilyAndLevel[key, default: []]
            if used.count == 3 {
                used.removeAll()
            }
            let available = (0...2).filter { !used.contains($0) }
            let digest = sha256(
                "variant:\(seed):\(lot.family):\(lot.level):\(lot.x):\(lot.y)"
            )
            let offset = Int(digest.prefix(8), radix: 16)! % available.count
            let selected = available[offset]
            used.insert(selected)
            usedByFamilyAndLevel[key] = used
            return selected
        }
    }

    private var repositoryRoot: URL {
        var root = URL(filePath: #filePath)
        for _ in 0..<5 {
            root.deleteLastPathComponent()
        }
        return root
    }

    private func sha256(_ value: String) -> String {
        sha256(Data(value.utf8))
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
