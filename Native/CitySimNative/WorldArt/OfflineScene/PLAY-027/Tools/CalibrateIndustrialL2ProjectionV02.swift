import CryptoKit
import Foundation
import SceneKit

enum ProjectionCalibrationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: calibrate-industrial-l2-projection-v02 --repository-root <path> --output-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private let frozenProofDescriptorSHA256 =
    "2af1e6488ea5ff8e799bf44482d4061b1efa1a190a360a34a4bdef0dc6d849c2"
private let frozenProofRawSHA256 =
    "77d47f3feef50c584dfd60177e41ab6793247a6772c536270806a0c3196db5b8"
private let frozenProofMetricsSHA256 =
    "d06995080e99ae587b378eac70926433693b712d6af52f0f8e828667761f941d"
private let frozenPrepixelCommit =
    "920af3b8730a556c564daa56d9a0c9a4d451cf18"
private let frozenRejectionCommit =
    "3794912daa96e9b6c92d1baa5f56ae7888ab0d1c"

private struct ProjectionPoint {
    let world: [Double]
    let cameraLocal: [Double]
    let oversampledSceneKit: [Double]
    let downsampledSceneKit: [Double]
    let registeredSource: [Double]

    var dictionary: [String: Any] {
        [
            "world": world,
            "cameraLocal": cameraLocal,
            "oversampledSceneKit": oversampledSceneKit,
            "downsampledSceneKit": downsampledSceneKit,
            "registeredSource": registeredSource,
        ]
    }
}

private func calibrationArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw ProjectionCalibrationError.arguments
    }
    return arguments[index + 1]
}

private func calibrationSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func calibrationSHA256(_ url: URL) throws -> String {
    calibrationSHA256(try Data(contentsOf: url))
}

private func writeCalibrationJSON(
    _ value: Any,
    to url: URL
) throws {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}

private func relative(
    _ url: URL,
    root: URL
) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

private func doubles(
    _ object: [String: Any],
    _ key: String
) throws -> [Double] {
    guard let values = object[key] as? [Double] else {
        throw ProjectionCalibrationError.invalid(
            "camera field \(key) is missing or malformed"
        )
    }
    return values
}

private func project(
    world: [Double],
    cameraNode: SCNNode,
    orthographicScale: Double,
    viewport: [Int],
    oversampling: Int,
    downsampleScale: Double,
    postProjectionOffset: [Double]
) -> ProjectionPoint {
    let local = cameraNode.convertPosition(
        SCNVector3(world[0], world[1], world[2]),
        from: nil
    )
    let oversampledWidth = Double(viewport[0] * oversampling)
    let oversampledHeight = Double(viewport[1] * oversampling)
    let oversampledPixelsPerWorld =
        oversampledHeight / (2 * orthographicScale)
    let oversampledX =
        oversampledWidth / 2 + Double(local.x) * oversampledPixelsPerWorld
    let oversampledY =
        oversampledHeight / 2 - Double(local.y) * oversampledPixelsPerWorld
    let sourceX = oversampledX * downsampleScale
    let sourceY = oversampledY * downsampleScale
    return ProjectionPoint(
        world: world,
        cameraLocal: [
            Double(local.x),
            Double(local.y),
            Double(local.z),
        ],
        oversampledSceneKit: [oversampledX, oversampledY],
        downsampledSceneKit: [sourceX, sourceY],
        registeredSource: [
            sourceX + postProjectionOffset[0],
            sourceY + postProjectionOffset[1],
        ]
    )
}

private func footprintProjection(
    scale: Double,
    cameraNode: SCNNode,
    viewport: [Int],
    oversampling: Int,
    downsampleScale: Double,
    postProjectionOffset: [Double]
) -> (
    points: [ProjectionPoint],
    width: Double,
    height: Double
) {
    let corners = [
        [-28.0, 0.0, -28.0],
        [28.0, 0.0, -28.0],
        [28.0, 0.0, 28.0],
        [-28.0, 0.0, 28.0],
    ]
    let points = corners.map {
        project(
            world: $0,
            cameraNode: cameraNode,
            orthographicScale: scale,
            viewport: viewport,
            oversampling: oversampling,
            downsampleScale: downsampleScale,
            postProjectionOffset: postProjectionOffset
        )
    }
    let xs = points.map { $0.registeredSource[0] }
    let ys = points.map { $0.registeredSource[1] }
    return (
        points,
        xs.max()! - xs.min()!,
        ys.max()! - ys.min()!
    )
}

private func solveOrthographicScale(
    targetWidth: Double,
    cameraNode: SCNNode,
    viewport: [Int],
    oversampling: Int,
    downsampleScale: Double,
    postProjectionOffset: [Double]
) -> Double {
    var lower = 1.0
    var upper = 512.0
    for _ in 0..<100 {
        let candidate = (lower + upper) / 2
        let width = footprintProjection(
            scale: candidate,
            cameraNode: cameraNode,
            viewport: viewport,
            oversampling: oversampling,
            downsampleScale: downsampleScale,
            postProjectionOffset: postProjectionOffset
        ).width
        if width > targetWidth {
            lower = candidate
        } else {
            upper = candidate
        }
    }
    return (lower + upper) / 2
}

@main
enum CalibrateIndustrialL2ProjectionV02Main {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try calibrationArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try calibrationArgument(
                "--output-root",
                in: arguments
            )
        ).standardizedFileURL
        let descriptorURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-raster-survival-v01/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let rawURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/raster-survival-art-proof-v01/proof/diagnostics/east-primary/raw.png"
        )
        let metricsURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/raster-survival-art-proof-v01/proof/review/RASTER-SURVIVAL-METRICS.json"
        )
        guard
            try calibrationSHA256(descriptorURL)
                == frozenProofDescriptorSHA256,
            try calibrationSHA256(rawURL) == frozenProofRawSHA256,
            try calibrationSHA256(metricsURL)
                == frozenProofMetricsSHA256
        else {
            throw ProjectionCalibrationError.invalid(
                "frozen v01 proof/rejection evidence hash drift"
            )
        }
        guard
            let descriptor = try JSONSerialization.jsonObject(
                with: Data(contentsOf: descriptorURL)
            ) as? [String: Any],
            let camera = descriptor["camera"] as? [String: Any],
            let sampling = descriptor["sampling"] as? [String: Any],
            let oldScale = camera["orthographicScale"] as? Double,
            let viewport = camera["renderViewportPixels"] as? [Int],
            let oversampling = camera["oversamplingFactor"] as? Int,
            let postOffset =
                camera["postProjectionOffsetPixels"] as? [Double],
            let downsample = sampling["downsample"] as? [String: Any],
            let downsampleScale = downsample["scale"] as? Double
        else {
            throw ProjectionCalibrationError.invalid(
                "frozen v01 descriptor projection fields are malformed"
            )
        }
        let position = try doubles(camera, "positionWorld")
        let target = try doubles(camera, "targetWorld")
        let cameraNode = SCNNode()
        let scnCamera = SCNCamera()
        scnCamera.usesOrthographicProjection = true
        scnCamera.orthographicScale = oldScale
        scnCamera.projectionDirection = .vertical
        cameraNode.camera = scnCamera
        cameraNode.position = SCNVector3(
            position[0],
            position[1],
            position[2]
        )
        cameraNode.look(
            at: SCNVector3(target[0], target[1], target[2]),
            up: SCNVector3(0, 1, 0),
            localFront: SCNVector3(0, 0, -1)
        )

        let oldProjection = footprintProjection(
            scale: oldScale,
            cameraNode: cameraNode,
            viewport: viewport,
            oversampling: oversampling,
            downsampleScale: downsampleScale,
            postProjectionOffset: postOffset
        )
        let solvedScale = solveOrthographicScale(
            targetWidth: 512,
            cameraNode: cameraNode,
            viewport: viewport,
            oversampling: oversampling,
            downsampleScale: downsampleScale,
            postProjectionOffset: postOffset
        )
        let solvedProjection = footprintProjection(
            scale: solvedScale,
            cameraNode: cameraNode,
            viewport: viewport,
            oversampling: oversampling,
            downsampleScale: downsampleScale,
            postProjectionOffset: postOffset
        )
        let expectedRegistration = [
            [768.0, 640.0],
            [1024.0, 768.0],
            [768.0, 896.0],
            [512.0, 768.0],
        ]
        let maximumCoordinateError = zip(
            solvedProjection.points.map(\.registeredSource),
            expectedRegistration
        ).flatMap { actual, expected in
            zip(actual, expected).map { abs($0 - $1) }
        }.max()!

        let shadowWorld = [
            [-28.0, -28.0],
            [28.0, -28.0],
            [28.0, 28.0],
            [-28.0, 28.0],
        ]
        let shadowOffset = [56.0, 28.0]
        let compositorShadowPoints = shadowWorld.map {
            [
                768 + ($0[0] - $0[1]) * 256 / 72
                    + shadowOffset[0],
                768 + ($0[0] + $0[1]) * 128 / 72
                    + shadowOffset[1],
            ]
        }
        let shadowXs = compositorShadowPoints.map { $0[0] }
        let shadowCoreWidth = shadowXs.max()! - shadowXs.min()!
        let retainedPlateWidth = 410.0
        let retainedRatio = retainedPlateWidth / 512
        let blurExpansion = retainedPlateWidth - shadowCoreWidth

        guard
            abs(oldProjection.width - 256) < 0.000_1,
            abs(oldProjection.height - 128) < 0.000_1,
            abs(solvedScale - oldScale / 2) < 0.000_1,
            abs(solvedProjection.width - 512) < 0.000_1,
            abs(solvedProjection.height - 256) < 0.000_1,
            maximumCoordinateError <= 1,
            abs(retainedRatio - 0.80078125) < 0.000_000_1
        else {
            throw ProjectionCalibrationError.invalid(
                "actual-camera calibration or retained 0.8 explanation failed"
            )
        }

        let calibration: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-actual-camera-projection-calibration-v02",
            "authority": "prepixel-no-render-process",
            "immutableInputs": [
                "prepixelCommit": frozenPrepixelCommit,
                "rejectionCommit": frozenRejectionCommit,
                "descriptorFile": relative(descriptorURL, root: root),
                "descriptorSHA256": frozenProofDescriptorSHA256,
                "rawFile": relative(rawURL, root: root),
                "rawSHA256": frozenProofRawSHA256,
                "metricsFile": relative(metricsURL, root: root),
                "metricsSHA256": frozenProofMetricsSHA256,
            ],
            "actualProductionPlumbing": [
                "cameraImplementation":
                    "SCNNode.look(at:up:localFront:) plus SCNCamera vertical orthographic projection",
                "sceneKitVerticalWorldSpan":
                    "2 * orthographicScale",
                "snapshotPixels": [
                    viewport[0] * oversampling,
                    viewport[1] * oversampling,
                ],
                "linearOversamplingFactor": oversampling,
                "sceneKitMSAA": "none",
                "overscanPixels": [0, 0],
                "safetyScale": 1,
                "downsampleFilter": "CILanczosScaleTransform",
                "downsampleScale": downsampleScale,
                "downsampleCropPixels": viewport,
                "postProjectionOffsetPixels": postOffset,
                "finalSourcePixels": viewport,
            ],
            "oldPath": [
                "orthographicScale": oldScale,
                "cameraVerticalWorldSpan": oldScale * 2,
                "projectedFootprintWidth": oldProjection.width,
                "projectedFootprintHeight": oldProjection.height,
                "cornerRecords":
                    oldProjection.points.map(\.dictionary),
                "retainedBuildingOnlyWidth": 254,
                "retainedBuildingVsProjectionDifferencePixels":
                    oldProjection.width - 254,
                "incorrectAnalyticAssumption":
                    "treated orthographicScale as the full vertical world span instead of the half-span",
            ],
            "solvedPath": [
                "orthographicScale": solvedScale,
                "cameraVerticalWorldSpan": solvedScale * 2,
                "targetFootprintPixels": [512, 256],
                "projectedFootprintWidth": solvedProjection.width,
                "projectedFootprintHeight": solvedProjection.height,
                "maximumRegistrationCoordinateErrorPixels":
                    maximumCoordinateError,
                "cornerRecords":
                    solvedProjection.points.map(\.dictionary),
            ],
            "retainedPlateExplanation": [
                "cameraIndependent": true,
                "compositorFormula":
                    "768 + (x-z)*256/72, 768 + (x+z)*128/72; then southeast offset and blur",
                "worldFootprintUnits": [56, 56],
                "registrationBasisWorldUnits": [72, 72],
                "unblurredShadowCorePoints": compositorShadowPoints,
                "unblurredShadowCoreWidth": shadowCoreWidth,
                "retainedBlurredPlateBoundsInclusive":
                    [619, 506, 1028, 905],
                "retainedBlurredPlateWidth": retainedPlateWidth,
                "blurAndRasterExpansionPixels": blurExpansion,
                "retainedPlateWidthOver512": retainedRatio,
                "explanation":
                    "56/72 produces a 398.2222-pixel core; blur/raster support expands it to 410, yielding 410/512 = 0.80078125. The plate measurement never tested SceneKit camera scale.",
            ],
            "rawRenderProcessesConsumed": 0,
            "passed": true,
            "productionSelected": false,
        ]
        let jsonURL = outputRoot.appendingPathComponent(
            "PROJECTION-CALIBRATION.json"
        )
        try writeCalibrationJSON(calibration, to: jsonURL)

        let markdown = """
        # PLAY-027 Industrial L2 East projection calibration v02

        This is a pre-pixel calibration. It consumes no Metal render process and preserves the complete `920af3b` / `3794912` proof and rejection trees.

        The production camera plumbing uses a 6144×4096 SceneKit snapshot, vertical orthographic projection, no MSAA, fixed 4× oversampling, software Lanczos 0.25 to 1536×1024, then the existing compositor offset. SceneKit interprets `orthographicScale` as half the vertical world span. Therefore the old value `\(oldScale)` exposes `\(oldScale * 2)` world units vertically and projects the 56×56 footprint to `\(oldProjection.width)`×`\(oldProjection.height)` source pixels. The retained building-only width of 254 pixels is within two pixels of that actual 256-pixel camera projection. The prior 512-pixel analytic claim omitted this factor of two.

        Solving through the actual `SCNNode.look` camera basis and every output scale gives corrected orthographic scale `\(solvedScale)`. It projects the four corners to the frozen registration diamond within `\(maximumCoordinateError)` pixel, with a 512×256 envelope.

        The observed 410-pixel plate is a separate compositor measurement. `drawShadow` scales the 56-unit contact polygon against a 72-unit basis, producing a `\(shadowCoreWidth)`-pixel core; blur and raster support add `\(blurExpansion)` pixels. The final 410/512 ratio is exactly `\(retainedRatio)`. It is camera-independent and cannot validate building utilization.
        """
        let markdownURL = outputRoot.appendingPathComponent(
            "PROJECTION-CALIBRATION.md"
        )
        try FileManager.default.createDirectory(
            at: markdownURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try (markdown + "\n").write(
            to: markdownURL,
            atomically: true,
            encoding: .utf8
        )

        print("old \(oldProjection.width)x\(oldProjection.height)")
        print("solvedScale \(solvedScale)")
        print(
            "solved \(solvedProjection.width)x\(solvedProjection.height) error=\(maximumCoordinateError)"
        )
        print("plate \(retainedPlateWidth)/512=\(retainedRatio)")
        print("rawRenderProcessesConsumed=0")
    }
}
