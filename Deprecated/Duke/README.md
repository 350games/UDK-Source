# Deprecated Duke integration

Status: **deprecated and excluded from the default UDK startup path**.

This directory preserves the Duke-specific integration that was recovered with
the source tree. The active `UDK` and `UTGame` targets use the normal UDK title,
configuration-driven startup movies, and the stock editor/runtime behavior.
Nothing in this directory is loaded by an ordinary editor or game launch.

Some shared launch files still contain `DUKEGAME` preprocessor branches. Those
branches are dormant for `UDK`/`UTGame` and remain in place because moving code
out of a shared translation unit would make the explicitly selected legacy
target harder to recover. Duke packages whose Unreal object paths are embedded
in assets must likewise remain at their original package paths; moving those
binary packages would break serialized references. They are not selected by the
default maps or game configuration.

Preserved material:

- `Localization/UnrealEd-Duke-legacy.int`: the original UTF-16 localization
  file before the Duke editor branding was replaced.
- `LegacyEngineHooks.md`: the removed hardwired branding, startup movie, and
  behavior overrides, retained as source history.
- `Source/UE3-Duke-projects-legacy.sln`: the original solution before its three
  missing Duke project entries and their deprecated solution folders were
  removed from the active UE3 solution.
- `Source/UnrealBuildTool/UE3BuildDukeGame.cs`: the optional legacy build-target
  definition, if present. It is explicitly selected only by `DUKEGAME` and is
  never used for `UDK` or `UTGame`.
