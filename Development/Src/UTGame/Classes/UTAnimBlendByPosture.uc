class UTAnimBlendByPosture extends UTAnimBlendBase
	native;                                         

cpptext
{
	virtual	void TickAnim( FLOAT DeltaSeconds );
}


defaultproperties
{
	Children(0)=(Name="Run",Weight=1.0)
	Children(1)=(Name="Crouch")
	bFixNumChildren=true
}
