import SwiftUI

// Port of ZombiepediaMenu (Type#5167)
// Evidence: TextColorsPalette ("ZombiepediaDescr", "ZombiepediaKills"), GameSprites/Portraits/*, localization (zombiepedia.unit.*)
public struct ZWZombiepediaView: View {
    @ObservedObject private var save = ZWSaveGameService.shared
    @ObservedObject private var loc = ZWLocalizationService.shared
    private let catalog = ZWGameCatalog.shared

    @State private var selectedEnemyID: String = "z_naked"
    @State private var searchText: String = ""

    public init() {}

    public var body: some View {
        let filtered = catalog.enemies.filter { enemy in
            if searchText.isEmpty { return true }
            let name = loc.text(enemy.locNameKey, fallback: enemy.id)
            return name.localizedCaseInsensitiveContains(searchText) || enemy.id.localizedCaseInsensitiveContains(searchText)
        }
        let selected = catalog.enemiesByID[selectedEnemyID] ?? catalog.enemies[0]

        HStack(spacing: 10) {
            // Left: Field Notebook Index of all 79 Zombies & Marauders
            ZWTacticalPanel {
                VStack(spacing: 6) {
                    HStack {
                        ZWOutlineText("ZOMBIEPEDIA (\(catalog.enemies.count))", palette: "GoldSolid", font: ZWTypography.impact(13))
                        Spacer()
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .font(ZWTypography.body(11))
                            .frame(width: 140)
                    }

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 6)], spacing: 6) {
                            ForEach(filtered) { enemy in
                                let kills = save.data.zombiepediaKills[enemy.id] ?? 0
                                let isSelected = selected.id == enemy.id
                                Button {
                                    selectedEnemyID = enemy.id
                                    ZWSoundEngine.shared.playTapHaptic()
                                } label: {
                                    VStack(spacing: 2) {
                                        ZWPixelSpriteView(enemy.id, folder: .portraits, fallbackSymbol: "exclamationmark.triangle.fill")
                                            .frame(width: 46, height: 46)
                                        Text(loc.text(enemy.locNameKey, fallback: enemy.id))
                                            .font(ZWTypography.mono(8))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text("\(kills) kills")
                                            .font(ZWTypography.mono(8))
                                            .foregroundColor(kills > 0 ? ZWPalette.coinGold : .gray)
                                    }
                                    .padding(4)
                                    .frame(maxWidth: .infinity)
                                    .background(isSelected ? ZWPalette.hazardOrange.opacity(0.25) : ZWPalette.tarmacDark)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(isSelected ? ZWPalette.hazardOrange : ZWPalette.panelBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity)

            // Right: Two-Page Parchment Field Notebook Entry
            ZWTacticalPanel(borderColor: Color.brown.opacity(0.8)) {
                VStack(alignment: .leading, spacing: 8) {
                    let kills = save.data.zombiepediaKills[selected.id] ?? 0
                    let canClaim = kills >= 1 && !save.data.zombiepediaClaimed.contains(selected.id)

                    HStack(spacing: 10) {
                        ZWAnimatedUnitView(sheetId: selected.id, state: "idle", fps: 5)
                            .frame(width: 64, height: 64)
                            .background(ZWPalette.notebookInk.opacity(0.12))
                            .cornerRadius(6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc.text(selected.locNameKey, fallback: selected.id))
                                .font(ZWTypography.impact(16))
                                .foregroundColor(ZWPaletteStore.shared.entry(named: "ZombiepediaDescr").fillColor)
                            Text("KILLS: \(kills)")
                                .font(ZWTypography.impact(13))
                                .foregroundColor(ZWPaletteStore.shared.entry(named: "ZombiepediaKills").fillColor)
                            Text(selected.isMarauder ? "MARAUDER" : (selected.isDemon ? "BLUE / ALIEN" : "INFECTED"))
                                .font(ZWTypography.mono(9))
                                .foregroundColor(ZWPalette.notebookInk.opacity(0.75))
                        }
                        Spacer()
                    }

                    Divider().background(ZWPalette.notebookInk.opacity(0.3))

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(loc.text(selected.locDescrKey, fallback: selected.traits.joined(separator: ", ")))
                                .font(ZWTypography.body(11))
                                .foregroundColor(ZWPaletteStore.shared.entry(named: "ZombiepediaDescr").fillColor)

                            HStack(spacing: 8) {
                                Text("HP: \(Int(selected.baseHP))")
                                Text("DMG: \(Int(selected.damage))")
                                Text("SPD: \(Int(selected.moveSpeed))")
                            }
                            .font(ZWTypography.mono(10))
                            .foregroundColor(ZWPalette.notebookInk)

                            ForEach(selected.traits, id: \.self) { trait in
                                Text("• \(trait)")
                                    .font(ZWTypography.mono(10))
                                    .foregroundColor(ZWPalette.notebookInk.opacity(0.85))
                            }
                        }
                    }

                    Spacer()

                    if canClaim {
                        Button {
                            _ = save.claimZombiepediaReward(for: selected.id)
                            ZWSoundEngine.shared.playTapHaptic()
                        } label: {
                            HStack {
                                Spacer()
                                ZWOutlineText("CLAIM ENTRY BOUNTY +3 CASH", palette: "WhiteSolid", font: ZWTypography.impact(12))
                                Spacer()
                            }
                        }
                        .buttonStyle(ZWTacticalButtonStyle(tone: .green))
                    } else if save.data.zombiepediaClaimed.contains(selected.id) {
                        Text("✓ ENTRY BOUNTY CLAIMED")
                            .font(ZWTypography.mono(10))
                            .foregroundColor(ZWPalette.notebookInk.opacity(0.7))
                    } else {
                        Text("Eliminate 1 target in battle to claim +3 Cash")
                            .font(ZWTypography.mono(9))
                            .foregroundColor(ZWPalette.notebookInk.opacity(0.65))
                    }
                }
                .padding(12)
                .background(ZWPalette.notebookPaper)
                .cornerRadius(6)
            }
            .frame(width: 285)
        }
    }
}
