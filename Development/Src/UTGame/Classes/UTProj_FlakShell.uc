/**
 * Created By:	Joe Wilcox
 * Copyright:	(c) 2004
 * Company:		Epic Games
*/

class UTProj_FlakShell extends UTProjectile;

defaultproperties
{

    speed=1200.000000
    Damage=90.000000
    MomentumTransfer=75000
    MyDamageType=class'UTDmgType_FlakShell'
    LifeSpan=8.0
    RotationRate=(Pitch=50000)
    bCollideWorld=true
	TossZ=+225.0

	ProjFlightTemplate=ParticleSystem'WP_RocketLauncher.Effects.P_WP_RocketLauncher_RocketTrail'
    ProjExplosionTemplate=ParticleSystem'WP_RocketLauncher.Effects.P_WP_RocketLauncher_RocketExplosion'

	Physics=PHYS_Falling

	Begin Object class=PointLightComponent name=FlakLight
		Brightness=2.0
		LightColor=(R=255,G=150,B=40)
		Radius=180
		CastShadows=True
		bEnabled=true
		Translation=(X=-200,Z=5)
	End Object
	Components.Add(FlakLight)

	DrawScale=1.5
}
