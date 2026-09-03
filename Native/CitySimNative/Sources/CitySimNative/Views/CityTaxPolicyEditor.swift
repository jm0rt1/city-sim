import SwiftUI

struct CityTaxPolicyEditor: View {
    @ObservedObject var store: CityGameStore
    let compact: Bool
    let onClose: () -> Void
    @State private var proposedPercent: Double

    init(store: CityGameStore, compact: Bool, initialRate: Double? = nil, onClose: @escaping () -> Void) {
        self.store = store
        self.compact = compact
        self.onClose = onClose
        _proposedPercent = State(initialValue: (initialRate ?? store.state.taxRate) * 100)
    }

    private var preview: CityTaxPolicyPreview {
        .make(in: store.state, proposedRate: proposedPercent.rounded() / 100)
    }

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 16 : 24) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("TAX PREVIEW").font(.caption.weight(.bold)).foregroundStyle(GameTheme.warning)
                    Spacer(minLength: 4)
                    Text("Not applied").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    rateButton(-1, label: "Lower proposed tax by one percentage point", symbol: "minus")
                    Slider(value: $proposedPercent, in: 4...18, step: 1)
                        .accessibilityLabel("Proposed city tax rate")
                        .accessibilityValue(preview.proposedRateText)
                        .accessibilityHint("Previews the operating impact. Policy changes only when you choose Apply.")
                        .accessibilityIdentifier("finance.tax.proposed-rate")
                    rateButton(1, label: "Raise proposed tax by one percentage point", symbol: "plus")
                    Text(preview.proposedRateText)
                        .font(.callout.bold().monospacedDigit())
                        .frame(minWidth: 36, alignment: .trailing)
                }
                Text(preview.tradeoff)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("Cancel", action: onClose)
                        .accessibilityHint("Discards this proposal without changing city policy.")
                        .accessibilityIdentifier("finance.tax.cancel")
                    Button("Apply \(preview.proposedRateText)") {
                        guard preview.canApply else { return }
                        store.setTaxRate(preview.proposedRate)
                        onClose()
                    }
                    .tint(GameTheme.accent)
                    .disabled(!preview.canApply)
                    .accessibilityLabel("Apply \(preview.proposedRateText) city tax")
                    .accessibilityHint("Commits this rate as one undoable city action. No immediate treasury charge.")
                    .accessibilityIdentifier("finance.tax.apply")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(minHeight: 28)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 5) {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                    GridRow {
                        Text("Per cycle").foregroundStyle(.secondary)
                        Text("Now · \(preview.currentRateText)")
                        Text("At \(preview.proposedRateText)")
                    }.font(.caption2.weight(.semibold))
                    comparisonRow("Revenue", preview.currentRevenue.currencyText, preview.proposedRevenue.currencyText)
                    comparisonRow("Upkeep", preview.upkeep.currencyText, preview.upkeep.currencyText)
                    comparisonRow("Net", preview.currentBalance.signedCurrencyText, preview.proposedBalance.signedCurrencyText)
                        .foregroundStyle(preview.proposedBalance >= 0 ? GameTheme.accent : GameTheme.danger)
                }
                .font(.caption.monospacedDigit())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(preview.accessibilitySummary)
                .accessibilityIdentifier("finance.tax.forecast")
                Text("Change \(preview.balanceChange.signedCurrencyText) / cycle")
                    .font(.caption.weight(.semibold).monospacedDigit())
                Text("Current city only; future growth may change results.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(8)
        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 11))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tax policy preview, not applied")
        .accessibilityIdentifier("finance.tax.editor")
        .onChange(of: store.state.taxRate) { _, _ in onClose() }
        .onChange(of: store.state.seed) { _, _ in onClose() }
        .onChange(of: store.state.tick) { old, new in if new < old { onClose() } }
    }

    private func rateButton(_ direction: Int, label: String, symbol: String) -> some View {
        Button {
            proposedPercent = min(18, max(4, proposedPercent.rounded() + Double(direction)))
        } label: {
            Image(systemName: symbol).frame(width: 16, height: 20)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(direction < 0 ? proposedPercent <= 4 : proposedPercent >= 18)
        .accessibilityLabel(label)
        .accessibilityIdentifier(direction < 0 ? "finance.tax.decrease" : "finance.tax.increase")
    }

    private func comparisonRow(_ label: String, _ current: String, _ proposed: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(current).frame(maxWidth: .infinity, alignment: .trailing)
            Text(proposed).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
