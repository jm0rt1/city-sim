import AppKit
import SpriteKit
import XCTest
@testable import CitySimNative

final class PLAY073PlaceCohesionTests: XCTestCase {
    @MainActor
    func testLotContextIsDeterministicTruthBoundedAndProtectsFrontage() {
        let style = WorldVisualStyle()
        let renderer = LotContextRenderer(style: style)
        let cases: [(BuildingKind, RoadConnectionMask, Set<LotContextRenderer.PlacementRole>)] = [
            (.residential, .north, [.plantingBed, .lamp]),
            (.commercial, .east, [.parkingBay, .wayfinding]),
            (.industrial, .south, [.serviceYard, .serviceProp, .lamp]),
            (.cityHall, .west, [.civicForecourt, .lamp, .wayfinding]),
            (.park, .south, [.parkTerrace, .bench, .wayfinding]),
        ]

        XCTAssertEqual(LotContextRenderer.visibleVariantCount(for: .residential), 4)
        XCTAssertEqual(LotContextRenderer.visibleVariantCount(for: .commercial), 2)
        XCTAssertEqual(LotContextRenderer.visibleVariantCount(for: .industrial), 3)
        XCTAssertEqual(LotContextRenderer.visibleVariantCount(for: .cityHall), 1)

        for (index, entry) in cases.enumerated() {
            let tile = CityTile(
                coordinate: GridCoordinate(x: 8 + index, y: 10 + index),
                kind: entry.0,
                level: 1,
                constructionProgress: 1
            )
            let first = renderer.placementLedger(
                for: tile,
                adjacentRoads: entry.1,
                selectedFrontage: entry.1
            )
            XCTAssertEqual(first, renderer.placementLedger(
                for: tile,
                adjacentRoads: entry.1,
                selectedFrontage: entry.1
            ))
            XCTAssertEqual(Set(first.map(\.role)), entry.2)

            let socket = style.roadSocket(for: entry.1)
            let entrance = CGPoint(x: 0, y: -13.5)
            for placement in first {
                XCTAssertLessThanOrEqual(
                    abs(placement.center.x) / (style.tileWidth / 2)
                        + abs(placement.center.y) / (style.tileHeight / 2),
                    0.93
                )
                XCTAssertLessThanOrEqual(placement.size.width, 29)
                XCTAssertLessThanOrEqual(placement.size.height, 9)
                if !placement.groundOnly {
                    XCTAssertGreaterThanOrEqual(
                        pointSegmentDistance(
                            CGPoint(
                                x: placement.center.x - entrance.x,
                                y: placement.center.y - entrance.y
                            ),
                            end: CGPoint(
                                x: socket.x - entrance.x,
                                y: socket.y - entrance.y
                            )
                        ),
                        4.5
                    )
                }
            }
            XCTAssertTrue(renderer.placementLedger(
                for: tile,
                adjacentRoads: [],
                selectedFrontage: nil
            ).isEmpty)
        }

        let tile = CityTile(
            coordinate: GridCoordinate(x: 15, y: 12),
            kind: .industrial,
            level: 1,
            constructionProgress: 1
        )
        let before = LotContextRenderer.cachedTemplateCountForTesting
        let firstCity = SKNode()
        let firstNeighborhood = SKNode()
        let firstBlock = SKNode()
        renderer.addContext(
            for: tile,
            adjacentRoads: [.south],
            selectedFrontage: .south,
            city: firstCity,
            neighborhood: firstNeighborhood,
            block: firstBlock
        )
        let afterFirst = LotContextRenderer.cachedTemplateCountForTesting
        let secondCity = SKNode()
        let secondNeighborhood = SKNode()
        let secondBlock = SKNode()
        renderer.addContext(
            for: tile,
            adjacentRoads: [.south],
            selectedFrontage: .south,
            city: secondCity,
            neighborhood: secondNeighborhood,
            block: secondBlock
        )

        XCTAssertGreaterThanOrEqual(afterFirst, before)
        XCTAssertLessThanOrEqual(afterFirst - before, 1)
        XCTAssertEqual(firstCity.children.map(\.name), secondCity.children.map(\.name))
        XCTAssertEqual(firstNeighborhood.children.map(\.name), secondNeighborhood.children.map(\.name))
        XCTAssertEqual(firstBlock.children.map(\.name), secondBlock.children.map(\.name))
        XCTAssertFalse(firstCity.children.isEmpty)
        XCTAssertFalse(firstNeighborhood.children.isEmpty)
        XCTAssertFalse(firstBlock.children.isEmpty)
        XCTAssertFalse(firstCity.children[0] === secondCity.children[0])
        XCTAssertLessThanOrEqual(LotContextRenderer.cachedTemplateCountForTesting, 5 * 4 * 5)
    }

    @MainActor
    func testCompletedLotsExposeDistinctCityNeighborhoodAndBlockContextWithoutLabelsOrActions() {
        let renderer = LotRenderer(style: WorldVisualStyle(), assets: WorldAssetCatalog())
        let cases: [(BuildingKind, String, String)] = [
            (.residential, "residential", "planting-bed"),
            (.commercial, "commercial", "parking-bay"),
            (.industrial, "industrial", "service-yard"),
            (.cityHall, "civic", "civic-forecourt"),
            (.park, "park", "park-terrace"),
        ]

        for (index, entry) in cases.enumerated() {
            let tile = CityTile(
                coordinate: GridCoordinate(x: 6 + index, y: 8),
                kind: entry.0,
                level: 1,
                constructionProgress: 1
            )
            let first = renderer.makeLot(
                for: tile,
                adjacentRoads: .south,
                detail: .block,
                reducedMotion: true
            )
            let second = renderer.makeLot(
                for: tile,
                adjacentRoads: .south,
                detail: .block,
                reducedMotion: true
            )
            let names = descendantNames(in: first)
            XCTAssertEqual(names, descendantNames(in: second))
            XCTAssertTrue(names.contains { $0.hasPrefix("lot.context.city.\(entry.1).material.") })
            XCTAssertTrue(names.contains { $0 == "lot.lod.neighborhood.public-realm.\(entry.1)" })
            XCTAssertTrue(names.contains { $0.contains("lot.context.\(entry.1).\(entry.2)") })
            XCTAssertTrue(descendantLabels(in: first).isEmpty)
            XCTAssertEqual(recursiveActiveActionCount(first), 0)
        }
    }

    @MainActor
    func testResidentialFrontagePriorityIsStableAndRoadlessLotsFailExplicitly() throws {
        let all = try XCTUnwrap(
            ResidentialGeneratedAssetIdentity(level: 9, adjacentRoads: .all)
        )
        XCTAssertEqual(all.level, 4)
        XCTAssertEqual(all.frontage, .south)
        XCTAssertEqual(all.logicalID, "residential_l04_v0_south")
        XCTAssertEqual(
            ResidentialGeneratedAssetIdentity(
                level: 1,
                adjacentRoads: [.north, .east, .west]
            )?.frontage,
            .north
        )
        XCTAssertEqual(
            ResidentialGeneratedAssetIdentity(level: 1, adjacentRoads: [.east, .west])?.frontage,
            .east
        )
        XCTAssertNil(ResidentialGeneratedAssetIdentity(level: 1, adjacentRoads: []))

        let context = LotContextRenderer(style: WorldVisualStyle())
        let tile = CityTile(
            coordinate: GridCoordinate(x: 8, y: 8),
            kind: .residential,
            level: 1,
            constructionProgress: 1
        )
        let city = SKNode()
        let neighborhood = SKNode()
        let block = SKNode()
        context.addContext(
            for: tile,
            adjacentRoads: .south,
            selectedFrontage: .south,
            city: city,
            neighborhood: neighborhood,
            block: block
        )
        let names = descendantNames(in: city) + descendantNames(in: neighborhood)
        XCTAssertTrue(names.contains { $0.contains("contact-shadow") })
        XCTAssertTrue(names.contains { $0.contains("variant-ground") })
        XCTAssertFalse(names.contains { $0.contains("garden-grove") || $0.contains("terraced-court") })
        XCTAssertEqual(
            context.placementLedger(for: tile, adjacentRoads: [], selectedFrontage: nil),
            []
        )
    }

    @MainActor
    func testReturnedPlaceCohesionUsesDirectionalFrontageAndRoadFacingServiceContext() {
        let style = WorldVisualStyle()
        let context = LotContextRenderer(style: style)
        let firstResidential = CityTile(
            coordinate: GridCoordinate(x: 8, y: 8),
            kind: .residential,
            level: 1,
            constructionProgress: 1
        )
        let secondResidential = CityTile(
            coordinate: GridCoordinate(x: 9, y: 8),
            kind: .residential,
            level: 1,
            constructionProgress: 1
        )
        XCTAssertNotEqual(
            LotContextRenderer.districtMaterialVariant(for: firstResidential),
            LotContextRenderer.districtMaterialVariant(for: secondResidential)
        )

        let firstNeighborhood = SKNode()
        context.addGroundContext(
            for: firstResidential,
            adjacentRoads: .south,
            selectedFrontage: .south,
            city: SKNode(),
            neighborhood: firstNeighborhood,
            block: SKNode()
        )
        let firstNames = descendantNames(in: firstNeighborhood)
        XCTAssertTrue(firstNames.contains { $0.contains("frontage-strip") })
        XCTAssertTrue(firstNames.contains { $0.contains("frontage-accent") })

        let industrial = CityTile(
            coordinate: GridCoordinate(x: 12, y: 12),
            kind: .industrial,
            level: 1,
            constructionProgress: 1
        )
        let serviceYard = context.placementLedger(
            for: industrial,
            adjacentRoads: .south,
            selectedFrontage: .south
        ).first { $0.role == .serviceYard }
        XCTAssertNotNil(serviceYard)
        let socket = style.roadSocket(for: .south)
        let yard = serviceYard?.center ?? .zero
        XCTAssertGreaterThan(yard.x * socket.x + yard.y * socket.y, 0)

        let renderer = LotRenderer(style: style, assets: WorldAssetCatalog())
        for edge in [RoadConnectionMask.north, .east, .south, .west] {
            let lot = renderer.makeLot(
                for: firstResidential,
                adjacentRoads: edge,
                detail: .block,
                reducedMotion: true
            )
            XCTAssertTrue(
                descendantNames(in: lot).contains {
                    $0.hasPrefix("lot.frontage.residential.\(edge.rawValue)")
                }
            )
        }
    }

    @MainActor
    private func descendantNames(in node: SKNode) -> [String] {
        var names = node.name.map { [$0] } ?? []
        for child in node.children {
            names.append(contentsOf: descendantNames(in: child))
        }
        return names
    }

    @MainActor
    private func descendantLabels(in node: SKNode) -> [SKLabelNode] {
        var labels: [SKLabelNode] = []
        if let label = node as? SKLabelNode {
            labels.append(label)
        }
        for child in node.children {
            labels.append(contentsOf: descendantLabels(in: child))
        }
        return labels
    }

    @MainActor
    private func recursiveActiveActionCount(_ node: SKNode) -> Int {
        let own = node.hasActions() ? 1 : 0
        return own + node.children.reduce(0) { $0 + recursiveActiveActionCount($1) }
    }

    private func pointSegmentDistance(_ point: CGPoint, end: CGPoint) -> CGFloat {
        let lengthSquared = end.x * end.x + end.y * end.y
        guard lengthSquared > 0 else { return hypot(point.x, point.y) }
        let projection = max(
            0,
            min(1, (point.x * end.x + point.y * end.y) / lengthSquared)
        )
        let closest = CGPoint(x: end.x * projection, y: end.y * projection)
        return hypot(point.x - closest.x, point.y - closest.y)
    }
}
