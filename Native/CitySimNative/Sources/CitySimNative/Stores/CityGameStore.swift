import AppKit
import Combine
import Foundation

@MainActor
final class CityGameStore: ObservableObject {
    @Published var state: CityGameState
    @Published var speed: SimulationSpeed = .normal
    @Published var selectedTool: BuildingKind = .road
    @Published var bulldozeMode = false
    @Published var selectedCoordinate: GridCoordinate?
    @Published var overlay: DataOverlay = .none
    @Published var showInspector = true
    @Published var showObjectives = true
    @Published var inspectorSection: InspectorSection = .overview
    @Published var lastFeedback: String?
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

    var analytics: CityAnalytics { CityAnalytics(state: state) }

    var objectives: [CityObjective] {
        [
            CityObjective(id: "population", title: "Metropolis in the Making", detail: "Reach 2,500 residents", progress: min(1, Double(state.population) / 2_500)),
            CityObjective(id: "happiness", title: "A City People Love", detail: "Maintain 65% happiness", progress: min(1, state.happiness / 65)),
            CityObjective(id: "solvent", title: "Responsible Stewardship", detail: "Keep the treasury above $0", progress: state.treasury >= 0 ? 1 : 0)
        ]
    }

    func pulse() {
        guard speed != .paused else { return }
        for _ in 0..<speed.ticksPerPulse { CitySimulation.step(&state) }
    }

    func select(_ coordinate: GridCoordinate) {
        selectedCoordinate = coordinate
        inspectorSection = .overview
        showInspector = true
    }

    func selectTool(_ kind: BuildingKind) {
        selectedTool = kind
        bulldozeMode = false
        showFeedback("\(kind.title) tool selected")
    }

    func toggleBulldozer() {
        bulldozeMode.toggle()
        showFeedback(bulldozeMode ? "Bulldozer active · Click a structure to remove it" : "Bulldozer deactivated")
    }

    func openInspector(_ section: InspectorSection) {
        selectedCoordinate = nil
        inspectorSection = section
        showInspector = true
    }

    func primaryAction(at coordinate: GridCoordinate) {
        if bulldozeMode {
            demolish(at: coordinate)
            return
        }
        if state.tile(at: coordinate)?.kind != .empty {
            select(coordinate)
            return
        }
        let previousState = state
        switch CitySimulation.build(selectedTool, at: coordinate, in: &state) {
        case .success:
            recordUndo(previousState)
            selectedCoordinate = coordinate
            showFeedback("\(selectedTool.title) construction approved")
            playSound(named: "Tink")
        case .failure(let rejection):
            showFeedback(rejection.message)
            playSound(named: "Basso")
        }
    }

    func demolishSelected() {
        guard let coordinate = selectedCoordinate else { return }
        let previousState = state
        if CitySimulation.demolish(at: coordinate, in: &state) {
            recordUndo(previousState)
            showFeedback("Structure demolished · Undo is available")
            selectedCoordinate = nil
        } else {
            showFeedback("City Hall and open land cannot be demolished")
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

    func newCity() {
        state = .newCity(seed: UInt64.random(in: 1...UInt64.max))
        speed = .normal
        selectedCoordinate = nil
        bulldozeMode = false
        inspectorSection = .overview
        undoStates.removeAll()
        canUndo = false
        showFeedback("A fresh region is ready")
    }

    func save() {
        do { try saves.save(state); showFeedback("City saved"); playSound(named: "Glass") }
        catch { showFeedback("Save failed: \(error.localizedDescription)") }
    }

    func load() {
        do {
            state = try saves.load()
            speed = .paused
            selectedCoordinate = nil
            bulldozeMode = false
            inspectorSection = .overview
            undoStates.removeAll()
            canUndo = false
            showFeedback("City loaded · Simulation paused")
        } catch { showFeedback("No valid save was found") }
    }

    func undoLastAction() {
        guard let previous = undoStates.popLast() else {
            showFeedback("Nothing to undo")
            return
        }
        state = previous
        selectedCoordinate = nil
        canUndo = !undoStates.isEmpty
        showFeedback("Last construction action undone")
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

    private func showFeedback(_ message: String) {
        feedbackDismissal?.cancel()
        lastFeedback = message
        let work = DispatchWorkItem { [weak self] in self?.lastFeedback = nil }
        feedbackDismissal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: work)
    }

    private func playSound(named name: String) {
        guard UserDefaults.standard.object(forKey: "soundEffects") as? Bool ?? true else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
