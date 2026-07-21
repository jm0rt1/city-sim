import AppKit
import SpriteKit

struct RoadConnectionMask: OptionSet, Hashable, Sendable {
    let rawValue: UInt8

    init(rawValue: UInt8) {
        self.rawValue = rawValue & 0b1111
    }

    static let north = RoadConnectionMask(rawValue: 1 << 0)
    static let east = RoadConnectionMask(rawValue: 1 << 1)
    static let south = RoadConnectionMask(rawValue: 1 << 2)
    static let west = RoadConnectionMask(rawValue: 1 << 3)
    static let all: RoadConnectionMask = [.north, .east, .south, .west]

    static let cardinalEdges: [RoadConnectionMask] = [.north, .east, .south, .west]

    static var allMasks: [RoadConnectionMask] {
        (0..<16).map { RoadConnectionMask(rawValue: UInt8($0)) }
    }

    var edges: [RoadConnectionMask] {
        Self.cardinalEdges.filter(contains)
    }

    var connectionCount: Int {
        rawValue.nonzeroBitCount
    }

    var opposite: RoadConnectionMask {
        switch self {
        case .north: .south
        case .east: .west
        case .south: .north
        case .west: .east
        default: []
        }
    }

    var coordinateDelta: (x: Int, y: Int) {
        switch self {
        case .north: (0, -1)
        case .east: (1, 0)
        case .south: (0, 1)
        case .west: (-1, 0)
        default: (0, 0)
        }
    }

    func rotatedClockwise(_ quarterTurns: Int = 1) -> RoadConnectionMask {
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns != 0 else { return self }
        var result: RoadConnectionMask = []
        for edge in edges {
            let bit = (Int(edge.rawValue.trailingZeroBitCount) + turns) % 4
            result.insert(RoadConnectionMask(rawValue: UInt8(1 << bit)))
        }
        return result
    }

    static func resolving(at coordinate: GridCoordinate, in state: CityGameState) -> RoadConnectionMask {
        var result: RoadConnectionMask = []
        for edge in cardinalEdges {
            let delta = edge.coordinateDelta
            let neighbor = GridCoordinate(x: coordinate.x + delta.x, y: coordinate.y + delta.y)
            if state.tile(at: neighbor)?.kind == .road {
                result.insert(edge)
            }
        }
        return result
    }
}

struct RoadTopology: Equatable, Sendable {
    enum Classification: String, CaseIterable, Sendable {
        case isolated
        case end
        case straight
        case corner
        case tee
        case crossing
    }

    let mask: RoadConnectionMask
    let classification: Classification
    let quarterTurns: Int

    init(mask: RoadConnectionMask) {
        let normalized = RoadConnectionMask(rawValue: mask.rawValue)
        self.mask = normalized

        switch normalized.connectionCount {
        case 0:
            classification = .isolated
            quarterTurns = 0
        case 1:
            classification = .end
            quarterTurns = Self.rotationIndex(forSingleEdge: normalized.edges[0])
        case 2 where normalized == [.north, .south]:
            classification = .straight
            quarterTurns = 0
        case 2 where normalized == [.east, .west]:
            classification = .straight
            quarterTurns = 1
        case 2:
            classification = .corner
            quarterTurns = Self.cornerRotation(for: normalized)
        case 3:
            classification = .tee
            quarterTurns = Self.teeRotation(for: normalized)
        default:
            classification = .crossing
            quarterTurns = 0
        }
    }

    var rotation: CGFloat {
        CGFloat(quarterTurns) * .pi / 2
    }

    var isJunction: Bool {
        classification == .tee || classification == .crossing
    }

    private static func rotationIndex(forSingleEdge edge: RoadConnectionMask) -> Int {
        switch edge {
        case .north: 0
        case .east: 1
        case .south: 2
        case .west: 3
        default: 0
        }
    }

    private static func cornerRotation(for mask: RoadConnectionMask) -> Int {
        switch mask {
        case [.north, .east]: 0
        case [.east, .south]: 1
        case [.south, .west]: 2
        case [.west, .north]: 3
        default: 0
        }
    }

    private static func teeRotation(for mask: RoadConnectionMask) -> Int {
        switch mask {
        case [.north, .east, .south]: 0
        case [.east, .south, .west]: 1
        case [.south, .west, .north]: 2
        case [.west, .north, .east]: 3
        default: 0
        }
    }
}

@MainActor
final class RoadRenderer {
    private let style: WorldVisualStyle
    private let assets: WorldAssetCatalog

    init(style: WorldVisualStyle, assets: WorldAssetCatalog = .shared) {
        self.style = style
        self.assets = assets
    }

    func makeRoad(
        at coordinate: GridCoordinate,
        in state: CityGameState,
        detail: CameraDetailLevel,
        reducedMotion: Bool
    ) -> SKNode {
        makeRoad(
            at: coordinate,
            connections: RoadConnectionMask.resolving(at: coordinate, in: state),
            detail: detail,
            reducedMotion: reducedMotion
        )
    }

    func makeRoad(
        at coordinate: GridCoordinate,
        connections: RoadConnectionMask,
        detail: CameraDetailLevel,
        reducedMotion: Bool
    ) -> SKNode {
        let topology = RoadTopology(mask: connections)
        let root = SKNode()
        root.name = "road.\(topology.classification.rawValue).\(connections.rawValue)"

        let cityLayer = style.makeDetailLayer(.city, visibleAt: detail)
        let neighborhoodLayer = style.makeDetailLayer(.neighborhood, visibleAt: detail)
        let blockLayer = style.makeDetailLayer(.block, visibleAt: detail)
        root.addChild(cityLayer)
        root.addChild(neighborhoodLayer)
        root.addChild(blockLayer)

        let generatedRoadName = String(
            format: "generated_v4_road_mask_%02d_%@",
            connections.rawValue,
            detail.assetSuffix
        )
        if let road = assets.sprite(
            named: generatedRoadName,
            size: CGSize(width: style.tileWidth + 2, height: style.tileHeight + 1)
        ) {
            road.name = "road.generated-v4.\(connections.rawValue).\(detail.assetSuffix)"
            road.zPosition = 2
            cityLayer.addChild(road)
        } else if let road = assets.sprite(
            named: String(format: "road_mask_%02d", connections.rawValue),
            // Slight atlas overlap keeps adjacent road materials continuous
            // across per-tile depth layers without changing hit geometry.
            size: CGSize(width: style.tileWidth + 6, height: style.tileHeight + 3)
        ) {
            road.zPosition = 2
            cityLayer.addChild(road)
        } else {
            addRoadbed(for: topology, to: cityLayer)
            addLaneLanguage(for: topology, to: neighborhoodLayer)
        }
        addStreetFurniture(
            at: coordinate,
            topology: topology,
            reducedMotion: reducedMotion,
            to: blockLayer
        )
        return root
    }

    private func addRoadbed(for topology: RoadTopology, to layer: SKNode) {
        if topology.classification == .isolated {
            let sidewalk = SKShapeNode(path: style.diamondPath(width: 48, height: 24))
            sidewalk.fillColor = style.palette.sidewalk
            sidewalk.strokeColor = style.palette.curb
            sidewalk.lineWidth = 2
            sidewalk.zPosition = 0
            layer.addChild(sidewalk)

            let asphalt = SKShapeNode(path: style.diamondPath(width: 38, height: 19))
            asphalt.fillColor = style.palette.asphalt
            asphalt.strokeColor = style.palette.asphaltLight
            asphalt.lineWidth = 1
            asphalt.zPosition = 1
            layer.addChild(asphalt)
            return
        }

        let segments = topology.mask.edges.map { edge -> CGPath in
            let endpoint = style.edgePoint(for: edge, inset: 0)
            let start = topology.classification == .end
                ? CGPoint(x: -endpoint.x * 0.30, y: -endpoint.y * 0.30)
                : .zero
            return WorldGeometryCache.line(from: start, to: endpoint)
        }

        // Draw material passes rather than complete branches. This prevents a
        // later branch's sidewalk from cutting a pale ring through prior asphalt.
        for path in segments {
            layer.addChild(stroke(path, color: style.palette.sidewalk, width: 25, z: 0, cap: .butt))
        }
        for path in segments {
            layer.addChild(stroke(path, color: style.palette.curb, width: 20.5, z: 1, cap: .butt))
        }
        for path in segments {
            layer.addChild(stroke(path, color: style.palette.asphalt, width: 17, z: 2, cap: .butt))
        }

        addLayeredJunction(to: layer)

        if topology.classification == .end, let edge = topology.mask.edges.first {
            addEndCap(onUnconnectedSideOf: edge, to: layer)
        }
    }

    private func addLaneLanguage(for topology: RoadTopology, to layer: SKNode) {
        for edge in topology.mask.edges {
            let endpoint = style.edgePoint(for: edge, inset: 3)
            let path = WorldGeometryCache.line(
                from: CGPoint(x: endpoint.x * 0.18, y: endpoint.y * 0.18),
                to: endpoint
            )
            let dashed = path.copy(dashingWithPhase: 0, lengths: [4.5, 4.0])
            layer.addChild(stroke(dashed, color: style.palette.laneMark, width: 1.25, z: 6, cap: .butt))
        }

        if topology.isJunction {
            for edge in topology.mask.edges {
                addCrosswalk(on: edge, to: layer)
            }
        } else if topology.classification == .end, let edge = topology.mask.edges.first {
            addStopLine(on: edge.opposite, to: layer)
        }

        if topology.classification == .straight {
            let seam = SKShapeNode(path: style.diamondPath(width: 12, height: 6))
            seam.strokeColor = style.palette.asphaltLight.withAlphaComponent(0.65)
            seam.fillColor = .clear
            seam.lineWidth = 0.7
            seam.zPosition = 5
            layer.addChild(seam)
        }
    }

    private func addLayeredJunction(to layer: SKNode) {
        let sidewalk = SKShapeNode(circleOfRadius: 12.5)
        sidewalk.fillColor = style.palette.sidewalk
        sidewalk.strokeColor = .clear
        sidewalk.zPosition = 0
        layer.addChild(sidewalk)

        let curb = SKShapeNode(circleOfRadius: 10.25)
        curb.fillColor = style.palette.curb
        curb.strokeColor = .clear
        curb.zPosition = 1
        layer.addChild(curb)

        let asphalt = SKShapeNode(circleOfRadius: 8.5)
        asphalt.fillColor = style.palette.asphalt
        asphalt.strokeColor = .clear
        asphalt.zPosition = 2
        layer.addChild(asphalt)
    }

    private func addEndCap(onUnconnectedSideOf connectedEdge: RoadConnectionMask, to layer: SKNode) {
        let endpoint = style.edgePoint(for: connectedEdge)
        let capCenter = CGPoint(x: -endpoint.x * 0.28, y: -endpoint.y * 0.28)

        let sidewalk = SKShapeNode(circleOfRadius: 12.5)
        sidewalk.fillColor = style.palette.sidewalk
        sidewalk.strokeColor = .clear
        sidewalk.position = capCenter
        sidewalk.zPosition = 0
        layer.addChild(sidewalk)

        let curb = SKShapeNode(circleOfRadius: 10.25)
        curb.fillColor = style.palette.curb
        curb.strokeColor = .clear
        curb.position = capCenter
        curb.zPosition = 1
        layer.addChild(curb)

        let asphalt = SKShapeNode(circleOfRadius: 8.5)
        asphalt.fillColor = style.palette.asphalt
        asphalt.strokeColor = .clear
        asphalt.position = capCenter
        asphalt.zPosition = 2
        layer.addChild(asphalt)
    }

    private func addStopLine(on edge: RoadConnectionMask, to layer: SKNode) {
        let endpoint = style.edgePoint(for: edge)
        let center = CGPoint(x: endpoint.x * 0.27, y: endpoint.y * 0.27)
        let vector = normalized(endpoint)
        let perpendicular = CGPoint(x: -vector.y, y: vector.x)
        let halfWidth: CGFloat = 5.5
        let path = WorldGeometryCache.line(
            from: CGPoint(x: center.x - perpendicular.x * halfWidth, y: center.y - perpendicular.y * halfWidth),
            to: CGPoint(x: center.x + perpendicular.x * halfWidth, y: center.y + perpendicular.y * halfWidth)
        )
        layer.addChild(stroke(path, color: style.palette.crosswalk, width: 1.5, z: 8, cap: .butt))
    }

    private func addCrosswalk(on edge: RoadConnectionMask, to layer: SKNode) {
        let endpoint = style.edgePoint(for: edge)
        let vector = normalized(endpoint)
        let perpendicular = CGPoint(x: -vector.y, y: vector.x)
        for index in -2...2 {
            let distance = CGFloat(index) * 2.5
            let center = CGPoint(
                x: endpoint.x * 0.54 + vector.x * distance,
                y: endpoint.y * 0.54 + vector.y * distance
            )
            let halfWidth: CGFloat = 4.7
            let path = WorldGeometryCache.line(
                from: CGPoint(x: center.x - perpendicular.x * halfWidth, y: center.y - perpendicular.y * halfWidth),
                to: CGPoint(x: center.x + perpendicular.x * halfWidth, y: center.y + perpendicular.y * halfWidth)
            )
            layer.addChild(stroke(path, color: style.palette.crosswalk, width: 1.2, z: 9, cap: .butt))
        }
    }

    private func addStreetFurniture(
        at coordinate: GridCoordinate,
        topology: RoadTopology,
        reducedMotion: Bool,
        to layer: SKNode
    ) {
        guard topology.classification != .isolated else { return }
        let variant = WorldVisualSeed.variant(count: 8, for: coordinate, kind: .road, salt: 0x51)
        guard variant <= 3 else { return }

        let edge = topology.mask.edges[variant % topology.mask.edges.count]
        let endpoint = style.edgePoint(for: edge, inset: 8)
        let vector = normalized(endpoint)
        let perpendicular = CGPoint(x: -vector.y, y: vector.x)
        let side: CGFloat = variant.isMultiple(of: 2) ? 1 : -1
        let anchor = CGPoint(
            x: endpoint.x * 0.55 + perpendicular.x * 11 * side,
            y: endpoint.y * 0.55 + perpendicular.y * 7 * side
        )

        let post = SKShapeNode(rectOf: CGSize(width: 1.4, height: 8), cornerRadius: 0.5)
        post.fillColor = NSColor(calibratedWhite: 0.23, alpha: 1)
        post.strokeColor = .clear
        post.position = CGPoint(x: anchor.x, y: anchor.y + 4)
        post.zPosition = 12
        let lamp = SKShapeNode(circleOfRadius: 2.2)
        lamp.fillColor = style.palette.warmWindow
        lamp.strokeColor = NSColor.white.withAlphaComponent(0.35)
        lamp.position.y = 4.4
        post.addChild(lamp)
        layer.addChild(post)

        if variant == 0 || variant == 3 {
            let hydrant = SKShapeNode(rectOf: CGSize(width: 3.6, height: 4.2), cornerRadius: 1)
            hydrant.fillColor = NSColor(calibratedRed: 0.78, green: 0.20, blue: 0.13, alpha: 1)
            hydrant.strokeColor = NSColor.white.withAlphaComponent(0.2)
            hydrant.position = CGPoint(x: anchor.x + 5, y: anchor.y - 1)
            hydrant.zPosition = 11
            layer.addChild(hydrant)
        }

        // Traffic remains deliberately static in this milestone. Route-informed
        // movement belongs to the later living-city phase; Reduce Motion therefore
        // never changes semantic road state here.
        _ = reducedMotion
    }

    private func stroke(
        _ path: CGPath,
        color: NSColor,
        width: CGFloat,
        z: CGFloat,
        cap: CGLineCap
    ) -> SKShapeNode {
        let node = SKShapeNode(path: path)
        node.strokeColor = color
        node.fillColor = .clear
        node.lineWidth = width
        node.lineCap = cap
        node.lineJoin = .round
        node.zPosition = z
        return node
    }

    private func normalized(_ point: CGPoint) -> CGPoint {
        let length = max(0.001, hypot(point.x, point.y))
        return CGPoint(x: point.x / length, y: point.y / length)
    }
}

private extension CameraDetailLevel {
    var assetSuffix: String {
        switch self {
        case .city: "city"
        case .neighborhood: "neighborhood"
        case .block: "block"
        }
    }
}
