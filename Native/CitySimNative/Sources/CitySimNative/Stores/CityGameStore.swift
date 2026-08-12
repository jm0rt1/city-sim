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
    @Published var cityNameDraft: String
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
    @Published private(set) var isCityFocusModeEnabled = false
    @Published private(set) var commandPolicy: CityCommandPolicy
    @Published var inspectorSection: InspectorSection = .overview
    @Published var hudContextScope: HUDContextScope = .city
    @Published var lastFeedback: String?
    @Published private(set) var lastFeedbackTone: PlayerFeedbackTone = .neutral
    @Published private(set) var resumeBrief: CityResumeBriefPresentation?
    @Published private(set) var startupResumeOffer: CityStartupResumePresentation?
    @Published private(set) var sessionReplacementConfirmation: CitySessionReplacementConfirmationPresentation?
    @Published private(set) var canUndo = false
    @Published private(set) var mapFocusRequestGeneration: UInt = 0

    private let saves: SaveGameService
    private var undoStates: [CityGameState] = []
    private var feedbackDismissal: DispatchWorkItem?
    private var lastNonPausedSpeed: SimulationSpeed = .normal
    private var speedBeforeSessionReplacementConfirmation: SimulationSpeed?
    private var pendingSessionReplacementLoad: SaveGameLoadResult?
    private var speedBeforeStartupResumeOffer: SimulationSpeed?
    private var pendingStartupResumeLoad: SaveGameLoadResult?
    private var startupResumeOfferWasConsidered = false
    private var lastPersistedState: CityGameState?

    init(
        state: CityGameState = .newCity(),
        commandPolicy: CityCommandPolicy = .enabled,
        saveService: SaveGameService = SaveGameService(),
        startsPaused: Bool = false
    ) {
        self.state = state
        self.cityNameDraft = state.cityName
        self.commandPolicy = commandPolicy
        self.saves = saveService
        if startsPaused || state.status != .playing {
            speed = .paused
        }
    }

    var selectedTile: CityTile? {
        selectedCoordinate.flatMap { state.tile(at: $0) }
    }

    var bulldozeMode: Bool {
        get { interactionMode == .bulldoze }
        set { interactionMode = newValue ? .bulldoze : .inspect }
    }

    var analytics: CityAnalytics { CityAnalytics(state: state) }

    var persistenceStatus: CityPersistenceStatusPresentation {
        CityPersistenceStatusPresentation.make(
            current: state,
            lastPersisted: lastPersistedState
        )
    }

    var hasUnsavedProgress: Bool {
        CityTerminationConfirmationPresentation.isRequired(
            state: state,
            persistenceStatus: persistenceStatus
        )
    }

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
        if metrics.townCharterAwarded, state.progression?.secondAct != nil {
            let regionalProgress: Double = switch metrics.secondActPhase {
            case .mandate: 0.10
            case .warnedPressure: 0.25
            case .recovery: 0.45
            case .qualification:
                0.55 + 0.45 * Double(metrics.regionalCapitalQualifyingCycles)
                    / Double(CitySimulation.regionalCapitalQualificationCycles)
            case .completed: 1
            case nil: 0
            }
            return [
                CityObjective(
                    id: "town-charter",
                    title: "Town Charter Secured",
                    detail: "Permanent first-act achievement",
                    progress: 1,
                    remaining: "The Charter opened a Regional Capital mandate"
                ),
                CityObjective(
                    id: "regional-capital",
                    title: "Earn Regional Capital",
                    detail: "Survive regional pressure, recover, and sustain the strategy",
                    progress: regionalProgress,
                    remaining: metrics.regionalCapitalStatusText
                ),
            ]
        }
        var objectives = [CityObjective]()
        if let strategyObjective = metrics.strategyObjective {
            objectives.append(strategyObjective)
        }
        objectives.append(contentsOf: [
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
        ])
        return objectives
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
        for _ in 0..<speed.ticksPerPulse {
            CitySimulation.step(&state)
            if state.status != .playing {
                speed = .paused
                break
            }
        }
    }

    @discardableResult
    func perform(_ command: CityCommandID) -> Bool {
        if command == .toggleCityFocus,
           Self.shouldQuarantineCityFocusShortcut(
               firstResponder: NSApp?.keyWindow?.firstResponder,
               event: NSApp?.currentEvent
           ) {
            return false
        }
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
            if currentCityHasProgress {
                requestSessionReplacementConfirmation(for: .newRegion)
            } else {
                newCity()
            }
        case .saveCity:
            save()
        case .loadCity:
            if currentCityHasProgress {
                prepareLoadReplacementConfirmation()
            } else {
                load()
            }
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
            leaveCityFocusForPresentedSurface()
            showObjectives.toggle()
        case .toggleCommandCenter:
            toggleInspector()
        case .toggleCityFocus:
            toggleCityFocus()
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

    @discardableResult
    func performFromCommandGuide(_ command: CityCommandID) -> Bool {
        guard showCommandGuide, perform(command) else { return false }
        showCommandGuide = false
        return true
    }

    func canPerform(_ command: CityCommandID) -> Bool {
        guard commandPolicy.allows(command) else { return false }
        let descriptor = CityCommandCatalog.descriptor(for: command)
        guard descriptor.route == .store, !descriptor.isSpatial else { return false }
        if sessionReplacementConfirmation != nil {
            return command == .cancelInteraction
        }
        if state.status != .playing,
           ![CityCommandID.newRegion, .saveCity, .loadCity].contains(command) {
            return false
        }
        return switch command {
        case .undo:
            canUndo
        case .loadCity:
            saves.hasLoadCandidate
        case .dismissFeedback:
            lastFeedback != nil
        case .cancelInteraction:
            showCommandGuide || isCityFocusModeEnabled || showInspector || showObjectives
                || selectedCoordinate != nil || interactionMode != .inspect
        default:
            true
        }
    }

    func disabledReason(for command: CityCommandID) -> String? {
        guard !canPerform(command) else { return nil }
        if let policyReason = commandPolicy.disabledReason { return policyReason }
        if sessionReplacementConfirmation != nil {
            return "Choose whether to keep or replace \(state.cityName)"
        }
        let descriptor = CityCommandCatalog.descriptor(for: command)
        if descriptor.isSpatial { return "Available when the city map has focus" }
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
            default:
                return switch state.status {
                case .playing:
                    "Unavailable in the current context"
                case .won:
                    "The mayoral mandate is complete; start a new region or load a city"
                case .lost:
                    "This city session ended in crisis; start a new region or load a city"
                }
            }
        }
    }

    func canRouteMapCommand(_ command: CityCommandID) -> Bool {
        guard sessionReplacementConfirmation == nil,
              state.status == .playing,
              commandPolicy.allows(command),
              CityCommandCatalog.mapFocusedCommands.contains(command) else {
            return false
        }
        if CityCommandCatalog.mapActionCommands.contains(command) {
            return selectedCoordinate.flatMap { state.tile(at: $0) } != nil
        }
        return true
    }

    var activeMapActionTargetPresentation: CityMapActionTargetPresentation? {
        guard let coordinate = selectedCoordinate,
              let tile = state.tile(at: coordinate) else { return nil }
        return CityMapActionTargetPresentation(
            coordinate: coordinate,
            primaryAction: CityMapPrimaryActionPresentation.make(
                interactionMode: interactionMode,
                tile: tile,
                state: state
            )
        )
    }

    @discardableResult
    func acceptPointerMapActionCandidate(
        _ coordinate: GridCoordinate
    ) -> CityMapActionTargetPresentation? {
        guard commandPolicy == .enabled,
              state.status == .playing,
              state.tile(at: coordinate) != nil else { return nil }
        switch interactionMode {
        case .inspect:
            return nil
        case .build, .bulldoze:
            selectedCoordinate = coordinate
            hudContextScope = .selection
            return activeMapActionTargetPresentation
        }
    }

    func canPerformMapCommand(_ command: CityCommandID) -> Bool {
        guard canRouteMapCommand(command) else { return false }
        if command == .mapPrimaryAction {
            return activeMapActionTargetPresentation?.primaryAction.isAvailable == true
        }
        return true
    }

    @discardableResult
    func performMapCommand(_ command: CityCommandID) -> Bool {
        guard canRouteMapCommand(command) else { return false }
        switch command {
        case .mapMoveNorth:
            return moveMapSelection(dx: 0, dy: -1, distance: 1)
        case .mapMoveEast:
            return moveMapSelection(dx: 1, dy: 0, distance: 1)
        case .mapMoveSouth:
            return moveMapSelection(dx: 0, dy: 1, distance: 1)
        case .mapMoveWest:
            return moveMapSelection(dx: -1, dy: 0, distance: 1)
        case .mapMoveNorthFast:
            return moveMapSelection(dx: 0, dy: -1, distance: 5)
        case .mapMoveEastFast:
            return moveMapSelection(dx: 1, dy: 0, distance: 5)
        case .mapMoveSouthFast:
            return moveMapSelection(dx: 0, dy: 1, distance: 5)
        case .mapMoveWestFast:
            return moveMapSelection(dx: -1, dy: 0, distance: 5)
        case .mapPrimaryAction:
            return performMapAction(primary: true)
        case .mapSecondaryAction:
            return performMapAction(primary: false)
        default:
            return false
        }
    }

    @discardableResult
    func moveMapSelection(dx: Int, dy: Int, distance: Int) -> Bool {
        guard commandPolicy == .enabled, distance > 0, state.gridWidth > 0, state.gridHeight > 0 else {
            return false
        }
        let origin = selectedCoordinate ?? initialMapSelectionCoordinate()
        let coordinate = GridCoordinate(
            x: min(state.gridWidth - 1, max(0, origin.x + dx * distance)),
            y: min(state.gridHeight - 1, max(0, origin.y + dy * distance))
        )
        selectedCoordinate = coordinate
        hudContextScope = .selection
        return true
    }

    @discardableResult
    func performMapAction(primary: Bool) -> Bool {
        guard commandPolicy == .enabled,
              let coordinate = selectedCoordinate,
              state.tile(at: coordinate) != nil else { return false }
        if primary {
            if case .build(let kind) = interactionMode,
               let action = activeMapActionTargetPresentation?.primaryAction,
               !action.isAvailable,
               let reason = action.buildDecision?.disabledReason {
                publishBlockedPlacementFeedback(for: kind, reason: reason)
                return true
            }
            primaryAction(at: coordinate)
        } else {
            secondaryAction(at: coordinate)
        }
        return true
    }

    @discardableResult
    func performMapFocused(_ command: CityCommandID) -> Bool {
        let approved: Set<CityCommandID> = [
            .buildRoad, .buildResidential, .buildCommercial, .buildIndustrial, .buildPark,
            .buildPowerPlant, .buildWaterTower,
            .bulldozeMode,
            .overlayUtilities, .overlayPollution, .overlayCity
        ]
        guard approved.contains(command), perform(command) else { return false }
        if let kind = CityCommandCatalog.buildingKind(for: command) {
            targetNearestBuildableParcel(for: kind)
        }
        mapFocusRequestGeneration &+= 1
        return true
    }

    private func targetNearestBuildableParcel(for kind: BuildingKind) {
        if let selectedCoordinate,
           case .success = CitySimulation.validateBuild(kind, at: selectedCoordinate, in: state) {
            hudContextScope = .selection
            return
        }

        let origin = selectedCoordinate ?? initialMapSelectionCoordinate()
        let target = state.tiles.lazy
            .filter { tile in
                if case .success = CitySimulation.validateBuild(kind, at: tile.coordinate, in: self.state) {
                    return true
                }
                return false
            }
            .min { lhs, rhs in
                let lhsDistance = abs(lhs.coordinate.x - origin.x) + abs(lhs.coordinate.y - origin.y)
                let rhsDistance = abs(rhs.coordinate.x - origin.x) + abs(rhs.coordinate.y - origin.y)
                if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                if lhs.coordinate.y != rhs.coordinate.y { return lhs.coordinate.y < rhs.coordinate.y }
                return lhs.coordinate.x < rhs.coordinate.x
            }

        guard let target else { return }
        selectedCoordinate = target.coordinate
        hudContextScope = .selection
    }

    @discardableResult
    func performBuildRecovery(_ recovery: CityDirectResponse) -> Bool {
        if recovery.command == .buildRoad,
           case .build(let blockedKind) = interactionMode,
           blockedKind.requiresRoad,
           let blockedCoordinate = selectedCoordinate,
           case .failure(.roadAccessRequired) = CitySimulation.validateBuild(
               blockedKind,
               at: blockedCoordinate,
               in: state
           ) {
            return beginRoadAccessRecovery(
                for: blockedKind,
                blockedCoordinate: blockedCoordinate
            )
        }
        return recovery.focusesMap
            ? performMapFocused(recovery.command)
            : perform(recovery.command)
    }

    private func beginRoadAccessRecovery(
        for blockedKind: BuildingKind,
        blockedCoordinate: GridCoordinate
    ) -> Bool {
        guard let roadCoordinate = roadAccessRecoveryCoordinate(adjacentTo: blockedCoordinate) else {
            showFeedback(
                "No open road block borders \(blockedKind.title) at block "
                    + "\(blockedCoordinate.x + 1), \(blockedCoordinate.y + 1). "
                    + "\(blockedKind.title) remains selected — choose another parcel.",
                tone: .caution,
                autoDismissAfter: nil
            )
            return false
        }
        guard perform(.buildRoad) else { return false }
        selectedCoordinate = roadCoordinate
        hudContextScope = .selection
        requestMapFocus()
        showFeedback(
            "Road target block \(roadCoordinate.x + 1), \(roadCoordinate.y + 1) borders "
                + "\(blockedKind.title) block \(blockedCoordinate.x + 1), \(blockedCoordinate.y + 1). "
                + "Confirm construction or press Escape.",
            autoDismissAfter: nil
        )
        return true
    }

    private func roadAccessRecoveryCoordinate(
        adjacentTo blockedCoordinate: GridCoordinate
    ) -> GridCoordinate? {
        let roadCoordinates = state.tiles.lazy
            .filter { $0.kind == .road }
            .map(\.coordinate)
        let candidates = state.neighbors(of: blockedCoordinate).filter {
            guard $0.kind == .empty else { return false }
            if case .success = CitySimulation.validateBuild(.road, at: $0.coordinate, in: state) {
                return true
            }
            return false
        }
        return candidates.sorted { lhs, rhs in
            let lhsExtendsRoad = state.neighbors(of: lhs.coordinate).contains { $0.kind == .road }
            let rhsExtendsRoad = state.neighbors(of: rhs.coordinate).contains { $0.kind == .road }
            if lhsExtendsRoad != rhsExtendsRoad {
                return lhsExtendsRoad
            }
            let lhsDistance = roadCoordinates.map {
                abs($0.x - lhs.coordinate.x) + abs($0.y - lhs.coordinate.y)
            }.min() ?? Int.max
            let rhsDistance = roadCoordinates.map {
                abs($0.x - rhs.coordinate.x) + abs($0.y - rhs.coordinate.y)
            }.min() ?? Int.max
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            if lhs.coordinate.y != rhs.coordinate.y {
                return lhs.coordinate.y < rhs.coordinate.y
            }
            return lhs.coordinate.x < rhs.coordinate.x
        }.first?.coordinate
    }

    private func initialMapSelectionCoordinate() -> GridCoordinate {
        let active = state.tiles.filter { $0.kind != .empty && $0.constructionProgress >= 1 }
        guard !active.isEmpty else {
            return GridCoordinate(x: state.gridWidth / 2, y: state.gridHeight / 2)
        }
        let centerX = Double(active.reduce(0) { $0 + $1.coordinate.x }) / Double(active.count)
        let centerY = Double(active.reduce(0) { $0 + $1.coordinate.y }) / Double(active.count)
        return active.min {
            let lhs = abs(Double($0.coordinate.x) - centerX) + abs(Double($0.coordinate.y) - centerY)
            let rhs = abs(Double($1.coordinate.x) - centerX) + abs(Double($1.coordinate.y) - centerY)
            if lhs != rhs { return lhs < rhs }
            if $0.coordinate.y != $1.coordinate.y { return $0.coordinate.y < $1.coordinate.y }
            return $0.coordinate.x < $1.coordinate.x
        }!.coordinate
    }

    func setSpeed(_ speed: SimulationSpeed) {
        self.speed = speed
    }

    func togglePause() {
        speed = speed == .paused ? lastNonPausedSpeed : .paused
    }

    func toggleCityFocus() {
        isCityFocusModeEnabled.toggle()
        requestMapFocus()
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

    func prepareStartupResumeOffer() {
        guard !startupResumeOfferWasConsidered,
              commandPolicy == .enabled,
              state.status == .playing,
              state == .newCity(seed: state.seed) else { return }
        startupResumeOfferWasConsidered = true
        guard saves.hasLoadCandidate else { return }
        do {
            let result = try saves.load()
            speedBeforeStartupResumeOffer = speed
            speed = .paused
            pendingStartupResumeLoad = result
            startupResumeOffer = CityStartupResumePresentation.make(result)
            presentBlockingModal(.startupResume)
        } catch {
            showInvalidQuicksaveFeedback()
        }
    }

    @discardableResult
    func resumeStartupCity() -> Bool {
        guard commandPolicy == .blocked(.startupResume),
              let result = pendingStartupResumeLoad else { return false }
        startupResumeOffer = nil
        pendingStartupResumeLoad = nil
        speedBeforeStartupResumeOffer = nil
        _ = dismissBlockingModal(.startupResume)
        applyLoadedResult(result)
        requestMapFocus()
        return true
    }

    @discardableResult
    func startFreshFromStartupOffer() -> Bool {
        guard commandPolicy == .blocked(.startupResume),
              let offer = startupResumeOffer else { return false }
        let previousSpeed = speedBeforeStartupResumeOffer ?? .paused
        startupResumeOffer = nil
        pendingStartupResumeLoad = nil
        speedBeforeStartupResumeOffer = nil
        _ = dismissBlockingModal(.startupResume)
        speed = previousSpeed
        requestMapFocus()
        showFeedback(
            "\(state.cityName) kept · \(offer.checkpoint) remains available from Load City"
        )
        return true
    }

    private func dismissTopmostSurfaceOrCancel() {
        if sessionReplacementConfirmation != nil {
            cancelSessionReplacement()
        } else if showCommandGuide {
            showCommandGuide = false
            requestMapFocus()
        } else if isCityFocusModeEnabled {
            isCityFocusModeEnabled = false
            requestMapFocus()
        } else if showInspector {
            dismissInspector()
            requestMapFocus()
        } else if showObjectives {
            showObjectives = false
            requestMapFocus()
        } else {
            cancelInteraction()
        }
    }

    private func requestMapFocus() {
        mapFocusRequestGeneration &+= 1
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
        leaveCityFocusForPresentedSurface()
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
        leaveCityFocusForPresentedSurface()
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
                if kind != .road {
                    // A completed one-off place should read as success, not
                    // immediately re-evaluate the newly occupied block as an
                    // invalid second placement. Roads retain their continuous
                    // build tool; places return to an inspectable result.
                    interactionMode = .inspect
                    hudContextScope = .selection
                    showInspector = false
                }
                showFeedback("\(kind.title) construction approved", tone: .positive)
                playSound(named: "Tink")
            case .failure(let rejection):
                publishBlockedPlacementFeedback(for: kind, reason: rejection.message)
            }
        }
    }

    private func publishBlockedPlacementFeedback(for kind: BuildingKind, reason: String) {
        showFeedback(
            "\(reason) \(kind.title) remains selected — choose another block.",
            tone: .caution,
            autoDismissAfter: nil
        )
        playSound(named: "Basso")
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
        let accepted = cleaned.isEmpty ? "New Arcadia" : String(cleaned.prefix(32))
        state.cityName = accepted
        cityNameDraft = accepted
    }

    func updateCityNameDraft(_ value: String) {
        cityNameDraft = String(value.prefix(32))
    }

    func commitCityNameDraft() {
        setCityName(cityNameDraft)
    }

    func openObjective(_ objective: CityObjective) {
        switch objective.id {
        case "stabilize": openInspector(.finances)
        case "capacity": openInspector(.utilities)
        case "town-charter":
            showObjectives = true
            let support = CityTownCharterDecisionSupport.make(analytics: analytics)
            let diagnosis = support.secondaryResponses.first ?? support.primaryResponse
            if diagnosis.focusesMap {
                openInspector(.overview)
            } else {
                _ = perform(diagnosis.command)
            }
        case "regional-capital":
            showObjectives = true
            guard analytics.secondActPhase == .qualification else {
                openInspector(.overview)
                return
            }
            let support = CityRegionalCapitalDecisionSupport.make(analytics: analytics)
            let diagnosis = support.secondaryResponses.first ?? support.primaryResponse
            if diagnosis.focusesMap {
                openInspector(.overview)
            } else {
                _ = perform(diagnosis.command)
            }
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
        case "Utility Reserve Tight", "Utility Shortfall":
            overlay = .utilities
            openInspector(.utilities)
            if message.severity == .warning || message.severity == .critical {
                setSpeed(.paused)
            }
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
        case "Budget Gap":
            openInspector(.finances)
            if message.severity == .warning || message.severity == .critical {
                setSpeed(.paused)
            }
        case "Hiring Bottleneck":
            openInspector(.employment)
            if message.severity == .warning || message.severity == .critical {
                setSpeed(.paused)
            }
        case "Town Charter Awarded":
            showObjectives = true
            openInspector(.overview)
        case "Town Charter Standards":
            showObjectives = true
            let support = CityTownCharterDecisionSupport.make(analytics: analytics)
            let diagnosis = support.secondaryResponses.first ?? support.primaryResponse
            if diagnosis.focusesMap {
                openInspector(.overview)
            } else {
                _ = perform(diagnosis.command)
            }
        case "Main Street Rebound", "Main Street Recovery Delayed",
             "Freight Network Secured", "Cleaner Industry Compact", "Freight Recovery Delayed":
            showObjectives = true
            let support = CityTownCharterDecisionSupport.make(analytics: analytics)
            let diagnosis = support.secondaryResponses.first ?? support.primaryResponse
            if diagnosis.focusesMap {
                openInspector(.overview)
            } else {
                _ = perform(diagnosis.command)
            }
        case "Town Charter Qualification Interrupted":
            showObjectives = true
            let support = CityTownCharterDecisionSupport.make(analytics: analytics)
            let diagnosis = support.secondaryResponses.first ?? support.primaryResponse
            if diagnosis.focusesMap {
                openInspector(.overview)
            } else {
                _ = perform(diagnosis.command)
            }
            setSpeed(.paused)
        case "Town Charter Qualification Resumed":
            showObjectives = true
            openInspector(.overview)
        case "Regional Retail Challenge", "Regional Retail Pressure":
            overlay = .happiness
            openInspector(.demand)
        case "Regional Grid Mandate", "Regional Freight Overload":
            overlay = .utilities
            openInspector(.utilities)
        case "Regional Qualification Interrupted":
            showObjectives = true
            let support = CityRegionalCapitalDecisionSupport.make(analytics: analytics)
            let diagnosis = support.secondaryResponses.first ?? support.primaryResponse
            if diagnosis.focusesMap {
                openInspector(.overview)
            } else {
                _ = perform(diagnosis.command)
            }
            setSpeed(.paused)
        case "Regional Main Street Recovery", "Regional Freight Recovery",
             "Regional Qualification Resumed", "Regional Capital Recognized":
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
        sessionReplacementConfirmation = nil
        speedBeforeSessionReplacementConfirmation = nil
        pendingSessionReplacementLoad = nil
        state = .newCity(seed: UInt64.random(in: 1...UInt64.max))
        lastPersistedState = nil
        cityNameDraft = state.cityName
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
        isCityFocusModeEnabled = false
        undoStates.removeAll()
        canUndo = false
        requestMapFocus()
        showFeedback("A fresh region is ready")
    }

    private var currentCityHasProgress: Bool {
        state.status == .playing && state != .newCity(seed: state.seed)
    }

    private func requestSessionReplacementConfirmation(
        for action: CitySessionReplacementAction,
        loadResult: SaveGameLoadResult? = nil
    ) {
        guard sessionReplacementConfirmation == nil else { return }
        speedBeforeSessionReplacementConfirmation = speed
        pendingSessionReplacementLoad = loadResult
        speed = .paused
        showCommandGuide = false
        sessionReplacementConfirmation = CitySessionReplacementConfirmationPresentation.make(
            state: state,
            action: action,
            loadResult: loadResult
        )
    }

    private func prepareLoadReplacementConfirmation() {
        do {
            let result = try saves.load()
            guard result.state != state else {
                applyLoadedResult(result)
                return
            }
            requestSessionReplacementConfirmation(
                for: .loadQuicksave,
                loadResult: result
            )
        } catch {
            showInvalidQuicksaveFeedback()
        }
    }

    @discardableResult
    func confirmSessionReplacement() -> Bool {
        guard let action = sessionReplacementConfirmation?.action else { return false }
        let preparedLoad = pendingSessionReplacementLoad
        sessionReplacementConfirmation = nil
        speedBeforeSessionReplacementConfirmation = nil
        pendingSessionReplacementLoad = nil
        switch action {
        case .newRegion:
            newCity()
        case .loadQuicksave:
            guard let preparedLoad else { return false }
            applyLoadedResult(preparedLoad)
        }
        return true
    }

    @discardableResult
    func cancelSessionReplacement() -> Bool {
        guard sessionReplacementConfirmation != nil else { return false }
        let previousSpeed = speedBeforeSessionReplacementConfirmation ?? .paused
        sessionReplacementConfirmation = nil
        speedBeforeSessionReplacementConfirmation = nil
        pendingSessionReplacementLoad = nil
        speed = previousSpeed
        let simulationStatus = previousSpeed == .paused
            ? "Simulation remains paused"
            : "Simulation resumed at \(previousSpeed.controlLabel)"
        showFeedback("\(state.cityName) kept · \(simulationStatus)", tone: .positive)
        return true
    }

    @discardableResult
    func save() -> Bool {
        do {
            try saves.save(state)
            lastPersistedState = state
            showFeedback(CityPersistenceFeedbackPresentation.saved(state).message, tone: .positive)
            playSound(named: "Glass")
            return true
        }
        catch {
            showFeedback(
                "Save failed · Your current city is still open: \(error.localizedDescription)",
                tone: .caution,
                autoDismissAfter: nil
            )
            return false
        }
    }

    func load() {
        do {
            applyLoadedResult(try saves.load())
        } catch {
            showInvalidQuicksaveFeedback()
        }
    }

    private func applyLoadedResult(_ result: SaveGameLoadResult) {
        state = result.state
        lastPersistedState = result.state
        cityNameDraft = state.cityName
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
        isCityFocusModeEnabled = false
        undoStates.removeAll()
        canUndo = false
        let brief = CityResumeBriefPresentation.make(analytics: analytics)
        showFeedback(
            CityPersistenceFeedbackPresentation.loaded(
                state,
                recoveredFromBackup: result.recoveredFromBackup
            ).message,
            tone: .positive,
            autoDismissAfter: brief == nil ? 3.2 : nil,
            resumeBrief: brief
        )
    }

    private func showInvalidQuicksaveFeedback() {
        showFeedback(
            "Quicksave could not be verified · Original save files were preserved",
            tone: .caution,
            autoDismissAfter: nil
        )
    }

    func undoLastAction() {
        guard let previous = undoStates.popLast() else {
            showFeedback("Nothing to undo", tone: .caution)
            return
        }
        let currentCityName = state.cityName
        state = previous
        state.cityName = currentCityName
        cityNameDraft = currentCityName
        selectedCoordinate = nil
        showInspector = false
        canUndo = !undoStates.isEmpty
        showFeedback("Last construction action undone", tone: .positive)
        playSound(named: "Pop")
    }

    func clearFeedback() {
        feedbackDismissal?.cancel()
        lastFeedback = nil
        resumeBrief = nil
    }

    @discardableResult
    func performResumeBriefAction() -> Bool {
        guard let command = resumeBrief?.command, canPerform(command) else { return false }
        clearFeedback()
        return perform(command)
    }

    private func recordUndo(_ snapshot: CityGameState) {
        undoStates.append(snapshot)
        if undoStates.count > 20 { undoStates.removeFirst() }
        canUndo = true
    }

    private func showFeedback(
        _ message: String,
        tone: PlayerFeedbackTone = .neutral,
        autoDismissAfter delay: TimeInterval? = 3.2,
        resumeBrief: CityResumeBriefPresentation? = nil
    ) {
        feedbackDismissal?.cancel()
        lastFeedback = message
        lastFeedbackTone = tone
        self.resumeBrief = resumeBrief
        guard let delay else {
            feedbackDismissal = nil
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.lastFeedback = nil }
        feedbackDismissal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func playSound(named name: String) {
        guard UserDefaults.standard.object(forKey: "soundEffects") as? Bool ?? true else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    private func leaveCityFocusForPresentedSurface() {
        isCityFocusModeEnabled = false
    }

    static func shouldQuarantineCityFocusShortcut(
        firstResponder: NSResponder?,
        event: NSEvent?
    ) -> Bool {
        guard firstResponder is NSTextView || firstResponder is NSTextField,
              let event,
              event.type == .keyDown,
              event.charactersIgnoringModifiers?.lowercased() == "f" else {
            return false
        }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return modifiers.contains(.command) && modifiers.contains(.shift)
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
