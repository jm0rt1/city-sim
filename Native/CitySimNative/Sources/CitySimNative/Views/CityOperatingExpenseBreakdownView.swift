import SwiftUI

struct CityOperatingExpenseBreakdownView: View {
    let presentation: CityOperatingExpensePresentation
    let compact: Bool

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: compact ? 2 : 3),
            spacing: 4
        ) {
            ForEach(presentation.rows) { row in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(row.category.title).lineLimit(1)
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
                .help(row.category.explanation)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.accessibilitySummary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Operating expenses, largest first. \(presentation.totalText). Construction purchases are not recurring upkeep.")
        .accessibilityIdentifier("finance.expense-breakdown")
    }
}
