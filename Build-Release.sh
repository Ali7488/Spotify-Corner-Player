#!/usr/bin/env bash
# Build a complete Windows v1.4.0 release ZIP from this checked-out repository.
# The accepted v1.2.4 script is included for one-click rollback.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "$0")" && pwd -P)"
cd "$ROOT"

command -v python3 >/dev/null || { echo 'Python 3 required to build ZIP' >&2; exit 1; }
command -v git >/dev/null || { echo 'Git required for source integrity check' >&2; exit 1; }

actual="$(git hash-object Spotify-Corner-Player-v1.2.4.ps1)"
if [[ "$actual" != 'f1935794f1220fefe08c5e2c6c8efa8054f75ecb' ]]; then
    echo "Stable v1.2.4 baseline has changed unexpectedly: $actual" >&2
    exit 1
fi

python3 - "$ROOT" <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import re
import sys
import xml.etree.ElementTree as ET

root = Path(sys.argv[1])
names = (
    "Install.bat",
    "Uninstall.bat",
    "Restore-v1.2.4.bat",
    "Setup.ps1",
    "Spotify-Corner-Player-v1.4.0.ps1",
    "Spotify-Corner-Player-v1.2.4.ps1",
    "Install-SpotifyPlayerLogs.ps1",
    "Spotify-Corner-Player-v1.2.3-rollback.ps1",
    "Spotify-Corner-Player-v1.2.0-rollback.ps1",
    "README.md",
)
missing = [name for name in names if not (root / name).is_file()]
if missing:
    raise SystemExit("Missing release components: " + ", ".join(missing))

source = (root / "Spotify-Corner-Player-v1.4.0.ps1").read_text(encoding="utf-8-sig")
if not all(marker in source for marker in (
    'x:Name="themeButton"',
    "Request-ThemeChange",
    "Convert-ThemeMarkup",
    "ShowOnStart",
    "'Restart' { Restart-CornerPlayer }",
    "Color theme",
)):
    raise SystemExit("Missing in-player theme picker or restart wiring.")

match = re.search(r"<Window xmlns=.*?</Window>", source, re.S)
if not match:
    raise SystemExit("Expected WPF XAML document not found.")
layout = ET.fromstring(match.group(0))
if not any(e.attrib.get("{http://schemas.microsoft.com/winfx/2006/xaml}Name") == "themeButton" for e in layout.iter()):
    raise SystemExit("Color theme button missing from XAML.")

colors = set(re.findall(r"#[0-9A-Fa-f]{6}\b", match.group(0), flags=re.I))
for theme in ("Forest", "Sapphire", "Amethyst", "Obsidian"):
    block = re.search(r"    " + theme + r" = @\{(.*?)\n    \}", source, re.S)
    if not block:
        raise SystemExit(f"Palette missing: {theme}")
    overrides = dict(re.findall(r"'(#[0-9A-Fa-f]{6})' = '(#[0-9A-Fa-f]{6})'", block.group(1)))
    if {v.upper() for v in overrides} != {v.upper() for v in colors}:
        raise SystemExit(f"Incomplete/extra color entries: {theme}")

output = root / "dist" / "Spotify-Corner-Player-v1.4.0-Windows.zip"
output.parent.mkdir(parents=True, exist_ok=True)
with ZipFile(output, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
    for name in names:
        archive.write(root / name, arcname=name)
with ZipFile(output) as archive:
    if archive.testzip() is not None:
        raise SystemExit("ZIP CRC validation failed")
print("Validated WPF XAML, 4 alternate palettes and ZIP CRC.")
print(f"Complete Windows ZIP: {output}")
PY
