import XCTest
@testable import CitySimNative

final class ProofWindowConfiguratorTests: XCTestCase {
    @MainActor
    func testExplicitProofRequestsAlsoDriveTheInitialSceneContentSize() {
        XCTAssertEqual(ProofWindowConfigurator.regularProofContentSize.width, 1_280)
        XCTAssertEqual(ProofWindowConfigurator.regularProofContentSize.height, 800)
        XCTAssertEqual(ProofWindowConfigurator.compactContentSize.width, 900)
        XCTAssertEqual(ProofWindowConfigurator.compactContentSize.height, 600)
        XCTAssertEqual(
            ProofWindowConfigurator.initialSceneContentSize(
                environment: ["CITYSIM_COMPACT_WINDOW": "1"]
            ),
            ProofWindowConfigurator.compactContentSize
        )
        XCTAssertEqual(
            ProofWindowConfigurator.initialSceneContentSize(
                environment: ["CITYSIM_REGULAR_WINDOW": "1"]
            ),
            ProofWindowConfigurator.regularProofContentSize
        )
        XCTAssertEqual(
            ProofWindowConfigurator.initialSceneContentSize(environment: [:]),
            ProofWindowConfigurator.defaultContentSize
        )
    }

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

    @MainActor
    func testOnlyExplicitProofGeometryReassertsAfterWindowActivation() {
        XCTAssertTrue(ProofWindowConfigurator.reassertsSizeAfterWindowActivation(
            environment: ["CITYSIM_COMPACT_WINDOW": "1"]
        ))
        XCTAssertTrue(ProofWindowConfigurator.reassertsSizeAfterWindowActivation(
            environment: ["CITYSIM_REGULAR_WINDOW": "1"]
        ))
        XCTAssertFalse(ProofWindowConfigurator.reassertsSizeAfterWindowActivation(
            environment: [SaveGameService.dataRootEnvironmentKey: "/tmp/citysim-candidate"]
        ))
        XCTAssertFalse(ProofWindowConfigurator.reassertsSizeAfterWindowActivation(environment: [:]))
    }
}
