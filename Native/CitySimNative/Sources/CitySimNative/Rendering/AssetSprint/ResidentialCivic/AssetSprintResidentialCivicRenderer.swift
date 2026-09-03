import AppKit
import Foundation

enum AssetSprintResidentialCivicAsset: String, CaseIterable, Sendable {
    case craftsman
    case rowhouses
    case courtyardApartments = "courtyard-apartments"
    case neighborhoodLibrary = "neighborhood-library"
    case cityHall = "city-hall"

    var fileName: String { "cedar-\(rawValue).png" }

    var footprint: (width: Int, depth: Int) {
        switch self {
        case .craftsman: (2, 2)
        case .rowhouses: (2, 3)
        case .courtyardApartments, .neighborhoodLibrary: (3, 3)
        case .cityHall: (4, 4)
        }
    }

    var expectedPixels: (width: Int, height: Int) {
        switch self {
        case .craftsman: (313, 157)
        case .rowhouses: (302, 201)
        case .courtyardApartments: (406, 271)
        case .neighborhoodLibrary: (355, 237)
        case .cityHall: (438, 292)
        }
    }
}

struct AssetSprintResidentialCivicCatalog {
    static let family = AssetSprintReferenceFamily.canonical

    static var resourceDirectoryURL: URL? {
        CityResourceBundle.shared.resourceURL?
            .appendingPathComponent("WorldAssets.atlas", isDirectory: true)
            .appendingPathComponent("AssetSprintResidentialCivic", isDirectory: true)
    }

    static func resourceURL(for asset: AssetSprintResidentialCivicAsset) -> URL? {
        resourceDirectoryURL?.appendingPathComponent(asset.fileName)
    }
}

/// Source-rendered neighborhood proof for the Residential + Civic sprint.
/// Every sprite is drawn at its authored 1:1 pixel size and placed with the
/// canonical family pivot. There are no per-asset transforms or scale fixes.
@MainActor
final class AssetSprintResidentialCivicRenderer {
    let family: AssetSprintReferenceFamily

    init(family: AssetSprintReferenceFamily = AssetSprintResidentialCivicCatalog.family) {
        self.family = family
    }

    func renderBlock(size: CGSize) -> NSBitmapImageRep? {
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
        let origin = CGPoint(x: size.width * 0.5, y: size.height * 0.16)
        drawDistrictGround(origin: origin)
        drawRoadNetwork(origin: origin)
        drawPlacedAssets(origin: origin)
        drawStreetDetails(origin: origin)

        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    func pngData(for image: NSBitmapImageRep) -> Data? {
        image.representation(using: .png, properties: [:])
    }

    private func drawBackdrop(size: CGSize) {
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.25, green: 0.33, blue: 0.34, alpha: 1),
            NSColor(calibratedRed: 0.49, green: 0.55, blue: 0.49, alpha: 1)
        ])!
        gradient.draw(in: NSRect(origin: .zero, size: size), angle: 90)
        NSColor(calibratedWhite: 0.92, alpha: 0.11).setFill()
        NSBezierPath(ovalIn: CGRect(
            x: size.width * 0.10,
            y: size.height * 0.67,
            width: size.width * 0.80,
            height: size.height * 0.19
        )).fill()
    }

    private func drawDistrictGround(origin: CGPoint) {
        let shadow = isoPolygon([(0, 0), (10, 0), (10, 8), (0, 8)], origin: origin, z: -0.18)
        var transform = AffineTransform.identity
        transform.translate(x: 18, y: -14)
        shadow.transform(using: transform)
        fill(shadow, NSColor(calibratedWhite: 0.08, alpha: 0.24))

        let outer = isoPolygon([(0, 0), (10, 0), (10, 8), (0, 8)], origin: origin, z: 0)
        fill(
            outer,
            NSColor(calibratedRed: 0.28, green: 0.43, blue: 0.27, alpha: 1),
            stroke: NSColor(calibratedRed: 0.10, green: 0.17, blue: 0.17, alpha: 0.85),
            lineWidth: 2
        )

        let inner = isoPolygon([(0.18, 0.18), (9.82, 0.18), (9.82, 7.82), (0.18, 7.82)], origin: origin, z: 0.03)
        fill(
            inner,
            NSColor(calibratedRed: 0.47, green: 0.62, blue: 0.38, alpha: 1),
            stroke: NSColor(calibratedRed: 0.69, green: 0.75, blue: 0.56, alpha: 0.8),
            lineWidth: 1
        )
    }

    private func drawRoadNetwork(origin: CGPoint) {
        drawRoad(x: 4.55, y: 0.16, width: 0.76, depth: 7.68, origin: origin)
        drawRoad(x: 0.16, y: 3.42, width: 9.68, depth: 0.76, origin: origin)

        for y in stride(from: 0.62, through: 7.25, by: 0.92) {
            drawLaneDash(x: 4.87, y: y, width: 0.10, depth: 0.38, origin: origin)
        }
        for x in stride(from: 0.58, through: 9.25, by: 0.94) {
            drawLaneDash(x: x, y: 3.74, width: 0.40, depth: 0.10, origin: origin)
        }
    }

    private func drawRoad(x: CGFloat, y: CGFloat, width: CGFloat, depth: CGFloat, origin: CGPoint) {
        let curb = isoPolygon(
            [(x - 0.12, y - 0.12), (x + width + 0.12, y - 0.12), (x + width + 0.12, y + depth + 0.12), (x - 0.12, y + depth + 0.12)],
            origin: origin,
            z: 0.07
        )
        fill(curb, NSColor(calibratedRed: 0.75, green: 0.72, blue: 0.65, alpha: 1))
        let asphalt = isoPolygon(
            [(x, y), (x + width, y), (x + width, y + depth), (x, y + depth)],
            origin: origin,
            z: 0.09
        )
        fill(
            asphalt,
            NSColor(calibratedRed: 0.20, green: 0.23, blue: 0.23, alpha: 1),
            stroke: NSColor(calibratedWhite: 0.38, alpha: 0.6),
            lineWidth: 0.7
        )
    }

    private func drawLaneDash(x: CGFloat, y: CGFloat, width: CGFloat, depth: CGFloat, origin: CGPoint) {
        let dash = isoPolygon(
            [(x, y), (x + width, y), (x + width, y + depth), (x, y + depth)],
            origin: origin,
            z: 0.11
        )
        fill(dash, NSColor(calibratedRed: 0.91, green: 0.78, blue: 0.39, alpha: 0.76))
    }

    private func drawPlacedAssets(origin: CGPoint) {
        let placements: [(AssetSprintResidentialCivicAsset, CGFloat, CGFloat)] = [
            (.cityHall, 7.45, 5.75),
            (.courtyardApartments, 2.15, 5.72),
            (.rowhouses, 4.10, 3.00),
            (.neighborhoodLibrary, 7.72, 1.62),
            (.craftsman, 1.55, 1.48)
        ]

        for (asset, x, y) in placements {
            draw(asset: asset, at: family.project(x: x, y: y, origin: origin))
        }
    }

    private func draw(asset: AssetSprintResidentialCivicAsset, at anchor: CGPoint) {
        guard let url = AssetSprintResidentialCivicCatalog.resourceURL(for: asset),
              let image = NSImage(contentsOf: url),
              let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first else { return }

        let width = CGFloat(bitmap.pixelsWide)
        let height = CGFloat(bitmap.pixelsHigh)
        let rect = CGRect(
            x: anchor.x - width * family.pivot.x,
            y: anchor.y - height * family.pivot.y,
            width: width,
            height: height
        )
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    private func drawStreetDetails(origin: CGPoint) {
        for (x, y) in [(4.32, 1.1), (5.54, 2.4), (4.30, 5.1), (5.55, 6.55)] {
            let base = family.project(x: x, y: y, z: 0.12, origin: origin)
            let top = CGPoint(x: base.x, y: base.y + 25)
            NSColor(calibratedRed: 0.15, green: 0.19, blue: 0.19, alpha: 1).setStroke()
            let pole = NSBezierPath()
            pole.move(to: base)
            pole.line(to: top)
            pole.lineWidth = 2
            pole.stroke()
            NSColor(calibratedRed: 1.0, green: 0.77, blue: 0.35, alpha: 0.95).setFill()
            NSBezierPath(ovalIn: CGRect(x: top.x - 4, y: top.y - 2, width: 8, height: 6)).fill()
        }
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
        lineWidth: CGFloat = 1
    ) {
        color.setFill()
        path.fill()
        if let stroke {
            stroke.setStroke()
            path.lineWidth = lineWidth
            path.stroke()
        }
    }
}
