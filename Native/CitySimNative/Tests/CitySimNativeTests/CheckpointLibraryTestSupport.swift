import XCTest
@testable import CitySimNative

extension CityGameStore {
    @MainActor
    @discardableResult
    func selectNewestCheckpointForTesting(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Bool {
        let library = try XCTUnwrap(checkpointLibrary, file: file, line: line)
        let checkpoint = try XCTUnwrap(
            library.cards.first(where: \.isLoadable),
            file: file,
            line: line
        )
        let selected = selectCheckpoint(checkpoint.id)
        XCTAssertTrue(selected, file: file, line: line)
        return selected
    }
}
