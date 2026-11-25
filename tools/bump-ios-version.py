#!/usr/bin/env python3
"""
Update iOS rebuild version & build number in apps/<slug>/ios-app/project.yml (SSOT),
ensure Info.plist uses $(MARKETING_VERSION) / $(CURRENT_PROJECT_VERSION),
and optionally sync apps/apps-manifest.json (`rebuildVersion`, `rebuildBuild`).

Usage:
  # Local bump before committing/pushing edits:
  python3 tools/bump-ios-version.py <slug>
  python3 tools/bump-ios-version.py --all
  python3 tools/bump-ios-version.py <slug> --part minor

  # CI ephemeral bump (used by .github/workflows/ios-build-ipa.yml on every CI run/re-run):
  python3 tools/bump-ios-version.py <slug> --ci-run "$GITHUB_RUN_NUMBER" --ci-attempt "${GITHUB_RUN_ATTEMPT:-1}" --no-manifest
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import plistlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APPS_DIR = ROOT / "apps"
MANIFEST_PATH = APPS_DIR / "apps-manifest.json"


def parse_semver(ver: str) -> tuple[int, int, int]:
    cleaned = ver.strip().strip('"').strip("'")
    m = re.match(r"^(\d+)(?:\.(\d+))?(?:\.(\d+))?$", cleaned)
    if not m:
        raise ValueError(f"Invalid semantic version '{ver}' (expected X.Y.Z)")
    return int(m.group(1)), int(m.group(2) or 0), int(m.group(3) or 0)


def parse_build_int(build: str) -> int:
    cleaned = build.strip().strip('"').strip("'")
    m = re.match(r"^(\d+)", cleaned)
    if not m:
        return 1
    return max(1, int(m.group(1)))


def bump_semver(ver: str, part: str) -> str:
    major, minor, patch = parse_semver(ver)
    if part == "major":
        major, minor, patch = major + 1, 0, 0
    elif part == "minor":
        major, minor, patch = major, minor + 1, 0
    else:
        patch += 1
    if (major, minor, patch) == (1, 0, 0):
        patch = 1
    return f"{major}.{minor}.{patch}"


def update_project_yml(yml_path: pathlib.Path, new_ver: str, new_build: str) -> tuple[str, str]:
    txt = yml_path.read_text(encoding="utf-8")

    if re.search(r"^\s*MARKETING_VERSION\s*:", txt, re.M):
        txt = re.sub(
            r'^(\s*MARKETING_VERSION\s*:\s*)(["\']?[^"\'\n]+["\']?)',
            lambda m: f'{m.group(1)}"{new_ver}"',
            txt,
            count=1,
            flags=re.M,
        )
    else:
        m = re.search(r'^(\s*)INFOPLIST_FILE\s*:.*$', txt, re.M)
        if not m:
            raise RuntimeError(f"Could not find INFOPLIST_FILE in {yml_path} to insert MARKETING_VERSION")
        indent = m.group(1)
        txt = txt[: m.end()] + f'\n{indent}MARKETING_VERSION: "{new_ver}"' + txt[m.end() :]

    if re.search(r"^\s*CURRENT_PROJECT_VERSION\s*:", txt, re.M):
        txt = re.sub(
            r'^(\s*CURRENT_PROJECT_VERSION\s*:\s*)(["\']?[^"\'\n]+["\']?)',
            lambda m: f'{m.group(1)}"{new_build}"',
            txt,
            count=1,
            flags=re.M,
        )
    else:
        m = re.search(r'^(\s*)MARKETING_VERSION\s*:.*$', txt, re.M)
        if not m:
            raise RuntimeError(f"Could not find MARKETING_VERSION in {yml_path} to insert CURRENT_PROJECT_VERSION")
        indent = m.group(1)
        txt = txt[: m.end()] + f'\n{indent}CURRENT_PROJECT_VERSION: "{new_build}"' + txt[m.end() :]

    yml_path.write_text(txt, encoding="utf-8")
    return new_ver, new_build


def read_project_version(yml_path: pathlib.Path) -> tuple[str, str]:
    txt = yml_path.read_text(encoding="utf-8")
    mv = re.search(r'^\s*MARKETING_VERSION\s*:\s*["\']?([^"\'\n#]+)["\']?', txt, re.M)
    bv = re.search(r'^\s*CURRENT_PROJECT_VERSION\s*:\s*["\']?([^"\'\n#]+)["\']?', txt, re.M)
    ver = mv.group(1).strip() if mv else "1.0.0"
    bld = bv.group(1).strip() if bv else "1"
    return ver, bld


def ensure_dynamic_info_plist(plist_path: pathlib.Path) -> bool:
    if not plist_path.is_file():
        return False
    with plist_path.open("rb") as fh:
        data = plistlib.load(fh)
    changed = False
    if data.get("CFBundleShortVersionString") != "$(MARKETING_VERSION)":
        data["CFBundleShortVersionString"] = "$(MARKETING_VERSION)"
        changed = True
    if data.get("CFBundleVersion") != "$(CURRENT_PROJECT_VERSION)":
        data["CFBundleVersion"] = "$(CURRENT_PROJECT_VERSION)"
        changed = True
    if changed:
        with plist_path.open("wb") as fh:
            plistlib.dump(data, fh, sort_keys=True)
    return changed


def update_manifest(slug: str, new_ver: str, new_build: str) -> None:
    if not MANIFEST_PATH.is_file():
        return
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    updated = False
    for entry in manifest:
        if entry.get("slug") == slug:
            entry["rebuildVersion"] = new_ver
            entry["rebuildBuild"] = new_build
            updated = True
    if updated:
        MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def process_slug(slug: str, args: argparse.Namespace) -> tuple[str, str]:
    ios_dir = APPS_DIR / slug / "ios-app"
    yml_path = ios_dir / "project.yml"
    if not yml_path.is_file():
        raise FileNotFoundError(f"Missing {yml_path}")

    cur_ver, cur_build = read_project_version(yml_path)
    base_build = parse_build_int(cur_build)

    if args.ci_run is not None:
        run_num = max(1, args.ci_run)
        run_attempt = max(1, args.ci_attempt)
        major, minor, patch = parse_semver(cur_ver)
        new_ver = f"{major}.{minor}.{patch + run_num}"
        build_num = base_build + run_num
        new_build = f"{build_num}.{run_attempt}" if run_attempt > 1 else str(build_num)
    else:
        if args.set_version:
            major, minor, patch = parse_semver(args.set_version)
            if (major, minor, patch) == (1, 0, 0):
                raise ValueError("Refusing to set rebuild version to 1.0.0; use >= 1.0.1")
            new_ver = f"{major}.{minor}.{patch}"
        else:
            new_ver = bump_semver(cur_ver, args.part)

        if args.set_build:
            new_build = str(parse_build_int(args.set_build))
        else:
            new_build = str(base_build + 1)

    update_project_yml(yml_path, new_ver, new_build)
    plist_changed = ensure_dynamic_info_plist(ios_dir / "Sources" / "Resources" / "Info.plist")

    if not args.no_manifest:
        update_manifest(slug, new_ver, new_build)

    plist_note = " (updated Info.plist placeholders)" if plist_changed else ""
    print(f"[VERSION] {slug}: {cur_ver} ({cur_build}) -> {new_ver} ({new_build}){plist_note}")
    return new_ver, new_build


def main() -> None:
    parser = argparse.ArgumentParser(description="Bump iOS rebuild version and build number.")
    parser.add_argument("slug", nargs="?", help="App slug under apps/")
    parser.add_argument("--all", action="store_true", help="Bump all apps under apps/*/ios-app/project.yml")
    parser.add_argument("--part", choices=["patch", "minor", "major"], default="patch", help="Semver component to increment")
    parser.add_argument("--set-version", default="", help="Explicitly set MARKETING_VERSION (e.g. 1.2.0)")
    parser.add_argument("--set-build", default="", help="Explicitly set CURRENT_PROJECT_VERSION")
    parser.add_argument("--ci-run", type=int, default=None, help="CI mode: increment by GITHUB_RUN_NUMBER")
    parser.add_argument("--ci-attempt", type=int, default=1, help="CI mode: GITHUB_RUN_ATTEMPT (adds .attempt if > 1)")
    parser.add_argument("--no-manifest", action="store_true", help="Do not modify apps/apps-manifest.json")
    parser.add_argument("--github-output", default="", help="Optional path to GITHUB_OUTPUT to emit app_version & app_build")
    args = parser.parse_args()

    if args.all:
        slugs = sorted(p.parent.parent.name for p in APPS_DIR.glob("*/ios-app/project.yml"))
    elif args.slug:
        slugs = [args.slug]
    else:
        parser.error("Provide <slug> or --all")

    last_ver, last_build = "", ""
    for s in slugs:
        last_ver, last_build = process_slug(s, args)

    gh_out = args.github_output or os.environ.get("GITHUB_OUTPUT", "")
    if gh_out and len(slugs) == 1 and args.ci_run is not None:
        with open(gh_out, "a", encoding="utf-8") as fh:
            fh.write(f"app_version={last_ver}\n")
            fh.write(f"app_build={last_build}\n")


if __name__ == "__main__":
    main()
