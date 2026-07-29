import AppKit
import CoreGraphics
import Foundation
import ImageIO

private let v15Revision = "source-v15-prepixel"
private let v15GeometryID =
    "industrial-l04-crucible-gantry-v15-north-recessed-frontage"
private let v15SourceSize = CGSize(width: 1536, height: 1024)
private let v15NativeSize = CGSize(width: 384, height: 256)
private let v15CompactSize = CGSize(width: 192, height: 128)

private func v15Argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        CommandLine.arguments.indices.contains(index + 1)
    else {
        throw V15SupportError.failed("missing \(name)")
    }
    return CommandLine.arguments[index + 1]
}

private func v15RecursiveIdentity(_ value: Any) -> Any {
    if let string = value as? String {
        return string
            .replacingOccurrences(of: "source-v14-prepixel", with: v15Revision)
            .replacingOccurrences(
                of: "industrial-l04-crucible-gantry-v14-north-board-led",
                with: v15GeometryID
            )
    }
    if let values = value as? [Any] {
        return values.map(v15RecursiveIdentity)
    }
    if let values = value as? [String: Any] {
        return values.mapValues(v15RecursiveIdentity)
    }
    return value
}

private func v15Role(for id: String) -> String {
    if id.contains("freight-1") { return "freight1" }
    if id.contains("freight-2") { return "freight2" }
    if id.contains("freight-3") { return "freight3" }
    if id.contains("staff") || id.contains("control") { return "staff" }
    if id.contains("gantry") || id.contains("girder") || id.contains("crane") {
        return "gantry"
    }
    if id.contains("crucible") { return "crucible" }
    if id.contains("court") || id.contains("rail") { return "court" }
    if id.contains("hall") || id.contains("clerestory") { return "hall" }
    if id.contains("stack") || id.contains("boiler") { return "stack" }
    return "structure"
}

private func v15Mass(from value: [String: Any]) throws -> V15Mass {
    guard
        let id = value["id"] as? String,
        let materialID = value["materialID"] as? String,
        let position = value["positionWorld"] as? [NSNumber],
        position.count == 3,
        let dimensions = value["dimensions"] as? [NSNumber],
        dimensions.count == 3
    else {
        throw V15SupportError.failed("invalid mass block")
    }
    return V15Mass(
        id: id,
        role: v15Role(for: id),
        materialID: materialID,
        center: V15V3(
            x: position[0].doubleValue,
            y: position[1].doubleValue,
            z: position[2].doubleValue
        ),
        size: V15V3(
            x: dimensions[0].doubleValue,
            y: dimensions[1].doubleValue,
            z: dimensions[2].doubleValue
        ),
        shape: "box"
    )
}

private func v15PropMass(from value: [String: Any]) throws -> V15Mass {
    let mass = try v15Mass(from: value)
    return V15Mass(
        id: mass.id,
        role: mass.role,
        materialID: mass.materialID,
        center: mass.center,
        size: mass.size,
        shape: value["kind"] as? String == "explicit-cylinder"
            ? "cylinder" : "box"
    )
}

private func v15MassJSON(_ mass: V15Mass) -> [String: Any] {
    [
        "id": mass.id,
        "dimensions": [mass.size.x, mass.size.y, mass.size.z],
        "positionWorld": [mass.center.x, mass.center.y, mass.center.z],
        "materialID": mass.materialID,
    ]
}

private func v15PropJSON(_ mass: V15Mass) -> [String: Any] {
    [
        "id": mass.id,
        "kind": mass.shape == "cylinder"
            ? "explicit-cylinder" : "explicit-box",
        "dimensions": [mass.size.x, mass.size.y, mass.size.z],
        "positionWorld": [mass.center.x, mass.center.y, mass.center.z],
        "materialID": mass.materialID,
    ]
}

private func v15Palette(_ library: [String: Any]) throws -> [String: [Double]] {
    guard let materials = library["materials"] as? [[String: Any]] else {
        throw V15SupportError.failed("material inventory missing")
    }
    return Dictionary(uniqueKeysWithValues: try materials.map { item in
        guard
            let id = item["id"] as? String,
            let values = item["baseColorRGBA"] as? [NSNumber],
            values.count == 4
        else {
            throw V15SupportError.failed("invalid material")
        }
        return (id, values.map(\.doubleValue))
    })
}

private func v15OpeningMasses() throws -> ([V15Mass], [V15RecessedOpening]) {
    let centers = [2.0, 10.5, 19.0]
    var openings: [V15RecessedOpening] = []
    var masses: [V15Mass] = []
    for (index, center) in centers.enumerated() {
        let opening = V15RecessedOpening(
            id: "v15-freight-\(index + 1)",
            centerX: center,
            baseY: 2,
            width: 6.5,
            height: 11,
            wallZ: -23,
            wallDepth: 3,
            frameWidth: 0.75,
            frameTop: 2.5,
            sillHeight: 0,
            backset: 3,
            wallMaterialID: "v14-warm-masonry",
            frameMaterialID: "v14-structural-mid-steel",
            backMaterialID: "v14-deep-freight-recess",
            role: "freight\(index + 1)"
        )
        openings.append(opening)
        masses += try opening.loweredPositiveMasses(sectionWidth: 8.5)
    }
    masses.append(
        V15Mass(
            id: "v15-freight-group-continuous-header",
            role: "freightGroupHeader",
            materialID: "v14-dark-gantry-steel",
            center: V15V3(x: 10.5, y: 15.25, z: -23),
            size: V15V3(x: 26.5, y: 2.5, z: 4)
        )
    )
    let staff = V15RecessedOpening(
        id: "v15-staff-opening",
        centerX: -20,
        baseY: 2,
        width: 5,
        height: 8,
        wallZ: -22,
        wallDepth: 4,
        frameWidth: 1,
        frameTop: 2,
        sillHeight: 0,
        backset: 3,
        wallMaterialID: "v14-warm-masonry",
        frameMaterialID: "v14-concrete-trim",
        backMaterialID: "v14-warm-glazing",
        role: "staff"
    )
    openings.append(staff)
    masses += try staff.loweredPositiveMasses(sectionWidth: 14)
    return (masses, openings)
}

private func v15OpeningIDsToRemove(_ id: String) -> Bool {
    id.hasPrefix("v14-freight-")
        || id == "v14-staff-entry"
        || id.hasPrefix("v14-staff-")
        || id == "v14-control-annex"
}

private func v15StructuralHash(_ masses: [V15Mass]) throws -> String {
    v15SHA256(
        try v15StableJSON(
            masses.sorted { $0.id < $1.id }.map {
                [
                    "id": $0.id,
                    "materialID": $0.materialID,
                    "positionWorld": [$0.center.x, $0.center.y, $0.center.z],
                    "dimensions": [$0.size.x, $0.size.y, $0.size.z],
                    "shape": $0.shape,
                ] as [String: Any]
            }
        )
    )
}

private func v15ClearRayReport(
    opening: V15RecessedOpening,
    masses: [V15Mass],
    camera: V15Camera
) throws -> [String: Any] {
    let aperture = opening.aperture
    let back = opening.insetBackPlane
    let backBox = V15AABB(center: back.center, size: back.size)
    let samples = [-0.35, -0.175, 0.0, 0.175, 0.35]
    var selected: (V15V3, Double, Double)?
    var bestBlocked: (
        target: V15V3,
        aperture: Double,
        back: Double,
        blockers: [(id: String, distance: Double)]
    )?
    for yFraction in samples {
        for xFraction in samples {
            let target = V15V3(
                x: back.center.x + back.size.x * xFraction,
                y: back.center.y + back.size.y * yFraction,
                z: back.center.z
            )
            let direction = try v15Normalized(
                v15Subtract(target, camera.position)
            )
            guard
                let apertureDistance = v15RayHitDistance(
                    origin: camera.position,
                    direction: direction,
                    box: aperture
                ),
                let backDistance = v15RayHitDistance(
                    origin: camera.position,
                    direction: direction,
                    box: backBox
                ),
                backDistance > apertureDistance
            else { continue }
            let blockers = masses.filter { $0.id != back.id }.compactMap {
                mass -> (id: String, distance: Double)? in
                guard let distance = v15RayHitDistance(
                    origin: camera.position,
                    direction: direction,
                    box: V15AABB(center: mass.center, size: mass.size)
                ), distance < backDistance else {
                    return nil
                }
                return (mass.id, distance)
            }.sorted { $0.distance < $1.distance }
            if blockers.isEmpty {
                selected = (target, apertureDistance, backDistance)
                break
            }
            if bestBlocked == nil
                || blockers.count < bestBlocked!.blockers.count
            {
                bestBlocked = (
                    target,
                    apertureDistance,
                    backDistance,
                    blockers
                )
            }
        }
        if selected != nil { break }
    }
    let corners = [
        V15V3(x: aperture.minimum.x, y: aperture.minimum.y, z: aperture.maximum.z),
        V15V3(x: aperture.maximum.x, y: aperture.minimum.y, z: aperture.maximum.z),
        V15V3(x: aperture.maximum.x, y: aperture.maximum.y, z: aperture.maximum.z),
        V15V3(x: aperture.minimum.x, y: aperture.maximum.y, z: aperture.maximum.z),
    ].map { v15Project($0, camera: camera, size: v15CompactSize) }
    let width = corners.map(\.x).max()! - corners.map(\.x).min()!
    let height = corners.map(\.y).max()! - corners.map(\.y).min()!
    let overlapOwners = masses.filter {
        $0.id != back.id
            && v15Overlaps(V15AABB(center: $0.center, size: $0.size), aperture)
    }.map(\.id).sorted()
    var report: [String: Any] = [
        "openingID": opening.id,
        "positiveSolidOverlapCount": overlapOwners.count,
        "positiveSolidOverlapOwners": overlapOwners,
        "projectedCompactBounds": [width, height],
    ]
    if let value = selected {
        report["clearRayPass"] = true
        report["rayFirstEncounter"] = "EMPTY_APERTURE"
        report["raySecondEncounter"] = back.id
        report["rayTarget"] = [value.0.x, value.0.y, value.0.z]
        report["apertureEntryDistance"] = value.1
        report["backPlaneDistance"] = value.2
    } else {
        report["clearRayPass"] = false
        report["rayFirstEncounter"] = "BLOCKED"
        report["raySecondEncounter"] = "UNREACHED"
        if let blocked = bestBlocked {
            report["closestBlockedTarget"] = [
                blocked.target.x,
                blocked.target.y,
                blocked.target.z,
            ]
            report["apertureEntryDistance"] = blocked.aperture
            report["backPlaneDistance"] = blocked.back
            report["blockingOwners"] = blocked.blockers.map {
                ["id": $0.id, "distance": $0.distance]
            }
        }
    }
    return report
}

private func v15RegistrationContactPanel(
    base: CGImage,
    registration: [String: Any]
) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: Int(v15CompactSize.width),
        height: Int(v15CompactSize.height),
        bitsPerComponent: 8,
        bytesPerRow: Int(v15CompactSize.width) * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V15SupportError.failed("cannot make registration panel")
    }
    context.translateBy(x: 0, y: v15CompactSize.height)
    context.scaleBy(x: 1, y: -1)
    context.draw(base, in: CGRect(origin: .zero, size: v15CompactSize))
    func point(_ value: [NSNumber]) -> CGPoint {
        CGPoint(
            x: value[0].doubleValue / 8,
            y: value[1].doubleValue / 8
        )
    }
    guard
        let footprint = registration["footprintPolygonSource"]
            as? [[NSNumber]],
        let frontage = registration["frontageEdgeSource"]
            as? [[NSNumber]],
        let socket = registration["frontageSocketSource"] as? [NSNumber],
        let pivot = registration["groundPivotSource"] as? [NSNumber],
        let door = registration["doorBaseSource"] as? [[NSNumber]]
    else {
        throw V15SupportError.failed("registration fields missing")
    }
    context.setLineWidth(1.25)
    context.setStrokeColor(CGColor(red: 0.15, green: 0.9, blue: 0.95, alpha: 1))
    context.beginPath()
    context.move(to: point(footprint[0]))
    for value in footprint.dropFirst() { context.addLine(to: point(value)) }
    context.closePath()
    context.strokePath()
    context.setStrokeColor(CGColor(red: 1, green: 0.55, blue: 0.1, alpha: 1))
    context.setLineWidth(2)
    context.move(to: point(frontage[0]))
    context.addLine(to: point(frontage[1]))
    context.strokePath()
    context.setFillColor(CGColor(red: 0.1, green: 1, blue: 0.25, alpha: 1))
    let socketPoint = point(socket)
    context.fillEllipse(
        in: CGRect(x: socketPoint.x - 2, y: socketPoint.y - 2, width: 4, height: 4)
    )
    context.setStrokeColor(CGColor(red: 1, green: 0.1, blue: 0.1, alpha: 1))
    let pivotPoint = point(pivot)
    context.setLineWidth(1.5)
    context.move(to: CGPoint(x: pivotPoint.x - 3, y: pivotPoint.y))
    context.addLine(to: CGPoint(x: pivotPoint.x + 3, y: pivotPoint.y))
    context.move(to: CGPoint(x: pivotPoint.x, y: pivotPoint.y - 3))
    context.addLine(to: CGPoint(x: pivotPoint.x, y: pivotPoint.y + 3))
    context.strokePath()
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 0.2, alpha: 1))
    context.setLineWidth(2)
    context.move(to: point(door[0]))
    context.addLine(to: point(door[1]))
    context.strokePath()
    guard let image = context.makeImage() else {
        throw V15SupportError.failed("cannot finish registration panel")
    }
    return image
}

private func v15LoadImage(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw V15SupportError.failed("cannot load \(url.path)")
    }
    return image
}

private func v15Comparison(
    left: CGImage,
    right: CGImage,
    cell: CGSize
) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: Int(cell.width * 2),
        height: Int(cell.height),
        bitsPerComponent: 8,
        bytesPerRow: Int(cell.width * 2) * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V15SupportError.failed("cannot make comparison")
    }
    context.translateBy(x: 0, y: cell.height)
    context.scaleBy(x: 1, y: -1)
    context.interpolationQuality = .high
    context.draw(left, in: CGRect(origin: .zero, size: cell))
    context.draw(
        right,
        in: CGRect(x: cell.width, y: 0, width: cell.width, height: cell.height)
    )
    guard let image = context.makeImage() else {
        throw V15SupportError.failed("cannot finish comparison")
    }
    return image
}

private func v15Run(
    repositoryRoot: URL,
    artifactRoot: URL,
    evidenceRoot: URL
) throws {
    let v14Root = repositoryRoot.appendingPathComponent(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/crucible-gantry-v14-north-prepixel/attempts/refinement-03"
    )
    let v14SceneURL = v14Root.appendingPathComponent(
        "artifact/scenes/industrial_l04/variant-0/n/scene.json"
    )
    let v14MaterialURL = v14Root.appendingPathComponent(
        "artifact/materials/industrial-l04-crucible-gantry-v14-north-prepixel.json"
    )
    let v14SceneData = try Data(contentsOf: v14SceneURL)
    let v14MaterialData = try Data(contentsOf: v14MaterialURL)
    var scene = v15RecursiveIdentity(
        try JSONSerialization.jsonObject(with: v14SceneData)
    ) as! [String: Any]
    scene["sourceRevision"] = v15Revision
    scene["sceneGeometryID"] = v15GeometryID
    scene["sourceAuthority"] = false
    scene["productionSelected"] = false
    scene["derivation"] = [
        "sourceKind": "offline-scene-v15-single-recessed-opening-refinement",
        "siblingSource": NSNull(),
        "mirror": false,
        "rotationDegrees": 0,
        "transform": "none",
    ]
    let materialSHA = v15SHA256(v14MaterialData)
    scene["materialLibrary"] = [
        "role": "industrial-l04-crucible-gantry-v15-north-material-library",
        "file": "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-crucible-gantry-v15-north-prepixel/materials/industrial-l04-crucible-gantry-v14-north-prepixel.json",
        "sha256": materialSHA,
    ]
    if var sampling = scene["sampling"] as? [String: Any] {
        sampling["sourceRevisionBinding"] = v15Revision
        scene["sampling"] = sampling
    }
    var building = scene["building"] as! [String: Any]
    let v14Blocks = try (building["massBlocks"] as! [[String: Any]]).map(v15Mass)
    let v14Props = try (scene["props"] as! [[String: Any]]).map(v15PropMass)
    let preservedBlocks = v14Blocks.filter { !v15OpeningIDsToRemove($0.id) }
    let preservedProps = v14Props.filter { !v15OpeningIDsToRemove($0.id) }
    let controlRear = V15Mass(
        id: "v15-control-annex-rear-body",
        role: "staff",
        materialID: "v14-warm-masonry",
        center: V15V3(x: -20, y: 6, z: -15.5),
        size: V15V3(x: 14, y: 10, z: 9)
    )
    let (openingMasses, openings) = try v15OpeningMasses()
    let v15Blocks = preservedBlocks + [controlRear] + openingMasses
    building["massBlocks"] = v15Blocks.map(v15MassJSON)
    scene["building"] = building
    scene["props"] = preservedProps.map(v15PropJSON)
    var entrance = scene["entrance"] as! [String: Any]
    entrance["baseWorld"] = [-20, -28]
    entrance["width"] = 5
    entrance["height"] = 8
    entrance["depth"] = 4
    scene["entrance"] = entrance

    let materialURL = artifactRoot.appendingPathComponent(
        "materials/industrial-l04-crucible-gantry-v14-north-prepixel.json"
    )
    let sceneURL = artifactRoot.appendingPathComponent(
        "scenes/industrial_l04/variant-0/n/scene.json"
    )
    try FileManager.default.createDirectory(
        at: materialURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: sceneURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try v14MaterialData.write(to: materialURL)
    let sceneData = try v15StableJSON(scene)
    try sceneData.write(to: sceneURL)
    _ = try JSONDecoder().decode(SceneDescriptor.self, from: sceneData)
    _ = try JSONDecoder().decode(
        MaterialLibraryDescriptor.self,
        from: v14MaterialData
    )
    let persistedScene = try JSONSerialization.jsonObject(with: sceneData)
        as! [String: Any]
    let camera = try v15Camera(from: persistedScene)
    let library = try JSONSerialization.jsonObject(with: v14MaterialData)
        as! [String: Any]
    let palette = try v15Palette(library)
    let allMasses = v15Blocks + preservedProps

    let removedIDs = Set((v14Blocks + v14Props)
        .filter { v15OpeningIDsToRemove($0.id) }.map(\.id))
    let v14Hero = (v14Blocks + v14Props).filter {
        !removedIDs.contains($0.id)
    }
    let v15Hero = allMasses.filter {
        !($0.id.hasPrefix("v15-freight")
            || $0.id.hasPrefix("v15-staff")
            || $0.id == controlRear.id)
    }
    let v14HeroSHA = try v15StructuralHash(v14Hero)
    let v15HeroSHA = try v15StructuralHash(v15Hero)
    guard v14HeroSHA == v15HeroSHA else {
        throw V15SupportError.failed("non-opening hero structure drift")
    }
    let openingReports = try openings.map {
        try v15ClearRayReport(opening: $0, masses: allMasses, camera: camera)
    }
    let openingGatePass = openingReports.allSatisfy {
        ($0["positiveSolidOverlapCount"] as? Int) == 0
            && ($0["clearRayPass"] as? Bool) == true
    }

    let review = evidenceRoot.appendingPathComponent("review")
    let sourceColor = try v15Render(
        masses: allMasses,
        camera: camera,
        palette: palette,
        size: v15SourceSize,
        grayscale: false
    )
    let sourceGray = try v15Render(
        masses: allMasses,
        camera: camera,
        palette: palette,
        size: v15SourceSize,
        grayscale: true
    )
    let nativeColor = try v15Render(
        masses: allMasses,
        camera: camera,
        palette: palette,
        size: v15NativeSize,
        grayscale: false
    )
    let nativeGray = try v15Render(
        masses: allMasses,
        camera: camera,
        palette: palette,
        size: v15NativeSize,
        grayscale: true
    )
    let compactColor = try v15Render(
        masses: allMasses,
        camera: camera,
        palette: palette,
        size: v15CompactSize,
        grayscale: false
    )
    let compactGray = try v15Render(
        masses: allMasses,
        camera: camera,
        palette: palette,
        size: v15CompactSize,
        grayscale: true
    )
    try v15WritePNG(sourceColor, to: review.appendingPathComponent("SOURCE-COLOR.png"))
    try v15WritePNG(sourceGray, to: review.appendingPathComponent("SOURCE-GRAYSCALE.png"))
    try v15WritePNG(nativeColor, to: review.appendingPathComponent("NATIVE-2X-COLOR.png"))
    try v15WritePNG(nativeGray, to: review.appendingPathComponent("NATIVE-2X-GRAYSCALE.png"))
    try v15WritePNG(compactColor, to: review.appendingPathComponent("EXACT-192X128-COLOR.png"))
    try v15WritePNG(compactGray, to: review.appendingPathComponent("EXACT-192X128-GRAYSCALE.png"))
    let semanticPalette = Dictionary(
        uniqueKeysWithValues: palette.keys.map { key in
            if key.contains("recess") { return (key, [0.95, 0.1, 0.8, 1]) }
            if key.contains("glazing") { return (key, [0.1, 0.9, 0.3, 1]) }
            return (key, [0.25, 0.30, 0.34, 1])
        }
    )
    try v15WritePNG(
        try v15Render(
            masses: allMasses,
            camera: camera,
            palette: semanticPalette,
            size: v15CompactSize,
            grayscale: false
        ),
        to: review.appendingPathComponent("SEMANTIC-SUPPORTING.png")
    )
    guard let registration = persistedScene["registration"] as? [String: Any]
    else {
        throw V15SupportError.failed("persisted registration missing")
    }
    try v15WritePNG(
        try v15RegistrationContactPanel(
            base: compactColor,
            registration: registration
        ),
        to: review.appendingPathComponent("REGISTRATION-CONTACT.png")
    )
    for (suffix, size, currentColor, currentGray) in [
        ("SOURCE", v15SourceSize, sourceColor, sourceGray),
        ("NATIVE-2X", v15NativeSize, nativeColor, nativeGray),
        ("EXACT-192X128", v15CompactSize, compactColor, compactGray),
    ] {
        let oldColor = try v15LoadImage(
            v14Root.appendingPathComponent(
                "evidence/review/\(suffix == "EXACT-192X128" ? "EXACT-192X128" : suffix)-COLOR.png"
            )
        )
        let oldGray = try v15LoadImage(
            v14Root.appendingPathComponent(
                "evidence/review/\(suffix == "EXACT-192X128" ? "EXACT-192X128" : suffix)-GRAYSCALE.png"
            )
        )
        try v15WritePNG(
            try v15Comparison(left: oldColor, right: currentColor, cell: size),
            to: review.appendingPathComponent("UNLABELLED-V14-V15-\(suffix)-COLOR.png")
        )
        try v15WritePNG(
            try v15Comparison(left: oldGray, right: currentGray, cell: size),
            to: review.appendingPathComponent("UNLABELLED-V14-V15-\(suffix)-GRAYSCALE.png")
        )
    }
    let report: [String: Any] = [
        "taskID": "PLAY-027",
        "revision": v15Revision,
        "disposition": openingGatePass
            ? "PENDING_INDEPENDENT_REVIEW"
            : "REJECTED_FIXED_CAMERA_APERTURE_GATE",
        "geometryID": v15GeometryID,
        "descriptorSHA256": v15SHA256(sceneData),
        "materialSHA256": materialSHA,
        "builderSourceSHA256": try v15SHA256(
            repositoryRoot.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4CrucibleGantryV15NorthPrepixel.swift"
            )
        ),
        "supportSourceSHA256": try v15SHA256(
            repositoryRoot.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/RecessedOpeningV15Support.swift"
            )
        ),
        "compiledBinarySHA256": try v15SHA256(
            URL(fileURLWithPath: CommandLine.arguments[0])
        ),
        "v14DescriptorSHA256": v15SHA256(v14SceneData),
        "v14MaterialSHA256": v15SHA256(v14MaterialData),
        "heroPreservationSHA256": v14HeroSHA,
        "heroPreservationPass": true,
        "openingGatePass": openingGatePass,
        "removedOpeningScopeIDs": removedIDs.sorted(),
        "newOpeningScopeIDs": openingMasses.map(\.id).sorted(),
        "openingReports": openingReports,
        "courtWorldBounds": [-6, -28, 28, 8],
        "northSocketSource": [896, 704],
        "groundPivotSource": [768, 896],
        "rawProcessCount": 0,
        "sceneKitProcessCount": 0,
        "metalProcessCount": 0,
        "normalizerProcessCount": 0,
        "sourceAuthority": false,
        "productionSelected": false,
    ]
    try v15StableJSON(report).write(
        to: evidenceRoot.appendingPathComponent("PREPIXEL-VALIDATION.json")
    )
    if !openingGatePass {
        throw V15SupportError.failed(
            "fixed-camera aperture ray/overlap gate failed"
        )
    }
}

@main
private enum BuildIndustrialL4CrucibleGantryV15NorthPrepixel {
    static func main() {
        do {
            try v15Run(
                repositoryRoot: URL(
                    fileURLWithPath: try v15Argument("--repository-root")
                ),
                artifactRoot: URL(
                    fileURLWithPath: try v15Argument("--artifact-root")
                ),
                evidenceRoot: URL(
                    fileURLWithPath: try v15Argument("--evidence-root")
                )
            )
            print("PASS v15 recessed-frontage pre-pixel")
        } catch {
            fputs("FAIL \(error)\n", stderr)
            exit(1)
        }
    }
}
