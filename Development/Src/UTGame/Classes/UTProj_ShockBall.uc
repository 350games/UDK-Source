/**
 * Created By:	Joe Wilcox
 * Copyright:	(c) 2004
 * Company:		Epic Games
*/

class UTProj_ShockBall extends UTProjectile;

var class<UTDamageType>	ComboDamageType;

event TakeDamage(int DamageAmount, Controller EventInstigator, vector HitLocation, vector Momentum, class<DamageType> DamageType, optional TraceHitInfo HitInfo, optional Actor DamageCauser)
{
	if ( DamageType==ComboDamageType )
	{
		// COMBO

	}

	Super.TakeDamage(DamageAmount, EventInstigator, HitLocation, Momentum, DamageType, HitInfo, DamageCauser);
}


defaultproperties
{

	ProjFlightTemplate=ParticleSystem'WP_ShockRifle.Particles.P_WP_ShockRifle_Ball'

	Begin Object class=PointLightComponent name=ShockLight
		Brightness=2.0
		LightColor=(R=255,G=128,B=200)
		Radius=180
		CastShadows=True
		bEnabled=true
		Translation=(X=-200,Z=5)
	End Object

	Components.Add(ShockLight)

	Begin Object Name=CollisionCylinder
		CollisionRadius=10
		CollisionHeight=10
		AlwaysLoadOnClient=True
		AlwaysLoadOnServer=True
		BlockNonZeroExtent=true
		BlockZeroExtent=true
		BlockActors=true
		CollideActors=true
	End Object


    Speed=1150
    MaxSpeed=1150

    Damage=45
    DamageRadius=150
    MomentumTransfer=70000

    MyDamageType=class'UTDmgType_ShockBall'
    LifeSpan=8.0

    bCollideWorld=true
    DrawScale=0.7
    bProjTarget=True

	ComboDamageType=class'UTDmgType_ShockPrimary'

}
