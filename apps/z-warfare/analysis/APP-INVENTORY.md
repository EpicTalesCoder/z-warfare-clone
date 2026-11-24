# iOS App Evidence Inventory — `z-warfare`

- **Decryption Status**: **PASS — DECRYPTED (`cryptid == 0`)**: Ready for REA / Ghidra / Hopper / IDA decompilation.
- **App Bundle**: `DeadAheadZombieWarfare.app`
- **Main Executable**: `DeadAheadZombieWarfare` (87,936 B)
- **CFBundleIdentifier**: `com.mobirate.DeadAheadTactics`
- **Display Name**: `Z Warfare`
- **Version / Build**: `4.4.7` (`4.4.7.257`)
- **Original MinimumOSVersion**: `10.0` (Rebuild target: **`iOS 16.0` for iPhone XS Max iOS 16.1.1**)
- **Detected Runtime Stack**: Unity IL2CPP, Objective-C
- **Assets.car**: Assets.car (1,540,088 B) — 45 renditions, 4 unique names
- **Exported Localizations**: 96 `.strings`/`.stringsdict` file(s) -> `analysis/metadata/strings-lproj/`

## 1. Main Mach-O Slices & FairPlay Check

| Arch | 64-bit | `cryptid` | Encrypted? | MinOS | SDK |
|---|---|---|---|---|---|
| `arm64` | True | `[0]` | NO (OK) | `15.0.0` | `26.0.0` |

## 2. Embedded Frameworks & Dynamic Libraries

| Framework / Dylib | Size | Archs | Encrypted? | MinOS |
|---|---:|---|---|---|
| `UnityFramework.framework` | 141,941,072 B | `arm64` | NO | `15.0.0` |
| `FBAudienceNetwork.framework` | 7,113,728 B | `arm64` | NO | `13.0.0` |
| `InMobiSDK.framework` | 6,479,760 B | `arm64` | NO | `12.0.0` |
| `AppLovinSDK.framework` | 5,572,064 B | `arm64` | NO | `12.0.0` |
| `MolocoSDK.framework` | 5,083,008 B | `arm64` | NO | `12.0.0` |
| `FBSDKCoreKit.framework` | 3,437,984 B | `arm64` | NO | `12.0.0` |
| `FBSDKGamingServicesKit.framework` | 1,196,544 B | `arm64` | NO | `12.0.0` |
| `FBSDKLoginKit.framework` | 969,728 B | `arm64` | NO | `12.0.0` |
| `FBSDKShareKit.framework` | 853,664 B | `arm64` | NO | `12.0.0` |
| `HelpshiftX.framework` | 736,144 B | `arm64` | NO | `10.0.0` |
| `FBAEMKit.framework` | 615,776 B | `arm64` | NO | `12.0.0` |
| `FBSDKCoreKit_Basics.framework` | 162,672 B | `arm64` | NO | `12.0.0` |
| `MCSDKMaterialPlugin.framework` | 134,096 B | `arm64` | NO | `12.0.0` |

## 3. Permissions, URL Schemes, Extensions & Resources

- **Permissions (`NS*UsageDescription`)**: `NSBluetoothAlwaysUsageDescription`, `NSCameraUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSLocationAlwaysUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSUserTrackingUsageDescription`
- **URL Schemes (`CFBundleURLTypes`)**: `fb1455350928112153`, `mbrtdazw`, `dazw`
- **App Extensions (`PlugIns/*.appex`)**: `PlugIns/Unity-iPhoneStickers.appex`
- **Bundled Fonts**: *(none)*
- **CoreData / Databases**: *(none)*
- **Interface Builder (`.nib` / `.storyboardc`)**: 25 item(s) — samples: `Frameworks/AppLovinSDK.framework/AppLovinSDKResources.bundle/ALDDetailTableViewCell.nib`, `Frameworks/AppLovinSDK.framework/AppLovinSDKResources.bundle/ALDMultiAdViewController.storyboardc`, `Frameworks/AppLovinSDK.framework/AppLovinSDKResources.bundle/ALDMultiAdViewController.storyboardc/3jf-B1-XNL-view-Iqa-CO-DFs.nib`, `Frameworks/AppLovinSDK.framework/AppLovinSDKResources.bundle/ALDMultiAdViewController.storyboardc/ALDMultiAdViewController.nib`, `Frameworks/AppLovinSDK.framework/AppLovinSDKResources.bundle/ALDRightDetailTableViewCell.nib`, `Frameworks/AppLovinSDK.framework/AppLovinSDKResources.bundle/MANativeAdBannerView.nib`, `Frameworks/AppLovinSDK.framework/AppLovinSDKResources.bundle/MANativeAdLeaderView.nib`, `Frameworks/AppLovinSDK.framework/AppLovinSDKResources.bundle/MANativeAdMRecView.nib`, `Frameworks/AppLovinSDK.framework/AppLovinSDKResources.bundle/MANativeAdMediaBannerView.nib`, `Frameworks/AppLovinSDK.framework/AppLovinSDKResources.bundle/MANativeAdTemplate1.nib`, `Frameworks/AppLovinSDK.framework/AppLovinSDKResources.bundle/MANativeAdVerticalBannerView.nib`, `Frameworks/AppLovinSDK.framework/AppLovinSDKResources.bundle/MANativeAdVerticalLeaderView.nib`

## 4. File Type Breakdown

| Extension | Count |
|---|---:|
| `.ab` | 349 |
| `.manifest` | 349 |
| `.png` | 242 |
| `.strings` | 96 |
| `.plist` | 70 |
| `(no-ext)` | 42 |
| `.xcprivacy` | 42 |
| `.nib` | 24 |
| `.gif` | 22 |
| `.json` | 19 |
| `.mp3` | 18 |
| `.car` | 6 |
| `.dat` | 6 |
| `.js` | 6 |
| `.html` | 6 |
| `.assets` | 4 |
| `.txt` | 3 |
| `.config` | 2 |
| `.ress` | 2 |
| `.ignore` | 2 |

## 5. Next Steps (Stage 1 -> Stage 4)
1. Verify **Decryption Status** above is `PASS (cryptid == 0)`.
2. Run REA `open_bundle_resources` (`inspect_plist`, `decode_interface_builder`, `inspect_asset_catalog`, `inspect_keyed_archive`) and `open_binary` (`project_apple_application_graph`, `inspect_macho`, `inspect_signature`, Ghidra/Hopper/IDA).
3. Write `apps/z-warfare/analysis/ARCHITECTURE-MAP.md` before coding `ios-app/Sources/`.
