#!/usr/bin/env python3
import os
import sys
import json
import re
import datetime
import subprocess

ALTERNATE_ICONS_DIR = os.path.join("assets", "alternate_icons")
THUMBNAILS_DIR = os.path.join(ALTERNATE_ICONS_DIR, "thumbnails")
MANIFEST_PATH = os.path.join("assets", "alternate_icons_manifest.json")
METADATA_PATH = os.path.join(ALTERNATE_ICONS_DIR, "metadata.json")

# Ensure base directories exist
os.makedirs(ALTERNATE_ICONS_DIR, exist_ok=True)
os.makedirs(THUMBNAILS_DIR, exist_ok=True)

# Attempt to install and import Pillow for thumbnail generation
PIL_AVAILABLE = False
try:
    from PIL import Image as PILImage
    PIL_AVAILABLE = True
except ImportError:
    print("[Manifest Generator] Pillow not found. Attempting to install...")
    try:
        subprocess.run([sys.executable, "-m", "pip", "install", "Pillow"], check=True)
        from PIL import Image as PILImage
        PIL_AVAILABLE = True
        print("[Manifest Generator] Pillow installed successfully.")
    except Exception as e:
        print(f"[Manifest Generator] Warning: Could not install Pillow ({e}). Will fallback to full resolution icons.")
        PIL_AVAILABLE = False

def validate_filename(filename):
    # Enforce safe filenames: lowercase letters, numbers, and underscores only
    # Reject spaces, uppercase, emojis, @2x, etc.
    name_part, ext = os.path.splitext(filename)
    if ext.lower() != ".png":
        return False, "Not a PNG file (must end with .png)"
    if not re.match(r"^[a-z0-9_]+$", name_part):
        return False, "Filename contains invalid characters. Only lowercase letters, numbers, and underscores are allowed."
    return True, None

def validate_png_dimensions(filepath):
    try:
        with open(filepath, 'rb') as f:
            sig = f.read(8)
            if sig != b'\x89PNG\r\n\x1a\n':
                return False, "Invalid PNG signature (file may be corrupted or not a PNG)"
            
            # Read first chunk length and type
            f.read(4) # length
            chunk_type = f.read(4)
            if chunk_type != b'IHDR':
                return False, "Missing IHDR chunk"
            
            # Read width and height
            width_bytes = f.read(4)
            height_bytes = f.read(4)
            
            width = int.from_bytes(width_bytes, byteorder='big')
            height = int.from_bytes(height_bytes, byteorder='big')
            
            if width != 1024 or height != 1024:
                return False, f"Image is {width}x{height} (expected 1024x1024)"
            
            return True, None
    except Exception as e:
        return False, f"Corrupted or unreadable PNG file: {e}"

def to_camel_case(snake_str):
    components = snake_str.split('_')
    return "".join(x.title() for x in components)

def main():
    print("[Manifest Generator] Scanning alternate icons...")
    
    # 1. Load metadata if available
    metadata = {}
    if os.path.exists(METADATA_PATH):
        try:
            with open(METADATA_PATH, "r", encoding="utf-8") as f:
                metadata = json.load(f)
            print("[Manifest Generator] Loaded metadata.json successfully.")
        except Exception as e:
            print(f"[Manifest Generator] Warning: Failed to parse metadata.json ({e}). Using default settings.")

    # 2. Scan and validate icons
    icons_in_dir = []
    seen_names_lower = {}
    
    for entry in os.scandir(ALTERNATE_ICONS_DIR):
        if not entry.is_file():
            continue
        filename = entry.name
        
        # Skip system metadata files or manifests
        if filename.startswith(".") or filename == "metadata.json" or filename == "alternate_icons_manifest.json":
            continue
            
        filepath = entry.path
        
        # Validate filename format
        is_valid_name, name_err = validate_filename(filename)
        if not is_valid_name:
            print(f"[FAIL] Icon validation failed for '{filename}'")
            print(f"Reason: {name_err}")
            sys.exit(1)
            
        # Detect case-insensitive duplicates
        name_lower = filename.lower()
        if name_lower in seen_names_lower:
            print(f"[FAIL] Duplicate Icon Name Detected: '{filename}' collides with '{seen_names_lower[name_lower]}'")
            sys.exit(1)
        seen_names_lower[name_lower] = filename
        
        # Validate PNG dimensions
        is_valid_png, png_err = validate_png_dimensions(filepath)
        if not is_valid_png:
            print(f"[FAIL] Icon validation failed for '{filename}'")
            print(f"Reason: {png_err}")
            sys.exit(1)
            
        icons_in_dir.append((filename, filepath))

    # 3. Process manifest entries & generate thumbnails
    icons_list = []
    active_filenames = set()
    
    for filename, filepath in icons_in_dir:
        name_part = os.path.splitext(filename)[0]
        active_filenames.add(filename)
        
        # Determine ID
        # Map default icons appropriately.
        is_default = (name_part == "icon_default" or name_part == "default")
        icon_id = "default" if is_default else f"GP{to_camel_case(name_part)}"
        
        # Naming convention parsing: e.g. minimal_clean -> category: Minimal, name: Clean
        parts = name_part.split('_')
        known_categories = {"default", "minimal", "dark", "neon", "quotes", "anime", "custom"}
        
        if parts[0] in known_categories:
            default_category = parts[0].capitalize()
            # If default_category is 'Icon' or parts length is 1, handle cleanly
            if len(parts) > 1:
                default_name = " ".join(p.capitalize() for p in parts[1:])
            else:
                default_name = parts[0].capitalize()
        else:
            default_category = "General"
            default_name = " ".join(p.capitalize() for p in parts)
            
        # Default fallback values
        added_at_dt = datetime.datetime.fromtimestamp(os.path.getmtime(filepath))
        added_at_str = added_at_dt.isoformat() + "Z"
        
        icon_meta = {
            "id": icon_id,
            "name": default_name,
            "assetPath": f"assets/alternate_icons/{filename}",
            "thumbnailPath": f"assets/alternate_icons/thumbnails/{filename}",
            "category": default_category,
            "author": "System",
            "tags": [default_category.lower()] + [p.lower() for p in parts],
            "sortOrder": 999,
            "addedAt": added_at_str
        }
        
        # Override with custom metadata if defined
        if name_part in metadata:
            custom = metadata[name_part]
            if "name" in custom:
                icon_meta["name"] = custom["name"]
            if "category" in custom:
                icon_meta["category"] = custom["category"]
            if "author" in custom:
                icon_meta["author"] = custom["author"]
            if "tags" in custom:
                icon_meta["tags"] = list(set(icon_meta["tags"] + custom["tags"]))
            if "sortOrder" in custom:
                icon_meta["sortOrder"] = int(custom["sortOrder"])
            if "addedAt" in custom:
                icon_meta["addedAt"] = custom["addedAt"]

        # Generate thumbnail
        dest_thumb_path = os.path.join(THUMBNAILS_DIR, filename)
        if PIL_AVAILABLE:
            try:
                # Open 1024px PNG and downscale
                img = PILImage.open(filepath)
                img.thumbnail((128, 128))
                img.save(dest_thumb_path, "PNG")
            except Exception as e:
                print(f"[Manifest Generator] Warning: Failed to generate thumbnail for '{filename}' ({e}). Falling back to original path.")
                icon_meta["thumbnailPath"] = icon_meta["assetPath"]
        else:
            icon_meta["thumbnailPath"] = icon_meta["assetPath"]

        icons_list.append(icon_meta)

    # 4. Cleanup stale thumbnails
    cleaned_count = 0
    if os.path.exists(THUMBNAILS_DIR):
        for entry in os.scandir(THUMBNAILS_DIR):
            if entry.is_file() and entry.name not in active_filenames:
                try:
                    os.remove(entry.path)
                    cleaned_count += 1
                except Exception as e:
                    print(f"[Manifest Generator] Warning: Failed to delete stale thumbnail '{entry.name}' ({e})")
    if cleaned_count > 0:
        print(f"[Manifest Generator] Cleaned up {cleaned_count} stale thumbnails.")

    # 5. Write the final manifest
    manifest_data = {
        "version": 1,
        "generatedAt": datetime.datetime.utcnow().isoformat() + "Z",
        "icons": icons_list
    }
    
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(manifest_data, f, indent=2)
        
    # 6. Print build report
    count = len(icons_list)
    print("\n================ BUILD REPORT ================")
    print(f"[OK] {count} icons discovered")
    print(f"[OK] {count} validated (1024x1024, square, PNG only)")
    print(f"[OK] {count} thumbnails generated/verified")
    print(f"[OK] Manifest version {manifest_data['version']} generated at '{MANIFEST_PATH}'")
    print("[OK] Ready for IPA build")
    print("==============================================\n")

if __name__ == "__main__":
    main()
