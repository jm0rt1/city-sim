import CryptoKit
import Foundation
import SceneKit

enum ExplicitBoxCapabilityValidationError:
    Error,
    CustomStringConvertible
{
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-explicit-box-prop-capability --repository-root <path> --output <json>"
        case let .invalid(message):
            return message
        }
    }
}

private let explicitBoxNorthDescriptorSHA256 =
    "c44e0eed41a06093cdfe533c8dbe92f0fd3fe69dac659a724245bf29a3941abd"
private let explicitBoxMaterialLibrarySHA256 =
    "6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb"
private let explicitBoxExpectedError =
    "explicit box dimensions must contain three positive values"

private func explicitBoxArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw ExplicitBoxCapabilityValidationError.arguments
    }
    return arguments[index + 1]
}

private func explicitBoxSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func explicitBoxSHA256(_ url: URL) throws -> String {
    explicitBoxSHA256(try Data(contentsOf: url))
}

private func explicitBoxClose(
    _ actual: Double,
    _ expected: Double,
    tolerance: Double = 0.000_01
) -> Bool {
    abs(actual - expected) <= tolerance
}

private func explicitBoxVector(
    _ value: SCNVector3
) -> [Double] {
    [Double(value.x), Double(value.y), Double(value.z)]
}

private func explicitBoxVectorsMatch(
    _ actual: [Double],
    _ expected: [Double]
) -> Bool {
    actual.count == expected.count
        && zip(actual, expected).allSatisfy {
            explicitBoxClose($0.0, $0.1)
        }
}

private func explicitBoxMutatedDescriptor(
    descriptorData: Data,
    dimensions: [Double]
) throws -> SceneDescriptor {
    guard
        var object = try JSONSerialization.jsonObject(
            with: descriptorData
        ) as? [String: Any],
        var props = object["props"] as? [[String: Any]],
        let index = props.firstIndex(where: {
            $0["kind"] as? String == "explicit-box"
        })
    else {
        throw ExplicitBoxCapabilityValidationError.invalid(
            "could not locate explicit-box prop for invalid-dimension proof"
        )
    }
    props[index]["dimensions"] = dimensions
    object["props"] = props
    return try JSONDecoder().decode(
        SceneDescriptor.self,
        from: JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    )
}

private func explicitBoxWriteJSON(
    _ object: Any,
    to url: URL
) throws {
    guard
        url.path.contains(
            "/docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v04/"
        ),
        !FileManager.default.fileExists(atPath: url.path)
    else {
        throw ExplicitBoxCapabilityValidationError.invalid(
            "output must be a new task-owned PLAY-027 evidence JSON"
        )
    }
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}

@main
enum ValidateExplicitBoxPropCapabilityMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try explicitBoxArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputURL = URL(
            fileURLWithPath: try explicitBoxArgument(
                "--output",
                in: arguments
            )
        ).standardizedFileURL
        let descriptorURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v04/scenes/industrial_l02/variant-0/north/scene.json"
        )
        let materialsURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/materials/industrial-l02-east-calibration-v05.json"
        )
        guard
            try explicitBoxSHA256(descriptorURL)
                == explicitBoxNorthDescriptorSHA256,
            try explicitBoxSHA256(materialsURL)
                == explicitBoxMaterialLibrarySHA256
        else {
            throw ExplicitBoxCapabilityValidationError.invalid(
                "frozen descriptor or material library drift"
            )
        }

        let descriptorData = try Data(contentsOf: descriptorURL)
        let materialsData = try Data(contentsOf: materialsURL)
        let decoder = JSONDecoder()
        let descriptor = try decoder.decode(
            SceneDescriptor.self,
            from: descriptorData
        )
        let materialDescriptor = try decoder.decode(
            MaterialLibraryDescriptor.self,
            from: materialsData
        )
        let builder = ContractSceneBuilder(
            materials: NativeMaterialLibrary(
                descriptor: materialDescriptor,
                repositoryRoot: repositoryRoot
            )
        )
        let scene = try builder.buildScene(from: descriptor)

        let boxProps = descriptor.props.filter {
            $0.kind == "explicit-box"
        }
        guard boxProps.count == 2 else {
            throw ExplicitBoxCapabilityValidationError.invalid(
                "North must contain exactly two explicit-box HVAC props"
            )
        }
        var boxRecords: [[String: Any]] = []
        for prop in boxProps {
            guard
                let node = scene.rootNode.childNode(
                    withName: prop.id,
                    recursively: false
                ),
                let geometry = node.geometry
            else {
                throw ExplicitBoxCapabilityValidationError.invalid(
                    "explicit-box node missing: \(prop.id)"
                )
            }
            let bounds = geometry.boundingBox
            let actualDimensions = [
                Double(bounds.max.x - bounds.min.x),
                Double(bounds.max.y - bounds.min.y),
                Double(bounds.max.z - bounds.min.z),
            ]
            let actualPosition = explicitBoxVector(node.position)
            let materialNames = geometry.materials.map {
                $0.name ?? ""
            }
            let expectedMaterialNames = (0..<6).map {
                "\(prop.materialID)-box-face-\($0)"
            }
            guard
                node.name == prop.id,
                explicitBoxVectorsMatch(
                    actualDimensions,
                    prop.dimensions
                ),
                explicitBoxVectorsMatch(
                    actualPosition,
                    prop.positionWorld
                ),
                materialNames == expectedMaterialNames,
                node.castsShadow
            else {
                throw ExplicitBoxCapabilityValidationError.invalid(
                    "explicit-box node contract mismatch: \(prop.id)"
                )
            }
            boxRecords.append([
                "id": prop.id,
                "nodeName": node.name ?? "",
                "expectedDimensions": prop.dimensions,
                "actualDimensions": actualDimensions,
                "expectedPositionWorld": prop.positionWorld,
                "actualPositionWorld": actualPosition,
                "materialID": prop.materialID,
                "materialNames": materialNames,
                "castsShadow": node.castsShadow,
                "passed": true,
            ])
        }

        let existingCylinderProps = descriptor.props.filter {
            $0.kind == "explicit-cylinder"
        }
        guard existingCylinderProps.count == 4 else {
            throw ExplicitBoxCapabilityValidationError.invalid(
                "North existing supported prop inventory drift"
            )
        }
        var cylinderRecords: [[String: Any]] = []
        for prop in existingCylinderProps {
            guard
                let node = scene.rootNode.childNode(
                    withName: prop.id,
                    recursively: false
                ),
                let cylinder = node.geometry as? SCNCylinder
            else {
                throw ExplicitBoxCapabilityValidationError.invalid(
                    "existing explicit-cylinder node missing: \(prop.id)"
                )
            }
            let expectedRadius =
                min(prop.dimensions[0], prop.dimensions[2]) / 2
            let actualPosition = explicitBoxVector(node.position)
            guard
                node.name == prop.id,
                explicitBoxClose(
                    Double(cylinder.radius),
                    expectedRadius
                ),
                explicitBoxClose(
                    Double(cylinder.height),
                    prop.dimensions[1]
                ),
                cylinder.radialSegmentCount == 32,
                cylinder.firstMaterial?.name == prop.materialID,
                explicitBoxVectorsMatch(
                    actualPosition,
                    prop.positionWorld
                ),
                node.castsShadow
            else {
                throw ExplicitBoxCapabilityValidationError.invalid(
                    "existing explicit-cylinder output changed: \(prop.id)"
                )
            }
            cylinderRecords.append([
                "id": prop.id,
                "nodeName": node.name ?? "",
                "radius": Double(cylinder.radius),
                "height": Double(cylinder.height),
                "radialSegmentCount": cylinder.radialSegmentCount,
                "positionWorld": actualPosition,
                "materialID": cylinder.firstMaterial?.name ?? "",
                "castsShadow": node.castsShadow,
                "passed": true,
            ])
        }

        let invalidCases: [[Double]] = [
            [7, 5],
            [7, 0, 7],
            [7, -1, 7],
        ]
        var invalidRecords: [[String: Any]] = []
        for dimensions in invalidCases {
            let invalidDescriptor = try explicitBoxMutatedDescriptor(
                descriptorData: descriptorData,
                dimensions: dimensions
            )
            let invalidBuilder = ContractSceneBuilder(
                materials: NativeMaterialLibrary(
                    descriptor: materialDescriptor,
                    repositoryRoot: repositoryRoot
                )
            )
            do {
                _ = try invalidBuilder.buildScene(
                    from: invalidDescriptor
                )
                throw ExplicitBoxCapabilityValidationError.invalid(
                    "invalid explicit-box dimensions unexpectedly passed: \(dimensions)"
                )
            } catch let error as OfflineRendererError {
                guard error.description == explicitBoxExpectedError else {
                    throw ExplicitBoxCapabilityValidationError.invalid(
                        "invalid explicit-box dimensions produced wrong error: \(error)"
                    )
                }
                invalidRecords.append([
                    "dimensions": dimensions,
                    "error": error.description,
                    "rejected": true,
                ])
            }
        }

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type":
                "industrial-l02-explicit-box-offline-prop-capability-validation",
            "descriptorSHA256":
                explicitBoxNorthDescriptorSHA256,
            "materialLibrarySHA256":
                explicitBoxMaterialLibrarySHA256,
            "explicitBoxNodeCount": boxRecords.count,
            "explicitBoxNodes": boxRecords,
            "invalidDimensionCases": invalidRecords,
            "existingSupportedPropKind":
                "explicit-cylinder",
            "existingSupportedPropNodeCount":
                cylinderRecords.count,
            "existingSupportedPropNodes":
                cylinderRecords,
            "existingSupportedPropOutputsUnchanged":
                true,
            "sceneKitSnapshotCount": 0,
            "metalProcessCount": 0,
            "rawPixelCount": 0,
            "productionSelected": false,
            "passed": true,
        ]
        try explicitBoxWriteJSON(report, to: outputURL)
        print(
            "PASS explicit-box nodes=2 invalid-dimensions=3 existing-explicit-cylinders=4"
        )
    }
}
