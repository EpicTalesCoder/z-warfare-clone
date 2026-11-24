import SwiftUI

// Port of UnitDeckMenu + UnitUpgradeMenu + Team Synergies View
// Fits 6-slot Deck, 53 Survivors + 9 Items Roster, and Stat/Upgrade/Gear/Charm Inspector inside Landscape 896x414 pt.
public struct ZWTeamDeckView: View {
    @ObservedObject private var save = ZWSaveGameService.shared
    @ObservedObject private var loc = ZWLocalizationService.shared
    private let catalog = ZWGameCatalog.shared

    private enum RosterTab: String, CaseIterable {
        case units = "SURVIVORS"
        case items = "ITEMS"
        case synergies = "TEAMS"
    }

    @State private var tab: RosterTab = .units
    @State private var selectedID: String = "h_naked"
    @State private var animPreviewState: String = "idle"

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            // Left: Active 6-Slot Battle Deck + Active Synergies
            deckSidebar
                .frame(width: 155)

            // Center: Roster Grid or Synergies Reference
            centerRosterPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Right: Unit / Item Upgrade & Equipment Inspector
            inspectorPanel
                .frame(width: 248)
        }
    }

    private var deckSidebar: some View {
        let synergies = ZWBattleFormulas.activeSynergyCounts(deckIDs: save.data.deckUnitIDs, catalog: catalog)
        return ZWTacticalPanel {
            VStack(spacing: 6) {
                ZWOutlineText("BATTLE DECK (\(save.data.deckUnitIDs.count)/6)", palette: "GoldSolid", font: ZWTypography.impact(11))

                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(save.data.deckUnitIDs, id: \.self) { id in
                            let isItem = catalog.isSupportItem(id)
                            let name = catalog.unitsByID[id].map { loc.text($0.locNameKey, fallback: id) }
                                ?? catalog.itemsByID[id].map { loc.text($0.locNameKey, fallback: id) }
                                ?? id
                            Button {
                                selectedID = id
                                ZWSoundEngine.shared.playTapHaptic()
                            } label: {
                                HStack(spacing: 6) {
                                    ZWPixelSpriteView(id, folder: isItem ? .ui : .portraits)
                                        .frame(width: 28, height: 28)
                                        .background(ZWPalette.tarmacDark)
                                        .cornerRadius(4)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(name)
                                            .font(ZWTypography.body(10))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text("Lv.\(save.unitLevel(for: id))")
                                            .font(ZWTypography.mono(9))
                                            .foregroundColor(ZWPalette.coinGold)
                                    }
                                    Spacer()
                                }
                                .padding(4)
                                .background(selectedID == id ? ZWPalette.coinGold.opacity(0.22) : ZWPalette.tarmacDark)
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider().background(ZWPalette.panelBorder)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ACTIVE SYNERGIES")
                        .font(ZWTypography.mono(8))
                        .foregroundColor(.gray)
                    ForEach(synergies.sorted(by: { $0.value > $1.value }), id: \.key) { faction, count in
                        if count >= 2 {
                            Text("• \(loc.text(faction.locKey, fallback: faction.rawValue)) (\(count)/5)")
                                .font(ZWTypography.mono(9))
                                .foregroundColor(ZWPalette.cashGreen)
                        }
                    }
                    if synergies.values.allSatisfy({ $0 < 2 }) {
                        Text("Need 2+ same team")
                            .font(ZWTypography.mono(9))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
        }
    }

    private var centerRosterPanel: some View {
        ZWTacticalPanel {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(RosterTab.allCases, id: \.self) { t in
                        Button(t.rawValue) {
                            tab = t
                            ZWSoundEngine.shared.playTapHaptic()
                        }
                        .font(ZWTypography.mono(10))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(tab == t ? ZWPalette.courageBlue.opacity(0.25) : ZWPalette.tarmacDark)
                        .foregroundColor(tab == t ? ZWPalette.courageBlue : .white)
                        .cornerRadius(5)
                    }
                    Spacer()
                }

                switch tab {
                case .units:
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], spacing: 6) {
                            ForEach(catalog.units) { u in
                                let owned = save.isOwned(u.id)
                                let inDeck = save.data.deckUnitIDs.contains(u.id)
                                Button {
                                    selectedID = u.id
                                    ZWSoundEngine.shared.playTapHaptic()
                                } label: {
                                    VStack(spacing: 3) {
                                        ZStack(alignment: .topTrailing) {
                                            ZWPixelSpriteView(u.id, folder: .portraits)
                                                .frame(width: 52, height: 52)
                                                .opacity(owned ? 1.0 : 0.42)
                                            if inDeck {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(ZWPalette.cashGreen)
                                            }
                                        }
                                        Text(loc.text(u.locNameKey, fallback: u.id))
                                            .font(ZWTypography.mono(9))
                                            .foregroundColor(owned ? .white : .gray)
                                            .lineLimit(1)
                                        Text(owned ? "Lv.\(save.unitLevel(for: u.id))" : (u.unlockCostCash > 0 ? "$\(u.unlockCostCash)" : "\(u.unlockCostCoins)c"))
                                            .font(ZWTypography.mono(8))
                                            .foregroundColor(owned ? ZWPalette.coinGold : ZWPalette.cashGreen)
                                    }
                                    .padding(5)
                                    .frame(maxWidth: .infinity)
                                    .background(selectedID == u.id ? ZWPalette.coinGold.opacity(0.2) : ZWPalette.tarmacDark)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(selectedID == u.id ? ZWPalette.coinGold : ZWPalette.panelBorder, lineWidth: selectedID == u.id ? 1.6 : 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                case .items:
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 6)], spacing: 6) {
                            ForEach(catalog.supportItems) { item in
                                let owned = save.isOwned(item.id)
                                let inDeck = save.data.deckUnitIDs.contains(item.id)
                                Button {
                                    selectedID = item.id
                                    ZWSoundEngine.shared.playTapHaptic()
                                } label: {
                                    VStack(spacing: 3) {
                                        ZStack(alignment: .topTrailing) {
                                            ZWPixelSpriteView(item.id, folder: .ui)
                                                .frame(width: 48, height: 48)
                                                .opacity(owned ? 1.0 : 0.45)
                                            if inDeck {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(ZWPalette.cashGreen)
                                            }
                                        }
                                        Text(loc.text(item.locNameKey, fallback: item.id))
                                            .font(ZWTypography.mono(9))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text(owned ? "Rage \(item.cost)" : "\(item.unlockCostCoins)c")
                                            .font(ZWTypography.mono(8))
                                            .foregroundColor(ZWPalette.ragePink)
                                    }
                                    .padding(6)
                                    .frame(maxWidth: .infinity)
                                    .background(selectedID == item.id ? ZWPalette.ragePink.opacity(0.2) : ZWPalette.tarmacDark)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                case .synergies:
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(catalog.synergies) { syn in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(loc.text(syn.faction.locKey, fallback: syn.faction.rawValue))
                                        .font(ZWTypography.impact(12))
                                        .foregroundColor(ZWPalette.coinGold)
                                    ForEach(syn.tiers, id: \.requiredCount) { tier in
                                        Text("\(tier.requiredCount)/5: \(tier.effectSummary)")
                                            .font(ZWTypography.body(10))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(ZWPalette.tarmacDark)
                                .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private var inspectorPanel: some View {
        ZWTacticalPanel {
            ScrollView {
                if let u = catalog.unitsByID[selectedID] {
                    unitInspector(u)
                } else if let item = catalog.itemsByID[selectedID] {
                    itemInspector(item)
                }
            }
            .padding(10)
        }
    }

    private func unitInspector(_ u: ZWUnitDefinition) -> some View {
        let lvl = max(1, save.unitLevel(for: u.id))
        let owned = save.isOwned(u.id)
        let inDeck = save.data.deckUnitIDs.contains(u.id)
        let cost = save.upgradeCost(currentLevel: lvl)
        let hp = Int(ZWBattleFormulas.upgradedStat(base: u.baseHP, level: lvl))
        let dmg = Int(ZWBattleFormulas.upgradedStat(base: max(u.baseMeleeDamage, u.baseRangedDamage), level: lvl))

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Button {
                    animPreviewState = animPreviewState == "idle" ? "attack" : "idle"
                } label: {
                    ZWAnimatedUnitView(sheetId: u.id, state: animPreviewState, fps: 7)
                        .frame(width: 62, height: 54)
                        .background(ZWPalette.tarmacDark)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    ZWOutlineText(loc.text(u.locNameKey, fallback: u.id), palette: "GoldSolid", font: ZWTypography.impact(13))
                    Text("\(u.unitClass.rawValue) • \(loc.text(u.faction.locKey, fallback: u.faction.rawValue))")
                        .font(ZWTypography.mono(9))
                        .foregroundColor(ZWPalette.courageBlue)
                    Text(owned ? "Level \(lvl)/30" : "LOCKED")
                        .font(ZWTypography.mono(10))
                        .foregroundColor(owned ? ZWPalette.cashGreen : ZWPalette.dangerRed)
                }
            }

            Text(loc.text(u.locDescrKey, fallback: u.perkSummary))
                .font(ZWTypography.body(10))
                .foregroundColor(.white.opacity(0.85))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                statPill("HP", "\(hp)", ZWPalette.cashGreen)
                statPill("DMG", "\(dmg)", ZWPalette.hazardOrange)
                statPill("COST", "\(u.cost) \(u.currency == .courage ? "C" : "R")", ZWPalette.courageBlue)
                statPill("PREP", String(format: "%.1fs", u.prepareTime), .white)
                statPill("CRIT", "\(Int(u.critChance * 100))%", ZWPalette.coinGold)
                statPill("RES", u.resistances.bulletResist > 0 ? "\(Int(u.resistances.bulletResist * 100))% BUL" : (u.resistances.fireImmune ? "FIRE IMM" : "STD"), .white)
            }

            if !owned {
                Button {
                    _ = save.unlockUnit(u)
                } label: {
                    Text(u.unlockCostCash > 0 ? "UNLOCK $\(u.unlockCostCash)" : "UNLOCK \(u.unlockCostCoins) COINS")
                        .font(ZWTypography.impact(12))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ZWTacticalButtonStyle(tone: .gold))
            } else {
                HStack(spacing: 6) {
                    Button {
                        _ = save.upgradeUnit(u.id)
                    } label: {
                        Text(lvl >= 30 ? "MAX LVL" : "UP (\(cost.coins)c / \(cost.powerPoints)PP)")
                            .font(ZWTypography.mono(9))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ZWTacticalButtonStyle(tone: .green, compact: true))
                    .disabled(lvl >= 30 || save.data.coins < cost.coins || save.data.powerPoints < cost.powerPoints)

                    Button {
                        save.toggleDeckUnit(u.id)
                    } label: {
                        Text(inDeck ? "REMOVE" : "EQUIP")
                            .font(ZWTypography.mono(9))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(ZWTacticalButtonStyle(tone: inDeck ? .red : .blue, compact: true))
                }

                // Gear & Charm quick bar
                Text("GEAR & CHARM")
                    .font(ZWTypography.mono(8))
                    .foregroundColor(.gray)

                HStack(spacing: 5) {
                    ForEach(ZWGearItem.Slot.allCases, id: \.self) { slot in
                        let equipped = save.data.equippedGear[u.id]?[slot.rawValue]
                        Button {
                            save.equipStarterGear(setName: "Firefighter", slot: slot, for: u.id)
                        } label: {
                            ZWPixelSpriteView(equipped?.iconName ?? "item_empty_slot_bg", folder: .ui)
                                .frame(width: 28, height: 28)
                                .background(ZWPalette.tarmacDark)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Menu {
                        ForEach(catalog.charms) { ch in
                            Button("\(loc.text(ch.locNameKey)) (\(ch.bonusSummary))") {
                                save.equipCharm(ch.id, for: u.id)
                            }
                        }
                        Button("Unequip Charm") {
                            save.equipCharm(nil, for: u.id)
                        }
                    } label: {
                        let cid = save.data.equippedCharms[u.id]
                        let charm = catalog.charms.first { $0.id == cid }
                        ZWPixelSpriteView(charm?.iconName ?? "charm_common_card", folder: .ui)
                            .frame(width: 30, height: 30)
                            .background(ZWPalette.coinGold.opacity(0.18))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }

    private func itemInspector(_ item: ZWSupportItemDefinition) -> some View {
        let lvl = max(1, save.unitLevel(for: item.id))
        let owned = save.isOwned(item.id)
        let inDeck = save.data.deckUnitIDs.contains(item.id)
        let dmg = Int(ZWBattleFormulas.upgradedStat(base: item.baseDamage, level: lvl))

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZWPixelSpriteView(item.id, folder: .ui)
                    .frame(width: 54, height: 54)
                    .background(ZWPalette.tarmacDark)
                    .cornerRadius(6)
                VStack(alignment: .leading) {
                    ZWOutlineText(loc.text(item.locNameKey, fallback: item.id), palette: "RageColor", font: ZWTypography.impact(13))
                    Text("Support Item • Rage \(item.cost)")
                        .font(ZWTypography.mono(9))
                        .foregroundColor(ZWPalette.ragePink)
                }
            }
            Text(item.description)
                .font(ZWTypography.body(11))
                .foregroundColor(.white.opacity(0.85))
            Text("Effect / Damage: \(dmg) • Prep: \(Int(item.prepareTime))s")
                .font(ZWTypography.mono(10))
                .foregroundColor(ZWPalette.coinGold)

            if !owned {
                Button("UNLOCK \(item.unlockCostCoins) COINS") {
                    _ = save.unlockSupportItem(item)
                }
                .buttonStyle(ZWTacticalButtonStyle(tone: .gold))
            } else {
                HStack(spacing: 6) {
                    Button("UPGRADE Lv.\(lvl + 1)") {
                        _ = save.upgradeUnit(item.id)
                    }
                    .buttonStyle(ZWTacticalButtonStyle(tone: .green, compact: true))
                    Button(inDeck ? "REMOVE" : "EQUIP") {
                        save.toggleDeckUnit(item.id)
                    }
                    .buttonStyle(ZWTacticalButtonStyle(tone: inDeck ? .red : .blue, compact: true))
                }
            }
        }
    }

    private func statPill(_ label: String, _ val: String, _ color: Color) -> some View {
        HStack {
            Text(label).font(ZWTypography.mono(8)).foregroundColor(.gray)
            Spacer()
            Text(val).font(ZWTypography.mono(9)).foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(ZWPalette.tarmacDark)
        .cornerRadius(4)
    }
}
