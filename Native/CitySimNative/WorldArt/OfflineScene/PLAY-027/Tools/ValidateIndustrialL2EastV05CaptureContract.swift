import CryptoKit
import Foundation

enum IndustrialL2EastV05CaptureValidationError: Error {
    case invalid(String)
}

private func captureValidationArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2EastV05CaptureValidationError.invalid(
            "missing \(name)"
        )
    }
    return arguments[index + 1]
}

private func captureValidationSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

@main
enum ValidateIndustrialL2EastV05CaptureContractMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath:
                try captureValidationArgument(
                    "--repository-root",
                    in: arguments
                )
        ).standardizedFileURL
        let output = URL(
            fileURLWithPath:
                try captureValidationArgument("--output", in: arguments)
        ).standardizedFileURL
        guard
            output.path
                == root.path
                    + "/docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05/raw-calibration/preflight/CAPTURE-CONTRACT-VALIDATION.json",
            !FileManager.default.fileExists(atPath: output.path)
        else {
            throw IndustrialL2EastV05CaptureValidationError.invalid(
                "output path must be exact and absent"
            )
        }
        let sceneURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialsURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/materials/industrial-l02-east-calibration-v05.json"
        )
        let sceneData = try Data(contentsOf: sceneURL)
        let materialData = try Data(contentsOf: materialsURL)
        guard
            captureValidationSHA256(sceneData)
                == "482bea0169e9229df437b05ca6f0299046d49bb92e2e9d9ef4f3865df9be5fa0",
            captureValidationSHA256(materialData)
                == "6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb"
        else {
            throw IndustrialL2EastV05CaptureValidationError.invalid(
                "frozen input hash drift"
            )
        }
        let descriptor = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: sceneData
        )
        let materials = try JSONDecoder().decode(
            MaterialLibraryDescriptor.self,
            from: materialData
        )
        let sampling = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        let recognizedPatterns: Set<String> = [
            "solid-depth-cavity",
            "horizontal-section-joints",
            "procedural-vertical-corrugation",
            "procedural-formed-concrete",
            "rolled-membrane-seams",
            "large-scored-slabs",
            "muted-mullion-grid",
            "muted-warm-glazing",
            "fine-galvanized",
            "painted-steel",
            "solid-safety-paint",
        ]
        let unknownPatterns = Set(
            materials.materials.map(\.pattern)
        ).subtracting(recognizedPatterns)
        let passed =
            descriptor.sourceRevision
                == "east-quality-calibration-art-proof-v05"
            && descriptor.sceneGeometryID
                == "industrial-l02-east-wide-low-capable-campus-geometry-v05"
            && sampling.contractID
                == "play027-deterministic-4x-no-msaa-lanczos-v3"
            && sampling.purpose == "diagnostic-regression"
            && sampling.sceneKitAntialiasing == "none"
            && sampling.linearOversamplingFactor == 4
            && sampling.downsampleFilter == "CILanczosScaleTransform"
            && sampling.downsampleScale == 0.25
            && unknownPatterns.isEmpty
            && materials.productionSelected == false
            && descriptor.productionSelected == false
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type":
                "industrial-l02-east-v05-capture-contract-validation",
            "passed": passed,
            "sceneDescriptorSHA256":
                captureValidationSHA256(sceneData),
            "materialLibrarySHA256":
                captureValidationSHA256(materialData),
            "materialDecoderPassed": true,
            "samplingResolverPassed": true,
            "effectiveSampling": [
                "contractID": sampling.contractID,
                "purpose": sampling.purpose,
                "sceneKitAntialiasing":
                    sampling.sceneKitAntialiasing,
                "linearOversamplingFactor":
                    sampling.linearOversamplingFactor,
                "downsampleFilter": sampling.downsampleFilter,
                "downsampleScale": sampling.downsampleScale,
            ],
            "unknownMaterialPatterns":
                unknownPatterns.sorted(),
            "metalProcesses": 0,
            "productionSelected": false,
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        try data.write(to: output, options: .atomic)
        guard passed else {
            throw IndustrialL2EastV05CaptureValidationError.invalid(
                "capture contract validation failed"
            )
        }
        print("PASS material-decoder sampling-resolver no-metal")
    }
}
