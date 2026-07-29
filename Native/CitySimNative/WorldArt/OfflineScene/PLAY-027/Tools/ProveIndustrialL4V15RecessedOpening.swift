import Foundation

private let fixtureRevision = "source-v15-recessed-opening-fixture"
private let fixtureGeometryID = "play027-v15-north-recessed-opening-fixture"
private let compactSize = CGSize(width: 192, height: 128)

private func replaceIdentity(_ value: Any) -> Any {
    if let string = value as? String {
        return string
            .replacingOccurrences(of: "source-v14-prepixel", with: fixtureRevision)
            .replacingOccurrences(
                of: "industrial-l04-crucible-gantry-v14-north-board-led",
                with: fixtureGeometryID
            )
    }
    if let values = value as? [Any] { return values.map(replaceIdentity) }
    if let values = value as? [String: Any] {
        return values.mapValues(replaceIdentity)
    }
    return value
}

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        CommandLine.arguments.indices.contains(index + 1)
    else {
        throw V15SupportError.failed("missing \(name)")
    }
    return CommandLine.arguments[index + 1]
}

private func massJSON(_ mass: V15Mass) -> [String: Any] {
    [
        "id": mass.id,
        "dimensions": [mass.size.x, mass.size.y, mass.size.z],
        "positionWorld": [mass.center.x, mass.center.y, mass.center.z],
        "materialID": mass.materialID,
    ]
}

private func run(repositoryRoot: URL, outputRoot: URL) throws {
    let v14Root = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/crucible-gantry-v14-north-prepixel/attempts/refinement-03/artifact"
    )
    let templateURL = v14Root.appendingPathComponent(
        "scenes/industrial_l04/variant-0/n/scene.json"
    )
    let templateData = try Data(contentsOf: templateURL)
    let templateDecoded = try JSONDecoder().decode(
        SceneDescriptor.self,
        from: templateData
    )
    let encodedRoundTrip = try JSONEncoder().encode(templateDecoded)
    let decodedRoundTrip = try JSONDecoder().decode(
        SceneDescriptor.self,
        from: encodedRoundTrip
    )
    guard templateDecoded == decodedRoundTrip else {
        throw V15SupportError.failed("shared SceneDescriptor round-trip drift")
    }
    var scene = replaceIdentity(
        try JSONSerialization.jsonObject(with: templateData)
    ) as! [String: Any]
    scene["sourceRevision"] = fixtureRevision
    scene["sceneGeometryID"] = fixtureGeometryID
    scene["sourceAuthority"] = false
    scene["productionSelected"] = false
    if var sampling = scene["sampling"] as? [String: Any] {
        sampling["sourceRevisionBinding"] = fixtureRevision
        scene["sampling"] = sampling
    }
    let opening = V15RecessedOpening(
        id: "fixture-opening",
        centerX: 0,
        baseY: 2,
        width: 12,
        height: 12,
        wallZ: -20,
        wallDepth: 4,
        frameWidth: 2,
        frameTop: 4,
        sillHeight: 2,
        backset: 3,
        wallMaterialID: "v14-warm-masonry",
        frameMaterialID: "v14-concrete-trim",
        backMaterialID: "v14-deep-freight-recess",
        role: "fixtureOpening"
    )
    let masses = try opening.loweredPositiveMasses(sectionWidth: 30)
    let aperture = opening.aperture
    let overlapIDs = masses.filter {
        $0.id != opening.insetBackPlane.id
            && v15Overlaps(V15AABB(center: $0.center, size: $0.size), aperture)
    }.map(\.id)
    guard overlapIDs.isEmpty else {
        throw V15SupportError.failed("aperture overlap \(overlapIDs)")
    }
    var building = scene["building"] as! [String: Any]
    building["massBlocks"] = masses.map(massJSON)
    building["roofVolumes"] = []
    building["trimBands"] = []
    building["foundationDimensions"] = [30, 1, 8]
    building["foundationPositionWorld"] = [0, 0.5, -20]
    scene["building"] = building
    scene["props"] = []
    let sceneData = try v15StableJSON(scene)
    let sceneURL = outputRoot.appendingPathComponent("scene.json")
    try FileManager.default.createDirectory(
        at: outputRoot,
        withIntermediateDirectories: true
    )
    try sceneData.write(to: sceneURL)
    let persisted = try Data(contentsOf: sceneURL)
    _ = try JSONDecoder().decode(SceneDescriptor.self, from: persisted)
    let persistedJSON = try JSONSerialization.jsonObject(with: persisted)
        as! [String: Any]
    let camera = try v15Camera(from: persistedJSON)
    let backBox = V15AABB(
        center: opening.insetBackPlane.center,
        size: opening.insetBackPlane.size
    )
    var selectedTarget: V15V3?
    var selectedApertureDistance: Double?
    var selectedBackDistance: Double?
    let samples = [-0.25, 0.0, 0.25]
    for yFraction in samples {
        for xFraction in samples {
            let target = V15V3(
                x: opening.insetBackPlane.center.x
                    + opening.insetBackPlane.size.x * xFraction,
                y: opening.insetBackPlane.center.y
                    + opening.insetBackPlane.size.y * yFraction,
                z: opening.insetBackPlane.center.z
            )
            let rayDirection = try v15Normalized(
                v15Subtract(target, camera.position)
            )
            guard
                let apertureDistance = v15RayHitDistance(
                    origin: camera.position,
                    direction: rayDirection,
                    box: aperture
                ),
                let backDistance = v15RayHitDistance(
                    origin: camera.position,
                    direction: rayDirection,
                    box: backBox
                ),
                backDistance > apertureDistance
            else { continue }
            let positiveHits = masses
                .filter { $0.id != opening.insetBackPlane.id }
                .compactMap { mass in
                    v15RayHitDistance(
                        origin: camera.position,
                        direction: rayDirection,
                        box: V15AABB(center: mass.center, size: mass.size)
                    )
                }
            if positiveHits.isEmpty {
                selectedTarget = target
                selectedApertureDistance = apertureDistance
                selectedBackDistance = backDistance
                break
            }
        }
        if selectedTarget != nil { break }
    }
    guard
        let rayTarget = selectedTarget,
        let apertureDistance = selectedApertureDistance,
        let backDistance = selectedBackDistance
    else {
        throw V15SupportError.failed(
            "no deterministic camera ray crosses empty aperture before back plane"
        )
    }
    let palette: [String: [Double]] = [
        "v14-warm-masonry": [0.68, 0.40, 0.24, 1],
        "v14-concrete-trim": [0.58, 0.54, 0.46, 1],
        "v14-deep-freight-recess": [0.035, 0.05, 0.05, 1],
    ]
    try v15WritePNG(
        try v15Render(
            masses: masses,
            camera: camera,
            palette: palette,
            size: compactSize,
            grayscale: false
        ),
        to: outputRoot.appendingPathComponent("EXACT-192X128-COLOR.png")
    )
    try v15WritePNG(
        try v15Render(
            masses: masses,
            camera: camera,
            palette: palette,
            size: compactSize,
            grayscale: true
        ),
        to: outputRoot.appendingPathComponent("EXACT-192X128-GRAYSCALE.png")
    )
    let report: [String: Any] = [
        "taskID": "PLAY-027",
        "capability": "recessed-opening-positive-mass-segmentation-v1",
        "revision": fixtureRevision,
        "geometryID": fixtureGeometryID,
        "descriptorSHA256": v15SHA256(sceneData),
        "sharedSceneDescriptorRoundTrip": "PASS",
        "sharedSceneDescriptorSourceChanged": false,
        "aperture": [
            "minimum": [
                aperture.minimum.x,
                aperture.minimum.y,
                aperture.minimum.z,
            ],
            "maximum": [
                aperture.maximum.x,
                aperture.maximum.y,
                aperture.maximum.z,
            ],
        ],
        "positiveSolidOverlapCount": overlapIDs.count,
        "positiveSolidOverlapIDs": overlapIDs,
        "cameraRaySolidHitsBeforeBackPlane": [],
        "cameraRayFirstEncounter": "EMPTY_APERTURE",
        "cameraRaySecondEncounter": opening.insetBackPlane.id,
        "cameraRayTarget": [rayTarget.x, rayTarget.y, rayTarget.z],
        "cameraRayApertureEntryDistance": apertureDistance,
        "cameraRayBackPlaneDistance": backDistance,
        "rawProcessCount": 0,
        "sceneKitProcessCount": 0,
        "metalProcessCount": 0,
        "normalizerProcessCount": 0,
        "sourceAuthority": false,
        "productionSelected": false,
    ]
    try v15StableJSON(report).write(
        to: outputRoot.appendingPathComponent("STRUCTURAL-VALIDATION.json")
    )
}

@main
private enum ProveIndustrialL4V15RecessedOpening {
    static func main() {
        do {
            try run(
                repositoryRoot: URL(
                    fileURLWithPath: try argument("--repository-root")
                ),
                outputRoot: URL(
                    fileURLWithPath: try argument("--output-root")
                )
            )
            print("PASS recessed opening capability")
        } catch {
            fputs("FAIL \(error)\n", stderr)
            exit(1)
        }
    }
}
