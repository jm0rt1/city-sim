import AppKit
import SpriteKit

@MainActor
final class TerrainRenderer {
    private struct BackdropTemplateKey: Hashable {
        let gridWidth: Int
        let gridHeight: Int
        let tileWidthHundredths: Int
        let tileHeightHundredths: Int
    }

    private static var backdropTemplates: [BackdropTemplateKey: SKNode] = [:]
    private static let maximumBackdropTemplateCount = 4

    private struct DevelopedGroundRole: Hashable {
        let x: Int
        let y: Int
        let kind: BuildingKind
        let isComplete: Bool
    }

    private struct DevelopedGroundTemplateKey: Hashable {
        let gridWidth: Int
        let gridHeight: Int
        let roles: [DevelopedGroundRole]
        let tileWidthHundredths: Int
        let tileHeightHundredths: Int
        let usesFourViewGroundEcology: Bool
    }

    private static var developedGroundTemplates: [DevelopedGroundTemplateKey: SKNode] = [:]
    private static let maximumDevelopedGroundTemplateCount = 8

    private let style: WorldVisualStyle
    private let assets: WorldAssetCatalog
    private let groundEcologyAssets: FourViewGroundEcologyCatalog?

    init(
        style: WorldVisualStyle,
        assets: WorldAssetCatalog = .shared,
        groundEcologyAssets: FourViewGroundEcologyCatalog? = nil
    ) {
        self.style = style
        self.assets = assets
        self.groundEcologyAssets = groundEcologyAssets
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

        if tile.constructionProgress >= 1,
           let authoredGround = groundEcologyAssets?.makeGroundSprite(
               for: tile,
               worldTileWidth: style.tileWidth
           ) {
            let assetID = groundEcologyAssets?.groundAssetID(for: tile) ?? "unknown"
            authoredGround.name = "terrain.ground-ecology.\(assetID).\(detail.assetSuffix)"
            authoredGround.color = .clear
            authoredGround.colorBlendFactor = 0
            authoredGround.position = .zero
            cityLayer.addChild(authoredGround)
        } else {
            addLotSurface(for: tile, to: cityLayer)
            addStableTerrainBreakup(for: tile, to: neighborhoodLayer)
            addCloseTerrainDetail(for: tile, to: blockLayer)
        }
        return root
    }

    /// Creates the environmental plate behind the grid. Its geometry is already
    /// in world coordinates, so callers add it at `.zero` below tile nodes.
    func makeBackdrop(
        gridWidth: Int,
        gridHeight: Int,
        detail: CameraDetailLevel = .block
    ) -> SKNode {
        let key = BackdropTemplateKey(
            gridWidth: gridWidth,
            gridHeight: gridHeight,
            tileWidthHundredths: Int((style.tileWidth * 100).rounded()),
            tileHeightHundredths: Int((style.tileHeight * 100).rounded())
        )
        if let prototype = Self.backdropTemplates[key],
           let copy = prototype.copy() as? SKNode {
            style.updateDetailVisibility(in: copy, detail: detail)
            return copy
        }

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
        // The macro bed is vacant ground, not a single connected green
        // screen. Keep it in the established soil/grass material language so
        // the deterministic grass, meadow, furrow, parcel, and public-realm
        // regions read as authored terrain transitions and remain legible as
        // buildable opportunity. A warm soil base also prevents transparent
        // swatches from being mistaken for one uninterrupted green mass.
        turf.fillColor = style.palette.grass[1].blended(
            withFraction: 0.22,
            of: style.palette.soil
        ) ?? style.palette.grass[1]
        turf.strokeColor = .clear
        field.addChild(turf)

        // Build one all-detail immutable prototype per physical grid. Cold
        // scenes then deep-copy the already compiled SpriteKit paths and only
        // update LOD visibility, avoiding repeated macro-terrain construction.
        let cityLayer = style.makeDetailLayer(.city, visibleAt: .block)
        let neighborhoodLayer = style.makeDetailLayer(.neighborhood, visibleAt: .block)
        let blockLayer = style.makeDetailLayer(.block, visibleAt: .block)
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
        rim.strokeColor = style.palette.mapRim.withAlphaComponent(0.72)
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

        if Self.backdropTemplates.count < Self.maximumBackdropTemplateCount,
           let prototype = root.copy() as? SKNode {
            Self.backdropTemplates[key] = prototype
        }
        style.updateDetailVisibility(in: root, detail: detail)
        return root
    }

    static var cachedBackdropTemplateCountForTesting: Int {
        backdropTemplates.count
    }

    /// A state-bound ground plane for the real developed fabric. It joins
    /// completed occupied parcels, their connected authoritative road network,
    /// and road-enclosed vacant commons without painting a new road or occupied
    /// lot. Empty coordinates remain exact inverse-isometric build targets.
    func makeDevelopedDistrictGround(
        in state: CityGameState,
        detail: CameraDetailLevel = .block
    ) -> SKNode {
        let key = DevelopedGroundTemplateKey(
            gridWidth: state.gridWidth,
            gridHeight: state.gridHeight,
            roles: state.tiles.compactMap { tile in
                guard tile.kind != .empty else { return nil }
                return DevelopedGroundRole(
                    x: tile.coordinate.x,
                    y: tile.coordinate.y,
                    kind: tile.kind,
                    isComplete: tile.constructionProgress >= 1
                )
            }.sorted {
                ($0.y, $0.x, $0.kind.rawValue) < ($1.y, $1.x, $1.kind.rawValue)
            },
            tileWidthHundredths: Int((style.tileWidth * 100).rounded()),
            tileHeightHundredths: Int((style.tileHeight * 100).rounded()),
            usesFourViewGroundEcology: groundEcologyAssets?.manifest != nil
        )
        if let prototype = Self.developedGroundTemplates[key],
           let copy = prototype.copy() as? SKNode {
            style.updateDetailVisibility(in: copy, detail: detail)
            return copy
        }

        let root = SKNode()
        root.name = "world.environment.developed-district-ground"
        root.zPosition = -10_000

        let completed = state.tiles.filter {
            $0.kind != .empty && $0.kind != .road && $0.constructionProgress >= 1
        }
        guard !completed.isEmpty else { return root }
        let developedRoads = connectedFrontageRoads(
            in: state,
            completed: completed
        )
        let enclosedBlocks = enclosedDistrictBlocks(in: state)

        let cityLayer = style.makeDetailLayer(.city, visibleAt: .block)
        let neighborhoodLayer = style.makeDetailLayer(.neighborhood, visibleAt: .block)
        let blockLayer = style.makeDetailLayer(.block, visibleAt: .block)
        root.addChild(cityLayer)
        root.addChild(neighborhoodLayer)
        root.addChild(blockLayer)

        // The authored fabric is a renderer-only ground envelope. It joins
        // existing occupied parcels and authoritative roads without changing
        // tile kinds, buildability, or hit geometry. The separate expansion
        // band keeps the next truthful buildable context visible instead of
        // letting the district become a crop-only composition.
        let fabricCoordinates = completed.map(\.coordinate) + developedRoads.map(\.coordinate)
        let fabricEnvelope = SKShapeNode(path: combinedDiamondPath(
            coordinates: fabricCoordinates,
            width: style.tileWidth + 2.4,
            height: style.tileHeight + 1.2,
            offset: CGPoint(x: 0.4, y: -0.25)
        ))
        fabricEnvelope.name = "district.fabric.authored-envelope"
        fabricEnvelope.fillColor = style.palette.lotGrass.blended(
            withFraction: 0.40,
            of: style.palette.sidewalk
        )?.withAlphaComponent(0.48) ?? style.palette.lotGrass.withAlphaComponent(0.48)
        fabricEnvelope.strokeColor = style.palette.concreteLight.withAlphaComponent(0.18)
        fabricEnvelope.lineWidth = 0.9
        fabricEnvelope.zPosition = 0.2
        cityLayer.addChild(fabricEnvelope)

        let expansionCoordinates = expansionBandCoordinates(
            in: state,
            around: fabricCoordinates
        )
        if !expansionCoordinates.isEmpty {
            let expansion = SKShapeNode(path: combinedDiamondPath(
                coordinates: expansionCoordinates,
                width: style.tileWidth - 2.4,
                height: style.tileHeight - 1.2,
                offset: CGPoint(x: 0.2, y: -0.15)
            ))
            expansion.name = "district.fabric.expansion-band"
            expansion.fillColor = style.palette.lotGrass.withAlphaComponent(0.24)
            expansion.strokeColor = style.palette.concreteLight.withAlphaComponent(0.22)
            expansion.lineWidth = 0.7
            expansion.zPosition = 0.15
            cityLayer.addChild(expansion)

            addFourViewExpansionGround(
                coordinates: expansionCoordinates,
                detail: detail,
                to: cityLayer
            )
        }

        let publicEnvelope = SKShapeNode(path: combinedDiamondPath(
            coordinates: developedRoads.map(\.coordinate),
            width: style.tileWidth + 4.5,
            height: style.tileHeight + 2.25
        ))
        publicEnvelope.name = "district.fabric.public-realm-envelope"
        publicEnvelope.fillColor = style.palette.sidewalk.blended(
            withFraction: 0.24,
            of: style.palette.lotGrass
        )?.withAlphaComponent(0.60) ?? style.palette.sidewalk.withAlphaComponent(0.60)
        publicEnvelope.strokeColor = style.palette.curb.withAlphaComponent(0.36)
        publicEnvelope.lineWidth = 1.1
        publicEnvelope.zPosition = 0.35
        neighborhoodLayer.addChild(publicEnvelope)

        let sharedCoordinates = completed.map(\.coordinate) + developedRoads.map(\.coordinate)
        let shadowPath = combinedDiamondPath(
            coordinates: sharedCoordinates,
            width: style.tileWidth - 0.5,
            height: style.tileHeight - 0.25,
            offset: CGPoint(x: 1.6, y: -1.4)
        )
        let shadow = SKShapeNode(path: shadowPath)
        shadow.name = "district.ground.shared-contact"
        shadow.fillColor = NSColor.black.withAlphaComponent(0.11)
        shadow.strokeColor = .clear
        root.addChild(shadow)

        let roadPath = combinedDiamondPath(
            coordinates: developedRoads.map(\.coordinate),
            width: style.tileWidth + 1.5,
            height: style.tileHeight + 0.75
        )
        let publicRealm = SKShapeNode(path: roadPath)
        publicRealm.name = "district.ground.authoritative-public-realm"
        publicRealm.fillColor = style.palette.sidewalk.blended(
            withFraction: 0.36,
            of: style.palette.lotGrass
        )?.withAlphaComponent(0.90) ?? style.palette.sidewalk.withAlphaComponent(0.90)
        publicRealm.strokeColor = .clear
        publicRealm.zPosition = 1
        root.addChild(publicRealm)

        let structuralKinds = Set(completed.map(\.kind)).subtracting([
            .park, .powerPlant, .waterTower,
        ])
        let frontageShadow = SKShapeNode(path: frontageLinkPath(
            completed: completed,
            in: state,
            kinds: structuralKinds,
            offset: CGPoint(x: 1.2, y: -1.1)
        ))
        frontageShadow.name = "district.ground.frontage-links.contact"
        frontageShadow.strokeColor = NSColor.black.withAlphaComponent(0.16)
        frontageShadow.lineWidth = 18
        frontageShadow.lineCap = .butt
        frontageShadow.zPosition = 1.2
        root.addChild(frontageShadow)

        let frontageLinks = SKShapeNode(path: frontageLinkPath(
            completed: completed,
            in: state,
            kinds: structuralKinds
        ))
        frontageLinks.name = "district.ground.frontage-links.material"
        frontageLinks.strokeColor = style.palette.concrete.blended(
            withFraction: 0.22,
            of: style.palette.sidewalk
        )?.withAlphaComponent(0.96) ?? style.palette.concrete
        frontageLinks.lineWidth = 15
        frontageLinks.lineCap = .butt
        frontageLinks.zPosition = 1.4
        root.addChild(frontageLinks)

        let parkFrontageShadow = SKShapeNode(path: frontageLinkPath(
            completed: completed,
            in: state,
            kinds: [.park],
            offset: CGPoint(x: 1.2, y: -1.1)
        ))
        parkFrontageShadow.name = "district.ground.park-access.contact"
        parkFrontageShadow.strokeColor = NSColor.black.withAlphaComponent(0.15)
        parkFrontageShadow.lineWidth = 24
        parkFrontageShadow.lineCap = .butt
        parkFrontageShadow.zPosition = 1.2
        root.addChild(parkFrontageShadow)

        let parkFrontage = SKShapeNode(path: frontageLinkPath(
            completed: completed,
            in: state,
            kinds: [.park]
        ))
        parkFrontage.name = "district.ground.park-access.material"
        parkFrontage.strokeColor = style.palette.parkPath.blended(
            withFraction: 0.24,
            of: style.palette.sidewalk
        )?.withAlphaComponent(0.96) ?? style.palette.parkPath
        parkFrontage.lineWidth = 23
        parkFrontage.lineCap = .butt
        parkFrontage.zPosition = 1.4
        root.addChild(parkFrontage)

        let serviceKinds: Set<BuildingKind> = [.powerPlant, .waterTower]
        let serviceFrontageShadow = SKShapeNode(path: frontageLinkPath(
            completed: completed,
            in: state,
            kinds: serviceKinds,
            offset: CGPoint(x: 1.2, y: -1.1)
        ))
        serviceFrontageShadow.name = "district.ground.service-access.contact"
        serviceFrontageShadow.strokeColor = NSColor.black.withAlphaComponent(0.17)
        serviceFrontageShadow.lineWidth = 26
        serviceFrontageShadow.lineCap = .butt
        serviceFrontageShadow.zPosition = 1.2
        root.addChild(serviceFrontageShadow)

        let serviceFrontage = SKShapeNode(path: frontageLinkPath(
            completed: completed,
            in: state,
            kinds: serviceKinds
        ))
        serviceFrontage.name = "district.ground.service-access.material"
        serviceFrontage.strokeColor = style.palette.soil.blended(
            withFraction: 0.34,
            of: style.palette.concrete
        )?.withAlphaComponent(0.98) ?? style.palette.soil
        serviceFrontage.lineWidth = 22
        serviceFrontage.lineCap = .butt
        serviceFrontage.zPosition = 1.4
        root.addChild(serviceFrontage)

        let serviceCampus = serviceCampusCoordinates(
            in: state,
            completed: completed
        )
        addServiceCampusGround(
            coordinates: serviceCampus,
            to: neighborhoodLayer
        )

        let familyGroups = Dictionary(grouping: completed, by: \.kind)
        for (kind, tiles) in familyGroups {
            if kind == .park {
                addSpecialParcelMaterial(
                    kind: kind,
                    tiles: tiles,
                    to: neighborhoodLayer
                )
                continue
            }
            if kind == .powerPlant || kind == .waterTower {
                continue
            }
            let parcelSize: CGSize = switch kind {
            default: CGSize(width: style.tileWidth - 3, height: style.tileHeight - 1.5)
            }
            let parcel = SKShapeNode(path: combinedDiamondPath(
                coordinates: tiles.map(\.coordinate),
                width: parcelSize.width,
                height: parcelSize.height
            ))
            parcel.name = "district.ground.authoritative-parcels.\(kind.rawValue)"
            parcel.fillColor = districtGroundColor(for: kind)
            parcel.strokeColor = .clear
            parcel.zPosition = 2
            root.addChild(parcel)
        }
        for (index, block) in enclosedBlocks.enumerated() {
            addEnclosedCommons(
                block,
                index: index,
                // The prototype carries the highest accepted source once;
                // detail-layer visibility still controls when it is shown.
                detail: .block,
                city: cityLayer,
                neighborhood: neighborhoodLayer,
                block: blockLayer
            )
        }
        if Self.developedGroundTemplates.count < Self.maximumDevelopedGroundTemplateCount,
           let prototype = root.copy() as? SKNode {
            Self.developedGroundTemplates[key] = prototype
        }
        style.updateDetailVisibility(in: root, detail: detail)
        return root
    }

    func connectedFrontageRoadCoordinatesForTesting(
        in state: CityGameState
    ) -> Set<GridCoordinate> {
        let completed = state.tiles.filter {
            $0.kind != .empty && $0.kind != .road && $0.constructionProgress >= 1
        }
        return Set(connectedFrontageRoads(in: state, completed: completed).map(\.coordinate))
    }

    func enclosedVacantCoordinatesForTesting(
        in state: CityGameState
    ) -> Set<GridCoordinate> {
        Set(enclosedDistrictBlocks(in: state).flatMap(\.vacantCoordinates))
    }

    func serviceCampusGroundCoordinatesForTesting(
        in state: CityGameState
    ) -> Set<GridCoordinate> {
        let completed = state.tiles.filter {
            $0.kind != .empty && $0.kind != .road && $0.constructionProgress >= 1
        }
        return Set(serviceCampusCoordinates(in: state, completed: completed))
    }

    private struct EnclosedDistrictBlock {
        let componentCoordinates: [GridCoordinate]
        let vacantCoordinates: [GridCoordinate]
    }

    private func connectedFrontageRoads(
        in state: CityGameState,
        completed: [CityTile]
    ) -> [CityTile] {
        let roadsByCoordinate = Dictionary(
            uniqueKeysWithValues: state.tiles.filter { $0.kind == .road }.map {
                ($0.coordinate, $0)
            }
        )
        let completedCoordinates = Set(completed.map(\.coordinate))
        var pending = roadsByCoordinate.keys.filter { coordinate in
            cardinalNeighbors(of: coordinate).contains {
                completedCoordinates.contains($0)
            }
        }.sorted(by: coordinateComesBefore)
        var connected = Set<GridCoordinate>()
        while !pending.isEmpty {
            let coordinate = pending.removeFirst()
            guard connected.insert(coordinate).inserted else { continue }
            for neighbor in cardinalNeighbors(of: coordinate)
                where roadsByCoordinate[neighbor] != nil && !connected.contains(neighbor) {
                pending.append(neighbor)
            }
        }
        return connected.sorted(by: coordinateComesBefore).compactMap {
            roadsByCoordinate[$0]
        }
    }

    /// Finds non-road regions that cannot reach the map edge, then retains
    /// their authoritative empty coordinates. Occupied coordinates may divide
    /// the visual surface, but never become part of the commons geometry.
    private func enclosedDistrictBlocks(in state: CityGameState) -> [EnclosedDistrictBlock] {
        guard state.gridWidth > 2, state.gridHeight > 2 else { return [] }
        let nonRoad = Set(state.tiles.filter { $0.kind != .road }.map(\.coordinate))
        var exterior = Set<GridCoordinate>()
        var pending = nonRoad.filter {
            $0.x == 0 || $0.y == 0
                || $0.x == state.gridWidth - 1
                || $0.y == state.gridHeight - 1
        }.sorted(by: coordinateComesBefore)
        while !pending.isEmpty {
            let coordinate = pending.removeFirst()
            guard exterior.insert(coordinate).inserted else { continue }
            for neighbor in cardinalNeighbors(of: coordinate)
                where nonRoad.contains(neighbor) && !exterior.contains(neighbor) {
                pending.append(neighbor)
            }
        }

        let enclosed = nonRoad.subtracting(exterior)
        var remaining = enclosed
        var components: [[GridCoordinate]] = []
        while let origin = remaining.min(by: coordinateComesBefore) {
            remaining.remove(origin)
            var component = [origin]
            var frontier = [origin]
            while !frontier.isEmpty {
                let coordinate = frontier.removeFirst()
                for neighbor in cardinalNeighbors(of: coordinate)
                    where remaining.remove(neighbor) != nil {
                    component.append(neighbor)
                    frontier.append(neighbor)
                }
            }
            components.append(component.sorted(by: coordinateComesBefore))
        }

        return components.compactMap { component in
            let vacant = component.filter { state.tile(at: $0)?.kind == .empty }
            guard vacant.count >= 2 else { return nil }
            return EnclosedDistrictBlock(
                componentCoordinates: component,
                vacantCoordinates: vacant
            )
        }.sorted {
            guard let lhs = $0.vacantCoordinates.first,
                  let rhs = $1.vacantCoordinates.first else { return false }
            return coordinateComesBefore(lhs, rhs)
        }
    }

    private func addEnclosedCommons(
        _ commons: EnclosedDistrictBlock,
        index: Int,
        detail: CameraDetailLevel,
        city: SKNode,
        neighborhood: SKNode,
        block _: SKNode
    ) {
        let bounds = commons.componentCoordinates.reduce(
            into: (
                minimumX: Int.max,
                minimumY: Int.max,
                maximumX: Int.min,
                maximumY: Int.min
            )
        ) { result, coordinate in
            result.minimumX = min(result.minimumX, coordinate.x)
            result.minimumY = min(result.minimumY, coordinate.y)
            result.maximumX = max(result.maximumX, coordinate.x)
            result.maximumY = max(result.maximumY, coordinate.y)
        }
        let field = fieldCorners(
            minimumX: bounds.minimumX,
            minimumY: bounds.minimumY,
            maximumX: bounds.maximumX,
            maximumY: bounds.maximumY
        )
        let meadow = SKShapeNode(path: style.polygonPath(field))
        meadow.name = "district.commons.natural-meadow.\(index)"
        meadow.fillColor = style.palette.lotGrass.blended(
            withFraction: 0.18,
            of: style.palette.soil
        ) ?? style.palette.lotGrass
        meadow.strokeColor = .clear
        meadow.isAntialiased = false
        meadow.zPosition = 3
        city.addChild(meadow)

        let textureAnchors = if commons.vacantCoordinates.count >= 8 {
            [
                commons.vacantCoordinates.count / 4,
                commons.vacantCoordinates.count / 2,
                commons.vacantCoordinates.count * 3 / 4,
            ]
        } else {
            [commons.vacantCoordinates.count / 2]
        }
        for (textureIndex, coordinateIndex) in textureAnchors.enumerated() {
            let textureCoordinate = commons.vacantCoordinates[coordinateIndex]
            let textureCenter = style.isoPosition(textureCoordinate)
            let texture = SKShapeNode(path: terrainTexturePath(
                center: CGPoint(
                    x: textureCenter.x + (
                        WorldVisualSeed.unit(
                            for: textureCoordinate,
                            kind: .empty,
                            salt: 0xC080 + UInt64(textureIndex)
                        ) - 0.5
                    ) * style.tileWidth * 0.42,
                    y: textureCenter.y + (
                        WorldVisualSeed.unit(
                            for: textureCoordinate,
                            kind: .empty,
                            salt: 0xC090 + UInt64(textureIndex)
                        ) - 0.5
                    ) * style.tileHeight * 0.30
                ),
                anchor: textureCoordinate,
                radiusX: style.tileWidth * (1.15 + CGFloat(textureIndex) * 0.12),
                radiusY: style.tileHeight * (0.54 + CGFloat(textureIndex) * 0.05),
                saltOffset: 0xC073 + UInt64(textureIndex) * 0x20
            ))
            texture.name = "district.commons.natural-texture.\(index).\(textureIndex)"
            let fill = textureIndex.isMultiple(of: 2)
                ? style.palette.parkGrass.blended(
                    withFraction: 0.46,
                    of: style.palette.lotGrass
                )
                : style.palette.soil.blended(
                    withFraction: 0.72,
                    of: style.palette.lotGrass
                )
            texture.fillColor = fill?.withAlphaComponent(0.18)
                ?? style.palette.parkGrass.withAlphaComponent(0.18)
            texture.strokeColor = .clear
            texture.zPosition = 4
            neighborhood.addChild(texture)
        }

        guard index == 0,
              let foliageCoordinate = commons.vacantCoordinates.first,
              let grove = assets.generatedSprite(
                  logicalID: "ambient_vegetation_cluster",
                  detail: detail
              ) else { return }
        let position = style.isoPosition(foliageCoordinate)
        grove.name = "district.commons.existing-foliage.\(index)"
        grove.position = CGPoint(
            x: position.x + grove.position.x + style.tileWidth * 0.16,
            y: position.y + grove.position.y - style.tileHeight * 0.06
        )
        grove.setScale(0.64)
        grove.zPosition = 6
        neighborhood.addChild(grove)
    }

    private func cardinalNeighbors(of coordinate: GridCoordinate) -> [GridCoordinate] {
        [
            GridCoordinate(x: coordinate.x + 1, y: coordinate.y),
            GridCoordinate(x: coordinate.x - 1, y: coordinate.y),
            GridCoordinate(x: coordinate.x, y: coordinate.y + 1),
            GridCoordinate(x: coordinate.x, y: coordinate.y - 1),
        ]
    }

    private func expansionBandCoordinates(
        in state: CityGameState,
        around fabricCoordinates: [GridCoordinate]
    ) -> [GridCoordinate] {
        let fabric = Set(fabricCoordinates)
        let candidates = fabric.flatMap { coordinate in
            cardinalNeighbors(of: coordinate)
        }
        return Set(candidates)
            .filter { coordinate in
                guard !fabric.contains(coordinate),
                      let tile = state.tile(at: coordinate) else { return false }
                return tile.kind == .empty
            }
            .sorted(by: coordinateComesBefore)
    }

    private func addFourViewExpansionGround(
        coordinates: [GridCoordinate],
        detail: CameraDetailLevel,
        to layer: SKNode
    ) {
        guard let groundEcologyAssets else { return }
        for coordinate in coordinates {
            let assetID = WorldVisualSeed.variant(
                count: 4,
                for: coordinate,
                kind: .empty,
                salt: 0x6EC0
            ) == 0
                ? "worn_neighborhood_ground"
                : "civic_meadow_ground"
            guard let sprite = groundEcologyAssets.makeSprite(
                assetID: assetID,
                worldTileWidth: style.tileWidth,
                zPosition: 0.24
            ) else { continue }
            sprite.name = "terrain.ground-ecology.\(assetID).\(detail.assetSuffix)"
            sprite.position = style.isoPosition(coordinate)
            sprite.color = .clear
            sprite.colorBlendFactor = 0
            layer.addChild(sprite)
        }
    }

    private func coordinateComesBefore(_ lhs: GridCoordinate, _ rhs: GridCoordinate) -> Bool {
        (lhs.y, lhs.x) < (rhs.y, rhs.x)
    }

    private func combinedDiamondPath(
        coordinates: [GridCoordinate],
        width: CGFloat,
        height: CGFloat,
        offset: CGPoint = .zero
    ) -> CGPath {
        let path = CGMutablePath()
        let diamond = style.diamondPath(width: width, height: height)
        for coordinate in coordinates {
            let position = style.isoPosition(coordinate)
            var transform = CGAffineTransform(
                translationX: position.x + offset.x,
                y: position.y + offset.y
            )
            if let translated = diamond.copy(using: &transform) {
                path.addPath(translated)
            }
        }
        return path
    }

    private func frontageLinkPath(
        completed: [CityTile],
        in state: CityGameState,
        kinds: Set<BuildingKind>,
        offset: CGPoint = .zero
    ) -> CGPath {
        let path = CGMutablePath()
        for tile in completed where kinds.contains(tile.kind) {
            let roads = RoadConnectionMask.resolving(at: tile.coordinate, in: state)
            guard let frontage = ResidentialGeneratedAssetIdentity
                .authoritativeFrontagePriority
                .first(where: roads.contains) else { continue }
            let center = style.isoPosition(tile.coordinate)
            let socket = style.roadSocket(for: frontage, overreach: 1.25)
            path.move(to: CGPoint(
                x: center.x + socket.x * 0.30 + offset.x,
                y: center.y + socket.y * 0.30 + offset.y
            ))
            path.addLine(to: CGPoint(
                x: center.x + socket.x * 1.05 + offset.x,
                y: center.y + socket.y * 1.05 + offset.y
            ))
        }
        return path
    }

    private func districtGroundColor(for kind: BuildingKind) -> NSColor {
        switch kind {
        case .residential:
            style.palette.lotGrass.withAlphaComponent(0.88)
        case .commercial, .cityHall, .fireStation, .policeStation, .school:
            style.palette.concrete.withAlphaComponent(0.90)
        case .industrial, .powerPlant, .waterTower:
            style.palette.soil.blended(
                withFraction: 0.40,
                of: style.palette.concrete
            )?.withAlphaComponent(0.90) ?? style.palette.soil.withAlphaComponent(0.90)
        case .park:
            style.palette.parkGrass.withAlphaComponent(0.92)
        case .empty, .road:
            .clear
        }
    }

    /// Adds irregular material inside and immediately around the authoritative
    /// one-cell parcel. It carries no hit target or gameplay meaning; its only
    /// job is to dissolve the square source-plate read while leaving every
    /// accepted above-ground sprite and registered shadow pixel intact.
    private func addSpecialParcelMaterial(
        kind: BuildingKind,
        tiles: [CityTile],
        to layer: SKNode
    ) {
        for (index, tile) in tiles.enumerated() {
            let center = style.isoPosition(tile.coordinate)
            let texture = SKShapeNode(path: terrainTexturePath(
                center: CGPoint(
                    x: center.x - style.tileWidth * 0.035,
                    y: center.y + style.tileHeight * 0.045
                ),
                anchor: tile.coordinate,
                radiusX: style.tileWidth * 0.39,
                radiusY: style.tileHeight * 0.17,
                saltOffset: 0xA730 + UInt64(index) * 0x10
            ))
            texture.name = "district.ground.authoritative-parcels."
                + "\(kind.rawValue).internal-material.\(index)"
            switch kind {
            case .park:
                texture.fillColor = style.palette.parkGrass.blended(
                    withFraction: 0.28,
                    of: style.palette.lotGrass
                )?.withAlphaComponent(0.46) ?? style.palette.parkGrass
            case .powerPlant, .waterTower:
                texture.fillColor = style.palette.soil.blended(
                    withFraction: 0.34,
                    of: style.palette.asphaltLight
                )?.withAlphaComponent(0.50) ?? style.palette.soil
            default:
                continue
            }
            texture.strokeColor = .clear
            texture.zPosition = 2.15
            layer.addChild(texture)

            if kind == .park {
                let halo = SKShapeNode(path: terrainTexturePath(
                    center: CGPoint(
                        x: center.x - style.tileWidth * 0.02,
                        y: center.y - style.tileHeight * 0.015
                    ),
                    anchor: tile.coordinate,
                    radiusX: style.tileWidth * 0.72,
                    radiusY: style.tileHeight * 0.34,
                    saltOffset: 0xA750 + UInt64(index) * 0x10
                ))
                halo.name = "district.ground.authoritative-parcels."
                    + "park.surrounding-ground.\(index)"
                halo.fillColor = style.palette.parkGrass.blended(
                    withFraction: 0.65,
                    of: style.palette.lotGrass
                )?.withAlphaComponent(0.78) ?? style.palette.parkGrass
                halo.strokeColor = .clear
                halo.zPosition = 2.08
                layer.addChild(halo)
            }

            let highlight = SKShapeNode(path: terrainTexturePath(
                center: CGPoint(
                    x: center.x - style.tileWidth * 0.09,
                    y: center.y + style.tileHeight * 0.10
                ),
                anchor: tile.coordinate,
                radiusX: style.tileWidth * 0.22,
                radiusY: style.tileHeight * 0.085,
                saltOffset: 0xA790 + UInt64(index) * 0x10
            ))
            highlight.name = "district.ground.authoritative-parcels."
                + "\(kind.rawValue).nw-highlight.\(index)"
            highlight.fillColor = style.palette.concreteLight.withAlphaComponent(
                kind == .park ? 0.055 : 0.07
            )
            highlight.strokeColor = .clear
            highlight.zPosition = 2.2
            layer.addChild(highlight)
        }
    }

    private func serviceCampusCoordinates(
        in state: CityGameState,
        completed: [CityTile]
    ) -> [GridCoordinate] {
        let serviceAnchors = Set(completed.compactMap { tile in
            tile.kind == .powerPlant || tile.kind == .waterTower
                ? tile.coordinate
                : nil
        })
        guard !serviceAnchors.isEmpty else { return [] }

        let frontageRoads = Set(serviceAnchors.flatMap { coordinate in
            cardinalNeighbors(of: coordinate).filter {
                state.tile(at: $0)?.kind == .road
            }
        })
        var surface = serviceAnchors.union(frontageRoads)

        func bridgeAlignedCoordinates(_ coordinates: Set<GridCoordinate>) {
            let ordered = coordinates.sorted(by: coordinateComesBefore)
            for leftIndex in ordered.indices {
                for rightIndex in ordered.indices where rightIndex > leftIndex {
                    let left = ordered[leftIndex]
                    let right = ordered[rightIndex]
                    if left.y == right.y, abs(left.x - right.x) <= 4 {
                        for x in min(left.x, right.x)...max(left.x, right.x) {
                            let coordinate = GridCoordinate(x: x, y: left.y)
                            guard let kind = state.tile(at: coordinate)?.kind,
                                  kind == .empty
                                    || kind == .road
                                    || kind == .powerPlant
                                    || kind == .waterTower else { continue }
                            surface.insert(coordinate)
                        }
                    } else if left.x == right.x, abs(left.y - right.y) <= 4 {
                        for y in min(left.y, right.y)...max(left.y, right.y) {
                            let coordinate = GridCoordinate(x: left.x, y: y)
                            guard let kind = state.tile(at: coordinate)?.kind,
                                  kind == .empty
                                    || kind == .road
                                    || kind == .powerPlant
                                    || kind == .waterTower else { continue }
                            surface.insert(coordinate)
                        }
                    }
                }
            }
        }
        bridgeAlignedCoordinates(serviceAnchors)
        bridgeAlignedCoordinates(frontageRoads)

        // A completed industrial place whose real frontage meets the same
        // authoritative access corridor may share the campus ground. No empty
        // coordinate changes kind, hit target, or buildability.
        for tile in completed where tile.kind == .industrial {
            if cardinalNeighbors(of: tile.coordinate).contains(where: surface.contains) {
                surface.insert(tile.coordinate)
            }
        }
        return surface.sorted(by: coordinateComesBefore)
    }

    private func addServiceCampusGround(
        coordinates: [GridCoordinate],
        to layer: SKNode
    ) {
        guard !coordinates.isEmpty else { return }
        let contact = SKShapeNode(path: combinedDiamondPath(
            coordinates: coordinates,
            width: style.tileWidth - 3,
            height: style.tileHeight - 2,
            offset: CGPoint(x: 0.45, y: -0.25)
        ))
        contact.name = "district.ground.service-campus.contact"
        contact.fillColor = NSColor.black.withAlphaComponent(0.15)
        contact.strokeColor = .clear
        contact.zPosition = 1.7
        layer.addChild(contact)

        let ground = SKShapeNode(path: combinedDiamondPath(
            coordinates: coordinates,
            width: style.tileWidth - 3,
            height: style.tileHeight - 1.5
        ))
        ground.name = "district.ground.service-campus.material"
        ground.fillColor = style.palette.soil.blended(
            withFraction: 0.56,
            of: style.palette.lotGrass
        )?.withAlphaComponent(0.90) ?? style.palette.soil
        ground.strokeColor = .clear
        ground.zPosition = 1.9
        layer.addChild(ground)

        let variationPath = CGMutablePath()
        for (index, coordinate) in coordinates.enumerated() {
            let center = style.isoPosition(coordinate)
            variationPath.addPath(terrainTexturePath(
                center: CGPoint(
                    x: center.x - style.tileWidth * 0.05,
                    y: center.y + style.tileHeight * 0.05
                ),
                anchor: coordinate,
                radiusX: style.tileWidth * 0.45,
                radiusY: style.tileHeight * 0.20,
                saltOffset: 0xA830 + UInt64(index) * 0x10
            ))
        }
        let variation = SKShapeNode(path: variationPath)
        variation.name = "district.ground.service-campus.internal-material"
        variation.fillColor = style.palette.asphaltLight.blended(
            withFraction: 0.60,
            of: style.palette.soil
        )?.withAlphaComponent(0.34) ?? style.palette.asphaltLight
        variation.strokeColor = .clear
        variation.zPosition = 2.05
        layer.addChild(variation)
    }

    private func macroFieldColor(variant: Int) -> NSColor {
        switch variant {
        case 0:
            style.palette.grass[0].blended(
                withFraction: 0.18,
                of: style.palette.soil
            )?.withAlphaComponent(0.13) ?? style.palette.grass[0].withAlphaComponent(0.13)
        case 1:
            style.palette.grass[1].blended(
                withFraction: 0.28,
                of: style.palette.soil
            )?.withAlphaComponent(0.12) ?? style.palette.grass[1].withAlphaComponent(0.12)
        case 2:
            style.palette.grass[2].blended(
                withFraction: 0.14,
                of: style.palette.lotGrass
            )?.withAlphaComponent(0.14) ?? style.palette.grass[2].withAlphaComponent(0.14)
        case 3:
            style.palette.grass[3].blended(
                withFraction: 0.24,
                of: style.palette.soil
            )?.withAlphaComponent(0.115) ?? style.palette.grass[3].withAlphaComponent(0.115)
        default:
            style.palette.soil.blended(
                withFraction: 0.38,
                of: style.palette.grass[0]
            )?.withAlphaComponent(0.11) ?? style.palette.soil.withAlphaComponent(0.11)
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
        let materialSpan = 2
        var materialIndex = 0
        for y in stride(from: 2, to: gridHeight - 1, by: materialSpan) {
            for x in stride(from: 2, to: gridWidth - 1, by: materialSpan) {
                let anchor = GridCoordinate(x: x, y: y)
                let center = style.isoPosition(anchor)
                let radiusX = style.tileWidth * (
                    1.18 + WorldVisualSeed.unit(
                        for: anchor,
                        kind: .empty,
                        salt: 0x7E22
                    ) * 0.38
                )
                let radiusY = style.tileHeight * (
                    0.62 + WorldVisualSeed.unit(
                        for: anchor,
                        kind: .empty,
                        salt: 0x7E23
                    ) * 0.22
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
                    meadow.fillColor = style.palette.grass[3].blended(
                        withFraction: 0.24,
                        of: style.palette.soil
                    )?.withAlphaComponent(0.065)
                        ?? style.palette.grass[3].withAlphaComponent(0.065)
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

        // Three bounded, broad material regions keep the outer board from
        // reading as one plain field. They are ground-only, deterministic,
        // and derived from the physical grid dimensions; they never create a
        // parcel, road, occupancy, or hit target.
        let regionalAnchors = [
            GridCoordinate(x: max(1, gridWidth / 4), y: max(1, gridHeight / 3)),
            GridCoordinate(x: max(1, gridWidth * 3 / 4), y: max(1, gridHeight / 3)),
            GridCoordinate(x: max(1, gridWidth / 3), y: max(1, gridHeight * 2 / 3)),
        ]
        for (index, anchor) in regionalAnchors.enumerated() {
            let center = style.isoPosition(anchor)
            let region = SKShapeNode(path: organicSwatchPath(
                center: center,
                anchor: anchor,
                radiusX: style.tileWidth * (2.25 + CGFloat(index) * 0.16),
                radiusY: style.tileHeight * (1.02 + CGFloat(index % 2) * 0.12),
                saltOffset: 0x920 + UInt64(index) * 0x17
            ))
            region.name = "terrain.macro.regional.material.\(index)"
            region.fillColor = macroFieldColor(variant: index + 1)
                .withAlphaComponent(0.22)
            region.strokeColor = .clear
            region.zPosition = 0.16
            city.addChild(region)
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

    private func terrainTexturePath(
        center: CGPoint,
        anchor: GridCoordinate,
        radiusX: CGFloat,
        radiusY: CGFloat,
        saltOffset: UInt64 = 0
    ) -> CGPath {
        let pointCount = 12
        let points = (0..<pointCount).map { index in
            let angle = CGFloat(index) / CGFloat(pointCount) * .pi * 2
            let radialVariation = 0.78 + WorldVisualSeed.unit(
                for: anchor,
                kind: .empty,
                salt: 0x7E30 + saltOffset + UInt64(index)
            ) * 0.28
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
        let combined = CGMutablePath()
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
            for range in [
                (0.16 + phase, 0.39 + phase),
                (0.61 - phase, 0.82 - phase)
            ] {
                let segmentStart = CGPoint(
                    x: start.x + (end.x - start.x) * range.0,
                    y: start.y + (end.y - start.y) * range.0
                )
                let segmentEnd = CGPoint(
                    x: start.x + (end.x - start.x) * range.1,
                    y: start.y + (end.y - start.y) * range.1
                )
                combined.addPath(WorldGeometryCache.line(
                    from: segmentStart,
                    to: segmentEnd
                ))
            }
        }
        let furrows = SKShapeNode(path: combined)
        furrows.name = "terrain.macro.furrows.\(parcelIndex)"
        furrows.fillColor = .clear
        furrows.strokeColor = style.palette.concreteLight.blended(
            withFraction: 0.54,
            of: style.palette.soil
        )?.withAlphaComponent(0.075)
            ?? style.palette.concreteLight.withAlphaComponent(0.075)
        furrows.lineWidth = 0.7
        furrows.lineCap = .round
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
