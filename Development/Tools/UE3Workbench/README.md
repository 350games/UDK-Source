# UE3 Workbench

UE3 Workbench is the local settings shell for the recovered UTGame/UDK build.
Its **Settings** menu separates project-facing configuration from editor-wide
preferences, following the Unreal/UDK workflow.

Build it from this directory:

```powershell
msbuild .\UE3Workbench.csproj /t:Rebuild /m:1 /p:Configuration=Release /p:Platform=AnyCPU
```

Launch it from the repository root after building:

```powershell
.\Binaries\UE3Workbench.exe
```

You can open either settings window directly with:

```powershell
.\Binaries\UE3Workbench.exe editor-settings
.\Binaries\UE3Workbench.exe project-settings
```

## Settings menu

**Project Settings** contains:

- **Rendering**: current UE3 graphics values (OpenGL initialization,
  high-quality materials, post-process MLAA, and VSync), plus clearly labeled
  intent for future Direct3D 11/12, Vulkan, OpenGL, SM5, HDR, and threaded
  rendering work.
- **Plugins**: project-local plugin policy and the reserved
  `UTGame\Plugins` location. A plugin host is not yet implemented, so the UI
  does not claim that plugins can currently load.
- **Misc**: project display name, build/diagnostic preferences, and a validated
  startup-map picker from `UTGame\Content\Maps`.

Applying Project Settings updates only supported configuration:

- `DefaultEngine.ini` and `UTEngine.ini`: `[URL]` `Map` and `LocalMap`
- `UTSystemSettings.ini`: the four current graphics values above
- `UE3Workbench.ini`: Workbench-only project intent, preserving the splash
  section and any future Workbench sections

**Editor Settings** contains:

- **General**: startup level and editor audio/volume
- **Viewports**: flight camera, realtime viewports, orthographic linking, and
  legacy viewport interaction options
- **Saving & Source Control**: autosave, undo buffer, and source-control
  preferences
- **Splash & Branding**: default UE3 or custom splash artwork

Editor preferences are written to `UTGame\Config\UTEditorUserSettings.ini`.
Close the UE3 editor before applying them, as a running editor can overwrite
its user configuration on exit.

The two splash modes are:

- **Default UE3** uses the supplied UE3 artwork from `Binaries\Splash` and writes a native-safe 24-bit project override.
- **Custom image** copies a user-selected 650 × 375, 24-bit BMP.

The selected art is applied to both `UTGame\Splash\PC\EdSplash.bmp` and
`UTGame\Splash\PC\Splash.bmp`, which the native engine checks before
`Engine\Splash`. Previous project override files are backed up under
`UTGame\Splash\UE3Workbench\Backups`; other Workbench settings in
`UTGame\Config\UE3Workbench.ini` are preserved.

Leave the lower 44 pixels clear for editor status text and the lower 26 pixels
clear for game copyright text.
