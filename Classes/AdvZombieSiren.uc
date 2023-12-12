/*
 * Modified Siren - blind and deadly.
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
 */
class AdvZombieSiren extends KFMonster;

// todo: make her take extra dmg from fire

var bool bEnableLiterallyBlind;         // When the Siren is not near any zeds, or isn't taking any gun fire, she loses her ability to path effectively. When entering this state, she starts screaming helpessly.
var bool bEnableNewScreamMechanics;     // Sirens scream when they're in pain or when she hears the death rattle of nearby zeds. She stops screaming when a Fleshpound rages or a Scrake bumps into her.
var bool bEnableNewScreamCancel;        // Sirens will not be able to scream for a short time after taking any headshot damage. Headshotting interrupts any active scream.
var bool bEnablePullingScream;          // Sirens can pull in players and projectiles alike. Locked to Hard and above.
var bool bEnableExtinguishingScream;    // Sirens screams extinguishes flames and any burning zeds that are nearby. Locked to Suicidal and above.
var bool bEnableDestructiveScream;      // Sirens screams can detonate explosives and destroy projectiles. Players carrying explosives immediately explode if they're too close. Locked to HoE and above.

var float RestunTime;
var bool bStunAllowed;

var () int ScreamRadius; // AOE for scream attack.

var () class <DamageType> ScreamDamageType;
var () int ScreamForce;

var(Shake)  rotator RotMag;            // how far to rot view
var(Shake)  float   RotRate;           // how fast to rot view
var(Shake)  vector  OffsetMag;         // max view offset vertically
var(Shake)  float   OffsetRate;        // how fast to offset view vertically
var(Shake)  float   ShakeTime;         // how long to shake for per scream
var(Shake)  float   ShakeFadeTime;     // how long after starting to shake to start fading out
var(Shake)  float	ShakeEffectScalar; // Overall scale for shake/blur effect
var(Shake)  float	MinShakeEffectScale;// The minimum that the shake effect drops off over distance
var(Shake)  float	ScreamBlurScale;   // How much motion blur to give from screams


simulated function bool HitCanInterruptAction(){
    if( bShotAnim ) {
        return false;
    }
    return true;
}

simulated event SetAnimAction(name NewAction){
    local int meleeAnimIndex;

    if( NewAction=='' ){
        Return;
    }
    if(NewAction == 'Claw') {
        meleeAnimIndex = Rand(3);
        NewAction = meleeAnims[meleeAnimIndex];
        CurrentDamtype = ZombieDamType[meleeAnimIndex];
    }
    ExpectingChannel = DoAnimAction(NewAction);

    if( AnimNeedsWait(NewAction) ) {
        bWaitForAnim = true;
    } else {
        bWaitForAnim = false;
    }

    if( Level.NetMode!=NM_Client ) {
        AnimAction = NewAction;
        bResetAnimAct = True;
        ResetAnimActTime = Level.TimeSeconds+0.3;
    }
}

function bool FlipOver() {
    Return False;
}

function DoorAttack(Actor A) {
    if ( bShotAnim || Physics == PHYS_Swimming || bDecapitated || A==None ){
        return;
    }
    bShotAnim = true;
    SetAnimAction('Siren_Scream');
}

function RangedAttack(Actor A) {
    local int LastFireTime;
    local float Dist;

    if ( bShotAnim ){
        return;
    }
        

    Dist = VSize(A.Location - Location);

    if ( Physics == PHYS_Swimming ) {
        SetAnimAction('Claw');
        bShotAnim = true;
        LastFireTime = Level.TimeSeconds;
    } else if ( Dist < MeleeRange + CollisionRadius + A.CollisionRadius ) {
        bShotAnim = true;
        LastFireTime = Level.TimeSeconds;
        SetAnimAction('Claw');
        //PlaySound(sound'Claw2s', SLOT_Interact); KFTODO: Replace this
        Controller.bPreparingMove = true;
        Acceleration = vect(0,0,0);
    } else if( Dist <= ScreamRadius && !bDecapitated && !bZapped ) {
        bShotAnim=true;
        SetAnimAction('Siren_Scream');
        // Only stop moving if we are close
        if( Dist < ScreamRadius * 0.25 ) {
            Controller.bPreparingMove = true;
            Acceleration = vect(0,0,0);
        } else {
            Acceleration = AccelRate * Normal(A.Location - Location);
        }
    }
}

simulated function int DoAnimAction( name AnimName ) {
    if( AnimName=='Siren_Scream' || AnimName=='Siren_Bite' || AnimName=='Siren_Bite2' ) {
        AnimBlendParams(1, 1.0, 0.0,, SpineBone1);
        PlayAnim(AnimName,, 0.1, 1);
        return 1;
    }

    if( AnimName=='HitF' || AnimName=='HitF2' || AnimName=='HitF3' || AnimName==KFHitFront || AnimName==KFHitBack || AnimName==KFHitRight
     || AnimName==KFHitLeft || AnimName=='HitReactionF') {
        AnimBlendParams(1, 1.0, 0.0,, SpineBone1);
        PlayAnim(AnimName,, 0.1, 1);
        return 1;
    }

    PlayAnim(AnimName,,0.1);
    Return 0;
}

// Scream Time
simulated function SpawnTwoShots() {
    if( bZapped || bDecapitated || bPlayedDeath) {
        return;
    }

    DoShakeEffect();

    if( Level.NetMode!=NM_Client ) {
        // Deal Actual Damage.
        if( Controller!=None && KFDoorMover(Controller.Target)!=None ){
            Controller.Target.TakeDamage(ScreamDamage*0.6,Self,Location,vect(0,0,0),ScreamDamageType);
        } else {
            HurtRadius(ScreamDamage ,ScreamRadius, ScreamDamageType, ScreamForce, Location);
        }
    }
}

// Shake nearby players screens
simulated function DoShakeEffect() {
    local PlayerController PC;
    local float Dist, scale, BlurScale;

    //viewshake
    if (Level.NetMode != NM_DedicatedServer) {
        PC = Level.GetLocalPlayerController();
        if (PC != None && PC.ViewTarget != None) {
            Dist = VSize(Location - PC.ViewTarget.Location);
            if (Dist < ScreamRadius ) {
                scale = (ScreamRadius - Dist) / (ScreamRadius);
                scale *= ShakeEffectScalar;
                BlurScale = scale;

                // Reduce blur if there is something between us and the siren
                if( !FastTrace(PC.ViewTarget.Location,Location) ) {
                    scale *= 0.25;
                    BlurScale = scale;
                } else {
                    scale = Lerp(scale,MinShakeEffectScale,1.0);
                }

                PC.SetAmbientShake(Level.TimeSeconds + ShakeFadeTime, ShakeTime, OffsetMag * Scale, OffsetRate, RotMag * Scale, RotRate);

                if( KFHumanPawn(PC.ViewTarget) != none ) {
                    KFHumanPawn(PC.ViewTarget).AddBlur(ShakeTime, BlurScale * ScreamBlurScale);
                }

                // 10% chance of player saying something about our scream
                if ( Level != none && Level.Game != none && !KFGameType(Level.Game).bDidSirenScreamMessage && FRand() < 0.10 ) {
                    PC.Speech('AUTO', 16, "");
                    KFGameType(Level.Game).bDidSirenScreamMessage = true;
                }
            }
        }
    }
}

simulated function HurtRadius( float DamageAmount, float DamageRadius, class<DamageType> DamageType, float Momentum, vector HitLocation )
{
    local actor Victims;
    local float damageScale, dist;
    local vector dir;
    local float UsedDamageAmount;

    if( bHurtEntry ){
        return;
    }

    bHurtEntry = true;
    foreach VisibleCollidingActors( class 'Actor', Victims, DamageRadius, HitLocation )
    {
        // don't let blast damage affect fluid - VisibleCollisingActors doesn't really work for them - jag
        // Or Karma actors in this case. Self inflicted Death due to flying chairs is uncool for a zombie of your stature.
        if( (Victims != self) && !Victims.IsA('FluidSurfaceInfo') && !Victims.IsA('KFMonster') && !Victims.IsA('ExtendedZCollision') ) {
            dir = Victims.Location - HitLocation;
            dist = FMax(1,VSize(dir));
            dir = dir/dist;
            damageScale = 1 - FMax(0,(dist - Victims.CollisionRadius)/DamageRadius);

            if (!Victims.IsA('KFHumanPawn')) // If it aint human, don't pull the vortex crap on it.
                Momentum = 0;

            if (Victims.IsA('KFGlassMover')) {
                UsedDamageAmount = 100000; // Siren always shatters glass
            } else {
                UsedDamageAmount = DamageAmount;
            }

            Victims.TakeDamage(damageScale * UsedDamageAmount,Instigator, Victims.Location - 0.5 * (Victims.CollisionHeight + Victims.CollisionRadius) * dir,(damageScale * Momentum * dir),DamageType);

            if (Instigator != None && Vehicle(Victims) != None && Vehicle(Victims).Health > 0){
                Vehicle(Victims).DriverRadiusDamage(UsedDamageAmount, DamageRadius, Instigator.Controller, DamageType, Momentum, HitLocation);
            }
        }
    }
    bHurtEntry = false;
}


function RemoveHead(){
    Super.RemoveHead();
    // Just kill her when she's got no head.
    KilledBy(LastDamagedBy);
}

function TakeDamage( int Damage, Pawn InstigatedBy, Vector Hitlocation, Vector Momentum, class<DamageType> damageType, optional int HitIndex) {
    local bool bIsHeadShot;

    bIsHeadShot = IsHeadShot(Hitlocation, normal(Momentum), 1.0);

    // Sirens that have been headshot have their scream animation interrupted
    if(bIsHeadshot && bShotAnim && bStunAllowed && Damage >= 100){
        bStunAllowed = false;
        RestunTime = Level.TimeSeconds + 1.0;
        SetAnimAction('HitReactionF');
    }
    

    Super.TakeDamage(Damage,instigatedBy,hitlocation,momentum,damageType,HitIndex);
}


simulated function Tick( float Delta ){
    local SirenScream ScreamEmitter;
    Super.Tick(Delta);

    if(ScreamEmitter != none &&( bPlayedDeath || !bStunAllowed)){
        ScreamEmitter.Destroy();
    }

    if(Level.TimeSeconds > RestunTime){
        bStunAllowed = true;
    }

    if( Role == ROLE_Authority ) {
        if( bShotAnim ) {
            SetGroundSpeed(GetOriginalGroundSpeed() * 0.65);

            if( LookTarget!=None ) {
                Acceleration = AccelRate * Normal(LookTarget.Location - Location);
            }
        } else {
            SetGroundSpeed(GetOriginalGroundSpeed());
        }
    }
}

simulated function ProcessHitFX(){
    local Coords boneCoords;
    local class<xEmitter> HitEffects[4];
    local int i,j;
    local float GibPerterbation;

    if( (Level.NetMode == NM_DedicatedServer) || bSkeletized || (Mesh == SkeletonMesh)) {
        SimHitFxTicker = HitFxTicker;
        return;
    }

    for ( SimHitFxTicker = SimHitFxTicker; SimHitFxTicker != HitFxTicker; SimHitFxTicker = (SimHitFxTicker + 1) % ArrayCount(HitFX) ) {
        j++;
        if ( j > 30 ) {
            SimHitFxTicker = HitFxTicker;
            return;
        }

        if( (HitFX[SimHitFxTicker].damtype == None) || (Level.bDropDetail && (Level.TimeSeconds - LastRenderTime > 3) && !IsHumanControlled()) )
            continue;

        //log("Processing effects for damtype "$HitFX[SimHitFxTicker].damtype);

        if( HitFX[SimHitFxTicker].bone == 'obliterate' && !class'GameInfo'.static.UseLowGore()) {
            SpawnGibs( HitFX[SimHitFxTicker].rotDir, 1);
            bGibbed = true;
            // Wait a tick on a listen server so the obliteration can replicate before the pawn is destroyed
            if( Level.NetMode == NM_ListenServer ) {
                bDestroyNextTick = true;
                TimeSetDestroyNextTickTime = Level.TimeSeconds;
            } else {
                Destroy();
            }
            return;
        }

        boneCoords = GetBoneCoords( HitFX[SimHitFxTicker].bone );

        if ( !Level.bDropDetail && !class'GameInfo'.static.NoBlood() && !bSkeletized && !class'GameInfo'.static.UseLowGore()) {
            //AttachEmitterEffect( BleedingEmitterClass, HitFX[SimHitFxTicker].bone, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir );

            HitFX[SimHitFxTicker].damtype.static.GetHitEffects( HitEffects, Health );

            if( !PhysicsVolume.bWaterVolume )  {
                for( i = 0; i < ArrayCount(HitEffects); i++ ) {
                    if( HitEffects[i] == None )
                        continue;

                      AttachEffect( HitEffects[i], HitFX[SimHitFxTicker].bone, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir );
                }
            }
        }
        if ( class'GameInfo'.static.UseLowGore() ){
            HitFX[SimHitFxTicker].bSever = false;
        }

        if( HitFX[SimHitFxTicker].bSever ) {
            GibPerterbation = HitFX[SimHitFxTicker].damtype.default.GibPerterbation;

            switch( HitFX[SimHitFxTicker].bone ) {
                case 'obliterate':
                    break;

                case LeftThighBone:
                    if( !bLeftLegGibbed ) {
                        SpawnSeveredGiblet( DetachedLegClass, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, GetBoneRotation(HitFX[SimHitFxTicker].bone) );
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrainb',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        bLeftLegGibbed=true;
                    }
                    break;

                case RightThighBone:
                    if( !bRightLegGibbed ) {
                        SpawnSeveredGiblet( DetachedLegClass, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, GetBoneRotation(HitFX[SimHitFxTicker].bone) );
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrainb',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        bRightLegGibbed=true;
                    }
                    break;

                case LeftFArmBone:
                    break;

                case RightFArmBone:
                    break;

                case 'head':
                    if( !bHeadGibbed ) {
                        if ( HitFX[SimHitFxTicker].damtype == class'DamTypeDecapitation' ) {
                            DecapFX( boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, false);
                        } else if( HitFX[SimHitFxTicker].damtype == class'DamTypeProjectileDecap' ) {
                            DecapFX( boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, false, true);
                        } else if( HitFX[SimHitFxTicker].damtype == class'DamTypeMeleeDecapitation' ) {
                            DecapFX( boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, true);
                        }

                          bHeadGibbed=true;
                      }
                    break;
            }


            if( HitFX[SimHitFXTicker].bone != 'Spine' && HitFX[SimHitFXTicker].bone != FireRootBone &&
                HitFX[SimHitFXTicker].bone != LeftFArmBone && HitFX[SimHitFXTicker].bone != RightFArmBone &&
                HitFX[SimHitFXTicker].bone != 'head' && Health <=0 )
                HideBone(HitFX[SimHitFxTicker].bone);
        }
    }
}

static simulated function PreCacheMaterials(LevelInfo myLevel) {//should be derived and used.
    myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T.siren_cmb');
    myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T.siren_env_cmb');
    myLevel.AddPrecacheMaterial(Texture'KF_Specimens_Trip_T.siren_diffuse');
    myLevel.AddPrecacheMaterial(Texture'KF_Specimens_Trip_T.siren_hair');
    myLevel.AddPrecacheMaterial(Material'KF_Specimens_Trip_T.siren_hair_fb');
}

defaultproperties{
    DetachedLegClass=class'SeveredLegSiren'
	DetachedHeadClass=class'SeveredHeadSiren'

    Mesh=SkeletalMesh'KF_Freaks_Trip.Siren_Freak'

    Skins(0)=FinalBlend'KF_Specimens_Trip_T.siren_hair_fb'
    Skins(1)=Combiner'KF_Specimens_Trip_T.siren_cmb'

    AmbientSound=Sound'KF_BaseSiren.Siren_IdleLoop'
    MoanVoice=Sound'KF_EnemiesFinalSnd.Siren_Talk'
    JumpSound=Sound'KF_EnemiesFinalSnd.Siren_Jump'

    HitSound(0)=Sound'KF_EnemiesFinalSnd.Siren_Pain'
    DeathSound(0)=Sound'KF_EnemiesFinalSnd.Siren_Death'

    ControllerClass=class'KFChar.SirenZombieController'
    bUseExtendedCollision=true
    ColOffset=(Z=48)
    ColRadius=25
    ColHeight=5

    ExtCollAttachBoneName="Collision_Attach"

    DrawScale=1.05
    PrePivot=(Z=3)
    ScreamRadius=700//800
    ScreamDamage=8 // 10
    ScreamDamageType=Class'KFMod.SirenScreamDamage'
    ScreamForce=-150000//-300000
    RotMag=(Pitch=150,Yaw=150,Roll=150)
    RotRate=500
    OffsetMag=(X=0.000000,Y=5.000000,Z=1.000000)
    OffsetRate=500
    MeleeAnims(0)="Siren_Bite"
    MeleeAnims(1)="Siren_Bite2"
    MeleeAnims(2)="Siren_Bite"
    HitAnims(0)="HitReactionF"
    HitAnims(1)="HitReactionF"
    HitAnims(2)="HitReactionF"
    MeleeDamage=13
    damageForce=5000
    KFRagdollName="Siren_Trip"
    ZombieDamType(0)=Class'KFMod.DamTypeSlashingAttack'
    ZombieDamType(1)=Class'KFMod.DamTypeSlashingAttack'
    ZombieDamType(2)=Class'KFMod.DamTypeSlashingAttack'

    ScoringValue=25
    SoundGroupClass=Class'KFMod.KFFemaleZombieSounds'
    IdleHeavyAnim="Siren_Idle"
    IdleRifleAnim="Siren_Idle"
    MeleeRange=45.000000
    GroundSpeed=100.0//100.000000
    WaterSpeed=80.000000
    Health=300//350
    HealthMax=300
    PlayerCountHealthScale=0.10
    PlayerNumHeadHealthScale=0.05
    HeadHealth=200
    MovementAnims(0)="Siren_Walk"
    MovementAnims(1)="Siren_Walk"
    MovementAnims(2)="Siren_Walk"
    MovementAnims(3)="Siren_Walk"
    WalkAnims(0)="Siren_Walk"
    WalkAnims(1)="Siren_Walk"
    WalkAnims(2)="Siren_Walk"
    WalkAnims(3)="Siren_Walk"
    IdleCrouchAnim="Siren_Idle"
    IdleWeaponAnim="Siren_Idle"
    IdleRestAnim="Siren_Idle"

    AmbientGlow=0
    CollisionRadius=26.000000
    RotationRate=(Yaw=45000,Roll=0)

    // these could need to be moved into children if children change them
    ChallengeSound(0)=Sound'KF_EnemiesFinalSnd.Siren_Challenge'
    ChallengeSound(1)=Sound'KF_EnemiesFinalSnd.Siren_Challenge'
    ChallengeSound(2)=Sound'KF_EnemiesFinalSnd.Siren_Challenge'
    ChallengeSound(3)=Sound'KF_EnemiesFinalSnd.Siren_Challenge'

    MenuName="Siren"

    bCanDistanceAttackDoors=True
    ZombieFlag=1

    ShakeEffectScalar=1.0
    ShakeTime=2.0
    ShakeFadeTime=0.25
    MinShakeEffectScale=0.6
    ScreamBlurScale=0.85

    SeveredHeadAttachScale=1.0
    SeveredLegAttachScale=0.7
    SeveredArmAttachScale=1.0
    HeadHeight=1.0
    HeadScale=1.0
    CrispUpThreshhold=7
    OnlineHeadshotOffset=(X=6,Y=0,Z=41)
    OnlineHeadshotScale=1.2
    MotionDetectorThreat=2.0
    ZapThreshold=0.5
    ZappedDamageMod=1.5
}