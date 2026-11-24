import SwiftUI
import SpriteKit

// Port of CampaignController Battle HUD + UnitStatsMenu + Victory/Defeat Modal
// Designed specifically for iPhone XS Max Landscape (896x414 pt @3x) with 44pt side safe-area awareness.
public struct ZWBattleView: View {
    @StateObject private var engine: ZWBattleEngine
    @State private var scene: ZWBattleScene
    @ObservedObject private var loc = ZWLocalizationService.shared
    @ObservedObject private var saveService = ZWSaveGameService.shared
    @State private var selectedTargetX: Double = 55.0
    @State private var showUnitStats = false
    @State private var committedOutcome = false

    public let onExit: () -> Void

    public init(mode: ZWBattleMode, mission: ZWMissionConfig, onExit: @escaping () -> Void) {
        let save = ZWSaveGameService.shared.data
        let eng = ZWBattleEngine(mode: mode, mission: mission, saveData: save)
        _engine = StateObject(wrappedValue: eng)
        _scene = State(initialValue: ZWBattleScene(engine: eng))
        self.onExit = onExit
    }

    public var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 60)
                .ignoresSafeArea()
                .onAppear {
                    scene.onWorldTapX = { x in
                        selectedTargetX = x
                    }
                    let track: ZWMusicTrack = {
                        switch engine.mode {
                        case .skirmishPvP: return .pvp
                        case .metro: return .metro
                        case .weeklyEvent: return .bridgeBattle
                        default: return .battle
                        }
                    }()
                    ZWSoundEngine.shared.playMusic(track)
                }

            VStack(spacing: 0) {
                topBattleHUD
                if engine.finalWaveTriggered && engine.outcome == nil {
                    finalWaveBanner
                }
                Spacer()
                bottomDeploymentHUD
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            if engine.isPaused && engine.outcome == nil {
                pauseOverlay
            }
            if let result = engine.outcome {
                outcomeOverlay(result)
            }
        }
        .onChange(of: engine.outcome?.victory) { _ in
            if let outcome = engine.outcome, !committedOutcome {
                committedOutcome = true
                saveService.recordBattleOutcome(outcome)
            }
        }
    }

    private var topBattleHUD: some View {
        HStack(spacing: 12) {
            // Left: Bus HP Bar
            HStack(spacing: 6) {
                ZWPixelSpriteView("yellow_bus_yellow_1", folder: .bus, fallbackSymbol: "bus.fill")
                    .frame(width: 28, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    ZWOutlineText("BUS HP \(Int(max(0, engine.busHP)))/\(Int(engine.busMaxHP))", palette: "GreenSolid", font: ZWTypography.mono(10))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.75))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ZWPalette.cashGreen)
                                .frame(width: geo.size.width * CGFloat(max(0, engine.busHP / max(1, engine.busMaxHP))))
                        }
                    }
                    .frame(width: 145, height: 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ZWPalette.hudBarBackground)
            .cornerRadius(6)

            // Center-Left: Bill Machine Gun active skill
            Button {
                _ = engine.activateBillBarrage()
            } label: {
                HStack(spacing: 4) {
                    ZWPixelSpriteView("h_busdriver_idle_00", folder: .bus, fallbackSymbol: "flame.fill")
                        .frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(engine.billCooldownRemaining > 0 ? "\(Int(ceil(engine.billCooldownRemaining)))s" : "BILL MG")
                            .font(ZWTypography.mono(10))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(ZWTacticalButtonStyle(tone: engine.billCooldownRemaining > 0 ? .slate : .gold, compact: true))
            .disabled(engine.billCooldownRemaining > 0)

            Spacer()

            // Active Team Synergies badges
            HStack(spacing: 4) {
                ForEach(engine.activeSynergies.sorted(by: { $0.value > $1.value }), id: \.key) { faction, count in
                    if count >= 2 {
                        Text("\(loc.text(faction.locKey, fallback: faction.rawValue)) \(count)")
                            .font(ZWTypography.mono(9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ZWPalette.coinGold.opacity(0.25))
                            .foregroundColor(ZWPalette.coinGold)
                            .cornerRadius(4)
                    }
                }
            }

            // Right: Barricade HP + Speed + Pause
            if engine.mode != .skirmishPvP {
                VStack(alignment: .trailing, spacing: 2) {
                    ZWOutlineText("BARRICADE \(Int(max(0, engine.barricadeHP)))", palette: "WarningMessage", font: ZWTypography.mono(10))
                    GeometryReader { geo in
                        ZStack(alignment: .trailing) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.75))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ZWPalette.dangerRed)
                                .frame(width: geo.size.width * CGFloat(max(0, engine.barricadeHP / max(1, engine.barricadeMaxHP))))
                        }
                    }
                    .frame(width: 140, height: 8)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ZWPalette.hudBarBackground)
                .cornerRadius(6)
            }

            Button {
                engine.toggleSpeed()
            } label: {
                Text(engine.speedMultiplier > 1.5 ? "2x" : "1x")
                    .font(ZWTypography.mono(11))
                    .foregroundColor(.white)
            }
            .buttonStyle(ZWTacticalButtonStyle(tone: engine.speedMultiplier > 1.5 ? .blue : .slate, compact: true))

            Button {
                engine.togglePause()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .buttonStyle(ZWTacticalButtonStyle(tone: .slate, compact: true))
        }
    }

    private var finalWaveBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("FINAL WAVE — HORDE APPROACHING")
                .font(ZWTypography.impact(12))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(ZWPalette.dangerRed.opacity(0.9))
        .cornerRadius(5)
        .padding(.top, 4)
    }

    private var bottomDeploymentHUD: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Left Gauges: Courage + Rage
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    ZWPixelSpriteView("bar_water", folder: .ui, fallbackSymbol: "drop.fill")
                        .frame(width: 18, height: 18)
                    ZWOutlineText("\(Int(engine.courage))", palette: "WaterColor", font: ZWTypography.impact(14))
                        .frame(width: 30, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.8))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ZWPalette.courageBlue)
                                .frame(width: geo.size.width * CGFloat(engine.courage / engine.maxCourage))
                        }
                    }
                    .frame(width: 70, height: 8)
                }

                HStack(spacing: 5) {
                    ZWPixelSpriteView("bar_rage", folder: .ui, fallbackSymbol: "flame.fill")
                        .frame(width: 18, height: 18)
                    ZWOutlineText("\(Int(engine.rage))", palette: "RageColor", font: ZWTypography.impact(14))
                        .frame(width: 30, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.8))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ZWPalette.ragePink)
                                .frame(width: geo.size.width * CGFloat(engine.rage / engine.maxRage))
                        }
                    }
                    .frame(width: 70, height: 8)
                }
            }
            .padding(8)
            .background(ZWPalette.hudBarBackground)
            .cornerRadius(8)

            // Center/Right: 6 Unit & Support Item Deployment Cards
            HStack(spacing: 7) {
                ForEach(Array(engine.cardSlots.enumerated()), id: \.element.id) { index, slot in
                    let hasResource = slot.currency == .courage
                        ? Int(engine.courage) >= slot.cost
                        : Int(engine.rage) >= slot.cost
                    let isReady = slot.remainingPrepare <= 0.01 && hasResource

                    Button {
                        _ = engine.deployCard(slotIndex: index, targetWorldX: selectedTargetX)
                    } label: {
                        ZStack(alignment: .bottom) {
                            VStack(spacing: 2) {
                                ZWPixelSpriteView(
                                    slot.id,
                                    folder: slot.isSupportItem ? .ui : .portraits,
                                    fallbackSymbol: "person.fill"
                                )
                                .frame(width: 48, height: 42)
                                .background(ZWPalette.tarmacDark)
                                .cornerRadius(4)

                                Text(slot.displayName)
                                    .font(ZWTypography.mono(8))
                                    .lineLimit(1)
                                    .foregroundColor(.white)
                                    .frame(width: 58)
                            }
                            .padding(4)
                            .background(ZWPalette.panelSlate)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(isReady ? (slot.currency == .courage ? ZWPalette.courageBlue : ZWPalette.ragePink) : ZWPalette.panelBorder, lineWidth: isReady ? 2 : 1)
                            )

                            // Cooldown veil
                            if slot.remainingPrepare > 0.01 {
                                GeometryReader { geo in
                                    let ratio = CGFloat(slot.remainingPrepare / max(0.1, slot.maxPrepareTime))
                                    Color.black.opacity(0.68)
                                        .frame(height: geo.size.height * ratio)
                                        .overlay(
                                            Text("\(Int(ceil(slot.remainingPrepare)))s")
                                                .font(ZWTypography.mono(10))
                                                .foregroundColor(.white)
                                        )
                                }
                                .cornerRadius(6)
                            }

                            // Top-left cost pill
                            VStack {
                                HStack {
                                    Text("\(slot.cost)")
                                        .font(ZWTypography.mono(9))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(slot.currency == .courage ? ZWPalette.courageBlue : ZWPalette.ragePink)
                                        .cornerRadius(3)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .padding(2)
                        }
                        .frame(width: 66, height: 68)
                        .opacity(hasResource ? 1.0 : 0.62)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isReady)
                }
            }
            Spacer()
        }
    }

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            ZWTacticalPanel {
                VStack(spacing: 14) {
                    ZWOutlineText("PAUSED", palette: "GoldSolid", font: ZWTypography.impact(20))
                    Text("Stage \(engine.mission.location)-\(engine.mission.stageNumber)")
                        .font(ZWTypography.body(13))
                        .foregroundColor(.white.opacity(0.85))
                    HStack(spacing: 12) {
                        Button("RESUME") {
                            engine.togglePause()
                        }
                        .buttonStyle(ZWTacticalButtonStyle(tone: .green))

                        Button("RETREAT") {
                            onExit()
                        }
                        .buttonStyle(ZWTacticalButtonStyle(tone: .red))
                    }
                }
                .padding(20)
            }
            .frame(width: 280)
        }
    }

    private func outcomeOverlay(_ result: ZWBattleOutcome) -> some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            ZWTacticalPanel(borderColor: result.victory ? ZWPalette.coinGold : ZWPalette.dangerRed) {
                VStack(spacing: 10) {
                    ZWOutlineText(
                        result.victory ? "MISSION COMPLETE!" : "BUS DESTROYED",
                        palette: result.victory ? "GoldSolid" : "WarningMessage",
                        font: ZWTypography.impact(20)
                    )

                    if result.victory {
                        HStack(spacing: 8) {
                            ForEach(1...3, id: \.self) { starIdx in
                                Image(systemName: starIdx <= result.stars ? "star.fill" : "star")
                                    .font(.system(size: 22))
                                    .foregroundColor(starIdx <= result.stars ? ZWPalette.coinGold : .gray)
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        Label("+\(result.coinsEarned)", systemImage: "dollarsign.circle.fill")
                            .foregroundColor(ZWPalette.coinGold)
                        Label("+\(result.powerPointsEarned) PP", systemImage: "bolt.fill")
                            .foregroundColor(ZWPalette.courageBlue)
                        Label("+\(result.xpEarned) XP", systemImage: "sparkles")
                            .foregroundColor(.white)
                    }
                    .font(ZWTypography.mono(12))

                    if showUnitStats {
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(result.unitTelemetry) { stat in
                                    HStack {
                                        Text(stat.displayName)
                                            .font(ZWTypography.body(11))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("DMG \(Int(stat.totalDamageDealt)) • KILLS \(stat.kills)")
                                            .font(ZWTypography.mono(10))
                                            .foregroundColor(ZWPalette.coinGold)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.35))
                                    .cornerRadius(4)
                                }
                            }
                        }
                        .frame(height: 92)
                    }

                    HStack(spacing: 12) {
                        Button(showUnitStats ? "HIDE STATS" : "UNIT STATS") {
                            showUnitStats.toggle()
                        }
                        .buttonStyle(ZWTacticalButtonStyle(tone: .blue, compact: true))

                        Button("CONTINUE") {
                            ZWSoundEngine.shared.playMusic(.menu)
                            onExit()
                        }
                        .buttonStyle(ZWTacticalButtonStyle(tone: result.victory ? .green : .gold))
                    }
                }
                .padding(18)
            }
            .frame(width: 390)
        }
    }
}
