import AppKit
import SpriteKit

struct ResidentialGeneratedAssetIdentity: Equatable, Sendable {
    static let authoritativeFrontagePriority: [RoadConnectionMask] = [
        .south, .north, .east, .west,
    ]

    let level: Int
    let variant: Int
    let frontage: RoadConnectionMask
    let direction: String
    let logicalID: String

    static func liveVisualVariant(at coordinate: GridCoordinate) -> Int {
        1 + WorldVisualSeed.variant(
            count: 2,
            for: coordinate,
            kind: .residential
        )
    }

    init?(
        level: Int,
        adjacentRoads: RoadConnectionMask,
        visualVariant: Int = 0
    ) {
        guard let frontage = Self.authoritativeFrontagePriority.first(
            where: adjacentRoads.contains
        ) else {
            return nil
        }
        self.level = min(4, max(1, level))
        variant = self.level == 1 ? min(2, max(0, visualVariant)) : 0
        self.frontage = frontage
        direction = switch frontage {
        case .north: "north"
        case .east: "east"
        case .south: "south"
        case .west: "west"
        default: preconditionFailure("frontage priority contains only cardinal edges")
        }
        logicalID = "residential_l\(String(format: "%02d", self.level))_v\(variant)_\(direction)"
    }
}

struct CommercialGeneratedAssetIdentity: Equatable, Sendable {
    static let authoritativeFrontagePriority =
        ResidentialGeneratedAssetIdentity.authoritativeFrontagePriority

    let level: Int
    let frontage: RoadConnectionMask
    let direction: String
    let logicalID: String

    init?(level: Int, adjacentRoads: RoadConnectionMask) {
        guard let frontage = Self.authoritativeFrontagePriority.first(
            where: adjacentRoads.contains
        ) else {
            return nil
        }
        self.level = min(4, max(1, level))
        self.frontage = frontage
        direction = switch frontage {
        case .north: "north"
        case .east: "east"
        case .south: "south"
        case .west: "west"
        default: preconditionFailure("frontage priority contains only cardinal edges")
        }
        logicalID = "commercial_l\(String(format: "%02d", self.level))_v0_\(direction)"
    }
}

struct IndustrialGeneratedAssetIdentity: Equatable, Sendable {
    static let authoritativeFrontagePriority =
        ResidentialGeneratedAssetIdentity.authoritativeFrontagePriority

    let level: Int
    let frontage: RoadConnectionMask
    let direction: String
    let logicalID: String

    init?(level: Int, adjacentRoads: RoadConnectionMask) {
        guard (1...3).contains(level),
              let frontage = Self.authoritativeFrontagePriority.first(
                  where: adjacentRoads.contains
              ) else {
            return nil
        }
        self.level = level
        self.frontage = frontage
        direction = switch frontage {
        case .north: "north"
        case .east: "east"
        case .south: "south"
        case .west: "west"
        default: preconditionFailure("frontage priority contains only cardinal edges")
        }
        logicalID = "industrial_l\(String(format: "%02d", level))_v0_\(direction)"
    }
}

struct CivicGeneratedAssetIdentity: Equatable, Sendable {
    static let authoritativeFrontagePriority =
        ResidentialGeneratedAssetIdentity.authoritativeFrontagePriority

    let frontage: RoadConnectionMask
    let direction: String
    let logicalID: String

    init?(adjacentRoads: RoadConnectionMask) {
        guard let frontage = Self.authoritativeFrontagePriority.first(
            where: adjacentRoads.contains
        ) else {
            return nil
        }
        self.frontage = frontage
        direction = switch frontage {
        case .north: "north"
        case .east: "east"
        case .south: "south"
        case .west: "west"
        default: preconditionFailure("frontage priority contains only cardinal edges")
        }
        logicalID = "civic_l01_v0_\(direction)"
    }
}

@MainActor
final class LotRenderer {
    private let style: WorldVisualStyle
    private let assets: WorldAssetCatalog
    private let lifecycleRenderer: LotLifecycleRenderer
    private let contextRenderer: LotContextRenderer

    init(style: WorldVisualStyle, assets: WorldAssetCatalog = .shared) {
        self.style = style
        self.assets = assets
        self.lifecycleRenderer = LotLifecycleRenderer(style: style)
        self.contextRenderer = LotContextRenderer(style: style)
    }

    func makeLot(
        for tile: CityTile,
        adjacentRoads: RoadConnectionMask = [],
        detail: CameraDetailLevel,
        reducedMotion: Bool
    ) -> SKNode {
        let variant = WorldVisualSeed.variant(count: 3, for: tile.coordinate, kind: tile.kind)
        // Variant 0 remains in the catalog for provenance and focused asset
        // inspection, but its flat black-roof silhouette belongs to a
        // different visual family than the starter district. Live level-one
        // homes intentionally alternate between the two projection-, scale-,
        // and lighting-compatible families until that source is re-authored.
        let residentialVariant = ResidentialGeneratedAssetIdentity.liveVisualVariant(
            at: tile.coordinate
        )
        let presentation = LotConsequencePresentation(tile: tile)
        let strategyIdentity = StrategyDistrictVisualIdentity(tile: tile)
        let residentialIdentity = tile.kind == .residential
            ? ResidentialGeneratedAssetIdentity(
                level: tile.level,
                adjacentRoads: adjacentRoads,
                visualVariant: residentialVariant
            )
            : nil
        let commercialIdentity = tile.kind == .commercial
            ? CommercialGeneratedAssetIdentity(level: tile.level, adjacentRoads: adjacentRoads)
            : nil
        let industrialIdentity = tile.kind == .industrial && (1...3).contains(tile.level)
            ? IndustrialGeneratedAssetIdentity(
                level: tile.level,
                adjacentRoads: adjacentRoads
            )
            : nil
        let civicIdentity: CivicGeneratedAssetIdentity? = switch tile.kind {
        case .cityHall, .fireStation, .policeStation, .school:
            CivicGeneratedAssetIdentity(adjacentRoads: adjacentRoads)
        default:
            nil
        }
        let root = SKNode()
        root.name = if let strategyIdentity {
            "lot.\(tile.kind.rawValue).density.\(strategyIdentity.densityTier).variant.\(variant)"
        } else {
            "lot.\(tile.kind.rawValue).variant.\(variant)"
        }

        let cityLayer = style.makeDetailLayer(.city, visibleAt: detail)
        let neighborhoodLayer = style.makeDetailLayer(.neighborhood, visibleAt: detail)
        let blockLayer = style.makeDetailLayer(.block, visibleAt: detail)
        root.addChild(cityLayer)
        root.addChild(neighborhoodLayer)
        root.addChild(blockLayer)

        addCityDensityFoundation(for: tile.kind, to: cityLayer)
        if presentation.construction == .complete || presentation.construction == .finishing {
            contextRenderer.addGroundContext(
                for: tile,
                adjacentRoads: adjacentRoads,
                selectedFrontage: residentialIdentity?.frontage
                    ?? commercialIdentity?.frontage
                    ?? industrialIdentity?.frontage
                    ?? civicIdentity?.frontage,
                city: cityLayer,
                neighborhood: neighborhoodLayer,
                block: blockLayer
            )
        }
        addAuthoredFrontage(
            for: tile.kind,
            adjacentRoads: adjacentRoads,
            selectedEdge: residentialIdentity?.frontage
                ?? commercialIdentity?.frontage
                ?? industrialIdentity?.frontage
                ?? civicIdentity?.frontage,
            detail: detail,
            to: neighborhoodLayer
        )
        if presentation.construction == .complete {
            addBlockInspectionDetail(
                for: tile,
                condition: presentation.condition,
                to: blockLayer
            )
        }
        if presentation.construction == .complete || presentation.construction == .finishing {
            _ = addAuthoredPlaceFamily(
                tile,
                variant: tile.kind == .residential ? residentialVariant : variant,
                residentialIdentity: residentialIdentity,
                commercialIdentity: commercialIdentity,
                industrialIdentity: industrialIdentity,
                civicIdentity: civicIdentity,
                adjacentRoads: adjacentRoads,
                detail: detail,
                city: cityLayer,
                neighborhood: neighborhoodLayer,
                block: blockLayer
            )
        }
        if presentation.construction == .complete {
            contextRenderer.addForegroundContext(
                for: tile,
                adjacentRoads: adjacentRoads,
                selectedFrontage: residentialIdentity?.frontage
                    ?? commercialIdentity?.frontage
                    ?? industrialIdentity?.frontage
                    ?? civicIdentity?.frontage,
                city: cityLayer,
                neighborhood: neighborhoodLayer,
                block: blockLayer
            )
        }

        if presentation.construction == .finishing {
            cityLayer.alpha = 0.64
            neighborhoodLayer.alpha = 0.64
            blockLayer.alpha = 0.64
        }

        if presentation.construction != .complete {
            root.addChild(lifecycleRenderer.makeConstruction(
                for: tile,
                stage: presentation.construction,
                detail: detail,
                reducedMotion: reducedMotion
            ))
        } else {
            root.addChild(lifecycleRenderer.makeCompletedState(
                for: tile,
                presentation: presentation,
                detail: detail,
                reducedMotion: reducedMotion
            ))
        }
        return root
    }

    @discardableResult
    private func addAuthoredPlaceFamily(
        _ tile: CityTile,
        variant: Int,
        residentialIdentity: ResidentialGeneratedAssetIdentity?,
        commercialIdentity: CommercialGeneratedAssetIdentity?,
        industrialIdentity: IndustrialGeneratedAssetIdentity?,
        civicIdentity: CivicGeneratedAssetIdentity?,
        adjacentRoads: RoadConnectionMask,
        detail: CameraDetailLevel,
        city: SKNode,
        neighborhood _: SKNode,
        block: SKNode
    ) -> Bool {
        if tile.kind == .residential {
            guard let result = assets.generatedResidentialPresentation(
                level: tile.level,
                adjacentRoads: adjacentRoads,
                visualVariant: variant,
                detail: detail
            ) else {
                return false
            }
            guard residentialIdentity == result.identity else { return false }
            let sprite = result.presentation.sprite
            sprite.name = "lot.generated-v4.\(result.identity.logicalID).\(detail.assetSuffix)"
            harmonizeAuthoredSprite(sprite, for: tile, variant: variant)
            city.addChild(sprite)
            return true
        }
        if tile.kind == .commercial {
            guard let result = assets.generatedCommercialPresentation(
                level: tile.level,
                adjacentRoads: adjacentRoads,
                detail: detail
            ) else {
                return false
            }
            guard commercialIdentity == result.identity else { return false }
            let sprite = result.presentation.sprite
            sprite.name = "lot.generated-v4.\(result.identity.logicalID).\(detail.assetSuffix)"
            harmonizeAuthoredSprite(sprite, for: tile, variant: variant)
            city.addChild(sprite)
            return true
        }
        if tile.kind == .industrial && (1...3).contains(tile.level) {
            guard let result = assets.generatedIndustrialPresentation(
                level: tile.level,
                adjacentRoads: adjacentRoads,
                detail: detail
            ) else {
                return false
            }
            guard industrialIdentity == result.identity else { return false }
            let sprite = result.presentation.sprite
            sprite.name = "lot.generated-v4.\(result.identity.logicalID).\(detail.assetSuffix)"
            harmonizeAuthoredSprite(sprite, for: tile, variant: variant)
            city.addChild(sprite)
            return true
        }
        if civicIdentity != nil {
            guard let result = assets.generatedCivicPresentation(
                adjacentRoads: adjacentRoads,
                detail: detail
            ) else {
                return false
            }
            guard civicIdentity == result.identity else { return false }
            let sprite = result.presentation.sprite
            sprite.name = "lot.generated-v4.\(result.identity.logicalID).\(detail.assetSuffix)"
            harmonizeAuthoredSprite(sprite, for: tile, variant: variant)
            city.addChild(sprite)
            addGeneratedRoleIdentity(for: tile.kind, to: block)
            return true
        }
        if let generatedID = generatedLogicalID(for: tile.kind),
           let sprite = assets.generatedSprite(logicalID: generatedID, detail: detail) {
            sprite.name = "lot.generated-v4.\(generatedID).\(detail.assetSuffix)"
            harmonizeAuthoredSprite(sprite, for: tile, variant: variant)
            city.addChild(sprite)
            addGeneratedRoleIdentity(for: tile.kind, to: block)
            return true
        }
        // Production never silently drops back to the legacy atlas or shape
        // buildings. A missing generated source is counted by the catalog and
        // leaves an explicit semantic hole for staged verification to reject.
        return false
    }

    /// Applies a secondary deterministic presentation grade without changing
    /// accepted source bytes, projection, registration, frontage, or
    /// silhouette. Structural grounding and contextual lot dressing carry the
    /// district treatment; semantic identity continues to come exclusively
    /// from the accepted logical asset.
    private func harmonizeAuthoredSprite(
        _ sprite: SKSpriteNode,
        for tile: CityTile,
        variant _: Int
    ) {
        // Preserve every generated descriptor's anchor and placement pivot.
        // Normalize only sprites whose measured authored bounds exceed the
        // established one-cell presentation envelope. This leaves families
        // already inside that envelope at their accepted scale while bringing
        // the larger Industrial and residential-variant payloads into the
        // same composed-city range without changing source art or metadata.
        let presentationScale = min(
            1,
            60 / sprite.size.width,
            50 / sprite.size.height
        )
        if presentationScale != 1 {
            sprite.setScale(presentationScale)
        }
        switch tile.kind {
        case .residential:
            sprite.colorBlendFactor = 0
        case .commercial:
            sprite.colorBlendFactor = 0
        case .industrial:
            sprite.colorBlendFactor = 0
        case .powerPlant:
            sprite.color = style.palette.asphaltLight
            sprite.colorBlendFactor = 0.03
            sprite.setScale(0.88)
        case .waterTower:
            sprite.color = style.palette.concreteLight
            sprite.colorBlendFactor = 0.018
            // Preserve the descriptor pivot while bringing the one-cell
            // landmark back into the starter district's physical hierarchy.
            // The accepted source is still taller than its neighboring
            // service building, but no longer overwhelms the whole corridor.
            sprite.setScale(0.64)
        case .park:
            sprite.color = style.palette.parkGrass
            sprite.colorBlendFactor = 0.014
            // Reveal the continuous renderer-owned park ground and frontage
            // around the accepted source plate instead of letting its square
            // edge read as a floating tile.
            sprite.setScale(0.96)
        case .cityHall, .fireStation, .policeStation, .school:
            sprite.color = style.palette.concreteLight
            sprite.colorBlendFactor = 0.018
        case .empty, .road:
            break
        }
    }

    private func generatedLogicalID(for kind: BuildingKind) -> String? {
        switch kind {
        case .residential: nil
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

    private func addGeneratedRoleIdentity(for kind: BuildingKind, to node: SKNode) {
        let identity = SKNode()
        identity.name = "lot.generated-role.\(kind.rawValue)"
        switch kind {
        case .powerPlant:
            addTransformerBank(at: CGPoint(x: -24, y: -7), to: identity)
        case .fireStation:
            addHydrant(at: CGPoint(x: 24, y: -6), to: identity)
        case .policeStation:
            addBollards(at: CGPoint(x: -22, y: -7), count: 2, to: identity)
        case .school:
            addFlagpole(at: CGPoint(x: 22, y: 6), to: identity)
        case .empty, .road, .residential, .commercial, .industrial, .park, .waterTower, .cityHall:
            break
        }
        if !identity.children.isEmpty { node.addChild(identity) }
    }

    private func addCityDensityFoundation(for kind: BuildingKind, to node: SKNode) {
        let fill: NSColor
        let size: CGSize
        switch kind {
        case .residential:
            fill = style.palette.lotGrass
            size = CGSize(width: 61, height: 30.5)
        case .commercial, .cityHall, .fireStation, .policeStation, .school:
            fill = style.palette.concrete
            size = CGSize(width: 65, height: 32.5)
        case .industrial, .powerPlant, .waterTower:
            fill = style.palette.soil
            size = CGSize(width: 67, height: 33.5)
        case .park:
            fill = style.palette.parkGrass
            size = CGSize(width: 68, height: 34)
        case .empty, .road:
            return
        }
        let foundation = SKShapeNode(path: style.diamondPath(
            width: size.width,
            height: size.height
        ))
        foundation.name = "lot.lod.city.mass.\(kind.rawValue)"
        foundation.fillColor = fill.withAlphaComponent(0.88)
        foundation.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.42)
        foundation.lineWidth = 0.9
        // The generated park is a ground-and-vegetation composition whose
        // authored depth role is intentionally below building structures.
        // Keeping the generic density plate above it hid the fountain,
        // planting, paths, benches, and trees and left only a turquoise slab
        // visible in normal play. Park grounding belongs behind that authored
        // composition; structure families retain their prior depth.
        foundation.zPosition = kind == .park ? -5.2 : -3.4
        node.addChild(foundation)
    }

    private func addStrategyGround(
        _ identity: StrategyDistrictVisualIdentity,
        to node: SKNode
    ) {
        guard let ground = assets.sprite(
            named: identity.groundAssetName,
            size: CGSize(width: style.tileWidth, height: style.tileHeight)
        ) else { return }
        ground.name = "lot.strategyGround.\(identity.family.rawValue).density.\(identity.densityTier)"
        ground.zPosition = -0.5
        node.addChild(ground)
    }

    private func addAuthoredFrontage(
        for kind: BuildingKind,
        adjacentRoads: RoadConnectionMask,
        selectedEdge: RoadConnectionMask?,
        detail _: CameraDetailLevel,
        to node: SKNode
    ) {
        let family: String?
        switch kind {
        case .residential: family = "residential"
        case .commercial: family = "commercial"
        case .industrial, .powerPlant, .waterTower: family = "industrial"
        case .park: family = "park"
        case .cityHall, .fireStation, .policeStation, .school: family = "civic"
        case .empty, .road: family = nil
        }
        guard let family else { return }

        // Architecture keeps its authored south-facing projection and lighting.
        // A deterministic site path joins the declared entrance to an actual
        // road socket; the renderer never rotates a bitmap independently from
        // its building or invents a different occupied footprint.
        guard let edge = selectedEdge
            ?? ResidentialGeneratedAssetIdentity.authoritativeFrontagePriority.first(
                where: adjacentRoads.contains
            ) else {
            return
        }
        let endpoint = style.roadSocket(for: edge, overreach: 0.75)
        let entrance = frontageEntrance(for: kind, edge: edge)
        let path = CGMutablePath()
        path.move(to: entrance)
        path.addQuadCurve(
            to: endpoint,
            control: CGPoint(
                x: entrance.x * 0.35 + endpoint.x * 0.65,
                y: entrance.y * 0.35 + endpoint.y * 0.65
            )
        )

        let width: CGFloat = switch kind {
        case .industrial, .powerPlant, .waterTower: 8
        case .commercial, .cityHall, .fireStation, .policeStation, .school: 6
        case .park: 5
        default: 4
        }
        let edgeStroke = SKShapeNode(path: path)
        edgeStroke.name = "lot.frontage.\(family).\(edge.rawValue)"
        edgeStroke.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.48)
        edgeStroke.lineWidth = width + 2
        edgeStroke.lineCap = .butt
        edgeStroke.lineJoin = .round
        edgeStroke.zPosition = 2.8
        node.addChild(edgeStroke)

        let apron = SKShapeNode(path: path)
        apron.name = "lot.frontage.apron.\(family).\(edge.rawValue)"
        apron.strokeColor = kind == .park
            ? style.palette.parkPath
            : style.palette.concreteLight.withAlphaComponent(0.94)
        apron.lineWidth = width
        apron.lineCap = .butt
        apron.lineJoin = .round
        apron.zPosition = 3
        node.addChild(apron)

        let length = max(0.001, hypot(endpoint.x, endpoint.y))
        let perpendicular = CGPoint(x: -endpoint.y / length, y: endpoint.x / length)
        let curbCenter = CGPoint(x: endpoint.x * 0.86, y: endpoint.y * 0.86)
        let curbBreak = SKShapeNode(path: WorldGeometryCache.line(
            from: CGPoint(
                x: curbCenter.x - perpendicular.x * (width / 2 + 1),
                y: curbCenter.y - perpendicular.y * (width / 2 + 1)
            ),
            to: CGPoint(
                x: curbCenter.x + perpendicular.x * (width / 2 + 1),
                y: curbCenter.y + perpendicular.y * (width / 2 + 1)
            )
        ))
        curbBreak.name = "lot.frontage.curb-break.\(edge.rawValue)"
        curbBreak.strokeColor = style.palette.curb
        curbBreak.lineWidth = 1.4
        curbBreak.zPosition = 3.2
        node.addChild(curbBreak)
    }

    /// The accepted generated descriptors keep one directional projection per
    /// frontage. Keep the path in that same local direction; using the old
    /// south-only entrance made otherwise valid north/east/west structures
    /// appear detached while leaving their source bytes untouched.
    private func frontageEntrance(
        for kind: BuildingKind,
        edge: RoadConnectionMask
    ) -> CGPoint {
        if kind == .waterTower {
            return CGPoint(x: 0, y: -14)
        }
        return switch edge {
        case .north: CGPoint(x: 0, y: 13.5)
        case .east: CGPoint(x: 13.5, y: 0)
        case .south: CGPoint(x: 0, y: -13.5)
        case .west: CGPoint(x: -13.5, y: 0)
        default: CGPoint.zero
        }
    }

    /// Neighborhood LOD adds use-specific frontage furniture instead of only
    /// enlarging the city silhouette. The cues stay in the ground plane and
    /// share the authored site's material palette; they never become bright
    /// circular markers, poles, facade-mounted boxes, or gameplay assertions.
    private func addNeighborhoodPublicRealm(
        for kind: BuildingKind,
        to node: SKNode
    ) {
        let publicRealm = SKNode()
        switch kind {
        case .residential:
            publicRealm.name = "lot.lod.neighborhood.public-realm.residential"
            addGroundInlay(
                name: "planting-west",
                width: 18,
                height: 6,
                fill: style.palette.parkGrass.blended(
                    withFraction: 0.34,
                    of: style.palette.mapEarthDark
                ) ?? style.palette.parkGrass,
                at: CGPoint(x: -18, y: -10),
                to: publicRealm
            )
            addGroundInlay(
                name: "planting-east",
                width: 12,
                height: 4.5,
                fill: style.palette.parkGrass.blended(
                    withFraction: 0.28,
                    of: style.palette.mapEarthDark
                ) ?? style.palette.parkGrass,
                at: CGPoint(x: 19, y: -8),
                to: publicRealm
            )
        case .commercial:
            publicRealm.name = "lot.lod.neighborhood.public-realm.commercial"
            addPaverSeams(
                from: CGPoint(x: -24, y: -10),
                to: CGPoint(x: 24, y: -10),
                count: 4,
                to: publicRealm
            )
        case .industrial, .powerPlant, .waterTower:
            publicRealm.name = "lot.lod.neighborhood.public-realm.industrial"
            addLoadingRails(at: CGPoint(x: 18, y: -10), to: publicRealm)
        case .park:
            publicRealm.name = "lot.lod.neighborhood.public-realm.park"
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -23, y: -9))
            path.addQuadCurve(
                to: CGPoint(x: 23, y: -5),
                control: CGPoint(x: -2, y: -15)
            )
            let wornPath = SKShapeNode(path: path)
            wornPath.name = "lot.lod.neighborhood.public-realm.park-worn-path"
            wornPath.strokeColor = style.palette.parkPath.withAlphaComponent(0.46)
            wornPath.lineWidth = 3.2
            wornPath.lineCap = .round
            publicRealm.addChild(wornPath)
        case .cityHall, .fireStation, .policeStation, .school:
            publicRealm.name = "lot.lod.neighborhood.public-realm.civic"
            addGroundInlay(
                name: "civic-forecourt",
                width: 30,
                height: 7,
                fill: style.palette.concreteLight.blended(
                    withFraction: 0.22,
                    of: style.palette.mapEarth
                ) ?? style.palette.concreteLight,
                at: CGPoint(x: 0, y: -10),
                to: publicRealm
            )
        case .empty, .road:
            return
        }
        if !publicRealm.children.isEmpty { node.addChild(publicRealm) }
    }

    private func addGroundInlay(
        name: String,
        width: CGFloat,
        height: CGFloat,
        fill: NSColor,
        at position: CGPoint,
        to node: SKNode
    ) {
        let inlay = SKShapeNode(path: style.diamondPath(width: width, height: height))
        inlay.name = "lot.lod.neighborhood.\(name)"
        inlay.fillColor = fill.withAlphaComponent(0.58)
        inlay.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.34)
        inlay.lineWidth = 0.55
        inlay.position = position
        inlay.zPosition = 4.5
        node.addChild(inlay)
    }

    private func addPaverSeams(
        from start: CGPoint,
        to end: CGPoint,
        count: Int,
        to node: SKNode
    ) {
        let seams = CGMutablePath()
        for index in 0..<count {
            let progress = CGFloat(index + 1) / CGFloat(count + 1)
            let x = start.x + (end.x - start.x) * progress
            seams.move(to: CGPoint(x: x - 3, y: start.y - 1.5))
            seams.addLine(to: CGPoint(x: x + 3, y: start.y + 1.5))
        }
        let marks = SKShapeNode(path: seams)
        marks.name = "lot.lod.neighborhood.public-realm.commercial-pavers"
        marks.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.31)
        marks.lineWidth = 0.65
        marks.lineCap = .round
        marks.zPosition = 4.5
        node.addChild(marks)
    }

    private func addLoadingRails(at position: CGPoint, to node: SKNode) {
        let rails = CGMutablePath()
        for offset in [-3.0, 0.0, 3.0] {
            rails.move(to: CGPoint(x: position.x - 10, y: position.y + offset))
            rails.addLine(to: CGPoint(x: position.x + 10, y: position.y + offset))
        }
        let marks = SKShapeNode(path: rails)
        marks.name = "lot.lod.neighborhood.public-realm.industrial-loading-rails"
        marks.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.42)
        marks.lineWidth = 0.8
        marks.lineCap = .butt
        marks.zPosition = 4.5
        node.addChild(marks)
    }

    /// Block LOD exposes the physical entrance and material condition at the
    /// player's active inspection scale. The condition mapping reuses the
    /// renderer-only lifecycle presentation and remains subordinate to
    /// selection, placement, and consequence overlays.
    private func addBlockInspectionDetail(
        for tile: CityTile,
        condition: LotConditionPresentation,
        to node: SKNode
    ) {
        let threshold = SKShapeNode(path: style.diamondPath(width: 13, height: 4.5))
        threshold.name = "lot.lod.block.entrance.\(tile.kind.rawValue)"
        threshold.fillColor = style.palette.concreteLight.withAlphaComponent(0.78)
        threshold.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.48)
        threshold.lineWidth = 0.65
        threshold.position = CGPoint(x: 0, y: -12)
        threshold.zPosition = 13
        node.addChild(threshold)

        guard condition != .maintained else { return }
        let wear = SKNode()
        wear.name = "lot.lod.block.material-wear.\(condition)"
        let count = condition == .distressed ? 3 : 2
        for index in 0..<count {
            let x = CGFloat(index - (count - 1) / 2) * 7
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x - 3, y: -9))
            path.addLine(to: CGPoint(x: x, y: -12))
            path.addLine(to: CGPoint(x: x + 3, y: -10))
            let crack = SKShapeNode(path: path)
            crack.strokeColor = style.palette.mapEarthDark.withAlphaComponent(
                condition == .distressed ? 0.68 : 0.42
            )
            crack.lineWidth = condition == .distressed ? 1.15 : 0.75
            crack.lineCap = .round
            wear.addChild(crack)
        }
        node.addChild(wear)
    }

    private func addResidential(
        _ tile: CityTile,
        variant: Int,
        city: SKNode,
        neighborhood: SKNode,
        block: SKNode
    ) {
        let base = style.palette.residential[variant]
        switch variant {
        case 0:
            addPrism(width: 36, depth: 19, height: 24 + levelHeight(tile, step: 5), base: base,
                     roof: style.palette.roofWarm, at: CGPoint(x: -2, y: 1), to: city)
            addGable(width: 33, height: 10, at: CGPoint(x: -2, y: 26 + levelHeight(tile, step: 5)),
                     color: style.palette.roofWarm, to: city)
            addWindowGrid(columns: 2, rows: 2, width: 30, height: 20, origin: CGPoint(x: -2, y: 7),
                          color: style.palette.warmWindow, to: neighborhood)
            addDoor(at: CGPoint(x: 6, y: 7), color: style.palette.roofDark, to: neighborhood)
            addTree(at: CGPoint(x: -23, y: 3), scale: 0.82, variant: variant, to: block)
            addFence(from: CGPoint(x: -27, y: -6), to: CGPoint(x: -8, y: -14), to: block)
        case 1:
            for index in 0..<2 {
                let x = CGFloat(index * 21 - 10)
                let height: CGFloat = 25 + CGFloat(index * 4) + levelHeight(tile, step: 5)
                let tint = base.blended(withFraction: CGFloat(index) * 0.09, of: .white) ?? base
                addPrism(width: 23, depth: 15, height: height, base: tint,
                         roof: style.palette.roofDark, at: CGPoint(x: x, y: CGFloat(index) * 1.5), to: city)
                addWindowGrid(columns: 1, rows: 2, width: 18, height: height - 4,
                              origin: CGPoint(x: x, y: 7), color: style.palette.warmWindow, to: neighborhood)
                addDoor(at: CGPoint(x: x + 4, y: 5), color: style.palette.roofWarm, to: neighborhood)
            }
            addHedge(at: CGPoint(x: -24, y: -4), count: 3, to: block)
            addHedge(at: CGPoint(x: 21, y: 3), count: 2, to: block)
        default:
            let height: CGFloat = 39 + levelHeight(tile, step: 8)
            addPrism(width: 39, depth: 21, height: height, base: base,
                     roof: style.palette.roofDark, at: CGPoint(x: 0, y: 1), to: city)
            addWindowGrid(columns: 3, rows: max(2, Int(height / 12)), width: 34, height: height - 5,
                          origin: CGPoint(x: 0, y: 7), color: style.palette.warmWindow, to: neighborhood)
            for floor in 0..<3 {
                let balcony = SKShapeNode(rectOf: CGSize(width: 21, height: 1.2), cornerRadius: 0.4)
                balcony.fillColor = style.palette.concreteLight
                balcony.strokeColor = .clear
                balcony.position = CGPoint(x: -6, y: 13 + CGFloat(floor) * 10)
                balcony.zPosition = 8
                neighborhood.addChild(balcony)
            }
            addRoofVent(at: CGPoint(x: 7, y: height + 5), to: block)
            addTree(at: CGPoint(x: -24, y: -2), scale: 0.72, variant: variant, to: block)
        }
    }

    private func addCommercial(
        _ tile: CityTile,
        variant: Int,
        city: SKNode,
        neighborhood: SKNode,
        block: SKNode
    ) {
        let base = style.palette.commercial[variant]
        switch variant {
        case 0:
            let height: CGFloat = 25 + levelHeight(tile, step: 7)
            addPrism(width: 47, depth: 23, height: height, base: base,
                     roof: style.palette.roofDark, at: CGPoint(x: 0, y: 1), to: city)
            addStorefront(width: 35, at: CGPoint(x: 5, y: 8), accent: .systemPink, to: neighborhood)
            addAwning(width: 35, at: CGPoint(x: 5, y: 15), color: .systemPink, to: neighborhood)
            addRoofVent(at: CGPoint(x: -7, y: height + 5), to: block)
            addPlanters(at: [CGPoint(x: -21, y: -2), CGPoint(x: 22, y: 2)], to: block)
        case 1:
            let height: CGFloat = 45 + levelHeight(tile, step: 10)
            addPrism(width: 34, depth: 19, height: height, base: base,
                     roof: style.palette.glass.blended(withFraction: 0.3, of: .white) ?? style.palette.glass,
                     at: CGPoint(x: 0, y: 0), to: city)
            for floor in 0..<max(3, Int(height / 10)) {
                let band = SKShapeNode(rectOf: CGSize(width: 25, height: 3.2), cornerRadius: 0.7)
                band.fillColor = style.palette.glass
                band.strokeColor = NSColor.white.withAlphaComponent(0.12)
                band.position = CGPoint(x: 3, y: 8 + CGFloat(floor) * 9)
                band.zPosition = 7
                neighborhood.addChild(band)
            }
            addRoofEquipment(at: CGPoint(x: 0, y: height + 4), to: block)
            addPlanters(at: [CGPoint(x: -21, y: 1), CGPoint(x: 19, y: -1)], to: block)
        default:
            addPrism(width: 45, depth: 22, height: 21 + levelHeight(tile, step: 6), base: base,
                     roof: style.palette.roofWarm, at: CGPoint(x: -2, y: 0), to: city)
            let canopy = SKShapeNode(path: style.diamondPath(width: 38, height: 12))
            canopy.fillColor = NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.23, alpha: 1)
            canopy.strokeColor = NSColor.white.withAlphaComponent(0.25)
            canopy.position = CGPoint(x: 5, y: 16)
            canopy.zPosition = 9
            neighborhood.addChild(canopy)
            addStorefront(width: 29, at: CGPoint(x: 3, y: 7), accent: style.palette.glass, to: neighborhood)
            addCrates(at: CGPoint(x: -22, y: -3), to: block)
            addPlanters(at: [CGPoint(x: 23, y: 2)], to: block)
        }
    }

    private func addIndustrial(
        _ tile: CityTile,
        variant: Int,
        city: SKNode,
        neighborhood: SKNode,
        block: SKNode
    ) {
        let base = style.palette.industrial[variant]
        switch variant {
        case 0:
            let height: CGFloat = 22 + levelHeight(tile, step: 6)
            addPrism(width: 47, depth: 24, height: height, base: base,
                     roof: style.palette.roofDark, at: CGPoint(x: -2, y: 0), to: city)
            for index in 0..<3 {
                let tooth = SKShapeNode(path: style.polygonPath([
                    CGPoint(x: -16 + CGFloat(index) * 12, y: height + 1),
                    CGPoint(x: -11 + CGFloat(index) * 12, y: height + 9),
                    CGPoint(x: -5 + CGFloat(index) * 12, y: height + 1)
                ]))
                tooth.fillColor = style.palette.concreteLight
                tooth.strokeColor = style.palette.roofDark
                tooth.lineWidth = 0.8
                tooth.zPosition = 7
                city.addChild(tooth)
            }
            addLoadingDoors(count: 2, at: CGPoint(x: 5, y: 7), to: neighborhood)
            addStack(at: CGPoint(x: 17, y: height + 7), height: 22, to: city)
            addCrates(at: CGPoint(x: -24, y: -4), to: block)
        case 1:
            let height: CGFloat = 18 + levelHeight(tile, step: 5)
            addPrism(width: 52, depth: 25, height: height, base: base,
                     roof: style.palette.concreteLight, at: CGPoint(x: 0, y: 0), to: city)
            addLoadingDoors(count: 3, at: CGPoint(x: 5, y: 6), to: neighborhood)
            addTank(at: CGPoint(x: -20, y: 7), scale: 0.75, to: city)
            addTank(at: CGPoint(x: 21, y: 5), scale: 0.58, to: city)
            addPipes(at: CGPoint(x: 0, y: height + 5), to: block)
        default:
            let height: CGFloat = 28 + levelHeight(tile, step: 7)
            addPrism(width: 36, depth: 21, height: height, base: base,
                     roof: style.palette.roofDark, at: CGPoint(x: -7, y: 0), to: city)
            addPrism(width: 19, depth: 14, height: 18, base: style.palette.concrete,
                     roof: style.palette.concreteLight, at: CGPoint(x: 18, y: -2), to: city)
            addLoadingDoors(count: 1, at: CGPoint(x: -3, y: 8), to: neighborhood)
            addStack(at: CGPoint(x: 4, y: height + 7), height: 18, to: city)
            addRoofEquipment(at: CGPoint(x: 18, y: 20), to: block)
            addCrates(at: CGPoint(x: 23, y: -6), to: block)
        }
    }

    private func addPark(
        _ tile: CityTile,
        variant: Int,
        city: SKNode,
        neighborhood: SKNode,
        block: SKNode
    ) {
        switch variant {
        case 0:
            let positions = [CGPoint(x: -18, y: 1), CGPoint(x: -4, y: 8), CGPoint(x: 14, y: 2), CGPoint(x: 23, y: -5)]
            for (index, position) in positions.enumerated() {
                addTree(at: position, scale: 0.82 + CGFloat(index % 2) * 0.13, variant: index, to: city)
            }
            addBench(at: CGPoint(x: 2, y: -5), rotation: -0.2, to: neighborhood)
            addLamp(at: CGPoint(x: -9, y: -5), to: block)
        case 1:
            let pond = SKShapeNode(ellipseOf: CGSize(width: 35, height: 15))
            pond.fillColor = NSColor(calibratedRed: 0.20, green: 0.61, blue: 0.69, alpha: 0.9)
            pond.strokeColor = NSColor(calibratedRed: 0.64, green: 0.87, blue: 0.88, alpha: 0.7)
            pond.lineWidth = 1.4
            pond.position = CGPoint(x: 1, y: -1)
            pond.zPosition = 2
            city.addChild(pond)
            addTree(at: CGPoint(x: -22, y: 3), scale: 0.9, variant: 1, to: city)
            addTree(at: CGPoint(x: 20, y: 4), scale: 0.78, variant: 2, to: city)
            for index in 0..<3 {
                let ripple = SKShapeNode(ellipseOf: CGSize(width: 5 + CGFloat(index) * 4, height: 1.7 + CGFloat(index)))
                ripple.strokeColor = NSColor.white.withAlphaComponent(0.38 - CGFloat(index) * 0.08)
                ripple.fillColor = .clear
                ripple.position = CGPoint(x: -3, y: -1)
                ripple.zPosition = 4
                neighborhood.addChild(ripple)
            }
            addBench(at: CGPoint(x: 9, y: 8), rotation: 0.2, to: block)
        default:
            let pavilion = SKShapeNode(path: style.diamondPath(width: 28, height: 14))
            pavilion.fillColor = style.palette.roofWarm
            pavilion.strokeColor = NSColor.white.withAlphaComponent(0.3)
            pavilion.position = CGPoint(x: -12, y: 14)
            pavilion.zPosition = 8
            city.addChild(pavilion)
            for x in [-20.0, -4.0] {
                let post = SKShapeNode(rectOf: CGSize(width: 2, height: 13))
                post.fillColor = style.palette.civicStone
                post.strokeColor = .clear
                post.position = CGPoint(x: x, y: 6)
                post.zPosition = 7
                city.addChild(post)
            }
            let playSurface = SKShapeNode(ellipseOf: CGSize(width: 27, height: 11))
            playSurface.fillColor = NSColor(calibratedRed: 0.30, green: 0.52, blue: 0.54, alpha: 0.65)
            playSurface.strokeColor = .clear
            playSurface.position = CGPoint(x: 15, y: -3)
            neighborhood.addChild(playSurface)
            addPlayFrame(at: CGPoint(x: 15, y: 4), to: neighborhood)
            addTree(at: CGPoint(x: 25, y: 5), scale: 0.72, variant: 0, to: city)
            addBench(at: CGPoint(x: -1, y: -7), rotation: -0.15, to: block)
        }
        addFlowerBed(at: CGPoint(x: -4 + CGFloat(variant * 4), y: -8), to: block)
        _ = tile
    }

    private func addCityHall(_ tile: CityTile, city: SKNode, neighborhood: SKNode, block: SKNode) {
        let height: CGFloat = 34 + levelHeight(tile, step: 7)
        addPrism(width: 48, depth: 25, height: height, base: style.palette.civicStone,
                 roof: style.palette.civicRoof, at: CGPoint(x: 0, y: 0), to: city)
        addPrism(width: 25, depth: 15, height: 12, base: style.palette.civicStone,
                 roof: style.palette.civicRoof, at: CGPoint(x: 0, y: height + 2), shadow: false, to: city)

        let dome = SKShapeNode(ellipseOf: CGSize(width: 19, height: 12))
        dome.fillColor = style.palette.civicRoof
        dome.strokeColor = NSColor.white.withAlphaComponent(0.3)
        dome.position = CGPoint(x: 0, y: height + 17)
        dome.zPosition = 12
        city.addChild(dome)
        let spire = SKShapeNode(path: style.polygonPath([
            CGPoint(x: -2, y: height + 21), CGPoint(x: 0, y: height + 32), CGPoint(x: 2, y: height + 21)
        ]))
        spire.fillColor = NSColor(calibratedRed: 0.91, green: 0.72, blue: 0.23, alpha: 1)
        spire.strokeColor = .clear
        spire.zPosition = 13
        city.addChild(spire)

        for index in -2...2 {
            let column = SKShapeNode(rectOf: CGSize(width: 2.3, height: 18), cornerRadius: 0.4)
            column.fillColor = NSColor(calibratedWhite: 0.88, alpha: 1)
            column.strokeColor = style.palette.roofDark.withAlphaComponent(0.25)
            column.position = CGPoint(x: CGFloat(index) * 7, y: 11)
            column.zPosition = 9
            neighborhood.addChild(column)
        }
        addSteps(width: 34, at: CGPoint(x: 2, y: -5), to: neighborhood)
        addPlanters(at: [CGPoint(x: -25, y: 1), CGPoint(x: 25, y: 1)], to: block)
        addLamp(at: CGPoint(x: -19, y: -6), to: block)
        addLamp(at: CGPoint(x: 19, y: -6), to: block)
    }

    private func addPowerPlant(
        _ tile: CityTile,
        variant: Int,
        city: SKNode,
        neighborhood: SKNode,
        block: SKNode
    ) {
        let base = style.palette.industrial[variant]
        let height: CGFloat = 24 + levelHeight(tile, step: 5)
        addPrism(width: 44, depth: 24, height: height, base: base,
                 roof: style.palette.roofDark, at: CGPoint(x: -5, y: 0), to: city)
        addCoolingTower(at: CGPoint(x: 18, y: 13), scale: 0.78, to: city)
        addStack(at: CGPoint(x: -18, y: height + 9), height: 28, to: city)
        if variant == 2 { addStack(at: CGPoint(x: -7, y: height + 7), height: 22, to: city) }
        addPipes(at: CGPoint(x: -1, y: height + 5), to: neighborhood)
        addTransformerBank(at: CGPoint(x: 20, y: -5), to: block)
    }

    private func addWaterTower(
        _ tile: CityTile,
        variant: Int,
        city: SKNode,
        neighborhood: SKNode,
        block: SKNode
    ) {
        addPrism(width: 27, depth: 17, height: 15, base: style.palette.concrete,
                 roof: style.palette.roofDark, at: CGPoint(x: -15, y: -1), to: city)
        let towerHeight: CGFloat = 45 + levelHeight(tile, step: 5)
        for x in [-8.0, 8.0] {
            let leg = SKShapeNode(rectOf: CGSize(width: 2.5, height: towerHeight - 10), cornerRadius: 0.5)
            leg.fillColor = style.palette.concreteLight
            leg.strokeColor = style.palette.roofDark.withAlphaComponent(0.35)
            leg.position = CGPoint(x: x + 8, y: towerHeight / 2 - 4)
            leg.zPosition = 6
            city.addChild(leg)
        }
        let tank = SKShapeNode(ellipseOf: CGSize(width: 34 + CGFloat(variant) * 2, height: 19))
        tank.fillColor = NSColor(calibratedRed: 0.45, green: 0.76, blue: 0.82, alpha: 1)
        tank.strokeColor = NSColor.white.withAlphaComponent(0.38)
        tank.lineWidth = 1.2
        tank.position = CGPoint(x: 8, y: towerHeight)
        tank.zPosition = 9
        city.addChild(tank)
        let cap = SKShapeNode(path: style.polygonPath([
            CGPoint(x: -2, y: towerHeight + 8), CGPoint(x: 8, y: towerHeight + 15), CGPoint(x: 18, y: towerHeight + 8)
        ]))
        cap.fillColor = style.palette.roofDark
        cap.strokeColor = .clear
        cap.zPosition = 10
        city.addChild(cap)
        addPipeBrace(at: CGPoint(x: 8, y: 22), to: neighborhood)
        addFence(from: CGPoint(x: 12, y: -8), to: CGPoint(x: 28, y: -1), to: block)
    }

    private func addFireStation(
        _ tile: CityTile,
        variant: Int,
        city: SKNode,
        neighborhood: SKNode,
        block: SKNode
    ) {
        let height: CGFloat = 24 + levelHeight(tile, step: 5)
        let red = NSColor(calibratedRed: 0.69, green: 0.20, blue: 0.16, alpha: 1)
        addPrism(width: 48, depth: 23, height: height, base: red,
                 roof: style.palette.roofDark, at: CGPoint(x: 0, y: 0), to: city)
        addPrism(width: 15, depth: 12, height: 15 + CGFloat(variant) * 3, base: red,
                 roof: style.palette.roofWarm, at: CGPoint(x: -18, y: height - 1), shadow: false, to: city)
        addLoadingDoors(count: 2, at: CGPoint(x: 7, y: 8), color: NSColor(calibratedWhite: 0.82, alpha: 1), to: neighborhood)
        let beacon = SKShapeNode(circleOfRadius: 2.4)
        beacon.fillColor = NSColor.systemRed
        beacon.strokeColor = NSColor.white.withAlphaComponent(0.5)
        beacon.position = CGPoint(x: -18, y: height + 17 + CGFloat(variant) * 3)
        beacon.zPosition = 14
        city.addChild(beacon)
        addHydrant(at: CGPoint(x: 25, y: -4), to: block)
        addSteps(width: 13, at: CGPoint(x: -14, y: -5), to: block)
    }

    private func addPoliceStation(
        _ tile: CityTile,
        variant: Int,
        city: SKNode,
        neighborhood: SKNode,
        block: SKNode
    ) {
        let height: CGFloat = 27 + levelHeight(tile, step: 6)
        let blue = NSColor(calibratedRed: 0.25, green: 0.38, blue: 0.62, alpha: 1)
        addPrism(width: 43, depth: 22, height: height, base: style.palette.civicStone,
                 roof: style.palette.roofDark, at: CGPoint(x: -2, y: 0), to: city)
        addPrism(width: 17, depth: 13, height: 16 + CGFloat(variant) * 2, base: blue,
                 roof: style.palette.concreteLight, at: CGPoint(x: 17, y: height - 3), shadow: false, to: city)
        let band = SKShapeNode(rectOf: CGSize(width: 35, height: 4), cornerRadius: 0.5)
        band.fillColor = blue
        band.strokeColor = .clear
        band.position = CGPoint(x: 2, y: 15)
        band.zPosition = 8
        neighborhood.addChild(band)
        addWindowGrid(columns: 3, rows: 2, width: 34, height: height - 6,
                      origin: CGPoint(x: 0, y: 7), color: style.palette.glass, to: neighborhood)
        addAntenna(at: CGPoint(x: 17, y: height + 16 + CGFloat(variant) * 2), to: city)
        addBollards(at: CGPoint(x: -18, y: -6), count: 3, to: block)
    }

    private func addSchool(
        _ tile: CityTile,
        variant: Int,
        city: SKNode,
        neighborhood: SKNode,
        block: SKNode
    ) {
        let height: CGFloat = 24 + levelHeight(tile, step: 5)
        let brick = NSColor(calibratedRed: 0.66, green: 0.39, blue: 0.25, alpha: 1)
        addPrism(width: 51, depth: 24, height: height, base: brick,
                 roof: style.palette.roofDark, at: CGPoint(x: 0, y: 0), to: city)
        addPrism(width: 21, depth: 15, height: 13 + CGFloat(variant) * 2, base: brick,
                 roof: style.palette.roofWarm, at: CGPoint(x: 0, y: height - 1), shadow: false, to: city)
        addWindowGrid(columns: 4, rows: 2, width: 43, height: height - 5,
                      origin: CGPoint(x: 0, y: 7), color: style.palette.warmWindow, to: neighborhood)
        addDoor(at: CGPoint(x: 0, y: 7), color: style.palette.civicRoof, to: neighborhood)
        addFlagpole(at: CGPoint(x: 23, y: 15), to: city)
        addTree(at: CGPoint(x: -25, y: 1), scale: 0.67, variant: variant, to: block)
        addBollards(at: CGPoint(x: 16, y: -7), count: 2, to: block)
    }

    // MARK: - Building primitives

    private func addPrism(
        width: CGFloat,
        depth: CGFloat,
        height: CGFloat,
        base: NSColor,
        roof: NSColor,
        at origin: CGPoint,
        shadow: Bool = true,
        to node: SKNode
    ) {
        if shadow {
            let shadowNode = SKShapeNode(ellipseOf: CGSize(width: width * 1.28, height: max(8, depth * 0.72)))
            shadowNode.fillColor = style.palette.shadow
            shadowNode.strokeColor = .clear
            shadowNode.position = CGPoint(x: origin.x + 7, y: origin.y - 5)
            shadowNode.zPosition = 0
            node.addChild(shadowNode)
        }

        let left = SKShapeNode(path: style.polygonPath([
            CGPoint(x: origin.x - width / 2, y: origin.y),
            CGPoint(x: origin.x, y: origin.y - depth / 2),
            CGPoint(x: origin.x, y: origin.y + height - depth / 2),
            CGPoint(x: origin.x - width / 2, y: origin.y + height)
        ]))
        left.fillColor = base.blended(withFraction: 0.31, of: .black) ?? base
        left.strokeColor = NSColor.black.withAlphaComponent(0.28)
        left.lineWidth = 0.8
        left.zPosition = 2

        let right = SKShapeNode(path: style.polygonPath([
            CGPoint(x: origin.x, y: origin.y - depth / 2),
            CGPoint(x: origin.x + width / 2, y: origin.y),
            CGPoint(x: origin.x + width / 2, y: origin.y + height),
            CGPoint(x: origin.x, y: origin.y + height - depth / 2)
        ]))
        right.fillColor = base.blended(withFraction: 0.14, of: .black) ?? base
        right.strokeColor = NSColor.black.withAlphaComponent(0.28)
        right.lineWidth = 0.8
        right.zPosition = 3

        let roofNode = SKShapeNode(path: style.diamondPath(width: width, height: depth))
        roofNode.fillColor = roof
        roofNode.strokeColor = NSColor.white.withAlphaComponent(0.24)
        roofNode.lineWidth = 0.9
        roofNode.position = CGPoint(x: origin.x, y: origin.y + height)
        roofNode.zPosition = 4
        node.addChild(left)
        node.addChild(right)
        node.addChild(roofNode)
    }

    private func addGable(width: CGFloat, height: CGFloat, at origin: CGPoint, color: NSColor, to node: SKNode) {
        let gable = SKShapeNode(path: style.polygonPath([
            CGPoint(x: origin.x - width / 2, y: origin.y),
            CGPoint(x: origin.x, y: origin.y + height),
            CGPoint(x: origin.x + width / 2, y: origin.y)
        ]))
        gable.fillColor = color
        gable.strokeColor = NSColor.white.withAlphaComponent(0.2)
        gable.lineWidth = 0.8
        gable.zPosition = 7
        node.addChild(gable)
    }

    private func addWindowGrid(
        columns: Int,
        rows: Int,
        width: CGFloat,
        height: CGFloat,
        origin: CGPoint,
        color: NSColor,
        to node: SKNode
    ) {
        guard columns > 0, rows > 0 else { return }
        let xStep = width / CGFloat(columns)
        let yStep = height / CGFloat(rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let window = SKShapeNode(rectOf: CGSize(
                    width: max(3, min(6, xStep * 0.42)),
                    height: max(2.5, min(4.2, yStep * 0.36))
                ), cornerRadius: 0.55)
                window.fillColor = color
                window.strokeColor = NSColor.white.withAlphaComponent(0.13)
                window.lineWidth = 0.5
                window.position = CGPoint(
                    x: origin.x - width / 2 + xStep * (CGFloat(column) + 0.5),
                    y: origin.y + yStep * (CGFloat(row) + 0.45)
                )
                window.zPosition = 8
                node.addChild(window)
            }
        }
    }

    private func addDoor(at position: CGPoint, color: NSColor, to node: SKNode) {
        let door = SKShapeNode(rectOf: CGSize(width: 7, height: 10), cornerRadius: 0.7)
        door.fillColor = color
        door.strokeColor = NSColor.white.withAlphaComponent(0.22)
        door.lineWidth = 0.7
        door.position = position
        door.zPosition = 10
        node.addChild(door)
    }

    private func addStorefront(width: CGFloat, at position: CGPoint, accent: NSColor, to node: SKNode) {
        let glass = SKShapeNode(rectOf: CGSize(width: width, height: 10), cornerRadius: 1)
        glass.fillColor = style.palette.glass
        glass.strokeColor = accent.withAlphaComponent(0.75)
        glass.lineWidth = 1.5
        glass.position = position
        glass.zPosition = 8
        node.addChild(glass)
        for divider in [-0.25, 0.25] {
            let mullion = SKShapeNode(rectOf: CGSize(width: 1, height: 9))
            mullion.fillColor = style.palette.roofDark.withAlphaComponent(0.7)
            mullion.strokeColor = .clear
            mullion.position = CGPoint(x: position.x + width * divider, y: position.y)
            mullion.zPosition = 9
            node.addChild(mullion)
        }
    }

    private func addAwning(width: CGFloat, at position: CGPoint, color: NSColor, to node: SKNode) {
        let awning = SKShapeNode(path: style.polygonPath([
            CGPoint(x: position.x - width / 2, y: position.y + 2),
            CGPoint(x: position.x + width / 2, y: position.y + 2),
            CGPoint(x: position.x + width / 2 - 3, y: position.y - 3),
            CGPoint(x: position.x - width / 2 + 3, y: position.y - 3)
        ]))
        awning.fillColor = color
        awning.strokeColor = NSColor.white.withAlphaComponent(0.22)
        awning.lineWidth = 0.7
        awning.zPosition = 11
        node.addChild(awning)
    }

    private func addLoadingDoors(
        count: Int,
        at position: CGPoint,
        color: NSColor = NSColor(calibratedWhite: 0.20, alpha: 1),
        to node: SKNode
    ) {
        for index in 0..<count {
            let door = SKShapeNode(rectOf: CGSize(width: 10, height: 10), cornerRadius: 0.7)
            door.fillColor = color
            door.strokeColor = NSColor.white.withAlphaComponent(0.24)
            door.lineWidth = 0.8
            door.position = CGPoint(x: position.x + CGFloat(index) * 12 - CGFloat(count - 1) * 6, y: position.y)
            door.zPosition = 9
            node.addChild(door)
            for slat in 0..<3 {
                let line = SKShapeNode(rectOf: CGSize(width: 8, height: 0.6))
                line.fillColor = NSColor.white.withAlphaComponent(0.16)
                line.strokeColor = .clear
                line.position = CGPoint(x: door.position.x, y: door.position.y - 3 + CGFloat(slat) * 3)
                line.zPosition = 10
                node.addChild(line)
            }
        }
    }

    private func addTree(at position: CGPoint, scale: CGFloat, variant: Int, to node: SKNode) {
        let tree = SKNode()
        tree.position = position
        tree.setScale(scale)
        tree.zPosition = 12 + position.y * 0.02
        let trunk = SKShapeNode(rectOf: CGSize(width: 3, height: 10), cornerRadius: 1)
        trunk.fillColor = style.palette.trunk
        trunk.strokeColor = .clear
        trunk.position.y = 5
        tree.addChild(trunk)
        let crown = SKShapeNode(ellipseOf: CGSize(width: 14, height: 13))
        crown.fillColor = style.palette.foliage[variant % style.palette.foliage.count]
        crown.strokeColor = NSColor.white.withAlphaComponent(0.12)
        crown.lineWidth = 0.8
        crown.position = CGPoint(x: 0, y: 13)
        crown.zPosition = 2
        tree.addChild(crown)
        let highlight = SKShapeNode(ellipseOf: CGSize(width: 6, height: 5))
        highlight.fillColor = NSColor.white.withAlphaComponent(0.12)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -3, y: 16)
        highlight.zPosition = 3
        tree.addChild(highlight)
        node.addChild(tree)
    }

    private func addHedge(at position: CGPoint, count: Int, to node: SKNode) {
        for index in 0..<count {
            let hedge = SKShapeNode(ellipseOf: CGSize(width: 7, height: 5))
            hedge.fillColor = style.palette.foliage[1]
            hedge.strokeColor = NSColor.white.withAlphaComponent(0.1)
            hedge.position = CGPoint(x: position.x + CGFloat(index) * 5, y: position.y + CGFloat(index) * 1.6)
            hedge.zPosition = 9
            node.addChild(hedge)
        }
    }

    private func addPlanters(at positions: [CGPoint], to node: SKNode) {
        for (index, position) in positions.enumerated() {
            let planter = SKShapeNode(ellipseOf: CGSize(width: 8, height: 4))
            planter.fillColor = style.palette.soil
            planter.strokeColor = style.palette.concreteLight.withAlphaComponent(0.55)
            planter.position = position
            planter.zPosition = 10
            node.addChild(planter)
            let shrub = SKShapeNode(circleOfRadius: 2.6)
            shrub.fillColor = style.palette.foliage[index % style.palette.foliage.count]
            shrub.strokeColor = .clear
            shrub.position.y = 2
            planter.addChild(shrub)
        }
    }

    private func addRoofVent(at position: CGPoint, to node: SKNode) {
        let vent = SKShapeNode(ellipseOf: CGSize(width: 7, height: 4))
        vent.fillColor = style.palette.concreteLight
        vent.strokeColor = style.palette.roofDark.withAlphaComponent(0.55)
        vent.position = position
        vent.zPosition = 11
        node.addChild(vent)
    }

    private func addRoofEquipment(at position: CGPoint, to node: SKNode) {
        let unit = SKShapeNode(rectOf: CGSize(width: 12, height: 6), cornerRadius: 1)
        unit.fillColor = style.palette.concrete
        unit.strokeColor = NSColor.white.withAlphaComponent(0.22)
        unit.position = position
        unit.zPosition = 11
        node.addChild(unit)
        for x in [-3.0, 0.0, 3.0] {
            let grille = SKShapeNode(rectOf: CGSize(width: 0.7, height: 4.5))
            grille.fillColor = style.palette.roofDark.withAlphaComponent(0.55)
            grille.strokeColor = .clear
            grille.position = CGPoint(x: position.x + x, y: position.y)
            grille.zPosition = 12
            node.addChild(grille)
        }
    }

    private func addStack(at position: CGPoint, height: CGFloat, to node: SKNode) {
        let stack = SKShapeNode(path: style.polygonPath([
            CGPoint(x: position.x - 3.5, y: position.y - height / 2),
            CGPoint(x: position.x + 3.5, y: position.y - height / 2),
            CGPoint(x: position.x + 2.6, y: position.y + height / 2),
            CGPoint(x: position.x - 2.6, y: position.y + height / 2)
        ]))
        stack.fillColor = NSColor(calibratedRed: 0.34, green: 0.31, blue: 0.28, alpha: 1)
        stack.strokeColor = NSColor.white.withAlphaComponent(0.18)
        stack.lineWidth = 0.7
        stack.zPosition = 10
        node.addChild(stack)
        let collar = SKShapeNode(rectOf: CGSize(width: 8, height: 2))
        collar.fillColor = NSColor(calibratedRed: 0.73, green: 0.37, blue: 0.18, alpha: 1)
        collar.strokeColor = .clear
        collar.position = CGPoint(x: position.x, y: position.y + height / 2 - 4)
        collar.zPosition = 11
        node.addChild(collar)
    }

    private func addTank(at position: CGPoint, scale: CGFloat, to node: SKNode) {
        let tank = SKShapeNode(ellipseOf: CGSize(width: 19 * scale, height: 11 * scale))
        tank.fillColor = style.palette.concreteLight
        tank.strokeColor = style.palette.roofDark.withAlphaComponent(0.45)
        tank.lineWidth = 1
        tank.position = position
        tank.zPosition = 8
        node.addChild(tank)
        let body = SKShapeNode(rectOf: CGSize(width: 18 * scale, height: 10 * scale))
        body.fillColor = style.palette.concrete
        body.strokeColor = .clear
        body.position = CGPoint(x: position.x, y: position.y - 4 * scale)
        body.zPosition = 7
        node.addChild(body)
    }

    private func addCoolingTower(at position: CGPoint, scale: CGFloat, to node: SKNode) {
        let tower = SKShapeNode(path: style.polygonPath([
            CGPoint(x: position.x - 10 * scale, y: position.y - 16 * scale),
            CGPoint(x: position.x + 10 * scale, y: position.y - 16 * scale),
            CGPoint(x: position.x + 6 * scale, y: position.y + 15 * scale),
            CGPoint(x: position.x - 6 * scale, y: position.y + 15 * scale)
        ]))
        tower.fillColor = style.palette.concrete
        tower.strokeColor = NSColor.white.withAlphaComponent(0.24)
        tower.lineWidth = 0.8
        tower.zPosition = 8
        node.addChild(tower)
        let lip = SKShapeNode(ellipseOf: CGSize(width: 13 * scale, height: 5 * scale))
        lip.fillColor = style.palette.roofDark
        lip.strokeColor = .clear
        lip.position = CGPoint(x: position.x, y: position.y + 15 * scale)
        lip.zPosition = 9
        node.addChild(lip)
    }

    private func addPipes(at position: CGPoint, to node: SKNode) {
        for index in 0..<3 {
            let pipe = SKShapeNode(rectOf: CGSize(width: 3, height: 9 + CGFloat(index) * 2), cornerRadius: 1)
            pipe.fillColor = style.palette.concreteLight
            pipe.strokeColor = style.palette.roofDark.withAlphaComponent(0.35)
            pipe.position = CGPoint(x: position.x + CGFloat(index * 6 - 6), y: position.y + CGFloat(index))
            pipe.zPosition = 11
            node.addChild(pipe)
        }
    }

    private func addCrates(at position: CGPoint, to node: SKNode) {
        for index in 0..<3 {
            let crate = SKShapeNode(rectOf: CGSize(width: 6, height: 5), cornerRadius: 0.4)
            crate.fillColor = NSColor(calibratedRed: 0.47, green: 0.31, blue: 0.16, alpha: 1)
            crate.strokeColor = NSColor.black.withAlphaComponent(0.28)
            crate.position = CGPoint(x: position.x + CGFloat(index % 2) * 6, y: position.y + CGFloat(index / 2) * 5)
            crate.zPosition = 11 + CGFloat(index)
            node.addChild(crate)
        }
    }

    private func addFence(from start: CGPoint, to end: CGPoint, to node: SKNode) {
        let rail = SKShapeNode(path: WorldGeometryCache.line(from: start, to: end))
        rail.strokeColor = style.palette.concreteLight.withAlphaComponent(0.72)
        rail.lineWidth = 1
        rail.zPosition = 10
        node.addChild(rail)
        for fraction in stride(from: CGFloat(0), through: 1, by: 0.25) {
            let position = CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
            let post = SKShapeNode(rectOf: CGSize(width: 1, height: 5))
            post.fillColor = style.palette.concreteLight
            post.strokeColor = .clear
            post.position = CGPoint(x: position.x, y: position.y + 2)
            post.zPosition = 11
            node.addChild(post)
        }
    }

    private func addBench(at position: CGPoint, rotation: CGFloat, to node: SKNode) {
        let bench = SKNode()
        bench.position = position
        bench.zRotation = rotation
        bench.zPosition = 11
        let seat = SKShapeNode(rectOf: CGSize(width: 12, height: 2.5), cornerRadius: 0.6)
        seat.fillColor = NSColor(calibratedRed: 0.43, green: 0.27, blue: 0.13, alpha: 1)
        seat.strokeColor = NSColor.white.withAlphaComponent(0.15)
        bench.addChild(seat)
        for x in [-4.0, 4.0] {
            let leg = SKShapeNode(rectOf: CGSize(width: 1.2, height: 4))
            leg.fillColor = style.palette.roofDark
            leg.strokeColor = .clear
            leg.position = CGPoint(x: x, y: -2)
            bench.addChild(leg)
        }
        node.addChild(bench)
    }

    private func addLamp(at position: CGPoint, to node: SKNode) {
        let post = SKShapeNode(rectOf: CGSize(width: 1.5, height: 11), cornerRadius: 0.5)
        post.fillColor = style.palette.roofDark
        post.strokeColor = .clear
        post.position = CGPoint(x: position.x, y: position.y + 5)
        post.zPosition = 12
        node.addChild(post)
        let lamp = SKShapeNode(circleOfRadius: 2.2)
        lamp.fillColor = style.palette.warmWindow
        lamp.strokeColor = NSColor.white.withAlphaComponent(0.35)
        lamp.position = CGPoint(x: position.x, y: position.y + 11)
        lamp.zPosition = 13
        node.addChild(lamp)
    }

    private func addFlowerBed(at position: CGPoint, to node: SKNode) {
        let bed = SKShapeNode(ellipseOf: CGSize(width: 18, height: 6))
        bed.fillColor = style.palette.soil
        bed.strokeColor = style.palette.parkPath.withAlphaComponent(0.65)
        bed.position = position
        bed.zPosition = 6
        node.addChild(bed)
        let colors: [NSColor] = [.systemYellow, .systemPink, .systemPurple]
        for index in 0..<5 {
            let flower = SKShapeNode(circleOfRadius: 1.1)
            flower.fillColor = colors[index % colors.count]
            flower.strokeColor = .clear
            flower.position = CGPoint(x: position.x + CGFloat(index * 3 - 6), y: position.y + CGFloat(index % 2))
            flower.zPosition = 7
            node.addChild(flower)
        }
    }

    private func addPlayFrame(at position: CGPoint, to node: SKNode) {
        for x in [-6.0, 6.0] {
            let support = SKShapeNode(rectOf: CGSize(width: 2, height: 13), cornerRadius: 0.5)
            support.fillColor = NSColor.systemOrange
            support.strokeColor = .clear
            support.position = CGPoint(x: position.x + x, y: position.y + 5)
            support.zPosition = 8
            node.addChild(support)
        }
        let crossbar = SKShapeNode(rectOf: CGSize(width: 15, height: 2), cornerRadius: 0.5)
        crossbar.fillColor = NSColor.systemOrange
        crossbar.strokeColor = .clear
        crossbar.position = CGPoint(x: position.x, y: position.y + 12)
        crossbar.zPosition = 9
        node.addChild(crossbar)
    }

    private func addSteps(width: CGFloat, at position: CGPoint, to node: SKNode) {
        for index in 0..<3 {
            let step = SKShapeNode(rectOf: CGSize(width: width + CGFloat(index) * 4, height: 2.4), cornerRadius: 0.4)
            step.fillColor = style.palette.concreteLight.blended(withFraction: CGFloat(index) * 0.07, of: .black)
                ?? style.palette.concreteLight
            step.strokeColor = .clear
            step.position = CGPoint(x: position.x, y: position.y - CGFloat(index) * 1.7)
            step.zPosition = 10 - CGFloat(index)
            node.addChild(step)
        }
    }

    private func addHydrant(at position: CGPoint, to node: SKNode) {
        let hydrant = SKShapeNode(rectOf: CGSize(width: 4, height: 5), cornerRadius: 1)
        hydrant.fillColor = .systemRed
        hydrant.strokeColor = NSColor.white.withAlphaComponent(0.24)
        hydrant.position = position
        hydrant.zPosition = 12
        node.addChild(hydrant)
    }

    private func addAntenna(at position: CGPoint, to node: SKNode) {
        let mast = SKShapeNode(rectOf: CGSize(width: 1.2, height: 18))
        mast.fillColor = style.palette.concreteLight
        mast.strokeColor = .clear
        mast.position = CGPoint(x: position.x, y: position.y - 8)
        mast.zPosition = 13
        node.addChild(mast)
        for index in 0..<2 {
            let bar = SKShapeNode(rectOf: CGSize(width: 9 - CGFloat(index) * 3, height: 1))
            bar.fillColor = style.palette.concreteLight
            bar.strokeColor = .clear
            bar.position = CGPoint(x: position.x, y: position.y - CGFloat(index) * 5)
            bar.zPosition = 14
            node.addChild(bar)
        }
    }

    private func addFlagpole(at position: CGPoint, to node: SKNode) {
        let pole = SKShapeNode(rectOf: CGSize(width: 1.2, height: 23))
        pole.fillColor = NSColor(calibratedWhite: 0.82, alpha: 1)
        pole.strokeColor = .clear
        pole.position = position
        pole.zPosition = 13
        node.addChild(pole)
        let flag = SKShapeNode(path: style.polygonPath([
            CGPoint(x: position.x, y: position.y + 11),
            CGPoint(x: position.x + 11, y: position.y + 7),
            CGPoint(x: position.x, y: position.y + 3)
        ]))
        flag.fillColor = NSColor(calibratedRed: 0.22, green: 0.58, blue: 0.59, alpha: 1)
        flag.strokeColor = .clear
        flag.zPosition = 14
        node.addChild(flag)
    }

    private func addBollards(at position: CGPoint, count: Int, to node: SKNode) {
        for index in 0..<count {
            let bollard = SKShapeNode(rectOf: CGSize(width: 2, height: 5), cornerRadius: 0.7)
            bollard.fillColor = style.palette.roofDark
            bollard.strokeColor = NSColor.white.withAlphaComponent(0.18)
            bollard.position = CGPoint(x: position.x + CGFloat(index) * 6, y: position.y + CGFloat(index) * 1.8)
            bollard.zPosition = 12
            node.addChild(bollard)
        }
    }

    private func addTransformerBank(at position: CGPoint, to node: SKNode) {
        for index in 0..<3 {
            let transformer = SKShapeNode(rectOf: CGSize(width: 6, height: 8), cornerRadius: 1)
            transformer.fillColor = NSColor(calibratedRed: 0.29, green: 0.38, blue: 0.31, alpha: 1)
            transformer.strokeColor = NSColor.white.withAlphaComponent(0.16)
            transformer.position = CGPoint(x: position.x + CGFloat(index) * 7, y: position.y + CGFloat(index) * 2)
            transformer.zPosition = 12
            node.addChild(transformer)
        }
    }

    private func addPipeBrace(at position: CGPoint, to node: SKNode) {
        let horizontal = SKShapeNode(rectOf: CGSize(width: 19, height: 1.5))
        horizontal.fillColor = style.palette.concreteLight
        horizontal.strokeColor = .clear
        horizontal.position = position
        horizontal.zPosition = 10
        node.addChild(horizontal)
        for x in [-7.0, 7.0] {
            let brace = SKShapeNode(rectOf: CGSize(width: 1.2, height: 13))
            brace.fillColor = style.palette.concreteLight
            brace.strokeColor = .clear
            brace.position = CGPoint(x: position.x + x, y: position.y)
            brace.zPosition = 10
            node.addChild(brace)
        }
    }

    private func levelHeight(_ tile: CityTile, step: CGFloat) -> CGFloat {
        CGFloat(max(0, tile.level - 1)) * step
    }
}
