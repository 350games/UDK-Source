class UTPlayerReplicationInfo extends PlayerReplicationInfo;

var bool bAdrenalineEnabled; 
var byte Adrenaline;	
var byte AdrenalineMax; 

var UTLinkedReplicationInfo CustomReplicationInfo;	// for use by mod authors

//FIXMESTEVE var class<VoicePack>	VoiceType;
var string				VoiceTypeName;
var repnotify string	CharacterName;

/** True when this player is using a female character/voice profile. */
var bool bIsFemale;

replication
{
	if ( Role==ROLE_Authority )
		CustomReplicationInfo, CharacterName, bIsFemale;
	if ( bNetOwner && (Role==ROLE_Authority) )
		Adrenaline;
}

simulated event ReplicatedEvent(name VarName)
{
	if ( VarName == 'CharacterName' )
	{
		UpdateCharacter();
	}
	else
	{
		Super.ReplicatedEvent(VarName);
	}
}

function UpdateCharacter();

function AwardAdrenaline(float amount)
{
	if ( bAdrenalineEnabled )
	{
		//FIXMESTEVE if ( (Adrenaline < AdrenalineMax) && (Adrenaline+amount >= AdrenalineMax) && ((Pawn == None) || !Pawn.InCurrentCombo()) )
		//	ClientDelayedAnnouncementNamed('Adrenalin',15);
		Adrenaline += Amount;
		Adrenaline = Clamp( Adrenaline, 0, AdrenalineMax );
	}
}

function bool NeedsAdrenaline()
{
	return false;
	//FIXMESTEVE return ( (Pawn != None) && !Pawn.InCurrentCombo() && (Adrenaline < AdrenalineMax) );
}

function Reset()
{
	Super.Reset();
	
	Adrenaline = 0;
}


simulated function string GetCallSign()
{
	if ( Team == None || Team.TeamIndex > 14 )
		return "";
	return class'UTGame'.default.CallSigns[Team.TeamIndex];
}

simulated event string GetNameCallSign()
{
	if ( Team == None || Team.TeamIndex > 14 )
		return PlayerName;
	return PlayerName$" ["$class'UTGame'.default.CallSigns[Team.TeamIndex]$"]";
}

/* FIXMESTEVE

function SetCharacterVoice(string S)
{
	local class<VoicePack> NewVoiceType;

	if ( (WorldInfo.NetMode == NM_DedicatedServer) && (VoiceType != None) )
	{
		VoiceTypeName = S;
		return;
	}
	if ( S == "" )
	{
		VoiceTypeName = "";
		return;
	}

	NewVoiceType = class<VoicePack>(DynamicLoadObject(S,class'Class'));
	if ( NewVoiceType != None )
	{
		VoiceType = NewVoiceType;
		VoiceTypeName = S;
	}
}
*/
defaultproperties
{
    Adrenaline=0
    AdrenalineMax=100
    bAdrenalineEnabled=false
}
