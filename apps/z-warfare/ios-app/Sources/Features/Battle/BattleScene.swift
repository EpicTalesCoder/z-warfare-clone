import Foundation
import SpriteKit
import SwiftUI

// Port of CampaignController / Arena BattleRenderer + Camera pan + Unit Sprite Animator
// Evidence: GameSprites/Backgrounds/loc_*, GameSprites/Bus/*, GameSprites/UnitSheets/*, GameSprites/Battle/*
public final class ZWBattleScene: SKScene {
    public weak var engine: ZWBattleEngine?

    private let worldLayer = SKNode()
    private let bgLayer = SKNode()
    private let actorLayer = SKNode()
    private let fxLayer = SKNode()

    private var actorNodes: [UUID: SKNode] = [:]
    private var actorLastState: [UUID: ZWAnimState] = [:]
    private var zoneNodes: [UUID: SKShapeNode] = [:]
    private var floatingNodes: [UUID: SKLabelNode] = [:]

    private var busNode: SKSpriteNode?
    private var billNode: SKSpriteNode?
    private var barricadeNode: SKSpriteNode?
    private var busFireOverlay: SKShapeNode?

    private let worldWidth: CGFloat = 1180
    private let worldHeight: CGFloat = 414
    private var cameraOffsetX: CGFloat = 0
    private var lastTouchX: CGFloat?

    public var onWorldTapX: ((Double) -> Void)?

    public init(engine: ZWBattleEngine) {
        self.engine = engine
        super.init(size: CGSize(width: 896, height: 414))
        self.scaleMode = .aspectFill
        self.backgroundColor = SKColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1.0)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMove(to view: SKView) {
        removeAllChildren()
        addChild(worldLayer)
        worldLayer.addChild(bgLayer)
        worldLayer.addChild(actorLayer)
        worldLayer.addChild(fxLayer)

        buildEnvironment()
        buildBusAndBarricade()
    }

    private func buildEnvironment() {
        bgLayer.removeAllChildren()
        let locID = engine?.mission.location ?? 1
        let loader = ZWSpriteLoader.shared
        let allBGs = loader.availableFileNames(in: .backgrounds)

        let modePrefix: String = {
            switch engine?.mode {
            case .metro: return "loc_metro_"
            case .weeklyEvent: return "loc_bridge_"
            default: return "loc_\(locID)_"
            }
        }()

        // Sky backdrop gradient panel behind tiled pixel art
        let skyNode = SKSpriteNode(color: skyColor(for: locID), size: CGSize(width: worldWidth, height: worldHeight))
        skyNode.position = CGPoint(x: worldWidth * 0.5, y: worldHeight * 0.5)
        skyNode.zPosition = -30
        bgLayer.addChild(skyNode)

        // Foreground scenery textures from GameSprites/Backgrounds
        let scenicNames = allBGs.filter { $0.hasPrefix(modePrefix) && !$0.contains("_road_") }
        if let bgName = scenicNames.first, let tex = loader.skTexture(named: bgName, in: .backgrounds) {
            let scale = (worldHeight * 0.56) / max(1, tex.size().height)
            let tileW = max(120, tex.size().width * scale)
            let count = Int(ceil(worldWidth / tileW)) + 1
            for i in 0..<count {
                let tile = SKSpriteNode(texture: tex)
                tile.anchorPoint = CGPoint(x: 0, y: 0)
                tile.size = CGSize(width: tileW, height: tex.size().height * scale)
                tile.position = CGPoint(x: CGFloat(i) * tileW, y: 175)
                tile.zPosition = -20
                bgLayer.addChild(tile)
            }
        }

        // Asphalt road tiles (bottom half combat lanes)
        let roadNames = allBGs.filter { $0.hasPrefix(modePrefix) && $0.contains("_road_") }
        if let roadName = roadNames.first, let rTex = loader.skTexture(named: roadName, in: .backgrounds) {
            let scale = 195 / max(1, rTex.size().height)
            let tileW = max(100, rTex.size().width * scale)
            let count = Int(ceil(worldWidth / tileW)) + 1
            for i in 0..<count {
                let tile = SKSpriteNode(texture: rTex)
                tile.anchorPoint = CGPoint(x: 0, y: 0)
                tile.size = CGSize(width: tileW, height: 195)
                tile.position = CGPoint(x: CGFloat(i) * tileW, y: 0)
                tile.zPosition = -10
                bgLayer.addChild(tile)
            }
        } else {
            let asphalt = SKSpriteNode(color: SKColor(red: 0.16, green: 0.17, blue: 0.19, alpha: 1), size: CGSize(width: worldWidth, height: 185))
            asphalt.anchorPoint = CGPoint(x: 0, y: 0)
            asphalt.zPosition = -10
            bgLayer.addChild(asphalt)
        }
    }

    private func buildBusAndBarricade() {
        let loader = ZWSpriteLoader.shared
        let skin = engine?.busSkinID ?? "yellow"
        let busName = loader.url(for: "\(skin)_bus_\(skin)_1", in: .bus) != nil
            ? "\(skin)_bus_\(skin)_1"
            : "yellow_bus_yellow_1"

        if let busTex = loader.skTexture(named: busName, in: .bus) {
            let bus = SKSpriteNode(texture: busTex)
            let scale: CGFloat = 2.0
            bus.size = CGSize(width: busTex.size().width * scale, height: busTex.size().height * scale)
            bus.position = CGPoint(x: 82, y: 148)
            bus.zPosition = 5
            actorLayer.addChild(bus)
            self.busNode = bus
        }

        // Driver Bill peeking from bus roof/cabin
        if let billTex = loader.skTexture(named: "h_busdriver_idle_00", in: .bus) {
            let bill = SKSpriteNode(texture: billTex)
            bill.size = CGSize(width: 44, height: 44)
            bill.position = CGPoint(x: 92, y: 205)
            bill.zPosition = 6
            actorLayer.addChild(bill)
            self.billNode = bill
        }

        // Right-side Zombie Barricade constructed from extracted Battle barricade textures
        let container = SKSpriteNode(color: .clear, size: CGSize(width: 90, height: 120))
        container.position = CGPoint(x: worldWidth - 70, y: 138)
        container.zPosition = 5

        let partNames = ["part_barricade1_01", "part_barricade2_01", "part_barricade1_03", "part_barricade21_03"]
        for (i, pName) in partNames.enumerated() {
            if let tex = loader.skTexture(named: pName, in: .battle) {
                let piece = SKSpriteNode(texture: tex)
                piece.size = CGSize(width: tex.size().width * 1.9, height: tex.size().height * 1.9)
                piece.position = CGPoint(x: CGFloat((i % 2) * 14 - 8), y: CGFloat(i * 18 - 32))
                container.addChild(piece)
            }
        }
        actorLayer.addChild(container)
        self.barricadeNode = container
    }

    private func skyColor(for location: Int) -> SKColor {
        switch location {
        case 3, 6: return SKColor(red: 0.14, green: 0.22, blue: 0.17, alpha: 1) // Toxic fog green
        case 4, 7: return SKColor(red: 0.10, green: 0.15, blue: 0.24, alpha: 1) // Night storm blue
        case 5, 9: return SKColor(red: 0.27, green: 0.16, blue: 0.11, alpha: 1) // Desert heatwave
        case 8, 10: return SKColor(red: 0.13, green: 0.10, blue: 0.24, alpha: 1) // Alien twilight purple
        default: return SKColor(red: 0.20, green: 0.26, blue: 0.34, alpha: 1)
        }
    }

    public override func update(_ currentTime: TimeInterval) {
        struct StaticTime { static var last: TimeInterval = 0 }
        let dt = StaticTime.last == 0 ? 1.0 / 60.0 : min(0.05, max(0.001, currentTime - StaticTime.last))
        StaticTime.last = currentTime

        guard let engine = engine else { return }
        engine.step(deltaTime: dt)
        syncVisuals(with: engine)
    }

    private func syncVisuals(with engine: ZWBattleEngine) {
        // Sync active actors
        let liveIDs = Set(engine.actors.map { $0.id })
        for (id, node) in actorNodes where !liveIDs.contains(id) {
            node.removeFromParent()
            actorNodes.removeValue(forKey: id)
            actorLastState.removeValue(forKey: id)
        }

        for actor in engine.actors {
            let node: SKNode
            if let existing = actorNodes[actor.id] {
                node = existing
            } else {
                node = createActorNode(for: actor)
                actorLayer.addChild(node)
                actorNodes[actor.id] = node
            }

            let px = worldToSceneX(actor.x)
            let py = 122 + CGFloat(actor.laneY) * 44
            node.position = CGPoint(x: px, y: py)
            node.zPosition = 200 - py

            if let hpFill = node.childNode(withName: "hpFill") as? SKShapeNode {
                let ratio = CGFloat(max(0, min(1, actor.hp / max(1, actor.maxHP))))
                hpFill.xScale = max(0.01, ratio)
            }
            if actorLastState[actor.id] != actor.state {
                actorLastState[actor.id] = actor.state
                if let sprite = node.childNode(withName: "sprite") as? SKSpriteNode {
                    applyAnimation(state: actor.state, sheetId: actor.configID, to: sprite)
                }
            }
            node.alpha = actor.isDead ? max(0.15, CGFloat(1.0 - actor.deathFadeTimer / 1.8)) : 1.0
        }

        // Sync support zones (Molotov / Medkit / Nitrogen)
        let zoneIDs = Set(engine.supportZones.map { $0.id })
        for (id, zNode) in zoneNodes where !zoneIDs.contains(id) {
            zNode.removeFromParent()
            zoneNodes.removeValue(forKey: id)
        }
        for zone in engine.supportZones where zoneNodes[zone.id] == nil {
            let radiusPt = CGFloat(zone.radius) * (worldWidth / 100.0)
            let oval = SKShapeNode(ellipseOf: CGSize(width: radiusPt * 2.0, height: 52))
            oval.position = CGPoint(x: worldToSceneX(zone.x), y: 120)
            oval.zPosition = 1
            if zone.itemID == "item_molotov" {
                oval.fillColor = SKColor(red: 1.0, green: 0.42, blue: 0.08, alpha: 0.35)
                oval.strokeColor = SKColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 0.85)
            } else if zone.itemID == "item_nitrogen" {
                oval.fillColor = SKColor(red: 0.3, green: 0.85, blue: 1.0, alpha: 0.35)
                oval.strokeColor = SKColor(red: 0.7, green: 0.95, blue: 1.0, alpha: 0.85)
            } else {
                oval.fillColor = SKColor(red: 0.25, green: 0.9, blue: 0.35, alpha: 0.28)
                oval.strokeColor = SKColor(red: 0.45, green: 1.0, blue: 0.5, alpha: 0.85)
            }
            fxLayer.addChild(oval)
            zoneNodes[zone.id] = oval
        }

        // Sync floating damage numbers
        let textIDs = Set(engine.floatingTexts.map { $0.id })
        for (id, lNode) in floatingNodes where !textIDs.contains(id) {
            lNode.removeFromParent()
            floatingNodes.removeValue(forKey: id)
        }
        for ft in engine.floatingTexts {
            let label: SKLabelNode
            if let existing = floatingNodes[ft.id] {
                label = existing
            } else {
                label = SKLabelNode(text: ft.text)
                label.fontName = "AvenirNext-Heavy"
                label.fontSize = ft.text.hasSuffix("!") ? 15 : 12
                label.fontColor = ZWPaletteStore.shared.entry(named: ft.paletteName).uiFillColor
                label.zPosition = 500
                fxLayer.addChild(label)
                floatingNodes[ft.id] = label
            }
            label.position = CGPoint(
                x: worldToSceneX(ft.x),
                y: 162 + CGFloat(ft.laneY) * 44 + CGFloat(ft.age) * 32
            )
            label.alpha = CGFloat(max(0, 1.0 - ft.age / 0.9))
        }

        // Barricade shake & fade when damaged
        if let bar = barricadeNode {
            let hpRatio = CGFloat(max(0, engine.barricadeHP / max(1, engine.barricadeMaxHP)))
            bar.alpha = max(0.25, 0.35 + hpRatio * 0.65)
            bar.isHidden = engine.mode == .skirmishPvP
        }
    }

    private func createActorNode(for actor: ZWLaneActor) -> SKNode {
        let root = SKNode()
        let sprite = SKSpriteNode()
        sprite.name = "sprite"
        let textures = ZWSpriteLoader.shared.frames(for: actor.configID, state: "idle")
        if let first = textures.first {
            sprite.texture = first
            let aspect = first.size().width / max(1, first.size().height)
            let h: CGFloat = actor.configID == "z_boss" || actor.configID == "z_cephalopoda" ? 96 : 64
            sprite.size = CGSize(width: h * aspect, height: h)
        } else {
            sprite.color = actor.side == .ally ? .cyan : .red
            sprite.size = CGSize(width: 42, height: 54)
        }
        // Enemies walk left facing toward player Bus
        if actor.side == .enemy {
            sprite.xScale = -1
        }
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.15)
        root.addChild(sprite)

        // Compact HP Bar above unit head
        let barW: CGFloat = 28
        let barBG = SKShapeNode(rectOf: CGSize(width: barW, height: 4), cornerRadius: 1)
        barBG.fillColor = SKColor(white: 0.05, alpha: 0.85)
        barBG.strokeColor = SKColor(white: 0.25, alpha: 0.9)
        barBG.position = CGPoint(x: 0, y: sprite.size.height * 0.85)
        root.addChild(barBG)

        let hpFill = SKShapeNode(rectOf: CGSize(width: barW - 2, height: 2.5), cornerRadius: 1)
        hpFill.name = "hpFill"
        hpFill.fillColor = actor.side == .ally ? SKColor(red: 0.25, green: 0.92, blue: 0.35, alpha: 1) : SKColor(red: 0.95, green: 0.25, blue: 0.22, alpha: 1)
        hpFill.strokeColor = .clear
        hpFill.position = CGPoint(x: 0, y: sprite.size.height * 0.85)
        root.addChild(hpFill)

        return root
    }

    private func applyAnimation(state: ZWAnimState, sheetId: String, to sprite: SKSpriteNode) {
        sprite.removeAction(forKey: "anim")
        let frames = ZWSpriteLoader.shared.frames(for: sheetId, state: state.rawValue)
        guard !frames.isEmpty else { return }
        if frames.count == 1 {
            sprite.texture = frames[0]
            return
        }
        let duration: TimeInterval = state == .attack ? 0.10 : 0.14
        let action = SKAction.animate(with: frames, timePerFrame: duration, resize: false, restore: false)
        if state == .death {
            sprite.run(action, withKey: "anim")
        } else {
            sprite.run(SKAction.repeatForever(action), withKey: "anim")
        }
    }

    private func worldToSceneX(_ worldX: Double) -> CGFloat {
        CGFloat(worldX / 100.0) * (worldWidth - 40) + 20
    }

    // Horizontal pan across the 1180pt wide battlefield inside 896pt viewport
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        lastTouchX = touch.location(in: self).x
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let prev = lastTouchX else { return }
        let cur = touch.location(in: self).x
        let delta = cur - prev
        lastTouchX = cur
        let maxPan = max(0, worldWidth - size.width)
        cameraOffsetX = min(0, max(-maxPan, cameraOffsetX + delta))
        worldLayer.position.x = cameraOffsetX
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let worldPt = touch.location(in: worldLayer)
            let worldX = Double(((worldPt.x - 20) / max(1, worldWidth - 40)) * 100.0)
            onWorldTapX?(min(92, max(12, worldX)))
        }
        lastTouchX = nil
    }
}
