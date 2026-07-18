import Foundation

struct SaveGameService {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder = JSONDecoder()

    var saveURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appending(path: "CitySimNative", directoryHint: .isDirectory)
            .appending(path: "quicksave.json")
    }

    func save(_ state: CityGameState) throws {
        let directory = saveURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(state).write(to: saveURL, options: .atomic)
    }

    func load() throws -> CityGameState {
        try decoder.decode(CityGameState.self, from: Data(contentsOf: saveURL))
    }
}
