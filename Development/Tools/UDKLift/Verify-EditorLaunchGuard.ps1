[CmdletBinding()]
param(
    [string]$LauncherPath,

    [string]$SourcePath,

    [string]$ProjectPath,

    [switch]$SkipLaunchSmoke
)

$verificationRoot = Split-Path -Parent $PSCommandPath
if ([string]::IsNullOrWhiteSpace($LauncherPath)) {
    $LauncherPath = Join-Path $verificationRoot '..\..\..\Binaries\UDKLift.exe'
}
if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $SourcePath = Join-Path $verificationRoot 'Program.cs'
}
if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = Join-Path $verificationRoot 'UDKLift.csproj'
}

# UDKLift targets .NET Framework. PowerShell 7 cannot reflect over a .NET
# Framework executable directly, so hand the verification to Windows
# PowerShell when it is available.
if ($PSVersionTable.PSEdition -eq 'Core') {
    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf) {
        $forwardedArguments = @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', $PSCommandPath,
            '-LauncherPath', $LauncherPath,
            '-SourcePath', $SourcePath,
            '-ProjectPath', $ProjectPath
        )
        if ($SkipLaunchSmoke) {
            $forwardedArguments += '-SkipLaunchSmoke'
        }

        & $windowsPowerShell @forwardedArguments
        exit $LASTEXITCODE
    }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$launcher = (Resolve-Path -LiteralPath $LauncherPath).Path
$sourcePath = (Resolve-Path -LiteralPath $SourcePath).Path
$projectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
$assembly = [Reflection.Assembly]::LoadFrom($launcher)
$programType = $assembly.GetType('UDKLift.Program', $true)
$bindingFlags = [Reflection.BindingFlags]'NonPublic, Static'

if ($null -ne $programType.GetMethod('ContainsEditorLaunchToken', $bindingFlags)) {
    throw 'The obsolete UDKLift editor-launch guard is still present in the built launcher.'
}

$normalize = $programType.GetMethod('NormalizeLaunchArguments', $bindingFlags)
$requiresElevation = $programType.GetMethod('RequiresElevation', $bindingFlags)
$buildCommandLine = $programType.GetMethod('BuildCommandLine', $bindingFlags)
$targetExecutableName = $programType.GetMethod('GetTargetExecutableName', $bindingFlags)
$canWriteToFolder = $programType.GetMethod('CanWriteToFolder', $bindingFlags)

if ($null -eq $normalize -or $null -eq $requiresElevation -or
    $null -eq $buildCommandLine -or $null -eq $targetExecutableName -or
    $null -eq $canWriteToFolder) {
    throw 'One or more UDKLift forwarding helpers were not found.'
}

$normalizationCases = @(
    @{ Input = 'editor'; Expected = 'editor' },
    @{ Input = '-editor'; Expected = 'editor' },
    @{ Input = '/editor'; Expected = 'editor' },
    @{ Input = '--editor'; Expected = 'editor' },
    @{ Input = '///editor'; Expected = 'editor' },
    @{ Input = '  -editor  '; Expected = 'editor' },
    @{ Input = 'EDITOR'; Expected = 'editor' },
    @{ Input = '-EDITOR'; Expected = 'editor' },
    @{ Input = '/EDITOR'; Expected = 'editor' },
    @{ Input = '-editor=true'; Expected = '-editor=true' },
    @{ Input = 'editor.exe'; Expected = 'editor.exe' },
    @{ Input = 'Example Map.udk'; Expected = 'Example Map.udk' },
    @{ Input = 'make'; Expected = 'make' },
    @{ Input = 'cookpackages'; Expected = 'cookpackages' }
)

foreach ($case in $normalizationCases) {
    $actual = [string[]]$normalize.Invoke(
        $null,
        [object[]](, [string[]]@($case.Input))
    )
    if ($actual.Count -ne 1 -or $actual[0] -cne $case.Expected) {
        throw "Unexpected normalization for '$($case.Input)': '$($actual -join ' ')'"
    }
}

$argumentsToNormalize = [string[]]@('-editor', '/EDITOR', '--editor', 'Example Map.udk')
$normalized = [string[]]$normalize.Invoke($null, [object[]](, $argumentsToNormalize))
$expectedNormalized = [string[]]@('editor', 'editor', 'editor', 'Example Map.udk')
if (($normalized -join "`n") -cne ($expectedNormalized -join "`n")) {
    throw 'Editor arguments were not normalized without changing unrelated arguments.'
}

$elevationCases = @(
    @{ Arguments = @('editor'); Expected = $true },
    @{ Arguments = @('-editor'); Expected = $true },
    @{ Arguments = @('make'); Expected = $true },
    @{ Arguments = @('/cookpackages'); Expected = $true },
    @{ Arguments = @('Example Map.udk'); Expected = $false }
)
foreach ($case in $elevationCases) {
    $actual = [bool]$requiresElevation.Invoke($null, [object[]](, [string[]]$case.Arguments))
    if ($actual -ne $case.Expected) {
        throw "Unexpected elevation decision for '$($case.Arguments -join ' ')'."
    }
}

$quotedArguments = [string[]]@('make', 'Example Map.udk', '', 'say"hello', 'trailing slash\')
$quoted = [string]$buildCommandLine.Invoke($null, [object[]](, $quotedArguments))
if ($quoted -cne 'make "Example Map.udk" "" "say\"hello" "trailing slash\\"') {
    throw "Arguments were not quoted correctly: $quoted"
}

$mappedExecutable = [string]$targetExecutableName.Invoke(
    $null,
    [object[]]@('C:\UDK\Binaries\UDKLift.exe')
)
if ($mappedExecutable -cne 'UDK.exe') {
    throw "UDKLift did not map to UDK.exe: $mappedExecutable"
}

$source = Get-Content -LiteralPath $sourcePath -Raw
$project = Get-Content -LiteralPath $projectPath -Raw
if ($source.IndexOf('ContainsEditorLaunchToken', [StringComparison]::Ordinal) -ge 0) {
    throw 'The obsolete editor-launch guard is still present in Program.cs.'
}

$normalizeCall = $source.IndexOf('NormalizeLaunchArguments( Arguments )', [StringComparison]::Ordinal)
$commandLineBuild = $source.IndexOf('BuildCommandLine( NormalizedArguments )', [StringComparison]::Ordinal)
$processStart = $source.IndexOf('LaunchProcess.Start();', [StringComparison]::Ordinal)
if ($normalizeCall -lt 0 -or $commandLineBuild -lt 0 -or $processStart -lt 0 -or
    $normalizeCall -gt $commandLineBuild -or $commandLineBuild -gt $processStart) {
    throw 'UDKLift must normalize and quote arguments before starting UDK.'
}

if ($source.IndexOf('Environment.Is64BitOperatingSystem', [StringComparison]::Ordinal) -lt 0) {
    throw 'UDKLift must select Win64 from the operating-system architecture.'
}

$prefer32BitMatches = [regex]::Matches(
    $project,
    '<Prefer32Bit>\s*false\s*</Prefer32Bit>',
    [Text.RegularExpressions.RegexOptions]::IgnoreCase
)
if ($prefer32BitMatches.Count -lt 2) {
    throw 'UDKLift must not prefer a 32-bit launcher process in Debug or Release.'
}

if (-not $SkipLaunchSmoke) {
    $binariesFolder = Split-Path -Parent $launcher
    $isWritable = [bool]$canWriteToFolder.Invoke(
        $null,
        [object[]]@([string]$binariesFolder)
    )
    if (-not $isWritable) {
        throw 'The hidden launch smoke requires writable root Binaries so it cannot trigger a UAC prompt.'
    }

    $workspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
    $logName = 'UDKLiftForwardingSmoke-' + [Guid]::NewGuid().ToString('N')
    $logDirectory = Join-Path $workspaceRoot 'UTGame\Logs'
    $logCandidates = @(
        (Join-Path $logDirectory $logName),
        (Join-Path $logDirectory ($logName + '.log'))
    )
    $smokeArguments = [string[]]@(
        'PerformMapCheck',
        'ExampleEntry.udk',
        '-editor',
        '-unattended',
        '-nopause',
        '-forcelogflush',
        '-nullrhi',
        '-nosound',
        '-nosplash',
        ('-log=' + $logName)
    )
    $launcherCommandLine = [string]$buildCommandLine.Invoke(
        $null,
        [object[]](, $smokeArguments)
    )

    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $launcher
    $startInfo.Arguments = $launcherCommandLine
    $startInfo.WorkingDirectory = $binariesFolder
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden

    $expectedUdkExecutable = Join-Path $binariesFolder 'Win64\UDK.exe'
    function Get-ForwardedSmokeProcesses {
        @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'UDK.exe'" -ErrorAction SilentlyContinue |
            Where-Object {
                [String]::Equals(
                    [string]$_.ExecutablePath,
                    $expectedUdkExecutable,
                    [StringComparison]::OrdinalIgnoreCase
                ) -and
                $null -ne $_.CommandLine -and
                $_.CommandLine.IndexOf($logName, [StringComparison]::OrdinalIgnoreCase) -ge 0
            })
    }

    $launcherProcess = [Diagnostics.Process]::Start($startInfo)
    if ($null -eq $launcherProcess) {
        throw 'UDKLift did not start for the hidden forwarding smoke.'
    }

    try {
        try {
            if (-not $launcherProcess.WaitForExit(10000)) {
                try { $launcherProcess.Kill() } catch {}
                throw 'UDKLift did not return after starting the child commandlet.'
            }
            if ($launcherProcess.ExitCode -ne 0) {
                throw "UDKLift returned exit code $($launcherProcess.ExitCode)."
            }
        }
        finally {
            $launcherProcess.Dispose()
        }

        $deadline = [DateTime]::UtcNow.AddSeconds(180)
        $logPath = $null
        $logText = $null
        while ([DateTime]::UtcNow -lt $deadline) {
            foreach ($candidate in $logCandidates) {
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $logPath = $candidate
                    $logText = Get-Content -LiteralPath $candidate -Raw -ErrorAction SilentlyContinue
                    if ($null -ne $logText -and $logText.IndexOf('Log file closed', [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                        break
                    }
                }
            }

            if ($null -ne $logText -and $logText.IndexOf('Log file closed', [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                break
            }
            Start-Sleep -Milliseconds 100
        }

        if ($null -eq $logPath -or $null -eq $logText -or
            $logText.IndexOf('Log file closed', [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "The forwarded UDK commandlet did not close its unique log within 180 seconds: $logName"
        }

        $requiredLogText = @(
            'Command line: PerformMapCheck ExampleEntry.udk editor',
            'Executing Class UnrealEd.PerformMapCheckCommandlet',
            'Initializing Editor Engine Completed',
            'Found 1 maps',
            'Loading  ..\..\UTGame\Content\Maps\ExampleEntry.udk',
            'Checking ..\..\UTGame\Content\Maps\ExampleEntry.udk',
            'Success - 0 error(s), 0 warning(s)',
            'Editor shut down',
            'Object subsystem successfully closed',
            'Log file closed'
        )
        foreach ($requiredText in $requiredLogText) {
            if ($logText.IndexOf($requiredText, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                throw "The forwarded commandlet log is missing '$requiredText': $logPath"
            }
        }

        $expectedBaseDirectory = Join-Path $binariesFolder 'Win64'
        if ($logText.IndexOf(('Base directory: ' + $expectedBaseDirectory + '\'), [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "UDKLift did not forward to the root Win64 UDK executable: $logPath"
        }

        $forbiddenLogPattern = '(?im)^.*(?:Critical:|Error:|Warning:|ScriptWarning|appError|Fatal|Assertion failed|Unhandled Exception|\bcrash(?:ed)?\b|\bfailed(?: to)?\b|\bfallback\b|Class None|missing cached).*$'
        $forbiddenLogMatch = [regex]::Match($logText, $forbiddenLogPattern)
        if ($forbiddenLogMatch.Success) {
            throw "The forwarded commandlet log contains a failure marker: $($forbiddenLogMatch.Value.Trim()) ($logPath)"
        }

        Write-Host "UDKLift hidden forwarding smoke passed: $logPath"
    }
    finally {
        # If validation fails, clean up only the source-built UDK child carrying
        # this smoke test's unique log token.  Never stop unrelated UDK sessions.
        foreach ($smokeProcess in @(Get-ForwardedSmokeProcesses)) {
            Stop-Process -Id ([int]$smokeProcess.ProcessId) -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host 'UDKLift unguarded editor forwarding behavior verified.'
