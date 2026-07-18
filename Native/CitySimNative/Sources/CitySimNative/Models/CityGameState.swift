import Foundation

struct CityGameState: Codable, Equatable, Sendable {
    var cityName: String
    var gridWidth: Int
    var gridHeight: Int
    var tiles: [CityTile]
    var tick: Int
    var treasury: Double
    var population: Int
    var jobs: Int
    var happiness: Double
    var approval: Double
    var powerUsed: Int
    var powerCapacity: Int
    var waterUsed: Int
    var waterCapacity: Int
    var taxRate: Double
    var demand: DemandLevels
    var messages: [CityMessage]
    var status: GameStatus
    var seed: UInt64

    var day: Int { tick / 4 + 1 }
    var formattedDay: String { "Day \(day)" }

    static func newCity(seed: UInt64 = 0xC17C1A) -> CityGameState {
        let width = 24
        let height = 24
        var tiles = (0..<(width * height)).map { index in
            CityTile(
                coordinate: GridCoordinate(x: index % width, y: index / width),
                kind: .empty
            )
        }
        func set(_ x: Int, _ y: Int, _ kind: BuildingKind) {
            tiles[y * width + x].kind = kind
        }
        for x in 4..<20 { set(x, 12, .road) }
        for y in 8..<17 { set(12, y, .road) }
        set(11, 11, .cityHall)
        set(10, 11, .residential)
        set(9, 11, .residential)
        set(13, 11, .commercial)
        set(14, 11, .industrial)
        set(11, 13, .park)
        set(13, 13, .powerPlant)
        set(11, 14, .waterTower)

        return CityGameState(
            cityName: "New Arcadia", gridWidth: width, gridHeight: height,
            tiles: tiles, tick: 0, treasury: 75_000, population: 180, jobs: 140,
            happiness: 68, approval: 64, powerUsed: 148, powerCapacity: 2_200,
            waterUsed: 133, waterCapacity: 2_000, taxRate: 0.10,
            demand: DemandLevels(),
            messages: [CityMessage(tick: 0, severity: .information,
                                   title: "Welcome, Mayor",
                                   detail: "Grow New Arcadia to 2,500 residents while keeping the city solvent and livable.")],
            status: .playing, seed: seed
        )
    }

    func tile(at coordinate: GridCoordinate) -> CityTile? {
        guard coordinate.x >= 0, coordinate.y >= 0,
              coordinate.x < gridWidth, coordinate.y < gridHeight else { return nil }
        return tiles[coordinate.y * gridWidth + coordinate.x]
    }

    mutating func updateTile(at coordinate: GridCoordinate, _ update: (inout CityTile) -> Void) {
        guard coordinate.x >= 0, coordinate.y >= 0,
              coordinate.x < gridWidth, coordinate.y < gridHeight else { return }
        update(&tiles[coordinate.y * gridWidth + coordinate.x])
    }

    func neighbors(of coordinate: GridCoordinate) -> [CityTile] {
        [(1, 0), (-1, 0), (0, 1), (0, -1)].compactMap {
            tile(at: GridCoordinate(x: coordinate.x + $0.0, y: coordinate.y + $0.1))
        }
    }
}
