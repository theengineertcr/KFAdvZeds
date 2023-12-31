class AdvSawZombieController extends KFMonsterController;
// Custom Zombie Thinkerating
// By : Alex

var	bool	bDoneSpottedCheck;
var bool    bFacingTarget;
var float RelativeDir;

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

function bool FireWeaponAt(Actor A) {
    if (A == none) {
        A = Enemy;
    }
    if (A == none || Focus != A) {
        return false;
    }
    
    Monster(Pawn).RangedAttack(Target);
    return false;
}

function tick(float DeltaTime) {
    local vector aFacing, aToB, TargetFacing, BToa;
    local float TargetRelativeDir;

    super.tick(DeltaTime);
    
    aFacing = Normal(Vector(Pawn.Rotation));
    TargetFacing = Normal(Vector(Enemy.Rotation));

    // Get the vector from A to B
    aToB = Enemy.Location - Pawn.Location;
    BToa = Pawn.Location - Enemy.Location;

    RelativeDir = aFacing dot aToB;
    TargetRelativeDir = TargetFacing dot BToa;
    
    if (RelativeDir < 30) {
        bFacingTarget = false;
    } else {
        bFacingTarget = true;
    }
}

defaultproperties {
}
