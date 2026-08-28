import AppKit
import SpriteKit

enum WorldOverlayPattern: String, Sendable {
    case utilityEdge
    case pollutionHatch
    case landValueContour
    case trafficPressureTicks
    case happinessRipples
}

struct WorldOverlaySample {
    let value: Double
    let color: NSColor
    let pattern: WorldOverlayPattern
}

@MainActor
final class WorldOverlayRenderer {
    private let style: WorldVisualStyle

    init(style: WorldVisualStyle) {
        self.style = style
    }

    func makeOverlay(
        for tile: CityTile,
        state: CityGameState,
        consequence: CitySpatialConsequence?,
        overlay: DataOverlay,
        detail: CameraDetailLevel
    ) -> SKNode {
        let root = SKNode()
        root.name = "overlay.\(overlay.rawValue)"
        guard let sample = sample(
            for: tile,
            state: state,
            consequence: consequence,
            overlay: overlay
        ) else { return root }

        let severity = 1 - sample.value
        guard let minimumDetail = minimumDetail(for: severity) else { return root }

        let emphasis: SKNode
        switch sample.pattern {
        case .utilityEdge:
            emphasis = makeUtilityEdge(color: sample.color, severity: severity, detail: minimumDetail)
        case .pollutionHatch:
            emphasis = makePollutionHatch(color: sample.color, severity: severity, detail: minimumDetail)
        case .landValueContour:
            emphasis = makeLandValueContour(color: sample.color, severity: severity, detail: minimumDetail)
        case .trafficPressureTicks:
            emphasis = makeTrafficPressureTicks(color: sample.color, severity: severity, detail: minimumDetail)
        case .happinessRipples:
            emphasis = makeHappinessRipples(color: sample.color, severity: severity, detail: minimumDetail)
        }
        emphasis.name = "overlay.pattern.\(sample.pattern.rawValue)"
        emphasis.zPosition = 30
        let detailLayer = style.makeDetailLayer(minimumDetail, visibleAt: detail)
        detailLayer.addChild(emphasis)
        root.addChild(detailLayer)
        return root
    }

    func color(
        for tile: CityTile,
        state: CityGameState,
        consequence: CitySpatialConsequence?,
        overlay: DataOverlay
    ) -> NSColor? {
        sample(for: tile, state: state, consequence: consequence, overlay: overlay)?.color
    }

    func sample(
        for tile: CityTile,
        state _: CityGameState,
        consequence: CitySpatialConsequence?,
        overlay: DataOverlay
    ) -> WorldOverlaySample? {
        guard let consequence,
              consequence.coordinate == tile.coordinate,
              overlay.applies(to: tile) else {
            return nil
        }

        switch overlay {
        case .utilities:
            return makeSample(consequence.utility.combined, pattern: .utilityEdge)
        case .pollution:
            return makeSample(1 - consequence.pollutionExposure, pattern: .pollutionHatch)
        case .landValue:
            guard let value = consequence.landValueIndex else { return nil }
            return makeSample(value, pattern: .landValueContour)
        case .traffic:
            guard let pressure = consequence.trafficPressure else { return nil }
            // The renderer's heat scale is health-oriented. Invert the typed
            // pressure channel for color/severity only; do not infer traffic
            // from occupancy, topology, vehicles, or state here.
            return makeSample(1 - pressure, pattern: .trafficPressureTicks)
        case .happiness:
            guard let value = consequence.localHappinessIndex else { return nil }
            return makeSample(value, pattern: .happinessRipples)
        case .none:
            return nil
        }
    }

    private func makeSample(_ rawValue: Double, pattern: WorldOverlayPattern) -> WorldOverlaySample {
        let value = min(1, max(0, rawValue))
        return WorldOverlaySample(value: value, color: heatColor(value), pattern: pattern)
    }

    private func heatColor(_ value: Double) -> NSColor {
        if value < 0.5 {
            return NSColor.systemRed.blended(withFraction: value * 2, of: .systemYellow) ?? .systemYellow
        }
        return NSColor.systemYellow.blended(withFraction: (value - 0.5) * 2, of: .systemGreen) ?? .systemGreen
    }

    private func makeUtilityEdge(
        color: NSColor,
        severity: Double,
        detail: CameraDetailLevel
    ) -> SKNode {
        let root = SKNode()
        let ink = color.withAlphaComponent(detail == .city ? 0.78 : 0.68)
        let halfWidth = style.tileWidth * 0.25
        let upperY = -style.tileHeight / 12
        let lowerY = -style.tileHeight * 0.30
        let edgePath = CGMutablePath()
        edgePath.move(to: CGPoint(x: -halfWidth, y: upperY))
        edgePath.addLine(to: CGPoint(x: 0, y: lowerY))
        edgePath.addLine(to: CGPoint(x: halfWidth, y: upperY))

        let edge = SKShapeNode(path: edgePath)
        edge.name = "overlay.utility.status-edge"
        edge.fillColor = .clear
        edge.strokeColor = ink
        edge.lineWidth = detail == .city ? 1.5 : 1.15
        edge.lineCap = .round
        edge.lineJoin = .round
        root.addChild(edge)

        let notchCount = severityMarkCount(severity)
        for index in 0..<notchCount {
            let x = CGFloat(index - (notchCount - 1) / 2) * 6
            let notch = SKShapeNode(path: WorldGeometryCache.line(
                from: CGPoint(x: x, y: lowerY + 1),
                to: CGPoint(x: x, y: lowerY + 6)
            ))
            notch.name = "overlay.utility.severity-notch"
            notch.fillColor = .clear
            notch.strokeColor = ink
            notch.lineWidth = 1.25
            notch.lineCap = .round
            root.addChild(notch)
        }
        return root
    }

    private func makePollutionHatch(
        color: NSColor,
        severity: Double,
        detail: CameraDetailLevel
    ) -> SKNode {
        let root = SKNode()
        let ink = color.withAlphaComponent(detail == .city ? 0.72 : 0.60)
        let hatchCount = severityMarkCount(severity)
        // Keep pollution truth on the lot's ground/frontage plane. Marks over
        // roofs and facades obscure the very building condition the player is
        // diagnosing, especially when several pressured lots sit together.
        let verticalOffset = -style.tileHeight * 0.40
        for index in 0..<hatchCount {
            let x = CGFloat(index - (hatchCount - 1) / 2) * 6
            let hatch = SKShapeNode(path: WorldGeometryCache.line(
                from: CGPoint(x: x - 3, y: verticalOffset),
                to: CGPoint(x: x + 2, y: verticalOffset + 2.5)
            ))
            hatch.name = "overlay.pollution.exposure-hatch"
            hatch.fillColor = .clear
            hatch.strokeColor = ink
            hatch.lineWidth = detail == .city ? 1.2 : 0.9
            hatch.lineCap = .round
            root.addChild(hatch)
        }
        return root
    }

    private func makeLandValueContour(
        color: NSColor,
        severity: Double,
        detail: CameraDetailLevel
    ) -> SKNode {
        let root = SKNode()
        let ink = color.withAlphaComponent(detail == .city ? 0.76 : 0.62)
        let contourCount = severityMarkCount(severity)
        let baseY = -style.tileHeight * 0.38
        for index in 0..<contourCount {
            let inset = CGFloat(index) * 2
            let halfWidth = style.tileWidth * 0.18 - inset
            let rise = 2 + CGFloat(index) * 0.6
            let contour = CGMutablePath()
            contour.move(to: CGPoint(x: -halfWidth, y: baseY + inset * 0.35))
            contour.addLine(to: CGPoint(x: 0, y: baseY - rise))
            contour.addLine(to: CGPoint(x: halfWidth, y: baseY + inset * 0.35))
            let line = SKShapeNode(path: contour)
            line.name = "overlay.land-value.ground-contour"
            line.fillColor = .clear
            line.strokeColor = ink
            line.lineWidth = detail == .city ? 1.25 : 0.9
            line.lineCap = .round
            line.lineJoin = .round
            root.addChild(line)
        }
        return root
    }

    private func makeTrafficPressureTicks(
        color: NSColor,
        severity: Double,
        detail: CameraDetailLevel
    ) -> SKNode {
        let root = SKNode()
        let ink = color.withAlphaComponent(detail == .city ? 0.80 : 0.66)
        let pairCount = severityMarkCount(severity)
        let shoulderY = -style.tileHeight * 0.32
        for index in 0..<pairCount {
            let offset = CGFloat(index - (pairCount - 1) / 2) * 7
            for side: CGFloat in [-1, 1] {
                let x = side * (style.tileWidth * 0.14) + offset * 0.20
                let tick = SKShapeNode(path: WorldGeometryCache.line(
                    from: CGPoint(x: x - 2.5, y: shoulderY - 2),
                    to: CGPoint(x: x + 2.5, y: shoulderY + 1)
                ))
                tick.name = "overlay.traffic.pressure-tick"
                tick.fillColor = .clear
                tick.strokeColor = ink
                tick.lineWidth = detail == .city ? 1.5 : 1.05
                tick.lineCap = .round
                root.addChild(tick)
            }
        }
        return root
    }

    private func makeHappinessRipples(
        color: NSColor,
        severity: Double,
        detail: CameraDetailLevel
    ) -> SKNode {
        let root = SKNode()
        let ink = color.withAlphaComponent(detail == .city ? 0.74 : 0.60)
        let rippleCount = severityMarkCount(severity)
        let baseY = -style.tileHeight * 0.36
        for index in 0..<rippleCount {
            let halfWidth = 4 + CGFloat(index) * 3.2
            let depth = 1.8 + CGFloat(index) * 0.8
            let ripple = CGMutablePath()
            ripple.move(to: CGPoint(x: -halfWidth, y: baseY))
            ripple.addQuadCurve(
                to: CGPoint(x: halfWidth, y: baseY),
                control: CGPoint(x: 0, y: baseY - depth)
            )
            let line = SKShapeNode(path: ripple)
            line.name = "overlay.happiness.ground-ripple"
            line.fillColor = .clear
            line.strokeColor = ink
            line.lineWidth = detail == .city ? 1.35 : 0.95
            line.lineCap = .round
            root.addChild(line)
        }
        return root
    }

    private func minimumDetail(for severity: Double) -> CameraDetailLevel? {
        switch severity {
        case 0.50...:
            .city
        case 0.25...:
            .neighborhood
        case 0.08...:
            .block
        default:
            nil
        }
    }

    private func severityMarkCount(_ severity: Double) -> Int {
        switch severity {
        case 0.66...:
            3
        case 0.33...:
            2
        default:
            1
        }
    }

}

typealias OverlayRenderer = WorldOverlayRenderer
