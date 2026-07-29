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
        XCTAssertTrue(required.contains("transformFingerprints"))
        XCTAssertTrue(required.contains("productionSelected"))

        let packet = IndustrialL4DirectionPacketFactory.packet(.north)
        let encoded = try JSONEncoder().encode(packet)
        let decoded = try JSONDecoder().decode(
            IndustrialL4DirectionPacket.self,
            from: encoded
        )
        XCTAssertEqual(decoded, packet)

        let validator = IndustrialL4DirectionPacketValidator(
            appearanceLock: IndustrialL4DirectionPacketFactory.appearanceLock
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
    }

    private var repositoryRoot: URL {
        var root = URL(filePath: #filePath)
        for _ in 0..<5 {
            root.deleteLastPathComponent()
        }
        return root
    }
}
