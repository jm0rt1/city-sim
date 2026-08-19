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
        case network
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
    private let fourViewRoadAssets: FourViewRoadAssetCatalog?
    private let developedRoadbed: RoadbedPalette

    init(
        style: WorldVisualStyle,
        assets: WorldAssetCatalog = .shared,
        fourViewRoadAssets: FourViewRoadAssetCatalog? = nil
    ) {
        self.style = style
        self.assets = assets
        self.fourViewRoadAssets = fourViewRoadAssets
        self.developedRoadbed = RoadbedPalette(
            sidewalk: style.palette.sidewalk,
            curb: style.palette.curb,
            asphalt: style.palette.asphalt,
            asphaltLight: style.palette.asphaltLight,
            shadowAlpha: 0.22
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
        let emphasis: ContextEmphasis = distance <= 1 ? .developed : .network
        // Every authoritative road is physical infrastructure. Distance may
        // control sparse furniture, but never turns pavement into a translucent
        // green placement-preview language.
        let detailAlpha: CGFloat = 1
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
        // Every road tile must resolve onto one global material plane. Leaving
        // coordinate depth on these overlapping socket sprites lets a later
        // tile's sidewalk paint across an earlier tile's asphalt, exposing the
        // individual atlas plates instead of one continuous corridor.
        root.zPosition = -style.depth(for: coordinate)

        let cityLayer = style.makeDetailLayer(.city, visibleAt: detail)
        let neighborhoodLayer = style.makeDetailLayer(.neighborhood, visibleAt: detail)
        let blockLayer = style.makeDetailLayer(.block, visibleAt: detail)
        root.addChild(cityLayer)
        root.addChild(neighborhoodLayer)
        root.addChild(blockLayer)

        let fourViewRoad = fourViewRoadAssets?.makeSprite(
            connectionMask: connections.rawValue,
            worldTileWidth: style.tileWidth
        )
        if fourViewRoad == nil, fourViewRoadAssets == nil {
            addDistrictFabricHierarchy(
                for: topology,
                emphasis: emphasis,
                to: cityLayer
            )
        }

        let corridor = SKNode()
        corridor.name = "road.production-corridor.\(emphasis.rawValue).\(connections.rawValue)"
        if let authoredRoad = fourViewRoad {
            authoredRoad.name = "road.generated-v4.\(connections.rawValue).\(detail.assetSuffix)"
            authoredRoad.color = .clear
            authoredRoad.colorBlendFactor = 0
            authoredRoad.alpha = 1
            corridor.addChild(authoredRoad)
        } else if fourViewRoadAssets == nil, let authoredRoad = assets.generatedRoadSprite(
            connectionMask: connections.rawValue,
            detail: detail
        ) {
            authoredRoad.name = "road.generated-v4.\(connections.rawValue).\(detail.assetSuffix)"
            // Keep the accepted lane, crossing, wear, drainage, curb, and
            // sidewalk pixels intact. A bounded whole-sprite value lift keeps
            // the asphalt from becoming the scene's blackest mass without
            // covering it with a procedural ribbon.
            authoredRoad.color = style.palette.asphaltLight
            authoredRoad.colorBlendFactor = emphasis == .developed ? 0.16 : 0.18
            authoredRoad.alpha = 1
            corridor.addChild(authoredRoad)
        } else {
            let missing = SKNode()
            missing.name = String(
                format: "road.four-view.missing.mask-%02d",
                connections.rawValue
            )
            corridor.addChild(missing)
        }
        if fourViewRoad == nil, fourViewRoadAssets == nil {
            addSocketSeamBlends(for: topology, to: corridor)
            if topology.classification == .end, let connectedEdge = topology.mask.edges.first {
                addAuthoredTerminus(
                    onUnconnectedSideOf: connectedEdge,
                    to: corridor
                )
            }
        }
        cityLayer.addChild(corridor)
        if fourViewRoad == nil, fourViewRoadAssets == nil,
           detailAlpha > 0, detail == .block {
            addStreetFurniture(
                at: coordinate,
                topology: topology,
                emphasis: emphasis,
                reducedMotion: reducedMotion,
                to: blockLayer
            )
        }
        return root
    }

    private func addDistrictFabricHierarchy(
        for topology: RoadTopology,
        emphasis: ContextEmphasis,
        to layer: SKNode
    ) {
        let fabric = SKNode()
        fabric.name = "road.fabric.hierarchy.\(topology.mask.rawValue)"
        fabric.zPosition = -2

        if topology.classification == .isolated {
            let shadow = SKShapeNode(path: style.diamondPath(width: 54, height: 27))
            shadow.name = "road.fabric.shadow"
            shadow.fillColor = NSColor.black.withAlphaComponent(0.13)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 1.2, y: -1.4)
            fabric.addChild(shadow)

            let sidewalk = SKShapeNode(path: style.diamondPath(width: 51, height: 25.5))
            sidewalk.name = "road.fabric.sidewalk"
            sidewalk.fillColor = developedRoadbed.sidewalk.withAlphaComponent(0.38)
            sidewalk.strokeColor = developedRoadbed.curb.withAlphaComponent(0.42)
            sidewalk.lineWidth = 1.0
            fabric.addChild(sidewalk)

            let surface = SKShapeNode(path: style.diamondPath(width: 39.5, height: 19.75))
            surface.name = "road.fabric.surface"
            surface.fillColor = developedRoadbed.asphalt.withAlphaComponent(0.22)
            surface.strokeColor = .clear
            fabric.addChild(surface)
            layer.addChild(fabric)
            return
        }

        let segments = topology.mask.edges.map { edge -> CGPath in
            let endpoint = style.roadSocket(for: edge, overreach: 1.25)
            let start = topology.classification == .end
                ? CGPoint(x: -endpoint.x * 0.30, y: -endpoint.y * 0.30)
                : .zero
            return WorldGeometryCache.line(from: start, to: endpoint)
        }
        let combined = CGMutablePath()
        segments.forEach { combined.addPath($0) }

        var shadowTransform = CGAffineTransform(translationX: 1.1, y: -1.35)
        let shadowPath = combined.copy(using: &shadowTransform) ?? combined
        fabric.addChild(fabricStroke(
            shadowPath,
            name: "road.fabric.shadow",
            color: NSColor.black.withAlphaComponent(0.14),
            width: 30,
            z: -1
        ))
        fabric.addChild(fabricStroke(
            combined,
            name: "road.fabric.sidewalk",
            color: developedRoadbed.sidewalk.withAlphaComponent(
                emphasis == .developed ? 0.48 : 0.34
            ),
            width: 28,
            z: 0
        ))
        fabric.addChild(fabricStroke(
            combined,
            name: "road.fabric.curb",
            color: developedRoadbed.curb.withAlphaComponent(0.52),
            width: 23,
            z: 1
        ))
        fabric.addChild(fabricStroke(
            combined,
            name: "road.fabric.surface",
            color: developedRoadbed.asphalt.withAlphaComponent(0.22),
            width: 19,
            z: 2
        ))
        layer.addChild(fabric)
    }

    private func fabricStroke(
        _ path: CGPath,
        name: String,
        color: NSColor,
        width: CGFloat,
        z: CGFloat
    ) -> SKShapeNode {
        let node = SKShapeNode(path: path)
        node.name = name
        node.fillColor = .clear
        node.strokeColor = color
        node.lineWidth = width
        node.lineCap = .butt
        node.lineJoin = .round
        node.zPosition = z
        return node
    }

    private func addSocketSeamBlends(
        for topology: RoadTopology,
        to node: SKNode
    ) {
        guard !topology.mask.isEmpty else { return }
        let paths = CGMutablePath()
        for edge in topology.mask.edges {
            let socket = style.roadSocket(for: edge)
            let length = max(0.001, hypot(socket.x, socket.y))
            let perpendicular = CGPoint(
                x: -socket.y / length,
                y: socket.x / length
            )
            paths.addPath(WorldGeometryCache.line(
                from: CGPoint(
                    x: socket.x - perpendicular.x * 10,
                    y: socket.y - perpendicular.y * 10
                ),
                to: CGPoint(
                    x: socket.x + perpendicular.x * 10,
                    y: socket.y + perpendicular.y * 10
                )
            ))
        }
        let seam = SKShapeNode(path: paths)
        seam.name = "road.socket-seam-blend.\(topology.mask.rawValue)"
        seam.strokeColor = style.palette.asphaltLight.withAlphaComponent(0.20)
        seam.lineWidth = 1.2
        seam.lineCap = .butt
        seam.zPosition = 2.3
        node.addChild(seam)
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
        // Authoritative roads stay opaque and connected for truthful planning
        // and hit testing. Avoid per-tile alpha, which double-darkens
        // overlapping sockets.
        let palette = developedRoadbed
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
        let combinedSegments = CGMutablePath()
        for path in segments {
            combinedSegments.addPath(path)
        }

        // Draw material passes rather than complete branches. This prevents a
        // later branch's sidewalk from cutting a pale ring through prior asphalt.
        // A material pass is one drawable even when the topology has several
        // sockets. The disjoint subpaths retain exact socket geometry while
        // avoiding five duplicate SpriteKit allocations per extra branch.
        var shadowTransform = CGAffineTransform(translationX: 1.2, y: -1.5)
        let shadow = combinedSegments.copy(using: &shadowTransform) ?? combinedSegments
        layer.addChild(stroke(shadow, color: NSColor.black.withAlphaComponent(shadowAlpha), width: 29, z: -1, cap: .butt))
        layer.addChild(stroke(combinedSegments, color: sidewalkColor, width: 27, z: 0, cap: .butt))
        layer.addChild(stroke(combinedSegments, color: curbColor, width: 22, z: 1, cap: .butt))
        layer.addChild(stroke(combinedSegments, color: asphaltColor, width: 18, z: 2, cap: .butt))
        layer.addChild(stroke(
            combinedSegments,
            color: asphaltLightColor.withAlphaComponent(0.28),
            width: 0.8,
            z: 3,
            cap: .butt
        ))

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

    private func addAuthoredTerminus(
        onUnconnectedSideOf connectedEdge: RoadConnectionMask,
        to layer: SKNode
    ) {
        // A single connected edge is a real paved turning head wholly contained
        // by the authoritative road cell. It never paints a continuation,
        // frontage, plaza, or occupancy cue onto the neighboring empty cell.
        let connectedSocket = style.roadSocket(for: connectedEdge)
        let center = CGPoint(
            x: -connectedSocket.x * 0.30,
            y: -connectedSocket.y * 0.30
        )

        let shadow = SKShapeNode(path: style.diamondPath(width: 21, height: 10.5))
        shadow.name = "road.terminus.paved-shadow"
        shadow.fillColor = NSColor.black.withAlphaComponent(0.20)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: center.x + 1.2, y: center.y - 1.2)
        shadow.zPosition = 4
        layer.addChild(shadow)

        let apron = SKShapeNode(path: style.diamondPath(width: 19, height: 9.5))
        apron.name = "road.terminus.paved-apron"
        apron.fillColor = style.palette.asphalt
        apron.strokeColor = style.palette.curb.withAlphaComponent(0.95)
        apron.lineWidth = 1.2
        apron.position = center
        apron.zPosition = 5
        layer.addChild(apron)

        let socketVector = normalized(connectedSocket)
        let perpendicular = CGPoint(x: -socketVector.y, y: socketVector.x)
        let barrierPath = WorldGeometryCache.line(
            from: CGPoint(
                x: center.x - perpendicular.x * 6,
                y: center.y - perpendicular.y * 3
            ),
            to: CGPoint(
                x: center.x + perpendicular.x * 6,
                y: center.y + perpendicular.y * 3
            )
        )
        let barrier = SKShapeNode(path: barrierPath)
        barrier.name = "road.terminus.authenticated-barrier"
        barrier.fillColor = .clear
        barrier.strokeColor = style.palette.crosswalk.withAlphaComponent(0.90)
        barrier.lineWidth = 1.6
        barrier.lineCap = .butt
        barrier.position = CGPoint(
            x: -socketVector.x * 1.4,
            y: -socketVector.y * 0.7
        )
        barrier.zPosition = 6
        layer.addChild(barrier)

        for side: CGFloat in [-1, 1] {
            let bollard = SKShapeNode(rectOf: CGSize(width: 1.8, height: 5.2), cornerRadius: 0.4)
            bollard.name = "road.terminus.authenticated-bollard"
            bollard.fillColor = style.palette.curb
            bollard.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.55)
            bollard.lineWidth = 0.4
            bollard.position = CGPoint(
                x: center.x + perpendicular.x * 7 * side,
                y: center.y + perpendicular.y * 3.5 * side + 2
            )
            bollard.zPosition = 7
            layer.addChild(bollard)
        }
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
        emphasis: ContextEmphasis,
        reducedMotion: Bool,
        to layer: SKNode
    ) {
        guard topology.classification != .isolated else { return }
        let variant = WorldVisualSeed.variant(
            count: emphasis == .developed ? 4 : 10,
            for: coordinate,
            kind: .road,
            salt: 0x51
        )
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

        let fixturePath = CGMutablePath()
        fixturePath.addRect(CGRect(x: -0.55, y: 0, width: 1.1, height: 8))
        fixturePath.addPath(WorldGeometryCache.polygon([
            CGPoint(x: -2.4, y: 8),
            CGPoint(x: -1.1, y: 9.5),
            CGPoint(x: 1.9, y: 9.1),
            CGPoint(x: 2.5, y: 7.7),
            CGPoint(x: 0.8, y: 7.0),
            CGPoint(x: -1.7, y: 7.1),
        ]))
        let fixture = SKShapeNode(path: fixturePath)
        fixture.name = "road.public-realm.lamp"
        fixture.fillColor = style.palette.roofDark
        fixture.strokeColor = style.palette.concreteLight.withAlphaComponent(0.12)
        fixture.lineWidth = 0.35
        fixture.position = anchor
        fixture.zPosition = 12
        let glow = SKShapeNode(path: style.diamondPath(width: 2.7, height: 1.3))
        glow.name = "road.public-realm.lamp.warm-light"
        glow.fillColor = style.palette.warmWindow.withAlphaComponent(0.80)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0.25, y: 7.8)
        fixture.addChild(glow)
        layer.addChild(fixture)

        let hydrantPath = CGMutablePath()
        hydrantPath.addPath(WorldGeometryCache.polygon([
            CGPoint(x: -1.6, y: -2),
            CGPoint(x: 1.6, y: -2),
            CGPoint(x: 1.4, y: 1.5),
            CGPoint(x: -1.4, y: 1.5),
        ]))
        hydrantPath.addPath(WorldGeometryCache.polygon([
            CGPoint(x: -2.1, y: 1.4),
            CGPoint(x: -1.0, y: 2.6),
            CGPoint(x: 1.0, y: 2.6),
            CGPoint(x: 2.1, y: 1.4),
        ]))
        let hydrant = SKShapeNode(path: hydrantPath)
        hydrant.name = "road.public-realm.hydrant"
        hydrant.fillColor = NSColor(calibratedRed: 0.48, green: 0.20, blue: 0.15, alpha: 1)
        hydrant.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.62)
        hydrant.lineWidth = 0.45
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
