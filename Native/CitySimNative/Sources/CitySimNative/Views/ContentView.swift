import SwiftUI

struct ContentView: View {
    @ObservedObject var store: CityGameStore
    @AppStorage("hasSeenCitySimWelcome") private var hasSeenWelcome = false
    @AppStorage("reduceGameMotion") private var gameReduceMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var reduceMotion: Bool { systemReduceMotion || gameReduceMotion }

    var body: some View {
        GeometryReader { proxy in
            let compact = Self.isCompactLayout(proxy.size)
            gameContent(compact: compact)
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(ProofWindowConfigurator())
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    withAnimation(GameTheme.animation(reduceMotion: reduceMotion)) {
                        store.showObjectives.toggle()
                    }
                } label: {
                    Label("Objectives", systemImage: "flag.checkered")
                }
                Button { store.toggleInspector() } label: {
                    Label("Command Center", systemImage: "rectangle.bottomthird.inset.filled")
                }
                Button { store.save() } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                Button { store.undoLastAction() } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!store.canUndo)
            }
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
        .onExitCommand { store.cancelInteraction() }
    }

    static func isCompactLayout(_ size: CGSize) -> Bool {
        size.width < 1_100 || size.height < 700
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
            CitySceneView(store: store).ignoresSafeArea()

            VStack(spacing: compact ? 8 : 10) {
                TopHUDView(store: store, compact: compact)

                HStack(alignment: .top) {
                    if store.showObjectives {
                        ObjectivesView(store: store)
                            .transition(GameTheme.transition(edge: .leading, reduceMotion: reduceMotion))
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
                        Button { store.clearFeedback() } label: {
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
            }
            .padding(compact ? GameTheme.compactPadding : GameTheme.regularPadding)

            if store.state.status != .playing {
                GameStatusOverlay(store: store)
            }
            if !hasSeenWelcome {
                WelcomeView {
                    withAnimation(GameTheme.animation(reduceMotion: reduceMotion)) {
                        hasSeenWelcome = true
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(GameTheme.animation(reduceMotion: reduceMotion), value: store.showInspector)
        .animation(GameTheme.animation(reduceMotion: reduceMotion), value: store.showObjectives)
    }
}
