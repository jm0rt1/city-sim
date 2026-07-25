import AppKit
import SpriteKit

/// Truth-safe physical context for completed lots. Every cue is derived only
/// from authoritative tile kind, coordinate, construction state, and adjacent
/// road sockets. It never implies occupancy, trips, service, prosperity, or
/// another gameplay outcome.
@MainActor
final class LotContextRenderer {
    enum PlacementRole: String, Sendable {
        case plantingBed = "planting-bed"
        case parkingBay = "parking-bay"
        case serviceYard = "service-yard"
        case civicForecourt = "civic-forecourt"
        case parkTerrace = "park-terrace"
        case lamp
        case wayfinding
        case bench
        case serviceProp = "service-prop"
    }

    struct Placement: Equatable, Sendable {
        let role: PlacementRole
        let center: CGPoint
        let size: CGSize
        let groundOnly: Bool
    }

    private enum Family: String {
        case residential
        case commercial
        case industrial
        case civic
        case park
    }

    private struct TemplateKey: Hashable {
        let family: String
        let variant: Int
        let frontage: UInt8
        let tileWidthHundredths: Int
        let tileHeightHundredths: Int
    }

    private struct ContextTemplate {
        let cityChildren: [SKNode]
        let neighborhoodChildren: [SKNode]
        let blockChildren: [SKNode]
    }

    /// Context geometry is immutable for one bounded
    /// family/variant/frontage/physical-grid identity. Keep prototypes rather
    /// than rebuilding the same paths, palette blends, and SpriteKit subtree
    /// for every scene and pulse. Callers receive deep copies, so visibility
    /// and later node mutation cannot affect the cached source.
    private static var templates: [TemplateKey: ContextTemplate] = [:]
    private static let maximumTemplateCount = 5 * 4 * 5

    private let style: WorldVisualStyle

    init(style: WorldVisualStyle) {
        self.style = style
    }

    func addContext(
        for tile: CityTile,
        adjacentRoads: RoadConnectionMask,
        selectedFrontage: RoadConnectionMask?,
        city: SKNode,
        neighborhood: SKNode,
        block: SKNode
    ) {
        guard let family = family(for: tile.kind) else { return }
        let frontage = selectedFrontage
            ?? ResidentialGeneratedAssetIdentity.authoritativeFrontagePriority.first(
                where: adjacentRoads.contains
            )
        let variant = WorldVisualSeed.variant(
            count: 4,
            for: tile.coordinate,
            kind: tile.kind,
            salt: 0x6600
        )
        let key = TemplateKey(
            family: family.rawValue,
            variant: variant,
            frontage: frontage?.rawValue ?? 0,
            tileWidthHundredths: Int((style.tileWidth * 100).rounded()),
            tileHeightHundredths: Int((style.tileHeight * 100).rounded())
        )
        let template: ContextTemplate
        if let cached = Self.templates[key] {
            template = cached
        } else {
            template = makeTemplate(
                family: family,
                variant: variant,
                frontage: frontage
            )
            if Self.templates.count < Self.maximumTemplateCount {
                Self.templates[key] = template
            }
        }
        addCopies(of: template.cityChildren, to: city)
        addCopies(of: template.neighborhoodChildren, to: neighborhood)
        addCopies(of: template.blockChildren, to: block)
    }

    func placementLedger(
        for tile: CityTile,
        adjacentRoads: RoadConnectionMask,
        selectedFrontage: RoadConnectionMask? = nil
    ) -> [Placement] {
        guard let family = family(for: tile.kind) else { return [] }
        let variant = Self.districtMaterialVariant(for: tile)
        let frontage = selectedFrontage
            ?? ResidentialGeneratedAssetIdentity.authoritativeFrontagePriority.first(
                where: adjacentRoads.contains
            )
        guard let frontage else { return [] }
        return placementLedger(family: family, frontage: frontage, variant: variant)
    }

    private func placementLedger(
        family: Family,
        frontage: RoadConnectionMask,
        variant: Int
    ) -> [Placement] {
        let front = normalized(style.roadSocket(for: frontage))
        let across = CGPoint(x: -front.y, y: front.x)
        func point(along: CGFloat, across side: CGFloat = 0) -> CGPoint {
            CGPoint(
                x: front.x * along + across.x * side,
                y: front.y * along + across.y * side
            )
        }

        switch family {
        case .residential:
            let side: CGFloat = variant.isMultiple(of: 2) ? -1 : 1
            return [
                Placement(
                    role: .plantingBed,
                    center: point(along: -8.8, across: 10.5 * side),
                    size: CGSize(width: 11, height: 4),
                    groundOnly: true
                ),
                Placement(
                    role: .lamp,
                    center: point(along: 10, across: -8.5 * side),
                    size: CGSize(width: 2.4, height: 2.4),
                    groundOnly: false
                ),
            ]
        case .commercial:
            let side: CGFloat = variant.isMultiple(of: 2) ? -1 : 1
            return [
                Placement(
                    role: .parkingBay,
                    center: point(along: -10, across: 3.5 * side),
                    size: CGSize(width: variant.isMultiple(of: 2) ? 24 : 28, height: 8),
                    groundOnly: true
                ),
                Placement(
                    role: .wayfinding,
                    center: point(along: 11.5, across: 11),
                    size: CGSize(width: 3.5, height: 2.5),
                    groundOnly: false
                ),
            ]
        case .industrial:
            return [
                Placement(
                    role: .serviceYard,
                    center: point(along: -9.5, across: 0),
                    size: CGSize(width: 29, height: 9),
                    groundOnly: true
                ),
                Placement(
                    role: .serviceProp,
                    center: point(along: -9, across: -8),
                    size: CGSize(width: 5, height: 3),
                    groundOnly: false
                ),
                Placement(
                    role: .lamp,
                    center: point(along: 11.5, across: -11),
                    size: CGSize(width: 2.4, height: 2.4),
                    groundOnly: false
                ),
            ]
        case .civic:
            return [
                Placement(
                    role: .civicForecourt,
                    center: point(along: 7.5, across: 0),
                    size: CGSize(width: 26, height: 8),
                    groundOnly: true
                ),
                Placement(
                    role: .lamp,
                    center: point(along: 10.5, across: -10.5),
                    size: CGSize(width: 2.4, height: 2.4),
                    groundOnly: false
                ),
                Placement(
                    role: .wayfinding,
                    center: point(along: 8.5, across: 12),
                    size: CGSize(width: 3.5, height: 2.5),
                    groundOnly: false
                ),
            ]
        case .park:
            return [
                Placement(
                    role: .parkTerrace,
                    center: point(along: 6.5, across: 0),
                    size: CGSize(width: 24, height: 9),
                    groundOnly: true
                ),
                Placement(
                    role: .bench,
                    center: point(along: -7, across: -8),
                    size: CGSize(width: 8, height: 3),
                    groundOnly: false
                ),
                Placement(
                    role: .wayfinding,
                    center: point(along: 6, across: -9),
                    size: CGSize(width: 3.5, height: 2.5),
                    groundOnly: false
                ),
            ]
        }
    }

    private func makeTemplate(
        family: Family,
        variant: Int,
        frontage: RoadConnectionMask?
    ) -> ContextTemplate {
        let city = SKNode()
        let neighborhood = SKNode()
        let block = SKNode()
        addCityLotRhythm(family: family, variant: variant, to: city)
        addBoundary(
            family: family,
            frontage: frontage,
            variant: variant,
            to: neighborhood
        )
        if let frontage {
            let placements = placementLedger(
                family: family,
                frontage: frontage,
                variant: variant
            )
            for (index, placement) in placements.enumerated() {
                let destination = placement.groundOnly ? neighborhood : block
                add(
                    placement: placement,
                    index: index,
                    family: family,
                    variant: variant,
                    frontage: frontage,
                    to: destination
                )
            }
        }
        return ContextTemplate(
            cityChildren: detachedChildren(of: city),
            neighborhoodChildren: detachedChildren(of: neighborhood),
            blockChildren: detachedChildren(of: block)
        )
    }

    private func detachedChildren(of root: SKNode) -> [SKNode] {
        let children = root.children
        for child in children {
            child.removeFromParent()
        }
        return children
    }

    private func addCopies(of prototypes: [SKNode], to destination: SKNode) {
        for prototype in prototypes {
            guard let copy = prototype.copy() as? SKNode else { continue }
            destination.addChild(copy)
        }
    }

    static var cachedTemplateCountForTesting: Int {
        templates.count
    }

    private func family(for kind: BuildingKind) -> Family? {
        switch kind {
        case .residential:
            .residential
        case .commercial:
            .commercial
        case .industrial, .powerPlant, .waterTower:
            .industrial
        case .cityHall, .fireStation, .policeStation, .school:
            .civic
        case .park:
            .park
        case .empty, .road:
            nil
        }
    }

    private func addCityLotRhythm(
        family: Family,
        variant: Int,
        to node: SKNode
    ) {
        let rhythm = SKShapeNode(path: style.diamondPath(width: 64, height: 32))
        rhythm.name = "lot.context.city.\(family.rawValue).material.\(variant)"
        rhythm.fillColor = .clear
        rhythm.strokeColor = boundaryColor(for: family).withAlphaComponent(0.30)
        rhythm.lineWidth = family == .industrial ? 1.25 : 0.9
        rhythm.zPosition = -3.1
        node.addChild(rhythm)
    }

    private func addBoundary(
        family: Family,
        frontage: RoadConnectionMask?,
        variant: Int,
        to node: SKNode
    ) {
        let sockets: [(RoadConnectionMask, CGPoint)] = [
            (.north, style.roadSocket(for: .north, overreach: -2.5)),
            (.east, style.roadSocket(for: .east, overreach: -2.5)),
            (.south, style.roadSocket(for: .south, overreach: -2.5)),
            (.west, style.roadSocket(for: .west, overreach: -2.5)),
        ]
        let edgePath = CGMutablePath()
        for index in sockets.indices {
            let nextIndex = (index + 1) % sockets.count
            var start = sockets[index].1
            var end = sockets[nextIndex].1
            if sockets[index].0 == frontage {
                start = interpolate(start, end, progress: 0.32)
            }
            if sockets[nextIndex].0 == frontage {
                end = interpolate(end, start, progress: 0.32)
            }
            edgePath.move(to: start)
            edgePath.addLine(to: end)
        }
        let boundary = SKShapeNode(path: edgePath)
        boundary.name = "lot.lod.neighborhood.public-realm.\(family.rawValue)"
        boundary.strokeColor = boundaryColor(for: family)
        boundary.lineWidth = boundaryWidth(for: family)
        boundary.lineCap = .round
        boundary.zPosition = 3.9
        node.addChild(boundary)

        guard family == .residential, let frontage else { return }
        let front = normalized(style.roadSocket(for: frontage))
        let across = CGPoint(x: -front.y, y: front.x)
        let side: CGFloat = variant.isMultiple(of: 2) ? -1 : 1
        let center = CGPoint(
            x: -front.x * 10.5 + across.x * 8.5 * side,
            y: -front.y * 10.5 + across.y * 8.5 * side
        )
        let edge = WorldGeometryCache.line(
            from: CGPoint(
                x: center.x - across.x * 5.2,
                y: center.y - across.y * 2.6
            ),
            to: CGPoint(
                x: center.x + across.x * 5.2,
                y: center.y + across.y * 2.6
            )
        )
        let rearEdge = SKShapeNode(path: edge)
        rearEdge.name = "lot.context.residential.rear-edge.\(variant)"
        rearEdge.strokeColor = style.palette.foliage[
            variant % style.palette.foliage.count
        ].blended(
            withFraction: 0.38,
            of: style.palette.mapEarthDark
        )?.withAlphaComponent(0.82) ?? style.palette.foliage[0]
        rearEdge.lineWidth = variant.isMultiple(of: 2) ? 1.8 : 1.25
        rearEdge.lineCap = .round
        rearEdge.zPosition = 4
        node.addChild(rearEdge)
    }

    private func add(
        placement: Placement,
        index: Int,
        family: Family,
        variant: Int,
        frontage: RoadConnectionMask?,
        to node: SKNode
    ) {
        let root = SKNode()
        root.name = "lot.context.\(family.rawValue).\(placement.role.rawValue).\(index)"
        root.position = placement.center
        root.zPosition = placement.groundOnly ? 4.1 : 12
        if let frontage {
            let vector = style.roadSocket(for: frontage)
            root.zRotation = atan2(vector.y, vector.x)
        }

        switch placement.role {
        case .plantingBed:
            addPlantingBed(size: placement.size, variant: variant + index, to: root)
        case .parkingBay:
            addParkingBay(size: placement.size, variant: variant, to: root)
        case .serviceYard:
            addServiceYard(size: placement.size, variant: variant, to: root)
        case .civicForecourt:
            addCivicForecourt(size: placement.size, to: root)
        case .parkTerrace:
            addParkTerrace(size: placement.size, variant: variant, to: root)
        case .lamp:
            addLamp(variant: variant + index, to: root)
        case .wayfinding:
            addWayfinding(family: family, to: root)
        case .bench:
            addBench(variant: variant + index, to: root)
        case .serviceProp:
            addServiceProp(variant: variant + index, to: root)
        }
        switch placement.role {
        case .lamp:
            root.setScale(0.72)
        case .wayfinding:
            root.setScale(0.60)
        case .bench, .serviceProp:
            root.setScale(0.82)
        default:
            break
        }
        node.addChild(root)
    }

    private func addPlantingBed(size: CGSize, variant: Int, to node: SKNode) {
        let bed = SKShapeNode(path: style.diamondPath(width: size.width, height: size.height))
        bed.name = "lot.context.planting.soil"
        bed.fillColor = style.palette.mapEarth.blended(
            withFraction: 0.24,
            of: style.palette.soil
        ) ?? style.palette.mapEarth
        bed.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.55)
        bed.lineWidth = 0.6
        node.addChild(bed)

        let palette = style.palette.foliage
        let offsets: [CGPoint] = [
            CGPoint(x: -size.width * 0.24, y: 0),
            CGPoint(x: 0, y: size.height * 0.13),
            CGPoint(x: size.width * 0.23, y: -size.height * 0.08),
        ]
        let foliagePath = CGMutablePath()
        for (index, offset) in offsets.enumerated() {
            let width = 2.8 + CGFloat((variant + index) % 2)
            let height = 1.8 + CGFloat((variant + index + 1) % 2) * 0.5
            foliagePath.addEllipse(in: CGRect(
                x: offset.x - width / 2,
                y: offset.y - height / 2,
                width: width,
                height: height
            ))
        }
        let lobes = SKShapeNode(path: foliagePath)
        lobes.name = "lot.context.planting.organic-lobes"
        lobes.fillColor = palette[variant % palette.count].withAlphaComponent(0.92)
        lobes.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.24)
        lobes.lineWidth = 0.35
        lobes.zPosition = 1
        node.addChild(lobes)
    }

    private func addParkingBay(size: CGSize, variant: Int, to node: SKNode) {
        let court = SKShapeNode(path: style.diamondPath(width: size.width, height: size.height))
        court.name = "lot.context.parking.material.\(variant)"
        court.fillColor = style.palette.asphaltLight.blended(
            withFraction: 0.34,
            of: style.palette.concrete
        ) ?? style.palette.asphaltLight
        court.strokeColor = style.palette.curb.withAlphaComponent(0.74)
        court.lineWidth = 0.7
        court.zPosition = 0.2
        node.addChild(court)

        let seams = CGMutablePath()
        for offset in [-7.0, 0.0, 7.0] {
            seams.move(to: CGPoint(x: offset - 2.6, y: -2.3))
            seams.addLine(to: CGPoint(x: offset + 2.6, y: 2.3))
        }
        let marks = SKShapeNode(path: seams)
        marks.name = "lot.context.parking.stalls"
        marks.strokeColor = style.palette.crosswalk.withAlphaComponent(0.42)
        marks.lineWidth = 0.55
        marks.lineCap = .butt
        marks.zPosition = 0.4
        node.addChild(marks)
    }

    private func addServiceYard(size: CGSize, variant: Int, to node: SKNode) {
        let yard = SKShapeNode(path: style.diamondPath(width: size.width, height: size.height))
        yard.name = "lot.context.service-yard.material.\(variant)"
        yard.fillColor = style.palette.soil.blended(
            withFraction: 0.56,
            of: style.palette.asphalt
        ) ?? style.palette.soil
        yard.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.74)
        yard.lineWidth = 0.9
        node.addChild(yard)

        let drainage = CGMutablePath()
        for offset in [-7.0, 0.0, 7.0] {
            drainage.move(to: CGPoint(x: offset - 4, y: -2.8))
            drainage.addLine(to: CGPoint(x: offset + 4, y: 2.8))
        }
        let rails = SKShapeNode(path: drainage)
        rails.name = "lot.context.service-yard.drainage"
        rails.strokeColor = style.palette.curb.withAlphaComponent(0.32)
        rails.lineWidth = 0.55
        rails.zPosition = 0.3
        node.addChild(rails)
    }

    private func addCivicForecourt(size: CGSize, to node: SKNode) {
        let court = SKShapeNode(path: style.diamondPath(width: size.width, height: size.height))
        court.name = "lot.context.civic.forecourt-stone"
        court.fillColor = style.palette.civicStone.blended(
            withFraction: 0.26,
            of: style.palette.concrete
        ) ?? style.palette.civicStone
        court.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.42)
        court.lineWidth = 0.75
        node.addChild(court)
        addPaverJoints(width: size.width, to: node)
    }

    private func addParkTerrace(size: CGSize, variant: Int, to node: SKNode) {
        let terrace = SKShapeNode(path: style.diamondPath(width: size.width, height: size.height))
        terrace.name = "lot.context.park.terrace.\(variant)"
        terrace.fillColor = style.palette.parkPath.blended(
            withFraction: 0.22,
            of: style.palette.concreteLight
        ) ?? style.palette.parkPath
        terrace.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.38)
        terrace.lineWidth = 0.7
        node.addChild(terrace)
        addPaverJoints(width: size.width, to: node)
    }

    private func addPaverJoints(width: CGFloat, to node: SKNode) {
        let joints = CGMutablePath()
        for fraction in [-0.24, 0.0, 0.24] {
            let x = width * fraction
            joints.move(to: CGPoint(x: x - 2.8, y: -2.3))
            joints.addLine(to: CGPoint(x: x + 2.8, y: 2.3))
        }
        let lines = SKShapeNode(path: joints)
        lines.name = "lot.context.paver-joints"
        lines.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.26)
        lines.lineWidth = 0.45
        lines.zPosition = 0.3
        node.addChild(lines)
    }

    private func addLamp(variant: Int, to node: SKNode) {
        let post = SKShapeNode(rectOf: CGSize(width: 1.1, height: 8.5), cornerRadius: 0.35)
        post.name = "lot.context.lamp.post"
        post.fillColor = style.palette.roofDark
        post.strokeColor = NSColor.white.withAlphaComponent(0.08)
        post.lineWidth = 0.35
        post.position.y = 4.25
        post.zPosition = 1
        node.addChild(post)

        let hood = SKShapeNode(path: WorldGeometryCache.polygon([
            CGPoint(x: -2.4, y: 0),
            CGPoint(x: -1.1, y: 1.7),
            CGPoint(x: 2.1, y: 1.2),
            CGPoint(x: 2.6, y: -0.5),
            CGPoint(x: 0.8, y: -1.3),
            CGPoint(x: -1.7, y: -1.0),
        ]))
        hood.name = "lot.context.lamp.hood.\(variant % 3)"
        hood.fillColor = style.palette.roofDark
        hood.strokeColor = style.palette.concreteLight.withAlphaComponent(0.24)
        hood.lineWidth = 0.4
        hood.position.y = 8.8
        hood.zPosition = 2
        node.addChild(hood)

        let glow = SKShapeNode(path: style.diamondPath(width: 2.8, height: 1.4))
        glow.name = "lot.context.lamp.warm-light"
        glow.fillColor = style.palette.warmWindow.withAlphaComponent(0.82)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0.3, y: 8.1)
        glow.zPosition = 2.2
        node.addChild(glow)
    }

    private func addWayfinding(family: Family, to node: SKNode) {
        let post = SKShapeNode(rectOf: CGSize(width: 0.8, height: 5.6), cornerRadius: 0.25)
        post.fillColor = style.palette.roofDark
        post.strokeColor = .clear
        post.position.y = 2.8
        post.zPosition = 1
        node.addChild(post)

        let plaque = SKShapeNode(path: WorldGeometryCache.polygon([
            CGPoint(x: -2.5, y: 0.75),
            CGPoint(x: 1.8, y: 0.75),
            CGPoint(x: 2.5, y: 0),
            CGPoint(x: 1.8, y: -0.75),
            CGPoint(x: -2.5, y: -0.75),
        ]))
        plaque.name = "lot.context.wayfinding.plaque.\(family.rawValue)"
        plaque.fillColor = style.palette.roofDark.blended(
            withFraction: family == .park ? 0.22 : 0.12,
            of: style.palette.foliage[0]
        ) ?? style.palette.roofDark
        plaque.strokeColor = style.palette.concreteLight.withAlphaComponent(0.22)
        plaque.lineWidth = 0.45
        plaque.position = CGPoint(x: 0.8, y: 5.2)
        plaque.zPosition = 2
        node.addChild(plaque)
    }

    private func addBench(variant: Int, to node: SKNode) {
        let contact = SKShapeNode(path: style.diamondPath(width: 9, height: 3))
        contact.name = "lot.context.bench.contact"
        contact.fillColor = NSColor.black.withAlphaComponent(0.14)
        contact.strokeColor = .clear
        contact.position.y = -0.8
        node.addChild(contact)

        let seat = SKShapeNode(path: WorldGeometryCache.polygon([
            CGPoint(x: -4.5, y: 0),
            CGPoint(x: -2.7, y: 1.5),
            CGPoint(x: 4.5, y: 0),
            CGPoint(x: 2.7, y: -1.5),
        ]))
        seat.name = "lot.context.bench.seat.\(variant % 3)"
        seat.fillColor = NSColor(calibratedRed: 0.34, green: 0.23, blue: 0.14, alpha: 1)
        seat.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.72)
        seat.lineWidth = 0.55
        seat.position.y = 2.2
        seat.zPosition = 1
        node.addChild(seat)
    }

    private func addServiceProp(variant: Int, to node: SKNode) {
        let shadow = SKShapeNode(path: style.diamondPath(width: 6.2, height: 3))
        shadow.name = "lot.context.service-prop.contact"
        shadow.fillColor = NSColor.black.withAlphaComponent(0.16)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0.8, y: -0.8)
        node.addChild(shadow)

        let base = SKShapeNode(path: WorldGeometryCache.polygon([
            CGPoint(x: -2.8, y: 1),
            CGPoint(x: 0, y: 2.5),
            CGPoint(x: 2.8, y: 1),
            CGPoint(x: 2.8, y: -1.4),
            CGPoint(x: 0, y: -2.8),
            CGPoint(x: -2.8, y: -1.4),
        ]))
        base.name = "lot.context.service-prop.\(variant % 3)"
        base.fillColor = style.palette.industrial[(variant + 1) % style.palette.industrial.count]
            .blended(withFraction: 0.38, of: style.palette.roofDark)
            ?? style.palette.roofDark
        base.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.66)
        base.lineWidth = 0.55
        base.position.y = 1.5
        base.zPosition = 1
        node.addChild(base)
    }

    private func boundaryColor(for family: Family) -> NSColor {
        switch family {
        case .residential:
            style.palette.foliage[0].blended(
                withFraction: 0.44,
                of: style.palette.mapEarthDark
            ) ?? style.palette.foliage[0]
        case .park:
            style.palette.curb.withAlphaComponent(0.62)
        case .commercial, .civic:
            style.palette.curb.withAlphaComponent(0.82)
        case .industrial:
            style.palette.roofDark.withAlphaComponent(0.88)
        }
    }

    private func boundaryWidth(for family: Family) -> CGFloat {
        switch family {
        case .residential: 1.55
        case .park: 0.9
        case .industrial: 1.1
        case .commercial, .civic: 0.8
        }
    }

    private func normalized(_ point: CGPoint) -> CGPoint {
        let length = max(0.001, hypot(point.x, point.y))
        return CGPoint(x: point.x / length, y: point.y / length)
    }

    private func interpolate(_ start: CGPoint, _ end: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }
}
