import Foundation

/// Renderer-local, deterministic art identity derived only from authoritative
/// building kind, level, and coordinate. It carries no prosperity, service,
/// pollution, occupancy, or event meaning.
struct StrategyDistrictVisualIdentity: Equatable, Sendable {
    enum Family: String, Sendable {
        case commercial
        case industrial
    }

    let family: Family
    let densityTier: Int
    let variant: Int

    init?(tile: CityTile) {
        switch tile.kind {
        case .commercial: family = .commercial
        case .industrial: family = .industrial
        default: return nil
        }
        densityTier = min(3, max(1, tile.level))
        variant = WorldVisualSeed.variant(count: 3, for: tile.coordinate, kind: tile.kind)
    }

    var placeAssetName: String {
        "place_\(family.rawValue)_tier_\(densityTier)_\(variant)"
    }

    var groundAssetName: String {
        "strategy_ground_\(family.rawValue)_tier_\(densityTier)"
    }

    var architecturalCue: String {
        switch (family, densityTier) {
        case (.commercial, 1): "main-street shop row"
        case (.commercial, 2): "courtyard mixed block"
        case (.commercial, 3): "stepped tower district"
        case (.industrial, 1): "fabrication sheds and service yard"
        case (.industrial, 2): "warehouse and logistics silos"
        case (.industrial, 3): "process campus and pipe gantries"
        default: "district architecture"
        }
    }
}
