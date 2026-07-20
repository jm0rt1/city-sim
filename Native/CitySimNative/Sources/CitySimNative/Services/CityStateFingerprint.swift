import CryptoKit
import Foundation

struct CityStateFingerprint: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let digest: String

    init(version: Int = currentVersion, digest: String) {
        self.version = version
        self.digest = digest
    }
}

enum CityStateFingerprinter {
    static func canonicalData(for state: CityGameState, version: Int = CityStateFingerprint.currentVersion) throws -> Data {
        guard version == CityStateFingerprint.currentVersion else {
            throw CityStateFingerprintError.unsupportedVersion(version)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }

    static func fingerprint(
        _ state: CityGameState,
        version: Int = CityStateFingerprint.currentVersion
    ) throws -> CityStateFingerprint {
        let canonicalData = try canonicalData(for: state, version: version)
        let digest = SHA256.hash(data: canonicalData).map { String(format: "%02x", $0) }.joined()
        return CityStateFingerprint(version: version, digest: digest)
    }
}

enum CityStateFingerprintError: Error, Equatable {
    case unsupportedVersion(Int)
}
