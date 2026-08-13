import AppKit
import Foundation

/// Deterministic source renderer for the original Cedar Market reference
/// family. It intentionally uses a single world projection for every object.
/// The output is usable as a composed reference plate and as category sprites
/// while the production families are expanded in parallel.
@MainActor
final class AssetSprintReferenceRenderer {
    let family: AssetSprintReferenceFamily

    init(family: AssetSprintReferenceFamily = .canonical) {
        self.family = family
    }

    func renderNeighborhood(size: CGSize = CGSize(width: 1_280, height: 800)) -> NSBitmapImageRep? {
        render(size: size, opaque: true) { [self] in
            drawBackdrop(size: size)
            let origin = CGPoint(x: size.width * 0.49, y: size.height * 0.13)
            drawGround(origin: origin)
            drawRoads(origin: origin)

            // Back-to-front painter order, shared across every family.
            drawUtility(x: 8.2, y: 7.2, origin: origin)
            drawCivic(x: 4.8, y: 7.0, origin: origin)
            drawRowhouses(x: 1.0, y: 7.1, origin: origin, facade: Palette.blue)
            drawApartments(x: 7.7, y: 4.6, origin: origin)
            drawMarket(x: 4.6, y: 4.4, origin: origin)
            drawRowhouses(x: 0.9, y: 4.4, origin: origin, facade: Palette.cream)
            drawRowhouses(x: 7.5, y: 1.2, origin: origin, facade: Palette.rose)
            drawCafe(x: 4.5, y: 1.1, origin: origin)
            drawRowhouses(x: 1.0, y: 1.2, origin: origin, facade: Palette.sage)

            drawNeighborhoodDetails(origin: origin)
        }
    }

    func renderAsset(_ asset: AssetSprintReferenceAsset, size: CGSize = CGSize(width: 512, height: 512)) -> NSBitmapImageRep? {
        render(size: size, opaque: false) { [self] in
            let origin = CGPoint(x: size.width * 0.50, y: size.height * 0.24)
            drawLotBase(x: 1, y: 1, width: 3.25, depth: 3.25, origin: origin)
            switch asset {
            case .residential:
                drawRowhouses(x: 1.3, y: 1.35, origin: origin, facade: Palette.blue)
            case .commercial:
                drawMarket(x: 1.2, y: 1.2, origin: origin)
            case .civic:
                drawCivic(x: 1.2, y: 1.15, origin: origin)
            case .utility:
                drawUtility(x: 1.3, y: 1.3, origin: origin)
            case .terrainRoads:
                drawRoadKit(origin: CGPoint(x: size.width * 0.5, y: size.height * 0.22))
            }
        }
    }

    func pngData(for image: NSBitmapImageRep) -> Data? {
        image.representation(using: .png, properties: [:])
    }

    private func render(size: CGSize, opaque: Bool, drawing: () -> Void) -> NSBitmapImageRep? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        bitmap.size = size
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.shouldAntialias = true
        if !opaque { NSColor.clear.setFill(); NSRect(origin: .zero, size: size).fill() }
        drawing()
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    private func drawBackdrop(size: CGSize) {
        let gradient = NSGradient(colors: [Palette.skyTop, Palette.skyBottom])!
        gradient.draw(in: NSRect(origin: .zero, size: size), angle: 90)
        Palette.haze.withAlphaComponent(0.22).setFill()
        NSBezierPath(ovalIn: CGRect(x: 140, y: 580, width: 1_000, height: 170)).fill()
    }

    private func drawGround(origin: CGPoint) {
        let outer = isoPolygon([(0, 0, 0), (12, 0, 0), (12, 10, 0), (0, 10, 0)], origin: origin)
        shadow(of: outer, offset: CGSize(width: 24, height: -18), alpha: 0.23)
        fill(outer, Palette.grassDark, stroke: Palette.edge, line: 2)

        let inner = isoPolygon([(0.18, 0.18, 0.02), (11.82, 0.18, 0.02), (11.82, 9.82, 0.02), (0.18, 9.82, 0.02)], origin: origin)
        fill(inner, Palette.grass, stroke: Palette.grassLight.withAlphaComponent(0.5), line: 1)

        // Three large joined lots, avoiding the empty checkerboard treatment.
        for rectangle in [
            (0.45, 0.45, 3.25, 8.9), (4.1, 0.45, 3.75, 8.9), (8.25, 0.45, 3.3, 8.9)
        ] {
            drawLotBase(x: rectangle.0, y: rectangle.1, width: rectangle.2, depth: rectangle.3, origin: origin)
        }
    }

    private func drawRoads(origin: CGPoint) {
        drawRoadStrip(x: 3.62, y: 0.15, width: 0.68, depth: 9.7, origin: origin)
        drawRoadStrip(x: 7.72, y: 0.15, width: 0.68, depth: 9.7, origin: origin)
        drawRoadStrip(x: 0.15, y: 3.55, width: 11.7, depth: 0.72, origin: origin)
        drawRoadStrip(x: 0.15, y: 6.50, width: 11.7, depth: 0.72, origin: origin)

        for x in stride(from: 0.8, through: 11.2, by: 1.15) {
            drawRoadDash(x: x, y: 3.88, horizontal: true, origin: origin)
            drawRoadDash(x: x, y: 6.84, horizontal: true, origin: origin)
        }
        for y in stride(from: 0.75, through: 9.2, by: 1.15) {
            drawRoadDash(x: 3.94, y: y, horizontal: false, origin: origin)
            drawRoadDash(x: 8.04, y: y, horizontal: false, origin: origin)
        }

        for crosswalk in [(3.94, 3.9), (8.04, 3.9), (3.94, 6.84), (8.04, 6.84)] {
            drawCrosswalk(x: crosswalk.0, y: crosswalk.1, origin: origin)
        }
    }

    private func drawLotBase(x: CGFloat, y: CGFloat, width: CGFloat, depth: CGFloat, origin: CGPoint) {
        let lot = isoPolygon([(x, y, 0.025), (x + width, y, 0.025), (x + width, y + depth, 0.025), (x, y + depth, 0.025)], origin: origin)
        fill(lot, Palette.lawn, stroke: Palette.edge.withAlphaComponent(0.48), line: 0.8)
        let walk = isoPolygon([(x + 0.12, y + 0.12, 0.035), (x + width - 0.12, y + 0.12, 0.035), (x + width - 0.12, y + depth - 0.12, 0.035), (x + 0.12, y + depth - 0.12, 0.035)], origin: origin)
        stroke(walk, Palette.walk, line: 4.2)
    }

    private func drawRoadStrip(x: CGFloat, y: CGFloat, width: CGFloat, depth: CGFloat, origin: CGPoint) {
        let curb = isoPolygon([(x - 0.11, y - 0.11, 0.06), (x + width + 0.11, y - 0.11, 0.06), (x + width + 0.11, y + depth + 0.11, 0.06), (x - 0.11, y + depth + 0.11, 0.06)], origin: origin)
        fill(curb, Palette.curb, stroke: Palette.edge.withAlphaComponent(0.55), line: 0.8)
        let road = isoPolygon([(x, y, 0.07), (x + width, y, 0.07), (x + width, y + depth, 0.07), (x, y + depth, 0.07)], origin: origin)
        fill(road, Palette.asphalt, stroke: Palette.asphaltLight, line: 0.8)
    }

    private func drawRoadDash(x: CGFloat, y: CGFloat, horizontal: Bool, origin: CGPoint) {
        let w: CGFloat = horizontal ? 0.38 : 0.08
        let d: CGFloat = horizontal ? 0.08 : 0.38
        let path = isoPolygon([(x, y, 0.08), (x + w, y, 0.08), (x + w, y + d, 0.08), (x, y + d, 0.08)], origin: origin)
        fill(path, Palette.lane.withAlphaComponent(0.72))
    }

    private func drawCrosswalk(x: CGFloat, y: CGFloat, origin: CGPoint) {
        for offset in stride(from: -0.25, through: 0.25, by: 0.12) {
            let stripe = isoPolygon([
                (x - 0.34, y + offset, 0.085), (x + 0.34, y + offset, 0.085),
                (x + 0.34, y + offset + 0.055, 0.085), (x - 0.34, y + offset + 0.055, 0.085)
            ], origin: origin)
            fill(stripe, Palette.crosswalk.withAlphaComponent(0.78))
        }
    }

    private func drawRowhouses(x: CGFloat, y: CGFloat, origin: CGPoint, facade: NSColor) {
        drawBuildingBox(x: x, y: y, width: 2.45, depth: 1.62, height: 2.15, origin: origin, front: facade, side: facade.shadowed(0.74), roof: Palette.roofBlue)
        drawGableRoof(x: x, y: y, width: 2.45, depth: 1.62, wallHeight: 2.15, roofHeight: 0.78, origin: origin, color: Palette.roofBlue)
        for bay in [0.42, 1.12, 1.82] {
            drawWindowOnFront(x: x + bay, y: y, z: 0.78, origin: origin, lit: bay != 1.12)
            drawWindowOnFront(x: x + bay, y: y, z: 1.52, origin: origin, lit: bay == 1.12)
        }
        drawDoorOnFront(x: x + 1.12, y: y, origin: origin, color: Palette.door)
        drawChimney(x: x + 1.85, y: y + 1.12, z: 2.66, origin: origin)
        drawShrub(x: x + 0.28, y: y - 0.12, origin: origin)
        drawShrub(x: x + 2.18, y: y - 0.12, origin: origin)
    }

    private func drawApartments(x: CGFloat, y: CGFloat, origin: CGPoint) {
        drawBuildingBox(x: x, y: y, width: 2.75, depth: 1.9, height: 3.65, origin: origin, front: Palette.brick, side: Palette.brick.shadowed(0.68), roof: Palette.roofFlat)
        drawFlatRoof(x: x, y: y, width: 2.75, depth: 1.9, height: 3.65, origin: origin)
        for floor in 0..<3 {
            for bay in [0.38, 1.05, 1.72, 2.38] {
                drawWindowOnFront(x: x + bay, y: y, z: 0.72 + CGFloat(floor) * 0.92, origin: origin, lit: (floor + Int(bay * 10)) % 3 == 0)
            }
        }
        drawAwning(x: x + 0.88, y: y - 0.05, width: 1.05, z: 0.82, origin: origin, color: Palette.teal)
        drawPlanter(x: x + 0.30, y: y - 0.22, origin: origin)
        drawPlanter(x: x + 2.48, y: y - 0.22, origin: origin)
    }

    private func drawMarket(x: CGFloat, y: CGFloat, origin: CGPoint) {
        drawBuildingBox(x: x, y: y, width: 2.85, depth: 1.82, height: 2.55, origin: origin, front: Palette.ochre, side: Palette.ochre.shadowed(0.72), roof: Palette.roofFlat)
        drawFlatRoof(x: x, y: y, width: 2.85, depth: 1.82, height: 2.55, origin: origin)
        for bay in [0.35, 1.02, 1.69, 2.36] {
            drawWindowOnFront(x: x + bay, y: y, z: 1.58, origin: origin, lit: true)
        }
        for awningX in [0.20, 1.15, 2.10] {
            drawAwning(x: x + awningX, y: y - 0.06, width: 0.76, z: 0.88, origin: origin, color: awningX == 1.15 ? Palette.cream : Palette.rust)
        }
        drawRoofUnit(x: x + 1.1, y: y + 0.78, z: 2.65, origin: origin)
        drawPlanter(x: x + 0.15, y: y - 0.24, origin: origin)
        drawPlanter(x: x + 2.66, y: y - 0.24, origin: origin)
    }

    private func drawCafe(x: CGFloat, y: CGFloat, origin: CGPoint) {
        drawBuildingBox(x: x, y: y, width: 2.55, depth: 1.7, height: 2.25, origin: origin, front: Palette.teal, side: Palette.teal.shadowed(0.70), roof: Palette.roofFlat)
        drawFlatRoof(x: x, y: y, width: 2.55, depth: 1.7, height: 2.25, origin: origin)
        for bay in [0.28, 0.92, 1.56, 2.20] {
            drawWindowOnFront(x: x + bay, y: y, z: 1.40, origin: origin, lit: bay > 1)
        }
        drawAwning(x: x + 0.18, y: y - 0.06, width: 2.18, z: 0.86, origin: origin, color: Palette.coral)
        drawPlanter(x: x + 0.12, y: y - 0.28, origin: origin)
        drawCafeTables(x: x + 1.8, y: y - 0.52, origin: origin)
    }

    private func drawCivic(x: CGFloat, y: CGFloat, origin: CGPoint) {
        drawBuildingBox(x: x, y: y, width: 2.75, depth: 2.0, height: 2.25, origin: origin, front: Palette.stone, side: Palette.stone.shadowed(0.77), roof: Palette.roofBlue)
        drawGableRoof(x: x, y: y, width: 2.75, depth: 2.0, wallHeight: 2.25, roofHeight: 0.82, origin: origin, color: Palette.roofBlue)
        drawPortico(x: x + 0.72, y: y - 0.18, width: 1.3, origin: origin)
        drawCupola(x: x + 1.37, y: y + 1.0, z: 3.05, origin: origin)
        for bay in [0.38, 2.35] {
            drawWindowOnFront(x: x + bay, y: y, z: 1.18, origin: origin, lit: true)
        }
        drawFlag(x: x + 1.37, y: y + 1.0, z: 4.28, origin: origin)
    }

    private func drawUtility(x: CGFloat, y: CGFloat, origin: CGPoint) {
        drawBuildingBox(x: x, y: y, width: 2.45, depth: 1.75, height: 1.48, origin: origin, front: Palette.utility, side: Palette.utility.shadowed(0.70), roof: Palette.roofFlat)
        drawFlatRoof(x: x, y: y, width: 2.45, depth: 1.75, height: 1.48, origin: origin)
        let center = family.project(x: x + 1.25, y: y + 0.9, z: 1.52, origin: origin)
        drawWaterTower(center: center)
        drawPipe(x: x + 0.34, y: y - 0.08, origin: origin)
        drawFence(x: x + 2.30, y: y + 0.15, length: 1.35, origin: origin)
    }

    private func drawBuildingBox(x: CGFloat, y: CGFloat, width: CGFloat, depth: CGFloat, height: CGFloat, origin: CGPoint, front: NSColor, side: NSColor, roof: NSColor) {
        let footprint = isoPolygon([(x, y, 0), (x + width, y, 0), (x + width, y + depth, 0), (x, y + depth, 0)], origin: origin)
        shadow(of: footprint, offset: CGSize(width: family.shadowOffset.dx, height: family.shadowOffset.dy), alpha: 0.28)
        let frontFace = isoPolygon([(x, y, 0), (x + width, y, 0), (x + width, y, height), (x, y, height)], origin: origin)
        let sideFace = isoPolygon([(x + width, y, 0), (x + width, y + depth, 0), (x + width, y + depth, height), (x + width, y, height)], origin: origin)
        let top = isoPolygon([(x, y, height), (x + width, y, height), (x + width, y + depth, height), (x, y + depth, height)], origin: origin)
        fill(sideFace, side, stroke: Palette.edge, line: 1.0)
        fill(frontFace, front, stroke: Palette.edge, line: 1.0)
        fill(top, roof, stroke: Palette.edge, line: 1.1)
    }

    private func drawGableRoof(x: CGFloat, y: CGFloat, width: CGFloat, depth: CGFloat, wallHeight: CGFloat, roofHeight: CGFloat, origin: CGPoint, color: NSColor) {
        let ridgeY = y + depth / 2
        let leftPlane = isoPolygon([(x, y, wallHeight), (x + width, y, wallHeight), (x + width, ridgeY, wallHeight + roofHeight), (x, ridgeY, wallHeight + roofHeight)], origin: origin)
        let rightPlane = isoPolygon([(x, ridgeY, wallHeight + roofHeight), (x + width, ridgeY, wallHeight + roofHeight), (x + width, y + depth, wallHeight), (x, y + depth, wallHeight)], origin: origin)
        fill(rightPlane, color.shadowed(0.72), stroke: Palette.edge, line: 1)
        fill(leftPlane, color, stroke: Palette.edge, line: 1)
        for t in stride(from: CGFloat(0.18), through: width - 0.1, by: 0.35) {
            let a = family.project(x: x + t, y: y + 0.08, z: wallHeight + 0.05, origin: origin)
            let b = family.project(x: x + t, y: ridgeY, z: wallHeight + roofHeight + 0.02, origin: origin)
            line(from: a, to: b, color: Palette.roofLine.withAlphaComponent(0.50), width: 0.55)
        }
    }

    private func drawFlatRoof(x: CGFloat, y: CGFloat, width: CGFloat, depth: CGFloat, height: CGFloat, origin: CGPoint) {
        let inset: CGFloat = 0.13
        let parapet = isoPolygon([(x + inset, y + inset, height + 0.10), (x + width - inset, y + inset, height + 0.10), (x + width - inset, y + depth - inset, height + 0.10), (x + inset, y + depth - inset, height + 0.10)], origin: origin)
        stroke(parapet, Palette.roofEdge, line: 2.1)
    }

    private func drawWindowOnFront(x: CGFloat, y: CGFloat, z: CGFloat, origin: CGPoint, lit: Bool) {
        let center = family.project(x: x, y: y - 0.012, z: z, origin: origin)
        let window = NSBezierPath(rect: CGRect(x: center.x - 7, y: center.y - 9, width: 14, height: 18))
        fill(window, lit ? Palette.windowLit : Palette.window, stroke: Palette.windowFrame, line: 1.4)
        line(from: CGPoint(x: center.x, y: center.y - 8), to: CGPoint(x: center.x, y: center.y + 8), color: Palette.windowFrame, width: 0.8)
    }

    private func drawDoorOnFront(x: CGFloat, y: CGFloat, origin: CGPoint, color: NSColor) {
        let center = family.project(x: x, y: y - 0.02, z: 0.45, origin: origin)
        let door = NSBezierPath(rect: CGRect(x: center.x - 8, y: center.y - 10, width: 16, height: 28))
        fill(door, color, stroke: Palette.edge, line: 1.1)
        Palette.brass.setFill(); NSBezierPath(ovalIn: CGRect(x: center.x + 3, y: center.y + 3, width: 2.5, height: 2.5)).fill()
    }

    private func drawAwning(x: CGFloat, y: CGFloat, width: CGFloat, z: CGFloat, origin: CGPoint, color: NSColor) {
        let a = family.project(x: x, y: y, z: z, origin: origin)
        let b = family.project(x: x + width, y: y, z: z, origin: origin)
        let path = polygon([a, b, CGPoint(x: b.x + 5, y: b.y - 9), CGPoint(x: a.x + 5, y: a.y - 9)])
        fill(path, color, stroke: Palette.edge, line: 0.8)
        for t in stride(from: CGFloat(0.15), through: width, by: 0.32) {
            let top = family.project(x: x + t, y: y, z: z, origin: origin)
            line(from: top, to: CGPoint(x: top.x + 5, y: top.y - 8), color: Palette.cream.withAlphaComponent(0.8), width: 2.4)
        }
    }

    private func drawPortico(x: CGFloat, y: CGFloat, width: CGFloat, origin: CGPoint) {
        let roof = isoPolygon([(x, y, 1.30), (x + width, y, 1.30), (x + width, y + 0.38, 1.30), (x, y + 0.38, 1.30)], origin: origin)
        fill(roof, Palette.stoneLight, stroke: Palette.edge, line: 1)
        for columnX in [x + 0.12, x + width - 0.12] {
            let base = family.project(x: columnX, y: y, z: 0, origin: origin)
            let top = family.project(x: columnX, y: y, z: 1.30, origin: origin)
            line(from: base, to: top, color: Palette.stoneLight, width: 5.5)
            line(from: base, to: top, color: Palette.edge.withAlphaComponent(0.5), width: 0.8)
        }
    }

    private func drawCupola(x: CGFloat, y: CGFloat, z: CGFloat, origin: CGPoint) {
        let center = family.project(x: x, y: y, z: z, origin: origin)
        fill(NSBezierPath(rect: CGRect(x: center.x - 15, y: center.y - 10, width: 30, height: 24)), Palette.stoneLight, stroke: Palette.edge, line: 1)
        for dx in [-8.0, 0.0, 8.0] {
            fill(NSBezierPath(rect: CGRect(x: center.x + dx - 2, y: center.y - 4, width: 4, height: 11)), Palette.window, stroke: Palette.edge, line: 0.5)
        }
        let dome = NSBezierPath()
        dome.move(to: CGPoint(x: center.x - 18, y: center.y + 13))
        dome.curve(to: CGPoint(x: center.x + 18, y: center.y + 13), controlPoint1: CGPoint(x: center.x - 12, y: center.y + 37), controlPoint2: CGPoint(x: center.x + 12, y: center.y + 37))
        dome.close()
        fill(dome, Palette.copper, stroke: Palette.edge, line: 1)
    }

    private func drawWaterTower(center: CGPoint) {
        for dx in [-18.0, 18.0] {
            line(from: CGPoint(x: center.x + dx, y: center.y - 78), to: CGPoint(x: center.x + dx * 0.52, y: center.y - 5), color: Palette.metalDark, width: 4)
        }
        line(from: CGPoint(x: center.x - 18, y: center.y - 58), to: CGPoint(x: center.x + 18, y: center.y - 34), color: Palette.metalDark, width: 2)
        line(from: CGPoint(x: center.x + 18, y: center.y - 58), to: CGPoint(x: center.x - 18, y: center.y - 34), color: Palette.metalDark, width: 2)
        let tank = NSBezierPath(roundedRect: CGRect(x: center.x - 35, y: center.y - 10, width: 70, height: 48), xRadius: 20, yRadius: 20)
        fill(tank, Palette.metal, stroke: Palette.edge, line: 1.3)
        let highlight = NSBezierPath(ovalIn: CGRect(x: center.x - 24, y: center.y + 17, width: 48, height: 15))
        fill(highlight, Palette.metalLight.withAlphaComponent(0.6))
        line(from: CGPoint(x: center.x, y: center.y + 38), to: CGPoint(x: center.x, y: center.y + 52), color: Palette.metalDark, width: 2)
    }

    private func drawRoofUnit(x: CGFloat, y: CGFloat, z: CGFloat, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: z, origin: origin)
        let box = NSBezierPath(rect: CGRect(x: p.x - 13, y: p.y - 7, width: 26, height: 15))
        fill(box, Palette.metal, stroke: Palette.edge, line: 0.9)
        for dx in [-7.0, 0.0, 7.0] { line(from: CGPoint(x: p.x + dx, y: p.y - 5), to: CGPoint(x: p.x + dx, y: p.y + 6), color: Palette.metalDark, width: 1) }
    }

    private func drawChimney(x: CGFloat, y: CGFloat, z: CGFloat, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: z, origin: origin)
        fill(NSBezierPath(rect: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 19)), Palette.brickDark, stroke: Palette.edge, line: 0.8)
        line(from: CGPoint(x: p.x - 5, y: p.y + 15), to: CGPoint(x: p.x + 5, y: p.y + 15), color: Palette.stoneLight, width: 2)
    }

    private func drawFlag(x: CGFloat, y: CGFloat, z: CGFloat, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: z, origin: origin)
        line(from: p, to: CGPoint(x: p.x, y: p.y + 31), color: Palette.metalLight, width: 1.5)
        let flag = polygon([CGPoint(x: p.x, y: p.y + 29), CGPoint(x: p.x + 23, y: p.y + 22), CGPoint(x: p.x, y: p.y + 15)])
        fill(flag, Palette.coral, stroke: Palette.edge, line: 0.6)
    }

    private func drawPipe(x: CGFloat, y: CGFloat, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: 0.18, origin: origin)
        let pipe = NSBezierPath(roundedRect: CGRect(x: p.x - 4, y: p.y, width: 9, height: 24), xRadius: 4, yRadius: 4)
        fill(pipe, Palette.rust, stroke: Palette.edge, line: 0.8)
    }

    private func drawFence(x: CGFloat, y: CGFloat, length: CGFloat, origin: CGPoint) {
        for t in stride(from: CGFloat(0), through: length, by: 0.22) {
            let p = family.project(x: x, y: y + t, z: 0, origin: origin)
            line(from: p, to: CGPoint(x: p.x, y: p.y + 15), color: Palette.metalDark, width: 1)
        }
    }

    private func drawNeighborhoodDetails(origin: CGPoint) {
        let treeSites: [(CGFloat, CGFloat, CGFloat)] = [
            (0.55, 0.65, 0.9), (3.18, 2.85, 0.75), (0.60, 5.58, 0.88),
            (2.95, 8.78, 0.72), (4.43, 8.95, 0.82), (7.38, 8.76, 0.78),
            (8.72, 5.72, 0.72), (11.20, 8.75, 0.92), (11.25, 5.25, 0.78),
            (10.88, 2.82, 0.72), (7.42, 0.72, 0.76), (4.38, 0.70, 0.74)
        ]
        for (x, y, scale) in treeSites { drawTree(x: x, y: y, scale: scale, origin: origin) }

        for site in [(2.9, 3.40), (6.1, 3.42), (9.9, 3.42), (2.2, 6.36), (6.2, 6.36), (10.2, 6.36)] {
            drawLamp(x: site.0, y: site.1, origin: origin)
        }
        drawCar(x: 5.65, y: 3.82, color: Palette.coral, origin: origin)
        drawCar(x: 9.45, y: 6.76, color: Palette.blue, origin: origin)
        drawCar(x: 3.82, y: 7.65, color: Palette.mustard, origin: origin)
        drawPedestrian(x: 3.32, y: 3.30, coat: Palette.teal, origin: origin)
        drawPedestrian(x: 8.55, y: 4.30, coat: Palette.coral, origin: origin)
        drawPedestrian(x: 6.90, y: 6.28, coat: Palette.blue, origin: origin)
    }

    private func drawTree(x: CGFloat, y: CGFloat, scale: CGFloat, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: 0.05, origin: origin)
        let shadow = NSBezierPath(ovalIn: CGRect(x: p.x - 16 * scale + 8, y: p.y - 7 * scale - 5, width: 38 * scale, height: 14 * scale))
        fill(shadow, Palette.edge.withAlphaComponent(0.23))
        line(from: p, to: CGPoint(x: p.x, y: p.y + 31 * scale), color: Palette.trunk, width: 5 * scale)
        for crown in [
            CGRect(x: p.x - 20 * scale, y: p.y + 18 * scale, width: 29 * scale, height: 30 * scale),
            CGRect(x: p.x - 4 * scale, y: p.y + 23 * scale, width: 31 * scale, height: 33 * scale),
            CGRect(x: p.x - 12 * scale, y: p.y + 38 * scale, width: 28 * scale, height: 28 * scale)
        ] {
            fill(NSBezierPath(ovalIn: crown), Palette.tree, stroke: Palette.treeDark, line: 0.8)
        }
        fill(NSBezierPath(ovalIn: CGRect(x: p.x - 8 * scale, y: p.y + 42 * scale, width: 16 * scale, height: 13 * scale)), Palette.treeLight.withAlphaComponent(0.72))
    }

    private func drawShrub(x: CGFloat, y: CGFloat, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: 0.05, origin: origin)
        for dx in [-5.0, 2.0, 8.0] {
            fill(NSBezierPath(ovalIn: CGRect(x: p.x + dx - 6, y: p.y - 2, width: 13, height: 12)), Palette.shrub, stroke: Palette.treeDark, line: 0.5)
        }
    }

    private func drawPlanter(x: CGFloat, y: CGFloat, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: 0.04, origin: origin)
        fill(NSBezierPath(roundedRect: CGRect(x: p.x - 8, y: p.y - 3, width: 18, height: 8), xRadius: 2, yRadius: 2), Palette.terracotta, stroke: Palette.edge, line: 0.6)
        for dx in [-4.0, 1.0, 5.0] { fill(NSBezierPath(ovalIn: CGRect(x: p.x + dx - 3, y: p.y + 2, width: 7, height: 8)), dx == 1 ? Palette.flower : Palette.shrub) }
    }

    private func drawLamp(x: CGFloat, y: CGFloat, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: 0.05, origin: origin)
        line(from: p, to: CGPoint(x: p.x, y: p.y + 28), color: Palette.metalDark, width: 2)
        fill(NSBezierPath(ovalIn: CGRect(x: p.x - 5, y: p.y + 24, width: 10, height: 8)), Palette.lamp, stroke: Palette.edge, line: 0.6)
    }

    private func drawCar(x: CGFloat, y: CGFloat, color: NSColor, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: 0.10, origin: origin)
        let body = polygon([CGPoint(x: p.x - 14, y: p.y - 5), CGPoint(x: p.x + 15, y: p.y + 2), CGPoint(x: p.x + 10, y: p.y + 12), CGPoint(x: p.x - 10, y: p.y + 8)])
        shadow(of: body, offset: CGSize(width: 4, height: -4), alpha: 0.22)
        fill(body, color, stroke: Palette.edge, line: 0.8)
        let glass = polygon([CGPoint(x: p.x - 5, y: p.y + 5), CGPoint(x: p.x + 7, y: p.y + 8), CGPoint(x: p.x + 4, y: p.y + 12), CGPoint(x: p.x - 3, y: p.y + 10)])
        fill(glass, Palette.window)
    }

    private func drawPedestrian(x: CGFloat, y: CGFloat, coat: NSColor, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: 0.06, origin: origin)
        fill(NSBezierPath(ovalIn: CGRect(x: p.x - 3, y: p.y - 2, width: 9, height: 4)), Palette.edge.withAlphaComponent(0.24))
        fill(NSBezierPath(ovalIn: CGRect(x: p.x - 3, y: p.y + 7, width: 7, height: 12)), coat, stroke: Palette.edge, line: 0.5)
        fill(NSBezierPath(ovalIn: CGRect(x: p.x - 2, y: p.y + 17, width: 6, height: 6)), Palette.skin, stroke: Palette.edge, line: 0.4)
    }

    private func drawCafeTables(x: CGFloat, y: CGFloat, origin: CGPoint) {
        for offset in [0.0, 0.48] {
            let p = family.project(x: x + offset, y: y, z: 0.05, origin: origin)
            fill(NSBezierPath(ovalIn: CGRect(x: p.x - 8, y: p.y + 5, width: 17, height: 8)), Palette.cream, stroke: Palette.edge, line: 0.6)
            line(from: CGPoint(x: p.x, y: p.y + 5), to: CGPoint(x: p.x, y: p.y - 5), color: Palette.edge, width: 1.2)
            line(from: CGPoint(x: p.x, y: p.y + 13), to: CGPoint(x: p.x, y: p.y + 36), color: Palette.edge, width: 1)
            let umbrella = polygon([CGPoint(x: p.x - 15, y: p.y + 28), CGPoint(x: p.x, y: p.y + 42), CGPoint(x: p.x + 15, y: p.y + 28)])
            fill(umbrella, offset == 0 ? Palette.mustard : Palette.coral, stroke: Palette.edge, line: 0.6)
        }
    }

    private func drawRoadKit(origin: CGPoint) {
        let base = isoPolygon([(0, 0, 0), (5, 0, 0), (5, 5, 0), (0, 5, 0)], origin: origin)
        fill(base, Palette.grass, stroke: Palette.edge, line: 1.4)
        drawRoadStrip(x: 2.05, y: 0.1, width: 0.90, depth: 4.8, origin: origin)
        drawRoadStrip(x: 0.1, y: 2.05, width: 4.8, depth: 0.90, origin: origin)
        drawCrosswalk(x: 2.5, y: 2.5, origin: origin)
        drawTree(x: 0.85, y: 3.75, scale: 0.9, origin: origin)
        drawLamp(x: 3.55, y: 1.2, origin: origin)
        drawPlanter(x: 0.9, y: 0.7, origin: origin)
    }

    private func isoPolygon(_ points: [(CGFloat, CGFloat, CGFloat)], origin: CGPoint) -> NSBezierPath {
        polygon(points.map { family.project(x: $0.0, y: $0.1, z: $0.2, origin: origin) })
    }

    private func polygon(_ points: [CGPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.line(to: point) }
        path.close()
        return path
    }

    private func fill(_ path: NSBezierPath, _ color: NSColor, stroke: NSColor? = nil, line: CGFloat = 0) {
        color.setFill(); path.fill()
        if let stroke, line > 0 { stroke.setStroke(); path.lineWidth = line; path.stroke() }
    }

    private func stroke(_ path: NSBezierPath, _ color: NSColor, line: CGFloat) {
        color.setStroke(); path.lineWidth = line; path.stroke()
    }

    private func line(from: CGPoint, to: CGPoint, color: NSColor, width: CGFloat) {
        let path = NSBezierPath(); path.move(to: from); path.line(to: to)
        color.setStroke(); path.lineWidth = width; path.stroke()
    }

    private func shadow(of path: NSBezierPath, offset: CGSize, alpha: CGFloat) {
        let copy = path.copy() as! NSBezierPath
        let transform = AffineTransform(translationByX: offset.width, byY: offset.height)
        copy.transform(using: transform)
        fill(copy, Palette.edge.withAlphaComponent(alpha))
    }
}

private extension NSColor {
    func shadowed(_ factor: CGFloat) -> NSColor {
        guard let rgb = usingColorSpace(.deviceRGB) else { return self }
        return NSColor(red: rgb.redComponent * factor, green: rgb.greenComponent * factor, blue: rgb.blueComponent * factor, alpha: rgb.alphaComponent)
    }
}

private enum Palette {
    static let skyTop = NSColor(calibratedRed: 0.15, green: 0.23, blue: 0.25, alpha: 1)
    static let skyBottom = NSColor(calibratedRed: 0.43, green: 0.48, blue: 0.42, alpha: 1)
    static let haze = NSColor(calibratedRed: 0.78, green: 0.67, blue: 0.49, alpha: 1)
    static let grassDark = NSColor(calibratedRed: 0.26, green: 0.37, blue: 0.25, alpha: 1)
    static let grass = NSColor(calibratedRed: 0.42, green: 0.55, blue: 0.34, alpha: 1)
    static let grassLight = NSColor(calibratedRed: 0.60, green: 0.70, blue: 0.42, alpha: 1)
    static let lawn = NSColor(calibratedRed: 0.52, green: 0.61, blue: 0.40, alpha: 1)
    static let walk = NSColor(calibratedRed: 0.77, green: 0.72, blue: 0.62, alpha: 1)
    static let curb = NSColor(calibratedRed: 0.62, green: 0.60, blue: 0.54, alpha: 1)
    static let asphalt = NSColor(calibratedRed: 0.19, green: 0.21, blue: 0.22, alpha: 1)
    static let asphaltLight = NSColor(calibratedRed: 0.29, green: 0.31, blue: 0.31, alpha: 1)
    static let lane = NSColor(calibratedRed: 0.90, green: 0.69, blue: 0.28, alpha: 1)
    static let crosswalk = NSColor(calibratedRed: 0.91, green: 0.88, blue: 0.76, alpha: 1)
    static let edge = NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.15, alpha: 1)
    static let blue = NSColor(calibratedRed: 0.28, green: 0.48, blue: 0.58, alpha: 1)
    static let cream = NSColor(calibratedRed: 0.82, green: 0.73, blue: 0.55, alpha: 1)
    static let rose = NSColor(calibratedRed: 0.66, green: 0.38, blue: 0.34, alpha: 1)
    static let sage = NSColor(calibratedRed: 0.43, green: 0.57, blue: 0.45, alpha: 1)
    static let brick = NSColor(calibratedRed: 0.60, green: 0.29, blue: 0.20, alpha: 1)
    static let brickDark = NSColor(calibratedRed: 0.43, green: 0.20, blue: 0.15, alpha: 1)
    static let ochre = NSColor(calibratedRed: 0.72, green: 0.43, blue: 0.18, alpha: 1)
    static let teal = NSColor(calibratedRed: 0.12, green: 0.45, blue: 0.43, alpha: 1)
    static let coral = NSColor(calibratedRed: 0.79, green: 0.30, blue: 0.20, alpha: 1)
    static let mustard = NSColor(calibratedRed: 0.88, green: 0.62, blue: 0.18, alpha: 1)
    static let stone = NSColor(calibratedRed: 0.72, green: 0.67, blue: 0.56, alpha: 1)
    static let stoneLight = NSColor(calibratedRed: 0.88, green: 0.82, blue: 0.68, alpha: 1)
    static let utility = NSColor(calibratedRed: 0.46, green: 0.48, blue: 0.46, alpha: 1)
    static let roofBlue = NSColor(calibratedRed: 0.21, green: 0.29, blue: 0.38, alpha: 1)
    static let roofFlat = NSColor(calibratedRed: 0.34, green: 0.32, blue: 0.29, alpha: 1)
    static let roofLine = NSColor(calibratedRed: 0.58, green: 0.62, blue: 0.64, alpha: 1)
    static let roofEdge = NSColor(calibratedRed: 0.67, green: 0.58, blue: 0.46, alpha: 1)
    static let window = NSColor(calibratedRed: 0.25, green: 0.48, blue: 0.57, alpha: 1)
    static let windowLit = NSColor(calibratedRed: 0.96, green: 0.72, blue: 0.31, alpha: 1)
    static let windowFrame = NSColor(calibratedRed: 0.87, green: 0.82, blue: 0.70, alpha: 1)
    static let door = NSColor(calibratedRed: 0.39, green: 0.16, blue: 0.12, alpha: 1)
    static let brass = NSColor(calibratedRed: 0.91, green: 0.70, blue: 0.25, alpha: 1)
    static let copper = NSColor(calibratedRed: 0.25, green: 0.52, blue: 0.48, alpha: 1)
    static let metal = NSColor(calibratedRed: 0.59, green: 0.65, blue: 0.64, alpha: 1)
    static let metalLight = NSColor(calibratedRed: 0.79, green: 0.83, blue: 0.80, alpha: 1)
    static let metalDark = NSColor(calibratedRed: 0.24, green: 0.29, blue: 0.29, alpha: 1)
    static let rust = NSColor(calibratedRed: 0.68, green: 0.28, blue: 0.14, alpha: 1)
    static let tree = NSColor(calibratedRed: 0.24, green: 0.47, blue: 0.19, alpha: 1)
    static let treeDark = NSColor(calibratedRed: 0.14, green: 0.31, blue: 0.13, alpha: 1)
    static let treeLight = NSColor(calibratedRed: 0.55, green: 0.67, blue: 0.25, alpha: 1)
    static let shrub = NSColor(calibratedRed: 0.27, green: 0.53, blue: 0.20, alpha: 1)
    static let trunk = NSColor(calibratedRed: 0.36, green: 0.22, blue: 0.13, alpha: 1)
    static let terracotta = NSColor(calibratedRed: 0.66, green: 0.31, blue: 0.18, alpha: 1)
    static let flower = NSColor(calibratedRed: 0.87, green: 0.36, blue: 0.52, alpha: 1)
    static let lamp = NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.38, alpha: 1)
    static let skin = NSColor(calibratedRed: 0.77, green: 0.56, blue: 0.40, alpha: 1)
}
