#Requires -Version 5.1
<#
Adds or removes the per-user `spotifyPlayerLogs` function in Windows PowerShell 5.1.
Makes a timestamped backup before any change and does not alter unrelated profile lines.

Install: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-SpotifyPlayerLogs.ps1 -Mode Install
Remove:  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-SpotifyPlayerLogs.ps1 -Mode Remove
#>
[CmdletBinding()]
param([ValidateSet('Install','Remove')][string]$Mode = 'Install')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or [Environment]::OSVersion.Platform -ne 'Win32NT') {
    throw 'Use Windows PowerShell 5.1 (powershell.exe) for this profile helper.'
}

$profileFile = $PROFILE.CurrentUserAllHosts
$parent = Split-Path -Parent $profileFile
$begin = '# >>> Spotify Corner Player Logs (managed) >>>'
$end = '# <<< Spotify Corner Player Logs (managed) <<<'
$rx = '(?ms)^' + [regex]::Escape($begin) + '\r?\n.*?^' + [regex]::Escape($end) + '\r?\n?'
$old = if (Test-Path -LiteralPath $profileFile -PathType Leaf) {
    [IO.File]::ReadAllText($profileFile)
} else { '' }
if ($old.Contains($begin) -xor $old.Contains($end)) {
    throw "The PowerShell profile contains an incomplete managed block. Inspect manually: $profileFile"
}
if ($old.Contains($begin) -and !([regex]::IsMatch($old,$rx))) {
    throw "Managed block boundaries are malformed: $profileFile"
}
$clean = [regex]::Replace($old, $rx, '').TrimEnd("`r", "`n")
$block = @'
# >>> Spotify Corner Player Logs (managed) >>>
function global:spotifyPlayerLogs {
    [CmdletBinding()]
    param([switch]$Folder, [ValidateRange(0,10000)][int]$Tail = 0)
    $folderPath = Join-Path $env:LOCALAPPDATA 'SpotifyCornerPlayer\Logs'
    $logPath = Join-Path $folderPath 'player.log'
    if (!(Test-Path -LiteralPath $folderPath -PathType Container)) {
        Write-Warning "No Spotify Corner Player diagnostics folder yet: $folderPath"
        return
    }
    if ($Folder) {
        Start-Process -FilePath explorer.exe -ArgumentList ('"{0}"' -f $folderPath)
    } elseif ($Tail -gt 0) {
        if (Test-Path -LiteralPath $logPath -PathType Leaf) {
            Get-Content -LiteralPath $logPath -Tail $Tail
        } else { Write-Warning "No player.log yet: $logPath" }
    } elseif (Test-Path -LiteralPath $logPath -PathType Leaf) {
        Start-Process -FilePath notepad.exe -ArgumentList ('"{0}"' -f $logPath)
    } else {
        Start-Process -FilePath explorer.exe -ArgumentList ('"{0}"' -f $folderPath)
    }
}
# <<< Spotify Corner Player Logs (managed) <<<
'@
$new = if ($Mode -eq 'Install') {
    if ($clean.Length -eq 0) { $block + "`r`n" }
    else { $clean + "`r`n`r`n" + $block + "`r`n" }
} else {
    if ($clean.Length -gt 0) { $clean + "`r`n" } else { '' }
}
if ($new -ceq $old) {
    Write-Output "No change necessary: $profileFile"
    return
}
$null = New-Item -ItemType Directory -Path $parent -Force
if (Test-Path -LiteralPath $profileFile -PathType Leaf) {
    $backup = $profileFile + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
    Copy-Item -LiteralPath $profileFile -Destination $backup -ErrorAction Stop
    Write-Output "Profile backup: $backup"
}
[IO.File]::WriteAllText($profileFile, $new, [Text.UTF8Encoding]::new($true))
Write-Output $(if ($Mode -eq 'Install') {
    "Installed spotifyPlayerLogs in $profileFile. Open a NEW Windows PowerShell window to use it."
} else { "Removed only Spotify log helper block from $profileFile" })
