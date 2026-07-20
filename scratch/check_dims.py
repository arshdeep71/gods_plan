import os
import re
from PIL import Image

ALTERNATE_ICONS_DIR = os.path.join("assets", "alternate_icons")

for entry in os.scandir(ALTERNATE_ICONS_DIR):
    if entry.is_file() and entry.name.endswith(".png"):
        try:
            img = Image.open(entry.path)
            print(f"{entry.name}: {img.width}x{img.height}, format={img.format}")
        except Exception as e:
            print(f"{entry.name}: failed to open ({e})")
