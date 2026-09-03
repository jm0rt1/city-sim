import SwiftUI

struct CityGrowthQueueView: View {
    let queue: CityGrowthQueue
    @Binding var filter: CityGrowthQueue.Filter
    @Binding var page: Int
    let inspect: (GridCoordinate) -> Void

    private var filteredSites: [CityGrowthQueue.Site] { queue.sites(matching: filter) }
    private var lastPage: Int { max(0, (filteredSites.count - 1) / CityGrowthQueue.pageSize) }
    private var currentPage: Int { min(max(0, page), lastPage) }
    private var start: Int { currentPage * CityGrowthQueue.pageSize }
    private var visibleSites: [CityGrowthQueue.Site] {
        Array(filteredSites.dropFirst(start).prefix(CityGrowthQueue.pageSize))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Picker("Growth status", selection: $filter) {
                    ForEach(CityGrowthQueue.Filter.allCases) { status in
                        Text("\(status.title) \(queue.sites(matching: status).count)").tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 380)
                .accessibilityIdentifier("growth.queue.filter")
                Spacer(minLength: 0)
                Text(filter == .held ? "Fewest unmet requirements first" : "Automatic development review")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if visibleSites.isEmpty {
                Text(filter == .all ? "No growable blocks yet. Build homes or workplaces to start the pipeline."
                     : "No \(filter.rawValue) sites. Choose All to review the rest of the city's development.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    .accessibilityIdentifier("growth.queue.empty")
            } else {
                ForEach(visibleSites) { site in
                    Button { inspect(site.coordinate) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Label(site.title, systemImage: site.kind.symbol)
                                    .font(.caption.weight(.bold))
                                Spacer(minLength: 4)
                                Text(site.outlook.statusLabel)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(site.outlook.status == .held ? GameTheme.warning : GameTheme.accent)
                                Image(systemName: "scope").foregroundStyle(GameTheme.information)
                            }
                            Text(site.outlook.payoff)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(GameTheme.information)
                            Text(site.requirementsText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Inspect \(site.kind.title), block \(site.coordinate.x + 1), \(site.coordinate.y + 1)")
                    .accessibilityValue(site.outlook.accessibilitySummary)
                    .accessibilityHint("Opens this block's details and pauses the city. Does not build or upgrade.")
                    .accessibilityIdentifier("growth.queue.site.\(site.coordinate.x).\(site.coordinate.y)")
                }
                HStack(spacing: 10) {
                    Text("Sites \(start + 1)–\(start + visibleSites.count) of \(filteredSites.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("growth.queue.range")
                    Spacer()
                    Button("Previous") { page = currentPage - 1 }
                        .disabled(currentPage == 0)
                        .accessibilityLabel("Previous growth sites")
                        .accessibilityIdentifier("growth.queue.previous")
                    Button("Next") { page = currentPage + 1 }
                        .disabled(currentPage == lastPage)
                        .accessibilityLabel("Next growth sites")
                        .accessibilityIdentifier("growth.queue.next")
                }
                .controlSize(.small)
            }
        }
        .onChange(of: filter) { _, _ in page = 0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Growth queue")
    }
}
