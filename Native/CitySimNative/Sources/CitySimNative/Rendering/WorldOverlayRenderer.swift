import AppKit
import SpriteKit

enum WorldOverlayPattern: String, Sendable {
    case none
    case contours
    case chevrons
    case utilityGrid
    case amenityDots
    case diagonalHatch
}

struct WorldOverlaySample {
    let value: Double
    let color: NSColor
    let pattern: WorldOverlayPattern
}

@MainActor
final class WorldOverlayRenderer {
    private let style: WorldVisualStyle

    init(style: WorldVisualStyle) {
        self.style = style
    }

    func makeOverlay(
        for tile: CityTile,
        state: CityGameState,
        overlay: DataOverlay,
        detail: CameraDetailLevel
    ) -> SKNode {
        let root = SKNode()
        root.name = "overlay.\(overlay.rawValue)"
        guard let sample = sample(for: tile, state: state, overlay: overlay) else { return root }

        let wash = SKShapeNode(path: style.diamondPath(width: style.tileWidth - 3, height: style.tileHeight - 1.5))
        let opacity: CGFloat = tile.kind == .road && overlay == .traffic ? 0.36 : 0.22
        wash.fillColor = sample.color.withAlphaComponent(opacity)
        wash.strokeColor = sample.color.blended(withFraction: 0.22, of: .white)?.withAlphaComponent(0.24)
            ?? sample.color.withAlphaComponent(0.24)
        wash.lineWidth = 0.7
        wash.zPosition = 30
        wash.name = "overlay.base"
        root.addChild(wash)

        if shouldDrawPattern(for: tile, overlay: overlay) {
            let neighborhoodLayer = style.makeDetailLayer(.neighborhood, visibleAt: detail)
            let intensity = overlay == .pollution ? 1 - sample.value : sample.value
            let pattern = makePattern(sample.pattern, intensity: intensity)
            pattern.name = "overlay.pattern.\(sample.pattern.rawValue)"
            pattern.zPosition = 31
            neighborhoodLayer.addChild(pattern)
            root.addChild(neighborhoodLayer)
        }
        return root
    }

    func color(for tile: CityTile, state: CityGameState, overlay: DataOverlay) -> NSColor? {
        sample(for: tile, state: state, overlay: overlay)?.color
    }

    func sample(for tile: CityTile, state: CityGameState, overlay: DataOverlay) -> WorldOverlaySample? {
        switch overlay {
        case .none:
            return nil
        case .landValue:
            let parkBoost = proximityInfluence(from: tile.coordinate, kinds: [.park], radius: 5, in: state) * 0.38
            let civicBoost = proximityInfluence(
                from: tile.coordinate,
                kinds: [.cityHall, .school],
                radius: 7,
                in: state
            ) * 0.22
            let roadBoost = state.neighbors(of: tile.coordinate).contains(where: { $0.kind == .road }) ? 0.14 : 0
            let industryPenalty = proximityInfluence(
                from: tile.coordinate,
                kinds: [.industrial, .powerPlant],
                radius: 5,
                in: state
            ) * 0.42
            return makeSample(0.40 + parkBoost + civicBoost + roadBoost - industryPenalty, pattern: .contours)
        case .traffic:
            guard tile.kind == .road else { return nil }
            let nearbyDevelopment = state.tiles.lazy.filter {
                $0.kind != .empty && $0.kind != .road && self.manhattan($0.coordinate, tile.coordinate) <= 2
            }.count
            let junctionLoad = max(0, state.neighbors(of: tile.coordinate).filter { $0.kind == .road }.count - 2)
            let congestion = min(
                1,
                Double(nearbyDevelopment) * 0.13
                    + Double(junctionLoad) * 0.14
                    + Double(state.population) / 6_000
            )
            return makeSample(1 - congestion, pattern: .chevrons)
        case .utilities:
            if tile.kind == .powerPlant {
                return WorldOverlaySample(value: 1, color: .systemYellow, pattern: .utilityGrid)
            }
            if tile.kind == .waterTower {
                return WorldOverlaySample(value: 1, color: .systemBlue, pattern: .utilityGrid)
            }
            let powerReach = nearestDistance(from: tile.coordinate, kinds: [.powerPlant], in: state)
                .map { max(0, 1 - Double($0) / 12) } ?? 0
            let waterReach = nearestDistance(from: tile.coordinate, kinds: [.waterTower], in: state)
                .map { max(0, 1 - Double($0) / 12) } ?? 0
            let capacityFactor = state.powerCapacity >= state.powerUsed && state.waterCapacity >= state.waterUsed
                ? 1.0
                : 0.35
            return makeSample(min(powerReach, waterReach) * capacityFactor, pattern: .utilityGrid)
        case .happiness:
            let parkBoost = proximityInfluence(from: tile.coordinate, kinds: [.park], radius: 4, in: state) * 0.22
            let serviceBoost = proximityInfluence(
                from: tile.coordinate,
                kinds: [.fireStation, .policeStation, .school],
                radius: 6,
                in: state
            ) * 0.16
            let pollutionPenalty = proximityInfluence(
                from: tile.coordinate,
                kinds: [.industrial, .powerPlant],
                radius: 5,
                in: state
            ) * 0.28
            return makeSample(state.happiness / 100 + parkBoost + serviceBoost - pollutionPenalty,
                              pattern: .amenityDots)
        case .pollution:
            let industrial = proximityInfluence(from: tile.coordinate, kinds: [.industrial], radius: 6, in: state) * 0.62
            let power = proximityInfluence(from: tile.coordinate, kinds: [.powerPlant], radius: 8, in: state) * 0.82
            let parkRelief = proximityInfluence(from: tile.coordinate, kinds: [.park], radius: 3, in: state) * 0.16
            return makeSample(1 - industrial - power + parkRelief, pattern: .diagonalHatch)
        }
    }

    private func makeSample(_ rawValue: Double, pattern: WorldOverlayPattern) -> WorldOverlaySample {
        let value = min(1, max(0, rawValue))
        return WorldOverlaySample(value: value, color: heatColor(value), pattern: pattern)
    }

    private func heatColor(_ value: Double) -> NSColor {
        if value < 0.5 {
            return NSColor.systemRed.blended(withFraction: value * 2, of: .systemYellow) ?? .systemYellow
        }
        return NSColor.systemYellow.blended(withFraction: (value - 0.5) * 2, of: .systemGreen) ?? .systemGreen
    }

    private func makePattern(_ pattern: WorldOverlayPattern, intensity: Double) -> SKNode {
        let root = SKNode()
        let ink = NSColor.white.withAlphaComponent(0.30)
        let count = max(1, min(2, Int((intensity * 2).rounded(.up))))
        switch pattern {
        case .none:
            break
        case .contours:
            for index in 0..<count {
                let inset = CGFloat(index) * 5
                let contour = SKShapeNode(path: style.diamondPath(
                    width: max(12, style.tileWidth * 0.46 - inset),
                    height: max(6, style.tileHeight * 0.46 - inset / 2)
                ))
                contour.fillColor = .clear
                contour.strokeColor = ink
                contour.lineWidth = 0.75
                root.addChild(contour)
            }
        case .chevrons:
            for index in 0..<count {
                let y = CGFloat(index - 1) * 4
                let path = CGMutablePath()
                path.move(to: CGPoint(x: -5, y: y + 2))
                path.addLine(to: CGPoint(x: 0, y: y - 1))
                path.addLine(to: CGPoint(x: 5, y: y + 2))
                let chevron = SKShapeNode(path: path)
                chevron.fillColor = .clear
                chevron.strokeColor = ink
                chevron.lineWidth = 1.1
                chevron.lineCap = .round
                root.addChild(chevron)
            }
        case .utilityGrid:
            let horizontal = SKShapeNode(path: WorldGeometryCache.line(
                from: CGPoint(x: -17, y: 0), to: CGPoint(x: 17, y: 0)
            ))
            horizontal.strokeColor = ink
            horizontal.lineWidth = 0.9
            root.addChild(horizontal)
            for x in stride(from: CGFloat(-12), through: 12, by: 8) {
                let tick = SKShapeNode(path: WorldGeometryCache.line(
                    from: CGPoint(x: x, y: -4), to: CGPoint(x: x, y: 4)
                ))
                tick.strokeColor = ink
                tick.lineWidth = 0.8
                root.addChild(tick)
            }
        case .amenityDots:
            for index in 0..<count {
                let ring = SKShapeNode(circleOfRadius: 2.5 + CGFloat(index) * 3.4)
                ring.fillColor = .clear
                ring.strokeColor = ink
                ring.lineWidth = 0.8
                root.addChild(ring)
            }
        case .diagonalHatch:
            for index in -2...2 {
                let x = CGFloat(index) * 7
                let hatch = SKShapeNode(path: WorldGeometryCache.line(
                    from: CGPoint(x: x - 8, y: -7), to: CGPoint(x: x + 8, y: 7)
                ))
                hatch.strokeColor = ink
                hatch.lineWidth = 0.75
                root.addChild(hatch)
            }
        }
        return root
    }

    private func shouldDrawPattern(for tile: CityTile, overlay: DataOverlay) -> Bool {
        if overlay == .traffic { return tile.kind == .road }
        if overlay == .utilities && (tile.kind == .powerPlant || tile.kind == .waterTower) { return true }
        let salt: UInt64
        switch overlay {
        case .none: return false
        case .landValue: salt = 0x4c41_4e44
        case .traffic: salt = 0x5452_4146
        case .utilities: salt = 0x5554_494c
        case .happiness: salt = 0x4841_5050
        case .pollution: salt = 0x504f_4c4c
        }
        return WorldVisualSeed.variant(count: 5, for: tile.coordinate, kind: tile.kind, salt: salt) == 0
    }

    private func proximityInfluence(
        from coordinate: GridCoordinate,
        kinds: Set<BuildingKind>,
        radius: Int,
        in state: CityGameState
    ) -> Double {
        guard let distance = nearestDistance(from: coordinate, kinds: kinds, in: state), distance <= radius else {
            return 0
        }
        return 1 - Double(distance) / Double(max(1, radius))
    }

    private func nearestDistance(
        from coordinate: GridCoordinate,
        kinds: Set<BuildingKind>,
        in state: CityGameState
    ) -> Int? {
        state.tiles.lazy
            .filter { kinds.contains($0.kind) }
            .map { self.manhattan($0.coordinate, coordinate) }
            .min()
    }

    private func manhattan(_ lhs: GridCoordinate, _ rhs: GridCoordinate) -> Int {
        abs(lhs.x - rhs.x) + abs(lhs.y - rhs.y)
    }
}

typealias OverlayRenderer = WorldOverlayRenderer
