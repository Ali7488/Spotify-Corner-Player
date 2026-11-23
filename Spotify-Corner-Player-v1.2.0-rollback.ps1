#Requires -Version 5.1
<#
.SYNOPSIS
Installs Spotify Corner Player v1.2.0 for the current Windows user.

.EXAMPLE
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Spotify-Corner-Player-v1.2.0.ps1 -Mode Install

.EXAMPLE
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Spotify-Corner-Player-v1.2.0.ps1 -Mode Uninstall
#>
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Uninstall', 'Run')]
    [string] $Mode = 'Install'
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
            'Spotify Corner Player v1.2.0'
            'Running for the current Windows user. Startup shortcut installed.'
            'Burgundy theme, crossfading album artwork, spinning vinyl, animated show/hide.'
            'Hover at the middle-right screen edge for a tiny Music tab; click the tab to open the player.'
            'No full-player auto-popup. Mouse out hides the tiny tab after a moment.'
            'Ctrl+Shift+Q toggles the player if that key combination is available.'
            'The panel has an Open Spotify button even when Spotify is closed.'
            'Use the tray icon for Show or Exit. Run the script with -Mode Uninstall to remove it.'
            "Startup shortcut: $startupLink"
        ) | Set-Content -LiteralPath $reportFile -Encoding UTF8
    } catch {
        $failure = $_
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
            Remove-Item -LiteralPath $reportFile, $marker -ErrorAction SilentlyContinue
            if (!(Get-ChildItem -LiteralPath $installFolder -Force | Select-Object -First 1)) {
                Remove-Item -LiteralPath $installFolder
            }
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
    foreach ($path in @($startupLink, $installedScript, $reportFile, $marker)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Remove-Item -LiteralPath $path -Force
        }
    }
    if ((Test-Path -LiteralPath $installFolder -PathType Container) -and
        !(Get-ChildItem -LiteralPath $installFolder -Force | Select-Object -First 1)) {
        Remove-Item -LiteralPath $installFolder
    }
    Write-Output 'Spotify Corner Player removed from this Windows account.'
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
    $script:flyout.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $script:flyout.Opacity = [Math]::Max(0.01, $script:flyout.Opacity)
    $script:panelShift.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $null)
    $script:panelShift.X = 26
    $script:panelScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $null)
    $script:panelScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $null)
    $script:panelScale.ScaleX = 0.965
    $script:panelScale.ScaleY = 0.965
    Animate-Double $script:flyout ([System.Windows.UIElement]::OpacityProperty) 1 255
    Animate-Double $script:panelShift ([System.Windows.Media.TranslateTransform]::XProperty) 0 290
    Animate-Double $script:panelScale ([System.Windows.Media.ScaleTransform]::ScaleXProperty) 1 290
    Animate-Double $script:panelScale ([System.Windows.Media.ScaleTransform]::ScaleYProperty) 1 290
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
    $script:metadataTask = $null
    $script:trackKey = ''
    Set-DiscMotion $false
}

function Set-Art($media) {
    $script:song.Text = if ($media.Title) { $media.Title } else { 'Spotify' }
    $script:artist.Text = $media.Artist
    $key = '{0}|{1}|{2}' -f $media.Title, $media.Artist, $media.AlbumTitle
    if ($key -eq $script:trackKey) { return }
    $script:trackKey = $key
    Animate-TextChange
    if ($script:artTask -and $script:artTask.IsCompleted) {
        try {
            $oldStream = $script:artTask.GetAwaiter().GetResult()
            if ($oldStream -is [IDisposable]) { $oldStream.Dispose() }
        } catch {}
    }
    $script:artTask = $null
    if ($media.Thumbnail) {
        $script:artTask = New-MediaTask ($media.Thumbnail.OpenReadAsync()) $script:streamType
    } else {
        Set-CoverBrush $script:coverPlaceholder
    }
}

function Read-Cover {
    if (!$script:artTask -or !$script:artTask.IsCompleted) { return }
    $task = $script:artTask
    $script:artTask = $null
    $random = $task.GetAwaiter().GetResult()
    try {
        $stream = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($random)
        try {
            $image = [System.Windows.Media.Imaging.BitmapImage]::new()
            $image.BeginInit()
            $image.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $image.DecodePixelWidth = 256
            $image.StreamSource = $stream
            $image.EndInit()
            $image.Freeze()
            $brush = [System.Windows.Media.ImageBrush]::new($image)
            $brush.Stretch = 'UniformToFill'
            Set-CoverBrush $brush
        } finally {
            $stream.Dispose()
        }
    } finally {
        if ($random -is [IDisposable]) { $random.Dispose() }
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
        try { Read-Cover } catch { Set-CoverBrush $script:coverPlaceholder }
        if ($script:controlTask -and $script:controlTask.IsCompleted) {
            $task = $script:controlTask
            $script:controlTask = $null
            if (!$task.GetAwaiter().GetResult()) {
                $script:notice.Text = 'Spotify did not accept that action.'
            }
        }
    } catch {
        $script:playerId = ''
        $script:controlTask = $null
        Reset-MediaPanel 'Spotify controls are temporarily unavailable'
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

function New-DispatcherTimer([int] $milliseconds) {
    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds($milliseconds)
    $timer
}

function Update-CornerPosition {
    # Window positioning uses WPF device-independent pixels on the primary screen.
    $area = [System.Windows.SystemParameters]::WorkArea
    $script:preview.Left = $area.Right - $script:preview.Width - 3
    $script:preview.Top = $area.Top + ($area.Height - $script:preview.Height) / 2
    $script:flyout.Left = [Math]::Max($area.Left + 8,
        $area.Right - $script:flyout.Width - $script:preview.Width - 12)
    $script:flyout.Top = [Math]::Max($area.Top + 8,
        [Math]::Min($area.Bottom - $script:flyout.ActualHeight - 8,
            $area.Top + ($area.Height - $script:flyout.ActualHeight) / 2))
}

function Test-MiddleRightEdge($area, $pointer) {
    $centre = $area.Top + ($area.Height / 2)
    $pointer.X -ge ($area.Right - 16) -and $pointer.X -lt $area.Right -and
        [Math]::Abs($pointer.Y - $centre) -le 88
}

function Show-EdgePreview {
    if ($script:preview.IsVisible) { return }
    Update-CornerPosition
    $script:previewHideTimer.Stop()
    $script:preview.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $script:previewShift.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $null)
    $script:preview.Opacity = 0
    $script:previewShift.X = 17
    $script:preview.Show()
    Animate-Double $script:preview ([System.Windows.UIElement]::OpacityProperty) 1 190
    Animate-Double $script:previewShift ([System.Windows.Media.TranslateTransform]::XProperty) 0 220
}

function Hide-EdgePreview {
    $script:previewHideTimer.Stop()
    if ($script:preview.IsVisible -and !$script:flyout.IsVisible) {
        $script:preview.Hide()
    }
}

function Update-EdgePreview {
    # Cursor and hot-zone share WinForms physical pixels; WPF sizes are handled separately.
    $area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $pointer = [System.Windows.Forms.Cursor]::Position
    $nearEdge = Test-MiddleRightEdge $area $pointer
    if ($nearEdge -or $script:preview.IsMouseOver -or $script:flyout.IsVisible) {
        $script:previewHideTimer.Stop()
        if ($nearEdge -and !$script:flyout.IsVisible) { Show-EdgePreview }
    } elseif ($script:preview.IsVisible -and !$script:previewHideTimer.IsEnabled) {
        $script:previewHideTimer.Start()
    }
}

function Show-Flyout {
    $script:exitTimer.Stop()
    $script:closing = $false
    $script:previewHideTimer.Stop()
    $script:preview.Hide()
    # Ensure its ActualHeight is populated before final placement.
    if (!$script:flyout.IsVisible) {
        $script:flyout.Opacity = 0
        $script:flyout.Show()
    }
    Update-CornerPosition
    Animate-PanelIn
    $script:mediaTimer.Start()
    if ($script:managerType) { Update-Media }
}

function Hide-Flyout {
    if (!$script:flyout.IsVisible -or $script:closing) { return }
    $script:closing = $true
    Animate-Double $script:flyout ([System.Windows.UIElement]::OpacityProperty) 0 165 'In'
    Animate-Double $script:panelShift ([System.Windows.Media.TranslateTransform]::XProperty) 22 165 'In'
    Animate-Double $script:panelScale ([System.Windows.Media.ScaleTransform]::ScaleXProperty) 0.97 165 'In'
    Animate-Double $script:panelScale ([System.Windows.Media.ScaleTransform]::ScaleYProperty) 0.97 165 'In'
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
            if ($script:flyout.IsVisible -and !$script:closing) { Hide-Flyout } else { Show-Flyout }
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
        } catch {}

        $script:app = [System.Windows.Application]::new()
        $script:app.ShutdownMode = 'OnExplicitShutdown'

        [xml] $previewLayout = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Music edge tab" Width="94" Height="48"
        WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
        Background="Transparent" Topmost="True" ShowActivated="False" ShowInTaskbar="False"
        FontFamily="Segoe UI">
  <Grid RenderTransformOrigin="0.8,0.5">
    <Grid.RenderTransform><TranslateTransform x:Name="previewShift" /></Grid.RenderTransform>
    <Border CornerRadius="13,0,0,13" Background="#2A0D1B" BorderBrush="#A25272" BorderThickness="1.2">
      <Button x:Name="previewButton" ToolTip="Open Spotify controls" Background="Transparent"
              BorderThickness="0" Cursor="Hand" Padding="6,2" Foreground="#FFE6EF">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Center">
          <TextBlock Text="&#9835;" FontSize="20" Foreground="#F2A4C0" Margin="0,0,7,0" VerticalAlignment="Center"/>
          <TextBlock Text="Music" FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center"/>
        </StackPanel>
      </Button>
    </Border>
  </Grid>
</Window>
'@
        $previewReader = [System.Xml.XmlNodeReader]::new($previewLayout)
        try { $script:preview = [System.Windows.Markup.XamlReader]::Load($previewReader) }
        finally { $previewReader.Dispose() }
        $script:previewShift = $script:preview.FindName('previewShift')
        $script:preview.FindName('previewButton').Add_Click({ Show-Flyout })

        [xml] $layout = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Spotify Corner Player" Width="354" SizeToContent="Height"
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
  <Border x:Name="panel" CornerRadius="21" BorderBrush="#874461" BorderThickness="1.2" Padding="17,15,17,16"
          RenderTransformOrigin="0.95,0.03">
    <Border.Background>
      <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
        <GradientStop Color="#341323" Offset="0" />
        <GradientStop Color="#1B0C15" Offset="0.56" />
        <GradientStop Color="#290E1C" Offset="1" />
      </LinearGradientBrush>
    </Border.Background>
    <Border.RenderTransform>
      <TransformGroup>
        <ScaleTransform x:Name="panelScale" ScaleX="1" ScaleY="1" />
        <TranslateTransform x:Name="panelShift" />
      </TransformGroup>
    </Border.RenderTransform>
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
      <UniformGrid Columns="3" Margin="0,0,0,8">
        <Button x:Name="previous" Content="&#10094;  Prev" />
        <Button x:Name="toggle" Content="Play" Background="#800020" BorderBrush="#C05A7C" />
        <Button x:Name="next" Content="Next  &#10095;" />
      </UniformGrid>
      <Button x:Name="openSpotify" Content="Open Spotify" Background="#392031" />
      <TextBlock x:Name="notice" Foreground="#F5CAAA" FontSize="11" TextWrapping="Wrap" Margin="4,7,4,0" />
    </StackPanel>
  </Border>
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
        $script:panelShift = $script:flyout.FindName('panelShift')
        $script:panelScale = $script:flyout.FindName('panelScale')
        $script:coverPlaceholder = $script:cover.Fill
        $script:song = $script:flyout.FindName('song')
        $script:artist = $script:flyout.FindName('artist')
        $script:detail = $script:flyout.FindName('detail')
        $script:progress = $script:flyout.FindName('progress')
        $script:previous = $script:flyout.FindName('previous')
        $script:toggle = $script:flyout.FindName('toggle')
        $script:next = $script:flyout.FindName('next')
        $script:notice = $script:flyout.FindName('notice')
        $script:discMoving = $false
        $script:closing = $false
        $script:manager = $null
        $script:managerTask = $null
        $script:controlTask = $null
        $script:playerId = ''
        $script:nextMetadata = [DateTime]::MinValue
        Reset-MediaPanel 'Spotify is closed or idle'
        if (!$script:managerType) { $script:notice.Text = 'Windows media controls are unavailable.' }

        $script:exitTimer = New-DispatcherTimer 185
        $script:exitTimer.Add_Tick({
            $script:exitTimer.Stop()
            if ($script:closing) {
                $script:flyout.Hide()
                $script:mediaTimer.Stop()
                Set-DiscMotion $false
                $script:closing = $false
            }
        })
        $script:mediaTimer = New-DispatcherTimer 270
        $script:mediaTimer.Add_Tick({ if ($script:managerType) { Update-Media } })
        $script:hoverTimer = New-DispatcherTimer 125
        $script:hoverTimer.Add_Tick({ Update-EdgePreview })
        $script:previewHideTimer = New-DispatcherTimer 570
        $script:previewHideTimer.Add_Tick({
            $script:previewHideTimer.Stop()
            if (!$script:preview.IsMouseOver) { Hide-EdgePreview }
        })
        $script:flyout.Add_PreviewKeyDown({ param($source, $event)
            if ($event.Key -eq 'Escape') { Hide-Flyout; $event.Handled = $true }
        })
        $script:flyout.FindName('close').Add_Click({ Hide-Flyout })
        $script:flyout.FindName('openSpotify').Add_Click({ Open-Spotify })
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
                $script:exitTimer.Stop()
                $script:hoverTimer.Stop()
                $script:previewHideTimer.Stop()
                $script:app.Shutdown()
            } elseif ($script:flyout.IsVisible -or $script:preview.IsVisible) {
                Update-CornerPosition
            }
        })
        Update-CornerPosition
        $script:hoverTimer.Start()
        $script:lifecycle.Start()
        $null = $ready.Set()
        $null = $script:app.Run()
    } finally {
        if ($script:shortcutHandle -ne [IntPtr]::Zero) {
            $null = [SpotifyCornerPlayer.HotKey]::UnregisterHotKey($script:shortcutHandle, 1)
        }
        if ($script:preview) { $script:preview.Close() }
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
