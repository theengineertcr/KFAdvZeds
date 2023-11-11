class AdvSawZombieController extends KFMonsterController;
// Custom Zombie Thinkerating
// By : Alex

var	bool	bDoneSpottedCheck;
var bool    bFacingTarget;

state ZombieHunt {
    event SeePlayer(Pawn SeenPlayer) {
        if ( !bDoneSpottedCheck && PlayerController(SeenPlayer.Controller) != none ) {
            // 25% chance of first player to see this Scrake saying something
            if ( !KFGameType(Level.Game).bDidSpottedScrakeMessage && FRand() < 0.25 ) {
                PlayerController(SeenPlayer.Controller).Speech('AUTO', 14, "");
                KFGameType(Level.Game).bDidSpottedScrakeMessage = true;
            }

            bDoneSpottedCheck = true;
        }

        super.SeePlayer(SeenPlayer);
    }
}

function TimedFireWeaponAtEnemy() {
    if ( (Enemy == None) || FireWeaponAt(Enemy) )
        SetCombatTimer();
    else SetTimer(0.01, True);
}

function bool FireWeaponAt(Actor A) {
    local vector aFacing, aToB, TargetFacing, BToa;
    local float RelativeDir, TargetRelativeDir;

    if (A == none) {
        A = Enemy;
    }
    if (A == none || Focus != A) {
        return false;
    }


    aFacing = Normal(Vector(Pawn.Rotation));
    TargetFacing = Normal(Vector(A.Rotation));

    // Get the vector from A to B
    aToB = A.Location - Pawn.Location;
    BToa = Pawn.Location - A.Location;

    RelativeDir = aFacing dot aToB;
    TargetRelativeDir = TargetFacing dot BToa;

    if (RelativeDir < -15) {
        bFacingTarget = false;
    } else {
        bFacingTarget = true;
    }
    

    if (CanAttack(A)) {
        Target = A;
        Monster(Pawn).RangedAttack(Target);
    }
    return false;
}

state ZombieCharge {
    // Don't do this in this state
    function GetOutOfTheWayOfShot(vector ShotDirection, vector ShotOrigin){}

    function bool StrafeFromDamage(float Damage, class<DamageType> DamageType, bool bFindDest) {
        return false;
    }
    function bool TryStrafe(vector sideDir) {
        return false;
    }
    function Timer() {
        Disable('NotifyBump');
        Target = Enemy;
        TimedFireWeaponAtEnemy();
    }

WaitForAnim:

    While( Monster(Pawn).bShotAnim )
        Sleep(0.25);
    if ( !FindBestPathToward(Enemy, false,true) )
        GotoState('ZombieRestFormation');
Moving:
    MoveToward(Enemy);
    WhatToDoNext(17);
    if ( bSoaking )
        SoakStop("STUCK IN CHARGING!");
}

defaultproperties {
}
