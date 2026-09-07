import SwiftUI

struct CityOperatingExpenseBreakdownView: View {
    let presentation: CityOperatingExpensePresentation
    let compact: Bool
    var onFindUtility: ((GridCoordinate) -> Void)? = nil
    @State private var showsUtilitySites = false

    var body: some View {
        if showsUtilitySites, let onFindUtility {
            CityUtilityExpenseSitesView(presentation: presentation, compact: compact,
                onBack: { showsUtilitySites = false }, onFind: onFindUtility)
        } else {
            expenseGrid
        }
    }

    private var expenseGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: compact ? 2 : 3),
            spacing: 4
        ) {
            ForEach(presentation.rows) { row in
                if row.category == .utilities, !presentation.utilitySites.isEmpty, onFindUtility != nil {
                    Button { showsUtilitySites = true } label: {
                        expenseRow(row, opensSites: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Review utility operating costs")
                    .accessibilityValue(row.accessibilitySummary)
                    .accessibilityHint("Lists completed facilities and their upkeep shares, largest first. No spending or demolition.")
                    .accessibilityIdentifier("finance.expenses.utilities")
                } else {
                    expenseRow(row, opensSites: false)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Operating expenses, largest first. \(presentation.totalText). Construction purchases are not recurring upkeep.")
        .accessibilityIdentifier("finance.expense-breakdown")
    }

    private func expenseRow(_ row: CityOperatingExpensePresentation.Row, opensSites: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(row.category.title).lineLimit(1)
                if opensSites {
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(GameTheme.accent)
                }
                Spacer(minLength: 2)
                Text(row.amountText).monospacedDigit().lineLimit(1)
            }
            .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                Text(row.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ProgressView(value: row.share)
                    .controlSize(.mini)
                    .tint(GameTheme.warning)
                    .frame(maxWidth: 64)
                    .frame(height: 4)
                    .accessibilityHidden(true)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 6))
        .help(opensSites ? "Review each facility's upkeep share and find it on the map" : row.category.explanation)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilitySummary)
    }
}
