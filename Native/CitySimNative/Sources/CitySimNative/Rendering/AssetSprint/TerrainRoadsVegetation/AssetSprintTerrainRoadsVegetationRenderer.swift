import AppKit
import Foundation

/// Deterministic source renderer for joined ground, road, planting, and park
/// treatments. Geometry always passes through the canonical 88x44 projector.
@MainActor
final class AssetSprintTerrainRoadsVegetationRenderer {
    let family: AssetSprintTerrainRoadsVegetationFamily

    init(family: AssetSprintTerrainRoadsVegetationFamily = .canonical) {
        self.family = family
    }

    func renderAsset(_ asset: AssetSprintTerrainAsset) -> NSBitmapImageRep? {
        if asset == .parkTreatment,
           let url = AssetSprintTerrainRoadsVegetationFamily.resourceDirectoryURL?.appendingPathComponent(asset.fileName),
           let packaged = bitmap(at: url) {
            return packaged
        }

        return render(size: family.assetCanvas, opaque: false) { [self] in
            let origin = CGPoint(x: 256, y: 154)
            switch asset {
            case .grass:
                drawGround(.grass, origin: origin)
            case .lawn:
                drawGround(.lawn, origin: origin)
            case .plaza:
                drawGround(.plaza, origin: origin)
            case .industrialYard:
                drawGround(.industrialYard, origin: origin)
            case .roadStraight:
                drawRoad(.straight, origin: origin)
            case .roadCorner:
                drawRoad(.corner, origin: origin)
            case .roadIntersection:
                drawRoad(.intersection, origin: origin)
            case .vegetationCluster:
                drawGround(.lawn, origin: origin)
                drawTree(x: 0.78, y: 1.02, height: 2.2, origin: origin, crown: Palette.leafGold)
                drawTree(x: 2.15, y: 1.62, height: 2.75, origin: origin, crown: Palette.leaf)
                drawTree(x: 1.36, y: 2.48, height: 1.8, origin: origin, crown: Palette.leafDark)
                for point in [(0.48, 2.55), (1.02, 2.82), (2.55, 0.72), (2.72, 2.35)] {
                    drawShrub(x: point.0, y: point.1, origin: origin)
                }
            case .streetDressingCluster:
                drawGround(.plaza, origin: origin)
                drawBench(x: 0.62, y: 1.18, origin: origin)
                drawLamp(x: 2.38, y: 0.72, origin: origin)
                drawPlanter(x: 2.25, y: 2.18, origin: origin)
                drawBollards(origin: origin)
            case .parkTreatment:
                break
            }
        }
    }

    func renderRepresentativeBlock(size: CGSize) -> NSBitmapImageRep? {
        guard let sourceURL = AssetSprintTerrainRoadsVegetationFamily.resourceDirectoryURL?
            .appendingPathComponent("cedar-market-ground-system-source.png"),
            let source = NSImage(contentsOf: sourceURL)
        else { return nil }

        return render(size: size, opaque: true) {
            NSColor(calibratedRed: 0.26, green: 0.35, blue: 0.39, alpha: 1).setFill()
            NSRect(origin: .zero, size: size).fill()
            let inset: CGFloat = min(size.width * 0.035, 34)
            let available = CGSize(width: size.width - inset * 2, height: size.height - inset * 2)
            let factor = min(available.width / source.size.width, available.height / source.size.height)
            let drawSize = CGSize(width: source.size.width * factor, height: source.size.height * factor)
            let destination = CGRect(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            source.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    func pngData(for image: NSBitmapImageRep) -> Data? {
        image.representation(using: .png, properties: [:])
    }

    private enum GroundKind { case grass, lawn, plaza, industrialYard }
    private enum RoadKind { case straight, corner, intersection }

    private func drawGround(_ kind: GroundKind, origin: CGPoint) {
        let base = isoPolygon([(0, 0, 0), (4, 0, 0), (4, 4, 0), (0, 4, 0)], origin: origin)
        shadow(base, offset: CGSize(width: 16, height: -10), alpha: 0.22)
        let fillColor: NSColor
        switch kind {
        case .grass: fillColor = Palette.grass
        case .lawn: fillColor = Palette.lawn
        case .plaza: fillColor = Palette.plaza
        case .industrialYard: fillColor = Palette.gravel
        }
        fill(base, fillColor, stroke: Palette.edge, line: 1.5)

        switch kind {
        case .grass, .lawn:
            for index in 0..<48 {
                let x = CGFloat((index * 37) % 360) / 90 + 0.05
                let y = CGFloat((index * 61) % 360) / 90 + 0.05
                let point = family.reference.project(x: x, y: y, z: 0.025, origin: origin)
                let color = index.isMultiple(of: 3) ? Palette.grassHighlight : Palette.grassShadow
                line(from: point, to: CGPoint(x: point.x + 2, y: point.y + 4), color: color.withAlphaComponent(0.42), width: 0.75)
            }
        case .plaza:
            for row in 0...10 {
                let y = CGFloat(row) * 0.38
                let a = family.reference.project(x: 0, y: y, z: 0.025, origin: origin)
                let b = family.reference.project(x: 4, y: y, z: 0.025, origin: origin)
                line(from: a, to: b, color: Palette.mortar.withAlphaComponent(0.65), width: 0.8)
            }
            for column in 0...10 {
                let x = CGFloat(column) * 0.38
                let a = family.reference.project(x: x, y: 0, z: 0.027, origin: origin)
                let b = family.reference.project(x: x, y: 4, z: 0.027, origin: origin)
                line(from: a, to: b, color: Palette.mortar.withAlphaComponent(0.52), width: 0.75)
            }
        case .industrialYard:
            for index in 0..<70 {
                let x = CGFloat((index * 43) % 375) / 94 + 0.03
                let y = CGFloat((index * 71) % 375) / 94 + 0.03
                let point = family.reference.project(x: x, y: y, z: 0.026, origin: origin)
                let radius = CGFloat(index % 3) * 0.6 + 0.6
                fill(NSBezierPath(ovalIn: CGRect(x: point.x - radius, y: point.y - radius / 2, width: radius * 2, height: radius)), Palette.aggregate.withAlphaComponent(0.34))
            }
            let stain = isoPolygon([(0.7, 0.8, 0.028), (2.2, 0.9, 0.028), (2.5, 1.65, 0.028), (0.9, 1.55, 0.028)], origin: origin)
            fill(stain, Palette.yardStain.withAlphaComponent(0.22))
        }
    }

    private func drawRoad(_ kind: RoadKind, origin: CGPoint) {
        drawGround(.plaza, origin: origin)
        let strips: [(CGFloat, CGFloat, CGFloat, CGFloat)]
        switch kind {
        case .straight:
            strips = [(1.25, 0, 1.5, 4)]
        case .corner:
            strips = [(1.25, 0, 1.5, 2.75), (1.25, 1.25, 2.75, 1.5)]
        case .intersection:
            strips = [(1.25, 0, 1.5, 4), (0, 1.25, 4, 1.5)]
        }
        for strip in strips { drawRoadStrip(strip, origin: origin) }
        drawLaneMarks(kind, origin: origin)
        if kind == .intersection { drawCrosswalks(origin: origin) }
    }

    private func drawRoadStrip(_ rect: (CGFloat, CGFloat, CGFloat, CGFloat), origin: CGPoint) {
        let (x, y, width, depth) = rect
        let curb = isoPolygon([(x - 0.10, y - 0.10, 0.05), (x + width + 0.10, y - 0.10, 0.05), (x + width + 0.10, y + depth + 0.10, 0.05), (x - 0.10, y + depth + 0.10, 0.05)], origin: origin)
        fill(curb, Palette.curb, stroke: Palette.edge.withAlphaComponent(0.6), line: 0.8)
        let road = isoPolygon([(x, y, 0.06), (x + width, y, 0.06), (x + width, y + depth, 0.06), (x, y + depth, 0.06)], origin: origin)
        fill(road, Palette.asphalt, stroke: Palette.asphaltEdge, line: 0.9)
        for index in 0..<22 {
            let px = x + CGFloat((index * 17) % 90) / 90 * width
            let py = y + CGFloat((index * 29) % 90) / 90 * depth
            let point = family.reference.project(x: px, y: py, z: 0.066, origin: origin)
            fill(NSBezierPath(ovalIn: CGRect(x: point.x, y: point.y, width: 1.3, height: 0.7)), Palette.asphaltSpeck.withAlphaComponent(0.30))
        }
    }

    private func drawLaneMarks(_ kind: RoadKind, origin: CGPoint) {
        if kind == .straight || kind == .intersection {
            for y in stride(from: CGFloat(0.20), through: 3.65, by: 0.58) {
                drawMark(x: 1.95, y: y, width: 0.10, depth: 0.28, origin: origin)
            }
        }
        if kind == .corner || kind == .intersection {
            for x in stride(from: kind == .corner ? CGFloat(1.5) : 0.20, through: 3.65, by: 0.58) {
                drawMark(x: x, y: 1.95, width: 0.28, depth: 0.10, origin: origin)
            }
        }
    }

    private func drawMark(x: CGFloat, y: CGFloat, width: CGFloat, depth: CGFloat, origin: CGPoint) {
        let mark = isoPolygon([(x, y, 0.072), (x + width, y, 0.072), (x + width, y + depth, 0.072), (x, y + depth, 0.072)], origin: origin)
        fill(mark, Palette.lane.withAlphaComponent(0.80))
    }

    private func drawCrosswalks(origin: CGPoint) {
        for offset in stride(from: CGFloat(0.55), through: 1.05, by: 0.12) {
            drawMark(x: offset, y: 1.32, width: 0.055, depth: 0.52, origin: origin)
            drawMark(x: 2.82, y: offset, width: 0.52, depth: 0.055, origin: origin)
        }
    }

    private func drawTree(x: CGFloat, y: CGFloat, height: CGFloat, origin: CGPoint, crown: NSColor) {
        let base = family.reference.project(x: x, y: y, z: 0.05, origin: origin)
        let top = family.reference.project(x: x, y: y, z: height, origin: origin)
        line(from: base, to: top, color: Palette.trunkShadow, width: 8)
        line(from: CGPoint(x: base.x - 1, y: base.y), to: CGPoint(x: top.x - 1, y: top.y), color: Palette.trunk, width: 4)
        shadow(NSBezierPath(ovalIn: CGRect(x: top.x - 31, y: top.y - 20, width: 66, height: 46)), offset: CGSize(width: 9, height: -6), alpha: 0.16)
        for blob in [(-17.0, -2.0, 34.0), (10.0, 2.0, 38.0), (-2.0, 17.0, 42.0), (0.0, -13.0, 36.0)] {
            let oval = NSBezierPath(ovalIn: CGRect(x: top.x + blob.0 - blob.2 / 2, y: top.y + blob.1 - blob.2 / 2, width: blob.2, height: blob.2 * 0.78))
            fill(oval, blob.0 < 0 ? crown.highlighted(1.08) : crown.shadowed(0.78), stroke: Palette.leafEdge, line: 0.7)
        }
    }

    private func drawShrub(x: CGFloat, y: CGFloat, origin: CGPoint) {
        let p = family.reference.project(x: x, y: y, z: 0.12, origin: origin)
        for dx in [-9.0, 0.0, 9.0] {
            fill(NSBezierPath(ovalIn: CGRect(x: p.x + dx - 8, y: p.y - 5, width: 18, height: 13)), dx < 0 ? Palette.leaf : Palette.leafDark, stroke: Palette.leafEdge, line: 0.45)
        }
    }

    private func drawBench(x: CGFloat, y: CGFloat, origin: CGPoint) {
        let p = family.reference.project(x: x, y: y, z: 0.15, origin: origin)
        let seat = NSBezierPath(roundedRect: CGRect(x: p.x - 24, y: p.y - 4, width: 48, height: 9), xRadius: 3, yRadius: 3)
        fill(seat, Palette.wood, stroke: Palette.edge, line: 0.8)
        line(from: CGPoint(x: p.x - 20, y: p.y - 5), to: CGPoint(x: p.x - 20, y: p.y - 15), color: Palette.metal, width: 3)
        line(from: CGPoint(x: p.x + 20, y: p.y - 5), to: CGPoint(x: p.x + 20, y: p.y - 15), color: Palette.metal, width: 3)
    }

    private func drawLamp(x: CGFloat, y: CGFloat, origin: CGPoint) {
        let base = family.reference.project(x: x, y: y, z: 0.05, origin: origin)
        let top = family.reference.project(x: x, y: y, z: 2.4, origin: origin)
        line(from: base, to: top, color: Palette.metalDark, width: 5)
        fill(NSBezierPath(ovalIn: CGRect(x: base.x - 8, y: base.y - 4, width: 16, height: 8)), Palette.metalDark)
        let lamp = NSBezierPath(roundedRect: CGRect(x: top.x - 11, y: top.y - 8, width: 22, height: 22), xRadius: 4, yRadius: 4)
        fill(lamp, Palette.lampGlow, stroke: Palette.metalDark, line: 2)
    }

    private func drawPlanter(x: CGFloat, y: CGFloat, origin: CGPoint) {
        let p = family.reference.project(x: x, y: y, z: 0.08, origin: origin)
        let box = NSBezierPath(roundedRect: CGRect(x: p.x - 20, y: p.y - 8, width: 40, height: 16), xRadius: 3, yRadius: 3)
        fill(box, Palette.terracotta, stroke: Palette.edge, line: 0.8)
        for dx in [-12.0, -4.0, 5.0, 13.0] {
            fill(NSBezierPath(ovalIn: CGRect(x: p.x + dx - 5, y: p.y + 3, width: 10, height: 9)), dx < 0 ? Palette.leaf : Palette.flower)
        }
    }

    private func drawBollards(origin: CGPoint) {
        for x in [0.65, 1.2, 1.75] {
            let p = family.reference.project(x: x, y: 2.8, z: 0.1, origin: origin)
            line(from: p, to: CGPoint(x: p.x, y: p.y + 17), color: Palette.metalDark, width: 5)
            fill(NSBezierPath(ovalIn: CGRect(x: p.x - 3.5, y: p.y + 13, width: 7, height: 7)), Palette.brass)
        }
    }

    private func render(size: CGSize, opaque: Bool, drawing: () -> Void) -> NSBitmapImageRep? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        bitmap.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.shouldAntialias = true
        if !opaque { NSColor.clear.setFill(); NSRect(origin: .zero, size: size).fill() }
        drawing()
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    private func bitmap(at url: URL) -> NSBitmapImageRep? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        return image.representations.compactMap { $0 as? NSBitmapImageRep }.first
    }

    private func isoPolygon(_ points: [(CGFloat, CGFloat, CGFloat)], origin: CGPoint) -> NSBezierPath {
        polygon(points.map { family.reference.project(x: $0.0, y: $0.1, z: $0.2, origin: origin) })
    }

    private func polygon(_ points: [CGPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.line(to: $0) }
        path.close()
        return path
    }

    private func fill(_ path: NSBezierPath, _ color: NSColor, stroke: NSColor? = nil, line: CGFloat = 0) {
        color.setFill(); path.fill()
        if let stroke, line > 0 { stroke.setStroke(); path.lineWidth = line; path.stroke() }
    }

    private func line(from: CGPoint, to: CGPoint, color: NSColor, width: CGFloat) {
        let path = NSBezierPath(); path.move(to: from); path.line(to: to)
        color.setStroke(); path.lineWidth = width; path.lineCapStyle = .round; path.stroke()
    }

    private func shadow(_ path: NSBezierPath, offset: CGSize, alpha: CGFloat) {
        let copy = path.copy() as! NSBezierPath
        let transform = AffineTransform(translationByX: offset.width, byY: offset.height)
        copy.transform(using: transform)
        Palette.shadow.withAlphaComponent(alpha).setFill(); copy.fill()
    }

    private enum Palette {
        static let edge = NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.18, alpha: 1)
        static let shadow = NSColor(calibratedWhite: 0.08, alpha: 1)
        static let grass = NSColor(calibratedRed: 0.38, green: 0.50, blue: 0.25, alpha: 1)
        static let lawn = NSColor(calibratedRed: 0.48, green: 0.60, blue: 0.32, alpha: 1)
        static let grassHighlight = NSColor(calibratedRed: 0.66, green: 0.72, blue: 0.38, alpha: 1)
        static let grassShadow = NSColor(calibratedRed: 0.21, green: 0.34, blue: 0.18, alpha: 1)
        static let plaza = NSColor(calibratedRed: 0.72, green: 0.47, blue: 0.32, alpha: 1)
        static let mortar = NSColor(calibratedRed: 0.89, green: 0.73, blue: 0.57, alpha: 1)
        static let gravel = NSColor(calibratedRed: 0.48, green: 0.44, blue: 0.38, alpha: 1)
        static let aggregate = NSColor(calibratedRed: 0.78, green: 0.70, blue: 0.57, alpha: 1)
        static let yardStain = NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.13, alpha: 1)
        static let curb = NSColor(calibratedRed: 0.80, green: 0.72, blue: 0.61, alpha: 1)
        static let asphalt = NSColor(calibratedRed: 0.19, green: 0.21, blue: 0.22, alpha: 1)
        static let asphaltEdge = NSColor(calibratedRed: 0.34, green: 0.36, blue: 0.35, alpha: 1)
        static let asphaltSpeck = NSColor(calibratedRed: 0.55, green: 0.53, blue: 0.48, alpha: 1)
        static let lane = NSColor(calibratedRed: 0.92, green: 0.69, blue: 0.22, alpha: 1)
        static let trunk = NSColor(calibratedRed: 0.40, green: 0.24, blue: 0.13, alpha: 1)
        static let trunkShadow = NSColor(calibratedRed: 0.20, green: 0.13, blue: 0.09, alpha: 1)
        static let leaf = NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.22, alpha: 1)
        static let leafDark = NSColor(calibratedRed: 0.20, green: 0.39, blue: 0.18, alpha: 1)
        static let leafGold = NSColor(calibratedRed: 0.62, green: 0.58, blue: 0.20, alpha: 1)
        static let leafEdge = NSColor(calibratedRed: 0.17, green: 0.29, blue: 0.13, alpha: 1)
        static let wood = NSColor(calibratedRed: 0.57, green: 0.30, blue: 0.14, alpha: 1)
        static let metal = NSColor(calibratedRed: 0.18, green: 0.35, blue: 0.34, alpha: 1)
        static let metalDark = NSColor(calibratedRed: 0.11, green: 0.25, blue: 0.26, alpha: 1)
        static let lampGlow = NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.30, alpha: 1)
        static let terracotta = NSColor(calibratedRed: 0.63, green: 0.31, blue: 0.18, alpha: 1)
        static let flower = NSColor(calibratedRed: 0.87, green: 0.57, blue: 0.48, alpha: 1)
        static let brass = NSColor(calibratedRed: 0.81, green: 0.61, blue: 0.24, alpha: 1)
    }
}

private extension NSColor {
    func shadowed(_ factor: CGFloat) -> NSColor {
        guard let rgb = usingColorSpace(.deviceRGB) else { return self }
        return NSColor(red: rgb.redComponent * factor, green: rgb.greenComponent * factor, blue: rgb.blueComponent * factor, alpha: rgb.alphaComponent)
    }

    func highlighted(_ factor: CGFloat) -> NSColor {
        guard let rgb = usingColorSpace(.deviceRGB) else { return self }
        return NSColor(red: min(1, rgb.redComponent * factor), green: min(1, rgb.greenComponent * factor), blue: min(1, rgb.blueComponent * factor), alpha: rgb.alphaComponent)
    }
}
