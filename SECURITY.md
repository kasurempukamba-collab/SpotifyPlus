# Security Policy

## Supported versions

SpotifyPlus is a single rolling script, not a set of versioned releases:
`Install_*.bat`/`Uninstall.bat` always fetch the current `run.ps1` from the
`main` branch of this repository. Only that latest copy is supported -
there is no older branch that still receives security fixes, so "update"
simply means "run the installer again."

## Reporting a vulnerability

Please **do not** open a public issue or pull request that includes
exploit details, proof-of-concept code, or anything else that could help
someone abuse the problem before it's fixed.

Instead, use GitHub's private reporting for this repository:

1. Go to the **Security** tab of this repository.
2. Click **Report a vulnerability**.

If that option isn't available to you, open a regular issue asking to be
pointed to a private contact, without including any technical detail
about the issue itself, and a maintainer will follow up.

When reporting, it helps to include:

- What the issue is and why it matters (impact).
- Steps to reproduce it, or a minimal example.
- Which copy of `run.ps1` you tested against (commit hash or download
  date is enough).

## What's already documented

Before reporting something, it may already be a known, intentional
trade-off rather than a bug - see the [`Security` section of
README.md](README.md#security) and the "Resource integrity verification"
comment block near the top of `run.ps1` for the full, current threat
model: what the SHA-256 integrity manifest covers and doesn't, why
`run.ps1` itself isn't code-signed, and what the default Microsoft
Defender exclusions do and don't touch.

Separately, this project patches the official Spotify client to remove
ads/unlock features, which is a violation of Spotify's Terms of Service
and can get an account flagged or suspended - see the Disclaimer section
of README.md. That is a known, disclosed characteristic of the project
itself, not something to report here.
