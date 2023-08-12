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


// TODO: Figure out a way to only disable Stalker's collision with
// Other zeds and players, otherwise they're invincible while they-
// -'re Leaping around.
// TODO: Make stalkers flank around their target

//----------------------------------------------------------------------------
// NOTE: All Variables are declared in the base class to eliminate hitching
//----------------------------------------------------------------------------

simulated function PostBeginPlay()
{
    // Difficulty Scaling for her stealthiness
    if (Level.Game != none && !bDiffAdjusted)
    {
        Skins[0] = GetCloakSkin();
        Skins[1] = GetCloakSkin();
        FootStepVolume = GetFootstepVolume();
        FootStepRadius = GetFootstepRadius();
        if( (Level.Game.GameDifficulty < 4.0 && !bIgnoreDifficulty) || StealthLevel == 0 && bIgnoreDifficulty)
        {
            SoundRadius = 40;
            SoundVolume = 50;
            MoanVolume  = 1.0;
            GruntVolume = 1.0;
            TransientSoundRadius = 500;
            AmbientSoundScaling  = 6.8;
        }
        else if( (Level.Game.GameDifficulty <= 4.0 && !bIgnoreDifficulty) || StealthLevel == 1 && bIgnoreDifficulty)
        {
            SoundRadius = 20;
            SoundVolume = 25;
            MoanVolume  = 0.75;
            GruntVolume = 0.75;
            TransientSoundRadius = 250;
            AmbientSoundScaling  = 3.4;
        }
        else if( (Level.Game.GameDifficulty <= 5.0 && !bIgnoreDifficulty) || StealthLevel == 2 && bIgnoreDifficulty)
        {
            SoundRadius = 12;
            SoundVolume = 12;
            MoanVolume  = 0.375;
            GruntVolume = 0.375;
            TransientSoundRadius = 125;
            AmbientSoundScaling  = 1.7;
        }
        else if( (Level.Game.GameDifficulty > 5.0 && !bIgnoreDifficulty) || StealthLevel == 3 && bIgnoreDifficulty)
        {
            SoundRadius = 6;
            SoundVolume = 8;
            MoanVolume  = 0.150;
            GruntVolume = 0.150;
            TransientSoundRadius = 50;
            AmbientSoundScaling  = 1.0;
        }
    }

    CloakStalker();
    super.PostBeginPlay();
}

function PlayChallengeSound()
{
        if( (Level.Game.GameDifficulty <= 4.0 && !bIgnoreDifficulty) || StealthLevel <= 1 && bIgnoreDifficulty)
        {
            PlaySound(ChallengeSound[Rand(4)],SLOT_Talk,GruntVolume);
        }
        else return;
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
        if( (HumanTargetController!=none && (AdvStalkerController(Controller).bFlanking || (AdvStalkerController(Controller).LastPounceTime + (12 - 1.5)) < Level.TimeSeconds))
            && bDisorientingAttacks && (Level.Game.GameDifficulty >= 4.0 || bIgnoreDifficulty))
            HumanTargetController.ShakeView(RotMag, RotRate, RotTime, OffsetMag, OffsetRate, OffsetTime);
    }
}

function RangedAttack(Actor A)
{
    if((AdvStalkerController(Controller).LastPounceTime + (12 - 1.5)) < Level.TimeSeconds && !AdvStalkerController(Controller).bFlanking && (Physics == PHYS_Walking) &&
        VSize(A.Location-Location)<=100 && !bDisableLeap && (bLeapIfSpotted && (Level.Game.GameDifficulty > 5.0 || bIgnoreDifficulty)))
    {
        SetAnimAction('DodgeF');
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
    if ( bZapped || bIsCrouched || bWantsToCrouch || bShotAnim || (Physics != PHYS_Walking) || bDisableLeap ||
         !bLeapIfSpotted || bLeapIfSpotted && (Level.Game.GameDifficulty <= 5.0 && !bIgnoreDifficulty))
        return false;

    if(!bCloaked)
        CloakStalker();
    Velocity = Normal(Controller.Target.Location-Location)*PounceSpeed;
    Velocity.Z = JumpZ * 1.75;
    SetPhysics(PHYS_Falling);
    SetCollision(true, false, false);
    SetAnimAction('HitReactionB');
    bPouncing=true;
    return true;
}

function PrepareToPounce()
{
    if ( bZapped || bIsCrouched || bWantsToCrouch || (Physics != PHYS_Walking))
        return;

    if(!bCloaked)
        CloakStalker();
    Velocity = Normal(Location-Controller.Target.Location)*PounceSpeed*0.7;
    Velocity.Z = JumpZ * 0.5;
    SetPhysics(PHYS_Falling);
    bPouncing=true;
}

function PreservativeDodge()
{
    if ( bZapped || bIsCrouched || bWantsToCrouch || (Physics != PHYS_Walking) || LastDodgeTime + 8 > Level.TimeSeconds
        || !bPreservativeDodge || bPreservativeDodge && (Level.Game.GameDifficulty < 5.0 && !bIgnoreDifficulty))
        return;

    if(!bCloaked)
        CloakStalker();
    LastDodgeTime = Level.TimeSeconds;
    Velocity = Normal(DodgeSpot)*PounceSpeed*JumpSpeedMultiplier;
    Velocity.Z = JumpZ * JumpHeightMultiplier;
    SetCollision(true, false, false);
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
    PlaySound(sound'KF_EnemiesFinalSnd.Stalker.Stalker_StepDefault', SLOT_None, FootstepVolume,,FootStepRadius);
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
    local AdvZombieStalker Stalker;
    local KFMonster Monster;
    local Nade Grenade;
    local float LeapCheckTime;
    Super(ZombieStalkerBase).Tick(DeltaTime);

    if (Controller != none && !IsInState('ZombieDying'))
    {

        foreach CollidingActors(class'Nade', Grenade, 150, Location)
        {
            JumpHeightMultiplier= 1.25;
            JumpSpeedMultiplier = 0.75;
            if (Controller == none || IsInState('ZombieDying') || IsInState('GettingOutOfTheWayOfShot'))
                break;
            else
            DodgeSpot = Grenade.Location - Location + Controller.Target.Location;
            PreservativeDodge();
        }

        foreach CollidingActors(class'KFMonster', Monster, 300, Location)
        {
            JumpHeightMultiplier = 0.5;
            JumpSpeedMultiplier = 1.5;
            DodgeSpot = Location - Monster.Location;
            if (Monster.bPlayedDeath && Monster != Self)
                PreservativeDodge();
        }

        foreach CollidingActors(class'AdvZombieStalker', Stalker, 300, Location)
        {
            if (Stalker != Self && !Stalker.bPlayedDeath)
            {
                bDisableLeap = true;
                LeapCheckTime = Level.TimeSeconds;
            }
        }

        if(Level.TimeSeconds > LeapCheckTime && bDisableLeap != false)
            bDisableLeap = false;
    }

    if( Level.NetMode==NM_DedicatedServer )
        Return; // Servers aren't intrested in this info.

    if(Level.TimeSeconds > NextFlickerTime && Health > 0 && bCloaked)
    {
        NextFlickerTime = Level.TimeSeconds + 3.0;
        if((Level.Game.GameDifficulty < 4.0 && !bIgnoreDifficulty) || StealthLevel == 0 && bIgnoreDifficulty)
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.15, true);
        else if((Level.Game.GameDifficulty <= 4.0 && !bIgnoreDifficulty) || StealthLevel == 1 && bIgnoreDifficulty)
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.10, true);
        else if((Level.Game.GameDifficulty <= 5.0 && !bIgnoreDifficulty) || StealthLevel == 2 && bIgnoreDifficulty)
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.10, true);
        else if((Level.Game.GameDifficulty > 5.0 && !bIgnoreDifficulty) || StealthLevel == 3 && bIgnoreDifficulty)
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.05, true);
    }
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
            else if ( !IsCloakSkin(Skins[0]) )
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
    if(AdvStalkerController(Controller).bFlanking && ZombieDamType[0]!=Class'DamTypeStalkerAPClaws' && bPiercingAttacks && (Level.Game.GameDifficulty > 5.0 || bIgnoreDifficulty))
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

simulated function bool IsCloakSkin(Material toCheck) {
    if (toCheck == Shader'KF_Specimens_Trip_T.stalker_invisible') return true;
    if (toCheck == ColorModifier'KFAdvZeds_T.Stalker_Hard') return true;
    if (toCheck == ColorModifier'KFAdvZeds_T.Stalker_Sui') return true;
    if (toCheck == ColorModifier'KFAdvZeds_T.Stalker_HOE') return true;

    return false;
}

simulated function Material GetCloakSkin() {
    if(default.StealthLevel == 0)
        return Shader'KF_Specimens_Trip_T.stalker_invisible';
    else if(default.StealthLevel == 1)
        return ColorModifier'KFAdvZeds_T.Stalker_Hard';
    else if(default.StealthLevel == 2)
        return ColorModifier'KFAdvZeds_T.Stalker_Sui';
    else if(default.StealthLevel == 3)
        return ColorModifier'KFAdvZeds_T.Stalker_HOE';
    return Shader'KF_Specimens_Trip_T.stalker_invisible';
}

simulated function float GetFootstepVolume() {
    if(default.StealthLevel == 0)
        return  1.0;
    else if(default.StealthLevel == 1)
        return  0.50;
    else if(default.StealthLevel == 2)
        return  0.25;
    else if(default.StealthLevel == 3)
        return  0.20;
    return 1.0;
}

simulated function float GetFootstepRadius(){
    if(default.StealthLevel == 0)
        return  40;
    else if(default.StealthLevel == 1)
        return  10;
    else if(default.StealthLevel == 2)
        return  6;
    else if(default.StealthLevel == 3)
        return  4;
    return 25;
}

// Cloak Functions ( called from animation notifies to save Gibby trouble ;) )

simulated function CloakStalker()
{
    // No cloaking if zapped
    if( bZapped )
    {
        return;
    }

    if ( bSpotted )
    {
        if( Level.NetMode == NM_DedicatedServer )
            return;

        Skins[0] = Finalblend'KFX.StalkerGlow';
        Skins[1] = Finalblend'KFX.StalkerGlow';
        bUnlit = true;
        return;
    }

    if ( !bDecapitated && !bCrispified ) // No head, no cloak, honey.  updated :  Being charred means no cloak either :D
    {
        Visibility = 1;
        bCloaked = true;

        if( Level.NetMode == NM_DedicatedServer )
            Return;

        Skins[0] = GetCloakSkin();
        Skins[1] = GetCloakSkin();
        FootStepVolume = GetFootstepVolume();
        FootStepRadius = GetFootstepRadius();

        // Invisible - no shadow
        if(PlayerShadow != none)
            PlayerShadow.bShadowActive = false;
        if(RealTimeShadow != none)
            RealTimeShadow.Destroy();

        // Remove/disallow projectors on invisible people
        Projectors.Remove(0, Projectors.Length);
        bAcceptsProjectors = false;

        if((Level.Game.GameDifficulty < 4.0 && !bIgnoreDifficulty) || StealthLevel == 0 && bIgnoreDifficulty)
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.25, true);
        else if((Level.Game.GameDifficulty <= 4.0 && !bIgnoreDifficulty) || StealthLevel == 1 && bIgnoreDifficulty)
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.15, true);
        else if((Level.Game.GameDifficulty <= 5.0 && !bIgnoreDifficulty) || StealthLevel == 2 && bIgnoreDifficulty)
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.08, true);
        else if((Level.Game.GameDifficulty > 5.0 && !bIgnoreDifficulty) || StealthLevel == 3 && bIgnoreDifficulty)
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.04, true);
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
        if( Level.NetMode!=NM_Client && !KFGameType(Level.Game).bDidStalkerInvisibleMessage && FRand()<0.25 && Controller.Enemy!=none &&
         PlayerController(Controller.Enemy.Controller)!=none )
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

            if((Level.Game.GameDifficulty < 4.0 && !bIgnoreDifficulty) || StealthLevel == 0 && bIgnoreDifficulty)
                SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.25, true);
            else if((Level.Game.GameDifficulty <= 4.0 && !bIgnoreDifficulty) || StealthLevel == 1 && bIgnoreDifficulty)
                SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.15, true);
            else if((Level.Game.GameDifficulty <= 5.0 && !bIgnoreDifficulty) || StealthLevel == 2 && bIgnoreDifficulty)
                SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.08, true);
            else if((Level.Game.GameDifficulty > 5.0 && !bIgnoreDifficulty) || StealthLevel == 3 && bIgnoreDifficulty)
                SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.04, true);
        }
    }
}

// Set the zed to the zapped behavior
simulated function SetZappedBehavior()
{
    super.SetZappedBehavior();

    bUnlit = false;

    // Handle setting the zed to uncloaked so the zapped overlay works properly
    Skins[1] = FinalBlend'KF_Specimens_Trip_T.stalker_fb';
    Skins[0] = Combiner'KF_Specimens_Trip_T.stalker_cmb';

    if (PlayerShadow != none)
        PlayerShadow.bShadowActive = true;

    bAcceptsProjectors = true;
    SetOverlayMaterial(Material'KFZED_FX_T.Energy.ZED_overlay_Hit_Shdr', 999, true);
}

function TakeDamage( int Damage, Pawn InstigatedBy, Vector Hitlocation, Vector Momentum, class<DamageType> damageType, optional int HitIndex)
{
    if(Damage < (HealthMax / 2.5))
        PreservativeDodge();
    Super.TakeDamage(Damage,instigatedBy,hitlocation,momentum,damageType,HitIndex);
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
    myLevel.AddPrecacheMaterial(Material'KFAdvZeds_T.Stalker_Hard');
    myLevel.AddPrecacheMaterial(Material'KFAdvZeds_T.Stalker_Sui');
    myLevel.AddPrecacheMaterial(Material'KFAdvZeds_T.Stalker_HOE');
}

defaultproperties
{
    //-------------------------------------------------------------------------------
    // NOTE: Most Default Properties are set in the base class to eliminate hitching
    //-------------------------------------------------------------------------------
    EventClasses(0)="KFAdvZeds.AdvZombieStalker_S"
    ControllerClass=Class'KFAdvZeds.AdvStalkerController'
}