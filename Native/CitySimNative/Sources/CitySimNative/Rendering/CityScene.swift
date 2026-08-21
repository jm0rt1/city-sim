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
    var backdropUpdateDurationMilliseconds = 0.0
    var renderPreparationDurationMilliseconds = 0.0
    var tileBuildDurationMilliseconds = 0.0
    var runtimeTreeMetricsDurationMilliseconds = 0.0
    var worldUpdateDurationMilliseconds = 0.0
    var totalRenderDurationMilliseconds = 0.0
    var assetDecodeLoadCount = 0
    var assetDecodeLoadDurationMilliseconds = 0.0
    var detailLevel: CameraDetailLevel = .neighborhood
    var updatedCoordinates: Set<GridCoordinate> = []

    /// Compatibility name for the historical update-world measurement. This
    /// deliberately excludes camera, ambient, tree-recount, and asset decode.
    var updateDurationMilliseconds: Double { worldUpdateDurationMilliseconds }
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
    case invalidBuild(BuildingKind, String)
    case validBulldoze(BuildingKind)
    case invalidBulldoze(String)
}

private struct InteractionPreviewSignature: Equatable {
    let coordinate: GridCoordinate
    let status: InteractionPreviewStatus
    let detail: CameraDetailLevel
    let selectedCoordinate: GridCoordinate?
}

private struct AmbientContextSignature: Equatable {
    let layoutRoles: [UInt8]
    let detail: CameraDetailLevel
    let reducedMotion: Bool
    let motionEnabled: Bool
}

private struct AmbientActivitySignature: Equatable {
    let domain: AmbientLifeRenderer.ActivityDomain
    let sourceCoordinate: GridCoordinate
    let surfaceCoordinate: GridCoordinate
    let presentationBand: UInt8
}

private struct AmbientCorridorSignature: Equatable {
    let context: AmbientContextSignature
    let activitySamples: [AmbientActivitySignature]
}

private struct AmbientGroundSignature: Equatable {
    let layoutRoles: [UInt8]
    let detail: CameraDetailLevel
}

private struct GeneratedResidencyTileSignature: Equatable {
    let kind: BuildingKind
    let level: Int
    let constructionBand: UInt8
}

private struct CityVisualCompositionBounds {
    let occupiedDeveloped: CGRect
    let cameraPriority: CGRect
    let networkOpportunity: CGRect
    let cameraPriorityCoordinates: Set<GridCoordinate>
}

private final class TileRenderRecord {
    let root: SKNode
    var overlayLayer: SKNode?
    var consequenceLayer: SKNode?
    let signature: TileRenderSignature
    var overlaySignature: OverlayRenderSignature

    init(
        root: SKNode,
        overlayLayer: SKNode?,
        consequenceLayer: SKNode?,
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
    private static let minimumCameraScale: CGFloat = 0.30
    private static let canonicalCityCameraScale: CGFloat = 0.74
    private static let cityOccupiedWidthTarget: CGFloat = 0.68

    var onPrimaryAction: ((GridCoordinate) -> Void)?
    var onSecondaryAction: ((GridCoordinate) -> Void)?
    var onActiveActionTargetCandidate: ((GridCoordinate) -> CityMapActionTargetPresentation?)?
    var onCommandAction: ((CityCommandID) -> Void)?
    var allowsCommand: ((CityCommandID) -> Bool)?
    var reducedMotion = false

    private let style: WorldVisualStyle
    private let assets: WorldAssetCatalog
    private let terrainRenderer: TerrainRenderer
    private let roadRenderer: RoadRenderer
    private let lotRenderer: LotRenderer
    private let ambientLifeRenderer: AmbientLifeRenderer
    private let overlayRenderer: WorldOverlayRenderer
    private let spatialConsequenceRenderer: SpatialConsequenceRenderer
    private let worldLayer = SKNode()
    private let backdropLayer = SKNode()
    private let tileLayer = SKNode()
    private let ambientLayer = SKNode()
    private let ambientGroundLayer = SKNode()
    private let ambientLifeLayer = SKNode()
    private let cameraNode = SKCameraNode()
    private let hoverNode = SKShapeNode()
    private let selectionNode = SKShapeNode()
    private var renderedState: CityGameState?
    private var renderedSnapshot: CityPresentationSnapshot?
    private var renderedReducedMotion = false
    private var presentedConsequenceEventTicks: [String: Int] = [:]
    private var displayedConsequenceEventExpiryTicks: [GridCoordinate: Int] = [:]
    private var renderedOverlay: DataOverlay = .none
    private var renderedSelection: GridCoordinate?
    private var renderedInteractionMode: CityInteractionMode = .inspect
    private var renderedActiveActionTarget: CityMapActionTargetPresentation?
    private var hoveredCoordinate: GridCoordinate?
    private var lastPreviewSignature: InteractionPreviewSignature?
    private var renderedGridSize: CGSize?
    private var ambientCorridorSignature: AmbientCorridorSignature?
    private var ambientGroundSignature: AmbientGroundSignature?
    private var ambientLayoutRoles: [UInt8] = []
    private var ambientActivityExcludedRoadCoordinates: Set<GridCoordinate> = []
    private var ambientActivityCandidates = AmbientLifeRenderer.ActivityCandidates(
        streets: [],
        places: [],
        reservedSurfaces: []
    )
    private var generatedResidencyGridSize: CGSize?
    private var generatedResidencyTileSignatures: [GeneratedResidencyTileSignature] = []
    private var generatedResidencyDetail: CameraDetailLevel?
    private var viewportInsets: CityMapViewportInsets = .zero
    private var hasUserAdjustedCamera = false
    private var needsSettledInitialCameraFit = true
    private var needsAutomaticCameraRefit = false
    private var lastValidDevelopedComposition: CityVisualCompositionBounds?
    private(set) var occupiedDevelopedVisualBoundsForTesting: CGRect = .null
    private(set) var cameraPriorityVisualBoundsForTesting: CGRect = .null
    private(set) var networkOpportunityVisualBoundsForTesting: CGRect = .null
    private(set) var cameraPriorityCoordinatesForTesting: Set<GridCoordinate> = []
    private(set) var activeTargetContextBoundsForTesting: CGRect = .null
    private(set) var activeTargetRoadFrontierForTesting: GridCoordinate?
    var developedVisualBoundsForTesting: CGRect { occupiedDevelopedVisualBoundsForTesting }
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
    var cityScaleLimitForTesting: CGFloat { cityScaleLimit }
    var ambientActionCountForTesting: Int { runtimeTreeMetrics(ambientLayer).actions }
    var ambientMotionEnabledForTesting: Bool { ambientMotionEnabled }
    private(set) var ambientRebuildCountForTesting = 0
    private(set) var ambientGroundRebuildCountForTesting = 0
    private(set) var generatedResidencyPreloadCountForTesting = 0
    var renderedActivityNamesForTesting: [String] {
        func names(in node: SKNode) -> [String] {
            (node.name.map { [$0] } ?? []) + node.children.flatMap(names)
        }
        return names(in: ambientLayer).filter {
            (
                $0.hasPrefix("world.activity.street.local-activity.")
                    || $0.hasPrefix("world.activity.place.local-activity.")
            ) && !$0.contains(".generated-v4.")
        }
    }
    var ambientCorridorIdentifierForTesting: ObjectIdentifier? {
        ambientLifeLayer.childNode(withName: "world.ambient.corridor").map(ObjectIdentifier.init)
    }
    var ambientEnvironmentNamesForTesting: [String] {
        func names(in node: SKNode) -> [String] {
            (node.name.map { [$0] } ?? []) + node.children.flatMap(names)
        }
        return names(in: ambientLayer).filter {
            $0.hasPrefix("world.environment.")
                || $0.hasPrefix("district.ground.")
        }
    }
    var consumedConsequenceEventIDCountForTesting: Int { presentedConsequenceEventTicks.count }
    var selectionIsHiddenForTesting: Bool { selectionNode.isHidden }
    var hoverIsHiddenForTesting: Bool { hoverNode.isHidden }
    var hoverVisualBoundsForTesting: CGRect { hoverNode.calculateAccumulatedFrame() }
    var activeActionTargetForTesting: CityMapActionTargetPresentation? { renderedActiveActionTarget }
    var interactionNamesForTesting: [String] {
        func names(in node: SKNode) -> [String] {
            (node.name.map { [$0] } ?? []) + node.children.flatMap(names)
        }
        return names(in: hoverNode) + names(in: selectionNode)
    }

    func safeViewportRectForTesting(_ insets: CityMapViewportInsets) -> CGRect {
        safeViewportRect(insets)
    }

    func scenePointForTesting(at coordinate: GridCoordinate) -> CGPoint {
        style.isoPosition(coordinate)
    }

    func tileGroundBoundsForTesting(at coordinate: GridCoordinate) -> CGRect {
        tileGroundBounds(at: style.isoPosition(coordinate))
    }

    func resolvedCoordinateForTesting(at scenePoint: CGPoint) -> GridCoordinate? {
        coordinate(at: scenePoint)
    }

    override init(size: CGSize) {
        let style = WorldVisualStyle()
        let assets = WorldAssetCatalog.shared
        self.style = style
        self.assets = assets
        self.terrainRenderer = TerrainRenderer(
            style: style,
            assets: assets,
            groundEcologyAssets: .shared
        )
        self.roadRenderer = RoadRenderer(
            style: style,
            assets: assets,
            fourViewRoadAssets: .shared
        )
        self.lotRenderer = LotRenderer(
            style: style,
            assets: assets,
            fourViewAssets: .shared
        )
        self.ambientLifeRenderer = AmbientLifeRenderer(
            style: style,
            assets: assets,
            groundEcologyAssets: .shared
        )
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
        ambientLayer.name = "world.ambient.layer"
        ambientGroundLayer.name = "world.ambient.ground-layer"
        ambientLifeLayer.name = "world.ambient.life-layer"
        ambientLayer.addChild(ambientGroundLayer)
        ambientLayer.addChild(ambientLifeLayer)
        worldLayer.addChild(ambientLayer)
        addChild(cameraNode)
        camera = cameraNode
        hoverNode.zPosition = 90_000
        configureHighlight(selectionNode, color: NSColor(calibratedRed: 0.25, green: 0.95, blue: 0.78, alpha: 1), alpha: 0.65, z: 90_001)
        selectionNode.fillColor = .clear
        selectionNode.strokeColor = style.palette.concreteLight.withAlphaComponent(0.96)
        selectionNode.lineWidth = 2.2
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
        interactionMode: CityInteractionMode,
        activeActionTarget: CityMapActionTargetPresentation? = nil
    ) {
        let renderStarted = ProcessInfo.processInfo.systemUptime
        let assetResidencyBefore = assets.residencySnapshot()
        if renderedSnapshot?.fingerprint == snapshot.fingerprint,
           renderedOverlay == overlay,
           renderedSelection == selection,
           renderedInteractionMode == interactionMode,
           renderedActiveActionTarget == activeActionTarget,
           renderedReducedMotion == reducedMotion {
            diagnosticsSnapshot.createdTileCount = 0
            diagnosticsSnapshot.updatedTileCount = 0
            diagnosticsSnapshot.reusedTileCount = tileRecords.count
            diagnosticsSnapshot.removedTileCount = 0
            diagnosticsSnapshot.overlayUpdateCount = 0
            diagnosticsSnapshot.consumedConsequenceEventCount = 0
            diagnosticsSnapshot.updatedCoordinates = []
            diagnosticsSnapshot.worldUpdateDurationMilliseconds = 0
            finishRenderDiagnostics(
                startedAt: renderStarted,
                assetResidencyBefore: assetResidencyBefore
            )
            return
        }
        let isFirstRender = renderedSnapshot == nil
        let previousSnapshot = renderedSnapshot
        let previousOverlay = renderedOverlay
        let previousSelection = renderedSelection
        let previousActiveActionTarget = renderedActiveActionTarget
        let previousInteractionMode = renderedInteractionMode
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
        } else if needsSettledInitialCameraFit || needsAutomaticCameraRefit {
            // The first SwiftUI representable update can precede AppKit's
            // settled map aperture. Refit once on the first authoritative
            // pulse after launch, while the camera is still untouched, so the
            // shipping opening cannot retain that provisional wide scale.
            if !hasUserAdjustedCamera, selection == nil {
                applyDevelopedCoreCamera(state)
            }
            needsSettledInitialCameraFit = false
            needsAutomaticCameraRefit = false
        }
        let resolvedDetail = resolvedCameraDetailLevel(for: cameraNode.xScale)
        if resolvedDetail != currentCameraDetailLevel {
            currentCameraDetailLevel = resolvedDetail
            for record in tileRecords.values {
                style.updateDetailVisibility(in: record.root, detail: resolvedDetail)
            }
            lastPreviewSignature = nil
        }
        preloadGeneratedResidencyIfNeeded(for: resolvedDetail, state: state)
        renderedState = state
        renderedSnapshot = snapshot
        renderedOverlay = overlay
        renderedSelection = selection
        renderedInteractionMode = interactionMode
        renderedActiveActionTarget = activeActionTarget
        renderedReducedMotion = reducedMotion
        diagnosticsSnapshot = updateWorld(
            snapshot: snapshot,
            overlay: overlay,
            previousSnapshot: motionChanged ? nil : previousSnapshot,
            previousOverlay: previousOverlay,
            defersRuntimeMetricsToFullRecount: isFirstRender
        )
        _ = updateAmbientCorridor(snapshot: snapshot)
        let expiredCueCount = expireConsequenceEvents(at: snapshot.authoritativeTick)
        let insertedCueCount = presentConsequenceEvents(consequenceEvents)
        updateSelection(selection)
        refreshPersistentConsequenceEmphasis(at: [previousSelection, selection])
        refreshInteractionPreview()
        if previousSelection != selection, let selection {
            revealSelection(selection, viewportInsets: viewportInsets)
        } else if let activeActionTarget,
                  activeActionTarget.coordinate == selection,
                  renderedInteractionMode != .inspect,
                  (
                    previousInteractionMode != interactionMode
                        || previousActiveActionTarget?.coordinate != activeActionTarget.coordinate
                  ) {
            revealActionTargetContext(
                activeActionTarget.coordinate,
                viewportInsets: viewportInsets
            )
        }
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
        let runtimeMetricsStarted = ProcessInfo.processInfo.systemUptime
        refreshRuntimeDiagnostics(
            consumedEventCount: consequenceEvents.count,
            displayedCueCount: displayedCueCount,
            requiresTreeRecount: requiresTreeRecount
        )
        diagnosticsSnapshot.runtimeTreeMetricsDurationMilliseconds = requiresTreeRecount
            ? (ProcessInfo.processInfo.systemUptime - runtimeMetricsStarted) * 1_000
            : 0
        finishRenderDiagnostics(
            startedAt: renderStarted,
            assetResidencyBefore: assetResidencyBefore
        )
    }

    func render(
        state: CityGameState,
        overlay: DataOverlay,
        selection: GridCoordinate?,
        interactionMode: CityInteractionMode,
        activeActionTarget: CityMapActionTargetPresentation? = nil
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
            interactionMode: interactionMode,
            activeActionTarget: activeActionTarget
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
        if materiallyChanged, renderedState != nil {
            if !hasUserAdjustedCamera {
                needsAutomaticCameraRefit = true
            }
            if let renderedSnapshot {
                _ = updateAmbientCorridor(snapshot: renderedSnapshot)
            }
        }
    }

    func updateViewportInsets(_ insets: CityMapViewportInsets) {
        guard viewportInsets != insets else { return }
        viewportInsets = insets
        if !hasUserAdjustedCamera, renderedState != nil {
            needsAutomaticCameraRefit = true
        }
        if let selection = renderedSelection {
            revealSelection(selection, viewportInsets: insets)
        }
    }

    func frameCity() {
        if let state = renderedState {
            hasUserAdjustedCamera = false
            focusDevelopedCore(state)
        }
    }

    func occupiedDevelopedViewportOccupancyForTesting() -> CGSize {
        viewportOccupancy(for: occupiedDevelopedVisualBoundsForTesting)
    }

    func networkOpportunityViewportOccupancyForTesting() -> CGSize {
        viewportOccupancy(for: networkOpportunityVisualBoundsForTesting)
    }

    func cameraPriorityViewportOccupancyForTesting() -> CGSize {
        viewportOccupancy(for: cameraPriorityVisualBoundsForTesting)
    }

    func persistentConsequenceAlphaForTesting(at coordinate: GridCoordinate) -> CGFloat? {
        guard let record = tileRecords[coordinate] else { return nil }
        return record.consequenceLayer?
            .childNode(withName: "spatial.consequences")?
            .alpha ?? 0
    }

    func developedViewportOccupancyForTesting() -> CGSize {
        occupiedDevelopedViewportOccupancyForTesting()
    }

    private func viewportOccupancy(for bounds: CGRect) -> CGSize {
        guard !bounds.isNull else { return .zero }
        let safeWidth = max(1, size.width - viewportInsets.leading - viewportInsets.trailing)
        let safeHeight = max(1, size.height - viewportInsets.top - viewportInsets.bottom)
        return CGSize(
            width: bounds.width / (safeWidth * cameraNode.xScale),
            height: bounds.height / (safeHeight * cameraNode.yScale)
        )
    }

    func tileRootIdentifier(at coordinate: GridCoordinate) -> ObjectIdentifier? {
        tileRecords[coordinate].map { ObjectIdentifier($0.root) }
    }

    func tileRootIsHiddenForTesting(at coordinate: GridCoordinate) -> Bool? {
        tileRecords[coordinate]?.root.isHidden
    }

    func tileRootIsAttachedForTesting(at coordinate: GridCoordinate) -> Bool? {
        tileRecords[coordinate]?.root.parent != nil
    }

    func tileDescendantNamesForTesting(at coordinate: GridCoordinate) -> [String] {
        guard let root = tileRecords[coordinate]?.root else { return [] }
        func names(in node: SKNode) -> [String] {
            (node.name.map { [$0] } ?? []) + node.children.flatMap(names)
        }
        return names(in: root)
    }

    func tileVisibleDescendantNamesForTesting(at coordinate: GridCoordinate) -> [String] {
        guard let root = tileRecords[coordinate]?.root else { return [] }
        func names(in node: SKNode, ancestorHidden: Bool) -> [String] {
            let hidden = ancestorHidden || node.isHidden || node.alpha <= 0.001
            guard !hidden else { return [] }
            return (node.name.map { [$0] } ?? [])
                + node.children.flatMap { names(in: $0, ancestorHidden: hidden) }
        }
        return names(in: root, ancestorHidden: false)
    }

    func tileConsequenceEventNodeCountForTesting(at coordinate: GridCoordinate) -> Int {
        tileRecords[coordinate]?.consequenceLayer?.children.filter {
            $0.name?.hasPrefix("spatial.event.") == true
        }.count ?? 0
    }

    func recountedRuntimeMetricsForTesting() -> (nodes: Int, drawables: Int, actions: Int) {
        let metrics = runtimeTreeMetrics(worldLayer)
        return (metrics.nodes - 1, metrics.drawables, metrics.actions)
    }

    func configureProofCamera(
        detail: CameraDetailLevel,
        centeredOn coordinate: GridCoordinate? = nil,
        framingScale: CGFloat = 1
    ) {
        let canonicalScale: CGFloat
        switch detail {
        case .city: canonicalScale = Self.canonicalCityCameraScale
        case .neighborhood: canonicalScale = 0.66
        case .block: canonicalScale = 0.50
        }
        cameraNode.setScale(
            actualCameraScale(forCanonicalScale: canonicalScale) * max(1, framingScale)
        )
        if let coordinate { cameraNode.position = style.isoPosition(coordinate) }
        refreshForCameraChange()
    }

    func configureProofInteraction(at coordinate: GridCoordinate?) {
        let previous = hoveredCoordinate
        guard let coordinate else {
            if renderedInteractionMode == .inspect {
                hoveredCoordinate = nil
                clearInteractionPreview()
                refreshPersistentConsequenceEmphasis(at: [previous])
            }
            return
        }
        if renderedInteractionMode != .inspect {
            guard let target = onActiveActionTargetCandidate?(coordinate)
                    ?? renderedActiveActionTarget.flatMap({ $0.coordinate == coordinate ? $0 : nil })
            else { return }
            applyActiveActionTarget(target)
            return
        }
        hoveredCoordinate = coordinate
        hoverNode.position = style.isoPosition(coordinate)
        hoverNode.isHidden = false
        updateBuildPreview(at: coordinate)
        refreshPersistentConsequenceEmphasis(at: [previous, coordinate])
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
        activatePrimaryAction(at: coordinate)
    }

    func activatePrimaryActionForTesting(at coordinate: GridCoordinate) {
        activatePrimaryAction(at: coordinate)
    }

    private func activatePrimaryAction(at coordinate: GridCoordinate) {
        if renderedInteractionMode == .inspect {
            onPrimaryAction?(coordinate)
            return
        }
        guard let target = onActiveActionTargetCandidate?(coordinate) else { return }
        applyActiveActionTarget(target)
        onPrimaryAction?(target.coordinate)
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
        if renderedInteractionMode != .inspect,
           renderedState != nil,
           renderedActiveActionTarget?.coordinate == coordinate {
            revealActionTargetContext(coordinate, viewportInsets: viewportInsets)
            return
        }
        revealCoordinateOnly(coordinate, viewportInsets: viewportInsets)
    }

    private func revealCoordinateOnly(
        _ coordinate: GridCoordinate,
        viewportInsets: CityMapViewportInsets
    ) {
        activeTargetContextBoundsForTesting = .null
        activeTargetRoadFrontierForTesting = nil
        let target = style.isoPosition(coordinate)
        let safeRect = safeViewportRect(viewportInsets)
        let revealMargin: CGFloat = 0.5
        let horizontalMargin = safeRect.width >= revealMargin * 2 ? revealMargin : 0
        let verticalMargin = safeRect.height >= revealMargin * 2 ? revealMargin : 0
        if target.x < safeRect.minX {
            cameraNode.position.x -= safeRect.minX - target.x + horizontalMargin
        }
        if target.x > safeRect.maxX {
            cameraNode.position.x += target.x - safeRect.maxX + horizontalMargin
        }
        if target.y < safeRect.minY {
            cameraNode.position.y -= safeRect.minY - target.y + verticalMargin
        }
        if target.y > safeRect.maxY {
            cameraNode.position.y += target.y - safeRect.maxY + verticalMargin
        }
        refreshForCameraChange()
    }

    /// Keeps a typed player target legible without turning it into a detached
    /// hero frame. The context is derived only from the current authoritative
    /// state: the selected coordinate, the nearest real road cell, and the
    /// already-approved developed-district composition. No target, road,
    /// placement rule, or recovery route is synthesized here.
    private func revealActionTargetContext(
        _ coordinate: GridCoordinate,
        viewportInsets: CityMapViewportInsets
    ) {
        guard let state = renderedState else {
            revealCoordinateOnly(coordinate, viewportInsets: viewportInsets)
            return
        }
        let composition = visualCompositionBounds(in: state)
        guard !composition.cameraPriority.isNull,
              !composition.cameraPriority.isEmpty else {
            revealCoordinateOnly(coordinate, viewportInsets: viewportInsets)
            return
        }

        let targetBounds = tileGroundBounds(at: style.isoPosition(coordinate))
        let roadFrontier = nearestAuthoritativeRoad(to: coordinate, in: state)
        let roadFrontierBounds = roadFrontier.map {
            tileGroundBounds(at: style.isoPosition($0))
        }
        let currentSafeRect = safeViewportRect(viewportInsets)
        let visibleDistrict = currentSafeRect.intersection(composition.cameraPriority)
        let currentDistrictWidthShare = visibleDistrict.width / max(1, currentSafeRect.width)
        let currentDistrictHeightShare = visibleDistrict.height / max(1, currentSafeRect.height)

        // Intended nearby targets already live inside the composed district.
        // Keep their exact camera rather than zooming out merely because the
        // interaction mode changed. Remote targets receive the contextual fit
        // below only when the present aperture cannot fully show both target
        // and its real road frontier with a meaningful amount of the district.
        let currentTargetIsVisible = currentSafeRect.contains(targetBounds)
        let currentRoadFrontierIsVisible = roadFrontierBounds.map {
            currentSafeRect.contains($0)
        } ?? true
        if currentTargetIsVisible,
           currentRoadFrontierIsVisible,
           currentDistrictWidthShare >= 0.25,
           currentDistrictHeightShare >= 0.25 {
            activeTargetContextBoundsForTesting = composition.cameraPriority
                .union(targetBounds)
                .union(roadFrontierBounds ?? .null)
            activeTargetRoadFrontierForTesting = roadFrontier
            return
        }

        // Fit the occupied district mass rather than every remote road extent.
        // A remote target needs a meaningful district anchor, not every far
        // roof edge. Trim less than one tile from the district edge opposite
        // the target; the intervening authoritative network remains rendered.
        var districtContextBounds = composition.occupiedDeveloped
        let farEdgeTrim = min(
            tileHeight * 0.9,
            districtContextBounds.height * 0.2
        )
        if targetBounds.midY < districtContextBounds.midY {
            districtContextBounds.size.height -= farEdgeTrim
        } else {
            districtContextBounds.origin.y += farEdgeTrim
            districtContextBounds.size.height -= farEdgeTrim
        }
        var contextBounds = districtContextBounds.union(targetBounds)
        if let roadFrontierBounds {
            contextBounds = contextBounds.union(roadFrontierBounds)
        }

        let safeWidth = max(1, size.width - viewportInsets.leading - viewportInsets.trailing)
        let safeHeight = max(1, size.height - viewportInsets.top - viewportInsets.bottom)
        // Account exactly for the safe-viewport tile guard. Both ground
        // diamonds are already part of `contextBounds`, so adding more world
        // margin here would only miniaturize the district.
        let horizontalWorldPadding = tileWidth * 1.25 * 2 + 8
        let verticalWorldPadding = tileHeight * 1.75 * 2 + 8
        let requiredScale = max(
            (contextBounds.width + horizontalWorldPadding) / safeWidth,
            (contextBounds.height + verticalWorldPadding) / safeHeight
        )
        // A compact placement aperture can be extremely shallow beneath HUD
        // chrome. Stay below the full-board fallback ceiling: the contextual
        // fit must keep the target visible without shrinking the connected
        // district into an unreadable edge sliver.
        let scale = min(2.18, max(cameraNode.xScale, requiredScale))
        cameraNode.setScale(scale)

        let safeCenterOffset = CGPoint(
            x: (viewportInsets.leading - viewportInsets.trailing) * scale / 2,
            y: (viewportInsets.bottom - viewportInsets.top) * scale / 2
        )
        cameraNode.position = CGPoint(
            x: contextBounds.midX - safeCenterOffset.x,
            y: contextBounds.midY - safeCenterOffset.y
        )
        activeTargetContextBoundsForTesting = contextBounds
        activeTargetRoadFrontierForTesting = roadFrontier
        refreshForCameraChange()
    }

    private func nearestAuthoritativeRoad(
        to coordinate: GridCoordinate,
        in state: CityGameState
    ) -> GridCoordinate? {
        state.tiles
            .filter { $0.kind == .road }
            .map(\.coordinate)
            .min { lhs, rhs in
                let lhsDistance = abs(lhs.x - coordinate.x) + abs(lhs.y - coordinate.y)
                let rhsDistance = abs(rhs.x - coordinate.x) + abs(rhs.y - coordinate.y)
                if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                return coordinateComesBefore(lhs, rhs)
            }
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
        let previous = hoveredCoordinate
        guard let coordinate = coordinate(at: event.location(in: self)) else {
            if renderedInteractionMode == .inspect {
                hoveredCoordinate = nil
                clearInteractionPreview()
                refreshPersistentConsequenceEmphasis(at: [previous])
            }
            return
        }
        if renderedInteractionMode != .inspect {
            guard renderedActiveActionTarget?.coordinate != coordinate,
                  let target = onActiveActionTargetCandidate?(coordinate) else { return }
            applyActiveActionTarget(target)
            return
        }
        hoveredCoordinate = coordinate
        hoverNode.position = style.isoPosition(coordinate)
        hoverNode.isHidden = false
        updateBuildPreview(at: coordinate)
        refreshPersistentConsequenceEmphasis(at: [previous, coordinate])
    }

    override func scrollWheel(with event: NSEvent) {
        handleMapScrollWheel(event)
    }

    override func magnify(with event: NSEvent) {
        handleMapMagnification(event)
    }

    func handleMapScrollWheel(_ event: NSEvent) {
        let factor = exp(event.scrollingDeltaY * 0.012)
        zoomCamera(by: factor, anchoredAt: event.location(in: self))
    }

    func handleMapMagnification(_ event: NSEvent) {
        let factor = exp(-event.magnification)
        zoomCamera(by: factor, anchoredAt: event.location(in: self))
    }

    func zoomCameraForTesting(by factor: CGFloat, anchoredAt anchor: CGPoint?) {
        zoomCamera(by: factor, anchoredAt: anchor)
    }

    private func zoomCamera(by factor: CGFloat, anchoredAt anchor: CGPoint? = nil) {
        // Keep the strategic city stop focused on the lived-in corridor plus
        // honest expansion context. Showing the entire 24 x 24 board turns a
        // small starting settlement into an unreadable island and provides no
        // useful additional planning information.
        let previousScale = cameraNode.xScale
        let scale = min(cityScaleLimit, max(Self.minimumCameraScale, previousScale * factor))
        guard abs(scale - previousScale) > .ulpOfOne else { return }
        if let anchor {
            let scaleRatio = scale / previousScale
            cameraNode.position = CGPoint(
                x: anchor.x + (cameraNode.position.x - anchor.x) * scaleRatio,
                y: anchor.y + (cameraNode.position.y - anchor.y) * scaleRatio
            )
        }
        cameraNode.setScale(scale)
        hasUserAdjustedCamera = true
        refreshForCameraChange()
    }

    /// The strategic stop is window-specific: a larger world aperture must not
    /// turn the authoritative developed core into a tiny island. LOD selection
    /// is normalized separately, so the same three semantic texture families
    /// remain available without changing their shared thresholds.
    private var cityScaleLimit: CGFloat {
        guard !cameraPriorityVisualBoundsForTesting.isNull,
              !cameraPriorityVisualBoundsForTesting.isEmpty else {
            return Self.canonicalCityCameraScale
        }
        let safeWidth = max(1, size.width - viewportInsets.leading - viewportInsets.trailing)
        let occupiedWidthLimit = cameraPriorityVisualBoundsForTesting.width
            / (safeWidth * Self.cityOccupiedWidthTarget)
        return min(
            Self.canonicalCityCameraScale,
            max(Self.minimumCameraScale + 0.01, occupiedWidthLimit)
        )
    }

    private func canonicalCameraScale(for actualScale: CGFloat) -> CGFloat {
        let actualRange = cityScaleLimit - Self.minimumCameraScale
        guard actualRange > .ulpOfOne else { return Self.canonicalCityCameraScale }
        let progress = min(1, max(0, (actualScale - Self.minimumCameraScale) / actualRange))
        return Self.minimumCameraScale
            + progress * (Self.canonicalCityCameraScale - Self.minimumCameraScale)
    }

    private func actualCameraScale(forCanonicalScale canonicalScale: CGFloat) -> CGFloat {
        let canonicalRange = Self.canonicalCityCameraScale - Self.minimumCameraScale
        guard canonicalRange > .ulpOfOne else { return cityScaleLimit }
        let progress = min(1, max(0, (canonicalScale - Self.minimumCameraScale) / canonicalRange))
        return Self.minimumCameraScale + progress * (cityScaleLimit - Self.minimumCameraScale)
    }

    private func resolvedCameraDetailLevel(for actualScale: CGFloat) -> CameraDetailLevel {
        style.detailLevel(cameraScale: canonicalCameraScale(for: actualScale))
    }

    @discardableResult
    private func updateAmbientCorridor(snapshot: CityPresentationSnapshot) -> Bool {
        let state = snapshot.state
        let context = ambientContextSignature(
            for: state,
            changedCoordinates: diagnosticsSnapshot.updatedCoordinates
        )
        if ambientCorridorSignature?.context != context {
            ambientActivityExcludedRoadCoordinates =
                ambientLifeRenderer.activityExcludedRoadCoordinates(
                    in: state,
                    detail: currentCameraDetailLevel
                )
            ambientActivityCandidates = ambientLifeRenderer.activityCandidates(
                in: state,
                excluding: ambientActivityExcludedRoadCoordinates
            )
        }
        let placements = ambientLifeRenderer.activityPlacements(
            in: state,
            candidates: ambientActivityCandidates,
            consequences: snapshot.spatialConsequences,
            detail: currentCameraDetailLevel
        )
        return reconcileAmbientCorridor(
            snapshot: snapshot,
            context: context,
            placements: placements
        )
    }

    private func ambientContextSignature(
        for state: CityGameState,
        changedCoordinates: Set<GridCoordinate>? = nil
    ) -> AmbientContextSignature {
        let detail = currentCameraDetailLevel
        let motionEnabled = ambientMotionEnabled
        if ambientLayoutRoles.count != state.tiles.count || changedCoordinates == nil {
            ambientLayoutRoles = state.tiles.map(ambientLayoutRole)
        } else if let changedCoordinates {
            for coordinate in changedCoordinates {
                let index = coordinate.y * state.gridWidth + coordinate.x
                guard ambientLayoutRoles.indices.contains(index),
                      let tile = state.tile(at: coordinate) else { continue }
                let role = ambientLayoutRole(for: tile)
                if ambientLayoutRoles[index] != role {
                    ambientLayoutRoles[index] = role
                }
            }
        }
        return AmbientContextSignature(
            layoutRoles: ambientLayoutRoles,
            detail: detail,
            reducedMotion: reducedMotion,
            motionEnabled: motionEnabled
        )
    }

    private func ambientLayoutRole(for tile: CityTile) -> UInt8 {
        if tile.kind == .empty { return 0 }
        if tile.kind == .road { return 1 }
        return tile.constructionProgress >= 1 ? 2 : 3
    }

    @discardableResult
    private func reconcileAmbientCorridor(
        snapshot: CityPresentationSnapshot,
        context: AmbientContextSignature,
        placements: [AmbientLifeRenderer.ActivityPlacement]
    ) -> Bool {
        let signature = AmbientCorridorSignature(
            context: context,
            activitySamples: activitySignature(placements)
        )
        guard signature != ambientCorridorSignature else { return false }
        ambientRebuildCountForTesting += 1
        let priorGroundMetrics = attachedRuntimeTreeMetrics(ambientGroundLayer)
        let priorLifeMetrics = attachedRuntimeTreeMetrics(ambientLifeLayer)
        let groundSignature = AmbientGroundSignature(
            layoutRoles: context.layoutRoles,
            detail: context.detail
        )
        if groundSignature != ambientGroundSignature {
            ambientGroundLayer.removeAllChildren()
            ambientGroundLayer.addChild(terrainRenderer.makeDevelopedDistrictGround(
                in: snapshot.state,
                detail: currentCameraDetailLevel
            ))
            ambientGroundSignature = groundSignature
            ambientGroundRebuildCountForTesting += 1
        }
        if ambientCorridorSignature?.context != context {
            ambientLifeLayer.removeAllChildren()
            ambientLifeLayer.addChild(ambientLifeRenderer.makeCorridorLife(
                in: snapshot.state,
                consequences: snapshot.spatialConsequences,
                detail: currentCameraDetailLevel,
                reducedMotion: !ambientMotionEnabled,
                resolvedActivityPlacements: placements
            ))
        } else if let corridor = ambientLifeLayer.childNode(
            withName: "world.ambient.corridor"
        ) {
            // Activity-band changes are authoritative but do not invalidate
            // the deterministic furniture, vegetation, or vacant-land tree.
            // Replace only the bounded actor layer so a state pulse does not
            // rebuild the complete public realm.
            corridor.childNode(withName: "world.activity.local")?.removeFromParent()
            let activity = ambientLifeRenderer.makeLocalActivity(
                placements: placements,
                detail: currentCameraDetailLevel,
                reducedMotion: !ambientMotionEnabled
            )
            if !activity.children.isEmpty {
                corridor.addChild(activity)
            }
        } else {
            ambientLifeLayer.removeAllChildren()
            ambientLifeLayer.addChild(ambientLifeRenderer.makeCorridorLife(
                in: snapshot.state,
                consequences: snapshot.spatialConsequences,
                detail: currentCameraDetailLevel,
                reducedMotion: !ambientMotionEnabled,
                resolvedActivityPlacements: placements
            ))
        }
        applyRuntimeDelta(
            from: priorGroundMetrics,
            to: attachedRuntimeTreeMetrics(ambientGroundLayer),
            diagnostics: &diagnosticsSnapshot
        )
        applyRuntimeDelta(
            from: priorLifeMetrics,
            to: attachedRuntimeTreeMetrics(ambientLifeLayer),
            diagnostics: &diagnosticsSnapshot
        )
        ambientCorridorSignature = signature
        return true
    }

    @discardableResult
    func reconcileAmbientActivityForTesting(
        snapshot: CityPresentationSnapshot,
        placements: [AmbientLifeRenderer.ActivityPlacement]
    ) -> Bool {
        let context = ambientContextSignature(
            for: snapshot.state,
            changedCoordinates: nil
        )
        return reconcileAmbientCorridor(
            snapshot: snapshot,
            context: context,
            placements: placements
        )
    }

    private func activitySignature(
        _ placements: [AmbientLifeRenderer.ActivityPlacement]
    ) -> [AmbientActivitySignature] {
        placements.map { placement in
            AmbientActivitySignature(
                domain: placement.domain,
                sourceCoordinate: placement.sourceCoordinate,
                surfaceCoordinate: placement.surfaceCoordinate,
                presentationBand: UInt8((placement.intensity * 3).rounded())
            )
        }
    }

    /// Compact windows retain the complete ambient semantic set but keep it
    /// static. Exercising even one SpriteKit action while repeatedly cycling
    /// LODs pinned a compact-only graphics working set above the governed
    /// physical-footprint ceiling after the required 60-second settle.
    private var ambientMotionEnabled: Bool {
        !reducedMotion && size.width >= 1_000
    }

    private func updateWorld(
        snapshot: CityPresentationSnapshot,
        overlay: DataOverlay,
        previousSnapshot: CityPresentationSnapshot?,
        previousOverlay: DataOverlay,
        defersRuntimeMetricsToFullRecount: Bool
    ) -> RendererDiagnosticsSnapshot {
        let state = snapshot.state
        let updateStarted = ProcessInfo.processInfo.systemUptime
        var diagnostics = RendererDiagnosticsSnapshot(
            nodeCount: diagnosticsSnapshot.nodeCount,
            drawableNodeCount: diagnosticsSnapshot.drawableNodeCount,
            activeActionCount: diagnosticsSnapshot.activeActionCount,
            detailLevel: currentCameraDetailLevel
        )
        let backdropStarted = ProcessInfo.processInfo.systemUptime
        let gridSize = CGSize(width: state.gridWidth, height: state.gridHeight)
        if renderedGridSize != gridSize {
            let priorBackdropMetrics = defersRuntimeMetricsToFullRecount
                ? nil
                : runtimeTreeMetrics(backdropLayer)
            renderedGridSize = gridSize
            backdropLayer.removeAllChildren()
            backdropLayer.addChild(terrainRenderer.makeBackdrop(
                gridWidth: state.gridWidth,
                gridHeight: state.gridHeight,
                detail: currentCameraDetailLevel
            ))
            if let priorBackdropMetrics {
                applyRuntimeDelta(
                    from: priorBackdropMetrics,
                    to: runtimeTreeMetrics(backdropLayer),
                    diagnostics: &diagnostics
                )
            }
        }
        diagnostics.backdropUpdateDurationMilliseconds =
            (ProcessInfo.processInfo.systemUptime - backdropStarted) * 1_000

        let preparationStarted = ProcessInfo.processInfo.systemUptime
        let removed: [GridCoordinate]
        if tileRecords.isEmpty {
            removed = []
        } else {
            let desiredCoordinates = Set(state.tiles.map(\.coordinate))
            removed = tileRecords.keys.filter { !desiredCoordinates.contains($0) }
        }
        for coordinate in removed {
            if let record = tileRecords.removeValue(forKey: coordinate) {
                applyRuntimeDelta(
                    from: attachedRuntimeTreeMetrics(record.root),
                    to: RuntimeTreeMetrics(nodes: 0, drawables: 0, actions: 0),
                    diagnostics: &diagnostics
                )
                record.root.removeFromParent()
            }
        }
        diagnostics.removedTileCount = removed.count

        let developedRoadContextCoordinates = state.tiles.compactMap { tile in
            tile.kind != .empty && tile.kind != .road ? tile.coordinate : nil
        }
        let changedCoordinates = changedRenderCoordinates(
            from: previousSnapshot,
            to: snapshot,
            canReuseOverlay: previousOverlay == overlay && overlay == .none
        )
        diagnostics.renderPreparationDurationMilliseconds =
            (ProcessInfo.processInfo.systemUptime - preparationStarted) * 1_000

        let tileBuildStarted = ProcessInfo.processInfo.systemUptime
        for tile in state.tiles {
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
                    let priorRootMetrics = attachedRuntimeTreeMetrics(existing.root)
                    if overlay == .none {
                        existing.overlayLayer?.removeAllChildren()
                        existing.overlayLayer?.removeFromParent()
                        existing.overlayLayer = nil
                    } else {
                        let layer = existing.overlayLayer ?? makeOverlayLayer()
                        existing.overlayLayer = layer
                        updateOverlay(
                            in: layer,
                            tile: tile,
                            consequence: consequence,
                            state: state,
                            overlay: overlay
                        )
                        if layer.children.isEmpty {
                            layer.removeFromParent()
                        } else if layer.parent == nil {
                            existing.root.addChild(layer)
                        }
                    }
                    synchronizeTileRootAttachment(existing.root)
                    applyRuntimeDelta(
                        from: priorRootMetrics,
                        to: attachedRuntimeTreeMetrics(existing.root),
                        diagnostics: &diagnostics
                    )
                    existing.overlaySignature = overlaySignature
                    if let consequenceLayer = existing.consequenceLayer {
                        updatePersistentConsequenceEmphasis(
                            in: consequenceLayer,
                            at: tile.coordinate,
                            overlay: overlay
                        )
                    }
                    diagnostics.overlayUpdateCount += 1
                }
                continue
            }

            let priorRecordMetrics = tileRecords[tile.coordinate].map {
                attachedRuntimeTreeMetrics($0.root)
            }
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
                    developedRoadContextCoordinates: developedRoadContextCoordinates,
                    overlay: overlay,
                    signature: signature,
                    overlaySignature: overlaySignature
                )
            }
            if let existing = tileRecords.updateValue(replacement, forKey: tile.coordinate) {
                if !defersRuntimeMetricsToFullRecount {
                    applyRuntimeDelta(
                        from: priorRecordMetrics ?? attachedRuntimeTreeMetrics(existing.root),
                        to: visibleRuntimeTreeMetrics(replacement.root),
                        diagnostics: &diagnostics
                    )
                }
                existing.root.removeFromParent()
                diagnostics.updatedTileCount += 1
                diagnostics.updatedCoordinates.insert(tile.coordinate)
            } else {
                if !defersRuntimeMetricsToFullRecount {
                    applyRuntimeDelta(
                        from: RuntimeTreeMetrics(nodes: 0, drawables: 0, actions: 0),
                        to: visibleRuntimeTreeMetrics(replacement.root),
                        diagnostics: &diagnostics
                    )
                }
                diagnostics.createdTileCount += 1
            }
            synchronizeTileRootAttachment(replacement.root)
        }
        diagnostics.tileBuildDurationMilliseconds =
            (ProcessInfo.processInfo.systemUptime - tileBuildStarted) * 1_000

        diagnostics.totalTileCount = tileRecords.count
        diagnostics.worldUpdateDurationMilliseconds =
            (ProcessInfo.processInfo.systemUptime - updateStarted) * 1_000
        return diagnostics
    }

    private func finishRenderDiagnostics(
        startedAt renderStarted: TimeInterval,
        assetResidencyBefore: WorldAssetResidencySnapshot
    ) {
        let assetResidencyAfter = assets.residencySnapshot()
        diagnosticsSnapshot.assetDecodeLoadCount = max(
            0,
            assetResidencyAfter.textureDecodeLoadCount - assetResidencyBefore.textureDecodeLoadCount
        )
        diagnosticsSnapshot.assetDecodeLoadDurationMilliseconds = max(
            0,
            assetResidencyAfter.textureDecodeLoadDurationMilliseconds
                - assetResidencyBefore.textureDecodeLoadDurationMilliseconds
        )
        diagnosticsSnapshot.totalRenderDurationMilliseconds =
            (ProcessInfo.processInfo.systemUptime - renderStarted) * 1_000
    }

    private func generatedLogicalIDsNeeded(for state: CityGameState) -> Set<String> {
        var logicalIDs: Set<String> = []
        var completedDevelopment: Set<GridCoordinate> = []
        var roadCoordinates: [GridCoordinate] = []
        for tile in state.tiles {
            if tile.kind == .road {
                roadCoordinates.append(tile.coordinate)
                continue
            }
            guard tile.kind != .empty else { continue }
            if tile.constructionProgress >= 1 {
                completedDevelopment.insert(tile.coordinate)
            }
            guard tile.constructionProgress >= 0.75,
                  let logicalID = generatedLogicalID(for: tile, in: state) else { continue }
            logicalIDs.insert(logicalID)
        }
        let hasDevelopedRoad = roadCoordinates.contains { coordinate in
            RoadConnectionMask.cardinalEdges.contains { edge in
                let delta = edge.coordinateDelta
                return completedDevelopment.contains(GridCoordinate(
                    x: coordinate.x + delta.x,
                    y: coordinate.y + delta.y
                ))
            }
        }
        if !completedDevelopment.isEmpty && hasDevelopedRoad {
            logicalIDs.formUnion([
                "ambient_pedestrian_pair",
                "ambient_service_object",
                "ambient_vegetation_cluster",
            ])
        }
        return logicalIDs
    }

    private func generatedResidencyTileSignature(
        for tile: CityTile
    ) -> GeneratedResidencyTileSignature {
        let constructionBand: UInt8
        if tile.constructionProgress >= 1 {
            constructionBand = 2
        } else if tile.constructionProgress >= 0.75 {
            constructionBand = 1
        } else {
            constructionBand = 0
        }
        return GeneratedResidencyTileSignature(
            kind: tile.kind,
            level: tile.level,
            constructionBand: constructionBand
        )
    }

    private func generatedResidencyStateChanged(_ state: CityGameState) -> Bool {
        let gridSize = CGSize(width: state.gridWidth, height: state.gridHeight)
        guard generatedResidencyGridSize == gridSize,
              generatedResidencyTileSignatures.count == state.tiles.count else {
            return true
        }
        for index in state.tiles.indices
        where generatedResidencyTileSignatures[index]
            != generatedResidencyTileSignature(for: state.tiles[index]) {
            return true
        }
        return false
    }

    private func preloadGeneratedResidencyIfNeeded(
        for detail: CameraDetailLevel,
        state: CityGameState
    ) {
        let stateChanged = generatedResidencyStateChanged(state)
        guard stateChanged || detail != generatedResidencyDetail else {
            return
        }
        assets.preloadGeneratedResidency(
            for: detail,
            logicalIDs: generatedLogicalIDsNeeded(for: state),
            roadMasks: generatedRoadMasksNeeded(for: state)
        )
        if stateChanged {
            generatedResidencyGridSize = CGSize(
                width: state.gridWidth,
                height: state.gridHeight
            )
            generatedResidencyTileSignatures = state.tiles.map {
                generatedResidencyTileSignature(for: $0)
            }
        }
        generatedResidencyDetail = detail
        generatedResidencyPreloadCountForTesting += 1
    }

    private func generatedRoadMasksNeeded(for state: CityGameState) -> Set<UInt8> {
        Set(state.tiles.compactMap { tile in
            guard tile.kind == .road else { return nil }
            return RoadConnectionMask.resolving(
                at: tile.coordinate,
                in: state
            ).rawValue
        })
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

        return TileRenderRecord(
            root: root,
            overlayLayer: existing.overlayLayer,
            consequenceLayer: nil,
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
        developedRoadContextCoordinates: [GridCoordinate],
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

        let isMapEdge = tile.coordinate.x == 0 || tile.coordinate.y == 0
            || tile.coordinate.x == state.gridWidth - 1
            || tile.coordinate.y == state.gridHeight - 1
        if (tile.kind != .empty && tile.kind != .road) || isMapEdge {
            let terrainLayer = SKNode()
            terrainLayer.name = "terrain.layer"
            if tile.kind != .empty && tile.kind != .road {
                let ground = terrainRenderer.makeGround(
                    for: tile,
                    detail: currentCameraDetailLevel
                )
                if !ground.children.isEmpty {
                    terrainLayer.addChild(ground)
                }
            }
            if isMapEdge {
                terrainLayer.addChild(terrainRenderer.makeMapEdge(
                    for: tile.coordinate,
                    gridWidth: state.gridWidth,
                    gridHeight: state.gridHeight,
                    detail: currentCameraDetailLevel
                ))
            }
            if !terrainLayer.children.isEmpty {
                root.addChild(terrainLayer)
            }
        }

        var overlayLayer: SKNode?
        if overlay != .none {
            let candidate = makeOverlayLayer()
            updateOverlay(
                in: candidate,
                tile: tile,
                consequence: consequence,
                state: state,
                overlay: overlay
            )
            if !candidate.children.isEmpty {
                root.addChild(candidate)
                overlayLayer = candidate
            }
        }

        switch tile.kind {
        case .empty:
            break
        case .road:
            let contentLayer = SKNode()
            contentLayer.name = "content.layer"
            contentLayer.zPosition = 40
            contentLayer.addChild(roadRenderer.makeRoad(
                at: tile.coordinate,
                connections: signature.roadConnections,
                detail: currentCameraDetailLevel,
                reducedMotion: reducedMotion,
                developedCoordinates: developedRoadContextCoordinates
            ))
            root.addChild(contentLayer)
        default:
            let contentLayer = SKNode()
            contentLayer.name = "content.layer"
            contentLayer.zPosition = 40
            contentLayer.addChild(lotRenderer.makeLot(
                for: tile,
                adjacentRoads: signature.roadConnections,
                detail: currentCameraDetailLevel,
                reducedMotion: reducedMotion
            ))
            root.addChild(contentLayer)
        }

        return TileRenderRecord(
            root: root,
            overlayLayer: overlayLayer,
            consequenceLayer: nil,
            signature: signature,
            overlaySignature: overlaySignature
        )
    }

    private func updatePersistentConsequenceEmphasis(
        in layer: SKNode,
        at coordinate: GridCoordinate,
        overlay: DataOverlay
    ) {
        // The selected diagnostic overlay already carries a sparse, typed,
        // non-color pattern plus an AX legend. Revealing compound utility,
        // pollution, and vitality glyphs on every facade duplicates that truth
        // and obscures the authored buildings. Persistent cues stay available
        // to focused renderer proofs, while the shipping map gives the chosen
        // overlay and selection exclusive visual priority.
        _ = coordinate
        _ = overlay
        layer.childNode(withName: "spatial.consequences")?.alpha = 0
    }

    private func makeOverlayLayer() -> SKNode {
        let layer = SKNode()
        layer.name = "overlay.layer"
        layer.zPosition = 20
        return layer
    }

    private func makeConsequenceLayer() -> SKNode {
        let layer = SKNode()
        layer.name = "spatial.layer"
        layer.zPosition = 72
        return layer
    }

    private func refreshPersistentConsequenceEmphasis(at coordinates: [GridCoordinate?]) {
        for coordinate in Set(coordinates.compactMap { $0 }) {
            guard let layer = tileRecords[coordinate]?.consequenceLayer else { continue }
            updatePersistentConsequenceEmphasis(in: layer, at: coordinate, overlay: renderedOverlay)
        }
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
        guard overlay != .none else {
            return OverlayRenderSignature(overlay: .none, colorToken: 0)
        }
        return OverlayRenderSignature(
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
        guard overlay != .none else { return }
        let renderedOverlay = overlayRenderer.makeOverlay(
            for: tile,
            state: state,
            consequence: consequence,
            overlay: overlay,
            detail: currentCameraDetailLevel
        )
        if !renderedOverlay.children.isEmpty { layer.addChild(renderedOverlay) }
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
            guard let record = tileRecords[event.coordinate] else { continue }
            let layer = record.consequenceLayer ?? makeConsequenceLayer()
            record.consequenceLayer = layer
            if layer.parent == nil {
                record.root.addChild(layer)
                addRuntimeMetrics(RuntimeTreeMetrics(nodes: 1, drawables: 0, actions: 0), to: &diagnosticsSnapshot)
            }
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
            count + (record.consequenceLayer?.children.filter {
                $0.name?.hasPrefix("spatial.event.") == true
            }.count ?? 0)
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
        var nodes = 1
        var drawables = node is SKShapeNode || node is SKSpriteNode || node is SKLabelNode ? 1 : 0
        var actions = node.hasActions() ? 1 : 0
        for child in node.children {
            let childMetrics = runtimeTreeMetrics(child)
            nodes += childMetrics.nodes
            drawables += childMetrics.drawables
            actions += childMetrics.actions
        }
        return RuntimeTreeMetrics(nodes: nodes, drawables: drawables, actions: actions)
    }

    private func attachedRuntimeTreeMetrics(_ root: SKNode) -> RuntimeTreeMetrics {
        guard root.parent != nil else {
            return RuntimeTreeMetrics(nodes: 0, drawables: 0, actions: 0)
        }
        return runtimeTreeMetrics(root)
    }

    private func visibleRuntimeTreeMetrics(_ root: SKNode) -> RuntimeTreeMetrics {
        guard !root.children.isEmpty else {
            return RuntimeTreeMetrics(nodes: 0, drawables: 0, actions: 0)
        }
        return runtimeTreeMetrics(root)
    }

    /// Keep logical tile records for deterministic reuse and diagnostics, while
    /// excluding structurally empty interior parcels from the SpriteKit tree.
    /// Inverse-isometric hit testing remains authoritative for those parcels.
    private func synchronizeTileRootAttachment(_ root: SKNode) {
        if root.children.isEmpty {
            if root.parent != nil {
                root.removeFromParent()
            }
        } else if root.parent == nil {
            tileLayer.addChild(root)
        }
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
        let detail = resolvedCameraDetailLevel(for: cameraNode.xScale)
        guard detail != currentCameraDetailLevel else { return }
        currentCameraDetailLevel = detail
        if let renderedState {
            preloadGeneratedResidencyIfNeeded(for: detail, state: renderedState)
        } else {
            assets.prepareGeneratedResidency(for: detail)
        }
        for record in tileRecords.values {
            updateGeneratedLOD(in: record.root, detail: detail)
            style.updateDetailVisibility(in: record.root, detail: detail)
        }
        style.updateDetailVisibility(in: backdropLayer, detail: detail)
        let ambientChanged = renderedSnapshot.map { updateAmbientCorridor(snapshot: $0) } ?? false
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
        refreshInteractionPreview()
        if ambientChanged {
            let metrics = runtimeTreeMetrics(worldLayer)
            diagnosticsSnapshot.nodeCount = metrics.nodes - 1
            diagnosticsSnapshot.drawableNodeCount = metrics.drawables
            diagnosticsSnapshot.activeActionCount = metrics.actions
        }
    }

    private func updateGeneratedLOD(in node: SKNode, detail: CameraDetailLevel) {
        if let sprite = node as? SKSpriteNode,
           let name = sprite.name,
           name.hasPrefix("road.generated-v4."),
           sprite.children.contains(where: {
               $0.name?.hasPrefix("road.four-view.") == true
           }) {
            // Four-View roads retain one fixed camNE source at every LOD.
            // Only the diagnostic suffix changes; the canonical texture,
            // canvas, pivot, and scale never do.
            let components = name.split(separator: ".")
            if components.count >= 4, let connectionMask = UInt8(components[2]) {
                sprite.name = "road.generated-v4.\(connectionMask).\(detail.assetSuffix)"
            }
        } else if let sprite = node as? SKSpriteNode,
                  let name = sprite.name,
                  name.hasPrefix("road.generated-v4.") {
            let components = name.split(separator: ".")
            if components.count >= 4, let connectionMask = UInt8(components[2]) {
                assets.applyGeneratedRoadLOD(
                    to: sprite,
                    connectionMask: connectionMask,
                    detail: detail,
                    semanticName: "road.generated-v4.\(connectionMask).\(detail.assetSuffix)"
                )
            }
        } else if let sprite = node as? SKSpriteNode,
                  let name = sprite.name,
                  name.hasPrefix("terrain.ground-ecology."),
                  sprite.children.contains(where: {
                      $0.name?.hasPrefix("ground-ecology.four-view.") == true
                  }) {
            let components = name.split(separator: ".")
            if components.count >= 4 {
                let assetID = String(components[2])
                sprite.name = "terrain.ground-ecology.\(assetID).\(detail.assetSuffix)"
            }
        } else if let sprite = node as? SKSpriteNode,
                  let name = sprite.name,
                  name.hasPrefix("lot.generated-v4."),
                  sprite.children.contains(where: {
                      $0.name?.hasPrefix("lot.four-view.") == true
                  }) {
            // Four-View sprites retain one fixed camNE source at every LOD.
            // Preserve the semantic suffix expected by diagnostics and save/
            // load tests, but never hand their texture back to the legacy
            // generated-atlas residency updater.
            let components = name.split(separator: ".")
            if components.count >= 4 {
                let logicalID = String(components[2])
                sprite.name = "lot.generated-v4.\(logicalID).\(detail.assetSuffix)"
            }
        } else if let sprite = node as? SKSpriteNode,
                  let name = sprite.name,
                  name.hasPrefix("lot.generated-v4.")
                    || name.hasPrefix("terrain.generated-v4.") {
            let components = name.split(separator: ".")
            if components.count >= 4 {
                let semanticPrefix = String(components[0])
                let logicalID = String(components[2])
                assets.applyGeneratedLOD(
                    to: sprite,
                    logicalID: logicalID,
                    detail: detail,
                    semanticName: "\(semanticPrefix).generated-v4.\(logicalID).\(detail.assetSuffix)"
                )
            }
        }
        for child in node.children {
            updateGeneratedLOD(in: child, detail: detail)
        }
    }

    private func updateSelection(_ coordinate: GridCoordinate?) {
        selectionNode.removeAction(forKey: "selection.pulse")
        selectionNode.alpha = 1
        lastPreviewSignature = nil
        guard let coordinate else {
            selectionNode.isHidden = true
            return
        }
        selectionNode.position = style.isoPosition(coordinate)
        selectionNode.isHidden = false
    }

    private func applyActiveActionTarget(_ target: CityMapActionTargetPresentation) {
        let previousSelection = renderedSelection
        hoveredCoordinate = nil
        renderedActiveActionTarget = target
        renderedSelection = target.coordinate
        updateSelection(target.coordinate)
        refreshPersistentConsequenceEmphasis(at: [previousSelection, target.coordinate])
        hoverNode.position = style.isoPosition(target.coordinate)
        hoverNode.isHidden = false
        updateBuildPreview(at: target.coordinate)
    }

    private func refreshInteractionPreview() {
        switch renderedInteractionMode {
        case .inspect:
            guard let hoveredCoordinate else {
                clearInteractionPreview()
                return
            }
            hoverNode.position = style.isoPosition(hoveredCoordinate)
            hoverNode.isHidden = false
            updateBuildPreview(at: hoveredCoordinate)
        case .build, .bulldoze:
            hoveredCoordinate = nil
            guard let target = renderedActiveActionTarget,
                  target.coordinate == renderedSelection else {
                clearInteractionPreview()
                return
            }
            hoverNode.position = style.isoPosition(target.coordinate)
            hoverNode.isHidden = false
            updateBuildPreview(at: target.coordinate)
        }
    }

    private func clearInteractionPreview() {
        lastPreviewSignature = nil
        hoverNode.removeAllChildren()
        hoverNode.isHidden = true
    }

    private func updateBuildPreview(at coordinate: GridCoordinate) {
        guard let state = renderedState else { return }
        let primaryAction = renderedActiveActionTarget.flatMap {
            $0.coordinate == coordinate ? $0.primaryAction : nil
        }
        guard let status = interactionPreviewStatus(
            at: coordinate,
            state: state,
            primaryAction: primaryAction
        ) else {
            clearInteractionPreview()
            return
        }
        let isInspecting: Bool
        if case .inspect = status { isInspecting = true } else { isInspecting = false }
        hoverNode.isHidden = isInspecting && renderedSelection == coordinate
        let signature = InteractionPreviewSignature(
            coordinate: coordinate,
            status: status,
            detail: currentCameraDetailLevel,
            selectedCoordinate: renderedSelection
        )
        guard signature != lastPreviewSignature else { return }
        lastPreviewSignature = signature
        hoverNode.removeAllChildren()

        let presentation = previewPresentation(status)
        let color = presentation.color
        if isInspecting {
            hoverNode.path = nil
            hoverNode.fillColor = .clear
            hoverNode.strokeColor = .clear
            addInspectHoverAdornment(to: hoverNode)
        } else {
            hoverNode.path = style.diamondPath(width: tileWidth, height: tileHeight)
            hoverNode.fillColor = color.withAlphaComponent(0.035)
            hoverNode.strokeColor = color.withAlphaComponent(0.90)
            hoverNode.lineWidth = presentation.isBlocked ? 2.6 : 2.2
        }

        if case .validBuild(let kind) = status {
            addPlacementGhost(kind, at: coordinate, state: state, alpha: 0.54, to: hoverNode)
        } else if case .invalidBuild(let kind, _) = status {
            addPlacementGhost(kind, at: coordinate, state: state, alpha: 0.24, to: hoverNode)
        }
        if presentation.isBlocked {
            addInvalidHatch(color: color, to: hoverNode)
        }
    }

    private func addInspectHoverAdornment(to node: SKNode) {
        // Inspect hover is a quiet frontage bracket below the authored facade,
        // not a second selection ring. Selection retains the complete grounded
        // boundary and cyan frontage anchor; build modes retain the full
        // valid/invalid parcel footprint.
        let y = -tileHeight / 2 + 2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -12, y: y + 3.5))
        path.addLine(to: CGPoint(x: -8, y: y))
        path.addLine(to: CGPoint(x: -4, y: y))
        path.move(to: CGPoint(x: 12, y: y + 3.5))
        path.addLine(to: CGPoint(x: 8, y: y))
        path.addLine(to: CGPoint(x: 4, y: y))
        let bracket = SKShapeNode(path: path)
        bracket.name = "interaction.hover.frontage-brackets"
        bracket.fillColor = .clear
        bracket.strokeColor = NSColor.white.withAlphaComponent(0.68)
        bracket.lineWidth = 1
        bracket.lineCap = .round
        bracket.lineJoin = .round
        bracket.zPosition = 2
        node.addChild(bracket)
    }

    private func interactionPreviewStatus(
        at coordinate: GridCoordinate,
        state: CityGameState,
        primaryAction: CityMapPrimaryActionPresentation?
    ) -> InteractionPreviewStatus? {
        switch renderedInteractionMode {
        case .inspect:
            return .inspect(state.tile(at: coordinate)?.kind ?? .empty)
        case .build(let kind):
            guard let primaryAction else { return nil }
            return primaryAction.isAvailable
                ? .validBuild(kind)
                : .invalidBuild(kind, primaryAction.disclosure)
        case .bulldoze:
            guard let primaryAction,
                  let tile = state.tile(at: coordinate) else { return nil }
            return primaryAction.isAvailable
                ? .validBulldoze(tile.kind)
                : .invalidBulldoze(primaryAction.disclosure)
        }
    }

    private func previewPresentation(
        _ status: InteractionPreviewStatus
    ) -> (color: NSColor, isBlocked: Bool) {
        switch status {
        case .inspect:
            return (.white, false)
        case .validBuild:
            return (.systemGreen, false)
        case .invalidBuild(_, let reason):
            return (reason.contains("Only one City Hall") ? .systemOrange : .systemRed, true)
        case .validBulldoze:
            return (.systemRed, false)
        case .invalidBulldoze(let reason):
            return (reason.contains("protected") ? .systemOrange : .systemGray, true)
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
        for index in -1...1 {
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
        activeTargetContextBoundsForTesting = .null
        activeTargetRoadFrontierForTesting = nil
        let composition = visualCompositionBounds(in: state)
        let occupiedBounds = composition.occupiedDeveloped
        let cameraPriorityBounds = composition.cameraPriority
        guard !occupiedBounds.isNull, !occupiedBounds.isEmpty,
              !cameraPriorityBounds.isNull, !cameraPriorityBounds.isEmpty else {
            if lastValidDevelopedComposition != nil,
               state.tiles.contains(where: { ![.empty, .road].contains($0.kind) }) {
                // AppKit may deliver a transient incomplete state while a
                // resize/inset pair settles. Keep the last authoritative
                // developed composition and camera instead of falling back to
                // a whole-board fit that makes the district unreadable.
                return
            }
            occupiedDevelopedVisualBoundsForTesting = .null
            cameraPriorityVisualBoundsForTesting = .null
            networkOpportunityVisualBoundsForTesting = .null
            cameraPriorityCoordinatesForTesting = []
            fitCity(state)
            return
        }
        lastValidDevelopedComposition = composition
        occupiedDevelopedVisualBoundsForTesting = occupiedBounds
        cameraPriorityVisualBoundsForTesting = cameraPriorityBounds
        networkOpportunityVisualBoundsForTesting = composition.networkOpportunity
        cameraPriorityCoordinatesForTesting = composition.cameraPriorityCoordinates

        // Camera breathing room is deliberately excluded from the occupied-mass
        // measurement. Only authoritative lots and their immediately adjoining
        // public realm may satisfy that gate.
        let cameraBounds = cameraPriorityBounds.insetBy(dx: -14, dy: -10)

        let safeWidth = max(420, size.width - viewportInsets.leading - viewportInsets.trailing)
        let safeHeight = max(260, size.height - viewportInsets.top - viewportInsets.bottom)
        // The staged HUD creates a deliberately shallow aperture. Width is the
        // primary composition axis for the 2:1 district; authored roofs and
        // shadows may extend beneath translucent chrome instead of forcing the
        // settlement back into the rejected toy-island scale.
        let isCompact = size.width <= 900 || size.height <= 600
        let targetWidthOccupancy: CGFloat = isCompact ? 0.68 : 0.90
        // The authoritative two-block opening is taller than the retired
        // one-cross fixture. Give that real vertical mass the same under-chrome
        // breathing room as its horizontal frontage so the new district does
        // not regress to a smaller default composition.
        let allowedHeightOccupancy: CGFloat = isCompact ? 1.50 : 1.36
        var scale = max(
            cameraBounds.width / (safeWidth * targetWidthOccupancy),
            cameraBounds.height / (safeHeight * allowedHeightOccupancy)
        )
        if isCompact {
            // A fit-to-height camera still produces the rejected tiny island in
            // the compact HUD's unusually shallow opening. Preserve the
            // dominant district horizontally without letting a remote, fully
            // truthful lot pull the entire expansion network back into frame.
            // Remote semantic objects stay rendered, hittable, and reachable
            // through pan; they do not define the deterministic reset view.
            let compactWidthScale = cameraPriorityBounds.width / (safeWidth * 0.64)
            scale = max(scale, min(compactWidthScale, 0.62))
            // Map the semantic thresholds into this window's compressed camera
            // range before the occupied-mass cap below decides whether the
            // authored district needs block detail to remain legible.
            let compactNeighborhoodMinimum = actualCameraScale(
                forCanonicalScale: CameraDetailLevel.blockMaximumCameraScale + 0.01
            )
            let compactNeighborhoodPreferredMaximum = actualCameraScale(
                forCanonicalScale: 0.655
            )
            scale = min(
                compactNeighborhoodPreferredMaximum,
                max(scale, compactNeighborhoodMinimum)
            )
        }
        // A frontage-serving camera is only successful when the actual
        // authoritative occupied mass—not the surrounding opportunity loop—
        // remains legible. This cap preserves one complete road-accessible
        // expansion band in `cameraBounds` while preventing tall utility art or
        // a long connected road component from shrinking the lived district
        // below the Wave 009 width admission bar.
        let developedWidthScale = occupiedBounds.width / (safeWidth * 0.60)
        scale = min(scale, developedWidthScale)
#if DEBUG
        if let proofScale = ProcessInfo.processInfo.environment["CITYSIM_PROOF_CAMERA_SCALE"]
            .flatMap(Double.init) {
            scale = CGFloat(proofScale)
        }
#endif
        scale = min(1.55, max(0.30, scale))
        cameraNode.setScale(scale)

        let safeCenterOffset = CGPoint(
            x: (viewportInsets.leading - viewportInsets.trailing) * scale / 2,
            y: (viewportInsets.bottom - viewportInsets.top) * scale / 2
        )
        cameraNode.position = CGPoint(
            x: cameraBounds.midX - safeCenterOffset.x,
            y: cameraBounds.midY - safeCenterOffset.y
        )
    }

    private func visualCompositionBounds(in state: CityGameState) -> CityVisualCompositionBounds {
        let developed = state.tiles.filter { ![.empty, .road].contains($0.kind) }
        guard !developed.isEmpty else {
            return CityVisualCompositionBounds(
                occupiedDeveloped: .null,
                cameraPriority: .null,
                networkOpportunity: .null,
                cameraPriorityCoordinates: []
            )
        }
        let developedCoordinates = Set(developed.map(\.coordinate))
        let cameraPriorityDevelopment = dominantDevelopedDistrict(in: developed)
        let cameraPriorityCoordinates = Set(cameraPriorityDevelopment.map(\.coordinate))
        let nearbyRoads = state.tiles.filter { tile in
            guard tile.kind == .road else { return false }
            return RoadConnectionMask.cardinalEdges.contains { edge in
                // Frame the lived-in frontage, not the full length of future-facing
                // road stubs. The latter remain available as honest expansion context
                // once the player pans, but must not shrink the opening architecture.
                let delta = edge.coordinateDelta
                return developedCoordinates.contains(GridCoordinate(
                    x: tile.coordinate.x + delta.x,
                    y: tile.coordinate.y + delta.y
                ))
            }
        }
        let cameraPriorityFrontageRoads = nearbyRoads.filter { tile in
            RoadConnectionMask.cardinalEdges.contains { edge in
                let delta = edge.coordinateDelta
                return cameraPriorityCoordinates.contains(GridCoordinate(
                    x: tile.coordinate.x + delta.x,
                    y: tile.coordinate.y + delta.y
                ))
            }
        }
        let cameraPriorityRoads = connectedAuthoritativeRoads(
            from: Set(cameraPriorityFrontageRoads.map(\.coordinate)),
            in: state,
            maximumRoadDistance: 2
        )
        let expansionSockets = state.tiles.filter { tile in
            guard tile.kind == .empty else { return false }
            return RoadConnectionMask.cardinalEdges.contains { edge in
                let delta = edge.coordinateDelta
                return state.tile(at: GridCoordinate(
                    x: tile.coordinate.x + delta.x,
                    y: tile.coordinate.y + delta.y
                ))?.kind == .road
            }
        }

        let occupiedBounds = visualBounds(
            for: developed,
            adjoiningRoads: nearbyRoads,
            state: state
        )
        var cameraPriorityBounds = visualBounds(
            for: cameraPriorityDevelopment,
            adjoiningRoads: cameraPriorityRoads,
            state: state
        )
        let cameraRoadCoordinates = Set(cameraPriorityRoads.map(\.coordinate))
        let cameraExpansionBand = expansionSockets.filter { tile in
            let servesPriorityRoad = RoadConnectionMask.cardinalEdges.contains { edge in
                let delta = edge.coordinateDelta
                return cameraRoadCoordinates.contains(GridCoordinate(
                    x: tile.coordinate.x + delta.x,
                    y: tile.coordinate.y + delta.y
                ))
            }
            guard servesPriorityRoad else { return false }
            return cameraPriorityCoordinates.contains { developed in
                max(
                    abs(developed.x - tile.coordinate.x),
                    abs(developed.y - tile.coordinate.y)
                ) <= 3
            }
        }
        for tile in cameraExpansionBand {
            cameraPriorityBounds = cameraPriorityBounds.union(
                tileGroundBounds(at: style.isoPosition(tile.coordinate))
            )
        }

        var networkBounds = CGRect.null
        let contextTiles = state.tiles.filter { $0.kind == .road } + expansionSockets
        for tile in contextTiles {
            networkBounds = networkBounds.union(tileGroundBounds(at: style.isoPosition(tile.coordinate)))
        }
        return CityVisualCompositionBounds(
            occupiedDeveloped: occupiedBounds,
            cameraPriority: cameraPriorityBounds,
            networkOpportunity: networkBounds,
            cameraPriorityCoordinates: cameraPriorityCoordinates
        )
    }

    /// Returns only real road cells in the component that serves the dominant
    /// developed frontages. The camera can therefore frame one continuous
    /// lived district—including its road-enclosed commons—without allowing
    /// disconnected opportunity stubs or remote empty acreage to shrink it.
    private func connectedAuthoritativeRoads(
        from origins: Set<GridCoordinate>,
        in state: CityGameState,
        maximumRoadDistance: Int
    ) -> [CityTile] {
        let roadsByCoordinate = Dictionary(
            uniqueKeysWithValues: state.tiles.filter { $0.kind == .road }.map {
                ($0.coordinate, $0)
            }
        )
        var pending = origins.filter { roadsByCoordinate[$0] != nil }
            .sorted(by: coordinateComesBefore)
            .map { ($0, 0) }
        var connected = Set<GridCoordinate>()
        while !pending.isEmpty {
            let (coordinate, distance) = pending.removeFirst()
            guard connected.insert(coordinate).inserted else { continue }
            guard distance < maximumRoadDistance else { continue }
            for edge in RoadConnectionMask.cardinalEdges {
                let delta = edge.coordinateDelta
                let neighbor = GridCoordinate(
                    x: coordinate.x + delta.x,
                    y: coordinate.y + delta.y
                )
                if roadsByCoordinate[neighbor] != nil && !connected.contains(neighbor) {
                    pending.append((neighbor, distance + 1))
                }
            }
        }
        return connected.sorted(by: coordinateComesBefore).compactMap {
            roadsByCoordinate[$0]
        }
    }

    /// Selects the largest spatially coherent developed district without using
    /// seed identity, numeric occupancy, balance thresholds, or scenario
    /// knowledge. Remote authoritative places remain rendered and hittable;
    /// they simply do not force the deterministic `0` camera to shrink the
    /// lived-in district into a small island.
    private func dominantDevelopedDistrict(in developed: [CityTile]) -> [CityTile] {
        let tilesByCoordinate = Dictionary(uniqueKeysWithValues: developed.map {
            ($0.coordinate, $0)
        })
        var remaining = Set(tilesByCoordinate.keys)
        var districts: [[CityTile]] = []

        while let origin = remaining.min(by: coordinateComesBefore) {
            remaining.remove(origin)
            var pending = [origin]
            var coordinates = [origin]
            while let current = pending.popLast() {
                let neighbors = remaining.filter { candidate in
                    abs(candidate.x - current.x) + abs(candidate.y - current.y) <= 4
                }
                for neighbor in neighbors {
                    remaining.remove(neighbor)
                    pending.append(neighbor)
                    coordinates.append(neighbor)
                }
            }
            districts.append(coordinates.compactMap { tilesByCoordinate[$0] })
        }

        return districts.max { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count < rhs.count }
            let lhsLevel = lhs.reduce(0) { $0 + max(1, $1.level) }
            let rhsLevel = rhs.reduce(0) { $0 + max(1, $1.level) }
            if lhsLevel != rhsLevel { return lhsLevel < rhsLevel }
            let lhsAnchor = lhs.map(\.coordinate).min(by: coordinateComesBefore)
            let rhsAnchor = rhs.map(\.coordinate).min(by: coordinateComesBefore)
            guard let lhsAnchor, let rhsAnchor else { return false }
            return coordinateComesBefore(rhsAnchor, lhsAnchor)
        } ?? developed
    }

    private func coordinateComesBefore(_ lhs: GridCoordinate, _ rhs: GridCoordinate) -> Bool {
        (lhs.y, lhs.x) < (rhs.y, rhs.x)
    }

    private func visualBounds(
        for developed: [CityTile],
        adjoiningRoads: [CityTile],
        state: CityGameState
    ) -> CGRect {
        var bounds = CGRect.null
        for tile in developed {
            let position = style.isoPosition(tile.coordinate)
            bounds = bounds.union(tileGroundBounds(at: position))
            if let logicalID = generatedLogicalID(for: tile, in: state),
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
        for tile in adjoiningRoads {
            bounds = bounds.union(tileGroundBounds(at: style.isoPosition(tile.coordinate)))
        }
        return bounds
    }

    private func tileGroundBounds(at position: CGPoint) -> CGRect {
        CGRect(
            x: position.x - tileWidth / 2,
            y: position.y - tileHeight / 2,
            width: tileWidth,
            height: tileHeight
        )
    }

    private func generatedLogicalID(for kind: BuildingKind) -> String? {
        switch kind {
        case .residential: "residential_l01"
        case .commercial: "commercial_l01"
        case .industrial: "industrial_l01"
        case .park: "park_l01"
        case .cityHall: "city_hall_l01"
        case .waterTower: "water_tower_l01"
        case .powerPlant: "industrial_l01"
        case .fireStation: "commercial_l01"
        case .policeStation: "city_hall_l01"
        case .school: "residential_l01"
        default: nil
        }
    }

    private func generatedLogicalID(
        for tile: CityTile,
        in state: CityGameState
    ) -> String? {
        if tile.kind == .residential {
            return ResidentialGeneratedAssetIdentity(
                level: tile.level,
                adjacentRoads: RoadConnectionMask.resolving(
                    at: tile.coordinate,
                    in: state
                )
            )?.logicalID
        }
        if tile.kind == .commercial {
            return CommercialGeneratedAssetIdentity(
                level: tile.level,
                adjacentRoads: RoadConnectionMask.resolving(
                    at: tile.coordinate,
                    in: state
                )
            )?.logicalID
        }
        if tile.kind == .industrial && (1...3).contains(tile.level) {
            return IndustrialGeneratedAssetIdentity(
                level: tile.level,
                adjacentRoads: RoadConnectionMask.resolving(
                    at: tile.coordinate,
                    in: state
                )
            )?.logicalID
        }
        return generatedLogicalID(for: tile.kind)
    }

    private func coordinate(at scenePoint: CGPoint) -> GridCoordinate? {
        let hoverHidden = hoverNode.isHidden
        let selectionHidden = selectionNode.isHidden
        hoverNode.isHidden = true
        selectionNode.isHidden = true
        var node: SKNode? = atPoint(scenePoint)
        hoverNode.isHidden = hoverHidden
        selectionNode.isHidden = selectionHidden
        var hitFourViewCanvas = false
        while let current = node {
            if current.children.contains(where: {
                $0.name?.hasPrefix("lot.four-view.") == true
                    || $0.name?.hasPrefix("road.four-view.") == true
                    || $0.name?.hasPrefix("ground-ecology.four-view.") == true
            }) {
                hitFourViewCanvas = true
            }
            if let name = current.name, name.hasPrefix("tile:") {
                if hitFourViewCanvas { break }
                let parts = name.split(separator: ":")
                if parts.count == 3, let x = Int(parts[1]), let y = Int(parts[2]) { return GridCoordinate(x: x, y: y) }
            }
            node = current.parent
        }
        guard let state = renderedState else { return nil }
        return IsometricGridCoordinateResolver(tileWidth: tileWidth, tileHeight: tileHeight)
            .coordinate(
                at: scenePoint,
                gridWidth: state.gridWidth,
                gridHeight: state.gridHeight
            )
    }

    private func configureSelectionAdornment() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -7, y: -tileHeight / 2 + 2))
        path.addLine(to: CGPoint(x: 0, y: -tileHeight / 2 - 2))
        path.addLine(to: CGPoint(x: 7, y: -tileHeight / 2 + 2))
        let anchor = SKShapeNode(path: path)
        anchor.name = "interaction.selection.frontage-anchor"
        anchor.strokeColor = style.palette.civicRoof.withAlphaComponent(0.98)
        anchor.lineWidth = 3
        anchor.lineCap = .round
        anchor.lineJoin = .round
        anchor.zPosition = 3
        selectionNode.addChild(anchor)
    }

    private func configureHighlight(_ node: SKShapeNode, color: NSColor, alpha: CGFloat, z: CGFloat) {
        node.path = style.diamondPath(width: tileWidth, height: tileHeight)
        node.fillColor = color.withAlphaComponent(alpha * 0.32)
        node.strokeColor = color.withAlphaComponent(alpha)
        node.lineWidth = 2.5
        node.zPosition = z
    }

}
