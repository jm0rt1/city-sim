import AppKit
import SpriteKit

struct CityMapViewportInsets: Equatable, Sendable {
    var top: CGFloat
    var leading: CGFloat
    var bottom: CGFloat
    var trailing: CGFloat

    static let zero = CityMapViewportInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
}

struct RendererDiagnosticsSnapshot: Equatable, Sendable {
    var totalTileCount = 0
    var createdTileCount = 0
    var updatedTileCount = 0
    var reusedTileCount = 0
    var removedTileCount = 0
    var overlayUpdateCount = 0
    var nodeCount = 0
    var drawableNodeCount = 0
    var activeActionCount = 0
    var consumedConsequenceEventCount = 0
    var displayedConsequenceCueCount = 0
    var updateDurationMilliseconds = 0.0
    var detailLevel: CameraDetailLevel = .neighborhood
    var updatedCoordinates: Set<GridCoordinate> = []
}

private struct TileRenderSignature: Equatable {
    let kind: BuildingKind
    let lotPresentation: LotConsequencePresentation?
    let spatialConsequences: SpatialConsequenceRenderSignature
    let reducedMotion: Bool
    let roadConnections: RoadConnectionMask
    let gridWidth: Int
    let gridHeight: Int

    func matchesNonSpatialFields(of other: TileRenderSignature) -> Bool {
        kind == other.kind
            && lotPresentation == other.lotPresentation
            && reducedMotion == other.reducedMotion
            && roadConnections == other.roadConnections
            && gridWidth == other.gridWidth
            && gridHeight == other.gridHeight
    }
}

private struct OverlayRenderSignature: Equatable {
    let overlay: DataOverlay
    let colorToken: UInt32
}

private struct RuntimeTreeMetrics {
    let nodes: Int
    let drawables: Int
    let actions: Int
}

private enum InteractionPreviewStatus: Equatable {
    case inspect(BuildingKind)
    case validBuild(BuildingKind)
    case invalidBuild(BuildingKind, BuildRejection)
    case validBulldoze(BuildingKind)
    case invalidBulldoze(String)
}

private struct InteractionPreviewSignature: Equatable {
    let coordinate: GridCoordinate
    let status: InteractionPreviewStatus
    let detail: CameraDetailLevel
}

private final class TileRenderRecord {
    let root: SKNode
    let overlayLayer: SKNode
    let consequenceLayer: SKNode
    let signature: TileRenderSignature
    var overlaySignature: OverlayRenderSignature

    init(
        root: SKNode,
        overlayLayer: SKNode,
        consequenceLayer: SKNode,
        signature: TileRenderSignature,
        overlaySignature: OverlayRenderSignature
    ) {
        self.root = root
        self.overlayLayer = overlayLayer
        self.consequenceLayer = consequenceLayer
        self.signature = signature
        self.overlaySignature = overlaySignature
    }
}

@MainActor
final class CityScene: SKScene {
    var onPrimaryAction: ((GridCoordinate) -> Void)?
    var onSecondaryAction: ((GridCoordinate) -> Void)?
    var onCommandAction: ((CityCommandID) -> Void)?
    var allowsCommand: ((CityCommandID) -> Bool)?
    var reducedMotion = false

    private let style: WorldVisualStyle
    private let assets: WorldAssetCatalog
    private let terrainRenderer: TerrainRenderer
    private let roadRenderer: RoadRenderer
    private let lotRenderer: LotRenderer
    private let overlayRenderer: WorldOverlayRenderer
    private let spatialConsequenceRenderer: SpatialConsequenceRenderer
    private let worldLayer = SKNode()
    private let backdropLayer = SKNode()
    private let tileLayer = SKNode()
    private let cameraNode = SKCameraNode()
    private let hoverNode = SKShapeNode()
    private let selectionNode = SKShapeNode()
    private let selectionLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
    private var renderedState: CityGameState?
    private var renderedSnapshot: CityPresentationSnapshot?
    private var renderedReducedMotion = false
    private var presentedConsequenceEventTicks: [String: Int] = [:]
    private var displayedConsequenceEventExpiryTicks: [GridCoordinate: Int] = [:]
    private var renderedOverlay: DataOverlay = .none
    private var renderedSelection: GridCoordinate?
    private var renderedInteractionMode: CityInteractionMode = .inspect
    private var hoveredCoordinate: GridCoordinate?
    private var lastPreviewSignature: InteractionPreviewSignature?
    private var renderedGridSize: CGSize?
    private var viewportInsets: CityMapViewportInsets = .zero
    private var hasUserAdjustedCamera = false
    private(set) var developedVisualBoundsForTesting: CGRect = .null
    private var tileRecords: [GridCoordinate: TileRenderRecord] = [:]
    private var lastDragLocation: CGPoint?
    private var didDrag = false
    private var tileWidth: CGFloat { style.tileWidth }
    private var tileHeight: CGFloat { style.tileHeight }
    private(set) var currentCameraDetailLevel: CameraDetailLevel
    private(set) var diagnosticsSnapshot = RendererDiagnosticsSnapshot()
    var cameraScaleForTesting: CGFloat { cameraNode.xScale }
    var cameraPositionForTesting: CGPoint { cameraNode.position }
    var cameraScale: CGFloat { cameraNode.xScale }
    var consumedConsequenceEventIDCountForTesting: Int { presentedConsequenceEventTicks.count }

    func safeViewportRectForTesting(_ insets: CityMapViewportInsets) -> CGRect {
        safeViewportRect(insets)
    }

    func scenePointForTesting(at coordinate: GridCoordinate) -> CGPoint {
        style.isoPosition(coordinate)
    }

    override init(size: CGSize) {
        let style = WorldVisualStyle()
        let assets = WorldAssetCatalog.shared
        self.style = style
        self.assets = assets
        self.terrainRenderer = TerrainRenderer(style: style, assets: assets)
        self.roadRenderer = RoadRenderer(style: style, assets: assets)
        self.lotRenderer = LotRenderer(style: style, assets: assets)
        self.overlayRenderer = WorldOverlayRenderer(style: style)
        self.spatialConsequenceRenderer = SpatialConsequenceRenderer(style: style)
        self.currentCameraDetailLevel = style.detailLevel(cameraScale: 1)
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = style.palette.backdrop
        addChild(worldLayer)
        backdropLayer.zPosition = -20_000
        worldLayer.addChild(backdropLayer)
        worldLayer.addChild(tileLayer)
        addChild(cameraNode)
        camera = cameraNode
        configureHighlight(hoverNode, color: .white, alpha: 0.24, z: 90_000)
        configureHighlight(selectionNode, color: NSColor(calibratedRed: 0.25, green: 0.95, blue: 0.78, alpha: 1), alpha: 0.65, z: 90_001)
        hoverNode.name = "interaction.hover"
        selectionNode.name = "interaction.selection"
        configureSelectionAdornment()
        worldLayer.addChild(hoverNode)
        worldLayer.addChild(selectionNode)
        hoverNode.isHidden = true
        selectionNode.isHidden = true
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        view.window?.acceptsMouseMovedEvents = true
        if let state = renderedState {
            fitCity(state)
            refreshForCameraChange()
        }
    }

    func render(
        snapshot: CityPresentationSnapshot,
        overlay: DataOverlay,
        selection: GridCoordinate?,
        interactionMode: CityInteractionMode
    ) {
        let renderStarted = ProcessInfo.processInfo.systemUptime
        if renderedSnapshot?.fingerprint == snapshot.fingerprint,
           renderedOverlay == overlay,
           renderedSelection == selection,
           renderedInteractionMode == interactionMode,
           renderedReducedMotion == reducedMotion {
            diagnosticsSnapshot.createdTileCount = 0
            diagnosticsSnapshot.updatedTileCount = 0
            diagnosticsSnapshot.reusedTileCount = tileRecords.count
            diagnosticsSnapshot.removedTileCount = 0
            diagnosticsSnapshot.overlayUpdateCount = 0
            diagnosticsSnapshot.consumedConsequenceEventCount = 0
            diagnosticsSnapshot.updatedCoordinates = []
            diagnosticsSnapshot.updateDurationMilliseconds =
                (ProcessInfo.processInfo.systemUptime - renderStarted) * 1_000
            return
        }
        let isFirstRender = renderedSnapshot == nil
        let previousSnapshot = renderedSnapshot
        let previousOverlay = renderedOverlay
        let previousSelection = renderedSelection
        let motionChanged = renderedReducedMotion != reducedMotion
        let priorDisplayedCueCount = diagnosticsSnapshot.displayedConsequenceCueCount
        presentedConsequenceEventTicks = presentedConsequenceEventTicks.filter {
            $0.value >= snapshot.authoritativeTick - 128
        }
        let consequenceEvents = snapshot.consequenceEvents(since: previousSnapshot)
            .filter { event in
                guard presentedConsequenceEventTicks[event.id] == nil else { return false }
                presentedConsequenceEventTicks[event.id] = event.authoritativeTick
                return true
            }
        let state = snapshot.state
        if isFirstRender {
            applyDevelopedCoreCamera(state)
        }
        let resolvedDetail = style.detailLevel(cameraScale: cameraNode.xScale)
        if resolvedDetail != currentCameraDetailLevel {
            currentCameraDetailLevel = resolvedDetail
            for record in tileRecords.values {
                style.updateDetailVisibility(in: record.root, detail: resolvedDetail)
            }
            lastPreviewSignature = nil
        }
        renderedState = state
        renderedSnapshot = snapshot
        renderedOverlay = overlay
        renderedSelection = selection
        renderedInteractionMode = interactionMode
        renderedReducedMotion = reducedMotion
        diagnosticsSnapshot = updateWorld(
            snapshot: snapshot,
            overlay: overlay,
            previousSnapshot: motionChanged ? nil : previousSnapshot,
            previousOverlay: previousOverlay
        )
        let expiredCueCount = expireConsequenceEvents(at: snapshot.authoritativeTick)
        let insertedCueCount = presentConsequenceEvents(consequenceEvents)
        updateSelection(selection)
        if let hoveredCoordinate { updateBuildPreview(at: hoveredCoordinate) }
        let worldChanged = diagnosticsSnapshot.createdTileCount > 0
            || diagnosticsSnapshot.updatedTileCount > 0
            || diagnosticsSnapshot.removedTileCount > 0
            || diagnosticsSnapshot.overlayUpdateCount > 0
        let displayedCueCount = worldChanged
            ? currentDisplayedConsequenceCueCount()
            : max(0, priorDisplayedCueCount + insertedCueCount - expiredCueCount)
        let unexplainedCueRemoval = priorDisplayedCueCount != displayedCueCount
            && expiredCueCount == 0
            && insertedCueCount == 0
            && !worldChanged
        let requiresTreeRecount = isFirstRender
            || previousSelection != selection
            || motionChanged
            || unexplainedCueRemoval
        refreshRuntimeDiagnostics(
            consumedEventCount: consequenceEvents.count,
            displayedCueCount: displayedCueCount,
            requiresTreeRecount: requiresTreeRecount
        )
        diagnosticsSnapshot.updateDurationMilliseconds =
            (ProcessInfo.processInfo.systemUptime - renderStarted) * 1_000
    }

    func render(
        state: CityGameState,
        overlay: DataOverlay,
        selection: GridCoordinate?,
        interactionMode: CityInteractionMode
    ) {
        let snapshot: CityPresentationSnapshot
        if let renderedSnapshot, renderedSnapshot.state == state {
            snapshot = renderedSnapshot
        } else {
            guard let derived = try? CityPresentationSnapshot(state: state) else { return }
            snapshot = derived
        }
        render(
            snapshot: snapshot,
            overlay: overlay,
            selection: selection,
            interactionMode: interactionMode
        )
    }

    func render(
        state: CityGameState,
        overlay: DataOverlay,
        selection: GridCoordinate?,
        selectedTool: BuildingKind,
        bulldozeMode: Bool
    ) {
        render(
            state: state,
            overlay: overlay,
            selection: selection,
            interactionMode: bulldozeMode ? .bulldoze : .build(selectedTool)
        )
    }

    func resize(to newSize: CGSize) {
        let materiallyChanged = abs(size.width - newSize.width) > 1 || abs(size.height - newSize.height) > 1
        size = newSize
        if materiallyChanged, !hasUserAdjustedCamera, let state = renderedState {
            focusDevelopedCore(state)
        }
    }

    func updateViewportInsets(_ insets: CityMapViewportInsets) {
        guard viewportInsets != insets else { return }
        viewportInsets = insets
        if !hasUserAdjustedCamera, let state = renderedState {
            focusDevelopedCore(state)
        }
    }

    func frameCity() {
        if let state = renderedState {
            hasUserAdjustedCamera = false
            focusDevelopedCore(state)
        }
    }

    func developedViewportOccupancyForTesting() -> CGSize {
        guard !developedVisualBoundsForTesting.isNull else { return .zero }
        let safeWidth = max(1, size.width - viewportInsets.leading - viewportInsets.trailing)
        let safeHeight = max(1, size.height - viewportInsets.top - viewportInsets.bottom)
        return CGSize(
            width: developedVisualBoundsForTesting.width / (safeWidth * cameraNode.xScale),
            height: developedVisualBoundsForTesting.height / (safeHeight * cameraNode.yScale)
        )
    }

    func tileRootIdentifier(at coordinate: GridCoordinate) -> ObjectIdentifier? {
        tileRecords[coordinate].map { ObjectIdentifier($0.root) }
    }

    func tileRootIsHiddenForTesting(at coordinate: GridCoordinate) -> Bool? {
        tileRecords[coordinate]?.root.isHidden
    }

    func tileDescendantNamesForTesting(at coordinate: GridCoordinate) -> [String] {
        guard let root = tileRecords[coordinate]?.root else { return [] }
        func names(in node: SKNode) -> [String] {
            (node.name.map { [$0] } ?? []) + node.children.flatMap(names)
        }
        return names(in: root)
    }

    func tileConsequenceEventNodeCountForTesting(at coordinate: GridCoordinate) -> Int {
        tileRecords[coordinate]?.consequenceLayer.children.filter {
            $0.name?.hasPrefix("spatial.event.") == true
        }.count ?? 0
    }

    func recountedRuntimeMetricsForTesting() -> (nodes: Int, drawables: Int, actions: Int) {
        let metrics = runtimeTreeMetrics(worldLayer)
        return (metrics.nodes - 1, metrics.drawables, metrics.actions)
    }

    func configureProofCamera(detail: CameraDetailLevel, centeredOn coordinate: GridCoordinate? = nil) {
        let scale: CGFloat
        switch detail {
        case .city: scale = 1.45
        case .neighborhood: scale = 0.82
        case .block: scale = 0.50
        }
        cameraNode.setScale(scale)
        if let coordinate { cameraNode.position = style.isoPosition(coordinate) }
        refreshForCameraChange()
    }

    func configureProofInteraction(at coordinate: GridCoordinate?) {
        hoveredCoordinate = coordinate
        guard let coordinate else {
            lastPreviewSignature = nil
            hoverNode.removeAllChildren()
            hoverNode.isHidden = true
            return
        }
        hoverNode.position = style.isoPosition(coordinate)
        hoverNode.isHidden = false
        updateBuildPreview(at: coordinate)
    }

    override func mouseDown(with event: NSEvent) {
        lastDragLocation = event.location(in: self)
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        let point = event.location(in: self)
        guard let last = lastDragLocation else { return }
        let dx = point.x - last.x
        let dy = point.y - last.y
        if hypot(dx, dy) > 1 { didDrag = true }
        cameraNode.position.x -= dx * cameraNode.xScale
        cameraNode.position.y -= dy * cameraNode.yScale
        hasUserAdjustedCamera = true
        lastDragLocation = point
    }

    override func mouseUp(with event: NSEvent) {
        defer { lastDragLocation = nil }
        guard !didDrag, let coordinate = coordinate(at: event.location(in: self)) else { return }
        onPrimaryAction?(coordinate)
    }

    override func rightMouseDown(with event: NSEvent) {
        if let coordinate = coordinate(at: event.location(in: self)) { onSecondaryAction?(coordinate) }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            guard allowsCommand?(.cancelInteraction) ?? true else { return }
            onCommandAction?(.cancelInteraction)
            return
        }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !modifiers.contains(.command), !modifiers.contains(.control), !modifiers.contains(.option) else {
            super.keyDown(with: event)
            return
        }
        var key = catalogKey(for: event)
        if key == "+" { key = "=" }
        if key == "_" { key = "-" }
        let catalogModifiers: CityCommandModifiers = modifiers.contains(.shift) ? [.shift] : []
        if let command = CityCommandCatalog.matchingCommand(
            key: key,
            modifiers: catalogModifiers,
            scope: .gameplay
        ) {
            if CityCommandCatalog.mapFocusedCommands.contains(command) {
                guard let mapView = view, mapView.window?.firstResponder === mapView else {
                    super.keyDown(with: event)
                    return
                }
            }
            guard allowsCommand?(command) ?? true else { return }
            onCommandAction?(command)
            return
        }
        if let command = CityCommandCatalog.matchingCommand(
            key: key,
            modifiers: catalogModifiers,
            scope: .renderer
        ) {
            guard allowsCommand?(command) ?? true else { return }
            switch command {
            case .cameraZoomIn: zoomCamera(by: 0.82)
            case .cameraZoomOut: zoomCamera(by: 1.22)
            case .cameraFrameCity: frameCity()
            default: break
            }
            return
        }
        super.keyDown(with: event)
    }

    func revealSelection(
        _ coordinate: GridCoordinate,
        viewportInsets: CityMapViewportInsets = .zero
    ) {
        let target = style.isoPosition(coordinate)
        let safeRect = safeViewportRect(viewportInsets)
        if target.x < safeRect.minX { cameraNode.position.x -= safeRect.minX - target.x }
        if target.x > safeRect.maxX { cameraNode.position.x += target.x - safeRect.maxX }
        if target.y < safeRect.minY { cameraNode.position.y -= safeRect.minY - target.y }
        if target.y > safeRect.maxY { cameraNode.position.y += target.y - safeRect.maxY }
        refreshForCameraChange()
    }

    private func safeViewportRect(_ viewportInsets: CityMapViewportInsets) -> CGRect {
        let scale = cameraNode.xScale
        let halfWidth = size.width * scale / 2
        let halfHeight = size.height * scale / 2
        let tilePaddingX = tileWidth * 1.25
        let tilePaddingY = tileHeight * 1.75
        let left = cameraNode.position.x - halfWidth + viewportInsets.leading * scale + tilePaddingX
        let right = cameraNode.position.x + halfWidth - viewportInsets.trailing * scale - tilePaddingX
        let bottom = cameraNode.position.y - halfHeight + viewportInsets.bottom * scale + tilePaddingY
        let top = cameraNode.position.y + halfHeight - viewportInsets.top * scale - tilePaddingY

        // Degenerate measurements must never produce inverted reveal motion.
        let resolvedRight = max(left, right)
        let resolvedTop = max(bottom, top)
        return CGRect(x: left, y: bottom, width: resolvedRight - left, height: resolvedTop - bottom)
    }

    private func catalogKey(for event: NSEvent) -> String {
        switch event.keyCode {
        case 123: "left"
        case 124: "right"
        case 125: "down"
        case 126: "up"
        case 36, 76: "return"
        default: event.charactersIgnoringModifiers?.lowercased() ?? ""
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard let coordinate = coordinate(at: event.location(in: self)) else {
            hoveredCoordinate = nil
            lastPreviewSignature = nil
            hoverNode.removeAllChildren()
            hoverNode.isHidden = true
            return
        }
        hoveredCoordinate = coordinate
        hoverNode.position = style.isoPosition(coordinate)
        hoverNode.isHidden = false
        updateBuildPreview(at: coordinate)
    }

    override func scrollWheel(with event: NSEvent) {
        let factor = exp(event.scrollingDeltaY * 0.012)
        zoomCamera(by: factor)
    }

    private func zoomCamera(by factor: CGFloat) {
        let scale = min(2.4, max(0.30, cameraNode.xScale * factor))
        cameraNode.setScale(scale)
        hasUserAdjustedCamera = true
        refreshForCameraChange()
    }

    private func updateWorld(
        snapshot: CityPresentationSnapshot,
        overlay: DataOverlay,
        previousSnapshot: CityPresentationSnapshot?,
        previousOverlay: DataOverlay
    ) -> RendererDiagnosticsSnapshot {
        let state = snapshot.state
        let updateStarted = ProcessInfo.processInfo.systemUptime
        var diagnostics = RendererDiagnosticsSnapshot(
            nodeCount: diagnosticsSnapshot.nodeCount,
            drawableNodeCount: diagnosticsSnapshot.drawableNodeCount,
            activeActionCount: diagnosticsSnapshot.activeActionCount,
            detailLevel: currentCameraDetailLevel
        )
        let gridSize = CGSize(width: state.gridWidth, height: state.gridHeight)
        if renderedGridSize != gridSize {
            let priorBackdropMetrics = runtimeTreeMetrics(backdropLayer)
            renderedGridSize = gridSize
            backdropLayer.removeAllChildren()
            backdropLayer.addChild(terrainRenderer.makeBackdrop(gridWidth: state.gridWidth, gridHeight: state.gridHeight))
            applyRuntimeDelta(
                from: priorBackdropMetrics,
                to: runtimeTreeMetrics(backdropLayer),
                diagnostics: &diagnostics
            )
        }

        let desiredCoordinates = Set(state.tiles.map(\.coordinate))
        let removed = tileRecords.keys.filter { !desiredCoordinates.contains($0) }
        for coordinate in removed {
            if let record = tileRecords.removeValue(forKey: coordinate) {
                applyRuntimeDelta(
                    from: runtimeTreeMetrics(record.root),
                    to: RuntimeTreeMetrics(nodes: 0, drawables: 0, actions: 0),
                    diagnostics: &diagnostics
                )
                record.root.removeFromParent()
            }
        }
        diagnostics.removedTileCount = removed.count

        let sortedTiles = state.tiles.sorted { lhs, rhs in
            let lhsDepth = lhs.coordinate.x + lhs.coordinate.y
            let rhsDepth = rhs.coordinate.x + rhs.coordinate.y
            if lhsDepth != rhsDepth { return lhsDepth < rhsDepth }
            if lhs.coordinate.x != rhs.coordinate.x { return lhs.coordinate.x < rhs.coordinate.x }
            return lhs.coordinate.y < rhs.coordinate.y
        }
        let changedCoordinates = changedRenderCoordinates(
            from: previousSnapshot,
            to: snapshot,
            canReuseOverlay: previousOverlay == overlay && overlay == .none
        )

        for tile in sortedTiles {
            guard let consequence = snapshot.spatialConsequences[tile.coordinate] else { continue }
            if let changedCoordinates,
               !changedCoordinates.contains(tile.coordinate),
               tileRecords[tile.coordinate] != nil {
                diagnostics.reusedTileCount += 1
                continue
            }
            let signature = tileSignature(for: tile, consequence: consequence, state: state)
            let overlaySignature = overlaySignature(
                for: tile,
                consequence: consequence,
                state: state,
                overlay: overlay
            )
            if let existing = tileRecords[tile.coordinate], existing.signature == signature {
                diagnostics.reusedTileCount += 1
                if existing.overlaySignature != overlaySignature {
                    let priorOverlayMetrics = runtimeTreeMetrics(existing.overlayLayer)
                    updateOverlay(
                        in: existing.overlayLayer,
                        tile: tile,
                        consequence: consequence,
                        state: state,
                        overlay: overlay
                    )
                    applyRuntimeDelta(
                        from: priorOverlayMetrics,
                        to: runtimeTreeMetrics(existing.overlayLayer),
                        diagnostics: &diagnostics
                    )
                    existing.overlaySignature = overlaySignature
                    updatePersistentConsequenceEmphasis(in: existing.consequenceLayer, overlay: overlay)
                    diagnostics.overlayUpdateCount += 1
                }
                continue
            }

            let priorRecordMetrics = tileRecords[tile.coordinate].map { runtimeTreeMetrics($0.root) }
            let replacement: TileRenderRecord
            if let existing = tileRecords[tile.coordinate],
               existing.signature.matchesNonSpatialFields(of: signature),
               existing.overlaySignature == overlaySignature {
                replacement = makeSpatiallyUpdatedTileRecord(
                    reusing: existing,
                    tile: tile,
                    consequence: consequence,
                    overlay: overlay,
                    signature: signature
                )
            } else {
                replacement = makeTileRecord(
                    tile: tile,
                    consequence: consequence,
                    state: state,
                    overlay: overlay,
                    signature: signature,
                    overlaySignature: overlaySignature
                )
            }
            if let existing = tileRecords.updateValue(replacement, forKey: tile.coordinate) {
                applyRuntimeDelta(
                    from: priorRecordMetrics ?? runtimeTreeMetrics(existing.root),
                    to: runtimeTreeMetrics(replacement.root),
                    diagnostics: &diagnostics
                )
                existing.root.removeFromParent()
                diagnostics.updatedTileCount += 1
                diagnostics.updatedCoordinates.insert(tile.coordinate)
            } else {
                applyRuntimeDelta(
                    from: RuntimeTreeMetrics(nodes: 0, drawables: 0, actions: 0),
                    to: runtimeTreeMetrics(replacement.root),
                    diagnostics: &diagnostics
                )
                diagnostics.createdTileCount += 1
            }
            tileLayer.addChild(replacement.root)
        }

        diagnostics.totalTileCount = tileRecords.count
        diagnostics.updateDurationMilliseconds =
            (ProcessInfo.processInfo.systemUptime - updateStarted) * 1_000
        return diagnostics
    }

    private func makeSpatiallyUpdatedTileRecord(
        reusing existing: TileRenderRecord,
        tile: CityTile,
        consequence: CitySpatialConsequence,
        overlay: DataOverlay,
        signature: TileRenderSignature
    ) -> TileRenderRecord {
        let root = SKNode()
        root.position = existing.root.position
        root.zPosition = existing.root.zPosition
        root.name = existing.root.name
        for layerName in ["terrain.layer", "overlay.layer", "content.layer"] {
            if let layer = existing.root.childNode(withName: layerName) {
                layer.removeFromParent()
                root.addChild(layer)
            }
        }

        let consequenceLayer = SKNode()
        consequenceLayer.name = "spatial.layer"
        consequenceLayer.zPosition = 72
        consequenceLayer.addChild(spatialConsequenceRenderer.makePersistentCues(
            for: consequence,
            detail: currentCameraDetailLevel
        ))
        updatePersistentConsequenceEmphasis(in: consequenceLayer, overlay: overlay)
        root.addChild(consequenceLayer)
        return TileRenderRecord(
            root: root,
            overlayLayer: existing.overlayLayer,
            consequenceLayer: consequenceLayer,
            signature: signature,
            overlaySignature: existing.overlaySignature
        )
    }

    private func changedRenderCoordinates(
        from previous: CityPresentationSnapshot?,
        to current: CityPresentationSnapshot,
        canReuseOverlay: Bool
    ) -> Set<GridCoordinate>? {
        guard canReuseOverlay,
              let previous,
              previous.state.gridWidth == current.state.gridWidth,
              previous.state.gridHeight == current.state.gridHeight,
              previous.state.tiles.count == current.state.tiles.count,
              previous.spatialConsequences.samples.count == current.spatialConsequences.samples.count else {
            return nil
        }

        var changed: Set<GridCoordinate> = []
        for index in current.state.tiles.indices {
            let oldTile = previous.state.tiles[index]
            let newTile = current.state.tiles[index]
            let oldConsequence = previous.spatialConsequences.samples[index]
            let newConsequence = current.spatialConsequences.samples[index]
            guard oldTile.coordinate == newTile.coordinate,
                  oldConsequence.coordinate == newConsequence.coordinate,
                  newTile.coordinate == newConsequence.coordinate else {
                return nil
            }
            if oldTile != newTile
                || SpatialConsequenceRenderSignature(oldConsequence)
                    != SpatialConsequenceRenderSignature(newConsequence) {
                changed.insert(newTile.coordinate)
            }
            if (oldTile.kind == .road) != (newTile.kind == .road) {
                changed.formUnion(orthogonalCoordinates(around: newTile.coordinate, in: current.state))
            }
        }
        return changed
    }

    private func orthogonalCoordinates(
        around coordinate: GridCoordinate,
        in state: CityGameState
    ) -> [GridCoordinate] {
        [
            GridCoordinate(x: coordinate.x, y: coordinate.y - 1),
            GridCoordinate(x: coordinate.x + 1, y: coordinate.y),
            GridCoordinate(x: coordinate.x, y: coordinate.y + 1),
            GridCoordinate(x: coordinate.x - 1, y: coordinate.y),
        ].filter {
            $0.x >= 0 && $0.x < state.gridWidth && $0.y >= 0 && $0.y < state.gridHeight
        }
    }

    private func makeTileRecord(
        tile: CityTile,
        consequence: CitySpatialConsequence,
        state: CityGameState,
        overlay: DataOverlay,
        signature: TileRenderSignature,
        overlaySignature: OverlayRenderSignature
    ) -> TileRenderRecord {
        let root = SKNode()
        root.position = style.isoPosition(tile.coordinate)
        root.zPosition = style.depth(for: tile.coordinate)
            + CGFloat(tile.coordinate.x) * 0.01
            + CGFloat(tile.coordinate.y) * 0.0001
        root.name = "tile:\(tile.coordinate.x):\(tile.coordinate.y)"

        let terrainLayer = SKNode()
        terrainLayer.name = "terrain.layer"
        terrainLayer.addChild(terrainRenderer.makeGround(for: tile, detail: currentCameraDetailLevel))
        terrainLayer.addChild(terrainRenderer.makeMapEdge(
            for: tile.coordinate,
            gridWidth: state.gridWidth,
            gridHeight: state.gridHeight,
            detail: currentCameraDetailLevel
        ))
        root.addChild(terrainLayer)

        let overlayLayer = SKNode()
        overlayLayer.name = "overlay.layer"
        overlayLayer.zPosition = 20
        root.addChild(overlayLayer)
        updateOverlay(
            in: overlayLayer,
            tile: tile,
            consequence: consequence,
            state: state,
            overlay: overlay
        )

        let contentLayer = SKNode()
        contentLayer.name = "content.layer"
        contentLayer.zPosition = 40
        switch tile.kind {
        case .empty:
            break
        case .road:
            contentLayer.addChild(roadRenderer.makeRoad(
                at: tile.coordinate,
                in: state,
                detail: currentCameraDetailLevel,
                reducedMotion: reducedMotion
            ))
        default:
            contentLayer.addChild(lotRenderer.makeLot(
                for: tile,
                adjacentRoads: RoadConnectionMask.resolving(at: tile.coordinate, in: state),
                detail: currentCameraDetailLevel,
                reducedMotion: reducedMotion
            ))
        }
        root.addChild(contentLayer)

        let consequenceLayer = SKNode()
        consequenceLayer.name = "spatial.layer"
        consequenceLayer.zPosition = 72
        consequenceLayer.addChild(spatialConsequenceRenderer.makePersistentCues(
            for: consequence,
            detail: currentCameraDetailLevel
        ))
        updatePersistentConsequenceEmphasis(in: consequenceLayer, overlay: overlay)
        root.addChild(consequenceLayer)
        return TileRenderRecord(
            root: root,
            overlayLayer: overlayLayer,
            consequenceLayer: consequenceLayer,
            signature: signature,
            overlaySignature: overlaySignature
        )
    }

    private func updatePersistentConsequenceEmphasis(in layer: SKNode, overlay: DataOverlay) {
        layer.childNode(withName: "spatial.consequences")?.alpha = overlay == .none ? 0.16 : 0.82
    }

    private func tileSignature(
        for tile: CityTile,
        consequence: CitySpatialConsequence,
        state: CityGameState
    ) -> TileRenderSignature {
        let lotPresentation: LotConsequencePresentation?
        switch tile.kind {
        case .empty, .road:
            lotPresentation = nil
        default:
            lotPresentation = LotConsequencePresentation(tile: tile)
        }
        return TileRenderSignature(
            kind: tile.kind,
            lotPresentation: lotPresentation,
            spatialConsequences: SpatialConsequenceRenderSignature(consequence),
            reducedMotion: lotPresentation == nil ? false : reducedMotion,
            roadConnections: tile.kind == .empty
                ? []
                : RoadConnectionMask.resolving(at: tile.coordinate, in: state),
            gridWidth: state.gridWidth,
            gridHeight: state.gridHeight
        )
    }

    private func overlaySignature(
        for tile: CityTile,
        consequence: CitySpatialConsequence,
        state: CityGameState,
        overlay: DataOverlay
    ) -> OverlayRenderSignature {
        OverlayRenderSignature(
            overlay: overlay,
            colorToken: overlayRenderer.color(
                for: tile,
                state: state,
                consequence: consequence,
                overlay: overlay
            ).map(colorToken) ?? 0
        )
    }

    private func updateOverlay(
        in layer: SKNode,
        tile: CityTile,
        consequence: CitySpatialConsequence,
        state: CityGameState,
        overlay: DataOverlay
    ) {
        layer.removeAllChildren()
        layer.addChild(overlayRenderer.makeOverlay(
            for: tile,
            state: state,
            consequence: consequence,
            overlay: overlay,
            detail: currentCameraDetailLevel
        ))
    }

    private func presentConsequenceEvents(_ events: [CitySpatialConsequenceEvent]) -> Int {
        guard let state = renderedState else { return 0 }
        let visible = events.filter { event in
            guard let tile = state.tile(at: event.coordinate) else { return false }
            return tile.kind != .empty && tile.kind != .road && tile.constructionProgress >= 1
        }
        let summarized = Dictionary(grouping: visible, by: \.coordinate).compactMap { _, events in
            events.sorted(by: consequenceEventPriority).first
        }.sorted { lhs, rhs in
            if lhs.coordinate.y != rhs.coordinate.y { return lhs.coordinate.y < rhs.coordinate.y }
            return lhs.coordinate.x < rhs.coordinate.x
        }
        var insertedCount = 0
        for event in summarized {
            guard let layer = tileRecords[event.coordinate]?.consequenceLayer else { continue }
            for prior in layer.children where prior.name?.hasPrefix("spatial.event.") == true {
                subtractRuntimeMetrics(runtimeTreeMetrics(prior), from: &diagnosticsSnapshot)
                prior.removeFromParent()
            }
            let cue = spatialConsequenceRenderer.makeEventCue(
                for: event,
                reducedMotion: reducedMotion
            )
            layer.addChild(cue)
            addRuntimeMetrics(runtimeTreeMetrics(cue), to: &diagnosticsSnapshot)
            displayedConsequenceEventExpiryTicks[event.coordinate] = event.authoritativeTick + 4
            insertedCount += 1
        }
        return insertedCount
    }

    private func expireConsequenceEvents(at authoritativeTick: Int) -> Int {
        let expired = displayedConsequenceEventExpiryTicks.filter {
            authoritativeTick >= $0.value
        }.map(\.key)
        var removedCount = 0
        for coordinate in expired {
            if let layer = tileRecords[coordinate]?.consequenceLayer {
                for child in layer.children where child.name?.hasPrefix("spatial.event.") == true {
                    subtractRuntimeMetrics(runtimeTreeMetrics(child), from: &diagnosticsSnapshot)
                    child.removeFromParent()
                    removedCount += 1
                }
            }
            displayedConsequenceEventExpiryTicks.removeValue(forKey: coordinate)
        }
        return removedCount
    }

    private func currentDisplayedConsequenceCueCount() -> Int {
        tileRecords.values.reduce(0) { count, record in
            count + record.consequenceLayer.children.filter {
                $0.name?.hasPrefix("spatial.event.") == true
            }.count
        }
    }

    private func refreshRuntimeDiagnostics(
        consumedEventCount: Int,
        displayedCueCount: Int,
        requiresTreeRecount: Bool
    ) {
        if requiresTreeRecount {
            let metrics = runtimeTreeMetrics(worldLayer)
            diagnosticsSnapshot.nodeCount = metrics.nodes - 1
            diagnosticsSnapshot.drawableNodeCount = metrics.drawables
            diagnosticsSnapshot.activeActionCount = metrics.actions
        }
        diagnosticsSnapshot.consumedConsequenceEventCount = consumedEventCount
        diagnosticsSnapshot.displayedConsequenceCueCount = displayedCueCount
    }

    private func runtimeTreeMetrics(_ node: SKNode) -> RuntimeTreeMetrics {
        RuntimeTreeMetrics(
            nodes: 1 + recursiveNodeCount(node),
            drawables: recursiveDrawableNodeCount(node),
            actions: recursiveActiveActionCount(node)
        )
    }

    private func applyRuntimeDelta(
        from old: RuntimeTreeMetrics,
        to new: RuntimeTreeMetrics,
        diagnostics: inout RendererDiagnosticsSnapshot
    ) {
        diagnostics.nodeCount += new.nodes - old.nodes
        diagnostics.drawableNodeCount += new.drawables - old.drawables
        diagnostics.activeActionCount += new.actions - old.actions
    }

    private func addRuntimeMetrics(
        _ metrics: RuntimeTreeMetrics,
        to diagnostics: inout RendererDiagnosticsSnapshot
    ) {
        diagnostics.nodeCount += metrics.nodes
        diagnostics.drawableNodeCount += metrics.drawables
        diagnostics.activeActionCount += metrics.actions
    }

    private func subtractRuntimeMetrics(
        _ metrics: RuntimeTreeMetrics,
        from diagnostics: inout RendererDiagnosticsSnapshot
    ) {
        diagnostics.nodeCount -= metrics.nodes
        diagnostics.drawableNodeCount -= metrics.drawables
        diagnostics.activeActionCount -= metrics.actions
    }

    private func consequenceEventPriority(
        _ lhs: CitySpatialConsequenceEvent,
        _ rhs: CitySpatialConsequenceEvent
    ) -> Bool {
        if lhs.direction != rhs.direction { return lhs.direction == .worsening }
        let order: [CitySpatialConsequenceDimension: Int] = [
            .utility: 0,
            .pollution: 1,
            .vitality: 2
        ]
        return order[lhs.dimension, default: 99] < order[rhs.dimension, default: 99]
    }

    private func colorToken(_ color: NSColor) -> UInt32 {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return 0 }
        let red = UInt32((rgb.redComponent * 255).rounded())
        let green = UInt32((rgb.greenComponent * 255).rounded())
        let blue = UInt32((rgb.blueComponent * 255).rounded())
        let alpha = UInt32((rgb.alphaComponent * 255).rounded())
        return red << 24 | green << 16 | blue << 8 | alpha
    }

    private func refreshForCameraChange(preservingUpdateDiagnostics: Bool = false) {
        let detail = style.detailLevel(cameraScale: cameraNode.xScale)
        guard detail != currentCameraDetailLevel else { return }
        currentCameraDetailLevel = detail
        assets.prepareGeneratedResidency(for: detail)
        for record in tileRecords.values {
            updateGeneratedLOD(in: record.root, detail: detail)
            style.updateDetailVisibility(in: record.root, detail: detail)
        }
        if preservingUpdateDiagnostics {
            diagnosticsSnapshot.detailLevel = detail
        } else {
            diagnosticsSnapshot = RendererDiagnosticsSnapshot(
                totalTileCount: tileRecords.count,
                reusedTileCount: tileRecords.count,
                nodeCount: diagnosticsSnapshot.nodeCount,
                drawableNodeCount: diagnosticsSnapshot.drawableNodeCount,
                activeActionCount: diagnosticsSnapshot.activeActionCount,
                detailLevel: detail
            )
        }
        updateSelection(renderedSelection)
        if let hoveredCoordinate { updateBuildPreview(at: hoveredCoordinate) }
    }

    private func updateGeneratedLOD(in node: SKNode, detail: CameraDetailLevel) {
        if let sprite = node as? SKSpriteNode,
           let name = sprite.name,
           name.hasPrefix("lot.generated-v4.") {
            let components = name.split(separator: ".")
            if components.count >= 4 {
                let logicalID = String(components[2])
                assets.applyGeneratedLOD(
                    to: sprite,
                    logicalID: logicalID,
                    detail: detail,
                    semanticName: "lot.generated-v4.\(logicalID).\(detail.assetSuffix)"
                )
            }
        }
        for child in node.children {
            updateGeneratedLOD(in: child, detail: detail)
        }
    }

    private func recursiveNodeCount(_ node: SKNode) -> Int {
        node.children.reduce(node.children.count) { $0 + recursiveNodeCount($1) }
    }

    private func recursiveDrawableNodeCount(_ node: SKNode) -> Int {
        let localCount = node is SKShapeNode || node is SKSpriteNode || node is SKLabelNode ? 1 : 0
        return node.children.reduce(localCount) { $0 + recursiveDrawableNodeCount($1) }
    }

    private func recursiveActiveActionCount(_ node: SKNode) -> Int {
        let localCount = node.hasActions() ? 1 : 0
        return node.children.reduce(localCount) { $0 + recursiveActiveActionCount($1) }
    }

    private func updateSelection(_ coordinate: GridCoordinate?) {
        guard let coordinate else {
            selectionNode.removeAction(forKey: "selection.pulse")
            selectionNode.isHidden = true
            selectionLabel.text = nil
            return
        }
        selectionLabel.text = "SELECTED"
        selectionNode.position = style.isoPosition(coordinate)
        selectionNode.isHidden = false
        if reducedMotion {
            selectionNode.removeAction(forKey: "selection.pulse")
            selectionNode.alpha = 1
        } else if selectionNode.action(forKey: "selection.pulse") == nil {
            selectionNode.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.72, duration: 0.72),
                .fadeAlpha(to: 1, duration: 0.72)
            ])), withKey: "selection.pulse")
        }
    }

    private func updateBuildPreview(at coordinate: GridCoordinate) {
        guard let state = renderedState else { return }
        let status = interactionPreviewStatus(at: coordinate, state: state)
        let signature = InteractionPreviewSignature(
            coordinate: coordinate,
            status: status,
            detail: currentCameraDetailLevel
        )
        guard signature != lastPreviewSignature else { return }
        lastPreviewSignature = signature
        hoverNode.removeAllChildren()

        let presentation = previewPresentation(status, coordinate: coordinate)
        let color = presentation.color
        hoverNode.fillColor = color.withAlphaComponent(0.16)
        hoverNode.strokeColor = color.withAlphaComponent(0.96)
        hoverNode.lineWidth = presentation.isBlocked ? 4 : 3

        if case .validBuild(let kind) = status {
            addPlacementGhost(kind, at: coordinate, state: state, alpha: 0.54, to: hoverNode)
        } else if case .invalidBuild(let kind, _) = status {
            addPlacementGhost(kind, at: coordinate, state: state, alpha: 0.24, to: hoverNode)
        }
        if presentation.isBlocked {
            addInvalidHatch(color: color, to: hoverNode)
        }
        addStatusMark(presentation.marker, color: color, to: hoverNode)
        addPreviewLabel(
            headline: presentation.headline,
            detail: presentation.detail,
            color: color,
            horizontalOffset: coordinate.x >= state.gridWidth / 2 ? -118 : 118,
            to: hoverNode
        )
    }

    private func interactionPreviewStatus(
        at coordinate: GridCoordinate,
        state: CityGameState
    ) -> InteractionPreviewStatus {
        switch renderedInteractionMode {
        case .inspect:
            return .inspect(state.tile(at: coordinate)?.kind ?? .empty)
        case .build(let kind):
            switch CitySimulation.validateBuild(kind, at: coordinate, in: state) {
            case .success: return .validBuild(kind)
            case .failure(let rejection): return .invalidBuild(kind, rejection)
            }
        case .bulldoze:
            guard let tile = state.tile(at: coordinate) else {
                return .invalidBulldoze("Outside the city boundary")
            }
            if tile.kind == .cityHall { return .invalidBulldoze("City Hall is a protected landmark") }
            if tile.kind == .empty { return .invalidBulldoze("There is nothing to demolish") }
            return .validBulldoze(tile.kind)
        }
    }

    private func previewPresentation(
        _ status: InteractionPreviewStatus,
        coordinate: GridCoordinate
    ) -> (headline: String, detail: String, marker: String, color: NSColor, isBlocked: Bool) {
        switch status {
        case .inspect(let kind):
            return (
                "INSPECT · \(kind.title.uppercased())",
                "Block \(coordinate.x + 1), \(coordinate.y + 1) · Click for details",
                "i",
                .white,
                false
            )
        case .validBuild(let kind):
            return (
                "VALID · \(kind.title.uppercased())",
                "Cost \(currency(kind.buildCost)) · Upkeep \(currency(kind.upkeep))/cycle",
                "OK",
                .systemGreen,
                false
            )
        case .invalidBuild(let kind, let rejection):
            return (
                rejection == .uniqueBuildingExists ? "PROTECTED · \(kind.title.uppercased())" : "BLOCKED · \(kind.title.uppercased())",
                rejection.message,
                "X",
                rejection == .uniqueBuildingExists ? .systemOrange : .systemRed,
                true
            )
        case .validBulldoze(let kind):
            let cost = kind.demolitionCost
            return (
                "BULLDOZE · \(kind.title.uppercased())",
                "Demolition \(currency(cost)) · Undo available",
                "X",
                .systemRed,
                false
            )
        case .invalidBulldoze(let reason):
            return (
                reason.contains("protected") ? "PROTECTED" : "BLOCKED",
                reason,
                "!",
                reason.contains("protected") ? .systemOrange : .systemGray,
                true
            )
        }
    }

    private func addPlacementGhost(
        _ kind: BuildingKind,
        at coordinate: GridCoordinate,
        state: CityGameState,
        alpha: CGFloat,
        to node: SKNode
    ) {
        let ghost: SKNode
        if kind == .road {
            ghost = roadRenderer.makeRoad(
                at: coordinate,
                connections: RoadConnectionMask.resolving(at: coordinate, in: state),
                detail: max(currentCameraDetailLevel, .neighborhood),
                reducedMotion: true
            )
        } else {
            let previewTile = CityTile(
                coordinate: coordinate,
                kind: kind,
                level: 1,
                occupancy: 0,
                condition: 1,
                constructionProgress: 1
            )
            ghost = lotRenderer.makeLot(
                for: previewTile,
                detail: max(currentCameraDetailLevel, .neighborhood),
                reducedMotion: true
            )
        }
        ghost.name = "interaction.placementGhost"
        ghost.alpha = alpha
        ghost.setScale(0.86)
        ghost.position.y = 2
        ghost.zPosition = 2
        node.addChild(ghost)
    }

    private func addInvalidHatch(color: NSColor, to node: SKNode) {
        for index in -2...2 {
            let x = CGFloat(index) * 8
            let hatch = SKShapeNode(path: WorldGeometryCache.line(
                from: CGPoint(x: x - 9, y: -10),
                to: CGPoint(x: x + 9, y: 10)
            ))
            hatch.strokeColor = color.withAlphaComponent(0.72)
            hatch.lineWidth = 1.7
            hatch.zPosition = 10
            hatch.name = "interaction.invalidHatch"
            node.addChild(hatch)
        }
    }

    private func addStatusMark(_ text: String, color: NSColor, to node: SKNode) {
        let marker = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
        marker.text = text
        marker.fontSize = text.count > 1 ? 8 : 13
        marker.fontColor = color
        marker.verticalAlignmentMode = .center
        marker.horizontalAlignmentMode = .center
        marker.position = CGPoint(x: 0, y: 5)
        marker.zPosition = 14
        marker.name = "interaction.preview.marker"
        node.addChild(marker)
    }

    private func addPreviewLabel(
        headline: String,
        detail: String,
        color: NSColor,
        horizontalOffset: CGFloat,
        to node: SKNode
    ) {
        let panel = SKShapeNode(rectOf: CGSize(width: 204, height: 34), cornerRadius: 7)
        panel.fillColor = NSColor(calibratedWhite: 0.055, alpha: 0.92)
        panel.strokeColor = color.withAlphaComponent(0.86)
        panel.lineWidth = 1.2
        panel.position = CGPoint(x: horizontalOffset, y: 50)
        panel.zPosition = 20
        panel.name = "interaction.preview.panel"

        let headlineNode = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
        headlineNode.text = headline
        headlineNode.fontSize = 8.5
        headlineNode.fontColor = .white
        headlineNode.verticalAlignmentMode = .center
        headlineNode.position.y = 7
        headlineNode.name = "interaction.preview.headline"
        panel.addChild(headlineNode)

        let detailNode = SKLabelNode(fontNamed: ".AppleSystemUIFont")
        detailNode.text = detail
        detailNode.fontSize = 7
        detailNode.fontColor = NSColor.white.withAlphaComponent(0.76)
        detailNode.verticalAlignmentMode = .center
        detailNode.position.y = -7
        detailNode.name = "interaction.preview.detail"
        panel.addChild(detailNode)
        node.addChild(panel)
    }

    private func currency(_ amount: Double) -> String {
        "$\(Int(amount.rounded()).formatted())"
    }

    private func fitCity(_ state: CityGameState) {
        let worldWidth = CGFloat(state.gridWidth + state.gridHeight) * tileWidth / 2
        let worldHeight = CGFloat(state.gridWidth + state.gridHeight) * tileHeight / 2 + 140
        let scale = max(worldWidth / max(600, size.width - 120), worldHeight / max(400, size.height - 180)) * 1.08
        cameraNode.position = CGPoint(x: 0, y: -CGFloat(state.gridWidth + state.gridHeight) * tileHeight / 4 + 20)
        cameraNode.setScale(min(2.2, max(0.55, scale)))
    }

    private func focusDevelopedCore(_ state: CityGameState) {
        applyDevelopedCoreCamera(state)
        refreshForCameraChange(preservingUpdateDiagnostics: true)
    }

    private func applyDevelopedCoreCamera(_ state: CityGameState) {
        let bounds = developedVisualBounds(in: state)
        guard !bounds.isNull, !bounds.isEmpty else { fitCity(state); return }
        developedVisualBoundsForTesting = bounds

        let safeWidth = max(420, size.width - viewportInsets.leading - viewportInsets.trailing)
        let safeHeight = max(260, size.height - viewportInsets.top - viewportInsets.bottom)
        let targetOccupancy: CGFloat = 0.64
        var scale = max(
            bounds.width / (safeWidth * targetOccupancy),
            bounds.height / (safeHeight * targetOccupancy)
        )
#if DEBUG
        if let proofScale = ProcessInfo.processInfo.environment["CITYSIM_PROOF_CAMERA_SCALE"]
            .flatMap(Double.init) {
            scale = CGFloat(proofScale)
        }
#endif
        scale = min(1.55, max(0.38, scale))
        cameraNode.setScale(scale)

        let safeCenterOffset = CGPoint(
            x: (viewportInsets.leading - viewportInsets.trailing) * scale / 2,
            y: (viewportInsets.bottom - viewportInsets.top) * scale / 2
        )
        cameraNode.position = CGPoint(
            x: bounds.midX - safeCenterOffset.x,
            y: bounds.midY - safeCenterOffset.y
        )
    }

    private func developedVisualBounds(in state: CityGameState) -> CGRect {
        let developed = state.tiles.filter { ![.empty, .road].contains($0.kind) }
        guard !developed.isEmpty else { return .null }
        let developedCoordinates = Set(developed.map(\.coordinate))
        let nearbyRoads = state.tiles.filter { tile in
            guard tile.kind == .road else { return false }
            return developedCoordinates.contains { coordinate in
                abs(coordinate.x - tile.coordinate.x) + abs(coordinate.y - tile.coordinate.y) <= 3
            }
        }
        let expansionSockets = state.tiles.filter { tile in
            guard tile.kind == .empty else { return false }
            return RoadConnectionMask.cardinalEdges.contains { edge in
                let delta = edge.coordinateDelta
                return state.tile(at: GridCoordinate(
                    x: tile.coordinate.x + delta.x,
                    y: tile.coordinate.y + delta.y
                ))?.kind == .road
            }
        }.sorted { lhs, rhs in
            let lhsDistance = developedCoordinates.map {
                abs($0.x - lhs.coordinate.x) + abs($0.y - lhs.coordinate.y)
            }.min() ?? .max
            let rhsDistance = developedCoordinates.map {
                abs($0.x - rhs.coordinate.x) + abs($0.y - rhs.coordinate.y)
            }.min() ?? .max
            if lhsDistance == rhsDistance {
                return (lhs.coordinate.y, lhs.coordinate.x) < (rhs.coordinate.y, rhs.coordinate.x)
            }
            return lhsDistance < rhsDistance
        }.prefix(3)

        var bounds = CGRect.null
        for tile in developed {
            let position = style.isoPosition(tile.coordinate)
            if tile.level == 1,
               let logicalID = generatedLogicalID(for: tile.kind),
               let asset = assets.generatedAsset(logicalID: logicalID),
               asset.opaqueBoundsWorld.count == 4 {
                let physical = asset.opaqueBoundsWorld
                bounds = bounds.union(CGRect(
                    x: position.x + physical[0],
                    y: position.y + physical[1],
                    width: physical[2] - physical[0],
                    height: physical[3] - physical[1]
                ))
            } else {
                bounds = bounds.union(CGRect(
                    x: position.x - tileWidth / 2,
                    y: position.y - tileHeight / 2,
                    width: tileWidth,
                    height: tileHeight + 64
                ))
            }
        }
        for tile in nearbyRoads + Array(expansionSockets) {
            let position = style.isoPosition(tile.coordinate)
            bounds = bounds.union(CGRect(
                x: position.x - tileWidth / 2,
                y: position.y - tileHeight / 2,
                width: tileWidth,
                height: tileHeight
            ))
        }
        return bounds.insetBy(dx: -28, dy: -20)
    }

    private func generatedLogicalID(for kind: BuildingKind) -> String? {
        switch kind {
        case .residential: "residential_l01"
        case .commercial: "commercial_l01"
        case .industrial: "industrial_l01"
        case .park: "park_l01"
        case .cityHall: "city_hall_l01"
        case .waterTower: "water_tower_l01"
        default: nil
        }
    }

    private func coordinate(at scenePoint: CGPoint) -> GridCoordinate? {
        let hoverHidden = hoverNode.isHidden
        let selectionHidden = selectionNode.isHidden
        hoverNode.isHidden = true
        selectionNode.isHidden = true
        var node: SKNode? = atPoint(scenePoint)
        hoverNode.isHidden = hoverHidden
        selectionNode.isHidden = selectionHidden
        while let current = node {
            if let name = current.name, name.hasPrefix("tile:") {
                let parts = name.split(separator: ":")
                if parts.count == 3, let x = Int(parts[1]), let y = Int(parts[2]) { return GridCoordinate(x: x, y: y) }
            }
            node = current.parent
        }
        return nil
    }

    private func configureSelectionAdornment() {
        let raisedOutline = SKShapeNode(path: style.diamondPath(
            width: tileWidth * 0.88,
            height: tileHeight * 0.88
        ))
        raisedOutline.fillColor = .clear
        raisedOutline.strokeColor = NSColor.white.withAlphaComponent(0.92)
        raisedOutline.lineWidth = 1.4
        raisedOutline.position.y = 5
        raisedOutline.zPosition = 2
        selectionNode.addChild(raisedOutline)

        let corners = [
            CGPoint(x: 0, y: tileHeight / 2),
            CGPoint(x: tileWidth / 2, y: 0),
            CGPoint(x: 0, y: -tileHeight / 2),
            CGPoint(x: -tileWidth / 2, y: 0)
        ]
        for point in corners {
            let bracket = SKShapeNode(rectOf: CGSize(width: 5, height: 5), cornerRadius: 1)
            bracket.fillColor = .white
            bracket.strokeColor = style.palette.civicRoof
            bracket.lineWidth = 1
            bracket.position = point
            bracket.zPosition = 4
            selectionNode.addChild(bracket)
        }

        let beam = SKShapeNode(path: WorldGeometryCache.line(
            from: CGPoint(x: 0, y: tileHeight / 2 + 2),
            to: CGPoint(x: 0, y: 57)
        ))
        beam.strokeColor = style.palette.glass.withAlphaComponent(0.72)
        beam.lineWidth = 2.2
        beam.zPosition = 3
        selectionNode.addChild(beam)

        let cap = SKShapeNode(circleOfRadius: 4)
        cap.fillColor = style.palette.civicRoof
        cap.strokeColor = .white
        cap.lineWidth = 1.2
        cap.position.y = 59
        cap.zPosition = 4
        selectionNode.addChild(cap)

        selectionLabel.text = nil
        selectionLabel.fontSize = 7.5
        selectionLabel.fontColor = .white
        selectionLabel.position = CGPoint(x: 0, y: 66)
        selectionLabel.zPosition = 5
        selectionNode.addChild(selectionLabel)
    }

    private func configureHighlight(_ node: SKShapeNode, color: NSColor, alpha: CGFloat, z: CGFloat) {
        node.path = style.diamondPath(width: tileWidth, height: tileHeight)
        node.fillColor = color.withAlphaComponent(alpha * 0.32)
        node.strokeColor = color.withAlphaComponent(alpha)
        node.lineWidth = 2.5
        node.zPosition = z
    }

}
