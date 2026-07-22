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

struct ContentView: View {
    @ObservedObject var store: CityGameStore
    @AppStorage("hasSeenCitySimWelcome") private var hasSeenWelcome = false
    @AppStorage("reduceGameMotion") private var gameReduceMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var hudChromeFrames = CityHUDChromeFrames()

    private var reduceMotion: Bool { systemReduceMotion || gameReduceMotion }

    var body: some View {
        GeometryReader { proxy in
            let compact = Self.isCompactLayout(proxy.size)
            gameContent(compact: compact)
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(ProofWindowConfigurator())
        .toolbar {
            if !Self.suppressesGameSurface(for: store.commandPolicy) {
                ToolbarItemGroup(placement: .primaryAction) {
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

    static func suppressesGameSurface(for commandPolicy: CityCommandPolicy) -> Bool {
        commandPolicy != .enabled
    }

    static func mapViewportInsets(
        windowSize: CGSize,
        compact: Bool,
        chromeFrames: CityHUDChromeFrames
    ) -> CityMapViewportInsets {
        let edgePadding = compact ? GameTheme.compactPadding : GameTheme.regularPadding
        let fallbackTop: CGFloat = compact ? 126 : 82
        let fallbackBottom: CGFloat = compact ? 132 : 126
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
                .allowsHitTesting(!Self.suppressesGameSurface(for: store.commandPolicy))
                .accessibilityHidden(Self.suppressesGameSurface(for: store.commandPolicy))

            if store.commandPolicy == .blocked(.welcome) {
                WelcomeView {
                    withAnimation(GameTheme.animation(reduceMotion: reduceMotion)) {
                        if store.dismissBlockingModal(.welcome) {
                            hasSeenWelcome = true
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(GameTheme.animation(reduceMotion: reduceMotion), value: store.showInspector)
        .animation(GameTheme.animation(reduceMotion: reduceMotion), value: store.showObjectives)
    }

    @ViewBuilder
    private func gameSurface(compact: Bool) -> some View {
        GeometryReader { mapProxy in
            let viewportInsets = Self.mapViewportInsets(
                windowSize: mapProxy.size,
                compact: compact,
                chromeFrames: hudChromeFrames
            )
            ZStack {
                CitySceneView(store: store, viewportInsets: viewportInsets).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 10) {
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
                }

                if store.overlay != .none {
                    HStack {
                        Spacer()
                        OverlayLegendView(overlay: store.overlay)
                    }
                    .transition(.opacity)
                }

                    BuildToolbarView(store: store, compact: compact)
                        .frame(maxWidth: compact ? .infinity : 1_120)
                        .background(chromeFrameReader(.bottom))
                }
                .padding(compact ? GameTheme.compactPadding : GameTheme.regularPadding)

                if store.state.status != .playing {
                    GameStatusOverlay(store: store)
                }
            }
            .coordinateSpace(name: "city.game.surface")
            .onPreferenceChange(CityHUDChromeFramePreference.self) { frames in
                let updated = CityHUDChromeFrames(
                    top: frames[.top] ?? .zero,
                    bottom: frames[.bottom] ?? .zero
                )
                if updated != hudChromeFrames { hudChromeFrames = updated }
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
