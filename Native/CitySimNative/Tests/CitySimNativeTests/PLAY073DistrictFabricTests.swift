import AppKit
import Foundation
import SpriteKit
import XCTest
@testable import CitySimNative

final class PLAY073DistrictFabricTests: XCTestCase {
    @MainActor
    func testBackdropPreserves121PatchesAndAddsExactlyThreeRegionalMaterials() {
        let renderer = TerrainRenderer(style: WorldVisualStyle())
        let first = renderer.makeBackdrop(gridWidth: 24, gridHeight: 24, detail: .city)
        let second = renderer.makeBackdrop(gridWidth: 24, gridHeight: 24, detail: .city)

        let firstNames = descendantNames(in: first)
        XCTAssertEqual(
            firstNames.filter { $0.hasPrefix("terrain.macro.material.patch.") }.count,
            121
        )
        XCTAssertEqual(
            firstNames.filter { $0.hasPrefix("terrain.macro.regional.material.") }.count,
            3
        )
        XCTAssertFalse(firstNames.contains { $0.hasPrefix("terrain.hit-") })
        XCTAssertEqual(nodeSignature(first), nodeSignature(second))
    }

    @MainActor
    func testDistrictFabricJoinsTruthfulGroundAndKeepsExpansionBuildability() {
        let state = CityGameState.newCity(seed: 42)
        let originalKinds = Dictionary(uniqueKeysWithValues: state.tiles.map {
            ($0.coordinate, $0.kind)
        })
        let renderer = TerrainRenderer(style: WorldVisualStyle())
        let first = renderer.makeDevelopedDistrictGround(in: state, detail: .city)
        let second = renderer.makeDevelopedDistrictGround(in: state, detail: .city)
        let names = descendantNames(in: first)

        XCTAssertTrue(names.contains("district.fabric.authored-envelope"))
        XCTAssertTrue(names.contains("district.fabric.public-realm-envelope"))
        XCTAssertTrue(names.contains("district.fabric.expansion-band"))
        XCTAssertTrue(names.contains("district.ground.authoritative-public-realm"))
        XCTAssertFalse(names.contains { $0.hasPrefix("terrain.hit-") })
        XCTAssertTrue(descendantLabels(in: first).isEmpty)
        XCTAssertEqual(recursiveActiveActionCount(first), 0)
        XCTAssertEqual(nodeSignature(first), nodeSignature(second))

        for tile in state.tiles {
            XCTAssertEqual(state.tile(at: tile.coordinate)?.kind, originalKinds[tile.coordinate])
        }
    }

    @MainActor
    func testRoadFabricHierarchyCoversEveryMaskWithoutChangingRoadTopology() {
        let renderer = RoadRenderer(style: WorldVisualStyle())
        for mask in RoadConnectionMask.allMasks {
            let first = renderer.makeRoad(
                at: GridCoordinate(x: 8, y: 8),
                connections: mask,
                detail: .city,
                reducedMotion: true
            )
            let second = renderer.makeRoad(
                at: GridCoordinate(x: 8, y: 8),
                connections: mask,
                detail: .city,
                reducedMotion: true
            )
            let names = descendantNames(in: first)
            XCTAssertTrue(names.contains("road.fabric.hierarchy.\(mask.rawValue)"))
            XCTAssertTrue(names.contains("road.fabric.shadow"))
            XCTAssertTrue(names.contains("road.fabric.sidewalk"))
            XCTAssertTrue(names.contains("road.fabric.surface"))
            if !mask.isEmpty {
                XCTAssertTrue(names.contains("road.fabric.curb"))
            }
            XCTAssertEqual(nodeSignature(first), nodeSignature(second))
            XCTAssertEqual(recursiveActiveActionCount(first), 0)
        }
    }

    @MainActor
    func testRegularAndCompactSemanticMasksRepeatByteForByteWhenRequested() throws {
        let regular = try semanticMask(size: CGSize(width: 1_280, height: 800), detail: .city)
        let compact = try semanticMask(size: CGSize(width: 900, height: 600), detail: .neighborhood)
        XCTAssertGreaterThan(regular.count, 1_000)
        XCTAssertGreaterThan(compact.count, 1_000)

        if let path = ProcessInfo.processInfo.environment["PLAY073_R4_F1_REGULAR_MASK"] {
            try regular.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        if let path = ProcessInfo.processInfo.environment["PLAY073_R4_F1_COMPACT_MASK"] {
            try compact.write(to: URL(fileURLWithPath: path), options: .atomic)
        }

        let regularRepeat = try semanticMask(size: CGSize(width: 1_280, height: 800), detail: .city)
        let compactRepeat = try semanticMask(size: CGSize(width: 900, height: 600), detail: .neighborhood)
        XCTAssertEqual(regular, regularRepeat)
        XCTAssertEqual(compact, compactRepeat)
    }

    @MainActor
    func testF4ConservativeGreenMassStaysAtOrBelowQuarterAcrossFiveApertures() throws {
        let apertures: [(name: String, size: CGSize, detail: CameraDetailLevel, safe: CGRect, offset: CGPoint)] = [
            (
                "regular",
                CGSize(width: 1_229, height: 768),
                .city,
                CGRect(x: 0, y: 156, width: 1_229, height: 552),
                .zero
            ),
            (
                "compact",
                CGSize(width: 901, height: 653),
                .neighborhood,
                CGRect(x: 0, y: 164, width: 901, height: 417),
                CGPoint(x: -10, y: 4)
            ),
            (
                "compact-focus-city",
                CGSize(width: 901, height: 653),
                .neighborhood,
                CGRect(x: 0, y: 157, width: 901, height: 496),
                CGPoint(x: 18, y: -8)
            ),
            (
                "maximized-regular",
                CGSize(width: 1_277, height: 768),
                .city,
                CGRect(x: 0, y: 130, width: 1_277, height: 584),
                CGPoint(x: 16, y: 0)
            ),
            (
                "maximized-focus-city",
                CGSize(width: 1_277, height: 768),
                .city,
                CGRect(x: 0, y: 94, width: 1_277, height: 674),
                CGPoint(x: -16, y: 8)
            ),
        ]

        var measurements: [[String: Any]] = []
        for aperture in apertures {
            let rendered = try renderF4Aperture(
                size: aperture.size,
                detail: aperture.detail,
                offset: aperture.offset
            )
            let repeated = try renderF4Aperture(
                size: aperture.size,
                detail: aperture.detail,
                offset: aperture.offset
            )
            XCTAssertEqual(
                rendered.png,
                repeated.png,
                "\(aperture.name) semantic output was not deterministic"
            )
            let ratio = largestConservativeGreenRatio(
                in: rendered.image,
                safeAperture: aperture.safe,
                excluding: rendered.districtFrame
            )
            XCTAssertLessThanOrEqual(
                ratio,
                0.25,
                "\(aperture.name) conservative green ratio was \(ratio)"
            )
            measurements.append([
                "layout": aperture.name,
                "safeAperture": [
                    aperture.safe.minX,
                    aperture.safe.minY,
                    aperture.safe.width,
                    aperture.safe.height,
                ],
                "conservativeGreenRatio": ratio,
                "threshold": 0.25,
            ])

            if let path = ProcessInfo.processInfo.environment[
                "PLAY073_R4_F4_\(aperture.name.uppercased().replacingOccurrences(of: "-", with: "_"))"
            ] {
                try rendered.png.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
        if let path = ProcessInfo.processInfo.environment["PLAY073_R4_F4_METRICS"] {
            let data = try JSONSerialization.data(
                withJSONObject: measurements,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @MainActor
    private func renderF4Aperture(
        size: CGSize,
        detail: CameraDetailLevel,
        offset: CGPoint
    ) throws -> (image: NSBitmapImageRep, png: Data, districtFrame: CGRect) {
        let state = CityGameState.newCity(seed: 42)
        let style = WorldVisualStyle()
        let terrain = TerrainRenderer(style: style)
        let roads = RoadRenderer(style: style)
        let scene = SKScene(size: size)
        scene.backgroundColor = NSColor(calibratedWhite: 0.035, alpha: 1)

        let root = SKNode()
        root.addChild(terrain.makeBackdrop(
            gridWidth: state.gridWidth,
            gridHeight: state.gridHeight,
            detail: detail
        ))
        let district = terrain.makeDevelopedDistrictGround(in: state, detail: detail)
        root.addChild(district)
        for tile in state.tiles where tile.kind == .road {
            let road = roads.makeRoad(
                at: tile.coordinate,
                in: state,
                detail: detail,
                reducedMotion: true
            )
            road.position = style.isoPosition(tile.coordinate)
            root.addChild(road)
        }

        let rootFrame = root.calculateAccumulatedFrame()
        root.position = CGPoint(
            x: (size.width - rootFrame.width) / 2 - rootFrame.minX + offset.x,
            y: (size.height - rootFrame.height) / 2 - rootFrame.minY + offset.y
        )
        scene.addChild(root)

        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        let texture = try XCTUnwrap(view.texture(from: scene))
        let image = NSBitmapImageRep(cgImage: texture.cgImage())
        let png = try XCTUnwrap(image.representation(using: .png, properties: [:]))
        return (image, png, district.calculateAccumulatedFrame())
    }

    @MainActor
    private func largestConservativeGreenRatio(
        in image: NSBitmapImageRep,
        safeAperture: CGRect,
        excluding districtFrame: CGRect
    ) -> Double {
        let safe = safeAperture.intersection(
            CGRect(x: 0, y: 0, width: image.pixelsWide, height: image.pixelsHigh)
        )
        guard !safe.isNull, safe.width > 0, safe.height > 0 else { return 0 }

        func pixelIsGreen(_ x: Int, _ y: Int) -> Bool {
            guard let color = image.colorAt(x: x, y: y),
                  let rgb = color.usingColorSpace(.deviceRGB) else { return false }
            let red = rgb.redComponent * 255
            let green = rgb.greenComponent * 255
            let blue = rgb.blueComponent * 255
            return red >= 25 && red <= 135
                && green >= 45 && green <= 155
                && blue >= 20 && blue <= 130
                && green - red >= 9
                && green - blue >= 10
        }

        var greenPixels = Set<Int>()
        let minimumX = max(0, Int(floor(safe.minX)))
        let maximumX = min(image.pixelsWide - 1, Int(ceil(safe.maxX)) - 1)
        let minimumY = max(0, Int(floor(safe.minY)))
        let maximumY = min(image.pixelsHigh - 1, Int(ceil(safe.maxY)) - 1)
        for y in minimumY...maximumY {
            for x in minimumX...maximumX {
                guard !districtFrame.contains(CGPoint(x: x, y: y)),
                      pixelIsGreen(x, y) else { continue }
                greenPixels.insert(y * image.pixelsWide + x)
            }
        }

        var largest = 0
        while let seed = greenPixels.first {
            greenPixels.remove(seed)
            var pending = [seed]
            var count = 0
            while let current = pending.popLast() {
                count += 1
                let x = current % image.pixelsWide
                let y = current / image.pixelsWide
                for neighbor in [
                    current - 1,
                    current + 1,
                    current - image.pixelsWide,
                    current + image.pixelsWide,
                ] where greenPixels.remove(neighbor) != nil {
                    let neighborX = neighbor % image.pixelsWide
                    let neighborY = neighbor / image.pixelsWide
                    guard abs(neighborX - x) + abs(neighborY - y) == 1 else { continue }
                    pending.append(neighbor)
                }
            }
            largest = max(largest, count)
        }
        return Double(largest) / Double(max(1, Int(safe.width * safe.height)))
    }

    @MainActor
    private func semanticMask(size: CGSize, detail: CameraDetailLevel) throws -> Data {
        let state = CityGameState.newCity(seed: 42)
        let style = WorldVisualStyle()
        let terrain = TerrainRenderer(style: style)
        let roads = RoadRenderer(style: style)
        let scene = SKScene(size: size)
        scene.backgroundColor = NSColor(calibratedWhite: 0.035, alpha: 1)
        let root = SKNode()
        root.name = "play073.r4-f1.semantic-mask"
        root.addChild(terrain.makeBackdrop(
            gridWidth: state.gridWidth,
            gridHeight: state.gridHeight,
            detail: detail
        ))
        root.addChild(terrain.makeDevelopedDistrictGround(in: state, detail: detail))
        for tile in state.tiles where tile.kind == .road {
            let road = roads.makeRoad(
                at: tile.coordinate,
                in: state,
                detail: detail,
                reducedMotion: true
            )
            road.position = style.isoPosition(tile.coordinate)
            root.addChild(road)
        }
        let frame = root.calculateAccumulatedFrame()
        root.position = CGPoint(
            x: (size.width - frame.width) / 2 - frame.minX,
            y: (size.height - frame.height) / 2 - frame.minY
        )
        scene.addChild(root)

        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        let texture = try XCTUnwrap(view.texture(from: scene))
        let representation = NSBitmapImageRep(cgImage: texture.cgImage())
        return try XCTUnwrap(representation.representation(using: .png, properties: [:]))
    }

    @MainActor
    private func descendantNames(in node: SKNode) -> [String] {
        var result = node.name.map { [$0] } ?? []
        for child in node.children {
            result.append(contentsOf: descendantNames(in: child))
        }
        return result
    }

    @MainActor
    private func descendantLabels(in node: SKNode) -> [String] {
        var result: [String] = []
        if let label = node as? SKLabelNode, let text = label.text {
            result.append(text)
        }
        for child in node.children {
            result.append(contentsOf: descendantLabels(in: child))
        }
        return result
    }

    @MainActor
    private func recursiveActiveActionCount(_ node: SKNode) -> Int {
        let local = node.hasActions() ? 1 : 0
        return node.children.reduce(local) { $0 + recursiveActiveActionCount($1) }
    }

    @MainActor
    private func nodeSignature(_ node: SKNode) -> [String] {
        var result = [
            "\(node.name ?? "")|\(String(format: "%.3f", node.position.x))|\(String(format: "%.3f", node.position.y))|\(String(format: "%.3f", node.zPosition))|\(node.children.count)"
        ]
        for child in node.children {
            result.append(contentsOf: nodeSignature(child))
        }
        return result
    }
}
