import Foundation

struct CityPresentationSnapshot: Equatable, Sendable {
    let state: CityGameState
    let fingerprint: CityStateFingerprint
    let spatialConsequences: CitySpatialConsequenceMap

    init(state: CityGameState) throws {
        self.state = state
        self.fingerprint = try CityStateFingerprinter.fingerprint(state)
        self.spatialConsequences = CitySpatialConsequenceMap(state: state)
    }

    var authoritativeTick: Int { state.tick }
    var analytics: CityAnalytics { CityAnalytics(state: state) }

    func consequenceEvents(
        since previous: CityPresentationSnapshot?
    ) -> [CitySpatialConsequenceEvent] {
        guard let previous,
              previous.fingerprint != fingerprint,
              previous.authoritativeTick < authoritativeTick,
              previous.spatialConsequences.width == spatialConsequences.width,
              previous.spatialConsequences.height == spatialConsequences.height,
              previous.spatialConsequences.samples.count == spatialConsequences.samples.count else {
            return []
        }

        var events: [CitySpatialConsequenceEvent] = []
        events.reserveCapacity(spatialConsequences.samples.count)

        for index in spatialConsequences.samples.indices {
            let old = previous.spatialConsequences.samples[index]
            let new = spatialConsequences.samples[index]
            guard old.coordinate == new.coordinate else { return [] }

            appendEvent(
                coordinate: new.coordinate,
                dimension: .utility,
                from: old.utility.combinedBand,
                to: new.utility.combinedBand,
                into: &events
            )
            appendEvent(
                coordinate: new.coordinate,
                dimension: .pollution,
                from: old.pollutionBand,
                to: new.pollutionBand,
                into: &events
            )
            if let oldVitality = old.vitality.comparisonBand,
               let newVitality = new.vitality.comparisonBand {
                appendEvent(
                    coordinate: new.coordinate,
                    dimension: .vitality,
                    from: oldVitality,
                    to: newVitality,
                    into: &events
                )
            }
        }
        return events
    }

    private func appendEvent(
        coordinate: GridCoordinate,
        dimension: CitySpatialConsequenceDimension,
        from oldBand: CityConsequenceBand,
        to newBand: CityConsequenceBand,
        into events: inout [CitySpatialConsequenceEvent]
    ) {
        guard oldBand != newBand else { return }
        let direction: CitySpatialConsequenceDirection = newBand.rawValue > oldBand.rawValue
            ? .recovery
            : .worsening
        let id = [
            "spatial-v1",
            String(fingerprint.version),
            fingerprint.digest,
            String(coordinate.x),
            String(coordinate.y),
            dimension.rawValue,
            String(oldBand.rawValue),
            String(newBand.rawValue)
        ].joined(separator: ":")
        events.append(CitySpatialConsequenceEvent(
            id: id,
            authoritativeTick: authoritativeTick,
            coordinate: coordinate,
            dimension: dimension,
            direction: direction,
            fromBand: oldBand,
            toBand: newBand
        ))
    }
}
