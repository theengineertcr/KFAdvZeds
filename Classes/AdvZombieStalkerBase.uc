/*
 * Modified Stalker Base class. Holds a majority of the variables.
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
*/
class AdvZombieStalkerBase extends KFMonster
    abstract;

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

//-------------------------------------------------------------------------------
// NOTE: All Code resides in the child class(this class was only created to
//         eliminate hitching caused by loading default properties during play)
//-------------------------------------------------------------------------------

var() float PounceSpeed;
var bool bPouncing;

var() vector RotMag;
var() vector RotRate;
var() float RotTime;
var() vector OffsetMag;
var() vector OffsetRate;
var() float OffsetTime;

function bool DoPounce() {
    if (bZapped || bIsCrouched || bWantsToCrouch || bShotAnim || Physics != PHYS_Walking) {
        return false;
    }

    Velocity = Normal(Controller.Target.Location - Location) * PounceSpeed;
    Velocity.Z = JumpZ * 1.75;
    SetPhysics(PHYS_Falling);
    SetCollision(false, false, false);
    bPouncing = true;

    return true;
}

function PrepareToPounce() {
    Velocity = Normal(Location - Controller.Target.Location) * PounceSpeed * 0.7;
    Velocity.Z = JumpZ * 0.5;
    SetPhysics(PHYS_Falling);
    bPouncing = true;
}

event Landed(vector HitNormal) {
    bPouncing = false;
    SetCollision(true, true, true);
    super.Landed(HitNormal);
}

defaultproperties {
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