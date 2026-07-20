import XCTest
@testable import CitySimNative

final class SessionPlatformTests: XCTestCase {
    func testVersionOneFingerprintFixturesAreFrozen() throws {
        let explicitProgression = CityGameState.newCity(seed: 42)
        var legacyNilProgression = explicitProgression
        legacyNilProgression.progression = nil

        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(explicitProgression),
            CityStateFingerprint(digest: "947b383684145d6d18738f313fec4f648861680165134f33b4f65ad42e5c0e3f")
        )
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(legacyNilProgression),
            CityStateFingerprint(digest: "b7608f0aa748f5b40086d59ffeba746908599780f791b6483d6c613e80dedeb5")
        )
    }

    func testVersionOneFingerprintIsRepeatableAndPreservesNilProgressionDistinction() throws {
        let explicitProgression = CityGameState.newCity(seed: 42)
        var legacyNilProgression = explicitProgression
        legacyNilProgression.progression = nil

        let repeated = try (0..<100).map { _ in
            try CityStateFingerprinter.fingerprint(explicitProgression)
        }

        XCTAssertEqual(Set(repeated.map(\.digest)).count, 1)
        XCTAssertNotEqual(
            try CityStateFingerprinter.fingerprint(explicitProgression),
            try CityStateFingerprinter.fingerprint(legacyNilProgression)
        )
    }

    func testFingerprintRejectsUnknownCanonicalVersion() {
        XCTAssertThrowsError(try CityStateFingerprinter.fingerprint(.newCity(seed: 42), version: 2)) { error in
            XCTAssertEqual(error as? CityStateFingerprintError, .unsupportedVersion(2))
        }
    }
}
