/**
 * UTProjectile
 *
 * This is our base projectile class.
 *
 * Created By:	Joe Wilcox
 * Copyright:	(c) 2004
 * Company:		Epic Games
*/

class UTProjectile extends Projectile
	abstract;

/** Additional Sounds */

var SoundCue	AmbientSound;	// The sound that is played looped.

/** Effects */

var Emitter ProjEffects;	// Effects to display

/** Effects Template */

var ParticleSystem ProjFlightTemplate;
var ParticleSystem ProjExplosionTemplate;

/** Additional upward velocity applied when Init() launches the projectile. */
var float TossZ;

/**
 * Explode when landing
 */

event Landed(vector HitNormal, Actor FloorActor)
{
	Super.Landed(HitNormal, FloorActor);
	Explode(Location,HitNormal);
}

/**
 * When this actor begins its life, play any ambient sounds attached to it
 */

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();

	if (AmbientSound != None && WorldInfo.NetMode != NM_DedicatedServer)
		PlaySound(AmbientSound);

	SpawnFlightEffects();
}

/**
 * Initalize the Projectile
 */

function Init(vector Direction)
{
	SetRotation(Rotator(Direction));
	Velocity = Speed * Direction;
	Velocity.Z += TossZ;
}

/**
 * We touched someone
 */

simulated function ProcessTouch(Actor Other, Vector HitLocation, Vector HitNormal)
{
	if ( Other != Instigator )
	{
		if (DamageRadius > 0.0)
			Explode( HitLocation, HitNormal );
		else
			Other.TakeDamage(Damage, InstigatorController, HitLocation, MomentumTransfer * Normal(Velocity), MyDamageType,, self);
	}
}


/**
 * Explode this Projectile
 */

simulated function Explode(vector HitLocation, vector HitNormal)
{
	HurtRadius(Damage,DamageRadius, MyDamageType, MomentumTransfer, HitLocation );
	SpawnExplosionEffects();

	if ( Role == ROLE_Authority )
		MakeNoise(1.0);

	Destroy();
}



/**
 * Spawns any effects needed for the flight of this projectile
 */

simulated function SpawnFlightEffects()
{
	if ( WorldInfo.NetMode != NM_DedicatedServer )
		ProjEffects = Spawn(class'emitter',self);

	if (ProjEffects!=None && ProjFlightTemplate != none)
	{
		ProjEffects.SetTemplate(ProjFlightTemplate,true);
		ProjEffects.SetBase(self);
	}
}


/**
 * SPawn Explosion Effects
 */

simulated function SpawnExplosionEffects()
{
	local Emitter SFX;
	if ( WorldInfo.NetMode != NM_DedicatedServer )
		SFX = Spawn(class'emitter',self);

	if (SFX!=None && ProjExplosionTemplate != none)
		SFX.SetTemplate(ProjExplosionTemplate,true);
}

/**
 * Clean up
 */

simulated function Destroyed()
{
	if (ProjEffects!=None)
	{
		ProjEffects.bDestroyOnSystemFinish=true;
		ProjEffects.ParticleSystemComponent.DeactivateSystem();
		ProjEffects.SetBase(none);
//		ProjEffects.Destroy();
	}

	super.Destroyed();
}


defaultproperties
{
	TossZ=0.0
}
