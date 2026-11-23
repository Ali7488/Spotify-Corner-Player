#!/usr/bin/env python3
"""User-only KDE Plasma 6 applet installer with Spotify/Spotifast preflight.

Check packages BEFORE changing files. Does not modify any existing Emerald Vinyl
applet or Spotify installation. Never needs sudo or a distro-specific package manager.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

PLUGIN = "org.mohannad.spotify.cornerplayer"
PACKAGE = Path(__file__).resolve().parent / "widget"


def desktop_directories() -> list[Path]:
    home = Path.home()
    data_home = Path(os.environ.get("XDG_DATA_HOME") or home / ".local/share")
    data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    dirs = [data_home / "applications"]
    dirs += [Path(part) / "applications" for part in data_dirs.split(":") if part]
    dirs += [
        home / ".local/share/flatpak/exports/share/applications",
        Path("/var/lib/flatpak/exports/share/applications"),
        Path("/var/lib/snapd/desktop/applications"),
    ]
    # Keep stable order, remove duplicates.
    return list(dict.fromkeys(dirs))


def available(command: list[str], *, timeout: float = 4.0) -> bool:
    if not shutil.which(command[0]):
        return False
    try:
        return subprocess.run(
            command, check=False, timeout=timeout,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        ).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def installed_players() -> dict[str, list[str]]:
    """Identify *installed* apps, not archives sitting in Downloads.

    Native commands, desktop launchers, Flatpak and Snap are supported. A
    portable AppImage is detected once its desktop entry is registered.
    """
    definitions = {
        "Spotify": {
            "commands": ("spotify",),
            "desktops": ("spotify.desktop", "com.spotify.Client.desktop"),
            "flatpak": "com.spotify.Client",
            "snap": "spotify",
        },
        "Spotifast": {
            "commands": ("spotifast",),
            "desktops": ("spotifast.desktop", "rocks.spotifast.Spotifast.desktop"),
            "flatpak": "rocks.spotifast.Spotifast",
            "snap": None,
        },
    }
    results: dict[str, list[str]] = {}
    for player, spec in definitions.items():
        found: list[str] = []
        for command in spec["commands"]:
            location = shutil.which(command)
            if location:
                found.append("executable: " + location)
        for directory in desktop_directories():
            for filename in spec["desktops"]:
                if (directory / filename).is_file():
                    found.append("desktop entry: " + str(directory / filename))
        if available(["flatpak", "info", "--show-ref", spec["flatpak"]]):
            found.append("Flatpak: " + str(spec["flatpak"]))
        if spec["snap"] and available(["snap", "list", spec["snap"]]):
            found.append("Snap: " + str(spec["snap"]))
        if found:
            results[player] = list(dict.fromkeys(found))
    return results


def require_plasma6() -> str:
    if not shutil.which("plasmashell"):
        raise RuntimeError("KDE Plasma is not installed (plasmashell not found). Requires Plasma 6.")
    try:
        result = subprocess.run(
            ["plasmashell", "--version"], check=False, capture_output=True,
            text=True, timeout=7,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError("Cannot determine the installed Plasma version.") from exc
    version = (result.stdout + " " + result.stderr).strip()
    numbers = re.search(r"\b(\d+)\.(\d+)(?:\.\d+)?", version)
    if not numbers or int(numbers.group(1)) != 6:
        raise RuntimeError("Requires KDE Plasma 6; detected: " + (version or "unknown"))
    return version


def verify_package(package: Path) -> None:
    if package.is_symlink() or not package.is_dir():
        raise RuntimeError("Missing or symlinked widget package: " + str(package))
    metadata = json.loads((package / "metadata.json").read_text(encoding="utf-8"))
    if (
        metadata.get("KPackageStructure") != "Plasma/Applet"
        or metadata.get("KPlugin", {}).get("Id") != PLUGIN
    ):
        raise RuntimeError("Unexpected Plasma widget identifier: " + str(package))
    for name in (
        "contents/ui/main.qml", "contents/ui/VinylPopup.qml",
        "contents/ui/Record.qml", "contents/ui/ThemeColors.js",
        "contents/config/main.xml",
    ):
        if not (package / name).is_file():
            raise RuntimeError("Incomplete widget package: missing " + name)
    for path in package.rglob("*"):
        if path.is_symlink():
            raise RuntimeError("Symlinks are not permitted in the packaged widget: " + str(path))


def digest_tree(directory: Path) -> dict[str, str]:
    return {
        str(path.relative_to(directory)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(directory.rglob("*")) if path.is_file()
    }


def installation_directory() -> Path:
    data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    return data / "plasma" / "plasmoids" / PLUGIN


def install_widget() -> Path | None:
    target = installation_directory()
    verify_package(PACKAGE)
    parent = target.parent
    parent.mkdir(parents=True, exist_ok=True)

    if target.is_symlink():
        raise RuntimeError("Refusing to replace a symlinked widget installation.")
    if target.exists():
        verify_package(target)
        if digest_tree(target) == digest_tree(PACKAGE):
            print("Already installed; no changes made.")
            return None

    # Staging on target's filesystem allows atomic rename without temporary gaps.
    with tempfile.TemporaryDirectory(prefix=".spotify-corner-", dir=parent) as temp:
        work = Path(temp)
        staged = work / "new"
        shutil.copytree(PACKAGE, staged, symlinks=False)
        if digest_tree(staged) != digest_tree(PACKAGE):
            raise RuntimeError("Staged widget failed its integrity check.")
        if not target.exists():
            staged.rename(target)
            return None

        state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
        backup_dir = state / "spotify-corner-player" / "backups"
        backup_dir.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        backup = backup_dir / timestamp
        shutil.copytree(target, backup)
        if digest_tree(backup) != digest_tree(target):
            shutil.rmtree(backup)
            raise RuntimeError("Backup validation failed. Nothing was changed.")
        old = work / "old"
        target.rename(old)
        try:
            staged.rename(target)
        except BaseException:
            old.rename(target)
            raise
        return backup


def uninstall_widget() -> None:
    target = installation_directory()
    if not target.exists() and not target.is_symlink():
        print("Corner Media Player widget is not installed.")
        return
    verify_package(target)
    shutil.rmtree(target)
    print("Uninstalled Corner Media Player widget only.")
    print("Existing Plasma panel layout, settings and Emerald Vinyl are unchanged.")
    print("Sign out/in to clear any loaded Plasma instance.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    options = parser.add_mutually_exclusive_group()
    options.add_argument("--check", action="store_true", help="read-only compatibility and player preflight")
    options.add_argument("--uninstall", action="store_true", help="remove only this widget")
    args = parser.parse_args()

    if os.geteuid() == 0:
        parser.error("Run as your normal KDE user; do NOT use sudo.")

    try:
        if args.uninstall:
            uninstall_widget()
            return 0
        version = require_plasma6()
        detected = installed_players()
        print("Desktop: " + version)
        for name in ("Spotify", "Spotifast"):
            paths = detected.get(name, [])
            print(f"{name}: " + ("INSTALLED" if paths else "not detected"))
            for path in paths:
                print("  " + path)
        if not detected:
            raise RuntimeError(
                "Neither Spotify nor Spotifast is installed or registered. "
                "Install at least one first, then run this setup again. "
                "An AppImage only in Downloads is not an installed player."
            )
        if args.check:
            print("Preflight passed; no changes made.")
            return 0
        backup = install_widget()
        print("Widget installed in: " + str(installation_directory()))
        if backup:
            print("Previous installation backed up at: " + str(backup))
        print("Open Plasma Edit Mode > Add Widgets > 'Corner Media Player (Plasma 6)'.")
        print("If it is not listed, sign out and in before adding it.")
        print("Existing Emerald Vinyl was not changed.")
        return 0
    except (OSError, RuntimeError, ValueError, KeyError, json.JSONDecodeError) as error:
        print("Setup stopped: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
