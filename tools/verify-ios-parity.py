#!/usr/bin/env python3
"""
Hard Anti-Hallucination & iOS 16.1.1 (iPhone XS Max) Parity Gate.
Run:
  python3 tools/verify-ios-parity.py <slug>
  python3 tools/verify-ios-parity.py <slug> --ci

Exits 0 ONLY if all hard verification gates pass:
  1. Static analysis evidence intact (APP-INVENTORY.md, ARCHITECTURE-MAP.md, ASSETS-SHA256.txt, Info.plist.xml)
     and FairPlay decryption verified (no unresolved cryptid != 0 blocker)
  2. XcodeGen project.yml valid for iPhone XS Max / iOS 16.1.1:
     - deploymentTarget / IPHONEOS_DEPLOYMENT_TARGET <= 16.1 (recommended 16.0)
     - ARCHS includes arm64
     - SWIFT_VERSION pinned to 5.x (prevents Swift 6 breakage on GitHub Actions Xcode 16)
     - CODE_SIGNING_ALLOWED: NO (unsigned/ad-hoc CI mode)
     - Info.plist MinimumOSVersion <= 16.1
  3. Zero unguarded iOS 17+/18+ forbidden APIs in ios-app/Sources/**/*.swift
  4. Mandatory decompiled evidence citations (`// Port of ...` or `// Evidence: ...`) and zero unresolved UNVERIFIED markers
  5. XCTest unit/parity tests exist under ios-app/Tests/ and app is registered in apps/apps-manifest.json
"""
from __future__ import annotations

import argparse
import collections
import json
import pathlib
import plistlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# APIs introduced in iOS 17.0+ / 18.0+ that crash or fail compilation on iOS 16.1.1 unless wrapped in #available(iOS 17, *)
FORBIDDEN_IOS17_APIS: list[tuple[str, re.Pattern]] = [
    ("import Observation (iOS 17+)", re.compile(r"^\s*import\s+Observation\b", re.M)),
    ("@Observable macro (iOS 17+)", re.compile(r"@Observable\b")),
    ("@Bindable macro (iOS 17+)", re.compile(r"@Bindable\b")),
    ("import SwiftData (iOS 17+)", re.compile(r"^\s*import\s+SwiftData\b", re.M)),
    ("@Model macro (iOS 17+)", re.compile(r"@Model\b")),
    ("ContentUnavailableView (iOS 17+)", re.compile(r"\bContentUnavailableView\b")),
    ("UIContentUnavailableConfiguration (iOS 17+)", re.compile(r"\bUIContentUnavailableConfiguration\b")),
    (".sensoryFeedback (iOS 17+)", re.compile(r"\.sensoryFeedback\s*\(")),
    (".symbolEffect (iOS 17+)", re.compile(r"\.symbolEffect\s*\(")),
    (".scrollTargetBehavior (iOS 17+)", re.compile(r"\.scrollTargetBehavior\s*\(")),
    (".scrollPosition(id:) (iOS 17+)", re.compile(r"\.scrollPosition\s*\(")),
    (".containerRelativeFrame (iOS 17+)", re.compile(r"\.containerRelativeFrame\s*\(")),
    (".contentMargins (iOS 17+)", re.compile(r"\.contentMargins\s*\(")),
    ("PhaseAnimator / KeyframeAnimator (iOS 17+)", re.compile(r"\b(?:PhaseAnimator|KeyframeAnimator)\b")),
    ("import TipKit (iOS 17+)", re.compile(r"^\s*import\s+TipKit\b", re.M)),
    ("registerForTraitChanges (iOS 17+)", re.compile(r"\bregisterForTraitChanges\s*\(")),
    (".navigationTransition (iOS 18+)", re.compile(r"\.navigationTransition\s*\(")),
    # 2-parameter onChange(of: ...) { oldVal, newVal in } (iOS 17+)
    ("2-param .onChange(of:) { old, new in } (iOS 17+)", re.compile(r"\.onChange\s*\(\s*of:[^)]*\)\s*\{\s*[A-Za-z_][A-Za-z0-9_]*\s*,\s*[A-Za-z_][A-Za-z0-9_]*\s+in\b")),
]


def parse_version_tuple(ver: str) -> tuple[int, ...] | None:
    m = re.match(r"^\s*(\d+)(?:\.(\d+))?(?:\.(\d+))?\s*$", ver.strip().strip('"').strip("'"))
    if not m:
        return None
    major = int(m.group(1))
    minor = int(m.group(2) or 0)
    patch = int(m.group(3) or 0)
    return (major, minor, patch)


def has_available_ios17_guard(lines: list[str], idx: int) -> bool:
    start = max(0, idx - 6)
    window = "\n".join(lines[start : idx + 1])
    return bool(re.search(r"#available\s*\(\s*iOS\s+1[789]", window))


def main() -> None:
    parser = argparse.ArgumentParser(description="Verify iOS 16.1.1 (iPhone XS Max) rebuild evidence, API compliance, and CI spec.")
    parser.add_argument("slug", help="App folder slug under apps/")
    parser.add_argument(
        "--ci",
        action="store_true",
        help="CI mode: do not require gitignored original/*.ipa or analysis/extracted/ on GitHub Actions runners",
    )
    args = parser.parse_args()

    slug = args.slug
    app_dir = ROOT / "apps" / slug
    orig_dir = app_dir / "original"
    analysis_dir = app_dir / "analysis"
    ios_dir = app_dir / "ios-app"

    failures: list[str] = []
    warnings: list[str] = []
    passed: list[str] = []

    if not app_dir.exists():
        print(f"[FAIL] App directory not found: {app_dir}")
        sys.exit(1)

    # Gate 1: Original artifact (local) & Static Evidence + Decryption verification
    if not args.ci:
        ipas = sorted(orig_dir.glob("*.ipa")) if orig_dir.exists() else []
        apps = sorted(orig_dir.glob("*.app")) if orig_dir.exists() else []
        if ipas and ipas[0].stat().st_size > 0:
            passed.append(f"Original IPA intact: {ipas[0].name} ({ipas[0].stat().st_size:,} B)")
        elif apps:
            passed.append(f"Original .app bundle intact: {apps[0].name}")
        else:
            warnings.append(f"No original .ipa/.app in apps/{slug}/original/ (expected locally; ignored in git)")

    inv_path = analysis_dir / "APP-INVENTORY.md"
    arch_path = analysis_dir / "ARCHITECTURE-MAP.md"
    sha_path = analysis_dir / "ASSETS-SHA256.txt"
    info_xml = analysis_dir / "metadata" / "Info.plist.xml"

    if inv_path.is_file() and inv_path.stat().st_size > 100:
        inv_txt = inv_path.read_text(encoding="utf-8", errors="replace")
        if "FAIRPLAY ENCRYPTED" in inv_txt or "YES (BLOCKED)" in inv_txt:
            failures.append(
                f"apps/{slug}/analysis/APP-INVENTORY.md reports FairPlay encryption (cryptid != 0) — dump decrypted IPA first"
            )
        else:
            passed.append("APP-INVENTORY.md present & FairPlay cryptid == 0 verified")
    else:
        failures.append(f"Missing apps/{slug}/analysis/APP-INVENTORY.md (run python3 tools/prepare-ios-evidence.py {slug})")

    if arch_path.is_file() and arch_path.stat().st_size > 150:
        passed.append("ARCHITECTURE-MAP.md present (Stage 1 complete)")
    else:
        failures.append(f"Missing or incomplete apps/{slug}/analysis/ARCHITECTURE-MAP.md (required from Stage 1)")

    if sha_path.is_file() and sha_path.stat().st_size > 32:
        passed.append("ASSETS-SHA256.txt integrity manifest present")
    else:
        failures.append(f"Missing apps/{slug}/analysis/ASSETS-SHA256.txt")

    if info_xml.is_file() and info_xml.stat().st_size > 50:
        passed.append("metadata/Info.plist.xml evidence present")
    else:
        failures.append(f"Missing apps/{slug}/analysis/metadata/Info.plist.xml")

    # Gate 2: XcodeGen project.yml & iOS 16.1.1 / iPhone XS Max build settings
    proj_yml = ios_dir / "project.yml"
    if not proj_yml.is_file():
        failures.append(f"Missing XcodeGen spec: apps/{slug}/ios-app/project.yml")
    else:
        yml_txt = proj_yml.read_text(encoding="utf-8", errors="replace")
        passed.append("XcodeGen project.yml present")

        # Check all deployment targets are <= 16.1
        dt_matches = re.findall(r'(?:IPHONEOS_DEPLOYMENT_TARGET|deploymentTarget|iOS)\s*:\s*["\']?(\d+(?:\.\d+)*)["\']?', yml_txt)
        if not dt_matches:
            failures.append("project.yml does not explicitly set iOS deploymentTarget / IPHONEOS_DEPLOYMENT_TARGET (must be <= 16.1)")
        else:
            bad_dt = []
            for v in dt_matches:
                vt = parse_version_tuple(v)
                if vt is None or vt > (16, 1, 1):
                    bad_dt.append(v)
            if bad_dt:
                failures.append(f"project.yml contains deployment target > iOS 16.1.1: {bad_dt} (must be 16.0 or <= 16.1)")
            else:
                passed.append(f"Deployment target compatible with iOS 16.1.1 ({sorted(set(dt_matches))})")

        if not re.search(r"ARCHS\s*:\s*.*arm64", yml_txt):
            failures.append("project.yml missing ARCHS: arm64 (required for iPhone XS Max A12)")
        else:
            passed.append("Architecture locked to arm64 (iPhone XS Max A12)")

        if not re.search(r'SWIFT_VERSION\s*:\s*["\']?5(?:\.\d+)?["\']?', yml_txt):
            warnings.append('project.yml should set SWIFT_VERSION: "5.0" to avoid Swift 6 strict-concurrency build errors on Xcode 16 CI')
        else:
            passed.append('SWIFT_VERSION locked to 5.x (Xcode 16 CI safe)')

        if not re.search(r"CODE_SIGNING_ALLOWED\s*:\s*(?:NO|false)", yml_txt, re.I):
            warnings.append("project.yml should set CODE_SIGNING_ALLOWED: NO for unsigned/ad-hoc CI builds")
        else:
            passed.append("Unsigned/ad-hoc CI signing settings present (CODE_SIGNING_ALLOWED: NO)")

        mv_match = re.search(r'^\s*MARKETING_VERSION\s*:\s*["\']?([^"\'\n#]+)["\']?', yml_txt, re.M)
        bv_match = re.search(r'^\s*CURRENT_PROJECT_VERSION\s*:\s*["\']?([^"\'\n#]+)["\']?', yml_txt, re.M)
        if not mv_match or not bv_match:
            failures.append(
                "project.yml must explicitly set MARKETING_VERSION and CURRENT_PROJECT_VERSION "
                "(run python3 tools/bump-ios-version.py <slug>)"
            )
        else:
            mkt_ver = mv_match.group(1).strip()
            bld_ver = bv_match.group(1).strip()
            if mkt_ver == "1.0.0":
                failures.append(
                    f"MARKETING_VERSION is still '1.0.0' — bump rebuild version via `python3 tools/bump-ios-version.py {slug}`"
                )
            elif not re.match(r"^\d+\.\d+(?:\.\d+)?$", mkt_ver):
                failures.append(f"Invalid MARKETING_VERSION '{mkt_ver}' in project.yml (expected X.Y or X.Y.Z)")
            else:
                passed.append(f"Rebuild version configured: {mkt_ver} ({bld_ver})")

        # Verify Info.plist & Entitlements.plist exclusions + folder-ref excludes (prevents Xcode 16 'Multiple commands produce' CI break)
        if "Resources/Info.plist" not in yml_txt or "Resources/Entitlements.plist" not in yml_txt:
            failures.append("project.yml Sources.excludes must exclude Resources/Info.plist and Resources/Entitlements.plist")
        else:
            passed.append("Info.plist & Entitlements.plist excluded from CopyBundleResources")

        folder_refs = [
            (ios_dir / m.group(1).strip().strip('"').strip("'")).resolve()
            for m in re.finditer(r"-\s*path:\s*([^\n]+)\n\s*type:\s*folder", yml_txt)
        ]
        dup_mount_errs = []
        for fr in folder_refs:
            try:
                rel_src = str(fr.relative_to((ios_dir / "Sources").resolve()))
            except ValueError:
                continue
            if yml_txt.count(rel_src) < 2:
                dup_mount_errs.append(rel_src)
        if dup_mount_errs:
            failures.append(
                f"project.yml mounts type: folder {dup_mount_errs} without excluding them from Sources (causes Xcode 16 duplicate copy error)"
            )
        elif folder_refs:
            passed.append(f"Folder resource mounts properly excluded before mounting ({len(folder_refs)} folder(s))")

        # Verify Tests target sets PRODUCT_BUNDLE_IDENTIFIER when GENERATE_INFOPLIST_FILE: YES is used
        if re.search(r"Tests:\s*[\s\S]*GENERATE_INFOPLIST_FILE:\s*YES", yml_txt):
            if not re.search(r"Tests:[\s\S]*PRODUCT_BUNDLE_IDENTIFIER\s*:", yml_txt):
                warnings.append("project.yml *Tests target uses GENERATE_INFOPLIST_FILE: YES without explicit PRODUCT_BUNDLE_IDENTIFIER")
            else:
                passed.append("XCTest target declares explicit PRODUCT_BUNDLE_IDENTIFIER")

        # Verify AccentColor existence if referenced in project.yml
        accent_m = re.search(r"ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME\s*:\s*['\"]?([^'\"\n]+)['\"]?", yml_txt)
        if accent_m:
            ac_name = accent_m.group(1).strip()
            if not (ios_dir / "Sources" / "Resources" / "Assets.xcassets" / f"{ac_name}.colorset").is_dir():
                failures.append(f"project.yml references AccentColor '{ac_name}' missing from Assets.xcassets")

    # Check resource hygiene (Info.plist, .strings syntax, Contents.json, flattened filename collisions)
    res_dir = ios_dir / "Sources" / "Resources"
    if res_dir.is_dir():
        yml_for_res = proj_yml.read_text(encoding="utf-8", errors="replace") if proj_yml.is_file() else ""
        folder_ref_dirs = [
            (ios_dir / m.group(1).strip().strip('"').strip("'")).resolve()
            for m in re.finditer(r"-\s*path:\s*([^\n]+)\n\s*type:\s*folder", yml_for_res)
        ]
        by_name: dict[str, list[str]] = collections.defaultdict(list)
        bad_assets: list[str] = []
        plutil_bin = shutil.which("plutil")
        for f in sorted(res_dir.rglob("*")):
            if not f.is_file() or f.name == ".DS_Store":
                continue
            rf = f.resolve()
            rel = f.relative_to(res_dir)
            parts = rel.parts
            if f.name == "Contents.json" and any(p.endswith(".xcassets") for p in parts):
                try:
                    cjson = json.loads(f.read_text(encoding="utf-8"))
                    for img in cjson.get("images", []):
                        fn = img.get("filename")
                        if fn and not (f.parent / fn).is_file():
                            bad_assets.append(f"Missing asset referenced by {rel}: {fn}")
                except Exception as exc:
                    bad_assets.append(f"Invalid JSON in {rel}: {exc}")
            if plutil_bin and f.suffix in (".plist", ".strings"):
                rp = subprocess.run([plutil_bin, "-lint", "-s", str(f)], capture_output=True, text=True)
                if rp.returncode != 0:
                    bad_assets.append(f"plutil lint error in {rel}: {(rp.stdout + rp.stderr).strip()}")
            if any(p.endswith((".xcassets", ".lproj", ".xcdatamodeld")) for p in parts):
                continue
            if f.name in ("Info.plist", "Entitlements.plist"):
                continue
            if any(fr in rf.parents or fr == rf for fr in folder_ref_dirs):
                continue
            by_name[f.name].append(str(rel))

        collisions = {k: v for k, v in by_name.items() if len(v) > 1}
        if collisions:
            failures.append(f"Flattened CopyBundleResources filename collision(s): {collisions}")
        else:
            passed.append("Zero flattened CopyBundleResources resource collisions")

        if bad_assets:
            for ba in bad_assets[:5]:
                failures.append(ba)
        else:
            passed.append("Assets.xcassets / Info.plist / .strings resource syntax verified")

    # Verify CI workflow avoids broken SYMROOT + clean build trap when present
    ci_yml = ROOT / ".github" / "workflows" / "ios-build-ipa.yml"
    if ci_yml.is_file():
        ci_txt = ci_yml.read_text(encoding="utf-8", errors="replace")
        if "xcodebuild clean" in ci_txt and "SYMROOT=" in ci_txt:
            failures.append(".github/workflows/ios-build-ipa.yml still uses 'xcodebuild clean ... SYMROOT=' (use 'rm -rf build' + '-derivedDataPath')")
        elif "-derivedDataPath" in ci_txt:
            passed.append("CI workflow uses DerivedData build isolation (no clean/SYMROOT conflict)")

    # Check Info.plist MinimumOSVersion & dynamic version bindings if present
    app_info_plist = ios_dir / "Sources" / "Resources" / "Info.plist"
    if app_info_plist.is_file():
        try:
            with app_info_plist.open("rb") as fh:
                plist_data = plistlib.load(fh)
            min_os = str(plist_data.get("MinimumOSVersion", ""))
            if min_os:
                vt = parse_version_tuple(min_os)
                if vt is None or vt > (16, 1, 1):
                    failures.append(f"Sources/Resources/Info.plist MinimumOSVersion={min_os} exceeds iOS 16.1.1!")
                else:
                    passed.append(f"Info.plist MinimumOSVersion={min_os} (<= 16.1.1 OK)")
            short_ver = str(plist_data.get("CFBundleShortVersionString", ""))
            bundle_ver = str(plist_data.get("CFBundleVersion", ""))
            if short_ver != "$(MARKETING_VERSION)" or bundle_ver != "$(CURRENT_PROJECT_VERSION)":
                failures.append(
                    "Sources/Resources/Info.plist must use $(MARKETING_VERSION) and $(CURRENT_PROJECT_VERSION) "
                    f"(found '{short_ver}' / '{bundle_ver}') so version bumps and CI increments take effect"
                )
            else:
                passed.append("Info.plist dynamically binds $(MARKETING_VERSION) & $(CURRENT_PROJECT_VERSION)")
        except Exception as exc:
            failures.append(f"Failed to parse Sources/Resources/Info.plist: {exc}")
    else:
        warnings.append("Sources/Resources/Info.plist not found (ensure INFOPLIST_FILE path matches project.yml)")

    # Gate 3 & 4: Swift source scan — iOS 17+ forbidden APIs, evidence citations, UNVERIFIED markers
    sources_dir = ios_dir / "Sources"
    swift_files = sorted(sources_dir.rglob("*.swift")) if sources_dir.exists() else []
    objc_files = sorted(list(sources_dir.rglob("*.m")) + list(sources_dir.rglob("*.mm"))) if sources_dir.exists() else []
    code_files = swift_files + objc_files

    if not code_files:
        failures.append(f"No Swift/ObjC source files found under apps/{slug}/ios-app/Sources/")
    else:
        cite_re = re.compile(r"(?:Port\s+of\s+|Evidence:\s*)", re.I)
        unverified_re = re.compile(r"\bUNVERIFIED\b")
        ios17_hits: list[str] = []
        total_cites = 0
        total_unverified = 0
        hardcoded_di_hits = 0

        for sf in code_files:
            txt = sf.read_text(encoding="utf-8", errors="replace")
            rel = sf.relative_to(ios_dir)
            total_cites += len(cite_re.findall(txt))
            total_unverified += len(unverified_re.findall(txt))

            lines = txt.splitlines()
            if sf.suffix == ".swift":
                for label, rx in FORBIDDEN_IOS17_APIS:
                    for m in rx.finditer(txt):
                        line_no = txt[: m.start()].count("\n")
                        # Skip comments
                        stripped = lines[line_no].strip()
                        if stripped.startswith("//") or stripped.startswith("*"):
                            continue
                        if not has_available_ios17_guard(lines, line_no):
                            ios17_hits.append(f"{rel}:{line_no + 1} uses {label}")

                if re.search(r"UIScreen\.main\.bounds", txt):
                    warnings.append(f"{rel} references UIScreen.main.bounds — verify safeAreaInsets/GeometryReader parity on XS Max (414x896 Notch)")
                if re.search(r"\b59(?:\.0)?\b.*(?:top|inset|safe|notch|island)", txt, re.I):
                    hardcoded_di_hits += 1

        if ios17_hits:
            for hit in ios17_hits[:10]:
                failures.append(f"iOS 17+/18+ API incompatible with iOS 16.1.1: {hit}")
            if len(ios17_hits) > 10:
                failures.append(f"...and {len(ios17_hits) - 10} more iOS 17+/18+ API violation(s)")
        else:
            passed.append(f"iOS 16.1.1 API ceiling verified across {len(code_files)} source file(s) (0 unguarded iOS 17+ APIs)")

        if total_cites < 3:
            failures.append(
                f"Only {total_cites} decompiled evidence citation(s) (`// Port of ...` / `// Evidence: ...`) in Sources/ "
                f"(minimum 3 required to prove evidence-backed 1:1 rebuild)"
            )
        else:
            passed.append(f"Evidence citations verified: {total_cites} reference(s)")

        if total_unverified > 0:
            failures.append(f"Found {total_unverified} unresolved UNVERIFIED marker(s) in Sources/ — verify against binary/REA before finishing")
        else:
            passed.append("Zero unresolved UNVERIFIED markers")

        if hardcoded_di_hits > 0:
            warnings.append("Detected potential Dynamic Island 59pt top inset constant — iPhone XS Max Notch top safe area is 44pt")

    # Gate 5: XCTests & apps-manifest.json registration
    tests_dir = ios_dir / "Tests"
    test_files = sorted(tests_dir.rglob("*.swift")) if tests_dir.exists() else []
    if not test_files:
        failures.append(f"No XCTest files found in apps/{slug}/ios-app/Tests/")
    else:
        passed.append(f"XCTest suite present: {len(test_files)} test file(s)")

    manifest_path = ROOT / "apps" / "apps-manifest.json"
    if manifest_path.is_file():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if any(entry.get("slug") == slug for entry in manifest):
            passed.append("Registered in apps/apps-manifest.json")
        else:
            failures.append(f"App '{slug}' is NOT registered in apps/apps-manifest.json")
    else:
        failures.append("Missing apps/apps-manifest.json")

    # Gate 6: Advisory Visual Oracle reference frames
    ref_dir = analysis_dir / "reference-frames"
    ref_pngs = list(ref_dir.rglob("*.png")) + list(ref_dir.rglob("*.jpg")) if ref_dir.exists() else []
    if ref_pngs:
        passed.append(f"iPhone XS Max reference screenshots present: {len(ref_pngs)} image(s)")
    else:
        warnings.append(f"No reference screenshots in apps/{slug}/analysis/reference-frames/ (recommended for 1:1 XS Max visual comparison)")

    # Print report
    print(f"=== iOS 16.1.1 (iPhone XS Max) Parity Gate Report: {slug} ===")
    for p in passed:
        print(f"  [PASS] {p}")
    for w in warnings:
        print(f"  [WARN] {w}")
    for f in failures:
        print(f"  [FAIL] {f}")

    if failures:
        print(f"\nRESULT: FAIL ({len(failures)} hard gate(s) failed — fix before reporting done!)")
        sys.exit(1)
    print(f"\nRESULT: PASS ({len(passed)} checks passed, {len(warnings)} warning(s))")
    sys.exit(0)


if __name__ == "__main__":
    main()
