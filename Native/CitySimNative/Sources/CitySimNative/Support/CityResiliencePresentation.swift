import Foundation

struct CityResiliencePresentation: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case incidentsDisabled
        case growthWatch
        case prepare
        case ready
        case recoveryBlocked
        case recovering
        case recovered
    }

    let phase: Phase
    let status: String
    let title: String
    let detail: String
    let timingLabel: String
    let exposureLabel: String
    let reserveLabel: String
    let protectionLabel: String
    let recoveryLabel: String
    let primaryResponse: CityDirectResponse

    var accessibilitySummary: String {
        "Resilience forecast. \(status). \(title). \(detail) \(timingLabel). \(exposureLabel). \(reserveLabel). \(protectionLabel). \(recoveryLabel). Next action: \(primaryResponse.title)."
    }

    static func make(analytics: CityAnalytics) -> Self {
        let state = analytics.state
        let protection = CitySimulation.stormProtection(in: state)
        let reservePercent = Int((protection.utilityReserve * 100).rounded())
        let damagePercent = Int((protection.estimatedConditionDamage * 100).rounded())
        let exposureLabel = protection.exposedResidentialLots == 1
            ? "1 completed home exposed"
            : "Up to \(protection.exposedResidentialLots) completed homes exposed"
        let reserveLabel = "Utility reserve \(reservePercent)% / 15% required"
        let protectionLabel = "\(protection.parkCount) parks · \(protection.serviceCount) emergency services · about \(damagePercent)% condition at risk"

        if state.sandboxRules?.incidentsEnabled == false {
            return Self(
                phase: .incidentsDisabled,
                status: "INCIDENTS OFF",
                title: "Storm response is disabled",
                detail: "This sandbox will not create severe storms. Utility and service standards still support ordinary growth.",
                timingLabel: "No incident reviews scheduled",
                exposureLabel: exposureLabel,
                reserveLabel: reserveLabel,
                protectionLabel: protectionLabel,
                recoveryLabel: "No storm recovery active",
                primaryResponse: .init(
                    title: "Review city overview",
                    command: .inspectorOverview,
                    explanation: "Return to the operating position for this incident-free sandbox.",
                    focusesMap: false
                )
            )
        }

        if let recovery = state.stormRecovery, recovery.disposition == .active {
            let remainingDamage = recovery.targets.reduce(0) {
                $0 + max(0, $1.remainingConditionDamage)
            }
            let averageRemaining = recovery.targets.isEmpty
                ? 0
                : remainingDamage / Double(recovery.targets.count)
            let recoveryPercent = Int((averageRemaining * 100).rounded())
            let canRepair = analytics.utilityCoverage >= 1
                && protection.utilityReserve >= CitySimulation.stormRecoveryRequiredUtilityReserve
            let response = canRepair
                ? accelerationResponse(protection: protection)
                : utilityResponse(analytics: analytics)
            return Self(
                phase: canRepair ? .recovering : .recoveryBlocked,
                status: canRepair ? "RECOVERING" : "RECOVERY BLOCKED",
                title: canRepair
                    ? "\(recovery.targets.count) homes are repairing"
                    : "Restore the 15% utility reserve",
                detail: canRepair
                    ? "Repairs advance each city day. Parks and emergency services increase the repair rate."
                    : "Storm repairs pause until both utility networks cover current use with at least 15% reserve.",
                timingLabel: "Latest storm Day \(recovery.latestEventTick / 4 + 1)",
                exposureLabel: exposureLabel,
                reserveLabel: reserveLabel,
                protectionLabel: protectionLabel,
                recoveryLabel: "\(recovery.targets.count) homes · about \(recoveryPercent)% average damage remaining",
                primaryResponse: response
            )
        }

        if state.population < 500 {
            return Self(
                phase: .growthWatch,
                status: "GROWTH WATCH",
                title: "Incident reviews begin at 500 residents",
                detail: "Prepare utility reserve and neighborhood protection before the city crosses the incident threshold.",
                timingLabel: "\((500 - state.population).formatted()) residents until watch begins",
                exposureLabel: exposureLabel,
                reserveLabel: reserveLabel,
                protectionLabel: protectionLabel,
                recoveryLabel: "No storm recovery active",
                primaryResponse: protection.utilityReserve < CitySimulation.stormRecoveryRequiredUtilityReserve
                    ? utilityResponse(analytics: analytics)
                    : .init(
                        title: "Review population",
                        command: .inspectorPopulation,
                        explanation: "Review housing headroom before growth activates incident reviews.",
                        focusesMap: false
                    )
            )
        }

        let nextReviewTick = CitySimulation.nextIncidentReviewTick(in: state)
        let nextReviewDay = nextReviewTick.map { $0 / 4 + 1 }
        let guaranteedTick = CitySimulation.firstGuaranteedStormReviewTick(in: state)
        let ready = analytics.utilityCoverage >= 1
            && protection.utilityReserve >= CitySimulation.stormRecoveryRequiredUtilityReserve
        let recovered = state.stormRecovery?.disposition == .recovered
        let timingLabel: String
        if let nextReviewDay, let guaranteedTick {
            timingLabel = "Next review Day \(nextReviewDay) · first storm by Day \(guaranteedTick / 4 + 1)"
        } else if let nextReviewDay {
            timingLabel = "Next incident review Day \(nextReviewDay)"
        } else {
            timingLabel = "Incident schedule awaiting the next city day"
        }
        return Self(
            phase: recovered ? .recovered : (ready ? .ready : .prepare),
            status: recovered ? "RECOVERY COMPLETE" : (ready ? "READY" : "PREPARE"),
            title: recovered
                ? "Neighborhood recovery is complete"
                : (ready ? "Recovery standard secured" : "Build reserve before the next review"),
            detail: recovered
                ? "The latest damaged homes cleared their recorded storm damage; future reviews remain active."
                : (ready
                    ? "Utilities can sustain storm repairs. Parks and emergency services reduce damage and accelerate recovery."
                    : "A severe storm costs $2,000, lowers happiness, and can weather up to three completed homes."),
            timingLabel: timingLabel,
            exposureLabel: exposureLabel,
            reserveLabel: reserveLabel,
            protectionLabel: protectionLabel,
            recoveryLabel: recovered ? "Latest recovery cleared" : "No storm recovery active",
            primaryResponse: ready
                ? accelerationResponse(protection: protection)
                : utilityResponse(analytics: analytics)
        )
    }

    private static func utilityResponse(analytics: CityAnalytics) -> CityDirectResponse {
        let support = CityUtilityDecisionSupport.make(analytics: analytics)
        if let response = support.response { return response }
        let kind = support.priorityKind
        return .init(
            title: kind == .waterTower ? "Build Water Tower" : "Build Power Plant",
            command: CityCommandCatalog.id(for: kind),
            explanation: "Add capacity to raise the most constrained utility above the 15% storm-recovery reserve.",
            focusesMap: true
        )
    }

    private static func accelerationResponse(
        protection: CityStormProtectionSnapshot
    ) -> CityDirectResponse {
        if protection.parkCount < 2 {
            return .init(
                title: "Build a park",
                command: .buildPark,
                explanation: "Parks reduce storm damage and accelerate daily residential repairs.",
                focusesMap: true
            )
        }
        return .init(
            title: "Build a fire station",
            command: .buildFireStation,
            explanation: "Emergency services reduce storm damage and accelerate daily residential repairs.",
            focusesMap: true
        )
    }
}
