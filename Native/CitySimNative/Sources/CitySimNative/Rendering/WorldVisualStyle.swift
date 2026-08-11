import AppKit
import SpriteKit

private func worldSRGB(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

enum RenderQuality: Int, CaseIterable, Sendable {
    case low
    case medium
    case high

    fileprivate func limiting(_ detail: CameraDetailLevel) -> CameraDetailLevel {
        switch (self, detail) {
        case (.low, .block): .neighborhood
        default: detail
        }
    }
}

enum CameraDetailLevel: Int, CaseIterable, Comparable, Sendable {
    case city
    case neighborhood
    case block

    /// SpriteKit camera scales grow as the camera zooms out.
    static let blockMaximumCameraScale: CGFloat = 0.60
    static let neighborhoodMaximumCameraScale: CGFloat = 0.70

    static func resolve(
        cameraScale: CGFloat,
        quality: RenderQuality = .high
    ) -> CameraDetailLevel {
        let resolved: CameraDetailLevel
        if cameraScale <= blockMaximumCameraScale {
            resolved = .block
        } else if cameraScale <= neighborhoodMaximumCameraScale {
            resolved = .neighborhood
        } else {
            resolved = .city
        }
        return quality.limiting(resolved)
    }

    static func < (lhs: CameraDetailLevel, rhs: CameraDetailLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var layerName: String {
        switch self {
        case .city: "detail.city"
        case .neighborhood: "detail.neighborhood"
        case .block: "detail.block"
        }
    }

    func includes(_ layer: CameraDetailLevel) -> Bool {
        rawValue >= layer.rawValue
    }
}

/// Stable visual randomness that deliberately avoids Swift's randomized `Hasher`,
/// the simulation seed, and incidental SpriteKit state.
enum WorldVisualSeed {
    private static let offsetBasis: UInt64 = 0xcbf29ce484222325
    private static let prime: UInt64 = 0x100000001b3

    static func value(
        for coordinate: GridCoordinate,
        kind: BuildingKind,
        salt: UInt64 = 0
    ) -> UInt64 {
        var hash = offsetBasis
        mix(UInt64(bitPattern: Int64(coordinate.x)), into: &hash)
        mix(UInt64(bitPattern: Int64(coordinate.y)), into: &hash)
        for byte in kind.rawValue.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        mix(salt, into: &hash)

        // MurmurHash3's finalizer gives nearby coordinates good visual separation.
        hash ^= hash >> 33
        hash &*= 0xff51afd7ed558ccd
        hash ^= hash >> 33
        hash &*= 0xc4ceb9fe1a85ec53
        hash ^= hash >> 33
        return hash
    }

    static func variant(
        count: Int,
        for coordinate: GridCoordinate,
        kind: BuildingKind,
        salt: UInt64 = 0
    ) -> Int {
        guard count > 0 else { return 0 }
        return Int(value(for: coordinate, kind: kind, salt: salt) % UInt64(count))
    }

    static func unit(
        for coordinate: GridCoordinate,
        kind: BuildingKind,
        salt: UInt64 = 0
    ) -> CGFloat {
        let sample = value(for: coordinate, kind: kind, salt: salt) >> 11
        return CGFloat(Double(sample) / Double(1 << 53))
    }

    private static func mix(_ value: UInt64, into hash: inout UInt64) {
        for shift in stride(from: 0, through: 56, by: 8) {
            hash ^= (value >> UInt64(shift)) & 0xff
            hash &*= prime
        }
    }
}

@MainActor
final class WorldGeometryCache {
    private struct DiamondKey: Hashable {
        let width: Int
        let height: Int
    }

    private var diamonds: [DiamondKey: CGPath] = [:]

    func diamond(width: CGFloat, height: CGFloat) -> CGPath {
        let key = DiamondKey(width: Int((width * 100).rounded()), height: Int((height * 100).rounded()))
        if let cached = diamonds[key] { return cached }
        let path = WorldGeometryCache.polygon([
            CGPoint(x: 0, y: height / 2),
            CGPoint(x: width / 2, y: 0),
            CGPoint(x: 0, y: -height / 2),
            CGPoint(x: -width / 2, y: 0)
        ])
        diamonds[key] = path
        return path
    }

    static func polygon(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    static func line(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

@MainActor
struct WorldVisualStyle {
    struct Palette {
        let backdrop = NSColor(calibratedRed: 0.035, green: 0.075, blue: 0.085, alpha: 1)
        let backdropHalo = NSColor(calibratedRed: 0.12, green: 0.28, blue: 0.25, alpha: 0.32)
        let mapRim = worldSRGB(0x54634D)
        let mapEarth = worldSRGB(0x473B2B)
        let mapEarthDark = worldSRGB(0x1C1A14)

        let grass = [
            worldSRGB(0x5C6B4F),
            worldSRGB(0x667557),
            worldSRGB(0x52614A),
            worldSRGB(0x707A5C)
        ]
        let lotGrass = worldSRGB(0x5E6B52)
        let parkGrass = NSColor(calibratedRed: 0.18, green: 0.50, blue: 0.285, alpha: 1)
        let parkPath = NSColor(calibratedRed: 0.77, green: 0.67, blue: 0.49, alpha: 1)
        let soil = worldSRGB(0x614A36)
        let concrete = worldSRGB(0x857D70)
        let concreteLight = worldSRGB(0xADA391)

        let asphalt = worldSRGB(0x262626)
        let asphaltLight = worldSRGB(0x3B3836)
        let curb = worldSRGB(0x948C7D)
        let sidewalk = worldSRGB(0x756E61)
        let laneMark = worldSRGB(0xD6A64D, alpha: 0.9)
        let crosswalk = NSColor(calibratedWhite: 0.92, alpha: 0.82)

        let residential = [
            NSColor(calibratedRed: 0.38, green: 0.66, blue: 0.76, alpha: 1),
            NSColor(calibratedRed: 0.79, green: 0.59, blue: 0.42, alpha: 1),
            NSColor(calibratedRed: 0.52, green: 0.70, blue: 0.56, alpha: 1)
        ]
        let commercial = [
            NSColor(calibratedRed: 0.37, green: 0.55, blue: 0.78, alpha: 1),
            NSColor(calibratedRed: 0.47, green: 0.39, blue: 0.69, alpha: 1),
            NSColor(calibratedRed: 0.29, green: 0.64, blue: 0.66, alpha: 1)
        ]
        let industrial = [
            NSColor(calibratedRed: 0.66, green: 0.43, blue: 0.25, alpha: 1),
            NSColor(calibratedRed: 0.48, green: 0.50, blue: 0.48, alpha: 1),
            NSColor(calibratedRed: 0.69, green: 0.53, blue: 0.25, alpha: 1)
        ]
        let civicStone = NSColor(calibratedRed: 0.72, green: 0.74, blue: 0.70, alpha: 1)
        let civicRoof = NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.43, alpha: 1)
        let roofDark = NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.22, alpha: 1)
        let roofWarm = NSColor(calibratedRed: 0.48, green: 0.20, blue: 0.15, alpha: 1)
        let foliage = [
            NSColor(calibratedRed: 0.12, green: 0.39, blue: 0.22, alpha: 1),
            NSColor(calibratedRed: 0.17, green: 0.51, blue: 0.27, alpha: 1),
            NSColor(calibratedRed: 0.25, green: 0.59, blue: 0.30, alpha: 1)
        ]
        let trunk = NSColor(calibratedRed: 0.31, green: 0.205, blue: 0.12, alpha: 1)
        let glass = NSColor(calibratedRed: 0.38, green: 0.75, blue: 0.84, alpha: 0.88)
        let warmWindow = NSColor(calibratedRed: 1.0, green: 0.79, blue: 0.38, alpha: 0.9)
        let shadow = NSColor.black.withAlphaComponent(0.30)
    }

    let tileWidth: CGFloat
    let tileHeight: CGFloat
    let quality: RenderQuality
    let palette: Palette
    let geometry: WorldGeometryCache

    init(
        tileWidth: CGFloat = 72,
        tileHeight: CGFloat = 36,
        quality: RenderQuality = .high,
        geometry: WorldGeometryCache = WorldGeometryCache()
    ) {
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.quality = quality
        self.palette = Palette()
        self.geometry = geometry
    }

    func diamondPath(width: CGFloat? = nil, height: CGFloat? = nil) -> CGPath {
        geometry.diamond(width: width ?? tileWidth, height: height ?? tileHeight)
    }

    func polygonPath(_ points: [CGPoint]) -> CGPath {
        WorldGeometryCache.polygon(points)
    }

    func isoPosition(_ coordinate: GridCoordinate) -> CGPoint {
        CGPoint(
            x: CGFloat(coordinate.x - coordinate.y) * tileWidth / 2,
            y: -CGFloat(coordinate.x + coordinate.y) * tileHeight / 2
        )
    }

    func depth(for coordinate: GridCoordinate) -> CGFloat {
        CGFloat(coordinate.x + coordinate.y) * 100
    }

    func detailLevel(cameraScale: CGFloat) -> CameraDetailLevel {
        CameraDetailLevel.resolve(cameraScale: cameraScale, quality: quality)
    }

    func edgePoint(for edge: RoadConnectionMask, inset: CGFloat = 0) -> CGPoint {
        let x = max(0, tileWidth / 2 - inset)
        let y = max(0, tileHeight / 2 - inset / 2)
        return switch edge {
        case .north: CGPoint(x: x, y: y)
        case .east: CGPoint(x: x, y: -y)
        case .south: CGPoint(x: -x, y: -y)
        case .west: CGPoint(x: -x, y: y)
        default: .zero
        }
    }

    /// Reciprocal road/frontage socket at the midpoint between neighboring
    /// isometric tile centers. A small positive overreach hides antialias seams
    /// while preserving one authoritative topology connection per edge.
    func roadSocket(for edge: RoadConnectionMask, overreach: CGFloat = 0) -> CGPoint {
        let x = tileWidth / 4 + overreach
        let y = tileHeight / 4 + overreach / 2
        return switch edge {
        case .north: CGPoint(x: x, y: y)
        case .east: CGPoint(x: x, y: -y)
        case .south: CGPoint(x: -x, y: -y)
        case .west: CGPoint(x: -x, y: y)
        default: .zero
        }
    }

    func makeDetailLayer(_ level: CameraDetailLevel, visibleAt detail: CameraDetailLevel) -> SKNode {
        let node = SKNode()
        node.name = level.layerName
        node.isHidden = !detail.includes(level)
        return node
    }

    func updateDetailVisibility(in root: SKNode, detail: CameraDetailLevel) {
        for level in CameraDetailLevel.allCases {
            root.enumerateChildNodes(withName: "//\(level.layerName)") { node, _ in
                node.isHidden = !detail.includes(level)
            }
        }
    }
}
