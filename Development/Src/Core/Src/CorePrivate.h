/*=============================================================================
	CorePrivate.h: compatibility forwarding header.
	Copyright 1998-2013 Epic Games, Inc. All Rights Reserved.
=============================================================================*/

// The source-directory copy was an unguarded pre-UE3 header whose declarations
// no longer match Core.  Preserve legacy includes while routing them to the
// current guarded private header used by the project manifest and PCH.
#ifndef _INC_COREPRIVATE_SOURCE_FORWARDER
#define _INC_COREPRIVATE_SOURCE_FORWARDER
#include "../Inc/CorePrivate.h"
#endif
