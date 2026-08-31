import AppKit
import CryptoKit
import ImageIO
import OSLog
import SpriteKit

struct WorldAssetResidencySnapshot: Equatable, Sendable {
    let packID: String
    let manifestSHA256: String?
    let activeDetail: CameraDetailLevel?
    let prefetchedDetail: CameraDetailLevel?
    let residentTextureCount: Int
    let residentDecodedBytes: Int
    let highWaterDecodedBytes: Int
    let cacheHits: Int
    let cacheMisses: Int
    let evictions: Int
    let fallbackCount: Int
    let fallbackDiagnostics: [String]
    let textureDecodeLoadCount: Int
    let textureDecodeLoadDurationMilliseconds: Double
}

@MainActor
struct GeneratedWorldPresentation {
    let sprite: SKSpriteNode
    let asset: GeneratedWorldAssetManifest.Asset
    let lod: GeneratedWorldAssetManifest.LOD
}

@MainActor
struct GeneratedResidentialPresentation {
    let identity: ResidentialGeneratedAssetIdentity
    let presentation: GeneratedWorldPresentation
}

@MainActor
struct GeneratedCommercialPresentation {
    let identity: CommercialGeneratedAssetIdentity
    let presentation: GeneratedWorldPresentation
}

@MainActor
struct GeneratedIndustrialPresentation {
    let identity: IndustrialGeneratedAssetIdentity
    let presentation: GeneratedWorldPresentation
}

@MainActor
struct GeneratedCivicPresentation {
    let identity: CivicGeneratedAssetIdentity
    let presentation: GeneratedWorldPresentation
}

/// Loads repo-owned world resources from the packaged app resource bundle or,
/// for SwiftPM builds and tests, `Bundle.module`. The generated-v4 loader
/// validates page digests, creates descriptor-authorized subtextures,
/// prefetches one adjacent semantic LOD, and keeps decoded pages bounded.
/// Geometry remains manifest authority; pixels never invent cells.
@MainActor
final class WorldAssetCatalog {
    static let shared = WorldAssetCatalog()

    private static let logger = Logger(
        subsystem: "com.jfmortensen.citysim",
        category: "generated-world-assets"
    )
    private static let generatedPackID = "generated-v4-calibration"
    private static let rollbackPackID = "legacy-v2"
    private static let maximumFallbackDiagnostics = 32
    static let resourceBundleName = "CitySimNative_CitySimNative.bundle"

    private struct TextureRecord {
        let texture: SKTexture
    }

    private struct PageRecord {
        let texture: SKTexture
        let decodedBytes: Int
        let detail: CameraDetailLevel
    }

    private let resourceBundle: Bundle
    private let requestedPackID: String?
    let selectedPackID: String

    private var textures: [String: TextureRecord] = [:]
    private var pageTextures: [String: PageRecord] = [:]
    private var generatedSubtextures: [String: SKTexture] = [:]
    private var activeGeneratedDetail: CameraDetailLevel?
    private var prefetchedGeneratedDetail: CameraDetailLevel?
    private var residentGeneratedBytes = 0
    private var highWaterGeneratedBytes = 0
    private var cacheHits = 0
    private var cacheMisses = 0
    private var evictionCount = 0
    private var fallbackCount = 0
    private var fallbackDiagnostics: [String] = []
    private var textureDecodeLoadCount = 0
    private var textureDecodeLoadDurationMilliseconds = 0.0
    private(set) var generatedManifestSHA256: String?

    private(set) lazy var generatedManifest: GeneratedWorldAssetManifest? = loadGeneratedManifest()
    private lazy var generatedAssetsByID: [String: GeneratedWorldAssetManifest.Asset] = {
        Dictionary(uniqueKeysWithValues: (generatedManifest?.assets ?? []).map { ($0.logicalID, $0) })
    }()
    private lazy var generatedPagesByID: [String: GeneratedWorldAssetManifest.Page] = {
        Dictionary(uniqueKeysWithValues: (generatedManifest?.pages ?? []).map { ($0.id, $0) })
    }()

    init(
        resourceBundle: Bundle? = nil,
        packOverride: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        if let resourceBundle {
            self.resourceBundle = resourceBundle
        } else if let packagedBundle = Self.packagedResourceBundle(
            mainResourceURL: Bundle.main.resourceURL
        ) {
            self.resourceBundle = packagedBundle
        } else {
            self.resourceBundle = .module
        }
        #if DEBUG
        let requested = packOverride ?? environment["CITYSIM_WORLD_ASSET_PACK"]
        #else
        let requested: String? = nil
        #endif
        requestedPackID = requested
        selectedPackID = requested == Self.rollbackPackID
            ? Self.rollbackPackID
            : Self.generatedPackID
    }

    static func packagedResourceBundle(mainResourceURL: URL?) -> Bundle? {
        guard let mainResourceURL else { return nil }
        let bundleURL = mainResourceURL.appendingPathComponent(
            resourceBundleName,
            isDirectory: true
        )
        return Bundle(path: bundleURL.path)
    }

    private func loadGeneratedManifest() -> GeneratedWorldAssetManifest? {
        guard selectedPackID == Self.generatedPackID else { return nil }
        if let requestedPackID,
           requestedPackID != Self.generatedPackID,
           requestedPackID != Self.rollbackPackID {
            recordFallback("unknown pack override \(requestedPackID)")
            return nil
        }
        guard let url = resourceBundle.url(
            forResource: "generated-v4-manifest",
            withExtension: "json",
            subdirectory: "WorldAssets.atlas"
        ), let data = try? Data(contentsOf: url) else {
            recordFallback("generated-v4 manifest missing from resource bundle")
            return nil
        }
        generatedManifestSHA256 = Self.sha256(data)
        guard let manifest = try? JSONDecoder().decode(GeneratedWorldAssetManifest.self, from: data),
              manifest.schema == 4,
              manifest.packID == Self.generatedPackID,
              manifest.productionSelection else {
            recordFallback("generated-v4 manifest rejected")
            return nil
        }
        return manifest
    }

    func generatedAsset(logicalID: String) -> GeneratedWorldAssetManifest.Asset? {
        generatedAssetsByID[logicalID]
    }

    func prepareGeneratedResidency(for detail: CameraDetailLevel) {
        guard selectedPackID == Self.generatedPackID else { return }
        guard activeGeneratedDetail != detail else { return }
        activeGeneratedDetail = detail
        prefetchedGeneratedDetail = adjacentDetail(to: detail)
        let allowed = Set([detail, prefetchedGeneratedDetail].compactMap { $0 })
        let stalePageIDs = pageTextures.compactMap { pageID, record in
            allowed.contains(record.detail) ? nil : pageID
        }
        for pageID in stalePageIDs {
            guard let removed = pageTextures.removeValue(forKey: pageID) else { continue }
            residentGeneratedBytes = max(0, residentGeneratedBytes - removed.decodedBytes)
            evictionCount += 1
        }
        generatedSubtextures = generatedSubtextures.filter { key, _ in
            allowed.contains(where: { key.hasSuffix("|\($0.assetSuffix)") })
        }
    }

    /// Resolve active semantic pages before node creation, then warm one
    /// adjacent LOD. The accepted calibration pack needs at most three resident
    /// pages for this active-plus-next policy.
    func preloadGeneratedResidency(
        for detail: CameraDetailLevel,
        logicalIDs: Set<String>,
        roadMasks: Set<UInt8> = []
    ) {
        guard selectedPackID == Self.generatedPackID else { return }
        prepareGeneratedResidency(for: detail)
        var pageIDs = Set<String>()
        for requestedDetail in [detail, prefetchedGeneratedDetail].compactMap({ $0 }) {
            for logicalID in logicalIDs.sorted() {
                guard let asset = generatedAssetsByID[logicalID],
                      let lod = asset.lods[requestedDetail.assetSuffix] else {
                    continue
                }
                pageIDs.insert(lod.page)
                _ = packedTexture(
                    pageID: lod.page,
                    rectPixels: lod.textureRectPixels,
                    cacheKey: "asset:\(logicalID)|\(requestedDetail.assetSuffix)",
                    detail: requestedDetail
                )
            }
            if let network = generatedManifest?.compiledNetwork.lods[requestedDetail.assetSuffix] {
                for mask in roadMasks.sorted() {
                    if let placement = network.textures[String(mask)] {
                        let page = placement.page
                        pageIDs.insert(page)
                        _ = packedTexture(
                            pageID: page,
                            rectPixels: placement.textureRectPixels,
                            cacheKey: "road:\(mask)|\(requestedDetail.assetSuffix)",
                            detail: requestedDetail
                        )
                    }
                }
            }
        }
        for pageID in pageIDs.sorted() {
            _ = pageTexture(pageID: pageID)
        }
    }

    func residencySnapshot() -> WorldAssetResidencySnapshot {
        WorldAssetResidencySnapshot(
            packID: selectedPackID,
            manifestSHA256: generatedManifestSHA256,
            activeDetail: activeGeneratedDetail,
            prefetchedDetail: prefetchedGeneratedDetail,
            residentTextureCount: pageTextures.count,
            residentDecodedBytes: residentGeneratedBytes,
            highWaterDecodedBytes: highWaterGeneratedBytes,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            evictions: evictionCount,
            fallbackCount: fallbackCount,
            fallbackDiagnostics: fallbackDiagnostics,
            textureDecodeLoadCount: textureDecodeLoadCount,
            textureDecodeLoadDurationMilliseconds: textureDecodeLoadDurationMilliseconds
        )
    }

    func manifestValidationIssues() -> [String] {
        if selectedPackID == Self.rollbackPackID { return [] }
        guard let manifest = generatedManifest else {
            return ["generated-v4 manifest failed to decode"]
        }
        var issues: [String] = []
        let pageByID = Dictionary(uniqueKeysWithValues: manifest.pages.map { ($0.id, $0) })
        let inventoryByFile = Dictionary(uniqueKeysWithValues: manifest.inventory.map { ($0.file, $0) })
        if Set(manifest.assets.map(\.logicalID)).count != manifest.assets.count {
            issues.append("logical IDs are not unique")
        }
        if Set(manifest.pages.map(\.id)).count != manifest.pages.count {
            issues.append("page IDs are not unique")
        }
        if Set(manifest.inventory.map(\.file)).count != manifest.inventory.count {
            issues.append("inventory filenames are not unique")
        }
        if manifest.compiledNetwork.connectionMasks != 16 {
            issues.append("compiled road network does not contain 16 masks")
        }
        let residential = manifest.assets.filter {
            $0.family == "residential" && $0.viewDirection != nil
        }
        let directions = ["north", "east", "south", "west"]
        let residentialVariantZero = residential.filter { $0.variant == 0 }
        let residentialVariantOne = residential.filter { $0.variant == 1 }
        let residentialVariantTwo = residential.filter { $0.variant == 2 }
        let expectedResidentialVariantZero = Set(
            (1...4).flatMap { level in
                directions.map {
                    "residential_l\(String(format: "%02d", level))_v0_\($0)"
                }
            }
        )
        let expectedResidentialVariantOne = Set(directions.map { "residential_l01_v1_\($0)" })
        let expectedResidentialVariantTwo = Set(directions.map { "residential_l01_v2_\($0)" })
        if Set(residentialVariantZero.map(\.logicalID)) != expectedResidentialVariantZero {
            issues.append("residential v0 production selection is not the exact L1-L4 N/E/S/W matrix")
        }
        if Set(residentialVariantOne.map(\.logicalID)) != expectedResidentialVariantOne {
            issues.append("residential L1 variant-one production selection is not the exact N/E/S/W quartet")
        }
        if Set(residentialVariantTwo.map(\.logicalID)) != expectedResidentialVariantTwo {
            issues.append("residential L1 variant-two production selection is not the exact N/E/S/W quartet")
        }
        let civic = manifest.assets.filter {
            $0.family == "civic" && $0.level == 1 && $0.viewDirection != nil
        }
        let expectedCivic = Set(directions.map { "civic_l01_v0_\($0)" })
        if Set(civic.map(\.logicalID)) != expectedCivic {
            issues.append("civic L1 production selection is not the exact N/E/S/W quartet")
        }
        if Set(civic.compactMap(\.sourceSHA256)).count != 4 {
            issues.append("civic L1 production sources are missing or aliased")
        }
        let civicLODHashes = civic.flatMap { asset in
            CameraDetailLevel.allCases.compactMap {
                asset.lods[$0.assetSuffix]?.normalizedSHA256
            }
        }
        if Set(civicLODHashes).count != 12 {
            issues.append("civic L1 normalized LODs are missing or aliased")
        }
        for asset in civic {
            guard let direction = asset.viewDirection else {
                issues.append("\(asset.logicalID) is missing view direction")
                continue
            }
            if asset.frontageEdge != direction
                || asset.supportedOrientation != "\(direction)-facing-authored"
                || asset.provenanceFile == nil
                || asset.provenanceSHA256 == nil
                || asset.normalizationRecordFile == nil
                || asset.normalizationRecordSHA256 == nil {
                issues.append("\(asset.logicalID) has incomplete civic directional provenance")
            }
        }
        if Set(residentialVariantZero.compactMap(\.sourceKey)).count != 16
            || Set(residentialVariantZero.compactMap(\.sourceSHA256)).count != 16 {
            issues.append("residential v0 production sources are missing or aliased")
        }
        if Set(residentialVariantOne.compactMap(\.sourceKey)).count != 4
            || Set(residentialVariantOne.compactMap(\.sourceSHA256)).count != 4 {
            issues.append("residential L1 variant-one production sources are missing or aliased")
        }
        if Set(residentialVariantTwo.compactMap(\.sourceKey)).count != 4
            || Set(residentialVariantTwo.compactMap(\.sourceSHA256)).count != 4 {
            issues.append("residential L1 variant-two production sources are missing or aliased")
        }
        let normalizedResidentialVariantZeroHashes = residentialVariantZero.flatMap { asset in
            CameraDetailLevel.allCases.compactMap {
                asset.lods[$0.assetSuffix]?.normalizedSHA256
            }
        }
        let normalizedResidentialVariantOneHashes = residentialVariantOne.flatMap { asset in
            CameraDetailLevel.allCases.compactMap {
                asset.lods[$0.assetSuffix]?.normalizedSHA256
            }
        }
        let variantZeroLODHashes = Set(normalizedResidentialVariantZeroHashes)
        let variantOneLODHashes = Set(normalizedResidentialVariantOneHashes)
        let normalizedResidentialVariantTwoHashes = residentialVariantTwo.flatMap { asset in
            CameraDetailLevel.allCases.compactMap {
                asset.lods[$0.assetSuffix]?.normalizedSHA256
            }
        }
        let variantTwoLODHashes = Set(normalizedResidentialVariantTwoHashes)
        if variantZeroLODHashes.count != 48 {
            issues.append("residential v0 normalized LODs are missing or aliased")
        }
        if variantOneLODHashes.count != 12 || !variantZeroLODHashes.isDisjoint(with: variantOneLODHashes) {
            issues.append("residential L1 variant-one normalized LODs are missing or aliased")
        }
        if variantTwoLODHashes.count != 12
            || !variantZeroLODHashes.isDisjoint(with: variantTwoLODHashes)
            || !variantOneLODHashes.isDisjoint(with: variantTwoLODHashes) {
            issues.append("residential L1 variant-two normalized LODs are missing or aliased")
        }
        for asset in residentialVariantZero {
            guard let direction = asset.viewDirection else {
                issues.append("\(asset.logicalID) is missing view direction")
                continue
            }
            if asset.frontageEdge != direction
                || asset.supportedOrientation != "\(direction)-facing-authored"
                || asset.sourceRevision == nil
                || asset.provenanceFile == nil
                || asset.provenanceSHA256 == nil
                || asset.normalizationRecordFile == nil
                || asset.normalizationRecordSHA256 == nil
                || asset.sceneDescriptorFile == nil
                || asset.sceneDescriptorSHA256 == nil {
                issues.append("\(asset.logicalID) has incomplete directional provenance")
            }
        }
        let variantOneRawSHA256 = [
            "east": "ec8da7e13befac3abd5e3f242168649fb91b3cc59061a0e9122596329f97b1f3",
            "north": "1661eeebe01dbfeb0bf5b443ebe61f1ed850e5650258917b09b24d2de03bdab2",
            "south": "ef1dab1277f0c2dd6cd3a37a1e459e94c417b013fadda5f4f46b6b21187e3577",
            "west": "49657d70488a1478b384c035c73b7551653ffb1f2549fcf20134bed55f622386",
        ]
        let variantOneReceipt = "CitySimNative/WorldArt/ImageGenFourView/PLAY-101/residential_l01_v1/BUILD-RECEIPT.json"
        let variantOneReceiptSHA256 = "9d8360f997bee2125e8223de36c709f2bc7f79ab68a63b5f2cac138134a7e95b"
        for asset in residentialVariantOne {
            let direction = asset.viewDirection
            let expectedSourceKey = direction.map { "residential_l01/variant-1/\($0)/source-v01" }
            let expectedSourceSHA256 = direction.flatMap({ variantOneRawSHA256[$0] })
            if asset.level != 1
                || asset.frontageEdge != direction
                || asset.supportedOrientation != direction.map({ "\($0)-facing-authored" })
                || asset.sourceRevision != "source-v01"
                || asset.sourceKey != expectedSourceKey
                || asset.sourceSHA256 != expectedSourceSHA256
                || asset.provenanceFile != variantOneReceipt
                || asset.provenanceSHA256 != variantOneReceiptSHA256
                || asset.normalizationRecordFile != variantOneReceipt
                || asset.normalizationRecordSHA256 != variantOneReceiptSHA256
                || asset.sceneDescriptorFile != nil
                || asset.sceneDescriptorSHA256 != nil {
                issues.append("\(asset.logicalID) does not bind the admitted variant-one build receipt")
            }
        }
        let variantTwoRawSHA256 = [
            "east": "5a73d62cfc26d3f1caa07b6f66373c24d06b81bdcb64da6f4c6ef5a061e4a15a",
            "north": "424301b44eb4ef31dc81021917bb222a64f480d1d9d7d7a0f727b0aa7da78bab",
            "south": "e9601a663c479b8eff8887ab853dcf6b59719054c4c5eb72a2e391eb053921b6",
            "west": "ec25dae262dc8706b2e063acdd80179dacdf919f0f072c7634dd92516a2f60c3",
        ]
        let variantTwoReceipt = "CitySimNative/WorldArt/ImageGenFourView/PLAY-101/residential_l01_v2/normalized-v03/NORMALIZATION-RECEIPT.json"
        let variantTwoReceiptSHA256 = "219878c2a4a3d3a38f94a88b050555b6196f49d0ebcb5450a55e5dfd9bef8bef"
        for asset in residentialVariantTwo {
            let direction = asset.viewDirection
            let expectedSourceKey = direction.map { "residential_l01/variant-2/\($0)/source-v03" }
            let expectedSourceSHA256 = direction.flatMap({ variantTwoRawSHA256[$0] })
            if asset.level != 1
                || asset.frontageEdge != direction
                || asset.supportedOrientation != direction.map({ "\($0)-facing-authored" })
                || asset.sourceRevision != "source-v03"
                || asset.sourceKey != expectedSourceKey
                || asset.sourceSHA256 != expectedSourceSHA256
                || asset.provenanceFile != variantTwoReceipt
                || asset.provenanceSHA256 != variantTwoReceiptSHA256
                || asset.normalizationRecordFile != variantTwoReceipt
                || asset.normalizationRecordSHA256 != variantTwoReceiptSHA256
                || asset.sceneDescriptorFile != nil
                || asset.sceneDescriptorSHA256 != nil {
                issues.append("\(asset.logicalID) does not bind the admitted variant-two build receipt")
            }
        }
        let industrial = manifest.assets.filter {
            $0.family == "industrial" && $0.viewDirection != nil
        }
        let expectedIndustrialIdentities = Set(
            (1...3).flatMap { level in
                ["north", "east", "south", "west"].map {
                    "industrial_l\(String(format: "%02d", level))_v0_\($0)"
                }
            }
        )
        if Set(industrial.map(\.logicalID)) != expectedIndustrialIdentities {
            issues.append("industrial production selection is not the exact L1-L3 N/E/S/W matrix")
        }
        if Set(industrial.compactMap(\.sourceKey)).count != 12
            || Set(industrial.compactMap(\.sourceSHA256)).count != 12 {
            issues.append("industrial L1-L3 production sources are missing or aliased")
        }
        let normalizedIndustrialHashes = industrial.flatMap { asset in
            CameraDetailLevel.allCases.compactMap {
                asset.lods[$0.assetSuffix]?.normalizedSHA256
            }
        }
        if Set(normalizedIndustrialHashes).count != 36 {
            issues.append("industrial L1-L3 normalized LODs are missing or aliased")
        }
        for asset in industrial {
            guard let direction = asset.viewDirection else {
                issues.append("\(asset.logicalID) is missing view direction")
                continue
            }
            if !(1...3).contains(asset.level)
                || asset.frontageEdge != direction
                || asset.supportedOrientation != "\(direction)-facing-authored"
                || asset.provenanceFile == nil
                || asset.provenanceSHA256 == nil
                || asset.normalizationRecordFile == nil
                || asset.normalizationRecordSHA256 == nil
                || asset.sceneDescriptorFile == nil
                || asset.sceneDescriptorSHA256 == nil {
                issues.append("\(asset.logicalID) has incomplete directional provenance")
            }
        }
        for page in manifest.pages {
            if page.pixels.count != 2
                || !page.pixels.allSatisfy({ $0 > 0 && $0 <= 2_048 && $0.nonzeroBitCount == 1 }) {
                issues.append("\(page.id) is not a bounded power-of-two page")
            }
            if page.paddingPixels < 4 || page.extrusionPixels < 2 || page.rotation {
                issues.append("\(page.id) violates padding/extrusion/rotation policy")
            }
            guard let inventory = inventoryByFile[page.file],
                  inventory.sha256 == page.sha256,
                  inventory.pixels == page.pixels else {
                issues.append("\(page.id) inventory record is missing or inconsistent")
                continue
            }
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
                if lod.pixels.count != 2 || lod.sourcePixels.count != 2
                    || lod.trimRectPixels.count != 4 || lod.sourceTrimRectPixels.count != 4
                    || lod.textureRectPixels.count != 4 || lod.packedRectPixels.count != 4
                    || lod.anchor.count != 2 || lod.worldSize.count != 2 {
                    issues.append("\(asset.logicalID).\(detail.assetSuffix) has incomplete registration")
                }
                if lod.paddingPixels < 4 || lod.extrusionPixels < 2 {
                    issues.append("\(asset.logicalID).\(detail.assetSuffix) has unsafe atlas padding")
                }
                validate(rect: lod.textureRectPixels, pageID: lod.page, expectedDetail: detail, pages: pageByID)
                    .map { issues.append("\(asset.logicalID).\(detail.assetSuffix) \($0)") }
            }
        }
        for detail in CameraDetailLevel.allCases {
            guard let network = manifest.compiledNetwork.lods[detail.assetSuffix] else {
                issues.append("compiled network is missing \(detail.assetSuffix)")
                continue
            }
            if network.textures.count != 16 {
                issues.append("compiled network \(detail.assetSuffix) does not declare 16 packed textures")
            }
            for mask in 0..<16 {
                guard let texture = network.textures[String(mask)] else {
                    issues.append("compiled network \(detail.assetSuffix) missing mask \(mask)")
                    continue
                }
                validate(
                    rect: texture.textureRectPixels,
                    pageID: texture.page,
                    expectedDetail: detail,
                    pages: pageByID
                ).map { issues.append("road \(mask).\(detail.assetSuffix) \($0)") }
            }
            let activeAndNext = Set([detail, adjacentDetail(to: detail)].compactMap { $0 })
            let decodedBytes = manifest.pages
                .filter { page in
                    activeAndNext.contains(where: { $0.assetSuffix == page.lod })
                }
                .reduce(0) { $0 + $1.decodedByteEstimate }
            if decodedBytes > 128 * 1_024 * 1_024 {
                issues.append("\(detail.assetSuffix) active-plus-next residency exceeds 128 MiB")
            }
        }
        return issues
    }

    func texture(named name: String) -> SKTexture? {
        if let cached = textures[name] {
            cacheHits += 1
            return cached.texture
        }
        cacheMisses += 1
        let started = ProcessInfo.processInfo.systemUptime
        defer {
            textureDecodeLoadCount += 1
            textureDecodeLoadDurationMilliseconds +=
                (ProcessInfo.processInfo.systemUptime - started) * 1_000
        }
        guard let url = resourceBundle.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "WorldAssets.atlas"
        ), let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
           let image = CGImageSourceCreateImageAtIndex(
               imageSource,
               0,
               [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
           ) else {
            return nil
        }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = name.hasPrefix("golden_district_")
        textures[name] = TextureRecord(texture: texture)
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
        guard selectedPackID == Self.generatedPackID else { return nil }
        prepareGeneratedResidency(for: detail)
        guard let asset = generatedAssetsByID[logicalID] else {
            recordFallback("unknown logical asset \(logicalID)")
            return nil
        }
        guard let lod = asset.lods[detail.assetSuffix],
              lod.pixels.count == 2,
              lod.sourcePixels.count == 2,
              lod.trimRectPixels.count == 4,
              lod.sourceTrimRectPixels.count == 4,
              lod.textureRectPixels.count == 4,
              lod.worldSize.count == 2,
              lod.anchor.count == 2 else {
            recordFallback("incomplete descriptor \(logicalID).\(detail.assetSuffix)")
            return nil
        }
        guard let presentationTexture = packedTexture(
            pageID: lod.page,
            rectPixels: lod.textureRectPixels,
            cacheKey: "asset:\(logicalID)|\(detail.assetSuffix)",
            detail: detail
        ) else {
            recordFallback("missing packed texture \(logicalID).\(detail.assetSuffix)")
            return nil
        }
        let sprite = SKSpriteNode(
            texture: presentationTexture,
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

    func generatedResidentialPresentation(
        level: Int,
        adjacentRoads: RoadConnectionMask,
        visualVariant: Int = 0,
        detail: CameraDetailLevel
    ) -> GeneratedResidentialPresentation? {
        guard let identity = ResidentialGeneratedAssetIdentity(
            level: level,
            adjacentRoads: adjacentRoads,
            visualVariant: visualVariant
        ) else {
            recordFallback(
                "residential level \(min(4, max(1, level))) has no authoritative adjacent road"
            )
            return nil
        }
        guard let asset = generatedAssetsByID[identity.logicalID],
              asset.family == "residential",
              asset.level == identity.level,
              asset.variant == identity.variant,
              asset.frontageEdge == identity.direction,
              asset.viewDirection == identity.direction else {
            recordFallback("directional descriptor mismatch \(identity.logicalID)")
            return nil
        }
        guard let presentation = generatedPresentation(
            logicalID: identity.logicalID,
            detail: detail
        ) else {
            return nil
        }
        return GeneratedResidentialPresentation(
            identity: identity,
            presentation: presentation
        )
    }

    func generatedCommercialPresentation(
        level: Int,
        adjacentRoads: RoadConnectionMask,
        detail: CameraDetailLevel
    ) -> GeneratedCommercialPresentation? {
        guard let identity = CommercialGeneratedAssetIdentity(
            level: level,
            adjacentRoads: adjacentRoads
        ) else {
            recordFallback(
                "commercial level \(min(4, max(1, level))) has no authoritative adjacent road"
            )
            return nil
        }
        guard let asset = generatedAssetsByID[identity.logicalID],
              asset.family == "commercial",
              asset.level == identity.level,
              asset.variant == 0,
              asset.frontageEdge == identity.direction,
              asset.viewDirection == identity.direction else {
            recordFallback("directional descriptor mismatch \(identity.logicalID)")
            return nil
        }
        guard let presentation = generatedPresentation(
            logicalID: identity.logicalID,
            detail: detail
        ) else {
            return nil
        }
        return GeneratedCommercialPresentation(
            identity: identity,
            presentation: presentation
        )
    }

    func generatedIndustrialPresentation(
        level: Int,
        adjacentRoads: RoadConnectionMask,
        detail: CameraDetailLevel
    ) -> GeneratedIndustrialPresentation? {
        guard let identity = IndustrialGeneratedAssetIdentity(
            level: level,
            adjacentRoads: adjacentRoads
        ) else {
            recordFallback(
                "industrial level \(level) has no accepted directional source or authoritative adjacent road"
            )
            return nil
        }
        guard let asset = generatedAssetsByID[identity.logicalID],
              asset.family == "industrial",
              asset.level == identity.level,
              asset.variant == 0,
              asset.frontageEdge == identity.direction,
              asset.viewDirection == identity.direction else {
            recordFallback("directional descriptor mismatch \(identity.logicalID)")
            return nil
        }
        guard let presentation = generatedPresentation(
            logicalID: identity.logicalID,
            detail: detail
        ) else {
            return nil
        }
        return GeneratedIndustrialPresentation(
            identity: identity,
            presentation: presentation
        )
    }

    func generatedCivicPresentation(
        adjacentRoads: RoadConnectionMask,
        detail: CameraDetailLevel
    ) -> GeneratedCivicPresentation? {
        guard let identity = CivicGeneratedAssetIdentity(adjacentRoads: adjacentRoads) else {
            recordFallback("civic L1 has no authoritative adjacent road")
            return nil
        }
        guard let asset = generatedAssetsByID[identity.logicalID],
              asset.family == "civic",
              asset.level == 1,
              asset.variant == 0,
              asset.frontageEdge == identity.direction,
              asset.viewDirection == identity.direction else {
            recordFallback("directional descriptor mismatch \(identity.logicalID)")
            return nil
        }
        guard let presentation = generatedPresentation(
            logicalID: identity.logicalID,
            detail: detail
        ) else {
            return nil
        }
        return GeneratedCivicPresentation(
            identity: identity,
            presentation: presentation
        )
    }

    func generatedSprite(
        logicalID: String,
        detail: CameraDetailLevel
    ) -> SKSpriteNode? {
        generatedPresentation(logicalID: logicalID, detail: detail)?.sprite
    }

    @discardableResult
    func applyGeneratedLOD(
        to sprite: SKSpriteNode,
        logicalID: String,
        detail: CameraDetailLevel,
        semanticName: String
    ) -> Bool {
        guard let presentation = generatedPresentation(logicalID: logicalID, detail: detail) else {
            return false
        }
        // LOD changes texture resolution, not the placed world's geometry.
        // Reapplying raw descriptor dimensions here discards the lot's
        // established presentation size and makes buildings jump on zoom.
        sprite.texture = presentation.sprite.texture
        sprite.name = semanticName
        return true
    }

    func generatedRoadSprite(
        connectionMask: UInt8,
        detail: CameraDetailLevel
    ) -> SKSpriteNode? {
        guard selectedPackID == Self.generatedPackID else { return nil }
        prepareGeneratedResidency(for: detail)
        guard connectionMask < 16,
              let descriptor = generatedManifest?.compiledNetwork.lods[detail.assetSuffix],
              descriptor.worldSize.count == 2,
              let placement = descriptor.textures[String(connectionMask)] else {
            recordFallback("incomplete road descriptor \(connectionMask).\(detail.assetSuffix)")
            return nil
        }
        guard let texture = packedTexture(
            pageID: placement.page,
            rectPixels: placement.textureRectPixels,
            cacheKey: "road:\(connectionMask)|\(detail.assetSuffix)",
            detail: detail
        ) else {
            recordFallback("missing packed road \(connectionMask).\(detail.assetSuffix)")
            return nil
        }
        let sprite = SKSpriteNode(
            texture: texture,
            color: .clear,
            size: CGSize(width: descriptor.worldSize[0], height: descriptor.worldSize[1])
        )
        sprite.name = "road.generated-v4.\(connectionMask).\(detail.assetSuffix)"
        sprite.zPosition = generatedAssetsByID["road_material"]?.depthRoles["network"] ?? 2
        return sprite
    }

    @discardableResult
    func applyGeneratedRoadLOD(
        to sprite: SKSpriteNode,
        connectionMask: UInt8,
        detail: CameraDetailLevel,
        semanticName: String
    ) -> Bool {
        guard let presentation = generatedRoadSprite(
            connectionMask: connectionMask,
            detail: detail
        ) else {
            return false
        }
        sprite.texture = presentation.texture
        sprite.size = presentation.size
        sprite.anchorPoint = presentation.anchorPoint
        sprite.position = presentation.position
        sprite.zPosition = presentation.zPosition
        sprite.name = semanticName
        return true
    }

    private func pageTexture(pageID: String) -> SKTexture? {
        if let cached = pageTextures[pageID] {
            cacheHits += 1
            return cached.texture
        }
        cacheMisses += 1
        guard let descriptor = generatedPagesByID[pageID],
              let detail = CameraDetailLevel(assetSuffix: descriptor.lod) else {
            recordFallback("unknown page \(pageID)")
            return nil
        }
        let relative = descriptor.file as NSString
        let stem = relative.deletingPathExtension as NSString
        let directory = stem.deletingLastPathComponent
        let basename = stem.lastPathComponent
        let subdirectory = directory.isEmpty
            ? "WorldAssets.atlas"
            : "WorldAssets.atlas/\(directory)"
        let started = ProcessInfo.processInfo.systemUptime
        defer {
            textureDecodeLoadCount += 1
            textureDecodeLoadDurationMilliseconds +=
                (ProcessInfo.processInfo.systemUptime - started) * 1_000
        }
        guard let url = resourceBundle.url(
            forResource: basename,
            withExtension: "png",
            subdirectory: subdirectory
        ), let data = try? Data(contentsOf: url) else {
            recordFallback("page \(pageID) missing from resource bundle")
            return nil
        }
        guard Self.sha256(data) == descriptor.sha256 else {
            recordFallback("page \(pageID) digest mismatch")
            return nil
        }
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(
                  imageSource,
                  0,
                  [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
              ) else {
            recordFallback("page \(pageID) decode failed")
            return nil
        }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        pageTextures[pageID] = PageRecord(
            texture: texture,
            decodedBytes: descriptor.decodedByteEstimate,
            detail: detail
        )
        residentGeneratedBytes += descriptor.decodedByteEstimate
        highWaterGeneratedBytes = max(highWaterGeneratedBytes, residentGeneratedBytes)
        return texture
    }

    private func packedTexture(
        pageID: String,
        rectPixels: [Int],
        cacheKey: String,
        detail: CameraDetailLevel
    ) -> SKTexture? {
        if let cached = generatedSubtextures[cacheKey] {
            cacheHits += 1
            return cached
        }
        guard rectPixels.count == 4,
              let descriptor = generatedPagesByID[pageID],
              descriptor.pixels.count == 2,
              descriptor.lod == detail.assetSuffix,
              let page = pageTexture(pageID: pageID) else {
            return nil
        }
        let pageWidth = CGFloat(descriptor.pixels[0])
        let pageHeight = CGFloat(descriptor.pixels[1])
        let rect = rectPixels.map(CGFloat.init)
        guard pageWidth > 0, pageHeight > 0, rect[2] > 0, rect[3] > 0,
              rect[0] >= 0, rect[1] >= 0,
              rect[0] + rect[2] <= pageWidth,
              rect[1] + rect[3] <= pageHeight else {
            return nil
        }
        let normalized = CGRect(
            x: rect[0] / pageWidth,
            y: (pageHeight - rect[1] - rect[3]) / pageHeight,
            width: rect[2] / pageWidth,
            height: rect[3] / pageHeight
        )
        let texture = SKTexture(rect: normalized, in: page)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        generatedSubtextures[cacheKey] = texture
        return texture
    }

    private func validate(
        rect: [Int],
        pageID: String,
        expectedDetail: CameraDetailLevel,
        pages: [String: GeneratedWorldAssetManifest.Page]
    ) -> String? {
        guard let page = pages[pageID], page.lod == expectedDetail.assetSuffix else {
            return "references an unknown or cross-LOD page"
        }
        guard rect.count == 4, page.pixels.count == 2,
              rect[0] >= 0, rect[1] >= 0, rect[2] > 0, rect[3] > 0,
              rect[0] + rect[2] <= page.pixels[0],
              rect[1] + rect[3] <= page.pixels[1] else {
            return "has an out-of-bounds texture rectangle"
        }
        return nil
    }

    private func adjacentDetail(to detail: CameraDetailLevel) -> CameraDetailLevel {
        switch detail {
        case .city: .neighborhood
        case .neighborhood: .block
        case .block: .neighborhood
        }
    }

    private func recordFallback(_ reason: String) {
        fallbackCount += 1
        if !fallbackDiagnostics.contains(reason),
           fallbackDiagnostics.count < Self.maximumFallbackDiagnostics {
            fallbackDiagnostics.append(reason)
        }
        Self.logger.error("generated-v4 fallback: \(reason, privacy: .public)")
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
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

    init?(assetSuffix: String) {
        switch assetSuffix {
        case "city": self = .city
        case "neighborhood": self = .neighborhood
        case "block": self = .block
        default: return nil
        }
    }
}
