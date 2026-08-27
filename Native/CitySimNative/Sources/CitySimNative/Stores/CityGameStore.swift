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
    static let autosaveIntervalTicks = 240

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
    @Published var showCityHandbook = false
    @Published private(set) var isCityFocusModeEnabled = false
    @Published private(set) var isPhotoModeEnabled = false
    @Published private(set) var photoCaptureRequestGeneration: UInt = 0
    @Published private(set) var latestPhotoCaptureURL: URL?
    @Published private(set) var commandPolicy: CityCommandPolicy
    @Published var inspectorSection: InspectorSection = .overview
    @Published var hudContextScope: HUDContextScope = .city
    @Published var lastFeedback: String?
    @Published private(set) var lastFeedbackTone: PlayerFeedbackTone = .neutral
    @Published private(set) var resumeBrief: CityResumeBriefPresentation?
    @Published private(set) var startupResumeOffer: CityStartupResumePresentation?
    @Published private(set) var newRegionSetup: CityNewRegionSetupPresentation?
    @Published private(set) var newRegionDraft = CityNewRegionDraft.initial(seed: 1)
    @Published private(set) var benchmarkSession: CityBenchmarkSessionPresentation?
    @Published private(set) var checkpointLibrary: CityCheckpointLibraryPresentation?
    @Published private(set) var checkpointSupportFeedback: CityCheckpointSupportFeedback?
    @Published private(set) var branchNaming: CityBranchNamingPresentation?
    @Published private(set) var branchNameDraft = ""
    @Published private(set) var branchNameError: String?
    @Published private(set) var sessionReplacementConfirmation: CitySessionReplacementConfirmationPresentation?
    @Published private(set) var canUndo = false
    @Published private(set) var mapFocusRequestGeneration: UInt = 0
    @Published private(set) var foundationsGuideProgress: CityFoundationsGuideProgress

    private let saves: SaveGameService
    private let playerDefaults: UserDefaults?
    private let soundFeedback: CitySoundFeedbackController
    private let photos: CityPhotoService
    private let benchmarkReports: CityBenchmarkReportService
    private let capturesScenarioCheckpoints: Bool
    private let revealSupportReport: (URL) -> Void
    private var undoStates: [CityGameState] = []
    private var feedbackDismissal: DispatchWorkItem?
    private var lastNonPausedSpeed: SimulationSpeed = .normal
    private var speedBeforeSessionReplacementConfirmation: SimulationSpeed?
    private var pendingSessionReplacementLoad: SaveGameLoadResult?
    private var speedBeforeStartupResumeOffer: SimulationSpeed?
    private var speedBeforeNewRegionSetup: SimulationSpeed?
    private var pendingStartupResumeLoad: SaveGameLoadResult?
    private var startupResumeOfferWasConsidered = false
    private var checkpointLoadsByID: [String: SaveGameLoadResult] = [:]
    private var checkpointEntriesByID: [String: SaveGameCheckpointCatalogEntry] = [:]
    private var speedBeforeCheckpointLibrary: SimulationSpeed?
    private var pendingBranchState: CityGameState?
    private var pendingBranchSource: SaveGameSource?
    private var branchNamingReturnsToLibrary = false
    private var speedBeforeBranchNaming: SimulationSpeed?
    private var lastPersistedState: CityGameState?
    private var lastPersistenceCheckpointKind: CityPersistenceCheckpointKind = .manual
    private var nextAutosaveTick: Int
    private var previousObjectiveProgressByID: [String: Double] = [:]
    private var speedBeforePhotoMode: SimulationSpeed?
    private var overlayBeforePhotoMode: DataOverlay?
    private var cityFocusBeforePhotoMode = false
    private var inspectorBeforePhotoMode = false
    private var objectivesBeforePhotoMode = false
    private var benchmarkTask: Task<Void, Never>?

    init(
        state: CityGameState = .newCity(),
        commandPolicy: CityCommandPolicy = .enabled,
        saveService: SaveGameService = SaveGameService(),
        startsPaused: Bool = false,
        capturesScenarioCheckpoints: Bool = false,
        photoService: CityPhotoService? = nil,
        benchmarkReportService: CityBenchmarkReportService? = nil,
        revealSupportReport: ((URL) -> Void)? = nil,
        playerDefaults: UserDefaults? = nil,
        soundPlayer: (any CitySoundPlaying)? = nil
    ) {
        self.state = state
        self.cityNameDraft = state.cityName
        self.commandPolicy = commandPolicy
        self.saves = saveService
        self.playerDefaults = playerDefaults
        self.soundFeedback = CitySoundFeedbackController(
            defaults: playerDefaults ?? .standard,
            player: soundPlayer ?? CitySystemSoundPlayer()
        )
        self.foundationsGuideProgress = playerDefaults.map {
            CityFoundationsGuidePersistence.read(from: $0)
        } ?? .fresh
        self.photos = photoService ?? CityPhotoService()
        self.benchmarkReports = benchmarkReportService ?? CityBenchmarkReportService()
        self.capturesScenarioCheckpoints = capturesScenarioCheckpoints
        self.revealSupportReport = revealSupportReport ?? { url in
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        self.nextAutosaveTick = state.tick + Self.autosaveIntervalTicks
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

    var foundationsGuidePresentation: CityFoundationsGuidePresentation? {
        guard state.cityHistory != nil,
              state.authoredScenario == nil,
              state.sandboxRules == nil,
              !foundationsGuideProgress.isDismissed else { return nil }
        return CityFoundationsGuidePresentation.make(progress: foundationsGuideProgress)
    }

    var persistenceStatus: CityPersistenceStatusPresentation {
        CityPersistenceStatusPresentation.make(
            current: state,
            lastPersisted: lastPersistedState,
            checkpointKind: lastPersistenceCheckpointKind
        )
    }

    var hasUnsavedProgress: Bool {
        CityTerminationConfirmationPresentation.isRequired(
            state: state,
            persistenceStatus: persistenceStatus
        )
    }

    var objectives: [CityObjective] {
        if let scenario = CityAuthoredScenarioEvaluation.make(state: state) {
            return scenario.objectives
        }
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

    var objectivePresentations: [CityObjectivePresentation] {
        if let scenario = CityAuthoredScenarioEvaluation.make(state: state) {
            return scenario.presentations(previousProgressByID: previousObjectiveProgressByID)
        }
        let metrics = analytics
        return objectives.map {
            CityObjectivePresentation.make(
                objective: $0,
                analytics: metrics,
                previousProgress: previousObjectiveProgressByID[$0.id]
            )
        }
    }

    var primaryObjectivePresentation: CityObjectivePresentation {
        objectivePresentations.first(where: { !$0.completed }) ?? objectivePresentations[0]
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
        let dayBeforePulse = state.day
        let messagesBeforePulse = state.messages
        let objectivesBeforePulse = objectives
        let progressBeforePulse = Dictionary(uniqueKeysWithValues: objectives.map { ($0.id, $0.progress) })
        let initialStatus = state.status
        var scenarioFailure: String?
        for _ in 0..<speed.ticksPerPulse {
            let progressionBeforeStep = capturesScenarioCheckpoints
                ? state.progression
                : nil
            CitySimulation.step(&state)
            if capturesScenarioCheckpoints {
                scenarioFailure = captureScenarioCheckpoints(
                    reachedSince: progressionBeforeStep
                ) ?? scenarioFailure
            }
            if state.status != .playing {
                speed = .paused
                break
            }
        }
        if state.tick >= nextAutosaveTick
            || (initialStatus == .playing && state.status != .playing) {
            autosave()
        }
        if let failure = scenarioFailure {
            showFeedback(failure, tone: .caution, autoDismissAfter: nil)
        }
        if let cue = CitySimulationSoundTransition.resolve(
            messagesBefore: messagesBeforePulse,
            messagesAfter: state.messages,
            objectivesBefore: objectivesBeforePulse,
            objectivesAfter: objectives
        ) {
            soundFeedback.play(cue)
        }
        previousObjectiveProgressByID = progressBeforePulse
        if state.day > dayBeforePulse {
            completeFoundationsLesson(.runCity)
        }
    }

    @discardableResult
    func perform(_ command: CityCommandID) -> Bool {
        if command == .cancelInteraction,
           commandPolicy == .blocked(.branchNaming) {
            return cancelBranchNaming()
        }
        if command == .cancelInteraction,
           commandPolicy == .blocked(.checkpointLibrary) {
            return cancelCheckpointLibrary()
        }
        if command == .cancelInteraction,
           commandPolicy == .blocked(.newRegionSetup) {
            return benchmarkSession == nil ? cancelNewRegionSetup() : closeBenchmark()
        }
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
            if overlay == .utilities {
                completeFoundationsLesson(.utilities)
            }
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
                openNewRegionSetup()
            }
        case .saveCity:
            save()
        case .saveBranch:
            openBranchNamingForCurrentCity()
        case .loadCity:
            openCheckpointLibrary()
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
        case .togglePhotoMode:
            togglePhotoMode()
        case .capturePhoto:
            requestPhotoCapture()
        case .openNotices:
            openAlertCenter()
        case .openCommandGuide:
            showCityHandbook = false
            showCommandGuide = true
        case .openHandbook:
            showCommandGuide = false
            showCityHandbook = true
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
            return command == .cancelInteraction || command == .openHandbook
        }
        if state.status != .playing,
           ![CityCommandID.newRegion, .saveCity, .saveBranch, .loadCity, .openHandbook]
            .contains(command) {
            return false
        }
        return switch command {
        case .undo:
            canUndo
        case .loadCity:
            saves.hasResumeCandidate
        case .dismissFeedback:
            lastFeedback != nil
        case .cancelInteraction:
            showCityHandbook || showCommandGuide || isPhotoModeEnabled || isCityFocusModeEnabled
                || showInspector || showObjectives
                || selectedCoordinate != nil || interactionMode != .inspect
        case .capturePhoto:
            isPhotoModeEnabled
        case .togglePhotoMode:
            true
        default:
            !isPhotoModeEnabled
        }
    }

    func disabledReason(for command: CityCommandID) -> String? {
        guard !canPerform(command) else { return nil }
        if let policyReason = commandPolicy.disabledReason { return policyReason }
        if sessionReplacementConfirmation != nil {
            return sessionReplacementConfirmation?.action == .newRegion
                ? "Choose whether to open the mode chooser or keep \(state.cityName)"
                : "Choose whether to keep or replace \(state.cityName)"
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
            case .loadCity: return "No saved checkpoint is available"
            case .dismissFeedback: return "There is no transient action message"
            case .capturePhoto: return "Enter Photo Mode before taking a city photograph"
            case .togglePhotoMode: return "Photo Mode is unavailable in the current context"
            case .cancelInteraction: return "There is no open surface or active tool to cancel"
            default:
                return switch state.status {
                case .playing:
                    "Unavailable in the current context"
                case .won:
                    state.authoredScenario == nil
                        ? "The mayoral mandate is complete; start a new region or load a city"
                        : "The authored scenario is complete; start a new region or load a city"
                case .lost:
                    state.authoredScenario == nil
                        ? "This city session ended in crisis; start a new region or load a city"
                        : "The authored scenario ended; start a new region or load a city"
                }
            }
        }
    }

    func canRouteMapCommand(_ command: CityCommandID) -> Bool {
        guard sessionReplacementConfirmation == nil,
              state.status == .playing,
              !isPhotoModeEnabled,
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
           case .success = CitySimulation.validateBuild(kind, at: selectedCoordinate, in: state),
           kind != .road || state.neighbors(of: selectedCoordinate).contains(where: {
               $0.kind == .road
           }) {
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
                if kind == .road {
                    let lhsExtendsRoad = state.neighbors(of: lhs.coordinate).contains {
                        $0.kind == .road
                    }
                    let rhsExtendsRoad = state.neighbors(of: rhs.coordinate).contains {
                        $0.kind == .road
                    }
                    if lhsExtendsRoad != rhsExtendsRoad { return lhsExtendsRoad }
                }
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
        guard !isPhotoModeEnabled else { return }
        isCityFocusModeEnabled.toggle()
        requestMapFocus()
    }

    func togglePhotoMode() {
        isPhotoModeEnabled ? exitPhotoMode() : enterPhotoMode()
    }

    func enterPhotoMode() {
        guard state.status == .playing, commandPolicy == .enabled,
              !isPhotoModeEnabled else { return }
        speedBeforePhotoMode = speed
        overlayBeforePhotoMode = overlay
        cityFocusBeforePhotoMode = isCityFocusModeEnabled
        inspectorBeforePhotoMode = showInspector
        objectivesBeforePhotoMode = showObjectives
        speed = .paused
        overlay = .none
        isPhotoModeEnabled = true
        isCityFocusModeEnabled = false
        showInspector = false
        showObjectives = false
        showCommandGuide = false
        showCityHandbook = false
        latestPhotoCaptureURL = nil
        clearFeedback()
        requestMapFocus()
    }

    func exitPhotoMode() {
        guard isPhotoModeEnabled else { return }
        isPhotoModeEnabled = false
        if state.status == .playing, let prior = speedBeforePhotoMode {
            speed = prior
        }
        if let prior = overlayBeforePhotoMode { overlay = prior }
        isCityFocusModeEnabled = cityFocusBeforePhotoMode
        showInspector = inspectorBeforePhotoMode
        showObjectives = objectivesBeforePhotoMode
        speedBeforePhotoMode = nil
        overlayBeforePhotoMode = nil
        cityFocusBeforePhotoMode = false
        inspectorBeforePhotoMode = false
        objectivesBeforePhotoMode = false
        requestMapFocus()
    }

    func requestPhotoCapture() {
        guard isPhotoModeEnabled else { return }
        photoCaptureRequestGeneration &+= 1
    }

    func completePhotoCapture(pngData: Data) {
        guard isPhotoModeEnabled else { return }
        do {
            let result = try photos.export(
                pngData: pngData,
                cityName: state.cityName,
                day: state.day
            )
            latestPhotoCaptureURL = result.url
            showFeedback(
                "Photo saved to Pictures/CitySim · \(result.url.lastPathComponent)",
                tone: .positive
            )
        } catch {
            showFeedback(
                "Photo could not be saved · \(error.localizedDescription)",
                tone: .caution,
                autoDismissAfter: nil
            )
        }
    }

    func failPhotoCapture() {
        guard isPhotoModeEnabled else { return }
        showFeedback(
            "Photo could not be captured · Keep Photo Mode open and try again",
            tone: .caution,
            autoDismissAfter: nil
        )
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
              isFreshStartupCity else { return }
        startupResumeOfferWasConsidered = true
        guard saves.hasResumeCandidate else { return }
        do {
            let result = try saves.loadLatestResumeCandidate()
            speedBeforeStartupResumeOffer = speed
            speed = .paused
            pendingStartupResumeLoad = result
            startupResumeOffer = CityStartupResumePresentation.make(result)
            presentBlockingModal(.startupResume)
        } catch {
            showInvalidQuicksaveFeedback()
        }
    }

    private var isFreshStartupCity: Bool {
        state == .newCity(seed: state.seed)
            || state == .newTrackedCity(seed: state.seed)
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
        if benchmarkSession != nil {
            closeBenchmark()
        } else if newRegionSetup != nil {
            cancelNewRegionSetup()
        } else if branchNaming != nil {
            cancelBranchNaming()
        } else if checkpointLibrary != nil {
            cancelCheckpointLibrary()
        } else if sessionReplacementConfirmation != nil {
            cancelSessionReplacement()
        } else if showCityHandbook {
            showCityHandbook = false
            requestMapFocus()
        } else if showCommandGuide {
            showCommandGuide = false
            requestMapFocus()
        } else if isPhotoModeEnabled {
            exitPhotoMode()
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
        completeFoundationsLesson(.observe)
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
        switch section {
        case .overview:
            completeFoundationsLesson(.observe)
        case .finances:
            completeFoundationsLesson(.budget)
        case .utilities:
            completeFoundationsLesson(.utilities)
        case .journal:
            completeFoundationsLesson(.services)
        default:
            break
        }
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
                completeFoundationsLesson(for: kind)
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
                soundFeedback.play(.constructionApproved)
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
        soundFeedback.play(.actionRejected)
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
            soundFeedback.play(.demolitionApproved)
        } else {
            showFeedback("City Hall and open land cannot be demolished", tone: .caution)
            soundFeedback.play(.actionRejected)
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
        case "scenario-water":
            showObjectives = true
            overlay = .utilities
            openInspector(.utilities)
        case "scenario-stability":
            showObjectives = true
            if CitySimulation.utilityCoverage(in: state) < 1 {
                overlay = .utilities
                openInspector(.utilities)
            } else {
                openInspector(.finances)
            }
        case "scenario-reserve":
            showObjectives = true
            openInspector(.finances)
        case "scenario-population":
            showObjectives = true
            openInspector(.population)
        case "stabilize": openInspector(.finances)
        case "capacity": openInspector(.utilities)
        case "strategy":
            showObjectives = true
            if analytics.strategyPhase == .recovery {
                openInspector(analytics.committedStrategy == .industrialExpansion ? .utilities : .finances)
            } else {
                openInspector(.overview)
            }
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

    @discardableResult
    func performFoundationsGuideAction() -> Bool {
        guard let command = foundationsGuidePresentation?.currentLesson?.command else {
            return false
        }
        if CityCommandCatalog.mapFocusedCommands.contains(command)
            || CityCommandCatalog.buildingKind(for: command) != nil {
            return performMapFocused(command)
        }
        return perform(command)
    }

    func dismissFoundationsGuide() {
        guard foundationsGuidePresentation != nil else { return }
        var updated = foundationsGuideProgress
        updated.isDismissed = true
        foundationsGuideProgress = updated
        if let playerDefaults {
            CityFoundationsGuidePersistence.write(updated, to: playerDefaults)
        }
        showFeedback("City Coach hidden · Restart it anytime in Settings")
    }

    func restartFoundationsGuide() {
        foundationsGuideProgress = .fresh
        if let playerDefaults {
            CityFoundationsGuidePersistence.write(.fresh, to: playerDefaults)
        }
    }

    func reloadFoundationsGuideProgress() {
        guard let playerDefaults else { return }
        foundationsGuideProgress = CityFoundationsGuidePersistence.read(from: playerDefaults)
    }

    func newCity() {
        applyNewRegion(
            CityNewRegionConfiguration(
                experience: .guidedFoundations,
                cityName: "New Arcadia",
                seed: UInt64.random(in: 1...UInt64.max),
                startingResources: .balanced
            )
        )
    }

    func openNewRegionSetup(suggestedSeed: UInt64? = nil) {
        guard newRegionSetup == nil, commandPolicy == .enabled else { return }
        speedBeforeNewRegionSetup = speed
        speed = .paused
        showCommandGuide = false
        showCityHandbook = false
        let seed = suggestedSeed ?? UInt64.random(in: 1...UInt64.max)
        newRegionDraft = .initial(seed: seed)
        newRegionSetup = .standard
        presentBlockingModal(.newRegionSetup)
    }

    func updateNewRegionExperience(_ experience: CityNewRegionExperience) {
        guard commandPolicy == .blocked(.newRegionSetup) else { return }
        newRegionDraft.experience = experience
    }

    func updateNewRegionScenario(_ scenarioID: String) {
        guard commandPolicy == .blocked(.newRegionSetup),
              CityAuthoredScenarioCatalog.definition(for: scenarioID) != nil else { return }
        newRegionDraft.scenarioID = scenarioID
    }

    func updateNewRegionCityName(_ cityName: String) {
        guard commandPolicy == .blocked(.newRegionSetup) else { return }
        newRegionDraft.cityName = String(cityName.prefix(60))
    }

    func updateNewRegionSeed(_ seed: String) {
        guard commandPolicy == .blocked(.newRegionSetup) else { return }
        newRegionDraft.seedText = String(seed.prefix(24))
    }

    func updateNewRegionStartingResources(_ resources: CitySandboxStartingResources) {
        guard commandPolicy == .blocked(.newRegionSetup) else { return }
        newRegionDraft.startingResources = resources
    }

    func updateNewRegionSandboxEconomy(_ economy: CitySandboxEconomy) {
        guard commandPolicy == .blocked(.newRegionSetup) else { return }
        newRegionDraft.sandboxEconomy = economy
    }

    func updateNewRegionSandboxIncidents(_ incidentsEnabled: Bool) {
        guard commandPolicy == .blocked(.newRegionSetup) else { return }
        newRegionDraft.incidentsEnabled = incidentsEnabled
    }

    func updateNewRegionSandboxUnlimitedFunds(_ unlimitedFunds: Bool) {
        guard commandPolicy == .blocked(.newRegionSetup) else { return }
        newRegionDraft.unlimitedFunds = unlimitedFunds
    }

    @discardableResult
    func createNewRegion() -> Bool {
        guard commandPolicy == .blocked(.newRegionSetup) else { return false }
        if newRegionDraft.experience == .benchmark {
            newRegionSetup = nil
            benchmarkSession = .ready()
            return true
        }
        guard let configuration = newRegionDraft.configuration else { return false }
        _ = dismissBlockingModal(.newRegionSetup)
        newRegionSetup = nil
        speedBeforeNewRegionSetup = nil
        applyNewRegion(configuration)
        return true
    }

    @discardableResult
    func cancelNewRegionSetup() -> Bool {
        guard commandPolicy == .blocked(.newRegionSetup), newRegionSetup != nil else {
            return false
        }
        let previousSpeed = speedBeforeNewRegionSetup ?? .paused
        newRegionSetup = nil
        speedBeforeNewRegionSetup = nil
        _ = dismissBlockingModal(.newRegionSetup)
        speed = previousSpeed
        requestMapFocus()
        showFeedback("\(state.cityName) kept · New region setup canceled")
        return true
    }

    @discardableResult
    func startBenchmark() -> Bool {
        guard commandPolicy == .blocked(.newRegionSetup),
              var session = benchmarkSession,
              session.phase != .running else { return false }
        benchmarkTask?.cancel()
        session.phase = .running
        session.completedPulses = 0
        session.result = nil
        session.reportURL = nil
        session.message = nil
        benchmarkSession = session

        let definition = session.definition
        let benchmarkStore = self
        benchmarkTask = Task.detached(priority: .userInitiated) {
            do {
                let result = try await CityBenchmarkRunner.run(definition: definition) {
                    completed, _ in
                    await benchmarkStore.updateBenchmarkProgress(completed)
                }
                await benchmarkStore.completeBenchmark(result)
            } catch CityBenchmarkRunError.canceled {
                await benchmarkStore.finishBenchmarkCancellation()
            } catch {
                await benchmarkStore.failBenchmark(error.localizedDescription)
            }
        }
        return true
    }

    @discardableResult
    func cancelBenchmarkRun() -> Bool {
        guard benchmarkSession?.phase == .running else { return false }
        benchmarkTask?.cancel()
        benchmarkTask = nil
        finishBenchmarkCancellation()
        return true
    }

    @discardableResult
    func exportBenchmarkReport() -> Bool {
        guard var session = benchmarkSession, let result = session.result else { return false }
        do {
            let url = try benchmarkReports.export(result: result)
            session.reportURL = url
            session.message = nil
            benchmarkSession = session
            revealSupportReport(url)
            return true
        } catch {
            session.reportURL = nil
            session.message = "Report could not be saved · \(error.localizedDescription)"
            benchmarkSession = session
            return false
        }
    }

    @discardableResult
    func returnToModeChooserFromBenchmark() -> Bool {
        guard commandPolicy == .blocked(.newRegionSetup), benchmarkSession != nil else {
            return false
        }
        benchmarkTask?.cancel()
        benchmarkTask = nil
        benchmarkSession = nil
        newRegionSetup = .standard
        return true
    }

    @discardableResult
    func closeBenchmark() -> Bool {
        guard commandPolicy == .blocked(.newRegionSetup), benchmarkSession != nil else {
            return false
        }
        benchmarkTask?.cancel()
        benchmarkTask = nil
        benchmarkSession = nil
        newRegionSetup = nil
        let previousSpeed = speedBeforeNewRegionSetup ?? .paused
        speedBeforeNewRegionSetup = nil
        _ = dismissBlockingModal(.newRegionSetup)
        speed = previousSpeed
        requestMapFocus()
        showFeedback("\(state.cityName) kept · Benchmark closed without changing the city")
        return true
    }

    private func updateBenchmarkProgress(_ completedPulses: Int) {
        guard var session = benchmarkSession, session.phase == .running else { return }
        session.completedPulses = completedPulses
        benchmarkSession = session
    }

    private func completeBenchmark(_ result: CityBenchmarkResult) {
        guard var session = benchmarkSession, session.phase == .running else { return }
        benchmarkTask = nil
        session.phase = .complete
        session.completedPulses = session.definition.pulseCount
        session.result = result
        benchmarkSession = session
    }

    private func finishBenchmarkCancellation() {
        guard var session = benchmarkSession, session.phase == .running else { return }
        benchmarkTask = nil
        session.phase = .canceled
        session.message = "The temporary workload stopped. Your current city was not changed."
        benchmarkSession = session
    }

    private func failBenchmark(_ message: String) {
        guard var session = benchmarkSession else { return }
        benchmarkTask = nil
        session.phase = .failed
        session.message = "Benchmark could not finish · \(message)"
        benchmarkSession = session
    }

    private func applyNewRegion(_ configuration: CityNewRegionConfiguration) {
        sessionReplacementConfirmation = nil
        speedBeforeSessionReplacementConfirmation = nil
        pendingSessionReplacementLoad = nil
        newRegionSetup = nil
        benchmarkTask?.cancel()
        benchmarkTask = nil
        benchmarkSession = nil
        speedBeforeNewRegionSetup = nil
        checkpointLibrary = nil
        checkpointLoadsByID.removeAll()
        checkpointEntriesByID.removeAll()
        checkpointSupportFeedback = nil
        speedBeforeCheckpointLibrary = nil
        clearBranchNamingState()
        state = configuration.makeState()
        isPhotoModeEnabled = false
        speedBeforePhotoMode = nil
        overlayBeforePhotoMode = nil
        cityFocusBeforePhotoMode = false
        inspectorBeforePhotoMode = false
        objectivesBeforePhotoMode = false
        latestPhotoCaptureURL = nil
        previousObjectiveProgressByID.removeAll()
        lastPersistedState = nil
        lastPersistenceCheckpointKind = .manual
        nextAutosaveTick = state.tick + Self.autosaveIntervalTicks
        cityNameDraft = state.cityName
        speed = .paused
        lastNonPausedSpeed = .normal
        selectedTool = .road
        selectedBuildCategory = .roads
        interactionMode = .inspect
        selectedCoordinate = nil
        overlay = .none
        inspectorSection = .overview
        hudContextScope = .city
        showInspector = false
        showObjectives = false
        showCommandGuide = false
        showCityHandbook = false
        isCityFocusModeEnabled = false
        undoStates.removeAll()
        canUndo = false
        requestMapFocus()
        switch configuration.experience {
        case .guidedFoundations:
            restartFoundationsGuide()
            showFeedback("Guided Foundations ready · New Arcadia · Seed \(configuration.seed)")
        case .authoredScenario:
            showObjectives = true
            let scenario = CityAuthoredScenarioCatalog.definition(
                for: configuration.scenarioID ?? CityAuthoredScenarioCatalog.harborRecovery.id
            ) ?? CityAuthoredScenarioCatalog.harborRecovery
            showFeedback(
                "Scenario ready · \(scenario.title) · \(scenario.deadlineDay - 1) city days · Start paused",
                tone: .positive,
                autoDismissAfter: nil
            )
        case .openSandbox:
            showFeedback(
                "Sandbox ready · \(configuration.cityName) · Seed \(configuration.seed) · "
                    + configuration.sandboxRules.summary,
                tone: .positive
            )
        case .benchmark:
            break
        }
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
        showCityHandbook = false
        sessionReplacementConfirmation = CitySessionReplacementConfirmationPresentation.make(
            state: state,
            action: action,
            loadResult: loadResult
        )
    }

    func openCheckpointLibrary() {
        guard checkpointLibrary == nil, commandPolicy == .enabled else { return }
        let entries = saves.checkpointCatalog()
        guard !entries.isEmpty else {
            showInvalidQuicksaveFeedback()
            return
        }
        checkpointLoadsByID = Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
            entry.loadResult.map { (entry.id, $0) }
        })
        checkpointEntriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        checkpointSupportFeedback = nil
        speedBeforeCheckpointLibrary = speed
        speed = .paused
        showCommandGuide = false
        showCityHandbook = false
        checkpointLibrary = CityCheckpointLibraryPresentation.make(entries)
        presentBlockingModal(.checkpointLibrary)
    }

    @discardableResult
    func exportCheckpointSupportReport(for checkpointID: String) -> Bool {
        guard commandPolicy == .blocked(.checkpointLibrary),
              let entry = checkpointEntriesByID[checkpointID],
              !entry.isLoadable else { return false }
        do {
            let url = try saves.exportSupportReport(for: entry)
            checkpointSupportFeedback = CityCheckpointSupportFeedback(
                message: "Support report created · \(url.lastPathComponent) · "
                    + "Original recovery file unchanged",
                isError: false
            )
            revealSupportReport(url)
            return true
        } catch {
            checkpointSupportFeedback = CityCheckpointSupportFeedback(
                message: "Support report failed · The recovery file is unchanged: "
                    + error.localizedDescription,
                isError: true
            )
            return false
        }
    }

    func openBranchNamingForCurrentCity() {
        guard branchNaming == nil, commandPolicy == .enabled else { return }
        speedBeforeBranchNaming = speed
        speed = .paused
        pendingBranchState = state
        pendingBranchSource = nil
        branchNamingReturnsToLibrary = false
        branchNameDraft = suggestedBranchName(for: state)
        branchNameError = nil
        branchNaming = CityBranchNamingPresentation.make(state: state, source: nil)
        presentBlockingModal(.branchNaming)
    }

    @discardableResult
    func beginBranchNaming(for checkpointID: String) -> Bool {
        guard commandPolicy == .blocked(.checkpointLibrary),
              let result = checkpointLoadsByID[checkpointID] else { return false }
        pendingBranchState = result.state
        pendingBranchSource = result.source
        branchNamingReturnsToLibrary = true
        speedBeforeBranchNaming = speedBeforeCheckpointLibrary
        branchNameDraft = suggestedBranchName(for: result.state)
        branchNameError = nil
        branchNaming = CityBranchNamingPresentation.make(
            state: result.state,
            source: result.source
        )
        checkpointLibrary = nil
        _ = dismissBlockingModal(.checkpointLibrary)
        presentBlockingModal(.branchNaming)
        return true
    }

    func updateBranchNameDraft(_ value: String) {
        branchNameDraft = String(value.prefix(40))
        branchNameError = nil
    }

    var canCreateBranch: Bool {
        !branchNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    func createNamedBranch() -> Bool {
        guard commandPolicy == .blocked(.branchNaming),
              let pendingBranchState else { return false }
        let cleanedName = branchNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try saves.saveNamedBranch(pendingBranchState, name: cleanedName)
            let branchedCurrentState = pendingBranchSource == nil && pendingBranchState == state
            if branchedCurrentState {
                lastPersistedState = state
                lastPersistenceCheckpointKind = .branch
                nextAutosaveTick = state.tick + Self.autosaveIntervalTicks
            }
            let previousSpeed = speedBeforeBranchNaming ?? .paused
            clearBranchNamingState()
            checkpointLibrary = nil
            checkpointLoadsByID.removeAll()
            checkpointEntriesByID.removeAll()
            checkpointSupportFeedback = nil
            speedBeforeCheckpointLibrary = nil
            _ = dismissBlockingModal(.branchNaming)
            speed = previousSpeed
            requestMapFocus()
            showFeedback(
                CityPersistenceFeedbackPresentation.branched(
                    pendingBranchState,
                    name: cleanedName
                ).message,
                tone: .positive
            )
            return true
        } catch {
            branchNameError = error.localizedDescription
            showFeedback(
                "Timeline branch failed · The source checkpoint is unchanged: "
                    + error.localizedDescription,
                tone: .caution,
                autoDismissAfter: nil
            )
            return false
        }
    }

    @discardableResult
    func cancelBranchNaming() -> Bool {
        guard commandPolicy == .blocked(.branchNaming), branchNaming != nil else { return false }
        let returnsToLibrary = branchNamingReturnsToLibrary
        let previousSpeed = speedBeforeBranchNaming ?? .paused
        clearBranchNamingState()
        _ = dismissBlockingModal(.branchNaming)
        if returnsToLibrary {
            let entries = saves.checkpointCatalog()
            checkpointLoadsByID = Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
                entry.loadResult.map { (entry.id, $0) }
            })
            checkpointEntriesByID = Dictionary(
                uniqueKeysWithValues: entries.map { ($0.id, $0) }
            )
            checkpointSupportFeedback = nil
            checkpointLibrary = CityCheckpointLibraryPresentation.make(entries)
            presentBlockingModal(.checkpointLibrary)
        } else {
            speed = previousSpeed
            requestMapFocus()
        }
        return true
    }

    private func suggestedBranchName(for state: CityGameState) -> String {
        String("\(state.cityName) · \(state.formattedDay)".prefix(40))
    }

    private func clearBranchNamingState() {
        branchNaming = nil
        branchNameDraft = ""
        branchNameError = nil
        pendingBranchState = nil
        pendingBranchSource = nil
        branchNamingReturnsToLibrary = false
        speedBeforeBranchNaming = nil
    }

    @discardableResult
    func selectCheckpoint(_ id: String) -> Bool {
        guard commandPolicy == .blocked(.checkpointLibrary),
              let result = checkpointLoadsByID[id] else { return false }
        let previousSpeed = speedBeforeCheckpointLibrary ?? .paused
        checkpointLibrary = nil
        checkpointLoadsByID.removeAll()
        checkpointEntriesByID.removeAll()
        checkpointSupportFeedback = nil
        speedBeforeCheckpointLibrary = nil
        _ = dismissBlockingModal(.checkpointLibrary)
        speed = previousSpeed

        if currentCityHasProgress, result.state != state {
            requestSessionReplacementConfirmation(
                for: .loadQuicksave,
                loadResult: result
            )
        } else {
            applyLoadedResult(result)
            requestMapFocus()
        }
        return true
    }

    @discardableResult
    func cancelCheckpointLibrary() -> Bool {
        guard commandPolicy == .blocked(.checkpointLibrary), checkpointLibrary != nil else {
            return false
        }
        let previousSpeed = speedBeforeCheckpointLibrary ?? .paused
        checkpointLibrary = nil
        checkpointLoadsByID.removeAll()
        checkpointEntriesByID.removeAll()
        checkpointSupportFeedback = nil
        speedBeforeCheckpointLibrary = nil
        _ = dismissBlockingModal(.checkpointLibrary)
        speed = previousSpeed
        requestMapFocus()
        showFeedback("\(state.cityName) kept · No checkpoint loaded")
        return true
    }

    @discardableResult
    func confirmSessionReplacement() -> Bool {
        guard let action = sessionReplacementConfirmation?.action else { return false }
        let preparedLoad = pendingSessionReplacementLoad
        let previousSpeed = speedBeforeSessionReplacementConfirmation ?? .paused
        sessionReplacementConfirmation = nil
        speedBeforeSessionReplacementConfirmation = nil
        pendingSessionReplacementLoad = nil
        switch action {
        case .newRegion:
            openNewRegionSetup()
            speedBeforeNewRegionSetup = previousSpeed
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
            lastPersistenceCheckpointKind = .manual
            nextAutosaveTick = state.tick + Self.autosaveIntervalTicks
            showFeedback(CityPersistenceFeedbackPresentation.saved(state).message, tone: .positive)
            soundFeedback.play(.persistenceSucceeded)
            return true
        }
        catch {
            showFeedback(
                "Save failed · Your current city is still open: \(error.localizedDescription)",
                tone: .caution,
                autoDismissAfter: nil
            )
            soundFeedback.play(.actionRejected)
            return false
        }
    }

    func load() {
        do {
            applyLoadedResult(try saves.loadLatestResumeCandidate())
        } catch {
            showInvalidQuicksaveFeedback()
        }
    }

    @discardableResult
    private func autosave() -> Bool {
        nextAutosaveTick = state.tick + Self.autosaveIntervalTicks
        guard state != lastPersistedState else { return true }
        do {
            try saves.saveAutosave(state)
            lastPersistedState = state
            lastPersistenceCheckpointKind = .autosave
            showFeedback(
                CityPersistenceFeedbackPresentation.autosaved(state).message,
                tone: .positive,
                autoDismissAfter: 2.4
            )
            return true
        } catch {
            showFeedback(
                "Autosave failed · Keep playing or save manually: \(error.localizedDescription)",
                tone: .caution,
                autoDismissAfter: nil
            )
            return false
        }
    }

    private func captureScenarioCheckpoints(
        reachedSince previousProgression: CityProgressionState?
    ) -> String? {
        let checkpoints = CityScenarioCheckpointDetector.newlyReached(
            from: previousProgression,
            to: state.progression
        )
        guard !checkpoints.isEmpty else { return nil }

        var failureMessage: String?
        for checkpoint in checkpoints {
            do {
                guard try saves.saveScenarioCheckpoint(
                    state,
                    id: checkpoint.id,
                    title: checkpoint.title
                ) != nil else {
                    showFeedback(
                        CityPersistenceFeedbackPresentation.scenarioCheckpointAlreadyExists(
                            title: checkpoint.title
                        ).message,
                        tone: .neutral,
                        autoDismissAfter: 3.2
                    )
                    continue
                }
                lastPersistedState = state
                lastPersistenceCheckpointKind = .scenario
                nextAutosaveTick = state.tick + Self.autosaveIntervalTicks
                showFeedback(
                    CityPersistenceFeedbackPresentation.scenarioCheckpoint(
                        state,
                        title: checkpoint.title
                    ).message,
                    tone: .positive,
                    autoDismissAfter: 3.2
                )
            } catch {
                failureMessage = "Scenario checkpoint failed · Keep playing or save manually: "
                    + error.localizedDescription
            }
        }
        return failureMessage
    }

    private func applyLoadedResult(_ result: SaveGameLoadResult) {
        var migration: SaveGameMigrationResult?
        var migrationError: Error?
        if result.isLegacy {
            do {
                migration = try saves.migrateLegacyCheckpoint(result)
            } catch {
                migrationError = error
            }
        }
        checkpointLibrary = nil
        checkpointLoadsByID.removeAll()
        checkpointEntriesByID.removeAll()
        checkpointSupportFeedback = nil
        speedBeforeCheckpointLibrary = nil
        clearBranchNamingState()
        state = result.state
        isPhotoModeEnabled = false
        speedBeforePhotoMode = nil
        overlayBeforePhotoMode = nil
        cityFocusBeforePhotoMode = false
        inspectorBeforePhotoMode = false
        objectivesBeforePhotoMode = false
        latestPhotoCaptureURL = nil
        previousObjectiveProgressByID.removeAll()
        lastPersistedState = result.state
        lastPersistenceCheckpointKind = if migration != nil || result.isMigration {
            .migration
        } else if result.isAutosave {
            .autosave
        } else if result.isNamedBranch {
            .branch
        } else if result.isScenarioCheckpoint {
            .scenario
        } else {
            .manual
        }
        nextAutosaveTick = state.tick + Self.autosaveIntervalTicks
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
        showObjectives = state.authoredScenario?.result == .active
        showCommandGuide = false
        showCityHandbook = false
        isCityFocusModeEnabled = false
        undoStates.removeAll()
        canUndo = false
        let scenario = CityAuthoredScenarioEvaluation.make(state: state)
        let brief = scenario == nil ? CityResumeBriefPresentation.make(analytics: analytics) : nil
        let persistenceFeedback = if let migration {
            CityPersistenceFeedbackPresentation.loadedLegacyMigration(
                state,
                migration: migration
            )
        } else if let migrationError {
            CityPersistenceFeedbackPresentation.legacyMigrationFailed(
                state,
                originalFileName: result.checkpointFileName,
                error: migrationError
            )
        } else if result.isMigration {
            CityPersistenceFeedbackPresentation.loadedMigration(state)
        } else if result.isAutosave {
            CityPersistenceFeedbackPresentation.loadedAutosave(state)
        } else if result.isNamedBranch {
            CityPersistenceFeedbackPresentation.loadedBranch(
                state,
                name: result.branchName ?? state.cityName
            )
        } else if result.isScenarioCheckpoint {
            CityPersistenceFeedbackPresentation.loadedScenarioCheckpoint(
                state,
                title: result.scenarioCheckpointTitle ?? "Scenario checkpoint"
            )
        } else {
            CityPersistenceFeedbackPresentation.loaded(
                state,
                recoveredFromBackup: result.recoveredFromBackup
            )
        }
        let loadedMessage = if let scenario, scenario.session.result == .active {
            persistenceFeedback.message + " · \(scenario.definition.title) · "
                + "\(scenario.daysRemaining) days remaining · \(scenario.adaptiveHint)"
        } else {
            persistenceFeedback.message
        }
        showFeedback(
            loadedMessage,
            tone: migrationError == nil ? .positive : .caution,
            autoDismissAfter: migrationError == nil && brief == nil && scenario == nil ? 3.2 : nil,
            resumeBrief: brief
        )
        soundFeedback.play(migrationError == nil ? .persistenceSucceeded : .actionRejected)
    }

    private func showInvalidQuicksaveFeedback() {
        showFeedback(
            "Saved checkpoint could not be verified · Original save files were preserved",
            tone: .caution,
            autoDismissAfter: nil
        )
        soundFeedback.play(.actionRejected)
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
        soundFeedback.play(.actionReversed)
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

    private func completeFoundationsLesson(for kind: BuildingKind) {
        switch kind {
        case .road:
            completeFoundationsLesson(.roads)
        case .residential, .commercial, .industrial:
            completeFoundationsLesson(.zoning)
        case .powerPlant, .waterTower:
            completeFoundationsLesson(.utilities)
        case .park, .fireStation, .policeStation, .school:
            completeFoundationsLesson(.services)
        default:
            break
        }
    }

    private func completeFoundationsLesson(_ lessonID: CityFoundationsLessonID) {
        guard foundationsGuidePresentation != nil else { return }
        var updated = foundationsGuideProgress
        guard updated.complete(lessonID) else { return }
        foundationsGuideProgress = updated
        if let playerDefaults {
            CityFoundationsGuidePersistence.write(updated, to: playerDefaults)
        }
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
