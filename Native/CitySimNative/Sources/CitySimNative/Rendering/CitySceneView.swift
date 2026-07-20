import SpriteKit
import SwiftUI

@MainActor
struct CitySceneView: NSViewRepresentable {
    @ObservedObject var store: CityGameStore
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage("reduceGameMotion") private var reduceGameMotion = false

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeNSView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        let diagnosticsEnabled = ProcessInfo.processInfo.arguments.contains("--renderer-diagnostics") ||
            UserDefaults.standard.bool(forKey: "showRendererDiagnostics")
        view.showsFPS = diagnosticsEnabled
        view.showsNodeCount = diagnosticsEnabled
        view.showsDrawCount = diagnosticsEnabled
        let scene = CityScene(size: CGSize(width: 1280, height: 800))
        scene.onPrimaryAction = { [weak coordinator = context.coordinator] coordinate in coordinator?.store.primaryAction(at: coordinate) }
        scene.onSecondaryAction = { [weak coordinator = context.coordinator] coordinate in coordinator?.store.secondaryAction(at: coordinate) }
        scene.onCommandAction = { [weak coordinator = context.coordinator] command in
            coordinator?.store.perform(command)
        }
        scene.allowsCommand = { [weak coordinator = context.coordinator] command in
            coordinator?.store.commandPolicy.allows(command) ?? false
        }
        view.presentScene(scene)
        DispatchQueue.main.async { [weak view] in
            view?.window?.acceptsMouseMovedEvents = true
        }
        context.coordinator.scene = scene
        return view
    }

    func updateNSView(_ view: SKView, context: Context) {
        context.coordinator.store = store
        view.window?.acceptsMouseMovedEvents = true
        guard let scene = context.coordinator.scene else { return }
        scene.resize(to: view.bounds.size)
        scene.reducedMotion = accessibilityReduceMotion || reduceGameMotion
        scene.render(
            state: store.state,
            overlay: store.overlay,
            selection: store.selectedCoordinate,
            interactionMode: store.interactionMode
        )
    }

    final class Coordinator {
        var store: CityGameStore
        weak var scene: CityScene?
        init(store: CityGameStore) { self.store = store }
    }
}
