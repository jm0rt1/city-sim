import AppKit
import SpriteKit

enum WorldOverlayPattern: String, Sendable {
    case utilityEdge
    case pollutionHatch
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
        guard isDeveloped(tile),
              let consequence,
              consequence.coordinate == tile.coordinate else {
            return nil
        }

        switch overlay {
        case .utilities:
            return makeSample(consequence.utility.combined, pattern: .utilityEdge)
        case .pollution:
            return makeSample(1 - consequence.pollutionExposure, pattern: .pollutionHatch)
        case .none, .landValue, .traffic, .happiness:
            // These modes do not yet have approved coordinate-scoped analytics. Rendering
            // an inferred value here would turn presentation code into gameplay authority.
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
        let ink = color.withAlphaComponent(detail == .city ? 0.76 : 0.64)
        let hatchCount = severityMarkCount(severity)
        let verticalOffset = style.tileHeight / 18
        for index in 0..<hatchCount {
            let x = CGFloat(index - (hatchCount - 1) / 2) * 8
            let hatch = SKShapeNode(path: WorldGeometryCache.line(
                from: CGPoint(x: x - 5, y: verticalOffset),
                to: CGPoint(x: x + 3, y: verticalOffset + 6)
            ))
            hatch.name = "overlay.pollution.exposure-hatch"
            hatch.fillColor = .clear
            hatch.strokeColor = ink
            hatch.lineWidth = detail == .city ? 1.5 : 1.1
            hatch.lineCap = .round
            root.addChild(hatch)
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

    private func isDeveloped(_ tile: CityTile) -> Bool {
        tile.kind != .empty && tile.kind != .road
    }
}

typealias OverlayRenderer = WorldOverlayRenderer
