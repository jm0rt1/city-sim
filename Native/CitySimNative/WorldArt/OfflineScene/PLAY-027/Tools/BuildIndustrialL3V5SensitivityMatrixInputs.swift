import CryptoKit
import Foundation

enum IndustrialL3V5SensitivityInputError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: build-industrial-l3-v5-sensitivity-inputs \
              --repository-root <path> --output-root <diagnostics-path>
            """
        case let .invalid(message):
            return message
        }
    }
}

private struct MatrixRow {
    let id: String
    let direction: String
    let changes: [(materialID: String, channel: Int)]
}

private let northScene =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-frontage-v01/scenes/"
    + "industrial_l03/variant-0/north/scene.json"
private let westScene =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-frontage-v01/scenes/"
    + "industrial_l03/variant-0/west/scene.json"
private let materialsFile =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-east-v01/materials/"
    + "industrial-l03-cohesion-east-v01.json"
private let expectedHashes = [
    northScene:
        "a147ad0a7023374b982a6677325da2912f45796616b03579e1a72eb7da4a6b61",
    westScene:
        "56e9aef896ef5eef435f76ff466f837ac022ff18edbc4e6bd3fa24cb583d78dc",
    materialsFile:
        "f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65",
]
private let delta = 2.0 / 255.0
private let rows = [
    MatrixRow(
        id: "N1",
        direction: "north",
        changes: [
            ("l3c-charcoal-outline-steel", 0),
            ("l3c-warm-trim", 0),
        ]
    ),
    MatrixRow(
        id: "W1",
        direction: "west",
        changes: [
            ("l3c-charcoal-outline-steel", 0),
            ("l3c-warm-formed-concrete", 2),
        ]
    ),
    MatrixRow(
        id: "W2",
        direction: "west",
        changes: [
            ("l3c-charcoal-outline-steel", 0),
            ("l3c-restrained-safety", 2),
        ]
    ),
    MatrixRow(
        id: "W3",
        direction: "west",
        changes: [
            ("l3c-charcoal-outline-steel", 0),
            ("l3c-warm-formed-concrete", 2),
            ("l3c-restrained-safety", 2),
        ]
    ),
]

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3V5SensitivityInputError.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

private func jsonObject(_ data: Data, label: String) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    else {
        throw IndustrialL3V5SensitivityInputError.invalid(
            "\(label) must be a JSON object"
        )
    }
    return object
}

private func jsonData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func write(_ data: Data, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL3V5SensitivityInputError.invalid(
            "refusing to overwrite \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .withoutOverwriting)
}

private func validatedMaterialCopy(
    sourceData: Data,
    row: MatrixRow
) throws -> (Data, [[String: Any]]) {
    var object = try jsonObject(sourceData, label: "material library")
    guard var materials = object["materials"] as? [[String: Any]] else {
        throw IndustrialL3V5SensitivityInputError.invalid(
            "materials array missing"
        )
    }
    var ledger: [[String: Any]] = []
    for change in row.changes {
        guard
            let index = materials.firstIndex(
                where: { $0["id"] as? String == change.materialID }
            ),
            let colors = materials[index]["baseColorRGBA"] as? [NSNumber],
            colors.count == 4
        else {
            throw IndustrialL3V5SensitivityInputError.invalid(
                "\(row.id) material \(change.materialID) missing"
            )
        }
        let before = colors.map(\.doubleValue)
        var after = before
        after[change.channel] += delta
        guard
            after[change.channel] <= 1,
            abs(
                after[change.channel]
                    - before[change.channel]
                    - delta
            ) < 1e-15
        else {
            throw IndustrialL3V5SensitivityInputError.invalid(
                "\(row.id) exact positive 2/255 delta failed"
            )
        }
        materials[index]["baseColorRGBA"] = after
        ledger.append([
            "materialID": change.materialID,
            "channel": ["red", "green", "blue", "alpha"][change.channel],
            "channelIndex": change.channel,
            "before": before[change.channel],
            "after": after[change.channel],
            "delta": delta,
            "sign": "positive",
        ])
    }
    object["materials"] = materials
    let output = try jsonData(object)
    let roundTrip = try jsonObject(output, label: "\(row.id) material copy")
    guard
        let outputMaterials = roundTrip["materials"] as? [[String: Any]],
        outputMaterials.count == materials.count
    else {
        throw IndustrialL3V5SensitivityInputError.invalid(
            "\(row.id) material round trip failed"
        )
    }
    let allowed = Set(
        row.changes.map { "\($0.materialID)#\($0.channel)" }
    )
    guard
        let sourceMaterials =
            try jsonObject(sourceData, label: "source material library")[
                "materials"
            ] as? [[String: Any]]
    else {
        throw IndustrialL3V5SensitivityInputError.invalid(
            "source material comparison unavailable"
        )
    }
    for (source, candidate) in zip(sourceMaterials, outputMaterials) {
        guard
            let id = source["id"] as? String,
            let sourceColors = source["baseColorRGBA"] as? [NSNumber],
            let candidateColors =
                candidate["baseColorRGBA"] as? [NSNumber]
        else {
            throw IndustrialL3V5SensitivityInputError.invalid(
                "\(row.id) material identity comparison failed"
            )
        }
        var strippedSource = source
        var strippedCandidate = candidate
        strippedSource.removeValue(forKey: "baseColorRGBA")
        strippedCandidate.removeValue(forKey: "baseColorRGBA")
        guard
            NSDictionary(dictionary: strippedSource)
                .isEqual(to: strippedCandidate)
        else {
            throw IndustrialL3V5SensitivityInputError.invalid(
                "\(row.id) changed a non-color material field for \(id)"
            )
        }
        for channel in 0..<4 {
            let key = "\(id)#\(channel)"
            let difference =
                candidateColors[channel].doubleValue
                - sourceColors[channel].doubleValue
            if allowed.contains(key) {
                guard abs(difference - delta) < 1e-15 else {
                    throw IndustrialL3V5SensitivityInputError.invalid(
                        "\(row.id) authorized delta drifted for \(key)"
                    )
                }
            } else if difference != 0 {
                throw IndustrialL3V5SensitivityInputError.invalid(
                    "\(row.id) unauthorized color change at \(key)"
                )
            }
        }
    }
    return (output, ledger)
}

@main
private enum IndustrialL3V5SensitivityInputMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            ),
            isDirectory: true
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try argument("--output-root", in: arguments),
            isDirectory: true
        ).standardizedFileURL
        guard
            outputRoot.path.hasPrefix(repositoryRoot.path + "/"),
            outputRoot.path.contains(
                "/docs/production/evidence/PLAY-027/industrial-l03/"
            ),
            outputRoot.path.contains("/diagnostics/"),
            !FileManager.default.fileExists(atPath: outputRoot.path)
        else {
            throw IndustrialL3V5SensitivityInputError.invalid(
                "output must be one absent task-owned diagnostics root"
            )
        }
        let sceneURLs = [
            "north": repositoryRoot.appendingPathComponent(northScene),
            "west": repositoryRoot.appendingPathComponent(westScene),
        ]
        for (path, expected) in expectedHashes {
            let actual = try sha256(
                repositoryRoot.appendingPathComponent(path)
            )
            guard actual == expected else {
                throw IndustrialL3V5SensitivityInputError.invalid(
                    "frozen input hash drifted for \(path): \(actual)"
                )
            }
        }
        let materialURL = repositoryRoot.appendingPathComponent(materialsFile)
        let sourceMaterialData = try Data(contentsOf: materialURL)
        var rowRecords: [[String: Any]] = []
        for row in rows {
            guard let sceneURL = sceneURLs[row.direction] else {
                throw IndustrialL3V5SensitivityInputError.invalid(
                    "\(row.id) direction unavailable"
                )
            }
            let rowRoot = outputRoot.appendingPathComponent(row.id)
            let sceneCopy = rowRoot.appendingPathComponent("scene.json")
            let materialCopy =
                rowRoot.appendingPathComponent("materials.json")
            let sceneData = try Data(contentsOf: sceneURL)
            try write(sceneData, to: sceneCopy)
            let (materialData, ledger) = try validatedMaterialCopy(
                sourceData: sourceMaterialData,
                row: row
            )
            try write(materialData, to: materialCopy)
            guard
                try sha256(sceneCopy) == expectedHashes[
                    row.direction == "north" ? northScene : westScene
                ]
            else {
                throw IndustrialL3V5SensitivityInputError.invalid(
                    "\(row.id) descriptor copy is not byte exact"
                )
            }
            rowRecords.append([
                "row": row.id,
                "direction": row.direction,
                "descriptorCopy": sceneCopy.path
                    .replacingOccurrences(
                        of: repositoryRoot.path + "/",
                        with: ""
                    ),
                "descriptorSHA256": try sha256(sceneCopy),
                "materialCopy": materialCopy.path
                    .replacingOccurrences(
                        of: repositoryRoot.path + "/",
                        with: ""
                    ),
                "materialSHA256": try sha256(materialCopy),
                "changes": ledger,
                "sourceRevision": "source-v05",
                "productionSelected": false,
            ])
        }
        let manifest: [String: Any] = [
            "task": "PLAY-027",
            "authorityCommit":
                "78aba5442c675cc8664deaebffa13422ac2100c1",
            "attributionCheckpoint":
                "a235546ef0a7ddf31cc2e78d16dfba62f08f82fe",
            "sourceMaterialLibrary": [
                "path": materialsFile,
                "sha256": expectedHashes[materialsFile]!,
            ],
            "delta": delta,
            "sign": "positive",
            "rows": rowRecords,
            "sceneKitProcessCount": 0,
            "rawProcessCount": 0,
            "normalizerProcessCount": 0,
            "sourceAuthority": false,
            "productionSelected": false,
        ]
        try write(
            try jsonData(manifest),
            to: outputRoot.appendingPathComponent("INPUT-MANIFEST.json")
        )
        print("PASS created four diagnostics-only matrix input rows")
    }
}
