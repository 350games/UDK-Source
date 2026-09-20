<#
.SYNOPSIS
    Read-only preflight for the recovered local UTGame runtime.

.DESCRIPTION
    Verifies that one or more native UTGame executables exist and checks the
    source-built script package set that the local runtime must load. With
    -RequireAllNativeOutputs it also verifies the editor and build-tool
    executables, their architecture-specific app-local dependencies, managed
    Swarm outputs, and retained binary content required by the recovered
    runtime. By default it also checks UnrealEd.u, which is required by the
    source-built editor; use -RuntimeOnly to omit that editor-package check.
    It reads executable metadata and package headers only and never launches a
    process, copies payloads, or changes the workspace.

    The UDK Game and UDK Ultimate trees are inspected only as references.
    Their supplied package headers are reported as incompatible with this
    local engine when their version or licensee version is outside the values
    supported by the authoritative Development\Src build.

.EXAMPLE
    .\Test-LocalUTGameRuntime.ps1

.EXAMPLE
    .\Test-LocalUTGameRuntime.ps1 -Platform Win32 -Configuration Release -RequireAllNativeOutputs

.EXAMPLE
    .\Test-LocalUTGameRuntime.ps1 -Platform Win64 -RuntimeOnly
#>
[CmdletBinding()]
param(
    [ValidateSet('Win32', 'Win64', 'All')]
    [string]$Platform = 'All',

    [ValidateSet('Release', 'Debug', 'Shipping')]
    [string[]]$Configuration = @('Release'),

    [switch]$RequireAllNativeOutputs,

    [switch]$RuntimeOnly,

    [string]$ReferenceRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$defaultReferenceRoots = @(
    (Join-Path $repoRoot 'UDKsource code and templates'),
    (Join-Path $repoRoot 'UDK')
)
if ([string]::IsNullOrWhiteSpace($ReferenceRoot)) {
    $ReferenceRoot = $defaultReferenceRoots | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
}
$runtimePackages = @(
    'Core.u',
    'Engine.u',
    'GFxUI.u',
    'IpDrv.u',
    'GameFramework.u',
    'WinDrv.u',
    'OnlineSubsystemPC.u',
    'UTGame.u',
    'UDKStarter.u'
)
$requiredPackages = if ($RuntimeOnly) {
    $runtimePackages
}
else {
    @(
        'Core.u',
        'Engine.u',
        'GFxUI.u',
        'IpDrv.u',
        'GameFramework.u',
        'UnrealEd.u',
        'WinDrv.u',
        'OnlineSubsystemPC.u',
        'UTGame.u',
        'UDKStarter.u'
    )
}

function Write-Check {
    param(
        [Parameter(Mandatory = $true)]
        [string]$State,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ('[{0}] {1}' -f $State, $Message)
}

function Get-LastEnginePackageVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HeaderPath
    )

    # VER_LATEST_ENGINE is the enum value immediately before
    # VER_AUTOMATIC_VERSION_PLUS_ONE. Track the enum rather than duplicating
    # the current value in this script.
    $values = @{}
    $currentValue = $null
    $foundMarker = $false

    foreach ($rawLine in Get-Content -LiteralPath $HeaderPath) {
        $line = ($rawLine -replace '//.*$', '').Trim()
        if ($line -notmatch '^(VER_[A-Za-z0-9_]+)\s*(?:=\s*([^,]+))?\s*,?$') {
            continue
        }

        $name = $Matches[1]
        $expression = $Matches[2]
        if ($name -eq 'VER_AUTOMATIC_VERSION_PLUS_ONE') {
            $foundMarker = $true
            break
        }

        if ([string]::IsNullOrWhiteSpace($expression)) {
            if ($null -eq $currentValue) {
                continue
            }
            $currentValue++
        }
        else {
            $expression = $expression.Trim()
            if ($expression -match '^\d+$') {
                $currentValue = [int]$expression
            }
            elseif ($values.ContainsKey($expression)) {
                $currentValue = [int]$values[$expression]
            }
            else {
                # The version list contains aliases for earlier names. If an
                # unfamiliar expression is introduced, fail closed rather than
                # claiming compatibility with an unknown build.
                $currentValue = $null
                continue
            }
        }

        $values[$name] = $currentValue
    }

    if (-not $foundMarker -or $null -eq $currentValue) {
        throw "Unable to derive VER_LATEST_ENGINE from $HeaderPath."
    }

    return [int]$currentValue
}

function Get-EnginePackageCompatibility {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $versionSource = Join-Path $Root 'Development\Src\Core\Src\UnObjVer.cpp'
    $versionHeader = Join-Path $Root 'Development\Src\Core\Inc\UnObjVer.h'
    foreach ($path in @($versionSource, $versionHeader)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required engine version source was not found: $path"
        }
    }

    $sourceText = Get-Content -Raw -LiteralPath $versionSource
    $headerText = Get-Content -Raw -LiteralPath $versionHeader
    $engineVersionMatch = [regex]::Match($sourceText, '(?m)^\s*#define\s+ENGINE_VERSION\s+(\d+)\s*$')
    $minimumVersionMatch = [regex]::Match($sourceText, 'GPackageFileMinVersion\s*=\s*(\d+)')
    $licenseeVersionMatch = [regex]::Match($headerText, '(?m)^\s*#define\s+VER_LATEST_ENGINE_LICENSEE\s+(\d+)\s*$')

    if (-not $engineVersionMatch.Success -or -not $minimumVersionMatch.Success -or -not $licenseeVersionMatch.Success) {
        throw 'Unable to read the local engine package compatibility values.'
    }

    return [pscustomobject]@{
        EngineVersion          = [int]$engineVersionMatch.Groups[1].Value
        MinimumPackageVersion  = [int]$minimumVersionMatch.Groups[1].Value
        MaximumPackageVersion  = Get-LastEnginePackageVersion -HeaderPath $versionHeader
        MaximumLicenseeVersion = [int]$licenseeVersionMatch.Groups[1].Value
    }
}

function Get-UnrealPackageHeader {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $stream = $null
    try {
        $stream = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        $bytes = New-Object byte[] 12
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $read = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($read -le 0) {
                break
            }
            $offset += $read
        }

        if ($offset -ne $bytes.Length) {
            return [pscustomobject]@{
                IsReadable      = $false
                Tag             = $null
                PackageVersion  = $null
                LicenseeVersion = $null
                Error           = 'The file is shorter than the 12-byte Unreal package header.'
            }
        }

        # UE3 stores the package version and licensee version together in the
        # 32-bit FileVersion field.  The next DWORD is TotalHeaderSize, not a
        # licensee version (see FPackageFileSummary in Core/Inc/UnLinker.h).
        $packedFileVersion = [System.BitConverter]::ToUInt32($bytes, 4)

        return [pscustomobject]@{
            IsReadable      = $true
            Tag             = [System.BitConverter]::ToUInt32($bytes, 0)
            PackageVersion  = [int]($packedFileVersion -band 0xffff)
            LicenseeVersion = [int](($packedFileVersion -shr 16) -band 0xffff)
            Error           = $null
        }
    }
    catch {
        return [pscustomobject]@{
            IsReadable      = $false
            Tag             = $null
            PackageVersion  = $null
            LicenseeVersion = $null
            Error           = $_.Exception.Message
        }
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
}

function Test-PackageHeader {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [psobject]$Compatibility
    )

    $header = Get-UnrealPackageHeader -Path $Path
    $reasons = New-Object System.Collections.Generic.List[string]
    $expectedTag = [Convert]::ToUInt32('9E2A83C1', 16)

    if (-not $header.IsReadable) {
        [void]$reasons.Add($header.Error)
    }
    else {
        if ($header.Tag -ne $expectedTag) {
            [void]$reasons.Add(('tag 0x{0:X8} is not 0x{1:X8}' -f $header.Tag, $expectedTag))
        }
        if ($header.PackageVersion -lt $Compatibility.MinimumPackageVersion -or $header.PackageVersion -gt $Compatibility.MaximumPackageVersion) {
            [void]$reasons.Add(('package version {0} is outside {1}..{2}' -f $header.PackageVersion, $Compatibility.MinimumPackageVersion, $Compatibility.MaximumPackageVersion))
        }
        if ($header.LicenseeVersion -gt $Compatibility.MaximumLicenseeVersion) {
            [void]$reasons.Add(('licensee version {0} exceeds {1}' -f $header.LicenseeVersion, $Compatibility.MaximumLicenseeVersion))
        }
    }

    return [pscustomobject]@{
        Header       = $header
        IsCompatible = ($reasons.Count -eq 0)
        Reasons      = @($reasons)
    }
}

function Get-NativeOutputPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [ValidateSet('UTGame', 'UDK', 'UTGameScriptCompiler', 'UE3ShaderCompileWorker', 'UnrealLightmass')]
        [string]$Target,

        [Parameter(Mandatory = $true)]
        [string]$TargetPlatform,

        [Parameter(Mandatory = $true)]
        [string]$TargetConfiguration
    )

    $name = if ($TargetConfiguration -eq 'Release') {
        "$Target.exe"
    }
    else {
        '{0}-{1}-{2}.exe' -f $Target, $TargetPlatform, $TargetConfiguration
    }
    return Join-Path $Root (Join-Path (Join-Path 'Binaries' $TargetPlatform) $name)
}

function Test-NativeOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Win32', 'Win64')]
        [string]$TargetPlatform
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{
            Exists              = $false
            IsPE                = $false
            ArchitectureMatches = $false
            Machine             = $null
            MachineName         = $null
            Size                = 0
            Error               = 'not built'
        }
    }

    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $dosHeader = New-Object byte[] 64
            $read = $stream.Read($dosHeader, 0, $dosHeader.Length)
            $isPE = $false
            $machine = $null
            if ($read -eq $dosHeader.Length -and $dosHeader[0] -eq [byte][char]'M' -and $dosHeader[1] -eq [byte][char]'Z') {
                $peOffset = [System.BitConverter]::ToInt32($dosHeader, 60)
                if ($peOffset -ge $dosHeader.Length -and $peOffset -le ($stream.Length - 6)) {
                    [void]$stream.Seek($peOffset, [System.IO.SeekOrigin]::Begin)
                    $peHeader = New-Object byte[] 6
                    $headerRead = $stream.Read($peHeader, 0, $peHeader.Length)
                    $isPE = $headerRead -eq $peHeader.Length -and
                        $peHeader[0] -eq [byte][char]'P' -and
                        $peHeader[1] -eq [byte][char]'E' -and
                        $peHeader[2] -eq 0 -and
                        $peHeader[3] -eq 0
                    if ($isPE) {
                        $machine = [System.BitConverter]::ToUInt16($peHeader, 4)
                    }
                }
            }
        }
        finally {
            $stream.Dispose()
        }

        $expectedMachine = if ($TargetPlatform -eq 'Win64') { [uint16]0x8664 } else { [uint16]0x014c }
        $machineName = if ($null -eq $machine) {
            'unknown'
        }
        elseif ($machine -eq 0x014c) {
            'x86'
        }
        elseif ($machine -eq 0x8664) {
            'x64'
        }
        else {
            '0x{0:X4}' -f $machine
        }
        $item = Get-Item -LiteralPath $Path
        return [pscustomobject]@{
            Exists              = $true
            IsPE                = $isPE
            ArchitectureMatches = ($isPE -and $machine -eq $expectedMachine)
            Machine             = $machine
            MachineName         = $machineName
            Size                = $item.Length
            Error               = if ($isPE) { $null } else { 'invalid DOS/PE or COFF header' }
        }
    }
    catch {
        return [pscustomobject]@{
            Exists              = $true
            IsPE                = $false
            ArchitectureMatches = $false
            Machine             = $null
            MachineName         = 'unknown'
            Size                = 0
            Error               = $_.Exception.Message
        }
    }
}

function Test-ManagedAssembly {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedName
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ Exists = $false; IsValid = $false; Name = $null; Version = $null; Size = 0; Error = 'not built' }
    }

    try {
        # GetAssemblyName reads the CLR metadata without loading or executing
        # the assembly in this PowerShell process.
        $assemblyName = [System.Reflection.AssemblyName]::GetAssemblyName($Path)
        $item = Get-Item -LiteralPath $Path
        $nameMatches = $assemblyName.Name -ceq $ExpectedName
        return [pscustomobject]@{
            Exists  = $true
            IsValid = ($nameMatches -and $item.Length -gt 0)
            Name    = $assemblyName.Name
            Version = $assemblyName.Version
            Size    = $item.Length
            Error   = if ($nameMatches) { $null } else { "assembly name '$($assemblyName.Name)' does not match '$ExpectedName'" }
        }
    }
    catch {
        return [pscustomobject]@{ Exists = $true; IsValid = $false; Name = $null; Version = $null; Size = 0; Error = $_.Exception.Message }
    }
}

try {
    $compatibility = Get-EnginePackageCompatibility -Root $repoRoot
}
catch {
    Write-Error $_.Exception.Message
    exit 2
}

$targetPlatforms = if ($Platform -eq 'All') { @('Win32', 'Win64') } else { @($Platform) }
$targetConfigurations = @($Configuration | Select-Object -Unique)
$failed = $false
$validNativeOutputCount = 0

Write-Host 'Local UTGame runtime preflight (read-only; no launch or copy operations).'
Write-Host (
    'Supported local package header: tag=0x9E2A83C1, package version {0}..{1}, licensee version <= {2} (engine {3}).' -f
    $compatibility.MinimumPackageVersion,
    $compatibility.MaximumPackageVersion,
    $compatibility.MaximumLicenseeVersion,
    $compatibility.EngineVersion
)

Write-Host "`nNative outputs:"
$nativeOutputs = New-Object System.Collections.Generic.List[object]
foreach ($targetPlatform in $targetPlatforms) {
    foreach ($targetConfiguration in $targetConfigurations) {
        foreach ($target in $(if ($RequireAllNativeOutputs) { @('UTGame', 'UDK') } else { @('UTGame') })) {
            [void]$nativeOutputs.Add([pscustomobject]@{
                Target        = $target
                Platform      = $targetPlatform
                Configuration = $targetConfiguration
                Required      = [bool]$RequireAllNativeOutputs
            })
        }
    }

    if ($RequireAllNativeOutputs) {
        foreach ($target in @('UTGameScriptCompiler', 'UE3ShaderCompileWorker', 'UnrealLightmass')) {
            [void]$nativeOutputs.Add([pscustomobject]@{
                Target        = $target
                Platform      = $targetPlatform
                Configuration = 'Release'
                Required      = $true
            })
        }
    }
}

foreach ($nativeOutput in $nativeOutputs) {
    $path = Get-NativeOutputPath `
        -Root $repoRoot `
        -Target $nativeOutput.Target `
        -TargetPlatform $nativeOutput.Platform `
        -TargetConfiguration $nativeOutput.Configuration
    $result = Test-NativeOutput -Path $path -TargetPlatform $nativeOutput.Platform
    $displayPath = $path.Substring($repoRoot.Length + 1)
    if ($result.Exists -and $result.IsPE -and $result.ArchitectureMatches -and $result.Size -gt 0) {
        if ($nativeOutput.Target -eq 'UTGame') {
            $validNativeOutputCount++
        }
        Write-Check -State 'PASS' -Message ("{0}: {1} PE ({2:N0} bytes)" -f $displayPath, $result.MachineName, $result.Size)
    }
    elseif ($result.Exists -and $result.IsPE) {
        $failed = $true
        $expectedMachine = if ($nativeOutput.Platform -eq 'Win64') { 'x64/0x8664' } else { 'x86/0x014C' }
        Write-Check -State 'FAIL' -Message (
            "{0}: architecture is {1}/0x{2:X4}, expected {3}" -f
            $displayPath, $result.MachineName, $result.Machine, $expectedMachine
        )
    }
    elseif ($result.Exists) {
        $failed = $true
        Write-Check -State 'FAIL' -Message ("{0}: not a readable PE executable ({1})" -f $displayPath, $result.Error)
    }
    elseif ($nativeOutput.Required) {
        $failed = $true
        Write-Check -State 'FAIL' -Message ("{0}: {1}" -f $displayPath, $result.Error)
    }
    else {
        Write-Check -State 'INFO' -Message ("{0}: not built for this optional configuration" -f $displayPath)
    }
}

if ($validNativeOutputCount -eq 0) {
    $failed = $true
    Write-Check -State 'FAIL' -Message 'No valid native UTGame executable was found for the selected platform/configuration.'
}

if ($RequireAllNativeOutputs -and $targetPlatforms -contains 'Win64') {
    # These are the app-local portion of the Win64 import closure for UDK and
    # the script compiler. Operating-system and VC-runtime DLLs are
    # intentionally outside this workspace preflight; the recovered target
    # also compiles PhysX/APEX out with WITH_NOVODEX=0 and WITH_APEX=0.
    $requiredWin64NativeDlls = @(
        'dbghelp.dll',
        'EasyHook64.dll',
        'nvtt_64.dll',
        'wxbase28u_vc_custom_64.dll',
        'wxbase28u_net_vc_custom_64.dll',
        'wxbase28u_xml_vc_custom_64.dll',
        'wxmsw28u_adv_vc_custom_64.dll',
        'wxmsw28u_aui_vc_custom_64.dll',
        'wxmsw28u_core_vc_custom_64.dll',
        'wxmsw28u_html_vc_custom_64.dll',
        'wxmsw28u_media_vc_custom_64.dll',
        'wxmsw28u_qa_vc_custom_64.dll',
        'wxmsw28u_richtext_vc_custom_64.dll',
        'wxmsw28u_xrc_vc_custom_64.dll'
    )

    Write-Host "`nRequired Win64 app-local native DLLs:"
    $win64BinaryDirectory = Join-Path $repoRoot 'Binaries\Win64'
    foreach ($fileName in $requiredWin64NativeDlls) {
        $path = Join-Path $win64BinaryDirectory $fileName
        $result = Test-NativeOutput -Path $path -TargetPlatform 'Win64'
        $displayPath = $path.Substring($repoRoot.Length + 1)
        if ($result.Exists -and $result.IsPE -and $result.ArchitectureMatches -and $result.Size -gt 0) {
            Write-Check -State 'PASS' -Message ("{0}: x64 PE ({1:N0} bytes)" -f $displayPath, $result.Size)
        }
        elseif ($result.Exists -and $result.IsPE) {
            $failed = $true
            Write-Check -State 'FAIL' -Message (
                "{0}: architecture is {1}/0x{2:X4}, expected x64/0x8664" -f
                $displayPath, $result.MachineName, $result.Machine
            )
        }
        else {
            $failed = $true
            Write-Check -State 'FAIL' -Message ("{0}: {1}" -f $displayPath, $result.Error)
        }
    }
}

if ($RequireAllNativeOutputs) {
    $managedOutputs = New-Object System.Collections.Generic.List[object]
    foreach ($output in @(
        [pscustomobject]@{ RelativePath = 'Binaries\AgentInterface.dll'; ExpectedName = 'AgentInterface' },
        [pscustomobject]@{ RelativePath = 'Binaries\SwarmAgent.exe'; ExpectedName = 'SwarmAgent' },
        [pscustomobject]@{ RelativePath = 'Binaries\SwarmCoordinatorInterface.dll'; ExpectedName = 'SwarmCoordinatorInterface' },
        [pscustomobject]@{ RelativePath = 'Binaries\UnrealControls.dll'; ExpectedName = 'UnrealControls' }
    )) {
        [void]$managedOutputs.Add($output)
    }
    foreach ($targetPlatform in $targetPlatforms) {
        [void]$managedOutputs.Add([pscustomobject]@{
            RelativePath = "Binaries\$targetPlatform\AgentInterface.dll"
            ExpectedName = 'AgentInterface'
        })
    }

    Write-Host "`nRequired managed Swarm outputs:"
    foreach ($managedOutput in $managedOutputs) {
        $path = Join-Path $repoRoot $managedOutput.RelativePath
        $result = Test-ManagedAssembly -Path $path -ExpectedName $managedOutput.ExpectedName
        if ($result.IsValid) {
            Write-Check -State 'PASS' -Message (
                "{0}: managed assembly {1}, version {2} ({3:N0} bytes)" -f
                $managedOutput.RelativePath, $result.Name, $result.Version, $result.Size
            )
        }
        else {
            $failed = $true
            Write-Check -State 'FAIL' -Message ("{0}: {1}" -f $managedOutput.RelativePath, $result.Error)
        }
    }

    $swarmAgentConfigPath = Join-Path $repoRoot 'Binaries\SwarmAgent.exe.config'
    if ((Test-Path -LiteralPath $swarmAgentConfigPath -PathType Leaf) -and (Get-Item -LiteralPath $swarmAgentConfigPath).Length -gt 0) {
        Write-Check -State 'PASS' -Message 'Binaries\SwarmAgent.exe.config: present and nonempty'
    }
    else {
        $failed = $true
        Write-Check -State 'FAIL' -Message 'Binaries\SwarmAgent.exe.config: missing or empty'
    }

    Write-Host "`nRequired retained binary content packages:"
    $requiredContentPackages = @(
        'Engine\Content\Engine_MI_Shaders.upk',
        'UTGame\Content\SoundClassesAndModes.upk',
        'UTGame\Content\PhysicalMaterials.upk'
    )
    $contentManifestPath = Join-Path $repoRoot 'Required-LocalUTGameContent.txt'
    if (-not (Test-Path -LiteralPath $contentManifestPath -PathType Leaf)) {
        $failed = $true
        Write-Check -State 'FAIL' -Message 'Required-LocalUTGameContent.txt: missing'
    }
    else {
        $manifestContentPackages = @(
            Get-Content -LiteralPath $contentManifestPath |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -and -not $_.StartsWith('#') }
        )
        $requiredContentPackages += $manifestContentPackages
    }
    foreach ($relativePath in $requiredContentPackages) {
        $path = Join-Path $repoRoot $relativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $failed = $true
            Write-Check -State 'FAIL' -Message ("{0}: missing" -f $relativePath)
            continue
        }

        $result = Test-PackageHeader -Path $path -Compatibility $compatibility
        if ($result.IsCompatible) {
            Write-Check -State 'PASS' -Message (
                "{0}: tag=0x{1:X8}, package={2}, licensee={3}" -f
                $relativePath,
                $result.Header.Tag,
                $result.Header.PackageVersion,
                $result.Header.LicenseeVersion
            )
        }
        else {
            $failed = $true
            Write-Check -State 'FAIL' -Message ("{0}: {1}" -f $relativePath, ($result.Reasons -join '; '))
        }
    }

    $contentRoots = @(
        (Join-Path $repoRoot 'Engine\Content'),
        (Join-Path $repoRoot 'UTGame\Content')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Container }
    $announcerPackages = @(
        $contentRoots | ForEach-Object {
            Get-ChildItem -LiteralPath $_ -Filter '*Announcer*.upk' -File -Recurse -ErrorAction SilentlyContinue
        } | Sort-Object FullName -Unique
    )
    if ($announcerPackages.Count -eq 0) {
        Write-Check -State 'INFO' -Message 'No retained announcer .upk packages are present; optional announcer header checks were skipped.'
    }
    else {
        foreach ($announcerPackage in $announcerPackages) {
            $relativePath = $announcerPackage.FullName.Substring($repoRoot.Length + 1)
            $result = Test-PackageHeader -Path $announcerPackage.FullName -Compatibility $compatibility
            if ($result.IsCompatible) {
                Write-Check -State 'PASS' -Message (
                    "{0}: tag=0x{1:X8}, package={2}, licensee={3}" -f
                    $relativePath,
                    $result.Header.Tag,
                    $result.Header.PackageVersion,
                    $result.Header.LicenseeVersion
                )
            }
            else {
                $failed = $true
                Write-Check -State 'FAIL' -Message ("{0}: {1}" -f $relativePath, ($result.Reasons -join '; '))
            }
        }
    }
}

$scriptDirectory = Join-Path $repoRoot 'UTGame\Script'
Write-Host "`nRequired source-built script packages:"
Write-Host ("{0} (all must be present under UTGame\Script and pass the header check)." -f ($requiredPackages -join ', '))
foreach ($packageName in $requiredPackages) {
    $path = Join-Path $scriptDirectory $packageName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failed = $true
        Write-Check -State 'FAIL' -Message ("UTGame\Script\{0}: missing" -f $packageName)
        continue
    }

    $result = Test-PackageHeader -Path $path -Compatibility $compatibility
    if ($result.IsCompatible) {
        Write-Check -State 'PASS' -Message (
            "UTGame\Script\{0}: tag=0x{1:X8}, package={2}, licensee={3}" -f
            $packageName,
            $result.Header.Tag,
            $result.Header.PackageVersion,
            $result.Header.LicenseeVersion
        )
    }
    else {
        $failed = $true
        Write-Check -State 'FAIL' -Message (
            "UTGame\Script\{0}: {1}" -f $packageName, ($result.Reasons -join '; ')
        )
    }
}

Write-Host "`nSupplied UDK template checks (reference only):"
$templateReferences = @(
    [pscustomobject]@{
        Name = 'UDK Game'
        ScriptDirectory = if ($ReferenceRoot) { Join-Path $ReferenceRoot 'UDK Game\UDKGame\Script' } else { $null }
    },
    [pscustomobject]@{
        Name = 'UDK Ultimate'
        ScriptDirectory = if ($ReferenceRoot) { Join-Path $ReferenceRoot 'UDK Ultimate\UDKGame\Script' } else { $null }
    }
)

foreach ($templateReference in $templateReferences) {
    $templateIssues = New-Object System.Collections.Generic.List[string]
    if (-not $ReferenceRoot) {
        [void]$templateIssues.Add('no supplied template root was found')
    }
    elseif (-not (Test-Path -LiteralPath $templateReference.ScriptDirectory -PathType Container)) {
        [void]$templateIssues.Add('the supplied template Script directory is absent')
    }
    else {
        foreach ($packageName in $requiredPackages) {
            $path = Join-Path $templateReference.ScriptDirectory $packageName
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                [void]$templateIssues.Add(("{0} is absent" -f $packageName))
                continue
            }

            $result = Test-PackageHeader -Path $path -Compatibility $compatibility
            if (-not $result.IsCompatible) {
                [void]$templateIssues.Add(("{0}: {1}" -f $packageName, ($result.Reasons -join '; ')))
            }
        }
    }

    if ($templateIssues.Count -gt 0) {
        Write-Check -State 'INCOMPATIBLE' -Message (
            ('{0} is reference-only and will not be copied. ' -f $templateReference.Name) +
            ($templateIssues -join ' | ')
        )
    }
    else {
        Write-Check -State 'REFERENCE-ONLY' -Message (
            ('{0} passed this necessary header check, but it will not be copied or treated as a matching runtime payload.' -f $templateReference.Name)
        )
    }
}

if ($failed) {
    Write-Host "`nPreflight failed: run Build-LocalUTGame.ps1 to regenerate the selected native output and source-built script packages before launching."
    exit 1
}

Write-Host "`nPreflight passed. Header checks are necessary but do not replace full runtime compatibility testing."
exit 0
