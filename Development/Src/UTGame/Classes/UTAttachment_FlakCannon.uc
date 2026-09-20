/**
 * Created By:	Joe Wilcox
 * Copyright:	(c) 2004
 * Company:		Epic Games
*/

class UTAttachment_FlakCannon extends UTWeaponAttachment;

defaultproperties
{

	Begin Object Class=SkeletalMeshComponent Name=SkeletalMeshComponent0
		SkeletalMesh=SkeletalMesh'WP_SteamLauncher.Mesh.Weap_SteamLauncher_Mesh'
		AnimSets(0)=AnimSet'WP_SteamLauncher.Anim.K_WP_SteamLauncher'
		bOwnerNoSee=true
		CollideActors=false
		Translation=(X=-3.0,Y=-15.0,Z=11.0)
		Rotation=(Yaw=90)
		Scale=2.0
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
