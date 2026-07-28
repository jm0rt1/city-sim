import AppKit
import CoreGraphics
import Foundation
import ImageIO

private let v16Revision = "source-v16-prepixel"
private let v16GeometryID =
    "industrial-l04-crucible-gantry-v16-north-l-side-return"
private let v16SourceSize = CGSize(width: 1536, height: 1024)
private let v16NativeSize = CGSize(width: 384, height: 256)
private let v16CompactSize = CGSize(width: 192, height: 128)

private struct V16OpeningProof {
    let id: String
    let role: String
    let aperture: V15AABB
    let backPlane: V15Mass
}

private struct V16SideOpening {
    let id: String
    let centerZ: Double
    let baseY: Double
    let width: Double
    let height: Double
    let wallX: Double
    let wallDepth: Double
    let frameWidth: Double
    let frameTop: Double
    let backset: Double
    let wallMaterialID: String
    let frameMaterialID: String
    let backMaterialID: String
    let role: String

    var aperture: V15AABB {
        V15AABB(
            center: V15V3(
                x: wallX,
                y: baseY + height * 0.5,
                z: centerZ
            ),
            size: V15V3(x: wallDepth, y: height, z: width)
        )
    }

    var backPlane: V15Mass {
        V15Mass(
            id: "\(id)-inset-back-plane",
            role: "\(role)Back",
            materialID: backMaterialID,
            center: V15V3(
                x: wallX - wallDepth * 0.5 - backset,
                y: baseY + height * 0.5,
                z: centerZ
            ),
            size: V15V3(x: 0.8, y: height, z: width)
        )
    }

    func loweredPositiveMasses(sectionDepth: Double) throws -> [V15Mass] {
        guard
            width > 0,
            height > 0,
            wallDepth > 0,
            frameWidth > 0,
            frameTop > 0,
            backset > 0,
            sectionDepth > width + frameWidth * 2
        else {
            throw V15SupportError.failed("\(id) dimensions invalid")
        }
        let sideDepth = (sectionDepth - width) * 0.5
        let sideOffset = width * 0.5 + sideDepth * 0.5
        let sectionHeight = baseY + height + frameTop
        let frontX = wallX + wallDepth * 0.5 + 0.45
        return [
            V15Mass(
                id: "\(id)-wall-south",
                role: "\(role)Wall",
                materialID: wallMaterialID,
                center: V15V3(
                    x: wallX,
                    y: sectionHeight * 0.5,
                    z: centerZ - sideOffset
                ),
                size: V15V3(
                    x: wallDepth,
                    y: sectionHeight,
                    z: sideDepth
                )
            ),
            V15Mass(
                id: "\(id)-wall-north",
                role: "\(role)Wall",
                materialID: wallMaterialID,
                center: V15V3(
                    x: wallX,
                    y: sectionHeight * 0.5,
                    z: centerZ + sideOffset
                ),
                size: V15V3(
                    x: wallDepth,
                    y: sectionHeight,
                    z: sideDepth
                )
            ),
            V15Mass(
                id: "\(id)-wall-header",
                role: "\(role)Header",
                materialID: wallMaterialID,
                center: V15V3(
                    x: wallX,
                    y: baseY + height + frameTop * 0.5,
                    z: centerZ
                ),
                size: V15V3(
                    x: wallDepth,
                    y: frameTop,
                    z: width
                )
            ),
            V15Mass(
                id: "\(id)-jamb-south",
                role: "\(role)Jamb",
                materialID: frameMaterialID,
                center: V15V3(
                    x: frontX,
                    y: baseY + height * 0.5,
                    z: centerZ - width * 0.5 - frameWidth * 0.5
                ),
                size: V15V3(
                    x: 0.9,
                    y: height + frameTop,
                    z: frameWidth
                )
            ),
            V15Mass(
                id: "\(id)-jamb-north",
                role: "\(role)Jamb",
                materialID: frameMaterialID,
                center: V15V3(
                    x: frontX,
                    y: baseY + height * 0.5,
                    z: centerZ + width * 0.5 + frameWidth * 0.5
                ),
                size: V15V3(
                    x: 0.9,
                    y: height + frameTop,
                    z: frameWidth
                )
            ),
            V15Mass(
                id: "\(id)-lintel",
                role: "\(role)Lintel",
                materialID: frameMaterialID,
                center: V15V3(
                    x: frontX,
                    y: baseY + height + frameTop * 0.5,
                    z: centerZ
                ),
                size: V15V3(
                    x: 0.9,
                    y: frameTop,
                    z: width + frameWidth * 2
                )
            ),
            backPlane,
        ]
    }
}

private func v16Argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        CommandLine.arguments.indices.contains(index + 1)
    else {
        throw V15SupportError.failed("missing \(name)")
    }
    return CommandLine.arguments[index + 1]
}

private func v16RecursiveIdentity(_ value: Any) -> Any {
    if let string = value as? String {
        return string
            .replacingOccurrences(of: "source-v14-prepixel", with: v16Revision)
            .replacingOccurrences(
                of: "industrial-l04-crucible-gantry-v14-north-board-led",
                with: v16GeometryID
            )
    }
    if let values = value as? [Any] {
        return values.map(v16RecursiveIdentity)
    }
    if let values = value as? [String: Any] {
        return values.mapValues(v16RecursiveIdentity)
    }
    return value
}

private func v16MassJSON(_ mass: V15Mass) -> [String: Any] {
    [
        "id": mass.id,
        "dimensions": [mass.size.x, mass.size.y, mass.size.z],
        "positionWorld": [mass.center.x, mass.center.y, mass.center.z],
        "materialID": mass.materialID,
    ]
}

private func v16PropJSON(_ mass: V15Mass) -> [String: Any] {
    [
        "id": mass.id,
        "kind": mass.shape == "cylinder"
            ? "explicit-cylinder" : "explicit-box",
        "dimensions": [mass.size.x, mass.size.y, mass.size.z],
        "positionWorld": [mass.center.x, mass.center.y, mass.center.z],
        "materialID": mass.materialID,
    ]
}

private func v16Palette(_ data: Data) throws -> [String: [Double]] {
    let library = try JSONSerialization.jsonObject(with: data) as! [String: Any]
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

private func v16Mass(
    _ id: String,
    _ role: String,
    _ material: String,
    _ center: (Double, Double, Double),
    _ size: (Double, Double, Double),
    shape: String = "box"
) -> V15Mass {
    V15Mass(
        id: id,
        role: role,
        materialID: material,
        center: V15V3(x: center.0, y: center.1, z: center.2),
        size: V15V3(x: size.0, y: size.1, z: size.2),
        shape: shape
    )
}

private func v16Geometry() throws -> (
    blocks: [V15Mass],
    props: [V15Mass],
    openings: [V16OpeningProof]
) {
    var blocks: [V15Mass] = [
        v16Mass(
            "v16-foundation", "foundation", "v14-dark-foundation",
            (0, 0.7, 0), (56, 1.4, 56)
        ),
        v16Mass(
            "v16-private-service-yard", "court", "v14-scored-concrete",
            (13, 1.2, 1), (30, 1.6, 34)
        ),
        v16Mass(
            "v16-north-freight-throat", "court", "v14-scored-concrete",
            (0, 1.2, -22), (12, 1.6, 12)
        ),
        v16Mass(
            "v16-hall-western-core", "hall", "v14-warm-masonry",
            (-18, 10.2, 1.5), (20, 17.6, 35)
        ),
        v16Mass(
            "v16-hall-roof", "hallRoof", "v14-dark-roof-steel",
            (-15, 20.5, 5), (28, 3, 44)
        ),
        v16Mass(
            "v16-clerestory-base", "hall", "v14-structural-mid-steel",
            (-15, 22.5, 7), (18, 2, 30)
        ),
        v16Mass(
            "v16-clerestory-cap", "hallRoof", "v14-dark-roof-steel",
            (-15, 25, 7), (21, 1.5, 32)
        ),
        v16Mass(
            "v16-side-return-upper-band", "hall", "v14-warm-masonry",
            (-2, 17.5, 0), (3, 4.5, 32)
        ),
        v16Mass(
            "v16-side-return-north-wall", "hall", "v14-warm-masonry",
            (-2, 9.5, 21.5), (3, 17.5, 11)
        ),
        v16Mass(
            "v16-staff-wall-west", "staff", "v14-warm-masonry",
            (-26.5, 6.2, 26), (3, 12.4, 4)
        ),
        v16Mass(
            "v16-staff-wall-east", "staff", "v14-warm-masonry",
            (-9.5, 6.2, 26), (15, 12.4, 4)
        ),
        v16Mass(
            "v16-staff-upper-wall", "staff", "v14-warm-masonry",
            (-18, 15.2, 26), (14, 5.6, 4)
        ),
        v16Mass(
            "v16-staff-control-roof", "staff", "v14-oxidized-copper",
            (-18, 19, 23), (16, 2, 10)
        ),
        v16Mass(
            "v16-throat-post-west", "throat", "v14-dark-gantry-steel",
            (-6.5, 6, -24), (2, 10, 4)
        ),
        v16Mass(
            "v16-throat-post-east", "throat", "v14-dark-gantry-steel",
            (6.5, 6, -24), (2, 10, 4)
        ),
        v16Mass(
            "v16-throat-header", "throat", "v14-structural-mid-steel",
            (0, 12, -24), (15, 3, 4)
        ),
        v16Mass(
            "v16-gantry-pier-west", "gantry", "v14-dark-gantry-steel",
            (8, 16, 14), (5, 29, 7)
        ),
        v16Mass(
            "v16-gantry-pier-east", "gantry", "v14-dark-gantry-steel",
            (26, 16, 14), (5, 29, 7)
        ),
        v16Mass(
            "v16-gantry-west-foot", "gantry", "v14-dark-gantry-steel",
            (8, 4, 14), (9, 7, 11)
        ),
        v16Mass(
            "v16-gantry-east-foot", "gantry", "v14-dark-gantry-steel",
            (26, 4, 14), (9, 7, 11)
        ),
        v16Mass(
            "v16-gantry-girder-south", "gantry", "v14-dark-gantry-steel",
            (17, 30, 10), (28, 5.5, 4)
        ),
        v16Mass(
            "v16-gantry-girder-north", "gantry", "v14-dark-gantry-steel",
            (17, 30, 18), (28, 5.5, 4)
        ),
        v16Mass(
            "v16-gantry-lower-flange", "gantry", "v14-structural-mid-steel",
            (17, 27.2, 14), (28, 1.4, 12)
        ),
        v16Mass(
            "v16-crane-trolley", "gantry", "v14-oxidized-copper",
            (17, 25.5, 14), (7, 5, 9)
        ),
        v16Mass(
            "v16-lift-rail", "gantry", "v14-process-heat",
            (17, 21, 14), (1.2, 8, 1.2)
        ),
        v16Mass(
            "v16-boiler-block", "stack", "v14-restrained-green",
            (-24, 8, 20), (8, 14, 10)
        ),
    ]
    var openings: [V16OpeningProof] = []
    for (index, centerZ) in [-11.0, 0.0, 11.0].enumerated() {
        let opening = V16SideOpening(
            id: "v16-side-freight-\(index + 1)",
            centerZ: centerZ,
            baseY: 2.3,
            width: 9,
            height: index == 0 ? 13 : 12,
            wallX: -2,
            wallDepth: 3,
            frameWidth: 0.8,
            frameTop: 2.5,
            backset: 3,
            wallMaterialID: "v14-warm-masonry",
            frameMaterialID: "v14-structural-mid-steel",
            backMaterialID: "v14-deep-freight-recess",
            role: "freight\(index + 1)"
        )
        blocks += try opening.loweredPositiveMasses(sectionDepth: 11)
        openings.append(
            V16OpeningProof(
                id: opening.id,
                role: opening.role,
                aperture: opening.aperture,
                backPlane: opening.backPlane
            )
        )
    }
    let staff = V15RecessedOpening(
        id: "v16-staff-opening",
        centerX: -18,
        baseY: 2.3,
        width: 6,
        height: 8,
        wallZ: 26,
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
    blocks += try staff.loweredPositiveMasses(sectionWidth: 14)
    openings.append(
        V16OpeningProof(
            id: staff.id,
            role: "staff",
            aperture: staff.aperture,
            backPlane: staff.insetBackPlane
        )
    )
    let props: [V15Mass] = [
        v16Mass(
            "v16-crucible-base", "crucible", "v14-dark-gantry-steel",
            (17, 4, 10), (16, 3, 16), shape: "cylinder"
        ),
        v16Mass(
            "v16-crucible-lower", "crucible", "v14-oxidized-copper",
            (17, 8, 10), (13, 7, 13), shape: "cylinder"
        ),
        v16Mass(
            "v16-crucible-shoulder", "crucible", "v14-oxidized-copper",
            (17, 13, 10), (17, 4, 17), shape: "cylinder"
        ),
        v16Mass(
            "v16-crucible-upper", "crucible", "v14-oxidized-copper-light",
            (17, 17, 10), (14, 5, 14), shape: "cylinder"
        ),
        v16Mass(
            "v16-crucible-neck", "crucible", "v14-dark-gantry-steel",
            (17, 20, 10), (10, 2, 10), shape: "cylinder"
        ),
        v16Mass(
            "v16-crucible-rim", "crucible", "v14-concrete-trim",
            (17, 21.8, 10), (13, 2.5, 13), shape: "cylinder"
        ),
        v16Mass(
            "v16-crucible-mouth", "crucible", "v14-process-heat",
            (17, 23.2, 10), (9, 1.5, 9), shape: "cylinder"
        ),
        v16Mass(
            "v16-stack", "stack", "v14-warm-masonry",
            (-24, 23, 20), (5, 29, 5), shape: "cylinder"
        ),
        v16Mass(
            "v16-stack-rim", "stack", "v14-dark-gantry-steel",
            (-24, 38, 20), (6.5, 2, 6.5), shape: "cylinder"
        ),
        v16Mass(
            "v16-service-pipe-a", "plant", "v14-oxidized-copper",
            (-26, 11, 8), (2.2, 17, 2.2), shape: "cylinder"
        ),
        v16Mass(
            "v16-service-pipe-b", "plant", "v14-oxidized-copper",
            (-26, 11, 14), (2.2, 17, 2.2), shape: "cylinder"
        ),
    ]
    return (blocks, props, openings)
}

private func v16OpeningReport(
    opening: V16OpeningProof,
    masses: [V15Mass],
    camera: V15Camera
) throws -> [String: Any] {
    let backBox = V15AABB(
        center: opening.backPlane.center,
        size: opening.backPlane.size
    )
    let overlapOwners = masses.filter {
        $0.id != opening.backPlane.id
            && v15Overlaps(
                V15AABB(center: $0.center, size: $0.size),
                opening.aperture
            )
    }.map(\.id).sorted()
    let samples = [-0.38, -0.19, 0.0, 0.19, 0.38]
    var selected: (V15V3, Double, Double)?
    var bestBlockers: [(id: String, distance: Double)] = []
    for vertical in samples {
        for lateral in samples {
            let target: V15V3
            if opening.role == "staff" {
                target = V15V3(
                    x: opening.backPlane.center.x
                        + opening.backPlane.size.x * lateral,
                    y: opening.backPlane.center.y
                        + opening.backPlane.size.y * vertical,
                    z: opening.backPlane.center.z
                )
            } else {
                target = V15V3(
                    x: opening.backPlane.center.x,
                    y: opening.backPlane.center.y
                        + opening.backPlane.size.y * vertical,
                    z: opening.backPlane.center.z
                        + opening.backPlane.size.z * lateral
                )
            }
            let direction = try v15Normalized(
                v15Subtract(target, camera.position)
            )
            guard
                let apertureDistance = v15RayHitDistance(
                    origin: camera.position,
                    direction: direction,
                    box: opening.aperture
                ),
                let backDistance = v15RayHitDistance(
                    origin: camera.position,
                    direction: direction,
                    box: backBox
                ),
                backDistance > apertureDistance
            else { continue }
            let blockers = masses.filter {
                $0.id != opening.backPlane.id
            }.compactMap { mass -> (id: String, distance: Double)? in
                guard
                    let distance = v15RayHitDistance(
                        origin: camera.position,
                        direction: direction,
                        box: V15AABB(center: mass.center, size: mass.size)
                    ),
                    distance < backDistance
                else { return nil }
                return (mass.id, distance)
            }.sorted { $0.distance < $1.distance }
            if blockers.isEmpty {
                selected = (target, apertureDistance, backDistance)
                break
            }
            if bestBlockers.isEmpty || blockers.count < bestBlockers.count {
                bestBlockers = blockers
            }
        }
        if selected != nil { break }
    }
    let compactCorners: [V15V3] = [
        opening.aperture.minimum,
        opening.aperture.maximum,
    ]
    let projected = compactCorners.map {
        v15Project($0, camera: camera, size: v16CompactSize)
    }
    var report: [String: Any] = [
        "openingID": opening.id,
        "role": opening.role,
        "positiveSolidOverlapCount": overlapOwners.count,
        "positiveSolidOverlapOwners": overlapOwners,
        "projectedCompactWidth": abs(projected[1].x - projected[0].x),
        "projectedCompactHeight": abs(projected[1].y - projected[0].y),
    ]
    if let selected {
        report["pass"] = overlapOwners.isEmpty
        report["rayFirstEncounter"] = "EMPTY_APERTURE"
        report["raySecondEncounter"] = opening.backPlane.id
        report["rayTarget"] = [
            selected.0.x, selected.0.y, selected.0.z,
        ]
        report["apertureEntryDistance"] = selected.1
        report["backPlaneDistance"] = selected.2
    } else {
        report["pass"] = false
        report["rayFirstEncounter"] = "BLOCKED"
        report["raySecondEncounter"] = "UNREACHED"
        report["blockingOwners"] = bestBlockers.map {
            ["id": $0.id, "distance": $0.distance]
        }
    }
    return report
}

private func v16LoadImage(_ url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw V15SupportError.failed("cannot load \(url.path)")
    }
    return image
}

private func v16Comparison(
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

private func v16RegistrationPanel(
    base: CGImage,
    registration: [String: Any]
) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: Int(v16CompactSize.width),
        height: Int(v16CompactSize.height),
        bitsPerComponent: 8,
        bytesPerRow: Int(v16CompactSize.width) * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw V15SupportError.failed("cannot make registration panel")
    }
    context.draw(base, in: CGRect(origin: .zero, size: v16CompactSize))
    func point(_ values: [NSNumber]) -> CGPoint {
        CGPoint(
            x: values[0].doubleValue / 8,
            y: v16CompactSize.height - values[1].doubleValue / 8
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
    context.setStrokeColor(CGColor(red: 0.1, green: 0.95, blue: 1, alpha: 1))
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
    let socketPoint = point(socket)
    context.setFillColor(CGColor(red: 0.1, green: 1, blue: 0.25, alpha: 1))
    context.fillEllipse(
        in: CGRect(x: socketPoint.x - 2, y: socketPoint.y - 2, width: 4, height: 4)
    )
    let pivotPoint = point(pivot)
    context.setStrokeColor(CGColor(red: 1, green: 0.1, blue: 0.1, alpha: 1))
    context.move(to: CGPoint(x: pivotPoint.x - 3, y: pivotPoint.y))
    context.addLine(to: CGPoint(x: pivotPoint.x + 3, y: pivotPoint.y))
    context.move(to: CGPoint(x: pivotPoint.x, y: pivotPoint.y - 3))
    context.addLine(to: CGPoint(x: pivotPoint.x, y: pivotPoint.y + 3))
    context.strokePath()
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 0.1, alpha: 1))
    context.setLineWidth(2)
    context.move(to: point(door[0]))
    context.addLine(to: point(door[1]))
    context.strokePath()
    guard let image = context.makeImage() else {
        throw V15SupportError.failed("cannot finish registration panel")
    }
    return image
}

private func v16Run(
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
    let materialData = try Data(contentsOf: v14MaterialURL)
    var scene = v16RecursiveIdentity(
        try JSONSerialization.jsonObject(with: v14SceneData)
    ) as! [String: Any]
    let geometry = try v16Geometry()
    scene["sourceRevision"] = v16Revision
    scene["sceneGeometryID"] = v16GeometryID
    scene["sourceAuthority"] = false
    scene["productionSelected"] = false
    scene["derivation"] = [
        "sourceKind": "offline-scene-v16-independent-l-side-return",
        "siblingSource": NSNull(),
        "mirror": false,
        "rotationDegrees": 0,
        "transform": "none",
    ]
    scene["materialLibrary"] = [
        "role": "industrial-l04-crucible-gantry-v16-north-material-library",
        "file": "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-crucible-gantry-v16-north-prepixel/materials/industrial-l04-crucible-gantry-v14-north-prepixel.json",
        "sha256": v15SHA256(materialData),
    ]
    if var sampling = scene["sampling"] as? [String: Any] {
        sampling["sourceRevisionBinding"] = v16Revision
        scene["sampling"] = sampling
    }
    var building = scene["building"] as! [String: Any]
    building["massBlocks"] = geometry.blocks.map(v16MassJSON)
    scene["building"] = building
    scene["props"] = geometry.props.map(v16PropJSON)
    var entrance = scene["entrance"] as! [String: Any]
    entrance["baseWorld"] = [0, -28]
    entrance["width"] = 12
    entrance["height"] = 12
    entrance["depth"] = 12
    entrance["style"] = "north-freight-court-throat"
    scene["entrance"] = entrance
    let camera = try v15Camera(from: scene)
    let doorLeft = v15Project(
        V15V3(x: -6, y: 0, z: -28),
        camera: camera,
        size: v16SourceSize
    )
    let doorRight = v15Project(
        V15V3(x: 6, y: 0, z: -28),
        camera: camera,
        size: v16SourceSize
    )
    var registration = scene["registration"] as! [String: Any]
    registration["doorBaseSource"] = [
        [doorLeft.x, doorLeft.y],
        [doorRight.x, doorRight.y],
    ]
    scene["registration"] = registration
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
    try materialData.write(to: materialURL)
    let sceneData = try v15StableJSON(scene)
    try sceneData.write(to: sceneURL)
    _ = try JSONDecoder().decode(SceneDescriptor.self, from: sceneData)
    _ = try JSONDecoder().decode(
        MaterialLibraryDescriptor.self,
        from: materialData
    )
    let persisted = try JSONSerialization.jsonObject(with: sceneData)
        as! [String: Any]
    let persistedCamera = try v15Camera(from: persisted)
    let palette = try v16Palette(materialData)
    let masses = geometry.blocks + geometry.props
    let openingReports = try geometry.openings.map {
        try v16OpeningReport(
            opening: $0,
            masses: masses,
            camera: persistedCamera
        )
    }
    let openingGatePass = openingReports.allSatisfy {
        ($0["pass"] as? Bool) == true
    }
    let throatLeft = v15Project(
        V15V3(x: -6, y: 1.2, z: -28),
        camera: persistedCamera,
        size: v16CompactSize
    )
    let throatRight = v15Project(
        V15V3(x: 6, y: 1.2, z: -28),
        camera: persistedCamera,
        size: v16CompactSize
    )
    let throatWidth = hypot(
        throatRight.x - throatLeft.x,
        throatRight.y - throatLeft.y
    )
    let review = evidenceRoot.appendingPathComponent("review")
    let sourceColor = try v15Render(
        masses: masses, camera: persistedCamera, palette: palette,
        size: v16SourceSize, grayscale: false
    )
    let sourceGray = try v15Render(
        masses: masses, camera: persistedCamera, palette: palette,
        size: v16SourceSize, grayscale: true
    )
    let nativeColor = try v15Render(
        masses: masses, camera: persistedCamera, palette: palette,
        size: v16NativeSize, grayscale: false
    )
    let nativeGray = try v15Render(
        masses: masses, camera: persistedCamera, palette: palette,
        size: v16NativeSize, grayscale: true
    )
    let compactColor = try v15Render(
        masses: masses, camera: persistedCamera, palette: palette,
        size: v16CompactSize, grayscale: false
    )
    let compactGray = try v15Render(
        masses: masses, camera: persistedCamera, palette: palette,
        size: v16CompactSize, grayscale: true
    )
    for (name, image) in [
        ("SOURCE-COLOR.png", sourceColor),
        ("SOURCE-GRAYSCALE.png", sourceGray),
        ("NATIVE-2X-COLOR.png", nativeColor),
        ("NATIVE-2X-GRAYSCALE.png", nativeGray),
        ("EXACT-192X128-COLOR.png", compactColor),
        ("EXACT-192X128-GRAYSCALE.png", compactGray),
    ] {
        try v15WritePNG(image, to: review.appendingPathComponent(name))
    }
    let semanticPalette = Dictionary(
        uniqueKeysWithValues: palette.keys.map { id -> (String, [Double]) in
            if id.contains("recess") { return (id, [0.95, 0.1, 0.8, 1]) }
            if id.contains("glazing") { return (id, [0.1, 0.95, 0.3, 1]) }
            if id.contains("concrete") { return (id, [0.15, 0.6, 1, 1]) }
            return (id, [0.25, 0.30, 0.34, 1])
        }
    )
    try v15WritePNG(
        try v15Render(
            masses: masses,
            camera: persistedCamera,
            palette: semanticPalette,
            size: v16CompactSize,
            grayscale: false
        ),
        to: review.appendingPathComponent("SEMANTIC-SUPPORTING.png")
    )
    try v15WritePNG(
        try v16RegistrationPanel(
            base: compactColor,
            registration: persisted["registration"] as! [String: Any]
        ),
        to: review.appendingPathComponent("REGISTRATION-CONTACT.png")
    )
    let silhouettePalette = Dictionary(
        uniqueKeysWithValues: palette.keys.map { ($0, [0.88, 0.88, 0.88, 1]) }
    )
    try v15WritePNG(
        try v15Render(
            masses: masses,
            camera: persistedCamera,
            palette: silhouettePalette,
            size: v16CompactSize,
            grayscale: false
        ),
        to: review.appendingPathComponent("ALL-BUILDING-SILHOUETTE.png")
    )
    for (suffix, size, currentColor, currentGray) in [
        ("SOURCE", v16SourceSize, sourceColor, sourceGray),
        ("NATIVE-2X", v16NativeSize, nativeColor, nativeGray),
        ("EXACT-192X128", v16CompactSize, compactColor, compactGray),
    ] {
        let oldColor = try v16LoadImage(
            v14Root.appendingPathComponent(
                "evidence/review/\(suffix)-COLOR.png"
            )
        )
        let oldGray = try v16LoadImage(
            v14Root.appendingPathComponent(
                "evidence/review/\(suffix)-GRAYSCALE.png"
            )
        )
        try v15WritePNG(
            try v16Comparison(left: oldColor, right: currentColor, cell: size),
            to: review.appendingPathComponent(
                "UNLABELLED-V14-V16-\(suffix)-COLOR.png"
            )
        )
        try v15WritePNG(
            try v16Comparison(left: oldGray, right: currentGray, cell: size),
            to: review.appendingPathComponent(
                "UNLABELLED-V14-V16-\(suffix)-GRAYSCALE.png"
            )
        )
    }
    let report: [String: Any] = [
        "taskID": "PLAY-027",
        "revision": v16Revision,
        "geometryID": v16GeometryID,
        "disposition": openingGatePass && throatWidth >= 5
            ? "PENDING_LITERAL_VISUAL_REVIEW"
            : "REJECTED_MACHINE_GATE",
        "descriptorSHA256": v15SHA256(sceneData),
        "materialSHA256": v15SHA256(materialData),
        "builderSourceSHA256": try v15SHA256(
            repositoryRoot.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4CrucibleGantryV16NorthPrepixel.swift"
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
        "openingGatePass": openingGatePass,
        "openingReports": openingReports,
        "northThroatCompactWidth": throatWidth,
        "northThroatMinimumPass": throatWidth >= 5,
        "northSocketSource": [896, 704],
        "groundPivotSource": [768, 896],
        "fixedFootprintWorld": [-28, 28, -28, 28],
        "orientationTransform": "none",
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
    let decisions = """
    # Industrial L4 North v16 design decisions

    - One independent L-shaped side-return foundry layout.
    - The exact North socket enters a 12-world-unit private freight throat.
    - Three real segmented recessed openings face +X on the visible hall return.
    - The hall core terminates behind every inset plane; no parent box fills a void.
    - Gantry and seven-tier crucible occupy the southeast service yard.
    - The staff opening is a separate +Z segmented return and remains secondary.
    - The accepted v14 material library is byte-preserved.
    - No mirror, rotation, sibling alias, raw render, or production selection.
    """
    try Data(decisions.utf8).write(
        to: evidenceRoot.appendingPathComponent("DESIGN-DECISIONS.md")
    )
    guard openingGatePass, throatWidth >= 5 else {
        throw V15SupportError.failed("v16 machine gate failed")
    }
}

@main
private enum BuildIndustrialL4CrucibleGantryV16NorthPrepixel {
    static func main() {
        do {
            try v16Run(
                repositoryRoot: URL(
                    fileURLWithPath: try v16Argument("--repository-root")
                ),
                artifactRoot: URL(
                    fileURLWithPath: try v16Argument("--artifact-root")
                ),
                evidenceRoot: URL(
                    fileURLWithPath: try v16Argument("--evidence-root")
                )
            )
            print("PASS v16 L-shaped side-return pre-pixel")
        } catch {
            fputs("FAIL \(error)\n", stderr)
            exit(1)
        }
    }
}
