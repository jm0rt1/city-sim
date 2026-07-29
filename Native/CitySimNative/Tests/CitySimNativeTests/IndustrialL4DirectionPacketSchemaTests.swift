import Foundation
import XCTest
@testable import CitySimNative

final class IndustrialL4DirectionPacketSchemaTests: XCTestCase {
    func testMachineReadableSchemaAndSyntheticPacketBindNonShippingBoundary() throws {
        let schemaURL = repositoryRoot
            .appending(path: "docs/production/evidence/PLAY-073")
            .appending(path: "industrial-l04-direction-quarantine-v1")
            .appending(path: "DIRECTION-PACKET-SCHEMA.json")
        let schema = try XCTUnwrap(
            try JSONSerialization.jsonObject(
                with: Data(contentsOf: schemaURL)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            schema["$id"] as? String,
            "citysim://play-073/industrial-l04-direction-quarantine-v1"
        )
        let required = try XCTUnwrap(schema["required"] as? [String])
        XCTAssertTrue(required.contains("appearanceLock"))
        XCTAssertTrue(required.contains("directionBridge"))
        XCTAssertTrue(required.contains("transformFingerprints"))
        XCTAssertTrue(required.contains("productionSelected"))
        let schemaText = try String(contentsOf: schemaURL, encoding: .utf8)
        XCTAssertFalse(schemaText.contains("entranceSocketWorld"))
        XCTAssertFalse(schemaText.lowercased().contains("blender"))
        XCTAssertFalse(schemaText.lowercased().contains("dcc"))

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

    private var repositoryRoot: URL {
        var root = URL(filePath: #filePath)
        for _ in 0..<5 {
            root.deleteLastPathComponent()
        }
        return root
    }
}
