/*
 * Modified Husk - uses new attacks based on distance and difficulty!
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : MIT
 * Copyright    : 2023 theengineertcr
*/
class AdvZombieHusk extends AdvZombieHuskBase
    abstract;


// Package Loading
#exec OBJ LOAD FILE=KFAdvZeds_A.ukx


//----------------------------------------------------------------------------
// NOTE: All Variables are declared in the base class to eliminate hitching
//----------------------------------------------------------------------------


// HuskFireProjClass to "AdvHuskFireProjClass"
// Subsequent mentions have been modified as well
var class<Projectile> AdvHuskFireProjClass;


// New class variable for the flamethrower attack projectile
var class<Projectile> AdvHuskFlameProjClass;


// Config Variables
var bool bEnableHuskMoveAndShoot;
var bool bEnableHuskFlamethrower;
var bool bEnableHuskFlameAndMove;
var bool bIgnoreDifficulty;


simulated function BeginPlay()
{
    //Link the mesh to our custom animations
    LinkSkelAnim(MeshAnimation'AdvBurns_Anim');
    Super.BeginPlay();
}


simulated function PostBeginPlay()
{
    // Difficulty Scaling, same as default
    if (Level.Game != none && !bDiffAdjusted)
    {
        if( Level.Game.GameDifficulty < 2.0 )
        {
            ProjectileFireInterval = default.ProjectileFireInterval * 1.25;
            BurnDamageScale = default.BurnDamageScale * 2.0;
        }
        else if( Level.Game.GameDifficulty < 4.0 )
        {
            ProjectileFireInterval = default.ProjectileFireInterval * 1.0;
            BurnDamageScale = default.BurnDamageScale * 1.0;
        }
        else if( Level.Game.GameDifficulty < 5.0 )
        {
            ProjectileFireInterval = default.ProjectileFireInterval * 0.75;
            BurnDamageScale = default.BurnDamageScale * 0.75;
        }
        else // Hardest difficulty
        {
            ProjectileFireInterval = default.ProjectileFireInterval * 0.60;
            BurnDamageScale = default.BurnDamageScale * 0.5;
        }
    }

    super.PostBeginPlay();
}


// don't interrupt the husk while he is shooting
simulated function bool HitCanInterruptAction()
{
    if( bShotAnim )
    {
        return false;
    }

    return true;
}


function DoorAttack(Actor A)
{
    if ( bShotAnim || Physics == PHYS_Swimming)
        return;
    else if ( A!=None )
    {
        bShotAnim = true;
        if( !bDecapitated && bDistanceAttackingDoor )
        {
            SetAnimAction('ShootBurns');
        }
        else
        {
            SetAnimAction('DoorBash');
            GotoState('DoorBashing');
        }
    }
}


function RangedAttack(Actor A)
{
    // Additional local variable "ChargeChance"
    // Used to determine the chance for a Husk to
    // Shoot while charging towards their victim
    local int LastFireTime;
    local float ChargeChance;


    // Ditto but for the flamethrower attack
    local float FlamingChargeChance;


    if ( bShotAnim )
        return;

    if ( Physics == PHYS_Swimming )
    {
        SetAnimAction('Claw');
        bShotAnim = true;
        LastFireTime = Level.TimeSeconds;
    }
    else if ( VSize(A.Location - Location) < MeleeRange + CollisionRadius + A.CollisionRadius )
    {
        bShotAnim = true;
        LastFireTime = Level.TimeSeconds;
        SetAnimAction('Claw');
        //PlaySound(sound'Claw2s', SLOT_Interact); KFTODO: Replace this
        Controller.bPreparingMove = true;
        Acceleration = vect(0,0,0);
    }
    else if ( (KFDoorMover(A) != none ||
        (!Region.Zone.bDistanceFog && VSize(A.Location-Location) <= 65535) ||
        (Region.Zone.bDistanceFog && VSizeSquared(A.Location-Location) < (Square(Region.Zone.DistanceFogEnd) * 0.8)))  // Make him come out of the fog a bit
        && !bDecapitated )
    {
        // Decide what chance the Husk has of charging during a ranged attack
        if( Level.Game.GameDifficulty < 4.0 )
        {
            ChargeChance = 0.33;
            FlamingChargeChance = 0.05;
        }
        else if( Level.Game.GameDifficulty < 5.0 )
        {
            ChargeChance = 0.55;
            FlamingChargeChance = 0.05;
        }
        else // Hardest difficulty
        {
            ChargeChance = 0.85;
            FlamingChargeChance = 0.33;
        }

        if( FRand() < FlamingChargeChance && (Level.Game.GameDifficulty >= 5.0 || bIgnoreDifficulty) && VSize(A.Location-Location) <= 600 && bEnableHuskFlamethrower && bEnableHuskFlameAndMove)
        {
            SetAnimAction('MovingAndBurning');
            RunAttackTimeout = GetAnimDuration('SprayBurnsMove', 1.0);
            bMovingRangedAttack=true;
        }
        else if((Level.Game.GameDifficulty >= 5.0  || bIgnoreDifficulty) && VSize(A.Location-Location) <= 600 && bEnableHuskFlamethrower)
        {
            SetAnimAction('SprayBurns');
            Controller.bPreparingMove = true;
            Acceleration = vect(0,0,0);
        }
        else if( FRand() < ChargeChance && (Level.Game.GameDifficulty >= 4.0 || bIgnoreDifficulty) && bEnableHuskMoveAndShoot)
        {
            SetAnimAction('MovingAndShooting');
            RunAttackTimeout = GetAnimDuration('ShootBurnsMove', 1.0);
            bMovingRangedAttack=true;
        }
        else
        {
            SetAnimAction('ShootBurns');
            Controller.bPreparingMove = true;
            Acceleration = vect(0,0,0);
        }

        bShotAnim = true;

        NextFireProjectileTime = Level.TimeSeconds + ProjectileFireInterval + (FRand() * 2.0);
    }
}

// Overridden to handle playing upper body only attacks when moving
simulated event SetAnimAction(name NewAction)
{
    local int meleeAnimIndex;
    local bool bWantsToShootAndMove;
    local bool bWantsToBurnAndMove;

    if( NewAction=='' )
        Return;

    bWantsToShootAndMove = NewAction == 'MovingAndShooting';
    bWantsToBurnAndMove = NewAction == 'MovingAndBurning';

    if( NewAction == 'Claw' )
    {
        meleeAnimIndex = Rand(3);
        NewAction = meleeAnims[meleeAnimIndex];
        CurrentDamtype = ZombieDamType[meleeAnimIndex];
    }
    else if( NewAction == 'DoorBash' )
    {
       CurrentDamtype = ZombieDamType[Rand(3)];
    }

    // If they want to shoot and move, use the expected channel
    if( bWantsToShootAndMove || bWantsToBurnAndMove )
    {
       ExpectingChannel = AttackAndMoveDoAnimAction(NewAction);
    }
    else
    {
       ExpectingChannel = DoAnimAction(NewAction);
    }

    if( !bWantsToShootAndMove && AnimNeedsWait(NewAction) || !bWantsToBurnAndMove && AnimNeedsWait(NewAction))
    {
        bWaitForAnim = true;
    }
    else
    {
        bWaitForAnim = false;
    }

    if( Level.NetMode!=NM_Client )
    {
        AnimAction = NewAction;
        bResetAnimAct = True;
        ResetAnimActTime = Level.TimeSeconds+0.3;
    }
}

// Handle playing the anim action on the upper body only if we're attacking and moving
simulated function int AttackAndMoveDoAnimAction( name AnimName )
{
    if( AnimName=='MovingAndShooting' )
    {
        AnimBlendParams(1, 1.0, 0.0,, FireRootBone);
        PlayAnim('ShootBurnsMove',, 0.1, 1);

        return 1;
    }

    if( AnimName=='MovingAndBurning' )
    {
        AnimBlendParams(1, 1.0, 0.0,, FireRootBone);
        PlayAnim('SprayBurnsMove',, 0.1, 1);

        return 1;
    }

    return super.DoAnimAction( AnimName );
}

function SpawnTwoShots()
{
    local vector X,Y,Z, FireStart;
    local rotator FireRotation;
    local KFMonsterController KFMonstControl;


    if( Controller!=None && KFDoorMover(Controller.Target)!=None )
    {
        Controller.Target.TakeDamage(22,Self,Location,vect(0,0,0),Class'DamTypeVomit');
        return;
    }

    GetAxes(Rotation,X,Y,Z);
    FireStart = GetBoneCoords('Barrel').Origin;
    // Use the Advanced Husks's Projectile
    AdvHuskFireProjClass = Class'AdvHuskFireProjectile';
    if ( !SavedFireProperties.bInitialized )
    {
        SavedFireProperties.AmmoClass = Class'SkaarjAmmo';
        SavedFireProperties.ProjectileClass = AdvHuskFireProjClass;
        SavedFireProperties.WarnTargetPct = 1;
        SavedFireProperties.MaxRange = 65535;
        SavedFireProperties.bTossed = False;
        SavedFireProperties.bTrySplash = true;
        SavedFireProperties.bLeadTarget = True;
        SavedFireProperties.bInstantHit = False;
        SavedFireProperties.bInitialized = True;
    }

    // Turn off extra collision before spawning vomit, otherwise spawn fails
    ToggleAuxCollision(false);

    FireRotation = Controller.AdjustAim(SavedFireProperties,FireStart,600);

    foreach DynamicActors(class'KFMonsterController', KFMonstControl)
    {
        if( KFMonstControl != Controller )
        {
            if( PointDistToLine(KFMonstControl.Pawn.Location, vector(FireRotation), FireStart) < 75 )
            {
                KFMonstControl.GetOutOfTheWayOfShot(vector(FireRotation),FireStart);
            }
        }
    }

    Spawn(AdvHuskFireProjClass,,,FireStart,FireRotation);

    // Turn extra collision back on
    ToggleAuxCollision(true);
}

// Shoot out flames!
function SpawnFlameShots()
{
    local vector X,Y,Z, FireStart;
    local rotator FireRotation;
    local KFMonsterController KFMonstControl;


    if( Controller!=None && KFDoorMover(Controller.Target)!=None )
    {
        Controller.Target.TakeDamage(22,Self,Location,vect(0,0,0),Class'DamTypeVomit');
        return;
    }

    GetAxes(Rotation,X,Y,Z);
    FireStart = GetBoneCoords('Barrel').Origin;
    // Use the FlameTendril
    AdvHuskFlameProjClass = Class'AdvHuskFlameProjectile';
    if ( !SavedFireProperties.bInitialized )
    {
        SavedFireProperties.AmmoClass = Class'SkaarjAmmo';
        SavedFireProperties.ProjectileClass = AdvHuskFlameProjClass;
        SavedFireProperties.WarnTargetPct = 1;
        SavedFireProperties.MaxRange = 65535;
        SavedFireProperties.bTossed = False;
        SavedFireProperties.bTrySplash = true;
        SavedFireProperties.bLeadTarget = True;
        SavedFireProperties.bInstantHit = False;
        SavedFireProperties.bInitialized = True;
    }

    // Turn off extra collision before spawning vomit, otherwise spawn fails
    ToggleAuxCollision(false);

    FireRotation = Controller.AdjustAim(SavedFireProperties,FireStart,600);

    foreach DynamicActors(class'KFMonsterController', KFMonstControl)
    {
        if( KFMonstControl != Controller )
        {
            if( PointDistToLine(KFMonstControl.Pawn.Location, vector(FireRotation), FireStart) < 75 )
            {
                KFMonstControl.GetOutOfTheWayOfShot(vector(FireRotation),FireStart);
            }
        }
    }

    Spawn(AdvHuskFlameProjClass,,,FireStart,FireRotation);

    // Turn extra collision back on
    ToggleAuxCollision(true);
}

// Get the closest point along a line to another point
simulated function float PointDistToLine(vector Point, vector Line, vector Origin, optional out vector OutClosestPoint)
{
    local vector SafeDir;

    SafeDir = Normal(Line);
    OutClosestPoint = Origin + (SafeDir * ((Point-Origin) dot SafeDir));
    return VSize(OutClosestPoint-Point);
}

simulated function Tick(float deltatime)
{
    Super.tick(deltatime);

    if( Role == ROLE_Authority && bMovingRangedAttack )
    {
        // Keep moving toward the target until the timer runs out (anim finishes)
        if( RunAttackTimeout > 0 )
        {
            RunAttackTimeout -= DeltaTime;

            if( RunAttackTimeout <= 0 )
            {
                RunAttackTimeout = 0;
                bMovingRangedAttack=false;
            }
        }

        // Keep the gorefast moving toward its target when attacking
        if( bShotAnim && !bWaitForAnim )
        {
            if( LookTarget!=None )
            {
                Acceleration = AccelRate * Normal(LookTarget.Location - Location);
            }
        }
    }

    // Hack to force animation updates on the server for the Fleshpound if he is relevant to someone
    // He has glitches when some of his animations don't play on the server. If we
    // find some other fix for the glitches take this out - Ramm
    if( Level.NetMode != NM_Client && Level.NetMode != NM_Standalone )
    {
        if( (Level.TimeSeconds-LastSeenOrRelevantTime) < 1.0  )
        {
            bForceSkelUpdate=true;
        }
        else
        {
            bForceSkelUpdate=false;
        }
    }
}

function RemoveHead()
{
    bCanDistanceAttackDoors = False;
    Super.RemoveHead();
}

function TakeDamage( int Damage, Pawn InstigatedBy, Vector Hitlocation, Vector Momentum, class<DamageType> damageType, optional int HitIndex)
{
    // Reduced damage from fire
    if (DamageType == class 'DamTypeBurned' || DamageType == class 'DamTypeFlamethrower')
    {
        Damage *= BurnDamageScale;
    }

    Super.TakeDamage(Damage,instigatedBy,hitlocation,momentum,damageType,HitIndex);
}

simulated function ProcessHitFX()
{
    local Coords boneCoords;
    local class<xEmitter> HitEffects[4];
    local int i,j;
    local float GibPerterbation;

    if( (Level.NetMode == NM_DedicatedServer) || bSkeletized || (Mesh == SkeletonMesh))
    {
        SimHitFxTicker = HitFxTicker;
        return;
    }

    for ( SimHitFxTicker = SimHitFxTicker; SimHitFxTicker != HitFxTicker; SimHitFxTicker = (SimHitFxTicker + 1) % ArrayCount(HitFX) )
    {
        j++;
        if ( j > 30 )
        {
            SimHitFxTicker = HitFxTicker;
            return;
        }

        if( (HitFX[SimHitFxTicker].damtype == None) || (Level.bDropDetail && (Level.TimeSeconds - LastRenderTime > 3) && !IsHumanControlled()) )
            continue;

        //log("Processing effects for damtype "$HitFX[SimHitFxTicker].damtype);

        if( HitFX[SimHitFxTicker].bone == 'obliterate' && !class'GameInfo'.static.UseLowGore())
        {
            SpawnGibs( HitFX[SimHitFxTicker].rotDir, 1);
            bGibbed = true;
            // Wait a tick on a listen server so the obliteration can replicate before the pawn is destroyed
            if( Level.NetMode == NM_ListenServer )
            {
                bDestroyNextTick = true;
                TimeSetDestroyNextTickTime = Level.TimeSeconds;
            }
            else
            {
                Destroy();
            }
            return;
        }

        boneCoords = GetBoneCoords( HitFX[SimHitFxTicker].bone );

        if ( !Level.bDropDetail && !class'GameInfo'.static.NoBlood() && !bSkeletized && !class'GameInfo'.static.UseLowGore() )
        {
            //AttachEmitterEffect( BleedingEmitterClass, HitFX[SimHitFxTicker].bone, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir );

            HitFX[SimHitFxTicker].damtype.static.GetHitEffects( HitEffects, Health );

            if( !PhysicsVolume.bWaterVolume ) // don't attach effects under water
            {
                for( i = 0; i < ArrayCount(HitEffects); i++ )
                {
                    if( HitEffects[i] == None )
                        continue;

                      AttachEffect( HitEffects[i], HitFX[SimHitFxTicker].bone, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir );
                }
            }
        }
        if ( class'GameInfo'.static.UseLowGore() )
            HitFX[SimHitFxTicker].bSever = false;

        if( HitFX[SimHitFxTicker].bSever )
        {
            GibPerterbation = HitFX[SimHitFxTicker].damtype.default.GibPerterbation;

            switch( HitFX[SimHitFxTicker].bone )
            {
                case 'obliterate':
                    break;

                case LeftThighBone:
                    if( !bLeftLegGibbed )
                    {
                        SpawnSeveredGiblet( DetachedLegClass, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, GetBoneRotation(HitFX[SimHitFxTicker].bone) );
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrainb',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        bLeftLegGibbed=true;
                    }
                    break;

                case RightThighBone:
                    if( !bRightLegGibbed )
                    {
                        SpawnSeveredGiblet( DetachedLegClass, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, GetBoneRotation(HitFX[SimHitFxTicker].bone) );
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrainb',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        bRightLegGibbed=true;
                    }
                    break;

                case LeftFArmBone:
                    if( !bLeftArmGibbed )
                    {
                        SpawnSeveredGiblet( DetachedArmClass, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, GetBoneRotation(HitFX[SimHitFxTicker].bone) );
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrainb',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;;
                        bLeftArmGibbed=true;
                    }
                    break;

                case RightFArmBone:
                    if( !bRightArmGibbed )
                    {
                        SpawnSeveredGiblet( DetachedSpecialArmClass, boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, GetBoneRotation(HitFX[SimHitFxTicker].bone) );
                        KFSpawnGiblet( class 'KFMod.KFGibBrain',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        KFSpawnGiblet( class 'KFMod.KFGibBrainb',boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, GibPerterbation, 250 ) ;
                        bRightArmGibbed=true;
                    }
                    break;

                case 'head':
                    if( !bHeadGibbed )
                    {
                        if ( HitFX[SimHitFxTicker].damtype == class'DamTypeDecapitation' )
                        {
                            DecapFX( boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, false);
                        }
                        else if( HitFX[SimHitFxTicker].damtype == class'DamTypeProjectileDecap' )
                        {
                            DecapFX( boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, false, true);
                        }
                        else if( HitFX[SimHitFxTicker].damtype == class'DamTypeMeleeDecapitation' )
                        {
                            DecapFX( boneCoords.Origin, HitFX[SimHitFxTicker].rotDir, true);
                        }

                          bHeadGibbed=true;
                      }
                    break;
            }


            if( HitFX[SimHitFXTicker].bone != 'Spine' && HitFX[SimHitFXTicker].bone != FireRootBone &&
                HitFX[SimHitFXTicker].bone != 'head' && Health <=0 )
                HideBone(HitFX[SimHitFxTicker].bone);
        }
    }
}

// New Hit FX for Zombies!
function PlayHit(float Damage, Pawn InstigatedBy, vector HitLocation, class<DamageType> damageType, vector Momentum, optional int HitIdx )
{
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
    OldPlayHit(Damage, InstigatedBy, HitLocation, DamageType,Momentum);

    if ( Damage <= 0 )
        return;

    if( Health>0 && Damage>(float(Default.Health)/1.5) )
    {
        FlipOver();
    }
    else if( Health > 0 && (damageType == class'DamTypeCrossbow' || damageType == class'DamTypeCrossbowHeadShot' ||
         damageType == class'DamTypeWinchester' || damageType == class'DamTypeM14EBR'
         || damageType == class'DamTypeM99HeadShot' || damageType == class'DamTypeM99SniperRifle'
         || damageType == class'DamTypeSPSniper' )
         &&  Damage > 200 ) // 200 Damage will be a headshot with the Winchester or EBR, or a hit with the Crossbow
    {
        FlipOver();
    }

    PC = PlayerController(Controller);
    bShowEffects = ( (Level.NetMode != NM_Standalone) || (Level.TimeSeconds - LastRenderTime < 2.5)
                    || ((InstigatedBy != None) && (PlayerController(InstigatedBy.Controller) != None))
                    || (PC != None) );
    if ( !bShowEffects )
        return;

    if ( BurnDown > 0 && !bBurnified )
    {
        bBurnified = true;
    }

    HitRay = vect(0,0,0);
    if( InstigatedBy != None )
        HitRay = Normal(HitLocation-(InstigatedBy.Location+(vect(0,0,1)*InstigatedBy.EyeHeight)));

    if( DamageType.default.bLocationalHit )
    {
        CalcHitLoc( HitLocation, HitRay, HitBone, HitBoneDist );

        // Do a zapped effect is someone shoots us and we're zapped to help show that the zed is taking more damage
        if ( bZapped && DamageType.name != 'DamTypeZEDGun' )
        {
            PlaySound(class'ZedGunProjectile'.default.ExplosionSound,,class'ZedGunProjectile'.default.ExplosionSoundVolume);
            Spawn(class'ZedGunProjectile'.default.ExplosionEmitter,,,HitLocation + HitNormal*20,rotator(HitNormal));
        }
    }
    else
    {
        HitLocation = Location ;
        HitBone = FireRootBone;
        HitBoneDist = 0.0f;
    }

    if( DamageType.default.bAlwaysSevers && DamageType.default.bSpecial )
        HitBone = 'head';

    if( InstigatedBy != None )
        HitNormal = Normal( Normal(InstigatedBy.Location-HitLocation) + VRand() * 0.2 + vect(0,0,2.8) );
    else
        HitNormal = Normal( Vect(0,0,1) + VRand() * 0.2 + vect(0,0,2.8) );

    //log("HitLocation "$Hitlocation) ;

    if ( DamageType.Default.bCausesBlood && (!bRecentHit || (bRecentHit && (FRand() > 0.8))))
    {
        if ( !class'GameInfo'.static.NoBlood() && !class'GameInfo'.static.UseLowGore() )
        {
            if ( Momentum != vect(0,0,0) )
                SplatRot = rotator(Normal(Momentum));
            else
            {
                if ( InstigatedBy != None )
                    SplatRot = rotator(Normal(Location - InstigatedBy.Location));
                else
                    SplatRot = rotator(Normal(Location - HitLocation));
            }

             BloodHit = Spawn(ProjectileBloodSplatClass,InstigatedBy,, HitLocation, SplatRot);
        }
    }

    if( InstigatedBy != none && InstigatedBy.PlayerReplicationInfo != none &&
        KFSteamStatsAndAchievements(InstigatedBy.PlayerReplicationInfo.SteamStatsAndAchievements) != none &&
        Health <= 0 && Damage > DamageType.default.HumanObliterationThreshhold && Damage != 1000 && (!bDecapitated || bPlayBrainSplash) )
    {
        KFSteamStatsAndAchievements(InstigatedBy.PlayerReplicationInfo.SteamStatsAndAchievements).AddGibKill(class<DamTypeM79Grenade>(damageType) != none);

        if ( self.IsA('ZombieFleshPound') )
        {
            KFSteamStatsAndAchievements(InstigatedBy.PlayerReplicationInfo.SteamStatsAndAchievements).AddFleshpoundGibKill();
        }
    }

    DoDamageFX( HitBone, Damage, DamageType, Rotator(HitNormal) );

    if (DamageType.default.DamageOverlayMaterial != None && Damage > 0 ) // additional check in case shield absorbed
        SetOverlayMaterial( DamageType.default.DamageOverlayMaterial, DamageType.default.DamageOverlayTime, false );
}

static simulated function PreCacheMaterials(LevelInfo myLevel)
{//should be derived and used.
    myLevel.AddPrecacheMaterial(Texture'KF_Specimens_Trip_T_Two.burns_diff');
    myLevel.AddPrecacheMaterial(Texture'KF_Specimens_Trip_T_Two.burns_emissive_mask');
    myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T_Two.burns_energy_cmb');
    myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T_Two.burns_env_cmb');
    myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T_Two.burns_fire_cmb');
    myLevel.AddPrecacheMaterial(Material'KF_Specimens_Trip_T_Two.burns_shdr');
    myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T_Two.burns_cmb');
}

defaultproperties
{
    //-------------------------------------------------------------------------------
    // NOTE: Most Default Properties are set in the base class to eliminate hitching
    //-------------------------------------------------------------------------------
    EventClasses(0)="KFAdvZeds.AdvZombieHusk_S"
    AdvHuskFireProjClass=Class'AdvHuskFireProjectile'
    AdvHuskFlameProjClass=Class'AdvHuskFlameProjectile'
    ControllerClass=Class'AdvHuskZombieController'
}
