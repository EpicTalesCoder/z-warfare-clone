import SwiftUI

// Port of MapMenuManager (Type#4440) + Location 1..10 highway nodes (missions_locations.json)
public struct ZWWorldMapView: View {
    @ObservedObject private var save = ZWSaveGameService.shared
    @ObservedObject private var loc = ZWLocalizationService.shared
    private let catalog = ZWGameCatalog.shared

    @State private var selectedLocation: Int = 1
    @State private var selectedMission: ZWMissionConfig?
    @State private var fuelAlert = false

    public let onLaunchMission: (ZWBattleMode, ZWMissionConfig) -> Void

    public init(onLaunchMission: @escaping (ZWBattleMode, ZWMissionConfig) -> Void) {
        self.onLaunchMission = onLaunchMission
    }

    public var body: some View {
        HStack(spacing: 10) {
            // Left: Interactive Location 1..10 Highway Map Canvas
            VStack(spacing: 6) {
                locationSelectorBar
                missionMapCanvas
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Right: Selected Mission Briefing Card
            missionBriefingPanel
                .frame(width: 245)
        }
        .onAppear {
            if selectedMission == nil {
                selectedMission = (catalog.missionsByLocation[selectedLocation] ?? []).first
            }
        }
        .alert("Not Enough Fuel", isPresented: $fuelAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Wait for automatic fuel regeneration (1 Fuel every 12 minutes) or claim quests/shop refills.")
        }
    }

    private var locationSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(1...10, id: \.self) { locNum in
                    let unlocked = locNum <= save.data.highestLocationUnlocked || locNum == 1
                    let missions = catalog.missionsByLocation[locNum] ?? []
                    let earnedStars = missions.reduce(0) { $0 + (save.data.missionStars[$1.id] ?? 0) }
                    let maxStars = missions.count * 3
                    let isSelected = selectedLocation == locNum

                    Button {
                        selectedLocation = locNum
                        selectedMission = missions.first
                        ZWSoundEngine.shared.playTapHaptic()
                    } label: {
                        HStack(spacing: 4) {
                            Text("LOC \(locNum)")
                                .font(ZWTypography.impact(11))
                            Text("\(earnedStars)/\(maxStars)★")
                                .font(ZWTypography.mono(9))
                                .foregroundColor(ZWPalette.coinGold)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(isSelected ? ZWPalette.coinGold.opacity(0.25) : ZWPalette.tarmacDark)
                        .foregroundColor(unlocked ? .white : .gray)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(isSelected ? ZWPalette.coinGold : ZWPalette.panelBorder, lineWidth: isSelected ? 1.8 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 30)
    }

    private var missionMapCanvas: some View {
        let missions = catalog.missionsByLocation[selectedLocation] ?? []
        let xs = missions.map { Double($0.mapX) }
        let ys = missions.map { Double($0.mapY) }
        let minX = (xs.min() ?? 0) - 2
        let maxX = max(minX + 4, (xs.max() ?? 10) + 2)
        let minY = (ys.min() ?? 0) - 2
        let maxY = max(minY + 4, (ys.max() ?? 10) + 2)

        return ZWTacticalPanel {
            GeometryReader { geo in
                ZStack {
                    // Location road backdrop preview tint from extracted GameSprites/Backgrounds
                    let bgNames = ZWSpriteLoader.shared.availableFileNames(in: .backgrounds)
                    let locBg = bgNames.first { $0.hasPrefix("loc_\(selectedLocation)_") && !$0.contains("_road_") } ?? "loc_1_1_set1_bg_18"
                    ZWPixelSpriteView(locBg, folder: .backgrounds, fallbackSymbol: "map.fill", contentMode: .fill)
                        .opacity(0.24)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    // Highway polyline connecting nodes in sequence
                    Path { path in
                        for (idx, m) in missions.enumerated() {
                            let pt = point(for: m, in: geo.size, minX: minX, maxX: maxX, minY: minY, maxY: maxY)
                            if idx == 0 {
                                path.move(to: pt)
                            } else {
                                path.addLine(to: pt)
                            }
                        }
                    }
                    .stroke(Color(white: 0.45, opacity: 0.65), style: StrokeStyle(lineWidth: 2.5, dash: [5, 4]))

                    // Mission Pins
                    ForEach(missions) { mission in
                        let pt = point(for: mission, in: geo.size, minX: minX, maxX: maxX, minY: minY, maxY: maxY)
                        let stars = save.data.missionStars[mission.id] ?? 0
                        let isSelected = selectedMission?.id == mission.id

                        Button {
                            selectedMission = mission
                            ZWSoundEngine.shared.playTapHaptic()
                        } label: {
                            VStack(spacing: 1) {
                                ZStack {
                                    Circle()
                                        .fill(pinColor(for: mission, stars: stars))
                                        .frame(width: isSelected ? 24 : 18, height: isSelected ? 24 : 18)
                                        .overlay(
                                            Circle().strokeBorder(isSelected ? Color.white : Color.black, lineWidth: isSelected ? 2 : 1)
                                        )
                                    Text("\(mission.stageNumber)")
                                        .font(ZWTypography.mono(8))
                                        .foregroundColor(.black)
                                }
                                if stars > 0 {
                                    Text(String(repeating: "★", count: stars))
                                        .font(.system(size: 7))
                                        .foregroundColor(ZWPalette.coinGold)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .position(pt)
                    }
                }
            }
        }
    }

    private func point(
        for m: ZWMissionConfig,
        in size: CGSize,
        minX: Double,
        maxX: Double,
        minY: Double,
        maxY: Double
    ) -> CGPoint {
        let padX: CGFloat = 24
        let padY: CGFloat = 22
        let nx = (Double(m.mapX) - minX) / max(1, maxX - minX)
        let ny = (Double(m.mapY) - minY) / max(1, maxY - minY)
        return CGPoint(
            x: padX + CGFloat(nx) * max(1, size.width - padX * 2),
            y: padY + CGFloat(1.0 - ny) * max(1, size.height - padY * 2)
        )
    }

    private func pinColor(for mission: ZWMissionConfig, stars: Int) -> Color {
        if mission.isBossMission { return ZWPalette.dangerRed }
        if mission.isSupplyRun { return ZWPalette.courageBlue }
        if stars >= 3 { return ZWPalette.coinGold }
        if stars > 0 { return ZWPalette.cashGreen }
        return Color.white.opacity(0.85)
    }

    private var missionBriefingPanel: some View {
        ZWTacticalPanel {
            if let m = selectedMission {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ZWOutlineText(
                            m.isBossMission ? "BOSS STAGE \(m.location)-\(m.stageNumber)" :
                                (m.isSupplyRun ? "SUPPLY RUN \(m.location)-\(m.stageNumber)" : "MISSION \(m.location)-\(m.stageNumber)"),
                            palette: "GoldSolid",
                            font: ZWTypography.impact(14)
                        )
                        Spacer()
                        let diffColors = ["Difficulty0", "Difficulty1", "Difficulty2", "Difficulty3", "Difficulty4", "Difficulty5"]
                        let pal = diffColors[min(5, max(0, m.difficultyIndex))]
                        ZWOutlineText(difficultyTitle(m.difficultyIndex), palette: pal, font: ZWTypography.mono(9))
                    }

                    Divider().background(ZWPalette.panelBorder)

                    HStack(spacing: 8) {
                        Label("\(m.fuelCost) Fuel", systemImage: "fuelpump.fill")
                            .foregroundColor(ZWPalette.hazardOrange)
                        if let weather = m.weatherHazard {
                            Label(weather, systemImage: "cloud.bolt.rain.fill")
                                .foregroundColor(ZWPalette.courageBlue)
                        }
                    }
                    .font(ZWTypography.mono(10))

                    Text("ENEMY WAVES")
                        .font(ZWTypography.mono(9))
                        .foregroundColor(.gray)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(Set(m.waves.map { $0.enemyID })).sorted(), id: \.self) { eid in
                                VStack(spacing: 2) {
                                    ZWPixelSpriteView(eid, folder: .portraits, fallbackSymbol: "exclamationmark.shield.fill")
                                        .frame(width: 34, height: 34)
                                        .background(ZWPalette.tarmacDark)
                                        .cornerRadius(4)
                                    Text(loc.text("zombiepedia.unit.name.\(eid)", fallback: eid))
                                        .font(ZWTypography.mono(8))
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineLimit(1)
                                        .frame(width: 48)
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Label("+\(m.coinReward)", systemImage: "dollarsign.circle.fill")
                            .foregroundColor(ZWPalette.coinGold)
                        Label("+\(m.powerPointReward) PP", systemImage: "bolt.fill")
                            .foregroundColor(ZWPalette.courageBlue)
                    }
                    .font(ZWTypography.mono(10))

                    Spacer()

                    Button {
                        if save.spendFuel(m.fuelCost) {
                            let mode: ZWBattleMode = m.isSupplyRun ? .supplyRun : .campaign
                            onLaunchMission(mode, m)
                        } else {
                            fuelAlert = true
                        }
                    } label: {
                        HStack {
                            Spacer()
                            ZWOutlineText("FIGHT!", palette: "WhiteSolid", font: ZWTypography.impact(16))
                            Spacer()
                        }
                    }
                    .buttonStyle(ZWTacticalButtonStyle(tone: .green))
                }
                .padding(12)
            } else {
                Text("Select a mission pin on the highway")
                    .font(ZWTypography.body(12))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func difficultyTitle(_ index: Int) -> String {
        switch index {
        case 0: return "EASY"
        case 1: return "NORMAL"
        case 2: return "HARD"
        case 3: return "INSANE"
        case 4: return "NIGHTMARE"
        default: return "APOCALYPSE"
        }
    }
}
