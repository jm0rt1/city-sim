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

private struct CityHUDChromeFramePreference: PreferenceKey {
    static let defaultValue: [CityHUDChromeRegion: CGRect] = [:]

    static func reduce(
        value: inout [CityHUDChromeRegion: CGRect],
        nextValue: () -> [CityHUDChromeRegion: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

enum ObjectiveSurfacePresentation: Equatable {
    case hidden
    case expanded
    case compactSummary
}

@MainActor
final class CityFocusPointerShieldView: NSView {
    var traceLabel: String
    var action: () -> Void
    private(set) var monitorIsInstalled = false
    private var localMonitor: Any?
    private var ownsPointerSequence = false
    private var pointerDraggedOutside = false

    init(traceLabel: String, action: @escaping () -> Void) {
        self.traceLabel = traceLabel
        self.action = action
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
        trace(phase: "viewDidMoveToWindow")
    }

    override func layout() {
        super.layout()
        trace(phase: "layout")
    }

    func startMonitoringIfNeeded() {
        guard window != nil, localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handleLocalPointerEvent(event) ?? event
        }
        monitorIsInstalled = localMonitor != nil
        trace(phase: "monitorInstalled")
    }

    func stopMonitoring() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
        monitorIsInstalled = false
        ownsPointerSequence = false
        pointerDraggedOutside = false
    }

    func handleLocalPointerEvent(_ event: NSEvent) -> NSEvent? {
        trace(phase: "callback.pre", event: event)
        if ownsPointerSequence {
            switch event.type {
            case .leftMouseDragged:
                if !contains(event) {
                    pointerDraggedOutside = true
                }
                trace(phase: "callback.post.consumeDrag", event: event)
                return nil
            case .leftMouseUp:
                let shouldPerform = !pointerDraggedOutside && contains(event)
                ownsPointerSequence = false
                pointerDraggedOutside = false
                trace(
                    phase: shouldPerform ? "callback.post.perform" : "callback.post.cancel",
                    event: event
                )
                if shouldPerform {
                    action()
                }
                return nil
            case .leftMouseDown:
                trace(phase: "callback.post.consumeRepeatedDown", event: event)
                return nil
            default:
                trace(phase: "callback.post.passUnexpected", event: event)
                return event
            }
        }

        let exactWindow = event.window === window
        let isInside = contains(event)
        guard event.type == .leftMouseDown, exactWindow, isInside else {
            trace(phase: "callback.post.pass", event: event)
            return event
        }
        ownsPointerSequence = true
        pointerDraggedOutside = false
        trace(phase: "callback.post.own", event: event)
        return nil
    }

    private func contains(_ event: NSEvent) -> Bool {
        guard event.window === window else { return false }
        return bounds.contains(convert(event.locationInWindow, from: nil))
    }

    #if DEBUG
    private func trace(phase: String, event: NSEvent? = nil) {
        guard let path = ProcessInfo.processInfo.environment["CITYSIM_FOCUS_POINTER_TRACE_PATH"],
              !path.isEmpty else { return }
        let eventPoint = event.map { convert($0.locationInWindow, from: nil) }
        let eventWindowObject = event?.window?.windowNumber ?? -1
        let line = [
            "label=\(traceLabel)",
            "phase=\(phase)",
            "eventType=\(event.map { String(describing: $0.type) } ?? "none")",
            "eventWindowNumber=\(event?.windowNumber ?? -1)",
            "eventWindowObject=\(eventWindowObject)",
            "viewWindowNumber=\(window?.windowNumber ?? -1)",
            "eventLocationInWindow=\(event.map { NSStringFromPoint($0.locationInWindow) } ?? "none")",
            "convertedPoint=\(eventPoint.map(NSStringFromPoint) ?? "none")",
            "bounds=\(NSStringFromRect(bounds))",
            "frame=\(NSStringFromRect(frame))",
            "windowRect=\(NSStringFromRect(convert(bounds, to: nil)))",
            "windowFrame=\(NSStringFromRect(window?.frame ?? .zero))",
            "contains=\(event.map(contains) ?? false)",
            "owned=\(ownsPointerSequence)",
            "draggedOutside=\(pointerDraggedOutside)",
            "monitorInstalled=\(monitorIsInstalled)"
        ].joined(separator: " ")
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            fileManager.createFile(atPath: path, contents: nil)
        }
        guard let handle = FileHandle(forWritingAtPath: path) else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((line + "\n").utf8))
        } catch {
            // The trace is task-owned diagnostics only and must never affect input.
        }
    }
    #else
    private func trace(phase: String, event: NSEvent? = nil) {}
    #endif
}

@MainActor
struct CityFocusPointerShield: NSViewRepresentable {
    let traceLabel: String
    let action: () -> Void

    func makeNSView(context: Context) -> CityFocusPointerShieldView {
        CityFocusPointerShieldView(traceLabel: traceLabel, action: action)
    }

    func updateNSView(_ nsView: CityFocusPointerShieldView, context: Context) {
        nsView.traceLabel = traceLabel
        nsView.action = action
    }

    static func dismantleNSView(_ nsView: CityFocusPointerShieldView, coordinator: ()) {
        nsView.stopMonitoring()
    }
}

struct ContentView: View {
    @ObservedObject var store: CityGameStore
    @AppStorage("hasSeenCitySimWelcome") private var hasSeenWelcome = false
    @AppStorage("reduceGameMotion") private var gameReduceMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var hudChromeFrames = CityHUDChromeFrames()
    @State private var retainedFocusCityViewportInsets: CityMapViewportInsets?

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
                    if store.isCityFocusModeEnabled {
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
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        Button { store.perform(.undo) } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(!store.canPerform(.undo))
                    }
                }
            }
        }
        .onAppear { synchronizeWelcomePolicy() }
        .onChange(of: hasSeenWelcome) { _, _ in synchronizeWelcomePolicy() }
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
        let measuredTop = chromeFrames.top.isEmpty ? 0 : chromeFrames.top.maxY + 10
        let measuredBottom = chromeFrames.bottom.isEmpty ? 0 : windowSize.height - chromeFrames.bottom.minY + 10
        return CityMapViewportInsets(
            top: max(fallbackTop, measuredTop),
            leading: edgePadding + 10,
            bottom: max(fallbackBottom, measuredBottom),
            trailing: edgePadding + 10
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
            let viewportInsets = Self.resolvedMapViewportInsets(
                measured: measuredViewportInsets,
                retainedForFocusCity: retainedFocusCityViewportInsets,
                focusCity: store.isCityFocusModeEnabled,
                bottomChromeIsVisible: !hudChromeFrames.bottom.isEmpty
            )
            ZStack {
                CitySceneView(store: store, viewportInsets: viewportInsets).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 10) {
                    if store.isCityFocusModeEnabled {
                        FocusCityHUDView(store: store, compact: compact)
                            .background(chromeFrameReader(.top))
                            .transition(.opacity)
                    } else {
                        TopHUDView(store: store, compact: compact)
                            .background(chromeFrameReader(.top))

                        HStack(alignment: .top) {
                            switch Self.objectiveSurfacePresentation(
                                compact: compact,
                                showObjectives: store.showObjectives,
                                showInspector: store.showInspector
                            ) {
                            case .hidden:
                                EmptyView()
                            case .expanded:
                                ObjectivesView(store: store)
                                    .transition(GameTheme.transition(edge: .leading, reduceMotion: reduceMotion))
                            case .compactSummary:
                                ObjectiveSummaryView(store: store)
                                    .transition(GameTheme.transition(edge: .leading, reduceMotion: reduceMotion))
                                    .accessibilityHint("Close command-center details to expand all objectives")
                            }
                            Spacer(minLength: 8)
                            EventFeedView(store: store, compact: compact)
                        }
                    }

                    Spacer(minLength: 8)

                    if let feedback = store.lastFeedback {
                        HStack(spacing: 9) {
                            Image(systemName: feedbackSymbol)
                                .foregroundStyle(feedbackColor)
                            Text(feedback).font(.callout.weight(.semibold))
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
                        .background(.thickMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(store.lastFeedbackTone == .caution ? "Action blocked" : "Action update")
                        .accessibilityValue(feedback)
                    }

                    if store.overlay != .none {
                        HStack {
                            Spacer()
                            OverlayLegendView(overlay: store.overlay)
                        }
                        .transition(.opacity)
                    }

                    if !store.isCityFocusModeEnabled {
                        BuildToolbarView(store: store, compact: compact)
                            .frame(maxWidth: compact ? .infinity : 1_120)
                            .background(chromeFrameReader(.bottom))
                            .transition(.opacity)
                    }
                }
                .padding(compact ? GameTheme.compactPadding : GameTheme.regularPadding)

            }
            .coordinateSpace(name: "city.game.surface")
            .onChange(of: store.isCityFocusModeEnabled) { _, enabled in
                if enabled {
                    retainedFocusCityViewportInsets = measuredViewportInsets
                }
            }
            .onPreferenceChange(CityHUDChromeFramePreference.self) { frames in
                let updated = CityHUDChromeFrames(
                    top: frames[.top] ?? .zero,
                    bottom: frames[.bottom] ?? .zero
                )
                if updated != hudChromeFrames { hudChromeFrames = updated }
                if !store.isCityFocusModeEnabled, !updated.bottom.isEmpty {
                    retainedFocusCityViewportInsets = nil
                }
            }
        }
    }

    private func chromeFrameReader(_ region: CityHUDChromeRegion) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: CityHUDChromeFramePreference.self,
                value: [region: proxy.frame(in: .named("city.game.surface"))]
            )
        }
    }

    private func synchronizeWelcomePolicy() {
        if hasSeenWelcome {
            _ = store.dismissBlockingModal(.welcome)
        } else {
            store.presentBlockingModal(.welcome)
        }
    }
}
