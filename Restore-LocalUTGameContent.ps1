<#
.SYNOPSIS
    Restores and verifies the exact supplied content closure used by UTGame.

.DESCRIPTION
    Reads Required-LocalUTGameContent.txt, copies only missing packages from the
    supplied UDK Ultimate content tree, and SHA-256 verifies every destination.
    Existing files are never overwritten. A differing existing package is a
    hard failure so local edits cannot be silently replaced.

.EXAMPLE
    .\Restore-LocalUTGameContent.ps1

.EXAMPLE
    .\Restore-LocalUTGameContent.ps1 -VerifyOnly
#>
[CmdletBinding()]
param(
    [switch]$VerifyOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'Required-LocalUTGameContent.txt'
$sourceContentRoot = Join-Path $repoRoot 'UDKsource code and templates\UDK Ultimate\UDKGame\Content'
$destinationPrefix = 'UTGame\Content\'

function Get-Sha256Hash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Get-FileHash is not available in every supported Windows PowerShell
    # installation.  Use the .NET implementation directly so content-closure
    # verification remains mandatory on all supported hosts.
    $stream = $null
    $algorithm = $null
    try {
        $algorithm = [Security.Cryptography.SHA256]::Create()
        $stream = [IO.File]::OpenRead($Path)
        return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '')
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
        if ($null -ne $algorithm) {
            $algorithm.Dispose()
        }
    }
}

foreach ($requiredPath in @($manifestPath, $sourceContentRoot)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required content-restore input is missing: $requiredPath"
    }
}

$manifestEntries = @(
    Get-Content -LiteralPath $manifestPath |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') }
)
if ($manifestEntries.Count -eq 0) {
    throw "The required-content manifest is empty: $manifestPath"
}
if (@($manifestEntries | Sort-Object -Unique).Count -ne $manifestEntries.Count) {
    throw "The required-content manifest contains duplicate paths: $manifestPath"
}

$copiedCount = 0
$verifiedBytes = [long]0
foreach ($relativeDestination in $manifestEntries) {
    if (-not $relativeDestination.StartsWith($destinationPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Manifest path is outside UTGame\Content: $relativeDestination"
    }

    $contentRelativePath = $relativeDestination.Substring($destinationPrefix.Length)
    $sourcePath = Join-Path $sourceContentRoot $contentRelativePath
    $destinationPath = Join-Path $repoRoot $relativeDestination
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Supplied source package is missing: $sourcePath"
    }

    if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
        if ($VerifyOnly) {
            throw "Required destination package is missing: $destinationPath"
        }
        $destinationDirectory = Split-Path -Parent $destinationPath
        if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
            [void](New-Item -ItemType Directory -Path $destinationDirectory -Force)
        }
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath
        $copiedCount++
    }

    $sourceItem = Get-Item -LiteralPath $sourcePath
    $destinationItem = Get-Item -LiteralPath $destinationPath
    if ($sourceItem.Length -ne $destinationItem.Length) {
        throw "Size mismatch for required package: $relativeDestination"
    }

	$sourceHash = Get-Sha256Hash -Path $sourcePath
	$destinationHash = Get-Sha256Hash -Path $destinationPath
    if ($sourceHash -cne $destinationHash) {
        throw "SHA-256 mismatch for required package: $relativeDestination"
    }
    $verifiedBytes += $destinationItem.Length
}

Write-Host (
    'Required content closure verified: {0} packages, {1:N0} bytes, {2} copied.' -f
    $manifestEntries.Count,
    $verifiedBytes,
    $copiedCount
)
