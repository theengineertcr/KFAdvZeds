/*
 * Modified Bloat
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
 */
class AdvZombieBloat extends KFMonster;

var bool bEnableAbsorption;           // Stops projectiles and hitscan weapons with penetration from going through him. Does not affect damage.
var bool bEnableNewBurnBehaviour;     // When Bloats die while on fire, their body explodes into flames and ignites anyone nearby.
var bool bEnableUsedAsCover;          // Zeds use him as a cover. Locked to Hard and above.
var bool bEnableHeadlessBileSpray;    // While headless, Bloats spray bile from their neck until they die. Locked to Suicidal and above.
var bool bEnableBileRemains;          // Bile on the floor is equivalent to standing in lava, burning players to death. Locked to HoE and above.

var float RestunTime;
var bool bStunAllowed;
var class<FleshHitEmitter> BileExplosion;
var class<FleshHitEmitter> BileExplosionHeadless;

var BileJet BloatJet;
var bool bPlayBileSplash;
var bool bMovingPukeAttack;
var float RunAttackTimeout;

function bool FlipOver() {
    return false;
}

simulated function PostBeginPlay() {
    super.PostBeginPlay();
}

// don't interrupt the bloat while he is puking
simulated function bool HitCanInterruptAction() {
    if( bShotAnim ) {
        return false;
    }
    return true;
}

function DoorAttack(Actor A) {
    if ( bShotAnim || Physics == PHYS_Swimming) {
        return;
    } else if ( A!=None ) {
        bShotAnim = true;
        if( !bDecapitated && bDistanceAttackingDoor ) {
            SetAnimAction('ZombieBarf');
        } else {
            SetAnimAction('DoorBash');
            GotoState('DoorBashing');
        }
    }
}

function RangedAttack(Actor A) {
    local int LastFireTime;
    local float ChargeChance;

    if ( bShotAnim ) {
        return;
    }

    if ( Physics == PHYS_Swimming ) {
        SetAnimAction('Claw');
        bShotAnim = true;
        LastFireTime = Level.TimeSeconds;
    } else if ( VSize(A.Location - Location) < MeleeRange + CollisionRadius + A.CollisionRadius ) {
        bShotAnim = true;
        LastFireTime = Level.TimeSeconds;
        SetAnimAction('Claw');
        //PlaySound(sound'Claw2s', SLOT_Interact); KFTODO: Replace this
        Controller.bPreparingMove = true;
        Acceleration = vect(0,0,0);
    } else if ( (KFDoorMover(A) != none || VSize(A.Location-Location) <= 250) && !bDecapitated ) {
        bShotAnim = true;

        // Decide what chance the bloat has of charging during a puke attack
        if( Level.Game.GameDifficulty < 2.0 ) {
            ChargeChance = 0.2;
        } else if( Level.Game.GameDifficulty < 4.0 ) {
            ChargeChance = 0.4;
        } else if( Level.Game.GameDifficulty < 5.0 ) {
            ChargeChance = 0.6;
        } else {
            ChargeChance = 0.8;
        }

        // Randomly do a moving attack so the player can't kite the zed
        if( FRand() < ChargeChance ) {
            SetAnimAction('ZombieBarfMoving');
            RunAttackTimeout = GetAnimDuration('ZombieBarf', 1.0);
            bMovingPukeAttack=true;
        } else {
            SetAnimAction('ZombieBarf');
            Controller.bPreparingMove = true;
            Acceleration = vect(0,0,0);
        }


        // Randomly send out a message about Bloat Vomit burning(3% chance)
        if ( FRand() < 0.03 && KFHumanPawn(A) != none && PlayerController(KFHumanPawn(A).Controller) != none ) {
            PlayerController(KFHumanPawn(A).Controller).Speech('AUTO', 7, "");
        }
    }
}

// Overridden to handle playing upper body only attacks when moving
simulated event SetAnimAction(name NewAction) {
    local int meleeAnimIndex;
    local bool bWantsToAttackAndMove;

    if (NewAction=='' ) {
        Return;
    }

    bWantsToAttackAndMove = NewAction == 'ZombieBarfMoving';

    if (NewAction == 'Claw' ) {
        meleeAnimIndex = Rand(3);
        NewAction = meleeAnims[meleeAnimIndex];
        CurrentDamtype = ZombieDamType[meleeAnimIndex];
    } else if( NewAction == 'DoorBash' ) {
       CurrentDamtype = ZombieDamType[Rand(3)];
    }

    if (bWantsToAttackAndMove ) {
       ExpectingChannel = AttackAndMoveDoAnimAction(NewAction);
    } else {
       ExpectingChannel = DoAnimAction(NewAction);
    }

    if (!bWantsToAttackAndMove && AnimNeedsWait(NewAction) ) {
        bWaitForAnim = true;
    } else {
        bWaitForAnim = false;
    }

    if (Level.NetMode!=NM_Client ) {
        AnimAction = NewAction;
        bResetAnimAct = True;
        ResetAnimActTime = Level.TimeSeconds+0.3;
    }
}

// Handle playing the anim action on the upper body only if we're attacking and moving
simulated function int AttackAndMoveDoAnimAction( name AnimName ) {
    if( AnimName=='ZombieBarfMoving' ) {
        AnimBlendParams(1, 1.0, 0.0,, FireRootBone);
        PlayAnim('ZombieBarf',, 0.1, 1);
        return 1;
    }
    return super.DoAnimAction( AnimName );
}

function PlayDyingSound() {
    if( Level.NetMode!=NM_Client ) {
        if ( bGibbed ) {
            PlaySound(sound'KF_EnemiesFinalSnd.Bloat_DeathPop', SLOT_Pain,2.0,true,525);
            return;
        }

        if( bDecapitated ) {
            PlaySound(HeadlessDeathSound, SLOT_Pain,1.30,true,525);
        } else {
            PlaySound(sound'KF_EnemiesFinalSnd.Bloat_DeathPop', SLOT_Pain,2.0,true,525);
        }
    }
}

function SpawnTwoShots() {
    local vector X,Y,Z, FireStart;
    local rotator FireRotation;


    if(bDecapitated || bPlayedDeath){
        return;
    }

    if( Controller!=None && KFDoorMover(Controller.Target)!=None ) {
        Controller.Target.TakeDamage(22,Self,Location,vect(0,0,0),Class'DamTypeVomit');
        return;
    }

    GetAxes(Rotation,X,Y,Z);
    FireStart = Location+(vect(30,0,64) >> Rotation)*DrawScale;
    if ( !SavedFireProperties.bInitialized ) {
        SavedFireProperties.AmmoClass = Class'SkaarjAmmo';
        SavedFireProperties.ProjectileClass = Class'KFBloatVomit';
        SavedFireProperties.WarnTargetPct = 1;
        SavedFireProperties.MaxRange = 500;
        SavedFireProperties.bTossed = False;
        SavedFireProperties.bTrySplash = False;
        SavedFireProperties.bLeadTarget = True;
        SavedFireProperties.bInstantHit = True;
        SavedFireProperties.bInitialized = True;
    }

    // Turn off extra collision before spawning vomit, otherwise spawn fails
    ToggleAuxCollision(false);
    FireRotation = Controller.AdjustAim(SavedFireProperties,FireStart,600);
    Spawn(Class'KFBloatVomit',,,FireStart,FireRotation);
    //Spawn puke puddle when puking
    //TODO: Limit this to hard+
    Spawn(Class'AdvZedsPukePuddle',,,FireStart,FireRotation);

    FireStart-=(0.5*CollisionRadius*Y);
    FireRotation.Yaw -= 1200;
    spawn(Class'KFBloatVomit',,,FireStart, FireRotation);

    FireStart+=(CollisionRadius*Y);
    FireRotation.Yaw += 2400;
    spawn(Class'KFBloatVomit',,,FireStart, FireRotation);
    // Turn extra collision back on
    ToggleAuxCollision(true);
}

simulated function Tick(float deltatime) {
    local vector BileExplosionLoc;
    local FleshHitEmitter GibBileExplosion;

    Super.tick(deltatime);

    if(Level.TimeSeconds > RestunTime){
        bStunAllowed = true;
    }


    if( Role == ROLE_Authority && bMovingPukeAttack ) {
        // Keep moving toward the target until the timer runs out (anim finishes)
        if( RunAttackTimeout > 0 ) {
            RunAttackTimeout -= DeltaTime;

            if( RunAttackTimeout <= 0 ) {
                RunAttackTimeout = 0;
                bMovingPukeAttack=false;
            }
        }

        // Keep the gorefast moving toward its target when attacking
        if( bShotAnim && !bWaitForAnim ) {
            if( LookTarget!=None ) {
                Acceleration = AccelRate * Normal(LookTarget.Location - Location);
            }
        }
    }

    // Hack to force animation updates on the server for the bloat if he is relevant to someone
    // He has glitches when some of his animations don't play on the server. If we
    // find some other fix for the glitches take this out - Ramm
    if( Level.NetMode != NM_Client && Level.NetMode != NM_Standalone ) {
        if( (Level.TimeSeconds-LastSeenOrRelevantTime) < 1.0  ) {
            bForceSkelUpdate=true;
        } else {
            bForceSkelUpdate=false;
        }
    }

    if ( Level.NetMode!=NM_DedicatedServer && Health <= 0 && !bPlayBileSplash &&
        HitDamageType != class'DamTypeBleedOut' ) {
        if ( !class'GameInfo'.static.UseLowGore() ) {
            BileExplosionLoc = self.Location;
            BileExplosionLoc.z += (CollisionHeight - (CollisionHeight * 0.5));

            if (bDecapitated) {
                GibBileExplosion = Spawn(BileExplosionHeadless,self,, BileExplosionLoc );
            } else {
                GibBileExplosion = Spawn(BileExplosion,self,, BileExplosionLoc );
            }
            bPlayBileSplash = true;
        } else {
            BileExplosionLoc = self.Location;
            BileExplosionLoc.z += (CollisionHeight - (CollisionHeight * 0.5));

            GibBileExplosion = Spawn(class 'LowGoreBileExplosion',self,, BileExplosionLoc );
            bPlayBileSplash = true;
        }
    }
}

function BileBomb() {
    BloatJet = spawn(class'BileJet', self,,Location,Rotator(-PhysicsVolume.Gravity));
    //Spawn puke puddle after exploding
    //TODO: Limit this to hard+
    Spawn(Class'AdvZedsPukePuddle', self,,Location,Rotator(-PhysicsVolume.Gravity));
}


function PlayDyingAnimation(class<DamageType> DamageType, vector HitLoc) {
    super.PlayDyingAnimation(DamageType, HitLoc);

    // Don't blow up with bleed out
    if( bDecapitated && DamageType == class'DamTypeBleedOut' ) {
        return;
    }

    if ( !class'GameInfo'.static.UseLowGore() ) {
        HideBone(SpineBone2);
    }

    if(Role == ROLE_Authority) {
        BileBomb();
    }
}

simulated function HideBone(name boneName) {
    local int BoneScaleSlot;
    local coords boneCoords;
    local bool bValidBoneToHide;

       if( boneName == LeftThighBone ) {
        boneScaleSlot = 0;
        bValidBoneToHide = true;
        if( SeveredLeftLeg == none ) {
            SeveredLeftLeg = Spawn(SeveredLegAttachClass,self);
            SeveredLeftLeg.SetDrawScale(SeveredLegAttachScale);
            boneCoords = GetBoneCoords( 'lleg' );
            AttachEmitterEffect( LimbSpurtEmitterClass, 'lleg', boneCoords.Origin, rot(0,0,0) );
            AttachToBone(SeveredLeftLeg, 'lleg');
        }
    } else if ( boneName == RightThighBone ) {
        boneScaleSlot = 1;
        bValidBoneToHide = true;
        if( SeveredRightLeg == none ) {
            SeveredRightLeg = Spawn(SeveredLegAttachClass,self);
            SeveredRightLeg.SetDrawScale(SeveredLegAttachScale);
            boneCoords = GetBoneCoords( 'rleg' );
            AttachEmitterEffect( LimbSpurtEmitterClass, 'rleg', boneCoords.Origin, rot(0,0,0) );
            AttachToBone(SeveredRightLeg, 'rleg');
        }
    } else if( boneName == RightFArmBone ) {
        boneScaleSlot = 2;
        bValidBoneToHide = true;
        if( SeveredRightArm == none ) {
            SeveredRightArm = Spawn(SeveredArmAttachClass,self);
            SeveredRightArm.SetDrawScale(SeveredArmAttachScale);
            boneCoords = GetBoneCoords( 'rarm' );
            AttachEmitterEffect( LimbSpurtEmitterClass, 'rarm', boneCoords.Origin, rot(0,0,0) );
            AttachToBone(SeveredRightArm, 'rarm');
        }
    } else if ( boneName == LeftFArmBone ) {
        boneScaleSlot = 3;
        bValidBoneToHide = true;
        if( SeveredLeftArm == none ) {
            SeveredLeftArm = Spawn(SeveredArmAttachClass,self);
            SeveredLeftArm.SetDrawScale(SeveredArmAttachScale);
            boneCoords = GetBoneCoords( 'larm' );
            AttachEmitterEffect( LimbSpurtEmitterClass, 'larm', boneCoords.Origin, rot(0,0,0) );
            AttachToBone(SeveredLeftArm, 'larm');
        }
    } else if ( boneName == HeadBone ) {
        // Only scale the bone down once
        if( SeveredHead == none ) {
            bValidBoneToHide = true;
            boneScaleSlot = 4;
            SeveredHead = Spawn(SeveredHeadAttachClass,self);
            SeveredHead.SetDrawScale(SeveredHeadAttachScale);
            boneCoords = GetBoneCoords( 'neck' );
            AttachEmitterEffect( NeckSpurtEmitterClass, 'neck', boneCoords.Origin, rot(0,0,0) );
            AttachToBone(SeveredHead, 'neck');
        } else {
            return;
        }
    } else if ( boneName == 'spine' ) {
        bValidBoneToHide = true;
        boneScaleSlot = 5;
    } else if ( boneName == SpineBone2 ) {
        bValidBoneToHide = true;
        boneScaleSlot = 6;
    }

    // Only hide the bone if it is one of the arms, legs, or head, don't hide other misc bones
    if( bValidBoneToHide ) {
        SetBoneScale(BoneScaleSlot, 0.0, BoneName);
    }
}

State Dying {
    function tick(float deltaTime) {
    if (BloatJet != none) {
        BloatJet.SetLocation(location);
        BloatJet.SetRotation(GetBoneRotation(FireRootBone));
    }
        super.tick(deltaTime);
    }
}

function RemoveHead() {
    bCanDistanceAttackDoors = False;
    Super.RemoveHead();
}

function TakeDamage( int Damage, Pawn InstigatedBy, Vector Hitlocation, Vector Momentum, class<DamageType> damageType, optional int HitIndex) {
    local bool bIsHeadShot;

    bIsHeadShot = IsHeadShot(Hitlocation, normal(Momentum), 1.0);

    // Bloats are volatile. They burn faster than other zeds.
    if (DamageType == class 'DamTypeBurned') {
        Damage *= 1.5;
    }

    if (damageType == class 'DamTypeVomit') {
        return;
    } else if( damageType == class 'DamTypeBlowerThrower' ) {
       // Reduced damage from the blower thrower bile, but lets not zero it out entirely
       Damage *= 0.25;
    }

    if(bIsHeadshot && bShotAnim && bStunAllowed){
        bStunAllowed = false;
        RestunTime = Level.TimeSeconds + 1;
        SetAnimAction('HitF');
    }
    

    Super.TakeDamage(Damage,instigatedBy,hitlocation,momentum,damageType,HitIndex);
}

simulated function ProcessHitFX() {
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

        if ( !Level.bDropDetail && !class'GameInfo'.static.NoBlood() && !bSkeletized && !class'GameInfo'.static.UseLowGore() ) {
            //AttachEmitterEffect( BleedingEmitterClass, HitFX[SimHitFxTicker].bone, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir );

            HitFX[SimHitFxTicker].damtype.static.GetHitEffects( HitEffects, Health );

            if( !PhysicsVolume.bWaterVolume ) {
                for( i = 0; i < ArrayCount(HitEffects); i++ ) {
                    if( HitEffects[i] == None )
                        continue;

                      AttachEffect( HitEffects[i], HitFX[SimHitFxTicker].bone, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir );
                }
            }
        }

        if ( class'GameInfo'.static.UseLowGore() ) {
            HitFX[SimHitFxTicker].bSever = false;

            switch( HitFX[SimHitFxTicker].bone ) {
                 case 'head':
                    if ( !bHeadGibbed ) {
                        if ( HitFX[SimHitFxTicker].damtype == class'DamTypeDecapitation' ) {
                            DecapFX( boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, false);
                        } else if ( HitFX[SimHitFxTicker].damtype == class'DamTypeProjectileDecap' ) {
                            DecapFX( boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, false, true);
                        } else if ( HitFX[SimHitFxTicker].damtype == class'DamTypeMeleeDecapitation' ) {
                            DecapFX( boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, true);
                        }

                          bHeadGibbed=true;
                      }
                    break;
            }

            return;
        }

        if ( HitFX[SimHitFxTicker].bSever ) {
            GibPerterbation = HitFX[SimHitFxTicker].damtype.default.GibPerterbation;

            switch( HitFX[SimHitFxTicker].bone ) {
                case 'obliterate':
                    break;

                case LeftThighBone:
                    if ( !bLeftLegGibbed ) {
                        SpawnSeveredGiblet( DetachedLegClass, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, GetBoneRotation(HitFX[SimHitFxTicker].bone) );
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrainb',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        bLeftLegGibbed=true;
                    }
                    break;

                case RightThighBone:
                    if ( !bRightLegGibbed ) {
                        SpawnSeveredGiblet( DetachedLegClass, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, GetBoneRotation(HitFX[SimHitFxTicker].bone) );
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrainb',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        bRightLegGibbed=true;
                    }
                    break;

                case LeftFArmBone:
                    if ( !bLeftArmGibbed ) {
                        SpawnSeveredGiblet( DetachedArmClass, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, GetBoneRotation(HitFX[SimHitFxTicker].bone) );
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrainb',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;;
                        bLeftArmGibbed=true;
                    }
                    break;

                case RightFArmBone:
                    if ( !bRightArmGibbed ) {
                        SpawnSeveredGiblet( DetachedArmClass, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, GetBoneRotation(HitFX[SimHitFxTicker].bone) );
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrainb',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        bRightArmGibbed=true;
                    }
                    break;

                case 'head':
                    if ( !bHeadGibbed ) {
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

            // Don't do this right now until we get the effects sorted - Ramm
            if ( HitFX[SimHitFXTicker].bone != 'Spine' && HitFX[SimHitFXTicker].bone != FireRootBone &&
                HitFX[SimHitFXTicker].bone != LeftFArmBone && HitFX[SimHitFXTicker].bone != RightFArmBone &&
                HitFX[SimHitFXTicker].bone != 'head' && Health <=0 )
                HideBone(HitFX[SimHitFxTicker].bone);
        }
    }
}

static simulated function PreCacheStaticMeshes(LevelInfo myLevel) {//should be derived and used.
    Super.PreCacheStaticMeshes(myLevel);
    myLevel.AddPrecacheStaticMesh(StaticMesh'kf_gore_trip_sm.limbs.bloat_head');
}

static simulated function PreCacheMaterials(LevelInfo myLevel) {
    myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T.bloat_cmb');
    myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T.bloat_env_cmb');
    myLevel.AddPrecacheMaterial(Texture'KF_Specimens_Trip_T.bloat_diffuse');
}

defaultproperties {
    DetachedArmClass=class'SeveredArmBloat'
    DetachedLegClass=class'SeveredLegBloat'
    DetachedHeadClass=class'SeveredHeadBloat'

    BileExplosion=class'KFMod.BileExplosion'
    BileExplosionHeadless=class'KFMod.BileExplosionHeadless'

    Mesh=SkeletalMesh'KF_Freaks_Trip.Bloat_Freak'

    Skins(0)=Combiner'KF_Specimens_Trip_T.bloat_cmb'

    AmbientSound=Sound'KF_BaseBloat.Bloat_Idle1Loop'
    MoanVoice=Sound'KF_EnemiesFinalSnd.Bloat_Talk'
    JumpSound=Sound'KF_EnemiesFinalSnd.Bloat_Jump'
    MeleeAttackHitSound=sound'KF_EnemiesFinalSnd.Bloat_HitPlayer'

    HitSound(0)=Sound'KF_EnemiesFinalSnd.Bloat_Pain'
    DeathSound(0)=Sound'KF_EnemiesFinalSnd.Bloat_Death'

    ChallengeSound(0)=Sound'KF_EnemiesFinalSnd.Bloat_Challenge'
    ChallengeSound(1)=Sound'KF_EnemiesFinalSnd.Bloat_Challenge'
    ChallengeSound(2)=Sound'KF_EnemiesFinalSnd.Bloat_Challenge'
    ChallengeSound(3)=Sound'KF_EnemiesFinalSnd.Bloat_Challenge'
    DrawScale=1.075
    Prepivot=(Z=5.0)

    MeleeAnims(0)="BloatChop2"
    MeleeAnims(1)="BloatChop2"
    MeleeAnims(2)="BloatChop2"
    damageForce=70000
    bFatAss=True
    KFRagdollName="Bloat_Trip"
    PuntAnim="BloatPunt"

    AmmunitionClass=Class'KFMod.BZombieAmmo'
    ScoringValue=17
    IdleHeavyAnim="BloatIdle"
    IdleRifleAnim="BloatIdle"
    MeleeRange=30.0//55.000000

    MovementAnims(0)="WalkBloat"
    MovementAnims(1)="WalkBloat"
    WalkAnims(0)="WalkBloat"
    WalkAnims(1)="WalkBloat"
    WalkAnims(2)="WalkBloat"
    WalkAnims(3)="WalkBloat"
    IdleCrouchAnim="BloatIdle"
    IdleWeaponAnim="BloatIdle"
    IdleRestAnim="BloatIdle"
    //SoundRadius=2.5
    AmbientSoundScaling=8.0
    SoundVolume=200
    AmbientGlow=0

    Mass=400.000000
    RotationRate=(Yaw=45000,Roll=0)

    GroundSpeed=75.0//105.000000
    WaterSpeed=102.000000
    Health=525//800
    HealthMax=525
    PlayerCountHealthScale=0.25
    PlayerNumHeadHealthScale=0.0
    HeadHealth=25
    MeleeDamage=14
    JumpZ=320.000000

    bCannibal = False // No animation for him.
    MenuName="Bloat"

    CollisionRadius=26.000000
    CollisionHeight=44
    bCanDistanceAttackDoors=True
    Intelligence=BRAINS_Stupid
    bUseExtendedCollision=True
    ColOffset=(Z=60)//(Z=42)
    ColRadius=27
    ColHeight=22//40
    ZombieFlag=1

    SeveredHeadAttachScale=1.7
    SeveredLegAttachScale=1.3
    SeveredArmAttachScale=1.1

    BleedOutDuration=6.0
    HeadHeight=2.5
    HeadScale=1.5
    OnlineHeadshotOffset=(X=5,Y=0,Z=70)
    OnlineHeadshotScale=1.5
    MotionDetectorThreat=1.0

    ZapThreshold=0.5
    ZappedDamageMod=1.5
    bHarpoonToHeadStuns=true
    bHarpoonToBodyStuns=false
}