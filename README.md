# Spotify Corner Player

A lightweight, unofficial Spotify music controller with two **native implementations** in one open-source repository.

> **Current stable: [v1.4.0](https://github.com/Ali7488/Spotify-Corner-Player/releases/tag/1.4.0).** Verified working on Windows and CachyOS KDE Plasma 6, with automated platform checks. The previous [v1.3.0 release](https://github.com/Ali7488/Spotify-Corner-Player/releases/tag/1.3.0) remains available for rollback.

| Platform | Implementation | Media source |
| --- | --- | --- |
| Windows 10/11 | PowerShell 5.1, WPF, Windows media sessions | Spotify desktop |
| KDE Plasma 6 | QML / Qt Quick, KDE Plasma and MPRIS | Spotify or Spotifast |

The two versions are packaged as **separate ZIPs** under the same GitHub release. They are not one cross-platform binary, and there is no mandatory background web service.

## Features

Both versions offer:

- Five dark themes, selectable from the popup: Burgundy Rose, Emerald Forest/Coral, Midnight Sapphire, Royal Amethyst/Gold, Obsidian Gold/Purple
- Animated vinyl record that follows playback state
- Track metadata, play/pause, previous/next, a lyrics web-search shortcut
- Compact/expanded UI (new in v1.4)
- Repeat controls only when exposed by the selected media session (new in v1.4)
- Per-user installation and preservation of existing settings

**Windows:** right-edge drawer, tray menu, `Ctrl+Shift+Q`, Spotify-specific volume/mute control, **seek slider** when Windows reports that seeking is supported (new in v1.4). **No pin/unpin option on Windows in v1.4.** Album artwork is intentionally not loaded on Windows due to previous stability issues.

**KDE Plasma 6:** album-cover vinyl, Spotify/Spotifast/Auto selection, player-specific volume control, and **Pin open/Unpin** (Linux-only in v1.4). Plasma handles its native panel and MPRIS media sessions. See [Linux setup and compatibility notes](linux/plasma6/README.md).

Repeat and seeking may be disabled if Spotify/Spotifast does not expose them through its operating-system media interface. The widget cannot force support that the player has not implemented.

## Installation

### Windows

Download the **complete Windows ZIP**, extract, and double-click `Install.bat`. Do not run the source script from inside a compressed ZIP. Install uses the current Windows user account and does not require Administrator.

The player is accessible through the middle-right edge, the tray icon, or `Ctrl+Shift+Q`. Select themes and compact mode from the popup.

Run `Uninstall.bat` to remove the installed app and startup shortcut. `Restore-v1.2.4.bat` is included as an emergency fallback.

### KDE Plasma 6 (Linux)

Download the **Plasma6 ZIP**, extract and run the installer under your normal desktop user:

```bash
cd Spotify-Corner-Player-Plasma6
python3 install.py --check
python3 install.py
```

Open Plasma **Edit Mode → Add Widgets → Spotify Corner Player (Plasma 6)**. The applet requires Plasma 6 and at least one installed Spotify/Spotifast application. The installer refuses to modify any widget files if the prerequisite check fails.

The Linux widget has a separate package ID from the original Emerald Vinyl, so the original is not removed or overwritten. You may remove the old widget manually after confirming the new one works.

## Safe upgrades, including manually installed v1.2.4

**Do not uninstall old versions by deleting guessed folders or killing all Spotify processes.**

Windows v1.4 installs to the same per-user `%LOCALAPPDATA%\SpotifyCornerPlayer\Spotify-Corner-Player.ps1` as the older scripts. This includes manually installed versions that **did not come from GitHub Releases**, such as v1.2.4. The installer:

1. Verifies the owner marker `SpotifyCornerPlayer/1` and checks any existing startup shortcut belongs to this app.
2. Stops only the existing Spotify Corner Player instance via its per-user stop event (not Spotify itself).
3. Creates a timestamped backup of the previous installed player and startup shortcut.
4. Replaces the installed script and startup entry in place, rather than leaving a second version installed.
5. Restores the previous script/shortcut if the new app cannot start. It attempts to relaunch the old app.
6. Preserves existing themes, diagnostic logs and other per-user settings.

To inspect without changing anything, use Windows PowerShell 5.1 from the extracted directory:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Setup.ps1 -Mode Check
```

This detects the old owned script by its installed contents, **not by where the ZIP was downloaded**. Unrecognized folders, startup entries or links are refused; an unidentified or unrelated application is never silently deleted. If someone copied the player script into an unrelated location and ran it without installing, there is no safe automatic uninstall guarantee.

Linux upgrades only the matching Plasma package ID and creates a backup under `~/.local/state/spotify-corner-player/backups/`. The installer never removes another widget or application.

## Build and validation

From a checkout containing the complete source:

```bash
bash Build-Release.sh
python3 -m unittest discover -s linux/plasma6/tests -v
python3 linux/plasma6/build-release.py
```

Windows PowerShell 5.1 parsing, WPF XAML checks, ownership/migration fixtures, Linux Python tests, QML parsing, and ZIP integrity run in GitHub Actions. These checks do not substitute for running the interfaces on real desktops.

The project does not manage Spotify accounts, send telemetry, or stream music independently. All music playback remains with Spotify or Spotifast. The program is unofficial and not affiliated with Spotify or KDE.

This is a public personal utility project, **not a résumé or portfolio project**.
