class UTCharacter extends UTPawn
	Placeable;

var UTAnimBlendByWeapon		WeaponBlend;

simulated event PostBeginPlay()
{
	Super.PostBeginPlay();

	if (Mesh != None && Mesh.Animations != None)
	{
		WeaponBlend = UTAnimBlendByWeapon(Mesh.Animations.FindAnimNode('FireNode'));
	}

	if (WeaponBlend==None)
		`warn("Could not find Firing Node (firenode) for this mesh ("$Mesh$")");

}

simulated event Destroyed()
{
	WeaponBlend = none;

	super.Destroyed();
}


/** Plays a Firing Animation */

simulated function PlayFiring(float Rate, name InFiringMode)
{
	if (WeaponBlend != None)
	{
		WeaponBlend.AnimFire('fire_straight_rif',false,Rate, 0.15);
	}
}

simulated function StopPlayFiring()
{
	if (WeaponBlend != None)
	{
		WeaponBlend.AnimStopFire(0.15);
	}
}

defaultproperties
{
	DefaultInventory(0)=class'UTWeap_Minigun'

	Begin Object Class=AnimNodeSequence Name=PawnIdleSequence
		NodeName=IdleSequence
		AnimSeqName="idle_ready_rif"
		bLooping=true
		bPlaying=true
	End Object

	Begin Object Class=AnimNodeSequence Name=PawnFireSequence
		NodeName=FireSequence
		AnimSeqName="fire_straight_rif"
	End Object

	Begin Object Class=UTAnimBlendByWeapon Name=PawnFireBlend
		NodeName=FireNode
		Children(0)=(Anim=PawnIdleSequence,Name="Not-Firing",Weight=1.0)
		Children(1)=(Anim=PawnFireSequence,Name="Firing")
		BranchStartBoneName(0)=Spine
	End Object

	Begin Object Class=SkeletalMeshComponent Name=WPawnSkeletalMeshComponent
		SkeletalMesh=SkeletalMesh'CH_IronGuard_Male.Mesh.SK_CH_IronGuard_MaleA'
		PhysicsAsset=none
		AnimSets(0)=AnimSet'CH_AnimHuman.Anims.K_AnimHuman_BaseMale'
		Animations=PawnFireBlend
		AlwaysLoadOnClient=true
		AlwaysLoadOnServer=true
		bOwnerNoSee=true
		CastShadow=false
	End Object
	Mesh=WPawnSkeletalMeshComponent
	Components.Add(WPawnSkeletalMeshComponent)
	Components.Remove(Sprite)

	WeaponBone=WeaponPoint

}
