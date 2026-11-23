# Spotify Corner Player for KDE Plasma 6 (Linux)

**Version 1.4.0 stable. One public repository, separate release ZIPs:**
- `Spotify-Corner-Player-v1.4.0-Windows.zip`: Windows PowerShell/WPF implementation
- `Spotify-Corner-Player-v1.4.0-Plasma6.zip`: KDE Plasma 6 / Qt Quick implementation

The Linux widget is based on the custom **Emerald Vinyl v1.0.3** widget. It is **not** a port of Windows WPF code. Both versions share the same five named visual themes and in-player theme selection, while each uses its native platform's media APIs.

This is a public hobby utility, **not a resume or portfolio project**. Do not add it to career claims or resume inventories.

## Requirements

- **KDE Plasma 6**, Qt 6 / Qt Quick Controls and KDE's standard Plasma/Kirigami/MPRIS QML modules.
- Python 3 (standard library only) for installation.
- At least **one installed** player: Spotify desktop or Spotifast. Either may be native, desktop-registered, or Flatpak; Spotify Snap is also detected.
- A running player must expose an **MPRIS** session to provide playback controls. The widget never asks for Spotify credentials.
- Plasma 5, GNOME, and generic Qt-only environments are **not supported**.

The implementation uses Plasma 6 APIs, not `pacman`, `apt`, or Fedora-specific paths. That makes it suitable for Kubuntu, CachyOS, Fedora KDE, openSUSE, Arch KDE and similar Plasma 6 installations **when their necessary KDE QML modules are available**. Universal compatibility is a target, not a claim of tests on every distribution.

An AppImage lying in Downloads is not enough for preflight. Install/integrate its desktop entry, or use a standard native/Flatpak installation.

## Install (two-step preflight)

Extract the Linux ZIP and run:

```bash
cd Spotify-Corner-Player-Plasma6
python3 install.py --check
python3 install.py
```

The installer **checks KDE Plasma 6 and installed Spotify/Spotifast before modifying any files**. If neither is detected it stops with an error and does not install anything. It does **not** install Spotify, Spotifast or any dependency without permission.

Installation is **per user** at `~/.local/share/plasma/plasmoids/org.mohannad.spotify.cornerplayer` (or `$XDG_DATA_HOME/plasma/plasmoids/...`). No sudo. Updates create an integrity-checked backup under `~/.local/state/spotify-corner-player/backups/` (or `$XDG_STATE_HOME`). A symlinked or unexpected target is refused.

Open Plasma desktop/panel **Edit Mode → Add Widgets**, find **Spotify Corner Player (Plasma 6)**, and place it on the desired panel. If not found, log out and back in. The widget does not silently rewrite or restart panels on installation. It does not replace the existing Emerald Vinyl widget; remove that manually **only after the new one works**.

## Change color or select media source without a terminal

Click the widget's small vinyl icon to open the popup.

- **◐ color button** opens a menu with five themes and their paired accent swatches. Selection saves in Plasma's ordinary KConfig widget settings, and the popup recolors in place.
- **Compact view / Expanded view:** reduces the popup to track information, seeking, volume and transport controls. The control is directly in the popup and the preference persists.
- **Pin open / Unpin (Linux only):** uses Plasma 6's native `hideOnWindowDeactivate` property so the popup remains open when it loses focus. There is intentionally no pin control in Windows v1.4.
- **Repeat:** cycles Off → Repeat all → Repeat one, only when the selected MPRIS player implements the optional loop property.
- **Volume:** controls only the selected MPRIS player's own normalized volume (0–100%). It does not adjust global sound volume. Unsupported players show N/A and disable the control.
- **♫ source button** opens **Auto / Spotify / Spotifast**. Auto follows active playback, otherwise prefers a detected Spotifast MPRIS session. Other MPRIS players (YouTube Music, Firefox, etc.) are ignored.
- If the chosen app is installed but not running, the popup shows that its MPRIS session is not running. The **Open Spotify / Open Spotifast** action tries registered app launchers, then native/Flatpak, with Snap fallback for Spotify. The source can still be selected when idle.
- Preference survives Plasma restarts. Unlike the Windows WPF implementation, color changes in the QML widget need **no app restart**.

| Theme | Main | Contrasting accent |
| --- | --- | --- |
| Burgundy Rose | Burgundy `#800020` | Rose, original Windows style |
| Emerald Forest | Emerald `#146B50` | Coral `#FA9888` |
| Midnight Sapphire | Blue `#234C8A` | Cool blue `#76A2DC` |
| Royal Amethyst | Purple `#7043AB` | Gold `#E4BD75` |
| Obsidian Gold | Muted gold `#88652F` | Purple `#B898F1` |

## Player controls

Artwork-centered vinyl spins only while the selected MPRIS player reports playback, with animation/track transitions inherited from Emerald Vinyl. The popup retains previous / play-pause / next, seek when supported, shuffle when supported, current song and artist, elapsed/total time, an Open Player button, and a lyrics browser search. The QML widget does not control a global audio endpoint volume; that Windows-specific capability is not falsely advertised for Linux.

## Upgrade from manually installed or earlier versions

The installer detects the existing applet by its **Plasma plugin ID**, not by how its ZIP was downloaded. It verifies that the existing package belongs to Spotify Corner Player, then backs it up before replacing it. KDE KConfig preferences remain intact. It refuses symlinked or unrelated installation paths.

The original Emerald Vinyl applet has a different plugin ID and is not automatically removed. Its own source and settings are intentionally preserved.

## Uninstall

```bash
python3 install.py --uninstall
```

Removes only this widget's own package files after validating the plugin ID. It leaves existing Plasma panels, Spotify/Spotifast, the earlier Emerald Vinyl applet and personal configuration intact.

## Build and publish the Linux ZIP beside Windows

From the repository root:

```bash
python3 -m unittest discover -s linux/plasma6/tests -v
python3 linux/plasma6/build-release.py
```

Output: `dist/Spotify-Corner-Player-v1.4.0-Plasma6.zip`. Attach it to the **same** GitHub Release as the corresponding Windows ZIP, with a separate asset filename. This is a co-release of two independent implementations, not one cross-platform binary:

```bash
gh release upload 1.4.0 \
  dist/Spotify-Corner-Player-v1.4.0-Plasma6.zip \
  -R Ali7488/Spotify-Corner-Player
```

v1.4.0 is confirmed working on CachyOS KDE Plasma 6. Other KDE Plasma 6 distributions should be tested individually. The existing v1.3.0 release remains available for rollback.

## Validation and limitations

Cross-distro compatibility must be verified on actual Plasma 6 desktops. The MPRIS model is KDE's own Plasma QML module and can vary across minor versions; the distro must supply it. Spotify/Spotifast media control capabilities differ by app and version. Static tests, Python fixtures, ZIP verification and QML parsing are not substitutes for live integration testing.

Recommended tests: Spotify only installed; Spotifast only installed; both installed and playing alternately; neither installed (no changes); native, Flatpak, and Spotify Snap; palette persistence; panel placement after logout; album-art changes, shuffle, seek and Open Player on Wayland/X11. Do not delete Emerald Vinyl until the new widget is confirmed functional.

## Source and credit

This QML implementation derives from the MIT-labelled Emerald Vinyl v1.0.3 applet in the author's Development Vault and uses KDE Plasma 6's MPRIS integration. It is unofficial software, not affiliated with Spotify or KDE.
