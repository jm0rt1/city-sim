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

struct CityNewRegionConfiguration: Equatable, Sendable {
    let experience: CityNewRegionExperience
    let cityName: String
    let seed: UInt64
    let startingResources: CitySandboxStartingResources

    func makeState() -> CityGameState {
        if experience == .authoredScenario {
            return CityAuthoredScenarioCatalog.harborRecovery.makeState()
        }
        var state = CityGameState.newCity(seed: seed)
        state.cityName = cityName
        state.treasury = startingResources.treasury
        if experience == .openSandbox {
            state.messages = [
                CityMessage(
                    tick: 0,
                    severity: .information,
                    title: "Open Sandbox Ready",
                    detail: "Shape \(cityName) in any direction. The Town Charter and Regional Capital remain optional milestones, while budget, utilities, demand, and city consequences stay fully active. This region uses deterministic seed \(seed)."
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

    static func initial(seed: UInt64) -> Self {
        Self(
            experience: .guidedFoundations,
            cityName: "New Arcadia",
            seedText: String(seed),
            startingResources: .balanced
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
                startingResources: startingResources
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
            "Lean, balanced, or generous starting treasury",
            "All simulation pressures stay active; milestones are optional",
        ]
    )
}
