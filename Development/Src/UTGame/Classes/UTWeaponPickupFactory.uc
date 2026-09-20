class UTWeaponPickupFactory extends UTPickupFactory;

var() class<Weapon>		WeaponPickupClass;
var   bool				bWeaponStay;

simulated function PreBeginPlay()
{
	InventoryType = WeaponPickupClass;
	SetWeaponStay();
	Super.PreBeginPlay();
}

simulated function SetPickupHidden()
{
	bForceNetUpdate = true;
	Super.SetPickupHidden();
}

simulated function SetPickupVisible()
{
	bForceNetUpdate = true;
	Super.SetPickupVisible();
}

simulated function Tick(float DeltaTime)
{
	// fixmesteve - move to C++
	local Rotator R;

	R = PickupMesh.Rotation;
	R.Yaw += DeltaTime * RotationRate.Yaw;
	PickupMesh.SetRotation(R);
}

function bool CheckForErrors()
{
	if ( Super.CheckForErrors() )
		return true;

	if ( WeaponPickupClass == None )
	{
		`log(self$" no weapon pickup class");
		return true;
	}

	return false;
}

function SetWeaponStay()
{
	bWeaponStay = ( bWeaponStay && UTGame(WorldInfo.Game).bWeaponStay );
}

function StartSleeping()
{
	if (!bWeaponStay)
	    GotoState('Sleeping');
}

function bool AllowRepeatPickup()
{
    return !bWeaponStay;
}

/*
*/
defaultproperties
{
	Components.Remove(Sprite)

	bWeaponStay=true
	RotationRate=(Yaw=32768)
	bStatic=false

	Begin Object Class=StaticMeshComponent Name=StaticMeshComponent0
		StaticMesh=StaticMesh'Pickups.WeaponBase.S_Pickups_WeaponBase'
		bOwnerNoSee=true
		CollideActors=false
		Translation=(X=0.0,Y=0.0,Z=-44.0)
		Scale3D=(X=1.0,Y=1.0,Z=1.0)
	End Object
	Components.Add(StaticMeshComponent0)
}
