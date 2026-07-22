import SwiftUI

struct BuildToolbarView: View {
    @ObservedObject var store: CityGameStore
    var compact = false

    // The command row, padding, and this capped scroll region keep more than 40%
    // of a 900 x 600 window available to the interactive map.
    static let compactDetailsMaxHeight: CGFloat = 72

    var body: some View {
        VStack(spacing: compact ? 7 : 9) {
            commandRow
            if store.showInspector {
                if compact {
                    compactInspector
                } else {
                    InspectorView(store: store, compact: false)
                        .transition(.opacity)
                }
            } else {
                operationalRow
                cityPulseStrip
            }
        }
        .padding(compact ? 9 : 11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: GameTheme.panelRadius).stroke(GameTheme.strongPanelStroke))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.showInspector ? "City command deck with details open" : "City command deck")
    }

    private var compactInspector: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Scrollable command-center details", systemImage: "arrow.up.and.down.text.horizontal")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHint("Use the scroll area to reach every diagnostic control")
            ScrollView(.vertical) {
                InspectorView(store: store, compact: true)
                    .padding(.trailing, 6)
            }
            .scrollIndicators(.visible)
            .frame(maxHeight: Self.compactDetailsMaxHeight, alignment: .top)
            .focusable()
            .accessibilityLabel("Scrollable command-center details")
            .accessibilityIdentifier("hud.command.details.scroll")
        }
        .transition(.opacity)
    }

    private var commandRow: some View {
        HStack(spacing: 6) {
            modeButton(
                title: "Inspect",
                symbol: "cursorarrow.rays",
                active: store.interactionMode == .inspect,
                tint: GameTheme.information,
                action: { store.perform(.inspectMode) }
            )
            modeButton(
                title: "Build",
                symbol: "hammer.fill",
                active: isBuildMode,
                tint: GameTheme.accent,
                action: { store.perform(.buildMode) }
            )
            modeButton(
                title: "Bulldoze",
                symbol: "trash.fill",
                active: store.interactionMode == .bulldoze,
                tint: GameTheme.danger,
                action: { store.perform(.bulldozeMode) }
            )

            Divider().frame(height: 30)

            if compact {
                buildCatalogMenu
            } else {
                ForEach(BuildCategory.allCases) { category in
                    categoryButton(category)
                }
            }

            Spacer(minLength: 6)
            commandGuideButton
            detailsButton
            OverlayPickerView(store: store, compact: compact)
        }
    }

    @ViewBuilder
    private var operationalRow: some View {
        if compact {
            compactSelectionRow
        } else {
            switch store.interactionMode {
            case .inspect:
                inspectReadoutRow
            case .build:
                catalogRow
            case .bulldoze:
                bulldozeReadoutRow
            }
        }
    }

    private var catalogRow: some View {
        HStack(spacing: 7) {
            Label(store.selectedBuildCategory.title.uppercased(), systemImage: store.selectedBuildCategory.symbol)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(minWidth: 76, alignment: .leading)

            ForEach(store.selectedBuildCategory.buildingKinds) { kind in
                toolButton(kind)
            }

            Spacer(minLength: 10)
            selectedToolSummary
        }
    }

    private var compactSelectionRow: some View {
        HStack(spacing: 8) {
            Label(compactModeTitle, systemImage: store.interactionMode.symbol)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 6)
            selectedToolSummary
        }
        .frame(minHeight: 30)
    }

    private var inspectReadoutRow: some View {
        HStack(spacing: 10) {
            Label("CITY DESK", systemImage: "cursorarrow.rays")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(GameTheme.information)
            Divider().frame(height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.primaryObjective.title).font(.caption.weight(.semibold)).lineLimit(1)
                Text(store.primaryObjective.remaining).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            ProgressView(value: store.primaryObjective.progress)
                .tint(.cyan)
                .frame(width: 82)
            Divider().frame(height: 26)
            Label("\(store.alertCount) notices", systemImage: "bell.fill")
                .font(.caption.monospacedDigit())
            Spacer(minLength: 8)
            Label("Select a block or a status signal for context", systemImage: "arrow.down.left.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(minHeight: GameTheme.controlMinimum)
    }

    private var bulldozeReadoutRow: some View {
        HStack(spacing: 10) {
            Label("BULLDOZE MODE", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(GameTheme.danger)
            Divider().frame(height: 26)
            Text("Point at a structure to see demolition cost and protection state on the map.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if store.canUndo {
                Button { store.perform(.undo) } label: {
                    Label("Undo last action", systemImage: "arrow.uturn.backward")
                        .frame(minHeight: GameTheme.controlMinimum)
                }
                .buttonStyle(.bordered)
            }
            Text("Esc cancels")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: GameTheme.controlMinimum)
    }

    private var detailsButton: some View {
        Button { store.perform(.toggleCommandCenter) } label: {
            Label("Details", systemImage: "rectangle.bottomthird.inset.filled")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(store.showInspector ? Color.black : Color.primary)
        .background(store.showInspector ? GameTheme.accent : GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
        .help(store.showInspector ? "Close command-center details" : "Open command-center details")
        .accessibilityLabel(store.showInspector ? "Close command-center details" : "Open command-center details")
        .accessibilityValue(store.showInspector ? "Open" : "Closed")
        .accessibilityIdentifier("hud.command.details")
    }

    private var commandGuideButton: some View {
        let descriptor = CityCommandCatalog.descriptor(for: .openCommandGuide)
        return Button { store.perform(.openCommandGuide) } label: {
            Label(compact ? "Cmds" : "Commands", systemImage: "command.square")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, compact ? 0 : 8)
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
        .help("\(descriptor.discoverability) \(descriptor.shortcut?.display ?? "")")
        .accessibilityLabel("Open command guide")
        .accessibilityValue(descriptor.shortcut?.display ?? "No shortcut")
        .accessibilityIdentifier("hud.command.guide")
    }

    @ViewBuilder
    private var selectedToolSummary: some View {
        Group {
            switch store.interactionMode {
            case .inspect:
                Label("Choose a block for details", systemImage: "info.circle")
                    .accessibilityLabel("Inspect mode. Choose a block for details")
            case .bulldoze:
                Label("Cost shown on map · Undo available", systemImage: "arrow.uturn.backward.circle")
                    .accessibilityLabel("Bulldoze mode. Demolition cost is shown on the map. Undo is available")
            case .build(let kind):
                HStack(spacing: 9) {
                    Label(kind.buildCost.currencyText, systemImage: "banknote")
                    Label("\(kind.upkeep.currencyText) / cycle", systemImage: "arrow.triangle.2.circlepath")
                    if kind.requiresRoad {
                        Label("Road required", systemImage: "road.lanes")
                    } else {
                        Label("Flexible access", systemImage: "checkmark.circle")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Selected \(kind.title)")
                .accessibilityValue(
                    "Cost \(kind.buildCost.currencyText), upkeep \(kind.upkeep.currencyText) per cycle, "
                        + (kind.requiresRoad ? "road required" : "no road required")
                )
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private var buildCatalogMenu: some View {
        Menu {
            ForEach(BuildCategory.allCases) { category in
                Section(category.title) {
                    ForEach(category.buildingKinds) { kind in
                        Button { store.perform(CityCommandCatalog.id(for: kind)) } label: {
                            Label(
                                "\(kind.title) · \(kind.buildCost.currencyText) · \(kind.upkeep.currencyText)/cycle",
                                systemImage: kind.symbol
                            )
                        }
                    }
                }
            }
        } label: {
            Label("Catalog", systemImage: "square.grid.2x2")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .frame(minHeight: GameTheme.controlMinimum)
        }
        .menuStyle(.borderlessButton)
        .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
        .accessibilityLabel("Open categorized build catalog")
        .accessibilityValue("Selected \(store.selectedTool.title)")
    }

    private func modeButton(
        title: String,
        symbol: String,
        active: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: active ? "checkmark.circle.fill" : symbol)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, compact ? 7 : 10)
            .frame(minHeight: GameTheme.controlMinimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? Color.black : Color.primary)
        .background(active ? tint : GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
        .accessibilityLabel("\(title) mode")
        .accessibilityValue(active ? "Selected" : "Not selected")
    }

    private func categoryButton(_ category: BuildCategory) -> some View {
        let active = store.selectedBuildCategory == category
        return Button { store.perform(CityCommandCatalog.id(for: category)) } label: {
            Label(category.title, systemImage: category.symbol)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .frame(minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? GameTheme.accent : .primary)
        .background(active ? GameTheme.accent.opacity(0.15) : GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            if active {
                RoundedRectangle(cornerRadius: 9).stroke(GameTheme.accent.opacity(0.8), lineWidth: 1.5)
            }
        }
        .accessibilityLabel("\(category.title) build category")
        .accessibilityValue(active ? "Selected" : "Not selected")
    }

    private func toolButton(_ kind: BuildingKind) -> some View {
        let active = store.interactionMode == .build(kind)
        return Button { store.perform(CityCommandCatalog.id(for: kind)) } label: {
            HStack(spacing: 7) {
                Image(systemName: active ? "checkmark.circle.fill" : kind.symbol)
                    .font(.system(size: 15, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.title).font(.caption.weight(.semibold)).lineLimit(1)
                    Text(kind.buildCost.currencyText).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 9)
            .frame(minWidth: 92, minHeight: GameTheme.controlMinimum, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? Color.black : Color.primary)
        .background(active ? GameTheme.accent : GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
        .help("Build \(kind.title) · \(kind.buildCost.currencyText) · \(kind.upkeep.currencyText) per cycle")
        .accessibilityLabel("Build \(kind.title)")
        .accessibilityValue("Cost \(kind.buildCost.currencyText), upkeep \(kind.upkeep.currencyText) per cycle")
    }

    private var cityPulseStrip: some View {
        ViewThatFits(in: .horizontal) {
            fullCityPulseStrip
            compactCityPulseStrip
        }
    }

    private var fullCityPulseStrip: some View {
        HStack(spacing: 6) {
            Label("CITY PULSE", systemImage: "waveform.path.ecg")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(GameTheme.accent)
            pulseButton("Cashflow", value: store.analytics.projectedBalance.signedCurrencyText, symbol: "dollarsign.arrow.circlepath", tint: store.analytics.projectedBalance >= 0 ? GameTheme.accent : GameTheme.danger) {
                store.perform(.inspectorFinances)
            }
            pulseButton("Homes open", value: store.analytics.housingHeadroom.formatted(), symbol: "house.fill", tint: .cyan) {
                store.perform(.inspectorPopulation)
            }
            pulseButton("Jobs open", value: store.analytics.jobHeadroom.formatted(), symbol: "briefcase.fill", tint: .purple) {
                store.perform(.inspectorEmployment)
            }
            pulseButton("Power spare", value: store.analytics.powerHeadroom.formatted(), symbol: "bolt.fill", tint: .yellow) {
                store.perform(.inspectorUtilities)
            }
            pulseButton("Water spare", value: store.analytics.waterHeadroom.formatted(), symbol: "drop.fill", tint: .blue) {
                store.perform(.inspectorUtilities)
            }
            Divider().frame(height: 28)
            DemandBar(label: "R", accessibilityName: "Residential", value: store.state.demand.residential, color: .cyan) {
                store.perform(.inspectorDemand)
            }
            DemandBar(label: "C", accessibilityName: "Commercial", value: store.state.demand.commercial, color: .purple) {
                store.perform(.inspectorDemand)
            }
            DemandBar(label: "I", accessibilityName: "Industrial", value: store.state.demand.industrial, color: .orange) {
                store.perform(.inspectorDemand)
            }
            Spacer(minLength: 4)
            if store.canUndo {
                Button { store.perform(.undo) } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: GameTheme.controlMinimum)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Undo last construction action")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactCityPulseStrip: some View {
        HStack(spacing: 5) {
            pulseButton("Net", value: store.analytics.projectedBalance.signedCurrencyText, symbol: "dollarsign.arrow.circlepath", tint: store.analytics.projectedBalance >= 0 ? GameTheme.accent : GameTheme.danger) {
                store.perform(.inspectorFinances)
            }
            pulseButton("Homes", value: store.analytics.housingHeadroom.formatted(), symbol: "house.fill", tint: .cyan) {
                store.perform(.inspectorPopulation)
            }
            pulseButton("Power", value: store.analytics.powerHeadroom.formatted(), symbol: "bolt.fill", tint: .yellow) {
                store.perform(.inspectorUtilities)
            }
            pulseButton("Water", value: store.analytics.waterHeadroom.formatted(), symbol: "drop.fill", tint: .blue) {
                store.perform(.inspectorUtilities)
            }
            Button { store.perform(.inspectorDemand) } label: {
                Label("Demand", systemImage: "chart.bar.fill")
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: GameTheme.controlMinimum)
            }
            .buttonStyle(.bordered)
            if store.canUndo {
                Button { store.perform(.undo) } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Undo last construction action")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pulseButton(
        _ title: String,
        value: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title.uppercased())
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .frame(minWidth: compact ? 70 : 84, maxWidth: .infinity, minHeight: GameTheme.controlMinimum, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(GameTheme.contextCard, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private var isBuildMode: Bool {
        if case .build = store.interactionMode { return true }
        return false
    }

    private var compactModeTitle: String {
        switch store.interactionMode {
        case .inspect: "Inspect mode"
        case .build(let kind): "Build: \(kind.title)"
        case .bulldoze: "Bulldoze mode"
        }
    }

}

private struct DemandBar: View {
    let label: String
    let accessibilityName: String
    let value: Double
    let color: Color
    let action: () -> Void

    private var status: String {
        if value >= 0.67 { return "High" }
        if value >= 0.34 { return "Steady" }
        return "Low"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label).font(.caption2.weight(.semibold))
                ProgressView(value: value)
                    .tint(color)
                    .frame(width: 48)
                Text("\((value * 100).percentText) \(status)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: GameTheme.controlMinimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open demand details")
        .accessibilityLabel("\(accessibilityName) demand")
        .accessibilityValue("\((value * 100).percentText), \(status)")
    }
}
