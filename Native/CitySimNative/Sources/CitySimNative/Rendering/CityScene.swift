import AppKit
import SpriteKit

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
    var updateDurationMilliseconds = 0.0
    var detailLevel: CameraDetailLevel = .neighborhood
    var updatedCoordinates: Set<GridCoordinate> = []
}

private struct TileRenderSignature: Equatable {
    let kind: BuildingKind
    let lotPresentation: LotConsequencePresentation?
    let reducedMotion: Bool
    let roadConnections: RoadConnectionMask
    let gridWidth: Int
    let gridHeight: Int
}

private struct OverlayRenderSignature: Equatable {
    let overlay: DataOverlay
    let colorToken: UInt32
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
    let signature: TileRenderSignature
    var overlaySignature: OverlayRenderSignature

    init(
        root: SKNode,
        overlayLayer: SKNode,
        signature: TileRenderSignature,
        overlaySignature: OverlayRenderSignature
    ) {
        self.root = root
        self.overlayLayer = overlayLayer
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
    private let terrainRenderer: TerrainRenderer
    private let roadRenderer: RoadRenderer
    private let lotRenderer: LotRenderer
    private let overlayRenderer: WorldOverlayRenderer
    private let worldLayer = SKNode()
    private let backdropLayer = SKNode()
    private let tileLayer = SKNode()
    private let cameraNode = SKCameraNode()
    private let hoverNode = SKShapeNode()
    private let selectionNode = SKShapeNode()
    private let selectionLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
    private var renderedState: CityGameState?
    private var renderedOverlay: DataOverlay = .none
    private var renderedSelection: GridCoordinate?
    private var renderedInteractionMode: CityInteractionMode = .inspect
    private var hoveredCoordinate: GridCoordinate?
    private var lastPreviewSignature: InteractionPreviewSignature?
    private var renderedGridSize: CGSize?
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

    override init(size: CGSize) {
        let style = WorldVisualStyle()
        self.style = style
        self.terrainRenderer = TerrainRenderer(style: style)
        self.roadRenderer = RoadRenderer(style: style)
        self.lotRenderer = LotRenderer(style: style)
        self.overlayRenderer = WorldOverlayRenderer(style: style)
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
        state: CityGameState,
        overlay: DataOverlay,
        selection: GridCoordinate?,
        interactionMode: CityInteractionMode
    ) {
        let isFirstRender = renderedState == nil
        let resolvedDetail = style.detailLevel(cameraScale: cameraNode.xScale)
        if resolvedDetail != currentCameraDetailLevel {
            currentCameraDetailLevel = resolvedDetail
            for record in tileRecords.values {
                style.updateDetailVisibility(in: record.root, detail: resolvedDetail)
            }
            lastPreviewSignature = nil
        }
        renderedState = state
        renderedOverlay = overlay
        renderedSelection = selection
        renderedInteractionMode = interactionMode
        diagnosticsSnapshot = updateWorld(state: state, overlay: overlay)
        updateSelection(selection)
        if let hoveredCoordinate { updateBuildPreview(at: hoveredCoordinate) }
        if isFirstRender { focusDevelopedCore(state) }
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
        size = newSize
    }

    func frameCity() {
        if let state = renderedState {
            fitCity(state)
            refreshForCameraChange()
        }
    }

    func tileRootIdentifier(at coordinate: GridCoordinate) -> ObjectIdentifier? {
        tileRecords[coordinate].map { ObjectIdentifier($0.root) }
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

    func revealSelection(_ coordinate: GridCoordinate) {
        let target = style.isoPosition(coordinate)
        let horizontalInset = max(tileWidth * 2, size.width * cameraNode.xScale * 0.34)
        let verticalInset = max(tileHeight * 2, size.height * cameraNode.yScale * 0.30)
        let dx = target.x - cameraNode.position.x
        let dy = target.y - cameraNode.position.y
        if abs(dx) > horizontalInset {
            cameraNode.position.x = target.x - copysign(horizontalInset, dx)
        }
        if abs(dy) > verticalInset {
            cameraNode.position.y = target.y - copysign(verticalInset, dy)
        }
        refreshForCameraChange()
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
        refreshForCameraChange()
    }

    private func updateWorld(state: CityGameState, overlay: DataOverlay) -> RendererDiagnosticsSnapshot {
        let updateStarted = ProcessInfo.processInfo.systemUptime
        var diagnostics = RendererDiagnosticsSnapshot(
            nodeCount: diagnosticsSnapshot.nodeCount,
            drawableNodeCount: diagnosticsSnapshot.drawableNodeCount,
            activeActionCount: diagnosticsSnapshot.activeActionCount,
            detailLevel: currentCameraDetailLevel
        )
        let gridSize = CGSize(width: state.gridWidth, height: state.gridHeight)
        if renderedGridSize != gridSize {
            renderedGridSize = gridSize
            backdropLayer.removeAllChildren()
            backdropLayer.addChild(terrainRenderer.makeBackdrop(gridWidth: state.gridWidth, gridHeight: state.gridHeight))
        }

        let desiredCoordinates = Set(state.tiles.map(\.coordinate))
        let removed = tileRecords.keys.filter { !desiredCoordinates.contains($0) }
        for coordinate in removed {
            tileRecords.removeValue(forKey: coordinate)?.root.removeFromParent()
        }
        diagnostics.removedTileCount = removed.count

        let sortedTiles = state.tiles.sorted { lhs, rhs in
            let lhsDepth = lhs.coordinate.x + lhs.coordinate.y
            let rhsDepth = rhs.coordinate.x + rhs.coordinate.y
            if lhsDepth != rhsDepth { return lhsDepth < rhsDepth }
            if lhs.coordinate.x != rhs.coordinate.x { return lhs.coordinate.x < rhs.coordinate.x }
            return lhs.coordinate.y < rhs.coordinate.y
        }

        for tile in sortedTiles {
            let signature = tileSignature(for: tile, state: state)
            let overlaySignature = overlaySignature(for: tile, state: state, overlay: overlay)
            if let existing = tileRecords[tile.coordinate], existing.signature == signature {
                diagnostics.reusedTileCount += 1
                if existing.overlaySignature != overlaySignature {
                    updateOverlay(
                        in: existing.overlayLayer,
                        tile: tile,
                        state: state,
                        overlay: overlay
                    )
                    existing.overlaySignature = overlaySignature
                    diagnostics.overlayUpdateCount += 1
                }
                continue
            }

            let replacement = makeTileRecord(
                tile: tile,
                state: state,
                overlay: overlay,
                signature: signature,
                overlaySignature: overlaySignature
            )
            if let existing = tileRecords.updateValue(replacement, forKey: tile.coordinate) {
                existing.root.removeFromParent()
                diagnostics.updatedTileCount += 1
                diagnostics.updatedCoordinates.insert(tile.coordinate)
            } else {
                diagnostics.createdTileCount += 1
            }
            tileLayer.addChild(replacement.root)
        }

        diagnostics.totalTileCount = tileRecords.count
        if diagnostics.createdTileCount > 0 || diagnostics.updatedTileCount > 0
            || diagnostics.removedTileCount > 0 || diagnostics.overlayUpdateCount > 0 {
            diagnostics.nodeCount = recursiveNodeCount(worldLayer)
            diagnostics.drawableNodeCount = recursiveDrawableNodeCount(worldLayer)
            diagnostics.activeActionCount = recursiveActiveActionCount(worldLayer)
        }
        diagnostics.updateDurationMilliseconds =
            (ProcessInfo.processInfo.systemUptime - updateStarted) * 1_000
        return diagnostics
    }

    private func makeTileRecord(
        tile: CityTile,
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
        updateOverlay(in: overlayLayer, tile: tile, state: state, overlay: overlay)

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
        return TileRenderRecord(
            root: root,
            overlayLayer: overlayLayer,
            signature: signature,
            overlaySignature: overlaySignature
        )
    }

    private func tileSignature(for tile: CityTile, state: CityGameState) -> TileRenderSignature {
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
        state: CityGameState,
        overlay: DataOverlay
    ) -> OverlayRenderSignature {
        OverlayRenderSignature(
            overlay: overlay,
            colorToken: overlayRenderer.color(for: tile, state: state, overlay: overlay).map(colorToken) ?? 0
        )
    }

    private func updateOverlay(
        in layer: SKNode,
        tile: CityTile,
        state: CityGameState,
        overlay: DataOverlay
    ) {
        layer.removeAllChildren()
        layer.addChild(overlayRenderer.makeOverlay(
            for: tile,
            state: state,
            overlay: overlay,
            detail: currentCameraDetailLevel
        ))
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
        for record in tileRecords.values {
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
        let developed = state.tiles.filter { ![.empty, .road].contains($0.kind) }
        guard !developed.isEmpty else { fitCity(state); return }
        let points = developed.map { style.isoPosition($0.coordinate) }
        let center = CGPoint(
            x: points.reduce(0) { $0 + $1.x } / CGFloat(points.count),
            y: points.reduce(0) { $0 + $1.y } / CGFloat(points.count) + 30
        )
        cameraNode.position = center
        // Open on the place the player can act on, while keeping road arms and
        // several buildable blocks as honest expansion context. Compact uses a
        // slightly wider lens so the command deck never crowds the neighborhood.
        let defaultScale: CGFloat = size.width <= 980 ? 0.46 : 0.35
#if DEBUG
        let proofScale = ProcessInfo.processInfo.environment["CITYSIM_PROOF_CAMERA_SCALE"]
            .flatMap(Double.init)
            .map { CGFloat($0) }
        cameraNode.setScale(proofScale.map { min(2.2, max(0.35, $0)) } ?? defaultScale)
#else
        cameraNode.setScale(defaultScale)
#endif
        refreshForCameraChange(preservingUpdateDiagnostics: true)
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
