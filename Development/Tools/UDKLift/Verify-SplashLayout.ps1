<#
.SYNOPSIS
    Captures the real editor splash screen and verifies its lower-left text layout.

.DESCRIPTION
    Launches the editor through UDKLift by default without -nosplash, captures
    the native SplashScreenClass window after both editor status strings have
    been set, and then lets the editor finish a normal startup and shutdown.
    The source assertion prevents the version and startup-progress labels from
    sharing a row again.
#>
[CmdletBinding()]
param(
    [switch]$Direct,

    [ValidateRange(5, 60)]
    [int]$SplashTimeoutSeconds = 20,

    [ValidateRange(10, 300)]
    [int]$StartupTimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public struct UDKLiftSplashRect
{
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

public static class UDKLiftSplashWindow
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "FindWindowW")]
    public static extern IntPtr FindWindowByClass(string lpClassName, IntPtr lpWindowName);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetWindowRect(IntPtr hWnd, out UDKLiftSplashRect lpRect);

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
$splashSource = Join-Path $repoRoot 'Development\Src\Engine\Src\SplashScreen.cpp'

foreach ($requiredPath in @($udkExecutable, $launcherExecutable, $logDirectory, $splashSource)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required splash-verification input is missing: $requiredPath"
    }
}

$splashSourceText = Get-Content -LiteralPath $splashSource -Raw
$versionRowPattern = 'VersionInfo1\s*\]\s*\.top\s*=\s*bm\.bmHeight\s*-\s*44\s*;'
$progressRowPattern = 'StartupProgress\s*\]\s*\.top\s*=\s*bm\.bmHeight\s*-\s*20\s*;'
if (-not [Text.RegularExpressions.Regex]::IsMatch($splashSourceText, $versionRowPattern) -or
    -not [Text.RegularExpressions.Regex]::IsMatch($splashSourceText, $progressRowPattern)) {
    throw 'The editor splash source does not reserve distinct rows for version information and startup progress.'
}

$existingSplashWindow = [UDKLiftSplashWindow]::FindWindowByClass('SplashScreenClass', [IntPtr]::Zero)
if ($existingSplashWindow -ne [IntPtr]::Zero) {
    throw 'An existing UDK splash window is already active. Close it before running this verifier.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$logName = "UDKLiftSplashLayout-$stamp.log"
$logPath = Join-Path $logDirectory $logName
$screenshotPath = Join-Path $logDirectory "UDKLiftSplashLayout-$stamp.png"
$existingUdkProcessIds = @(
    Get-CimInstance Win32_Process -Filter "Name='UDK.exe'" -ErrorAction SilentlyContinue |
        ForEach-Object { [int]$_.ProcessId }
)

$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = if ($Direct) { $udkExecutable } else { $launcherExecutable }
$editorToken = if ($Direct) { 'editor' } else { '-editor' }
$startInfo.Arguments = "$editorToken -unattended -nopause -forcelogflush -windowed -ResX=800 -ResY=600 -log=$logName"
$startInfo.WorkingDirectory = if ($Direct) { $win64Directory } else { $binariesDirectory }
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden

$startedProcess = $null
$editorProcess = $null
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

    $splashDeadline = [datetime]::UtcNow.AddSeconds($SplashTimeoutSeconds)
    $splashWindow = [IntPtr]::Zero
    do {
        $editorProcess.Refresh()
        if ($editorProcess.HasExited) {
            throw "The editor exited before its splash screen was shown. Inspect $logPath"
        }

		$splashWindow = [UDKLiftSplashWindow]::FindWindowByClass('SplashScreenClass', [IntPtr]::Zero)
        if ($splashWindow -ne [IntPtr]::Zero) {
            break
        }
        Start-Sleep -Milliseconds 100
    } while ([datetime]::UtcNow -lt $splashDeadline)

    if ($splashWindow -eq [IntPtr]::Zero) {
        throw "The editor splash window was not visible within $SplashTimeoutSeconds seconds. Inspect $logPath"
    }

    # Give the splash thread time to populate both the version and initial
    # startup-progress strings before copying the native window pixels.
    Start-Sleep -Milliseconds 750
    $splashRect = New-Object UDKLiftSplashRect
    if (-not [UDKLiftSplashWindow]::GetWindowRect($splashWindow, [ref]$splashRect)) {
        throw 'Could not read the splash window bounds.'
    }
    $width = $splashRect.Right - $splashRect.Left
    $height = $splashRect.Bottom - $splashRect.Top
    if ($width -le 0 -or $height -le 0) {
        throw "The splash window has invalid bounds: ${width}x${height}."
    }

    $bitmap = New-Object Drawing.Bitmap($width, $height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($splashRect.Left, $splashRect.Top, 0, 0, $bitmap.Size)
        $bitmap.Save($screenshotPath, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }

    $startupDeadline = [datetime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
    do {
        $editorProcess.Refresh()
        if ($editorProcess.HasExited) {
            throw "The editor exited before it completed startup. Inspect $logPath"
        }

        if (Test-Path -LiteralPath $logPath) {
            $logText = Get-Content -LiteralPath $logPath -Raw
            if ($logText.Contains('TIMER ALL OF INIT')) {
                break
            }
        }
        Start-Sleep -Milliseconds 250
    } while ([datetime]::UtcNow -lt $startupDeadline)

    if (-not (Test-Path -LiteralPath $logPath) -or
        -not (Get-Content -LiteralPath $logPath -Raw).Contains('TIMER ALL OF INIT')) {
        throw "The editor did not complete startup within $StartupTimeoutSeconds seconds. Inspect $logPath"
    }

    $editorProcess.Refresh()
    if ($editorProcess.MainWindowHandle -eq [IntPtr]::Zero -or -not $editorProcess.Responding) {
        throw 'The initialized editor window is not responding.'
    }
    if (-not [UDKLiftSplashWindow]::PostMessage($editorProcess.MainWindowHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)) {
        throw 'Failed to send WM_CLOSE to the editor after splash capture.'
    }
    if (-not $editorProcess.WaitForExit(30000)) {
        throw 'The editor did not shut down within 30 seconds after splash capture.'
    }

    $finalLogText = Get-Content -LiteralPath $logPath -Raw
    if (-not $finalLogText.Contains('Exit: Editor shut down') -or
        -not $finalLogText.Contains('Exit: Object subsystem successfully closed.')) {
        throw "The editor exited without clean-shutdown markers. Inspect $logPath"
    }

    $passed = $true
    Write-Host "Splash layout passed; captured native editor splash: $screenshotPath"
}
finally {
    if (-not $passed -and $null -ne $editorProcess) {
        $editorProcess.Refresh()
        if (-not $editorProcess.HasExited) {
            try {
                if ([IO.Path]::GetFullPath($editorProcess.Path) -eq [IO.Path]::GetFullPath($udkExecutable)) {
                    Stop-Process -Id $editorProcess.Id -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                # The original failure is more useful than a cleanup failure.
            }
        }
    }
}
