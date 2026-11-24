# ARCHITECTURE MAP — Z Warfare (`Dead Ahead: Zombie Warfare` v4.4.7 — 1:1 iOS 16.1.1 / iPhone XS Max Rebuild)

> **Evidence Lock**: Every claim below is directly observed from static inspection, REA `inspect-il2cpp-metadata` / `inspect-asset-catalog` / `decode-interface-builder`, UnityFS/SerializedFile extraction, and `objdump` ARM64 disassembly of `apps/Z Warfare-4.4.7.ipa` (`SHA-256: 8083342a40555833...`, recorded in `apps/z-warfare/analysis/ASSETS-SHA256.txt`) in `apps/z-warfare/analysis/metadata/` and `apps/z-warfare/analysis/decompiled/`.

---

## 1. Binary, Signing, Encryption & Target Hardware Matrix

| Field | Original Shipped Binary (`DeadAheadZombieWarfare.app`) | Rebuild Target Profile (`apps/z-warfare/ios-app`) |
|---|---|---|
| **Display Name / Executable** | `Z Warfare` / `DeadAheadZombieWarfare` (`87,936 B` stub) + `Frameworks/UnityFramework.framework/UnityFramework` (`141,941,072 B`) | `Z Warfare` / `ZWarfare` |
| **Bundle Identifier** | `com.mobirate.DeadAheadTactics` (Original) | `com.rebuild.zwarfare` (Parallel installable alongside original; original Team ID `98BXR499L4`, Game Center enabled) |
| **Version / Build** | `4.4.7` (`4.4.7.257`, `build.number=257`, `build.timestamp=2026-10-27 16:11:17`) | `4.4.7` (`4.4.7.257`) |
| **Mach-O / FairPlay Status** | `arm64`, **`cryptid 0` — DECRYPTED** across main binary, `UnityFramework`, all 12 third-party frameworks, and `Unity-iPhoneStickers.appex` | `arm64` (`ARCHS: arm64`, `ONLY_ACTIVE_ARCH: NO`, `-sdk iphoneos` Release) |
| **OS Deployment Target** | `Info.plist` `MinimumOSVersion 10.0`; Mach-O `LC_BUILD_VERSION minos 15.0.0`, `sdk 26.0.0` | `IPHONEOS_DEPLOYMENT_TARGET: "16.0"` (`<= 16.1`), `SWIFT_VERSION: "5.0"` |
| **Target Device & Geometry** | Universal (`UIDeviceFamily [1, 2]`), **Landscape-Only** (`UIInterfaceOrientationLandscapeLeft` / `LandscapeRight`), `UIStatusBarHidden = true`, `UIRequiresFullScreen = true` | Locked **iPhone XS Max** (`iPhone11,6`/`iPhone11,4`, `896×414 pt @3x` Landscape = `2688×1242 px`, Landscape Safe Area Left/Right `44 pt`, Bottom `21 pt`, Top `0 pt`, 60 Hz OLED, 4 GB RAM) |
| **Original Runtime Stack** | Unity `2022.3.62f3` IL2CPP (`global-metadata.dat` v31: 97 images, 18,083 types, 131,009 methods, 23,324 string literals), `Physics2D`, `SpriteMask`, `TextMeshPro`, `DOTween`, `Cinemachine`, `UIElements` + 349 LZ4 AssetBundles + 18 MP3 music tracks | 100% Native **Swift 5 + SwiftUI + SpriteKit + UIKit + AVFoundation** (60 Hz SpriteKit 2D lane engine + native SwiftUI HUD/Menus/Garage/Map/Shop/Zombiepedia/Metro/Skirmish) |
| **CI Packaging** | App Store signed (`SC_Info/`) | `.github/workflows/ios-build-ipa.yml` -> inside-out ad-hoc signed `.ipa` for **TrollStore 2**, **Sideloadly**, **AltStore**, **SideStore** |

---

## 2. Info.plist, Entitlements, URL Schemes, Permissions & Extensions

Source evidence: [Info.plist.xml](./metadata/Info.plist.xml), [entitlements.xml](./metadata/entitlements.xml), [interface-builder.json](./decompiled/interface-builder.json), [asset-catalog.json](./decompiled/asset-catalog.json).

- **Orientations & Status Bar**:
  - `UISupportedInterfaceOrientations`: `UIInterfaceOrientationLandscapeRight`, `UIInterfaceOrientationLandscapeLeft` (Landscape-locked!).
  - `UIStatusBarHidden = true`, `UIRequiresFullScreen = true`.
- **Launch Screen (`LaunchScreen-iPhone.nib`)**:
  - Decoded by REA `decode-interface-builder`: Root `UIView` with `UISystemColorName = blackColor` (`#000000`) containing a `UIImageView` (`Splash.png`, `119,334 B`) centered with `centerX`, `top`, `bottom` `NSLayoutConstraint`s.
- **App Icons (`Assets.car`)**:
  - Primary `AppIcon` (`1024×1024` + `@2x`/`@3x` slots, `AppIcon60x60@2x.png`, `AppIcon76x76@2x~ipad.png`) + alternate icon `MAR-1721_v1`.
- **URL Schemes & Queries**:
  - `CFBundleURLTypes`: `fb1455350928112153`, `mbrtdazw`, `dazw`.
  - `LSApplicationQueriesSchemes`: `fbapi`, `fb-messenger-api`, `fbauth2`, `fbshareextension`, `daone`.
- **Entitlements (`entitlements.xml`)**:
  - `aps-environment: production`, `com.apple.developer.game-center: true`. (For unsigned/ad-hoc TrollStore/Sideloadly builds, `Entitlements.plist` keeps clean compatibility without tying to provisioning-locked push entitlement.)
- **App Extension (`PlugIns/Unity-iPhoneStickers.appex`)**:
  - Contains 22 animated `.gif` iMessage stickers (`stiker_billHello_400.gif`, `stiker_freehugsidle_400.gif`, `stiker_charlotteBang_400.gif`, etc.). Omitted from standalone unsigned iOS 16 main target to avoid Free Apple ID App ID cap (`Sideloadly`/`AltStore`), documented here cleanly.
- **Supported Localizations (`CFBundleLocalizations` & `37_localization.txt`)**:
  - 12+ languages observed in `Data/resources.assets/localization` (`2,745` keys): `en`, `fr`, `de`, `it`, `br` (`pt`), `ru`, `zhs` (`zh-Hans`), `es`, `zht` (`zh-Hant`), `ja`, `ko`, `tr`.

---

## 3. Excluded Ad / Tracking / Third-Party SDKs (Clean Native Substitution)

Per project steering (neutralize intrusive ad, tracking, and third-party billing/telemetry SDKs cleanly with documentation):

- **Excluded Frameworks & Assemblies**:
  - **Ad / Mediation / Attribution**: `AppLovinSDK.framework`, `FBAudienceNetwork.framework`, `InMobiSDK.framework`, `MolocoSDK.framework`, `MCSDKMaterialPlugin.framework`, `MobirateAudienceNetwork.dll`, `Yodo1.MAS`, `GoogleMobileAds*`, `AppsFlyer.dll`, `SKAdNetworkItems` (200+ IDs). (Also removes unused ad-triggered `NSLocation*UsageDescription`, `NSBluetoothAlwaysUsageDescription`, `NSUserTrackingUsageDescription` TCC prompts!)
  - **Social / Telemetry / External Payment**: `FBSDKCoreKit*`, `FBSDKLoginKit`, `FBSDKShareKit`, `FBSDKGamingServicesKit`, `FBAEMKit`, `Firebase*`, `AWSSDK.*` (Cognito/Lambda/KinesisFirehose/STS), `Xsolla.SDK.*`, `HelpshiftX.framework`, `Pley.dll`, `Unity.Services.Analytics`.
- **Native iOS 16.1.1 Substitutes**:
  - **Audio / Music**: `AVAudioPlayer` (`AVFoundation`) playing extracted original `MusicMp3/*.mp3` + sound effects extracted from `sounds/*.ab`.
  - **Storage / Persistence**: Native `FileManager` JSON + `UserDefaults` + `CryptStream` XOR/GZIP compatibility layer (`0x03b9c8ac`) matching `SaveData` & `SaveGameJsonLoader` (`0x03bb3760`).
  - **Haptics & Input**: `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` (iOS 16-safe).
  - **Rendering**: 60 Hz `SpriteKit` (`SKScene` / `SKView`) for the real-time 2D zombie lane battlefield, bus, parallax backgrounds, projectiles, explosions, and unit/zombie sprite animation, paired with native `SwiftUI` (`ObservableObject` + `@Published` + `NavigationStack`) for HUD, World Map, Garage/Bus Upgrade, Unit Deck, Shop/Trader/Roulette, Dailies, Zombiepedia, Infected Metro, and Skirmish PvP.

---

## 4. Visual Design System & Recovered Resources

### 4.1 Exact Color Palette (`TextColorsPalette`, `Data/resources.assets` PID 93)
Extracted directly from `TextColorsPalette` (`59` entries, `36 B` stride, primary fill + outline RGBA):

| Token | Fill RGBA | Outline RGBA | Usage |
|---|---|---|---|
| `WhiteSolid` | `#FFFFFF` (`a=1.00`) | `#000000` (`a=0.60`) | Primary HUD / button text |
| `WhiteTransparent` | `#FFFFFF` (`a=0.60`) | `#2D2D30` (`a=1.00`) | Secondary / muted labels |
| `GoldSolid` | `#FFFF66` (`a=1.00`) | `#000000` (`a=0.60`) | Coins, stars, crit damage |
| `GreenSolid` | `#99FF00` (`a=1.00`) | `#000000` (`a=0.60`) | Cash / green bills / upgrade gains |
| `WaterColor` | `#66FFFF` (`a=1.00`) | `#000000` (`a=1.00`) | Courage (battle spawn energy) |
| `RageColor` | `#FF3399` (`a=1.00`) | `#000000` (`a=1.00`) | Rage points (support items / bus skill) |
| `ExpSolid` | `#029DC9` (`a=1.00`) | `#000000` (`a=0.60`) | Player XP / Rank progress |
| `KeysColor` | `#00CCFF` (`a=1.00`) | `#000000` (`a=0.60`) | Supply Run blue keys |
| `RedKeysColor` | `#FF7F66` (`a=1.00`) | `#000000` (`a=0.60`) | Red keys |
| `SkinCoins` | `#67DDFF` (`a=1.00`) | `#000000` (`a=0.60`) | Skin tokens |
| `CharmPoints` | `#FF9F00` (`a=1.00`) | `#000000` (`a=0.60`) | Charm upgrade points |
| `WarningMessage` | `#FF3333` (`a=1.00`) | `#000000` (`a=0.60`) | Final wave / boss / insufficient warnings |
| `DarkRedSolid` / `RedWithoutOutline` | `#912004` / `#D13304` | `#2D2D30` / clear | Enemy damage, zombie kills |
| `OrangeSolid` | `#FFCC00` (`a=1.00`) | `#000000` (`a=0.60`) | Legendary / special ability highlights |
| `ZombiepediaDescr` / `LegacyBattleDeckMenu` | `#4C534C` (`a=1.00`) | `#000000` (`a=0.10`) | Notebook paper body text |
| `ZombiepediaKills` | `#D13304` (`a=1.00`) | `#000000` (`a=0.10`) | Zombie kill tally |
| `Difficulty0..5` | `#79CF02`, `#CCCFCE`, `#D9552E`, `#FF67F7`, `#FBCE32`, `#A472FF` | `#2D2D30` (`a=1.00`) | Mission difficulty badges (Normal -> Nightmare) |
| `PvpSolid` / `PvpNew` | `#D5D3C0` / `#D4ABA3` | `#000000` / `#781E00` | Skirmish PvP slate panels |

### 4.2 Extracted Audio, Textures & Fonts
- **AppIcon & Splash**: Extracted from `Assets.car` / `AppIcon60x60@2x.png` + `Splash.png` (`119,334 B`).
- **Music (`Data/Raw/MusicMp3/`)**: 18 `.mp3` tracks (`menu_ost.mp3`, `battle_ost.mp3`, `final_wave.mp3`, `pvp_ost.mp3`, `metro.mp3`, `bridge_battle.mp3`, `dungeon_battle.mp3`, `halloween_battle.mp3`, `saving_hero_battle.mp3`, `summer_battle.mp3`, `weekly_event.mp3`, etc.).
- **Bitmap / Pixel Fonts (`fonts/eu.ab`)**: `Eu_PSK8`, `Eu_Impact15`, `Eu_Impact30`, `Eu_Arial10` + UI sprites extracted from `bundles/common.ab`, `bundles/battle.ab`, `bundles/map.ab`, `bundles/zombiepedia.ab`, `battleunits/*.ab`, `busskin/*.ab`, `backgroundmanager/*.ab`.
- **Localization**: Full `localization.json` (`2,745` entries in 12+ languages) from `Data/resources.assets` PID 37.

---

## 5. Complete Screen & Navigation Architecture (192 Observed Menu/Panel Classes)

Entry & boot pipeline (`level0` -> `level1` -> `scenes/splash.ab` -> `scenes/map.ab` -> `scenes/battle.ab`):

1. **Splash / Boot (`scenes/splash.ab`, `WebConfigLoader` `0x03b60174`)**:
   - Black `#000000` backdrop + `Splash.png` (`LaunchScreen-iPhone.nib`), loads localizations, `SaveData` (`SaveGameService`), config database, and routes to World Map (`MapMenuManager` `Type#4440`).
2. **World Map Hub (`scenes/map.ab`, `MapMenuManager`, `MapLoader`, `MissionsStorage`)**:
   - Interactive pan/zoom campaign map covering **Locations 1–10** with **594 Campaign Missions** (`102..1104`) and tile grids decoded directly from `resources.assets` (`missions` + `map` + `blocked_groups`).
   - **Top HUD Bars**: Player Rank + XP (`RankStorage`), Fuel/Stamina (`MaxStamina`), Coins (`GoldSolid`), Cash/Green Bills (`GreenSolid`), Blue/Red Keys, Skin Tokens.
   - **Left/Bottom Quick Nav Dock**:
     - **Deck / Team (`TeamMenu`, `BattleDeckMenu`, `UnitDetailsMenu`, `UnitStatsMenu`, `UnitUpgradeManager`, `CharmsManager`, `SkillMasteryMenu`, `SynergyInfoMenu`)**: Configure 6-slot active battle deck (Units + Support Items), inspect stats, level up units (`1..MaxUnitLevel`), equip 4 Gear Set items (Cup, Watch, Knife, Book) & Charms, unlock Special Abilities (`BuySpecialPowerMenu`), view Team Power Synergies (`SynergyManager`).
     - **Bus Garage (`BusUpgradeMenu`, `CarPartsManager`, `PaintManager`, `BusCharacteristicsStorage`)**: Upgrade Bus level (`MaxBusLevel`), equip bus parts (Wheels, Pipe, TopPipe, Window, Step), apply 28 Bus Skins (`busskin/*.ab`).
     - **Shop & Trader (`ShopMenu`, `ResourceShopMenu`, `TraderMenu`, `RouletteMenu`, `SafeMenu`, `PiggyBankManager`, `SeasonalBattlePassManager`)**: Resource packs, Daily Trader craft/deals, Safe/Piggy Bank, Roulette wheel.
     - **Dailies & Quests (`DailiesMenu`, `DailyQuestManager`, `ExperienceQuestManager`, `TimeBoxes`, `DungeonManager`)**: Daily Quests, Chapter Tasks, Time Boxes, Supply Runs (`d1..d10`, `d1c..d10c`).
     - **Zombiepedia (`ZombiepediaMenu`, `ZPPageContentUnit`)**: Interactive two-page field guide with survival time, kill counters, unit/zombie tabs, and Zombiepedia kill-milestone claims (`ZombiepediaReward`).
     - **Special Modes**:
       - **Skirmish PvP (`PVPMenu`, `PvpController`, `PVPLeagues`)**: Asynchronous 6-slot squad auto-battle Arena (`PVPBattleJudge`).
       - **Infected Metro (`MetroMenu`, `MetroController`, `MetroManager`)**: 12 stations × 3 stages timed challenge mode with rotating decks (`MetroBattleSettings`).
       - **Bridge / Weekly Events (`BridgeMenu`, `WeeklyEventMenu`)**: Corn Farm, Harvest Day, Princess Rescue, Wall Mart, Halloween, Xmas, Last Resort (`RoguelikeConfig`).
       - **Profile & Settings (`ProfileMenu`, `LanguageSelectMenu`, `UnitCollectionRewardsMenu`, `StarsRewardMenu`)**: Language switcher across 12 languages, sound/music toggles, Star Road rewards (`StarsManager`).
3. **Battle Enter Modal (`BattleEnterMenu`, `MissionFeaturesPanel`)**:
   - Displays mission ID, difficulty (`Difficulty0..5`), fuel cost, star objectives, enemy preview list, weather/hazard badges (Rain, Sandstorm, Toxic Fog), and `Start` button.
4. **Real-Time 2D Lane Battle (`scenes/battle.ab`, `GameController` `Type#902`, `CampaignController` `Type#915`, `BaseBattleUI`)**:
   - **Battlefield Geometry (`GameController`)**: Side-scrolling 2D lane with depth-sorted Z-band (`RoadMinZ..RoadMaxZ`, `RoadMiddleZ`), Player School Bus on left (`DefaultBusBorderX`), Zombie Barricade on right (`DefaultBarricadePositionX`), offscreen zombie spawn (`OffscreenZombieLeft`), `MaxBattleSpeed` (1x / 2x via `BattleSpeedUpButton`).
   - **Resources (`WaterManager` `0x034ac5bc`, `FuryManager` `0x03c37afc`)**:
     - **Courage (Water)**: Regenerates continuously (`WaterManager.OnUpdated` `0x034ada4c`), plus +25 Courage drops (`WaterDrop`) during battle; used to deploy survivor units from the 6-card bottom deck (`BattleUnitCell`, `BattleHireCostManager.GetCost` `0x03c26a04`), gated by per-unit prepare cooldown (`UnitUpgradeManager.CalcPrepareTimeInternal` `0x03782100`).
     - **Rage (Fury)**: Earned from zombie kills/hits (`BonusZombieRage`); used to deploy Support Items (`item_barrel`, `item_red_barrel`, `item_molotov`, `item_medkit`, `item_nitrogen`, `item_generator`, `item_turret`, `item_mine`, `item_drone`) and Bus Machine Gun Barrage (`BillBehaviour`).
   - **Unit AI & Combat (`CommonUnitBehaviour`, `CommonHumanBehaviour`, `ZombieBehaviour`, `AttackManager.DoAttack` `0x03c1d7c0`)**:
     - Target acquisition (`UnitTargeter`), lane movement (`UnitMover`), melee/ranged attacks (`UnitShootingUtils`), critical hits, knockback (`PushManager`), elemental status (`FireManager`, `FreezeManager`, `BleedingManager`, `PoisonManager`), resistances (`MeleeResist`, `BulletResist`, `FireResist`, `ExplosionResist`, `PoisonResist`), resurrection (`CorpseManager`: dead humans turn into zombies unless `ResurrectResist`), Team Power Synergies (`BattleSynergyManager`), and Final Wave timer (`FinalWaveUI`).
   - **End Battle (`VictoryMenu`, `DefeatMenu`, `UnitStatsMenu`)**:
     - Star calculation (Bus HP 100% = 3 stars, damaged = 2 stars, low = 1 star), 3-star reward bonus, XP/Coins/Items payout, and per-unit battle stats (`UnitStatsManager`: DamageDealt, MaxDamageDealt, DamageReceived, Kills, Healing).

---

## 6. Key Algorithms, Binary Citations & Static Provenance Boundary

### 6.1 Verified Binary Symbols & Formulas
- **`Crypt.CryptStream.Decrypt` (`0x03b9c8ac`) & `.ctor` (`0x03b9c5fc`)**:
  - 4-byte rotating key XOR + position shift: `decrypted[i] = ((raw[i] ^ key[pos & 3]) - pos + 56) & 0xFF`.
  - Verified against `Data/resources.assets` `packs` (`pid=42`, `3,820 B`) using key `0x235c5cf4` -> GZIP magic `1F 8B 08 00` -> `6,807 B` CSV (`168` rows).
- **`AttackManager.DoAttack` (`0x03c1d7c0`)**:
  - Pipeline verified via `objdump`: `TeamContent.RaiseBeforeCriticalAttackInflicted` (`0x34ddaec`) -> `BattleSpecialPowerManager.ModifyDamage` (`0x3460f3c`) -> `TeamDamageModificationManager.ModifyDamage` (`0x343b90c`) -> `TeamCritDamageModificationManager.ModifyCritDamage` (`0x343b5f0`) -> `CommonBehaviour.HandleAttackReceived` (`0x340150c`) -> `RaiseAfterCriticalAttackInflicted` (`0x34ddb08`) -> `RaiseAttackInflicted` (`0x34015ac`) -> `RaiseKillGained` (`0x34dda7c`) / `RaiseDamagePreventedByChance` (`0x34ddad0`).
- **`UnitUpgradeManager.BonusBattle.UpgradeValue` (`0x03782228`) & `CalcPrepareTimeInternal` (`0x03782100`)**:
  - Aggregates 5 additive/multiplicative upgrade layers (`GetUpgradeValueSingleKind` `0x0378427c` with source indices `0, 4, 2, 1, 3`: Base/Level, Category/Mastery, Gear Items, Charm, Skin/Synergy).
  - Prepare time cooldown reduction formula observed at `0x3782544..0x3782548`: inverse agility/cooldown scaling (`15.0 / denom`).
- **`BattleHireCostManager.GetCost` (`0x03c26a04`)**:
  - Delegates to `UnitUpgradeManager.GetUnitHireCost` (`0x0377c52c`) applying item cost-reduction modifiers and deck/synergy discounts before `MutableCreatureCost`.
- **`WaterManager.OnUpdated` (`0x034ada4c`) & `SaveGameJsonLoader` (`0x03bb3760`)**:
  - Continuous courage regeneration tick (`SetWaterPerSecond` `0x034acab4`, `AddMultiplier` `0x034ad784`) and JSON-based local persistence (`SaveData` `Type#4818`).

### 6.2 Network Endpoints & Remote Config Provenance Boundary
- **Observed Endpoints in `il2cpp-string-literals.txt`**:
  - Config CDN: `https://dazw-dl.mobirate.com/cfg/ios/{0}.cfg` and `https://dazw-dl-sel.mobirate.com/cfg/ios/{0}.cfg` (`WebConfigLoader.GetPrimaryCryptedConfigUrl` `0x03b60608`).
  - Popular Item Sets: `https://dazw-dl.mobirate.com/popular-itemsets/data.json`.
  - Support / Legal: `https://mobirate.helpshift.com/hc/en/4-dead-ahead-zombie-warfare/`, `https://www.mobirate.com/privacy-policy`.
- **Static Provenance Boundary (`primarydata.cfg`)**:
  - `WebConfigLoader` (`0x03b60174..0x03b6ae88`) retrieves the dynamic balance table (`primarydata.cfg` containing numeric `WebConfigParams`, `BattleParams`, unit/zombie HP/ATK tables, and per-mission wave spawn lists) from `https://dazw-dl.mobirate.com/cfg/ios/{0}.cfg` as a `CryptStream`-encoded gzipped JSON payload; `primarydata.cfg` is NOT shipped inside `Data/resources.assets` of the App Store `.ipa`.
  - Meanwhile, **all 594 campaign mission IDs & map coordinates**, **all 10 location tile maps**, **all 2,745 localization strings (12 languages)**, **all 59 UI palette colors**, **all 161 unit/zombie/item AssetBundles**, **all 28 bus skins & 28 bus parts**, **all 39 battle backgrounds**, **all 18 MP3 music tracks**, and **all C# class schemas & combat/upgrade formulas** ARE present directly inside the `.ipa`.
  - The native iOS 16.1.1 rebuild implements the exact `CryptStream` + GZIP `WebConfigLoader` parser (`0x03b9c8ac`) so an authentic `primarydata.cfg` / `primarydata.json` can be imported or cached natively, paired with a complete, schema-exact bundled game catalog seeded from the extracted `.ipa` roster, mission coordinates, `localization.json`, `TextColorsPalette`, and `BattleParams` / `WebConfigParams` schemas.
