import SwiftUI

struct CityHandbookView: View {
    let presentation: CityHandbookPresentation
    let closeAction: () -> Void

    @State private var query = ""
    @State private var selectedSectionID: CityHandbookSectionID?
    @FocusState private var searchFocused: Bool

    init(
        presentation: CityHandbookPresentation = .standard,
        closeAction: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.closeAction = closeAction
    }

    private var searchResult: CityHandbookSearchResult {
        presentation.search(query: query, sectionID: selectedSectionID)
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 1_050 || proxy.size.height < 700
            VStack(spacing: 0) {
                header(compact: compact)
                Divider()
                HStack(spacing: 0) {
                    sidebar(compact: compact)
                    Divider()
                    detail(compact: compact)
                }
            }
            .cityPanelBackground(.regular, in: Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous)
                    .stroke(GameTheme.strongPanelStroke)
            )
            .shadow(color: .black.opacity(0.32), radius: 28, y: 14)
            .padding(compact ? 14 : 22)
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            DispatchQueue.main.async { searchFocused = true }
        }
        .onExitCommand(perform: close)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(presentation.accessibilitySummary)
        .accessibilityIdentifier("city-handbook")
    }

    func close() {
        closeAction()
    }

    private func header(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: compact ? 25 : 30, weight: .semibold))
                    .foregroundStyle(GameTheme.accent.gradient)
                    .frame(width: compact ? 42 : 48, height: compact ? 42 : 48)
                    .background(GameTheme.accent.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.title)
                        .font(.system(size: compact ? 23 : 28, weight: .heavy, design: .rounded))
                    Text(presentation.subtitle)
                        .font(compact ? .caption : .callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 12)
                Button(action: close) {
                    Label("Close", systemImage: "xmark")
                        .frame(minHeight: GameTheme.controlMinimum)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close City Handbook")
                .accessibilityHint("Returns to the city")
                .accessibilityIdentifier("city-handbook.close")
            }

            HStack(spacing: 12) {
                TextField("Search topics, problems, saves, or shortcuts", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                    .accessibilityLabel("Search the City Handbook")
                    .accessibilityHint("Matches section titles, summaries, keywords, and guidance items")
                    .accessibilityIdentifier("city-handbook.search")
                Text(searchResult.countSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(searchResult.isEmpty ? GameTheme.warning : Color.secondary)
                    .frame(minWidth: compact ? 112 : 132, alignment: .trailing)
                    .accessibilityIdentifier("city-handbook.result-count")
            }
        }
        .padding(compact ? 16 : 20)
    }

    private func sidebar(compact: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("HANDBOOK")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)

                sidebarButton(
                    title: "All Topics",
                    detail: "\(presentation.sections.count) sections",
                    symbol: "square.grid.2x2.fill",
                    isSelected: selectedSectionID == nil,
                    identifier: "city-handbook.sidebar.all"
                ) {
                    selectedSectionID = nil
                }

                ForEach(presentation.sections) { section in
                    sidebarButton(
                        title: section.title,
                        detail: "\(section.entries.count) " + (section.entries.count == 1 ? "item" : "items"),
                        symbol: section.symbol,
                        isSelected: selectedSectionID == section.id,
                        identifier: "city-handbook.sidebar.\(section.id.rawValue)"
                    ) {
                        selectedSectionID = section.id
                    }
                    .accessibilityLabel(section.title)
                    .accessibilityValue(section.summary)
                    .accessibilityHint("Filters the handbook to this section")
                }
            }
            .padding(compact ? 10 : 14)
        }
        .frame(width: compact ? 210 : 250)
        .background(GameTheme.hudRaisedFill.opacity(0.45))
        .accessibilityLabel("Handbook sections")
    }

    private func sidebarButton(
        title: String,
        detail: String,
        symbol: String,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isSelected ? GameTheme.accent : GameTheme.information)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                sidebarTitle(title, detail: detail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(
                isSelected ? GameTheme.accent.opacity(0.15) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? GameTheme.accent.opacity(0.48) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func sidebarTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .lineLimit(1)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func detail(compact: Bool) -> some View {
        if searchResult.isEmpty {
            ContentUnavailableView(
                CityHandbookSearchResult.noResultTitle,
                systemImage: "text.book.closed.fill",
                description: Text(CityHandbookSearchResult.noResultDetail)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(CityHandbookSearchResult.noResultTitle)
            .accessibilityValue(CityHandbookSearchResult.noResultDetail)
            .accessibilityIdentifier("city-handbook.no-results")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: compact ? 14 : 18) {
                    ForEach(searchResult.sections) { section in
                        sectionCard(section, compact: compact)
                    }
                }
                .padding(compact ? 16 : 22)
            }
            .scrollIndicators(.visible)
            .accessibilityLabel("Handbook guidance results")
            .accessibilityIdentifier("city-handbook.results")
        }
    }

    private func sectionCard(_ section: CityHandbookSection, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 11 : 14) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: section.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(GameTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(GameTheme.accent.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.title)
                        .font(.title3.weight(.bold))
                    Text(section.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(section.entries) { entry in
                handbookEntry(entry, sectionID: section.id, compact: compact)
            }
        }
        .padding(compact ? 14 : 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GameTheme.contextCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GameTheme.panelStroke)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(section.accessibilitySummary)
        .accessibilityIdentifier("city-handbook.section.\(section.id.rawValue)")
    }

    private func handbookEntry(
        _ entry: CityHandbookEntry,
        sectionID: CityHandbookSectionID,
        compact: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: entry.symbol)
                .font(.callout.weight(.semibold))
                .foregroundStyle(GameTheme.information)
                .frame(width: 28, height: 28)
                .background(GameTheme.information.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.title)
                        .font(.callout.weight(.semibold))
                    Spacer(minLength: 8)
                    if let shortcut = entry.shortcut {
                        Text(shortcut)
                            .font(.caption.weight(.semibold).monospaced())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                Text(entry.detail)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(compact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.accessibilitySummary)
        .accessibilityIdentifier("city-handbook.entry.\(sectionID.rawValue).\(entry.id)")
    }
}
