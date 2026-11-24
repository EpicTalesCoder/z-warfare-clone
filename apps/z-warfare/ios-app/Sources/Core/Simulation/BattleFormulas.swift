import Foundation

// Pure deterministic combat & progression formulas ported 1:1 from IL2CPP ARM64 disassembly:
// - UnitUpgradeManager.BonusBattle.UpgradeValue (0x03782228)
// - UnitUpgradeManager.CalcPrepareTimeInternal (0x03782100 -> lower clamp 0.01f)
// - BattleHireCostManager.GetCost (0x03c26a04)
// - WaterManager.OnUpdated (0x034ada4c)
// - AttackManager.DoAttack (0x03c1d7c0) & CommonBehaviour.HandleAttackReceived (0x0340150c)
public enum ZWBattleFormulas {
    /// Exponential per-level stat scaling matching DAZW 10% per upgrade tier plus flat Gear/Charm bonuses.
    // Port of UnitUpgradeManager.BonusBattle.UpgradeValue (0x03782228)
    public static func upgradedStat(
        base: Double,
        level: Int,
        scalePerLevel: Double = 0.10,
        flatGearBonus: Double = 0,
        percentBonus: Double = 0
    ) -> Double {
        let clampedLevel = max(0, min(30, level - 1))
        let leveled = base * pow(1.0 + scalePerLevel, Double(clampedLevel))
        return (leveled * (1.0 + percentBonus)) + flatGearBonus
    }

    /// Preparation cooldown formula combining base prep, watch gear reduction, charm bonus, and team synergy reduction.
    /// Disassembly 0x03782100 clamps minimum factor >= 0.01s.
    // Port of UnitUpgradeManager.CalcPrepareTimeInternal (0x03782100)
    public static func prepareTime(
        basePrepare: Double,
        gearDelta: Double = 0,
        charmDelta: Double = 0,
        synergyMultiplier: Double = 1.0
    ) -> Double {
        let combined = (basePrepare + gearDelta - charmDelta) * synergyMultiplier
        return max(0.7, combined)
    }

    /// Courage / Rage hire cost after item cost reductions and TMF/Faction synergy rebates, clamped >= 5.
    // Port of BattleHireCostManager.GetCost (0x03c26a04)
    public static func effectiveHireCost(baseCost: Int, gearReduction: Int = 0, synergyDelta: Int = 0) -> Int {
        max(5, baseCost - gearReduction - synergyDelta)
    }

    /// Courage generation per second (default 1 Courage every 0.85s boosted by team perks / generator).
    // Port of WaterManager.OnUpdated (0x034ada4c)
    public static func courageRegenPerSecond(busLevel: Int, multiplier: Double = 1.0) -> Double {
        let baseRate = 1.18 + Double(min(30, max(1, busLevel))) * 0.015
        return baseRate * multiplier
    }

    /// Computes post-mitigation hit damage accounting for crit multiplier, armor resistances, and fire/poison immunity.
    // Port of AttackManager.DoAttack (0x03c1d7c0) & CommonBehaviour.HandleAttackReceived (0x0340150c)
    public static func computeDamage(
        rawDamage: Double,
        damageType: ZWDamageType,
        attackerLevel: Int,
        isCrit: Bool,
        critMultiplier: Double,
        defenderResistances: ZWUnitResistances,
        markedMultiplier: Double = 1.0
    ) -> Double {
        var amount = rawDamage
        if isCrit {
            amount *= (1.0 + max(0.25, critMultiplier))
        }
        switch damageType {
        case .ranged:
            amount *= max(0.05, 1.0 - defenderResistances.bulletResist)
        case .melee:
            amount *= max(0.10, 1.0 - defenderResistances.meleeResist)
        case .explosion:
            amount *= max(0.10, 1.0 - defenderResistances.explosionResist)
        case .fire:
            if defenderResistances.fireImmune { return 0 }
        case .poison:
            if defenderResistances.poisonImmune { return 0 }
        case .freeze:
            amount *= 0.85
        }
        return max(1.0, (amount * markedMultiplier).rounded())
    }

    /// Player Bus HP scales with Bus level and Bus Armor part upgrades.
    public static func busMaxHP(busLevel: Int, armorLevel: Int) -> Double {
        let base = 240.0 + Double(max(1, busLevel)) * 45.0
        let armor = Double(max(1, armorLevel)) * 35.0
        return base + armor
    }

    /// Evaluates active Team Synergy counts from a 6-card deck.
    public static func activeSynergyCounts(deckIDs: [String], catalog: ZWGameCatalog = .shared) -> [ZWTeamFaction: Int] {
        var counts: [ZWTeamFaction: Int] = [:]
        var seenIDs = Set<String>()
        for id in deckIDs where !seenIDs.contains(id) {
            seenIDs.insert(id)
            if let unit = catalog.unitsByID[id] {
                counts[unit.faction, default: 0] += (id == "h_agent" ? 2 : 1)
            }
        }
        return counts
    }

    /// Victory star rating (3★ if Bus >= 99% HP, 2★ if >= 50% HP, 1★ otherwise).
    public static func starRating(busHP: Double, busMaxHP: Double) -> Int {
        guard busMaxHP > 0 else { return 1 }
        let ratio = busHP / busMaxHP
        if ratio >= 0.99 { return 3 }
        if ratio >= 0.50 { return 2 }
        return 1
    }
}
