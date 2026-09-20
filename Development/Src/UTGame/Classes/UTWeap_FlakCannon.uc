/**
 * Created By:	Joe Wilcox
 * Copyright:	(c) 2004
 * Company:		Epic Games
*/

class UTWeap_FlakCannon extends UTWeapon;

const SPREADDIST=1400;


/** Contains the # of flak shards to fire each time */

var int NoShardsPerFire;

simulated function CustomFire()
{
	local int i;
    local rotator Adjustment;
	local vector RealStartLoc, StartTrace, AimDir;
	local ImpactInfo Impact;
	local Projectile Proj;

	IncrementFlashCount();

	// Trace where crosshair is aiming at. Get hit info.
	StartTrace = Instigator.GetWeaponStartTraceLocation();
	AimDir = vector(GetAdjustedAim(StartTrace));
	Impact = CalcWeaponFire(StartTrace, StartTrace + AimDir * GetTraceRange());

	// this is the location where the projectile is spawned
	RealStartLoc = GetPhysicalFireStartLoc(AimDir);

	AimDir = Normal(Impact.HitLocation - RealStartLoc);

	for (i=0;i<NoShardsPerFire;i++)
	{
        Adjustment.Yaw   = SPREADDIST * (FRand()-0.5);
        Adjustment.Pitch = SPREADDIST * (FRand()-0.5);
        Adjustment.Roll  = SPREADDIST * (FRand()-0.5);

		Proj = Spawn( GetProjectileClass(),,, RealStartLoc );
		if (Proj!=None)
			Proj.Init( AimDir >> Adjustment );
    }
}


defaultproperties
{

	WeaponColor=(R=255,G=255,B=128,A=255)
	FireInterval(0)=+0.8947
	FireInterval(1)=+0.9
	PlayerViewOffset=(X=0.0,Y=7.0,Z=-9.0)

	Begin Object class=AnimNodeSequence Name=MeshSequenceA
	End Object

	Begin Object Class=SkeletalMeshComponent Name=MeshComponentA
		SkeletalMesh=SkeletalMesh'WP_SteamLauncher.Mesh.Weap_SteamLauncher_Mesh'
		PhysicsAsset=none
		AnimSets(0)=AnimSet'WP_SteamLauncher.Anim.K_WP_SteamLauncher'
		Animations=MeshSequenceA
		AlwaysLoadOnClient=true
		AlwaysLoadOnServer=true
		CastShadow=false
		Translation=(X=-5,Y=-10,Z=-25)
		Rotation=(Yaw=-16384)
		Scale3D=(X=1.0,Y=1.0,Z=1.0)
		Scale=0.70
	End Object
	Mesh=MeshComponentA

	AttachmentClass=class'UTGame.UTAttachment_FlakCannon'
	Components.Add(MeshComponentA)


	Begin Object Class=SkeletalMeshComponent Name=SkeletalMeshComponent1
		SkeletalMesh=SkeletalMesh'WP_SteamLauncher.Mesh.Weap_SteamLauncher_Mesh'
		AnimSets(0)=AnimSet'WP_SteamLauncher.Anim.K_WP_SteamLauncher'
		bOnlyOwnerSee=false
	    CastShadow=false
		CollideActors=false
		Translation=(X=0.0,Y=0.0,Z=-10.0)
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

	WeaponFireSnd(0)=SoundCue'A_Weapon_RocketLauncher.Cue.A_Weapon_RL_Fire_Cue'
	WeaponFireSnd(1)=SoundCue'A_Weapon_RocketLauncher.Cue.A_Weapon_RL_Fire_Cue'

 	WeaponFireTypes(0)=EWFT_Custom
	WeaponFireTypes(1)=EWFT_Projectile
	WeaponProjectiles(0)=class'UTProj_FlakShard'
	WeaponProjectiles(1)=class'UTProj_FlakShell'

	WeaponFireAnim=WeaponFire
	WeaponPutDownAnim=WeaponPutDown
	WeaponEquipAnim=WeaponEquip

	FireOffset=(X=25)
	NoShardsPerFire=9
}
