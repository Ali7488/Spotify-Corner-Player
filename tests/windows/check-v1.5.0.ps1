#Requires -Version 5.1
# Offline v1.5.0 regression: no installation, no media playback and no UI launch.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$sourcePath = Join-Path $root 'Spotify-Corner-Player-v1.5.0.ps1'
$source = [IO.File]::ReadAllText($sourcePath)
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) { throw "PowerShell source parse failed: $($errors | Out-String)" }

$match = [regex]::Match($source, '(?s)<Window xmlns=.*?</Window>')
if (!$match.Success) { throw 'WPF XAML not found' }
[xml] $xml = $match.Value
$ns = 'http://schemas.microsoft.com/winfx/2006/xaml'
foreach ($name in @('pinButton', 'shuffleButton', 'repeatButton', 'compactButton', 'sourceName')) {
    $found = @($xml.SelectNodes('//*[@*[local-name()="Name"]]') | Where-Object { $_.GetAttribute('Name', $ns) -eq $name })
    if ($found.Count -ne 1) { throw "Missing/duplicate control: $name" }
    if ($name -ne 'sourceName' -and [int]$found[0].GetAttribute('Width') -gt 35) {
        throw "Oversized utility button: $name"
    }
}
foreach ($expected in @('Get-PinChoice', 'Set-Pinned', 'Add_Deactivated',
                      'TryChangeShuffleActiveAsync', 'Get-ActiveMediaSession', 'Activate()',
                      'Get-MediaSessionLabel', 'volumeSlider.IsEnabled = $false')) {
    if (!$source.Contains($expected)) { throw "Missing v1.5.0 feature: $expected" }
}
if ($source.Contains('function Get-SpotifySession')) { throw 'Old Spotify-only session selector still present' }

# Run only the isolated media-selection function using in-memory fake sessions.
$definitions = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-ActiveMediaSession'
}, $true))
if ($definitions.Count -ne 1) { throw 'Expected one auto session selector' }
. ([ScriptBlock]::Create($definitions[0].Extent.Text))

function New-FakeSession([string] $id, [string] $status) {
    $s = [pscustomobject]@{ SourceAppUserModelId = $id; Status = $status }
    $s | Add-Member -MemberType ScriptMethod -Name GetPlaybackInfo -Value {
        return [pscustomobject]@{ PlaybackStatus = $this.Status }
    } -PassThru
}
$script:sessions = @()
$script:manager = [pscustomobject]@{}
$script:manager | Add-Member -MemberType ScriptMethod -Name GetSessions -Value { return $script:sessions }
$script:playerId = ''
if ($null -ne (Get-ActiveMediaSession)) { throw 'Empty session list should return null' }

$script:sessions = @(
    (New-FakeSession 'Spotify.exe' 'Paused'),
    (New-FakeSession 'firefox.exe' 'Playing')
)
if ((Get-ActiveMediaSession).SourceAppUserModelId -ne 'firefox.exe') {
    throw 'Auto should select the active playing application'
}
$script:playerId = 'firefox.exe'
$script:sessions[1].Status = 'Paused'
if ((Get-ActiveMediaSession).SourceAppUserModelId -ne 'firefox.exe') {
    throw 'A paused selected session should remain selected'
}
$script:playerId = ''
if ((Get-ActiveMediaSession).SourceAppUserModelId -ne 'Spotify.exe') {
    throw 'Idle fallback should prefer Spotify'
}
Write-Host 'PASS: WPF controls, Pin/Unpin click-away wiring, and active-session selection.'
