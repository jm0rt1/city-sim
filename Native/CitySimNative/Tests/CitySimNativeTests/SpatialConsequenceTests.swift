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
                sample.trafficExposure,
                sample.civicService?.combined,
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
            first.spatialConsequences.samples.compactMap(\.trafficExposure).count,
            completedDevelopmentCount
        )
        XCTAssertEqual(
            first.spatialConsequences.samples.compactMap(\.civicService).count,
            completedDevelopmentCount
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
        XCTAssertNotNil(developed.trafficExposure)
        XCTAssertNotNil(developed.civicService)
        XCTAssertNil(developed.streetActivityIndex)
        XCTAssertNotNil(developed.placeActivityIndex)

        let road = try XCTUnwrap(
            first.spatialConsequences[GridCoordinate(x: 10, y: 12)]
        )
        XCTAssertNil(road.landValueIndex)
        XCTAssertNil(road.localHappinessIndex)
        XCTAssertNotNil(road.trafficPressure)
        XCTAssertNil(road.trafficExposure)
        XCTAssertNil(road.civicService)
        XCTAssertNotNil(road.streetActivityIndex)
        XCTAssertNil(road.placeActivityIndex)

        let empty = try XCTUnwrap(
            first.spatialConsequences[GridCoordinate(x: 0, y: 0)]
        )
        XCTAssertNil(empty.landValueIndex)
        XCTAssertNil(empty.localHappinessIndex)
        XCTAssertNil(empty.trafficPressure)
        XCTAssertNil(empty.trafficExposure)
        XCTAssertNil(empty.civicService)
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
        XCTAssertNil(incomplete.trafficExposure)
        XCTAssertNil(incomplete.civicService)
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
                sample.trafficExposure,
                sample.civicService?.combined,
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

    func testTrafficAssignmentRequiresACompletedConnectedHomeAndWorkplace() throws {
        let road = GridCoordinate(x: 7, y: 9)
        let home = GridCoordinate(x: 4, y: 10)
        var connected = trafficRouteState()

        let connectedAnalysis = CityTrafficAnalysis(state: connected)
        let reading = try XCTUnwrap(connectedAnalysis[road])
        XCTAssertGreaterThan(reading.assignedTrips, 0)
        XCTAssertGreaterThan(reading.pressure, 0)
        XCTAssertGreaterThan(reading.delay, 0)
        XCTAssertLessThan(reading.reliability, 1)
        XCTAssertGreaterThan(
            try XCTUnwrap(connectedAnalysis.place(at: home)).exposure,
            0
        )
        XCTAssertNil(connectedAnalysis[GridCoordinate(x: 0, y: 0)])

        connected.updateTile(at: GridCoordinate(x: 7, y: 9)) { $0.kind = .empty }
        XCTAssertEqual(
            try XCTUnwrap(CityTrafficAnalysis(state: connected)[GridCoordinate(x: 6, y: 9)]).pressure,
            0
        )

        var incomplete = trafficRouteState()
        incomplete.updateTile(at: home) { $0.constructionProgress = 0.75 }
        XCTAssertEqual(
            try XCTUnwrap(CityTrafficAnalysis(state: incomplete)[road]).pressure,
            0
        )
    }

    func testNewCityAggregateOccupancySeedsReadOnlyOpeningTraffic() {
        let state = CityGameState.newCity(seed: 42)
        let original = state

        XCTAssertTrue(
            state.tiles
                .filter { $0.kind == .residential || $0.kind == .commercial || $0.kind == .industrial }
                .allSatisfy { $0.occupancy == 0 },
            "The opening city keeps aggregate population and jobs before the first per-lot simulation review"
        )

        let analysis = CityTrafficAnalysis(state: state)
        let assignedRoads = state.tiles.compactMap { tile -> CityTrafficRoadReading? in
            guard tile.kind == .road else { return nil }
            return analysis[tile.coordinate]
        }

        XCTAssertTrue(assignedRoads.contains { $0.assignedTrips > 0 })
        XCTAssertTrue(assignedRoads.contains { $0.delay > 0 })
        XCTAssertEqual(state, original, "Opening traffic must remain derived and save-neutral")
    }

    func testTrafficAssignmentRespondsToDemandAndAlternateRoadsShareLoad() throws {
        let mainRoad = GridCoordinate(x: 7, y: 9)
        let alternateRoad = GridCoordinate(x: 7, y: 11)

        var lowDemand = trafficRouteState()
        lowDemand.demand.commercial = 0
        var highDemand = lowDemand
        highDemand.demand.commercial = 1
        XCTAssertGreaterThan(
            try XCTUnwrap(CityTrafficAnalysis(state: highDemand)[mainRoad]).pressure,
            try XCTUnwrap(CityTrafficAnalysis(state: lowDemand)[mainRoad]).pressure
        )

        let singleRoute = trafficRouteState()
        let alternateRoute = trafficRouteState(includeAlternate: true)
        let singleAnalysis = CityTrafficAnalysis(state: singleRoute)
        let alternateAnalysis = CityTrafficAnalysis(state: alternateRoute)
        XCTAssertGreaterThan(
            try XCTUnwrap(alternateAnalysis[alternateRoad]).assignedTrips,
            0
        )
        XCTAssertLessThan(
            try XCTUnwrap(alternateAnalysis[mainRoad]).pressure,
            try XCTUnwrap(singleAnalysis[mainRoad]).pressure
        )

        let home = GridCoordinate(x: 4, y: 10)
        let congested = try diagnosticSample(in: singleRoute, at: home)
        let relieved = try diagnosticSample(in: alternateRoute, at: home)
        XCTAssertLessThan(
            try XCTUnwrap(relieved.trafficExposure),
            try XCTUnwrap(congested.trafficExposure)
        )
        XCTAssertGreaterThan(
            try XCTUnwrap(relieved.landValueIndex),
            try XCTUnwrap(congested.landValueIndex)
        )
        XCTAssertGreaterThan(
            try XCTUnwrap(relieved.localHappinessIndex),
            try XCTUnwrap(congested.localHappinessIndex)
        )
        XCTAssertGreaterThan(relieved.vitalityScore, congested.vitalityScore)

        var deadEnd = singleRoute
        deadEnd.updateTile(at: GridCoordinate(x: 4, y: 11)) { $0.kind = .road }
        XCTAssertEqual(
            try XCTUnwrap(
                CityTrafficAnalysis(state: deadEnd).place(at: home)
            ).exposure,
            try XCTUnwrap(singleAnalysis.place(at: home)).exposure,
            accuracy: 0.000_001,
            "An adjacent dead end must not dilute exposure without carrying any assigned trips"
        )
    }

    func testTrafficWearsUsedRoadsAndConditionReducesCapacityAndReliability() throws {
        var state = trafficRouteState(includeAlternate: true)
        state.demand.commercial = 0
        let maintained = CityTrafficAnalysis(state: state)
        let candidate = try XCTUnwrap(
            state.tiles
                .filter { $0.kind == .road }
                .compactMap { maintained[$0.coordinate] }
                .filter {
                    $0.assignedTrips > 0
                        && $0.pressure >= CityRoadMaintenance.minimumWearPressure
                        && $0.pressure < 0.95
                }
                .min { $0.pressure < $1.pressure }
        )
        let unused = state.tiles
            .filter { $0.kind == .road }
            .first {
                (maintained[$0.coordinate]?.pressure ?? 0)
                    < CityRoadMaintenance.minimumWearPressure
            }?.coordinate

        var damaged = state
        damaged.updateTile(at: candidate.coordinate) { $0.condition = 0.40 }
        let damagedReading = try XCTUnwrap(
            CityTrafficAnalysis(state: damaged)[candidate.coordinate]
        )
        XCTAssertEqual(
            damagedReading.assignedTrips,
            candidate.assignedTrips,
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(damagedReading.pressure, candidate.pressure)
        XCTAssertLessThan(damagedReading.reliability, candidate.reliability)

        let changed = CitySimulation.applyDailyRoadWear(&state)
        XCTAssertTrue(changed.contains(candidate.coordinate))
        XCTAssertLessThan(
            try XCTUnwrap(state.tile(at: candidate.coordinate)?.condition),
            1
        )
        if let unused {
            XCTAssertEqual(state.tile(at: unused)?.condition, 1)
            XCTAssertFalse(changed.contains(unused))
        }
    }

    func testResidentialCommuteAccessUsesReachableJobsRouteLengthAndReliability() throws {
        let home = GridCoordinate(x: 4, y: 10)
        let connected = trafficRouteState()
        let original = connected
        let connectedAnalysis = CityTrafficAnalysis(state: connected)
        let connectedCommute = try XCTUnwrap(connectedAnalysis.place(at: home)?.commute)

        XCTAssertEqual(connectedCommute.reachableJobs, CitySimulation.commercialJobCapacity)
        XCTAssertEqual(connectedCommute.requiredWorkers, 196)
        XCTAssertEqual(connectedCommute.routeLength, 6)
        XCTAssertGreaterThan(connectedCommute.routeReliability, 0)
        XCTAssertGreaterThan(connectedCommute.access, 0)
        XCTAssertLessThan(connectedCommute.access, CityCommuteAccessReading.healthyAccessThreshold)
        XCTAssertEqual(
            connectedAnalysis.residentWeightedCommuteAccess,
            connectedCommute.access,
            accuracy: 0.000_001
        )

        var improved = trafficRouteState(includeAlternate: true)
        improved.updateTile(at: GridCoordinate(x: 7, y: 8)) {
            $0.kind = .industrial
            $0.occupancy = CitySimulation.industrialJobCapacity
        }
        let improvedCommute = try XCTUnwrap(
            CityTrafficAnalysis(state: improved).place(at: home)?.commute
        )
        XCTAssertEqual(
            improvedCommute.reachableJobs,
            CitySimulation.commercialJobCapacity + CitySimulation.industrialJobCapacity
        )
        XCTAssertGreaterThan(improvedCommute.access, connectedCommute.access)
        XCTAssertGreaterThanOrEqual(
            improvedCommute.routeReliability,
            connectedCommute.routeReliability
        )

        var disconnected = connected
        disconnected.updateTile(at: GridCoordinate(x: 7, y: 9)) { $0.kind = .empty }
        let disconnectedAnalysis = CityTrafficAnalysis(state: disconnected)
        let disconnectedCommute = try XCTUnwrap(
            disconnectedAnalysis.place(at: home)?.commute
        )
        XCTAssertEqual(disconnectedCommute.reachableJobs, 0)
        XCTAssertNil(disconnectedCommute.routeLength)
        XCTAssertEqual(disconnectedCommute.routeReliability, 0)
        XCTAssertEqual(disconnectedCommute.access, 0)
        XCTAssertEqual(disconnectedAnalysis.residentWeightedCommuteAccess, 0)

        let connectedSample = try diagnosticSample(in: connected, at: home)
        let disconnectedSample = try diagnosticSample(in: disconnected, at: home)
        XCTAssertGreaterThan(connectedSample.vitalityScore, disconnectedSample.vitalityScore)
        XCTAssertGreaterThan(
            try XCTUnwrap(connectedSample.landValueIndex),
            try XCTUnwrap(disconnectedSample.landValueIndex)
        )
        XCTAssertGreaterThan(
            try XCTUnwrap(connectedSample.localHappinessIndex),
            try XCTUnwrap(disconnectedSample.localHappinessIndex)
        )

        let snapshot = try CityPresentationSnapshot(state: connected)
        let homeTile = try XCTUnwrap(connected.tile(at: home))
        let conditions = try XCTUnwrap(
            CitySelectedLocationConditions.make(tile: homeTile, snapshot: snapshot)
        )
        XCTAssertEqual(conditions.commuteAccess, Int((connectedCommute.access * 100).rounded()))
        XCTAssertTrue(conditions.accessibilitySummary.contains("commute access"))
        let diagnosis = try XCTUnwrap(
            CitySelectedLocationDiagnosis.make(tile: homeTile, snapshot: snapshot)
        )
        XCTAssertTrue(diagnosis.cause.contains("Commute access is strained"))
        XCTAssertTrue(diagnosis.cause.contains("80 reachable jobs for 196 workers"))
        XCTAssertTrue(diagnosis.consequence.contains("city happiness target"))
        XCTAssertTrue(diagnosis.responses.contains { $0.command == .buildRoad })
        XCTAssertTrue(diagnosis.responses.contains { $0.command == .overlayTraffic })
        XCTAssertEqual(connected, original, "Commute access must remain derived and save-neutral")
    }

    func testDailyHappinessRewardsAConnectedHomeToWorkRoute() {
        var connected = trafficRouteState()
        var disconnected = connected
        disconnected.updateTile(at: GridCoordinate(x: 7, y: 9)) { $0.kind = .empty }
        connected.happiness = 50
        disconnected.happiness = 50

        CitySimulation.step(&connected)
        CitySimulation.step(&disconnected)

        XCTAssertGreaterThan(connected.happiness, disconnected.happiness)
    }

    func testTrafficAssignmentSkipsDisconnectedNearerJobsForAReachableWorkplace() throws {
        var state = emptyState()
        state.demand.commercial = 1
        state.updateTile(at: GridCoordinate(x: 4, y: 10)) {
            $0.kind = .residential
            $0.occupancy = 280
        }
        state.updateTile(at: GridCoordinate(x: 14, y: 10)) {
            $0.kind = .commercial
            $0.occupancy = CitySimulation.commercialJobCapacity
        }
        for x in 4...14 {
            state.updateTile(at: GridCoordinate(x: x, y: 9)) { $0.kind = .road }
        }
        for x in [5, 7, 9] {
            state.updateTile(at: GridCoordinate(x: x, y: 12)) {
                $0.kind = .commercial
                $0.occupancy = CitySimulation.commercialJobCapacity
            }
            state.updateTile(at: GridCoordinate(x: x, y: 11)) { $0.kind = .road }
        }

        XCTAssertGreaterThan(
            try XCTUnwrap(
                CityTrafficAnalysis(state: state)[GridCoordinate(x: 8, y: 9)]
            ).assignedTrips,
            0
        )
    }

    func testTrafficAnalysisIsDeterministicAndDoesNotMutateSavedCityState() throws {
        let state = trafficRouteState(includeAlternate: true)
        let original = state
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(state)

        XCTAssertEqual(CityTrafficAnalysis(state: state), CityTrafficAnalysis(state: state))
        XCTAssertEqual(state, original)
        XCTAssertEqual(try encoder.encode(state), encoded)
    }

    func testTrafficDiagnosisExplainsDelayPenaltyAndAnHonestRecoveryPath() throws {
        let state = trafficRouteState()
        let snapshot = try CityPresentationSnapshot(state: state)
        let road = try XCTUnwrap(state.tile(at: GridCoordinate(x: 7, y: 9)))
        let roadDiagnosis = try XCTUnwrap(
            CitySelectedLocationDiagnosis.make(tile: road, snapshot: snapshot)
        )

        XCTAssertTrue(roadDiagnosis.cause.contains("Assigned home-to-work trips"))
        XCTAssertTrue(roadDiagnosis.cause.contains("100% pressure"))
        XCTAssertTrue(roadDiagnosis.consequence.contains("75%"))
        XCTAssertTrue(roadDiagnosis.consequence.contains("reliability"))
        XCTAssertTrue(roadDiagnosis.consequence.contains("55% pressure"))
        XCTAssertEqual(roadDiagnosis.responses.map(\.command), [.buildRoad, .overlayTraffic])

        let home = try XCTUnwrap(state.tile(at: GridCoordinate(x: 4, y: 10)))
        let homeDiagnosis = try XCTUnwrap(
            CitySelectedLocationDiagnosis.make(tile: home, snapshot: snapshot)
        )
        XCTAssertTrue(homeDiagnosis.cause.contains("Traffic exposure is congested"))
        XCTAssertTrue(homeDiagnosis.consequence.contains("12.0% local-value drag"))
        XCTAssertTrue(homeDiagnosis.responses.contains { $0.command == .buildRoad })
        XCTAssertTrue(homeDiagnosis.responses.contains { $0.command == .overlayTraffic })
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
            "commercial-opening-v5":
                "362679c053057b7cce596b2ace390d3772875a492f5bee3cd48bf1997c4773a2",
            "commercial-complication-v5":
                "26ac048aa9c5003c247cd03f70423c74fa7cf2297a7d7085758bd6c834303ce5",
            "commercial-recovery-v5":
                "79add2062d6648b5d208f01bc4847897b71166923e8f6f8938de45f0dea576d1",
            "commercial-charter-midpoint-v5":
                "48130f6b0ad13f98a527799f4f3380b5704ab0a1a3292455214668702348e4fc",
            "commercial-tax-relief-regional-capital-v5":
                "e705a7664e77ece672c9937d3b882bb8e7a29278e220b0c15f2053b8a6f428fa",
            "commercial-public-realm-regional-capital-v5":
                "eb28ee767c06b09ab83f5c53f0105ac2345025ae4e616ced0f09c426b1a24871",
            "commercial-opening-v6":
                "362679c053057b7cce596b2ace390d3772875a492f5bee3cd48bf1997c4773a2",
            "commercial-complication-v6":
                "26ac048aa9c5003c247cd03f70423c74fa7cf2297a7d7085758bd6c834303ce5",
            "commercial-recovery-v6":
                "79add2062d6648b5d208f01bc4847897b71166923e8f6f8938de45f0dea576d1",
            "commercial-charter-midpoint-v6":
                "48130f6b0ad13f98a527799f4f3380b5704ab0a1a3292455214668702348e4fc",
            "commercial-tax-relief-regional-capital-v6":
                "e705a7664e77ece672c9937d3b882bb8e7a29278e220b0c15f2053b8a6f428fa",
            "commercial-public-realm-regional-capital-v6":
                "eb28ee767c06b09ab83f5c53f0105ac2345025ae4e616ced0f09c426b1a24871",
            "commercial-opening-v7":
                "e049112556e169b95ef03a13ac623403f22732a6f98d1694bce916d1eb5349d7",
            "commercial-complication-v7":
                "4c6379cb34814e350953d26f1fab5a1d13cb7f4880eddb3e2f795f699fac7265",
            "commercial-recovery-v7":
                "fc6e783cc5ca4456822bd1a3cae8033f3951f02b9e3f899a10551f2e44667aeb",
            "commercial-charter-midpoint-v7":
                "1a324ef043cb67686bdc20964d45d483e4f84bd13e7a8679c806e49cbb9d08e1",
            "commercial-tax-relief-regional-capital-v7":
                "87fffca92c64c682cbaeb8b8c3224272722397811b1445c2ac16240da801f1c4",
            "commercial-public-realm-regional-capital-v7":
                "97ce0a6fdc924c379ad533943352807e17a4453815635a38e78e1d577e69c336",
            "commercial-charter-victory-v1":
                "d2e1150e0bc9e709a3e7d8c6253178c0546030bbb3be4b1e31afe9e17a13426e",
            "industrial-opening-v5":
                "9efd6b44acbdac26dfaf187e40f8ef3d4e9be21ea5396aeab6334e88520a1c2b",
            "industrial-complication-v5":
                "3fb13431b5082079dde08cd0b367f874632fe5564b20cdf71c1bf82b85b4c25e",
            "industrial-recovery-v5":
                "5bfd3e9463034be29f54630fe1969262369888d3b01152596fcb35c6956cece6",
            "industrial-charter-midpoint-v5":
                "f9e72e815c8670e68ec2c0619884b9e5dd0f036bd456ba0f81f3e37f6c94881b",
            "industrial-utility-expansion-regional-capital-v5":
                "3341da4c835e62cd972550cf80db515b05909038949623ea4e8c737845856bf6",
            "industrial-green-buffer-regional-capital-v5":
                "8f494ddaaad2208b132a909f2f25aa56022814910a24fb506b7bd287f35cc5df",
            "industrial-opening-v6":
                "9efd6b44acbdac26dfaf187e40f8ef3d4e9be21ea5396aeab6334e88520a1c2b",
            "industrial-complication-v6":
                "3fb13431b5082079dde08cd0b367f874632fe5564b20cdf71c1bf82b85b4c25e",
            "industrial-recovery-v6":
                "5bfd3e9463034be29f54630fe1969262369888d3b01152596fcb35c6956cece6",
            "industrial-charter-midpoint-v6":
                "f9e72e815c8670e68ec2c0619884b9e5dd0f036bd456ba0f81f3e37f6c94881b",
            "industrial-utility-expansion-regional-capital-v6":
                "3341da4c835e62cd972550cf80db515b05909038949623ea4e8c737845856bf6",
            "industrial-green-buffer-regional-capital-v6":
                "8f494ddaaad2208b132a909f2f25aa56022814910a24fb506b7bd287f35cc5df",
            "industrial-opening-v7":
                "fbcc5e8efa46b8bc2dfb6e83487e00c51a2ded03186108d503789122438db984",
            "industrial-complication-v7":
                "f41eca412bc05b000e28f733bf9a9e7d2e492e5d5d0f07e73e473d22ded687ec",
            "industrial-recovery-v7":
                "be45abe46f1ad025662a3e4d08fece4ae23c912ef88fd03f9c80f045f1d17d33",
            "industrial-charter-midpoint-v7":
                "17fe44d69fc3f7ca526b438efdf93a5905c68490b10ec87f1e1328b9950c07d0",
            "industrial-utility-expansion-regional-capital-v7":
                "62f297ac9135167d90bdcac56898589c556555f6397ab4db0a2b979f7ec81ee4",
            "industrial-green-buffer-regional-capital-v7":
                "568f32223a4255ded91b414f26b1959f878b1cac5d0d492f9de4962b831adcc0",
            "industrial-charter-victory-v1":
                "3c8fc741bf7d43c238486579a94de2c6af0d2f51f33518664a1db4ecad6d61e5",
        ]
        let expectedActivityDigests = [
            "commercial-opening-v5":
                "409980357ab76a2f07d77855f3a37fd8568f5f6269524e1eb5e61ea5f1b0886a",
            "commercial-complication-v5":
                "dd617de9d484f44480224316c1cbe6b854d26a44f0466fd84cfbabb1f5e31a5a",
            "commercial-recovery-v5":
                "9033aca3cf076c09b724667a227f323cf1a5c411e160cfe159de9a815e05cbad",
            "commercial-charter-midpoint-v5":
                "63aaba2f0c740e8893b321e2ec1128d2fff95ead7dba5e3d6e64cc0310629174",
            "commercial-tax-relief-regional-capital-v5":
                "110f56a2bc57c186ea54886a0708136ea45203295305b65dc4c81ef146378b7e",
            "commercial-public-realm-regional-capital-v5":
                "9dca836441b4027b0a4acc5b405232197026cd48a885f8379abe61ab21319522",
            "commercial-opening-v6":
                "409980357ab76a2f07d77855f3a37fd8568f5f6269524e1eb5e61ea5f1b0886a",
            "commercial-complication-v6":
                "dd617de9d484f44480224316c1cbe6b854d26a44f0466fd84cfbabb1f5e31a5a",
            "commercial-recovery-v6":
                "9033aca3cf076c09b724667a227f323cf1a5c411e160cfe159de9a815e05cbad",
            "commercial-charter-midpoint-v6":
                "63aaba2f0c740e8893b321e2ec1128d2fff95ead7dba5e3d6e64cc0310629174",
            "commercial-tax-relief-regional-capital-v6":
                "110f56a2bc57c186ea54886a0708136ea45203295305b65dc4c81ef146378b7e",
            "commercial-public-realm-regional-capital-v6":
                "9dca836441b4027b0a4acc5b405232197026cd48a885f8379abe61ab21319522",
            "commercial-opening-v7":
                "3c556b95a81925e008f80e9e88dc464c9f119f9d52011daedad34ef2a15de81d",
            "commercial-complication-v7":
                "a1ae4b3ba1446c09c8305d57b3a5d79c2e6a57e7cd26fe41600f905a48baef1a",
            "commercial-recovery-v7":
                "fad24bca93788b11f2d6dd7b06256128162c3daaa3c9ac76f83373b0e6539b4b",
            "commercial-charter-midpoint-v7":
                "c94b93a153056bcac06f73ac706d6110c13e7a99a646447db02acaf7c87ee235",
            "commercial-tax-relief-regional-capital-v7":
                "b9866575c0c1bf58546afdb0a455e60a953763b633e13cbb58bbb295f886b9d3",
            "commercial-public-realm-regional-capital-v7":
                "dce7745eed02637ce52820a3f79f4c900e895aba0b06a753824c1140cca7cf13",
            "commercial-charter-victory-v1":
                "a150bb0b748290c9c7ec246590a61c96ddea8a716526bb70c891897e3cd3cbd8",
            "industrial-opening-v5":
                "3a44bdda20d8e169e6190d56b2f6897ea1c6cfd139b1ccbc80aa6b2e0bf8a209",
            "industrial-complication-v5":
                "be62fcfe3e1d162e839f6cf753c11dec6585cdf09b48bb0c3303baea8e296d4e",
            "industrial-recovery-v5":
                "a7a1f04cfe4cf1d19b48cadf841209fa25a2bcb899cecddb93e503bef564eb6e",
            "industrial-charter-midpoint-v5":
                "d32f3366be475676bf105d74df410a648832758f283693a88cfbdb05814f1e2c",
            "industrial-utility-expansion-regional-capital-v5":
                "ce296786e056ca1c1ed402c44ba30e0b91cc851559b65ee712abd7dfb5f3f2d1",
            "industrial-green-buffer-regional-capital-v5":
                "f1095e39c0bec2a6188a1e46b91646e778abf29a68175681da00962926189d42",
            "industrial-opening-v6":
                "3a44bdda20d8e169e6190d56b2f6897ea1c6cfd139b1ccbc80aa6b2e0bf8a209",
            "industrial-complication-v6":
                "be62fcfe3e1d162e839f6cf753c11dec6585cdf09b48bb0c3303baea8e296d4e",
            "industrial-recovery-v6":
                "a7a1f04cfe4cf1d19b48cadf841209fa25a2bcb899cecddb93e503bef564eb6e",
            "industrial-charter-midpoint-v6":
                "d32f3366be475676bf105d74df410a648832758f283693a88cfbdb05814f1e2c",
            "industrial-utility-expansion-regional-capital-v6":
                "ce296786e056ca1c1ed402c44ba30e0b91cc851559b65ee712abd7dfb5f3f2d1",
            "industrial-green-buffer-regional-capital-v6":
                "f1095e39c0bec2a6188a1e46b91646e778abf29a68175681da00962926189d42",
            "industrial-opening-v7":
                "98b67c446c09ef073c6d219df086cce2b1edbb545122096fa36b7bc0bbbab5a1",
            "industrial-complication-v7":
                "d2bc07e4b3cde1c6bf77b05acee1276a783bf80ae67d83ccc0fb569a928ee011",
            "industrial-recovery-v7":
                "b23dc2c70acf0d8ccca49156391df529b3ec21322e5a0742a3ce99d3b4cf3eee",
            "industrial-charter-midpoint-v7":
                "a97a06966e98d4ffa12fdb74bc7d75c2407d0c3033e685ef80fb14539c5253bc",
            "industrial-utility-expansion-regional-capital-v7":
                "f5b13ce67f0343635f1f20727e7845f0ee69eca522aaac894c4a0eec2908381c",
            "industrial-green-buffer-regional-capital-v7":
                "7cd4f9ac2e5c7a6cf3e13c5a37db6c1f057d8c329d5fbd178238fadc2e8e2bda",
            "industrial-charter-victory-v1":
                "0cd370d11d8173139b0a52d247069dea21fef06c3b5c7ed586ca0ada463961f3",
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
        var canonical = "spatial-diagnostics-v2|\(map.width)|\(map.height)\n"
        for sample in map.samples {
            canonical += [
                String(sample.coordinate.x),
                String(sample.coordinate.y),
                optionalBitPattern(sample.landValueIndex),
                optionalBitPattern(sample.localHappinessIndex),
                optionalBitPattern(sample.trafficPressure),
                optionalBitPattern(sample.trafficExposure),
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

    private func trafficRouteState(includeAlternate: Bool = false) -> CityGameState {
        var state = emptyState()
        state.demand.commercial = 1
        state.updateTile(at: GridCoordinate(x: 4, y: 10)) {
            $0.kind = .residential
            $0.occupancy = 280
        }
        state.updateTile(at: GridCoordinate(x: 10, y: 10)) {
            $0.kind = .commercial
            $0.occupancy = CitySimulation.commercialJobCapacity
        }
        for x in 4...10 {
            state.updateTile(at: GridCoordinate(x: x, y: 9)) { $0.kind = .road }
            if includeAlternate {
                state.updateTile(at: GridCoordinate(x: x, y: 11)) { $0.kind = .road }
            }
        }
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
