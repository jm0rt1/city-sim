import SwiftUI

struct InspectorView: View {
    @ObservedObject var store: CityGameStore
    var compact = false

    static let compactColumnCount = 2
    static let regularColumnCount = 4
    static let compactMinimumVisibleNoticeCount = 2

    private var analytics: CityAnalytics { store.analytics }
    private var contextColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 8, alignment: .top),
            count: compact ? Self.compactColumnCount : Self.regularColumnCount
        )
    }

    var body: some View {
        Group {
            if compact {
                HStack(alignment: .top, spacing: 8) {
                    contextHeader
                        .frame(width: 260, alignment: .topLeading)
                    Divider().overlay(GameTheme.subtleDivider)
                    contextBody
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    contextHeader
                    Divider().overlay(GameTheme.subtleDivider)
                    contextBody
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(contextAccessibilityLabel)
    }

    @ViewBuilder
    private var contextBody: some View {
        if store.hudContextScope == .selection, let tile = store.selectedTile {
            tileContext(tile)
        } else {
            cityContext
        }
    }

    private var contextHeader: some View {
        HStack(spacing: 8) {
            if store.hudContextScope == .selection, let tile = store.selectedTile {
                Label(tile.kind.title, systemImage: tile.kind.symbol)
                    .font(.callout.weight(.bold))
                    .lineLimit(1)
                Text("Block \(tile.coordinate.x + 1), \(tile.coordinate.y + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !compact {
                    Button("City data") { store.perform(.inspectorOverview) }
                        .buttonStyle(.borderless)
                        .frame(minHeight: GameTheme.controlMinimum)
                        .accessibilityLabel("Show citywide data and keep block selected")
                }
            } else {
                Label(store.inspectorSection.deckTitle, systemImage: store.inspectorSection.symbol)
                    .font(.callout.weight(.bold))
                    .lineLimit(1)
                if store.selectedTile != nil {
                    Button("Selected block") { store.showSelectionContext() }
                        .buttonStyle(.borderless)
                        .frame(minHeight: GameTheme.controlMinimum)
                        .accessibilityLabel("Return to selected block details")
                }
            }

            Spacer(minLength: 4)
            sectionNavigation

            Button { store.perform(.toggleCommandCenter) } label: {
                Label(compact ? "" : "Close", systemImage: "xmark")
                    .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close command-center details")
            .accessibilityLabel("Close command-center details")
            .accessibilityIdentifier("hud.context.close")
        }
        .frame(minHeight: GameTheme.controlMinimum)
    }

    @ViewBuilder
    private var sectionNavigation: some View {
        if compact {
            Menu {
                ForEach(InspectorSection.allCases) { section in
                    Button { store.perform(CityCommandCatalog.id(for: section)) } label: {
                        Label(section.deckTitle, systemImage: section.symbol)
                    }
                }
            } label: {
                Label("City data", systemImage: "chart.dots.scatter")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .frame(minHeight: GameTheme.controlMinimum)
            }
            .menuStyle(.borderlessButton)
            .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
            .accessibilityLabel("Choose city data")
            .accessibilityValue(store.inspectorSection.deckTitle)
        } else {
            HStack(spacing: 4) {
                ForEach(InspectorSection.allCases) { section in
                    sectionButton(section)
                }
            }
        }
    }

    private func sectionButton(_ section: InspectorSection) -> some View {
        let active = store.hudContextScope == .city && store.inspectorSection == section
        return Button { store.perform(CityCommandCatalog.id(for: section)) } label: {
            Image(systemName: section.symbol)
                .frame(width: GameTheme.controlMinimum, height: GameTheme.controlMinimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? Color.black : Color.primary)
        .background(active ? GameTheme.accent : GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 8))
        .help(section.deckTitle)
        .accessibilityLabel("Show \(section.deckTitle)")
        .accessibilityValue(active ? "Selected" : "Not selected")
        .accessibilityIdentifier("hud.context.section.\(section.rawValue)")
    }

    @ViewBuilder
    private var cityContext: some View {
        switch store.inspectorSection {
        case .overview: overviewContext
        case .finances: financeContext
        case .population: populationContext
        case .happiness: happinessContext
        case .employment: employmentContext
        case .demand: demandContext
        case .utilities: utilityContext
        case .journal: journalContext
        }
    }

    private func tileContext(_ tile: CityTile) -> some View {
        LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            ContextCard(title: "Identity", symbol: tile.kind.symbol, tint: tile.kind.contextTint) {
                ContextValueRow(label: "Type", value: tile.kind.title)
                ContextValueRow(label: "Level", value: "\(tile.level)")
                if tile.constructionProgress < 1 {
                    ProgressView("Construction", value: tile.constructionProgress)
                        .tint(GameTheme.warning)
                } else {
                    Label("Operational", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GameTheme.accent)
                }
            }

            ContextCard(title: tile.kind.activityTitle, symbol: tile.kind.activitySymbol, tint: .cyan) {
                let capacity = analytics.capacity(for: tile)
                if capacity > 0 {
                    ContextValueRow(label: tile.kind == .residential ? "Residents" : "Workers", value: tile.occupancy.formatted())
                    ContextValueRow(label: "Capacity", value: capacity.formatted())
                    ProgressView(value: Double(tile.occupancy), total: Double(max(1, capacity)))
                        .tint(tile.kind.contextTint)
                } else if tile.kind == .empty {
                    Text("Ready for a road, zone, park, utility, or civic project.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ContextValueRow(label: "Condition", value: (tile.condition * 100).percentText)
                    Text(tile.kind.contextDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            ContextCard(title: "Operations", symbol: "gauge.with.dots.needle.50percent", tint: GameTheme.information) {
                ContextValueRow(label: "Upkeep", value: "\(tile.kind.upkeep.currencyText) / cycle")
                if tile.kind.requiresRoad {
                    let connected = analytics.hasRoadAccess(at: tile.coordinate)
                    ContextValueRow(label: "Road", value: connected ? "Connected" : "Missing")
                    Label(connected ? "Road access active" : "Road access needed", systemImage: connected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(connected ? GameTheme.accent : GameTheme.warning)
                } else {
                    ContextValueRow(label: "Road", value: "Not required")
                }
            }

            if let snapshot = try? CityPresentationSnapshot(state: store.state),
               let diagnosis = CitySelectedLocationDiagnosis.make(
                tile: tile,
                snapshot: snapshot
            ) {
                ContextCard(title: "Cause · consequence · response", symbol: "cross.case.fill", tint: GameTheme.warning) {
                    Text(diagnosis.cause)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(compact ? 2 : 3)
                    Text(diagnosis.consequence)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    diagnosisActions(diagnosis)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(diagnosis.accessibilitySummary)
            }

            ContextCard(title: "Next action", symbol: "arrow.turn.down.right", tint: GameTheme.accent) {
                if tile.kind == .empty {
                    HStack(spacing: 6) {
                        compactAction("Road", symbol: BuildingKind.road.symbol) { store.perform(.buildRoad) }
                        compactAction("Homes", symbol: BuildingKind.residential.symbol) { store.perform(.buildResidential) }
                    }
                    compactAction("Open build catalog", symbol: "square.grid.2x2") { store.perform(.buildMode) }
                } else if tile.kind == .cityHall {
                    Label("Protected landmark", systemImage: "shield.lefthalf.filled")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GameTheme.information)
                        .accessibilityLabel("City Hall is a protected landmark and cannot be demolished")
                    Text("City Hall anchors the city and cannot be removed.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    compactAction("City data", symbol: "chart.dots.scatter") { store.perform(.inspectorOverview) }
                } else {
                    ContextValueRow(label: "Demolition", value: tile.kind.demolitionCost.currencyText)
                    HStack(spacing: 6) {
                        compactAction("City data", symbol: "chart.dots.scatter") { store.perform(.inspectorOverview) }
                        Button(role: .destructive) { store.demolishSelected() } label: {
                            Label("Demolish", systemImage: "trash")
                                .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Demolish \(tile.kind.title) for \(tile.kind.demolitionCost.currencyText)")
                        .accessibilityHint("Demolition costs \(tile.kind.demolitionCost.currencyText). Undo is available after activation.")
                    }
                }
            }
        }
    }

    private var overviewContext: some View {
        LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            ContextCard(
                title: "Operating position",
                symbol: "chart.line.uptrend.xyaxis",
                tint: store.analytics.projectedBalance >= 0 ? GameTheme.accent : GameTheme.danger
            ) {
                ContextValueRow(label: "Net / cycle", value: store.analytics.projectedBalance.signedCurrencyText)
                ContextValueRow(label: "Housing open", value: store.analytics.housingHeadroom.formatted())
                ContextValueRow(label: "Notices", value: store.alertCount.formatted())
                compactAction("Open journal", symbol: "newspaper.fill") { store.perform(.inspectorJournal) }
            }

            ContextCard(title: "Current objective", symbol: "flag.checkered", tint: .cyan) {
                Text(store.primaryObjective.title)
                    .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold))
                    .lineLimit(1)
                Text(store.primaryObjective.remaining)
                    .font(.system(size: GameTheme.hudSupportTextSize, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                ProgressView(value: store.primaryObjective.progress).tint(.cyan)
            }

            ContextCard(title: "City identity", symbol: "building.2.fill", tint: GameTheme.accent) {
                TextField(
                    "City name",
                    text: Binding(
                        get: { store.state.cityName },
                        set: { store.state.cityName = String($0.prefix(32)) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit { store.setCityName(store.state.cityName) }
                ContextValueRow(label: "Today", value: store.state.formattedDay)
            }

            ContextCard(title: "City health", symbol: "heart.text.square.fill", tint: GameTheme.information) {
                ContextValueRow(label: "Residents", value: store.state.population.formatted())
                ContextValueRow(label: "Happiness", value: store.state.happiness.percentText)
                ContextValueRow(label: "Mayor approval", value: store.state.approval.percentText)
            }
        }
    }

    private var financeContext: some View {
        LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            ContextCard(title: "Treasury", symbol: "dollarsign.circle.fill", tint: store.state.treasury >= 0 ? GameTheme.accent : GameTheme.danger) {
                Text(store.state.treasury.currencyText)
                    .font(.title3.bold().monospacedDigit())
                Text("Available for construction and operating commitments")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ContextCard(title: "Next cycle", symbol: "arrow.triangle.2.circlepath", tint: store.analytics.projectedBalance >= 0 ? GameTheme.accent : GameTheme.danger) {
                ContextValueRow(label: "Revenue", value: store.analytics.projectedRevenue.currencyText)
                ContextValueRow(label: "Upkeep", value: store.analytics.projectedUpkeep.currencyText)
                ContextValueRow(label: "Net", value: store.analytics.projectedBalance.signedCurrencyText)
            }

            ContextCard(title: "Tax policy", symbol: "percent", tint: GameTheme.warning) {
                HStack {
                    Text("Tax rate").font(.caption.weight(.semibold))
                    Spacer()
                    Text((store.state.taxRate * 100).percentText).font(.caption.monospacedDigit())
                }
                Slider(
                    value: Binding(get: { store.state.taxRate }, set: { store.setTaxRate($0) }),
                    in: 0.04...0.18,
                    step: 0.01
                )
                .accessibilityLabel("City tax rate")
                .accessibilityValue((store.state.taxRate * 100).percentText)
            }

            ContextCard(title: "Decision support", symbol: "lightbulb.fill", tint: GameTheme.information) {
                Text(store.analytics.projectedBalance >= 0 ? "Operations are forecast to add to the treasury." : "Operating commitments exceed forecast revenue.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                compactAction("Demand", symbol: "chart.bar.fill") { store.perform(.inspectorDemand) }
            }
        }
    }

    private var populationContext: some View {
        LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            ContextCard(title: "Residents", symbol: "person.3.fill", tint: .cyan) {
                Text(store.state.population.formatted()).font(.title3.bold().monospacedDigit())
                ContextValueRow(label: "Housing", value: store.analytics.housingCapacity.formatted())
                ProgressView(value: store.analytics.housingUtilization).tint(.cyan)
            }
            ContextCard(title: "Housing reserve", symbol: "house.fill", tint: .cyan) {
                Text(store.analytics.housingHeadroom.formatted()).font(.title3.bold().monospacedDigit())
                Text("homes available before new residential capacity is needed")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(3)
            }
            ContextCard(title: "Neighborhoods", symbol: BuildingKind.residential.symbol, tint: .cyan) {
                ContextValueRow(label: "Buildings", value: store.analytics.count(.residential).formatted())
                ContextValueRow(label: "Residential demand", value: (store.state.demand.residential * 100).percentText)
                compactAction("Build homes", symbol: BuildingKind.residential.symbol) { store.perform(.buildResidential) }
            }
            ContextCard(title: "Growth balance", symbol: "person.crop.circle.badge.checkmark", tint: GameTheme.information) {
                ContextValueRow(label: "Job openings", value: store.analytics.jobHeadroom.formatted())
                ContextValueRow(label: "Employment target", value: (store.analytics.employmentRate * 100).percentText)
                compactAction("Employment", symbol: "briefcase.fill") { store.perform(.inspectorEmployment) }
            }
        }
    }

    private var happinessContext: some View {
        LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            ContextCard(title: "Resident happiness", symbol: "face.smiling.fill", tint: store.state.happiness >= 60 ? GameTheme.accent : GameTheme.warning) {
                Text(store.state.happiness.percentText).font(.title3.bold().monospacedDigit())
                ProgressView(value: store.state.happiness, total: 100)
                    .tint(store.state.happiness >= 60 ? GameTheme.accent : GameTheme.warning)
            }
            ContextCard(title: "Mayor approval", symbol: "person.badge.shield.checkmark.fill", tint: GameTheme.information) {
                Text(store.state.approval.percentText).font(.title3.bold().monospacedDigit())
                Text("Public confidence in current city stewardship")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(3)
            }
            ContextCard(title: "Livability inputs", symbol: "leaf.fill", tint: GameTheme.accent) {
                ContextValueRow(label: "Parks", value: store.analytics.count(.park).formatted())
                ContextValueRow(label: "Services", value: store.analytics.serviceBuildings.formatted())
                ContextValueRow(label: "Pollution index", value: store.analytics.pollutionPressure.formatted(.number.precision(.fractionLength(0))))
            }
            ContextCard(title: "Diagnose", symbol: "map.fill", tint: GameTheme.information) {
                compactAction("Happiness map", symbol: DataOverlay.happiness.symbol) { store.perform(.overlayHappiness) }
                compactAction("Pollution map", symbol: DataOverlay.pollution.symbol) { store.perform(.overlayPollution) }
            }
        }
    }

    private var employmentContext: some View {
        LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            ContextCard(title: "Jobs filled", symbol: "briefcase.fill", tint: .purple) {
                Text(store.state.jobs.formatted()).font(.title3.bold().monospacedDigit())
                ContextValueRow(label: "Capacity", value: store.analytics.jobCapacity.formatted())
                ProgressView(value: store.analytics.jobUtilization).tint(.purple)
            }
            ContextCard(title: "Open positions", symbol: "person.crop.circle.badge.plus", tint: .purple) {
                Text(store.analytics.jobHeadroom.formatted()).font(.title3.bold().monospacedDigit())
                ContextValueRow(label: "Resident target", value: (store.state.population * 7 / 10).formatted())
                ContextValueRow(label: "Coverage", value: (store.analytics.employmentRate * 100).percentText)
            }
            ContextCard(title: "Commercial", symbol: BuildingKind.commercial.symbol, tint: .purple) {
                ContextValueRow(label: "Buildings", value: store.analytics.count(.commercial).formatted())
                ContextValueRow(label: "Demand", value: (store.state.demand.commercial * 100).percentText)
                compactAction("Build commercial", symbol: BuildingKind.commercial.symbol) { store.perform(.buildCommercial) }
            }
            ContextCard(title: "Industrial", symbol: BuildingKind.industrial.symbol, tint: .orange) {
                ContextValueRow(label: "Buildings", value: store.analytics.count(.industrial).formatted())
                ContextValueRow(label: "Demand", value: (store.state.demand.industrial * 100).percentText)
                compactAction("Build industrial", symbol: BuildingKind.industrial.symbol) { store.perform(.buildIndustrial) }
            }
        }
    }

    private var demandContext: some View {
        LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            demandCard(title: "Residential", kind: .residential, value: store.state.demand.residential, tint: .cyan)
            demandCard(title: "Commercial", kind: .commercial, value: store.state.demand.commercial, tint: .purple)
            demandCard(title: "Industrial", kind: .industrial, value: store.state.demand.industrial, tint: .orange)
            ContextCard(title: "Development readiness", symbol: "checklist", tint: GameTheme.information) {
                ContextValueRow(label: "Treasury", value: store.state.treasury.currencyText)
                ContextValueRow(label: "Power spare", value: store.analytics.powerHeadroom.formatted())
                ContextValueRow(label: "Water spare", value: store.analytics.waterHeadroom.formatted())
                Text("Demand is opportunity; access, utilities, funds, and workforce still govern placement.")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
        }
    }

    private var utilityContext: some View {
        LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            utilityCard(
                title: "Power",
                symbol: "bolt.fill",
                used: store.state.powerUsed,
                capacity: store.state.powerCapacity,
                headroom: store.analytics.powerHeadroom,
                tint: .yellow,
                actionTitle: "Build power",
                action: { store.perform(.buildPowerPlant) }
            )
            utilityCard(
                title: "Water",
                symbol: "drop.fill",
                used: store.state.waterUsed,
                capacity: store.state.waterCapacity,
                headroom: store.analytics.waterHeadroom,
                tint: .blue,
                actionTitle: "Build water",
                action: { store.perform(.buildWaterTower) }
            )
            ContextCard(title: "Combined coverage", symbol: "bolt.horizontal.circle.fill", tint: store.analytics.utilityCoverage >= 1 ? GameTheme.accent : GameTheme.danger) {
                Text((store.analytics.utilityCoverage * 100).percentText).font(.title3.bold().monospacedDigit())
                Text(store.analytics.utilityCoverage >= 1 ? "Both networks cover current use." : "At least one network is below current use.")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                compactAction("Utility map", symbol: DataOverlay.utilities.symbol) { store.perform(.overlayUtilities) }
            }
            ContextCard(title: "Expansion signal", symbol: "chart.line.uptrend.xyaxis", tint: GameTheme.information) {
                ContextValueRow(label: "Residents", value: store.state.population.formatted())
                ContextValueRow(label: "Housing open", value: store.analytics.housingHeadroom.formatted())
                ContextValueRow(label: "Growth demand", value: (store.state.demand.residential * 100).percentText)
            }
        }
    }

    private var journalContext: some View {
        let summaries = store.messageSummaries
        return Group {
            if summaries.count > 4 && !compact {
                ScrollView(.vertical) {
                    journalGrid(summaries)
                }
                .scrollIndicators(.visible)
                .frame(maxHeight: compact ? 168 : 180, alignment: .top)
                .accessibilityLabel("City notice journal")
            } else {
                journalGrid(summaries)
            }
        }
    }

    @ViewBuilder
    private func journalGrid(_ summaries: [CityMessageSummary]) -> some View {
        LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            if summaries.isEmpty {
                ContextCard(title: "All clear", symbol: "checkmark.circle.fill", tint: GameTheme.accent) {
                    Text("There are no active city notices.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                ForEach(summaries) { summary in
                    ContextCard(title: summary.message.title, symbol: summary.message.severity.symbol, tint: summary.message.severity.tint) {
                        HStack {
                            Text("Day \(summary.message.tick / 4 + 1)")
                            Spacer()
                            if summary.count > 1 { Text("×\(summary.count)") }
                        }
                        .font(.system(size: GameTheme.hudSupportTextSize, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        Text(summary.message.detail)
                            .font(.system(size: GameTheme.hudSupportTextSize, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        HStack(spacing: 6) {
                            compactAction("Related data", symbol: "arrow.up.forward.square") { store.openMessage(summary.message) }
                            noticeActionMenu(summary.message)
                            Button("Dismiss") { store.dismissMessageSummary(summary) }
                                .buttonStyle(.borderless)
                                .frame(minHeight: GameTheme.controlMinimum)
                                .accessibilityLabel("Dismiss \(summary.message.title) notices")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func diagnosisActions(_ diagnosis: CitySelectedLocationDiagnosis) -> some View {
        if let primary = diagnosis.responses.first {
            compactAction(primary.title, symbol: primary.focusesMap ? "scope" : "arrow.up.forward.square") {
                perform(primary)
            }
            .accessibilityHint(primary.explanation + (primary.focusesMap ? " Focus returns to the map." : ""))
        }
        if diagnosis.responses.count > 1 {
            Menu("More responses") {
                ForEach(Array(diagnosis.responses.dropFirst())) { response in
                    Button(response.title) { perform(response) }
                        .accessibilityHint(response.explanation + (response.focusesMap ? " Focus returns to the map." : ""))
                }
            }
            .frame(minHeight: GameTheme.controlMinimum)
            .accessibilityLabel("More honest responses for selected block")
        }
    }

    @ViewBuilder
    private func noticeActionMenu(_ message: CityMessage) -> some View {
        let actions = CityNoticeActionCatalog.actions(for: message.title)
        if !actions.isEmpty {
            Menu("Act") {
                ForEach(actions) { response in
                    Button(response.title) { perform(response) }
                        .accessibilityHint(response.explanation + (response.focusesMap ? " Focus returns to the map." : ""))
                }
            }
            .frame(minHeight: GameTheme.controlMinimum)
            .accessibilityLabel("Act on \(message.title)")
        }
    }

    private func perform(_ response: CityDirectResponse) {
        if response.focusesMap {
            store.performMapFocused(response.command)
        } else {
            store.perform(response.command)
        }
    }

    private func demandCard(title: String, kind: BuildingKind, value: Double, tint: Color) -> some View {
        ContextCard(title: title, symbol: kind.symbol, tint: tint) {
            HStack {
                Text((value * 100).percentText).font(.title3.bold().monospacedDigit())
                Spacer()
                Text(value.demandLabel).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            ProgressView(value: value).tint(tint)
            compactAction("Build \(title.lowercased())", symbol: kind.symbol) { store.perform(CityCommandCatalog.id(for: kind)) }
        }
    }

    private func utilityCard(
        title: String,
        symbol: String,
        used: Int,
        capacity: Int,
        headroom: Int,
        tint: Color,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        ContextCard(title: title, symbol: symbol, tint: tint) {
            ContextValueRow(label: "Use", value: "\(used.formatted()) / \(capacity.formatted())")
            ContextValueRow(label: "Spare", value: headroom.formatted())
            ProgressView(value: Double(used), total: Double(max(1, capacity))).tint(used > capacity ? GameTheme.danger : tint)
            compactAction(actionTitle, symbol: symbol, action: action)
        }
    }

    private func compactAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
    }

    private var contextAccessibilityLabel: String {
        if store.hudContextScope == .selection, let tile = store.selectedTile {
            return "Selected block command center, \(tile.kind.title), block \(tile.coordinate.x + 1), \(tile.coordinate.y + 1)"
        }
        return "City command center, \(store.inspectorSection.deckTitle)"
    }
}

private struct ContextCard<Content: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    let content: Content

    init(title: String, symbol: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title.uppercased(), systemImage: symbol)
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded))
                .tracking(0.25)
                .foregroundStyle(tint)
                .lineLimit(1)
            content
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct ContextValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Text(label).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 4)
            Text(value).monospacedDigit().lineLimit(1)
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
    }
}

private extension InspectorSection {
    var deckTitle: String {
        switch self {
        case .overview: "Overview"
        case .finances: "Finances"
        case .population: "Population"
        case .happiness: "Happiness"
        case .employment: "Employment"
        case .demand: "Demand"
        case .utilities: "Utilities"
        case .journal: "Journal"
        }
    }
}

private extension BuildingKind {
    var contextTint: Color {
        switch self {
        case .residential: .cyan
        case .commercial: .purple
        case .industrial: .orange
        case .park: GameTheme.accent
        case .powerPlant: .yellow
        case .waterTower: .blue
        case .fireStation: GameTheme.danger
        case .policeStation: GameTheme.information
        case .school: .mint
        case .cityHall: .teal
        case .road, .empty: .secondary
        }
    }

    var activityTitle: String {
        switch self {
        case .residential: "Residents"
        case .commercial, .industrial: "Workplaces"
        case .empty: "Opportunity"
        default: "Status"
        }
    }

    var activitySymbol: String {
        switch self {
        case .residential: "person.2.fill"
        case .commercial, .industrial: "person.crop.rectangle.stack.fill"
        case .empty: "sparkles"
        default: "checkmark.seal.fill"
        }
    }

    var contextDescription: String {
        switch self {
        case .road: "Connected street segment supporting nearby development."
        case .park: "Public green space supporting neighborhood livability."
        case .powerPlant: "Citywide electrical generation infrastructure."
        case .waterTower: "Citywide water capacity infrastructure."
        case .fireStation: "Fire protection and emergency response coverage."
        case .policeStation: "Public safety and police service coverage."
        case .school: "Education and neighborhood service capacity."
        case .cityHall: "Protected civic landmark and city administration."
        default: "Active city property."
        }
    }
}

private extension MessageSeverity {
    var symbol: String {
        switch self {
        case .good: "sparkles"
        case .information: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .good: GameTheme.accent
        case .information: GameTheme.information
        case .warning: GameTheme.warning
        case .critical: GameTheme.danger
        }
    }
}

private extension Double {
    var demandLabel: String {
        if self >= 0.67 { return "High" }
        if self >= 0.34 { return "Steady" }
        return "Low"
    }
}
