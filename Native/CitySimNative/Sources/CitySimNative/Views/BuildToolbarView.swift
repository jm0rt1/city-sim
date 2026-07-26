import AppKit
import SwiftUI

@MainActor
final class CityBuildCatalogWindowBindingView: NSView {
    let pointerTransitionGate: CityMapPointerTransitionGate
    private var inputMonitor: Any?

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
        inputMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseUp, .keyDown]
        ) { [weak self] event in
            guard let self else { return event }
            pointerTransitionGate.observeCompactCatalogInput(event, controlView: self)
            return event
        }
    }

    private func stopMonitoring() {
        guard let inputMonitor else { return }
        NSEvent.removeMonitor(inputMonitor)
        self.inputMonitor = nil
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

    // The low command rail preserves the world aperture; details remain
    // reachable in a visibly scrolling region instead of growing over the map.
    static let compactClosedMaximumHeight: CGFloat = 64
    static let compactBuildDecisionMaximumHeight: CGFloat = 118
    static let regularClosedMaximumHeight: CGFloat = 108
    static let regularSituationalMaximumHeight: CGFloat = 64
    static let compactOpenMaximumHeight: CGFloat = 176
    static let regularOpenMaximumHeight: CGFloat = 208
    static let compactDetailsMaxHeight: CGFloat = 112
    static let regularDetailsMaxHeight: CGFloat = 144

    var body: some View {
        VStack(spacing: compact ? 5 : 6) {
            commandRow
            if store.showInspector {
                inspectorDetails
            } else if let decision = activeBuildDecision {
                buildDecisionRow(decision)
            } else if !compact, isBuildMode {
                operationalRow
            }
        }
        .padding(compact ? 7 : 8)
        .frame(
            maxHeight: store.showInspector
                ? (compact ? Self.compactOpenMaximumHeight : Self.regularOpenMaximumHeight)
                : Self.closedMaximumHeight(
                    compact: compact,
                    isBuildMode: isBuildMode,
                    hasBuildDecision: activeBuildDecision != nil
                )
        )
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous))
        .background(
            GameTheme.hudSurfaceFill,
            in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: GameTheme.panelRadius).stroke(GameTheme.strongPanelStroke))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.showInspector ? "City command deck with details open" : "City command deck")
    }

    private var inspectorDetails: some View {
        ScrollView(.vertical) {
            InspectorView(store: store, compact: compact)
                .padding(.trailing, 6)
        }
        .scrollIndicators(.visible)
        .frame(
            maxHeight: compact ? Self.compactDetailsMaxHeight : Self.regularDetailsMaxHeight,
            alignment: .top
        )
        .focusable()
        .accessibilityLabel("Scrollable command-center details")
        .accessibilityHint("Use the scroll area to reach every diagnostic control")
        .accessibilityIdentifier("hud.command.details.scroll")
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

            if !store.showInspector, activeBuildDecision == nil {
                selectedToolSummary
                    .frame(maxWidth: compact ? 184 : 260, alignment: .trailing)
            }

            Spacer(minLength: 2)
            cityFocusButton
            commandGuideButton
            detailsButton
            OverlayPickerView(store: store, compact: compact)
        }
    }

    static func closedMaximumHeight(
        compact: Bool,
        isBuildMode: Bool,
        hasBuildDecision: Bool = false
    ) -> CGFloat {
        if compact {
            return hasBuildDecision ? compactBuildDecisionMaximumHeight : compactClosedMaximumHeight
        }
        return isBuildMode ? regularClosedMaximumHeight : regularSituationalMaximumHeight
    }

    private func buildDecisionRow(_ decision: CityBuildDecisionPresentation) -> some View {
        HStack(spacing: compact ? 8 : 12) {
            VStack(alignment: .leading, spacing: 3) {
                Label("PLACE \(decision.buildingTitle.uppercased())", systemImage: decision.buildingSymbol)
                    .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(GameTheme.accent)
                    .lineLimit(1)
                Text("\(decision.target) · \(decision.footprint) · \(decision.cost)")
                    .font(.system(size: GameTheme.hudCriticalTextSize - 1, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(compact ? 2 : 1)
            }
            .frame(width: compact ? 230 : 280, alignment: .leading)
            .layoutPriority(3)

            Divider().frame(height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Label(
                    decision.availability.uppercased(),
                    systemImage: decision.disabledReason == nil
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill"
                )
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded))
                .foregroundStyle(decision.disabledReason == nil ? GameTheme.accent : GameTheme.warning)
                .lineLimit(1)

                Text(decision.disabledReason ?? decision.likelyConsequence)
                    .font(.system(size: GameTheme.hudCriticalTextSize - 1, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if decision.disabledReason != nil {
                    Text("Likely: \(decision.likelyConsequence)")
                        .font(.system(size: GameTheme.hudCriticalTextSize - 1, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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
                store.perform(.cancelInteraction)
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
        .accessibilityValue(decision.accessibilitySummary)
        .accessibilityIdentifier("hud.build.decision")
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

    @ViewBuilder
    private var selectedToolSummary: some View {
        Group {
            switch store.interactionMode {
            case .inspect:
                if let tile = store.selectedTile {
                    Label(
                        "\(tile.kind.title) · Block \(tile.coordinate.x + 1), \(tile.coordinate.y + 1)",
                        systemImage: "mappin.and.ellipse"
                    )
                    .accessibilityLabel(
                        "Inspecting \(tile.kind.title) at block \(tile.coordinate.x + 1), \(tile.coordinate.y + 1)"
                    )
                } else {
                    Label("Choose a block for details", systemImage: "info.circle")
                        .accessibilityLabel("Inspect mode. Choose a block for details")
                }
            case .bulldoze:
                if let target = store.activeMapActionTargetPresentation {
                    Label(
                        "Block \(target.coordinate.x + 1), \(target.coordinate.y + 1) · "
                            + (target.primaryAction.isAvailable ? "Ready" : "Blocked"),
                        systemImage: target.primaryAction.isAvailable
                            ? "checkmark.circle.fill"
                            : "exclamationmark.triangle.fill"
                    )
                    .accessibilityLabel(target.primaryAction.name)
                    .accessibilityValue(target.primaryAction.disclosure)
                } else {
                    Label("Cost shown on map · Undo available", systemImage: "arrow.uturn.backward.circle")
                        .accessibilityLabel("Bulldoze mode. Demolition cost is shown on the map. Undo is available")
                }
            case .build(let kind):
                if let target = store.activeMapActionTargetPresentation {
                    HStack(spacing: 8) {
                        Label(
                            "Block \(target.coordinate.x + 1), \(target.coordinate.y + 1)",
                            systemImage: "mappin.and.ellipse"
                        )
                        Label(
                            target.primaryAction.isAvailable ? "Ready" : "Blocked",
                            systemImage: target.primaryAction.isAvailable
                                ? "checkmark.circle.fill"
                                : "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(
                            target.primaryAction.isAvailable ? GameTheme.accent : GameTheme.warning
                        )
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(target.primaryAction.name)
                    .accessibilityValue(target.primaryAction.disclosure)
                } else {
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
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .accessibilityIdentifier("hud.selected.context")
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
        .overlay {
            CityBuildCatalogWindowBinder(pointerTransitionGate: pointerTransitionGate)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Open categorized build catalog")
        .accessibilityValue("Selected \(store.selectedTool.title)")
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
