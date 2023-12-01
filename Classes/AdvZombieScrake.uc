/*
 * Modified Scrake
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
 */
class AdvZombieScrake extends KFMonster;

/* TODO
    - Melee attack is an instant kill
    - Can only deal damage IF his target is infront of him
    - Starts out with slow movement speed until he spots his first target, which then he passively
      Gains a speed increase until walks as fast as a player running with a knife
    - Once he has a target, he will not change it until they are dead
      On HoE, if target breaks line of sight for too long, rage
    - When raged, bumps zeds out of the way + starts spawning avoidlocations infront of him
    - Slowly turns to face target while melee attacking, allowing flanking from speedy perks
    - Has a grace period where he derages temporarily after killing a player that lasts 15 seconds
 */

#exec OBJ LOAD FILE=PlayerSounds.uax

var bool bEnablePush;               // Scrakes pushes zeds and players away while charging.
var bool bFocusTarget;              // Scrake will pursue the first player he sees until they die or they lose sight of them for more than 10-15 seconds.
var bool bEnableThrow;              // Scrake will knock players infront of him away if they block him from his main target. If possible, when this happens, all zeds target this player.
var bool bPassiveSpeedIncrease;     // Scrakes walking speed keeps increasing the longer the player avoids him. Reaches maximum after 10 seconds(Walking speed is equal to player running speed with a knife). Locked to Hard and above.
var bool bBetterControl;            // Scrakes can rotate towards his target while attacking much more effectively. Locked to Suicidal and above.
var bool bRagesOnFocusTargetLoss;   // Instead of changing target, they rage if they lose sight of them for too long. Basically the opposite of a Fleshpounds rage. Locked to HoE and above.
var(Sounds) sound   SawAttackLoopSound; // THe sound for the saw revved up, looping
var(Sounds) sound   ChainSawOffSound;   //The sound of this zombie dieing without a head
var         bool    bCharging;          // Scrake charges when his health gets low
var()       float   AttackChargeRate;   // Ratio to increase scrake movement speed when charging and attacking

// Exhaust effects
var()	class<VehicleExhaustEffect>	ExhaustEffectClass; // Effect class for the exhaust emitter
var()	VehicleExhaustEffect 		ExhaustEffect;
var 		bool	bNoExhaustRespawn;

replication{
    reliable if(Role == ROLE_Authority)
        bCharging;
    
}


simulated function PostNetBeginPlay() {
    EnableChannelNotify ( 1,1);
    AnimBlendParams(1, 1.0, 0.0,, SpineBone1);
    super.PostNetBeginPlay();
}

simulated function PostBeginPlay() {
    super.PostBeginPlay();
    SpawnExhaustEmitter();
}

// Make the scrakes's ambient scale higher, since there are just a few, and thier chainsaw need to be heard from a distance
simulated function CalcAmbientRelevancyScale() {
    CustomAmbientRelevancyScale = 1500/(100 * SoundRadius);
}

simulated function PostNetReceive() {
    if (bCharging){
        MovementAnims[0]='ChargeF';
    } else if( !(bCrispified && bBurnified) ) {
        MovementAnims[0]=default.MovementAnims[0];
    }
}

// This zed has been taken control of. Boost its health and speed
function SetMindControlled(bool bNewMindControlled) {
    if( bNewMindControlled ) {
        NumZCDHits++;

        // if we hit him a couple of times, make him rage!
        if( NumZCDHits > 1 ) {
            if( !IsInState('RunningToMarker') ) {
                GotoState('RunningToMarker');
            } else {
                NumZCDHits = 1;
                if( IsInState('RunningToMarker') ) {
                    GotoState('');
                }
            }
        } else {
            if( IsInState('RunningToMarker') ) {
                GotoState('');
            }
        }

        if( bNewMindControlled != bZedUnderControl ) {
            SetGroundSpeed(OriginalGroundSpeed * 1.25);
            Health *= 1.25;
            HealthMax *= 1.25;
        }
    } else {
        NumZCDHits=0;
    }
    bZedUnderControl = bNewMindControlled;
}

// Handle the zed being commanded to move to a new location
function GivenNewMarker() {
    if( bCharging && NumZCDHits > 1  ) {
        GotoState('RunningToMarker');
    } else {
        GotoState('');
    }
}

simulated function SetBurningBehavior() {
    // If we're burning stop charging
    if( Role == Role_Authority && IsInState('RunningState') ) {
        super.SetBurningBehavior();
        GotoState('');
    }
    super.SetBurningBehavior();
}

simulated function SpawnExhaustEmitter() {
    if ( Level.NetMode != NM_DedicatedServer ) {
        if ( ExhaustEffectClass != none ) {
            ExhaustEffect = Spawn(ExhaustEffectClass, self);

            if ( ExhaustEffect != none ) {
                AttachToBone(ExhaustEffect, 'Chainsaw_lod1');
                ExhaustEffect.SetRelativeLocation(vect(0, -20, 0));
            }
        }
    }
}

simulated function UpdateExhaustEmitter() {
    local byte Throttle;

    if ( Level.NetMode != NM_DedicatedServer ) {
        if ( ExhaustEffect != none ) {
            if ( bShotAnim ) {
                Throttle = 3;
            } else {
                Throttle = 0;
            }
        } else {
            if ( !bNoExhaustRespawn ) {
                SpawnExhaustEmitter();
            }
        }
    }
}

simulated function Tick(float DeltaTime) {
    super.Tick(DeltaTime);
    UpdateExhaustEmitter();
}

function RangedAttack(Actor A) {
    if ( bShotAnim || Physics == PHYS_Swimming)
        return;
    else if ( CanAttack(A) && AdvSawZombieController(Controller).bFacingTarget) {
        bShotAnim = true;
        SetAnimAction(MeleeAnims[Rand(2)]);
        CurrentDamType = ZombieDamType[0];
        //PlaySound(sound'Claw2s', SLOT_None); KFTODO: Replace this
        Controller.GoToState('WaitForAnim');
        KFMonsterController(Controller).Focus = none;
        KFMonsterController(Controller).FocalPoint = KFMonsterController(Controller).LastSeenPos;
        KFMonsterController(Controller).bUseFreezeHack = true;
    }

    if( !bShotAnim && !bDecapitated ) {
        if ( Level.Game.GameDifficulty < 5.0 ) {
            if ( float(Health)/HealthMax < 0.5 )
                GoToState('RunningState');
        } else {
            if ( float(Health)/HealthMax < 0.75 ) {
                GoToState('RunningState');
            }
        }
    }
}

function bool MeleeDamageTarget(int hitdamage, vector pushdir) {
    local vector HitLocation, HitNormal;
    local actor HitActor;
    local Name TearBone;
    local float dummy;
    local Emitter BloodHit;
    //local vector TraceDir;


    if( Level.NetMode==NM_Client || Controller==None ) {
        Return False; // Never should be done on client.
    }

    if ( Controller.Target!=none && Controller.Target.IsA('KFDoorMover')) {
        Controller.Target.TakeDamage(hitdamage, self ,HitLocation,pushdir, CurrentDamType);
        Return True;
    }

    if (AdvSawZombieController(Controller).RelativeDir < 30) {
        return false;
    }
    /*ClearStayingDebugLines();

    TraceDir = Normal(Controller.Target.Location - Location);

    DrawStayingDebugLine(Location, Location + (TraceDir * (MeleeRange * 1.4 + Controller.Target.CollisionRadius + CollisionRadius)) , 255,255,0);*/

    // check if still in melee range
    if ( (Controller.target != None) && (bSTUNNED == false) && (DECAP == false) && 
        (VSize(Controller.Target.Location - Location) <= MeleeRange * 1.4 + Controller.Target.CollisionRadius + CollisionRadius) &&
        ((Physics == PHYS_Flying) || (Physics == PHYS_Swimming) || (Abs(Location.Z - Controller.Target.Location.Z)
        <= FMax(CollisionHeight, Controller.Target.CollisionHeight) + 0.5 * FMin(CollisionHeight, Controller.Target.CollisionHeight))) ) {

        bBlockHitPointTraces = false;
        HitActor = Trace(HitLocation, HitNormal, Controller.Target.Location , Location + EyePosition(), true);
        bBlockHitPointTraces = true;

        // If the trace wouldn't hit a pawn, do the old thing of just checking if there is something blocking the trace
        if( Pawn(HitActor) == none ) {
            // Have to turn of hit point collision so trace doesn't hit the Human Pawn's bullet whiz cylinder
            bBlockHitPointTraces = false;
            HitActor = Trace(HitLocation, HitNormal, Controller.Target.Location, Location, false);
            bBlockHitPointTraces = true;

            if ( HitActor != None ) {
                return false;
            }
        }

        if ( KFHumanPawn(Controller.Target) != none ) {
            //TODO - line below was KFPawn. Does this whole block need to be KFPawn, or is it OK as KFHumanPawn?
            KFHumanPawn(Controller.Target).TakeDamage(hitdamage, Instigator ,HitLocation,pushdir, CurrentDamType); //class 'KFmod.ZombieMeleeDamage');

            if (KFHumanPawn(Controller.Target).Health <=0) {
                if ( !class'GameInfo'.static.UseLowGore() ) {
                    BloodHit = Spawn(class'KFMod.FeedingSpray',self,,Controller.Target.Location,rotator(pushdir));	 //
                    KFHumanPawn(Controller.Target).SpawnGibs(rotator(pushdir), 1);
                    TearBone=KFPawn(Controller.Target).GetClosestBone(HitLocation,Velocity,dummy);
                    KFHumanPawn(Controller.Target).HideBone(TearBone);
                }

                // Give us some Health back
                if (Health <= (1.0-FeedThreshold)*HealthMax) {
                    Health += FeedThreshold*HealthMax * Health/HealthMax;
                }
            }

        }
        else if (Controller.target != None)
        {
            // Do more damage if you are attacking another zed so that zeds don't just stand there whacking each other forever! - Ramm
            if( KFMonster(Controller.Target) != none )
            {
                hitdamage *= DamageToMonsterScale;
            }

            Controller.Target.TakeDamage(hitdamage, self ,HitLocation,pushdir, CurrentDamType); //class 'KFmod.ZombieMeleeDamage');
        }

        return true;
    }

    return false;
}

state RunningState {
    // Set the zed to the zapped behavior
    simulated function SetZappedBehavior() {
        Global.SetZappedBehavior();
        GoToState('');
    }

    // Don't override speed in this state
    function bool CanSpeedAdjust() {
        return false;
    }

    function BeginState() {
        if( bZapped ) {
            GoToState('');
        } else {
            SetGroundSpeed(OriginalGroundSpeed * 3.5);
            bCharging = true;
            if( Level.NetMode!=NM_DedicatedServer ) {
                PostNetReceive();
            }

            NetUpdateTime = Level.TimeSeconds - 1;
        }
    }

    function EndState() {
        if( !bZapped ) {
            SetGroundSpeed(GetOriginalGroundSpeed());
        }
        bCharging = False;
        if( Level.NetMode!=NM_DedicatedServer ) {
            PostNetReceive();
        }
        
    }

    function RemoveHead() {
        GoToState('');
        Global.RemoveHead();
    }

    function RangedAttack(Actor A) {
        if ( bShotAnim || Physics == PHYS_Swimming)
            return;
        else if ( CanAttack(A) ) {
            bShotAnim = true;
            SetAnimAction(MeleeAnims[Rand(2)]);
            CurrentDamType = ZombieDamType[0];
            GoToState('SawingLoop');
        }
    }
}

state RunningToMarker extends RunningState {
}

State SawingLoop {
    // Don't override speed in this state
    function bool CanSpeedAdjust() {
        return false;
    }

    function bool CanGetOutOfWay() {
        return false;
    }

    function BeginState() {
        local float ChargeChance, RagingChargeChance;

        // Decide what chance the scrake has of charging during an attack
        if( Level.Game.GameDifficulty < 2.0 ) {
            ChargeChance = 0.25;
            RagingChargeChance = 0.5;
        } else if( Level.Game.GameDifficulty < 4.0 ) {
            ChargeChance = 0.5;
            RagingChargeChance = 0.70;
        } else if( Level.Game.GameDifficulty < 5.0 ) {
            ChargeChance = 0.65;
            RagingChargeChance = 0.85;
        }
        else { // Hardest difficulty
            ChargeChance = 0.95;
            RagingChargeChance = 1.0;
        }

        // Randomly have the scrake charge during an attack so it will be less predictable
        if( (Health/HealthMax < 0.5 && FRand() <= RagingChargeChance ) || FRand() <= ChargeChance ) {
            SetGroundSpeed(OriginalGroundSpeed * AttackChargeRate);
            bCharging = true;
            if( Level.NetMode!=NM_DedicatedServer ) {
                PostNetReceive();
            }

            NetUpdateTime = Level.TimeSeconds - 1;
        }
    }

    function RangedAttack(Actor A) {
        if ( bShotAnim )
            return;
        else if ( CanAttack(A) ) {
            Acceleration = vect(0,0,0);
            bShotAnim = true;
            MeleeDamage = default.MeleeDamage*0.6;
            SetAnimAction('SawImpaleLoop');
            CurrentDamType = ZombieDamType[0];
            if( AmbientSound != SawAttackLoopSound ) {
                AmbientSound=SawAttackLoopSound;
            }
        }
        else GoToState('');
    }

    function AnimEnd( int Channel ) {
        Super.AnimEnd(Channel);
        if( Controller!=None && Controller.Enemy!=None ) {
            RangedAttack(Controller.Enemy); // Keep on attacking if possible.
        }
    }

    function Tick( float Delta ) {
        // Keep the scrake moving toward its target when attacking
        if( Role == ROLE_Authority && bShotAnim && !bWaitForAnim ) {
            if( LookTarget!=None ) {
                Acceleration = AccelRate * Normal(LookTarget.Location - Location);
            }
        }

        global.Tick(Delta);
    }

    function EndState() {
        AmbientSound=default.AmbientSound;
        MeleeDamage = Max( DifficultyDamageModifer() * default.MeleeDamage, 1 );

        SetGroundSpeed(GetOriginalGroundSpeed());
        bCharging = False;
        if( Level.NetMode!=NM_DedicatedServer ) {
            PostNetReceive();
        }
    }
}

// Added in Balance Round 1 to reduce the headshot damage taken from Crossbows
function TakeDamage( int Damage, Pawn InstigatedBy, Vector Hitlocation, Vector Momentum, class<DamageType> damageType, optional int HitIndex) {
    local bool bIsHeadShot;
    local PlayerController PC;
    local KFSteamStatsAndAchievements Stats;

    bIsHeadShot = IsHeadShot(Hitlocation, normal(Momentum), 1.0);

    if ( Level.Game.GameDifficulty >= 5.0 && bIsHeadshot && (class<DamTypeCrossbow>(damageType) != none || class<DamTypeCrossbowHeadShot>(damageType) != none) ) {
        Damage *= 0.5; // Was 0.5 in Balance Round 1, then 0.6 in Round 2, back to 0.5 in Round 3
    }

    Super.takeDamage(Damage, instigatedBy, hitLocation, momentum, damageType, HitIndex);

    // Added in Balance Round 3 to make the Scrake "Rage" more reliably when his health gets low(limited to Suicidal and HoE in Round 7)
    if ( Level.Game.GameDifficulty >= 5.0 && !IsInState('SawingLoop') && !IsInState('RunningState') && float(Health) / HealthMax < 0.75 ) {
        RangedAttack(InstigatedBy);
    }

    if( damageType == class'DamTypeDBShotgun' ) {
        PC = PlayerController( InstigatedBy.Controller );
        if( PC != none ) {
            Stats = KFSteamStatsAndAchievements( PC.SteamStatsAndAchievements );
            if( Stats != none ) {
                Stats.CheckAndSetAchievementComplete( Stats.KFACHIEVEMENT_PushScrakeSPJ );
            }
        }
    }
}

function PlayTakeHit(vector HitLocation, int Damage, class<DamageType> DamageType) {
    local int StunChance;

    StunChance = rand(5);

    if( Level.TimeSeconds - LastPainAnim < MinTimeBetweenPainAnims )
        return;

    if( (Level.Game.GameDifficulty < 5.0 || StunsRemaining != 0) && (Damage>=150 || (DamageType.name=='DamTypeStunNade' && StunChance>3) || (DamageType.name=='DamTypeCrossbowHeadshot' && Damage>=200)) ) {
        PlayDirectionalHit(HitLocation);
    }

    LastPainAnim = Level.TimeSeconds;

    if( Level.TimeSeconds - LastPainSound < MinTimeBetweenPainSounds )
        return;

    LastPainSound = Level.TimeSeconds;
    PlaySound(HitSound[0], SLOT_Pain,1.25,,400);
}

simulated function int DoAnimAction( name AnimName ) {
    if( AnimName=='SawZombieAttack1' || AnimName=='SawZombieAttack2' ) {
        AnimBlendParams(1, 1.0, 0.0,, FireRootBone);
        PlayAnim(AnimName,, 0.1, 1);
        Return 1;
    }
    Return Super.DoAnimAction(AnimName);
}

simulated event SetAnimAction(name NewAction) {
    local int meleeAnimIndex;

    if( NewAction=='' )
        Return;
    if(NewAction == 'Claw') {
        meleeAnimIndex = Rand(3);
        NewAction = meleeAnims[meleeAnimIndex];
        CurrentDamtype = ZombieDamType[meleeAnimIndex];
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

// The animation is full body and should set the bWaitForAnim flag
simulated function bool AnimNeedsWait(name TestAnim) {
    if( TestAnim == 'SawImpaleLoop' || TestAnim == 'DoorBash' || TestAnim == 'KnockDown' ) {
        return true;
    }

    return false;
}

function PlayDyingSound()
{
    if( Level.NetMode!=NM_Client ) {
        if ( bGibbed ) {
            // Do nothing for now
            PlaySound(GibGroupClass.static.GibSound(), SLOT_Pain,2.0,true,525);
            return;
        }

        if( bDecapitated ) {
            PlaySound(HeadlessDeathSound, SLOT_Pain,1.30,true,525);
        } else {
            PlaySound(DeathSound[0], SLOT_Pain,1.30,true,525);
        }

        PlaySound(ChainSawOffSound, SLOT_Misc, 2.0,,525.0);
    }
}

function Died(Controller Killer, class<DamageType> damageType, vector HitLocation) {
    AmbientSound = none;

    if ( ExhaustEffect != none ) {
        ExhaustEffect.Destroy();
        ExhaustEffect = none;
        bNoExhaustRespawn = true;
    }

    super.Died( Killer, damageType, HitLocation );
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
                    if( !bLeftArmGibbed ) {
                        SpawnSeveredGiblet( DetachedArmClass, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, GetBoneRotation(HitFX[SimHitFxTicker].bone) );
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrainb',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;;
                        bLeftArmGibbed=true;
                    }
                    break;

                case RightFArmBone:
                    if( !bRightArmGibbed ) {
                        SpawnSeveredGiblet( DetachedSpecialArmClass, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, GetBoneRotation(HitFX[SimHitFxTicker].bone) );
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrainb',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        bRightArmGibbed=true;
                    }
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
                HitFX[SimHitFXTicker].bone != 'head' && Health <=0 ) {
                HideBone(HitFX[SimHitFxTicker].bone);
            }
        }
    }
}

// Maybe spawn some chunks when the player gets obliterated
simulated function SpawnGibs(Rotator HitRotation, float ChunkPerterbation) {
    if ( ExhaustEffect != none ) {
        ExhaustEffect.Destroy();
        ExhaustEffect = none;
        bNoExhaustRespawn = true;
    }

    super.SpawnGibs(HitRotation,ChunkPerterbation);
}

static simulated function PreCacheMaterials(LevelInfo myLevel) {
    myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T.scrake_env_cmb');
    myLevel.AddPrecacheMaterial(Texture'KF_Specimens_Trip_T.scrake_diff');
    myLevel.AddPrecacheMaterial(Texture'KF_Specimens_Trip_T.scrake_spec');
    myLevel.AddPrecacheMaterial(Material'KF_Specimens_Trip_T.scrake_saw_panner');
    myLevel.AddPrecacheMaterial(Material'KF_Specimens_Trip_T.scrake_FB');
    myLevel.AddPrecacheMaterial(Texture'KF_Specimens_Trip_T.Chainsaw_blade_diff');
}

defaultproperties {
    DetachedArmClass=class'SeveredArmScrake'
    DetachedSpecialArmClass=class'SeveredArmScrakeSaw'
    DetachedLegClass=class'SeveredLegScrake'
    DetachedHeadClass=class'SeveredHeadScrake'

    Mesh=SkeletalMesh'KF_Freaks_Trip.Scrake_Freak'

    Skins(0)=Shader'KF_Specimens_Trip_T.scrake_FB'
    Skins(1)=TexPanner'KF_Specimens_Trip_T.scrake_saw_panner'

    AmbientSound=Sound'KF_BaseScrake.Scrake_Chainsaw_Idle'
    MoanVoice=Sound'KF_EnemiesFinalSnd.Scrake_Talk'
    JumpSound=Sound'KF_EnemiesFinalSnd.Scrake_Jump'
    MeleeAttackHitSound=Sound'KF_EnemiesFinalSnd.Scrake_Chainsaw_HitPlayer'

    HitSound(0)=Sound'KF_EnemiesFinalSnd.Scrake_Pain'
    DeathSound(0)=Sound'KF_EnemiesFinalSnd.Scrake_Death'

    ChallengeSound(0)=Sound'KF_EnemiesFinalSnd.Scrake_Challenge'
    ChallengeSound(1)=Sound'KF_EnemiesFinalSnd.Scrake_Challenge'
    ChallengeSound(2)=Sound'KF_EnemiesFinalSnd.Scrake_Challenge'
    ChallengeSound(3)=Sound'KF_EnemiesFinalSnd.Scrake_Challenge'

    SawAttackLoopSound=Sound'KF_BaseScrake.Scrake_Chainsaw_Impale'
    ChainSawOffSound=Sound'KF_ChainsawSnd.Chainsaw_Deselect'
    DrawScale=1.05
    Prepivot=(Z=3.0)

    bMeleeStunImmune = true

    MeleeAnims(0)="SawZombieAttack1"
    MeleeAnims(1)="SawZombieAttack2"
    MeleeDamage=20
    damageForce=-75000//-400000
    KFRagdollName="Scrake_Trip"

    ScoringValue=75
    IdleHeavyAnim="SawZombieIdle"
    IdleRifleAnim="SawZombieIdle"
    MeleeRange=40.0//60.000000
    GroundSpeed=85.000000
    WaterSpeed=75.000000
    //StunTime=0.3 Was used in Balance Round 1(removed for Round 2)
    StunsRemaining=1 //Added in Balance Round 2
    Health=1000//1500
    HealthMax=1000
    PlayerCountHealthScale=0.5
    PlayerNumHeadHealthScale=0.30 // Was 0.35 in Balance Round 1
    HeadHealth=650
    MovementAnims(0)="SawZombieWalk"
    MovementAnims(1)="SawZombieWalk"
    MovementAnims(2)="SawZombieWalk"
    MovementAnims(3)="SawZombieWalk"
    WalkAnims(0)="SawZombieWalk"
    WalkAnims(1)="SawZombieWalk"
    WalkAnims(2)="SawZombieWalk"
    WalkAnims(3)="SawZombieWalk"
    IdleCrouchAnim="SawZombieIdle"
    IdleWeaponAnim="SawZombieIdle"
    IdleRestAnim="SawZombieIdle"


    AmbientGlow=0
    bFatAss=True
    Mass=500.000000
    RotationRate=(Yaw=0,Roll=0)

    bCannibal = false
    MenuName="Scrake"

    CollisionRadius=26
    CollisionHeight=44

    SoundVolume=175
    SoundRadius=100.0


    Intelligence=BRAINS_Mammal
    bUseExtendedCollision=True
    ColOffset=(Z=55)
    ColRadius=29
    ColHeight=18
    ZombieFlag=3

    SeveredHeadAttachScale=1.0
    SeveredLegAttachScale=1.1
    SeveredArmAttachScale=1.1
    BleedOutDuration=6.0
    PoundRageBumpDamScale=0.01
    HeadHeight=2.2
    HeadScale=1.1
    AttackChargeRate=2.5

    ExhaustEffectClass=class'KFMOD.ChainSawExhaust'
    OnlineHeadshotOffset=(X=22,Y=5,Z=58)
    OnlineHeadshotScale=1.5
    MotionDetectorThreat=3.0
    ZapThreshold=1.25
    ZappedDamageMod=1.25

    DamageToMonsterScale=8.0
    bHarpoonToHeadStuns=true
    bHarpoonToBodyStuns=false
    ControllerClass=Class'KFAdvZeds.AdvSawZombieController'
}