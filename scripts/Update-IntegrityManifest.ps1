<#
.SYNOPSIS
    Regenerates the $script:IntegrityManifest hashtable embedded in run.ps1.

.DESCRIPTION
    Run this from anywhere in the repository (or pass -RepoRoot) before
    publishing a new release, whenever any tracked resource file below has
    changed, or whenever a new one is added. It computes the current SHA-256
    of every tracked file and rewrites the $script:IntegrityManifest
    assignment inside run.ps1 in place. The existing assignment is located
    precisely via the PowerShell AST, so this script will not accidentally
    touch anything else in run.ps1, and it re-parses run.ps1 after writing
    to confirm the result is still syntactically valid.

    If you add a new resource that run.ps1 fetches from this repository at
    runtime, add its relative path to $TrackedPaths below AND add a
    corresponding Assert-TrustedResource check at its fetch site in run.ps1.
    This script only keeps hash *values* current for paths it already knows
    about; it does not add new fetch/verification call sites for you.

.PARAMETER RepoRoot
    Path to the repository root. Defaults to the parent of this script's
    directory (i.e. assumes this script stays at scripts/Update-IntegrityManifest.ps1).

.PARAMETER CheckOnly
    Report whether the manifest is out of date (exit code 1) without writing
    anything. Useful in CI to catch a forgotten manifest update before merge.

.EXAMPLE
    scripts/Update-IntegrityManifest.ps1

.EXAMPLE
    scripts/Update-IntegrityManifest.ps1 -CheckOnly
#>

[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'

$RunPs1Path = Join-Path $RepoRoot 'run.ps1'

if (-not (Test-Path -LiteralPath $RunPs1Path -PathType Leaf)) {
    throw "run.ps1 not found at $RunPs1Path (wrong -RepoRoot?)"
}

# Every file run.ps1 fetches from THIS repository at runtime (via Get-Link
# with the default Owner/Repository) and verifies with Assert-TrustedResource.
# Keep the fixed entries here in sync with the fetch sites in run.ps1; the
# installer-lang entries are discovered automatically below.
$TrackedPaths = @(
    'js-helper/checkVersion.js'
    'js-helper/goofyHistory.js'
    'js-helper/sectionBlock.js'
    'css-helper/lyrics-color/colors.css'
    'css-helper/lyrics-color/rules.css'
    'patches/patches.json'
    'patches/Augmented translation/ru.json'
    'res/login.spa'
)

$langDir = Join-Path $RepoRoot 'scripts/installer-lang'
if (Test-Path -LiteralPath $langDir) {
    $langFiles = Get-ChildItem -LiteralPath $langDir -Filter '*.ps1' |
        Sort-Object Name |
        ForEach-Object { "scripts/installer-lang/$($_.Name)" }
    $TrackedPaths = @($TrackedPaths) + @($langFiles)
}

# Safety net: warn about files on disk, in directories that are supposed to
# be fully tracked, that aren't in $TrackedPaths. This does not fail the
# script (a new file might be intentionally not-yet-wired-up), but it is
# easy to miss otherwise.
$directoriesExpectedFullyTracked = @(
    'js-helper'
    'css-helper/lyrics-color'
)
foreach ($dir in $directoriesExpectedFullyTracked) {
    $full = Join-Path $RepoRoot $dir
    if (Test-Path -LiteralPath $full) {
        Get-ChildItem -LiteralPath $full -File | ForEach-Object {
            $rel = "$dir/$($_.Name)"
            if ($TrackedPaths -notcontains $rel) {
                Write-Warning "On disk but NOT in `$TrackedPaths (add it if run.ps1 should fetch+verify it): $rel"
            }
        }
    }
}

$missing = New-Object System.Collections.Generic.List[string]
$manifest = [ordered]@{}

foreach ($rel in $TrackedPaths) {
    $full = Join-Path $RepoRoot $rel
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $missing.Add($rel)
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($full)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha256.ComputeHash($bytes)
    }
    finally {
        $sha256.Dispose()
    }

    $sb = [System.Text.StringBuilder]::new($hashBytes.Length * 2)
    foreach ($b in $hashBytes) {
        [void]$sb.Append($b.ToString('x2'))
    }
    $manifest[$rel] = $sb.ToString()
}

if ($missing.Count -gt 0) {
    throw "`$TrackedPaths references file(s) that do not exist on disk:`n$($missing -join "`n")`nRemove them from `$TrackedPaths, or restore the files."
}

# Build the replacement hashtable literal text. Keys are sorted so the
# generated text (and its diff against the previous version) is stable and
# does not depend on filesystem enumeration order.
$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add('$script:IntegrityManifest = @{')
foreach ($key in ($manifest.Keys | Sort-Object)) {
    $escapedKey = $key.Replace("'", "''")
    [void]$lines.Add("    '$escapedKey' = '$($manifest[$key])'")
}
[void]$lines.Add('}')
$newLiteralText = ($lines -join "`n")

# Locate the existing assignment precisely via the AST.
$parseErrors = $null
$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($RunPs1Path, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors -and $parseErrors.Count -gt 0) {
    throw "run.ps1 currently has $($parseErrors.Count) parse error(s); refusing to touch it. Fix those first, then re-run this script."
}

$assignStmt = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left.Extent.Text -eq '$script:IntegrityManifest'
    }, $true)

if (-not $assignStmt) {
    throw "Could not find the `$script:IntegrityManifest assignment in run.ps1. Has it been renamed or removed?"
}

# Read raw bytes and decode manually (rather than Get-Content -Raw) so we
# know exactly what encoding we are dealing with, and can write back the
# same one. run.ps1 is UTF-8 without a byte order mark; introducing a BOM
# (which Set-Content -Encoding UTF8 does on Windows PowerShell 5.1) would
# make every future diff of this file noisy for no reason.
$originalBytes = [System.IO.File]::ReadAllBytes($RunPs1Path)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$originalText = $utf8NoBom.GetString($originalBytes)

$oldLiteralText = $assignStmt.Extent.Text

if ($oldLiteralText -eq $newLiteralText) {
    Write-Host "Integrity manifest is already up to date ($($manifest.Count) entries) - no changes needed." -ForegroundColor Green
    exit 0
}

if ($CheckOnly) {
    Write-Host "Integrity manifest is OUT OF DATE. Run this script without -CheckOnly to update it." -ForegroundColor Yellow
    exit 1
}

$startIndex = $originalText.IndexOf($oldLiteralText, [System.StringComparison]::Ordinal)
if ($startIndex -lt 0) {
    throw "Could not locate the exact text of the existing manifest assignment for replacement (unexpected - the file may use different line endings than the AST extent)."
}

$secondIndex = $originalText.IndexOf($oldLiteralText, $startIndex + 1, [System.StringComparison]::Ordinal)
if ($secondIndex -ge 0) {
    throw "The existing manifest assignment text is not unique in run.ps1; refusing to guess which occurrence to replace. Please update it manually this once."
}

$updatedText = $originalText.Substring(0, $startIndex) + $newLiteralText + $originalText.Substring($startIndex + $oldLiteralText.Length)

[System.IO.File]::WriteAllText($RunPs1Path, $updatedText, $utf8NoBom)

# Re-parse to make sure the edit didn't break anything.
$parseErrors2 = $null
$tokens2 = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($RunPs1Path, [ref]$tokens2, [ref]$parseErrors2)
if ($parseErrors2 -and $parseErrors2.Count -gt 0) {
    throw "run.ps1 has $($parseErrors2.Count) parse error(s) AFTER the update - this should not happen. The file has already been written; use git diff / git checkout to inspect or revert, then report this as a bug."
}

Write-Host "Updated `$script:IntegrityManifest in run.ps1 with $($manifest.Count) entries." -ForegroundColor Green
Write-Host "Review the diff (git diff run.ps1) and commit both the changed resource file(s) and run.ps1 together."
