import Foundation

struct GridCoordinate: Hashable, Codable, Identifiable, Sendable {
    let x: Int
    let y: Int
    var id: String { "\(x)-\(y)" }
}

enum BuildingKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case empty, road, residential, commercial, industrial, park
    case powerPlant, waterTower, fireStation, policeStation, school, cityHall

    var id: String { rawValue }

    var title: String {
        switch self {
        case .empty: "Open Land"
        case .road: "Road"
        case .residential: "Residential"
        case .commercial: "Commercial"
        case .industrial: "Industrial"
        case .park: "Park"
        case .powerPlant: "Power Plant"
        case .waterTower: "Water Tower"
        case .fireStation: "Fire Station"
        case .policeStation: "Police Station"
        case .school: "School"
        case .cityHall: "City Hall"
        }
    }

    var symbol: String {
        switch self {
        case .empty: "square.dashed"
        case .road: "road.lanes"
        case .residential: "house.fill"
        case .commercial: "storefront.fill"
        case .industrial: "building.2.crop.circle.fill"
        case .park: "tree.fill"
        case .powerPlant: "bolt.fill"
        case .waterTower: "drop.fill"
        case .fireStation: "flame.fill"
        case .policeStation: "shield.fill"
        case .school: "graduationcap.fill"
        case .cityHall: "building.columns.fill"
        }
    }

    var buildCost: Double {
        switch self {
        case .empty: 0
        case .road: 120
        case .residential: 1_800
        case .commercial: 2_400
        case .industrial: 3_200
        case .park: 900
        case .powerPlant: 12_000
        case .waterTower: 8_500
        case .fireStation: 9_000
        case .policeStation: 9_000
        case .school: 11_000
        case .cityHall: 18_000
        }
    }

    var upkeep: Double {
        switch self {
        case .empty: 0
        case .road: 2
        case .residential: 4
        case .commercial: 6
        case .industrial: 8
        case .park: 18
        case .powerPlant: 95
        case .waterTower: 70
        case .fireStation, .policeStation: 80
        case .school: 100
        case .cityHall: 120
        }
    }

    var demolitionCost: Double {
        max(50, buildCost * 0.08)
    }

    var requiresRoad: Bool {
        ![.empty, .road, .park].contains(self)
    }

    static var buildPalette: [BuildingKind] {
        [.road, .residential, .commercial, .industrial, .park, .powerPlant,
         .waterTower, .fireStation, .policeStation, .school, .cityHall]
    }

    var buildCategory: BuildCategory {
        switch self {
        case .road: .roads
        case .residential, .commercial, .industrial: .zones
        case .powerPlant, .waterTower: .utilities
        case .fireStation, .policeStation, .school: .services
        case .park, .cityHall, .empty: .civic
        }
    }
}

enum BuildCategory: String, CaseIterable, Identifiable, Sendable {
    case roads, zones, utilities, services, civic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .roads: "Roads"
        case .zones: "Zones"
        case .utilities: "Utilities"
        case .services: "Services"
        case .civic: "Civic"
        }
    }

    var symbol: String {
        switch self {
        case .roads: "road.lanes"
        case .zones: "square.grid.2x2.fill"
        case .utilities: "bolt.horizontal.fill"
        case .services: "cross.case.fill"
        case .civic: "building.columns.fill"
        }
    }

    var buildingKinds: [BuildingKind] {
        switch self {
        case .roads: [.road]
        case .zones: [.residential, .commercial, .industrial]
        case .utilities: [.powerPlant, .waterTower]
        case .services: [.fireStation, .policeStation, .school]
        case .civic: [.park, .cityHall]
        }
    }
}

enum CityInteractionMode: Equatable, Sendable {
    case inspect
    case build(BuildingKind)
    case bulldoze

    var title: String {
        switch self {
        case .inspect: "Inspect"
        case .build: "Build"
        case .bulldoze: "Bulldoze"
        }
    }

    var symbol: String {
        switch self {
        case .inspect: "cursorarrow.rays"
        case .build: "hammer.fill"
        case .bulldoze: "trash.fill"
        }
    }
}

struct CityTile: Identifiable, Codable, Equatable, Sendable {
    let coordinate: GridCoordinate
    var kind: BuildingKind
    var level: Int = 1
    var occupancy: Int = 0
    var condition: Double = 1
    var constructionProgress: Double = 1
    var id: String { coordinate.id }
}

enum SimulationSpeed: Int, CaseIterable, Identifiable, Sendable {
    case paused = 0, normal = 1, fast = 2, fastest = 3
    var id: Int { rawValue }
    var title: String { self == .paused ? "Paused" : "Speed \(rawValue)" }
    var controlLabel: String { self == .paused ? "Pause" : "\(rawValue)x" }
    var symbol: String {
        switch self {
        case .paused: "pause.fill"
        case .normal: "play.fill"
        case .fast: "forward.fill"
        case .fastest: "forward.end.fill"
        }
    }
    var ticksPerPulse: Int { rawValue }
}

enum DataOverlay: String, CaseIterable, Identifiable, Sendable {
    case none, landValue, traffic, utilities, happiness, pollution
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "City"
        case .landValue: "Land Value"
        case .traffic: "Traffic"
        case .utilities: "Utilities"
        case .happiness: "Happiness"
        case .pollution: "Pollution"
        }
    }
    var symbol: String {
        switch self {
        case .none: "building.2"
        case .landValue: "dollarsign.circle"
        case .traffic: "car.2"
        case .utilities: "bolt.horizontal"
        case .happiness: "face.smiling"
        case .pollution: "aqi.medium"
        }
    }
}

enum InspectorSection: String, CaseIterable, Identifiable, Sendable {
    case overview, finances, population, happiness, employment, demand, utilities, journal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "City Overview"
        case .finances: "City Finances"
        case .population: "Population"
        case .happiness: "Happiness"
        case .employment: "Employment"
        case .demand: "Development Demand"
        case .utilities: "Utilities"
        case .journal: "City Journal"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "building.2.fill"
        case .finances: "dollarsign.circle.fill"
        case .population: "person.3.fill"
        case .happiness: "face.smiling.fill"
        case .employment: "briefcase.fill"
        case .demand: "chart.bar.fill"
        case .utilities: "bolt.horizontal.fill"
        case .journal: "newspaper.fill"
        }
    }
}

enum HUDContextScope: Equatable, Sendable {
    case city
    case selection
}

enum GameStatus: String, Codable, Sendable {
    case playing, won, lost
}

enum MessageSeverity: String, Codable, Sendable {
    case good, information, warning, critical
}

struct CityMessage: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let tick: Int
    let severity: MessageSeverity
    let title: String
    let detail: String

    init(tick: Int, severity: MessageSeverity, title: String, detail: String) {
        self.id = "\(tick)-\(title)"
        self.tick = tick
        self.severity = severity
        self.title = title
        self.detail = detail
    }
}

struct CityMessageSummary: Identifiable, Equatable, Sendable {
    let message: CityMessage
    let count: Int

    var id: String { "\(message.severity.rawValue)-\(message.title)" }
    var presentationID: String { "\(message.id)-\(count)" }
}

struct DemandLevels: Codable, Equatable, Sendable {
    var residential: Double = 0.65
    var commercial: Double = 0.45
    var industrial: Double = 0.40
}

struct CityObjective: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let progress: Double
    let remaining: String
    var completed: Bool { progress >= 1 }
}
