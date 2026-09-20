// Build adapter for the legacy TinyXML sources retained by UnrealEd. Keep the
// compatibility define local to this third-party code instead of suppressing
// secure-CRT diagnostics across the engine.
#if defined(_MSC_VER) && !defined(_CRT_SECURE_NO_WARNINGS)
#define _CRT_SECURE_NO_WARNINGS
#endif

#include "tinystr.cpp"
#include "tinyxml.cpp"
#include "tinyxmlerror.cpp"
#include "tinyxmlparser.cpp"
