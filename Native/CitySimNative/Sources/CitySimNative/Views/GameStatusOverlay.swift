import SwiftUI

struct CityVictoryMetric: Equatable, Identifiable {
    let label: String
    let value: String
    let symbol: String

    var id: String { label }
}

struct CityVictoryStory: Equatable {
    let title: String
    let detail: String
    let symbol: String
}

struct CityVictoryPresentation: Equatable {
    let eyebrow: String
    let title: String
    let summary: String
    let storyHeading: String
    let accessibilityLabel: String
    let metrics: [CityVictoryMetric]
    let strategy: CityVictoryStory?
    let recovery: CityVictoryStory?

    var accessibilitySummary: String {
        let terminalPunctuation = CharacterSet(charactersIn: ".!?")
        return ([eyebrow, title, summary] + metrics.map { "\($0.label): \($0.value)" } +
                [strategy, recovery].compactMap { story in
                    story.map { "\($0.title). \($0.detail)" }
                })
        .map { $0.trimmingCharacters(in: terminalPunctuation) }
        .joined(separator: ". ")
        + "."
    }

    static func make(state: CityGameState, analytics: CityAnalytics) -> CityVictoryPresentation {
        let isRegionalCapital = analytics.regionalCapitalAwarded
        return CityVictoryPresentation(
            eyebrow: isRegionalCapital ? "Regional Capital Recognized" : "Town Charter Secured",
            title: isRegionalCapital
                ? "\(state.cityName) Became a Regional Capital"
                : "\(state.cityName) Earned Its Town Charter",
            summary: isRegionalCapital
                ? "Your \(state.population.formatted()) residents sustained a healthy, growing city through regional pressure and recovery. Regional Capital recognition records the strategy that carried the city forward."
                : "Your \(state.population.formatted()) residents sustained a solvent, fully served town. The Charter records how you grew and how you recovered.",
            storyHeading: isRegionalCapital ? "Your Regional Capital Story" : "Your Charter Story",
            accessibilityLabel: isRegionalCapital ? "Regional Capital victory" : "Town Charter victory",
            metrics: [
                CityVictoryMetric(label: "Residents", value: state.population.formatted(), symbol: "person.3.fill"),
                CityVictoryMetric(label: "Treasury", value: state.treasury.currencyText, symbol: "banknote.fill"),
                CityVictoryMetric(
                    label: "Cashflow",
                    value: analytics.projectedBalance.currencyText,
                    symbol: analytics.projectedBalance >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"
                ),
                CityVictoryMetric(
                    label: "Happiness",
                    value: "\(Int(state.happiness.rounded()))%",
                    symbol: "face.smiling.fill"
                )
            ],
            strategy: analytics.committedStrategy.map(CityVictoryStory.strategy),
            recovery: analytics.strategyRecoveryResolution.map(CityVictoryStory.recovery)
        )
    }
}

private extension CityVictoryStory {
    static func strategy(_ strategy: CityStrategy) -> CityVictoryStory {
        switch strategy {
        case .commercialStewardship:
            CityVictoryStory(
                title: "Commercial Stewardship",
                detail: "Main Street led the city’s growth, balancing storefront opportunity with utility and treasury discipline.",
                symbol: "storefront.fill"
            )
        case .industrialExpansion:
            CityVictoryStory(
                title: "Industrial Expansion",
                detail: "Freight and industry led the city’s growth, creating jobs while demanding deliberate utility and livability choices.",
                symbol: "building.2.fill"
            )
        }
    }

    static func recovery(_ resolution: CityStrategyRecoveryResolution) -> CityVictoryStory {
        switch resolution {
        case .commercialTaxRelief:
            CityVictoryStory(
                title: "Recovery · Temporary Tax Relief",
                detail: "Tax relief brought customers back and stabilized local shops, trading near-term revenue for renewed confidence.",
                symbol: "percent"
            )
        case .commercialPublicRealmInvestment:
            CityVictoryStory(
                title: "Recovery · Public Realm Investment",
                detail: "A new park restored foot traffic without sacrificing the tax base, turning public space into a Main Street rebound.",
                symbol: "tree.fill"
            )
        case .industrialUtilityExpansion:
            CityVictoryStory(
                title: "Recovery · Utility Expansion",
                detail: "Power and water reserves absorbed the freight surge, protecting reliable factories and the regional contract.",
                symbol: "bolt.horizontal.fill"
            )
        case .industrialGreenBuffer:
            CityVictoryStory(
                title: "Recovery · Green Buffer",
                detail: "A new green buffer won neighborhood support while industry retained its contract and recovered livability.",
                symbol: "leaf.fill"
            )
        }
    }
}

struct GameStatusOverlay: View {
    private enum ReplayFocus: Hashable {
        case newRegion
        case loadQuicksave
    }

    @ObservedObject var store: CityGameStore
    @FocusState private var replayFocus: ReplayFocus?
    @State private var replayTransitionStarted = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 1_100 || proxy.size.height < 700
            ZStack {
                Color.black.opacity(0.66)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())

                VStack(spacing: compact ? 12 : 18) {
                    statusHeader(compact: compact)

                    ScrollView {
                        if store.state.status == .won {
                            victoryContent(compact: compact)
                        } else {
                            lossContent
                        }
                    }
                    .scrollIndicators(.visible)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    actionBar(compact: compact)
                }
                .padding(compact ? 22 : 32)
                .frame(
                    width: min(compact ? 720 : 780, max(520, proxy.size.width - 32)),
                    height: min(compact ? 560 : 620, max(440, proxy.size.height - 32))
                )
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.16)))
                .shadow(color: .black.opacity(0.45), radius: 36, y: 18)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(blockingAccessibilityLabel)
                .accessibilityValue(accessibilitySummary)
            }
        }
        .onAppear {
            replayTransitionStarted = false
            replayFocus = .newRegion
        }
        .onChange(of: store.state.status) { _, _ in
            replayTransitionStarted = false
            replayFocus = .newRegion
        }
        .onExitCommand {
            replayFocus = .newRegion
        }
        .accessibilityIdentifier("game-status.blocking-modal")
    }

    @ViewBuilder
    private func statusHeader(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 10) {
            Image(systemName: store.state.status == .won ? "checkmark.seal.fill" : "exclamationmark.octagon.fill")
                .font(.system(size: compact ? 38 : 50, weight: .bold))
                .foregroundStyle(store.state.status == .won ? GameTheme.warning : GameTheme.danger)
                .accessibilityHidden(true)
            if store.state.status == .won {
                let presentation = CityVictoryPresentation.make(state: store.state, analytics: store.analytics)
                Text(presentation.eyebrow.uppercased())
                    .font(.caption.weight(.black))
                    .tracking(1.4)
                    .foregroundStyle(GameTheme.warning)
                Text(presentation.title)
                    .font(.system(size: compact ? 25 : 31, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
            } else {
                Text("The City Is in Crisis")
                    .font(.system(size: compact ? 25 : 30, weight: .heavy, design: .rounded))
            }
        }
    }

    @ViewBuilder
    private func victoryContent(compact: Bool) -> some View {
        let presentation = CityVictoryPresentation.make(state: store.state, analytics: store.analytics)
        VStack(spacing: compact ? 14 : 18) {
            Text(presentation.summary)
                .font(compact ? .body : .title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 10),
                    count: compact ? 2 : 4
                ),
                spacing: 10
            ) {
                ForEach(presentation.metrics) { metric in
                    HStack(spacing: 8) {
                        Image(systemName: metric.symbol)
                            .foregroundStyle(GameTheme.accent)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(metric.value)
                                .font(.headline.monospacedDigit())
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                }
            }

            if presentation.strategy != nil || presentation.recovery != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Label(presentation.storyHeading, systemImage: "book.closed.fill")
                        .font(.headline)
                        .foregroundStyle(GameTheme.warning)
                    if let strategy = presentation.strategy {
                        storyRow(strategy)
                    }
                    if let recovery = presentation.recovery {
                        storyRow(recovery)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal, 2)
    }

    private var lossContent: some View {
        Text("New Arcadia can no longer meet its obligations. Reconsider the balance between growth, services, and taxation.")
            .font(.title3)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 520)
            .padding(.top, 8)
    }

    private func storyRow(_ story: CityVictoryStory) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: story.symbol)
                .frame(width: 24)
                .foregroundStyle(GameTheme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(story.title).font(.subheadline.weight(.bold))
                Text(story.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func actionBar(compact: Bool) -> some View {
        HStack(spacing: 12) {
            Button("Start a New Region") { startNewRegion() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(GameTheme.accent)
                .keyboardShortcut(.defaultAction)
                .focused($replayFocus, equals: .newRegion)
                .disabled(replayTransitionStarted)
                .accessibilityIdentifier("victory.start-new-region")
                .accessibilityHint("Starts one fresh authored city and closes this result")

            Button("Load Quicksave") { store.perform(.loadCity) }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .focused($replayFocus, equals: .loadQuicksave)
                .disabled(!store.canPerform(.loadCity))
                .accessibilityIdentifier("victory.load-quicksave")
                .accessibilityHint(
                    store.disabledReason(for: .loadCity) ?? "Loads the quicksave and pauses the city"
                )

            if !compact {
                Spacer()
                Text("Return or Space starts a new region")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accessibilitySummary: String {
        if store.state.status == .won {
            return CityVictoryPresentation.make(state: store.state, analytics: store.analytics)
                .accessibilitySummary
        }
        return "New Arcadia can no longer meet its obligations."
    }

    private var blockingAccessibilityLabel: String {
        guard store.state.status == .won else { return "City crisis" }
        return CityVictoryPresentation.make(state: store.state, analytics: store.analytics)
            .accessibilityLabel
    }

    private func startNewRegion() {
        guard !replayTransitionStarted else { return }
        replayTransitionStarted = true
        if !store.perform(.newRegion) {
            replayTransitionStarted = false
        }
    }
}
