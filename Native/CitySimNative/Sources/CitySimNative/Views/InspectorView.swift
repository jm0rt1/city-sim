import SwiftUI

struct InspectorView: View {
    @ObservedObject var store: CityGameStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let tile = store.selectedTile {
                    tileInspector(tile)
                } else {
                    sectionPicker
                    Divider()
                    sectionContent
                }
            }
            .padding(18)
        }
        .background(.regularMaterial)
    }

    private var sectionPicker: some View {
        Picker("Inspector", selection: $store.inspectorSection) {
            ForEach(InspectorSection.allCases) { section in
                Label(section.title, systemImage: section.symbol).tag(section)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch store.inspectorSection {
        case .overview: overviewSection
        case .finances: financeSection
        case .population: populationSection
        case .happiness: happinessSection
        case .employment: employmentSection
        case .demand: demandSection
        case .utilities: utilitySection
        case .journal: journalSection
        }
    }

    private func tileInspector(_ tile: CityTile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(tile.kind.title, systemImage: tile.kind.symbol).font(.title2.bold())
                Spacer()
                Button("City Details") { store.openInspector(.overview) }.buttonStyle(.link)
            }
            Text("Block \(tile.coordinate.x + 1), \(tile.coordinate.y + 1)")
                .font(.caption).foregroundStyle(.secondary)
            InspectorRow(label: "Level", value: "\(tile.level)")
            InspectorRow(label: "Occupancy", value: tile.occupancy.formatted())
            InspectorRow(label: "Condition", value: (tile.condition * 100).formatted(.number.precision(.fractionLength(0))) + "%")
            InspectorRow(label: "Upkeep", value: tile.kind.upkeep.currencyText + " / cycle")
            InspectorRow(label: "Road access", value: tile.kind.requiresRoad ? "Required" : "Not required")
            if tile.constructionProgress < 1 {
                ProgressView("Construction", value: tile.constructionProgress).tint(GameTheme.warning)
            }
            Divider()
            Button(role: .destructive) { store.demolishSelected() } label: {
                Label("Demolish Structure", systemImage: "trash")
            }
            .disabled(tile.kind == .cityHall || tile.kind == .empty)
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeader(.overview, detail: "Manage the city identity and review its operating position.")
            TextField(
                "City name",
                text: Binding(
                    get: { store.state.cityName },
                    set: { store.state.cityName = String($0.prefix(32)) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit { store.setCityName(store.state.cityName) }
            InspectorRow(label: "Day", value: "\(store.state.day)")
            InspectorRow(label: "Approval", value: store.state.approval.percentText)
            InspectorRow(label: "Population", value: store.state.population.formatted())
            InspectorRow(label: "Jobs filled", value: store.state.jobs.formatted())
            InspectorRow(label: "Active tool", value: store.bulldozeMode ? "Bulldozer" : store.selectedTool.title)
            Button { store.openInspector(.journal) } label: { Label("Open City Journal", systemImage: "newspaper") }
        }
    }

    private var financeSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeader(.finances, detail: "Adjust taxation and see the next-cycle operating forecast.")
            InspectorRow(label: "Treasury", value: store.state.treasury.currencyText)
            InspectorRow(label: "Projected revenue", value: store.analytics.projectedRevenue.currencyText)
            InspectorRow(label: "Projected upkeep", value: store.analytics.projectedUpkeep.currencyText)
            HStack {
                Text("Projected balance").foregroundStyle(.secondary)
                Spacer()
                Text(store.analytics.projectedBalance.currencyText)
                    .monospacedDigit().foregroundStyle(store.analytics.projectedBalance >= 0 ? GameTheme.accent : GameTheme.danger)
            }
            Divider()
            HStack {
                Text("Tax rate")
                Spacer()
                Text((store.state.taxRate * 100).formatted(.number.precision(.fractionLength(0))) + "%").monospacedDigit()
            }
            Slider(
                value: Binding(get: { store.state.taxRate }, set: { store.setTaxRate($0) }),
                in: 0.04...0.18,
                step: 0.01
            )
            Text("Higher taxes increase revenue immediately but suppress demand and happiness.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var populationSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeader(.population, detail: "Housing and jobs jointly determine whether the city can keep growing.")
            InspectorRow(label: "Residents", value: store.state.population.formatted())
            InspectorRow(label: "Housing capacity", value: store.analytics.housingCapacity.formatted())
            InspectorRow(label: "Available homes", value: max(0, store.analytics.housingCapacity - store.state.population).formatted())
            InspectorRow(label: "Residential buildings", value: store.analytics.count(.residential).formatted())
            ProgressView(
                "Housing utilization",
                value: Double(store.state.population),
                total: Double(max(1, store.analytics.housingCapacity))
            ).tint(.cyan)
            Button { store.selectTool(.residential) } label: { Label("Select Residential Tool", systemImage: BuildingKind.residential.symbol) }
        }
    }

    private var happinessSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeader(.happiness, detail: "Livability responds to utilities, jobs, parks, services, pollution, and taxes.")
            InspectorRow(label: "Happiness", value: store.state.happiness.percentText)
            InspectorRow(label: "Mayor approval", value: store.state.approval.percentText)
            InspectorRow(label: "Parks", value: store.analytics.count(.park).formatted())
            InspectorRow(label: "Service buildings", value: store.analytics.serviceBuildings.formatted())
            InspectorRow(label: "Pollution pressure", value: store.analytics.pollutionPressure.percentText)
            ProgressView(value: store.state.happiness, total: 100).tint(store.state.happiness >= 60 ? GameTheme.accent : GameTheme.warning)
            HStack {
                Button("Happiness Map") { store.overlay = .happiness }
                Button("Pollution Map") { store.overlay = .pollution }
            }
        }
    }

    private var employmentSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeader(.employment, detail: "Commercial and industrial buildings create the jobs that support population growth.")
            InspectorRow(label: "Jobs filled", value: store.state.jobs.formatted())
            InspectorRow(label: "Job capacity", value: store.analytics.jobCapacity.formatted())
            InspectorRow(label: "Target employment", value: (store.state.population * 7 / 10).formatted())
            InspectorRow(label: "Employment coverage", value: (store.analytics.employmentRate * 100).percentText)
            InspectorRow(label: "Commercial buildings", value: store.analytics.count(.commercial).formatted())
            InspectorRow(label: "Industrial buildings", value: store.analytics.count(.industrial).formatted())
            HStack {
                Button("Build Commercial") { store.selectTool(.commercial) }
                Button("Build Industrial") { store.selectTool(.industrial) }
            }
        }
    }

    private var demandSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(.demand, detail: "Demand measures how strongly each development type can be absorbed right now.")
            DemandInspectorRow(title: "Residential", value: store.state.demand.residential, tint: .cyan) { store.selectTool(.residential) }
            DemandInspectorRow(title: "Commercial", value: store.state.demand.commercial, tint: .purple) { store.selectTool(.commercial) }
            DemandInspectorRow(title: "Industrial", value: store.state.demand.industrial, tint: .orange) { store.selectTool(.industrial) }
            Text("High demand is an opportunity, not a guarantee: construction still needs funding, road access, utilities, and enough workers or housing.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var utilitySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeader(.utilities, detail: "Power and water capacity must stay ahead of citywide consumption.")
            capacityRow("Power", symbol: "bolt.fill", used: store.state.powerUsed, capacity: store.state.powerCapacity, tint: .yellow)
            capacityRow("Water", symbol: "drop.fill", used: store.state.waterUsed, capacity: store.state.waterCapacity, tint: .blue)
            InspectorRow(label: "Combined coverage", value: (store.analytics.utilityCoverage * 100).percentText)
            HStack {
                Button("Build Power") { store.selectTool(.powerPlant) }
                Button("Build Water") { store.selectTool(.waterTower) }
                Button("Utility Map") { store.overlay = .utilities }
            }
        }
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(.journal, detail: "Review city events, follow their related data, or dismiss resolved notices.")
            if store.state.messages.isEmpty {
                ContentUnavailableView("No City Events", systemImage: "checkmark.circle", description: Text("New events will appear as the simulation advances."))
            }
            ForEach(store.state.messages) { message in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(message.title).font(.callout.weight(.semibold))
                        Spacer()
                        Text("Day \(message.tick / 4 + 1)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(message.detail).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Open Related Data") { store.openMessage(message) }
                        Spacer()
                        Button("Dismiss") { store.dismissMessage(message.id) }.buttonStyle(.link)
                    }
                }
                .padding(10)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func sectionHeader(_ section: InspectorSection, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(section.title, systemImage: section.symbol).font(.title2.bold())
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func capacityRow(_ title: String, symbol: String, used: Int, capacity: Int, tint: Color) -> some View {
        VStack(spacing: 5) {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Text("\(used.formatted()) / \(capacity.formatted())").monospacedDigit().foregroundStyle(.secondary)
            }
            ProgressView(value: Double(used), total: Double(max(1, capacity)))
                .tint(used > capacity ? GameTheme.danger : tint)
        }
    }
}

private struct InspectorRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }
}

private struct DemandInspectorRow: View {
    let title: String
    let value: Double
    let tint: Color
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.callout.weight(.semibold))
                Spacer()
                Text((value * 100).percentText).monospacedDigit()
            }
            ProgressView(value: value).tint(tint)
            Button("Select \(title) Tool", action: action).buttonStyle(.link)
        }
    }
}
