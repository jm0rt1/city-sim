import SpriteKit
import SwiftUI

@MainActor
final class CityMapSKView: SKView {
    static let defaultAccessibilityHelp = "Use Arrow keys to select blocks, Shift-Arrow to jump five blocks, Return for the announced primary action, and Shift-Return to inspect."

    var cityAccessibilityLabel = "City map"
    var cityAccessibilityValue: String = "No block selected"
    var cityAccessibilityHelp = CityMapSKView.defaultAccessibilityHelp
    var cityAccessibilityActions: [NSAccessibilityCustomAction] = []

    override func accessibilityLabel() -> String? { cityAccessibilityLabel }
    override func accessibilityValue() -> Any? { cityAccessibilityValue }
    override func accessibilityHelp() -> String? { cityAccessibilityHelp }
    override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? { cityAccessibilityActions }
}

@MainActor
struct CitySceneView: NSViewRepresentable {
    @ObservedObject var store: CityGameStore
    var viewportInsets: CityMapViewportInsets = .zero
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage("reduceGameMotion") private var reduceGameMotion = false

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeNSView(context: Context) -> SKView {
        let view = CityMapSKView(frame: .zero)
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
            guard let coordinator else { return }
            if CityCommandCatalog.mapFocusedCommands.contains(command) {
                if coordinator.store.performMapCommand(command),
                   CityCommandCatalog.mapSelectionCommands.contains(command),
                   let coordinate = coordinator.store.selectedCoordinate {
                    coordinator.scene?.revealSelection(
                        coordinate,
                        viewportInsets: coordinator.viewportInsets
                    )
                }
            } else {
                coordinator.store.perform(command)
            }
        }
        scene.allowsCommand = { [weak coordinator = context.coordinator] command in
            guard let coordinator else { return false }
            return CityCommandCatalog.mapFocusedCommands.contains(command)
                ? coordinator.store.canRouteMapCommand(command)
                : coordinator.store.commandPolicy.allows(command)
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
        context.coordinator.viewportInsets = viewportInsets
        view.window?.acceptsMouseMovedEvents = true
        context.coordinator.synchronizeCommandPolicy(store.commandPolicy, in: view)
        context.coordinator.synchronizeMapFocusRequest(store.mapFocusRequestGeneration, in: view)
        context.coordinator.configureMapAccessibility(in: view)
        guard let scene = context.coordinator.scene else { return }
        scene.resize(to: view.bounds.size)
        let proofReducedMotion: Bool
#if DEBUG
        proofReducedMotion = ProcessInfo.processInfo.environment["CITYSIM_REDUCE_MOTION_PROOF"] == "1"
#else
        proofReducedMotion = false
#endif
        scene.reducedMotion = accessibilityReduceMotion || reduceGameMotion || proofReducedMotion
        guard let snapshot = context.coordinator.presentationSnapshot(for: store.state) else { return }
        scene.render(
            snapshot: snapshot,
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
        var viewportInsets: CityMapViewportInsets = .zero
        weak var scene: CityScene?
        private(set) var previousCommandPolicy: CityCommandPolicy
        private(set) var focusHandoffGeneration: UInt = 0
        private(set) var pendingFocusHandoffGeneration: UInt?
        private(set) var observedMapFocusRequestGeneration: UInt
        private var cachedPresentationSnapshot: CityPresentationSnapshot?
        private let enqueueOnMain: MainLoopEnqueuer

        init(
            store: CityGameStore,
            enqueueOnMain: @escaping MainLoopEnqueuer = { action in
                DispatchQueue.main.async(execute: action)
            }
        ) {
            self.store = store
            previousCommandPolicy = store.commandPolicy
            observedMapFocusRequestGeneration = store.mapFocusRequestGeneration
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

            return enqueueFocusHandoff(in: view)
        }

        @discardableResult
        func synchronizeMapFocusRequest(_ generation: UInt, in view: SKView) -> Bool {
            guard generation != observedMapFocusRequestGeneration else { return false }
            observedMapFocusRequestGeneration = generation
            guard store.commandPolicy == .enabled, previousCommandPolicy == .enabled,
                  pendingFocusHandoffGeneration == nil else { return false }
            return enqueueFocusHandoff(in: view)
        }

        func configureMapAccessibility(in view: SKView) {
            view.setAccessibilityElement(true)
            let mapView = view as? CityMapSKView
            guard let coordinate = store.selectedCoordinate,
                  let tile = store.state.tile(at: coordinate) else {
                mapView?.cityAccessibilityValue = "No block selected"
                mapView?.cityAccessibilityHelp = CityMapSKView.defaultAccessibilityHelp
                mapView?.cityAccessibilityActions = []
                return
            }

            let baseValue = "Selected \(tile.kind.title), block \(coordinate.x + 1), \(coordinate.y + 1)"
            let primary = CityMapPrimaryActionPresentation.make(
                interactionMode: store.interactionMode,
                tile: tile,
                state: store.state
            )
            var valueParts = [baseValue]
            if let snapshot = try? CityPresentationSnapshot(state: store.state),
               let diagnosis = CitySelectedLocationDiagnosis.make(tile: tile, snapshot: snapshot) {
                valueParts.append(diagnosis.cause)
                valueParts.append(diagnosis.consequence)
            }
            valueParts.append("Primary action: \(primary.name). \(primary.disclosure)")
            mapView?.cityAccessibilityValue = valueParts.joined(separator: ". ")
            mapView?.cityAccessibilityHelp = primary.disclosure

            var actions: [NSAccessibilityCustomAction] = []
            if primary.isAvailable {
                actions.append(NSAccessibilityCustomAction(name: primary.name) { [weak self] in
                    self?.store.performMapCommand(.mapPrimaryAction) ?? false
                })
            }
            if store.interactionMode != .inspect {
                actions.append(NSAccessibilityCustomAction(name: "Inspect \(tile.kind.title) at block \(coordinate.x + 1), \(coordinate.y + 1)") { [weak self] in
                    self?.store.performMapCommand(.mapSecondaryAction) ?? false
                })
            }
            mapView?.cityAccessibilityActions = actions
        }

        private func enqueueFocusHandoff(in view: SKView) -> Bool {
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

        func presentationSnapshot(for state: CityGameState) -> CityPresentationSnapshot? {
            if let cachedPresentationSnapshot, cachedPresentationSnapshot.state == state {
                return cachedPresentationSnapshot
            }
            guard let snapshot = try? CityPresentationSnapshot(state: state) else { return nil }
            cachedPresentationSnapshot = snapshot
            return snapshot
        }
    }
}
