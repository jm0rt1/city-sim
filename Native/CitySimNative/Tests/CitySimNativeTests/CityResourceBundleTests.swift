import Foundation
import XCTest
@testable import CitySimNative

final class CityResourceBundleTests: XCTestCase {
    func testPackagedResourcesWinWithoutEvaluatingTheBuildDirectoryFallback() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("citysim-sealed-resources-\(UUID().uuidString)")
        let resources = root.appendingPathComponent("Relocated City.app/Contents/Resources", isDirectory: true)
        try manager.createDirectory(at: resources, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        try manager.createSymbolicLink(
            at: resources.appendingPathComponent(CityResourceBundle.name),
            withDestinationURL: Bundle.module.bundleURL
        )
        var evaluatedFallback = false
        let resolved = CityResourceBundle.resolve(mainResourceURL: resources) {
            evaluatedFallback = true
            return Bundle.main
        }
        XCTAssertFalse(evaluatedFallback, "A staged app must not touch SwiftPM's absolute build path")
        XCTAssertEqual(resolved.bundleURL.resolvingSymlinksInPath(), Bundle.module.bundleURL.resolvingSymlinksInPath())
    }

    func testUnpackagedSwiftPMExecutionRetainsItsExplicitFallback() {
        for resources in [nil, URL(fileURLWithPath: "/nonexistent-citysim-resource-root")] {
            var fallbackCalls = 0
            let resolved = CityResourceBundle.resolve(mainResourceURL: resources) {
                fallbackCalls += 1
                return Bundle.module
            }
            XCTAssertEqual(fallbackCalls, 1)
            XCTAssertEqual(resolved.bundleURL, Bundle.module.bundleURL)
        }
    }

    @MainActor
    func testSharedRuntimeResourcesLoadEveryCanonicalAssetFamily() throws {
        let bundle = CityResourceBundle.shared
        for directory in ["FourViewAssets", "FourViewRoadAssets", "FourViewGroundEcologyAssets"] {
            XCTAssertNotNil(bundle.url(forResource: "manifest", withExtension: "json", subdirectory: directory))
        }
        XCTAssertNotNil(FourViewWorldAssetCatalog().manifest)
        XCTAssertNotNil(FourViewRoadAssetCatalog().manifest)
        XCTAssertNotNil(FourViewGroundEcologyCatalog().manifest)
        XCTAssertNotNil(WorldAssetCatalog().generatedManifest)
    }
}
