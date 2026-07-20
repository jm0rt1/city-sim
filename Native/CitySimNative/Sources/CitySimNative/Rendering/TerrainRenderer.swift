import AppKit
import SpriteKit

@MainActor
final class TerrainRenderer {
    private let style: WorldVisualStyle
    private let assets: WorldAssetCatalog

    init(style: WorldVisualStyle, assets: WorldAssetCatalog = .shared) {
        self.style = style
        self.assets = assets
    }

    func makeGround(for tile: CityTile, detail: CameraDetailLevel) -> SKNode {
        let root = SKNode()
        root.name = "terrain.\(tile.kind.rawValue)"

        let cityLayer = style.makeDetailLayer(.city, visibleAt: detail)
        let neighborhoodLayer = style.makeDetailLayer(.neighborhood, visibleAt: detail)
        let blockLayer = style.makeDetailLayer(.block, visibleAt: detail)
        root.addChild(cityLayer)
        root.addChild(neighborhoodLayer)
        root.addChild(blockLayer)

        if let ground = assets.sprite(
            named: groundAssetName(for: tile),
            size: CGSize(width: style.tileWidth, height: style.tileHeight)
        ) {
            ground.zPosition = -4
            cityLayer.addChild(ground)
        } else {
            let ground = SKShapeNode(path: style.diamondPath())
            ground.fillColor = groundColor(for: tile)
            ground.strokeColor = ground.fillColor.blended(withFraction: 0.20, of: .black) ?? .black
            ground.lineWidth = 0.45
            ground.zPosition = -4
            cityLayer.addChild(ground)
        }

        addLotSurface(for: tile, to: cityLayer)
        addStableTerrainBreakup(for: tile, to: neighborhoodLayer)
        addCloseTerrainDetail(for: tile, to: blockLayer)
        return root
    }

    /// Creates the environmental plate behind the grid. Its geometry is already
    /// in world coordinates, so callers add it at `.zero` below tile nodes.
    func makeBackdrop(gridWidth: Int, gridHeight: Int) -> SKNode {
        let root = SKNode()
        root.name = "world.backdrop"
        guard gridWidth > 0, gridHeight > 0 else { return root }

        let corners = mapCorners(gridWidth: gridWidth, gridHeight: gridHeight)
        let path = style.polygonPath(corners)

        let deepShadow = SKShapeNode(path: path)
        deepShadow.fillColor = style.palette.mapEarthDark.withAlphaComponent(0.88)
        deepShadow.strokeColor = .clear
        deepShadow.position = CGPoint(x: 12, y: -24)
        deepShadow.zPosition = -103
        root.addChild(deepShadow)

        let earthPlate = SKShapeNode(path: path)
        earthPlate.fillColor = style.palette.mapEarth
        earthPlate.strokeColor = style.palette.backdropHalo
        earthPlate.lineWidth = 18
        earthPlate.position.y = -8
        earthPlate.zPosition = -102
        root.addChild(earthPlate)

        let rim = SKShapeNode(path: path)
        rim.fillColor = style.palette.mapRim
        rim.strokeColor = NSColor.white.withAlphaComponent(0.13)
        rim.lineWidth = 2.2
        rim.zPosition = -101
        root.addChild(rim)

        let waterShadow = SKShapeNode(ellipseOf: CGSize(
            width: CGFloat(gridWidth + gridHeight) * style.tileWidth * 0.64,
            height: CGFloat(gridWidth + gridHeight) * style.tileHeight * 0.56
        ))
        waterShadow.fillColor = style.palette.backdropHalo.withAlphaComponent(0.18)
        waterShadow.strokeColor = .clear
        waterShadow.position = CGPoint(x: 20, y: -35)
        waterShadow.zPosition = -104
        root.addChild(waterShadow)
        return root
    }

    /// Adds a thin soil skirt and crisp rim only on actual grid boundaries.
    /// Returned geometry is tile-local and can be attached to that tile node.
    func makeMapEdge(
        for coordinate: GridCoordinate,
        gridWidth: Int,
        gridHeight: Int,
        detail: CameraDetailLevel
    ) -> SKNode {
        let root = SKNode()
        root.name = "terrain.edge"
        guard gridWidth > 0, gridHeight > 0 else { return root }

        let blockLayer = style.makeDetailLayer(.block, visibleAt: detail)
        root.addChild(blockLayer)

        let top = CGPoint(x: 0, y: style.tileHeight / 2)
        let right = CGPoint(x: style.tileWidth / 2, y: 0)
        let bottom = CGPoint(x: 0, y: -style.tileHeight / 2)
        let left = CGPoint(x: -style.tileWidth / 2, y: 0)
        let drop: CGFloat = 7

        if coordinate.x == gridWidth - 1 {
            let face = SKShapeNode(path: style.polygonPath([
                right, bottom,
                CGPoint(x: bottom.x, y: bottom.y - drop),
                CGPoint(x: right.x, y: right.y - drop)
            ]))
            face.fillColor = style.palette.mapEarth
            face.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.8)
            face.lineWidth = 0.7
            face.zPosition = -2.8
            root.addChild(face)
        }

        if coordinate.y == gridHeight - 1 {
            let face = SKShapeNode(path: style.polygonPath([
                bottom, left,
                CGPoint(x: left.x, y: left.y - drop),
                CGPoint(x: bottom.x, y: bottom.y - drop)
            ]))
            face.fillColor = style.palette.mapEarth.blended(withFraction: 0.16, of: .black) ?? style.palette.mapEarth
            face.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.8)
            face.lineWidth = 0.7
            face.zPosition = -2.7
            root.addChild(face)
        }

        if coordinate.y == 0 { root.addChild(edgeStroke(from: top, to: right)) }
        if coordinate.x == 0 { root.addChild(edgeStroke(from: left, to: top)) }
        if coordinate.x == gridWidth - 1 { root.addChild(edgeStroke(from: right, to: bottom)) }
        if coordinate.y == gridHeight - 1 { root.addChild(edgeStroke(from: bottom, to: left)) }

        if coordinate.x == gridWidth - 1 || coordinate.y == gridHeight - 1 {
            let pebble = SKShapeNode(ellipseOf: CGSize(width: 4, height: 1.8))
            pebble.fillColor = style.palette.mapEarthDark.withAlphaComponent(0.5)
            pebble.strokeColor = .clear
            pebble.position = CGPoint(x: 4, y: -style.tileHeight / 2 - 3.5)
            pebble.zPosition = -2.5
            blockLayer.addChild(pebble)
        }
        return root
    }

    private func groundColor(for tile: CityTile) -> NSColor {
        let variant = WorldVisualSeed.variant(count: style.palette.grass.count, for: tile.coordinate, kind: tile.kind)
        switch tile.kind {
        case .park:
            return style.palette.parkGrass
        case .residential:
            return style.palette.lotGrass
        case .commercial, .cityHall, .fireStation, .policeStation, .school:
            return style.palette.concrete.blended(withFraction: 0.38, of: style.palette.lotGrass)
                ?? style.palette.lotGrass
        case .industrial, .powerPlant, .waterTower:
            return style.palette.soil.blended(withFraction: 0.30, of: style.palette.lotGrass)
                ?? style.palette.soil
        case .empty, .road:
            return style.palette.grass[variant]
        }
    }

    private func groundAssetName(for tile: CityTile) -> String {
        switch tile.kind {
        case .park:
            "terrain_park"
        case .residential:
            "terrain_lawn"
        case .commercial, .cityHall, .fireStation, .policeStation, .school:
            "terrain_plaza"
        case .industrial, .powerPlant, .waterTower:
            "terrain_yard"
        case .empty, .road:
            "terrain_grass_\(WorldVisualSeed.variant(count: 6, for: tile.coordinate, kind: tile.kind))"
        }
    }

    private func addLotSurface(for tile: CityTile, to layer: SKNode) {
        switch tile.kind {
        case .residential:
            let lawn = SKShapeNode(path: style.diamondPath(width: 59, height: 29))
            lawn.fillColor = style.palette.lotGrass
            lawn.strokeColor = NSColor.white.withAlphaComponent(0.06)
            lawn.lineWidth = 0.8
            lawn.zPosition = -3
            layer.addChild(lawn)
        case .commercial, .cityHall, .fireStation, .policeStation, .school:
            let plaza = SKShapeNode(path: style.diamondPath(width: 62, height: 31))
            plaza.fillColor = style.palette.concrete
            plaza.strokeColor = style.palette.concreteLight.withAlphaComponent(0.45)
            plaza.lineWidth = 1
            plaza.zPosition = -3
            layer.addChild(plaza)
        case .industrial, .powerPlant, .waterTower:
            let yard = SKShapeNode(path: style.diamondPath(width: 63, height: 31.5))
            yard.fillColor = style.palette.soil
            yard.strokeColor = style.palette.concrete.withAlphaComponent(0.6)
            yard.lineWidth = 1
            yard.zPosition = -3
            layer.addChild(yard)
        case .park:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -style.tileWidth * 0.43, y: 3))
            path.addCurve(
                to: CGPoint(x: style.tileWidth * 0.43, y: -2),
                control1: CGPoint(x: -10, y: -10),
                control2: CGPoint(x: 10, y: 10)
            )
            let walk = SKShapeNode(path: path)
            walk.strokeColor = style.palette.parkPath
            walk.lineWidth = 5
            walk.lineCap = .round
            walk.zPosition = -2
            layer.addChild(walk)
        case .empty, .road:
            break
        }
    }

    private func addStableTerrainBreakup(for tile: CityTile, to layer: SKNode) {
        let count: Int
        switch tile.kind {
        case .empty: count = 3
        case .park: count = 2
        case .industrial, .powerPlant, .waterTower: count = 4
        default: count = 1
        }

        for index in 0..<count {
            let salt = UInt64(0x100 + index)
            let x = (WorldVisualSeed.unit(for: tile.coordinate, kind: tile.kind, salt: salt) - 0.5)
                * style.tileWidth * 0.62
            let y = (WorldVisualSeed.unit(for: tile.coordinate, kind: tile.kind, salt: salt + 0x40) - 0.5)
                * style.tileHeight * 0.43
            let detail = SKShapeNode(ellipseOf: CGSize(width: 5.5 + CGFloat(index % 2) * 2, height: 2.1))
            if [.industrial, .powerPlant, .waterTower].contains(tile.kind) {
                detail.fillColor = style.palette.mapEarthDark.withAlphaComponent(0.22)
            } else {
                let xVariant = Int(tile.coordinate.x.magnitude % UInt(style.palette.foliage.count))
                detail.fillColor = style.palette.foliage[(index + xVariant) % style.palette.foliage.count]
                    .withAlphaComponent(0.36)
            }
            detail.strokeColor = .clear
            detail.position = CGPoint(x: x, y: y)
            detail.zPosition = -1.5
            layer.addChild(detail)
        }
    }

    private func addCloseTerrainDetail(for tile: CityTile, to layer: SKNode) {
        guard tile.kind == .empty || tile.kind == .park else {
            if [.industrial, .powerPlant, .waterTower].contains(tile.kind) {
                for index in 0..<3 {
                    let aggregate = SKShapeNode(circleOfRadius: CGFloat(0.8 + Double(index) * 0.25))
                    aggregate.fillColor = style.palette.concreteLight.withAlphaComponent(0.35)
                    aggregate.strokeColor = .clear
                    aggregate.position = CGPoint(x: CGFloat(index * 5 - 5), y: CGFloat(index % 2) * 3 - 5)
                    layer.addChild(aggregate)
                }
            }
            return
        }

        let flowerVariant = WorldVisualSeed.variant(count: 5, for: tile.coordinate, kind: tile.kind, salt: 0xF10)
        guard flowerVariant <= 1 else { return }
        for index in 0..<4 {
            let flower = SKShapeNode(circleOfRadius: 1.1)
            flower.fillColor = index.isMultiple(of: 2)
                ? NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.34, alpha: 0.9)
                : NSColor(calibratedRed: 0.78, green: 0.63, blue: 0.94, alpha: 0.88)
            flower.strokeColor = .clear
            flower.position = CGPoint(x: CGFloat(index * 3 - 5), y: CGFloat(index % 2) * 2 + 2)
            flower.zPosition = 0
            layer.addChild(flower)
        }
    }

    private func edgeStroke(from start: CGPoint, to end: CGPoint) -> SKShapeNode {
        let edge = SKShapeNode(path: WorldGeometryCache.line(from: start, to: end))
        edge.strokeColor = NSColor.white.withAlphaComponent(0.16)
        edge.lineWidth = 1.4
        edge.lineCap = .round
        edge.zPosition = 25
        return edge
    }

    private func mapCorners(gridWidth: Int, gridHeight: Int) -> [CGPoint] {
        let north = style.isoPosition(GridCoordinate(x: 0, y: 0))
        let east = style.isoPosition(GridCoordinate(x: gridWidth - 1, y: 0))
        let south = style.isoPosition(GridCoordinate(x: gridWidth - 1, y: gridHeight - 1))
        let west = style.isoPosition(GridCoordinate(x: 0, y: gridHeight - 1))
        return [
            CGPoint(x: north.x, y: north.y + style.tileHeight / 2),
            CGPoint(x: east.x + style.tileWidth / 2, y: east.y),
            CGPoint(x: south.x, y: south.y - style.tileHeight / 2),
            CGPoint(x: west.x - style.tileWidth / 2, y: west.y)
        ]
    }
}
