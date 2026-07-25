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

        // The macro terrain bed owns visible undeveloped land. Empty and road
        // coordinates resolve through exact inverse-isometric geometry in the
        // scene, so they need no invisible SpriteKit hit allocation here.
        // Avoid building three invisible LOD containers on every undeveloped
        // parcel in a 24 x 24 map.
        guard tile.kind != .empty, tile.kind != .road else { return root }

        let cityLayer = style.makeDetailLayer(.city, visibleAt: detail)
        let neighborhoodLayer = style.makeDetailLayer(.neighborhood, visibleAt: detail)
        let blockLayer = style.makeDetailLayer(.block, visibleAt: detail)
        root.addChild(cityLayer)
        root.addChild(neighborhoodLayer)
        root.addChild(blockLayer)

        addLotSurface(for: tile, to: cityLayer)
        addStableTerrainBreakup(for: tile, to: neighborhoodLayer)
        addCloseTerrainDetail(for: tile, to: blockLayer)
        return root
    }

    /// Creates the environmental plate behind the grid. Its geometry is already
    /// in world coordinates, so callers add it at `.zero` below tile nodes.
    func makeBackdrop(
        gridWidth: Int,
        gridHeight: Int,
        detail: CameraDetailLevel = .block
    ) -> SKNode {
        let root = SKNode()
        root.name = "world.backdrop"
        guard gridWidth > 0, gridHeight > 0 else { return root }

        let corners = mapCorners(gridWidth: gridWidth, gridHeight: gridHeight)
        let path = style.polygonPath(corners)

        let deepShadow = SKShapeNode(path: path)
        deepShadow.name = "terrain.macro.deep-shadow"
        deepShadow.fillColor = style.palette.mapEarthDark.withAlphaComponent(0.88)
        deepShadow.strokeColor = .clear
        deepShadow.position = CGPoint(x: 12, y: -24)
        deepShadow.zPosition = -103
        root.addChild(deepShadow)

        let earthPlate = SKShapeNode(path: path)
        earthPlate.name = "terrain.macro.earth"
        earthPlate.fillColor = style.palette.mapEarth
        earthPlate.strokeColor = style.palette.backdropHalo
        earthPlate.lineWidth = 18
        earthPlate.position.y = -8
        earthPlate.zPosition = -102
        root.addChild(earthPlate)

        // Keep every macro material inside the convex map diamond instead of
        // masking a full-window texture. SKCropNode forces SpriteKit to retain
        // another backing-scale render target. The authored 2:1 field parcels
        // align with the simulation grid, but remain strictly ground material:
        // they never assert a road, frontage, plaza, occupancy, or hit target.
        let field = SKNode()
        field.name = "terrain.macro.field"
        field.zPosition = -101

        let turf = SKShapeNode(path: path)
        turf.name = "terrain.macro.turf"
        turf.fillColor = NSColor(calibratedRed: 0.235, green: 0.405, blue: 0.255, alpha: 1)
        turf.strokeColor = .clear
        field.addChild(turf)

        let cityLayer = style.makeDetailLayer(.city, visibleAt: detail)
        let neighborhoodLayer = style.makeDetailLayer(.neighborhood, visibleAt: detail)
        let blockLayer = style.makeDetailLayer(.block, visibleAt: detail)
        field.addChild(cityLayer)
        field.addChild(neighborhoodLayer)
        field.addChild(blockLayer)

        addContinuousTerrainComposition(
            gridWidth: gridWidth,
            gridHeight: gridHeight,
            city: cityLayer,
            neighborhood: neighborhoodLayer,
            block: blockLayer
        )
        root.addChild(field)

        let rim = SKShapeNode(path: path)
        rim.name = "terrain.macro.rim"
        rim.fillColor = .clear
        rim.strokeColor = NSColor(calibratedRed: 0.47, green: 0.60, blue: 0.36, alpha: 0.72)
        rim.lineWidth = 2.4
        rim.zPosition = -100
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

    private func macroFieldColor(variant: Int) -> NSColor {
        switch variant {
        case 0:
            NSColor(calibratedRed: 0.16, green: 0.31, blue: 0.19, alpha: 0.12)
        case 1:
            NSColor(calibratedRed: 0.48, green: 0.50, blue: 0.24, alpha: 0.08)
        case 2:
            NSColor(calibratedRed: 0.20, green: 0.38, blue: 0.25, alpha: 0.10)
        case 3:
            NSColor(calibratedRed: 0.36, green: 0.42, blue: 0.20, alpha: 0.09)
        default:
            NSColor(calibratedRed: 0.34, green: 0.28, blue: 0.16, alpha: 0.07)
        }
    }

    /// Breaks the board into overlapping, low-contrast material swatches.
    /// Unlike parcel-sized polygons, each swatch has a short irregular contour
    /// with no shared edge, so a continuous diagonal seam cannot be traced
    /// through the aperture. Every mark is ground-only and deterministic.
    private func addContinuousTerrainComposition(
        gridWidth: Int,
        gridHeight: Int,
        city: SKNode,
        neighborhood: SKNode,
        block: SKNode
    ) {
        guard gridWidth >= 5, gridHeight >= 5 else { return }
        let materialSpan = 3
        var materialIndex = 0
        for y in stride(from: 2, to: gridHeight - 1, by: materialSpan) {
            for x in stride(from: 2, to: gridWidth - 1, by: materialSpan) {
                let anchor = GridCoordinate(x: x, y: y)
                let center = style.isoPosition(anchor)
                let radiusX = style.tileWidth * (
                    1.08 + WorldVisualSeed.unit(
                        for: anchor,
                        kind: .empty,
                        salt: 0x7E22
                    ) * 0.42
                )
                let radiusY = style.tileHeight * (
                    0.78 + WorldVisualSeed.unit(
                        for: anchor,
                        kind: .empty,
                        salt: 0x7E23
                    ) * 0.34
                )
                let variant = WorldVisualSeed.variant(
                    count: 5,
                    for: anchor,
                    kind: .empty,
                    salt: 0x7E21
                )
                let material = SKShapeNode(path: organicSwatchPath(
                    center: center,
                    anchor: anchor,
                    radiusX: radiusX,
                    radiusY: radiusY
                ))
                material.name = "terrain.macro.material.patch.\(materialIndex)"
                material.fillColor = macroFieldColor(variant: variant)
                material.strokeColor = .clear
                city.addChild(material)

                if (materialIndex + variant).isMultiple(of: 2) {
                    let meadow = SKShapeNode(path: organicSwatchPath(
                        center: CGPoint(
                            x: center.x + radiusX * 0.08,
                            y: center.y - radiusY * 0.06
                        ),
                        anchor: anchor,
                        radiusX: radiusX * 0.62,
                        radiusY: radiusY * 0.58,
                        saltOffset: 0x20
                    ))
                    meadow.name = "terrain.macro.meadow.patch.\(materialIndex)"
                    meadow.fillColor = NSColor(
                        calibratedRed: 0.54,
                        green: 0.58,
                        blue: 0.29,
                        alpha: 0.055
                    )
                    meadow.strokeColor = .clear
                    neighborhood.addChild(meadow)
                }

                if (materialIndex + variant).isMultiple(of: 3) {
                    addFieldFurrows(
                        minimumX: max(0, x - 1),
                        minimumY: max(0, y - 1),
                        maximumX: min(gridWidth - 1, x + 1),
                        maximumY: min(gridHeight - 1, y + 1),
                        variant: variant,
                        parcelIndex: materialIndex,
                        to: block
                    )
                }
                materialIndex += 1
            }
        }
    }

    private func organicSwatchPath(
        center: CGPoint,
        anchor: GridCoordinate,
        radiusX: CGFloat,
        radiusY: CGFloat,
        saltOffset: UInt64 = 0
    ) -> CGPath {
        let pointCount = 10
        let points = (0..<pointCount).map { index in
            let angle = CGFloat(index) / CGFloat(pointCount) * .pi * 2
            let radialVariation = 0.84 + WorldVisualSeed.unit(
                for: anchor,
                kind: .empty,
                salt: 0x7E30 + saltOffset + UInt64(index)
            ) * 0.22
            return CGPoint(
                x: center.x + cos(angle) * radiusX * radialVariation,
                y: center.y + sin(angle) * radiusY * radialVariation
            )
        }

        let path = CGMutablePath()
        path.move(to: CGPoint(
            x: (points[pointCount - 1].x + points[0].x) / 2,
            y: (points[pointCount - 1].y + points[0].y) / 2
        ))
        for index in 0..<pointCount {
            let current = points[index]
            let next = points[(index + 1) % pointCount]
            path.addQuadCurve(
                to: CGPoint(
                    x: (current.x + next.x) / 2,
                    y: (current.y + next.y) / 2
                ),
                control: current
            )
        }
        path.closeSubpath()
        return path
    }

    private func fieldCorners(
        minimumX: Int,
        minimumY: Int,
        maximumX: Int,
        maximumY: Int
    ) -> [CGPoint] {
        let north = style.isoPosition(GridCoordinate(x: minimumX, y: minimumY))
        let east = style.isoPosition(GridCoordinate(x: maximumX, y: minimumY))
        let south = style.isoPosition(GridCoordinate(x: maximumX, y: maximumY))
        let west = style.isoPosition(GridCoordinate(x: minimumX, y: maximumY))
        return [
            CGPoint(x: north.x, y: north.y + style.tileHeight / 2),
            CGPoint(x: east.x + style.tileWidth / 2, y: east.y),
            CGPoint(x: south.x, y: south.y - style.tileHeight / 2),
            CGPoint(x: west.x - style.tileWidth / 2, y: west.y),
        ]
    }

    private func addFieldFurrows(
        minimumX: Int,
        minimumY: Int,
        maximumX: Int,
        maximumY: Int,
        variant: Int,
        parcelIndex: Int,
        to layer: SKNode
    ) {
        let furrows = SKNode()
        furrows.name = "terrain.macro.furrows.\(parcelIndex)"
        let runsAlongX = variant.isMultiple(of: 2)
        for offset in 1...3 {
            let progress = CGFloat(offset) / 4
            let startCoordinate: GridCoordinate
            let endCoordinate: GridCoordinate
            if runsAlongX {
                let y = minimumY + Int((CGFloat(maximumY - minimumY) * progress).rounded())
                startCoordinate = GridCoordinate(x: minimumX, y: y)
                endCoordinate = GridCoordinate(x: maximumX, y: y)
            } else {
                let x = minimumX + Int((CGFloat(maximumX - minimumX) * progress).rounded())
                startCoordinate = GridCoordinate(x: x, y: minimumY)
                endCoordinate = GridCoordinate(x: x, y: maximumY)
            }
            let start = style.isoPosition(startCoordinate)
            let end = style.isoPosition(endCoordinate)
            let phase = WorldVisualSeed.unit(
                for: GridCoordinate(x: minimumX + offset, y: minimumY + variant),
                kind: .empty,
                salt: 0x7E71 + UInt64(parcelIndex)
            ) * 0.08
            for (segmentIndex, range) in [
                (0.16 + phase, 0.39 + phase),
                (0.61 - phase, 0.82 - phase)
            ].enumerated() {
                let segmentStart = CGPoint(
                    x: start.x + (end.x - start.x) * range.0,
                    y: start.y + (end.y - start.y) * range.0
                )
                let segmentEnd = CGPoint(
                    x: start.x + (end.x - start.x) * range.1,
                    y: start.y + (end.y - start.y) * range.1
                )
                let mark = SKShapeNode(path: WorldGeometryCache.line(
                    from: segmentStart,
                    to: segmentEnd
                ))
                mark.name = "terrain.field-mark.segment.\(offset).\(segmentIndex)"
                mark.fillColor = .clear
                mark.strokeColor = NSColor(
                    calibratedRed: 0.69,
                    green: 0.68,
                    blue: 0.39,
                    alpha: 0.075
                )
                mark.lineWidth = 0.7
                mark.lineCap = .round
                furrows.addChild(mark)
            }
        }
        layer.addChild(furrows)
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
        if tile.constructionProgress >= 1,
           tile.kind != .empty,
           tile.kind != .road {
            return
        }
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
        case .empty, .road: count = 0
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

        let flowerVariant = WorldVisualSeed.variant(count: 37, for: tile.coordinate, kind: tile.kind, salt: 0xF10)
        guard flowerVariant == 0 else { return }
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

    /// Gives undeveloped land authored rhythm without implying buildings,
    /// services, traffic, occupancy, or any other simulation state.
    private func addVacantGrove(for tile: CityTile, to layer: SKNode) {
        guard tile.kind == .empty,
              WorldVisualSeed.variant(
                  count: 8,
                  for: tile.coordinate,
                  kind: tile.kind,
                  salt: 0x6A0E
              ) == 0 else { return }

        let grove = SKNode()
        grove.name = "terrain.vacant.grove"
        let mirror: CGFloat = WorldVisualSeed.variant(
            count: 2,
            for: tile.coordinate,
            kind: tile.kind,
            salt: 0x6A0F
        ) == 0 ? -1 : 1
        grove.position = CGPoint(x: mirror * 11, y: -1)
        grove.zPosition = -0.8

        for index in 0..<2 {
            let x = CGFloat(index * 11 - 5) * mirror
            let trunk = SKShapeNode(rectOf: CGSize(width: 2.2, height: 8), cornerRadius: 0.6)
            trunk.fillColor = style.palette.mapEarthDark.withAlphaComponent(0.84)
            trunk.strokeColor = .clear
            trunk.position = CGPoint(x: x, y: CGFloat(index) * 2)
            grove.addChild(trunk)

            let canopy = SKShapeNode(ellipseOf: CGSize(
                width: 12 + CGFloat(index) * 2,
                height: 9 + CGFloat(index)
            ))
            let colorIndex = (tile.coordinate.x + tile.coordinate.y + index)
                % style.palette.foliage.count
            canopy.fillColor = style.palette.foliage[colorIndex].withAlphaComponent(0.9)
            canopy.strokeColor = NSColor.black.withAlphaComponent(0.16)
            canopy.lineWidth = 0.7
            canopy.position = CGPoint(x: x - 1.5, y: 7 + CGFloat(index) * 2)
            grove.addChild(canopy)
        }

        layer.addChild(grove)
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
