#Requires -Version 5.1
<#
.SYNOPSIS
  Offline migration verification for manually installed Spotify Corner Player.
.DESCRIPTION
  Uses isolated temporary AppData and Startup folders.
  It loads ONLY two narrowly selected functions from the checked-in script.
  It never launches, stops, installs, or uninstalls the real player.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))) 'Spotify-Corner-Player-v1.4.3.ps1'
$tokens = $null
$errors = $null
$tree = [Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) { throw 'Source parse failed.' }
foreach ($functionName in @('Get-ExistingInstallInfo', 'Assert-OwnedInstall')) {
    $definitions = @($tree.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $functionName
    }, $true))
    if ($definitions.Count -ne 1) { throw "Expected exactly one $functionName" }
    . ([ScriptBlock]::Create($definitions[0].Extent.Text))
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('SpotifyCorner-Migration-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $temp -Force
try {
    $installFolder = Join-Path $temp 'AppData\SpotifyCornerPlayer'
    $installedScript = Join-Path $installFolder 'Spotify-Corner-Player.ps1'
    $marker = Join-Path $installFolder '.owner'
    $startupFolder = Join-Path $temp 'Startup'
    $startupLink = Join-Path $startupFolder 'Spotify Corner Player.lnk'
    $signature = 'SpotifyCornerPlayer/1'
    $engine = Join-Path $PSHOME 'powershell.exe'
    $startupArgs = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Mode Run' -f $installedScript
    $null = New-Item -ItemType Directory -Path $installFolder, $startupFolder -Force
    # Verify v1.2.4 source (not produced by the release download).
    Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $sourcePath) 'Spotify-Corner-Player-v1.2.4.ps1') -Destination $installedScript
    [IO.File]::WriteAllText($marker, $signature)
    if ((Get-ExistingInstallInfo) -ne 'v1.2.4') {
        throw 'Manually installed v1.2.4 was not detected.'
    }
    Assert-OwnedInstall
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($startupLink)
    $shortcut.TargetPath = $engine
    $shortcut.Arguments = $startupArgs
    $shortcut.Save()
    Assert-OwnedInstall

    # A legacy owned shortcut might use different argument formatting.
    $shortcut = $shell.CreateShortcut($startupLink)
    $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Mode Run -STA' -f $installedScript
    $shortcut.Save()
    Assert-OwnedInstall

    # A genuine foreign shortcut must never be overwritten.
    $shortcut = $shell.CreateShortcut($startupLink)
    $shortcut.TargetPath = Join-Path $env:WINDIR 'System32\cmd.exe'
    $shortcut.Arguments = '/c echo not spotify corner player'
    $shortcut.Save()
    $refused = $false
    try { Assert-OwnedInstall } catch { $refused = $true }
    if (!$refused) { throw 'Unrelated startup shortcut was accepted.' }

    Remove-Item -LiteralPath $startupLink -Force
    [IO.File]::WriteAllText($marker, 'unrelated application marker')
    $refused = $false
    try { Assert-OwnedInstall } catch { $refused = $true }
    if (!$refused) { throw 'Unrelated installation marker was accepted.' }

    [IO.File]::WriteAllText($marker, $signature)
    [IO.File]::WriteAllText($installedScript, '# Manually installed v1.3.0 preview\n')
    if ((Get-ExistingInstallInfo) -ne 'v1.3.0') {
        throw 'Manual v1.3.0 installation was not detected.'
    }
    Assert-OwnedInstall

    Write-Host 'PASS: v1.2.4 / v1.3.0 manual installs accepted; foreign marker/shortcut refused.'
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
