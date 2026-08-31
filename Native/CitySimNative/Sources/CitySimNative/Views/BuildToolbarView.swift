import AppKit
import SwiftUI

@MainActor
final class CityBuildCatalogWindowBindingView: NSView {
    let pointerTransitionGate: CityMapPointerTransitionGate
    private var inputMonitor: Any?
    private weak var trackedCatalogMenu: NSMenu?

    init(pointerTransitionGate: CityMapPointerTransitionGate) {
        self.pointerTransitionGate = pointerTransitionGate
        super.init(frame: .zero)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow !== window {
            stopMonitoring()
            pointerTransitionGate.unbindCompactCatalogWindow(window)
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        pointerTransitionGate.bindCompactCatalogWindow(window)
        startMonitoring()
    }

    func dismantle() {
        stopMonitoring()
        pointerTransitionGate.unbindCompactCatalogWindow(window)
    }

    private func startMonitoring() {
        guard window != nil, inputMonitor == nil else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuDidBeginTracking(_:)),
            name: NSMenu.didBeginTrackingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuDidEndTracking(_:)),
            name: NSMenu.didEndTrackingNotification,
            object: nil
        )
        inputMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseUp, .keyDown]
        ) { [weak self] event in
            guard let self else { return event }
            pointerTransitionGate.observeCompactCatalogInput(event, controlView: self)
            return event
        }
    }

    private func stopMonitoring() {
        if let inputMonitor {
            NSEvent.removeMonitor(inputMonitor)
            self.inputMonitor = nil
        }
        NotificationCenter.default.removeObserver(self)
        trackedCatalogMenu = nil
        pointerTransitionGate.endCompactCatalogTracking()
    }

    @objc
    private func menuDidBeginTracking(_ notification: Notification) {
        guard let menu = notification.object as? NSMenu,
              Self.isBuildCatalogMenu(menu) else { return }
        trackedCatalogMenu = menu
        pointerTransitionGate.beginCompactCatalogTracking()
    }

    @objc
    private func menuDidEndTracking(_ notification: Notification) {
        guard let menu = notification.object as? NSMenu,
              menu === trackedCatalogMenu else { return }
        trackedCatalogMenu = nil
        pointerTransitionGate.endCompactCatalogTracking()
    }

    private static func isBuildCatalogMenu(_ menu: NSMenu) -> Bool {
        BuildingKind.allCases.allSatisfy { kind in
            menu.items.contains { $0.title.hasPrefix("\(kind.title) ·") }
        }
    }
}

@MainActor
struct CityBuildCatalogWindowBinder: NSViewRepresentable {
    let pointerTransitionGate: CityMapPointerTransitionGate

    func makeNSView(context: Context) -> CityBuildCatalogWindowBindingView {
        CityBuildCatalogWindowBindingView(pointerTransitionGate: pointerTransitionGate)
    }

    func updateNSView(_ nsView: CityBuildCatalogWindowBindingView, context: Context) {}

    static func dismantleNSView(
        _ nsView: CityBuildCatalogWindowBindingView,
        coordinator: ()
    ) {
        nsView.dismantle()
    }
}

struct BuildToolbarView: View {
    @ObservedObject var store: CityGameStore
    var compact = false
    let pointerTransitionGate: CityMapPointerTransitionGate

    enum TargetBeaconTone: Equatable {
        case information
        case ready
        case blocked
    }

    struct TargetBeaconPresentation: Equatable {
        let title: String
        let detail: String
        let status: String
        let symbol: String
        let tone: TargetBeaconTone
        let accessibilityLabel: String
        let accessibilityValue: String
        let opensDetails: Bool
    }

    struct DevelopmentDemandPresentation: Equatable {
        let percent: Int
        let level: String

        var summary: String { "\(level) demand \(percent)%" }
        var railSummary: String { "\(level) \(percent)%" }
        var accessibilitySummary: String {
            "\(level) demand, \(percent) percent."
        }
    }

    // The low command rail is the only persistent map inset. Details are a
    // bounded contextual surface above it, so a selection never reserves city
    // height until the player explicitly asks to inspect it.
    static let compactClosedMaximumHeight: CGFloat = 60
    static let compactBuildDecisionMaximumHeight: CGFloat = 112
    static let regularClosedMaximumHeight: CGFloat = 60
    static let regularSituationalMaximumHeight: CGFloat = 60
    static let compactOpenMaximumHeight: CGFloat = 264
    static let regularOpenMaximumHeight: CGFloat = 208
    static let compactDetailsMaxHeight: CGFloat = 196
    static let regularDetailsMaxHeight: CGFloat = 144
    static let compactDetailsWidth: CGFloat = 720
    static let regularDetailsWidth: CGFloat = 840
    static let selectedBlockDetailsHeight: CGFloat = 220

    static func detailsHeight(compact: Bool, selectedBlock: Bool) -> CGFloat {
        selectedBlock ? selectedBlockDetailsHeight
            : (compact ? compactDetailsMaxHeight : regularDetailsMaxHeight)
    }

    var body: some View {
        VStack(spacing: compact ? 5 : 6) {
            commandRow
            if let decision = activeBuildDecision {
                buildDecisionRow(decision)
            }
        }
        .padding(compact ? 7 : 8)
        .frame(height: persistentDeckHeight)
        .cityHUDSurface(prominent: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.showInspector ? "City command deck with details open" : "City command deck")
        .overlay(alignment: .bottom) {
            if store.showInspector {
                inspectorDetails
                    .frame(width: compact ? Self.compactDetailsWidth : Self.regularDetailsWidth)
                    .padding(8)
                    .cityHUDSurface(prominent: true)
                    .offset(y: -persistentDeckHeight - 8)
                    .accessibilityIdentifier("hud.command.details.overlay")
            }
        }
    }

    private var persistentDeckHeight: CGFloat {
        Self.closedMaximumHeight(
            compact: compact,
            isBuildMode: isBuildMode,
            hasBuildDecision: activeBuildDecision != nil
        )
    }

    private var inspectorDetails: some View {
        ScrollView(.vertical) {
            InspectorView(store: store, compact: compact)
                .padding(.trailing, 6)
        }
        .scrollIndicators(.visible)
        .frame(
            height: Self.detailsHeight(
                compact: compact,
                selectedBlock: store.hudContextScope == .selection && store.selectedTile != nil
            ),
            alignment: .top
        )
        .focusable()
        .accessibilityLabel("Scrollable command-center details")
        .accessibilityHint("Use the scroll area to reach every diagnostic control")
        .accessibilityIdentifier("hud.command.details.scroll")
        .transition(.opacity)
    }

    private var commandRow: some View {
        HStack(spacing: compact ? 4 : 6) {
            modeCluster

            if isBuildMode {
                buildCatalogMenu
            }

            if activeBuildDecision == nil, store.selectedTile != nil || isBuildMode {
                selectedToolSummary
                    .frame(
                        minWidth: compact ? 170 : 174,
                        maxWidth: 220,
                        alignment: .trailing
                    )
                    .layoutPriority(1)
            }

            if !compact {
                shelfDivider
            }
            toolsMenu
            if !compact {
                commandGuideButton
            }
            detailsButton
        }
    }

    private var modeCluster: some View {
        HStack(spacing: 2) {
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
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map tools")
    }

    private var toolsMenu: some View {
        let diagnosticLayerIsActive = store.overlay != .none
        return Menu {
            Section("Map layers") {
                ForEach(DataOverlay.allCases) { overlay in
                    Button {
                        store.perform(CityCommandCatalog.id(for: overlay))
                    } label: {
                        Label(overlay.title, systemImage: overlay.symbol)
                    }
                }
            }
            Divider()
            Button { store.perform(.toggleCityFocus) } label: {
                Label("Focus City", systemImage: "viewfinder")
            }
            Button { store.perform(.togglePhotoMode) } label: {
                Label("Photo Mode", systemImage: "camera.aperture")
            }
            if compact {
                Divider()
                Button { store.perform(.openCommandGuide) } label: {
                    Label("Command Guide", systemImage: "command.square")
                }
            }
        } label: {
            Label(
                diagnosticLayerIsActive ? store.overlay.title : (compact ? "More" : "Tools"),
                systemImage: diagnosticLayerIsActive ? store.overlay.symbol : "slider.horizontal.3"
            )
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
                .padding(.horizontal, compact ? 4 : 8)
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("City tools and map layers")
        .accessibilityValue("Current layer \(store.overlay.title)")
        .accessibilityIdentifier("hud.city.tools")
    }

    private var shelfDivider: some View {
        Rectangle()
            .fill(GameTheme.panelStroke)
            .frame(width: 1, height: 24)
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
    }

    static func closedMaximumHeight(
        compact: Bool,
        isBuildMode: Bool,
        hasBuildDecision: Bool = false
    ) -> CGFloat {
        if hasBuildDecision {
            return compact ? compactBuildDecisionMaximumHeight : 112
        }
        return compact ? compactClosedMaximumHeight : regularSituationalMaximumHeight
    }

    static func roadConnectionActionTitle(compact: Bool) -> String {
        compact ? "Build all" : "Build route"
    }

    private func buildDecisionRow(_ decision: CityBuildDecisionPresentation) -> some View {
        let routePlan = store.roadConnectionPlanPresentation
        return HStack(spacing: compact ? 8 : 12) {
            VStack(alignment: .leading, spacing: 3) {
                Label("PLACE \(decision.buildingTitle.uppercased())", systemImage: decision.buildingSymbol)
                    .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(GameTheme.accent)
                    .lineLimit(1)
                Text(compact
                    ? "\(decision.target) · \(decision.cost)"
                    : "\(decision.target) · \(decision.footprint) · \(decision.cost)")
                    .font(.system(size: GameTheme.hudCriticalTextSize - 1, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(compact ? 2 : 1)
            }
            .frame(width: compact ? 205 : 280, alignment: .leading)
            .layoutPriority(3)

            Divider().frame(height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Label(
                    (routePlan == nil
                        ? decision.siteComparison.map {
                            "\(decision.availability) · vs \($0.referenceAbbreviation)"
                        } ?? decision.availability
                        : "\(routePlan?.destinationTitle ?? "Project") route plan").uppercased(),
                    systemImage: decision.disabledReason == nil
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill"
                )
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded))
                .foregroundStyle(decision.disabledReason == nil ? GameTheme.accent : GameTheme.warning)
                .lineLimit(1)

                Text(routePlan?.headline ?? decision.disabledReason ?? decision.operatingImpact)
                    .font(.system(size: GameTheme.hudCriticalTextSize - 1, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let routePlan {
                    Text(routePlan.operatingImpact)
                        .font(.system(size: GameTheme.hudCriticalTextSize - 1, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if decision.disabledReason != nil {
                    Text("Likely: \(decision.likelyConsequence)")
                        .font(.system(size: GameTheme.hudCriticalTextSize - 1, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    if let comparison = decision.siteComparison {
                        siteComparisonRow(comparison)
                    } else {
                        Text(decision.likelyConsequence)
                            .font(.system(size: GameTheme.hudCriticalTextSize - 1, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(2)

            if let recovery = decision.recovery {
                Button {
                    performBuildRecovery(recovery)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.uturn.forward.circle.fill")
                        Text(recovery.title)
                    }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, compact ? 7 : 10)
                        .frame(
                            minWidth: compact ? 86 : 104,
                            minHeight: GameTheme.controlMinimum
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(GameTheme.warning)
                .disabled(!store.canPerform(recovery.command))
                .help(recovery.explanation)
                .accessibilityHint(recovery.explanation)
                .accessibilityIdentifier("hud.build.recovery")
            } else if let routePlan {
                Button {
                    store.buildRoadConnectionPlan()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "point.topleft.down.curvedto.point.bottomright.up.fill")
                        Text(Self.roadConnectionActionTitle(compact: compact))
                    }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, compact ? 7 : 10)
                        .frame(
                            minWidth: compact ? 86 : 104,
                            minHeight: GameTheme.controlMinimum
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(GameTheme.accent)
                .disabled(!store.canBuildRoadConnectionPlan)
                .help(routePlan.buildActionHint)
                .accessibilityLabel("Build planned street route")
                .accessibilityHint(routePlan.buildActionHint)
                .accessibilityIdentifier("hud.build.route")
            } else {
                Button {
                    store.performMapCommand(.mapPrimaryAction)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "hammer.circle.fill")
                        Text("Build here")
                    }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, compact ? 7 : 10)
                        .frame(
                            minWidth: compact ? 86 : 104,
                            minHeight: GameTheme.controlMinimum
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(GameTheme.accent)
                .disabled(!store.canPerformMapCommand(.mapPrimaryAction))
                .help("Commit \(decision.buildingTitle) at \(decision.target) exactly once")
                .accessibilityHint("Uses the same primary map action as Return and the city map action")
                .accessibilityIdentifier("hud.build.commit")
            }

            Button {
                store.cancelBuildDecision()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                    Text("Cancel")
                }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, compact ? 5 : 8)
                    .frame(
                        minWidth: compact ? 64 : 72,
                        minHeight: GameTheme.controlMinimum
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
            .help(decision.cancellation)
            .accessibilityHint(decision.cancellation)
            .accessibilityIdentifier("hud.build.cancel")
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Build decision")
        .accessibilityValue(
            [decision.accessibilitySummary, routePlan?.accessibilitySummary]
                .compactMap { $0 }
                .joined(separator: ". ")
        )
        .accessibilityIdentifier("hud.build.decision")
    }

    private func siteComparisonRow(
        _ comparison: CityDevelopmentSiteComparisonPresentation
    ) -> some View {
        HStack(spacing: compact ? 5 : 7) {
            Text(comparison.capacity)
                .font(.system(size: GameTheme.hudCriticalTextSize - 2, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            siteComparisonMetric(
                compact ? "V" : "Value",
                currentValue: comparison.currentLandValue,
                deltaText: comparison.landValueDeltaText,
                delta: comparison.landValueDelta
            )
            siteComparisonMetric(
                compact ? "U" : "Util",
                currentValue: comparison.currentUtilityService,
                deltaText: comparison.utilityServiceDeltaText,
                delta: comparison.utilityServiceDelta
            )
            siteComparisonMetric(
                compact ? "P" : "Poll",
                currentValue: comparison.currentPollutionExposure,
                deltaText: comparison.pollutionExposureDeltaText,
                delta: comparison.pollutionExposureDelta,
                lowerIsBetter: true
            )
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(comparison.accessibilitySummary)
        .accessibilityIdentifier("hud.build.site-comparison")
    }

    private func siteComparisonMetric(
        _ label: String,
        currentValue: Int,
        deltaText: String,
        delta: Int,
        lowerIsBetter: Bool = false
    ) -> some View {
        Text("\(label) \(currentValue) (\(deltaText))")
            .font(.system(size: GameTheme.hudCriticalTextSize - 2, weight: .bold, design: .rounded))
            .foregroundStyle(siteComparisonColor(delta: delta, lowerIsBetter: lowerIsBetter))
    }

    private func siteComparisonColor(delta: Int, lowerIsBetter: Bool) -> Color {
        guard delta != 0 else { return .secondary }
        let isBetter = lowerIsBetter ? delta < 0 : delta > 0
        return isBetter ? GameTheme.accent : GameTheme.warning
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
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded))
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
        HStack(spacing: 8) {
            Label("INSPECT", systemImage: "cursorarrow.rays")
                .font(.caption.weight(.bold))
                .foregroundStyle(GameTheme.information)
            Spacer(minLength: 6)
            selectedToolSummary
            Text("Arrows move · Shift-Return opens details")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
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
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
                .padding(.horizontal, 8)
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(store.showInspector ? Color.black : Color.primary)
        .background(store.showInspector ? GameTheme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        .help(store.showInspector ? "Close command-center details" : "Open command-center details")
        .accessibilityLabel(store.showInspector ? "Close command-center details" : "Open command-center details")
        .accessibilityValue(store.showInspector ? "Open" : "Closed")
        .accessibilityIdentifier("hud.command.details")
    }

    private var commandGuideButton: some View {
        let descriptor = CityCommandCatalog.descriptor(for: .openCommandGuide)
        return Button { store.perform(.openCommandGuide) } label: {
            Label("Commands", systemImage: "command.square")
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, compact ? 0 : 8)
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(descriptor.discoverability) \(descriptor.shortcut?.display ?? "")")
        .accessibilityLabel("Open command guide")
        .accessibilityValue(descriptor.shortcut?.display ?? "No shortcut")
        .accessibilityIdentifier("hud.command.guide")
    }

    private var cityFocusButton: some View {
        let descriptor = CityCommandCatalog.descriptor(for: .toggleCityFocus)
        return Button { store.perform(.toggleCityFocus) } label: {
            Label(compact ? "Focus" : "Focus City", systemImage: "viewfinder")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, compact ? 2 : 8)
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            CityFocusPointerTransitionMonitor(pointerTransitionGate: pointerTransitionGate)
                .accessibilityHidden(true)
        }
        .help("\(descriptor.discoverability) \(descriptor.shortcut?.display ?? "")")
        .accessibilityLabel("Enter Focus City")
        .accessibilityValue(descriptor.shortcut?.display ?? "No shortcut")
        .accessibilityHint(descriptor.discoverability)
        .accessibilityIdentifier("hud.focus-city.enter")
    }

    private var photoModeButton: some View {
        let descriptor = CityCommandCatalog.descriptor(for: .togglePhotoMode)
        return Button { store.perform(.togglePhotoMode) } label: {
            Label(compact ? "Photo" : "Photo Mode", systemImage: "camera.aperture")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, compact ? 2 : 8)
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
        .help("\(descriptor.discoverability) \(descriptor.shortcut?.display ?? "")")
        .accessibilityLabel("Enter Photo Mode")
        .accessibilityValue(descriptor.shortcut?.display ?? "No shortcut")
        .accessibilityHint("Pauses the simulation and opens distraction-free capture controls")
        .accessibilityIdentifier("hud.photo-mode.enter")
    }

    @ViewBuilder
    private var selectedToolSummary: some View {
        let presentation = Self.targetBeaconPresentation(
            interactionMode: store.interactionMode,
            selectedTile: store.selectedTile,
            target: store.activeMapActionTargetPresentation,
            unlimitedFunds: store.state.usesUnlimitedFunds,
            demand: Self.developmentDemandPresentation(
                for: store.selectedTool,
                in: store.state
            ),
            buildOpportunities: CityBuildOpportunityInventory.make(
                kind: store.selectedTool,
                in: store.state
            )
        )
        if presentation.opensDetails {
            Button {
                Self.activateTargetBeacon(store: store)
            } label: {
                targetBeaconLabel(presentation)
            }
            .buttonStyle(.plain)
            .help("Open Details for the selected target")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.accessibilityLabel)
            .accessibilityValue(presentation.accessibilityValue)
            .accessibilityHint("Opens Details for the selected target")
            .accessibilityIdentifier("hud.selected.context")
        } else {
            targetBeaconLabel(presentation)
                .help(presentation.accessibilityValue)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(presentation.accessibilityLabel)
                .accessibilityValue(presentation.accessibilityValue)
                .accessibilityIdentifier("hud.selected.context")
        }
    }

    private func targetBeaconLabel(_ presentation: TargetBeaconPresentation) -> some View {
        let tint = targetBeaconTint(presentation.tone)
        return HStack(spacing: 7) {
            Image(systemName: presentation.symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 17)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(presentation.title)
                    .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .layoutPriority(1)
                Text(presentation.detail)
                    .font(.system(size: GameTheme.hudSupportTextSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 2)

            if presentation.opensDetails {
                Text(presentation.status)
                    .font(.system(size: GameTheme.hudSupportTextSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(tint.opacity(0.14), in: Capsule())
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum, alignment: .leading)
        .contentShape(Rectangle())
        .background(GameTheme.contextCard.opacity(0.40), in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(presentation.opensDetails ? tint.opacity(0.55) : GameTheme.panelStroke, lineWidth: 1)
        )
    }

    private func targetBeaconTint(_ tone: TargetBeaconTone) -> Color {
        switch tone {
        case .information: GameTheme.information
        case .ready: GameTheme.accent
        case .blocked: GameTheme.warning
        }
    }

    private static func compactRailCurrency(_ amount: Double) -> String {
        let wholeAmount = Int(amount.rounded())
        let thousands = wholeAmount / 1_000
        let hundreds = (wholeAmount % 1_000) / 100
        return hundreds == 0
            ? "$\(thousands)K"
            : "$\(thousands).\(hundreds)K"
    }

    static func targetBeaconPresentation(
        interactionMode: CityInteractionMode,
        selectedTile: CityTile?,
        target: CityMapActionTargetPresentation?,
        unlimitedFunds: Bool = false,
        demand: DevelopmentDemandPresentation? = nil,
        buildOpportunities: CityBuildOpportunityInventory? = nil
    ) -> TargetBeaconPresentation {
        switch interactionMode {
        case .inspect:
            guard let selectedTile else {
                return TargetBeaconPresentation(
                    title: "No block selected",
                    detail: "Choose a block",
                    status: "INSPECT",
                    symbol: CityInteractionMode.inspect.symbol,
                    tone: .information,
                    accessibilityLabel: "Inspect mode",
                    accessibilityValue: "No block selected",
                    opensDetails: false
                )
            }
            let block = "Block \(selectedTile.coordinate.x + 1), \(selectedTile.coordinate.y + 1)"
            return TargetBeaconPresentation(
                title: selectedTile.kind.title,
                detail: block,
                status: "INSPECT",
                symbol: selectedTile.kind.symbol,
                tone: .information,
                accessibilityLabel: "Open details for \(selectedTile.kind.title) at \(block.lowercased())",
                accessibilityValue: target?.primaryAction.disclosure
                    ?? "Available. Opens details for the selected target.",
                opensDetails: true
            )
        case .build(let kind):
            guard let target else {
                let costDetail = unlimitedFunds ? "COST WAIVED" : kind.buildCost.currencyText
                let visibleLegend = buildOpportunities?.visibleStrengthLegend
                let railCostDetail = if unlimitedFunds {
                    "WAIVED"
                } else if kind.buildCost >= 1_000 {
                    Self.compactRailCurrency(kind.buildCost)
                } else {
                    kind.buildCost.currencyText
                }
                let title = if visibleLegend != nil {
                    [kind.title, demand?.railSummary, railCostDetail]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                } else {
                    buildOpportunities?.titleSuffix.map {
                        "\(kind.title) · \($0)"
                    } ?? kind.title
                }
                let detail = if let buildOpportunities, let visibleLegend {
                    [buildOpportunities.detail, visibleLegend]
                        .joined(separator: " · ")
                } else if let buildOpportunities {
                    [
                        buildOpportunities.detail,
                        demand?.summary,
                        costDetail
                    ]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                } else {
                    [demand?.summary, costDetail, "choose block for forecast"]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                }
                let demandAccessibility = demand.map { " \($0.accessibilitySummary)" } ?? ""
                let opportunityAccessibility = buildOpportunities.map {
                    " \($0.accessibilitySummary) Choose an outlined site or any other eligible block for the authoritative operating forecast."
                } ?? " Choose a block for the authoritative operating forecast."
                let accessibilityValue = unlimitedFunds
                    ? "Selected \(kind.title).\(demandAccessibility) Spending is waived.\(opportunityAccessibility)"
                    : "Selected \(kind.title).\(demandAccessibility) Cost \(kind.buildCost.currencyText).\(opportunityAccessibility)"
                return TargetBeaconPresentation(
                    title: title,
                    detail: detail,
                    status: "CHOOSE",
                    symbol: kind.symbol,
                    tone: .information,
                    accessibilityLabel: "Build \(kind.title)",
                    accessibilityValue: accessibilityValue,
                    opensDetails: false
                )
            }
            let isAvailable = target.primaryAction.isAvailable
            let block = "block \(target.coordinate.x + 1), \(target.coordinate.y + 1)"
            return TargetBeaconPresentation(
                title: kind.title,
                detail: "Block \(target.coordinate.x + 1), \(target.coordinate.y + 1)",
                status: isAvailable ? "READY" : "BLOCKED",
                symbol: isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                tone: isAvailable ? .ready : .blocked,
                accessibilityLabel: "Open details for \(kind.title) at \(block)",
                accessibilityValue: target.primaryAction.disclosure,
                opensDetails: selectedTile != nil
            )
        case .bulldoze:
            guard let target else {
                return TargetBeaconPresentation(
                    title: "No structure selected",
                    detail: "Choose a structure",
                    status: "BULLDOZE",
                    symbol: CityInteractionMode.bulldoze.symbol,
                    tone: .information,
                    accessibilityLabel: "Bulldoze mode",
                    accessibilityValue: "Choose a structure. Protected structures and open land remain unavailable.",
                    opensDetails: false
                )
            }
            let isAvailable = target.primaryAction.isAvailable
            let title = selectedTile?.kind.title ?? "Selected block"
            let block = "block \(target.coordinate.x + 1), \(target.coordinate.y + 1)"
            return TargetBeaconPresentation(
                title: title,
                detail: "Block \(target.coordinate.x + 1), \(target.coordinate.y + 1)",
                status: isAvailable ? "READY" : "BLOCKED",
                symbol: isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                tone: isAvailable ? .ready : .blocked,
                accessibilityLabel: "Open details for \(title) at \(block)",
                accessibilityValue: target.primaryAction.disclosure,
                opensDetails: selectedTile != nil
            )
        }
    }

    @MainActor
    @discardableResult
    static func activateTargetBeacon(store: CityGameStore) -> Bool {
        guard store.selectedTile != nil else { return false }
        return store.perform(.toggleCommandCenter)
    }

    private var buildCatalogMenu: some View {
        Menu {
            ForEach(BuildCategory.allCases) { category in
                Section(category.title) {
                    ForEach(category.buildingKinds) { kind in
                        Button {
                            Self.performCompactCatalogSelection(
                                kind,
                                store: store,
                                pointerTransitionGate: pointerTransitionGate,
                                event: NSApp.currentEvent
                            )
                        } label: {
                            Label(
                                Self.buildCatalogItemTitle(for: kind, in: store.state),
                                systemImage: kind.symbol
                            )
                        }
                    }
                }
            }
        } label: {
            Label("Catalog", systemImage: "square.grid.2x2")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, compact ? 6 : 9)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minHeight: GameTheme.controlMinimum)
        }
        .menuStyle(.borderlessButton)
        .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            CityBuildCatalogWindowBinder(pointerTransitionGate: pointerTransitionGate)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Open categorized build catalog")
        .accessibilityValue("Selected \(store.selectedTool.title)")
    }

    static func buildCatalogItemTitle(
        for kind: BuildingKind,
        in state: CityGameState
    ) -> String {
        var facts = [kind.title]
        if let demand = developmentDemandPresentation(for: kind, in: state) {
            facts.append(demand.summary)
        }
        facts.append(kind.buildCost.currencyText)
        facts.append("forecast at block")
        return facts.joined(separator: " · ")
    }

    static func developmentDemandPresentation(
        for kind: BuildingKind,
        in state: CityGameState
    ) -> DevelopmentDemandPresentation? {
        let value: Double
        switch kind {
        case .residential: value = state.demand.residential
        case .commercial: value = state.demand.commercial
        case .industrial: value = state.demand.industrial
        default: return nil
        }

        let bounded = min(max(value, 0), 1)
        let level = if bounded >= 0.67 {
            "High"
        } else if bounded >= 0.34 {
            "Steady"
        } else {
            "Low"
        }
        return DevelopmentDemandPresentation(
            percent: Int((bounded * 100).rounded()),
            level: level
        )
    }

    @discardableResult
    static func performCompactCatalogSelection(
        _ kind: BuildingKind,
        store: CityGameStore,
        pointerTransitionGate: CityMapPointerTransitionGate,
        event: NSEvent?
    ) -> Bool {
        let beganPointerTransition = pointerTransitionGate.beginCompactCatalogSelection(event: event)
        let performed = store.perform(CityCommandCatalog.id(for: kind))
        if beganPointerTransition, !performed {
            pointerTransitionGate.cancel()
        }
        return performed
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, compact ? 7 : 10)
            .frame(minHeight: GameTheme.controlMinimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? Color.black : Color.primary)
        .background(active ? tint : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        .accessibilityLabel("\(title) mode")
        .accessibilityValue(active ? "Selected" : "Not selected")
    }

    private func toolButton(_ kind: BuildingKind) -> some View {
        let active = store.interactionMode == .build(kind)
        let costLabel = store.state.usesUnlimitedFunds ? "COST WAIVED" : kind.buildCost.currencyText
        let help = store.state.usesUnlimitedFunds
            ? "Build \(kind.title) · sandbox spending waived"
            : "Build \(kind.title) · \(kind.buildCost.currencyText) · operating forecast at selected block"
        let accessibilityValue = store.state.usesUnlimitedFunds
            ? "Spending waived; tracked operating forecast appears after choosing a block"
            : "Cost \(kind.buildCost.currencyText); authoritative operating forecast appears after choosing a block"
        return Button { store.perform(CityCommandCatalog.id(for: kind)) } label: {
            HStack(spacing: 7) {
                Image(systemName: active ? "checkmark.circle.fill" : kind.symbol)
                    .font(.system(size: 15, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.title).font(.caption.weight(.semibold)).lineLimit(1)
                    Text(costLabel).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 9)
            .frame(minWidth: 92, minHeight: GameTheme.controlMinimum, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? Color.black : Color.primary)
        .background(active ? GameTheme.accent : GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
        .help(help)
        .accessibilityLabel("Build \(kind.title)")
        .accessibilityValue(accessibilityValue)
    }

    private var isBuildMode: Bool {
        if case .build = store.interactionMode { return true }
        return false
    }

    private var activeBuildDecision: CityBuildDecisionPresentation? {
        guard case .build = store.interactionMode else { return nil }
        return store.activeMapActionTargetPresentation?.primaryAction.buildDecision
    }

    private func performBuildRecovery(_ recovery: CityDirectResponse) {
        store.performBuildRecovery(recovery)
    }

    private var compactModeTitle: String {
        switch store.interactionMode {
        case .inspect: "Inspect mode"
        case .build(let kind): "Build: \(kind.title)"
        case .bulldoze: "Bulldoze mode"
        }
    }

}
