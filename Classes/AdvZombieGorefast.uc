/*
 * Modified Gorefast - can block gunfire, parry Berserkers!
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
 */

class AdvZombieGorefast extends AdvZombieGorefastBase
    abstract;

// Package Loading
#exec OBJ LOAD FILE=KFAdvZeds_A.ukx


var bool bEnableNewBurnBehaviour;       // Gorefasts take extra damage when on fire, enter the burnt state much faster, burn for longer, and gain an increase in movement speed whilst on fire.
var bool bEnableBlock;                  // Chance to enter a blocking state when shot at or when a Player closes in on a him while holding a melee weapon.
var bool bEnableParry;                  // Gorefasts that are meleed during a blocking state will negate all damage from the melee hit and counter with an attack that deals double damage
var bool bEnableLegshots;               // Gorefasts can have their charge interrupted and disabled by shots to the leg. Shotguns and high caliber weapons can dismember legs.
var bool bEnableDestroyableBladeArm;    // Shotguns and high caliber weapons can dismember his arm. Gorefast's Blade can be destroyed when hit by the Chainsaw.
var int FinesseLevel;                   // How good Gorefasts are at parrying. Higher numbers increases parry chance and makes higher tier melee weapons e.g Katana, parryable.


// Check for shots to the legs - modified headshot code(WIP)
function bool IsLegShot(vector loc, vector ray, float AdditionalScale)
{
    local coords C;
    local vector LegLoc, B, M, diff;
    local float t, DotMM, Distance;
    local int look;
    local bool bUseAltLegShotLocation;
    local bool bWasAnimating;

    if (LeftFootBone == '')
        return False;

    // If we are a dedicated server estimate what animation is most likely playing on the client
    if (Level.NetMode == NM_DedicatedServer)
    {
        if (Physics == PHYS_Falling)
            PlayAnim(AirAnims[0], 1.0, 0.0);
        else if (Physics == PHYS_Walking)
        {
            // Only play the idle anim if we're not already doing a different anim.
            // This prevents anims getting interrupted on the server and borking things up - Ramm

            if( !IsAnimating(0) && !IsAnimating(1) )
            {
                if (bIsCrouched)
                {
                    PlayAnim(IdleCrouchAnim, 1.0, 0.0);
                }
                else
                {
                    bUseAltLegShotLocation=true;
                }
            }
            else
            {
                bWasAnimating = true;
            }

            if ( bDoTorsoTwist )
            {
                SmoothViewYaw = Rotation.Yaw;
                SmoothViewPitch = ViewPitch;

                look = (256 * ViewPitch) & 65535;
                if (look > 32768)
                    look -= 65536;

                SetTwistLook(0, look);
            }
        }
        else if (Physics == PHYS_Swimming)
            PlayAnim(SwimAnims[0], 1.0, 0.0);

        if( !bWasAnimating )
        {
            SetAnimFrame(0.5);
        }
    }

    if( bUseAltLegShotLocation )
    {
        LegLoc = Location + (OnlineHeadshotOffset >> Rotation);
        AdditionalScale *= OnlineHeadshotScale;
    }
    else
    {
        C = GetBoneCoords(LeftFootBone);

        LegLoc = C.Origin + (HeadHeight * HeadScale * AdditionalScale * C.XAxis);
    }

    // Express snipe trace line in terms of B + tM
    B = loc;
    M = ray * (2.0 * CollisionHeight + 2.0 * CollisionRadius);

    // Find Point-Line Squared Distance
    diff = LegLoc - B;
    t = M Dot diff;
    if (t > 0)
    {
        DotMM = M dot M;
        if (t < DotMM)
        {
            t = t / DotMM;
            diff = diff - (t * M);
        }
        else
        {
            t = 1;
            diff -= M;
        }
    }
    else
        t = 0;

    Distance = Sqrt(diff Dot diff);

    return (Distance < (HeadRadius * HeadScale * AdditionalScale));
}


simulated function PostNetReceive()
{
    if( !bZapped )
    {
        if (bRunning)
            MovementAnims[0]='ZombieRun';
        else MovementAnims[0]=default.MovementAnims[0];
    }
}

// This zed has been taken control of. Boost its health and speed
function SetMindControlled(bool bNewMindControlled)
{
    if( bNewMindControlled )
    {
        NumZCDHits++;

        // if we hit him a couple of times, make him rage!
        if( NumZCDHits > 1 )
        {
            if( !IsInState('RunningToMarker') )
            {
                GotoState('RunningToMarker');
            }
            else
            {
                NumZCDHits = 1;
                if( IsInState('RunningToMarker') )
                {
                    GotoState('');
                }
            }
        }
        else
        {
            if( IsInState('RunningToMarker') )
            {
                GotoState('');
            }
        }

        if( bNewMindControlled != bZedUnderControl )
        {
            SetGroundSpeed(OriginalGroundSpeed * 1.25);
            Health *= 1.25;
            HealthMax *= 1.25;
        }
    }
    else
    {
        NumZCDHits=0;
    }

    bZedUnderControl = bNewMindControlled;
}

// Handle the zed being commanded to move to a new location
function GivenNewMarker()
{
    if( bRunning && NumZCDHits > 1 )
    {
        GotoState('RunningToMarker');
    }
    else
    {
        GotoState('');
    }
}

function RangedAttack(Actor A)
{
    Super.RangedAttack(A);
    if( !bShotAnim && !bDecapitated && VSize(A.Location-Location)<=700 )
        GoToState('RunningState');
}

state RunningState
{
    // Set the zed to the zapped behavior
    simulated function SetZappedBehavior()
    {
        Global.SetZappedBehavior();
        GoToState('');
    }

    // Don't override speed in this state
    function bool CanSpeedAdjust()
    {
        return false;
    }

    function BeginState()
    {
        if( bZapped )
        {
            GoToState('');
        }
        else
        {
            SetGroundSpeed(OriginalGroundSpeed * 1.875);
            bRunning = true;
            if( Level.NetMode!=NM_DedicatedServer )
                PostNetReceive();

            NetUpdateTime = Level.TimeSeconds - 1;
        }
    }

    function EndState()
    {
        if( !bZapped )
        {
            SetGroundSpeed(GetOriginalGroundSpeed());
        }
        bRunning = False;
        if( Level.NetMode!=NM_DedicatedServer )
            PostNetReceive();

        RunAttackTimeout=0;

        NetUpdateTime = Level.TimeSeconds - 1;
    }

    function RemoveHead()
    {
        GoToState('');
        Global.RemoveHead();
    }

    function RangedAttack(Actor A)
    {
        local float ChargeChance;

        // Decide what chance the gorefast has of charging during an attack
        if( Level.Game.GameDifficulty < 2.0 )
        {
            ChargeChance = 0.1;
        }
        else if( Level.Game.GameDifficulty < 4.0 )
        {
            ChargeChance = 0.2;
        }
        else if( Level.Game.GameDifficulty < 5.0 )
        {
            ChargeChance = 0.3;
        }
        else // Hardest difficulty
        {
            ChargeChance = 0.4;
        }

        if ( bShotAnim || Physics == PHYS_Swimming)
            return;
        else if ( CanAttack(A) )
        {
            bShotAnim = true;

            // Randomly do a moving attack so the player can't kite the zed
            if( FRand() < ChargeChance )
            {
                SetAnimAction('ClawAndMove');
                RunAttackTimeout = GetAnimDuration('GoreAttack1', 1.0);
            }
            else
            {
                SetAnimAction('Claw');
                Controller.bPreparingMove = true;
                Acceleration = vect(0,0,0);
                // Once we attack stop running
                GoToState('');
            }
            return;
        }
    }

    simulated function Tick(float DeltaTime)
    {
        // Keep moving toward the target until the timer runs out (anim finishes)
        if( RunAttackTimeout > 0 )
        {
            RunAttackTimeout -= DeltaTime;

            if( RunAttackTimeout <= 0 && !bZedUnderControl )
            {
                RunAttackTimeout = 0;
                GoToState('');
            }
        }

        // Keep the gorefast moving toward its target when attacking
        if( Role == ROLE_Authority && bShotAnim && !bWaitForAnim )
        {
            if( LookTarget!=None )
            {
                Acceleration = AccelRate * Normal(LookTarget.Location - Location);
            }
        }

        global.Tick(DeltaTime);
    }


Begin:
    GoTo('CheckCharge');
CheckCharge:
    if( Controller!=None && Controller.Target!=None && VSize(Controller.Target.Location-Location)<700 )
    {
        Sleep(0.5+ FRand() * 0.5);
        //log("Still charging");
        GoTo('CheckCharge');
    }
    else
    {
        //log("Done charging");
        GoToState('');
    }
}

// State where the zed is charging to a marked location.
state RunningToMarker extends RunningState
{
    simulated function Tick(float DeltaTime)
    {
        // Keep moving toward the target until the timer runs out (anim finishes)
        if( RunAttackTimeout > 0 )
        {
            RunAttackTimeout -= DeltaTime;

            if( RunAttackTimeout <= 0 && !bZedUnderControl )
            {
                RunAttackTimeout = 0;
                GoToState('');
            }
        }

        // Keep the gorefast moving toward its target when attacking
        if( Role == ROLE_Authority && bShotAnim && !bWaitForAnim )
        {
            if( LookTarget!=None )
            {
                Acceleration = AccelRate * Normal(LookTarget.Location - Location);
            }
        }

        global.Tick(DeltaTime);
    }


Begin:
    GoTo('CheckCharge');
CheckCharge:
    if( bZedUnderControl || (Controller!=None && Controller.Target!=None && VSize(Controller.Target.Location-Location)<700) )
    {
        Sleep(0.5+ FRand() * 0.5);
        GoTo('CheckCharge');
    }
    else
    {
        GoToState('');
    }
}

// Overridden to handle playing upper body only attacks when moving
simulated event SetAnimAction(name NewAction)
{
    local int meleeAnimIndex;
    local bool bWantsToAttackAndMove;

    if( NewAction=='' )
        Return;

    bWantsToAttackAndMove = NewAction == 'ClawAndMove';

    if( NewAction == 'Claw' )
    {
        meleeAnimIndex = Rand(3);
        NewAction = meleeAnims[meleeAnimIndex];
        CurrentDamtype = ZombieDamType[meleeAnimIndex];
    }

    if( bWantsToAttackAndMove )
    {
       ExpectingChannel = AttackAndMoveDoAnimAction(NewAction);
    }
    else
    {
       ExpectingChannel = DoAnimAction(NewAction);
    }

    if( !bWantsToAttackAndMove && AnimNeedsWait(NewAction) )
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
    local int meleeAnimIndex;

    if( AnimName == 'ClawAndMove' )
    {
        meleeAnimIndex = Rand(3);
        AnimName = meleeAnims[meleeAnimIndex];
        CurrentDamtype = ZombieDamType[meleeAnimIndex];
    }

    if( AnimName=='GoreAttack1' || AnimName=='GoreAttack2' )
    {
        AnimBlendParams(1, 1.0, 0.0,, FireRootBone);
        PlayAnim(AnimName,, 0.1, 1);

        return 1;
    }

    return super.DoAnimAction( AnimName );
}

simulated function HideBone(name boneName)
{
    //  Gorefast does not have a left arm and does not need it to be hidden
    if (boneName != LeftFArmBone)
    {
        super.HideBone(boneName);
    }
}

static simulated function PreCacheMaterials(LevelInfo myLevel)
{//should be derived and used.
    myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T.gorefast_cmb');
    myLevel.AddPrecacheMaterial(Combiner'KF_Specimens_Trip_T.gorefast_env_cmb');
    myLevel.AddPrecacheMaterial(Texture'KF_Specimens_Trip_T.gorefast_diff');
}

defaultproperties
{
    //-------------------------------------------------------------------------------
    // NOTE: Most Default Properties are set in the base class to eliminate hitching
    //-------------------------------------------------------------------------------

    EventClasses(0)="KFAdvZeds.AdvZombieGorefast"
    ControllerClass=Class'KFAdvZeds.AdvZombieGorefastController'

    // The gorefasts left arm is already set to gibbed so that shooting his nub will not create severed limbs
    bLeftArmGibbed=true
}