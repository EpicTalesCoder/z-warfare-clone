import Foundation
import Combine

// Port of GameController (Type#902), CampaignController (Type#915), PvpController (Type#943),
// MetroController (Type#936), UnitStatsManager (Type#1115), FuryManager (Type#1495).
// Drives live 2D lane battle simulation (world x: 0 Bus ... 100 Barricade; y lane depth -1 ... +1).

public enum ZWCombatantSide: String, Codable, Sendable {
    case ally
    case enemy
}

public enum ZWAnimState: String, Codable, Sendable {
    case idle
    case move
    case attack
    case death
}

public final class ZWLaneActor: Identifiable, ObservableObject {
    public let id: UUID
    public let configID: String
    public let displayName: String
    public let side: ZWCombatantSide
    public let attackRange: Double
    public let moveSpeed: Double
    public let meleeDamage: Double
    public let rangedDamage: Double
    public let critChance: Double
    public let critMultiplier: Double
    public let resistances: ZWUnitResistances
    public let corpseID: String
    public let isTurret: Bool
    public let isGenerator: Bool

    public var x: Double           // 0...100 world units
    public var laneY: Double       // -1.0...+1.0 depth
    public var hp: Double
    public let maxHP: Double
    public var shield: Double = 0
    public var state: ZWAnimState = .move
    public var attackTimer: Double = 0
    public var generatorTimer: Double = 0
    public var burnTimer: Double = 0
    public var poisonTimer: Double = 0
    public var freezeTimer: Double = 0
    public var stunTimer: Double = 0
    public var deathFadeTimer: Double = 0
    public var isDead: Bool = false
    public var turnTimer: Double = 0
    public var lifetimeRemaining: Double? = nil

    public init(
        id: UUID = UUID(),
        configID: String,
        displayName: String,
        side: ZWCombatantSide,
        x: Double,
        laneY: Double,
        maxHP: Double,
        meleeDamage: Double,
        rangedDamage: Double,
        attackRange: Double,
        moveSpeed: Double,
        critChance: Double,
        critMultiplier: Double,
        resistances: ZWUnitResistances,
        corpseID: String = "",
        shield: Double = 0,
        isTurret: Bool = false,
        isGenerator: Bool = false,
        lifetime: Double? = nil
    ) {
        self.id = id
        self.configID = configID
        self.displayName = displayName
        self.side = side
        self.x = x
        self.laneY = laneY
        self.hp = maxHP
        self.maxHP = maxHP
        self.shield = shield
        self.meleeDamage = meleeDamage
        self.rangedDamage = rangedDamage
        self.attackRange = attackRange
        self.moveSpeed = moveSpeed
        self.critChance = critChance
        self.critMultiplier = critMultiplier
        self.resistances = resistances
        self.corpseID = corpseID
        self.isTurret = isTurret
        self.isGenerator = isGenerator
        self.lifetimeRemaining = lifetime
    }
}

public struct ZWSupportZone: Identifiable {
    public let id = UUID()
    public let itemID: String
    public let x: Double
    public let radius: Double
    public var remaining: Double
    public var tickTimer: Double = 0
    public let damagePerTick: Double
}

public struct ZWFloatingCombatText: Identifiable {
    public let id = UUID()
    public let text: String
    public let x: Double
    public let laneY: Double
    public let paletteName: String
    public var age: Double = 0
}

public struct ZWBattleCardSlot: Identifiable {
    public let id: String
    public let displayName: String
    public let currency: ZWCoinCurrency
    public let cost: Int
    public let maxPrepareTime: Double
    public var remainingPrepare: Double
    public let isSupportItem: Bool
    public let level: Int
}

public final class ZWBattleEngine: ObservableObject {
    public let mode: ZWBattleMode
    public let mission: ZWMissionConfig
    public let busSkinID: String

    @Published public private(set) var busHP: Double
    public let busMaxHP: Double
    @Published public private(set) var barricadeHP: Double
    public let barricadeMaxHP: Double

    @Published public private(set) var courage: Double = 32
    public let maxCourage: Double = 100
    @Published public private(set) var rage: Double = 18
    public let maxRage: Double = 100

    @Published public private(set) var billCooldownRemaining: Double = 0
    public let billMaxCooldown: Double = 28.0
    @Published public private(set) var billFiringRemaining: Double = 0

    @Published public private(set) var elapsedTime: Double = 0
    @Published public private(set) var finalWaveTriggered: Bool = false
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var speedMultiplier: Double = 1.0
    @Published public private(set) var outcome: ZWBattleOutcome? = nil

    @Published public private(set) var cardSlots: [ZWBattleCardSlot] = []
    @Published public private(set) var actors: [ZWLaneActor] = []
    @Published public private(set) var supportZones: [ZWSupportZone] = []
    @Published public private(set) var floatingTexts: [ZWFloatingCombatText] = []
    @Published public private(set) var activeSynergies: [ZWTeamFaction: Int] = [:]

    private var pendingWaves: [ZWWaveSpawnEntry]
    private var nextHordeSpawnTime: Double = 55.0
    private var killsByEnemy: [String: Int] = [:]
    private var spawnedByUnit: [String: Int] = [:]
    private var killsByUnit: [String: Int] = [:]
    private var damageByUnit: [String: Double] = [:]
    private var coinsFoundInBattle: Int = 0
    private var billShotAccum: Double = 0

    private let catalog: ZWGameCatalog
    private let loc: ZWLocalizationService
    private let saveData: ZWSaveData

    public init(
        mode: ZWBattleMode,
        mission: ZWMissionConfig,
        saveData: ZWSaveData,
        catalog: ZWGameCatalog = .shared,
        localization: ZWLocalizationService = .shared
    ) {
        self.mode = mode
        self.mission = mission
        self.saveData = saveData
        self.catalog = catalog
        self.loc = localization
        self.busSkinID = saveData.equippedBusSkinID

        let maxBus = ZWBattleFormulas.busMaxHP(busLevel: saveData.busLevel, armorLevel: saveData.busArmorLevel)
        self.busHP = maxBus
        self.busMaxHP = maxBus
        self.barricadeHP = mission.barricadeHP
        self.barricadeMaxHP = mission.barricadeHP
        self.pendingWaves = mission.waves.sorted { $0.timeSeconds < $1.timeSeconds }
        self.activeSynergies = ZWBattleFormulas.activeSynergyCounts(deckIDs: saveData.deckUnitIDs, catalog: catalog)

        let supportCDMult = (activeSynergies[.jailers] ?? 0) >= 2 ? 0.70 : 1.0
        let unitCDMult = (activeSynergies[.jailers] ?? 0) >= 5 ? 0.70 : 1.0

        self.cardSlots = saveData.deckUnitIDs.compactMap { id in
            let lvl = max(1, saveData.unitLevels[id] ?? 1)
            if let unit = catalog.unitsByID[id] {
                let prep = ZWBattleFormulas.prepareTime(basePrepare: unit.prepareTime, synergyMultiplier: unitCDMult)
                return ZWBattleCardSlot(
                    id: id,
                    displayName: localization.text(unit.locNameKey, fallback: unit.id),
                    currency: unit.currency,
                    cost: unit.cost,
                    maxPrepareTime: prep,
                    remainingPrepare: min(2.0, prep * 0.2),
                    isSupportItem: false,
                    level: lvl
                )
            } else if let item = catalog.itemsByID[id] {
                let prep = ZWBattleFormulas.prepareTime(basePrepare: item.prepareTime, synergyMultiplier: supportCDMult)
                return ZWBattleCardSlot(
                    id: id,
                    displayName: localization.text(item.locNameKey, fallback: item.id),
                    currency: .rage,
                    cost: item.cost,
                    maxPrepareTime: prep,
                    remainingPrepare: 1.0,
                    isSupportItem: true,
                    level: lvl
                )
            }
            return nil
        }

        if mode == .skirmishPvP {
            self.courage = 100
            self.pendingWaves = []
            spawnSkirmishOpponentTeam()
        }
    }

    private func spawnSkirmishOpponentTeam() {
        let opponentIDs = ["h_cop", "h_sniper", "h_grenader", "h_builder", "h_mechanic", "h_shocker"]
        for (idx, id) in opponentIDs.enumerated() {
            if let def = catalog.unitsByID[id] {
                let lvl = max(4, saveData.playerRank + 2)
                let hp = ZWBattleFormulas.upgradedStat(base: def.baseHP, level: lvl)
                let melee = ZWBattleFormulas.upgradedStat(base: def.baseMeleeDamage, level: lvl)
                let ranged = ZWBattleFormulas.upgradedStat(base: def.baseRangedDamage, level: lvl)
                let actor = ZWLaneActor(
                    configID: def.id,
                    displayName: loc.text(def.locNameKey, fallback: def.id),
                    side: .enemy,
                    x: 80 + Double(idx) * 2.5,
                    laneY: Double.random(in: -0.75...0.75),
                    maxHP: hp,
                    meleeDamage: melee,
                    rangedDamage: ranged,
                    attackRange: def.attackRange * 0.45,
                    moveSpeed: def.moveSpeed * 0.25,
                    critChance: def.critChance,
                    critMultiplier: def.critDamage,
                    resistances: def.resistances,
                    corpseID: ""
                )
                actors.append(actor)
            }
        }
    }

    public func togglePause() {
        isPaused.toggle()
    }

    public func toggleSpeed() {
        speedMultiplier = speedMultiplier < 1.5 ? 2.0 : 1.0
    }

    // Port of Driver Bill Machine Gun skill (`b_bill`) triggered by Rage
    @discardableResult
    public func activateBillBarrage() -> Bool {
        guard outcome == nil, !isPaused, billCooldownRemaining <= 0 else { return false }
        billCooldownRemaining = billMaxCooldown
        billFiringRemaining = 3.5
        ZWSoundEngine.shared.playExplosionHaptic()
        return true
    }

    @discardableResult
    public func deployCard(slotIndex: Int, targetWorldX: Double? = nil) -> Bool {
        guard outcome == nil, !isPaused, cardSlots.indices.contains(slotIndex) else { return false }
        let slot = cardSlots[slotIndex]
        guard slot.remainingPrepare <= 0.01 else { return false }

        switch slot.currency {
        case .courage:
            guard courage >= Double(slot.cost) else { return false }
            courage -= Double(slot.cost)
        case .rage:
            guard rage >= Double(slot.cost) else { return false }
            rage -= Double(slot.cost)
        }

        cardSlots[slotIndex].remainingPrepare = slot.maxPrepareTime
        ZWSoundEngine.shared.playDeployHaptic()

        if slot.isSupportItem, let item = catalog.itemsByID[slot.id] {
            deploySupportItem(item, level: slot.level, targetWorldX: targetWorldX ?? 54.0)
            return true
        }

        guard let def = catalog.unitsByID[slot.id] else { return false }
        spawnAllyUnit(def, level: slot.level, atX: 12.0)

        // Two-unit spawn for Agents
        if def.id == "h_agent" {
            spawnAllyUnit(def, level: slot.level, atX: 10.0)
        }

        // Mechanics 2/2 synergy repairs Bus by 5% on deploy
        if def.faction == .mechanics && (activeSynergies[.mechanics] ?? 0) >= 2 {
            busHP = min(busMaxHP, busHP + busMaxHP * 0.05)
            floatingTexts.append(ZWFloatingCombatText(text: "+BUS HP", x: 10, laneY: 0.2, paletteName: "GreenSolid"))
        }
        // Mechanics 3/3 synergy 25% (100% Welder) chance for free Turret
        if def.faction == .mechanics && (activeSynergies[.mechanics] ?? 0) >= 3 {
            let chance = def.id == "h_welder" ? 1.0 : 0.25
            if Double.random(in: 0...1) <= chance, let turret = catalog.itemsByID["item_turret"] {
                deploySupportItem(turret, level: slot.level, targetWorldX: 28.0)
            }
        }
        return true
    }

    private func spawnAllyUnit(_ def: ZWUnitDefinition, level: Int, atX: Double) {
        let gearSlots = saveData.equippedGear[def.id]?.values
        let flatHP = gearSlots?.reduce(0) { $0 + $1.flatHP } ?? 0
        let flatDmg = gearSlots?.reduce(0) { $0 + $1.flatDamage } ?? 0
        let critGear = gearSlots?.reduce(0) { $0 + $1.percentCritChance } ?? 0

        let charm = saveData.equippedCharms[def.id].flatMap { cid in catalog.charms.first { $0.id == cid } }
        let hpPct = charm?.hpPercentBonus ?? 0
        let dmgPct = charm?.damagePercentBonus ?? 0

        let hp = ZWBattleFormulas.upgradedStat(base: def.baseHP, level: level, flatGearBonus: flatHP, percentBonus: hpPct)
        let melee = ZWBattleFormulas.upgradedStat(base: def.baseMeleeDamage, level: level, flatGearBonus: flatDmg, percentBonus: dmgPct)
        let ranged = def.baseRangedDamage > 0 ? ZWBattleFormulas.upgradedStat(base: def.baseRangedDamage, level: level, flatGearBonus: flatDmg, percentBonus: dmgPct) : 0
        let shield = (def.faction == .police && (activeSynergies[.police] ?? 0) >= 3) ? hp : 0

        let actor = ZWLaneActor(
            configID: def.id,
            displayName: loc.text(def.locNameKey, fallback: def.id),
            side: .ally,
            x: atX,
            laneY: Double.random(in: -0.75...0.75),
            maxHP: hp,
            meleeDamage: melee,
            rangedDamage: ranged,
            attackRange: def.attackRange * 0.42,
            moveSpeed: def.moveSpeed * 0.26,
            critChance: min(0.95, def.critChance + critGear),
            critMultiplier: def.critDamage,
            resistances: def.resistances,
            corpseID: def.zombieCorpseID,
            shield: shield
        )
        actors.append(actor)
        spawnedByUnit[def.id, default: 0] += 1
    }

    private func deploySupportItem(_ item: ZWSupportItemDefinition, level: Int, targetWorldX: Double) {
        let clampedX = min(88, max(16, targetWorldX))
        let dmg = ZWBattleFormulas.upgradedStat(base: item.baseDamage, level: level)
        switch item.id {
        case "item_grenade":
            applyExplosionDamage(centerX: clampedX, radius: item.radius * 0.35, damage: dmg, freezeSeconds: 0, burnSeconds: 0)
        case "item_red_barrel", "item_barrel":
            let barrel = ZWLaneActor(
                configID: item.id,
                displayName: loc.text(item.locNameKey, fallback: item.id),
                side: .ally,
                x: clampedX,
                laneY: Double.random(in: -0.35...0.35),
                maxHP: item.id == "item_barrel" ? 260 : 110,
                meleeDamage: dmg,
                rangedDamage: 0,
                attackRange: 6,
                moveSpeed: 0,
                critChance: 0,
                critMultiplier: 0,
                resistances: .none,
                lifetime: item.duration
            )
            actors.append(barrel)
            applyExplosionDamage(centerX: clampedX, radius: 14, damage: item.id == "item_red_barrel" ? dmg * 0.55 : dmg * 0.35, freezeSeconds: 0, burnSeconds: 0)
        case "item_turret":
            let turret = ZWLaneActor(
                configID: "item_turret",
                displayName: loc.text(item.locNameKey, fallback: "Turret"),
                side: .ally,
                x: min(72, max(20, clampedX)),
                laneY: 0.0,
                maxHP: 140 + Double(level) * 14,
                meleeDamage: 0,
                rangedDamage: dmg,
                attackRange: 62,
                moveSpeed: 0,
                critChance: 0.08,
                critMultiplier: 0.5,
                resistances: .none,
                isTurret: true,
                lifetime: item.duration
            )
            actors.append(turret)
        case "item_generator":
            let gen = ZWLaneActor(
                configID: "item_generator",
                displayName: loc.text(item.locNameKey, fallback: "Generator"),
                side: .ally,
                x: min(40, max(16, clampedX)),
                laneY: -0.45,
                maxHP: 130 + Double(level) * 12,
                meleeDamage: 0,
                rangedDamage: 0,
                attackRange: 0,
                moveSpeed: 0,
                critChance: 0,
                critMultiplier: 0,
                resistances: .none,
                isGenerator: true,
                lifetime: item.duration
            )
            actors.append(gen)
        case "item_molotov":
            applyExplosionDamage(centerX: clampedX, radius: item.radius * 0.35, damage: dmg * 0.45, freezeSeconds: 0, burnSeconds: 5.5)
            supportZones.append(ZWSupportZone(itemID: item.id, x: clampedX, radius: 14, remaining: item.duration, damagePerTick: dmg * 0.25))
        case "item_nitrogen":
            applyExplosionDamage(centerX: clampedX, radius: item.radius * 0.4, damage: dmg, freezeSeconds: 5.0, burnSeconds: 0)
            supportZones.append(ZWSupportZone(itemID: item.id, x: clampedX, radius: 16, remaining: item.duration, damagePerTick: 6))
        case "item_medkit":
            supportZones.append(ZWSupportZone(itemID: item.id, x: clampedX, radius: 16, remaining: item.duration, damagePerTick: 28 + Double(level) * 4))
        case "item_drone":
            applyExplosionDamage(centerX: clampedX, radius: 20, damage: dmg, freezeSeconds: 0, burnSeconds: 0)
        default:
            break
        }
    }

    // Main simulation step called at 60Hz by SpriteKit scene (with fixed/clamped dt)
    public func step(deltaTime rawDt: Double) {
        guard outcome == nil, !isPaused else { return }
        let dt = min(0.05, max(0.001, rawDt)) * speedMultiplier
        elapsedTime += dt

        // 1. Courage regen
        let regen = ZWBattleFormulas.courageRegenPerSecond(busLevel: saveData.busLevel)
        courage = min(maxCourage, courage + regen * dt)

        // 2. Card cooldowns
        for idx in cardSlots.indices {
            if cardSlots[idx].remainingPrepare > 0 {
                cardSlots[idx].remainingPrepare = max(0, cardSlots[idx].remainingPrepare - dt)
            }
        }
        if billCooldownRemaining > 0 {
            billCooldownRemaining = max(0, billCooldownRemaining - dt)
        }

        // 3. Driver Bill Machine Gun active barrage
        if billFiringRemaining > 0 {
            billFiringRemaining = max(0, billFiringRemaining - dt)
            billShotAccum += dt
            if billShotAccum >= 0.14 {
                billShotAccum = 0
                fireBillBullet()
            }
        }

        // 4. Wave Spawns + Final Wave Horde at 75s
        while let next = pendingWaves.first, elapsedTime >= next.timeSeconds {
            pendingWaves.removeFirst()
            spawnEnemyWave(next)
        }
        if mode == .campaign && elapsedTime >= 75.0 {
            if !finalWaveTriggered {
                finalWaveTriggered = true
                ZWSoundEngine.shared.playMusic(.finalWave)
            }
            if elapsedTime >= nextHordeSpawnTime {
                nextHordeSpawnTime = elapsedTime + 11.0
                spawnEnemyWave(ZWWaveSpawnEntry(timeSeconds: elapsedTime, enemyID: "z_witch", count: 3, level: max(2, mission.location + 2)))
            }
        }

        // 5. Support zones (Medkit / Molotov / Nitrogen)
        stepSupportZones(dt: dt)

        // 6. Combat actors AI & attacks
        stepActors(dt: dt)

        // 7. Decay floating texts
        floatingTexts = floatingTexts.compactMap { txt in
            var copy = txt
            copy.age += dt
            return copy.age < 0.9 ? copy : nil
        }

        // 8. Check win/loss
        checkOutcome()
    }

    private func fireBillBullet() {
        let enemies = actors.filter { $0.side == .enemy && !$0.isDead }
        guard let target = enemies.min(by: { $0.x < $1.x }) else { return }
        let dmg = ZWBattleFormulas.computeDamage(
            rawDamage: 14.0 + Double(saveData.busLevel) * 2.5,
            damageType: .ranged,
            attackerLevel: saveData.busLevel,
            isCrit: false,
            critMultiplier: 0.5,
            defenderResistances: target.resistances
        )
        applyDamage(dmg, to: target, isCrit: false, attackerUnitID: nil)
    }

    private func spawnEnemyWave(_ wave: ZWWaveSpawnEntry) {
        guard let def = catalog.enemiesByID[wave.enemyID] else { return }
        for _ in 0..<wave.count {
            let hp = ZWBattleFormulas.upgradedStat(base: def.baseHP, level: wave.level)
            let dmg = ZWBattleFormulas.upgradedStat(base: def.damage, level: wave.level)
            let enemy = ZWLaneActor(
                configID: def.id,
                displayName: loc.text(def.locNameKey, fallback: def.id),
                side: .enemy,
                x: Double.random(in: 89...94),
                laneY: Double.random(in: -0.78...0.78),
                maxHP: hp,
                meleeDamage: def.attackRange <= 25 ? dmg : 0,
                rangedDamage: def.attackRange > 25 ? dmg : 0,
                attackRange: def.attackRange * 0.42,
                moveSpeed: def.moveSpeed * 0.25,
                critChance: 0.08,
                critMultiplier: 0.5,
                resistances: def.resistances
            )
            actors.append(enemy)
        }
    }

    private func stepSupportZones(dt: Double) {
        var nextZones: [ZWSupportZone] = []
        for var zone in supportZones {
            zone.remaining -= dt
            zone.tickTimer += dt
            if zone.tickTimer >= 0.8 {
                zone.tickTimer = 0
                if zone.itemID == "item_medkit" {
                    for ally in actors where ally.side == .ally && !ally.isDead && abs(ally.x - zone.x) <= zone.radius {
                        ally.hp = min(ally.maxHP, ally.hp + zone.damagePerTick)
                        ally.poisonTimer = 0
                    }
                } else if zone.itemID == "item_molotov" {
                    for enemy in actors where enemy.side == .enemy && !enemy.isDead && abs(enemy.x - zone.x) <= zone.radius {
                        let dmg = ZWBattleFormulas.computeDamage(rawDamage: zone.damagePerTick, damageType: .fire, attackerLevel: 1, isCrit: false, critMultiplier: 0, defenderResistances: enemy.resistances)
                        applyDamage(dmg, to: enemy, isCrit: false, attackerUnitID: nil)
                    }
                }
            }
            if zone.remaining > 0 {
                nextZones.append(zone)
            }
        }
        supportZones = nextZones
    }

    private func stepActors(dt: Double) {
        var zombiesToSpawn: [ZWLaneActor] = []

        for actor in actors {
            if actor.isDead {
                actor.deathFadeTimer += dt
                if actor.side == .ally && !actor.corpseID.isEmpty && actor.turnTimer > 0 {
                    actor.turnTimer -= dt
                    if actor.turnTimer <= 0, let zDef = catalog.enemiesByID[actor.corpseID] {
                        let zActor = ZWLaneActor(
                            configID: zDef.id,
                            displayName: loc.text(zDef.locNameKey, fallback: zDef.id),
                            side: .enemy,
                            x: actor.x,
                            laneY: actor.laneY,
                            maxHP: zDef.baseHP,
                            meleeDamage: zDef.damage,
                            rangedDamage: 0,
                            attackRange: zDef.attackRange * 0.42,
                            moveSpeed: zDef.moveSpeed * 0.25,
                            critChance: 0.05,
                            critMultiplier: 0.5,
                            resistances: zDef.resistances
                        )
                        zombiesToSpawn.append(zActor)
                        actor.deathFadeTimer = 99
                    }
                }
                continue
            }

            if let life = actor.lifetimeRemaining {
                let nextLife = life - dt
                actor.lifetimeRemaining = nextLife
                if nextLife <= 0 {
                    actor.isDead = true
                    actor.state = .death
                    continue
                }
            }

            // DoTs & Generator
            if actor.isGenerator {
                actor.generatorTimer += dt
                if actor.generatorTimer >= 6.0 {
                    actor.generatorTimer = 0
                    courage = min(maxCourage, courage + 15)
                    floatingTexts.append(ZWFloatingCombatText(text: "+15 COURAGE", x: actor.x, laneY: actor.laneY, paletteName: "WaterColor"))
                }
                actor.state = .idle
                continue
            }

            if actor.burnTimer > 0 {
                actor.burnTimer -= dt
                actor.hp -= 12 * dt
            }
            if actor.stunTimer > 0 {
                actor.stunTimer -= dt
                actor.state = .idle
                continue
            }
            let speedScale = actor.freezeTimer > 0 ? 0.35 : 1.0
            if actor.freezeTimer > 0 {
                actor.freezeTimer = max(0, actor.freezeTimer - dt)
            }

            if actor.hp <= 0 {
                markDead(actor)
                continue
            }

            // Target selection
            let opponents = actors.filter { $0.side != actor.side && !$0.isDead }
            let target: ZWLaneActor? = {
                if actor.side == .ally {
                    return opponents.filter { $0.x >= actor.x - 4 }.min(by: { $0.x < $1.x })
                } else {
                    return opponents.filter { $0.x <= actor.x + 4 }.max(by: { $0.x < $1.x })
                }
            }()

            if let target = target {
                let dist = abs(target.x - actor.x)
                if dist <= max(5.5, actor.attackRange) {
                    actor.state = .attack
                    actor.attackTimer += dt
                    let interval = actor.isTurret ? 0.22 : (actor.rangedDamage > 0 ? 0.85 : 0.95)
                    if actor.attackTimer >= interval {
                        actor.attackTimer = 0
                        performAttack(attacker: actor, target: target)
                    }
                    continue
                }
            }

            // Barricade / Bus check
            if actor.side == .ally && !actor.isTurret && actor.x >= 92 - min(18, actor.attackRange) && barricadeHP > 0 {
                actor.state = .attack
                actor.attackTimer += dt
                if actor.attackTimer >= 0.95 {
                    actor.attackTimer = 0
                    let base = actor.rangedDamage > 0 ? actor.rangedDamage : actor.meleeDamage
                    let dmg = max(1, base.rounded())
                    barricadeHP = max(0, barricadeHP - dmg)
                    damageByUnit[actor.configID, default: 0] += dmg
                    floatingTexts.append(ZWFloatingCombatText(text: "-\(Int(dmg))", x: 94, laneY: actor.laneY, paletteName: "GoldSolid"))
                }
                continue
            }

            if actor.side == .enemy && actor.x <= 9.5 + min(10, actor.attackRange * 0.4) {
                actor.state = .attack
                actor.attackTimer += dt
                if actor.attackTimer >= 1.05 {
                    actor.attackTimer = 0
                    let dmg = max(1, actor.meleeDamage + actor.rangedDamage)
                    busHP = max(0, busHP - dmg)
                    floatingTexts.append(ZWFloatingCombatText(text: "-\(Int(dmg))", x: 9, laneY: actor.laneY, paletteName: "RedWithOutline"))
                }
                continue
            }

            // Advance along lane
            if actor.moveSpeed > 0 {
                actor.state = .move
                let dir: Double = actor.side == .ally ? 1.0 : -1.0
                actor.x = min(94, max(7, actor.x + dir * actor.moveSpeed * speedScale * dt))
            } else {
                actor.state = .idle
            }
        }

        actors.append(contentsOf: zombiesToSpawn)
        actors.removeAll { $0.isDead && $0.deathFadeTimer > 1.8 }
    }

    private func performAttack(attacker: ZWLaneActor, target: ZWLaneActor) {
        let isCrit = Double.random(in: 0...1) < attacker.critChance
        let dtype: ZWDamageType = attacker.rangedDamage > 0 ? .ranged : .melee
        let baseDmg = attacker.rangedDamage > 0 ? attacker.rangedDamage : attacker.meleeDamage
        let finalDmg = ZWBattleFormulas.computeDamage(
            rawDamage: baseDmg,
            damageType: dtype,
            attackerLevel: 1,
            isCrit: isCrit,
            critMultiplier: attacker.critMultiplier,
            defenderResistances: target.resistances
        )
        applyDamage(finalDmg, to: target, isCrit: isCrit, attackerUnitID: attacker.side == .ally ? attacker.configID : nil)
        if attacker.configID == "h_jailer" && isCrit {
            target.stunTimer = 1.4
        }
        if attacker.configID == "h_freeze" || target.configID == "h_freeze" {
            target.freezeTimer = 2.0
        }
    }

    private func applyDamage(_ amount: Double, to target: ZWLaneActor, isCrit: Bool, attackerUnitID: String?) {
        var remaining = amount
        if target.shield > 0 {
            let absorbed = min(target.shield, remaining)
            target.shield -= absorbed
            remaining -= absorbed
        }
        target.hp -= remaining
        if let uid = attackerUnitID {
            damageByUnit[uid, default: 0] += amount
        }
        floatingTexts.append(
            ZWFloatingCombatText(
                text: isCrit ? "\(Int(amount))!" : "\(Int(amount))",
                x: target.x,
                laneY: target.laneY,
                paletteName: target.side == .enemy ? (isCrit ? "GoldSolid" : "WhiteSolid") : "WarningMessage"
            )
        )
        if target.hp <= 0 && !target.isDead {
            markDead(target, killerUnitID: attackerUnitID)
        }
    }

    private func applyExplosionDamage(centerX: Double, radius: Double, damage: Double, freezeSeconds: Double, burnSeconds: Double) {
        ZWSoundEngine.shared.playExplosionHaptic()
        for enemy in actors where enemy.side == .enemy && !enemy.isDead && abs(enemy.x - centerX) <= radius {
            let dealt = ZWBattleFormulas.computeDamage(
                rawDamage: damage,
                damageType: .explosion,
                attackerLevel: 1,
                isCrit: false,
                critMultiplier: 0,
                defenderResistances: enemy.resistances
            )
            if freezeSeconds > 0 { enemy.freezeTimer = max(enemy.freezeTimer, freezeSeconds) }
            if burnSeconds > 0 && !enemy.resistances.fireImmune { enemy.burnTimer = max(enemy.burnTimer, burnSeconds) }
            applyDamage(dealt, to: enemy, isCrit: false, attackerUnitID: nil)
        }
    }

    private func markDead(_ actor: ZWLaneActor, killerUnitID: String? = nil) {
        actor.isDead = true
        actor.state = .death
        actor.deathFadeTimer = 0
        if actor.side == .enemy {
            killsByEnemy[actor.configID, default: 0] += 1
            if let uid = killerUnitID {
                killsByUnit[uid, default: 0] += 1
                if uid == "h_austin" { coinsFoundInBattle += 12 }
            }
            rage = min(maxRage, rage + (actor.configID == "z_freehugs" ? 25 : 4))
            // Boomer explosion on death
            if actor.configID == "z_boomer" || actor.configID == "z_chineseExpl" {
                for ally in actors where ally.side == .ally && !ally.isDead && abs(ally.x - actor.x) <= 12 {
                    applyDamage(48, to: ally, isCrit: false, attackerUnitID: nil)
                }
            }
        } else {
            // College 2/2 synergy prevents zombie turning
            let preventTurn = (activeSynergies[.college] ?? 0) >= 2
            if !preventTurn && !actor.corpseID.isEmpty {
                actor.turnTimer = 2.2
            }
        }
    }

    private func checkOutcome() {
        let won: Bool
        if mode == .skirmishPvP {
            let aliveEnemies = actors.filter { $0.side == .enemy && !$0.isDead }
            let aliveAllies = actors.filter { $0.side == .ally && !$0.isDead }
            if aliveEnemies.isEmpty && elapsedTime > 2.0 {
                won = true
            } else if aliveAllies.isEmpty && courage < 10 && elapsedTime > 3.0 {
                won = false
            } else {
                return
            }
        } else {
            if barricadeHP <= 0 {
                won = true
            } else if busHP <= 0 {
                won = false
            } else {
                return
            }
        }

        let stars = won ? ZWBattleFormulas.starRating(busHP: busHP, busMaxHP: busMaxHP) : 0
        let telemetry = cardSlots.filter { !$0.isSupportItem }.map { slot in
            ZWBattleUnitTelemetry(
                id: slot.id,
                displayName: slot.displayName,
                spawnedCount: spawnedByUnit[slot.id] ?? 0,
                kills: killsByUnit[slot.id] ?? 0,
                totalDamageDealt: damageByUnit[slot.id] ?? 0
            )
        }

        let result = ZWBattleOutcome(
            mode: mode,
            missionID: mission.id,
            victory: won,
            stars: stars,
            durationSeconds: elapsedTime,
            coinsEarned: won ? (mission.coinReward + coinsFoundInBattle) : max(10, coinsFoundInBattle),
            cashEarned: (won && mission.isBossMission) ? 15 : 0,
            powerPointsEarned: won ? mission.powerPointReward : 5,
            xpEarned: won ? mission.xpReward : 8,
            killCountsByEnemy: killsByEnemy,
            unitTelemetry: telemetry
        )
        ZWSoundEngine.shared.playVictoryHaptic(won: won)
        outcome = result
    }
}
