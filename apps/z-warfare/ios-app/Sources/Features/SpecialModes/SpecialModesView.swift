import SwiftUI

// Port of PVPMenu (Skirmish), MetroController (12 Stations), and BridgeGameplayController / Weekly Events
public struct ZWSpecialModesView: View {
    @ObservedObject private var save = ZWSaveGameService.shared
    private let catalog = ZWGameCatalog.shared

    public let onLaunchMode: (ZWBattleMode, ZWMissionConfig) -> Void

    public init(onLaunchMode: @escaping (ZWBattleMode, ZWMissionConfig) -> Void) {
        self.onLaunchMode = onLaunchMode
    }

    public var body: some View {
        HStack(spacing: 10) {
            // 1. Skirmish PvP Arena
            ZWTacticalPanel(borderColor: ZWPaletteStore.shared.entry(named: "PvpSolid").fillColor) {
                VStack(alignment: .leading, spacing: 8) {
                    ZWOutlineText("SKIRMISH PvP ARENA", palette: "PvpSolid", font: ZWTypography.impact(14))
                    ZWPixelSpriteView("bar_pvpcoins", folder: .ui, fallbackSymbol: "shield.lefthalf.filled")
                        .frame(width: 44, height: 44)
                    Text("6v6 survivor arena combat using your equipped Battle Deck against rival squads.")
                        .font(ZWTypography.body(10))
                        .foregroundColor(.white.opacity(0.85))
                    Text("Season Wins: \(save.data.skirmishWins) • PvP Coins: \(save.data.pvpCoins)")
                        .font(ZWTypography.mono(10))
                        .foregroundColor(ZWPalette.coinGold)
                    Spacer()
                    Button("ENTER SKIRMISH") {
                        let skirmishMission = ZWMissionConfig(
                            id: 9001,
                            location: 4,
                            mapX: 0,
                            mapY: 0,
                            stageNumber: 1,
                            difficultyIndex: 2,
                            fuelCost: 0,
                            barricadeHP: 1,
                            coinReward: 160,
                            xpReward: 40,
                            powerPointReward: 65,
                            weatherHazard: nil,
                            isBossMission: false,
                            isSupplyRun: false,
                            waves: []
                        )
                        onLaunchMode(.skirmishPvP, skirmishMission)
                    }
                    .buttonStyle(ZWTacticalButtonStyle(tone: .blue))
                }
                .padding(12)
            }
            .frame(width: 225)

            // 2. Infected Metro (12 Stations)
            ZWTacticalPanel(borderColor: ZWPalette.metroPurple) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        ZWOutlineText("INFECTED METRO", palette: "MagentaSolid", font: ZWTypography.impact(14))
                        Spacer()
                        Text("Cleared: \(save.data.metroClearedStation)/12")
                            .font(ZWTypography.mono(9))
                            .foregroundColor(.white)
                    }
                    ScrollView {
                        VStack(spacing: 5) {
                            ForEach(catalog.metroStations) { st in
                                let cleared = st.id <= save.data.metroClearedStation
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(st.name)
                                            .font(ZWTypography.body(11))
                                            .foregroundColor(.white)
                                        Text("Reward: +\(st.rewardMetroCoins) Metro • +\(st.rewardCash) Cash")
                                            .font(ZWTypography.mono(9))
                                            .foregroundColor(ZWPalette.coinGold)
                                    }
                                    Spacer()
                                    Button(cleared ? "REPLAY" : "RAID") {
                                        let cfg = ZWMissionConfig(
                                            id: 8000 + st.id,
                                            location: 6,
                                            mapX: 0,
                                            mapY: 0,
                                            stageNumber: st.id,
                                            difficultyIndex: min(5, st.id / 2),
                                            fuelCost: 0,
                                            barricadeHP: st.barricadeHP,
                                            coinReward: 180 + st.id * 25,
                                            xpReward: 55,
                                            powerPointReward: 95,
                                            weatherHazard: "Subway Tunnel",
                                            isBossMission: st.id == 12,
                                            isSupplyRun: false,
                                            waves: st.waves
                                        )
                                        onLaunchMode(.metro, cfg)
                                    }
                                    .buttonStyle(ZWTacticalButtonStyle(tone: .purple, compact: true))
                                }
                                .padding(7)
                                .background(ZWPalette.tarmacDark)
                                .cornerRadius(5)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .frame(maxWidth: .infinity)

            // 3. Weekly Event / Highway Bridge
            ZWTacticalPanel(borderColor: ZWPalette.hazardOrange) {
                VStack(alignment: .leading, spacing: 8) {
                    ZWOutlineText("WEEKLY BRIDGE EVENT", palette: "WarningMessage", font: ZWTypography.impact(13))
                    ZWPixelSpriteView("loc_bridge_0_bridge_bg_03", folder: .backgrounds, contentMode: .fill)
                        .frame(height: 80)
                        .clipped()
                        .cornerRadius(5)
                    Text("Push across the collapsed highway bridge through armored marauders and alien waves.")
                        .font(ZWTypography.body(10))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Button("PLAY BRIDGE") {
                        let cfg = ZWMissionConfig(
                            id: 7001,
                            location: 7,
                            mapX: 0,
                            mapY: 0,
                            stageNumber: 1,
                            difficultyIndex: 3,
                            fuelCost: 0,
                            barricadeHP: 950,
                            coinReward: 260,
                            xpReward: 70,
                            powerPointReward: 120,
                            weatherHazard: "Bridge Crosswind",
                            isBossMission: true,
                            isSupplyRun: false,
                            waves: [
                                ZWWaveSpawnEntry(timeSeconds: 1.5, enemyID: "b_crazy", count: 3, level: 8),
                                ZWWaveSpawnEntry(timeSeconds: 8.0, enemyID: "b_farmer", count: 2, level: 8),
                                ZWWaveSpawnEntry(timeSeconds: 16.0, enemyID: "b_alienBuilder", count: 2, level: 9),
                                ZWWaveSpawnEntry(timeSeconds: 26.0, enemyID: "z_boss", count: 1, level: 10)
                            ]
                        )
                        onLaunchMode(.weeklyEvent, cfg)
                    }
                    .buttonStyle(ZWTacticalButtonStyle(tone: .gold))
                }
                .padding(12)
            }
            .frame(width: 225)
        }
    }
}
