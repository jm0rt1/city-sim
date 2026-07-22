import CoreGraphics

/// Resolves world-space points against the authoritative isometric grid without
/// allocating one invisible SpriteKit hit node per map cell.
struct IsometricGridCoordinateResolver {
    let tileWidth: CGFloat
    let tileHeight: CGFloat

    func coordinate(
        at point: CGPoint,
        gridWidth: Int,
        gridHeight: Int
    ) -> GridCoordinate? {
        guard tileWidth > 0, tileHeight > 0, gridWidth > 0, gridHeight > 0 else {
            return nil
        }

        let projectedX = point.x / (tileWidth / 2)
        let projectedY = -point.y / (tileHeight / 2)
        let floatingX = (projectedX + projectedY) / 2
        let floatingY = (projectedY - projectedX) / 2
        let baseX = Int(floatingX.rounded(.down))
        let baseY = Int(floatingY.rounded(.down))

        var matches: [(coordinate: GridCoordinate, distance: CGFloat)] = []
        for x in (baseX - 1)...(baseX + 2) {
            guard x >= 0, x < gridWidth else { continue }
            for y in (baseY - 1)...(baseY + 2) {
                guard y >= 0, y < gridHeight else { continue }
                let coordinate = GridCoordinate(x: x, y: y)
                let center = CGPoint(
                    x: CGFloat(x - y) * tileWidth / 2,
                    y: -CGFloat(x + y) * tileHeight / 2
                )
                let distance = abs(point.x - center.x) / (tileWidth / 2)
                    + abs(point.y - center.y) / (tileHeight / 2)
                if distance <= 1.000_001 {
                    matches.append((coordinate, distance))
                }
            }
        }

        return matches.min { lhs, rhs in
            if abs(lhs.distance - rhs.distance) > 0.000_001 {
                return lhs.distance < rhs.distance
            }
            let lhsDepth = lhs.coordinate.x + lhs.coordinate.y
            let rhsDepth = rhs.coordinate.x + rhs.coordinate.y
            if lhsDepth != rhsDepth { return lhsDepth > rhsDepth }
            if lhs.coordinate.y != rhs.coordinate.y {
                return lhs.coordinate.y > rhs.coordinate.y
            }
            return lhs.coordinate.x > rhs.coordinate.x
        }?.coordinate
    }
}
