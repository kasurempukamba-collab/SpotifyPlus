@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

set "SPOTIFY_PATH=%Appdata%\Spotify"
set "RESTORE_FAILED=0"

if exist "%SPOTIFY_PATH%\chrome_elf.dll.bak" ( 
    del /s /q "%SPOTIFY_PATH%\chrome_elf.dll" > NUL 2>&1
    move /y "%SPOTIFY_PATH%\chrome_elf.dll.bak" "%SPOTIFY_PATH%\chrome_elf.dll" > NUL 2>&1
    if not exist "%SPOTIFY_PATH%\chrome_elf.dll" set "RESTORE_FAILED=1"
    if exist "%SPOTIFY_PATH%\chrome_elf.dll.bak" set "RESTORE_FAILED=1"
)

if exist "%SPOTIFY_PATH%\Spotify.dll.bak" ( 
    del /s /q "%SPOTIFY_PATH%\Spotify.dll" > NUL 2>&1
    move /y "%SPOTIFY_PATH%\Spotify.dll.bak" "%SPOTIFY_PATH%\Spotify.dll" > NUL 2>&1
    if not exist "%SPOTIFY_PATH%\Spotify.dll" set "RESTORE_FAILED=1"
    if exist "%SPOTIFY_PATH%\Spotify.dll.bak" set "RESTORE_FAILED=1"
)

if exist "%SPOTIFY_PATH%\Spotify.bak" ( 
    del /s /q "%SPOTIFY_PATH%\Spotify.exe" > NUL 2>&1
    move /y "%SPOTIFY_PATH%\Spotify.bak" "%SPOTIFY_PATH%\Spotify.exe" > NUL 2>&1
    if not exist "%SPOTIFY_PATH%\Spotify.exe" set "RESTORE_FAILED=1"
    if exist "%SPOTIFY_PATH%\Spotify.bak" set "RESTORE_FAILED=1"
)

if exist "%SPOTIFY_PATH%\Apps\xpui.bak" (
    del /s /q "%SPOTIFY_PATH%\Apps\xpui.spa" > NUL 2>&1
    move /y "%SPOTIFY_PATH%\Apps\xpui.bak" "%SPOTIFY_PATH%\Apps\xpui.spa" > NUL 2>&1
    if not exist "%SPOTIFY_PATH%\Apps\xpui.spa" set "RESTORE_FAILED=1"
    if exist "%SPOTIFY_PATH%\Apps\xpui.bak" set "RESTORE_FAILED=1"
) 

if exist "%temp%\SpotX_Temp*" (
    for /d %%i in ("%temp%\SpotX_Temp*") do (
        rd /s/q "%%i" > NUL 2>&1
    )
)

if "%RESTORE_FAILED%"=="1" (
    echo One or more original files could not be restored.
    echo Make sure Spotify is fully closed ^(check Task Manager^), then run this uninstaller again.
) else (
    echo Patch successfully removed
)

pause