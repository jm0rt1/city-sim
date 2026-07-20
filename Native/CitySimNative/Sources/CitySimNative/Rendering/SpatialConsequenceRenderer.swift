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

        let neighborhood = style.makeDetailLayer(.neighborhood, visibleAt: detail)
        neighborhood.name = "spatial.neighborhood"
        addUtilityCue(consequence.utility, to: neighborhood)
        addPollutionCue(consequence.pollutionBand, to: neighborhood)
        root.addChild(neighborhood)

        let block = style.makeDetailLayer(.block, visibleAt: detail)
        block.name = "spatial.block"
        addVitalityCue(consequence.vitality, to: block)
        root.addChild(block)
        return root
    }

    func makeEventCue(
        for event: CitySpatialConsequenceEvent,
        reducedMotion: Bool
    ) -> SKNode {
        let root = SKNode()
        root.name = "spatial.event.\(event.dimension.rawValue).\(event.direction.rawValue).\(event.id)"
        root.zPosition = 78

        let color: NSColor = event.direction == .recovery ? .systemMint : .systemOrange
        let ring = SKShapeNode(ellipseOf: CGSize(width: 46, height: 23))
        ring.name = "spatial.event.ring.\(event.direction.rawValue)"
        ring.fillColor = .clear
        ring.strokeColor = color.withAlphaComponent(0.95)
        ring.lineWidth = event.direction == .recovery ? 2.2 : 3.4
        root.addChild(ring)

        let mark = SKShapeNode(path: eventMarkPath(event.direction))
        mark.name = "spatial.event.mark.\(event.direction.rawValue)"
        mark.strokeColor = color
        mark.lineWidth = 2.4
        mark.lineCap = .round
        mark.lineJoin = .round
        mark.fillColor = .clear
        mark.position = CGPoint(x: 0, y: 17)
        root.addChild(mark)

        if !reducedMotion {
            root.setScale(0.72)
            root.alpha = 0.92
            root.run(.sequence([
                .group([
                    .scale(to: 1.18, duration: 0.22),
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
        let color = NSColor(calibratedWhite: band == .severe ? 0.18 : 0.30, alpha: 0.78)
        let count = band == .severe ? 5 : 3
        for index in 0..<count {
            let x = CGFloat(index - count / 2) * 8
            let slash = SKShapeNode(path: WorldGeometryCache.line(
                from: CGPoint(x: x - 5, y: -8),
                to: CGPoint(x: x + 5, y: 8)
            ))
            slash.name = "spatial.pollution.\(bandName(band)).hatch.\(index)"
            slash.strokeColor = color
            slash.lineWidth = band == .severe ? 2.0 : 1.2
            root.addChild(slash)
        }
        let particulate = SKShapeNode(circleOfRadius: band == .severe ? 3 : 2)
        particulate.name = "spatial.pollution.\(bandName(band)).particulate"
        particulate.fillColor = color
        particulate.strokeColor = .clear
        particulate.position = CGPoint(x: 17, y: 10)
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
