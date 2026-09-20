/**
 * Default game type for a clean UDK starter project.
 *
 * This intentionally derives from Engine.GameInfo instead of UTGame so PIE
 * does not enter the legacy tournament readiness, countdown, announcer, or
 * score-match lifecycle.
 */
class UDKStarterGameInfo extends GameInfo
	config(Game);

/**
 * A local starter session has no online session to transition. Mark its
 * replication state as started directly; retain the engine's normal online
 * path for listen and dedicated servers.
 */
function StartOnlineGame()
{
	if (WorldInfo.NetMode == NM_Standalone)
	{
		GameReplicationInfo.StartMatch();
	}
	else
	{
		Super.StartOnlineGame();
	}
}

auto state PendingMatch
{
Begin:
	StartMatch();
}

defaultproperties
{
	HUDType=class'GameFramework.MobileHUD'
	PlayerControllerClass=class'UDKStarter.UDKStarterPlayerController'
	DefaultPawnClass=class'UDKStarter.UDKStarterPawn'
	bDelayedStart=false
	bRestartLevel=false
}
