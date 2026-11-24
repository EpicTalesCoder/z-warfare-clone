import SwiftUI

// Port of BusUpgradeMenu (Type#4131) + Bus Skins & Parts customization
// Evidence: GameSprites/Bus/*_bus_*.png, part_buswheels*, h_busdriver_idle_00
public struct ZWBusGarageView: View {
    @ObservedObject private var save = ZWSaveGameService.shared
    private let catalog = ZWGameCatalog.shared

    public init() {}

    public var body: some View {
        let activeSkin = catalog.busSkinsByID[save.data.equippedBusSkinID] ?? catalog.busSkins[0]
        let busHP = Int(ZWBattleFormulas.busMaxHP(busLevel: save.data.busLevel, armorLevel: save.data.busArmorLevel))
        let upgCost = save.busUpgradeCost(level: save.data.busLevel)

        HStack(spacing: 10) {
            // Left: Bus Showcase & Stats
            ZWTacticalPanel {
                VStack(spacing: 8) {
                    HStack {
                        ZWOutlineText("SURVIVOR BUS — Lv.\(save.data.busLevel)/30", palette: "GoldSolid", font: ZWTypography.impact(14))
                        Spacer()
                        ZWOutlineText("HP \(busHP)", palette: "GreenSolid", font: ZWTypography.impact(14))
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ZWPalette.tarmacDark)
                        HStack(spacing: 12) {
                            ZWPixelSpriteView(activeSkin.bodySpriteName, folder: .bus)
                                .frame(height: 110)
                            VStack(spacing: 4) {
                                ZWPixelSpriteView("h_busdriver_idle_00", folder: .bus)
                                    .frame(width: 52, height: 52)
                                Text("Driver Bill")
                                    .font(ZWTypography.mono(9))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .frame(height: 135)

                    HStack(spacing: 8) {
                        Button {
                            _ = save.upgradeBus()
                        } label: {
                            Text(save.data.busLevel >= 30 ? "BUS MAX LEVEL" : "UPGRADE BUS (\(upgCost) COINS)")
                                .font(ZWTypography.impact(12))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ZWTacticalButtonStyle(tone: .green))
                        .disabled(save.data.busLevel >= 30 || save.data.coins < upgCost)
                    }

                    HStack(spacing: 10) {
                        partBadge("Wheels Lv.\(save.data.busWheelLevel)", sprite: "part_buswheels1_bus_wheel1f_00") {
                            if save.data.coins >= 120 {
                                save.data.coins -= 120
                                save.data.busWheelLevel += 1
                                save.save()
                            }
                        }
                        partBadge("Exhaust Lv.\(save.data.busPipeLevel)", sprite: "part_pipe1_Pipe1") {
                            if save.data.coins >= 120 {
                                save.data.coins -= 120
                                save.data.busPipeLevel += 1
                                save.save()
                            }
                        }
                        partBadge("Armor Lv.\(save.data.busArmorLevel)", sprite: "part_window1_Window1") {
                            if save.data.coins >= 150 {
                                save.data.coins -= 150
                                save.data.busArmorLevel += 1
                                save.save()
                            }
                        }
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity)

            // Right: All 17 Extracted Bus Skins
            ZWTacticalPanel {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        ZWOutlineText("PAINTS & SKINS", palette: "SkinCoins", font: ZWTypography.impact(13))
                        Spacer()
                        Text("\(save.data.skinCoins) SC")
                            .font(ZWTypography.mono(10))
                            .foregroundColor(ZWPaletteStore.shared.entry(named: "SkinCoins").fillColor)
                    }
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(catalog.busSkins) { skin in
                                let unlocked = save.data.unlockedBusSkinIDs.contains(skin.id)
                                let equipped = save.data.equippedBusSkinID == skin.id
                                Button {
                                    _ = save.selectOrUnlockBusSkin(skin)
                                    ZWSoundEngine.shared.playTapHaptic()
                                } label: {
                                    VStack(spacing: 3) {
                                        ZWPixelSpriteView(skin.bodySpriteName, folder: .bus)
                                            .frame(height: 44)
                                            .opacity(unlocked ? 1 : 0.55)
                                        Text(skin.displayName)
                                            .font(ZWTypography.mono(9))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text(equipped ? "EQUIPPED" : (unlocked ? "OWNED" : "\(skin.costSkinCoins) SC"))
                                            .font(ZWTypography.mono(8))
                                            .foregroundColor(equipped ? ZWPalette.cashGreen : ZWPalette.coinGold)
                                    }
                                    .padding(6)
                                    .frame(maxWidth: .infinity)
                                    .background(equipped ? ZWPalette.cashGreen.opacity(0.2) : ZWPalette.tarmacDark)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(equipped ? ZWPalette.cashGreen : ZWPalette.panelBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .frame(width: 295)
        }
    }

    private func partBadge(_ title: String, sprite: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ZWPixelSpriteView(sprite, folder: .bus)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading) {
                    Text(title).font(ZWTypography.mono(9)).foregroundColor(.white)
                    Text("+Up 120c").font(ZWTypography.mono(8)).foregroundColor(ZWPalette.coinGold)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(ZWPalette.tarmacDark)
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}
