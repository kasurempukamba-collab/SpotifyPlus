#Requires -Version 5.1
<#
    .SYNOPSIS
        Recomputes and (optionally) rewrites the SHA-256 hashes pinned in
        run.ps1's $script:IntegrityManifest.

    .DESCRIPTION
        run.ps1 downloads several files from this repository at runtime
        (css-helper/*, js-helper/*, patches/*, res/login.spa,
        scripts/installer-lang/*) and verifies each one's SHA-256 hash
        against a value pinned in $script:IntegrityManifest before it is
        ever executed, injected, or parsed (see Assert-TrustedResource in
        run.ps1). This script is the tool referenced by that manifest's
        comment block and by README "Security": it is how a maintainer
        regenerates those pinned hashes after intentionally changing one of
        the tracked files, and it is how CI or a maintainer can check that
        the pinned hashes still match what is actually on disk before a
        release ships.

        By default this script only REPORTS drift; it never modifies
        run.ps1 unless -Apply is passed. This is deliberate: a hash change
        should be a reviewed, intentional part of a commit, not a silent
        side effect of running a script.

        Adding a brand-new tracked resource is a manual, one-line edit by
        design: add 'relative/path' = '' as a new entry under
        $script:IntegrityManifest in run.ps1, then re-run this script with
        -Apply to fill in the real hash. Assert-TrustedResource already
        fails closed at runtime for any resource with no manifest entry
        (see its $expected -eq $null branch), so an accidentally-omitted
        new entry cannot silently bypass verification - it can only cause
        that one resource to be (safely) refused until the entry is added.

    .PARAMETER Apply
        Rewrite $script:IntegrityManifest in run.ps1 in place with freshly
        computed hashes for every entry whose file still exists on disk.
        Without this switch, the script only prints a report and exits
        with a non-zero code if drift was found (suitable for CI).

    .PARAMETER RemoveMissing
        Only meaningful together with -Apply. Also deletes manifest entries
        whose file no longer exists on disk. Off by default: a missing file
        is reported as an error either way, but the entry is left in place
        so a maintainer makes that removal a deliberate, reviewed decision
        rather than something this script decides on its own.

    .EXAMPLE
        pwsh ./scripts/Update-IntegrityManifest.ps1
        Reports drift only. Exit code 0 = manifest matches disk exactly.

    .EXAMPLE
        pwsh ./scripts/Update-IntegrityManifest.ps1 -Apply
        Recomputes and rewrites every hash that has drifted, then reports
        what changed. Review the resulting git diff before committing.
#>
[CmdletBinding()]
param (
    [switch]$Apply,
    [switch]$RemoveMissing
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Sha256Hex {
    <#
        Returns the lowercase hex SHA-256 digest of the given bytes.
        Intentionally identical to Get-Sha256Hex in run.ps1 so the hashes
        this script produces are guaranteed to match what run.ps1 itself
        will compute for the same bytes at runtime.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [byte[]]$Bytes
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha256.ComputeHash($Bytes)
        $sb = [System.Text.StringBuilder]::new($hashBytes.Length * 2)
        foreach ($b in $hashBytes) {
            [void]$sb.Append($b.ToString('x2'))
        }
        return $sb.ToString()
    }
    finally {
        $sha256.Dispose()
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$runPs1Path = Join-Path $repoRoot 'run.ps1'

if (-not (Test-Path -LiteralPath $runPs1Path -PathType Leaf)) {
    throw "Could not find run.ps1 at '$runPs1Path'. Run this script from its normal location at scripts/Update-IntegrityManifest.ps1 inside the repository."
}

$runPs1Text = Get-Content -LiteralPath $runPs1Path -Raw

$manifestMarker = '$script:IntegrityManifest = @{'
$manifestStart = $runPs1Text.IndexOf($manifestMarker, [System.StringComparison]::Ordinal)
if ($manifestStart -lt 0) {
    throw "Could not find '$manifestMarker' in run.ps1. Has it been renamed?"
}

$manifestBodyStart = $manifestStart + $manifestMarker.Length
$manifestEnd = $runPs1Text.IndexOf("`n}", $manifestBodyStart, [System.StringComparison]::Ordinal)
if ($manifestEnd -lt 0) {
    throw "Could not find the closing '}' of `$script:IntegrityManifest in run.ps1."
}

$manifestBody = $runPs1Text.Substring($manifestBodyStart, $manifestEnd - $manifestBodyStart)

# Ordered so re-emission preserves the exact order entries currently appear
# in, instead of re-sorting them (keeps future git diffs minimal).
$entries = [System.Collections.Specialized.OrderedDictionary]::new()
$entryPattern = [regex]"(?m)^\s*'([^']+)'\s*=\s*'([0-9a-f]{0,64})'\s*$"
foreach ($match in $entryPattern.Matches($manifestBody)) {
    $entries[$match.Groups[1].Value] = $match.Groups[2].Value
}

if ($entries.Count -eq 0) {
    throw 'Parsed zero entries out of $script:IntegrityManifest. Refusing to continue: either the manifest is genuinely empty, or the parser above no longer matches its format, and this script must not silently produce a truncated manifest either way.'
}

Write-Host "Found $($entries.Count) manifest entries in run.ps1." -ForegroundColor Cyan
Write-Host

$unchanged = New-Object System.Collections.Generic.List[string]
$changed = New-Object System.Collections.Generic.List[string]
$missing = New-Object System.Collections.Generic.List[string]
$newHashes = [System.Collections.Specialized.OrderedDictionary]::new()

foreach ($relativePath in $entries.Keys) {
    $expected = $entries[$relativePath]
    $diskPath = Join-Path $repoRoot $relativePath

    if (-not (Test-Path -LiteralPath $diskPath -PathType Leaf)) {
        Write-Host "MISSING   $relativePath (no longer exists on disk)" -ForegroundColor Yellow
        $missing.Add($relativePath)
        $newHashes[$relativePath] = $expected
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($diskPath)
    $actual = Get-Sha256Hex -Bytes $bytes

    if ($actual -eq $expected) {
        Write-Host "OK        $relativePath" -ForegroundColor DarkGray
        $unchanged.Add($relativePath)
        $newHashes[$relativePath] = $expected
    }
    else {
        Write-Host "CHANGED   $relativePath" -ForegroundColor Green
        Write-Host "  pinned : $expected" -ForegroundColor DarkGray
        Write-Host "  actual : $actual" -ForegroundColor DarkGray
        $changed.Add($relativePath)
        $newHashes[$relativePath] = $actual
    }
}

Write-Host
Write-Host "$($unchanged.Count) unchanged, $($changed.Count) changed, $($missing.Count) missing." -ForegroundColor Cyan

if (-not $Apply) {
    if ($changed.Count -gt 0 -or $missing.Count -gt 0) {
        Write-Host
        Write-Host 'Drift detected. Re-run with -Apply to rewrite the pinned hashes in run.ps1, then review the diff before committing.' -ForegroundColor Yellow
        exit 1
    }
    Write-Host 'run.ps1 manifest matches disk exactly. Nothing to do.' -ForegroundColor Green
    exit 0
}

if ($RemoveMissing -and $missing.Count -gt 0) {
    foreach ($relativePath in $missing) {
        $newHashes.Remove($relativePath)
    }
    Write-Host
    Write-Host "-RemoveMissing: dropped $($missing.Count) entr$(if ($missing.Count -eq 1) { 'y' } else { 'ies' }) for files that no longer exist." -ForegroundColor Yellow
}
elseif ($missing.Count -gt 0) {
    Write-Host
    Write-Host "$($missing.Count) missing entr$(if ($missing.Count -eq 1) { 'y was' } else { 'ies were' }) left in place with its previous hash (pass -RemoveMissing to drop them instead)." -ForegroundColor Yellow
}

if ($changed.Count -eq 0 -and $missing.Count -eq 0) {
    Write-Host
    Write-Host 'Nothing to write: run.ps1 already matches disk exactly.' -ForegroundColor Green
    exit 0
}

$newLines = foreach ($relativePath in $newHashes.Keys) {
    "    '$relativePath' = '$($newHashes[$relativePath])'"
}
# No trailing "`n" here: $runPs1Text.Substring($manifestEnd) below already
# starts at the "`n}" that closes the hashtable, so appending one here would
# leave a blank line before the closing brace on every -Apply rewrite.
$newManifestBody = "`n" + ($newLines -join "`n")

$newRunPs1Text = $runPs1Text.Substring(0, $manifestBodyStart) `
    + $newManifestBody `
    + $runPs1Text.Substring($manifestEnd)

# run.ps1 is authored/committed as UTF-8 without a byte-order mark; match
# that so this rewrite does not introduce a BOM or change line endings.
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($runPs1Path, $newRunPs1Text, $utf8NoBom)

Write-Host
Write-Host "Wrote $($changed.Count) updated hash(es) to run.ps1." -ForegroundColor Green
Write-Host 'Review the diff, then run the check_spotx workflow (or test locally) before publishing a release.' -ForegroundColor Green
