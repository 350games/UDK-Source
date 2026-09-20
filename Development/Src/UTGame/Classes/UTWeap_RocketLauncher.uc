class UTWeap_RocketLauncher extends UTWeapon;

const MAXLOADCOUNT=3;
const SPREADDIST=1000;

var int LoadedShotCount;
var SoundCue WeaponLoadSnd;
var byte FlockIndex;

var name AltFireAnim[3];

/*********************************************************************************************
 * Hud/Crosshairs
 *********************************************************************************************/

/**
 * This function Displays the current Shot Count on the hud

simulated function ActiveRenderOverlays( HUD H )
{
	local string s;
	local float xl,yl;

	super.ActiveRenderOverlays(H);

	H.Canvas.DrawColor = H.WhiteColor;
    s = "Ammo:"@AmmoCount@LoadedShotCount;
	H.Canvas.Font = class'Engine'.Default.LargeFont;
	H.Canvas.Strlen(S, xl, yl);

    H.Canvas.SetPos(H.Canvas.ClipX - 5 - XL - 10, H.Canvas.ClipY-5-YL);
    H.Canvas.DrawText(s);

}

 */

/*********************************************************************************************
 * Temp Ammo Functions.  Remove when the ammo system is completed.
 *********************************************************************************************/

function ConsumeAmmo( byte FireModeNum ) {}

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

/*********************************************************************************************
 * Utility Functions.
 *********************************************************************************************/

/**
 * Fire off a load of rockets.
 *
 * Network: Server Only
 */

function FireLoad()
{
    local int i,j,k;
    local vector SpreadVector;
    local rotator Aim;
	local float theta;
	local vector FireLocation, RealStartLoc, StartTrace, AimDir, X, Y, Z;
	local ImpactInfo Impact;
	local Projectile	SpawnedProjectile;
	local UTProj_Rocket FiredRockets[4];
	local bool bCurl;

	local bool bFlocked;

	if ( UTPawn(Instigator) != None )
	{
		UTPawn(Instigator).IncrementFlashCount(self, 1);
	}

	bFlocked = PendingFire[0] > 0;
	bCurl = false;

	// Trace where crosshair is aiming at. Get hit info.
	StartTrace = Instigator.GetWeaponStartTraceLocation();
	AimDir = vector(GetAdjustedAim(StartTrace));
	Impact = CalcWeaponFire(StartTrace, StartTrace + AimDir * GetTraceRange());

	// this is the location where the projectile is spawned
	RealStartLoc = GetPhysicalFireStartLoc(AimDir);

	Aim = rotator(Impact.HitLocation - RealStartLoc);

	GetViewAxes(X,Y,Z);

    for (i = 0; i < LoadedShotCount; i++)
    {

    	if (!bFlocked)
    	{
   	    	// Give them some gradual spread.

	        theta = SPREADDIST*PI/32768*(i - float(LoadedShotCount-1)/2.0);
	        SpreadVector.X = Cos(theta);
	        SpreadVector.Y = Sin(theta);
	        SpreadVector.Z = 0.0;
			SpawnedProjectile = Spawn(GetProjectileClass(),,, RealStartLoc, Rotator(SpreadVector >> Aim));
			if ( SpawnedProjectile != None )
			{
				SpawnedProjectile.Init(SpreadVector >> Aim);
			}

		}
		else
		{
			Firelocation = RealStartLoc - 2* ( (Sin(i*2*PI/MAXLOADCOUNT)*8 - 7)*Y - (Cos(i*2*PI/MAXLOADCOUNT)*8 - 7)*Z) - X * 8 * FRand();
			SpawnedProjectile = Spawn(GetProjectileClass(),,, FireLocation, Aim);
			if ( SpawnedProjectile != None )
			{
				SpawnedProjectile.Init( Vector(Aim) );
			}

	        FiredRockets[i] = UTProj_Rocket(SpawnedProjectile);
		}
    }

	// Initialize the rockets so they flock towards each other

    if (bFlocked)
    {
		FlockIndex++;
		if ( FlockIndex == 0 )
		{
			FlockIndex = 1;
		}

	    // To get crazy flying, we tell each projectile in the flock about the others.
	    for ( i = 0; i < LoadedShotCount; i++ )
	    {
			if ( FiredRockets[i] != None )
			{
				FiredRockets[i].bCurl = bCurl;
				FiredRockets[i].FlockIndex = FlockIndex;
				j=0;
				for ( k=0; k<LoadedShotCount; k++ )
				{
					if ( (i != k) && (FiredRockets[k] != None) )
					{
						FiredRockets[i].Flock[j] = FiredRockets[k];
						j++;
					}
				}
				bCurl = !bCurl;
				if ( WorldInfo.NetMode != NM_DedicatedServer )
				{
					FiredRockets[i].SetTimer(0.1, true, 'FlockTimer');
				}
			}
		}

    }

}

/*********************************************************************************************
 * State WeaponLoadAmmo
 * In this state, ammo will continue to load up until MAXLOADCOUNT has been reached.  It's
 * similar to the firing state
 *********************************************************************************************/

simulated state WeaponLoadAmmo
{
	/**
	 * Adds a rocket to the count and uses up some ammo.  In Addition, it plays
	 * a sound so that other pawns in the world can here it.
	 */

	simulated function AddRocket()
	{
    	if ( LoadedShotCount < MAXLOADCOUNT && CheckAmmo(CurrentFireMode,1) )
    	{
			// Add the Rocket

			LoadedShotCount++;
			UseAmmo(CurrentFireMode,1);

			// Play a sound
			// FIXME: Wrap this once we have the ability to play on the client and everyone but the client,
			// but for now, just play on the server

			if (Role==ROLE_Authority)
			{
				PlaySound(WeaponLoadSnd);
			}

			// Play the que animation

			if ( Instigator.IsLocallyControlled() )
				PlayWeaponAnimation(AltFireAnim[ LoadedShotCount-1], FireInterval[1]);

			TimeWeaponFiring(CurrentFireMode);
		}
		else
		{
			WeaponFireLoad();
		}

	}

	simulated function WeaponFireLoad()
	{
	    Instigator.MakeNoise(1.0);

	    if (Role==Role_Authority)
	    {
			FireLoad();
		}

		if ( Instigator.IsLocallyControlled() )
		{
			PlayFireEffects( CurrentFireMode );
		}

		LoadedShotCount = 0;
		TimeWeaponFiring(CurrentFireMode);

		//FIXME: Add support for changing weapons when out of ammo
	}

	simulated event ShotFired()
	{
		if ( PendingFire[1]==0 )	// We are still firing
		{
			GotoState('Active');
		}
		else
		{
			AddRocket();
		}
	}

	/**
	 * We need to override WeaponEndFire so that we can correctly fire off the
	 * current load if we have any.
	 */

	simulated function WeaponEndFire(byte FireModeNum)
	{

		// Pass along to the global to handle everything

		Global.WeaponEndFire(FireModeNum);


		if ( FireModeNum == 1 )
		{
			if (LoadedShotCount>0)
			{
				WeaponFireLoad();
			}
		}
	}

	/**
	 * Insure that the LoadedShotCount is 0 when we leave this state
	 */

	simulated function EndState(Name NextStateName)
	{
		LoadedShotCount=0;
		Super.EndState(NextStateName);
	}

begin:
	AddRocket();
}

defaultproperties
{
	WeaponColor=(R=255,G=0,B=0,A=255)
	FireInterval(0)=+0.9
	FireInterval(1)=+0.95
	PlayerViewOffset=(X=0.0,Y=7.0,Z=-9.0)

	FiringStatesArray(1)=WeaponLoadAmmo

	Begin Object class=AnimNodeSequence Name=MeshSequenceA
	End Object

	Begin Object Class=SkeletalMeshComponent Name=MeshComponentA
		SkeletalMesh=SkeletalMesh'WP_RocketLauncher.Mesh.SK_WP_RocketLauncher_1P'
		PhysicsAsset=none
		AnimSets(0)=AnimSet'WP_RocketLauncher.Anims.K_WP_RocketLauncher_1P_Base'
		Animations=MeshSequenceA
		AlwaysLoadOnClient=true
		AlwaysLoadOnServer=true
		CastShadow=false
		Translation=(X=-5,Y=-10,Z=-5)
		Rotation=(Yaw=-16384)
		Scale3D=(X=1.0,Y=1.0,Z=1.0)
		Scale=0.70
	End Object
	Mesh=MeshComponentA

	AttachmentClass=class'UTGame.UTAttachment_RocketLauncher'
	Components.Add(MeshComponentA)


	// Pickup staticmesh

	Begin Object Class=SkeletalMeshComponent Name=SkeletalMeshComponent1
		SkeletalMesh=SkeletalMesh'WP_RocketLauncher.Mesh.SK_WP_RocketLauncher_3P'
		AnimSets(0)=AnimSet'WP_RocketLauncher.Anims.K_WP_RocketLauncher_3P'
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
	WeaponLoadSnd=SoundCue'A_Weapon_RocketLauncher.Cue.A_Weapon_RL_Load_Cue'

 	WeaponFireTypes(0)=EWFT_Projectile
	WeaponFireTypes(1)=EWFT_Projectile

	WeaponProjectiles(0)=class'UTProj_Rocket'
	WeaponProjectiles(1)=class'UTProj_Rocket'

	WeaponFireAnim=WeaponFire
	WeaponPutDownAnim=WeaponPutDown
	WeaponEquipAnim=WeaponEquip

 	FireOffset=(X=70)

 	AltFireAnim(0)=AltFireQueue1
 	AltFireAnim(1)=AltFireQueue2
 	AltFireAnim(2)=AltFireQueue3
}
