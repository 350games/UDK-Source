# Legacy Duke engine hooks

These recovered hooks were removed from shared engine execution so a normal UDK
editor/game launch cannot call them. They are retained here for reference.

## Forced startup movie

The shared Bink initialization unconditionally executed:

```cpp
StartupMovieNames.AddUniqueItem(TEXT("DukeIntro"));
```

Startup movies are now read only from the active game's `[FullScreenMovie]`
configuration.

## Editor and splash branding

The editor frame returned `Duke's Enormous Tool 2004` for every build, and the
splash text used `Duke's Enormous Tool 2004 (Loading Please Wait...)`. The active
code now uses the existing localized UDK title/version formats.

## Recovered behavior overrides

The recovered source also carried `jmarshall` edits that disabled normal UDK
behavior: perspective Play-In-Editor ignored the viewport start position, game
asset database warnings were suppressed, animation changes during notifies were
allowed despite the crash guard, and splash progress updates were discarded.
Those overrides have been removed from active source. The unused Duke-only
`FVector::GetXAxisVector`, `GetYAxisVector`, and `GetZAxisVector` additions were
also removed; their definitions returned `(1,0,0)`, `(0,1,0)`, and `(0,0,1)`.

