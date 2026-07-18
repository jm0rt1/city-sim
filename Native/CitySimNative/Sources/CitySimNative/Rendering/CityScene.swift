import AppKit
import SpriteKit

@MainActor
final class CityScene: SKScene {
    var onPrimaryAction: ((GridCoordinate) -> Void)?
    var onSecondaryAction: ((GridCoordinate) -> Void)?
    var reducedMotion = false

    private let worldLayer = SKNode()
    private let cameraNode = SKCameraNode()
    private let hoverNode = SKShapeNode()
    private let selectionNode = SKShapeNode()
    private var renderedState: CityGameState?
    private var renderedOverlay: DataOverlay = .none
    private var renderedSelection: GridCoordinate?
    private var renderedTool: BuildingKind = .road
    private var renderedBulldozeMode = false
    private var mouseDownLocation: CGPoint?
    private var lastDragLocation: CGPoint?
    private var didDrag = false
    private let tileWidth: CGFloat = 72
    private let tileHeight: CGFloat = 36

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.105, alpha: 1)
        addChild(worldLayer)
        addChild(cameraNode)
        camera = cameraNode
        configureHighlight(hoverNode, color: .white, alpha: 0.24, z: 90_000)
        configureHighlight(selectionNode, color: NSColor(calibratedRed: 0.25, green: 0.95, blue: 0.78, alpha: 1), alpha: 0.65, z: 90_001)
        worldLayer.addChild(hoverNode)
        worldLayer.addChild(selectionNode)
        hoverNode.isHidden = true
        selectionNode.isHidden = true
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        view.window?.acceptsMouseMovedEvents = true
        if let state = renderedState { fitCity(state) }
    }

    func render(
        state: CityGameState,
        overlay: DataOverlay,
        selection: GridCoordinate?,
        selectedTool: BuildingKind,
        bulldozeMode: Bool
    ) {
        let isFirstRender = renderedState == nil
        let shouldRebuild = renderedState != state || renderedOverlay != overlay
        renderedState = state
        renderedOverlay = overlay
        renderedSelection = selection
        renderedTool = selectedTool
        renderedBulldozeMode = bulldozeMode
        if shouldRebuild { rebuildWorld(state: state, overlay: overlay) }
        updateSelection(selection)
        if isFirstRender { focusDevelopedCore(state) }
    }

    func resize(to newSize: CGSize) {
        size = newSize
    }

    func frameCity() {
        if let state = renderedState { fitCity(state) }
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.location(in: self)
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
        defer { mouseDownLocation = nil; lastDragLocation = nil }
        guard !didDrag, let coordinate = coordinate(at: event.location(in: self)) else { return }
        onPrimaryAction?(coordinate)
    }

    override func rightMouseDown(with event: NSEvent) {
        if let coordinate = coordinate(at: event.location(in: self)) { onSecondaryAction?(coordinate) }
    }

    override func mouseMoved(with event: NSEvent) {
        guard let coordinate = coordinate(at: event.location(in: self)) else {
            hoverNode.isHidden = true
            return
        }
        hoverNode.position = isoPosition(coordinate)
        hoverNode.isHidden = false
        updateBuildPreview(at: coordinate)
    }

    override func scrollWheel(with event: NSEvent) {
        let factor = exp(event.scrollingDeltaY * 0.012)
        let scale = min(2.4, max(0.42, cameraNode.xScale * factor))
        cameraNode.setScale(scale)
    }

    private func rebuildWorld(state: CityGameState, overlay: DataOverlay) {
        worldLayer.removeAllChildren()
        for tile in state.tiles.sorted(by: { ($0.coordinate.x + $0.coordinate.y) < ($1.coordinate.x + $1.coordinate.y) }) {
            let node = makeTile(tile, state: state, overlay: overlay)
            node.position = isoPosition(tile.coordinate)
            node.zPosition = CGFloat(tile.coordinate.x + tile.coordinate.y) * 100
            node.name = "tile:\(tile.coordinate.x):\(tile.coordinate.y)"
            worldLayer.addChild(node)
        }
        worldLayer.addChild(hoverNode)
        worldLayer.addChild(selectionNode)
        updateSelection(renderedSelection)
    }

    private func makeTile(_ tile: CityTile, state: CityGameState, overlay: DataOverlay) -> SKNode {
        let container = SKNode()
        let terrain = SKShapeNode(path: diamondPath(width: tileWidth, height: tileHeight))
        terrain.fillColor = terrainColor(for: tile, state: state, overlay: overlay)
        terrain.strokeColor = terrain.fillColor.blended(withFraction: 0.28, of: .black) ?? .black
        terrain.lineWidth = 0.8
        container.addChild(terrain)

        switch tile.kind {
        case .empty: addGroundDetail(to: container, coordinate: tile.coordinate)
        case .road: addRoad(to: container, coordinate: tile.coordinate, state: state)
        case .park: addPark(to: container, coordinate: tile.coordinate)
        default: addBuilding(tile, to: container)
        }
        if tile.constructionProgress < 1 { addConstruction(to: container, progress: tile.constructionProgress) }
        return container
    }

    private func addGroundDetail(to node: SKNode, coordinate: GridCoordinate) {
        let detailSeed = (coordinate.x * 17 + coordinate.y * 31)
        if detailSeed % 9 == 0 {
            let shrub = SKShapeNode(circleOfRadius: 2.6)
            shrub.fillColor = NSColor(calibratedRed: 0.16, green: 0.52, blue: 0.27, alpha: 0.9)
            shrub.strokeColor = .white.withAlphaComponent(0.08)
            shrub.position = CGPoint(x: CGFloat((coordinate.x % 3) * 7 - 7), y: 3)
            node.addChild(shrub)
        } else if detailSeed % 13 == 0 {
            let flowers = SKShapeNode(circleOfRadius: 1.7)
            flowers.fillColor = NSColor(calibratedRed: 0.94, green: 0.73, blue: 0.37, alpha: 0.9)
            flowers.strokeColor = .clear
            flowers.position = CGPoint(x: -8, y: 2)
            node.addChild(flowers)
        }
    }

    private func addRoad(to node: SKNode, coordinate: GridCoordinate, state: CityGameState) {
        let asphalt = SKShapeNode(path: diamondPath(width: tileWidth, height: tileHeight * 0.72))
        asphalt.fillColor = NSColor(calibratedWhite: 0.16, alpha: 1)
        asphalt.strokeColor = NSColor(calibratedWhite: 0.34, alpha: 1)
        asphalt.position.y = 1
        node.addChild(asphalt)
        let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        let connected = directions.filter { delta in
            state.tile(at: GridCoordinate(x: coordinate.x + delta.0, y: coordinate.y + delta.1))?.kind == .road
        }
        for delta in connected {
            let endpoint = CGPoint(
                x: CGFloat(delta.0 - delta.1) * tileWidth * 0.46,
                y: -CGFloat(delta.0 + delta.1) * tileHeight * 0.46
            )
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addLine(to: endpoint)
            let centerline = SKShapeNode(path: path)
            centerline.strokeColor = NSColor(calibratedRed: 0.96, green: 0.78, blue: 0.31, alpha: 0.78)
            centerline.lineWidth = 1.25
            centerline.lineCap = .round
            centerline.zPosition = 3
            node.addChild(centerline)
        }
        let junction = SKShapeNode(circleOfRadius: 1.7)
        junction.fillColor = NSColor(calibratedRed: 0.96, green: 0.78, blue: 0.31, alpha: 0.82)
        junction.strokeColor = .clear
        junction.zPosition = 3
        node.addChild(junction)
        if !reducedMotion, connected.count >= 2, (coordinate.x + coordinate.y) % 5 == 0 {
            let car = SKShapeNode(rectOf: CGSize(width: 8, height: 4), cornerRadius: 1.5)
            let carColors = [
                NSColor(calibratedRed: 0.22, green: 0.72, blue: 0.95, alpha: 1),
                NSColor(calibratedRed: 0.96, green: 0.38, blue: 0.28, alpha: 1),
                NSColor(calibratedRed: 0.92, green: 0.88, blue: 0.72, alpha: 1)
            ]
            car.fillColor = carColors[(coordinate.x + coordinate.y) % carColors.count]
            car.strokeColor = .white.withAlphaComponent(0.35)
            car.zPosition = 7
            let first = connected[0]
            let last = connected[1]
            let start = CGPoint(x: -CGFloat(first.0 - first.1) * 22, y: CGFloat(first.0 + first.1) * 11)
            let end = CGPoint(x: CGFloat(last.0 - last.1) * 22, y: -CGFloat(last.0 + last.1) * 11)
            car.position = start
            car.zRotation = atan2(end.y - start.y, end.x - start.x)
            car.run(.repeatForever(.sequence([.move(to: end, duration: 2.6), .move(to: start, duration: 0)])))
            node.addChild(car)
        }
    }

    private func addPark(to node: SKNode, coordinate: GridCoordinate) {
        for index in 0..<4 {
            let trunk = SKShapeNode(rectOf: CGSize(width: 2.5, height: 8), cornerRadius: 1)
            trunk.fillColor = NSColor(calibratedRed: 0.36, green: 0.22, blue: 0.12, alpha: 1)
            trunk.strokeColor = .clear
            trunk.position = CGPoint(x: CGFloat(index % 2) * 17 - 8, y: CGFloat(index / 2) * 8 + 3)
            let crown = SKShapeNode(circleOfRadius: 6.5)
            crown.fillColor = NSColor(calibratedRed: 0.18, green: 0.62 + CGFloat((coordinate.x + index) % 2) * 0.08, blue: 0.34, alpha: 1)
            crown.strokeColor = NSColor(calibratedWhite: 1, alpha: 0.15)
            crown.position.y = 7
            trunk.addChild(crown)
            trunk.zPosition = CGFloat(index + 2)
            node.addChild(trunk)
        }
    }

    private func addBuilding(_ tile: CityTile, to node: SKNode) {
        let height = buildingHeight(tile)
        let width = tile.kind == .cityHall ? 48.0 : tile.kind == .powerPlant ? 46.0 : 38.0
        let depth = width * 0.48
        let base = buildingColor(tile.kind)

        let shadow = SKShapeNode(ellipseOf: CGSize(width: width * 1.35, height: depth * 0.75))
        shadow.fillColor = .black.withAlphaComponent(0.24)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 7, y: -4)
        shadow.zPosition = -1
        node.addChild(shadow)

        let left = SKShapeNode(path: polygonPath([
            CGPoint(x: -width / 2, y: 3), CGPoint(x: 0, y: -depth / 2 + 3),
            CGPoint(x: 0, y: height - depth / 2 + 3), CGPoint(x: -width / 2, y: height + 3)
        ]))
        left.fillColor = base.blended(withFraction: 0.32, of: .black) ?? base
        left.strokeColor = .black.withAlphaComponent(0.3)
        let right = SKShapeNode(path: polygonPath([
            CGPoint(x: 0, y: -depth / 2 + 3), CGPoint(x: width / 2, y: 3),
            CGPoint(x: width / 2, y: height + 3), CGPoint(x: 0, y: height - depth / 2 + 3)
        ]))
        right.fillColor = base.blended(withFraction: 0.16, of: .black) ?? base
        right.strokeColor = .black.withAlphaComponent(0.3)
        let roof = SKShapeNode(path: diamondPath(width: width, height: depth))
        roof.fillColor = base.blended(withFraction: 0.2, of: .white) ?? base
        roof.strokeColor = .white.withAlphaComponent(0.28)
        roof.position.y = height + 3
        node.addChild(left); node.addChild(right); node.addChild(roof)

        if [.residential, .commercial, .cityHall, .school].contains(tile.kind) {
            addWindows(to: node, height: height, width: width)
        }
        if [.industrial, .powerPlant].contains(tile.kind) { addSmoke(to: node, height: height, width: width) }
        addLandmarkDetail(tile.kind, to: node, height: height, width: width)
        let badge = SKLabelNode(fontNamed: ".AppleSystemUIFont")
        badge.text = tile.kind.symbolGlyph
        badge.fontSize = 11
        badge.fontColor = .white.withAlphaComponent(0.86)
        badge.position = CGPoint(x: 0, y: height + 1)
        badge.zPosition = 8
        node.addChild(badge)
    }

    private func addWindows(to node: SKNode, height: CGFloat, width: CGFloat) {
        let floors = max(1, Int(height / 14))
        for floor in 0..<floors {
            for side in [-1, 1] {
                let window = SKShapeNode(rectOf: CGSize(width: 4.5, height: 3.4), cornerRadius: 0.7)
                window.fillColor = NSColor(calibratedRed: 0.36, green: 0.76, blue: 0.92, alpha: 0.78)
                window.strokeColor = .clear
                window.position = CGPoint(x: CGFloat(side) * width * 0.22, y: CGFloat(floor) * 11 + 9)
                window.zPosition = 4
                node.addChild(window)
            }
        }
    }

    private func addSmoke(to node: SKNode, height: CGFloat, width: CGFloat) {
        let stack = SKShapeNode(rectOf: CGSize(width: 6, height: 18))
        stack.fillColor = NSColor(calibratedWhite: 0.22, alpha: 1)
        stack.strokeColor = .clear
        stack.position = CGPoint(x: width * 0.24, y: height + 10)
        node.addChild(stack)
        guard !reducedMotion else { return }
        for index in 0..<3 {
            let puff = SKShapeNode(circleOfRadius: CGFloat(4 + index))
            puff.fillColor = NSColor(calibratedWhite: 0.72, alpha: 0.42)
            puff.strokeColor = .clear
            puff.position = CGPoint(x: stack.position.x, y: height + 22)
            puff.run(.repeatForever(.sequence([.wait(forDuration: Double(index) * 0.5), .group([.moveBy(x: 8, y: 28, duration: 2.2), .fadeOut(withDuration: 2.2)]), .run { puff.position = CGPoint(x: stack.position.x, y: height + 22); puff.alpha = 1 }])))
            node.addChild(puff)
        }
    }

    private func addLandmarkDetail(_ kind: BuildingKind, to node: SKNode, height: CGFloat, width: CGFloat) {
        switch kind {
        case .waterTower:
            let tank = SKShapeNode(ellipseOf: CGSize(width: 28, height: 14))
            tank.fillColor = NSColor(calibratedRed: 0.58, green: 0.86, blue: 0.95, alpha: 1)
            tank.strokeColor = .white.withAlphaComponent(0.4)
            tank.position.y = height + 13
            tank.zPosition = 6
            node.addChild(tank)
        case .cityHall:
            let spire = SKShapeNode(path: polygonPath([
                CGPoint(x: -5, y: height + 4), CGPoint(x: 0, y: height + 19), CGPoint(x: 5, y: height + 4)
            ]))
            spire.fillColor = NSColor(calibratedRed: 0.92, green: 0.78, blue: 0.28, alpha: 1)
            spire.strokeColor = .white.withAlphaComponent(0.35)
            spire.zPosition = 7
            node.addChild(spire)
        case .fireStation:
            let door = SKShapeNode(rectOf: CGSize(width: 14, height: 12), cornerRadius: 1)
            door.fillColor = NSColor(calibratedWhite: 0.12, alpha: 1)
            door.strokeColor = .white.withAlphaComponent(0.22)
            door.position = CGPoint(x: 7, y: 8)
            door.zPosition = 5
            node.addChild(door)
        case .school:
            let flagpole = SKShapeNode(rectOf: CGSize(width: 1.5, height: 20))
            flagpole.fillColor = .white.withAlphaComponent(0.75)
            flagpole.strokeColor = .clear
            flagpole.position = CGPoint(x: width * 0.3, y: height + 9)
            flagpole.zPosition = 6
            let flag = SKShapeNode(path: polygonPath([.zero, CGPoint(x: 10, y: -3), CGPoint(x: 0, y: -7)]))
            flag.fillColor = NSColor.systemTeal
            flag.strokeColor = .clear
            flag.position.y = 9
            flagpole.addChild(flag)
            node.addChild(flagpole)
        default:
            break
        }
    }

    private func addConstruction(to node: SKNode, progress: Double) {
        let frame = SKShapeNode(rectOf: CGSize(width: 48, height: 42))
        frame.strokeColor = NSColor(calibratedRed: 1, green: 0.66, blue: 0.16, alpha: 0.9)
        frame.lineWidth = 2
        frame.fillColor = .clear
        frame.position.y = 20
        frame.zPosition = 20
        node.addChild(frame)
        let label = SKLabelNode(text: "\(Int(progress * 100))%")
        label.fontName = ".AppleSystemUIFontBold"
        label.fontSize = 10
        label.position.y = 17
        label.zPosition = 21
        node.addChild(label)
    }

    private func terrainColor(for tile: CityTile, state: CityGameState, overlay: DataOverlay) -> NSColor {
        guard overlay != .none else {
            let variation = CGFloat((tile.coordinate.x * 13 + tile.coordinate.y * 7) % 5) * 0.012
            return NSColor(calibratedRed: 0.20 + variation, green: 0.42 + variation, blue: 0.25, alpha: 1)
        }
        switch overlay {
        case .landValue:
            let parkBoost = proximityInfluence(from: tile.coordinate, kinds: [.park], radius: 5, in: state) * 0.38
            let civicBoost = proximityInfluence(from: tile.coordinate, kinds: [.cityHall, .school], radius: 7, in: state) * 0.22
            let roadBoost = state.neighbors(of: tile.coordinate).contains(where: { $0.kind == .road }) ? 0.14 : 0
            let industryPenalty = proximityInfluence(from: tile.coordinate, kinds: [.industrial, .powerPlant], radius: 5, in: state) * 0.42
            return heatColor(0.40 + parkBoost + civicBoost + roadBoost - industryPenalty)
        case .traffic:
            guard tile.kind == .road else { return NSColor(calibratedWhite: 0.16, alpha: 0.9) }
            let nearbyDevelopment = state.tiles.filter {
                $0.kind != .empty && $0.kind != .road && manhattan($0.coordinate, tile.coordinate) <= 2
            }.count
            let junctionLoad = max(0, state.neighbors(of: tile.coordinate).filter { $0.kind == .road }.count - 2)
            let congestion = min(1, Double(nearbyDevelopment) * 0.13 + Double(junctionLoad) * 0.14 + Double(state.population) / 6_000)
            return heatColor(1 - congestion)
        case .utilities:
            if tile.kind == .powerPlant { return .systemYellow }
            if tile.kind == .waterTower { return .systemBlue }
            let powerReach = nearestDistance(from: tile.coordinate, kinds: [.powerPlant], in: state)
                .map { max(0, 1 - Double($0) / 12) } ?? 0
            let waterReach = nearestDistance(from: tile.coordinate, kinds: [.waterTower], in: state)
                .map { max(0, 1 - Double($0) / 12) } ?? 0
            let capacityFactor = state.powerCapacity >= state.powerUsed && state.waterCapacity >= state.waterUsed ? 1.0 : 0.35
            return heatColor(min(powerReach, waterReach) * capacityFactor)
        case .happiness:
            let parkBoost = proximityInfluence(from: tile.coordinate, kinds: [.park], radius: 4, in: state) * 0.22
            let serviceBoost = proximityInfluence(from: tile.coordinate, kinds: [.fireStation, .policeStation, .school], radius: 6, in: state) * 0.16
            let pollutionPenalty = proximityInfluence(from: tile.coordinate, kinds: [.industrial, .powerPlant], radius: 5, in: state) * 0.28
            return heatColor(state.happiness / 100 + parkBoost + serviceBoost - pollutionPenalty)
        case .pollution:
            let industrial = proximityInfluence(from: tile.coordinate, kinds: [.industrial], radius: 6, in: state) * 0.62
            let power = proximityInfluence(from: tile.coordinate, kinds: [.powerPlant], radius: 8, in: state) * 0.82
            let parkRelief = proximityInfluence(from: tile.coordinate, kinds: [.park], radius: 3, in: state) * 0.16
            return heatColor(1 - industrial - power + parkRelief)
        case .none: return .systemGreen
        }
    }

    private func heatColor(_ rawValue: Double) -> NSColor {
        let value = min(1, max(0, rawValue))
        if value < 0.5 {
            return NSColor.systemRed.blended(withFraction: value * 2, of: .systemYellow) ?? .systemYellow
        }
        return NSColor.systemYellow.blended(withFraction: (value - 0.5) * 2, of: .systemGreen) ?? .systemGreen
    }

    private func proximityInfluence(
        from coordinate: GridCoordinate,
        kinds: Set<BuildingKind>,
        radius: Int,
        in state: CityGameState
    ) -> Double {
        guard let distance = nearestDistance(from: coordinate, kinds: kinds, in: state), distance <= radius else { return 0 }
        return 1 - Double(distance) / Double(max(1, radius))
    }

    private func nearestDistance(
        from coordinate: GridCoordinate,
        kinds: Set<BuildingKind>,
        in state: CityGameState
    ) -> Int? {
        state.tiles.lazy.filter { kinds.contains($0.kind) }.map { self.manhattan($0.coordinate, coordinate) }.min()
    }

    private func manhattan(_ lhs: GridCoordinate, _ rhs: GridCoordinate) -> Int {
        abs(lhs.x - rhs.x) + abs(lhs.y - rhs.y)
    }

    private func buildingHeight(_ tile: CityTile) -> CGFloat {
        let base: CGFloat
        switch tile.kind {
        case .residential: base = 26
        case .commercial: base = 36
        case .industrial: base = 24
        case .powerPlant: base = 32
        case .waterTower: base = 46
        case .cityHall: base = 42
        default: base = 28
        }
        return base + CGFloat(max(0, tile.level - 1)) * 13
    }

    private func buildingColor(_ kind: BuildingKind) -> NSColor {
        switch kind {
        case .residential: NSColor(calibratedRed: 0.26, green: 0.68, blue: 0.84, alpha: 1)
        case .commercial: NSColor(calibratedRed: 0.56, green: 0.42, blue: 0.88, alpha: 1)
        case .industrial: NSColor(calibratedRed: 0.84, green: 0.48, blue: 0.22, alpha: 1)
        case .powerPlant: NSColor(calibratedRed: 0.86, green: 0.67, blue: 0.20, alpha: 1)
        case .waterTower: NSColor(calibratedRed: 0.24, green: 0.70, blue: 0.83, alpha: 1)
        case .fireStation: NSColor(calibratedRed: 0.88, green: 0.25, blue: 0.24, alpha: 1)
        case .policeStation: NSColor(calibratedRed: 0.24, green: 0.39, blue: 0.78, alpha: 1)
        case .school: NSColor(calibratedRed: 0.82, green: 0.63, blue: 0.24, alpha: 1)
        case .cityHall: NSColor(calibratedRed: 0.80, green: 0.82, blue: 0.86, alpha: 1)
        default: NSColor.systemGray
        }
    }

    private func updateSelection(_ coordinate: GridCoordinate?) {
        guard let coordinate else { selectionNode.isHidden = true; return }
        selectionNode.position = isoPosition(coordinate)
        selectionNode.isHidden = false
    }

    private func updateBuildPreview(at coordinate: GridCoordinate) {
        hoverNode.removeAllChildren()
        guard let state = renderedState else { return }
        let isOpen = state.tile(at: coordinate)?.kind == .empty
        let valid: Bool
        if renderedBulldozeMode {
            valid = state.tile(at: coordinate).map { $0.kind != .empty && $0.kind != .cityHall } ?? false
        } else if isOpen, case .success = CitySimulation.validateBuild(renderedTool, at: coordinate, in: state) {
            valid = true
        } else {
            valid = false
        }
        let color: NSColor
        if renderedBulldozeMode {
            color = valid ? .systemRed : .systemGray
        } else {
            color = isOpen ? (valid ? .systemGreen : .systemRed) : .white
        }
        hoverNode.fillColor = color.withAlphaComponent(0.16)
        hoverNode.strokeColor = color.withAlphaComponent(0.9)
        let glyph = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
        glyph.text = renderedBulldozeMode ? "⌫" : (isOpen ? renderedTool.symbolGlyph : "⌕")
        glyph.fontSize = 14
        glyph.fontColor = color
        glyph.position.y = 7
        glyph.zPosition = 3
        hoverNode.addChild(glyph)
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
        let points = developed.map { isoPosition($0.coordinate) }
        let center = CGPoint(
            x: points.reduce(0) { $0 + $1.x } / CGFloat(points.count),
            y: points.reduce(0) { $0 + $1.y } / CGFloat(points.count) + 30
        )
        cameraNode.position = center
        cameraNode.setScale(0.72)
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

    private func isoPosition(_ coordinate: GridCoordinate) -> CGPoint {
        CGPoint(x: CGFloat(coordinate.x - coordinate.y) * tileWidth / 2,
                y: -CGFloat(coordinate.x + coordinate.y) * tileHeight / 2)
    }

    private func configureHighlight(_ node: SKShapeNode, color: NSColor, alpha: CGFloat, z: CGFloat) {
        node.path = diamondPath(width: tileWidth, height: tileHeight)
        node.fillColor = color.withAlphaComponent(alpha * 0.32)
        node.strokeColor = color.withAlphaComponent(alpha)
        node.lineWidth = 2.5
        node.zPosition = z
    }

    private func diamondPath(width: CGFloat, height: CGFloat) -> CGPath {
        polygonPath([CGPoint(x: 0, y: height / 2), CGPoint(x: width / 2, y: 0), CGPoint(x: 0, y: -height / 2), CGPoint(x: -width / 2, y: 0)])
    }

    private func polygonPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }
}

private extension BuildingKind {
    var symbolGlyph: String {
        switch self {
        case .road: "═"
        case .residential: "⌂"
        case .commercial: "$"
        case .industrial: "⚙"
        case .park: "♣"
        case .powerPlant: "ϟ"
        case .waterTower: "●"
        case .fireStation: "F"
        case .policeStation: "P"
        case .school: "A"
        case .cityHall: "★"
        case .empty: ""
        }
    }
}
