import CryptoKit
import Foundation

enum RasterProofValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l2-east-raster-survival-proof --repository-root <path> --scene <path> --materials <path>"
        case let .invalid(message):
            return message
        }
    }
}

private func proofArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw RasterProofValidationError.arguments
    }
    return arguments[index + 1]
}

private func proofSHA256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url))
        .map { String(format: "%02x", $0) }
        .joined()
}

private func proofApproximatelyEqual(
    _ first: [Double],
    _ second: [Double],
    tolerance: Double = 0.000_001
) -> Bool {
    first.count == second.count
        && zip(first, second).allSatisfy {
            abs($0 - $1) <= tolerance
        }
}

@main
enum ValidateIndustrialL2EastRasterSurvivalProofMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try proofArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let sceneURL = URL(
            fileURLWithPath: try proofArgument(
                "--scene",
                in: arguments
            )
        ).standardizedFileURL
        let materialsURL = URL(
            fileURLWithPath: try proofArgument(
                "--materials",
                in: arguments
            )
        ).standardizedFileURL
        let decoder = JSONDecoder()
        let scene = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: sceneURL)
        )
        let materials = try decoder.decode(
            MaterialLibraryDescriptor.self,
            from: Data(contentsOf: materialsURL)
        )
        let materialFileSHA256 = try proofSHA256(materialsURL)
        let sampling = try DescriptorSamplingResolver.resolve(
            descriptor: scene
        )
        let repositoryPrefix = root.path + "/"
        let materialIDs = Set(materials.materials.map(\.id))
        let usedMaterialIDs = Set(
            (scene.building.massBlocks ?? []).map(\.materialID)
                + scene.props.map(\.materialID)
                + [
                    scene.building.foundationMaterialID,
                    scene.building.wallMaterialID,
                    scene.building.trimMaterialID,
                    scene.building.roofMaterialID,
                    scene.entrance.doorMaterialID,
                    scene.entrance.surroundMaterialID,
                    scene.entrance.pavilionMaterialID,
                ]
        )
        let requiredComponents = Set([
            "proof-process-tower",
            "proof-production-hall",
            "proof-administration-wing",
            "proof-logistics-rear-wall",
            "proof-dock-door-a",
            "proof-dock-door-b",
            "proof-dock-door-c",
            "proof-dock-canopy-a",
            "proof-dock-canopy-b",
            "proof-dock-canopy-c",
            "proof-personnel-door",
            "proof-loading-apron",
        ])
        let componentIDs = Set(
            (scene.building.massBlocks ?? []).map(\.id)
                + scene.props.map(\.id)
        )
        guard
            sceneURL.path.hasPrefix(repositoryPrefix),
            materialsURL.path.hasPrefix(repositoryPrefix),
            scene.schema == 2,
            scene.task == "PLAY-027",
            scene.logicalBuildingID == "industrial_l02",
            scene.family == "industrial",
            scene.level == 2,
            scene.variantID == "variant-0",
            scene.viewDirection == "east",
            scene.sourceRevision == "art-proof-v01",
            scene.sceneGeometryID
                == "industrial-l02-east-raster-survival-art-proof-geometry-v01",
            scene.authoredIndependently,
            !scene.productionSelected,
            !materials.productionSelected,
            scene.derivation.siblingSource == nil,
            !scene.derivation.mirror,
            scene.derivation.rotationDegrees == 0,
            scene.derivation.transform == "none",
            scene.registration.orientationTransform == "none",
            scene.building.width == 56,
            scene.building.depth == 56,
            proofApproximatelyEqual(
                scene.building.foundationDimensions ?? [],
                [55, 3, 56]
            ),
            proofApproximatelyEqual(
                scene.building.foundationPositionWorld ?? [],
                [-0.5, 1.5, 0]
            ),
            proofApproximatelyEqual(
                scene.registration.contactPolygonWorld.flatMap { $0 },
                [-28, -28, 28, -28, 28, 28, -28, 28]
            ),
            proofApproximatelyEqual(
                scene.registration.frontageSocketSource,
                [896, 832]
            ),
            proofApproximatelyEqual(
                scene.registration.groundPivotSource,
                [768, 896]
            ),
            proofApproximatelyEqual(
                scene.registration.doorBaseSource.flatMap { $0 },
                [934, 813, 858, 851]
            ),
            scene.camera.projection == "orthographic-2:1",
            scene.camera.yawDegrees == 45,
            scene.camera.elevationDegrees == 30,
            abs(
                scene.camera.orthographicScale
                    - 158.39191898578665
            ) < 0.000_001,
            sampling.contractID
                == DescriptorSamplingResolver.schema2ContractV3ID,
            sampling.purpose == "diagnostic-regression",
            sampling.sceneKitAntialiasing == "none",
            sampling.sceneKitShadows == "current",
            sampling.sceneKitLightingMode == "lambert-scene-lights",
            sampling.linearOversamplingFactor == 4,
            sampling.downsampleFilter == "CILanczosScaleTransform",
            sampling.downsampleScale == 0.25,
            sampling.quantizerStep == 32,
            materials.imageGenMaterialSwatchesUsed == false,
            scene.materialLibrary.sha256 == materialFileSHA256,
            usedMaterialIDs.isSubset(of: materialIDs),
            requiredComponents.isSubset(of: componentIDs),
            (scene.building.massBlocks ?? []).count == 40,
            scene.props.count == 6
        else {
            throw RasterProofValidationError.invalid(
                "East raster-survival typed descriptor/material contract failed"
            )
        }
        print("typed descriptor decode PASS")
        print("schema-2 v3 diagnostic sampling PASS")
        print("registration/camera PASS")
        print("materials resolved \(usedMaterialIDs.count)/\(materialIDs.count)")
        print("components 46 required-large-form set PASS")
        print("scene \(try proofSHA256(sceneURL))")
        print("materials \(materialFileSHA256)")
        print("productionSelected=false")
    }
}
