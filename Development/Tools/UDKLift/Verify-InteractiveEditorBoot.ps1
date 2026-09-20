<#
.SYNOPSIS
    Launches the real D3D UDK editor hidden and verifies a stable, clean boot.

.DESCRIPTION
    Uses UDKLift by default so the launcher handoff and native editor are tested
    together. The verifier waits for engine initialization, the editor window,
    and the template-map initialization timer; rejects Duke branding and any
    warning/error/load-failure markers; holds the process for a stability
    interval; and closes the editor through WM_CLOSE.

.EXAMPLE
    .\Verify-InteractiveEditorBoot.ps1

.EXAMPLE
    .\Verify-InteractiveEditorBoot.ps1 -Direct
#>
[CmdletBinding()]
param(
    [switch]$Direct,

    [ValidateRange(5, 300)]
    [int]$StartupTimeoutSeconds = 120,

    [ValidateRange(5, 60)]
    [int]$StabilitySeconds = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class UDKLiftEditorWindow
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
}
'@

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$binariesDirectory = Join-Path $repoRoot 'Binaries'
$win64Directory = Join-Path $binariesDirectory 'Win64'
$udkExecutable = Join-Path $win64Directory 'UDK.exe'
$launcherExecutable = Join-Path $binariesDirectory 'UDKLift.exe'
$logDirectory = Join-Path $repoRoot 'UTGame\Logs'

foreach ($requiredPath in @($udkExecutable, $launcherExecutable, $logDirectory)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required editor-boot input is missing: $requiredPath"
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$logName = "UDKLiftInteractiveBoot-$stamp.log"
$logPath = Join-Path $logDirectory $logName
$existingUdkProcessIds = @(
    Get-CimInstance Win32_Process -Filter "Name='UDK.exe'" -ErrorAction SilentlyContinue |
        ForEach-Object { [int]$_.ProcessId }
)

$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = if ($Direct) { $udkExecutable } else { $launcherExecutable }
$editorToken = if ($Direct) { 'editor' } else { '-editor' }
$startInfo.Arguments = "$editorToken -unattended -nopause -forcelogflush -nosplash -windowed -ResX=800 -ResY=600 -log=$logName"
$startInfo.WorkingDirectory = if ($Direct) { $win64Directory } else { $binariesDirectory }
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden

$startedProcess = $null
$editorProcess = $null
$editorWindowHandle = [IntPtr]::Zero
$editorWindowTitle = ''
$passed = $false

try {
    $startedProcess = [Diagnostics.Process]::Start($startInfo)
    if ($null -eq $startedProcess) {
        throw "Failed to start $($startInfo.FileName)."
    }

    if ($Direct) {
        $editorProcess = $startedProcess
    }
    else {
        if (-not $startedProcess.WaitForExit(15000)) {
            throw 'UDKLift did not complete its editor handoff within 15 seconds.'
        }

        $handoffDeadline = [datetime]::UtcNow.AddSeconds(15)
        do {
            $child = Get-CimInstance Win32_Process -Filter "Name='UDK.exe'" -ErrorAction SilentlyContinue |
                Where-Object {
                    $existingUdkProcessIds -notcontains [int]$_.ProcessId -and
                    $_.CommandLine -like "*$logName*"
                } |
                Select-Object -First 1
            if ($null -ne $child) {
                $editorProcess = Get-Process -Id ([int]$child.ProcessId) -ErrorAction Stop
                break
            }
            Start-Sleep -Milliseconds 200
        } while ([datetime]::UtcNow -lt $handoffDeadline)

        if ($null -eq $editorProcess) {
            throw 'UDKLift did not create the expected UDK editor child process.'
        }
    }

    $startupDeadline = [datetime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
    $engineInitialized = $false
    $mapInitialized = $false
    do {
        $editorProcess.Refresh()
        if ($editorProcess.HasExited) {
            throw "The editor exited before startup completed. Inspect $logPath"
        }

        if ($editorProcess.MainWindowHandle -ne [IntPtr]::Zero) {
            $editorWindowHandle = $editorProcess.MainWindowHandle
            if (-not [string]::IsNullOrWhiteSpace($editorProcess.MainWindowTitle)) {
                $editorWindowTitle = $editorProcess.MainWindowTitle
            }
            [void][UDKLiftEditorWindow]::ShowWindowAsync($editorWindowHandle, 0)
        }

        if (Test-Path -LiteralPath $logPath) {
            $logText = Get-Content -LiteralPath $logPath -Raw
            $engineInitialized = $logText.Contains('Initializing Engine Completed')
            $mapInitialized = $logText.Contains('TIMER ALL OF INIT')
        }

        if ($engineInitialized -and $mapInitialized -and $editorWindowHandle -ne [IntPtr]::Zero) {
            break
        }
        Start-Sleep -Milliseconds 250
    } while ([datetime]::UtcNow -lt $startupDeadline)

    if (-not ($engineInitialized -and $mapInitialized -and $editorWindowHandle -ne [IntPtr]::Zero)) {
        throw "The editor did not reach the complete UI startup gate within $StartupTimeoutSeconds seconds. Inspect $logPath"
    }

    $editorProcess.Refresh()
    if (-not $editorProcess.Responding) {
        throw 'The initialized editor window is not responding.'
    }
    if ($editorWindowTitle -match '(?i)duke') {
        throw "Deprecated Duke branding is still active: $editorWindowTitle"
    }
    if ($editorWindowTitle -notmatch '(?i)Unreal (Editor|Development Kit)') {
        throw "Unexpected editor title: $editorWindowTitle"
    }

    $badPattern = 'Fatal error|Critical:|Error:|Failed to load|Warning:'
    $badLines = @(Select-String -LiteralPath $logPath -Pattern $badPattern)
    if ($badLines.Count -ne 0) {
        throw "The initialized editor log contains diagnostics:`n$($badLines.Line -join [Environment]::NewLine)"
    }

    Start-Sleep -Seconds $StabilitySeconds
    $editorProcess.Refresh()
    if ($editorProcess.HasExited -or -not $editorProcess.Responding) {
        throw "The editor did not remain healthy for the $StabilitySeconds-second stability interval."
    }

    $badLines = @(Select-String -LiteralPath $logPath -Pattern $badPattern)
    if ($badLines.Count -ne 0) {
        throw "The stable editor log contains diagnostics:`n$($badLines.Line -join [Environment]::NewLine)"
    }

    if (-not [UDKLiftEditorWindow]::PostMessage($editorWindowHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)) {
        throw 'Failed to send WM_CLOSE to the editor window.'
    }
    if (-not $editorProcess.WaitForExit(30000)) {
        throw 'The editor did not shut down within 30 seconds after WM_CLOSE.'
    }

    $finalLogText = Get-Content -LiteralPath $logPath -Raw
    if (-not $finalLogText.Contains('Exit: Editor shut down') -or
        -not $finalLogText.Contains('Exit: Object subsystem successfully closed.')) {
        throw "The editor process exited without the complete clean-shutdown markers. Inspect $logPath"
    }

    $passed = $true
    Write-Host "Interactive editor boot passed: $logPath"
}
finally {
    if (-not $passed -and $null -ne $editorProcess) {
        $editorProcess.Refresh()
        if (-not $editorProcess.HasExited) {
            $actualPath = $editorProcess.Path
            if ([IO.Path]::GetFullPath($actualPath) -eq [IO.Path]::GetFullPath($udkExecutable)) {
                Stop-Process -Id $editorProcess.Id -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
