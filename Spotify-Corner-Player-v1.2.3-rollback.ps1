#Requires -Version 5.1
<#
.SYNOPSIS
Installs Spotify Corner Player v1.2.3 for the current Windows user.

.EXAMPLE
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Spotify-Corner-Player-v1.2.3.ps1 -Mode Install

.EXAMPLE
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Spotify-Corner-Player-v1.2.3.ps1 -Mode Uninstall
#>
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Uninstall', 'Run')]
    [string] $Mode = 'Install',
    [switch] $PurgeLogs
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

function Assert-OwnedInstall {
    if ((Test-Path -LiteralPath $installFolder) -and
        (!(Test-Path -LiteralPath $marker -PathType Leaf) -or [IO.File]::ReadAllText($marker) -ne $signature)) {
        throw "An unrelated folder already exists at $installFolder."
    }
    if (Test-Path -LiteralPath $startupLink) {
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($startupLink)
        if ($link.TargetPath -ne $engine -or $link.Arguments -ne $startupArgs) {
            throw "An unrelated startup shortcut already exists at $startupLink."
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

function Install-CornerPlayer {
    Assert-OwnedInstall
    Stop-CornerPlayer
    $hadInstall = Test-Path -LiteralPath $marker -PathType Leaf
    $hadShortcut = Test-Path -LiteralPath $startupLink -PathType Leaf
    $previousScript = if (Test-Path -LiteralPath $installedScript -PathType Leaf) {
        [IO.File]::ReadAllBytes($installedScript)
    }
    $null = New-Item -ItemType Directory -Force -Path $installFolder, $startupFolder
    [IO.File]::WriteAllText($marker, $signature)
    Write-PlayerLog 'INFO' 'Install' 'Starting upgrade to v1.2.3 (stable anchored edge drawer and artwork DataReader).'

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
            'Spotify Corner Player v1.2.3'
            'Running for the current Windows user. Startup shortcut installed.'
            'Burgundy theme, crossfading album artwork, spinning vinyl, animated show/hide.'
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
        Write-PlayerLog 'INFO' 'Install' 'Upgrade completed successfully.'
    } catch {
        $failure = $_
        Write-PlayerLog 'ERROR' 'Install' ($failure.Exception.ToString())
        Stop-CornerPlayer
        if (!$hadShortcut -and (Test-Path -LiteralPath $startupLink -PathType Leaf)) {
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

function Set-CoverBrush($brush) {
    if (!$brush) { $brush = $script:coverPlaceholder }
    # Keep a snapshot of the old artwork while the new one fades in.
    $script:coverOld.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $script:coverOld.Fill = $script:cover.Fill
    $script:coverOld.Opacity = 1
    $script:cover.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $script:cover.Fill = $brush
    $script:cover.Opacity = 0
    $script:discArt.Fill = $brush
    Animate-Double $script:cover ([System.Windows.UIElement]::OpacityProperty) 1 360
    Animate-Double $script:coverOld ([System.Windows.UIElement]::OpacityProperty) 0 360
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
        $angle = $script:disc.Angle
        $script:disc.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $null)
        $script:disc.Angle = $angle % 360
    }
}

function Reset-MediaPanel([string] $caption) {
    $script:song.Text = $caption
    $script:artist.Text = ''
    $script:detail.Text = ''
    $script:progress.Value = 0
    $script:progress.Visibility = 'Collapsed'
    $script:previous.IsEnabled = $false
    $script:toggle.IsEnabled = $false
    $script:next.IsEnabled = $false
    $script:toggle.Content = 'Play'
    $script:cover.Fill = $script:coverPlaceholder
    $script:discArt.Fill = $script:coverPlaceholder
    $script:coverOld.Opacity = 0
    $script:cover.Opacity = 1
    $script:artTask = $null
    $script:artLoadTask = $null
    $script:artReader = $null
    $script:artStream = $null
    $script:metadataTask = $null
    $script:trackKey = ''
    $script:trackThumbnail = $null
    $script:artAttempt = 0
    $script:artRetryAt = [DateTime]::MinValue
    $script:artSucceeded = $false
    Set-DiscMotion $false
}

function Request-Cover {
    if (!$script:trackThumbnail -or $script:artAttempt -ge 3 -or
        $script:artTask -or $script:artLoadTask -or $script:artSucceeded) { return }
    $script:artAttempt++
    $script:artRetryAt = [DateTime]::UtcNow.AddSeconds($(if ($script:artAttempt -eq 1) { 3 } else { 12 }))
    try {
        $script:artTask = New-MediaTask ($script:trackThumbnail.OpenReadAsync()) $script:streamType
        Write-PlayerLog 'INFO' 'Artwork' ('Requested thumbnail, attempt {0}/3.' -f $script:artAttempt)
    } catch {
        Write-PlayerLog 'ERROR' 'Artwork' ('Thumbnail open request failed: ' + $_.Exception.Message)
        $script:artTask = $null
    }
}

function Set-Art($media) {
    $script:song.Text = if ($media.Title) { $media.Title } else { 'Spotify' }
    $script:artist.Text = $media.Artist
    $key = '{0}|{1}|{2}' -f $media.Title, $media.Artist, $media.AlbumTitle
    if ($key -eq $script:trackKey) { return }
    $script:trackKey = $key
    Animate-TextChange
    # Drop old asynchronous work. Never call COM .Dispose(): System.__ComObject lacks it.
    # The old WinRT operations can finish and be collected without touching current artwork.
    $script:artTask = $null
    $script:artLoadTask = $null
    $script:artReader = $null
    $script:artStream = $null
    $script:trackThumbnail = $media.Thumbnail
    $script:artAttempt = 0
    $script:artRetryAt = [DateTime]::MinValue
    $script:artSucceeded = $false
    if (!$script:trackThumbnail) {
        Write-MediaIssue 'Artwork' 'Media session returned no thumbnail for the current track.'
        Set-CoverBrush $script:coverPlaceholder
    } else {
        Request-Cover
    }
}

function Read-Cover {
    # Deliberately do not use AsStreamForRead or direct WinRT COM .Dispose().
    # Actual v1.2.1 logs proved these both fail on this Windows PowerShell 5.1 host.
    if ($script:artLoadTask) {
        if (!$script:artLoadTask.IsCompleted) { return }
        $task = $script:artLoadTask
        $script:artLoadTask = $null
        try {
            $loaded = [uint32] $task.GetAwaiter().GetResult()
            if ($loaded -lt 16) { throw 'Artwork stream returned fewer than 16 bytes.' }
            if ($loaded -gt 12582912) { throw 'Artwork exceeds the 12 MiB safety limit.' }
            $bytes = [byte[]]::new([int] $loaded)
            $script:artReader.ReadBytes($bytes)
            $memory = [IO.MemoryStream]::new($bytes, 0, $bytes.Length, $false, $true)
            try {
                $image = [System.Windows.Media.Imaging.BitmapImage]::new()
                $image.BeginInit()
                $image.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $image.DecodePixelWidth = 256
                $image.StreamSource = $memory
                $image.EndInit()
                $image.Freeze()
                $brush = [System.Windows.Media.ImageBrush]::new($image)
                $brush.Stretch = 'UniformToFill'
                Set-CoverBrush $brush
            } finally {
                $memory.Dispose()
            }
            $script:artSucceeded = $true
            $script:notice.Text = ''
            Write-PlayerLog 'INFO' 'Artwork' ('Decoded cover with WinRT DataReader ({0} bytes).' -f $loaded)
        } catch {
            Write-CoverFailure $_.Exception.ToString()
        } finally {
            $script:artReader = $null
            $script:artStream = $null
        }
        return
    }
    if (!$script:artTask -or !$script:artTask.IsCompleted) { return }
    $task = $script:artTask
    $script:artTask = $null
    try {
        $random = $task.GetAwaiter().GetResult()
        if (!$random) { throw 'Windows returned an empty artwork stream.' }
        $size = [uint64] $random.Size
        if ($size -lt 16) { throw 'Windows supplied an empty or tiny artwork stream.' }
        if ($size -gt 12582912) { throw 'Artwork exceeds the 12 MiB safety limit.' }
        $input = $random.GetInputStreamAt([uint64] 0)
        $readerType = [Windows.Storage.Streams.DataReader,Windows.Storage.Streams,ContentType=WindowsRuntime]
        $script:artReader = [Activator]::CreateInstance($readerType, [object[]] @($input))
        $script:artStream = $random
        $script:artLoadTask = New-MediaTask ($script:artReader.LoadAsync([uint32]$size)) ([uint32])
    } catch {
        $script:artReader = $null
        $script:artStream = $null
        $script:artLoadTask = $null
        Write-CoverFailure $_.Exception.ToString()
    }
}

function Write-CoverFailure([string] $details) {
    Write-PlayerLog 'ERROR' 'Artwork' ('Cover loading attempt ' + $script:artAttempt + '/3 failed: ' + $details)
    if ($script:artAttempt -ge 3) {
        Set-CoverBrush $script:coverPlaceholder
        $script:notice.Text = 'Album artwork unavailable. See player logs.'
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
        $controls = $info.Controls
        $script:previous.IsEnabled = $controls.IsPreviousEnabled
        $script:next.IsEnabled = $controls.IsNextEnabled
        $script:toggle.IsEnabled = $controls.IsPlayPauseToggleEnabled -or
            ($playing -and $controls.IsPauseEnabled) -or (!$playing -and $controls.IsPlayEnabled)
        $script:toggle.Content = if ($playing) { 'Pause' } else { 'Play' }
        Set-DiscMotion $playing
        $timeline = $session.GetTimelineProperties()
        $duration = $timeline.EndTime.TotalSeconds - $timeline.StartTime.TotalSeconds
        if ($duration -gt 0) {
            $position = $timeline.Position.TotalSeconds - $timeline.StartTime.TotalSeconds
            if ($playing) { $position += [Math]::Max(0, ([DateTimeOffset]::UtcNow - $timeline.LastUpdatedTime).TotalSeconds) }
            $position = [Math]::Min($duration, [Math]::Max(0, $position))
            $script:progress.Value = 100 * $position / $duration
            $script:progress.Visibility = 'Visible'
            $script:detail.Text = '{0} / {1}' -f (Format-PlaybackTime $position), (Format-PlaybackTime $duration)
        } else {
            $script:progress.Visibility = 'Collapsed'
            $script:detail.Text = ''
        }

        if ($script:metadataTask -and $script:metadataTask.IsCompleted) {
            $task = $script:metadataTask
            $script:metadataTask = $null
            Set-Art ($task.GetAwaiter().GetResult())
        }
        if (!$script:metadataTask -and [DateTime]::UtcNow -ge $script:nextMetadata) {
            $script:nextMetadata = [DateTime]::UtcNow.AddSeconds(1)
            $script:metadataTask = New-MediaTask ($session.TryGetMediaPropertiesAsync()) $script:propertiesType
        }
        # Read-Cover logs its own errors and schedules bounded retries.
        Read-Cover
        if (!$script:artSucceeded -and !$script:artTask -and !$script:artLoadTask -and $script:trackThumbnail -and
            $script:artAttempt -lt 3 -and [DateTime]::UtcNow -ge $script:artRetryAt) {
            Request-Cover
        }
        if ($script:controlTask -and $script:controlTask.IsCompleted) {
            $task = $script:controlTask
            $script:controlTask = $null
            if (!$task.GetAwaiter().GetResult()) {
                $script:notice.Text = 'Spotify did not accept that action.'
            }
        }
    } catch {
        # A metadata hiccup must not clear the player and restart an entire artwork retry loop.
        Write-MediaIssue 'Playback' $_.Exception.ToString()
        $script:notice.Text = 'Spotify metadata briefly unavailable; see logs if it persists.'
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
    # Fixed 354-DIP panel, 72-DIP ribbon and 360-DIP height. Panel flush against right edge.
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
    if (!$script:flyout.IsVisible) { Update-CornerPosition; $script:flyout.Show() }
    Animate-PanelIn
    Write-PlayerLog 'INFO' 'UI' 'Expanded panel flush right; Music tab pushed beyond screen edge.'
    $script:mediaTimer.Start()
    $script:volumeRefreshTimer.Start()
    Update-SpotifyVolumeUI
    if ($script:managerType) { Update-Media }
}

function Hide-Flyout {
    if (!$script:expanded -or $script:closing) { return }
    $script:closing = $true
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
        Write-PlayerLog 'INFO' 'Runtime' 'Spotify Corner Player v1.2.3 launched.'
        $script:stopSignal = [System.Threading.EventWaitHandle]::new($false, [System.Threading.EventResetMode]::ManualReset, $stopName)
        $null = $script:stopSignal.Reset()
        $ready = [System.Threading.EventWaitHandle]::new($false, [System.Threading.EventResetMode]::ManualReset, $readyName)

        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing
        $script:managerType = $null
        try {
            Add-Type -AssemblyName System.Runtime.WindowsRuntime
            $script:propertiesType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime]
            $script:streamType = [Windows.Storage.Streams.IRandomAccessStreamWithContentType,Windows.Storage.Streams,ContentType=WindowsRuntime]
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

        [xml] $layout = @'
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
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Ellipse Width="8" Height="8" Fill="#DF7399" Margin="0,0,9,0" />
          <StackPanel>
            <TextBlock Text="SPOTIFY" Foreground="#F9EEF2" FontWeight="Bold" FontSize="12" />
            <TextBlock Text="NOW PLAYING" Foreground="#C684A0" FontSize="10" Margin="0,2,0,0" />
          </StackPanel>
        </StackPanel>
      </DockPanel>
      <Grid Margin="0,0,0,15" Height="133">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="146" />
          <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>
        <Grid Width="142" Height="128" HorizontalAlignment="Left" VerticalAlignment="Center">
          <Grid x:Name="record" Width="112" Height="112" HorizontalAlignment="Right" VerticalAlignment="Center"
                RenderTransformOrigin="0.5,0.5">
            <Grid.RenderTransform><RotateTransform x:Name="disc" /></Grid.RenderTransform>
            <Ellipse Fill="#110B12" Stroke="#95546E" StrokeThickness="1" />
            <Ellipse Margin="7" Stroke="#49303D" StrokeThickness="1" />
            <Ellipse Margin="12" Stroke="#49303D" StrokeThickness="1" />
            <Ellipse Margin="17" Stroke="#49303D" StrokeThickness="1" />
            <Ellipse x:Name="discArt" Width="48" Height="48" Fill="#800020" />
            <Ellipse Width="8" Height="8" Fill="#F1C6D6" />
          </Grid>
          <Border Width="116" Height="116" CornerRadius="14" BorderBrush="#AD647F"
                  BorderThickness="1" Background="#210D17" HorizontalAlignment="Left" VerticalAlignment="Center">
            <Grid Width="112" Height="112" ClipToBounds="True">
              <Rectangle x:Name="cover" RadiusX="12" RadiusY="12" Width="112" Height="112">
                <Rectangle.Fill>
                  <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                    <GradientStop Color="#7F2748" Offset="0" />
                    <GradientStop Color="#371426" Offset="1" />
                  </LinearGradientBrush>
                </Rectangle.Fill>
              </Rectangle>
              <Rectangle x:Name="coverOld" RadiusX="12" RadiusY="12" Width="112" Height="112" Opacity="0" />
            </Grid>
          </Border>
        </Grid>
        <StackPanel x:Name="trackText" Grid.Column="1" VerticalAlignment="Center" Margin="4,0,0,0" Opacity="1">
          <StackPanel.RenderTransform><TranslateTransform x:Name="textShift" /></StackPanel.RenderTransform>
          <TextBlock x:Name="song" Text="Spotify" TextWrapping="Wrap" MaxHeight="67"
                     TextTrimming="CharacterEllipsis" Foreground="#FFF4F7" FontSize="17" FontWeight="Bold" />
          <TextBlock x:Name="artist" TextWrapping="Wrap" MaxHeight="40" Foreground="#DFB1C1" FontSize="12" Margin="0,6,0,0" />
          <TextBlock x:Name="detail" Foreground="#BC839B" FontSize="11" Margin="0,10,0,0" />
        </StackPanel>
      </Grid>
      <Border CornerRadius="2" Background="#503044" Height="4" Margin="3,0,3,11">
        <ProgressBar x:Name="progress" Height="4" Maximum="100" Foreground="#D45D87" Background="#503044" BorderThickness="0" />
      </Border>
      <DockPanel Height="30" Margin="3,0,3,8" LastChildFill="True" VerticalAlignment="Center">
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
        <Button x:Name="previous" Content="&#10094;  Prev" />
        <Button x:Name="toggle" Content="Play" Background="#800020" BorderBrush="#C05A7C" />
        <Button x:Name="next" Content="Next  &#10095;" />
      </UniformGrid>
      <UniformGrid Columns="2" Margin="0,0,0,2">
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
          Width="72" Height="34" CornerRadius="0,10,10,0" Background="#800020"
          BorderBrush="#C56D8C" BorderThickness="1,1,0,1">
    <Border.RenderTransform><TranslateTransform x:Name="tabShift" X="-72" /></Border.RenderTransform>
    <Button x:Name="attachedButton" AutomationProperties.Name="Collapse player" ToolTip="Collapse to Music tab"
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
        $reader = [System.Xml.XmlNodeReader]::new($layout)
        try { $script:flyout = [System.Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Dispose() }
        $script:disc = $script:flyout.FindName('disc')
        $script:discArt = $script:flyout.FindName('discArt')
        $script:cover = $script:flyout.FindName('cover')
        $script:coverOld = $script:flyout.FindName('coverOld')
        $script:trackText = $script:flyout.FindName('trackText')
        $script:textShift = $script:flyout.FindName('textShift')
        $script:panel = $script:flyout.FindName('panel')
        $script:panelRevealClip = $script:flyout.FindName('panelRevealClip')
        $script:tabShift = $script:flyout.FindName('tabShift')
        $script:coverPlaceholder = $script:cover.Fill
        $script:song = $script:flyout.FindName('song')
        $script:artist = $script:flyout.FindName('artist')
        $script:detail = $script:flyout.FindName('detail')
        $script:progress = $script:flyout.FindName('progress')
        $script:previous = $script:flyout.FindName('previous')
        $script:toggle = $script:flyout.FindName('toggle')
        $script:next = $script:flyout.FindName('next')
        $script:notice = $script:flyout.FindName('notice')
        $script:volumeMute = $script:flyout.FindName('volumeMute')
        $script:volumeSlider = $script:flyout.FindName('volumeSlider')
        $script:volumePercent = $script:flyout.FindName('volumePercent')
        $script:attachedButton = $script:flyout.FindName('attachedButton')
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

        $shortcutReady = $false
        try { $shortcutReady = Register-CornerShortcut } catch {}
        if (!$shortcutReady -and $script:managerType) {
            $script:notice.Text = 'Ctrl+Shift+Q is unavailable. Use the middle-right Music tab or tray icon.'
        }
        $trayMenu = [System.Windows.Forms.ContextMenuStrip]::new()
        $showItem = $trayMenu.Items.Add($(if ($shortcutReady) { 'Show player (Ctrl+Shift+Q)' } else { 'Show player' }))
        $showItem.Add_Click({ Show-Flyout })
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
}
