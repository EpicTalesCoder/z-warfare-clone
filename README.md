# Z Warfare (Clone)

1:1 native Swift rebuild targeting **iPhone XS Max (iPhone11,6 / 414x896 @3x / arm64)** on **iOS 16.1.1**.

## Project Metadata
- **Slug**: `z-warfare`
- **XcodeGen Target**: `ZWarfare`
- **Rebuild Bundle Identifier**: `com.rebuild.zwarfare`
- **Original Bundle / Source**: `com.mobirate.DeadAheadTactics` (`4.4.7`)
- **Deployment Target**: `iOS 16.0` (`arm64`, `SWIFT_VERSION: 5.0`)
- **Signing Mode**: `unsigned-adhoc-trollstore-sideloadly` (unsigned / inside-out ad-hoc signed `.ipa` for TrollStore 2, Sideloadly, AltStore, SideStore)

## Layout
- `apps/z-warfare/ios-app/` — XcodeGen `project.yml`, Swift `Sources/`, resources, and `Tests/`
- `apps/z-warfare/analysis/` — Static inventory, `ARCHITECTURE-MAP.md`, metadata, and disassembly evidence
- `.github/workflows/ios-build-ipa.yml` — Automated macOS CI pipeline building the `arm64` `.ipa` artifact

## Verification & Local Project Generation
```bash
python3 tools/verify-ios-parity.py z-warfare --ci
xcodegen generate --spec apps/z-warfare/ios-app/project.yml --project apps/z-warfare/ios-app
```
