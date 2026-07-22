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
    private enum ContextEmphasis: String {
        case developed
        case opportunity
    }

    private struct RoadbedPalette {
        let sidewalk: NSColor
        let curb: NSColor
        let asphalt: NSColor
        let asphaltLight: NSColor
        let shadowAlpha: CGFloat
    }

    private let style: WorldVisualStyle
    private let assets: WorldAssetCatalog
    private let developedRoadbed: RoadbedPalette
    private let opportunityRoadbed: RoadbedPalette

    init(style: WorldVisualStyle, assets: WorldAssetCatalog = .shared) {
        self.style = style
        self.assets = assets
        self.developedRoadbed = RoadbedPalette(
            sidewalk: style.palette.sidewalk,
            curb: style.palette.curb,
            asphalt: style.palette.asphalt,
            asphaltLight: style.palette.asphaltLight,
            shadowAlpha: 0.22
        )
        let turf = NSColor(calibratedRed: 0.235, green: 0.405, blue: 0.255, alpha: 1)
        self.opportunityRoadbed = RoadbedPalette(
            sidewalk: style.palette.sidewalk.blended(withFraction: 0.62, of: turf)
                ?? style.palette.sidewalk,
            curb: style.palette.curb.blended(withFraction: 0.68, of: turf)
                ?? style.palette.curb,
            asphalt: style.palette.asphalt.blended(withFraction: 0.48, of: turf)
                ?? style.palette.asphalt,
            asphaltLight: style.palette.asphaltLight.blended(withFraction: 0.52, of: turf)
                ?? style.palette.asphaltLight,
            shadowAlpha: 0.10
        )
    }

    func makeRoad(
        at coordinate: GridCoordinate,
        in state: CityGameState,
        detail: CameraDetailLevel,
        reducedMotion: Bool,
        developedCoordinates: [GridCoordinate]? = nil
    ) -> SKNode {
        let contextCoordinates = developedCoordinates ?? state.tiles.compactMap { tile in
            tile.kind != .empty && tile.kind != .road ? tile.coordinate : nil
        }
        return makeRoad(
            at: coordinate,
            connections: RoadConnectionMask.resolving(at: coordinate, in: state),
            detail: detail,
            reducedMotion: reducedMotion,
            developedCoordinates: contextCoordinates
        )
    }

    func makeRoad(
        at coordinate: GridCoordinate,
        connections: RoadConnectionMask,
        detail: CameraDetailLevel,
        reducedMotion: Bool,
        developedCoordinates: [GridCoordinate]
    ) -> SKNode {
        let distance = contextDistance(at: coordinate, developedCoordinates: developedCoordinates)
        let emphasis: ContextEmphasis = distance <= 1 ? .developed : .opportunity
        let detailAlpha: CGFloat = switch distance {
        case ...1: 1
        case 2: 0.25
        default: 0
        }
        let road = makeRoadNode(
            at: coordinate,
            connections: connections,
            detail: detail,
            reducedMotion: reducedMotion,
            emphasis: emphasis,
            detailAlpha: detailAlpha
        )
        road.childNode(withName: CameraDetailLevel.neighborhood.layerName)?.alpha = detailAlpha
        road.childNode(withName: CameraDetailLevel.block.layerName)?.alpha = detailAlpha
        return road
    }

    func makeRoad(
        at coordinate: GridCoordinate,
        connections: RoadConnectionMask,
        detail: CameraDetailLevel,
        reducedMotion: Bool
    ) -> SKNode {
        makeRoadNode(
            at: coordinate,
            connections: connections,
            detail: detail,
            reducedMotion: reducedMotion,
            emphasis: .developed,
            detailAlpha: 1
        )
    }

    private func makeRoadNode(
        at coordinate: GridCoordinate,
        connections: RoadConnectionMask,
        detail: CameraDetailLevel,
        reducedMotion: Bool,
        emphasis: ContextEmphasis,
        detailAlpha: CGFloat
    ) -> SKNode {
        let topology = RoadTopology(mask: connections)
        let root = SKNode()
        root.name = "road.\(topology.classification.rawValue).\(connections.rawValue)"
        // Cancel per-tile depth so every corridor material pass sorts as one
        // network. Otherwise a deeper neighbor's shadow is painted over the
        // prior tile's asphalt and exposes a dark seam at every socket.
        root.zPosition = -style.depth(for: coordinate)

        let cityLayer = style.makeDetailLayer(.city, visibleAt: detail)
        let neighborhoodLayer = style.makeDetailLayer(.neighborhood, visibleAt: detail)
        let blockLayer = style.makeDetailLayer(.block, visibleAt: detail)
        root.addChild(cityLayer)
        root.addChild(neighborhoodLayer)
        root.addChild(blockLayer)

        let corridor = SKNode()
        corridor.name = "road.production-corridor.\(emphasis.rawValue).\(connections.rawValue)"
        addRoadbed(for: topology, emphasis: emphasis, to: corridor)
        cityLayer.addChild(corridor)
        if detailAlpha > 0 {
            addLaneLanguage(for: topology, to: neighborhoodLayer)
            addMaterialDetail(at: coordinate, topology: topology, to: blockLayer)
            addStreetFurniture(
                at: coordinate,
                topology: topology,
                reducedMotion: reducedMotion,
                to: blockLayer
            )
        }
        return root
    }

    private func contextDistance(
        at coordinate: GridCoordinate,
        developedCoordinates: [GridCoordinate]
    ) -> Int {
        developedCoordinates.map { developed in
            max(
                abs(developed.x - coordinate.x),
                abs(developed.y - coordinate.y)
            )
        }.min() ?? .max
    }

    private func addRoadbed(
        for topology: RoadTopology,
        emphasis: ContextEmphasis,
        to layer: SKNode
    ) {
        // Opportunity roads stay opaque and connected for truthful planning
        // and hit testing, but recede toward the macro terrain value. Avoid
        // per-tile alpha, which double-darkens overlapping sockets.
        let palette = emphasis == .developed ? developedRoadbed : opportunityRoadbed
        let sidewalkColor = palette.sidewalk
        let curbColor = palette.curb
        let asphaltColor = palette.asphalt
        let asphaltLightColor = palette.asphaltLight
        let shadowAlpha = palette.shadowAlpha
        if topology.classification == .isolated {
            let shadow = SKShapeNode(path: style.diamondPath(width: 54, height: 27))
            shadow.name = "road.isolated.ground-shadow"
            shadow.fillColor = NSColor.black.withAlphaComponent(shadowAlpha)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 1.5, y: -2)
            shadow.zPosition = -1
            layer.addChild(shadow)

            let sidewalk = SKShapeNode(path: style.diamondPath(width: 52, height: 26))
            sidewalk.name = "road.isolated.sidewalk"
            sidewalk.fillColor = sidewalkColor
            sidewalk.strokeColor = curbColor
            sidewalk.lineWidth = 2
            sidewalk.zPosition = 0
            layer.addChild(sidewalk)

            let asphalt = SKShapeNode(path: style.diamondPath(width: 39, height: 19.5))
            asphalt.name = "road.isolated.turnaround"
            asphalt.fillColor = asphaltColor
            asphalt.strokeColor = asphaltLightColor
            asphalt.lineWidth = 1
            asphalt.zPosition = 1
            layer.addChild(asphalt)
            return
        }

        let segments = topology.mask.edges.map { edge -> CGPath in
            let endpoint = style.roadSocket(for: edge, overreach: 1.25)
            let start = topology.classification == .end
                ? CGPoint(x: -endpoint.x * 0.30, y: -endpoint.y * 0.30)
                : .zero
            return WorldGeometryCache.line(from: start, to: endpoint)
        }

        // Draw material passes rather than complete branches. This prevents a
        // later branch's sidewalk from cutting a pale ring through prior asphalt.
        for path in segments {
            var shadowTransform = CGAffineTransform(translationX: 1.2, y: -1.5)
            let shadow = path.copy(using: &shadowTransform) ?? path
            layer.addChild(stroke(shadow, color: NSColor.black.withAlphaComponent(shadowAlpha), width: 29, z: -1, cap: .butt))
        }
        for path in segments {
            layer.addChild(stroke(path, color: sidewalkColor, width: 27, z: 0, cap: .butt))
        }
        for path in segments {
            layer.addChild(stroke(path, color: curbColor, width: 22, z: 1, cap: .butt))
        }
        for path in segments {
            layer.addChild(stroke(path, color: asphaltColor, width: 18, z: 2, cap: .butt))
            layer.addChild(stroke(path, color: asphaltLightColor.withAlphaComponent(0.28), width: 0.8, z: 3, cap: .butt))
        }

        addLayeredJunction(
            to: layer,
            shadowAlpha: shadowAlpha,
            sidewalkColor: sidewalkColor,
            curbColor: curbColor,
            asphaltColor: asphaltColor
        )

        if topology.classification == .end, let edge = topology.mask.edges.first {
            addEndCap(
                onUnconnectedSideOf: edge,
                sidewalkColor: sidewalkColor,
                curbColor: curbColor,
                asphaltColor: asphaltColor,
                markColor: emphasis == .developed
                    ? style.palette.laneMark.withAlphaComponent(0.78)
                    : asphaltLightColor,
                to: layer
            )
        }
    }

    private func addLaneLanguage(for topology: RoadTopology, to layer: SKNode) {
        for edge in topology.mask.edges {
            let endpoint = style.roadSocket(for: edge, overreach: 0.75)
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

    }

    private func addMaterialDetail(
        at coordinate: GridCoordinate,
        topology: RoadTopology,
        to layer: SKNode
    ) {
        guard topology.classification != .isolated else { return }
        guard WorldVisualSeed.variant(count: 4, for: coordinate, kind: .road, salt: 0xD2A1) == 0,
              let edge = topology.mask.edges.first else { return }
        let endpoint = style.roadSocket(for: edge, overreach: -2)
        let drain = SKShapeNode(rectOf: CGSize(width: 5.5, height: 2.2), cornerRadius: 0.4)
        drain.name = "road.material.drain"
        drain.fillColor = NSColor(calibratedWhite: 0.12, alpha: 0.92)
        drain.strokeColor = style.palette.curb.withAlphaComponent(0.55)
        drain.lineWidth = 0.5
        drain.position = CGPoint(x: endpoint.x * 0.72, y: endpoint.y * 0.72)
        drain.zPosition = 7
        layer.addChild(drain)
    }

    private func addLayeredJunction(
        to layer: SKNode,
        shadowAlpha: CGFloat,
        sidewalkColor: NSColor,
        curbColor: NSColor,
        asphaltColor: NSColor
    ) {
        let shadow = SKShapeNode(circleOfRadius: 14.5)
        shadow.fillColor = NSColor.black.withAlphaComponent(shadowAlpha)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 1.2, y: -1.5)
        shadow.zPosition = -1
        layer.addChild(shadow)

        let sidewalk = SKShapeNode(circleOfRadius: 13.5)
        sidewalk.fillColor = sidewalkColor
        sidewalk.strokeColor = .clear
        sidewalk.zPosition = 0
        layer.addChild(sidewalk)

        let curb = SKShapeNode(circleOfRadius: 11)
        curb.fillColor = curbColor
        curb.strokeColor = .clear
        curb.zPosition = 1
        layer.addChild(curb)

        let asphalt = SKShapeNode(circleOfRadius: 9)
        asphalt.fillColor = asphaltColor
        asphalt.strokeColor = .clear
        asphalt.zPosition = 2
        layer.addChild(asphalt)
    }

    private func addEndCap(
        onUnconnectedSideOf connectedEdge: RoadConnectionMask,
        sidewalkColor: NSColor,
        curbColor: NSColor,
        asphaltColor: NSColor,
        markColor: NSColor,
        to layer: SKNode
    ) {
        let endpoint = style.roadSocket(for: connectedEdge)
        let capCenter = CGPoint(x: -endpoint.x * 0.28, y: -endpoint.y * 0.28)

        let sidewalk = SKShapeNode(circleOfRadius: 13.5)
        sidewalk.name = "road.terminus.intentional-sidewalk"
        sidewalk.fillColor = sidewalkColor
        sidewalk.strokeColor = .clear
        sidewalk.position = capCenter
        sidewalk.zPosition = 0
        layer.addChild(sidewalk)

        let curb = SKShapeNode(circleOfRadius: 11)
        curb.fillColor = curbColor
        curb.strokeColor = .clear
        curb.position = capCenter
        curb.zPosition = 1
        layer.addChild(curb)

        let asphalt = SKShapeNode(circleOfRadius: 9)
        asphalt.name = "road.terminus.turning-bulb"
        asphalt.fillColor = asphaltColor
        asphalt.strokeColor = .clear
        asphalt.position = capCenter
        asphalt.zPosition = 2
        layer.addChild(asphalt)

        let centerMark = SKShapeNode(path: style.diamondPath(width: 5.5, height: 2.8))
        centerMark.name = "road.terminus.center-mark"
        centerMark.fillColor = markColor
        centerMark.strokeColor = .clear
        centerMark.position = capCenter
        centerMark.zPosition = 4
        layer.addChild(centerMark)
    }

    private func addStopLine(on edge: RoadConnectionMask, to layer: SKNode) {
        let endpoint = style.roadSocket(for: edge)
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
        let endpoint = style.roadSocket(for: edge)
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
        let variant = WorldVisualSeed.variant(count: 12, for: coordinate, kind: .road, salt: 0x51)
        guard variant == 0 else { return }

        let edge = topology.mask.edges[variant % topology.mask.edges.count]
        let endpoint = style.roadSocket(for: edge, overreach: -2)
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

        let hydrant = SKShapeNode(rectOf: CGSize(width: 3.6, height: 4.2), cornerRadius: 1)
        hydrant.fillColor = NSColor(calibratedRed: 0.62, green: 0.25, blue: 0.18, alpha: 1)
        hydrant.strokeColor = NSColor.white.withAlphaComponent(0.16)
        hydrant.position = CGPoint(x: anchor.x + 5, y: anchor.y - 1)
        hydrant.zPosition = 11
        layer.addChild(hydrant)

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
