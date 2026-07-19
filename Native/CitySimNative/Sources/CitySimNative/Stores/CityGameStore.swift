import AppKit
import Combine
import Foundation

enum PlayerFeedbackTone: Sendable {
    case positive
    case neutral
    case caution
}

@MainActor
final class CityGameStore: ObservableObject {
    @Published var state: CityGameState
    @Published var speed: SimulationSpeed = .normal
    @Published var selectedTool: BuildingKind = .road
    @Published var interactionMode: CityInteractionMode = .inspect
    @Published var selectedBuildCategory: BuildCategory = .roads
    @Published var selectedCoordinate: GridCoordinate?
    @Published var overlay: DataOverlay = .none
    @Published var showInspector = false
    @Published var showObjectives = false
    @Published var inspectorSection: InspectorSection = .overview
    @Published var hudContextScope: HUDContextScope = .city
    @Published var lastFeedback: String?
    @Published private(set) var lastFeedbackTone: PlayerFeedbackTone = .neutral
    @Published private(set) var canUndo = false

    private let saves = SaveGameService()
    private var undoStates: [CityGameState] = []
    private var feedbackDismissal: DispatchWorkItem?

    init(state: CityGameState = .newCity()) {
        self.state = state
    }

    var selectedTile: CityTile? {
        selectedCoordinate.flatMap { state.tile(at: $0) }
    }

    var bulldozeMode: Bool {
        get { interactionMode == .bulldoze }
        set { interactionMode = newValue ? .bulldoze : .inspect }
    }

    var analytics: CityAnalytics { CityAnalytics(state: state) }

    var objectives: [CityObjective] {
        [
            CityObjective(
                id: "population",
                title: "Metropolis in the Making",
                detail: "Reach 2,500 residents",
                progress: min(1, Double(state.population) / 2_500),
                remaining: state.population >= 2_500
                    ? "Population goal reached"
                    : "\((2_500 - state.population).formatted()) residents to goal"
            ),
            CityObjective(
                id: "happiness",
                title: "A City People Love",
                detail: "Maintain 65% happiness",
                progress: min(1, state.happiness / 65),
                remaining: state.happiness >= 65
                    ? "Happiness goal reached"
                    : "\(Int(ceil(65 - state.happiness))) points to goal"
            ),
            CityObjective(
                id: "solvent",
                title: "Responsible Stewardship",
                detail: "Keep the treasury above $0",
                progress: state.treasury >= 0 ? 1 : 0,
                remaining: state.treasury >= 0
                    ? "Treasury is solvent"
                    : "\((-state.treasury).currencyText) below solvency"
            )
        ]
    }

    var primaryObjective: CityObjective {
        objectives.first(where: { !$0.completed }) ?? objectives[0]
    }

    var completedObjectiveCount: Int {
        objectives.filter(\.completed).count
    }

    var messageSummaries: [CityMessageSummary] {
        var seen = Set<String>()
        return state.messages.compactMap { message in
            let key = "\(message.severity.rawValue)-\(message.title)"
            guard seen.insert(key).inserted else { return nil }
            let count = state.messages.filter {
                $0.severity == message.severity && $0.title == message.title
            }.count
            return CityMessageSummary(message: message, count: count)
        }
    }

    var alertCount: Int { state.messages.count }

    var highestAlertSeverity: MessageSeverity? {
        state.messages.map(\.severity).max { alertPriority($0) < alertPriority($1) }
    }

    func pulse() {
        guard speed != .paused else { return }
        for _ in 0..<speed.ticksPerPulse { CitySimulation.step(&state) }
    }

    func select(_ coordinate: GridCoordinate) {
        selectedCoordinate = coordinate
        hudContextScope = .selection
        showInspector = true
    }

    func selectTool(_ kind: BuildingKind) {
        selectedTool = kind
        selectedBuildCategory = kind.buildCategory
        interactionMode = .build(kind)
        showInspector = false
        showFeedback("\(kind.title) tool selected")
    }

    func selectBuildCategory(_ category: BuildCategory) {
        selectedBuildCategory = category
        if let firstKind = category.buildingKinds.first {
            let categoryTool = category.buildingKinds.contains(selectedTool) ? selectedTool : firstKind
            selectedTool = categoryTool
            interactionMode = .build(categoryTool)
        }
        showInspector = false
    }

    func activateBuildMode() {
        interactionMode = .build(selectedTool)
        showInspector = false
        showFeedback("Build mode · \(selectedTool.title) selected")
    }

    func activateInspectMode() {
        interactionMode = .inspect
        showInspector = false
        showFeedback("Inspect mode active")
    }

    func cancelInteraction() {
        interactionMode = .inspect
        selectedCoordinate = nil
        hudContextScope = .city
        showInspector = false
        showFeedback("Action cancelled")
    }

    func toggleBulldozer() {
        if interactionMode == .bulldoze {
            interactionMode = .inspect
            showFeedback("Bulldozer deactivated · Inspect mode active")
        } else {
            interactionMode = .bulldoze
            showInspector = false
            showFeedback("Bulldozer active · Select a structure to remove it")
        }
    }

    func openInspector(_ section: InspectorSection) {
        inspectorSection = section
        hudContextScope = .city
        showInspector = true
    }

    func showSelectionContext() {
        guard selectedTile != nil else { return }
        hudContextScope = .selection
        showInspector = true
    }

    func toggleInspector() {
        if showInspector {
            showInspector = false
        } else {
            hudContextScope = selectedTile == nil ? .city : .selection
            showInspector = true
        }
    }

    func dismissInspector() {
        showInspector = false
    }

    func primaryAction(at coordinate: GridCoordinate) {
        switch interactionMode {
        case .inspect:
            select(coordinate)
        case .bulldoze:
            demolish(at: coordinate)
        case .build(let kind):
            let previousState = state
            switch CitySimulation.build(kind, at: coordinate, in: &state) {
            case .success:
                recordUndo(previousState)
                selectedCoordinate = coordinate
                showFeedback("\(kind.title) construction approved", tone: .positive)
                playSound(named: "Tink")
            case .failure(let rejection):
                showFeedback(rejection.message, tone: .caution)
                playSound(named: "Basso")
            }
        }
    }

    func secondaryAction(at coordinate: GridCoordinate) {
        interactionMode = .inspect
        selectedCoordinate = coordinate
        if state.tile(at: coordinate)?.kind != .empty {
            hudContextScope = .selection
            showInspector = true
        }
        showFeedback("Inspect mode active")
    }

    func demolishSelected() {
        guard let coordinate = selectedCoordinate else { return }
        let previousState = state
        if CitySimulation.demolish(at: coordinate, in: &state) {
            recordUndo(previousState)
            showFeedback("Structure demolished · Undo is available", tone: .positive)
            selectedCoordinate = nil
            showInspector = false
        } else {
            showFeedback("City Hall and open land cannot be demolished", tone: .caution)
        }
    }

    func demolish(at coordinate: GridCoordinate) {
        selectedCoordinate = coordinate
        demolishSelected()
    }

    func setTaxRate(_ value: Double) {
        state.taxRate = min(0.18, max(0.04, value))
    }

    func setCityName(_ value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        state.cityName = cleaned.isEmpty ? "New Arcadia" : String(cleaned.prefix(32))
    }

    func openObjective(_ objective: CityObjective) {
        switch objective.id {
        case "population": openInspector(.population)
        case "happiness":
            overlay = .happiness
            openInspector(.happiness)
        case "solvent": openInspector(.finances)
        default: openInspector(.overview)
        }
    }

    func dismissMessage(_ id: CityMessage.ID) {
        state.messages.removeAll { $0.id == id }
    }

    func dismissMessageSummary(_ summary: CityMessageSummary) {
        state.messages.removeAll {
            $0.severity == summary.message.severity && $0.title == summary.message.title
        }
    }

    func openMessage(_ message: CityMessage) {
        switch message.title {
        case "Severe Storm":
            overlay = .utilities
            openInspector(.utilities)
        case "Population Milestone":
            openInspector(.population)
        case "Neighborhood Upgraded":
            overlay = .landValue
            openInspector(.demand)
        case "State Growth Grant":
            openInspector(.finances)
        default:
            openInspector(.journal)
        }
    }

    func openAlertCenter() {
        openInspector(.journal)
    }

    func newCity() {
        state = .newCity(seed: UInt64.random(in: 1...UInt64.max))
        speed = .normal
        selectedTool = .road
        selectedBuildCategory = .roads
        interactionMode = .inspect
        selectedCoordinate = nil
        inspectorSection = .overview
        hudContextScope = .city
        showInspector = false
        undoStates.removeAll()
        canUndo = false
        showFeedback("A fresh region is ready")
    }

    func save() {
        do { try saves.save(state); showFeedback("City saved", tone: .positive); playSound(named: "Glass") }
        catch { showFeedback("Save failed: \(error.localizedDescription)", tone: .caution) }
    }

    func load() {
        do {
            state = try saves.load()
            speed = .paused
            selectedTool = .road
            selectedBuildCategory = .roads
            interactionMode = .inspect
            selectedCoordinate = nil
            inspectorSection = .overview
            hudContextScope = .city
            showInspector = false
            undoStates.removeAll()
            canUndo = false
            showFeedback("City loaded · Simulation paused", tone: .positive)
        } catch { showFeedback("No valid save was found", tone: .caution) }
    }

    func undoLastAction() {
        guard let previous = undoStates.popLast() else {
            showFeedback("Nothing to undo", tone: .caution)
            return
        }
        state = previous
        selectedCoordinate = nil
        showInspector = false
        canUndo = !undoStates.isEmpty
        showFeedback("Last construction action undone", tone: .positive)
        playSound(named: "Pop")
    }

    func clearFeedback() {
        feedbackDismissal?.cancel()
        lastFeedback = nil
    }

    private func recordUndo(_ snapshot: CityGameState) {
        undoStates.append(snapshot)
        if undoStates.count > 20 { undoStates.removeFirst() }
        canUndo = true
    }

    private func showFeedback(_ message: String, tone: PlayerFeedbackTone = .neutral) {
        feedbackDismissal?.cancel()
        lastFeedback = message
        lastFeedbackTone = tone
        let work = DispatchWorkItem { [weak self] in self?.lastFeedback = nil }
        feedbackDismissal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: work)
    }

    private func playSound(named name: String) {
        guard UserDefaults.standard.object(forKey: "soundEffects") as? Bool ?? true else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    private func alertPriority(_ severity: MessageSeverity) -> Int {
        switch severity {
        case .good: 0
        case .information: 1
        case .warning: 2
        case .critical: 3
        }
    }
}
