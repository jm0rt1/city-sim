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

    static let compactMaximumHeight: CGFloat = 48
    static let regularMaximumHeight: CGFloat = 74

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
        let titleAndDetail: String = presentation.title + " · " + presentation.shortDetail
        let sourceAndFreshness: String = presentation.source + " · " + presentation.freshness
        let activeSummary: String = titleAndDetail + " · " + sourceAndFreshness

        if compact {
            compactPalette(presentation: presentation)
        } else {
            expandedPalette(
                presentation: presentation,
                activeSummary: activeSummary
            )
        }
    }

    private func compactPalette(presentation: OverlayDiagnosticsPalettePresentation) -> some View {
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
                Label("Map layers", systemImage: "square.grid.2x2.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text(presentation.title + " · " + presentation.shortDetail)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous))
        .background(
            GameTheme.hudSurfaceFill,
            in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: GameTheme.panelRadius).stroke(GameTheme.strongPanelStroke))
        .accessibilityLabel("Map layers")
        .accessibilityValue(activePresentation.accessibilityValue)
        .accessibilityHint("Open to choose City or a diagnostic layer. Select a place on the map for local details.")
        .accessibilityIdentifier("hud.diagnostics.palette")
    }

    private func expandedPalette(
        presentation: OverlayDiagnosticsPalettePresentation,
        activeSummary: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Label("MAP DIAGNOSTICS", systemImage: "square.grid.2x2.fill")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Text(activeSummary)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                Text("Click a place for details")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(DataOverlay.allCases) { overlay in
                        overlayButton(overlay)
                    }
                }
            }
            .scrollClipDisabled()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.regularMaximumHeight)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous))
        .background(
            GameTheme.hudSurfaceFill,
            in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: GameTheme.panelRadius).stroke(GameTheme.strongPanelStroke))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("City diagnostics palette")
        .accessibilityValue(activePresentation.accessibilityValue)
        .accessibilityHint("Choose City or a diagnostic layer. Select a place on the map for local details.")
        .accessibilityIdentifier("hud.diagnostics.palette")
    }

    private func overlayButton(_ overlay: DataOverlay) -> some View {
        let presentation = OverlayDiagnosticsPalettePresentation.make(
            overlay: overlay,
            consequence: selectedConsequence,
            tick: store.state.tick
        )
        let isActive = store.overlay == overlay

        return Button {
            store.perform(CityCommandCatalog.id(for: overlay))
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Label(presentation.title, systemImage: overlay.symbol)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(presentation.shortDetail)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: compact ? 100 : 112, alignment: .leading)
            .frame(minHeight: GameTheme.controlMinimum, alignment: .center)
            .padding(.horizontal, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? GameTheme.accent : .primary)
        .background(
            isActive ? GameTheme.accent.opacity(0.18) : GameTheme.inactiveControl,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isActive ? GameTheme.accent : GameTheme.panelStroke)
        )
        .help(presentation.title + " layer. " + presentation.accessibilityValue)
        .accessibilityLabel(presentation.title + " layer")
        .accessibilityValue(isActive ? "Active. " + presentation.accessibilityValue : presentation.accessibilityValue)
        .accessibilityHint("Switches the map to this layer")
        .accessibilityIdentifier("hud.diagnostics." + overlay.rawValue)
    }
}
