import SpriteKit
import SwiftUI

@MainActor
final class CityMapSKView: SKView {
    static let defaultAccessibilityHelp = "Pinch or scroll to zoom, use Plus and Minus to zoom from the center, press 0 to frame the city, use Arrow keys to select blocks, Shift-Arrow to jump five blocks, Return for the announced primary action, and Shift-Return to inspect."

    var cityAccessibilityLabel = "City map"
    var cityAccessibilityValue: String = "No block selected"
    var cityAccessibilityHelp = CityMapSKView.defaultAccessibilityHelp
    // SKView's stored accessibility action attribute is not reliably queried by
    // external AX clients. Keep the actions on the native map view and publish
    // them through the protocol getter that AppKit consults for this element.
    var cityAccessibilityActions: [NSAccessibilityCustomAction] = []
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { cityAccessibilityLabel }
    override func accessibilityValue() -> Any? { cityAccessibilityValue }
    override func accessibilityHelp() -> String? { cityAccessibilityHelp }
    override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? { cityAccessibilityActions }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard event.keyCode == 48,
              !modifiers.contains(.command),
              !modifiers.contains(.control),
              !modifiers.contains(.option) else {
            super.keyDown(with: event)
            return
        }

        if modifiers.contains(.shift) {
            window?.selectPreviousKeyView(self)
        } else {
            window?.selectNextKeyView(self)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard let cityScene = scene as? CityScene else {
            super.scrollWheel(with: event)
            return
        }
        cityScene.handleMapScrollWheel(event)
    }

    override func magnify(with event: NSEvent) {
        guard let cityScene = scene as? CityScene else {
            super.magnify(with: event)
            return
        }
        cityScene.handleMapMagnification(event)
    }
}

@MainActor
struct CitySceneView: NSViewRepresentable {
    typealias NSViewType = CityMapSKView

    @ObservedObject var store: CityGameStore
    var viewportInsets: CityMapViewportInsets = .zero
    let pointerTransitionGate: CityMapPointerTransitionGate
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage("reduceGameMotion") private var reduceGameMotion = false

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, pointerTransitionGate: pointerTransitionGate)
    }

    func makeNSView(context: Context) -> CityMapSKView {
        let view = CityMapSKView(frame: .zero)
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        // This scene is strictly 2D. Aligning with Core Animation and omitting
        // depth/stencil prevents redundant backing-scale render targets while
        // preserving the requested display cadence.
        view.isAsynchronous = false
        view.shouldCullNonVisibleNodes = true
        view.disableDepthStencilBuffer = true
        let diagnosticsEnabled = ProcessInfo.processInfo.arguments.contains("--renderer-diagnostics") ||
            UserDefaults.standard.bool(forKey: "showRendererDiagnostics")
        view.showsFPS = diagnosticsEnabled
        view.showsNodeCount = diagnosticsEnabled
        view.showsDrawCount = diagnosticsEnabled
        let scene = CityScene(size: CGSize(width: 1280, height: 800))
        scene.onActiveActionTargetCandidate = { [weak coordinator = context.coordinator, weak view] coordinate in
            guard let coordinator, let view else { return nil }
            return coordinator.acceptPointerMapActionCandidate(coordinate, in: view)
        }
        scene.onPrimaryAction = { [weak coordinator = context.coordinator, weak view] coordinate in
            guard let coordinator, let view else { return }
            coordinator.performPointerPrimaryAction(at: coordinate, in: view)
        }
        scene.onSecondaryAction = { [weak coordinator = context.coordinator, weak view] coordinate in
            guard let coordinator, let view else { return }
            coordinator.performPointerSecondaryAction(at: coordinate, in: view)
        }
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

    func updateNSView(_ view: CityMapSKView, context: Context) {
        context.coordinator.store = store
        context.coordinator.viewportInsets = viewportInsets
        context.coordinator.pointerTransitionGate = pointerTransitionGate
        view.window?.acceptsMouseMovedEvents = true
        context.coordinator.synchronizeCommandPolicy(store.commandPolicy, in: view)
        context.coordinator.synchronizeMapFocusRequest(store.mapFocusRequestGeneration, in: view)
        context.coordinator.configureMapAccessibility(in: view)
        guard let scene = context.coordinator.scene else { return }
        scene.resize(to: view.bounds.size)
        scene.updateViewportInsets(
            viewportInsets,
            preserveActionTargetScale: store.showInspector
                && !store.isCityFocusModeEnabled && !store.isPhotoModeEnabled
        )
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
            selection: store.isPhotoModeEnabled ? nil : store.selectedCoordinate,
            interactionMode: store.isPhotoModeEnabled ? .inspect : store.interactionMode,
            activeActionTarget: store.isPhotoModeEnabled ? nil : store.activeMapActionTargetPresentation,
            guidedRoadRoute: store.isPhotoModeEnabled ? [] : store.roadConnectionRecoveryRoute
        )
        context.coordinator.synchronizeCityFocusCamera(
            isEnabled: store.isCityFocusModeEnabled,
            selectedCoordinate: store.selectedCoordinate
        )
        context.coordinator.synchronizePhotoCaptureRequest(
            store.photoCaptureRequestGeneration,
            in: view
        )
        // The representable's first update can render before AppKit has
        // delivered its final map aperture. Reapply the same authoritative
        // developed-bounds camera once after that initial render so a cold
        // staged launch cannot remain at the toy-island city scale. This is
        // identical to the existing player-invoked Frame Developed City route
        // and never changes topology or simulation truth.
        if !context.coordinator.hasFramedInitialState {
            context.coordinator.hasFramedInitialState = true
            scene.frameCity()
        }
    }

    @MainActor
    final class Coordinator {
        typealias MainLoopAction = @MainActor @Sendable () -> Void
        typealias MainLoopEnqueuer = (@escaping MainLoopAction) -> Void

        var store: CityGameStore
        var viewportInsets: CityMapViewportInsets = .zero
        var pointerTransitionGate: CityMapPointerTransitionGate
        weak var scene: CityScene?
        private(set) var previousCommandPolicy: CityCommandPolicy
        var hasFramedInitialState = false
        private(set) var focusHandoffGeneration: UInt = 0
        private(set) var pendingFocusHandoffGeneration: UInt?
        private(set) var observedMapFocusRequestGeneration: UInt
        private var observedPhotoCaptureRequestGeneration: UInt
        private var previousCityFocusModeEnabled: Bool
        private var cachedPresentationSnapshot: CityPresentationSnapshot?
        private let enqueueOnMain: MainLoopEnqueuer

        init(
            store: CityGameStore,
            pointerTransitionGate: CityMapPointerTransitionGate = CityMapPointerTransitionGate(),
            enqueueOnMain: @escaping MainLoopEnqueuer = { action in
                DispatchQueue.main.async(execute: action)
            }
        ) {
            self.store = store
            self.pointerTransitionGate = pointerTransitionGate
            previousCommandPolicy = store.commandPolicy
            observedMapFocusRequestGeneration = store.mapFocusRequestGeneration
            observedPhotoCaptureRequestGeneration = store.photoCaptureRequestGeneration
            previousCityFocusModeEnabled = store.isCityFocusModeEnabled
            self.enqueueOnMain = enqueueOnMain
        }

        @discardableResult
        func synchronizePhotoCaptureRequest(
            _ generation: UInt,
            in view: CityMapSKView
        ) -> Bool {
            guard generation != observedPhotoCaptureRequestGeneration else { return false }
            observedPhotoCaptureRequestGeneration = generation
            guard store.isPhotoModeEnabled, let scene,
                  let texture = view.texture(from: scene) else {
                store.failPhotoCapture()
                return false
            }
            let representation = NSBitmapImageRep(cgImage: texture.cgImage())
            guard let data = representation.representation(using: .png, properties: [:]) else {
                store.failPhotoCapture()
                return false
            }
            store.completePhotoCapture(pngData: data)
            return true
        }

        @discardableResult
        func synchronizeCityFocusCamera(
            isEnabled: Bool,
            selectedCoordinate _: GridCoordinate?
        ) -> Bool {
            let enteredFocusCity = isEnabled && !previousCityFocusModeEnabled
            previousCityFocusModeEnabled = isEnabled
            guard enteredFocusCity, let scene else {
                return false
            }
            // ContentView owns the exact Focus City aperture and publishes it
            // through the existing viewport-insets handoff before this point.
            // Refit once on the mode transition even when a block is selected;
            // selection remains authoritative, while the renderer consumes the
            // larger safe aperture instead of retaining stale pre-focus framing.
            scene.frameCity()
            return true
        }

        @discardableResult
        func synchronizeCommandPolicy(_ commandPolicy: CityCommandPolicy, in view: CityMapSKView) -> Bool {
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
        func synchronizeMapFocusRequest(_ generation: UInt, in view: CityMapSKView) -> Bool {
            guard generation != observedMapFocusRequestGeneration else { return false }
            observedMapFocusRequestGeneration = generation
            guard store.commandPolicy == .enabled, previousCommandPolicy == .enabled,
                  pendingFocusHandoffGeneration == nil else { return false }
            if case .build = store.interactionMode,
               store.selectedCoordinate != nil, let window = view.window {
                // Closing an inspector or menu can synthesize hover over the
                // newly exposed map. Preserve the suggested parcel until the
                // player deliberately moves the pointer.
                pointerTransitionGate.begin(
                    window: window,
                    anchor: window.convertPoint(fromScreen: NSEvent.mouseLocation)
                )
            }
            return enqueueFocusHandoff(in: view)
        }

        func configureMapAccessibility(in view: CityMapSKView) {
            view.setAccessibilityElement(true)
            guard let coordinate = store.selectedCoordinate,
                  let tile = store.state.tile(at: coordinate) else {
                view.cityAccessibilityValue = "No block selected"
                view.cityAccessibilityHelp = CityMapSKView.defaultAccessibilityHelp
                if case .build(let kind) = store.interactionMode {
                    view.cityAccessibilityActions = [
                        NSAccessibilityCustomAction(name: "Select buildable block") { [weak self] in
                            guard let self,
                                  let coordinate = Self.firstBuildableCoordinate(
                                      for: kind,
                                      in: self.store.state
                                  ) else {
                                return false
                            }
                            guard self.store.acceptPointerMapActionCandidate(coordinate) != nil else {
                                return false
                            }
                            self.configureMapAccessibility(in: view)
                            return true
                        }
                    ]
                } else {
                    view.cityAccessibilityActions = []
                }
                return
            }

            let activeCoordinate: String
            switch store.interactionMode {
            case .inspect:
                activeCoordinate = "Selected \(tile.kind.title), block \(coordinate.x + 1), \(coordinate.y + 1)"
            case .build(let kind):
                activeCoordinate = "Selected target, pending \(kind.title) placement at block \(coordinate.x + 1), \(coordinate.y + 1)"
            case .bulldoze:
                activeCoordinate = "Selected target, pending bulldoze at \(tile.kind.title), block \(coordinate.x + 1), \(coordinate.y + 1)"
            }
            guard let primary = store.activeMapActionTargetPresentation?.primaryAction else {
                view.cityAccessibilityActions = []
                return
            }
            var valueParts = [activeCoordinate]
            if tile.kind != .empty && tile.kind != .road {
                let presentation = LotConsequencePresentation(tile: tile)
                if presentation.construction != .complete {
                    valueParts.append(
                        "Construction \(presentation.construction.label.lowercased()), " +
                        "\(Int((tile.constructionProgress * 100).rounded())) percent"
                    )
                } else {
                    let condition = switch presentation.condition {
                    case .maintained: "maintained"
                    case .weathered: "weathered"
                    case .distressed: "distressed"
                    }
                    valueParts.append("Completed, \(condition) condition")
                }
            } else if tile.kind == .road,
                      let maintenance = CityRoadMaintenancePresentation.make(
                          tile: tile,
                          state: store.state
                      ) {
                valueParts.append(maintenance.accessibilitySummary)
            }
            if store.overlay != .none {
                valueParts.append("\(store.overlay.title) overlay active")
            }
            if let snapshot = try? CityPresentationSnapshot(state: store.state) {
                if let diagnosis = CitySelectedLocationDiagnosis.make(tile: tile, snapshot: snapshot) {
                    valueParts.append(diagnosis.cause)
                    valueParts.append(diagnosis.consequence)
                }
                if store.overlay == .traffic,
                   let commute = snapshot.spatialConsequences.commuteRoute(from: coordinate) {
                    valueParts.append(
                        "Assigned commute route visible across \(commute.roadCoordinates.count) road blocks"
                    )
                }
            }
            valueParts.append("Primary action: \(primary.name). \(primary.disclosure)")
            view.cityAccessibilityValue = valueParts.joined(separator: ". ")
            view.cityAccessibilityHelp = primary.disclosure

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
            view.cityAccessibilityActions = actions
        }

        static func firstBuildableCoordinate(
            for kind: BuildingKind,
            in state: CityGameState
        ) -> GridCoordinate? {
            let candidates = state.tiles
                .sorted {
                    if $0.coordinate.y != $1.coordinate.y {
                        return $0.coordinate.y < $1.coordinate.y
                    }
                    return $0.coordinate.x < $1.coordinate.x
                }
                .filter {
                    if case .success = CitySimulation.validateBuild(
                        kind,
                        at: $0.coordinate,
                        in: state
                    ) {
                        return true
                    }
                    return false
                }
            if kind == .road,
               let extensionTarget = candidates.first(where: { candidate in
                   state.neighbors(of: candidate.coordinate).contains { $0.kind == .road }
               }) {
                return extensionTarget.coordinate
            }
            if kind != .road,
               let visibleOpportunity = CityBuildOpportunityInventory.make(
                   kind: kind,
                   in: state
               )?.outlinedCoordinates.first {
                return visibleOpportunity
            }
            return candidates.first?.coordinate
        }

        func allowsPointerMapActionCandidate(in view: CityMapSKView) -> Bool {
            guard store.commandPolicy == .enabled, !store.isPhotoModeEnabled else { return false }
            guard !pointerTransitionGate.blocksPointerInput(in: view.window) else { return false }
            let responder = view.window?.firstResponder
            return !(responder is NSTextView) && !(responder is NSTextField)
        }

        func acceptPointerMapActionCandidate(
            _ coordinate: GridCoordinate,
            in view: CityMapSKView
        ) -> CityMapActionTargetPresentation? {
            guard allowsPointerMapActionCandidate(in: view) else { return nil }
            return store.acceptPointerMapActionCandidate(coordinate)
        }

        @discardableResult
        func performPointerPrimaryAction(
            at coordinate: GridCoordinate,
            in view: CityMapSKView
        ) -> Bool {
            guard !pointerTransitionGate.blocksPointerInput(in: view.window) else { return false }
            if store.interactionMode == .inspect {
                store.primaryAction(at: coordinate)
                return true
            }
            guard store.selectedCoordinate == coordinate else { return false }
            return store.performMapCommand(.mapPrimaryAction)
        }

        @discardableResult
        func performPointerSecondaryAction(
            at coordinate: GridCoordinate,
            in view: CityMapSKView
        ) -> Bool {
            guard !pointerTransitionGate.blocksPointerInput(in: view.window) else { return false }
            store.secondaryAction(at: coordinate)
            return true
        }

        private func enqueueFocusHandoff(in view: CityMapSKView) -> Bool {
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
        func fulfillFocusHandoff(generation: UInt, in view: CityMapSKView) -> Bool {
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
