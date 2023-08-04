/*
 * Modified Stalker - her combat and stealth capabilities depend on difficulty!
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : MIT
 * Copyright    : 2023 theengineertcr
*/
class AdvZombieStalker extends AdvZombieStalkerBase
    abstract;


// Package loading
#exec OBJ LOAD FILE=KFAdvZeds_A.ukx
#exec OBJ LOAD FILE=KFAdvZeds_T.utx
#exec OBJ LOAD FILE=KFX.utx
#exec OBJ LOAD FILE=KF_BaseStalker.uax


//----------------------------------------------------------------------------
// NOTE: All Variables are declared in the base class to eliminate hitching
//----------------------------------------------------------------------------

// Variables
// TODO: Implement configs into mut class & assign each ability to a difficulty level
var bool bDisorientingAttacks;  // Shake the targets view, causing them to be disoriented.
var bool bPiercingAttacks;		// Pierce through the targets armour, dealing damage to their health.
var bool bLeapIfSpotted;		// Leap behind your target if they're facing towards you and you're close.
var bool bPreservativeDodge;   	// Dodge away from danger to preserve your life(nearby zed dies, grenade/medic smoke, taking damage).
var bool bSpeedboostAfterAttack;// Gain a % increase in movement and dodge speed after striking their target.
var float  SoundLevelMultiplier;// Multiplier that's used to reduce the volume of her sounds.


simulated function PostBeginPlay()
{
    // Difficulty Scaling for her stealthiness
    if (Level.Game != none && !bDiffAdjusted)
    {
        if( Level.Game.GameDifficulty < 2.0 )
        {
            SoundLevelMultiplier = 1;
			Skins[0] = Shader'KF_Specimens_Trip_T.stalker_invisible';
			Skins[1] = Shader'KF_Specimens_Trip_T.stalker_invisible';
        }
        else if( Level.Game.GameDifficulty < 4.0 )
        {
            SoundLevelMultiplier = 0.10;
			Skins[0] = ColorModifier'KFAdvZeds_T.Stalker_Hard';
			Skins[1] = ColorModifier'KFAdvZeds_T.Stalker_Hard';
        }
        else if( Level.Game.GameDifficulty < 5.0 )
        {
            SoundLevelMultiplier = 0.07;
			Skins[0] = ColorModifier'KFAdvZeds_T.Stalker_Sui';
			Skins[1] = ColorModifier'KFAdvZeds_T.Stalker_Sui';
        }
        else // Hardest difficulty
        {
            SoundLevelMultiplier = 0.05;
			Skins[0] = ColorModifier'KFAdvZeds_T.Stalker_HOE';
			Skins[1] = ColorModifier'KFAdvZeds_T.Stalker_HOE';
        }
    }
	SoundRadius *=(SoundLevelMultiplier);
    SoundVolume *= (SoundLevelMultiplier);
	MoanVolume *= (SoundLevelMultiplier - 0.05);
	GruntVolume *= (SoundLevelMultiplier - 0.05);
    TransientSoundRadius*= (SoundLevelMultiplier);
	AmbientSoundScaling *= (SoundLevelMultiplier);

	CloakStalker();
	super.PostBeginPlay();
}

function ClawDamageTarget()
{
    local vector PushDir;
    local KFHumanPawn HumanTarget;
    local KFPlayerController HumanTargetController;
    local float UsedMeleeDamage;

	super.ClawDamageTarget();

    if (MeleeDamageTarget(UsedMeleeDamage,PushDir))
    {
        HumanTarget = KFHumanPawn(Controller.Target);

        if( HumanTarget!=none )
            HumanTargetController = KFPlayerController(HumanTarget.Controller);

		//If were flanking our target, or were not exhausted from performing a leap attack, our strikes will disorient our foe's view.
        if( HumanTargetController!=none && (AdvStalkerController(Controller).bFlanking || (AdvStalkerController(Controller).LastPounceTime + (12 - 1.5)) < Level.TimeSeconds))
            HumanTargetController.ShakeView(RotMag, RotRate, RotTime, OffsetMag, OffsetRate, OffsetTime);
	}
}

function RangedAttack(Actor A)
{
	if((AdvStalkerController(Controller).LastPounceTime + (12 - 1.5)) < Level.TimeSeconds && !AdvStalkerController(Controller).bFlanking && (Physics == PHYS_Walking) && VSize(A.Location-Location)<=100)
	{
		SetAnimAction('DodgeF');
		Controller.GoToState('WaitForAnim');
		PrepareToPounce();
	}
	else if ( bShotAnim || (Physics != PHYS_Walking))
		return;
	else if ( CanAttack(A) )
	{
		bShotAnim = true;
		SetAnimAction('Claw');
		Controller.bPreparingMove = true;
		Acceleration = vect(0,0,0);
		return;
	}
}

function bool DoPounce()
{
	if ( bZapped || bIsCrouched || bWantsToCrouch || bShotAnim || (Physics != PHYS_Walking))
		return false;

	CloakStalker();
	Velocity = Normal(Controller.Target.Location-Location)*PounceSpeed;
	Velocity.Z = JumpZ * 1.75;
	SetPhysics(PHYS_Falling);
	SetCollision(false, false, false);
	SetAnimAction('HitB');
	Controller.GoToState('WaitForAnim');
	bPouncing=true;
	return true;
}


function PrepareToPounce()
{
	if ( bZapped || bIsCrouched || bWantsToCrouch || (Physics != PHYS_Walking))
		return;

	Velocity = Normal(Location-Controller.Target.Location)*PounceSpeed*0.7;
	Velocity.Z = JumpZ * 0.5;
	SetPhysics(PHYS_Falling);
	bPouncing=true;
}

event Landed(vector HitNormal)
{
	bPouncing=false;
	SetCollision(true, true, true);
	super.Landed(HitNormal);
}

simulated function BeginPlay()
{
    // Link the mesh to our custom animations
    LinkSkelAnim(MeshAnimation'AdvStalker_Anim');
    Super.BeginPlay();
}

// Footsteps are linked to Anim-notifies
simulated function StalkerFootstep()
{
	PlaySound(sound'KF_EnemiesFinalSnd.Stalker.Stalker_StepDefault', SLOT_None, FootstepVolume * (SoundLevelMultiplier));
}


simulated function PostNetBeginPlay()
{
    local PlayerController PC;

	super.PostNetBeginPlay();

	if( Level.NetMode!=NM_DedicatedServer )
	{
        PC = Level.GetLocalPlayerController();
        if( PC != none && PC.Pawn != none )
        {
            LocalKFHumanPawn = KFHumanPawn(PC.Pawn);
        }
	}
}

simulated event SetAnimAction(name NewAction)
{
	if ( NewAction == 'Claw' || NewAction == MeleeAnims[0] || NewAction == MeleeAnims[1] || NewAction == MeleeAnims[2] )
	{
		UncloakStalker();
	}

	super.SetAnimAction(NewAction);
}


simulated function Tick(float DeltaTime)
{
	Super.Tick(DeltaTime);


	if( Level.NetMode==NM_DedicatedServer )
		Return; // Servers aren't intrested in this info.

    if( bZapped )
    {
        // Make sure we check if we need to be cloaked as soon as the zap wears off
        NextCheckTime = Level.TimeSeconds;
    }
	else if( Level.TimeSeconds > NextCheckTime && Health > 0 )
	{
		NextCheckTime = Level.TimeSeconds + 0.5;

        if( LocalKFHumanPawn != none && LocalKFHumanPawn.Health > 0 && LocalKFHumanPawn.ShowStalkers() &&
            VSizeSquared(Location - LocalKFHumanPawn.Location) < LocalKFHumanPawn.GetStalkerViewDistanceMulti() * 640000.0 ) // 640000 = 800 Units
        {
			bSpotted = True;
		}
		else
		{
			bSpotted = false;
		}

		if ( !bSpotted && !bCloaked && Skins[0] != Combiner'KF_Specimens_Trip_T.stalker_cmb' )
		{
			UncloakStalker();
		}
		else if ( Level.TimeSeconds - LastUncloakTime > 1.2 )
		{
			// if we're uberbrite, turn down the light
			if( bSpotted && Skins[0] != Finalblend'KFX.StalkerGlow' )
			{
				bUnlit = false;
				CloakStalker();
			}
			else if ( Skins[0] != Shader'KF_Specimens_Trip_T.stalker_invisible')
			{
				CloakStalker();
			}
		}
		if(bCloaked)
		{
			if(PlayerShadow != none)
				PlayerShadow.bShadowActive = false;
			if(RealTimeShadow != none)
				RealTimeShadow.Destroy();
		}
	}
	// If were behind our target, our attacks pierce through their armour
	if(AdvStalkerController(Controller).bFlanking && ZombieDamType[0]!=Class'DamTypeStalkerAPClaws')
	{
			ZombieDamType[0]=Class'DamTypeStalkerAPClaws';
			ZombieDamType[1]=Class'DamTypeStalkerAPClaws';
			ZombieDamType[2]=Class'DamTypeStalkerAPClaws';
	}
	else if(!AdvStalkerController(Controller).bFlanking && ZombieDamType[0]!=Class'DamTypeSlashingAttack')
	{
		ZombieDamType[0]=Class'DamTypeSlashingAttack';
		ZombieDamType[1]=Class'DamTypeSlashingAttack';
		ZombieDamType[2]=Class'DamTypeSlashingAttack';
	}
}

// Cloak Functions ( called from animation notifies to save Gibby trouble ;) )

simulated function CloakStalker()
{
	if ( bSpotted && !bZapped && !bDecapitated && !bCrispified)
	{
		if( Level.NetMode == NM_DedicatedServer )
			return;

		Skins[0] = Finalblend'KFX.StalkerGlow';
		Skins[1] = Finalblend'KFX.StalkerGlow';
		bUnlit = true;
		return;
	}

    // No cloaking if zapped
    if( bZapped || bCloaked)
    {
        return;
    }

	if ( !bDecapitated && !bCrispified ) // No head, no cloak, honey.  updated :  Being charred means no cloak either :D
	{
		Visibility = 1;
		bCloaked = true;

		if( Level.NetMode == NM_DedicatedServer )
			Return;

		if(Level.Game.GameDifficulty < 2.0)
		{
			Skins[0] = Shader'KF_Specimens_Trip_T.stalker_invisible';
			Skins[1] = Shader'KF_Specimens_Trip_T.stalker_invisible';
		}
        else if( Level.Game.GameDifficulty < 4.0 )
        {
			Skins[0] = ColorModifier'KFAdvZeds_T.Stalker_Hard';
			Skins[1] = ColorModifier'KFAdvZeds_T.Stalker_Hard';
        }
        else if( Level.Game.GameDifficulty < 5.0 )
        {
			Skins[0] = ColorModifier'KFAdvZeds_T.Stalker_Sui';
			Skins[1] = ColorModifier'KFAdvZeds_T.Stalker_Sui';
        }
        else // Hardest difficulty
        {
			Skins[0] = ColorModifier'KFAdvZeds_T.Stalker_HOE';
			Skins[1] = ColorModifier'KFAdvZeds_T.Stalker_HOE';
        }

		// Invisible - no shadow
		if(PlayerShadow != none)
			PlayerShadow.bShadowActive = false;
		if(RealTimeShadow != none)
			RealTimeShadow.Destroy();

		// Remove/disallow projectors on invisible people
		Projectors.Remove(0, Projectors.Length);
		bAcceptsProjectors = false;
		SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.25, true);
	}
}

simulated function UnCloakStalker()
{
    if( bZapped )
    {
        return;
    }

	if( !bCrispified )
	{
		LastUncloakTime = Level.TimeSeconds;

		Visibility = default.Visibility;
		bCloaked = false;
		bUnlit = false;

		// 25% chance of our Enemy saying something about us being invisible
		// Doesn't work past normal difficulty
		if( Level.NetMode!=NM_Client && !KFGameType(Level.Game).bDidStalkerInvisibleMessage && FRand()<0.25 && Controller.Enemy!=none &&
		 PlayerController(Controller.Enemy.Controller)!=none  && Level.Game.GameDifficulty < 2.0)
		{
			PlayerController(Controller.Enemy.Controller).Speech('AUTO', 17, "");
			KFGameType(Level.Game).bDidStalkerInvisibleMessage = true;
		}
		if( Level.NetMode == NM_DedicatedServer )
			Return;

		if ( Skins[0] != Combiner'KF_Specimens_Trip_T.stalker_cmb' )
		{
			Skins[1] = FinalBlend'KF_Specimens_Trip_T.stalker_fb';
			Skins[0] = Combiner'KF_Specimens_Trip_T.stalker_cmb';

			if (PlayerShadow != none)
				PlayerShadow.bShadowActive = true;

			bAcceptsProjectors = true;

			SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.25, true);
		}
	}
}

// Set the zed to the zapped behavior
simulated function SetZappedBehavior()
{
    super.SetZappedBehavior();

    bUnlit = false;

	// Handle setting the zed to uncloaked so the zapped overlay works properly
    if( Level.Netmode != NM_DedicatedServer )
	{
        Skins[1] = FinalBlend'KF_Specimens_Trip_T.stalker_fb';
		Skins[0] = Combiner'KF_Specimens_Trip_T.stalker_cmb';

		if (PlayerShadow != none)
			PlayerShadow.bShadowActive = true;

		bAcceptsProjectors = true;
		SetOverlayMaterial(Material'KFZED_FX_T.Energy.ZED_overlay_Hit_Shdr', 999, true);
	}
}

// Turn off the zapped behavior
simulated function UnSetZappedBehavior()
{
    super.UnSetZappedBehavior();

	// Handle getting the zed back cloaked if need be
    if( Level.Netmode != NM_DedicatedServer )
	{
        NextCheckTime = Level.TimeSeconds;
        SetOverlayMaterial(None, 0.0f, true);
	}
}

// Overridden because we need to handle the overlays differently for zombies that can cloak
function SetZapped(float ZapAmount, Pawn Instigator)
{
    LastZapTime = Level.TimeSeconds;

    if( bZapped )
    {
        TotalZap = ZapThreshold;
        RemainingZap = ZapDuration;
    }
    else
    {
        TotalZap += ZapAmount;

        if( TotalZap >= ZapThreshold )
        {
            RemainingZap = ZapDuration;
              bZapped = true;
        }
    }
    ZappedBy = Instigator;
}

function RemoveHead()
{
	Super.RemoveHead();

	if (!bCrispified)
	{
		Skins[1] = FinalBlend'KF_Specimens_Trip_T.stalker_fb';
		Skins[0] = Combiner'KF_Specimens_Trip_T.stalker_cmb';
	}
}

simulated function PlayDying(class<DamageType> DamageType, vector HitLoc)
{
	Super.PlayDying(DamageType,HitLoc);

	if(bUnlit)
		bUnlit=!bUnlit;

    LocalKFHumanPawn = none;

	if (!bCrispified)
	{
		Skins[1] = FinalBlend'KF_Specimens_Trip_T.stalker_fb';
		Skins[0] = Combiner'KF_Specimens_Trip_T.stalker_cmb';
	}
}

// Give her the ability to spring.
function bool DoJump( bool bUpdating )
{
	if ( !bIsCrouched && !bWantsToCrouch && ((Physics == PHYS_Walking) || (Physics == PHYS_Ladder) || (Physics == PHYS_Spider)) )
	{
		if ( Role == ROLE_Authority )
		{
			if ( (Level.Game != None) && (Level.Game.GameDifficulty > 2) )
				MakeNoise(0.1 * Level.Game.GameDifficulty);
			if ( bCountJumps && (Inventory != None) )
				Inventory.OwnerEvent('Jumped');
		}
		if ( Physics == PHYS_Spider )
			Velocity = JumpZ * Floor;
		else if ( Physics == PHYS_Ladder )
			Velocity.Z = 0;
		else if ( bIsWalking )
		{
			Velocity.Z = Default.JumpZ;
			Velocity.X = (Default.JumpZ * 0.6);
		}
		else
		{
			Velocity.Z = JumpZ;
			Velocity.X = (JumpZ * 0.6);
		}
		if ( (Base != None) && !Base.bWorldGeometry )
		{
			Velocity.Z += Base.Velocity.Z;
			Velocity.X += Base.Velocity.X;
		}
		SetPhysics(PHYS_Falling);
		return true;
	}
	return false;
}

static simulated function PreCacheMaterials(LevelInfo myLevel)
{//should be derived and used.
	myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T.stalker_cmb');
	myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T.stalker_env_cmb');
	myLevel.AddPrecacheMaterial(Texture'KF_Specimens_Trip_T.stalker_diff');
	myLevel.AddPrecacheMaterial(Texture'KF_Specimens_Trip_T.stalker_spec');
	myLevel.AddPrecacheMaterial(Material'KF_Specimens_Trip_T.stalker_invisible');
	myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T.StalkerCloakOpacity_cmb');
	myLevel.AddPrecacheMaterial(Material'KF_Specimens_Trip_T.StalkerCloakEnv_rot');
	myLevel.AddPrecacheMaterial(Material'KF_Specimens_Trip_T.stalker_opacity_osc');
	myLevel.AddPrecacheMaterial(Material'KFCharacters.StalkerSkin');
}

defaultproperties
{
	//-------------------------------------------------------------------------------
	// NOTE: Most Default Properties are set in the base class to eliminate hitching
	//-------------------------------------------------------------------------------
	EventClasses(0)="KFAdvZeds.AdvZombieStalker_S"
	ControllerClass=Class'KFAdvZeds.AdvStalkerController'
}
