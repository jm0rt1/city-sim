import Combine
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: CityGameStore
    @AppStorage("hasSeenCitySimWelcome") private var hasSeenWelcome = false
    private let simulationClock = Timer.publish(every: 0.42, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            CitySceneView(store: store).ignoresSafeArea()

            VStack(spacing: 12) {
                TopHUDView(store: store)
                HStack(alignment: .top) {
                    if store.showObjectives { ObjectivesView(store: store).transition(.move(edge: .leading).combined(with: .opacity)) }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 10) {
                        OverlayPickerView(store: store)
                        if store.overlay != .none { OverlayLegendView(overlay: store.overlay) }
                        EventFeedView(store: store)
                    }
                }
                Spacer()
                if let feedback = store.lastFeedback {
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(GameTheme.accent)
                        Text(feedback).font(.callout.weight(.semibold))
                        Button { store.clearFeedback() } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(.thickMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
                        .transition(.scale.combined(with: .opacity))
                }
                BuildToolbarView(store: store)
            }
            .padding(14)

            if store.state.status != .playing { GameStatusOverlay(store: store) }
            if !hasSeenWelcome {
                WelcomeView {
                    withAnimation(.easeOut(duration: 0.24)) { hasSeenWelcome = true }
                }
                .transition(.opacity)
            }
        }
        .frame(minWidth: 1_100, minHeight: 720)
        .inspector(isPresented: $store.showInspector) {
            InspectorView(store: store)
                .inspectorColumnWidth(min: 270, ideal: 310, max: 380)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { withAnimation { store.showObjectives.toggle() } } label: { Label("Objectives", systemImage: "flag.checkered") }
                Button { store.showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.right") }
                Button { store.save() } label: { Label("Save", systemImage: "square.and.arrow.down") }
                Button { store.undoLastAction() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .disabled(!store.canUndo)
            }
        }
        .onReceive(simulationClock) { _ in store.pulse() }
    }
}
