import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    var tint: Color = .primary
    var detail: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    if let detail {
                        Text(detail).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(5)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .frame(minWidth: 108, alignment: .leading)
        .help("Open \(title.lowercased()) details")
    }
}
