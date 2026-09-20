/**
 * Formats localized UT kill and suicide messages for the HUD and console.
 *
 * Switch 0: RelatedPRI_1 killed RelatedPRI_2.
 * Switch 1: RelatedPRI_2 committed suicide.
 * OptionalObject is the damage type class.
 */
class UTDeathMessage extends UTLocalMessage;

var(Message) localized string KilledString;
var(Message) localized string SomeoneString;

static function color GetConsoleColor(PlayerReplicationInfo RelatedPRI_1)
{
	return class'HUD'.Default.GreenColor;
}

static function string GetString(
	optional int Switch,
	optional bool bPRI1HUD,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
	)
{
	local string KillerName, VictimName;
	local class<UTDamageType> KillDamageType;

	KillDamageType = class<UTDamageType>(OptionalObject);
	if (KillDamageType == None)
	{
		KillDamageType = class'UTDamageType';
	}

	KillerName = (RelatedPRI_1 != None) ? RelatedPRI_1.PlayerName : Default.SomeoneString;
	VictimName = (RelatedPRI_2 != None) ? RelatedPRI_2.PlayerName : Default.SomeoneString;

	if (Switch == 1)
	{
		return class'UTGame'.static.ParseKillMessage(
			KillerName,
			VictimName,
			KillDamageType.static.SuicideMessage(RelatedPRI_2));
	}

	return class'UTGame'.static.ParseKillMessage(
		KillerName,
		VictimName,
		KillDamageType.static.DeathMessage(RelatedPRI_1, RelatedPRI_2));
}

defaultproperties
{
	DrawColor=(R=255,G=0,B=0,A=255)
	bIsSpecial=false
}
