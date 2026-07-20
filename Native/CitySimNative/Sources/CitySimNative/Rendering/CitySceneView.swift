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
        context.coordinator.synchronizeCommandPolicy(store.commandPolicy, in: view)
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
        typealias MainLoopAction = @MainActor @Sendable () -> Void
        typealias MainLoopEnqueuer = (@escaping MainLoopAction) -> Void

        var store: CityGameStore
        weak var scene: CityScene?
        private(set) var previousCommandPolicy: CityCommandPolicy
        private(set) var focusHandoffGeneration: UInt = 0
        private(set) var pendingFocusHandoffGeneration: UInt?
        private let enqueueOnMain: MainLoopEnqueuer

        init(
            store: CityGameStore,
            enqueueOnMain: @escaping MainLoopEnqueuer = { action in
                DispatchQueue.main.async(execute: action)
            }
        ) {
            self.store = store
            previousCommandPolicy = store.commandPolicy
            self.enqueueOnMain = enqueueOnMain
        }

        @discardableResult
        func synchronizeCommandPolicy(_ commandPolicy: CityCommandPolicy, in view: SKView) -> Bool {
            let priorPolicy = previousCommandPolicy
            previousCommandPolicy = commandPolicy
            guard commandPolicy == .enabled else {
                invalidatePendingFocusHandoff()
                return false
            }
            guard Self.requiresGameplayFocus(from: priorPolicy, to: commandPolicy),
                  pendingFocusHandoffGeneration == nil else { return false }

            focusHandoffGeneration &+= 1
            let generation = focusHandoffGeneration
            pendingFocusHandoffGeneration = generation
            enqueueOnMain { [weak self, weak view] in
                guard let self else { return }
                guard let view else {
                    self.discardFocusHandoff(generation: generation)
                    return
                }
                self.fulfillFocusHandoff(generation: generation, in: view)
            }
            return true
        }

        @discardableResult
        func fulfillFocusHandoff(generation: UInt, in view: SKView) -> Bool {
            guard pendingFocusHandoffGeneration == generation else { return false }
            pendingFocusHandoffGeneration = nil
            guard previousCommandPolicy == .enabled,
                  store.commandPolicy == .enabled,
                  let window = view.window else { return false }
            return window.makeFirstResponder(view)
        }

        private func discardFocusHandoff(generation: UInt) {
            guard pendingFocusHandoffGeneration == generation else { return }
            pendingFocusHandoffGeneration = nil
        }

        private func invalidatePendingFocusHandoff() {
            guard pendingFocusHandoffGeneration != nil else { return }
            focusHandoffGeneration &+= 1
            pendingFocusHandoffGeneration = nil
        }

        static func requiresGameplayFocus(
            from priorPolicy: CityCommandPolicy,
            to commandPolicy: CityCommandPolicy
        ) -> Bool {
            priorPolicy == .blocked(.welcome) && commandPolicy == .enabled
        }
    }
}
