import SwiftUI

struct NewRegionSetupView: View {
    let presentation: CityNewRegionSetupPresentation
    let draft: CityNewRegionDraft
    let updateExperience: (CityNewRegionExperience) -> Void
    let updateScenario: (String) -> Void
    let updateCityName: (String) -> Void
    let updateSeed: (String) -> Void
    let updateStartingResources: (CitySandboxStartingResources) -> Void
    let updateSandboxEconomy: (CitySandboxEconomy) -> Void
    let updateSandboxIncidents: (Bool) -> Void
    let updateSandboxUnlimitedFunds: (Bool) -> Void
    let createAction: () -> Void
    let cancelAction: () -> Void
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case cityName
        case seed
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700
            ZStack {
                Color.black.opacity(0.70).ignoresSafeArea()
                VStack(spacing: compact ? 14 : 18) {
                    header(compact: compact)
                    experienceChooser(compact: compact)
                    configurationPanel(compact: compact)
                    actionBar
                }
                .padding(compact ? 22 : 28)
                .frame(width: min(850, max(720, proxy.size.width - 40)))
                .cityPanelBackground(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.15)))
                .shadow(color: .black.opacity(0.45), radius: 36, y: 18)
            }
        }
        .onChange(of: draft.experience) { _, experience in
            focusedField = experience == .openSandbox ? .cityName : nil
        }
        .accessibilityIdentifier("new-region-setup.blocking-modal")
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(GameTheme.accent.opacity(0.16))
                    .frame(width: compact ? 58 : 68, height: compact ? 58 : 68)
                Image(systemName: "map.fill")
                    .font(.system(size: compact ? 28 : 34, weight: .semibold))
                    .foregroundStyle(GameTheme.accent.gradient)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(presentation.title)
                    .font(.system(size: compact ? 25 : 29, weight: .heavy, design: .rounded))
                Text(presentation.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func experienceChooser(compact: Bool) -> some View {
        HStack(spacing: 12) {
            ForEach(CityNewRegionExperience.allCases) { experience in
                Button { updateExperience(experience) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: experience.symbol)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(
                                draft.experience == experience ? GameTheme.accent : .secondary
                            )
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(experience.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(experience.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: draft.experience == experience ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(
                                draft.experience == experience ? GameTheme.accent : .secondary
                            )
                    }
                    .padding(compact ? 12 : 14)
                    .frame(maxWidth: .infinity, minHeight: compact ? 88 : 102, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(draft.experience == experience
                                ? GameTheme.accent.opacity(0.12)
                                : Color.white.opacity(0.035))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(draft.experience == experience
                                ? GameTheme.accent.opacity(0.75)
                                : Color.white.opacity(0.10), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("new-region-setup.\(experience.rawValue)")
                .accessibilityAddTraits(draft.experience == experience ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func configurationPanel(compact: Bool) -> some View {
        Group {
            switch draft.experience {
            case .guidedFoundations:
                highlightPanel(
                    title: "Authored opening",
                    symbol: "sparkles",
                    highlights: presentation.guidedHighlights,
                    compact: compact
                )
            case .authoredScenario:
                scenarioConfiguration(compact: compact)
            case .openSandbox:
                sandboxConfiguration(compact: compact)
            case .benchmark:
                benchmarkConfiguration(compact: compact)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func benchmarkConfiguration(compact: Bool) -> some View {
        let benchmark = CityBenchmarkDefinition.verticalSlice
        return VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack {
                Label("LOCAL PERFORMANCE CHECK", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.headline)
                    .foregroundStyle(GameTheme.information)
                Spacer()
                Text("Usually under a minute")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(benchmark.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                benchmarkFact("Workload", benchmark.title, symbol: "building.2.fill")
                benchmarkFact("Map", benchmark.citySize, symbol: "square.grid.3x3.fill")
                benchmarkFact("Measurement", "3× average · p95 · 16 ms budget", symbol: "chart.xyaxis.line")
            }
            Label(
                "Runs on a temporary city. It never autosaves, overwrites, or advances your current city.",
                systemImage: "lock.shield.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(GameTheme.accent)
            Text(benchmark.qualification)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(compact ? 14 : 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }

    private func benchmarkFact(_ label: String, _ value: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(GameTheme.information)
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
    }

    private func scenarioConfiguration(compact: Bool) -> some View {
        let scenario = draft.selectedScenario ?? CityAuthoredScenarioCatalog.harborRecovery
        return VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 8) {
                ForEach(CityAuthoredScenarioCatalog.all) { option in
                    Button { updateScenario(option.id) } label: {
                        HStack(spacing: 7) {
                            Image(systemName: option.kind == .waterResilience ? "drop.fill" : "lifepreserver.fill")
                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.title)
                                    .font(.caption.weight(.bold))
                                Text(option.cityName)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: scenario.id == option.id ? "checkmark.circle.fill" : "circle")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, compact ? 7 : 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            scenario.id == option.id
                                ? GameTheme.accent.opacity(0.14)
                                : Color.black.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(scenario.id == option.id ? GameTheme.accent.opacity(0.7) : .white.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("new-region-setup.scenario.\(option.id)")
                    .accessibilityAddTraits(scenario.id == option.id ? .isSelected : [])
                }
            }

            HStack {
                Label(scenario.eyebrow, systemImage: "flag.checkered")
                    .font(.headline)
                    .foregroundStyle(GameTheme.warning)
                Spacer()
                Label(scenario.estimatedDuration, systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(scenario.briefing)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Label(scenario.objective, systemImage: "scope")
                .font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 8) {
                ForEach(scenario.targetTiers) { tier in
                    VStack(alignment: .leading, spacing: 3) {
                        Label(tier.medal.title, systemImage: tier.medal.symbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tier.medal == .gold ? GameTheme.warning : GameTheme.accent)
                        Text(tier.requirements)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(tier.deadline)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            if !compact {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(scenario.constraints, id: \.self) { constraint in
                        Label(constraint, systemImage: "checkmark.shield.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            } else {
                Text("Normal costs and crises stay active · Pause is safe · Deadline: Day \(scenario.deadlineDay)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }

    private func highlightPanel(
        title: String,
        symbol: String,
        highlights: [String],
        compact: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(GameTheme.accent)
            ForEach(highlights, id: \.self) { highlight in
                Label(highlight, systemImage: "checkmark")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text("Seed \(draft.seedText) · New Arcadia · Day 1")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(compact ? 14 : 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }

    private func sandboxConfiguration(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack(alignment: .top, spacing: 16) {
                labeledField("City name") {
                    TextField(
                        "Example: Harbor Point",
                        text: Binding(get: { draft.cityName }, set: { updateCityName($0) })
                    )
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .cityName)
                    .accessibilityIdentifier("new-region-setup.city-name")
                }
                labeledField("World seed") {
                    TextField(
                        "Whole number",
                        text: Binding(get: { draft.seedText }, set: { updateSeed($0) })
                    )
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .seed)
                    .accessibilityIdentifier("new-region-setup.seed")
                }
                .frame(maxWidth: 250)
            }

            HStack(alignment: .top, spacing: 16) {
                labeledField(draft.unlimitedFunds ? "Fixed treasury display" : "Starting resources") {
                    Picker(
                        "Starting resources",
                        selection: Binding(
                            get: { draft.startingResources },
                            set: { updateStartingResources($0) }
                        )
                    ) {
                        ForEach(CitySandboxStartingResources.allCases) { resources in
                            Text(resources.title).tag(resources)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .disabled(draft.unlimitedFunds)
                    .accessibilityIdentifier("new-region-setup.resources")
                }

                labeledField("Economy") {
                    Picker(
                        "Economy",
                        selection: Binding(
                            get: { draft.sandboxEconomy },
                            set: { updateSandboxEconomy($0) }
                        )
                    ) {
                        ForEach(CitySandboxEconomy.allCases) { economy in
                            Text(economy.title).tag(economy)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("new-region-setup.economy")
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: draft.validationMessage == nil
                    ? "info.circle.fill"
                    : "exclamationmark.triangle.fill")
                Text(draft.validationMessage ?? sandboxRuleDetail)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text("\(draft.cityName.count)/40")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(draft.validationMessage == nil ? .secondary : GameTheme.warning)

            HStack(spacing: 12) {
                sandboxRuleToggle(
                    title: "City incidents",
                    detail: draft.incidentsEnabled ? "Storms and grants can occur" : "Random incidents are disabled",
                    symbol: draft.incidentsEnabled ? "cloud.bolt.rain.fill" : "cloud.sun.fill",
                    isOn: draft.incidentsEnabled,
                    update: updateSandboxIncidents,
                    identifier: "new-region-setup.incidents"
                )
                sandboxRuleToggle(
                    title: "Unlimited funds",
                    detail: draft.unlimitedFunds ? "Spending is waived; cash stays fixed" : "Construction and operations affect cash",
                    symbol: draft.unlimitedFunds ? "infinity.circle.fill" : "banknote.fill",
                    isOn: draft.unlimitedFunds,
                    update: updateSandboxUnlimitedFunds,
                    identifier: "new-region-setup.unlimited-funds"
                )
            }

            if !compact {
                Divider().overlay(Color.white.opacity(0.10))
                HStack(alignment: .top, spacing: 18) {
                    ForEach(presentation.sandboxHighlights, id: \.self) { highlight in
                        Label(highlight, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
        .padding(compact ? 14 : 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }

    private var sandboxRuleDetail: String {
        let funds = draft.unlimitedFunds
            ? "Treasury remains fixed at \(draft.startingResources.treasury.currencyText)."
            : draft.startingResources.detail
        return "\(draft.sandboxEconomy.detail). \(funds)"
    }

    private func sandboxRuleToggle(
        title: String,
        detail: String,
        symbol: String,
        isOn: Bool,
        update: @escaping (Bool) -> Void,
        identifier: String
    ) -> some View {
        Toggle(
            isOn: Binding(get: { isOn }, set: { update($0) }),
            label: {
                HStack(spacing: 9) {
                    Image(systemName: symbol)
                        .foregroundStyle(isOn ? GameTheme.accent : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.caption.weight(.bold))
                        Text(detail)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        )
        .toggleStyle(.switch)
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 11))
        .accessibilityIdentifier(identifier)
    }

    private func labeledField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Text(supportingFooter)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", action: cancelAction)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("new-region-setup.cancel")
            Button(draft.experience.actionTitle, action: createAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(GameTheme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.canStart)
                .accessibilityIdentifier("new-region-setup.create")
        }
    }

    private var supportingFooter: String {
        switch draft.experience {
        case .guidedFoundations:
            "Guidance can be revisited in the City Handbook."
        case .authoredScenario:
            "The deterministic start, deadline, medal, and outcome persist with the city."
        case .openSandbox:
            "The seed makes this start reproducible across new sessions."
        case .benchmark:
            "The benchmark runs separately; your current city remains untouched."
        }
    }
}
