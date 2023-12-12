/*
 * Modified Clot
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
 */
class AdvZombieClot extends KFMonster;

// todo: clot base health to 400, head health to 95,
// new "brain shot" hitzone above main head that has 25 hp,
// no head = instantly dead

var bool bEnableDismemberment;          // Clots can lose their limbs.
var bool bDisableIncreasedDurability;   // Clots use default health
var int  GrabLevel;                     // How effective their grabbing is. 0 = default || 1 = Player cannot reload || 2 = Player cannot Swap weapons(disabled in solo) || 3 = player can't shoot for a second if grabbed from front, and cannot turn if grabbed from behind(if alone/berserker, lasts for only a second)
var Rotator PlayerRot;
var KFPawn KFP;

var     KFPawn  DisabledPawn;           // The pawn that has been disabled by this zombie's grapple
var     bool    bGrappling;             // This zombie is grappling someone
var     float   GrappleEndTime;         // When the current grapple should be over
var()   float   GrappleDuration;        // How long a grapple by this zombie should last

var	float	ClotGrabMessageDelay;	// Amount of time between a player saying "I've been grabbed" message

replication{
    reliable if(bNetDirty && Role == ROLE_Authority)
        bGrappling;
}

function BreakGrapple(){
    if( DisabledPawn != none ){
         DisabledPawn.bMovementDisabled = false;
         DisabledPawn = none;
    }
}

function ClawDamageTarget(){
    local vector PushDir;
    local float UsedMeleeDamage;


    if( MeleeDamage > 1 ){
       UsedMeleeDamage = (MeleeDamage - (MeleeDamage * 0.05)) + (MeleeDamage * (FRand() * 0.1));
    } else {
       UsedMeleeDamage = MeleeDamage;
    }

    // If zombie has latched onto us...
    if ( MeleeDamageTarget( UsedMeleeDamage, PushDir)) {
        KFP = KFPawn(Controller.Target);

        PlaySound(MeleeAttackHitSound, SLOT_Interact, 2.0);
        
        if(PlayerRot != KFP.Rotation){
            PlayerRot=KFP.Rotation;
        }

        if( !bDecapitated && KFP != none ) {
            if ( KFPlayerReplicationInfo(KFP.PlayerReplicationInfo) == none ||
                KFP.GetVeteran().static.CanBeGrabbed(KFPlayerReplicationInfo(KFP.PlayerReplicationInfo), self)) {
                if( DisabledPawn != none ) {
                     DisabledPawn.bMovementDisabled = false;
                }
                KFP.DisableMovement(GrappleDuration);
                DisabledPawn = KFP;
            }
        }
    }
}

function RangedAttack(Actor A) {
    if ( bShotAnim || Physics == PHYS_Swimming){
        return;
    } else if ( CanAttack(A) ) {
        bShotAnim = true;
        SetAnimAction('Claw');
        return;
    }
}

simulated event SetAnimAction(name NewAction) {
    local int meleeAnimIndex;

    if( NewAction=='' ){
        Return;
    }
        
    if(NewAction == 'Claw') {
        meleeAnimIndex = Rand(3);
        NewAction = meleeAnims[meleeAnimIndex];
        CurrentDamtype = ZombieDamType[meleeAnimIndex];
    } else if( NewAction == 'DoorBash' ) {
       CurrentDamtype = ZombieDamType[Rand(3)];
    }
    ExpectingChannel = DoAnimAction(NewAction);

    if( AnimNeedsWait(NewAction) ) {
        bWaitForAnim = true;
    }

    if( Level.NetMode!=NM_Client ) {
        AnimAction = NewAction;
        bResetAnimAct = True;
        ResetAnimActTime = Level.TimeSeconds+0.3;
    }
}

simulated function bool AnimNeedsWait(name TestAnim) {
    if( TestAnim == 'KnockDown' || TestAnim == 'DoorBash' ) {
        return true;
    }
    return false;
}

simulated function int DoAnimAction( name AnimName ) {
    if( AnimName=='ClotGrapple' || AnimName=='ClotGrappleTwo' || AnimName=='ClotGrappleThree' ) {
        AnimBlendParams(1, 1.0, 0.1,, FireRootBone);
        PlayAnim(AnimName,, 0.1, 1);

        // Randomly send out a message about Clot grabbing you(10% chance)
        if ( FRand() < 0.10 && LookTarget != none && KFPlayerController(LookTarget.Controller) != none &&
            VSizeSquared(Location - LookTarget.Location) < 2500 &&
            Level.TimeSeconds - KFPlayerController(LookTarget.Controller).LastClotGrabMessageTime > ClotGrabMessageDelay &&
            KFPlayerController(LookTarget.Controller).SelectedVeterancy != class'KFVetBerserker' ) {
            PlayerController(LookTarget.Controller).Speech('AUTO', 11, "");
            KFPlayerController(LookTarget.Controller).LastClotGrabMessageTime = Level.TimeSeconds;
        }
        bGrappling = true;
        GrappleEndTime = Level.TimeSeconds + GrappleDuration;
        return 1;
    }
    return super.DoAnimAction( AnimName );
}

simulated function Tick(float DeltaTime) {
    super.Tick(DeltaTime);
    if( bShotAnim && Role == ROLE_Authority ) {
        if( LookTarget!=None ) {
            Acceleration = AccelRate * Normal(LookTarget.Location - Location);
        }
    }

    // This doesn't work because I don't know how to replicate it online
    if(bGrappling && !bPlayedDeath && !bDecapitated){
        if(KFP == none){
            KFP = KFPawn(Controller.Target);
        }
        if (KFP != none && KFP.Controller != none && KFP.Rotation != PlayerRot){
            KFP.SetViewRotation(PlayerRot);
        }
    }

    if( Role == ROLE_Authority && bGrappling ) {
        if( Level.TimeSeconds > GrappleEndTime ) {
            bGrappling = false;
        }
    }

    // if we move out of melee range, stop doing the grapple animation
    if( bGrappling && LookTarget != none ) {
        if( VSize(LookTarget.Location - Location) > MeleeRange + CollisionRadius + LookTarget.CollisionRadius ) {
            bGrappling = false;
            AnimEnd(1);
        }
    }
}

function RemoveHead() {
    Super.RemoveHead();
    MeleeAnims[0] = 'Claw';
    MeleeAnims[1] = 'Claw';
    MeleeAnims[2] = 'Claw2';

    MeleeDamage *= 2;
    MeleeRange *= 2;

    if( DisabledPawn != none ) {
         DisabledPawn.bMovementDisabled = false;
         DisabledPawn = none;
    }
}

function Died(Controller Killer, class<DamageType> damageType, vector HitLocation) {
    if( DisabledPawn != none ) {
         DisabledPawn.bMovementDisabled = false;
         DisabledPawn = none;
    }
    super.Died(Killer, damageType, HitLocation);
}

simulated function Destroyed() {
    super.Destroyed();

    if( DisabledPawn != none ) {
         DisabledPawn.bMovementDisabled = false;
         DisabledPawn = none;
    }
}

static simulated function PreCacheStaticMeshes(LevelInfo myLevel) {
    Super.PreCacheStaticMeshes(myLevel);
}

static simulated function PreCacheMaterials(LevelInfo myLevel) {
    myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T.clot_cmb');
    myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T.clot_env_cmb');
    myLevel.AddPrecacheMaterial(Texture'KF_Specimens_Trip_T.clot_diffuse');
    myLevel.AddPrecacheMaterial(Texture'KF_Specimens_Trip_T.clot_spec');
}

defaultproperties {
    DetachedArmClass="SeveredArmClot"
    DetachedLegClass="SeveredLegClot"
    DetachedHeadClass="SeveredHeadClot"

    Mesh=SkeletalMesh'KF_Freaks_Trip.CLOT_Freak'

    Skins(0)=Combiner'KF_Specimens_Trip_T.clot_cmb'

    AmbientSound=Sound'KF_BaseClot.Clot_Idle1Loop'//Sound'KFPlayerSound.Zombiesbreath'//
    MoanVoice=Sound'KF_EnemiesFinalSnd.Clot_Talk'
    JumpSound=Sound'KF_EnemiesFinalSnd.Clot_Jump'
    MeleeAttackHitSound=sound'KF_EnemiesFinalSnd.Clot_HitPlayer'

    HitSound(0)=Sound'KF_EnemiesFinalSnd.Clot_Pain'
    DeathSound(0)=Sound'KF_EnemiesFinalSnd.Clot_Death'

    ChallengeSound(0)=Sound'KF_EnemiesFinalSnd.Clot_Challenge'
    ChallengeSound(1)=Sound'KF_EnemiesFinalSnd.Clot_Challenge'
    ChallengeSound(2)=Sound'KF_EnemiesFinalSnd.Clot_Challenge'
    ChallengeSound(3)=Sound'KF_EnemiesFinalSnd.Clot_Challenge'
    DrawScale=1.1
    Prepivot=(Z=5.0)

    bUseExtendedCollision=true
    ColOffset=(Z=48)
    ColRadius=25
    ColHeight=5

    ExtCollAttachBoneName="Collision_Attach"

    BurningWalkFAnims(0)="WalkF_Fire"
    BurningWalkFAnims(1)="WalkF_Fire"
    BurningWalkFAnims(2)="WalkF_Fire"

    MeleeAnims(0)="ClotGrapple"
    MeleeAnims(1)="ClotGrappleTwo"
    MeleeAnims(2)="ClotGrappleThree"

    damageForce=5000
    KFRagdollName="Clot_Trip"

    ScoringValue=7

    MovementAnims(0)="ClotWalk"
    WalkAnims(0)="ClotWalk"
    WalkAnims(1)="ClotWalk"
    WalkAnims(2)="ClotWalk"
    WalkAnims(3)="ClotWalk"
    SoundRadius=80
    SoundVolume=50

    CollisionRadius=26.000000
    RotationRate=(Yaw=45000,Roll=0)

    GroundSpeed=125.000000
    WaterSpeed=125.000000
    MeleeDamage=6
    Health=180//130//200
    HealthMax=180//130//200
    HeadHealth=58//35
    JumpZ=340.000000

    MeleeRange=25.0//30.000000

    PuntAnim="ClotPunt"

    bCannibal = true
    MenuName="Clot"

    AdditionalWalkAnims(0) = "ClotWalk2"

    Intelligence=BRAINS_Mammal
    GrappleDuration=1.5

    SeveredHeadAttachScale=0.8
    SeveredLegAttachScale=0.8
    SeveredArmAttachScale=0.8

    ClotGrabMessageDelay=12.0
    HeadHeight=2.0
    HeadScale=1.1
    CrispUpThreshhold=9
    OnlineHeadshotOffset=(X=20,Y=0,Z=37)
    OnlineHeadshotScale=1.3
    MotionDetectorThreat=0.34
}
