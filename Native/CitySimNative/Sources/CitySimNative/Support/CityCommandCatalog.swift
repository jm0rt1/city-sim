import SwiftUI

enum CityCommandID: String, CaseIterable, Identifiable, Sendable {
    case newRegion = "file.new-region"
    case saveCity = "file.save"
    case loadCity = "file.load"
    case undo = "edit.undo"

    case togglePause = "simulation.toggle-pause"
    case speedNormal = "simulation.speed-1"
    case speedFast = "simulation.speed-2"
    case speedFastest = "simulation.speed-3"

    case inspectMode = "mode.inspect"
    case buildMode = "mode.build"
    case bulldozeMode = "mode.bulldoze"
    case cancelInteraction = "mode.cancel"

    case categoryRoads = "build.category.roads"
    case categoryZones = "build.category.zones"
    case categoryUtilities = "build.category.utilities"
    case categoryServices = "build.category.services"
    case categoryCivic = "build.category.civic"

    case buildRoad = "build.tool.road"
    case buildResidential = "build.tool.residential"
    case buildCommercial = "build.tool.commercial"
    case buildIndustrial = "build.tool.industrial"
    case buildPark = "build.tool.park"
    case buildPowerPlant = "build.tool.power-plant"
    case buildWaterTower = "build.tool.water-tower"
    case buildFireStation = "build.tool.fire-station"
    case buildPoliceStation = "build.tool.police-station"
    case buildSchool = "build.tool.school"
    case buildCityHall = "build.tool.city-hall"

    case overlayCity = "data.overlay.city"
    case overlayLandValue = "data.overlay.land-value"
    case overlayTraffic = "data.overlay.traffic"
    case overlayUtilities = "data.overlay.utilities"
    case overlayHappiness = "data.overlay.happiness"
    case overlayPollution = "data.overlay.pollution"

    case toggleObjectives = "panel.objectives"
    case toggleCommandCenter = "panel.command-center"
    case toggleCityFocus = "panel.focus-city"
    case openNotices = "panel.notices"
    case openCommandGuide = "panel.command-guide"
    case dismissFeedback = "panel.dismiss-feedback"

    case inspectorOverview = "inspector.overview"
    case inspectorFinances = "inspector.finances"
    case inspectorPopulation = "inspector.population"
    case inspectorHappiness = "inspector.happiness"
    case inspectorEmployment = "inspector.employment"
    case inspectorDemand = "inspector.demand"
    case inspectorUtilities = "inspector.utilities"
    case inspectorJournal = "inspector.journal"

    case openSettings = "system.settings"
    case toggleFullScreen = "system.full-screen"

    case cameraZoomIn = "camera.zoom-in"
    case cameraZoomOut = "camera.zoom-out"
    case cameraFrameCity = "camera.frame-city"
    case mapMoveNorth = "map.selection.north"
    case mapMoveEast = "map.selection.east"
    case mapMoveSouth = "map.selection.south"
    case mapMoveWest = "map.selection.west"
    case mapMoveNorthFast = "map.selection.north-fast"
    case mapMoveEastFast = "map.selection.east-fast"
    case mapMoveSouthFast = "map.selection.south-fast"
    case mapMoveWestFast = "map.selection.west-fast"
    case mapPrimaryAction = "map.action.primary"
    case mapSecondaryAction = "map.action.secondary"

    var id: String { rawValue }
}

enum CityCommandCategory: String, CaseIterable, Identifiable, Sendable {
    case files = "File and history"
    case simulation = "Simulation"
    case modes = "Interaction modes"
    case buildCategories = "Build categories"
    case buildTools = "Build tools"
    case overlays = "Data overlays"
    case panels = "Panels and notices"
    case inspectors = "Command Center"
    case system = "Application and window"
    case camera = "Map camera"

    var id: String { rawValue }
}

enum CityCommandRoute: String, Sendable {
    case store
    case renderer
    case system
}

enum CityBlockingModal: String, Equatable, Sendable {
    case welcome
    case startupResume
    case checkpointLibrary
}

enum CityCommandPolicy: Equatable, Sendable {
    case enabled
    case blocked(CityBlockingModal)

    func allows(_ command: CityCommandID) -> Bool {
        switch self {
        case .enabled:
            true
        case .blocked:
            false
        }
    }

    var disabledReason: String? {
        switch self {
        case .enabled:
            nil
        case .blocked(.welcome):
            "Finish Welcome to New Arcadia to use city commands"
        case .blocked(.startupResume):
            "Choose whether to resume the saved city or start fresh"
        case .blocked(.checkpointLibrary):
            "Choose a verified checkpoint or return to the current city"
        }
    }
}

enum CityCommandFocusScope: String, Hashable, Sendable {
    case global
    case gameplay
    case renderer
    case system
}

struct CityCommandModifiers: OptionSet, Hashable, Sendable {
    let rawValue: UInt8

    static let command = Self(rawValue: 1 << 0)
    static let option = Self(rawValue: 1 << 1)
    static let control = Self(rawValue: 1 << 2)
    static let shift = Self(rawValue: 1 << 3)

    var eventModifiers: EventModifiers {
        var result: EventModifiers = []
        if contains(.command) { result.insert(.command) }
        if contains(.option) { result.insert(.option) }
        if contains(.control) { result.insert(.control) }
        if contains(.shift) { result.insert(.shift) }
        return result
    }
}

struct CityCommandShortcut: Hashable, Sendable {
    let key: String
    let modifiers: CityCommandModifiers
    let display: String
    let focusScope: CityCommandFocusScope

    var keyEquivalent: KeyEquivalent? {
        guard key.count == 1, let character = key.first else { return nil }
        return KeyEquivalent(character)
    }
}

struct CityCommandDescriptor: Identifiable, Hashable, Sendable {
    let id: CityCommandID
    let title: String
    let category: CityCommandCategory
    let shortcut: CityCommandShortcut?
    let discoverability: String
    let isSpatial: Bool
    let route: CityCommandRoute
}

enum CityCommandCatalog {
    static let descriptors: [CityCommandDescriptor] = {
        var values: [CityCommandDescriptor] = []

        func shortcut(
            _ key: String,
            _ modifiers: CityCommandModifiers = [],
            _ display: String,
            scope: CityCommandFocusScope
        ) -> CityCommandShortcut {
            CityCommandShortcut(key: key, modifiers: modifiers, display: display, focusScope: scope)
        }

        func add(
            _ id: CityCommandID,
            _ title: String,
            _ category: CityCommandCategory,
            _ discoverability: String,
            shortcut: CityCommandShortcut? = nil,
            isSpatial: Bool = false,
            route: CityCommandRoute = .store
        ) {
            values.append(CityCommandDescriptor(
                id: id,
                title: title,
                category: category,
                shortcut: shortcut,
                discoverability: discoverability,
                isSpatial: isSpatial,
                route: route
            ))
        }

        add(.newRegion, "New Region", .files, "Start a fresh authored city.", shortcut: shortcut("n", [.command], "⌘N", scope: .global))
        add(.saveCity, "Save City", .files, "Save the current city.", shortcut: shortcut("s", [.command], "⌘S", scope: .global))
        add(.loadCity, "Load City", .files, "Browse verified manual and automatic checkpoints.", shortcut: shortcut("o", [.command], "⌘O", scope: .global))
        add(.undo, "Undo Construction", .files, "Undo the latest reversible build or demolition.", shortcut: shortcut("z", [.command], "⌘Z", scope: .global))

        add(.togglePause, "Pause or Resume", .simulation, "Toggle between paused and the last active speed.", shortcut: shortcut(" ", [], "Space", scope: .gameplay))
        add(.speedNormal, "Set 1x Speed", .simulation, "Run the city at normal speed.", shortcut: shortcut("1", [], "1", scope: .gameplay))
        add(.speedFast, "Set 2x Speed", .simulation, "Run the city at fast speed.", shortcut: shortcut("2", [], "2", scope: .gameplay))
        add(.speedFastest, "Set 3x Speed", .simulation, "Run the city at fastest speed.", shortcut: shortcut("3", [], "3", scope: .gameplay))

        add(.inspectMode, "Inspect Mode", .modes, "Read a block without changing it.", shortcut: shortcut("v", [], "V", scope: .gameplay))
        add(.buildMode, "Build Mode", .modes, "Return to the selected construction tool.", shortcut: shortcut("t", [], "T", scope: .gameplay))
        add(.bulldozeMode, "Bulldoze Mode", .modes, "Enter or leave the reversible demolition tool.", shortcut: shortcut("b", [], "B", scope: .gameplay))
        add(.cancelInteraction, "Cancel Current Surface or Tool", .modes, "Close the topmost surface, then cancel the active tool.", shortcut: CityCommandShortcut(key: "escape", modifiers: [], display: "Esc", focusScope: .gameplay))

        for category in BuildCategory.allCases {
            add(
                id(for: category),
                "Open \(category.title)",
                .buildCategories,
                "Open the \(category.title.lowercased()) build category.",
                shortcut: shortcut(String(categoryShortcutNumber(category)), [.shift], "⇧\(categoryShortcutNumber(category))", scope: .gameplay)
            )
        }

        let toolKeys: [BuildingKind: (String, String)] = [
            .road: ("r", "R"), .residential: ("h", "H"), .commercial: ("c", "C"),
            .industrial: ("i", "I"), .park: ("p", "P"), .powerPlant: ("e", "E"),
            .waterTower: ("w", "W"), .fireStation: ("f", "F"), .policeStation: ("l", "L"),
            .school: ("s", "S"), .cityHall: ("g", "G")
        ]
        for kind in BuildingKind.buildPalette {
            let key = toolKeys[kind]!
            add(
                id(for: kind),
                "Build \(kind.title)",
                .buildTools,
                "Select \(kind.title.lowercased()) for placement. Cost \(kind.buildCost.currencyText), upkeep \(kind.upkeep.currencyText) per cycle.",
                shortcut: shortcut(key.0, [], key.1, scope: .gameplay)
            )
        }

        for overlay in DataOverlay.allCases {
            let number = overlayShortcutNumber(overlay)
            add(
                id(for: overlay),
                overlay == .none ? "Clear Data Overlay" : "Show \(overlay.title) Overlay",
                .overlays,
                overlay == .none ? "Return to the normal city view." : "Show \(overlay.title.lowercased()) data on the city.",
                shortcut: shortcut(String(number), [.control], "⌃\(number)", scope: .global)
            )
        }

        add(.toggleObjectives, "Toggle Objectives", .panels, "Open or collapse the current mayoral objectives.", shortcut: shortcut("j", [.command], "⌘J", scope: .global))
        add(.toggleCommandCenter, "Toggle Command Center", .panels, "Open or close contextual city details.", shortcut: shortcut("i", [.command, .option], "⌥⌘I", scope: .global))
        add(.toggleCityFocus, "Toggle Focus City", .panels, "Give the city maximum space while retaining critical operating truth.", shortcut: shortcut("f", [.command, .shift], "⇧⌘F", scope: .global))
        add(.openNotices, "Open City Notices", .panels, "Open the notice journal and related diagnostics.", shortcut: shortcut("a", [.command, .shift], "⇧⌘A", scope: .global))
        add(.openCommandGuide, "Open Command Guide", .panels, "Search every command, shortcut, and availability rule.", shortcut: shortcut("/", [.command], "⌘/", scope: .global))
        add(.dismissFeedback, "Dismiss Action Message", .panels, "Dismiss the transient action message only.", shortcut: shortcut(".", [.command], "⌘.", scope: .global))

        for section in InspectorSection.allCases {
            let number = inspectorShortcutNumber(section)
            let title = inspectorTitle(section)
            add(
                id(for: section),
                "Open \(title)",
                .inspectors,
                "Open \(title.lowercased()) in the Command Center.",
                shortcut: shortcut(String(number), [.option], "⌥\(number)", scope: .global)
            )
        }

        add(.openSettings, "Open Settings", .system, "Use the CitySim application menu to open Settings.", shortcut: shortcut(",", [.command], "⌘,", scope: .system), route: .system)
        add(.toggleFullScreen, "Toggle Full Screen", .system, "Use the Window menu to enter or leave full screen.", shortcut: shortcut("f", [.command, .control], "⌃⌘F", scope: .system), route: .system)

        add(.cameraZoomIn, "Zoom Map In", .camera, "Zoom the focused city map in.", shortcut: shortcut("=", [], "+", scope: .renderer), isSpatial: true, route: .renderer)
        add(.cameraZoomOut, "Zoom Map Out", .camera, "Zoom the focused city map out.", shortcut: shortcut("-", [], "−", scope: .renderer), isSpatial: true, route: .renderer)
        add(.cameraFrameCity, "Frame Developed City", .camera, "Return the focused map to the developed city frame.", shortcut: shortcut("0", [], "0", scope: .renderer), isSpatial: true, route: .renderer)
        add(.mapMoveNorth, "Select Block North", .camera, "Move the focused map selection one block north.", shortcut: shortcut("up", [], "↑", scope: .gameplay), isSpatial: true)
        add(.mapMoveEast, "Select Block East", .camera, "Move the focused map selection one block east.", shortcut: shortcut("right", [], "→", scope: .gameplay), isSpatial: true)
        add(.mapMoveSouth, "Select Block South", .camera, "Move the focused map selection one block south.", shortcut: shortcut("down", [], "↓", scope: .gameplay), isSpatial: true)
        add(.mapMoveWest, "Select Block West", .camera, "Move the focused map selection one block west.", shortcut: shortcut("left", [], "←", scope: .gameplay), isSpatial: true)
        add(.mapMoveNorthFast, "Jump Selection North", .camera, "Move the focused map selection five blocks north.", shortcut: shortcut("up", [.shift], "⇧↑", scope: .gameplay), isSpatial: true)
        add(.mapMoveEastFast, "Jump Selection East", .camera, "Move the focused map selection five blocks east.", shortcut: shortcut("right", [.shift], "⇧→", scope: .gameplay), isSpatial: true)
        add(.mapMoveSouthFast, "Jump Selection South", .camera, "Move the focused map selection five blocks south.", shortcut: shortcut("down", [.shift], "⇧↓", scope: .gameplay), isSpatial: true)
        add(.mapMoveWestFast, "Jump Selection West", .camera, "Move the focused map selection five blocks west.", shortcut: shortcut("left", [.shift], "⇧←", scope: .gameplay), isSpatial: true)
        add(.mapPrimaryAction, "Use Primary Map Action", .camera, "Use the active inspect, build, or bulldoze action on the selected block.", shortcut: shortcut("return", [], "Return", scope: .gameplay), isSpatial: true)
        add(.mapSecondaryAction, "Inspect Selected Block", .camera, "Use the secondary inspect action on the selected block.", shortcut: shortcut("return", [.shift], "⇧Return", scope: .gameplay), isSpatial: true)

        return values
    }()

    static let descriptorByID: [CityCommandID: CityCommandDescriptor] =
        Dictionary(uniqueKeysWithValues: descriptors.map { ($0.id, $0) })

    static func descriptor(for id: CityCommandID) -> CityCommandDescriptor {
        descriptorByID[id]!
    }

    static func descriptors(in category: CityCommandCategory) -> [CityCommandDescriptor] {
        descriptors.filter { $0.category == category }
    }

    static func matchingDescriptors(query: String) -> [CityCommandDescriptor] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return descriptors }
        return descriptors.filter { descriptor in
            let searchableValues = [
                descriptor.title,
                descriptor.category.rawValue,
                descriptor.discoverability,
                descriptor.shortcut?.display ?? "",
                searchAliases[descriptor.id, default: []].joined(separator: " ")
            ]
            return searchableValues.contains { $0.localizedCaseInsensitiveContains(needle) }
        }
    }

    private static let searchAliases: [CityCommandID: [String]] = [
        .inspectorFinances: [
            "tax", "tax policy", "budget", "cashflow", "storefront", "storefront slump", "revenue"
        ]
    ]

    static func matchingCommand(
        key: String,
        modifiers: CityCommandModifiers,
        scope: CityCommandFocusScope
    ) -> CityCommandID? {
        descriptors.first {
            $0.shortcut?.key == key.lowercased()
                && $0.shortcut?.modifiers == modifiers
                && $0.shortcut?.focusScope == scope
        }?.id
    }

    static let mapSelectionCommands: Set<CityCommandID> = [
        .mapMoveNorth, .mapMoveEast, .mapMoveSouth, .mapMoveWest,
        .mapMoveNorthFast, .mapMoveEastFast, .mapMoveSouthFast, .mapMoveWestFast
    ]

    static let mapActionCommands: Set<CityCommandID> = [.mapPrimaryAction, .mapSecondaryAction]

    static var mapFocusedCommands: Set<CityCommandID> {
        mapSelectionCommands.union(mapActionCommands)
    }

    static func id(for speed: SimulationSpeed) -> CityCommandID {
        switch speed {
        case .paused: .togglePause
        case .normal: .speedNormal
        case .fast: .speedFast
        case .fastest: .speedFastest
        }
    }

    static func id(for category: BuildCategory) -> CityCommandID {
        switch category {
        case .roads: .categoryRoads
        case .zones: .categoryZones
        case .utilities: .categoryUtilities
        case .services: .categoryServices
        case .civic: .categoryCivic
        }
    }

    static func id(for kind: BuildingKind) -> CityCommandID {
        switch kind {
        case .road: .buildRoad
        case .residential: .buildResidential
        case .commercial: .buildCommercial
        case .industrial: .buildIndustrial
        case .park: .buildPark
        case .powerPlant: .buildPowerPlant
        case .waterTower: .buildWaterTower
        case .fireStation: .buildFireStation
        case .policeStation: .buildPoliceStation
        case .school: .buildSchool
        case .cityHall: .buildCityHall
        case .empty: preconditionFailure("Open land is not a build palette command")
        }
    }

    static func buildingKind(for id: CityCommandID) -> BuildingKind? {
        BuildingKind.buildPalette.first { self.id(for: $0) == id }
    }

    static func buildCategory(for id: CityCommandID) -> BuildCategory? {
        BuildCategory.allCases.first { self.id(for: $0) == id }
    }

    static func id(for overlay: DataOverlay) -> CityCommandID {
        switch overlay {
        case .none: .overlayCity
        case .landValue: .overlayLandValue
        case .traffic: .overlayTraffic
        case .utilities: .overlayUtilities
        case .happiness: .overlayHappiness
        case .pollution: .overlayPollution
        }
    }

    static func overlay(for id: CityCommandID) -> DataOverlay? {
        DataOverlay.allCases.first { self.id(for: $0) == id }
    }

    static func id(for section: InspectorSection) -> CityCommandID {
        switch section {
        case .overview: .inspectorOverview
        case .finances: .inspectorFinances
        case .population: .inspectorPopulation
        case .happiness: .inspectorHappiness
        case .employment: .inspectorEmployment
        case .demand: .inspectorDemand
        case .utilities: .inspectorUtilities
        case .journal: .inspectorJournal
        }
    }

    static func inspectorSection(for id: CityCommandID) -> InspectorSection? {
        InspectorSection.allCases.first { self.id(for: $0) == id }
    }

    private static func categoryShortcutNumber(_ category: BuildCategory) -> Int {
        BuildCategory.allCases.firstIndex(of: category)! + 1
    }

    private static func overlayShortcutNumber(_ overlay: DataOverlay) -> Int {
        DataOverlay.allCases.firstIndex(of: overlay)!
    }

    private static func inspectorShortcutNumber(_ section: InspectorSection) -> Int {
        InspectorSection.allCases.firstIndex(of: section)! + 1
    }

    private static func inspectorTitle(_ section: InspectorSection) -> String {
        switch section {
        case .overview: "Overview"
        case .finances: "Tax Policy and Finances"
        case .population: "Population"
        case .happiness: "Happiness"
        case .employment: "Employment"
        case .demand: "Demand"
        case .utilities: "Utilities"
        case .journal: "Journal"
        }
    }
}

struct CityCatalogShortcutModifier: ViewModifier {
    let shortcut: CityCommandShortcut?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let shortcut,
           shortcut.focusScope == .global,
           let keyEquivalent = shortcut.keyEquivalent {
            content.keyboardShortcut(keyEquivalent, modifiers: shortcut.modifiers.eventModifiers)
        } else {
            content
        }
    }
}
