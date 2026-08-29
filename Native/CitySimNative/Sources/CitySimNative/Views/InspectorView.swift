import SwiftUI

struct CityFinanceDecisionSupport: Equatable {
    let detail: String
    let accessibilityHint: String
    let recoveryTaxRate: Double?
    let offersParkAlternative: Bool

    static func make(analytics: CityAnalytics) -> CityFinanceDecisionSupport {
        if analytics.projectedBalance >= 0 {
            let detail = "Operations forecast \(analytics.projectedBalance.signedCurrencyText) per cycle. Lower tax supports demand; higher tax builds reserves."
            return CityFinanceDecisionSupport(
                detail: detail,
                accessibilityHint: detail,
                recoveryTaxRate: nil,
                offersParkAlternative: false
            )
        }

        if let recoveryTaxRate = analytics.breakEvenTaxRate {
            let recoveryBalance = analytics.projectedBalance(atTaxRate: recoveryTaxRate)
            let rate = (recoveryTaxRate * 100).percentText
            let conflictsWithMainStreet = recoveryTaxRate > 0.09
                && analytics.committedStrategy == .commercialStewardship
                && analytics.strategyRecoveryResolution == nil
                && analytics.strategyPhase != .completed
            let offersParkAlternative = conflictsWithMainStreet && analytics.count(.park) < 2
            let detail = if conflictsWithMainStreet {
                "\(rate) restores \(recoveryBalance.signedCurrencyText) per cycle but ends the 9% tax-relief route. \(offersParkAlternative ? "Build a second park first, or grow revenue." : "Main Street already has its park alternative; raise tax when ready.")"
            } else {
                "\(rate) tax forecasts \(recoveryBalance.signedCurrencyText) per cycle. Higher tax cools demand; growth or lower upkeep preserves today's rate."
            }
            return CityFinanceDecisionSupport(
                detail: detail,
                accessibilityHint: conflictsWithMainStreet
                    ? "Raising tax to \(rate) restores non-negative cashflow but conflicts with the 9% Main Street tax-relief route."
                    : "Raise the tax slider to \(rate) to restore non-negative cashflow now. Higher taxes can reduce demand.",
                recoveryTaxRate: recoveryTaxRate,
                offersParkAlternative: offersParkAlternative
            )
        }

        let gap = (-analytics.projectedBalance).currencyText
        let detail = "Tax alone cannot close the \(gap) gap. Add occupied homes or jobs, or remove unneeded upkeep."
        return CityFinanceDecisionSupport(
            detail: detail,
            accessibilityHint: detail,
            recoveryTaxRate: nil,
            offersParkAlternative: false
        )
    }
}

struct InspectorView: View {
    @ObservedObject var store: CityGameStore
    var compact = false
    @FocusState private var cityNameFieldFocused: Bool

    static let compactColumnCount = 2
    static let regularColumnCount = 4
    static let compactMinimumVisibleNoticeCount = 2

    enum FinanceCard: Hashable {
        case treasury
        case nextCycle
        case taxPolicy
        case decisionSupport
    }

    enum SelectionActionTier: Equatable {
        case diagnosis
        case nextAction
        case siteActions
    }

    static func financeCardOrder(compact: Bool, projectedBalance: Double) -> [FinanceCard] {
        guard compact else {
            return [.treasury, .nextCycle, .taxPolicy, .decisionSupport]
        }
        return projectedBalance < 0
            ? [.taxPolicy, .decisionSupport, .nextCycle, .treasury]
            : [.taxPolicy, .treasury, .nextCycle, .decisionSupport]
    }

    static func selectionActionOrder(
        for kind: BuildingKind,
        diagnosisAvailable: Bool
    ) -> [SelectionActionTier] {
        var order: [SelectionActionTier] = diagnosisAvailable ? [.diagnosis] : []
        if kind == .empty || kind == .cityHall {
            order.append(.nextAction)
        } else if kind == .road {
            order.append(contentsOf: [.nextAction, .siteActions])
        } else {
            order.append(.siteActions)
        }
        return order
    }

    private var analytics: CityAnalytics { store.analytics }
    private var financeDecisionSupport: CityFinanceDecisionSupport {
        CityFinanceDecisionSupport.make(analytics: analytics)
    }
    private var utilityDecisionSupport: CityUtilityDecisionSupport {
        CityUtilityDecisionSupport.make(analytics: analytics)
    }
    private var resiliencePresentation: CityResiliencePresentation {
        CityResiliencePresentation.make(analytics: analytics)
    }
    private var growthCapacityPresentation: CityGrowthCapacityPresentation {
        CityGrowthCapacityPresentation.make(analytics: analytics)
    }
    private var contextColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 8, alignment: .top),
            count: compact ? Self.compactColumnCount : Self.regularColumnCount
        )
    }

    var body: some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 6) {
                    contextHeader
                    Divider().overlay(GameTheme.subtleDivider)
                    contextBody
                        .frame(maxWidth: .infinity, alignment: .topLeading)
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
                Image(systemName: "xmark")
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
        case .trends: trendsContext
        case .resilience: resilienceContext
        }
    }

    private func tileContext(_ tile: CityTile) -> some View {
        let snapshot = try? CityPresentationSnapshot(state: store.state)
        let diagnosis = snapshot.flatMap {
            CitySelectedLocationDiagnosis.make(tile: tile, snapshot: $0)
        }
        let actionOrder = Self.selectionActionOrder(
            for: tile.kind,
            diagnosisAvailable: diagnosis != nil
        )
        return LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            if actionOrder.first == .diagnosis, let diagnosis {
                diagnosisCard(diagnosis)
            }

            if let outlook = CityDevelopmentOutlook.make(tile: tile, state: store.state) {
                let outlookTint: Color = switch outlook.status {
                case .ready: GameTheme.accent
                case .held: GameTheme.warning
                case .building, .mature: GameTheme.information
                }
                ContextCard(
                    title: "Growth outlook",
                    symbol: "arrow.up.right.square.fill",
                    tint: outlookTint
                ) {
                    Text(outlook.statusLabel.uppercased())
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(outlookTint)
                        .lineLimit(1)
                    Text(outlook.detail)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text(outlook.payoff)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Growth outlook")
                .accessibilityValue(outlook.accessibilitySummary)
            }

            if let snapshot,
               let conditions = CitySelectedLocationConditions.make(
                   tile: tile,
                   snapshot: snapshot
                ) {
                ContextCard(title: "Local conditions", symbol: "map.fill", tint: GameTheme.information) {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        alignment: .leading,
                        spacing: 4
                    ) {
                        localConditionMetric("Value", conditions.landValueIndex.formatted())
                        localConditionMetric("Utility", "\(conditions.utilityService)%")
                        localConditionMetric("Service", "\(conditions.civicServiceCoverage)%")
                        if let commuteAccess = conditions.commuteAccess {
                            localConditionMetric("Commute", "\(commuteAccess)%")
                        }
                        localConditionMetric("Traffic", "\(conditions.trafficExposure)%")
                        localConditionMetric("Pollution", "\(conditions.pollutionExposure)%")
                        localConditionMetric(
                            conditions.vitality.capitalized,
                            "\(conditions.vitalityScore)%"
                        )
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Local conditions")
                .accessibilityValue(conditions.accessibilitySummary)
            }

            if actionOrder.contains(.nextAction) {
                nextActionCard(for: tile)
            }

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

            if actionOrder.last == .siteActions {
                siteActionsCard(for: tile)
            }
        }
    }

    private func diagnosisCard(_ diagnosis: CitySelectedLocationDiagnosis) -> some View {
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
        .accessibilityIdentifier("hud.selection.priority-response")
    }

    private func localConditionMetric(_ label: String, _ value: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption2.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private func nextActionCard(for tile: CityTile) -> some View {
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
            } else if let maintenance = CityRoadMaintenancePresentation.make(
                tile: tile,
                state: store.state
            ) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(maintenance.band.title.uppercased())
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(
                            maintenance.band == .maintained
                                ? GameTheme.accent
                                : maintenance.band == .worn
                                    ? GameTheme.warning
                                    : GameTheme.danger
                        )
                    Spacer(minLength: 4)
                    Text("\(maintenance.conditionPercent)%")
                        .font(.caption.bold().monospacedDigit())
                }
                Text(maintenance.statusDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(compact ? 2 : 3)
                if maintenance.needsRepair {
                    Button { store.repairSelectedRoad() } label: {
                        Label(maintenance.repairTitle, systemImage: "wrench.and.screwdriver.fill")
                            .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(maintenance.band == .damaged ? GameTheme.danger : GameTheme.warning)
                    .disabled(!maintenance.canAfford)
                    .help(
                        maintenance.canAfford
                            ? "Restore full road capacity and commute reliability. Undo is available."
                            : "Treasury funds are below the repair cost."
                    )
                    .accessibilityLabel(maintenance.repairTitle)
                    .accessibilityHint(
                        maintenance.canAfford
                            ? "Restores full road capacity and commute reliability. Undo is available."
                            : "Unavailable because the treasury is below the repair cost."
                    )
                    .accessibilityIdentifier("hud.selection.road-repair")
                } else {
                    compactAction("Traffic map", symbol: DataOverlay.traffic.symbol) {
                        store.perform(.overlayTraffic)
                    }
                }
            }
        }
    }

    private func siteActionsCard(for tile: CityTile) -> some View {
        ContextCard(title: "Site actions", symbol: "wrench.and.screwdriver.fill", tint: GameTheme.information) {
            ContextValueRow(
                label: "Demolition",
                value: store.state.usesUnlimitedFunds ? "Waived" : tile.kind.demolitionCost.currencyText
            )
            if let forecast = CityDemolitionForecast.make(tile: tile, state: store.state) {
                Text(forecast.summary)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(forecast.balanceChange >= 0 ? GameTheme.accent : GameTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Demolition impact")
                    .accessibilityValue(forecast.summary)
            }
            HStack(spacing: 6) {
                compactAction("City data", symbol: "chart.dots.scatter") { store.perform(.inspectorOverview) }
                Button(role: .destructive) { store.demolishSelected() } label: {
                    Label("Demolish", systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(
                    store.state.usesUnlimitedFunds
                        ? "Demolish \(tile.kind.title) with spending waived"
                        : "Demolish \(tile.kind.title) for \(tile.kind.demolitionCost.currencyText)"
                )
                .accessibilityHint(
                    store.state.usesUnlimitedFunds
                        ? "Sandbox demolition spending is waived. The operating and capacity impact is shown above. Undo is available after activation."
                        : "Demolition costs \(tile.kind.demolitionCost.currencyText). The operating and capacity impact is shown above. Undo is available after activation."
                )
            }
        }
        .accessibilityIdentifier("hud.selection.site-actions")
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
                        get: { store.cityNameDraft },
                        set: { store.updateCityNameDraft($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .focused($cityNameFieldFocused)
                .onSubmit { store.commitCityNameDraft() }
                .onChange(of: cityNameFieldFocused) { _, focused in
                    if !focused { store.commitCityNameDraft() }
                }
                .onDisappear { store.commitCityNameDraft() }
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
            ForEach(
                Self.financeCardOrder(
                    compact: compact,
                    projectedBalance: analytics.projectedBalance
                ),
                id: \.self
            ) { card in
                financeCard(card)
            }
        }
    }

    @ViewBuilder
    private func financeCard(_ card: FinanceCard) -> some View {
        switch card {
        case .treasury:
            ContextCard(
                title: "Treasury",
                symbol: "dollarsign.circle.fill",
                tint: store.state.usesUnlimitedFunds || store.state.treasury >= 0
                    ? GameTheme.accent
                    : GameTheme.danger
            ) {
                Text(store.state.usesUnlimitedFunds ? "Unlimited" : store.state.treasury.currencyText)
                    .font(.title3.bold().monospacedDigit())
                Text(treasuryDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .nextCycle:
            ContextCard(title: "Next cycle", symbol: "arrow.triangle.2.circlepath", tint: store.analytics.projectedBalance >= 0 ? GameTheme.accent : GameTheme.danger) {
                ContextValueRow(label: "Revenue", value: store.analytics.projectedRevenue.currencyText)
                ContextValueRow(label: "Upkeep", value: store.analytics.projectedUpkeep.currencyText)
                ContextValueRow(label: "Net", value: store.analytics.projectedBalance.signedCurrencyText)
            }
        case .taxPolicy:
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
                .accessibilityHint(financeDecisionSupport.accessibilityHint)
            }
        case .decisionSupport:
            ContextCard(title: "Decision support", symbol: "lightbulb.fill", tint: GameTheme.information) {
                Text(financeDecisionSupport.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                if financeDecisionSupport.offersParkAlternative {
                    compactAction("Build second park", symbol: BuildingKind.park.symbol) {
                        store.performMapFocused(.buildPark)
                    }
                } else if analytics.projectedBalance >= 0 {
                    compactAction("Demand", symbol: "chart.bar.fill") { store.perform(.inspectorDemand) }
                }
            }
        }
    }

    private var populationContext: some View {
        let forecast = growthCapacityPresentation
        return LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            ContextCard(
                title: forecast.decisionTitle,
                symbol: forecast.constraint?.symbol ?? "chart.line.uptrend.xyaxis",
                tint: growthForecastTint(forecast.phase),
                minimumHeight: 80
            ) {
                compactAction(
                    forecast.response.title,
                    symbol: forecast.constraint?.symbol ?? "chart.bar.fill"
                ) {
                    perform(forecast.response)
                }
                .accessibilityHint(forecast.response.explanation)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(forecast.accessibilitySummary)
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
        }
    }

    private func growthForecastTint(
        _ phase: CityGrowthCapacityPresentation.Phase
    ) -> Color {
        switch phase {
        case .currentShortfall: GameTheme.danger
        case .prepare: GameTheme.warning
        case .ready: GameTheme.accent
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
        let pipeline = CityDevelopmentPipeline.make(state: store.state)
        return LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            if compact {
                developmentPipelineCard(pipeline)
            }
            ForEach(demandKinds, id: \.rawValue) { kind in
                demandCard(
                    title: kind.title,
                    kind: kind,
                    value: demandValue(for: kind),
                    tint: demandTint(for: kind)
                )
            }
            if !compact {
                developmentPipelineCard(pipeline)
            }
        }
    }

    private var demandKinds: [BuildingKind] {
        Self.demandKindOrder(compact: compact, demand: store.state.demand)
    }

    static func demandKindOrder(compact: Bool, demand: DemandLevels) -> [BuildingKind] {
        let kinds = [BuildingKind.residential, .commercial, .industrial]
        guard compact else { return kinds }
        return kinds.sorted { lhs, rhs in
            let left = demandValue(for: lhs, demand: demand)
            let right = demandValue(for: rhs, demand: demand)
            if left != right { return left > right }
            return lhs.rawValue < rhs.rawValue
        }
    }

    private func demandValue(for kind: BuildingKind) -> Double {
        Self.demandValue(for: kind, demand: store.state.demand)
    }

    private static func demandValue(for kind: BuildingKind, demand: DemandLevels) -> Double {
        switch kind {
        case .residential: demand.residential
        case .commercial: demand.commercial
        case .industrial: demand.industrial
        default: 0
        }
    }

    private func demandTint(for kind: BuildingKind) -> Color {
        switch kind {
        case .residential: .cyan
        case .commercial: .purple
        case .industrial: .orange
        default: GameTheme.information
        }
    }

    private func developmentPipelineCard(_ pipeline: CityDevelopmentPipeline) -> some View {
        ContextCard(title: "Growth pipeline", symbol: "checklist", tint: GameTheme.information) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(pipeline.readyCount) READY")
                    .font(.title3.bold().monospacedDigit())
                Spacer(minLength: 4)
                Text("\(pipeline.heldCount) HELD")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(pipeline.heldCount > 0 ? GameTheme.warning : .secondary)
            }
            .accessibilityHidden(true)
            if let response = pipeline.response {
                Button {
                    StrategyCommandCenterView.perform(response, on: store)
                } label: {
                    HStack(spacing: 4) {
                        Text(pipeline.detail)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Spacer(minLength: 2)
                        Image(systemName: "arrow.right.circle.fill")
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(GameTheme.information)
                .frame(minHeight: 24)
                .help(response.explanation)
                .accessibilityLabel(response.title)
                .accessibilityValue(pipeline.accessibilitySummary)
                .accessibilityHint(response.explanation)
            } else {
                Text(pipeline.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .accessibilityLabel(pipeline.accessibilitySummary)
            }
        }
    }

    private var treasuryDetail: String {
        guard let rules = store.state.sandboxRules else {
            return "Available for construction and operating commitments"
        }
        if rules.unlimitedFunds {
            return "Spending waived · cash fixed · \(rules.economy.title) economy · \(rules.incidentsEnabled ? "incidents on" : "incidents off")"
        }
        return "\(rules.economy.title) economy · \(rules.incidentsEnabled ? "incidents on" : "incidents off")"
    }

    private var utilityContext: some View {
        let support = utilityDecisionSupport
        return LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            ContextCard(
                title: support.title,
                symbol: support.status == .shortfall ? "exclamationmark.octagon.fill" : "gauge.with.dots.needle.67percent",
                tint: utilityDecisionTint
            ) {
                Text(support.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                if let response = support.response {
                    compactAction(response.title, symbol: support.priorityKind.symbol) {
                        StrategyCommandCenterView.perform(response, on: store)
                    }
                } else {
                    compactAction("Utility map", symbol: DataOverlay.utilities.symbol) {
                        store.performMapFocused(.overlayUtilities)
                    }
                }
            }
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
        }
    }

    private var utilityDecisionTint: Color {
        switch utilityDecisionSupport.status {
        case .healthy: GameTheme.accent
        case .tight: GameTheme.warning
        case .shortfall: GameTheme.danger
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

    private var resilienceContext: some View {
        let presentation = resiliencePresentation
        return LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
            ContextCard(
                title: "Incident outlook",
                symbol: "cloud.bolt.rain.fill",
                tint: resilienceTint(for: presentation.phase)
            ) {
                Text(presentation.status)
                    .font(.title3.bold().monospaced())
                    .foregroundStyle(resilienceTint(for: presentation.phase))
                Text(presentation.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Text(presentation.timingLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ContextCard(title: "Exposure", symbol: "house.and.flag.fill", tint: GameTheme.warning) {
                ContextValueRow(label: "Homes", value: presentation.exposureLabel)
                ContextValueRow(label: "Response cost", value: "$2,000")
                Text(presentation.protectionLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            ContextCard(title: "Recovery standard", symbol: "bolt.shield.fill", tint: GameTheme.information) {
                Text(presentation.reserveLabel)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .lineLimit(2)
                Text(presentation.recoveryLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                compactAction("Utility details", symbol: DataOverlay.utilities.symbol) {
                    store.perform(.inspectorUtilities)
                }
            }

            ContextCard(title: "Next preparation", symbol: "checklist", tint: GameTheme.accent) {
                Text(presentation.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                compactAction(
                    presentation.primaryResponse.title,
                    symbol: "arrow.up.forward.square"
                ) {
                    perform(presentation.primaryResponse)
                }
                .accessibilityHint(presentation.primaryResponse.explanation)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(presentation.accessibilitySummary)
    }

    private func resilienceTint(
        for phase: CityResiliencePresentation.Phase
    ) -> Color {
        switch phase {
        case .incidentsDisabled, .ready, .recovered:
            GameTheme.accent
        case .growthWatch, .recovering:
            GameTheme.information
        case .prepare:
            GameTheme.warning
        case .recoveryBlocked:
            GameTheme.danger
        }
    }

    @ViewBuilder
    private var trendsContext: some View {
        let samples = store.state.cityHistory ?? []
        if samples.isEmpty {
            LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
                ContextCard(title: "History starts here", symbol: "clock.arrow.circlepath", tint: GameTheme.information) {
                    Text("This checkpoint predates daily trends. New regions retain up to 90 daily observations in their saves.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
        } else {
            LazyVGrid(columns: contextColumns, alignment: .leading, spacing: 8) {
                ForEach(CityTrendMetric.allCases) { metric in
                    trendCard(metric, samples: samples)
                }
            }
        }
    }

    private func trendCard(_ metric: CityTrendMetric, samples: [CityHistorySample]) -> some View {
        let values = samples.map { metric.value(in: $0) }
        let first = values.first ?? 0
        let latest = values.last ?? 0
        let change = latest - first
        let firstDay = samples.first?.day ?? store.state.day
        let latestDay = samples.last?.day ?? store.state.day
        return ContextCard(title: metric.title, symbol: metric.symbol, tint: metric.tint(change: change)) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.formatted(latest))
                    .font(.title3.bold().monospacedDigit())
                Spacer(minLength: 4)
                Text(metric.formattedChange(change))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(metric.tint(change: change))
            }
            CityTrendSparkline(values: values, tint: metric.tint(change: change))
            Text(samples.count == 1 ? "Day \(latestDay) baseline" : "Day \(firstDay) to Day \(latestDay) · \(samples.count) daily points")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(metric.accessibilityLabel(first: first, latest: latest, change: change, firstDay: firstDay, latestDay: latestDay))
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
        let actions = CityNoticeActionCatalog.actions(for: message.title, analytics: analytics)
        if !actions.isEmpty {
            Menu("Act") {
                ForEach(actions) { response in
                    Button(response.title) {
                        StrategyCommandCenterView.perform(response, on: store)
                    }
                        .accessibilityHint(response.explanation + (response.focusesMap ? " Focus returns to the map." : ""))
                }
            }
            .frame(minHeight: GameTheme.controlMinimum)
            .accessibilityLabel("Act on \(message.title)")
        }
    }

    private func perform(_ response: CityDirectResponse) {
        StrategyCommandCenterView.perform(response, on: store)
    }

    private func demandCard(title: String, kind: BuildingKind, value: Double, tint: Color) -> some View {
        ContextCard(title: title, symbol: kind.symbol, tint: tint) {
            HStack(spacing: 6) {
                Text((value * 100).percentText).font(.title3.bold().monospacedDigit())
                Text(value.demandLabel).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Button("Build") {
                    store.perform(CityCommandCatalog.id(for: kind))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Choose \(title) and return focus to the map")
                .accessibilityLabel("Build \(title.lowercased())")
                .accessibilityHint("Chooses \(title) and returns focus to the map")
            }
            ProgressView(value: value).tint(tint)
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
    let minimumHeight: CGFloat
    let content: Content

    init(
        title: String,
        symbol: String,
        tint: Color,
        minimumHeight: CGFloat = 108,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.minimumHeight = minimumHeight
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
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
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
        case .trends: "Trends"
        case .resilience: "Resilience"
        }
    }
}

private enum CityTrendMetric: String, CaseIterable, Identifiable {
    case population, treasury, cashflow, happiness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .population: "Population"
        case .treasury: "Treasury"
        case .cashflow: "Cashflow"
        case .happiness: "Happiness"
        }
    }

    var symbol: String {
        switch self {
        case .population: "person.3.fill"
        case .treasury: "dollarsign.circle.fill"
        case .cashflow: "arrow.up.arrow.down.circle.fill"
        case .happiness: "face.smiling.fill"
        }
    }

    func value(in sample: CityHistorySample) -> Double {
        switch self {
        case .population: Double(sample.population)
        case .treasury: sample.treasury
        case .cashflow: sample.projectedBalance
        case .happiness: sample.happiness
        }
    }

    func formatted(_ value: Double) -> String {
        switch self {
        case .population: Int(value.rounded()).formatted()
        case .treasury: value.currencyText
        case .cashflow: value.signedCurrencyText
        case .happiness: value.percentText
        }
    }

    func formattedChange(_ change: Double) -> String {
        switch self {
        case .population:
            let value = Int(change.rounded())
            return value == 0 ? "No change" : "\(value > 0 ? "+" : "")\(value.formatted())"
        case .treasury, .cashflow:
            return change == 0 ? "No change" : change.signedCurrencyText
        case .happiness:
            return change == 0 ? "No change" : "\(change > 0 ? "+" : "")\(change.formatted(.number.precision(.fractionLength(1)))) pts"
        }
    }

    func tint(change: Double) -> Color {
        if abs(change) < 0.001 { return GameTheme.information }
        return change > 0 ? GameTheme.accent : GameTheme.warning
    }

    func accessibilityLabel(first: Double, latest: Double, change: Double, firstDay: Int, latestDay: Int) -> String {
        "\(title). Day \(firstDay), \(formatted(first)). Day \(latestDay), \(formatted(latest)). Change, \(formattedChange(change))."
    }
}

private struct CityTrendSparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        Canvas { context, size in
            guard let minimum = values.min(), let maximum = values.max(), !values.isEmpty else { return }
            let range = max(maximum - minimum, 1)
            let denominator = max(1, values.count - 1)
            if values.count == 1 {
                context.fill(
                    Path(ellipseIn: CGRect(x: 0, y: size.height / 2 - 2, width: 4, height: 4)),
                    with: .color(tint)
                )
                return
            }
            var path = Path()
            for (index, value) in values.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(denominator)
                let normalized = (value - minimum) / range
                let y = size.height - 3 - ((size.height - 6) * CGFloat(normalized))
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 28)
        .padding(.vertical, 2)
        .accessibilityHidden(true)
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
