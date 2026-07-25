import CryptoKit
import Foundation
import XCTest
@testable import CitySimNative

final class SpatialConsequenceTests: XCTestCase {
    func testMapIsImmutableRowMajorAndProvidesBoundedConstantIndexLookup() throws {
        var state = CityGameState.newCity(seed: 42)
        let snapshot = try CityPresentationSnapshot(state: state)

        XCTAssertEqual(snapshot.spatialConsequences.width, 24)
        XCTAssertEqual(snapshot.spatialConsequences.height, 24)
        XCTAssertEqual(snapshot.spatialConsequences.samples.count, 576)
        XCTAssertEqual(snapshot.spatialConsequences.samples.first?.coordinate, GridCoordinate(x: 0, y: 0))
        XCTAssertEqual(snapshot.spatialConsequences.samples.last?.coordinate, GridCoordinate(x: 23, y: 23))
        XCTAssertEqual(
            snapshot.spatialConsequences[GridCoordinate(x: 10, y: 11)],
            snapshot.spatialConsequences.samples[11 * 24 + 10]
        )
        XCTAssertNil(snapshot.spatialConsequences[GridCoordinate(x: -1, y: 0)])
        XCTAssertNil(snapshot.spatialConsequences[GridCoordinate(x: 24, y: 0)])

        state.powerCapacity = 0
        state.updateTile(at: GridCoordinate(x: 10, y: 11)) { $0.condition = 0 }
        XCTAssertNotEqual(
            try CityPresentationSnapshot(state: state).spatialConsequences,
            snapshot.spatialConsequences
        )
    }

    func testDiagnosticChannelsAreOptionalBoundedRepeatableAndRowMajor() throws {
        var state = CityGameState.newCity(seed: 42)
        let original = state
        let first = try CityPresentationSnapshot(state: state)
        let second = try CityPresentationSnapshot(state: state)

        XCTAssertEqual(first.spatialConsequences, second.spatialConsequences)
        XCTAssertEqual(state, original)
        for (index, sample) in first.spatialConsequences.samples.enumerated() {
            XCTAssertEqual(
                sample.coordinate,
                GridCoordinate(x: index % state.gridWidth, y: index / state.gridWidth)
            )
            for value in [
                sample.landValueIndex,
                sample.localHappinessIndex,
                sample.trafficPressure,
                sample.streetActivityIndex,
                sample.placeActivityIndex
            ].compactMap({ $0 }) {
                XCTAssertTrue((0...1).contains(value), "\(sample.coordinate): \(value)")
            }
        }

        let completedDevelopmentCount = state.tiles.filter {
            $0.kind != .empty && $0.kind != .road && $0.constructionProgress >= 1
        }.count
        let roadCount = state.tiles.filter { $0.kind == .road }.count
        XCTAssertEqual(
            first.spatialConsequences.samples.compactMap(\.landValueIndex).count,
            completedDevelopmentCount
        )
        XCTAssertEqual(
            first.spatialConsequences.samples.compactMap(\.localHappinessIndex).count,
            completedDevelopmentCount
        )
        XCTAssertEqual(
            first.spatialConsequences.samples.compactMap(\.trafficPressure).count,
            roadCount
        )
        XCTAssertEqual(
            first.spatialConsequences.samples.compactMap(\.streetActivityIndex).count,
            roadCount
        )
        XCTAssertEqual(
            first.spatialConsequences.samples.compactMap(\.placeActivityIndex).count,
            completedDevelopmentCount
        )

        let developed = try XCTUnwrap(
            first.spatialConsequences[GridCoordinate(x: 10, y: 11)]
        )
        XCTAssertNotNil(developed.landValueIndex)
        XCTAssertNotNil(developed.localHappinessIndex)
        XCTAssertNil(developed.trafficPressure)
        XCTAssertNil(developed.streetActivityIndex)
        XCTAssertNotNil(developed.placeActivityIndex)

        let road = try XCTUnwrap(
            first.spatialConsequences[GridCoordinate(x: 10, y: 12)]
        )
        XCTAssertNil(road.landValueIndex)
        XCTAssertNil(road.localHappinessIndex)
        XCTAssertNotNil(road.trafficPressure)
        XCTAssertNotNil(road.streetActivityIndex)
        XCTAssertNil(road.placeActivityIndex)

        let empty = try XCTUnwrap(
            first.spatialConsequences[GridCoordinate(x: 0, y: 0)]
        )
        XCTAssertNil(empty.landValueIndex)
        XCTAssertNil(empty.localHappinessIndex)
        XCTAssertNil(empty.trafficPressure)
        XCTAssertNil(empty.streetActivityIndex)
        XCTAssertNil(empty.placeActivityIndex)

        state.updateTile(at: GridCoordinate(x: 10, y: 11)) {
            $0.constructionProgress = 0.75
        }
        let incomplete = try XCTUnwrap(
            CityPresentationSnapshot(state: state)
                .spatialConsequences[GridCoordinate(x: 10, y: 11)]
        )
        XCTAssertNil(incomplete.landValueIndex)
        XCTAssertNil(incomplete.localHappinessIndex)
        XCTAssertNil(incomplete.trafficPressure)
        XCTAssertNil(incomplete.streetActivityIndex)
        XCTAssertNil(incomplete.placeActivityIndex)

        var extreme = state
        extreme.happiness = 10_000
        extreme.demand.commercial = 100
        extreme.demand.industrial = 100
        extreme.updateTile(at: GridCoordinate(x: 10, y: 11)) {
            $0.constructionProgress = 1
            $0.condition = 100
            $0.occupancy = Int.max
        }
        for coordinate in [
            GridCoordinate(x: 10, y: 11),
            GridCoordinate(x: 10, y: 12)
        ] {
            let sample = try diagnosticSample(in: extreme, at: coordinate)
            for value in [
                sample.landValueIndex,
                sample.localHappinessIndex,
                sample.trafficPressure,
                sample.streetActivityIndex,
                sample.placeActivityIndex
            ].compactMap({ $0 }) {
                XCTAssertTrue((0...1).contains(value), "\(coordinate): \(value)")
            }
        }
    }

    func testLandValueAndLocalHappinessAreLocallyMonotonic() throws {
        let coordinate = GridCoordinate(x: 10, y: 11)
        let base = CityGameState.newCity(seed: 42)

        var poorCondition = base
        poorCondition.updateTile(at: coordinate) { $0.condition = 0 }
        var soundCondition = poorCondition
        soundCondition.updateTile(at: coordinate) { $0.condition = 1 }
        try assertDiagnosticIncrease(
            from: poorCondition,
            to: soundCondition,
            at: coordinate,
            landValue: true,
            localHappiness: true
        )

        var unserved = base
        unserved.updateTile(at: GridCoordinate(x: 13, y: 13)) { $0.kind = .empty }
        unserved.updateTile(at: GridCoordinate(x: 15, y: 13)) { $0.kind = .empty }
        try assertDiagnosticIncrease(
            from: unserved,
            to: base,
            at: coordinate,
            landValue: true,
            localHappiness: true
        )

        var clean = base
        clean.updateTile(at: GridCoordinate(x: 14, y: 11)) { $0.kind = .empty }
        try assertDiagnosticIncrease(
            from: base,
            to: clean,
            at: coordinate,
            landValue: true,
            localHappiness: true
        )

        var withoutPark = base
        withoutPark.updateTile(at: GridCoordinate(x: 11, y: 13)) { $0.kind = .empty }
        var withNearbyPark = withoutPark
        withNearbyPark.updateTile(at: GridCoordinate(x: 10, y: 10)) {
            $0.kind = .park
        }
        try assertDiagnosticIncrease(
            from: withoutPark,
            to: withNearbyPark,
            at: coordinate,
            landValue: true,
            localHappiness: true
        )

        var withoutRoadAccess = base
        withoutRoadAccess.updateTile(at: GridCoordinate(x: 10, y: 12)) {
            $0.kind = .empty
        }
        try assertDiagnosticIncrease(
            from: withoutRoadAccess,
            to: base,
            at: coordinate,
            landValue: true,
            localHappiness: false
        )

        var unhappy = base
        unhappy.happiness = 0
        var happy = base
        happy.happiness = 100
        let unhappySample = try diagnosticSample(in: unhappy, at: coordinate)
        let happySample = try diagnosticSample(in: happy, at: coordinate)
        XCTAssertGreaterThan(
            try XCTUnwrap(happySample.localHappinessIndex),
            try XCTUnwrap(unhappySample.localHappinessIndex)
        )
        XCTAssertEqual(happySample.landValueIndex, unhappySample.landValueIndex)
    }

    func testTrafficPressureIsRoadOnlyAndMonotonicForTopologyOccupancyAndDemand() throws {
        let coordinate = GridCoordinate(x: 10, y: 10)
        var sparse = CityGameState.newCity(seed: 42)
        for index in sparse.tiles.indices {
            sparse.tiles[index] = CityTile(
                coordinate: sparse.tiles[index].coordinate,
                kind: .empty
            )
        }
        sparse.updateTile(at: coordinate) { $0.kind = .road }

        let sparseSample = try diagnosticSample(in: sparse, at: coordinate)
        XCTAssertEqual(try XCTUnwrap(sparseSample.trafficPressure), 0)
        XCTAssertNil(sparseSample.landValueIndex)
        XCTAssertNil(sparseSample.localHappinessIndex)

        var connected = sparse
        connected.updateTile(at: GridCoordinate(x: 10, y: 9)) { $0.kind = .road }
        XCTAssertGreaterThan(
            try XCTUnwrap(
                diagnosticSample(in: connected, at: coordinate).trafficPressure
            ),
            try XCTUnwrap(sparseSample.trafficPressure)
        )

        var occupied = sparse
        occupied.updateTile(at: GridCoordinate(x: 11, y: 10)) {
            $0.kind = .residential
            $0.occupancy = 280
        }
        XCTAssertGreaterThan(
            try XCTUnwrap(
                diagnosticSample(in: occupied, at: coordinate).trafficPressure
            ),
            try XCTUnwrap(sparseSample.trafficPressure)
        )

        var lowJobDemand = sparse
        lowJobDemand.demand.commercial = 0
        lowJobDemand.updateTile(at: GridCoordinate(x: 10, y: 12)) {
            $0.kind = .commercial
            $0.occupancy = CitySimulation.commercialJobCapacity
        }
        var highJobDemand = lowJobDemand
        highJobDemand.demand.commercial = 1
        XCTAssertGreaterThan(
            try XCTUnwrap(
                diagnosticSample(in: highJobDemand, at: coordinate).trafficPressure
            ),
            try XCTUnwrap(
                diagnosticSample(in: lowJobDemand, at: coordinate).trafficPressure
            )
        )

        var incomplete = occupied
        incomplete.updateTile(at: GridCoordinate(x: 11, y: 10)) {
            $0.constructionProgress = 0.75
        }
        XCTAssertEqual(
            try XCTUnwrap(
                diagnosticSample(in: incomplete, at: coordinate).trafficPressure
            ),
            try XCTUnwrap(sparseSample.trafficPressure)
        )
        XCTAssertNil(
            try diagnosticSample(
                in: occupied,
                at: GridCoordinate(x: 11, y: 10)
            ).trafficPressure
        )
    }

    func testLocalActivityApplicabilityCoversEveryTileFamilyAndMakesZeroExplicit() throws {
        let coordinate = GridCoordinate(x: 10, y: 10)

        for kind in BuildingKind.allCases {
            var state = emptyState()
            state.updateTile(at: coordinate) {
                $0.kind = kind
                $0.constructionProgress = 1
            }
            let sample = try diagnosticSample(in: state, at: coordinate)

            switch kind {
            case .empty:
                XCTAssertNil(sample.streetActivityIndex, kind.rawValue)
                XCTAssertNil(sample.placeActivityIndex, kind.rawValue)
            case .road:
                XCTAssertEqual(try XCTUnwrap(sample.streetActivityIndex), 0, kind.rawValue)
                XCTAssertNil(sample.placeActivityIndex, kind.rawValue)
            case .residential, .commercial, .industrial, .park, .powerPlant,
                 .waterTower, .fireStation, .policeStation, .school, .cityHall:
                XCTAssertNil(sample.streetActivityIndex, kind.rawValue)
                XCTAssertNotNil(sample.placeActivityIndex, kind.rawValue)
            }

            if ![BuildingKind.empty, .road].contains(kind) {
                state.updateTile(at: coordinate) { $0.constructionProgress = 0.75 }
                let incomplete = try diagnosticSample(in: state, at: coordinate)
                XCTAssertNil(incomplete.streetActivityIndex, kind.rawValue)
                XCTAssertNil(incomplete.placeActivityIndex, kind.rawValue)
            }
        }
    }

    func testLocalActivityIsMonotonicForConnectionOccupancyConditionServiceAndRecovery() throws {
        let place = GridCoordinate(x: 10, y: 10)
        let street = GridCoordinate(x: 10, y: 11)

        var disconnected = emptyState()
        disconnected.updateTile(at: place) {
            $0.kind = .residential
            $0.occupancy = 0
        }
        var connected = disconnected
        connected.updateTile(at: street) { $0.kind = .road }
        XCTAssertGreaterThan(
            try XCTUnwrap(diagnosticSample(in: connected, at: place).placeActivityIndex),
            try XCTUnwrap(diagnosticSample(in: disconnected, at: place).placeActivityIndex)
        )

        var unoccupied = connected
        unoccupied.updateTile(at: place) { $0.occupancy = 0 }
        var occupied = unoccupied
        occupied.updateTile(at: place) { $0.occupancy = 280 }
        try assertActivityIncrease(
            from: unoccupied,
            to: occupied,
            place: place,
            street: street
        )

        var poorCondition = occupied
        poorCondition.updateTile(at: place) { $0.condition = 0 }
        var soundCondition = poorCondition
        soundCondition.updateTile(at: place) { $0.condition = 1 }
        try assertActivityIncrease(
            from: poorCondition,
            to: soundCondition,
            place: place,
            street: street
        )

        let unserved = soundCondition
        var served = unserved
        served.updateTile(at: GridCoordinate(x: 13, y: 13)) {
            $0.kind = .powerPlant
        }
        served.updateTile(at: GridCoordinate(x: 15, y: 13)) {
            $0.kind = .waterTower
        }
        try assertActivityIncrease(
            from: unserved,
            to: served,
            place: place,
            street: street
        )

        var failed = served
        failed.happiness = 0
        failed.powerCapacity = 0
        failed.waterCapacity = 0
        failed.updateTile(at: place) {
            $0.condition = 0
            $0.occupancy = 0
        }
        var recovered = failed
        recovered.happiness = 100
        recovered.powerCapacity = 300
        recovered.waterCapacity = 270
        recovered.updateTile(at: place) {
            $0.condition = 1
            $0.occupancy = 280
        }
        try assertActivityIncrease(
            from: failed,
            to: recovered,
            place: place,
            street: street
        )
    }

    func testStoryFixturesFreezeDiagnosticChannelIdentityWithoutChangingStateFingerprints() throws {
        let corpus = try ProductionStoryFixtureCorpus.build()
        let expectedDiagnosticDigests = [
            "commercial-opening-v3":
                "1d68a4218943f8f8bf1e4959d2731994e88a5adcc3466a66d01cc04255798e98",
            "commercial-complication-v3":
                "e848cf922e762e03a53abbf8b42c4f83f5f6f83ddc2d43f4885e068dbe78a76b",
            "commercial-recovery-v3":
                "0091590c1554125160ea04e784b688af1fe1fdf7051c638f0cf2be18bf8770b6",
            "commercial-charter-midpoint-v3":
                "6226d9037cbc8aee871b408b92440217b4b415f201b9bb4835a79471f05295b9",
            "commercial-tax-relief-regional-capital-v3":
                "38f759fbf0b04b67b9b07261d7c09f1dc22c8b5ed73fb21ea914274190d63850",
            "commercial-public-realm-regional-capital-v3":
                "9eb0e73c1474f7182a8caa5c16d4f552970a14572292db06ac0df7add4e6b63f",
            "commercial-charter-victory-v1":
                "5806de89dc766fe4041c05e3e720e8af3931f088f3098717e38c21d192f36c33",
            "industrial-opening-v3":
                "ad825abf41405fb2864ae5bb800ceebdf6eb9560fca0f820582504940837a9c3",
            "industrial-complication-v3":
                "4877a909eadfaefa862631adee0d1f4ed38073121db01e6bdc643a6a0c5622ef",
            "industrial-recovery-v3":
                "dda222e3c3d14e724f4cc841f4a414a45365141f967c58802455f69de9431414",
            "industrial-charter-midpoint-v3":
                "258276ebb3343f46bee74a72444edc662f764d0a1e7b9432502cf7b02c302893",
            "industrial-utility-expansion-regional-capital-v3":
                "450f6caef57cf3501ebfa863c9aa418eeacafc6eb86be5df2aa6e45ef3846354",
            "industrial-green-buffer-regional-capital-v3":
                "8bb17688dcc1c61d904db131200988001bfb1252d9ebd97aa23e2d9893398194",
            "industrial-charter-victory-v1":
                "dd590d6fe6ffa8f949dba2988c4605917f85650532bd5838bb286f3b7d98ab9c",
        ]
        let expectedActivityDigests = [
            "commercial-opening-v3":
                "7aabdf91130f15a63faad21b107944a263fff00060fb74120a2d530fb1ae8dba",
            "commercial-complication-v3":
                "22c7346580424e8d09682f7b3b0264606ac2c743869c95a612a53a9df550710e",
            "commercial-recovery-v3":
                "5cccefea9b9a8235baa0f7c92a8ee1c6fe28ae9afa056142bd5112e9c6070651",
            "commercial-charter-midpoint-v3":
                "783cc75ae88f7dbac769390baaa861cbb6757e499c7aea1b58c8d7dc2620ed80",
            "commercial-tax-relief-regional-capital-v3":
                "97277a2a9cbd23c1c6eccaa37c63b862ffc3d949db9bed5e447070ae5fd7b0bc",
            "commercial-public-realm-regional-capital-v3":
                "4b55fe14a985fbae26a350367247a302ece0e97df04e80bbe99e8a139b863611",
            "commercial-charter-victory-v1":
                "a57786ae493774b289dfe51d9fbbf65b632ef24bad8dc4c193dff35653e15319",
            "industrial-opening-v3":
                "3cec89d4698e4f986f5ad1a49de7575170ada9175a9eb04172d4c2169b71e1ca",
            "industrial-complication-v3":
                "5bad93ab73998e6c7345627d50f874912cd7b205a101407aff0e92b2c226aff7",
            "industrial-recovery-v3":
                "3596b6a54bbe57fe0d2c61ad8923477ada7206dd0dea0ebca897a81c063d1614",
            "industrial-charter-midpoint-v3":
                "1f274175e2c169b0109d6742b4b7be2928ec127ca84fc12e7b7c1a8ff014adc1",
            "industrial-utility-expansion-regional-capital-v3":
                "84ae4028741a29f28fb85d2eeb2274812450575cb2ec4542616c3db25a07a9b1",
            "industrial-green-buffer-regional-capital-v3":
                "996fc4156139cf1422b59d98708de32d00d4174ac4007a106d4d8715873bdc4e",
            "industrial-charter-victory-v1":
                "7a9373a5ef1506c1d3ba85e3fe05222ca89ab2d09a5a44ab5a42d9c9f13aae52",
        ]

        for artifact in corpus.artifacts {
            let first = try CityPresentationSnapshot(state: artifact.state)
            let second = try CityPresentationSnapshot(state: artifact.state)
            let diagnosticDigest = diagnosticChannelsDigest(
                first.spatialConsequences
            )
            let activityDigest = localActivityDigest(first.spatialConsequences)
            print(
                "CITYSIM_PLAY059_FIXTURE id=\(artifact.definition.id) " +
                "state=\(artifact.fingerprint.digest) diagnostics=\(diagnosticDigest) " +
                "CITYSIM_PLAY065_ACTIVITY=\(activityDigest)"
            )
            XCTAssertEqual(first.spatialConsequences, second.spatialConsequences)
            XCTAssertEqual(
                try CityStateFingerprinter.fingerprint(artifact.state),
                artifact.fingerprint,
                artifact.definition.id
            )
            XCTAssertEqual(
                diagnosticDigest,
                expectedDiagnosticDigests[artifact.definition.id],
                artifact.definition.id
            )
            XCTAssertEqual(
                activityDigest,
                expectedActivityDigests[artifact.definition.id],
                artifact.definition.id
            )
        }

        for legacy in [
            (
                id: "commercial-charter-victory-v1",
                file: "story-commercial-charter-victory-v1.json"
            ),
            (
                id: "industrial-charter-victory-v1",
                file: "story-industrial-charter-victory-v1.json"
            ),
        ] {
            let bytes = try storyFixtureData(file: legacy.file)
            try withTemporaryRoot { root in
                let service = SaveGameService(rootURL: root)
                try FileManager.default.createDirectory(
                    at: root,
                    withIntermediateDirectories: true
                )
                try bytes.write(to: service.saveURL, options: .atomic)
                let state = try service.load().state
                XCTAssertNil(state.progression?.secondAct, legacy.id)
                let snapshot = try CityPresentationSnapshot(state: state)
                XCTAssertEqual(
                    diagnosticChannelsDigest(snapshot.spatialConsequences),
                    expectedDiagnosticDigests[legacy.id],
                    legacy.id
                )
                XCTAssertEqual(
                    localActivityDigest(snapshot.spatialConsequences),
                    expectedActivityDigests[legacy.id],
                    legacy.id
                )
            }
        }
    }

    func testUtilityPublishesIndependentBandsFromFullyActiveSources() throws {
        var state = CityGameState.newCity(seed: 42)
        state.powerCapacity = 100
        state.powerUsed = 200
        state.waterCapacity = 50
        state.waterUsed = 200

        let sample = try XCTUnwrap(
            CityPresentationSnapshot(state: state).spatialConsequences[GridCoordinate(x: 12, y: 13)]
        )
        XCTAssertEqual(sample.utility.power, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(sample.utility.water, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(sample.utility.combined, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(sample.utility.powerBand, .strained)
        XCTAssertEqual(sample.utility.waterBand, .severe)
        XCTAssertEqual(sample.utility.combinedBand, .severe)

        state.updateTile(at: GridCoordinate(x: 13, y: 13)) { $0.constructionProgress = 0.75 }
        let inactiveSource = try XCTUnwrap(
            CityPresentationSnapshot(state: state).spatialConsequences[GridCoordinate(x: 13, y: 13)]
        )
        XCTAssertEqual(inactiveSource.utility.power, 0)
        XCTAssertEqual(inactiveSource.utility.powerBand, .severe)
    }

    func testPollutionExposureIsBoundedSourceDrivenAndMitigatedByActiveParks() throws {
        var withPark = CityGameState.newCity(seed: 42)
        let coordinate = GridCoordinate(x: 12, y: 13)
        var clean = withPark
        clean.updateTile(at: GridCoordinate(x: 14, y: 11)) { $0.kind = .empty }
        clean.updateTile(at: GridCoordinate(x: 13, y: 13)) { $0.kind = .empty }
        let cleanSnapshot = try CityPresentationSnapshot(state: clean)

        withPark.tick = 1
        let pollutedSnapshot = try CityPresentationSnapshot(state: withPark)
        let mitigated = try XCTUnwrap(
            pollutedSnapshot.spatialConsequences[coordinate]
        )

        withPark.updateTile(at: GridCoordinate(x: 11, y: 13)) { $0.kind = .empty }
        let withoutPark = try XCTUnwrap(
            CityPresentationSnapshot(state: withPark).spatialConsequences[coordinate]
        )
        let far = try XCTUnwrap(
            CityPresentationSnapshot(state: withPark).spatialConsequences[GridCoordinate(x: 0, y: 0)]
        )

        XCTAssertGreaterThan(withoutPark.pollutionExposure, mitigated.pollutionExposure)
        XCTAssertGreaterThan(withoutPark.pollutionExposure, far.pollutionExposure)
        XCTAssertTrue((0...1).contains(mitigated.pollutionExposure))
        XCTAssertEqual(withoutPark.pollutionBand, .severe)
        XCTAssertEqual(far.pollutionBand, .healthy)

        let worsening = try XCTUnwrap(pollutedSnapshot.consequenceEvents(since: cleanSnapshot).first {
            $0.coordinate == coordinate && $0.dimension == .pollution
        })
        XCTAssertEqual(worsening.direction, .worsening)
        XCTAssertEqual(worsening.fromBand, .healthy)
        XCTAssertEqual(worsening.toBand, .severe)
    }

    func testVitalityUsesOnlyActiveAuthoritativeLocationInputs() throws {
        let coordinate = GridCoordinate(x: 10, y: 11)
        var prosperous = CityGameState.newCity(seed: 42)
        prosperous.happiness = 100
        prosperous.updateTile(at: coordinate) {
            $0.condition = 1
            $0.occupancy = 280
            $0.constructionProgress = 1
        }
        let prosperousSample = try XCTUnwrap(
            CityPresentationSnapshot(state: prosperous).spatialConsequences[coordinate]
        )
        XCTAssertEqual(prosperousSample.vitality, .prosperous)
        XCTAssertTrue((0...1).contains(prosperousSample.vitalityScore))

        var strained = prosperous
        strained.happiness = 0
        strained.powerCapacity = 0
        strained.waterCapacity = 0
        strained.updateTile(at: coordinate) {
            $0.condition = 0
            $0.occupancy = 0
        }
        let strainedSample = try XCTUnwrap(
            CityPresentationSnapshot(state: strained).spatialConsequences[coordinate]
        )
        XCTAssertEqual(strainedSample.vitality, .strained)
        XCTAssertLessThan(strainedSample.vitalityScore, prosperousSample.vitalityScore)

        strained.updateTile(at: coordinate) { $0.constructionProgress = 0.75 }
        let incomplete = try XCTUnwrap(
            CityPresentationSnapshot(state: strained).spatialConsequences[coordinate]
        )
        XCTAssertEqual(incomplete.vitality, .notApplicable)
        XCTAssertEqual(incomplete.vitality.comparisonBand, nil)
    }

    func testTransitionEventsAreStableOrderedAndSuppressDiscontinuities() throws {
        var strained = CityGameState.newCity(seed: 42)
        strained.powerCapacity = 0
        strained.waterCapacity = 0
        let previous = try CityPresentationSnapshot(state: strained)

        var recovered = strained
        recovered.tick = 1
        recovered.powerCapacity = 300
        recovered.waterCapacity = 270
        let current = try CityPresentationSnapshot(state: recovered)

        let first = current.consequenceEvents(since: previous)
        let repeated = current.consequenceEvents(since: previous)
        XCTAssertEqual(first, repeated)
        XCTAssertFalse(first.isEmpty)
        XCTAssertTrue(first.allSatisfy { $0.direction == .recovery })
        XCTAssertEqual(first.map(\.id), first.map(\.id).sorted(by: eventIDOrder))
        XCTAssertTrue(first.allSatisfy {
            $0.id.hasPrefix("spatial-v1:\(current.fingerprint.version):\(current.fingerprint.digest):")
        })

        XCTAssertTrue(current.consequenceEvents(since: nil).isEmpty)
        XCTAssertTrue(current.consequenceEvents(since: current).isEmpty)

        var sameTick = recovered
        sameTick.treasury += 1
        XCTAssertTrue(
            try CityPresentationSnapshot(state: sameTick).consequenceEvents(since: current).isEmpty
        )

        var wrongDimensions = recovered
        wrongDimensions.tick = 2
        wrongDimensions.gridWidth = 12
        wrongDimensions.gridHeight = 48
        XCTAssertTrue(
            try CityPresentationSnapshot(state: wrongDimensions).consequenceEvents(since: current).isEmpty
        )
    }

    func testVitalityEventsSuppressNotApplicableEndpointsAndReportRecovery() throws {
        let coordinate = GridCoordinate(x: 10, y: 11)
        var inactive = CityGameState.newCity(seed: 42)
        inactive.updateTile(at: coordinate) { $0.constructionProgress = 0.75 }
        let inactiveSnapshot = try CityPresentationSnapshot(state: inactive)

        var active = inactive
        active.tick = 1
        active.updateTile(at: coordinate) { $0.constructionProgress = 1 }
        let activeSnapshot = try CityPresentationSnapshot(state: active)
        XCTAssertFalse(activeSnapshot.consequenceEvents(since: inactiveSnapshot).contains {
            $0.coordinate == coordinate && $0.dimension == .vitality
        })

        var strained = active
        strained.happiness = 0
        strained.powerCapacity = 0
        strained.waterCapacity = 0
        strained.updateTile(at: coordinate) {
            $0.condition = 0
            $0.occupancy = 0
        }
        let strainedSnapshot = try CityPresentationSnapshot(state: strained)

        var recovered = strained
        recovered.tick = 2
        recovered.happiness = 100
        recovered.powerCapacity = 300
        recovered.waterCapacity = 270
        recovered.updateTile(at: coordinate) {
            $0.condition = 1
            $0.occupancy = 280
        }
        let recoveredSnapshot = try CityPresentationSnapshot(state: recovered)
        let event = try XCTUnwrap(recoveredSnapshot.consequenceEvents(since: strainedSnapshot).first {
            $0.coordinate == coordinate && $0.dimension == .vitality
        })
        XCTAssertEqual(event.direction, .recovery)
        XCTAssertEqual(event.fromBand, .severe)
        XCTAssertEqual(event.toBand, .healthy)
    }

    @MainActor
    func testSaveLoadLegacyAndUndoPreserveExactDerivedTruthWithoutChangingBytes() throws {
        try withTemporaryRoot { root in
            let state = CityGameState.newCity(seed: 42)
            let canonicalBefore = try CityStateFingerprinter.canonicalData(for: state)
            let service = SaveGameService(rootURL: root)
            let write = try service.save(state)
            let saveBeforeSnapshot = try Data(contentsOf: service.saveURL)
            let before = try CityPresentationSnapshot(state: state)
            let load = try service.load()
            let after = try CityPresentationSnapshot(state: load.state)

            XCTAssertEqual(before.spatialConsequences, after.spatialConsequences)
            XCTAssertEqual(before.fingerprint, after.fingerprint)
            XCTAssertEqual(write.fingerprint, before.fingerprint)
            XCTAssertEqual(saveBeforeSnapshot, try Data(contentsOf: service.saveURL))
            XCTAssertEqual(canonicalBefore, try CityStateFingerprinter.canonicalData(for: state))

            let legacyRoot = root.appending(path: "legacy", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: legacyRoot, withIntermediateDirectories: true)
            let legacyService = SaveGameService(rootURL: legacyRoot)
            try JSONEncoder().encode(state).write(to: legacyService.saveURL, options: .atomic)
            let legacy = try legacyService.load()
            XCTAssertEqual(legacy.schemaVersion, 0)
            XCTAssertEqual(
                try CityPresentationSnapshot(state: legacy.state).spatialConsequences,
                before.spatialConsequences
            )
        }

        let store = CityGameStore(state: .newCity(seed: 42))
        let beforeState = store.state
        let before = try CityPresentationSnapshot(state: beforeState)
        store.selectTool(.residential)
        store.primaryAction(at: GridCoordinate(x: 8, y: 11))
        store.undoLastAction()
        let undoneState = store.state
        let undone = try CityPresentationSnapshot(state: undoneState)
        XCTAssertEqual(undone, before)
        XCTAssertTrue(undone.consequenceEvents(since: before).isEmpty)
    }

    func testReplayProducesExactMapsAcrossEquivalentTickGrouping() throws {
        let startingState = CityGameState.newCity(seed: 42)
        let snapshots = try SimulationSpeed.allCases.filter { $0 != .paused }.map { speed in
            var state = startingState
            var remaining = 120
            while remaining > 0 {
                let group = min(speed.ticksPerPulse, remaining)
                for _ in 0..<group { CitySimulation.step(&state) }
                remaining -= group
            }
            return try CityPresentationSnapshot(state: state)
        }

        XCTAssertEqual(snapshots[0], snapshots[1])
        XCTAssertEqual(snapshots[1], snapshots[2])
        XCTAssertEqual(snapshots[0].spatialConsequences, snapshots[2].spatialConsequences)
    }

    func testAcceptedAndDenseFixturesMeetDerivationDiffAndStorageBudgets() throws {
        let states = [
            CityGameState.newCity(seed: 42),
            strategyState(kind: .commercial),
            strategyState(kind: .industrial),
            strainedState(),
            recoveredState(),
            denseState()
        ]

        var derivationMilliseconds: [Double] = []
        var snapshotMilliseconds: [Double] = []
        for state in states {
            _ = CitySpatialConsequenceMap(state: state)
            let start = ProcessInfo.processInfo.systemUptime
            let map = CitySpatialConsequenceMap(state: state)
            derivationMilliseconds.append(elapsedMilliseconds(since: start))
            XCTAssertEqual(map.samples.count, 576)

            _ = try CityPresentationSnapshot(state: state)
            let snapshotStart = ProcessInfo.processInfo.systemUptime
            _ = try CityPresentationSnapshot(state: state)
            snapshotMilliseconds.append(elapsedMilliseconds(since: snapshotStart))
        }

        let previous = try CityPresentationSnapshot(state: strainedState())
        let current = try CityPresentationSnapshot(state: recoveredState())
        let diffStart = ProcessInfo.processInfo.systemUptime
        let events = current.consequenceEvents(since: previous)
        let diffMilliseconds = elapsedMilliseconds(since: diffStart)
        let retainedBytes = MemoryLayout<CitySpatialConsequence>.stride * 576

        XCTAssertLessThanOrEqual(derivationMilliseconds.reduce(0, +) / Double(states.count), 5)
        XCTAssertLessThanOrEqual(try XCTUnwrap(derivationMilliseconds.max()), 10)
        XCTAssertLessThanOrEqual(
            snapshotMilliseconds.reduce(0, +) / Double(states.count),
            25
        )
        XCTAssertLessThanOrEqual(try XCTUnwrap(snapshotMilliseconds.max()), 50)
        XCTAssertLessThanOrEqual(diffMilliseconds, 5)
        XCTAssertLessThanOrEqual(events.count, 1_728)
        XCTAssertLessThanOrEqual(retainedBytes, 128 * 1_024)

        let selected = GridCoordinate(x: 10, y: 11)
        let rendererInput = current.spatialConsequences[selected]
        let uiInput = current.spatialConsequences[selected]
        XCTAssertEqual(rendererInput, uiInput)

        print(
            "CITYSIM_PLAY059_SPATIAL_DIAGNOSTICS fixtures=\(states.count) " +
            "average_ms=\(metric(derivationMilliseconds.reduce(0, +) / Double(states.count))) " +
            "max_ms=\(metric(try XCTUnwrap(derivationMilliseconds.max()))) " +
            "snapshot_average_ms=\(metric(snapshotMilliseconds.reduce(0, +) / Double(states.count))) " +
            "snapshot_max_ms=\(metric(try XCTUnwrap(snapshotMilliseconds.max()))) " +
            "diff_ms=\(metric(diffMilliseconds)) events=\(events.count) " +
            "retained_sample_bytes=\(retainedBytes)"
        )
    }

    private func assertDiagnosticIncrease(
        from lowerState: CityGameState,
        to higherState: CityGameState,
        at coordinate: GridCoordinate,
        landValue: Bool,
        localHappiness: Bool
    ) throws {
        let lower = try diagnosticSample(in: lowerState, at: coordinate)
        let higher = try diagnosticSample(in: higherState, at: coordinate)
        if landValue {
            XCTAssertGreaterThan(
                try XCTUnwrap(higher.landValueIndex),
                try XCTUnwrap(lower.landValueIndex)
            )
        }
        if localHappiness {
            XCTAssertGreaterThan(
                try XCTUnwrap(higher.localHappinessIndex),
                try XCTUnwrap(lower.localHappinessIndex)
            )
        }
    }

    private func assertActivityIncrease(
        from lowerState: CityGameState,
        to higherState: CityGameState,
        place: GridCoordinate,
        street: GridCoordinate
    ) throws {
        XCTAssertGreaterThan(
            try XCTUnwrap(diagnosticSample(in: higherState, at: place).placeActivityIndex),
            try XCTUnwrap(diagnosticSample(in: lowerState, at: place).placeActivityIndex)
        )
        XCTAssertGreaterThan(
            try XCTUnwrap(diagnosticSample(in: higherState, at: street).streetActivityIndex),
            try XCTUnwrap(diagnosticSample(in: lowerState, at: street).streetActivityIndex)
        )
    }

    private func diagnosticSample(
        in state: CityGameState,
        at coordinate: GridCoordinate
    ) throws -> CitySpatialConsequence {
        try XCTUnwrap(
            CityPresentationSnapshot(state: state).spatialConsequences[coordinate]
        )
    }

    private func diagnosticChannelsDigest(
        _ map: CitySpatialConsequenceMap
    ) -> String {
        var canonical = "spatial-diagnostics-v1|\(map.width)|\(map.height)\n"
        for sample in map.samples {
            canonical += [
                String(sample.coordinate.x),
                String(sample.coordinate.y),
                optionalBitPattern(sample.landValueIndex),
                optionalBitPattern(sample.localHappinessIndex),
                optionalBitPattern(sample.trafficPressure),
            ].joined(separator: ",")
            canonical += "\n"
        }
        return SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func localActivityDigest(
        _ map: CitySpatialConsequenceMap
    ) -> String {
        var canonical = "local-activity-v1|\(map.width)|\(map.height)\n"
        for sample in map.samples {
            canonical += [
                String(sample.coordinate.x),
                String(sample.coordinate.y),
                optionalBitPattern(sample.streetActivityIndex),
                optionalBitPattern(sample.placeActivityIndex),
            ].joined(separator: ",")
            canonical += "\n"
        }
        return SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func storyFixtureData(file: String) throws -> Data {
        let name = String(file.dropLast(".json".count))
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: name,
                withExtension: "json",
                subdirectory: "Fixtures/StoryStates"
            )
        )
        return try Data(contentsOf: url)
    }

    private func optionalBitPattern(_ value: Double?) -> String {
        value.map { String($0.bitPattern) } ?? "nil"
    }

    private func eventIDOrder(_ lhs: String, _ rhs: String) -> Bool {
        func components(_ id: String) -> (Int, Int, Int) {
            let values = id.split(separator: ":")
            return (
                Int(values[3]) ?? -1,
                Int(values[4]) ?? -1,
                CitySpatialConsequenceDimension(rawValue: String(values[5]))?.order ?? -1
            )
        }
        let left = components(lhs)
        let right = components(rhs)
        if left.1 != right.1 { return left.1 < right.1 }
        if left.0 != right.0 { return left.0 < right.0 }
        return left.2 < right.2
    }

    private func strategyState(kind: BuildingKind) -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.updateTile(at: GridCoordinate(x: 8, y: 11)) {
            $0.kind = kind
            $0.occupancy = CitySimulation.jobCapacity(for: kind)
        }
        return state
    }

    private func strainedState() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.tick = 4
        state.powerCapacity = 0
        state.waterCapacity = 0
        state.happiness = 20
        state.updateTile(at: GridCoordinate(x: 10, y: 11)) {
            $0.condition = 0.2
            $0.occupancy = 0
        }
        return state
    }

    private func recoveredState() -> CityGameState {
        var state = strainedState()
        state.tick = 8
        state.powerCapacity = 300
        state.waterCapacity = 270
        state.happiness = 80
        state.updateTile(at: GridCoordinate(x: 10, y: 11)) {
            $0.condition = 1
            $0.occupancy = 280
        }
        return state
    }

    private func denseState() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        let kinds: [BuildingKind] = [
            .residential, .commercial, .industrial, .park,
            .powerPlant, .waterTower, .fireStation, .policeStation, .school
        ]
        for index in state.tiles.indices where state.tiles[index].kind == .empty {
            state.tiles[index].kind = kinds[index % kinds.count]
            state.tiles[index].level = 4
            state.tiles[index].occupancy = 180
            state.tiles[index].condition = 0.92
            state.tiles[index].constructionProgress = 1
        }
        state.population = 50_000
        state.treasury = 8_000_000
        return state
    }

    private func emptyState() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for index in state.tiles.indices {
            state.tiles[index] = CityTile(
                coordinate: state.tiles[index].coordinate,
                kind: .empty
            )
        }
        return state
    }

    private func withTemporaryRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play041-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func elapsedMilliseconds(since start: TimeInterval) -> Double {
        (ProcessInfo.processInfo.systemUptime - start) * 1_000
    }

    private func metric(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

private extension CitySpatialConsequenceDimension {
    var order: Int {
        switch self {
        case .utility: 0
        case .pollution: 1
        case .vitality: 2
        }
    }
}
