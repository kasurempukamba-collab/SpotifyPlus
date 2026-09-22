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
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%spplus_script%" -confirm_uninstall_ms_spoti -confirm_spoti_recomended_over -podcasts_off -block_update_on -start_spoti -new_theme -adsections_off -lyrics_stat spotify -no_pause

set "exitcode=%ERRORLEVEL%"
del /q "%spplus_script%" >nul 2>&1

pause
exit /b %exitcode%
