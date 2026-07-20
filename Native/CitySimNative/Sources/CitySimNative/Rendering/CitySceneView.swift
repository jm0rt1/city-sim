import SpriteKit
import SwiftUI

struct CitySceneFocusRequest: Equatable {
    static let initial = CitySceneFocusRequest(sequence: 0)

    let sequence: UInt

    func next() -> CitySceneFocusRequest {
        CitySceneFocusRequest(sequence: sequence &+ 1)
    }
}

@MainActor
struct CitySceneView: NSViewRepresentable {
    @ObservedObject var store: CityGameStore
    var focusRequest: CitySceneFocusRequest = .initial
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
        context.coordinator.fulfill(focusRequest, in: view)
        guard let scene = context.coordinator.scene else { return }
        scene.resize(to: view.bounds.size)
        let proofReducedMotion: Bool
#if DEBUG
        proofReducedMotion = ProcessInfo.processInfo.environment["CITYSIM_REDUCE_MOTION_PROOF"] == "1"
#else
        proofReducedMotion = false
#endif
        scene.reducedMotion = accessibilityReduceMotion || reduceGameMotion || proofReducedMotion
        scene.render(
            state: store.state,
            overlay: store.overlay,
            selection: store.selectedCoordinate,
            interactionMode: store.interactionMode
        )
    }

    @MainActor
    final class Coordinator {
        var store: CityGameStore
        weak var scene: CityScene?
        private(set) var fulfilledFocusRequest = CitySceneFocusRequest.initial
        init(store: CityGameStore) { self.store = store }

        @discardableResult
        func fulfill(_ request: CitySceneFocusRequest, in view: SKView) -> Bool {
            guard request != fulfilledFocusRequest,
                  let window = view.window,
                  window.makeFirstResponder(view) else { return false }
            fulfilledFocusRequest = request
            return true
        }
    }
}
