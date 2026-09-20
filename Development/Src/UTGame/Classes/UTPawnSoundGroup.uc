class UTPawnSoundGroup extends Object
	abstract;

var SoundCue DodgeSound;
var SoundCue DoubleJumpSound;
var SoundCue JumpSound;
var SoundCue LandSound;
var SoundCue FootStepSound;
var SoundCue DyingSound;

static function PlayDodgeSound(Pawn P)
{
	P.PlaySound(Default.DodgeSound);
}

static function PlayDoubleJumpSound(Pawn P)
{
	P.PlaySound(Default.DoubleJumpSound);
}

static function PlayJumpSound(Pawn P)
{
	P.PlaySound(Default.JumpSound);
}

static function PlayLandSound(Pawn P)
{
    //    PlayOwnedSound(GetSound(EST_Land), SLOT_Interact, FMin(1,-0.3 * P.Velocity.Z/P.JumpZ));
	P.PlaySound(Default.LandSound);
}	

static function PlayFootStepSound( Pawn P, int FootDown )
{
	P.PlaySound(Default.FootStepSound);
}

static function PlayDyingSound(Pawn P)
{
	P.PlaySound(Default.DyingSound);
}

defaultproperties
{
	DodgeSound=SoundCue'A_Character_CorruptEnigma_Cue.Mean_Efforts.A_Effort_EnigmaMean_Dodge_Cue'
	DoubleJumpSound=SoundCue'A_Character_CorruptEnigma_Cue.Mean_Efforts.A_Effort_EnigmaMean_DoubleJump_Cue'
	JumpSound=SoundCue'A_Character_Footsteps.FootSteps.A_Character_Footstep_DirtJumpCue'
	LandSound=SoundCue'A_Character_CorruptEnigma_Cue.Mean_Efforts.A_Effort_EnigmaMean_LandLight_Cue'
	FootStepSound=SoundCue'A_Character_Footsteps.FootSteps.A_Character_Footstep_DefaultCue'
	DyingSound=SoundCue'A_Character_CorruptEnigma_Cue.Mean_Efforts.A_Effort_EnigmaMean_Death_Cue'
}
