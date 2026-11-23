# Spotify Corner Player for Windows

**Latest test candidate: v1.3.0** | **Known working release: v1.2.4**

Windows PowerShell 5.1 / WPF mini-player for the Spotify desktop app. The existing Music drawer stays on the middle-right edge of the primary display. v1.3.0 adds five theme presets with contrasting accents and a selector **inside the player**. The original WPF playback logic and panel positioning remain based on v1.2.4.

## Install (Windows 10 1809+ or Windows 11)

1. Download the **complete v1.3.0 Windows ZIP** from the release asset, or build it using `Build-Release.sh`.
2. Extract the ZIP using File Explorer's **Extract All**.
3. Double-click `Install.bat` in the extracted folder.
4. Hover at the **middle-right screen edge**, then click **Music** to open the player. Use the regular Windows desktop Spotify app.

The installer requires no administrator access. It installs per Windows user, starts the player, and registers login startup. No PowerShell commands need to be pasted.

## Theme settings inside the player

Click the **◐ palette button** next to the close **×** control. A popup shows all five themes, two color swatches per theme, and a checkmark next to the active one. Choose a theme from the list. It saves to `%LOCALAPPDATA%\SpotifyCornerPlayer\theme.txt`, refreshes only the player process, and reopens the drawer if it was already expanded. No terminal is necessary.

| Theme | Primary palette | Contrast |
| --- | --- | --- |
| Burgundy Rose | Deep burgundy, rose pink | Original palette unchanged |
| Emerald Forest | Dark emerald, mint | **Coral** accents |
| Midnight Sapphire | Navy, royal blue, icy blue | Cool blue accents, unchanged |
| Royal Amethyst | Plum and lavender | **Gold** accents |
| Obsidian Gold | Charcoal and muted gold | **Purple** accents |

The tray icon also offers the same **Color theme** menu. Theme choice persists after signing out or restarting. Changing it does not restart Spotify or Windows.

## Features retained from v1.2.4

- Music tab animated from middle-right edge, drawer expands left, `Ctrl+Shift+Q` toggle and tray controls.
- Previous/next/play/pause; Spotify-only Windows audio-session volume and mute (not system volume).
- Song and playback progress metadata when Windows makes it available.
- Vinyl spins only when Spotify is playing. Pausing freezes it.
- Lyrics button opens a search in the default browser.
- Bounded local logs, login startup and one-click uninstall.
- **No album artwork loading**. It was deliberately removed from stable v1.2.4.

## Uninstall and recovery

- `Uninstall.bat` removes the installed player, startup shortcut and the optional PowerShell diagnostic helper. Logs remain for debugging.
- `Restore-v1.2.4.bat` installs the *known-working* v1.2.4 version if you encounter a regression. v1.2.4 ignores the saved theme.
- Diagnostics: `%LOCALAPPDATA%\SpotifyCornerPlayer\Logs\player.log`. In PowerShell 5.1, the optional `spotifyPlayerLogs -Tail 80` command opens the latest errors.

Windows SmartScreen may warn about an unsigned custom installer. Run the ZIP only from a trusted repository. The launcher uses execution policy bypass for its child PowerShell process only; no machine-wide policy change.

## Build and publish the complete Windows ZIP from Linux

```bash
git switch feature/v1.3.0-color-themes
bash ./Build-Release.sh
```

Output: `dist/Spotify-Corner-Player-v1.3.0-Windows.zip`. This ZIP contains the v1.3.0 player, known working v1.2.4 script, both older rollback candidates, log helper, install/uninstall/restore launchers, setup wrapper, and README.

The `Build-Release.sh` command validates the pinned v1.2.4 source, WPF XAML well-formedness, theme-button presence, palette coverage and ZIP CRC. It does **not** publish a release; the `dist/` directory is ignored by Git. Attach the ZIP as a GitHub Release asset only after Windows testing. `Build-Local-Project.sh` is retained as an alias to the newer release builder.

## Testing status

Stable v1.2.4 was confirmed working on Windows on November 22, 2026. The themed v1.3.0 branch is **not yet tested on Windows**, so it remains a test candidate rather than replacing the published stable release.

Windows acceptance checklist: install; reveal middle-right Music tab; click palette button and switch among all 5 themes; verify emerald/coral, purple/gold and gold/purple contrast accents; confirm auto-reopen and persistence across login; exercise Spotify controls, volume, vinyl and keyboard shortcut; test `Restore-v1.2.4.bat` and `Uninstall.bat`.
