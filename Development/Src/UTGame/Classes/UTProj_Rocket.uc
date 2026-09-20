class UTProj_Rocket extends UTProjectile;

/** Used for the curling rocket effect */

var byte FlockIndex;
var UTProj_Rocket Flock[2];

var() float	FlockRadius;
var() float	FlockStiffness;
var() float FlockMaxForce;
var() float	FlockCurlForce;
var bool bCurl;
var vector Dir;

var PointLightComponent RocketGlow;

replication
{
	    if ( bNetInitial && (Role == ROLE_Authority) )
        FlockIndex, bCurl;
}

function Init(vector Direction)
{
	super.Init(Direction);
	Dir = Direction;
}


simulated function Destroyed()
{
	ClearTimer('FlockTimer');
	super.Destroyed();
}

simulated function PostBeginPlay()
{
	local UTProj_Rocket R;
	local int i;

	Super.PostBeginPlay();

	if ( FlockIndex != 0 )
	{
	    SetTimer(0.1, true, 'FlockTimer');

	    // look for other rockets
	    if ( Flock[1] == None )
	    {

			ForEach DynamicActors(class'UTProj_Rocket',R)
				if ( R.FlockIndex == FlockIndex )
				{
					Flock[i] = R;
					if ( R.Flock[0] == None )
						R.Flock[0] = self;
					else if ( R.Flock[0] != self )
						R.Flock[1] = self;
					i++;
					if ( i == 2 )
						break;
				}
		}
	}
}

simulated function FlockTimer()
{
    local vector ForceDir, CurlDir;
    local float ForceMag;
    local int i;

	Velocity =  Default.Speed * Normal(Dir * 0.5 * Default.Speed + Velocity);

	// Work out force between flock to add madness
	for(i=0; i<2; i++)
	{
		if(Flock[i] == None)
			continue;

		// Attract if distance between rockets is over 2*FlockRadius, repulse if below.
		ForceDir = Flock[i].Location - Location;
		ForceMag = FlockStiffness * ( (2 * FlockRadius) - VSize(ForceDir) );
		Acceleration = Normal(ForceDir) * Min(ForceMag, FlockMaxForce);

		// Vector 'curl'
		CurlDir = Flock[i].Velocity Cross ForceDir;
		if ( bCurl == Flock[i].bCurl )
			Acceleration += Normal(CurlDir) * FlockCurlForce;
		else
			Acceleration -= Normal(CurlDir) * FlockCurlForce;
	}
}


defaultproperties
{

	ProjFlightTemplate=ParticleSystem'WP_RocketLauncher.Effects.P_WP_RocketLauncher_RocketTrail'
    ProjExplosionTemplate=ParticleSystem'WP_RocketLauncher.Effects.P_WP_RocketLauncher_RocketExplosion'
	speed=1350.0
    MaxSpeed=1350.0
    Damage=90.0
    DamageRadius=220.0
    MomentumTransfer=50000
    MyDamageType=class'UTDmgType_Rocket'
    LifeSpan=8.0
    AmbientSound=SoundCue'A_Weapon_RocketLauncher.Cue.A_Weapon_RL_Travel_Cue'
    RotationRate=(Roll=50000)
    bCollideWorld=true

	// Add the Mesh

	Begin Object Class=StaticMeshComponent Name=WRocketMesh
		StaticMesh=StaticMesh'WP_RocketLauncher.Mesh.S_WP_Rocketlauncher_Rocket_old_lit'
	End Object

	Begin Object class=PointLightComponent name=RocketLight
		Brightness=2.0
		LightColor=(R=255,G=150,B=40)
		Radius=180
		CastShadows=True
		bEnabled=true
		Translation=(X=-200,Z=5)
	End Object

	Components.Add(WRocketMesh)
	Components.Add(RocketLight)

	// Flocking

    FlockRadius=12
    FlockStiffness=-40
    FlockMaxForce=600
    FlockCurlForce=450

    DrawScale=0.25


}
