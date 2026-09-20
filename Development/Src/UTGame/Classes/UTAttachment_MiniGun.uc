
class UTAttachment_MiniGun extends UTWeaponAttachment;

simulated event ImpactEffects()
{
	local Emitter E;
	local vector HitLocation,HitNormal;

	super.ImpactEffects();

	if ( UTPawn(Owner) != none )
	{
		HitLocation = UTPawn(Owner).FlashLocation;
		HitNormal = normal(Owner.Location-HitLocation);

		E = Spawn( class'Emitter',,, HitLocation, rotator(HitNormal) );
		E.SetTemplate( ParticleSystem'WP_ShockRifle.Particles.P_WP_ShockRifle_Beam_Impact', true );
	}

}

defaultproperties
{

	// Weapon SkeletalMesh
	Begin Object Class=SkeletalMeshComponent Name=SkeletalMeshComponent0
		SkeletalMesh=SkeletalMesh'WP_Stinger.Mesh.SK_WP_Stinger_3P_Mid'
		AnimSets(0)=AnimSet'WP_Stinger.Anims.K_WP_Stinger_3P_Base'
		bOwnerNoSee=true
		bOnlyOwnerSee=false
		CollideActors=false
		AlwaysLoadOnClient=true
		AlwaysLoadOnServer=true
	End Object
    Mesh=SkeletalMeshComponent0

	Begin Object class=PointLightComponent name=MuzzleFlashLightC
		Brightness=1.0
		LightColor=(R=255,G=255,B=128)
		Radius=255
		CastShadows=True
		bEnabled=false
		Translation=(X=-60,Z=5)
	End Object
	MuzzleFlashLight=MuzzleFlashLightC


	MuzzleFlashLightDuration=0.3
	MuzzleFlashLightBrightness=2.0


}
