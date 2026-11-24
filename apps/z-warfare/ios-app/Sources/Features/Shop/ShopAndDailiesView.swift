import SwiftUI

// Port of ShopMenu (Type#4784) + DailiesMenu (Type#4895) + Offline Crate Roulette
// Zero third-party ads or external billing SDKs per iOS 16.1.1 steering; uses local currency economy & packs registry.
public struct ZWShopAndDailiesView: View {
    @ObservedObject private var save = ZWSaveGameService.shared
    private let catalog = ZWGameCatalog.shared
    @State private var rouletteRewardText: String?

    public init() {}

    public var body: some View {
        HStack(spacing: 10) {
            // Left: Daily Quests (DailiesMenu)
            ZWTacticalPanel {
                VStack(alignment: .leading, spacing: 6) {
                    ZWOutlineText("DAILY TASKS", palette: "GoldSolid", font: ZWTypography.impact(14))
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(save.data.dailyQuests) { q in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(q.title)
                                            .font(ZWTypography.body(11))
                                            .foregroundColor(.white)
                                        Text("\(q.progressCount)/\(q.targetCount)  •  +\(q.rewardCoins) Coins, +\(q.rewardCash) Cash")
                                            .font(ZWTypography.mono(9))
                                            .foregroundColor(ZWPalette.coinGold)
                                    }
                                    Spacer()
                                    if q.claimed {
                                        Text("CLAIMED")
                                            .font(ZWTypography.mono(9))
                                            .foregroundColor(.gray)
                                    } else {
                                        Button("CLAIM") {
                                            save.claimDailyQuest(id: q.id)
                                            ZWSoundEngine.shared.playTapHaptic()
                                        }
                                        .buttonStyle(ZWTacticalButtonStyle(tone: q.progressCount >= q.targetCount ? .green : .slate, compact: true))
                                        .disabled(q.progressCount < q.targetCount)
                                    }
                                }
                                .padding(8)
                                .background(ZWPalette.tarmacDark)
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .frame(maxWidth: .infinity)

            // Right: Supply Trader, Crate Roulette, & Exchanges
            ZWTacticalPanel {
                VStack(alignment: .leading, spacing: 8) {
                    ZWOutlineText("SURVIVOR TRADER & SUPPLY CRATES", palette: "GreenSolid", font: ZWTypography.impact(14))

                    ScrollView {
                        VStack(spacing: 7) {
                            traderRow(
                                title: "Military Supply Crate (Roulette)",
                                subtitle: "Roll for Coins, Power Points, Skin Coins, or Charm Points",
                                sprite: "award_box_Shop_Box1",
                                buttonLabel: "OPEN (1 KEY)",
                                tone: .gold,
                                enabled: save.data.blueKeys >= 1
                            ) {
                                guard save.data.blueKeys >= 1 else { return }
                                save.data.blueKeys -= 1
                                let bonusCoins = Int.random(in: 120...320)
                                let bonusPP = Int.random(in: 80...220)
                                let bonusSC = Int.random(in: 20...60)
                                save.data.coins += bonusCoins
                                save.data.powerPoints += bonusPP
                                save.data.skinCoins += bonusSC
                                save.save()
                                rouletteRewardText = "Crate opened: +\(bonusCoins) Coins, +\(bonusPP) PP, +\(bonusSC) Skin Coins!"
                            }

                            traderRow(
                                title: "Red Key Elite Cache",
                                subtitle: "High-tier cache with guaranteed Cash & Power Points",
                                sprite: "award_redkeys",
                                buttonLabel: "OPEN (1 RED KEY)",
                                tone: .red,
                                enabled: save.data.redKeys >= 1
                            ) {
                                guard save.data.redKeys >= 1 else { return }
                                save.data.redKeys -= 1
                                save.data.cash += 12
                                save.data.powerPoints += 350
                                save.data.charmPoints += 30
                                save.save()
                                rouletteRewardText = "Elite cache: +12 Cash, +350 PP, +30 Charm Points!"
                            }

                            traderRow(
                                title: "Fuel Jerrycan Refill (+20)",
                                subtitle: "Refills Highway Fuel tank immediately",
                                sprite: "lootIcon_fuel",
                                buttonLabel: "20 CASH",
                                tone: .green,
                                enabled: save.data.cash >= 20 && save.data.fuel < save.data.maxFuel
                            ) {
                                guard save.data.cash >= 20 else { return }
                                save.data.cash -= 20
                                save.data.fuel = save.data.maxFuel
                                save.save()
                                rouletteRewardText = "Fuel tank restored to 20/20!"
                            }

                            traderRow(
                                title: "Austin's Coin Pouch (+800 Coins)",
                                subtitle: "Exchange Cash for unit & bus upgrade Coins",
                                sprite: "award_coins",
                                buttonLabel: "15 CASH",
                                tone: .blue,
                                enabled: save.data.cash >= 15
                            ) {
                                guard save.data.cash >= 15 else { return }
                                save.data.cash -= 15
                                save.data.coins += 800
                                save.save()
                                rouletteRewardText = "Exchanged +800 Coins!"
                            }
                        }
                    }

                    if let msg = rouletteRewardText {
                        Text(msg)
                            .font(ZWTypography.mono(10))
                            .foregroundColor(ZWPalette.cashGreen)
                    }

                    Text("Encrypted Packs Catalog Verified: \(catalog.encryptedPackHashes.count) IDs")
                        .font(ZWTypography.mono(8))
                        .foregroundColor(.gray)
                }
                .padding(10)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func traderRow(
        title: String,
        subtitle: String,
        sprite: String,
        buttonLabel: String,
        tone: ZWButtonTone,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            ZWPixelSpriteView(sprite, folder: .ui)
                .frame(width: 36, height: 36)
                .background(ZWPalette.tarmacDark)
                .cornerRadius(5)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ZWTypography.body(11))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(ZWTypography.mono(9))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            Spacer()
            Button(buttonLabel, action: action)
                .font(ZWTypography.mono(9))
                .foregroundColor(.white)
                .buttonStyle(ZWTacticalButtonStyle(tone: enabled ? tone : .slate, compact: true))
                .disabled(!enabled)
        }
        .padding(8)
        .background(ZWPalette.tarmacDark)
        .cornerRadius(6)
    }
}
