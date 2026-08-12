import SwiftUI

struct NewRegionSetupView: View {
    let presentation: CityNewRegionSetupPresentation
    let draft: CityNewRegionDraft
    let updateExperience: (CityNewRegionExperience) -> Void
    let updateCityName: (String) -> Void
    let updateSeed: (String) -> Void
    let updateStartingResources: (CitySandboxStartingResources) -> Void
    let createAction: () -> Void
    let cancelAction: () -> Void
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case cityName
        case seed
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700
            ZStack {
                Color.black.opacity(0.70).ignoresSafeArea()
                VStack(spacing: compact ? 14 : 18) {
                    header(compact: compact)
                    experienceChooser(compact: compact)
                    configurationPanel(compact: compact)
                    actionBar
                }
                .padding(compact ? 22 : 28)
                .frame(width: min(850, max(720, proxy.size.width - 40)))
                .cityPanelBackground(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.15)))
                .shadow(color: .black.opacity(0.45), radius: 36, y: 18)
            }
        }
        .onChange(of: draft.experience) { _, experience in
            focusedField = experience == .openSandbox ? .cityName : nil
        }
        .accessibilityIdentifier("new-region-setup.blocking-modal")
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(GameTheme.accent.opacity(0.16))
                    .frame(width: compact ? 58 : 68, height: compact ? 58 : 68)
                Image(systemName: "map.fill")
                    .font(.system(size: compact ? 28 : 34, weight: .semibold))
                    .foregroundStyle(GameTheme.accent.gradient)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(presentation.title)
                    .font(.system(size: compact ? 25 : 29, weight: .heavy, design: .rounded))
                Text(presentation.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func experienceChooser(compact: Bool) -> some View {
        HStack(spacing: 12) {
            ForEach(CityNewRegionExperience.allCases) { experience in
                Button { updateExperience(experience) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: experience.symbol)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(
                                draft.experience == experience ? GameTheme.accent : .secondary
                            )
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(experience.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(experience.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: draft.experience == experience ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(
                                draft.experience == experience ? GameTheme.accent : .secondary
                            )
                    }
                    .padding(compact ? 12 : 14)
                    .frame(maxWidth: .infinity, minHeight: compact ? 88 : 102, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(draft.experience == experience
                                ? GameTheme.accent.opacity(0.12)
                                : Color.white.opacity(0.035))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(draft.experience == experience
                                ? GameTheme.accent.opacity(0.75)
                                : Color.white.opacity(0.10), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("new-region-setup.\(experience.rawValue)")
                .accessibilityAddTraits(draft.experience == experience ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func configurationPanel(compact: Bool) -> some View {
        Group {
            if draft.experience == .guidedFoundations {
                highlightPanel(
                    title: "Authored opening",
                    symbol: "sparkles",
                    highlights: presentation.guidedHighlights,
                    compact: compact
                )
            } else {
                sandboxConfiguration(compact: compact)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func highlightPanel(
        title: String,
        symbol: String,
        highlights: [String],
        compact: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(GameTheme.accent)
            ForEach(highlights, id: \.self) { highlight in
                Label(highlight, systemImage: "checkmark")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text("Seed \(draft.seedText) · New Arcadia · Day 1")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(compact ? 14 : 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }

    private func sandboxConfiguration(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack(alignment: .top, spacing: 16) {
                labeledField("City name") {
                    TextField(
                        "Example: Harbor Point",
                        text: Binding(get: { draft.cityName }, set: { updateCityName($0) })
                    )
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .cityName)
                    .accessibilityIdentifier("new-region-setup.city-name")
                }
                labeledField("World seed") {
                    TextField(
                        "Whole number",
                        text: Binding(get: { draft.seedText }, set: { updateSeed($0) })
                    )
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .seed)
                    .accessibilityIdentifier("new-region-setup.seed")
                }
                .frame(maxWidth: 250)
            }

            labeledField("Starting resources") {
                Picker(
                    "Starting resources",
                    selection: Binding(
                        get: { draft.startingResources },
                        set: { updateStartingResources($0) }
                    )
                ) {
                    ForEach(CitySandboxStartingResources.allCases) { resources in
                        Text(resources.title).tag(resources)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .accessibilityIdentifier("new-region-setup.resources")
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: draft.validationMessage == nil
                    ? "info.circle.fill"
                    : "exclamationmark.triangle.fill")
                Text(draft.validationMessage ?? draft.startingResources.detail)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text("\(draft.cityName.count)/40")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(draft.validationMessage == nil ? .secondary : GameTheme.warning)

            Divider().overlay(Color.white.opacity(0.10))
            HStack(alignment: .top, spacing: 18) {
                ForEach(presentation.sandboxHighlights, id: \.self) { highlight in
                    Label(highlight, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .padding(compact ? 14 : 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }

    private func labeledField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Text(draft.experience == .guidedFoundations
                ? "Guidance can be revisited in the City Handbook."
                : "The seed makes this start reproducible across new sessions.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", action: cancelAction)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("new-region-setup.cancel")
            Button(draft.experience.actionTitle, action: createAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(GameTheme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(draft.configuration == nil)
                .accessibilityIdentifier("new-region-setup.create")
        }
    }
}
