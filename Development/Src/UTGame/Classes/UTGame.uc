// ====================================================================
// (C) 2004, Epic Games
// ====================================================================

class UTGame extends GameInfo
	config(Game)
	abstract;

var config bool					bWeaponStay;              // Whether or not weapons stay when picked up.
var bool bAllowMPGameSpeed;
var bool					bTeamScoreRounds;
var bool					bSoaking;
var bool			bPlayersVsBots;

var string CallSigns[15];
var string Acronym;

var globalconfig int ServerSkillLevel;	// The Server Skill Level ( 0 - 2, Beginner/Experienced/Expert )
var globalconfig float		EndTimeDelay;
var globalconfig float		BotRatio;			// only used when bPlayersVsBots is true
var config int 	NetWait;       // time to wait for players in netgames w/ bWaitForNetPlayers (typically team games)
var globalconfig int	MinNetPlayers; // how many players must join before net game will start
var globalconfig int	RestartWait;

var globalconfig bool	bTournament;  // number of players must equal maxplayers for game to start
var globalconfig bool	bAutoNumBots;	// Match bots to map's recommended bot count
var globalconfig bool	bPlayersMustBeReady;// players must confirm ready for game to start
var config bool			bForceRespawn;
var globalconfig bool    bWaitForNetPlayers;     // wait until more than MinNetPlayers players have joined before starting match
var bool	bFirstBlood;
var bool	bQuickStart;
var bool	bSkipPlaySound;		// override "play!" sound
var bool	bStartedCountDown;
var bool	bFinalStartup;
var bool	bOverTimeBroadcast;
var bool bMustHaveMultiplePlayers;
var bool bPlayerBecameActive;
var bool    bMustJoinBeforeStart;   // players can only spectate if they join after the game starts
var globalconfig bool			bWeaponShouldViewShake;
var bool						bModViewShake;			// for mutators to turn off weaponviewshake

var byte StartupStage;              // what startup message to display
var int NumRounds;
var int MinPlayers;

var config float		SpawnProtectionTime;
var int			DefaultMaxLives;
var config int			LateEntryLives;	// defines how many lives in a player can still join

var int RemainingTime, ElapsedTime;
var int CountDown;
var float AdjustedDifficulty;
var int PlayerKills, PlayerDeaths;

var NavigationPoint LastPlayerStartSpot;    // last place player looking for start spot started from
var NavigationPoint LastStartSpot;          // last place any player started from

var float EndTime;
var int             EndMessageWait;         // wait before playing which team won the match
var transient int   EndMessageCounter;      // end message counter

var   string			      RulesMenuType;			// Type of rules menu to display.
var   string				  GameUMenuType;			// Type of Game dropdown to display.

var actor EndGameFocus;

var() int                     ResetCountDown;
var() config int              ResetTimeDelay;           // time (seconds) before restarting teams

var array<Vehicle> VehicleList;

// FIXME - temporary properties for gravity setting tweaks
var float GravityModifier;
var float JumpModifier;

/** Replaces the localized kill-message name tokens used by UT damage types. */
static function string ParseKillMessage(string KillerName, string VictimName, string DeathMessage)
{
	return Repl(Repl(DeathMessage, "\`k", KillerName), "\`o", VictimName);
}

function PostBeginPlay()
{
	Super.PostBeginPlay();

	// FIXMESTEVE TEMP hardcode gravity
	WorldInfo.WorldGravityZ = -475.0 * GravityModifier;
    GameReplicationInfo.RemainingTime = RemainingTime;

}

/* SetPlayerDefaults()
 first make sure pawn properties are back to default, then give mutators an opportunity
 to modify them
*/
function SetPlayerDefaults(Pawn PlayerPawn)
{
	Super.SetPlayerDefaults(PlayerPawn);
	PlayerPawn.JumpZ = PlayerPawn.JumpZ * JumpModifier;
	UTPawn(PlayerPawn).DodgeSpeedZ = UTPawn(PlayerPawn).DodgeSpeedZ * JumpModifier;
	UTPawn(PlayerPawn).DodgeSpeed = UTPawn(PlayerPawn).DodgeSpeed * JumpModifier;
}

function bool BecomeSpectator(PlayerController P)
{
	if ( (P.PlayerReplicationInfo == None) || !GameReplicationInfo.bMatchHasBegun
	     || (NumSpectators >= MaxSpectators) || P.IsInState('GameEnded') || P.IsInState('RoundEnded') )
	{
		P.ReceiveLocalizedMessage(GameMessageClass, 12);
		return false;
	}

	P.PlayerReplicationInfo.bOnlySpectator = true;
	NumSpectators++;
	NumPlayers--;

	return true;
}

function bool AllowBecomeActivePlayer(PlayerController P)
{
	if ( (P.PlayerReplicationInfo == None) || !GameReplicationInfo.bMatchHasBegun || bMustJoinBeforeStart
	     || (NumPlayers >= MaxPlayers) || (MaxLives > 0) || P.IsInState('GameEnded') || P.IsInState('RoundEnded') )
	{
		P.ReceiveLocalizedMessage(GameMessageClass, 13);
		return false;
	}
	return true;
}

/* Reset()
reset actor to initial state - used when restarting level without reloading.
*/
function Reset()
{
    Super.Reset();
    ElapsedTime = NetWait - 3;
    bWaitForNetPlayers = ( WorldInfo.NetMode != NM_StandAlone );
	bStartedCountDown = false;
	bFinalStartup = false;
    CountDown = Default.Countdown;
    RemainingTime = 60 * TimeLimit;
    GotoState('PendingMatch');
}

/* FIXMESTEVE
function SetWeaponViewShake(PlayerController P)
{
	P.ClientSetWeaponViewShake(bWeaponShouldViewShake && bModViewShake);
}
*/

function bool SkipPlaySound()
{
	return bQuickStart || bSkipPlaySound;
}

function bool AllowGameSpeedChange()
{
	return bAllowMPGameSpeed || (WorldInfo.NetMode == NM_Standalone);
}

//
// Set gameplay speed.
//
function SetGameSpeed( Float T )
{
	if ( !AllowGameSpeedChange() )
		WorldInfo.TimeDilation = 1.1;
	else
	{
		GameSpeed = FMax(T, 0.1);
		WorldInfo.TimeDilation = 1.1 * GameSpeed;
	}
    SetTimer(WorldInfo.TimeDilation, true);
}


function ScoreKill(Controller Killer, Controller Other)
{
	local PlayerReplicationInfo OtherPRI;

	OtherPRI = Other.PlayerReplicationInfo;
    if ( OtherPRI != None )
    {
        OtherPRI.NumLives++;
        if ( (MaxLives > 0) && (OtherPRI.NumLives >=MaxLives) )
            OtherPRI.bOutOfLives = true;
    }

	/* FIXMESTEVE
	if ( bAllowTaunts && (Killer != None) && (Killer != Other) && Killer.AutoTaunt()
		&& (Killer.PlayerReplicationInfo != None) && (Killer.PlayerReplicationInfo.VoiceType != None) )
	{
		if( Killer.IsA('PlayerController') )
			Killer.SendMessage(OtherPRI, 'AUTOTAUNT', Killer.PlayerReplicationInfo.VoiceType.static.PickRandomTauntFor(Killer, false, false), 10, 'GLOBAL');
		else
			Killer.SendMessage(OtherPRI, 'AUTOTAUNT', Killer.PlayerReplicationInfo.VoiceType.static.PickRandomTauntFor(Killer, false, true), 10, 'GLOBAL');
	}
	*/
    Super.ScoreKill(Killer,Other);

    if ( (killer == None) || (Other == None) )
        return;
/* FIXMESTEVE
    if ( bAdjustSkill && (killer.IsA('PlayerController') || Other.IsA('PlayerController')) )
    {
        if ( killer.IsA('AIController') )
            AdjustSkill(AIController(killer), PlayerController(Other),true);
        if ( Other.IsA('AIController') )
            AdjustSkill(AIController(Other), PlayerController(Killer),false);
    }
*/
}

// Monitor killed messages for fraglimit
function Killed( Controller Killer, Controller Killed, Pawn KilledPawn, class<DamageType> damageType )
{
	//local int		Score;
	//local string	KillInfo;
	//local vehicle V;

	if ( UTBot(Killed) != None )
		UTBot(Killed).WasKilledBy(Killer);

	/*FIXMESTEVE
	if ( KilledPawn != None && KilledPawn.GetSpree() > 4 )
	{
		if ( bEnemyKill && (Killer != None) )
			Killer.AwardAdrenaline(ADR_MajorKill);
		EndSpree(Killer, Killed);
	}
	if ( (Killer != None) && Killer.bIsPlayer && (Killed != None) && Killed.bIsPlayer )
	{
		if ( UnrealPlayer(Killer) != None )
			UnrealPlayer(Killer).LogMultiKills(ADR_MajorKill, bEnemyKill);

		if ( bEnemyKill )
			DamageType.static.ScoreKill(Killer, Killed);

		if ( !bFirstBlood && (Killer != Killed) && bEnemyKill )
		{
			Killer.AwardAdrenaline(ADR_MajorKill);
			bFirstBlood = True;
			BroadcastLocalizedMessage( class'FirstBloodMessage', 0, Killer.PlayerReplicationInfo );
			SpecialEvent(Killer.PlayerReplicationInfo,"first_blood");
		}
		if ( Killer == Killed )
			Killer.AwardAdrenaline(ADR_MinorError);
		else if ( bTeamGame && (Killed.PlayerReplicationInfo.Team == Killer.PlayerReplicationInfo.Team) )
			Killer.AwardAdrenaline(ADR_KillTeamMate);
		else
		{
			Killer.AwardAdrenaline(ADR_Kill);
			if ( UTPawn(Killer.Pawn) != None )
			{
				UTPawn(Killer.Pawn).IncrementSpree();
				if ( UTPawn(Killer.Pawn).GetSpree() > 4 )
					NotifySpree(Killer, UTPawn(Killer.Pawn).GetSpree());
			}
		}
	}

	// Vehicle Score Kill
	if ( Killer != None && Killer.bIsPlayer && Killer.PlayerReplicationInfo != None && Vehicle(KilledPawn) != None
	     && (Killed != None || Vehicle(KilledPawn).bEjectDriver) && Vehicle(KilledPawn).IndependentVehicle() )
	{
		Score = VehicleScoreKill( Killer, Killed, Vehicle(KilledPawn), KillInfo );
		if ( Score > 0 )
		{
			// if driver(s) have been ejected from vehicle, Killed == None
			if ( Killed != None )
			{
				if ( !bEnemyKill && Killed.PlayerReplicationInfo != None )
				{
					Score		= -Score;					// substract score if team kill.
					KillInfo	= "TeamKill_" $ KillInfo;
				}
			}

			if ( Score != 0 )
			{
				Killer.PlayerReplicationInfo.Score += Score;
				Killer.PlayerReplicationInfo.NetUpdateTime	= WorldInfo.TimeSeconds - 1;
				ScoreEvent(Killer.PlayerReplicationInfo, Score, KillInfo);
			}
		}
	}
	*/
    super.Killed(Killer, Killed, KilledPawn, damageType);

	/* FIXMESTEVE
    if ( bAllowVehicles && (WorldInfo.NetMode == NM_Standalone) && (PlayerController(Killed) != None) )
    {
		// tell bots not to get into nearby vehicles
		for ( V=VehicleList; V!=None; V=V.NextVehicle )
			if ( WorldInfo.GRI.OnSameTeam(Killed,V) )
				V.PlayerStartTime = 0;
	}
	*/
}

/* special scorekill function for vehicles
 Note that it is called only once per independant vehicle (ie not for attached turrets subclass)
 If a player is killed inside, normal scorekill will also be applied (so extra points for killed players)
 */
function int VehicleScoreKill( Controller Killer, Controller Killed, Vehicle DestroyedVehicle, out string KillInfo )
{
	//log("VehicleScoreKill Killer:" @ Killer.GetHumanReadableName() @ "Killed:" @ Killed @ "DestroyedVehicle:" @ DestroyedVehicle );

	// Broadcast vehicle kill message if killed no player inside
	/* FIXMESTEVE
	if ( Killed == None && PlayerController(Killer) != None )
		PlayerController(Killer).TeamMessage( Killer.PlayerReplicationInfo, YouDestroyed@DestroyedVehicle.VehicleNameString@YouDestroyedTrailer, 'CriticalEvent' );

	if ( KillInfo == "" )
	{
		if ( DestroyedVehicle.bKeyVehicle || DestroyedVehicle.bHighScoreKill )
		{
			KillInfo = "destroyed_key_vehicle";
			return 5;
		}
	}
	*/
	return 0;
}


// Parse options for this game...
event InitGame( string Options, out string Error )
{
    local string InOpt;

    Super.InitGame(Options, Error);

    SetGameSpeed(GameSpeed);
    MaxLives = Max(0,GetIntOption( Options, "MaxLives", MaxLives ));
    if ( MaxLives > 0 )
		bForceRespawn = true;
	else if ( DefaultMaxLives > 0 )
	{
		bForceRespawn = true;
		MaxLives = DefaultMaxLives;
	}
    GoalScore = Max(0,GetIntOption( Options, "GoalScore", GoalScore ));
    TimeLimit = Max(0,GetIntOption( Options, "TimeLimit", TimeLimit ));
	if ( DefaultMaxLives > 0 )
		TimeLimit = 0;

	// FIXME - temporary properties for gravity setting tweaks
	InOpt = ParseOption( Options, "Gravity");
    if ( InOpt != "" )
    {
		GravityModifier = float(InOpt);
		JumpModifier = sqrt(GravityModifier);
	}

	/* FIXMESTEVE
	InOpt = ParseOption( Options, "Translocator");
    // For instant action, use map defaults
    if ( InOpt != "" )
    {
        log("Translocators: "$bool(InOpt));
        bAllowTrans = bool(InOpt);
    }
    InOpt = ParseOption( Options, "bAutoNumBots");
    if ( InOpt != "" )
    {
        log("bAutoNumBots: "$bool(InOpt));
        bAutoNumBots = bool(InOpt);
    }
    if ( bTeamGame && (WorldInfo.NetMode != NM_Standalone) )
    {
		InOpt = ParseOption( Options, "VsBots");
		if ( InOpt != "" )
		{
			log("bPlayersVsBots: "$bool(InOpt));
			bPlayersVsBots = bool(InOpt);
		}
		if ( bPlayersVsBots )
			bAutoNumBots = false;
	}
    InOpt = ParseOption( Options, "AutoAdjust");
    if ( InOpt != "" )
    {
        bAdjustSkill = !bTeamGame && bool(InOpt);
        log("Adjust skill "$bAdjustSkill);
    }
    InOpt = ParseOption( Options, "PlayersMustBeReady");
    if ( InOpt != "" )
    {
    	log("PlayerMustBeReady: "$Bool(InOpt));
        bPlayersMustBeReady = bool(InOpt);
    }

	EnemyRosterName = ParseOption( Options, "DMTeam");
	if ( EnemyRosterName != "" )
		bCustomBots = true;

    // SP
    if ( single player match )
    {
		MaxLives = 0;
		bAllowTrans = default.bDefaultTranslocator;
        bAdjustSkill = false;
    }

    if (HasOption(Options, "NumBots"))
    	bAutoNumBots = false;
    if (bAutoNumBots && WorldInfo.NetMode == NM_Standalone)
    {
        LevelMinPlayers = GetMinPlayers();

		if ( bTeamgame && bMustHaveMultiplePlayers )
		{
			if ( LevelMinPlayers < 4 )
				LevelMinPlayers = 4;
			else if ( (LevelMinPlayers & 1) == 1 )
				LevelMinPlayers++;
		}
		else if( LevelMinPlayers < 2 )
            LevelMinPlayers = 2;

        InitialBots = Max(0,LevelMinPlayers - 1);
    }
    else
    {
        MinPlayers = Clamp(GetIntOption( Options, "MinPlayers", MinPlayers ),0,32);
        InitialBots = Clamp(GetIntOption( Options, "NumBots", InitialBots ),0,32);
        if ( bPlayersVsBots )
			MinPlayers = 2;
    }
	*/
    RemainingTime = 60 * TimeLimit;

    InOpt = ParseOption( Options, "WeaponStay");
    if ( InOpt != "" )
    {
        `log("WeaponStay: "$bool(InOpt));
        bWeaponStay = bool(InOpt);
    }

	if ( bTournament )
		bTournament = (GetIntOption( Options, "Tournament", 1 ) > 0);
	else
		bTournament = (GetIntOption( Options, "Tournament", 0 ) > 0);

    // FIXMESTEVE if ( bTournament )
    //    CheckReady();
    bWaitForNetPlayers = ( WorldInfo.NetMode != NM_StandAlone );

    InOpt = ParseOption(Options,"QuickStart");
    if ( InOpt != "" )
		bQuickStart = true;

    AdjustedDifficulty = GameDifficulty;
}

event PlayerController Login
(
    string Portal,
    string Options,
    const UniqueNetID UniqueID,
    out string Error
)
{
	local PlayerController NewPlayer;
	local Controller C;
    local string    InSex;

	if ( MaxLives > 0 )
	{
		// check that game isn't too far along
		foreach WorldInfo.AllControllers(class'Controller', C)
		{
			if ( (C.PlayerReplicationInfo != None) && (C.PlayerReplicationInfo.NumLives > LateEntryLives) )
			{
				Options = "?SpectatorOnly=1"$Options;
				break;
			}
		}
	}

	NewPlayer = Super.Login(Portal, Options, UniqueID, Error);

	if ( UTPlayerController(NewPlayer) != None )
	{
		InSex = ParseOption(Options, "Sex");
		if ( Left(InSex,1) ~= "F" )
			UTPlayerController(NewPlayer).SetPawnFemale();	// only effective if character not valid

		if ( bMustJoinBeforeStart && GameReplicationInfo.bMatchHasBegun )
			UTPlayerController(NewPlayer).bLatecomer = true;

		// custom voicepack
		UTPlayerReplicationInfo(NewPlayer.PlayerReplicationInfo).VoiceTypeName = ParseOption ( Options, "Voice");
	}

/* FIXMESTEVE
	if ( WorldInfo.NetMode == NM_Standalone )
	{
		if( NewPlayer.PlayerReplicationInfo.bOnlySpectator )
		{
			// Compensate for the space left for the player
			if ( !bCustomBots && (bAutoNumBots || (bTeamGame && (InitialBots%2 == 1))) )
				InitialBots++;
		}
	}
*/
	return NewPlayer;
}

/* FIXMESTEVE
function string RecommendCombo(string ComboName)
{
	return ComboName;
}

function string NewRecommendCombo(string ComboName, AIController C)
{
	local string NewComboName;

	NewComboName = RecommendCombo(ComboName);
	if (NewComboName != ComboName)
		return NewComboName;

	return BaseMutator.NewRecommendCombo(ComboName, C);
}
*/

function KillEvent(string Killtype, PlayerReplicationInfo Killer, PlayerReplicationInfo Victim, class<DamageType> Damage)
{
}

function actor FindSpecGoalFor(PlayerReplicationInfo PRI, int TeamIndex)
{
	return none;
}


function GameEvent(string GEvent, string Desc, PlayerReplicationInfo Who)
{
}

function ScoreEvent(PlayerReplicationInfo Who, float Points, string Desc)
{
}

function TeamScoreEvent(int Team, float Points, string Desc)
{
}

function int GetNumPlayers()
{
	if ( NumPlayers > 0 )
		return Max(NumPlayers, Min(NumPlayers+NumBots, MaxPlayers-1));
	return NumPlayers;
}

function bool ShouldRespawn(PickupFactory Other)
{
	return true;
}

function float SpawnWait(AIController B)
{
	if ( B.PlayerReplicationInfo.bOutOfLives )
		return 999;
	if ( WorldInfo.NetMode == NM_Standalone )
	{
		if ( NumBots < 4 )
			return 0;
		return ( 0.5 * FMax(2,NumBots-4) * FRand() );
	}
	if ( bPlayersVsBots )
		return 0;
	return FRand();
}

function bool TooManyBots(Controller botToRemove)
{
	if ( (WorldInfo.NetMode != NM_Standalone) && bPlayersVsBots )
		return ( NumBots > Min(16,BotRatio*NumPlayers) );
	if ( bPlayerBecameActive )
	{
		bPlayerBecameActive = false;
		return true;
	}
	return ( (WorldInfo.NetMode != NM_Standalone) && (NumBots + NumPlayers > MinPlayers) );
}

function RestartGame()
{
	if ( bGameRestarted )
		return;
	/* FIXMESTEVE
    if ( single player match )
    {
		CurrentGameProfile.ContinueSinglePlayerGame(Level);
		return;
	}
	*/
	if ( EndTime > WorldInfo.TimeSeconds ) // still showing end screen
		return;

	Super.RestartGame();
}


function bool CheckEndGame(PlayerReplicationInfo Winner, string Reason)
{
    local Controller P;
    local PlayerController Player;
    local bool bLastMan;

	if ( bOverTime )
	{
		if ( Numbots + NumPlayers == 0 )
			return true;
		bLastMan = true;
		foreach WorldInfo.AllControllers(class'Controller', P)
			if ( (P.PlayerReplicationInfo != None) && !P.PlayerReplicationInfo.bOutOfLives )
			{
				bLastMan = false;
				break;
			}
		if ( bLastMan )
			return true;
	}

    bLastMan = ( Reason ~= "LastMan" );

	/*FIXMESTEVE
    if ( !bLastMan && (GameRulesModifiers != None) && !GameRulesModifiers.CheckEndGame(Winner, Reason) )
        return false;
*/
	if ( Winner == None )
	{
		// find winner
		foreach WorldInfo.AllControllers(class'Controller', P)
			if ( P.bIsPlayer && !P.PlayerReplicationInfo.bOutOfLives
				&& ((Winner == None) || (P.PlayerReplicationInfo.Score >= Winner.Score)) )
			{
				Winner = P.PlayerReplicationInfo;
			}
	}

    // check for tie
    if ( !bLastMan )
    {
		foreach WorldInfo.AllControllers(class'Controller', P)
		{
			if ( P.bIsPlayer &&
				(Winner != P.PlayerReplicationInfo) &&
				(P.PlayerReplicationInfo.Score == Winner.Score)
				&& !P.PlayerReplicationInfo.bOutOfLives )
			{
				if ( !bOverTimeBroadcast )
				{
					StartupStage = 7;
					PlayStartupMessage();
					bOverTimeBroadcast = true;
				}
				return false;
			}
		}
	}

    EndTime = WorldInfo.TimeSeconds + EndTimeDelay;
    GameReplicationInfo.Winner = Winner;

    EndGameFocus = Controller(Winner.Owner).Pawn;
    if ( EndGameFocus != None )
		EndGameFocus.bAlwaysRelevant = true;
    foreach WorldInfo.AllControllers(class'Controller', P)
    {
        Player = PlayerController(P);
        if ( Player != None )
        {
			if ( !Player.PlayerReplicationInfo.bOnlySpectator )
	            PlayWinMessage(Player, (Player.PlayerReplicationInfo == Winner));
            //FIXMESTEVE Player.ClientSetBehindView(true);
            if ( EndGameFocus != None )
            {
				Player.ClientSetViewTarget(EndGameFocus);
                Player.SetViewTarget(EndGameFocus);
            }
        }
        P.GameHasEnded(EndGameFocus, (P.PlayerReplicationInfo != None) && (P.PlayerReplicationInfo == Winner));
    }
    return true;
}

function PlayWinMessage(PlayerController Player, bool bWinner)
{
	/* FIXMESTEVE
	if ( UTPlayerController(Player) != None )
		UTPlayerController(Player).PlayWinMessage(bWinner);
	*/
}

function bool AtCapacity(bool bSpectator)
{
	local Controller C;
	local bool bForcedSpectator;

    if ( WorldInfo.NetMode == NM_Standalone )
        return false;

	if ( bPlayersVsBots )
		MaxPlayers = Min(MaxPlayers,16);

    if ( MaxLives <= 0 )
		return Super.AtCapacity(bSpectator);

	foreach WorldInfo.AllControllers(class'Controller', C)
	{
		if ( (C.PlayerReplicationInfo != None) && (C.PlayerReplicationInfo.NumLives > LateEntryLives) )
		{
			bForcedSpectator = true;
			break;
		}
	}
	if ( !bForcedSpectator )
		return Super.AtCapacity(bSpectator);

	return ( NumPlayers + NumSpectators >= MaxPlayers + MaxSpectators );
}

event PostLogin( playercontroller NewPlayer )
{
	Super.PostLogin(NewPlayer);

	if ( UTPlayerController(NewPlayer) != None )
	{
		//FIXMESTEVE UTPlayerController(NewPlayer).ClientReceiveLoginMenu(LoginMenuClass, bAlwaysShowLoginMenu);
		UTPlayerController(NewPlayer).PlayStartUpMessage(StartupStage);
		//FIXMESTEVE SetWeaponViewShake(NewPlayer);
	}
}

function RestartPlayer( Controller aPlayer )
{
	//local Vehicle V, Best;
	//local vector ViewDir;
	//local float BestDist, Dist;

	/* FIXMESTEVE
    if ( bMustJoinBeforeStart && (UTPlayerController(aPlayer) != None)
        && UTPlayerController(aPlayer).bLatecomer )
        return;
	*/
    if ( aPlayer.PlayerReplicationInfo.bOutOfLives )
        return;

    if ( aPlayer.IsA('Bot') && TooManyBots(aPlayer) )
    {
        aPlayer.Destroy();
        return;
    }
    Super.RestartPlayer(aPlayer);
/* FIXMESTEVE
    if ( bAllowVehicles && (WorldInfo.NetMode == NM_Standalone) && (PlayerController(aPlayer) != None) )
    {
		// tell bots not to get into nearby vehicles for a little while
		BestDist = 2000;
		ViewDir = vector(aPlayer.Pawn.Rotation);
		for ( V=VehicleList; V!=None; V=V.NextVehicle )
			if ( V.bTeamLocked && WorldInfo.GRI.OnSameTeam(aPlayer,V) )
			{
				Dist = VSize(V.Location - aPlayer.Pawn.Location);
				if ( (ViewDir Dot (V.Location - aPlayer.Pawn.Location)) < 0 )
					Dist *= 2;
				if ( Dist < BestDist )
				{
					Best = V;
					BestDist = Dist;
				}
			}

		if ( Best != None )
			Best.PlayerStartTime = WorldInfo.TimeSeconds + 8;
	}
*/
}

function AddDefaultInventory( pawn PlayerPawn )
{
    if ( UTPawn(PlayerPawn) != None )
        UTPawn(PlayerPawn).AddDefaultInventory();
    SetPlayerDefaults(PlayerPawn);
}

function bool CanSpectate(PlayerController Viewer, PlayerReplicationInfo ViewTarget)
{
	return (ViewTarget != None) && !ViewTarget.bOnlySpectator
		&& ((WorldInfo.NetMode == NM_Standalone) || Viewer.PlayerReplicationInfo.bOnlySpectator);
}

function ChangeName(Controller Other, string S, bool bNameChange)
{
    local Controller APlayer;

    if ( S == "" )
        return;

    if ( Other.PlayerReplicationInfo.playername~=S )
        return;

	S = Left(S,20);
    ReplaceText(S, " ", "_");

    foreach WorldInfo.AllControllers(class'Controller', APlayer)
        if ( APlayer.bIsPlayer && (APlayer.PlayerReplicationInfo.playername~=S) )
        {
            if ( Other.IsA('PlayerController') )
            {
                PlayerController(Other).ReceiveLocalizedMessage( GameMessageClass, 8 );
				return;
			}
			/* FIXMESTEVE
			else
			{
				if ( Other.PlayerReplicationInfo.bIsFemale )
				{
					S = FemaleBackupNames[FemaleBackupNameOffset%32];
					FemaleBackupNameOffset++;
				}
				else
				{
					S = MaleBackupNames[MaleBackupNameOffset%32];
					MaleBackupNameOffset++;
				}
				foreach WorldInfo.AllControllers(class'Controller', P)
					if ( P.bIsPlayer && (P.PlayerReplicationInfo.playername~=S) )
					{
						S = NamePrefixes[NameNumber%10]$S$NameSuffixes[NameNumber%10];
						NameNumber++;
						break;
					}
				break;
			}
            S = NamePrefixes[NameNumber%10]$S$NameSuffixes[NameNumber%10];
            NameNumber++;
            break;
			*/
        }

	if( bNameChange )
		GameEvent("NameChange",s,Other.PlayerReplicationInfo);

    Other.PlayerReplicationInfo.SetPlayerName(S);
}

function Logout(controller Exiting)
{
    Super.Logout(Exiting);
	/* FIXMESTEVE
    if ( Exiting.IsA('Bot') )
        NumBots--;
    if ( !bKillBots )
		RemainingBots++;
    if ( !NeedPlayers() || AddBot() )
        RemainingBots--;
	*/
    if ( MaxLives > 0 )
         CheckMaxLives(none);
	//VotingHandler.PlayerExit(Exiting);
}

function bool NeedPlayers()
{
	/* FIXMESTEVE
    if ( WorldInfo.NetMode == NM_Standalone )
        return ( RemainingBots > 0 );
    if ( bMustJoinBeforeStart )
        return false;
    if ( bPlayersVsBots )
		return ( NumBots < Min(16,BotRatio*NumPlayers) );
    return (NumPlayers + NumBots < MinPlayers);
	*/
	return false;
}

function InitGameReplicationInfo()
{
    Super.InitGameReplicationInfo();
    GameReplicationInfo.GoalScore = GoalScore;
    GameReplicationInfo.TimeLimit = TimeLimit;
    UTGameReplicationInfo(GameReplicationInfo).MinNetPlayers = MinNetPlayers;
}

/* FIXMESTEVE
function ReduceDamage( out int Damage, pawn injured, pawn instigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType )
{
    local float InstigatorSkill;

	if ( (instigatedBy != None) && (InstigatedBy != Injured) && (WorldInfo.TimeSeconds - injured.SpawnTime < SpawnProtectionTime)
		&& (class<WeaponDamageType>(DamageType) != None || class<VehicleDamageType>(DamageType) != None) )
		return 0;

    Damage = Super.ReduceDamage( Damage, injured, InstigatedBy, HitLocation, Momentum, DamageType );

    if ( instigatedBy == None)
        return Damage;

    if ( WorldInfo.Game.GameDifficulty <= 3 )
    {
        if ( injured.IsPlayerPawn() && (injured == instigatedby) && (WorldInfo.NetMode == NM_Standalone) )
            Damage *= 0.5;

        //skill level modification
        if ( (AIController(instigatedBy.Controller) != None)
			&& ((WorldInfo.NetMode == NM_Standalone) || (TurretController(InstigatedBy.Controller) != None)) )
        {
            InstigatorSkill = AIController(instigatedBy.Controller).Skill;
            if ( (InstigatorSkill <= 3) && injured.IsHumanControlled() )
			{
				if ( ((instigatedBy.Weapon != None) && instigatedBy.Weapon.bMeleeWeapon)
					|| ((injured.Weapon != None) && injured.Weapon.bMeleeWeapon && (VSize(injured.location - instigatedBy.Location) < 600)) )
						Damage = Damage * (0.76 + 0.08 * InstigatorSkill);
				else
						Damage = Damage * (0.25 + 0.15 * InstigatorSkill);
            }
        }
    }
    Damage = Damage * instigatedBy.DamageScaling);
}
*/

function NotifySpree(Controller Other, int num)
{
	/* FIXMESTEVE
	local Controller C;

	if ( num == 5 )
		num = 0;
	else if ( num == 10 )
		num = 1;
	else if ( num == 15 )
		num = 2;
	else if ( num == 20 )
		num = 3;
	else if ( num == 25 )
		num = 4;
	else if ( num == 30 )
		num = 5;
	else
		return;

	SpecialEvent(Other.PlayerReplicationInfo,"spree_"$(num+1));
	Other.AwardAdrenaline( ADR_MajorKill );

	foreach WorldInfo.AllControllers(class'Controller', C)
		if ( PlayerController(C) != None )
			PlayerController(C).ReceiveLocalizedMessage( class'KillingSpreeMessage', Num, Other.PlayerReplicationInfo );
	*/
}

function EndSpree(Controller Killer, Controller Other)
{
	/*FIXMESTEVE
	local Controller C;

	if ( (Other == None) || !Other.bIsPlayer )
		return;
	foreach WorldInfo.AllControllers(class'Controller', C)
		if ( PlayerController(C) != None )
		{
			if ( (Killer == Other) || (Killer == None) || !Killer.bIsPlayer )
				PlayerController(C).ReceiveLocalizedMessage( class'KillingSpreeMessage', 1, None, Other.PlayerReplicationInfo );
			else
				PlayerController(C).ReceiveLocalizedMessage( class'KillingSpreeMessage', 0, Other.PlayerReplicationInfo, Killer.PlayerReplicationInfo );
		}
	*/
}

//------------------------------------------------------------------------------
// Game States

function StartMatch()
{

    GotoState('MatchInProgress');
	/* FIXMESTEVE
    if ( WorldInfo.NetMode == NM_Standalone )
        RemainingBots = InitialBots;
    else
        RemainingBots = 0;
	*/
    GameReplicationInfo.RemainingMinute = RemainingTime;
    Super.StartMatch();
	/*FIXMESTEVE
    bTemp = bMustJoinBeforeStart;
    bMustJoinBeforeStart = false;
    while ( NeedPlayers() && (Num<16) )
    {
		if ( AddBot() )
			RemainingBots--;
		Num++;
    }
    bMustJoinBeforeStart = bTemp;
	*/
    `log("START MATCH");
}

function EndGame(PlayerReplicationInfo Winner, string Reason )
{
    if ( (Reason ~= "triggered") ||
         (Reason ~= "LastMan")   ||
         (Reason ~= "TimeLimit") ||
         (Reason ~= "FragLimit") ||
         (Reason ~= "TeamScoreLimit") )
    {
        Super.EndGame(Winner,Reason);
        if ( bGameEnded )
            GotoState('MatchOver');
    }
}

/* FindPlayerStart()
returns the 'best' player start for this player to start from.
*/
function NavigationPoint FindPlayerStart(Controller Player, optional byte InTeam, optional string incomingName)
{
    local NavigationPoint Best;

    if ( (Player != None) && (Player.StartSpot != None) )
        LastPlayerStartSpot = Player.StartSpot;

    Best = Super.FindPlayerStart(Player, InTeam, incomingName );
    if ( Best != None )
        LastStartSpot = Best;
    return Best;
}

function bool DominatingVictory()
{
	return ( (PlayerReplicationInfo(GameReplicationInfo.Winner).Deaths == 0)
		&& (PlayerReplicationInfo(GameReplicationInfo.Winner).Score >= 5) );
}

function bool IsAWinner(PlayerController C)
{
	return ( C.PlayerReplicationInfo.bOnlySpectator || (C.PlayerReplicationInfo == GameReplicationInfo.Winner) );
}

function PlayEndOfMatchMessage()
{
	local controller C;

    if ( DominatingVictory() )
    {
		foreach WorldInfo.AllControllers(class'Controller', C)
		{
			if ( UTPlayerController(C) != None )
			{
				if ( IsAWinner(PlayerController(C)) )
					UTPlayerController(C).ClientPlayAnnouncement(class'VictoryMessage', 0);
				else
					UTPlayerController(C).ClientPlayAnnouncement(class'VictoryMessage', 1);
			}
		}
	}
	else
		PlayRegularEndOfMatchMessage();
}

function PlayRegularEndOfMatchMessage()
{
	local controller C;

	foreach WorldInfo.AllControllers(class'Controller', C)
	{
		if ( UTPlayerController(C) != None && !C.PlayerReplicationInfo.bOnlySpectator )
		{
			if ( IsAWinner(PlayerController(C)) )
				UTPlayerController(C).ClientPlayAnnouncement(class'VictoryMessage', 2);
			else
				UTPlayerController(C).ClientPlayAnnouncement(class'VictoryMessage', 3);
		}
	}
}

function PlayStartupMessage()
{
	local Controller P;

    // keep message displayed for waiting players
    foreach WorldInfo.AllControllers(class'Controller', P)
        if ( UTPlayerController(P) != None )
            UTPlayerController(P).PlayStartUpMessage(StartupStage);
}

auto State PendingMatch
{
	function RestartPlayer( Controller aPlayer )
	{
		if ( CountDown <= 0 )
			Super.RestartPlayer(aPlayer);
	}

	/*FIXMESTEVE
    function bool AddBot(optional string botName)
    {
        if ( WorldInfo.NetMode == NM_Standalone )
            InitialBots++;
        if ( botName != "" )
			PreLoadNamedBot(botName);
		else
			PreLoadBot();
        return true;
    }
	*/
    function Timer()
    {
        local Controller P;
        local bool bReady;

        Global.Timer();

        // first check if there are enough net players, and enough time has elapsed to give people
        // a chance to join
        if ( NumPlayers == 0 )
			bWaitForNetPlayers = true;

        if ( bWaitForNetPlayers && (WorldInfo.NetMode != NM_Standalone) )
        {
             if ( NumPlayers >= MinNetPlayers )
                ElapsedTime++;
            else
                ElapsedTime = 0;
            if ( (NumPlayers == MaxPlayers) || (ElapsedTime > NetWait) )
            {
                bWaitForNetPlayers = false;
                CountDown = Default.CountDown;
            }
        }

        if ( (WorldInfo.NetMode != NM_Standalone) && (bWaitForNetPlayers || (bTournament && (NumPlayers < MaxPlayers))) )
        {
       		PlayStartupMessage();
            return;
		}

		// check if players are ready
        bReady = true;
        StartupStage = 1;
        if ( !bStartedCountDown && (bTournament || bPlayersMustBeReady || (WorldInfo.NetMode == NM_Standalone)) )
        {
            foreach WorldInfo.AllControllers(class'Controller', P)
                if ( P.IsA('PlayerController') && (P.PlayerReplicationInfo != None)
                    && P.bIsPlayer && P.PlayerReplicationInfo.bWaitingPlayer
                    && !P.PlayerReplicationInfo.bReadyToPlay )
                    bReady = false;
        }
        if ( bReady ) //FIXMESTEVE && !bReviewingJumpspots )
        {
			bStartedCountDown = true;
            CountDown--;
            if ( CountDown <= 0 )
                StartMatch();
            else
                StartupStage = 5 - CountDown;
        }
		PlayStartupMessage();
    }

    function BeginState(Name PreviousStateName)
    {
		bWaitingToStartMatch = true;
        StartupStage = 0;
        if ( IsA('xLastManStandingGame') )
			NetWait = Max(NetWait,10);
    }

Begin:
	if ( bQuickStart )
		StartMatch();
}

State MatchInProgress
{
    function Timer()
    {
        local Controller P;

        Global.Timer();
		if ( !bFinalStartup )
		{
			bFinalStartup = true;
			PlayStartupMessage();
		}
        if ( bForceRespawn )
            foreach WorldInfo.AllControllers(class'Controller', P)
            {
                if ( (P.Pawn == None) && P.IsA('PlayerController') && !P.PlayerReplicationInfo.bOnlySpectator )
                    PlayerController(P).ServerReStartPlayer();
            }
		/* FIXMESTEVE
        if ( NeedPlayers() && AddBot() && (RemainingBots > 0) )
			RemainingBots--;
		*/
        if ( bOverTime )
			EndGame(None,"TimeLimit");
        else if ( TimeLimit > 0 )
        {
            GameReplicationInfo.bStopCountDown = false;
            RemainingTime--;
            GameReplicationInfo.RemainingTime = RemainingTime;
            if ( RemainingTime % 60 == 0 )
                GameReplicationInfo.RemainingMinute = RemainingTime;
            if ( RemainingTime <= 0 )
                EndGame(None,"TimeLimit");
        }
        else if ( (MaxLives > 0) && (NumPlayers + NumBots != 1) )
			CheckMaxLives(none);

        ElapsedTime++;
        GameReplicationInfo.ElapsedTime = ElapsedTime;
    }

    function BeginState(Name PreviousStateName)
    {
		local PlayerReplicationInfo PRI;

		ForEach DynamicActors(class'PlayerReplicationInfo',PRI)
			PRI.StartTime = 0;
		ElapsedTime = 0;
		bWaitingToStartMatch = false;
        StartupStage = 5;
        PlayStartupMessage();
        StartupStage = 6;
    }
}

State MatchOver
{
	function RestartPlayer( Controller aPlayer ) {}
	function ScoreKill(Controller Killer, Controller Other) {}

	function ReduceDamage(out int Damage, Pawn Injured, Controller InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType, Actor DamageCauser)
	{
		Damage = 0;
		Momentum = vect(0,0,0);
	}

	function bool ChangeTeam(Controller Other, int num, bool bNewTeam)
	{
		return false;
	}

    function Timer()
    {
		local Controller C;

        Global.Timer();

        if ( !bGameRestarted && (WorldInfo.TimeSeconds > EndTime + RestartWait) )
            RestartGame();

		if ( EndGameFocus != None )
		{
			EndGameFocus.bAlwaysRelevant = true;
			foreach WorldInfo.AllControllers(class'Controller', C)
				if ( PlayerController(C) != None )
					PlayerController(C).ClientSetViewtarget(EndGameFocus);
		}

         // play end-of-match message for winner/losers (for single and muli-player)
        EndMessageCounter++;
        if ( EndMessageCounter == EndMessageWait )
	         PlayEndOfMatchMessage();
	}


    function bool NeedPlayers()
    {
        return false;
    }

    function BeginState(Name PreviousStateName)
    {
		GameReplicationInfo.bStopCountDown = true;
	}
}

/* Rate whether player should choose this NavigationPoint as its start
*/
function float RatePlayerStart(PlayerStart P, byte Team, Controller Player)
{
	local NavigationPoint N;
    local float Score, NextDist;
    local Controller OtherPlayer;

	N = P;

    if ( (P == None) || !P.bEnabled || P.PhysicsVolume.bWaterVolume )
        return -10000000;

    //assess candidate
    if ( P.bPrimaryStart )
		Score = 10000000;
	else
		Score = 5000000;
    if ( (N == LastStartSpot) || (N == LastPlayerStartSpot) )
        Score -= 10000.0;
    else
        Score += 3000 * FRand(); //randomize

    foreach WorldInfo.AllControllers(class'Controller', OtherPlayer)
        if ( OtherPlayer.bIsPlayer && (OtherPlayer.Pawn != None) )
        {
            if ( OtherPlayer.Pawn.PhysicsVolume == N.PhysicsVolume )
                Score -= 1500;
            NextDist = VSize(OtherPlayer.Pawn.Location - N.Location);
            if ( NextDist < 2*(OtherPlayer.Pawn.CylinderComponent.CollisionRadius + OtherPlayer.Pawn.CylinderComponent.CollisionHeight) )
                Score -= 1000000.0;
            else if ( (NextDist < 3000) && FastTrace(N.Location, OtherPlayer.Pawn.Location) )
                Score -= (10000.0 - NextDist);
            else if ( NumPlayers + NumBots == 2 )
            {
                Score += 2 * VSize(OtherPlayer.Pawn.Location - N.Location);
                if ( FastTrace(N.Location, OtherPlayer.Pawn.Location) )
                    Score -= 10000;
            }
        }
    return FMax(Score, 5);
}

// check if all other players are out
function bool CheckMaxLives(PlayerReplicationInfo Scorer)
{
    local Controller C;
    local PlayerReplicationInfo Living;
    local bool bNoneLeft;

    if ( MaxLives > 0 )
    {
		if ( (Scorer != None) && !Scorer.bOutOfLives )
			Living = Scorer;
        bNoneLeft = true;
        foreach WorldInfo.AllControllers(class'Controller', C)
            if ( (C.PlayerReplicationInfo != None) && C.bIsPlayer
                && !C.PlayerReplicationInfo.bOutOfLives
                && !C.PlayerReplicationInfo.bOnlySpectator )
            {
				if ( Living == None )
					Living = C.PlayerReplicationInfo;
				else if (C.PlayerReplicationInfo != Living)
			   	{
    	        	bNoneLeft = false;
	            	break;
				}
            }
        if ( bNoneLeft )
        {
			if ( Living != None )
				EndGame(Living,"LastMan");
			else
				EndGame(Scorer,"LastMan");
			return true;
		}
    }
    return false;
}

/* CheckScore()
see if this score means the game ends
*/
function bool CheckScore(PlayerReplicationInfo Scorer)
{
	local controller C;

	if ( CheckMaxLives(Scorer) )
		return false;

	/*FIXMESTEVE
    if ( (GameRulesModifiers != None) && GameRulesModifiers.CheckScore(Scorer) )
        return;
*/
	if ( Scorer != None )
	{
		if ( (GoalScore > 0) && (Scorer.Score >= GoalScore) )
			EndGame(Scorer,"fraglimit");
		else if ( bOverTime )
		{
			// end game only if scorer has highest score
			foreach WorldInfo.AllControllers(class'Controller', C)
				if ( (C.PlayerReplicationInfo != None)
					&& (C.PlayerReplicationInfo != Scorer)
					&& (C.PlayerReplicationInfo.Score >= Scorer.Score) )
					return false;
			EndGame(Scorer,"fraglimit");
		}
	}
	return true;
}

function RegisterVehicle(Vehicle V)
{
	// add to AI vehicle list
	if ( VehicleList.Find(V) == INDEX_NONE )
		VehicleList.AddItem(V);
}

static function int OrderToIndex(int Order)
{
	return Order;
}

defaultproperties
{
    HUDType=class'UTGame.UTHUD'
	DeathMessageClass=class'UTGame.UTDeathMessage'
	PlayerControllerClass=class'UTGame.UTPlayerController'
	DefaultPawnClass=class'UTGame.UTCharacter'
	PlayerReplicationInfoClass=Class'UTGame.UTPlayerReplicationInfo'
	GameReplicationInfoClass=class'UTGame.UTGameReplicationInfo'
	bRestartLevel=False
	bDelayedStart=True
	bTeamScoreRounds=false

    NumRounds=1
    CountDown=4
    bPauseable=False
    EndMessageWait=2
    DefaultMaxLives=0
    bModViewShake=true

	Callsigns[0]="ALPHA"
	Callsigns[1]="BRAVO"
	Callsigns[2]="CHARLIE"
	Callsigns[3]="DELTA"
	Callsigns[4]="ECHO"
	Callsigns[5]="FOXTROT"
	Callsigns[6]="GOLF"
	Callsigns[7]="HOTEL"
	Callsigns[8]="INDIA"
	Callsigns[9]="JULIET"
	Callsigns[10]="KILO"
	Callsigns[11]="LIMA"
	Callsigns[12]="MIKE"
	Callsigns[13]="NOVEMBER"
	Callsigns[14]="OSCAR"

	GravityModifier=+1.0
	JumpModifier=+1.0
    Acronym="???"
}
