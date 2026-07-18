import SpriteKit
import SwiftUI

@MainActor
struct CitySceneView: NSViewRepresentable {
    @ObservedObject var store: CityGameStore

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeNSView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        view.showsFPS = false
        view.showsNodeCount = false
        let scene = CityScene(size: CGSize(width: 1280, height: 800))
        scene.onPrimaryAction = { [weak coordinator = context.coordinator] coordinate in coordinator?.store.primaryAction(at: coordinate) }
        scene.onSecondaryAction = { [weak coordinator = context.coordinator] coordinate in coordinator?.store.demolish(at: coordinate) }
        view.presentScene(scene)
        context.coordinator.scene = scene
        return view
    }

    func updateNSView(_ view: SKView, context: Context) {
        context.coordinator.store = store
        guard let scene = context.coordinator.scene else { return }
        scene.resize(to: view.bounds.size)
        scene.reducedMotion = UserDefaults.standard.bool(forKey: "reduceGameMotion")
        scene.render(
            state: store.state,
            overlay: store.overlay,
            selection: store.selectedCoordinate,
            selectedTool: store.selectedTool,
            bulldozeMode: store.bulldozeMode
        )
    }

    final class Coordinator {
        var store: CityGameStore
        weak var scene: CityScene?
        init(store: CityGameStore) { self.store = store }
    }
}
