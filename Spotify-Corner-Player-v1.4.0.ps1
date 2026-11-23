#Requires -Version 5.1
<#
.SYNOPSIS
Installs Spotify Corner Player v1.4.0 for the current Windows user.

.EXAMPLE
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Spotify-Corner-Player-v1.4.0.ps1 -Mode Install

.EXAMPLE
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Spotify-Corner-Player-v1.4.0.ps1 -Mode Uninstall
#>
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Uninstall', 'Run', 'Restart')]
    [string] $Mode = 'Install',
    [switch] $PurgeLogs,
    [switch] $ShowOnStart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or $PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Run this with Windows PowerShell (powershell.exe) on Windows.'
}
if ($Mode -ne 'Uninstall' -and [Environment]::OSVersion.Version.Build -lt 17763) {
    throw 'This player needs Windows 10 version 1809 or Windows 11.'
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$eventPrefix = "Local\SpotifyCornerPlayer.$identity"
$mutexName = "$eventPrefix.Instance"
$stopName = "$eventPrefix.Stop"
$readyName = "$eventPrefix.Ready"
$installFolder = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'SpotifyCornerPlayer'
$installedScript = Join-Path $installFolder 'Spotify-Corner-Player.ps1'
$marker = Join-Path $installFolder '.owner'
$reportFile = Join-Path $installFolder 'install-report.txt'
$script:themeFile = Join-Path $installFolder 'theme.txt'
$script:layoutFile = Join-Path $installFolder 'layout.txt'
$script:scriptFilePath = $PSCommandPath
$engine = Join-Path $PSHOME 'powershell.exe'
$startupFolder = [Environment]::GetFolderPath('Startup')
$startupLink = Join-Path $startupFolder 'Spotify Corner Player.lnk'
$signature = 'SpotifyCornerPlayer/1'
$startupArgs = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Mode Run' -f $installedScript
$logFolder = Join-Path $installFolder 'Logs'
$logFile = Join-Path $logFolder 'player.log'
$script:lastMediaIssue = ''
$script:lastMediaIssueAt = [DateTime]::MinValue

# Diagnostics are private, per-user, and bounded. Never log track titles or album art bytes.
function Write-PlayerLog([string] $level, [string] $area, [string] $message) {
    try {
        $null = [IO.Directory]::CreateDirectory($logFolder)
        if ([IO.File]::Exists($logFile) -and ([IO.FileInfo]::new($logFile)).Length -gt 1048576) {
            $previous = Join-Path $logFolder 'player.previous.log'
            if ([IO.File]::Exists($previous)) { [IO.File]::Delete($previous) }
            [IO.File]::Move($logFile, $previous)
        }
        $safe = $message -replace '[\r\n]+', ' | '
        $line = '{0:u} [{1}] [{2}] {3}{4}' -f [DateTime]::UtcNow, $level, $area, $safe, [Environment]::NewLine
        [IO.File]::AppendAllText($logFile, $line, [Text.Encoding]::UTF8)
    } catch {
        # A logging failure must never disable media controls.
    }
}

function Write-MediaIssue([string] $area, [string] $message) {
    $signature = "$area/$message"
    if ($signature -ne $script:lastMediaIssue -or
        [DateTime]::UtcNow.Subtract($script:lastMediaIssueAt).TotalSeconds -ge 30) {
        Write-PlayerLog 'WARN' $area $message
        $script:lastMediaIssue = $signature
        $script:lastMediaIssueAt = [DateTime]::UtcNow
    }
}


# Theme state is per Windows user. Only a known identifier is stored; palette
# colors are embedded in this file, so startup has no external theme dependencies.
$script:themeNames = @{
    Burgundy = 'Burgundy Rose'
    Forest = 'Emerald Forest + Coral'
    Sapphire = 'Midnight Sapphire'
    Amethyst = 'Royal Amethyst + Gold'
    Obsidian = 'Obsidian Gold + Purple'
}
$script:themeMaps = @{
    Forest = @{
        '#0E0910' = '#0A0F0D'
        '#100A12' = '#0B110F'
        '#170C15' = '#0D1613'
        '#1B0C15' = '#0B201B'
        '#24131E' = '#15221E'
        '#290E1C' = '#10271F'
        '#341323' = '#163128'
        '#382035' = '#22362F'
        '#39202D' = '#223730'
        '#392031' = '#223730'
        '#3D122A' = '#16392D'
        '#452031' = '#234238'
        '#4C2C41' = '#2F4940'
        '#502D42' = '#304D43'
        '#503044' = '#334D44'
        '#5C3047' = '#34584C'
        '#5D3449' = '#38594E'
        '#643049' = '#355F51'
        '#6D3953' = '#3E685A'
        '#6F3A50' = '#3F6A5C'
        '#764057' = '#457162'
        '#800020' = '#146B50'
        '#874461' = '#4A816F'
        '#87506A' = '#558273'
        '#8C536E' = '#588777'
        '#8D294B' = '#328469'
        '#95617B' = '#669082'
        '#B56B8A' = '#72AE9A'
        '#B77494' = '#7AB19F'
        '#B94970' = '#F1947D'
        '#B95C7F' = '#64B197'
        '#BC839B' = '#88B7A7'
        '#C05A7C' = '#63B79B'
        '#C55B80' = '#E98672'
        '#C56D8C' = '#75BDA5'
        '#C684A0' = '#8AC0AE'
        '#CE7497' = '#7CC6AD'
        '#D45D87' = '#EC8B79'
        '#D77E9E' = '#86CFB7'
        '#DF7399' = '#FA9888'
        '#DFB1C1' = '#B5DBCE'
        '#E7B5C8' = '#BAE3D5'
        '#F2B4CA' = '#BAECDB'
        '#F4C5D5' = '#C9F0E3'
        '#F5CAAA' = '#FFB3A4'
        '#F5D2DE' = '#D5F2E8'
        '#F9EEF2' = '#EFF8F5'
        '#FFD9E7' = '#DCFCF1'
        '#FFF3F6' = '#F4FEFB'
        '#FFF4F7' = '#F5FEFB'
    }
    Sapphire = @{
        '#0E0910' = '#090C10'
        '#100A12' = '#0A0D12'
        '#170C15' = '#0C1117'
        '#1B0C15' = '#0B1426'
        '#24131E' = '#131A24'
        '#290E1C' = '#0F1A28'
        '#341323' = '#142133'
        '#382035' = '#212A37'
        '#39202D' = '#212B38'
        '#392031' = '#212B38'
        '#3D122A' = '#13253C'
        '#452031' = '#213044'
        '#4C2C41' = '#2D3A4B'
        '#502D42' = '#2E3C4F'
        '#503044' = '#313E4F'
        '#5C3047' = '#31435B'
        '#5D3449' = '#35465C'
        '#643049' = '#314763'
        '#6D3953' = '#3A506C'
        '#6F3A50' = '#3B516E'
        '#764057' = '#415875'
        '#800020' = '#234C8A'
        '#874461' = '#466185'
        '#87506A' = '#516886'
        '#8C536E' = '#546C8B'
        '#8D294B' = '#2C558B'
        '#95617B' = '#627894'
        '#B56B8A' = '#6D8BB3'
        '#B77494' = '#7691B5'
        '#B94970' = '#4C7AB6'
        '#B95C7F' = '#5E85B7'
        '#BC839B' = '#849CBB'
        '#C05A7C' = '#5D87BD'
        '#C55B80' = '#5E89C2'
        '#C56D8C' = '#6F93C3'
        '#C684A0' = '#86A1C4'
        '#CE7497' = '#769BCC'
        '#D45D87' = '#6091D1'
        '#D77E9E' = '#80A5D5'
        '#DF7399' = '#76A2DC'
        '#DFB1C1' = '#B2C5DE'
        '#E7B5C8' = '#B6CBE6'
        '#F2B4CA' = '#B6CFF0'
        '#F4C5D5' = '#C6DAF3'
        '#F5CAAA' = '#ACCBF3'
        '#F5D2DE' = '#D3E1F4'
        '#F9EEF2' = '#EEF3F9'
        '#FFD9E7' = '#DCEAFC'
        '#FFF3F6' = '#F4F8FE'
        '#FFF4F7' = '#F5F9FE'
    }
    Amethyst = @{
        '#0E0910' = '#0D0A0F'
        '#100A12' = '#0E0B11'
        '#170C15' = '#120D16'
        '#1B0C15' = '#1A1129'
        '#24131E' = '#1C1522'
        '#290E1C' = '#1D1126'
        '#341323' = '#251631'
        '#382035' = '#2D2236'
        '#39202D' = '#2E2237'
        '#392031' = '#2E2237'
        '#3D122A' = '#2A1639'
        '#452031' = '#342441'
        '#4C2C41' = '#3E2F49'
        '#502D42' = '#40314D'
        '#503044' = '#42334D'
        '#5C3047' = '#483458'
        '#5D3449' = '#4B3859'
        '#643049' = '#4D355F'
        '#6D3953' = '#563E68'
        '#6F3A50' = '#573F6A'
        '#764057' = '#5E4571'
        '#800020' = '#7043AB'
        '#874461' = '#694B80'
        '#87506A' = '#6E5682'
        '#8C536E' = '#735986'
        '#8D294B' = '#603383'
        '#95617B' = '#7E6690'
        '#B56B8A' = '#9472AE'
        '#B77494' = '#997BB0'
        '#B94970' = '#E2B66E'
        '#B95C7F' = '#8F65B0'
        '#BC839B' = '#A389B6'
        '#C05A7C' = '#9264B6'
        '#C55B80' = '#D1A05D'
        '#C56D8C' = '#9E76BC'
        '#C684A0' = '#A98BBF'
        '#CE7497' = '#A67DC5'
        '#D45D87' = '#D7AE67'
        '#D77E9E' = '#AF87CE'
        '#DF7399' = '#E4BD75'
        '#DFB1C1' = '#CAB6DA'
        '#E7B5C8' = '#D1BAE2'
        '#F2B4CA' = '#D6BAEC'
        '#F4C5D5' = '#DFCAEF'
        '#F5CAAA' = '#F2D49C'
        '#F5D2DE' = '#E5D5F2'
        '#F9EEF2' = '#F4EFF8'
        '#FFD9E7' = '#EEDDFB'
        '#FFF3F6' = '#FAF4FE'
        '#FFF4F7' = '#FAF5FE'
    }
    Obsidian = @{
        '#0E0910' = '#0E0D0B'
        '#100A12' = '#100F0C'
        '#170C15' = '#14120F'
        '#1B0C15' = '#17191C'
        '#24131E' = '#1F1D18'
        '#290E1C' = '#221D15'
        '#341323' = '#2B261C'
        '#382035' = '#312E27'
        '#39202D' = '#322E27'
        '#392031' = '#322E27'
        '#3D122A' = '#312A1E'
        '#452031' = '#3B352A'
        '#4C2C41' = '#433E35'
        '#502D42' = '#464137'
        '#503044' = '#474239'
        '#5C3047' = '#50493C'
        '#5D3449' = '#524B3F'
        '#643049' = '#564E3E'
        '#6D3953' = '#5F5747'
        '#6F3A50' = '#605849'
        '#764057' = '#675F4F'
        '#800020' = '#88652F'
        '#874461' = '#756A56'
        '#87506A' = '#786F5F'
        '#8C536E' = '#7C7363'
        '#8D294B' = '#726245'
        '#95617B' = '#877F6F'
        '#B56B8A' = '#A1957F'
        '#B77494' = '#A59A86'
        '#B94970' = '#B898F1'
        '#B95C7F' = '#9F9176'
        '#BC839B' = '#ACA393'
        '#C05A7C' = '#A49476'
        '#C55B80' = '#A17FD9'
        '#C56D8C' = '#AD9F85'
        '#C684A0' = '#B4A996'
        '#CE7497' = '#B5A78D'
        '#D45D87' = '#A787E0'
        '#D77E9E' = '#BFB196'
        '#DF7399' = '#B898F1'
        '#DFB1C1' = '#D2CBBE'
        '#E7B5C8' = '#D9D1C3'
        '#F2B4CA' = '#E1D7C5'
        '#F4C5D5' = '#E7E0D2'
        '#F5CAAA' = '#D7BBFF'
        '#F5D2DE' = '#EBE6DC'
        '#F9EEF2' = '#F6F4F1'
        '#FFD9E7' = '#F5EFE3'
        '#FFF3F6' = '#FCFAF6'
        '#FFF4F7' = '#FCFAF7'
    }
}

function Get-ThemeChoice {
    try {
        if ([IO.File]::Exists($script:themeFile)) {
            $choice = [IO.File]::ReadAllText($script:themeFile).Trim()
            if ($script:themeNames.ContainsKey($choice)) { return $choice }
            Write-PlayerLog 'WARN' 'Theme' 'Unknown saved theme; defaulting to Burgundy Rose.'
        }
    } catch {
        Write-PlayerLog 'WARN' 'Theme' 'Unable to read saved theme; defaulting to Burgundy Rose.'
    }
    return 'Burgundy'
}

function Save-ThemeChoice([string] $choice) {
    if (!$script:themeNames.ContainsKey($choice)) {
        throw "Unsupported color theme: $choice"
    }
    $null = [IO.Directory]::CreateDirectory($installFolder)
    [IO.File]::WriteAllText($script:themeFile, $choice, [Text.UTF8Encoding]::new($false))
}


function Get-LayoutChoice {
    try {
        if ([IO.File]::Exists($script:layoutFile)) {
            $value = [IO.File]::ReadAllText($script:layoutFile).Trim()
            return $value -eq 'Compact'
        }
    } catch { Write-PlayerLog 'WARN' 'Layout' 'Could not read saved layout.' }
    return $false
}

function Set-CompactLayout([bool] $compact) {
    $script:compact = $compact
    [IO.File]::WriteAllText($script:layoutFile, $(if ($compact) { 'Compact' } else { 'Expanded' }),
        [Text.UTF8Encoding]::new($false))
    $script:recordPresentation.Visibility = if ($compact) { 'Collapsed' } else { 'Visible' }
    $script:recordRow.Height = if ($compact) { 77 } else { 133 }
    $script:recordRow.ColumnDefinitions[0].Width = [System.Windows.GridLength]::new($(if ($compact) { 0 } else { 146 }))
    $script:volumeRow.Visibility = if ($compact) { 'Collapsed' } else { 'Visible' }
    $script:linksRow.Visibility = if ($compact) { 'Collapsed' } else { 'Visible' }
    $script:panel.VerticalAlignment = if ($compact) { 'Center' } else { 'Stretch' }
    $script:panel.Height = if ($compact) { 264 } else { [double]::NaN }
    $script:compactButton.ToolTip = if ($compact) { 'Switch to expanded view' } else { 'Switch to compact view' }
    $script:compactButton.Content = if ($compact) { [char]0x25A3 } else { [char]0x25A5 }
    Write-PlayerLog 'INFO' 'Layout' $(if ($compact) { 'Compact view selected' } else { 'Expanded view selected' })
}

function Request-ThemeChange([string] $choice) {
    if ($choice -eq $script:activeTheme) { return }
    try {
        Save-ThemeChoice $choice
        # Restart only this player; the original Spotify process is not touched.
        # Remember whether the WPF panel was open, so the newly styled panel
        # automatically reopens after the app-only refresh.
        $restartArgs = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Mode Restart' -f $script:scriptFilePath
        if ($script:expanded) { $restartArgs += ' -ShowOnStart' }
        $null = Start-Process -FilePath $engine -ArgumentList $restartArgs -WindowStyle Hidden -PassThru
        if ($script:themeMenu) { $script:themeMenu.Enabled = $false }
        if ($script:themeButton) { $script:themeButton.IsEnabled = $false }
        Write-PlayerLog 'INFO' 'Theme' ("Theme change requested: " + $choice)
    } catch {
        Write-PlayerLog 'ERROR' 'Theme' $_.Exception.ToString()
        [System.Windows.MessageBox]::Show(
            'Could not switch theme. The current player remains running.',
            'Spotify Corner Player'
        ) | Out-Null
    }
}

function Convert-ThemeMarkup([string] $markup, [string] $choice) {
    # For the known-working default, pass through the original XAML unchanged.
    if ($choice -eq 'Burgundy') { return $markup }
    $palette = $script:themeMaps[$choice]
    if (!$palette) { throw "Unsupported color theme: $choice" }
    # A single regex pass avoids cascading substitutions when palette hex values
    # happen to coincide with original hex values.
    return [regex]::Replace(
        $markup,
        '#[0-9A-Fa-f]{6}\b',
        [System.Text.RegularExpressions.MatchEvaluator] {
            param($match)
            $key = $match.Value.ToUpperInvariant()
            if ($palette.ContainsKey($key)) { return [string] $palette[$key] }
            return $match.Value
        }
    )
}

function Get-ExistingInstallInfo {
    # Manual installations and release ZIPs write the SAME owned location.
    # We intentionally identify ownership rather than infer it from Downloads filenames.
    if (!(Test-Path -LiteralPath $installedScript -PathType Leaf)) { return 'none' }
    $body = [IO.File]::ReadAllText($installedScript)
    if ($body -match 'v(1\.[0-9]+\.[0-9]+)') { return ('v' + $Matches[1]) }
    return 'previous owned version'
}

function Assert-OwnedInstall {
    # Migrates older manually run scripts only when their ownership is proven.
    foreach ($path in @($installFolder, $installedScript, $marker, $startupLink)) {
        if (Test-Path -LiteralPath $path) {
            $entry = Get-Item -LiteralPath $path -Force
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing to modify a symlink or junction: $path"
            }
        }
    }
    if ((Test-Path -LiteralPath $installFolder) -and
        (!(Test-Path -LiteralPath $marker -PathType Leaf) -or [IO.File]::ReadAllText($marker) -ne $signature)) {
        throw "An unrelated folder already exists at $installFolder."
    }
    if (Test-Path -LiteralPath $startupLink) {
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($startupLink)
        # v1.0.x, v1.2.4 and v1.3.0 have the same owned AppData
        # destination, but older handmade installers may vary flags/order.
        $targetOk = [string]::Equals($link.TargetPath, $engine,
            [StringComparison]::OrdinalIgnoreCase)
        $argsOk = $link.Arguments.IndexOf($installedScript, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            $link.Arguments -match '(?i)-Mode\s+Run(?:\s|$)'
        if (!$targetOk -or !$argsOk) {
            throw "Unrecognized startup shortcut at $startupLink. Refusing to remove or overwrite it."
        }
    }
}

function Stop-CornerPlayer {
    try {
        $stop = [Threading.EventWaitHandle]::OpenExisting($stopName)
    } catch [Threading.WaitHandleCannotBeOpenedException] {
        return
    }
    try {
        $null = $stop.Set()
    } finally {
        $stop.Dispose()
    }
    try {
        $instance = [Threading.Mutex]::OpenExisting($mutexName)
    } catch [Threading.WaitHandleCannotBeOpenedException] {
        return
    }
    try {
        try {
            $stopped = $instance.WaitOne(6000)
        } catch [Threading.AbandonedMutexException] {
            $stopped = $true
        }
        if (!$stopped) {
            throw 'Exit Spotify Corner Player from its tray menu, then retry.'
        }
        $instance.ReleaseMutex()
    } finally {
        $instance.Dispose()
    }
}


function Restart-CornerPlayer {
    # Called in a second process after a tray-menu theme change. The existing
    # process exits via its own stop event, releasing its singleton mutex.
    Stop-CornerPlayer
    $ready = [System.Threading.EventWaitHandle]::new(
        $false, [System.Threading.EventResetMode]::ManualReset, $readyName
    )
    try {
        $null = $ready.Reset()
        $argsToRun = $startupArgs
        if ($ShowOnStart) { $argsToRun += ' -ShowOnStart' }
        $null = Start-Process -FilePath $engine -ArgumentList $argsToRun -WindowStyle Hidden -PassThru
        if (!$ready.WaitOne(12000)) {
            throw 'Spotify Corner Player did not restart after changing theme.'
        }
    } finally {
        $ready.Dispose()
    }
}

function Install-CornerPlayer {
    Assert-OwnedInstall
    Stop-CornerPlayer
    $hadInstall = Test-Path -LiteralPath $marker -PathType Leaf
    $hadShortcut = Test-Path -LiteralPath $startupLink -PathType Leaf
    $previousScript = if (Test-Path -LiteralPath $installedScript -PathType Leaf) {
        [IO.File]::ReadAllBytes($installedScript)
    }
    $oldVersion = Get-ExistingInstallInfo
    $backupFolder = $null
    $oldShortcut = if ($hadShortcut) { [IO.File]::ReadAllBytes($startupLink) } else { $null }
    if ($null -ne $previousScript) {
        $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
        $backupFolder = Join-Path $installFolder ("Backups\" + $stamp)
        $null = New-Item -ItemType Directory -Path $backupFolder -Force
        [IO.File]::WriteAllBytes((Join-Path $backupFolder 'Spotify-Corner-Player.ps1'), $previousScript)
        if ($null -ne $oldShortcut) {
            [IO.File]::WriteAllBytes((Join-Path $backupFolder 'Spotify Corner Player.lnk'), $oldShortcut)
        }
        Write-PlayerLog 'INFO' 'Upgrade' ("Backed up existing $oldVersion before replacement.")
    }
    $null = New-Item -ItemType Directory -Force -Path $installFolder, $startupFolder
    [IO.File]::WriteAllText($marker, $signature)
    Write-PlayerLog 'INFO' 'Install' 'Installing v1.4.0 with compact mode, seek and repeat controls.'

    $ready = [System.Threading.EventWaitHandle]::new($false, [System.Threading.EventResetMode]::ManualReset, $readyName)
    try {
        if ($PSCommandPath -ne $installedScript) {
            [IO.File]::WriteAllBytes($installedScript, [IO.File]::ReadAllBytes($PSCommandPath))
        }
        $null = $ready.Reset()
        $null = Start-Process -FilePath $engine -ArgumentList $startupArgs -WindowStyle Hidden -PassThru
        if (!$ready.WaitOne(12000)) {
            throw "The player did not start. Run the downloaded script with -Mode Run to see the error."
        }
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($startupLink)
        $link.TargetPath = $engine
        $link.Arguments = $startupArgs
        $link.Description = 'Spotify Corner Player'
        $link.WorkingDirectory = $installFolder
        $link.Save()
        @(
            'Spotify Corner Player v1.4.0'
            'Running for the current Windows user. Startup shortcut installed.'
            'Five themes, compact/expanded views, seeking and repeat when supported.'
            'Hover at middle-right edge for Music; click to reveal flush player pushing tab offscreen.'
            'No full-player auto-popup. Mouse out hides the tiny tab after a moment.'
            'Ctrl+Shift+Q toggles the player if that key combination is available.'
            'The panel has an Open Spotify button even when Spotify is closed.'
            'Lyrics button opens a song-and-artist search in the default browser.'
        'Volume slider and mute control Spotify only through Windows audio sessions (when available).'
            'Use the tray icon for Show or Exit. Run the script with -Mode Uninstall to remove it.'
            "Startup shortcut: $startupLink"
            "Diagnostics: $logFile"
        ) | Set-Content -LiteralPath $reportFile -Encoding UTF8
        Write-PlayerLog 'INFO' 'Install' ("Upgrade completed from $oldVersion to v1.4.0.")
        if ($oldVersion -ne 'none') {
            Write-Output ("Previous owned version detected and replaced: $oldVersion")
            if ($backupFolder) { Write-Output "Safe rollback backup: $backupFolder" }
        }
    } catch {
        $failure = $_
        Write-PlayerLog 'ERROR' 'Install' ($failure.Exception.ToString())
        Stop-CornerPlayer
        if ($hadShortcut -and $null -ne $oldShortcut) {
            [IO.File]::WriteAllBytes($startupLink, [byte[]] $oldShortcut)
        } elseif (Test-Path -LiteralPath $startupLink -PathType Leaf) {
            Remove-Item -LiteralPath $startupLink
        }
        if ($null -ne $previousScript) {
            [IO.File]::WriteAllBytes($installedScript, [byte[]] $previousScript)
        } else {
            Remove-Item -LiteralPath $installedScript -ErrorAction SilentlyContinue
        }
        if (!$hadInstall) {
            Remove-Item -LiteralPath $reportFile -ErrorAction SilentlyContinue
            # Keep the ownership marker with failure logs for safe reinstall and diagnosis.
        }
        throw $failure
    } finally {
        $ready.Dispose()
    }
    Get-Content -LiteralPath $reportFile
    try { Start-Process -FilePath explorer.exe -ArgumentList ('"{0}"' -f $installFolder) } catch {}
}

function Uninstall-CornerPlayer {
    Assert-OwnedInstall
    Stop-CornerPlayer
    Write-PlayerLog 'INFO' 'Uninstall' 'Uninstall requested.'
    foreach ($path in @($startupLink, $installedScript, $reportFile)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Remove-Item -LiteralPath $path -Force
        }
    }
    if ($PurgeLogs) {
        if (Test-Path -LiteralPath $logFolder -PathType Container) {
            Remove-Item -LiteralPath $logFolder -Recurse -Force
        }
        if (Test-Path -LiteralPath $marker -PathType Leaf) {
            Remove-Item -LiteralPath $marker -Force
        }
        if ((Test-Path -LiteralPath $installFolder -PathType Container) -and
            !(Get-ChildItem -LiteralPath $installFolder -Force | Select-Object -First 1)) {
            Remove-Item -LiteralPath $installFolder
        }
        Write-Output 'Spotify Corner Player removed. Diagnostic logs purged.'
    } else {
        Write-Output "Spotify Corner Player removed. Diagnostic logs retained at: $logFolder"
        Write-Output 'For full removal, rerun Uninstall with -PurgeLogs.'
    }
}

function New-MediaTask($operation, [type] $resultType) {
    $method = $script:asTask.MakeGenericMethod([type[]] @($resultType))
    $method.Invoke($null, [object[]] @($operation))
}

function Animate-Double($element, $property, [double] $destination, [int] $milliseconds, [string] $easing = 'Out') {
    $animation = [System.Windows.Media.Animation.DoubleAnimation]::new()
    $animation.To = $destination
    $animation.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds($milliseconds))
    $curve = [System.Windows.Media.Animation.CubicEase]::new()
    $curve.EasingMode = if ($easing -eq 'In') { 'EaseIn' } else { 'EaseOut' }
    $animation.EasingFunction = $curve
    $element.BeginAnimation($property, $animation, [System.Windows.Media.Animation.HandoffBehavior]::SnapshotAndReplace)
}

function Animate-TextChange {
    $script:trackText.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $script:trackText.Opacity = 0.15
    $script:textShift.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $null)
    $script:textShift.Y = 11
    Animate-Double $script:trackText ([System.Windows.UIElement]::OpacityProperty) 1 280
    Animate-Double $script:textShift ([System.Windows.Media.TranslateTransform]::YProperty) 0 330
}

function Animate-PanelIn {
    # Reveal the panel right-to-left while Music is pushed off the monitor's right edge.
    # Window itself NEVER animates or changes size: prevents WPF layered-window flicker.
    $script:panelRevealClip.BeginAnimation([System.Windows.Media.RectangleGeometry]::RectProperty, $null)
    $script:panelRevealClip.Rect = [System.Windows.Rect]::new(353, 0, 1, 398)
    $script:tabShift.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $null)
    $script:tabShift.X = -72
    Animate-Rect $script:panelRevealClip ([System.Windows.Rect]::new(0,0,354,398)) 310
    Animate-Double $script:tabShift ([System.Windows.Media.TranslateTransform]::XProperty) 0 310
    # The record blooms into place while its rotation starts. No thumbnail request is made.
    $script:recordPresentation.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $script:recordPresentation.Opacity = 0.15
    $script:recordScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $null)
    $script:recordScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $null)
    $script:recordScale.ScaleX = 0.82
    $script:recordScale.ScaleY = 0.82
    Animate-Double $script:recordPresentation ([System.Windows.UIElement]::OpacityProperty) 1 400
    Animate-Double $script:recordScale ([System.Windows.Media.ScaleTransform]::ScaleXProperty) 1 420
    Animate-Double $script:recordScale ([System.Windows.Media.ScaleTransform]::ScaleYProperty) 1 420
}

function Animate-Rect($geometry, [System.Windows.Rect] $destination, [int] $milliseconds) {
    $animation = [System.Windows.Media.Animation.RectAnimation]::new()
    $animation.To = $destination
    $animation.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds($milliseconds))
    $curve = [System.Windows.Media.Animation.CubicEase]::new()
    $curve.EasingMode = 'EaseOut'
    $animation.EasingFunction = $curve
    $geometry.BeginAnimation([System.Windows.Media.RectangleGeometry]::RectProperty, $animation,
        [System.Windows.Media.Animation.HandoffBehavior]::SnapshotAndReplace)
}

function Set-DiscMotion([bool] $rotate) {
    if ($script:discMoving -eq $rotate) { return }
    $script:discMoving = $rotate
    if ($rotate) {
        $animation = [System.Windows.Media.Animation.DoubleAnimation]::new()
        $animation.From = [double] $script:disc.Angle
        $animation.To = [double] ($script:disc.Angle + 360)
        $animation.Duration = [System.Windows.Duration]::new([TimeSpan]::FromSeconds(12))
        $animation.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        [System.Windows.Media.Animation.Timeline]::SetDesiredFrameRate($animation, 30)
        $script:disc.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $animation)
    } else {
        # Capture the effective animated angle BEFORE removing the WPF clock.
        # This freezes the record at its current position without a visible jump.
        $angle = [double] $script:disc.GetValue([System.Windows.Media.RotateTransform]::AngleProperty)
        $script:disc.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $null)
        $script:disc.Angle = $angle % 360
    }
}

function Reset-MediaPanel([string] $caption) {
    Set-DiscMotion $false
    $script:song.Text = $caption
    $script:artist.Text = ''
    $script:detail.Text = ''
    $script:progress.Value = 0
    $script:progress.IsEnabled = $false
    $script:seekAvailable = $false
    $script:durationTicks = 0
    $script:seekStartTicks = 0
    $script:repeatButton.IsEnabled = $false
    $script:repeatButton.Content = 'Repeat'
    $script:progress.Visibility = 'Collapsed'
    $script:previous.IsEnabled = $false
    $script:toggle.IsEnabled = $false
    $script:next.IsEnabled = $false
    $script:playIcon.Visibility = 'Visible'
    $script:pauseIcon.Visibility = 'Collapsed'
    $script:toggle.ToolTip = 'Play'
    [System.Windows.Automation.AutomationProperties]::SetName($script:toggle, 'Play')
    $script:metadataTask = $null
    $script:trackKey = ''
}

# Deliberately use only the title/artist metadata. Spotify artwork is not requested.
function Set-MediaText($media) {
    $title = if ($media.Title) { [string] $media.Title } else { 'Spotify' }
    $artist = if ($media.Artist) { [string] $media.Artist } else { '' }
    $key = '{0}|{1}|{2}' -f $title, $artist, $media.AlbumTitle
    if ($key -ne $script:trackKey) {
        $script:trackKey = $key
        $script:song.Text = $title
        $script:artist.Text = $artist
        Animate-TextChange
    }
}

function Format-PlaybackTime([double] $seconds) {
    $interval = [TimeSpan]::FromSeconds($seconds)
    if ($seconds -ge 3600) { return $interval.ToString('h\:mm\:ss') }
    $interval.ToString('m\:ss')
}

function Get-SpotifySession {
    foreach ($candidate in $script:manager.GetSessions()) {
        if ($candidate.SourceAppUserModelId -match '^(Spotify(\.exe)?|SpotifyAB\.SpotifyMusic([^!]*)![^!]+)$') {
            return $candidate
        }
    }
}

function Update-Media {
    try {
        if (!$script:manager) {
            if (!$script:managerTask) {
                $script:managerTask = New-MediaTask ($script:managerType::RequestAsync()) $script:managerType
                return
            }
            if (!$script:managerTask.IsCompleted) { return }
            $task = $script:managerTask
            $script:managerTask = $null
            $script:manager = $task.GetAwaiter().GetResult()
        }
        $session = Get-SpotifySession

        if (!$session) {
            Set-DiscMotion $false
            if ($script:playerId -or $script:song.Text -ne 'Spotify is closed or idle') {
                $script:playerId = ''
                $script:controlTask = $null
                Reset-MediaPanel 'Spotify is closed or idle'
            }
            return
        }

        if ($script:playerId -ne $session.SourceAppUserModelId) {
            Reset-MediaPanel 'Spotify'
            $script:playerId = $session.SourceAppUserModelId
            $script:nextMetadata = [DateTime]::MinValue
        }

        $info = $session.GetPlaybackInfo()
        $playing = "$($info.PlaybackStatus)" -eq 'Playing'
        # Rotate only while Spotify reports Playing AND the drawer is open.
        # Set-DiscMotion is stateful; its animation is not restarted on every poll.
        Set-DiscMotion ([bool] ($playing -and $script:expanded -and !$script:closing))
        $controls = $info.Controls
        $script:repeatButton.IsEnabled = [bool] $controls.IsRepeatEnabled
        $script:repeatButton.Content = if ($controls.IsRepeatEnabled) {
            switch ("$($info.AutoRepeatMode)") {
                'Track' { 'Repeat one' }
                'List' { 'Repeat all' }
                default { 'Repeat off' }
            }
        } else { 'Repeat' }
        $script:previous.IsEnabled = $controls.IsPreviousEnabled
        $script:next.IsEnabled = $controls.IsNextEnabled
        $script:toggle.IsEnabled = $controls.IsPlayPauseToggleEnabled -or
            ($playing -and $controls.IsPauseEnabled) -or (!$playing -and $controls.IsPlayEnabled)
        $script:playIcon.Visibility = if ($playing) { 'Collapsed' } else { 'Visible' }
        $script:pauseIcon.Visibility = if ($playing) { 'Visible' } else { 'Collapsed' }
        $script:toggle.ToolTip = if ($playing) { 'Pause' } else { 'Play' }
        [System.Windows.Automation.AutomationProperties]::SetName($script:toggle, $script:toggle.ToolTip)
        $timeline = $session.GetTimelineProperties()
        $duration = $timeline.EndTime.TotalSeconds - $timeline.StartTime.TotalSeconds
        $script:seekAvailable = [bool] ($controls.IsPlaybackPositionEnabled -and $duration -gt 0)
        $script:progress.IsEnabled = $script:seekAvailable
        $script:durationTicks = if ($duration -gt 0) { [int64]($timeline.EndTime.Ticks - $timeline.StartTime.Ticks) } else { 0 }
        $script:seekStartTicks = [int64]$timeline.StartTime.Ticks
        if ($duration -gt 0) {
            $position = $timeline.Position.TotalSeconds - $timeline.StartTime.TotalSeconds
            if ($playing) { $position += [Math]::Max(0, ([DateTimeOffset]::UtcNow - $timeline.LastUpdatedTime).TotalSeconds) }
            $position = [Math]::Min($duration, [Math]::Max(0, $position))
            if (!$script:seeking -and !$script:progress.IsMouseCaptureWithin) {
                $script:progress.Value = 1000 * $position / $duration
            }
            $script:progress.Visibility = 'Visible'
            $script:detail.Text = '{0} / {1}' -f (Format-PlaybackTime $position), (Format-PlaybackTime $duration)
        } else {
            $script:progress.Visibility = 'Collapsed'
            $script:detail.Text = ''
        }

        if ($script:metadataTask -and $script:metadataTask.IsCompleted) {
            $task = $script:metadataTask
            $script:metadataTask = $null
            Set-MediaText ($task.GetAwaiter().GetResult())
        }
        if (!$script:metadataTask -and [DateTime]::UtcNow -ge $script:nextMetadata) {
            $script:nextMetadata = [DateTime]::UtcNow.AddSeconds(1)
            $script:metadataTask = New-MediaTask ($session.TryGetMediaPropertiesAsync()) $script:propertiesType
        }
        if ($script:controlTask -and $script:controlTask.IsCompleted) {
            $task = $script:controlTask
            $script:controlTask = $null
            if (!$task.GetAwaiter().GetResult()) {
                $script:notice.Text = 'Spotify did not accept that action.'
            }
        }
    } catch {
        # If playback state cannot be verified, leave the vinyl stopped.
        # Preserve existing song text when metadata is temporarily unavailable.
        Set-DiscMotion $false
        Write-MediaIssue 'Playback' $_.Exception.ToString()
        $script:notice.Text = 'Spotify metadata briefly unavailable; see logs if it persists.'
    }
}

function Invoke-SeekFromSlider {
    if (!$script:seekAvailable -or $script:durationTicks -le 0 -or $script:controlTask) { return }
    try {
        $session = Get-SpotifySession
        if (!$session -or $session.SourceAppUserModelId -ne $script:playerId) { return }
        $fraction = [Math]::Max(0, [Math]::Min(1, $script:progress.Value / 1000.0))
        $ticks = [int64]($script:seekStartTicks + [Math]::Round($fraction * $script:durationTicks))
        $script:controlTask = New-MediaTask ($session.TryChangePlaybackPositionAsync($ticks)) ([bool])
    } catch {
        $script:notice.Text = 'Spotify does not currently accept seeking.'
        Write-MediaIssue 'Seek' $_.Exception.ToString()
    }
}

function Set-RepeatMode {
    if (!$script:manager -or $script:controlTask -or !$script:repeatButton.IsEnabled) { return }
    try {
        $session = Get-SpotifySession
        if (!$session -or $session.SourceAppUserModelId -ne $script:playerId) { return }
        $current = "$($session.GetPlaybackInfo().AutoRepeatMode)"
        $value = switch ($current) { 'None' { 2 } 'List' { 1 } default { 0 } }
        $mode = [Windows.Media.MediaPlaybackAutoRepeatMode,Windows.Media,ContentType=WindowsRuntime]
        $script:controlTask = New-MediaTask ($session.TryChangeAutoRepeatModeAsync([Enum]::ToObject($mode, $value))) ([bool])
    } catch {
        $script:repeatButton.IsEnabled = $false
        $script:notice.Text = 'Spotify does not currently accept repeat changes.'
        Write-MediaIssue 'Repeat' $_.Exception.ToString()
    }
}

function Send-MediaControl([string] $action) {
    if (!$script:manager -or $script:controlTask) { return }
    $script:notice.Text = ''
    try {
        $session = Get-SpotifySession
        if (!$session -or $session.SourceAppUserModelId -ne $script:playerId) { return }
        $operation = switch ($action) {
            'previous' { $session.TrySkipPreviousAsync() }
            'next' { $session.TrySkipNextAsync() }
            'toggle' {
                $info = $session.GetPlaybackInfo()
                if ($info.Controls.IsPlayPauseToggleEnabled) {
                    $session.TryTogglePlayPauseAsync()
                } elseif ("$($info.PlaybackStatus)" -eq 'Playing') {
                    $session.TryPauseAsync()
                } else {
                    $session.TryPlayAsync()
                }
            }
        }
        $script:controlTask = New-MediaTask $operation ([bool])
    } catch {
        Write-PlayerLog 'ERROR' 'Control' $_.Exception.ToString()
        $script:notice.Text = 'Spotify did not accept that action.'
    }
}

function Open-Spotify {
    $script:notice.Text = ''
    try {
        Start-Process -FilePath 'spotify:'
    } catch {
        $desktopApp = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Spotify\Spotify.exe'
        try {
            if (Test-Path -LiteralPath $desktopApp -PathType Leaf) {
                Start-Process -FilePath $desktopApp
            } else {
                $spotifyApp = Get-StartApps | Where-Object {
                    $_.Name -eq 'Spotify' -and $_.AppID -like 'SpotifyAB.SpotifyMusic*!*'
                } | Select-Object -First 1
                if (!$spotifyApp) { throw 'Spotify could not be found.' }
                Start-Process -FilePath explorer.exe -ArgumentList ('"shell:AppsFolder\{0}"' -f $spotifyApp.AppID)
            }
        } catch {
            $script:notice.Text = 'Open Spotify from the Windows Start menu.'
        }
    }
}

# Open a browser search. Windows media transport metadata does not expose lyric text.
# Never send song titles to our local diagnostics, only to the user's default browser on click.
function Open-Lyrics {
    if (!$script:playerId -or !$script:song.Text -or $script:song.Text -eq 'Spotify' -or
        $script:song.Text -match 'temporarily unavailable|closed or idle') {
        $script:notice.Text = 'Play a song in Spotify first to look up its lyrics.'
        return
    }
    try {
        $query = [Uri]::EscapeDataString(($script:song.Text + ' ' + $script:artist.Text + ' lyrics').Trim())
        Start-Process -FilePath ('https://www.google.com/search?q=' + $query) -ErrorAction Stop
        Write-PlayerLog 'INFO' 'Lyrics' 'Opened lyrics search in default browser.'
    } catch {
        Write-PlayerLog 'ERROR' 'Lyrics' $_.Exception.ToString()
        $script:notice.Text = 'Could not open browser for lyrics. See diagnostics.'
    }
}

function New-DispatcherTimer([int] $milliseconds) {
    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds($milliseconds)
    $timer
}

function Update-CornerPosition {
    # Fixed 354-DIP panel, 72-DIP ribbon and 398-DIP height. Panel flush against right edge.
    # All WPF coordinates are device-independent; pointer detection uses WinForms physical px.
    $area = [System.Windows.SystemParameters]::WorkArea
    $left = [Math]::Max($area.Left, $area.Right - 354)
    $top = $area.Top + [Math]::Max(0, ($area.Height - 398) / 2)
    if ([Math]::Abs($script:flyout.Left - $left) -gt 0.5) { $script:flyout.Left = $left }
    if ([Math]::Abs($script:flyout.Top - $top) -gt 0.5) { $script:flyout.Top = $top }
}

function Test-MiddleRightEdge($area, $pointer) {
    $centre = $area.Top + ($area.Height / 2)
    $pointer.X -ge ($area.Right - 18) -and $pointer.X -lt $area.Right -and
        [Math]::Abs($pointer.Y - $centre) -le 80
}

function Show-EdgePreview {
    if ($script:expanded -or $script:closing -or $script:flyout.IsVisible) { return }
    $script:previewHideTimer.Stop()
    $script:panel.Visibility = 'Collapsed'
    $script:panel.IsHitTestVisible = $false
    $script:tabShift.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $null)
    $script:tabShift.X = 0
    $script:attachedButton.ToolTip = 'Open player'
    [System.Windows.Automation.AutomationProperties]::SetName($script:attachedButton, 'Open player')
    Update-CornerPosition
    $script:flyout.Show()
    Animate-Double $script:tabShift ([System.Windows.Media.TranslateTransform]::XProperty) -72 195
    Write-PlayerLog 'INFO' 'UI' 'Music tab slid in from screen edge.'
}

function Hide-EdgePreview {
    $script:previewHideTimer.Stop()
    if (!$script:expanded -and !$script:closing -and $script:flyout.IsVisible) {
        $script:flyout.Hide()
    }
}

function Update-EdgePreview {
    # Physical coordinates used only for edge detection, never for WPF window placement.
    if ($script:expanded -or $script:closing) { return }
    $area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $pointer = [System.Windows.Forms.Cursor]::Position
    $nearEdge = Test-MiddleRightEdge $area $pointer
    if ($nearEdge -or ($script:flyout.IsVisible -and $script:attachedButton.IsMouseOver)) {
        $script:previewHideTimer.Stop()
        if ($nearEdge) { Show-EdgePreview }
    } elseif ($script:flyout.IsVisible -and !$script:previewHideTimer.IsEnabled) {
        $script:previewHideTimer.Start()
    }
}

function Show-Flyout {
    if ($script:expanded -or $script:closing) { return }
    $script:exitTimer.Stop()
    $script:closing = $false
    $script:expanded = $true
    $script:previewHideTimer.Stop()
    $script:panel.Visibility = 'Visible'
    $script:panel.IsHitTestVisible = $true
    $script:attachedButton.ToolTip = 'Hide player'
    [System.Windows.Automation.AutomationProperties]::SetName($script:attachedButton, 'Hide player')
    if (!$script:flyout.IsVisible) { Update-CornerPosition; $script:flyout.Show() }
    Animate-PanelIn
    # Opening does not start the record. Update-Media determines actual playback.
    Set-DiscMotion $false
    Write-PlayerLog 'INFO' 'UI' 'Expanded player; vinyl follows Spotify playback state.'
    $script:mediaTimer.Start()
    $script:volumeRefreshTimer.Start()
    Update-SpotifyVolumeUI
    if ($script:managerType) { Update-Media }
}

function Hide-Flyout {
    if (!$script:expanded -or $script:closing) { return }
    $script:closing = $true
    Set-DiscMotion $false
    $script:panel.IsHitTestVisible = $false
    Animate-Rect $script:panelRevealClip ([System.Windows.Rect]::new(353,0,1,398)) 270
    Animate-Double $script:tabShift ([System.Windows.Media.TranslateTransform]::XProperty) -72 270 'In'
    $script:exitTimer.Start()
}

function Register-CornerShortcut {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace SpotifyCornerPlayer
{
    public static class HotKey
    {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool RegisterHotKey(IntPtr window, int id, uint modifiers, uint key);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool UnregisterHotKey(IntPtr window, int id);
    }
}
'@
    $helper = [System.Windows.Interop.WindowInteropHelper]::new($script:flyout)
    $handle = $helper.EnsureHandle()
    $source = [System.Windows.Interop.HwndSource]::FromHwnd($handle)
    if (!$source) { return $false }

    $hook = [System.Windows.Interop.HwndSourceHook] {
        param([IntPtr] $window, [int] $message, [IntPtr] $keyId, [IntPtr] $data, [ref] $handled)
        if ($message -eq 0x0312 -and $keyId.ToInt32() -eq 1) {
            if ($script:expanded -and !$script:closing) { Hide-Flyout } elseif (!$script:closing) { Show-Flyout }
            $handled.Value = $true
        }
        [IntPtr]::Zero
    }
    $source.AddHook($hook)
    # Ctrl + Shift, no auto-repeat, virtual key Q.
    if (![SpotifyCornerPlayer.HotKey]::RegisterHotKey($handle, 1, 0x4006, 0x51)) {
        $source.RemoveHook($hook)
        return $false
    }
    $script:shortcutHandle = $handle
    return $true
}

$script:volumeCSharp = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace SpotifyCornerPlayer {
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    internal class MMDeviceEnumerator { }

    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceEnumerator {
        [PreserveSig] int EnumAudioEndpoints(int flow, uint states, out IntPtr devices);
        [PreserveSig] int GetDefaultAudioEndpoint(int flow, int role, out IMMDevice device);
        [PreserveSig] int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, out IMMDevice device);
        [PreserveSig] int RegisterEndpointNotificationCallback(IntPtr client);
        [PreserveSig] int UnregisterEndpointNotificationCallback(IntPtr client);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDevice {
        [PreserveSig] int Activate(ref Guid iid, uint clsctx, IntPtr activation, [MarshalAs(UnmanagedType.IUnknown)] out object result);
        [PreserveSig] int OpenPropertyStore(int access, out IntPtr properties);
        [PreserveSig] int GetId(out IntPtr id);
        [PreserveSig] int GetState(out int state);
    }

    [ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioSessionManager2 {
        [PreserveSig] int GetAudioSessionControl(IntPtr guid, uint flags, out IntPtr control);
        [PreserveSig] int GetSimpleAudioVolume(IntPtr guid, uint flags, out IntPtr volume);
        [PreserveSig] int GetSessionEnumerator(out IAudioSessionEnumerator sessions);
        [PreserveSig] int RegisterSessionNotification(IntPtr notification);
        [PreserveSig] int UnregisterSessionNotification(IntPtr notification);
        [PreserveSig] int RegisterDuckNotification(IntPtr session, IntPtr notification);
        [PreserveSig] int UnregisterDuckNotification(IntPtr notification);
    }

    [ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioSessionEnumerator {
        [PreserveSig] int GetCount(out int count);
        [PreserveSig] int GetSession(int index, out IAudioSessionControl session);
    }

    [ComImport, Guid("F4B1A599-7266-4319-A8CA-E70ACB11E8CD"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioSessionControl {
        [PreserveSig] int GetState(out int state);
        [PreserveSig] int GetDisplayName(out IntPtr displayName);
        [PreserveSig] int SetDisplayName(IntPtr name, IntPtr context);
        [PreserveSig] int GetIconPath(out IntPtr iconPath);
        [PreserveSig] int SetIconPath(IntPtr iconPath, IntPtr context);
        [PreserveSig] int GetGroupingParam(out Guid guid);
        [PreserveSig] int SetGroupingParam(ref Guid guid, IntPtr context);
        [PreserveSig] int RegisterAudioSessionNotification(IntPtr notification);
        [PreserveSig] int UnregisterAudioSessionNotification(IntPtr notification);
    }

    // Must list inherited IAudioSessionControl slots before IAudioSessionControl2 slots.
    [ComImport, Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioSessionControl2 {
        [PreserveSig] int GetState(out int state);
        [PreserveSig] int GetDisplayName(out IntPtr displayName);
        [PreserveSig] int SetDisplayName(IntPtr name, IntPtr context);
        [PreserveSig] int GetIconPath(out IntPtr iconPath);
        [PreserveSig] int SetIconPath(IntPtr iconPath, IntPtr context);
        [PreserveSig] int GetGroupingParam(out Guid guid);
        [PreserveSig] int SetGroupingParam(ref Guid guid, IntPtr context);
        [PreserveSig] int RegisterAudioSessionNotification(IntPtr notification);
        [PreserveSig] int UnregisterAudioSessionNotification(IntPtr notification);
        [PreserveSig] int GetSessionIdentifier(out IntPtr id);
        [PreserveSig] int GetSessionInstanceIdentifier(out IntPtr id);
        [PreserveSig] int GetProcessId(out uint pid);
        [PreserveSig] int IsSystemSoundsSession();
        [PreserveSig] int SetDuckingPreference([MarshalAs(UnmanagedType.Bool)] bool optOut);
    }

    [ComImport, Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface ISimpleAudioVolume {
        [PreserveSig] int SetMasterVolume(float level, IntPtr eventContext);
        [PreserveSig] int GetMasterVolume(out float level);
        [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, IntPtr eventContext);
        [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
    }

    public static class SpotifyVolume {
        private static void Release(object com) {
            if (com != null && Marshal.IsComObject(com)) { Marshal.ReleaseComObject(com); }
        }

        // Returns [Spotify-session volume 0..100, muted 0/1] or null if unavailable.
        // Uses the default Windows multimedia output, NEVER the global endpoint/master volume.
        private static float[] Apply(float? requestedLevel, bool? requestedMute) {
            IMMDeviceEnumerator devices = null;
            IMMDevice device = null;
            IAudioSessionManager2 manager = null;
            IAudioSessionEnumerator sessions = null;
            try {
                devices = (IMMDeviceEnumerator)new MMDeviceEnumerator();
                Marshal.ThrowExceptionForHR(devices.GetDefaultAudioEndpoint(0, 1, out device));
                Guid iid = typeof(IAudioSessionManager2).GUID;
                object obj;
                Marshal.ThrowExceptionForHR(device.Activate(ref iid, 23, IntPtr.Zero, out obj));
                manager = (IAudioSessionManager2)obj;
                Marshal.ThrowExceptionForHR(manager.GetSessionEnumerator(out sessions));
                int count;
                Marshal.ThrowExceptionForHR(sessions.GetCount(out count));
                float[] observed = null;
                bool observedActive = false;
                for (int i = 0; i < count; i++) {
                    IAudioSessionControl session = null;
                    try {
                        if (sessions.GetSession(i, out session) < 0 || session == null) continue;
                        IAudioSessionControl2 extended = session as IAudioSessionControl2;
                        if (extended == null) continue;
                        uint pid;
                        if (extended.GetProcessId(out pid) < 0 || pid == 0) continue;
                        bool spotify = false;
                        try {
                            using (Process proc = Process.GetProcessById(checked((int)pid))) {
                                spotify = String.Equals(proc.ProcessName, "Spotify", StringComparison.OrdinalIgnoreCase);
                            }
                        } catch (ArgumentException) { continue; }
                          catch (System.ComponentModel.Win32Exception) { continue; }
                        if (!spotify) continue;
                        ISimpleAudioVolume volume = session as ISimpleAudioVolume;
                        if (volume == null) continue;
                        if (requestedLevel.HasValue) {
                            Marshal.ThrowExceptionForHR(volume.SetMasterVolume(requestedLevel.Value, IntPtr.Zero));
                        }
                        if (requestedMute.HasValue) {
                            Marshal.ThrowExceptionForHR(volume.SetMute(requestedMute.Value, IntPtr.Zero));
                        }
                        float gain; bool muted;
                        if (volume.GetMasterVolume(out gain) < 0 || volume.GetMute(out muted) < 0) continue;
                        int state;
                        bool active = session.GetState(out state) >= 0 && state == 0;
                        if (observed == null || (active && !observedActive)) {
                            observed = new float[]{ Math.Max(0f, Math.Min(100f, gain * 100f)), muted ? 1 : 0 };
                            observedActive = active;
                        }
                    } finally {
                        Release(session);
                    }
                }
                return observed;
            } finally {
                Release(sessions);
                Release(manager);
                Release(device);
                Release(devices);
            }
        }

        public static float[] Get() { return Apply(null, null); }
        public static bool SetLevel(int percent) { return Apply((float)Math.Max(0, Math.Min(100, percent)) / 100f, null) != null; }
        public static bool SetMuted(bool mute) { return Apply(null, mute) != null; }
    }
}
'@


function Initialize-SpotifyVolume {
    $script:volumeReady = $false
    $script:volumeSyncing = $false
    $script:volumePending = $false
    $script:volumeMuted = $false
    $script:volumeLastGood = [DateTime]::MinValue
    try {
        Add-Type -TypeDefinition $script:volumeCSharp -ErrorAction Stop
        $script:volumeReady = $true
        Write-PlayerLog 'INFO' 'Volume' 'Spotify-only Core Audio session controls initialized.'
    } catch {
        Write-PlayerLog 'ERROR' 'Volume' ('Failed to load Spotify audio-session API: ' + $_.Exception.ToString())
        $script:volumeMute.IsEnabled = $false
        $script:volumeSlider.IsEnabled = $false
    }
    Update-SpotifyVolumeUI
}

function Update-SpotifyVolumeUI {
    if (!$script:volumeReady -or $script:volumePending -or $script:volumeSlider.IsMouseCaptureWithin) { return }
    try {
        $snapshot = [SpotifyCornerPlayer.SpotifyVolume]::Get()
        if (!$snapshot) {
            $script:volumeMute.IsEnabled = $false
            $script:volumeSlider.IsEnabled = $false
            $script:volumePercent.Text = '--'
            $script:volumeMute.Content = [char]0x266A
            return
        }
        $script:volumeSyncing = $true
        try {
            $script:volumeSlider.IsEnabled = $true
            $script:volumeMute.IsEnabled = $true
            $script:volumeSlider.Value = [Math]::Round($snapshot[0])
            $script:volumeMuted = $snapshot[1] -ge 0.5
            $script:volumeMute.Content = if ($script:volumeMuted) { [char]0x266A } else { [char]0x266B }
            $script:volumeMute.ToolTip = if ($script:volumeMuted) { 'Unmute Spotify' } else { 'Mute Spotify' }
            $script:volumePercent.Text = ('{0}%' -f [Math]::Round($snapshot[0]))
        } finally {
            $script:volumeSyncing = $false
        }
    } catch {
        Write-MediaIssue 'Volume' ('Unable to inspect Spotify volume: ' + $_.Exception.Message)
        $script:volumeMute.IsEnabled = $false
        $script:volumeSlider.IsEnabled = $false
        $script:volumePercent.Text = '--'
    }
}

function Set-SpotifyVolumeFromSlider {
    $script:volumeApplyTimer.Stop()
    if (!$script:volumeReady -or !$script:volumeSlider.IsEnabled) { return }
    try {
        $level = [int][Math]::Round($script:volumeSlider.Value)
        $ok = [SpotifyCornerPlayer.SpotifyVolume]::SetLevel($level)
        if (!$ok) { Write-MediaIssue 'Volume' 'Spotify audio session was unavailable while applying volume.' }
    } catch {
        Write-MediaIssue 'Volume' ('Unable to set Spotify volume: ' + $_.Exception.Message)
    } finally {
        $script:volumePending = $false
        Update-SpotifyVolumeUI
    }
}

function Toggle-SpotifyMute {
    if (!$script:volumeReady -or !$script:volumeMute.IsEnabled) { return }
    try {
        if (![SpotifyCornerPlayer.SpotifyVolume]::SetMuted(!$script:volumeMuted)) {
            Write-MediaIssue 'Volume' 'Spotify audio session unavailable while toggling mute.'
        }
    } catch {
        Write-MediaIssue 'Volume' ('Unable to toggle Spotify mute: ' + $_.Exception.Message)
    } finally { Update-SpotifyVolumeUI }
}

function Start-CornerPlayer {
    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) {
        throw 'Start the player with powershell.exe -STA.'
    }
    $instance = [System.Threading.Mutex]::new($false, $mutexName)
    $script:stopSignal = $null
    $ready = $null
    $tray = $null
    $ownsInstance = $false
    $script:shortcutHandle = [IntPtr]::Zero
    try {
        try {
            $ownsInstance = $instance.WaitOne(0)
        } catch [Threading.AbandonedMutexException] {
            $ownsInstance = $true
        }
        if (!$ownsInstance) { return }
        Write-PlayerLog 'INFO' 'Runtime' 'Spotify Corner Player v1.4.0 launched.'
        $script:stopSignal = [System.Threading.EventWaitHandle]::new($false, [System.Threading.EventResetMode]::ManualReset, $stopName)
        $null = $script:stopSignal.Reset()
        $ready = [System.Threading.EventWaitHandle]::new($false, [System.Threading.EventResetMode]::ManualReset, $readyName)

        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing
        $script:managerType = $null
        try {
            Add-Type -AssemblyName System.Runtime.WindowsRuntime
            $script:propertiesType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime]
            $script:asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
                $_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition -and
                $_.GetGenericArguments().Length -eq 1 -and $_.GetParameters().Length -eq 1 -and
                $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
            } | Select-Object -First 1
            if ($script:asTask) {
                $script:managerType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
            }
        } catch {
            Write-PlayerLog 'ERROR' 'WinRT' $_.Exception.ToString()
        }
        if (!$script:managerType) {
            Write-PlayerLog 'WARN' 'WinRT' 'Windows media transport API initialization did not succeed.'
        }

        $script:app = [System.Windows.Application]::new()
        $script:app.Add_DispatcherUnhandledException({ param($sender, $args)
            Write-PlayerLog 'ERROR' 'Dispatcher' $args.Exception.ToString()
            # Do not swallow otherwise fatal UI exceptions.
        })
        $script:app.ShutdownMode = 'OnExplicitShutdown'

        $script:activeTheme = Get-ThemeChoice
        $layoutMarkup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Spotify Corner Player" Width="426" Height="398"
        WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
        Background="Transparent" Topmost="True" ShowActivated="False" ShowInTaskbar="False"
        FontFamily="Segoe UI">
  <Window.Resources>
    <SolidColorBrush x:Key="Burgundy" Color="#800020" />
    <Style TargetType="{x:Type Button}">
      <Setter Property="Background" Value="#452031" />
      <Setter Property="Foreground" Value="#FFF3F6" />
      <Setter Property="BorderBrush" Value="#6F3A50" />
      <Setter Property="BorderThickness" Value="1" />
      <Setter Property="FontWeight" Value="SemiBold" />
      <Setter Property="FontSize" Value="12" />
      <Setter Property="Padding" Value="12,9" />
      <Setter Property="Margin" Value="3" />
      <Setter Property="Cursor" Value="Hand" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type Button}">
            <Border x:Name="shape" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="11">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"
                                RecognizesAccessKey="True" Margin="{TemplateBinding Padding}" />
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="shape" Property="Border.Background" Value="#643049" />
                <Setter TargetName="shape" Property="Border.BorderBrush" Value="#B95C7F" />
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="shape" Property="Border.Background" Value="#8D294B" />
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.35" />
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Grid ClipToBounds="False">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="354" />
      <ColumnDefinition Width="72" />
    </Grid.ColumnDefinitions>
  <Grid x:Name="panelHost" Grid.Column="0" ClipToBounds="True">
    <Grid.Clip><RectangleGeometry x:Name="panelRevealClip" Rect="353,0,1,398" /></Grid.Clip>
  <Border x:Name="panel" Visibility="Collapsed" CornerRadius="21" BorderBrush="#874461" BorderThickness="1.2" Padding="17,15,17,16"
          RenderTransformOrigin="0.95,0.03">
    <Border.Background>
      <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
        <GradientStop Color="#341323" Offset="0" />
        <GradientStop Color="#1B0C15" Offset="0.56" />
        <GradientStop Color="#290E1C" Offset="1" />
      </LinearGradientBrush>
    </Border.Background>

    <StackPanel>
      <DockPanel LastChildFill="True" Margin="2,0,0,12">
        <Button x:Name="close" DockPanel.Dock="Right" Content="&#215;" AutomationProperties.Name="Hide player"
                Width="34" Height="32" Padding="0" Background="#39202D" />
        <Button x:Name="repeatButton" DockPanel.Dock="Right" Content="Repeat" AutomationProperties.Name="Repeat mode"
                ToolTip="Repeat (when supported)" IsEnabled="False" Width="65" Height="32"
                Padding="0" Background="#39202D" Margin="2,3,2,3" FontSize="10" />
        <Button x:Name="compactButton" DockPanel.Dock="Right" Content="&#9635;" AutomationProperties.Name="Compact / expanded view"
                ToolTip="Compact / expanded view" Width="34" Height="32" Padding="0"
                Background="#39202D" Margin="2,3,2,3" FontSize="17" />
        <Button x:Name="themeButton" DockPanel.Dock="Right" Content="&#9680;" AutomationProperties.Name="Choose color theme"
                ToolTip="Choose color theme" Width="34" Height="32" Padding="0"
                Background="#39202D" Margin="3,3,5,3" FontSize="17" />
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Ellipse Width="8" Height="8" Fill="#DF7399" Margin="0,0,9,0" />
          <StackPanel>
            <TextBlock Text="SPOTIFY" Foreground="#F9EEF2" FontWeight="Bold" FontSize="12" />
            <TextBlock Text="NOW PLAYING" Foreground="#C684A0" FontSize="10" Margin="0,2,0,0" />
          </StackPanel>
        </StackPanel>
      </DockPanel>
      <Grid x:Name="recordRow" Margin="0,0,0,15" Height="133">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="146" />
          <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>
        <!-- Single stylized record; independent of Spotify's unreliable thumbnail stream. -->
        <Grid x:Name="recordPresentation" Width="142" Height="132" HorizontalAlignment="Left"
              VerticalAlignment="Center" RenderTransformOrigin="0.5,0.5">
          <Grid.RenderTransform><ScaleTransform x:Name="recordScale" ScaleX="1" ScaleY="1" /></Grid.RenderTransform>
          <Ellipse Width="128" Height="128" Fill="#0E0910" Stroke="#6D3953" StrokeThickness="1.5" />
          <Grid x:Name="record" Width="126" Height="126" HorizontalAlignment="Center" VerticalAlignment="Center"
                RenderTransformOrigin="0.5,0.5">
            <Grid.RenderTransform><RotateTransform x:Name="disc" /></Grid.RenderTransform>
            <Ellipse Stroke="#B56B8A" StrokeThickness="1.1">
              <Ellipse.Fill>
                <RadialGradientBrush Center="0.37,0.28" GradientOrigin="0.3,0.2" RadiusX="0.84" RadiusY="0.84">
                  <GradientStop Color="#5C3047" Offset="0" />
                  <GradientStop Color="#24131E" Offset="0.28" />
                  <GradientStop Color="#100A12" Offset="0.85" />
                  <GradientStop Color="#382035" Offset="1" />
                </RadialGradientBrush>
              </Ellipse.Fill>
            </Ellipse>
            <Ellipse Margin="5" Stroke="#8C536E" StrokeThickness="0.8" Opacity="0.65" />
            <Ellipse Margin="9" Stroke="#502D42" StrokeThickness="0.7" />
            <Ellipse Margin="13" Stroke="#95617B" StrokeThickness="0.55" Opacity="0.7" />
            <Ellipse Margin="17" Stroke="#4C2C41" StrokeThickness="0.8" />
            <Ellipse Margin="21" Stroke="#87506A" StrokeThickness="0.6" Opacity="0.75" />
            <Ellipse Margin="26" Stroke="#5D3449" StrokeThickness="0.6" />
            <Ellipse Margin="31" Stroke="#B77494" StrokeThickness="0.55" Opacity="0.6" />
            <Ellipse Width="49" Height="49" Stroke="#CE7497" StrokeThickness="1.3">
              <Ellipse.Fill>
                <RadialGradientBrush Center="0.32,0.25" RadiusX="0.85" RadiusY="0.85">
                  <GradientStop Color="#B94970" Offset="0" />
                  <GradientStop Color="#800020" Offset="0.58" />
                  <GradientStop Color="#3D122A" Offset="1" />
                </RadialGradientBrush>
              </Ellipse.Fill>
            </Ellipse>
            <Ellipse Width="37" Height="37" Stroke="#D77E9E" StrokeThickness="0.65" Opacity="0.75" />
            <TextBlock Text="&#9835;" FontFamily="Segoe UI Symbol" FontSize="17" Foreground="#F5D2DE"
                       HorizontalAlignment="Center" VerticalAlignment="Center" Margin="0,0,0,2" />
            <Ellipse Width="5" Height="5" Fill="#170C15" Stroke="#F4C5D5" StrokeThickness="0.65" />
          </Grid>
        </Grid>
        <StackPanel x:Name="trackText" Grid.Column="1" VerticalAlignment="Center" Margin="4,0,0,0" Opacity="1">
          <StackPanel.RenderTransform><TranslateTransform x:Name="textShift" /></StackPanel.RenderTransform>
          <TextBlock x:Name="song" Text="Spotify" TextWrapping="Wrap" MaxHeight="67"
                     TextTrimming="CharacterEllipsis" Foreground="#FFF4F7" FontSize="17" FontWeight="Bold" />
          <TextBlock x:Name="artist" TextWrapping="Wrap" MaxHeight="40" Foreground="#DFB1C1" FontSize="12" Margin="0,6,0,0" />
          <TextBlock x:Name="detail" Foreground="#BC839B" FontSize="11" Margin="0,10,0,0" />
        </StackPanel>
      </Grid>
      <Border CornerRadius="7" Background="#503044" Height="14" Margin="3,0,3,8">
        <Slider x:Name="progress" Height="14" Minimum="0" Maximum="1000" Value="0"
                IsMoveToPointEnabled="True" IsEnabled="False" Foreground="#D45D87" Background="#503044"
                ToolTip="Seek (when supported)" AutomationProperties.Name="Playback position" />
      </Border>
      <DockPanel x:Name="volumeRow" Height="30" Margin="3,0,3,8" LastChildFill="True" VerticalAlignment="Center">
        <Button x:Name="volumeMute" DockPanel.Dock="Left" Width="32" Height="26" Padding="0"
                Content="&#9835;" ToolTip="Mute Spotify" AutomationProperties.Name="Mute Spotify"
                Background="#392031" BorderBrush="#764057" />
        <TextBlock DockPanel.Dock="Left" Text="VOL" Foreground="#C684A0" FontSize="10"
                   VerticalAlignment="Center" Margin="8,0,6,0" />
        <TextBlock x:Name="volumePercent" DockPanel.Dock="Right" Text="--" Width="37"
                   TextAlignment="Right" Foreground="#E7B5C8" FontSize="11"
                   VerticalAlignment="Center" />
        <Slider x:Name="volumeSlider" Minimum="0" Maximum="100" Value="50"
                Height="24" Margin="2,0,8,0" VerticalAlignment="Center"
                IsMoveToPointEnabled="True" IsEnabled="False"
                AutomationProperties.Name="Spotify application volume">
          <Slider.Template>
            <ControlTemplate TargetType="{x:Type Slider}">
              <Grid Background="Transparent" Height="24">
                <Track x:Name="PART_Track" VerticalAlignment="Center" Height="18">
                  <Track.DecreaseRepeatButton>
                    <RepeatButton Command="Slider.DecreaseLarge" Focusable="False">
                      <RepeatButton.Template>
                        <ControlTemplate TargetType="{x:Type RepeatButton}">
                          <Border Background="#C55B80" Height="4" CornerRadius="2" />
                        </ControlTemplate>
                      </RepeatButton.Template>
                    </RepeatButton>
                  </Track.DecreaseRepeatButton>
                  <Track.Thumb>
                    <Thumb Width="12" Height="12" Background="#FFD9E7">
                      <Thumb.Template>
                        <ControlTemplate TargetType="{x:Type Thumb}">
                          <Ellipse Fill="#FFD9E7" Stroke="#800020" StrokeThickness="2" />
                        </ControlTemplate>
                      </Thumb.Template>
                    </Thumb>
                  </Track.Thumb>
                  <Track.IncreaseRepeatButton>
                    <RepeatButton Command="Slider.IncreaseLarge" Focusable="False">
                      <RepeatButton.Template>
                        <ControlTemplate TargetType="{x:Type RepeatButton}">
                          <Border Background="#503044" Height="4" CornerRadius="2" />
                        </ControlTemplate>
                      </RepeatButton.Template>
                    </RepeatButton>
                  </Track.IncreaseRepeatButton>
                </Track>
              </Grid>
            </ControlTemplate>
          </Slider.Template>
        </Slider>
      </DockPanel>
      <UniformGrid Columns="3" Margin="0,0,0,8">
        <Button x:Name="previous" ToolTip="Previous track" AutomationProperties.Name="Previous track" Padding="8,9">
          <Path Width="23" Height="20" Stretch="Uniform" Fill="#FFF3F6"
                Data="M 3,2 L 6,2 L 6,18 L 3,18 Z M 19,2 L 7,10 L 19,18 Z" />
        </Button>
        <Button x:Name="toggle" ToolTip="Play" AutomationProperties.Name="Play"
                Padding="8,9" Background="#800020" BorderBrush="#C05A7C">
          <Grid Width="23" Height="20">
            <Path x:Name="playIcon" Stretch="Uniform" Fill="#FFF3F6"
                  Data="M 5,2 L 19,10 L 5,18 Z" />
            <Path x:Name="pauseIcon" Visibility="Collapsed" Stretch="Uniform" Fill="#FFF3F6"
                  Data="M 3,2 L 9,2 L 9,18 L 3,18 Z M 14,2 L 20,2 L 20,18 L 14,18 Z" />
          </Grid>
        </Button>
        <Button x:Name="next" ToolTip="Next track" AutomationProperties.Name="Next track" Padding="8,9">
          <Path Width="23" Height="20" Stretch="Uniform" Fill="#FFF3F6"
                Data="M 3,2 L 15,10 L 3,18 Z M 17,2 L 20,2 L 20,18 L 17,18 Z" />
        </Button>
      </UniformGrid>
      <UniformGrid x:Name="linksRow" Columns="2" Margin="0,0,0,2">
        <Button x:Name="openSpotify" Content="Open Spotify" Background="#392031" />
        <Button x:Name="openLyrics" Content="Lyrics &#9835;" Background="#392031"
                AutomationProperties.Name="Search lyrics for the current song" ToolTip="Open current song lyrics in a browser" />
      </UniformGrid>
      <TextBlock x:Name="notice" Foreground="#F5CAAA" FontSize="11" TextWrapping="Wrap" Margin="4,7,4,0" />
    </StackPanel>
  </Border>
  </Grid>
  <!-- The Music tab animates OUTSIDE the screen while panel becomes flush with its edge. -->
  <Border x:Name="attachedTab" Grid.Column="1" Panel.ZIndex="4" HorizontalAlignment="Right" VerticalAlignment="Center"
          Width="72" Height="34" CornerRadius="10,0,0,10" Background="#800020"
          BorderBrush="#C56D8C" BorderThickness="1,1,0,1">
    <Border.RenderTransform><TranslateTransform x:Name="tabShift" X="-72" /></Border.RenderTransform>
    <Button x:Name="attachedButton" AutomationProperties.Name="Open player" ToolTip="Open player"
            Background="Transparent" BorderThickness="0" Padding="1" Foreground="#FFF3F6">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
        <TextBlock Text="&#9835;" Foreground="#F2B4CA" FontSize="14" Margin="0,0,4,0" />
        <TextBlock Text="Music" Foreground="#FFF3F6" FontSize="11" FontWeight="SemiBold" />
      </StackPanel>
    </Button>
  </Border>
  </Grid>
</Window>
'@
        [xml] $layout = Convert-ThemeMarkup $layoutMarkup $script:activeTheme
        $reader = [System.Xml.XmlNodeReader]::new($layout)
        try { $script:flyout = [System.Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Dispose() }
        $script:disc = $script:flyout.FindName('disc')
        $script:recordPresentation = $script:flyout.FindName('recordPresentation')
        $script:recordScale = $script:flyout.FindName('recordScale')
        $script:playIcon = $script:flyout.FindName('playIcon')
        $script:pauseIcon = $script:flyout.FindName('pauseIcon')
        $script:trackText = $script:flyout.FindName('trackText')
        $script:textShift = $script:flyout.FindName('textShift')
        $script:panel = $script:flyout.FindName('panel')
        $script:panelRevealClip = $script:flyout.FindName('panelRevealClip')
        $script:tabShift = $script:flyout.FindName('tabShift')
        $script:song = $script:flyout.FindName('song')
        $script:artist = $script:flyout.FindName('artist')
        $script:detail = $script:flyout.FindName('detail')
        $script:progress = $script:flyout.FindName('progress')
        $script:recordRow = $script:flyout.FindName('recordRow')
        $script:volumeRow = $script:flyout.FindName('volumeRow')
        $script:linksRow = $script:flyout.FindName('linksRow')
        $script:compactButton = $script:flyout.FindName('compactButton')
        $script:repeatButton = $script:flyout.FindName('repeatButton')
        $script:seeking = $false
        $script:previous = $script:flyout.FindName('previous')
        $script:toggle = $script:flyout.FindName('toggle')
        $script:next = $script:flyout.FindName('next')
        $script:notice = $script:flyout.FindName('notice')
        $script:volumeMute = $script:flyout.FindName('volumeMute')
        $script:volumeSlider = $script:flyout.FindName('volumeSlider')
        $script:volumePercent = $script:flyout.FindName('volumePercent')
        $script:attachedButton = $script:flyout.FindName('attachedButton')
        $script:themeButton = $script:flyout.FindName('themeButton')
        Set-CompactLayout (Get-LayoutChoice)
        $script:discMoving = $false
        $script:closing = $false
        $script:expanded = $false
        $script:manager = $null
        $script:managerTask = $null
        $script:controlTask = $null
        $script:playerId = ''
        $script:nextMetadata = [DateTime]::MinValue
        Reset-MediaPanel 'Spotify is closed or idle'
        if (!$script:managerType) { $script:notice.Text = 'Windows media controls are unavailable.' }

        $script:exitTimer = New-DispatcherTimer 305
        $script:exitTimer.Add_Tick({
            $script:exitTimer.Stop()
            if ($script:closing) {
                $script:panelRevealClip.BeginAnimation([System.Windows.Media.RectangleGeometry]::RectProperty, $null)
                $script:panelRevealClip.Rect = [System.Windows.Rect]::new(353,0,1,398)
                $script:tabShift.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $null)
                $script:tabShift.X = -72
                $script:attachedButton.ToolTip = 'Open player'
                [System.Windows.Automation.AutomationProperties]::SetName($script:attachedButton, 'Open player')
                $script:panel.Visibility = 'Collapsed' 
                $script:mediaTimer.Stop()
                $script:volumeRefreshTimer.Stop()
                Set-DiscMotion $false
                $script:closing = $false
                $script:expanded = $false
                # The ribbon remains at its original screen coordinate, centered.
                # Do not hide and re-show the top-level window mid-transition.
                if (!$script:flyout.IsVisible) { Show-EdgePreview }
                Update-EdgePreview
            }
        })
        $script:volumeApplyTimer = New-DispatcherTimer 160
        $script:volumeApplyTimer.Add_Tick({ Set-SpotifyVolumeFromSlider })
        $script:volumeRefreshTimer = New-DispatcherTimer 1400
        $script:volumeRefreshTimer.Add_Tick({ Update-SpotifyVolumeUI })
        $script:volumeMute.Add_Click({ Toggle-SpotifyMute })
        $script:volumeSlider.Add_ValueChanged({
            if ($script:volumeReady -and !$script:volumeSyncing -and $script:volumeSlider.IsEnabled) {
                $script:volumePercent.Text = ('{0}%' -f [int][Math]::Round($script:volumeSlider.Value))
                $script:volumePending = $true
                $script:volumeApplyTimer.Stop()
                $script:volumeApplyTimer.Start()
            }
        })
        Initialize-SpotifyVolume
        $script:mediaTimer = New-DispatcherTimer 270
        $script:mediaTimer.Add_Tick({ if ($script:managerType) { Update-Media } })
        $script:hoverTimer = New-DispatcherTimer 125
        $script:hoverTimer.Add_Tick({ Update-EdgePreview })
        $script:previewHideTimer = New-DispatcherTimer 570
        $script:previewHideTimer.Add_Tick({
            $script:previewHideTimer.Stop()
            if (!$script:attachedButton.IsMouseOver) {
                $p = [System.Windows.Forms.Cursor]::Position
                $a = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
                if (!(Test-MiddleRightEdge $a $p)) { Hide-EdgePreview }
            }
        })
        $script:flyout.Add_PreviewKeyDown({ param($source, $event)
            if ($event.Key -eq 'Escape') { Hide-Flyout; $event.Handled = $true }
        })
        $script:flyout.FindName('close').Add_Click({ Hide-Flyout })
        $script:attachedButton.Add_Click({ if ($script:expanded) { Hide-Flyout } else { Show-Flyout } })
        $script:flyout.FindName('openSpotify').Add_Click({ Open-Spotify })
        $script:flyout.FindName('openLyrics').Add_Click({ Open-Lyrics })
        $script:previous.Add_Click({ Send-MediaControl 'previous' })
        $script:toggle.Add_Click({ Send-MediaControl 'toggle' })
        $script:next.Add_Click({ Send-MediaControl 'next' })
        $script:compactButton.Add_Click({ Set-CompactLayout (!$script:compact) })
        $script:repeatButton.Add_Click({ Set-RepeatMode })
        $script:progress.Add_PreviewMouseLeftButtonDown({ $script:seeking = $true })
        $script:progress.Add_PreviewMouseLeftButtonUp({
            if ($script:seeking) { $script:seeking = $false; Invoke-SeekFromSlider }
        })
        $script:progress.Add_PreviewKeyUp({
            param($sender, $eventArgs)
            if ($eventArgs.Key -in @('Left','Right','Home','End','PageUp','PageDown')) {
                Invoke-SeekFromSlider
            }
        })


        # In-player palette chooser. The menu is attached to the existing header
        # and does not change the 354 x 398 panel geometry or its edge animation.
        $script:themePicker = [System.Windows.Controls.ContextMenu]::new()
        $script:themePicker.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString(
            $(if ($script:activeTheme -eq 'Burgundy') { '#341323' } else { $script:themeMaps[$script:activeTheme]['#341323'] })
        )
        $script:themePicker.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString(
            $(if ($script:activeTheme -eq 'Burgundy') { '#FFF3F6' } else { $script:themeMaps[$script:activeTheme]['#FFF3F6'] })
        )
        $script:themePicker.BorderThickness = [System.Windows.Thickness]::new(1)
        $brushFactory = [System.Windows.Media.BrushConverter]::new()
        foreach ($themeId in @('Burgundy', 'Forest', 'Sapphire', 'Amethyst', 'Obsidian')) {
            $themeChoice = [System.Windows.Controls.MenuItem]::new()
            $themeChoice.Tag = $themeId
            $themeChoice.IsCheckable = $true
            $themeChoice.IsChecked = $themeId -eq $script:activeTheme
            $themeChoice.ToolTip = [string] $script:themeNames[$themeId]

            $swatches = [System.Windows.Controls.StackPanel]::new()
            $swatches.Orientation = [System.Windows.Controls.Orientation]::Horizontal
            $palette = $script:themeMaps[$themeId]
            foreach ($sourceColor in @('#800020', '#DF7399')) {
                $swatch = [System.Windows.Shapes.Ellipse]::new()
                $swatch.Width = 11
                $swatch.Height = 11
                $swatch.Margin = [System.Windows.Thickness]::new(0,0,5,0)
                $color = if ($themeId -eq 'Burgundy') { $sourceColor } else { [string] $palette[$sourceColor] }
                $swatch.Fill = $brushFactory.ConvertFromString($color)
                $null = $swatches.Children.Add($swatch)
            }
            $caption = [System.Windows.Controls.TextBlock]::new()
            $caption.Text = [string] $script:themeNames[$themeId]
            $caption.Foreground = $script:themePicker.Foreground
            $caption.Margin = [System.Windows.Thickness]::new(5,0,0,0)
            $null = $swatches.Children.Add($caption)
            $themeChoice.Header = $swatches
            $themeChoice.Add_Click({
                param($sender, $eventArgs)
                Request-ThemeChange ([string] $sender.Tag)
            })
            $null = $script:themePicker.Items.Add($themeChoice)
        }
        $script:themeButton.ContextMenu = $script:themePicker
        $script:themeButton.Add_Click({
            $script:themePicker.PlacementTarget = $script:themeButton
            $script:themePicker.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Bottom
            $script:themePicker.IsOpen = $true
        })

        $shortcutReady = $false
        try { $shortcutReady = Register-CornerShortcut } catch {}
        if (!$shortcutReady -and $script:managerType) {
            $script:notice.Text = 'Ctrl+Shift+Q is unavailable. Use the middle-right Music tab or tray icon.'
        }
        $trayMenu = [System.Windows.Forms.ContextMenuStrip]::new()
        $showItem = $trayMenu.Items.Add($(if ($shortcutReady) { 'Show player (Ctrl+Shift+Q)' } else { 'Show player' }))
        $showItem.Add_Click({ Show-Flyout })

        # A tray submenu avoids resizing or rearranging the accepted WPF panel.
        # Theme changes persist and restart only this application.
        $script:themeMenu = [System.Windows.Forms.ToolStripMenuItem]::new('Color theme')
        foreach ($themeId in @('Burgundy', 'Forest', 'Sapphire', 'Amethyst', 'Obsidian')) {
            $themeItem = [System.Windows.Forms.ToolStripMenuItem]::new([string] $script:themeNames[$themeId])
            $themeItem.Tag = $themeId
            $themeItem.Checked = $themeId -eq $script:activeTheme
            $themeItem.Add_Click({
                param($sender, $eventArgs)
                $choice = [string] $sender.Tag
                if ($choice -eq $script:activeTheme) { return }
                Request-ThemeChange $choice
            })
            $null = $script:themeMenu.DropDownItems.Add($themeItem)
        }
        $null = $trayMenu.Items.Add($script:themeMenu)
        $launchItem = $trayMenu.Items.Add('Open Spotify')
        $launchItem.Add_Click({ Open-Spotify })
        $logsItem = $trayMenu.Items.Add('Open diagnostics folder')
        $logsItem.Add_Click({
            try { Start-Process explorer.exe -ArgumentList ('"{0}"' -f $logFolder) }
            catch { Write-PlayerLog 'ERROR' 'UI' $_.Exception.ToString() }
        })
        $exitItem = $trayMenu.Items.Add('Exit player')
        $exitItem.Add_Click({ $script:app.Shutdown() })
        $tray = [System.Windows.Forms.NotifyIcon]::new()
        $tray.Icon = [Drawing.SystemIcons]::Application
        $tray.Text = 'Spotify Corner Player'
        $tray.ContextMenuStrip = $trayMenu
        $tray.Add_DoubleClick({ Show-Flyout })
        $tray.Visible = $true

        $script:lifecycle = New-DispatcherTimer 1000
        $script:lifecycle.Add_Tick({
            if ($script:stopSignal.WaitOne(0)) {
                $script:lifecycle.Stop()
                $script:mediaTimer.Stop()
                $script:volumeRefreshTimer.Stop()
                $script:volumeApplyTimer.Stop()
                $script:exitTimer.Stop()
                $script:hoverTimer.Stop()
                $script:previewHideTimer.Stop()
                $script:app.Shutdown()
            } elseif ($script:flyout.IsVisible -and $script:expanded) {
                Update-CornerPosition
            }
        })
        Update-CornerPosition
        $script:hoverTimer.Start()
        $script:lifecycle.Start()
        Write-PlayerLog 'INFO' 'Runtime' 'Single-window UI initialized and ready.'
        $null = $ready.Set()
        if ($ShowOnStart) {
            # A fresh theme opens the player again, without extra clicks.
            $script:themeOpenTimer = New-DispatcherTimer 350
            $script:themeOpenTimer.Add_Tick({
                $script:themeOpenTimer.Stop()
                Show-Flyout
            })
            $script:themeOpenTimer.Start()
        }
        $null = $script:app.Run()
        Write-PlayerLog 'INFO' 'Runtime' 'Player exited normally.'
    } catch {
        Write-PlayerLog 'ERROR' 'Runtime' $_.Exception.ToString()
        throw
    } finally {
        if ($script:shortcutHandle -ne [IntPtr]::Zero) {
            $null = [SpotifyCornerPlayer.HotKey]::UnregisterHotKey($script:shortcutHandle, 1)
        }
        if ($tray) { $tray.Visible = $false; $tray.Dispose() }
        if ($ready) { $ready.Dispose() }
        if ($script:stopSignal) { $script:stopSignal.Dispose() }
        if ($ownsInstance) { $instance.ReleaseMutex() }
        $instance.Dispose()
    }
}

switch ($Mode) {
    'Install' { Install-CornerPlayer }
    'Uninstall' { Uninstall-CornerPlayer }
    'Run' { Start-CornerPlayer }
    'Restart' { Restart-CornerPlayer }
}
