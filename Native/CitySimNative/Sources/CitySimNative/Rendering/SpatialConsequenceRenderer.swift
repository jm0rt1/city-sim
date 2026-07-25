import AppKit
import SpriteKit

struct SpatialConsequenceRenderSignature: Equatable {
    let power: CityConsequenceBand
    let water: CityConsequenceBand
    let combinedUtility: CityConsequenceBand
    let pollution: CityConsequenceBand
    let vitality: CityLocationVitality

    init(_ consequence: CitySpatialConsequence) {
        power = consequence.utility.powerBand
        water = consequence.utility.waterBand
        combinedUtility = consequence.utility.combinedBand
        pollution = consequence.pollutionBand
        vitality = consequence.vitality
    }
}

@MainActor
final class SpatialConsequenceRenderer {
    private let style: WorldVisualStyle

    init(style: WorldVisualStyle) {
        self.style = style
    }

    func makePersistentCues(
        for consequence: CitySpatialConsequence,
        detail: CameraDetailLevel
    ) -> SKNode {
        let root = SKNode()
        root.name = "spatial.consequences"
        guard consequence.vitality != .notApplicable else { return root }

        let city = style.makeDetailLayer(.city, visibleAt: detail)
        let cityContent = SKNode()
        cityContent.name = "spatial.city"
        addCityAggregateCue(consequence, to: cityContent)
        if !cityContent.children.isEmpty {
            city.addChild(cityContent)
            root.addChild(city)
        }

        let neighborhood = style.makeDetailLayer(.neighborhood, visibleAt: detail)
        let neighborhoodContent = SKNode()
        neighborhoodContent.name = "spatial.neighborhood"
        addUtilityCue(consequence.utility, to: neighborhoodContent)
        addPollutionCue(consequence.pollutionBand, to: neighborhoodContent)
        if !neighborhoodContent.children.isEmpty {
            neighborhood.addChild(neighborhoodContent)
            root.addChild(neighborhood)
        }

        let block = style.makeDetailLayer(.block, visibleAt: detail)
        let blockContent = SKNode()
        blockContent.name = "spatial.block"
        addVitalityCue(consequence.vitality, to: blockContent)
        if !blockContent.children.isEmpty {
            block.addChild(blockContent)
            root.addChild(block)
        }
        return root
    }

    private func addCityAggregateCue(_ consequence: CitySpatialConsequence, to root: SKNode) {
        enum Aggregate {
            case severe
            case strained
            case prosperous
        }
        let aggregate: Aggregate?
        if consequence.utility.combinedBand == .severe
            || consequence.pollutionBand == .severe
            || consequence.vitality == .strained {
            aggregate = .severe
        } else if consequence.utility.combinedBand == .strained
            || consequence.pollutionBand == .strained {
            aggregate = .strained
        } else if consequence.vitality == .prosperous {
            aggregate = .prosperous
        } else {
            aggregate = nil
        }
        guard let aggregate else { return }

        let path = CGMutablePath()
        let name: String
        let color: NSColor
        switch aggregate {
        case .severe:
            name = "spatial.city.aggregate.severe.cross"
            color = .systemRed
            path.move(to: CGPoint(x: -6, y: -4))
            path.addLine(to: CGPoint(x: 6, y: 4))
            path.move(to: CGPoint(x: -6, y: 4))
            path.addLine(to: CGPoint(x: 6, y: -4))
        case .strained:
            name = "spatial.city.aggregate.strained.triangle"
            color = .systemOrange
            path.move(to: CGPoint(x: -7, y: -4))
            path.addLine(to: CGPoint(x: 0, y: 5))
            path.addLine(to: CGPoint(x: 7, y: -4))
            path.closeSubpath()
        case .prosperous:
            name = "spatial.city.aggregate.prosperous.chevron"
            color = .systemMint
            path.move(to: CGPoint(x: -7, y: -3))
            path.addLine(to: CGPoint(x: 0, y: 5))
            path.addLine(to: CGPoint(x: 7, y: -3))
        }
        let cue = SKShapeNode(path: path)
        cue.name = name
        cue.fillColor = .clear
        cue.strokeColor = color
        cue.lineWidth = 2.5
        cue.lineCap = .square
        cue.lineJoin = .miter
        cue.position = CGPoint(x: 0, y: 19)
        root.addChild(cue)
    }

    func makeEventCue(
        for event: CitySpatialConsequenceEvent,
        reducedMotion: Bool
    ) -> SKNode {
        let root = SKNode()
        root.name = "spatial.event.\(event.dimension.rawValue).\(event.direction.rawValue).\(event.id)"
        root.zPosition = 78

        let color: NSColor = event.direction == .recovery ? .systemMint : .systemOrange
        // Transition feedback stays on the frontage below the facade. At the
        // strategic camera stop a world-space ellipse grows into an obscuring
        // screen-space targeting ring, so use a compact grounded bracket.
        let frontageY = -style.tileHeight / 2 + 2
        let bracketPath = CGMutablePath()
        bracketPath.move(to: CGPoint(x: -8, y: frontageY + 3))
        bracketPath.addLine(to: CGPoint(x: -5, y: frontageY))
        bracketPath.addLine(to: CGPoint(x: 5, y: frontageY))
        bracketPath.addLine(to: CGPoint(x: 8, y: frontageY + 3))
        let bracket = SKShapeNode(path: bracketPath)
        bracket.name = "spatial.event.frontage-bracket.\(event.direction.rawValue)"
        bracket.fillColor = .clear
        bracket.strokeColor = color.withAlphaComponent(reducedMotion ? 0.48 : 0.78)
        bracket.lineWidth = event.direction == .recovery ? 0.9 : 1.1
        bracket.lineCap = .round
        bracket.lineJoin = .round
        root.addChild(bracket)

        let mark = SKShapeNode(path: eventMarkPath(event.direction))
        mark.name = "spatial.event.mark.\(event.direction.rawValue)"
        mark.strokeColor = color.withAlphaComponent(reducedMotion ? 0.78 : 0.94)
        mark.lineWidth = 1.15
        mark.lineCap = .round
        mark.lineJoin = .round
        mark.fillColor = .clear
        mark.setScale(0.38)
        mark.position = CGPoint(x: 0, y: frontageY + 6)
        root.addChild(mark)

        if !reducedMotion {
            root.setScale(0.86)
            root.alpha = 0.92
            root.run(.sequence([
                .group([
                    .scale(to: 1.03, duration: 0.22),
                    .fadeAlpha(to: 1, duration: 0.22)
                ]),
                .wait(forDuration: 0.55),
                .fadeOut(withDuration: 0.32),
                .removeFromParent()
            ]), withKey: "spatial.event.once")
        }
        return root
    }

    private func addUtilityCue(_ utility: CityLocationUtilityService, to root: SKNode) {
        guard utility.combinedBand != .healthy else { return }
        let color: NSColor = utility.combinedBand == .severe ? .systemRed : .systemOrange

        let bracketPath = CGMutablePath()
        bracketPath.move(to: CGPoint(x: -22, y: -9))
        bracketPath.addLine(to: CGPoint(x: -22, y: 7))
        bracketPath.addLine(to: CGPoint(x: -16, y: 10))
        bracketPath.move(to: CGPoint(x: 22, y: -9))
        bracketPath.addLine(to: CGPoint(x: 22, y: 7))
        bracketPath.addLine(to: CGPoint(x: 16, y: 10))
        let bracket = SKShapeNode(path: bracketPath)
        bracket.name = "spatial.utility.\(bandName(utility.combinedBand)).brackets"
        bracket.strokeColor = color.withAlphaComponent(0.88)
        bracket.lineWidth = utility.combinedBand == .severe ? 2.4 : 1.5
        bracket.lineCap = .square
        root.addChild(bracket)

        if utility.powerBand != .healthy {
            let boltPath = CGMutablePath()
            boltPath.move(to: CGPoint(x: -9, y: 11))
            boltPath.addLine(to: CGPoint(x: -14, y: 2))
            boltPath.addLine(to: CGPoint(x: -9, y: 2))
            boltPath.addLine(to: CGPoint(x: -13, y: -7))
            let bolt = SKShapeNode(path: boltPath)
            bolt.name = "spatial.utility.power.\(bandName(utility.powerBand)).broken-bolt"
            bolt.strokeColor = color
            bolt.lineWidth = 2
            bolt.lineJoin = .bevel
            root.addChild(bolt)
        }

        if utility.waterBand != .healthy {
            let dropPath = CGMutablePath()
            dropPath.move(to: CGPoint(x: 11, y: 10))
            dropPath.addCurve(
                to: CGPoint(x: 11, y: -7),
                control1: CGPoint(x: 3, y: 0),
                control2: CGPoint(x: 4, y: -7)
            )
            dropPath.addCurve(
                to: CGPoint(x: 11, y: 10),
                control1: CGPoint(x: 18, y: -7),
                control2: CGPoint(x: 19, y: 0)
            )
            let drop = SKShapeNode(path: dropPath)
            drop.name = "spatial.utility.water.\(bandName(utility.waterBand)).dry-drop"
            drop.fillColor = .clear
            drop.strokeColor = color
            drop.lineWidth = 1.8
            root.addChild(drop)
        }
    }

    private func addPollutionCue(_ band: CityConsequenceBand, to root: SKNode) {
        guard band != .healthy else { return }
        let color = NSColor(calibratedWhite: band == .severe ? 0.18 : 0.30, alpha: 0.70)
        let count = band == .severe ? 4 : 2
        let frontageY = -style.tileHeight / 2 + 4
        for index in 0..<count {
            let x = CGFloat(index - count / 2) * 6
            let slash = SKShapeNode(path: WorldGeometryCache.line(
                from: CGPoint(x: x - 3, y: frontageY),
                to: CGPoint(x: x + 3, y: frontageY + 4)
            ))
            slash.name = "spatial.pollution.\(bandName(band)).hatch.\(index)"
            slash.strokeColor = color
            slash.lineWidth = band == .severe ? 1.35 : 0.95
            slash.lineCap = .round
            root.addChild(slash)
        }
        let particulate = SKShapeNode(circleOfRadius: band == .severe ? 2.1 : 1.5)
        particulate.name = "spatial.pollution.\(bandName(band)).particulate"
        particulate.fillColor = color
        particulate.strokeColor = .clear
        particulate.position = CGPoint(x: 15, y: frontageY + 3)
        root.addChild(particulate)
    }

    private func addVitalityCue(_ vitality: CityLocationVitality, to root: SKNode) {
        switch vitality {
        case .notApplicable, .stable:
            return
        case .strained:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -14, y: 15))
            path.addLine(to: CGPoint(x: -5, y: 12))
            path.addLine(to: CGPoint(x: 3, y: 15))
            path.addLine(to: CGPoint(x: 13, y: 11))
            let patch = SKShapeNode(path: path)
            patch.name = "spatial.vitality.strained.patchwork"
            patch.strokeColor = .systemOrange
            patch.lineWidth = 2.2
            patch.lineCap = .square
            root.addChild(patch)
        case .prosperous:
            let canopy = SKShapeNode(rectOf: CGSize(width: 28, height: 5), cornerRadius: 1.5)
            canopy.name = "spatial.vitality.prosperous.canopy"
            canopy.fillColor = .systemMint.withAlphaComponent(0.72)
            canopy.strokeColor = .white.withAlphaComponent(0.72)
            canopy.lineWidth = 0.8
            canopy.position = CGPoint(x: 0, y: 14)
            root.addChild(canopy)
        }
    }

    private func eventMarkPath(_ direction: CitySpatialConsequenceDirection) -> CGPath {
        let path = CGMutablePath()
        if direction == .recovery {
            path.move(to: CGPoint(x: -7, y: 0))
            path.addLine(to: CGPoint(x: -1, y: -6))
            path.addLine(to: CGPoint(x: 8, y: 6))
        } else {
            path.move(to: CGPoint(x: -7, y: 5))
            path.addLine(to: CGPoint(x: 0, y: -6))
            path.addLine(to: CGPoint(x: 7, y: 5))
        }
        return path
    }

    private func bandName(_ band: CityConsequenceBand) -> String {
        switch band {
        case .severe: "severe"
        case .strained: "strained"
        case .healthy: "healthy"
        }
    }
}
