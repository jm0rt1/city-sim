import XCTest
@testable import CitySimNative

final class ProofWindowConfiguratorTests: XCTestCase {
    @MainActor
    func testFreshCandidateGetsDefaultButOnlyExplicitCompactGetsNineHundredBySixHundred() {
        let candidateEnvironment = [SaveGameService.dataRootEnvironmentKey: "/tmp/citysim-candidate"]

        XCTAssertEqual(
            ProofWindowConfigurator.requestedContentSize(
                environment: candidateEnvironment,
                hasEstablishedCandidateDefault: false
            ),
            ProofWindowConfigurator.defaultContentSize
        )
        XCTAssertNil(ProofWindowConfigurator.requestedContentSize(
            environment: candidateEnvironment,
            hasEstablishedCandidateDefault: true
        ))
        XCTAssertNil(ProofWindowConfigurator.requestedContentSize(
            environment: [:],
            hasEstablishedCandidateDefault: false
        ), "Production preferences must not be replaced by candidate first-launch policy")
        XCTAssertEqual(
            ProofWindowConfigurator.requestedContentSize(
                environment: [
                    SaveGameService.dataRootEnvironmentKey: "/tmp/citysim-candidate",
                    "CITYSIM_COMPACT_WINDOW": "1"
                ],
                hasEstablishedCandidateDefault: false
            ),
            ProofWindowConfigurator.compactContentSize
        )
        XCTAssertEqual(
            ProofWindowConfigurator.requestedContentSize(
                environment: ["CITYSIM_REGULAR_WINDOW": "1"],
                hasEstablishedCandidateDefault: true
            ),
            ProofWindowConfigurator.regularProofContentSize
        )
    }
}
