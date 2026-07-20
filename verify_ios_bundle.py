#!/usr/bin/env python3
"""
verify_ios_bundle.py
--------------------
Verifies that all alternate icons listed in the manifest are physically bundled
inside the final iOS .app, registered in the compiled Info.plist, and added to the Xcode project.
"""

import os
import sys
import json
import plistlib

MANIFEST_PATH = "assets/alternate_icons_manifest.json"
APP_BUNDLE_DIR = "build/ios/iphoneos/Runner.app"
APP_PLIST_PATH = os.path.join(APP_BUNDLE_DIR, "Info.plist")
PBXPROJ_PATH = "ios/Runner.xcodeproj/project.pbxproj"

def main():
    print("\n================ VERIFYING IOS BUNDLE ================")
    
    # 1. Check if built app exists
    if not os.path.exists(APP_BUNDLE_DIR):
        print(f"ERROR: .app bundle not found at {APP_BUNDLE_DIR}.")
        print("Did the iOS build fail, or was it not run?")
        sys.exit(1)
        
    # 2. Load manifest
    try:
        with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
            manifest = json.load(f)
    except Exception as e:
        print(f"ERROR: Failed to parse manifest ({e}).")
        sys.exit(1)

    icons = manifest.get("icons", [])
    alternate_icons = [icon for icon in icons if icon["id"] != "default"]
    
    # 3. Load compiled Info.plist
    if not os.path.exists(APP_PLIST_PATH):
        print(f"ERROR: Info.plist not found in bundle at {APP_PLIST_PATH}.")
        sys.exit(1)
        
    with open(APP_PLIST_PATH, "rb") as f:
        plist = plistlib.load(f)
        
    alt_icons_dict = plist.get("CFBundleIcons", {}).get("CFBundleAlternateIcons", {})
    
    # 4. Load PBXPROJ as text
    if not os.path.exists(PBXPROJ_PATH):
        print(f"ERROR: project.pbxproj not found at {PBXPROJ_PATH}.")
        sys.exit(1)
        
    with open(PBXPROJ_PATH, "r", encoding="utf-8") as f:
        pbxproj_content = f.read()
        
    # 5. Verify every icon
    all_passed = True
    for icon in alternate_icons:
        icon_id = icon["id"]
        filename = f"{icon_id}.png"
        original_name = icon.get("name", icon_id).lower()
        
        # Check bundle
        bundle_path = os.path.join(APP_BUNDLE_DIR, filename)
        if not os.path.exists(bundle_path):
            print(f"✗ {original_name}.png - Missing from Runner.app bundle")
            all_passed = False
            continue
            
        # Check Info.plist
        if icon_id not in alt_icons_dict:
            print(f"✗ {original_name}.png - Missing from CFBundleAlternateIcons")
            all_passed = False
            continue
            
        # Check Xcode project
        if filename not in pbxproj_content:
            print(f"✗ {original_name}.png - Missing from Xcode project (project.pbxproj)")
            all_passed = False
            continue
            
        # If all checks pass
        print(f"✓ {original_name}.png - Registered and Packaged")
        
    print("======================================================")
    if not all_passed:
        print("\nERROR: One or more alternate icons failed packaging verification.")
        sys.exit(1)
        
    print("SUCCESS: All alternate icons are successfully bundled and registered.")
    
if __name__ == "__main__":
    main()
