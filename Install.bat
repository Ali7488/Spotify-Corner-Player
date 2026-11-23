@echo off
setlocal
cd /d "%~dp0"
title Corner Media Player - Install
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Setup.ps1" -Mode Install
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" (
    echo Installation failed or was incomplete. Review the error above.
) else (
    echo Corner Media Player setup completed.
)
echo.
pause
exit /b %RESULT%
