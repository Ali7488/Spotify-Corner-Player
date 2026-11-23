# Spotify Corner Player

An unofficial, public Spotify/Spotifast music widget project with **two native implementations** in one repository.

| Platform | Implementation | Download/build |
| --- | --- | --- |
| Windows 10/11 | Windows PowerShell 5.1 + WPF | [Windows releases](https://github.com/Ali7488/Spotify-Corner-Player/releases) and `Install.bat` |
| **KDE Plasma 6 (Linux)** | Qt Quick / QML Plasma widget + MPRIS | [Linux setup guide](linux/plasma6/README.md) and `linux/plasma6/build-release.py` |

**Linux preflight:** the installer checks KDE Plasma 6 and whether **Spotify and/or Spotifast is installed** *before* installing anything. If neither app is installed, setup exits without making changes. Both implementations offer five themes: Burgundy Rose, Emerald Forest + Coral, Midnight Sapphire, Royal Amethyst + Gold, and Obsidian Gold + Purple. The Linux widget adds a source selector (Auto / Spotify / Spotifast) and stores both settings through KDE KConfig.

This is a public **personal utility / hobby project, not a résumé or portfolio project**. Neither platform's code should be presented as a professional experience claim.

The Linux applet is packaged separately and does **not** replace your current Emerald Vinyl applet without you explicitly doing so. Both implementations should be treated as previews until platform-specific UI testing passes.

---

## Windows Spotify Corner Player

A small, per-user Windows PowerShell 5.1 / WPF player for the **Spotify desktop application**.

**Known working baseline: v1.2.4** (confirmed on a Windows laptop on November 22, 2026). The original player script is archived unchanged. The new `Install.bat` and `Setup.ps1` only automate installation; they do not redesign the UI.

## Install on another Windows computer

1. Download the **complete Windows release ZIP** or this repository's ZIP after source assembly.
2. In File Explorer, right-click the ZIP and select **Extract All**.
3. Open the extracted folder and **double-click `Install.bat`**.
4. Read the status in the terminal window. No admin rights or developer tools are required.
5. Open the regular Spotify desktop app and play music. The Music tab is at the **middle-right edge of the primary monitor**; click it to reveal the player toward the left.

Windows SmartScreen or other security software may flag an unsigned custom script. Only run code from a trusted source and review it if prompted. This package uses per-invocation `-ExecutionPolicy Bypass`; it does not change your system-wide PowerShell policy.

## Controls

- Middle-right Music tab, or `Ctrl+Shift+Q`, or tray icon.
- Previous / play-pause / next track.
- Spotify-only audio-session volume and mute (does not change system volume).
- Vinyl animation follows Spotify's *Playing* state, and stops on pause.
- Song metadata/progress if available from Windows Media sessions.
- Lyrics opens a browser search.
- Sign-in startup shortcut and private, rotated logs.
- No Spotify API token, Node.js or Python needed.

Album artwork retrieval is **intentionally removed** from v1.2.4 due to previously observed errors. Do not advertise artwork support.

## Uninstall

Double-click `Uninstall.bat`. The app and its startup shortcut are removed, as well as the optional PowerShell `spotifyPlayerLogs` helper. Logs are retained for diagnostics. No system-wide modification is performed.

## Diagnostics

Open **Windows PowerShell 5.1** after installation and run `spotifyPlayerLogs -Tail 80`, or view `%LOCALAPPDATA%\SpotifyCornerPlayer\Logs\player.log`.

If the optional log helper fails, the player may already be installed; the setup window explicitly reports this partial success.

## Manual commands

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File '.\Spotify-Corner-Player-v1.2.4.ps1' -Mode Install
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File '.\Spotify-Corner-Player-v1.2.4.ps1' -Mode Uninstall
```

## Release layout

- `Install.bat`: user-facing double-click launcher.
- `Uninstall.bat`: user-facing removal launcher.
- `Setup.ps1`: preflight parser checks, then calls the verified player's built-in installer and diagnostic helper.
- `Spotify-Corner-Player-v1.2.4.ps1`: original accepted working player, untouched.
- `Install-SpotifyPlayerLogs.ps1`: optional diagnostic profile function, reversible.
- `Spotify-Corner-Player-v1.2.3-rollback.ps1`: historical rollback candidate.
- `Spotify-Corner-Player-v1.2.0-rollback.ps1`: historical pre-regression fallback.

All original source files are from the private `Ali7488/pharm` canonical archive. Their Git blob SHA-1 values are pinned in `Build-Local-Project.sh` so assembly will stop if the archive changes unexpectedly. The GitHub repository should contain source code, not logs or user machine data.

## Maintainer: create the full project and Windows ZIP from the private archive

From a Linux machine authenticated with the GitHub CLI (`gh auth status`):

```bash
bash ./Build-Local-Project.sh
```

This populates `~/projects/PersonalProjects/Spotify-Corner-Player` and creates `dist/Spotify-Corner-Player-v1.2.4-Windows.zip` with everything needed for Windows. It runs Git blob verification, creates a clean local Git repository if needed, and does **not** push or publish anything. Run it only from this bootstrap directory.

After inspecting the project in Linux:

```bash
cd ~/projects/PersonalProjects/Spotify-Corner-Player
git add .
git commit -m "Import Spotify Corner Player v1.2.4 with one-click Windows setup"
gh repo create Spotify-Corner-Player --private --source . --remote origin --push
```

The final command creates the remote, so do not use it if the remote repository already exists. You can later attach the `dist/*.zip` release file via `gh release create v1.2.4 dist/Spotify-Corner-Player-v1.2.4-Windows.zip --title 'Spotify Corner Player v1.2.4'`.

## Testing

Static packaging and Bash checks do not prove WPF/window/COM behavior. Verify on a Windows test machine: installer launch, middle-right tab behavior, vinyl pausing, Spotify audio session controls, lyrics link, startup after sign-in, uninstall, and log-helper command. Keep v1.2.4 as the stable baseline until new runtime tests pass.
