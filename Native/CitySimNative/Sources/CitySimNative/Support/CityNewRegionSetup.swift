import Foundation

enum CityNewRegionExperience: String, CaseIterable, Identifiable, Equatable, Sendable {
    case guidedFoundations
    case authoredScenario
    case openSandbox
    case benchmark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guidedFoundations: "Guided Foundations"
        case .authoredScenario: "Harbor Recovery"
        case .openSandbox: "Open Sandbox"
        case .benchmark: "Benchmark"
        }
    }

    var symbol: String {
        switch self {
        case .guidedFoundations: "signpost.right.and.left.fill"
        case .authoredScenario: "flag.checkered.2.crossed"
        case .openSandbox: "slider.horizontal.3"
        case .benchmark: "gauge.with.dots.needle.67percent"
        }
    }

    var detail: String {
        switch self {
        case .guidedFoundations:
            "Rebuild New Arcadia through an authored two-act mayoral mandate."
        case .authoredScenario:
            "Stabilize a pressured harbor town before its 40-day deadline."
        case .openSandbox:
            "Choose your city identity, deterministic seed, and starting resources."
        case .benchmark:
            "Measure a known city workload without changing your current city."
        }
    }

    var actionTitle: String {
        switch self {
        case .guidedFoundations: "Begin Guided City"
        case .authoredScenario: "Start Scenario"
        case .openSandbox: "Create Sandbox"
        case .benchmark: "Open Benchmark"
        }
    }
}

enum CitySandboxStartingResources: String, CaseIterable, Identifiable, Equatable, Sendable {
    case lean
    case balanced
    case generous

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lean: "Lean · $20,000"
        case .balanced: "Balanced · $32,000"
        case .generous: "Generous · $60,000"
        }
    }

    var treasury: Double {
        switch self {
        case .lean: 20_000
        case .balanced: 32_000
        case .generous: 60_000
        }
    }

    var detail: String {
        switch self {
        case .lean: "Every early expansion competes with operating reserves."
        case .balanced: "The authored baseline with meaningful budget pressure."
        case .generous: "More room to experiment before cashflow becomes decisive."
        }
    }
}

enum CitySandboxEconomy: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case relaxed
    case standard
    case demanding

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relaxed: "Relaxed"
        case .standard: "Standard"
        case .demanding: "Demanding"
        }
    }

    var detail: String {
        switch self {
        case .relaxed: "15% stronger revenue and 15% lower upkeep"
        case .standard: "The authored city economy"
        case .demanding: "15% lower revenue and 15% higher upkeep"
        }
    }

    var revenueMultiplier: Double {
        switch self {
        case .relaxed: 1.15
        case .standard: 1
        case .demanding: 0.85
        }
    }

    var upkeepMultiplier: Double {
        switch self {
        case .relaxed: 0.85
        case .standard: 1
        case .demanding: 1.15
        }
    }
}

struct CitySandboxRules: Codable, Equatable, Sendable {
    var economy: CitySandboxEconomy
    var incidentsEnabled: Bool
    var unlimitedFunds: Bool

    static let standard = CitySandboxRules(
        economy: .standard,
        incidentsEnabled: true,
        unlimitedFunds: false
    )

    var summary: String {
        let incidents = incidentsEnabled ? "Incidents on" : "Incidents off"
        let funds = unlimitedFunds ? "Unlimited funds" : "Budget active"
        return "\(economy.title) economy · \(incidents) · \(funds)"
    }
}

struct CityNewRegionConfiguration: Equatable, Sendable {
    let experience: CityNewRegionExperience
    let cityName: String
    let seed: UInt64
    let startingResources: CitySandboxStartingResources
    let sandboxRules: CitySandboxRules

    init(
        experience: CityNewRegionExperience,
        cityName: String,
        seed: UInt64,
        startingResources: CitySandboxStartingResources,
        sandboxRules: CitySandboxRules = .standard
    ) {
        self.experience = experience
        self.cityName = cityName
        self.seed = seed
        self.startingResources = startingResources
        self.sandboxRules = sandboxRules
    }

    func makeState() -> CityGameState {
        if experience == .authoredScenario {
            return CityAuthoredScenarioCatalog.harborRecovery.makeState()
        }
        var state = CityGameState.newCity(seed: seed)
        state.cityName = cityName
        state.treasury = startingResources.treasury
        if experience == .openSandbox {
            state.progression = nil
            state.sandboxRules = sandboxRules
            state.messages = [
                CityMessage(
                    tick: 0,
                    severity: .information,
                    title: "Open Sandbox Ready",
                    detail: "Shape \(cityName) in any direction with \(sandboxRules.summary.lowercased()). Utilities, demand, growth, and city consequences remain active. This region uses deterministic seed \(seed), and its sandbox rules persist with the city."
                )
            ]
        }
        return state
    }
}

struct CityNewRegionDraft: Equatable, Sendable {
    var experience: CityNewRegionExperience
    var cityName: String
    var seedText: String
    var startingResources: CitySandboxStartingResources
    var sandboxEconomy: CitySandboxEconomy
    var incidentsEnabled: Bool
    var unlimitedFunds: Bool

    static func initial(seed: UInt64) -> Self {
        Self(
            experience: .guidedFoundations,
            cityName: "New Arcadia",
            seedText: String(seed),
            startingResources: .balanced,
            sandboxEconomy: .standard,
            incidentsEnabled: true,
            unlimitedFunds: false
        )
    }

    var configuration: CityNewRegionConfiguration? {
        switch experience {
        case .guidedFoundations:
            guard let seed = parsedSeed else { return nil }
            return CityNewRegionConfiguration(
                experience: experience,
                cityName: "New Arcadia",
                seed: seed,
                startingResources: .balanced
            )
        case .authoredScenario:
            let scenario = CityAuthoredScenarioCatalog.harborRecovery
            return CityNewRegionConfiguration(
                experience: experience,
                cityName: scenario.cityName,
                seed: scenario.seed,
                startingResources: .balanced
            )
        case .openSandbox:
            guard let seed = parsedSeed else { return nil }
            let cleanedName = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedName.isEmpty, cleanedName.count <= 40 else { return nil }
            return CityNewRegionConfiguration(
                experience: experience,
                cityName: cleanedName,
                seed: seed,
                startingResources: startingResources,
                sandboxRules: CitySandboxRules(
                    economy: sandboxEconomy,
                    incidentsEnabled: incidentsEnabled,
                    unlimitedFunds: unlimitedFunds
                )
            )
        case .benchmark:
            return nil
        }
    }

    var canStart: Bool { experience == .benchmark || configuration != nil }

    var validationMessage: String? {
        guard experience == .openSandbox else { return nil }
        let cleanedName = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedName.isEmpty { return "Enter a city name." }
        if cleanedName.count > 40 { return "City names can use at most 40 characters." }
        if parsedSeed == nil { return "Enter a whole-number seed from 1 to 18,446,744,073,709,551,615." }
        return nil
    }

    private var parsedSeed: UInt64? {
        let cleanedSeed = seedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let seed = UInt64(cleanedSeed), seed > 0 else { return nil }
        return seed
    }
}

struct CityNewRegionSetupPresentation: Equatable, Sendable {
    let title: String
    let detail: String
    let guidedHighlights: [String]
    let sandboxHighlights: [String]

    static let standard = CityNewRegionSetupPresentation(
        title: "Choose Your Next City",
        detail: "Choose a guided city, challenge, sandbox, or local performance benchmark.",
        guidedHighlights: [
            "Two-act Town Charter and Regional Capital journey",
            "Contextual objectives, recovery choices, and checkpoints",
            "Balanced $32,000 opening treasury",
        ],
        sandboxHighlights: [
            "Custom city name and reproducible seed",
            "Choose economic pressure and starting treasury",
            "Toggle incidents or waive all city spending",
        ]
    )
}
