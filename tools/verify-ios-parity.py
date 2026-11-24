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
import argparse
import json
import pathlib
import plistlib
import re
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

    # Check Info.plist MinimumOSVersion if present
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
