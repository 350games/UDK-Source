<#
.SYNOPSIS
    Builds the self-contained UTGame runtime, script packages, and UDK editor.

.DESCRIPTION
    Runs the complete source-build sequence required by this recovered UE3
    tree. For Win64, the script first rebuilds and deploys the complete wxWidgets
    x64 Unicode Release DLL graph. It then builds UnrealBuildTool, the Release shader compile worker,
    AutoReporter, UnrealLightmass, the managed Swarm tools, and UE3 Workbench for the selected
    platform. It then builds the Release script compiler, regenerates native UnrealScript
    headers, rebuilds the script compiler against those headers, compiles all
    ten configured script packages, and finally builds the requested UTGame
    runtime and UDK editor configurations. A read-only package/native preflight
    is run last.

    The shader worker, AutoReporter, UnrealLightmass, Swarm tools, and script
    compiler are always built in Release because they are editor/build support tools.
    -Configuration controls the final UTGame and UDK native outputs.

.EXAMPLE
    .\Build-LocalUTGame.ps1

.EXAMPLE
    .\Build-LocalUTGame.ps1 -Configuration Release,Debug,Shipping

.EXAMPLE
    .\Build-LocalUTGame.ps1 -Platform Win32 -Configuration Release
#>
[CmdletBinding()]
param(
    [ValidateSet('Win32', 'Win64')]
    [string]$Platform = 'Win64',

    [ValidateSet('Release', 'Debug', 'Shipping')]
    [string[]]$Configuration = @('Release')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-MsBuildPath {
    $onPath = Get-Command 'MSBuild.exe' -ErrorAction SilentlyContinue
    if ($null -ne $onPath) {
        return $onPath.Source
    }

    $vswhereCandidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\Installer\vswhere.exe')
    )

    foreach ($vswhere in $vswhereCandidates) {
        if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
            continue
        }

        $found = @(& $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null) |
            Select-Object -First 1
        if ($LASTEXITCODE -eq 0 -and $found -and (Test-Path -LiteralPath $found -PathType Leaf)) {
            return $found
        }
    }

    throw 'MSBuild.exe was not found. Install Visual Studio Build Tools with MSBuild, the Desktop development with C++ workload, and the .NET Framework 4.8 targeting pack.'
}

function Get-PowerShellExecutable {
    $commandName = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
    $command = Get-Command $commandName -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "Unable to find $commandName for the isolated preflight process."
    }
    return $command.Source
}

function Get-TargetOutputPath {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('UTGame', 'UTGameScriptCompiler', 'UDK')]
        [string]$Target,

        [Parameter(Mandatory = $true)]
        [string]$TargetPlatform,

        [Parameter(Mandatory = $true)]
        [string]$TargetConfiguration
    )

    $outputName = if ($TargetConfiguration -eq 'Release') {
        "$Target.exe"
    }
    else {
        '{0}-{1}-{2}.exe' -f $Target, $TargetPlatform, $TargetConfiguration
    }

    return Join-Path $repoRoot (Join-Path (Join-Path 'Binaries' $TargetPlatform) $outputName)
}

function Assert-PortableExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Win32', 'Win64')]
        [string]$ExpectedPlatform
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description was not produced: $Path"
    }

    $stream = $null
    try {
        $stream = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        if ($stream.Length -lt 64) {
            throw "$Description is too short to be a PE executable: $Path"
        }

        $dosHeader = New-Object byte[] 64
        if ($stream.Read($dosHeader, 0, $dosHeader.Length) -ne $dosHeader.Length -or
            $dosHeader[0] -ne [byte][char]'M' -or
            $dosHeader[1] -ne [byte][char]'Z') {
            throw "$Description does not have a valid DOS/PE header: $Path"
        }

        $peOffset = [System.BitConverter]::ToInt32($dosHeader, 60)
        if ($peOffset -lt 0 -or $peOffset -gt ($stream.Length - 6)) {
            throw "$Description has an invalid PE header offset: $Path"
        }

        [void]$stream.Seek($peOffset, [System.IO.SeekOrigin]::Begin)
        $signature = New-Object byte[] 4
        if ($stream.Read($signature, 0, $signature.Length) -ne $signature.Length -or
            $signature[0] -ne [byte][char]'P' -or
            $signature[1] -ne [byte][char]'E' -or
            $signature[2] -ne 0 -or
            $signature[3] -ne 0) {
            throw "$Description does not have a valid PE signature: $Path"
        }

        $machineBytes = New-Object byte[] 2
        if ($stream.Read($machineBytes, 0, $machineBytes.Length) -ne $machineBytes.Length) {
            throw "$Description has a truncated COFF header: $Path"
        }

        $actualMachine = [System.BitConverter]::ToUInt16($machineBytes, 0)
        $expectedMachine = if ($ExpectedPlatform -eq 'Win64') {
            [uint16]0x8664
        }
        else {
            [uint16]0x014c
        }
        if ($actualMachine -ne $expectedMachine) {
            throw ('{0} has COFF machine 0x{1:X4}; expected 0x{2:X4} for {3}: {4}' -f
                $Description, $actualMachine, $expectedMachine, $ExpectedPlatform, $Path)
        }
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }

    $item = Get-Item -LiteralPath $Path
    Write-Host ('Verified {0}: {1} PE, {2} ({3:N0} bytes)' -f
        $Description, $ExpectedPlatform, $Path, $item.Length)
}

function Assert-NonEmptyOutput {
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

    Write-Host ('Verified {0}: {1} ({2:N0} bytes)' -f $Description, $Path, $item.Length)
}

function Remove-ExistingBuildOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    # Invalidate only an exact file beneath this workspace. This prevents a
    # successful-but-misdirected build from passing validation against an old
    # artifact while also keeping cleanup bounded to known build outputs.
    $resolvedRepoRoot = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd([char[]]@('\', '/'))
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $workspacePrefix = $resolvedRepoRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedPath.StartsWith($workspacePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove $Description outside the workspace: $resolvedPath"
    }

    if (Test-Path -LiteralPath $resolvedPath) {
        if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
            throw "$Description output path is not a file: $resolvedPath"
        }

        Remove-Item -LiteralPath $resolvedPath -Force
        if (Test-Path -LiteralPath $resolvedPath) {
            throw "Unable to invalidate the previous $Description output: $resolvedPath"
        }
        Write-Host "Invalidated previous $Description output: $resolvedPath"
    }
}

function Assert-ManagedAssembly {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedAssemblyName,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    Assert-NonEmptyOutput -Path $Path -Description $Description
    try {
        $assemblyName = [System.Reflection.AssemblyName]::GetAssemblyName($Path)
    }
    catch {
        throw "$Description is not a valid managed assembly: $Path`n$($_.Exception.Message)"
    }

    if ($assemblyName.Name -ne $ExpectedAssemblyName) {
        throw "$Description has assembly name '$($assemblyName.Name)'; expected '$ExpectedAssemblyName': $Path"
    }

    Write-Host "Verified managed assembly identity: $($assemblyName.FullName)"
}

function Invoke-ShaderCompileWorkerBuild {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MsBuildPath
    )

    Remove-ExistingBuildOutput -Path $shaderCompileWorkerPath -Description "UE3ShaderCompileWorker $Platform Release"

    Write-Host "`nBuilding UE3ShaderCompileWorker $Platform Release"
    & $MsBuildPath $shaderCompileWorkerProject `
        '/t:Rebuild' `
        '/m:1' `
        '/nologo' `
        '/p:Configuration=Release' `
        '/p:TrackFileAccess=false' `
        "/p:Platform=$shaderCompileWorkerMsBuildPlatform"
    if ($LASTEXITCODE -ne 0) {
        throw "UE3ShaderCompileWorker $Platform Release build failed with exit code $LASTEXITCODE."
    }

    Assert-PortableExecutable `
        -Path $shaderCompileWorkerPath `
        -Description "UE3ShaderCompileWorker $Platform Release" `
        -ExpectedPlatform $Platform
}

function Test-SwarmAgentLocalSourceStartup {
    $smokeParent = Join-Path $repoRoot 'Development\Intermediate\SwarmAgentStartupSmoke'
    $smokeDirectory = Join-Path $smokeParent ([guid]::NewGuid().ToString('N'))
    $resolvedSmokeParent = [System.IO.Path]::GetFullPath($smokeParent).TrimEnd([char[]]@('\', '/'))
    $resolvedSmokeDirectory = [System.IO.Path]::GetFullPath($smokeDirectory)
    $smokePrefix = $resolvedSmokeParent + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedSmokeDirectory.StartsWith($smokePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to create the Swarm Agent smoke directory outside its intended parent: $resolvedSmokeDirectory"
    }

    [void](New-Item -ItemType Directory -Path $resolvedSmokeDirectory -Force)
    $process = $null
    try {
        foreach ($artifact in @(
            $swarmAgentPath,
            $swarmAgentConfigPath,
            $agentInterfacePath,
            $unrealControlsPath,
            $swarmCoordinatorInterfacePath
        )) {
            Copy-Item -LiteralPath $artifact -Destination $resolvedSmokeDirectory
        }

        # Give the isolated test unique remoting endpoints so it cannot collide
        # with an Agent already serving an editor session on the standard ports.
        $ports = @()
        while ($ports.Count -lt 2) {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
            try {
                $listener.Start()
                $candidate = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
            }
            finally {
                $listener.Stop()
            }
            if ($ports -notcontains $candidate) {
                $ports += $candidate
            }
        }

        $smokeConfigPath = Join-Path $resolvedSmokeDirectory 'SwarmAgent.exe.config'
        $smokeConfig = [xml](Get-Content -Raw -LiteralPath $smokeConfigPath)
        $agentPortNode = $smokeConfig.SelectSingleNode("/configuration/applicationSettings/*/setting[@name='AgentRemotingPort']/value")
        $coordinatorPortNode = $smokeConfig.SelectSingleNode("/configuration/applicationSettings/*/setting[@name='CoordinatorRemotingPort']/value")
        if ($null -eq $agentPortNode -or $null -eq $coordinatorPortNode) {
            throw "Swarm Agent runtime configuration is missing its remoting port settings: $smokeConfigPath"
        }
        $agentPortNode.InnerText = $ports[0].ToString()
        $coordinatorPortNode.InnerText = $ports[1].ToString()
        $smokeConfig.Save($smokeConfigPath)

        $smokeExecutable = Join-Path $resolvedSmokeDirectory 'SwarmAgent.exe'
        $process = Start-Process -FilePath $smokeExecutable `
            -WorkingDirectory $resolvedSmokeDirectory `
            -WindowStyle Hidden `
            -PassThru

        $deadline = [datetime]::UtcNow.AddSeconds(30)
        $logFile = $null
        $logText = ''
        do {
            Start-Sleep -Milliseconds 250
            $logDirectory = Join-Path $resolvedSmokeDirectory 'SwarmCache\Logs'
            $logFile = Get-ChildItem -LiteralPath $logDirectory -Filter 'AgentLog_*.log' -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTimeUtc -Descending |
                Select-Object -First 1
            if ($null -ne $logFile) {
                $logText = Get-Content -Raw -LiteralPath $logFile.FullName -ErrorAction SilentlyContinue
            }
        } while (
            [datetime]::UtcNow -lt $deadline -and
            -not $process.HasExited -and
            $logText.IndexOf('initialization successful, SwarmAgent now running', [System.StringComparison]::Ordinal) -lt 0
        )

        if ($null -eq $logFile) {
            throw 'The fresh Swarm Agent smoke test did not create an app-local cache log.'
        }
        foreach ($requiredLine in @(
            'unsigned local-source executable accepted for standalone-only execution',
            "using cache folder '$resolvedSmokeDirectory\SwarmCache'",
            'standalone mode enabled; SwarmCoordinator connection disabled',
            'initialization successful, SwarmAgent now running'
        )) {
            if ($logText.IndexOf($requiredLine, [System.StringComparison]::Ordinal) -lt 0) {
                throw "The fresh Swarm Agent smoke log is missing '$requiredLine':`n$logText"
            }
        }
        if ($logText -match '(?im)^.*(?:\[ERROR\]|\bfailed\b|\bfatal\b|\bexception\b|certificate validation failed).*$') {
            throw "The fresh Swarm Agent smoke log contains a failure:`n$($Matches[0])`n`n$logText"
        }

        Write-Host "Verified fresh unsigned local Swarm Agent startup in standalone mode with an app-local cache and no logged failures."
    }
    finally {
        if ($null -ne $process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
            [void]$process.WaitForExit(5000)
        }
        if (Test-Path -LiteralPath $resolvedSmokeDirectory) {
            if (-not $resolvedSmokeDirectory.StartsWith($smokePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to remove the Swarm Agent smoke directory outside its intended parent: $resolvedSmokeDirectory"
            }
            Remove-Item -LiteralPath $resolvedSmokeDirectory -Recurse -Force
        }
    }
}

function Invoke-EditorSupportBuild {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MsBuildPath
    )

    foreach ($output in $editorSupportOutputPaths) {
        Remove-ExistingBuildOutput -Path $output.Path -Description $output.Description
    }

    # Resource files restored from downloaded source archives can retain a
    # Mark-of-the-Web alternate stream. MSBuild intentionally rejects blocked
    # .resx inputs, so normalize only the known, trusted editor-support inputs.
    foreach ($resourcePath in $editorSupportResourceInputs) {
        Unblock-File -LiteralPath $resourcePath
    }

    Write-Host "`nBuilding AutoReporter (.NET Framework 4.8, AnyCPU)"
    & $MsBuildPath $autoReporterProject `
        '/t:Rebuild' `
        '/m:1' `
        '/nologo' `
        '/p:Configuration=Release' `
        '/p:Platform=AnyCPU'
    if ($LASTEXITCODE -ne 0) {
        throw "AutoReporter Release build failed with exit code $LASTEXITCODE."
    }

    Write-Host "`nBuilding Swarm Agent and its managed interfaces (.NET Framework 4.8, AnyCPU)"
    & $MsBuildPath $swarmAgentProject `
        '/t:Rebuild' `
        '/m:1' `
        '/nologo' `
        '/p:Configuration=Release' `
        '/p:Platform=AnyCPU'
    if ($LASTEXITCODE -ne 0) {
        throw "Swarm Agent Release build failed with exit code $LASTEXITCODE."
    }

    Write-Host "`nBuilding Swarm Coordinator (.NET Framework 4.8, AnyCPU)"
    & $MsBuildPath $swarmCoordinatorProject `
        '/t:Rebuild' `
        '/m:1' `
        '/nologo' `
        '/p:Configuration=Release' `
        '/p:Platform=AnyCPU'
    if ($LASTEXITCODE -ne 0) {
        throw "Swarm Coordinator Release build failed with exit code $LASTEXITCODE."
    }

    Write-Host "`nBuilding UnrealLightmass $Platform Release"
    & $MsBuildPath $unrealLightmassProject `
        '/t:Rebuild' `
        '/m:1' `
        '/nologo' `
        '/p:Configuration=Release' `
        '/p:TrackFileAccess=false' `
        "/p:Platform=$editorSupportMsBuildPlatform"
    if ($LASTEXITCODE -ne 0) {
        throw "UnrealLightmass $Platform Release build failed with exit code $LASTEXITCODE."
    }

    Assert-ManagedAssembly -Path $autoReporterPath -ExpectedAssemblyName 'AutoReporter' -Description 'AutoReporter'
    Assert-NonEmptyOutput -Path $autoReporterConfigPath -Description 'AutoReporter runtime configuration'
    Assert-ManagedAssembly -Path $autoReporterXmlSerializersPath -ExpectedAssemblyName 'AutoReporter.XmlSerializers' -Description 'AutoReporter XML serializers'
    Assert-ManagedAssembly -Path $unrealControlsPath -ExpectedAssemblyName 'UnrealControls' -Description 'UnrealControls'
    Assert-ManagedAssembly -Path $agentInterfacePath -ExpectedAssemblyName 'AgentInterface' -Description 'Swarm Agent interface'
    Assert-ManagedAssembly -Path $platformAgentInterfacePath -ExpectedAssemblyName 'AgentInterface' -Description "$Platform Swarm Agent interface"
    Assert-ManagedAssembly -Path $swarmCoordinatorInterfacePath -ExpectedAssemblyName 'SwarmCoordinatorInterface' -Description 'Swarm Coordinator interface'
    Assert-ManagedAssembly -Path $swarmAgentPath -ExpectedAssemblyName 'SwarmAgent' -Description 'Swarm Agent'
    Assert-NonEmptyOutput -Path $swarmAgentConfigPath -Description 'Swarm Agent runtime configuration'
    Assert-ManagedAssembly -Path $swarmCoordinatorPath -ExpectedAssemblyName 'SwarmCoordinator' -Description 'Swarm Coordinator'
    Assert-NonEmptyOutput -Path $swarmCoordinatorConfigPath -Description 'Swarm Coordinator runtime configuration'
    Assert-PortableExecutable -Path $unrealLightmassPath -Description "UnrealLightmass $Platform Release" -ExpectedPlatform $Platform
    Assert-PortableExecutable -Path $directXRuntimePath -Description "DirectX 9 D3DX runtime required by UnrealLightmass $Platform" -ExpectedPlatform $Platform
    Test-SwarmAgentLocalSourceStartup
}

function Invoke-UE3WorkbenchBuild {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MsBuildPath
    )

    Remove-ExistingBuildOutput -Path $ue3WorkbenchPath -Description 'UE3 Workbench Release'

    Write-Host "`nBuilding UE3 Workbench (.NET Framework 4.8, AnyCPU)"
    & $MsBuildPath $ue3WorkbenchProject `
        '/t:Rebuild' `
        '/m:1' `
        '/nologo' `
        '/p:Configuration=Release' `
        '/p:Platform=AnyCPU'
    if ($LASTEXITCODE -ne 0) {
        throw "UE3 Workbench Release build failed with exit code $LASTEXITCODE."
    }

    Assert-ManagedAssembly -Path $ue3WorkbenchPath -ExpectedAssemblyName 'UE3Workbench' -Description 'UE3 Workbench'
}

function Invoke-UnrealBuild {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('UTGame', 'UTGameScriptCompiler', 'UDK')]
        [string]$Target,

        [Parameter(Mandatory = $true)]
        [string]$TargetConfiguration
    )

    $outputPath = Get-TargetOutputPath -Target $Target -TargetPlatform $Platform -TargetConfiguration $TargetConfiguration
    Remove-ExistingBuildOutput -Path $outputPath -Description "$Target $Platform $TargetConfiguration"

    Write-Host "`nBuilding $Target $Platform $TargetConfiguration"
    Push-Location -LiteralPath $sourceRoot
    try {
        & $ubtExecutable $Target $Platform $TargetConfiguration '-noxge'
        if ($LASTEXITCODE -ne 0) {
            throw "$Target $Platform $TargetConfiguration build failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }

    Assert-PortableExecutable `
        -Path $outputPath `
        -Description "$Target $Platform $TargetConfiguration" `
        -ExpectedPlatform $Platform
    return $outputPath
}

function Invoke-ScriptCompiler {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    Write-Host "`n$Description"
    $process = Start-Process -FilePath $scriptCompilerPath `
        -ArgumentList $Arguments `
        -WorkingDirectory $binaryDirectory `
        -WindowStyle Hidden `
        -Wait `
        -PassThru
    if ($process.ExitCode -ne 0) {
        throw "$Description failed with exit code $($process.ExitCode)."
    }
}

function Assert-GeneratedHeaders {
    foreach ($relativePath in $requiredGeneratedHeaders) {
        $path = Join-Path $repoRoot $relativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "The header-generation pass did not produce $path."
        }

        $item = Get-Item -LiteralPath $path
        if ($item.Length -le 0) {
            throw "The header-generation pass produced an empty file: $path"
        }

        $text = Get-Content -Raw -LiteralPath $path
        $requiredMarker = if ($item.Name.EndsWith('Names.h', [System.StringComparison]::OrdinalIgnoreCase)) {
            'AUTOGENERATE_NAME'
        }
        else {
            'C++ class definitions exported from UnrealScript'
        }
        if ($text.IndexOf($requiredMarker, [System.StringComparison]::Ordinal) -lt 0) {
            throw "Generated header marker '$requiredMarker' was not found in $path."
        }

        Write-Host "Verified generated header: $path"
    }
}

function Assert-ScriptPackages {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$CompilationStartedUtc
    )

    # NTFS timestamps have finer resolution, but retain a small margin for
    # workspaces hosted on filesystems with coarser timestamp granularity.
    $oldestAcceptedWriteUtc = $CompilationStartedUtc.AddSeconds(-2)
    foreach ($packageName in $requiredScriptPackages) {
        $path = Join-Path $scriptDirectory $packageName
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "The full script pass did not produce $path."
        }

        $item = Get-Item -LiteralPath $path
        if ($item.Length -le 12) {
            throw "The full script pass produced an invalid or empty package: $path"
        }
        if ($item.LastWriteTimeUtc -lt $oldestAcceptedWriteUtc) {
            throw "The full script pass did not refresh $path."
        }

        Write-Host ('Verified source-built script package: {0} ({1:N0} bytes)' -f $path, $item.Length)
    }
}

$repoRoot = $PSScriptRoot
$sourceRoot = Join-Path $repoRoot 'Development\Src'
$ubtProject = Join-Path $sourceRoot 'UnrealBuildTool\UnrealBuildTool.csproj'
$ubtExecutable = Join-Path $repoRoot 'Development\Intermediate\UnrealBuildTool\Release\UnrealBuildTool.exe'
$shaderCompileWorkerProject = Join-Path $repoRoot 'Development\Tools\ShaderCompileWorker\ShaderCompileWorker.Local.vcxproj'
$shaderCompileWorkerMsBuildPlatform = if ($Platform -eq 'Win64') { 'x64' } else { 'Win32' }
$autoReporterProject = Join-Path $repoRoot 'Development\Tools\CrashReport\AutoReporter\AutoReporter.csproj'
$swarmAgentProject = Join-Path $repoRoot 'Development\Tools\UnrealSwarm\Agent\Agent.csproj'
$swarmCoordinatorProject = Join-Path $repoRoot 'Development\Tools\UnrealSwarm\SwarmCoordinator\SwarmCoordinator.csproj'
$unrealLightmassProject = Join-Path $repoRoot 'Development\Tools\UnrealLightmass\UnrealLightmass.vcxproj'
$ue3WorkbenchProject = Join-Path $repoRoot 'Development\Tools\UE3Workbench\UE3Workbench.csproj'
$editorSupportMsBuildPlatform = if ($Platform -eq 'Win64') { 'x64' } else { 'Win32' }
$binaryDirectory = Join-Path $repoRoot (Join-Path 'Binaries' $Platform)
$shaderCompileWorkerPath = Join-Path $binaryDirectory 'UE3ShaderCompileWorker.exe'
$scriptCompilerPath = Join-Path $binaryDirectory 'UTGameScriptCompiler.exe'
$autoReporterPath = Join-Path $repoRoot 'Binaries\AutoReporter.exe'
$autoReporterConfigPath = Join-Path $repoRoot 'Binaries\AutoReporter.exe.config'
$autoReporterXmlSerializersPath = Join-Path $repoRoot 'Binaries\AutoReporter.XmlSerializers.dll'
$unrealControlsPath = Join-Path $repoRoot 'Binaries\UnrealControls.dll'
$agentInterfacePath = Join-Path $repoRoot 'Binaries\AgentInterface.dll'
$platformAgentInterfacePath = Join-Path $binaryDirectory 'AgentInterface.dll'
$swarmCoordinatorInterfacePath = Join-Path $repoRoot 'Binaries\SwarmCoordinatorInterface.dll'
$swarmAgentPath = Join-Path $repoRoot 'Binaries\SwarmAgent.exe'
$swarmAgentConfigPath = Join-Path $repoRoot 'Binaries\SwarmAgent.exe.config'
$swarmCoordinatorPath = Join-Path $repoRoot 'Binaries\SwarmCoordinator.exe'
$swarmCoordinatorConfigPath = Join-Path $repoRoot 'Binaries\SwarmCoordinator.exe.config'
$unrealLightmassPath = Join-Path $binaryDirectory 'UnrealLightmass.exe'
$ue3WorkbenchPath = Join-Path $repoRoot 'Binaries\UE3Workbench.exe'
$windowsSystemDirectoryName = if ($Platform -eq 'Win64') {
    if (-not [System.Environment]::Is64BitOperatingSystem) {
        throw 'A Win64 build requires a 64-bit Windows operating system.'
    }
    if ([System.Environment]::Is64BitProcess) { 'System32' } else { 'Sysnative' }
}
elseif ([System.Environment]::Is64BitOperatingSystem) {
    'SysWOW64'
}
else {
    'System32'
}
$directXRuntimePath = Join-Path (Join-Path $env:WINDIR $windowsSystemDirectoryName) 'd3dx9_39.dll'
$scriptDirectory = Join-Path $repoRoot 'UTGame\Script'
$preflightScript = Join-Path $repoRoot 'Test-LocalUTGameRuntime.ps1'
$wxBuildScript = Join-Path $repoRoot 'Build-WxWidgets.ps1'
$contentRestoreScript = Join-Path $repoRoot 'Restore-LocalUTGameContent.ps1'
$contentManifest = Join-Path $repoRoot 'Required-LocalUTGameContent.txt'

$editorSupportOutputPaths = @(
    [pscustomobject]@{ Path = $autoReporterPath; Description = 'AutoReporter' },
    [pscustomobject]@{ Path = $autoReporterConfigPath; Description = 'AutoReporter runtime configuration' },
    [pscustomobject]@{ Path = $autoReporterXmlSerializersPath; Description = 'AutoReporter XML serializers' },
    [pscustomobject]@{ Path = $unrealControlsPath; Description = 'UnrealControls' },
    [pscustomobject]@{ Path = $agentInterfacePath; Description = 'Swarm Agent interface' },
    [pscustomobject]@{ Path = $platformAgentInterfacePath; Description = "$Platform Swarm Agent interface" },
    [pscustomobject]@{ Path = $swarmCoordinatorInterfacePath; Description = 'Swarm Coordinator interface' },
    [pscustomobject]@{ Path = $swarmAgentPath; Description = 'Swarm Agent' },
    [pscustomobject]@{ Path = $swarmAgentConfigPath; Description = 'Swarm Agent runtime configuration' },
    [pscustomobject]@{ Path = $swarmCoordinatorPath; Description = 'Swarm Coordinator' },
    [pscustomobject]@{ Path = $swarmCoordinatorConfigPath; Description = 'Swarm Coordinator runtime configuration' },
    [pscustomobject]@{ Path = $unrealLightmassPath; Description = "UnrealLightmass $Platform Release" }
)

$editorSupportResourceInputs = @(
    (Join-Path $repoRoot 'Development\Tools\CrashReport\AutoReporter\CrashURLDlg.resx'),
    (Join-Path $repoRoot 'Development\Tools\CrashReport\AutoReporter\Form1.resx'),
    (Join-Path $repoRoot 'Development\Tools\CrashReport\AutoReporter\Properties\Resources.resx'),
    (Join-Path $repoRoot 'Development\Tools\UnrealControls\OutputWindowView.resx'),
    (Join-Path $repoRoot 'Development\Tools\UnrealControls\Properties\Resources.resx'),
    (Join-Path $repoRoot 'Development\Tools\UnrealControls\UnrealAboutBox.resx'),
    (Join-Path $repoRoot 'Development\Tools\UnrealSwarm\Agent\Display.resx'),
    (Join-Path $repoRoot 'Development\Tools\UnrealSwarm\Agent\Properties\Resources.resx'),
    (Join-Path $repoRoot 'Development\Tools\UnrealSwarm\SwarmCoordinator\Properties\Resources.resx'),
    (Join-Path $repoRoot 'Development\Tools\UnrealSwarm\SwarmCoordinator\SwarmCoordinator.resx')
)

$requiredScriptPackages = @(
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

$requiredGeneratedHeaders = @(
    'Development\Src\Core\Inc\CoreClasses.h',
    'Development\Src\Core\Inc\CoreNames.h',
    'Development\Src\Engine\Inc\EngineClasses.h',
    'Development\Src\Engine\Inc\EngineNames.h',
    'Development\Src\GFxUI\Inc\GFxUIClasses.h',
    'Development\Src\GFxUI\Inc\GFxUINames.h',
    'Development\Src\GFxUI\Inc\GFxUIUIPrivateClasses.h',
    'Development\Src\GFxUI\Inc\GFxUIUISequenceClasses.h',
    'Development\Src\IpDrv\Inc\IpDrvClasses.h',
    'Development\Src\IpDrv\Inc\IpDrvNames.h',
    'Development\Src\GameFramework\Inc\GameFrameworkClasses.h',
    'Development\Src\GameFramework\Inc\GameFrameworkNames.h',
    'Development\Src\UnrealEd\Inc\UnrealEdClasses.h',
    'Development\Src\UnrealEd\Inc\UnrealEdNames.h',
    'Development\Src\WinDrv\Inc\WinDrvClasses.h',
    'Development\Src\WinDrv\Inc\WinDrvNames.h',
    'Development\Src\OnlineSubsystemPC\Inc\OnlineSubsystemPCClasses.h',
    'Development\Src\OnlineSubsystemPC\Inc\OnlineSubsystemPCNames.h',
    'Development\Src\UTGame\Inc\UTGameClasses.h',
    'Development\Src\UTGame\Inc\UTGameNames.h'
)

$requiredBuildInputs = @(
    $sourceRoot,
    $ubtProject,
    $shaderCompileWorkerProject,
    $autoReporterProject,
    $swarmAgentProject,
    $swarmCoordinatorProject,
    $unrealLightmassProject,
    $preflightScript,
    $wxBuildScript,
    $contentRestoreScript,
    $contentManifest
) + $editorSupportResourceInputs
foreach ($requiredPath in $requiredBuildInputs) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required local build input was not found: $requiredPath"
    }
}

$targetConfigurations = @($Configuration | Select-Object -Unique)
if ($targetConfigurations.Count -eq 0) {
    throw 'At least one target configuration is required.'
}

# UBT owns shared intermediate/output files. Refuse a second script instance
# instead of allowing two UBT processes to overwrite one another's artifacts.
$buildMutex = [System.Threading.Mutex]::new($false, 'Local\UnrealEngine3SC.LocalUTGameBuild')
$ownsBuildMutex = $false

try {
    try {
        $ownsBuildMutex = $buildMutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        $ownsBuildMutex = $true
    }

    if (-not $ownsBuildMutex) {
        throw 'Another Build-LocalUTGame.ps1 invocation is already building this workspace. Wait for it to finish before starting another build.'
    }

    Write-Host "`nRestoring and verifying the required supplied content closure"
    & $contentRestoreScript

    if ($Platform -eq 'Win64') {
        Write-Host "`nRebuilding and deploying the wxWidgets Win64 dependency graph"
        & $wxBuildScript
    }

    $msbuild = Get-MsBuildPath
    Invoke-ShaderCompileWorkerBuild -MsBuildPath $msbuild
    Invoke-EditorSupportBuild -MsBuildPath $msbuild
    Invoke-UE3WorkbenchBuild -MsBuildPath $msbuild

    Remove-ExistingBuildOutput -Path $ubtExecutable -Description 'UnrealBuildTool Release'
    Write-Host "Building UnrealBuildTool with $msbuild"
    & $msbuild $ubtProject '/t:Rebuild' '/m:1' '/nologo' '/p:Configuration=Release' '/p:Platform=AnyCPU'
    if ($LASTEXITCODE -ne 0) {
        throw "UnrealBuildTool build failed with exit code $LASTEXITCODE."
    }
    Assert-ManagedAssembly -Path $ubtExecutable -ExpectedAssemblyName 'UnrealBuildTool' -Description 'UnrealBuildTool Release'

    # The first pass compiles UnrealScript only far enough to regenerate the
    # native C++ interface. The native compiler is then rebuilt against that
    # interface before the final .u packages are emitted.
    [void](Invoke-UnrealBuild -Target 'UTGameScriptCompiler' -TargetConfiguration 'Release')
    Invoke-ScriptCompiler -Arguments @('make', '-full', '-headers', '-auto', '-unattended', '-nopause', '-forcelogflush', '-nullrhi', '-warningsaserrors') -Description 'Generating native UnrealScript headers'
    Assert-GeneratedHeaders

    [void](Invoke-UnrealBuild -Target 'UTGameScriptCompiler' -TargetConfiguration 'Release')
    $scriptCompilationStartedUtc = [datetime]::UtcNow
    Invoke-ScriptCompiler -Arguments @('make', '-full', '-unattended', '-nopause', '-forcelogflush', '-nullrhi', '-warningsaserrors') -Description 'Compiling the complete UnrealScript package set'
    Assert-ScriptPackages -CompilationStartedUtc $scriptCompilationStartedUtc

    foreach ($targetConfiguration in $targetConfigurations) {
        [void](Invoke-UnrealBuild -Target 'UTGame' -TargetConfiguration $targetConfiguration)
        [void](Invoke-UnrealBuild -Target 'UDK' -TargetConfiguration $targetConfiguration)
    }

    # Run the package-version parser in a separate PowerShell process because
    # the read-only preflight deliberately returns a process exit code.
    $powerShellExecutable = Get-PowerShellExecutable
    Write-Host "`nRunning final native and script-package preflight"
    foreach ($targetConfiguration in $targetConfigurations) {
        # Invoke once per configuration so Windows PowerShell 5.1 does not
        # need to marshal a string-array parameter through powershell.exe.
        $preflightArguments = @(
            '-NoLogo',
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            $preflightScript,
            '-Platform',
            $Platform,
            '-Configuration',
            $targetConfiguration,
            '-RequireAllNativeOutputs'
        )
        & $powerShellExecutable @preflightArguments
        if ($LASTEXITCODE -ne 0) {
            throw "Runtime preflight for $Platform $targetConfiguration failed with exit code $LASTEXITCODE."
        }
    }

    $wxSummary = if ($Platform -eq 'Win64') { 'wxWidgets, ' } else { '' }
    Write-Host "`nFull $Platform source build completed successfully. The ${wxSummary}shader worker, AutoReporter, UnrealLightmass, Swarm tools, UTGame, UDK, and all ten script packages passed verification."
}
finally {
    if ($ownsBuildMutex) {
        [void]$buildMutex.ReleaseMutex()
    }
    $buildMutex.Dispose()
}
