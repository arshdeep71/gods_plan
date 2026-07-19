#!/usr/bin/env python3
"""
patch_ios_plist.py
------------------
Patches ios/Runner/Info.plist to:
  1. Add NSPhotoLibraryUsageDescription (in case it is still required by other plugins)
  2. Declare CFBundleAlternateIcons dynamically for all icons listed in the manifest
  3. Copies the alternate icon PNGs into ios/Runner/ using their sanitized IDs (e.g. GPIconDark.png)
  4. Verifies the registration at build-time to ensure no mismatch exists.

Run this in GitHub Actions AFTER `flutter build ios --config-only --no-codesign`
and BEFORE the actual `flutter build ios --release --no-codesign`.
"""

import os
import shutil
import plistlib
import sys
import json

PLIST_PATH = os.path.join("ios", "Runner", "Info.plist")
MANIFEST_PATH = os.path.join("assets", "alternate_icons_manifest.json")

def main():
    if not os.path.exists(PLIST_PATH):
        print(f"[patch_ios_plist] ERROR: {PLIST_PATH} not found. "
              "Run 'flutter build ios --config-only' first.")
        sys.exit(1)

    if not os.path.exists(MANIFEST_PATH):
        print(f"[patch_ios_plist] ERROR: Manifest file not found at '{MANIFEST_PATH}'.")
        sys.exit(1)

    # ── Read manifest ─────────────────────────────────────────────────────────
    try:
        with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
            manifest = json.load(f)
    except Exception as e:
        print(f"[patch_ios_plist] ERROR: Failed to parse manifest ({e}).")
        sys.exit(1)

    icons = manifest.get("icons", [])
    alternate_icons = [icon for icon in icons if icon["id"] != "default"]

    # ── Read plist ────────────────────────────────────────────────────────────
    with open(PLIST_PATH, "rb") as f:
        plist = plistlib.load(f)

    # ── 1. Photo library usage description ───────────────────────────────────
    if "NSPhotoLibraryUsageDescription" not in plist:
        plist["NSPhotoLibraryUsageDescription"] = (
            "God's Plan needs access to your photo library to let you select a custom app icon."
        )
        print("[patch_ios_plist] Added NSPhotoLibraryUsageDescription.")

    # ── 2. CFBundleAlternateIcons Dynamic Registration ───────────────────────
    # Initialize dictionary structure for alternate icons (iPhone)
    bundle_icons = plist.get("CFBundleIcons", {})
    alt_icons = bundle_icons.get("CFBundleAlternateIcons", {})

    # Initialize dictionary structure for alternate icons (iPad)
    bundle_icons_ipad = plist.get("CFBundleIcons~ipad", {})
    alt_icons_ipad = bundle_icons_ipad.get("CFBundleAlternateIcons", {})

    # Clear old auto-generated alternate icons to keep it clean (remove icons starting with 'GP')
    for old_id in list(alt_icons.keys()):
        if old_id.startswith("GP"):
            del alt_icons[old_id]
    for old_id in list(alt_icons_ipad.keys()):
        if old_id.startswith("GP"):
            del alt_icons_ipad[old_id]

    # Register each alternate icon
    copied_files = []
    for icon in alternate_icons:
        icon_id = icon["id"]
        src_path = icon["assetPath"]
        dest_filename = f"{icon_id}.png"
        dest_path = os.path.join("ios", "Runner", dest_filename)

        # Copy alternate icon PNG into ios/Runner/
        if os.path.exists(src_path):
            shutil.copy2(src_path, dest_path)
            copied_files.append(dest_path)
            print(f"[patch_ios_plist] Copied {src_path} → {dest_path}")
        else:
            print(f"[patch_ios_plist] ERROR: Source asset '{src_path}' for icon '{icon_id}' not found.")
            sys.exit(1)

        # Register in plist (iPhone)
        alt_icons[icon_id] = {
            "CFBundleIconFiles": [icon_id],
            "UIPrerenderedIcon": False,
        }

        # Register in plist (iPad)
        alt_icons_ipad[icon_id] = {
            "CFBundleIconFiles": [icon_id],
            "UIPrerenderedIcon": False,
        }

    # Save alternate icons dictionaries back to structures
    bundle_icons["CFBundleAlternateIcons"] = alt_icons
    plist["CFBundleIcons"] = bundle_icons

    bundle_icons_ipad["CFBundleAlternateIcons"] = alt_icons_ipad
    plist["CFBundleIcons~ipad"] = bundle_icons_ipad

    # ── 3. Write plist back ───────────────────────────────────────────────────
    with open(PLIST_PATH, "wb") as f:
        plistlib.dump(plist, f, fmt=plistlib.FMT_XML)
    print(f"[patch_ios_plist] Info.plist updated successfully.")

    # ── 4. Build-time Verification of iOS Registration ────────────────────────
    print("[patch_ios_plist] Running build-time verification...")
    
    # Reload plist to verify changes were saved correctly
    with open(PLIST_PATH, "rb") as f:
        verified_plist = plistlib.load(f)

    verified_bundle_icons = verified_plist.get("CFBundleIcons", {})
    verified_alt_icons = verified_bundle_icons.get("CFBundleAlternateIcons", {})

    verified_bundle_icons_ipad = verified_plist.get("CFBundleIcons~ipad", {})
    verified_alt_icons_ipad = verified_bundle_icons_ipad.get("CFBundleAlternateIcons", {})

    for icon in alternate_icons:
        icon_id = icon["id"]
        
        # Verify Info.plist registrations
        if icon_id not in verified_alt_icons:
            print(f"[patch_ios_plist] VERIFICATION FAILED: Alternate icon '{icon_id}' is missing from CFBundleIcons in Info.plist")
            sys.exit(1)
        if icon_id not in verified_alt_icons_ipad:
            print(f"[patch_ios_plist] VERIFICATION FAILED: Alternate icon '{icon_id}' is missing from CFBundleIcons~ipad in Info.plist")
            sys.exit(1)

        # Verify physical file existence in ios/Runner/
        expected_file = os.path.join("ios", "Runner", f"{icon_id}.png")
        if not os.path.exists(expected_file):
            print(f"[patch_ios_plist] VERIFICATION FAILED: Expected asset file '{expected_file}' is missing from ios/Runner/")
            sys.exit(1)

    print("\n================ VERIFICATION REPORT ================")
    print(f"[OK] {len(alternate_icons)} alternate icons registered in Info.plist (iPhone)")
    print(f"[OK] {len(alternate_icons)} alternate icons registered in Info.plist (iPad)")
    print(f"[OK] {len(copied_files)} alternate icon assets copied to ios/Runner/")
    print("[OK] iOS registration build-time verification passed.")
    print("=====================================================\n")

if __name__ == "__main__":
    main()
