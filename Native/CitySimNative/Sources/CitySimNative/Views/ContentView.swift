import AppKit
import SwiftUI

struct CityHUDChromeFrames: Equatable {
    var top = CGRect.zero
    var bottom = CGRect.zero
}

private enum CityHUDChromeRegion: Hashable {
    case top
    case bottom
}

enum ObjectiveSurfacePresentation: Equatable {
    case hidden
    case expanded
    case compactSummary
}

enum ContextualGuidancePresentation: Equatable {
    case hidden
    case objectives
    case activity
}

@MainActor
final class CityFocusPointerTransitionView: NSView {
    let pointerTransitionGate: CityMapPointerTransitionGate
    private(set) var monitorIsInstalled = false
    private var localMonitor: Any?
    private var ownsPointerSequence = false

    init(pointerTransitionGate: CityMapPointerTransitionGate) {
        self.pointerTransitionGate = pointerTransitionGate
        super.init(frame: .zero)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // The SwiftUI Button remains the semantic, FKA, focus-ring, and AX
        // control. This view exists only to install the window-scoped pointer
        // event boundary.
        nil
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow !== window {
            stopMonitoring()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startMonitoringIfNeeded()
    }

    func startMonitoringIfNeeded() {
        guard window != nil, localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handleLocalPointerEvent(event) ?? event
        }
        monitorIsInstalled = localMonitor != nil
    }

    func stopMonitoring() {
        if ownsPointerSequence {
            pointerTransitionGate.cancel()
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
        monitorIsInstalled = false
        ownsPointerSequence = false
    }

    func handleLocalPointerEvent(_ event: NSEvent) -> NSEvent? {
        if ownsPointerSequence {
            switch event.type {
            case .leftMouseDragged:
                if !contains(event) {
                    ownsPointerSequence = false
                    pointerTransitionGate.cancel()
                }
                return event
            case .leftMouseUp:
                if !contains(event) {
                    pointerTransitionGate.cancel()
                }
                ownsPointerSequence = false
                return event
            case .leftMouseDown:
                return event
            default:
                return event
            }
        }

        guard event.type == .leftMouseDown,
              let window,
              eventMatchesWindow(event, window: window),
              contains(event) else { return event }
        ownsPointerSequence = true
        pointerTransitionGate.begin(window: window, anchor: event.locationInWindow)
        return event
    }

    private func contains(_ event: NSEvent) -> Bool {
        guard let window, eventMatchesWindow(event, window: window) else { return false }
        return bounds.contains(convert(event.locationInWindow, from: nil))
    }

    private func eventMatchesWindow(_ event: NSEvent, window: NSWindow) -> Bool {
        if let eventWindow = event.window {
            return eventWindow === window || eventWindow.windowNumber == window.windowNumber
        }
        return event.windowNumber == window.windowNumber
    }
}

@MainActor
struct CityFocusPointerTransitionMonitor: NSViewRepresentable {
    let pointerTransitionGate: CityMapPointerTransitionGate

    func makeNSView(context: Context) -> CityFocusPointerTransitionView {
        CityFocusPointerTransitionView(pointerTransitionGate: pointerTransitionGate)
    }

    func updateNSView(_ nsView: CityFocusPointerTransitionView, context: Context) {}

    static func dismantleNSView(_ nsView: CityFocusPointerTransitionView, coordinator: ()) {
        nsView.stopMonitoring()
    }
}

struct ContentView: View {
    @ObservedObject var store: CityGameStore
    private let startupResumeEnabled: Bool
    private let onChromeFrames: ((CityHUDChromeFrames) -> Void)?
    @StateObject private var pointerTransitionGate = CityMapPointerTransitionGate()
    @AppStorage(CityPlayerPreferenceKey.hasSeenWelcome) private var hasSeenWelcome = false
    @AppStorage(CityPlayerPreferenceKey.reduceMotion) private var gameReduceMotion = false
    @AppStorage(CityPlayerPreferenceKey.reduceTransparency) private var gameReduceTransparency = false
    @AppStorage(CityPlayerPreferenceKey.increaseContrast) private var gameIncreaseContrast = false
    @AppStorage(CityPlayerPreferenceKey.differentiateWithoutColor)
    private var gameDifferentiateWithoutColor = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor)
    private var systemDifferentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var systemContrast
    @State private var hudChromeFrames = CityHUDChromeFrames()
    @State private var focusCityChromeFrame = CGRect.zero

    init(
        store: CityGameStore,
        startupResumeEnabled: Bool = false,
        onChromeFrames: ((CityHUDChromeFrames) -> Void)? = nil
    ) {
        self.store = store
        self.startupResumeEnabled = startupResumeEnabled
        self.onChromeFrames = onChromeFrames
    }

    private var reduceMotion: Bool { systemReduceMotion || gameReduceMotion }

    var body: some View {
        GeometryReader { proxy in
            let compact = Self.isCompactLayout(proxy.size)
            gameContent(compact: compact)
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(ProofWindowConfigurator())
        .toolbar {
            if !Self.suppressesGameSurface(for: store.commandPolicy, status: store.state.status) {
                ToolbarItemGroup(placement: .primaryAction) {
                    if store.isPhotoModeEnabled {
                        Button { store.perform(.capturePhoto) } label: {
                            Label("Capture PNG", systemImage: "camera.fill")
                        }
                        Button { store.perform(.togglePhotoMode) } label: {
                            Label("Exit Photo Mode", systemImage: "xmark.circle")
                        }
                    } else if store.isCityFocusModeEnabled {
                        Button { store.perform(.toggleCityFocus) } label: {
                            Label("Exit Focus City", systemImage: "viewfinder.circle")
                        }
                        .help("Restore the full command surface without changing the active target")
                        .accessibilityIdentifier("toolbar.focus-city.exit")
                    } else {
                        Button {
                            withAnimation(GameTheme.animation(reduceMotion: reduceMotion)) {
                                _ = store.perform(.toggleObjectives)
                            }
                        } label: {
                            Label("Objectives", systemImage: "flag.checkered")
                        }
                        Button { store.perform(.toggleCommandCenter) } label: {
                            Label("Command Center", systemImage: "rectangle.bottomthird.inset.filled")
                        }
                        Button { store.perform(.openCommandGuide) } label: {
                            Label("Commands", systemImage: "command.square")
                        }
                        Button { store.perform(.saveCity) } label: {
                            Label("Save", systemImage: store.persistenceStatus.symbol)
                        }
                        .help("Save city · \(store.persistenceStatus.help)")
                        Button { store.perform(.undo) } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(!store.canPerform(.undo))
                    }
                }
            }
        }
        .onAppear {
            synchronizeWelcomePolicy()
            synchronizeStartupResumeOffer()
        }
        .onChange(of: hasSeenWelcome) { _, _ in
            synchronizeWelcomePolicy()
            synchronizeStartupResumeOffer()
        }
        .onChange(of: store.commandPolicy) { _, _ in
            synchronizeWelcomePolicy()
        }
        .onChange(of: store.state.status) { _, _ in
            synchronizeWelcomePolicy()
        }
        .onChange(of: store.sessionReplacementConfirmation != nil) { _, _ in
            synchronizeWelcomePolicy()
        }
        .onChange(of: store.newRegionSetup != nil) { _, _ in
            synchronizeWelcomePolicy()
        }
        .onChange(of: store.showCommandGuide) { _, _ in
            synchronizeWelcomePolicy()
        }
        .onChange(of: store.showCityHandbook) { _, _ in
            synchronizeWelcomePolicy()
        }
        .task(id: hasSeenWelcome) {
            guard hasSeenWelcome else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 420_000_000)
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                store.pulse()
            }
        }
        .onExitCommand { store.perform(.cancelInteraction) }
        .sheet(isPresented: $store.showCommandGuide) {
            CommandGuideView(store: store)
        }
        .sheet(isPresented: $store.showCityHandbook) {
            CityHandbookView {
                store.showCityHandbook = false
            }
        }
        .confirmationDialog(
            store.sessionReplacementConfirmation?.title ?? "Replace the Current City?",
            isPresented: Binding(
                get: { store.sessionReplacementConfirmation != nil },
                set: { isPresented in
                    guard !isPresented else { return }
                    // Confirmation actions run in the same event that dismisses the dialog.
                    // Defer implicit dismissal so an explicit destructive action wins first.
                    DispatchQueue.main.async {
                        store.cancelSessionReplacement()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(
                store.sessionReplacementConfirmation?.destructiveActionTitle ?? "Replace City",
                role: store.sessionReplacementConfirmation?.action == .loadQuicksave
                    ? .destructive
                    : nil
            ) {
                store.confirmSessionReplacement()
            }
            Button(
                store.sessionReplacementConfirmation?.cancelActionTitle ?? "Keep Current City",
                role: .cancel
            ) {
                store.cancelSessionReplacement()
            }
        } message: {
            Text(store.sessionReplacementConfirmation?.message ?? "")
        }
        .cityAccessibilityAppearance(
            CityAccessibilityAppearance(
                reduceTransparency: CityPlayerPreferenceSnapshot.resolved(
                    playerOverride: gameReduceTransparency,
                    systemPreference: systemReduceTransparency
                ),
                increaseContrast: CityPlayerPreferenceSnapshot.resolved(
                    playerOverride: gameIncreaseContrast,
                    systemPreference: systemContrast == .increased
                ),
                differentiateWithoutColor: CityPlayerPreferenceSnapshot.resolved(
                    playerOverride: gameDifferentiateWithoutColor,
                    systemPreference: systemDifferentiateWithoutColor
                )
            )
        )
    }

    static func isCompactLayout(_ size: CGSize) -> Bool {
        size.width < 1_100 || size.height < 700
    }

    static func suppressesGameSurface(
        for commandPolicy: CityCommandPolicy,
        status: GameStatus = .playing
    ) -> Bool {
        commandPolicy != .enabled || status != .playing
    }

    static func mapViewportInsets(
        windowSize: CGSize,
        compact: Bool,
        chromeFrames: CityHUDChromeFrames
    ) -> CityMapViewportInsets {
        let edgePadding = compact ? GameTheme.compactPadding : GameTheme.regularPadding
        let fallbackTop: CGFloat = 136
        let fallbackBottom: CGFloat = 116
        let measuredTop = chromeFrames.top.maxY + 10
        let measuredBottom = windowSize.height - chromeFrames.bottom.minY + 10
        return CityMapViewportInsets(
            top: chromeFrames.top.isEmpty ? fallbackTop : measuredTop,
            leading: edgePadding + 10,
            bottom: chromeFrames.bottom.isEmpty ? fallbackBottom : measuredBottom,
            trailing: edgePadding + 10
        )
    }

    static func focusCityViewportInsets(
        compact: Bool,
        chromeFrame: CGRect
    ) -> CityMapViewportInsets {
        let fallbackTop = (compact ? GameTheme.compactPadding : GameTheme.regularPadding)
            + (compact ? FocusCityHUDView.compactMaximumHeight : FocusCityHUDView.regularMaximumHeight)
            + 10
        return CityMapViewportInsets(
            top: chromeFrame.isEmpty ? fallbackTop : chromeFrame.maxY + 10,
            leading: 0,
            bottom: 0,
            trailing: 0
        )
    }

    static func interactiveMapHeight(
        windowHeight: CGFloat,
        chromeFrames: CityHUDChromeFrames
    ) -> CGFloat {
        let topBoundary = chromeFrames.top.isEmpty ? 0 : chromeFrames.top.maxY
        let bottomBoundary = chromeFrames.bottom.isEmpty ? windowHeight : chromeFrames.bottom.minY
        return max(0, bottomBoundary - topBoundary)
    }

    static func resolvedMapViewportInsets(
        measured: CityMapViewportInsets,
        retainedForFocusCity: CityMapViewportInsets?,
        focusCity: Bool,
        bottomChromeIsVisible: Bool
    ) -> CityMapViewportInsets {
        guard let retainedForFocusCity,
              focusCity || !bottomChromeIsVisible else {
            return measured
        }
        return retainedForFocusCity
    }

    static func objectiveSurfacePresentation(
        compact: Bool,
        showObjectives: Bool,
        showInspector: Bool
    ) -> ObjectiveSurfacePresentation {
        guard showObjectives else { return .hidden }
        return compact && showInspector ? .compactSummary : .expanded
    }

    static func contextualGuidancePresentation(
        showObjectives: Bool,
        showInspector: Bool,
        hasActivity: Bool
    ) -> ContextualGuidancePresentation {
        guard !showInspector else { return .hidden }
        if showObjectives { return .objectives }
        return hasActivity ? .activity : .hidden
    }

    private var feedbackSymbol: String {
        switch store.lastFeedbackTone {
        case .positive: "checkmark.circle.fill"
        case .neutral: "info.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        }
    }

    private var feedbackColor: Color {
        switch store.lastFeedbackTone {
        case .positive: GameTheme.accent
        case .neutral: GameTheme.information
        case .caution: GameTheme.warning
        }
    }

    @ViewBuilder
    private func gameContent(compact: Bool) -> some View {
        ZStack {
            gameSurface(compact: compact)
                .allowsHitTesting(!Self.suppressesGameSurface(
                    for: store.commandPolicy,
                    status: store.state.status
                ))
                .accessibilityHidden(Self.suppressesGameSurface(
                    for: store.commandPolicy,
                    status: store.state.status
                ))

            if store.commandPolicy == .blocked(.welcome) {
                WelcomeView {
                    withAnimation(GameTheme.animation(reduceMotion: reduceMotion)) {
                        if store.dismissBlockingModal(.welcome) {
                            hasSeenWelcome = true
                        }
                    }
                }
                .transition(.opacity)
            } else if let offer = store.startupResumeOffer {
                StartupResumeView(
                    presentation: offer,
                    resumeAction: { store.resumeStartupCity() },
                    startFreshAction: { store.startFreshFromStartupOffer() }
                )
                .transition(.opacity)
            } else if let benchmark = store.benchmarkSession {
                CityBenchmarkView(
                    session: benchmark,
                    runAction: { _ = store.startBenchmark() },
                    cancelRunAction: { _ = store.cancelBenchmarkRun() },
                    exportAction: { _ = store.exportBenchmarkReport() },
                    backAction: { _ = store.returnToModeChooserFromBenchmark() },
                    doneAction: { _ = store.closeBenchmark() }
                )
                .transition(.opacity)
            } else if let setup = store.newRegionSetup {
                NewRegionSetupView(
                    presentation: setup,
                    draft: store.newRegionDraft,
                    updateExperience: store.updateNewRegionExperience,
                    updateCityName: store.updateNewRegionCityName,
                    updateSeed: store.updateNewRegionSeed,
                    updateStartingResources: store.updateNewRegionStartingResources,
                    updateSandboxEconomy: store.updateNewRegionSandboxEconomy,
                    updateSandboxIncidents: store.updateNewRegionSandboxIncidents,
                    updateSandboxUnlimitedFunds: store.updateNewRegionSandboxUnlimitedFunds,
                    createAction: { _ = store.createNewRegion() },
                    cancelAction: { _ = store.cancelNewRegionSetup() }
                )
                .transition(.opacity)
            } else if let library = store.checkpointLibrary {
                CheckpointLibraryView(
                    presentation: library,
                    supportFeedback: store.checkpointSupportFeedback,
                    selectAction: { _ = store.selectCheckpoint($0) },
                    branchAction: { _ = store.beginBranchNaming(for: $0) },
                    exportSupportReportAction: {
                        _ = store.exportCheckpointSupportReport(for: $0)
                    },
                    cancelAction: { store.cancelCheckpointLibrary() }
                )
                .transition(.opacity)
            } else if let branchNaming = store.branchNaming {
                BranchNamingView(
                    presentation: branchNaming,
                    name: store.branchNameDraft,
                    error: store.branchNameError,
                    canCreate: store.canCreateBranch,
                    updateName: store.updateBranchNameDraft,
                    createAction: { _ = store.createNamedBranch() },
                    cancelAction: { store.cancelBranchNaming() }
                )
                .transition(.opacity)
            } else if store.state.status != .playing {
                GameStatusOverlay(store: store)
                    .transition(.opacity)
            }
        }
        .animation(GameTheme.animation(reduceMotion: reduceMotion), value: store.showInspector)
        .animation(GameTheme.animation(reduceMotion: reduceMotion), value: store.showObjectives)
        .animation(GameTheme.animation(reduceMotion: reduceMotion), value: store.isCityFocusModeEnabled)
    }

    @ViewBuilder
    private func gameSurface(compact: Bool) -> some View {
        GeometryReader { mapProxy in
            let measuredViewportInsets = Self.mapViewportInsets(
                windowSize: mapProxy.size,
                compact: compact,
                chromeFrames: hudChromeFrames
            )
            let focusCityInsets = Self.focusCityViewportInsets(
                compact: compact,
                chromeFrame: focusCityChromeFrame
            )
            let retainedFocusInsets = store.isCityFocusModeEnabled || !focusCityChromeFrame.isEmpty
                ? focusCityInsets
                : nil
            let resolvedViewportInsets = Self.resolvedMapViewportInsets(
                measured: measuredViewportInsets,
                retainedForFocusCity: retainedFocusInsets,
                focusCity: store.isCityFocusModeEnabled,
                bottomChromeIsVisible: !hudChromeFrames.bottom.isEmpty
            )
            let viewportInsets = store.isPhotoModeEnabled ? CityMapViewportInsets.zero : resolvedViewportInsets
            ZStack {
                CitySceneView(
                    store: store,
                    viewportInsets: viewportInsets,
                    pointerTransitionGate: pointerTransitionGate
                )
                .ignoresSafeArea()

                if store.isPhotoModeEnabled {
                    PhotoModeHUDView(store: store, compact: compact)
                        .transition(.opacity)
                } else {
                VStack(spacing: compact ? 8 : 4) {
                    if store.isCityFocusModeEnabled {
                        FocusCityHUDView(
                            store: store,
                            compact: compact,
                            pointerTransitionGate: pointerTransitionGate
                        )
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .named("city.game.surface"))
                            } action: { frame in
                                recordChromeFrame(frame, in: .top)
                            }
                            .transition(.opacity)
                    } else {
                        TopHUDView(store: store, compact: compact)
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .named("city.game.surface"))
                            } action: { frame in
                                recordChromeFrame(frame, in: .top)
                            }

                        HStack(alignment: .top) {
                            switch Self.contextualGuidancePresentation(
                                showObjectives: store.showObjectives,
                                showInspector: store.showInspector,
                                hasActivity: !store.messageSummaries.isEmpty
                            ) {
                            case .hidden:
                                EmptyView()
                            case .objectives:
                                ObjectivesView(store: store)
                                    .transition(GameTheme.transition(edge: .leading, reduceMotion: reduceMotion))
                            case .activity:
                                Spacer(minLength: 8)
                                EventFeedView(store: store, compact: compact)
                                    .opacity(compact ? 1 : 0.78)
                                    .scaleEffect(compact ? 1 : 0.88, anchor: .topTrailing)
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    if let feedback = store.lastFeedback {
                        HStack(spacing: 9) {
                            Image(systemName: feedbackSymbol)
                                .foregroundStyle(feedbackColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feedback).font(.callout.weight(.semibold))
                                if let brief = store.resumeBrief {
                                    Text(brief.compactText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                }
                            }
                            if let command = store.resumeBrief?.command {
                                Button(store.resumeBrief?.nextAction ?? "Continue") {
                                    store.performResumeBriefAction()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(!store.canPerform(command))
                                .accessibilityHint("Opens the diagnosed next step for the loaded city")
                            }
                            Button { store.perform(.dismissFeedback) } label: {
                                Image(systemName: "xmark")
                                    .frame(width: GameTheme.controlMinimum, height: GameTheme.controlMinimum)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Dismiss action message")
                        }
                        .padding(.leading, 14)
                        .padding(.trailing, 4)
                        .cityPanelBackground(.thick, in: Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(store.lastFeedbackTone == .caution ? "Action blocked" : "Action update")
                        .accessibilityValue(
                            store.resumeBrief?.accessibilitySummary ?? feedback
                        )
                    }

                    if !store.isCityFocusModeEnabled {
                        VStack(spacing: compact ? 4 : 6) {
                            OverlayDiagnosticsPaletteView(store: store, compact: compact)
                            BuildToolbarView(
                                store: store,
                                compact: compact,
                                pointerTransitionGate: pointerTransitionGate
                            )
                        }
                            .frame(maxWidth: compact ? .infinity : 1_120)
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .named("city.game.surface"))
                            } action: { frame in
                                recordChromeFrame(frame, in: .bottom)
                            }
                            .transition(.opacity)
                    }
                }
                .padding(compact ? GameTheme.compactPadding : 8)
                }

            }
            .coordinateSpace(name: "city.game.surface")
            .onChange(of: store.isCityFocusModeEnabled) { _, enabled in
                if enabled {
                    focusCityChromeFrame = .zero
                    hudChromeFrames.bottom = .zero
                }
            }
            .onChange(of: store.isPhotoModeEnabled) { _, enabled in
                if enabled {
                    focusCityChromeFrame = .zero
                    hudChromeFrames = CityHUDChromeFrames()
                }
            }
            .onDisappear {
                pointerTransitionGate.cancel()
            }
        }
    }

    private func recordChromeFrame(_ frame: CGRect, in region: CityHUDChromeRegion) {
        guard !frame.isEmpty, !frame.isInfinite, !frame.isNull else { return }
        if region == .bottom, store.isCityFocusModeEnabled { return }

        var updated = hudChromeFrames
        switch region {
        case .top:
            updated.top = frame
            if store.isCityFocusModeEnabled {
                focusCityChromeFrame = frame
            }
        case .bottom:
            updated.bottom = frame
        }
        if updated != hudChromeFrames {
            hudChromeFrames = updated
            onChromeFrames?(updated)
        }
        if region == .bottom, !store.isCityFocusModeEnabled {
            focusCityChromeFrame = .zero
        }
    }

    private func synchronizeWelcomePolicy() {
        if hasSeenWelcome {
            _ = store.dismissBlockingModal(.welcome)
        } else if store.commandPolicy == .enabled,
                  store.state.status == .playing,
                  store.sessionReplacementConfirmation == nil,
                  store.newRegionSetup == nil,
                  !store.showCommandGuide,
                  !store.showCityHandbook {
            store.presentBlockingModal(.welcome)
        }
    }

    private func synchronizeStartupResumeOffer() {
        guard startupResumeEnabled, hasSeenWelcome else { return }
        store.prepareStartupResumeOffer()
    }
}
