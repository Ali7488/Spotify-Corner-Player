#!/usr/bin/env python3
"""Build a standalone KDE Plasma 6 ZIP for the same GitHub Releases page."""

from __future__ import annotations
import hashlib
from pathlib import Path
import sys
from zipfile import ZipFile, ZIP_DEFLATED
import json
import xml.etree.ElementTree as ET


def main() -> int:
    root = Path(__file__).resolve().parent
    metadata = json.loads((root / "widget/metadata.json").read_text(encoding="utf-8"))
    if metadata.get("KPackageStructure") != "Plasma/Applet":
        raise ValueError("Not a Plasma applet.")
    if metadata.get("KPlugin", {}).get("Id") != "org.mohannad.spotify.cornerplayer":
        raise ValueError("Unexpected applet ID.")
    if metadata.get("KPlugin", {}).get("Version") != "1.5.1":
        raise ValueError("Release version mismatch.")
    settings = ET.parse(root / "widget/contents/config/main.xml")
    entries = {element.attrib.get("name") for element in settings.iter() if element.tag.endswith("entry")}
    if not {"themeId", "playerPreference", "compactMode", "pinned", "artworkMode"} <= entries:
        raise ValueError("Persistent theme/player settings not defined.")

    license_file = root.parent.parent / "LICENSE"
    if not license_file.is_file() or "MIT License" not in license_file.read_text(encoding="utf-8"):
        raise ValueError("Missing MIT LICENSE in repository root.")
    files = [
        root / "install.py",
        root / "README.md",
        *sorted((root / "widget").rglob("*")),
    ]
    files = [f for f in files if f.is_file()]
    if any(f.is_symlink() for f in files):
        raise ValueError("Symlinks are not allowed in the release.")
    if not {"main.qml", "VinylPopup.qml", "Record.qml", "ThemeColors.js"} <= {f.name for f in files}:
        raise ValueError("Incomplete widget package.")
    source = (root / "widget/contents/ui/main.qml").read_text(encoding="utf-8")
    popup = (root / "widget/contents/ui/VinylPopup.qml").read_text(encoding="utf-8")
    theme = (root / "widget/contents/ui/ThemeColors.js").read_text(encoding="utf-8")
    for string in ("Spotify", "Spotifast", "Mpris2Model", "setPlayerPreference", "Plasmoid.configuration"):
        if string not in source:
            raise ValueError(f"Missing runtime feature: {string}")
    for string in ("themeButton", "sourceButton", "themeMenu", "sourceMenu", "compactButton", "pinButton", "repeatButton", "artworkButton", "volumeSlider"):
        if string not in popup:
            raise ValueError(f"Missing popup control: {string}")
    for string in ("Burgundy", "Forest", "Sapphire", "Amethyst", "Obsidian"):
        if string not in theme:
            raise ValueError(f"Missing color scheme: {string}")

    output = root.parent.parent / "dist/Corner-Media-Player-v1.5.1-Plasma6.zip"
    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, "w", ZIP_DEFLATED, compresslevel=9) as zipfile:
        for entry in files:
            zipfile.write(entry, "Corner-Media-Player-Plasma6/" + entry.relative_to(root).as_posix())
        zipfile.write(license_file, "Corner-Media-Player-Plasma6/LICENSE")
    with ZipFile(output) as check:
        if check.testzip():
            raise ValueError("Invalid ZIP CRC")
        names = check.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate paths in ZIP")
        if "Corner-Media-Player-Plasma6/LICENSE" not in names:
            raise ValueError("License missing from Linux release ZIP")
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    print(f"Plasma 6 ZIP: {output}")
    print(f"SHA-256: {digest}")
    print(f"Files: {len(files)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
