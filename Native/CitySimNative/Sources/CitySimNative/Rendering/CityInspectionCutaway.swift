import SpriteKit

/// A temporary interaction treatment, never a change to source art or lot geometry.
@MainActor
final class CityInspectionCutaway {
    private var faded: [(sprite: FourViewInspectionSprite, alpha: CGFloat)] = []

    func update(selectedRoot: SKNode?, roots: [SKNode], in plane: SKNode, groundHeight: CGFloat) {
        for entry in faded { entry.sprite.alpha = entry.alpha }
        faded.removeAll(keepingCapacity: true)
        guard let selectedRoot,
              let selected = visibleSprite(in: selectedRoot) else { return }

        // Exclude the lot's ground/shadow: adjacent pavement is not an obstruction.
        let selectedBounds = bounds(of: selected, in: plane)
        let bottom = max(selectedBounds.minY, selectedRoot.position.y + groundHeight / 4)
        let buildingBounds = CGRect(x: selectedBounds.minX, y: bottom,
                                    width: selectedBounds.width,
                                    height: max(0, selectedBounds.maxY - bottom))
        let selectedDepth = depth(of: selected, in: plane)
        for root in roots where root !== selectedRoot {
            guard let foreground = visibleSprite(in: root),
                  depth(of: foreground, in: plane) > selectedDepth else { continue }
            let overlap = buildingBounds.intersection(bounds(of: foreground, in: plane))
            guard !overlap.isNull, !overlap.isEmpty,
                  hasOpaqueOverlap(selected, foreground, within: overlap, in: plane) else { continue }
            faded.append((foreground, foreground.alpha))
            foreground.alpha *= 0.18
        }
    }

    private func visibleSprite(in node: SKNode) -> FourViewInspectionSprite? {
        guard !node.isHidden, node.alpha >= 0.5 else { return nil }
        if let sprite = node as? FourViewInspectionSprite { return sprite }
        return node.children.lazy.compactMap { self.visibleSprite(in: $0) }.first
    }

    private func depth(of node: SKNode, in plane: SKNode) -> CGFloat {
        var depth: CGFloat = 0
        var current: SKNode? = node
        while let node = current, node !== plane {
            depth += node.zPosition
            current = node.parent
        }
        return depth
    }

    private func bounds(of sprite: FourViewInspectionSprite, in plane: SKNode) -> CGRect {
        guard let parent = sprite.parent else { return .null }
        let frame = sprite.frame
        let a = parent.convert(CGPoint(x: frame.minX, y: frame.minY), to: plane)
        let b = parent.convert(CGPoint(x: frame.maxX, y: frame.maxY), to: plane)
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                      width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    private func hasOpaqueOverlap(
        _ selected: FourViewInspectionSprite,
        _ foreground: FourViewInspectionSprite,
        within bounds: CGRect,
        in plane: SKNode
    ) -> Bool {
        // Bounded source-mask sampling only when selection/world changes. No
        // texture copies, readback, per-frame actions, or transparent-padding hits.
        for y in 0..<16 {
            for x in 0..<16 {
                let point = CGPoint(x: bounds.minX + (CGFloat(x) + 0.5) * bounds.width / 16,
                                    y: bounds.minY + (CGFloat(y) + 0.5) * bounds.height / 16)
                if selected.containsOpaquePixel(at: selected.convert(point, from: plane)),
                   foreground.containsOpaquePixel(at: foreground.convert(point, from: plane)) {
                    return true
                }
            }
        }
        return false
    }
}
