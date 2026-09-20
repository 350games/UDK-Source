class UTAttachment_RocketLauncher extends UTWeaponAttachment;

defaultproperties
{
	Begin Object Class=SkeletalMeshComponent Name=SkeletalMeshComponent0
		SkeletalMesh=SkeletalMesh'WP_RocketLauncher.Mesh.SK_WP_RocketLauncher_3P'
		AnimSets(0)=AnimSet'WP_RocketLauncher.Anims.K_WP_RocketLauncher_3P'
		bOwnerNoSee=true
		CollideActors=false
		Translation=(X=1.0,Y=-1.0,Z=0.0)
		Rotation=(Roll=1000)
		Scale=1.1
	End Object
    Mesh=SkeletalMeshComponent0

	Begin Object class=PointLightComponent name=MuzzleFlashLightC
		Brightness=1.0
		LightColor=(R=255,G=128,B=128)
		Radius=255
		CastShadows=True
		bEnabled=false
		Translation=(X=-60,Z=5)
	End Object
	MuzzleFlashLight=MuzzleFlashLightC

	MuzzleFlashLightDuration=0.3
	MuzzleFlashLightBrightness=2.0


}
