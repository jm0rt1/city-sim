import AppKit
import Foundation

/// Revised Cedar Market proof built entirely in one world-coordinate system.
/// Ground, lots, roads, walls, roofs, storefronts, and street details share
/// the canonical 2:1 basis. No imported sprite, rotation, skew, or corrective
/// per-asset transform can introduce an independent camera angle.
@MainActor
final class AssetSprintIntegratedNeighborhoodRenderer {
    enum BuildingRole: String, CaseIterable, Sendable {
        case craftsman
        case rowhouses
        case apartments
        case market
        case cafe
        case library
        case cityHall
        case workshop
        case factory
        case utility
    }

    enum RoofProfile: String, Sendable {
        case gable
        case flatParapet
        case industrialMonitor
    }

    enum FacadePattern: String, Sendable {
        case clapboard
        case masonry
        case civicStone
        case storefront
        case industrial
    }

    struct BuildingStyle: Hashable, Sendable {
        let stories: Int
        let frontBays: Int
        let sideBays: Int
        let roof: RoofProfile
        let facade: FacadePattern
    }

    struct Placement: Sendable {
        let role: BuildingRole
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let depth: CGFloat
        let height: CGFloat
    }

    static let canonicalSize = CGSize(width: 1_280, height: 800)
    static let worldWidth: CGFloat = 14
    static let worldDepth: CGFloat = 10
    static let roadWidth: CGFloat = 0.74
    static let roadX: [CGFloat] = [4.02, 8.82]
    static let roadY: [CGFloat] = [3.20, 6.35]

    static let placements: [Placement] = [
        .init(role: .apartments, x: 0.65, y: 7.15, width: 2.75, depth: 1.85, height: 3.65),
        .init(role: .cityHall, x: 5.20, y: 7.16, width: 2.75, depth: 2.00, height: 2.30),
        .init(role: .factory, x: 10.05, y: 7.16, width: 2.80, depth: 1.90, height: 2.20),
        .init(role: .rowhouses, x: 0.75, y: 4.25, width: 2.55, depth: 1.55, height: 2.20),
        .init(role: .market, x: 5.05, y: 4.25, width: 2.90, depth: 1.55, height: 2.55),
        .init(role: .utility, x: 10.20, y: 4.25, width: 2.55, depth: 1.60, height: 1.55),
        .init(role: .craftsman, x: 0.85, y: 0.95, width: 2.35, depth: 1.65, height: 1.70),
        .init(role: .cafe, x: 5.20, y: 1.00, width: 2.55, depth: 1.55, height: 2.15),
        .init(role: .library, x: 9.85, y: 0.95, width: 2.80, depth: 1.75, height: 1.85),
        .init(role: .workshop, x: 10.25, y: 2.38, width: 2.45, depth: 0.45, height: 1.45),
    ]

    static func style(for role: BuildingRole) -> BuildingStyle {
        switch role {
        case .craftsman:
            .init(stories: 1, frontBays: 3, sideBays: 2, roof: .gable, facade: .clapboard)
        case .rowhouses:
            .init(stories: 2, frontBays: 4, sideBays: 2, roof: .gable, facade: .clapboard)
        case .apartments:
            .init(stories: 3, frontBays: 5, sideBays: 3, roof: .flatParapet, facade: .masonry)
        case .market:
            .init(stories: 2, frontBays: 4, sideBays: 2, roof: .flatParapet, facade: .storefront)
        case .cafe:
            .init(stories: 2, frontBays: 4, sideBays: 2, roof: .flatParapet, facade: .storefront)
        case .library:
            .init(stories: 1, frontBays: 4, sideBays: 2, roof: .gable, facade: .civicStone)
        case .cityHall:
            .init(stories: 2, frontBays: 5, sideBays: 3, roof: .gable, facade: .civicStone)
        case .workshop:
            .init(stories: 1, frontBays: 4, sideBays: 1, roof: .industrialMonitor, facade: .industrial)
        case .factory:
            .init(stories: 2, frontBays: 5, sideBays: 3, roof: .industrialMonitor, facade: .industrial)
        case .utility:
            .init(stories: 1, frontBays: 3, sideBays: 2, roof: .flatParapet, facade: .industrial)
        }
    }

    let family: AssetSprintReferenceFamily

    init(family: AssetSprintReferenceFamily = .canonical) {
        self.family = family
    }

    func render(size: CGSize) -> NSBitmapImageRep? {
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
        context.imageInterpolation = .high
        drawBackdrop(size: size)

        let sceneScale = min(size.width / Self.canonicalSize.width, size.height / Self.canonicalSize.height)
        let offset = CGPoint(
            x: (size.width - Self.canonicalSize.width * sceneScale) / 2,
            y: (size.height - Self.canonicalSize.height * sceneScale) / 2
        )
        context.cgContext.saveGState()
        context.cgContext.translateBy(x: offset.x, y: offset.y)
        context.cgContext.scaleBy(x: sceneScale, y: sceneScale)
        let origin = CGPoint(x: 640, y: 92)
        drawGround(origin: origin)
        drawRoadNetwork(origin: origin)
        drawLots(origin: origin)
        drawBuildings(origin: origin)
        drawStreetDetails(origin: origin)
        context.cgContext.restoreGState()

        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    func pngData(for bitmap: NSBitmapImageRep) -> Data? {
        bitmap.representation(using: .png, properties: [:])
    }

    private func drawBackdrop(size: CGSize) {
        NSGradient(colors: [Palette.skyTop, Palette.skyBottom])?.draw(
            in: CGRect(origin: .zero, size: size), angle: 90
        )
        Palette.haze.setFill()
        NSBezierPath(ovalIn: CGRect(x: size.width * 0.10, y: size.height * 0.69,
                                    width: size.width * 0.80, height: size.height * 0.16)).fill()
    }

    private func drawGround(origin: CGPoint) {
        let outline = isoRect(x: 0, y: 0, width: Self.worldWidth, depth: Self.worldDepth, z: 0, origin: origin)
        shadow(outline, offset: CGSize(width: 22, height: -16), alpha: 0.24)
        fill(outline, Palette.grassDark, stroke: Palette.edge, line: 2.5)
        fill(
            isoRect(x: 0.18, y: 0.18, width: 13.64, depth: 9.64, z: 0.02, origin: origin),
            Palette.grass, stroke: Palette.grassLight.withAlphaComponent(0.58), line: 1
        )
    }

    private func drawRoadNetwork(origin: CGPoint) {
        for x in Self.roadX {
            drawRoad(x: x, y: 0.16, width: Self.roadWidth, depth: 9.68, origin: origin)
        }
        for y in Self.roadY {
            drawRoad(x: 0.16, y: y, width: 13.68, depth: Self.roadWidth, origin: origin)
        }
        for y in Self.roadY {
            for x in stride(from: CGFloat(0.50), through: 13.2, by: 0.82) {
                fill(isoRect(x: x, y: y + 0.33, width: 0.34, depth: 0.08, z: 0.085, origin: origin), Palette.lane)
            }
        }
        for x in Self.roadX {
            for y in stride(from: CGFloat(0.48), through: 9.3, by: 0.82) {
                fill(isoRect(x: x + 0.33, y: y, width: 0.08, depth: 0.34, z: 0.085, origin: origin), Palette.lane)
            }
        }
        drawCrosswalk(x: Self.roadX[0], y: 2.74, acrossVerticalRoad: true, origin: origin)
        drawCrosswalk(x: 8.30, y: Self.roadY[0], acrossVerticalRoad: false, origin: origin)
        drawCrosswalk(x: Self.roadX[1], y: 7.18, acrossVerticalRoad: true, origin: origin)
        drawCrosswalk(x: 4.94, y: Self.roadY[1], acrossVerticalRoad: false, origin: origin)
    }

    private func drawRoad(x: CGFloat, y: CGFloat, width: CGFloat, depth: CGFloat, origin: CGPoint) {
        fill(
            isoRect(x: x - 0.13, y: y - 0.13, width: width + 0.26, depth: depth + 0.26, z: 0.055, origin: origin),
            Palette.curb, stroke: Palette.edge.withAlphaComponent(0.55), line: 0.8
        )
        fill(
            isoRect(x: x, y: y, width: width, depth: depth, z: 0.07, origin: origin),
            Palette.asphalt, stroke: Palette.asphaltLight, line: 0.7
        )
    }

    private func drawCrosswalk(x: CGFloat, y: CGFloat,
                               acrossVerticalRoad: Bool, origin: CGPoint) {
        for index in 0..<4 {
            if acrossVerticalRoad {
                fill(isoRect(x: x + 0.08, y: y + CGFloat(index) * 0.13,
                             width: Self.roadWidth - 0.16, depth: 0.065,
                             z: 0.092, origin: origin), Palette.crosswalk)
            } else {
                fill(isoRect(x: x + CGFloat(index) * 0.13, y: y + 0.08,
                             width: 0.065, depth: Self.roadWidth - 0.16,
                             z: 0.092, origin: origin), Palette.crosswalk)
            }
        }
    }

    private func drawLots(origin: CGPoint) {
        for placement in Self.placements {
            let margin: CGFloat = placement.role == .workshop ? 0.16 : 0.22
            let lot = isoRect(
                x: placement.x - margin, y: placement.y - margin,
                width: placement.width + margin * 2,
                depth: placement.depth + margin * 2,
                z: 0.035, origin: origin
            )
            fill(lot, lotColor(for: placement.role), stroke: Palette.edge.withAlphaComponent(0.52), line: 0.75)
            stroke(
                isoRect(
                    x: placement.x - margin + 0.08, y: placement.y - margin + 0.08,
                    width: placement.width + margin * 2 - 0.16,
                    depth: placement.depth + margin * 2 - 0.16,
                    z: 0.045, origin: origin
                ),
                Palette.walk, line: 3.1
            )
        }

        // Pocket park is geometry, not a floating imported plate.
        let park = isoRect(x: 5.10, y: 6.65, width: 2.80, depth: 0.28, z: 0.04, origin: origin)
        fill(park, Palette.park, stroke: Palette.edge.withAlphaComponent(0.45), line: 0.7)
        for x in stride(from: CGFloat(5.35), through: 7.55, by: 0.55) {
            drawShrub(x: x, y: 6.78, origin: origin)
        }
    }

    private func drawBuildings(origin: CGPoint) {
        let ordered = Self.placements.sorted {
            family.project(x: $0.x, y: $0.y, origin: origin).y
                > family.project(x: $1.x, y: $1.y, origin: origin).y
        }
        for placement in ordered { drawBuilding(placement, origin: origin) }
    }

    private func drawBuilding(_ p: Placement, origin: CGPoint) {
        let colors = colors(for: p.role)
        let style = Self.style(for: p.role)
        drawBox(p, front: colors.front, side: colors.side, roof: colors.roof, origin: origin)

        // Facade details are authored in world space first. Roof planes and
        // parapets then occlude their upper edges naturally in painter order.
        drawFacadeDetails(p, style: style, origin: origin)

        switch style.roof {
        case .gable:
            drawGableRoof(p, roofHeight: p.role == .craftsman ? 0.75 : 0.82, color: colors.roof, origin: origin)
        case .flatParapet:
            drawFlatRoof(p, origin: origin)
        case .industrialMonitor:
            drawIndustrialMonitor(p, origin: origin)
        }

        switch p.role {
        case .apartments:
            drawBalcony(x: p.x + 0.35, y: p.y - 0.04, width: 0.82, z: 1.75, origin: origin)
            drawBalcony(x: p.x + 1.55, y: p.y - 0.04, width: 0.82, z: 2.62, origin: origin)
            drawAwning(x: p.x + 0.75, y: p.y - 0.04, width: 1.15, z: 0.82, color: Palette.teal, origin: origin)
        case .market, .cafe:
            drawAwning(x: p.x + 0.18, y: p.y - 0.04, width: p.width - 0.36, z: 0.84,
                       color: p.role == .market ? Palette.rust : Palette.coral, origin: origin)
            drawFrontDoor(x: p.x + p.width * 0.52, y: p.y - 0.012, width: 0.28,
                          height: 0.72, color: Palette.door, origin: origin)
            drawFrontPanel(x: p.x + 0.24, y: p.y - 0.014, width: p.width - 0.48,
                           baseZ: 1.82, height: 0.24, color: Palette.signBand, origin: origin)
        case .cityHall:
            drawPortico(x: p.x + 0.68, y: p.y - 0.14, width: 1.35, origin: origin)
            drawCupola(x: p.x + p.width / 2, y: p.y + p.depth / 2,
                       z: p.height + 0.82, origin: origin)
        case .factory:
            drawStack(x: p.x + 0.55, y: p.y + p.depth * 0.64,
                      baseZ: p.height + 0.12, height: 1.25, origin: origin)
            drawStack(x: p.x + 1.10, y: p.y + p.depth * 0.64,
                      baseZ: p.height + 0.12, height: 1.05, origin: origin)
            drawRollupDoor(x: p.x + p.width * 0.64, y: p.y - 0.012,
                           width: 0.72, height: 1.12, origin: origin)
        case .workshop:
            drawRoofUnit(x: p.x + p.width * 0.55, y: p.y + p.depth * 0.55, z: p.height + 0.14, origin: origin)
            drawRollupDoor(x: p.x + p.width * 0.56, y: p.y - 0.012,
                           width: 0.62, height: 0.92, origin: origin)
        case .utility:
            drawTank(x: p.x + p.width * 0.72, y: p.y + p.depth * 0.62,
                     z: p.height + 0.18, origin: origin)
        case .craftsman, .rowhouses:
            drawChimney(x: p.x + p.width * 0.72, y: p.y + p.depth * 0.52,
                        baseZ: p.height + 0.28, origin: origin)
        case .library:
            drawFrontDoor(x: p.x + p.width / 2, y: p.y - 0.012, width: 0.34,
                          height: 0.78, color: Palette.door, origin: origin)
        }

        if [.craftsman, .rowhouses].contains(p.role) {
            drawFrontDoor(x: p.x + p.width / 2, y: p.y - 0.012, width: 0.30,
                          height: 0.72, color: Palette.door, origin: origin)
        }
        drawRoleGroundDetails(p, origin: origin)
    }

    private func drawBox(_ p: Placement, front: NSColor, side: NSColor, roof: NSColor, origin: CGPoint) {
        let footprint = isoRect(x: p.x, y: p.y, width: p.width, depth: p.depth, z: 0, origin: origin)
        shadow(footprint, offset: CGSize(width: family.shadowOffset.dx, height: family.shadowOffset.dy), alpha: 0.25)
        drawPrism(x: p.x, y: p.y, width: p.width, depth: p.depth,
                  baseZ: 0, height: p.height, front: front, side: side, top: roof, origin: origin)
    }

    private func drawPrism(x: CGFloat, y: CGFloat, width: CGFloat, depth: CGFloat,
                           baseZ: CGFloat, height: CGFloat, front: NSColor,
                           side: NSColor, top: NSColor, origin: CGPoint) {
        let frontFace = isoPolygon([
            (x, y, baseZ), (x + width, y, baseZ),
            (x + width, y, baseZ + height), (x, y, baseZ + height),
        ], origin: origin)
        let sideFace = isoPolygon([
            (x, y, baseZ), (x, y + depth, baseZ),
            (x, y + depth, baseZ + height), (x, y, baseZ + height),
        ], origin: origin)
        fill(sideFace, side, stroke: Palette.edge, line: 1)
        fill(frontFace, front, stroke: Palette.edge, line: 1)
        fill(isoRect(x: x, y: y, width: width, depth: depth, z: baseZ + height, origin: origin),
             top, stroke: Palette.edge, line: 1.1)
    }

    private func drawGableRoof(_ p: Placement, roofHeight: CGFloat, color: NSColor, origin: CGPoint) {
        let ridge = p.y + p.depth / 2
        let near = isoPolygon([
            (p.x, p.y, p.height), (p.x + p.width, p.y, p.height),
            (p.x + p.width, ridge, p.height + roofHeight), (p.x, ridge, p.height + roofHeight),
        ], origin: origin)
        let far = isoPolygon([
            (p.x, ridge, p.height + roofHeight), (p.x + p.width, ridge, p.height + roofHeight),
            (p.x + p.width, p.y + p.depth, p.height), (p.x, p.y + p.depth, p.height),
        ], origin: origin)
        fill(far, color.shadowed(0.72), stroke: Palette.edge, line: 1)
        fill(near, color, stroke: Palette.edge, line: 1)
        for x in stride(from: p.x + 0.18, through: p.x + p.width - 0.08, by: 0.35) {
            line(from: family.project(x: x, y: p.y + 0.06, z: p.height + 0.04, origin: origin),
                 to: family.project(x: x, y: ridge, z: p.height + roofHeight, origin: origin),
                 color: Palette.roofLine, width: 0.55)
        }
    }

    private func drawFlatRoof(_ p: Placement, origin: CGPoint) {
        drawFrontPanel(x: p.x - 0.04, y: p.y - 0.01, width: p.width + 0.08,
                       baseZ: p.height, height: 0.17, color: Palette.roofEdge, origin: origin)
        drawSidePanel(x: p.x - 0.01, y: p.y - 0.04, depth: p.depth + 0.08,
                      baseZ: p.height, height: 0.17, color: Palette.roofEdge.shadowed(0.74), origin: origin)
        stroke(
            isoRect(x: p.x + 0.12, y: p.y + 0.12, width: p.width - 0.24,
                    depth: p.depth - 0.24, z: p.height + 0.10, origin: origin),
            Palette.roofEdge, line: 2
        )
    }

    private func drawIndustrialMonitor(_ p: Placement, origin: CGPoint) {
        drawFlatRoof(p, origin: origin)
        let width = max(0.70, p.width - 0.62)
        drawPrism(x: p.x + (p.width - width) / 2, y: p.y + p.depth * 0.38,
                  width: width, depth: min(0.42, p.depth * 0.34),
                  baseZ: p.height + 0.07, height: 0.30,
                  front: Palette.metal, side: Palette.metal.shadowed(0.70),
                  top: Palette.roofBlue, origin: origin)
    }

    private func drawFacadeDetails(_ p: Placement, style: BuildingStyle, origin: CGPoint) {
        drawSurfacePattern(p, style: style, origin: origin)
        let floorHeight = p.height / CGFloat(style.stories)
        for story in 0..<style.stories {
            let baseZ = CGFloat(story) * floorHeight + floorHeight * 0.24
            let windowHeight = min(0.52, floorHeight * 0.52)
            let frontWidth = min(0.34, p.width / CGFloat(style.frontBays) * 0.52)
            let sideWidth = min(0.30, p.depth / CGFloat(style.sideBays) * 0.46)

            for bay in 0..<style.frontBays {
                let centerX = p.x + (CGFloat(bay) + 0.5) * p.width / CGFloat(style.frontBays)
                drawFrontWindow(centerX: centerX, y: p.y - 0.012, width: frontWidth,
                                baseZ: baseZ, height: windowHeight,
                                lit: (story + bay + p.role.rawValue.count) % 4 == 0, origin: origin)
            }
            for bay in 0..<style.sideBays {
                let centerY = p.y + (CGFloat(bay) + 0.5) * p.depth / CGFloat(style.sideBays)
                drawSideWindow(x: p.x - 0.012, centerY: centerY, width: sideWidth,
                               baseZ: baseZ, height: windowHeight,
                               lit: (story + bay) % 3 == 0, origin: origin)
            }
        }

        drawFrontPanel(x: p.x, y: p.y - 0.014, width: p.width,
                       baseZ: p.height - 0.15, height: 0.12,
                       color: Palette.cornice, origin: origin)
        drawSidePanel(x: p.x - 0.014, y: p.y, depth: p.depth,
                      baseZ: p.height - 0.15, height: 0.12,
                      color: Palette.cornice.shadowed(0.72), origin: origin)
    }

    private func drawSurfacePattern(_ p: Placement, style: BuildingStyle, origin: CGPoint) {
        let spacing: CGFloat = switch style.facade {
        case .clapboard: 0.20
        case .masonry: 0.38
        case .civicStone: 0.46
        case .storefront: 0.56
        case .industrial: 0.44
        }
        let color: NSColor = switch style.facade {
        case .clapboard: Palette.materialLight.withAlphaComponent(0.42)
        case .masonry: Palette.mortar.withAlphaComponent(0.52)
        case .civicStone: Palette.stoneLight.withAlphaComponent(0.58)
        case .storefront: Palette.cornice.withAlphaComponent(0.42)
        case .industrial: Palette.metalDark.withAlphaComponent(0.28)
        }
        for z in stride(from: spacing, to: p.height - 0.18, by: spacing) {
            line(from: family.project(x: p.x, y: p.y - 0.016, z: z, origin: origin),
                 to: family.project(x: p.x + p.width, y: p.y - 0.016, z: z, origin: origin),
                 color: color, width: style.facade == .clapboard ? 0.65 : 0.85)
            line(from: family.project(x: p.x - 0.016, y: p.y, z: z, origin: origin),
                 to: family.project(x: p.x - 0.016, y: p.y + p.depth, z: z, origin: origin),
                 color: color.shadowed(0.80), width: style.facade == .clapboard ? 0.55 : 0.75)
        }
    }

    private func drawFrontWindow(centerX: CGFloat, y: CGFloat, width: CGFloat,
                                 baseZ: CGFloat, height: CGFloat, lit: Bool, origin: CGPoint) {
        drawFrontPanel(x: centerX - width / 2 - 0.035, y: y, width: width + 0.07,
                       baseZ: baseZ - 0.035, height: height + 0.07,
                       color: Palette.windowFrame, origin: origin)
        drawFrontPanel(x: centerX - width / 2, y: y - 0.003, width: width,
                       baseZ: baseZ, height: height,
                       color: lit ? Palette.windowLit : Palette.window, origin: origin)
        line(from: family.project(x: centerX, y: y - 0.006, z: baseZ, origin: origin),
             to: family.project(x: centerX, y: y - 0.006, z: baseZ + height, origin: origin),
             color: Palette.windowFrame, width: 0.65)
    }

    private func drawSideWindow(x: CGFloat, centerY: CGFloat, width: CGFloat,
                                baseZ: CGFloat, height: CGFloat, lit: Bool, origin: CGPoint) {
        drawSidePanel(x: x, y: centerY - width / 2 - 0.035, depth: width + 0.07,
                      baseZ: baseZ - 0.035, height: height + 0.07,
                      color: Palette.windowFrame.shadowed(0.80), origin: origin)
        drawSidePanel(x: x + 0.003, y: centerY - width / 2, depth: width,
                      baseZ: baseZ, height: height,
                      color: lit ? Palette.windowLit.shadowed(0.90) : Palette.window.shadowed(0.78),
                      origin: origin)
    }

    private func drawFrontDoor(x: CGFloat, y: CGFloat, width: CGFloat,
                               height: CGFloat, color: NSColor, origin: CGPoint) {
        drawFrontPanel(x: x - width / 2 - 0.04, y: y, width: width + 0.08,
                       baseZ: 0, height: height + 0.06, color: Palette.windowFrame, origin: origin)
        drawFrontPanel(x: x - width / 2, y: y - 0.003, width: width,
                       baseZ: 0, height: height, color: color, origin: origin)
    }

    private func drawRollupDoor(x: CGFloat, y: CGFloat, width: CGFloat,
                                height: CGFloat, origin: CGPoint) {
        drawFrontPanel(x: x - width / 2 - 0.05, y: y, width: width + 0.10,
                       baseZ: 0, height: height + 0.05, color: Palette.metalDark, origin: origin)
        drawFrontPanel(x: x - width / 2, y: y - 0.003, width: width,
                       baseZ: 0, height: height, color: Palette.metal, origin: origin)
        for z in stride(from: CGFloat(0.14), to: height, by: 0.16) {
            line(from: family.project(x: x - width / 2, y: y - 0.006, z: z, origin: origin),
                 to: family.project(x: x + width / 2, y: y - 0.006, z: z, origin: origin),
                 color: Palette.metalDark.withAlphaComponent(0.48), width: 0.65)
        }
    }

    private func drawAwning(x: CGFloat, y: CGFloat, width: CGFloat, z: CGFloat,
                            color: NSColor, origin: CGPoint) {
        let a = family.project(x: x, y: y, z: z, origin: origin)
        let b = family.project(x: x + width, y: y, z: z, origin: origin)
        let c = family.project(x: x + width, y: y - 0.20, z: z - 0.08, origin: origin)
        let d = family.project(x: x, y: y - 0.20, z: z - 0.08, origin: origin)
        fill(polygon([a, b, c, d]), color, stroke: Palette.edge, line: 0.8)
    }

    private func drawPortico(x: CGFloat, y: CGFloat, width: CGFloat, origin: CGPoint) {
        fill(isoRect(x: x, y: y, width: width, depth: 0.38, z: 1.30, origin: origin),
             Palette.stoneLight, stroke: Palette.edge, line: 1)
        for columnX in [x + 0.12, x + width - 0.12] {
            drawPrism(x: columnX - 0.045, y: y + 0.04, width: 0.09, depth: 0.09,
                      baseZ: 0, height: 1.30, front: Palette.stoneLight,
                      side: Palette.stone, top: Palette.stoneLight, origin: origin)
        }
    }

    private func drawCupola(x: CGFloat, y: CGFloat, z: CGFloat, origin: CGPoint) {
        drawPrism(x: x - 0.24, y: y - 0.24, width: 0.48, depth: 0.48,
                  baseZ: z, height: 0.48, front: Palette.stoneLight,
                  side: Palette.stone, top: Palette.copper, origin: origin)
        drawPyramidRoof(x: x - 0.31, y: y - 0.31, width: 0.62, depth: 0.62,
                        baseZ: z + 0.48, height: 0.42, color: Palette.copper, origin: origin)
    }

    private func drawRoofUnit(x: CGFloat, y: CGFloat, z: CGFloat, origin: CGPoint) {
        drawPrism(x: x - 0.24, y: y - 0.18, width: 0.48, depth: 0.36,
                  baseZ: z, height: 0.25, front: Palette.metal,
                  side: Palette.metal.shadowed(0.68), top: Palette.metalLight, origin: origin)
    }

    private func drawTank(x: CGFloat, y: CGFloat, z: CGFloat, origin: CGPoint) {
        for (dx, dy) in [(-0.25, -0.20), (0.25, -0.20), (0.25, 0.20), (-0.25, 0.20)] {
            line(from: family.project(x: x + dx, y: y + dy, z: z - 0.72, origin: origin),
                 to: family.project(x: x + dx * 0.68, y: y + dy * 0.68, z: z, origin: origin),
                 color: Palette.metalDark, width: 2)
        }
        drawPrism(x: x - 0.42, y: y - 0.34, width: 0.84, depth: 0.68,
                  baseZ: z, height: 0.48, front: Palette.metal,
                  side: Palette.metal.shadowed(0.72), top: Palette.metalLight, origin: origin)
        drawPyramidRoof(x: x - 0.42, y: y - 0.34, width: 0.84, depth: 0.68,
                        baseZ: z + 0.48, height: 0.18, color: Palette.metalLight, origin: origin)
    }

    private func drawStack(x: CGFloat, y: CGFloat, baseZ: CGFloat,
                           height: CGFloat, origin: CGPoint) {
        drawPrism(x: x - 0.13, y: y - 0.13, width: 0.26, depth: 0.26,
                  baseZ: baseZ, height: height, front: Palette.stackRed,
                  side: Palette.stackRed.shadowed(0.70), top: Palette.metalDark, origin: origin)
        for fraction in [0.22, 0.52, 0.82] {
            drawFrontPanel(x: x - 0.13, y: y - 0.14, width: 0.26,
                           baseZ: baseZ + height * CGFloat(fraction), height: 0.12,
                           color: Palette.stackCream, origin: origin)
            drawSidePanel(x: x - 0.14, y: y - 0.13, depth: 0.26,
                          baseZ: baseZ + height * CGFloat(fraction), height: 0.12,
                          color: Palette.stackCream.shadowed(0.82), origin: origin)
        }
    }

    private func drawChimney(x: CGFloat, y: CGFloat, baseZ: CGFloat, origin: CGPoint) {
        drawPrism(x: x - 0.12, y: y - 0.12, width: 0.24, depth: 0.24,
                  baseZ: baseZ, height: 0.72, front: Palette.brick,
                  side: Palette.brickDark, top: Palette.edge, origin: origin)
    }

    private func drawBalcony(x: CGFloat, y: CGFloat, width: CGFloat,
                             z: CGFloat, origin: CGPoint) {
        fill(isoRect(x: x, y: y - 0.20, width: width, depth: 0.22, z: z, origin: origin),
             Palette.metalDark, stroke: Palette.edge, line: 0.7)
        for postX in stride(from: x, through: x + width, by: width / 4) {
            line(from: family.project(x: postX, y: y - 0.20, z: z, origin: origin),
                 to: family.project(x: postX, y: y - 0.20, z: z + 0.38, origin: origin),
                 color: Palette.metalDark, width: 1)
        }
        line(from: family.project(x: x, y: y - 0.20, z: z + 0.38, origin: origin),
             to: family.project(x: x + width, y: y - 0.20, z: z + 0.38, origin: origin),
             color: Palette.metalDark, width: 1.2)
    }

    private func drawPyramidRoof(x: CGFloat, y: CGFloat, width: CGFloat, depth: CGFloat,
                                 baseZ: CGFloat, height: CGFloat, color: NSColor, origin: CGPoint) {
        let apex = (x + width / 2, y + depth / 2, baseZ + height)
        fill(isoPolygon([(x, y, baseZ), (x + width, y, baseZ), apex], origin: origin),
             color, stroke: Palette.edge, line: 0.8)
        fill(isoPolygon([(x + width, y, baseZ), (x + width, y + depth, baseZ), apex], origin: origin),
             color.shadowed(0.72), stroke: Palette.edge, line: 0.8)
    }

    private func drawFrontPanel(x: CGFloat, y: CGFloat, width: CGFloat,
                                baseZ: CGFloat, height: CGFloat, color: NSColor,
                                origin: CGPoint) {
        fill(isoPolygon([(x, y, baseZ), (x + width, y, baseZ),
                         (x + width, y, baseZ + height), (x, y, baseZ + height)], origin: origin),
             color, stroke: Palette.edge.withAlphaComponent(0.54), line: 0.45)
    }

    private func drawSidePanel(x: CGFloat, y: CGFloat, depth: CGFloat,
                               baseZ: CGFloat, height: CGFloat, color: NSColor,
                               origin: CGPoint) {
        fill(isoPolygon([(x, y, baseZ), (x, y + depth, baseZ),
                         (x, y + depth, baseZ + height), (x, y, baseZ + height)], origin: origin),
             color, stroke: Palette.edge.withAlphaComponent(0.50), line: 0.42)
    }

    private func drawRoleGroundDetails(_ p: Placement, origin: CGPoint) {
        switch p.role {
        case .craftsman, .rowhouses, .apartments, .library, .cityHall:
            drawShrub(x: p.x + 0.16, y: p.y - 0.15, origin: origin)
            drawShrub(x: p.x + p.width - 0.16, y: p.y - 0.15, origin: origin)
        case .market, .cafe:
            drawPlanter(x: p.x + 0.18, y: p.y - 0.18, origin: origin)
            drawPlanter(x: p.x + p.width - 0.18, y: p.y - 0.18, origin: origin)
        case .factory, .workshop, .utility:
            let pad = isoRect(x: p.x + p.width - 0.50, y: p.y - 0.18, width: 0.40, depth: 0.22,
                              z: 0.06, origin: origin)
            fill(pad, Palette.asphaltLight, stroke: Palette.edge, line: 0.5)
        }
    }

    private func drawStreetDetails(origin: CGPoint) {
        for (x, y) in [(3.78, 1.20), (4.95, 2.55), (8.58, 1.25), (9.78, 2.55),
                       (3.78, 5.05), (4.95, 7.75), (8.58, 5.05), (9.78, 7.75)] {
            drawLamp(x: x, y: y, origin: origin)
        }
        drawTree(x: 0.42, y: 0.55, origin: origin)
        drawTree(x: 3.45, y: 2.75, origin: origin)
        drawTree(x: 0.45, y: 6.05, origin: origin)
        drawTree(x: 13.45, y: 9.30, origin: origin)
        drawTree(x: 13.40, y: 5.95, origin: origin)
        drawTree(x: 13.38, y: 0.65, origin: origin)
        drawVehicle(x: 4.15, y: 4.86, width: 0.46, depth: 0.76,
                    color: Palette.vehicleBlue, origin: origin)
        drawVehicle(x: 6.72, y: 6.49, width: 0.78, depth: 0.42,
                    color: Palette.vehicleRed, origin: origin)
        drawVehicle(x: 8.96, y: 1.72, width: 0.46, depth: 0.76,
                    color: Palette.vehicleCream, origin: origin)
        drawBench(x: 6.00, y: 6.79, width: 0.52, origin: origin)
        drawBench(x: 7.05, y: 6.79, width: 0.52, origin: origin)
        drawHydrant(x: 3.76, y: 4.14, origin: origin)
        drawHydrant(x: 9.70, y: 6.14, origin: origin)
    }

    private func drawVehicle(x: CGFloat, y: CGFloat, width: CGFloat,
                             depth: CGFloat, color: NSColor, origin: CGPoint) {
        drawPrism(x: x, y: y, width: width, depth: depth,
                  baseZ: 0.10, height: 0.18, front: color,
                  side: color.shadowed(0.68), top: color.highlighted(1.12), origin: origin)
        drawPrism(x: x + width * 0.16, y: y + depth * 0.20,
                  width: width * 0.68, depth: depth * 0.52,
                  baseZ: 0.28, height: 0.19, front: Palette.vehicleGlass,
                  side: Palette.vehicleGlass.shadowed(0.70), top: Palette.vehicleGlass,
                  origin: origin)
    }

    private func drawBench(x: CGFloat, y: CGFloat, width: CGFloat, origin: CGPoint) {
        drawPrism(x: x, y: y, width: width, depth: 0.11,
                  baseZ: 0.12, height: 0.13, front: Palette.wood,
                  side: Palette.wood.shadowed(0.70), top: Palette.wood.highlighted(1.10),
                  origin: origin)
        for legX in [x + 0.08, x + width - 0.08] {
            line(from: family.project(x: legX, y: y + 0.03, z: 0.04, origin: origin),
                 to: family.project(x: legX, y: y + 0.03, z: 0.14, origin: origin),
                 color: Palette.metalDark, width: 1)
        }
    }

    private func drawHydrant(x: CGFloat, y: CGFloat, origin: CGPoint) {
        drawPrism(x: x - 0.055, y: y - 0.055, width: 0.11, depth: 0.11,
                  baseZ: 0.06, height: 0.28, front: Palette.hydrant,
                  side: Palette.hydrant.shadowed(0.72), top: Palette.stackCream,
                  origin: origin)
    }

    private func drawLamp(x: CGFloat, y: CGFloat, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: 0.06, origin: origin)
        line(from: p, to: CGPoint(x: p.x, y: p.y + 26), color: Palette.metalDark, width: 2)
        fill(NSBezierPath(ovalIn: CGRect(x: p.x - 4, y: p.y + 22, width: 8, height: 7)),
             Palette.lamp, stroke: Palette.edge, line: 0.5)
    }

    private func drawTree(x: CGFloat, y: CGFloat, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: 0.05, origin: origin)
        line(from: p, to: CGPoint(x: p.x, y: p.y + 28), color: Palette.trunk, width: 4)
        fill(NSBezierPath(ovalIn: CGRect(x: p.x - 17, y: p.y + 20, width: 28, height: 29)),
             Palette.treeDark, stroke: Palette.edge, line: 0.6)
        fill(NSBezierPath(ovalIn: CGRect(x: p.x - 4, y: p.y + 26, width: 28, height: 30)),
             Palette.tree, stroke: Palette.edge, line: 0.6)
        fill(NSBezierPath(ovalIn: CGRect(x: p.x - 10, y: p.y + 39, width: 22, height: 21)),
             Palette.treeLight, stroke: Palette.edge, line: 0.5)
    }

    private func drawShrub(x: CGFloat, y: CGFloat, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: 0.04, origin: origin)
        for dx in [-4.0, 2.0, 7.0] {
            fill(NSBezierPath(ovalIn: CGRect(x: p.x + dx - 5, y: p.y - 1, width: 11, height: 10)),
                 Palette.shrub, stroke: Palette.treeDark, line: 0.4)
        }
    }

    private func drawPlanter(x: CGFloat, y: CGFloat, origin: CGPoint) {
        let p = family.project(x: x, y: y, z: 0.04, origin: origin)
        fill(NSBezierPath(roundedRect: CGRect(x: p.x - 7, y: p.y - 2, width: 15, height: 7),
                                      xRadius: 2, yRadius: 2),
             Palette.terracotta, stroke: Palette.edge, line: 0.5)
        fill(NSBezierPath(ovalIn: CGRect(x: p.x - 4, y: p.y + 2, width: 8, height: 8)), Palette.flower)
    }

    private func lotColor(for role: BuildingRole) -> NSColor {
        switch role {
        case .factory, .workshop, .utility: Palette.industrialGround
        case .market, .cafe, .cityHall, .library: Palette.civicGround
        default: Palette.lawn
        }
    }

    private func colors(for role: BuildingRole) -> (front: NSColor, side: NSColor, roof: NSColor) {
        let front: NSColor = switch role {
        case .craftsman: Palette.cream
        case .rowhouses: Palette.blue
        case .apartments: Palette.brick
        case .market: Palette.ochre
        case .cafe: Palette.teal
        case .library: Palette.sage
        case .cityHall: Palette.stone
        case .workshop: Palette.rust
        case .factory: Palette.brickDark
        case .utility: Palette.utility
        }
        let roof: NSColor = switch role {
        case .craftsman, .rowhouses, .library, .cityHall: Palette.roofBlue
        default: Palette.roofFlat
        }
        return (front, front.shadowed(0.70), roof)
    }

    private func isoRect(x: CGFloat, y: CGFloat, width: CGFloat, depth: CGFloat,
                         z: CGFloat, origin: CGPoint) -> NSBezierPath {
        isoPolygon([(x, y, z), (x + width, y, z),
                    (x + width, y + depth, z), (x, y + depth, z)], origin: origin)
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

    private func fill(_ path: NSBezierPath, _ color: NSColor,
                      stroke: NSColor? = nil, line: CGFloat = 1) {
        color.setFill(); path.fill()
        if let stroke { stroke.setStroke(); path.lineWidth = line; path.stroke() }
    }

    private func stroke(_ path: NSBezierPath, _ color: NSColor, line: CGFloat) {
        color.setStroke(); path.lineWidth = line; path.stroke()
    }

    private func line(from start: CGPoint, to end: CGPoint, color: NSColor, width: CGFloat) {
        let path = NSBezierPath(); path.move(to: start); path.line(to: end)
        color.setStroke(); path.lineWidth = width; path.stroke()
    }

    private func shadow(_ path: NSBezierPath, offset: CGSize, alpha: CGFloat) {
        let copy = path.copy() as! NSBezierPath
        let transform = AffineTransform(translationByX: offset.width, byY: offset.height)
        copy.transform(using: transform)
        Palette.edge.withAlphaComponent(alpha).setFill(); copy.fill()
    }
}

private enum Palette {
    static let skyTop = NSColor(calibratedRed: 0.56, green: 0.55, blue: 0.49, alpha: 1)
    static let skyBottom = NSColor(calibratedRed: 0.29, green: 0.35, blue: 0.35, alpha: 1)
    static let haze = NSColor(calibratedRed: 0.94, green: 0.87, blue: 0.72, alpha: 0.12)
    static let edge = NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.14, alpha: 1)
    static let grassDark = NSColor(calibratedRed: 0.27, green: 0.40, blue: 0.25, alpha: 1)
    static let grass = NSColor(calibratedRed: 0.50, green: 0.63, blue: 0.39, alpha: 1)
    static let grassLight = NSColor(calibratedRed: 0.72, green: 0.78, blue: 0.58, alpha: 1)
    static let lawn = NSColor(calibratedRed: 0.57, green: 0.66, blue: 0.45, alpha: 1)
    static let civicGround = NSColor(calibratedRed: 0.67, green: 0.64, blue: 0.56, alpha: 1)
    static let industrialGround = NSColor(calibratedRed: 0.47, green: 0.44, blue: 0.38, alpha: 1)
    static let park = NSColor(calibratedRed: 0.36, green: 0.57, blue: 0.31, alpha: 1)
    static let walk = NSColor(calibratedRed: 0.79, green: 0.75, blue: 0.66, alpha: 1)
    static let curb = NSColor(calibratedRed: 0.78, green: 0.73, blue: 0.64, alpha: 1)
    static let asphalt = NSColor(calibratedRed: 0.17, green: 0.20, blue: 0.21, alpha: 1)
    static let asphaltLight = NSColor(calibratedWhite: 0.38, alpha: 0.60)
    static let lane = NSColor(calibratedRed: 0.91, green: 0.72, blue: 0.30, alpha: 0.76)
    static let crosswalk = NSColor(calibratedRed: 0.91, green: 0.89, blue: 0.80, alpha: 0.86)
    static let cream = NSColor(calibratedRed: 0.90, green: 0.81, blue: 0.63, alpha: 1)
    static let blue = NSColor(calibratedRed: 0.40, green: 0.65, blue: 0.72, alpha: 1)
    static let sage = NSColor(calibratedRed: 0.51, green: 0.64, blue: 0.50, alpha: 1)
    static let brick = NSColor(calibratedRed: 0.67, green: 0.35, blue: 0.24, alpha: 1)
    static let brickDark = NSColor(calibratedRed: 0.50, green: 0.27, blue: 0.20, alpha: 1)
    static let ochre = NSColor(calibratedRed: 0.82, green: 0.52, blue: 0.25, alpha: 1)
    static let teal = NSColor(calibratedRed: 0.20, green: 0.51, blue: 0.52, alpha: 1)
    static let stone = NSColor(calibratedRed: 0.77, green: 0.73, blue: 0.64, alpha: 1)
    static let stoneLight = NSColor(calibratedRed: 0.90, green: 0.87, blue: 0.78, alpha: 1)
    static let materialLight = NSColor(calibratedRed: 0.95, green: 0.90, blue: 0.78, alpha: 1)
    static let mortar = NSColor(calibratedRed: 0.83, green: 0.72, blue: 0.59, alpha: 1)
    static let cornice = NSColor(calibratedRed: 0.85, green: 0.76, blue: 0.61, alpha: 1)
    static let signBand = NSColor(calibratedRed: 0.17, green: 0.35, blue: 0.38, alpha: 1)
    static let rust = NSColor(calibratedRed: 0.70, green: 0.31, blue: 0.20, alpha: 1)
    static let coral = NSColor(calibratedRed: 0.88, green: 0.38, blue: 0.27, alpha: 1)
    static let utility = NSColor(calibratedRed: 0.48, green: 0.52, blue: 0.50, alpha: 1)
    static let roofBlue = NSColor(calibratedRed: 0.18, green: 0.29, blue: 0.39, alpha: 1)
    static let roofFlat = NSColor(calibratedRed: 0.37, green: 0.34, blue: 0.30, alpha: 1)
    static let roofLine = NSColor(calibratedRed: 0.48, green: 0.58, blue: 0.66, alpha: 0.50)
    static let roofEdge = NSColor(calibratedRed: 0.62, green: 0.57, blue: 0.49, alpha: 1)
    static let window = NSColor(calibratedRed: 0.31, green: 0.62, blue: 0.68, alpha: 1)
    static let windowLit = NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.34, alpha: 1)
    static let windowFrame = NSColor(calibratedRed: 0.88, green: 0.85, blue: 0.76, alpha: 1)
    static let door = NSColor(calibratedRed: 0.38, green: 0.17, blue: 0.12, alpha: 1)
    static let copper = NSColor(calibratedRed: 0.22, green: 0.58, blue: 0.52, alpha: 1)
    static let metal = NSColor(calibratedRed: 0.66, green: 0.68, blue: 0.65, alpha: 1)
    static let metalLight = NSColor(calibratedRed: 0.78, green: 0.79, blue: 0.74, alpha: 1)
    static let metalDark = NSColor(calibratedRed: 0.20, green: 0.23, blue: 0.23, alpha: 1)
    static let stackRed = NSColor(calibratedRed: 0.72, green: 0.20, blue: 0.15, alpha: 1)
    static let stackCream = NSColor(calibratedRed: 0.93, green: 0.88, blue: 0.75, alpha: 1)
    static let vehicleBlue = NSColor(calibratedRed: 0.18, green: 0.43, blue: 0.58, alpha: 1)
    static let vehicleRed = NSColor(calibratedRed: 0.67, green: 0.24, blue: 0.18, alpha: 1)
    static let vehicleCream = NSColor(calibratedRed: 0.84, green: 0.72, blue: 0.49, alpha: 1)
    static let vehicleGlass = NSColor(calibratedRed: 0.25, green: 0.43, blue: 0.48, alpha: 1)
    static let wood = NSColor(calibratedRed: 0.47, green: 0.27, blue: 0.14, alpha: 1)
    static let hydrant = NSColor(calibratedRed: 0.79, green: 0.19, blue: 0.13, alpha: 1)
    static let lamp = NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.35, alpha: 1)
    static let trunk = NSColor(calibratedRed: 0.34, green: 0.22, blue: 0.13, alpha: 1)
    static let treeDark = NSColor(calibratedRed: 0.13, green: 0.35, blue: 0.18, alpha: 1)
    static let tree = NSColor(calibratedRed: 0.23, green: 0.48, blue: 0.24, alpha: 1)
    static let treeLight = NSColor(calibratedRed: 0.43, green: 0.62, blue: 0.29, alpha: 1)
    static let shrub = NSColor(calibratedRed: 0.28, green: 0.52, blue: 0.24, alpha: 1)
    static let terracotta = NSColor(calibratedRed: 0.63, green: 0.31, blue: 0.20, alpha: 1)
    static let flower = NSColor(calibratedRed: 0.88, green: 0.37, blue: 0.48, alpha: 1)
}

private extension NSColor {
    func shadowed(_ factor: CGFloat) -> NSColor {
        guard let rgb = usingColorSpace(.deviceRGB) else { return self }
        return NSColor(calibratedRed: rgb.redComponent * factor,
                       green: rgb.greenComponent * factor,
                       blue: rgb.blueComponent * factor,
                       alpha: rgb.alphaComponent)
    }

    func highlighted(_ factor: CGFloat) -> NSColor {
        guard let rgb = usingColorSpace(.deviceRGB) else { return self }
        return NSColor(calibratedRed: min(1, rgb.redComponent * factor),
                       green: min(1, rgb.greenComponent * factor),
                       blue: min(1, rgb.blueComponent * factor),
                       alpha: rgb.alphaComponent)
    }
}
