import CoreGraphics
import CryptoKit
import Foundation

enum IndustrialL2V8EastFiniteEquivalenceError:
    Error,
    CustomStringConvertible
{
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

struct IndustrialL2FiniteRGBApplicationDescriptor: Codable, Equatable {
    var alphaWrites: Bool
    var ambiguousClassPolicy: String
    var channels: String
    var coordinateScope: String
    var crossRunState: String
    var exactChromaPolicy: String
    var geometryWrites: Bool
    var inputHashDriftPolicy: String
    var registrationWrites: Bool
    var requiresAlpha: Int
    var singleFramePureTransform: Bool
    var unknownTuplePolicy: String
}

struct IndustrialL2FiniteRGBDerivationDescriptor: Codable, Equatable {
    var derivationUsesCrossRunEvidence: Bool
    var inputCount: Int
    var pixelAlignment: String
    var unstableAlphaCoordinateCount: Int
    var unstableBounds4x: [Int]
    var unstableChromaCoordinateCount: Int
    var unstableCoordinateCount: Int
}

struct IndustrialL2FiniteRGBMemberDescriptor: Codable, Equatable {
    var rgb: [Int]
    var unstableObservationCount: Int
}

struct IndustrialL2FiniteRGBClassDescriptor: Codable, Equatable {
    var id: String
    var members: [IndustrialL2FiniteRGBMemberDescriptor]
    var representativeRGB: [Int]
    var representativeRule: String
}

struct IndustrialL2FiniteRGBCoordinateDescriptor: Codable, Equatable {
    var allowedRGB: [[Int]]
    var classID: String
    var coordinate4x: [Int]
    var representativeRGB: [Int]
    var unknownTuplePolicy: String
}

struct IndustrialL2FiniteRGBEquivalenceTable: Codable, Equatable {
    var application: IndustrialL2FiniteRGBApplicationDescriptor
    var classCount: Int
    var classes: [IndustrialL2FiniteRGBClassDescriptor]
    var contractID: String
    var coordinates: [IndustrialL2FiniteRGBCoordinateDescriptor]
    var derivation: IndustrialL2FiniteRGBDerivationDescriptor
    var productionSelected: Bool
    var schema: Int
    var task: String
    var tupleCount: Int
}

struct IndustrialL2FiniteRGBMutation: Equatable {
    let x: Int
    let y: Int
    let classID: String
    let originalRGB: [Int]
    let representativeRGB: [Int]
}

struct IndustrialL2FiniteRGBApplicationResult {
    let image: CGImage
    let inputDecodedRGBASHA256: String
    let mappedDecodedRGBASHA256: String
    let mutations: [IndustrialL2FiniteRGBMutation]
}

enum IndustrialL2V8EastFiniteEquivalenceContract {
    static let contractID =
        "industrial-l02-source-v08-equivalent-east-finite-rgb-validation-v1"
    static let tableContractID =
        "industrial-l02-source-v06-east-finite-rgb-equivalence-proposal-v1"
    static let evidenceRoot =
        "docs/production/evidence/PLAY-027/industrial-l02/l02/"
        + "source-v08-finite-equivalence-validation/diagnostics"
    static let diagnosticScenePath =
        "/tmp/"
        + "play027-industrial-l02-source-v06-equivalence-input/"
        + "scene.json"
    static let materialPath =
        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/materials/"
        + "industrial-l02-v0-source-v05-materials.json"
    static let tablePath =
        "docs/production/evidence/PLAY-027/industrial-l02/l02/"
        + "source-v06-finite-equivalence-diagnostic/proposal/"
        + "FINITE-RGB-EQUIVALENCE-TABLE.json"
    static let sceneSHA256 =
        "70b36a0e76581524e64d40f19e364659eed6a53d7f7ab8d8924c51ba5d0951dd"
    static let materialSHA256 =
        "4f4e34aa87891d70c442e596315bcbd474f059638c0af69abe6ecaac17af0815"
    static let tableSHA256 =
        "7c2d5940b8fca22d1e2cb15fa248ab678e8b8266fb3ed453332d82474284ed31"
    static let targetCoordinate = [707, 687]
    static let expectedViewportPixels = [1536, 1024]
    static let expectedFramePixels = [6144, 4096]
    static let expectedPostProjectionOffsetPixels = [0.0, 256.0]
    static let expectedLinearOversamplingFactor = 4
    static let expectedCoordinateCount = 57
    static let expectedClassCount = 2
    static let expectedTupleCount = 15

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map {
            String(format: "%02x", $0)
        }.joined()
    }

    static func canonicalRGBA(image: CGImage) throws -> [UInt8] {
        var rgba = [UInt8](
            repeating: 0,
            count: image.width * image.height * 4
        )
        let rendered = rgba.withUnsafeMutableBytes {
            storage -> Bool in
            guard let context = CGContext(
                data: storage.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo:
                    CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                return false
            }
            context.interpolationQuality = .none
            context.draw(
                image,
                in: CGRect(
                    x: 0,
                    y: 0,
                    width: image.width,
                    height: image.height
                )
            )
            return true
        }
        guard rendered else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "could not decode finite equivalence image"
            )
        }
        return rgba
    }

    private static func relativePath(
        _ url: URL,
        repositoryRoot: URL
    ) -> String? {
        let root = repositoryRoot.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(root) else {
            return nil
        }
        return String(path.dropFirst(root.count))
    }

    private static func validatedRGB(
        _ rgb: [Int],
        label: String
    ) throws -> UInt32 {
        guard
            rgb.count == 3,
            rgb.allSatisfy({ (0...255).contains($0) })
        else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "\(label) must be one RGB8 tuple"
            )
        }
        return UInt32(rgb[0]) << 16
            | UInt32(rgb[1]) << 8
            | UInt32(rgb[2])
    }

    static func loadValidatedTable(
        data: Data,
        expectedSHA256: String = tableSHA256
    ) throws -> IndustrialL2FiniteRGBEquivalenceTable {
        guard sha256(data) == expectedSHA256 else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "finite equivalence table hash drifted"
            )
        }
        let table = try JSONDecoder().decode(
            IndustrialL2FiniteRGBEquivalenceTable.self,
            from: data
        )
        guard
            table.schema == 1,
            table.task == "PLAY-027",
            table.contractID == tableContractID,
            table.productionSelected == false,
            table.classCount == expectedClassCount,
            table.classes.count == expectedClassCount,
            table.tupleCount == expectedTupleCount,
            table.coordinates.count == expectedCoordinateCount,
            table.derivation.inputCount == 3,
            table.derivation.pixelAlignment
                == "exact 6144x4096 top-left RGBA",
            table.derivation.unstableAlphaCoordinateCount == 0,
            table.derivation.unstableChromaCoordinateCount == 0,
            table.derivation.unstableCoordinateCount
                == expectedCoordinateCount,
            table.application.alphaWrites == false,
            table.application.channels == "rgb-only",
            table.application.crossRunState == "none",
            table.application.exactChromaPolicy
                == "bypass-byte-exact",
            table.application.geometryWrites == false,
            table.application.inputHashDriftPolicy == "reject",
            table.application.registrationWrites == false,
            table.application.requiresAlpha == 255,
            table.application.singleFramePureTransform,
            table.application.ambiguousClassPolicy == "reject"
        else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "finite equivalence table contract drifted"
            )
        }

        var classIDs = Set<String>()
        var tupleOwners: [UInt32: String] = [:]
        var tupleCount = 0
        var representatives: [String: UInt32] = [:]
        for rgbClass in table.classes {
            guard classIDs.insert(rgbClass.id).inserted else {
                throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                    "duplicate equivalence class identifier"
                )
            }
            let representative = try validatedRGB(
                rgbClass.representativeRGB,
                label: "class representative"
            )
            representatives[rgbClass.id] = representative
            guard
                rgbClass.representativeRule
                    == "unique highest observation count across exact unstable coordinates; ties reject",
                !rgbClass.members.isEmpty
            else {
                throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                    "ambiguous equivalence representative"
                )
            }
            let maximum = rgbClass.members.map(
                \.unstableObservationCount
            ).max()
            let winners = rgbClass.members.filter {
                $0.unstableObservationCount == maximum
            }
            guard
                winners.count == 1,
                try validatedRGB(
                    winners[0].rgb,
                    label: "class winner"
                ) == representative
            else {
                throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                    "equivalence representative is not uniquely derived"
                )
            }
            for member in rgbClass.members {
                let key = try validatedRGB(
                    member.rgb,
                    label: "class member"
                )
                guard
                    member.unstableObservationCount > 0,
                    tupleOwners[key] == nil
                else {
                    throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                        "tuple belongs to multiple or invalid classes"
                    )
                }
                tupleOwners[key] = rgbClass.id
                tupleCount += 1
            }
        }
        guard tupleCount == expectedTupleCount else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "finite equivalence tuple count drifted"
            )
        }

        var coordinates = Set<Int>()
        for coordinate in table.coordinates {
            guard
                coordinate.coordinate4x.count == 2,
                (0..<expectedFramePixels[0]).contains(
                    coordinate.coordinate4x[0]
                ),
                (0..<expectedFramePixels[1]).contains(
                    coordinate.coordinate4x[1]
                ),
                coordinate.unknownTuplePolicy == "reject",
                let representative = representatives[
                    coordinate.classID
                ],
                try validatedRGB(
                    coordinate.representativeRGB,
                    label: "coordinate representative"
                ) == representative,
                !coordinate.allowedRGB.isEmpty
            else {
                throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                    "invalid governed coordinate"
                )
            }
            let linear =
                coordinate.coordinate4x[1] * expectedFramePixels[0]
                + coordinate.coordinate4x[0]
            guard coordinates.insert(linear).inserted else {
                throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                    "duplicate governed coordinate"
                )
            }
            var allowed = Set<UInt32>()
            for rgb in coordinate.allowedRGB {
                let key = try validatedRGB(
                    rgb,
                    label: "coordinate allowed tuple"
                )
                guard
                    allowed.insert(key).inserted,
                    tupleOwners[key] == coordinate.classID
                else {
                    throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                        "ambiguous or duplicate coordinate tuple"
                    )
                }
            }
        }
        return table
    }

    static func apply(
        image: CGImage,
        table: IndustrialL2FiniteRGBEquivalenceTable,
        expectedInputDecodedRGBASHA256: String
    ) throws -> IndustrialL2FiniteRGBApplicationResult {
        guard
            image.width == expectedFramePixels[0],
            image.height == expectedFramePixels[1]
        else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "finite equivalence input dimensions drifted"
            )
        }
        let source = try canonicalRGBA(image: image)
        let inputHash = sha256(Data(source))
        guard inputHash == expectedInputDecodedRGBASHA256 else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "finite equivalence input decoded hash drifted"
            )
        }
        var mapped = source
        var mutations: [IndustrialL2FiniteRGBMutation] = []
        mutations.reserveCapacity(table.coordinates.count)
        for coordinate in table.coordinates {
            let x = coordinate.coordinate4x[0]
            let y = coordinate.coordinate4x[1]
            let offset = (y * image.width + x) * 4
            let original = [
                Int(source[offset]),
                Int(source[offset + 1]),
                Int(source[offset + 2]),
            ]
            guard source[offset + 3] == 255 else {
                throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                    "governed coordinate is not fully opaque"
                )
            }
            guard original != [255, 0, 255] else {
                throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                    "governed coordinate is exact chroma"
                )
            }
            guard coordinate.allowedRGB.contains(original) else {
                throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                    "unknown tuple at governed coordinate \(x),\(y)"
                )
            }
            let replacement = coordinate.representativeRGB
            if original != replacement {
                mapped[offset] = UInt8(replacement[0])
                mapped[offset + 1] = UInt8(replacement[1])
                mapped[offset + 2] = UInt8(replacement[2])
                mutations.append(
                    IndustrialL2FiniteRGBMutation(
                        x: x,
                        y: y,
                        classID: coordinate.classID,
                        originalRGB: original,
                        representativeRGB: replacement
                    )
                )
            }
        }
        for pixel in stride(from: 0, to: source.count, by: 4) {
            guard mapped[pixel + 3] == source[pixel + 3] else {
                throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                    "finite equivalence attempted an alpha write"
                )
            }
            if
                source[pixel] == 255,
                source[pixel + 1] == 0,
                source[pixel + 2] == 255
            {
                guard
                    mapped[pixel] == source[pixel],
                    mapped[pixel + 1] == source[pixel + 1],
                    mapped[pixel + 2] == source[pixel + 2]
                else {
                    throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                        "finite equivalence attempted a chroma write"
                    )
                }
            }
        }
        guard
            let provider = CGDataProvider(
                data: Data(mapped) as CFData
            ),
            let output = CGImage(
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(
                    rawValue:
                        CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "could not create mapped 4x image"
            )
        }
        return IndustrialL2FiniteRGBApplicationResult(
            image: output,
            inputDecodedRGBASHA256: inputHash,
            mappedDecodedRGBASHA256: sha256(Data(mapped)),
            mutations: mutations
        )
    }

    static func validate(
        requestedContractID: String?,
        repositoryRoot: URL,
        sceneURL: URL,
        sceneFileSHA256: String,
        materialsURL: URL,
        materialFileSHA256: String,
        outputURL: URL,
        recordURL: URL,
        stageCaptureDirectory: URL?,
        stageCoordinate: [Int]?,
        diagnosticPrequantizedOutput: URL?,
        explicitAntialiasing: String?,
        explicitSceneShadows: String?,
        explicitMaterialLighting: String?,
        descriptor: SceneDescriptor,
        sampling: EffectiveSamplingContract
    ) throws -> IndustrialL2V5EastSceneKitLanczosRecord? {
        guard let requestedContractID else {
            return nil
        }
        guard requestedContractID == contractID else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "unknown Industrial L2 finite equivalence validation contract"
            )
        }
        guard
            descriptor.logicalBuildingID == "industrial_l02",
            descriptor.variantID == "variant-0",
            descriptor.sourceRevision == "source-v06",
            descriptor.viewDirection == "east",
            descriptor.productionSelected == false,
            descriptor.camera.renderViewportPixels
                == expectedViewportPixels,
            descriptor.camera.oversamplingFactor
                == expectedLinearOversamplingFactor,
            descriptor.camera.postProjectionOffsetPixels
                == expectedPostProjectionOffsetPixels
        else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "validation requires frozen Industrial L2 source-v06 East"
            )
        }
        guard
            explicitAntialiasing == "none",
            explicitSceneShadows == "current",
            explicitMaterialLighting == "current",
            stageCoordinate == targetCoordinate,
            let stageCaptureDirectory,
            let diagnosticPrequantizedOutput
        else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "validation requires explicit none/current/current, coordinate 707,687, and prequantized capture"
            )
        }
        guard
            sampling.contractID
                == DescriptorSamplingResolver.schema2ContractV3ID,
            sampling.descriptorSchema == 2,
            sampling.purpose == "source-authority",
            sampling.sceneKitAntialiasing == "none",
            sampling.sceneKitShadows == "disabled",
            sampling.sceneKitLightingMode == "authored-constant-v1",
            sampling.linearOversamplingFactor == 4,
            sampling.downsampleFilter == "CILanczosScaleTransform",
            sampling.downsampleScale == 0.25,
            sampling.downsampleAspectRatio == 1,
            sampling.ciUseSoftwareRenderer,
            sampling.ciCacheIntermediates == false,
            sampling.ciWorkingColorSpace == "extended-srgb",
            sampling.ciOutputColorSpace == "srgb",
            sampling.quantizerID == "step32-midpoint-offset8-v1",
            sampling.quantizerStep == 32,
            sampling.quantizerMidpointOffset == 8,
            sampling.chromaBypassRGBA == [255, 0, 255, 255],
            sampling.canonicalizerID == "imageio-sips-png-v1",
            sampling.canonicalizerEncoder == "ImageIO",
            sampling.canonicalizerPostEncoder == "/usr/bin/sips",
            sampling.canonicalizerFormat == "png",
            sampling.postQuantizationCanonicalizer?.version == 3,
            sampling.preLanczosCanonicalizer == nil
        else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "source-v06 sampling contract drifted"
            )
        }
        let tableURL = repositoryRoot.appendingPathComponent(tablePath)
        guard
            sceneURL.path == diagnosticScenePath,
            sceneFileSHA256 == sceneSHA256,
            relativePath(materialsURL, repositoryRoot: repositoryRoot)
                == materialPath,
            materialFileSHA256 == materialSHA256,
            FileManager.default.fileExists(atPath: tableURL.path),
            try sha256(Data(contentsOf: tableURL)) == tableSHA256
        else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "descriptor, material, or finite table path/hash drifted"
            )
        }
        _ = try loadValidatedTable(data: Data(contentsOf: tableURL))
        guard
            let captureRelative = relativePath(
                stageCaptureDirectory,
                repositoryRoot: repositoryRoot
            ),
            let outputRelative = relativePath(
                outputURL,
                repositoryRoot: repositoryRoot
            ),
            let recordRelative = relativePath(
                recordURL,
                repositoryRoot: repositoryRoot
            ),
            let prequantizedRelative = relativePath(
                diagnosticPrequantizedOutput,
                repositoryRoot: repositoryRoot
            ),
            ["run-a", "run-b", "run-c"].contains(
                stageCaptureDirectory.lastPathComponent
            ),
            (captureRelative as NSString).deletingLastPathComponent
                == evidenceRoot,
            outputRelative == captureRelative + "/final-sips.png",
            recordRelative == captureRelative + "/provenance.json",
            prequantizedRelative
                == captureRelative
                    + "/POST-LANCZOS-PREQUANTIZED.png",
            !FileManager.default.fileExists(
                atPath: stageCaptureDirectory.path
            )
        else {
            throw IndustrialL2V8EastFiniteEquivalenceError.invalid(
                "validation requires one new exact run-a, run-b, or run-c directory"
            )
        }
        let geometry = try IndustrialL2V5EastSceneKitLanczosContract
            .supportGeometry(
                outputTargetCoordinate: targetCoordinate,
                viewportPixels: descriptor.camera.renderViewportPixels,
                postProjectionOffsetPixels:
                    descriptor.camera.postProjectionOffsetPixels,
                linearOversamplingFactor:
                    sampling.linearOversamplingFactor
            )
        return IndustrialL2V5EastSceneKitLanczosRecord(
            value: [
                "contractID": contractID,
                "purpose":
                    "validate a source-v08-equivalent East-only finite RGB equivalence sampling contract",
                "sourceAuthority": false,
                "descriptorChanged": false,
                "materialsChanged": false,
                "geometryChanged": false,
                "cameraChanged": false,
                "registrationChanged": false,
                "lightingChanged": false,
                "shadowsChanged": false,
                "samplerChanged": true,
                "finiteTableFile": tablePath,
                "finiteTableSHA256": tableSHA256,
                "sceneDescriptorSHA256": sceneSHA256,
                "materialLibrarySHA256": materialSHA256,
                "governedCoordinateCount": expectedCoordinateCount,
                "classCount": expectedClassCount,
                "tupleCount": expectedTupleCount,
                "crossRunState": "none",
                "passThroughElsewhere": "byte-exact",
                "unknownTuplePolicy": "reject",
                "persistCompletePreMap4xRGBA": true,
                "persistCompleteMapped4xRGBA": true,
                "productionSelected": false,
            ],
            supportGeometry: geometry
        )
    }
}
