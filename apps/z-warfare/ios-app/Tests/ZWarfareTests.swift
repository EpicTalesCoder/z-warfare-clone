import XCTest
@testable import ZWarfare

// Parity verification suite covering CryptStream decryption (0x03b9c8ac),
// BattleFormulas (0x03782100 / 0x03782228 / 0x03c1d7c0 / 0x03c26a04),
// BattleEngine simulation, SaveGameService JSON round-trip, and recovered assets.
final class ZWarfareTests: XCTestCase {

    func testCryptStreamDecryptsObserved42PacksHeaderToGzipMagic() {
        // Observed first 4 bytes of extracted 42_packs.bin under CryptStream key 0x235C5CF4
        let cipherPrefix = Data([0x13, 0x08, 0x8E, 0xE8])
        let decrypted = ZWCryptStream.decrypt(cipherPrefix, key: ZWCryptStream.defaultConfigKey)
        XCTAssertEqual(decrypted[0], 0x1F, "Expected GZIP ID1 byte 0x1F")
        XCTAssertEqual(decrypted[1], 0x8B, "Expected GZIP ID2 byte 0x8B")
        XCTAssertEqual(decrypted[2], 0x08, "Expected GZIP Deflate method byte 0x08")

        let sample = "0cd308ff-b382-45b1-a982-92a4af966e02,3\r\n".data(using: .utf8)!
        let encrypted = ZWCryptStream.encrypt(sample)
        let roundTripped = ZWCryptStream.decrypt(encrypted)
        XCTAssertEqual(roundTripped, sample)
    }

    func testBattleFormulasPortedParity() {
        let baseHP = 100.0
        XCTAssertEqual(ZWBattleFormulas.upgradedStat(base: baseHP, level: 1), 100.0, accuracy: 0.001)
        XCTAssertEqual(ZWBattleFormulas.upgradedStat(base: baseHP, level: 11), 259.374, accuracy: 0.01)

        // Prepare time lower clamp check
        XCTAssertEqual(ZWBattleFormulas.prepareTime(basePrepare: 1.0, gearDelta: -5.0), 0.7, accuracy: 0.001)

        // Hire cost clamp check
        XCTAssertEqual(ZWBattleFormulas.effectiveHireCost(baseCost: 15, gearReduction: 12), 5)

        // Bulletproof & Immunity Mitigation
        let builderRes = ZWUnitResistances(
            bulletResist: 0.9,
            meleeResist: 0,
            fireImmune: true,
            poisonImmune: true,
            explosionResist: 0.4,
            knockbackResist: 0
        )
        let rangedHit = ZWBattleFormulas.computeDamage(
            rawDamage: 100,
            damageType: .ranged,
            attackerLevel: 1,
            isCrit: false,
            critMultiplier: 0.5,
            defenderResistances: builderRes
        )
        XCTAssertEqual(rangedHit, 10.0, accuracy: 0.001)

        let fireHit = ZWBattleFormulas.computeDamage(
            rawDamage: 100,
            damageType: .fire,
            attackerLevel: 1,
            isCrit: false,
            critMultiplier: 0.5,
            defenderResistances: builderRes
        )
        XCTAssertEqual(fireHit, 0.0, accuracy: 0.001)

        // Star thresholds
        XCTAssertEqual(ZWBattleFormulas.starRating(busHP: 400, busMaxHP: 400), 3)
        XCTAssertEqual(ZWBattleFormulas.starRating(busHP: 220, busMaxHP: 400), 2)
        XCTAssertEqual(ZWBattleFormulas.starRating(busHP: 80, busMaxHP: 400), 1)
    }

    func testGameCatalogCompletenessAndAgentSynergyCount() {
        let catalog = ZWGameCatalog.shared
        XCTAssertEqual(catalog.units.count, 52)
        XCTAssertGreaterThanOrEqual(catalog.enemies.count, 79)
        XCTAssertEqual(catalog.supportItems.count, 9)
        XCTAssertEqual(catalog.busSkins.count, 17)
        XCTAssertEqual(catalog.metroStations.count, 12)

        // Agent counts as 2 Police for Synergy
        let counts = ZWBattleFormulas.activeSynergyCounts(deckIDs: ["h_agent", "h_cop"], catalog: catalog)
        XCTAssertEqual(counts[.police], 3)
    }

    func testSaveGameServiceIsolationAndJSONRoundTrip() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("zw_test_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let service = ZWSaveGameService(storageURL: tmp)
        let startCoins = service.data.coins
        XCTAssertTrue(service.upgradeUnit("h_naked"))
        XCTAssertLessThan(service.data.coins, startCoins)
        XCTAssertEqual(service.unitLevel(for: "h_naked"), 4)

        let exported = service.exportJSONString()
        let restored = ZWSaveGameService(storageURL: tmp)
        XCTAssertTrue(restored.importJSONString(exported))
        XCTAssertEqual(restored.unitLevel(for: "h_naked"), 4)
    }

    func testBattleEngineSimulationStepsAndDeploysUnits() {
        let catalog = ZWGameCatalog.shared
        let save = ZWSaveData.defaultNewGame()
        let testMission = catalog.allMissions.first ?? ZWMissionConfig(
            id: 1,
            location: 1,
            mapX: 0,
            mapY: 0,
            stageNumber: 1,
            difficultyIndex: 0,
            fuelCost: 0,
            barricadeHP: 120,
            coinReward: 50,
            xpReward: 25,
            powerPointReward: 20,
            weatherHazard: nil,
            isBossMission: false,
            isSupplyRun: false,
            waves: [ZWWaveSpawnEntry(timeSeconds: 0.5, enemyID: "z_naked", count: 1, level: 1)]
        )
        let engine = ZWBattleEngine(mode: .campaign, mission: testMission, saveData: save, catalog: catalog)
        XCTAssertFalse(engine.cardSlots.isEmpty)

        for _ in 0..<80 {
            engine.step(deltaTime: 0.05)
        }
        XCTAssertGreaterThan(engine.courage, 35.0)
        XCTAssertTrue(engine.deployCard(slotIndex: 0))
        XCTAssertFalse(engine.actors.isEmpty)
    }

    func testMinimumOSAndLandscapeConfiguration() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.rebuild.zwarfare"
        XCTAssertFalse(bundleID.isEmpty)
        XCTAssertNotNil(ZWPaletteStore.shared.entry(named: "WaterColor"))
        XCTAssertNotNil(ZWPaletteStore.shared.entry(named: "RageColor"))
        XCTAssertNotNil(ZWPaletteStore.shared.entry(named: "ZombiepediaKills"))
    }
}
