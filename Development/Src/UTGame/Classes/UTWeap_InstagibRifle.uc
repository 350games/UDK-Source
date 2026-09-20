class UTWeap_InstagibRifle extends UTWeapon;

/* No ammo use for instagib rifle */

simulated function float GetAmmoLeftPercent( byte FireModeNum )
{
	return 1;
}

simulated function bool CheckAmmo( byte FireModeNum, optional int Amount )
{
	return true;
}

simulated function bool HasAnyAmmo()
{
	return true;
}

defaultproperties
{
	WeaponColor=(R=255,G=0,B=64,A=255)
	FireInterval(0)=+1.1
	FireInterval(1)=+1.1
	//FireSound=
	PlayerViewOffset=(X=0.0,Y=7.0,Z=-9.0)

	// Weapon SkeletalMesh
	Begin Object Class=SkeletalMeshComponent Name=MeshComponent0
		SkeletalMesh=SkeletalMesh'WP_ShockRifle.Mesh.SK_WP_ShockRifle_3P'
		bOnlyOwnerSee=true
        CastShadow=false
		CollideActors=false
		Translation=(X=0.0,Y=0.0,Z=0)
		Scale3D=(X=0.2,Y=0.2,Z=0.2)
		Rotation=(Yaw=32768,Roll=-16384)
	End Object
    Mesh=MeshComponent0

	AttachmentClass=class'UTGame.UTAttachment_InstagibRifle'
	Components.Add(MeshComponent0)

	// Pickup staticmesh

	Begin Object Class=SkeletalMeshComponent Name=SkeletalMeshComponent1
		SkeletalMesh=SkeletalMesh'WP_ShockRifle.Mesh.SK_WP_ShockRifle_3P'
		bOnlyOwnerSee=false
	    CastShadow=false
		CollideActors=false
		Translation=(X=0.0,Y=0.0,Z=-20.0)
		Rotation=(Yaw=32768)
		Scale3D=(X=0.3,Y=0.3,Z=0.3)
    End Object
	DroppedPickupMesh=SkeletalMeshComponent1
	PickupFactoryMesh=SkeletalMeshComponent1

	// Lighting

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

	InstantHitDamage(0)=1000
	InstantHitDamage(1)=1000

	InstantHitDamageTypes(0)=class'UTDmgType_Instagib'
	InstantHitDamageTypes(1)=class'UTDmgType_Instagib'

	WeaponEquipSnd=SoundCue'A_Weapon_ShockRifle.Cue.A_Weapon_SR_RaiseCue'
	WeaponPutDownSnd=SoundCue'A_Weapon_ShockRifle.Cue.A_Weapon_SR_LowerCue'

	WeaponFireSnd(0)=SoundCue'A_Weapon_ShockRifle.Cue.A_Weapon_SR_FireCue'
	WeaponFireSnd(1)=SoundCue'A_Weapon_ShockRifle.Cue.A_Weapon_SR_FireCue'


}
