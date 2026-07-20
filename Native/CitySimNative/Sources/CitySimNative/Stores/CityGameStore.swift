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
    @Published var speed: SimulationSpeed = .normal {
        didSet {
            if speed != .paused { lastNonPausedSpeed = speed }
        }
    }
    @Published var selectedTool: BuildingKind = .road
    @Published var interactionMode: CityInteractionMode = .inspect
    @Published var selectedBuildCategory: BuildCategory = .roads
    @Published var selectedCoordinate: GridCoordinate?
    @Published var overlay: DataOverlay = .none
    @Published var showInspector = false
    @Published var showObjectives = false
    @Published var showCommandGuide = false
    @Published private(set) var commandPolicy: CityCommandPolicy
    @Published var inspectorSection: InspectorSection = .overview
    @Published var hudContextScope: HUDContextScope = .city
    @Published var lastFeedback: String?
    @Published private(set) var lastFeedbackTone: PlayerFeedbackTone = .neutral
    @Published private(set) var canUndo = false

    private let saves = SaveGameService()
    private var undoStates: [CityGameState] = []
    private var feedbackDismissal: DispatchWorkItem?
    private var lastNonPausedSpeed: SimulationSpeed = .normal

    init(
        state: CityGameState = .newCity(),
        commandPolicy: CityCommandPolicy = .enabled
    ) {
        self.state = state
        self.commandPolicy = commandPolicy
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
        let metrics = analytics
        let budgetProgress = min(1, max(0, 1 + metrics.projectedBalance / 250))
        let capacityProgress = min(
            1,
            min(
                Double(metrics.jobCapacity) / 350,
                min(Double(state.powerCapacity) / 410, Double(state.waterCapacity) / 370)
            )
        )
        let charterProgress = metrics.townCharterAwarded
            ? 1
            : Double(metrics.townCharterQualifyingCycles) / Double(CitySimulation.townCharterQualificationCycles)
        return [
            CityObjective(
                id: "stabilize",
                title: "Balance the Books",
                detail: "Restore non-negative operating cashflow",
                progress: budgetProgress,
                remaining: metrics.projectedBalance >= 0
                    ? "Operations are self-funding"
                    : "Close the \((-metrics.projectedBalance).currencyText) operating gap"
            ),
            CityObjective(
                id: "capacity",
                title: "Prepare for Growth",
                detail: "Create jobs, power, and water for 500 residents",
                progress: capacityProgress,
                remaining: capacityProgress >= 1
                    ? "Growth capacity is ready"
                    : "Need J \(max(0, 350 - metrics.jobCapacity)) · P \(max(0, 410 - state.powerCapacity)) · W \(max(0, 370 - state.waterCapacity))"
            ),
            CityObjective(
                id: "town-charter",
                title: "Earn the Town Charter",
                detail: "Sustain a balanced town for 12 consecutive days",
                progress: charterProgress,
                remaining: metrics.townCharterStatusText
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
        guard commandPolicy == .enabled else { return }
        guard speed != .paused else { return }
        for _ in 0..<speed.ticksPerPulse { CitySimulation.step(&state) }
    }

    @discardableResult
    func perform(_ command: CityCommandID) -> Bool {
        guard canPerform(command) else { return false }

        if let kind = CityCommandCatalog.buildingKind(for: command) {
            selectTool(kind)
            return true
        }
        if let category = CityCommandCatalog.buildCategory(for: command) {
            selectBuildCategory(category)
            return true
        }
        if let overlay = CityCommandCatalog.overlay(for: command) {
            self.overlay = overlay
            return true
        }
        if let section = CityCommandCatalog.inspectorSection(for: command) {
            openInspector(section)
            return true
        }

        switch command {
        case .newRegion:
            newCity()
        case .saveCity:
            save()
        case .loadCity:
            load()
        case .undo:
            undoLastAction()
        case .togglePause:
            togglePause()
        case .speedNormal:
            setSpeed(.normal)
        case .speedFast:
            setSpeed(.fast)
        case .speedFastest:
            setSpeed(.fastest)
        case .inspectMode:
            activateInspectMode()
        case .buildMode:
            activateBuildMode()
        case .bulldozeMode:
            toggleBulldozer()
        case .cancelInteraction:
            dismissTopmostSurfaceOrCancel()
        case .toggleObjectives:
            showObjectives.toggle()
        case .toggleCommandCenter:
            toggleInspector()
        case .openNotices:
            openAlertCenter()
        case .openCommandGuide:
            showCommandGuide = true
        case .dismissFeedback:
            clearFeedback()
        default:
            return false
        }
        return true
    }

    func canPerform(_ command: CityCommandID) -> Bool {
        guard commandPolicy.allows(command) else { return false }
        let descriptor = CityCommandCatalog.descriptor(for: command)
        guard descriptor.route == .store, !descriptor.isSpatial else { return false }
        return switch command {
        case .undo:
            canUndo
        case .loadCity:
            FileManager.default.fileExists(atPath: saves.saveURL.path)
        case .dismissFeedback:
            lastFeedback != nil
        case .cancelInteraction:
            showCommandGuide || showInspector || showObjectives || selectedCoordinate != nil || interactionMode != .inspect
        default:
            true
        }
    }

    func disabledReason(for command: CityCommandID) -> String? {
        guard !canPerform(command) else { return nil }
        if let policyReason = commandPolicy.disabledReason { return policyReason }
        let descriptor = CityCommandCatalog.descriptor(for: command)
        switch descriptor.route {
        case .renderer:
            return "Available when the city map has focus"
        case .system:
            return descriptor.discoverability
        case .store:
            switch command {
            case .undo: return "There is no reversible construction action"
            case .loadCity: return "No quicksave is available"
            case .dismissFeedback: return "There is no transient action message"
            case .cancelInteraction: return "There is no open surface or active tool to cancel"
            default: return "Unavailable in the current context"
            }
        }
    }

    func setSpeed(_ speed: SimulationSpeed) {
        self.speed = speed
    }

    func togglePause() {
        speed = speed == .paused ? lastNonPausedSpeed : .paused
    }

    func presentBlockingModal(_ modal: CityBlockingModal) {
        commandPolicy = .blocked(modal)
    }

    @discardableResult
    func dismissBlockingModal(_ modal: CityBlockingModal) -> Bool {
        guard commandPolicy == .blocked(modal) else { return false }
        commandPolicy = .enabled
        return true
    }

    private func dismissTopmostSurfaceOrCancel() {
        if showCommandGuide {
            showCommandGuide = false
        } else if showInspector {
            dismissInspector()
        } else if showObjectives {
            showObjectives = false
        } else {
            cancelInteraction()
        }
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
        guard commandPolicy == .enabled else { return }
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
        guard commandPolicy == .enabled else { return }
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
        case "stabilize": openInspector(.finances)
        case "capacity": openInspector(.utilities)
        case "town-charter":
            showObjectives = true
            openInspector(.overview)
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
        case "Town Charter Awarded":
            showObjectives = true
            openInspector(.overview)
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
        lastNonPausedSpeed = .normal
        selectedTool = .road
        selectedBuildCategory = .roads
        interactionMode = .inspect
        selectedCoordinate = nil
        inspectorSection = .overview
        hudContextScope = .city
        showInspector = false
        showCommandGuide = false
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
            let result = try saves.load()
            state = result.state
            speed = .paused
            lastNonPausedSpeed = .normal
            selectedTool = .road
            selectedBuildCategory = .roads
            interactionMode = .inspect
            selectedCoordinate = nil
            inspectorSection = .overview
            hudContextScope = .city
            showInspector = false
            showCommandGuide = false
            undoStates.removeAll()
            canUndo = false
            showFeedback(
                result.recoveredFromBackup
                    ? "Recovered last known-good city · Simulation paused"
                    : "City loaded · Simulation paused",
                tone: .positive
            )
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
