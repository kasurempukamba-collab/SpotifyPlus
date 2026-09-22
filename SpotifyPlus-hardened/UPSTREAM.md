# Upstream

SpotifyPlus is based on the Windows version of SpotX.

- Upstream: https://github.com/SpotX-Official/SpotX
- License: MIT
- Original copyright: Copyright (c) 2021-2026 amd64fox

## Changes in SpotifyPlus

- Rebranded the Windows project as SpotifyPlus.
- Changed installer bootstrap URLs to the SpotifyPlus repository.
- Added SpotifyPlus-specific documentation.
- Added resource integrity verification (SHA-256 pinning) for every file run.ps1 fetches from this repository at runtime, a best-effort size check for the downloaded Spotify installer, and made the `checkVersion.js` version-reporting helper opt-in (`-sendversion_on`) instead of opt-out. These are SpotifyPlus-specific hardening changes not present upstream; see README "Security" and "Privacy & telemetry". They do not change what any patch does to the Spotify client, only how run.ps1 fetches and verifies the code/instructions that implement those patches.
- Follow-up hardening pass: scoped the default Microsoft Defender exclusion down to the specific Spotify paths it was meant for and removed the broader `-ExclusionProcess` entry it was also adding for the currently-running `powershell.exe` (which could reduce real-time scanning for anything else later run through that same shared system binary, not just this install); added `scripts/Update-IntegrityManifest.ps1`, the maintainer tool that regenerates the pinned hashes described above (previously referenced by the manifest's own comments and by README but not actually committed); fixed `Uninstall.bat` reporting success even when a restore step silently failed; pinned the two third-party GitHub Actions used in this repo's workflows to a specific commit instead of a mutable version tag; corrected the auto-close-issue workflow's maintainer allowlist and its "mention us" message, both of which still pointed at the upstream author instead of this fork; and added `SECURITY.md` plus a report-only PSScriptAnalyzer CI check.
- Future project-specific changes will be maintained separately from the upstream patch engine.

The upstream LICENSE file is preserved in this repository.
