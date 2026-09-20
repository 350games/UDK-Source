<#
.SYNOPSIS
    Rebuilds and deploys the Win64 wxWidgets DLL set used by UDK.

.DESCRIPTION
    Builds the recovered wxWidgets 2.8 source with the Visual Studio 2022 x64
    compiler, verifies the complete Unicode Release DLL/PDB/import-library set,
    and deploys it to the paths consumed by the Win64 UDK build and runtime.

    The build is incremental, but every expected artifact is validated after
    nmake and every deployed file is SHA-256 compared with its source.

.EXAMPLE
    .\Build-WxWidgets.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Vs2022VcVars64Path {
    $vswhereCandidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\Installer\vswhere.exe')
    ) | Select-Object -Unique

    foreach ($vswhere in $vswhereCandidates) {
        if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
            continue
        }

        $installations = @(& $vswhere `
            -latest `
            -products '*' `
            -version '[17.0,18.0)' `
            -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
            -property installationPath 2>$null)
        if ($LASTEXITCODE -ne 0) {
            continue
        }

        foreach ($installation in $installations) {
            if ([string]::IsNullOrWhiteSpace($installation)) {
                continue
            }

            $candidate = Join-Path $installation.Trim() 'VC\Auxiliary\Build\vcvars64.bat'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return $candidate
            }
        }
    }

    foreach ($edition in @('BuildTools', 'Community', 'Professional', 'Enterprise')) {
        $candidate = Join-Path $env:ProgramFiles "Microsoft Visual Studio\2022\$edition\VC\Auxiliary\Build\vcvars64.bat"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    throw 'Visual Studio 2022 x64 C++ build tools were not found. Install the Desktop development with C++ workload.'
}

function Import-Vs2022VcEnvironment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VcVars64Path
    )

    if (-not [System.Environment]::Is64BitOperatingSystem) {
        throw 'The wxWidgets Win64 build requires a 64-bit Windows operating system.'
    }
    if (-not (Test-Path -LiteralPath $env:ComSpec -PathType Leaf)) {
        throw "The Windows command processor was not found: $env:ComSpec"
    }

    $environmentCommand = 'call "{0}" >nul && set' -f $VcVars64Path
    $environmentLines = @(& $env:ComSpec /d /s /c $environmentCommand)
    if ($LASTEXITCODE -ne 0) {
        throw "Visual Studio 2022 environment initialization failed with exit code $LASTEXITCODE."
    }

    foreach ($line in $environmentLines) {
        $separator = $line.IndexOf('=')
        # cmd.exe includes drive-current-directory entries such as '=C:=...'.
        if ($separator -le 0) {
            continue
        }

        $name = $line.Substring(0, $separator)
        $value = $line.Substring($separator + 1)
        [System.Environment]::SetEnvironmentVariable($name, $value, [System.EnvironmentVariableTarget]::Process)
    }

    if ($env:VisualStudioVersion -notlike '17.*' -or $env:VSCMD_ARG_TGT_ARCH -ne 'x64') {
        throw "vcvars64.bat initialized an unexpected toolchain (VisualStudioVersion='$env:VisualStudioVersion', target='$env:VSCMD_ARG_TGT_ARCH')."
    }

    $nmake = Get-Command 'nmake.exe' -ErrorAction SilentlyContinue
    if ($null -eq $nmake -or -not (Test-Path -LiteralPath $nmake.Source -PathType Leaf)) {
        throw 'nmake.exe was not found after initializing the Visual Studio 2022 x64 C++ environment.'
    }

    Write-Host "Using Visual Studio $env:VisualStudioVersion x64 tools from $VcVars64Path"
    return $nmake.Source
}

function Assert-NonEmptyFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description was not produced: $Path"
    }

    $item = Get-Item -LiteralPath $Path
    if ($item.Length -le 0) {
        throw "$Description is empty: $Path"
    }
}

function Assert-Win64PortableExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    Assert-NonEmptyFile -Path $Path -Description $Description

    $stream = $null
    try {
        $stream = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        if ($stream.Length -lt 64) {
            throw "$Description is too short to contain a PE header: $Path"
        }

        $dosHeader = New-Object byte[] 64
        if ($stream.Read($dosHeader, 0, $dosHeader.Length) -ne $dosHeader.Length -or
            $dosHeader[0] -ne [byte][char]'M' -or
            $dosHeader[1] -ne [byte][char]'Z') {
            throw "$Description does not have a valid DOS header: $Path"
        }

        $peOffset = [System.BitConverter]::ToInt32($dosHeader, 60)
        if ($peOffset -lt 0 -or $peOffset -gt ($stream.Length - 6)) {
            throw "$Description has an invalid PE header offset: $Path"
        }

        [void]$stream.Seek($peOffset, [System.IO.SeekOrigin]::Begin)
        $peHeader = New-Object byte[] 6
        if ($stream.Read($peHeader, 0, $peHeader.Length) -ne $peHeader.Length -or
            $peHeader[0] -ne [byte][char]'P' -or
            $peHeader[1] -ne [byte][char]'E' -or
            $peHeader[2] -ne 0 -or
            $peHeader[3] -ne 0) {
            throw "$Description does not have a valid PE signature: $Path"
        }

        $machine = [System.BitConverter]::ToUInt16($peHeader, 4)
        if ($machine -ne [uint16]0x8664) {
            throw ('{0} has COFF machine 0x{1:X4}; expected 0x8664 for Win64: {2}' -f $Description, $machine, $Path)
        }
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
}

function Get-Sha256Hash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Get-FileHash is not available in every supported Windows PowerShell
    # installation.  The dependency deployment must still verify every byte,
    # so use SHA-256 through the .NET runtime directly.
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

function Copy-VerifiedFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    Assert-NonEmptyFile -Path $Source -Description "$Description source"

    $destinationDirectory = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $destinationDirectory -Force)
    }

	$sourceHash = Get-Sha256Hash -Path $Source
    $copyRequired = $true
    if (Test-Path -LiteralPath $Destination) {
        if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
            throw "$Description destination is not a file: $Destination"
        }

		$destinationHash = Get-Sha256Hash -Path $Destination
        $copyRequired = $sourceHash -ne $destinationHash
        if ($copyRequired) {
            $attributes = [System.IO.File]::GetAttributes($Destination)
            $blockingAttributes = [System.IO.FileAttributes]::ReadOnly -bor [System.IO.FileAttributes]::System
            if (($attributes -band $blockingAttributes) -ne 0) {
                $remainingAttributes = [int]$attributes -band (-bnot [int]$blockingAttributes)
                [System.IO.File]::SetAttributes($Destination, [System.IO.FileAttributes]$remainingAttributes)
            }
        }
    }

    if ($copyRequired) {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }

    Assert-NonEmptyFile -Path $Destination -Description "$Description destination"
	$deployedHash = Get-Sha256Hash -Path $Destination
    if ($deployedHash -ne $sourceHash) {
        throw "$Description failed SHA-256 verification after deployment: $Destination"
    }

    $action = if ($copyRequired) { 'Deployed' } else { 'Verified current' }
    Write-Host "$action ${Description}: $Destination"
}

$repoRoot = $PSScriptRoot
$wxRoot = Join-Path $repoRoot 'Development\External\wxWidgets'
$buildDirectory = Join-Path $wxRoot 'build\msw'
$makefile = Join-Path $buildDirectory 'makefile.vc'
$setupSource = Join-Path $wxRoot 'include\wx\msw\setup.h'
$outputDirectory = Join-Path $wxRoot 'lib\vc_amd64_dll_ue3v143'
$setupDestination = Join-Path $outputDirectory 'mswu\wx\setup.h'
$runtimeDirectory = Join-Path $repoRoot 'Binaries\Win64'
$importLibraryDirectory = Join-Path $wxRoot 'lib\vc_dll\x64'

$dllNames = @(
    'wxbase28u_vc_custom_64.dll',
    'wxbase28u_net_vc_custom_64.dll',
    'wxbase28u_xml_vc_custom_64.dll',
    'wxmsw28u_core_vc_custom_64.dll',
    'wxmsw28u_adv_vc_custom_64.dll',
    'wxmsw28u_aui_vc_custom_64.dll',
    'wxmsw28u_html_vc_custom_64.dll',
    'wxmsw28u_media_vc_custom_64.dll',
    'wxmsw28u_qa_vc_custom_64.dll',
    'wxmsw28u_richtext_vc_custom_64.dll',
    'wxmsw28u_xrc_vc_custom_64.dll'
)

$importLibraryMap = @(
    [pscustomobject]@{ Source = 'wxbase28u.lib'; Destination = 'wxmsw28u_64.lib' },
    [pscustomobject]@{ Source = 'wxbase28u_net.lib'; Destination = 'wxmsw28u_net_64.lib' },
    [pscustomobject]@{ Source = 'wxbase28u_xml.lib'; Destination = 'wxmsw28u_xml_64.lib' },
    [pscustomobject]@{ Source = 'wxmsw28u_core.lib'; Destination = 'wxmsw28u_core_64.lib' },
    [pscustomobject]@{ Source = 'wxmsw28u_adv.lib'; Destination = 'wxmsw28u_adv_64.lib' },
    [pscustomobject]@{ Source = 'wxmsw28u_aui.lib'; Destination = 'wxmsw28u_aui_64.lib' },
    [pscustomobject]@{ Source = 'wxmsw28u_html.lib'; Destination = 'wxmsw28u_html_64.lib' },
    [pscustomobject]@{ Source = 'wxmsw28u_media.lib'; Destination = 'wxmsw28u_media_64.lib' },
    [pscustomobject]@{ Source = 'wxmsw28u_qa.lib'; Destination = 'wxmsw28u_qa_64.lib' },
    [pscustomobject]@{ Source = 'wxmsw28u_richtext.lib'; Destination = 'wxmsw28u_richtext_64.lib' },
    [pscustomobject]@{ Source = 'wxmsw28u_xrc.lib'; Destination = 'wxmsw28u_xrc_64.lib' }
)

foreach ($requiredInput in @($wxRoot, $buildDirectory, $makefile, $setupSource)) {
    if (-not (Test-Path -LiteralPath $requiredInput)) {
        throw "Required wxWidgets build input was not found: $requiredInput"
    }
}

$buildMutex = [System.Threading.Mutex]::new($false, 'Local\UnrealEngine3SC.WxWidgetsBuild')
$ownsBuildMutex = $false

try {
    try {
        $ownsBuildMutex = $buildMutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        $ownsBuildMutex = $true
    }

    if (-not $ownsBuildMutex) {
        throw 'Another Build-WxWidgets.ps1 invocation is already building or deploying this wxWidgets tree.'
    }

    Copy-VerifiedFile -Source $setupSource -Destination $setupDestination -Description 'wxWidgets x64 setup header'

    $vcVars64 = Get-Vs2022VcVars64Path
    $nmake = Import-Vs2022VcEnvironment -VcVars64Path $vcVars64
    $nmakeArguments = @(
        '/nologo',
        '-f',
        'makefile.vc',
        'SHARED=1',
        'UNICODE=1',
        'BUILD=release',
        'TARGET_CPU=amd64',
        'VENDOR=custom_64',
        'CFG=_ue3v143',
        'DEBUG_INFO=1',
        'CPPFLAGS=/DwxUSE_UNICODE=1'
    )

    Write-Host "`nBuilding the complete wxWidgets x64 Unicode Release DLL graph"
    Push-Location -LiteralPath $buildDirectory
    try {
        & $nmake @nmakeArguments
        if ($LASTEXITCODE -ne 0) {
            throw "wxWidgets x64 build failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }

    foreach ($dllName in $dllNames) {
        $dllSource = Join-Path $outputDirectory $dllName
        $pdbName = [System.IO.Path]::ChangeExtension($dllName, '.pdb')
        $pdbSource = Join-Path $outputDirectory $pdbName

        Assert-Win64PortableExecutable -Path $dllSource -Description "wxWidgets DLL $dllName"
        Assert-NonEmptyFile -Path $pdbSource -Description "wxWidgets symbols $pdbName"
        Copy-VerifiedFile -Source $dllSource -Destination (Join-Path $runtimeDirectory $dllName) -Description "wxWidgets DLL $dllName"
        Copy-VerifiedFile -Source $pdbSource -Destination (Join-Path $runtimeDirectory $pdbName) -Description "wxWidgets symbols $pdbName"
    }

    foreach ($mapping in $importLibraryMap) {
        $librarySource = Join-Path $outputDirectory $mapping.Source
        $libraryDestination = Join-Path $importLibraryDirectory $mapping.Destination
        Copy-VerifiedFile -Source $librarySource -Destination $libraryDestination -Description "wxWidgets import library $($mapping.Destination)"
    }

    Write-Host "`nwxWidgets x64 build and deployment completed successfully. All 11 DLLs, PDBs, and UBT import libraries passed verification."
}
finally {
    if ($ownsBuildMutex) {
        [void]$buildMutex.ReleaseMutex()
    }
    $buildMutex.Dispose()
}
