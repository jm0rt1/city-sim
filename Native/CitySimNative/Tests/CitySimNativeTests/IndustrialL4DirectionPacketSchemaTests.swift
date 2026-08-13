import Foundation
import XCTest
@testable import CitySimNative

final class IndustrialL4DirectionPacketSchemaTests: XCTestCase {
    func testSyntheticPacketBindsNonShippingBoundary() throws {
        let packet = IndustrialL4DirectionPacketFactory.packet(.north)
        let encoded = try JSONEncoder().encode(packet)
        let decoded = try JSONDecoder().decode(
            IndustrialL4DirectionPacket.self,
            from: encoded
        )
        XCTAssertEqual(decoded, packet)

        let validator = IndustrialL4DirectionPacketValidator(
            appearanceLock: IndustrialL4DirectionPacketFactory.appearanceLock,
            directionBridge: IndustrialL4DirectionPacketFactory.directionBridge
        )
        XCTAssertNoThrow(try validator.validate(decoded))
        XCTAssertTrue(decoded.sourceReady)
        XCTAssertFalse(decoded.productionSelected)
        XCTAssertNil(decoded.source.fallbackSourceKey)
        XCTAssertEqual(
            decoded.transformFingerprints.identity,
            decoded.source.decodedRgbaSha256
        )
        XCTAssertEqual(Set(decoded.transformFingerprints.all).count, 8)
        XCTAssertEqual(decoded.registration.frontageSocketSource, [896, 704])
        XCTAssertEqual(
            decoded.directionBridge.coordinateSystem,
            "citysim_source_pixels_v1"
        )

    }

    func testCanonicalCitySimSourcePixelSocketsAreDirectionBound() throws {
        let expectedSockets: [IndustrialL4PacketDirection: [Int]] = [
            .north: [896, 704],
            .east: [896, 832],
            .south: [640, 832],
            .west: [640, 704],
        ]
        let validator = IndustrialL4DirectionPacketValidator(
            appearanceLock: IndustrialL4DirectionPacketFactory.appearanceLock,
            directionBridge: IndustrialL4DirectionPacketFactory.directionBridge
        )
        for direction in IndustrialL4PacketDirection.allCases {
            let packet = IndustrialL4DirectionPacketFactory.packet(direction)
            XCTAssertNoThrow(try validator.validate(packet))
            XCTAssertEqual(
                packet.registration.frontageSocketSource,
                expectedSockets[direction]
            )
            XCTAssertEqual(packet.registration.frontageEdge, direction.rawValue)
        }
    }

    func testDirectionPacketCannotDecodeWithoutBridgeAuthority() throws {
        let packet = IndustrialL4DirectionPacketFactory.packet(.north)
        let encoded = try JSONEncoder().encode(packet)
        var object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "directionBridge")
        let missingBridge = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                IndustrialL4DirectionPacket.self,
                from: missingBridge
            )
        )
    }

}
