# Local UTGame project

This directory contains the configuration, UnrealScript source tree, generated
script-package output directory, and the game content that is present in this
snapshot. Run `..\Build-LocalUTGame.ps1` from the repository root to generate
the native headers and compile the matching `.u` packages directly from
`Development\Src`; external package restoration is not part of the supported
build.

The source-built runtime targets Windows 10 or newer and uses the system
`D3DCompiler_47.dll` and `XAudio2_9.dll`. The build cannot fabricate maps,
localization, movies, or gameplay assets that are not present in the snapshot.
