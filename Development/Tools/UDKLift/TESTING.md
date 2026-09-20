# UDKLift editor forwarding

UDKLift is the root launcher and elevation helper for the source-built UDK
editor. Editor launch arguments are no longer blocked: supported spellings are
normalized to the canonical `editor` token and forwarded to the matching
`Binaries\Win64\UDK.exe` or `Binaries\Win32\UDK.exe` target.

After changing `Program.cs`, rebuild and verify the Release launcher with:

```powershell
msbuild .\UDKLift.csproj /t:Rebuild /m:1 /p:Configuration=Release /p:Platform=AnyCPU
.\Verify-EditorLaunchGuard.ps1
```

The verifier rejects any remaining editor guard and tests normalization,
elevation-token detection, Windows argument quoting, `UDKLift.exe` to
`UDK.exe` mapping, OS-architecture target selection, and the
non-preferred-32-bit project settings.

By default it also performs a hidden commandlet forwarding smoke. The launcher
receives an editor-form token after `PerformMapCheck ExampleEntry.udk`, so the
native editor engine loads and checks the supplied map while the forwarded
token is visible as canonical `editor` in the child command line. Keeping the
map-check commandlet first prevents the interactive editor from opening. The
unique log must report one map checked, zero errors, and zero warnings.
Use `-SkipLaunchSmoke` only while iterating on helper logic when an executable
launch is intentionally unavailable; it is not sufficient for final release
validation.

After the complete build and commandlet verifier succeed, run the real hidden
D3D editor acceptance test. This exercises the wx UI, template-map load,
branding, stability interval, and normal editor shutdown through UDKLift:

```powershell
.\Verify-InteractiveEditorBoot.ps1
```

The interactive verifier rejects every fatal, critical, error, failed-load, or
warning line and any deprecated Duke title. Use `-Direct` to test `UDK.exe`
without the launcher. This is the release gate that proves the editor actually
boots; the commandlet smoke alone is not sufficient.

To verify the native startup splash itself, including the separate lower-left
version and loading rows, run:

```powershell
.\Verify-SplashLayout.ps1
```

This launches through UDKLift without `-nosplash`, captures the real splash
window, and confirms a clean editor startup and shutdown afterwards. Active
PC splash artwork is neutral UDK art; preserved Duke artwork is retained only
under `Deprecated\Duke\Splash`.

After the editor boot gate passes, exercise the default starter game through a
real Play In Editor session:

```powershell
.\Verify-StarterPIE.ps1
```

This verifier dynamically invokes the editor's native **Play > In Editor**
command, uses the normal PIE save and `PLAYWORLD` reload path, and requires the
map to select `UDKStarterGameInfo` without a game URL override. It also rejects
the legacy press-fire/readiness countdown, `START MATCH`, and any runtime
diagnostics before closing the editor cleanly. Use `-Direct` to bypass UDKLift
while diagnosing the native editor; the default UDKLift path is the release
gate.

The **Blank Map** choice intentionally creates a genuinely empty map. It is
expected to have no sky, lights, or `PlayerStart` until the level author adds
them; this is the normal UDK blank-map behavior. The renderer acceptance probe
checks that this empty editor viewport is not the erroneous solid-red output.

To leave the editor open for normal use after all release verifiers pass, run:

```powershell
.\Binaries\UDKLift.exe editor
```
