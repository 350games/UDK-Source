/**
 * UTDamageType
 *
 *
 * Created By:	Joe Wilcox
 * Copyright:	(c) 2004
 * Company:		Epic Games
*/

class UTDamageType extends DamageType;

/** Localized kill-feed text supplied by each concrete UT damage type. */
var() localized string DeathString;
var() localized string FemaleSuicide;
var() localized string MaleSuicide;

/** Weapon responsible for this damage, when the recovered game has an exact class. */
var class<UTWeapon> DamageWeaponClass;

static function string DeathMessage(PlayerReplicationInfo Killer, PlayerReplicationInfo Victim)
{
	return Default.DeathString;
}

static function string SuicideMessage(PlayerReplicationInfo Victim)
{
	if (UTPlayerReplicationInfo(Victim) != None && UTPlayerReplicationInfo(Victim).bIsFemale)
	{
		return Default.FemaleSuicide;
	}

	return Default.MaleSuicide;
}


/**
 * Returns a list of effects to spawn when this damage is applied
 *
 */

static function GetHitEffects(out array<Emitter> HitEffects, int VictimHealth );
