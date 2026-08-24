import SwiftUI

struct OverlayDiagnosticsPalettePresentation: Equatable {
    let title: String
    let value: String
    let scale: String
    let applicability: String
    let source: String
    let freshness: String
    let clickThrough: String

    var shortDetail: String {
        value + " · " + applicability
    }

    var accessibilityValue: String {
        value + ". Scale " + scale + ". " + applicability + ". Source " + source + ", " + freshness + ". " + clickThrough + "."
    }

    static func make(
        overlay: DataOverlay,
        consequence: CitySpatialConsequence?,
        tick: Int
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
                clickThrough: clickThrough
            )
        case .landValue:
            return Self(
                title: title,
                value: normalized(consequence?.landValueIndex),
                scale: scale,
                applicability: consequence?.landValueIndex == nil ? "No data · developed places" : "Developed places",
                source: source,
                freshness: freshness,
                clickThrough: clickThrough
            )
        case .traffic:
            return Self(
                title: title,
                value: normalized(consequence?.trafficPressure),
                scale: scale,
                applicability: consequence?.trafficPressure == nil ? "No data · roads only" : "Roads only",
                source: source,
                freshness: freshness,
                clickThrough: clickThrough
            )
        case .utilities:
            return Self(
                title: title,
                value: normalized(consequence?.utility.combined),
                scale: scale,
                applicability: "Developed places",
                source: source,
                freshness: freshness,
                clickThrough: clickThrough
            )
        case .happiness:
            return Self(
                title: title,
                value: normalized(consequence?.localHappinessIndex),
                scale: scale,
                applicability: consequence?.localHappinessIndex == nil ? "No data · occupied places" : "Occupied places",
                source: source,
                freshness: freshness,
                clickThrough: clickThrough
            )
        case .pollution:
            return Self(
                title: title,
                value: normalized(consequence?.pollutionExposure),
                scale: scale,
                applicability: "All places",
                source: source,
                freshness: freshness,
                clickThrough: clickThrough
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
        .make(
            overlay: store.overlay,
            consequence: selectedConsequence,
            tick: store.state.tick
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
                let overlayPresentation = OverlayDiagnosticsPalettePresentation.make(
                    overlay: overlay,
                    consequence: selectedConsequence,
                    tick: store.state.tick
                )
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
            HStack(spacing: 6) {
                Label(embedded ? "Layers" : "Map layers", systemImage: "square.grid.2x2.fill")
                    .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
                if !embedded {
                    Text(presentation.title + " · " + presentation.shortDetail)
                        .font(.system(size: GameTheme.hudSupportTextSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                }
            }
            .padding(.horizontal, embedded ? 4 : 8)
            .frame(
                minWidth: GameTheme.controlMinimum,
                maxWidth: embedded ? nil : .infinity,
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
        paletteMenu(presentation: presentation, embedded: false)
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
