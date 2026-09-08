import AppKit
import SpriteKit

/// A source-pixel hit map, decoded once with the texture. No image readback or
/// asset transformation occurs during pointer movement.
struct CitySpriteAlphaMask {
    let width: Int
    let height: Int
    private let alpha: [UInt8]
    let roofAnchor: CGPoint?

    init?(bitmap: NSBitmapImageRep) {
        guard let source = bitmap.cgImage else { return nil }
        let bitmapWidth = bitmap.pixelsWide
        let bitmapHeight = bitmap.pixelsHigh
        width = bitmapWidth
        height = bitmapHeight
        guard width > 0, height > 0 else { return nil }
        var samples = [UInt8](repeating: 0, count: bitmapWidth * bitmapHeight * 4)
        let decoded = samples.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: bitmapWidth, height: bitmapHeight,
                bitsPerComponent: 8, bytesPerRow: bitmapWidth * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return false }
            context.draw(source, in: CGRect(x: 0, y: 0, width: bitmapWidth, height: bitmapHeight))
            return true
        }
        guard decoded else { return nil }
        let decodedAlpha = stride(from: 3, to: samples.count, by: 4).map { samples[$0] }
        alpha = decodedAlpha
        if let first = decodedAlpha.firstIndex(where: { $0 >= 128 }) {
            let row = first / bitmapWidth
            let columns = (0..<bitmapWidth).filter { decodedAlpha[row * bitmapWidth + $0] >= 128 }
            roofAnchor = CGPoint(
                x: (CGFloat(columns.first! + columns.last!) / 2 + 0.5) / CGFloat(width),
                y: 1 - CGFloat(row) / CGFloat(height)
            )
        } else {
            roofAnchor = nil
        }
    }

    /// Sprite texture coordinates are bottom-up; source bitmap rows are top-down.
    func containsOpaquePixel(at normalized: CGPoint) -> Bool {
        guard normalized.x.isFinite, normalized.y.isFinite,
              normalized.x >= 0, normalized.x < 1,
              normalized.y >= 0, normalized.y < 1 else { return false }
        let x = Int(normalized.x * CGFloat(width))
        let y = height - 1 - Int(normalized.y * CGFloat(height))
        // Ignore transparent padding and translucent ground shadows, retaining
        // the solid authored building/lot silhouette.
        return alpha[y * width + x] >= 128
    }
}

@MainActor
final class FourViewInspectionSprite: SKSpriteNode {
    var inspectionMask: CitySpriteAlphaMask?

    var roofAnchor: CGPoint? {
        guard let anchor = inspectionMask?.roofAnchor,
              size.width > 0, size.height > 0, xScale != 0, yScale != 0 else { return nil }
        return CGPoint(x: (anchor.x - anchorPoint.x) * size.width / abs(xScale),
                       y: (anchor.y - anchorPoint.y) * size.height / abs(yScale))
    }

    func containsOpaquePixel(at localPoint: CGPoint) -> Bool {
        guard size.width > 0, size.height > 0, xScale != 0, yScale != 0 else { return false }
        // SpriteKit reports the scaled sprite size, while convert(_:from:)
        // returns coordinates before the node's scale is applied.
        let localWidth = size.width / abs(xScale)
        let localHeight = size.height / abs(yScale)
        return inspectionMask?.containsOpaquePixel(at: CGPoint(
            x: localPoint.x / localWidth + anchorPoint.x,
            y: localPoint.y / localHeight + anchorPoint.y
        )) ?? false
    }
}
