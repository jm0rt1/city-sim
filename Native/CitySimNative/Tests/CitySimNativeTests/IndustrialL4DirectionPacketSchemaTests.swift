import CryptoKit
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
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let directionBridgeSchema = try XCTUnwrap(
            properties["directionBridge"] as? [String: Any]
        )
        let directionBridgeProperties = try XCTUnwrap(
            directionBridgeSchema["properties"] as? [String: Any]
        )
        XCTAssertEqual(
            try XCTUnwrap(
                directionBridgeProperties["documentPath"] as? [String: Any]
            )["const"] as? String,
            IndustrialL4DirectionPacketFactory.directionBridge.documentPath
        )
        XCTAssertEqual(
            try XCTUnwrap(
                directionBridgeProperties["commit"] as? [String: Any]
            )["const"] as? String,
            IndustrialL4DirectionPacketFactory.directionBridge.commit
        )
        XCTAssertEqual(
            try XCTUnwrap(
                directionBridgeProperties["documentSha256"] as? [String: Any]
            )["const"] as? String,
            IndustrialL4DirectionPacketFactory.directionBridge.documentSha256
        )
        XCTAssertEqual(
            try XCTUnwrap(
                directionBridgeProperties["canonicalMappingSha256"] as? [String: Any]
            )["const"] as? String,
            IndustrialL4DirectionPacketFactory.directionBridge.canonicalMappingSha256
        )
        let schemaText = try String(contentsOf: schemaURL, encoding: .utf8)
        XCTAssertFalse(schemaText.contains("entranceSocketWorld"))
        XCTAssertFalse(schemaText.contains("\"socketBlender\""))
        XCTAssertFalse(schemaText.contains("\"dccNativeCoordinates\""))

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

        let bridgeDocumentURL = repositoryRoot.appending(
            path: decoded.directionBridge.documentPath
        )
        XCTAssertEqual(
            sha256(try Data(contentsOf: bridgeDocumentURL)),
            decoded.directionBridge.documentSha256
        )
        let mappingContractURL = repositoryRoot.appending(
            path:
                "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json"
        )
        XCTAssertEqual(
            sha256(try Data(contentsOf: mappingContractURL)),
            decoded.directionBridge.canonicalMappingSha256
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

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
