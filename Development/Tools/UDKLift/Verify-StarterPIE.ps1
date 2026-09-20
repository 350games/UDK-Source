<#
.SYNOPSIS
    Verifies that the default UDK starter game runs through a real PIE session.

.DESCRIPTION
    Launches the native editor through UDKLift by default, waits for the editor
    and its template map to finish initializing, and invokes the native
    Play > In Editor command through the editor's Win32 menu. The verifier uses
    standard PIE (not USEFASTPIE), so the PIE save and PLAYWORLD reload path are
    both exercised.

    The run must select UDKStarterGameInfo without a URL override, finish PIE
    startup without the legacy UT readiness/countdown lifecycle or diagnostics,
    remain responsive briefly, and then complete a clean editor shutdown.

.EXAMPLE
    .\Verify-StarterPIE.ps1

.EXAMPLE
    .\Verify-StarterPIE.ps1 -Direct
#>
[CmdletBinding()]
param(
    [switch]$Direct,

    [ValidateRange(5, 300)]
    [int]$StartupTimeoutSeconds = 120,

    [ValidateRange(15, 600)]
    [int]$PIETimeoutSeconds = 240,

    [ValidateRange(3, 60)]
    [int]$StabilitySeconds = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class UDKLiftStarterPIEWindow
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr GetMenu(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetMenuItemCount(IntPtr hMenu);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr GetSubMenu(IntPtr hMenu, int nPos);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetMenuItemID(IntPtr hMenu, int nPos);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int GetMenuString(
        IntPtr hMenu,
        uint uIDItem,
        StringBuilder lpString,
        int cchMax,
        uint flags);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
}
'@

function ConvertTo-NormalizedMenuLabel {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Label
    )

    return (($Label -replace '&', '') -replace "`t.*$", '').Trim()
}

function Get-NativeMenuEntry {
    param(
        [Parameter(Mandatory = $true)]
        [IntPtr]$MenuHandle,

        [string[]]$ParentPath = @()
    )

    $entryCount = [UDKLiftStarterPIEWindow]::GetMenuItemCount($MenuHandle)
    if ($entryCount -lt 0) {
        throw 'Failed to enumerate the native editor menu.'
    }

    for ($position = 0; $position -lt $entryCount; $position++) {
        $labelBuffer = [Text.StringBuilder]::new(512)
        [void][UDKLiftStarterPIEWindow]::GetMenuString(
            $MenuHandle,
            [uint32]$position,
            $labelBuffer,
            $labelBuffer.Capacity,
            0x0400) # MF_BYPOSITION

        $rawLabel = $labelBuffer.ToString()
        $label = ConvertTo-NormalizedMenuLabel -Label $rawLabel
        $subMenuHandle = [UDKLiftStarterPIEWindow]::GetSubMenu($MenuHandle, $position)
        $hasSubMenu = $subMenuHandle -ne [IntPtr]::Zero
        $path = if ([string]::IsNullOrWhiteSpace($label)) {
            @($ParentPath)
        }
        else {
            @($ParentPath + $label)
        }

        [pscustomobject]@{
            Id           = [UDKLiftStarterPIEWindow]::GetMenuItemID($MenuHandle, $position)
            Label        = $label
            RawLabel     = $rawLabel
            Path         = $path
            DisplayPath  = $path -join ' > '
            HasSubMenu   = $hasSubMenu
        }

        if ($hasSubMenu) {
            Get-NativeMenuEntry -MenuHandle $subMenuHandle -ParentPath $path
        }
    }
}

function Get-LogText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return ''
    }

    return Get-Content -LiteralPath $Path -Raw
}

function Assert-CleanStarterPIELog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Stage
    )

    $diagnosticPattern = 'Fatal error|Critical:|Error:|ScriptError|ScriptWarning|Failed to load|Failed to create|Warning:'
    $diagnostics = @(Select-String -LiteralPath $Path -Pattern $diagnosticPattern)
    if ($diagnostics.Count -ne 0) {
        throw "$Stage contains diagnostics:`n$($diagnostics.Line -join [Environment]::NewLine)"
    }

    $legacyPattern = 'Press\s+FIRE|Press\s+Fire|START MATCH|Match begins in|count[ -]?down|UTStartupMessage'
    $legacyLines = @(Select-String -LiteralPath $Path -Pattern $legacyPattern)
    if ($legacyLines.Count -ne 0) {
        throw "$Stage entered the deprecated match-start lifecycle:`n$($legacyLines.Line -join [Environment]::NewLine)"
    }
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$binariesDirectory = Join-Path $repoRoot 'Binaries'
$win64Directory = Join-Path $binariesDirectory 'Win64'
$udkExecutable = Join-Path $win64Directory 'UDK.exe'
$launcherExecutable = Join-Path $binariesDirectory 'UDKLift.exe'
$logDirectory = Join-Path $repoRoot 'UTGame\Logs'

foreach ($requiredPath in @($udkExecutable, $launcherExecutable, $logDirectory)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required starter-PIE input is missing: $requiredPath"
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$logName = "UDKStarterPIE-$stamp.log"
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
            [void][UDKLiftStarterPIEWindow]::ShowWindowAsync($editorWindowHandle, 0) # SW_HIDE
        }

        $logText = Get-LogText -Path $logPath
        $engineInitialized = $logText.Contains('Initializing Engine Completed')
        $mapInitialized = $logText.Contains('TIMER ALL OF INIT')

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

    Assert-CleanStarterPIELog -Path $logPath -Stage 'Editor startup'

    $mainMenuHandle = [UDKLiftStarterPIEWindow]::GetMenu($editorWindowHandle)
    if ($mainMenuHandle -eq [IntPtr]::Zero) {
        throw 'The initialized editor window has no native menu.'
    }

    $menuEntries = @(Get-NativeMenuEntry -MenuHandle $mainMenuHandle)
    $playCommands = @(
        $menuEntries | Where-Object {
            -not $_.HasSubMenu -and
            ($_.Path -join '|') -eq 'Play|In Editor'
        }
    )
    if ($playCommands.Count -ne 1) {
        $availablePlayEntries = @(
            $menuEntries |
                Where-Object { $_.DisplayPath -match '(?i)play|editor' } |
                ForEach-Object { $_.DisplayPath }
        )
        throw "Expected one native 'Play > In Editor' command but found $($playCommands.Count). Relevant entries: $($availablePlayEntries -join '; ')"
    }

    $playCommand = $playCommands[0]
    if ($playCommand.Id -eq [uint32]::MaxValue -or $playCommand.Id -eq ([uint32]::MaxValue - 1)) {
        throw "The discovered PIE menu entry has an invalid command ID: $($playCommand.Id)"
    }

    if (-not [UDKLiftStarterPIEWindow]::PostMessage(
            $editorWindowHandle,
            0x0111, # WM_COMMAND
            [IntPtr]([long]$playCommand.Id),
            [IntPtr]::Zero)) {
        throw "Failed to invoke '$($playCommand.DisplayPath)' through WM_COMMAND."
    }

    $pieDeadline = [datetime]::UtcNow.AddSeconds($PIETimeoutSeconds)
    $starterGameSelected = $false
    $standardPIELoaded = $false
    $pieCompleted = $false
    do {
        Start-Sleep -Milliseconds 250
        $editorProcess.Refresh()
        if ($editorProcess.HasExited) {
            throw "The editor exited while PIE was starting. Inspect $logPath"
        }

        $logText = Get-LogText -Path $logPath
        $starterGameSelected = $logText -match "Game class is 'UDKStarterGameInfo'"
        $standardPIELoaded = $logText -match 'MAP LOAD PLAYWORLD=1'
        $pieCompleted = $logText -match 'PIE: play in editor start time for'

        if ($starterGameSelected -and $standardPIELoaded -and $pieCompleted) {
            break
        }
    } while ([datetime]::UtcNow -lt $pieDeadline)

    if (-not ($starterGameSelected -and $standardPIELoaded -and $pieCompleted)) {
        throw "PIE did not reach the complete standard startup gate within $PIETimeoutSeconds seconds (starter game: $starterGameSelected; PLAYWORLD load: $standardPIELoaded; PIE completion: $pieCompleted). Inspect $logPath"
    }

    Assert-CleanStarterPIELog -Path $logPath -Stage 'PIE startup'

    Start-Sleep -Seconds $StabilitySeconds
    $editorProcess.Refresh()
    if ($editorProcess.HasExited -or -not $editorProcess.Responding) {
        throw "The PIE editor process did not remain healthy for the $StabilitySeconds-second stability interval."
    }

    Assert-CleanStarterPIELog -Path $logPath -Stage 'Stable PIE session'

    if (-not [UDKLiftStarterPIEWindow]::PostMessage(
            $editorWindowHandle,
            0x0010, # WM_CLOSE
            [IntPtr]::Zero,
            [IntPtr]::Zero)) {
        throw 'Failed to send WM_CLOSE to the editor window.'
    }
    if (-not $editorProcess.WaitForExit(30000)) {
        throw 'The editor did not shut down within 30 seconds after WM_CLOSE.'
    }
    # A process object rediscovered after the UDKLift handoff does not retain
    # an exit-code handle on every PowerShell/.NET combination. The direct
    # process does, while the handoff path is gated by the complete native
    # clean-shutdown markers below.
    if ($Direct -and $editorProcess.ExitCode -ne 0) {
        throw "The editor exited with code $($editorProcess.ExitCode). Inspect $logPath"
    }

    $finalLogText = Get-LogText -Path $logPath
    if (-not $finalLogText.Contains('Exit: Editor shut down') -or
        -not $finalLogText.Contains('Exit: Object subsystem successfully closed.')) {
        throw "The editor process exited without the complete clean-shutdown markers. Inspect $logPath"
    }
    Assert-CleanStarterPIELog -Path $logPath -Stage 'Completed starter PIE run'

    $passed = $true
    Write-Host "Starter PIE passed through '$($playCommand.DisplayPath)' (command ID $($playCommand.Id)): $logPath"
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
