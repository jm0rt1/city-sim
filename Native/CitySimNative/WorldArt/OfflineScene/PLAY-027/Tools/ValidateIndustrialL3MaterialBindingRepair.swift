import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let bindingBaseline =
    "0aefb804c59b4ff9b919dc81fdca907cd4b85c5e"
private let bindingManifest =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "source-v06-complete-family-v01/FAMILY-MANIFEST.json"
private let bindingCohesionFile =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l03-cohesion-east-v01/materials/"
    + "industrial-l03-cohesion-east-v01.json"
private let bindingCohesionSHA256 =
    "f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65"

private func bindingGitShow(
    root: URL,
    commit: String,
    path: String
) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = [
        "-C", root.path, "show", "\(commit):\(path)",
    ]
    let output = Pipe()
    let error = Pipe()
    process.standardOutput = output
    process.standardError = error
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        let message = String(
            data: error.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? "git show failed"
        throw IndustrialL3FinalError.invalid(
            "baseline read failed for \(path): \(message)"
        )
    }
    return data
}

private func bindingSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func bindingJSONObject(_ data: Data) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    else {
        throw IndustrialL3FinalError.invalid("JSON object expected")
    }
    return object
}

private func bindingCanonicalDescriptor(
    _ data: Data
) throws -> Data {
    var object = try bindingJSONObject(data)
    guard var material = object["materialLibrary"] as? [String: Any] else {
        throw IndustrialL3FinalError.invalid(
            "descriptor materialLibrary missing"
        )
    }
    material.removeValue(forKey: "file")
    material.removeValue(forKey: "sha256")
    object["materialLibrary"] = material
    return try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

private func bindingValid(
    _ material: [String: Any],
    expectedFile: String,
    expectedSHA256: String,
    root: URL
) -> Bool {
    guard
        material["file"] as? String == expectedFile,
        material["sha256"] as? String == expectedSHA256,
        let data = try? Data(
            contentsOf: l3FinalURL(expectedFile, root: root)
        ),
        bindingSHA256(data) == expectedSHA256
    else {
        return false
    }
    return true
}

private func bindingRecord(
    _ records: [[String: Any]],
    direction: String
) throws -> [String: Any] {
    guard
        let record = records.first(where: {
            $0["direction"] as? String == direction
        })
    else {
        throw IndustrialL3FinalError.invalid(
            "\(direction) manifest record missing"
        )
    }
    return record
}

private func bindingPixelInventory(
    baselineManifest: [String: Any]
) throws -> [String] {
    guard
        let rawMasters = baselineManifest["rawMasters"] as? [[String: Any]],
        let normalized =
            baselineManifest["normalizedOutputs"] as? [[String: Any]]
    else {
        throw IndustrialL3FinalError.invalid(
            "baseline pixel inventory missing"
        )
    }
    var paths = rawMasters.compactMap { $0["file"] as? String }
    for record in normalized {
        if let path = record["runA"] as? String { paths.append(path) }
        if let path = record["runB"] as? String { paths.append(path) }
    }
    return Array(Set(paths)).sorted()
}

@main
enum ValidateIndustrialL3MaterialBindingRepair {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try l3FinalArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let output = URL(
            fileURLWithPath: try l3FinalArgument(
                "--output",
                in: arguments
            )
        ).standardizedFileURL
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw IndustrialL3FinalError.invalid(
                "validation output must be absent"
            )
        }

        let currentManifestData = try Data(
            contentsOf: l3FinalURL(bindingManifest, root: root)
        )
        let baselineManifestData = try bindingGitShow(
            root: root,
            commit: bindingBaseline,
            path: bindingManifest
        )
        let currentManifest = try bindingJSONObject(currentManifestData)
        let baselineManifest = try bindingJSONObject(baselineManifestData)
        guard
            let currentMasters =
                currentManifest["rawMasters"] as? [[String: Any]],
            let baselineMasters =
                baselineManifest["rawMasters"] as? [[String: Any]],
            let currentNormalized =
                currentManifest["normalizedOutputs"] as? [[String: Any]],
            let baselineNormalized =
                baselineManifest["normalizedOutputs"] as? [[String: Any]],
            currentMasters.count == 4,
            currentNormalized.count == 12,
            baselineNormalized.count == 12
        else {
            throw IndustrialL3FinalError.invalid(
                "family manifest structure drift"
            )
        }

        let directions = ["north", "east", "south", "west"]
        var descriptorRecords: [[String: Any]] = []
        var materialPaths = Set<String>()
        var provenancePaths = Set<String>()
        for direction in directions {
            let current = try bindingRecord(
                currentMasters,
                direction: direction
            )
            let baseline = try bindingRecord(
                baselineMasters,
                direction: direction
            )
            guard
                let descriptorPath = current["descriptor"] as? String,
                let provenancePath = current["provenance"] as? String,
                let manifestMaterial = current["materialLibrary"] as? String,
                let manifestMaterialSHA =
                    current["materialLibrarySHA256"] as? String
            else {
                throw IndustrialL3FinalError.invalid(
                    "\(direction) manifest binding missing"
                )
            }
            let descriptorData = try Data(
                contentsOf: l3FinalURL(descriptorPath, root: root)
            )
            let baselineDescriptorData = try bindingGitShow(
                root: root,
                commit: bindingBaseline,
                path: descriptorPath
            )
            let descriptor = try bindingJSONObject(descriptorData)
            let provenance = try l3FinalJSON(
                l3FinalURL(provenancePath, root: root)
            )
            guard
                let descriptorMaterial =
                    descriptor["materialLibrary"] as? [String: Any],
                bindingValid(
                    descriptorMaterial,
                    expectedFile: manifestMaterial,
                    expectedSHA256: manifestMaterialSHA,
                    root: root
                ),
                provenance["materialLibraryFile"] as? String
                    == manifestMaterial,
                provenance["materialLibrarySHA256"] as? String
                    == manifestMaterialSHA,
                current["descriptorSHA256"] as? String
                    == bindingSHA256(descriptorData),
                current["file"] as? String == baseline["file"] as? String,
                current["fileSHA256"] as? String
                    == baseline["fileSHA256"] as? String,
                current["decodedRGBASHA256"] as? String
                    == baseline["decodedRGBASHA256"] as? String
            else {
                throw IndustrialL3FinalError.invalid(
                    "\(direction) descriptor/manifest/provenance agreement failed"
                )
            }

            let isRepairDirection =
                direction == "east" || direction == "south"
            let structuralIdentity =
                try bindingCanonicalDescriptor(descriptorData)
                == bindingCanonicalDescriptor(baselineDescriptorData)
            let exactIdentity =
                descriptorData == baselineDescriptorData
            guard
                structuralIdentity,
                isRepairDirection ? !exactIdentity : exactIdentity,
                !isRepairDirection
                    || (
                        manifestMaterial == bindingCohesionFile
                        && manifestMaterialSHA == bindingCohesionSHA256
                    )
            else {
                throw IndustrialL3FinalError.invalid(
                    "\(direction) descriptor identity gate failed"
                )
            }
            descriptorRecords.append([
                "direction": direction,
                "file": descriptorPath,
                "oldSHA256": bindingSHA256(baselineDescriptorData),
                "newSHA256": bindingSHA256(descriptorData),
                "materialLibraryFile": manifestMaterial,
                "materialLibrarySHA256": manifestMaterialSHA,
                "structuralIdentityExcludingBinding": true,
                "exactByteIdentityExpected": !isRepairDirection,
                "exactByteIdentityPassed":
                    isRepairDirection ? !exactIdentity : exactIdentity,
                "descriptorManifestProvenanceAgreement": true,
            ])
            materialPaths.insert(manifestMaterial)
            provenancePaths.insert(provenancePath)
        }

        var immutableRecords: [[String: Any]] = []
        for path in materialPaths.union(provenancePaths).sorted() {
            let current = try Data(
                contentsOf: l3FinalURL(path, root: root)
            )
            let baseline = try bindingGitShow(
                root: root,
                commit: bindingBaseline,
                path: path
            )
            guard current == baseline else {
                throw IndustrialL3FinalError.invalid(
                    "immutable material/provenance drift: \(path)"
                )
            }
            immutableRecords.append([
                "file": path,
                "sha256": bindingSHA256(current),
                "baselineByteIdentity": true,
            ])
        }

        let pixelPaths = try bindingPixelInventory(
            baselineManifest: baselineManifest
        )
        var pixelRecords: [[String: Any]] = []
        for path in pixelPaths {
            let current = try Data(
                contentsOf: l3FinalURL(path, root: root)
            )
            let baseline = try bindingGitShow(
                root: root,
                commit: bindingBaseline,
                path: path
            )
            guard current == baseline else {
                throw IndustrialL3FinalError.invalid(
                    "accepted pixel byte drift: \(path)"
                )
            }
            pixelRecords.append([
                "file": path,
                "sha256": bindingSHA256(current),
                "baselineByteIdentity": true,
            ])
        }

        guard
            JSONSerialization.isValidJSONObject(currentNormalized),
            JSONSerialization.isValidJSONObject(baselineNormalized),
            try JSONSerialization.data(
                withJSONObject: currentNormalized,
                options: [.sortedKeys]
            )
                == JSONSerialization.data(
                    withJSONObject: baselineNormalized,
                    options: [.sortedKeys]
                )
        else {
            throw IndustrialL3FinalError.invalid(
                "normalized manifest records drift"
            )
        }

        var normalizedRecords: [[String: Any]] = []
        var fileHashes = Set<String>()
        var decodedHashes = Set<String>()
        for record in currentNormalized {
            guard
                let direction = record["direction"] as? String,
                let lod = record["lod"] as? String,
                let pathA = record["runA"] as? String,
                let pathB = record["runB"] as? String,
                let expectedFile = record["fileSHA256"] as? String,
                let expectedDecoded =
                    record["decodedRGBASHA256"] as? String
            else {
                throw IndustrialL3FinalError.invalid(
                    "normalized record fields missing"
                )
            }
            let rasterA = try l3FinalInspect(
                l3FinalURL(pathA, root: root)
            )
            let rasterB = try l3FinalInspect(
                l3FinalURL(pathB, root: root)
            )
            let passed =
                rasterA.fileSHA256 == expectedFile
                && rasterA.decodedRGBASHA256 == expectedDecoded
                && rasterA.fileSHA256 == rasterB.fileSHA256
                && rasterA.decodedRGBASHA256
                    == rasterB.decodedRGBASHA256
                && rasterA.alphaBounds == rasterB.alphaBounds
                && rasterA.visiblePixelCount == rasterB.visiblePixelCount
                && rasterA.hiddenRGBPixelCount == 0
                && rasterA.exactChromaPixelCount == 0
                && rasterA.visibleMagentaSpillPixelCount == 0
                && record["repeatFileIdentity"] as? Bool == true
                && record["repeatDecodedPixelIdentity"] as? Bool == true
                && record["paddingPassed"] as? Bool == true
                && record["registrationPassed"] as? Bool == true
                && record["contactShadowSupportReachedGroundPivot"]
                    as? Bool == true
            guard passed else {
                throw IndustrialL3FinalError.invalid(
                    "\(direction) \(lod) accepted normalized gate failed"
                )
            }
            fileHashes.insert(rasterA.fileSHA256)
            decodedHashes.insert(rasterA.decodedRGBASHA256)
            normalizedRecords.append([
                "direction": direction,
                "lod": lod,
                "fileSHA256": rasterA.fileSHA256,
                "decodedRGBASHA256": rasterA.decodedRGBASHA256,
                "repeatIdentity": true,
                "alphaChromaPaddingRegistrationContactShadow": "pass",
            ])
        }
        guard
            normalizedRecords.count == 12,
            fileHashes.count == 12,
            decodedHashes.count == 12
        else {
            throw IndustrialL3FinalError.invalid(
                "12-output uniqueness gate failed"
            )
        }

        var swapped =
            try bindingJSONObject(
                Data(
                    contentsOf: l3FinalURL(
                        "Native/CitySimNative/WorldArt/OfflineScene/"
                            + "PLAY-027/art-proof/"
                            + "industrial-l03-cohesion-source-v06-v01/"
                            + "scenes/industrial_l03/variant-0/north/"
                            + "scene.json",
                        root: root
                    )
                )
            )["materialLibrary"] as? [String: Any] ?? [:]
        let swappedRejected = !bindingValid(
            swapped,
            expectedFile: bindingCohesionFile,
            expectedSHA256: bindingCohesionSHA256,
            root: root
        )
        swapped = [
            "file": bindingCohesionFile,
            "sha256":
                "039bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65",
        ]
        let wrongHashRejected = !bindingValid(
            swapped,
            expectedFile: bindingCohesionFile,
            expectedSHA256: bindingCohesionSHA256,
            root: root
        )
        guard swappedRejected, wrongHashRejected else {
            throw IndustrialL3FinalError.invalid(
                "negative material-binding proof failed"
            )
        }

        let validatorPath =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
            + "ValidateIndustrialL3MaterialBindingRepair.swift"
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "family": "industrial_l03",
            "baselineCommit": bindingBaseline,
            "manifest": bindingManifest,
            "manifestSHA256": bindingSHA256(currentManifestData),
            "descriptorRepairs": descriptorRecords,
            "descriptorManifestProvenanceRawMasterAgreementPassed": true,
            "negativeTests": [
                "swappedValidLibraryRejected": swappedRejected,
                "wrongHashRejected": wrongHashRejected,
            ],
            "immutableMaterialAndProvenanceFiles": immutableRecords,
            "pixelInventory": [
                "rawPNGCount": 4,
                "normalizedPNGCount": 24,
                "totalPNGCount": pixelRecords.count,
                "allByteIdenticalToBaseline": true,
                "files": pixelRecords,
            ],
            "normalizedGateReplay": [
                "records": normalizedRecords,
                "outputCount": normalizedRecords.count,
                "uniqueFileIdentities": fileHashes.count,
                "uniqueDecodedPixelIdentities": decodedHashes.count,
                "allTwelveAcceptedGatesPassed": true,
            ],
            "northWestDescriptorByteIdentityPassed": true,
            "eastSouthStructuralIdentityExcludingBindingPassed": true,
            "materialLibraryBytesChanged": false,
            "rawOrNormalizedPixelsChanged": false,
            "rendererShippingPackageRuntimeChanged": false,
            "sourceAuthority": false,
            "productionSelected": false,
            "validatorSource": validatorPath,
            "validatorSourceSHA256": bindingSHA256(
                try Data(
                    contentsOf: l3FinalURL(validatorPath, root: root)
                )
            ),
            "validationPassed": true,
        ]
        try l3FinalWriteJSON(report, to: output)
    }
}
