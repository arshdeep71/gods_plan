#!/usr/bin/env python3
"""
patch_ios_plist.py
------------------
Patches ios/Runner/Info.plist to:
  1. Add NSPhotoLibraryUsageDescription (required by image_picker)
  2. Declare CFBundleAlternateIcons so iOS accepts setAlternateIconName()
  3. Copies the bundled alternate icon PNG into ios/Runner/

Run this in GitHub Actions AFTER `flutter build ios --config-only --no-codesign`
and BEFORE the actual `flutter build ios --release --no-codesign`.
"""

import os
import shutil
import plistlib
import sys

PLIST_PATH = os.path.join("ios", "Runner", "Info.plist")
ALTERNATE_ICON_SRC = os.path.join("assets", "alternate_icons", "icon_dark.png")
ALTERNATE_ICON_DEST = os.path.join("ios", "Runner", "icon_dark.png")

def main():
    if not os.path.exists(PLIST_PATH):
        print(f"[patch_ios_plist] ERROR: {PLIST_PATH} not found. "
              "Run 'flutter build ios --config-only' first.")
        sys.exit(1)

    # ── Read plist ────────────────────────────────────────────────────────────
    with open(PLIST_PATH, "rb") as f:
        plist = plistlib.load(f)

    # ── 1. Photo library usage description ───────────────────────────────────
    if "NSPhotoLibraryUsageDescription" not in plist:
        plist["NSPhotoLibraryUsageDescription"] = (
            "God's Plan needs access to your photo library to let you "
            "select a custom app icon image."
        )
        print("[patch_ios_plist] Added NSPhotoLibraryUsageDescription.")

    # ── 2. CFBundleAlternateIcons ─────────────────────────────────────────────
    # Structure required by Apple:
    # CFBundleIcons → CFBundleAlternateIcons → <icon_name> → CFBundleIconFiles
    bundle_icons = plist.get("CFBundleIcons", {})
    alt_icons = bundle_icons.get("CFBundleAlternateIcons", {})

    if "icon_dark" not in alt_icons:
        alt_icons["icon_dark"] = {
            "CFBundleIconFiles": ["icon_dark"],
            "UIPrerenderedIcon": False,
        }
        print("[patch_ios_plist] Registered alternate icon: icon_dark")

    bundle_icons["CFBundleAlternateIcons"] = alt_icons
    plist["CFBundleIcons"] = bundle_icons

    # ── 3. Write plist back ───────────────────────────────────────────────────
    with open(PLIST_PATH, "wb") as f:
        plistlib.dump(plist, f, fmt=plistlib.FMT_XML)
    print(f"[patch_ios_plist] Info.plist updated successfully.")

    # ── 4. Copy alternate icon PNG into ios/Runner/ ───────────────────────────
    if os.path.exists(ALTERNATE_ICON_SRC):
        shutil.copy2(ALTERNATE_ICON_SRC, ALTERNATE_ICON_DEST)
        print(f"[patch_ios_plist] Copied {ALTERNATE_ICON_SRC} → {ALTERNATE_ICON_DEST}")
    else:
        print(f"[patch_ios_plist] WARNING: {ALTERNATE_ICON_SRC} not found. "
              "Alternate icon will not be bundled.")

    print("[patch_ios_plist] Patch complete.")

if __name__ == "__main__":
    main()
