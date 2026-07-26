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
            "commercial-opening-v4":
                "362679c053057b7cce596b2ace390d3772875a492f5bee3cd48bf1997c4773a2",
            "commercial-complication-v4":
                "26ac048aa9c5003c247cd03f70423c74fa7cf2297a7d7085758bd6c834303ce5",
            "commercial-recovery-v4":
                "79add2062d6648b5d208f01bc4847897b71166923e8f6f8938de45f0dea576d1",
            "commercial-charter-midpoint-v4":
                "a688688cccc66f09c94c8d63024ba16982b0349adfb81942c9d974e35515dc3a",
            "commercial-tax-relief-regional-capital-v4":
                "731c99bdb65ce4b6b139686fe0c6df7288c808abf62cebc7ea7a389ef9ecef52",
            "commercial-public-realm-regional-capital-v4":
                "8536d04243be80a40cea277799e0c17f25568d5890a4d8235a76961703198260",
            "commercial-charter-victory-v1":
                "5806de89dc766fe4041c05e3e720e8af3931f088f3098717e38c21d192f36c33",
            "industrial-opening-v4":
                "9efd6b44acbdac26dfaf187e40f8ef3d4e9be21ea5396aeab6334e88520a1c2b",
            "industrial-complication-v4":
                "3fb13431b5082079dde08cd0b367f874632fe5564b20cdf71c1bf82b85b4c25e",
            "industrial-recovery-v4":
                "5bfd3e9463034be29f54630fe1969262369888d3b01152596fcb35c6956cece6",
            "industrial-charter-midpoint-v4":
                "34aba895cdb311a53e238a72e9da1526045ff1cb2aca7fa550773c8019b58316",
            "industrial-utility-expansion-regional-capital-v4":
                "19658b83e3c86279f2ec952568b523760a1ee73720146ef7f6981067daf7c82b",
            "industrial-green-buffer-regional-capital-v4":
                "6852c414c76436f6b454d95c7511c15bbdba4bfecbf780daaa8ac3400fc14470",
            "industrial-charter-victory-v1":
                "dd590d6fe6ffa8f949dba2988c4605917f85650532bd5838bb286f3b7d98ab9c",
        ]
        let expectedActivityDigests = [
            "commercial-opening-v4":
                "409980357ab76a2f07d77855f3a37fd8568f5f6269524e1eb5e61ea5f1b0886a",
            "commercial-complication-v4":
                "dd617de9d484f44480224316c1cbe6b854d26a44f0466fd84cfbabb1f5e31a5a",
            "commercial-recovery-v4":
                "9033aca3cf076c09b724667a227f323cf1a5c411e160cfe159de9a815e05cbad",
            "commercial-charter-midpoint-v4":
                "70d41f14ed16079aaa93cd0fd9ed533747dea1fe6c1e01c3e8e67a2710ad224d",
            "commercial-tax-relief-regional-capital-v4":
                "5ac5c6bcc4c2587a7b0fc5dc1c8c67d789e9706635404796ecf5f5761eeebf39",
            "commercial-public-realm-regional-capital-v4":
                "c41c9b9084ed2e0c86ba13794c0828d44bd3fb0c86cf7227599cd67cee9e64fb",
            "commercial-charter-victory-v1":
                "a57786ae493774b289dfe51d9fbbf65b632ef24bad8dc4c193dff35653e15319",
            "industrial-opening-v4":
                "3a44bdda20d8e169e6190d56b2f6897ea1c6cfd139b1ccbc80aa6b2e0bf8a209",
            "industrial-complication-v4":
                "be62fcfe3e1d162e839f6cf753c11dec6585cdf09b48bb0c3303baea8e296d4e",
            "industrial-recovery-v4":
                "a7a1f04cfe4cf1d19b48cadf841209fa25a2bcb899cecddb93e503bef564eb6e",
            "industrial-charter-midpoint-v4":
                "f0dc8c72b05cb72d4d397cffc3ffc9950dca7c12bf81994c2cb4159ce6207a19",
            "industrial-utility-expansion-regional-capital-v4":
                "a2cf23660460609063a96ecc071cb276832eb0d1edd22c711eda2adeb0134dd7",
            "industrial-green-buffer-regional-capital-v4":
                "acbe8479d368a05596aa30a89f0df4bb820a2a7b9b71a18b6ec2758a6aebe7e6",
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
        store.primaryAction(at: GridCoordinate(x: 4, y: 8))
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
        state.updateTile(at: GridCoordinate(x: 4, y: 8)) {
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
