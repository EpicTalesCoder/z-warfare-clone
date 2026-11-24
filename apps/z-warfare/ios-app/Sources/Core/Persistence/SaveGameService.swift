import Foundation
import Combine

// Port of SaveGameService + SaveGameJsonLoader (0x03bb3760)
// Persistent local JSON owner storing currencies, decks, unit upgrades, mission stars, quests, and Fuel regeneration.
public final class ZWSaveGameService: ObservableObject {
    public static let shared = ZWSaveGameService()

    @Published public var data: ZWSaveData

    private let fileURL: URL
    private let fuelRegenIntervalSeconds: TimeInterval = 720 // 1 Fuel per 12 min

    public init(storageURL: URL? = nil) {
        if let custom = storageURL {
            self.fileURL = custom
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let dir = appSupport.appendingPathComponent("ZWarfare", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("save_data_v1.json")
        }

        if let raw = try? Data(contentsOf: self.fileURL),
           let decoded = try? JSONDecoder().decode(ZWSaveData.self, from: raw) {
            self.data = decoded
        } else {
            self.data = ZWSaveData.defaultNewGame()
        }
        refreshFuelTimer()
    }

    public func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let encoded = try? encoder.encode(data) {
            try? encoded.write(to: fileURL, options: [.atomic])
        }
    }

    public func resetSave() {
        data = ZWSaveData.defaultNewGame()
        save()
    }

    public func exportJSONString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let encoded = try? encoder.encode(data),
              let str = String(data: encoded, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    @discardableResult
    public func importJSONString(_ jsonString: String) -> Bool {
        guard let raw = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ZWSaveData.self, from: raw) else {
            return false
        }
        data = decoded
        save()
        return true
    }

    public func refreshFuelTimer(now: Date = Date()) {
        let elapsed = max(0, now.timeIntervalSince1970 - data.lastFuelUpdateEpoch)
        let ticks = Int(elapsed / fuelRegenIntervalSeconds)
        if ticks > 0 {
            data.fuel = min(data.maxFuel, data.fuel + ticks)
            data.lastFuelUpdateEpoch += Double(ticks) * fuelRegenIntervalSeconds
            save()
        }
    }

    public var totalStars: Int {
        data.missionStars.values.reduce(0, +)
    }

    public func unitLevel(for id: String) -> Int {
        data.unitLevels[id] ?? 0
    }

    public func isOwned(_ id: String) -> Bool {
        (data.unitLevels[id] ?? 0) > 0
    }

    public func unlockUnit(_ def: ZWUnitDefinition) -> Bool {
        guard !isOwned(def.id) else { return false }
        if def.unlockCostCash > 0 {
            guard data.cash >= def.unlockCostCash else { return false }
            data.cash -= def.unlockCostCash
        } else {
            guard data.coins >= def.unlockCostCoins else { return false }
            data.coins -= def.unlockCostCoins
        }
        data.unitLevels[def.id] = 1
        save()
        return true
    }

    public func unlockSupportItem(_ item: ZWSupportItemDefinition) -> Bool {
        guard !isOwned(item.id) else { return false }
        guard data.coins >= item.unlockCostCoins else { return false }
        data.coins -= item.unlockCostCoins
        data.unitLevels[item.id] = 1
        save()
        return true
    }

    public func upgradeCost(currentLevel: Int) -> (coins: Int, powerPoints: Int) {
        let coins = 50 + currentLevel * 45 + (currentLevel >= 15 ? (currentLevel - 14) * 65 : 0)
        let pp = 25 + currentLevel * 20
        return (coins, pp)
    }

    public func upgradeUnit(_ id: String) -> Bool {
        let cur = unitLevel(for: id)
        guard cur >= 1, cur < 30 else { return false }
        let cost = upgradeCost(currentLevel: cur)
        guard data.coins >= cost.coins, data.powerPoints >= cost.powerPoints else { return false }
        data.coins -= cost.coins
        data.powerPoints -= cost.powerPoints
        data.unitLevels[id] = cur + 1
        incrementQuest(id: "dq_upgrade", by: 1)
        save()
        return true
    }

    public func unlockSpecialAbility(for id: String) -> Bool {
        guard unitLevel(for: id) >= 30,
              !data.specialUnlockedUnitIDs.contains(id),
              data.coins >= 10_000 else { return false }
        data.coins -= 10_000
        data.specialUnlockedUnitIDs.append(id)
        save()
        return true
    }

    public func toggleDeckUnit(_ id: String) {
        guard isOwned(id) else { return }
        if let idx = data.deckUnitIDs.firstIndex(of: id) {
            if data.deckUnitIDs.count > 1 {
                data.deckUnitIDs.remove(at: idx)
            }
        } else if data.deckUnitIDs.count < 6 {
            data.deckUnitIDs.append(id)
        }
        save()
    }

    public func busUpgradeCost(level: Int) -> Int {
        120 + level * 95
    }

    public func upgradeBus() -> Bool {
        guard data.busLevel < 30 else { return false }
        let cost = busUpgradeCost(level: data.busLevel)
        guard data.coins >= cost else { return false }
        data.coins -= cost
        data.busLevel += 1
        incrementQuest(id: "dq_upgrade", by: 1)
        save()
        return true
    }

    public func selectOrUnlockBusSkin(_ skin: ZWBusSkinDefinition) -> Bool {
        if data.unlockedBusSkinIDs.contains(skin.id) {
            data.equippedBusSkinID = skin.id
            save()
            return true
        }
        guard data.skinCoins >= skin.costSkinCoins else { return false }
        data.skinCoins -= skin.costSkinCoins
        data.unlockedBusSkinIDs.append(skin.id)
        data.equippedBusSkinID = skin.id
        save()
        return true
    }

    public func equipCharm(_ charmID: String?, for unitID: String) {
        if let cid = charmID {
            data.equippedCharms[unitID] = cid
        } else {
            data.equippedCharms.removeValue(forKey: unitID)
        }
        save()
    }

    public func equipStarterGear(setName: String, slot: ZWGearItem.Slot, for unitID: String) {
        let item = ZWGearItem(
            id: "\(setName)_\(slot.rawValue)_\(Int.random(in: 100...999))",
            setName: setName,
            slot: slot,
            rarity: .epic,
            level: 6,
            flatHP: slot == .cup ? 45 : 12,
            flatDamage: slot == .knife ? 18 : 6,
            percentCritChance: slot == .book ? 0.10 : 0.03,
            prepareSecondsDelta: slot == .watch ? -1.5 : 0,
            costReduction: slot == .watch ? 1 : 0,
            iconName: "epic_firefighter_\(slot.rawValue.lowercased())"
        )
        var slots = data.equippedGear[unitID] ?? [:]
        slots[slot.rawValue] = item
        data.equippedGear[unitID] = slots
        save()
    }

    public func spendFuel(_ amount: Int) -> Bool {
        refreshFuelTimer()
        guard data.fuel >= amount else { return false }
        data.fuel -= amount
        save()
        return true
    }

    public func recordBattleOutcome(_ outcome: ZWBattleOutcome) {
        data.coins += outcome.coinsEarned
        data.cash += outcome.cashEarned
        data.powerPoints += outcome.powerPointsEarned
        addXP(outcome.xpEarned)

        var totalKills = 0
        for (enemyID, count) in outcome.killCountsByEnemy {
            data.zombiepediaKills[enemyID, default: 0] += count
            totalKills += count
        }
        incrementQuest(id: "dq_kills", by: totalKills)

        if outcome.victory {
            switch outcome.mode {
            case .campaign, .supplyRun:
                let prev = data.missionStars[outcome.missionID] ?? 0
                if outcome.stars > prev {
                    data.missionStars[outcome.missionID] = outcome.stars
                }
                let loc = max(1, outcome.missionID / 100)
                if outcome.missionID == 1 && data.highestLocationUnlocked < 2 {
                    data.highestLocationUnlocked = 2
                } else if loc >= data.highestLocationUnlocked && data.highestLocationUnlocked < 10 {
                    data.highestLocationUnlocked = min(10, loc + 1)
                }
                incrementQuest(id: "dq_missions", by: 1)
                incrementQuest(id: "dq_barricade", by: 1)
            case .metro:
                if outcome.missionID > data.metroClearedStation {
                    data.metroClearedStation = outcome.missionID
                }
                data.metroCoins += 50 + outcome.missionID * 12
            case .skirmishPvP:
                data.skirmishWins += 1
                data.pvpCoins += 35
            case .weeklyEvent:
                data.powerPoints += 80
            }
        }
        save()
    }

    public func claimDailyQuest(id: String) {
        guard let idx = data.dailyQuests.firstIndex(where: { $0.id == id }) else { return }
        var quest = data.dailyQuests[idx]
        guard !quest.claimed, quest.progressCount >= quest.targetCount else { return }
        quest.claimed = true
        data.dailyQuests[idx] = quest
        data.cash += quest.rewardCash
        data.coins += quest.rewardCoins
        save()
    }

    public func claimZombiepediaReward(for enemyID: String) -> Int {
        guard !data.zombiepediaClaimed.contains(enemyID) else { return 0 }
        let kills = data.zombiepediaKills[enemyID] ?? 0
        guard kills >= 1 else { return 0 }
        data.zombiepediaClaimed.append(enemyID)
        let reward = 3
        data.cash += reward
        save()
        return reward
    }

    private func incrementQuest(id: String, by amount: Int) {
        guard amount > 0, let idx = data.dailyQuests.firstIndex(where: { $0.id == id }) else { return }
        data.dailyQuests[idx].progressCount = min(
            data.dailyQuests[idx].targetCount,
            data.dailyQuests[idx].progressCount + amount
        )
    }

    private func addXP(_ amount: Int) {
        data.playerXP += amount
        while data.playerXP >= xpThreshold(forRank: data.playerRank) {
            data.playerXP -= xpThreshold(forRank: data.playerRank)
            data.playerRank += 1
            data.fuel = data.maxFuel
            data.cash += 5
        }
    }

    public func xpThreshold(forRank rank: Int) -> Int {
        100 + rank * 65
    }
}
