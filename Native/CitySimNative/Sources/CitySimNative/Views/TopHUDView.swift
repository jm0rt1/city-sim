import SwiftUI

struct TopHUDView: View {
    @ObservedObject var store: CityGameStore

    var body: some View {
        HStack(spacing: 14) {
            Button { store.openInspector(.overview) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(store.state.cityName)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                        Image(systemName: "pencil").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(store.state.formattedDay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 150, alignment: .leading)
            .help("Rename city and open overview")

            Divider().frame(height: 38)
            MetricCard(title: "Treasury", value: store.state.treasury.currencyText,
                       symbol: "dollarsign.circle.fill",
                       tint: store.state.treasury >= 0 ? GameTheme.accent : GameTheme.danger,
                       detail: store.analytics.projectedBalance.currencyText + " / cycle") {
                store.openInspector(.finances)
            }
            MetricCard(title: "Population", value: store.state.population.compactText,
                       symbol: "person.3.fill", tint: .cyan,
                       detail: "\(store.analytics.housingCapacity.formatted()) capacity") {
                store.openInspector(.population)
            }
            MetricCard(title: "Happiness", value: store.state.happiness.percentText,
                       symbol: "face.smiling.fill",
                       tint: store.state.happiness >= 60 ? GameTheme.accent : GameTheme.warning,
                       detail: store.state.approval.percentText + " approval") {
                store.openInspector(.happiness)
            }
            MetricCard(title: "Employment", value: store.state.jobs.compactText,
                       symbol: "briefcase.fill", tint: .purple,
                       detail: (store.analytics.employmentRate * 100).percentText + " filled") {
                store.openInspector(.employment)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                ForEach(SimulationSpeed.allCases) { speed in
                    Button {
                        store.speed = speed
                    } label: {
                        Image(systemName: speed.symbol)
                            .frame(width: 25, height: 25)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(store.speed == speed ? Color.black : Color.primary)
                    .background(store.speed == speed ? GameTheme.accent : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                    .help(speed.title)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.26), radius: 18, y: 8)
    }
}
