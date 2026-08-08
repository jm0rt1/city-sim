import CryptoKit
import Foundation
import XCTest

final class SingleAngleWorldArtTests: XCTestCase {
    private enum Direction: String, CaseIterable, Hashable {
        case north
        case east
        case south
        case west
    }

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

    private struct AuthoredView: Equatable {
        let identity: LogicalIdentity
        var direction: Direction
        var rawSHA256: String
        var lods: [LOD]
        let registration: Registration
        var fallbackSourceKey: String?
        var orientationTransform: String
        var productionSelected: Bool

        var viewKey: String {
            "\(identity.value):\(direction.rawValue)"
        }
    }

    private struct Lot: Equatable {
        let x: Int
        let y: Int
        let family: String
        let level: Int
    }

    private enum ValidationError: Error, Equatable {
        case wrongSourceViewCount(Int)
        case duplicateLogicalIdentity(String)
        case wrongAuthoredViewCount(String, Int)
        case missingDirections(String, [String])
        case duplicateDirection(String, String)
        case duplicateRawSource(String)
        case wrongLODCount(String, Int)
        case duplicateNormalizedPayload(String)
        case resourceDigestMismatch(String)
        case invalidRegistration(String)
        case transformed(String)
        case fallback(String)
        case productionSelected(String)
        case forbiddenPath(String)
        case selectionFailure(String)
    }

    private let expectedAuthorityCommit =
        "a61ab80101f596f56ffc1dd7e37b32bd1b220357"
    private let expectedBaseCommit =
        "a61ab80101f596f56ffc1dd7e37b32bd1b220357"
    private let expectedWorkerHead =
        "56bd4618d7381c13c2f8af7785f22df4bbb6ab17"
    private let expectedRouteID = "four-view-v2:play-101-rotation-intake"
    private let expectedRouteSHA256 =
        "fbb0229fc9491621b1d3d605cc08f863ffd58da4039117e662063b4791955a57"

    func testExact43Identities172AuthoredViewsAnd516NormalizedLODs() throws {
        let graph = makeGraph()
        let identities = Set(graph.map(\.identity))

        XCTAssertEqual(identities.count, 43)
        XCTAssertEqual(graph.count, 172)
        XCTAssertEqual(graph.flatMap(\.lods).count, 516)
        XCTAssertNoThrow(try validate(graph))

        let familyCounts = Dictionary(grouping: identities, by: { $0.family })
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

        XCTAssertEqual(Set(graph.map(\.viewKey)).count, 172)
        XCTAssertEqual(
            Set(graph.flatMap { $0.lods.map(\.normalizedSHA256) }).count,
            516
        )
    }

    func testAuthoredDirectionSelectionPreservesIdentityAndVariant() throws {
        let graph = makeGraph()
        let identity = LogicalIdentity(family: "residential", level: 2, variant: 1)
        var selected: [AuthoredView] = []

        for direction in Direction.allCases {
            let view = try selectView(
                graph,
                identity: identity,
                direction: direction
            )
            selected.append(view)
            XCTAssertEqual(view.identity, identity)
            XCTAssertEqual(view.identity.value, "residential_l02_v1")
            XCTAssertEqual(view.direction, direction)
            XCTAssertFalse(view.identity.value.contains(direction.rawValue))
        }

        XCTAssertEqual(Set(selected.map(\.direction)), Set(Direction.allCases))
        XCTAssertEqual(Set(selected.map(\.rawSHA256)).count, 4)
        XCTAssertEqual(
            Set(selected.flatMap { $0.lods.map(\.normalizedSHA256) }).count,
            12
        )
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

    func testEveryIdentityRequiresAtomicFourOfFourAuthoredDirections() throws {
        let graph = makeGraph()
        let identity = graph[0].identity
        let identityViews = graph.filter { $0.identity == identity }

        XCTAssertEqual(identityViews.count, 4)
        XCTAssertNoThrow(try admitIdentity(identityViews))

        XCTAssertThrowsError(try admitIdentity(Array(identityViews.dropLast()))) {
            XCTAssertEqual(
                $0 as? ValidationError,
                .wrongAuthoredViewCount(identity.value, 3)
            )
        }

        var duplicateDirection = identityViews
        duplicateDirection[3].direction = duplicateDirection[0].direction
        XCTAssertThrowsError(try admitIdentity(duplicateDirection)) {
            XCTAssertEqual(
                $0 as? ValidationError,
                .duplicateDirection(identity.value, "north")
            )
        }

        XCTAssertEqual(try activate(graph).count, 172)
    }

    func testAtomicActivationRejectsAliasFallbackTransformAndSelection() throws {
        let graph = makeGraph()

        XCTAssertThrowsError(try activate(Array(graph.dropLast()))) {
            XCTAssertEqual($0 as? ValidationError, .wrongSourceViewCount(171))
        }

        var aliased = graph
        aliased[1].rawSHA256 = aliased[0].rawSHA256
        XCTAssertThrowsError(try activate(aliased)) {
            XCTAssertEqual(
                $0 as? ValidationError,
                .duplicateRawSource(aliased[1].viewKey)
            )
        }

        var fallback = graph
        fallback[0].fallbackSourceKey = "\(fallback[0].identity.value):south"
        XCTAssertThrowsError(try activate(fallback)) {
            XCTAssertEqual(
                $0 as? ValidationError,
                .fallback(fallback[0].viewKey)
            )
        }

        var transformed = graph
        transformed[0].orientationTransform = "mirrorX"
        XCTAssertThrowsError(try activate(transformed)) {
            XCTAssertEqual(
                $0 as? ValidationError,
                .transformed(transformed[0].viewKey)
            )
        }

        var selected = graph
        selected[0].productionSelected = true
        XCTAssertThrowsError(try activate(selected)) {
            XCTAssertEqual(
                $0 as? ValidationError,
                .productionSelected(selected[0].viewKey)
            )
        }
    }

    func testRegistrationAndResourceIntegrityRejectDecodedPayloadDrift() throws {
        let graph = makeGraph()
        XCTAssertNoThrow(try activate(graph))

        for view in graph {
            XCTAssertEqual(view.registration.canvasPixels, [1536, 1024])
            XCTAssertEqual(view.registration.groundPivotSource, [768, 896])
            XCTAssertEqual(view.registration.orientationTransform, "none")
            XCTAssertEqual(view.orientationTransform, "none")
            XCTAssertNil(view.fallbackSourceKey)
            XCTAssertFalse(view.productionSelected)
            XCTAssertTrue(
                view.lods.allSatisfy {
                    $0.resourcePath.hasPrefix("docs/production/evidence/PLAY-101/")
                }
            )
        }

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
                    "\(drifted[0].viewKey).\(drifted[0].lods[0].detail.rawValue)"
                )
            )
        }
    }

    func testCompactReceiptBindsContract025AndFourViewQuarantine() throws {
        let receiptURL = repositoryRoot
            .appending(path: "docs/production/evidence/PLAY-101")
            .appending(path: "renderer-intake-receipt-v1.json")
        let data = try Data(contentsOf: receiptURL)
        XCTAssertLessThan(data.count, 4096)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data))
        let receipt = try XCTUnwrap(object as? [String: Any])
        XCTAssertEqual(receipt["schema"] as? Int, 2)
        XCTAssertEqual(receipt["task"] as? String, "PLAY-101")
        XCTAssertEqual(receipt["routeId"] as? String, expectedRouteID)
        XCTAssertEqual(receipt["routeSha256"] as? String, expectedRouteSHA256)
        XCTAssertEqual(receipt["authorityCommit"] as? String, expectedAuthorityCommit)
        XCTAssertEqual(receipt["baseCommit"] as? String, expectedBaseCommit)
        XCTAssertEqual(receipt["workerHead"] as? String, expectedWorkerHead)

        let inventory = try XCTUnwrap(receipt["inventory"] as? [String: Any])
        XCTAssertEqual(inventory["logicalBuildingIdentities"] as? Int, 43)
        XCTAssertEqual(inventory["authoredSourceViews"] as? Int, 172)
        XCTAssertEqual(inventory["normalizedLODPayloads"] as? Int, 516)
        XCTAssertEqual(
            inventory["directions"] as? [String],
            Direction.allCases.map(\.rawValue)
        )
        XCTAssertEqual(inventory["directionPartOfLogicalIdentity"] as? Bool, false)

        let quarantine = try XCTUnwrap(receipt["quarantine"] as? [String: Any])
        XCTAssertEqual(quarantine["requiredDirectionsPerIdentity"] as? Int, 4)
        XCTAssertEqual(quarantine["completeIdentities"] as? Int, 43)
        XCTAssertEqual(quarantine["productionSelected"] as? Bool, false)
        XCTAssertNil(quarantine["fallbackSourceKey"] as? String)
        XCTAssertEqual(quarantine["activation"] as? String, "integration-only-after-exact-43-172-516")
    }

    private func makeGraph() -> [AuthoredView] {
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

        return identities.flatMap { identity in
            Direction.allCases.map { direction in
                let viewKey = "\(identity.value):\(direction.rawValue)"
                let rawSHA256 = sha256("raw:\(viewKey)")
                let lods = Detail.allCases.map { detail in
                    let payload = Data("normalized:\(viewKey):\(detail.rawValue)".utf8)
                    return LOD(
                        detail: detail,
                        normalizedSHA256: sha256(payload),
                        resourcePath: "docs/production/evidence/PLAY-101/quarantine/\(identity.value)/\(direction.rawValue)/\(detail.rawValue).rgba8",
                        resourceBytes: payload
                    )
                }
                return AuthoredView(
                    identity: identity,
                    direction: direction,
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
    }

    private func validate(_ graph: [AuthoredView]) throws {
        guard graph.count == 172 else {
            throw ValidationError.wrongSourceViewCount(graph.count)
        }

        var rawDigests = Set<String>()
        var normalizedDigests = Set<String>()
        let grouped = Dictionary(grouping: graph, by: \.identity)
        guard grouped.count == 43 else {
            throw ValidationError.duplicateLogicalIdentity("inventory")
        }

        for (identity, views) in grouped {
            _ = try admitIdentity(views)
            for view in views {
                guard rawDigests.insert(view.rawSHA256).inserted else {
                    throw ValidationError.duplicateRawSource(view.viewKey)
                }
                for lod in view.lods {
                    guard normalizedDigests.insert(lod.normalizedSHA256).inserted else {
                        throw ValidationError.duplicateNormalizedPayload(
                            "\(view.viewKey).\(lod.detail.rawValue)"
                        )
                    }
                    guard sha256(lod.resourceBytes) == lod.normalizedSHA256 else {
                        throw ValidationError.resourceDigestMismatch(
                            "\(view.viewKey).\(lod.detail.rawValue)"
                        )
                    }
                    guard lod.resourcePath.hasPrefix(
                        "docs/production/evidence/PLAY-101/"
                    ) else {
                        throw ValidationError.forbiddenPath(lod.resourcePath)
                    }
                }
            }
            XCTAssertEqual(views.map(\.identity), Array(repeating: identity, count: 4))
        }

        guard normalizedDigests.count == 516 else {
            throw ValidationError.duplicateNormalizedPayload("inventory")
        }
    }

    private func admitIdentity(_ views: [AuthoredView]) throws -> [AuthoredView] {
        guard let identity = views.first?.identity else {
            throw ValidationError.wrongAuthoredViewCount("unknown", 0)
        }
        guard views.count == 4 else {
            throw ValidationError.wrongAuthoredViewCount(identity.value, views.count)
        }

        var directions = Set<Direction>()
        for view in views {
            guard directions.insert(view.direction).inserted else {
                throw ValidationError.duplicateDirection(identity.value, view.direction.rawValue)
            }
            guard view.lods.count == 3 else {
                throw ValidationError.wrongLODCount(view.viewKey, view.lods.count)
            }
            guard view.registration == Registration(
                canvasPixels: [1536, 1024],
                groundPivotSource: [768, 896],
                orientationTransform: "none"
            ) else {
                throw ValidationError.invalidRegistration(view.viewKey)
            }
            if view.orientationTransform != "none" {
                throw ValidationError.transformed(view.viewKey)
            }
            if view.fallbackSourceKey != nil {
                throw ValidationError.fallback(view.viewKey)
            }
            if view.productionSelected {
                throw ValidationError.productionSelected(view.viewKey)
            }
        }
        let missing = Direction.allCases
            .filter { !directions.contains($0) }
            .map(\.rawValue)
        guard missing.isEmpty else {
            throw ValidationError.missingDirections(identity.value, missing)
        }
        return views.sorted { $0.direction.rawValue < $1.direction.rawValue }
    }

    private func activate(_ graph: [AuthoredView]) throws -> [AuthoredView] {
        try validate(graph)
        return graph.sorted { $0.viewKey < $1.viewKey }
    }

    private func selectView(
        _ graph: [AuthoredView],
        identity: LogicalIdentity,
        direction: Direction
    ) throws -> AuthoredView {
        let matches = graph.filter {
            $0.identity == identity && $0.direction == direction
        }
        guard matches.count == 1, let view = matches.first else {
            throw ValidationError.selectionFailure(
                "\(identity.value):\(direction.rawValue)"
            )
        }
        return view
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
