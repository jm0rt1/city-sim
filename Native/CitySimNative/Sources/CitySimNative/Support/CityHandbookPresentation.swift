import Foundation

enum CityHandbookSectionID: String, CaseIterable, Identifiable, Sendable {
    case gettingStarted = "getting-started"
    case buildAndUndo = "build-and-undo"
    case diagnoseCity = "diagnose-city"
    case savesAndRecovery = "saves-and-recovery"
    case keyboardControls = "keyboard-controls"
    case accessibility = "accessibility"

    var id: String { rawValue }
}

struct CityHandbookEntry: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let shortcut: String?
    let keywords: [String]

    init(
        id: String,
        title: String,
        detail: String,
        symbol: String,
        shortcut: String? = nil,
        keywords: [String] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.shortcut = shortcut
        self.keywords = keywords
    }

    var accessibilitySummary: String {
        [title, detail, shortcut.map { "Shortcut \($0)" }]
            .compactMap { $0 }
            .joined(separator: ". ")
    }

    fileprivate func matches(tokens: [String]) -> Bool {
        Self.matches(tokens: tokens, values: [title, detail] + keywords + [shortcut ?? ""])
    }

    fileprivate static func matches(tokens: [String], values: [String]) -> Bool {
        let haystack = values
            .joined(separator: " ")
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
        return tokens.allSatisfy { haystack.contains($0) }
    }

    fileprivate static func contains(phrase: String, values: [String]) -> Bool {
        values.contains { value in
            value.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            ).contains(phrase)
        }
    }
}

struct CityHandbookSection: Identifiable, Equatable, Sendable {
    let id: CityHandbookSectionID
    let title: String
    let summary: String
    let symbol: String
    let keywords: [String]
    let entries: [CityHandbookEntry]

    var accessibilitySummary: String {
        "\(title). \(summary). \(entries.count) guidance items."
    }

    fileprivate func filtered(tokens: [String], phrase: String) -> Self? {
        guard !tokens.isEmpty else { return self }
        let sectionMatches = CityHandbookEntry.contains(
            phrase: phrase,
            values: [title, summary] + keywords
        )
        let matchingEntries = sectionMatches ? entries : entries.filter { $0.matches(tokens: tokens) }
        guard !matchingEntries.isEmpty else { return nil }
        return Self(
            id: id,
            title: title,
            summary: summary,
            symbol: symbol,
            keywords: keywords,
            entries: matchingEntries
        )
    }
}

struct CityHandbookSearchResult: Equatable, Sendable {
    let query: String
    let sections: [CityHandbookSection]

    static let noResultTitle = "No handbook matches"
    static let noResultDetail = "Try a command, city problem, save type, or keyboard shortcut."

    var isEmpty: Bool { sections.isEmpty }
    var entryCount: Int { sections.reduce(0) { $0 + $1.entries.count } }

    var countSummary: String {
        if isEmpty { return "No guidance found" }
        let sectionLabel = sections.count == 1 ? "section" : "sections"
        let entryLabel = entryCount == 1 ? "item" : "items"
        return "\(sections.count) \(sectionLabel) · \(entryCount) \(entryLabel)"
    }
}

struct CityHandbookPresentation: Equatable, Sendable {
    let title: String
    let subtitle: String
    let sections: [CityHandbookSection]

    var accessibilitySummary: String {
        "City Handbook. \(sections.count) sections covering the growth loop, building and undo, diagnostics, saves and recovery, keyboard controls, and accessibility."
    }

    func search(
        query: String,
        sectionID: CityHandbookSectionID? = nil
    ) -> CityHandbookSearchResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = trimmed
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .split(whereSeparator: \Character.isWhitespace)
            .map(String.init)
        let candidates = sectionID.map { selectedID in
            sections.filter { $0.id == selectedID }
        } ?? sections
        return CityHandbookSearchResult(
            query: trimmed,
            sections: candidates.compactMap { $0.filtered(tokens: tokens, phrase: tokens.joined(separator: " ")) }
        )
    }

    static let standard = Self(
        title: "City Handbook",
        subtitle: "Practical answers for building, diagnosing, and protecting your city without leaving the game.",
        sections: [
            CityHandbookSection(
                id: .gettingStarted,
                title: "Getting Started",
                summary: "Use the growth loop to turn a first road into a healthy, resilient neighborhood.",
                symbol: "sparkles",
                keywords: ["growth loop", "new city", "beginner", "objectives", "cashflow"],
                entries: [
                    CityHandbookEntry(
                        id: "start-new-region",
                        title: "Choose guided, scenario, or sandbox play",
                        detail: "New Region offers Guided Foundations, the deterministic Harbor Recovery scenario with a deadline and medal tiers, or Open Sandbox with a custom city name, reproducible seed, and starting resources. The current city is preserved until you create the new start.",
                        symbol: "map.fill",
                        shortcut: "⌘N",
                        keywords: ["mode", "scenario", "harbor recovery", "medal", "sandbox", "seed", "starting resources", "guided", "new region"]
                    ),
                    CityHandbookEntry(
                        id: "start-pause",
                        title: "Pause and read the city",
                        detail: "Start paused. Check the treasury, demand, objectives, and existing services before spending. A short plan is cheaper than an emergency repair.",
                        symbol: "pause.circle.fill",
                        shortcut: "Space",
                        keywords: ["treasury", "budget", "demand", "plan"]
                    ),
                    CityHandbookEntry(
                        id: "start-loop",
                        title: "Follow the growth loop",
                        detail: "Connect roads, provide power and water, zone places for residents and jobs, then add services as demand grows. Keep enough cash for upkeep and the next fix.",
                        symbol: "arrow.triangle.2.circlepath",
                        keywords: ["roads", "utilities", "zones", "services", "residents", "jobs"]
                    ),
                    CityHandbookEntry(
                        id: "start-observe",
                        title: "Run, observe, adjust",
                        detail: "Resume at 1x speed and watch what changes. Use objectives as direction, not as a reason to ignore traffic, utility coverage, happiness, pollution, or cashflow.",
                        symbol: "gauge.with.dots.needle.50percent",
                        shortcut: "1",
                        keywords: ["speed", "simulate", "monitor", "health"]
                    )
                ]
            ),
            CityHandbookSection(
                id: .buildAndUndo,
                title: "Build and Undo",
                summary: "Preview deliberate construction, protect the budget, and reverse the latest supported change.",
                symbol: "hammer.fill",
                keywords: ["construction", "bulldoze", "demolition", "cost", "preview"],
                entries: [
                    CityHandbookEntry(
                        id: "build-place",
                        title: "Choose, preview, place",
                        detail: "Open a build category, choose a tool, and move the pointer or keyboard selection to a block. Read cost and placement feedback before confirming the build.",
                        symbol: "square.grid.3x3.square",
                        shortcut: "T",
                        keywords: ["tool", "category", "placement", "confirm"]
                    ),
                    CityHandbookEntry(
                        id: "build-undo",
                        title: "Undo Construction",
                        detail: "Undo reverses the latest reversible build or demolition. If Undo is unavailable, no supported construction change is waiting in history.",
                        symbol: "arrow.uturn.backward.circle.fill",
                        shortcut: "⌘Z",
                        keywords: ["history", "reverse", "restore", "mistake"]
                    ),
                    CityHandbookEntry(
                        id: "build-bulldoze",
                        title: "Inspect before demolition",
                        detail: "Inspect the block first, then use Bulldoze only when the consequence and cost are clear. Escape cancels the active tool without changing the city.",
                        symbol: "trash.slash.fill",
                        shortcut: "B",
                        keywords: ["remove", "cancel", "escape"]
                    )
                ]
            ),
            CityHandbookSection(
                id: .diagnoseCity,
                title: "Diagnose City",
                summary: "Combine map overlays with block and city inspectors to move from symptom to cause.",
                symbol: "stethoscope",
                keywords: ["diagnostics", "layers", "command center", "inspector", "problem"],
                entries: [
                    CityHandbookEntry(
                        id: "diagnose-overlays",
                        title: "Read diagnostic overlays",
                        detail: "Switch among Land Value, Traffic Pressure, Utilities, Happiness, and Pollution. The legend explains each scale; select a place to connect the map pattern to local details.",
                        symbol: "square.3.layers.3d.top.filled",
                        shortcut: "⌃1–⌃6",
                        keywords: ["land value", "traffic", "utilities", "happiness", "pollution", "legend"]
                    ),
                    CityHandbookEntry(
                        id: "diagnose-inspect",
                        title: "Inspect a place",
                        detail: "Use Inspect Mode, select a block, and open its context. Local operations, utilities, costs, and consequences help explain why an overlay is warning you.",
                        symbol: "scope",
                        shortcut: "V",
                        keywords: ["block", "place", "local", "context"]
                    ),
                    CityHandbookEntry(
                        id: "diagnose-citywide",
                        title: "Check the Command Center",
                        detail: "Review finances, population, happiness, employment, demand, utilities, and the journal for citywide evidence. Compare more than one signal before acting.",
                        symbol: "rectangle.bottomthird.inset.filled",
                        shortcut: "⌥⌘I",
                        keywords: ["finances", "population", "employment", "demand", "journal", "notices"]
                    )
                ]
            ),
            CityHandbookSection(
                id: .savesAndRecovery,
                title: "Saves and Recovery",
                summary: "Protect progress with manual saves and recover from verified automatic, branch, scenario, or migration copies.",
                symbol: "externaldrive.fill.badge.timemachine",
                keywords: ["checkpoint", "backup", "restore", "timeline", "legacy", "support report"],
                entries: [
                    CityHandbookEntry(
                        id: "save-manual",
                        title: "Make a manual save",
                        detail: "Save before a major expansion or risky repair. CitySim also maintains rotating autosaves and a known-good backup so one bad moment does not have to replace every recovery choice.",
                        symbol: "square.and.arrow.down.fill",
                        shortcut: "⌘S",
                        keywords: ["quicksave", "autosave", "known-good backup", "protect"]
                    ),
                    CityHandbookEntry(
                        id: "save-branches",
                        title: "Create a timeline branch",
                        detail: "A named branch preserves a verified moment without overwriting the current timeline. Use one before trying a different layout, policy, or recovery plan.",
                        symbol: "arrow.triangle.branch",
                        shortcut: "⇧⌘S",
                        keywords: ["named", "fork", "alternate", "experiment"]
                    ),
                    CityHandbookEntry(
                        id: "save-browse",
                        title: "Browse verified checkpoints",
                        detail: "Load City shows manual saves, autosaves, backups, named branches, authored scenario checkpoints, and preserved migration copies. Verification happens before a checkpoint can replace the current city.",
                        symbol: "checkmark.shield.fill",
                        shortcut: "⌘O",
                        keywords: ["load", "scenario", "migration", "upgrade", "integrity"]
                    ),
                    CityHandbookEntry(
                        id: "save-support",
                        title: "Export a support report",
                        detail: "If a recovery file cannot be verified, export its sanitized diagnostic report. The report helps support investigate while the original recovery file remains unchanged.",
                        symbol: "doc.badge.gearshape.fill",
                        keywords: ["invalid", "unreadable", "diagnostic", "sanitized", "unchanged"]
                    )
                ]
            ),
            CityHandbookSection(
                id: .keyboardControls,
                title: "Keyboard Controls",
                summary: "Keep common city actions close while the map remains focused.",
                symbol: "keyboard.fill",
                keywords: ["shortcuts", "keys", "commands", "focus"],
                entries: [
                    CityHandbookEntry(
                        id: "keys-time",
                        title: "Control time",
                        detail: "Space pauses or resumes. Press 1, 2, or 3 for normal, fast, or fastest simulation speed.",
                        symbol: "clock.fill",
                        shortcut: "Space · 1 · 2 · 3",
                        keywords: ["pause", "resume", "speed"]
                    ),
                    CityHandbookEntry(
                        id: "keys-modes",
                        title: "Switch interaction modes",
                        detail: "V enters Inspect, T returns to Build, and B enters Bulldoze. Escape closes the topmost surface first, then cancels the active tool.",
                        symbol: "cursorarrow.motionlines",
                        shortcut: "V · T · B · Esc",
                        keywords: ["inspect", "build", "bulldoze", "cancel", "close"]
                    ),
                    CityHandbookEntry(
                        id: "keys-map",
                        title: "Navigate the map",
                        detail: "Arrow keys move the selected block; Shift-arrow jumps five blocks. Return uses the primary map action, Shift-Return inspects, plus and minus zoom, and 0 frames the developed city.",
                        symbol: "move.3d",
                        shortcut: "Arrows · Return · + / − · 0",
                        keywords: ["selection", "jump", "primary action", "zoom", "frame"]
                    ),
                    CityHandbookEntry(
                        id: "keys-photo-mode",
                        title: "Photograph the city",
                        detail: "Photo Mode pauses safely, clears overlays and gameplay chrome, and keeps zoom and frame controls available. Capture PNG exports only the city composition to Pictures/CitySim; Escape restores the prior speed and workspace.",
                        symbol: "camera.aperture",
                        shortcut: "⇧⌘P · ⇧⌘C",
                        keywords: ["photo mode", "screenshot", "capture", "png", "export", "pictures"]
                    ),
                    CityHandbookEntry(
                        id: "keys-guide",
                        title: "Search every command",
                        detail: "Open the Command Guide for the complete command deck, focus rules, shortcuts, and current availability.",
                        symbol: "command.square.fill",
                        shortcut: "⌘/",
                        keywords: ["command guide", "catalog", "availability"]
                    )
                ]
            ),
            CityHandbookSection(
                id: .accessibility,
                title: "Accessibility",
                summary: "Play with keyboard navigation, VoiceOver-ready descriptions, readable status text, and reduced motion.",
                symbol: "accessibility",
                keywords: ["voiceover", "screen reader", "reduced motion", "labels", "hints", "contrast"],
                entries: [
                    CityHandbookEntry(
                        id: "access-keyboard",
                        title: "Play without precise pointing",
                        detail: "Use keyboard focus, arrow-key map selection, Return actions, shortcuts, and Escape dismissal. Visible controls remain available for the same essential actions.",
                        symbol: "keyboard.badge.ellipsis",
                        keywords: ["motor", "focus", "pointer", "dismissal"]
                    ),
                    CityHandbookEntry(
                        id: "access-voiceover",
                        title: "Use spoken context",
                        detail: "Important controls, map diagnostics, inspector details, and status feedback provide accessible labels, values, and hints for VoiceOver.",
                        symbol: "waveform.circle.fill",
                        keywords: ["spoken", "descriptions", "values", "screen reader"]
                    ),
                    CityHandbookEntry(
                        id: "access-not-color",
                        title: "Read status beyond color",
                        detail: "Warnings and success states pair color with text, symbols, or values. Read the label and legend when colors are difficult to distinguish.",
                        symbol: "circle.lefthalf.filled",
                        keywords: ["color blind", "colour", "symbols", "legend"]
                    ),
                    CityHandbookEntry(
                        id: "access-motion",
                        title: "Reduce ambient motion",
                        detail: "Open Settings and enable Reduce ambient animation to soften nonessential movement while keeping city state and controls available.",
                        symbol: "figure.walk.motion",
                        shortcut: "⌘,",
                        keywords: ["animation", "settings", "motion sensitivity"]
                    )
                ]
            )
        ]
    )
}
