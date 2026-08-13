import AppKit
import Foundation

/// Composes only accepted Asset Sprint sprites on the canonical Cedar Market
/// projection. One scene transform and one sprite scale apply to every family;
/// no asset receives corrective rotation, skew, or scale.
@MainActor
final class AssetSprintIntegratedNeighborhoodRenderer {
    struct Placement: Sendable {
        enum Asset: Sendable {
            case residentialCivic(AssetSprintResidentialCivicAsset)
            case commercialIndustrial(AssetSprintCommercialIndustrialAsset)
            case terrain(AssetSprintTerrainAsset)
        }

        let asset: Asset
        let x: CGFloat
        let y: CGFloat
    }

    static let canonicalSize = CGSize(width: 1_280, height: 800)
    /// Every opaque sprite footprint is normalized by this one semantic scale.
    /// Different source-canvas padding cannot make one production family loom
    /// over another, while larger authored footprints remain visibly larger.
    static let pixelsPerFootprintEdge: CGFloat = 42

    static let placements: [Placement] = [
        .init(asset: .residentialCivic(.cityHall), x: 7.0, y: 8.7),
        .init(asset: .commercialIndustrial(.factory), x: 11.0, y: 7.6),
        .init(asset: .residentialCivic(.courtyardApartments), x: 2.6, y: 7.3),
        .init(asset: .terrain(.parkTreatment), x: 7.1, y: 6.2),
        .init(asset: .commercialIndustrial(.utilityIndustry), x: 11.2, y: 4.6),
        .init(asset: .residentialCivic(.rowhouses), x: 2.5, y: 4.7),
        .init(asset: .commercialIndustrial(.mixedUse), x: 7.0, y: 4.2),
        .init(asset: .commercialIndustrial(.workshop), x: 11.1, y: 2.0),
        .init(asset: .residentialCivic(.craftsman), x: 2.5, y: 1.7),
        .init(asset: .commercialIndustrial(.cafe), x: 6.9, y: 1.4),
        .init(asset: .residentialCivic(.neighborhoodLibrary), x: 9.2, y: 0.8),
    ]

    let family: AssetSprintReferenceFamily

    init(family: AssetSprintReferenceFamily = .canonical) {
        self.family = family
    }

    func render(size: CGSize) -> NSBitmapImageRep? {
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
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }

        bitmap.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.shouldAntialias = true
        context.imageInterpolation = .high
        drawBackdrop(size: size)

        let sceneScale = min(
            size.width / Self.canonicalSize.width,
            size.height / Self.canonicalSize.height
        )
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
        drawAcceptedAssets(origin: origin)
        context.cgContext.restoreGState()

        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    func pngData(for bitmap: NSBitmapImageRep) -> Data? {
        bitmap.representation(using: .png, properties: [:])
    }

    private func drawBackdrop(size: CGSize) {
        NSGradient(colors: [
            NSColor(calibratedRed: 0.47, green: 0.53, blue: 0.48, alpha: 1),
            NSColor(calibratedRed: 0.23, green: 0.32, blue: 0.35, alpha: 1),
        ])?.draw(in: CGRect(origin: .zero, size: size), angle: 90)
        NSColor(calibratedWhite: 0.95, alpha: 0.10).setFill()
        NSBezierPath(ovalIn: CGRect(
            x: size.width * 0.10,
            y: size.height * 0.69,
            width: size.width * 0.80,
            height: size.height * 0.16
        )).fill()
    }

    private func drawGround(origin: CGPoint) {
        let shadow = isoPolygon([(0, 0), (14, 0), (14, 10), (0, 10)], origin: origin, z: -0.12)
        var transform = AffineTransform.identity
        transform.translate(x: 25, y: -18)
        shadow.transform(using: transform)
        fill(shadow, NSColor.black.withAlphaComponent(0.24))

        fill(
            isoPolygon([(0, 0), (14, 0), (14, 10), (0, 10)], origin: origin, z: 0),
            NSColor(calibratedRed: 0.30, green: 0.44, blue: 0.28, alpha: 1),
            stroke: NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.17, alpha: 0.90),
            line: 2.5
        )
        fill(
            isoPolygon([(0.20, 0.20), (13.80, 0.20), (13.80, 9.80), (0.20, 9.80)], origin: origin, z: 0.025),
            NSColor(calibratedRed: 0.51, green: 0.64, blue: 0.39, alpha: 1),
            stroke: NSColor(calibratedRed: 0.71, green: 0.76, blue: 0.57, alpha: 0.70),
            line: 1
        )

        for rectangle in [
            (0.35, 0.35, 3.6, 9.3),
            (4.65, 0.35, 4.15, 9.3),
            (9.5, 0.35, 4.15, 9.3),
        ] {
            let lot = isoPolygon([
                (rectangle.0, rectangle.1),
                (rectangle.0 + rectangle.2, rectangle.1),
                (rectangle.0 + rectangle.2, rectangle.1 + rectangle.3),
                (rectangle.0, rectangle.1 + rectangle.3),
            ], origin: origin, z: 0.04)
            fill(
                lot,
                rectangle.0 > 9
                    ? NSColor(calibratedRed: 0.45, green: 0.45, blue: 0.39, alpha: 1)
                    : NSColor(calibratedRed: 0.56, green: 0.66, blue: 0.44, alpha: 1),
                stroke: NSColor(calibratedWhite: 0.18, alpha: 0.45),
                line: 0.8
            )
        }
    }

    private func drawRoadNetwork(origin: CGPoint) {
        drawRoad(x: 4.02, y: 0.15, width: 0.72, depth: 9.70, origin: origin)
        drawRoad(x: 8.82, y: 0.15, width: 0.72, depth: 9.70, origin: origin)
        drawRoad(x: 0.15, y: 3.20, width: 13.70, depth: 0.74, origin: origin)
        drawRoad(x: 0.15, y: 6.35, width: 13.70, depth: 0.74, origin: origin)

        for x in stride(from: CGFloat(0.55), through: 13.2, by: 0.78) {
            drawRoadMark(x: x, y: 3.51, width: 0.34, depth: 0.08, origin: origin)
            drawRoadMark(x: x, y: 6.66, width: 0.34, depth: 0.08, origin: origin)
        }
        for y in stride(from: CGFloat(0.50), through: 9.25, by: 0.78) {
            drawRoadMark(x: 4.33, y: y, width: 0.08, depth: 0.34, origin: origin)
            drawRoadMark(x: 9.13, y: y, width: 0.08, depth: 0.34, origin: origin)
        }
    }

    private func drawRoad(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        depth: CGFloat,
        origin: CGPoint
    ) {
        fill(
            isoPolygon([
                (x - 0.13, y - 0.13), (x + width + 0.13, y - 0.13),
                (x + width + 0.13, y + depth + 0.13), (x - 0.13, y + depth + 0.13),
            ], origin: origin, z: 0.065),
            NSColor(calibratedRed: 0.78, green: 0.73, blue: 0.63, alpha: 1),
            stroke: NSColor(calibratedWhite: 0.25, alpha: 0.6),
            line: 0.8
        )
        fill(
            isoPolygon([
                (x, y), (x + width, y), (x + width, y + depth), (x, y + depth),
            ], origin: origin, z: 0.075),
            NSColor(calibratedRed: 0.17, green: 0.20, blue: 0.21, alpha: 1),
            stroke: NSColor(calibratedWhite: 0.40, alpha: 0.5),
            line: 0.7
        )
    }

    private func drawRoadMark(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        depth: CGFloat,
        origin: CGPoint
    ) {
        fill(
            isoPolygon([
                (x, y), (x + width, y), (x + width, y + depth), (x, y + depth),
            ], origin: origin, z: 0.085),
            NSColor(calibratedRed: 0.91, green: 0.72, blue: 0.30, alpha: 0.76)
        )
    }

    private func drawAcceptedAssets(origin: CGPoint) {
        let ordered = Self.placements.sorted {
            let lhs = family.project(x: $0.x, y: $0.y, origin: origin)
            let rhs = family.project(x: $1.x, y: $1.y, origin: origin)
            return lhs.y > rhs.y
        }
        for placement in ordered {
            let anchor = family.project(x: placement.x, y: placement.y, z: 0.10, origin: origin)
            draw(placement.asset, at: anchor)
        }
    }

    private func draw(_ asset: Placement.Asset, at anchor: CGPoint) {
        let url: URL?
        switch asset {
        case .residentialCivic(let value):
            url = AssetSprintResidentialCivicCatalog.resourceURL(for: value)
        case .commercialIndustrial(let value):
            url = AssetSprintCommercialIndustrialFamily.resourceDirectoryURL?
                .appendingPathComponent(value.fileName)
        case .terrain(let value):
            url = AssetSprintTerrainRoadsVegetationFamily.resourceDirectoryURL?
                .appendingPathComponent(value.fileName)
        }
        guard let url,
              let image = NSImage(contentsOf: url),
              let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first else {
            return
        }
        let opaqueBounds = opaqueBounds(in: bitmap)
        let normalization = Self.pixelsPerFootprintEdge * footprintSpan(of: asset)
            / max(1, opaqueBounds.width)
        let size = CGSize(
            width: CGFloat(bitmap.pixelsWide) * normalization,
            height: CGFloat(bitmap.pixelsHigh) * normalization
        )
        let destination = CGRect(
            x: anchor.x - size.width * family.pivot.x,
            y: anchor.y - size.height * family.pivot.y,
            width: size.width,
            height: size.height
        )
        image.draw(
            in: destination,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func footprintSpan(of asset: Placement.Asset) -> CGFloat {
        switch asset {
        case .residentialCivic(let value):
            let footprint = value.footprint
            return CGFloat(footprint.width + footprint.depth)
        case .commercialIndustrial(let value):
            return value.footprint.width + value.footprint.height
        case .terrain:
            return 8
        }
    }

    private func opaqueBounds(in bitmap: NSBitmapImageRep) -> CGRect {
        var minimumX = bitmap.pixelsWide
        var minimumY = bitmap.pixelsHigh
        var maximumX = 0
        var maximumY = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.02 {
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x + 1)
                maximumY = max(maximumY, y + 1)
            }
        }
        guard maximumX > minimumX, maximumY > minimumY else {
            return CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        }
        return CGRect(
            x: minimumX,
            y: minimumY,
            width: maximumX - minimumX,
            height: maximumY - minimumY
        )
    }

    private func isoPolygon(
        _ points: [(CGFloat, CGFloat)],
        origin: CGPoint,
        z: CGFloat
    ) -> NSBezierPath {
        let projected = points.map { family.project(x: $0.0, y: $0.1, z: z, origin: origin) }
        let path = NSBezierPath()
        guard let first = projected.first else { return path }
        path.move(to: first)
        for point in projected.dropFirst() { path.line(to: point) }
        path.close()
        return path
    }

    private func fill(
        _ path: NSBezierPath,
        _ color: NSColor,
        stroke: NSColor? = nil,
        line: CGFloat = 1
    ) {
        color.setFill()
        path.fill()
        if let stroke {
            stroke.setStroke()
            path.lineWidth = line
            path.stroke()
        }
    }
}
