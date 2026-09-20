# Unreal Engine 3 (10897) CUSTOM BUILD, README NOT UP TO DATE!

A list of useful references that people may need.

## Recovered self-contained UTGame and editor build

Build the runtime, UnrealScript packages, and editor from the repository root
with PowerShell:

```powershell
.\Build-LocalUTGame.ps1
```

The default is the complete `Win64 Release` path. It rebuilds the following
from the recovered source tree:

- the Release `UE3ShaderCompileWorker`;
- the complete Win64 Unicode Release wxWidgets DLL/import-library graph;
- AutoReporter, the managed Swarm Agent, Coordinator, and interfaces, plus
  Release `UnrealLightmass`;
- `UnrealBuildTool` and the Release `UTGameScriptCompiler`;
- the native C++ headers generated from UnrealScript, followed by a second
  script-compiler build against those headers;
- all nine configured `.u` packages, with UnrealScript warnings treated as
  errors; and
- the requested `UTGame.exe` and `UDK.exe` configurations.

The build refuses a concurrent invocation, removes each selected output before
rebuilding it, verifies the architecture and identity of the generated native
and managed binaries, and runs an isolated local-source Swarm Agent startup
check. It finishes by running the read-only native, dependency, retained-content,
and script-package preflight. A failed stage stops the build; a stale executable
is not accepted in place of a failed rebuild.

To build multiple runtime/editor configurations sequentially, use:

```powershell
.\Build-LocalUTGame.ps1 -Configuration Release,Debug,Shipping
```

Win32 uses the same source-build sequence:

```powershell
.\Build-LocalUTGame.ps1 -Platform Win32 -Configuration Release
```

For the default build, the platform-native outputs include
`Binaries\Win64\UE3ShaderCompileWorker.exe`,
`Binaries\Win64\UTGameScriptCompiler.exe`,
`Binaries\Win64\UnrealLightmass.exe`, `Binaries\Win64\UTGame.exe`, and
`Binaries\Win64\UDK.exe`. AutoReporter and the managed Swarm outputs are under
`Binaries`. Debug and Shipping runtime/editor names include the platform and
configuration suffix; editor/build support tools remain Release builds.

The generated package set under `UTGame\Script` is `Core.u`, `Engine.u`,
`GFxUI.u`, `IpDrv.u`, `GameFramework.u`, `UnrealEd.u`, `WinDrv.u`,
`OnlineSubsystemPC.u`, and `UTGame.u`. These files are compiled from
`Development\Src`; they are not copied from either supplied UDK template tree.

The workflow compiles the code and script assets present in this repository.
The exact compatible content dependency closure needed by the editor was
restored from the supplied `UDK Ultimate` reference tree with SHA-256 checks;
unrelated template/game payloads are not copied.

`Restore-LocalUTGameContent.ps1` makes that restoration reproducible. It reads
`Required-LocalUTGameContent.txt`, copies only missing packages, never
overwrites an existing package, and hash-verifies the full 39-package closure.
The complete build invokes it before native compilation.

Before attempting to launch a previously built runtime, run the complete
read-only preflight:

```powershell
.\Test-LocalUTGameRuntime.ps1 -Platform Win64 -Configuration Release -RequireAllNativeOutputs
```

Without `-RequireAllNativeOutputs`, the preflight checks the selected runtime
and, by default, all nine runtime/editor packages against the authoritative
`Development\Src` package-version rules. Use `-RuntimeOnly` to check the eight
runtime packages without requiring `UnrealEd.u`. The preflight never launches
a process or copies template payloads, so its success is necessary build
evidence rather than a substitute for the final runtime and interactive editor
smoke tests.

The `UDKsource code and templates\UDK Game` and `UDK Ultimate` trees remain
reference material. Passing a package header-range check alone does not prove
that a template package matches the recovered native class graph.

## Editor launch

The complete build produces the source-built editor directly at
`Binaries\Win64\UDK.exe` (or the selected platform/configuration equivalent).

**Launcher release status: unlocked and verified.** The temporary recovery
guard has been removed from `Development\Tools\UDKLift\Program.cs`, and the
root Release `Binaries\UDKLift.exe` has been rebuilt from that source. The
default forwarding verifier passed both its reflection/source checks and a
hidden end-to-end launch: UDKLift normalized `-editor` to canonical `editor`,
selected the root Win64 `UDK.exe`, loaded and checked `ExampleEntry.udk`, and
closed the editor engine with zero errors and zero warnings. The real hidden
D3D/wx acceptance test also reached the editor UI, loaded the template map,
remained responsive, and shut down cleanly with zero diagnostics. The
reproducible acceptance procedure is documented in
`Development\Tools\UDKLift\TESTING.md`.

Root `Binaries\UDKLift.exe` now forwards `editor`, `-editor`, `/editor`, and
`--editor` to the source-built native editor. The interactive user test is:

```powershell
.\Binaries\UDKLift.exe editor
```

Use `Development\Tools\UDKLift\Verify-InteractiveEditorBoot.ps1` for automated
release validation; it hides the real editor, checks its log/UI/stability, and
closes it normally. The visible command above is for normal editor use.

The recovered Duke-specific defaults are no longer called by UDK/UTGame. Their
original localization, solution, build-target definition, and removed engine
hooks are retained under `Deprecated\Duke` with a deprecation manifest; binary
packages that require fixed Unreal object paths remain unmoved and unselected.

The launchers and shortcuts inside the supplied template trees are reference
artifacts and are not part of the root build or launch path.

## Variables
- GNames
  - [UnrealEngine3/Development/Src/Core/Inc/UnName.h#L572](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnName.h#L572)
- GObjects
  - [UnrealEngine3/Development/Src/Core/Inc/UnObjBas.h#L1178](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnObjBas.h#L1178)
- GMalloc
  - [UnrealEngine3/Development/Src/Core/Src/Core.cpp#L390](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Src/Core.cpp#L390)
  - [UnrealEngine3/Development/LightmassCore/Inc/LMMemory.h#L109](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Tools/UnrealLightmass/LightmassCore/Inc/LMMemory.h#L109)
  - [UnrealEngine3/Development/LightmassCore/Src/LMMemory.cpp#L14](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Tools/UnrealLightmass/LightmassCore/Src/LMMemory.cpp#L14)
  - [UnrealEngine3/Development/LightmassCore/Src/LMMemory.cpp#L49](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Tools/UnrealLightmass/LightmassCore/Inc/LMMemory.h#L49)

 ## Files
- AES Encryption & Decryption
  - [UnrealEngine3/Development/Src/Core/Src/AES.cpp](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Src/AES.cpp)
- FColorList RGB Values
  - [UnrealEngine3/Runtime/Core/Private/Math/ColorList.cpp#L212](https://github.com/EpicGames/UnrealEngine/blob/release/Engine/Source/Runtime/Core/Private/Math/ColorList.cpp#L212)

## Functions
- ProcessEvent
  - [UnrealEngine3/Development/Src/Core/Src/UnCorSc.cpp#L6270](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Src/UnCorSc.cpp#L6270)
- ProcessInternal
  - [UnrealEngine3/Development/Src/Core/Src/UnCorSc.cpp#L6191](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Src/UnCorSc.cpp#L6191)
- ProcessDelegate
  - [UnrealEngine3/Development/Src/Core/Src/UnCorSc.cpp#L6408](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Src/UnCorSc.cpp#L6408)
- CallFunction
  - [UnrealEngine3/Development/Src/Core/Src/UnCorSc.cpp#L5933](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Src/UnCorSc.cpp#L5933)
- GCreateMalloc
  - [UnrealEngine3/Development/Src/Launch/Src/LaunchEngineLoop.cpp#L248](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Launch/Src/LaunchEngineLoop.cpp#L248)
- LoadFileAndDecrypt
  - [UnrealEngine3/Development/Src/Engine/Src/ScriptPlatformInterface.cpp#L31](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Engine/Src/ScriptPlatformInterface.cpp#L31)
- appLoadFileToArray
  - [UnrealEngine3/Development/Src/Core/Src/UnMisc.cpp#L3222](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Src/UnMisc.cpp#L3222)

## Classes
- UObject
  - [UnrealEngine3/Development/Src/Core/Inc/UnObjBas.h#L1070](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnObjBas.h#L1070)
- UPackage
  - [UnrealEngine3/Development/Src/Core/Inc/UnCorObj.h#L133](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnCorObj.h#L133)
- UField
  - [UnrealEngine3/Development/Src/Core/Inc/UnClass.h#L79](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnClass.h#L79)
- UEnum
  - [UnrealEngine3/Development/Src/Core/Inc/UnClass.h#L519](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnClass.h#L519)
- UConst
  - [UnrealEngine3/Development/Src/Core/Inc/UnClass.h#L983](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnClass.h#L983)
- UProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L135](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L135)
- UStruct
  - [UnrealEngine3/Development/Src/Core/Inc/UnClass.h#L171](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnClass.h#L171)
- UFunction
  - [UnrealEngine3/Development/Src/Core/Inc/UnClass.h#L377](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnClass.h#L377)
- UScriptStruct
  - [UnrealEngine3/Development/Src/Core/Inc/UnClass.h#L320](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnClass.h#L320)
- UState
  - [UnrealEngine3/Development/Src/Core/Inc/UnClass.h#L468](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnClass.h#L468)
- UClass
  - [UnrealEngine3/Development/Src/Core/Inc/UnClass.h#L632](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnClass.h#L632)
- UStructProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L1353](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L1353)
- UStrProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L1089](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L1089)
- UObjectProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L784](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L784)
- UClassProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L933](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L933)
- UComponentProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L896](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L896)
- UNameProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L1053](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L1053)
- UMapProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L1233](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L1233)
- UIntProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L658](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L658)
- UInterfaceProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L980](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L980)
- UFloatProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L747](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L747)
- UDelegateProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L1461](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L1461)
- UByteProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L607](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L607)
- UBoolProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L695](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L695)
- UArrayProperty
  - [UnrealEngine3/Development/Src/Core/Inc/UnType.h#L1129](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnType.h#L1129)

## Structs
- FMalloc
  - [UnrealEngine3/Development/Tools/UnrealLightmass/LightmassCore/Inc/LMMemory.h#L49](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Tools/UnrealLightmass/LightmassCore/Inc/LMMemory.h#L49)
- FGuid
  - [UnrealEngine3/Engine/Source/Runtime/Core/Public/Misc/Guid.h#L108](https://github.com/EpicGames/UnrealEngine/blob/release/Engine/Source/Runtime/Core/Public/Misc/Guid.h#L108)
- FNameEntry
  - [UnrealEngine3/Development/Src/Core/Inc/UnName.h#L74](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnName.h#L74)
- FName
  - [UnrealEngine3/Development/Src/Core/Inc/UnName.h#L262](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnName.h#L262)
- FScriptDelegate
  - [UnrealEngine3/Development/Src/Core/Inc/UnObjBas.h#L3454](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnObjBas.h#L3454)
- FOutputDevice
  - [UnrealEngine3/Development/Src/Core/Inc/Core.h #L702](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/Core.h#L702)
- FFrame
  - [UnrealEngine3/Development/Src/Core/Inc/UnStack.h#L283](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Core/Inc/UnStack.h#L283)
- FResource
  - [UnrealEngine3/Development/Src/Engine/Inc/RenderResource.h](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Engine/Inc/RenderResource.h)
- FTextureResource
  - [UnrealEngine3/Development/Src/Engine/Inc/RenderResource.h#L47](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/Engine/Inc/UnTex.h#L47)
- FD3D11Texture
  - [UnrealEngine3/Development/Src/D3D11Drv/Inc/D3D11Resources.h#L72](https://github.com/CodeRedModding/UnrealEngine3/blob/main/Development/Src/D3D11Drv/Inc/D3D11Resources.h#L72)
