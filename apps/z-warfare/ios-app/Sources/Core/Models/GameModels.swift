import Foundation

// Port of WebConfigParams (Type#5555), BattleParams (Type#5551), UnitStatsManager (Type#1115), SaveData (Type#4818)
// Evidence: assembly-csharp-classes.txt + Data/missions_locations.json + Data/localization.json

public enum ZWUnitClass: String, CaseIterable, Codable, Sendable {
    case fighter = "Fighter"
    case damager = "Damager"
    case heavyweight = "Heavyweight"
    case shooter = "Shooter"
    case shotgunner = "Shotgunner"
    case sniper = "Sniper"
    case support = "Support"

    public var badgeSymbol: String {
        switch self {
        case .fighter: return "figure.martial.arts"
        case .damager: return "hammer.fill"
        case .heavyweight: return "shield.fill"
        case .shooter: return "scope"
        case .shotgunner: return "flame.fill"
        case .sniper: return "viewfinder.circle.fill"
        case .support: return "cross.case.fill"
        }
    }
}

public enum ZWTeamFaction: String, CaseIterable, Codable, Identifiable, Sendable {
    case rednecks = "Rednecks"
    case mechanics = "Mechanics"
    case police = "Cops"
    case marines = "Marines"
    case military = "Military"
    case builders = "Builders"
    case emergency = "Emergency"
    case patriots = "Patriots"
    case ifForce = "IF"
    case scientists = "Epidemic"
    case college = "Faculty"
    case jailers = "Jailers"
    case tmf = "TMF"
    case psychos = "Psychos"
    case northerners = "North"
    case prisoners = "Prisoners"
    case delivery = "Delivery"
    case southerners = "Southerners"

    public var id: String { rawValue }

    public var locKey: String { "unitset.\(rawValue)" }
}

public enum ZWRarity: String, CaseIterable, Codable, Sendable {
    case common
    case rare
    case epic
    case legendary
}

public enum ZWDamageType: String, Codable, Sendable {
    case melee
    case ranged
    case fire
    case explosion
    case poison
    case freeze
}

public enum ZWCoinCurrency: String, Codable, Sendable {
    case courage
    case rage
}

public struct ZWUnitResistances: Codable, Hashable, Sendable {
    public let bulletResist: Double
    public let meleeResist: Double
    public let fireImmune: Bool
    public let poisonImmune: Bool
    public let explosionResist: Double
    public let knockbackResist: Double

    public static let none = ZWUnitResistances(
        bulletResist: 0,
        meleeResist: 0,
        fireImmune: false,
        poisonImmune: false,
        explosionResist: 0,
        knockbackResist: 0
    )
}

// Port of BattleUnitConfig / WebConfigParams unit stats schema
public struct ZWUnitDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: String            // e.g. "h_naked"
    public let locNameKey: String    // e.g. "unit.h_naked"
    public let locDescrKey: String   // e.g. "unit.description.h_naked"
    public let unitClass: ZWUnitClass
    public let faction: ZWTeamFaction
    public let currency: ZWCoinCurrency
    public let cost: Int
    public let prepareTime: Double
    public let baseHP: Double
    public let baseMeleeDamage: Double
    public let baseRangedDamage: Double
    public let attackRange: Double   // World meters (bus=0, barricade=100)
    public let moveSpeed: Double     // World meters / sec
    public let critChance: Double    // 0...1
    public let critDamage: Double    // multiplier e.g. 0.5 means +50%
    public let agility: Double       // 0...100
    public let aggression: Double    // 0...100
    public let charisma: Double      // 0...100
    public let valor: Double         // 0...100
    public let unlockCostCoins: Int
    public let unlockCostCash: Int
    public let requiredRank: Int
    public let resistances: ZWUnitResistances
    public let perkSummary: String
    public let specialAbilityDescr: String
    public let zombieCorpseID: String // e.g. "z_naked" if unit turns on death ("" if immune)
    public let skinIDs: [String]
}

public struct ZWSupportItemDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: String           // e.g. "item_red_barrel"
    public let locNameKey: String   // e.g. "unit.item_red_barrel"
    public let cost: Int            // Rage cost
    public let prepareTime: Double
    public let baseDamage: Double
    public let duration: Double
    public let radius: Double
    public let description: String
    public let unlockCostCoins: Int
}

public struct ZWEnemyDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: String           // e.g. "z_naked" or "b_crazy"
    public let locNameKey: String   // e.g. "zombiepedia.unit.name.z_naked"
    public let locDescrKey: String
    public let baseHP: Double
    public let damage: Double
    public let moveSpeed: Double
    public let attackRange: Double
    public let isDemon: Bool
    public let isMarauder: Bool
    public let resistances: ZWUnitResistances
    public let traits: [String]
    public let killMilestones: [Int]
}

// Evidence: Data/missions_locations.json ({id, x, y, location})
public struct ZWMissionCoordinate: Codable, Hashable, Sendable {
    public let id: Int
    public let x: Int
    public let y: Int
    public let location: Int
}

public struct ZWWaveSpawnEntry: Codable, Hashable, Sendable {
    public let timeSeconds: Double
    public let enemyID: String
    public let count: Int
    public let level: Int
}

public struct ZWMissionConfig: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let location: Int
    public let mapX: Int
    public let mapY: Int
    public let stageNumber: Int
    public let difficultyIndex: Int   // 0..5 -> Palette "Difficulty0"..."Difficulty5"
    public let fuelCost: Int
    public let barricadeHP: Double
    public let coinReward: Int
    public let xpReward: Int
    public let powerPointReward: Int
    public let weatherHazard: String? // "Rain", "Toxic Fog", "Heatwave", nil
    public let isBossMission: Bool
    public let isSupplyRun: Bool
    public let waves: [ZWWaveSpawnEntry]
}

public struct ZWSynergyTier: Codable, Hashable, Sendable {
    public let requiredCount: Int // 2, 3, 5
    public let descriptionKey: String
    public let effectSummary: String
}

public struct ZWTeamSynergyDefinition: Identifiable, Codable, Hashable, Sendable {
    public var id: String { faction.rawValue }
    public let faction: ZWTeamFaction
    public let tiers: [ZWSynergyTier]
}

public struct ZWBusSkinDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: String           // e.g. "yellow", "military", "heist"
    public let displayName: String
    public let bodySpriteName: String
    public let doorSpriteName: String
    public let costSkinCoins: Int
    public let perkText: String
}

public struct ZWCharmDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let locNameKey: String
    public let rarity: ZWRarity
    public let iconName: String
    public let bonusSummary: String
    public let hpPercentBonus: Double
    public let damagePercentBonus: Double
    public let prepareReduction: Double
}

public struct ZWDailyQuest: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let targetCount: Int
    public var progressCount: Int
    public let rewardCash: Int
    public let rewardCoins: Int
    public var claimed: Bool
}

public struct ZWMetroStation: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let recommendedPower: Int
    public let barricadeHP: Double
    public let waves: [ZWWaveSpawnEntry]
    public let rewardCash: Int
    public let rewardMetroCoins: Int
}

public struct ZWGearItem: Identifiable, Codable, Hashable, Sendable {
    public enum Slot: String, CaseIterable, Codable, Sendable {
        case cup = "Cup"
        case knife = "Knife"
        case watch = "Watch"
        case book = "Book"
    }

    public let id: String
    public let setName: String
    public let slot: Slot
    public let rarity: ZWRarity
    public let level: Int
    public let flatHP: Double
    public let flatDamage: Double
    public let percentCritChance: Double
    public let prepareSecondsDelta: Double
    public let costReduction: Int
    public let iconName: String
}

// Port of UnitStatsManager (Type#1115) telemetry reported in UnitStatsMenu after battle
public struct ZWBattleUnitTelemetry: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let spawnedCount: Int
    public let kills: Int
    public let totalDamageDealt: Double
}

public enum ZWBattleMode: String, Codable, Sendable {
    case campaign
    case supplyRun
    case skirmishPvP
    case metro
    case weeklyEvent
}

public struct ZWBattleOutcome: Codable, Sendable {
    public let mode: ZWBattleMode
    public let missionID: Int
    public let victory: Bool
    public let stars: Int
    public let durationSeconds: Double
    public let coinsEarned: Int
    public let cashEarned: Int
    public let powerPointsEarned: Int
    public let xpEarned: Int
    public let killCountsByEnemy: [String: Int]
    public let unitTelemetry: [ZWBattleUnitTelemetry]
}

// Port of SaveData (Type#4818) serialized by SaveGameService
public struct ZWSaveData: Codable, Sendable {
    public var playerRank: Int
    public var playerXP: Int
    public var coins: Int
    public var cash: Int
    public var fuel: Int
    public var maxFuel: Int
    public var lastFuelUpdateEpoch: TimeInterval
    public var blueKeys: Int
    public var redKeys: Int
    public var pvpCoins: Int
    public var metroCoins: Int
    public var skinCoins: Int
    public var charmPoints: Int
    public var powerPoints: Int

    public var busLevel: Int
    public var equippedBusSkinID: String
    public var unlockedBusSkinIDs: [String]
    public var busWheelLevel: Int
    public var busPipeLevel: Int
    public var busArmorLevel: Int

    public var deckUnitIDs: [String]          // Up to 6 slots (Units or Support Items)
    public var unitLevels: [String: Int]      // unitID -> 0...30
    public var specialUnlockedUnitIDs: [String]
    public var equippedSkins: [String: String]
    public var equippedCharms: [String: String]
    public var equippedGear: [String: [String: ZWGearItem]] // unitID -> slot.rawValue -> Gear

    public var missionStars: [Int: Int]       // missionID -> 1...3
    public var highestLocationUnlocked: Int
    public var metroClearedStation: Int
    public var zombiepediaKills: [String: Int]
    public var zombiepediaClaimed: [String]
    public var dailyQuests: [ZWDailyQuest]
    public var claimedStarMilestones: [Int]
    public var skirmishWins: Int

    public static func defaultNewGame() -> ZWSaveData {
        ZWSaveData(
            playerRank: 3,
            playerXP: 120,
            coins: 650,
            cash: 45,
            fuel: 20,
            maxFuel: 20,
            lastFuelUpdateEpoch: Date().timeIntervalSince1970,
            blueKeys: 4,
            redKeys: 1,
            pvpCoins: 150,
            metroCoins: 0,
            skinCoins: 120,
            charmPoints: 40,
            powerPoints: 1200,
            busLevel: 3,
            equippedBusSkinID: "yellow",
            unlockedBusSkinIDs: ["yellow", "red", "blue"],
            busWheelLevel: 2,
            busPipeLevel: 2,
            busArmorLevel: 2,
            deckUnitIDs: [
                "h_naked",
                "h_mechanic",
                "h_farmer",
                "h_judi",
                "item_red_barrel",
                "item_medkit"
            ],
            unitLevels: [
                "h_naked": 3,
                "h_mechanic": 3,
                "h_farmer": 2,
                "h_judi": 2,
                "h_builder": 2,
                "h_cop": 1,
                "item_red_barrel": 2,
                "item_medkit": 2
            ],
            specialUnlockedUnitIDs: [],
            equippedSkins: [:],
            equippedCharms: [:],
            equippedGear: [:],
            missionStars: [1: 3],
            highestLocationUnlocked: 1,
            metroClearedStation: 0,
            zombiepediaKills: [
                "z_naked": 18,
                "z_nakedRun": 9,
                "z_girl": 5
            ],
            zombiepediaClaimed: [],
            dailyQuests: [
                ZWDailyQuest(id: "dq_kills", title: "Eliminate 50 Infected", targetCount: 50, progressCount: 14, rewardCash: 5, rewardCoins: 120, claimed: false),
                ZWDailyQuest(id: "dq_missions", title: "Complete 2 Campaign Missions", targetCount: 2, progressCount: 1, rewardCash: 5, rewardCoins: 150, claimed: false),
                ZWDailyQuest(id: "dq_upgrade", title: "Upgrade a Survivor or the Bus", targetCount: 1, progressCount: 0, rewardCash: 3, rewardCoins: 100, claimed: false),
                ZWDailyQuest(id: "dq_barricade", title: "Destroy 2 Enemy Barricades", targetCount: 2, progressCount: 0, rewardCash: 5, rewardCoins: 200, claimed: false)
            ],
            claimedStarMilestones: [],
            skirmishWins: 0
        )
    }
}
