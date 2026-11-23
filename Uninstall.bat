@echo off
setlocal
cd /d "%~dp0"
title Spotify Corner Player - Uninstall
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Setup.ps1" -Mode Uninstall
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" (
    echo Uninstall did not complete. Review the error above.
) else (
    echo Spotify Corner Player removal completed. Diagnostic logs were preserved.
)
echo.
pause
exit /b %RESULT%
