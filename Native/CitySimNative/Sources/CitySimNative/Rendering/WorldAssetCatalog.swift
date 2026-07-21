import AppKit
import SpriteKit

struct WorldAssetResidencySnapshot: Equatable, Sendable {
    let activeDetail: CameraDetailLevel?
    let residentTextureCount: Int
    let residentDecodedBytes: Int
    let highWaterDecodedBytes: Int
    let cacheHits: Int
    let cacheMisses: Int
    let evictions: Int
    let fallbackCount: Int
}

@MainActor
struct GeneratedWorldPresentation {
    let sprite: SKSpriteNode
    let asset: GeneratedWorldAssetManifest.Asset
    let lod: GeneratedWorldAssetManifest.LOD
}

/// Loads repo-owned world resources through SwiftPM's resource bundle and keeps
/// generated-v4 residency bounded to the active semantic LOD. Geometry comes
/// from the shipping descriptor; SpriteKit never infers gameplay footprint.
@MainActor
final class WorldAssetCatalog {
    static let shared = WorldAssetCatalog()

    private struct TextureRecord {
        let texture: SKTexture
        let decodedBytes: Int
        let generatedDetail: CameraDetailLevel?
    }

    private var textures: [String: TextureRecord] = [:]
    private var activeGeneratedDetail: CameraDetailLevel?
    private var residentGeneratedBytes = 0
    private var highWaterGeneratedBytes = 0
    private var cacheHits = 0
    private var cacheMisses = 0
    private var evictionCount = 0
    private var fallbackCount = 0

    private(set) lazy var generatedManifest: GeneratedWorldAssetManifest? = loadGeneratedManifest()
    private lazy var generatedAssetsByID: [String: GeneratedWorldAssetManifest.Asset] = {
        Dictionary(uniqueKeysWithValues: (generatedManifest?.assets ?? []).map { ($0.logicalID, $0) })
    }()
    private lazy var generatedInventoryByStem: [String: GeneratedWorldAssetManifest.InventoryItem] = {
        Dictionary(uniqueKeysWithValues: (generatedManifest?.inventory ?? []).map {
            ((($0.file as NSString).deletingPathExtension), $0)
        })
    }()

    private func loadGeneratedManifest() -> GeneratedWorldAssetManifest? {
        guard let url = Bundle.module.url(
            forResource: "generated-v4-manifest",
            withExtension: "json",
            subdirectory: "WorldAssets.atlas"
        ), let data = try? Data(contentsOf: url),
           let manifest = try? JSONDecoder().decode(GeneratedWorldAssetManifest.self, from: data),
           manifest.schema == 4,
           manifest.packID == "generated-v4-calibration",
           manifest.productionSelection else { return nil }
        return manifest
    }

    func generatedAsset(logicalID: String) -> GeneratedWorldAssetManifest.Asset? {
        generatedAssetsByID[logicalID]
    }

    func prepareGeneratedResidency(for detail: CameraDetailLevel) {
        guard activeGeneratedDetail != detail else { return }
        activeGeneratedDetail = detail
        let staleNames: [String] = textures.compactMap { element in
            let (name, record) = element
            guard let residentDetail = record.generatedDetail,
                  residentDetail != detail else { return nil }
            return name
        }
        for name in staleNames {
            guard let removed = textures.removeValue(forKey: name) else { continue }
            residentGeneratedBytes = max(0, residentGeneratedBytes - removed.decodedBytes)
            evictionCount += 1
        }
    }

    func residencySnapshot() -> WorldAssetResidencySnapshot {
        WorldAssetResidencySnapshot(
            activeDetail: activeGeneratedDetail,
            residentTextureCount: textures.values.filter { $0.generatedDetail != nil }.count,
            residentDecodedBytes: residentGeneratedBytes,
            highWaterDecodedBytes: highWaterGeneratedBytes,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            evictions: evictionCount,
            fallbackCount: fallbackCount
        )
    }

    func manifestValidationIssues() -> [String] {
        guard let manifest = generatedManifest else { return ["generated-v4 manifest failed to decode"] }
        var issues: [String] = []
        if Set(manifest.assets.map(\.logicalID)).count != manifest.assets.count {
            issues.append("logical IDs are not unique")
        }
        if Set(manifest.inventory.map(\.file)).count != manifest.inventory.count {
            issues.append("inventory filenames are not unique")
        }
        if manifest.compiledNetwork.connectionMasks != 16 {
            issues.append("compiled road network does not contain 16 masks")
        }
        for asset in manifest.assets {
            if asset.sourceCanvasPixels.count != 2 || asset.footprintTiles != [1, 1] {
                issues.append("\(asset.logicalID) does not resolve to one authoritative presentation tile")
            }
            if asset.groundContactPolygonWorld.count < 4 || asset.opaqueBoundsWorld.count != 4
                || asset.shadowBoundsWorld.count != 4 || asset.placementOffsetWorld.count != 2 {
                issues.append("\(asset.logicalID) has incomplete physical geometry")
            }
            for detail in CameraDetailLevel.allCases {
                guard let lod = asset.lods[detail.assetSuffix] else {
                    issues.append("\(asset.logicalID) is missing \(detail.assetSuffix) LOD")
                    continue
                }
                if lod.pixels.count != 2 || lod.trimRectPixels.count != 4
                    || lod.anchor.count != 2 || lod.worldSize.count != 2 {
                    issues.append("\(asset.logicalID).\(detail.assetSuffix) has incomplete registration")
                }
            }
        }
        for detail in CameraDetailLevel.allCases {
            let assetBytes = manifest.assets.compactMap { $0.lods[detail.assetSuffix]?.decodedByteEstimate }.reduce(0, +)
            let roadBytes = (manifest.compiledNetwork.lods[detail.assetSuffix]?.decodedBytesPerTexture ?? 0)
                * manifest.compiledNetwork.connectionMasks
            if assetBytes + roadBytes > 96 * 1_024 * 1_024 {
                issues.append("\(detail.assetSuffix) active residency exceeds 96 MiB")
            }
        }
        return issues
    }

    func texture(named name: String) -> SKTexture? {
        if let detail = generatedDetail(for: name) {
            prepareGeneratedResidency(for: detail)
        }
        if let cached = textures[name] {
            cacheHits += 1
            return cached.texture
        }
        cacheMisses += 1
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "WorldAssets.atlas"
        ), let image = NSImage(contentsOf: url) else {
            return nil
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = name.hasPrefix("golden_district_")
        let detail = generatedDetail(for: name)
        let decodedBytes = generatedInventoryByStem[name]?.decodedByteEstimate ?? 0
        textures[name] = TextureRecord(
            texture: texture,
            decodedBytes: decodedBytes,
            generatedDetail: detail
        )
        if detail != nil {
            residentGeneratedBytes += decodedBytes
            highWaterGeneratedBytes = max(highWaterGeneratedBytes, residentGeneratedBytes)
        }
        return texture
    }

    func sprite(
        named name: String,
        size: CGSize,
        anchorPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> SKSpriteNode? {
        guard let texture = texture(named: name) else { return nil }
        let sprite = SKSpriteNode(texture: texture, color: .clear, size: size)
        sprite.anchorPoint = anchorPoint
        sprite.name = "asset.\(name)"
        return sprite
    }

    func generatedPresentation(
        logicalID: String,
        detail: CameraDetailLevel
    ) -> GeneratedWorldPresentation? {
        prepareGeneratedResidency(for: detail)
        guard let asset = generatedAssetsByID[logicalID],
              let lod = asset.lods[detail.assetSuffix],
              lod.pixels.count == 2,
              lod.trimRectPixels.count == 4,
              lod.worldSize.count == 2,
              lod.anchor.count == 2 else {
            fallbackCount += 1
            return nil
        }
        let name = (lod.file as NSString).deletingPathExtension
        guard let sourceTexture = texture(named: name) else {
            fallbackCount += 1
            return nil
        }
        let pixelWidth = CGFloat(lod.pixels[0])
        let pixelHeight = CGFloat(lod.pixels[1])
        let trim = lod.trimRectPixels.map(CGFloat.init)
        guard pixelWidth > 0, pixelHeight > 0, trim[2] > 0, trim[3] > 0 else {
            fallbackCount += 1
            return nil
        }
        let textureRect = CGRect(
            x: trim[0] / pixelWidth,
            y: (pixelHeight - trim[1] - trim[3]) / pixelHeight,
            width: trim[2] / pixelWidth,
            height: trim[3] / pixelHeight
        )
        let croppedTexture = SKTexture(rect: textureRect, in: sourceTexture)
        croppedTexture.filteringMode = .linear
        croppedTexture.usesMipmaps = false
        let sprite = SKSpriteNode(
            texture: croppedTexture,
            color: .clear,
            size: CGSize(width: lod.worldSize[0], height: lod.worldSize[1])
        )
        sprite.anchorPoint = CGPoint(x: lod.anchor[0], y: lod.anchor[1])
        sprite.position = CGPoint(
            x: asset.placementOffsetWorld[0],
            y: asset.placementOffsetWorld[1]
        )
        sprite.zPosition = asset.depthRoles["structure"]
            ?? asset.depthRoles["ground"]
            ?? asset.depthRoles["network"]
            ?? 0
        sprite.name = "asset.generated-v4.\(logicalID).\(detail.assetSuffix)"
        return GeneratedWorldPresentation(sprite: sprite, asset: asset, lod: lod)
    }

    func generatedSprite(
        logicalID: String,
        detail: CameraDetailLevel
    ) -> SKSpriteNode? {
        generatedPresentation(logicalID: logicalID, detail: detail)?.sprite
    }

    func generatedRoadSprite(
        connectionMask: UInt8,
        detail: CameraDetailLevel
    ) -> SKSpriteNode? {
        prepareGeneratedResidency(for: detail)
        guard connectionMask < 16,
              let descriptor = generatedManifest?.compiledNetwork.lods[detail.assetSuffix],
              descriptor.worldSize.count == 2 else {
            fallbackCount += 1
            return nil
        }
        let name = String(
            format: "generated_v4_road_mask_%02d_%@",
            connectionMask,
            detail.assetSuffix
        )
        guard let sprite = sprite(
            named: name,
            size: CGSize(width: descriptor.worldSize[0], height: descriptor.worldSize[1])
        ) else {
            fallbackCount += 1
            return nil
        }
        sprite.name = "road.generated-v4.\(connectionMask).\(detail.assetSuffix)"
        sprite.zPosition = generatedAssetsByID["road_material"]?.depthRoles["network"] ?? 2
        return sprite
    }

    private func generatedDetail(for name: String) -> CameraDetailLevel? {
        guard name.hasPrefix("generated_v4_") else { return nil }
        if name.hasSuffix("_block") { return .block }
        if name.hasSuffix("_neighborhood") { return .neighborhood }
        if name.hasSuffix("_city") { return .city }
        return nil
    }
}

extension CameraDetailLevel {
    var assetSuffix: String {
        switch self {
        case .city: "city"
        case .neighborhood: "neighborhood"
        case .block: "block"
        }
    }
}
