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
- Future project-specific changes will be maintained separately from the upstream patch engine.

The upstream LICENSE file is preserved in this repository.
