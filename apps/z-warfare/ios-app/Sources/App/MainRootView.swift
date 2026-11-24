import SwiftUI

// Port of LaunchScreen-iPhone.nib + Main Map Hub HUD Chrome + Bottom Navigation Dock
// Engineered for iPhone XS Max Landscape (896x414 pt @3x): 40pt top resource strip + 48pt bottom navigation dock.
public enum ZWHubTab: String, CaseIterable, Identifiable {
    case map = "MAP"
    case deck = "UNITS"
    case bus = "BUS"
    case events = "MODES"
    case zombiepedia = "ZOMBIEPEDIA"
    case shop = "SHOP"
    case settings = "OPTIONS"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .map: return "map.fill"
        case .deck: return "person.3.fill"
        case .bus: return "bus.fill"
        case .events: return "flame.fill"
        case .zombiepedia: return "book.closed.fill"
        case .shop: return "cart.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct ZWMainRootView: View {
    @ObservedObject private var save = ZWSaveGameService.shared
    @State private var selectedTab: ZWHubTab = .map
    @State private var activeBattle: (mode: ZWBattleMode, mission: ZWMissionConfig)?
    @State private var showSplash: Bool = true

    public init() {}

    public var body: some View {
        ZStack {
            ZWPalette.voidBlack.ignoresSafeArea()

            if let battle = activeBattle {
                ZWBattleView(mode: battle.mode, mission: battle.mission) {
                    activeBattle = nil
                    ZWSoundEngine.shared.playMusic(.menu)
                }
            } else {
                VStack(spacing: 6) {
                    topCurrencyBar
                    Group {
                        switch selectedTab {
                        case .map:
                            ZWWorldMapView { mode, mission in
                                activeBattle = (mode, mission)
                            }
                        case .deck:
                            ZWTeamDeckView()
                        case .bus:
                            ZWBusGarageView()
                        case .events:
                            ZWSpecialModesView { mode, mission in
                                activeBattle = (mode, mission)
                            }
                        case .zombiepedia:
                            ZWZombiepediaView()
                        case .shop:
                            ZWShopAndDailiesView()
                        case .settings:
                            ZWProfileSettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    bottomNavDock
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            // Evidence: LaunchScreen-iPhone.nib (#000000 + Splash.png)
            if showSplash {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image("Splash")
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(24)
                }
                .transition(.opacity)
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            ZWSoundEngine.shared.playMusic(.menu)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(.easeOut(duration: 0.35)) {
                    showSplash = false
                }
            }
        }
    }

    private var topCurrencyBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ZWOutlineText("RANK \(save.data.playerRank)", palette: "ExpSolid", font: ZWTypography.impact(12))
                Text("★\(save.totalStars)")
                    .font(ZWTypography.mono(11))
                    .foregroundColor(ZWPalette.coinGold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ZWPalette.hudBarBackground)
            .cornerRadius(6)

            Spacer()

            currencyPill(icon: "lootIcon_fuel", fallback: "fuelpump.fill", value: "\(save.data.fuel)/\(save.data.maxFuel)", color: ZWPalette.hazardOrange)
            currencyPill(icon: "bar_keys", fallback: "key.fill", value: "\(save.data.blueKeys)/\(save.data.redKeys)", color: ZWPalette.courageBlue)
            currencyPill(icon: "award_water", fallback: "bolt.fill", value: "\(save.data.powerPoints)", color: ZWPalette.courageBlue)
            currencyPill(icon: "bar_coins", fallback: "dollarsign.circle.fill", value: "\(save.data.coins)", color: ZWPalette.coinGold)
            currencyPill(icon: "award_rage", fallback: "banknote.fill", value: "\(save.data.cash)", color: ZWPalette.cashGreen)
        }
    }

    private func currencyPill(icon: String, fallback: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            ZWPixelSpriteView(icon, folder: .ui, fallbackSymbol: fallback)
                .frame(width: 16, height: 16)
            Text(value)
                .font(ZWTypography.mono(11))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ZWPalette.hudBarBackground)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(ZWPalette.panelBorder.opacity(0.6), lineWidth: 1)
        )
    }

    private var bottomNavDock: some View {
        HStack(spacing: 8) {
            ForEach(ZWHubTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    selectedTab = tab
                    ZWSoundEngine.shared.playTapHaptic()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 12, weight: .bold))
                        Text(tab.rawValue)
                            .font(ZWTypography.impact(11))
                    }
                    .foregroundColor(isSelected ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? ZWPalette.coinGold : ZWPalette.panelSlate)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isSelected ? Color.white.opacity(0.7) : ZWPalette.panelBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
