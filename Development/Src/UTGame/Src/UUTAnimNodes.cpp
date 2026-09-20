//=============================================================================
// Copyright 2004 Epic Games - All Rights Reserved.
// Confidential.
//=============================================================================

#include "UTGame.h"

IMPLEMENT_CLASS(UUTAnimBlendBase);
IMPLEMENT_CLASS(UUTAnimBlendByIdle);
IMPLEMENT_CLASS(UUTAnimNodeSequence);
IMPLEMENT_CLASS(UUTAnimBlendByPhysics);
IMPLEMENT_CLASS(UUTAnimBlendByFall);
IMPLEMENT_CLASS(UUTAnimBlendByPosture);
IMPLEMENT_CLASS(UUTAnimBlendByWeapon);
IMPLEMENT_CLASS(UUTAnimBlendByDirection);
IMPLEMENT_CLASS(UUTAnimBlendByDodge);


/**
 *  BlendByPhysics - This AnimNode type is used to determine which branch to player
 *  by looking at the current physics of the pawn.  It uses that value to choose a node
 */
void UUTAnimBlendByPhysics::TickAnim( FLOAT DeltaSeconds )
{
	// Get the Pawn Owner
	APawn* POwner = Cast<APawn>(SkelComponent ? SkelComponent->GetOwner() : NULL);
	if ( POwner != NULL )
	{
		// Get the current physics from the pawn

		INT CurrentPhysics = INT(POwner->Physics);

		// If the physics has changed, and there is a valid blend for it, blend to that value

		if ( LastPhysics != CurrentPhysics )
		{
			INT PhysicsIndex = PhysicsMap[CurrentPhysics];
			SetActiveChild( PhysicsIndex,eventGetBlendTime(PhysicsIndex,false) );
			// This snapshot has no matching UnrealScript ChangeAnimation event.
		}

		LastPhysics = CurrentPhysics;			
		Super::TickAnim(DeltaSeconds);
	}
}

/**
 * BlendByFall - Will use the pawn's Z Velocity to determine what type of blend to perform.  
 * -- FIXME: Add code to trace to the ground and blend to landing
 */

void UUTAnimBlendByFall::TickAnim( FLOAT DeltaSeconds )
{

	if ( NodeTotalWeight > ZERO_ANIMWEIGHT_THRESH )
	{
		APawn* POwner = Cast<APawn>(SkelComponent ? SkelComponent->GetOwner() : NULL);
		if ( POwner != NULL )
		{
			if (POwner->Physics == PHYS_Falling)
			{
				FLOAT FallingVelocity = POwner->Velocity.Z;
				switch (FallState)
				{
					case FBT_Land:
					case FBT_None:		//------------- We were inactive, determine the initial state

						if ( FallingVelocity < 0 )			// Falling
							ChangeFallState(FBT_Down);
						else								// Jumping
		
							ChangeFallState(FBT_Up);
															
						SetActiveChild(FallState, 0.f);

						break;

					case FBT_Up:		//------------- We are jumping
						if ( LastFallingVelocity < FallingVelocity )	// Double Jump
						{
							ChangeFallState(FBT_Up);
						}

						else if (FallingVelocity <= 0)					// Begun to fall
							ChangeFallState(FBT_Down);

						break;
						
					case FBT_Down:		//------------- We are falling

						if ( !bDodgeFall && FallingVelocity > 0 && FallingVelocity > LastFallingVelocity )		// Double Jump
							ChangeFallState(FBT_Up);
						else
						{
							if (!bDodgeFall)
							{

								DWORD TraceFlags = TRACE_World;
								FCheckResult Hit(1.f);

								FVector HowFar = POwner->Velocity * eventGetBlendTime(FBT_PreLand,false) * 1.5;
								GWorld->SingleLineCheck(Hit, POwner, POwner->Location + HowFar, POwner->Location,TraceFlags);

								if ( Hit.Actor ) 
								{
									ChangeFallState(FBT_PreLand);
								}
							}
							else if ( FallingVelocity < 0 )
							{
									ChangeFallState(FBT_PreLand);
									BlendTimeToGo = 1.0f; //FallTime;
							}

						}

						break;
				}
				LastFallingVelocity = FallingVelocity;
			}
			else if ( FallState != FBT_Land )
			{
				ChangeFallState(FBT_Land);
			}

		}
	}
	Super::TickAnim(DeltaSeconds);

}

void UUTAnimBlendByFall::SetActiveChild( INT ChildIndex, FLOAT BlendTime )
{
	Super::SetActiveChild(ChildIndex,BlendTime);

	if ( Cast<UAnimNodeSequence>( Children(ChildIndex).Anim ) )
	{
		UAnimNodeSequence* P = Cast<UAnimNodeSequence>( Children(ChildIndex).Anim );	
		P->PlayAnim(P->bLooping);
	}
}


void UUTAnimBlendByFall::OnChildAnimEnd(UAnimNodeSequence* Child, FLOAT PlayedTime, FLOAT ExcessTime)
{
	if ( bDodgeFall && FallState == FBT_Up && Child == Children(FBT_Up).Anim )
	{
		ChangeFallState(FBT_Down);
	}

	Super::OnChildAnimEnd(Child, PlayedTime, ExcessTime);
}
		

// Changes the falling state

void UUTAnimBlendByFall::ChangeFallState(EBlendFallTypes NewState)
{
	if (FallState != NewState)
	{
		FallState = NewState;
		if (FallState!=FBT_None)
		{
			SetActiveChild( NewState, eventGetBlendTime(NewState,false) );
		}
	}
}

/**
 *  BlendByPosture is used to determine if we should be playing the Crouch/walk animations, or the 
 *  running animations.
 */

void UUTAnimBlendByPosture::TickAnim( FLOAT DeltaSeconds )
{
	// Get the Pawn Owner
	APawn* POwner = Cast<APawn>(SkelComponent ? SkelComponent->GetOwner() : NULL);
	if ( POwner != NULL )
	{
		if ( POwner->bIsCrouched && ActiveChildIndex!=1 )
		{
			SetActiveChild(1,0);
		}
		else if ( ActiveChildIndex != 0 )
		{
			SetActiveChild(0,0); // FIXME: Add a blend rate
		}

	}
	Super::TickAnim(DeltaSeconds);
}

/**
 * BlendByWeapon - This node is NOT automanaged.  Instead it's designed to have it's Fire/StopFire functions
 * called.  If it's playing a firing animation that's not looping (ie: not auto-fire) it will blend back out after the
 * animation completes.
 */

void UUTAnimBlendByWeapon::OnChildAnimEnd(UAnimNodeSequence* Child, FLOAT PlayedTime, FLOAT ExcessTime)
{
	Super::OnChildAnimEnd(Child, PlayedTime, ExcessTime);

	// Call the script event if we are not looping.

	if (!bLooping)
		eventAnimStopFire( BlendTime );
}


/** 
 * BlendByDirection nodes look at the direction their owner is moving and use it to
 * blend between the different children.  We have extended the Base (BlendDirectional) in
 * order to add the ability to adjust the animation speed of one of this node's children
 * depending on the velocity of the pawn.  
 */

void UUTAnimBlendByDirection::TickAnim( FLOAT DeltaSeconds )
{

	// We only work if we are visible

	if ( NodeTotalWeight > ZERO_ANIMWEIGHT_THRESH )
	{
		// bAdjustRateByVelocity is used to make the animation slow down the animation

		if (bAdjustRateByVelocity)
		{
			APawn* POwner = Cast<APawn>(SkelComponent ? SkelComponent->GetOwner() : NULL);
			if ( POwner != NULL )
			{
				FLOAT NewRate = POwner->Velocity.Size() / POwner->GroundSpeed;
				for (INT i=0;i<Children.Num();i++)
				{
					if ( Cast<UUTAnimNodeSequence>(Children(i).Anim) )
						Cast<UUTAnimNodeSequence>(Children(i).Anim)->Rate = NewRate;
				}
			}
		}

		EBlendDirTypes	CurrentDirection = Get4WayDir();

		if (CurrentDirection != LastDirection)		// Direction changed
		{
			SetActiveChild( CurrentDirection, eventGetBlendTime(CurrentDirection,false) );
		}

		LastDirection = CurrentDirection;

	}
	else
		LastDirection = FBDir_None;

	Super::TickAnim(DeltaSeconds);

}

void UUTAnimBlendByDirection::OnCeaseRelevant()
{
	Super::OnCeaseRelevant();
	LastDirection = FBDir_None;
}

void UUTAnimBlendByDirection::SetActiveChild( INT ChildIndex, FLOAT BlendTime )
{
	Super::SetActiveChild(ChildIndex,BlendTime);

	if ( Cast<UAnimNodeSequence>( Children(ChildIndex).Anim ) )
	{
		UAnimNodeSequence* P = Cast<UAnimNodeSequence>( Children(ChildIndex).Anim );
		P->PlayAnim(P->bLooping);
	}
}


EBlendDirTypes UUTAnimBlendByDirection::Get4WayDir()
{

    FLOAT forward, right;
    FVector V;

	APawn* POwner = Cast<APawn>(SkelComponent ? SkelComponent->GetOwner() : NULL);
	if ( POwner != NULL )
	{
		V = POwner->Velocity;
		V.Z = 0.0f;

		if ( V.IsNearlyZero() )
			return FBDir_Forward;

		FRotationMatrix RotMatrix(POwner->Rotation);

		V.Normalize();
		forward = RotMatrix.GetAxis(0) | V;
		if (forward > 0.82f) // 55 degrees
			return FBDir_Forward;
		else if (forward < -0.82f)
			return FBDir_Back;
		else
		{
			right = RotMatrix.GetAxis(1) | V;
			
			if (right > 0.0f)
				return FBDir_Right;
			else
				return FBDir_Left;
		}
	}
	
	return FBDir_Forward;

}


/**
 * This blend looks at the velocity of the player and blends depending on if they are moving or not
 */

void UUTAnimBlendByIdle::TickAnim(FLOAT DeltaSeconds)
{
	// Get the Pawn Owner
	APawn* POwner = Cast<APawn>(SkelComponent ? SkelComponent->GetOwner() : NULL);
	if ( POwner != NULL )
	{
		if ( POwner->Velocity.Size() == 0)
			SetActiveChild(0,BlendTime);
		else
			SetActiveChild(1,BlendTime);
	}
	Super::TickAnim(DeltaSeconds);
}

/**
 * When the sequence becomes relevant, check whether it should restart the animation.
 */

void UUTAnimNodeSequence::OnBecomeRelevant()
{
	Super::OnBecomeRelevant();

	if (bResetOnActivate)
	{
		ReplayAnim();
	}
}

/**
 * BlendByDodge checkes the velocity to determine if a dodge has occured.
 */

void UUTAnimBlendByDodge::TickAnim(FLOAT DeltaSeconds)
{
	// Find the type of dodge to perform

	if ( NodeTotalWeight > ZERO_ANIMWEIGHT_THRESH ) 
	{

		// Get the Pawn Owner
		APawn* POwner = Cast<APawn>(SkelComponent ? SkelComponent->GetOwner() : NULL);
		if ( POwner != NULL )
		{
			if (POwner->Physics == PHYS_Falling)		// If we aren't falling ,we aren't dodging
			{

				// Check to see if we have any weight and if so, are we not dodging yet?

				if (CurrentDodge == DODGEBLEND_None)
				{
					float DodgeSpeedThresh = ((POwner->GroundSpeed * 1.5) + POwner->GroundSpeed) * 0.5f ;
					float XYVelocitySquared = (POwner->Velocity.X*POwner->Velocity.X)+(POwner->Velocity.Y*POwner->Velocity.Y);

					// Check to see if we are actually Dodging

					if ( XYVelocitySquared > DodgeSpeedThresh*DodgeSpeedThresh ) 
					{
						INT	CurrentDirection = Get4WayDir();

						UUTAnimBlendByFall* BFall = Cast<UUTAnimBlendByFall>( Children(1).Anim );
						if (BFall)
						{
							for (INT i=0;i<4;i++)
							{	
								BFall->Children(i).Anim->SetAnim(DodgeAnims[ (CurrentDirection*4) + i]);
							}
						}

						CurrentDodge = CurrentDirection + 1;
						SetActiveChild(1, eventGetBlendTime(1,false) );
					}
				}

			}
			else if (CurrentDodge != DODGEBLEND_None)
			{
				SetActiveChild(0,eventGetBlendTime(0,false) );
				CurrentDodge = DODGEBLEND_None;
			}
		}
	}

	UAnimNodeBlendList::TickAnim(DeltaSeconds);

}

void UUTAnimBlendByDodge::OnCeaseRelevant()
{
	Super::OnCeaseRelevant();

	if ( CurrentDodge != DODGEBLEND_None )
	{
		SetActiveChild(0, 0.f);
		CurrentDodge = DODGEBLEND_None;
	}
}
