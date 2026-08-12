import SwiftUI

struct CommandGuideView: View {
    @ObservedObject var store: CityGameStore
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var matchingDescriptors: [CityCommandDescriptor] {
        CityCommandCatalog.matchingDescriptors(query: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(CityCommandCategory.allCases) { category in
                        let commands = matchingDescriptors.filter { $0.category == category }
                        if !commands.isEmpty {
                            commandSection(category, commands: commands)
                        }
                    }
                    if matchingDescriptors.isEmpty {
                        ContentUnavailableView.search(text: query)
                            .frame(maxWidth: .infinity, minHeight: 220)
                    }
                }
                .padding(18)
            }
            .scrollIndicators(.visible)
            .focusable()
            .accessibilityLabel("Searchable CitySim command catalog")
        }
        .frame(minWidth: 620, idealWidth: 760, maxWidth: 860, minHeight: 480, idealHeight: 560, maxHeight: 680)
        .cityPanelBackground(.regular, in: Rectangle())
        .onAppear {
            query = ""
            DispatchQueue.main.async { searchFocused = true }
        }
        .onExitCommand { store.perform(.cancelInteraction) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("CitySim command guide")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("COMMAND GUIDE", systemImage: "command.square.fill")
                        .font(.title2.bold())
                    Text("Search the entire command deck, see focus rules, and execute available non-spatial actions.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { store.perform(.cancelInteraction) } label: {
                    Label("Close", systemImage: "xmark")
                        .frame(minHeight: GameTheme.controlMinimum)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close command guide")
            }
            TextField("Search commands, shortcuts, and outcomes", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .accessibilityLabel("Search CitySim commands")
        }
        .padding(18)
    }

    private func commandSection(
        _ category: CityCommandCategory,
        commands: [CityCommandDescriptor]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.rawValue.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            ForEach(commands) { descriptor in
                CommandGuideRow(
                    store: store,
                    descriptor: descriptor,
                    isSoleSearchResult: !query.isEmpty && matchingDescriptors.count == 1
                )
            }
        }
    }
}

private struct CommandGuideRow: View {
    @ObservedObject var store: CityGameStore
    let descriptor: CityCommandDescriptor
    let isSoleSearchResult: Bool

    @ViewBuilder
    var body: some View {
        if descriptor.route == .store && !descriptor.isSpatial {
            Button { store.performFromCommandGuide(descriptor.id) } label: {
                rowContent
            }
            .buttonStyle(.plain)
            .disabled(!store.canPerform(descriptor.id))
            .keyboardShortcut(isSoleSearchResult ? .defaultAction : nil)
            .modifier(CommandGuideRowChrome(isAvailable: store.canPerform(descriptor.id)))
            .accessibilityLabel(descriptor.title)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(descriptor.discoverability)
        } else {
            rowContent
                .modifier(CommandGuideRowChrome(isAvailable: false))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(descriptor.title)
                .accessibilityValue(accessibilityValue)
                .accessibilityHint(descriptor.discoverability)
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(descriptor.title)
                    .font(.callout.weight(.semibold))
                Text(descriptor.discoverability)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let reason = store.disabledReason(for: descriptor.id) {
                    Label(reason, systemImage: "info.circle")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let shortcut = descriptor.shortcut {
                Text(shortcut.display)
                    .font(.callout.weight(.semibold).monospaced())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 7))
                    .accessibilityLabel("Shortcut \(shortcut.display)")
            } else {
                Text("Focus route")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private var accessibilityValue: String {
        var values: [String] = []
        if let shortcut = descriptor.shortcut { values.append("Shortcut \(shortcut.display)") }
        if let reason = store.disabledReason(for: descriptor.id) { values.append("Unavailable: \(reason)") }
        else if descriptor.route == .store && !descriptor.isSpatial { values.append("Available") }
        return values.joined(separator: ". ")
    }
}

private struct CommandGuideRowChrome: ViewModifier {
    let isAvailable: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(GameTheme.contextCard, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isAvailable ? GameTheme.panelStroke : GameTheme.subtleDivider)
            )
    }
}
