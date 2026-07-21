import AppKit
import SpriteKit

/// Renders lifecycle cues from the renderer-only interpretation of authoritative
/// `CityTile` fields. Nothing in this component feeds state back to simulation.
@MainActor
final class LotLifecycleRenderer {
    private let style: WorldVisualStyle

    init(style: WorldVisualStyle) {
        self.style = style
    }

    func makeConstruction(
        for tile: CityTile,
        stage: LotConstructionStage,
        detail: CameraDetailLevel,
        reducedMotion: Bool
    ) -> SKNode {
        let root = SKNode()
        root.name = "lot.lifecycle.construction.\(stage.label.lowercased())"
        root.zPosition = 80

        let city = style.makeDetailLayer(.city, visibleAt: detail)
        let neighborhood = style.makeDetailLayer(.neighborhood, visibleAt: detail)
        let block = style.makeDetailLayer(.block, visibleAt: detail)
        root.addChild(city)
        root.addChild(neighborhood)
        root.addChild(block)

        addPreparedSite(stage: stage, to: city)
        switch stage {
        case .site:
            addExcavation(to: city)
            addSurveyStakes(to: neighborhood)
            addEarthMovingTracks(to: block)
        case .foundation:
            addFoundation(to: city)
            addRebar(to: neighborhood)
            addMaterialPallets(to: block)
        case .structure:
            addFoundation(to: city)
            addStructuralFrame(to: city)
            addTowerCrane(for: tile, reducedMotion: reducedMotion, to: neighborhood)
            addMaterialPallets(to: block)
        case .finishing:
            addFoundation(to: city)
            addScaffold(to: city)
            addTowerCrane(for: tile, reducedMotion: reducedMotion, to: neighborhood)
            addFinishProps(to: block)
        case .complete:
            break
        }

        if stage != .complete {
            addSafetyCones(to: block)
        }
        return root
    }

    func makeCompletedState(
        for tile: CityTile,
        presentation: LotConsequencePresentation,
        detail: CameraDetailLevel,
        reducedMotion: Bool
    ) -> SKNode {
        let root = SKNode()
        root.name = "lot.lifecycle.complete"
        root.zPosition = 72

        let city = style.makeDetailLayer(.city, visibleAt: detail)
        let neighborhood = style.makeDetailLayer(.neighborhood, visibleAt: detail)
        let block = style.makeDetailLayer(.block, visibleAt: detail)
        root.addChild(city)
        root.addChild(neighborhood)
        root.addChild(block)

        addCondition(
            presentation.condition,
            for: tile,
            reducedMotion: reducedMotion,
            city: city,
            neighborhood: neighborhood,
            block: block
        )

        if presentation.condition == .maintained, presentation.growthTier > 1 {
            addHealthyGrowth(
                tier: presentation.growthTier,
                for: tile,
                reducedMotion: reducedMotion,
                city: city,
                neighborhood: neighborhood,
                block: block
            )
        }
        return root
    }

    private func addPreparedSite(stage: LotConstructionStage, to node: SKNode) {
        let preparedSite = SKShapeNode(path: style.diamondPath(width: 62, height: 31))
        preparedSite.fillColor = style.palette.soil.withAlphaComponent(0.96)
        preparedSite.strokeColor = constructionColor.withAlphaComponent(0.92)
        preparedSite.lineWidth = stage == .site ? 2.2 : 1.4
        preparedSite.name = "lot.construction.site"
        node.addChild(preparedSite)
    }

    private func addExcavation(to node: SKNode) {
        let pit = SKShapeNode(path: style.diamondPath(width: 43, height: 21))
        pit.fillColor = NSColor(calibratedRed: 0.17, green: 0.13, blue: 0.09, alpha: 1)
        pit.strokeColor = NSColor(calibratedWhite: 0.78, alpha: 0.38)
        pit.lineWidth = 1.2
        pit.position.y = -1
        pit.name = "lot.construction.excavation"
        node.addChild(pit)

        for (index, x) in [-23.0, 23.0].enumerated() {
            let pile = SKShapeNode(path: style.polygonPath([
                CGPoint(x: -10, y: -3),
                CGPoint(x: -2, y: 7 + CGFloat(index) * 2),
                CGPoint(x: 10, y: -3)
            ]))
            pile.fillColor = style.palette.soil.blended(withFraction: 0.18, of: .white) ?? style.palette.soil
            pile.strokeColor = NSColor.black.withAlphaComponent(0.26)
            pile.position = CGPoint(x: x, y: -4 + CGFloat(index) * 6)
            pile.name = "lot.construction.earthPile"
            node.addChild(pile)
        }
    }

    private func addFoundation(to node: SKNode) {
        let slab = SKShapeNode(path: style.diamondPath(width: 49, height: 24))
        slab.fillColor = style.palette.concrete.withAlphaComponent(0.98)
        slab.strokeColor = NSColor.white.withAlphaComponent(0.56)
        slab.lineWidth = 1.5
        slab.position.y = 2
        slab.name = "lot.construction.foundation"
        node.addChild(slab)

        let inset = SKShapeNode(path: style.diamondPath(width: 34, height: 16))
        inset.fillColor = .clear
        inset.strokeColor = NSColor(calibratedWhite: 0.18, alpha: 0.72)
        inset.lineWidth = 1.1
        inset.position.y = 3
        node.addChild(inset)
    }

    private func addStructuralFrame(to node: SKNode) {
        let frame = SKNode()
        frame.name = "lot.construction.frameSilhouette"
        for x in [-20.0, 0.0, 20.0] {
            let upright = SKShapeNode(rectOf: CGSize(width: 2.5, height: 43))
            upright.fillColor = constructionColor
            upright.strokeColor = NSColor.black.withAlphaComponent(0.22)
            upright.position = CGPoint(x: x, y: 23)
            frame.addChild(upright)
        }
        for row in 0..<4 {
            let rail = SKShapeNode(rectOf: CGSize(width: 45, height: 2))
            rail.fillColor = constructionColor.withAlphaComponent(0.94)
            rail.strokeColor = NSColor.black.withAlphaComponent(0.18)
            rail.position = CGPoint(x: 0, y: CGFloat(row) * 12 + 6)
            frame.addChild(rail)
        }
        node.addChild(frame)
    }

    private func addScaffold(to node: SKNode) {
        let scaffold = SKNode()
        scaffold.name = "lot.construction.scaffoldSilhouette"
        for x in [-25.0, -8.0, 8.0, 25.0] {
            let upright = SKShapeNode(rectOf: CGSize(width: 1.7, height: 48))
            upright.fillColor = constructionColor.withAlphaComponent(0.92)
            upright.strokeColor = .clear
            upright.position = CGPoint(x: x, y: 24)
            scaffold.addChild(upright)
        }
        for row in 0..<5 {
            let platform = SKShapeNode(rectOf: CGSize(width: 54, height: 1.5))
            platform.fillColor = constructionColor.withAlphaComponent(0.78)
            platform.strokeColor = .clear
            platform.position = CGPoint(x: 0, y: CGFloat(row) * 10 + 4)
            scaffold.addChild(platform)
        }
        let wrap = SKShapeNode(rectOf: CGSize(width: 51, height: 39), cornerRadius: 2)
        wrap.fillColor = NSColor(calibratedRed: 0.72, green: 0.66, blue: 0.51, alpha: 0.14)
        wrap.strokeColor = NSColor(calibratedRed: 0.57, green: 0.52, blue: 0.39, alpha: 0.72)
        wrap.lineWidth = 1.4
        wrap.position.y = 22
        wrap.name = "lot.construction.finishWrap"
        scaffold.addChild(wrap)
        node.addChild(scaffold)
    }

    private func addSurveyStakes(to node: SKNode) {
        for x in [-25.0, 25.0] {
            let stake = SKShapeNode(rectOf: CGSize(width: 1.8, height: 13))
            stake.fillColor = constructionColor
            stake.strokeColor = .clear
            stake.position = CGPoint(x: x, y: 8)
            stake.name = "lot.construction.surveyStake"
            node.addChild(stake)

            let flag = SKShapeNode(path: style.polygonPath([
                CGPoint(x: 0, y: 5), CGPoint(x: 8, y: 2), CGPoint(x: 0, y: -1)
            ]))
            flag.fillColor = .systemRed
            flag.strokeColor = .clear
            flag.position = CGPoint(x: x, y: 14)
            node.addChild(flag)
        }
    }

    private func addRebar(to node: SKNode) {
        let rebar = SKNode()
        rebar.name = "lot.construction.rebar"
        for x in stride(from: -18.0, through: 18.0, by: 9.0) {
            let rod = SKShapeNode(rectOf: CGSize(width: 1.2, height: 22))
            rod.fillColor = NSColor(calibratedRed: 0.47, green: 0.24, blue: 0.12, alpha: 1)
            rod.strokeColor = .clear
            rod.position = CGPoint(x: x, y: 14)
            rebar.addChild(rod)
        }
        let tie = SKShapeNode(rectOf: CGSize(width: 43, height: 1.2))
        tie.fillColor = NSColor(calibratedRed: 0.47, green: 0.24, blue: 0.12, alpha: 1)
        tie.strokeColor = .clear
        tie.position.y = 9
        rebar.addChild(tie)
        node.addChild(rebar)
    }

    private func addTowerCrane(for tile: CityTile, reducedMotion: Bool, to node: SKNode) {
        let crane = SKNode()
        crane.name = "lot.construction.crane"
        crane.position = CGPoint(x: 21, y: 3)

        let mast = SKShapeNode(rectOf: CGSize(width: 3, height: 57))
        mast.fillColor = constructionColor
        mast.strokeColor = NSColor.black.withAlphaComponent(0.24)
        mast.position.y = 28
        crane.addChild(mast)

        let boom = SKShapeNode(path: WorldGeometryCache.line(
            from: CGPoint(x: -37, y: 0),
            to: CGPoint(x: 18, y: 0)
        ))
        boom.strokeColor = constructionColor
        boom.lineWidth = 3
        boom.position.y = 56
        boom.name = "lot.construction.craneBoom"
        crane.addChild(boom)

        let hookLine = SKShapeNode(path: WorldGeometryCache.line(
            from: CGPoint(x: -29, y: 55),
            to: CGPoint(x: -29, y: 31)
        ))
        hookLine.strokeColor = NSColor(calibratedWhite: 0.16, alpha: 0.9)
        hookLine.lineWidth = 1
        crane.addChild(hookLine)

        let load = SKShapeNode(rectOf: CGSize(width: 8, height: 5), cornerRadius: 1)
        load.fillColor = style.palette.concreteLight
        load.strokeColor = NSColor.black.withAlphaComponent(0.32)
        load.position = CGPoint(x: -29, y: 29)
        crane.addChild(load)

        if !reducedMotion {
            runDeterministicLoop(
                .sequence([
                    .rotate(toAngle: 0.075, duration: 1.6, shortestUnitArc: true),
                    .rotate(toAngle: -0.075, duration: 1.6, shortestUnitArc: true)
                ]),
                on: boom,
                for: tile,
                salt: 0xC8A6E,
                key: "lifecycle.crane"
            )
        }
        node.addChild(crane)
    }

    private func addConstructionProgress(stage: LotConstructionStage, progress rawProgress: Double, to node: SKNode) {
        let progress = min(1, max(0, rawProgress))
        let track = SKShapeNode(rectOf: CGSize(width: 44, height: 5), cornerRadius: 2.5)
        track.fillColor = NSColor.black.withAlphaComponent(0.64)
        track.strokeColor = NSColor.white.withAlphaComponent(0.28)
        track.position = CGPoint(x: 0, y: -12)
        track.name = "lot.construction.progressTrack.\(stage.label.lowercased())"
        node.addChild(track)

        let width = max(3, 42 * progress)
        let fill = SKShapeNode(rectOf: CGSize(width: width, height: 3), cornerRadius: 1.5)
        fill.fillColor = constructionColor
        fill.strokeColor = .clear
        fill.position = CGPoint(x: -21 + width / 2, y: -12)
        fill.name = "lot.construction.progress"
        node.addChild(fill)
    }

    private func addSafetyCones(to node: SKNode) {
        for (index, x) in [-27.0, 27.0].enumerated() {
            let cone = SKShapeNode(path: style.polygonPath([
                CGPoint(x: 0, y: 6), CGPoint(x: -4, y: -3), CGPoint(x: 4, y: -3)
            ]))
            cone.fillColor = constructionColor
            cone.strokeColor = NSColor.white.withAlphaComponent(0.72)
            cone.lineWidth = 0.8
            cone.position = CGPoint(x: x, y: -4 + CGFloat(index) * 4)
            cone.name = "lot.construction.safetyCone"
            node.addChild(cone)
        }
    }

    private func addConstructionMotion(
        for tile: CityTile,
        stage: LotConstructionStage,
        reducedMotion: Bool,
        to node: SKNode
    ) {
        guard !reducedMotion else { return }
        let dust = SKNode()
        dust.name = "lot.lifecycle.motion.constructionDust"
        dust.position = CGPoint(x: stage == .site ? 3 : -19, y: stage == .finishing ? 33 : 9)
        for index in 0..<3 {
            let mote = SKShapeNode(circleOfRadius: 2.6 + CGFloat(index) * 0.7)
            mote.fillColor = NSColor(calibratedRed: 0.77, green: 0.66, blue: 0.46, alpha: 0.44)
            mote.strokeColor = .clear
            mote.position = CGPoint(x: CGFloat(index * 7 - 7), y: CGFloat(index * 3))
            dust.addChild(mote)
        }
        runDeterministicLoop(
            .sequence([
                .group([.moveBy(x: 0, y: 6, duration: 1.1), .fadeAlpha(to: 0.28, duration: 1.1)]),
                .group([.moveBy(x: 0, y: -6, duration: 0), .fadeAlpha(to: 1, duration: 0.2)])
            ]),
            on: dust,
            for: tile,
            salt: 0xD057,
            key: "lifecycle.dust"
        )
        node.addChild(dust)
    }

    private func addEarthMovingTracks(to node: SKNode) {
        for offset in [-5.0, 5.0] {
            for segment in 0..<6 {
                let startX = CGFloat(segment) * 7 - 20
                let startY = offset - 8 + CGFloat(segment) * 1.9
                let track = SKShapeNode(path: WorldGeometryCache.line(
                    from: CGPoint(x: startX, y: startY),
                    to: CGPoint(x: startX + 4, y: startY + 1.2)
                ))
                track.strokeColor = NSColor.black.withAlphaComponent(0.34)
                track.lineWidth = 1.8
                track.name = "lot.construction.trackMark"
                node.addChild(track)
            }
        }
    }

    private func addMaterialPallets(to node: SKNode) {
        for index in 0..<3 {
            let pallet = SKShapeNode(rectOf: CGSize(width: 11, height: 4), cornerRadius: 0.7)
            pallet.fillColor = NSColor(calibratedRed: 0.54, green: 0.34, blue: 0.16, alpha: 1)
            pallet.strokeColor = NSColor.black.withAlphaComponent(0.28)
            pallet.position = CGPoint(x: -24 + CGFloat(index) * 6, y: -2 + CGFloat(index) * 3)
            pallet.name = "lot.construction.materialPallet"
            node.addChild(pallet)
        }
    }

    private func addFinishProps(to node: SKNode) {
        addMaterialPallets(to: node)
        for index in 0..<2 {
            let bucket = SKShapeNode(rectOf: CGSize(width: 5, height: 6), cornerRadius: 1)
            bucket.fillColor = index == 0
                ? NSColor(calibratedRed: 0.38, green: 0.46, blue: 0.43, alpha: 1)
                : NSColor(calibratedRed: 0.76, green: 0.63, blue: 0.35, alpha: 1)
            bucket.strokeColor = NSColor.white.withAlphaComponent(0.38)
            bucket.position = CGPoint(x: 19 + CGFloat(index) * 7, y: -2 + CGFloat(index) * 3)
            bucket.name = "lot.construction.finishBucket"
            node.addChild(bucket)
        }
    }

    private func addCondition(
        _ condition: LotConditionPresentation,
        for tile: CityTile,
        reducedMotion: Bool,
        city: SKNode,
        neighborhood: SKNode,
        block: SKNode
    ) {
        switch condition {
        case .maintained:
            break
        case .weathered:
            addStressSilhouette(distressed: false, to: city)
            addDryPlanters(to: block)
        case .distressed:
            addStressSilhouette(distressed: true, to: city)
            addBoarding(to: neighborhood)
            addRubble(to: block)
        }
    }

    private func addMaintainedFrontage(to node: SKNode) {
        let frontage = SKNode()
        frontage.name = "lot.lifecycle.condition.maintained"
        let curb = SKShapeNode(path: WorldGeometryCache.line(
            from: CGPoint(x: -21, y: -11),
            to: CGPoint(x: 21, y: -11)
        ))
        curb.strokeColor = NSColor(calibratedWhite: 0.88, alpha: 0.72)
        curb.lineWidth = 1.7
        frontage.addChild(curb)
        for x in [-17.0, 17.0] {
            let planter = SKShapeNode(rectOf: CGSize(width: 8, height: 4), cornerRadius: 1)
            planter.fillColor = NSColor(calibratedRed: 0.22, green: 0.38, blue: 0.20, alpha: 1)
            planter.strokeColor = NSColor.white.withAlphaComponent(0.22)
            planter.position = CGPoint(x: x, y: -7)
            frontage.addChild(planter)
        }
        node.addChild(frontage)
    }

    private func addStressSilhouette(distressed: Bool, to node: SKNode) {
        let layer = SKNode()
        layer.name = "lot.lifecycle.condition.\(distressed ? "distressed" : "weathered")"
        let color = distressed
            ? NSColor(calibratedRed: 0.25, green: 0.18, blue: 0.14, alpha: 1)
            : NSColor(calibratedRed: 0.48, green: 0.36, blue: 0.23, alpha: 1)

        let sag = SKShapeNode(path: style.polygonPath([
            CGPoint(x: -28, y: 33),
            CGPoint(x: -8, y: 28),
            CGPoint(x: 8, y: 34),
            CGPoint(x: 27, y: 26)
        ]))
        sag.strokeColor = color.withAlphaComponent(0.82)
        sag.lineWidth = distressed ? 3 : 1.8
        sag.fillColor = .clear
        sag.name = "lot.condition.saggingProfile"
        layer.addChild(sag)

        for index in 0..<(distressed ? 4 : 2) {
            let x = CGFloat(index * 12 - 18)
            let crack = CGMutablePath()
            crack.move(to: CGPoint(x: x - 5, y: -8))
            crack.addLine(to: CGPoint(x: x, y: -2))
            crack.addLine(to: CGPoint(x: x - 3, y: 4))
            crack.addLine(to: CGPoint(x: x + 4, y: 9))
            let crackNode = SKShapeNode(path: crack)
            crackNode.strokeColor = color.withAlphaComponent(0.88)
            crackNode.lineWidth = 1.2
            crackNode.lineCap = .round
            layer.addChild(crackNode)
        }
        node.addChild(layer)
    }

    private func addPatchwork(
        for tile: CityTile,
        distressed: Bool,
        reducedMotion: Bool,
        to node: SKNode
    ) {
        let patch = SKNode()
        patch.name = "lot.condition.patchwork"
        let color = distressed ? NSColor.systemRed : NSColor.systemOrange
        for index in 0..<(distressed ? 3 : 2) {
            let panel = SKShapeNode(rectOf: CGSize(width: 13, height: 7), cornerRadius: 1)
            panel.fillColor = NSColor(calibratedWhite: 0.16, alpha: 0.84)
            panel.strokeColor = color.withAlphaComponent(0.74)
            panel.lineWidth = 1
            panel.position = CGPoint(x: CGFloat(index * 13 - 13), y: 12 + CGFloat(index % 2) * 9)
            patch.addChild(panel)
        }

        let ribbon = SKShapeNode(rectOf: CGSize(width: 43, height: 2.5), cornerRadius: 1)
        ribbon.fillColor = color
        ribbon.strokeColor = .clear
        ribbon.position = CGPoint(x: 0, y: 41)
        ribbon.name = "lot.lifecycle.motion.cautionRibbon"
        patch.addChild(ribbon)
        if !reducedMotion {
            runDeterministicLoop(
                .sequence([
                    .scaleX(to: 0.86, duration: 0.55),
                    .scaleX(to: 1.0, duration: 0.55)
                ]),
                on: ribbon,
                for: tile,
                salt: distressed ? 0xDEC1 : 0x57E55,
                key: "lifecycle.ribbon"
            )
        }
        node.addChild(patch)
    }

    private func addBoarding(to node: SKNode) {
        let boarding = SKNode()
        boarding.name = "lot.condition.boarding"
        for y in [12.0, 25.0, 38.0] {
            let left = SKShapeNode(rectOf: CGSize(width: 22, height: 3), cornerRadius: 0.6)
            left.fillColor = NSColor(calibratedRed: 0.43, green: 0.27, blue: 0.13, alpha: 1)
            left.strokeColor = NSColor.black.withAlphaComponent(0.32)
            left.position = CGPoint(x: -7, y: y)
            left.zRotation = 0.24
            boarding.addChild(left)

            let right = left.copy() as! SKShapeNode
            right.zRotation = -0.24
            right.position.x = 7
            boarding.addChild(right)
        }
        node.addChild(boarding)
    }

    private func addRubble(to node: SKNode) {
        let rubble = SKNode()
        rubble.name = "lot.condition.rubble"
        for index in 0..<6 {
            let chunk = SKShapeNode(path: style.polygonPath([
                CGPoint(x: -3, y: -2), CGPoint(x: 1, y: 3), CGPoint(x: 4, y: -1)
            ]))
            chunk.fillColor = index.isMultiple(of: 2) ? style.palette.concrete : style.palette.soil
            chunk.strokeColor = NSColor.black.withAlphaComponent(0.28)
            chunk.position = CGPoint(
                x: CGFloat(index * 7 - 18),
                y: -7 + CGFloat(index % 3) * 3
            )
            rubble.addChild(chunk)
        }
        node.addChild(rubble)
    }

    private func addDryPlanters(to node: SKNode) {
        let props = SKNode()
        props.name = "lot.condition.dryPlanters"
        for x in [-17.0, 17.0] {
            let planter = SKShapeNode(rectOf: CGSize(width: 9, height: 4), cornerRadius: 1)
            planter.fillColor = style.palette.soil
            planter.strokeColor = NSColor.systemOrange.withAlphaComponent(0.7)
            planter.position = CGPoint(x: x, y: -7)
            props.addChild(planter)
            let stem = SKShapeNode(path: WorldGeometryCache.line(
                from: CGPoint(x: x, y: -4),
                to: CGPoint(x: x + 3, y: 3)
            ))
            stem.strokeColor = NSColor(calibratedRed: 0.42, green: 0.29, blue: 0.13, alpha: 1)
            stem.lineWidth = 1.2
            props.addChild(stem)
        }
        node.addChild(props)
    }

    private func addHealthyGrowth(
        tier: Int,
        for tile: CityTile,
        reducedMotion: Bool,
        city: SKNode,
        neighborhood: SKNode,
        block: SKNode
    ) {
        let growth = SKNode()
        growth.name = "lot.lifecycle.growth.tier.\(tier)"
        city.addChild(growth)

        let freshFacade = SKNode()
        freshFacade.name = "lot.growth.freshFacade"
        for index in 0..<min(4, tier + 1) {
            let window = SKShapeNode(rectOf: CGSize(width: 6, height: 8), cornerRadius: 0.8)
            window.fillColor = style.palette.warmWindow.withAlphaComponent(0.92)
            window.strokeColor = NSColor.white.withAlphaComponent(0.32)
            window.lineWidth = 0.7
            window.position = CGPoint(x: CGFloat(index * 9 - 14), y: 21)
            freshFacade.addChild(window)
        }
        let sill = SKShapeNode(rectOf: CGSize(width: 38, height: 1.5), cornerRadius: 0.5)
        sill.fillColor = style.palette.concreteLight
        sill.strokeColor = .clear
        sill.position = CGPoint(x: 0, y: 15)
        freshFacade.addChild(sill)
        neighborhood.addChild(freshFacade)

        let entranceCanopy = SKShapeNode(path: style.diamondPath(width: 24, height: 8))
        entranceCanopy.name = "lot.growth.entrance-canopy"
        entranceCanopy.fillColor = style.palette.civicRoof.withAlphaComponent(0.92)
        entranceCanopy.strokeColor = style.palette.concreteLight.withAlphaComponent(0.38)
        entranceCanopy.lineWidth = 0.7
        entranceCanopy.position = CGPoint(x: 4, y: 9)
        block.addChild(entranceCanopy)
    }

    private func runDeterministicLoop(
        _ action: SKAction,
        on node: SKNode,
        for tile: CityTile,
        salt: UInt64,
        key: String
    ) {
        let phase = Double(WorldVisualSeed.unit(
            for: tile.coordinate,
            kind: tile.kind,
            salt: salt
        )) * 0.9
        node.run(.sequence([.wait(forDuration: phase), .repeatForever(action)]), withKey: key)
    }

    private var constructionColor: NSColor {
        NSColor(calibratedRed: 0.61, green: 0.43, blue: 0.22, alpha: 1)
    }
}
