import SwiftUI

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
        selectionApplies: Bool? = nil
    ) -> Self {
        let title = displayTitle(for: overlay)
        let scale = "0–100"
        let source = "Spatial consequences"
        let freshness = "fresh at tick " + String(tick)
        let clickThrough = "Click a place to open details"

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
                value: reading(consequence?.landValueIndex, selectionApplies: selectionApplies),
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
                value: reading(consequence?.trafficPressure, selectionApplies: selectionApplies),
                scale: scale,
                applicability: "Roads only",
                source: source,
                freshness: freshness,
                clickThrough: clickThrough,
                visualKey: "More road ticks signal heavier traffic"
            )
        case .utilities:
            return Self(
                title: title,
                value: reading(consequence?.utility.combined, selectionApplies: selectionApplies),
                scale: scale,
                applicability: "Developed places",
                source: source,
                freshness: freshness,
                clickThrough: clickThrough,
                visualKey: "More edge notches signal larger shortfall"
            )
        case .happiness:
            return Self(
                title: title,
                value: reading(consequence?.localHappinessIndex, selectionApplies: selectionApplies),
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
                value: reading(consequence?.pollutionExposure, selectionApplies: selectionApplies),
                scale: scale,
                applicability: "Developed places",
                source: source,
                freshness: freshness,
                clickThrough: clickThrough,
                visualKey: "More hatches signal higher pollution"
            )
        }
    }

    static func displayTitle(for overlay: DataOverlay) -> String {
        overlay == .traffic ? "Traffic pressure" : overlay.title
    }

    private static func normalized(_ value: Double?) -> String {
        guard let value else { return "No data" }
        return String(Int((min(1, max(0, value)) * 100).rounded())) + " / 100"
    }

    private static func reading(_ value: Double?, selectionApplies: Bool?) -> String {
        guard let selectionApplies else { return "Select a place" }
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

    private var selectedConsequence: CitySpatialConsequence? {
        guard let coordinate = store.selectedCoordinate,
              let snapshot = try? CityPresentationSnapshot(state: store.state) else {
            return nil
        }
        return snapshot.spatialConsequences[coordinate]
    }

    private var activePresentation: OverlayDiagnosticsPalettePresentation {
        makePresentation(for: store.overlay)
    }

    private func makePresentation(for overlay: DataOverlay) -> OverlayDiagnosticsPalettePresentation {
        let selectionApplies = store.selectedTile.map { overlay.applies(to: $0) }
        return .make(
            overlay: overlay,
            consequence: selectionApplies == false ? nil : selectedConsequence,
            tick: store.state.tick,
            selectionApplies: selectionApplies
        )
    }

    var body: some View {
        let presentation: OverlayDiagnosticsPalettePresentation = activePresentation
        if embedded {
            embeddedPalette(presentation: presentation)
        } else {
            standalonePalette(presentation: presentation)
        }
    }

    private func paletteMenu(
        presentation: OverlayDiagnosticsPalettePresentation,
        embedded: Bool
    ) -> some View {
        Menu {
            ForEach(DataOverlay.allCases) { overlay in
                let overlayPresentation = makePresentation(for: overlay)
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
        .accessibilityValue(activePresentation.accessibilityValue)
        .accessibilityHint("Open to choose City or a diagnostic layer. Select a place on the map for local details.")
        .accessibilityIdentifier("hud.diagnostics.palette")
    }

    private func standalonePalette(presentation: OverlayDiagnosticsPalettePresentation) -> some View {
        HStack(spacing: 8) {
            paletteMenu(presentation: presentation, embedded: false)
                .fixedSize(horizontal: true, vertical: false)
            Rectangle()
                .fill(GameTheme.panelStroke)
                .frame(width: 1, height: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(presentation.title + " · " + presentation.shortDetail)
                    .font(.system(size: GameTheme.hudSupportTextSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)
                Text(presentation.visualKey)
                    .font(.system(size: GameTheme.hudSupportTextSize - 1, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .layoutPriority(1)
            .accessibilityHidden(true)
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

    private func embeddedPalette(presentation: OverlayDiagnosticsPalettePresentation) -> some View {
        paletteMenu(presentation: presentation, embedded: true)
            .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
    }
}
