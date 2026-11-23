# Spotify Corner Player for Marah | v1.2.4

**Release:** 2026-11-22. **Status: USER-CONFIRMED WORKING on Marah's Windows PC (2026-11-22).** Mohannad reported "works" after installing the final v1.2.4 build with playback-gated vinyl. Windows PowerShell 5.1, Windows 10 1809+ or Windows 11. No admin rights required.

**Acceptance record (2026-11-22):** Prior versions v1.2.1-v1.2.3 had reported flashing, detached/backwards Music ribbon, or album-art failures. The last v1.2.4 adjustment made the vinyl spin only when Spotify is playing. After that adjustment, Mohannad confirmed the player **works**. That confirmation supports normal Windows runtime success; it does not prove every individual feature (login autostart, multi-display positioning, lyrics search, volume/mute, or restart behavior) was independently exercised. Preserve v1.2.4 as the working baseline, and do not casually reintroduce album-cover retrieval or an independent floating ribbon window.

## What changed from v1.2.3

- **Tab direction fixed:** The right-edge **Music** tab now has **rounded left corners** and a **square right edge** that meets the monitor boundary. In the collapsed state, its tooltip and accessibility label read **Open player**, not **Collapse player**. This is the backwards appearance and tooltip seen in the screenshot.
- **Correct pull-out direction retained:** Hover at the middle-right edge and only the 72 × 34 device-independent-pixel Music tab slides left into view from the right-hand screen boundary. Click the tab: the 354-DIP-wide player reveals from right to left, flush with the screen's working-area right edge, while the tab travels **rightward entirely offscreen**. Click × or use the shortcut to reverse the animation. The single 426 × 398 DIP transparent WPF window stays fixed in place.
- **Entirely removed Spotify album-cover retrieval.** No artwork thumbnail streams, WinRT DataReader, album-art download, image decoding, retries, or blank-cover placeholders. Media transport metadata is still required to show the current song title, artist, progress, and play/pause status. The 2026-11-22 logs showed the old artwork conversion failed on Windows PowerShell 5.1, so the best fix here is not to use it.
- **Animated vector vinyl:** A detailed burgundy/black record with circular grooves and an inset center label replaces the artwork. On opening the full player, the record fades/scales into view but stays still until Spotify reports **Playing**. It freezes at its current angle when playback pauses, closes, becomes unavailable, or the panel is collapsed; it resumes from that angle when playback continues. No images, fonts downloaded, or external assets are used.
- **Symbol-only transport buttons:** Previous track, play/pause (state-dependent), and next track use crisp vector icons instead of button text. Tooltips and Windows accessibility labels describe the action. Playback behavior is otherwise unchanged.
- **All other v1.2.3 features retained:** Spotify-only volume slider (Windows Core Audio session; disabled if unavailable), mute/unmute, progress, Open Spotify, lyrics browser search, tray controls, Ctrl+Shift+Q, login startup, private error logging, and reversible installation.

## Exact installation command

Download **`Spotify-Corner-Player-v1.2.4-Release.zip`** into the Windows **Downloads** directory. Open **Windows PowerShell** (not PowerShell 7), paste the entire command below. It extracts the ZIP, enters the release folder, validates PowerShell parsing, installs the player, and installs or refreshes the `spotifyPlayerLogs` profile function.

```powershell
$ErrorActionPreference = 'Stop'
$zip = Join-Path $HOME 'Downloads\Spotify-Corner-Player-v1.2.4-Release.zip'
$folder = Join-Path $HOME 'Downloads\Spotify-Corner-Player-v1.2.4'
if (!(Test-Path -LiteralPath $zip -PathType Leaf)) { throw "ZIP not found: $zip" }
Expand-Archive -LiteralPath $zip -DestinationPath $folder -Force
Set-Location -LiteralPath $folder
$tokens = $null; $errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $folder 'Spotify-Corner-Player-v1.2.4.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) { throw ($errors | Out-String) }
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File '.\Spotify-Corner-Player-v1.2.4.ps1' -Mode Install
if ($LASTEXITCODE -ne 0) { throw 'Player installation failed' }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\Install-SpotifyPlayerLogs.ps1' -Mode Install
if ($LASTEXITCODE -ne 0) { throw 'Log helper installation failed' }
```

The per-user installer stops the existing owned player, saves and replaces the script at `%LOCALAPPDATA%\SpotifyCornerPlayer\Spotify-Corner-Player.ps1`, updates the login startup shortcut, and starts the player in the tray. It preserves logs. The profile helper makes a timestamped backup of existing PowerShell profiles before editing, and can be removed separately.

## Usage and diagnostics

- Hover **middle-right** near the primary display edge for the Music tab. Click to expand. In expanded view the tab goes rightward out of the screen and the player is flush right. × collapses the player. Ctrl+Shift+Q toggles; tray icon menu can open/exit the player.
- **♫ spinning vinyl** is decorative, but follows Spotify playback: spins while Playing and stays still while Paused, stopped, or unavailable. Artwork loading is intentionally absent.
- Playback buttons are icon-only, but have tooltips: previous, play or pause, next.
- **Volume:** controls Spotify's Windows audio session; not system master volume. If no Spotify session exists on the default playback endpoint, volume/mute are disabled. Spotify web player not supported.
- **Lyrics:** opens a default-browser search for the song title and artist; no internal lyrics database or scraper.
- **Logs:** `%LOCALAPPDATA%\SpotifyCornerPlayer\Logs\player.log`; logs rotate around 1 MiB to `player.previous.log`. They do not intentionally include song titles or file contents.

Open a **new** Windows PowerShell console after installing the helper and use:

```powershell
spotifyPlayerLogs           # Open the log in Notepad
spotifyPlayerLogs -Tail 80  # Last 80 lines in the console
spotifyPlayerLogs -Folder   # Open the diagnostic folder
```

## Validation checklist on Windows

1. Place cursor at right edge near its middle. Music tab slides **left into view once**, with rounded **left** side, straight **right** side, and tooltip **Open player**.
2. Click Music. Panel emerges **leftward**, ending flush against the right edge, and the Music tab moves completely **right/offscreen**. It must not overlap the player.
3. Vinyl smoothly scales/fades in but only spins when Spotify reports Playing. Pause Spotify and verify the record stops in place; resume and verify it continues from the same angle. Close ×: record stops and tab returns to right screen edge. No flashing loops.
4. Song name, artist, progress, and Spotify playback icon state update; previous/next buttons work. No artwork requests or `[Artwork]` errors from this new version.
5. Volume and mute affect **Spotify only**, with `--`/disabled controls if there is no matching audio session.
6. Lyrics opens a browser search after a track is detected. `spotifyPlayerLogs -Tail 80` displays v1.2.4 startup and UI events; restart Windows to test startup.

**Important:** XML validity, static inspection and ZIP CRC checks do not prove Windows rendering or COM audio behavior. If the UI still flashes, send the v1.2.4 log and use rollback instead of reinstalling it repeatedly.

## Rollback and uninstall

The release ZIP contains both **v1.2.3 rollback** (previous candidate with volume/lyrics) and **v1.2.0 rollback** (earlier functioning baseline without the corrected ribbon or volume), in the same folder. To revert after extracting and entering the folder:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File '.\Spotify-Corner-Player-v1.2.3-rollback.ps1' -Mode Install
```

Or revert to earlier v1.2.0:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File '.\Spotify-Corner-Player-v1.2.0-rollback.ps1' -Mode Install
```

To uninstall the current player and startup shortcut while keeping diagnostics:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File '.\Spotify-Corner-Player-v1.2.4.ps1' -Mode Uninstall
```

The PowerShell logging helper remains installed until removed with `Install-SpotifyPlayerLogs.ps1 -Mode Remove`.

## Source-of-truth repositories

This release is logged in:
- `Ali7488/pharm`: `System/Marah Devices & Services/Spotify Corner Player/`
- `Ali7488/development-vault`: `75 Home Lab and System/Tools/Spotify Corner Player for Windows v1.2.4/`

Both repositories store source and documentation. Mohannad separately confirmed v1.2.4 works on Marah's Windows PC on 2026-11-22. Do not commit machine logs or sensitive personal data.