#Requires -Version 5.1
<#
.SYNOPSIS
    One-click setup and migration check for Corner Media Player v1.4.3.
.DESCRIPTION
    Uses the v1.4.3 player with compact view, repeat and seeking based on the accepted v1.2.4 baseline. Invokes its own install
    logic and the independently reversible Windows PowerShell logging helper.
    Must be run with Windows PowerShell 5.1 by Install.bat or Uninstall.bat.
#>
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Uninstall', 'Check')]
    [string] $Mode = 'Install'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
        $PSVersionTable.PSEdition -ne 'Desktop' -or
        $PSVersionTable.PSVersion.Major -ne 5) {
        throw 'This setup requires Windows PowerShell 5.1 on Windows.'
    }

    $root = Split-Path -Parent $PSCommandPath
    $player = Join-Path $root 'Spotify-Corner-Player-v1.4.3.ps1'
    $helper = Join-Path $root 'Install-SpotifyPlayerLogs.ps1'
    $engine = Join-Path $PSHOME 'powershell.exe'

    foreach ($file in @($player, $helper)) {
        if (!(Test-Path -LiteralPath $file -PathType Leaf)) {
            throw "Required file missing: $file. Extract the COMPLETE release ZIP before installing."
        }
        $tokens = $null
        $errors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors)
        if ($errors.Count -gt 0) {
            throw "PowerShell parse error in $file : $($errors | Out-String)"
        }
    }

    if ($Mode -eq 'Check') {
        Write-Host 'Inspecting existing Corner Media Player installation...' -ForegroundColor Cyan
        & $engine -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File $player -Mode Check
        if ($LASTEXITCODE -ne 0) { throw 'Existing installation could not be safely identified.' }
        Write-Host 'Read-only upgrade check complete.' -ForegroundColor Green
        exit 0
    }
    if ($Mode -eq 'Install') {
        if ([Environment]::OSVersion.Version.Build -lt 17763) {
            throw 'Requires Windows 10 version 1809 or later, or Windows 11.'
        }
        Write-Host 'Installing Corner Media Player v1.4.3 for the current Windows user...' -ForegroundColor Cyan
        & $engine -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File $player -Mode Install
        if ($LASTEXITCODE -ne 0) { throw "Player installer failed (exit code $LASTEXITCODE)." }

        Write-Host 'Installing the optional spotifyPlayerLogs diagnostic command...' -ForegroundColor Cyan
        & $engine -NoLogo -NoProfile -ExecutionPolicy Bypass -File $helper -Mode Install
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The player installed, but the optional diagnostic helper failed (exit code $LASTEXITCODE)."
            Write-Warning 'The player itself is already installed; see the messages above to repair the helper.'
            exit 2
        }

        Write-Host ''
        Write-Host 'SUCCESS: Installed and launched, with startup at login.' -ForegroundColor Green
        Write-Host 'Use the Music tab at the middle-right edge, Ctrl+Shift+Q, or the tray icon.'
        Write-Host 'Themes: use the in-player color button (or tray menu). Compact mode: in-player toggle.'
        Write-Host 'Logs: %LOCALAPPDATA%\SpotifyCornerPlayer\Logs\player.log'
    }
    else {
        Write-Host 'Removing Corner Media Player for the current Windows user...' -ForegroundColor Cyan
        & $engine -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File $player -Mode Uninstall
        if ($LASTEXITCODE -ne 0) { throw "Player uninstaller failed (exit code $LASTEXITCODE)." }
        & $engine -NoLogo -NoProfile -ExecutionPolicy Bypass -File $helper -Mode Remove
        if ($LASTEXITCODE -ne 0) { throw "Optional log helper removal failed (exit code $LASTEXITCODE)." }
        Write-Host 'SUCCESS: Removed player, startup shortcut and log helper.' -ForegroundColor Green
        Write-Host 'Existing diagnostic logs are intentionally retained.'
    }
    exit 0
}
catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
