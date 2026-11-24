import Foundation

// Evidence: Data/missions_locations.json, Data/localization.json, Data/packs_decoded.csv,
// GameSprites/UnitSheets/unit_sheets_manifest.json, GameSprites/Bus/*.png
// Port of WebConfigParams (Type#5555) offline database owner backed by extracted .ipa assets.
public final class ZWGameCatalog: @unchecked Sendable {
    public static let shared = ZWGameCatalog()

    public private(set) var missionsByLocation: [Int: [ZWMissionConfig]] = [:]
    public private(set) var allMissions: [ZWMissionConfig] = []
    public private(set) var encryptedPackHashes: [(uuid: String, rank: Int)] = []

    public let units: [ZWUnitDefinition]
    public let supportItems: [ZWSupportItemDefinition]
    public let enemies: [ZWEnemyDefinition]
    public let synergies: [ZWTeamSynergyDefinition]
    public let busSkins: [ZWBusSkinDefinition]
    public let charms: [ZWCharmDefinition]
    public let metroStations: [ZWMetroStation]

    public let unitsByID: [String: ZWUnitDefinition]
    public let itemsByID: [String: ZWSupportItemDefinition]
    public let enemiesByID: [String: ZWEnemyDefinition]
    public let busSkinsByID: [String: ZWBusSkinDefinition]

    private init() {
        let builtUnits = Self.buildUnits()
        let builtItems = Self.buildSupportItems()
        let builtEnemies = Self.buildEnemies()
        let builtSkins = Self.buildBusSkins()

        self.units = builtUnits
        self.supportItems = builtItems
        self.enemies = builtEnemies
        self.busSkins = builtSkins
        self.synergies = Self.buildSynergies()
        self.charms = Self.buildCharms()

        var uMap: [String: ZWUnitDefinition] = [:]
        for u in builtUnits { uMap[u.id] = u }
        self.unitsByID = uMap

        var iMap: [String: ZWSupportItemDefinition] = [:]
        for i in builtItems { iMap[i.id] = i }
        self.itemsByID = iMap

        var eMap: [String: ZWEnemyDefinition] = [:]
        for e in builtEnemies { eMap[e.id] = e }
        self.enemiesByID = eMap

        var sMap: [String: ZWBusSkinDefinition] = [:]
        for s in builtSkins { sMap[s.id] = s }
        self.busSkinsByID = sMap

        self.metroStations = Self.buildMetroStations()
        loadMissionsFromBundle()
        loadPackRegistry()
    }

    public func mission(id: Int) -> ZWMissionConfig? {
        allMissions.first { $0.id == id }
    }

    public func isSupportItem(_ id: String) -> Bool {
        itemsByID[id] != nil
    }

    // Evidence: Data/missions_locations.json (Locations 1..10)
    public func loadMissionsFromBundle(bundle: Bundle = .main) {
        let urls: [URL?] = [
            bundle.url(forResource: "missions_locations", withExtension: "json", subdirectory: "Data"),
            bundle.url(forResource: "missions_locations", withExtension: "json")
        ]
        for case let url? in urls {
            if let data = try? Data(contentsOf: url),
               let raw = try? JSONDecoder().decode([String: [ZWMissionCoordinate]].self, from: data) {
                var byLoc: [Int: [ZWMissionConfig]] = [:]
                var flat: [ZWMissionConfig] = []

                for (locKey, coords) in raw {
                    guard let locNum = Int(locKey) else { continue }
                    let sortedCoords = coords.sorted { $0.id < $1.id }
                    var built: [ZWMissionConfig] = []
                    for (idx, coord) in sortedCoords.enumerated() {
                        let config = Self.buildMissionConfig(coord: coord, stageIndex: idx, totalInLoc: sortedCoords.count)
                        built.append(config)
                        flat.append(config)
                    }
                    byLoc[locNum] = built
                }
                self.missionsByLocation = byLoc
                self.allMissions = flat.sorted { $0.id < $1.id }
                return
            }
        }
    }

    private func loadPackRegistry(bundle: Bundle = .main) {
        let urls: [URL?] = [
            bundle.url(forResource: "packs_decoded", withExtension: "csv", subdirectory: "Data"),
            bundle.url(forResource: "packs_decoded", withExtension: "csv")
        ]
        for case let url? in urls {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                self.encryptedPackHashes = text
                    .split(whereSeparator: \.isNewline)
                    .compactMap { line in
                        let parts = line.split(separator: ",")
                        guard parts.count == 2, let rank = Int(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
                        return (String(parts[0]), rank)
                    }
                return
            }
        }
    }

    private static func buildMissionConfig(coord: ZWMissionCoordinate, stageIndex: Int, totalInLoc: Int) -> ZWMissionConfig {
        let loc = coord.location
        let progress = Double(stageIndex) / Double(max(1, totalInLoc - 1))
        let diff = min(5, max(0, (loc - 1) / 2 + (progress > 0.72 ? 1 : 0)))
        let isBoss = (stageIndex == totalInLoc - 1) && (loc == 2 || loc == 4 || loc == 6 || loc == 8 || loc == 10)
        let isSupply = (stageIndex % 7 == 5) && loc >= 2
        let fuel = isSupply ? 3 : (coord.id == 1 ? 0 : 2)

        let barricadeHP = Double(120 + loc * 110 + stageIndex * 22 + (isBoss ? 800 : 0))
        let baseCoin = 35 + loc * 18 + stageIndex * 4
        let pp = isSupply ? (45 + loc * 15) : (8 + loc * 4)

        var hazard: String? = nil
        if loc == 3 || loc == 6 { hazard = "Toxic Fog" }
        else if loc == 4 || loc == 7 { hazard = "Rain" }
        else if loc == 5 || loc == 9 { hazard = "Heatwave" }

        let pool = enemyPool(forLocation: loc)
        var waves: [ZWWaveSpawnEntry] = []
        let lvl = max(1, loc * 2 + Int(progress * 4))

        waves.append(ZWWaveSpawnEntry(timeSeconds: 1.5, enemyID: pool[0], count: 2 + (loc > 3 ? 1 : 0), level: lvl))
        waves.append(ZWWaveSpawnEntry(timeSeconds: 7.5, enemyID: pool[min(1, pool.count - 1)], count: 2 + (loc > 5 ? 1 : 0), level: lvl))
        waves.append(ZWWaveSpawnEntry(timeSeconds: 14.0, enemyID: pool[min(2, pool.count - 1)], count: 2, level: lvl))
        if pool.count > 3 {
            waves.append(ZWWaveSpawnEntry(timeSeconds: 22.0, enemyID: pool[3], count: 2 + (stageIndex % 2), level: lvl + 1))
        }
        let bossEnemy = isBoss ? (loc == 8 ? "z_cephalopoda" : "z_boss") : pool.last!
        waves.append(ZWWaveSpawnEntry(timeSeconds: 32.0, enemyID: bossEnemy, count: isBoss ? 1 : (3 + loc / 3), level: lvl + 1))

        return ZWMissionConfig(
            id: coord.id,
            location: loc,
            mapX: coord.x,
            mapY: coord.y,
            stageNumber: stageIndex + 1,
            difficultyIndex: diff,
            fuelCost: fuel,
            barricadeHP: barricadeHP,
            coinReward: baseCoin,
            xpReward: 20 + loc * 10,
            powerPointReward: pp,
            weatherHazard: hazard,
            isBossMission: isBoss,
            isSupplyRun: isSupply,
            waves: waves
        )
    }

    private static func enemyPool(forLocation loc: Int) -> [String] {
        switch loc {
        case 1: return ["z_naked", "z_nakedRun", "z_girl", "z_builder"]
        case 2: return ["z_nakedRun", "z_builder", "z_boomer", "z_skeleton"]
        case 3: return ["b_crazy", "b_naked", "b_builder", "b_farmer"]
        case 4: return ["z_cop", "z_firefighter", "z_boomer", "z_witch"]
        case 5: return ["z_hunter", "z_bulletproof", "z_soldier", "z_demon"]
        case 6: return ["z_yellow", "z_yellowFat", "z_putrid", "z_necromancer"]
        case 7: return ["z_alienNaked", "z_alienNakedRun", "z_alienBuilder", "z_sphere"]
        case 8: return ["z_alienCop", "z_alienBoomer", "z_insect", "z_twins"]
        case 9: return ["z_alienTwins", "z_girlPrisoner", "z_crank", "z_swat"]
        default: return ["z_alienTwins", "z_girlPrisoner", "z_hypnotist", "z_abby"]
        }
    }

    // Evidence: All 53 verified playable unit IDs from localization.json (`unit.h_*`) & GameSprites/Portraits + UnitSheets
    private static func buildUnits() -> [ZWUnitDefinition] {
        return [
            unit("h_naked", .fighter, .rednecks, .courage, cost: 15, prep: 3.0, hp: 36, melee: 13, ranged: 0, range: 14, speed: 62, critC: 0.12, critD: 0.5, unlockCoins: 0, unlockCash: 0, rank: 1, res: .none, perk: "Fast preparation cheap spammer", sp: "Crit hits knock enemies back", corpse: "z_naked", skins: ["h_naked_skin1", "h_naked_skin2", "h_naked_skin3"]),
            unit("h_mechanic", .fighter, .mechanics, .courage, cost: 15, prep: 10.0, hp: 40, melee: 14, ranged: 0, range: 15, speed: 68, critC: 0.15, critD: 1.0, unlockCoins: 100, unlockCash: 0, rank: 1, res: .none, perk: "First hit uses Sledgehammer (3x Crit)", sp: "Sledgehammer chains on kills", corpse: "z_builder", skins: ["h_mechanic_skin1", "h_mechanic_skin2", "h_mechanic_skin3"]),
            unit("h_farmer", .shotgunner, .rednecks, .courage, cost: 20, prep: 18.0, hp: 52, melee: 8, ranged: 19, range: 115, speed: 46, critC: 0.12, critD: 0.5, unlockCoins: 0, unlockCash: 0, rank: 1, res: .none, perk: "Double-barrel shotgun blast", sp: "Critical pellets pierce targets", corpse: "z_farmer", skins: ["h_farmer_skin1", "h_farmer_skin2", "h_farmer_skin3"]),
            unit("h_judi", .support, .police, .courage, cost: 25, prep: 18.0, hp: 55, melee: 10, ranged: 12, range: 130, speed: 50, critC: 0.10, critD: 0.5, unlockCoins: 0, unlockCash: 0, rank: 2, res: .none, perk: "Inspires nearby allies (+Agility)", sp: "Drops buff aura on deploy", corpse: "z_girl", skins: ["h_judi_skin1", "h_judi_skin2", "h_judi_skin3"]),
            unit("h_builder", .damager, .builders, .courage, cost: 25, prep: 14.0, hp: 92, melee: 22, ranged: 0, range: 15, speed: 48, critC: 0.12, critD: 0.6, unlockCoins: 250, unlockCash: 0, rank: 2, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: false, poisonImmune: false, explosionResist: 0, knockbackResist: 0.3), perk: "Bulletproof helmet (90% bullet resist)", sp: "Deals 2x damage to barricades", corpse: "z_builder", skins: ["h_builder_skin1", "h_builder_skin2", "h_builder_skin3"]),
            unit("h_cop", .shotgunner, .police, .courage, cost: 30, prep: 24.0, hp: 140, melee: 16, ranged: 24, range: 110, speed: 40, critC: 0.10, critD: 0.5, unlockCoins: 600, unlockCash: 0, rank: 3, res: ZWUnitResistances(bulletResist: 0, meleeResist: 0.5, fireImmune: false, poisonImmune: false, explosionResist: 0, knockbackResist: 0.5), perk: "Melee resistance (50% reduction)", sp: "Never stops firing at close range", corpse: "z_cop", skins: ["h_cop_skin1", "h_cop_skin2", "h_cop_skin3"]),
            unit("h_firefighter", .damager, .emergency, .courage, cost: 25, prep: 20.0, hp: 105, melee: 25, ranged: 0, range: 16, speed: 48, critC: 0.16, critD: 0.6, unlockCoins: 550, unlockCash: 0, rank: 3, res: ZWUnitResistances(bulletResist: 0, meleeResist: 0, fireImmune: true, poisonImmune: true, explosionResist: 0.5, knockbackResist: 0.2), perk: "Fire, Poison & Explosion resistant", sp: "Ignites on death with oil", corpse: "z_firefighter", skins: ["h_firefighter_skin1", "h_firefighter_skin2", "h_firefighter_skin3"]),
            unit("h_grenader", .damager, .ifForce, .courage, cost: 25, prep: 22.0, hp: 112, melee: 26, ranged: 0, range: 16, speed: 52, critC: 0.15, critD: 0.5, unlockCoins: 1100, unlockCash: 0, rank: 5, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: false, poisonImmune: false, explosionResist: 0.3, knockbackResist: 0.3), perk: "Throws frag grenade (160 AoE dmg)", sp: "Throws additional grenade on death", corpse: "z_bulletproof", skins: ["h_grenader_skin1", "h_grenader_skin2"]),
            unit("h_cheechmarin", .fighter, .marines, .courage, cost: 15, prep: 3.5, hp: 46, melee: 18, ranged: 0, range: 15, speed: 70, critC: 0.20, critD: 0.8, unlockCoins: 1400, unlockCash: 0, rank: 6, res: .none, perk: "Combat knife multi-slash", sp: "Drops frag knife throw every 3 hits", corpse: "z_cheechmarin", skins: ["h_cheechmarin_skin1", "h_cheechmarin_skin2"]),
            unit("h_sniper", .sniper, .jailers, .courage, cost: 25, prep: 32.0, hp: 48, melee: 6, ranged: 54, range: 260, speed: 38, critC: 0.10, critD: 0.7, unlockCoins: 2400, unlockCash: 0, rank: 6, res: .none, perk: "Longest sniper range on battlefield", sp: "Ignores 40% of enemy armor", corpse: "z_girl", skins: ["h_sniper_skin1", "h_sniper_skin2", "h_sniper_skin3"]),
            unit("h_charlotte", .sniper, .police, .courage, cost: 25, prep: 28.0, hp: 52, melee: 8, ranged: 44, range: 210, speed: 42, critC: 0.12, critD: 0.6, unlockCoins: 1800, unlockCash: 0, rank: 5, res: .none, perk: "Each consecutive shot boosts damage", sp: "Stacking precision (+10% per hit)", corpse: "z_girl", skins: ["h_charlotte_skin1", "h_charlotte_skin2"]),
            unit("h_carlos", .shooter, .prisoners, .courage, cost: 20, prep: 20.0, hp: 52, melee: 7, ranged: 11, range: 145, speed: 52, critC: 0.12, critD: 0.5, unlockCoins: 1600, unlockCash: 0, rank: 5, res: .none, perk: "Dual-wield rapid fire SMGs", sp: "Adds incendiary rounds", corpse: "z_naked", skins: ["h_carlos_skin1", "h_carlos_skin2", "h_carlos_skin3"]),
            unit("h_sonya", .shooter, .marines, .courage, cost: 25, prep: 22.0, hp: 64, melee: 18, ranged: 14, range: 150, speed: 54, critC: 0.15, critD: 0.6, unlockCoins: 3500, unlockCash: 0, rank: 7, res: .none, perk: "Roundhouse kick knocks back flankers", sp: "Extra burst projectiles per volley", corpse: "z_girl", skins: ["h_sonya_skin1", "h_sonya_skin2"]),
            unit("h_shocker", .fighter, .tmf, .courage, cost: 20, prep: 6.5, hp: 78, melee: 29, ranged: 0, range: 15, speed: 66, critC: 0.25, critD: 0.8, unlockCoins: 8500, unlockCash: 0, rank: 10, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: false, poisonImmune: false, explosionResist: 0, knockbackResist: 0.4), perk: "Stuns enemies on critical stun baton", sp: "Deals +1% damage per 3 pts of Agility", corpse: "z_bulletproof", skins: ["h_shocker_skin1", "h_shocker_skin2", "h_shocker_skin3"]),
            unit("h_glenn", .fighter, .police, .courage, cost: 25, prep: 18.0, hp: 65, melee: 19, ranged: 0, range: 14, speed: 62, critC: 0.18, critD: 0.6, unlockCoins: 2800, unlockCash: 0, rank: 7, res: .none, perk: "Revives after death (up to 2x at Lvl 30)", sp: "Second revival with full fury", corpse: "z_naked", skins: ["h_glenn_skin1", "h_glenn_skin2", "h_glenn_skin3"]),
            unit("h_medic", .support, .emergency, .courage, cost: 35, prep: 32.0, hp: 70, melee: 8, ranged: 14, range: 140, speed: 46, critC: 0.08, critD: 0.5, unlockCoins: 3200, unlockCash: 0, rank: 7, res: ZWUnitResistances(bulletResist: 0, meleeResist: 0, fireImmune: false, poisonImmune: true, explosionResist: 0, knockbackResist: 0), perk: "Drops Medkits for wounded allies", sp: "Heals Poisoned teammates", corpse: "z_shielder", skins: ["h_medic_skin1", "h_medic_skin2"]),
            unit("h_hero", .shotgunner, .ifForce, .courage, cost: 30, prep: 24.0, hp: 96, melee: 14, ranged: 28, range: 125, speed: 50, critC: 0.14, critD: 0.6, unlockCoins: 4200, unlockCash: 0, rank: 8, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: false, poisonImmune: false, explosionResist: 0, knockbackResist: 0.3), perk: "Bulletproof armor + rapid tactical shotgun", sp: "12% dodge evasion chance", corpse: "z_bulletproof", skins: ["h_hero_skin1", "h_hero_skin2"]),
            unit("h_guard", .damager, .jailers, .courage, cost: 30, prep: 24.0, hp: 138, melee: 32, ranged: 0, range: 16, speed: 56, critC: 0.22, critD: 0.8, unlockCoins: 4800, unlockCash: 0, rank: 8, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: false, poisonImmune: false, explosionResist: 0, knockbackResist: 0.5), perk: "Gains shield on critical hit", sp: "Starts with 25% HP Energy Shield", corpse: "z_undead", skins: ["h_guard_skin1", "h_guard_skin2", "h_guard_skin3"]),
            unit("h_hammer", .heavyweight, .builders, .courage, cost: 35, prep: 35.0, hp: 310, melee: 48, ranged: 0, range: 18, speed: 36, critC: 0.25, critD: 0.9, unlockCoins: 6500, unlockCash: 0, rank: 9, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: false, poisonImmune: false, explosionResist: 0.5, knockbackResist: 0.8), perk: "Explosive slam shockwave crits", sp: "Gains a shield equal to 30% HP", corpse: "z_heavyGuard", skins: ["h_hammer_skin1", "h_hammer_skin2", "h_hammer_skin3"]),
            unit("h_paramedicVolt", .support, .rednecks, .courage, cost: 25, prep: 22.0, hp: 68, melee: 10, ranged: 0, range: 16, speed: 54, critC: 0.05, critD: 0.5, unlockCoins: 7500, unlockCash: 0, rank: 10, res: ZWUnitResistances(bulletResist: 0, meleeResist: 0, fireImmune: false, poisonImmune: true, explosionResist: 0, knockbackResist: 0), perk: "Heals allies and revives fallen allies once", sp: "Lightning strike on death damages foes", corpse: "z_paramedicVolt", skins: ["h_paramedicVolt_skin1", "h_paramedicVolt_skin2"]),
            unit("h_heavyGuard", .heavyweight, .scientists, .courage, cost: 35, prep: 38.0, hp: 230, melee: 22, ranged: 16, range: 85, speed: 34, critC: 0.10, critD: 0.5, unlockCoins: 5800, unlockCash: 0, rank: 9, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: false, poisonImmune: true, explosionResist: 0.4, knockbackResist: 0.8), perk: "Stun gun freezes targets in tracks", sp: "Shield equals 50% of max HP", corpse: "z_heavyGuard", skins: ["h_heavyGuard_skin1", "h_heavyGuard_skin2"]),
            unit("h_abby", .shooter, .builders, .courage, cost: 40, prep: 45.0, hp: 90, melee: 28, ranged: 36, range: 155, speed: 44, critC: 0.12, critD: 0.5, unlockCoins: 9200, unlockCash: 0, rank: 11, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: false, poisonImmune: false, explosionResist: 0, knockbackResist: 0.4), perk: "Fires devastating Minigun burst, then swings hammer", sp: "30% longer Minigun fire time", corpse: "z_abby", skins: ["h_abby_skin1", "h_abby_skin2", "h_abby_skin3"]),
            unit("h_austin", .shooter, .psychos, .courage, cost: 25, prep: 28.0, hp: 70, melee: 12, ranged: 18, range: 145, speed: 50, critC: 0.10, critD: 0.5, unlockCoins: 0, unlockCash: 250, rank: 5, res: .none, perk: "Generates bonus Coins on enemy kills", sp: "Increases Coin bag chance (+150%)", corpse: "z_naked", skins: ["h_austin_skin1", "h_austin_skin2"]),
            unit("h_agent", .shooter, .police, .courage, cost: 20, prep: 26.0, hp: 58, melee: 10, ranged: 21, range: 155, speed: 54, critC: 0.15, critD: 0.6, unlockCoins: 0, unlockCash: 180, rank: 4, res: .none, perk: "Deploys TWO silenced Agents for 1 slot", sp: "Counts as 2 Police units for Synergy", corpse: "z_copsmall", skins: ["h_agent_skin1", "h_agent_skin2"]),
            unit("h_specops", .shooter, .military, .courage, cost: 30, prep: 32.0, hp: 102, melee: 22, ranged: 22, range: 155, speed: 52, critC: 0.15, critD: 0.6, unlockCoins: 0, unlockCash: 250, rank: 7, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: false, poisonImmune: false, explosionResist: 0, knockbackResist: 0.3), perk: "Parachutes anywhere onto the battlefield", sp: "Drops random Support Item on death", corpse: "z_soldier", skins: ["h_specops_skin1"]),
            unit("h_swat", .shooter, .tmf, .courage, cost: 35, prep: 36.0, hp: 110, melee: 20, ranged: 20, range: 155, speed: 46, critC: 0.12, critD: 0.5, unlockCoins: 0, unlockCash: 320, rank: 8, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: true, poisonImmune: true, explosionResist: 0.9, knockbackResist: 0.4), perk: "Incendiary bullets ignite enemies", sp: "Increases Charisma buff on TMF allies", corpse: "z_swat", skins: ["h_swat_skin1"]),
            unit("h_flamethrower", .shotgunner, .tmf, .courage, cost: 30, prep: 30.0, hp: 96, melee: 15, ranged: 16, range: 85, speed: 48, critC: 0.10, critD: 0.5, unlockCoins: 0, unlockCash: 320, rank: 8, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: true, poisonImmune: true, explosionResist: 0.5, knockbackResist: 0.3), perk: "Scorching continuous flame stream", sp: "Double fire damage over time", corpse: "z_swat", skins: ["h_flamethrower_skin1"]),
            unit("h_soldierCap", .shooter, .tmf, .courage, cost: 30, prep: 30.0, hp: 108, melee: 18, ranged: 22, range: 150, speed: 48, critC: 0.14, critD: 0.6, unlockCoins: 0, unlockCash: 320, rank: 8, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: true, poisonImmune: true, explosionResist: 0.5, knockbackResist: 0.4), perk: "Inspires teammates periodically", sp: "Increases damage of inspired allies", corpse: "z_swat", skins: ["h_soldierCap_skin1"]),
            unit("h_ballisticShielder", .heavyweight, .tmf, .courage, cost: 35, prep: 35.0, hp: 360, melee: 26, ranged: 0, range: 16, speed: 34, critC: 0.12, critD: 0.5, unlockCoins: 0, unlockCash: 320, rank: 8, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: true, poisonImmune: true, explosionResist: 0.9, knockbackResist: 0.9), perk: "Titanium riot shield absorbs massive hits", sp: "Additional HP shield aura", corpse: "z_heavyGuard", skins: ["h_ballisticShielder_skin1", "h_ballisticShielder_skin2", "h_ballisticShielder_skin3"]),
            unit("h_saw", .fighter, .psychos, .rage, cost: 20, prep: 18.0, hp: 78, melee: 34, ranged: 0, range: 16, speed: 60, critC: 0.25, critD: 0.7, unlockCoins: 0, unlockCash: 250, rank: 8, res: .none, perk: "Summoned with Rage points; chainsaw shreds", sp: "Costs 15 Rage instead of 20", corpse: "z_chopper", skins: ["h_saw_skin1", "h_saw_skin2"]),
            unit("h_berserker", .fighter, .psychos, .rage, cost: 15, prep: 12.0, hp: 68, melee: 30, ranged: 0, range: 15, speed: 68, critC: 0.28, critD: 0.8, unlockCoins: 0, unlockCash: 250, rank: 8, res: .none, perk: "Summoned with Rage; twin axes bleed foes", sp: "Lowers Rage cost and raises crit", corpse: "z_hunter", skins: ["h_berserker_skin1"]),
            unit("h_queen", .shooter, .psychos, .rage, cost: 20, prep: 20.0, hp: 74, melee: 18, ranged: 32, range: 145, speed: 50, critC: 0.15, critD: 0.6, unlockCoins: 0, unlockCash: 250, rank: 8, res: .none, perk: "Fires explosive cluster grenades", sp: "Drops fire puddle on grenade detonation", corpse: "z_girl", skins: ["h_queen_skin1", "h_queen_skin2"]),
            unit("h_epidemiologist", .support, .scientists, .courage, cost: 25, prep: 26.0, hp: 74, melee: 10, ranged: 22, range: 145, speed: 46, critC: 0.10, critD: 0.5, unlockCoins: 0, unlockCash: 280, rank: 9, res: ZWUnitResistances(bulletResist: 0, meleeResist: 0, fireImmune: false, poisonImmune: true, explosionResist: 0, knockbackResist: 0), perk: "Marks enemies to receive +50% damage", sp: "Explodes poison cloud on death", corpse: "z_yellow", skins: ["h_epidemiologist_skin1"]),
            unit("h_freeze", .support, .scientists, .courage, cost: 30, prep: 30.0, hp: 82, melee: 12, ranged: 20, range: 120, speed: 44, critC: 0.10, critD: 0.5, unlockCoins: 0, unlockCash: 280, rank: 9, res: ZWUnitResistances(bulletResist: 0, meleeResist: 0, fireImmune: true, poisonImmune: true, explosionResist: 0.4, knockbackResist: 0.2), perk: "Liquid nitrogen cannon slows zombies", sp: "Freezes nearby enemies solid on death", corpse: "z_yellow", skins: ["h_freeze_skin1", "h_freeze_skin2"]),
            unit("h_yellow", .support, .scientists, .courage, cost: 20, prep: 20.0, hp: 66, melee: 10, ranged: 16, range: 135, speed: 50, critC: 0.10, critD: 0.5, unlockCoins: 0, unlockCash: 280, rank: 9, res: ZWUnitResistances(bulletResist: 0, meleeResist: 0, fireImmune: false, poisonImmune: true, explosionResist: 0, knockbackResist: 0), perk: "Plants laser proximity Claymore Mine", sp: "Drops backup Claymore when killed", corpse: "z_yellow", skins: ["h_yellow_skin1"]),
            unit("h_welder", .support, .mechanics, .rage, cost: 50, prep: 65.0, hp: 56, melee: 16, ranged: 0, range: 18, speed: 64, critC: 0.05, critD: 0.5, unlockCoins: 3600, unlockCash: 0, rank: 7, res: .none, perk: "Ignores enemies, repairs Bus & destroys Barricade", sp: "Repairs active Turrets & Generators", corpse: "", skins: ["h_welder_skin1"]),
            unit("h_carol", .fighter, .ifForce, .courage, cost: 20, prep: 18.0, hp: 62, melee: 28, ranged: 0, range: 16, speed: 74, critC: 0.25, critD: 0.7, unlockCoins: 4200, unlockCash: 0, rank: 7, res: .none, perk: "Teleporting spear lunge strikes targets immediately", sp: "Crit on lunge resets cooldown", corpse: "z_girl", skins: ["h_carol_skin1", "h_carol_skin2"]),
            unit("h_jailer", .damager, .jailers, .courage, cost: 15, prep: 10.0, hp: 72, melee: 20, ranged: 0, range: 15, speed: 58, critC: 0.22, critD: 0.6, unlockCoins: 0, unlockCash: 90, rank: 3, res: .none, perk: "Taser baton chains stun across foes", sp: "Critical arc stuns up to 3 enemies", corpse: "z_naked", skins: ["h_jailer_skin1"]),
            unit("h_jailerrifle", .shooter, .jailers, .courage, cost: 15, prep: 16.0, hp: 50, melee: 6, ranged: 12, range: 145, speed: 50, critC: 0.12, critD: 0.5, unlockCoins: 400, unlockCash: 0, rank: 3, res: .none, perk: "Rapid semi-auto rifleman at low Courage cost", sp: "Fires extra armor-piercing round", corpse: "z_naked", skins: ["h_jailerrifle_skin1", "h_jailerrifle_skin2"]),
            unit("h_lightSoldier", .damager, .ifForce, .courage, cost: 30, prep: 26.0, hp: 164, melee: 38, ranged: 0, range: 17, speed: 50, critC: 0.24, critD: 0.8, unlockCoins: 7600, unlockCash: 0, rank: 10, res: ZWUnitResistances(bulletResist: 0.9, meleeResist: 0, fireImmune: false, poisonImmune: true, explosionResist: 0.5, knockbackResist: 0.7), perk: "Heavy armored IF Bruiser", sp: "Increased knockback & bonus crit dmg", corpse: "z_bulletproof", skins: ["h_lightSoldier_skin1"]),
            unit("h_chopper", .heavyweight, .northerners, .courage, cost: 30, prep: 28.0, hp: 280, melee: 34, ranged: 0, range: 17, speed: 38, critC: 0.15, critD: 0.6, unlockCoins: 3000, unlockCash: 0, rank: 6, res: ZWUnitResistances(bulletResist: 0, meleeResist: 0, fireImmune: false, poisonImmune: false, explosionResist: 0, knockbackResist: 0.9), perk: "Periodically drinks beverage restoring 30% HP", sp: "Boosts HP up to +50%", corpse: "z_chopper", skins: ["h_chopper_skin1", "h_chopper_skin2"]),
            unit("h_turbogirl", .damager, .college, .courage, cost: 25, prep: 20.0, hp: 96, melee: 28, ranged: 0, range: 16, speed: 56, critC: 0.20, critD: 0.7, unlockCoins: 0, unlockCash: 250, rank: 6, res: ZWUnitResistances(bulletResist: 1.0, meleeResist: 0, fireImmune: false, poisonImmune: false, explosionResist: 0.2, knockbackResist: 0.4), perk: "100% Bulletproof crash helmet", sp: "Baseball swing launches foes backwards", corpse: "z_girl", skins: ["h_turbogirl_skin1"]),
            unit("h_cashier", .fighter, .college, .courage, cost: 25, prep: 18.0, hp: 78, melee: 26, ranged: 0, range: 15, speed: 56, critC: 0.25, critD: 3.0, unlockCoins: 0, unlockCash: 250, rank: 6, res: .none, perk: "4x Critical damage multiplier", sp: "Crits apply bleeding", corpse: "z_naked", skins: ["h_cashier_skin1"]),
            unit("h_lester", .shotgunner, .northerners, .courage, cost: 20, prep: 16.0, hp: 56, melee: 9, ranged: 24, range: 118, speed: 52, critC: 0.16, critD: 0.6, unlockCoins: 0, unlockCash: 200, rank: 5, res: .none, perk: "Faster reload & higher move speed than Farmer", sp: "Blazing double blast pellets", corpse: "z_naked", skins: ["h_lester_skin1", "h_lester_skin2"]),
            unit("h_xmas", .fighter, .psychos, .courage, cost: 20, prep: 16.0, hp: 82, melee: 25, ranged: 0, range: 16, speed: 58, critC: 0.20, critD: 0.6, unlockCoins: 0, unlockCash: 220, rank: 6, res: .none, perk: "Shockwave axe crits inspire teammates", sp: "Adds fire resistance & extra psy waves", corpse: "z_naked", skins: ["h_xmas_skin1"]),
            unit("h_forestFirefighter", .heavyweight, .emergency, .courage, cost: 30, prep: 28.0, hp: 250, melee: 32, ranged: 0, range: 17, speed: 44, critC: 0.16, critD: 0.6, unlockCoins: 5400, unlockCash: 0, rank: 8, res: ZWUnitResistances(bulletResist: 0, meleeResist: 0, fireImmune: true, poisonImmune: false, explosionResist: 0.4, knockbackResist: 0.8), perk: "Slams burning oil pools on attack", sp: "Boosts damage per burning unit nearby", corpse: "z_forestFirefighter", skins: ["h_forestFirefighter_skin1"]),
            unit("h_escapee", .shooter, .prisoners, .courage, cost: 25, prep: 24.0, hp: 70, melee: 12, ranged: 22, range: 145, speed: 54, critC: 0.18, critD: 0.6, unlockCoins: 4600, unlockCash: 0, rank: 7, res: .none, perk: "Heals allies slightly per headshot kill", sp: "Ricochet double pistol rounds", corpse: "z_girlPrisoner", skins: ["h_escapee_skin1"]),
            unit("h_archer", .sniper, .patriots, .courage, cost: 25, prep: 26.0, hp: 56, melee: 8, ranged: 34, range: 185, speed: 48, critC: 0.18, critD: 0.7, unlockCoins: 0, unlockCash: 250, rank: 6, res: .none, perk: "Explosive fire arrows ignite and damage AoE", sp: "Arrows pierce first enemy", corpse: "z_girl", skins: ["h_archer_skin1"]),
            unit("h_haruko", .fighter, .delivery, .courage, cost: 20, prep: 14.0, hp: 66, melee: 22, ranged: 0, range: 15, speed: 66, critC: 0.18, critD: 0.6, unlockCoins: 3800, unlockCash: 0, rank: 7, res: .none, perk: "Agile delivery courier", sp: "Gains dodge chance while running", corpse: "z_girl", skins: ["h_haruko_skin1"]),
            unit("h_akira", .shooter, .delivery, .courage, cost: 25, prep: 22.0, hp: 80, melee: 14, ranged: 26, range: 165, speed: 54, critC: 0.15, critD: 0.6, unlockCoins: 5200, unlockCash: 0, rank: 9, res: .none, perk: "Railgun burst pierces crowds", sp: "Plasma beam penetrates barricades", corpse: "z_naked", skins: ["h_akira_skin1"]),
            unit("h_sarah", .fighter, .southerners, .courage, cost: 20, prep: 15.0, hp: 64, melee: 24, ranged: 0, range: 15, speed: 62, critC: 0.20, critD: 0.7, unlockCoins: 3200, unlockCash: 0, rank: 6, res: .none, perk: "Quick melee striker", sp: "Extra bleeding on critical strike", corpse: "z_girl", skins: ["h_sarah_skin1"]),
            unit("h_decoy", .support, .builders, .courage, cost: 25, prep: 25.0, hp: 85, melee: 20, ranged: 0, range: 15, speed: 50, critC: 0.15, critD: 0.5, unlockCoins: 3600, unlockCash: 0, rank: 7, res: .none, perk: "Demolitionist blasts targets with C4", sp: "Large explosive detonation on defeat", corpse: "z_builder", skins: [])
        ]
    }

    private static func unit(
        _ id: String, _ cls: ZWUnitClass, _ faction: ZWTeamFaction, _ cur: ZWCoinCurrency,
        cost: Int, prep: Double, hp: Double, melee: Double, ranged: Double,
        range: Double, speed: Double, critC: Double, critD: Double,
        unlockCoins: Int, unlockCash: Int, rank: Int,
        res: ZWUnitResistances, perk: String, sp: String, corpse: String, skins: [String]
    ) -> ZWUnitDefinition {
        ZWUnitDefinition(
            id: id,
            locNameKey: "unit.\(id)",
            locDescrKey: "unit.description.\(id)",
            unitClass: cls,
            faction: faction,
            currency: cur,
            cost: cost,
            prepareTime: prep,
            baseHP: hp,
            baseMeleeDamage: melee,
            baseRangedDamage: ranged,
            attackRange: range,
            moveSpeed: speed,
            critChance: critC,
            critDamage: critD,
            agility: 75,
            aggression: 75,
            charisma: 65,
            valor: 65,
            unlockCostCoins: unlockCoins,
            unlockCostCash: unlockCash,
            requiredRank: rank,
            resistances: res,
            perkSummary: perk,
            specialAbilityDescr: sp,
            zombieCorpseID: corpse,
            skinIDs: skins
        )
    }

    private static func buildSupportItems() -> [ZWSupportItemDefinition] {
        return [
            ZWSupportItemDefinition(id: "item_barrel", locNameKey: "unit.item_barrel", cost: 10, prepareTime: 10, baseDamage: 90, duration: 15, radius: 22, description: "Drops an empty steel barrel that blocks zombies", unlockCostCoins: 150),
            ZWSupportItemDefinition(id: "item_red_barrel", locNameKey: "unit.item_red_barrel", cost: 15, prepareTime: 12, baseDamage: 240, duration: 15, radius: 52, description: "Drops an explosive fuel barrel; tap or break to detonate", unlockCostCoins: 450),
            ZWSupportItemDefinition(id: "item_medkit", locNameKey: "unit.item_medkit", cost: 15, prepareTime: 15, baseDamage: 0, duration: 12, radius: 55, description: "Heals all allied units inside the medkit aura", unlockCostCoins: 350),
            ZWSupportItemDefinition(id: "item_molotov", locNameKey: "unit.item_molotov", cost: 20, prepareTime: 22, baseDamage: 140, duration: 8, radius: 54, description: "Coats an area in burning flames that melt zombies over time", unlockCostCoins: 900),
            ZWSupportItemDefinition(id: "item_nitrogen", locNameKey: "unit.item_nitrogen", cost: 25, prepareTime: 26, baseDamage: 85, duration: 9, radius: 60, description: "Freezes and heavily slows zombies across a wide blast zone", unlockCostCoins: 1800),
            ZWSupportItemDefinition(id: "item_generator", locNameKey: "unit.item_generator", cost: 25, prepareTime: 30, baseDamage: 0, duration: 30, radius: 24, description: "Produces +25 Courage periodically on the battlefield", unlockCostCoins: 2400),
            ZWSupportItemDefinition(id: "item_turret", locNameKey: "unit.item_turret", cost: 35, prepareTime: 35, baseDamage: 18, duration: 22, radius: 190, description: "Automatic sentry gun shreds oncoming hordes", unlockCostCoins: 5500),
            ZWSupportItemDefinition(id: "item_grenade", locNameKey: "unit.item_grenade", cost: 20, prepareTime: 20, baseDamage: 320, duration: 0.5, radius: 58, description: "Instant precision fragmentation airstrike", unlockCostCoins: 2200),
            ZWSupportItemDefinition(id: "item_drone", locNameKey: "unit.item_drone", cost: 20, prepareTime: 25, baseDamage: 280, duration: 6, radius: 65, description: "Decoy radar drone lures zombies together before detonating", unlockCostCoins: 3400)
        ]
    }

    // Evidence: All 79 verified IDs from localization.json (`zombiepedia.unit.name.*`)
    private static func buildEnemies() -> [ZWEnemyDefinition] {
        let specs: [(id: String, hp: Double, dmg: Double, spd: Double, range: Double, demon: Bool, mar: Bool, br: Double, fireImm: Bool, traits: [String])] = [
            ("z_naked", 55, 11, 28, 13, false, false, 0, false, ["Common walker"]),
            ("z_nakedRun", 48, 12, 46, 13, false, false, 0, false, ["Fast runner"]),
            ("z_girl", 42, 9, 32, 12, false, false, 0, false, ["Agile walker"]),
            ("z_builder", 130, 17, 26, 14, false, false, 0.85, false, ["Bulletproof helmet"]),
            ("z_builderRun", 95, 16, 44, 14, false, false, 0.75, false, ["Fast armored runner"]),
            ("z_boomer", 260, 24, 20, 15, false, false, 0.5, false, ["Explodes on death"]),
            ("z_skeleton", 34, 10, 38, 12, false, false, 0, false, ["Rises in cemeteries"]),
            ("z_blackSkeleton", 90, 14, 34, 13, false, false, 0.4, false, ["Sturdy skeleton"]),
            ("z_skeletonMillitary", 160, 18, 30, 14, false, false, 0.9, false, ["Bulletproof skeleton"]),
            ("z_skeletonSapper", 120, 35, 32, 14, false, false, 0.4, false, ["Detonates near units"]),
            ("z_cop", 340, 26, 22, 15, false, false, 0.4, false, ["Heavy riot cruiser"]),
            ("z_copsmall", 75, 13, 36, 13, false, false, 0.3, false, ["Traffic officer"]),
            ("z_firefighter", 185, 22, 26, 15, false, false, 0, true, ["Fire & explosion immune"]),
            ("z_forestFirefighter", 240, 25, 24, 15, false, false, 0, true, ["Burns allies nearby"]),
            ("z_farmer", 68, 12, 28, 13, false, false, 0, false, ["Infected farmer"]),
            ("z_chopper", 380, 30, 22, 16, false, false, 0, false, ["High HP knockback resistant"]),
            ("z_heavyGuard", 480, 36, 20, 16, false, false, 0.75, false, ["Heavy armored juggernaut"]),
            ("z_bulletproof", 190, 20, 28, 14, false, false, 0.9, false, ["90% Bullet resistance"]),
            ("z_hunter", 72, 18, 52, 14, false, false, 0, false, ["Frenetic runner"]),
            ("z_witch", 88, 22, 58, 13, false, false, 0, false, ["Screams & rushes rapidly"]),
            ("z_demon", 520, 40, 22, 16, true, false, 0.6, true, ["Periodic ground spike wave"]),
            ("z_demonMini", 160, 20, 44, 14, true, false, 0.3, true, ["Spawns from Demon portals"]),
            ("z_dog", 45, 14, 58, 12, false, false, 0, false, ["Rapid hound"]),
            ("z_yellow", 125, 16, 30, 14, false, false, 0, false, ["Poisonous spit"]),
            ("z_yellowFat", 290, 22, 20, 15, false, false, 0.3, false, ["Explodes in toxic cloud"]),
            ("z_putrid", 320, 26, 22, 15, false, false, 0.3, false, ["Releases runners on death"]),
            ("z_rotten", 95, 15, 26, 13, false, false, 0, false, ["Relentless horde zombie"]),
            ("z_puke", 70, 14, 24, 13, false, false, 0, false, ["Poison puddle on fall"]),
            ("z_undead", 145, 21, 28, 14, false, false, 0.85, false, ["Revives multiple times unless burned"]),
            ("z_necromancer", 140, 15, 18, 90, false, false, 0.3, false, ["Summons skeletons periodically"]),
            ("z_paramedic", 210, 32, 22, 15, false, false, 0.6, false, ["Lightning shock on attack"]),
            ("z_paramedicVolt", 150, 20, 30, 14, false, false, 0.2, false, ["Charges nearby zombies"]),
            ("z_megavolt", 250, 34, 22, 15, false, false, 0.5, false, ["High-voltage AoE discharge"]),
            ("z_swat", 280, 28, 26, 15, false, false, 0.9, true, ["Full riot SWAT armor"]),
            ("z_soldier", 220, 24, 28, 15, false, false, 0.85, false, ["Armored military sergeant"]),
            ("z_soldierfat", 240, 25, 24, 15, false, false, 0.5, false, ["Heavy infantry zombie"]),
            ("z_cheechmarin", 110, 19, 34, 14, false, false, 0.2, false, ["Fallen marine"]),
            ("z_shielder", 160, 15, 28, 14, false, false, 0.4, false, ["Medical gear"]),
            ("z_monk", 180, 22, 34, 14, false, false, 0.2, false, ["Fast lunging strikes"]),
            ("z_prisoner", 130, 18, 30, 14, false, false, 0.2, false, ["Hardened inmate"]),
            ("z_prisonerLocusts", 140, 22, 42, 14, false, false, 0.2, false, ["Venomous locust variant"]),
            ("z_girlPrisoner", 220, 26, 46, 14, false, false, 0.8, false, ["Transformative two-phase Escapee"]),
            ("z_girlPumpkin", 120, 18, 44, 14, false, false, 0.2, false, ["Pumpkin festival variant"]),
            ("z_abby", 310, 36, 36, 15, false, false, 0.85, false, ["Deadly fast juggernaut"]),
            ("z_crank", 460, 42, 22, 16, false, false, 0.5, false, ["Gains frenzy damage boost"]),
            ("z_twins", 580, 35, 18, 16, false, false, 0.85, false, ["Extreme bulletproof + melee defense"]),
            ("z_kamikaze", 35, 85, 76, 12, false, false, 0, false, ["Charged suicide rusher"]),
            ("z_sphere", 135, 999, 28, 12, true, false, 0.7, true, ["Converts killed units into Offal"]),
            ("z_offal", 150, 20, 36, 14, false, false, 0, false, ["Corrupted unit husk"]),
            ("z_egg", 650, 0, 0, 16, true, false, 0.9, true, ["Spawns Energy Spheres & Shockwaves"]),
            ("z_preEgg", 340, 28, 22, 15, true, false, 0.5, true, ["Armored spore carrier"]),
            ("z_insect", 170, 32, 48, 14, true, false, 0.2, false, ["Leaps onto ranged units"]),
            ("z_preAlien", 110, 20, 44, 14, true, false, 0, false, ["Feral xenomorph stalker"]),
            ("z_alienNaked", 220, 24, 24, 15, true, false, 0.2, false, ["Blue zombie stuns on hit"]),
            ("z_alienNakedRun", 175, 22, 44, 14, true, false, 0.2, false, ["Fast Blue runner"]),
            ("z_alienBuilder", 440, 30, 20, 16, true, false, 0.6, false, ["Tough Blue high HP brute"]),
            ("z_alienCop", 680, 36, 18, 16, true, false, 0.7, false, ["Big Blue regenerates HP"]),
            ("z_alienBoomer", 520, 34, 18, 16, true, false, 0.5, false, ["Blubber freezes/slows on burst"]),
            ("z_alienTwins", 860, 42, 18, 16, true, false, 0.9, false, ["Double-headed zombie bullet tank"]),
            ("z_hypnotist", 210, 26, 20, 120, true, false, 0.3, false, ["Mind-control beam stuns survivors"]),
            ("z_psy", 180, 24, 24, 95, true, false, 0.2, false, ["Psychic pulse shockwave"]),
            ("z_mimic", 260, 28, 28, 15, true, false, 0.4, false, ["Duplicates on hit"]),
            ("z_terminal", 340, 32, 26, 15, true, false, 0.6, false, ["Releases high-voltage shock"]),
            ("z_boss", 2400, 65, 16, 18, true, false, 0.7, true, ["Location Crane Boss"]),
            ("z_cephalopoda", 4800, 95, 0, 220, true, false, 0.85, true, ["Location 8 Final Alien Boss"]),
            ("z_cephalopodaMini", 240, 24, 34, 14, true, false, 0.4, true, ["Sentinel drone"]),
            ("z_freehugs", 50, 0, 0, 10, false, false, 0, false, ["Drops bonus Rage points"]),
            ("z_smoker", 90, 14, 24, 80, false, false, 0, false, ["Cut archive enemy"]),
            ("z_chinese", 75, 14, 30, 14, false, false, 0, false, ["Historical event walker"]),
            ("z_chineseExpl", 95, 45, 32, 14, false, false, 0, false, ["Firework hazard"]),
            ("z_xmasnaked", 65, 12, 28, 13, false, false, 0, false, ["Holiday event walker"]),
            ("z_xmasnakedrun", 55, 14, 46, 13, false, false, 0, false, ["Holiday runner"]),
            ("z_xmasgirl", 50, 11, 34, 13, false, false, 0, false, ["Holiday variant"]),
            ("z_xmascop", 290, 24, 22, 15, false, false, 0.4, false, ["Holiday heavyweight"]),
            ("z_pumpkinnaked", 70, 14, 30, 13, false, false, 0, false, ["Halloween walker"]),
            ("z_pumpkinnakedrun", 60, 15, 46, 13, false, false, 0, false, ["Halloween runner"]),
            ("z_summernaked", 65, 12, 30, 13, false, false, 0, false, ["Summer beach walker"]),
            ("z_summernakedrun", 55, 14, 46, 13, false, false, 0, false, ["Summer beach runner"]),
            // Marauders (b_*)
            ("b_naked", 60, 13, 38, 14, false, true, 0, false, ["Fast armed marauder"]),
            ("b_crazy", 68, 17, 46, 14, false, true, 0, false, ["Reckless berserker marauder"]),
            ("b_builder", 130, 20, 34, 15, false, true, 0.85, false, ["Bulletproof marauder"]),
            ("b_brother", 110, 16, 38, 14, false, true, 0.3, false, ["Loot scavenger"]),
            ("b_farmer", 78, 22, 28, 135, false, true, 0, false, ["Rifleman shoots from range"]),
            ("b_biker", 145, 24, 40, 14, false, true, 0.4, false, ["Heavy melee biker"]),
            ("b_cap", 160, 24, 32, 140, false, true, 0.5, false, ["Marauder officer"]),
            ("b_bomber", 180, 45, 28, 140, false, true, 0.5, false, ["Throws grenades"]),
            ("b_alienBuilder", 320, 34, 24, 16, false, true, 0.85, false, ["Armored Brute marauder"])
        ]

        return specs.map { s in
            ZWEnemyDefinition(
                id: s.id,
                locNameKey: "zombiepedia.unit.name.\(s.id)",
                locDescrKey: "zombiepedia.unit.descr.\(s.id)",
                baseHP: s.hp,
                damage: s.dmg,
                moveSpeed: s.spd,
                attackRange: s.range,
                isDemon: s.demon,
                isMarauder: s.mar,
                resistances: ZWUnitResistances(
                    bulletResist: s.br,
                    meleeResist: 0,
                    fireImmune: s.fireImm,
                    poisonImmune: s.demon,
                    explosionResist: s.br * 0.4,
                    knockbackResist: s.hp > 250 ? 0.6 : 0.1
                ),
                traits: s.traits,
                killMilestones: [10, 50, 200, 1000]
            )
        }
    }

    private static func buildSynergies() -> [ZWTeamSynergyDefinition] {
        return [
            ZWTeamSynergyDefinition(faction: .rednecks, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.14.description", effectSummary: "5% chance of bonus Courage (+25) when Redneck takes damage"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.15.description", effectSummary: "Redneck restores 100% HP when bonus Courage drops"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.16.description", effectSummary: "All allies gain reduced fire/poison duration")
            ]),
            ZWTeamSynergyDefinition(faction: .mechanics, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.2.description", effectSummary: "Repairs Bus HP by 5% every time a Mechanic is deployed"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.19.description", effectSummary: "25% chance (100% for Welder) to spawn a Turret on deploy"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.20.description", effectSummary: "Turrets overheat 3x slower")
            ]),
            ZWTeamSynergyDefinition(faction: .police, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.4.description", effectSummary: "Increases magazine capacity by +100%"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.39.description", effectSummary: "All Police units gain an Energy Shield equal to 100% HP"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.25.description", effectSummary: "Whenever a Police unit falls, all survivors gain Fury")
            ]),
            ZWTeamSynergyDefinition(faction: .marines, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.12.description", effectSummary: "Private Rodriguez gains max Agility & Aggression"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.26.description", effectSummary: "All Marines gain max Agility"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.27.description", effectSummary: "All Marines gain max Aggression & faster deploy")
            ]),
            ZWTeamSynergyDefinition(faction: .builders, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.21.description", effectSummary: "Chance for a random Builder to enter free on deploy"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.21.description", effectSummary: "Guarantees bonus Builder on 3-unique lineup"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.22.description", effectSummary: "Damage increases per Builder on field")
            ]),
            ZWTeamSynergyDefinition(faction: .military, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.34.description", effectSummary: "Dodges first incoming ranged/leap attack"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.10.description", effectSummary: "SpecOps drops in when Military teammates fall"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.30.description", effectSummary: "Chance to nullify fatal damage once")
            ]),
            ZWTeamSynergyDefinition(faction: .tmf, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.35.description", effectSummary: "50% chance to resist Explosion damage"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.36.description", effectSummary: "Summons free random TMF unit once"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.35.description", effectSummary: "Reduces deploy Courage cost of random TMF unit by 5")
            ]),
            ZWTeamSynergyDefinition(faction: .emergency, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.40.description", effectSummary: "Fire & Poison resistance + Medkit bonus"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.40.description", effectSummary: "Allies near Medkit deal 2x damage"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.41.description", effectSummary: "Healing summons backup Emergency responder")
            ]),
            ZWTeamSynergyDefinition(faction: .psychos, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.32.description", effectSummary: "Critical hits have a 25% chance to drop Rage"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.33.description", effectSummary: "Picking up Rage grants Fury"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.32.description", effectSummary: "Critical hits generate double Rage")
            ]),
            ZWTeamSynergyDefinition(faction: .scientists, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.42.description", effectSummary: "Support Drone strikes fallen killer"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.42.description", effectSummary: "Drone blasts group upon enemy wave"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.43.description", effectSummary: "Damage increases per analyzed zombie type")
            ]),
            ZWTeamSynergyDefinition(faction: .ifForce, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.3.description", effectSummary: "Medkit lasts 50% longer"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.28.description", effectSummary: "Drops periodic Medkit on battlefield"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.29.description", effectSummary: "Enemies inside Medkit suffer damage over time")
            ]),
            ZWTeamSynergyDefinition(faction: .jailers, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.0.description", effectSummary: "Support Item cooldown reduced by 30%"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.38.description", effectSummary: "All Jailers stun enemies on critical hit"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.1.description", effectSummary: "All Unit preparation time reduced by 30%")
            ]),
            ZWTeamSynergyDefinition(faction: .northerners, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.13.description", effectSummary: "Guaranteed critical hit after each kill"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.23.description", effectSummary: "First attack is guaranteed Crit"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.24.description", effectSummary: "Critical damage scales per stack")
            ]),
            ZWTeamSynergyDefinition(faction: .patriots, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.31.description", effectSummary: "Fire & Molotov damage increased by 100%"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.37.description", effectSummary: "Burning enemies deal 30% less damage"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.44.description", effectSummary: "Chance to spawn fiery explosion on death")
            ]),
            ZWTeamSynergyDefinition(faction: .college, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.17.description", effectSummary: "Prevent teammates from turning into zombies on defeat"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.17.description", effectSummary: "+50 Charisma for College survivors"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.18.description", effectSummary: "Every 10 kills spawns a free College ally")
            ]),
            ZWTeamSynergyDefinition(faction: .prisoners, tiers: [
                ZWSynergyTier(requiredCount: 2, descriptionKey: "synergy.11.description", effectSummary: "Melee damage taken reduced by 50%"),
                ZWSynergyTier(requiredCount: 3, descriptionKey: "synergy.11.description", effectSummary: "Gain +25% Crit Damage per survivor"),
                ZWSynergyTier(requiredCount: 5, descriptionKey: "synergy.11.description", effectSummary: "Fearless frenzy boost")
            ])
        ]
    }

    // Evidence: GameSprites/Bus/*_bus_*.png
    private static func buildBusSkins() -> [ZWBusSkinDefinition] {
        return [
            ZWBusSkinDefinition(id: "yellow", displayName: "Classic School Bus", bodySpriteName: "yellow_bus_yellow_1", doorSpriteName: "yellow_bus_door_01", costSkinCoins: 0, perkText: "Standard survivor transport"),
            ZWBusSkinDefinition(id: "red", displayName: "Red Cruiser", bodySpriteName: "red_bus_red_1", doorSpriteName: "red_bus_door_01", costSkinCoins: 0, perkText: "Refurbished crimson coat"),
            ZWBusSkinDefinition(id: "blue", displayName: "Cobalt Transit", bodySpriteName: "blue_bus_blue_1", doorSpriteName: "blue_bus_door_01", costSkinCoins: 0, perkText: "Heavy highway paint"),
            ZWBusSkinDefinition(id: "black", displayName: "NightOps", bodySpriteName: "black_bus_black_1", doorSpriteName: "black_bus_door_01", costSkinCoins: 80, perkText: "Matte tactical armor finish"),
            ZWBusSkinDefinition(id: "gray", displayName: "Armored Steel", bodySpriteName: "gray_bus_gray_1", doorSpriteName: "gray_bus_door_01", costSkinCoins: 80, perkText: "Bare riveted plating"),
            ZWBusSkinDefinition(id: "deepblue", displayName: "Midnight Express", bodySpriteName: "deepblue_bus_deepblue_1", doorSpriteName: "deepblue_bus_door_01", costSkinCoins: 100, perkText: "Metro line livery"),
            ZWBusSkinDefinition(id: "olive", displayName: "Wasteland Olive", bodySpriteName: "olive_bus_olive_1", doorSpriteName: "olive_bus_door_01", costSkinCoins: 120, perkText: "Surplus camo coat"),
            ZWBusSkinDefinition(id: "military", displayName: "Military", bodySpriteName: "military_bus_military_1", doorSpriteName: "military_bus_door_01", costSkinCoins: 180, perkText: "Full army reinforced chassis"),
            ZWBusSkinDefinition(id: "specops", displayName: "SpecOps", bodySpriteName: "specops_bus_specops_1", doorSpriteName: "specops_bus_door_01", costSkinCoins: 240, perkText: "Special operations matte rig"),
            ZWBusSkinDefinition(id: "heist", displayName: "Jailbreak Heist", bodySpriteName: "heist_bus_heist_1", doorSpriteName: "heist_bus_door_01", costSkinCoins: 260, perkText: "Prison convoy armor"),
            ZWBusSkinDefinition(id: "metro", displayName: "Metro Shuttle", bodySpriteName: "metro_bus_metro_1", doorSpriteName: "metro_bus_door_01", costSkinCoins: 220, perkText: "Subway station runner"),
            ZWBusSkinDefinition(id: "circus", displayName: "Psychos Circus", bodySpriteName: "circus_bus_circus_1", doorSpriteName: "circus_bus_door_01", costSkinCoins: 250, perkText: "Carnival chaos stripes"),
            ZWBusSkinDefinition(id: "chicken", displayName: "Fast Food Wagon", bodySpriteName: "chicken_bus_chicken_1", doorSpriteName: "chicken_bus_door_01", costSkinCoins: 200, perkText: "Highway diner mobile"),
            ZWBusSkinDefinition(id: "halloween", displayName: "Haunted Coach", bodySpriteName: "halloween_bus_halloween_1", doorSpriteName: "halloween_bus_door_01", costSkinCoins: 300, perkText: "Spooky pumpkin harvest edition"),
            ZWBusSkinDefinition(id: "summer", displayName: "Coastline Surfer", bodySpriteName: "summer_bus_summer_1", doorSpriteName: "summer_bus_door_01", costSkinCoins: 200, perkText: "Sun-bleached coastal van"),
            ZWBusSkinDefinition(id: "christmas", displayName: "Winter Express", bodySpriteName: "christmas_bus_christmas_1", doorSpriteName: "christmas_bus_door_01", costSkinCoins: 250, perkText: "Holiday convoy"),
            ZWBusSkinDefinition(id: "xmas19", displayName: "Frostbite Bus", bodySpriteName: "xmas19_bus_xmas19_1", doorSpriteName: "xmas19_bus_door_01", costSkinCoins: 280, perkText: "Iced holiday edition")
        ]
    }

    // Evidence: GameSprites/UI/charm_*.png + Data/localization.json (charm.*)
    private static func buildCharms() -> [ZWCharmDefinition] {
        return [
            ZWCharmDefinition(id: "card", locNameKey: "charm.Card", rarity: .common, iconName: "charm_common_card", bonusSummary: "+6% Crit Chance", hpPercentBonus: 0, damagePercentBonus: 0.04, prepareReduction: 0),
            ZWCharmDefinition(id: "lighter", locNameKey: "charm.Lighter", rarity: .common, iconName: "charm_common_lighter", bonusSummary: "+8% Melee/Fire Damage", hpPercentBonus: 0, damagePercentBonus: 0.08, prepareReduction: 0),
            ZWCharmDefinition(id: "wrench", locNameKey: "charm.Wrench", rarity: .common, iconName: "charm_common_wrench", bonusSummary: "+8% HP, Faster Repair", hpPercentBonus: 0.08, damagePercentBonus: 0.02, prepareReduction: 0.5),
            ZWCharmDefinition(id: "baseball", locNameKey: "charm.Baseball", rarity: .epic, iconName: "charm_epic_baseball", bonusSummary: "+15% Damage & Knockback", hpPercentBonus: 0.05, damagePercentBonus: 0.15, prepareReduction: 0.5),
            ZWCharmDefinition(id: "dice", locNameKey: "charm.Dice", rarity: .epic, iconName: "charm_epic_dice", bonusSummary: "+14% Crit & -1.2s Prep", hpPercentBonus: 0.05, damagePercentBonus: 0.10, prepareReduction: 1.2),
            ZWCharmDefinition(id: "heart", locNameKey: "charm.Heart", rarity: .epic, iconName: "charm_epic_heart", bonusSummary: "+22% Max HP", hpPercentBonus: 0.22, damagePercentBonus: 0.04, prepareReduction: 0),
            ZWCharmDefinition(id: "duck", locNameKey: "charm.Duck", rarity: .legendary, iconName: "charm_legendary_duck", bonusSummary: "+18% HP, +18% Dmg, -2s Prep", hpPercentBonus: 0.18, damagePercentBonus: 0.18, prepareReduction: 2.0),
            ZWCharmDefinition(id: "headphones", locNameKey: "charm.Headphones", rarity: .legendary, iconName: "charm_legendary_headphones", bonusSummary: "+25% Ranged/Agility", hpPercentBonus: 0.10, damagePercentBonus: 0.25, prepareReduction: 1.5),
            ZWCharmDefinition(id: "manekineko", locNameKey: "charm.Manekineko", rarity: .legendary, iconName: "charm_legendary_manekineko", bonusSummary: "Lucky Fortune: +20% Stats", hpPercentBonus: 0.20, damagePercentBonus: 0.20, prepareReduction: 1.8)
        ]
    }

    private static func buildMetroStations() -> [ZWMetroStation] {
        return (1...12).map { station in
            let lvl = 6 + station * 2
            return ZWMetroStation(
                id: station,
                name: "Metro Station \(station)",
                recommendedPower: station * 180 + 250,
                barricadeHP: Double(500 + station * 280),
                waves: [
                    ZWWaveSpawnEntry(timeSeconds: 1.0, enemyID: station > 6 ? "z_alienNakedRun" : "z_nakedRun", count: 3 + station / 3, level: lvl),
                    ZWWaveSpawnEntry(timeSeconds: 7.0, enemyID: station > 4 ? "z_girlPrisoner" : "z_builder", count: 2 + station / 4, level: lvl),
                    ZWWaveSpawnEntry(timeSeconds: 14.0, enemyID: station > 8 ? "z_alienTwins" : "z_cop", count: 2, level: lvl + 1),
                    ZWWaveSpawnEntry(timeSeconds: 22.0, enemyID: station % 4 == 0 ? "z_hypnotist" : "z_insect", count: 3, level: lvl + 1)
                ],
                rewardCash: station % 3 == 0 ? 15 : 5,
                rewardMetroCoins: 40 + station * 15
            )
        }
    }
}
