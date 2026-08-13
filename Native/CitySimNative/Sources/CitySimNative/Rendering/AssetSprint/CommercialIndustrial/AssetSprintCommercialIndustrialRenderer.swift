import AppKit
import Foundation

/// Composes the approved production sprites with one shared projection and one
/// global scene scale. Individual assets receive no rotation, skew, or scale fixup.
@MainActor
final class AssetSprintCommercialIndustrialRenderer {
    struct Placement: Equatable, Sendable {
        let asset: AssetSprintCommercialIndustrialAsset
        let anchor: CGPoint
    }

    static let canonicalPlacements: [Placement] = [
        // Service district, back to front.
        Placement(asset: .utilityIndustry, anchor: CGPoint(x: 1_020, y: 432)),
        Placement(asset: .factory, anchor: CGPoint(x: 642, y: 472)),
        Placement(asset: .workshop, anchor: CGPoint(x: 262, y: 425)),
        // Active main street, back to front.
        Placement(asset: .cornerShop, anchor: CGPoint(x: 262, y: 178)),
        Placement(asset: .mixedUse, anchor: CGPoint(x: 642, y: 174)),
        Placement(asset: .cafe, anchor: CGPoint(x: 1_020, y: 182)),
    ]

    let family: AssetSprintCommercialIndustrialFamily
    let assetScale: CGFloat = 0.80

    init(family: AssetSprintCommercialIndustrialFamily = .canonical) {
        self.family = family
    }

    func renderRepresentativeBlock(size: CGSize) -> NSBitmapImageRep? {
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
        drawBackdrop(size: size)

        let canonicalSize = CGSize(width: 1_280, height: 800)
        let sceneScale = min(size.width / canonicalSize.width, size.height / canonicalSize.height)
        let offset = CGPoint(
            x: (size.width - canonicalSize.width * sceneScale) / 2,
            y: (size.height - canonicalSize.height * sceneScale) / 2
        )
        context.cgContext.saveGState()
        context.cgContext.translateBy(x: offset.x, y: offset.y)
        context.cgContext.scaleBy(x: sceneScale, y: sceneScale)
        drawDistrictGround()
        drawRoadAndBuffer()
        drawStreetDetails()
        for placement in Self.canonicalPlacements {
            draw(placement.asset, anchoredAt: placement.anchor)
        }
        context.cgContext.restoreGState()
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    func pngData(for image: NSBitmapImageRep) -> Data? {
        image.representation(using: .png, properties: [:])
    }

    func image(for asset: AssetSprintCommercialIndustrialAsset) -> NSImage? {
        guard let directory = AssetSprintCommercialIndustrialFamily.resourceDirectoryURL else { return nil }
        return NSImage(contentsOf: directory.appendingPathComponent(asset.fileName))
    }

    private func draw(_ asset: AssetSprintCommercialIndustrialAsset, anchoredAt anchor: CGPoint) {
        guard let image = image(for: asset) else { return }
        let size = CGSize(width: asset.pixelSize.width * assetScale, height: asset.pixelSize.height * assetScale)
        let origin = CGPoint(
            x: anchor.x - size.width * family.pivot.x,
            y: anchor.y - size.height * family.pivot.y
        )
        image.draw(
            in: CGRect(origin: origin, size: size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func drawBackdrop(size: CGSize) {
        NSGradient(colors: [
            NSColor(calibratedRed: 0.48, green: 0.55, blue: 0.52, alpha: 1),
            NSColor(calibratedRed: 0.23, green: 0.32, blue: 0.34, alpha: 1),
        ])?.draw(in: CGRect(origin: .zero, size: size), angle: 90)
    }

    private func drawDistrictGround() {
        let shadow = polygon([
            CGPoint(x: 660, y: 55), CGPoint(x: 1_205, y: 330),
            CGPoint(x: 660, y: 690), CGPoint(x: 115, y: 330),
        ])
        NSColor.black.withAlphaComponent(0.22).setFill()
        let transform = AffineTransform(translationByX: 24, byY: -18)
        shadow.transform(using: transform)
        shadow.fill()

        let ground = polygon([
            CGPoint(x: 640, y: 82), CGPoint(x: 1_180, y: 350),
            CGPoint(x: 640, y: 684), CGPoint(x: 100, y: 350),
        ])
        NSColor(calibratedRed: 0.39, green: 0.52, blue: 0.31, alpha: 1).setFill()
        ground.fill()
        NSColor(calibratedWhite: 0.12, alpha: 0.72).setStroke()
        ground.lineWidth = 3
        ground.stroke()
    }

    private func drawRoadAndBuffer() {
        NSGraphicsContext.current?.saveGraphicsState()
        polygon([
            CGPoint(x: 640, y: 82), CGPoint(x: 1_180, y: 350),
            CGPoint(x: 640, y: 684), CGPoint(x: 100, y: 350),
        ]).addClip()
        fill(polygon([
            CGPoint(x: 125, y: 280), CGPoint(x: 585, y: 510),
            CGPoint(x: 1_155, y: 225), CGPoint(x: 695, y: 0),
        ]), color: NSColor(calibratedWhite: 0.19, alpha: 1))
        fill(polygon([
            CGPoint(x: 175, y: 515), CGPoint(x: 300, y: 578),
            CGPoint(x: 1_100, y: 178), CGPoint(x: 972, y: 115),
        ]), color: NSColor(calibratedWhite: 0.24, alpha: 1))

        let buffer = polygon([
            CGPoint(x: 200, y: 348), CGPoint(x: 300, y: 398),
            CGPoint(x: 1_078, y: 10), CGPoint(x: 980, y: -39),
        ])
        fill(buffer, color: NSColor(calibratedRed: 0.33, green: 0.46, blue: 0.27, alpha: 1))
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private func drawStreetDetails() {
        let laneColor = NSColor(calibratedRed: 0.89, green: 0.70, blue: 0.30, alpha: 0.72)
        for x in stride(from: CGFloat(260), through: 1_015, by: 95) {
            let dash = polygon([
                CGPoint(x: x, y: 309), CGPoint(x: x + 34, y: 326),
                CGPoint(x: x + 42, y: 322), CGPoint(x: x + 8, y: 305),
            ])
            fill(dash, color: laneColor)
        }

        for point in [CGPoint(x: 180, y: 330), CGPoint(x: 1_090, y: 280), CGPoint(x: 915, y: 530)] {
            NSColor.black.withAlphaComponent(0.22).setFill()
            NSBezierPath(ovalIn: CGRect(x: point.x - 12, y: point.y - 7, width: 24, height: 12)).fill()
            NSColor(calibratedRed: 0.25, green: 0.42, blue: 0.19, alpha: 1).setFill()
            NSBezierPath(ovalIn: CGRect(x: point.x - 11, y: point.y + 5, width: 22, height: 31)).fill()
            NSColor(calibratedRed: 0.28, green: 0.20, blue: 0.13, alpha: 1).setStroke()
            let trunk = NSBezierPath()
            trunk.move(to: CGPoint(x: point.x, y: point.y))
            trunk.line(to: CGPoint(x: point.x, y: point.y + 12))
            trunk.lineWidth = 4
            trunk.stroke()
        }
    }

    private func polygon(_ points: [CGPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.line(to: point) }
        path.close()
        return path
    }

    private func fill(_ path: NSBezierPath, color: NSColor) {
        color.setFill()
        path.fill()
    }
}
