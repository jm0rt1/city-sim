import SwiftUI

/// One capacity-and-reach comparison fits the bounded command panel. The
/// existing store intents still own every map, gap and construction action.
struct CityUtilityDecisionView: View {
    @ObservedObject var store: CityGameStore

    var body: some View {
        let support = CityUtilityDecisionSupport.make(analytics: store.analytics)
        let reach = CityUtilityReachPresentation(state: store.state)
        VStack(alignment: .leading, spacing: 4) {
            planningBar(support: support, reach: reach)
            networkRow(reach.power, used: store.state.powerUsed,
                capacity: store.state.powerCapacity, kind: .powerPlant, tint: .yellow)
            networkRow(reach.water, used: store.state.waterUsed,
                capacity: store.state.waterCapacity, kind: .waterTower, tint: GameTheme.information)
            Text(reach.power.totalBlocks == 0
                ? "Complete development to assess local service."
                : "Local service: completed blocks · weak = strained or severe")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Utility capacity and local service")
        .accessibilityIdentifier("utilities.decision")
    }

    private func planningBar(support: CityUtilityDecisionSupport, reach: CityUtilityReachPresentation) -> some View {
        let priority = reach.priorityWhenCapacityAvailable(support)
        let tint: Color = priority != nil || support.status == .tight ? GameTheme.warning
            : (support.status == .shortfall ? GameTheme.danger : GameTheme.accent)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Label(priority?.planningTitle ?? support.title,
                    systemImage: priority != nil || support.status == .shortfall
                        ? "exclamationmark.octagon.fill" : "gauge.with.dots.needle.67percent")
                    .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold))
                    .foregroundStyle(tint)
                Text(priority?.planningDetail ?? support.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if let priority {
                    action(priority.actionTitle, symbol: "scope") {
                        store.focusUtilityServiceGap(priority.overlay)
                    }
                    .accessibilityValue(priority.accessibilitySummary)
                    .accessibilityHint(gapHint(priority.overlay))
                } else if let response = support.response {
                    action(response.title, symbol: support.priorityKind.symbol) {
                        StrategyCommandCenterView.perform(response, on: store)
                    }
                    .accessibilityHint(response.explanation)
                } else {
                    action("Utility map", symbol: DataOverlay.utilities.symbol) {
                        store.performMapFocused(.overlayUtilities)
                    }
                }
            }
            .frame(width: 164)
            .accessibilityIdentifier("utilities.priority-action")
        }
        .padding(6)
        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 9))
    }

    private func networkRow(_ network: CityUtilityReachPresentation.Network, used: Int,
                            capacity: Int, kind: BuildingKind, tint: Color) -> some View {
        let overlay = network.overlay
        let spare = capacity - used
        return HStack(spacing: 8) {
            Label(overlay.title, systemImage: overlay.symbol)
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 70, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("Use / capacity").font(.caption2).foregroundStyle(.secondary)
                Text("\(used.formatted()) / \(capacity.formatted())")
                    .font(.system(size: GameTheme.hudMetricValueTextSize, weight: .semibold).monospacedDigit())
                ProgressView(value: Double(used), total: Double(max(1, capacity)))
                    .controlSize(.mini)
                    .tint(spare < 0 ? GameTheme.danger : tint)
                    .frame(height: 4)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(overlay.title) citywide capacity")
            .accessibilityValue("\(used) used of \(capacity)")
            VStack(alignment: .leading, spacing: 2) {
                Text(spare < 0 ? "Shortfall" : "Spare").font(.caption2).foregroundStyle(.secondary)
                Text(abs(spare).formatted())
                    .font(.system(size: GameTheme.hudMetricValueTextSize, weight: .semibold).monospacedDigit())
                    .foregroundStyle(spare < 0 ? GameTheme.danger : Color.primary)
            }
            .frame(width: 66, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button {
                store.focusUtilityServiceGap(overlay)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weak blocks").font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(network.countText).monospacedDigit()
                        if network.weakBlocks > 0 { Image(systemName: "scope") }
                    }
                    .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 7))
            .frame(width: 90)
            .disabled(network.weakBlocks == 0)
            .help(network.accessibilitySummary)
            .accessibilityLabel(network.weakBlocks > 0 ? network.actionTitle : "\(overlay.title) local service")
            .accessibilityValue(network.accessibilitySummary)
            .accessibilityHint(network.weakBlocks > 0 ? gapHint(overlay) : "No weak completed blocks to focus")
            .accessibilityIdentifier("utilities.\(overlay.rawValue).gap")
            action("Build \(overlay.title.lowercased())", symbol: kind.symbol) {
                beginConstruction(kind)
            }
            .frame(width: 108)
            .accessibilityIdentifier("utilities.\(overlay.rawValue).build")
            action("\(overlay.title) map", symbol: "map") {
                if store.performMapFocused(CityCommandCatalog.id(for: overlay)) {
                    store.showInspector = false
                }
            }
            .frame(width: 104)
            .accessibilityHint("Shows local \(overlay.title.lowercased()) service without changing the city")
            .accessibilityIdentifier("utilities.\(overlay.rawValue).map")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 9))
    }

    private func action(_ title: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: symbol)
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 7))
    }

    private func gapHint(_ overlay: DataOverlay) -> String {
        "Focuses the weakest completed block on the \(overlay.title) map without changing the city"
    }

    @discardableResult
    func beginConstruction(_ kind: BuildingKind) -> Bool {
        // Citywide capacity planning starts a new-site decision, not a
        // replacement of whichever occupied facility the player inspected.
        guard store.performMapFocused(CityCommandCatalog.id(for: kind)) else { return false }
        store.speed = .paused
        return true
    }
}
