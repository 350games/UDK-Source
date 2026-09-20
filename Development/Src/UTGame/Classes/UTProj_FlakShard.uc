/**
 * Created By:	Joe Wilcox
 * Copyright:	(c) 2004
 * Company:		Epic Games
*/

class UTProj_FlakShard extends UTProjectile;

/** # of times they can bounce */

var int Bounces;

function Init(vector Direction)
{
	local float r;

	super.Init(Direction);
	if (PhysicsVolume.bWaterVolume)
		Velocity *= 0.65;

    r = FRand();
    if (r > 0.75)
        Bounces = 2;
    else if (r > 0.25)
        Bounces = 1;
    else
        Bounces = 0;

    SetRotation(RotRand());

}

simulated function Landed(vector HitNormal, Actor FloorActor)
{
    SetPhysics(PHYS_None);
    LifeSpan = 1.0;
}


simulated function HitWall(vector HitNormal, Actor Wall, PrimitiveComponent WallComp)
{
    if ( !Wall.bStatic && !Wall.bWorldGeometry  )
    {
	    	`log("# BLAH");
        if ( WorldInfo.NetMode != NM_Client )
		{
	            Wall.TakeDamage(Damage, InstigatorController, Location, MomentumTransfer * Normal(Velocity), MyDamageType,, self);
		}
        Destroy();
        return;
    }

    SetPhysics(PHYS_Falling);
	if (Bounces > 0)
    {

    //FIXME: Add Impact Sounds

//		if ( !WorldInfo.bDropDetail && (FRand() < 0.4) )
//			Playsound(ImpactSounds[Rand(6)]);

        Velocity = 0.65 * (Velocity - 2.0*HitNormal*(Velocity dot HitNormal));
        Bounces = Bounces - 1;
        return;
    }
    Super.HitWall(HitNormal, Wall, WallComp);
	bBounce = false;

}

defaultproperties
{

    speed=2500.000000
    MaxSpeed=2700.000000
    Damage=13
	DamageRadius=+220.0

    MomentumTransfer=10000
    MyDamageType=class'UTDmgType_FlakShard'
    LifeSpan=2.7
    RotationRate=(Roll=50000)
    bCollideWorld=true

	// Add the Mesh
	Begin Object class=StaticMeshComponent name=FlakShardMesh
		StaticMesh=StaticMesh'WP_ShockRifle.Mesh.S_Instagib_DebrisChunk01'
		bOwnerNoSee=true
		AlwaysLoadOnClient=true
		AlwaysLoadOnServer=true
		CastShadow=false
	End Object

	Components.Add(FlakShardMesh)

    DrawScale=0.5
	bBounce=true
	Bounces=1


}
