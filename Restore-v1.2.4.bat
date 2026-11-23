@echo off
setlocal
cd /d "%~dp0"
title Spotify Corner Player - Restore stable v1.2.4
echo Restoring the verified v1.2.4 Spotify Corner Player...
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Spotify-Corner-Player-v1.2.4.ps1" -Mode Install
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" (
    echo Restore failed. See the error above.
) else (
    echo Stable v1.2.4 has been restored. The saved theme will be ignored by this version.
)
echo.
pause
exit /b %RESULT%
