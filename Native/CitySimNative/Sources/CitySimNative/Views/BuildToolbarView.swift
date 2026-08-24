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

    // The low command rail is the only persistent map inset. Details are a
    // bounded contextual surface above it, so a selection never reserves city
    // height until the player explicitly asks to inspect it.
    static let compactClosedMaximumHeight: CGFloat = 60
    static let compactBuildDecisionMaximumHeight: CGFloat = 112
    static let regularClosedMaximumHeight: CGFloat = 60
    static let regularSituationalMaximumHeight: CGFloat = 60
    static let compactOpenMaximumHeight: CGFloat = 176
    static let regularOpenMaximumHeight: CGFloat = 208
    static let compactDetailsMaxHeight: CGFloat = 112
    static let regularDetailsMaxHeight: CGFloat = 144

    var body: some View {
        VStack(spacing: compact ? 5 : 6) {
            commandRow
            if let decision = activeBuildDecision {
                buildDecisionRow(decision)
            }
        }
        .padding(compact ? 7 : 8)
        .frame(height: persistentDeckHeight)
        .cityPanelBackground(.thin, in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous))
        .background(
            GameTheme.hudSurfaceFill,
            in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: GameTheme.panelRadius).stroke(GameTheme.strongPanelStroke))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.showInspector ? "City command deck with details open" : "City command deck")
        .overlay(alignment: .bottom) {
            if store.showInspector {
                inspectorDetails
                    .frame(maxWidth: compact ? 620 : 760)
                    .padding(8)
                    .cityPanelBackground(
                        .thick,
                        in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
                    )
                    .background(
                        GameTheme.hudSurfaceFill,
                        in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: GameTheme.panelRadius)
                            .stroke(GameTheme.strongPanelStroke)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 14, y: 5)
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
            height: compact ? Self.compactDetailsMaxHeight : Self.regularDetailsMaxHeight,
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
            modeCluster

            if isBuildMode {
                buildCatalogMenu
            }

            if activeBuildDecision == nil, store.selectedTile != nil || isBuildMode {
                selectedToolSummary
                    .frame(
                        minWidth: compact ? 150 : 174,
                        maxWidth: compact ? 184 : 220,
                        alignment: .trailing
                    )
                    .layoutPriority(1)
            }

            toolsMenu
            commandGuideButton
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
        .padding(2)
        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 11))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map tools")
    }

    private var toolsMenu: some View {
        Menu {
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
        } label: {
            Label(compact ? "More" : "City Tools", systemImage: "slider.horizontal.3")
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
                .padding(.horizontal, compact ? 4 : 8)
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
        }
        .menuStyle(.borderlessButton)
        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 9))
        .accessibilityLabel("City tools and map layers")
        .accessibilityValue("Current layer \(store.overlay.title)")
        .accessibilityIdentifier("hud.city.tools")
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

    private func buildDecisionRow(_ decision: CityBuildDecisionPresentation) -> some View {
        HStack(spacing: compact ? 8 : 12) {
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
                    decision.availability.uppercased(),
                    systemImage: decision.disabledReason == nil
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill"
                )
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded))
                .foregroundStyle(decision.disabledReason == nil ? GameTheme.accent : GameTheme.warning)
                .lineLimit(1)

                Text(decision.disabledReason ?? decision.operatingImpact)
                    .font(.system(size: GameTheme.hudCriticalTextSize - 1, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if decision.disabledReason != nil {
                    Text("Likely: \(decision.likelyConsequence)")
                        .font(.system(size: GameTheme.hudCriticalTextSize - 1, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(decision.likelyConsequence)
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
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
                .padding(.horizontal, 8)
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(store.showInspector ? Color.black : Color.primary)
        .background(store.showInspector ? GameTheme.accent : GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 9))
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
        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 9))
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
            unlimitedFunds: store.state.usesUnlimitedFunds
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

    static func targetBeaconPresentation(
        interactionMode: CityInteractionMode,
        selectedTile: CityTile?,
        target: CityMapActionTargetPresentation?,
        unlimitedFunds: Bool = false
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
                let detail = unlimitedFunds
                    ? "COST WAIVED · choose block for forecast"
                    : "\(kind.buildCost.currencyText) · choose block for forecast"
                let accessibilityValue = unlimitedFunds
                    ? "Selected \(kind.title). Spending is waived. Choose a block for the tracked operating forecast."
                    : "Selected \(kind.title). Cost \(kind.buildCost.currencyText). Choose a block for the authoritative operating forecast."
                return TargetBeaconPresentation(
                    title: kind.title,
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
                                "\(kind.title) · \(kind.buildCost.currencyText) · forecast at block",
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
