# SpotifyPlus

Spotify Desktop enhancement toolkit for Windows, derived from SpotX.

## Requirements
- Windows 7-11
- Official Spotify Desktop app
- PowerShell 5.1+
- Microsoft Store version is not supported

## Features
- Spotify Desktop patching
- Ad blocking
- Optional content filtering
- Spotify update control
- Experimental feature tweaks
- Blocks Spotify's own built-in analytics/logging calls (see "Privacy & telemetry" below for SpotifyPlus's own optional reporting helper, which is a separate thing and is off by default)
- Advanced installation parameters

## Install
Run one of the included installers:
- Install_New_theme.bat
- Install_Old_theme.bat
- scripts\Install_Auto.bat
- scripts\Install_Prem.bat

Or run the patcher directly from PowerShell:

```powershell
.\run.ps1 -new_theme
```

## Uninstall
Run Uninstall.bat.

## Privacy & telemetry
By default, SpotifyPlus makes network requests only to Spotify's own servers, to `github.com`/`raw.githubusercontent.com` (this repository, to fetch patch instructions and helper scripts) and to `loadspot.amd64fox1.workers.dev` (a third-party mirror used to download the Spotify installer itself - see "Security" below for what that does and does not guarantee).

SpotifyPlus also ships an **optional, opt-in** helper, `checkVersion.js` (`-sendversion_on`), which is **disabled by default**. If you explicitly pass `-sendversion_on`, it will, inside the Spotify client:
1. Read the `Authorization` bearer token that the official Spotify client itself sends to `spclient.wg.spotify.com` (this is the Spotify client's own short-lived session token; SpotifyPlus does not use or need your Spotify password).
2. Use that token to call Spotify's own official update endpoint (`.../desktop-update/v2/update`) for Windows and macOS, x64 and arm64, to discover current installer/update download links.
3. Send the discovered links, this script's version, and basic client diagnostics (OS/user agent, detected Spotify app version, language, and which platform lookups succeeded or failed - **never the token value itself**, only a boolean flag noting whether one was found) to a third-party endpoint, `spotify-ingest-admin.amd64fox1.workers.dev`, operated by the upstream SpotX project. In an error/diagnostic ("forensic") path, this can also include the raw response body from Spotify's update endpoint for the request that failed.

This exists so that the shared version table this project (and other SpotX-family forks) rely on to find current Spotify installer links stays up to date, contributed by opted-in users. If you do not explicitly pass `-sendversion_on`, none of this runs and none of this data is sent. `-sendversion_off` still works as a deprecated no-op for backward compatibility, since "off" is now the default.

The `goofyHistory.js` helper (listening-history logging) is separately opt-in and requires you to supply your **own** destination (`-urlform_goofy`/`-idbox_goofy`, e.g. a Google Form you control) - SpotifyPlus and upstream SpotX have no access to that data.

## Security
- **Resource integrity:** run.ps1 fetches several files from this repository at runtime (installer language files, JS/CSS injected into the Spotify client, `patches.json`, the Russian translation augmentation, and `res/login.spa`). Every one of those is verified against a SHA-256 hash pinned inside run.ps1 itself before it is executed, injected into the Spotify client, or parsed as patch instructions. If a fetched file doesn't match, SpotifyPlus refuses to use it and tells you to get the latest run.ps1, instead of silently proceeding. See the "Resource integrity verification" comment near the top of run.ps1 for exactly how this works and its documented scope/limits, and `scripts/Update-IntegrityManifest.ps1` for how the pinned hashes are regenerated at release time.
- **What this does *not* cover:** the pinned-hash mechanism only applies to files hosted in *this* repository. It does not and cannot verify the third-party `LoaderSpot/table` version manifest, or the Spotify installer binary served from `loadspot.amd64fox1.workers.dev` - this repository has no authority to publish a trusted hash for content it doesn't own. Instead, the downloaded installer's size is compared against the size published in the version manifest as a best-effort check that catches truncated/corrupted downloads and wrong-asset swaps; it is **not** a cryptographic guarantee and cannot catch a same-size tampered file. If you need a stronger guarantee for a specific version, verify the downloaded installer independently before trusting it.
- **run.ps1 itself is not code-signed.** `Install_*.bat`/`Uninstall.bat` download run.ps1 over plain HTTPS and execute it with `-ExecutionPolicy Bypass`, with no separate signature check on run.ps1 itself. All of the integrity verification above is only as trustworthy as the copy of run.ps1 you started from. If you want to double-check what you're about to run, read it (it's plain text) or compare it against the copy published in this repository before running it.
- **Microsoft Defender exclusions:** unless you pass `-defender_exclusions_off`, run.ps1 adds the Spotify install folder, `Spotify.exe`, `Spotify.dll`, `chrome_elf.dll`, the patched `xpui.spa`, and the Spotify shortcuts as Microsoft Defender path exclusions, so real-time protection doesn't quarantine/corrupt a file mid-patch. This is scoped to those specific Spotify paths only - it does **not** exclude PowerShell or any other process. If you're not already running elevated, you'll be asked to confirm (Y/N) before anything is added, and a UAC prompt follows if you say yes.
- Found a security issue? See [SECURITY.md](SECURITY.md) for how to report it.

## Upstream
SpotifyPlus is derived from SpotX. The upstream MIT license and attribution are preserved in LICENSE. See UPSTREAM.md for details.

## Disclaimer
SpotifyPlus patches the official Spotify desktop client binaries and bundled JavaScript/CSS to remove ads and unlock certain experimental/premium-gated features. **This is a violation of Spotify's Terms of Service.** Spotify can detect client modification and may, at its discretion, take action against the account used with a patched client, up to and including suspension - this is a real, not theoretical, risk, independent of anything in "Security" above. Use it at your own risk and on an account you're prepared to lose. SpotifyPlus is not affiliated with, endorsed by, or supported by Spotify Technology S.A.
