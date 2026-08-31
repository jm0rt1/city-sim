import SwiftUI

struct OverlayDiagnosticHotspot: Equatable, Sendable {
    let overlay: DataOverlay
    let coordinate: GridCoordinate
    let value: Double

    var conciseReading: String {
        let prefix: String
        switch overlay {
        case .traffic, .pollution:
            prefix = "Peak"
        case .landValue, .utilities, .services, .fireCoverage, .policeCoverage, .schoolCoverage, .happiness, .roadCondition:
            prefix = "Lowest"
        case .none:
            prefix = "City"
        }
        return "\(prefix) \(normalizedValue) · B\(coordinate.x + 1),\(coordinate.y + 1)"
    }

    var accessibilityLabel: String {
        let subject: String
        switch overlay {
        case .none:
            subject = "city"
        case .landValue:
            subject = "lowest land value"
        case .traffic:
            subject = "highest traffic delay road"
        case .utilities:
            subject = "weakest utility service"
        case .services:
            subject = "weakest civic service coverage"
        case .fireCoverage:
            subject = "weakest fire coverage"
        case .policeCoverage:
            subject = "weakest police coverage"
        case .schoolCoverage:
            subject = "weakest school coverage"
        case .happiness:
            subject = "lowest local happiness"
        case .pollution:
            subject = "highest pollution"
        case .roadCondition:
            subject = "lowest road condition"
        }
        return "Focus \(subject) at Block \(coordinate.x + 1), \(coordinate.y + 1)"
    }

    static func make(
        overlay: DataOverlay,
        snapshot: CityPresentationSnapshot
    ) -> Self? {
        guard overlay != .none else { return nil }

        let candidates = snapshot.spatialConsequences.samples.compactMap { consequence -> Self? in
            guard let tile = snapshot.state.tile(at: consequence.coordinate),
                  overlay.applies(to: tile),
                  let value = metric(for: overlay, tile: tile, consequence: consequence) else {
                return nil
            }
            return Self(overlay: overlay, coordinate: consequence.coordinate, value: value)
        }
        guard let first = candidates.first else { return nil }

        return candidates.dropFirst().reduce(first) { current, candidate in
            switch overlay {
            case .traffic, .pollution:
                candidate.value > current.value ? candidate : current
            case .landValue, .utilities, .services, .fireCoverage, .policeCoverage, .schoolCoverage, .happiness, .roadCondition:
                candidate.value < current.value ? candidate : current
            case .none:
                current
            }
        }
    }

    private var normalizedValue: Int {
        Int((min(1, max(0, value)) * 100).rounded())
    }

    private static func metric(
        for overlay: DataOverlay,
        tile: CityTile,
        consequence: CitySpatialConsequence
    ) -> Double? {
        switch overlay {
        case .none:
            nil
        case .landValue:
            consequence.landValueIndex
        case .traffic:
            consequence.trafficPressure
        case .utilities:
            consequence.utility.combined
        case .services, .fireCoverage, .policeCoverage, .schoolCoverage:
            overlay.civicServiceValue(in: consequence.civicService)
        case .happiness:
            consequence.localHappinessIndex
        case .pollution:
            consequence.pollutionExposure
        case .roadCondition:
            CityRoadMaintenance.clamp(tile.condition)
        }
    }
}

struct OverlayDiagnosticsPalettePresentation: Equatable {
    let title: String
    let value: String
    let scale: String
    let applicability: String
    let source: String
    let freshness: String
    let clickThrough: String
    let visualKey: String

    var shortDetail: String {
        value + " · " + applicability
    }

    var accessibilityValue: String {
        value + ". Scale " + scale + ". " + applicability + ". " + visualKey + ". Source " + source + ", " + freshness + ". " + clickThrough + "."
    }

    static func make(
        overlay: DataOverlay,
        consequence: CitySpatialConsequence?,
        tick: Int,
        selectionApplies: Bool? = nil,
        selectedRoadCondition: Double? = nil,
        civicServiceFundingPolicy: CityCivicServiceFundingPolicy = .standard,
        hotspot: OverlayDiagnosticHotspot? = nil
    ) -> Self {
        let title = displayTitle(for: overlay)
        let scale = "0–100"
        let source = "Spatial consequences"
        let freshness = "fresh at tick " + String(tick)
        let clickThrough = hotspot == nil
            ? "Click a place to open details"
            : "Activate the citywide hotspot to focus it on the map"

        switch overlay {
        case .none:
            return Self(
                title: title,
                value: "City overview",
                scale: "Full map",
                applicability: "All places",
                source: "Live city state",
                freshness: freshness,
                clickThrough: clickThrough,
                visualKey: "No diagnostic marks"
            )
        case .landValue:
            return Self(
                title: title,
                value: reading(
                    consequence?.landValueIndex,
                    selectionApplies: selectionApplies,
                    hotspot: hotspot
                ),
                scale: scale,
                applicability: "Completed places",
                source: source,
                freshness: freshness,
                clickThrough: clickThrough,
                visualKey: "More contours signal weaker land value"
            )
        case .traffic:
            return Self(
                title: title,
                value: reading(
                    consequence?.trafficPressure,
                    selectionApplies: selectionApplies,
                    hotspot: hotspot
                ),
                scale: scale,
                applicability: "Roads only",
                source: "Home-to-work route assignment",
                freshness: freshness,
                clickThrough: clickThrough,
                visualKey: "More road ticks signal higher modeled delay"
            )
        case .utilities:
            return Self(
                title: title,
                value: reading(
                    consequence?.utility.combined,
                    selectionApplies: selectionApplies,
                    hotspot: hotspot
                ),
                scale: scale,
                applicability: "Developed places",
                source: source,
                freshness: freshness,
                clickThrough: clickThrough,
                visualKey: "More edge notches signal larger shortfall"
            )
        case .services, .fireCoverage, .policeCoverage, .schoolCoverage:
            let serviceSource = overlay.civicServiceKind.map { "completed \($0.title.lowercased()) sites" }
                ?? "completed civic sites"
            let serviceSignal = overlay.civicServiceKind.map { _ in overlay.title.lowercased() + " " } ?? ""
            return Self(
                title: title,
                value: reading(
                    overlay.civicServiceValue(in: consequence?.civicService),
                    selectionApplies: selectionApplies,
                    hotspot: hotspot
                ),
                scale: scale,
                applicability: "Completed places",
                source: "\(civicServiceFundingPolicy.title) funding · "
                    + "\(serviceSource) over connected streets · "
                    + "\(civicServiceFundingPolicy.maximumRoadDistance)-block reach",
                freshness: freshness,
                clickThrough: clickThrough,
                visualKey: "More signals mean larger \(serviceSignal)gaps · "
                    + "\(civicServiceFundingPolicy.title) · "
                    + "\(civicServiceFundingPolicy.maximumRoadDistance) blocks"
            )
        case .happiness:
            return Self(
                title: title,
                value: reading(
                    consequence?.localHappinessIndex,
                    selectionApplies: selectionApplies,
                    hotspot: hotspot
                ),
                scale: scale,
                applicability: "Completed places",
                source: source,
                freshness: freshness,
                clickThrough: clickThrough,
                visualKey: "More ripples signal lower happiness"
            )
        case .pollution:
            return Self(
                title: title,
                value: reading(
                    consequence?.pollutionExposure,
                    selectionApplies: selectionApplies,
                    hotspot: hotspot
                ),
                scale: scale,
                applicability: "Developed places",
                source: source,
                freshness: freshness,
                clickThrough: clickThrough,
                visualKey: "More hatches signal higher pollution"
            )
        case .roadCondition:
            return Self(
                title: title,
                value: reading(
                    selectedRoadCondition.map(CityRoadMaintenance.clamp),
                    selectionApplies: selectionApplies,
                    hotspot: hotspot
                ),
                scale: scale,
                applicability: "Roads only",
                source: "Saved road condition",
                freshness: freshness,
                clickThrough: clickThrough,
                visualKey: "More shoulder bars signal worse road condition"
            )
        }
    }

    static func displayTitle(for overlay: DataOverlay) -> String {
        switch overlay {
        case .traffic: "Traffic pressure"
        case .services: "Civic service coverage"
        default: overlay.title
        }
    }

    private static func normalized(_ value: Double?) -> String {
        guard let value else { return "No data" }
        return String(Int((min(1, max(0, value)) * 100).rounded())) + " / 100"
    }

    private static func reading(
        _ value: Double?,
        selectionApplies: Bool?,
        hotspot: OverlayDiagnosticHotspot?
    ) -> String {
        guard let selectionApplies else { return hotspot?.conciseReading ?? "Select a place" }
        guard selectionApplies else { return "Not applicable here" }
        return normalized(value)
    }
}

struct OverlayDiagnosticsPaletteView: View {
    @ObservedObject var store: CityGameStore
    var compact = false
    var embedded = false

    static let compactMaximumHeight: CGFloat = 48
    static let regularMaximumHeight: CGFloat = 48

    private func makeHotspot(
        for overlay: DataOverlay,
        snapshot: CityPresentationSnapshot?
    ) -> OverlayDiagnosticHotspot? {
        guard store.selectedCoordinate == nil, let snapshot else {
            return nil
        }
        return .make(overlay: overlay, snapshot: snapshot)
    }

    private func makePresentation(
        for overlay: DataOverlay,
        snapshot: CityPresentationSnapshot?
    ) -> OverlayDiagnosticsPalettePresentation {
        let selectionApplies = store.selectedTile.map { overlay.applies(to: $0) }
        let selectedRoadCondition = store.selectedTile.flatMap {
            $0.kind == .road ? $0.condition : nil
        }
        let consequence = store.selectedCoordinate.flatMap { snapshot?.spatialConsequences[$0] }
        let hotspot = makeHotspot(for: overlay, snapshot: snapshot)
        return .make(
            overlay: overlay,
            consequence: selectionApplies == false ? nil : consequence,
            tick: store.state.tick,
            selectionApplies: selectionApplies,
            selectedRoadCondition: selectedRoadCondition,
            civicServiceFundingPolicy: store.state.effectiveCivicServiceFundingPolicy,
            hotspot: hotspot
        )
    }

    var body: some View {
        let snapshot = try? CityPresentationSnapshot(state: store.state)
        let hotspot = makeHotspot(for: store.overlay, snapshot: snapshot)
        let presentation = makePresentation(for: store.overlay, snapshot: snapshot)
        if embedded {
            embeddedPalette(presentation: presentation, snapshot: snapshot)
        } else {
            standalonePalette(
                presentation: presentation,
                hotspot: hotspot,
                snapshot: snapshot
            )
        }
    }

    private func paletteMenu(
        presentation: OverlayDiagnosticsPalettePresentation,
        embedded: Bool,
        snapshot: CityPresentationSnapshot?
    ) -> some View {
        Menu {
            ForEach(DataOverlay.allCases) { overlay in
                let overlayPresentation = makePresentation(for: overlay, snapshot: snapshot)
                Button {
                    store.perform(CityCommandCatalog.id(for: overlay))
                } label: {
                    Label(overlayPresentation.title, systemImage: overlay.symbol)
                }
                .accessibilityLabel(overlayPresentation.title + " layer")
                .accessibilityValue(
                    store.overlay == overlay
                        ? "Active. " + overlayPresentation.accessibilityValue
                        : overlayPresentation.accessibilityValue
                )
                .accessibilityHint("Switches the map to this layer")
            }
        } label: {
            Label(embedded ? "Layers" : "Map layers", systemImage: "square.grid.2x2.fill")
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
            .padding(.horizontal, embedded ? 4 : 8)
            .frame(
                minWidth: GameTheme.controlMinimum,
                minHeight: GameTheme.controlMinimum,
                alignment: .leading
            )
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Map layers")
        .accessibilityValue(presentation.accessibilityValue)
        .accessibilityHint("Open to choose City or a diagnostic layer. Select a place on the map for local details.")
        .accessibilityIdentifier("hud.diagnostics.palette")
    }

    private func standalonePalette(
        presentation: OverlayDiagnosticsPalettePresentation,
        hotspot: OverlayDiagnosticHotspot?,
        snapshot: CityPresentationSnapshot?
    ) -> some View {
        HStack(spacing: 8) {
            paletteMenu(presentation: presentation, embedded: false, snapshot: snapshot)
                .fixedSize(horizontal: true, vertical: false)
            Rectangle()
                .fill(GameTheme.panelStroke)
                .frame(width: 1, height: 26)
                .accessibilityHidden(true)
            if let hotspot {
                Button {
                    store.focusDiagnosticHotspot(hotspot.coordinate)
                } label: {
                    paletteSummary(presentation: presentation, showsFocusAffordance: true)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel(hotspot.accessibilityLabel)
                .accessibilityValue(presentation.value + ". " + presentation.visualKey)
                .accessibilityHint("Selects this map location in Inspect mode without changing the city")
                .accessibilityIdentifier("hud.diagnostics.hotspot")
            } else {
                paletteSummary(presentation: presentation, showsFocusAffordance: false)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum, alignment: .leading)
        .cityPanelBackground(.thin, in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous))
        .background(
            GameTheme.hudSurfaceFill,
            in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: GameTheme.panelRadius).stroke(GameTheme.strongPanelStroke))
    }

    private func paletteSummary(
        presentation: OverlayDiagnosticsPalettePresentation,
        showsFocusAffordance: Bool
    ) -> some View {
        let primaryLine = presentation.title + " · " + (
            showsFocusAffordance ? presentation.value : presentation.shortDetail
        )
        return HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(primaryLine)
                    .font(.system(size: GameTheme.hudSupportTextSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(presentation.visualKey)
                    .font(.system(size: GameTheme.hudSupportTextSize - 1, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            if showsFocusAffordance {
                Image(systemName: "scope")
                    .font(.system(size: GameTheme.hudSupportTextSize, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .truncationMode(.tail)
        .layoutPriority(1)
        .accessibilityHidden(true)
    }

    private func embeddedPalette(
        presentation: OverlayDiagnosticsPalettePresentation,
        snapshot: CityPresentationSnapshot?
    ) -> some View {
        paletteMenu(presentation: presentation, embedded: true, snapshot: snapshot)
            .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
    }
}
