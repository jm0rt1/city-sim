import AppKit
import SpriteKit

/// A steady screen-sized pointer to the selected authored building. The source
/// alpha mask supplies the roof location; neither the art nor its pivot changes.
@MainActor
final class CityInspectionMarker {
    let node = SKNode()

    init() {
        node.name = "interaction.inspection-marker"
        node.zPosition = 90_002
        node.isHidden = true
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: -8, y: 10))
        path.addCurve(to: CGPoint(x: 0, y: 24),
                      control1: CGPoint(x: -15, y: 20), control2: CGPoint(x: -7, y: 24))
        path.addCurve(to: CGPoint(x: 8, y: 10),
                      control1: CGPoint(x: 7, y: 24), control2: CGPoint(x: 15, y: 20))
        path.closeSubpath()
        let rim = SKShapeNode(path: path)
        rim.fillColor = .clear
        rim.strokeColor = NSColor(calibratedWhite: 0.08, alpha: 0.9)
        rim.lineWidth = 5
        rim.lineJoin = .round
        node.addChild(rim)
        let pin = SKShapeNode(path: path)
        pin.fillColor = NSColor(calibratedRed: 0.25, green: 0.95, blue: 0.78, alpha: 1)
        pin.strokeColor = .white
        pin.lineWidth = 2
        pin.lineJoin = .round
        pin.zPosition = 1
        node.addChild(pin)
        let center = SKShapeNode(circleOfRadius: 3)
        center.position.y = 15
        center.fillColor = .white
        center.strokeColor = .clear
        center.zPosition = 2
        node.addChild(center)
    }

    func update(selectedRoot: SKNode?, cameraScale: CGFloat) {
        guard let selectedRoot, let plane = node.parent,
              let roof = Self.roofPosition(of: selectedRoot, in: plane) else {
            node.isHidden = true
            return
        }
        node.position = roof
        node.position.y += 4 * cameraScale
        node.setScale(cameraScale)
        node.isHidden = false
    }

    static func roofPosition(of root: SKNode, in plane: SKNode) -> CGPoint? {
        guard let sprite = visibleSprite(in: root), let roof = sprite.roofAnchor else { return nil }
        return sprite.convert(roof, to: plane)
    }

    private static func visibleSprite(in node: SKNode) -> FourViewInspectionSprite? {
        guard !node.isHidden, node.alpha >= 0.5 else { return nil }
        if let sprite = node as? FourViewInspectionSprite { return sprite }
        return node.children.lazy.compactMap { visibleSprite(in: $0) }.first
    }
}
