import CoreGraphics
import XCTest
@testable import CitySimNative

final class IsometricGridCoordinateResolverTests: XCTestCase {
    private let resolver = IsometricGridCoordinateResolver(tileWidth: 72, tileHeight: 36)

    func testResolvesEveryAuthoritativeCellCenter() {
        for x in 0..<24 {
            for y in 0..<24 {
                let center = CGPoint(
                    x: CGFloat(x - y) * 36,
                    y: -CGFloat(x + y) * 18
                )
                XCTAssertEqual(
                    resolver.coordinate(at: center, gridWidth: 24, gridHeight: 24),
                    GridCoordinate(x: x, y: y),
                    "center \(x),\(y)"
                )
            }
        }
    }

    func testResolvesInteriorPointsWithoutCrossingDiamondEdges() {
        let coordinate = GridCoordinate(x: 12, y: 9)
        let center = CGPoint(x: 108, y: -378)
        for offset in [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 25, y: 3),
            CGPoint(x: -25, y: -3),
            CGPoint(x: 2, y: 14),
            CGPoint(x: -2, y: -14),
        ] {
            XCTAssertEqual(
                resolver.coordinate(
                    at: CGPoint(x: center.x + offset.x, y: center.y + offset.y),
                    gridWidth: 24,
                    gridHeight: 24
                ),
                coordinate,
                "offset \(offset)"
            )
        }
    }

    func testRejectsPointsBeyondTheAuthoritativeMapAndInvalidGeometry() {
        XCTAssertNil(resolver.coordinate(at: CGPoint(x: 2_000, y: 2_000), gridWidth: 24, gridHeight: 24))
        XCTAssertNil(resolver.coordinate(at: CGPoint(x: 0, y: 0), gridWidth: 0, gridHeight: 24))
        XCTAssertNil(
            IsometricGridCoordinateResolver(tileWidth: 0, tileHeight: 36)
                .coordinate(at: .zero, gridWidth: 24, gridHeight: 24)
        )
    }
}
