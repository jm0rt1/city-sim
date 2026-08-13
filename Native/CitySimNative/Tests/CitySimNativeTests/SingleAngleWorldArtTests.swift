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

        var canvasPixels: [Int] {
            switch self {
            case .block:
                return [1024, 683]
            case .neighborhood:
                return [512, 342]
            case .city:
                return [256, 171]
            }
        }
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
        let footprintPolygonSource: [[Int]]
        let frontageSocketSource: [Int]
        let orientationTransform: String
    }

    private struct Provenance: Equatable {
        let rawPath: String
        let rawSHA256: String
        let sourceCommit: String
        let promptReference: String
        let semanticDirection: Direction
    }

    private struct LOD: Equatable {
        let detail: Detail
        let canvasPixels: [Int]
        let filter: String
        let rounding: String
        let normalizedSHA256: String
        let resourcePath: String
        let resourceBytes: Data
        let strictKeyedMatteCount: Int
        let boundaryResidualChromaCount: Int
        let hiddenRGBCount: Int
        let frameEdgeAlphaOccupancy: Int
    }

    private struct AuthoredView: Equatable {
        let identity: LogicalIdentity
        var direction: Direction
        var rawSHA256: String
        var lods: [LOD]
        let registration: Registration
        let provenance: Provenance
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

    private struct QuarantineJob: Equatable {
        let direction: Direction
        let reservedIdentityCount: Int
        let state: String
        let sourceAdmissions: Int
        let rendererQuarantines: Int
        let evidenceRoot: String
    }

    private struct ActivationState: Equatable {
        let sourceAdmissions: Int
        let rendererQuarantines: Int
        let productionSelected: Bool
        let runtimeSelectorImplemented: Bool
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
        case invalidProvenance(String)
        case invalidLOD(String)
        case invalidAlphaChromaPadding(String)
        case transformed(String)
        case fallback(String)
        case productionSelected(String)
        case forbiddenPath(String)
        case selectionFailure(String)
        case activationLocked
    }

    private let expectedAuthorityCommit =
        "5b4c040a182d0a07f4f0f0e32e598797d4314c0e"

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

    func testContract027RotationPermutationSelectsExactAuthoredView() throws {
        let graph = makeGraph()
        let identity = LogicalIdentity(family: "residential", level: 2, variant: 1)
        let expected: [Direction: [Direction]] = [
            .north: [.north, .east, .south, .west],
            .east: [.east, .south, .west, .north],
            .south: [.south, .west, .north, .east],
            .west: [.west, .north, .east, .south],
        ]

        for frontage in Direction.allCases {
            for rotationIndex in 0...3 {
                let view = try selectAuthoredView(
                    graph,
                    identity: identity,
                    frontage: frontage,
                    rotationIndex: rotationIndex
                )
                XCTAssertEqual(view.direction, expected[frontage]![rotationIndex])
                XCTAssertEqual(view.identity, identity)
                XCTAssertEqual(view.registration.canvasPixels, [1536, 1024])
                XCTAssertEqual(view.registration.groundPivotSource, [768, 896])
                XCTAssertEqual(view.lods.map(\.detail), Detail.allCases)
                XCTAssertEqual(view.orientationTransform, "none")
                XCTAssertNil(view.fallbackSourceKey)
            }
        }

        XCTAssertEqual(
            try selectAuthoredView(
                graph,
                identity: identity,
                frontage: .south,
                rotationIndex: -1
            ).direction,
            .east
        )
        XCTAssertEqual(
            try selectAuthoredView(
                graph,
                identity: identity,
                frontage: .west,
                rotationIndex: 4
            ).direction,
            .west
        )

        let missingSouth = graph.filter {
            !($0.identity == identity && $0.direction == .south)
        }
        XCTAssertThrowsError(
            try selectAuthoredView(
                missingSouth,
                identity: identity,
                frontage: .south,
                rotationIndex: 0
            )
        ) {
            XCTAssertEqual(
                $0 as? ValidationError,
                .selectionFailure("residential_l02_v1:south")
            )
        }
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

    func testDirectionExclusiveQuarantineStartsEmptyAndActivationIsLocked() throws {
        let jobs = makeQuarantineJobs()
        XCTAssertEqual(jobs.count, 4)
        XCTAssertEqual(Set(jobs.map(\.direction)), Set(Direction.allCases))
        XCTAssertEqual(Set(jobs.map(\.evidenceRoot)).count, 4)
        for job in jobs {
            XCTAssertEqual(job.reservedIdentityCount, 43)
            XCTAssertEqual(job.state, "empty")
            XCTAssertEqual(job.sourceAdmissions, 0)
            XCTAssertEqual(job.rendererQuarantines, 0)
        }

        let emptyState = ActivationState(
            sourceAdmissions: 0,
            rendererQuarantines: 0,
            productionSelected: false,
            runtimeSelectorImplemented: false
        )
        XCTAssertThrowsError(try assembleCandidate(makeGraph(), state: emptyState)) {
            XCTAssertEqual($0 as? ValidationError, .activationLocked)
        }
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

        for transform in ["mirrorX", "mirrorY", "rotate90", "rotate180", "rotate270"] {
            var transformed = graph
            transformed[0].orientationTransform = transform
            XCTAssertThrowsError(try activate(transformed)) {
                XCTAssertEqual(
                    $0 as? ValidationError,
                    .transformed(transformed[0].viewKey)
                )
            }
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
            canvasPixels: driftedLODs[0].canvasPixels,
            filter: driftedLODs[0].filter,
            rounding: driftedLODs[0].rounding,
            normalizedSHA256: driftedLODs[0].normalizedSHA256,
            resourcePath: driftedLODs[0].resourcePath,
            resourceBytes: Data("drifted-payload".utf8),
            strictKeyedMatteCount: driftedLODs[0].strictKeyedMatteCount,
            boundaryResidualChromaCount: driftedLODs[0].boundaryResidualChromaCount,
            hiddenRGBCount: driftedLODs[0].hiddenRGBCount,
            frameEdgeAlphaOccupancy: driftedLODs[0].frameEdgeAlphaOccupancy
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

        var invalidAlpha = graph
        let sourceLOD = invalidAlpha[0].lods[0]
        invalidAlpha[0].lods[0] = LOD(
            detail: sourceLOD.detail,
            canvasPixels: sourceLOD.canvasPixels,
            filter: sourceLOD.filter,
            rounding: sourceLOD.rounding,
            normalizedSHA256: sourceLOD.normalizedSHA256,
            resourcePath: sourceLOD.resourcePath,
            resourceBytes: sourceLOD.resourceBytes,
            strictKeyedMatteCount: 0,
            boundaryResidualChromaCount: 1,
            hiddenRGBCount: 0,
            frameEdgeAlphaOccupancy: 0
        )
        XCTAssertThrowsError(try activate(invalidAlpha)) {
            XCTAssertEqual(
                $0 as? ValidationError,
                .invalidAlphaChromaPadding(
                    "\(invalidAlpha[0].viewKey).\(sourceLOD.detail.rawValue)"
                )
            )
        }
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
                        canvasPixels: detail.canvasPixels,
                        filter: "lanczos",
                        rounding: "round-half-even",
                        normalizedSHA256: sha256(payload),
                        resourcePath: "docs/production/evidence/PLAY-101/quarantine/\(identity.value)/\(direction.rawValue)/\(detail.rawValue).rgba8",
                        resourceBytes: payload,
                        strictKeyedMatteCount: 0,
                        boundaryResidualChromaCount: 0,
                        hiddenRGBCount: 0,
                        frameEdgeAlphaOccupancy: 0
                    )
                }
                let registration = Registration(
                    canvasPixels: [1536, 1024],
                    groundPivotSource: [768, 896],
                    footprintPolygonSource: [
                        [768, 640],
                        [1024, 768],
                        [768, 896],
                        [512, 768],
                    ],
                    frontageSocketSource: socket(for: direction),
                    orientationTransform: "none"
                )
                return AuthoredView(
                    identity: identity,
                    direction: direction,
                    rawSHA256: rawSHA256,
                    lods: lods,
                    registration: registration,
                    provenance: Provenance(
                        rawPath: "docs/production/evidence/PLAY-101/quarantine/\(identity.value)/\(direction.rawValue)/source.png",
                        rawSHA256: rawSHA256,
                        sourceCommit: expectedAuthorityCommit,
                        promptReference: "synthetic://PLAY-101/\(viewKey)",
                        semanticDirection: direction
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
                guard view.provenance.rawSHA256 == view.rawSHA256,
                      view.provenance.semanticDirection == view.direction,
                      !view.provenance.sourceCommit.isEmpty,
                      !view.provenance.promptReference.isEmpty,
                      view.provenance.rawPath.hasPrefix(
                          "docs/production/evidence/PLAY-101/quarantine/\(view.identity.value)/\(view.direction.rawValue)/"
                      ) else {
                    throw ValidationError.invalidProvenance(view.viewKey)
                }
                guard view.registration.footprintPolygonSource == [
                    [768, 640],
                    [1024, 768],
                    [768, 896],
                    [512, 768],
                ], view.registration.frontageSocketSource == socket(for: view.direction) else {
                    throw ValidationError.invalidRegistration(view.viewKey)
                }
                for lod in view.lods {
                    guard lod.canvasPixels == lod.detail.canvasPixels,
                          lod.filter == "lanczos",
                          lod.rounding == "round-half-even" else {
                        throw ValidationError.invalidLOD(
                            "\(view.viewKey).\(lod.detail.rawValue)"
                        )
                    }
                    guard lod.strictKeyedMatteCount == 0,
                          lod.boundaryResidualChromaCount == 0,
                          lod.hiddenRGBCount == 0,
                          lod.frameEdgeAlphaOccupancy == 0 else {
                        throw ValidationError.invalidAlphaChromaPadding(
                            "\(view.viewKey).\(lod.detail.rawValue)"
                        )
                    }
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
                footprintPolygonSource: [
                    [768, 640],
                    [1024, 768],
                    [768, 896],
                    [512, 768],
                ],
                frontageSocketSource: socket(for: view.direction),
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

    private func assembleCandidate(
        _ graph: [AuthoredView],
        state: ActivationState
    ) throws -> [AuthoredView] {
        _ = try activate(graph)
        guard state.sourceAdmissions == 4,
              state.rendererQuarantines == 4,
              !state.productionSelected,
              !state.runtimeSelectorImplemented else {
            throw ValidationError.activationLocked
        }
        return graph
    }

    private func makeQuarantineJobs() -> [QuarantineJob] {
        Direction.allCases.map { direction in
            QuarantineJob(
                direction: direction,
                reservedIdentityCount: 43,
                state: "empty",
                sourceAdmissions: 0,
                rendererQuarantines: 0,
                evidenceRoot: "docs/production/evidence/PLAY-101/quarantine/\(direction.rawValue)"
            )
        }
    }

    private func socket(for direction: Direction) -> [Int] {
        switch direction {
        case .north:
            return [896, 704]
        case .east:
            return [896, 832]
        case .south:
            return [640, 832]
        case .west:
            return [640, 704]
        }
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

    private func selectAuthoredView(
        _ graph: [AuthoredView],
        identity: LogicalIdentity,
        frontage: Direction,
        rotationIndex: Int
    ) throws -> AuthoredView {
        let normalizedRotation = ((rotationIndex % 4) + 4) % 4
        let directions = Direction.allCases
        guard let frontageIndex = directions.firstIndex(of: frontage) else {
            throw ValidationError.selectionFailure("unknown-frontage")
        }
        let authoredView = directions[(frontageIndex + normalizedRotation) % 4]
        return try selectView(graph, identity: identity, direction: authoredView)
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

    private func sha256(_ value: String) -> String {
        sha256(Data(value.utf8))
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
