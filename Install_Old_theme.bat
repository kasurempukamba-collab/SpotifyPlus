@echo off
setlocal

set "url=https://raw.githubusercontent.com/kasurempukamba-collab/SpotifyPlus/main/run.ps1"
set "spplus_script=%~dp0SpotifyPlus-run.ps1"

echo Downloading SpotifyPlus...
curl.exe -L --fail --silent --show-error "%url%" -o "%spplus_script%"

if errorlevel 1 (
    echo Failed to download SpotifyPlus.
    pause
    exit /b 1
)

echo Starting SpotifyPlus...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%spplus_script%" -v 1.2.13.661.ga588f749 -confirm_spoti_recomended_over -block_update_on -no_pause

set "exitcode=%ERRORLEVEL%"
del /q "%spplus_script%" >nul 2>&1

pause
exit /b %exitcode%
