/*
 * Created By:	Joe Wilcox
 * Copyright:	(c) 2004
 * Company:		Epic Games
*/

class UTAttachment_ShockRifle extends UTWeaponAttachment;


var float EffectTimer;
var color LineColor;
var vector Start,End;

simulated event ImpactEffects()
{
	local Emitter	EmitActor;
	local vector Dir;
	local PlayerController PC;

	super.ImpactEffects();

	if ( UTPawn(Owner) != none && UTPawn(Owner).FiringMode==0)
	{
		Start = Owner.Location;
		End   = UTPawn(Owner).FlashLocation;
		Dir = Normal(End - Start);
		EmitActor = Spawn( class'Emitter',,, End - 10*Dir, rotator(-Dir) );
		EmitActor.SetTemplate( ParticleSystem'WP_ShockRifle.Particles.P_WP_ShockRifle_Beam_Impact', true );

		foreach LocalPlayerControllers(class'PlayerController', PC)
		{
			if ( PC.MyHUD != None )
			{
				PC.MyHUD.Draw3DLine(Start, End, LineColor);
			}
		}
		EffectTimer=0.75;
		Enable('Tick');
	}

}

simulated function Tick(float DeltaTime)
{
	local PlayerController PC;

	if ( WorldInfo.NetMode == NM_DedicatedServer )
	{
		Disable('Tick');
		return;
	}

	ForEach LocalPlayerControllers(class'PlayerController', PC)
	{
		if ( PC.MyHUD != None )
		{
			LineColor.A = 255 * EffectTimer/0.75;
			PC.MyHUD.Draw3DLine(Start, End, LineColor);
		}
	}

	EffectTimer -= DeltaTime;

	if (EffectTimer <= 0.0)
		Disable('Tick');

}



defaultproperties
{
	// Weapon SkeletalMesh
	Begin Object Class=SkeletalMeshComponent Name=SkeletalMeshComponent0
		SkeletalMesh=SkeletalMesh'WP_ShockRifle.Mesh.SK_WP_ShockRifle_3P'
		bOwnerNoSee=true
		bOnlyOwnerSee=false
		CollideActors=false
		AlwaysLoadOnClient=true
		AlwaysLoadOnServer=true
	End Object
    Mesh=SkeletalMeshComponent0

	Begin Object class=PointLightComponent name=MuzzleFlashLightC
		Brightness=1.0
		LightColor=(R=255,G=80,B=200)
		Radius=255
		CastShadows=True
		bEnabled=false
		Translation=(X=-60,Z=5)
	End Object
	MuzzleFlashLight=MuzzleFlashLightC

	MuzzleFlashLightDuration=0.3
	MuzzleFlashLightBrightness=2.0
	LineColor=(R=255,G=255,B=0,A=255)

}
