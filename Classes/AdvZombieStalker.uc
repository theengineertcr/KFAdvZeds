/*
 * Modified Stalker - her combat and stealth capabilities depend on difficulty!
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
*/
class AdvZombieStalker extends KFMonster;

// Package loading
#exec OBJ LOAD FILE=KFAdvZeds_A.ukx
#exec OBJ LOAD FILE=KFAdvZeds_T.utx
#exec OBJ LOAD FILE=KFX.utx
#exec OBJ LOAD FILE=KF_BaseStalker.uax

var float NextCheckTime;
var float NextFlickerTime;
var KFHumanPawn LocalKFHumanPawn;
var float LastUncloakTime;

// Variables(Config)
var bool bDisorientingAttacks;                          // Shake the targets view, causing them to be disoriented. Config bool.
var bool bPiercingAttacks;                              // Pierce through the targets armour, dealing damage to their health. Config bool.
var bool bLeapIfSpotted;                                // Leap behind your target if they're facing towards you and you're close. Config bool.
var bool bPreservativeDodge;                            // Dodge away from danger to preserve your life(nearby zed dies, grenades, taking damage). Config bool.
var int StealthLevel;                                   // Stealth Level config. Affects both sounds and texture.
var bool bIgnoreDifficulty;                             // Ignores difficulty and checks users preferences.
var bool bDisableLeap;                                  // Used to temporarily disable the ability to leap if there are any nearby Stalkers.

// Variables
var vector DodgeSpot;                                   // What spot she's trying to dodge. Used to calculate to check whether she wants to dodge towards it, or away from it.
var float JumpHeightMultiplier, JumpSpeedMultiplier;    // Multipliers used to dynamically change the Jump Height/Speed depending on what she's trying to dodge.
var float LastDodgeTime;                                // Last time she used her presevative dodge.
var float FootStepRadius;
var bool bHasLeaped;

var() float PounceSpeed;
var bool bPouncing;

var() vector RotMag;
var() vector RotRate;
var() float RotTime;
var() vector OffsetMag;
var() vector OffsetRate;
var() float OffsetTime;


simulated function PostBeginPlay() {
    // Difficulty Scaling for her stealthiness
    if (Level.Game != none && !bDiffAdjusted) {
        Skins[0] = GetCloakSkin();
        Skins[1] = GetCloakSkin();
        FootStepVolume = GetFootstepVolume();
        FootStepRadius = GetFootstepRadius();

        if ((Level.Game.GameDifficulty < 4.0 && !bIgnoreDifficulty) || StealthLevel == 0 && bIgnoreDifficulty) {
            SoundRadius = 40;
            SoundVolume = 50;
            MoanVolume  = 1.0;
            GruntVolume = 1.0;
            TransientSoundRadius = 500;
            AmbientSoundScaling  = 6.8;
        } else if ((Level.Game.GameDifficulty <= 4.0 && !bIgnoreDifficulty) || StealthLevel == 1 && bIgnoreDifficulty) {
            SoundRadius = 20;
            SoundVolume = 25;
            MoanVolume  = 0.75;
            GruntVolume = 0.75;
            TransientSoundRadius = 250;
            AmbientSoundScaling  = 3.4;
        } else if ((Level.Game.GameDifficulty <= 5.0 && !bIgnoreDifficulty) || StealthLevel == 2 && bIgnoreDifficulty) {
            SoundRadius = 12;
            SoundVolume = 12;
            MoanVolume  = 0.375;
            GruntVolume = 0.375;
            TransientSoundRadius = 125;
            AmbientSoundScaling  = 1.7;
        } else if( (Level.Game.GameDifficulty > 5.0 && !bIgnoreDifficulty) || StealthLevel == 3 && bIgnoreDifficulty) {
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

function LandThump(){
}

function PlayChallengeSound() {
    if ((Level.Game.GameDifficulty <= 4.0 && !bIgnoreDifficulty) ||
        StealthLevel <= 1 && bIgnoreDifficulty) {
        PlaySound(ChallengeSound[Rand(4)], SLOT_Talk, GruntVolume);
    }
}

function ClawDamageTarget() {
    local vector PushDir;
    local KFHumanPawn HumanTarget;
    local KFPlayerController HumanTargetController;
    local float UsedMeleeDamage;

    super.ClawDamageTarget();

    if (MeleeDamageTarget(UsedMeleeDamage, PushDir)) {
        HumanTarget = KFHumanPawn(Controller.Target);

        if (HumanTarget != none) {
            HumanTargetController = KFPlayerController(HumanTarget.Controller);
        }

        // If were flanking our target, or were not exhausted from performing a leap attack, our strikes will disorient our foe's view.
        if (
            (HumanTargetController != none &&
            bDisorientingAttacks &&
            (Level.Game.GameDifficulty >= 4.0 || bIgnoreDifficulty) &&
            (AdvStalkerController(Controller).bFlanking || (AdvStalkerController(Controller).LastPounceTime + (12 - 1.5)) < Level.TimeSeconds))
        ) {
            HumanTargetController.ShakeView(RotMag, RotRate, RotTime, OffsetMag, OffsetRate, OffsetTime);
        }
    }
}

function RangedAttack(Actor A) {
    if (
        (AdvStalkerController(Controller).LastPounceTime + (12 - 1.5)) < Level.TimeSeconds &&
        !AdvStalkerController(Controller).bFlanking &&
        (Physics == PHYS_Walking) &&
        VSize(A.Location-Location)<=100 &&
        !bDisableLeap &&
        (bLeapIfSpotted && (Level.Game.GameDifficulty > 5.0 || bIgnoreDifficulty))
    ) {
        SetAnimAction('DodgeF');
        PrepareToPounce();
    } else if (bShotAnim || (Physics != PHYS_Walking)) {
        return;
    } else if (CanAttack(A)) {
        bShotAnim = true;
        SetAnimAction('Claw');
        Controller.bPreparingMove = true;
        Acceleration = vect(0, 0, 0);
        return;
    }
}

function bool DoPounce() {
    if (
        bZapped ||
        bIsCrouched ||
        bWantsToCrouch ||
        bShotAnim ||
        (Physics != PHYS_Walking) ||
        bDisableLeap ||
        !bLeapIfSpotted ||
        AnimAction == 'KnockDown' ||
        bDecapitated ||
        bLeapIfSpotted && (Level.Game.GameDifficulty <= 5.0 && !bIgnoreDifficulty)
    ) {
        return false;
    }

    if (!bCloaked) {
        CloakStalker();
    }
    Velocity = Normal(Controller.Target.Location - Location) * PounceSpeed;
    Velocity.Z = JumpZ * 1.75;
    SetPhysics(PHYS_Falling);
    SetCollision(true, false, false);
    SetAnimAction('HitReactionB');
    bPouncing = true;
    return true;
}

function PrepareToPounce() {
    if (bZapped || bIsCrouched || bWantsToCrouch || (Physics != PHYS_Walking) || AnimAction == 'KnockDown' || bDecapitated) {
        return;
    }

    if (!bCloaked) {
        CloakStalker();
    }
    Velocity = Normal(Location - Controller.Target.Location) * PounceSpeed * 0.7;
    Velocity.Z = JumpZ * 0.5;
    SetPhysics(PHYS_Falling);
    bPouncing = true;
}

function PreservativeDodge() {
    if (
        bZapped ||
        AnimAction == 'KnockDown' ||
        bIsCrouched ||
        bWantsToCrouch ||
        bDecapitated ||
        (Physics != PHYS_Walking) ||
        LastDodgeTime + 8 > Level.TimeSeconds ||
        !bPreservativeDodge ||
        bPreservativeDodge && (Level.Game.GameDifficulty < 4.0 && !bIgnoreDifficulty)
    ) {
        return;
    }

    if (!bCloaked) {
        CloakStalker();
    }
    LastDodgeTime = Level.TimeSeconds;
    Velocity = Normal(DodgeSpot) * PounceSpeed * JumpSpeedMultiplier;
    Velocity.Z = JumpZ * JumpHeightMultiplier;
    SetCollision(true, false, false);
    SetPhysics(PHYS_Falling);
    bPouncing = true;
}

event Landed(vector HitNormal) {
    bPouncing = false;
    SetCollision(true, true, true);
    super.Landed(HitNormal);
}

simulated function BeginPlay() {
    // Link the mesh to our custom animations
    LinkSkelAnim(MeshAnimation'AdvStalker_Anim');
    super.BeginPlay();
}

// Footsteps are linked to Anim-notifies
simulated function StalkerFootstep() {
    PlaySound(sound'KF_EnemiesFinalSnd.Stalker.Stalker_Stepdefault', SLOT_none, FootstepVolume,, FootStepRadius);
}

simulated function PostNetBeginPlay() {
    local PlayerController PC;

    super.PostNetBeginPlay();

    if (Level.NetMode != NM_DedicatedServer) {
        PC = Level.GetLocalPlayerController();
        if (PC != none && PC.Pawn != none) {
            LocalKFHumanPawn = KFHumanPawn(PC.Pawn);
        }
    }
}

simulated event SetAnimAction(name NewAction) {
    if (
        NewAction == 'Claw' ||
        NewAction == MeleeAnims[0] ||
        NewAction == MeleeAnims[1] ||
        NewAction == MeleeAnims[2]
    ) {
        UncloakStalker();
    }

    super.SetAnimAction(NewAction);
}

simulated function Tick(float DeltaTime) {
    local AdvZombieStalker Stalker;
    local KFMonster Monster;
    local Nade Grenade;
    local float LeapCheckTime;

    if (Controller != none && !IsInState('ZombieDying')) {

        // There's a grenade, get out of there!
        foreach CollidingActors(class'Nade', Grenade, 150, Location) {
            JumpHeightMultiplier = 1.25;
            JumpSpeedMultiplier = 1.0;
            if (Controller == none || IsInState('ZombieDying') || IsInState('GettingOutOfTheWayOfShot')) {
                break;
            } else {
                DodgeSpot = Grenade.Location - Location + Controller.Target.Location;
            }
            PreservativeDodge();
        }

        // If something right next to us dies, we know were in a dangerous position
        // And need to get away quick! Can only be done once.
        if (bHasLeaped == false) {
            foreach CollidingActors(class'KFMonster', Monster, 300, Location) {
                JumpHeightMultiplier = 0.5;
                JumpSpeedMultiplier = 1.5;
                DodgeSpot = Location - Monster.Location;
                // Can't dodge while attacking anymore!
                if (Monster.bPlayedDeath && Monster != Self && !bShotAnim) {
                    PreservativeDodge();
                    bHasLeaped = true;
                }
            }
        }

        // Don't leap if there are other Stalkers next to us and they're alive
        foreach CollidingActors(class'AdvZombieStalker', Stalker, 300, Location) {
            if (Stalker != Self && !Stalker.bPlayedDeath) {
                bDisableLeap = true;
                LeapCheckTime = Level.TimeSeconds;
            }
        }

        if (Level.TimeSeconds > LeapCheckTime && bDisableLeap != false) {
            bDisableLeap = false;
        }

        // If were behind our target, our attacks pierce through their armour and deal double damage
        if (
            AdvStalkerController(Controller).bFlanking &&
            ZombieDamType[0] != class'DamTypeStalkerAPClaws' &&
            bPiercingAttacks &&
            (Level.Game.GameDifficulty > 5.0 || bIgnoreDifficulty)
        ) {
            ZombieDamType[0] = class'DamTypeStalkerAPClaws';
            ZombieDamType[1] = class'DamTypeStalkerAPClaws';
            ZombieDamType[2] = class'DamTypeStalkerAPClaws';
            MeleeDamage = Max(DifficultyDamageModifer() * default.MeleeDamage * 2, 1);
        } else if (
            !AdvStalkerController(Controller).bFlanking &&
            ZombieDamType[0] != class'DamTypeSlashingAttack'
        ) {
            ZombieDamType[0] = class'DamTypeSlashingAttack';
            ZombieDamType[1] = class'DamTypeSlashingAttack';
            ZombieDamType[2] = class'DamTypeSlashingAttack';
            MeleeDamage = Max(DifficultyDamageModifer() * default.MeleeDamage, 1);
        }
    }

    // Servers aren't intrested in this info.
    if (Level.NetMode == NM_DedicatedServer) {
        return;
    }

    if (Level.TimeSeconds > NextFlickerTime && Health > 0 && bCloaked) {
        NextFlickerTime = Level.TimeSeconds + 3.0;

        if ((Level.Game.GameDifficulty < 4.0 && !bIgnoreDifficulty) || StealthLevel == 0 && bIgnoreDifficulty) {
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.15, true);
        } else if ((Level.Game.GameDifficulty <= 4.0 && !bIgnoreDifficulty) || StealthLevel == 1 && bIgnoreDifficulty) {
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.10, true);
        } else if ((Level.Game.GameDifficulty <= 5.0 && !bIgnoreDifficulty) || StealthLevel == 2 && bIgnoreDifficulty) {
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.10, true);
        } else if ((Level.Game.GameDifficulty > 5.0 && !bIgnoreDifficulty) || StealthLevel == 3 && bIgnoreDifficulty) {
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.05, true);
        }
    }

    if (bZapped) {
        // Make sure we check if we need to be cloaked as soon as the zap wears off
        NextCheckTime = Level.TimeSeconds;
    } else if (Level.TimeSeconds > NextCheckTime && Health > 0) {
        NextCheckTime = Level.TimeSeconds + 0.5;

        if (
            LocalKFHumanPawn != none &&
            LocalKFHumanPawn.Health > 0 &&
            LocalKFHumanPawn.ShowStalkers() &&
            // 640000 = 800 Units
            VSizeSquared(Location - LocalKFHumanPawn.Location) < LocalKFHumanPawn.GetStalkerViewDistanceMulti() * 640000.0
        ) {
            bSpotted = true;
        } else {
            bSpotted = false;
        }

        if (!bSpotted && !bCloaked && Skins[0] != Combiner'KF_Specimens_Trip_T.stalker_cmb') {
            UncloakStalker();
        } else if (Level.TimeSeconds - LastUncloakTime > 1.2) {
            // if we're uberbrite, turn down the light
            if (bSpotted && Skins[0] != Finalblend'KFX.StalkerGlow') {
                bUnlit = false;
                CloakStalker();
            } else if (!IsCloakSkin(Skins[0])) {
                CloakStalker();
            }
        }

        if (bCloaked) {
            if (PlayerShadow != none) {
                PlayerShadow.bShadowActive = false;
            }
            if (RealTimeShadow != none) {
                RealTimeShadow.Destroy();
            }
        }
    }
}

simulated function bool IsCloakSkin(Material toCheck) {
    if (
        toCheck == Shader'KF_Specimens_Trip_T.stalker_invisible' ||
        toCheck == ColorModifier'KFAdvZeds_T.Stalker_Hard' ||
        toCheck == ColorModifier'KFAdvZeds_T.Stalker_Sui' ||
        toCheck == ColorModifier'KFAdvZeds_T.Stalker_HOE'
    ) {
        return true;
    }

    return false;
}

simulated function Material GetCloakSkin() {
    if (default.StealthLevel == 0) {
        return Shader'KF_Specimens_Trip_T.stalker_invisible';
    } else if (default.StealthLevel == 1) {
        return ColorModifier'KFAdvZeds_T.Stalker_Hard';
    } else if (default.StealthLevel == 2) {
        return ColorModifier'KFAdvZeds_T.Stalker_Sui';
    } else if (default.StealthLevel == 3) {
        return ColorModifier'KFAdvZeds_T.Stalker_HOE';
    }

    return Shader'KF_Specimens_Trip_T.stalker_invisible';
}

simulated function float GetFootstepVolume() {
    if (default.StealthLevel == 0) {
        return  1.0;
    } else if (default.StealthLevel == 1) {
        return  0.50;
    } else if (default.StealthLevel == 2) {
        return  0.25;
    } else if (default.StealthLevel == 3) {
        return  0.20;
    }

    return 1.0;
}

simulated function float GetFootstepRadius() {
    if (default.StealthLevel == 0) {
        return 40;
    } else if (default.StealthLevel == 1) {
        return 10;
    } else if (default.StealthLevel == 2) {
        return  6;
    } else if (default.StealthLevel == 3) {
        return 4;
    }

    return 25;
}

// Cloak Functions (called from animation notifies to save Gibby trouble ;) )
simulated function CloakStalker() {
    // No cloaking if zapped
    if (bZapped) {
        return;
    }

    if (bSpotted) {
        if (Level.NetMode == NM_DedicatedServer) {
            return;
        }

        Skins[0] = Finalblend'KFX.StalkerGlow';
        Skins[1] = Finalblend'KFX.StalkerGlow';
        bUnlit = true;
        return;
    }
    // No head, no cloak, honey.  updated :  Being charred means no cloak either :D
    if (!bDecapitated && !bCrispified) {
        Visibility = 1;
        bCloaked = true;

        if (Level.NetMode == NM_DedicatedServer) {
            return;
        }

        Skins[0] = GetCloakSkin();
        Skins[1] = GetCloakSkin();
        FootStepVolume = GetFootstepVolume();
        FootStepRadius = GetFootstepRadius();

        // Invisible - no shadow
        if (PlayerShadow != none) {
            PlayerShadow.bShadowActive = false;
        }
        if (RealTimeShadow != none) {
            RealTimeShadow.Destroy();
        }

        // Remove/disallow projectors on invisible people
        Projectors.Remove(0, Projectors.Length);
        bAcceptsProjectors = false;

        if ((Level.Game.GameDifficulty < 4.0 && !bIgnoreDifficulty) || StealthLevel == 0 && bIgnoreDifficulty) {
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.25, true);
        } else if ((Level.Game.GameDifficulty <= 4.0 && !bIgnoreDifficulty) || StealthLevel == 1 && bIgnoreDifficulty) {
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.15, true);
        } else if ((Level.Game.GameDifficulty <= 5.0 && !bIgnoreDifficulty) || StealthLevel == 2 && bIgnoreDifficulty) {
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.08, true);
        } else if ((Level.Game.GameDifficulty > 5.0 && !bIgnoreDifficulty) || StealthLevel == 3 && bIgnoreDifficulty) {
            SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.04, true);
        }
    }
}

simulated function UnCloakStalker() {
    if (bZapped) {
        return;
    }

    if (!bCrispified) {
        LastUncloakTime = Level.TimeSeconds;

        Visibility = default.Visibility;
        bCloaked = false;
        bUnlit = false;

        // 25% chance of our Enemy saying something about us being invisible
        if (
            Level.NetMode != NM_Client &&
            !KFGameType(Level.Game).bDidStalkerInvisibleMessage &&
            FRand()<0.25 && Controller.Enemy != none &&
            PlayerController(Controller.Enemy.Controller) != none
        ) {
            PlayerController(Controller.Enemy.Controller).Speech('AUTO', 17, "");
            KFGameType(Level.Game).bDidStalkerInvisibleMessage = true;
        }
        if (Level.NetMode == NM_DedicatedServer) {
            return;
        }

        if (Skins[0] != Combiner'KF_Specimens_Trip_T.stalker_cmb') {
            Skins[1] = FinalBlend'KF_Specimens_Trip_T.stalker_fb';
            Skins[0] = Combiner'KF_Specimens_Trip_T.stalker_cmb';

            if (PlayerShadow != none) {
                PlayerShadow.bShadowActive = true;
            }
            bAcceptsProjectors = true;

            if ((Level.Game.GameDifficulty < 4.0 && !bIgnoreDifficulty) || StealthLevel == 0 && bIgnoreDifficulty) {
                SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.25, true);
            } else if ((Level.Game.GameDifficulty <= 4.0 && !bIgnoreDifficulty) || StealthLevel == 1 && bIgnoreDifficulty) {
                SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.15, true);
            } else if ((Level.Game.GameDifficulty <= 5.0 && !bIgnoreDifficulty) || StealthLevel == 2 && bIgnoreDifficulty) {
                SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.08, true);
            } else if((Level.Game.GameDifficulty > 5.0 && !bIgnoreDifficulty) || StealthLevel == 3 && bIgnoreDifficulty) {
                SetOverlayMaterial(Material'KFX.FBDecloakShader', 0.04, true);
            }
        }
    }
}

// Set the zed to the zapped behavior
simulated function SetZappedBehavior() {
    super.SetZappedBehavior();

    bUnlit = false;

    // Handle setting the zed to uncloaked so the zapped overlay works properly
    Skins[1] = FinalBlend'KF_Specimens_Trip_T.stalker_fb';
    Skins[0] = Combiner'KF_Specimens_Trip_T.stalker_cmb';

    if (PlayerShadow != none) {
        PlayerShadow.bShadowActive = true;
    }

    bAcceptsProjectors = true;
    SetOverlayMaterial(Material'KFZED_FX_T.Energy.ZED_overlay_Hit_Shdr', 999, true);
}

function TakeDamage(
    int Damage,
    Pawn InstigatedBy,
    Vector Hitlocation,
    Vector Momentum,
    class<DamageType> damageType,
    optional int HitIndex
) {
    // We took damage, dodge! - HoE+ Exclusive
    if (Damage < (HealthMax / 2.5) && (Level.Game.GameDifficulty > 4.0 && !bIgnoreDifficulty) && (AdvStalkerController(Controller).LastPounceTime + (12 - 1.5)) < Level.TimeSeconds) {
        DoPounce();
        AdvStalkerController(Controller).LastPounceTime = Level.TimeSeconds;
    }

    // Were in mid-air, take half damage! - HoE+ Exclusive
    if (Physics == PHYS_Falling && (Level.Game.GameDifficulty > 4.0 && !bIgnoreDifficulty)) {
        Damage *= 0.5;
    }

    super.TakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType, HitIndex);
}

function PlayHit(
    float Damage,
    Pawn InstigatedBy,
    vector HitLocation,
    class<DamageType> damageType,
    vector Momentum,
    optional int HitIdx
) {
    local Vector HitNormal;
    local Vector HitRay ;
    local Name HitBone;
    local float HitBoneDist;
    local PlayerController PC;
    local bool bShowEffects, bRecentHit;
    local ProjectileBloodSplat BloodHit;
    local rotator SplatRot;

    bRecentHit = Level.TimeSeconds - LastPainTime < 0.2;
    LastDamageAmount = Damage;

    // Call the modified version of the original Pawn playhit
    OldPlayHit(Damage, InstigatedBy, HitLocation, DamageType, Momentum);

    if (Damage <= 0) {
        return;
    }

    // If stunned while in mid-air, just instantly die as a reward for accurate shooters
    if (Health > 0 && Damage > (float(default.Health) / 1.5)) {
        if (Physics == PHYS_Falling) {
            KilledBy(LastDamagedBy);
        } else {
            FlipOver();
        }
    }

    PC = PlayerController(Controller);
    bShowEffects = (Level.NetMode != NM_Standalone) ||
        (Level.TimeSeconds - LastRenderTime < 2.5) ||
        ((InstigatedBy != none) && (PlayerController(InstigatedBy.Controller) != none)) ||
        (PC != none);

    if (!bShowEffects) {
        return;
    }

    if (BurnDown > 0 && !bBurnified) {
        bBurnified = true;
    }

    HitRay = vect(0, 0, 0);
    if (InstigatedBy != none) {
        HitRay = Normal(HitLocation - (InstigatedBy.Location + (vect(0, 0, 1) * InstigatedBy.EyeHeight)));
    }

    if (DamageType.default.bLocationalHit) {
        CalcHitLoc(HitLocation, HitRay, HitBone, HitBoneDist);

        // Do a zapped effect is someone shoots us and we're zapped to help show that the zed is taking more damage
        if (bZapped && DamageType.name != 'DamTypeZEDGun') {
            PlaySound(class'ZedGunProjectile'.default.ExplosionSound,, class'ZedGunProjectile'.default.ExplosionSoundVolume);
            Spawn(class'ZedGunProjectile'.default.ExplosionEmitter,,, HitLocation + HitNormal * 20, rotator(HitNormal));
        }
    } else {
        HitLocation = Location;
        HitBone = FireRootBone;
        HitBoneDist = 0.0f;
    }

    if (DamageType.default.bAlwaysSevers && DamageType.default.bSpecial) {
        HitBone = 'head';
    }

    if (InstigatedBy != none) {
        HitNormal = Normal(Normal(InstigatedBy.Location - HitLocation) + VRand() * 0.2 + vect(0, 0, 2.8));
    } else {
        HitNormal = Normal(Vect(0, 0, 1) + VRand() * 0.2 + vect(0, 0, 2.8));
    }
    // log("HitLocation "$Hitlocation);

    if (DamageType.default.bCausesBlood && (!bRecentHit || (bRecentHit && (FRand() > 0.8)))) {
        if (!class'GameInfo'.static.NoBlood() && !class'GameInfo'.static.UseLowGore()) {
            if (Momentum != vect(0, 0, 0)) {
                SplatRot = rotator(Normal(Momentum));
            } else {
                if (InstigatedBy != none) {
                    SplatRot = rotator(Normal(Location - InstigatedBy.Location));
                } else {
                    SplatRot = rotator(Normal(Location - HitLocation));
                }
            }

            BloodHit = Spawn(ProjectileBloodSplatClass, InstigatedBy,, HitLocation, SplatRot);
        }
    }

    if (
        InstigatedBy != none &&
        InstigatedBy.PlayerReplicationInfo != none &&
        KFSteamStatsAndAchievements(InstigatedBy.PlayerReplicationInfo.SteamStatsAndAchievements) != none &&
        Health <= 0 &&
        Damage > DamageType.default.HumanObliterationThreshhold &&
        Damage != 1000 &&
        (!bDecapitated || bPlayBrainSplash)
    ) {
        KFSteamStatsAndAchievements(InstigatedBy.PlayerReplicationInfo.SteamStatsAndAchievements).AddGibKill(class<DamTypeM79Grenade>(damageType) != none);

        if (self.IsA('ZombieFleshPound')) {
            KFSteamStatsAndAchievements(InstigatedBy.PlayerReplicationInfo.SteamStatsAndAchievements).AddFleshpoundGibKill();
        }
    }

    DoDamageFX(HitBone, Damage, DamageType, Rotator(HitNormal));
    // additional check in case shield absorbed
    if (DamageType.default.DamageOverlayMaterial != none && Damage > 0) {
        SetOverlayMaterial(DamageType.default.DamageOverlayMaterial, DamageType.default.DamageOverlayTime, false);
    }
}

// Overridden because we need to handle the overlays differently for zombies that can cloak
function SetZapped(float ZapAmount, Pawn Instigator) {
    LastZapTime = Level.TimeSeconds;

    if (bZapped) {
        TotalZap = ZapThreshold;
        RemainingZap = ZapDuration;
    } else {
        TotalZap += ZapAmount;

        if (TotalZap >= ZapThreshold) {
            RemainingZap = ZapDuration;
            bZapped = true;
        }
    }
    ZappedBy = Instigator;
}

function RemoveHead() {
    super.RemoveHead();

    if (!bCrispified) {
        Skins[1] = FinalBlend'KF_Specimens_Trip_T.stalker_fb';
        Skins[0] = Combiner'KF_Specimens_Trip_T.stalker_cmb';
    }
}

simulated function PlayDying(class<DamageType> DamageType, vector HitLoc) {
    super.PlayDying(DamageType,HitLoc);

    if (bUnlit) {
        bUnlit =! bUnlit;
    }

    LocalKFHumanPawn = none;

    if (!bCrispified) {
        Skins[1] = FinalBlend'KF_Specimens_Trip_T.stalker_fb';
        Skins[0] = Combiner'KF_Specimens_Trip_T.stalker_cmb';
    }
}

// Give her the ability to spring.
function bool DoJump(bool bUpdating) {
    if (
        !bIsCrouched &&
        !bWantsToCrouch &&
        ((Physics == PHYS_Walking) || (Physics == PHYS_Ladder) || (Physics == PHYS_Spider))
    ) {
        if (Role == ROLE_Authority) {
            if (Level.Game != none && Level.Game.GameDifficulty > 2) {
                MakeNoise(0.1 * Level.Game.GameDifficulty);
            }
            if (bCountJumps && Inventory != none) {
                Inventory.OwnerEvent('Jumped');
            }
        }

        if (Physics == PHYS_Spider) {
            Velocity = JumpZ * Floor;
        } else if (Physics == PHYS_Ladder) {
            Velocity.Z = 0;
        } else if (bIsWalking) {
            Velocity.Z = default.JumpZ;
            Velocity.X = default.JumpZ * 0.6;
        } else {
            Velocity.Z = JumpZ;
            Velocity.X = JumpZ * 0.6;
        }

        if (Base != none && !Base.bWorldGeometry) {
            Velocity.Z += Base.Velocity.Z;
            Velocity.X += Base.Velocity.X;
        }
        SetPhysics(PHYS_Falling);
        return true;
    }
    return false;
}

static simulated function PreCacheMaterials(LevelInfo myLevel) {
    //should be derived and used.
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

defaultproperties {
    ControllerClass=class'KFAdvZeds.AdvStalkerController'
    DetachedArmClass=class'SeveredArmStalker'
    DetachedLegClass=class'SeveredLegStalker'
    DetachedHeadClass=class'SeveredHeadStalker'

    Mesh=SkeletalMesh'KF_Freaks_Trip.Stalker_Freak'
    Skins(0)=Shader'KF_Specimens_Trip_T.stalker_invisible'  // Combiner'KF_Specimens_Trip_T.stalker_cmb'//Shader 'KFCharacters.StalkerHairShader'
    Skins(1)=Shader'KF_Specimens_Trip_T.stalker_invisible'  // Shader'KFCharacters.CloakShader';

    AmbientSound=Sound'KF_BaseStalker.Stalker_IdleLoop'
    MoanVoice=Sound'KF_EnemiesFinalSnd.Stalker_Talk'
    JumpSound=Sound'KF_EnemiesFinalSnd.Stalker_Jump'
    MeleeAttackHitSound=sound'KF_EnemiesFinalSnd.Stalker_HitPlayer'

    HitSound(0)=Sound'KF_EnemiesFinalSnd.Stalker_Pain'
    DeathSound(0)=Sound'KF_EnemiesFinalSnd.Stalker_Death'

    ChallengeSound(0)=Sound'KF_EnemiesFinalSnd.Stalker_Challenge'
    ChallengeSound(1)=Sound'KF_EnemiesFinalSnd.Stalker_Challenge'
    ChallengeSound(2)=Sound'KF_EnemiesFinalSnd.Stalker_Challenge'
    ChallengeSound(3)=Sound'KF_EnemiesFinalSnd.Stalker_Challenge'
    bIgnoreDifficulty=false
    StealthLevel=0
    DrawScale=1.1
    Prepivot=(Z=5.0)
    PounceSpeed=330.000000
    SoundRadius=80.0
    SoundVolume=50
    AmbientSoundScaling=6.83
    TransientSoundVolume=1.000000
    GruntVolume=1.500000
    MoanVolume=1.500000
    FootstepVolume=1.000000
    FootStepRadius=60
    TransientSoundRadius=500.000000

    MeleeAnims(0)="StalkerSpinAttack"
    MeleeAnims(1)="StalkerAttack1"
    MeleeAnims(2)="JumpAttack"
    MeleeDamage=9
    damageForce=5000
    ZombieDamType(0)=class'KFMod.DamTypeSlashingAttack'
    ZombieDamType(1)=class'KFMod.DamTypeSlashingAttack'
    ZombieDamType(2)=class'KFMod.DamTypeSlashingAttack'

    RotMag=(X=5000.000000,Y=2500.000000,Z=2500.000000)
    RotRate=(X=-40000.000000,Y=15000.000000,Z=15000.000000)
    RotTime=5.000000
    OffsetMag=(X=10.000000,Y=20.000000,Z=50.000000)
    OffsetRate=(X=600.000000,Y=600.000000,Z=-600.000000)
    OffsetTime=3.500000

    ScoringValue=15
    SoundGroupClass=class'KFMod.KFFemaleZombieSounds'
    IdleHeavyAnim="StalkerIdle"
    IdleRifleAnim="StalkerIdle"
    GroundSpeed=200.000000
    WaterSpeed=180.000000
    JumpZ=350.000000
    Health=100 // 120
    HealthMax=100 // 120
    MovementAnims(0)="ZombieRun"
    MovementAnims(1)="ZombieRun"
    MovementAnims(2)="ZombieRun"
    MovementAnims(3)="ZombieRun"
    WalkAnims(0)="ZombieRun"
    WalkAnims(1)="ZombieRun"
    WalkAnims(2)="ZombieRun"
    WalkAnims(3)="ZombieRun"
    IdleCrouchAnim="StalkerIdle"
    IdleWeaponAnim="StalkerIdle"
    IdleRestAnim="StalkerIdle"

    AmbientGlow=0
    CollisionRadius=26.000000
    RotationRate=(Yaw=45000,Roll=0)

    PuntAnim="ClotPunt"

    bCannibal=false
    MenuName="Stalker"
    KFRagdollName="Stalker_Trip"

    SeveredHeadAttachScale=1.0
    SeveredLegAttachScale=0.7
    SeveredArmAttachScale=0.8

    MeleeRange=35.000000
    HeadHeight=2.5
    HeadScale=1.1
    CrispUpThreshhold=10
    OnlineHeadshotOffset=(X=18,Y=0,Z=33)
    OnlineHeadshotScale=1.2
    MotionDetectorThreat=0.25
}